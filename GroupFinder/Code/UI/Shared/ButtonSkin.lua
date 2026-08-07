local _, GF = ...

GF.UI = GF.UI or {}

-- 共享红色按钮、表头刷新图标与四态皮肤。

local COMMON_BUTTON_PATH = GF.COMMON_BUTTON_TEXTURE
local COMMON_BUTTON_ATLAS_W = GF.COMMON_BUTTON_ATLAS_WIDTH
local COMMON_BUTTON_ATLAS_H = GF.COMMON_BUTTON_ATLAS_HEIGHT
local COMMON_BUTTON_WIDE_REGIONS = GF.COMMON_BUTTON_WIDE_REGIONS or {}
local COMMON_BUTTON_SQUARE_REGIONS = GF.COMMON_BUTTON_SQUARE_REGIONS or {}
local BUTTON_VISUAL_STATE = GF.BUTTON_VISUAL_STATE
local COMMON_BUTTON_VISUALS = GF.COMMON_BUTTON_VISUALS
local HEADER_REFRESH_ICON_VISUALS = GF.HEADER_REFRESH_ICON_VISUALS
local COMMON_BUTTON_CAP_SOURCE_W = 24
local COMMON_BUTTON_CAP_DISPLAY_W = 12
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

local function getCommonPanelButtonSlice(button)
	local w = button and button.GetWidth and button:GetWidth() or 0
	if w > 0 and w <= 30 then
		return "square"
	end
	if w > 0 and w <= ((GF.PANEL_BUTTON_TWO_CHAR_W or 72) + 1) then
		return "medium"
	end
	return "wide"
end

local function getCommonButtonVisual(state)
	return COMMON_BUTTON_VISUALS[state]
		or COMMON_BUTTON_VISUALS[BUTTON_VISUAL_STATE.NORMAL]
end

local function getCommonButtonRegion(visualState, square)
	local visual = getCommonButtonVisual(visualState)
	local regions = square and COMMON_BUTTON_SQUARE_REGIONS
		or COMMON_BUTTON_WIDE_REGIONS
	return regions[visual.atlasState] or regions.normal
end

local function setCommonButtonTexCoord(texture, visualState, square)
	local region = getCommonButtonRegion(visualState, square)
	if not (texture and region) then
		return
	end
	texture:SetTexCoord(
		region[1] / COMMON_BUTTON_ATLAS_W,
		(region[1] + region[3]) / COMMON_BUTTON_ATLAS_W,
		region[2] / COMMON_BUTTON_ATLAS_H,
		(region[2] + region[4]) / COMMON_BUTTON_ATLAS_H)
end

local function setCommonButtonPieceTexCoord(texture, visualState, _slice, piece)
	if not texture then
		return
	end
	local region = getCommonButtonRegion(visualState, false)
	if not region then
		return
	end
	local left = region[1]
	local right = region[1] + region[3]
	local top = region[2]
	local bottom = region[2] + region[4]
	local sourceW = math.max(1, right - left)
	local capW = math.min(COMMON_BUTTON_CAP_SOURCE_W, math.floor(sourceW / 2))
	if piece == "left" then
		right = left + capW
	elseif piece == "right" then
		left = right - capW
	elseif piece == "middle" then
		left = left + capW
		right = right - capW
		if right <= left then
			left = region[1]
			right = region[1] + region[3]
		end
	end
	texture:SetTexCoord(
		left / COMMON_BUTTON_ATLAS_W,
		right / COMMON_BUTTON_ATLAS_W,
		top / COMMON_BUTTON_ATLAS_H,
		bottom / COMMON_BUTTON_ATLAS_H
	)
end

function GF.UI.GetCommonButtonVisual(state)
	return getCommonButtonVisual(state)
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
	glow:SetTexture(GF.BROWSE_HEADER_REFRESH_TEXTURE or GF.REFRESH_TEXTURE)
	local texCoord = GF.REFRESH_TEXTURE_TEXCOORD
	if texCoord then
		glow:SetTexCoord(
			texCoord[1],
			texCoord[2],
			texCoord[3],
			texCoord[4]
		)
	else
		glow:SetTexCoord(0, 1, 0, 1)
	end
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
	local size = visual.size or GF.BROWSE_HEADER_REFRESH_ICON_SIZE or 21

	icon:ClearAllPoints()
	icon:SetSize(size, size)
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

function GF.UI.SetCommonButtonTextureState(texture, state, slice)
	if not texture then
		return false
	end
	texture:SetTexture(COMMON_BUTTON_PATH)
	setCommonButtonTexCoord(texture, state, slice == "square")
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

local function setupCommonPanelButtonBackground(button, slice)
	if not button then
		return nil
	end
	slice = slice or getCommonPanelButtonSlice(button)
	local buttonW = button.GetWidth and button:GetWidth() or 0
	if slice ~= "square" and buttonW > 0 then
		if button._gfCommonButtonBg then
			button._gfCommonButtonBg:Hide()
		end
		local capW = math.min(COMMON_BUTTON_CAP_DISPLAY_W, math.floor(buttonW / 2))
		local middleW = math.max(1, buttonW - (capW * 2))
		local left = button._gfCommonButtonLeft
		if not left then
			left = button:CreateTexture(nil, "BACKGROUND")
			button._gfCommonButtonLeft = left
		end
		local middle = button._gfCommonButtonMiddle
		if not middle then
			middle = button:CreateTexture(nil, "BACKGROUND")
			button._gfCommonButtonMiddle = middle
		end
		local right = button._gfCommonButtonRight
		if not right then
			right = button:CreateTexture(nil, "BACKGROUND")
			button._gfCommonButtonRight = right
		end
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT")
		left:SetPoint("BOTTOMLEFT")
		left:SetWidth(capW)
		middle:ClearAllPoints()
		middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
		middle:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, 0)
		middle:SetWidth(middleW)
		right:ClearAllPoints()
		right:SetPoint("TOPLEFT", middle, "TOPRIGHT", 0, 0)
		right:SetPoint("BOTTOMRIGHT")
		right:SetWidth(capW)
		for _, tex in ipairs({ left, middle, right }) do
			tex:SetTexture(COMMON_BUTTON_PATH)
			if tex.SetBlendMode then
				tex:SetBlendMode("BLEND")
			end
			if tex.SetDrawLayer then
				tex:SetDrawLayer("BACKGROUND", 0)
			end
			tex:SetVertexColor(1, 1, 1, 1)
			if tex.SetDesaturated then
				tex:SetDesaturated(false)
			end
			tex:SetAlpha(1)
			tex:Show()
		end
		setCommonButtonPieceTexCoord(left, BUTTON_VISUAL_STATE.NORMAL, slice, "left")
		setCommonButtonPieceTexCoord(middle, BUTTON_VISUAL_STATE.NORMAL, slice, "middle")
		setCommonButtonPieceTexCoord(right, BUTTON_VISUAL_STATE.NORMAL, slice, "right")
		return middle
	end
	if button._gfCommonButtonLeft then
		button._gfCommonButtonLeft:Hide()
	end
	if button._gfCommonButtonMiddle then
		button._gfCommonButtonMiddle:Hide()
	end
	if button._gfCommonButtonRight then
		button._gfCommonButtonRight:Hide()
	end
	local tex = button._gfCommonButtonBg
	if not tex then
		tex = button:CreateTexture(nil, "BACKGROUND")
		button._gfCommonButtonBg = tex
	end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT")
	tex:SetPoint("BOTTOMRIGHT")
	tex:SetTexture(COMMON_BUTTON_PATH)
	setCommonButtonTexCoord(tex, BUTTON_VISUAL_STATE.NORMAL, true)
	if tex.SetBlendMode then
		tex:SetBlendMode("BLEND")
	end
	if tex.SetDrawLayer then
		tex:SetDrawLayer("BACKGROUND", 0)
	end
	tex:SetVertexColor(1, 1, 1, 1)
	if tex.SetDesaturated then
		tex:SetDesaturated(false)
	end
	tex:SetAlpha(1)
	tex:Show()
	return tex
end

local function applyCommonPanelButtonVisualState(button, state)
	if not button then
		return
	end
	local visual = getCommonButtonVisual(state)
	local textureAlpha = visual.textureColor[4]
	if state == BUTTON_VISUAL_STATE.DISABLED
		and button._gfCommonButtonPreserveDisabledAlpha
	then
		textureAlpha = 1
	end
	local slice = getCommonPanelButtonSlice(button)
	setupCommonPanelButtonBackground(button, slice)
	button._gfCommonButtonSlice = slice
	if slice ~= "square" and button._gfCommonButtonLeft and button._gfCommonButtonMiddle and button._gfCommonButtonRight then
		local pieces = {
			{ button._gfCommonButtonLeft, "left" },
			{ button._gfCommonButtonMiddle, "middle" },
			{ button._gfCommonButtonRight, "right" },
		}
		for _, info in ipairs(pieces) do
			local tex, piece = info[1], info[2]
			setCommonButtonPieceTexCoord(tex, state, slice, piece)
			if tex.SetDesaturated then
				tex:SetDesaturated(visual.desaturated == true)
			end
			tex:SetVertexColor(
				visual.textureColor[1],
				visual.textureColor[2],
				visual.textureColor[3],
				textureAlpha)
			tex:SetAlpha(1)
			tex:Show()
		end
		return
	end
	local bg = button._gfCommonButtonBg
	if bg then
		setCommonButtonTexCoord(bg, state, slice == "square")
		if bg.SetDesaturated then
			bg:SetDesaturated(visual.desaturated == true)
		end
		bg:SetVertexColor(
			visual.textureColor[1],
			visual.textureColor[2],
			visual.textureColor[3],
			textureAlpha)
		bg:SetAlpha(1)
		bg:Show()
	end
end

local function getCommonPanelButtonLabel(button)
	if not button then
		return nil
	end
	return button._gfCommonButtonLabel
		or (button.GetFontString and button:GetFontString())
end

local function setCommonPanelButtonTextColor(button, state)
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
	local visual = getCommonButtonVisual(state)
	local color = visual.textColor
	fs:SetTextColor(color[1], color[2], color[3], color[4])
	if button._gfCommonButtonLabel == fs then
		local offset = visual.textOffset
		fs:ClearAllPoints()
		fs:SetPoint("CENTER", button, "CENTER", offset[1], offset[2])
	end
end

local function updateCommonPanelButtonTextState(button)
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
	setCommonPanelButtonTextColor(button, visualState)
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
	hook("OnEnable", updateCommonPanelButtonTextState)
	hook("OnDisable", updateCommonPanelButtonTextState)
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
	local slice = getCommonPanelButtonSlice(button)
	local bg = setupCommonPanelButtonBackground(button, slice)
	button._gfCommonButtonSlice = slice
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

local function setCommonTitleButtonTextureRegion(texture, region)
	if not (texture and region) then
		return false
	end
	local atlasWidth = GF.COMMON_ATLAS_WIDTH or 512
	local atlasHeight = GF.COMMON_ATLAS_HEIGHT or 256
	local inset = 0.5
	texture:SetTexture(COMMON_TITLE_BUTTON_TEXTURE)
	texture:SetTexCoord(
		(region[1] + inset) / atlasWidth,
		(region[1] + region[3] - inset) / atlasWidth,
		(region[2] + inset) / atlasHeight,
		(region[2] + region[4] - inset) / atlasHeight)
	return true
end

local function getCommonTitleButtonState(button)
	if button.IsEnabled and not button:IsEnabled() then
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

local function updateCommonTitleButtonVisual(button)
	local skin = button and button._gfCommonTitleButtonSkin
	if not skin then
		return
	end
	local state = getCommonTitleButtonState(button)
	local region = COMMON_TITLE_BUTTON_BACKGROUND_REGIONS[state]
		or COMMON_TITLE_BUTTON_BACKGROUND_REGIONS.normal
	setCommonTitleButtonTextureRegion(skin.background, region)

	local pressed = state == BUTTON_VISUAL_STATE.PRESSED
	local offsetX = pressed
		and (GF.COMMON_TITLE_BUTTON_PRESSED_OFFSET_X or 1) or 0
	local offsetY = pressed
		and (GF.COMMON_TITLE_BUTTON_PRESSED_OFFSET_Y or -1) or 0
	offsetX = offsetX + (tonumber(skin.iconOffsetX) or 0)
	offsetY = offsetY + (tonumber(skin.iconOffsetY) or 0)
	local width = button.GetWidth and button:GetWidth() or 24
	local height = button.GetHeight and button:GetHeight() or 24
	local scale = tonumber(skin.iconScale) or 1
	local glyphWidth = math.max(1, width * scale)
	local glyphHeight = math.max(1, height * scale)
	skin.glyph:ClearAllPoints()
	skin.glyph:SetSize(glyphWidth, glyphHeight)
	skin.glyph:SetPoint("CENTER", button, "CENTER", offsetX, offsetY)
	skin.glyph:SetAlpha(
		state == BUTTON_VISUAL_STATE.DISABLED
			and (GF.COMMON_TITLE_BUTTON_DISABLED_GLYPH_ALPHA or 0.5)
			or 1)
	skin.glow:ClearAllPoints()
	local glowScale = tonumber(skin.hoverGlowScale) or 1
	skin.glow:SetSize(glyphWidth * glowScale, glyphHeight * glowScale)
	skin.glow:SetPoint("CENTER", button, "CENTER", offsetX, offsetY)
	skin.glow:SetAlpha(
		state == BUTTON_VISUAL_STATE.HOVER
			and (skin.hoverGlowAlpha
				or GF.COMMON_TITLE_BUTTON_HOVER_GLOW_ALPHA
				or 0.4)
			or 0)
	button._gfCommonTitleButtonState = state
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
		self._gfCommonTitleButtonPressed = nil
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
	hook("OnDisable", updateCommonTitleButtonVisual)
	hook("OnShow", function(self)
		local hovered = false
		if self.IsMouseMotionFocus then
			local ok, value = pcall(self.IsMouseMotionFocus, self)
			hovered = ok and value == true
		end
		self._gfCommonTitleButtonHovered = hovered and true or nil
		self._gfCommonTitleButtonMouseDown = nil
		self._gfCommonTitleButtonPressed = nil
		updateCommonTitleButtonVisual(self)
	end)
	hook("OnHide", function(self)
		self._gfCommonTitleButtonHovered = nil
		self._gfCommonTitleButtonMouseDown = nil
		self._gfCommonTitleButtonPressed = nil
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
			glyph = button:CreateTexture(nil, "ARTWORK", nil, -1),
			glow = button:CreateTexture(nil, "OVERLAY", nil, 1),
		}
		button._gfCommonTitleButtonSkin = skin
	end
	skin.background:ClearAllPoints()
	local buttonWidth = button.GetWidth and button:GetWidth() or 24
	local buttonHeight = button.GetHeight and button:GetHeight() or 24
	local visualSize = math.min(
		buttonWidth,
		buttonHeight,
		GF.COMMON_TITLE_BUTTON_VISUAL_SIZE or 22)
	skin.background:SetSize(visualSize, visualSize)
	skin.background:SetPoint("CENTER", button, "CENTER", 0, 0)
	skin.background:SetBlendMode("BLEND")
	skin.background:SetVertexColor(1, 1, 1, 1)
	skin.background:SetAlpha(1)
	skin.background:Show()

	skin.iconScale = tonumber(options.iconScale)
		or GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_SCALE
		or 0.632
	skin.iconOffsetX = tonumber(options.iconOffsetX) or 0
	skin.iconOffsetY = tonumber(options.iconOffsetY) or 0
	skin.hoverGlowAlpha = tonumber(options.hoverGlowAlpha)
	skin.hoverGlowScale = tonumber(options.hoverGlowScale) or 1
	skin.hoverGlowDesaturated = options.hoverGlowDesaturated == true
	if options.iconTexture then
		skin.glyph:SetTexture(options.iconTexture)
		skin.glyph:SetTexCoord(0, 1, 0, 1)
		skin.glow:SetTexture(options.iconTexture)
		skin.glow:SetTexCoord(0, 1, 0, 1)
	else
		setCommonTitleButtonTextureRegion(
			skin.glyph,
			options.glyphRegion
				or COMMON_TITLE_BUTTON_CLOSE_GLYPH_REGION)
		setCommonTitleButtonTextureRegion(
			skin.glow,
			options.glyphRegion
				or COMMON_TITLE_BUTTON_CLOSE_GLYPH_REGION)
	end
	skin.glyph:SetBlendMode("BLEND")
	skin.glyph:SetVertexColor(1, 1, 1, 1)
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
		iconScale = GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_SCALE or 0.632,
		iconOffsetX = GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_OFFSET_X or 0.1,
		iconOffsetY = GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_OFFSET_Y or 0.9,
		hoverGlowAlpha = GF.COMMON_TITLE_BUTTON_CLOSE_HOVER_GLOW_ALPHA or 0.4,
		hoverGlowScale = GF.COMMON_TITLE_BUTTON_CLOSE_HOVER_GLOW_SCALE or 1,
		hoverGlowDesaturated =
			GF.COMMON_TITLE_BUTTON_CLOSE_HOVER_GLOW_DESATURATED == true,
	})
end

function GF.UI.RefreshCommonTitleActionButtonSkin(button)
	updateCommonTitleButtonVisual(button)
end
