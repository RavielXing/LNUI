local _, GF = ...

GF.MinimapButton = {}
local MM = GF.MinimapButton
local BROKER_NAME = "GroupFinderLauncher"
local btn
local ldbIcon
local initCustomButton
local ICON_TEX = GF.MINIMAP_ICON_TEXTURE or GF.ADDON_LOGO_TEXTURE
local EDGE_PAD = 5
local LAONONG_MINIMAP_BUTTON_NAMES = {
	"LibDBIcon10_" .. BROKER_NAME,
	"GroupFinderAddonMinimapButton",
}

local ICON_UP_SIZE = 22
local ICON_DOWN_SIZE = 20
local ICON_UP_Y = 1
local ICON_DOWN_Y = -1

local function applyLaonongMinimapCollector()
	local addDefaultCollect = _G.U1_MMBAddDefaultCollect
	if type(addDefaultCollect) == "function" then
		for _, buttonName in ipairs(LAONONG_MINIMAP_BUTTON_NAMES) do
			pcall(addDefaultCollect, buttonName)
		end
	end

	local function checkChildren()
		local checkMinimapChildren = _G.U1MMB_CheckMinimapChildren
		if type(checkMinimapChildren) == "function" then
			pcall(checkMinimapChildren)
		end
	end

	if C_Timer and type(C_Timer.After) == "function" then
		pcall(C_Timer.After, 0, checkChildren)
	else
		checkChildren()
	end
end

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

local function fillLauncherTooltip(tooltip)
	local L = GF.L or {}
	tooltip:AddLine(L.ADDON_NAME or "GroupFinder", 1, 1, 1)
	tooltip:AddLine(formatTooltipAction(
		L.MINIMAP_LEFT_CLICK or "Left-click", L.MINIMAP_TIP or ""),
		1, 0.82, 0)
	tooltip:AddLine(formatTooltipAction(
		L.MINIMAP_RIGHT_CLICK or "Right-click",
		L.MINIMAP_CREATE or "Open Create Listing"), 1, 0.82, 0)
end

local function createLauncherBroker(dataBroker)
	if type(dataBroker) ~= "table"
		or type(dataBroker.NewDataObject) ~= "function"
	then
		return nil
	end
	local L = GF.L or {}
	local ok, launcher = pcall(dataBroker.NewDataObject, dataBroker, BROKER_NAME, {
		type = "launcher",
		label = BROKER_NAME,
		text = L.ADDON_NAME or "GroupFinder",
		icon = ICON_TEX,
		OnClick = function(_, mouseButton)
			GF.HandleMinimapClick(mouseButton)
		end,
		OnTooltipShow = fillLauncherTooltip,
	})
	return ok and launcher or nil
end

local function tryInitLibDBIcon()
	if ldbIcon then
		return true
	end
	local resolver = GF.GetOptionalLibrary
	if type(resolver) ~= "function" then
		return false
	end
	local LDB = resolver("LibDataBroker-1.1")
	local LDBI = resolver("LibDBIcon-1.0")
	if type(LDB) ~= "table"
		or type(LDBI) ~= "table"
		or type(LDBI.IsRegistered) ~= "function"
		or type(LDBI.Register) ~= "function"
	then
		return false
	end
	local ok, registered = pcall(LDBI.IsRegistered, LDBI, BROKER_NAME)
	if not ok then
		return false
	end
	syncIconDBHide()
	if not registered then
		local launcher = createLauncherBroker(LDB)
		if launcher == nil then
			return false
		end
		ok = pcall(LDBI.Register, LDBI, BROKER_NAME, launcher, getIconDB())
		if not ok then
			return false
		end
	end
	ldbIcon = LDBI
	applyLaonongMinimapCollector()
	return true
end

function MM:UsesLibDBIcon()
	return ldbIcon ~= nil
end

local function halfExtents()
	local fallback = 80
	local canMeasure = Minimap and type(Minimap.GetWidth) == "function"
	if not canMeasure then
		return fallback, fallback
	end
	local halfWidth = (tonumber(Minimap:GetWidth()) or 0) * 0.5
	local halfHeight = (tonumber(Minimap:GetHeight()) or 0) * 0.5
	halfWidth = halfWidth > 0 and halfWidth or fallback
	halfHeight = halfHeight > 0 and halfHeight or halfWidth
	return halfWidth, halfHeight
end

local function applyLibDBIcon()
	if not ldbIcon then
		return
	end
	syncIconDBHide()
	local methodName = isMinimapButtonEnabled() and "Show" or "Hide"
	local setShown = ldbIcon[methodName]
	if setShown then
		setShown(ldbIcon, BROKER_NAME)
	end
end

local function useSquareOrbit()
	return GF.GetDB().minimapSquareOrbit == true
end

local function directionForDegrees(angleDeg)
	local radians = math.rad(angleDeg)
	return math.cos(radians), math.sin(radians)
end

local function offsetCircle(angleDeg, halfWidth)
	local dx, dy = directionForDegrees(angleDeg)
	local radius = halfWidth + EDGE_PAD
	return dx * radius, dy * radius
end

local function offsetSquare(angleDeg, halfWidth, halfHeight)
	local dx, dy = directionForDegrees(angleDeg)
	local absX, absY = math.abs(dx), math.abs(dy)
	local extentX = halfWidth + EDGE_PAD
	local extentY = halfHeight + EDGE_PAD
	local epsilon = 1e-6
	local radius
	if absX < epsilon then
		radius = extentY
	elseif absY < epsilon then
		radius = extentX
	else
		local hitsVerticalEdge = absX / extentX >= absY / extentY
		radius = hitsVerticalEdge and extentX / absX or extentY / absY
	end
	return dx * radius, dy * radius
end

local function place(angleDeg)
	local button = btn
	if not button or not Minimap then
		return
	end
	local angle = angleDeg or GF.GetDB().minimapAngle or 225
	local halfWidth, halfHeight = halfExtents()
	local calculateOffset = useSquareOrbit() and offsetSquare or offsetCircle
	local x, y = calculateOffset(angle, halfWidth, halfHeight)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
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

local function updateDragAngle(button)
	local minimapX, minimapY = Minimap:GetCenter()
	local cursorX, cursorY = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	cursorX, cursorY = cursorX / scale, cursorY / scale
	button._angle = math.deg(math.atan2(
		cursorY - minimapY, cursorX - minimapX))
	place(button._angle)
end

local function beginCustomButtonDrag(button)
	restoreIcon()
	button:SetScript("OnUpdate", updateDragAngle)
end

local function finishCustomButtonDrag(button)
	button:SetScript("OnUpdate", nil)
	restoreIcon()
	local angle = button._angle
	if angle ~= nil then
		GF.GetDB().minimapAngle = angle
		button._angle = nil
	end
end

local function showCustomButtonTooltip(owner)
	local L = GF.L or {}
	GF.UI.BeginGameTooltip(owner, "ANCHOR_LEFT")
	GameTooltip:ClearLines()
	GameTooltip:SetText(L.ADDON_NAME or "GroupFinder", 1, 1, 1)
	GameTooltip:AddLine(formatTooltipAction(
		L.MINIMAP_LEFT_CLICK or "Left-click", L.MINIMAP_TIP or ""),
		1, 0.82, 0, false)
	GameTooltip:AddLine(formatTooltipAction(
		L.MINIMAP_RIGHT_CLICK or "Right-click",
		L.MINIMAP_CREATE or "Open Create Listing"), 1, 0.82, 0, false)
	GF.UI.ShowGameTooltip()
end

local function hideCustomButtonTooltip()
	restoreIcon()
	GameTooltip_Hide()
end

local function placeAfterLogin(eventFrame)
	eventFrame:UnregisterEvent("PLAYER_LOGIN")
	local after = C_Timer and C_Timer.After
	if type(after) == "function" then
		after(0, place)
	else
		place()
	end
end

local function createCustomMinimapButton()
	local button = CreateFrame("Button", "GroupFinderAddonMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(50, 50)
	border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON_TEX)
	icon:SetTexCoord(0, 1, 0, 1)
	icon:SetSize(ICON_UP_SIZE, ICON_UP_SIZE)
	icon:SetPoint("CENTER", button, "CENTER", 0, ICON_UP_Y)
	button.icon = icon
	return button
end

initCustomButton = function()
	if btn or not Minimap then
		return
	end

	btn = createCustomMinimapButton()

	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")

	btn:SetScript("OnMouseDown", pressIcon)
	btn:SetScript("OnMouseUp", restoreIcon)
	btn:SetScript("OnDragStart", beginCustomButtonDrag)
	btn:SetScript("OnDragStop", finishCustomButtonDrag)
	btn:SetScript("OnClick", function(_, button)
		GF.HandleMinimapClick(button)
	end)
	btn:SetScript("OnEnter", showCustomButtonTooltip)
	btn:SetScript("OnLeave", hideCustomButtonTooltip)

	if GF.ApplyFrameStrata then
		GF.ApplyFrameStrata()
	end
	applyCustomButton()
	applyLaonongMinimapCollector()

	-- NDui/ElvUI 等在 PLAYER_LOGIN 才改 Minimap 尺寸；ADDON_LOADED 首帧 halfExtents 会偏大导致 /reload 偏移
	local loginFrame = CreateFrame("Frame")
	loginFrame:RegisterEvent("PLAYER_LOGIN")
	loginFrame:SetScript("OnEvent", placeAfterLogin)
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
