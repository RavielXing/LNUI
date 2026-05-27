------------------------------------------------------------
-- Templates.lua
--
-- Abin
-- 2015-9-06
------------------------------------------------------------

local CreateFrame = CreateFrame
local GetTime = GetTime
local tinsert = tinsert
local UISpecialFrames = UISpecialFrames
local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS

local addon = WhisperPop
local L = addon.L

local templates = {}
addon.templates = templates

function templates.CreateFrame(name, parent, movable)
	local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:SetBackdrop({ bgFile = addon.BACKGROUND, tile = true, tileSize = 16, edgeFile = addon.BORDER, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 } })

	if movable then
		frame:SetMovable(true)
		frame:SetUserPlaced(true)
		frame:SetDontSavePosition(false)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	end

	local text = frame:CreateFontString(name.."Text", "ARTWORK", "GameFontNormal")
	frame.text = text
	text:SetPoint("TOP", 0, -10)

	local topClose = CreateFrame("Button", name.."TopCloseButton", frame, "UIPanelCloseButton")
	frame.topClose = topClose
	topClose:SetSize(24, 24)
	topClose:SetPoint("TOPRIGHT", -5, -5)

	local topLine = frame:CreateTexture(name.."TopLine", "ARTWORK")
	frame.topLine = topLine
	topLine:SetTexture("Interface\\OptionsFrame\\UI-OptionsFrame-Spacer")
	topLine:SetVertexColor(1, 1, 1, 0.5)
	topLine:SetHeight(16)
	topLine:SetPoint("LEFT", frame, "TOPLEFT", 4, -28)
	topLine:SetPoint("RIGHT", frame, "TOPRIGHT", -4, -28)

	tinsert(UISpecialFrames, name)
	return frame
end

local function DelayHideFrame_OnUpdate(self, elapsed)
	if self.hideTime and GetTime() > self.hideTime then
		self.hideTime = nil
		self:SetScript("OnUpdate", nil)
		self:Hide()
	end
end

local function DelayHideFrame_StartCounting(self)
	self.hideTime = GetTime() + 0.2
	if not self:GetScript("OnUpdate") then
		self:SetScript("OnUpdate", DelayHideFrame_OnUpdate)
	end
end

local function DelayHideFrame_StopCounting(self, show)
	self.hideTime = nil
	self:SetScript("OnUpdate", nil)
	if show then
		self:Show()
	end
end

function templates.RegisterDelayHideFrame(frame)
	frame:SetScript("OnEnter", DelayHideFrame_StopCounting)
	frame:SetScript("OnLeave", DelayHideFrame_StartCounting)
	frame.StartCounting = DelayHideFrame_StartCounting
	frame.StopCounting = DelayHideFrame_StopCounting
end

local function IconButton_OnMouseDown(self)
	self.icon:SetPoint("CENTER", 1, -1)
end

local function IconButton_OnMouseUp(self)
	self.icon:SetPoint("CENTER")
end

function templates.CreateIconButton(name, parent, icon, size, checkable)
	local button = CreateFrame(checkable and "CheckButton" or "Button", name, parent)
	button:SetSize(size, size)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	if checkable then
		button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
		button:GetCheckedTexture():SetBlendMode("ADD")
	end

	button.icon = button:CreateTexture(name and (name.."Icon"), "ARTWORK")
	button.icon:SetSize(size, size)
	button.icon:SetPoint("CENTER")
	button.icon:SetTexture(icon)
	button:SetScript("OnMouseDown", IconButton_OnMouseDown)
	button:SetScript("OnMouseUp", IconButton_OnMouseUp)
	return button
end

function templates.ShowPlayerInfo(data, texture, fontString, forceRealm)
	if not data then
		return
	end

	if data.class == "GM" then
		texture:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Blizz")
		texture:SetTexCoord(0.18, 0.82, 0, 1)
	elseif data.class == "BN" then
		texture:SetTexture("Interface\\AddOns\\WhisperPop\\Media\\Textures\\BattleNet.png")
		texture:SetTexCoord(0, 1, 0, 1)
	else
		local coords = CLASS_ICON_TCOORDS[data.class]
		if coords then
			texture:SetTexture("Interface\\WorldStateFrame\\Icons-Classes")
			texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			texture:SetTexture()
		end
	end

	fontString:SetText(addon:GetDisplayName(data.name, forceRealm))
end

local function FlashFrame_CancelTicker(self)
	local t = self.flashTicker
	if t then
		t:Cancel()
		self.flashTicker = nil
	end
end

local function FlashFrame_OnTick(self)
	if not self:IsShown() then
		FlashFrame_CancelTicker(self)
		return
	end
	if self.stopTime and GetTime() > self.stopTime then
		self:Hide()
		return
	end
	if self.texture:IsShown() then
		self.texture:Hide()
	else
		self.texture:Show()
	end
end

local function FlashFrame_OnShow(self)
	self.texture:Show()
	FlashFrame_CancelTicker(self)
	if C_Timer and C_Timer.NewTicker then
		self.flashTicker = C_Timer.NewTicker(0.5, function()
			FlashFrame_OnTick(self)
		end)
	else
		self:SetScript("OnUpdate", function(f, elapsed)
			f._flashElapsed = (f._flashElapsed or 0) + elapsed
			if f._flashElapsed < 0.5 then
				return
			end
			f._flashElapsed = 0
			FlashFrame_OnTick(f)
		end)
	end
end

local function FlashFrame_OnHide(self)
	FlashFrame_CancelTicker(self)
	self:SetScript("OnUpdate", nil)
	self._flashElapsed = nil
end

local function FlashParent_StartFlash(self, duration)
	if type(duration) ~= "number" or duration <= 0 then
		duration = nil
	end

	if duration then
		self.flashFrame.stopTime = GetTime() + duration
	else
		self.flashFrame.stopTime = nil
	end

	self.flashFrame:Show()
end

local function FlashParent_StopFlash(self)
	self.flashFrame:Hide()
end

function templates.CreateFlash(parent)
	local name = parent:GetName()
	local frame = CreateFrame("Frame", name and name.."FlashFrame", parent)
	parent.flashFrame = frame
	frame:SetAllPoints(parent)
	frame:Hide()

	frame:SetScript("OnShow", FlashFrame_OnShow)
	frame:SetScript("OnHide", FlashFrame_OnHide)

	local texture = frame:CreateTexture(name and name.."FlashFrameTexture", "OVERLAY")
	frame.texture = texture
	texture:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-BlinkHilight")
	texture:SetAllPoints(frame)
	texture:Hide()

	parent.StartFlash = FlashParent_StartFlash
	parent.StopFlash = FlashParent_StopFlash

	return frame
end