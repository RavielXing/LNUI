local LibShowUIPanel = LibStub("LibShowUIPanel-1.0")
local ShowUIPanel = LibShowUIPanel.ShowUIPanel
local HideUIPanel = LibShowUIPanel.HideUIPanel

---------------------------------------------------------
-- Change IconScale to adjust the size of flight icons
-- Value is a decimal between 0 and 1
local IconScale = 1.0

---------------------------------------------------------
-- End of user settings
---------------------------------------------------------

local flightMapFrame = FlightMapFrame
-- InFlight uses FlightMapFrame directly, so it's necessary to change references
FlightMapFrame = WorldMapFrame
-- TaxiFrame = WorldMapFrame

-- Map data functions
local MapSizeCache = {} -- [uiMapID] = {left, top, right, bottom, etc}
local function GetCurrentMapContinent(uiMapID)
	--local uiMapID = uiMapID -- or WorldMapFrame:GetMapID()
	if uiMapID then
		local continent = MapUtil.GetMapParentInfo(uiMapID, Enum.UIMapType.Continent)
		if continent then
			return continent.mapID
		end
	end
end

local function GetParentZone(uiMapID)
	if uiMapID then
		local zone = MapUtil.GetMapParentInfo(uiMapID, Enum.UIMapType.Zone, uiMapID ~= 2346 and true or false)
		if zone then
			return zone.mapID
		end
		local continent = MapUtil.GetMapParentInfo(WorldMapFrame:GetMapID(), Enum.UIMapType.Continent)
		if continent then
			return continent.mapID
		end
		return uiMapID
	end
end

local function GetMapSize(uiMapID, noLoop)
	local uiMapID = uiMapID or WorldMapFrame:GetMapID()
	if not uiMapID then return end
	
	-- Return cached information if we've looked it up before
	if MapSizeCache[uiMapID] then
		return MapSizeCache[uiMapID]
	end
	
	local instanceID, topleft = C_Map.GetWorldPosFromMapPos(uiMapID, {x = 0, y = 0})
	local instanceID, bottomright = C_Map.GetWorldPosFromMapPos(uiMapID, {x = 1, y = 1})
	if not instanceID then return end
	
	local left, top = topleft.y, topleft.x
	local right, bottom = bottomright.y, bottomright.x
	local width, height = left - right, top - bottom
	
	local continentMapID = GetCurrentMapContinent(uiMapID)
	
	local mapInfo = C_Map.GetMapInfo(uiMapID)
	
	-- Transform coordinates for areas that draw on a different continent than the instance they belong to
	if continentMapID and not noLoop then
		local continentSize = GetMapSize(continentMapID, true)
		if continentSize then
			local relLeft, relRight, relTop, relBottom = C_Map.GetMapRectOnMap(uiMapID, continentMapID)
			left = continentSize.left - continentSize.width * relLeft
			right = continentSize.left - continentSize.width * relRight
			top = continentSize.top - continentSize.height * relTop
			bottom = continentSize.top - continentSize.height * relBottom
		end
	end
	
	local mapSize = {left = left, top = top, right = right, bottom = bottom, width = width, height = height, mapID = uiMapID, continent = continentMapID, mapInfo = mapInfo}
	
	-- Cache result so we don't have to do this again
	MapSizeCache[uiMapID] = mapSize
	
	return mapSize
end

-- Map provider
WorldFlightMapProvider = CreateFromMixins(FlightMap_FlightPathDataProviderMixin)
function WorldFlightMapProvider:OnAdded(...)
	FlightMap_FlightPathDataProviderMixin.OnAdded(self, ...)
	
	UIParent:UnregisterEvent('TAXIMAP_OPENED')
	TaxiFrame:UnregisterAllEvents() -- todo: does this even have any events registered any more?

	self:RegisterEvent('TAXIMAP_OPENED')
	self:RegisterEvent('TAXIMAP_CLOSED')
	self:RegisterEvent('ADDON_LOADED')
end

-- Arrow functions
local PinArrows = {} -- [pin] = arrow frame
local function BounceAnimation(self) -- SetLooping('BOUNCE') is producing broken animations, so we're just simulating what it's supposed to do
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

local function GetArrow(pin)
	-- Add an arrow frame to a pin
	if PinArrows[pin] then return PinArrows[pin] end
	local f = CreateFrame('frame', nil, pin)
	f:SetAllPoints(pin)
	
	local tx = f:CreateTexture(nil, 'OVERLAY')
	tx:SetPoint('BOTTOM', f, 'TOP')
	tx:SetSize(32, 32)
	tx:SetTexture('interface/minimap/minimap-deadarrow')
	tx:SetTexCoord(0, 1, 1, 0)
	
	local duration = 0.75
	local group = tx:CreateAnimationGroup()
	group.tx = tx
	
	local bounce = group:CreateAnimation('Translation')
	bounce:SetOffset(0, 10)
	bounce:SetDuration(0.5)
	bounce:SetSmoothing('IN')
	group.bounce = bounce
	
	group.up = true
	
	group:SetScript('OnFinished', BounceAnimation)
	group.parent = f
	f.arrow = tx
	f.pin = pin
	group:Play()
	f.group = group
	
	PinArrows[pin] = f
	return f
end

function WorldFlightMapProvider:OnEvent(event, ...)
	if event == 'TAXIMAP_OPENED' then
		-- You can't take a flight in combat, and opening the world map in combat taints the interface
		-- Therefor we need to prevent the interaction in the first place
		if InCombatLockdown() then
			CloseTaxiMap()
		else
			local overrideMapID
			if IsInInstance() then
				local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
				if instanceID == 2481 or instanceID == 2657 or instanceID == 2769 then
					if not C_AddOns.IsAddOnLoaded('Blizzard_FlightMap') then
						UIParentLoadAddOn('Blizzard_FlightMap')
						FlightMapFrame:UnregisterAllEvents()
						flightMapFrame = FlightMapFrame
					else
						FlightMapFrame =  flightMapFrame
					end

					ShowUIPanel(flightMapFrame)
					return
				elseif instanceID == 2516 then
					overrideMapID = 2093
				else
					-- 12.0至暗之夜地下堡修复：在未知实例（如地下堡）中，
					-- 使用当前所在地图ID，避免自动跳转到父地图导致无法显示内部传送网络
					local currentMapID = C_Map.GetBestMapForUnit('player')
					if currentMapID then
						overrideMapID = currentMapID
					end
				end
			end

			self:SetTaxiState(true)
			
			-- 12.0.7 v2 fix: Determine correct map for Naigtal/Val and similar zones
			-- Core issue: GetParentZone always jumps to parent (2405 Voidstorm), losing the correct map.
			-- Fix: Use player map directly when it is Zone-level or smaller.
			local rawTaxiMapID = GetTaxiMapID()
			local playerMapID = C_Map.GetBestMapForUnit('player')
			local playerMapInfo = C_Map.GetMapInfo(playerMapID)
			
			-- Determine the best map ID for display and flight data
			local bestMapID = overrideMapID
			if not bestMapID then
				-- Priority 1: If player is on a Zone-level (or smaller) map, use it directly
				-- This handles Naigtal (2600), Val (2601), and similar special zones
				if playerMapID and playerMapInfo and playerMapInfo.mapType
					and playerMapInfo.mapType >= Enum.UIMapType.Zone then
					bestMapID = playerMapID
				-- Priority 2: Use GetTaxiMapID() if available
				elseif rawTaxiMapID then
					bestMapID = rawTaxiMapID
				-- Priority 3: Fall back to player map
				elseif playerMapID then
					bestMapID = playerMapID
				end
			end
			
			self.taxiMap = GetMapSize(bestMapID)
			self.playerContinent = GetCurrentMapContinent(bestMapID or playerMapID)
			
			if not self:GetMap():IsShown() and not InCombatLockdown() then
				if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) else HideUIPanel(WorldMapFrame) end
				
				if bestMapID then
					self:GetMap():SetMapID(bestMapID)
				elseif playerMapInfo and playerMapInfo.parentMapID then
					-- Last resort fallback: use original parent zone logic
					local parentZone = GetParentZone(playerMapID)
					if parentZone then
						self:GetMap():SetMapID(parentZone)
					end
				end
			end

			self:RefreshAllData()
		end
	elseif event == 'TAXIMAP_CLOSED' then
		if FlightMapFrame ~= WorldMapFrame then
			flightMapFrame:OnEvent(event, ...)
			FlightMapFrame = WorldMapFrame
			return
		end

		self:SetTaxiState(false)

		-- CloseTaxiMap()
		if self:GetMap():IsShown() and not InCombatLockdown() then
			if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) else HideUIPanel(WorldMapFrame) end
		end

		self:RemoveAllData()
	end
end

function WorldFlightMapProvider:OnMapChanged()
	local uiMapID = self:GetMap():GetMapID()
	self.worldMap = GetMapSize(uiMapID)
	FlightMap_FlightPathDataProviderMixin.OnMapChanged(self)
end

local e = math.exp(1)

function WorldFlightMapProvider:AddFlightNode(taxiNodeData)
	if self.taxiMap and self.worldMap and self.worldMap.left then
		-- 12.0.7 v2 fix: relax continent filter for special zones
		-- When taxiMap and worldMap are the same, or for known special maps, skip continent check
		local skipContinentCheck = false
		if self.taxiMap and self.worldMap and self.taxiMap.mapID == self.worldMap.mapID then
			skipContinentCheck = true
		end
		if self.worldMap and self.worldMap.mapID and (self.worldMap.mapID == 2600 or self.worldMap.mapID == 2601) then
			skipContinentCheck = true
		end
		if skipContinentCheck or (self.worldMap.continent == self.playerContinent) then
			local taxiX, taxiY = taxiNodeData.position:GetXY()
			local worldTaxiX, worldTaxiY = self.taxiMap.left - taxiX * self.taxiMap.width, self.taxiMap.top - taxiY * self.taxiMap.height
			
			local mapTaxiX = (self.worldMap.left - worldTaxiX) / self.worldMap.width
			local mapTaxiY = (self.worldMap.top - worldTaxiY) / self.worldMap.height
			
			local drawPin = false
			--if self.playerContinent == 905 then -- match against node names for argus because coordinates are useless here (plus the vindicaar moves)
				local taxiNodes = C_TaxiMap.GetTaxiNodesForMap(self.worldMap.mapID)
				for _, landmark in pairs(taxiNodes) do
					if landmark.nodeID == taxiNodeData.nodeID then
						taxiNodeData.position.x = landmark.position.x
						taxiNodeData.position.y = landmark.position.y
						drawPin = true
						break
					end
				end
			--else
			if not drawPin then
				-- taxiNodeData.position.x = mapTaxiX
				-- taxiNodeData.position.y = mapTaxiY
				drawPin = true
			end
			
			if drawPin then
				-- Duplicating all of this from frameXML because we need to raise the frame level of the pins
				local playAnim = taxiNodeData.state ~= Enum.FlightPathState.Unreachable;
				local pin = self:GetMap():AcquirePin("WorldFlightPinTemplate", playAnim);
				
				-- For the sake of having other addons treat our buttons like normal taxi map buttons
				_G['TaxiButton' .. taxiNodeData.slotIndex] = pin
				pin:SetID(taxiNodeData.slotIndex)
				
				-- Only show arrows on zone maps
				local arrow = GetArrow(pin)
				if taxiNodeData.textureKit == 'FlightMaster_ProgenitorObelisk' then
					arrow:Hide()
				elseif self.worldMap.mapInfo and self.worldMap.mapInfo.mapType and self.worldMap.mapInfo.mapType > 2 and taxiNodeData.state == Enum.FlightPathState.Reachable then
					-- Restart animation so the arrows move in sync
					ResetAnimation(arrow.group)
					arrow:Show()
				else
					arrow:Hide()
				end
				
				self.slotIndexToPin[taxiNodeData.slotIndex] = pin;

				pin:SetPosition(taxiNodeData.position:GetXY());
				pin.taxiNodeData = taxiNodeData;
				pin.textureKit = taxiNodeData.textureKit;
				pin.isMapLayerTransition = taxiNodeData.isMapLayerTransition;
				pin.owner = self;
				pin.linkedPins = {};
				pin:SetFlightPathStyle(taxiNodeData.state);
				
				pin:UpdatePinSize(taxiNodeData.state);
				
				pin:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
				
				--pin:SetScalingLimits(1.25, 0.9625, 1.275)
				
				local initialScaleFactor = IconScale * (e ^ -(0.00000619843198095 * self.worldMap.width))
				pin:SetScalingLimits(1.25, initialScaleFactor, initialScaleFactor * 1.25)
				--pin:SetIgnoreGlobalPinScale(true)
				
				pin:SetShown(taxiNodeData.state ~= Enum.FlightPathState.Unreachable or taxiNodeData.isMapLayerTransition); -- Only show if part of a route, handled in the route building functions

				for poiPin in self:GetMap():EnumeratePinsByTemplate("WorldFlightPinTemplate") do
					if poiPin.name == taxiNodeData.name and playAnim then
						poiPin:Hide()
					else
						poiPin:ClearNudgeSettings()
						poiPin:ApplyCurrentPosition()
					end
				end
			end
		end
	end
end

function WorldFlightMapProvider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate("WorldFlightPinTemplate")
	self:GetMap():ResetTitleAndPortraitIcon()

	if self.highlightLinePool then
		self.highlightLinePool:ReleaseAll()
	end
	if self.backgroundLinePool then
		self.backgroundLinePool:ReleaseAll()
	end
end

function WorldFlightMapProvider:HighlightRouteToPin(pin)
	if self.playerContinent == 905 then return end -- don't draw lines on argus maps (we could if they're on the same zone map)
	
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
			local Line = self.linePool:Acquire()
			-- Line:SetNonBlocking(true)
			Line:SetAtlas('_UI-Taxi-Line-horizontal')
			Line:SetThickness(32)
			Line:SetStartPoint('CENTER', startPin)
			Line:SetEndPoint('CENTER', destPin)
			Line:Show()

			-- force show all the pins in the route
			startPin:Show()
			destPin:Show()
		end
	end
end

function WorldFlightMapProvider:RemoveRouteToPin(pin)
	if(self.linePool) then
		self.linePool:ReleaseAll()
	end

	for _, pin in next, self.slotIndexToPin do
		-- update visibility
		pin:SetShown(pin.taxiNodeData.state ~= Enum.FlightPathState.Unreachable)
		--Pin:UpdateState()
	end
end

function WorldFlightMapProvider:ShowBackgroundRoutesFromCurrent()
	-- todo: show initial hoplines to direct routes
end

function WorldFlightMapProvider:OnHide()
	if self:IsTaxiOpen() then
		CloseTaxiMap()
	end
end

function WorldFlightMapProvider:IsTaxiOpen()
	return self.taxiOpen
end

function WorldFlightMapProvider:SetTaxiState(state)
	self.taxiOpen = state
end

function WorldMapFrame:ResetTitleAndPortraitIcon()
	-- Placeholder for missing mixin method that gets called when the map is opened
end

function WorldMapFrame:UpdateTitleAndPortraitIcon()
	-- Called when map is opened to a zone with a bastion node on it
end

WorldMapFrame:AddDataProvider(WorldFlightMapProvider)

-- use modified pin mixin and template to prevent taint
-- https://github.com/Stanzilla/WoWUIBugs/issues/453
WorldFlightPinMixin = CreateFromMixins(FlightMap_FlightPointPinMixin)
WorldFlightPinMixin.SetPassThroughButtons = function() end
