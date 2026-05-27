local _,_,_,mygame = GetBuildInfo()
local _,ns = ...

hooksecurefunc("FriendsFrame_UpdateFriendButton", function(friendbutton)
if not friendbutton.id then return end
if friendbutton.buttonType == 3 then return end
if not C_BattleNet.GetFriendAccountInfo(friendbutton.id) then return end
local areaName = C_BattleNet.GetFriendAccountInfo(friendbutton.id).gameAccountInfo.areaName	--区域名
local realmDisplayName = C_BattleNet.GetFriendAccountInfo(friendbutton.id).gameAccountInfo.realmDisplayName	--服务器
local characterName = C_BattleNet.GetFriendAccountInfo(friendbutton.id).gameAccountInfo.characterName --角色名
local bnname = Ambiguate(C_BattleNet.GetFriendAccountInfo(friendbutton.id).battleTag,"short")	--战网名
local className = C_BattleNet.GetFriendAccountInfo(friendbutton.id).gameAccountInfo.className	--职业名
local level = C_BattleNet.GetFriendAccountInfo(friendbutton.id).gameAccountInfo.characterLevel	--等级
--local factionName = C_BattleNet.GetFriendAccountInfo(friendbutton.id).gameAccountInfo.factionName--阵营
local gamename = C_BattleNet.GetFriendAccountInfo(friendbutton.id).gameAccountInfo.wowProjectID	--游戏id,1是正式服,11是wlk
local rich = C_BattleNet.GetFriendAccountInfo(friendbutton.id).gameAccountInfo.richPresence	--丰富返回游戏版本-区域-服务器
--标题栏
local class
if characterName and className then
	for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		if v == className then
			class =RAID_CLASS_COLORS[k].colorStr
		end
	end
	friendbutton.name:SetText(bnname.."|c"..class.." ("..characterName..")".."|r    ")
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