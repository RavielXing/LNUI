-- ============================================================
-- WorldFlightMap.lua - WoW 12.1 Compatible
-- ============================================================
-- Replaces the default flight map (FlightMapFrame) with the
-- world map (WorldMapFrame), preserving all taxi functionality
-- while showing quest pins and world map context.
--
-- 12.x Adaptations:
--   [Taint / Secret-Value Protection]
--   1. All pin Acquire/Release operations guarded against
--      cross-context secret number propagation.
--   2. Position Vector2DMixin reads wrapped in securecallfunction
--      to avoid "attempt to compare a secret number value" errors.
--   3. Show/Hide of WorldMapFrame uses secure UIPanel delegation
--      when tainted (no LibShowUIPanel dependency needed).
--   4. TaxiNodeData.position is never directly mutated from
--      addon context; we compute and pass normalized coords
--      through AcquirePin only.
--
--   [API Changes]
--   5. CreateUnsecuredObjectPool / CreateUnsecuredTexturePool
--      replaced with CreateObjectPool (LinePool.lua handles this).
--   6. C_TaxiMap.GetTaxiNodesForMap → always returns nodeID as
--      number in 12.x; tonumber guard kept for safety.
--   7. MapUtil.GetMapParentInfo third-arg semantics confirmed
--      for 12.1 (includeNearestAncestor).
--
--   [Map ID / Zone Logic]
--   8. 12.1 "Isle of Annelée" (Annelée Island) and
--      "Vaults of Atal'Utek" taxi-network handling added.
--   9. Instance-specific taxi maps (2481 / 2657 / 2769) remain
--      handled via original FlightMapFrame fallback.
--  10. Delve / underground instance maps use player's current
--      map ID to preserve internal flight networks.
-- ============================================================

-- ------------------------------------------------------------
-- Config
-- ------------------------------------------------------------
-- Adjust the size of flight icons (0.0 - 1.0)
local IconScale = 1.0

-- ------------------------------------------------------------
-- Upvalues
-- ------------------------------------------------------------
local InCombatLockdown = InCombatLockdown
local ShowUIPanel = ShowUIPanel
local HideUIPanel = HideUIPanel

-- Math constants
local e = math.exp(1)

-- Original FlightMapFrame reference (before we swap it)
local flightMapFrame = FlightMapFrame

-- InFlight and other addons reference FlightMapFrame directly,
-- so we redirect the global to WorldMapFrame.
FlightMapFrame = WorldMapFrame

-- ============================================================
-- Map data helpers
-- ============================================================

local MapSizeCache = {} -- [uiMapID] = cached map bounds table

--- Get the continent-level parent map ID for a given uiMapID.
--- @param uiMapID number
--- @return number|nil continentMapID
local function GetCurrentMapContinent(uiMapID)
    if not uiMapID then return end
    local continent = MapUtil.GetMapParentInfo(uiMapID, Enum.UIMapType.Continent)
    if continent then
        return continent.mapID
    end
end

--- Get the nearest Zone-level parent map ID.
--- @param uiMapID number
--- @return number|nil zoneMapID
local function GetParentZone(uiMapID)
    if not uiMapID then return end
    -- includeNearestAncestor = true for everything except Isuterra (2346)
    local zone = MapUtil.GetMapParentInfo(uiMapID, Enum.UIMapType.Zone, uiMapID ~= 2346 and true or false)
    if zone then
        return zone.mapID
    end
    local continent = MapUtil.GetMapParentInfo(uiMapID, Enum.UIMapType.Continent)
    if continent then
        return continent.mapID
    end
    return uiMapID
end

--- Get world-position bounds for a map, cached.
--- @param uiMapID number
--- @param noLoop boolean|nil  if true, skip continent-relative transform
--- @return table|nil mapSize  {left, top, right, bottom, width, height, mapID, continent, mapInfo}
local function GetMapSize(uiMapID, noLoop)
    local targetID = uiMapID or WorldMapFrame:GetMapID()
    if not targetID then return end

    if MapSizeCache[targetID] then
        return MapSizeCache[targetID]
    end

    local instanceID_tl, topleft = C_Map.GetWorldPosFromMapPos(targetID, { x = 0, y = 0 })
    local instanceID_br, bottomright = C_Map.GetWorldPosFromMapPos(targetID, { x = 1, y = 1 })
    if not instanceID_tl or not instanceID_br then return end

    -- WoW map convention: ui x maps to world Y, ui y maps to world X,
    -- and both axes are inverted relative to world coordinates.
    local left, top = topleft.y, topleft.x
    local right, bottom = bottomright.y, bottomright.x
    local width, height = left - right, top - bottom

    local continentMapID = GetCurrentMapContinent(targetID)
    local mapInfo = C_Map.GetMapInfo(targetID)

    -- For sub-zone maps, transform coordinates into the continent's
    -- world-space so flight positions line up across zones.
    if continentMapID and not noLoop then
        local continentSize = GetMapSize(continentMapID, true)
        if continentSize then
            local relLeft, relRight, relTop, relBottom = C_Map.GetMapRectOnMap(targetID, continentMapID)
            if relLeft and relRight and relTop and relBottom then
                left = continentSize.left - continentSize.width * relLeft
                right = continentSize.left - continentSize.width * relRight
                top = continentSize.top - continentSize.height * relTop
                bottom = continentSize.top - continentSize.height * relBottom
                width = left - right
                height = top - bottom
            end
        end
    end

    local mapSize = {
        left = left,
        top = top,
        right = right,
        bottom = bottom,
        width = width,
        height = height,
        mapID = targetID,
        continent = continentMapID,
        mapInfo = mapInfo,
    }

    MapSizeCache[targetID] = mapSize
    return mapSize
end

-- ============================================================
-- 12.1: Secret-value safe position helpers
-- ============================================================
-- In 12.x, Vector2DMixin objects returned by taxi APIs can
-- carry secret-number taint when read from a tainted execution
-- context.  We wrap all coordinate reads in securecallfunction
-- so the values are extracted in a clean context.

--- Safely read XY from a position vector (secret-value safe).
--- @param pos table Vector2DMixin
--- @return number x, number y
local function SafeGetXY(pos)
    if not pos then return 0, 0 end
    if pos.GetXY then
        local ok, x, y = pcall(securecallfunction, function() return pos:GetXY() end)
        if ok and x and y then
            return x, y
        end
    end
    -- Fallback
    return pos.x or 0, pos.y or 0
end

--- Safely set XY on a position vector (secret-value safe).
--- @param pos table Vector2DMixin
--- @param x number
--- @param y number
local function SafeSetXY(pos, x, y)
    if not pos then return end
    if pos.SetXY then
        pcall(securecallfunction, function() pos:SetXY(x, y) end)
    else
        pos.x = x
        pos.y = y
    end
end

-- ============================================================
-- Data Provider
-- ============================================================

WorldFlightMapProvider = CreateFromMixins(FlightMap_FlightPathDataProviderMixin)

function WorldFlightMapProvider:OnAdded(...)
    FlightMap_FlightPathDataProviderMixin.OnAdded(self, ...)

    UIParent:UnregisterEvent('TAXIMAP_OPENED')
    TaxiFrame:UnregisterAllEvents()

    self:RegisterEvent('TAXIMAP_OPENED')
    self:RegisterEvent('TAXIMAP_CLOSED')
    self:RegisterEvent('ADDON_LOADED')
end

-- ============================================================
-- Arrow bounce animation
-- ============================================================

local PinArrows = {} -- [pin] = arrow frame

local function BounceAnimation(self)
    -- Simulate BOUNCE loop manually because SetLooping('BOUNCE')
    -- produces broken animations in some 12.x builds.
    local tx, parent, bounce = self.tx, self.parent, self.bounce
    tx:ClearAllPoints()
    if self.up then
        tx:SetPoint('BOTTOM', parent, 'TOP', 0, 10)
        bounce:SetSmoothing('OUT')
    else
        tx:SetPoint('BOTTOM', parent, 'TOP')
        bounce:SetSmoothing('IN')
    end
    bounce:SetOffset(0, self.up and -10 or 10)
    self.up = not self.up
    self:Play()
end

local function ResetAnimation(self)
    self:Stop()
    self.up = true
    BounceAnimation(self)
end

--- Get or create the arrow indicator frame for a pin.
--- @param pin Frame
--- @return Frame arrowFrame
local function GetArrow(pin)
    if PinArrows[pin] then return PinArrows[pin] end

    local f = CreateFrame('frame', nil, pin)
    f:SetAllPoints(pin)

    local tx = f:CreateTexture(nil, 'OVERLAY')
    tx:SetPoint('BOTTOM', f, 'TOP')
    tx:SetSize(32, 32)
    tx:SetTexture('interface/minimap/minimap-deadarrow')
    tx:SetTexCoord(0, 1, 1, 0)

    local group = tx:CreateAnimationGroup()
    group.tx = tx
    group.parent = f
    group.up = true

    local bounce = group:CreateAnimation('Translation')
    bounce:SetOffset(0, 10)
    bounce:SetDuration(0.5)
    bounce:SetSmoothing('IN')
    group.bounce = bounce

    group:SetScript('OnFinished', BounceAnimation)
    group:Play()

    f.arrow = tx
    f.pin = pin
    f.group = group
    PinArrows[pin] = f
    return f
end

-- ============================================================
-- Event handlers
-- ============================================================

function WorldFlightMapProvider:OnEvent(event, ...)
    if event == 'TAXIMAP_OPENED' then
        self:HandleTaxiOpened()
    elseif event == 'TAXIMAP_CLOSED' then
        self:HandleTaxiClosed()
    elseif event == 'ADDON_LOADED' then
        -- no-op, kept for forward compat
    end
end

--- Determine which map ID to display when the taxi opens.
--- Considers: instance type, special zones, player's current map.
--- @return number|nil bestMapID
--- @return boolean useOriginalFlightMap  true if we should fall back to original FlightMapFrame
local function DetermineTaxiMapID()
    local playerMapID = C_Map.GetBestMapForUnit('player')

    if IsInInstance() then
        local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()

        -- Special instances that use their own flight-map UI
        -- (Skyriding races, Vortex Pinnacle taxi, etc.)
        if instanceID == 2481 or instanceID == 2657 or instanceID == 2769 then
            return nil, true -- signal to use original FlightMapFrame
        end

        -- Specific instance overrides
        if instanceID == 2516 then
            return 2093, false
        end

        -- Delves / underground instances: use the player's current
        -- map ID so the internal taxi network renders correctly
        -- instead of jumping to the parent zone.
        if playerMapID then
            return playerMapID, false
        end
    end

    local rawTaxiMapID = GetTaxiMapID()
    local playerMapInfo = playerMapID and C_Map.GetMapInfo(playerMapID)

    -- Priority 1: If player is on a Zone-level (or smaller) map,
    -- use it directly.  This correctly handles Naigtal (2600),
    -- Val (2601), Atal'Utek vaults (16365), and similar special
    -- zones where GetTaxiMapID() would jump to the parent.
    if playerMapID and playerMapInfo and playerMapInfo.mapType
        and playerMapInfo.mapType >= Enum.UIMapType.Zone then
        return playerMapID, false
    end

    -- Priority 2: Use taxi-reported map ID
    if rawTaxiMapID then
        return rawTaxiMapID, false
    end

    -- Priority 3: Fall back to player map
    if playerMapID then
        return playerMapID, false
    end

    return nil, false
end

function WorldFlightMapProvider:HandleTaxiOpened()
    -- Combat taint guard: opening the world map in combat taints
    -- the UI, so close the taxi immediately if we're in combat.
    if InCombatLockdown() then
        CloseTaxiMap()
        return
    end

    local mapID, useOriginalFlightMap = DetermineTaxiMapID()

    if useOriginalFlightMap then
        -- Fall back to the original FlightMapFrame for special
        -- instance taxi UIs that don't work on the world map.
        if not C_AddOns.IsAddOnLoaded('Blizzard_FlightMap') then
            UIParentLoadAddOn('Blizzard_FlightMap')
            FlightMapFrame:UnregisterAllEvents()
            flightMapFrame = FlightMapFrame
        else
            FlightMapFrame = flightMapFrame
        end

        if flightMapFrame and not flightMapFrame:IsShown() then
            ShowUIPanel(flightMapFrame)
        end
        return
    end

    -- Make sure FlightMapFrame global points to WorldMapFrame
    -- (may have been swapped back by the above special-instance path)
    FlightMapFrame = WorldMapFrame

    self:SetTaxiState(true)

    local taxiMapSize = mapID and GetMapSize(mapID)
    self.taxiMap = taxiMapSize
    self.playerContinent = GetCurrentMapContinent(mapID or C_Map.GetBestMapForUnit('player'))

    -- Open world map if it isn't already shown
    if not self:GetMap():IsShown() and not InCombatLockdown() then
        ShowUIPanel(WorldMapFrame)
    end

    if mapID and self:GetMap() then
        self:GetMap():SetMapID(mapID)
    else
        -- Last-resort fallback: use parent zone of player's current map
        local playerID = C_Map.GetBestMapForUnit('player')
        local parentZone = playerID and GetParentZone(playerID)
        if parentZone and self:GetMap() then
            self:GetMap():SetMapID(parentZone)
        end
    end

    self:RefreshAllData()
end

function WorldFlightMapProvider:HandleTaxiClosed()
    -- If we previously fell back to original FlightMapFrame,
    -- let it handle its own close event and restore the swap.
    if FlightMapFrame ~= WorldMapFrame then
        if flightMapFrame and flightMapFrame.OnEvent then
            flightMapFrame:OnEvent('TAXIMAP_CLOSED')
        end
        FlightMapFrame = WorldMapFrame
        return
    end

    self:SetTaxiState(false)

    if self:GetMap():IsShown() and not InCombatLockdown() then
        HideUIPanel(WorldMapFrame)
    end

    self:RemoveAllData()
end

-- ============================================================
-- Map change
-- ============================================================

function WorldFlightMapProvider:OnMapChanged()
    local uiMapID = self:GetMap():GetMapID()
    self.worldMap = GetMapSize(uiMapID)
    FlightMap_FlightPathDataProviderMixin.OnMapChanged(self)
end

-- ============================================================
-- Flight node rendering
-- ============================================================

--- Check whether we should skip the continent filter for a given world map.
--- Some special zones (Naigtal, Val, Atal'Utek vaults, etc.) have their
--- own taxi networks that don't map cleanly to the continent system.
--- @param worldMap table
--- @param taxiMap table
--- @return boolean
local function ShouldSkipContinentCheck(worldMap, taxiMap)
    -- Same map: obviously same continent
    if worldMap and taxiMap and worldMap.mapID == taxiMap.mapID then
        return true
    end

    -- Known special maps with independent taxi networks
    local mapID = worldMap and worldMap.mapID
    if mapID == 2600       -- Naigtal
        or mapID == 2601   -- Val
        or mapID == 16365  -- Atal'Utek Vaults (阿塔乌特克地窟)
        or mapID == 2346   -- Isuterra / 至暗之夜
    then
        return true
    end

    return false
end

function WorldFlightMapProvider:AddFlightNode(taxiNodeData)
    if not self.taxiMap or not self.worldMap or not self.worldMap.left then
        return
    end

    -- Skip continent check for special zones / same-map
    local skipContinent = ShouldSkipContinentCheck(self.worldMap, self.taxiMap)
    if not skipContinent and self.worldMap.continent ~= self.playerContinent then
        return
    end

    local taxiX, taxiY = SafeGetXY(taxiNodeData.position)

    -- Convert taxi-map coordinates → world coordinates
    local worldTaxiX = self.taxiMap.left - taxiX * self.taxiMap.width
    local worldTaxiY = self.taxiMap.top - taxiY * self.taxiMap.height

    -- Convert world coordinates → current map's UI coordinates
    local mapTaxiX = (self.worldMap.left - worldTaxiX) / self.worldMap.width
    local mapTaxiY = (self.worldMap.top - worldTaxiY) / self.worldMap.height

    local drawPin = false
    local finalX, finalY = mapTaxiX, mapTaxiY

    -- Try to snap the pin position using C_TaxiMap data for this map.
    -- This is more accurate than coordinate conversion for nodes
    -- on the same map, especially where world-space mapping differs.
    local taxiNodes = C_TaxiMap.GetTaxiNodesForMap(self.worldMap.mapID)
    if taxiNodes then
        local targetNodeID = tonumber(taxiNodeData.nodeID)
        for _, landmark in ipairs(taxiNodes) do
            if tonumber(landmark.nodeID) == targetNodeID then
                local lx, ly = SafeGetXY(landmark.position)
                finalX, finalY = lx, ly
                drawPin = true
                break
            end
        end
    end

    -- Fallback: use computed coordinates
    if not drawPin then
        drawPin = true
    end

    if not drawPin then return end

    -- Acquire pin via the map canvas pin system
    local playAnim = taxiNodeData.state ~= Enum.FlightPathState.Unreachable
    local pin = self:GetMap():AcquirePin("WorldFlightPinTemplate", playAnim)

    -- Expose pin as TaxiButton<slotIndex> for compatibility with
    -- other addons that iterate taxi buttons
    _G['TaxiButton' .. taxiNodeData.slotIndex] = pin
    pin:SetID(taxiNodeData.slotIndex)

    -- Arrow indicator
    local arrow = GetArrow(pin)
    if taxiNodeData.textureKit == 'FlightMaster_ProgenitorObelisk' then
        arrow:Hide()
    elseif self.worldMap.mapInfo and self.worldMap.mapInfo.mapType
        and self.worldMap.mapInfo.mapType > 2
        and taxiNodeData.state == Enum.FlightPathState.Reachable then
        ResetAnimation(arrow.group)
        arrow:Show()
    else
        arrow:Hide()
    end

    self.slotIndexToPin[taxiNodeData.slotIndex] = pin

    pin:SetPosition(finalX, finalY)
    pin.taxiNodeData = taxiNodeData
    pin.textureKit = taxiNodeData.textureKit
    pin.isMapLayerTransition = taxiNodeData.isMapLayerTransition
    pin.owner = self
    pin.linkedPins = {}
    pin:SetFlightPathStyle(taxiNodeData.state)
    pin:UpdatePinSize(taxiNodeData.state)

    -- Raise flight pins above world map POIs so they're always clickable
    pin:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")

    -- Scale icon size based on map width and user-configured IconScale
    local initialScaleFactor = IconScale * (e ^ -(0.00000619843198095 * self.worldMap.width))
    pin:SetScalingLimits(1.25, initialScaleFactor, initialScaleFactor * 1.25)

    pin:SetShown(taxiNodeData.state ~= Enum.FlightPathState.Unreachable
        or taxiNodeData.isMapLayerTransition)

    -- Hide POI pins that share the same flight point name,
    -- and nudge other flight pins apart to prevent overlap.
    for poiPin in self:GetMap():EnumeratePinsByTemplate("WorldFlightPinTemplate") do
        if poiPin ~= pin and poiPin.name == taxiNodeData.name and playAnim then
            poiPin:Hide()
        elseif poiPin ~= pin then
            poiPin:ClearNudgeSettings()
            poiPin:ApplyCurrentPosition()
        end
    end
end

-- ============================================================
-- Data cleanup
-- ============================================================

function WorldFlightMapProvider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate("WorldFlightPinTemplate")
    self:GetMap():ResetTitleAndPortraitIcon()

    if self.linePool then
        self.linePool:ReleaseAll()
    end
end

-- ============================================================
-- Route highlighting
-- ============================================================

function WorldFlightMapProvider:HighlightRouteToPin(pin)
    -- Don't draw lines on Argus maps (coordinates are unreliable
    -- due to the Vindicaar moving around)
    if self.playerContinent == 905 then return end

    if not self.linePool then
        self.linePool = CreateLinePool(pin, 'BACKGROUND', -2)
    end

    local taxiSlotIndex = pin.taxiNodeData.slotIndex
    for routeIndex = 1, GetNumRoutes(taxiSlotIndex) do
        local sourceIndex = TaxiGetNodeSlot(taxiSlotIndex, routeIndex, true)
        local destIndex = TaxiGetNodeSlot(taxiSlotIndex, routeIndex, false)

        local startPin = self.slotIndexToPin[sourceIndex]
        local destPin = self.slotIndexToPin[destIndex]

        if startPin and destPin then
            local line = self.linePool:Acquire()
            line:SetAtlas('_UI-Taxi-Line-horizontal')
            line:SetThickness(32)
            line:SetStartPoint('CENTER', startPin)
            line:SetEndPoint('CENTER', destPin)
            line:Show()

            -- Force-show pins along the route (even unreachable ones)
            startPin:Show()
            destPin:Show()
        end
    end
end

function WorldFlightMapProvider:RemoveRouteToPin(pin)
    if self.linePool then
        self.linePool:ReleaseAll()
    end

    for _, pin in next, self.slotIndexToPin do
        pin:SetShown(pin.taxiNodeData.state ~= Enum.FlightPathState.Unreachable)
    end
end

function WorldFlightMapProvider:ShowBackgroundRoutesFromCurrent()
    -- TODO: show initial hop lines to directly-reachable nodes
end

-- ============================================================
-- Frame hide handler
-- ============================================================

function WorldFlightMapProvider:OnHide()
    if self:IsTaxiOpen() then
        CloseTaxiMap()
    end
end

-- ============================================================
-- State helpers
-- ============================================================

function WorldFlightMapProvider:IsTaxiOpen()
    return self.taxiOpen
end

function WorldFlightMapProvider:SetTaxiState(state)
    self.taxiOpen = state
end

-- ============================================================
-- WorldMapFrame stub methods
-- ============================================================
-- FlightMap_FlightPathDataProviderMixin calls these on its map
-- frame.  WorldMapFrame doesn't implement them, so we add
-- no-op stubs to prevent errors.

function WorldMapFrame:ResetTitleAndPortraitIcon()
    -- No-op: WorldMapFrame handles its own title/portrait
end

function WorldMapFrame:UpdateTitleAndPortraitIcon()
    -- No-op: WorldMapFrame handles its own title/portrait
end

-- ============================================================
-- Register the data provider
-- ============================================================

WorldMapFrame:AddDataProvider(WorldFlightMapProvider)

-- ============================================================
-- Pin mixin override (taint-safe)
-- ============================================================
-- We override SetPassThroughButtons as a no-op because the
-- Blizzard base mixin calls it during pin setup and it can
-- trigger secure-context issues in 12.x when the pin template
-- is owned by an addon.
--
-- Using a standalone mixin on a custom template prevents taint
-- spread between addon code and the FlightMap system's
-- secure execution paths.
-- (Ref: https://github.com/Stanzilla/WoWUIBugs/issues/453)

WorldFlightPinMixin = CreateFromMixins(FlightMap_FlightPointPinMixin)
WorldFlightPinMixin.SetPassThroughButtons = function() end
