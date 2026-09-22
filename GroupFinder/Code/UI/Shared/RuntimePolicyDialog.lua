local _, GF = ...

GF.RuntimePolicyDialog = GF.RuntimePolicyDialog or {}
local Dialog = GF.RuntimePolicyDialog

local DIALOG_NAME = "GroupFinderRuntimePolicyDialog"
local DIALOG_WIDTH = 390
local DIALOG_DENIED_HEIGHT = 144
local DIALOG_DIAGNOSTIC_HEIGHT = 184
local CONTENT_INSET = 26
local TITLE_ACCENT_ATLAS = "evergreen-scenario-line-top"
local TITLE_ACCENT_WIDTH = 72
local TITLE_ACCENT_HEIGHT = 5
local TITLE_ACCENT_COLOR = { 1, 0.82, 0, 1 }
local TITLE_FONT_SIZE = 17
local MESSAGE_FONT_SIZE = 14
local ACTION_FONT_SIZE = 12
local MESSAGE_LINE_SPACING = 4

local function T(key, fallback)
	local locale = GF.L or {}
	return locale[key] or fallback or key
end

local function formatText(formatKey, fallback, value)
	local formatString = T(formatKey, fallback)
	local ok, text = pcall(string.format, formatString, value)
	return ok and text or tostring(value or "")
end

local function copyForStatus(status)
	if status == "denied" then
		return {
			message = T("RUNTIME_POLICY_DENIED_MESSAGE",
				"This character is restricted from using GroupFinder. "
					.. "If you have an objection, contact the add-on author through an official "
					.. "channel to submit an appeal."),
		}
	end
	if status == "pending" then
		return {
			message = T("RUNTIME_POLICY_IDENTITY_UNAVAILABLE_MESSAGE",
				"GroupFinder could not verify the current character and has stopped."),
			action = T("RUNTIME_POLICY_IDENTITY_UNAVAILABLE_ACTION",
				"Reload the interface and try again."),
			code = "GF-IDENTITY-001",
		}
	end
	return {
		message = T("RUNTIME_POLICY_INVALID_MESSAGE",
			"GroupFinder's core runtime policy does not match the official release."),
		action = T("RUNTIME_POLICY_INVALID_ACTION",
			"Reinstall it from the official distribution."),
		code = "GF-INTEGRITY-001",
	}
end

local function applyFixedFont(fontString, templateName, size, flags)
	local fontObject = _G and _G[templateName]
	if not (fontString and fontString.SetFont and fontObject
		and type(fontObject.GetFont) == "function")
	then
		return
	end
	local ok, path = pcall(fontObject.GetFont, fontObject)
	if ok and type(path) == "string" and path ~= "" then
		pcall(fontString.SetFont, fontString, path, size, flags or "")
	end
end

local function createText(frame, template, size, color)
	local text = frame:CreateFontString(nil, "OVERLAY", template)
	applyFixedFont(text, template, size, "")
	text:SetJustifyH("CENTER")
	text:SetJustifyV("MIDDLE")
	text:SetWordWrap(true)
	if text.SetTextColor then
		text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	end
	return text
end

local function trySetAtlas(texture, atlas, useAtlasSize)
	if not texture then
		return false
	end
	if GF.UI and type(GF.UI.TrySetAtlas) == "function"
		and GF.UI.TrySetAtlas(texture, atlas, useAtlasSize == true)
	then
		return true
	end
	if type(texture.SetAtlas) == "function" then
		local ok, result = pcall(
			texture.SetAtlas, texture, atlas, useAtlasSize == true)
		return ok and result ~= false
	end
	return false
end

local function getTitleAccentAtlasInfo()
	if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
		local info = C_Texture.GetAtlasInfo(TITLE_ACCENT_ATLAS)
		if info
			and type(info.leftTexCoord) == "number"
			and type(info.rightTexCoord) == "number"
			and type(info.topTexCoord) == "number"
			and type(info.bottomTexCoord) == "number"
		then
			return info
		end
	end
	return nil
end

local function createAccentLine(frame, side)
	local line = frame:CreateTexture(nil, "ARTWORK")
	local hasAtlas = false
	local info = getTitleAccentAtlasInfo()
	local firstHalf = side == "left"
	local relativeLeft = firstHalf and 0 or 0.5
	local relativeRight = firstHalf and 0.5 or 1
	local file = info and (info.file or info.filename)
	if file and type(line.SetTexture) == "function"
		and type(line.SetTexCoord) == "function"
	then
		local atlasWidth = info.rightTexCoord - info.leftTexCoord
		local split = info.leftTexCoord + (atlasWidth * 0.5)
		line:SetTexture(file)
		line:SetTexCoord(
			firstHalf and info.leftTexCoord or split,
			firstHalf and split or info.rightTexCoord,
			info.topTexCoord,
			info.bottomTexCoord)
		hasAtlas = true
	else
		hasAtlas = trySetAtlas(line, TITLE_ACCENT_ATLAS, false)
	end
	if hasAtlas and not file and type(line.SetTexCoord) == "function" then
		line:SetTexCoord(relativeLeft, relativeRight, 0, 1)
	elseif not hasAtlas then
		line:SetColorTexture(
			TITLE_ACCENT_COLOR[1], TITLE_ACCENT_COLOR[2],
			TITLE_ACCENT_COLOR[3], TITLE_ACCENT_COLOR[4])
	end
	if hasAtlas and type(line.SetVertexColor) == "function" then
		line:SetVertexColor(
			TITLE_ACCENT_COLOR[1], TITLE_ACCENT_COLOR[2],
			TITLE_ACCENT_COLOR[3], TITLE_ACCENT_COLOR[4])
	end
	line:SetSize(TITLE_ACCENT_WIDTH, TITLE_ACCENT_HEIGHT)
	return line
end

local function centerFrame(frame)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function ensureFrame()
	if Dialog.frame then
		return Dialog.frame
	end
	if type(CreateFrame) ~= "function" or UIParent == nil then
		return nil
	end

	local frame = CreateFrame("Frame", DIALOG_NAME, UIParent)
	frame:SetSize(DIALOG_WIDTH, DIALOG_DENIED_HEIGHT)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(1000)
	if frame.SetToplevel then
		frame:SetToplevel(true)
	end
	centerFrame(frame)
	frame:Hide()

	local UI = GF.UI
	if UI and type(UI.ApplyStaticPopupFrameArt) == "function" then
		UI.ApplyStaticPopupFrameArt(frame)
	end

	frame.titleText = createText(
		frame, "GameFontNormalLarge", TITLE_FONT_SIZE, { 1, 0.82, 0, 1 })
	frame.titleText:SetPoint("TOP", frame, "TOP", 0, -15)
	frame.titleText:SetHeight(20)
	frame.titleText:SetWordWrap(false)
	frame.titleText:SetMaxLines(1)
	frame.titleText:SetText(T("RUNTIME_POLICY_DIALOG_TITLE", "Service Denied"))

	frame.leftTitleAccent = createAccentLine(frame, "left")
	frame.leftTitleAccent:SetPoint(
		"RIGHT", frame.titleText, "LEFT", -12, 0)
	frame.rightTitleAccent = createAccentLine(frame, "right")
	frame.rightTitleAccent:SetPoint(
		"LEFT", frame.titleText, "RIGHT", 12, 0)

	frame.messageText = createText(
		frame, "GameFontHighlight", MESSAGE_FONT_SIZE,
		{ 0.94, 0.93, 0.90, 1 })
	frame.messageText:SetJustifyH("LEFT")
	if frame.messageText.SetSpacing then
		frame.messageText:SetSpacing(MESSAGE_LINE_SPACING)
	end
	frame.messageText:SetPoint(
		"TOPLEFT", frame, "TOPLEFT", CONTENT_INSET, -45)
	frame.messageText:SetPoint(
		"TOPRIGHT", frame, "TOPRIGHT", -CONTENT_INSET, -45)
	frame.messageText:SetHeight(48)
	if frame.messageText.SetNonSpaceWrap then
		frame.messageText:SetNonSpaceWrap(true)
	end
	if frame.messageText.SetMaxLines then
		frame.messageText:SetMaxLines(3)
	end

	frame.actionText = createText(
		frame, "GameFontNormal", ACTION_FONT_SIZE, { 1, 0.82, 0, 1 })
	frame.actionText:SetPoint(
		"TOPLEFT", frame, "TOPLEFT", CONTENT_INSET, -99)
	frame.actionText:SetPoint(
		"TOPRIGHT", frame, "TOPRIGHT", -CONTENT_INSET, -99)
	frame.actionText:SetHeight(18)
	if frame.actionText.SetMaxLines then
		frame.actionText:SetMaxLines(1)
	end

	frame.codeText = createText(
		frame, "GameFontDisableSmall", 11, { 0.55, 0.55, 0.55, 1 })
	frame.codeText:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_INSET, -123)
	frame.codeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CONTENT_INSET, -123)
	frame.codeText:SetHeight(14)
	if frame.codeText.SetMaxLines then
		frame.codeText:SetMaxLines(1)
	end

	local button = CreateFrame(
		"Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(84, 24)
	button:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
	button:SetText(T("RUNTIME_POLICY_ACCEPT", "Close"))
	if UI and type(UI.ApplyCommonPanelButtonSkin) == "function" then
		UI.ApplyCommonPanelButtonSkin(button)
	end
	local buttonText = button.GetFontString and button:GetFontString()
	if buttonText then
		buttonText._gfFontSizeOverride = 13
		buttonText._gfIgnoreFontScale = true
		applyFixedFont(buttonText, "GameFontNormal", 13, "")
	end
	button:SetScript("OnClick", function()
		if UI and type(UI.PlayUISound) == "function" then
			UI.PlayUISound("check")
		end
		frame:Hide()
	end)
	frame.acceptButton = button

	if UI and type(UI.InstallPopupOpenAnimation) == "function" then
		UI.InstallPopupOpenAnimation(frame, { preset = "dialog" })
	end

	if type(UISpecialFrames) == "table" then
		local registered = false
		for index = 1, #UISpecialFrames do
			if UISpecialFrames[index] == DIALOG_NAME then
				registered = true
				break
			end
		end
		if not registered then
			table.insert(UISpecialFrames, DIALOG_NAME)
		end
	end

	Dialog.frame = frame
	return frame
end

function Dialog:Show(status)
	local frame = ensureFrame()
	if not frame then
		return false
	end
	local copy = copyForStatus(status)
	frame:SetHeight(copy.code and DIALOG_DIAGNOSTIC_HEIGHT
		or DIALOG_DENIED_HEIGHT)
	frame.titleText:SetText(T("RUNTIME_POLICY_DIALOG_TITLE", "Service Denied"))
	frame.messageText:SetText(copy.message)
	if copy.action then
		frame.actionText:SetText(copy.action)
		frame.actionText:Show()
	else
		frame.actionText:SetText("")
		frame.actionText:Hide()
	end
	if copy.code then
		frame.codeText:SetText(formatText(
			"RUNTIME_POLICY_ERROR_CODE_FMT", "Error: %s", copy.code))
		frame.codeText:Show()
	else
		frame.codeText:SetText("")
		frame.codeText:Hide()
	end
	frame.acceptButton:SetText(T("RUNTIME_POLICY_ACCEPT", "Close"))
	centerFrame(frame)
	frame:Show()
	if frame.Raise then
		frame:Raise()
	end
	self.status = status
	self.shown = true
	return frame:IsShown() == true
end

function Dialog:Hide()
	if self.frame then
		self.frame:Hide()
	end
end

function Dialog:IsShownForSession()
	return self.shown == true
end
