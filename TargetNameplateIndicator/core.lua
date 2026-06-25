local addon, TNI = ...

local LNR = LibStub("LibNameplateRegistry-1.0")

LibStub("AceAddon-3.0"):NewAddon(TNI, addon, "AceConsole-3.0")

-- 检查是否支持秘密限制系统
local hasSecretRestrictions = C_Secrets and C_Secrets.ShouldUnitComparisonBeSecret and true or false

local function SafeUnitIsUnit(unit1, unit2)
	if not unit1 or not unit2 then return false end

	-- 如果启用了秘密限制，预先检查比较是否会是秘密的
	if hasSecretRestrictions and C_Secrets.ShouldUnitComparisonBeSecret(unit1, unit2) then
		-- 在秘密限制状态下，保守返回 false，避免 UnitIsUnit 返回 secret boolean
		return false
	end

	local success, result = pcall(UnitIsUnit, unit1, unit2)
	if success then
		return result
	end

	local success1, guid1 = pcall(UnitGUID, unit1)
	local success2, guid2 = pcall(UnitGUID, unit2)
	if success1 and success2 and guid1 and guid2 then
		return guid1 == guid2
	end
	return false
end

local function SafeUnitIsFriend(unit1, unit2)
	if not unit1 or not unit2 then return false end

	-- 在秘密限制状态下，如果单位比较是秘密的，保守地返回 false（视为非友方）
	if hasSecretRestrictions and C_Secrets.ShouldUnitComparisonBeSecret(unit1, unit2) then
		return false
	end

	local success, result = pcall(UnitIsFriend, unit1, unit2)
	if success then
		return result
	end

	return false
end

local function SafeBoolean(value)
	if type(value) == "boolean" then
		return value
	end
	local success, result = pcall(function() return value and true or false end)
	if success then
		return result
	end
	return false
end

local print, format = print, string.format

local function errorPrint(fatal, formatString, ...)
	local message = "|cffFF0000LibNameplateRegistry has encountered a" .. (fatal and " fatal" or "n") .. " error:|r"
	print("TargetNameplateIndicator:", message, format(formatString, ...))
end

function TNI:OnError_FatalIncompatibility(callback, incompatibilityType)
	local detailedMessage
	if incompatibilityType == "TRACKING: OnHide" or incompatibilityType == "TRACKING: OnShow" then
		detailedMessage = "LibNameplateRegistry missed several nameplate show and hide events."
	elseif incompatibilityType == "TRACKING: OnShow missed" then
		detailedMessage = "A nameplate was hidden but never shown."
	else
		detailedMessage = "Something has gone terribly wrong!"
	end

	errorPrint(true, "(Error Code: %s) %s", incompatibilityType, detailedMessage)
end

local defaults

do
	local function CreateUnitReactionTypeDefaults()
		return {
			enable = true,
			texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\Reticule",
			height = 50,
			width = 50,
			frameStrata = "BACKGROUND",
			opacity = 1,
			texturePoint = "BOTTOM",
			anchorPoint = "TOP",
			xOffset = 0,
			yOffset = 5,
		}
	end

	local function CreateUnitDefaults()
		return {
			enable = true,
			self = CreateUnitReactionTypeDefaults(),
			friendly = CreateUnitReactionTypeDefaults(),
			hostile = CreateUnitReactionTypeDefaults(),
		}
	end

	defaults = {
		profile = {
			target = CreateUnitDefaults(),
			mouseover = CreateUnitDefaults(),
			focus = CreateUnitDefaults(),
			targettarget = CreateUnitDefaults(),
		}
	}
end

function TNI:OnInitialize()
	LNR:Embed(self)
	self.db = LibStub("AceDB-3.0"):New("TargetNameplateIndicatorDB", defaults, true)
	self:RegisterOptions()

	self:LNR_RegisterCallback("LNR_ERROR_FATAL_INCOMPATIBILITY", "OnError_FatalIncompatibility")
end

function TNI:OnEnable()
	for unit, indicator in pairs(self.Indicators) do
		indicator:Show()
	end
end

function TNI:OnDisable()
	for unit, indicator in pairs(self.Indicators) do
		indicator:Hide()
	end
end

function TNI:RefreshIndicator(unit)
	local indicator = self.Indicators[unit]

	if not indicator then
		error("Invalid unit \"" .. unit .. "\"")
	end

	indicator:Refresh()
end

TNI.Indicators = {}

local Indicator = {}

function Indicator:Update(nameplate, skipConfigCheck)
	-- 在秘密限制状态下，如果与 player 的比较是秘密的，隐藏指示器避免后续布尔判断出错
	if hasSecretRestrictions and C_Secrets.ShouldUnitComparisonBeSecret(self.unit, "player") then
		self:Hide()
		self.Texture:Hide()
		return
	end

	self.currentNameplate = nameplate
	self.Texture:ClearAllPoints()

	local config
	if not skipConfigCheck then
		local unitConfig = TNI.db.profile[self.unit]

		local isSelf = SafeUnitIsUnit("player", self.unit)
		local isFriend = SafeUnitIsFriend("player", self.unit)

		if isSelf then
			config = unitConfig.self
		elseif isFriend then
			config = unitConfig.friendly
		else
			config = unitConfig.hostile
		end

		local shouldShow = SafeBoolean(unitConfig.enable)
		self:SetShown(shouldShow)
		self.enabled = shouldShow
	end

	if nameplate and config and SafeBoolean(config.enable) then
		local texture = config.texture
		if texture == "custom" then
			texture = config.textureCustom
		end

		self:SetFrameStrata(config.frameStrata)
		self.Texture:Show()
		self.Texture:SetTexture(texture)
		self.Texture:SetSize(config.width, config.height)
		self.Texture:SetAlpha(config.opacity)
		self.Texture:SetPoint(config.texturePoint, nameplate, config.anchorPoint, config.xOffset, config.yOffset)
	else
		self.Texture:Hide()
	end
end

function Indicator:Refresh()
	self:Update(self.currentNameplate)
end

function Indicator:OnRecyclePlate(callback, nameplate, plateData)
	if nameplate == self.currentNameplate then
		self:Update()
	end
end

function Indicator:CheckAndHideLowerPriorityIndicators()
	for unit, indicator in pairs(TNI.Indicators) do
		if indicator.enabled and self.unit ~= unit and SafeUnitIsUnit(self.unit, unit) then
			if self.priority > indicator.priority then
				indicator:Update()
				return true
			else
				return false
			end
		end
	end

	return true
end

local GetNamePlateUnit
if NamePlateBaseMixin and NamePlateBaseMixin.GetUnit then
	GetNamePlateUnit = function(nameplate)
		return nameplate:GetUnit()
	end
else
	GetNamePlateUnit = function(nameplate)
		return nameplate.namePlateUnitToken
	end
end

function Indicator:VerifyNameplateUnit()
	if self.currentNameplate and not GetNamePlateUnit(self.currentNameplate) then
		TNI.db.profile[self.unit].enable = false
		self:Hide()

		error((
			"TargetNameplateIndicator: %s indicator found a nameplate without a unit token and as such is unable to function." ..
			" This is usually caused by AddOns that replace the default nameplates (e.g. EKPlates)." ..
			" This indicator will now be disabled until it's re-enabled in the options menu."
		):format(self.unit))
	end

	return true
end

local function CreateIndicator(unit, priority)
	local indicator = CreateFrame("Frame", "TargetNameplateIndicator_" .. unit)

	indicator:SetFrameStrata("BACKGROUND")
	indicator.Texture = indicator:CreateTexture("$parentTexture", "OVERLAY")

	indicator.unit = unit
	indicator.priority = priority

	LNR:Embed(indicator)
	Mixin(indicator, Indicator)

	indicator:LNR_RegisterCallback("LNR_ON_RECYCLE_PLATE", "OnRecyclePlate")

	indicator:SetScript("OnEvent", function(self, event, ...)
		self[event](self, ...)
	end)

	TNI.Indicators[unit] = indicator

	return indicator
end

local NonTargetIndicator = {}

function NonTargetIndicator:Disable()
	self:Update(nil, true)
	self.enabled = false
	self:Hide()
end

function NonTargetIndicator:Enable()
	self:Show()
	self:Refresh()
end

function NonTargetIndicator:OnUpdate()
	if hasSecretRestrictions and C_Secrets.ShouldUnitComparisonBeSecret(self.unit, "player") then
		self:Disable()
		return
	end

	if self.currentNameplate and self:VerifyNameplateUnit() and SafeUnitIsUnit(self.unit, GetNamePlateUnit(self.currentNameplate)) then
		return
	end

	if not self.currentNameplate and not UnitExists(self.unit) then
		return
	end

	if self.unit == "targettarget" then
		if self.currentNameplate then
			self:Update(nil)
		end
		return
	end

	local nameplate = C_NamePlate.GetNamePlateForUnit(self.unit)

	local shouldDisplay = self:CheckAndHideLowerPriorityIndicators()

	if shouldDisplay then
		self:Update(nameplate)
	else
		self:Update(nil)
	end
end

function NonTargetIndicator:ADDON_RESTRICTION_STATE_CHANGED(type, state)
	if state == Enum.AddOnRestrictionState.Inactive and not C_Secrets.ShouldUnitComparisonBeSecret(self.unit, "player") then
		self:Enable()
	end
end

local function CreateNonTargetIndicator(unit, priority)
	local indicator = CreateIndicator(unit, priority)

	Mixin(indicator, NonTargetIndicator)

	indicator:SetScript("OnUpdate", indicator.OnUpdate)

	if hasSecretRestrictions then
		indicator:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
	end

	return indicator
end

local TargetIndicator = CreateIndicator("target", 100)

function TargetIndicator:PLAYER_TARGET_CHANGED()
	local nameplate = C_NamePlate.GetNamePlateForUnit(self.unit)

	if not nameplate then
		self:Update()
	end
end

function TargetIndicator:OnTargetPlateOnScreen(callback, nameplate, plateData)
	local shouldDisplay = self:CheckAndHideLowerPriorityIndicators()

	if shouldDisplay then
		self:Update(nameplate)
	else
		self:Update()
	end
end

TargetIndicator:RegisterEvent("PLAYER_TARGET_CHANGED")
TargetIndicator:LNR_RegisterCallback("LNR_ON_TARGET_PLATE_ON_SCREEN", "OnTargetPlateOnScreen")

local MouseoverIndicator = CreateNonTargetIndicator("mouseover", 10)

local FocusIndicator = CreateNonTargetIndicator("focus", 90)

local TargetOfTargetIndicator = CreateNonTargetIndicator("targettarget", 50)
