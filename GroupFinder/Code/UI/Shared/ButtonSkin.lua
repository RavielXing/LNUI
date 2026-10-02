local _, GF = ...

GF.UI = GF.UI or {}

-- 共享红色按钮、表头刷新图标与四态皮肤。

local BUTTON_VISUAL_STATE = GF.BUTTON_VISUAL_STATE
local COMMON_BUTTON_VISUALS = GF.COMMON_BUTTON_VISUALS
local HEADER_REFRESH_ICON_VISUALS = GF.HEADER_REFRESH_ICON_VISUALS
local COMMON_BUTTON_STYLE = GF.COMMON_BUTTON_STYLE
local COMMON_TITLE_BUTTON_TEXTURE = GF.COMMON_TITLE_BUTTON_TEXTURE
local COMMON_TITLE_BUTTON_BACKGROUND_REGIONS =
	GF.COMMON_TITLE_BUTTON_BACKGROUND_REGIONS or {}
local COMMON_TITLE_BUTTON_CLOSE_GLYPH_REGION =
	GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_REGION
local function killTextureRegion(region)
	if not region then
		return
	end
	if region.SetTexture then
		region:SetTexture(nil)
	end
	if region.SetAtlas then
		region:SetAtlas(nil)
	end
	if region.SetColorTexture then
		region:SetColorTexture(0, 0, 0, 0)
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
	if region.Hide then
		region:Hide()
	end
end

local function getCommonButtonVisual(state)
	return COMMON_BUTTON_VISUALS[state]
		or COMMON_BUTTON_VISUALS[BUTTON_VISUAL_STATE.NORMAL]
end

function GF.UI.GetCommonButtonVisual(state)
	return getCommonButtonVisual(state)
end

-- The native atlas owns its UVs; never reuse the former Common.png crop.
function GF.UI.SetRefreshIconAtlas(texture, maxSize)
	if not texture then return false end
	texture:SetTexture(nil)
	if maxSize then
		return GF.UI.SetAtlasFit(texture, GF.REFRESH_ICON_ATLAS, maxSize, maxSize)
	end
	return GF.UI.TrySetAtlas(texture, GF.REFRESH_ICON_ATLAS, false, nil, true)
end

local function updateHeaderRefreshHoverGlow(button, state)
	local glow = button and button._gfHeaderRefreshIconHoverGlow
	if not glow then
		return
	end
	local alpha = state == BUTTON_VISUAL_STATE.HOVER
		and (GF.BROWSE_HEADER_REFRESH_ICON_HOVER_GLOW_ALPHA or 0.4)
		or 0
	glow:SetAlpha(alpha)
end

local function isHeaderRefreshButtonAvailable(button)
	return button
		and button._gfHeaderRefreshPending ~= true
		and (not button.IsEnabled or button:IsEnabled())
end

local function resolveHeaderRefreshIconState(button, state)
	if not button then
		return state
	end
	if button._gfHeaderRefreshPending == true then
		return BUTTON_VISUAL_STATE.NORMAL
	end
	if button.IsEnabled and not button:IsEnabled() then
		return BUTTON_VISUAL_STATE.DISABLED
	end
	if state == BUTTON_VISUAL_STATE.NORMAL then
		if button._gfHeaderRefreshIconPressed == true then
			return BUTTON_VISUAL_STATE.PRESSED
		end
		if button._gfHeaderRefreshIconHovered == true then
			return BUTTON_VISUAL_STATE.HOVER
		end
	end
	return state
end

local function getHeaderRefreshRestingState(button)
	if button and button._gfHeaderRefreshPending == true then
		return BUTTON_VISUAL_STATE.NORMAL
	end
	if button and button.IsEnabled and not button:IsEnabled() then
		return BUTTON_VISUAL_STATE.DISABLED
	end
	if button and button._gfHeaderRefreshIconHovered == true then
		return BUTTON_VISUAL_STATE.HOVER
	end
	return BUTTON_VISUAL_STATE.NORMAL
end

local function installHeaderRefreshIconStateHooks(button)
	if not (button and button.HookScript)
		or button._gfHeaderRefreshIconStateHooks
	then
		return
	end
	button._gfHeaderRefreshIconStateHooks = true
	local function hook(scriptName, handler)
		pcall(button.HookScript, button, scriptName, handler)
	end
	-- The business callback may already have started loading when this hook runs.
	hook("OnClick", function(_, mouseButton)
		if mouseButton == "LeftButton" and GF.UI.PlayUISound then
			GF.UI.PlayUISound(GF.BROWSE_HEADER_REFRESH_CLICK_SOUND)
		end
	end)
	hook("OnEnter", function(self)
		self._gfHeaderRefreshIconHovered = true
		if isHeaderRefreshButtonAvailable(self) then
			GF.UI.SetHeaderRefreshIconState(
				self,
				BUTTON_VISUAL_STATE.HOVER
			)
		end
	end)
	hook("OnLeave", function(self)
		self._gfHeaderRefreshIconHovered = nil
		self._gfHeaderRefreshIconPressed = nil
		GF.UI.SetHeaderRefreshIconState(
			self,
			getHeaderRefreshRestingState(self)
		)
	end)
	hook("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton"
			and isHeaderRefreshButtonAvailable(self)
		then
			self._gfHeaderRefreshIconPressed = true
			GF.UI.SetHeaderRefreshIconState(
				self,
				BUTTON_VISUAL_STATE.PRESSED
			)
		end
	end)
	hook("OnMouseUp", function(self, mouseButton)
		if mouseButton == nil or mouseButton == "LeftButton" then
			self._gfHeaderRefreshIconPressed = nil
			GF.UI.SetHeaderRefreshIconState(
				self,
				getHeaderRefreshRestingState(self)
			)
		end
	end)
	hook("OnEnable", function(self)
		GF.UI.SetHeaderRefreshIconState(
			self,
			getHeaderRefreshRestingState(self)
		)
	end)
	hook("OnDisable", function(self)
		self._gfHeaderRefreshIconPressed = nil
		GF.UI.SetHeaderRefreshIconState(
			self,
			self._gfHeaderRefreshPending
				and BUTTON_VISUAL_STATE.NORMAL
				or BUTTON_VISUAL_STATE.DISABLED
		)
	end)
	hook("OnHide", function(self)
		self._gfHeaderRefreshIconHovered = nil
		self._gfHeaderRefreshIconPressed = nil
		updateHeaderRefreshHoverGlow(self, BUTTON_VISUAL_STATE.NORMAL)
	end)
end

function GF.UI.InstallHeaderRefreshIconHoverGlow(button)
	local icon = button and button.Icon
	if not (button and icon and button.CreateTexture) then
		return nil
	end
	local glow = button._gfHeaderRefreshIconHoverGlow
	if not glow then
		glow = button:CreateTexture(nil, "OVERLAY", nil, 1)
		button._gfHeaderRefreshIconHoverGlow = glow
	end
	GF.UI.SetRefreshIconAtlas(glow)
	glow:ClearAllPoints()
	glow:SetAllPoints(icon)
	glow:SetBlendMode("ADD")
	if glow.SetDesaturated then
		glow:SetDesaturated(
			GF.BROWSE_HEADER_REFRESH_ICON_HOVER_GLOW_DESATURATED == true
		)
	end
	glow:SetVertexColor(1, 1, 1, 1)
	glow:Show()
	installHeaderRefreshIconStateHooks(button)
	updateHeaderRefreshHoverGlow(
		button,
		button._gfHeaderRefreshIconState
	)
	return glow
end

function GF.UI.SetHeaderRefreshIconState(button, state, baseOffsetY)
	local icon = button and button.Icon
	if not icon then
		return
	end

	if baseOffsetY ~= nil then
		button._gfHeaderRefreshIconBaseOffsetY = tonumber(baseOffsetY) or 0
	end
	baseOffsetY = button._gfHeaderRefreshIconBaseOffsetY or 0

	state = resolveHeaderRefreshIconState(
		button,
		state or BUTTON_VISUAL_STATE.NORMAL
	)
	local visual = HEADER_REFRESH_ICON_VISUALS[state]
		or HEADER_REFRESH_ICON_VISUALS[BUTTON_VISUAL_STATE.NORMAL]
		or {}
	local offset = visual.offset or { 0, 0 }
	local size = visual.size or GF.BROWSE_HEADER_REFRESH_ICON_SIZE or 18

	icon:ClearAllPoints()
	-- State sizes bound the artwork; the native atlas keeps its aspect ratio.
	GF.UI.SetRefreshIconAtlas(icon, size)
	icon:SetPoint(
		"CENTER",
		button,
		"CENTER",
		offset[1] or 0,
		baseOffsetY + (offset[2] or 0)
	)
	icon:SetAlpha(visual.alpha == nil and 1 or visual.alpha)
	if icon.SetDesaturated then
		icon:SetDesaturated(visual.desaturated == true)
	end
	if icon.SetBlendMode then
		icon:SetBlendMode(visual.blendMode or "BLEND")
	end
	button._gfHeaderRefreshIconState = state
	updateHeaderRefreshHoverGlow(button, state)
end

-- One native nine-slice texture; only the middle stretches horizontally.
function GF.UI.CreateCommonButtonBackground(parent)
	local texture = parent:CreateTexture(nil, "BACKGROUND")
	texture._gfButtonOwner = parent
	texture:SetTexture(GF.COMMON_BUTTON_TEXTURE)
	texture:SetBlendMode("BLEND")
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(false)
		texture:SetTexelSnappingBias(0)
	end
	return texture
end

function GF.UI.SetCommonButtonTextureState(texture, state)
	if not texture then return false end
	local region = GF.COMMON_BUTTON_REGIONS[state] or GF.COMMON_BUTTON_REGIONS.normal
	local parent = texture._gfButtonOwner
	local width, height = parent:GetWidth(), parent:GetHeight()
	if width <= 0 or height <= 0 then return false end
	local scale = height / region[4]
	texture:SetTexCoord(region[1] / GF.COMMON_ATLAS_WIDTH,
		(region[1] + region[3]) / GF.COMMON_ATLAS_WIDTH,
		region[2] / GF.COMMON_ATLAS_HEIGHT,
		(region[2] + region[4]) / GF.COMMON_ATLAS_HEIGHT)
	local margin = COMMON_BUTTON_STYLE.sliceMargin
	texture:SetTextureSliceMargins(margin, margin, margin, margin)
	texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
	texture:SetScale(scale)
	texture:ClearAllPoints()
	texture:SetSize(width / scale, height / scale)
	texture:SetPoint("CENTER", parent, "CENTER", 0, 0)
	return true
end

local function clearButtonStateTexture(button, kind)
	if not button then
		return
	end
	local getter = button["Get" .. kind .. "Texture"]
	local setter = button["Set" .. kind .. "Texture"]
	if getter then
		killTextureRegion(getter(button))
	end
	if setter then
		pcall(setter, button, nil)
	end
end

GF.UI.ClearButtonStateTexture = clearButtonStateTexture

local BUTTON_FADE_STATES = { "normal", "pressed", "hover", "disabled" }

local function createButtonStateFade(button, skin, updateLayer, paintValues)
	local fade = { layers = {}, values = {}, targetValues = {}, fromValues = {} }
	fade.driver = CreateFrame("Frame", nil, button)
	function fade:Paint()
		if self.active then
			-- Limit overlap dimming without fully cancelling the outgoing fade:
			-- transparent border pixels must also disappear continuously.
			local covered = 0
			for index = #self.layers, 1, -1 do
				local layer = self.layers[index]
				layer.texture:SetAlpha(math.min(1, layer.weight / (1 - covered * 0.65)))
				covered = math.min(1, covered + layer.weight)
			end
		end
		paintValues(self.values)
	end
	function fade:Finish()
		self.active = nil
		self.driver:SetScript("OnUpdate", nil)
		for _, layer in ipairs(self.layers) do
			layer.weight = layer.state == self.state and 1 or 0
			layer.texture:Hide()
		end
		skin.background:SetAlpha(1)
		for index, value in ipairs(self.targetValues) do self.values[index] = value end
		self:Paint()
	end

	local function advance(_, elapsed)
		fade.elapsed = fade.elapsed + elapsed
		local progress = math.min(1, fade.elapsed / skin.transitionDuration)
		local eased = progress * progress * (3 - 2 * progress)
		for _, layer in ipairs(fade.layers) do
			local target = layer.state == fade.state and 1 or 0
			layer.weight = layer.fromWeight + (target - layer.fromWeight) * eased
		end
		for index, target in ipairs(fade.targetValues) do
			local from = fade.fromValues[index]
			fade.values[index] = from + (target - from) * eased
		end
		if progress == 1 then fade:Finish() else fade:Paint() end
	end

	function fade:Set(state, values, immediate)
		local previousState = self.state
		local changed = state ~= previousState
		for index, value in ipairs(values) do
			if self.targetValues[index] ~= value then changed = true end
			self.targetValues[index] = value
		end
		self.state = state
		-- Input state changes immediately. Press/release remain tactile; fading
		-- only affects color, including a disable that interrupts a held press.
		if immediate or not previousState or skin.transitionDuration <= 0
			or (button.IsVisible and not button:IsVisible())
			or state == BUTTON_VISUAL_STATE.PRESSED
			or (previousState == BUTTON_VISUAL_STATE.PRESSED
				and state ~= BUTTON_VISUAL_STATE.DISABLED)
		then
			self:Finish()
			return
		end
		if changed then
			if #self.layers == 0 then
				for _, candidate in ipairs(BUTTON_FADE_STATES) do
					local texture = button:CreateTexture(nil, "ARTWORK", nil, -2)
					updateLayer(texture, candidate)
					texture:SetBlendMode("BLEND")
					if texture.SetSnapToPixelGrid then
						texture:SetSnapToPixelGrid(false)
						texture:SetTexelSnappingBias(0)
					end
					self.layers[#self.layers + 1] = {
						state = candidate, texture = texture,
						weight = candidate == previousState and 1 or 0,
					}
				end
			end
			for _, layer in ipairs(self.layers) do layer.fromWeight = layer.weight end
			for index, value in ipairs(self.values) do self.fromValues[index] = value end
			self.elapsed, self.active = 0, true
			self.driver:SetScript("OnUpdate", advance)
		end
		if self.active then
			local drawLayer, subLevel = "ARTWORK", -2
			if skin.background.GetDrawLayer then
				local layer, level = skin.background:GetDrawLayer()
				drawLayer, subLevel = layer or drawLayer, level or 0
			end
			for index, layer in ipairs(self.layers) do
				updateLayer(layer.texture, layer.state)
				layer.texture:SetDrawLayer(drawLayer, subLevel - #self.layers + index)
				layer.texture:Show()
			end
			skin.background:SetAlpha(0)
		end
		self:Paint()
	end
	fade.driver:SetScript("OnHide", function() fade:Finish() end)
	return fade
end


local function setupCommonPanelButtonBackground(button)
	if not button._gfCommonButtonBg then
		button._gfCommonButtonBg = GF.UI.CreateCommonButtonBackground(button)
	end
	return button._gfCommonButtonBg
end

local function applyCommonPanelButtonVisualState(button, state)
	if not button then return end
	local visual = getCommonButtonVisual(state)
	local texture = setupCommonPanelButtonBackground(button)
	GF.UI.SetCommonButtonTextureState(texture, state)
	texture:SetDesaturated(visual.desaturated == true)
	local color = visual.textureColor
	texture:SetVertexColor(color[1], color[2], color[3], color[4])
	texture:SetAlpha(1)
	texture:Show()
	button._gfCommonButtonSlice = "nativeNineSlice"
end

local function getCommonPanelButtonLabel(button)
	if not button then
		return nil
	end
	return button._gfCommonButtonLabel
		or (button.GetFontString and button:GetFontString())
end

local function setCommonPanelButtonTextColor(button, state, immediate)
	if not button then
		return
	end
	local fs = getCommonPanelButtonLabel(button)
	if not fs or not fs.SetTextColor then
		return
	end
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(
			fs,
			fs._gfFontTemplate or "GameFontNormal")
	end
	local width = button.GetWidth and button:GetWidth() or 0
	if width > COMMON_BUTTON_STYLE.textPadding * 2 then
		local available = width - COMMON_BUTTON_STYLE.textPadding * 2
		fs:SetWidth(available)
		if GF.Font and GF.Font.SetFitWidth then
			GF.Font.SetFitWidth(fs, available, fs._gfFitMinSize or COMMON_BUTTON_STYLE.minFontSize)
		end
	end
	local visual = getCommonButtonVisual(state)
	local color = (button._gfCommonButtonTextColors and button._gfCommonButtonTextColors[state])
		or visual.textColor
	local skin = button._gfCommonPanelButtonSkin
	if not skin then
		skin = {
			background = button._gfCommonButtonBg,
			transitionDuration = GF.COMMON_PANEL_BUTTON_FADE_DURATION or 0.16,
		}
		button._gfCommonPanelButtonSkin = skin
		skin.fade = createButtonStateFade(button, skin, function(texture, layerState)
			texture._gfButtonOwner = button
			texture:SetTexture(GF.COMMON_BUTTON_TEXTURE)
			GF.UI.SetCommonButtonTextureState(texture, layerState)
			local layerVisual = getCommonButtonVisual(layerState)
			texture:SetDesaturated(layerVisual.desaturated == true)
			local tint = layerVisual.textureColor
			texture:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
		end, function(values)
			local label = getCommonPanelButtonLabel(button)
			if label then label:SetTextColor(values[1], values[2], values[3], values[4]) end
		end)
	end
	skin.fade:Set(state, color, immediate)
	if button._gfCommonButtonLabel == fs then
		local offset = visual.textOffset
		fs:ClearAllPoints()
		fs:SetPoint("CENTER", button, "CENTER", offset[1], offset[2])
	end
end

local function updateCommonPanelButtonTextState(button, immediate)
	if not button then
		return
	end
	local enabled = not button.IsEnabled or button:IsEnabled()
	local visualState = BUTTON_VISUAL_STATE.NORMAL
	if not enabled then
		visualState = BUTTON_VISUAL_STATE.DISABLED
	elseif button._gfCommonButtonPressed then
		visualState = BUTTON_VISUAL_STATE.PRESSED
	elseif button._gfCommonButtonHovered then
		visualState = BUTTON_VISUAL_STATE.HOVER
	end
	applyCommonPanelButtonVisualState(button, visualState)
	setCommonPanelButtonTextColor(button, visualState, immediate == true)
	button._gfCommonButtonState = visualState
end

local function setCommonPanelButtonHoverState(button, hovered)
	if not button then
		return
	end
	button._gfCommonButtonHovered = hovered and true or nil
	if not hovered then
		button._gfCommonButtonPressed = nil
	end
	updateCommonPanelButtonTextState(button)
end

function GF.UI.SetCommonPanelButtonHovered(button, hovered)
	setCommonPanelButtonHoverState(button, hovered)
end

function GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(button, preserve)
	if not button then
		return
	end
	button._gfCommonButtonPreserveDisabledAlpha =
		preserve == true or nil
	updateCommonPanelButtonTextState(button)
end

local function installCommonPanelButtonTextStates(button)
	if not button or button._gfCommonButtonTextStates then
		updateCommonPanelButtonTextState(button)
		return
	end
	button._gfCommonButtonTextStates = true
	if button.SetEnabled and not button._gfCommonButtonSetEnabled then
		button._gfCommonButtonSetEnabled = button.SetEnabled
		button.SetEnabled = function(self, enabled)
			self:_gfCommonButtonSetEnabled(enabled)
			if not self:IsEnabled() then self._gfCommonButtonPressed = nil end
			updateCommonPanelButtonTextState(self)
		end
	end
	local function hook(scriptName, handler)
		if button.HookScript then
			pcall(button.HookScript, button, scriptName, handler)
		end
	end
	hook("OnEnter", function(self)
		setCommonPanelButtonHoverState(self, true)
	end)
	hook("OnLeave", function(self)
		setCommonPanelButtonHoverState(self, false)
	end)
	hook("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton" and (not self.IsEnabled or self:IsEnabled()) then
			self._gfCommonButtonPressed = true
			updateCommonPanelButtonTextState(self)
		end
	end)
	hook("OnMouseUp", function(self)
		self._gfCommonButtonPressed = nil
		updateCommonPanelButtonTextState(self)
	end)
	hook("OnEnable", function(self) updateCommonPanelButtonTextState(self) end)
	hook("OnDisable", function(self)
		self._gfCommonButtonPressed = nil
		updateCommonPanelButtonTextState(self)
	end)
	hook("OnHide", function(self)
		self._gfCommonButtonHovered = nil
		self._gfCommonButtonPressed = nil
		updateCommonPanelButtonTextState(self, true)
	end)
	hook("OnShow", function(self)
		local hovered = false
		if self.IsMouseMotionFocus then
			local ok, value = pcall(self.IsMouseMotionFocus, self)
			hovered = ok and value == true
		end
		self._gfCommonButtonHovered = hovered and true or nil
		self._gfCommonButtonPressed = nil
		updateCommonPanelButtonTextState(self, true)
	end)
	-- Native nine-slice follows both dimensions; refresh label fitting when
	-- responsive layouts resize a button without changing its visual state.
	hook("OnSizeChanged", function(self) updateCommonPanelButtonTextState(self) end)
	updateCommonPanelButtonTextState(button)
end

function GF.UI.RefreshCommonPanelButtonSkin(button)
	updateCommonPanelButtonTextState(button)
end

function GF.UI.ApplyCommonPanelButtonSkin(button, options)
	if not button then
		return
	end
	options = type(options) == "table" and options or {}
	-- A caller can specialize label colors while retaining the shared atlas,
	-- pressed offset, disabled treatment and shared state lifecycle.
	if options.textColors ~= nil then
		button._gfCommonButtonTextColors = type(options.textColors) == "table" and options.textColors or nil
	end
	if options.label then
		button._gfCommonButtonLabel = options.label
	end
	clearButtonStateTexture(button, "Normal")
	clearButtonStateTexture(button, "Pushed")
	clearButtonStateTexture(button, "Highlight")
	clearButtonStateTexture(button, "Disabled")
	if button.Left then
		button.Left:SetAlpha(0)
	end
	if button.Middle then
		button.Middle:SetAlpha(0)
	end
	if button.Right then
		button.Right:SetAlpha(0)
	end
	local bg = setupCommonPanelButtonBackground(button)
	button._gfCommonButtonSlice = "nativeNineSlice"
	if bg then
		bg:SetVertexColor(1, 1, 1, 1)
	end
	local pressedOffset = getCommonButtonVisual(BUTTON_VISUAL_STATE.PRESSED).textOffset
	button:SetPushedTextOffset(pressedOffset[1], pressedOffset[2])
	button:SetMotionScriptsWhileDisabled(true)
	local fs = getCommonPanelButtonLabel(button)
	if not fs then
		fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("CENTER", button, "CENTER", 0, 0)
		button:SetFontString(fs)
	end
	if fs then
		if GF.Font and GF.Font.Track then
			GF.Font.Track(fs, fs._gfFontTemplate or "GameFontNormal")
		end
		if fs ~= button._gfCommonButtonLabel then
			fs:SetText(button:GetText() or "")
		end
		fs:SetJustifyH("CENTER")
		fs:SetJustifyV("MIDDLE")
		local color = getCommonButtonVisual(BUTTON_VISUAL_STATE.NORMAL).textColor
		fs:SetTextColor(color[1], color[2], color[3], color[4])
	end
	installCommonPanelButtonTextStates(button)
end

local function setCommonTitleButtonTextureRegion(texture, region, inset)
	if not (texture and region) then
		return false
	end
	local atlasWidth = GF.COMMON_ATLAS_WIDTH or 512
	local atlasHeight = GF.COMMON_ATLAS_HEIGHT or 256
	inset = tonumber(inset) or 0.5
	texture:SetTexture(COMMON_TITLE_BUTTON_TEXTURE)
	texture:SetTexCoord(
		(region[1] + inset) / atlasWidth,
		(region[1] + region[3] - inset) / atlasWidth,
		(region[2] + inset) / atlasHeight,
		(region[2] + region[4] - inset) / atlasHeight)
	return true
end

local function getCommonTitleButtonState(button)
	local skin = button._gfCommonTitleButtonSkin
	if (button.IsEnabled and not button:IsEnabled())
		or (skin and skin.isDisabled and skin.isDisabled(button))
	then
		return BUTTON_VISUAL_STATE.DISABLED
	end
	if button._gfCommonTitleButtonPressed then
		return BUTTON_VISUAL_STATE.PRESSED
	end
	if button._gfCommonTitleButtonHovered then
		return BUTTON_VISUAL_STATE.HOVER
	end
	return BUTTON_VISUAL_STATE.NORMAL
end

local function layoutTitleButtonBackground(button, texture)
	local width = button.GetWidth and button:GetWidth() or 24
	local height = button.GetHeight and button:GetHeight() or 24
	local skin = button._gfCommonTitleButtonSkin
	local size = math.min(width, height,
		skin and skin.visualSize or GF.COMMON_TITLE_BUTTON_VISUAL_SIZE or 22)
	local scale = GF.COMMON_TITLE_BUTTON_TEXTURE_SCALE or 0.7
	local margin = GF.COMMON_TITLE_BUTTON_SLICE_MARGIN or 14
	texture:SetTextureSliceMargins(margin, margin, margin, margin)
	texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
	texture:SetScale(scale)
	texture:ClearAllPoints()
	texture:SetSize(size / scale, size / scale)
	texture:SetPoint("CENTER", button, "CENTER", 0, 0)
	return size
end

local function paintTitleButtonOpacity(skin, glyphAlpha, glowAlpha)
	skin.glyph:SetAlpha(glyphAlpha)
	skin.glow:SetAlpha(glowAlpha)
	if skin.shadow and skin.iconShadow then
		skin.shadow:SetAlpha((tonumber(skin.iconShadow.alpha) or 0.65) * glyphAlpha)
	end
end

local function paintTitleButtonValues(skin, values)
	paintTitleButtonOpacity(skin, values[1], values[2])
	if skin.iconHoverStyle then
		skin.glyph:SetVertexColor(values[3], values[4], values[5], 1)
	end
end

local function createTitleButtonFade(button, skin)
	return createButtonStateFade(button, skin, function(texture, state)
		setCommonTitleButtonTextureRegion(texture, COMMON_TITLE_BUTTON_BACKGROUND_REGIONS[state], 0)
		texture:SetVertexColor(1, 1, 1, 1)
		layoutTitleButtonBackground(button, texture)
	end, function(values)
		paintTitleButtonValues(skin, values)
	end)
end

local function applyCommonTitleButtonVisual(button, explicitState, immediate)
	local skin = button and button._gfCommonTitleButtonSkin
	if not skin then
		return
	end
	local state = explicitState or getCommonTitleButtonState(button)
	if state == BUTTON_VISUAL_STATE.DISABLED then
		button._gfCommonTitleButtonMouseDown = nil
		button._gfCommonTitleButtonPressed = nil
	end
	local region = COMMON_TITLE_BUTTON_BACKGROUND_REGIONS[state]
		or COMMON_TITLE_BUTTON_BACKGROUND_REGIONS.normal
	setCommonTitleButtonTextureRegion(skin.background, region, 0)
	local visualSize = layoutTitleButtonBackground(button, skin.background)

	local pressed = state == BUTTON_VISUAL_STATE.PRESSED
	local offsetX = pressed
		and (GF.COMMON_TITLE_BUTTON_PRESSED_OFFSET_X or 1) or 0
	local offsetY = pressed
		and (GF.COMMON_TITLE_BUTTON_PRESSED_OFFSET_Y or -1) or 0
	offsetX = offsetX + (tonumber(skin.iconOffsetX) or 0)
	offsetY = offsetY + (tonumber(skin.iconOffsetY) or 0)
	local scale = tonumber(skin.iconScale) or 1
	local glyphWidth = tonumber(skin.iconWidth)
		or math.max(1, visualSize * scale * (skin.iconAspectRatio or 1))
	local glyphHeight = tonumber(skin.iconHeight)
		or math.max(1, visualSize * scale)
	skin.glyph:ClearAllPoints()
	skin.glyph:SetSize(glyphWidth, glyphHeight)
	skin.glyph:SetPoint("CENTER", button, "CENTER", offsetX, offsetY)
	local glyphAlpha = state == BUTTON_VISUAL_STATE.DISABLED
		and (skin.disabledGlyphAlpha or GF.COMMON_TITLE_BUTTON_DISABLED_GLYPH_ALPHA or 0.5) or 1
	if skin.shadow and skin.iconShadow then
		local shadow = skin.iconShadow
		local shadowScale = glyphHeight / (tonumber(shadow.referenceHeight) or glyphHeight)
		local spread = (tonumber(shadow.spread) or 0) * shadowScale
		skin.shadow:ClearAllPoints()
		skin.shadow:SetSize(glyphWidth + spread, glyphHeight + spread)
		skin.shadow:SetPoint("CENTER", button, "CENTER",
			offsetX + (tonumber(shadow.offsetX) or 0) * shadowScale,
			offsetY + (tonumber(shadow.offsetY) or 0) * shadowScale)
	end
	skin.glow:ClearAllPoints()
	local glowScale = tonumber(skin.hoverGlowScale) or 1
	skin.glow:SetSize(glyphWidth * glowScale, glyphHeight * glowScale)
	skin.glow:SetPoint("CENTER", button, "CENTER", offsetX, offsetY)
	local glowAlpha = state == BUTTON_VISUAL_STATE.HOVER
			and (skin.hoverGlowAlpha
				or GF.COMMON_TITLE_BUTTON_HOVER_GLOW_ALPHA
				or 0)
			or 0
	local values = { glyphAlpha, glowAlpha }
	local hoverStyle = skin.iconHoverStyle
	if hoverStyle then
		local hovered = state == BUTTON_VISUAL_STATE.HOVER
		local color = state == BUTTON_VISUAL_STATE.DISABLED and hoverStyle.disabledColor
			or (hovered or pressed) and hoverStyle.hoverColor or hoverStyle.normalColor
		values[3], values[4], values[5] = color[1], color[2], color[3]
	end
	if skin.transitionDuration > 0 or skin.fade then
		skin.fade = skin.fade or createTitleButtonFade(button, skin)
		skin.fade:Set(state, values, immediate)
	else
		paintTitleButtonValues(skin, values)
	end
	button._gfCommonTitleButtonState = state
end

local function updateCommonTitleButtonVisual(button)
	applyCommonTitleButtonVisual(button)
end

local function setTitleActionIconTexCoords(texture, texCoords)
	if not texture then
		return
	end
	if type(texCoords) == "table" and texCoords[8] ~= nil then
		texture:SetTexCoord(
			texCoords[1], texCoords[2],
			texCoords[3], texCoords[4],
			texCoords[5], texCoords[6],
			texCoords[7], texCoords[8])
	elseif type(texCoords) == "table" and texCoords[4] ~= nil then
		texture:SetTexCoord(
			texCoords[1], texCoords[2], texCoords[3], texCoords[4])
	else
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

local function installCommonTitleButtonStateHooks(button)
	if button._gfCommonTitleButtonStateHooks then
		return
	end
	button._gfCommonTitleButtonStateHooks = true
	local function hook(scriptName, handler)
		if button.HookScript then
			pcall(button.HookScript, button, scriptName, handler)
		end
	end
	hook("OnEnter", function(self)
		self._gfCommonTitleButtonHovered = true
		local stillPressed = self._gfCommonTitleButtonMouseDown == true
			and IsMouseButtonDown
			and IsMouseButtonDown("LeftButton")
		self._gfCommonTitleButtonPressed = stillPressed and true or nil
		if not stillPressed then
			self._gfCommonTitleButtonMouseDown = nil
		end
		updateCommonTitleButtonVisual(self)
	end)
	hook("OnLeave", function(self)
		self._gfCommonTitleButtonHovered = nil
		updateCommonTitleButtonVisual(self)
	end)
	hook("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton"
			and (not self.IsEnabled or self:IsEnabled())
		then
			self._gfCommonTitleButtonMouseDown = true
			self._gfCommonTitleButtonPressed = true
			updateCommonTitleButtonVisual(self)
		end
	end)
	hook("OnMouseUp", function(self, mouseButton)
		if mouseButton == "LeftButton" then
			self._gfCommonTitleButtonMouseDown = nil
			self._gfCommonTitleButtonPressed = nil
			updateCommonTitleButtonVisual(self)
		end
	end)
	hook("OnEnable", updateCommonTitleButtonVisual)
	hook("OnDisable", function(self)
		self._gfCommonTitleButtonMouseDown = nil
		self._gfCommonTitleButtonPressed = nil
		updateCommonTitleButtonVisual(self)
	end)
	hook("OnSizeChanged", updateCommonTitleButtonVisual)
	hook("OnShow", function(self)
		local hovered = false
		if self.IsMouseMotionFocus then
			local ok, value = pcall(self.IsMouseMotionFocus, self)
			hovered = ok and value == true
		end
		self._gfCommonTitleButtonHovered = hovered and true or nil
		self._gfCommonTitleButtonMouseDown = nil
		self._gfCommonTitleButtonPressed = nil
		applyCommonTitleButtonVisual(self, nil, true)
	end)
	hook("OnHide", function(self)
		self._gfCommonTitleButtonHovered = nil
		self._gfCommonTitleButtonMouseDown = nil
		self._gfCommonTitleButtonPressed = nil
		applyCommonTitleButtonVisual(self, nil, true)
	end)
end

function GF.UI.ApplyCommonTitleActionButtonSkin(button, options)
	if not button then
		return nil
	end
	options = type(options) == "table" and options or {}
	clearButtonStateTexture(button, "Normal")
	clearButtonStateTexture(button, "Pushed")
	clearButtonStateTexture(button, "Highlight")
	clearButtonStateTexture(button, "Disabled")

	local skin = button._gfCommonTitleButtonSkin
	if not skin then
		skin = {
			background = button:CreateTexture(nil, "ARTWORK", nil, -2),
			glyph = options.glyph or button:CreateTexture(nil, "ARTWORK", nil, 0),
			glow = button:CreateTexture(nil, "OVERLAY", nil, 1),
		}
		button._gfCommonTitleButtonSkin = skin
	end
	skin.background:SetBlendMode("BLEND")
	skin.background:SetVertexColor(1, 1, 1, 1)
	skin.background:SetAlpha(1)
	skin.background:Show()

	skin.externalGlyph = options.glyph ~= nil
	-- Some actions remain clickable while unavailable to explain the restriction.
	skin.isDisabled = type(options.isDisabled) == "function" and options.isDisabled or nil
	skin.visualSize = tonumber(options.visualSize)
	skin.transitionDuration = tonumber(options.transitionDuration) or 0
	skin.disabledGlyphAlpha = tonumber(options.disabledGlyphAlpha)
	skin.iconScale = tonumber(options.iconScale)
		or GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_SCALE
		or 0.62
	skin.iconAspectRatio = tonumber(options.iconAspectRatio) or 1
	skin.iconWidth = tonumber(options.iconWidth)
	skin.iconHeight = tonumber(options.iconHeight)
	skin.iconOffsetX = tonumber(options.iconOffsetX) or 0
	skin.iconOffsetY = tonumber(options.iconOffsetY) or 0
	-- Opt-in glyph feedback shares the existing fade driver and input lifecycle.
	skin.iconHoverStyle = type(options.iconHoverStyle) == "table" and options.iconHoverStyle or nil
	skin.hoverGlowAlpha = tonumber(options.hoverGlowAlpha)
	skin.hoverGlowScale = tonumber(options.hoverGlowScale) or 1
	skin.hoverGlowDesaturated = options.hoverGlowDesaturated == true
	skin.iconShadow = type(options.iconShadow) == "table" and options.iconShadow or nil
	if skin.iconShadow then
		skin.shadow = skin.shadow or button:CreateTexture(nil, "ARTWORK", nil, -1)
		skin.shadow:SetBlendMode("BLEND")
		skin.shadow:SetVertexColor(0, 0, 0, 1)
		skin.shadow:Show()
	elseif skin.shadow then
		skin.shadow:Hide()
	end
	for _, texture in ipairs({ skin.glyph, skin.glow, skin.shadow }) do
		if texture.SetSnapToPixelGrid then
			texture:SetSnapToPixelGrid(false)
			texture:SetTexelSnappingBias(0)
		end
		if skin.externalGlyph then
			-- Caller-owned glyphs retain their native atlas, rotation and tint.
		elseif options.iconTexture then
			texture:SetTexture(options.iconTexture)
			setTitleActionIconTexCoords(texture, options.iconTexCoords)
		else
			setCommonTitleButtonTextureRegion(texture,
				options.glyphRegion or COMMON_TITLE_BUTTON_CLOSE_GLYPH_REGION, 0)
		end
	end
	if skin.background.SetSnapToPixelGrid then
		skin.background:SetSnapToPixelGrid(false)
		skin.background:SetTexelSnappingBias(0)
	end
	if not skin.externalGlyph then
		skin.glyph:SetBlendMode("BLEND")
		skin.glyph:SetVertexColor(1, 1, 1, 1)
	end
	skin.glyph:Show()
	skin.glow:SetBlendMode("ADD")
	skin.glow:SetVertexColor(1, 1, 1, 1)
	if skin.glow.SetDesaturated then
		skin.glow:SetDesaturated(skin.hoverGlowDesaturated)
	end
	skin.glow:Show()
	installCommonTitleButtonStateHooks(button)
	updateCommonTitleButtonVisual(button)
	return skin
end

function GF.UI.ApplyCommonCloseButtonSkin(button)
	return GF.UI.ApplyCommonTitleActionButtonSkin(button, {
		glyphRegion = COMMON_TITLE_BUTTON_CLOSE_GLYPH_REGION,
		iconScale = GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_SCALE or 0.62,
		iconOffsetX = GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_OFFSET_X or 0,
		iconOffsetY = GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_OFFSET_Y or 0,
		hoverGlowAlpha = GF.COMMON_TITLE_BUTTON_CLOSE_HOVER_GLOW_ALPHA or 0,
		hoverGlowScale = GF.COMMON_TITLE_BUTTON_CLOSE_HOVER_GLOW_SCALE or 1,
		hoverGlowDesaturated =
			GF.COMMON_TITLE_BUTTON_CLOSE_HOVER_GLOW_DESATURATED == true,
	})
end

function GF.UI.RefreshCommonTitleActionButtonSkin(button)
	updateCommonTitleButtonVisual(button)
end

-- Square action controls share the close button's renderer and input lifecycle.
-- The caller owns only the glyph and business scripts, never a second skin.
function GF.UI.ApplyCommonSmallButtonSkin(button, glyph, options)
	options = type(options) == "table" and options or {}
	options.glyph = glyph
	options.iconWidth = options.iconWidth or GF.COMMON_BUTTON_STYLE.iconSize
	options.iconHeight = options.iconHeight or GF.COMMON_BUTTON_STYLE.iconSize
	options.hoverGlowAlpha = 0
	options.transitionDuration = options.transitionDuration
		or GF.COMMON_SMALL_BUTTON_FADE_DURATION or 0.16
	local skin = GF.UI.ApplyCommonTitleActionButtonSkin(button, options)
	button:SetMotionScriptsWhileDisabled(true)
	button._gfCommonSmallButton = true
	return skin
end

-- Navigation owns its row state and projects it onto a mouse-transparent skin.
function GF.UI.SetCommonSmallButtonVisualState(button, state)
	applyCommonTitleButtonVisual(button, state)
end
