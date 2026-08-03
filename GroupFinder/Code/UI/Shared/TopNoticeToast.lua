local _, GF = ...

GF.TopNoticeToast = GF.TopNoticeToast or {}
local Toast = GF.TopNoticeToast

local TOAST_W = 644
local TOAST_H = 220
local TOAST_TOP_OFFSET_Y = -82
local TOAST_DISPLAY_SECONDS = 3.8
local TOAST_LONG_DISPLAY_SECONDS = 5.0
local TOAST_FADE_SECONDS = 0.35
local TEXT_INSET_X = 42
local SINGLE_LINE_HEIGHT = 30
local SINGLE_LINE_SIZE = 18
local SINGLE_LINE_MIN_SIZE = 14
local BLOCK_TEXT_HEIGHT = 48
local BLOCK_TEXT_SIZE = 15
local BLOCK_TEXT_MAX_LINES = 2
local FALLBACK_SOUND = "IG_MAINMENU_OPTION_CHECKBOX_ON"
local FALLBACK_ATLAS = "evergreen-scenario-TitleBG"
local DEFAULT_GOLD = { 1, 0.82, 0, 1 }

local function applyToastBlendMode(texture, atlas)
	if texture and texture.SetBlendMode then
		texture:SetBlendMode(type(atlas) == "string" and atlas:match("%-add$") and "ADD" or "BLEND")
	end
end

local function setToastBackgroundAtlas(texture)
	local atlas = GF.TOP_NOTICE_TOAST_ATLAS
		or GF.JOIN_ANNOUNCE_TOAST_ATLAS
		or FALLBACK_ATLAS
	if GF.UI and GF.UI.TrySetAtlas and GF.UI.TrySetAtlas(texture, atlas, true) then
		applyToastBlendMode(texture, atlas)
		texture:Show()
		return true
	end
	if texture.SetAtlas then
		local ok = pcall(texture.SetAtlas, texture, atlas, true)
		if ok then
			applyToastBlendMode(texture, atlas)
			texture:Show()
			return true
		end
	end
	texture:Hide()
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
		GF.Font.ApplyToFontString(text, "GameFontNormalLarge")
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

local function getTextWidthBudget(frame)
	local frameWidth = TOAST_W
	if frame and type(frame.GetWidth) == "function" then
		local ok, width = pcall(frame.GetWidth, frame)
		width = ok and tonumber(width) or nil
		if width and width > 0 then
			frameWidth = width
		end
	end
	return math.max(1, frameWidth - TEXT_INSET_X * 2)
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
	local widthBudget = getTextWidthBudget(frame)
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

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	if setToastBackgroundAtlas(bg) then
		local atlasW, atlasH = bg:GetSize()
		if atlasW and atlasW > 0 and atlasH and atlasH > 0 then
			frame:SetSize(atlasW, atlasH)
		end
	end
	bg:SetAllPoints(frame)

	local text = GF.UI.CreateFontString(frame, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("LEFT", frame, "LEFT", TEXT_INSET_X, 0)
	text:SetPoint("RIGHT", frame, "RIGHT", -TEXT_INSET_X, 0)
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
	text:SetTextColor(DEFAULT_GOLD[1], DEFAULT_GOLD[2], DEFAULT_GOLD[3], DEFAULT_GOLD[4])
	text:SetShadowColor(0, 0, 0, 0.95)
	text:SetShadowOffset(1, -1)
	text._gfFontSizeOverride = SINGLE_LINE_SIZE
	text._gfIgnoreFontScale = true
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(text, "GameFontNormalLarge")
	elseif text.SetFont then
		text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", SINGLE_LINE_SIZE, "")
	end

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

	frame.bg = bg
	frame.text = text
	frame.fade = fade
	self.frame = frame
	return frame
end

function Toast:Show(message, opts)
	local normalize = GF.NormalizeTopNoticeMessage
	local text = type(normalize) == "function" and normalize(message) or message
	if type(text) ~= "string" or text == "" then
		return false
	end
	opts = opts or {}
	local frame = self:Init()
	self._token = (self._token or 0) + 1
	local token = self._token
	cancelDisplayTimer()
	frame._gfTopNoticeFadeToken = nil
	if frame.fade and frame.fade:IsPlaying() then
		frame.fade:Stop()
	end
	frame:SetAlpha(1)
	frame.text:SetTextColor(DEFAULT_GOLD[1], DEFAULT_GOLD[2], DEFAULT_GOLD[3], DEFAULT_GOLD[4])
	local displaySeconds = updateTextLayout(frame, text)
	frame:Show()
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

function GF.JoinAnnounceToast:Show(message, opts)
	return Toast:Show(message, opts)
end
