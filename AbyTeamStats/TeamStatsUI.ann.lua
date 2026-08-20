local _, TS = ...
local L = TS.L

local annLine = {}

local function TSFrame()
    return _G[TS.FRAME_NAME]
end

local CLASS_LOCALIZED = {
    ["WARRIOR"] = "战士",
    ["PALADIN"] = "圣骑士",
    ["HUNTER"] = "猎人",
    ["ROGUE"] = "潜行者",
    ["PRIEST"] = "牧师",
    ["DEATHKNIGHT"] = "死亡骑士",
    ["SHAMAN"] = "萨满祭司",
    ["MAGE"] = "法师",
    ["WARLOCK"] = "术士",
    ["MONK"] = "武僧",
    ["DRUID"] = "德鲁伊",
    ["DEMONHUNTER"] = "恶魔猎手",
    ["EVOKER"] = "唤魔师",
}

local function GetLocalizedClass(class)
    return CLASS_LOCALIZED[class] or "未知职业"
end

local function GetPlayerAnnText(name)
    local tab = TS.TABS[TSFrame().tabIdx]
    table.wipe(annLine)
    local player = TS.db.players[name]
    if(player) then
        tinsert(annLine, "★")
        tinsert(annLine, player.name)
        tinsert(annLine, " ")
        tinsert(annLine, GetLocalizedClass(player.class))
        
        if player.gsGot then
            tinsert(annLine, " ")
            tinsert(annLine, "装等:")
            tinsert(annLine, player.gs and format("%.1f", player.gs) or "未知")
        end
        
        -- ========== 根据不同标签页定制内容 ==========
        if tab.tab == "史诗钥石评分" then
            -- 添加钥石评分
            if player.mscore then
                tinsert(annLine, " ")
                tinsert(annLine, "钥石评分:")
                tinsert(annLine, player.mscore)
            end
            
            -- 添加各地下城副本评分
            tinsert(annLine, " 副本评分:")
            local firstDungeon = true
            for i, id in ipairs(tab.specialIDs) do
                if id ~= 0 then -- 跳过总评分列
                    local data = TS.temp_data[name]
                    data = data and data["mythic"]
                    if data and data[id] then
                        if not firstDungeon then
                            tinsert(annLine, ",")
                        else
                            firstDungeon = false
                        end
                        -- 提取纯数字评分
                        local score = data[id]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                        tinsert(annLine, tab.names[i]..":"..score)
                    end
                end
            end
            
        elseif tab.tab == "千钧一发" then
            -- 添加千钧一发情况
            tinsert(annLine, " 千钧一发:")
            local firstBoss = true
            for i, idData in ipairs(tab.ids) do
                local completed = false
                if type(idData) == "table" then
                    for _, id in ipairs(idData) do
                        local statId = TS.mirror[id]
                        if statId and player.stats and player.stats[statId] and player.stats[statId] > 0 then
                            completed = true
                            break
                        end
                    end
                else
                    local statId = TS.mirror[idData]
                    if statId and player.stats and player.stats[statId] and player.stats[statId] > 0 then
                        completed = true
                    end
                end
                
                if completed then
                    if not firstBoss then
                        tinsert(annLine, ",")
                    else
                        firstBoss = false
                    end
                    tinsert(annLine, tab.names[i])
                end
            end
            if firstBoss then
                tinsert(annLine, "无")
            end
            
        elseif tab.tab == "坚韧钥石（第1赛季）" then
            -- 坚韧钥石标签页保持原有逻辑
            tinsert(annLine, " 坚韧钥石:")
            local first = true
            for i, idData in ipairs(tab.ids) do
                if idData ~= 0 then -- 跳过评分列
                    local text = TeamStatsUI_GetAchievementOrStaticText(player, idData)
                    if text and text ~= "?" and text ~= "-" and text:find("天") then
                        if not first then
                            tinsert(annLine, ",")
                        else
                            first = false
                        end
                        tinsert(annLine, tab.names[i].."("..text..")")
                    end
                end
            end
            if first then
                tinsert(annLine, "无")
            end
            
        else
            -- 其他标签页（包括总览）保持原有逻辑
            if player.mscore and tab.tab ~= "史诗钥石评分" then
                tinsert(annLine, " ")
                tinsert(annLine, "钥石评分:")
                tinsert(annLine, player.mscore or 0)
            end
            
            if tab.any_done then
                tinsert(annLine, " 千钧一发:")
                local first = true
                for i, ids in ipairs(tab.ids) do
                    local progress = TeamStatsUI_GetAchievementOrStaticText(player, ids)
                    if progress and progress ~= "?" and progress ~= "-" and progress ~= "0" then
                        if not first then
                            tinsert(annLine, ",")
                        else
                            first = false
                        end
                        tinsert(annLine, tab.names[i])
                    end
                end
                if first then
                    tinsert(annLine, "无")
                end
            else
                for i, ids in ipairs(tab.ids or {}) do
                    if tab.reports == nil or tab.reports[i] then
                        if type(ids) == "table" then
                            local progress, max = TeamStatsUI_GetAchievementOrStaticText(player, ids)
                            if progress and progress ~= 0 then
                                tinsert(annLine, " ")
                                tinsert(annLine, tab.names[i])
                                tinsert(annLine, progress.."/"..max)
                            end
                        else
                            local text = TeamStatsUI_GetAchievementOrStaticText(player, ids)
                            if text ~= "?" and text ~= "-" then
                                tinsert(annLine, " ")
                                tinsert(annLine, tab.names[i])
                                tinsert(annLine, text)
                            end
                        end
                    end
                end
            end
        end
        -- ========== 结束定制内容 ==========

        return table.concat(annLine, "")
    end
end

StaticPopupDialogs["TEAMSTATS_ANN"] = {
    preferredIndex = 3,
    text = L["BtnAnnPopupText"],
    button1 = YES,
    button2 = CANCEL,
    OnAccept = function(self)
       local tab = TS.TABS[TSFrame().tabIdx]
       local channel = self.data[1]
       local target = self.data[2]
       local selectedNames = self.data[3]  -- 获取选中的玩家列表
       
       SendChatMessage("【团员信息统计】 - "..tab.tab.."：", channel, nil, target)
       -- 修复：只遍历选中的玩家，而不是所有人
       for i=1, #selectedNames do
           local line = GetPlayerAnnText(selectedNames[i])
           if line then
               SendChatMessage(line, channel, nil, target)
           end
       end
    end,
    timeout = 0,
    hideOnEscape = 1,
    whileDead = 1,
    exclusive = 1,
}

function TeamStatsUI_BtnAnnOnClick(self)
    local count = 0
    local selectedNames = {}  -- 存储选中的玩家名字
    
    for i=1,#TS.ui_names do
        local player = TS.db.players[TS.ui_names[i]]
        if player and player.selected then 
            count = count + 1
            tinsert(selectedNames, TS.ui_names[i])  -- 收集选中的玩家名字
        end
    end

    if(count==0) then print(L["BtnAnnNoSelect"]); return; end
    
    local channel, target = 'SAY', nil
    if(IsInGroup()) then
        if(IsInRaid()) then
            channel = 'RAID'
        else
            channel = 'PARTY'
        end
    end

    -- 单选时直接插入到聊天框
    if count == 1 then
        local line = GetPlayerAnnText(selectedNames[1])
        if line then
            CoreUIChatEdit_Insert(line)
        end
    else
        -- 多选时检查当前聊天框频道
        local chatFrame = GetCVar("chatStyle")=="im" and SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
        local eb = chatFrame and chatFrame.editBox
        if eb then
            local chatType = eb:GetAttribute("chatType")
            if (chatType == "RAID" or chatType == "PARTY" or chatType == "SAY" or chatType == "INSTANCE") then
                channel = chatType
            elseif chatType == "WHISPER" then
                target = eb:GetAttribute("tellTarget")
                if target and target ~= "" then channel = chatType end
            elseif chatType == "CHANNEL" then
                target = eb:GetAttribute("channelTarget")
                if target and target ~= "" then channel = chatType end
            end
        end
        
        local channelName = channel=="RAID" and "团队" or channel=="PARTY" and "小队" or 
                           channel=="INSTANCE" and "副本" or channel=="WHISPER" and "密语:%s" or 
                           channel=="CHANNEL" and "频道:%s" or "说"
        StaticPopup_Show("TEAMSTATS_ANN", count, format(channelName, target), {channel, target, selectedNames})
    end
end