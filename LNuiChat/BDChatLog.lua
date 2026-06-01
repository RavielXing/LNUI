-- 作者: LengKu  更新日期: 0527
-- 插件名称: BDChatlog 聊天日志
-- https://nga.178.com/read.php?tid=46478931
-- 内存优化版：限制缓存上限、弱引用战网缓存、抑制器键值裁剪、延迟队列上限、搜索分页、清理空表

local addonName = ...

-- ==========================================
-- 配置
-- ==========================================
local CL_Config = {
    OlderEntryCount     = 500,   -- 较早视图的日志条目数（原1000，降低以减少内存）
    RecentEntryCount    = 150,    -- 最近视图的日志条目数（原200，降低以减少内存）
    MaxTotalEntries     = 650,   -- 【新增】单窗口硬性总上限，超出直接丢弃旧数据

    EditBoxMinHeight    = 100, 

    LineSpacing         = 0,      -- 额外行间距，默认0。单位：像素
    ScrollLines         = 10,      -- 鼠标滚轮每次滚动的行数

    -- 【高优先级黑名单】指定不保存聊天记录的标签页名称
    IgnoredTabs = {
        --["大脚交易"] = true,
        ["战斗记录"] = true, ["战记"] = true, ["战斗"] = true, ["战"] = true,
    },

    -- 【角色切换器排序】定义角色顺序，不在列表里的角色按字节值排在末尾
    CharOrder = {
        --"角色A-服务器", "角色B-服务器",
    },
}


-- ==========================================
-- 第一部分：登陆初始化与会话分割
-- ==========================================

local frame = CreateFrame("Frame")
local preLoginMessages = {}
local sessionStarted = false

-- ── 分割线与登陆前消息缓冲 ──────────────────────────────
local function CL_AddSessionSeparator()
    if not frame.ownCharDB then return end

    local timestamp = date("%Y-%m-%d %H:%M:%S")
    local sepText   = "|cffA0A0A0------------------------ [ 登录会话: " .. timestamp .. " ] ------------------------|r"

    for i = 1, NUM_CHAT_WINDOWS do
        local tabName        = "ChatFrame" .. i
        local chatFrame      = _G[tabName]
        local tabLabel       = _G[tabName .. "Tab"]
        local tabDisplayName = chatFrame and chatFrame.name
        local isVisibleTab   = chatFrame and tabLabel and tabLabel:IsShown()

        if isVisibleTab and not (tabDisplayName and CL_Config.IgnoredTabs[tabDisplayName]) then
            frame.ownCharDB[tabName] = frame.ownCharDB[tabName] or {}
            local logData = frame.ownCharDB[tabName]

            -- 插入分隔线
            local lastMsg = logData[#logData]
            if lastMsg and lastMsg.isSeparator then
                lastMsg.t = sepText
            else
                table.insert(logData, { t=sepText, isSeparator=true })
            end

            -- 追加登录前缓冲的消息
            if preLoginMessages[tabName] and #preLoginMessages[tabName] > 0 then
                for _, msgData in ipairs(preLoginMessages[tabName]) do
                    msgData.t = "- " .. msgData.t
                    table.insert(logData, msgData)
                end
            end
        else
            local logData = frame.ownCharDB[tabName]
            if type(logData) == "table" and next(logData) == nil then
                frame.ownCharDB[tabName] = nil
            end
        end
        preLoginMessages[tabName] = nil
    end
    preLoginMessages = {}
end

-- ── PLAYER_LOGIN 事件处理 ──────────────────────────────
local CL_SaveDeferredQueue
local CL_RestoreDeferredQueue
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then

        -- 初始化全局存档表
        LNuiChatDB = LNuiChatDB or {}
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        LNuiChatDB[charKey] = LNuiChatDB[charKey] or {}

        self.ownCharDB    = LNuiChatDB[charKey]
        self.viewedCharDB = self.ownCharDB 

        -- 记录当前角色的标签页名称与数量
        self.ownCharDB["_tabs"] = {}
        for i = 1, NUM_CHAT_WINDOWS do
            local tabLabel = _G["ChatFrame" .. i .. "Tab"]
            if tabLabel and tabLabel:IsShown() then
                self.ownCharDB["_tabs"][i] = _G["ChatFrame" .. i].name or ("频道" .. i)
            end
        end

        -- 记录当前角色的职业标识
        local _, classTag = UnitClass("player")
        self.ownCharDB["_class"] = classTag

        CL_AddSessionSeparator()

        sessionStarted = true
        self:UnregisterEvent("PLAYER_LOGIN")

        CL_RestoreDeferredQueue()  

    elseif event == "PLAYER_LOGOUT" then   
        CL_SaveDeferredQueue()

        -- 【内存优化】登出时清理所有空日志表，释放无用键
        if self.ownCharDB then
            for k, v in pairs(self.ownCharDB) do
                if type(v) == "table" and #v == 0 and not k:match("^_") then
                    self.ownCharDB[k] = nil
                end
            end
        end
    end
end)


-- ==========================================
-- 第二部分：信息工具函数
-- ==========================================

-- ── 检测默认战斗记录标签页 ──────────────────────
local function CL_IsCombatLogFrame(chatWindow)
    return chatWindow == ChatFrame2
end

-- ── 战网好友名解析 ─────────────────────────────
local function CL_ResolveBNDisplayName(bnID)
    if not bnID then return nil end
    local ok1, bninfo = pcall(C_BattleNet.GetAccountInfoByID, bnID)
    if ok1 and bninfo and bninfo.battleTag then
        return bninfo.battleTag:match("^(.-)#") or bninfo.battleTag
    end
    return nil  
end

-- ── 写入战网昵称缓存 ─────────────────────────────
-- 【内存优化】使用弱值表，允许GC自动清理不常用条目
local BNNameCache = setmetatable({}, { __mode = "v" })
local function CL_SetBNNameCache(bnID, name)
    local count = 0
    local oldestKey, oldestTime = nil, math.huge
    for k, v in pairs(BNNameCache) do
        count = count + 1
        if (v.time or 0) < oldestTime then oldestKey, oldestTime = k, v.time end
    end
    if count >= 102 and oldestKey then BNNameCache[oldestKey] = nil end
    BNNameCache[bnID] = { name = name, time = GetTime() }
end

-- ── 超链接处理 ───────────────────────────────────
local function CL_GetHLinkType(link)
    if type(link) ~= "string" then return nil end
    local linkType = link:match("^([^:]+):")
    return linkType and linkType:lower() or nil
end

-- 允许保存的超链接类型
local CL_AllowedLogHLinks = {
    item = true, spell = true, quest = true, achievement = true, currency = true, 
    enchant = true, 
    unit = true, journal = true, 
    transmogappearance = true, transmogillusion = true, 
    talent = true, pvptal = true, talentbuild = true, 
    mount = true, mountequipment = true, battlepet = true, 
    keystone = true, instancelock = true, dungeonscore = true, pvprating = true, 
    garrmission = true, garrfollower = true, garrfollowerability = true,
    worldmap = true, 
    perksactivity = true, initiativetask = true,
    housingdecor = true, warbandscene = true,
}
-- 自制悬停提示的类型
local CL_TextHintHLinks = {
    journal = "点击查看冒险指南条目",
    transmogappearance = "点击查看外观",
    transmogillusion = "点击查看幻象",
    battlepet = "点击查看宠物信息",
    mountequipment = "点击查看坐骑装备",
    talentbuild = "点击查看天赋配置",
    dungeonscore = "点击查看史诗钥石评分",
    pvprating = "点击查看PvP评分",
    garrmission = "点击打开要塞任务",
    garrfollower = "点击查看追随者",
    garrfollowerability = "点击查看追随者技能",
    worldmap = "点击定位到地图位置",
    perksactivity = "点击查看旅行者日志活动",
    initiativetask = "点击查看住宅任务",
    housingdecor = "点击查看住宅装饰",
    warbandscene = "点击查看战团场景",
}
-- 拒绝受保护的 |K 内容
local function CL_IsAllowedLogHLinkType(link)
    if type(link) ~= "string" or link:find("|K", 1, true) then return false end
    local linkType = CL_GetHLinkType(link)
    return linkType and CL_AllowedLogHLinks[linkType] or false
end
-- 清洗链接：白名单保留完整原始链接，其余链接只留下显示文字
local function CL_StripUnsafeHLinks(text)
    text = text:gsub("(|H([^|]-)|h(.-)|h)", function(full, link, label)
        if CL_IsAllowedLogHLinkType(link) and not tostring(full):find("|K", 1, true) then
            return full
        end
        return label
    end)
    -- 清理截断或残留的坏 |H 片段，避免 EditBox 解析异常
    return text:gsub("|H[^|]*$", "")
end

local function CL_InlineIconToText(tag)
    local key = tostring(tag or ""):lower()
    if key:find("ui%-goldicon") or key:find("gold") then return "|cffffd700金|r" end
    if key:find("ui%-silvericon") or key:find("silver") then return "|cffcccccc银|r" end
    if key:find("ui%-coppericon") or key:find("copper") then return "|cffd98a50铜|r" end
    return ""
end

-- ── 净化消息文本 ─────────────────────────────
-- 【内存优化】合并处理步骤，减少中间字符串副本
local function CL_SanitizeMessage(text)
    if not text then return nil end

    if type(issecretvalue) == "function" then
        local ok, sec = pcall(issecretvalue, text)
        if not ok then return nil end
        if sec then return "[??]" end
    end
    if type(text) ~= "string" then return nil end

    -- 还原战网隐藏名
    if text:find("|K.-|k") then
        local isBNMessage = text:find("|HBNplayer") ~= nil

        if isBNMessage then
            local resolvedName = nil
            -- 从原生战网链接中提取真正的 bnetAccountID
            local realBnIDStr = text:match("|HBNplayer:[^:]+:(%d+)")
            local realBnID = tonumber(realBnIDStr)
            if realBnID and BNNameCache[realBnID] then
                resolvedName = BNNameCache[realBnID].name
            elseif realBnID then
                resolvedName = CL_ResolveBNDisplayName(realBnID)
                if resolvedName then
                    CL_SetBNNameCache(realBnID, resolvedName)
                end
            end
            text = text:gsub("|K.-|k", resolvedName or "战网好友")
            text = text:gsub("|HBNplayer.-|h(.-)|h", "%1")
        else
            -- 非 BN 私聊消息（战斗记录等）中的 |K...|k 是其他受保护内容，统一替换为 [?]
            -- （超链接）若受保护标记混在链接里，只剥该链接为显示文字，避免保留隐藏/保护链接
            text = text:gsub("|H([^|]-)|h(.-)|h", function(link, label)
                if link:find("|K", 1, true) or label:find("|K", 1, true) then
                    return label
                end
                return "|H" .. link .. "|h" .. label .. "|h"
            end)
            text = text:gsub("|K.-|k", "[?]")
        end
    end

    -- 替换被暴雪屏蔽的消息
    if text:find("censoredmessage:") then
        text = text:gsub("|Hcensoredmessage:.-|h.-|h", "[内容被和谐]")
    end

    if text:find("|", 1, true) then
        -- （超链接）只保留安全游戏链接，其余链接退回显示文字
        text = CL_StripUnsafeHLinks(text)
        -- 移除纹理 / 图标 / atlas 标签；（特定图标转文字）
        text = text:gsub("|T(.-)|t", CL_InlineIconToText)
        text = text:gsub("|A(.-)|a", CL_InlineIconToText)
    end

    return text
end

-- ── 裁剪日志数量 ─────────────────────────────
-- 【内存优化】使用硬性总上限，更积极地丢弃旧数据
local function CL_TrimLogData(logData)
    local maxEntries = CL_Config.MaxTotalEntries
    if #logData > maxEntries + 50 then
        local excess = #logData - maxEntries
        for i = 1, #logData - excess do
            logData[i] = logData[i + excess]
        end
        for i = #logData - excess + 1, #logData do
            logData[i] = nil
        end
    end
end

-- 返回指定日志视图在日志数组中的起止索引，空视图返回 1, 0。
local function CL_GetLogViewRange(totalEntries, view)
    totalEntries = tonumber(totalEntries) or 0
    if totalEntries <= 0 then return 1, 0 end

    local maxEntries = CL_Config.OlderEntryCount + CL_Config.RecentEntryCount
    local recentCount = totalEntries > maxEntries and (totalEntries - CL_Config.OlderEntryCount) or CL_Config.RecentEntryCount

    if view == "older" then
        local endIdx = totalEntries - recentCount
        if endIdx <= 0 then return 1, 0 end
        return 1, endIdx
    end

    local startIdx = math.max(1, totalEntries - recentCount + 1)
    return startIdx, totalEntries
end

-- 新消息写入后只刷新当前打开的主日志视图。
local function CL_RefreshOpenLogViewAfterAppend(tabName, logData)
    local mainFrame = BDCL_MainFrame
    if not (mainFrame and mainFrame:IsShown() and mainFrame.currentTab == tabName) then return end
    if frame.viewedCharDB ~= frame.ownCharDB then return end

    mainFrame.totalEntries = #logData
    mainFrame.currentView = mainFrame.currentView or "recent"
    if mainFrame.searchResults or mainFrame.currentView ~= "recent" then
        if mainFrame.UpdateViewLabel then mainFrame.UpdateViewLabel() end
        if mainFrame.UpdateLogViewButtons then mainFrame.UpdateLogViewButtons() end
        return
    end

    local sf = mainFrame.ScrollFrame
    local eb = mainFrame.EditBox
    local sb = mainFrame.ScrollBar
    if not (sf and eb and sb) then
        if mainFrame.UpdateViewLabel then mainFrame.UpdateViewLabel() end
        if mainFrame.UpdateLogViewButtons then mainFrame.UpdateLogViewButtons() end
        return
    end

    local maxOffset = math.max(0, eb:GetHeight() - sf:GetHeight())
    local isNearBottom = (maxOffset - sf:GetVerticalScroll()) <= 32
    mainFrame.RenderLog(tabName, isNearBottom and "bottom" or "preserve")
end



-- ==========================================
-- 第三部分：正常消息处理
-- ==========================================

-- ── 剥离消息开头的时间戳 ─────────────────────
local function CL_StripTimestamp(text)
    if not text then return text end
    text = text:gsub("^|c%x%x%x%x%x%x%x%x%[?%d+:%d+[:%d]*%]?|r%s*", "")
    text = text:gsub("^%[?%d+:%d+[:%d]*%s*[AP]?M?%]?%s*", "")
    return text:gsub("^%s+", "")
end

-- ── 移除文本颜色码 ──────────────────────────
local function CL_ColorlessText(text)
    text = tostring(text or "")
    if not text:find("|", 1, true) then return text end
    -- （超链接）关键词过滤/搜索只按链接显示文字匹配，不按 |H 控制结构匹配
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|H[^|]+", "")
    text = text:gsub("|K.-|k", "")

    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|cn[%w_]+:", "")
    text = text:gsub("|r", "")
    return text
end

-- ── 重复消息抑制使用显示文本做 key，避免 player: 链接内 lineID 变化导致失效 ─────────────
local function CL_GetSuppressKey(text)
    local key = CL_ColorlessText(text):gsub("%s+", " ")
    key = key:gsub("^%s+", ""):gsub("%s+$", "")
    return key ~= "" and key or tostring(text or "")
end

-- ── 解析关键词过滤列表 ───────────────────────
local function CL_CollectFilterKeywords(raw)
    raw = tostring(raw or ""):gsub("；", ";")
    local list = {}
    local seen = {}

    for word in raw:gmatch("[^;]+") do
        word = word:gsub("^%s+", ""):gsub("%s+$", "")
        if word ~= "" then
            local key = word:lower()
            if not seen[key] then
                seen[key] = true
                table.insert(list, word)
            end
        end
    end

    return list
end

-- ── 规范化关键词过滤文本 ─────────────────────
local function CL_NormalizeKeywordFilterText(raw)
    local list = CL_CollectFilterKeywords(raw)
    if #list == 0 then return "" end
    return table.concat(list, ";") .. ";"
end

-- ── 读取存档关键词过滤文本 ───────────────────
local function CL_GetKeywordFilterSaveText()
    return (LNuiChatDB and LNuiChatDB.KeywordFilterSaveText) or ""
end

-- ── 关键词缓存 ─────────────────────────────
local CL_filterCache = { save = { raw = nil, list = {} } }
local function CL_GetFilterListCached(slot, rawText)
    local c = CL_filterCache[slot]
    if c.raw ~= rawText then
        c.raw  = rawText
        c.list = CL_CollectFilterKeywords(rawText)
    end
    return c.list
end

-- ── 判断消息是否命中关键词组 ───────────────────
local function CL_MessageMatchesKeywords(text, list)
    if #list == 0 then return false end
    local plain = CL_ColorlessText(text):lower()
    for _, word in ipairs(list) do
        if plain:find(word:lower(), 1, true) then return true end
    end
    return false
end

-- ── 保存关键词过滤文本 ─────────────────────────
local function CL_SaveKeywordFilterText(key, raw)
    LNuiChatDB = LNuiChatDB or {}
    local normalized = CL_NormalizeKeywordFilterText(raw)
    LNuiChatDB[key] = normalized
    return normalized
end

-- 【内存优化】抑制器状态：限制每个窗口保留的键数量，防止长文本键无限累积
local suppressMsgState = {}
local suppressStatePool = {}
local CL_lockdownLastSeenAt
local CL_lockdownNoticeNeedsNormal
local CL_LOCKDOWN_NOTICE = "|cffff9900[BDChatLog]|r：|cffffff00当前环境暂时限制了信息获取，受限解除后将尝试恢复 密语/队团/公会 等聊天内容。|r"
local CL_RecordLockdownNotice
local CL_ResetLockdownNoticeIfReady

-- ── 聊天发送锁定检测：锁定期间不要触碰原生超链接文本，避免污染 SendChatMessage ─────────────
local function CL_IsChatMessagingLocked()
    return C_ChatInfo
        and C_ChatInfo.InChatMessagingLockdown
        and C_ChatInfo.InChatMessagingLockdown()
        or false
end

local function CL_IsHLinkClickRestricted()
    if CL_IsChatMessagingLocked() then return true end
    return IsEncounterInProgress and IsEncounterInProgress() or false
end

-- ── 正常聊天消息捕获与写入 ──────────────────────
for i = 1, NUM_CHAT_WINDOWS do
    local chatFrame = _G["ChatFrame" .. i]
    if chatFrame then
        hooksecurefunc(chatFrame, "AddMessage", function(self, text, r, g, b)
            local tabDisplayName = self.name or GetChatWindowInfo(self:GetID())
            local inLockdown = CL_IsChatMessagingLocked()
            local isIgnored = (tabDisplayName and CL_Config.IgnoredTabs[tabDisplayName]) or CL_IsCombatLogFrame(self)

            if inLockdown and not isIgnored then
                if CL_RecordLockdownNotice then
                    CL_RecordLockdownNotice()
                end
            end

            -- 黑名单 + 战斗记录过滤
            if isIgnored then
                return
            end

            if inLockdown and type(issecretvalue) == "function" then
                local ok, secret = pcall(issecretvalue, text)
                if not ok or secret then return end
            end

            if not inLockdown and CL_ResetLockdownNoticeIfReady then
                CL_ResetLockdownNoticeIfReady()
            end

            -- 净化消息文本
            text = CL_SanitizeMessage(text)
            if not text or text == "" then return end

            -- 重建时间戳前缀 (仅用于剔除原生前缀，不再拼接死在正文里)
            text = CL_StripTimestamp(text)
            local tabName  = "ChatFrame" .. i

            -- 短时间相同消息存档刷屏抑制
            local now = GetTime()
            local suppressWindow = 10
            suppressMsgState[tabName] = suppressMsgState[tabName] or {}
            local tabState = suppressMsgState[tabName]
            local suppressKey = CL_GetSuppressKey(text)

            -- 【内存优化】清理过期条目，并限制每个窗口最多保留30条抑制记录
            local stateCount = 0
            local oldestMsg, oldestTime = nil, math.huge
            for msg, st in pairs(tabState) do
                stateCount = stateCount + 1
                if now - (st.lastTime or 0) > suppressWindow then
                    tabState[msg] = nil
                    st.count = nil
                    st.lastTime = nil
                    if #suppressStatePool < 100 then
                        suppressStatePool[#suppressStatePool + 1] = st
                    end
                elseif (st.lastTime or 0) < oldestTime then
                    oldestMsg, oldestTime = msg, st.lastTime
                end
            end
            if stateCount > 30 and oldestMsg then
                tabState[oldestMsg] = nil
            end

            local state = tabState[suppressKey]

            if state and now - (state.lastTime or 0) <= suppressWindow then
                state.count = state.count + 1
                state.lastTime = now
            else
                state = suppressStatePool[#suppressStatePool]
                if state then
                    suppressStatePool[#suppressStatePool] = nil
                else
                    state = {}
                end

                state.count = 1
                state.lastTime = now
                tabState[suppressKey] = state
            end

            if state.count > 4 then
                return
            elseif state.count == 4 then
                text = "|cffff9900[BDChatLog]|r：|cffffff00检测到短时间内多条相同信息，已自动抑制后续重复|r" .. text ..
                "|cffffff00，防止存档刷屏。|r"
            end

            -- 关键词过滤
            if CL_MessageMatchesKeywords(text, CL_GetFilterListCached("save", CL_GetKeywordFilterSaveText())) then return end

            -- 构建消息条目 (仅存纯文本，时间戳用 ts 分离存储)
            local msgEntry = {
                t  = text,
                c  = math.floor((r or 1)*255+0.5)*65536 + math.floor((g or 1)*255+0.5)*256 + math.floor((b or 1)*255+0.5),
                ts = time(),
            }

            if not sessionStarted then
                preLoginMessages[tabName] = preLoginMessages[tabName] or {}
                table.insert(preLoginMessages[tabName], msgEntry)
            else
                if not frame.ownCharDB then return end
                frame.ownCharDB[tabName] = frame.ownCharDB[tabName] or {}
                local logData = frame.ownCharDB[tabName]

                table.insert(logData, msgEntry)
                CL_TrimLogData(logData)
                CL_RefreshOpenLogViewAfterAppend(tabName, logData)
            end
        end)
    end
end

-- ==========================================
-- 第四部分：延迟消息获取
-- ==========================================

local CL_deferQueue, CL_deferHead, CL_deferTail = {}, 1, 0   -- 待处理的延迟消息队列
local CL_deferPollActive = false
-- 【内存优化】延迟队列硬性上限，防止锁定期间无限堆积
local CL_DEFER_MAX_QUEUE = 100

local function CL_DeferQueueIsEmpty()
    return CL_deferHead > CL_deferTail
end

local function CL_DeferQueuePush(item)
    -- 超出上限时丢弃最旧的消息
    while CL_deferTail - CL_deferHead >= CL_DEFER_MAX_QUEUE do
        CL_deferQueue[CL_deferHead] = nil
        CL_deferHead = CL_deferHead + 1
    end
    CL_deferTail = CL_deferTail + 1
    CL_deferQueue[CL_deferTail] = item
end

local function CL_DeferQueuePop()
    if CL_DeferQueueIsEmpty() then return nil end
    local item = CL_deferQueue[CL_deferHead]
    CL_deferQueue[CL_deferHead] = nil
    CL_deferHead = CL_deferHead + 1
    if CL_DeferQueueIsEmpty() then
        CL_deferQueue, CL_deferHead, CL_deferTail = {}, 1, 0
    end
    return item
end

-- ── 简化玩家名字 ────────────────────────────
local function CL_SafeAmbiguate(name)
    if not Ambiguate then return name end
    local ok, result = pcall(Ambiguate, name, "none")
    return (ok and type(result) == "string" and result ~= "") and result or name
end

-- ── 捕获聊天行 lineID ────────────────────────────
local function CL_CaptureLineID(...)
    local lineID = select(11, ...)
    if type(lineID) == "number" and lineID > 0 then
        return lineID
    end
end

-- ── 判断单个值是否受保护 ───────────────────────────
local function CL_IsSecretValue(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret or false
end

-- ── 获取事件对应的聊天标签页 ────────────────────────
local function CL_TabNamesForEvent(event)
    local tabs = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame and chatFrame:IsEventRegistered(event) then
            local tabName        = "ChatFrame" .. i
            local tabDisplayName = chatFrame.name or GetChatWindowInfo(chatFrame:GetID())
            if not (tabDisplayName and CL_Config.IgnoredTabs[tabDisplayName])
                and not CL_IsCombatLogFrame(chatFrame)
            then
                table.insert(tabs, tabName)
            end
        end
    end
    if #tabs == 0 then
        table.insert(tabs, "ChatFrame1")
    end
    return tabs
end

-- ── 锁定期间只写固定提示，不触碰原始聊天超链接文本 ───────────────────────
CL_RecordLockdownNotice = function()
    if not frame.ownCharDB then return end
    local now = time()
    local tabName = "ChatFrame1"

    CL_lockdownLastSeenAt = now
    if CL_lockdownNoticeNeedsNormal then return end

    CL_lockdownNoticeNeedsNormal = true
    frame.ownCharDB[tabName] = frame.ownCharDB[tabName] or {}
    local logData = frame.ownCharDB[tabName]
    table.insert(logData, {
        t          = CL_LOCKDOWN_NOTICE,
        ts         = now,
        preColored = true,
    })
    CL_TrimLogData(logData)

    CL_RefreshOpenLogViewAfterAppend(tabName, logData)
end

CL_ResetLockdownNoticeIfReady = function()
    if CL_lockdownNoticeNeedsNormal
        and CL_lockdownLastSeenAt
        and time() - CL_lockdownLastSeenAt >= 300
    then
        CL_lockdownNoticeNeedsNormal = nil
    end
end

-- ── 安全读取聊天行正文 ─────────────────────────────
local function CL_GetChatLineText(lineID)
    if not (C_ChatInfo and C_ChatInfo.GetChatLineText) then return nil end
    local ok, text = pcall(C_ChatInfo.GetChatLineText, lineID)
    if not ok or type(text) ~= "string" or text == "" then return nil end
    if CL_IsSecretValue(text) then return nil end
    return text
end

-- ── 安全读取聊天行发送者名称 ────────────────────────
local function CL_GetChatLineSenderName(lineID)
    if not (C_ChatInfo and C_ChatInfo.GetChatLineSenderName) then return nil end
    local ok, sender = pcall(C_ChatInfo.GetChatLineSenderName, lineID)
    if not ok or type(sender) ~= "string" or sender == "" then return nil end
    if CL_IsSecretValue(sender) then return nil end
    return CL_SafeAmbiguate(sender)
end

-- ── 安全读取聊天行发送者 GUID ───────────────────────
local function CL_GetChatLineSenderGUID(lineID)
    if not (C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID) then return nil end
    local ok, guid = pcall(C_ChatInfo.GetChatLineSenderGUID, lineID)
    if ok and type(guid) == "string" and guid ~= "" then
        return guid
    end
end

-- ── 按名字反查队伍成员职业 ───────────────────────────
local function CL_GetClassFileByName(name)
    if not name or name == "" then return nil end
    local shortName = CL_SafeAmbiguate(name)   
    if UnitName("player") == shortName then
        local _, classFile = UnitClass("player")
        return classFile
    end
    local count  = GetNumGroupMembers()
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, count do
        local unit = prefix .. i
        if UnitName(unit) == shortName then     -- 用 shortName 比
            local _, classFile = UnitClass(unit)
            return classFile
        end
    end
end

-- ── 为发送者名称附加职业颜色 ─────────────────────────────
local function CL_ClassColorNameByLineID(name, lineID)
    if type(name) ~= "string" or name == "" then return name end
    -- 优先 lineID → GUID → GetPlayerInfoByGUID，失败时按队伍 unit 名字匹配
    local classFile
    local guid = CL_GetChatLineSenderGUID(lineID)
    if guid then
        local dummy, cf = GetPlayerInfoByGUID(guid)
        classFile = cf
    end
    if not classFile then
        classFile = CL_GetClassFileByName(name)
    end
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not c then return name end
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
end

-- ── 提取 BNplayer 链接中的战网 ID ────────────────────────
local function CL_ExtractBNIDFromText(text)
    if type(text) ~= "string" then return nil end
    local id = tonumber(text:match("|HBNplayer:[^:]+:(%d+)"))
    if id and id > 0 then return id end
end

-- ── 通过发送者名称反查战网账号 ID ──────────────────────────
local function CL_ResolveBnetAccountIdFromSender(sender)
    if type(sender) ~= "string" or sender == "" then return nil end
    if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends) then return nil end
    local target = CL_SafeAmbiguate(sender)
    for i = 1, BNGetNumFriends() do
        local ok, info = pcall(C_BattleNet.GetFriendAccountInfo, i)
        if ok and info and info.bnetAccountID then
            local id = info.bnetAccountID
            if info.accountName == target then return id end
            if info.battleTag   == target then return id end
            local charName = info.gameAccountInfo and info.gameAccountInfo.characterName
            if charName then
                local resolvedChar = CL_SafeAmbiguate(charName)
                if resolvedChar == target then return id end
            end
        end
    end
end

-- ── 恢复 BN 密语真实发送者昵称 ─────────────────────────────
local function CL_ResolveDeferredBNName(lineID, text)
    local sender = CL_GetChatLineSenderName(lineID)
    -- 依次尝试：文本内 BNplayer 链接 → sender 名反查 → 缓存 → 实时查询
    local bnID = CL_ExtractBNIDFromText(text)
    if not bnID and sender then
        bnID = CL_ResolveBnetAccountIdFromSender(sender)
    end
    if bnID then
        if BNNameCache[bnID] and BNNameCache[bnID].name then
            return BNNameCache[bnID].name
        end
        local name = CL_ResolveBNDisplayName(bnID)
        if name then
            CL_SetBNNameCache(bnID, name)
            return name
        end
    end
    return (sender and sender ~= "") and sender or "战网好友"
end

-- ── 转换 RGB 为 WoW 颜色码 ──────────────────────
local function CL_RGBToHex(r, g, b)
    r = math.floor((tonumber(r) or 1) * 255 + 0.5)
    g = math.floor((tonumber(g) or 1) * 255 + 0.5)
    b = math.floor((tonumber(b) or 1) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

-- ── 事件频道颜色映射 ─────────────────────────────
local CL_EventColorKey = {
    CHAT_MSG_BN_WHISPER           = "BN_WHISPER",
    CHAT_MSG_BN_WHISPER_INFORM    = "BN_WHISPER_INFORM",
    CHAT_MSG_WHISPER              = "WHISPER",
    CHAT_MSG_WHISPER_INFORM       = "WHISPER_INFORM",
    CHAT_MSG_PARTY                = "PARTY",
    CHAT_MSG_PARTY_LEADER         = "PARTY_LEADER",
    CHAT_MSG_RAID                 = "RAID",
    CHAT_MSG_RAID_LEADER          = "RAID_LEADER",
    CHAT_MSG_INSTANCE_CHAT        = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT_LEADER",
    CHAT_MSG_GUILD                = "GUILD",
}

-- ── 获取事件频道颜色 ─────────────────────────────
local function CL_GetColorForEvent(event)
    local key = CL_EventColorKey[event]
    local c   = key and ChatTypeInfo and ChatTypeInfo[key]
    if c then return c.r or 1, c.g or 1, c.b or 1 end
    return 1, 1, 1
end

-- ── 延迟消息前缀模板 ─────────────────────────────
local CL_EventPrefixTemplate = {
    CHAT_MSG_WHISPER_INFORM       = "**发送给[%s]：|r",
    CHAT_MSG_BN_WHISPER_INFORM    = "**发送给[%s]：|r",
    CHAT_MSG_WHISPER              = "**[%s]悄悄地说：|r",
    CHAT_MSG_BN_WHISPER           = "**[%s]悄悄地说：|r",
    CHAT_MSG_PARTY                = "**[小队] [%s]：|r",
    CHAT_MSG_PARTY_LEADER         = "**[队长] [%s]：|r",
    CHAT_MSG_RAID                 = "**[团队] [%s]：|r",
    CHAT_MSG_RAID_LEADER          = "**[团队领袖] [%s]：|r",
    CHAT_MSG_INSTANCE_CHAT        = "**[副本] [%s]：|r",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "**[副本向导] [%s]：|r",
    CHAT_MSG_GUILD                = "**[公会] [%s]：|r",
}

-- ── 拼装延迟消息前缀 ─────────────────────────────
local function CL_GetPrefixForDeferredEvent(event, sender, prefixColor)
    local tpl = CL_EventPrefixTemplate[event]
    if tpl then
        return prefixColor .. string.format(tpl, sender .. prefixColor)
    end
    return prefixColor .. "[" .. sender .. prefixColor .. "]：|r"
end

-- ── 回查并写入单条延迟消息 ─────────────────────────────
local function CL_FlushDeferredItem(item)
    if not item then return end

    local event   = item.event
    local rawText = CL_GetChatLineText(item.lineID)
    if not rawText or rawText == "" then return end

    local text = CL_SanitizeMessage(rawText)
    if not text or text == "" then return end

    -- 解析发送者：BN 密语走昵称恢复，其余走 lineID 反查并染职业色
    local sender
    if event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM" then
        sender = CL_ResolveDeferredBNName(item.lineID, rawText)
    else
        local senderName = CL_GetChatLineSenderName(item.lineID) or "?"
        sender = CL_ClassColorNameByLineID(senderName, item.lineID)
    end

    local r, g, b = CL_GetColorForEvent(event)
    local prefixColor = CL_RGBToHex(r, g, b)
    local prefix = CL_GetPrefixForDeferredEvent(event, sender, prefixColor)
    local msgTime = tonumber(item.time) or time()

    local finalText = prefix .. prefixColor .. text .. "|r"

    -- tabNames 由入队时已确定；兜底取 item.tabName 或默认帧
    local tabNames = item.tabNames
    if type(tabNames) ~= "table" or #tabNames == 0 then
        tabNames = { item.tabName or "ChatFrame1" }
    end

    if not frame.ownCharDB then return end

    for _, tabName in ipairs(tabNames) do
        frame.ownCharDB[tabName] = frame.ownCharDB[tabName] or {}
        local logData = frame.ownCharDB[tabName]

        local msgEntry = {
            t          = finalText,
            ts         = msgTime,
            preColored = true,
        }

        table.insert(logData, msgEntry)
        CL_TrimLogData(logData)

        CL_RefreshOpenLogViewAfterAppend(tabName, logData)

    end
end

-- ── 轮询延迟消息队列 ─────────────────────────────
local function CL_DeferPump()
    if CL_DeferQueueIsEmpty() then
        CL_deferPollActive = false
        return
    end
    if CL_IsChatMessagingLocked() then
        if not CL_deferPollActive then
            CL_deferPollActive = true
            C_Timer.After(0.3, function()
                CL_deferPollActive = false
                CL_DeferPump()
            end)
        end
        return
    end
    -- lockdown 已解除：处理队首一条，剩余在下一帧继续
    CL_deferPollActive = false
    local item = CL_DeferQueuePop()
    if item then CL_FlushDeferredItem(item) end
    if not CL_DeferQueueIsEmpty() then C_Timer.After(0, CL_DeferPump) end
end

-- ── 保存延迟消息队列 ─────────────────────────────
CL_SaveDeferredQueue = function()
    LNuiChatDB = LNuiChatDB or {}
    if CL_DeferQueueIsEmpty() then
        LNuiChatDB.pendingDeferred = nil
        return
    end
    -- 【内存优化】保存前只保留最近的50条，避免存档过大
    local pending = {}
    local startIdx = math.max(CL_deferHead, CL_deferTail - 49)
    for i = startIdx, CL_deferTail do
        local item = CL_deferQueue[i]
        if item and type(item.lineID) == "number" and item.lineID > 0 then
            table.insert(pending, {
                event    = item.event,
                lineID   = item.lineID,
                tabNames = item.tabNames,
                t        = item.time,
            })
        end
    end
    LNuiChatDB.pendingDeferred = #pending > 0 and pending or nil
end

-- ── 恢复延迟消息队列 ─────────────────────────────
CL_RestoreDeferredQueue = function()
    if not LNuiChatDB or type(LNuiChatDB.pendingDeferred) ~= "table" then return end
    local pending = LNuiChatDB.pendingDeferred
    LNuiChatDB.pendingDeferred = nil
    for _, item in ipairs(pending) do
        if type(item.event) == "string"
            and type(item.lineID) == "number"
            and item.lineID > 0
        then
            CL_DeferQueuePush({
                event    = item.event,
                lineID   = item.lineID,
                tabNames = item.tabNames or { "ChatFrame1" },
                time     = item.t or time(),
            })
        end
    end
    if not CL_DeferQueueIsEmpty() then
        CL_DeferPump()
    end
end

-- ── 受限聊天事件入口 ─────────────────────────────
local CL_deferFrame = CreateFrame("Frame")
local CL_DeferredEvents = {
    "CHAT_MSG_WHISPER",           "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",        "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY",             "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",              "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT",     "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD",
}

for _, event in ipairs(CL_DeferredEvents) do
    CL_deferFrame:RegisterEvent(event)
end

CL_deferFrame:SetScript("OnEvent", function(self, event, ...)
    if not sessionStarted then return end
    -- 只在聊天锁定期间接管；不扫描事件参数，避免污染系统发送链路
    if not CL_IsChatMessagingLocked() then return end
    local tabNames = CL_TabNamesForEvent(event)
    CL_RecordLockdownNotice()

    local lineID = CL_CaptureLineID(...)
    if not lineID then return end
    CL_DeferQueuePush({
        event    = event,
        lineID   = lineID,
        tabNames = tabNames,
        time     = time(),
    })
    CL_DeferPump()
end)



-- ==========================================
-- 第五部分：面板通用函数
-- ==========================================
local CL_InsertIntoMemo

-- ── 保存数值四舍五入 ─────────────────────────────
local function CL_RoundSavedValue(v)
    return math.floor((tonumber(v) or 0) * 1000 + 0.5) / 1000
end

-- ── 判断玩家移动状态 ─────────────────────────────
local function CL_CheckMoving()
    if IsPlayerMoving() then return true end
    --if IsFalling() then return true end       --原地跳跃？
    if IsFlying() or IsSwimming() then
        local keys = { GetBindingKey("JUMP") }
        for _, k in ipairs(keys) do
            if k and IsKeyDown(k) then return true end
        end
    end
    return false
end

-- ── 启动移动状态轮询 ─────────────────────────────
local function CL_StartMoveTicker(owner, onChanged)
    if owner.CL_MoveTicker then return end
    owner.CL_IsMoving = CL_CheckMoving()
    onChanged(owner.CL_IsMoving)
    owner.CL_MoveTicker = C_Timer.NewTicker(0.1, function()
        local moving = CL_CheckMoving()
        if moving ~= owner.CL_IsMoving then
            owner.CL_IsMoving = moving
            onChanged(moving)
        end
    end)
end

-- ── 停止移动状态轮询 ─────────────────────────────
local function CL_StopMoveTicker(owner)
    if owner.CL_MoveTicker then
        owner.CL_MoveTicker:Cancel()
        owner.CL_MoveTicker = nil
    end
end

-- ── 启用编辑框滚轮滚动 ─────────────────────────────
local function CL_EnableEditBoxWheelScroll(scrollFrame, editBox)
    if not scrollFrame or not editBox then return end
    local function OnWheel(_, delta)
        local _, fontSize = editBox:GetFont()
        local lineHeight  = (tonumber(fontSize) or 16) + (tonumber(CL_Config.LineSpacing) or 0)
        local scrollLines = math.max(1, tonumber(CL_Config.ScrollLines) or 5)
        local maxScroll   = math.max(0, editBox:GetHeight() - scrollFrame:GetHeight())
        local new         = math.max(0, math.min(maxScroll, scrollFrame:GetVerticalScroll() - delta * scrollLines * lineHeight))
        scrollFrame:SetVerticalScroll(new)
        if scrollFrame.scrollBar then
            scrollFrame.scrollBar:SetMinMaxValues(0, maxScroll)
            scrollFrame.scrollBar:SetValue(new)
        end
    end
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", OnWheel)
    editBox:EnableMouseWheel(true)
    editBox:SetScript("OnMouseWheel", OnWheel)
end

-- ── 创建右下角缩放按钮 ─────────────────────────────
local function CL_CreateResizeButton(parentFrame, size, xOfs, yOfs)
    local resizeBtn = CreateFrame("Button", nil, parentFrame)
    resizeBtn:SetSize(size, size)
    resizeBtn:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", xOfs, yOfs)
    resizeBtn:SetFrameLevel(parentFrame:GetFrameLevel() + 20)
    local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    resizeTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeTex:SetAllPoints(resizeBtn)
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    return resizeBtn
end

-- ── 绑定通用缩放拖拽逻辑 ─────────────────────────────
local function CL_AttachResizeBehavior(btn, targetFrame, minW, minH, callbacks)
    callbacks = callbacks or {}
    btn:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local startMouseX, startMouseY = GetCursorPosition()
        local startW, startH = targetFrame:GetWidth(), targetFrame:GetHeight()
        local maxW = math.floor(UIParent:GetWidth() * 0.9)
        local maxH = math.floor(UIParent:GetHeight() * 0.9)
        local scale = targetFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local left = targetFrame:GetLeft() * scale
        local top = targetFrame:GetTop() * scale
        targetFrame:ClearAllPoints()
        targetFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        if callbacks.onStart then callbacks.onStart(targetFrame, self) end
        self:SetScript("OnUpdate", function()
            local curX, curY = GetCursorPosition()
            local frameScale = targetFrame:GetEffectiveScale()
            local dx = (curX - startMouseX) / frameScale
            local dy = (startMouseY - curY) / frameScale
            targetFrame:SetSize(
                math.max(minW, math.min(maxW, startW + dx)),
                math.max(minH, math.min(maxH, startH + dy))
            )
            if callbacks.onResize then callbacks.onResize(targetFrame, self) end
        end)
    end)
    btn:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        self:SetScript("OnUpdate", nil)
        if callbacks.onFinish then callbacks.onFinish(targetFrame, self) end
    end)
end

-- ── 格式化日志显示行 ─────────────────────────────
local function CL_FormatLogLineForDisplay(msgData, overrideText, isSearch, timestampLink)
    if not msgData then return "" end
    local text = overrideText or msgData.t or ""
    if msgData.isSeparator then
        return text
    end

    local timePrefix = ""
    if msgData.ts then
        local timeStr
        if isSearch then
            timeStr = date("[%m-%d %H:%M:%S]", msgData.ts)
        else
            timeStr = date("[%H:%M:%S]", msgData.ts)
        end
        if timestampLink then
            timePrefix = "|cffA0A0A0|H" .. timestampLink .. "|h" .. timeStr .. "|h|r "
        else
            timePrefix = "|cffA0A0A0" .. timeStr .. " |r"
        end
    end

    if msgData.preColored then return timePrefix .. text .. "|r" end

    local rr, gg, bb
    if msgData.c then
        rr = math.floor(msgData.c / 65536) % 256
        gg = math.floor(msgData.c / 256)   % 256
        bb = msgData.c % 256
    else
        rr = math.floor((msgData.r or 1) * 255)
        gg = math.floor((msgData.g or 1) * 255)
        bb = math.floor((msgData.b or 1) * 255)
    end

    return string.format("%s|cff%02x%02x%02x%s|r", timePrefix, rr, gg, bb, text)
end


-- ── 超链接互动 ───────────────────────────────
-- 记录鼠标按下位置，用于区分点击链接和拖拽选中文本
local function CL_RecordHLinkMouseDown(self)
    self.CL_LinkMouseX, self.CL_LinkMouseY = GetCursorPosition()
    self.CL_LinkMouseDownTime = GetTime()
end

-- 鼠标移动超过 12 像素视为拖拽，不触发普通链接打开
local function CL_WasHLinkDragged(self)
    local sx, sy = self.CL_LinkMouseX, self.CL_LinkMouseY
    if not sx or not sy then return false end
    -- 旧鼠标坐标超过 1 秒后失效，避免误挡下一次左键点击
    if self.CL_LinkMouseDownTime and GetTime() - self.CL_LinkMouseDownTime > 1 then return false end
    local x, y = GetCursorPosition()
    local dx, dy = x - sx, y - sy
    return (dx * dx + dy * dy) > 144
end

-- 把 tooltip 放到鼠标右下，并在悬停期间持续跟随鼠标
local function CL_PositionHLinkTooltip(owner)
    local tooltip = owner and owner.CL_HLinkTooltip or GameTooltip
    if not tooltip or not tooltip:IsShown() then return end
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 18, y / scale - 18)
end

local function CL_ShowHLinkHint(self, hintText)
    if not self or not GameTooltip or not hintText then return false end
    if BattlePetTooltip then BattlePetTooltip:Hide() end
    self.CL_HLinkTooltip = GameTooltip
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(hintText, 0.50, 0.80, 1.00, true)
    GameTooltip:Show()
    CL_PositionHLinkTooltip(self)
    self:SetScript("OnUpdate", CL_PositionHLinkTooltip)
    return true
end

-- 普通游戏链接悬停时显示 GameTooltip，失败时静默隐藏
local function CL_ShowHLinkTooltip(self, link, text)
    local linkType = CL_GetHLinkType(link)
    if not CL_IsAllowedLogHLinkType(link) then return end
    local hintText = linkType and CL_TextHintHLinks[linkType]
    -- 测试超链接实际类型
    -- print("BDCL hover linkType =", tostring(linkType), "text =", tostring(text), "link =", tostring(link))
    if hintText then
        CL_ShowHLinkHint(self, hintText)
        return
    end

    if not GameTooltip then return end
    self.CL_HLinkTooltip = GameTooltip
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    if not ok then
        GameTooltip:Hide()
        self.CL_HLinkTooltip = nil
        return
    end
    --GameTooltip:Show()    -- 超链接提示暂时放弃主动要求Show，可能存在风险
    CL_PositionHLinkTooltip(self)
    self:SetScript("OnUpdate", CL_PositionHLinkTooltip)
end

-- 鼠标离开链接时隐藏 tooltip
local function CL_HideHLinkTooltip(self)
    self:SetScript("OnUpdate", nil)
    self.CL_HLinkTooltip = nil
    if GameTooltip and GameTooltip:GetOwner() == self then
        GameTooltip:Hide()
    end
    if BattlePetTooltip then BattlePetTooltip:Hide() end
end

-- 左键打开白名单游戏链接
local function CL_OpenAllowedHLink(link, text, button)
    if CL_IsHLinkClickRestricted() then
        return
    end

    if CL_IsAllowedLogHLinkType(link) then
        if button ~= "LeftButton" or not SetItemRef then return end
        -- 锁定期间禁止从 BDChatLog 的链接插入聊天输入框，避免 taint 后阻塞 SendChatMessage
        if CL_IsChatMessagingLocked() and IsModifiedClick and IsModifiedClick("CHATLINK") then return end
    else
        return
    end
    local chatFrame = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME or ChatFrame1
    if chatFrame then
        pcall(SetItemRef, link, text, button, nil)
    end
end

-- 给日志和备忘录 EditBox 统一启用链接、tooltip、拖拽坐标记录
local function CL_EnableSafeHLinks(editBox)
    editBox:SetHyperlinksEnabled(true)
    editBox:HookScript("OnMouseDown", CL_RecordHLinkMouseDown)
    editBox:SetScript("OnHyperlinkEnter", CL_ShowHLinkTooltip)
    editBox:SetScript("OnHyperlinkLeave", CL_HideHLinkTooltip)
end



-- ==========================================
-- 第六部分：聊天日志面板
-- ==========================================

local function CL_EnsureMainFrame()

    if BDCL_MainFrame then
        local currentActiveTab = SELECTED_CHAT_FRAME and SELECTED_CHAT_FRAME:GetName() or "ChatFrame1"
        BDCL_MainFrame:Show()
        C_Timer.After(0, function()
            BDCL_MainFrame.RenderLog(currentActiveTab, "bottom")
        end)
        return
    end

    -- ── 主框架 ─────────────────────────────────────────
    local MainFrame = CreateFrame("Frame", "BDCL_MainFrame", UIParent, "ButtonFrameTemplate")
    MainFrame.currentView = "recent"
    MainFrame.totalEntries = 0
    MainFrame:SetFrameStrata("HIGH")
    MainFrame:SetSize(850, 700)
    MainFrame.CloseButton:SetScript("OnClick", function()
        MainFrame:Hide()
    end)
    MainFrame:HookScript("OnHide", function()
        if MainFrame.ClearSearchState then MainFrame.ClearSearchState() end
        if BDCL_UpdateOpenButtonStyle then BDCL_UpdateOpenButtonStyle() end
    end)
    MainFrame:SetMovable(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")

    -- 恢复上次关闭时保存的窗口位置，否则居中显示
    if LNuiChatDB and LNuiChatDB.position then
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint(unpack(LNuiChatDB.position))
    else
        MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end

    -- 恢复上次保存的窗口尺寸
    if LNuiChatDB.size then
        MainFrame:SetSize(LNuiChatDB.size[1], LNuiChatDB.size[2])
    end

    if not tContains(UISpecialFrames, "BDCL_MainFrame") then
        table.insert(UISpecialFrames, "BDCL_MainFrame")
    end

    -- ── 左上角职业头像 ────────────────────────────────────
    local _, classTag = UnitClass("player")
    local classIcon   = "Interface\\TargetingFrame\\UI-Classes-Circles"
    local classCoords = CLASS_ICON_TCOORDS[classTag]
    if classCoords then
        if MainFrame.PortraitContainer and MainFrame.PortraitContainer.portrait then
            MainFrame.PortraitContainer.portrait:SetTexture(classIcon)
            MainFrame.PortraitContainer.portrait:SetTexCoord(unpack(classCoords))
            MainFrame.PortraitContainer.portrait:SetIgnoreParentAlpha(true)
            MainFrame.PortraitContainer.portrait:SetAlpha(1)
        end
    end

    -- ── 透明度动态控制 ───────────────────────────────────
    local alpha_Stand_BG  = 1.0     --静止时背景透明度
    local alpha_Move_Text = 0.8     --移动时文字透明度
    local alpha_Move_BG   = 0.3     --移动时背景透明度

    local isMoving   = false
    local isDragging = false

    local BackgroundTextures = { MainFrame.Bg, MainFrame.Inset.Bg }
    for _, tex in pairs(BackgroundTextures) do
        if tex then
            tex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
        end
    end
    local function UpdateAlpha()
        if isDragging or isMoving then
            for _, tex in pairs(BackgroundTextures) do
                if tex then tex:SetAlpha(alpha_Move_BG) end
            end
            MainFrame:SetAlpha(alpha_Move_Text)
        else
            for _, tex in pairs(BackgroundTextures) do
                if tex then tex:SetAlpha(alpha_Stand_BG) end
            end
            MainFrame:SetAlpha(1.0)
        end
    end
    local function OnMoveChanged(moving)
        isMoving = moving
        UpdateAlpha()
    end

    -- ── 保存主面板位置尺寸 ──────────────────────────────────
    local function SaveMainFrameLayout()
        local point, relativeTo, relativePoint, xOfs, yOfs = MainFrame:GetPoint()
        LNuiChatDB.position = {
            point, relativeTo and relativeTo:GetName() or "UIParent", relativePoint,
            CL_RoundSavedValue(xOfs), CL_RoundSavedValue(yOfs),
        }
        LNuiChatDB.size = {
            CL_RoundSavedValue(MainFrame:GetWidth()),
            CL_RoundSavedValue(MainFrame:GetHeight()),
        }
    end
    MainFrame:HookScript("OnShow", function() CL_StartMoveTicker(MainFrame, OnMoveChanged) end)
    MainFrame:HookScript("OnHide", function() CL_StopMoveTicker(MainFrame) end)
    CL_StartMoveTicker(MainFrame, OnMoveChanged)
    MainFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
        isDragging = true
        UpdateAlpha()
    end)
    MainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        isDragging = false
        UpdateAlpha()
        SaveMainFrameLayout()
    end)


    -- ── 右下角拖拽缩放按钮 ──────────────────────────────────
    local resizeBtn = CL_CreateResizeButton(MainFrame, 16, -4, 4)
    CL_AttachResizeBehavior(resizeBtn, MainFrame, 670, 240, {       --主面板最小尺寸
        onStart = function()
            isDragging = true
            UpdateAlpha()
        end,
        onResize = function()
            if MainFrame.EditBox and MainFrame.ScrollFrame then
                MainFrame.EditBox:SetWidth(math.max(100, MainFrame.ScrollFrame:GetWidth() - 8))
            end
            if MainFrame.UpdateTabBtnLayout then MainFrame.UpdateTabBtnLayout() end
        end,
        onFinish = function()
            isDragging = false
            UpdateAlpha()
            SaveMainFrameLayout()

            -- 刷新内部布局
            if MainFrame.EditBox and MainFrame.ScrollFrame then
                MainFrame.EditBox:SetWidth(math.max(100, MainFrame.ScrollFrame:GetWidth() - 8))
                if MainFrame.currentTab then
                    MainFrame.RenderLog(MainFrame.currentTab, "preserve")
                end
                if MainFrame.UpdateTabBtnLayout then MainFrame.UpdateTabBtnLayout() end
            end
        end,
    })


    -- ── 标题：当前标签页名称（由 RenderLog 动态更新）─────────────────────────
    local titleText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("TOP", MainFrame, "TOP", 17, -33)

    -- ── 角色切换器 ───────────────────────────────────────────────────────────
    local currentCharKey = UnitName("player") .. "-" .. GetRealmName()
    local btnSwitchChar = CreateFrame("Button", "BDCL_SwitchCharBtn", MainFrame, "BackdropTemplate")
    btnSwitchChar:SetSize(200, 25)
    btnSwitchChar:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 58, -30)
    btnSwitchChar:SetFrameLevel(MainFrame:GetFrameLevel() + 10)
    btnSwitchChar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 8,
        edgeSize = 10,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    btnSwitchChar:SetBackdropColor(0, 0, 0, 0)
    btnSwitchChar:SetBackdropBorderColor(0.8, 0.65, 0.2, 1)

    -- 按钮内的角色名
    local switchLabel = btnSwitchChar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    switchLabel:SetPoint("CENTER", 0, 0)

    -- 应用角色标签颜色
    local function ApplyCharLabelColor(fontStr, isCurrentChar)
        if isCurrentChar then
            local _, classTag = UnitClass("player")
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag]
            if color then
                fontStr:SetTextColor(color.r, color.g, color.b)
            else
                fontStr:SetTextColor(1, 1, 1)
            end
        else
            fontStr:SetTextColor(0.6, 0.6, 0.6)
        end
    end

    -- 更新角色切换按钮文本
    local function UpdateSwitchLabel(charKey)
        ApplyCharLabelColor(switchLabel, charKey == currentCharKey)
        switchLabel:SetText(charKey)
    end

    UpdateSwitchLabel(currentCharKey)

    -- 角色列表下拉菜单框
    local charMenu = CreateFrame("Frame", "BDCL_CharMenu", MainFrame, "BackdropTemplate")
    charMenu:SetFrameStrata("DIALOG")
    charMenu:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 12,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    charMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    charMenu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    charMenu:Hide()
    charMenu.rows = {}

    btnSwitchChar:SetScript("OnClick", function()
        if charMenu:IsShown() then charMenu:Hide() return end

        local chars = {}
        for k in pairs(LNuiChatDB) do
            if type(LNuiChatDB[k]) == "table" and k:find("-") then
                table.insert(chars, k)
            end
        end
        table.sort(chars, function(a, b)
            local order = CL_Config.CharOrder or {}
            local ia, ib = 999, 999
            for i, v in ipairs(order) do
                if v == a then ia = i end
                if v == b then ib = i end
            end
            if ia ~= ib then return ia < ib end
            return a < b
        end)

        -- 复用已有的行，不足才创建，多余就隐藏
        local rowH = 22
        for idx, charKey in ipairs(chars) do
            if not charMenu.rows[idx] then
                local row = CreateFrame("Button", nil, charMenu, "BackdropTemplate")
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "ADD")
                row:GetHighlightTexture():SetAlpha(0.15)
                row:SetSize(160, rowH)
                local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                lbl:SetPoint("LEFT", 4, 0)
                row.lbl = lbl
                charMenu.rows[idx] = row
            end
            local row = charMenu.rows[idx]
            row:SetPoint("TOPLEFT", charMenu, "TOPLEFT", 6, -(6 + (idx - 1) * rowH))
            row.lbl:SetText(charKey)
            ApplyCharLabelColor(row.lbl, charKey == currentCharKey)
            row:SetScript("OnClick", function()
                frame.viewedCharDB = LNuiChatDB[charKey]
                MainFrame.RenderLog(MainFrame.currentTab or "ChatFrame1", "bottom")
                UpdateSwitchLabel(charKey)
                charMenu:Hide()
                local portrait = MainFrame.PortraitContainer and MainFrame.PortraitContainer.portrait
                if portrait then
                    local isCurrentChar = (charKey == currentCharKey)
                    local targetClass = isCurrentChar and (select(2, UnitClass("player"))) or LNuiChatDB[charKey]["_class"]
                    local coords = targetClass and CLASS_ICON_TCOORDS[targetClass]
                    if coords then
                        portrait:SetTexture(classIcon)
                        portrait:SetTexCoord(unpack(coords))
                        portrait:SetDesaturated(not isCurrentChar)
                    end
                end
            end)
            row:Show()
        end
        -- 隐藏多余的旧行
        for idx = #chars + 1, #charMenu.rows do
            charMenu.rows[idx]:Hide()
        end

        charMenu:SetSize(200, 12 + #chars * rowH)
        charMenu:SetPoint("TOPLEFT", btnSwitchChar, "BOTTOMLEFT", 0, -2)
        charMenu:Show()
    end)


    -- ── 标签页切换按钮（< / >）──────────────────────────────────────────────
    local function SwitchTab(dir)
        local curTab  = MainFrame.currentTab or "ChatFrame1"
        local curNum  = tonumber(curTab:match("%d+")) or 1
        local nextNum = curNum
        local tabs    = frame.viewedCharDB and frame.viewedCharDB["_tabs"] or {}
        for _ = 1, NUM_CHAT_WINDOWS do
            nextNum = (nextNum - 1 + dir + NUM_CHAT_WINDOWS) % NUM_CHAT_WINDOWS + 1
            if tabs[nextNum] then break end
        end
        MainFrame.RenderLog("ChatFrame" .. nextNum)
    end

    local btnTabPrev = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    btnTabPrev:SetFrameLevel(MainFrame:GetFrameLevel() + 10)  -- 强行提到顶层，防止被遮挡
    btnTabPrev:SetSize(40, 25)
    btnTabPrev:SetText("<")
    btnTabPrev:SetPoint("RIGHT", titleText, "CENTER", -120, 0)
    btnTabPrev:SetScript("OnClick", function()
        SwitchTab(-1)
    end)
    local btnTabNext = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    btnTabNext:SetFrameLevel(MainFrame:GetFrameLevel() + 10)  -- 强行提到顶层，防止被遮挡
    btnTabNext:SetSize(40, 25)
    btnTabNext:SetText(">")
    btnTabNext:SetPoint("LEFT", titleText, "CENTER", 120, 0)
    btnTabNext:SetScript("OnClick", function()
        SwitchTab(1)
    end)

    -- ── 搜索框 ───────────────────────────────────────────────────────────────
    MainFrame.searchResults = nil
    local searchBox = CreateFrame("EditBox", "BDCL_SearchBox", MainFrame, "SearchBoxTemplate")
    searchBox:SetSize(190, 23)
    searchBox:SetPoint("RIGHT", MainFrame, "TOPRIGHT", -30, -42)
    searchBox:SetFrameLevel(MainFrame:GetFrameLevel() + 10)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(ChatFontNormal)
    searchBox:SetMaxLetters(100)
    searchBox.Instructions:SetText("搜索当前标签")

    -- 退出搜索时清空搜索框并恢复普通日志控件。
    local searchDebounce = nil
    local function ClearSearchState()
        MainFrame.searchResults = nil
        if searchBox:GetText() ~= "" then
            searchBox:SetText("")
        end
        MainFrame.UpdateDeleteButtonText()
    end
    MainFrame.ClearSearchState = ClearSearchState

    -- ── 渲染搜索结果 ─────────────────────────────
    -- 【内存优化】限制单次搜索结果数量，避免EditBox文本爆炸
    local MAX_SEARCH_RESULTS = 400
    local function RenderSearchResults()
        local sr = MainFrame.searchResults
        if not sr then return end
        local entries = sr.entries or {}
        local keyword = sr.keyword or ""
        local displayLines = {}
        local resultHeader = string.format(
            "|cff00CCFF── 搜索 |cffFF6600>>|r|cffffffff%s|r|cffFF6600<<|r" ..
            "|cff00CCFF 共找到 |cffFF8C00%d|r|cff00CCFF 条结果 ──|r",
            keyword, #entries
        )
        table.insert(displayLines, resultHeader)
        for _, entry in ipairs(entries) do
            table.insert(displayLines, entry.line)
        end
        local eb = MainFrame.EditBox
        if eb then
            eb:SetText(table.concat(displayLines, "\n"))
            eb:SetHeight(1)
            local actualHeight = math.max(CL_Config.EditBoxMinHeight, eb:GetHeight() + 60)
            eb:SetHeight(actualHeight)
        end

        local sf  = MainFrame.ScrollFrame
        local sb  = MainFrame.ScrollBar
        if sf and sb and eb then
            local maxOffset = math.max(0, eb:GetHeight() - sf:GetHeight())
            sb:SetMinMaxValues(0, maxOffset)
            sf:SetVerticalScroll(0)
            sb:SetValue(0)
        end
        if MainFrame.UpdateViewLabel then
            MainFrame.UpdateViewLabel()
        end
    end

    -- ── 执行日志搜索 ─────────────────────────────
    -- 【内存优化】复用保护表，减少搜索时的临时表分配
    local searchParts = {}
    local function DoSearch(keyword)
        if not keyword or keyword == "" then
            ClearSearchState()
            MainFrame.RenderLog(MainFrame.currentTab or "ChatFrame1", "bottom")
            return
        end
        local tabName = MainFrame.currentTab or "ChatFrame1"
        local logs    = frame.viewedCharDB and frame.viewedCharDB[tabName] or {}
        local lowerKw = keyword:lower()
        local matched = {}

        local escapedKw = keyword:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        local casePattern = escapedKw:gsub("([%a])", function(c)
            return "[" .. c:upper() .. c:lower() .. "]"
        end)
        -- 保护超链接、颜色码与链接控制符
        local function protect(s)
            if #searchParts >= 255 then return s end
            local id = #searchParts + 1
            searchParts[id] = s
            local a = math.floor((id - 1) / 16)
            local b = (id - 1) % 16
            return "\1" .. string.char(3 + a) .. string.char(3 + b) .. "\2"
        end

        for logIndex, msgData in ipairs(logs) do
            local raw = msgData.t or ""
            -- （超链接）搜索匹配使用纯文本，避免把 |H 链接结构当成关键词内容
            local plain = CL_ColorlessText(raw)
            if plain:lower():find(lowerKw, 1, true) then
                for k = #searchParts, 1, -1 do searchParts[k] = nil end
                -- 先处理超链接：如果搜索词命中链接显示文字，就高亮整个链接
                local safe = raw:gsub("(|H.-|h(.-)|h)", function(linkBlock, linkText)
                    if linkText:find(casePattern) then
                        linkBlock = "|cffFF6600>>|r" .. linkBlock .. "|cffFF6600<<|r"
                    end
                    return protect(linkBlock)
                end)
                -- 剩下的颜色码和控制符继续保护，避免普通高亮破坏控制结构
                safe = safe:gsub("|c%x%x%x%x%x%x%x%x", protect)
                           :gsub("|cn[%w_]+:", protect)
                           :gsub("|[rRhHkK]", protect)
                local highlighted = safe:gsub("(" .. casePattern .. ")", "|cffFF6600>>|r%1|cffFF6600<<|r")
                highlighted = highlighted:gsub("\1(.)(.)\2", function(a, b)
                    local id = (string.byte(a) - 3) * 16 + (string.byte(b) - 3) + 1
                    return searchParts[id]
                end)
                local resultIndex = #matched + 1
                local line = CL_FormatLogLineForDisplay(msgData, highlighted, true, "bdclsearch:" .. resultIndex)
                -- 记住原始日志的索引，方便删除
                table.insert(matched, {
                    line     = line,
                    logIndex = logIndex,
                    ref      = msgData,
                })
                -- 【内存优化】达到上限后停止搜索，避免极端情况内存爆炸
                if #matched >= MAX_SEARCH_RESULTS then
                    break
                end
            end
        end
        MainFrame.searchResults = {
            entries = matched,
            keyword = keyword,
            tabName = tabName,
        }
        MainFrame.UpdateDeleteButtonText()
        RenderSearchResults()
    end

    -- ── 删除搜索结果 ─────────────────────────────
    local function DeleteSearchResults()
        local sr = MainFrame.searchResults
        if not sr or not sr.entries then return end
        local tabName = sr.tabName or MainFrame.currentTab
        local logs = frame.viewedCharDB and frame.viewedCharDB[tabName]
        if not logs then return end
        local indexMap = {}
        for _, entry in ipairs(sr.entries) do
            local idx = entry.logIndex
            if not idx or logs[idx] ~= entry.ref then
                idx = nil
                for j = #logs, 1, -1 do
                    if logs[j] == entry.ref then
                        idx = j
                        break
                    end
                end
            end
            if idx then
                indexMap[idx] = true
            end
        end
        local toDelete = {}
        for idx in pairs(indexMap) do
            table.insert(toDelete, idx)
        end
        table.sort(toDelete, function(a, b) return a > b end)
        for _, idx in ipairs(toDelete) do
            table.remove(logs, idx)
        end
        local deleted = #toDelete
        local keyword = sr.keyword or ""
        print(string.format(
            "|cffff9900[BDChatLog]|r：已删除搜索命中 |cffFF6600>>|r|cffffffff%s|r|cffFF6600<<|r 的共 |cffFF8C8C%d|r 条日志。",
            keyword,
            deleted
        ))
        -- 删除后重新搜索一次，刷新显示
        DoSearch(keyword)
    end

    -- OnTextChanged：实时防抖搜索
    searchBox:HookScript("OnTextChanged", function(self)
        local text = self:GetText()
        if searchDebounce then
            searchDebounce:Cancel()
            searchDebounce = nil
        end
        if text ~= "" then
            searchDebounce = C_Timer.NewTimer(0.1, function()
                DoSearch(text)
            end)
        else
            ClearSearchState()
            MainFrame.RenderLog(MainFrame.currentTab or "ChatFrame1", "bottom")
        end
    end)

    -- ESC：清空搜索框并还原日志视图
    searchBox:SetScript("OnEscapePressed", function(self)
        ClearSearchState()
        self:ClearFocus()
        MainFrame.RenderLog(MainFrame.currentTab or "ChatFrame1", "bottom")
    end)

    -- 回车：立即触发搜索
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        DoSearch(self:GetText())
    end)

    -- ── 面板宽度过小时截断标签页名 ─────────────────────
    local TAB_COMPACT_WIDTH  = 820
    local TAB_NORMAL_OFFSET  = 120
    local TAB_COMPACT_OFFSET = 52
    local TAB_COMPACT_CHARS  = 5

    -- 截断 UTF-8 标签名
    local function TruncateTabName(name, maxChars)
        name = name or ""
        local byteIdx, charCount = 1, 0
        while byteIdx <= #name do
            local b = name:byte(byteIdx)
            local step = (b >= 0xF0) and 4 or (b >= 0xE0) and 3 or (b >= 0xC0) and 2 or 1
            charCount = charCount + 1
            if charCount > maxChars then
                return name:sub(1, byteIdx - 1) .. ".."
            end
            byteIdx = byteIdx + step
        end
        return name
    end

    -- 更新标签切换布局
    local function UpdateTabBtnLayout()
        local compact = MainFrame:GetWidth() <= TAB_COMPACT_WIDTH
        local offset  = compact and TAB_COMPACT_OFFSET or TAB_NORMAL_OFFSET
        local title   = MainFrame._currentTabTitle or ""
        btnTabPrev:ClearAllPoints()
        btnTabPrev:SetPoint("RIGHT", titleText, "CENTER", -offset, 0)
        btnTabNext:ClearAllPoints()
        btnTabNext:SetPoint("LEFT", titleText, "CENTER", offset, 0)
        titleText:SetText(compact and TruncateTabName(title, TAB_COMPACT_CHARS) or title)
    end

    MainFrame.UpdateTabBtnLayout = UpdateTabBtnLayout

    -- ── 滚动区域 ─────────────────────────────────────────────────────────────
    local ScrollFrame = CreateFrame("ScrollFrame", "BDCL_ScrollFrame", MainFrame, "UIPanelScrollFrameTemplate")
    ScrollFrame:SetPoint("TOPLEFT",     MainFrame, "TOPLEFT",     15,  -70)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -35,  35)

    local EditBox = CreateFrame("EditBox", "BDCL_EditBox", ScrollFrame)
    EditBox:SetMultiLine(true)
    EditBox:SetMaxLetters(0)
    EditBox:EnableMouse(true)
    EditBox:SetAutoFocus(false)
    EditBox:SetFontObject(ChatFontNormal)

    if EditBox.SetSpacing then
        EditBox:SetSpacing(tonumber(CL_Config.LineSpacing) or 0)
    end
    -- （超链接）主日志 EditBox 开启安全链接悬停/点击支持
    CL_EnableSafeHLinks(EditBox)
    EditBox:SetScript("OnHyperlinkClick", function(self, link, text, button)
        -- （超链接）时间戳链接优先处理，右键保存整条日志到备忘录
        local linkText = type(link) == "string" and link or ""
        local searchIdx = tonumber(linkText:match("^bdclsearch:(%d+)$"))
        local logIdx = tonumber(linkText:match("^bdcl:(%d+)$"))
        if searchIdx or logIdx then
            if button ~= "RightButton" then return end
            local main = BDCL_MainFrame
            local sr = main and main.searchResults
            local entry = searchIdx and sr and sr.entries and sr.entries[searchIdx]
            local tabName = (sr and sr.tabName) or (main and main.currentTab) or "ChatFrame1"
            local logs = frame.viewedCharDB and frame.viewedCharDB[tabName] or {}
            local msgData = (entry and entry.ref) or (logIdx and logs[logIdx])
            if not msgData then return end

            if CL_InsertIntoMemo then
                CL_InsertIntoMemo(CL_FormatLogLineForDisplay(msgData, nil, true))
                local s, cx, cy = UIParent:GetEffectiveScale(), GetCursorPosition()
                local fx = CreateFrame("Frame", nil, UIParent)
                fx:SetFrameStrata("TOOLTIP") fx:SetSize(20, 20) fx:SetPoint("CENTER", nil, "BOTTOMLEFT", cx/s, cy/s)
                local t, ag = fx:CreateTexture(nil, "OVERLAY"), fx:CreateAnimationGroup()
                t:SetAllPoints() t:SetTexture("Interface\\Cooldown\\star4") t:SetBlendMode("ADD")
                t:SetVertexColor(0.55, 1, 0.65)
                local sc, al = ag:CreateAnimation("Scale"), ag:CreateAnimation("Alpha")
                sc:SetScale(2, 2) sc:SetDuration(0.2) sc:SetSmoothing("OUT")
                al:SetFromAlpha(1) al:SetToAlpha(0) al:SetDuration(0.17) al:SetSmoothing("IN")
                ag:SetScript("OnFinished", function() fx:Hide() end) 
                ag:Play()
            end
            return
        end
        -- （超链接）普通链接若来自拖拽选中文本，则不打开
        if CL_WasHLinkDragged(self) then return end
        -- （超链接）打开白名单游戏链接
        CL_OpenAllowedHLink(link, text, button)
    end)
    EditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ScrollFrame:SetScrollChild(EditBox)

    local scrollBar = _G["BDCL_ScrollFrameScrollBar"]
    ScrollFrame.scrollBar = scrollBar

    CL_EnableEditBoxWheelScroll(ScrollFrame, EditBox)

    -- ScrollFrame 尺寸变化时，同步调整 EditBox 宽度并重新渲染
    ScrollFrame:SetScript("OnSizeChanged", function(_, width)
        EditBox:SetWidth(math.max(100, width - 8))

        if MainFrame.currentTab then
            if MainFrame.searchResults then
                RenderSearchResults()
            else
                MainFrame.RenderLog(MainFrame.currentTab, "preserve")
            end
        end
    end)


    -- ── 底部控制区：日志视图按钮 ─────────────────────────────────────────────────────────
    local btnOlder = CreateFrame("Button", nil, MainFrame)
    btnOlder:SetSize(80, 26)
    btnOlder:SetPoint("BOTTOMLEFT", MainFrame, "BOTTOMLEFT", 30, 2)
    btnOlder:SetFontString(btnOlder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
    btnOlder:GetFontString():SetPoint("CENTER", 0, 2)
    btnOlder:SetText("较早")

    local btnRecent = CreateFrame("Button", nil, MainFrame)
    btnRecent:SetSize(80, 26)
    btnRecent:SetPoint("LEFT", btnOlder, "RIGHT", 6, 0)
    btnRecent:SetFontString(btnRecent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
    btnRecent:GetFontString():SetPoint("CENTER", 0, 2)
    btnRecent:SetText("最近")

    MainFrame.OlderViewButton  = btnOlder
    MainFrame.RecentViewButton = btnRecent

    -- 设置日志视图页签的搜索禁用与当前选中材质。
    local function SetLogViewButtonStyle(btn, active, disabled)
        if not btn then return end
        btn:SetEnabled(not disabled)
        btn:SetAlpha(disabled and 0.35 or 1)
        if active then
            btn:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
            btn:GetFontString():SetTextColor(1.00, 0.82, 0.20, 1)
        else
            btn:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
            btn:GetFontString():SetTextColor(0.82, 0.76, 0.64, 1)
        end
        local tex = btn:GetNormalTexture()
        if tex then tex:SetTexCoord(0, 1, 0, active and 0.63 or 1) end
    end

    -- 根据搜索状态和当前视图刷新两个日志视图页签。
    MainFrame.UpdateLogViewButtons = function()
        local inSearchMode = MainFrame.searchResults ~= nil
        local currentView = MainFrame.currentView or "recent"
        SetLogViewButtonStyle(MainFrame.OlderViewButton, currentView == "older", inSearchMode)
        SetLogViewButtonStyle(MainFrame.RecentViewButton, currentView == "recent", inSearchMode)
    end

    btnOlder:SetScript("OnClick", function()
        MainFrame.currentView = "older"
        MainFrame.RenderLog(MainFrame.currentTab)
    end)

    btnRecent:SetScript("OnClick", function()
        MainFrame.currentView = "recent"
        MainFrame.RenderLog(MainFrame.currentTab, "bottom")
    end)

    -- ── 底部控制区：视图状态 ───────────────────────────────────────────────
    local viewLabel = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    viewLabel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -30, 8)

    MainFrame.UpdateViewLabel = function()
        if MainFrame.searchResults then
            viewLabel:SetText("")
            return
        end

        local totalEntries = MainFrame.totalEntries or 0
        viewLabel:SetText(string.format("总计 %d 条", totalEntries))
    end

    -- ── 底部控制区：删除当前 ─────────────────────────────────
    local btnDeleteView = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    btnDeleteView:SetSize(150, 22)
    btnDeleteView:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -150, 4)

    MainFrame.DeleteViewButton = btnDeleteView

    -- 根据普通视图/搜索视图刷新删除按钮文案和页签状态。
    MainFrame.UpdateDeleteButtonText = function()
        if MainFrame.searchResults then
            MainFrame.DeleteViewButton:SetText("删除所有搜索结果")
        else
            local visibleCount = MainFrame._visibleEntries and #MainFrame._visibleEntries or 0
            MainFrame.DeleteViewButton:SetText(string.format("删除视图内 %d 条", visibleCount))
        end
        MainFrame.UpdateLogViewButtons()
    end
    MainFrame.UpdateDeleteButtonText()

    -- ── 弹出删除确认框 ─────────────────────────────
    local function ConfirmDelete(text, func)
        if type(func) ~= "function" then return end

        StaticPopupDialogs["BDCL_DELETE_CONFIRM"] = {
            text         = text or "确定要删除吗？",
            button1      = "删除",
            button2      = "取消",
            OnAccept     = function()
                func()
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
        }

        StaticPopup_Show("BDCL_DELETE_CONFIRM")
    end

    btnDeleteView:SetScript("OnClick", function()
        if MainFrame.searchResults then
            ConfirmDelete("确定要删除所有搜索结果吗？", DeleteSearchResults)        --弹确认窗
            --DeleteSearchResults()     --不弹确认窗
            return
        end

        if not MainFrame.currentTab or not frame.viewedCharDB then return end
        local logs = frame.viewedCharDB[MainFrame.currentTab]
        if not logs or #logs == 0 then return end

        local visibleEntries = MainFrame._visibleEntries
        if not visibleEntries or #visibleEntries == 0 then return end

        -- 删除当前实际显示的日志条目
        local refSet = {}
        for _, msgData in ipairs(visibleEntries) do
            if msgData then refSet[msgData] = true end
        end

        for i = #logs, 1, -1 do
            if refSet[logs[i]] then
                table.remove(logs, i)
            end
        end

        MainFrame._visibleEntries = {}
        MainFrame.totalEntries = #logs

        MainFrame.RenderLog(MainFrame.currentTab, MainFrame.currentView == "recent" and "bottom" or nil)
    end)

    -- ── 底部控制区：关键词过滤（阻止命中消息写入存档）────────────────────────
    local keywordHintIcon = CreateFrame("Button", nil, MainFrame)
    keywordHintIcon:SetSize(20, 20)
    keywordHintIcon:SetPoint("CENTER", MainFrame, "BOTTOMLEFT", 19, -11)
    keywordHintIcon:SetFrameLevel(MainFrame:GetFrameLevel() + 20)
    keywordHintIcon:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    keywordHintIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffff9900关键词过滤|r")
        GameTooltip:AddLine("只阻止命中的新消息写入存档", 1, 1, 1, true)
        GameTooltip:AddLine("|cffF76666回车确认|r   多个关键词用分号隔开", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("可用如 [5. 大脚] 的方式过滤频道", 0.55, 0.55, 0.55, true)
        GameTooltip:Show()
    end)
    keywordHintIcon:SetScript("OnLeave", GameTooltip_Hide)

    local saveKeywordBox = CreateFrame("EditBox", "BDCL_KeywordFilterSaveBox", MainFrame, "InputBoxTemplate")
    saveKeywordBox:SetHeight(23)
    saveKeywordBox:SetPoint("TOPLEFT", MainFrame, "BOTTOMLEFT", 40, 0)
    saveKeywordBox:SetPoint("TOPRIGHT", MainFrame, "BOTTOMRIGHT", -20, 0)
    saveKeywordBox:SetFrameLevel(MainFrame:GetFrameLevel() + 10)
    saveKeywordBox:SetAutoFocus(false)
    saveKeywordBox:SetFontObject(ChatFontNormal)
    saveKeywordBox:SetTextColor(0.70, 0.70, 0.70, 0.8)
    saveKeywordBox:SetMaxLetters(500)
    saveKeywordBox:SetScript("OnEditFocusGained", nil)
    local saveText = CL_GetKeywordFilterSaveText()
    saveKeywordBox:SetText(saveText)
    saveKeywordBox:SetCursorPosition(#saveText)
    -- 应用关键词过滤配置
    local function ApplyKeywordFilters()
        local normalizedSave = CL_SaveKeywordFilterText("KeywordFilterSaveText", saveKeywordBox:GetText())
        saveKeywordBox:SetText(normalizedSave)
        saveKeywordBox:SetCursorPosition(#normalizedSave)
        saveKeywordBox:ClearFocus()
    end
    saveKeywordBox:SetScript("OnEnterPressed", ApplyKeywordFilters)
    saveKeywordBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    MainFrame.KeywordFilterSaveBox = saveKeywordBox

    -- ── 渲染聊天日志视图 ─────────────────────────────
    -- 【内存优化】限制单次渲染到EditBox的最大行数，避免超长日志导致双倍内存占用
    local MAX_RENDER_LINES = 600
    MainFrame.RenderLog = function(tabName, scrollMode)
        local oldTab = MainFrame.currentTab
        local isTabSwitch = oldTab and oldTab ~= tabName

        if isTabSwitch then
            ClearSearchState()
        end

        MainFrame.currentTab = tabName
        local tabNum   = tonumber(tabName:match("%d+"))
        local tabTitle = (frame.viewedCharDB and frame.viewedCharDB["_tabs"] and frame.viewedCharDB["_tabs"][tabNum])
            or (_G[tabName] and _G[tabName].name)
            or tabName
        MainFrame._currentTabTitle = tabTitle
        UpdateTabBtnLayout()

        local logs = frame.viewedCharDB and frame.viewedCharDB[tabName] or {}

        local totalEntries = #logs
        MainFrame.totalEntries = totalEntries

        if scrollMode == "bottom" or isTabSwitch or not MainFrame.currentView then
            MainFrame.currentView = "recent"
            scrollMode = "bottom"
        end

        local startIdx, endIdx = CL_GetLogViewRange(totalEntries, MainFrame.currentView)

        MainFrame._visibleEntries = {}

        -- 只构造当前视图内容，不全量重建所有日志
        local displayLines = {}
        local renderCount = 0
        for i = startIdx, endIdx do
            local msgData = logs[i]
            if msgData then
                table.insert(displayLines, CL_FormatLogLineForDisplay(msgData, nil, nil, "bdcl:" .. i))
                table.insert(MainFrame._visibleEntries, msgData)
                renderCount = renderCount + 1
                if renderCount >= MAX_RENDER_LINES then
                    -- 达到上限，插入提示并终止
                    table.insert(displayLines, "|cffA0A0A0... 日志过长，仅显示最近 " .. MAX_RENDER_LINES .. " 条，其余已存档 ...|r")
                    break
                end
            end
        end
        local preserveScroll = ScrollFrame and ScrollFrame:GetVerticalScroll() or 0
        EditBox:SetText(table.concat(displayLines, "\n"))
        EditBox:SetHeight(1)
        local actualHeight = math.max(CL_Config.EditBoxMinHeight, EditBox:GetHeight() + 60)
        EditBox:SetHeight(actualHeight)

        -- 防止快速切标签/切视图时，旧的下一帧滚动覆盖新的渲染结果
        MainFrame._renderToken = (MainFrame._renderToken or 0) + 1
        local renderToken = MainFrame._renderToken
        local renderTab   = tabName
        local renderView  = MainFrame.currentView
        local renderMode  = scrollMode

        C_Timer.After(0, function()
            if renderToken ~= MainFrame._renderToken then return end
            if MainFrame.currentTab ~= renderTab or MainFrame.currentView ~= renderView then return end
            if not (ScrollFrame and scrollBar and EditBox) then return end

            local maxOffset = math.max(0, EditBox:GetHeight() - ScrollFrame:GetHeight())
            scrollBar:SetMinMaxValues(0, maxOffset)

            local targetOffset
            if renderMode == "preserve" then
                -- 新消息来了但玩家不在底部：保留当前阅读位置
                targetOffset = preserveScroll
            elseif renderView == "recent" then
                -- 最近视图显示底部，较早视图显示顶部
                targetOffset = maxOffset
            else
                targetOffset = 0
            end

            targetOffset = math.max(0, math.min(maxOffset, targetOffset))
            ScrollFrame:SetVerticalScroll(targetOffset)
            scrollBar:SetValue(targetOffset)
        end)

        MainFrame.UpdateViewLabel()
        MainFrame.UpdateDeleteButtonText()
    end

    MainFrame.ScrollFrame = ScrollFrame
    MainFrame.EditBox     = EditBox
    MainFrame.ScrollBar   = scrollBar

    -- 首次创建完成后的下一帧，显示当前聊天标签页并定位到最新底部。
    BDCL_MainFrame = MainFrame
    local currentActiveTab = SELECTED_CHAT_FRAME and SELECTED_CHAT_FRAME:GetName() or "ChatFrame1"
    C_Timer.After(0, function()
        MainFrame.RenderLog(currentActiveTab, "bottom")
    end)
end



-- ==========================================
-- 第七部分：备忘笔记面板
-- ==========================================
local BDCL_MemoPopup
-- 【内存优化】单页备忘录上限减半，降低长期运行内存占用
local CL_MEMO_MAX_LETTERS = 18000
local CL_MEMO_WARN_LETTERS = 16000
local CL_MemoTabs = {
    { key = "logArch", label = "迁" },
    { key = "one",     label = "一" },
    { key = "two",     label = "二" },
    { key = "three",   label = "三" },
    { key = "four",    label = "四" },
    { key = "five",    label = "五" },
    { key = "six",     label = "六" },
    { key = "seven",   label = "七" },
}

local CL_memoInsertLastKey, CL_memoInsertLastAt
-- 把同一技能的完整/简写链接归一，避免同次 Shift 点击插入两遍。
local function CL_GetMemoInsertDedupeKey(rawLink)
    if type(rawLink) ~= "string" then return nil end
    local spellID = rawLink:match("^spell:(%d+):0$")
    return spellID and ("spell:" .. spellID) or rawLink
end

local function CL_InsertMemoFocusedLink(link)
    local editBox = BDCL_MemoPopup and BDCL_MemoPopup.EditBox
    if type(link) ~= "string" or not (editBox and editBox:HasFocus()) then return end
    if link:find("|K", 1, true) then return end

    local rawLink = link:match("|H([^|]-)|h") or link
    if not CL_IsAllowedLogHLinkType(rawLink) then return end

    local dedupeKey = CL_GetMemoInsertDedupeKey(rawLink)
    local now = GetTime and GetTime() or 0
    if dedupeKey and dedupeKey == CL_memoInsertLastKey and now - (CL_memoInsertLastAt or 0) <= 0.05 then
        return
    end
    CL_memoInsertLastKey, CL_memoInsertLastAt = dedupeKey, now

    editBox:Insert(link)
end

if hooksecurefunc and ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", CL_InsertMemoFocusedLink)
end

-- ── 获取备忘笔记存档表 ─────────────────────────────
local function CL_GetMemoDB()
    LNuiChatDB = LNuiChatDB or {}
    LNuiChatDB.Memo = LNuiChatDB.Memo or {}
    LNuiChatDB.Memo.tabTexts = LNuiChatDB.Memo.tabTexts or {}
    LNuiChatDB.Memo.activeTab = LNuiChatDB.Memo.activeTab or "logArch"
    return LNuiChatDB.Memo
end

-- ── 保存备忘笔记窗口位置尺寸 ─────────────────────────
local function CL_SaveMemoLayout()
    if not BDCL_MemoPopup then return end
    local memo = CL_GetMemoDB()
    local point, relativeTo, relativePoint, x, y = BDCL_MemoPopup:GetPoint()
    memo.position = {
        point,
        relativeTo and relativeTo:GetName() or "UIParent",
        relativePoint,
        CL_RoundSavedValue(x),
        CL_RoundSavedValue(y),
    }
    memo.size = {
        CL_RoundSavedValue(BDCL_MemoPopup:GetWidth()),
        CL_RoundSavedValue(BDCL_MemoPopup:GetHeight()),
    }
end

-- ── 刷新备忘笔记滚动区域 ────────────────────────────
local function CL_UpdateMemoScroll()
    if not BDCL_MemoPopup then return end
    local popup = BDCL_MemoPopup
    if not popup.EditBox or not popup.ScrollFrame then return end

    local eb = popup.EditBox
    local sf = popup.ScrollFrame
    eb:SetWidth(math.max(100, sf:GetWidth() - 8))
    if sf.UpdateScrollChildRect then
        sf:UpdateScrollChildRect()
    end
end

-- ── 修正备忘笔记颜色码 ─────────────────────────────
local function CL_FixMemoColorCodes(text)
    text = tostring(text or "")
    text = text:gsub("||c", "|c")
    text = text:gsub("||C", "|C")
    text = text:gsub("||r", "|r")
    text = text:gsub("||R", "|R")
    return text
end

local function CL_CountMemoOpenColors(text)
    if type(text) ~= "string" or not text:find("|[cC]") then return 0 end
    local openCount = 0
    for pos, code in text:gmatch("()|([cCrR])") do
        if code == "r" or code == "R" then
            if openCount > 0 then openCount = openCount - 1 end
        elseif text:sub(pos + 2, pos + 9):match("^%x%x%x%x%x%x%x%x$") then
            openCount = openCount + 1
        elseif text:find("|[cC][nN][%w_]+:", pos) == pos then
            openCount = openCount + 1
        end
    end
    return openCount
end

local function CL_UpdateMemoColorWarning(popup, text)
    local warn = popup and popup.MemoColorWarnText
    if not warn then return end
    local count = CL_CountMemoOpenColors(text)
    if count > 0 then
        warn:SetText("颜色代码未闭合，缺少 " .. count .. " 个 ||r")
        warn:Show()
    else
        warn:Hide()
    end
end

-- ── 刷新备忘笔记页签按钮样式 ───────────────────────────
local function CL_UpdateMemoTabButtons(popup)
    if not popup or not popup.TabButtons then return end
    for _, info in ipairs(CL_MemoTabs) do
        local btn = popup.TabButtons[info.key]
        if btn then
            if popup.currentMemoTab == info.key then
                btn:SetBackdropColor(0.04, 0.13, 0.08, 0.80)
                btn:SetBackdropBorderColor(0.55, 1.00, 0.65, 1)
                btn:GetFontString():SetTextColor(0.55, 1.00, 0.65, 1)
            else
                btn:SetBackdropColor(0, 0, 0, 0.20)
                btn:SetBackdropBorderColor(0.50, 0.50, 0.50, 0.85)
                btn:GetFontString():SetTextColor(0.78, 0.78, 0.78, 1)
            end
        end
    end
end

-- ── 切换备忘笔记页签 ─────────────────────────────
local function CL_SetMemoTab(popup, tabKey)
    if not popup or not popup.EditBox then return end
    local memo = CL_GetMemoDB()
    if popup.currentMemoTab then
        memo.tabTexts[popup.currentMemoTab] = CL_FixMemoColorCodes(popup.EditBox:GetText())
    end
    popup.currentMemoTab = tabKey or "logArch"
    memo.activeTab = popup.currentMemoTab
    local text = memo.tabTexts[popup.currentMemoTab] or ""
    popup.EditBox:SetText(text)
    popup.EditBox:SetCursorPosition(#text)
    popup.EditBox:ClearFocus()
    CL_UpdateMemoTabButtons(popup)
    CL_UpdateMemoScroll()
    if popup.ScrollFrame then popup.ScrollFrame:SetVerticalScroll(0) end
end

-- ── 创建或复用备忘笔记窗口 ─────────────────────────────
local function CL_EnsureMemoPopup()
    if BDCL_MemoPopup then return BDCL_MemoPopup end

    local popup = CreateFrame("Frame", "BDCL_MemoPopup", UIParent, "BackdropTemplate")
    BDCL_MemoPopup = popup

    local memo = CL_GetMemoDB()
    local savedW = memo.size and tonumber(memo.size[1])
    local savedH = memo.size and tonumber(memo.size[2])
    popup:SetSize(savedW or 740, savedH or 520)
    if memo.position then
        local pos = memo.position
        popup:SetPoint(pos[1] or "CENTER", _G[pos[2]] or UIParent, pos[3] or pos[1] or "CENTER", tonumber(pos[4]) or 0, tonumber(pos[5]) or 0)
    else
        popup:SetPoint("CENTER", UIParent, "CENTER", 150, 50)
    end
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")

    if not tContains(UISpecialFrames, "BDCL_MemoPopup") then
        table.insert(UISpecialFrames, "BDCL_MemoPopup")
    end

    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        popup:Hide()
    end)

    local titleText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", popup, "TOP", 0, -15)
    titleText:SetText("备忘笔记")
    titleText:SetTextColor(1, 1, 1)

    popup.TabButtons = {}
    for i, info in ipairs(CL_MemoTabs) do
        local tabKey = info.key
        local tabBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
        tabBtn:SetSize(22, 20)
        tabBtn:SetPoint("TOPLEFT", popup, "TOPLEFT", 24 + (i - 1) * 26, -13)
        tabBtn:SetFrameLevel(popup:GetFrameLevel() + 20)
        tabBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        local tabText = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tabText:SetPoint("CENTER", 0, 1)
        tabBtn:SetFontString(tabText)
        tabBtn:SetText(info.label)
        tabBtn:SetScript("OnClick", function()
            CL_SetMemoTab(popup, tabKey)
        end)
        popup.TabButtons[tabKey] = tabBtn
    end
    popup.bg = popup:CreateTexture(nil, "BACKGROUND")
    popup.bg:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -4)
    popup.bg:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -4, 4)
    popup.bg:SetColorTexture(0.035, 0.035, 0.035, 0.8)
    popup.Border = CreateFrame("Frame", nil, popup, "QuestLogBorderFrameTemplate")
    popup.Border:SetAllPoints(popup)
    local editorBg = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    editorBg:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -34)
    editorBg:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -24, 24)
    editorBg:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    editorBg:SetBackdropColor(0, 0, 0, 0.1)
    editorBg:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    popup.MemoLimitText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.MemoLimitText:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 24, 8)
    popup.MemoLimitText:SetText("本页即将达到单页最大存储限制，请及时清理。")
    popup.MemoLimitText:SetTextColor(1.0, 0.82, 0.0, 1)
    popup.MemoLimitText:Hide()
    popup.MemoColorWarnText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.MemoColorWarnText:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -32, 8)
    popup.MemoColorWarnText:SetTextColor(1.0, 0.35, 0.35, 1)
    popup.MemoColorWarnText:Hide()
    local scrollFrame = CreateFrame("ScrollFrame", "BDCL_MemoScrollFrame", popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", editorBg, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", editorBg, "BOTTOMRIGHT", -26, 6)
    popup.ScrollFrame = scrollFrame
    local resizeBtn = CL_CreateResizeButton(popup, 18, -5, 5)
    local editBox = CreateFrame("EditBox", "BDCL_MemoEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(CL_MEMO_MAX_LETTERS)

    -- ──（超链接）备忘录接收鼠标事件 ──────────────────────────
    editBox:EnableMouse(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(math.max(100, scrollFrame:GetWidth() - 8))
    editBox:SetAutoFocus(false)
    editBox:SetJustifyH("LEFT")
    CL_EnableSafeHLinks(editBox)
    editBox:SetScript("OnHyperlinkClick", function(self, link, text, button)
        if CL_WasHLinkDragged(self) then return end
        CL_OpenAllowedHLink(link, text, button)
    end)


    editBox:SetScript("OnEnterPressed", function(self) self:Insert("\n") end)
    editBox:SetScript("OnEscapePressed", function(self)
        if self:HasFocus() then self:ClearFocus() end
    end)
    editBox:SetScript("OnTextChanged", function(self)
        local memo = CL_GetMemoDB()
        local text = self:GetText()
        memo.tabTexts[popup.currentMemoTab or memo.activeTab or "logArch"] = CL_FixMemoColorCodes(text)
        if popup.MemoLimitText then
            popup.MemoLimitText:SetShown(#text >= CL_MEMO_WARN_LETTERS)
        end
        CL_UpdateMemoColorWarning(popup, text)
        CL_UpdateMemoScroll()
    end)
    editBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    scrollFrame:SetScrollChild(editBox)
    popup.EditBox = editBox
    CL_EnableEditBoxWheelScroll(scrollFrame, editBox)
    CL_SetMemoTab(popup, memo.activeTab or "logArch")

    editorBg:SetScript("OnMouseDown", function() editBox:SetFocus() end)
    scrollFrame:SetScript("OnMouseDown", function() editBox:SetFocus() end)
    scrollFrame:SetScript("OnSizeChanged", CL_UpdateMemoScroll)

    local function UpdateMemoAlpha(moving)
        local bgAlpha = (popup.isDragging or moving) and 0.3 or 1.0
        local textAlpha = (popup.isDragging or moving) and 0.7 or 1.0
        if popup.memoBgAlpha ~= bgAlpha then
            popup.memoBgAlpha = bgAlpha
            popup.bg:SetVertexColor(1, 1, 1, bgAlpha)
        end
        if popup.memoTextAlpha ~= textAlpha then
            popup.memoTextAlpha = textAlpha
            popup:SetAlpha(textAlpha)
        end
    end

    popup:SetScript("OnDragStart", function(self)
        self:StartMoving()
        self.isDragging = true
        UpdateMemoAlpha(self.CL_IsMoving)
    end)
    popup:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isDragging = false
        CL_SaveMemoLayout()
        UpdateMemoAlpha(self.CL_IsMoving)
    end)
    popup:HookScript("OnShow", function(self)
        CL_StartMoveTicker(self, UpdateMemoAlpha)
        if BDCL_UpdateOpenButtonStyle then BDCL_UpdateOpenButtonStyle() end
    end)

    popup:HookScript("OnHide", function(self)
        CL_StopMoveTicker(self)
        if BDCL_UpdateOpenButtonStyle then BDCL_UpdateOpenButtonStyle() end
    end)
    UpdateMemoAlpha(CL_CheckMoving())

    CL_AttachResizeBehavior(resizeBtn, popup, 490, 200, {       -- 备忘笔记最小尺寸
        onStart = function()
            popup.isDragging = true
        end,
        onResize = function()
            CL_UpdateMemoScroll()
        end,
        onFinish = function()
            popup.isDragging = false
            CL_SaveMemoLayout()
            CL_UpdateMemoScroll()
        end,
    })

    popup:Hide()

    C_Timer.After(0, CL_UpdateMemoScroll)
    return popup
end

-- ── 切换备忘笔记窗口显示状态 ─────────────────────────────
local function CL_ToggleMemo()
    local popup = CL_EnsureMemoPopup()
    if popup:IsShown() then
        popup:Hide()
    else
        popup:Show()
        if popup.EditBox then popup.EditBox:ClearFocus() end
        C_Timer.After(0, CL_UpdateMemoScroll)
    end
end

-- ── 插入日志行到备忘笔记 ─────────────────────────────
-- 【内存优化】按行裁剪而非逐字符，减少字符串操作开销
CL_InsertIntoMemo = function(line)
    if not line or line == "" then return end

    local popup = CL_EnsureMemoPopup()
    CL_SetMemoTab(popup, "logArch")

    local editBox = popup.EditBox
    local oldText = editBox:GetText() or ""
    local sep = (oldText ~= "" and oldText:sub(-1) ~= "\n") and "\n" or ""
    local newText = oldText .. sep .. line
    -- 按行裁剪，更高效
    while #newText > CL_MEMO_MAX_LETTERS and newText:find("\n", 1, true) do
        newText = newText:gsub("^[^\n]*\n", "", 1)
    end
    -- 如果仍然超长（单行极长），直接截断
    if #newText > CL_MEMO_MAX_LETTERS then
        newText = newText:sub(-CL_MEMO_MAX_LETTERS)
    end

    editBox:SetText(newText)
    popup:Show()
    C_Timer.After(0, function()
        if not popup:IsShown() then return end
        CL_UpdateMemoScroll()
        local maxOffset = math.max(0, editBox:GetHeight() - popup.ScrollFrame:GetHeight())
        popup.ScrollFrame:SetVerticalScroll(maxOffset)
    end)
end

-- ==========================================
-- 第八部分：入口按钮
-- ==========================================

_G.LNuiChat_ToggleHistory = CL_EnsureMainFrame

_G.ChatCopy = { 
    CopyFromFrame = function() 
        if _G.LNuiChat_ToggleHistory then 
            _G.LNuiChat_ToggleHistory() 
        end 
    end 
}

-- 备忘录切换接口，供 ChannelBar 右键调用
_G.LNuiChat_ToggleMemo = CL_ToggleMemo