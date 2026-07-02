local ADDON_NAME, GF = ...

GF.UI = {}

GF.UI.TOOLTIP_GOLD_R = 1
GF.UI.TOOLTIP_GOLD_G = 0.82
GF.UI.TOOLTIP_GOLD_B = 0

local WHITE = "Interface\\Buttons\\WHITE8X8"
local COMMON_BUTTON_PATH = GF.COMMON_BUTTON_TEXTURE or ("Interface\\AddOns\\" .. (ADDON_NAME or "GroupFinder") .. "\\Art\\UI\\RedButton.png")
local COMMON_BUTTON_ATLAS_W = 392
local COMMON_BUTTON_ATLAS_H = 168
local COMMON_BUTTON_SLICES = {
	medium = { 0, 144 / COMMON_BUTTON_ATLAS_W },
	wide = { 156 / COMMON_BUTTON_ATLAS_W, 332 / COMMON_BUTTON_ATLAS_W },
	square = { 344 / COMMON_BUTTON_ATLAS_W, 392 / COMMON_BUTTON_ATLAS_W },
}
local COMMON_BUTTON_STATES = {
	normal = { 0, 48 / COMMON_BUTTON_ATLAS_H },
	highlight = { 60 / COMMON_BUTTON_ATLAS_H, 108 / COMMON_BUTTON_ATLAS_H },
	pressed = { 120 / COMMON_BUTTON_ATLAS_H, 168 / COMMON_BUTTON_ATLAS_H },
}
local COMMON_BUTTON_CAP_SOURCE_W = 24
local COMMON_BUTTON_CAP_DISPLAY_W = 12
local COMMON_BUTTON_TEXT_COLOR = {
	normal = { 1, 0.82, 0, 1 },
	hover = { 1, 0.95, 0.45, 1 },
	pressed = { 1, 0.68, 0.12, 1 },
	disabled = { 0.55, 0.55, 0.55, 1 },
}
local COMMON_BUTTON_DISABLED_VERTEX = { 0.55, 0.55, 0.55, 0.82 }
local FILTER_CHECK_ATLAS_TEXTURE = GF.FILTER_CHECK_ATLAS_TEXTURE or ("Interface\\AddOns\\" .. (ADDON_NAME or "GroupFinder") .. "\\Art\\UI\\FilterCheckAtlas.png")
local FILTER_CHECK_ATLAS_INSET_X = 0.5 / 128
local FILTER_CHECK_ATLAS_INSET_Y = 0.5 / 64
local FILTER_CHECK_ATLAS_COORDS = {
	checked = {
		FILTER_CHECK_ATLAS_INSET_X,
		0.5 - FILTER_CHECK_ATLAS_INSET_X,
		FILTER_CHECK_ATLAS_INSET_Y,
		1 - FILTER_CHECK_ATLAS_INSET_Y,
	},
	normal = {
		0.5 + FILTER_CHECK_ATLAS_INSET_X,
		1 - FILTER_CHECK_ATLAS_INSET_X,
		FILTER_CHECK_ATLAS_INSET_Y,
		1 - FILTER_CHECK_ATLAS_INSET_Y,
	},
}
FILTER_CHECK_ATLAS_COORDS.hover = FILTER_CHECK_ATLAS_COORDS.checked
local OPTIONS_TAB_ATLASES = {
	up = {
		left = "Options_Tab_Left",
		middle = "Options_Tab_Middle",
		right = "Options_Tab_Right",
	},
	selected = {
		left = "Options_Tab_Active_Left",
		middle = "Options_Tab_Active_Middle",
		right = "Options_Tab_Active_Right",
	},
}

local function paint(texture, r, g, b, a)
	if not texture then
		return
	end
	if texture.SetColorTexture then
		texture:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
	else
		texture:SetTexture(WHITE)
		texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	end
end

local function createFrameWithTemplateOptions(frameType, name, parent, templates)
	for _, template in ipairs(templates or {}) do
		local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
		if ok and frame then
			return frame, template
		end
	end
	return CreateFrame(frameType, name, parent), nil
end

function GF.UI.CreateFrameWithTemplateOptions(frameType, name, parent, templates)
	return createFrameWithTemplateOptions(frameType, name, parent, templates)
end

local function trySetAtlas(texture, atlas, useAtlasSize)
	if not texture or not texture.SetAtlas then
		return false
	end
	local ok = pcall(texture.SetAtlas, texture, atlas, useAtlasSize)
	return ok == true
end

function GF.UI.TrySetAtlas(texture, atlas, useAtlasSize)
	return trySetAtlas(texture, atlas, useAtlasSize)
end

local UI_SOUND_BY_KIND = {
	open = "IG_CHARACTER_INFO_OPEN",
	close = "IG_CHARACTER_INFO_CLOSE",
	tab = "IG_CHARACTER_INFO_TAB",
	check = "IG_MAINMENU_OPTION_CHECKBOX_ON",
}

function GF.UI.PlayUISound(kind)
	if not PlaySound then
		return
	end
	local key = UI_SOUND_BY_KIND[kind or ""]
	local sound = key and _G.SOUNDKIT and _G.SOUNDKIT[key]
	if sound then
		pcall(PlaySound, sound)
	end
end

local function snapCheckTexture(texture)
	if not texture then
		return
	end
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(true)
	end
	if texture.SetTexelSnappingBias then
		texture:SetTexelSnappingBias(0)
	end
end

local function hideCheckButtonRegion(region)
	if not region then
		return
	end
	if region.SetTexture then
		region:SetTexture(nil)
	end
	if region.Hide then
		region:Hide()
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
end

local function hideCheckButtonChrome(cb)
	hideCheckButtonRegion(cb.GetNormalTexture and cb:GetNormalTexture())
	hideCheckButtonRegion(cb.GetPushedTexture and cb:GetPushedTexture())
	hideCheckButtonRegion(cb.GetHighlightTexture and cb:GetHighlightTexture())
	hideCheckButtonRegion(cb.GetCheckedTexture and cb:GetCheckedTexture())
	hideCheckButtonRegion(cb.GetDisabledTexture and cb:GetDisabledTexture())
	hideCheckButtonRegion(cb.GetDisabledCheckedTexture and cb:GetDisabledCheckedTexture())
end

local function updateStyledFilterCheckButton(cb)
	if not cb or not cb._gfSharedFilterCheckStyled then
		return
	end
	hideCheckButtonChrome(cb)
	local enabled = not cb.IsEnabled or cb:IsEnabled()
	local checked = cb:GetChecked() == true or cb:GetChecked() == 1
	local coords = FILTER_CHECK_ATLAS_COORDS.normal
	if checked then
		coords = FILTER_CHECK_ATLAS_COORDS.checked
	elseif cb._gfSharedFilterCheckHovered then
		coords = FILTER_CHECK_ATLAS_COORDS.hover
	end
	if cb._gfSharedFilterCheckAtlas then
		cb._gfSharedFilterCheckAtlas:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		cb._gfSharedFilterCheckAtlas:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
	end
	if cb._gfSharedFilterCheckMark then
		cb._gfSharedFilterCheckMark:SetShown(checked)
		cb._gfSharedFilterCheckMark:SetVertexColor(1, 0.86, 0.28, enabled and 1 or 0.45)
	end
	if cb._gfSharedFilterCheckUpdateLabel then
		cb._gfSharedFilterCheckUpdateLabel(cb._gfSharedFilterCheckLabel, checked, enabled, cb)
	end
end

function GF.UI.UpdateFilterCheckButton(cb)
	updateStyledFilterCheckButton(cb)
end

function GF.UI.SetFilterCheckButtonHovered(cb, hovered)
	if not cb then
		return
	end
	cb._gfSharedFilterCheckHovered = hovered and true or false
	updateStyledFilterCheckButton(cb)
end

function GF.UI.StyleFilterCheckButton(cb, opts)
	if not cb then
		return cb
	end
	opts = opts or {}
	local size = opts.size or 20
	local markSize = opts.markSize or 16
	cb:SetSize(size, size)
	if cb.SetHitRectInsets then
		cb:SetHitRectInsets(0, 0, 0, 0)
	end
	hideCheckButtonChrome(cb)
	if not cb._gfSharedFilterCheckStyled then
		local atlas = cb:CreateTexture(nil, "BORDER", nil, -6)
		atlas:SetAllPoints(cb)
		atlas:SetTexture(FILTER_CHECK_ATLAS_TEXTURE)
		snapCheckTexture(atlas)
		cb._gfSharedFilterCheckAtlas = atlas

		local mark = cb:CreateTexture(nil, "ARTWORK")
		mark:SetPoint("CENTER", cb, "CENTER", 0, 0)
		mark:SetSize(markSize, markSize)
		mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		snapCheckTexture(mark)
		cb._gfSharedFilterCheckMark = mark

		cb._gfSharedFilterOrigSetChecked = cb.SetChecked
		cb.SetChecked = function(self, checked, ...)
			self:_gfSharedFilterOrigSetChecked(checked, ...)
			updateStyledFilterCheckButton(self)
		end
		cb:HookScript("OnClick", updateStyledFilterCheckButton)
		cb:HookScript("OnShow", updateStyledFilterCheckButton)
		cb:HookScript("OnEnable", updateStyledFilterCheckButton)
		cb:HookScript("OnDisable", updateStyledFilterCheckButton)
		cb:HookScript("OnEnter", function(self)
			self._gfSharedFilterCheckHovered = true
			updateStyledFilterCheckButton(self)
		end)
		cb:HookScript("OnLeave", function(self)
			self._gfSharedFilterCheckHovered = false
			updateStyledFilterCheckButton(self)
		end)
		cb._gfSharedFilterCheckStyled = true
	end
	cb._gfSharedFilterCheckLabel = opts.label
	cb._gfSharedFilterCheckUpdateLabel = opts.updateLabel
	updateStyledFilterCheckButton(cb)
	return cb
end

function GF.UI.CreateFilterCheckButton(parent, opts)
	opts = opts or {}
	local cb = CreateFrame("CheckButton", opts.name, parent)
	return GF.UI.StyleFilterCheckButton(cb, opts)
end

local function tryLoadQueueStatusFrameUI()
	if _G.EyeTemplateMixin then
		return true
	end
	if LoadAddOnWithErrorHandling then
		local ok = pcall(LoadAddOnWithErrorHandling, "Blizzard_QueueStatusFrame")
		if ok and _G.EyeTemplateMixin then
			return true
		end
	end
	if C_AddOns and C_AddOns.LoadAddOn then
		local ok = pcall(C_AddOns.LoadAddOn, "Blizzard_QueueStatusFrame")
		if ok and _G.EyeTemplateMixin then
			return true
		end
	end
	if UIParentLoadAddOn then
		local ok = pcall(UIParentLoadAddOn, "Blizzard_QueueStatusFrame")
		if ok and _G.EyeTemplateMixin then
			return true
		end
	end
	if LoadAddOn then
		local ok = pcall(LoadAddOn, "Blizzard_QueueStatusFrame")
		if ok and _G.EyeTemplateMixin then
			return true
		end
	end
	return _G.EyeTemplateMixin ~= nil
end

function GF.UI.TryLoadQueueStatusFrameUI()
	return tryLoadQueueStatusFrameUI()
end

local function getClassColor()
	local classTag = select(2, UnitClass("player"))
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	local color = colors and classTag and colors[classTag]
	if color then
		return color.r or 1, color.g or 0.82, color.b or 0
	end
	return 1, 0.82, 0
end

function GF.UI.GetClassColor()
	return getClassColor()
end

local function applySystemPanelTitleStyle(fontString)
	if not fontString then
		return
	end
	if fontString.SetFontObject and _G.GameFontNormal then
		fontString:SetFontObject(_G.GameFontNormal)
	end
	if fontString.SetTextColor and _G.NORMAL_FONT_COLOR and _G.NORMAL_FONT_COLOR.GetRGB then
		fontString:SetTextColor(_G.NORMAL_FONT_COLOR:GetRGB())
	elseif fontString.SetTextColor then
		fontString:SetTextColor(1, 0.82, 0, 1)
	end
end

local function centerSystemPanelTitle(frame, fontString)
	if not frame or not fontString then
		return
	end
	fontString:ClearAllPoints()
	fontString:SetPoint("TOP", frame, "TOP", 0, GF.MAIN_WINDOW_TITLE_OFFSET_Y or -6)
	fontString:SetJustifyH("CENTER")
end

local function resolveSystemPanelTitleText(frame)
	if not frame then
		return nil
	end
	return (frame.NineSlice and frame.NineSlice.Text)
		or frame.TitleText
		or (frame.TitleContainer and frame.TitleContainer.TitleText)
		or (frame.GetName and _G[(frame:GetName() or "") .. "TitleText"])
end

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

local function setCommonButtonTexCoord(texture, state, slice)
	local s = COMMON_BUTTON_STATES[state] or COMMON_BUTTON_STATES.normal
	local x = COMMON_BUTTON_SLICES[slice] or COMMON_BUTTON_SLICES.wide
	texture:SetTexCoord(x[1], x[2], s[1], s[2])
end

local function setCommonButtonPieceTexCoord(texture, state, slice, piece)
	if not texture then
		return
	end
	local s = COMMON_BUTTON_STATES[state] or COMMON_BUTTON_STATES.normal
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
		setCommonButtonPieceTexCoord(left, "normal", slice, "left")
		setCommonButtonPieceTexCoord(middle, "normal", slice, "middle")
		setCommonButtonPieceTexCoord(right, "normal", slice, "right")
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
	setCommonButtonTexCoord(tex, "normal", slice)
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

local function applyCommonPanelButtonVisualState(button, state, enabled)
	if not button then
		return
	end
	local slice = getCommonPanelButtonSlice(button)
	setupCommonPanelButtonBackground(button, slice)
	button._gfCommonButtonSlice = slice
	local disabled = enabled == false
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
				tex:SetDesaturated(disabled)
			end
			if disabled then
				tex:SetVertexColor(
					COMMON_BUTTON_DISABLED_VERTEX[1],
					COMMON_BUTTON_DISABLED_VERTEX[2],
					COMMON_BUTTON_DISABLED_VERTEX[3],
					COMMON_BUTTON_DISABLED_VERTEX[4]
				)
			else
				tex:SetVertexColor(1, 1, 1, 1)
			end
			tex:SetAlpha(1)
			tex:Show()
		end
		return
	end
	local bg = button._gfCommonButtonBg
	if bg then
		setCommonButtonTexCoord(bg, state, slice)
		if bg.SetDesaturated then
			bg:SetDesaturated(disabled)
		end
		if disabled then
			bg:SetVertexColor(
				COMMON_BUTTON_DISABLED_VERTEX[1],
				COMMON_BUTTON_DISABLED_VERTEX[2],
				COMMON_BUTTON_DISABLED_VERTEX[3],
				COMMON_BUTTON_DISABLED_VERTEX[4]
			)
		else
			bg:SetVertexColor(1, 1, 1, 1)
		end
		bg:SetAlpha(1)
		bg:Show()
	end
end

local function setCommonPanelButtonTextColor(button, state)
	if not button or not button.GetFontString then
		return
	end
	local fs = button:GetFontString()
	if not fs or not fs.SetTextColor then
		return
	end
	local color = COMMON_BUTTON_TEXT_COLOR[state or "normal"] or COMMON_BUTTON_TEXT_COLOR.normal
	fs:SetTextColor(color[1], color[2], color[3], color[4])
end

local function updateCommonPanelButtonTextState(button)
	if not button then
		return
	end
	local enabled = not button.IsEnabled or button:IsEnabled()
	local visualState = "normal"
	local textState = "normal"
	if not enabled then
		textState = "disabled"
	elseif button._gfCommonButtonPressed then
		visualState = "pressed"
		textState = "pressed"
	elseif button._gfCommonButtonHovered then
		visualState = "highlight"
		textState = "hover"
	end
	applyCommonPanelButtonVisualState(button, visualState, enabled)
	setCommonPanelButtonTextColor(button, textState)
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

function GF.UI.ApplyCommonPanelButtonSkin(button)
	if not button then
		return
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
	button:SetPushedTextOffset(1, -1)
	button:SetMotionScriptsWhileDisabled(true)
	local fs = button:GetFontString()
	if not fs then
		fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("CENTER", button, "CENTER", 0, 0)
		button:SetFontString(fs)
		if GF.Font and GF.Font.Track and button:GetText() then
			GF.Font.Track(fs, "GameFontNormal")
		end
	end
	if fs then
		fs:SetText(button:GetText() or "")
		fs:SetJustifyH("CENTER")
		fs:SetJustifyV("MIDDLE")
		fs:SetTextColor(COMMON_BUTTON_TEXT_COLOR.normal[1], COMMON_BUTTON_TEXT_COLOR.normal[2], COMMON_BUTTON_TEXT_COLOR.normal[3], COMMON_BUTTON_TEXT_COLOR.normal[4])
	end
	installCommonPanelButtonTextStates(button)
end

local function ensureFlatLayers(frame, prefix)
	if not frame or frame[prefix .. "Ready"] then
		return
	end
	local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetAllPoints(frame)
	bg:SetTexture(WHITE)
	frame[prefix .. "Bg"] = bg

	local border = frame:CreateTexture(nil, "BORDER", nil, -7)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	border:SetTexture(WHITE)
	frame[prefix .. "Border"] = border

	local inner = frame:CreateTexture(nil, "BORDER", nil, -6)
	inner:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	inner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	inner:SetTexture(WHITE)
	frame[prefix .. "Inner"] = inner

	frame[prefix .. "Ready"] = true
end

local function updateFlatButtonState(button)
	if not button then
		return
	end
	ensureFlatLayers(button, "_gfFlat")
	local bg = button._gfFlatBg
	local border = button._gfFlatBorder
	local inner = button._gfFlatInner
	local enabled = not button.IsEnabled or button:IsEnabled()
	local cr, cg, cb = getClassColor()
	if not enabled then
		paint(bg, 0, 0, 0, 0.42)
		paint(border, 0, 0, 0, 0)
		paint(inner, 1, 1, 1, 0.025)
	elseif button:IsMouseOver() then
		paint(bg, 0, 0, 0, 0.72)
		paint(border, cr, cg, cb, 0.95)
		paint(inner, 1, 1, 1, 0.05)
	else
		paint(bg, 0, 0, 0, 0.62)
		paint(border, 0, 0, 0, 0)
		paint(inner, 1, 1, 1, 0.035)
	end
end

function GF.UI.SkinButton(button)
	if not button then
		return button
	end
	ensureFlatLayers(button, "_gfFlat")
	local label = button.GetText and button:GetText() or nil
	killTextureRegion(button.GetNormalTexture and button:GetNormalTexture())
	killTextureRegion(button.GetPushedTexture and button:GetPushedTexture())
	killTextureRegion(button.GetHighlightTexture and button:GetHighlightTexture())
	killTextureRegion(button.GetDisabledTexture and button:GetDisabledTexture())
	if button.Left then
		button.Left:SetAlpha(0)
	end
	if button.Middle then
		button.Middle:SetAlpha(0)
	end
	if button.Right then
		button.Right:SetAlpha(0)
	end
	if not button._gfFlatButtonSkinned then
		button:EnableMouse(true)
		button:HookScript("OnEnter", updateFlatButtonState)
		button:HookScript("OnLeave", updateFlatButtonState)
		button:HookScript("OnShow", updateFlatButtonState)
		button:HookScript("OnEnable", updateFlatButtonState)
		button:HookScript("OnDisable", updateFlatButtonState)
		button:HookScript("OnMouseDown", function(self)
			local cr, cg, cb = getClassColor()
			paint(self._gfFlatBg, 0, 0, 0, 0.82)
			paint(self._gfFlatBorder, cr, cg, cb, 1)
		end)
		button:HookScript("OnMouseUp", updateFlatButtonState)
		button._gfFlatButtonSkinned = true
	end
	local fs = button:GetFontString()
	if not fs then
		fs = GF.UI.CreateFontString(button, "OVERLAY", "GameFontNormal")
		fs:SetPoint("CENTER", button, "CENTER", 0, 0)
		button:SetFontString(fs)
		if label and label ~= "" then
			fs:SetText(label)
		end
	end
	if fs then
		fs:SetTextColor(1, 1, 1, 1)
		fs._gfFontFlagsOverride = fs._gfFontFlagsOverride or "OUTLINE"
		if GF.Font and GF.Font.Track then
			GF.Font.Track(fs, "GameFontNormal")
		end
	end
	updateFlatButtonState(button)
	return button
end

local function applyVerticalBlackMask(texture, topAlpha, bottomAlpha)
	if not texture then
		return
	end
	texture:SetTexture(WHITE)
	if texture.SetGradient and CreateColor then
		local ok = pcall(texture.SetGradient, texture, "VERTICAL", CreateColor(0, 0, 0, topAlpha), CreateColor(0, 0, 0, bottomAlpha))
		if ok then
			return
		end
	end
	if texture.SetGradientAlpha then
		local ok = pcall(texture.SetGradientAlpha, texture, "VERTICAL", 0, 0, 0, topAlpha, 0, 0, 0, bottomAlpha)
		if ok then
			return
		end
	end
	texture:SetVertexColor(0, 0, 0, bottomAlpha or 0)
end

function GF.UI.InstallMainWindowSkin(frame)
	if not frame or frame._gfMainWindowSkin then
		return
	end
	if frame.Bg and frame.Bg.Hide then
		frame.Bg:Hide()
	end
	local pieces = {}
	for index = 1, 3 do
		local piece = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		paint(piece, 0, 0, 0, 0.82)
		pieces[index] = piece
	end
	local cornerRadius = 1
	local inset = 2
	pieces[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + cornerRadius, -inset)
	pieces[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset + cornerRadius), -inset)
	pieces[1]:SetHeight(cornerRadius)
	pieces[2]:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -(inset + cornerRadius))
	pieces[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset + cornerRadius)
	pieces[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset + cornerRadius, inset)
	pieces[3]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + cornerRadius), inset)
	pieces[3]:SetHeight(cornerRadius)
	frame._gfMainWindowPieces = pieces
	frame._gfMainWindowSkin = true
end

function GF.UI.InstallPanelBackplate(panel)
	if not panel or panel._gfPanelBackplate then
		return
	end
	local background = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
	local borderFrame = CreateFrame("Frame", nil, panel)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	panel._gfPanelBackground = background
	panel._gfPanelBorderFrame = borderFrame
	panel._gfPanelBorder = border

	local insetL = GF.MAIN_PANEL_BACKPLATE_BG_INSET_LEFT or 5
	local insetR = GF.MAIN_PANEL_BACKPLATE_BG_INSET_RIGHT or 5
	local insetT = GF.MAIN_PANEL_BACKPLATE_BG_INSET_TOP or 2
	local insetB = GF.MAIN_PANEL_BACKPLATE_BG_INSET_BOTTOM or 10
	background:SetPoint("TOPLEFT", panel, "TOPLEFT", insetL, -insetT)
	background:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -insetR, insetB)
	local bgColor = GF.MAIN_PANEL_BACKPLATE_BG_COLOR or { 0, 0, 0, 1 }
	paint(background, bgColor[1] or 0, bgColor[2] or 0, bgColor[3] or 0, bgColor[4] or 1)

	borderFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", -8, 12)
	borderFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 8, -6)
	borderFrame:EnableMouse(false)
	borderFrame:SetFrameLevel(panel:GetFrameLevel() + 12)
	border:SetAllPoints(borderFrame)
	trySetAtlas(border, "transmog-tabs-frame", false)
	border:SetVertexColor(1, 1, 1, 1)

	panel._gfPanelBackplate = true
end

function GF.UI.InstallTransmogOutfitPanelBackground(panel)
	if not panel or panel._gfTransmogOutfitBackground then
		return
	end
	panel._gfTransmogOutfitBackground = true
end

function GF.UI.InstallBrowseSidePanelChrome(panel)
	if not panel or panel._gfBrowseSideChrome then
		return
	end
	panel._gfBrowseSideChrome = true
end

function GF.UI.InstallTransmogTabsFrameBackground(panel)
	if not panel or panel._gfTransmogTabsFrameBackground then
		return
	end
	panel._gfTransmogTabsFrameBackground = true
end

		local function setCollectionTexCoord(texture, left, right, top, bottom)
			texture:SetTexCoord(left, right, top, bottom)
	end

	local function createCollectionBackgroundTexture(panel, layer, subLevel, atlas, left, right, top, bottom)
		local texture = panel:CreateTexture(nil, layer, nil, subLevel)
		trySetAtlas(texture, atlas, true)
		if left then
			setCollectionTexCoord(texture, left, right, top, bottom)
		end
		texture:SetVertexColor(1, 1, 1, 1)
		return texture
	end

	function GF.UI.InstallCollectionsBackground(panel)
		if not panel or panel._gfCollectionsBackground then
			return
		end

		local bg = {}
		bg.BackgroundTile = createCollectionBackgroundTexture(panel, "BACKGROUND", nil, "collections-background-tile")
		bg.BackgroundTile:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
		bg.BackgroundTile:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
		if bg.BackgroundTile.SetHorizTile then
			bg.BackgroundTile:SetHorizTile(true)
		end
		if bg.BackgroundTile.SetVertTile then
			bg.BackgroundTile:SetVertTile(true)
		end

		bg.ShadowCornerTopLeft = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large")
		bg.ShadowCornerTopRight = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 1, 0, 0, 1)
		bg.ShadowCornerBottomLeft = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 0, 1, 1, 0)
		bg.ShadowCornerBottomRight = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 1, 0, 1, 0)
		bg.ShadowCornerTop = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 0.9999, 1, 0, 1)
		bg.ShadowCornerLeft = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 0, 1, 0.9999, 1)
		bg.ShadowCornerRight = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 1, 0, 0.9999, 1)
		bg.ShadowCornerBottom = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 0.9999, 1, 1, 0)

		bg.ShadowCornerTopLeft:SetPoint("TOPLEFT", bg.BackgroundTile, "TOPLEFT")
		bg.ShadowCornerTopRight:SetPoint("TOPRIGHT", bg.BackgroundTile, "TOPRIGHT")
		bg.ShadowCornerBottomLeft:SetPoint("BOTTOMLEFT", bg.BackgroundTile, "BOTTOMLEFT")
		bg.ShadowCornerBottomRight:SetPoint("BOTTOMRIGHT", bg.BackgroundTile, "BOTTOMRIGHT")
		bg.ShadowCornerTop:SetPoint("TOPLEFT", bg.ShadowCornerTopLeft, "TOPRIGHT")
		bg.ShadowCornerTop:SetPoint("TOPRIGHT", bg.ShadowCornerTopRight, "TOPLEFT")
		bg.ShadowCornerLeft:SetPoint("TOPLEFT", bg.ShadowCornerTopLeft, "BOTTOMLEFT")
		bg.ShadowCornerLeft:SetPoint("BOTTOMLEFT", bg.ShadowCornerBottomLeft, "TOPLEFT")
		bg.ShadowCornerRight:SetPoint("TOPRIGHT", bg.ShadowCornerTopRight, "BOTTOMRIGHT")
		bg.ShadowCornerRight:SetPoint("BOTTOMRIGHT", bg.ShadowCornerBottomRight, "TOPRIGHT")
		bg.ShadowCornerBottom:SetPoint("BOTTOMLEFT", bg.ShadowCornerBottomLeft, "BOTTOMRIGHT")
		bg.ShadowCornerBottom:SetPoint("BOTTOMRIGHT", bg.ShadowCornerBottomRight, "BOTTOMLEFT")

		bg.OverlayShadowTopLeft = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small")
		bg.OverlayShadowTopRight = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 1, 0, 0, 1)
		bg.OverlayShadowBottomLeft = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 0, 1, 1, 0)
		bg.OverlayShadowBottomRight = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 1, 0, 1, 0)
		bg.OverlayShadowTop = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 0.9999, 1, 0, 1)
		bg.OverlayShadowLeft = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 0, 1, 0.9999, 1)
		bg.OverlayShadowRight = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 1, 0, 0.9999, 1)
		bg.OverlayShadowBottom = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 0.9999, 1, 1, 0)

		bg.OverlayShadowTopLeft:SetPoint("TOPLEFT", bg.BackgroundTile, "TOPLEFT")
		bg.OverlayShadowTopRight:SetPoint("TOPRIGHT", bg.BackgroundTile, "TOPRIGHT")
		bg.OverlayShadowBottomLeft:SetPoint("BOTTOMLEFT", bg.BackgroundTile, "BOTTOMLEFT")
		bg.OverlayShadowBottomRight:SetPoint("BOTTOMRIGHT", bg.BackgroundTile, "BOTTOMRIGHT")
		bg.OverlayShadowTop:SetPoint("TOPLEFT", bg.OverlayShadowTopLeft, "TOPRIGHT", 0, 0)
		bg.OverlayShadowTop:SetPoint("TOPRIGHT", bg.OverlayShadowTopRight, "TOPLEFT", 0, 0)
		bg.OverlayShadowLeft:SetPoint("TOPLEFT", bg.OverlayShadowTopLeft, "BOTTOMLEFT")
		bg.OverlayShadowLeft:SetPoint("BOTTOMLEFT", bg.OverlayShadowBottomLeft, "TOPLEFT")
		bg.OverlayShadowRight:SetPoint("TOPRIGHT", bg.OverlayShadowTopRight, "BOTTOMRIGHT")
		bg.OverlayShadowRight:SetPoint("BOTTOMRIGHT", bg.OverlayShadowBottomRight, "TOPRIGHT")
		bg.OverlayShadowBottom:SetPoint("BOTTOMLEFT", bg.OverlayShadowBottomLeft, "BOTTOMRIGHT", 0, 0)
		bg.OverlayShadowBottom:SetPoint("BOTTOMRIGHT", bg.OverlayShadowBottomRight, "BOTTOMLEFT", 0, 0)

		bg.BGCornerTopLeft = createCollectionBackgroundTexture(panel, "ARTWORK", 2, "collections-background-corner")
		bg.BGCornerTopRight = createCollectionBackgroundTexture(panel, "ARTWORK", 2, "collections-background-corner", 1, 0, 0, 1)
		bg.BGCornerBottomLeft = createCollectionBackgroundTexture(panel, "ARTWORK", 2, "collections-background-corner", 0, 1, 1, 0)
		bg.BGCornerBottomRight = createCollectionBackgroundTexture(panel, "ARTWORK", 2, "collections-background-corner", 1, 0, 1, 0)
		bg.BGCornerTopLeft:SetPoint("TOPLEFT", bg.BackgroundTile, "TOPLEFT")
		bg.BGCornerTopRight:SetPoint("TOPRIGHT", bg.BackgroundTile, "TOPRIGHT")
		bg.BGCornerBottomLeft:SetPoint("BOTTOMLEFT", bg.BackgroundTile, "BOTTOMLEFT")
		bg.BGCornerBottomRight:SetPoint("BOTTOMRIGHT", bg.BackgroundTile, "BOTTOMRIGHT")

		panel._gfCollectionsBackground = bg
	end

local function isFrameEffectivelyShown(frame)
	if not frame then
		return false
	end
	if frame.IsVisible then
		return frame:IsVisible()
	end
	return frame:IsShown()
end

local function syncExternalChromeVisibility(frame, backgroundFrame, owner)
	if not frame or not backgroundFrame then
		return
	end
	local function sync()
		backgroundFrame:SetShown(isFrameEffectivelyShown(frame))
	end
	frame:HookScript("OnShow", sync)
	frame:HookScript("OnHide", sync)
	if owner and owner ~= frame and owner.HookScript then
		owner:HookScript("OnShow", sync)
		owner:HookScript("OnHide", sync)
	end
	sync()
end

function GF.UI.InstallBrowseHeaderChrome(frame)
	if not frame or frame._gfBrowseHeaderChrome then
		return
	end
	frame._gfBrowseHeaderChrome = true
	local owner = frame:GetParent() or frame
	local backgroundParent = (GF.MainFrame and GF.MainFrame.layoutHost) or owner
	local backgroundFrame = CreateFrame("Frame", nil, backgroundParent)
	backgroundFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", GF.BROWSE_HEADER_BACKGROUND_INSET_L or 0, 0)
	backgroundFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	backgroundFrame:SetFrameLevel(math.max((backgroundParent:GetFrameLevel() or 1) + (GF.BROWSE_HEADER_BACKGROUND_FRAME_LEVEL_OFFSET or 1), 1))
	syncExternalChromeVisibility(frame, backgroundFrame, owner)
	local background = backgroundFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetAllPoints(backgroundFrame)
	if not trySetAtlas(background, GF.BROWSE_HEADER_BACKGROUND_ATLAS or "housefinder_header-bg-gradient", false) then
		background:SetTexture(WHITE)
		if background.SetGradientAlpha then
			background:SetGradientAlpha("VERTICAL", 0.22, 0.08, 0.02, 0.95, 0.04, 0.015, 0.005, 0.95)
		else
			background:SetVertexColor(0.12, 0.05, 0.01, 0.95)
		end
	end
	frame._gfBrowseHeaderBackgroundFrame = backgroundFrame
	frame._gfBrowseHeaderBackground = background
end

local function flipTextureVertically(texture)
	if not texture or not texture.GetTexCoord or not texture.SetTexCoord then
		return
	end
	local ulx, uly, llx, lly, urx, ury, lrx, lry = texture:GetTexCoord()
	if lry ~= nil then
		texture:SetTexCoord(llx, lly, ulx, uly, lrx, lry, urx, ury)
	elseif lly ~= nil then
		texture:SetTexCoord(ulx, uly, lly, llx)
	end
end

function GF.UI.InstallBrowseControlBarChrome(frame, opts)
	if not frame or frame._gfBrowseControlChrome then
		return
	end
	opts = opts or {}
	frame._gfBrowseControlChrome = true
	local owner = frame:GetParent() or frame
	local backgroundParent = opts.backgroundParent or (GF.MainFrame and GF.MainFrame.layoutHost) or owner
	local backgroundFrame = CreateFrame("Frame", nil, backgroundParent)
	local leftInset = opts.leftInset
	if leftInset == nil then
		leftInset = (GF.CONTENT_SCROLL_INSET_L or 0) + (GF.BROWSE_HEADER_BACKGROUND_INSET_L or 0)
	end
	local rightInset = opts.rightInset
	if rightInset == nil then
		rightInset = GF.CONTENT_SCROLL_INSET_R or 0
	end
	local h = opts.height or GF.BROWSE_CONTROL_BACKGROUND_H or GF.SUBTITLE_HEADER_H or frame:GetHeight()
	local y = opts.topOffset
	if y == nil then
		y = GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or GF.SUBTITLE_CONTROL_TOP_OFFSET or 0
	end
	backgroundFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", leftInset, y)
	backgroundFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rightInset, y)
	backgroundFrame:SetHeight(h)
	backgroundFrame:SetFrameLevel(math.max((backgroundParent:GetFrameLevel() or 1) + (opts.frameLevelOffset or GF.BROWSE_HEADER_BACKGROUND_FRAME_LEVEL_OFFSET or 1), 1))
	syncExternalChromeVisibility(frame, backgroundFrame, owner)
	local background = backgroundFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetAllPoints(backgroundFrame)
	if trySetAtlas(background, GF.BROWSE_CONTROL_BACKGROUND_ATLAS or GF.BROWSE_HEADER_BACKGROUND_ATLAS or "housefinder_header-bg-gradient", false) then
		flipTextureVertically(background)
		background:SetAlpha(GF.BROWSE_CONTROL_BACKGROUND_ALPHA or 1)
	else
		background:SetTexture(WHITE)
		if background.SetGradientAlpha then
			background:SetGradientAlpha("VERTICAL", 0.04, 0.015, 0.005, 0.95, 0.22, 0.08, 0.02, 0.95)
		else
			background:SetVertexColor(0.12, 0.05, 0.01, 0.95)
		end
	end
	frame._gfBrowseControlBackgroundFrame = backgroundFrame
	frame._gfBrowseControlBackground = background
end

function GF.UI.CreatePanelBackplate(parent)
	local panel = createFrameWithTemplateOptions("Frame", nil, parent, { "BackdropTemplate" })
	panel:SetPoint("TOPLEFT", parent, "TOPLEFT", GF.MAIN_PANEL_INSET_LEFT or 26, -(GF.MAIN_PANEL_INSET_TOP or 64))
	panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(GF.MAIN_PANEL_INSET_RIGHT or 26), GF.MAIN_PANEL_INSET_BOTTOM or 24)
	panel:SetFrameLevel(parent:GetFrameLevel() + 11)
	GF.UI.InstallPanelBackplate(panel)
	return panel
end

local function stopRecruitEyeAnimation(eye)
	if not eye then
		return
	end
	local nativeEye = eye.Eye or eye
	if nativeEye.StopAnimating then
		pcall(nativeEye.StopAnimating, nativeEye)
	elseif eye.StopAnimating then
		pcall(eye.StopAnimating, eye)
	end
	if nativeEye.texture then
		nativeEye.texture:Hide()
	end
	eye._gfRecruitEyeLooping = nil
end

local function startRecruitEyeAnimation(eye)
	if not eye then
		return false
	end
	local nativeEye = eye.Eye or eye
	if nativeEye.texture then
		nativeEye.texture:Hide()
	end
	if nativeEye.StartSearchingAnimation then
		local ok = pcall(nativeEye.StartSearchingAnimation, nativeEye)
		if ok then
			eye._gfRecruitEyeLooping = true
			return true
		end
	end
	if eye.StartSearchingAnimation then
		local ok = pcall(eye.StartSearchingAnimation, eye)
		if ok then
			eye._gfRecruitEyeLooping = true
			return true
		end
	end
	if nativeEye.StartFoundAnimationLoop then
		local ok = pcall(nativeEye.StartFoundAnimationLoop, nativeEye)
		if ok then
			eye._gfRecruitEyeLooping = true
			return true
		end
	end
	if eye.StartFoundAnimationLoop then
		local ok = pcall(eye.StartFoundAnimationLoop, eye)
		if ok then
			eye._gfRecruitEyeLooping = true
			return true
		end
	end
	return false
end

function GF.UI.InstallRecruitEyeLogo(frame)
	if not frame or frame._gfRecruitEyeLogo then
		return frame and frame._gfRecruitEyeLogo
	end
	local portraitContainer = frame.PortraitContainer
	local parent = portraitContainer or frame
	local anchor = portraitContainer and portraitContainer.portrait or parent
	if not parent or not anchor then
		return nil
	end
	if portraitContainer and portraitContainer.portrait then
		local portrait = portraitContainer.portrait
		portrait:SetTexture(nil)
		portrait:SetAlpha(0)
		portrait:Hide()
		portrait:ClearAllPoints()
		portrait:SetSize(63, 63)
		portrait:SetPoint("TOPLEFT", portraitContainer, "TOPLEFT", -6, 8.5)
		if portraitContainer.CircleMask then
			portraitContainer.CircleMask:ClearAllPoints()
			portraitContainer.CircleMask:SetPoint("TOPLEFT", portraitContainer, "TOPLEFT", -3, 7)
			portraitContainer.CircleMask:SetPoint("BOTTOMRIGHT", portraitContainer, "TOPLEFT", 55, -51)
		end
	end

	local host = CreateFrame("Frame", nil, parent)
	host:SetSize(GF.MAIN_WINDOW_EYE_HOST_SIZE or 68, GF.MAIN_WINDOW_EYE_HOST_SIZE or 68)
	host:SetPoint("CENTER", anchor, "CENTER", 0, 0)
	host:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or frame:GetFrameLevel()) + 30)
	host:EnableMouse(false)
	host._gfRecruitEyeLogo = true

	local blackFill = host:CreateTexture(nil, "BACKGROUND")
	blackFill:SetPoint("CENTER")
	blackFill:SetSize(GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54, GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54)
	paint(blackFill, 0, 0, 0, 1)
	if host.CreateMaskTexture and blackFill.AddMaskTexture then
		local mask = host:CreateMaskTexture()
		mask:SetTexture(GF.MAIN_WINDOW_EYE_BACKGROUND_MASK or "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetPoint("CENTER", blackFill, "CENTER", 0, 0)
		mask:SetSize(GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54, GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54)
		pcall(blackFill.AddMaskTexture, blackFill, mask)
		host.BlackFillMask = mask
	elseif portraitContainer and portraitContainer.CircleMask and blackFill.AddMaskTexture then
		pcall(blackFill.AddMaskTexture, blackFill, portraitContainer.CircleMask)
	end
	host.BlackFill = blackFill

	local staticEye = host:CreateTexture(nil, "ARTWORK")
	staticEye:SetPoint("CENTER", host, "CENTER", 0, 1)
	staticEye:SetSize(GF.MAIN_WINDOW_LOGO_SIZE or GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54, GF.MAIN_WINDOW_LOGO_SIZE or GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54)
	local logoPath = GF.MAIN_WINDOW_LOGO_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\Logo\\GroupFinderIcon.png"
	local logoOk = pcall(staticEye.SetTexture, staticEye, logoPath)
	if not logoOk and not trySetAtlas(staticEye, "groupfinder-eye-single", false) then
		staticEye:SetTexture(GF.ADDON_LOGO_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\Logo\\GroupFinderIcon.png")
	end
	staticEye:SetTexCoord(0, 1, 0, 1)
	staticEye:Show()
	host.StaticEye = staticEye

	if tryLoadQueueStatusFrameUI() then
		local ok, eye = pcall(CreateFrame, "Frame", nil, host, "EyeTemplate")
		if ok and eye then
			eye:SetSize(GF.MAIN_WINDOW_EYE_SIZE or 44, GF.MAIN_WINDOW_EYE_SIZE or 44)
			eye:SetPoint("CENTER", host, "CENTER", 0, 0)
			eye:SetFrameLevel(host:GetFrameLevel() + 5)
			eye:Hide()
			if eye.texture then
				eye.texture:Hide()
			end
			host.Eye = eye
		end
	end

	frame._gfRecruitEyeLogo = host
	return host
end

function GF.UI.SetRecruitEyeLogoActive(frame, active)
	local host = GF.UI.InstallRecruitEyeLogo(frame)
	if not host then
		return
	end
	active = active == true
	host:Show()
	if host.BlackFill then
		host.BlackFill:Show()
	end
	if active then
		if host.StaticEye then
			host.StaticEye:Hide()
		end
		if host.Eye then
			host.Eye:SetAlpha(1)
			host.Eye:SetScale(1)
			host.Eye:Show()
			if not host.Eye._gfRecruitEyeLooping and not startRecruitEyeAnimation(host.Eye) then
				host.Eye:Hide()
				if host.StaticEye then
					host.StaticEye:Show()
				end
			end
		elseif host.StaticEye then
			host.StaticEye:Show()
		end
	else
		if host.Eye then
			stopRecruitEyeAnimation(host.Eye)
			host.Eye:SetAlpha(1)
			host.Eye:SetScale(1)
			host.Eye:Hide()
		end
		if host.StaticEye then
			host.StaticEye:Show()
		end
	end
	host._gfRecruitEyeActive = active
end

local function assignOptionsTabAtlasKeys(button)
	button.upLeftTexture = OPTIONS_TAB_ATLASES.up.left
	button.upMiddleTexture = OPTIONS_TAB_ATLASES.up.middle
	button.upRightTexture = OPTIONS_TAB_ATLASES.up.right
	button.overLeftTexture = OPTIONS_TAB_ATLASES.up.left
	button.overMiddleTexture = OPTIONS_TAB_ATLASES.up.middle
	button.overRightTexture = OPTIONS_TAB_ATLASES.up.right
	button.selectedLeftTexture = OPTIONS_TAB_ATLASES.selected.left
	button.selectedMiddleTexture = OPTIONS_TAB_ATLASES.selected.middle
	button.selectedRightTexture = OPTIONS_TAB_ATLASES.selected.right
end

local function ensureNativeTabPieces(button)
	if not button.Left then
		button.Left = button:CreateTexture(nil, "BACKGROUND")
		button.Left:SetPoint("BOTTOMLEFT")
	end
	if not button.Right then
		button.Right = button:CreateTexture(nil, "BACKGROUND")
		button.Right:SetPoint("BOTTOMRIGHT")
	end
	if not button.Middle then
		button.Middle = button:CreateTexture(nil, "BACKGROUND")
		button.Middle:SetPoint("TOPLEFT", button.Left, "TOPRIGHT")
		button.Middle:SetPoint("TOPRIGHT", button.Right, "TOPLEFT")
	end
	if not button.Text then
		button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	end
	if button._gfTopTabStyle and not button.SelectedHighlight then
		local selectedHighlight = CreateFrame("Frame", nil, button)
		selectedHighlight:SetFrameLevel(button._gfSelectedHighlightFrameLevel or (button:GetFrameLevel() + 10))
		selectedHighlight:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 5)
		selectedHighlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 5)
		selectedHighlight:SetHeight(1)
		selectedHighlight:Hide()
		local highlight = selectedHighlight:CreateTexture(nil, "ARTWORK")
		highlight:SetAllPoints(selectedHighlight)
		trySetAtlas(highlight, "transmog-tab-hl", false)
		highlight:SetVertexColor(1, 1, 1, 1)
		selectedHighlight.Highlight = highlight
		button.SelectedHighlight = selectedHighlight
	end
end

local function updateNativeTabAtlas(button)
	if not button or button._gfTopTabStyle then
		return
	end
	local atlasSet = button._gfSelected and OPTIONS_TAB_ATLASES.selected or OPTIONS_TAB_ATLASES.up
	trySetAtlas(button.Left, atlasSet.left, true)
	trySetAtlas(button.Middle, atlasSet.middle, true)
	trySetAtlas(button.Right, atlasSet.right, true)
end

local function setNativeTabText(button, text)
	button.Text:SetText(text or "")
	button.Text:SetWidth(0)
	local textWidth = button.Text:GetStringWidth() or 0
	if button._gfTopTabStyle then
		local width = math.max(GF.MAIN_PANEL_TAB_MIN_WIDTH or 95, textWidth + 30)
		width = math.min(GF.MAIN_PANEL_TAB_MAX_WIDTH or 170, width)
		button:SetSize(width, GF.MAIN_PANEL_TAB_HEIGHT or 32)
		button.Text:SetWidth(math.max(1, width - 10))
	else
		button:SetSize(math.max(GF.MAIN_PANEL_TAB_MIN_WIDTH or 95, textWidth + 40), GF.MAIN_PANEL_TAB_HEIGHT or 32)
	end
end

function GF.UI.SetNativeTabText(button, text)
	if button and button.Text then
		setNativeTabText(button, text)
	end
end

function GF.UI.SetNativeTabSelected(button, selected)
	if not button or not button.Text then
		return
	end
	button._gfSelected = selected == true
	if button._gfTopTabStyle and button.SetTabSelected then
		local ok = pcall(button.SetTabSelected, button, selected == true)
		if ok then
			if button.SelectedHighlight then
				button.SelectedHighlight:SetShown(selected == true)
			end
			if selected then
				button.Text:SetTextColor(1, 1, 1, 1)
			else
				button.Text:SetTextColor(1, 0.82, 0, 1)
			end
			return
		end
	end
	if button.SetSelectedState and button.OnSelected then
		button:SetSelectedState(selected == true)
		button:OnSelected(selected == true)
	else
		updateNativeTabAtlas(button)
		button.Text:ClearAllPoints()
		button.Text:SetPoint("BOTTOM", button, "BOTTOM", 0, selected and 6 or 4)
		button.Text:SetFontObject(selected and "GameFontHighlightSmall" or "GameFontNormalSmall")
	end
end

function GF.UI.CreateNativeTabButton(parent, text, tabIndex)
	local name = ("GroupFinderAddonFrameTab%d"):format(tabIndex or 0)
	local button, template = createFrameWithTemplateOptions("Button", name, parent, {
		"TabSystemTopButtonTemplate",
		"MinimalTabTemplate",
	})
	button:SetID(tabIndex or 0)
	button._gfNativeTab = true
	button._gfTopTabStyle = template == "TabSystemTopButtonTemplate" and button.LeftActive and button.MiddleActive and button.RightActive
	button._gfSelectedHighlightFrameLevel = parent and parent.selectedHighlightFrameLevel
	if button._gfTopTabStyle then
		button:SetFrameLevel(parent:GetFrameLevel() + 1)
		button.isTabOnTop = true
		button.selectedFontObject = GameFontHighlight
		button.unselectedFontObject = GameFontNormal
		button.textOffsetY = 3
		button.textPadding = 17
		if button.HandleRotation then
			pcall(button.HandleRotation, button)
		end
	else
		assignOptionsTabAtlasKeys(button)
	end
	ensureNativeTabPieces(button)
	setNativeTabText(button, text)
	GF.UI.SetNativeTabSelected(button, false)
	if not button._gfTopTabStyle then
		button:SetScript("OnEnter", function(tabButton)
			tabButton.over = true
			if tabButton.UpdateAtlas then
				tabButton:UpdateAtlas()
			else
				updateNativeTabAtlas(tabButton)
			end
		end)
		button:SetScript("OnLeave", function(tabButton)
			tabButton.over = nil
			if tabButton.UpdateAtlas then
				tabButton:UpdateAtlas()
			else
				updateNativeTabAtlas(tabButton)
			end
		end)
	end
	return button
end

function GF.UI.CreateFontString(parent, layer, template)
	if not parent or not parent.CreateFontString then
		return nil
	end
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", template)
	if GF.Font and GF.Font.Track then
		GF.Font.Track(fs, template)
	end
	return fs
end

local DEFAULT_PENDING_SPINNER_SIZE = 18

local function createFallbackPendingSpinner(parent)
	if not parent then
		return nil
	end
	local spinner = CreateFrame("Frame", nil, parent)
	spinner.Ring = spinner:CreateTexture(nil, "ARTWORK")
	spinner.Ring:SetAllPoints(spinner)
	spinner.Ring:SetAtlas("Spinner_Ring")
	spinner.Sparks = spinner:CreateTexture(nil, "ARTWORK")
	spinner.Sparks:SetAllPoints(spinner)
	spinner.Sparks:SetAtlas("Spinner_Sparks")
	if spinner.Sparks.SetBlendMode then
		spinner.Sparks:SetBlendMode("ADD")
	end
	if spinner.Sparks.CreateAnimationGroup then
		local ok = pcall(function()
			local group = spinner.Sparks:CreateAnimationGroup()
			local rotation = group:CreateAnimation("Rotation")
			rotation:SetDuration(0.85)
			rotation:SetDegrees(360)
			group:SetLooping("REPEAT")
			spinner.Anim = group
		end)
		if not ok then
			spinner.Anim = nil
		end
	end
	return spinner
end

function GF.UI.CreatePendingSpinner(parent, size)
	if not parent then
		return nil
	end
	size = size or DEFAULT_PENDING_SPINNER_SIZE
	local ok, spinner = pcall(CreateFrame, "Frame", nil, parent, "SpinnerTemplate")
	spinner = ok and spinner or createFallbackPendingSpinner(parent)
	if spinner then
		spinner:SetSize(size, size)
		if spinner.SetFrameLevel and parent.GetFrameLevel then
			spinner:SetFrameLevel(parent:GetFrameLevel() + 2)
		end
		spinner:Hide()
	end
	return spinner
end

function GF.UI.StartPendingSpinner(spinner, size)
	if not spinner then
		return
	end
	size = size or DEFAULT_PENDING_SPINNER_SIZE
	spinner:SetSize(size, size)
	spinner:Show()
	if spinner.Anim and spinner.Anim.Play and (not spinner.Anim.IsPlaying or not spinner.Anim:IsPlaying()) then
		spinner.Anim:Play()
	end
end

function GF.UI.StopPendingSpinner(spinner)
	if not spinner then
		return
	end
	if spinner.Anim and spinner.Anim.Stop then
		spinner.Anim:Stop()
	end
	spinner:Hide()
end

function GF.UI.SetButtonPendingSpinner(button, shown, size)
	if not button then
		return
	end
	local fs = button.GetFontString and button:GetFontString()
	if shown then
		size = size or DEFAULT_PENDING_SPINNER_SIZE
		local currentText = button.GetText and button:GetText()
		if currentText and currentText ~= "" then
			button._gfPendingSpinnerText = currentText
		elseif button._gfPendingSpinnerText == nil then
			button._gfPendingSpinnerText = currentText or ""
		end
		if not button._gfPendingSpinner then
			button._gfPendingSpinner = GF.UI.CreatePendingSpinner(button, size)
			if button._gfPendingSpinner then
				button._gfPendingSpinner:SetPoint("CENTER", button, "CENTER", 0, 0)
			end
		end
		if button.SetText then
			button:SetText("")
		elseif fs and fs.SetText then
			fs:SetText("")
		end
		if fs and fs.SetAlpha then
			fs:SetAlpha(0)
		end
		GF.UI.StartPendingSpinner(button._gfPendingSpinner, size)
	else
		local restoreText = button._gfPendingSpinnerText
		button._gfPendingSpinnerText = nil
		if restoreText ~= nil then
			if button.SetText then
				button:SetText(restoreText)
			elseif fs and fs.SetText then
				fs:SetText(restoreText)
			end
		end
		if fs and fs.SetAlpha then
			fs:SetAlpha(1)
		end
		GF.UI.StopPendingSpinner(button._gfPendingSpinner)
	end
end

function GF.UI.TrackEditBox(box, template)
	if box and GF.Font and GF.Font.TrackEditBox then
		GF.Font.TrackEditBox(box, template or "GameFontHighlightSmall")
	end
	return box
end

function GF.UI.CreateInputBox(parent, width, height)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(width or 60, height or 18)
	box:SetAutoFocus(false)
	return GF.UI.TrackEditBox(box, "GameFontHighlightSmall")
end

local function hideInputBoxRegion(region)
	if not region then
		return
	end
	if region.Hide then
		region:Hide()
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
end

local function hideInputBoxChrome(editBox)
	if not editBox then
		return
	end
	local name = editBox.GetName and editBox:GetName()
	if name then
		for _, region in ipairs({
			_G[name .. "Left"],
			_G[name .. "Middle"],
			_G[name .. "Right"],
			_G[name .. "LeftTexture"],
			_G[name .. "MiddleTexture"],
			_G[name .. "RightTexture"],
		}) do
			hideInputBoxRegion(region)
		end
	end
	hideInputBoxRegion(editBox.Left)
	hideInputBoxRegion(editBox.Middle)
	hideInputBoxRegion(editBox.Right)
	hideInputBoxRegion(editBox.LeftTexture)
	hideInputBoxRegion(editBox.MiddleTexture)
	hideInputBoxRegion(editBox.RightTexture)
end

local function setTextureVertexColor(texture, color)
	if not texture then
		return
	end
	color = color or { 1, 1, 1, 1 }
	texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function installBrowseSearchBackground(editBox)
	if not editBox or editBox._gfBrowseSearchBackground then
		return
	end
	local insetX = GF.SUBTITLE_SEARCH_BACKGROUND_INSET_X or 0
	local insetY = GF.SUBTITLE_SEARCH_BACKGROUND_INSET_Y or 2
	local background = editBox:CreateTexture(nil, "BACKGROUND", nil, -2)
	background:SetPoint("TOPLEFT", editBox, "TOPLEFT", insetX, -insetY)
	background:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", -insetX, insetY)
	background:SetTexture(WHITE)
	setTextureVertexColor(background, GF.SUBTITLE_SEARCH_BACKGROUND_COLOR or { 0, 0, 0, 0.55 })

	local border = editBox:CreateTexture(nil, "BORDER", nil, -1)
	border:SetPoint("TOPLEFT", editBox, "TOPLEFT", -8, 7)
	border:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 8, -9)
	if not trySetAtlas(border, GF.SUBTITLE_SEARCH_BORDER_ATLAS or "common-dropdown-textholder", false) then
		border:SetTexture(WHITE)
		border:SetVertexColor(1, 1, 1, 0.14)
	end

	editBox._gfBrowseSearchBackground = background
	editBox._gfBrowseSearchBorder = border
end

function GF.UI.StyleBrowseSearchBox(editBox, placeholder)
	if not editBox then
		return nil
	end
	editBox:SetAutoFocus(false)
	editBox._gfFontSizeOverride = GF.SUBTITLE_SEARCH_TEXT_SIZE or 12
	editBox._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.TrackEditBox then
		GF.Font.TrackEditBox(editBox, "GameFontHighlightSmall")
	end
	local textColor = GF.SUBTITLE_SEARCH_TEXT_COLOR or { 1, 0.96, 0.86, 1 }
	editBox:SetTextColor(textColor[1] or 1, textColor[2] or 0.96, textColor[3] or 0.86, textColor[4] or 1)
	editBox:SetShadowColor(0, 0, 0, 0.8)
	editBox:SetShadowOffset(1, -1)
	if editBox.SetTextInsets then
		editBox:SetTextInsets(GF.SUBTITLE_SEARCH_TEXT_INSET_LEFT or 27, GF.SUBTITLE_SEARCH_TEXT_INSET_RIGHT or 24, 0, 0)
	end

	hideInputBoxChrome(editBox)
	installBrowseSearchBackground(editBox)

	if editBox.searchIcon then
		editBox.searchIcon:ClearAllPoints()
		editBox.searchIcon:SetPoint("LEFT", editBox, "LEFT", GF.SUBTITLE_SEARCH_ICON_INSET or 8, 0)
		editBox.searchIcon:SetSize(GF.SUBTITLE_SEARCH_ICON_SIZE or 14, GF.SUBTITLE_SEARCH_ICON_SIZE or 14)
	end
	if editBox.clearButton then
		editBox.clearButton:ClearAllPoints()
		editBox.clearButton:SetPoint("RIGHT", editBox, "RIGHT", -(GF.SUBTITLE_SEARCH_CLEAR_INSET or 6), 0)
	end
	if editBox.Instructions then
		local placeholderColor = GF.SUBTITLE_SEARCH_PLACEHOLDER_COLOR or { 0.55, 0.55, 0.55, 1 }
		editBox.Instructions:ClearAllPoints()
		editBox.Instructions:SetPoint("LEFT", editBox, "LEFT", GF.SUBTITLE_SEARCH_TEXT_INSET_LEFT or 27, 0)
		editBox.Instructions:SetPoint("RIGHT", editBox, "RIGHT", -(GF.SUBTITLE_SEARCH_TEXT_INSET_RIGHT or 24), 0)
		editBox.Instructions:SetText(placeholder or "")
		editBox.Instructions:SetTextColor(
			placeholderColor[1] or 0.55,
			placeholderColor[2] or 0.55,
			placeholderColor[3] or 0.55,
			placeholderColor[4] or 1
		)
		if editBox.Instructions.SetWordWrap then
			editBox.Instructions:SetWordWrap(false)
		end
		editBox.Instructions._gfFontSizeOverride = GF.SUBTITLE_SEARCH_TEXT_SIZE or 12
		editBox.Instructions._gfFontFlagsOverride = ""
		if GF.Font and GF.Font.Track then
			GF.Font.Track(editBox.Instructions, "GameFontDisableSmall")
		end
	end
	return editBox
end

function GF.UI.CreateDropdownButton(parent)
	local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	if GF.Font and GF.Font.TrackDropdownButton then
		GF.Font.TrackDropdownButton(dd)
	end
	if dd.SetupMenu and GF.Font and GF.Font.WrapMenuRoot then
		local origSetupMenu = dd.SetupMenu
		dd.SetupMenu = function(self, generator, ...)
			return origSetupMenu(self, function(owner, rootDescription, ...)
				GF.Font.WrapMenuRoot(rootDescription)
				return generator(owner, rootDescription, ...)
			end, ...)
		end
	end
	return dd
end

function GF.UI.SetHoverTooltipOwner(owner, anchor)
	if not owner or not GameTooltip or not GameTooltip.SetOwner then
		return
	end
	if anchor then
		GameTooltip:SetOwner(owner, anchor)
		return
	end
	local left = owner.GetLeft and owner:GetLeft()
	if left and left > 500 then
		GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	end
end

function GF.UI.BeginGameTooltip(owner, anchor)
	if not owner or not GameTooltip then
		return
	end
	GF.UI.SetHoverTooltipOwner(owner, anchor)
	if GF.Font and GF.Font.BeginTooltipFont then
		GF.Font.BeginTooltipFont(GameTooltip)
	end
end

function GF.UI.BeginGameTooltipAbove(owner, align)
	if not owner or not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_NONE")
	if GameTooltip.ClearAllPoints then
		GameTooltip:ClearAllPoints()
	end
	local gap = GF.TOOLTIP_BUTTON_TOP_GAP or 4
	if align == "RIGHT" then
		GameTooltip:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", 0, gap)
	elseif align == "LEFT" then
		GameTooltip:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, gap)
	else
		GameTooltip:SetPoint("BOTTOM", owner, "TOP", 0, gap)
	end
	if GF.Font and GF.Font.BeginTooltipFont then
		GF.Font.BeginTooltipFont(GameTooltip)
	end
end

function GF.UI.ApplyGameTooltipFont(tooltip)
	tooltip = tooltip or GameTooltip
	if GF.Font and GF.Font.ApplyTooltipFont then
		GF.Font.ApplyTooltipFont(tooltip)
	end
end

function GF.UI.ShowGameTooltip(tooltip)
	tooltip = tooltip or GameTooltip
	GF.UI.ApplyGameTooltipFont(tooltip)
	if tooltip and tooltip.Show then
		tooltip:Show()
	end
end

function GF.UI.ShowSimpleTooltip(owner, text, anchor)
	if not owner or not text or text == "" or not GameTooltip or not GameTooltip.SetText then
		return
	end
	GF.UI.BeginGameTooltip(owner, anchor)
	GameTooltip:SetText(text, nil, nil, nil, nil, true)
	GF.UI.ShowGameTooltip()
end

function GF.UI.ShowSimpleTooltipAbove(owner, text, align)
	if not owner or not text or text == "" or not GameTooltip or not GameTooltip.SetText then
		return
	end
	GF.UI.BeginGameTooltipAbove(owner, align)
	GameTooltip:SetText(text, nil, nil, nil, nil, true)
	GF.UI.ShowGameTooltip()
end

function GF.UI.SetTooltipText(text, r, g, b)
	if not GameTooltip or not GameTooltip.SetText or not text or text == "" then
		return
	end
	r = r or GF.UI.TOOLTIP_GOLD_R
	g = g or GF.UI.TOOLTIP_GOLD_G
	b = b or GF.UI.TOOLTIP_GOLD_B
	-- Retail: SetText(text, r, g, b, alpha, wrap) — 5th is alpha, not wrap.
	GameTooltip:SetText(text, r, g, b, 1, true)
end

function GF.UI.ShowApplicantBlockTooltip(btn, reason)
	if not btn or not reason then
		return
	end
	local msg = GF.Listing and GF.Listing.GetApplicantActionMessage
		and GF.Listing:GetApplicantActionMessage(reason)
	if not msg or msg == "" then
		return
	end
	GF.UI.BeginGameTooltip(btn)
	GF.UI.SetTooltipText(msg)
	GF.UI.ShowGameTooltip()
end

local function beginBoundButtonTooltip(btn, placement)
	if placement == "aboveRight" then
		GF.UI.BeginGameTooltipAbove(btn, "RIGHT")
	elseif placement == "aboveLeft" then
		GF.UI.BeginGameTooltipAbove(btn, "LEFT")
	elseif placement == "above" then
		GF.UI.BeginGameTooltipAbove(btn)
	else
		GF.UI.BeginGameTooltip(btn)
	end
end

local function bindPermissionButton(btn, canFn, msgFn, notifyFn, onClick, onEnterAlt, tooltipPlacement)
	if not btn then
		return
	end
	if btn.SetMotionScriptsWhileDisabled then
		btn:SetMotionScriptsWhileDisabled(true)
	end
	btn:SetScript("OnEnter", function(self)
		setCommonPanelButtonHoverState(self, true)
		if canFn and not canFn() then
			local msg = msgFn and msgFn()
			if msg and msg ~= "" then
				beginBoundButtonTooltip(self, tooltipPlacement)
				GF.UI.SetTooltipText(msg)
				GF.UI.ShowGameTooltip()
			end
			return
		end
		if onEnterAlt then
			onEnterAlt(self)
		end
	end)
	btn:SetScript("OnLeave", function(self)
		setCommonPanelButtonHoverState(self, false)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	btn:SetScript("OnClick", function(self)
		if canFn and not canFn() then
			if notifyFn then
				notifyFn()
			end
			return
		end
		if onClick then
			onClick(self)
		end
	end)
end

-- Leader-only LFG actions: disabled state from UpdateManageState; hover/click use Blizzard leader message.
-- onEnterAlt: optional tooltip when the player is leader (e.g. bump help text).
function GF.UI.BindLeaderOnlyButton(btn, onClick, onEnterAlt, tooltipPlacement)
	local L = GF.Listing
	bindPermissionButton(btn,
		function() return L and L.CanLeadListing and L:CanLeadListing() end,
		function() return L and L.GetLeaderOnlyMessage and L:GetLeaderOnlyMessage() end,
		function() if L and L.NotifyLeaderOnly then L:NotifyLeaderOnly() end end,
		onClick, onEnterAlt, tooltipPlacement)
end

-- Leader or raid assistant: disabled state from UpdateManageState; hover/click use manage-entry message.
function GF.UI.BindManageEntryButton(btn, onClick, onEnterAlt, tooltipPlacement)
	local L = GF.Listing
	bindPermissionButton(btn,
		function() return L and L.CanManageEntry and L:CanManageEntry() end,
		function() return L and L.GetApplicantActionMessage and L:GetApplicantActionMessage("unempowered") end,
		function() if L and L.NotifyApplicantActionBlocked then L:NotifyApplicantActionBlocked("unempowered") end end,
		onClick, onEnterAlt, tooltipPlacement)
end

function GF.UI.CreatePanelButton(parent, text, width, useCommonTexture)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width or 80, GF.PANEL_BUTTON_H or 24)
	btn:SetText(text or "")
	if GF.Font and GF.Font.TrackButton then
		GF.Font.TrackButton(btn, "GameFontNormal")
	end
	if useCommonTexture ~= false then
		GF.UI.ApplyCommonPanelButtonSkin(btn)
	else
		GF.UI.SkinButton(btn)
	end
	return btn
end

function GF.UI.CreateHelpIcon(parent, tooltipText, size)
	size = size or 30
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(size, size)
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Common\\help-i")
	icon:SetSize(size, size)
	icon:SetPoint("CENTER")
	local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Common\\help-i")
	highlight:SetBlendMode("ADD")
	highlight:SetSize(size, size)
	highlight:SetPoint("CENTER")
	btn:SetScript("OnEnter", function(self)
		local text = self._gfTooltip or tooltipText
		if not text or text == "" then
			return
		end
		GF.UI.ShowSimpleTooltip(self, text, "ANCHOR_RIGHT")
	end)
	btn:SetScript("OnLeave", GameTooltip_Hide)
	btn._gfTooltip = tooltipText
	return btn
end

-- FontString 定宽 + 引擎省略（申请者 / 组队 Browse 共用）
function GF.UI.SetEllipsisText(fontString, text, width)
	if not fontString then
		return
	end
	width = width or fontString:GetWidth() or 0
	fontString:SetWordWrap(false)
	fontString:SetMaxLines(1)
	if width > 0 then
		fontString:SetWidth(width)
	end
	fontString:SetText(text or "")
end

-- 申请者卡片：MyKeyStone-style 1:1 icon action buttons.
local function setApplicantActionButtonTexture(button, state)
	local bg = button and button.applicantActionBg
	if not bg then
		return
	end
	setCommonButtonTexCoord(bg, state or "normal", "square")
end

local function refreshApplicantActionButtonState(button)
	if not button then
		return
	end
	local enabled = not button.IsEnabled or button:IsEnabled()
	local state = "normal"
	if enabled and button._gfApplicantActionPressed then
		state = "pressed"
	elseif enabled and button._gfApplicantActionHovered then
		state = "highlight"
	end
	setApplicantActionButtonTexture(button, state)
	if button.applicantActionBg then
		if button.applicantActionBg.SetDesaturated then
			button.applicantActionBg:SetDesaturated(not enabled)
		end
		button.applicantActionBg:SetVertexColor(1, 1, 1, enabled and 1 or 0.55)
		button.applicantActionBg:SetAlpha(1)
	end
	local iconAlpha = enabled and 1 or 0.45
	local iconR, iconG, iconB = 1, 1, 1
	if enabled and button._gfApplicantActionHovered and not button._gfApplicantActionPressed then
		iconR, iconG, iconB = 1, 0.96, 0.58
	end
	if button.icon then
		button.icon:SetVertexColor(iconR, iconG, iconB, 1)
		button.icon:SetAlpha(iconAlpha)
	end
	if button.fallback then
		button.fallback:SetAlpha(iconAlpha)
		if button.fallback.SetTextColor then
			button.fallback:SetTextColor(iconR, iconG, iconB, 1)
		end
	end
end

local function createApplicantActionButton(parent, atlas, fallbackText)
	local size = GF.APPLICANT_ACTION_BUTTON_SIZE or 24
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(size, size)
	local btn = CreateFrame("Button", nil, holder)
	btn:SetSize(size, size)
	btn:SetAllPoints(holder)
	btn:SetMotionScriptsWhileDisabled(true)
	btn:SetText("")
	clearButtonStateTexture(btn, "Normal")
	clearButtonStateTexture(btn, "Pushed")
	clearButtonStateTexture(btn, "Highlight")
	clearButtonStateTexture(btn, "Disabled")
	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(btn)
	bg:SetTexture(COMMON_BUTTON_PATH)
	bg:SetVertexColor(1, 1, 1, 1)
	bg:SetAlpha(1)
	if bg.SetBlendMode then
		bg:SetBlendMode("BLEND")
	end
	btn.applicantActionBg = bg
	setApplicantActionButtonTexture(btn, "normal")
	local label = btn.Text or (btn.GetFontString and btn:GetFontString())
	if label then
		label:SetText("")
		label:Hide()
	end
	local icon = btn:CreateTexture(nil, "OVERLAY", nil, 2)
	if not trySetAtlas(icon, atlas, false) then
		icon:Hide()
		local fallback = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fallback:SetPoint("CENTER", btn, "CENTER", 0, 0)
		fallback:SetText(fallbackText or "")
		fallback:SetJustifyH("CENTER")
		fallback:SetJustifyV("MIDDLE")
		if GF.Font and GF.Font.Track then
			fallback._gfFontSizeOverride = 18
			fallback._gfFontFlagsOverride = "OUTLINE"
			GF.Font.Track(fallback, "GameFontHighlight")
		end
		btn.fallback = fallback
	else
		icon:SetSize(GF.APPLICANT_ACTION_ICON_SIZE or 12, GF.APPLICANT_ACTION_ICON_SIZE or 12)
		icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
		btn.icon = icon
	end
	holder.button = btn
	btn:HookScript("OnEnter", function(self)
		self._gfApplicantActionHovered = true
		refreshApplicantActionButtonState(self)
	end)
	btn:HookScript("OnLeave", function(self)
		self._gfApplicantActionHovered = nil
		self._gfApplicantActionPressed = nil
		refreshApplicantActionButtonState(self)
	end)
	btn:HookScript("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton" and (not self.IsEnabled or self:IsEnabled()) then
			self._gfApplicantActionPressed = true
			refreshApplicantActionButtonState(self)
		end
	end)
	btn:HookScript("OnMouseUp", function(self)
		self._gfApplicantActionPressed = nil
		if not (self.IsMouseOver and self:IsMouseOver()) then
			self._gfApplicantActionHovered = nil
		end
		refreshApplicantActionButtonState(self)
	end)
	btn:HookScript("OnEnable", refreshApplicantActionButtonState)
	btn:HookScript("OnDisable", refreshApplicantActionButtonState)
	btn.RefreshApplicantActionState = refreshApplicantActionButtonState
	refreshApplicantActionButtonState(btn)
	return holder, btn
end

function GF.UI.CreateApplicantInviteButton(parent)
	return createApplicantActionButton(parent, "UI-LFG-ReadyMark", "✓")
end

function GF.UI.CreateApplicantDeclineButton(parent)
	return createApplicantActionButton(parent, "UI-LFG-DeclineMark", "×")
end

function GF.UI.GetCategoryTitle(categoryID, activityInfo)
	if activityInfo then
		if activityInfo.fullName and activityInfo.fullName ~= "" then
			return activityInfo.fullName
		end
		if activityInfo.shortName and activityInfo.shortName ~= "" then
			return activityInfo.shortName
		end
	end
	local info = categoryID and C_LFGList.GetLfgCategoryInfo(categoryID)
	return info and info.name or ""
end

function GF.UI.ApplySettingsFrameChrome(frame, title)
	if frame and frame.Bg then
		frame.Bg:Hide()
	end
	local text = title or "GroupFinder"
	local fs = resolveSystemPanelTitleText(frame)
	if fs then
		applySystemPanelTitleStyle(fs)
		frame.systemTitleText = fs
		frame.titletext = fs
	end
	if frame and frame.SetTitle then
		pcall(frame.SetTitle, frame, text)
		fs = frame.systemTitleText or resolveSystemPanelTitleText(frame)
	end
	if fs then
		fs:SetText(text)
		applySystemPanelTitleStyle(fs)
		centerSystemPanelTitle(frame, fs)
		frame.systemTitleText = fs
		frame.titletext = fs
	end
end

function GF.UI.GetMainFrame()
	return GF.MainFrame and GF.MainFrame.frame
end

local satelliteFrames = {}

function GF.UI.RegisterSatelliteFrame(frame)
	if not frame then
		return
	end
	for i = 1, #satelliteFrames do
		if satelliteFrames[i] == frame then
			return
		end
	end
	satelliteFrames[#satelliteFrames + 1] = frame
	if GF.GetPanelScale and frame.SetScale then
		frame:SetScale(GF.GetPanelScale())
	end
	if GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
end

function GF.UI.RaiseFrame(frame)
	if frame and frame.Raise then
		frame:Raise()
		if frame == GF.UI.GetMainFrame() and GF.UI.RaiseMainFrameSatelliteGroup then
			GF.UI.RaiseMainFrameSatelliteGroup()
		end
	end
end

-- UIParent 独立窗 + 跟随主框 strata/level；需要浮在主框上方的窗口可设置 levelOffset/raise。
function GF.UI.ApplySatelliteFrameLayers(strataOverride)
	local mainFrame = GF.UI.GetMainFrame()
	local strata = strataOverride
		or (mainFrame and mainFrame.GetFrameStrata and mainFrame:GetFrameStrata())
		or (GF.GetFrameStrata and GF.GetFrameStrata())
		or "MEDIUM"
	local mainLevel = mainFrame and mainFrame.GetFrameLevel and mainFrame:GetFrameLevel()
	for i = 1, #satelliteFrames do
		local f = satelliteFrames[i]
		if f and f.SetFrameStrata then
			f:SetFrameStrata(strata)
		end
		if f and f.SetFrameLevel and mainLevel then
			f:SetFrameLevel(mainLevel + (f._gfLevelOffset or 5))
		end
		if f and f._gfOnSatelliteFrameLayersApplied then
			f:_gfOnSatelliteFrameLayersApplied(strata, mainLevel)
		end
	end
end

function GF.UI.RaiseMainFrameSatelliteGroup()
	local mainFrame = GF.UI.GetMainFrame()
	if not mainFrame then
		return
	end
	if mainFrame.Raise then
		mainFrame:Raise()
	end
	if GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
	for i = 1, #satelliteFrames do
		local f = satelliteFrames[i]
		if f and f._gfFollowMainFrameRaise
			and (not f.IsShown or f:IsShown()) then
			if f.Raise then
				f:Raise()
			end
			if f._gfOnSatelliteFrameLayersApplied then
				f:_gfOnSatelliteFrameLayersApplied(
					f.GetFrameStrata and f:GetFrameStrata(),
					mainFrame.GetFrameLevel and mainFrame:GetFrameLevel()
				)
			end
		end
	end
end

function GF.UI.ApplySatelliteFrameScale(scale)
	scale = tonumber(scale) or (GF.GetPanelScale and GF.GetPanelScale()) or 1
	for i = 1, #satelliteFrames do
		local f = satelliteFrames[i]
		if f and f.SetScale then
			f:SetScale(scale)
		end
	end
end

function GF.UI.InstallSatelliteFrame(frame, opts)
	opts = opts or {}
	if not frame then
		return
	end
	frame._gfLevelOffset = opts.levelOffset or 5
	frame._gfRaiseSatelliteFrame = opts.raise ~= false
	frame._gfFollowMainFrameRaise = opts.followMainRaise == true
	if frame.SetToplevel then
		frame:SetToplevel(opts.toplevel ~= false)
	end
	GF.UI.RegisterSatelliteFrame(frame)
	if frame._gfSatelliteStackingInstalled then
		return
	end
	frame._gfSatelliteStackingInstalled = true
	frame:HookScript("OnShow", function()
		GF.UI.ApplySatelliteFrameLayers()
		GF.UI.ApplySatelliteFrameScale()
		if frame._gfFollowMainFrameRaise and GF.UI.RaiseMainFrameSatelliteGroup then
			GF.UI.RaiseMainFrameSatelliteGroup()
		elseif frame._gfRaiseSatelliteFrame then
			GF.UI.RaiseFrame(frame)
		end
	end)
	frame:HookScript("OnMouseDown", function()
		if frame._gfFollowMainFrameRaise and GF.UI.RaiseMainFrameSatelliteGroup then
			GF.UI.RaiseMainFrameSatelliteGroup()
		elseif frame._gfRaiseSatelliteFrame then
			GF.UI.RaiseFrame(frame)
		else
			GF.UI.ApplySatelliteFrameLayers()
		end
	end)
end

function GF.UI.CenterOnMainFrame(frame, offsetY)
	offsetY = offsetY or 0
	if not frame then
		return
	end
	local mainFrame = GF.UI.GetMainFrame()
	frame:ClearAllPoints()
	if mainFrame then
		frame:SetPoint("CENTER", mainFrame, "CENTER", 0, offsetY)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY + 40)
	end
end

function GF.UI.CreateSatelliteSettingsFrame(opts)
	opts = opts or {}
	local f = CreateFrame("Frame", opts.name or "GroupFinderAddonSatelliteDialog", UIParent, "SettingsFrameTemplate")
	f:SetSize(opts.width or 480, opts.height or 400)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()
	GF.UI.InstallSatelliteFrame(f, { levelOffset = opts.levelOffset or 5 })
	GF.UI.InstallBodyBackground(f, { layout = "main" })
	GF.UI.ApplySettingsFrameChrome(f, opts.title or "")
	GF.UI.SetupTitleDragBar(f)
	if f.ClosePanelButton and opts.onClose then
		f.ClosePanelButton:SetScript("OnClick", opts.onClose)
	end
	if UISpecialFrames and f.GetName and f:GetName() then
		tinsert(UISpecialFrames, f:GetName())
	end
	return f
end

function GF.UI.PresentSatelliteFrame(frame, opts)
	opts = opts or {}
	if not frame then
		return
	end
	if opts.title then
		GF.UI.ApplySettingsFrameChrome(frame, opts.title)
	end
	if opts.prepare then
		opts.prepare(frame)
	end
	if opts.refreshBackground ~= false then
		GF.UI.ApplyBodyBackground(frame)
	end
	GF.UI.CenterOnMainFrame(frame, opts.offsetY or 0)
	frame:Show()
	if opts.onShown then
		opts.onShown(frame)
	end
end

function GF.UI.SetupTitleDragBar(frame, onDragStop)
	if not frame or frame.gfDragBar then
		return frame and frame.gfDragBar
	end
	frame:SetMovable(true)
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", GF.MAIN_WINDOW_DRAG_HANDLE_LEFT_INSET or 76, GF.MAIN_WINDOW_DRAG_HANDLE_TOP_OFFSET or 0)
	bar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -(GF.MAIN_WINDOW_DRAG_HANDLE_RIGHT_INSET or 78), GF.MAIN_WINDOW_DRAG_HANDLE_BOTTOM_OFFSET or -40)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	local function startMove()
		GF.UI.RaiseFrame(frame)
		if frame._gfTitleMoving then
			return
		end
		frame._gfTitleMoving = true
		frame:StartMoving()
	end
	local function stopMove()
		if not frame._gfTitleMoving then
			return
		end
		frame._gfTitleMoving = false
		frame:StopMovingOrSizing()
		if onDragStop then
			onDragStop(frame)
		end
	end
	bar:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			startMove()
		else
			GF.UI.RaiseFrame(frame)
		end
	end)
	bar:SetScript("OnMouseUp", stopMove)
	bar:SetScript("OnDragStart", startMove)
	bar:SetScript("OnDragStop", stopMove)
	bar:SetScript("OnHide", stopMove)
	bar:SetFrameLevel(frame:GetFrameLevel() + 50)
	frame.gfDragBar = bar
	return bar
end

function GF.GetWheelScrollRows()
	local minV = GF.LIST_WHEEL_ROWS_MIN or 1
	local maxV = GF.LIST_WHEEL_ROWS_MAX or 10
	local db = GF.GetDB()
	local rows = db and db.listWheelScrollRows
	if rows == nil then
		rows = GF.LIST_WHEEL_ROWS_DEFAULT or 3
	end
	rows = math.floor((tonumber(rows) or GF.LIST_WHEEL_ROWS_DEFAULT or 3) + 0.5)
	return math.max(minV, math.min(maxV, rows))
end

function GF.GetWheelScrollPixels(rowHeight)
	rowHeight = rowHeight or GF.LIST_ROW_H or 52
	return GF.GetWheelScrollRows() * rowHeight
end

function GF.UI.InstallWheelScroll(scroll, force)
	if not scroll then
		return
	end
	scroll._gfWheelRowH = scroll._gfWheelRowH or GF.LIST_ROW_H or 52
	if scroll._gfWheelInstalled and not force then
		return
	end
	scroll._gfWheelInstalled = true
	scroll:EnableMouseWheel(true)
	if scroll.SetPanExtent then
		scroll:SetPanExtent(GF.GetWheelScrollPixels(scroll._gfWheelRowH))
	end
	scroll:SetScript("OnMouseWheel", function(_, delta)
		if not delta or delta == 0 then
			return
		end
		if scroll._gfWheelAllow and not scroll._gfWheelAllow() then
			return
		end
		local step = GF.GetWheelScrollPixels(scroll._gfWheelRowH)
		if scroll.SetPanExtent then
			scroll:SetPanExtent(step)
		end
		local cur = scroll:GetVerticalScroll() or 0
		local range = scroll:GetVerticalScrollRange() or 0
		local newPos = math.max(0, math.min(range, cur - delta * step))
		scroll:SetVerticalScroll(newPos)
		local fn = scroll._gfOnWheelScrolled
		if fn then
			fn(scroll, newPos, delta)
		end
	end)
end

function GF.UI.CreateScrollFrame(parent, opts)
	opts = opts or {}
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetClipsChildren(true)
	scroll._gfWheelRowH = opts.rowHeight or GF.LIST_ROW_H or 52
	GF.UI.InstallWheelScroll(scroll)
	return scroll
end

function GF.UI.HideLegacyScrollBar(scroll)
	if not scroll then
		return
	end
	if scroll.ScrollBar and scroll.ScrollBar.Hide then
		scroll.ScrollBar:Hide()
	end
	local name = scroll:GetName()
	if name then
		local legacy = _G[name .. "ScrollBar"]
		if legacy and legacy.Hide then
			legacy:Hide()
		end
	end
end

local CHROME_LIGHT_A_HORZ = 0.22
local CHROME_LIGHT_A_VERT = 0.16

local function InstallBevelDivider(parent, orient)
	local dark = parent:CreateTexture(nil, "OVERLAY")
	dark:SetColorTexture(0, 0, 0, 0.58)
	local light = parent:CreateTexture(nil, "OVERLAY")
	local lightA = orient == "horiz" and CHROME_LIGHT_A_HORZ or CHROME_LIGHT_A_VERT
	light:SetColorTexture(0.82, 0.78, 0.68, lightA)
	if orient == "horiz" then
		local insetL = GF.FRAME_PAD or 4
		light:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", insetL, 0)
		light:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
		light:SetHeight(1)
		dark:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", insetL, 1)
		dark:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 1)
		dark:SetHeight(1)
	else
		dark:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		dark:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
		dark:SetWidth(1)
		light:SetPoint("TOPLEFT", dark, "TOPRIGHT", 0, 0)
		light:SetPoint("BOTTOMLEFT", dark, "BOTTOMRIGHT", 0, 0)
		light:SetWidth(1)
	end
end

function GF.UI.CommitRelayoutSig(panel)
	if not panel or not panel.GetRelayoutSig then
		return
	end
	local sig = panel:GetRelayoutSig()
	if sig then
		panel._relayoutSig = sig
	end
end

function GF.UI.RelayoutWhenReady(panel, attempt)
	attempt = attempt or 0
	if attempt > 5 or not panel or not panel.GetRelayoutSig or not panel.Relayout then
		return
	end
	if not panel.scrollList then
		return
	end
	local mf = GF.MainFrame and GF.MainFrame.frame
	if not mf or not mf:IsShown() then
		return
	end
	if panel.parent and not panel.parent:IsShown() then
		return
	end
	if panel._frameResizing or GF._frameResizing then
		return
	end
	panel:UpdateScrollWidth()
	local scrollW = panel.scrollList:GetLayoutWidth() or 0
	if scrollW <= 1 then
		local mainFrame = GF.MainFrame
		if mainFrame and mainFrame.ScheduleWhenShown then
			mainFrame:ScheduleWhenShown(0, function()
				GF.UI.RelayoutWhenReady(panel, attempt + 1)
			end)
		end
		return
	end
	local sig = panel:GetRelayoutSig()
	if sig and sig == panel._relayoutSig then
		if panel.scrollList.RetainScrollPosition then
			panel.scrollList:RetainScrollPosition()
		end
		return
	end
	panel:Relayout({ force = true })
end

local function setTextureColor(texture, color)
	if not texture or not color then
		return
	end
	texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function setBrowseDividerAccentGradient(texture, startAlpha, endAlpha)
	if not texture then
		return
	end
	local color = GF.NAV_DIVIDER_CENTER_ACCENT_COLOR or { 1, 0.82, 0 }
	local r, g, b = color[1] or 1, color[2] or 0.82, color[3] or 0
	if texture.SetGradient and CreateColor then
		local ok = pcall(texture.SetGradient, texture, "VERTICAL", CreateColor(r, g, b, startAlpha), CreateColor(r, g, b, endAlpha))
		if ok then
			return
		end
	end
	if texture.SetGradientAlpha then
		texture:SetGradientAlpha("VERTICAL", r, g, b, startAlpha, r, g, b, endAlpha)
	else
		texture:SetVertexColor(r, g, b, math.max(startAlpha or 0, endAlpha or 0))
	end
end

local function createBrowseDividerCenterAccent(parent)
	local accent = CreateFrame("Frame", nil, parent)
	accent:SetPoint("TOP", parent, "TOP", 0, 0)
	accent:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
	accent:SetPoint("CENTER", parent, "CENTER", 0, 0)
	accent:SetWidth(GF.NAV_DIVIDER_CENTER_ACCENT_W or 1)

	local top = accent:CreateTexture(nil, "OVERLAY")
	top:SetTexture(WHITE)
	top:SetPoint("TOPLEFT", accent, "TOPLEFT", 0, 0)
	top:SetPoint("BOTTOMRIGHT", accent, "RIGHT", 0, 0)
	setBrowseDividerAccentGradient(top, 1, 0)

	local bottom = accent:CreateTexture(nil, "OVERLAY")
	bottom:SetTexture(WHITE)
	bottom:SetPoint("TOPLEFT", accent, "LEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", accent, "BOTTOMRIGHT", 0, 0)
	setBrowseDividerAccentGradient(bottom, 0, 1)

	accent.Top = top
	accent.Bottom = bottom
	return accent
end

function GF.UI.InstallNavColumnDivider(host)
	if not host or host._gfMeetingStoneDivider then
		return
	end
	host:SetWidth(GF.NAV_DIVIDER_W or 3)

	local function addLine(layer, subLevel, color)
		local tex = host:CreateTexture(nil, layer or "ARTWORK", nil, subLevel or 0)
		tex:SetTexture("Interface\\Buttons\\WHITE8X8")
		setTextureColor(tex, color)
		return tex
	end

	local leftShadow = addLine("ARTWORK", 1, GF.NAV_DIVIDER_SHADOW_COLOR)
	leftShadow:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
	leftShadow:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
	leftShadow:SetWidth(2)

	local center = addLine("ARTWORK", 2, GF.NAV_DIVIDER_COLOR)
	center:SetPoint("TOPLEFT", leftShadow, "TOPRIGHT", 0, 0)
	center:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 0)

	local highlight = addLine("ARTWORK", 3, GF.NAV_DIVIDER_HIGHLIGHT_COLOR)
	highlight:SetPoint("TOPLEFT", center, "TOPLEFT", 0, 0)
	highlight:SetPoint("BOTTOMLEFT", center, "BOTTOMLEFT", 0, 0)
	highlight:SetWidth(1)

	local rightShadow = addLine("ARTWORK", 1, GF.NAV_DIVIDER_SHADOW_COLOR)
	rightShadow:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
	rightShadow:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
	rightShadow:SetWidth(2)

	local centerAccent = createBrowseDividerCenterAccent(host)
	host.CenterAccent = centerAccent

	host._gfMeetingStoneDivider = {
		center = center,
		leftShadow = leftShadow,
		highlight = highlight,
		rightShadow = rightShadow,
		centerAccent = centerAccent,
	}
end

function GF.UI.LayoutNavColumnDivider(host)
	local leftPanel = host and host:GetParent()
	if not host or not leftPanel then
		return
	end
	host:ClearAllPoints()
	host:SetPoint("TOP", leftPanel, "TOPRIGHT", GF.NAV_DIVIDER_OFFSET_X or -3, -(GF.NAV_DIVIDER_TOP_OFFSET or 4))
	host:SetPoint("BOTTOM", leftPanel, "BOTTOMRIGHT", GF.NAV_DIVIDER_OFFSET_X or -3, GF.NAV_DIVIDER_BOTTOM_OFFSET or 2)
	host:SetWidth(GF.NAV_DIVIDER_W or 3)
	host:SetFrameLevel((leftPanel:GetFrameLevel() or 1) + 6)
end

function GF.UI.ApplySubtitleChrome(frame)
	if frame._gfSubtitleChrome then
		return
	end
	frame._gfSubtitleChrome = true
	InstallBevelDivider(frame, "horiz")
end

local function ResetBodyBgTexState(fill)
	fill:SetHorizTile(false)
	fill:SetVertTile(false)
	fill:SetTexCoord(0, 1, 0, 1)
end

function GF.UI.LayoutBodyBackground(frame)
	local bg = frame and frame.gfBodyBg
	if not bg or not bg.fill then
		return
	end
	local fill = bg.fill
	local opts = frame._gfBodyBgOpts or {}
	fill:ClearAllPoints()
	if opts.layout == "fill" then
		fill:SetAllPoints(frame)
	else
		local insetL = GF.FRAME_BG_INSET_LEFT or 7
		local insetT = GF.FRAME_BG_INSET_TOP or -18
		local insetR = GF.FRAME_BG_INSET_RIGHT or -2
		local insetB = GF.FRAME_BG_INSET_BOTTOM or 3
		fill:SetPoint("TOPLEFT", frame, "TOPLEFT", insetL, insetT)
		fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", insetR, insetB)
	end
end

function GF.UI.ApplyBodyBackground(frame)
	local bg = frame and frame.gfBodyBg
	local opts = frame and frame._gfBodyBgOpts
	if not bg or not opts or not bg.fill then
		return
	end
	if frame.Bg then
		frame.Bg:Hide()
	end

	GF.UI.LayoutBodyBackground(frame)
	local fill = bg.fill

	if opts.style == "panelBackplate" then
		local c = GF.MAIN_PANEL_BACKPLATE_BG_COLOR or { 0, 0, 0, 1 }
		local cacheKey = string.format("panelBackplate:%.4f:%.4f:%.4f:%.4f", c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
		if fill._gfBodyBgCache == cacheKey then
			fill:Show()
			return
		end
		fill._gfBodyBgCache = cacheKey
		fill:SetAtlas(nil)
		fill:SetTexture(nil)
		ResetBodyBgTexState(fill)
		fill:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
		fill:Show()
		return
	end

	local c = GF.BODY_BACKGROUND_COLOR or { 0.05, 0.05, 0.08, 0.75 }
	local cacheKey = string.format("body:%.4f:%.4f:%.4f:%.4f", c[1] or 0.05, c[2] or 0.05, c[3] or 0.08, c[4] or 0.75)
	if fill._gfBodyBgCache == cacheKey then
		fill:Show()
		return
	end
	fill._gfBodyBgCache = cacheKey

	fill:SetAtlas(nil)
	fill:SetTexture(nil)
	ResetBodyBgTexState(fill)
	fill:SetColorTexture(c[1] or 0.05, c[2] or 0.05, c[3] or 0.08, c[4] or 0.75)

	bg.fill:Show()
end

function GF.UI.InstallBodyBackground(frame, opts)
	if not frame then
		return
	end
	opts = opts or {}
	frame._gfBodyBgOpts = opts
	if not frame.gfBodyBg then
		local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		frame.gfBodyBg = {
			fill = fill,
		}
	end
	GF.UI.ApplyBodyBackground(frame)
end

function GF.UI.CreateContentPanel(parent)
	return CreateFrame("Frame", nil, parent)
end

function GF.UI.StripMinimalScrollBarSteppers(bar)
	if not bar then
		return
	end
	local back = bar.GetBackStepper and bar:GetBackStepper() or bar.Back
	local forward = bar.GetForwardStepper and bar:GetForwardStepper() or bar.Forward
	if back and back.Hide then
		back:Hide()
	end
	if forward and forward.Hide then
		forward:Hide()
	end
	local track = bar.GetTrack and bar:GetTrack() or bar.Track
	if track and track.ClearAllPoints then
		track:ClearAllPoints()
		track:SetPoint("TOP", bar, "TOP", 0, 0)
		track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
	end
end

function GF.UI.AttachContentScrollBar(scroll, barParent)
	return GF.UI.AttachMinimalScrollBar(
		scroll,
		GF.CONTENT_SCROLLBAR_OFFSET_X or 9,
		barParent or scroll:GetParent() or scroll
	)
end

function GF.UI.AnchorContentScrollBottomRight(scroll, parent)
	scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -GF.CONTENT_SCROLL_INSET_R, GF.CONTENT_SCROLL_INSET_B)
end

function GF.UI.AttachMinimalScrollBar(scroll, offsetX, barParent, keepNativeChrome)
	offsetX = offsetX or 4
	barParent = barParent or scroll:GetParent() or scroll
	GF.UI.HideLegacyScrollBar(scroll)
	local bar = CreateFrame("EventFrame", nil, barParent, "MinimalScrollBar")
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", offsetX, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", offsetX, 0)
	bar:SetFrameLevel(scroll:GetFrameLevel() + 10)
	if not keepNativeChrome then
		GF.UI.StripMinimalScrollBarSteppers(bar)
	end
	bar:Show()
	if bar.SetHideIfUnscrollable then
		bar:SetHideIfUnscrollable(true)
	end
	scroll.ScrollBar = bar
	bar._gfHideIfUnscrollable = true
	if ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar then
		ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
	elseif scroll.UpdateScrollChildRect then
		scroll:UpdateScrollChildRect()
	end
	-- ScrollUtil overwrites OnMouseWheel + SetPanExtent(30); re-apply GF wheel step.
	GF.UI.InstallWheelScroll(scroll, true)
	return bar
end

function GF.UI.UpdateScrollFrame(scroll)
	if not scroll then
		return
	end
	if scroll.UpdateScrollChildRect then
		scroll:UpdateScrollChildRect()
	end
	local onRange = scroll:GetScript("OnScrollRangeChanged")
	if onRange then
		onRange(scroll, scroll:GetHorizontalScrollRange(), scroll:GetVerticalScrollRange())
	end
	if scroll.ScrollBar and scroll.ScrollBar.Update then
		scroll.ScrollBar:Update()
	end
	if scroll.ScrollBar and scroll.ScrollBar._gfHideIfUnscrollable and scroll.GetVerticalScrollRange then
		scroll.ScrollBar:SetShown((scroll:GetVerticalScrollRange() or 0) > 0)
	end
end

function GF.UI.SetupResizeHandle(frame, opts)
	if not frame or frame.gfResize then
		return frame and frame.gfResize
	end
	opts = opts or {}
	local minW = opts.minW or GF.FRAME_MIN_W
	local minH = opts.minH or GF.FRAME_MIN_H
	frame:SetResizable(true)
	local btn = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
	btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
	btn:SetFrameLevel(frame:GetFrameLevel() + 30)
	if btn.Init then
		btn:Init(frame, minW, minH, nil, nil)
	end
	if opts.onResize then
		btn:SetOnResizeCallback(function(_, width, height, isActive)
			opts.onResize(frame, width, height, isActive)
		end)
	end
	if opts.onResizeStopped then
		btn:SetOnResizeStoppedCallback(function()
			opts.onResizeStopped(frame)
		end)
	end
	frame.gfResize = btn
	return btn
end
