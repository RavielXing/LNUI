local CVar = CreateFrame("Frame")
CVar:RegisterEvent("PLAYER_ENTERING_WORLD")
CVar:SetScript("OnEvent", function()
    LNuiCompat.SetCVar("displayFreeBagSlots",0)                              --背包剩余空间    1:开启      0:关闭
    LNuiCompat.SetCVar("xpBarText",1)                                        --经验条数值显示    1:开启      0:关闭
    -- SetCVar("statusText",1)                                       --显示状态数值（上载具后载具两边的血量+蓝量 数值），0：只在鼠标移到上方时显示状态数字      1：永远显示 (注：7.0开始载具蓝量不能显示，是游戏的问题)
    LNuiCompat.SetCVar("screenshotQuality",10)                               --截图品质(10最高) 
    LNuiCompat.SetCVar("screenshotFormat", "jpg")                             --截图格式，tga或jpg 
    -- SetCVar("weatherDensity",3)                                   --天气效果 1-3表示效果，0是关闭 
    LNuiCompat.SetCVar("cameraTerrainTilt",0)                                --镜头跟随地形，爬坡时往上，下坡时往下     1:开启      0:关闭
    LNuiCompat.SetCVar("minimapTrackingShowAll",1) --追踪任务目标数据
    -- SetCVar("UberTooltips", 1)     -- 鼠标提示显示技能说明					启用：1		禁用：0
    -- SetCVar("GxAllowCachelessShaderMode", 0)    -- 修复 WoW 10.0 卡顿
end)

--过图前鼠标指向声望条，过图后会报错修正（12.0兼容版）
-- 使用 hooksecurefunc 避免 taint 污染，防止 secret number 错误
if ReputationParagonFrame_SetupParagonTooltip then
hooksecurefunc("ReputationParagonFrame_SetupParagonTooltip", function(frame)
   local currentValue, threshold = C_Reputation.GetFactionParagonInfo(frame.factionID);
   if currentValue == nil or threshold == nil then
        GameTooltip:Hide();
   end
end)
end

--套装管理器20套上限
MAX_EQUIPMENT_SETS_PER_PLAYER = 100

--装备面板显示当前等级和最高等级
if PaperDollFrame_SetItemLevel then
hooksecurefunc('PaperDollFrame_SetItemLevel', function(self, unit) 
   if (unit ~= 'player') then return end 

   local total, equip = GetAverageItemLevel() 
   if (total > 0) then total = string.format('%.1f', total) end 
   if (equip > 0) then equip = string.format('%.1f', equip) end 

   local ilvl = equip 
   if (equip ~= total) then 
      ilvl = equip .. ' / ' .. total 
   end 

   -- local ilvlLine = _G[self:GetName() .. 'StatText'] 
   CharacterStatsPane.ItemLevelFrame.Value:SetText(ilvl) 

   self.tooltip =  "|cffffffff".. STAT_AVERAGE_ITEM_LEVEL .. ' ' .. ilvl 
end)
end

--给装备面板增加移动速度http://bbs.ngacn.cc/read.php?&tid=9727518
-- table.insert(PAPERDOLL_STATCATEGORIES[1].stats,{ stat = "MOVESPEED" }) 

--关于移动速度代码(不然会出现错乱) 
-- local tempstatFrame 
   -- hooksecurefunc("PaperDollFrame_SetMovementSpeed",function(statFrame, unit) 
      -- if(tempstatFrame and tempstatFrame~=statFrame)then 
        -- tempstatFrame:SetScript("OnUpdate",nil); 
      -- end 
      -- statFrame:SetScript("OnUpdate", MovementSpeed_OnUpdate); 
      -- tempstatFrame = statFrame; 
      -- statFrame:Show(); 
-- end) 

--始终显示额外能量条的数值，临时去掉
-- hooksecurefunc("UnitPowerBarAlt_SetUp", function(self)
	-- local statusFrame = self.statusFrame
	-- if statusFrame.enabled then
		-- statusFrame:Show()
		-- statusFrame.Hide = statusFrame.Show
	-- end
-- end)

-- 输入坐标标记位置
local WayPointPositionButton = CreateFrame("Button", "WayPointPositionButton",
                                           WorldMapFrame.BorderFrame.TitleContainer,
                                           "UIPanelButtonTemplate")
WayPointPositionButton:SetWidth(65)
WayPointPositionButton:SetHeight(18)
WayPointPositionButton:SetText(LOCALE_zhCN and "定位" or "定位")
WayPointPositionButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

function WayPointPositionButton:OnShow()
    WayPointPositionButton:ClearAllPoints()
    if MapsterOptionsButton and MapsterOptionsButton:IsShown() then
        WayPointPositionButton:SetPoint('RIGHT', MapsterOptionsButton, 'LEFT',
                                        0, 0)
    else
        WayPointPositionButton:SetPoint('RIGHT', WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.MaximizeButton, 'RIGHT', -25, 1)
    end
    WayPointContainer:Close()
end
WayPointPositionButton:SetScript("OnShow", WayPointPositionButton.OnShow)

-- 设置目标位置
function WayPointPositionButton:SetWayPoint(desX, desY)
    local currentViewMapID = WorldMapFrame:GetMapID()
    if C_Map.CanSetUserWaypointOnMap(currentViewMapID) then
        local point = UiMapPoint.CreateFromCoordinates(currentViewMapID,
                                                       desX / 100, desY / 100)
        C_Map.SetUserWaypoint(point)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true);
    else
        print(LOCALE_zhCN and "|cFFFF0000当前地图无法标记！|r" or "|cFFFF0000当前地图无法标记！|r")
    end
end

-- 点击定位按钮
function WayPointPositionButton.OnClick(widget, button, down)
    if button == "RightButton" then
        C_Map.ClearUserWaypoint()
        C_SuperTrack.SetSuperTrackedUserWaypoint(false);
        return
    end
    local currentViewMapID = WorldMapFrame:GetMapID()
    if not C_Map.CanSetUserWaypointOnMap(currentViewMapID) then
        print(LOCALE_zhCN and "|cFFFF0000当前地图无法标记！|r" or "|cFFFF0000当前地图无法标记！|r")
        return
    end
    if WayPointContainer then
        if WayPointContainer:IsShown() then
            local xl = WayPointContainer.CoordX:GetText():len()
            local yl = WayPointContainer.CoordY:GetText():len()
            if xl ~= 0 and yl ~= 0 then
                -- 使用tonumber将文本转换为数字，支持小数
                local x = tonumber(WayPointContainer.CoordX:GetText())
                local y = tonumber(WayPointContainer.CoordY:GetText())
                if x and y then
                    WayPointPositionButton:SetWayPoint(x, y)
                else
                    print(LOCALE_zhCN and "|cFFFF0000请输入有效的坐标数字！|r" or "|cFFFF0000请输入有效的坐标数字！|r")
                end
            end
            WayPointContainer:Close()
        else
            WayPointContainer:Show()
            WayPointContainer.CoordX:SetFocus()
        end
    end
end

WayPointPositionButton:SetScript("OnClick", WayPointPositionButton.OnClick)

-- 地图切换
function WayPointPositionButton:OnMapChanged()
    local currentViewMapID = WorldMapFrame:GetMapID()
    if C_Map.CanSetUserWaypointOnMap(currentViewMapID) then
        WayPointPositionButton:Enable()
    else
        WayPointPositionButton:Disable()
    end
end

hooksecurefunc(WorldMapFrame, "OnMapChanged",
               WayPointPositionButton.OnMapChanged)

-- 显示鼠标提示
function WayPointPositionButton:ShowTooltip(event)
    if event == "OnEnter" then
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(LOCALE_zhCN and "左键显示输入框，右键取消位置标记" or "左键显示输入框，右键取消位置标记")
        GameTooltip:Show()
    else
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:Hide()
    end
end

WayPointPositionButton:SetScript("OnEnter", function(self)
    WayPointPositionButton:ShowTooltip("OnEnter")
end)
WayPointPositionButton:SetScript("OnLeave", function(self)
    WayPointPositionButton:ShowTooltip("OnLeave")
end)

local WayPointContainer = CreateFrame("Frame", "WayPointContainer",
                                      WorldMapFrame)
WayPointContainer:SetFrameStrata("DIALOG")
WayPointContainer:SetWidth(120) -- 增加宽度以容纳更多字符
WayPointContainer:SetHeight(25)

function WayPointContainer:ChangePointWithWorldMapFrameSize()
    WayPointContainer:ClearAllPoints()
    if WorldMapFrame:IsMaximized() then
        WayPointContainer:SetPoint("RIGHT", WayPointPositionButton, "LEFT", -1, 0)
    else
        WayPointContainer:SetPoint("BOTTOM", WayPointPositionButton, "TOP", 0, 5)
    end
end

hooksecurefunc(WorldMapFrame.BorderFrame.MaximizeMinimizeFrame,"Minimize",WayPointContainer.ChangePointWithWorldMapFrameSize)
hooksecurefunc(WorldMapFrame.BorderFrame.MaximizeMinimizeFrame,"Maximize",WayPointContainer.ChangePointWithWorldMapFrameSize)

function WayPointContainer:Close()
    WayPointContainer.CoordX:SetText("")
    WayPointContainer.CoordX:ClearFocus()
    WayPointContainer.CoordY:SetText("")
    WayPointContainer.CoordY:ClearFocus()
    WayPointContainer:Hide()
end

-- 输入tab
local function OnCoordTabPressed(editBox)
    if editBox == WayPointContainer.CoordX then
        WayPointContainer.CoordX:ClearFocus()
        WayPointContainer.CoordY:SetFocus()
    else
        WayPointContainer.CoordY:ClearFocus()
        WayPointContainer.CoordX:SetFocus()
    end
end

-- 输入回车
local function OnCoordEnterPressed(editBox)
    if editBox == WayPointContainer.CoordX then
        if editBox:GetText():len() ~= 0 then
            WayPointContainer.CoordX:ClearFocus()
            WayPointContainer.CoordY:SetFocus()
        end
    else
        local xText = WayPointContainer.CoordX:GetText()
        local yText = WayPointContainer.CoordY:GetText()

        if xText:len() ~= 0 and yText:len() ~= 0 then
            -- 使用tonumber将文本转换为数字，支持小数
            local x = tonumber(xText)
            local y = tonumber(yText)
            if x and y then
                WayPointPositionButton:SetWayPoint(x, y)
                WayPointContainer:Close()
            else
                print(LOCALE_zhCN and "|cFFFF0000请输入有效的坐标数字！|r" or "|cFFFF0000请输入有效的坐标数字！|r")
            end
        elseif yText:len() ~= 0 and xText:len() == 0 then
            WayPointContainer.CoordY:ClearFocus()
            WayPointContainer.CoordX:SetFocus()
        end
    end
end

-- 创建坐标输入框
WayPointContainer.CoordY = CreateFrame("EditBox", "WayPointCoordY",
                                       WayPointContainer, "InputBoxTemplate")
WayPointContainer.CoordY:SetAutoFocus(false)
WayPointContainer.CoordY:SetSize(45, 20) -- 增加宽度
WayPointContainer.CoordY:SetNumeric(false) -- 设置为false以支持小数点
WayPointContainer.CoordY:SetMaxLetters(7) -- 允许更多字符，如"100.00"
WayPointContainer.CoordY:SetPoint("LEFT", WayPointContainer, "CENTER", 5, 0) -- 调整位置
WayPointContainer.CoordY:SetScript("OnTabPressed", OnCoordTabPressed)
WayPointContainer.CoordY:SetScript("OnEnterPressed", OnCoordEnterPressed)

-- 限制只能输入数字和小数点
-- 优化：简化坐标输入验证，减少每次按键的字符串操作和循环
local function SanitizeCoordInput(self)
    local text = self:GetText()
    -- 仅保留数字和最多一个小数点
    local newText = text:gsub("[^0-9.]", "")
    local firstDot = newText:find("%.")
    if firstDot then
        local before = newText:sub(1, firstDot)
        local after = newText:sub(firstDot+1):gsub("%.", "")
        after = after:sub(1, 2) -- 最多2位小数
        newText = before .. after
    end
    -- 限制整数部分3位（0-100）
    local numPart = newText:match("(%d+)") or ""
    if #numPart > 3 then
        newText = newText:sub(1, 3) .. (newText:match("%..*") or "")
    end
    if text ~= newText then
        self:SetText(newText)
    end
end

WayPointContainer.CoordY:SetScript("OnTextChanged", SanitizeCoordInput)

WayPointContainer.CoordX = CreateFrame("EditBox", "WayPointCoordX",
                                       WayPointContainer, "InputBoxTemplate")
WayPointContainer.CoordX:SetAutoFocus(false)
WayPointContainer.CoordX:SetSize(45, 20) -- 增加宽度
WayPointContainer.CoordX:SetNumeric(false) -- 设置为false以支持小数点
WayPointContainer.CoordX:SetMaxLetters(7) -- 允许更多字符，如"100.00"
WayPointContainer.CoordX:SetPoint("RIGHT", WayPointContainer, "CENTER", -10, 0) -- 调整位置
WayPointContainer.CoordX:SetScript("OnTabPressed", OnCoordTabPressed)
WayPointContainer.CoordX:SetScript("OnEnterPressed", OnCoordEnterPressed)

-- 对X坐标框也应用相同的文本验证
WayPointContainer.CoordX:SetScript("OnTextChanged", SanitizeCoordInput)

WayPointContainer:Hide()


--屏蔽小地图插件数字
AddonCompartmentFrame:HookScript("OnShow", AddonCompartmentFrame.Hide)
AddonCompartmentFrame:Hide()

--屏蔽右键点击设置框体（12.0兼容版：使用hooksecurefunc避免taint）
if UnitFrame_UpdateTooltip then
hooksecurefunc("UnitFrame_UpdateTooltip", function(self)
	GameTooltip_SetDefaultAnchor(GameTooltip, self);
	if ( GameTooltip:SetUnit(self.unit, self.hideStatusOnTooltip) ) then
		self.UpdateTooltip = UnitFrame_UpdateTooltip;
	else
		self.UpdateTooltip = nil;
	end
end)
end

--宏框架扩大，作者：KeiraMetz 
local resizeMacroFrame = CreateFrame("FRAME", nil)
resizeMacroFrame:RegisterEvent("ADDON_LOADED")
resizeMacroFrame:SetScript("OnEvent", function (self, event, a1, ...)
    if event == "ADDON_LOADED" and a1 == "Blizzard_MacroUI" then
        MacroFrame:SetSize(535,600)
        MacroHorizontalBarLeft:SetSize(452,16)
        MacroHorizontalBarLeft:ClearAllPoints()
        MacroHorizontalBarLeft:SetPoint("TOPLEFT", 2, -340)
        MacroFrameSelectedMacroBackground:ClearAllPoints()
        MacroFrameSelectedMacroBackground:SetPoint("TOPLEFT", 5, -348)
        MacroFrame.MacroSelector:SetSize(520,276)
        local MacroSelectorUpdated = false
        hooksecurefunc(MacroFrame, "Update", function(self, ...)
            if not MacroSelectorUpdated then
                self.MacroSelector:SetCustomStride(10);
                self.MacroSelector:Init();
                MacroSelectorUpdated = true
            end
        end)
        MacroFrameScrollFrame:SetSize(484,130)
        MacroFrameText:SetSize(484,85)
        MacroFrameTextBackground:SetSize(520,140)
        MacroFrameTextBackground:ClearAllPoints()
        MacroFrameTextBackground:SetPoint("TOPLEFT", MacroFrame, 6, -419)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)