local _, GF = ...

GF.UI = GF.UI or {}

local function setCommonScrollBarTextureRegion(texture, region)
	if not (texture and region) then
		return
	end
	local atlasWidth = GF.COMMON_ATLAS_WIDTH or 512
	local atlasHeight = GF.COMMON_ATLAS_HEIGHT or 256
	texture:SetTexture(GF.COMMON_ATLAS_TEXTURE)
	texture:SetTexCoord(
		region[1] / atlasWidth,
		(region[1] + region[3]) / atlasWidth,
		region[2] / atlasHeight,
		(region[2] + region[4]) / atlasHeight)
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(true)
	end
	if texture.SetTexelSnappingBias then
		texture:SetTexelSnappingBias(0)
	end
end

local function getCommonScrollBarStepperState(stepper)
	if stepper.IsEnabled and not stepper:IsEnabled() then
		return "disabled"
	end
	if stepper._gfCommonScrollBarPressed or stepper.down then
		return "pressed"
	end
	if stepper.over
		or (stepper.IsMouseMotionFocus and stepper:IsMouseMotionFocus())
	then
		return "highlighted"
	end
	return "normal"
end

-- Keep the native textures attached: MinimalScrollBar's size/state scripts
-- still query their atlases. Only their presentation is replaced.
local function hideNativeScrollBarSlices(skin)
	for _, owner in ipairs({ skin.track, skin.thumb }) do
		for _, texture in pairs({ owner.Begin, owner.Middle, owner.End }) do
			texture:SetAlpha(0)
			texture:Hide()
		end
	end
end

local function createCommonScrollBarVerticalSlices(owner, region, width, cap)
	local slices = { owner = owner, width = width, cap = cap, region = region }
	for index = 1, 3 do
		slices[index] = owner:CreateTexture(nil, "ARTWORK", nil, 1)
	end
	return slices
end

local function updateCommonScrollBarVerticalSlices(slices, region)
	region = region or slices.region
	slices.region = region
	local x, y, width, height = region[1], region[2], region[3], region[4]
	local cap = slices.cap
	local displayCap = cap * slices.width / width
	-- The native controller may clamp a thumb to a very short track.
	local ownerHeight = slices.owner:GetHeight()
	if ownerHeight and ownerHeight > 0 then
		displayCap = math.min(displayCap, ownerHeight / 2)
	end
	local top, middle, bottom = slices[1], slices[2], slices[3]
	setCommonScrollBarTextureRegion(top, { x, y, width, cap })
	setCommonScrollBarTextureRegion(middle, { x, y + cap, width, height - 2 * cap })
	setCommonScrollBarTextureRegion(bottom, { x, y + height - cap, width, cap })
	top:ClearAllPoints()
	top:SetPoint("TOP", slices.owner, "TOP", 0, 0)
	top:SetSize(slices.width, displayCap)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOM", slices.owner, "BOTTOM", 0, 0)
	bottom:SetSize(slices.width, displayCap)
	middle:ClearAllPoints()
	middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
	middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)
	for index = 1, 3 do
		slices[index]:Show()
	end
end

local function updateCommonScrollBarThumb(thumb)
	local skin = thumb._gfCommonScrollBarOwner
	if not (skin and skin.active) then
		return
	end
	local state = getCommonScrollBarStepperState(thumb)
	local regions = GF.COMMON_SCROLLBAR_THUMB_REGIONS
	-- The source has three states; disabled uses the neutral normal thumb.
	updateCommonScrollBarVerticalSlices(skin.thumbSlices, regions[state] or regions.normal)
	skin.thumbState = state
	hideNativeScrollBarSlices(skin)
end

local function applyCommonScrollBarBody(bar, track, thumb)
	local skin = bar._gfCommonScrollBarSkin
	if not skin then
		skin = { track = track, thumb = thumb }
		bar._gfCommonScrollBarSkin = skin
		skin.trackSlices = createCommonScrollBarVerticalSlices(track,
			GF.COMMON_SCROLLBAR_TRACK_REGION, GF.COMMON_SCROLLBAR_TRACK_WIDTH,
			GF.COMMON_SCROLLBAR_TRACK_CAP)
		skin.thumbSlices = createCommonScrollBarVerticalSlices(thumb,
			GF.COMMON_SCROLLBAR_THUMB_REGIONS.normal, GF.COMMON_SCROLLBAR_THUMB_WIDTH,
			GF.COMMON_SCROLLBAR_THUMB_CAP)
		thumb._gfCommonScrollBarOwner = skin
		-- This also observes programmatic native button-state changes.
		local stateEvents = { "OnShow", "OnSizeChanged" }
		if hooksecurefunc and thumb.OnButtonStateChanged then
			hooksecurefunc(thumb, "OnButtonStateChanged", updateCommonScrollBarThumb)
		else
			stateEvents = { "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp",
				"OnEnable", "OnDisable", "OnShow", "OnSizeChanged" }
		end
		for _, event in ipairs(stateEvents) do
			thumb:HookScript(event, updateCommonScrollBarThumb)
		end
		track:HookScript("OnSizeChanged", function()
			if skin.active then
				updateCommonScrollBarVerticalSlices(skin.trackSlices)
			end
		end)
	end
	if not skin.active then
		skin.nativeSlices = {}
		for _, owner in ipairs({ track, thumb }) do
			for _, texture in pairs({ owner.Begin, owner.Middle, owner.End }) do
				table.insert(skin.nativeSlices, {
					texture = texture,
					alpha = texture.GetAlpha and texture:GetAlpha() or 1,
					shown = not texture.IsShown or texture:IsShown(),
				})
			end
		end
	end
	skin.active = true
	updateCommonScrollBarVerticalSlices(skin.trackSlices)
	updateCommonScrollBarThumb(thumb)
	return skin
end

-- Borrowed EntryCreation fields must return to Blizzard with their own chrome.
function GF.UI.RestoreCommonScrollBarSkin(bar)
	local skin = bar and bar._gfCommonScrollBarSkin
	if not (skin and skin.active) then
		return
	end
	skin.active = nil
	for _, slices in ipairs({ skin.trackSlices, skin.thumbSlices }) do
		for index = 1, 3 do
			slices[index]:Hide()
		end
	end
	for _, original in ipairs(skin.nativeSlices) do
		original.texture:SetAlpha(original.alpha)
		if original.shown then
			original.texture:Show()
		else
			original.texture:Hide()
		end
	end
end

local COMMON_SCROLLBAR_STEPPER_STATES = {
	"normal",
	"highlighted",
	"pressed",
	"disabled",
}

local function applyCommonScrollBarStepperState(skin, state)
	state = skin.textures[state] and state or "normal"
	for _, candidateState in ipairs(COMMON_SCROLLBAR_STEPPER_STATES) do
		local alpha = candidateState == state and 1 or 0
		skin.textures[candidateState]:SetAlpha(alpha)
		skin.currentAlphas[candidateState] = alpha
	end
	skin.texture = skin.textures[state]
	skin.state = state
	skin.targetState = state
	skin.startAlphas = nil
	skin.elapsed = 0
	skin.fading = nil
	if skin.driver and skin.driver.Hide then
		skin.driver:Hide()
	end
end

local function finishCommonScrollBarStepperFade(skin)
	if not (skin and skin.fading) then
		return
	end
	applyCommonScrollBarStepperState(skin, skin.targetState)
end

local function advanceCommonScrollBarStepperFade(skin, elapsed)
	if not (skin and skin.fading) then
		return
	end
	local duration = GF.COMMON_SCROLLBAR_STEPPER_FADE_DURATION or 0.18
	if duration <= 0 then
		finishCommonScrollBarStepperFade(skin)
		return
	end
	skin.elapsed = (skin.elapsed or 0) + math.max(0, tonumber(elapsed) or 0)
	local progress = math.min(1, skin.elapsed / duration)
	local eased = progress * progress * (3 - 2 * progress)
	for _, state in ipairs(COMMON_SCROLLBAR_STEPPER_STATES) do
		local startAlpha = skin.startAlphas[state] or 0
		local targetAlpha = state == skin.targetState and 1 or 0
		local alpha = startAlpha + ((targetAlpha - startAlpha) * eased)
		skin.currentAlphas[state] = alpha
		skin.textures[state]:SetAlpha(alpha)
	end
	if progress >= 1 then
		finishCommonScrollBarStepperFade(skin)
	end
end

local function beginCommonScrollBarStepperFade(skin, state)
	if state == skin.targetState then
		return
	end
	if not (skin.driver and skin.driver.Show) then
		applyCommonScrollBarStepperState(skin, state)
		return
	end
	skin.startAlphas = {}
	for _, candidateState in ipairs(COMMON_SCROLLBAR_STEPPER_STATES) do
		skin.startAlphas[candidateState] =
			skin.currentAlphas[candidateState] or 0
	end
	skin.targetState = state
	skin.elapsed = 0
	skin.fading = true
	skin.driver:Show()
end

local function updateCommonScrollBarStepper(stepper, immediate)
	local skin = stepper and stepper._gfCommonScrollBarSkin
	if not skin then
		return
	end
	local state = getCommonScrollBarStepperState(stepper)
	if immediate or not skin.state then
		applyCommonScrollBarStepperState(skin, state)
	elseif state ~= skin.targetState then
		beginCommonScrollBarStepperFade(skin, state)
	end
end

local function applyCommonScrollBarStepper(stepper, regions, options)
	if not (stepper and stepper.CreateTexture and regions) then
		return nil
	end
	if stepper._gfCommonScrollBarSkin then
		updateCommonScrollBarStepper(stepper)
		return stepper._gfCommonScrollBarSkin
	end
	if stepper.Texture then
		if stepper.Texture.SetAlpha then
			stepper.Texture:SetAlpha(0)
		end
		if stepper.Texture.Hide then
			stepper.Texture:Hide()
		end
	end
	options = options or {}
	local hitSize = options.hitSize
		or GF.COMMON_SCROLLBAR_STEPPER_SIZE or 16
	local visualSize = options.visualSize or hitSize
	local rotation = options.rotation
	if rotation == nil then
		rotation = GF.COMMON_SCROLLBAR_STEPPER_ROTATION or (math.pi * 1.5)
	end
	stepper:SetSize(hitSize, hitSize)
	local textures = {}
	local currentAlphas = {}
	for index, state in ipairs(COMMON_SCROLLBAR_STEPPER_STATES) do
		local arrowTexture = stepper:CreateTexture(
			nil,
			"ARTWORK",
			nil,
			index)
		textures[state] = arrowTexture
		currentAlphas[state] = 0
		arrowTexture:SetPoint("CENTER", stepper, "CENTER", 0, 0)
		arrowTexture:SetSize(visualSize, visualSize)
		setCommonScrollBarTextureRegion(
			arrowTexture,
			regions[state] or regions.normal)
		arrowTexture:SetAlpha(0)
		if arrowTexture.SetRotation then
			arrowTexture:SetRotation(rotation)
		end
	end
	stepper._gfCommonScrollBarSkin = {
		textures = textures,
		currentAlphas = currentAlphas,
		regions = regions,
	}
	local skin = stepper._gfCommonScrollBarSkin
	if CreateFrame then
		local ok, driver = pcall(CreateFrame, "Frame", nil, stepper)
		if ok and driver and driver.SetScript then
			skin.driver = driver
			driver:SetScript("OnUpdate", function(_, elapsed)
				advanceCommonScrollBarStepperFade(skin, elapsed)
			end)
			if driver.Hide then
				driver:Hide()
			end
		end
	end
	if stepper.HookScript then
		stepper:HookScript("OnEnter", updateCommonScrollBarStepper)
		stepper:HookScript("OnLeave", function(self)
			self._gfCommonScrollBarPressed = nil
			updateCommonScrollBarStepper(self)
		end)
		stepper:HookScript("OnMouseDown", function(self)
			if not self.IsEnabled or self:IsEnabled() then
				self._gfCommonScrollBarPressed = true
			end
			updateCommonScrollBarStepper(self)
		end)
		stepper:HookScript("OnMouseUp", function(self)
			self._gfCommonScrollBarPressed = nil
			updateCommonScrollBarStepper(self)
		end)
		stepper:HookScript("OnEnable", updateCommonScrollBarStepper)
		stepper:HookScript("OnDisable", updateCommonScrollBarStepper)
		stepper:HookScript("OnShow", function(self)
			updateCommonScrollBarStepper(self, true)
		end)
		stepper:HookScript("OnHide", function(self)
			self._gfCommonScrollBarPressed = nil
			updateCommonScrollBarStepper(self, true)
		end)
	end
	if stepper.Show then
		stepper:Show()
	end
	updateCommonScrollBarStepper(stepper)
	return stepper._gfCommonScrollBarSkin
end

function GF.UI.ApplyCommonArrowButtonSkin(button, direction, options)
	local regions = tonumber(direction) and tonumber(direction) < 0
		and (GF.COMMON_SCROLLBAR_BACK_REGIONS or {})
		or (GF.COMMON_SCROLLBAR_FORWARD_REGIONS or {})
	return applyCommonScrollBarStepper(button, regions, options)
end

function GF.UI.ApplyCommonScrollBarSkin(bar, options)
	if not bar or bar.isHorizontal then
		return nil
	end
	local track = bar.GetTrack and bar:GetTrack() or bar.Track
	local thumb = bar.GetThumb and bar:GetThumb()
		or (track and track.Thumb)
	local back = bar.GetBackStepper and bar:GetBackStepper() or bar.Back
	local forward = bar.GetForwardStepper and bar:GetForwardStepper() or bar.Forward
	if not (track and thumb and back and forward) then
		return nil
	end
	local skin = applyCommonScrollBarBody(bar, track, thumb)
	-- Short borrowed description inputs keep their full-height track and no arrows.
	if options and options.bodyOnly then
		return skin
	end
	if track.ClearAllPoints then
		track:ClearAllPoints()
		track:SetPoint("TOP", bar, "TOP", 0, -19)
		track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 19)
	end
	local backSkin = applyCommonScrollBarStepper(
		back,
		GF.COMMON_SCROLLBAR_BACK_REGIONS or {})
	local forwardSkin = applyCommonScrollBarStepper(
		forward,
		GF.COMMON_SCROLLBAR_FORWARD_REGIONS or {})
	skin.back = backSkin
	skin.forward = forwardSkin
	return skin
end

function GF.UI.CreateContentScrollBar(scroll, barParent)
	local owner = barParent or scroll:GetParent() or scroll
	return GF.UI.BindMinimalScrollBar(scroll, GF.CONTENT_SCROLLBAR_OFFSET_X or 9, owner)
end

function GF.UI.AnchorContentScrollBottomRight(scroll, parent)
	local rightInset = -(GF.CONTENT_SCROLL_INSET_R or 0)
	local bottomInset = GF.CONTENT_SCROLL_INSET_B or 0
	scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", rightInset, bottomInset)
end

local function connectScrollBar(scroll, bar)
	local initializer = ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar
	if initializer then
		initializer(scroll, bar)
	elseif scroll.UpdateScrollChildRect then
		scroll:UpdateScrollChildRect()
	end
end

function GF.UI.BindMinimalScrollBar(scroll, offsetX, barParent, _keepNativeChrome)
	local horizontalOffset = offsetX or 4
	local owner = barParent or scroll:GetParent() or scroll
	GF.UI.HideLegacyScrollBar(scroll)
	local bar = CreateFrame("EventFrame", nil, owner, "MinimalScrollBar")
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", horizontalOffset, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", horizontalOffset, 0)
	bar:SetFrameLevel(scroll:GetFrameLevel() + 10)
	GF.UI.ApplyCommonScrollBarSkin(bar)
	bar:Show()
	bar._gfHideIfUnscrollable = true
	scroll.ScrollBar = bar
	if bar.SetHideIfUnscrollable then bar:SetHideIfUnscrollable(true) end
	connectScrollBar(scroll, bar)
	-- ScrollUtil 会安装自己的滚轮脚本，初始化后再恢复按行滚动。
	local restoreWheel = GF.UI.BindRowWheelScrolling
	restoreWheel(scroll, true)
	return bar
end

function GF.UI.UpdateScrollFrame(scroll)
	if scroll == nil then
		return
	end
	if scroll.UpdateScrollChildRect then
		scroll:UpdateScrollChildRect()
	end
	local rangeChanged = scroll:GetScript("OnScrollRangeChanged")
	if rangeChanged then
		rangeChanged(scroll, scroll:GetHorizontalScrollRange(), scroll:GetVerticalScrollRange())
	end
	local bar = scroll.ScrollBar
	if bar and bar.Update then
		bar:Update()
	end
	if bar and bar._gfHideIfUnscrollable and scroll.GetVerticalScrollRange then
		bar:SetShown((scroll:GetVerticalScrollRange() or 0) > 0)
	end
end
