local _, GF = ...

local Dialog = {}
GF.BlacklistConfirmDialog = Dialog

local STYLE = GF.PLAYER_MANAGEMENT_CONFIRM_STYLE

local function T(key, fallback)
	local locale = GF.L or {}
	return locale[key] or fallback or key
end

local function setFontSize(fontString, size)
	if not fontString or not fontString.GetFont or not fontString.SetFont then
		return
	end
	local path, _, flags = fontString:GetFont()
	if path then
		fontString:SetFont(path, size or 12, flags or "")
	end
end

local function applyButtonFontSize(button, size)
	local fontString = button and button.GetFontString
		and button:GetFontString()
	if not fontString then
		return
	end
	fontString._gfFontSizeOverride = size
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, "GameFontNormal")
	else
		setFontSize(fontString, size)
	end
end

local function setMainWindowAlpha(dialog, transparent)
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	if not (mainFrame and mainFrame.SetAlpha) then
		return
	end
	if transparent then
		if dialog._previousMainAlpha == nil then
			dialog._previousMainAlpha = mainFrame.GetAlpha
				and mainFrame:GetAlpha() or 1
		end
		mainFrame:SetAlpha(STYLE.mainAlpha)
	elseif dialog._previousMainAlpha ~= nil then
		local previous = tonumber(dialog._previousMainAlpha) or 1
		dialog._previousMainAlpha = nil
		mainFrame:SetAlpha(previous)
	end
end

local function layoutDialog(dialog)
	local message, icon = dialog.Message, dialog.Icon
	local yes, no = dialog.YesButton, dialog.NoButton
	message._gfFontSizeOverride = STYLE.messageFontSize
	setFontSize(message, STYLE.messageFontSize)
	local color = STYLE.messageColor
	message:SetTextColor(color[1], color[2], color[3], color[4])
	-- Center the icon and the actual text as one row, including short prompts.
	local maxTextWidth = math.max(1, STYLE.width - STYLE.padding * 2 - STYLE.iconSize - STYLE.iconGap)
	local textWidth = math.min(maxTextWidth, math.max(1, math.ceil(message:GetUnboundedStringWidth())))
	message:SetSize(textWidth, 0)
	local textHeight = math.max(STYLE.messageMinHeight,
		math.ceil(message:GetStringHeight()) + STYLE.messageHeightPadding)
	local bodyWidth = STYLE.iconSize + STYLE.iconGap + textWidth
	local bodyHeight = math.max(STYLE.iconSize, textHeight)
	local contentHeight = bodyHeight + STYLE.messageButtonGap + STYLE.buttonHeight
	local height = math.max(STYLE.minHeight, STYLE.padding * 2 + contentHeight)
	local bodyLeft = (STYLE.width - bodyWidth) / 2
	local bodyTop = (height - contentHeight) / 2
	local bodyCenterY = -(bodyTop + bodyHeight / 2)
	dialog:SetSize(STYLE.width, height)
	message:ClearAllPoints()
	message:SetPoint("LEFT", dialog, "TOPLEFT", bodyLeft + STYLE.iconSize + STYLE.iconGap, bodyCenterY)
	message:SetSize(textWidth, textHeight)
	icon:SetSize(STYLE.iconSize, STYLE.iconSize)
	icon:ClearAllPoints()
	icon:SetPoint("LEFT", dialog, "TOPLEFT", bodyLeft, bodyCenterY)
	for _, button in ipairs({ yes, no }) do
		button:SetSize(STYLE.buttonWidth, STYLE.buttonHeight)
		applyButtonFontSize(button, STYLE.buttonFontSize)
		button:ClearAllPoints()
	end
	-- Actions have their own full-dialog center axis, independent of title length.
	local buttonY = -(bodyTop + bodyHeight + STYLE.messageButtonGap)
	yes:SetPoint("TOP", dialog, "TOP", -(STYLE.buttonWidth + STYLE.buttonGap) / 2, buttonY)
	no:SetPoint("TOP", dialog, "TOP", (STYLE.buttonWidth + STYLE.buttonGap) / 2, buttonY)
end

local function refreshDialogLocale(dialog)
	if not dialog then
		return
	end
	local request = dialog.request or {}
	if dialog.Icon then
		dialog.Icon:SetTexture(request.iconTexture or GF.BLACKLIST_ICON_TEXTURE)
	end
	if dialog.Message then
		dialog.Message:SetText(T(
			request.messageKey,
			request.messageFallback or ""))
	end
	if dialog.YesButton then
		dialog.YesButton:SetText(T(
			request.yesKey or "BLOCKLIST_CONFIRM_YES",
			request.yesFallback or "Yes"))
	end
	if dialog.NoButton then
		dialog.NoButton:SetText(T(
			request.noKey or "BLOCKLIST_CONFIRM_NO",
			request.noFallback or "No"))
	end
	layoutDialog(dialog)
end

local function playCheckSound()
	if GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("check")
	end
end

local function createDialog()
	local dialog = CreateFrame(
		"Frame",
		"GroupFinderAddonBlacklistRemoveDialog",
		UIParent)
	dialog:SetSize(STYLE.width, STYLE.minHeight)
	dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	dialog:SetFrameStrata(STYLE.frameStrata)
	dialog:SetFrameLevel(STYLE.frameLevel)
	dialog:SetToplevel(true)
	dialog:EnableMouse(true)
	dialog:Hide()
	if GF.UI and GF.UI.ApplyStaticPopupFrameArt then
		GF.UI.ApplyStaticPopupFrameArt(dialog)
	end
	dialog.Icon = dialog:CreateTexture(nil, "ARTWORK")
	dialog.Icon:SetSize(STYLE.iconSize, STYLE.iconSize)
	dialog.Icon:SetTexture(GF.BLACKLIST_ICON_TEXTURE)
	dialog.Message = dialog:CreateFontString(
		nil, "OVERLAY", "GameFontHighlightLarge")
	dialog.Message:SetJustifyH("LEFT")
	dialog.Message:SetJustifyV("MIDDLE")
	dialog.Message:SetWordWrap(true)
	dialog.Message:SetNonSpaceWrap(true)
	dialog.Message:SetMaxLines(0)
	dialog.YesButton = GF.UI.CreatePanelButton(
		dialog, T("BLOCKLIST_CONFIRM_YES", "Yes"), STYLE.buttonWidth)
	dialog.YesButton:SetSize(STYLE.buttonWidth, STYLE.buttonHeight)
	applyButtonFontSize(dialog.YesButton, STYLE.buttonFontSize)
	dialog.NoButton = GF.UI.CreatePanelButton(
		dialog, T("BLOCKLIST_CONFIRM_NO", "No"), STYLE.buttonWidth)
	dialog.NoButton:SetSize(STYLE.buttonWidth, STYLE.buttonHeight)
	applyButtonFontSize(dialog.NoButton, STYLE.buttonFontSize)
	dialog.YesButton:SetScript("OnClick", function()
		playCheckSound()
		local request = dialog.request
		if not request then
			return
		end
		local accepted = type(request.onAccept) ~= "function"
			or request.onAccept() == true
		if accepted and dialog.request == request then
			dialog._acceptedRequest = request
			dialog:Hide()
		end
	end)
	dialog.NoButton:SetScript("OnClick", function()
		playCheckSound()
		dialog:Hide()
	end)
	dialog:SetScript("OnShow", function(self)
		layoutDialog(self)
		setMainWindowAlpha(self, true)
		if self.EnableKeyboard then
			self:EnableKeyboard(true)
		end
	end)
	dialog:SetScript("OnHide", function(self)
		setMainWindowAlpha(self, false)
		local request = self.request
		local accepted = request ~= nil
			and self._acceptedRequest == request
		self.request = nil
		self._acceptedRequest = nil
		if self.EnableKeyboard then
			self:EnableKeyboard(false)
		end
		if not accepted and request
			and type(request.onCancel) == "function"
		then
			request.onCancel()
		end
	end)
	dialog:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:Hide()
		end
	end)
	if GF.UI and GF.UI.InstallPopupOpenAnimation then
		GF.UI.InstallPopupOpenAnimation(dialog, { preset = STYLE.animationPreset })
	end
	return dialog
end

local function ensureDialog()
	if not Dialog.frame then
		Dialog.frame = createDialog()
	end
	return Dialog.frame
end

function Dialog:Show(options)
	local dialog = ensureDialog()
	if dialog:IsShown() then
		dialog:Hide()
	end
	dialog.request = type(options) == "table" and options or {}
	refreshDialogLocale(dialog)
	dialog:ClearAllPoints()
	dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	dialog:Show()
	if dialog.Raise then
		dialog:Raise()
	end
	return true
end

function Dialog:Hide(request)
	if self.frame and self.frame:IsShown()
		and (request == nil or self.frame.request == request) then
		self.frame:Hide()
		return true
	end
	return false
end

function Dialog:RefreshLocale()
	if self.frame then
		refreshDialogLocale(self.frame)
	end
end
