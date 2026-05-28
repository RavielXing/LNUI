-- ==========================================
-- 功能：一键通报角色属性到聊天频道
-- ==========================================

local addonName = ...
local _, classFile = UnitClass("player")

-- ==========================================
-- 常量与配置
-- ==========================================
local STATS_CONFIG = {
    PRIMARY_STAT_INDEX = {
        ["WARRIOR"]     = 1,
        ["PALADIN"]     = 1,
        ["HUNTER"]      = 2,
        ["ROGUE"]       = 2,
        ["PRIEST"]      = 4,
        ["DEATHKNIGHT"] = 1,
        ["SHAMAN"]      = 2,
        ["MAGE"]        = 4,
        ["WARLOCK"]     = 4,
        ["MONK"]        = 2,
        ["DRUID"]       = 2,
        ["DEMONHUNTER"] = 2,
        ["EVOKER"]      = 4,
    },
    PRIMARY_STAT_NAME = {
        [1] = "力量",
        [2] = "敏捷", 
        [4] = "智力",
    },
}

-- ==========================================
-- 工具函数
-- ==========================================
local format = string.format
local UnitName = UnitName
local UnitStat = UnitStat
local UnitHealthMax = UnitHealthMax
local GetAverageItemLevel = GetAverageItemLevel
local GetCritChance = GetCritChance
local GetHaste = GetHaste
local GetMasteryEffect = GetMasteryEffect
local GetCombatRatingBonus = GetCombatRatingBonus
local GetVersatilityBonus = GetVersatilityBonus
local C_PlayerInfo_GetPlayerMythicPlusRatingSummary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary
local SendChatMessage = SendChatMessage
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsInGuild = IsInGuild
local IsInGroup_Instance = IsInGroup
local GetChannelName = GetChannelName
local UnitIsPlayer = UnitIsPlayer
local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE

-- 聊天编辑框相关局部化
local ChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow
local ChatEdit_ActivateChat = ChatEdit_ActivateChat
local ChatFrame_OpenChat = ChatFrame_OpenChat
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

local function Print(msg, color)
    color = color or "19CCF9"
    print("|TInterface/AddOns/LNuiChat/Media/Emotion/laonong:20|t|cff" .. color .. "[老农聊天条]:|r " .. msg)
end

local function FormatNum(num)
    if not num then return "0" end
    return format("%.1f", num)
end

local function FormatInt(num)
    if not num then return "0" end
    return format("%.0f", num)
end

-- 缓存主属性索引，避免每次调用时查表
local cachedPrimaryIndex = nil
local function GetPrimaryStatIndex()
    if cachedPrimaryIndex then return cachedPrimaryIndex end
    cachedPrimaryIndex = STATS_CONFIG.PRIMARY_STAT_INDEX[classFile] or 1
    return cachedPrimaryIndex
end

local function GetItemLevel()
    local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
    return FormatNum(avgItemLevelEquipped or avgItemLevel or 0)
end

local function GetMythicPlusScore()
    if C_PlayerInfo_GetPlayerMythicPlusRatingSummary then
        local summary = C_PlayerInfo_GetPlayerMythicPlusRatingSummary("player")
        if summary and summary.currentSeasonScore then
            return FormatInt(summary.currentSeasonScore)
        end
    end
    return "0"
end

local function GetHealth()
    return FormatInt(UnitHealthMax("player") or 0)
end

-- ==========================================
-- 返回值：base, stat, posBuff, negBuff
-- stat 是当前总属性值（已含正负buff），无需重复叠加
-- ==========================================
local function GetPrimaryStat()
    local statIndex = GetPrimaryStatIndex()
    local statName = STATS_CONFIG.PRIMARY_STAT_NAME[statIndex] or "力量"
    local base, stat, posBuff, negBuff = UnitStat("player", statIndex)
    -- stat 已经是包含buff后的当前总值
    local total = stat or 0
    return statName, FormatInt(total)
end

local function GetStamina()
    local base, stat, posBuff, negBuff = UnitStat("player", 3)
    -- stat 已经是包含buff后的当前总值
    local total = stat or 0
    return FormatInt(total)
end

-- ==========================================
-- GetCombatRatingBonus 返回的是战斗等级加成，不是面板显示百分比
-- 正式服应使用 GetCritChance / GetHaste / GetMasteryEffect / GetVersatilityBonus
-- ==========================================
local cachedSecondaryStats = nil
local cachedSecondaryTime = 0
local SECONDARY_CACHE_TTL = 0.5  -- 500ms缓存

local function GetSecondaryStats()
    local now = GetTime()
    if cachedSecondaryStats and (now - cachedSecondaryTime) < SECONDARY_CACHE_TTL then
        return cachedSecondaryStats
    end

    local crit = GetCritChance() or 0
    local haste = GetHaste() or 0
    local mastery = select(1, GetMasteryEffect()) or 0
    local versa = (GetCombatRatingBonus(29) or 0) + (GetVersatilityBonus(29) or 0)

    cachedSecondaryStats = {
        crit    = FormatInt(crit),
        haste   = FormatInt(haste),
        mastery = FormatInt(mastery),
        versa   = FormatInt(versa),
    }
    cachedSecondaryTime = now
    return cachedSecondaryStats
end

-- ==========================================
-- 构建通报字符串
-- ==========================================

local reportBuilder = {}

local function BuildStatsReport()
    local itemLevel = GetItemLevel()
    local mplusScore = GetMythicPlusScore()
    local health = GetHealth()
    local primaryName, primaryValue = GetPrimaryStat()
    local stamina = GetStamina()
    local secondary = GetSecondaryStats()

    -- 使用table.concat替代多次字符串拼接，大幅减少GC压力
    reportBuilder[1] = UnitName("player")
    reportBuilder[2] = "：装等"
    reportBuilder[3] = itemLevel
    reportBuilder[4] = " / 史诗钥石评分"
    reportBuilder[5] = mplusScore
    reportBuilder[6] = " / 血量"
    reportBuilder[7] = health
    reportBuilder[8] = " / "
    reportBuilder[9] = primaryName
    reportBuilder[10] = primaryValue
    reportBuilder[11] = " / 耐力"
    reportBuilder[12] = stamina
    reportBuilder[13] = " / 暴击"
    reportBuilder[14] = secondary.crit
    reportBuilder[15] = "% / 急速"
    reportBuilder[16] = secondary.haste
    reportBuilder[17] = "% / 精通"
    reportBuilder[18] = secondary.mastery
    reportBuilder[19] = "% / 全能"
    reportBuilder[20] = secondary.versa
    reportBuilder[21] = "%"

    return table.concat(reportBuilder, "", 1, 21)
end

-- ==========================================
-- 插入到当前聊天输入框（不直接发送）
-- ==========================================
local function InsertToCurrentChat()
    local report = BuildStatsReport()
    if not report or report == "" then
        Print("属性获取失败，请重试！", "ff0000")
        return
    end

    -- 安全检查
    if report:find(string.char(124), 1, true) then
        Print("通报内容包含非法字符，已取消插入！", "ff0000")
        return
    end

    -- 获取当前活跃的聊天编辑框
    local editBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if not editBox and DEFAULT_CHAT_FRAME then
        editBox = DEFAULT_CHAT_FRAME.editBox
    end

    if editBox and editBox:IsVisible() then
        -- 已有输入框打开，保留当前频道设置，追加内容
        local currentText = editBox:GetText() or ""
        if currentText ~= "" and currentText:sub(-1) ~= " " then
            currentText = currentText .. " "
        end
        local newText = currentText .. report
        editBox:SetText(newText)
        editBox:SetCursorPosition(#newText)
        pcall(function()
            editBox:SetFocus()
            if ChatEdit_ActivateChat then ChatEdit_ActivateChat(editBox) end
        end)
    else
        -- 没有打开的输入框，打开默认聊天编辑框并填入内容
        ChatFrame_OpenChat(report)
    end
end

-- ==========================================
-- 发送通报
-- ==========================================

local function SendStatsReport(channel)
    local report = BuildStatsReport()
    if not report or report == "" then
        Print("属性获取失败，请重试！", "ff0000")
        return
    end

    -- 安全检查
    if report:find(string.char(124), 1, true) then
        Print("通报内容包含非法字符，已取消发送！", "ff0000")
        return
    end

    if channel == "SAY" then
        SendChatMessage(report, "SAY")
    elseif channel == "PARTY" then
        if IsInGroup() then SendChatMessage(report, "PARTY")
        else Print("不在队伍中！", "ff0000"); return end
    elseif channel == "RAID" then
        if IsInRaid() then SendChatMessage(report, "RAID")
        else Print("不在团队中！", "ff0000"); return end
    elseif channel == "GUILD" then
        if IsInGuild() then SendChatMessage(report, "GUILD")
        else Print("不在公会中！", "ff0000"); return end
    elseif channel == "INSTANCE" then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then SendChatMessage(report, "INSTANCE_CHAT")
        else Print("不在副本队伍中！", "ff0000"); return end
    elseif channel == "WHISPER" then
        local target = UnitName("target")
        if target and UnitIsPlayer("target") then
            SendChatMessage(report, "WHISPER", nil, target)
        else Print("请先选中一个玩家目标！", "ff0000"); return end
    elseif channel == "CHANNEL" then
        local channelNum = GetChannelName("大脚世界频道")
        if channelNum and channelNum > 0 then
            SendChatMessage(report, "CHANNEL", nil, channelNum)
        else Print("未加入大脚世界频道！", "ff0000"); return end
    else
        SendChatMessage(report, "SAY")
    end
end

-- ==========================================
-- 外部接口（供 ChannelBar 调用）
-- ==========================================

_G.LNuiChat_StatsReport = {
    Report = function(channel)
        SendStatsReport(channel or "SAY")
    end,
    GetReportString = function()
        return BuildStatsReport()
    end,
    InsertToCurrentChat = function()
        InsertToCurrentChat()
    end,
}