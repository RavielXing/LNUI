local _, GF = ...

GF.TopNoticeToast = GF.TopNoticeToast or {}
local Toast = GF.TopNoticeToast

local TOAST_W = 418
local TOAST_H = 72
local TOAST_TOP_OFFSET_Y = -190
local TOAST_DISPLAY_SECONDS = 3.8
local TOAST_LONG_DISPLAY_SECONDS = 5.0
local TOAST_FADE_SECONDS = 0.35
local REVEAL_SECONDS = 0.5
local CONTENT_REVEAL_SECONDS = 0.33
local TEXT_SAFE_W = 300
-- The native line centers land at +28.5 and -37.5 inside the 72 px root.
-- A -4 px optical offset centers the visible title between them without the
-- half-pixel softness that a strict -4.5 px geometric anchor can introduce.
local TEXT_CENTER_OFFSET_Y = -4
local SINGLE_LINE_HEIGHT = 30
local SINGLE_LINE_SIZE = 30
local SINGLE_LINE_MIN_SIZE = 14
local BLOCK_TEXT_HEIGHT = 48
local BLOCK_TEXT_SIZE = 15
local BLOCK_TEXT_MAX_LINES = 2
local JOIN_TITLE_OFFSET_Y = 8
local JOIN_SUBTITLE_OFFSET_Y = -20
local JOIN_SUBTITLE_HEIGHT = 18
local JOIN_SUBTITLE_SIZE = 18
local JOIN_SUBTITLE_MIN_SIZE = 12
local FALLBACK_SOUND = "IG_MAINMENU_OPTION_CHECKBOX_ON"
local FALLBACK_ATLAS = "evergreen-scenario-TitleBG"
local SCENARIO_BLACK_ATLAS = "evergreen-scenario-black-background"
local SCENARIO_LINE_TOP_ATLAS = "evergreen-scenario-line-top"
local SCENARIO_LINE_BOTTOM_ATLAS = "evergreen-scenario-line-bottom"
local SCENARIO_PATTERN_ATLAS = "evergreen-scenario-pattern-background"
local SCENARIO_FILIGREE_TOP_ATLAS = "evergreen-scenario-filigree-top"
local SCENARIO_FILIGREE_BOTTOM_ATLAS = "evergreen-scenario-filigree-bottom"
local BLACK_BG_W = 326
local BLACK_BG_H = 64
local BLACK_BG_ALPHA = 0.6
local FALLBACK_LINE_W = 350
local FALLBACK_LINE_H = 5
local DEFAULT_SCENARIO_STAGE_COLOR = { 1, 233 / 255, 174 / 255, 1 }

local function applyToastBlendMode(texture, atlas)
	if texture and texture.SetBlendMode then
		texture:SetBlendMode(type(atlas) == "string" and atlas:match("%-add$") and "ADD" or "BLEND")
	end
end

local function setAtlas(texture, atlas, useAtlasSize)
	if not (texture and type(atlas) == "string" and atlas ~= "") then
		return false
	end
	if GF.UI and GF.UI.TrySetAtlas
		and GF.UI.TrySetAtlas(texture, atlas, useAtlasSize == true)
	then
		applyToastBlendMode(texture, atlas)
		texture:Show()
		return true
	end
	if texture.SetAtlas then
		local ok, result = pcall(texture.SetAtlas, texture, atlas, useAtlasSize == true)
		if ok and result ~= false then
			applyToastBlendMode(texture, atlas)
			texture:Show()
			return true
		end
	end
	texture:Hide()
	return false
end

local function setToastBackgroundAtlas(texture)
	local atlas = GF.TOP_NOTICE_TOAST_ATLAS
		or GF.JOIN_ANNOUNCE_TOAST_ATLAS
		or FALLBACK_ATLAS
	return setAtlas(texture, atlas, true)
end

local function setTextureSize(texture, width, height)
	if texture and type(texture.SetSize) == "function" then
		texture:SetSize(width, height)
	end
end

local function setTextureHeight(texture, height)
	if texture and type(texture.SetHeight) == "function" then
		texture:SetHeight(height)
	end
end

local function getScenarioStageColor()
	local color = _G.SCENARIO_STAGE_COLOR
	if color then
		local method = color.GetRGBA
		if type(method) == "function" then
			local ok, r, g, b, a = pcall(method, color)
			if ok and type(r) == "number" and type(g) == "number"
				and type(b) == "number"
			then
				return r, g, b, type(a) == "number" and a or 1
			end
		end
		local r, g, b, a = color.r, color.g, color.b, color.a
		if type(r) == "number" and type(g) == "number"
			and type(b) == "number"
		then
			return r, g, b, type(a) == "number" and a or 1
		end
	end
	return DEFAULT_SCENARIO_STAGE_COLOR[1], DEFAULT_SCENARIO_STAGE_COLOR[2],
		DEFAULT_SCENARIO_STAGE_COLOR[3], DEFAULT_SCENARIO_STAGE_COLOR[4]
end

local function applyScenarioStageColor(text)
	local r, g, b, a = getScenarioStageColor()
	text:SetTextColor(r, g, b, a)
end

local function setTexturePoint(texture, ...)
	if texture and type(texture.SetPoint) == "function" then
		texture:SetPoint(...)
	end
end

local function createSceneTexture(frame, layer, atlas, useAtlasSize)
	local texture = frame:CreateTexture(nil, layer)
	if not setAtlas(texture, atlas, useAtlasSize) then
		return texture, false
	end
	return texture, true
end

local function setRegionShown(region, shown)
	if not region then
		return
	end
	if type(region.SetShown) == "function" then
		region:SetShown(shown == true)
	elseif shown and type(region.Show) == "function" then
		region:Show()
	elseif not shown and type(region.Hide) == "function" then
		region:Hide()
	end
end

local function setRegionAlpha(region, alpha)
	if region and type(region.SetAlpha) == "function" then
		region:SetAlpha(alpha)
	end
end

local function setAnimationTarget(animation, target)
	if not (animation and target and type(animation.SetTarget) == "function") then
		return false
	end
	local ok, result = pcall(animation.SetTarget, animation, target)
	return ok and result ~= false
end

local function neutralizeAlphaAnimation(animation, duration)
	if not animation then
		return
	end
	if type(animation.SetFromAlpha) == "function" then
		animation:SetFromAlpha(1)
	end
	if type(animation.SetToAlpha) == "function" then
		animation:SetToAlpha(1)
	end
	if type(animation.SetDuration) == "function" then
		animation:SetDuration(duration)
	end
end

local function neutralizeScaleAnimation(animation, duration)
	if not animation then
		return
	end
	if type(animation.SetScaleFrom) == "function" then
		animation:SetScaleFrom(1, 1)
	end
	if type(animation.SetScaleTo) == "function" then
		animation:SetScaleTo(1, 1)
	end
	if type(animation.SetDuration) == "function" then
		animation:SetDuration(duration)
	end
end

local function addAlphaAnimation(group, target, fromAlpha, toAlpha, duration, startDelay)
	local animation = group:CreateAnimation("Alpha")
	if not setAnimationTarget(animation, target) then
		-- CreateAnimation has already attached the animation to the group. Keep
		-- it as an identity operation so a failed SetTarget cannot animate the
		-- group's owner (the whole Toast) by accident.
		neutralizeAlphaAnimation(animation, duration)
		return nil
	end
	animation:SetFromAlpha(fromAlpha)
	animation:SetToAlpha(toAlpha)
	animation:SetDuration(duration)
	if startDelay and startDelay > 0 and type(animation.SetStartDelay) == "function" then
		animation:SetStartDelay(startDelay)
	end
	if type(animation.SetSmoothing) == "function" then
		animation:SetSmoothing("OUT")
	end
	return animation
end

local function addScaleAnimation(group, target, fromX, fromY, toX, toY, duration, startDelay)
	local animation = group:CreateAnimation("Scale")
	if not setAnimationTarget(animation, target) then
		neutralizeScaleAnimation(animation, duration)
		return nil
	end
	if type(animation.SetScaleFrom) == "function" and type(animation.SetScaleTo) == "function" then
		animation:SetScaleFrom(fromX, fromY)
		animation:SetScaleTo(toX, toY)
	else
		return nil
	end
	if type(animation.SetOrigin) == "function" then
		animation:SetOrigin("CENTER", 0, 0)
	end
	animation:SetDuration(duration)
	if startDelay and startDelay > 0 and type(animation.SetStartDelay) == "function" then
		animation:SetStartDelay(startDelay)
	end
	if type(animation.SetSmoothing) == "function" then
		animation:SetSmoothing("OUT")
	end
	return animation
end

local function setFallbackColor(texture, r, g, b, a)
	if not texture then
		return false
	end
	if type(texture.SetColorTexture) == "function" then
		local ok = pcall(texture.SetColorTexture, texture, r, g, b, a)
		return ok == true
	end
	if type(texture.SetTexture) == "function" then
		local ok = pcall(texture.SetTexture, texture, "Interface\\Buttons\\WHITE8X8")
		if ok and type(texture.SetVertexColor) == "function" then
			pcall(texture.SetVertexColor, texture, r, g, b, a)
		end
		return ok == true
	end
	return false
end

local function stopToastSound()
	local handle = Toast._soundHandle
	Toast._soundHandle = nil
	if type(handle) == "number" and StopSound then
		pcall(StopSound, handle)
	end
end

local function rememberSoundHandle(success, handle)
	if success == true and type(handle) == "number" then
		Toast._soundHandle = handle
	end
	return success == true
end

local function playToastSound()
	stopToastSound()
	local soundPath = GF.TOP_NOTICE_TOAST_SOUND
		or GF.JOIN_ANNOUNCE_TOAST_SOUND
	if PlaySoundFile and type(soundPath) == "string" and soundPath ~= "" then
		local ok, success, handle = pcall(PlaySoundFile, soundPath, "Master")
		if ok and rememberSoundHandle(success, handle) then
			return true
		end
	end
	if PlaySound and _G.SOUNDKIT then
		local soundKit = _G.SOUNDKIT.UI_SCENARIO_STAGE_END
			or _G.SOUNDKIT.UI_SCENARIO_ENDING
			or _G.SOUNDKIT[FALLBACK_SOUND]
		if soundKit then
			local ok, success, handle = pcall(PlaySound, soundKit)
			if ok then
				rememberSoundHandle(success, handle)
				return success == true
			end
		end
	end
	return false
end

local function cancelDisplayTimer()
	local timer = Toast._displayTimer
	Toast._displayTimer = nil
	if timer and type(timer.Cancel) == "function" then
		pcall(timer.Cancel, timer)
	end
end

local function applyToastFont(text, size, maximumWidth, minimumSize)
	text._gfFontSizeOverride = size
	if GF.Font and type(GF.Font.SetFitWidth) == "function" then
		GF.Font.SetFitWidth(text, maximumWidth, minimumSize)
		return
	end
	if GF.Font and type(GF.Font.ApplyToFontString) == "function" then
		GF.Font.ApplyToFontString(text, "Fancy30Font")
		return
	end
	if type(text.GetFont) == "function" and type(text.SetFont) == "function" then
		local ok, path, _, flags = pcall(text.GetFont, text)
		if ok and type(path) == "string" and path ~= "" then
			pcall(text.SetFont, text, path, size, flags or "")
			return
		end
	end
	if type(text.SetFont) == "function" then
		pcall(text.SetFont, text, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
	end
end

local function getTextWidthBudget()
	return TEXT_SAFE_W
end

local function getUnboundedTextWidth(text)
	local method = text and (text.GetUnboundedStringWidth or text.GetStringWidth)
	if type(method) ~= "function" then
		return nil
	end
	local ok, rawWidth = pcall(method, text)
	if not ok then
		return nil
	end
	local numberOk, width = pcall(tonumber, rawWidth)
	return numberOk and width or nil
end

local function isTextOverflowing(text, widthBudget)
	local width = getUnboundedTextWidth(text)
	if width and width > widthBudget then
		return true
	end
	if text and type(text.IsTruncated) == "function" then
		local ok, truncated = pcall(text.IsTruncated, text)
		if ok and truncated == true then
			return true
		end
	end
	return false
end

local function resetSingleLineLayout(text)
	text:SetHeight(SINGLE_LINE_HEIGHT)
	text:SetWordWrap(false)
	if type(text.SetNonSpaceWrap) == "function" then
		text:SetNonSpaceWrap(false)
	end
	if type(text.SetMaxLines) == "function" then
		text:SetMaxLines(1)
	end
	applyToastFont(text, SINGLE_LINE_SIZE, nil, nil)
end

local function setTextAnchor(text, relativeTo, offsetY)
	if type(text.ClearAllPoints) == "function" then
		text:ClearAllPoints()
	end
	text:SetPoint("CENTER", relativeTo, "CENTER", 0, offsetY)
end

local function setBlockTextLayout(text)
	text:SetHeight(BLOCK_TEXT_HEIGHT)
	text:SetWordWrap(true)
	if type(text.SetNonSpaceWrap) == "function" then
		text:SetNonSpaceWrap(true)
	end
	if type(text.SetMaxLines) == "function" then
		text:SetMaxLines(BLOCK_TEXT_MAX_LINES)
	end
	applyToastFont(text, BLOCK_TEXT_SIZE, nil, nil)
end

local function updateTextLayout(frame, message)
	local widthBudget = getTextWidthBudget()
	setRegionShown(frame.subtitle, false)
	frame.subtitle:SetText("")
	setTextAnchor(frame.text, frame, TEXT_CENTER_OFFSET_Y)
	resetSingleLineLayout(frame.text)
	frame.text:SetText(message)
	if not isTextOverflowing(frame.text, widthBudget) then
		frame._gfTopNoticeTextLayout = "single"
		return TOAST_DISPLAY_SECONDS
	end
	applyToastFont(frame.text, SINGLE_LINE_SIZE, widthBudget, SINGLE_LINE_MIN_SIZE)
	if not isTextOverflowing(frame.text, widthBudget) then
		frame._gfTopNoticeTextLayout = "single"
		return TOAST_DISPLAY_SECONDS
	end
	setBlockTextLayout(frame.text)
	frame.text:SetText(message)
	frame._gfTopNoticeTextLayout = "block"
	return TOAST_LONG_DISPLAY_SECONDS
end

local function updateJoinTextLayout(frame, activityTitle, listingTitle, wideSubtitle)
	local widthBudget = getTextWidthBudget()
	setTextAnchor(frame.text, frame, JOIN_TITLE_OFFSET_Y)
	resetSingleLineLayout(frame.text)
	frame.text:SetText(activityTitle)
	if isTextOverflowing(frame.text, widthBudget) then
		applyToastFont(frame.text, SINGLE_LINE_SIZE, widthBudget,
			SINGLE_LINE_MIN_SIZE)
	end

	setTextAnchor(frame.subtitle, frame, JOIN_SUBTITLE_OFFSET_Y)
	-- Long instructions may use the full gold-line width while retaining the
	-- same scene and two-line layout. Reset this on every structured notice.
	local subtitleWidth = wideSubtitle and FALLBACK_LINE_W or widthBudget
	frame.subtitle:SetWidth(subtitleWidth)
	frame.subtitle:SetHeight(JOIN_SUBTITLE_HEIGHT)
	frame.subtitle:SetWordWrap(false)
	if type(frame.subtitle.SetNonSpaceWrap) == "function" then
		frame.subtitle:SetNonSpaceWrap(false)
	end
	if type(frame.subtitle.SetMaxLines) == "function" then
		frame.subtitle:SetMaxLines(1)
	end
	frame.subtitle:SetText(listingTitle)
	applyToastFont(frame.subtitle, JOIN_SUBTITLE_SIZE, subtitleWidth,
		JOIN_SUBTITLE_MIN_SIZE)
	setRegionShown(frame.subtitle, true)
	frame._gfTopNoticeTextLayout = "join"
	return TOAST_DISPLAY_SECONDS
end

function Toast:Init()
	if self.frame then
		return self.frame
	end
	local frame = CreateFrame("Frame", "GroupFinderTopNoticeToast", UIParent)
	frame:SetSize(TOAST_W, TOAST_H)
	frame:SetPoint("TOP", UIParent, "TOP", 0, TOAST_TOP_OFFSET_Y)
	frame:SetFrameStrata("HIGH")
	frame:SetFrameLevel(5000)
	frame:EnableMouse(false)
	frame:SetAlpha(1)
	frame:Hide()

	local blackBG = frame:CreateTexture(nil, "BACKGROUND")
	-- Match EventToastManager's inherited BlackBG geometry before Scenario
	-- replaces its atlas without requesting that atlas's one-pixel width.
	setTextureSize(blackBG, BLACK_BG_W, 103)
	local blackReady = setAtlas(blackBG, SCENARIO_BLACK_ATLAS, false)
	-- Blizzard's Scenario manager inherits a 326 px wide BlackBG, swaps the
	-- atlas without adopting its width, and only fixes the final height to 64.
	-- This explicit equivalent keeps our independently-created Texture from
	-- stretching the one-pixel evergreen atlas across the old 644 px canvas.
	setTextureHeight(blackBG, BLACK_BG_H)
	setTexturePoint(blackBG, "BOTTOM", frame, "BOTTOM", 0, 0)
	if not blackReady then
		blackReady = setFallbackColor(blackBG, 0, 0, 0, 1)
		setRegionShown(blackBG, blackReady)
	end
	setRegionAlpha(blackBG, BLACK_BG_ALPHA)

	local lineTop, lineTopReady = createSceneTexture(
		frame, "BORDER", SCENARIO_LINE_TOP_ATLAS, true)
	setTexturePoint(lineTop, "TOP", frame, "TOP", 0, -5)
	if not lineTopReady then
		lineTopReady = setFallbackColor(lineTop, 1, 233 / 255, 174 / 255, 1)
		setTextureSize(lineTop, FALLBACK_LINE_W, FALLBACK_LINE_H)
		setRegionShown(lineTop, lineTopReady)
	end
	local lineBottom, lineBottomReady = createSceneTexture(
		frame, "BORDER", SCENARIO_LINE_BOTTOM_ATLAS, true)
	setTexturePoint(lineBottom, "BOTTOM", frame, "BOTTOM", 0, -4)
	if not lineBottomReady then
		lineBottomReady = setFallbackColor(lineBottom, 1, 233 / 255, 174 / 255, 1)
		setTextureSize(lineBottom, FALLBACK_LINE_W, FALLBACK_LINE_H)
		setRegionShown(lineBottom, lineBottomReady)
	end

	local banner = CreateFrame("Frame", nil, frame)
	banner:SetSize(418, 72)
	banner:SetPoint("CENTER", frame, "CENTER", 0, 0)
	banner:EnableMouse(false)

	local patternTop, patternTopReady = createSceneTexture(
		banner, "BACKGROUND", SCENARIO_PATTERN_ATLAS, true)
	setTexturePoint(patternTop, "BOTTOM", banner, "TOP", 0, -6)
	local patternBottom, patternBottomReady = createSceneTexture(
		banner, "BACKGROUND", SCENARIO_PATTERN_ATLAS, true)
	setTexturePoint(patternBottom, "TOP", banner, "BOTTOM", 0, -2)
	if patternBottom and type(patternBottom.SetTexCoord) == "function" then
		patternBottom:SetTexCoord(0, 1, 1, 0)
	end
	setRegionAlpha(patternBottom, 0.5)

	local filigreeTop, filigreeTopReady = createSceneTexture(
		banner, "OVERLAY", SCENARIO_FILIGREE_TOP_ATLAS, true)
	setTexturePoint(filigreeTop, "TOP", banner, "TOP", 0, 2)
	local filigreeBottom, filigreeBottomReady = createSceneTexture(
		banner, "OVERLAY", SCENARIO_FILIGREE_BOTTOM_ATLAS, true)
	setTexturePoint(filigreeBottom, "BOTTOM", banner, "BOTTOM", 0, -7)

	local bannerReady = patternTopReady and patternBottomReady
		and filigreeTopReady and filigreeBottomReady
	setRegionShown(banner, bannerReady)

	local titleBG = frame:CreateTexture(nil, "BORDER")
	local titleReady = false
	if not bannerReady then
		titleReady = setToastBackgroundAtlas(titleBG)
	end
	setTexturePoint(titleBG, "CENTER", frame, "CENTER", 0, 0)
	setRegionShown(titleBG, titleReady)

	local textHost = CreateFrame("Frame", nil, frame)
	textHost:SetAllPoints(frame)
	textHost:EnableMouse(false)
	if type(textHost.SetFrameLevel) == "function" and type(frame.GetFrameLevel) == "function" then
		textHost:SetFrameLevel(frame:GetFrameLevel() + 2)
	end
	local text = GF.UI.CreateFontString(textHost, "OVERLAY", "Fancy30Font")
	if text and type(text.SetDrawLayer) == "function" then
		text:SetDrawLayer("OVERLAY", 7)
	end
	text:SetPoint("CENTER", frame, "CENTER", 0, TEXT_CENTER_OFFSET_Y)
	text:SetWidth(TEXT_SAFE_W)
	text:SetHeight(SINGLE_LINE_HEIGHT)
	text:SetJustifyH("CENTER")
	text:SetJustifyV("MIDDLE")
	text:SetWordWrap(false)
	if type(text.SetNonSpaceWrap) == "function" then
		text:SetNonSpaceWrap(false)
	end
	if type(text.SetMaxLines) == "function" then
		text:SetMaxLines(1)
	end
	applyScenarioStageColor(text)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	text._gfFontSizeOverride = SINGLE_LINE_SIZE
	text._gfFontFlagsOverride = ""
	text._gfIgnoreFontScale = true
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(text, "Fancy30Font")
	elseif text.SetFont then
		text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", SINGLE_LINE_SIZE, "")
	end

	local subtitle = GF.UI.CreateFontString(textHost, "OVERLAY", "Fancy30Font")
	if subtitle and type(subtitle.SetDrawLayer) == "function" then
		subtitle:SetDrawLayer("OVERLAY", 7)
	end
	subtitle:SetPoint("CENTER", frame, "CENTER", 0, JOIN_SUBTITLE_OFFSET_Y)
	subtitle:SetWidth(TEXT_SAFE_W)
	subtitle:SetHeight(JOIN_SUBTITLE_HEIGHT)
	subtitle:SetJustifyH("CENTER")
	subtitle:SetJustifyV("MIDDLE")
	subtitle:SetWordWrap(false)
	if type(subtitle.SetNonSpaceWrap) == "function" then
		subtitle:SetNonSpaceWrap(false)
	end
	if type(subtitle.SetMaxLines) == "function" then
		subtitle:SetMaxLines(1)
	end
	applyScenarioStageColor(subtitle)
	subtitle:SetShadowColor(0, 0, 0, 1)
	subtitle:SetShadowOffset(1, -1)
	subtitle._gfFontSizeOverride = JOIN_SUBTITLE_SIZE
	subtitle._gfFontFlagsOverride = ""
	subtitle._gfIgnoreFontScale = true
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(subtitle, "Fancy30Font")
	elseif subtitle.SetFont then
		subtitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
			JOIN_SUBTITLE_SIZE, "")
	end
	setRegionShown(subtitle, false)

	local reveal = frame:CreateAnimationGroup()
	if lineTopReady then
		addScaleAnimation(reveal, lineTop, 0.001, 1, 1, 1, REVEAL_SECONDS, 0)
	end
	if lineBottomReady then
		addScaleAnimation(reveal, lineBottom, 0.001, 1, 1, 1, REVEAL_SECONDS, 0)
	end
	-- Scenario disables the inherited BlackBG grow animation; the 0.6 shadow
	-- is present throughout while only the two gold lines expand.
	if titleReady then
		addScaleAnimation(reveal, titleBG, 0.001, 1, 1, 1, CONTENT_REVEAL_SECONDS, 0)
	elseif bannerReady then
		addAlphaAnimation(reveal, banner, 0, 1, CONTENT_REVEAL_SECONDS, 0)
	end
	addAlphaAnimation(reveal, text, 0, 1, CONTENT_REVEAL_SECONDS, 0)
	addAlphaAnimation(reveal, subtitle, 0, 1, CONTENT_REVEAL_SECONDS, 0)

	local fade = frame:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(0)
	alpha:SetDuration(TOAST_FADE_SECONDS)
	alpha:SetSmoothing("OUT")
	fade:SetScript("OnFinished", function()
		if frame._gfTopNoticeFadeToken ~= Toast._token then
			return
		end
		frame._gfTopNoticeFadeToken = nil
		frame:Hide()
		frame:SetAlpha(1)
	end)

	frame.bg = titleReady and titleBG or blackBG
	frame.blackBG = blackBG
	frame.lineTop = lineTop
	frame.lineBottom = lineBottom
	frame.titleBG = titleBG
	frame.banner = banner
	frame.patternTop = patternTop
	frame.patternBottom = patternBottom
	frame.filigreeTop = filigreeTop
	frame.filigreeBottom = filigreeBottom
	frame.sceneReady = blackReady and lineTopReady and lineBottomReady
	frame.titleReady = titleReady
	frame.textHost = textHost
	frame.text = text
	frame.subtitle = subtitle
	frame.reveal = reveal
	frame.fade = fade
	self.frame = frame
	return frame
end

function Toast:Show(message, opts)
	opts = type(opts) == "table" and opts or {}
	local normalize = GF.NormalizeTopNoticeMessage
	local text = type(normalize) == "function" and normalize(message) or message
	if type(text) ~= "string" or text == "" then
		return false
	end
	local subtitle
	if opts.subtitle ~= nil then
		subtitle = type(normalize) == "function"
			and normalize(opts.subtitle) or opts.subtitle
		if type(subtitle) ~= "string" or subtitle == "" then
			return false
		end
	end
	local frame = self:Init()
	self._token = (self._token or 0) + 1
	local token = self._token
	cancelDisplayTimer()
	frame._gfTopNoticeFadeToken = nil
	frame._gfTopNoticeRevealToken = nil
	if frame.reveal and frame.reveal:IsPlaying() then
		frame.reveal:Stop()
	end
	if frame.fade and frame.fade:IsPlaying() then
		frame.fade:Stop()
	end
	frame:SetAlpha(1)
	setRegionAlpha(frame.blackBG, BLACK_BG_ALPHA)
	setRegionAlpha(frame.banner, 1)
	setRegionAlpha(frame.titleBG, 1)
	setRegionAlpha(frame.text, 1)
	setRegionAlpha(frame.subtitle, 1)
	applyScenarioStageColor(frame.text)
	applyScenarioStageColor(frame.subtitle)
	local displaySeconds
	if subtitle then
		displaySeconds = updateJoinTextLayout(frame, text, subtitle, opts.wideSubtitle == true)
	else
		displaySeconds = updateTextLayout(frame, text)
	end
	frame:Show()
	frame._gfTopNoticeRevealToken = token
	if frame.reveal then
		frame.reveal:SetScript("OnFinished", function()
			if Toast._token ~= token
				or frame._gfTopNoticeRevealToken ~= token
			then
				return
			end
			frame._gfTopNoticeRevealToken = nil
			setRegionAlpha(frame.blackBG, BLACK_BG_ALPHA)
			setRegionAlpha(frame.banner, 1)
			setRegionAlpha(frame.titleBG, 1)
			setRegionAlpha(frame.text, 1)
			setRegionAlpha(frame.subtitle, 1)
		end)
		frame.reveal:Play()
	else
		frame._gfTopNoticeRevealToken = nil
	end
	if opts.playSound == false then
		stopToastSound()
	else
		playToastSound()
	end

	local function beginFade()
		if Toast._token ~= token or not frame:IsShown() then
			return
		end
		frame._gfTopNoticeFadeToken = token
		if frame.fade then
			frame.fade:Play()
		else
			frame:Hide()
		end
	end
	if C_Timer and C_Timer.NewTimer then
		local timer
		timer = C_Timer.NewTimer(displaySeconds, function()
			if Toast._displayTimer == timer then
				Toast._displayTimer = nil
			end
			beginFade()
		end)
		self._displayTimer = timer
	elseif C_Timer and C_Timer.After then
		C_Timer.After(displaySeconds, beginFade)
	end
	return true
end

function GF.ShowTopNotice(message, opts)
	return Toast:Show(message, opts)
end

-- 保留既有进组入口；开关只在 JoinAnnounce producer 中判断，
-- 此兼容 facade 与共享 Toast 本身都不读取 joinAnnounceEnabled。
GF.JoinAnnounceToast = GF.JoinAnnounceToast or {}
function GF.JoinAnnounceToast:Init()
	return Toast:Init()
end

function GF.JoinAnnounceToast:Show(activityTitle, listingTitle, opts)
	-- Retain the old one-message facade shape for external callers while the
	-- built-in join producer supplies two structured lines.
	if type(listingTitle) == "table" and opts == nil then
		return Toast:Show(activityTitle, listingTitle)
	end
	if listingTitle == nil then
		return Toast:Show(activityTitle, opts)
	end
	local toastOptions = {}
	if type(opts) == "table" then
		for key, value in pairs(opts) do
			toastOptions[key] = value
		end
	end
	toastOptions.subtitle = listingTitle
	return Toast:Show(activityTitle, toastOptions)
end
