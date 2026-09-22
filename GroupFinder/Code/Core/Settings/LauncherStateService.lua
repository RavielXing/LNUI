local _, GF = ...

local Service = {}
GF.LauncherStateService = Service

Service.SURFACE_MINIMAP = "minimap"
Service.SURFACE_FLOAT = "float"

Service.INTENT_NONE = "none"
Service.INTENT_OPEN_BROWSE = "open-browse"
Service.INTENT_OPEN_CREATE = "open-create"
Service.INTENT_HIDE_MAIN = "hide-main"
Service.INTENT_ACTIVE_LISTING_MENU = "active-listing-menu"

local DEFAULT_MINIMAP_ANGLE = 225
local listeners = {}

local function getDatabase()
	local getter = GF.GetDB
	if type(getter) ~= "function" then
		return nil
	end
	local database = getter()
	return type(database) == "table" and database or nil
end

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function toFiniteNumber(value)
	local number = tonumber(value)
	return isFiniteNumber(number) and number or nil
end

local visibilityKeys = {
	[Service.SURFACE_MINIMAP] = "showMinimap",
	[Service.SURFACE_FLOAT] = "showFloatButton",
}

function Service:AddListener(callback)
	if type(callback) ~= "function" then
		return nil
	end
	for index = 1, #listeners do
		if listeners[index] == callback then
			return callback
		end
	end
	listeners[#listeners + 1] = callback
	return callback
end

function Service:RemoveListener(callback)
	for index = #listeners, 1, -1 do
		if listeners[index] == callback then
			table.remove(listeners, index)
			return true
		end
	end
	return false
end

function Service:NotifyChanged(reason, surface)
	local snapshot = {}
	for index = 1, #listeners do
		snapshot[index] = listeners[index]
	end
	for index = 1, #snapshot do
		snapshot[index](self, reason or "launcher-state", surface)
	end
end

function Service:IsVisible(surface)
	local key = visibilityKeys[surface]
	local database = key and getDatabase()
	return database ~= nil and database[key] ~= false
end

function Service:SetVisible(surface, visible, reason)
	local key = visibilityKeys[surface]
	local database = key and getDatabase()
	if not database then
		return false
	end
	visible = visible == true
	local changed = (database[key] ~= false) ~= visible
	database[key] = visible
	if changed then
		self:NotifyChanged(reason or "visibility", surface)
	end
	return changed
end

function Service:IsMinimapVisible()
	return self:IsVisible(self.SURFACE_MINIMAP)
end

function Service:SetMinimapVisible(visible, reason)
	return self:SetVisible(
		self.SURFACE_MINIMAP, visible, reason or "minimap-visibility")
end

function Service:IsFloatVisible()
	return self:IsVisible(self.SURFACE_FLOAT)
end

function Service:SetFloatVisible(visible, reason)
	return self:SetVisible(
		self.SURFACE_FLOAT, visible, reason or "float-visibility")
end

function Service:GetMinimapAngle()
	local database = getDatabase()
	return database and toFiniteNumber(database.minimapAngle)
		or DEFAULT_MINIMAP_ANGLE
end

function Service:SetMinimapAngle(angle, reason)
	angle = toFiniteNumber(angle)
	local database = angle and getDatabase()
	if not database then
		return false
	end
	local changed = database.minimapAngle ~= angle
	database.minimapAngle = angle
	if changed then
		self:NotifyChanged(reason or "minimap-position", self.SURFACE_MINIMAP)
	end
	return changed
end

Service.SaveMinimapAngle = Service.SetMinimapAngle

function Service:UsesSquareMinimapOrbit()
	local database = getDatabase()
	return database ~= nil and database.minimapSquareOrbit == true
end

function Service:SetSquareMinimapOrbit(enabled, reason)
	local database = getDatabase()
	if not database then
		return false
	end
	enabled = enabled == true
	local changed = (database.minimapSquareOrbit == true) ~= enabled
	database.minimapSquareOrbit = enabled
	if changed then
		self:NotifyChanged(reason or "minimap-orbit", self.SURFACE_MINIMAP)
	end
	return changed
end

function Service:GetMinimapIconDB()
	local database = getDatabase()
	if not database then
		return nil
	end
	if type(database.minimapIcon) ~= "table" then
		database.minimapIcon = {}
	end
	local iconDatabase = database.minimapIcon
	iconDatabase.hide = not self:IsMinimapVisible()
	if toFiniteNumber(iconDatabase.minimapPos) == nil then
		iconDatabase.minimapPos = self:GetMinimapAngle()
	end
	return iconDatabase
end

function Service:IsFloatDragLocked()
	local database = getDatabase()
	return database ~= nil and database.lockFloatButton == true
end

function Service:SetFloatDragLocked(locked, reason)
	local database = getDatabase()
	if not database then
		return false
	end
	locked = locked == true
	local changed = (database.lockFloatButton == true) ~= locked
	database.lockFloatButton = locked
	if changed then
		self:NotifyChanged(reason or "float-drag-lock", self.SURFACE_FLOAT)
	end
	return changed
end

function Service:GetFloatPosition()
	local database = getDatabase()
	if not database or type(database.floatPoint) ~= "string" then
		return nil
	end
	local offsetX = toFiniteNumber(database.floatX)
	local offsetY = toFiniteNumber(database.floatY)
	if offsetX == nil or offsetY == nil then
		return nil
	end
	local relativePoint = type(database.floatRelPoint) == "string"
		and database.floatRelPoint or database.floatPoint
	return database.floatPoint, relativePoint, offsetX, offsetY
end

function Service:SetFloatPosition(point, relativePoint, offsetX, offsetY, reason)
	if type(point) ~= "string" or point == "" then
		return false
	end
	offsetX = toFiniteNumber(offsetX)
	offsetY = toFiniteNumber(offsetY)
	local database = offsetX ~= nil and offsetY ~= nil and getDatabase()
	if not database then
		return false
	end
	if type(relativePoint) ~= "string" or relativePoint == "" then
		relativePoint = nil
	end
	local changed = database.floatPoint ~= point
		or database.floatRelPoint ~= relativePoint
		or database.floatX ~= offsetX
		or database.floatY ~= offsetY
	database.floatPoint = point
	database.floatRelPoint = relativePoint
	database.floatX = offsetX
	database.floatY = offsetY
	if changed then
		self:NotifyChanged(reason or "float-position", self.SURFACE_FLOAT)
	end
	return changed
end

Service.SaveFloatPosition = Service.SetFloatPosition

function Service:ClearFloatPosition(reason)
	local database = getDatabase()
	if not database then
		return false
	end
	local changed = database.floatPoint ~= nil
		or database.floatRelPoint ~= nil
		or database.floatX ~= nil
		or database.floatY ~= nil
	database.floatPoint = nil
	database.floatRelPoint = nil
	database.floatX = nil
	database.floatY = nil
	if changed then
		self:NotifyChanged(reason or "float-position", self.SURFACE_FLOAT)
	end
	return changed
end

function Service:GetState(surface)
	if surface == self.SURFACE_MINIMAP then
		return {
			visible = self:IsMinimapVisible(),
			angle = self:GetMinimapAngle(),
			squareOrbit = self:UsesSquareMinimapOrbit(),
		}
	end
	if surface == self.SURFACE_FLOAT then
		local point, relativePoint, offsetX, offsetY = self:GetFloatPosition()
		return {
			visible = self:IsFloatVisible(),
			locked = self:IsFloatDragLocked(),
			point = point,
			relativePoint = relativePoint,
			x = offsetX,
			y = offsetY,
		}
	end
	return nil
end

local function readMainVisibility(controller)
	if controller and type(controller.IsUserVisible) == "function" then
		return controller:IsUserVisible() == true
	end
	local frame = controller and controller.frame
	return frame and type(frame.IsShown) == "function"
		and frame:IsShown() == true or false
end

local function readCurrentTab()
	local tabBar = GF.TabBar
	return tabBar and type(tabBar.GetCurrent) == "function"
		and tabBar:GetCurrent() or nil
end

local function resolveClickContext(options)
	options = type(options) == "table" and options or {}
	local controller = options.mainController or GF.MainFrame
	local mainAvailable = options.mainFrameAvailable
	if mainAvailable == nil then
		mainAvailable = controller ~= nil
	end
	local mainVisible = options.mainVisible
	if mainVisible == nil then
		mainVisible = readMainVisibility(controller)
	end
	local currentTab = options.currentTab
	if currentTab == nil then
		currentTab = readCurrentTab()
	end
	return {
		mainController = controller,
		mainFrameAvailable = mainAvailable == true,
		mainVisible = mainVisible == true,
		currentTab = currentTab,
		activeListing = options.activeListing == true,
	}
end

local function targetIntent(context, targetTab, openIntent)
	if not context.mainVisible then
		return openIntent
	end
	if context.currentTab == targetTab then
		return Service.INTENT_HIDE_MAIN
	end
	return openIntent
end

function Service:ResolveClickIntent(surface, mouseButton, options)
	local context = resolveClickContext(options)
	if not context.mainFrameAvailable then
		return self.INTENT_NONE
	end
	if surface == self.SURFACE_FLOAT and context.activeListing then
		if mouseButton == "RightButton" then
			return self.INTENT_ACTIVE_LISTING_MENU
		end
		return targetIntent(context, GF.TAB_CREATE, self.INTENT_OPEN_CREATE)
	end
	if surface ~= self.SURFACE_MINIMAP and surface ~= self.SURFACE_FLOAT then
		return self.INTENT_NONE
	end
	if mouseButton == "RightButton" then
		return targetIntent(context, GF.TAB_CREATE, self.INTENT_OPEN_CREATE)
	end
	return targetIntent(context, GF.TAB_BROWSE, self.INTENT_OPEN_BROWSE)
end

local function invoke(controller, methodName)
	local method = controller and controller[methodName]
	if type(method) ~= "function" then
		return false
	end
	method(controller)
	return true
end

function Service:ExecuteClickIntent(intent, options)
	local controller = type(options) == "table" and options.mainController
		or GF.MainFrame
	if intent == self.INTENT_OPEN_BROWSE then
		return invoke(controller, "OpenBrowseTab")
		or invoke(controller, "Toggle")
	end
	if intent == self.INTENT_OPEN_CREATE then
		return invoke(controller, "OpenCreateTab")
		or invoke(controller, "Toggle")
	end
	if intent == self.INTENT_HIDE_MAIN then
		return invoke(controller, "HideFrame")
		or invoke(controller, "Toggle")
	end
	return false
end

function Service:HandleClick(surface, mouseButton, options)
	local intent = self:ResolveClickIntent(surface, mouseButton, options)
	return intent, self:ExecuteClickIntent(intent, options)
end
