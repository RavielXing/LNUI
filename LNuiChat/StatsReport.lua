-- ==========================================
-- 功能：一键通报角色属性到聊天频道
-- ==========================================

local addonName = ...
local _, classFile = UnitClass("player")

-- 加载本地化模块
local L = _G.LNuiChat_L or {}
local locale = GetLocale()
local isZhTW = (locale == "zhTW")

-- 本地化辅助函数
local function GT(key)
    return L[key] or key
end

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
        [1] = isZhTW and "力量" or "力量",
        [2] = isZhTW and "敏捷" or "敏捷", 
        [4] = isZhTW and "智力" or "智力",
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
local GetSpecialization = GetSpecialization
local C_PlayerInfo_GetPlayerMythicPlusRatingSummary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary
local SendChatMessage = SendChatMessage
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsInGuild = IsInGuild
local IsInGroup_Instance = IsInGroup
local GetChannelName = GetChannelName
local UnitIsPlayer = UnitIsPlayer
local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE
local UnitAffectingCombat = UnitAffectingCombat
local C_ChallengeMode = C_ChallengeMode

-- 聊天编辑框相关局部化
local ChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow
local ChatEdit_ActivateChat = ChatEdit_ActivateChat
local ChatFrame_OpenChat = ChatFrame_OpenChat
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- 图标路径
local LNicon = L["icon"] or "|TInterface/AddOns/LNuiChat/Media/Emotion/laonong:20|t"

local function Print(msg, color)
    color = color or "19CCF9"
    print(LNicon .. "|cff" .. color .. "[" .. GT("addon_name") .. "]:|r " .. msg)
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
local function GetPrimaryStatIndex()
    local specIndex = GetSpecialization and GetSpecialization()
    if classFile == "MONK" then
        -- 1=酒仙(敏捷), 2=织雾(智力), 3=踏风(敏捷)
        return (specIndex == 2) and 4 or 2
    elseif classFile == "DRUID" then
        -- 1=平衡(智力), 2=野性(敏捷), 3=守护(敏捷), 4=恢复(智力)
        return (specIndex == 1 or specIndex == 4) and 4 or 2
    elseif classFile == "SHAMAN" then
        -- 1=元素(智力), 2=增强(敏捷), 3=恢复(智力)
        return (specIndex == 2) and 2 or 4
    elseif classFile == "PALADIN" then
        -- 1=神圣(智力), 2=防护(力量), 3=惩戒(力量)
        return (specIndex == 1) and 4 or 1
    else
        return STATS_CONFIG.PRIMARY_STAT_INDEX[classFile] or 1
    end
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
-- stat 是当前总属性值（已含正负buff），无需重复叠加
-- ==========================================
local function GetPrimaryStat()
    local statIndex = GetPrimaryStatIndex()
    local statName = STATS_CONFIG.PRIMARY_STAT_NAME[statIndex] or (isZhTW and "力量" or "力量")
    local base, stat, posBuff, negBuff = UnitStat("player", statIndex)
    local total = stat or 0
    return statName, FormatInt(total)
end

local function GetStamina()
    local base, stat, posBuff, negBuff = UnitStat("player", 3)
    local total = stat or 0
    return FormatInt(total)
end

-- ==========================================
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
-- 环境限制检查：战斗 + 大秘境
-- ==========================================
local function IsRestrictedEnvironment()
    if UnitAffectingCombat("player") then return true, GT("restricted_combat") end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return true, GT("restricted_mythic")
    end
    return false, nil
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

    -- 根据语言选择正确的术语
    local itemLevelLabel = isZhTW and GT("report_itemlevel") or GT("report_itemlevel")
    local mythicScoreLabel = isZhTW and GT("report_mythic_score") or GT("report_mythic_score")
    local healthLabel = isZhTW and GT("report_health") or GT("report_health")
    local staminaLabel = isZhTW and GT("stat_stamina") or GT("stat_stamina")
    local critLabel = isZhTW and GT("report_crit") or GT("report_crit")
    local hasteLabel = isZhTW and GT("report_haste") or GT("report_haste")
    local masteryLabel = isZhTW and GT("report_mastery") or GT("report_mastery")
    local versatilityLabel = isZhTW and GT("report_versatility") or GT("report_versatility")
    local percentSign = GT("report_percent")

    -- 使用table.concat替代多次字符串拼接，大幅减少GC压力
    reportBuilder[1] = UnitName("player")
    reportBuilder[2] = "：" .. itemLevelLabel
    reportBuilder[3] = itemLevel
    reportBuilder[4] = " / " .. mythicScoreLabel
    reportBuilder[5] = mplusScore
    reportBuilder[6] = " / " .. healthLabel
    reportBuilder[7] = health
    reportBuilder[8] = " / "
    reportBuilder[9] = primaryName
    reportBuilder[10] = primaryValue
    reportBuilder[11] = " / " .. staminaLabel
    reportBuilder[12] = stamina
    reportBuilder[13] = " / " .. critLabel
    reportBuilder[14] = secondary.crit
    reportBuilder[15] = percentSign .. " / " .. hasteLabel
    reportBuilder[16] = secondary.haste
    reportBuilder[17] = percentSign .. " / " .. masteryLabel
    reportBuilder[18] = secondary.mastery
    reportBuilder[19] = percentSign .. " / " .. versatilityLabel
    reportBuilder[20] = secondary.versa
    reportBuilder[21] = percentSign

    return table.concat(reportBuilder, "", 1, 21)
end

-- ==========================================
-- 插入到当前聊天输入框（不直接发送）
-- ==========================================
local function InsertToCurrentChat()
    -- 环境限制：战斗中或大秘境中无法安全获取属性数据
    local restricted, reason = IsRestrictedEnvironment()
    if restricted then
        Print(reason .. GT("restricted_action"), "ff0000")
        return
    end

    local report = BuildStatsReport()
    if not report or report == "" then
        Print(GT("get_stats_failed"), "ff0000")
        return
    end

    -- 安全检查
    if report:find(string.char(124), 1, true) then
        Print(GT("insert_invalid_chars"), "ff0000")
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
    -- 环境限制：战斗中或大秘境中无法安全获取属性数据
    local restricted, reason = IsRestrictedEnvironment()
    if restricted then
        Print(reason .. GT("restricted_action"), "ff0000")
        return
    end

    local report = BuildStatsReport()
    if not report or report == "" then
        Print(GT("get_stats_failed"), "ff0000")
        return
    end

    -- 安全检查
    if report:find(string.char(124), 1, true) then
        Print(GT("invalid_chars"), "ff0000")
        return
    end

    if channel == "SAY" then
        SendChatMessage(report, "SAY")
    elseif channel == "PARTY" then
        if IsInGroup() then SendChatMessage(report, "PARTY")
        else Print(GT("not_in_party"), "ff0000"); return end
    elseif channel == "RAID" then
        if IsInRaid() then SendChatMessage(report, "RAID")
        else Print(GT("not_in_raid"), "ff0000"); return end
    elseif channel == "GUILD" then
        if IsInGuild() then SendChatMessage(report, "GUILD")
        else Print(GT("not_in_guild"), "ff0000"); return end
    elseif channel == "INSTANCE" then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then SendChatMessage(report, "INSTANCE_CHAT")
        else Print(GT("not_in_instance_party"), "ff0000"); return end
    elseif channel == "WHISPER" then
        local target = UnitName("target")
        if target and UnitIsPlayer("target") then
            SendChatMessage(report, "WHISPER", nil, target)
        else Print(GT("select_target"), "ff0000"); return end
    elseif channel == "CHANNEL" then
        local worldChannelName = isZhTW and "大腳世界頻道" or "大脚世界频道"
        local channelNum = GetChannelName(worldChannelName)
        if channelNum and channelNum > 0 then
            SendChatMessage(report, "CHANNEL", nil, channelNum)
        else Print(GT("not_in_world_channel"), "ff0000"); return end
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
