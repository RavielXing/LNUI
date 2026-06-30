local _, GF = ...

GF.JoinAnnounceToast = {}
local JT = GF.JoinAnnounceToast

local TOAST_W = 644
local TOAST_H = 220
local TOAST_TOP_OFFSET_Y = -82
local TOAST_DISPLAY_SECONDS = 3.8
local TOAST_FADE_SECONDS = 0.35
local FALLBACK_SOUND = "IG_MAINMENU_OPTION_CHECKBOX_ON"
local FALLBACK_ATLAS = "evergreen-scenario-TitleBG"

local function applyToastBlendMode(texture, atlas)
	if texture and texture.SetBlendMode then
		texture:SetBlendMode(type(atlas) == "string" and atlas:match("%-add$") and "ADD" or "BLEND")
	end
end

local function setToastBackgroundAtlas(texture)
	local atlas = GF.JOIN_ANNOUNCE_TOAST_ATLAS or FALLBACK_ATLAS
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

local function playToastSound()
	local soundPath = GF.JOIN_ANNOUNCE_TOAST_SOUND or "Interface\\AddOns\\GroupFinder\\Sounds\\Glass.aiff"
	if PlaySoundFile then
		local ok, success = pcall(PlaySoundFile, soundPath, "Master")
		if ok and success ~= false then
			return
		end
	end
	if PlaySound and _G.SOUNDKIT then
		local soundKit = _G.SOUNDKIT.UI_SCENARIO_STAGE_END
			or _G.SOUNDKIT.UI_SCENARIO_ENDING
			or _G.SOUNDKIT[FALLBACK_SOUND]
		if soundKit then
			PlaySound(soundKit)
		end
	end
end

function JT:Init()
	if self.frame then
		return
	end
	local frame = CreateFrame("Frame", "GroupFinderJoinAnnounceToast", UIParent)
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
	text:SetPoint("LEFT", frame, "LEFT", 42, 0)
	text:SetPoint("RIGHT", frame, "RIGHT", -42, 0)
	text:SetHeight(30)
	text:SetJustifyH("CENTER")
	text:SetJustifyV("MIDDLE")
	text:SetWordWrap(false)
	text:SetTextColor(1, 0.82, 0, 1)
	text:SetShadowColor(0, 0, 0, 0.95)
	text:SetShadowOffset(1, -1)
	text._gfFontSizeOverride = 18
	text._gfIgnoreFontScale = true
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(text, "GameFontNormalLarge")
	elseif text.SetFont then
		text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 18, "")
	end

	local fade = frame:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(0)
	alpha:SetDuration(TOAST_FADE_SECONDS)
	alpha:SetSmoothing("OUT")
	fade:SetScript("OnFinished", function()
		frame:Hide()
		frame:SetAlpha(1)
	end)

	frame.bg = bg
	frame.text = text
	frame.fade = fade
	self.frame = frame
end

function JT:Show(message, opts)
	if not message or message == "" then
		return
	end
	self:Init()
	local frame = self.frame
	self._token = (self._token or 0) + 1
	local token = self._token
	if frame.fade and frame.fade:IsPlaying() then
		frame.fade:Stop()
	end
	frame:SetAlpha(1)
	frame.text:SetText(message)
	frame:Show()
	if not opts or opts.playSound ~= false then
		playToastSound()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(TOAST_DISPLAY_SECONDS, function()
			if JT._token ~= token or not frame:IsShown() then
				return
			end
			if frame.fade then
				frame.fade:Play()
			else
				frame:Hide()
			end
		end)
	end
end
