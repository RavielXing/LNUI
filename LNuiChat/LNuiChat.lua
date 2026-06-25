-- 局部化常用全局函数/变量（扩展缓存）
local string_gsub, table_insert, table_concat, date, type, tostring, print, pcall, ipairs, pairs, select, math, strsub, time, difftime, tContains, GetUnitSpeed, IsFalling, IsFlying, IsSwimming, StaticPopupDialogs, StaticPopup_Show =
      string.gsub, table.insert, table.concat, date, type, tostring, print, pcall, ipairs, pairs, select, math, string.sub, time, difftime, tContains, GetUnitSpeed, IsFalling, IsFlying, IsSwimming, StaticPopupDialogs, StaticPopup_Show
local GetChannelName = GetChannelName
local UnitAffectingCombat = UnitAffectingCombat
local IsInInstance = IsInInstance
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsInGuild = IsInGuild
local GetCVar = GetCVar
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatEdit_UpdateHeader = ChatEdit_UpdateHeader
local ChatFrame_OpenChat = ChatFrame_OpenChat
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local SELECTED_CHAT_FRAME = SELECTED_CHAT_FRAME
local C_Timer = C_Timer
local C_ChallengeMode = C_ChallengeMode
local C_Scenario = C_Scenario
local C_PartyInfo = C_PartyInfo
local C_ChatInfo = C_ChatInfo
local GetTime = GetTime
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10
local string_lower = string.lower
local string_find = string.find
local string_len = string.len
local string_gmatch = string.gmatch
local wipe = table.wipe
local CreateFrame = CreateFrame
local strupper = string.upper

-- 加载本地化模块
local L = _G.LNuiChat_L or {}
local locale = GetLocale()
local isZhTW = (locale == "zhTW")

-- 本地化辅助函数
local function GT(key)
    return L[key] or key
end

local function SafeCopy(str)
    if type(str) ~= "string" then return str end
    local ok = pcall(function() str:gsub("", "") end)
    if ok then return str end
    return "[Protected]"
end

-- ========================================================================================================================
-- 第一部分：聊天输入框位置调整
-- ========================================================================================================================
function _G.LNuiChat_UpdateInputPosition()
    local chatInput = DEFAULT_CHAT_FRAME.editBox
    if not chatInput then return end

    local db = _G.LNuiChatDB or {}
    local globalDB = db.global or {}
    local attachTo = globalDB.inputAttachTo or db.inputAttachTo or "chatframe"
    local hasMoved = db.hasMoved or false

    chatInput:ClearAllPoints()

    if attachTo == "channelbar" then
        local channelBar = _G.LNuiChat or _G.ChannelBar
        if channelBar and channelBar:IsShown() then
            local barWidth = channelBar:GetWidth()
            local targetWidth = math.max(barWidth - 10, 100)
            chatInput:SetWidth(targetWidth)
            local offsetY = hasMoved and -2 or -5
            chatInput:SetPoint("TOP", channelBar, "BOTTOM", 0, offsetY)
        else
            local chatFrameWidth = _G.ChatFrame1 and _G.ChatFrame1:GetWidth() or 0
            chatInput:SetPoint("BOTTOMLEFT", _G.ChatFrame1, "BOTTOMLEFT", 0, -2)
            if chatFrameWidth > 100 then chatInput:SetWidth(chatFrameWidth) end
        end
    else
        local chatFrameWidth = _G.ChatFrame1 and _G.ChatFrame1:GetWidth() or 0
        local offsetY = hasMoved and -35 or -55
        chatInput:SetPoint("BOTTOM", _G.ChatFrame1, "BOTTOM", -5, offsetY)
        if chatFrameWidth > 100 then chatInput:SetWidth(chatFrameWidth) end
    end

    local originalHeight = chatInput:GetHeight()
    chatInput:SetHeight(originalHeight)
end

local function AdjustChatInputPosition()
    _G.LNuiChat_UpdateInputPosition()
end

-- ========================================================================================================================
-- 第二部分：免ALT键查看输入记录
-- ========================================================================================================================
local chatHistory = {}
local chatHistoryIndex = 0
local MAX_HISTORY = 20

local function EnableChatHistory()
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame"..i.."EditBox"]
        if editBox then
            hooksecurefunc(editBox, "AddHistoryLine", function(self, msg)
                if editBox:GetAltArrowKeyMode() then return end
                if #chatHistory >= MAX_HISTORY then
                    table.remove(chatHistory, MAX_HISTORY)
                end
                table_insert(chatHistory, 1, msg)
            end)

            editBox:HookScript("OnShow", function()
                if editBox:GetAltArrowKeyMode() then return end
                chatHistoryIndex = 0
            end)

            editBox:HookScript("OnKeyDown", function(self, key)
                if key ~= "UP" and key ~= "DOWN" then return end
                local count = #chatHistory
                if count == 0 then return end

                if key == "UP" then
                    if chatHistoryIndex < count then chatHistoryIndex = chatHistoryIndex + 1
                    else chatHistoryIndex = 1 end
                elseif key == "DOWN" then
                    if chatHistoryIndex > 1 then chatHistoryIndex = chatHistoryIndex - 1
                    else chatHistoryIndex = count end
                end
                self:SetText(chatHistory[chatHistoryIndex])
            end)
        end
    end
end

local function SetAltArrowKeyMode(enabled)
    local mode = not enabled
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame"..i.."EditBox"]
        if editBox and editBox.SetAltArrowKeyMode then
            editBox:SetAltArrowKeyMode(mode)
        end
    end
end

local function InitializeAltArrowMode()
    local db = _G.LNuiChatDB or {}
    if db.altArrowMode == nil then db.altArrowMode = true end
    EnableChatHistory()
    SetAltArrowKeyMode(db.altArrowMode)
end

function _G.LNuiChat_SetAltArrowMode(enabled)
    local db = _G.LNuiChatDB or {}
    db.altArrowMode = enabled
    SetAltArrowKeyMode(enabled)
end

function _G.LNuiChat_GetAltArrowMode()
    local db = _G.LNuiChatDB or {}
    return db.altArrowMode
end

-- 获取大脚世界频道名称
local function GetWorldChannelName()
    return isZhTW and "大腳世界頻道" or "大脚世界频道"
end

-- ========================================================================================================================
-- 第三部分：TAB频道切换功能
-- ========================================================================================================================
local tabSwitchHooked = false

local cycles = {
    {chatType = "SAY", use = function() return true end},
    {chatType = "YELL", use = function() return true end},
    {chatType = "PARTY", use = function() return IsInGroup() end},
    {chatType = "RAID", use = function() return IsInRaid() end},
    {chatType = "INSTANCE_CHAT", use = function()
        local inInstance, instanceType = IsInInstance()
        return inInstance and instanceType == "pvp"
    end},
    {chatType = "GUILD", use = function() return IsInGuild() end},
    {chatType = "WHISPER", use = function(_, editbox)
        local tellTarget = editbox:GetAttribute("tellTarget")
        if tellTarget and tellTarget ~= "" then return true end
        if ChatEdit_GetLastTellTarget then
            local lastTarget = ChatEdit_GetLastTellTarget()
            if lastTarget and lastTarget ~= "" then
                editbox:SetAttribute("tellTarget", lastTarget)
                return true
            end
        end
        return false
    end},
    {chatType = "BN_WHISPER", use = function(_, editbox)
        local tellTarget = editbox:GetAttribute("tellTarget")
        if tellTarget and tellTarget ~= "" then return true end
        if ChatEdit_GetLastBNTellTarget then
            local lastTarget = ChatEdit_GetLastBNTellTarget()
            if lastTarget and lastTarget ~= "" then
                editbox:SetAttribute("tellTarget", lastTarget)
                return true
            end
        end
        return false
    end},
    {chatType = "CHANNEL", use = function(_, editbox)
        local currChatType = editbox:GetAttribute("chatType")
        local currNum
        if currChatType ~= "CHANNEL" then
            currNum = IsShiftKeyDown() and 21 or 0
        else
            currNum = editbox:GetAttribute("channelTarget")
        end
        local h, r, step = currNum + 1, 20, 1
        if IsShiftKeyDown() then h, r, step = currNum - 1, 1, -1 end
        local worldChannelName = GetWorldChannelName()
        for i = h, r, step do
            local channelNum, channelName = GetChannelName(i)
            if channelNum and channelNum > 0 and channelName and string_find(channelName, worldChannelName) then
                editbox:SetAttribute("channelTarget", i)
                return true
            end
        end
        return false
    end},
    {chatType = "SAY", use = function() return true end},
}

local function TabSwitchFunction(self)
    local text = tostring(self:GetText() or "")
    if strsub(text, 1, 1) == "/" then return end
    local currChatType = self:GetAttribute("chatType")
    local cycleCount = #cycles

    for i = 1, cycleCount do
        if cycles[i].chatType == currChatType then
            local startIndex = (currChatType == "CHANNEL") and i or (i + 1)
            for j = startIndex, cycleCount do
                if cycles[j].use(cycles[j], self) then
                    self:SetAttribute("chatType", cycles[j].chatType)
                    ChatEdit_UpdateHeader(self)
                    return
                end
            end
            for j = 1, i do
                if cycles[j].use(cycles[j], self) then
                    self:SetAttribute("chatType", cycles[j].chatType)
                    ChatEdit_UpdateHeader(self)
                    return
                end
            end
        end
    end
end

local function InitializeTabSwitch()
    if tabSwitchHooked then return end
    if type(ChatEdit_CustomTabPressed) == "function" or ChatEdit_CustomTabPressed == nil then
        ChatEdit_CustomTabPressed = TabSwitchFunction
        tabSwitchHooked = true
    end
end

-- ========================================================================================================================
-- 第四部分：聊天链接鼠标提示功能
-- ========================================================================================================================
local chatLinkTooltipHooked = false

local function OnHyperlinkEnter(frame, link, button)
    if not link or type(link) ~= "string" then return end
    if string_find(link, "^trade:") then return end

    GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    local success = pcall(function()
        if string_find(link, "^item:") or string_find(link, "^spell:") or string_find(link, "^enchant:") or
           string_find(link, "^glyph:") or string_find(link, "^instancelock:") or
           string_find(link, "^unit:") or string_find(link, "^achievement:") then
            GameTooltip:SetHyperlink(link)
        end
    end)
    if success then GameTooltip:Show() else GameTooltip:Hide() end
end

local function OnHyperlinkLeave()
    GameTooltip:Hide()
end

local function InitializeChatLinkTooltip()
    if chatLinkTooltipHooked then return end
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame"..i]
        if chatFrame then
            pcall(function()
                chatFrame:SetScript("OnHyperlinkEnter", OnHyperlinkEnter)
                chatFrame:SetScript("OnHyperlinkLeave", OnHyperlinkLeave)
            end)
        end
    end
    chatLinkTooltipHooked = true
end

-- ========================================================================================================================
-- 第五部分：聊天表情
-- ========================================================================================================================
_G.LNuiChatEmote = _G.LNuiChatEmote or {}

-- 获取本地化表情名称
local function GetLocalizedEmotes()
    if isZhTW then
        return {
            {"{rt1}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"},
            {"{rt2}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2"},
            {"{rt3}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"},
            {"{rt4}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4"},
            {"{rt5}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5"},
            {"{rt6}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6"},
            {"{rt7}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"},
            {"{rt8}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"},
            {GT("emote_angel"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Angel"},
            {GT("emote_angry"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Angry"},
            {GT("emote_biglaugh"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Biglaugh"},
            {GT("emote_clap"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Clap"},
            {GT("emote_cool"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Cool"},
            {GT("emote_cry"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Cry"},
            {GT("emote_cutie"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Cutie"},
            {GT("emote_despise"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Despise"},
            {GT("emote_dreamsmile"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Dreamsmile"},
            {GT("emote_embarrass"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Embarrass"},
            {GT("emote_evil"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Evil"},
            {GT("emote_excited"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Excited"},
            {GT("emote_faint"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Faint"},
            {GT("emote_fight"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Fight"},
            {GT("emote_flu"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Flu"},
            {GT("emote_freeze"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Freeze"},
            {GT("emote_frown"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Frown"},
            {GT("emote_greet"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Greet"},
            {GT("emote_grimace"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Grimace"},
            {GT("emote_growl"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Growl"},
            {GT("emote_happy"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Happy"},
            {GT("emote_heart"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Heart"},
            {GT("emote_horror"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Horror"},
            {GT("emote_ill"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Ill"},
            {GT("emote_innocent"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Innocent"},
            {GT("emote_kongfu"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Kongfu"},
            {GT("emote_love"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Love"},
            {GT("emote_mail"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Mail"},
            {GT("emote_makeup"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Makeup"},
            {GT("emote_meditate"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Meditate"},
            {GT("emote_miserable"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Miserable"},
            {GT("emote_okay"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Okay"},
            {GT("emote_pretty"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Pretty"},
            {GT("emote_puke"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Puke"},
            {GT("emote_shake"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Shake"},
            {GT("emote_shout"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Shout"},
            {GT("emote_shuuuu"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Shuuuu"},
            {GT("emote_shy"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Shy"},
            {GT("emote_sleep"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Sleep"},
            {GT("emote_smile"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Smile"},
            {GT("emote_surprise"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Suprise"},
            {GT("emote_surrender"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Surrender"},
            {GT("emote_sweat"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Sweat"},
            {GT("emote_tear"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Tear"},
            {GT("emote_tears"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Tears"},
            {GT("emote_think"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Think"},
            {GT("emote_titter"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Titter"},
            {GT("emote_ugly"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Ugly"},
            {GT("emote_victory"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Victory"},
            {GT("emote_volunteer"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Volunteer"},
            {GT("emote_wronged"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Wronged"},
            {GT("emote_laonong"), "Interface\\Addons\\LNuiChat\\Media\\Emotion\\laonong"},
        }
    else
        return {
            {"{rt1}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"},
            {"{rt2}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2"},
            {"{rt3}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"},
            {"{rt4}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4"},
            {"{rt5}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5"},
            {"{rt6}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6"},
            {"{rt7}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"},
            {"{rt8}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"},
            {"{天使}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Angel"},
            {"{生气}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Angry"},
            {"{大笑}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Biglaugh"},
            {"{鼓掌}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Clap"},
            {"{酷}",   "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Cool"},
            {"{哭}",   "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Cry"},
            {"{可爱}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Cutie"},
            {"{鄙视}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Despise"},
            {"{美梦}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Dreamsmile"},
            {"{尴尬}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Embarrass"},
            {"{邪恶}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Evil"},
            {"{兴奋}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Excited"},
            {"{晕}",   "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Faint"},
            {"{打架}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Fight"},
            {"{流感}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Flu"},
            {"{呆}",   "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Freeze"},
            {"{皱眉}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Frown"},
            {"{致敬}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Greet"},
            {"{鬼脸}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Grimace"},
            {"{龇牙}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Growl"},
            {"{开心}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Happy"},
            {"{心}",   "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Heart"},
            {"{恐惧}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Horror"},
            {"{生病}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Ill"},
            {"{无辜}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Innocent"},
            {"{功夫}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Kongfu"},
            {"{花痴}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Love"},
            {"{邮件}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Mail"},
            {"{化妆}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Makeup"},
            {"{沉思}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Meditate"},
            {"{可怜}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Miserable"},
            {"{好}",   "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Okay"},
            {"{漂亮}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Pretty"},
            {"{吐}",   "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Puke"},
            {"{握手}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Shake"},
            {"{喊}",   "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Shout"},
            {"{闭嘴}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Shuuuu"},
            {"{害羞}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Shy"},
            {"{睡觉}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Sleep"},
            {"{微笑}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Smile"},
            {"{吃惊}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Suprise"},
            {"{失败}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Surrender"},
            {"{流汗}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Sweat"},
            {"{流泪}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Tear"},
            {"{悲剧}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Tears"},
            {"{想}",   "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Think"},
            {"{偷笑}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Titter"},
            {"{猥琐}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Ugly"},
            {"{胜利}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Victory"},
            {"{雷锋}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Volunteer"},
            {"{委屈}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\Wronged"},
            {"{老农}", "Interface\\Addons\\LNuiChat\\Media\\Emotion\\laonong"},
        }
    end
end

local emotes = GetLocalizedEmotes()

local EmoteTableFrame = nil
local fmtstring = nil
local customEmoteStartIndex = 1
local emotePatterns = {}

local fmtCache = {}
local function BuildEmotePatterns(iconSize)
    local key = tostring(iconSize)
    if fmtCache[key] then return fmtCache[key] end
    local patterns = {}
    for i = customEmoteStartIndex, #emotes do
        patterns[emotes[i][1]] = format("\124T%s:%d\124t", emotes[i][2], iconSize)
    end
    fmtCache[key] = patterns
    return patterns
end

local function ChatEmoteFilter(_, _, msg, ...)
    if not msg or msg == "" then return false, msg, ... end
    if not fmtstring then return false, msg, ... end
    if not string_find(msg, "{") then return false, msg, ... end
    if not pcall(function() msg:gsub("", "") end) then return false, msg, ... end

    msg = SafeCopy(msg)
    local n = select("#", ...)
    local args
    if n > 0 then
        args = {}
        for i = 1, n do
            local arg = select(i, ...)
            args[i] = (type(arg) == "string") and SafeCopy(arg) or arg
        end
    end

    local success, result = pcall(function()
        return string_gsub(msg, "({[^}]+})", function(match)
            return emotePatterns[match] or match
        end)
    end)

    if success then
        if args then return false, result, unpack(args, 1, n)
        else return false, result end
    else
        if args then return false, msg, unpack(args, 1, n)
        else return false, msg end
    end
end

local function EmoteIconMouseUp(frame, button)
    if button == "LeftButton" then
        local chatStyle = GetCVar("chatStyle")
        local chatFrame = chatStyle == "im" and SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
        local eb = chatFrame and chatFrame.editBox
        if eb then
            eb:Insert(frame.text)
            eb:Show()
            eb:SetFocus()
        end
    end
    _G.LNuiChatEmote.Toggle()
end

local emoteFilterRegistered = false

function _G.LNuiChatEmote.Init()
    if EmoteTableFrame then return end

    local iconSize = 20
    local listIconSize = 20

    local chatFrame = DEFAULT_CHAT_FRAME
    local _, fontSize = chatFrame:GetFont()
    iconSize = math.max(math.floor(fontSize or 14), iconSize)
    fmtstring = format("\124T%%s:%d\124t", iconSize)
    emotePatterns = BuildEmotePatterns(iconSize)

    EmoteTableFrame = CreateFrame("Frame", "LNuiChatEmoteFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    EmoteTableFrame:SetMovable(true)
    EmoteTableFrame:RegisterForDrag("LeftButton")
    EmoteTableFrame:SetScript("OnDragStart", EmoteTableFrame.StartMoving)
    EmoteTableFrame:SetScript("OnDragStop", EmoteTableFrame.StopMovingOrSizing)
    EmoteTableFrame:EnableMouse(true)
    EmoteTableFrame:SetWidth((listIconSize + 6) * 12 + 10)
    EmoteTableFrame:SetHeight((listIconSize + 6) * 5 + 10)
    EmoteTableFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    EmoteTableFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    EmoteTableFrame:SetBackdropBorderColor(0.3, 0.3, 0.3)
    EmoteTableFrame:SetFrameStrata("DIALOG")
    EmoteTableFrame:Hide()

    local row, col = 1, 1
    for i = 1, #emotes do
        local text = emotes[i][1]
        local texture = emotes[i][2]
        local icon = CreateFrame("Frame", nil, EmoteTableFrame)
        icon:SetWidth(listIconSize + 6)
        icon:SetHeight(listIconSize + 6)
        icon.text = text
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetTexture(texture)
        icon.texture:SetAllPoints(icon)
        icon:Show()
        icon:SetPoint("TOPLEFT",
            5 + (col - 1) * (listIconSize + 6),
            -5 - (row - 1) * (listIconSize + 6)
        )
        icon:SetScript("OnMouseUp", EmoteIconMouseUp)
        icon:EnableMouse(true)
        col = col + 1
        if col > 12 then row = row + 1; col = 1 end
    end

    if not emoteFilterRegistered then
        emoteFilterRegistered = true
        local filterEvents = {
            "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
            "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_AFK", "CHAT_MSG_DND",
            "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
            "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_COMMUNITIES_CHANNEL",
        }
        for _, event in ipairs(filterEvents) do
            pcall(function() ChatFrame_AddMessageEventFilter(event, ChatEmoteFilter) end)
        end
    end
end

function _G.LNuiChatEmote.Toggle()
    if not EmoteTableFrame then _G.LNuiChatEmote.Init() end
    EmoteTableFrame:ClearAllPoints()

    local channelBar = _G.LNuiChat or _G.ChannelBar
    if channelBar then
        EmoteTableFrame:SetPoint("BOTTOM", channelBar, "TOP", 250, 5)
    else
        local editBox = _G.ChatFrame1EditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
        if editBox then
            EmoteTableFrame:SetPoint("BOTTOM", editBox, "BOTTOM", 290, 55)
        else
            EmoteTableFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end

    if EmoteTableFrame:IsShown() then EmoteTableFrame:Hide()
    else EmoteTableFrame:Show() end
end

-- ========================================================================================================================
-- 第六部分：密语粘性设置
-- ========================================================================================================================
local function InitializeWhisperSticky()
    C_Timer.After(0.1, function()
        if not _G.LNuiChatDB then _G.LNuiChatDB = {} end
        local globalDB = _G.LNuiChatDB.global or {}
        local enabled = globalDB.whisperStickyEnabled
        if enabled then
            ChatTypeInfo["WHISPER"].sticky = 1
            ChatTypeInfo["BN_WHISPER"].sticky = 1
        else
            ChatTypeInfo["WHISPER"].sticky = 0
            ChatTypeInfo["BN_WHISPER"].sticky = 0
        end
    end)
end

-- ========================================================================================================================
-- 第七部分：表情动作
-- ========================================================================================================================
_G.LNuiChatEmoteSearch = _G.LNuiChatEmoteSearch or {}

-- 获取本地化的 EmoteList
local function GetLocalizedEmoteList()
    if isZhTW then
        return {
          {token="wave", zh="揮手", en="wave", py="huishou hs"},
          {token="cheer", zh="歡呼", en="cheer", py="huanhu hh"},
          {token="clap", zh="鼓掌", en="clap", py="guzhang gz"},
          {token="laugh", zh="大笑", en="laugh", py="daxiao dx"},
          {token="smile", zh="微笑", en="smile", py="weixiao wx"},
          {token="hi", zh="打招呼", en="hi", py="dazhaohu dzh"},
          {token="bye", zh="再見", en="bye", py="zaijian zj"},
          {token="thanks", zh="謝謝", en="thanks", py="xiexie xx"},
          {token="thank", zh="感謝", en="thank", py="ganxie gx"},
          {token="hug", zh="擁抱", en="hug", py="yongbao yb"},
          {token="kiss", zh="飛吻", en="kiss", py="feiwen fw"},
          {token="dance", zh="跳舞", en="dance", py="tiaowu tw"},
          {token="salute", zh="敬禮", en="salute", py="jingli jl"},
          {token="flex", zh="秀肌肉", en="flex", py="xiujirou xjr"},
          {token="rofl", zh="笑翻", en="rofl", py="rofl"},
          {token="lol", zh="大笑", en="lol", py="lol"},
          {token="point", zh="指向", en="point", py="zhixiang zx"},
          {token="wait", zh="等一下", en="wait", py="dengyixia dyx"},
          {token="ready", zh="準備", en="ready", py="zhunbei zb"},
          {token="no", zh="搖頭", en="no", py="yaotou yt"},
          {token="yes", zh="點頭", en="yes", py="diantou dt"},
          {token="yawn", zh="打哈欠", en="yawn", py="dahaqian dhq"},
          {token="sleep", zh="睡覺", en="sleep", py="shuijiao sj"},
          {token="tired", zh="累了", en="tired", py="leilei ll"},
          {token="drink", zh="喝酒", en="drink", py="hejiu hj"},
          {token="eat", zh="吃東西", en="eat", py="chidongxi cdx"},
          {token="burp", zh="打嗝", en="burp", py="dag e dg"},
          {token="agree", zh="同意", en="agree", py="tongyi ty"},
          {token="angry", zh="生氣", en="angry", py="shengqi sq"},
          {token="applaud", zh="喝彩", en="applaud", py="hecai hc"},
          {token="beckon", zh="招手過來", en="beckon", py="zhaoshou zs"},
          {token="beg", zh="乞求", en="beg", py="qiuqiu qq"},
          {token="bored", zh="無聊", en="bored", py="wuliao wl"},
          {token="comfort", zh="安慰", en="comfort", py="anwei aw"},
          {token="confused", zh="困惑", en="confused", py="kunhuo kh"},
          {token="congrats", zh="祝賀", en="congrats", py="zhuhe zh"},
          {token="cough", zh="咳嗽", en="cough", py="kesou ks"},
          {token="drool", zh="流口水", en="drool", py="liukoushui lks"},
          {token="facepalm", zh="捂臉", en="facepalm", py="wulian wl2"},
          {token="gasp", zh="倒吸氣", en="gasp", py="daoxiqi dxq"},
          {token="giggle", zh="咯咯笑", en="giggle", py="gegexiao ggx"},
          {token="glare", zh="瞪眼", en="glare", py="dengyan dy"},
          {token="growl", zh="低吼", en="growl", py="dihou dh"},
          {token="happy", zh="開心", en="happy", py="kaixin kx"},
          {token="kneel", zh="下跪", en="kneel", py="xiagui xg"},
          {token="lick", zh="舔", en="lick", py="tian t"},
          {token="moan", zh="呻吟", en="moan", py="shenyin sy2"},
          {token="moon", zh="露屁股", en="moon", py="lubigu lb"},
          {token="nod", zh="點頭", en="nod", py="diantou dt"},
          {token="purr", zh="呼嚕", en="purr", py="hulu hl"},
          {token="rasp", zh="吐舌頭", en="rasp", py="tushetou tst"},
          {token="roar", zh="怒吼", en="roar", py="nuhou nh"},
          {token="rude", zh="粗魯", en="rude", py="culu cl"},
          {token="scratch", zh="抓撓", en="scratch", py="zhuanao zn"},
          {token="shout", zh="大喊", en="shout", py="dahan dh2"},
          {token="sigh", zh="嘆氣", en="sigh", py="tanqi tq"},
          {token="slap", zh="扇巴掌", en="slap", py="shanbazhang sbz"},
          {token="smirk", zh="壞笑", en="smirk", py="huaixiao hx"},
          {token="snicker", zh="竊笑", en="snicker", py="qiexiao qx"},
          {token="spit", zh="吐口水", en="spit", py="tukoushui tks"},
          {token="stare", zh="盯著看", en="stare", py="dingzeka dzk"},
          {token="taunt", zh="嘲諷", en="taunt", py="chaofeng cf2"},
          {token="tease", zh="取笑", en="tease", py="quxiao qx2"},
          {token="victory", zh="勝利", en="victory", py="shengli sl"},
          {token="violin", zh="拉小提琴", en="violin", py="laxiaotiqin lxtq"},
          {token="whistle", zh="吹口哨", en="whistle", py="chuikoushao cks"},
          {token="work", zh="工作", en="work", py="gongzuo gz3"},
          {token="absent", zh="走神", en="absent", py="zoushen zs"},
          {token="amaze", zh="驚嘆", en="amaze", py="jingtan jt"},
          {token="mad", zh="生氣", en="mad", py="shengqi sq"},
          {token="apologize", zh="道歉", en="apologize", py="daoqian dq"},
          {token="sorry", zh="抱歉", en="sorry", py="baoqian bq"},
          {token="bravo", zh="喝彩", en="bravo", py="hecai hc"},
          {token="applause", zh="鼓掌喝彩", en="applause", py="guzhanghecai gzhc"},
          {token="arm", zh="搭肩", en="arm", py="dajian dj"},
          {token="attacktarget", zh="攻擊目標", en="attacktarget", py="gongjimubiao gjmb"},
          {token="awe", zh="敬畏", en="awe", py="jingwei jw"},
          {token="backpack", zh="翻背包", en="backpack", py="fanbeibao fbb"},
          {token="pack", zh="翻背包", en="pack", py="fanbeibao fbb"},
          {token="badfeeling", zh="不祥預感", en="badfeeling", py="buxiangyugan bxyg"},
          {token="bad", zh="不好感覺", en="bad", py="buhaoganjue bhgj"},
          {token="bark", zh="汪汪叫", en="bark", py="wangwangjiao wwj"},
          {token="bashful", zh="害羞", en="bashful", py="haixiu hx"},
          {token="bite", zh="咬", en="bite", py="yao y"},
          {token="blame", zh="責怪", en="blame", py="zeguai zg"},
          {token="blank", zh="發呆", en="blank", py="fadai fd"},
          {token="bleed", zh="流血", en="bleed", py="liuxue lx"},
          {token="blood", zh="流血", en="blood", py="liuxue lx"},
          {token="blink", zh="眨眼", en="blink", py="zhayan zy"},
          {token="blush", zh="臉紅", en="blush", py="lianhong lh"},
          {token="boggle", zh="震驚", en="boggle", py="zhenjing zj"},
          {token="bonk", zh="敲頭", en="bonk", py="qiaotou qt"},
          {token="doh", zh="敲頭", en="doh", py="qiaotou qt"},
          {token="boop", zh="點鼻子", en="boop", py="dianbizi dbz"},
          {token="bounce", zh="蹦跳", en="bounce", py="bengtiao bt"},
          {token="bow", zh="鞠躬", en="bow", py="jugong jg"},
          {token="brandish", zh="揮舞武器", en="brandish", py="huiwuwuqi hwwq"},
          {token="brb", zh="馬上回來", en="brb", py="mashanghuilai mshl"},
          {token="breath", zh="深呼吸", en="breath", py="shenhuxi shx"},
          {token="belch", zh="打嗝", en="belch", py="dage dg"},
          {token="goodbye", zh="再見", en="goodbye", py="zaijian zj"},
          {token="farewell", zh="告別", en="farewell", py="gaobie gb"},
          {token="cackle", zh="狂笑", en="cackle", py="kuangxiao kx"},
          {token="calm", zh="冷靜", en="calm", py="lengjing lj"},
          {token="challenge", zh="挑戰", en="challenge", py="tiaozhan tz"},
          {token="charge", zh="衝鋒", en="charge", py="chongfeng cf"},
          {token="charm", zh="迷人", en="charm", py="miren mr"},
          {token="woot", zh="歡呼", en="woot", py="huanhu hh"},
          {token="chicken", zh="學雞", en="chicken", py="xueji xj"},
          {token="flap", zh="學雞", en="flap", py="xueji xj"},
          {token="strut", zh="學雞", en="strut", py="xueji xj"},
          {token="chuckle", zh="輕笑", en="chuckle", py="qingxiao qx"},
          {token="chug", zh="豪飲", en="chug", py="haoyin hy"},
          {token="cold", zh="寒冷", en="cold", py="hanleng hl"},
          {token="commend", zh="稱讚", en="commend", py="chengzan cz"},
          {token="grats", zh="祝賀", en="grats", py="zhuhe zh"},
          {token="cower", zh="畏縮", en="cower", py="weishuo ws"},
          {token="fear", zh="害怕", en="fear", py="haipa hp"},
          {token="cry", zh="哭泣", en="cry", py="kuqi kq"},
          {token="sob", zh="抽泣", en="sob", py="chouqi cq"},
          {token="weep", zh="哭", en="weep", py="ku k"},
          {token="ding", zh="升級", en="ding", py="shengji sj"},
          {token="disagree", zh="不同意", en="disagree", py="butongyi bty"},
          {token="duck", zh="躲避", en="duck", py="duobi db"},
          {token="chew", zh="咀嚼", en="chew", py="jujue jj"},
          {token="feast", zh="大吃", en="feast", py="dachi dc"},
          {token="encourage", zh="鼓勵", en="encourage", py="guli gl"},
          {token="eye", zh="打量", en="eye", py="daliang dl"},
          {token="faint", zh="暈倒", en="faint", py="yundao yd"},
          {token="fart", zh="放屁", en="fart", py="fangpi fp"},
          {token="flee", zh="逃跑", en="flee", py="taopao tp"},
          {token="retreat", zh="撤退", en="retreat", py="chetui ct"},
          {token="strong", zh="強壯", en="strong", py="qiangzhuang qz"},
          {token="flirt", zh="調情", en="flirt", py="tiaoqing tq"},
          {token="followme", zh="跟我來", en="followme", py="genwolai gwl"},
          {token="frown", zh="皺眉", en="frown", py="zhoumei zm"},
          {token="gasp", zh="驚訝", en="gasp", py="jingya jy"},
          {token="grin", zh="壞笑", en="grin", py="huaixiao hx"},
          {token="groan", zh="呻吟", en="groan", py="shenyin sy"},
          {token="guffaw", zh="大笑", en="guffaw", py="daxiao dx"},
          {token="hail", zh="致意", en="hail", py="zhiyi zy"},
          {token="hello", zh="你好", en="hello", py="nihao nh"},
          {token="hungry", zh="飢餓", en="hungry", py="jie e je"},
          {token="liedown", zh="躺下", en="liedown", py="tangxia tx"},
          {token="listen", zh="聽", en="listen", py="ting t"},
          {token="look", zh="看", en="look", py="kan k"},
          {token="lost", zh="迷路", en="lost", py="milu ml"},
          {token="love", zh="愛", en="love", py="ai a"},
          {token="massage", zh="按摩", en="massage", py="anmo am"},
          {token="meow", zh="喵叫", en="meow", py="miaojiao mj"},
          {token="mock", zh="嘲笑", en="mock", py="chaoxiao cx"},
          {token="moo", zh="學牛叫", en="moo", py="xueniao xn"},
          {token="mourn", zh="哀悼", en="mourn", py="aidao ad"},
          {token="nosepick", zh="挖鼻孔", en="nosepick", py="wabikong wbk"},
          {token="panic", zh="驚慌", en="panic", py="jinghuang jh"},
          {token="pat", zh="拍拍", en="pat", py="paipai pp"},
          {token="pet", zh="撫摸", en="pet", py="fumo fm"},
          {token="pity", zh="憐憫", en="pity", py="lianmin lm"},
          {token="plead", zh="懇求", en="plead", py="kenqiu kq"},
          {token="poke", zh="戳", en="poke", py="chuo c"},
          {token="ponder", zh="沉思", en="ponder", py="chensi cs"},
          {token="praise", zh="讚美", en="praise", py="zanmei zm"},
          {token="pray", zh="祈禱", en="pray", py="qidao qd"},
          {token="punch", zh="打", en="punch", py="da d"},
          {token="puzzled", zh="疑惑", en="puzzled", py="yihuo yh"},
          {token="quack", zh="鴨叫", en="quack", py="yajiao yj"},
          {token="rasp", zh="粗魯手勢", en="rasp", py="culushoushi clss"},
          {token="revenge", zh="復仇", en="revenge", py="fuchou fc"},
          {token="snort", zh="哼", en="snort", py="heng h"},
          {token="surprised", zh="驚訝", en="surprised", py="jingya jy"},
          {token="surrender", zh="投降", en="surrender", py="touxiang tx"},
          {token="think", zh="思考", en="think", py="sikao sk"},
          {token="thirsty", zh="口渴", en="thirsty", py="kouke kk"},
          {token="tickle", zh="撓癢", en="tickle", py="naoyang ny"},
          {token="train", zh="小火車", en="train", py="xiaohuoche xhc"},
          {token="welcome", zh="歡迎", en="welcome", py="huanying hy"},
          {token="whoa", zh="哇哦", en="whoa", py="wao wo"},
          {token="wink", zh="眨眼", en="wink", py="zhayan zy"},
          {token="lean", zh="倚靠", en="lean", py="yikao yk"},
        }
    else
        return {
          {token="wave", zh="挥手", en="wave", py="huishou hs"},
          {token="cheer", zh="欢呼", en="cheer", py="huanhu hh"},
          {token="clap", zh="鼓掌", en="clap", py="guzhang gz"},
          {token="laugh", zh="大笑", en="laugh", py="daxiao dx"},
          {token="smile", zh="微笑", en="smile", py="weixiao wx"},
          {token="hi", zh="打招呼", en="hi", py="dazhaohu dzh"},
          {token="bye", zh="再见", en="bye", py="zaijian zj"},
          {token="thanks", zh="谢谢", en="thanks", py="xiexie xx"},
          {token="thank", zh="感谢", en="thank", py="ganxie gx"},
          {token="hug", zh="拥抱", en="hug", py="yongbao yb"},
          {token="kiss", zh="飞吻", en="kiss", py="feiwen fw"},
          {token="dance", zh="跳舞", en="dance", py="tiaowu tw"},
          {token="salute", zh="敬礼", en="salute", py="jingli jl"},
          {token="flex", zh="秀肌肉", en="flex", py="xiujirou xjr"},
          {token="rofl", zh="笑翻", en="rofl", py="rofl"},
          {token="lol", zh="大笑", en="lol", py="lol"},
          {token="point", zh="指向", en="point", py="zhixiang zx"},
          {token="wait", zh="等一下", en="wait", py="dengyixia dyx"},
          {token="ready", zh="准备", en="ready", py="zhunbei zb"},
          {token="no", zh="摇头", en="no", py="yaotou yt"},
          {token="yes", zh="点头", en="yes", py="diantou dt"},
          {token="yawn", zh="打哈欠", en="yawn", py="dahaqian dhq"},
          {token="sleep", zh="睡觉", en="sleep", py="shuijiao sj"},
          {token="tired", zh="累了", en="tired", py="leilei ll"},
          {token="drink", zh="喝酒", en="drink", py="hejiu hj"},
          {token="eat", zh="吃东西", en="eat", py="chidongxi cdx"},
          {token="burp", zh="打嗝", en="burp", py="dag e dg"},
          {token="agree", zh="同意", en="agree", py="tongyi ty"},
          {token="angry", zh="生气", en="angry", py="shengqi sq"},
          {token="applaud", zh="喝彩", en="applaud", py="hecai hc"},
          {token="beckon", zh="招手过来", en="beckon", py="zhaoshou zs"},
          {token="beg", zh="乞求", en="beg", py="qiuqiu qq"},
          {token="bored", zh="无聊", en="bored", py="wuliao wl"},
          {token="comfort", zh="安慰", en="comfort", py="anwei aw"},
          {token="confused", zh="困惑", en="confused", py="kunhuo kh"},
          {token="congrats", zh="祝贺", en="congrats", py="zhuhe zh"},
          {token="cough", zh="咳嗽", en="cough", py="kesou ks"},
          {token="drool", zh="流口水", en="drool", py="liukoushui lks"},
          {token="facepalm", zh="捂脸", en="facepalm", py="wulian wl2"},
          {token="gasp", zh="倒吸气", en="gasp", py="daoxiqi dxq"},
          {token="giggle", zh="咯咯笑", en="giggle", py="gegexiao ggx"},
          {token="glare", zh="瞪眼", en="glare", py="dengyan dy"},
          {token="growl", zh="低吼", en="growl", py="dihou dh"},
          {token="happy", zh="开心", en="happy", py="kaixin kx"},
          {token="kneel", zh="下跪", en="kneel", py="xiagui xg"},
          {token="lick", zh="舔", en="lick", py="tian t"},
          {token="moan", zh="呻吟", en="moan", py="shenyin sy2"},
          {token="moon", zh="露屁股", en="moon", py="lubigu lb"},
          {token="nod", zh="点头", en="nod", py="diantou dt"},
          {token="purr", zh="呼噜", en="purr", py="hulu hl"},
          {token="rasp", zh="吐舌头", en="rasp", py="tushetou tst"},
          {token="roar", zh="怒吼", en="roar", py="nuhou nh"},
          {token="rude", zh="粗鲁", en="rude", py="culu cl"},
          {token="scratch", zh="抓挠", en="scratch", py="zhuanao zn"},
          {token="shout", zh="大喊", en="shout", py="dahan dh2"},
          {token="sigh", zh="叹气", en="sigh", py="tanqi tq"},
          {token="slap", zh="扇巴掌", en="slap", py="shanbazhang sbz"},
          {token="smirk", zh="坏笑", en="smirk", py="huaixiao hx"},
          {token="snicker", zh="窃笑", en="snicker", py="qiexiao qx"},
          {token="spit", zh="吐口水", en="spit", py="tukoushui tks"},
          {token="stare", zh="盯着看", en="stare", py="dingzeka dzk"},
          {token="taunt", zh="嘲讽", en="taunt", py="chaofeng cf2"},
          {token="tease", zh="取笑", en="tease", py="quxiao qx2"},
          {token="victory", zh="胜利", en="victory", py="shengli sl"},
          {token="violin", zh="拉小提琴", en="violin", py="laxiaotiqin lxtq"},
          {token="whistle", zh="吹口哨", en="whistle", py="chuikoushao cks"},
          {token="work", zh="工作", en="work", py="gongzuo gz3"},
          {token="absent", zh="走神", en="absent", py="zoushen zs"},
          {token="amaze", zh="惊叹", en="amaze", py="jingtan jt"},
          {token="mad", zh="生气", en="mad", py="shengqi sq"},
          {token="apologize", zh="道歉", en="apologize", py="daoqian dq"},
          {token="sorry", zh="抱歉", en="sorry", py="baoqian bq"},
          {token="bravo", zh="喝彩", en="bravo", py="hecai hc"},
          {token="applause", zh="鼓掌喝彩", en="applause", py="guzhanghecai gzhc"},
          {token="arm", zh="搭肩", en="arm", py="dajian dj"},
          {token="attacktarget", zh="攻击目标", en="attacktarget", py="gongjimubiao gjmb"},
          {token="awe", zh="敬畏", en="awe", py="jingwei jw"},
          {token="backpack", zh="翻背包", en="backpack", py="fanbeibao fbb"},
          {token="pack", zh="翻背包", en="pack", py="fanbeibao fbb"},
          {token="badfeeling", zh="不祥预感", en="badfeeling", py="buxiangyugan bxyg"},
          {token="bad", zh="不好感觉", en="bad", py="buhaoganjue bhgj"},
          {token="bark", zh="汪汪叫", en="bark", py="wangwangjiao wwj"},
          {token="bashful", zh="害羞", en="bashful", py="haixiu hx"},
          {token="bite", zh="咬", en="bite", py="yao y"},
          {token="blame", zh="责怪", en="blame", py="zeguai zg"},
          {token="blank", zh="发呆", en="blank", py="fadai fd"},
          {token="bleed", zh="流血", en="bleed", py="liuxue lx"},
          {token="blood", zh="流血", en="blood", py="liuxue lx"},
          {token="blink", zh="眨眼", en="blink", py="zhayan zy"},
          {token="blush", zh="脸红", en="blush", py="lianhong lh"},
          {token="boggle", zh="震惊", en="boggle", py="zhenjing zj"},
          {token="bonk", zh="敲头", en="bonk", py="qiaotou qt"},
          {token="doh", zh="敲头", en="doh", py="qiaotou qt"},
          {token="boop", zh="点鼻子", en="boop", py="dianbizi dbz"},
          {token="bounce", zh="蹦跳", en="bounce", py="bengtiao bt"},
          {token="bow", zh="鞠躬", en="bow", py="jugong jg"},
          {token="brandish", zh="挥舞武器", en="brandish", py="huiwuwuqi hwwq"},
          {token="brb", zh="马上回来", en="brb", py="mashanghuilai mshl"},
          {token="breath", zh="深呼吸", en="breath", py="shenhuxi shx"},
          {token="belch", zh="打嗝", en="belch", py="dage dg"},
          {token="goodbye", zh="再见", en="goodbye", py="zaijian zj"},
          {token="farewell", zh="告别", en="farewell", py="gaobie gb"},
          {token="cackle", zh="狂笑", en="cackle", py="kuangxiao kx"},
          {token="calm", zh="冷静", en="calm", py="lengjing lj"},
          {token="challenge", zh="挑战", en="challenge", py="tiaozhan tz"},
          {token="charge", zh="冲锋", en="charge", py="chongfeng cf"},
          {token="charm", zh="迷人", en="charm", py="miren mr"},
          {token="woot", zh="欢呼", en="woot", py="huanhu hh"},
          {token="chicken", zh="学鸡", en="chicken", py="xueji xj"},
          {token="flap", zh="学鸡", en="flap", py="xueji xj"},
          {token="strut", zh="学鸡", en="strut", py="xueji xj"},
          {token="chuckle", zh="轻笑", en="chuckle", py="qingxiao qx"},
          {token="chug", zh="豪饮", en="chug", py="haoyin hy"},
          {token="cold", zh="寒冷", en="cold", py="hanleng hl"},
          {token="commend", zh="称赞", en="commend", py="chengzan cz"},
          {token="grats", zh="祝贺", en="grats", py="zhuhe zh"},
          {token="cower", zh="畏缩", en="cower", py="weishuo ws"},
          {token="fear", zh="害怕", en="fear", py="haipa hp"},
          {token="cry", zh="哭泣", en="cry", py="kuqi kq"},
          {token="sob", zh="抽泣", en="sob", py="chouqi cq"},
          {token="weep", zh="哭", en="weep", py="ku k"},
          {token="ding", zh="升级", en="ding", py="shengji sj"},
          {token="disagree", zh="不同意", en="disagree", py="butongyi bty"},
          {token="duck", zh="躲避", en="duck", py="duobi db"},
          {token="chew", zh="咀嚼", en="chew", py="jujue jj"},
          {token="feast", zh="大吃", en="feast", py="dachi dc"},
          {token="encourage", zh="鼓励", en="encourage", py="guli gl"},
          {token="eye", zh="打量", en="eye", py="daliang dl"},
          {token="faint", zh="晕倒", en="faint", py="yundao yd"},
          {token="fart", zh="放屁", en="fart", py="fangpi fp"},
          {token="flee", zh="逃跑", en="flee", py="taopao tp"},
          {token="retreat", zh="撤退", en="retreat", py="chetui ct"},
          {token="strong", zh="强壮", en="strong", py="qiangzhuang qz"},
          {token="flirt", zh="调情", en="flirt", py="tiaoqing tq"},
          {token="followme", zh="跟我来", en="followme", py="genwolai gwl"},
          {token="frown", zh="皱眉", en="frown", py="zhoumei zm"},
          {token="gasp", zh="惊讶", en="gasp", py="jingya jy"},
          {token="grin", zh="坏笑", en="grin", py="huaixiao hx"},
          {token="groan", zh="呻吟", en="groan", py="shenyin sy"},
          {token="guffaw", zh="大笑", en="guffaw", py="daxiao dx"},
          {token="hail", zh="致意", en="hail", py="zhiyi zy"},
          {token="hello", zh="你好", en="hello", py="nihao nh"},
          {token="hungry", zh="饥饿", en="hungry", py="jie e je"},
          {token="liedown", zh="躺下", en="liedown", py="tangxia tx"},
          {token="listen", zh="听", en="listen", py="ting t"},
          {token="look", zh="看", en="look", py="kan k"},
          {token="lost", zh="迷路", en="lost", py="milu ml"},
          {token="love", zh="爱", en="love", py="ai a"},
          {token="massage", zh="按摩", en="massage", py="anmo am"},
          {token="meow", zh="喵叫", en="meow", py="miaojiao mj"},
          {token="mock", zh="嘲笑", en="mock", py="chaoxiao cx"},
          {token="moo", zh="学牛叫", en="moo", py="xueniao xn"},
          {token="mourn", zh="哀悼", en="mourn", py="aidao ad"},
          {token="nosepick", zh="挖鼻孔", en="nosepick", py="wabikong wbk"},
          {token="panic", zh="惊慌", en="panic", py="jinghuang jh"},
          {token="pat", zh="拍拍", en="pat", py="paipai pp"},
          {token="pet", zh="抚摸", en="pet", py="fumo fm"},
          {token="pity", zh="怜悯", en="pity", py="lianmin lm"},
          {token="plead", zh="恳求", en="plead", py="kenqiu kq"},
          {token="poke", zh="戳", en="poke", py="chuo c"},
          {token="ponder", zh="沉思", en="ponder", py="chensi cs"},
          {token="praise", zh="赞美", en="praise", py="zanmei zm"},
          {token="pray", zh="祈祷", en="pray", py="qidao qd"},
          {token="punch", zh="打", en="punch", py="da d"},
          {token="puzzled", zh="疑惑", en="puzzled", py="yihuo yh"},
          {token="quack", zh="鸭叫", en="quack", py="yajiao yj"},
          {token="rasp", zh="粗鲁手势", en="rasp", py="culushoushi clss"},
          {token="revenge", zh="复仇", en="revenge", py="fuchou fc"},
          {token="snort", zh="哼", en="snort", py="heng h"},
          {token="surprised", zh="惊讶", en="surprised", py="jingya jy"},
          {token="surrender", zh="投降", en="surrender", py="touxiang tx"},
          {token="think", zh="思考", en="think", py="sikao sk"},
          {token="thirsty", zh="口渴", en="thirsty", py="kouke kk"},
          {token="tickle", zh="挠痒", en="tickle", py="naoyang ny"},
          {token="train", zh="小火车", en="train", py="xiaohuoche xhc"},
          {token="welcome", zh="欢迎", en="welcome", py="huanying hy"},
          {token="whoa", zh="哇哦", en="whoa", py="wao wo"},
          {token="wink", zh="眨眼", en="wink", py="zhayan zy"},
          {token="lean", zh="倚靠", en="lean", py="yikao yk"},
        }
    end
end

local EmoteList = GetLocalizedEmoteList()

local filteredIndices = {}
local MAX_BUTTONS = 30
local emoteButtons = {}

local textBuilder = {}

local function UpdateEmoteList(query)
    wipe(filteredIndices)
    if not query or query == "" then
        for i = 1, #EmoteList do filteredIndices[i] = i end
    else
        query = string_lower(query)
        local asciiQuery = string.match(query, "^[a-z0-9]+$")
        for idx, e in ipairs(EmoteList) do
            local tok = string_lower(e.token or "")
            local en = string_lower(e.en or "")
            local zh = string_lower(e.zh or "")
            local py = string_lower(e.py or "")
            local matched = false

            if asciiQuery then
                if py ~= "" and string_find(py, query, 1, true) then matched = true end
                if not matched and string_find(tok, query, 1, true) then matched = true end
                if not matched and string_find(en, query, 1, true) then matched = true end
                if not matched and py ~= "" then
                    for p in string_gmatch(py, "%S+") do
                        if strsub(p, 1, string_len(query)) == query then matched = true; break end
                    end
                end
            else
                if string_find(tok, query, 1, true) then matched = true end
                if not matched and string_find(en, query, 1, true) then matched = true end
                if not matched and zh ~= "" and string_find(zh, query, 1, true) then matched = true end
                if not matched and py ~= "" and string_find(py, query, 1, true) then matched = true end
            end

            if matched then table_insert(filteredIndices, idx) end
        end
    end

    local count = #filteredIndices
    if EmoteSearchFrame and EmoteSearchFrame.content then
        EmoteSearchFrame.content:SetHeight(math.max(1, count * 30))
    end

    for i = 1, MAX_BUTTONS do
        local b = emoteButtons[i]
        if i <= count then
            local e = EmoteList[filteredIndices[i]]
            b._emote = e
            local tb = textBuilder
            local ti = 1
            tb[ti] = "|cff00ff00"; ti = ti + 1
            tb[ti] = e.token; ti = ti + 1
            tb[ti] = "|r  —  "; ti = ti + 1
            if e.zh then
                tb[ti] = e.zh; ti = ti + 1
                if e.en then
                    tb[ti] = " ("; ti = ti + 1
                    tb[ti] = e.en; ti = ti + 1
                    tb[ti] = ")"; ti = ti + 1
                end
            else
                tb[ti] = e.en or ""; ti = ti + 1
            end
            b.text:SetText(table_concat(tb, "", 1, ti - 1))
            b:Show()
        else
            b:Hide()
        end
    end
end

local function CreateEmoteButton(i, content)
    local b = CreateFrame("Button", "LNEmoteSearchBtn"..i, content)
    b:SetSize(290, 28)
    b:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -((i-1)*30))

    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetJustifyH("LEFT")

    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b:SetScript("OnClick", function(self, button)
        local e = self._emote
        if not e then return end

        if button == "LeftButton" then
            if type(DoEmote) == "function" then
                local ok = pcall(DoEmote, e.token)
                if not ok then pcall(DoEmote, strupper(e.token)) end
            else
                RunMacroText("/"..e.token)
            end
        elseif button == "RightButton" then
            local edit
            if ChatEdit_GetActiveWindow then edit = ChatEdit_GetActiveWindow()
            elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then edit = DEFAULT_CHAT_FRAME.editBox end

            if edit and edit:HasFocus() and type(edit.Insert) == "function" then
                edit:Insert("/"..e.token.." ")
            else
                ChatFrame_OpenChat("/"..e.token.." ")
            end
        end
    end)

    return b
end

local EmoteSearchFrame = nil

local function InitEmoteSearchFrame()
    if EmoteSearchFrame then return EmoteSearchFrame end

    local frame = CreateFrame("Frame", "LNuiChatEmoteSearchFrame", UIParent, "BackdropTemplate")
    frame:SetSize(310, 350)
    frame:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
    })
    frame:SetBackdropColor(0.06,0.06,0.06,0.8)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(GT("emote_action_title"))

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    drag:SetHeight(28)
    drag:EnableMouse(true)
    drag:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then frame:StartMoving() end
    end)
    drag:SetScript("OnMouseUp", function(self, button) frame:StopMovingOrSizing() end)

    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(220, 24)
    search:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self) UpdateEmoteList(self:GetText()) end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); UpdateEmoteList("") end)
    search:SetText(GT("emote_search_placeholder"))
    frame.searchBox = search

    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 24)
    clearBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
    clearBtn:SetText(GT("emote_clear"))
    clearBtn:SetScript("OnClick", function() search:SetText(""); search:ClearFocus(); UpdateEmoteList("") end)

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -6)
    help:SetText(GT("emote_search_hint"))

    local scrollFrame = CreateFrame("ScrollFrame", "LNEmoteSearchScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 12)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(290, 1)
    scrollFrame:SetScrollChild(content)
    frame.content = content

    for i = 1, MAX_BUTTONS do
        local b = CreateEmoteButton(i, content)
        b:Hide()
        emoteButtons[i] = b
    end

    UpdateEmoteList("")
    frame:Hide()
    EmoteSearchFrame = frame
    return frame
end

function _G.LNuiChatEmoteSearch.Toggle()
    local frame = InitEmoteSearchFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:ClearAllPoints()
        local channelBar = _G.LNuiChat or _G.ChannelBar
        if channelBar then
            frame:SetPoint("BOTTOM", channelBar, "TOP", 200, 5)
        else
            local editBox = _G.ChatFrame1EditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
            if editBox then frame:SetPoint("BOTTOM", editBox, "TOP", 200, 5)
            else frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
        end
        frame:Show()
        frame.searchBox:SetText("")
        UpdateEmoteList("")
    end
end

-- ========================================================================================================================
-- 第八部分：统一初始化
-- ========================================================================================================================
local addonName = "LNuiChat"
local featuresInitialized = false

local function InitializeAllFeatures()
    if featuresInitialized then return end
    featuresInitialized = true

    AdjustChatInputPosition()
    InitializeTabSwitch()
    InitializeChatLinkTooltip()
    InitializeAltArrowMode()
    _G.LNuiChatEmote.Init()
    InitializeWhisperSticky()
end

local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, InitializeAllFeatures)
    end
end)

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, event, addonNameLoaded)
    if addonNameLoaded == addonName then
        C_Timer.After(1, InitializeAllFeatures)
    end
end)

local chatFrameHook = CreateFrame("Frame")
chatFrameHook:RegisterEvent("CHAT_MSG_CHANNEL")
chatFrameHook:RegisterEvent("CHAT_MSG_SAY")
chatFrameHook:RegisterEvent("CHAT_MSG_YELL")
chatFrameHook:RegisterEvent("CHAT_MSG_GUILD")
chatFrameHook:RegisterEvent("CHAT_MSG_PARTY")
chatFrameHook:RegisterEvent("CHAT_MSG_RAID")
chatFrameHook:SetScript("OnEvent", function()
    if not tabSwitchHooked then pcall(InitializeTabSwitch) end
    if not chatLinkTooltipHooked then pcall(InitializeChatLinkTooltip) end
end)
