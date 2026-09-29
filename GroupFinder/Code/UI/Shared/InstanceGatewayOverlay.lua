local _, GF = ...

-- The view owns no game-state reads.  InstanceGatewayService supplies a
-- prepared snapshot and is also the only owner of position persistence.
GF.InstanceGatewayOverlay = GF.InstanceGatewayOverlay or {}
local Overlay = GF.InstanceGatewayOverlay

local IDLE_PRESENTATION_ALPHA = 0.46
local ACTIVE_ALPHA = 1
local FADE_ALPHA_PER_SECOND = 2.2
local PRESENTATION_ALPHA_PER_SECOND = 3.4
local SELECTION_SLIDE_PER_SECOND = 12
local FADE_EPSILON = 0.01
local TITLE_HEIGHT = 24
local TITLE_GAP = 5
local RAIL_HEIGHT = 34
local RAIL_LINE_HEIGHT = 4
local BUTTON_INSET_Y = RAIL_LINE_HEIGHT
local TEXT_OPTICAL_OFFSET_Y = -1
local TOOLTIP_GAP = 4
local TOOLTIP_LINE_SPACING = 4
local BUTTON_GAP = 0
local FRAME_PADDING_X = 12
local MIN_OPTION_WIDTH = 132
local MAX_OPTION_WIDTH = 230
local RAIL_MASK_ALPHA = 0.65
local HOVER_BACKDROP_ALPHA = 0.65
local HOVER_BACKDROP_IDLE_MULTIPLIER = 0.5
local HOVER_BACKDROP_OUTSET_X = 80
local HOVER_BACKDROP_HEIGHT = 180
local HOVER_CAPTURE_OUTSET_X = 64
local HOVER_CAPTURE_OUTSET_Y = 18
local HOVER_OPTION_GLOW_ALPHA = 0.82
local CLICK_PULSE_DURATION = 0.18

local function now()
	return GetTime and GetTime() or 0
end

local function service()
	return GF.InstanceGatewayService
end

local function localText(key, fallback)
	local locale = GF.L or {}
	return locale[key] or fallback
end

local function applyFont(fontString, template, size)
	-- All overlay text keeps its own size through settings/font refreshes.
	-- Font family and outline still come from the shared typography service.
	fontString._gfFontSizeOverride = size
	fontString._gfIgnoreFontScale = true
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template or "GameFontNormal")
	end
	if size and fontString.SetFont then
		local font, _, flags = fontString:GetFont()
		if font then
			fontString:SetFont(font, size, flags)
		end
	end
end

local function createFontString(parent, layer, template)
	return GF.UI and GF.UI.CreateFontString
		and GF.UI.CreateFontString(parent, layer, template)
		or parent:CreateFontString(nil, layer, template)
end

local function safelySetColor(texture, r, g, b, a)
	if texture.SetColorTexture then
		texture:SetColorTexture(r, g, b, a)
	else
		texture:SetTexture(GF.WHITE_TEXTURE)
		texture:SetVertexColor(r, g, b, a)
	end
end

local function setAtlas(texture, atlas, fallbackR, fallbackG, fallbackB, fallbackA)
	if type(texture.SetAtlas) == "function" then
		local ok = pcall(texture.SetAtlas, texture, atlas, false)
		if ok then
			return
		end
	end
	safelySetColor(texture, fallbackR, fallbackG, fallbackB, fallbackA)
end

local function setTintedAtlas(texture, atlas, r, g, b, a)
	if not (texture and type(texture.SetAtlas) == "function") then
		return false
	end
	local ok = pcall(texture.SetAtlas, texture, atlas, false)
	if not ok then
		return false
	end
	if texture.SetVertexColor then
		texture:SetVertexColor(r, g, b, a)
	end
	-- Black shadows use normal alpha blending.  The ADD blend used by yellow
	-- option glows cannot darken the world behind the overlay.
	if texture.SetBlendMode then
		texture:SetBlendMode("BLEND")
	end
	return true
end

local function layoutHoverBackdrop(backdrop, frame, frameWidth)
	if not (backdrop and frame and backdrop.ClearAllPoints and backdrop.SetSize
		and backdrop.SetPoint)
	then
		return
	end
	-- Follow the body's width with 80px of soft shadow on either side,
	-- independently of the mouse capture bounds.
	backdrop:ClearAllPoints()
	backdrop:SetSize(frameWidth + HOVER_BACKDROP_OUTSET_X * 2, HOVER_BACKDROP_HEIGHT)
	backdrop:SetPoint("CENTER", frame, "CENTER")
end

local function configureSelectionFrame(selection)
	if not (GF.UI and GF.UI.ApplyControlCardChrome) then
		return false
	end
	-- Source cuts and display corners are separate: the shared atlas renderer
	-- keeps four 8px corners fixed and stretches only the edges and center.
	local chrome = GF.UI.ApplyControlCardChrome(selection, {
		atlas = "house-chest-list-Item-active",
		state = "highlighted",
		displayMargin = GF.CONTROL_FRAME_DISPLAY_MARGIN,
		continuousInternalUV = true,
		layer = "ARTWORK",
		subLevel = -1,
	})
	return chrome ~= nil and chrome ~= false
end

local function createSelectionFrame(parent)
	local selection = CreateFrame("Frame", nil, parent)
	selection:EnableMouse(false)
	selection.hasFrame = configureSelectionFrame(selection)
	return selection
end

function Overlay:ConfigureSelectionFrame(selection)
	return configureSelectionFrame(selection)
end

local function formatProgress(option)
	if option.progressReady == true and option.done ~= nil
		and option.total ~= nil
	then
		return string.format("(%d/%d)", option.done, option.total)
	end
	return "(—)"
end

local function formatDifficulty(option, includePlayerCount)
	local name = option and option.name or ""
	local playerCount = tonumber(option and option.playerCount)
	if includePlayerCount ~= false and playerCount and playerCount > 0 then
		return string.format(
			localText("INSTANCE_GATEWAY_DIFFICULTY_SIZE_FMT", "(%d) %s"),
			playerCount, name)
	end
	return name
end

local function formatArrivalDetail(option)
	return string.format("|cffffd100%s|r |cffffffff%s|r",
		formatDifficulty(option, false), formatProgress(option))
end

local function setRegionAlpha(region, alpha)
	if region and region.SetAlpha then
		region:SetAlpha(alpha)
	end
end

local function setButtonTextColors(button, pulse)
	pulse = math.max(0, math.min(1, tonumber(pulse) or 0))
	if button and button.difficultyText and button.difficultyText.SetTextColor then
		button.difficultyText:SetTextColor(1,
			0.82 + 0.14 * pulse,
			0.10 + 0.32 * pulse, 1)
	end
	if button and button.progressText and button.progressText.SetTextColor then
		button.progressText:SetTextColor(1, 1, 1 - 0.22 * pulse, 1)
	end
end

local function setButtonState(button, option)
	button.option = option
	button:EnableMouse(Overlay.editing ~= true)
	button.difficultyText:SetText(formatDifficulty(option))
	button.progressText:SetText(formatProgress(option))
	button:SetEnabled(option.enabled == true and Overlay.editing ~= true)
	-- A separate read-only click surface lets group members link their own
	-- progress while the underlying difficulty button remains disabled.
	if button.shareButton then
		local sharing = Overlay.editing ~= true and option.enabled ~= true
			and Overlay.snapshot and Overlay.snapshot.isRaid == true
		button.shareButton:SetShown(sharing == true)
		button.shareButton:EnableMouse(sharing == true)
	end
	setButtonTextColors(button, 0)
end

local function applyOptionHoverHighlight(button, presentationAlpha)
	local highlight = button and button.hoverHighlight
	local option = button and button.option
	if not highlight then
		return
	end
	local shouldShow = button.hovered == true and option
		and option.selected ~= true
	if shouldShow then
		local alpha = HOVER_OPTION_GLOW_ALPHA * presentationAlpha
		if option.enabled ~= true then
			alpha = alpha * 0.65
		end
		setRegionAlpha(highlight, alpha)
		if highlight.Show then
			highlight:Show()
		end
	else
		setRegionAlpha(highlight, 0)
		if highlight.Hide then
			highlight:Hide()
		end
	end
end

local function layoutButtonText(button)
	local available = math.max(32, button:GetWidth() - 18)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(button.difficultyText, available * 0.64, 11)
		GF.Font.SetFitWidth(button.progressText, available * 0.36, 11)
	end
	local difficultyWidth = button.difficultyText:GetStringWidth() or 0
	local progressWidth = button.progressText:GetStringWidth() or 0
	local gap = 8
	local totalWidth = math.min(available, difficultyWidth + gap + progressWidth)
	button.difficultyText:ClearAllPoints()
	button.progressText:ClearAllPoints()
	button.difficultyText:SetHeight(button:GetHeight())
	button.progressText:SetHeight(button:GetHeight())
	button.difficultyText:SetPoint("LEFT", button, "CENTER", -totalWidth / 2,
		TEXT_OPTICAL_OFFSET_Y)
	button.progressText:SetPoint("LEFT", button.difficultyText, "RIGHT", gap, 0)
end

local function layoutTitleButton(frame, enabled)
	if not (frame and frame.titleButton) then
		return
	end
	local titleWidth = frame.title and frame.title:GetStringWidth() or 0
	local maximum = math.max(1, (frame:GetWidth() or 1) - FRAME_PADDING_X * 2)
	frame.titleButton:SetWidth(math.max(1, math.min(maximum, titleWidth + 20)))
	frame.titleButton:EnableMouse(enabled == true)
	if enabled == true then
		frame.titleButton:Show()
	else
		frame.titleButton:Hide()
	end
end

function Overlay:HideTooltip(owner)
	owner = owner or self.tooltipOwner
	-- GameTooltip is shared with every other UI surface; background refreshes
	-- and late OnLeave events may only dismiss the tooltip this control owns.
	if owner and GameTooltip and GameTooltip.Hide and GameTooltip.IsOwned
		and GameTooltip:IsOwned(owner)
	then
		GameTooltip:Hide()
	end
	if self.tooltipOwner == owner then
		self.tooltipOwner = nil
	end
end

function Overlay:SetHovered(hovered)
	local changed = self.hovered ~= (hovered == true)
	self.hovered = hovered == true
	if self.hovered then
		self.pendingHoverLeaveAt = nil
	end
	if self.hideAfterFade then
		return
	end
	if changed and not self.editing and self.snapshot and self.snapshot.kind == "arrival"
		and service() and service().SetArrivalPaused then
		service():SetArrivalPaused(self.arrivalToken, self.hovered)
	end
	if self.editing or self.hovered
		or not (self.snapshot and self.snapshot.kind == "entrance")
	then
		self:SetPresentationTarget(ACTIVE_ALPHA)
	else
		self:SetPresentationTarget(IDLE_PRESENTATION_ALPHA)
	end
end

function Overlay:QueueHoverLeave()
	-- Parent/child mouse transitions can briefly report an OnLeave while the
	-- pointer is still moving across a difficulty button.  The physical hit
	-- test below owns the eventual decision; this only starts its grace window.
	if not self.pendingHoverLeaveAt then
		self.pendingHoverLeaveAt = now() + 0.05
	end
end

local function readMouseOver(region)
	if not (region and type(region.IsMouseOver) == "function") then
		return nil, false
	end
	local ok, isMouseOver = pcall(region.IsMouseOver, region)
	if not ok then
		return nil, true
	end
	return isMouseOver == true, false
end

local function inspectMouseRegion(region, inspected, queryFailed, anyOver, button)
	local over, failed = readMouseOver(region)
	if failed then return inspected, true, anyOver end
	if over ~= nil then
		inspected, anyOver = true, anyOver or over
		if button and button.hovered ~= over then
			button.hovered = over
			Overlay._presentationDirty = true
		end
	end
	return inspected, queryFailed, anyOver
end

function Overlay:RefreshHoverState(frame)
	if not frame then
		return
	end
	-- A parent Frame does not promise to include children in IsMouseOver().
	-- Treat the dedicated wide capture layer, title, rail and every option as
	-- one interaction region.  This separates whole-widget fading from the
	-- per-option hover events, so moving across text, gaps and buttons cannot
	-- spuriously make the rail turn transparent.
	local inspected = false
	local queryFailed = false
	local anyOver = false
	if not self.editing and self.snapshot and self.snapshot.kind == "arrival" then
		-- Only the two visible text rows pause an arrival. Its large shadow,
		-- hidden rail and root rectangle must not create an invisible hit area.
		local titleOver, titleFailed = readMouseOver(frame.titleButton)
		local detailOver, detailFailed = readMouseOver(frame.arrivalButton)
		if titleOver or detailOver then
			self:SetHovered(true)
		elseif not titleFailed and not detailFailed then
			if self.hovered then self:QueueHoverLeave() end
			if self.pendingHoverLeaveAt and now() >= self.pendingHoverLeaveAt then
				self.pendingHoverLeaveAt = nil
				self:SetHovered(false)
			end
		end
		return
	end
	inspected, queryFailed, anyOver = inspectMouseRegion(frame, inspected, queryFailed, anyOver)
	inspected, queryFailed, anyOver = inspectMouseRegion(frame.hoverCapture, inspected, queryFailed, anyOver)
	inspected, queryFailed, anyOver = inspectMouseRegion(frame.titleButton, inspected, queryFailed, anyOver)
	inspected, queryFailed, anyOver = inspectMouseRegion(frame.rail, inspected, queryFailed, anyOver)
	for _, button in ipairs(frame.buttons or {}) do
		local isShown = not button.IsShown or button:IsShown()
		if isShown then
			inspected, queryFailed, anyOver = inspectMouseRegion(button,
				inspected, queryFailed, anyOver, button)
		end
	end
	if anyOver then
		self:SetHovered(true)
		return
	end
	-- A bad native hit-test result is not evidence that the pointer departed.
	-- Keep the current visual state until a later valid check or mouse event.
	if queryFailed or not inspected then
		return
	end
	if self.hovered and not self.pendingHoverLeaveAt then
		self:QueueHoverLeave()
	end
	if self.pendingHoverLeaveAt and now() >= self.pendingHoverLeaveAt then
		self.pendingHoverLeaveAt = nil
		self:SetHovered(false)
	end
end

function Overlay:ResolveQueuedHoverLeave(frame)
	-- Retained as the small public test seam used by the F57 contract.  It now
	-- reconciles the complete interactive area instead of only the root Frame.
	self:RefreshHoverState(frame)
end

function Overlay:SetTargetAlpha(alpha)
	self.targetAlpha = alpha
	if alpha > 0 then
		self.hideAfterFade = nil
	end
end

function Overlay:SetPresentationTarget(alpha)
	if self.presentationAlpha == nil then
		self.presentationAlpha = alpha
	end
	self.targetPresentationAlpha = alpha
end

function Overlay:BeginFadeOut()
	self.hovered = false
	self.pendingHoverLeaveAt = nil
	self.targetAlpha = 0
	self.hideAfterFade = true
	if self.arrivalToken and service() and service().DismissArrival then
		service():DismissArrival(self.arrivalToken)
	end
	self.selectionX = nil
	self.selectionWidth = nil
	self.selectionTargetX = nil
	self.selectionTargetWidth = nil
	if self.frame then
		self.frame:EnableMouse(false)
		if self.frame.hoverCapture then
			self.frame.hoverCapture:SetMouseMotionEnabled(false)
		end
		if self.frame.titleButton then
			self.frame.titleButton:EnableMouse(false)
		end
		if self.frame.arrivalButton then self.frame.arrivalButton:EnableMouse(false) end
		for _, button in ipairs(self.frame.buttons or {}) do
			button:EnableMouse(false)
			if button.shareButton then button.shareButton:EnableMouse(false) end
		end
	end
	self:HideTooltip()
end

function Overlay:AdvanceFade(frame, elapsed)
	local current = frame:GetAlpha() or 0
	local target = self.targetAlpha or 0
	local step = math.max(0, elapsed or 0) * FADE_ALPHA_PER_SECOND
	if math.abs(current - target) > FADE_EPSILON then
		if current < target then
			current = math.min(target, current + step)
		else
			current = math.max(target, current - step)
		end
		frame:SetAlpha(current)
	else
		if current ~= target then frame:SetAlpha(target) end
		current = target
	end
	if self.hideAfterFade and target <= 0 and current <= FADE_EPSILON then
		self.hideAfterFade = nil
		frame:Hide()
	end
end

function Overlay:ApplyPresentation(frame, alpha)
	self._presentationDirty = nil
	alpha = math.max(0, math.min(1, alpha or IDLE_PRESENTATION_ALPHA))
	-- The instance name remains a stable orientation anchor while the idle
	-- rail yields to the scene.  The root frame alpha still fades it naturally
	-- when the whole overlay enters or leaves range.
	setRegionAlpha(frame.title, ACTIVE_ALPHA)
	setRegionAlpha(frame.arrivalDetail, ACTIVE_ALPHA)
	setRegionAlpha(frame.hint, alpha)
	setRegionAlpha(frame.topLine, alpha)
	setRegionAlpha(frame.bottomLine, alpha)
	if frame.railMask then
		setRegionAlpha(frame.railMask, RAIL_MASK_ALPHA * alpha)
	end
	local hoverProgress = math.max(0, math.min(1,
		(alpha - IDLE_PRESENTATION_ALPHA) / (1 - IDLE_PRESENTATION_ALPHA)))
	if frame.hoverBackdrop then
		-- Match Plumber's 0.65 shadow under an idle 0.5 / active 1 bar,
		-- while retaining this view's existing smooth presentation transition.
		setRegionAlpha(frame.hoverBackdrop,
			HOVER_BACKDROP_ALPHA * (HOVER_BACKDROP_IDLE_MULTIPLIER
				+ (1 - HOVER_BACKDROP_IDLE_MULTIPLIER) * hoverProgress))
	end
	if frame.selection then
		setRegionAlpha(frame.selection, ACTIVE_ALPHA)
	end
	for _, button in ipairs(frame.buttons or {}) do
		local option = button.option
		if option then
			local optionAlpha = option.selected == true and ACTIVE_ALPHA or alpha
			if option.enabled ~= true and option.selected ~= true then
				-- Keep disabled text subdued at rest, then fully readable on hover.
				optionAlpha = optionAlpha * (0.58 + 0.42 * hoverProgress)
			end
			setRegionAlpha(button.difficultyText, optionAlpha)
			setRegionAlpha(button.progressText, optionAlpha)
			applyOptionHoverHighlight(button, alpha)
		end
	end
end

function Overlay:AdvancePresentation(frame, elapsed)
	local target = self.targetPresentationAlpha
	if target == nil then
		return
	end
	local current = self.presentationAlpha
	if current == nil then
		current = target
	end
	if current == target and not self._presentationDirty then return end
	local step = math.max(0, elapsed or 0) * PRESENTATION_ALPHA_PER_SECOND
	if math.abs(current - target) > FADE_EPSILON then
		if current < target then
			current = math.min(target, current + step)
		else
			current = math.max(target, current - step)
		end
	else
		current = target
	end
	self.presentationAlpha = current
	self:ApplyPresentation(frame, current)
end

function Overlay:StartOptionClickFeedback(button)
	if not button then
		return
	end
	button.clickPulseStartedAt = now()
	if button.clickPulse then
		setRegionAlpha(button.clickPulse, 1)
		if button.clickPulse.Show then
			button.clickPulse:Show()
		end
	end
	setButtonTextColors(button, 1)
end

function Overlay:AdvanceClickFeedback(frame)
	for _, button in ipairs((frame and frame.buttons) or {}) do
		local startedAt = button.clickPulseStartedAt
		if startedAt then
			local progress = math.max(0, (now() - startedAt) / CLICK_PULSE_DURATION)
			if progress >= 1 then
				button.clickPulseStartedAt = nil
				setButtonTextColors(button, 0)
				if button.clickPulse then
					setRegionAlpha(button.clickPulse, 0)
					if button.clickPulse.Hide then
						button.clickPulse:Hide()
					end
				end
			else
				local pulse = (1 - progress) * (1 - progress)
				setButtonTextColors(button, pulse)
				if button.clickPulse then
					setRegionAlpha(button.clickPulse, pulse)
				end
			end
		end
	end
end

function Overlay:ApplySelectionPosition(frame)
	if not (frame and frame.rail and frame.selection and self.selectionX
		and self.selectionWidth)
	then
		return
	end
	if frame.selection.hasFrame == false then
		frame.selection:Hide()
		return
	end
	frame.selection:ClearAllPoints()
	-- Preserve the top edge while extending the bottom by one pixel.
	frame.selection:SetPoint("LEFT", frame.rail, "LEFT", self.selectionX, -1.5)
	frame.selection:SetSize(self.selectionWidth, RAIL_HEIGHT + 1)
	frame.selection:Show()
end

function Overlay:SetSelectionTarget(frame, x, width)
	if self.selectionX == nil or self.selectionWidth == nil then
		self.selectionX = x
		self.selectionWidth = width
	elseif self.selectionWidth ~= width then
		-- Every visible slot has one shared width, just as Plumber's selector
		-- does.  A layout rebuild (e.g. UI scale/count change) may change that
		-- width, but it must happen atomically rather than stretching the active
		-- frame while it travels across the rail.
		self.selectionWidth = width
	end
	self.selectionTargetX = x
	self.selectionTargetWidth = width
	self:ApplySelectionPosition(frame)
end

function Overlay:AdvanceSelection(frame, elapsed)
	if not (self.selectionTargetX and self.selectionTargetWidth
		and self.selectionX and self.selectionWidth)
	then
		return
	end
	if self.selectionX == self.selectionTargetX
		and self.selectionWidth == self.selectionTargetWidth then return end
	local mix = math.min(1, math.max(0, elapsed or 0)
		* SELECTION_SLIDE_PER_SECOND)
	self.selectionX = self.selectionX
		+ (self.selectionTargetX - self.selectionX) * mix
	if math.abs(self.selectionTargetX - self.selectionX) < FADE_EPSILON then
		self.selectionX = self.selectionTargetX
	end
	self.selectionWidth = self.selectionTargetWidth
	self:ApplySelectionPosition(frame)
end

function Overlay:ShowAnchoredTooltip(anchor, bottomInset)
	local tooltip = GameTooltip
	if not (tooltip and anchor and self.tooltipOwner
		and tooltip:IsOwned(self.tooltipOwner))
	then
		return
	end
	local anchorScale = anchor.GetEffectiveScale and anchor:GetEffectiveScale() or 1
	local tooltipScale = tooltip.GetEffectiveScale and tooltip:GetEffectiveScale() or 1
	local offset = TOOLTIP_GAP + (bottomInset or 0) * anchorScale / tooltipScale
	tooltip:ClearAllPoints()
	tooltip:SetPoint("TOP", anchor, "BOTTOM", 0, -offset)
	tooltip:SetClampedToScreen(true)
	tooltip:Show()

	-- Measure after Show has laid out the lines. Compare unclamped anchor
	-- coordinates so screen clamping cannot disguise a lack of space below.
	local bottom = anchor.GetBottom and anchor:GetBottom()
	local height = tooltip:GetHeight()
	local screenBottom = UIParent and UIParent:GetBottom() or 0
	local screenScale = UIParent and UIParent:GetEffectiveScale() or 1
	local frame = self.frame or anchor
	local top = frame.GetTop and frame:GetTop()
	local anchorTop = anchor.GetTop and anchor:GetTop()
	if bottom and height and top and anchorTop
		and bottom * anchorScale - (offset + height) * tooltipScale
			< screenBottom * screenScale
	then
		local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
		local aboveOffset = (top * frameScale - anchorTop * anchorScale) / tooltipScale
		tooltip:ClearAllPoints()
		tooltip:SetPoint("BOTTOM", anchor, "TOP", 0, aboveOffset + TOOLTIP_GAP)
	end
end

local function resetTooltipLineSpacing(tooltip)
	if tooltip._gfInstanceGatewayLineSpacing then
		tooltip._gfInstanceGatewayLineSpacing = nil
		tooltip:SetCustomLineSpacing(0)
	end
end

local function setTooltipLineSpacing(tooltip, spacing)
	if not tooltip.SetCustomLineSpacing then return end
	if not tooltip._gfInstanceGatewaySpacingHooks and tooltip.HookScript then
		tooltip._gfInstanceGatewaySpacingHooks = true
		tooltip:HookScript("OnTooltipCleared", resetTooltipLineSpacing)
		tooltip:HookScript("OnHide", resetTooltipLineSpacing)
	end
	tooltip._gfInstanceGatewayLineSpacing = spacing ~= 0 or nil
	tooltip:SetCustomLineSpacing(spacing)
end

function Overlay:ShowOptionTooltip(button)
	local option = button and button.option
	if self.editing or not (option and GameTooltip) then
		return
	end
	GameTooltip:SetOwner(button, "ANCHOR_NONE")
	self.tooltipOwner = button
	local bosses = option.bosses
	local hasBosses = type(bosses) == "table" and #bosses > 0
	-- Native spacing applies to the completed tooltip, not just the next line.
	-- Keep it through Show/layout, then reset when this tooltip is cleared/hidden.
	setTooltipLineSpacing(GameTooltip, hasBosses and TOOLTIP_LINE_SPACING or 0)
	local snapshot = self.snapshot or {}
	GameTooltip:AddDoubleLine(snapshot.name or "", formatDifficulty(option),
		1, 0.82, 0, 1, 0.82, 0)
	local hasShareHint = self:AddShareHint(option)
	if hasBosses or hasShareHint then
		GameTooltip:AddLine(" ")
	end
	if hasBosses then
		for _, boss in ipairs(bosses) do
			local defeated = boss.defeated
			local status, red, green, blue
			if defeated == true then
				status = BOSS_DEAD
				red, green, blue = 1, 0.125, 0.125
			elseif defeated == false then
				status = BOSS_ALIVE
				red, green, blue = 0.1, 1, 0.1
			else
				status = UNKNOWN
				red, green, blue = 0.62, 0.62, 0.62
			end
			local nameColor = defeated == true and 0.62 or 1
			GameTooltip:AddDoubleLine(boss.name or "", status,
				nameColor, nameColor, nameColor, red, green, blue)
		end
	elseif option.progressReady then
		GameTooltip:AddLine(string.format(
			localText("INSTANCE_GATEWAY_PROGRESS_FMT", "Progress: %d/%d"),
			option.done or 0, option.total or 0), 1, 1, 1)
	else
		GameTooltip:AddLine(
			localText("INSTANCE_GATEWAY_PROGRESS_PENDING", "Loading lockout data"),
			0.7, 0.7, 0.7, true)
	end
	if option.enabled ~= true and option.disabledReason == "not-group-leader" then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(localText("INSTANCE_GATEWAY_LEADER_REQUIRED",
			"The current character cannot change instance difficulty"),
			1, 0.125, 0.125, true)
	end
	self:AddSavedProgressTooltip(option)
	if snapshot.kind == "arrival" then
		self:AddArrivalActions()
		self:ShowAnchoredTooltip(self.frame or button, 0)
		return
	end
	-- The button's bottom is inset from the lower gold line.
	self:ShowAnchoredTooltip(button, BUTTON_INSET_Y)
end

local function addTitleActionLine(labelKey, labelFallback, actionKey, actionFallback)
	local label = localText(labelKey, labelFallback)
	if NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.WrapTextInColorCode then
		label = NORMAL_FONT_COLOR:WrapTextInColorCode(label)
	end
	GameTooltip:AddLine(label .. localText(actionKey, actionFallback), 1, 1, 1, true)
end

function Overlay:AddSavedProgressTooltip(option)
	local snapshot = self.snapshot or {}
	if not snapshot.isRaid or not option.legacy then return end
	GameTooltip:AddLine(" ")
	local progress = snapshot.savedProgress
	if not progress or not progress.ready or progress.legacyLockoutState == "unknown" then
		GameTooltip:AddLine(localText("INSTANCE_GATEWAY_PROGRESS_PENDING",
			"Loading lockout data"), 0.7, 0.7, 0.7, true)
		return
	end
	if progress.legacyLockoutState == "locked" then
		for _, entry in ipairs(progress.entries or {}) do
			if entry.difficultyID == progress.legacyLockedDifficultyID
				and (not entry.expiresAt or now() < entry.expiresAt) then
				if option.difficultyID == entry.difficultyID then
					GameTooltip:AddLine(string.format(localText("INSTANCE_GATEWAY_LEGACY_LOCKED_CURRENT_FMT",
						"Instance difficulty locked. Bosses defeated: |cffff2020%d|r"), entry.done),
						1, 0.82, 0, true)
					return
				end
				local difficulty = entry.name or ""
				if entry.playerCount and entry.playerCount > 0 then
					difficulty = string.format(localText("INSTANCE_GATEWAY_LOCKED_DIFFICULTY_SIZE_FMT",
						"(%d) %s"), entry.playerCount, difficulty)
				end
				difficulty = "|cffffd100" .. difficulty .. "|r"
				GameTooltip:AddLine(string.format(localText("INSTANCE_GATEWAY_LEGACY_LOCKED_FMT",
					"Instance difficulty locked to: %s"), difficulty),
					1, 0.125, 0.125, true)
				return
			end
		end
		-- The snapshot may outlive its reset deadline until the next event.
		GameTooltip:AddLine(localText("INSTANCE_GATEWAY_PROGRESS_PENDING",
			"Loading lockout data"), 0.7, 0.7, 0.7, true)
		return
	elseif progress.legacyLockoutState == "clear" then
		GameTooltip:AddLine(localText("INSTANCE_GATEWAY_LEGACY_NOTICE",
			"Defeating any boss will lock this instance to that difficulty."), 1, 0.82, 0, true)
		return
	end
	-- Retain the actual records when more than one saved difficulty has kills;
	-- never label one arbitrary difficulty as the only lock.
	local hasEntries
	for _, entry in ipairs(progress.entries or {}) do
		if not entry.expiresAt or now() < entry.expiresAt then
			if not hasEntries then
				hasEntries = true
				GameTooltip:AddLine(localText("INSTANCE_GATEWAY_SAVED_PROGRESS",
					"Current saved progress:"), 1, 0.82, 0, true)
			end
			local label = formatDifficulty(entry)
			if entry.extended then
				label = label .. localText("INSTANCE_GATEWAY_EXTENDED", " (extended)")
			end
			local count = entry.done and entry.total
				and string.format("(%d/%d)", entry.done, entry.total) or "(—)"
			GameTooltip:AddDoubleLine(label, count, 1, 1, 1, 1, 1, 1)
		end
	end
end

local function hasChatLinkModifier()
	local key = GetModifiedClick and GetModifiedClick("CHATLINK")
	return type(key) == "string" and key ~= "" and key ~= "NONE"
end

function Overlay:AddShareHint(option)
	local canShare = option and option.canShareProgress and hasChatLinkModifier()
	local progress = self.snapshot and self.snapshot.savedProgress
	if canShare and progress then
		if option.legacy and progress.legacyLockoutState == "locked"
			and option.difficultyID ~= progress.legacyLockedDifficultyID then return end
		local currentEntry
		for _, entry in ipairs(progress.entries or {}) do
			if entry.difficultyID == option.difficultyID
				and (not entry.expiresAt or now() < entry.expiresAt) then
				currentEntry = entry
			end
		end
		if not progress.ready or not currentEntry then canShare = false end
	end
	if canShare then
		GameTooltip:AddLine(localText("INSTANCE_GATEWAY_SHARE_HINT",
			"You can insert current instance progress into chat to share it"),
			0.1, 1, 0.1, true)
		return true
	end
end

function Overlay:ShareProgress(difficultyID)
	local owner = service()
	if not owner or not owner.ShareProgress then return end
	local accepted, reason = owner:ShareProgress(difficultyID)
	if accepted then return end
	local key = reason == "open-chat" and "INSTANCE_GATEWAY_SHARE_OPEN_CHAT"
		or reason == "not-ready" and "INSTANCE_GATEWAY_SHARE_PENDING"
		or "INSTANCE_GATEWAY_SHARE_UNAVAILABLE"
	local message = localText(key, "No shareable progress. Open chat and try again.")
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(message)
	end
end

function Overlay:AddArrivalActions()
	GameTooltip:AddLine(" ")
	if self.snapshot and self.snapshot.journalInstanceID then
		addTitleActionLine("INSTANCE_GATEWAY_TITLE_LEFT_CLICK", "Left-click: ",
			"INSTANCE_GATEWAY_TITLE_OPEN_GUIDE", "Open Adventure Guide")
	end
	addTitleActionLine("INSTANCE_GATEWAY_TITLE_RIGHT_CLICK", "Right-click: ",
		"INSTANCE_GATEWAY_ARRIVAL_CLOSE", "Dismiss this notice")
end

function Overlay:DismissArrival()
	self.arrivalExpiredToken = self.arrivalToken
	self:BeginFadeOut()
end

function Overlay:ShowTitleTooltip(button)
	if self.editing or not GameTooltip then
		return
	end
	if self.snapshot and self.snapshot.kind == "arrival" then
		button.option = self.snapshot.options and self.snapshot.options[1]
		self:ShowOptionTooltip(button)
		return
	end
	GameTooltip:SetOwner(button, "ANCHOR_NONE")
	self.tooltipOwner = button
	setTooltipLineSpacing(GameTooltip, TOOLTIP_LINE_SPACING)
	local snapshot = self.snapshot or {}
	GameTooltip:AddLine(snapshot.name or "", 1, 0.82, 0, true)
	for _, option in ipairs(snapshot.options or {}) do
		if option.selected then
			if self:AddShareHint(option) then GameTooltip:AddLine(" ") end
			break
		end
	end
	addTitleActionLine("INSTANCE_GATEWAY_TITLE_LEFT_CLICK", "Left-click: ",
		"INSTANCE_GATEWAY_TITLE_OPEN_GUIDE", "Open Adventure Guide")
	if snapshot.kind == "entrance" then
		addTitleActionLine("INSTANCE_GATEWAY_TITLE_RIGHT_CLICK", "Right-click: ",
			"INSTANCE_GATEWAY_TITLE_RESET", "Reset all instances")
	end
	-- The full overlay ends at the rail (or the arrival notice's detail row).
	self:ShowAnchoredTooltip(self.frame or button, 0)
end

local function playOptionClickSound()
	if GF.UI and type(GF.UI.PlayUISound) == "function" then
		GF.UI.PlayUISound("check")
		return
	end
	local sound = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
	if sound and type(PlaySound) == "function" then
		pcall(PlaySound, sound)
	end
end

local function createOptionButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(RAIL_HEIGHT - BUTTON_INSET_Y * 2)
	button:EnableMouse(true)
	-- Native disabled buttons can still show their read-only lockout tooltip.
	-- Clicks stay disabled; edit mode and fade-out separately release the mouse.
	button:SetMotionScriptsWhileDisabled(true)
	-- This native quest-log glow is deliberately limited to an unselected
	-- option.  It scales only across that option's current width and remains a
	-- hover affordance, not a second selected-state frame.
	button.hoverHighlight = button:CreateTexture(nil, "BACKGROUND", nil, 2)
	setAtlas(button.hoverHighlight, "questlog-header-glow-yellow", 1, 0.82, 0, 0)
	-- The glow has transparent pixels below its bright edge.  Align its texture
	-- bottom with the rail bottom so the visible edge meets the gold line;
	-- adding the gold line's centre offset again would lift the glow by 2px.
	button.hoverHighlight:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -2,
		-BUTTON_INSET_Y)
	button.hoverHighlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2,
		-BUTTON_INSET_Y)
	button.hoverHighlight:SetHeight(16)
	if button.hoverHighlight.SetBlendMode then
		button.hoverHighlight:SetBlendMode("ADD")
	end
	button.hoverHighlight:SetAlpha(0)
	button.hoverHighlight:Hide()
	button.clickPulse = button:CreateTexture(nil, "ARTWORK", nil, -2)
	setAtlas(button.clickPulse, "questlog-header-glow-yellow", 1, 0.9, 0.25, 0)
	button.clickPulse:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -2,
		-BUTTON_INSET_Y)
	button.clickPulse:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2,
		-BUTTON_INSET_Y)
	button.clickPulse:SetHeight(16)
	if button.clickPulse.SetBlendMode then
		button.clickPulse:SetBlendMode("ADD")
	end
	button.clickPulse:SetAlpha(0)
	button.clickPulse:Hide()
	local difficultyFontSize = GF.INSTANCE_GATEWAY_DIFFICULTY_FONT_SIZE or 14
	button.difficultyText = createFontString(button, "OVERLAY", "GameFontNormal")
	button.difficultyText:SetJustifyH("LEFT")
	if button.difficultyText.SetJustifyV then
		button.difficultyText:SetJustifyV("MIDDLE")
	end
	applyFont(button.difficultyText, "GameFontNormal", difficultyFontSize)
	button.progressText = createFontString(button, "OVERLAY", "GameFontNormal")
	button.progressText:SetJustifyH("LEFT")
	if button.progressText.SetJustifyV then
		button.progressText:SetJustifyV("MIDDLE")
	end
	applyFont(button.progressText, "GameFontNormal", difficultyFontSize)
	button:SetScript("OnEnter", function(self)
		if Overlay.editing then
			return
		end
		self.hovered = true
		Overlay._presentationDirty = true
		Overlay:SetHovered(true)
		Overlay:ShowOptionTooltip(self)
	end)
	button:SetScript("OnLeave", function(self)
		self.hovered = false
		Overlay._presentationDirty = true
		-- Leaving one option can still leave the cursor inside the shared rail.
		-- Resolve the complete root/rail/button hit set after a short grace
		-- interval rather than trusting parent/child event ordering.
		Overlay:QueueHoverLeave()
		Overlay:HideTooltip(self)
	end)
	button:SetScript("OnClick", function(self, mouseButton)
		if Overlay.editing or Overlay.hideAfterFade then
			return
		end
		local option = self.option
		if not option or (mouseButton ~= nil and mouseButton ~= "LeftButton") then return end
		if (mouseButton == nil or mouseButton == "LeftButton")
			and IsModifiedClick and IsModifiedClick("CHATLINK") then
			Overlay:ShareProgress(option and option.difficultyID)
			return
		end
		if option and option.enabled and option.selected ~= true and service() then
			-- This remains inside the physical button click stack.  The service
			-- never invokes the protected difficulty setters from a callback.
			local accepted = service():SelectDifficulty(option.difficultyID)
			if accepted == true then
				-- The pulse/sound acknowledge this physical click only.  The gold
				-- selection frame still waits for the later read-only confirmation.
				Overlay:StartOptionClickFeedback(self)
				playOptionClickSound()
			end
		end
	end)
	button.shareButton = CreateFrame("Button", nil, button)
	button.shareButton:SetAllPoints(button)
	button.shareButton:SetScript("OnEnter", function()
		button:GetScript("OnEnter")(button)
	end)
	button.shareButton:SetScript("OnLeave", function()
		button:GetScript("OnLeave")(button)
	end)
	button.shareButton:SetScript("OnClick", function(_, mouseButton)
		-- Normal clicks intentionally do nothing on the read-only surface.
		if mouseButton == "LeftButton" and IsModifiedClick and IsModifiedClick("CHATLINK")
			and not Overlay.editing and not Overlay.hideAfterFade then
			Overlay:ShareProgress(button.option and button.option.difficultyID)
		end
	end)
	button.shareButton:Hide()
	return button
end

function Overlay:EnsureFrame()
	if self.frame or not CreateFrame then
		return self.frame
	end
	-- Stay on UIParent, outside the main panel and its scaled satellites.
	local frame = CreateFrame("Frame", "GroupFinderInstanceGatewayOverlay", UIParent)
	self.frame = frame
	-- Position belongs exclusively to InstanceGatewayService's saved variables.
	frame:SetDontSavePosition(true)
	-- SetUserPlaced requires a movable/resizable frame; clear it only after
	-- an actual edit drag. A newly created frame has no user placement to clear.
	frame:SetMovable(self.editing == true)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(false)
	frame:Hide()
	-- Account data is ready at startup, but the screen geometry can settle
	-- later. Keep an unsaved default current across those native boundaries.
	for _, event in ipairs({
		"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_DISABLED",
		"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
	}) do
		frame:RegisterEvent(event)
	end
	frame:SetScript("OnEvent", function() Overlay:QueueDefaultPositionRefresh() end)
	frame:SetScript("OnShow", function() Overlay:RefreshDefaultPosition() end)
	frame:SetScript("OnHide", function()
		if Overlay.arrivalToken and service() and service().DismissArrival then
			service():DismissArrival(Overlay.arrivalToken)
		end
		Overlay:HideTooltip()
	end)
	-- Plumber keeps a separate broad hover target behind its controls.  Keep the
	-- same interaction separation here: this frame owns only whole-overlay
	-- presentation, while the title and difficulty Buttons above it retain their
	-- native clicks, tooltips and per-option highlights.
	-- Static native propagation keeps hover feedback without blocking the
	-- controls underneath.  Only the actual title/difficulty Buttons own clicks.
	frame.hoverCapture = CreateFrame("Frame", nil, frame,
		"GroupFinderInstanceGatewayMotionTemplate")
	if frame.GetFrameLevel and frame.hoverCapture.SetFrameLevel then
		frame.hoverCapture:SetFrameLevel(frame:GetFrameLevel())
	end
	frame.hoverCapture:SetScript("OnEnter", function()
		Overlay:SetHovered(true)
	end)
	frame.hoverCapture:SetScript("OnLeave", function()
		Overlay:QueueHoverLeave()
	end)

	frame.title = createFontString(frame, "OVERLAY", "GameFontNormalLarge")
	local titleFontSize = GF.INSTANCE_GATEWAY_TITLE_FONT_SIZE or 18
	frame.title:SetPoint("TOP", frame, "TOP", 0, -1)
	frame.title:SetHeight(TITLE_HEIGHT)
	frame.title:SetJustifyH("CENTER")
	applyFont(frame.title, "GameFontNormalLarge", titleFontSize)
	frame.title:SetTextColor(0.96, 0.88, 0.68, 1)
	if frame.title.SetShadowColor then
		frame.title:SetShadowColor(0, 0, 0, 1)
		frame.title:SetShadowOffset(1, -1)
	end
	-- The title's user actions own their own physical click surface.  It is
	-- configured once during frame construction because RegisterForClicks is a
	-- protected API; refreshes only resize/show it and never mutate its click
	-- registration.
	frame.titleButton = CreateFrame("Button", nil, frame)
	frame.titleButton:SetPoint("TOP", frame, "TOP", 0, -1)
	frame.titleButton:SetHeight(TITLE_HEIGHT)
	frame.titleButton:SetWidth(1)
	frame.titleButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame.titleButton:SetScript("OnEnter", function(self)
		Overlay:SetHovered(true)
		Overlay:ShowTitleTooltip(self)
	end)
	frame.titleButton:SetScript("OnLeave", function(self)
		Overlay:QueueHoverLeave()
		Overlay:HideTooltip(self)
	end)
	frame.titleButton:SetScript("OnClick", function(_, button)
		if Overlay.editing or Overlay.hideAfterFade or not service() then
			return
		end
		if button == "LeftButton" then
			if IsModifiedClick and IsModifiedClick("CHATLINK") then
				Overlay:ShareProgress()
			else
				service():OpenAdventureGuide()
			end
		elseif button == "RightButton" then
			if Overlay.snapshot and Overlay.snapshot.kind == "arrival" then
				Overlay:DismissArrival()
			else
				service():ShowResetInstancesConfirmation()
			end
		end
	end)
	frame.arrivalDetail = createFontString(frame, "OVERLAY", "GameFontNormal")
	frame.arrivalDetail:SetPoint("TOP", frame.title, "BOTTOM", 0, -2)
	frame.arrivalDetail:SetHeight(22)
	frame.arrivalDetail:SetJustifyH("CENTER")
	if frame.arrivalDetail.SetJustifyV then
		frame.arrivalDetail:SetJustifyV("MIDDLE")
	end
	applyFont(frame.arrivalDetail, "GameFontNormal", 18)
	frame.arrivalButton = CreateFrame("Button", nil, frame)
	frame.arrivalButton:SetPoint("TOP", frame.arrivalDetail, "TOP")
	frame.arrivalButton:SetHeight(22)
	frame.arrivalButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame.arrivalButton:SetScript("OnEnter", function(self)
		Overlay:SetHovered(true)
		Overlay:ShowOptionTooltip(self)
	end)
	frame.arrivalButton:SetScript("OnLeave", function(self)
		Overlay:QueueHoverLeave()
		Overlay:HideTooltip(self)
	end)
	frame.arrivalButton:SetScript("OnClick", function(_, button)
		frame.titleButton:GetScript("OnClick")(frame.titleButton, button)
	end)
	frame.arrivalButton:Hide()
	frame.hint = createFontString(frame, "OVERLAY", "GameFontNormal")
	frame.hint:SetPoint("TOP", frame.title, "BOTTOM", 0, -2)
	frame.hint:SetJustifyH("CENTER")
	applyFont(frame.hint, "GameFontNormal", 12)
	frame.hint:SetTextColor(0.88, 0.86, 0.8, 1)

	frame.rail = CreateFrame("Frame", nil, frame)
	if frame.GetFrameLevel and frame.rail.SetFrameLevel then
		frame.rail:SetFrameLevel(frame:GetFrameLevel() + 1)
	end
	frame.rail:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -TITLE_HEIGHT - TITLE_GAP)
	frame.rail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -TITLE_HEIGHT - TITLE_GAP)
	frame.rail:SetHeight(RAIL_HEIGHT)
	frame.rail:EnableMouse(false)
	frame.hoverCapture:SetPoint("TOPLEFT", frame, "TOPLEFT",
		-HOVER_CAPTURE_OUTSET_X, HOVER_CAPTURE_OUTSET_Y)
	frame.hoverCapture:SetPoint("BOTTOMRIGHT", frame.rail, "BOTTOMRIGHT",
		HOVER_CAPTURE_OUTSET_X, -HOVER_CAPTURE_OUTSET_Y)
	-- Start below the upper gold-line strip so the mask cannot show above it.
	-- Keep the bottom at the lower rail edge to retain its existing contact.
	frame.railMask = frame.rail:CreateTexture(nil, "BACKGROUND")
	if setTintedAtlas(frame.railMask, "plunderstorm-pickup-BG", 0, 0, 0, 1) then
		frame.railMask:SetPoint("TOPLEFT", frame.rail, "TOPLEFT", 0, -RAIL_LINE_HEIGHT)
		frame.railMask:SetPoint("BOTTOMRIGHT", frame.rail, "BOTTOMRIGHT", 0, 0)
	else
		frame.railMask:Hide()
	end
	-- Use the shop's native soft black shadow behind the title and rail.
	-- This decorative texture owns no mouse input, even outside the frame.
	frame.hoverBackdrop = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	if setTintedAtlas(frame.hoverBackdrop, "shop-drop-shadow", 1, 1, 1, 1) then
		frame.hoverBackdrop:SetAlpha(HOVER_BACKDROP_ALPHA * HOVER_BACKDROP_IDLE_MULTIPLIER)
	else
		frame.hoverBackdrop:Hide()
	end
	frame.topLine = frame.rail:CreateTexture(nil, "ARTWORK")
	setAtlas(frame.topLine, "levelup-bar-gold", 1, 0.72, 0.05, 0.9)
	frame.topLine:SetPoint("TOPLEFT", frame.rail, "TOPLEFT")
	frame.topLine:SetPoint("TOPRIGHT", frame.rail, "TOPRIGHT")
	frame.topLine:SetHeight(RAIL_LINE_HEIGHT)
	frame.bottomLine = frame.rail:CreateTexture(nil, "ARTWORK")
	setAtlas(frame.bottomLine, "levelup-bar-gold", 1, 0.72, 0.05, 0.9)
	frame.bottomLine:SetPoint("BOTTOMLEFT", frame.rail, "BOTTOMLEFT")
	frame.bottomLine:SetPoint("BOTTOMRIGHT", frame.rail, "BOTTOMRIGHT")
	frame.bottomLine:SetHeight(RAIL_LINE_HEIGHT)
	frame.selection = createSelectionFrame(frame.rail)
	if frame.rail.GetFrameLevel and frame.selection.SetFrameLevel then
		frame.selection:SetFrameLevel(frame.rail:GetFrameLevel() + 1)
	end
	frame.selection:Hide()
	frame.buttons = {}

	frame:SetScript("OnUpdate", function(_, elapsed)
		Overlay:AdvanceFade(frame, elapsed)
		Overlay._hoverElapsed = (Overlay._hoverElapsed or 0) + elapsed
		if Overlay._hoverElapsed >= 0.05 then
			Overlay._hoverElapsed = 0
			Overlay:RefreshHoverState(frame)
		end
		Overlay:AdvancePresentation(frame, elapsed)
		Overlay:AdvanceSelection(frame, elapsed)
		Overlay:AdvanceClickFeedback(frame)
		if not Overlay.editing and Overlay.snapshot and Overlay.snapshot.kind == "arrival"
			and Overlay.arrivalUntil
			and not Overlay.arrivalPaused
			and Overlay.arrivalExpiredToken ~= Overlay.arrivalToken
			and now() >= Overlay.arrivalUntil
		then
			Overlay.arrivalExpiredToken = Overlay.arrivalToken
			Overlay:Apply()
		end
	end)
	self:ApplyPosition()
	return frame
end

function Overlay:RefreshDefaultPosition()
	local editor = GF.InstanceGatewayEditMode
	local owner = service()
	if not self.frame or not owner or (editor and editor.dragging)
		or owner:GetPosition() ~= nil
	then
		return false
	end
	self:ApplyPosition()
	return true
end

function Overlay:QueueDefaultPositionRefresh()
	if not self.frame or self.defaultPositionRefreshPending then
		return
	end
	self.defaultPositionRefreshPending = true
	local function refresh()
		self.defaultPositionRefreshPending = nil
		-- Recheck saved position and dragging when the callback runs: the user
		-- may have moved the overlay since the layout event was received.
		self:RefreshDefaultPosition()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, refresh)
	else
		refresh()
	end
end

function Overlay:ApplyPosition()
	local frame = self:EnsureFrame()
	if not frame then
		return
	end
	local point, relativePoint, x, y
	if service() then
		point, relativePoint, x, y = service():GetPosition()
	end
	frame:ClearAllPoints()
	if point then
		frame:SetPoint(point, UIParent, relativePoint, x, y)
	else
		local defaultPoint, defaultRelativePoint, defaultX, defaultY =
			GF.UI.GetDefaultInstanceGatewayPosition()
		frame:SetPoint(defaultPoint, UIParent, defaultRelativePoint, defaultX, defaultY)
	end
end

function Overlay:SavePosition()
	local frame = self.frame
	local owner = service()
	if not (frame and owner and UIParent) then
		return false
	end
	local centerX = frame:GetCenter()
	local top = frame:GetTop()
	local parentCenterX = UIParent:GetCenter()
	local parentTop = UIParent:GetTop()
	if not (centerX and top and parentCenterX and parentTop) then
		return false
	end
	local relativeScale = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
	-- Native dragging may choose LEFT/RIGHT or a corner. Keep the title's
	-- top center stable when the preview and real difficulty layouts differ.
	local x = centerX - parentCenterX * relativeScale
	local y = top - parentTop * relativeScale
	if owner:SetPosition("TOP", "TOP", x, y) ~= true then
		return false
	end
	self:ApplyPosition()
	return true
end

function Overlay:EnsureButton(index)
	local frame = self:EnsureFrame()
	if not frame then
		return nil
	end
	local button = frame.buttons[index]
	if not button then
		button = createOptionButton(frame.rail)
		frame.buttons[index] = button
	end
	return button
end

function Overlay:RenderEditPreview(frame)
	-- These options never enter the service snapshot and have no difficulty IDs.
	-- Reuse the real renderer so fonts, shadows, gold lines and selection match.
	local options = {}
	for index, entry in ipairs({
		{ "INSTANCE_GATEWAY_PREVIEW_NORMAL", "Normal difficulty" },
		{ "INSTANCE_GATEWAY_PREVIEW_HEROIC", "Heroic difficulty" },
		{ "INSTANCE_GATEWAY_PREVIEW_MYTHIC", "Mythic difficulty" },
	}) do
		options[index] = {
			name = localText(entry[1], entry[2]), playerCount = 5,
			progressReady = true, done = 0, total = 3,
			enabled = true, selected = index == 1,
		}
	end
	self:RenderEntrance(frame, {
		kind = "preview",
		name = localText("SET_SECTION_INSTANCE_GATEWAY", "Instance difficulty overlay"),
		options = options,
	})
end

function Overlay:RenderArrival(frame, snapshot)
	local option = snapshot.options and snapshot.options[1]
	if not option then
		self:BeginFadeOut()
		return
	end
	frame.title:SetText(snapshot.name or "")
	frame.arrivalDetail:SetText(formatArrivalDetail(option))
	frame.arrivalDetail:Show()
	frame.arrivalButton.option = option
	frame.arrivalButton:SetWidth(math.max(1, (frame.arrivalDetail:GetStringWidth() or 0) + 20))
	frame.arrivalButton:EnableMouse(true)
	frame.arrivalButton:Show()
	frame.hint:Hide()
	frame.rail:Hide()
	if frame.hoverCapture then
		frame.hoverCapture:Hide()
	end
	if frame.hoverBackdrop then
		frame.hoverBackdrop:Hide()
	end
	frame.selection:Hide()
	for _, button in ipairs(frame.buttons) do
		button:Hide()
	end
	local titleWidth = frame.title:GetStringWidth() or 0
	local detailWidth = frame.arrivalDetail:GetStringWidth() or 0
	frame:SetSize(math.max(240, math.ceil(math.max(titleWidth, detailWidth) + 48)),
		TITLE_HEIGHT + 24)
	layoutTitleButton(frame, true)
	frame:SetMovable(false)
	if not frame:IsShown() then
		frame:SetAlpha(0)
	end
	frame:EnableMouse(false)
	if frame.hoverCapture then
		frame.hoverCapture:SetMouseMotionEnabled(false)
	end
	self:SetTargetAlpha(ACTIVE_ALPHA)
	self:SetPresentationTarget(ACTIVE_ALPHA)
	self:ApplyPresentation(frame, self.presentationAlpha or ACTIVE_ALPHA)
	frame:Show()
end

function Overlay:Render(snapshot)
	-- A hidden startup snapshot needs neither a frame nor its fonts/textures.
	-- Keep the existing fade lifecycle once the view has actually been shown.
	if not self.editing and not (snapshot.options and #snapshot.options > 0)
	then
		if self.frame then self:BeginFadeOut() end
		return
	end
	local frame = self:EnsureFrame()
	if not frame then
		return
	end
	if self.editing then
		self:RenderEditPreview(frame)
		return
	end
	if snapshot.kind == "arrival" then
		self:RenderArrival(frame, snapshot)
		return
	end
	self:RenderEntrance(frame, snapshot)
end

function Overlay:RenderEntrance(frame, snapshot)
	local options = snapshot.options or {}
	local count = #options
	if count == 0 then
		self:BeginFadeOut()
		return
	end
	frame.title:SetText(snapshot.name or "")
	frame.arrivalDetail:Hide()
	frame.arrivalButton:Hide()
	frame.hint:Hide()
	frame.rail:Show()
	if frame.hoverCapture then
		frame.hoverCapture:SetShown(not self.editing)
		frame.hoverCapture:SetMouseMotionEnabled(not self.editing)
	end
	if frame.hoverBackdrop then
		frame.hoverBackdrop:Show()
	end
	-- All rows receive the same slot width (the widest text plus padding).  The
	-- selected frame therefore only slides along X; it never changes width as it
	-- crosses differently named difficulties, which is the important visual
	-- distinction in Plumber's selector and prevents corner deformation.
	local widestText = 0
	for index = 1, count do
		local button = self:EnsureButton(index)
		button.difficultyText:SetText(formatDifficulty(options[index]))
		button.progressText:SetText(formatProgress(options[index]))
		local textWidth = (button.difficultyText:GetStringWidth() or 0)
			+ 8 + (button.progressText:GetStringWidth() or 0)
		widestText = math.max(widestText, textWidth)
	end
	local optionWidth = math.max(MIN_OPTION_WIDTH,
		math.min(MAX_OPTION_WIDTH, math.ceil(widestText + 30)))
	local totalWidth = optionWidth * count
	if count > 1 then
		totalWidth = totalWidth + (count - 1) * BUTTON_GAP
	end
	local maxWidth = math.max(280, (UIParent:GetWidth() or 1024) - 80)
	if totalWidth + FRAME_PADDING_X * 2 > maxWidth then
		local available = math.max(72, math.floor((maxWidth - FRAME_PADDING_X * 2
			- (count - 1) * BUTTON_GAP) / count))
		totalWidth = 0
		optionWidth = available
		totalWidth = optionWidth * count
		if count > 1 then
			totalWidth = totalWidth + (count - 1) * BUTTON_GAP
		end
	end
	local frameWidth = math.max(280, totalWidth + FRAME_PADDING_X * 2)
	frame:SetSize(frameWidth, TITLE_HEIGHT + TITLE_GAP + RAIL_HEIGHT)
	layoutHoverBackdrop(frame.hoverBackdrop, frame, frameWidth)
	layoutTitleButton(frame, not self.editing and snapshot.journalInstanceID ~= nil)
	-- Share extra space from the minimum frame width between both sides.
	local x = (frameWidth - totalWidth) / 2
	local selectedX, selectedWidth
	for index = 1, count do
		local button = self:EnsureButton(index)
		button:ClearAllPoints()
		button:SetSize(optionWidth, RAIL_HEIGHT - BUTTON_INSET_Y * 2)
		button:SetPoint("LEFT", frame.rail, "LEFT", x, 0)
		setButtonState(button, options[index])
		layoutButtonText(button)
		button:Show()
		if options[index].selected == true then
			selectedX, selectedWidth = x, optionWidth
		end
		x = x + optionWidth + BUTTON_GAP
	end
	for index = count + 1, #frame.buttons do
		frame.buttons[index]:Hide()
	end
	if selectedX then
		-- An atlas unavailable during construction must not leave this cached
		-- frame hidden forever.  Retry only on normal snapshot renders.
		if frame.selection.hasFrame == false then
			frame.selection.hasFrame = configureSelectionFrame(frame.selection)
		end
		self:SetSelectionTarget(frame, selectedX, selectedWidth)
	else
		self.selectionX, self.selectionWidth = nil, nil
		self.selectionTargetX, self.selectionTargetWidth = nil, nil
		frame.selection:Hide()
	end
	frame:SetMovable(self.editing == true)
	if not frame:IsShown() then
		frame:SetAlpha(0)
	end
	frame:EnableMouse(false)
	self:SetTargetAlpha(ACTIVE_ALPHA)
	self:SetPresentationTarget((self.editing or self.hovered) and ACTIVE_ALPHA
		or (snapshot.kind == "entrance" and IDLE_PRESENTATION_ALPHA or ACTIVE_ALPHA))
	if self.editing then
		frame:SetAlpha(ACTIVE_ALPHA)
		self.presentationAlpha = ACTIVE_ALPHA
	end
	self:ApplyPresentation(frame, self.presentationAlpha
		or self.targetPresentationAlpha)
	frame:Show()
end

function Overlay:Apply(snapshot)
	if snapshot then
		self.snapshot = snapshot
	end
	local active = self.snapshot
	if not active and service() then
		active = service():GetSnapshot()
		self.snapshot = active
	end
	if not (active and service() and service():IsEnabled()) and not self.editing then
		-- Disabling the feature is a deliberate interruption, not an instance
		-- departure.  Remember the already-visible arrival token so re-enabling
		-- during that same entry cannot replay its one-time four-second notice.
		if self.arrivalToken then
			self.arrivalSuppressedToken = self.arrivalToken
		end
		if self.frame then
			self:BeginFadeOut()
		end
		return
	end
	if active and active.kind == "arrival" then
		local arrivalToken = active.arrivalToken or active.arrivalUntil
		if self.arrivalToken ~= arrivalToken then
			self.arrivalToken = arrivalToken
			self.arrivalExpiredToken = nil
			self.hovered, self.pendingHoverLeaveAt = false, nil
		end
		self.arrivalUntil = active.arrivalUntil
		self.arrivalPaused = active.arrivalPaused == true
		if self.arrivalSuppressedToken == arrivalToken then
			self.arrivalExpiredToken = arrivalToken
		end
		if self.editing ~= true and (active.arrivalDismissed
			or self.arrivalExpiredToken == arrivalToken
			or (not self.arrivalPaused and self.arrivalUntil and now() >= self.arrivalUntil))
		then
			self.arrivalExpiredToken = arrivalToken
			self:BeginFadeOut()
			return
		end
	else
		self.arrivalUntil = nil
		self.arrivalPaused = nil
		self.arrivalToken = nil
		self.arrivalExpiredToken = nil
		self.arrivalSuppressedToken = nil
	end
	self:Render(active or { kind = "hidden", options = {} })
	local tooltipOwner = self.tooltipOwner
	if tooltipOwner and GameTooltip and GameTooltip:IsOwned(tooltipOwner) then
		if self.frame and tooltipOwner == self.frame.titleButton then
			self:ShowTitleTooltip(tooltipOwner)
		elseif tooltipOwner.option then
			self:ShowOptionTooltip(tooltipOwner)
		end
	end
end

function Overlay:SetEditing(enteringEditMode)
	enteringEditMode = enteringEditMode == true
	if (self.editing == true) == enteringEditMode then
		return
	end
	if enteringEditMode and self.snapshot and self.snapshot.kind == "arrival" then
		-- Entering position edit mode deliberately replaces the short arrival
		-- announcement.  Mark this token consumed so returning from edit mode
		-- cannot replay a notice that was already shown for this entry.
		self.arrivalExpiredToken = self.arrivalToken
		if service() and service().DismissArrival then
			service():DismissArrival(self.arrivalToken)
		end
	end
	self:HideTooltip()
	self.hovered, self.pendingHoverLeaveAt = false, nil
	self.selectionX, self.selectionWidth = nil, nil
	self.selectionTargetX, self.selectionTargetWidth = nil, nil
	for _, button in ipairs(self.frame and self.frame.buttons or {}) do
		button.hovered, button.clickPulseStartedAt = false, nil
		if button.clickPulse then button.clickPulse:Hide() end
	end
	self.editing = enteringEditMode
	if self.frame then
		self.frame:SetMovable(enteringEditMode)
	end
	if enteringEditMode then
		self:RefreshDefaultPosition()
	end
	self:Apply()
	return self.editing
end

function Overlay:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	if UIParent and UIParent.HookScript then
		-- Also cover root resizes performed after the native scale event.
		UIParent:HookScript("OnSizeChanged", function()
			Overlay:QueueDefaultPositionRefresh()
		end)
	end
	if service() then
		service():AddListener(function(snapshot)
			Overlay:Apply(snapshot)
		end)
	end
	self:Apply()
end

-- RuntimeLifecycle initializes this view after SavedVariables and the service.
