local _, GF = ...

GF.UI = GF.UI or {}

-- 共享红色按钮、表头刷新图标与四态皮肤。

local COMMON_BUTTON_PATH = GF.COMMON_BUTTON_TEXTURE
local COMMON_BUTTON_ATLAS_W = GF.COMMON_BUTTON_ATLAS_WIDTH
local COMMON_BUTTON_ATLAS_H = GF.COMMON_BUTTON_ATLAS_HEIGHT
local COMMON_BUTTON_SLICES = GF.COMMON_BUTTON_SLICE_COORDS
local COMMON_BUTTON_STATES = GF.COMMON_BUTTON_STATE_COORDS
local BUTTON_VISUAL_STATE = GF.BUTTON_VISUAL_STATE
local COMMON_BUTTON_VISUALS = GF.COMMON_BUTTON_VISUALS
local HEADER_REFRESH_ICON_VISUALS = GF.HEADER_REFRESH_ICON_VISUALS
local COMMON_BUTTON_CAP_SOURCE_W = 24
local COMMON_BUTTON_CAP_DISPLAY_W = 12
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

local function setCommonButtonTexCoord(texture, visualState, slice)
	local visual = getCommonButtonVisual(visualState)
	local s = COMMON_BUTTON_STATES[visual.atlasState] or COMMON_BUTTON_STATES.normal
	local x = COMMON_BUTTON_SLICES[slice] or COMMON_BUTTON_SLICES.wide
	texture:SetTexCoord(x[1], x[2], s[1], s[2])
end

local function setCommonButtonPieceTexCoord(texture, visualState, slice, piece)
	if not texture then
		return
	end
	local visual = getCommonButtonVisual(visualState)
	local s = COMMON_BUTTON_STATES[visual.atlasState] or COMMON_BUTTON_STATES.normal
	local x = COMMON_BUTTON_SLICES[slice] or COMMON_BUTTON_SLICES.wide
	local left = x[1] * COMMON_BUTTON_ATLAS_W
	local right = x[2] * COMMON_BUTTON_ATLAS_W
	local top = s[1] * COMMON_BUTTON_ATLAS_H
	local bottom = s[2] * COMMON_BUTTON_ATLAS_H
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
			left = x[1] * COMMON_BUTTON_ATLAS_W
			right = x[2] * COMMON_BUTTON_ATLAS_W
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

function GF.UI.SetHeaderRefreshIconState(button, state, baseOffsetY)
	local icon = button and button.Icon
	if not icon then
		return
	end

	if baseOffsetY ~= nil then
		button._gfHeaderRefreshIconBaseOffsetY = tonumber(baseOffsetY) or 0
	end
	baseOffsetY = button._gfHeaderRefreshIconBaseOffsetY or 0

	state = state or BUTTON_VISUAL_STATE.NORMAL
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
end

function GF.UI.SetCommonButtonTextureState(texture, state, slice)
	if not texture then
		return false
	end
	texture:SetTexture(COMMON_BUTTON_PATH)
	setCommonButtonTexCoord(texture, state, slice or "wide")
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
	setCommonButtonTexCoord(tex, BUTTON_VISUAL_STATE.NORMAL, slice)
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
		setCommonButtonTexCoord(bg, state, slice)
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
