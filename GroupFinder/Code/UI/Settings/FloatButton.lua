local _, GF = ...

GF.FloatButton = {}
local FB = GF.FloatButton

local btn
local backHost
local chromeHost
local frameTexture
local animationTicker
local animationFrames
local animationFramePos = 1
local animationElapsed = 0
local animationLoop = false
local chromeState = "idle"
local contentHost
local icon
local floatingEye
local statusHost
local applicantText
local groupText

local TEAMUP_TEX = GF.TEAMUP_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\TeamUp.png"
local FRAME_TEX = GF.FLOATING_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\Floating.png"
local FRAME_ATLAS_COLS = 6
local FRAME_ATLAS_ROWS = 15
local FRAME_ATLAS_IMAGE_W = 2048
local FRAME_ATLAS_IMAGE_H = 2048
local FRAME_ATLAS_CELL_W = 320
local FRAME_ATLAS_CELL_H = 80
local FRAME_ATLAS_TEXEL_U = 0.5 / FRAME_ATLAS_IMAGE_W
local FRAME_ATLAS_TEXEL_V = 0.5 / FRAME_ATLAS_IMAGE_H
local FRAME_STATIC_CELL = 0
local function makeFrameRange(startIndex, endIndex)
	local frames = {}
	for index = startIndex, endIndex do
		frames[#frames + 1] = index
	end
	return frames
end
local FRAME_EXPANDED_CELL = 19
local EXPAND_FRAMES = makeFrameRange(0, 19)
local FLASH_FRAMES = makeFrameRange(20, 79)
local COLLAPSE_FRAMES = makeFrameRange(80, 87)
local LEGACY_SEQUENCE_FRAME_DURATION = 0.05
local EXPAND_FRAME_DURATION = (10 * LEGACY_SEQUENCE_FRAME_DURATION) / #EXPAND_FRAMES
local FLASH_FRAME_DURATION = LEGACY_SEQUENCE_FRAME_DURATION
local COLLAPSE_FRAME_DURATION = (4 * LEGACY_SEQUENCE_FRAME_DURATION) / #COLLAPSE_FRAMES
local animationFrameDuration = LEGACY_SEQUENCE_FRAME_DURATION
local FRAME_W = 160
local FRAME_H = 40
local FRAME_BG_W = 172
local FRAME_BG_H = 43
local BACK_EYE_SIZE = 40
local EYE_TEMPLATE_NATIVE_SIZE = 45
local FLOATING_EYE_SCALE = BACK_EYE_SIZE / EYE_TEMPLATE_NATIVE_SIZE
local STATUS_AREA_LEFT = 42
local STATUS_AREA_RIGHT = 8
local STATUS_CENTER_OFFSET_X = ((STATUS_AREA_LEFT + (FRAME_W - STATUS_AREA_RIGHT)) / 2) - (FRAME_W / 2)
local STATUS_CENTER_OFFSET_Y = 0
local STATUS_MAX_W = FRAME_W - STATUS_AREA_LEFT - STATUS_AREA_RIGHT
local FRAME_SOURCE_CENTER_X = FRAME_ATLAS_CELL_W / 2
local FRAME_RENDER_SCALE_X = FRAME_BG_W / FRAME_ATLAS_CELL_W
local APPLICANT_COUNT_SOURCE_X = (56 + 129) / 2
local GROUP_COUNT_SOURCE_X = (190 + 262) / 2
local APPLICANT_COUNT_OFFSET_X = (APPLICANT_COUNT_SOURCE_X - FRAME_SOURCE_CENTER_X) * FRAME_RENDER_SCALE_X
local GROUP_COUNT_OFFSET_X = (GROUP_COUNT_SOURCE_X - FRAME_SOURCE_CENTER_X) * FRAME_RENDER_SCALE_X
local DEFAULT_TOP_OFFSET_FRACTION = 0.02
local DEFAULT_TOP_OFFSET_FALLBACK = -32
local TEAMUP_IMAGE_W = 372
local TEAMUP_FRAME_W = TEAMUP_IMAGE_W / 3
local TEAMUP_FRAME_H = 116
local TOOLTIP_ICON_SIZE = 18
local FLOAT_TOOLTIP_OFFSET_Y = -(GF.TOOLTIP_BUTTON_TOP_GAP or 4)
local TEAMUP_FRAMES = {
	applicant = { 0, 116, 0, 116 },
	group = { (TEAMUP_FRAME_W * 2) + 8, TEAMUP_IMAGE_W, 0, 116 },
}
local FLOAT_CTX_MENU_MIN_W = GF.CONTEXT_MENU_MIN_W or 140
local FLOAT_CTX_ANCHOR_GAP_Y = -8
local FLOAT_RESTRICTED_ALPHA = 0.15

local function isDragLocked()
	return GF.GetDB().lockFloatButton == true
end

local function syncFloatingLayerLevels()
	if not btn then
		return
	end
	local baseLevel = btn:GetFrameLevel() or 0
	if backHost then
		backHost:SetFrameLevel(baseLevel + 1)
	end
	if floatingEye then
		floatingEye:SetFrameLevel(baseLevel + 2)
	end
	if chromeHost then
		chromeHost:SetFrameLevel(baseLevel + 3)
	end
	if contentHost then
		contentHost:SetFrameLevel(baseLevel + 4)
	end
end

local function savePosition()
	if not btn then
		return
	end
	local db = GF.GetDB()
	local point, _, relPoint, x, y = btn:GetPoint(1)
	if point then
		db.floatPoint = point
		db.floatRelPoint = relPoint
		db.floatX = x
		db.floatY = y
	end
end

local function applyDragLock()
	if not btn then
		return
	end
	btn:SetMovable(not isDragLocked())
end

local function restorePosition()
	if not btn then
		return
	end
	local db = GF.GetDB()
	btn:ClearAllPoints()
	if db.floatX ~= nil and db.floatY ~= nil and db.floatPoint then
		btn:SetPoint(db.floatPoint, UIParent, db.floatRelPoint or db.floatPoint, db.floatX, db.floatY)
	else
		local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight()
		local defaultY = DEFAULT_TOP_OFFSET_FALLBACK
		if parentHeight and parentHeight > 0 then
			defaultY = -math.floor((parentHeight * DEFAULT_TOP_OFFSET_FRACTION) + 0.5)
		end
		btn:SetPoint("TOP", UIParent, "TOP", 0, defaultY)
	end
end

local function getTextWidth(text, fallback)
	if not text then
		return fallback or 0
	end
	local width = text:GetStringWidth()
	if not width or width <= 0 then
		width = text:GetWidth() or 0
	end
	if not width or width <= 0 then
		width = fallback or 0
	end
	return math.ceil(width)
end

local function hasActiveListing()
	if GF.MainFrame and GF.MainFrame.HasActiveListing then
		return GF.MainFrame:HasActiveListing()
	end
	return GF.Listing and GF.Listing.HasActive and GF.Listing:HasActive()
end

local function getApplicantStatusCount()
	local listed = hasActiveListing()
	if listed and GF.Listing and GF.Listing.GetApplicantCount then
		return tonumber(GF.Listing:GetApplicantCount()) or 0, true
	end
	if GF.Apply and GF.Apply.GetActiveApplicationCount then
		return tonumber(GF.Apply:GetActiveApplicationCount()) or 0, false
	end
	return 0, false
end

local function hasActiveOutgoingApplication()
	return GF.Apply and GF.Apply.HasActiveApplication and GF.Apply:HasActiveApplication()
end

local function getActiveListingTitle()
	local L = GF.L or {}
	local title
	if GF.Listing and GF.Listing.GetActive then
		local ok, info = pcall(GF.Listing.GetActive, GF.Listing)
		if ok and info then
			title = info.name
		end
	end
	if type(title) ~= "string" or title == "" then
		title = L.CREATE_LISTING or "Group"
	end
	return title
end

local function canManageActiveListing()
	return GF.Listing and GF.Listing.CanManageEntry and GF.Listing:CanManageEntry()
end

local function isPremadeRestricted()
	if GF.Availability and GF.Availability.IsRestricted then
		local ok, restricted = pcall(GF.Availability.IsRestricted, GF.Availability)
		return ok and restricted == true
	end
	return false
end

local function updateRestrictedVisualState()
	if not btn then
		return false
	end
	local restricted = isPremadeRestricted()
	btn:SetAlpha(restricted and FLOAT_RESTRICTED_ALPHA or 1)
	if restricted then
		GameTooltip_Hide()
	end
	return restricted
end

local function getGroupCount()
	local count = 0
	if GF.FindGroupTab and GF.FindGroupTab.GetDisplayedResultCount then
		local ok, value = pcall(GF.FindGroupTab.GetDisplayedResultCount, GF.FindGroupTab)
		if ok then
			count = tonumber(value) or 0
		end
	end
	if count <= 0 and GF.Result then
		count = tonumber(GF.Result.total) or 0
	end
	return math.max(0, count)
end

function GF.GetLauncherStatusCounts()
	local applicantCount, activeListing = getApplicantStatusCount()
	local L = GF.L or {}
	local applicantUnit = activeListing and (L.FLOAT_APPLICANTS_UNIT or "人") or (L.FLOAT_APPLICATION_GROUPS_UNIT or "队")
	return applicantCount, getGroupCount(), activeListing, applicantUnit
end

local function refreshTitanPanel()
	if GF.TitanPanel and GF.TitanPanel.UpdateButton then
		GF.TitanPanel:UpdateButton()
	end
end

local function formatCount(count)
	count = tonumber(count) or 0
	if count > 999 then
		return "999+"
	end
	return tostring(count)
end

local function formatTooltipIcon(frameKey)
	local coords = TEAMUP_FRAMES[frameKey]
	if not coords then
		return ""
	end
	return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(
		TEAMUP_TEX,
		TOOLTIP_ICON_SIZE,
		TOOLTIP_ICON_SIZE,
		TEAMUP_IMAGE_W,
		TEAMUP_FRAME_H,
		math.floor(coords[1] + 0.5),
		math.floor(coords[2] + 0.5),
		math.floor(coords[3] + 0.5),
		math.floor(coords[4] + 0.5)
	)
end

local function formatTooltipLeft(frameKey, label)
	return string.format("%s  %s：", formatTooltipIcon(frameKey), label or "")
end

local function formatTooltipRight(count, unit)
	return string.format("%s %s", formatCount(count), unit or "")
end

local function beginFloatingTooltip(owner)
	if not (owner and GameTooltip) then
		return false
	end
	GameTooltip:SetOwner(owner, "ANCHOR_NONE")
	if GameTooltip.ClearAllPoints then
		GameTooltip:ClearAllPoints()
	end
	GameTooltip:SetPoint("TOP", owner, "BOTTOM", 0, FLOAT_TOOLTIP_OFFSET_Y)
	if GF.Font and GF.Font.BeginTooltipFont then
		GF.Font.BeginTooltipFont(GameTooltip)
	end
	return true
end

local function setFloatingAtlasFrame(texture, cellIndex)
	if not texture then
		return
	end
	cellIndex = math.max(0, math.min(cellIndex or 0, (FRAME_ATLAS_COLS * FRAME_ATLAS_ROWS) - 1))
	local col = cellIndex % FRAME_ATLAS_COLS
	local row = math.floor(cellIndex / FRAME_ATLAS_COLS)
	if not texture._gfFloatingAtlasTextureSet then
		texture:SetTexture(FRAME_TEX)
		texture._gfFloatingAtlasTextureSet = true
	end
	texture:SetTexCoord(
		((col * FRAME_ATLAS_CELL_W) / FRAME_ATLAS_IMAGE_W) + FRAME_ATLAS_TEXEL_U,
		(((col + 1) * FRAME_ATLAS_CELL_W) / FRAME_ATLAS_IMAGE_W) - FRAME_ATLAS_TEXEL_U,
		((row * FRAME_ATLAS_CELL_H) / FRAME_ATLAS_IMAGE_H) + FRAME_ATLAS_TEXEL_V,
		(((row + 1) * FRAME_ATLAS_CELL_H) / FRAME_ATLAS_IMAGE_H) - FRAME_ATLAS_TEXEL_V
	)
end

local function setChromeFrame(cellIndex)
	setFloatingAtlasFrame(frameTexture, cellIndex)
end

local function stopChromeAnimation()
	if animationTicker then
		animationTicker:Hide()
	end
	animationFrames = nil
	animationFramePos = 1
	animationElapsed = 0
	animationLoop = false
end

local function setChromeState(state)
	state = state or "idle"
	stopChromeAnimation()
	chromeState = state
	if state == "expanded" then
		setChromeFrame(FRAME_EXPANDED_CELL)
	elseif state == "flash" then
		setChromeFrame(FLASH_FRAMES[1])
	else
		chromeState = "idle"
		setChromeFrame(FRAME_STATIC_CELL)
	end
end

local function closeFloatingContextMenu()
	if CloseDropDownMenus then
		CloseDropDownMenus()
	end
	if CloseMenus then
		CloseMenus()
	end
end

local function showActiveListingContextMenu()
	if not (GF.RowContextMenu and GF.RowContextMenu.ShowMenu) then
		return false
	end
	local L = GF.L or {}
	if GF.ApplyFrameStrata then
		GF.ApplyFrameStrata()
	end
	local menuItems = {
		{
			isTitle = true,
			text = getActiveListingTitle(),
		},
		{
			text = L.VIEW_LISTING or "View Group",
			func = function()
				closeFloatingContextMenu()
				if GF.MainFrame and GF.MainFrame.OpenCreateTab then
					GF.MainFrame:OpenCreateTab()
				end
			end,
		},
		{
			text = L.REMOVE_LISTING or "Delist",
			disabled = not canManageActiveListing(),
			func = function()
				closeFloatingContextMenu()
				if GF.Listing and GF.Listing.Remove then
					GF.Listing:Remove()
				end
			end,
		},
	}
	closeFloatingContextMenu()
	GameTooltip_Hide()
	GF.RowContextMenu:ShowMenu(menuItems, {
		anchorFrame = btn,
		point = "TOP",
		relativePoint = "BOTTOM",
		relativeTo = btn,
		xOffset = 0,
		yOffset = FLOAT_CTX_ANCHOR_GAP_Y,
		minWidth = FLOAT_CTX_MENU_MIN_W,
	})
	return true
end

local function onAnimationComplete(targetState)
	if targetState == "expanded" then
		setChromeState("expanded")
	elseif targetState == "flash" then
		setChromeState("flash")
	else
		setChromeState("idle")
	end
end

local function onChromeAnimationUpdate(_, elapsed)
	if not frameTexture or not animationFrames then
		return
	end
	animationElapsed = (animationElapsed or 0) + (elapsed or 0)
	local frameDuration = animationFrameDuration or LEGACY_SEQUENCE_FRAME_DURATION
	while animationElapsed >= frameDuration do
		animationElapsed = animationElapsed - frameDuration
		animationFramePos = animationFramePos + 1
		if animationFramePos > #animationFrames then
			if animationLoop then
				animationFramePos = 1
			else
				local targetState = frameTexture._gfFloatingTargetState
				onAnimationComplete(targetState)
				return
			end
		end
		setChromeFrame(animationFrames[animationFramePos])
	end
end

local function playChromeAnimation(frames, targetState, loop, frameDuration)
	if not (frameTexture and animationTicker and frames and frames[1]) then
		return
	end
	animationFrames = frames
	animationFramePos = 1
	animationElapsed = 0
	animationLoop = loop == true
	animationFrameDuration = frameDuration or LEGACY_SEQUENCE_FRAME_DURATION
	frameTexture._gfFloatingTargetState = targetState
	chromeState = targetState or chromeState
	setChromeFrame(frames[1])
	animationTicker:Show()
end

local function transitionChromeTo(targetState)
	targetState = targetState or "idle"
	if targetState == "flash" then
		if chromeState ~= "flash" then
			playChromeAnimation(FLASH_FRAMES, "flash", true, FLASH_FRAME_DURATION)
		end
	elseif targetState == "expanded" then
		if chromeState == "idle" then
			playChromeAnimation(EXPAND_FRAMES, "expanded", false, EXPAND_FRAME_DURATION)
		elseif chromeState ~= "expanded" then
			setChromeState("expanded")
		end
	else
		if chromeState == "expanded" or chromeState == "flash" then
			playChromeAnimation(COLLAPSE_FRAMES, "idle", false, COLLAPSE_FRAME_DURATION)
		elseif chromeState ~= "idle" then
			setChromeState("idle")
		end
	end
end

local function stopFloatingEyeAnimation()
	if not floatingEye then
		return
	end
	if floatingEye.StopAnimating then
		pcall(floatingEye.StopAnimating, floatingEye)
	end
	if floatingEye.texture then
		floatingEye.texture:Hide()
	end
	floatingEye._gfFloatingEyeLooping = nil
end

local function startFloatingEyeAnimation()
	if not floatingEye then
		return false
	end
	if floatingEye.texture then
		floatingEye.texture:Hide()
	end
	if floatingEye.StartSearchingAnimation then
		local ok = pcall(floatingEye.StartSearchingAnimation, floatingEye)
		if ok then
			floatingEye._gfFloatingEyeLooping = true
			return true
		end
	end
	if floatingEye.StartFoundAnimationLoop then
		local ok = pcall(floatingEye.StartFoundAnimationLoop, floatingEye)
		if ok then
			floatingEye._gfFloatingEyeLooping = true
			return true
		end
	end
	return false
end

local function setFloatingLogoActive(active)
	active = active == true
	if active and floatingEye then
		if icon then
			icon:Hide()
		end
		floatingEye:SetAlpha(1)
		floatingEye:SetScale(FLOATING_EYE_SCALE)
		floatingEye:Show()
		if floatingEye._gfFloatingEyeLooping or startFloatingEyeAnimation() then
			return
		end
	end
	if floatingEye then
		stopFloatingEyeAnimation()
		floatingEye:Hide()
	end
	if icon then
		icon:Show()
	end
end

local function setStatusTextShown(text, shown, count)
	if text then
		text:SetShown(shown)
		if shown then
			text:SetText(formatCount(count))
		end
	end
end

local function layoutStatusItems(showApplicants, showGroups)
	if not statusHost then
		return 0
	end
	if showApplicants and applicantText then
		local textWidth = getTextWidth(applicantText, 8)
		applicantText:SetWidth(math.max(18, textWidth))
		applicantText:ClearAllPoints()
		applicantText:SetPoint("CENTER", btn, "CENTER", APPLICANT_COUNT_OFFSET_X, STATUS_CENTER_OFFSET_Y)
	end
	if showGroups and groupText then
		local textWidth = getTextWidth(groupText, 8)
		groupText:SetWidth(math.max(18, textWidth))
		groupText:ClearAllPoints()
		groupText:SetPoint("CENTER", btn, "CENTER", GROUP_COUNT_OFFSET_X, STATUS_CENTER_OFFSET_Y)
	end
	return STATUS_MAX_W
end

local function layoutContent(showIdle)
	if not contentHost then
		return
	end
	if showIdle then
		if statusHost then
			statusHost:Hide()
		end
		contentHost:SetSize(STATUS_MAX_W, FRAME_H)
		contentHost:ClearAllPoints()
		contentHost:SetPoint("CENTER", btn, "CENTER", STATUS_CENTER_OFFSET_X, 0)
		return
	end
	if statusHost then
		statusHost:Show()
	end
	local contentWidth = math.min(layoutStatusItems(true, true), STATUS_MAX_W)
	if statusHost then
		statusHost:ClearAllPoints()
		statusHost:SetPoint("LEFT", contentHost, "LEFT", 0, 0)
		statusHost:SetWidth(contentWidth)
	end
	contentHost:SetSize(math.max(1, contentWidth), FRAME_H)
	contentHost:ClearAllPoints()
	contentHost:SetPoint("CENTER", btn, "CENTER", STATUS_CENTER_OFFSET_X, 0)
end

local function showTooltip(owner)
	if isPremadeRestricted() then
		GameTooltip_Hide()
		return
	end
	if not beginFloatingTooltip(owner) then
		return
	end
	local L = GF.L or {}
	local applicantCount, activeListing = getApplicantStatusCount()
	local applicantUnit = activeListing and (L.FLOAT_APPLICANTS_UNIT or "人") or (L.FLOAT_APPLICATION_GROUPS_UNIT or "队")
	local groupCount = getGroupCount()
	GameTooltip:ClearLines()
	GameTooltip:AddLine(L.ADDON_NAME or "队伍查找器", 1, 0.82, 0, true)
	GameTooltip:AddDoubleLine(
		formatTooltipLeft("applicant", L.FLOAT_APPLICATIONS_LABEL or "申请"),
		formatTooltipRight(applicantCount, applicantUnit),
		1, 1, 1,
		1, 1, 1
	)
	GameTooltip:AddDoubleLine(
		formatTooltipLeft("group", L.FLOAT_GROUPS_LABEL or "队伍"),
		formatTooltipRight(groupCount, L.FLOAT_GROUPS_UNIT or "组"),
		1, 1, 1,
		1, 1, 1
	)
	if GF.UI and GF.UI.ShowGameTooltip then
		GF.UI.ShowGameTooltip()
	else
		GameTooltip:Show()
	end
end

function FB:RefreshAlert()
	if not btn or not btn:IsShown() then
		refreshTitanPanel()
		return
	end
	updateRestrictedVisualState()
	local applicantCount, activeListing = getApplicantStatusCount()
	local groupCount = getGroupCount()
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	local mainShown = mainFrame and mainFrame.IsShown and mainFrame:IsShown()
	local showIdle = applicantCount <= 0 and not activeListing and not mainShown
	local targetState = "idle"
	if applicantCount > 0 then
		targetState = "flash"
	elseif activeListing or mainShown then
		targetState = "expanded"
	end

	syncFloatingLayerLevels()
	transitionChromeTo(targetState)
	setFloatingLogoActive(activeListing)
	setStatusTextShown(applicantText, not showIdle, applicantCount)
	setStatusTextShown(groupText, not showIdle, groupCount)
	layoutContent(showIdle)
	if btn and GameTooltip and GameTooltip:IsOwned(btn) then
		showTooltip(btn)
	end
	refreshTitanPanel()
end

function FB:Refresh()
	self:RefreshAlert()
end

function FB:HandleClick(mouseButton)
	closeFloatingContextMenu()
	if hasActiveListing() and GF.MainFrame then
		if mouseButton == "RightButton" and showActiveListingContextMenu() then
			return
		end
		local mainFrame = GF.MainFrame.frame
		local currentTab = GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar:GetCurrent()
		if mainFrame and mainFrame:IsShown() and currentTab == GF.TAB_CREATE and GF.MainFrame.HideFrame then
			GF.MainFrame:HideFrame()
		elseif GF.MainFrame.OpenCreateTab then
			GF.MainFrame:OpenCreateTab()
		else
			GF.MainFrame:Toggle()
		end
		return
	end
	if GF.HandleMinimapClick then
		GF.HandleMinimapClick(mouseButton)
	elseif GF.MainFrame then
		GF.MainFrame:Toggle()
	end
end

function FB:Apply()
	if not btn then
		return
	end
	applyDragLock()
	if GF.GetDB().showFloatButton ~= false then
		btn:Show()
		restorePosition()
		syncFloatingLayerLevels()
		updateRestrictedVisualState()
		self:RefreshAlert()
	else
		setChromeState("idle")
		setFloatingLogoActive(false)
		btn:SetAlpha(1)
		btn:Hide()
	end
end

function FB:ApplyDragLock()
	applyDragLock()
end

function FB:GetButtonFrame()
	return btn
end

function FB:Init()
	if not btn then
		btn = CreateFrame("Button", "GroupFinderAddonFloatButton", UIParent, "BackdropTemplate")
	end
	if btn._gfFloatInited then
		return
	end
	btn._gfFloatInited = true

	btn:SetSize(FRAME_W, FRAME_H)
	btn:SetClampedToScreen(true)
	btn:SetMovable(true)
	btn:EnableMouse(true)

	backHost = CreateFrame("Frame", nil, btn)
	backHost:SetAllPoints(btn)

	icon = backHost:CreateTexture(nil, "ARTWORK")
	setFloatingAtlasFrame(icon, FRAME_STATIC_CELL)
	icon:SetSize(FRAME_BG_W, FRAME_BG_H)
	icon:SetPoint("CENTER", btn, "CENTER", 0, 0)

	chromeHost = CreateFrame("Frame", nil, btn)
	chromeHost:SetAllPoints(btn)

	frameTexture = chromeHost:CreateTexture(nil, "ARTWORK")
	setChromeFrame(FRAME_STATIC_CELL)
	frameTexture:SetSize(FRAME_BG_W, FRAME_BG_H)
	frameTexture:SetPoint("CENTER", btn, "CENTER", 0, 0)

	animationTicker = CreateFrame("Frame", nil, btn)
	animationTicker:SetAllPoints(btn)
	animationTicker:SetScript("OnUpdate", onChromeAnimationUpdate)
	animationTicker:Hide()

	contentHost = CreateFrame("Frame", nil, btn)
	contentHost:SetSize(STATUS_MAX_W, FRAME_H)
	contentHost:SetPoint("CENTER", btn, "CENTER", STATUS_CENTER_OFFSET_X, 0)

	if GF.UI and GF.UI.TryLoadQueueStatusFrameUI and GF.UI.TryLoadQueueStatusFrameUI() then
		local ok, eye = pcall(CreateFrame, "Frame", nil, backHost, "EyeTemplate")
		if ok and eye then
			floatingEye = eye
			floatingEye:SetSize(EYE_TEMPLATE_NATIVE_SIZE, EYE_TEMPLATE_NATIVE_SIZE)
			floatingEye:SetScale(FLOATING_EYE_SCALE)
			floatingEye:SetPoint("CENTER", btn, "CENTER", 0, 0)
			floatingEye:Hide()
			if floatingEye.texture then
				floatingEye.texture:Hide()
			end
		end
	end

	statusHost = CreateFrame("Frame", nil, contentHost)
	statusHost:SetPoint("LEFT", contentHost, "LEFT", 0, 0)
	statusHost:SetWidth(0)
	statusHost:SetHeight(FRAME_H)

	applicantText = GF.UI.CreateFontString(statusHost, "ARTWORK", "GameFontHighlightSmall")
	if applicantText then
		applicantText:SetTextColor(1, 1, 1)
		applicantText:SetJustifyH("CENTER")
		applicantText:SetJustifyV("MIDDLE")
	end

	groupText = GF.UI.CreateFontString(statusHost, "ARTWORK", "GameFontHighlightSmall")
	if groupText then
		groupText:SetTextColor(1, 1, 1)
		groupText:SetJustifyH("CENTER")
		groupText:SetJustifyV("MIDDLE")
	end

	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")

	btn:SetScript("OnDragStart", function(self)
		if isDragLocked() then
			return
		end
		self:StartMoving()
	end)

	btn:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if not isDragLocked() then
			savePosition()
		end
	end)

	btn:SetScript("OnClick", function(_, mouseButton)
		FB:HandleClick(mouseButton)
	end)
	btn:SetScript("OnEnter", function(self)
		showTooltip(self)
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip_Hide()
	end)

	if GF.UI.InstallSatelliteFrame then
		GF.UI.InstallSatelliteFrame(btn, { levelOffset = 8 })
	end

	if GF.ApplyFrameStrata then
		GF.ApplyFrameStrata()
	end
	syncFloatingLayerLevels()

	self:Apply()
end
