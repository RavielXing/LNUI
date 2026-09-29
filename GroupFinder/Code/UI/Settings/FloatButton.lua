local _, GF = ...

GF.FloatButton = {}
local FB = GF.FloatButton

local btn
local visualHost
local backHost
local chromeHost
local panelHost
local glowHost
local sidePanels = {}
local borderGlow
local breatheTextures = {}
local animationTicker
local motion = { progress = 0, target = 0, moving = false }
local effects = {
	breathe = { wanted = false, time = 0, alpha = 0, target = 0 },
	border = { wanted = false, time = 0, alpha = 0, target = 0 },
}
local chromeState = "idle"
local floatingContextMenuOpen = false
local floatingContextMenuToken = 0
local contentHost
local icon
local floatingEye
local statusHost
local statusFadeElapsed
local applicantText
local groupText
local restrictedFadeTicker
local restrictedFadeFromAlpha = 1
local restrictedFadeTargetAlpha = 1
local restrictedFadeElapsed = 0
local restrictedFadeRunning = false
local petBattleSuppressed = false
local messageAlert

local ART = GF.FLOATING_ART
local STYLE = GF.FLOATING_STYLE
local FRAME_W = STYLE.width
local FRAME_H = GF.FLOAT_BUTTON_HEIGHT or 40
local FRAME_BG_W = STYLE.artWidth
local FRAME_BG_H = STYLE.artHeight
local EYE_TEMPLATE_NATIVE_SIZE = 45
local FLOATING_EYE_SCALE = STYLE.eyeSize / STYLE.eyeContentSize
local STATUS_AREA_LEFT = 42
local STATUS_AREA_RIGHT = 8
local STATUS_CENTER_OFFSET_X = ((STATUS_AREA_LEFT + (FRAME_W - STATUS_AREA_RIGHT)) / 2) - (FRAME_W / 2)
local STATUS_CENTER_OFFSET_Y = 0
local STATUS_MAX_W = FRAME_W - STATUS_AREA_LEFT - STATUS_AREA_RIGHT
local APPLICANT_COUNT_OFFSET_X = STYLE.applicantOffset
local GROUP_COUNT_OFFSET_X = STYLE.groupOffset
local TOOLTIP_ICON_SIZE = 16
local TOOLTIP_MIN_WIDTH = 160
local TOOLTIP_LINE_SPACING = 6
local FLOAT_TOOLTIP_OFFSET_Y = -(GF.TOOLTIP_BUTTON_TOP_GAP or 4)
local TEAMUP_ATLASES = GF.TEAMUP_INLINE_ATLASES or {}
local FLOAT_RESTRICTED_ALPHA = 0.15
local FLOAT_RESTRICTED_FADE_DURATION = 0.18
local STATUS_FADE_DURATION = STYLE.statusDuration
local STATUS_FADE_DELAY = STYLE.statusDelay

local function getLauncherState()
	return GF.LauncherStateService
end

local function isDragLocked()
	local state = getLauncherState()
	return state and state:IsFloatDragLocked() or false
end

local function syncFloatingLayerLevels()
	if not btn then
		return
	end
	local baseLevel = btn:GetFrameLevel() or 0
	if visualHost then
		visualHost:SetFrameLevel(baseLevel + 1)
	end
	if panelHost then panelHost:SetFrameLevel(baseLevel + 2) end
	for _, side in ipairs(sidePanels) do
		side.clip:SetFrameLevel(baseLevel + 2)
		side.frame:SetFrameLevel(baseLevel + 3)
	end
	if glowHost then glowHost:SetFrameLevel(baseLevel + 4) end
	if messageAlert then messageAlert:SetFrameLevel(baseLevel + 4, baseLevel + 10, baseLevel + 2) end
	if backHost then backHost:SetFrameLevel(baseLevel + 5) end
	if floatingEye then
		floatingEye:SetFrameLevel(baseLevel + 6)
		-- EyeTemplate renders in child frames with explicit MEDIUM strata.
		-- Give them a separate level below the ring, including the fallback glow.
		for _, layer in ipairs({ floatingEye:GetChildren() }) do
			layer:SetFrameStrata(btn:GetFrameStrata())
			layer:SetFrameLevel(baseLevel + 7)
		end
	end
	if chromeHost then chromeHost:SetFrameLevel(baseLevel + 8) end
	if contentHost then contentHost:SetFrameLevel(baseLevel + 9) end
end

local function savePosition()
	local button = btn
	if not button then
		return
	end
	local point, _, relativePoint, offsetX, offsetY = button:GetPoint(1)
	if type(point) == "string" then
		local state = getLauncherState()
		if state then
			state:SetFloatPosition(
				point, relativePoint, offsetX, offsetY, "floating-button-drag")
		end
	end
end

local function applyDragLock()
	local button = btn
	if button then
		button:SetMovable(isDragLocked() ~= true)
	end
end

local function applyScale()
	local button = btn
	if not (button and button.SetScale) then
		return
	end
	local scale = GF.GetFloatScale and GF.GetFloatScale() or 1
	local currentScale = button.GetScale and button:GetScale()
	if currentScale == nil or math.abs(currentScale - scale) > 0.0001 then
		button:SetScale(scale)
	end
end

-- Delegate to the early shared helper, which is also safe for views loaded
-- before this launcher module.
function FB:GetDefaultPosition()
	return GF.UI.GetDefaultFloatingButtonPosition()
end

local function restorePosition()
	local button = btn
	if not button then
		return
	end
	local state = getLauncherState()
	local point, relativePoint, offsetX, offsetY
	if state then
		point, relativePoint, offsetX, offsetY = state:GetFloatPosition()
	end
	button:ClearAllPoints()
	if point then
		button:SetPoint(point, UIParent, relativePoint, offsetX, offsetY)
	else
		local defaultPoint, defaultRelativePoint, defaultX, defaultY = FB:GetDefaultPosition()
		button:SetPoint(defaultPoint, UIParent, defaultRelativePoint, defaultX, defaultY)
	end
end

local function refreshDefaultPositionOnNextFrame(self)
	self:SetScript("OnUpdate", nil)
	if self._gfFloatDragging then return end
	local state = getLauncherState()
	if state and state:GetFloatPosition() then return end
	-- Login and display events can precede the final UIParent geometry.
	-- Re-read it after layout, without replacing a user-saved anchor.
	restorePosition()
end

local function queueDefaultPositionRefresh(self)
	self:SetScript("OnUpdate", refreshDefaultPositionOnNextFrame)
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
	return GF.RecruitmentSession and GF.RecruitmentSession.HasActive and GF.RecruitmentSession:HasActive()
end

local function getApplicantStatusCount()
	local listed = hasActiveListing()
	if listed then
		local service = GF.ApplicantActionService
		return service and service.GetApplicantCount
			and tonumber(service:GetApplicantCount()) or 0, true
	end
	if GF.Apply and GF.Apply.GetActiveApplicationCount then
		return tonumber(GF.Apply:GetActiveApplicationCount()) or 0, false
	end
	return 0, false
end

local function getActiveListingTitle()
	local L = GF.L or {}
	local title
	if GF.RecruitmentSession and GF.RecruitmentSession.GetActive then
		local ok, info = pcall(GF.RecruitmentSession.GetActive, GF.RecruitmentSession)
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
	if GF.RecruitmentSession and GF.RecruitmentSession.IsBusy and GF.RecruitmentSession:IsBusy() then
		return false
	end
	return GF.RecruitmentSession
		and GF.RecruitmentSession.CanPublish
		and GF.RecruitmentSession:CanPublish()
end

local function isPremadeRestricted()
	if GF.Availability and GF.Availability.IsRestricted then
		local ok, restricted = pcall(GF.Availability.IsRestricted, GF.Availability)
		return ok and restricted == true
	end
	return false
end

local function stopRestrictedFade()
	if restrictedFadeTicker then
		restrictedFadeTicker:Hide()
	end
	restrictedFadeElapsed = 0
	restrictedFadeRunning = false
end

local function setRestrictedVisualAlpha(targetAlpha, immediate)
	local host = visualHost or btn
	if not host then
		return
	end
	targetAlpha = tonumber(targetAlpha) or 1
	if restrictedFadeRunning
		and math.abs(restrictedFadeTargetAlpha - targetAlpha) <= 0.001 then
		return
	end
	restrictedFadeTargetAlpha = targetAlpha

	local currentAlpha
	if type(host.GetAlpha) == "function" then
		local ok, value = pcall(host.GetAlpha, host)
		if ok then
			currentAlpha = tonumber(value)
		end
	end
	currentAlpha = currentAlpha or restrictedFadeFromAlpha or 1

	if immediate == true or not restrictedFadeTicker
		or math.abs(currentAlpha - targetAlpha) <= 0.001 then
		stopRestrictedFade()
		restrictedFadeFromAlpha = targetAlpha
		host:SetAlpha(targetAlpha)
		return
	end

	restrictedFadeFromAlpha = currentAlpha
	restrictedFadeElapsed = 0
	restrictedFadeRunning = true
	restrictedFadeTicker:Show()
end

local function onRestrictedFadeUpdate(_, elapsed)
	local host = visualHost or btn
	if not host then
		stopRestrictedFade()
		return
	end
	restrictedFadeElapsed = restrictedFadeElapsed + (tonumber(elapsed) or 0)
	local progress = math.min(1,
		restrictedFadeElapsed / FLOAT_RESTRICTED_FADE_DURATION)
	-- Smoothstep keeps the short transition readable without a hard alpha snap.
	local eased = progress * progress * (3 - (2 * progress))
	local alpha = restrictedFadeFromAlpha
		+ ((restrictedFadeTargetAlpha - restrictedFadeFromAlpha) * eased)
	host:SetAlpha(alpha)
	if progress >= 1 then
		host:SetAlpha(restrictedFadeTargetAlpha)
		restrictedFadeFromAlpha = restrictedFadeTargetAlpha
		stopRestrictedFade()
	end
end

local function updateRestrictedVisualState(snapshot, immediate)
	if not btn then
		return false
	end
	local restricted
	if type(snapshot) == "table" and type(snapshot.restricted) == "boolean" then
		restricted = snapshot.restricted
	else
		restricted = isPremadeRestricted()
	end
	setRestrictedVisualAlpha(
		restricted and FLOAT_RESTRICTED_ALPHA or 1,
		immediate)
	if restricted then
		if type(GameTooltip_Hide) == "function" then
			GameTooltip_Hide()
		end
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
	local atlas = TEAMUP_ATLASES[frameKey]
	if not atlas then
		return ""
	end
	return CreateAtlasMarkup(atlas, TOOLTIP_ICON_SIZE, TOOLTIP_ICON_SIZE)
end

local function formatTooltipLeft(frameKey, label)
	local markup = formatTooltipIcon(frameKey)
	return markup ~= "" and string.format("%s  %s", markup, label or "") or (label or "")
end

local function formatTooltipRight(count, unit)
	return string.format("%s |cff9d9d9d%s|r", formatCount(count), unit or "")
end

local function resetFloatingTooltipLayout(tooltip)
	if not tooltip._gfFloatingTooltipLayout then
		return
	end
	tooltip._gfFloatingTooltipLayout = nil
	if tooltip.SetMinimumWidth then
		tooltip:SetMinimumWidth(0)
	end
	if tooltip.SetCustomLineSpacing then
		tooltip:SetCustomLineSpacing(0)
	end
end

local function applyFloatingTooltipLayout(tooltip)
	-- GameTooltip is shared: release only this launcher's layout on clear/hide.
	if not tooltip._gfFloatingTooltipLayoutHooks and tooltip.HookScript then
		tooltip._gfFloatingTooltipLayoutHooks = true
		tooltip:HookScript("OnTooltipCleared", resetFloatingTooltipLayout)
		tooltip:HookScript("OnHide", resetFloatingTooltipLayout)
	end
	tooltip._gfFloatingTooltipLayout = true
	if tooltip.SetMinimumWidth then
		tooltip:SetMinimumWidth(TOOLTIP_MIN_WIDTH)
	end
	if tooltip.SetCustomLineSpacing then
		tooltip:SetCustomLineSpacing(TOOLTIP_LINE_SPACING)
	end
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

local function setEffectFrame(texture, atlas, index, mirrored)
	if texture._gfFloatingEffectFrame == index then return end
	texture._gfFloatingEffectFrame = index
	local x = (index % atlas.columns) * (atlas.cellWidth + 2 * atlas.padding) + atlas.padding
	local y = math.floor(index / atlas.columns) * (atlas.cellHeight + 2 * atlas.padding) + atlas.padding
	local left, right = (x + 0.5) / atlas.width, (x + atlas.cellWidth - 0.5) / atlas.width
	if mirrored then left, right = right, left end
	texture:SetTexCoord(left, right, (y + 0.5) / atlas.height, (y + atlas.cellHeight - 0.5) / atlas.height)
end

local function renderExpansion()
	if messageAlert then messageAlert:SetExpansion(motion.progress) end
	for _, side in ipairs(sidePanels) do
		local offset = STYLE.panelWidth * (1 - motion.progress)
		if side.mirrored then
			side.frame:SetPoint("RIGHT", side.clip, "RIGHT", offset, 0)
		else
			side.frame:SetPoint("LEFT", side.clip, "LEFT", -offset, 0)
		end
		side.clip:SetShown(motion.progress > 0)
	end
end

local function hasVisibleEffects()
	return effects.breathe.alpha > 0 or effects.border.alpha > 0
end

local function setEffectTarget(effect, target)
	if effect.target == target then return end
	effect.from, effect.target, effect.elapsed = effect.alpha, target, 0
	local duration = target == 1 and STYLE.effectFadeIn or STYLE.effectFadeOut
	effect.duration = math.max(0.001, duration * math.abs(target - effect.alpha))
	effect.fading = effect.alpha ~= target
end

local function renderEffectAlpha(texture, effect, ready)
	if texture:GetAlpha() ~= effect.alpha then texture:SetAlpha(effect.alpha) end
	texture:SetShown(effect.alpha > 0 or (effect.wanted and ready))
end

local function renderEffects()
	local ready = motion.progress >= 1 and motion.target == 1 and chromeState ~= "idle"
	for _, effect in pairs(effects) do
		setEffectTarget(effect, effect.wanted and ready and 1 or 0)
	end
	local breathe = effects.breathe
	if breathe.alpha > 0 or (breathe.wanted and ready) then
		local last = ART.breathe.frames - 1
		local step = math.floor(breathe.time / ART.breathe.duration * (2 * last)) % (2 * last)
		local index = step <= last and step or 2 * last - step
		for i, texture in ipairs(breatheTextures) do
			setEffectFrame(texture, ART.breathe, index, i == 1)
		end
	end
	for _, texture in ipairs(breatheTextures) do renderEffectAlpha(texture, breathe, ready) end
	if borderGlow then
		local border = effects.border
		if border.alpha > 0 or (border.wanted and ready) then
			local index = math.floor(border.time / ART.border.duration * ART.border.frames) % ART.border.frames
			setEffectFrame(borderGlow, ART.border, index, false)
		end
		renderEffectAlpha(borderGlow, border, ready)
	end
end

local function updateAnimationDriver()
	if not animationTicker then return end
	local waitingForNumbers = chromeState ~= "idle" and motion.target == 1
		and (motion.openedElapsed or 0) < STATUS_FADE_DELAY
	animationTicker:SetShown(motion.moving or waitingForNumbers or hasVisibleEffects()
		or effects.breathe.wanted or effects.border.wanted)
end

local function setAlertEffects(breathe, border, immediate)
	effects.breathe.wanted, effects.border.wanted = breathe, border
	if immediate then
		for _, effect in pairs(effects) do
			effect.alpha, effect.target, effect.time, effect.fading = 0, 0, 0, false
		end
	end
	renderEffects()
	updateAnimationDriver()
end

local function advanceEffects(elapsed, wasExpanded)
	for kind, effect in pairs(effects) do
		if effect.alpha > 0 or (effect.wanted and wasExpanded) then
			effect.time = (effect.time + elapsed) % ART[kind].duration
		end
		if effect.fading then
			effect.elapsed = effect.elapsed + elapsed
			local progress = math.min(1, effect.elapsed / effect.duration)
			local eased = progress * progress * (3 - 2 * progress)
			effect.alpha = effect.from + (effect.target - effect.from) * eased
			if progress >= 1 then effect.alpha, effect.fading = effect.target, false end
		end
		-- Keep the loop phase until the last visible fade-out frame is gone.
		if not effect.wanted and effect.alpha == 0 then effect.time = 0 end
	end
end

local function resetStatusFade()
	statusFadeElapsed = nil
	if statusHost then
		statusHost:SetScript("OnUpdate", nil)
		statusHost:SetAlpha(0)
	end
end

local function onStatusFadeUpdate(_, elapsed)
	statusFadeElapsed = statusFadeElapsed + elapsed
	local progress = math.min(1, statusFadeElapsed / STATUS_FADE_DURATION)
	statusHost:SetAlpha(progress * progress * (3 - 2 * progress))
	if progress >= 1 then
		statusFadeElapsed = nil
		statusHost:SetScript("OnUpdate", nil)
	end
end

local function startStatusFade()
	if not statusHost or not statusHost:IsShown() or chromeState == "idle"
		or (motion.openedElapsed or 0) < STATUS_FADE_DELAY or statusFadeElapsed
		or statusHost:GetAlpha() >= 1 then
		return
	end
	statusFadeElapsed = 0
	statusHost:SetScript("OnUpdate", onStatusFadeUpdate)
end

local function resetChrome()
	if messageAlert then messageAlert:SetEnabled(false) end
	chromeState = "idle"
	motion.progress, motion.target, motion.moving, motion.openedElapsed = 0, 0, false, nil
	resetStatusFade()
	renderExpansion()
	setAlertEffects(false, false, true)
end

local function closeFloatingContextMenu()
	if CloseDropDownMenus then
		CloseDropDownMenus()
	end
	if CloseMenus then
		CloseMenus()
	end
end

local function dismissFloatingTransientUI()
	if floatingContextMenuOpen then
		floatingContextMenuToken = floatingContextMenuToken + 1
		floatingContextMenuOpen = false
		closeFloatingContextMenu()
	end
	if btn and GameTooltip then
		local owned = false
		if type(GameTooltip.IsOwned) == "function" then
			local ok, value = pcall(GameTooltip.IsOwned, GameTooltip, btn)
			owned = ok and value == true
		elseif type(GameTooltip.GetOwner) == "function" then
			local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
			owned = ok and owner == btn
		end
		if owned and type(GameTooltip_Hide) == "function" then
			GameTooltip_Hide()
		end
	end
end

local function finishFloatingContextMenu(token)
	if token ~= floatingContextMenuToken then
		return
	end
	floatingContextMenuOpen = false
end

local function createAnchoredFloatingContextMenu(generator)
	if not (MenuUtil and type(MenuUtil.CreateRootMenuDescription) == "function")
		or not (MenuVariants and type(MenuVariants.GetDefaultContextMenuMixin) == "function")
		or not (AnchorUtil and type(AnchorUtil.CreateAnchor) == "function")
		or not (Menu and type(Menu.GetManager) == "function")
	then
		return nil
	end
	local getMenuMixin = MenuVariants.GetDefaultContextMenuMixin
	local menuMixin = securecallfunction and securecallfunction(getMenuMixin)
		or getMenuMixin()
	if not menuMixin then
		return nil
	end
	local rootDescription = MenuUtil.CreateRootMenuDescription(menuMixin)
	if not rootDescription then
		return nil
	end
	if type(Menu.PopulateDescription) == "function" then
		Menu.PopulateDescription(generator, btn, rootDescription)
	else
		generator(btn, rootDescription)
	end
	local motionRegistered = GF.UI and GF.UI.InstallMenuOpenAnimation
		and GF.UI.InstallMenuOpenAnimation(
			rootDescription,
			{ preset = "menu", groupFinderOwned = true })
	local anchor = AnchorUtil.CreateAnchor("TOP", btn, "BOTTOM", 0, 0)
	local manager = Menu.GetManager()
	if not (manager and type(manager.OpenMenu) == "function") then
		return nil
	end
	local menu = manager:OpenMenu(btn, rootDescription, anchor)
	if menu and not motionRegistered
		and GF.UI and GF.UI.PlayPopupOpenAnimation
	then
		GF.UI.PlayPopupOpenAnimation(
			menu,
			{ preset = "menu", groupFinderOwned = true })
	end
	if menu and PlaySound and SOUNDKIT then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
	return menu
end

local function showActiveListingContextMenu()
	local L = GF.L or {}
	if GF.ApplyFrameStrata then
		GF.ApplyFrameStrata()
	end
	closeFloatingContextMenu()
	GameTooltip_Hide()
	floatingContextMenuToken = floatingContextMenuToken + 1
	local menuToken = floatingContextMenuToken
	floatingContextMenuOpen = true
	local releaseRegistered = false
	local menu = createAnchoredFloatingContextMenu(function(_, rootDescription)
		if type(rootDescription.AddMenuReleasedCallback) == "function" then
			releaseRegistered = true
			rootDescription:AddMenuReleasedCallback(function()
				finishFloatingContextMenu(menuToken)
			end)
		end
		rootDescription:CreateTitle(getActiveListingTitle())
		if GF.RowContextMenu and GF.RowContextMenu.CreateTitleDivider then
			GF.RowContextMenu:CreateTitleDivider(rootDescription)
		elseif type(rootDescription.CreateDivider) == "function" then
			rootDescription:CreateDivider()
		end

		rootDescription:CreateButton(
			LFG_LIST_VIEW_GROUP or L.VIEW_LISTING or "View Group",
			function()
				closeFloatingContextMenu()
				if GF.MainFrame and GF.MainFrame.OpenCreateTab then
					GF.MainFrame:OpenCreateTab()
				end
			end)

		local unlistButton = rootDescription:CreateButton(
			UNLIST_MY_GROUP or L.REMOVE_LISTING or "Delist",
			function()
				closeFloatingContextMenu()
				if GF.RecruitmentSession and GF.RecruitmentSession.Remove then
					GF.RecruitmentSession:Remove()
				end
			end)
		if unlistButton and type(unlistButton.SetEnabled) == "function" then
			unlistButton:SetEnabled(canManageActiveListing())
		end
	end)
	if not menu then
		finishFloatingContextMenu(menuToken)
		return false
	end
	if not releaseRegistered then
		finishFloatingContextMenu(menuToken)
	end
	return true
end

local function moveChromeTo(target)
	if motion.target == target then return end
	motion.from, motion.target, motion.elapsed = motion.progress, target, 0
	local duration = target == 1 and STYLE.expandDuration or STYLE.collapseDuration
	motion.duration = math.max(0.001, duration * math.abs(target - motion.progress))
	motion.moving = motion.progress ~= target
	motion.openedElapsed = target == 1 and 0 or nil
	resetStatusFade()
end

local function onChromeAnimationUpdate(_, elapsed)
	elapsed = math.max(0, tonumber(elapsed) or 0)
	local wasExpanded = motion.progress >= 1 and motion.target == 1
	local closeWait
	if chromeState == "idle" and motion.target == 1 then
		closeWait = 0
		for _, effect in pairs(effects) do
			if effect.fading then
				closeWait = math.max(closeWait, effect.duration - effect.elapsed)
			end
		end
	end
	advanceEffects(elapsed, wasExpanded)
	local slideElapsed = elapsed
	if closeWait then
		if hasVisibleEffects() then
			slideElapsed = 0
		else
			moveChromeTo(0)
			-- A slow frame can finish both stages without replaying missed UVs.
			slideElapsed = math.max(0, elapsed - closeWait)
		end
	end
	if chromeState ~= "idle" and motion.target == 1 then
		motion.openedElapsed = math.min(STATUS_FADE_DELAY, (motion.openedElapsed or 0) + elapsed)
	end
	if motion.moving then
		motion.elapsed = motion.elapsed + slideElapsed
		local progress = math.min(1, motion.elapsed / motion.duration)
		local eased = progress * progress * (3 - 2 * progress)
		motion.progress = motion.from + (motion.target - motion.from) * eased
		if progress >= 1 then motion.progress, motion.moving = motion.target, false end
		renderExpansion()
	end
	renderEffects()
	startStatusFade()
	updateAnimationDriver()
end

local function transitionChromeTo(targetState)
	local target = targetState == "idle" and 0 or 1
	if chromeState ~= targetState then
		-- A pending fade-out can keep the panel physically open. Reopening it
		-- still starts a fresh number reveal, just like reversing a real slide.
		motion.openedElapsed = target == 1 and 0 or nil
		resetStatusFade()
	end
	chromeState = target == 1 and "expanded" or "idle"
	-- Fixed-shape light atlases fade on the open panel before it slides away.
	if target == 1 or not hasVisibleEffects() then moveChromeTo(target) end
	renderEffects()
	updateAnimationDriver()
end

local function fitFloatingEyeLayer(layer, texture)
	if not (layer and texture) then return end
	-- The native flipbook's eye is above its canvas center. Move the artwork,
	-- keeping the circular aperture centered on the same host as our gold ring.
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", floatingEye, "CENTER", 0, STYLE.eyeContentOffsetY)
	local mask = layer:CreateMaskTexture()
	mask:SetTexture(ART.eyeMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetSize(STYLE.eyeContentSize, STYLE.eyeContentSize)
	mask:SetPoint("CENTER", floatingEye, "CENTER", 0, 0)
	texture:AddMaskTexture(mask)
	layer._gfFloatingEyeMask = mask
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

local function hasActiveRaidSeeking()
	local service = GF.RaidSeekingService
	return service and service.GetMyActivity and service:GetMyActivity() ~= nil or false
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
		resetStatusFade()
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
	startStatusFade()
end

local function showTooltip(owner)
	if floatingContextMenuOpen or isPremadeRestricted() then
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
	applyFloatingTooltipLayout(GameTooltip)
	GameTooltip:AddLine(L.ADDON_NAME or "魔兽集合石", 1, 0.82, 0, true)
	GameTooltip:AddDoubleLine(
		formatTooltipLeft("applicant", L.FLOAT_APPLICATIONS_LABEL or "申请"),
		formatTooltipRight(applicantCount, applicantUnit),
		0.78, 0.78, 0.78,
		1, applicantCount > 0 and 0.82 or 1, applicantCount > 0 and 0 or 1
	)
	GameTooltip:AddDoubleLine(
		formatTooltipLeft("group", L.FLOAT_GROUPS_LABEL or "队伍"),
		formatTooltipRight(groupCount, L.FLOAT_GROUPS_UNIT or "组"),
		0.78, 0.78, 0.78,
		1, 1, 1
	)
	if GF.UI and GF.UI.ShowGameTooltip then
		GF.UI.ShowGameTooltip()
	else
		GameTooltip:Show()
	end
end

local function isMainShown()
	local mainController = GF.MainFrame
	if mainController and mainController.IsUserVisible then return mainController:IsUserVisible() == true end
	return mainController and mainController.frame and mainController.frame:IsShown() or false
end

local function viewedMessageKey()
	if not isMainShown() then return nil end
	local view = GF.RaidSeekingPanel and GF.RaidSeekingPanel.chat
	if view and view.IsViewingConversation and view:IsViewingConversation(view.selectedKey) then return view.selectedKey end
end

local function refreshMessageUnread()
	if not messageAlert then return end
	local chat, viewed = GF.RaidSeekingChatService, viewedMessageKey()
	messageAlert:SetExpansion(motion.progress)
	messageAlert:SetUnread(chat and chat.HasUnread and
		(chat:HasUnread("seeking", viewed) or chat:HasUnread("board", viewed)) or false)
end

function FB:RefreshAlert(snapshot)
	if not btn then
		refreshTitanPanel()
		return
	end
	if self._runtimePolicyRestricted == true then
		syncFloatingLayerLevels()
		resetChrome()
		setFloatingLogoActive(false)
		setStatusTextShown(applicantText, false, 0)
		setStatusTextShown(groupText, false, 0)
		layoutContent(true)
		return
	end
	local shown = btn:IsShown()
	updateRestrictedVisualState(snapshot, not shown)
	if not shown then
		refreshTitanPanel()
		return
	end
	local applicantCount, activeListing = getApplicantStatusCount()
	local groupCount = getGroupCount()
	local mainShown = isMainShown()
	local outgoingCount = applicantCount
	if activeListing then
		outgoingCount = GF.Apply and GF.Apply.GetActiveApplicationCount
			and tonumber(GF.Apply:GetActiveApplicationCount()) or 0
	end
	local incoming = activeListing and applicantCount > 0
	local breathing = incoming or outgoingCount > 0
	local showIdle = not breathing and not activeListing and not mainShown

	syncFloatingLayerLevels()
	transitionChromeTo(showIdle and "idle" or "expanded")
	setAlertEffects(breathing, incoming)
	if messageAlert then
		refreshMessageUnread()
		messageAlert:SetEnabled(true)
	end
	setFloatingLogoActive(activeListing or hasActiveRaidSeeking())
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

local function readPetBattleActive()
	local petBattles = C_PetBattles
	local reader = petBattles and petBattles.IsInBattle
	if type(reader) ~= "function" then
		return nil
	end
	local ok, active = pcall(reader)
	if not ok or type(active) ~= "boolean" then
		return nil
	end
	return active
end

function FB:IsPetBattleSuppressed()
	return petBattleSuppressed == true
end

function FB:SetPetBattleSuppressed(suppressed)
	suppressed = suppressed == true
	if petBattleSuppressed == suppressed then
		return false
	end
	petBattleSuppressed = suppressed
	self:Apply()
	return true
end

function FB:SyncPetBattleVisibility()
	local active = readPetBattleActive()
	if type(active) ~= "boolean" then
		-- An unavailable reader must not overturn a latched event edge. The
		-- explicit PET_BATTLE_CLOSE event remains the recovery authority.
		return false
	end
	return self:SetPetBattleSuppressed(active)
end

function FB:HandleClick(mouseButton)
	closeFloatingContextMenu()
	if type(GameTooltip_Hide) == "function" then
		GameTooltip_Hide()
	end
	local lifecycle = GF.RuntimeLifecycle
	if lifecycle and type(lifecycle.RequestAccess) == "function"
		and lifecycle:RequestAccess() ~= true
	then
		return false
	end
	if mouseButton == "LeftButton" then
		local chat = GF.RaidSeekingChatService
		local unread = chat and chat.GetLatestUnread and chat:GetLatestUnread(viewedMessageKey())
		if unread then
			local main = GF.MainFrame
			-- An unread click is an open action, even when the window is already
			-- on that page. A blocked open must never fall through to a toggle.
			return main and main.OpenRaidConversation and main:OpenRaidConversation(unread.key) or false
		end
	end
	local state = getLauncherState()
	if not state then
		return
	end
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	local mainShown
	if GF.MainFrame and GF.MainFrame.IsUserVisible then
		mainShown = GF.MainFrame:IsUserVisible()
	else
		mainShown = mainFrame and mainFrame:IsShown()
	end
	local context = {
		mainController = GF.MainFrame,
		mainFrameAvailable = GF.MainFrame ~= nil,
		mainVisible = mainShown,
		currentTab = GF.TabBar and GF.TabBar.GetCurrent
			and GF.TabBar:GetCurrent() or nil,
		activeListing = hasActiveListing(),
	}
	local intent = state:ResolveClickIntent(
		state.SURFACE_FLOAT, mouseButton, context)
	if intent == state.INTENT_ACTIVE_LISTING_MENU then
		if showActiveListingContextMenu() then
			return
		end
		intent = state:ResolveClickIntent(
			state.SURFACE_FLOAT, "LeftButton", context)
	end
	state:ExecuteClickIntent(intent, context)
end

function FB:Apply()
	if not btn then
		return
	end
	applyScale()
	applyDragLock()
	local state = getLauncherState()
	local forceVisible = self._runtimePolicyRestricted == true
	if (forceVisible or (state and state:IsFloatVisible()))
		and not petBattleSuppressed
	then
		btn:SetAlpha(1)
		btn:Show()
		restorePosition()
		syncFloatingLayerLevels()
		updateRestrictedVisualState(nil, true)
		self:RefreshAlert()
	else
		dismissFloatingTransientUI()
		resetChrome()
		setFloatingLogoActive(false)
		stopRestrictedFade()
		if visualHost then
			visualHost:SetAlpha(1)
		end
		btn:SetAlpha(1)
		btn:Hide()
	end
end

function FB:SetRuntimePolicyRestricted(restricted)
	self._runtimePolicyRestricted = restricted == true
	if btn then
		self:Apply()
	end
end

function FB:ApplyDragLock()
	applyDragLock()
end

function FB:ApplyScale()
	applyScale()
end

function FB:GetButtonFrame()
	return btn
end

local function bindLauncherState()
	if FB._launcherStateListener then
		return
	end
	local state = getLauncherState()
	if not (state and type(state.AddListener) == "function") then
		return
	end
	local function onLauncherStateChanged(_, _, surface)
		if surface == nil or surface == state.SURFACE_FLOAT then
			FB:Apply()
		end
	end
	FB._launcherStateListener = state:AddListener(onLauncherStateChanged)
end

local function bindRaidSeekingState()
	local service = GF.RaidSeekingService
	if FB._raidSeekingListener or not (service and service.AddListener) then
		return
	end
	local active = hasActiveRaidSeeking()
	FB._raidSeekingListener = function()
		local nextActive = hasActiveRaidSeeking()
		if nextActive ~= active then
			active = nextActive
			FB:RefreshAlert()
		end
	end
	service:AddListener(FB._raidSeekingListener)
end

local function bindMessageAlerts()
	local chat = GF.RaidSeekingChatService
	if FB._messageIncomingListener or not (messageAlert and chat and chat.AddIncomingListener) then return end
	FB._messageIncomingListener = function(contact)
		if (contact.context == "board" or contact.context == "seeking") and contact.key ~= viewedMessageKey() then
			messageAlert:SetExpansion(motion.progress)
			messageAlert:OnMessage()
		end
	end
	FB._messageUnreadListener = refreshMessageUnread
	chat:AddIncomingListener(FB._messageIncomingListener)
	chat:AddUnreadListener(FB._messageUnreadListener)
	FB._messageUnreadListener()
end

function FB:Init()
	self:SyncPetBattleVisibility()
	if not btn then
		btn = CreateFrame("Button", "GroupFinderAddonFloatButton", UIParent, "BackdropTemplate")
	end
	if btn._gfFloatInited then
		self:Apply()
		return
	end
	btn._gfFloatInited = true
	bindLauncherState()
	bindRaidSeekingState()

	btn:SetSize(FRAME_W, FRAME_H)
	-- Decorative halos and message markers must not expand movement bounds.
	btn:SetIgnoringChildrenForBounds(true)
	btn:SetClampedToScreen(true)
	btn:SetMovable(true)
	btn:EnableMouse(true)
	btn:RegisterEvent("PLAYER_ENTERING_WORLD")
	btn:RegisterEvent("UI_SCALE_CHANGED")
	btn:RegisterEvent("DISPLAY_SIZE_CHANGED")
	btn:SetScript("OnEvent", queueDefaultPositionRefresh)

	visualHost = CreateFrame("Frame", nil, btn)
	visualHost:SetAllPoints(btn)
	visualHost:SetAlpha(1)
	if GF.FloatMessageAlert then
		messageAlert = GF.FloatMessageAlert.New(visualHost, btn)
		self._messageAlert = messageAlert
		bindMessageAlerts()
	end

	restrictedFadeTicker = CreateFrame("Frame", nil, btn)
	restrictedFadeTicker:SetAllPoints(btn)
	restrictedFadeTicker:SetScript("OnUpdate", onRestrictedFadeUpdate)
	restrictedFadeTicker:Hide()

	panelHost = CreateFrame("Frame", nil, visualHost)
	panelHost:SetAllPoints(visualHost)
	panelHost:EnableMouse(false)
	for index = 1, 2 do
		local mirrored = index == 1
		local clip = CreateFrame("Frame", nil, panelHost)
		clip:SetSize(FRAME_BG_W / 2, FRAME_BG_H)
		clip:SetPoint(mirrored and "RIGHT" or "LEFT", btn, "CENTER", 0, 0)
		clip:SetClipsChildren(true)
		clip:EnableMouse(false)
		local panel = CreateFrame("Frame", nil, clip)
		panel:SetSize(STYLE.panelWidth, STYLE.panelHeight)
		panel:EnableMouse(false)
		local capWidth = STYLE.panelHeight / 2
		local body = panel:CreateTexture(nil, "BACKGROUND")
		body:SetTexture(ART.panel)
		body:SetSize(STYLE.panelWidth - capWidth, STYLE.panelHeight)
		body:SetPoint(mirrored and "RIGHT" or "LEFT", panel, mirrored and "RIGHT" or "LEFT", 0, 0)
		body:SetTexCoord(mirrored and STYLE.panelBodyU or 0, mirrored and 0 or STYLE.panelBodyU, 0, 1)
		local cap = panel:CreateTexture(nil, "BACKGROUND")
		cap:SetTexture(ART.panel)
		cap:SetSize(capWidth, STYLE.panelHeight)
		cap:SetPoint(mirrored and "LEFT" or "RIGHT", panel, mirrored and "LEFT" or "RIGHT", 0, 0)
		cap:SetTexCoord(mirrored and 1 or STYLE.panelBodyU, mirrored and STYLE.panelBodyU or 1, 0, 1)
		local statusIcon = panel:CreateTexture(nil, "ARTWORK")
		local atlas = TEAMUP_ATLASES[mirrored and "applicant" or "group"]
		GF.UI.SetAtlasFit(statusIcon, atlas, STYLE.statusIconSize, STYLE.statusIconSize)
		statusIcon:SetPoint("CENTER", panel, mirrored and "LEFT" or "RIGHT",
			mirrored and STYLE.statusIconInset or -STYLE.statusIconInset, 0)
		sidePanels[index] = { clip = clip, frame = panel, mirrored = mirrored }
	end

	glowHost = CreateFrame("Frame", nil, visualHost)
	glowHost:SetAllPoints(visualHost)
	glowHost:EnableMouse(false)
	for index = 1, 2 do
		local texture = glowHost:CreateTexture(nil, "ARTWORK")
		texture:SetTexture(ART.breathe.texture)
		texture:SetSize(ART.breathe.cellWidth * FRAME_BG_W / ART.border.cellWidth,
			ART.breathe.cellHeight * FRAME_BG_H / ART.border.cellHeight)
		texture:SetPoint(index == 1 and "RIGHT" or "LEFT", btn, "CENTER", 0, 0)
		texture:Hide()
		breatheTextures[index] = texture
	end

	backHost = CreateFrame("Frame", nil, visualHost)
	backHost:SetAllPoints(visualHost)
	backHost:EnableMouse(false)
	icon = backHost:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(GF.ADDON_LOGO_TEXTURE)
	icon:SetSize(STYLE.logoSize, STYLE.logoSize)
	icon:SetPoint("CENTER", btn, "CENTER", 0, 0)

	chromeHost = CreateFrame("Frame", nil, visualHost)
	chromeHost:SetAllPoints(visualHost)
	chromeHost:EnableMouse(false)
	local ring = chromeHost:CreateTexture(nil, "ARTWORK")
	ring:SetTexture(ART.ring)
	ring:SetSize(STYLE.ringWidth, STYLE.ringHeight)
	ring:SetPoint("CENTER", btn, "CENTER", 0, 0)
	borderGlow = chromeHost:CreateTexture(nil, "OVERLAY")
	borderGlow:SetTexture(ART.border.texture)
	borderGlow:SetSize(STYLE.borderWidth, STYLE.borderHeight)
	borderGlow:SetPoint("CENTER", btn, "CENTER", STYLE.borderOffsetX, STYLE.borderOffsetY)
	borderGlow:Hide()

	animationTicker = CreateFrame("Frame", nil, btn)
	animationTicker:SetAllPoints(btn)
	animationTicker:SetScript("OnUpdate", onChromeAnimationUpdate)
	animationTicker:Hide()
	renderExpansion()

	contentHost = CreateFrame("Frame", nil, visualHost)
	contentHost:SetSize(STATUS_MAX_W, FRAME_H)
	contentHost:SetPoint("CENTER", btn, "CENTER", STATUS_CENTER_OFFSET_X, 0)

	if GF.UI and GF.UI.TryLoadQueueStatusFrameUI and GF.UI.TryLoadQueueStatusFrameUI() then
		local ok, eye = pcall(CreateFrame, "Frame", nil, backHost, "EyeTemplate")
		if ok and eye then
			floatingEye = eye
			floatingEye:SetSize(EYE_TEMPLATE_NATIVE_SIZE, EYE_TEMPLATE_NATIVE_SIZE)
			floatingEye:SetScale(FLOATING_EYE_SCALE)
			floatingEye:SetPoint("CENTER", btn, "CENTER", 0, 0)
			local searching = floatingEye.EyeSearchingLoop
			fitFloatingEyeLayer(searching, searching and searching.EyeSearchingTexture)
			local found = floatingEye.EyeFoundLoop
			fitFloatingEyeLayer(found, found and found.EyeFoundLoopTexture)
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
	statusHost:SetAlpha(0)

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
		self._gfFloatDragging = true
		self:StartMoving()
	end)

	btn:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self._gfFloatDragging = nil
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
	if type(btn.HookScript) == "function" then
		btn:HookScript("OnShow", function()
			btn:SetAlpha(1)
			updateRestrictedVisualState(nil, true)
		end)
	end

	btn._gfOnSatelliteFrameLayersApplied = syncFloatingLayerLevels
	local installSatellite = GF.UI and GF.UI.InstallSatelliteFrame
	if installSatellite then
		installSatellite(btn, {
			levelOffset = 8,
			scaleWithPanel = false,
		})
	end

	local refreshStrata = GF.ApplyFrameStrata
	if refreshStrata then
		refreshStrata()
	end
	syncFloatingLayerLevels()

	self:Apply()
end
