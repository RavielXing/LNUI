local addonName, ns = ...

-- ========================================================================================================================
-- 世界地图缩放
-- ========================================================================================================================
function ns:SetMapScale(scale)
    if not RoyMapGuideDB then return end

    local scaleValue = scale or RoyMapGuideDB.mapScale or 1.0

    -- 如果地图最大化，不应用缩放
    if WorldMapFrame:IsMaximized() then
        if WorldMapFrame:GetScale() ~= 1 then
            WorldMapFrame:SetScale(1)
        end
        return
    end

    -- 应用缩放
    if WorldMapFrame:GetScale() ~= scaleValue then
        WorldMapFrame:SetScale(scaleValue)
    end
end

local function SecureHook(object, method, handler)
    if object[method] then
        hooksecurefunc(object, method, handler)
    end
end

local function WorldMapFrame_SynchronizeDisplayState()
    ns:SetMapScale()
end

-- 初始化地图缩放
local function InitializeMapScaling()
    if WorldMapFrame.SynchronizeDisplayState then
        SecureHook(WorldMapFrame, "SynchronizeDisplayState", WorldMapFrame_SynchronizeDisplayState)
    end

    ns:SetMapScale()
end

ns.RegisterEventHandler("ADDON_LOADED", function(addon)
    if addon == addonName then
        InitializeMapScaling()
    end
end)

ns.RegisterEventHandler("PLAYER_LOGIN", function()
    if RoyMapGuideDB and RoyMapGuideDB.mapScale then
        C_Timer.After(1, function()
            ns:SetMapScale()
        end)
    end
end)

-- ========================================================================================================================
-- 地图坐标和ID显示
-- ========================================================================================================================
local CoordsDisplay = {
    mouseUpdateInterval = 0.1,     -- 鼠标坐标刷新间隔
    playerUpdateInterval = 0.3,    -- 玩家坐标刷新间隔
    playerIdleCheckInterval = 1.0,
    playerIdleDuration = 6,
    -- 状态变量
    isEnabled = false,
    isMouseOverMap = false,
    playerMoving = false,
    -- 计时器
    mouseTicker = nil,
    playerTicker = nil,
    playerIdleMonitor = nil,
    playerIdleExpireAt = nil,
    -- UI元素
    frame = nil,
    mapIDText = nil,
    cursorText = nil,
    playerText = nil,
    -- 字符串缓存
    lastMapIDText = nil,
    lastCursorText = nil,
    lastPlayerText = nil,
    -- 当前地图ID缓存
    currentMapID = nil,
}

--------------------------------------------------------------------------------
-- 工具函数
--------------------------------------------------------------------------------
function CoordsDisplay:IsPlayerMoving()
    return IsPlayerMoving()
end

function CoordsDisplay:IsPlayerInTravelState()
    return self:IsPlayerMoving() or UnitOnTaxi("player") or IsFlying() or IsFalling()
end

--------------------------------------------------------------------------------
-- 地图ID更新
--------------------------------------------------------------------------------
function CoordsDisplay:UpdateMapID()
    if not self.isEnabled or not self.frame or not self.frame:IsShown() then
        return
    end

    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        if self.mapIDText and self.mapIDText:GetText() ~= "" then
            self.mapIDText:SetText("")
            self.lastMapIDText = ""
        end
        return
    end

    -- 获取当前地图ID
    local mapID = WorldMapFrame:GetMapID() or C_Map.GetBestMapForUnit("player")
    local newText = ""

    if mapID then
        self.currentMapID = mapID
        newText = string.format("MapID: %d", mapID)
    end

    if newText ~= self.lastMapIDText then
        self.mapIDText:SetText(newText)
        self.lastMapIDText = newText
    end
end

--------------------------------------------------------------------------------
-- 鼠标坐标
--------------------------------------------------------------------------------
-- 获取鼠标坐标
function CoordsDisplay:GetNormalizedCursorPosition()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return nil, nil
    end

    local scrollContainer = WorldMapFrame.ScrollContainer
    if not scrollContainer or not scrollContainer.Child then
        return nil, nil
    end

    local left, top = scrollContainer.Child:GetLeft(), scrollContainer.Child:GetTop()
    local width, height = scrollContainer.Child:GetWidth(), scrollContainer.Child:GetHeight()
    local scale = scrollContainer.Child:GetEffectiveScale()

    if not left or not top or not width or not height or width == 0 or height == 0 then
        return nil, nil
    end

    local x, y = GetCursorPosition()
    if not x or not y then
        return nil, nil
    end

    local cx = (x/scale - left) / width
    local cy = (top - y/scale) / height

    if cx < 0 or cx > 1 or cy < 0 or cy > 1 then
        return nil, nil
    end

    return cx, cy
end

-- 更新鼠标坐标
function CoordsDisplay:UpdateMouseCoords()
    if not self.isEnabled or not self.frame or not self.frame:IsShown() then
        return false
    end

    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        if self.cursorText:GetText() ~= "" then
            self.cursorText:SetText("")
            self.lastCursorText = ""
        end
        return false
    end

    local cursorX, cursorY = self:GetNormalizedCursorPosition()
    local newText = ""

    if cursorX and cursorY then
        local accuracy = RoyMapGuideDB and RoyMapGuideDB.coordsAccuracy or 1

        if accuracy == 0 then
            newText = string.format("鼠标：%.0f丨%.0f", 100 * cursorX, 100 * cursorY)
        elseif accuracy == 1 then
            newText = string.format("鼠标：%.1f丨%.1f", 100 * cursorX, 100 * cursorY)
        else
            newText = string.format("鼠标：%.2f丨%.2f", 100 * cursorX, 100 * cursorY)
        end
    end

    if newText ~= self.lastCursorText then
        self.cursorText:SetText(newText)
        self.lastCursorText = newText
    end

    return cursorX ~= nil
end

--------------------------------------------------------------------------------
-- 更新玩家坐标
--------------------------------------------------------------------------------
function CoordsDisplay:UpdatePlayerCoords()
    if not self.isEnabled or not self.frame or not self.frame:IsShown() then
        return
    end

    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        if self.playerText:GetText() ~= "" then
            self.playerText:SetText("")
            self.lastPlayerText = ""
        end
        return
    end

    local playerPos = C_Map.GetPlayerMapPosition(WorldMapFrame:GetMapID(), "player")
    local newText = ""

    if playerPos then
        local playerX, playerY = playerPos:GetXY()
        if playerX and playerY and playerX ~= 0 then
            local accuracy = RoyMapGuideDB and RoyMapGuideDB.coordsAccuracy or 1

            if accuracy == 0 then
                newText = string.format("玩家：%.0f丨%.0f", 100 * playerX, 100 * playerY)
            elseif accuracy == 1 then
                newText = string.format("玩家：%.1f丨%.1f", 100 * playerX, 100 * playerY)
            else
                newText = string.format("玩家：%.2f丨%.2f", 100 * playerX, 100 * playerY)
            end
        end
    end

    if newText ~= self.lastPlayerText then
        self.playerText:SetText(newText)
        self.lastPlayerText = newText
    end
end

--------------------------------------------------------------------------------
-- 更新所有显示元素
--------------------------------------------------------------------------------
function CoordsDisplay:UpdateAllDisplays()
    self:UpdateMapID()
    self:UpdatePlayerCoords()
    if self.isMouseOverMap then
        self:UpdateMouseCoords()
    end
end

--------------------------------------------------------------------------------
-- 更新器管理
--------------------------------------------------------------------------------
-- 鼠标更新器
function CoordsDisplay:StartMouseUpdater()
    if self.mouseTicker then return end

    self:UpdateMouseCoords()

    self.mouseTicker = C_Timer.NewTicker(self.mouseUpdateInterval, function()
        if not self.isEnabled or not WorldMapFrame or not WorldMapFrame:IsShown() then
            self:StopMouseUpdater()
            return
        end
        self:UpdateMouseCoords()
    end)
end

function CoordsDisplay:StopMouseUpdater()
    if self.mouseTicker then
        self.mouseTicker:Cancel()
        self.mouseTicker = nil
    end
end

-- 玩家更新器
function CoordsDisplay:StartPlayerUpdater()
    if self.playerTicker then return end

    self:UpdatePlayerCoords()
    self:UpdateMapID()

    self.playerTicker = C_Timer.NewTicker(self.playerUpdateInterval, function()
        if not self.isEnabled then
            self:StopPlayerUpdater()
            return
        end
        
        self:UpdatePlayerCoords()
        self:UpdateMapID()
        
        if not self:IsPlayerInTravelState() then
            self:StopPlayerUpdater()
            self:StartIdleMonitor(false)
        end
    end)
end

function CoordsDisplay:StopPlayerUpdater()
    if self.playerTicker then
        self.playerTicker:Cancel()
        self.playerTicker = nil
    end
end

--------------------------------------------------------------------------------
-- 玩家静止检测器管理
--------------------------------------------------------------------------------
function CoordsDisplay:StartIdleMonitor(persistent)
    if self.playerTicker then return end

    if persistent then
        self.playerIdleExpireAt = nil
    else
        self.playerIdleExpireAt = GetTime() + self.playerIdleDuration
    end

    if self.playerIdleMonitor then return end

    self.playerIdleMonitor = C_Timer.NewTicker(self.playerIdleCheckInterval, function()
        if not self.isEnabled then
            self:StopIdleMonitor()
            return
        end

        if self.playerTicker then
            self:StopIdleMonitor()
            return
        end

        if self.playerIdleExpireAt and GetTime() >= self.playerIdleExpireAt then
            self:StopIdleMonitor()
            return
        end

        if self:IsPlayerInTravelState() then
            self:StartPlayerUpdater()
            self:UpdateAllDisplays()
        end
    end)
end

function CoordsDisplay:StopIdleMonitor()
    if self.playerIdleMonitor then
        self.playerIdleMonitor:Cancel()
        self.playerIdleMonitor = nil
    end
    self.playerIdleExpireAt = nil
end

--------------------------------------------------------------------------------
-- 刷新跟踪状态
--------------------------------------------------------------------------------
function CoordsDisplay:RefreshTrackingState()
    if not self.isEnabled then
        return
    end

    -- 玩家跟踪
    if self:IsPlayerInTravelState() then
        self:StartPlayerUpdater()
    else
        self:StopPlayerUpdater()
        self:StartIdleMonitor(false)
    end

    -- 鼠标跟踪
    if WorldMapFrame and WorldMapFrame:IsShown() and self.isMouseOverMap then
        self:StartMouseUpdater()
    else
        self:StopMouseUpdater()
        if self.cursorText and self.cursorText:GetText() ~= "" then
            self.cursorText:SetText("")
            self.lastCursorText = ""
        end
    end

    -- 打开地图时强制刷新所有显示
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:UpdateAllDisplays()
    end
end

--------------------------------------------------------------------------------
-- 应用样式
--------------------------------------------------------------------------------
function CoordsDisplay:ApplyStyle()
    if not self.frame then return end

    local fontSize = RoyMapGuideDB and RoyMapGuideDB.coordsFontSize or 14
    local fontPath = GameFontNormal:GetFont()
    local textColor = RoyMapGuideDB and RoyMapGuideDB.coordsTextColor or "FFFFFFFF"
    local r, g, b = ns.HexToRGBA(textColor)

    for _, textObj in ipairs({self.mapIDText, self.cursorText, self.playerText}) do
        if textObj then
            textObj:SetFont(fontPath, fontSize, "OUTLINE")
            textObj:SetTextColor(r, g, b)
        end
    end

    self.lastMapIDText = nil
    self.lastCursorText = nil
    self.lastPlayerText = nil
    self:UpdateAllDisplays()
end

--------------------------------------------------------------------------------
-- 应用垂直位移
--------------------------------------------------------------------------------
function CoordsDisplay:ApplyVerticalOffset()
    if not self.frame or not WorldMapFrame or not WorldMapFrame.ScrollContainer then
        return
    end

    local offset = RoyMapGuideDB and RoyMapGuideDB.coordsVerticalOffset or 0

    self.mapIDText:ClearAllPoints()
    self.cursorText:ClearAllPoints()
    self.playerText:ClearAllPoints()

    self.mapIDText:SetPoint("LEFT", WorldMapFrame.ScrollContainer, "LEFT", 10, offset)
    self.cursorText:SetPoint("LEFT", WorldMapFrame.ScrollContainer, "CENTER", 30, offset)
    self.playerText:SetPoint("RIGHT", WorldMapFrame.ScrollContainer, "CENTER", -30, offset)
end

--------------------------------------------------------------------------------
-- 创建样式
--------------------------------------------------------------------------------
function CoordsDisplay:CreateUI()
    if self.frame then return end

    self.frame = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)

    self.mapIDText = self.frame:CreateFontString(nil, "OVERLAY")
    self.cursorText = self.frame:CreateFontString(nil, "OVERLAY")
    self.playerText = self.frame:CreateFontString(nil, "OVERLAY")

    self:ApplyStyle()
    self:ApplyVerticalOffset()

    self.lastMapIDText = ""
    self.lastCursorText = ""
    self.lastPlayerText = ""
end

--------------------------------------------------------------------------------
-- 鼠标检测
--------------------------------------------------------------------------------
function CoordsDisplay:SetupMouseDetection()
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then
        return
    end

    local scrollContainer = WorldMapFrame.ScrollContainer

    scrollContainer:HookScript("OnEnter", function()
        self.isMouseOverMap = true
        if self.isEnabled then
            self:StartMouseUpdater()
        end
    end)

    scrollContainer:HookScript("OnLeave", function()
        self.isMouseOverMap = false
        if not WorldMapFrame:IsShown() then
            self:StopMouseUpdater()
            if self.cursorText then
                self.cursorText:SetText("")
                self.lastCursorText = ""
            end
        end
    end)

    scrollContainer:HookScript("OnMouseWheel", function()
        if self.isEnabled and self.isMouseOverMap then
            self:UpdateMouseCoords()
        end
    end)
end

--------------------------------------------------------------------------------
-- 功能启用和禁用
--------------------------------------------------------------------------------
function CoordsDisplay:Enable()
    self.isEnabled = true

    if not self.frame then
        self:CreateUI()
        self:SetupMouseDetection()
    end

    self.frame:Show()
    self.isMouseOverMap = WorldMapFrame.ScrollContainer and 
                          WorldMapFrame.ScrollContainer:IsMouseOver()

    self:UpdateAllDisplays()
    if self.isMouseOverMap then
        self:UpdateMouseCoords()
    end

    self:RefreshTrackingState()
end

function CoordsDisplay:Disable()
    self.isEnabled = false

    self:StopMouseUpdater()
    self:StopPlayerUpdater()
    self:StopIdleMonitor()

    if self.frame then
        self.frame:Hide()
    end

    self.lastMapIDText = ""
    self.lastCursorText = ""
    self.lastPlayerText = ""
end

--------------------------------------------------------------------------------
-- 接口
--------------------------------------------------------------------------------
function ns:ToggleCoordsDisplay()
    if not RoyMapGuideDB then return end

    if RoyMapGuideDB.isShowCoords then
        CoordsDisplay:Enable()
    else
        CoordsDisplay:Disable()
    end
end

function ns:UpdateCoordsFontSize()
    CoordsDisplay:ApplyStyle()
end

function ns:UpdateCoordsTextColor()
    CoordsDisplay:ApplyStyle()
end

function ns:UpdateCoordsVerticalOffset()
    CoordsDisplay:ApplyVerticalOffset()
end

function ns:UpdateCoordsDisplay()
    CoordsDisplay.lastCursorText = nil
    CoordsDisplay.lastPlayerText = nil
    CoordsDisplay:UpdateAllDisplays()
end

--------------------------------------------------------------------------------
-- 事件
--------------------------------------------------------------------------------
local function SetupEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_STARTED_MOVING")
    eventFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

    eventFrame:SetScript("OnEvent", function(_, event)
        if not RoyMapGuideDB or not RoyMapGuideDB.isShowCoords then
            return
        end

        if event == "PLAYER_STARTED_MOVING" then
            CoordsDisplay:StartPlayerUpdater()
            return
        end

        CoordsDisplay:RefreshTrackingState()
    end)

    -- 地图钩子
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            if RoyMapGuideDB and RoyMapGuideDB.isShowCoords then
                CoordsDisplay:UpdateAllDisplays()
                CoordsDisplay:RefreshTrackingState()
            end
        end)
        
        WorldMapFrame:HookScript("OnHide", function()
            CoordsDisplay:StopMouseUpdater()
            if CoordsDisplay.cursorText then
                CoordsDisplay.cursorText:SetText("")
                CoordsDisplay.lastCursorText = ""
            end
        end)
        
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            if RoyMapGuideDB and RoyMapGuideDB.isShowCoords then
                CoordsDisplay.lastMapIDText = nil
                CoordsDisplay.lastPlayerText = nil
                CoordsDisplay:UpdateAllDisplays()
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------
local function Initialize()
    SetupEvents()
    
    if RoyMapGuideDB and RoyMapGuideDB.isShowCoords then
        C_Timer.After(1, function()
            CoordsDisplay:Enable()
        end)
    end
end

C_Timer.After(1, Initialize)

-- ========================================================================================================================
-- 全地图NPC标记
-- ========================================================================================================================
local COMPENSATION_FACTOR = 0.1
local MARKER_FRAME_STRATA = "MEDIUM"
local GLOW_ATLAS = "GearEnchant_IconBorder"
local GLOW_COLOR = {r = 1, g = 1, b = 1, a = 1}
local GLOW_BLEND_MODE = "ADD"
local GLOW_SCALE = 1.3
local floor = math.floor

-- 颜色定义表
local COLOR_TABLE = {
    ["portal"] = {r = 0, g = 0.87, b = 1},
    ["inn"] = {r = 0, g = 1, b = 0},
    ["official"] = {r = 1, g = 1, b = 0},
    ["profession"] = {r = 1, g = 1, b = 1},
    ["service"] = {r = 1, g = 0, b = 1},
    ["stable"] = {r = 1, g = 0.6, b = 0},
    ["collection"] = {r = 1, g = 0.53, b = 0.8},
    ["vendor"] = {r = 0.67, g = 0.2, b = 1},
    ["unique"] = {r = 0.2, g = 0.4, b = 1},
    ["special"] = {r = 0, g = 1, b = 0.73},
    ["quartermaster"] = {r = 1, g = 0.31, b = 0},
    ["pvp"] = {r = 1, g = 0.25, b = 0.25},
    ["instance"] = {r = 1, g = 0, b = 0.33},
    ["delve"] = {r = 0.47, g = 0.47, b = 1},
}

-- 专业映射表
local PROFESSION_TO_SKILLLINE = {
    ["Alchemy"] = 171,
    ["Archaeology"] = 794,
    ["Blacksmithing"] = 164,
    ["Cooking"] = 185,
    ["Enchanting"] = 333,
    ["Engineering"] = 202,
    ["Fishing"] = 356,
    ["Herbalism"] = 182,
    ["Inscription"] = 773,
    ["Jewelcrafting"] = 755,
    ["Leatherworking"] = 165,
    ["Mining"] = 186,
    ["Skinning"] = 393,
    ["Tailoring"] = 197,
}

-- 数据库导入
local MARKER_DATABASE = RoyMapGuide_MAP_DATA or {}
if not next(MARKER_DATABASE) then
    print("|cFF33FF99RoyMapGuide|r丨数据库加载失败")
end

--------------------------------------------------------------------------------
-- 核心定义
--------------------------------------------------------------------------------
local MapMarkers = {
    activeMarkers = {},
    dynamicMarkers = {},
    playerProfessions = {},
    persistentDynamicMarkers = {},
    processedDynamicPins = {},
    hooksRegistered = false,
    professionEventFrame = nil,
    professionLastUpdate = 0,

    -- 对象池
    markerPool = {
        frames = {},
        currentMarkerType = nil
    },
    poolConfig = {
        maxKeep = 80,
        cleanupOnHide = true
    },

    -- 模板表
    templates = RoyMapGuide_MAP_DATA_TEMPLATES or {},
}

--------------------------------------------------------------------------------
-- 路径点功能
--------------------------------------------------------------------------------
-- 创建路径点
local function CreateWaypoint(uiMapID, x, y)
    if not C_Map.CanSetUserWaypointOnMap(uiMapID) then
        return false
    end
    
    C_Map.ClearUserWaypoint()
    C_Map.SetUserWaypoint({ uiMapID = uiMapID, position = { x = x, y = y } })
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    return true
end

-- 标记点击处理
local function OnMarkerClick(frame, button, marker)
    if not RoyMapGuideDB or not RoyMapGuideDB.enableMarkerWaypoint then
        return
    end
    
    -- 有icon字段才支持创建路径点
    if not marker.icon then
        return
    end
    
    local mapID = WorldMapFrame:GetMapID()
    if not mapID then
        return
    end
    
    local x, y = MapMarkers:GetXY(marker.coord)
    
    if button == "LeftButton" then
        CreateWaypoint(mapID, x, y)
    elseif button == "RightButton" then
        C_Map.ClearUserWaypoint()
    end
end

--------------------------------------------------------------------------------
-- 工具函数
--------------------------------------------------------------------------------
-- 坐标转换
function MapMarkers:GetXY(coord)
    if not coord then return 0, 0 end
    local x = floor(coord / 10000) / 10000
    local y = (coord % 10000) / 10000
    return x, y
end

-- 地图缩放因子
function MapMarkers:GetMapScaleFactor()
    if not WorldMapFrame.ScrollContainer or not WorldMapFrame.ScrollContainer.Child then
        return 1.0
    end

    local mapScale = WorldMapFrame.ScrollContainer.Child:GetScale()
    if not mapScale or mapScale == 0 then
        return 1.0
    end

    return (1 / mapScale) ^ 0.7
end

-- 全局大小
function MapMarkers:GetGlobalSize()
    if RoyMapGuideDB and RoyMapGuideDB.globalMarkerSize then
        return RoyMapGuideDB.globalMarkerSize
    end
    return 18
end

-- 获取地图缩放级别
function MapMarkers:GetMapZoomLevel()
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then
        return 0
    end

    local scrollContainer = WorldMapFrame.ScrollContainer
    local currentScale = scrollContainer.Child:GetScale()

    -- 实际缩放比例
    local scaleSteps = {
        0.18151038,
        0.25930055,
        0.33709071,
        0.41488088,
        0.49267104,
        0.57046121,
        0.64825137,
        0.72604154
    }

    local nativeLevel = 1
    local epsilon = 0.0000001  -- 浮点误差容忍

    -- 匹配原生缩放级别
    for i = #scaleSteps, 1, -1 do
        if currentScale >= (scaleSteps[i] - epsilon) then
            nativeLevel = i
            break
        end
    end

    local wheelTimes = nativeLevel - 1
    wheelTimes = math.max(0, math.min(7, wheelTimes))

    return wheelTimes
end

-- 模板解析函数
function MapMarkers:ResolveMarker(marker)
    if not marker.template then
        return marker
    end
    
    local template = self.templates[marker.template]
    if not template then
        return marker
    end
    
    local resolved = {}
    for k, v in pairs(template) do
        resolved[k] = v
    end
    for k, v in pairs(marker) do
        if k ~= "template" then
            if v == nil then
                resolved[k] = nil
            else
                resolved[k] = v
            end
        end
    end
    
    return resolved
end

--------------------------------------------------------------------------------
-- 动态捕获
--------------------------------------------------------------------------------
-- 核心处理函数
function MapMarkers:ProcessDynamicPin(pin, configGetter)
    if not RoyMapGuideDB or not RoyMapGuideDB.enableMapMarkers then return end
    if not pin or not pin.GetOwningMap then return end
    if pin:GetOwningMap() ~= WorldMapFrame then return end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end

    local mapData = MARKER_DATABASE[mapID]
    if not mapData then return end

    local name = pin.name
    if not name or name == "" then return end

    local displayName, colorKey = configGetter(mapData, name)
    if not displayName or not colorKey then return end

    local switchKey = "mapMarkers" .. colorKey:gsub("^%l", string.upper)
    if RoyMapGuideDB[switchKey] == false then return end

    local coord = self:GetPinCoord(pin)
    if not coord then return end

    local uniqueKey = mapID .. "_" .. name .. "_" .. coord
    if self.processedDynamicPins[uniqueKey] then return end
    self.processedDynamicPins[uniqueKey] = true

    -- 创建标记数据
    local marker = {
        coord = coord,
        text = displayName,
        color = colorKey,
        textA = "CENTER",
        isDynamic = true,
        mapID = mapID,
        name = name,
    }

    self.persistentDynamicMarkers[uniqueKey] = marker
    table.insert(self.dynamicMarkers, marker)

    if WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == mapID then
        self:AddDynamicMarker(marker)
    end
end

-- 动态捕获通用POI标记
function MapMarkers:OnPOIPinAcquired(pin)
    self:ProcessDynamicPin(pin, function(mapData, name)
        if not mapData.poiNames or not mapData.poiNames[name] then return end
        local config = mapData.poiNames[name]
        return config.text, config.color
    end)
end

-- 动态捕获地图链接标记
function MapMarkers:OnMapLinkPinAcquired(pin)
    self:ProcessDynamicPin(pin, function(mapData, name)
        if not mapData.maplinkNames or not mapData.maplinkNames[name] then return end
        return mapData.maplinkNames[name], "portal"
    end)
end

-- 动态捕获副本
function MapMarkers:OnInstancePinAcquired(pin)
    self:ProcessDynamicPin(pin, function(mapData, name)
        if not mapData.instanceNames or not mapData.instanceNames[name] then return end
        return mapData.instanceNames[name], "instance"
    end)
end

-- 动态捕获地下堡
function MapMarkers:OnDelvePinAcquired(pin)
    self:ProcessDynamicPin(pin, function(mapData, name)
        if not mapData.delveNames or not mapData.delveNames[name] then return end
        return mapData.delveNames[name], "delve"
    end)
end

-- 从Pin获取坐标
function MapMarkers:GetPinCoord(pin)
    if not pin or not pin.GetPosition then return nil end
    local x, y = pin:GetPosition()
    if not x or not y then return nil end
    return floor(x * 10000) * 10000 + floor(y * 10000)
end

function MapMarkers:AddDynamicMarker(marker)
    if not marker or not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end

    local mapWidth, mapHeight = canvas:GetWidth(), canvas:GetHeight()
    local markerFrame = self:CreateMarker(canvas, marker, mapWidth, mapHeight, 1.0)
    if markerFrame then
        markerFrame.markerData = {
            mapID = marker.mapID,
            text = marker.text,
            color = marker.color
        }
        table.insert(self.activeMarkers, markerFrame)
    end
end

--------------------------------------------------------------------------------
-- 专业过滤
--------------------------------------------------------------------------------
-- 更新玩家专业信息
function MapMarkers:UpdatePlayerProfessions()
    local prof1, prof2, arch, fish, cook = GetProfessions()
    
    for k in pairs(self.playerProfessions) do
        self.playerProfessions[k] = nil
    end
    
    for _, prof in ipairs({prof1, prof2, arch, fish, cook}) do
        if prof then
            local name, _, _, _, _, _, skillLine = GetProfessionInfo(prof)
            self.playerProfessions[skillLine] = name
        end
    end
    
    self.professionLastUpdate = GetTime()
end

-- 初始化专业系统
function MapMarkers:InitializeProfessions()
    self:UpdatePlayerProfessions()
    
    self.professionEventFrame = CreateFrame("Frame")
    self.professionEventFrame:RegisterEvent("SKILL_LINES_CHANGED")
    self.professionEventFrame:SetScript("OnEvent", function()
        self:UpdatePlayerProfessions()
        self:UpdateMapMarkers()
    end)
end

-- 专业过滤检查
function MapMarkers:ShouldShowByProfession(marker)
    if not RoyMapGuideDB or not RoyMapGuideDB.mapMarkerProfessionFilter then
        return true
    end
    
    if not marker.type then
        return true
    end
    
    local types = {}
    
    if type(marker.type) == "table" then
        types = marker.type
    elseif type(marker.type) == "string" then
        types = {marker.type}
    else
        return true
    end
    
    -- 通用专业豁免
    for _, professionType in ipairs(types) do
        if professionType == "Fishing" or professionType == "Archaeology" or professionType == "Cooking" then
            return true
        end
        local skillLine = PROFESSION_TO_SKILLLINE[professionType]
        if skillLine and self.playerProfessions[skillLine] then
            return true
        end
    end
    
    return false
end

-- 类型开关检查
function MapMarkers:ShouldShowByType(marker)
    if not RoyMapGuideDB then return true end
    
    -- 类型开关表
    local typeSwitches = {
        portal = RoyMapGuideDB.mapMarkersPortal,
        inn = RoyMapGuideDB.mapMarkersInn,
        official = RoyMapGuideDB.mapMarkersOfficial,
        profession = RoyMapGuideDB.mapMarkersProfession,
        service = RoyMapGuideDB.mapMarkersService,
        stable = RoyMapGuideDB.mapMarkersStable,
        collection = RoyMapGuideDB.mapMarkersCollection,
        vendor = RoyMapGuideDB.mapMarkersVendor,
        unique = RoyMapGuideDB.mapMarkersUnique,
        special = RoyMapGuideDB.mapMarkersSpecial,
        quartermaster = RoyMapGuideDB.mapMarkersQuartermaster,
        pvp = RoyMapGuideDB.mapMarkersPvp,
        instance = RoyMapGuideDB.mapMarkersInstance,
        delve = RoyMapGuideDB.mapMarkersDelve
    }
    
    -- 处理混合标记
    if marker.tags and #marker.tags > 0 then
        -- 去重检查
        local checked = {}
        
        for _, tag in ipairs(marker.tags) do
            if not checked[tag] then
                checked[tag] = true
                
                local switchValue = typeSwitches[tag]
                if switchValue == nil or switchValue == true then
                    return true
                end
            end
        end
        
        return false
    end
    
    -- 处理普通标记
    if not marker.color then return true end
    
    local colorType = marker.color
    local switchValue = typeSwitches[colorType]
    
    return switchValue == nil or switchValue == true
end

-- 聚合/独立标记切换
function MapMarkers:ShouldShowMarkerByZoom(marker)
    -- 开启专业过滤，强制显示独立标记
    if RoyMapGuideDB and RoyMapGuideDB.mapMarkerProfessionFilter then
        if marker.color == "profession" then
            if marker.isAggregate then
                return false
            end
            return true
        end
    end

    local threshold = RoyMapGuideDB and RoyMapGuideDB.markerZoomThreshold
    if threshold == nil then
        threshold = 2
    end

    -- 关闭专业过滤，正常判断
    local zoomLevel = self:GetMapZoomLevel() or 0
    if not marker.isAggregate and not marker.isIndividual then
        return true
    end
    if marker.isAggregate == nil and marker.isIndividual == nil then
        return true
    end
    if zoomLevel < threshold then
        return marker.isAggregate == true
    end
    return marker.isIndividual == true
end

--------------------------------------------------------------------------------
-- 对象池清理函数
--------------------------------------------------------------------------------
-- 对象池清理函数
function MapMarkers:CleanupObjectPool()
    local maxKeep = self.poolConfig.maxKeep
    local keepCount = math.min(maxKeep, #self.markerPool.frames)
    
    -- 保留 maxKeep 个标记在池中，其余的彻底销毁
    while #self.markerPool.frames > keepCount do
        local frame = table.remove(self.markerPool.frames, #self.markerPool.frames)
        if frame then
            if frame.texture then
                frame.texture:SetTexture(nil)
                frame.texture = nil
            end
            if frame.fontString then
                frame.fontString:SetText("")
            end
            if frame.Glow then
                frame.Glow:SetTexture(nil)
                frame.Glow = nil
            end
            frame:Destroy()
        end
    end
end

--------------------------------------------------------------------------------
-- 城市过滤
--------------------------------------------------------------------------------
function MapMarkers:ShouldShowByCity(mapData)
    if not mapData or not mapData.group then return true end
    if not RoyMapGuideDB then return true end
    
    local configKey = "show" .. mapData.group
    return RoyMapGuideDB[configKey] ~= false
end

function MapMarkers:GetCityScale(mapData)
    if not mapData or not mapData.group then return 1.0 end
    if not RoyMapGuideDB then return 1.0 end
    
    local configKey = "scale" .. mapData.group
    local scale = RoyMapGuideDB[configKey]
    if scale and type(scale) == "number" then
        return scale
    end
    return 1.0
end

function MapMarkers:GetMarkers(mapData)
    local markers = {}
    if mapData then
        for _, item in ipairs(mapData) do
            if item.coord then
                -- 解析模板
                local resolved = self:ResolveMarker(item)
                table.insert(markers, resolved)
            end
        end
    end
    return markers
end

--------------------------------------------------------------------------------
-- 鼠标提示
--------------------------------------------------------------------------------
function MapMarkers:AddMarkerTooltip(frame, marker)
    local tooltipsEnabled = RoyMapGuideDB and RoyMapGuideDB.mapMarkerTooltips
    if not tooltipsEnabled or not marker.title then 
        frame:EnableMouse(false)
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        return 
    end
    
    frame:EnableMouse(true)
    
    frame:SetScript("OnEnter", function(self)
        if not (RoyMapGuideDB and RoyMapGuideDB.mapMarkerTooltips) then return end
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(marker.title, 1, 0.82, 0)
        if marker.info then
            GameTooltip:AddLine(marker.info, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

--------------------------------------------------------------------------------
-- 对象池管理函数
--------------------------------------------------------------------------------
function MapMarkers:GetMarkerFromPool()
    if #self.markerPool.frames > 0 then
        local frame = table.remove(self.markerPool.frames)
        frame:Show()
        return frame
    end
    return nil
end

function MapMarkers:ReturnMarkerToPool(frame)
    if not frame then return end
    
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(nil)
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
    
    if frame.fontString then
        frame.fontString:SetText("")
        frame.fontString:Hide()
    end
    
    if frame.texture then
        frame.texture:SetTexture(nil)
        frame.texture:Hide()
    end
    
    if frame.Glow then
        frame.Glow:Hide()
    end
    
    table.insert(self.markerPool.frames, frame)
end

--------------------------------------------------------------------------------
-- 创建文本标记
--------------------------------------------------------------------------------
function MapMarkers:CreateTextMarker(parent, marker, mapWidth, mapHeight, cityScale)
    cityScale = cityScale or 1.0
    
    -- 尝试从对象池获取
    local textFrame = self:GetMarkerFromPool()
    local isReused = textFrame ~= nil
    
    local frameLevel = RoyMapGuideDB and RoyMapGuideDB.markerFrameLevel or 2200

    if not textFrame then
        -- 创建新标记
        textFrame = CreateFrame("Frame", nil, parent)
        textFrame:SetFrameStrata(MARKER_FRAME_STRATA)
        textFrame:SetFrameLevel(frameLevel)
        textFrame.fontString = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    else
        -- 复用现有标记
        textFrame:SetParent(parent)
        textFrame:SetFrameStrata(MARKER_FRAME_STRATA)
        textFrame:SetFrameLevel(frameLevel)
    end
    
    local fontString = textFrame.fontString

    if not fontString then
        textFrame.fontString = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fontString = textFrame.fontString
    end
    fontString:Show()
    
    -- 计算位置和大小
    local x, y = self:GetXY(marker.coord)
    local reverseScale = self:GetMapScaleFactor()

    -- 应用城市缩放倍数：全局大小 × 城市缩放倍数 × 地图缩放系数
    local finalTextSize = self:GetGlobalSize() * cityScale * reverseScale
    
    local fontPath = GameFontNormal:GetFont()
    local outlineStyle = RoyMapGuideDB and RoyMapGuideDB.mapMarkerTextOutline or ""
    fontString:SetFont(fontPath, finalTextSize, outlineStyle)
    fontString:SetShadowOffset(0, 0)
    
    fontString:SetText(marker.text or "")
    local color = COLOR_TABLE[marker.color] or {r = 1, g = 1, b = 1}
    fontString:SetTextColor(color.r, color.g, color.b, 1)

    if textFrame.texture then
        textFrame.texture:Hide()
    end
    
    local textWidth = fontString:GetStringWidth()
    local textHeight = fontString:GetStringHeight()
    textFrame:SetSize(textWidth, textHeight)
    
    local posX = x * mapWidth
    local posY = -y * mapHeight
    local offsetX = (marker.offsetX or 0) * reverseScale
    local offsetY = (marker.offsetY or 0) * reverseScale

    -- 对动态捕获标记应用上下偏移
    if marker.isDynamic then
        local dynamicOffset = RoyMapGuideDB and RoyMapGuideDB.dynamicMarkerYOffset or 0
        offsetY = offsetY + dynamicOffset * reverseScale
    end
    
    -- 设置锚点和位置
    local textAnchor = marker.textA or "CENTER"
    
    if textAnchor == "CENTER" then
        fontString:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
        fontString:SetJustifyH("CENTER")
        textFrame:SetPoint("CENTER", parent, "TOPLEFT", posX + offsetX, posY + offsetY)
        
    elseif textAnchor == "RIGHT" then
        fontString:SetPoint("LEFT", textFrame, "LEFT", 0, 0)
        fontString:SetJustifyH("LEFT")
        local compensation = textWidth * COMPENSATION_FACTOR
        local finalX = posX - compensation + offsetX
        textFrame:SetPoint("LEFT", parent, "TOPLEFT", finalX, posY + offsetY)
        
    elseif textAnchor == "LEFT" then
        fontString:SetPoint("RIGHT", textFrame, "RIGHT", 0, 0)
        fontString:SetJustifyH("RIGHT")
        local compensation = textWidth * COMPENSATION_FACTOR
        local finalX = posX + compensation + offsetX
        textFrame:SetPoint("RIGHT", parent, "TOPLEFT", finalX, posY + offsetY)
    end
    
    -- 添加鼠标提示
    self:AddMarkerTooltip(textFrame, marker)
    
    -- 路径点功能
    if marker.icon then
        textFrame:EnableMouse(true)
        textFrame:SetMouseClickEnabled(true)
        textFrame:SetScript("OnMouseDown", function(_, button)
            OnMarkerClick(textFrame, button, marker)
        end)
    else
        textFrame:EnableMouse(false)
        textFrame:SetMouseClickEnabled(false)
        textFrame:SetScript("OnMouseDown", nil)
    end
    
    -- 存储标记数据以便缩放时更新
    if not isReused then
        textFrame.markerData = {}
    end
    textFrame.markerData.coord = marker.coord
    textFrame.markerData.offsetX = marker.offsetX
    textFrame.markerData.offsetY = marker.offsetY
    textFrame.markerData.cityScale = cityScale
    textFrame.markerData.text = marker.text
    textFrame.markerData.color = marker.color
    textFrame.markerData.textA = marker.textA
    textFrame.markerData.isIcon = false
    
    return textFrame
end

--------------------------------------------------------------------------------
-- 创建图标标记
--------------------------------------------------------------------------------
function MapMarkers:CreateIconMarker(parent, marker, mapWidth, mapHeight, cityScale)
    cityScale = cityScale or 1.0
    
    -- 尝试从对象池获取
    local iconFrame = self:GetMarkerFromPool()
    local isReused = iconFrame ~= nil
    
    local frameLevel = RoyMapGuideDB and RoyMapGuideDB.markerFrameLevel or 2200

    if not iconFrame then
        -- 创建新标记
        iconFrame = CreateFrame("Frame", nil, parent)
    else
        -- 复用现有标记
        iconFrame:SetParent(parent)
    end

    iconFrame:SetFrameStrata(MARKER_FRAME_STRATA)
    iconFrame:SetFrameLevel(frameLevel)
    
    -- 计算大小
    local x, y = self:GetXY(marker.coord)
    local reverseScale = self:GetMapScaleFactor()

    -- 应用城市缩放倍数：全局大小 × 城市缩放倍数 × 图标比例 × 地图缩放系数
    local finalIconSize = self:GetGlobalSize() * cityScale * 1.5 * reverseScale
    iconFrame:SetSize(finalIconSize, finalIconSize)

    if not iconFrame.texture then
        iconFrame.texture = iconFrame:CreateTexture(nil, "ARTWORK")
        iconFrame.texture:SetAllPoints()
    end
    iconFrame.texture:Show()
    iconFrame.texture:SetTexture(marker.icon or 134414)
    
    -- 发光效果
    local glowEnabled = RoyMapGuideDB and RoyMapGuideDB.mapMarkerIconGlow == "GLOW"
    if glowEnabled then
        if not iconFrame.Glow then
            local glow = iconFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
            glow:SetAtlas(GLOW_ATLAS)
            glow:SetVertexColor(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, GLOW_COLOR.a)
            glow:SetBlendMode(GLOW_BLEND_MODE)
            iconFrame.Glow = glow
        end
        iconFrame.Glow:SetSize(finalIconSize * GLOW_SCALE, finalIconSize * GLOW_SCALE)
        iconFrame.Glow:SetPoint("CENTER", iconFrame.texture, "CENTER")
        iconFrame.Glow:Show()
    elseif iconFrame.Glow then
        iconFrame.Glow:Hide()
    end

    if iconFrame.fontString then
        iconFrame.fontString:Hide()
    end
    
    local posX = x * mapWidth
    local posY = -y * mapHeight
    local offsetX = (marker.offsetX or 0) * reverseScale
    local offsetY = (marker.offsetY or 0) * reverseScale
    
    iconFrame:SetPoint("CENTER", parent, "TOPLEFT", posX + offsetX, posY + offsetY)
    
    -- 添加鼠标提示
    self:AddMarkerTooltip(iconFrame, marker)
    
    -- 路径点功能
    iconFrame:EnableMouse(true)
    iconFrame:SetMouseClickEnabled(true)
    iconFrame:SetScript("OnMouseDown", function(_, button)
        OnMarkerClick(iconFrame, button, marker)
    end)
    
    -- 存储标记数据
    if not isReused then
        iconFrame.markerData = {}
    end
    iconFrame.markerData.coord = marker.coord
    iconFrame.markerData.offsetX = marker.offsetX
    iconFrame.markerData.offsetY = marker.offsetY
    iconFrame.markerData.cityScale = cityScale
    iconFrame.markerData.icon = marker.icon
    iconFrame.markerData.isIcon = true
    
    return iconFrame
end

--------------------------------------------------------------------------------
-- 创建标记
--------------------------------------------------------------------------------
function MapMarkers:CreateMarker(parent, marker, mapWidth, mapHeight, cityScale)
    cityScale = cityScale or 1.0
    
    local markerType = RoyMapGuideDB and RoyMapGuideDB.mapMarkerType or "TEXT"
    
    -- 检查标记类型是否变更
    if self.markerPool.currentMarkerType and 
       self.markerPool.currentMarkerType ~= markerType then
        self.markerPool.frames = {}
    end
    self.markerPool.currentMarkerType = markerType
    
    -- 图标模式：只显示有icon字段的标记
    if markerType == "ICON" then
        if marker.icon then
            return self:CreateIconMarker(parent, marker, mapWidth, mapHeight, cityScale)
        end
        return nil
    end
    
    -- 文本模式：显示所有标记
    return self:CreateTextMarker(parent, marker, mapWidth, mapHeight, cityScale)
end

--------------------------------------------------------------------------------
-- 标记管理
--------------------------------------------------------------------------------
-- 清除所有标记（放回对象池）
function MapMarkers:ClearAllMarkers()
    for _, markerFrame in ipairs(self.activeMarkers) do
        if markerFrame then
            self:ReturnMarkerToPool(markerFrame)
        end
    end
    self.activeMarkers = {}
end

-- 缩放时更新位置（不重建）
function MapMarkers:UpdateMarkerPositions()
    if #self.activeMarkers == 0 then return end
    
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end
    
    local mapWidth = canvas:GetWidth()
    local mapHeight = canvas:GetHeight()
    local reverseScale = self:GetMapScaleFactor()
    
    for _, markerFrame in ipairs(self.activeMarkers) do
        if markerFrame and markerFrame.markerData then
            local data = markerFrame.markerData
            
            -- 重新计算位置
            local x, y = self:GetXY(data.coord)
            local posX = x * mapWidth
            local posY = -y * mapHeight
            local offsetX = (data.offsetX or 0) * reverseScale
            local offsetY = (data.offsetY or 0) * reverseScale
            
            -- 更新位置
            if data.isIcon then
                -- 图标标记：更新位置和大小
                local finalIconSize = self:GetGlobalSize() * (data.cityScale or 1.0) * 1.4 * reverseScale
                markerFrame:SetSize(finalIconSize, finalIconSize)
                markerFrame:SetPoint("CENTER", canvas, "TOPLEFT", posX + offsetX, posY + offsetY)
                
                -- 更新发光效果大小
                if markerFrame.Glow and markerFrame.Glow:IsShown() then
                    markerFrame.Glow:SetSize(finalIconSize * GLOW_SCALE, finalIconSize * GLOW_SCALE)
                end
            else
                -- 文本标记：更新位置和字体大小
                local finalTextSize = self:GetGlobalSize() * (data.cityScale or 1.0) * reverseScale
                local fontPath = GameFontNormal:GetFont()
                local outlineStyle = RoyMapGuideDB and RoyMapGuideDB.mapMarkerTextOutline or ""
                markerFrame.fontString:SetFont(fontPath, finalTextSize, outlineStyle)
                markerFrame.fontString:SetShadowOffset(0, 0)
                
                -- 重新计算文本大小
                local textWidth = markerFrame.fontString:GetStringWidth()
                local textHeight = markerFrame.fontString:GetStringHeight()
                markerFrame:SetSize(textWidth, textHeight)
                
                -- 更新位置（考虑锚点）
                local textAnchor = data.textA or "CENTER"
                if textAnchor == "CENTER" then
                    markerFrame:SetPoint("CENTER", canvas, "TOPLEFT", posX + offsetX, posY + offsetY)
                elseif textAnchor == "RIGHT" then
                    local compensation = textWidth * COMPENSATION_FACTOR
                    local finalX = posX - compensation + offsetX
                    markerFrame:SetPoint("LEFT", canvas, "TOPLEFT", finalX, posY + offsetY)
                elseif textAnchor == "LEFT" then
                    local compensation = textWidth * COMPENSATION_FACTOR
                    local finalX = posX + compensation + offsetX
                    markerFrame:SetPoint("RIGHT", canvas, "TOPLEFT", finalX, posY + offsetY)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 更新标记
--------------------------------------------------------------------------------
function MapMarkers:UpdateMapMarkers(forceRecreate)
    if not RoyMapGuideDB then
        self:ClearAllMarkers()
        return
    end

    if not WorldMapFrame or not WorldMapFrame:IsVisible() then
        self:ClearAllMarkers()
        return
    end

    if not RoyMapGuideDB.enableMapMarkers then
        self:ClearAllMarkers()
        return
    end

    local currentMapID = WorldMapFrame:GetMapID()
    if not currentMapID then return end

    if not forceRecreate and #self.activeMarkers > 0 then
        local mapData = MARKER_DATABASE[currentMapID]
        if mapData and self:ShouldShowByCity(mapData) then
            self:UpdateMarkerPositions()
            return
        end
    end

    self:ClearAllMarkers()

    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end

    local mapWidth, mapHeight = canvas:GetWidth(), canvas:GetHeight()
    local mapData = MARKER_DATABASE[currentMapID]

    local shouldShowMap, cityScale = true, 1.0
    if mapData then
        shouldShowMap = self:ShouldShowByCity(mapData)
        cityScale = self:GetCityScale(mapData)
    end

    if not shouldShowMap then
        self:ClearAllMarkers()
        return
    end

    -- 显示数据库普通标记
    if mapData then
        for _, marker in ipairs(self:GetMarkers(mapData)) do
            if self:ShouldShowByProfession(marker) and 
               self:ShouldShowByType(marker) and 
               self:ShouldShowMarkerByZoom(marker) then
                local frame = self:CreateMarker(canvas, marker, mapWidth, mapHeight, cityScale)
                if frame then table.insert(self.activeMarkers, frame) end
            end
        end
    end

    -- 显示动态标记
    if mapData then
        local displayedKeys = {}

        for _, marker in ipairs(self.dynamicMarkers) do
            if marker.mapID == currentMapID and self:ShouldShowByType(marker) then
                local displayKey = marker.mapID .. "_" .. marker.coord
                if not displayedKeys[displayKey] then
                    displayedKeys[displayKey] = true

                    local frame = self:CreateMarker(canvas, marker, mapWidth, mapHeight, cityScale)
                    if frame then
                        table.insert(self.activeMarkers, frame)
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 事件处理
--------------------------------------------------------------------------------
local function OnMapZoom()
    MapMarkers:UpdateMapMarkers(true)
end

local function OnMapChanged()
    local currentMapID = WorldMapFrame:GetMapID()
    if currentMapID then
        local newList = {}
        for _, marker in pairs(MapMarkers.persistentDynamicMarkers) do
            if marker.mapID == currentMapID then
                table.insert(newList, marker)
            end
        end
        MapMarkers.dynamicMarkers = newList
    end
    
    MapMarkers:UpdateMapMarkers(true)
end

-- 初始化标记系统
local function InitializeMapMarkers()
    if not MapMarkers.hooksRegistered then
        if AreaPOIPinMixin then
            hooksecurefunc(AreaPOIPinMixin, "OnAcquired", function(pin)
                MapMarkers:OnPOIPinAcquired(pin)
            end)
        end

        if MapLinkPinMixin then
            hooksecurefunc(MapLinkPinMixin, "OnAcquired", function(pin)
                MapMarkers:OnMapLinkPinAcquired(pin)
            end)
        end

        if DungeonEntrancePinMixin then
            hooksecurefunc(DungeonEntrancePinMixin, "OnAcquired", function(pin)
                MapMarkers:OnInstancePinAcquired(pin)
            end)
        end

        if DelveEntrancePinMixin then
            hooksecurefunc(DelveEntrancePinMixin, "OnAcquired", function(pin)
                MapMarkers:OnDelvePinAcquired(pin)
            end)
        end
        
        MapMarkers.hooksRegistered = true
    end

    WorldMapFrame:HookScript("OnShow", function()
        local currentMapID = WorldMapFrame:GetMapID()
        if currentMapID then
            local newList = {}
            for _, marker in pairs(MapMarkers.persistentDynamicMarkers) do
                if marker.mapID == currentMapID then
                    table.insert(newList, marker)
                end
            end
            MapMarkers.dynamicMarkers = newList
        end
        
        MapMarkers:UpdateMapMarkers(true)
    end)
    
    WorldMapFrame:HookScript("OnHide", function()
        MapMarkers:ClearAllMarkers()
        MapMarkers.markerPool.frames = {}
        MapMarkers.dynamicMarkers = {}
    end)
    
    hooksecurefunc(WorldMapFrame, "OnMapChanged", OnMapChanged)
    
    if WorldMapFrame.ScrollContainer then
        hooksecurefunc(WorldMapFrame.ScrollContainer, "ZoomIn", OnMapZoom)
        hooksecurefunc(WorldMapFrame.ScrollContainer, "ZoomOut", OnMapZoom)
    end

    MapMarkers:InitializeProfessions()

    -- 注册重载事件清理
    ns.RegisterEventHandler("PLAYER_LOGOUT", function()
        MapMarkers.processedDynamicPins = {}
        MapMarkers.persistentDynamicMarkers = {}
    end)
end

--------------------------------------------------------------------------------
-- 外部接口和事件注册
--------------------------------------------------------------------------------
function ns:ToggleMapMarkers()
    if RoyMapGuideDB then
        if RoyMapGuideDB.enableMapMarkers then
            MapMarkers:UpdateMapMarkers(true)
        else
            MapMarkers:ClearAllMarkers()
        end
    end
end

function ns:ToggleMarkerWaypoint(value)
    if WorldMapFrame and WorldMapFrame:IsShown() then
        MapMarkers:UpdateMapMarkers(true)
    end
end

ns.RegisterEventHandler("ADDON_LOADED", function(addon)
    if addon == addonName then
        InitializeMapMarkers()
    end
end)