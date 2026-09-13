local _,_,_,mygame = GetBuildInfo()
local _,ns = ...

-- 12.0/12.1 兼容：FriendsFrame_UpdateFriendButton 不存在时跳过，避免 hooksecurefunc 报错
if FriendsFrame_UpdateFriendButton then
    -- 本地职业名 -> 英文职业token 反向表（一次性构建，避免每次刷新循环查找）
    local classTokens = {}
    for token, loc in pairs(LOCALIZED_CLASS_NAMES_MALE) do classTokens[loc] = token end
    for token, loc in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do classTokens[loc] = token end

    hooksecurefunc("FriendsFrame_UpdateFriendButton", function(friendbutton)
        if not friendbutton.id then return end
        if friendbutton.buttonType == 3 then return end
        -- 只查询一次账户信息，避免每个字段各调一次 GetFriendAccountInfo
        local accountInfo = C_BattleNet.GetFriendAccountInfo(friendbutton.id)
        if not accountInfo then return end
        local gameInfo = accountInfo.gameAccountInfo
        local areaName = gameInfo.areaName	--区域名
        local realmDisplayName = gameInfo.realmDisplayName	--服务器
        local characterName = gameInfo.characterName --角色名
        local bnname = Ambiguate(accountInfo.battleTag,"short")	--战网名
        local className = gameInfo.className	--职业名
        local level = gameInfo.characterLevel	--等级
        --local factionName = gameInfo.factionName--阵营
        local gamename = gameInfo.wowProjectID	--游戏id,1是正式服,11是wlk
        local rich = gameInfo.richPresence	--丰富返回游戏版本-区域-服务器
        --标题栏
        local class = characterName and className and classTokens[className]
        if class then
            friendbutton.name:SetText(bnname.."|c"..RAID_CLASS_COLORS[class].colorStr.." ("..characterName..")".."|r    ")
        end

        --信息栏
        if realmDisplayName and areaName and gamename == 1 then
            friendbutton.info:SetText(areaName.."-"..realmDisplayName.."-"..level)
        elseif areaName and gamename == 14 then
            local _,fwq = strsplit("-",rich)	--怀旧服只要服务器名字
            if realmDisplayName then
                friendbutton.info:SetText("CTM".."-"..areaName.."-"..realmDisplayName.."-"..level)
            elseif fwq then
                friendbutton.info:SetText("CTM".."-"..areaName.."-"..fwq.."-"..level)
            end
        elseif areaName and gamename == 11 then
            local _,fwq = strsplit("-",rich)	--怀旧服只要服务器名字
            if realmDisplayName then
                friendbutton.info:SetText("WLK".."-"..areaName.."-"..realmDisplayName.."-"..level)
            elseif fwq then
                friendbutton.info:SetText("WLK".."-"..areaName.."-"..fwq.."-"..level)
            end
        elseif areaName and gamename == 2 then
            local _,fwq = strsplit("-",rich)	--怀旧服只要服务器名字
            if realmDisplayName then
                friendbutton.info:SetText("(怀旧60)".."-"..areaName.."-"..realmDisplayName.."-"..level)
            elseif fwq then
                friendbutton.info:SetText("(怀旧60)".."-"..areaName.."-"..fwq.."-"..level)
            end
        end

        --对比游戏版本
        if mygame > 90000 then
            if not gamename or gamename == 1 then
                friendbutton.name:SetAlpha(1)
                friendbutton.info:SetAlpha(1)
            else
                friendbutton.name:SetAlpha(.4)
                friendbutton.info:SetAlpha(.4)
            end
        end
    end)
end
