local MAJOR, MINOR = "HereBeDragons-2.0", 22
assert(LibStub, MAJOR .. " requires LibStub")

local HereBeDragons, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not HereBeDragons then return end

local CBH = LibStub("CallbackHandler-1.0")

HereBeDragons.eventFrame       = HereBeDragons.eventFrame or CreateFrame("Frame")

HereBeDragons.mapData          = HereBeDragons.mapData or {}
HereBeDragons.worldMapData     = HereBeDragons.worldMapData or {}
HereBeDragons.transforms       = HereBeDragons.transforms or {}
HereBeDragons.callbacks        = HereBeDragons.callbacks or CBH:New(HereBeDragons, nil, nil, false)

local WOW_INTERFACE_VER = select(4, GetBuildInfo())
local WoWClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local WoWBC = (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) and WOW_INTERFACE_VER >= 20500 and WOW_INTERFACE_VER < 30000
local WoWWrath = (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) and WOW_INTERFACE_VER >= 30400 and WOW_INTERFACE_VER < 40000

local COSMIC_MAP_ID = 946
local WORLD_MAP_ID = 947

local PI2 = math.pi * 2
local atan2 = math.atan2
local pairs, ipairs = pairs, ipairs

local UnitPosition = UnitPosition
local C_Map = C_Map

local mapData          = HereBeDragons.mapData -- table { width, height, left, top, .instance, .name, .mapType }
local worldMapData     = HereBeDragons.worldMapData -- table { width, height, left, top }
local transforms       = HereBeDragons.transforms

local currentPlayerUIMapID, currentPlayerUIMapType

local instanceIDOverrides = {
    -- Draenor
    [1152] = 1116, -- Horde Garrison 1
    [1330] = 1116, -- Horde Garrison 2
    [1153] = 1116, -- Horde Garrison 3
    [1154] = 1116, -- Horde Garrison 4 (unused)
    [1158] = 1116, -- Alliance Garrison 1
    [1331] = 1116, -- Alliance Garrison 2
    [1159] = 1116, -- Alliance Garrison 3
    [1160] = 1116, -- Alliance Garrison 4 (unused)
    [1191] = 1116, -- Ashran PvP Zone
    [1203] = 1116, -- Frostfire Finale Scenario
    [1207] = 1116, -- Talador Finale Scenario
    [1277] = 1116, -- Defense of Karabor Scenario (SMV)
    [1402] = 1116, -- Gorgrond Finale Scenario
    [1464] = 1116, -- Tanaan
    [1465] = 1116, -- Tanaan
    -- Legion
    [1478] = 1220, -- Temple of Elune Scenario (Val'Sharah)
    [1495] = 1220, -- Protection Paladin Artifact Scenario (Stormheim)
    [1502] = 1220, -- Dalaran Underbelly
    [1533] = 0,    -- Karazhan Artifact Scenario
    [1539] = 0,    -- Arm Warrior Artifact Tirisfal Scenario
    [1612] = 1220, -- Feral Druid Artifact Scenario (Suramar)
    [1626] = 1220, -- Suramar Withered Scenario
    [1662] = 1220, -- Suramar Invasion Scenario
    -- BfA
    [2213] = 0,    -- Horrific Vision of Stormwind
    [2241] = 1,    -- Uldum N'zoth assault
    [2274] = 1,    -- Uldum N'zoth Minor Vision
    [2275] = 870,  -- Vale of Eternal Blossoms N'zoth Minor Vision
}

local dynamicInstanceIDOverrides = {}
instanceIDOverrides = setmetatable(instanceIDOverrides, { __index = dynamicInstanceIDOverrides })

local function overrideInstance(instance) return instanceIDOverrides[instance] or instance end

HereBeDragons.___DIIDO = dynamicInstanceIDOverrides

if not oldversion or oldversion < 21 then
    if oldversion then
        wipe(mapData)
        wipe(worldMapData)
        wipe(transforms)
    end

    local transformData
    if WoWClassic then
        transformData = {}
    elseif WoWBC then
        transformData = {
            { 530, 0, 4800, 16000, -10133.3, -2666.67, -2400, 2662.8 },
            { 530, 1, -6933.33, 533.33, -16000, -8000, 10339.7, 17600 },
        }
    elseif WoWWrath then
        transformData = {
            { 530, 0, 4800, 16000, -10133.3, -2666.67, -2400, 2662.8 },
            { 530, 1, -6933.33, 533.33, -16000, -8000, 10339.7, 17600 },
            { 609, 0, -10000, 10000, -10000, 10000, 0, 0 },
        }
    else
        transformData = {
            { 530, 1, -6933.33, 533.33, -16000, -8000, 9916, 17600 },
            { 530, 0, 4800, 16000, -10133.3, -2666.67, -2400, 2400 },
            { 732, 0, -3200, 533.3, -533.3, 2666.7, -611.8, 3904.3 },
            { 1014, 870, 3200, 5333.3, 1066.7, 2666.7, 0, 0 },
            { 1064, 870, 5391, 8148, 3518, 7655, -2134.2, -2286.6 },
            { 1208, 1116, -2666, -2133, -2133, -1600, 10210.7, 2411.4 },
            { 1460, 1220, -1066.7, 2133.3, 0, 3200, -2333.9, 966.7 },
            { 1498, 1220, -533.3, 2133.3, 3733.3, 5866.7, 0, 0 },
            { 1545, 1220, -2666.7, 0, 4800, 8000, 0, -0 },
            { 1599, 1, 4800, 5866.7, -4266.7, -3200, -490.6, -0.4 },
            { 1609, 571, 6400, 8533.3, -1600, 533.3, 512.8, 545.3 },
        }
    end

    local function processTransforms()
        for _, transform in pairs(transformData) do
            local instanceID, newInstanceID, minY, maxY, minX, maxX, offsetY, offsetX = unpack(transform)
            if not transforms[instanceID] then
                transforms[instanceID] = {}
            end
            table.insert(transforms[instanceID], { newInstanceID = newInstanceID, minY = minY, maxY = maxY, minX = minX, maxX = maxX, offsetY = offsetY, offsetX = offsetX })
        end
    end

    local function applyMapTransforms(instanceID, left, right, top, bottom)
        if transforms[instanceID] then
            for _, data in ipairs(transforms[instanceID]) do
                if left <= data.maxX and right >= data.minX and top <= data.maxY and bottom >= data.minY then
                    instanceID = data.newInstanceID
                    left   = left   + data.offsetX
                    right  = right  + data.offsetX
                    top    = top    + data.offsetY
                    bottom = bottom + data.offsetY
                    break
                end
            end
        end
        return instanceID, left, right, top, bottom
    end

    local vector00, vector05 = CreateVector2D(0, 0), CreateVector2D(0.5, 0.5)
    local function processMap(id, data, parent)
        if not id or not data or mapData[id] then return end

        if data.parentMapID and data.parentMapID ~= 0 then
            parent = data.parentMapID
        elseif not parent then
            parent = 0
        end

        local instance, topLeft = C_Map.GetWorldPosFromMapPos(id, vector00)
        local _, bottomRight = C_Map.GetWorldPosFromMapPos(id, vector05)
        if topLeft and bottomRight then
            local top, left = topLeft:GetXY()
            local bottom, right = bottomRight:GetXY()
            bottom = top + (bottom - top) * 2
            right = left + (right - left) * 2

            instance, left, right, top, bottom = applyMapTransforms(instance, left, right, top, bottom)
            mapData[id] = {left - right, top - bottom, left, top, instance = instance, name = data.name, mapType = data.mapType, parent = parent }
        else
            mapData[id] = {0, 0, 0, 0, instance = instance or -1, name = data.name, mapType = data.mapType, parent = parent }
        end
    end

    local function processMapChildrenRecursive(parent)
        local children = C_Map.GetMapChildrenInfo(parent)
        if children and #children > 0 then
            for i = 1, #children do
                local id = children[i].mapID
                if id and not mapData[id] then
                    processMap(id, children[i], parent)
                    processMapChildrenRecursive(id)

                    local groupID = C_Map.GetMapGroupID(id)
                    if groupID then
                        local groupMembers = C_Map.GetMapGroupMembersInfo(groupID)
                        if groupMembers then
                            for k = 1, #groupMembers do
                                local memberId = groupMembers[k].mapID
                                if memberId and not mapData[memberId] then
                                    processMap(memberId, C_Map.GetMapInfo(memberId), parent)
                                    processMapChildrenRecursive(memberId)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local function fixupZones()
        local cosmic = C_Map.GetMapInfo(COSMIC_MAP_ID)
        if cosmic then
            mapData[COSMIC_MAP_ID] = {0, 0, 0, 0}
            mapData[COSMIC_MAP_ID].instance = -1
            mapData[COSMIC_MAP_ID].name = cosmic.name
            mapData[COSMIC_MAP_ID].mapType = cosmic.mapType
        end

        if WoWClassic then
            worldMapData[0] = { 44688.53, 29795.11, 32601.04,  9894.93 }
            worldMapData[1] = { 44878.66, 29916.10,  8723.96, 14824.53 }
        elseif WoWBC then
            worldMapData[0] = { 44688.53, 29791.24, 32681.47, 11479.44 }
            worldMapData[1] = { 44878.66, 29916.10,  8723.96, 14824.53 }
        elseif WoWWrath then
            worldMapData[0] = { 48033.24, 32020.8, 36867.97, 14848.84 }
            worldMapData[1] = { 47908.72, 31935.28, 8552.61, 18467.83 }
            worldMapData[571] = { 47662.7, 31772.19, 25198.53, 11072.07 }
        else
            worldMapData[0] = { 76153.14, 50748.62, 65008.24, 23827.51 }
            worldMapData[1] = { 77621.13, 51854.98, 18576.47, 28030.61 }
            worldMapData[571] = { 71773.64, 50054.05, 36205.94, 12366.81 }
            worldMapData[870] = { 67710.54, 45118.08, 33565.89, 38020.67 }
            worldMapData[1220] = { 82758.64, 55151.28, 52943.46, 24484.72 }
            worldMapData[1642] = { 77933.3, 51988.91, 44262.36, 32835.1 }
            worldMapData[1643] = { 76060.47, 50696.96, 55384.8, 25774.35 }
            worldMapData[2444] = { 111420.37, 74283, 86088.21, 15682.4 }
        end
    end

    local function gatherMapData()
        processTransforms()

        if WoWClassic then
            processMap(WORLD_MAP_ID)
            processMapChildrenRecursive(WORLD_MAP_ID)
        else
            processMapChildrenRecursive(COSMIC_MAP_ID)
        end

        fixupZones()

        for i = 1, 2500 do
            if not mapData[i] then
                local mapInfo = C_Map.GetMapInfo(i)
                if mapInfo and mapInfo.name then
                    processMap(i, mapInfo, nil)
                end
            end
        end
    end

    gatherMapData()
end

local function applyCoordinateTransforms(x, y, instanceID)
    if transforms[instanceID] then
        for _, transformData in ipairs(transforms[instanceID]) do
            if transformData.minX <= x and transformData.maxX >= x and transformData.minY <= y and transformData.maxY >= y then
                instanceID = transformData.newInstanceID
                x = x + transformData.offsetX
                y = y + transformData.offsetY
                break
            end
        end
    end
    return x, y, overrideInstance(instanceID)
end

local StartUpdateTimer
local function UpdateCurrentPosition(instanceCheck)
    local uiMapID = C_Map.GetBestMapForUnit("player")

    if instanceCheck then
        local _x, _y, instance = HereBeDragons:GetPlayerWorldPosition()
        if instance and instance ~= -1 and mapData[uiMapID] and mapData[uiMapID].instance ~= instance and uiMapID ~= -1 and not instanceIDOverrides[instance] and not instanceIDOverrides[mapData[uiMapID].instance] then
            dynamicInstanceIDOverrides[instance] = mapData[uiMapID].instance
        end
    end

    if uiMapID ~= currentPlayerUIMapID then
        currentPlayerUIMapID, currentPlayerUIMapType = uiMapID, mapData[uiMapID] and mapData[uiMapID].mapType or 0

        HereBeDragons.callbacks:Fire("PlayerZoneChanged", currentPlayerUIMapID, currentPlayerUIMapType)
    end

    if currentPlayerUIMapType == Enum.UIMapType.Micro then
        StartUpdateTimer()
    end
end

HereBeDragons.UpdateCurrentPosition = UpdateCurrentPosition
local function UpdateTimerCallback()
    HereBeDragons.updateTimerActive = nil

    HereBeDragons.UpdateCurrentPosition()
end

function StartUpdateTimer()
    if not HereBeDragons.updateTimerActive then
        HereBeDragons.updateTimerActive = true

        C_Timer.After(1, UpdateTimerCallback)
    end
end

local function OnEvent(frame, event, ...)
    UpdateCurrentPosition(true)
end

HereBeDragons.eventFrame:SetScript("OnEvent", OnEvent)
HereBeDragons.eventFrame:UnregisterAllEvents()
HereBeDragons.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
HereBeDragons.eventFrame:RegisterEvent("ZONE_CHANGED")
HereBeDragons.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
HereBeDragons.eventFrame:RegisterEvent("NEW_WMO_CHUNK")
HereBeDragons.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

function HereBeDragons:GetLocalizedMap(uiMapID)
    return mapData[uiMapID] and mapData[uiMapID].name or nil
end

function HereBeDragons:GetZoneSize(uiMapID)
    local data = mapData[uiMapID]
    if not data then return 0, 0 end

    return data[1], data[2]
end

function HereBeDragons:GetAllMapIDs()
    local t = {}
    for id in pairs(mapData) do
        table.insert(t, id)
    end
    return t
end

function HereBeDragons:GetWorldCoordinatesFromZone(x, y, zone)
    local data = mapData[zone]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil, nil end
    if not x or not y then return nil, nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = left - width * x, top - height * y

    return x, y, overrideInstance(data.instance)
end

function HereBeDragons:GetWorldCoordinatesFromAzerothWorldMap(x, y, instance)
    local data = worldMapData[instance]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil, nil end
    if not x or not y then return nil, nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = left - width * x, top - height * y

    return x, y, instance
end

function HereBeDragons:GetZoneCoordinatesFromWorld(x, y, zone, allowOutOfBounds)
    local data = mapData[zone]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil end
    if not x or not y then return nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    if not allowOutOfBounds and (x < 0 or x > 1 or y < 0 or y > 1) then return nil, nil end

    return x, y
end

function HereBeDragons:GetAzerothWorldMapCoordinatesFromWorld(x, y, instance, allowOutOfBounds)
    local data = worldMapData[instance]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil end
    if not x or not y then return nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    if not allowOutOfBounds and (x < 0 or x > 1 or y < 0 or y > 1) then return nil, nil end

    return x, y
end

local function TranslateAzerothWorldMapCoordinates(self, x, y, oZone, dZone, allowOutOfBounds)
    if (oZone ~= WORLD_MAP_ID and not mapData[oZone]) or (dZone ~= WORLD_MAP_ID and not mapData[dZone]) then return nil, nil end
    local instance = overrideInstance((oZone == WORLD_MAP_ID) and mapData[dZone].instance or mapData[oZone].instance)
    if not worldMapData[instance] then return nil, nil end

    if oZone == WORLD_MAP_ID then
        x, y = self:GetWorldCoordinatesFromAzerothWorldMap(x, y, instance)
        return self:GetZoneCoordinatesFromWorld(x, y, dZone, allowOutOfBounds)
    else
        x, y = self:GetWorldCoordinatesFromZone(x, y, oZone)
        return self:GetAzerothWorldMapCoordinatesFromWorld(x, y, instance, allowOutOfBounds)
    end
end

function HereBeDragons:TranslateZoneCoordinates(x, y, oZone, dZone, allowOutOfBounds)
    if oZone == dZone then return x, y end

    if oZone == WORLD_MAP_ID or dZone == WORLD_MAP_ID then
        return TranslateAzerothWorldMapCoordinates(self, x, y, oZone, dZone, allowOutOfBounds)
    end

    local xCoord, yCoord, instance = self:GetWorldCoordinatesFromZone(x, y, oZone)
    if not xCoord then return nil, nil end

    local data = mapData[dZone]
    if not data or overrideInstance(data.instance) ~= instance then return nil, nil end

    return self:GetZoneCoordinatesFromWorld(xCoord, yCoord, dZone, allowOutOfBounds)
end

function HereBeDragons:GetWorldDistance(instanceID, oX, oY, dX, dY)
    if not oX or not oY or not dX or not dY then return nil, nil, nil end
    local deltaX, deltaY = dX - oX, dY - oY
    return (deltaX * deltaX + deltaY * deltaY)^0.5, deltaX, deltaY
end

function HereBeDragons:GetZoneDistance(oZone, oX, oY, dZone, dX, dY)
    local oInstance, dInstance
    oX, oY, oInstance = self:GetWorldCoordinatesFromZone(oX, oY, oZone)
    if not oX then return nil, nil, nil end

    dX, dY, dInstance = self:GetWorldCoordinatesFromZone(dX, dY, dZone)
    if not dX then return nil, nil, nil end

    if oInstance ~= dInstance then return nil, nil, nil end

    return self:GetWorldDistance(oInstance, oX, oY, dX, dY)
end

function HereBeDragons:GetWorldVector(instanceID, oX, oY, dX, dY)
    local distance, deltaX, deltaY = self:GetWorldDistance(instanceID, oX, oY, dX, dY)
    if not distance then return nil, nil end

    local angle = atan2(-deltaX, deltaY)

    if angle > 0 then
        angle = PI2 - angle
    else
        angle = -angle
    end

    return angle, distance
end

function HereBeDragons:GetUnitWorldPosition(unitId)
    local y, x, _z, instanceID = UnitPosition(unitId)
    if not x or not y then return nil, nil, overrideInstance(instanceID) end

    return applyCoordinateTransforms(x, y, instanceID)
end

function HereBeDragons:GetPlayerWorldPosition()
    local y, x, _z, instanceID = UnitPosition("player")
    if not x or not y then return nil, nil, overrideInstance(instanceID) end

    return applyCoordinateTransforms(x, y, instanceID)
end

function HereBeDragons:GetPlayerZone()
    return currentPlayerUIMapID, currentPlayerUIMapType
end

function HereBeDragons:GetPlayerZonePosition(allowOutOfBounds)
    if not currentPlayerUIMapID then return nil, nil, nil, nil end
    local x, y, _instanceID = self:GetPlayerWorldPosition()
    if not x or not y then return nil, nil, nil, nil end

    x, y = self:GetZoneCoordinatesFromWorld(x, y, currentPlayerUIMapID, allowOutOfBounds)
    if x and y then
        return x, y, currentPlayerUIMapID, currentPlayerUIMapType
    end
    return nil, nil, nil, nil
end

if IsLoggedIn() then
    UpdateCurrentPosition(true)
end
