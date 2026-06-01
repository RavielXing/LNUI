local addonName, ns = ...
local L = ns.L

-- ========================================================================
-- 【地图缩放】
-- ========================================================================
do
    local function ApplyScale()
        if not RoyMapGuideDB then return end
        if not RoyMapGuideDB.isMapScale then
            if WorldMapFrame:GetScale() ~= 1 then
                WorldMapFrame:SetScale(1)
            end
            return
        end
        if WorldMapFrame:IsMaximized() then
            if WorldMapFrame:GetScale() ~= 1 then
                WorldMapFrame:SetScale(1)
            end
            return
        end
        local scale = RoyMapGuideDB.mapScaleLevel or 1.0
        if WorldMapFrame:GetScale() ~= scale then
            WorldMapFrame:SetScale(scale)
        end
    end

    function ns.OnMapScaleChanged()
        ApplyScale()
    end

    EventUtil.ContinueOnAddOnLoaded(addonName, function()
        hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", ApplyScale)
        C_Timer.After(0, ApplyScale)
    end)
end

-- ========================================================================
-- 【地图ID显示】
-- ========================================================================
do
    local frame = nil
    local mapIDText = nil
    local lastMapIDStr = ""
    local cachedIDColor = {r = 1, g = 1, b = 1}

    local function UpdateIDColor()
        if not RoyMapGuideDB then return end
        local color = CreateColorFromHexString(RoyMapGuideDB.mapIDTextColor or "FFFFFFFF")
        cachedIDColor.r, cachedIDColor.g, cachedIDColor.b = color:GetRGB()
    end

    local function ApplyIDStyle()
        if not mapIDText then return end
        local path = mapIDText:GetFont()
        mapIDText:SetFont(path, RoyMapGuideDB.mapIDFontSize or 14, "OUTLINE")
        mapIDText:SetTextColor(cachedIDColor.r, cachedIDColor.g, cachedIDColor.b)
    end

    local function ApplyIDPosition()
        if not mapIDText then return end
        local sc = WorldMapFrame.ScrollContainer
        if not sc then return end
        mapIDText:ClearAllPoints()
        mapIDText:SetPoint("CENTER", sc, "CENTER",
            RoyMapGuideDB.mapIDPositionX or 0,
            RoyMapGuideDB.mapIDPositionY or 0)
    end

    local function UpdateMapID()
        if not mapIDText or not RoyMapGuideDB or not RoyMapGuideDB.isMapID then return end
        local mapID = WorldMapFrame:GetMapID()
        local newStr = mapID and (L["地图ID: "] .. mapID) or ""
        if newStr ~= lastMapIDStr then
            lastMapIDStr = newStr
            mapIDText:SetText(newStr)
        end
    end

    local function CreateMapIDUI()
        if frame then return end
        frame = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
        frame:SetSize(200, 20)
        frame:SetFrameStrata("TOOLTIP")
        mapIDText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        UpdateIDColor()
        ApplyIDStyle()
        ApplyIDPosition()
    end

    local function EnableMapID()
        if not frame then CreateMapIDUI() end
        UpdateMapID()
        frame:Show()
    end

    local function DisableMapID()
        if not frame then return end
        lastMapIDStr = ""
        frame:Hide()
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", function()
        if not RoyMapGuideDB or not RoyMapGuideDB.isMapID then return end
        if not WorldMapFrame:IsShown() then return end
        lastMapIDStr = ""
        UpdateMapID()
    end)

    function ns.OnMapInfoChanged()
        if not RoyMapGuideDB then return end
        if RoyMapGuideDB.isMapID then
            if WorldMapFrame:IsShown() then EnableMapID() end
        else
            DisableMapID()
        end
    end

    function ns.OnMapIDStyleChanged()
        UpdateIDColor()
        ApplyIDStyle()
        lastMapIDStr = ""
        UpdateMapID()
    end

    function ns.OnMapIDPositionChanged()
        ApplyIDPosition()
    end

    EventUtil.ContinueOnAddOnLoaded(addonName, function()
        WorldMapFrame:HookScript("OnShow", function()
            if RoyMapGuideDB and RoyMapGuideDB.isMapID then EnableMapID() end
        end)
        WorldMapFrame:HookScript("OnHide", function()
            lastMapIDStr = ""
        end)
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            if RoyMapGuideDB and RoyMapGuideDB.isMapID and WorldMapFrame:IsShown() then
                lastMapIDStr = ""
                UpdateMapID()
            end
        end)
        UpdateIDColor()
        if RoyMapGuideDB and RoyMapGuideDB.isMapID then
            C_Timer.After(1, function()
                if WorldMapFrame:IsShown() then EnableMapID() end
            end)
        end
    end)
end

-- ========================================================================
-- 【坐标显示】
-- ========================================================================
do
    local PLAYER_INTERVAL = 0.3
    local WATCHDOG_INTERVAL = 0.2
    local WATCHDOG_DURATION = 6

    local WATCHDOG_TRIGGER_EVENTS = {
        PLAYER_ENTERING_WORLD = true,
        ZONE_CHANGED_NEW_AREA = true,
        PLAYER_CONTROL_LOST = true,
        PLAYER_CONTROL_GAINED = true,
        PLAYER_MOUNT_DISPLAY_CHANGED = true,
    }

    local frame = nil
    local playerText = nil
    local mouseText = nil

    local lastPlayerStr = ""
    local lastMouseStr = ""

    local playerTicker = nil
    local watchdogTicker = nil
    local mouseTicker = nil
    local watchdogExpireAt = nil
    local watchdogPersistent = false

    local cachedCoordsColor = {r = 1, g = 1, b = 1}
    local coordFmt = "%.1f丨%.1f"

    -- ----------------------------------------------------------------
    -- 格式
    -- ----------------------------------------------------------------
    local function RebuildCoordFmt()
        if not RoyMapGuideDB then return end
        local places = RoyMapGuideDB.coordsDecimalPlaces or 1
        if places == 0 then coordFmt = "%.0f丨%.0f"
        elseif places == 2 then coordFmt = "%.2f丨%.2f"
        else coordFmt = "%.1f丨%.1f" end
    end

    -- ----------------------------------------------------------------
    -- 移动状态判断
    -- ----------------------------------------------------------------
    local function IsInTravelState()
        local speed = GetUnitSpeed("player")
        local moving = speed and not issecretvalue(speed) and speed > 0
        return moving or UnitOnTaxi("player") or IsFlying() or IsFalling()
    end

    -- ----------------------------------------------------------------
    -- 鼠标坐标计算
    -- ----------------------------------------------------------------
    local function GetNormalizedCursorPosition()
        local sc = WorldMapFrame.ScrollContainer
        if not sc then return nil, nil end
        if sc.GetNormalizedCursorPosition then
            local nx, ny = sc:GetNormalizedCursorPosition()
            if nx and ny and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
                return nx, ny
            end
        end
        return nil, nil
    end

    -- ----------------------------------------------------------------
    -- 更新函数
    -- ----------------------------------------------------------------
    local function UpdatePlayerCoords()
        if not playerText or not RoyMapGuideDB or not RoyMapGuideDB.isCoords then return end
        local mapID = WorldMapFrame:GetMapID()
        local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        local newStr = ""
        if pos then
            local px, py = pos:GetXY()
            if px and py and px ~= 0 then
                newStr = L["玩家："] .. string.format(coordFmt, px * 100, py * 100)
            end
        end
        if newStr ~= lastPlayerStr then
            lastPlayerStr = newStr
            playerText:SetText(newStr)
        end
    end

    local function UpdateMouseCoords()
        if not mouseText or not RoyMapGuideDB or not RoyMapGuideDB.isCoords then return false end
        local nx, ny = GetNormalizedCursorPosition()
        if not nx then
            if lastMouseStr ~= "" then
                lastMouseStr = ""
                mouseText:SetText("")
            end
            return false
        end
        local newStr = L["鼠标："] .. string.format(coordFmt, nx * 100, ny * 100)
        if newStr ~= lastMouseStr then
            lastMouseStr = newStr
            mouseText:SetText(newStr)
        end
        return true
    end

    -- ----------------------------------------------------------------
    -- Ticker 管理
    -- ----------------------------------------------------------------
    local StopWatchdog
    local StopPlayerTicker

    local function StartPlayerTicker()
        if playerTicker then return end
        StopWatchdog()
        playerTicker = C_Timer.NewTicker(PLAYER_INTERVAL, function()
            if not RoyMapGuideDB or not RoyMapGuideDB.isCoords then
                StopPlayerTicker()
                return
            end
            UpdatePlayerCoords()
            if not IsInTravelState() then
                StopPlayerTicker()
                if not watchdogTicker then
                    watchdogExpireAt = GetTime() + WATCHDOG_DURATION
                    watchdogPersistent = false
                    watchdogTicker = C_Timer.NewTicker(WATCHDOG_INTERVAL, function()
                        if playerTicker then StopWatchdog() return end
                        if watchdogPersistent then
                            if not IsMounted() then StopWatchdog() return end
                        else
                            if not watchdogExpireAt or GetTime() >= watchdogExpireAt then
                                StopWatchdog()
                                return
                            end
                        end
                        if IsInTravelState() then
                            StartPlayerTicker()
                            UpdatePlayerCoords()
                        end
                    end)
                end
            end
        end)
    end

    StopPlayerTicker = function()
        if playerTicker then
            playerTicker:Cancel()
            playerTicker = nil
        end
    end

    StopWatchdog = function()
        if watchdogTicker then
            watchdogTicker:Cancel()
            watchdogTicker = nil
        end
        watchdogExpireAt = nil
        watchdogPersistent = false
    end

    local function StartWatchdog(persistent)
        if playerTicker then return end
        if persistent then
            watchdogPersistent = true
            watchdogExpireAt = nil
        else
            local expireAt = GetTime() + WATCHDOG_DURATION
            if watchdogExpireAt and watchdogExpireAt > expireAt then
                expireAt = watchdogExpireAt
            end
            watchdogExpireAt = expireAt
            watchdogPersistent = false
        end
        if watchdogTicker then return end
        watchdogTicker = C_Timer.NewTicker(WATCHDOG_INTERVAL, function()
            if playerTicker then StopWatchdog() return end
            if watchdogPersistent then
                if not IsMounted() then StopWatchdog() return end
            else
                if not watchdogExpireAt or GetTime() >= watchdogExpireAt then
                    StopWatchdog()
                    return
                end
            end
            if IsInTravelState() then
                StartPlayerTicker()
                UpdatePlayerCoords()
            end
        end)
    end

    local function RefreshPlayerTrackingState(armWatchdog)
        if IsInTravelState() then
            StartPlayerTicker()
            return
        end
        StopPlayerTicker()
        if IsMounted() then
            StartWatchdog(true)
        elseif armWatchdog then
            StartWatchdog(false)
        else
            StopWatchdog()
        end
    end

    local function StopMouseTicker()
        if mouseTicker then
            mouseTicker:Cancel()
            mouseTicker = nil
        end
        if lastMouseStr ~= "" then
            lastMouseStr = ""
            if mouseText then mouseText:SetText("") end
        end
    end

    local function StartMouseTicker()
        if mouseTicker then return end
        if not WorldMapFrame:IsShown() then return end
        mouseTicker = C_Timer.NewTicker(0.1, function()
            if not WorldMapFrame:IsShown() then
                StopMouseTicker()
                return
            end
            if not UpdateMouseCoords() then
                StopMouseTicker()
            end
        end)
    end

    -- ----------------------------------------------------------------
    -- 样式与位置
    -- ----------------------------------------------------------------
    local function UpdateCoordsColor()
        if not RoyMapGuideDB then return end
        local color = CreateColorFromHexString(RoyMapGuideDB.coordsTextColor or "FFFFFFFF")
        cachedCoordsColor.r, cachedCoordsColor.g, cachedCoordsColor.b = color:GetRGB()
    end

    local function ApplyCoordsStyle()
        if not playerText then return end
        local path = playerText:GetFont()
        local size = RoyMapGuideDB.coordsFontSize or 14
        playerText:SetFont(path, size, "OUTLINE")
        mouseText:SetFont(path, size, "OUTLINE")
        playerText:SetTextColor(cachedCoordsColor.r, cachedCoordsColor.g, cachedCoordsColor.b)
        mouseText:SetTextColor(cachedCoordsColor.r, cachedCoordsColor.g, cachedCoordsColor.b)
        lastPlayerStr = ""
        lastMouseStr  = ""
    end

    local function ApplyCoordsPosition()
        if not playerText then return end
        local sc = WorldMapFrame.ScrollContainer
        if not sc then return end
        local cX = RoyMapGuideDB.coordsPositionX or 0
        local cY = RoyMapGuideDB.coordsPositionY or 0
        playerText:ClearAllPoints()
        playerText:SetPoint("RIGHT", sc, "CENTER", -30 + cX, cY)
        mouseText:ClearAllPoints()
        mouseText:SetPoint("LEFT", sc, "CENTER", 30 + cX, cY)
    end

    -- ----------------------------------------------------------------
    -- UI 创建
    -- ----------------------------------------------------------------
    local function CreateCoordsUI()
        if frame then return end
        local sc = WorldMapFrame.ScrollContainer
        frame = CreateFrame("Frame", nil, sc)
        frame:SetSize(1, 1)
        frame:SetPoint("CENTER", sc, "CENTER", 0, 0)
        frame:SetFrameStrata("TOOLTIP")
        playerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        mouseText  = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        UpdateCoordsColor()
        ApplyCoordsStyle()
        ApplyCoordsPosition()

        sc:HookScript("OnEnter", function()
            if RoyMapGuideDB and RoyMapGuideDB.isCoords and WorldMapFrame:IsShown() then
                UpdateMouseCoords()
                StartMouseTicker()
            end
        end)
        sc:HookScript("OnLeave", function()
            StopMouseTicker()
        end)
        sc:HookScript("OnMouseWheel", function()
            if RoyMapGuideDB and RoyMapGuideDB.isCoords then UpdateMouseCoords() end
        end)
    end

    -- ----------------------------------------------------------------
    -- 启用 / 禁用
    -- ----------------------------------------------------------------
    local function EnableCoords()
        if not frame then CreateCoordsUI() end
        frame:Show()
        UpdatePlayerCoords()
        local sc = WorldMapFrame.ScrollContainer
        if sc and sc:IsMouseOver() then
            UpdateMouseCoords()
            StartMouseTicker()
        end
        RefreshPlayerTrackingState(true)
    end

    local function DisableCoords()
        StopPlayerTicker()
        StopWatchdog()
        StopMouseTicker()
        lastPlayerStr = ""
        lastMouseStr  = ""
        if frame then frame:Hide() end
    end

    -- ----------------------------------------------------------------
    -- 事件
    -- ----------------------------------------------------------------
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_STARTED_MOVING")
    eventFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_CONTROL_LOST")
    eventFrame:RegisterEvent("PLAYER_CONTROL_GAINED")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if not RoyMapGuideDB or not RoyMapGuideDB.isCoords then return end
        if not WorldMapFrame:IsShown() then return end
        UpdatePlayerCoords()
        if event == "PLAYER_STARTED_MOVING" then
            StartPlayerTicker()
            return
        end
        local armWatchdog = WATCHDOG_TRIGGER_EVENTS[event] == true
        RefreshPlayerTrackingState(armWatchdog)
    end)

    -- ----------------------------------------------------------------
    -- 初始化
    -- ----------------------------------------------------------------
    EventUtil.ContinueOnAddOnLoaded(addonName, function()
        WorldMapFrame:HookScript("OnShow", function()
            if RoyMapGuideDB and RoyMapGuideDB.isCoords then EnableCoords() end
        end)
        WorldMapFrame:HookScript("OnHide", function()
            StopPlayerTicker()
            StopWatchdog()
            StopMouseTicker()
            lastPlayerStr = ""
            lastMouseStr  = ""
            if playerText then playerText:SetText("") end
            if mouseText  then mouseText:SetText("") end
        end)
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            if RoyMapGuideDB and RoyMapGuideDB.isCoords and WorldMapFrame:IsShown() then
                lastPlayerStr = ""
                UpdatePlayerCoords()
            end
        end)

        UpdateCoordsColor()
        RebuildCoordFmt()
        if RoyMapGuideDB and RoyMapGuideDB.isCoords then
            C_Timer.After(1, function()
                if WorldMapFrame:IsShown() then EnableCoords() end
            end)
        end
    end)

    -- ----------------------------------------------------------------
    -- 外部接口
    -- ----------------------------------------------------------------
    function ns.OnCoordsChanged()
        if not RoyMapGuideDB then return end
        RebuildCoordFmt()
        lastPlayerStr = ""
        if RoyMapGuideDB.isCoords then
            if WorldMapFrame and WorldMapFrame:IsShown() then EnableCoords() end
        else
            DisableCoords()
        end
    end

    function ns.OnCoordsStyleChanged()
        UpdateCoordsColor()
        ApplyCoordsStyle()
        if RoyMapGuideDB and RoyMapGuideDB.isCoords and WorldMapFrame:IsShown() then
            UpdatePlayerCoords()
        end
    end

    function ns.OnCoordsPositionChanged()
        ApplyCoordsPosition()
    end
end

-- ========================================================================
-- 【全地图NPC标记】
-- ========================================================================
do
    local floor = math.floor

    local MARKER_STRATA = "MEDIUM"
    local COMPENSATION_FACTOR = 0.1
    local GLOW_ATLAS = "GearEnchant_IconBorder"
    local GLOW_SCALE = 1.3
    local GLOW_COLOR = {r = 1, g = 1, b = 1, a = 1}
    local GLOW_BLEND = "ADD"

    local PROFESSION_TO_SKILLLINE = {
        Alchemy = 171,
        Archaeology = 794,
        Blacksmithing = 164,
        Cooking = 185,
        Enchanting = 333,
        Engineering = 202,
        Fishing = 356,
        Herbalism = 182,
        Inscription = 773,
        Jewelcrafting = 755,
        Leatherworking = 165,
        Mining = 186,
        Skinning = 393,
        Tailoring = 197,
    }

    local INFO_COLORS = {
        n = "|cFFFFD100",  -- NPC名称颜色
        i = "|cFF00FF00",  -- 特殊说明颜色
        c = "|cFF4499FF",  -- 货币颜色
        a = "|cFFEE8800",  -- 作者描述颜色
    }

    local function FormatInfo(str)
        if not str then return nil end
        return (str:gsub("%[([nica])%](.-)%[/%1%]", function(tag, content)
            return (INFO_COLORS[tag] or "") .. content .. "|r"
        end))
    end

    local COLOR_DEFAULTS = {
        portal = "FF00DDFF",
        inn = "FF00FF00",
        official = "FFFFFF00",
        profession = "FFFFFFFF",
        service = "FFFF00FF",
        stable = "FFFF9900",
        collection = "FFFF88CC",
        vendor = "FFAA33FF",
        unique = "FF3366FF",
        special = "FF00FFBB",
        quartermaster = "FFFF5000",
        pvp = "FFFF0000",
        instance = "FFFF0055",
        delve = "FF7777FF",
    }

    local COLOR_TABLE = {}

    local function RebuildColorTable()
        for colorName, defaultHex in pairs(COLOR_DEFAULTS) do
            local key = "mapMarkersColor" .. colorName:sub(1, 1):upper() .. colorName:sub(2)
            local hex = (RoyMapGuideDB and RoyMapGuideDB[key]) or defaultHex
            local c = CreateColorFromHexString(hex)
            local r, g, b = c:GetRGB()
            COLOR_TABLE[colorName] = {r = r, g = g, b = b}
        end
    end

    local DB = RoyMapGuide_MAP_DATA or {}
    local TEMPLATES = RoyMapGuide_MAP_DATA_TEMPLATES or {}

    -- ----------------------------------------------------------------
    -- 核心对象
    -- ----------------------------------------------------------------
    local Markers = {
        active = {},
        pool = {},
        currentMode = nil,
        playerProfessions = {},
        persistent = {},
        dynamic = {},
    }

    -- ----------------------------------------------------------------
    -- 工具函数
    -- ----------------------------------------------------------------
    local function GetXY(coord)
        local x = floor(coord / 10000) / 10000
        local y = (coord % 10000) / 10000
        return x, y
    end

    local function GetTextSize()
        return RoyMapGuideDB and RoyMapGuideDB.mapMarkersTextSize or 14
    end

    local function GetTextOutline()
        return RoyMapGuideDB and RoyMapGuideDB.mapMarkersTextOutline or "OUTLINE"
    end

    local function GetIconSize()
        return RoyMapGuideDB and RoyMapGuideDB.mapMarkersIconSize or 20
    end

    local function GetFrameLevel()
        return RoyMapGuideDB and RoyMapGuideDB.mapMarkersFrameLevel or 2200
    end

    local function GetDynamicOffsetY()
        return RoyMapGuideDB and RoyMapGuideDB.mapMarkersDynamicOffsetY or 0
    end

    local function GetZoomThreshold()
        return RoyMapGuideDB and RoyMapGuideDB.mapMarkersZoomThreshold or 2
    end

    local function GetMapZoomLevel()
        local sc = WorldMapFrame.ScrollContainer
        if not sc or not sc.Child then return 0 end
        local zoomLevels = sc.zoomLevels
        if not zoomLevels or #zoomLevels == 0 then return 0 end
        local currentScale = sc.Child:GetScale()
        if not currentScale or currentScale == 0 then return 0 end
        local epsilon = 0.0001
        for i = #zoomLevels, 1, -1 do
            local levelScale = zoomLevels[i].scale
            if levelScale and currentScale >= (levelScale - epsilon) then
                return i - 1
            end
        end
        return 0
    end

    local function GetScaleFactor()
        local sc = WorldMapFrame.ScrollContainer
        if not sc or not sc.Child then return 1.0 end
        local s = sc.Child:GetScale()
        if not s or s == 0 then return 1.0 end
        return (1 / s) ^ 0.7
    end

    local function GetCityScale(mapData)
        if not mapData or not mapData.group then return 1.0 end
        if not RoyMapGuideDB then return 1.0 end
        local scale = RoyMapGuideDB["scale" .. mapData.group]
        if type(scale) ~= "number" then scale = 1.0 end
        local subZoneScale = mapData.subZoneScale
        if type(subZoneScale) == "number" then scale = scale * subZoneScale end
        return scale
    end

    local function ShouldShowByCity(mapData)
        if not mapData or not mapData.group then return true end
        if not RoyMapGuideDB then return true end
        if mapData.faction then
            local factionKey = "show" .. mapData.faction .. "Group"
            if RoyMapGuideDB[factionKey] == false then return false end
        end
        return RoyMapGuideDB["show" .. mapData.group] ~= false
    end

    local function ResolveMarker(marker)
        if not marker.template then return marker end
        local t = TEMPLATES[marker.template]
        if not t then return marker end
        local resolved = {}
        for k, v in pairs(t) do resolved[k] = v end
        for k, v in pairs(marker) do
            if k ~= "template" then resolved[k] = v end
        end
        return resolved
    end

    local function GetPinCoord(pin)
        if not pin or not pin.GetPosition then return nil end
        local x, y = pin:GetPosition()
        if not x or not y then return nil end
        return floor(x * 10000) * 10000 + floor(y * 10000)
    end

    -- ----------------------------------------------------------------
    -- 过滤函数
    -- ----------------------------------------------------------------
    local function UpdatePlayerProfessions()
        local newProfs = {}
        local prof1, prof2, arch, fish, cook = GetProfessions()
        for _, prof in ipairs({prof1, prof2, arch, fish, cook}) do
            if prof then
                local _, _, _, _, _, _, skillLine = GetProfessionInfo(prof)
                if skillLine then newProfs[skillLine] = true end
            end
        end
        Markers.playerProfessions = newProfs
    end

    local function ShouldShowByProfession(marker)
        if not RoyMapGuideDB or not RoyMapGuideDB.isMapMarkersProfessionFilter then return true end
        if not marker.type then return true end
        local types = type(marker.type) == "table" and marker.type or {marker.type}
        for _, t in ipairs(types) do
            if t == "Fishing" or t == "Archaeology" or t == "Cooking" then return true end
            local skillLine = PROFESSION_TO_SKILLLINE[t]
            if skillLine and Markers.playerProfessions[skillLine] then return true end
        end
        return false
    end

    local function ShouldShowByZoom(marker)
        if not marker.isAggregate and not marker.isIndividual then return true end
        if RoyMapGuideDB and RoyMapGuideDB.isMapMarkersProfessionFilter and marker.color == "profession" then
            return marker.isIndividual == true
        end
        local zoomLevel = GetMapZoomLevel()
        if zoomLevel < GetZoomThreshold() then
            return marker.isAggregate == true
        end
        return marker.isIndividual == true
    end

    local function CheckColorSwitch(color)
        if not RoyMapGuideDB then return true end
        local db = RoyMapGuideDB
        if color == "portal" then return db.isMapMarkersPortal ~= false
        elseif color == "inn" then return db.isMapMarkersInn ~= false
        elseif color == "official" then return db.isMapMarkersOfficial ~= false
        elseif color == "profession" then return db.isMapMarkersProfession ~= false
        elseif color == "service" then return db.isMapMarkersService ~= false
        elseif color == "stable" then return db.isMapMarkersStable ~= false
        elseif color == "collection" then return db.isMapMarkersCollection ~= false
        elseif color == "vendor" then return db.isMapMarkersVendor ~= false
        elseif color == "unique" then return db.isMapMarkersUnique ~= false
        elseif color == "special" then return db.isMapMarkersSpecial ~= false
        elseif color == "quartermaster" then return db.isMapMarkersQuartermaster ~= false
        elseif color == "pvp" then return db.isMapMarkersPvp ~= false
        elseif color == "instance" then return db.isMapMarkersInstance ~= false
        elseif color == "delve" then return db.isMapMarkersDelve ~= false
        end
        return true
    end

    local function ShouldShowByType(marker)
        if marker.tags and #marker.tags > 0 then
            local checked = {}
            for _, tag in ipairs(marker.tags) do
                if not checked[tag] then
                    checked[tag] = true
                    if CheckColorSwitch(tag) then return true end
                end
            end
            return false
        end
        return CheckColorSwitch(marker.color)
    end

    -- ----------------------------------------------------------------
    -- 路径点
    -- ----------------------------------------------------------------
    local function CreateWaypoint(mapID, x, y)
        if not C_Map.CanSetUserWaypointOnMap(mapID) then return end
        C_Map.ClearUserWaypoint()
        C_Map.SetUserWaypoint({uiMapID = mapID, position = {x = x, y = y}})
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end

    -- ----------------------------------------------------------------
    -- 鼠标交互
    -- ----------------------------------------------------------------
    local function SetupMouseInteraction(frame, marker)
        local hasTooltip = marker.title and RoyMapGuideDB and RoyMapGuideDB.isMapMarkersTooltip
        local hasWaypoint = marker.icon and RoyMapGuideDB and RoyMapGuideDB.isMapMarkersWaypoint

        if not hasTooltip and not hasWaypoint then
            frame:EnableMouse(false)
            frame:SetMouseClickEnabled(false)
            frame:SetScript("OnEnter", nil)
            frame:SetScript("OnLeave", nil)
            frame:SetScript("OnMouseDown", nil)
            return
        end

        frame:EnableMouse(true)

        if hasTooltip then
            frame:SetScript("OnEnter", function(self)
                if not (RoyMapGuideDB and RoyMapGuideDB.isMapMarkersTooltip) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(marker.title, 1, 0.82, 0)
                if marker.info then
                    GameTooltip:AddLine(FormatInfo(marker.info), 1, 1, 1, true)
                end
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            frame:SetScript("OnEnter", nil)
            frame:SetScript("OnLeave", nil)
        end

        if hasWaypoint then
            frame:SetMouseClickEnabled(true)
            frame:SetScript("OnMouseDown", function(_, button)
                if not (RoyMapGuideDB and RoyMapGuideDB.isMapMarkersWaypoint) then return end
                local mapID = WorldMapFrame:GetMapID()
                if not mapID then return end
                local x, y = GetXY(marker.coord)
                if button == "LeftButton" then
                    CreateWaypoint(mapID, x, y)
                elseif button == "RightButton" then
                    C_Map.ClearUserWaypoint()
                end
            end)
        else
            frame:SetMouseClickEnabled(false)
            frame:SetScript("OnMouseDown", nil)
        end
    end

    -- ----------------------------------------------------------------
    -- 对象池
    -- ----------------------------------------------------------------
    local function GetFromPool()
        return table.remove(Markers.pool)
    end

    local function ReturnToPool(frame)
        if not frame then return end
        frame:Hide()
        frame:ClearAllPoints()
        frame:SetParent(nil)
        frame:EnableMouse(false)
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        frame:SetScript("OnMouseDown", nil)
        if frame.fontString then
            frame.fontString:SetText("")
            frame.fontString:Hide()
        end
        if frame.texture then
            frame.texture:SetTexture(nil)
            frame.texture:Hide()
        end
        if frame.glow then
            frame.glow:Hide()
        end
        table.insert(Markers.pool, frame)
    end

    -- ----------------------------------------------------------------
    -- 标记渲染
    -- ----------------------------------------------------------------
    local function CreateTextMarker(canvas, marker, mapW, mapH, cityScale)
        local frame = GetFromPool()
        if not frame or not frame.fontString then
            frame = CreateFrame("Frame", nil, canvas)
            frame:SetFrameStrata(MARKER_STRATA)
            frame.fontString = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        else
            frame:SetParent(canvas)
            frame:SetFrameStrata(MARKER_STRATA)
        end
        frame:SetFrameLevel(GetFrameLevel())

        local fs = frame.fontString
        fs:Show()

        local scale = GetScaleFactor()
        local size = GetTextSize() * cityScale * scale
        local fontPath = GameFontNormal:GetFont()
        fs:SetFont(fontPath, size, GetTextOutline())
        fs:SetShadowOffset(0, 0)
        fs:SetText(marker.text or "")

        local color = COLOR_TABLE[marker.color] or {r = 1, g = 1, b = 1}
        fs:SetTextColor(color.r, color.g, color.b, 1)

        if frame.texture then frame.texture:Hide() end

        local tw = fs:GetStringWidth()
        local th = fs:GetStringHeight()
        frame:SetSize(tw, th)

        local x, y = GetXY(marker.coord)
        local posX = x * mapW
        local posY = -y * mapH
        local offsetX = (marker.offsetX or 0) * scale
        local offsetY = (marker.offsetY or 0) * scale
        if marker.isDynamic then offsetY = offsetY + GetDynamicOffsetY() * scale end
        local anchor = marker.textA or "CENTER"

        if anchor == "CENTER" then
            fs:SetPoint("CENTER", frame, "CENTER", 0, 0)
            fs:SetJustifyH("CENTER")
            frame:SetPoint("CENTER", canvas, "TOPLEFT", posX + offsetX, posY + offsetY)
        elseif anchor == "RIGHT" then
            fs:SetPoint("LEFT", frame, "LEFT", 0, 0)
            fs:SetJustifyH("LEFT")
            frame:SetPoint("LEFT", canvas, "TOPLEFT", posX - tw * COMPENSATION_FACTOR + offsetX, posY + offsetY)
        elseif anchor == "LEFT" then
            fs:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            fs:SetJustifyH("RIGHT")
            frame:SetPoint("RIGHT", canvas, "TOPLEFT", posX + tw * COMPENSATION_FACTOR + offsetX, posY + offsetY)
        end

        frame.markerData = {
            coord = marker.coord,
            offsetX = marker.offsetX,
            offsetY = marker.offsetY,
            cityScale = cityScale,
            text = marker.text,
            color = marker.color,
            textA = marker.textA,
            isDynamic = marker.isDynamic,
            isIcon = false,
        }

        SetupMouseInteraction(frame, marker)
        frame:Show()
        return frame
    end

    local function CreateIconMarker(canvas, marker, mapW, mapH, cityScale)
        local frame = GetFromPool()
        if not frame or not frame.texture then
            frame = CreateFrame("Frame", nil, canvas)
            frame:SetFrameStrata(MARKER_STRATA)
        else
            frame:SetParent(canvas)
            frame:SetFrameStrata(MARKER_STRATA)
        end
        frame:SetFrameLevel(GetFrameLevel() + #Markers.active)

        local scale = GetScaleFactor()
        local size = GetIconSize() * cityScale * scale
        frame:SetSize(size, size)

        if not frame.texture then
            frame.texture = frame:CreateTexture(nil, "ARTWORK", nil, 1)
            frame.texture:SetAllPoints()
        end
        frame.texture:Show()
        frame.texture:SetTexture(marker.icon)
        if frame.fontString then frame.fontString:Hide() end

        local glowEnabled = RoyMapGuideDB and RoyMapGuideDB.mapMarkersIconGlow == "GLOW"
        if glowEnabled then
            if not frame.glow then
                frame.glow = frame:CreateTexture(nil, "ARTWORK", nil, 0)
                frame.glow:SetAtlas(GLOW_ATLAS)
                frame.glow:SetVertexColor(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, GLOW_COLOR.a)
                frame.glow:SetBlendMode(GLOW_BLEND)
            end
            local glowSize = size * GLOW_SCALE
            frame.glow:SetSize(glowSize, glowSize)
            frame.glow:SetPoint("CENTER", frame.texture, "CENTER")
            frame.glow:Show()
        elseif frame.glow then
            frame.glow:Hide()
        end

        local x, y = GetXY(marker.coord)
        local posX = x * mapW
        local posY = -y * mapH
        local offsetX = (marker.offsetX or 0) * scale
        local offsetY = (marker.offsetY or 0) * scale
        frame:SetPoint("CENTER", canvas, "TOPLEFT", posX + offsetX, posY + offsetY)

        frame.markerData = {
            coord = marker.coord,
            offsetX = marker.offsetX,
            offsetY = marker.offsetY,
            cityScale = cityScale,
            icon = marker.icon,
            isIcon = true,
        }

        SetupMouseInteraction(frame, marker)
        frame:Show()
        return frame
    end

    local function CreateMarker(canvas, marker, mapW, mapH, cityScale)
        local mode = RoyMapGuideDB and RoyMapGuideDB.mapMarkersMode or "TEXT"
        if mode == "ICON" then
            if not marker.icon then return nil end
            return CreateIconMarker(canvas, marker, mapW, mapH, cityScale)
        end
        return CreateTextMarker(canvas, marker, mapW, mapH, cityScale)
    end

    -- ----------------------------------------------------------------
    -- 动态标记捕获
    -- ----------------------------------------------------------------
    local function ProcessDynamicPin(pin, nameTable, defaultColor)
        if not RoyMapGuideDB or not RoyMapGuideDB.isMapMarkers then return end
        if not nameTable then return end

        local mapID = WorldMapFrame:GetMapID()
        if not mapID then return end

        local pinName = pin.name or ""
        if pinName == "" then return end
        pinName = pinName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

        local data = nameTable[pinName]
        if not data then return end

        local text = data.text or pinName
        local color = data.color or defaultColor
        if not CheckColorSwitch(color) then return end

        local coord = GetPinCoord(pin)
        if not coord then return end

        local uniqueKey = mapID .. "_" .. pinName .. "_" .. coord
        if Markers.persistent[uniqueKey] then return end

        local marker = {
            coord = coord,
            text = text,
            color = color,
            textA = "CENTER",
            isDynamic = true,
            mapID = mapID,
        }

        Markers.persistent[uniqueKey] = marker
        Markers.dynamic[#Markers.dynamic + 1] = marker

        if WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == mapID then
            local canvas = WorldMapFrame:GetCanvas()
            if not canvas then return end
            local mapData = DB[mapID]
            local cityScale = GetCityScale(mapData)
            local frame = CreateMarker(canvas, marker, canvas:GetWidth(), canvas:GetHeight(), cityScale)
            if frame then
                Markers.active[#Markers.active + 1] = frame
            end
        end
    end

    -- ----------------------------------------------------------------
    -- 标记管理
    -- ----------------------------------------------------------------
    local function ClearAllMarkers()
        for _, frame in ipairs(Markers.active) do
            ReturnToPool(frame)
        end
        Markers.active = {}
    end

    local function RenderMarkers()
        if not RoyMapGuideDB or not RoyMapGuideDB.isMapMarkers then
            ClearAllMarkers()
            return
        end

        local canvas = WorldMapFrame:GetCanvas()
        if not canvas then return end

        local mapID = WorldMapFrame:GetMapID()
        if not mapID then return end

        local mapData = DB[mapID]
        if not ShouldShowByCity(mapData) then
            ClearAllMarkers()
            return
        end

        local mode = RoyMapGuideDB and RoyMapGuideDB.mapMarkersMode or "TEXT"
        if mode ~= Markers.currentMode then
            for _, f in ipairs(Markers.pool) do
                if f.fontString then f.fontString:SetText("") end
                if f.texture then f.texture:SetTexture(nil) end
            end
            Markers.pool = {}
            Markers.currentMode = mode
        end

        ClearAllMarkers()

        local mapW = canvas:GetWidth()
        local mapH = canvas:GetHeight()
        local cityScale = GetCityScale(mapData)

        if mapData then
            for i = 1, #mapData do
                local raw = mapData[i]
                if type(raw) == "table" and raw.coord then
                    local marker = ResolveMarker(raw)
                    if ShouldShowByType(marker) and ShouldShowByProfession(marker) and ShouldShowByZoom(marker) then
                        local frame = CreateMarker(canvas, marker, mapW, mapH, cityScale)
                        if frame then
                            Markers.active[#Markers.active + 1] = frame
                        end
                    end
                end
            end
        end

        local seen = {}
        for _, marker in ipairs(Markers.dynamic) do
            if marker.mapID == mapID then
                local key = marker.coord
                if not seen[key] and CheckColorSwitch(marker.color) then
                    seen[key] = true
                    local frame = CreateMarker(canvas, marker, mapW, mapH, cityScale)
                    if frame then
                        Markers.active[#Markers.active + 1] = frame
                    end
                end
            end
        end
    end

    local function OnMapChanged()
        local mapID = WorldMapFrame:GetMapID()
        Markers.dynamic = {}
        if mapID then
            for _, marker in pairs(Markers.persistent) do
                if marker.mapID == mapID then
                    Markers.dynamic[#Markers.dynamic + 1] = marker
                end
            end
        end
        RenderMarkers()
    end

    -- ----------------------------------------------------------------
    -- 外部接口
    -- ----------------------------------------------------------------
    function ns.OnMapMarkersChanged()
        RebuildColorTable()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            RenderMarkers()
        end
    end

    -- ----------------------------------------------------------------
    -- 初始化
    -- ----------------------------------------------------------------
    EventUtil.ContinueOnAddOnLoaded(addonName, function()
        if not next(DB) then
            print("|cFF33FF99BF|r丨|cFFEE8800" .. L["地图标记数据库加载失败"] .. "|r")
        end

        RebuildColorTable()

        WorldMapFrame:HookScript("OnShow", function()
            if RoyMapGuideDB and RoyMapGuideDB.isMapMarkers then
                OnMapChanged()
            end
        end)

        WorldMapFrame:HookScript("OnHide", function()
            ClearAllMarkers()
            Markers.pool = {}
            Markers.dynamic = {}
        end)

        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            if RoyMapGuideDB and RoyMapGuideDB.isMapMarkers and WorldMapFrame:IsShown() then
                OnMapChanged()
            end
        end)

        if WorldMapFrame.ScrollContainer then
            hooksecurefunc(WorldMapFrame.ScrollContainer, "ZoomIn", function()
                if RoyMapGuideDB and RoyMapGuideDB.isMapMarkers and WorldMapFrame:IsShown() then
                    RenderMarkers()
                end
            end)
            hooksecurefunc(WorldMapFrame.ScrollContainer, "ZoomOut", function()
                if RoyMapGuideDB and RoyMapGuideDB.isMapMarkers and WorldMapFrame:IsShown() then
                    RenderMarkers()
                end
            end)
        end

        UpdatePlayerProfessions()
        local profFrame = CreateFrame("Frame")
        profFrame:RegisterEvent("SKILL_LINES_CHANGED")
        profFrame:SetScript("OnEvent", function()
            UpdatePlayerProfessions()
            if RoyMapGuideDB and RoyMapGuideDB.isMapMarkers and WorldMapFrame:IsShown() then
                RenderMarkers()
            end
        end)

        if AreaPOIPinMixin then
            hooksecurefunc(AreaPOIPinMixin, "OnAcquired", function(pin)
                local mapID = WorldMapFrame:GetMapID()
                local mapData = mapID and DB[mapID]
                if mapData and mapData.poiNames then
                    ProcessDynamicPin(pin, mapData.poiNames, "special")
                end
            end)
        end

        if MapLinkPinMixin then
            hooksecurefunc(MapLinkPinMixin, "OnAcquired", function(pin)
                local mapID = WorldMapFrame:GetMapID()
                local mapData = mapID and DB[mapID]
                if mapData and mapData.maplinkNames then
                    ProcessDynamicPin(pin, mapData.maplinkNames, "portal")
                end
            end)
        end

        if DungeonEntrancePinMixin then
            hooksecurefunc(DungeonEntrancePinMixin, "OnAcquired", function(pin)
                local mapID = WorldMapFrame:GetMapID()
                local mapData = mapID and DB[mapID]
                if mapData and mapData.instanceNames then
                    ProcessDynamicPin(pin, mapData.instanceNames, "instance")
                end
            end)
        end

        if DelveEntrancePinMixin then
            hooksecurefunc(DelveEntrancePinMixin, "OnAcquired", function(pin)
                local mapID = WorldMapFrame:GetMapID()
                local mapData = mapID and DB[mapID]
                if mapData and mapData.delveNames then
                    ProcessDynamicPin(pin, mapData.delveNames, "delve")
                end
            end)
        end

        local logoutFrame = CreateFrame("Frame")
        logoutFrame:RegisterEvent("PLAYER_LOGOUT")
        logoutFrame:SetScript("OnEvent", function()
            Markers.persistent = {}
        end)
    end)
end

-- ========================================================================
-- 【地图标记开关按钮】
-- ========================================================================
do
    local button = nil
    local label = nil

    local COLOR_ON = {r = 1, g = 0.82, b = 0}
    local COLOR_OFF = {r = 0.5, g = 0.5, b = 0.5}

    local function UpdateButton()
        if not button then return end
        local mode = RoyMapGuideDB and RoyMapGuideDB.mapMarkersMode or "TEXT"
        label:SetText(mode == "TEXT" and L["文"] or L["图"])
        if RoyMapGuideDB and RoyMapGuideDB.isMapMarkers then
            button:SetAlpha(1.0)
            label:SetTextColor(COLOR_ON.r, COLOR_ON.g, COLOR_ON.b)
        else
            button:SetAlpha(0.5)
            label:SetTextColor(COLOR_OFF.r, COLOR_OFF.g, COLOR_OFF.b)
        end
    end

    local function CreateButton()
        if button then return end
        button = CreateFrame("Button", nil, WorldMapFrame.BorderFrame, "BackdropTemplate")
        button:SetSize(28, 28)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        if WorldMapFrame.overlayFrames and WorldMapFrame.overlayFrames[2] then
            button:SetPoint("RIGHT", WorldMapFrame.overlayFrames[2], "LEFT", -20, 0)
        else
            button:SetPoint("TOPRIGHT", WorldMapFrame.BorderFrame, "TOPRIGHT", -10, -10)
        end

        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {left = 2, right = 2, top = 2, bottom = 2},
        })
        button:SetBackdropColor(0, 0, 0, 0.8)
        button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

        label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        label:SetPoint("CENTER")

        button:SetScript("OnClick", function(_, btn)
            if not RoyMapGuideDB then return end
            if btn == "LeftButton" then
                RoyMapGuideDB.isMapMarkers = not RoyMapGuideDB.isMapMarkers
                UpdateButton()
                if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
            elseif btn == "RightButton" then
                RoyMapGuideDB.mapMarkersMode = (RoyMapGuideDB.mapMarkersMode == "TEXT") and "ICON" or "TEXT"
                UpdateButton()
                if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
            end
        end)

        button:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
            label:SetTextColor(1, 1, 0.7)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["地图标记开关"], 1, 0.82, 0)
            GameTooltip:AddLine(L["左键：标记开关"], 1, 1, 1)
            GameTooltip:AddLine(L["右键：切换模式"], 1, 1, 1)
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0.8)
            UpdateButton()
            GameTooltip:Hide()
        end)

        UpdateButton()
    end

    local function ApplyButtonVisibility()
        if not RoyMapGuideDB then return end
        if RoyMapGuideDB.isMapMarkersButton then
            CreateButton()
            if button then button:SetShown(WorldMapFrame:IsShown()) end
        else
            if button then button:Hide() end
        end
    end

    function ns.OnMapMarkersButtonChanged()
        ApplyButtonVisibility()
    end

    local _orig = ns.OnMapMarkersChanged
    ns.OnMapMarkersChanged = function()
        if _orig then _orig() end
        UpdateButton()
    end

    EventUtil.ContinueOnAddOnLoaded(addonName, function()
        WorldMapFrame:HookScript("OnShow", function()
            if RoyMapGuideDB and RoyMapGuideDB.isMapMarkersButton then
                CreateButton()
                if button then button:Show() end
            end
        end)

        WorldMapFrame:HookScript("OnHide", function()
            if button then button:Hide() end
        end)

        ApplyButtonVisibility()
    end)
end