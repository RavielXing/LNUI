local _, GF = ...

GF.MinimapButton = {}
local MM = GF.MinimapButton
local BROKER_NAME = "GroupFinderLauncher"
local btn
local ldbIcon
local initCustomButton
local ICON_TEX = GF.MINIMAP_ICON_TEXTURE or GF.ADDON_LOGO_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\Logo\\GroupFinderIcon.png"
local EDGE_PAD = 5

local ICON_UP_SIZE = 22
local ICON_DOWN_SIZE = 20
local ICON_UP_Y = 1
local ICON_DOWN_Y = -1

local function restoreIcon()
	if btn and btn.icon then
		btn.icon:SetSize(ICON_UP_SIZE, ICON_UP_SIZE)
		btn.icon:ClearAllPoints()
		btn.icon:SetPoint("CENTER", btn, "CENTER", 0, ICON_UP_Y)
		btn.icon:SetVertexColor(1, 1, 1, 1)
	end
end

local function pressIcon()
	if btn and btn.icon then
		btn.icon:SetSize(ICON_DOWN_SIZE, ICON_DOWN_SIZE)
		btn.icon:ClearAllPoints()
		btn.icon:SetPoint("CENTER", btn, "CENTER", 0, ICON_DOWN_Y)
		btn.icon:SetVertexColor(0.72, 1, 0.72, 1)
	end
end

local function formatTooltipAction(label, action)
	local L = GF.L or {}
	local fmt = L.MINIMAP_ACTION_FMT or "%s: %s"
	return string.format(fmt, label or "", action or "")
end

local function isMainFrameShown()
	local frame = GF.MainFrame and GF.MainFrame.frame
	return frame and frame:IsShown()
end

local function isMinimapButtonEnabled()
	return GF.GetDB().showMinimap ~= false
end

local function openCreateTab()
	GF.MainFrame:OpenCreateTab()
end

local function openMinimapTargetTab(tabID)
	if tabID == GF.TAB_CREATE then
		openCreateTab()
	else
		GF.MainFrame:OpenBrowseTab()
	end
end

function GF.HandleMinimapClick(mouseButton)
	if not GF.MainFrame then
		return
	end
	local targetTab = mouseButton == "RightButton" and GF.TAB_CREATE or GF.TAB_BROWSE
	if not isMainFrameShown() then
		openMinimapTargetTab(targetTab)
		return
	end
	local currentTab = GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar:GetCurrent()
	if currentTab == targetTab then
		GF.MainFrame:HideFrame()
	else
		openMinimapTargetTab(targetTab)
	end
end

function GF.HandleLauncherClick(mouseButton)
	GF.HandleMinimapClick(mouseButton)
end

local function getIconDB()
	local db = GF.GetDB()
	if not db.minimapIcon then
		db.minimapIcon = {
			hide = not isMinimapButtonEnabled(),
			minimapPos = db.minimapAngle or 225,
		}
	end
	return db.minimapIcon
end

local function syncIconDBHide()
	local iconDB = getIconDB()
	iconDB.hide = not isMinimapButtonEnabled()
	return iconDB
end

local function tryInitLibDBIcon()
	if ldbIcon then
		return true
	end
	if not LibStub then
		return false
	end
	local LDB = LibStub("LibDataBroker-1.1", true)
	local LDBI = LibStub("LibDBIcon-1.0", true)
	if not LDB or not LDBI then
		return false
	end
	if LDBI:IsRegistered(BROKER_NAME) then
		syncIconDBHide()
		ldbIcon = LDBI
		return true
	end
	syncIconDBHide()
	local L = GF.L or {}
	local obj = LDB:NewDataObject(BROKER_NAME, {
		type = "launcher",
		label = BROKER_NAME,
		text = L.ADDON_NAME or "GroupFinder",
		icon = ICON_TEX,
		OnClick = function(_, mouseButton)
			GF.HandleMinimapClick(mouseButton)
		end,
		OnTooltipShow = function(tooltip)
			local L = GF.L or {}
			tooltip:AddLine(L.ADDON_NAME or "GroupFinder", 1, 1, 1)
			tooltip:AddLine(formatTooltipAction(L.MINIMAP_LEFT_CLICK or "Left-click", L.MINIMAP_TIP or ""), 1, 0.82, 0)
			tooltip:AddLine(formatTooltipAction(L.MINIMAP_RIGHT_CLICK or "Right-click", L.MINIMAP_CREATE or "Open Create Listing"), 1, 0.82, 0)
		end,
	})
	LDBI:Register(BROKER_NAME, obj, getIconDB())
	ldbIcon = LDBI
	return true
end

function MM:UsesLibDBIcon()
	return ldbIcon ~= nil
end

local function halfExtents()
	if not Minimap or not Minimap.GetWidth then
		return 80, 80
	end
	local hw = (Minimap:GetWidth() or 0) / 2
	local hh = (Minimap:GetHeight() or 0) / 2
	if hw <= 0 then
		hw = 80
	end
	if hh <= 0 then
		hh = hw
	end
	return hw, hh
end

local function applyLibDBIcon()
	if not ldbIcon then
		return
	end
	syncIconDBHide()
	if isMinimapButtonEnabled() then
		ldbIcon:Show(BROKER_NAME)
	else
		ldbIcon:Hide(BROKER_NAME)
	end
end

local function useSquareOrbit()
	return GF.GetDB().minimapSquareOrbit == true
end

local function offsetCircle(angleDeg, hw)
	local a = math.rad(angleDeg)
	local r = hw + EDGE_PAD
	return math.cos(a) * r, math.sin(a) * r
end

local function offsetSquare(angleDeg, hw, hh)
	local a = math.rad(angleDeg)
	local cosA, sinA = math.cos(a), math.sin(a)
	local ax, ay = math.abs(cosA), math.abs(sinA)
	local outerW, outerH = hw + EDGE_PAD, hh + EDGE_PAD
	local r
	if ax < 1e-6 then
		r = outerH
	elseif ay < 1e-6 then
		r = outerW
	elseif ax / outerW >= ay / outerH then
		r = outerW / ax
	else
		r = outerH / ay
	end
	return cosA * r, sinA * r
end

local function place(angleDeg)
	if not btn or not Minimap then
		return
	end
	local angle = angleDeg or GF.GetDB().minimapAngle or 225
	local hw, hh = halfExtents()
	local x, y
	if useSquareOrbit() then
		x, y = offsetSquare(angle, hw, hh)
	else
		x, y = offsetCircle(angle, hw)
	end
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function applyCustomButton()
	if not btn then
		return
	end
	if isMinimapButtonEnabled() then
		btn:Show()
		place()
	else
		btn:Hide()
	end
end

function MM:Apply()
	if ldbIcon then
		applyLibDBIcon()
		return
	end
	if not btn and tryInitLibDBIcon() then
		applyLibDBIcon()
		return
	end
	if not btn and initCustomButton then
		initCustomButton()
	end
	applyCustomButton()
end

initCustomButton = function()
	if btn or not Minimap then
		return
	end

	btn = CreateFrame("Button", "GroupFinderAddonMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetSize(50, 50)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON_UP_SIZE, ICON_UP_SIZE)
	icon:SetPoint("CENTER", btn, "CENTER", 0, ICON_UP_Y)
	icon:SetTexture(ICON_TEX)
	icon:SetTexCoord(0, 1, 0, 1)
	btn.icon = icon

	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")

	btn:SetScript("OnMouseDown", pressIcon)
	btn:SetScript("OnMouseUp", restoreIcon)

	btn:SetScript("OnDragStart", function(self)
		restoreIcon()
		self:SetScript("OnUpdate", function(s)
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			px, py = px / scale, py / scale
			s._angle = math.deg(math.atan2(py - my, px - mx))
			place(s._angle)
		end)
	end)

	btn:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		restoreIcon()
		if self._angle then
			GF.GetDB().minimapAngle = self._angle
			self._angle = nil
		end
	end)

	btn:SetScript("OnClick", function(_, button)
		GF.HandleMinimapClick(button)
	end)

	btn:SetScript("OnEnter", function(self)
		local L = GF.L or {}
		GF.UI.BeginGameTooltip(self, "ANCHOR_LEFT")
		GameTooltip:ClearLines()
		GameTooltip:SetText(L.ADDON_NAME or "GroupFinder", 1, 1, 1)
		GameTooltip:AddLine(formatTooltipAction(L.MINIMAP_LEFT_CLICK or "Left-click", L.MINIMAP_TIP or ""), 1, 0.82, 0, false)
		GameTooltip:AddLine(formatTooltipAction(L.MINIMAP_RIGHT_CLICK or "Right-click", L.MINIMAP_CREATE or "Open Create Listing"), 1, 0.82, 0, false)
		GF.UI.ShowGameTooltip()
	end)
	btn:SetScript("OnLeave", function()
		restoreIcon()
		GameTooltip_Hide()
	end)

	if GF.ApplyFrameStrata then
		GF.ApplyFrameStrata()
	end
	applyCustomButton()

	-- NDui/ElvUI 等在 PLAYER_LOGIN 才改 Minimap 尺寸；ADDON_LOADED 首帧 halfExtents 会偏大导致 /reload 偏移
	local loginFrame = CreateFrame("Frame")
	loginFrame:RegisterEvent("PLAYER_LOGIN")
	loginFrame:SetScript("OnEvent", function(self)
		self:UnregisterEvent("PLAYER_LOGIN")
		if C_Timer and C_Timer.After then
			C_Timer.After(0, place)
		else
			place()
		end
	end)
end

function MM:Init()
	if MM._initStarted or not Minimap then
		return
	end
	MM._initStarted = true

	if tryInitLibDBIcon() then
		MM:Apply()
		return
	end

	local function initAfterLogin()
		if tryInitLibDBIcon() then
			MM:Apply()
		else
			initCustomButton()
		end
	end

	if IsLoggedIn and IsLoggedIn() then
		initAfterLogin()
		return
	end

	local loginFrame = CreateFrame("Frame")
	loginFrame:RegisterEvent("PLAYER_LOGIN")
	loginFrame:SetScript("OnEvent", function(self)
		self:UnregisterEvent("PLAYER_LOGIN")
		initAfterLogin()
	end)
end

function MM:GetButtonFrame()
	if ldbIcon then
		return ldbIcon:GetMinimapButton(BROKER_NAME)
	end
	return btn
end
