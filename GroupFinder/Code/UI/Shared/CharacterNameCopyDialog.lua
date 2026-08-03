local _, GF = ...

GF.UI = GF.UI or {}
local UI = GF.UI
local SHARED_DIALOG_STYLE = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}

local CHARACTER_NAME_COPY_DIALOG_STYLE = {
	DIALOG_W = SHARED_DIALOG_STYLE.WIDTH or 420,
	DIALOG_H = SHARED_DIALOG_STYLE.HEIGHT or 176,
	DIALOG_LEVEL_OFFSET = SHARED_DIALOG_STYLE.LEVEL_OFFSET or 18,
	DIALOG_PRESENT_OFFSET_Y = 20,
	CONTENT_INSET_X = SHARED_DIALOG_STYLE.CONTENT_INSET_X or 36,
	CONTENT_BOTTOM_INSET = SHARED_DIALOG_STYLE.CONTENT_BOTTOM_INSET or 18,
	INPUT_CENTER_OFFSET_Y = SHARED_DIALOG_STYLE.COPY_INPUT_CENTER_OFFSET_Y or -12,
	HINT_FONT_SIZE = SHARED_DIALOG_STYLE.SECONDARY_TEXT_FONT_SIZE or 12,
	HINT_TO_INPUT_GAP = SHARED_DIALOG_STYLE.COPY_HINT_TO_INPUT_GAP or 10,
	INPUT_W = SHARED_DIALOG_STYLE.INPUT_WIDTH or 330,
	INPUT_H = SHARED_DIALOG_STYLE.INPUT_HEIGHT or 30,
	INPUT_EDIT_INSET_X = 10,
	INPUT_EDIT_TOP_OFFSET_Y = -3,
	INPUT_EDIT_BOTTOM_OFFSET_Y = 3,
	INPUT_TEXT_INSET_X = 6,
	NAME_FONT_SIZE = SHARED_DIALOG_STYLE.INPUT_VALUE_FONT_SIZE or 15,
	MIN_FITTED_TEXT_SIZE = SHARED_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE or 10,
}

local SELECTABLE_INPUT_DEFAULT_HEIGHT = 26
local SELECTABLE_INPUT_DEFAULT_FONT_SIZE = 14

local function updateCopyInputAtlasFrame(frame, active)
	if not frame then
		return
	end
	UI.ApplyFilterInputChrome(frame, active and "hover" or "normal")
end

local function updateCopyInputState(frame)
	local edit = frame and frame.edit
	local focused = edit and edit.HasFocus and edit:HasFocus()
	updateCopyInputAtlasFrame(frame, frame and (frame._gfCopyInputHovered or focused))
end

local function applyFontStringSizeOverride(fontString, template, size, flags)
	if not fontString or not GF.Font then
		return
	end
	fontString._gfFontSizeOverride = size
	fontString._gfFontFlagsOverride = flags
	if GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template or fontString._gfFontTemplate or "GameFontNormal")
	end
end

local function applyEditBoxSizeOverride(editBox, template, size, flags)
	if not editBox or not GF.Font then
		return
	end
	editBox._gfFontSizeOverride = size
	editBox._gfFontFlagsOverride = flags
	if GF.Font.ApplyToEditBox then
		GF.Font.ApplyToEditBox(editBox, template or editBox._gfFontTemplate or "GameFontHighlightSmall")
	end
end

function UI.CreateSelectableCopyInput(parent, width, options)
	local inputOptions = type(options) == "table" and options or {}
	local inputHeight = tonumber(inputOptions.height)
		or SELECTABLE_INPUT_DEFAULT_HEIGHT
	local inputFontSize = tonumber(inputOptions.fontSize)
		or SELECTABLE_INPUT_DEFAULT_FONT_SIZE
	local shell = CreateFrame("Frame", nil, parent)
	shell:SetSize(width or CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_W, inputHeight)
	shell:EnableMouse(true)

	local edit = CreateFrame("EditBox", nil, shell)
	edit:SetPoint(
		"TOPLEFT",
		shell,
		"TOPLEFT",
		CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_EDIT_INSET_X,
		CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_EDIT_TOP_OFFSET_Y
	)
	edit:SetPoint(
		"BOTTOMRIGHT",
		shell,
		"BOTTOMRIGHT",
		-CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_EDIT_INSET_X,
		CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_EDIT_BOTTOM_OFFSET_Y
	)
	edit:SetAutoFocus(false)
	edit:SetTextInsets(
		CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_TEXT_INSET_X,
		CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_TEXT_INSET_X,
		0,
		0
	)
	edit:SetJustifyH("CENTER")
	if edit.SetTextColor then
		edit:SetTextColor(1, 1, 1, 1)
	end
	UI.TrackEditBox(edit, "GameFontHighlightSmall")
	applyEditBoxSizeOverride(edit, "GameFontHighlightSmall", inputFontSize, "")
	shell.edit = edit
	shell.RefreshVisualState = updateCopyInputState

	shell:SetScript("OnEnter", function(self)
		self._gfCopyInputHovered = true
		updateCopyInputState(self)
	end)
	shell:SetScript("OnLeave", function(self)
		self._gfCopyInputHovered = nil
		updateCopyInputState(self)
	end)
	shell:SetScript("OnMouseDown", function(self)
		if self.edit then
			self.edit:SetFocus()
			if inputOptions.selectAllOnMouseDown ~= false then
				self.edit:HighlightText()
			end
		end
	end)
	edit:SetScript("OnEnter", function()
		shell._gfCopyInputHovered = true
		updateCopyInputState(shell)
	end)
	edit:SetScript("OnLeave", function()
		shell._gfCopyInputHovered = nil
		updateCopyInputState(shell)
	end)
	edit:HookScript("OnEditFocusGained", function()
		updateCopyInputState(shell)
	end)
	edit:HookScript("OnEditFocusLost", function()
		updateCopyInputState(shell)
	end)
	shell:HookScript("OnHide", function(self)
		self._gfCopyInputHovered = nil
		updateCopyInputState(self)
	end)
	shell:HookScript("OnShow", function(self)
		self._gfCopyInputHovered = self.IsMouseMotionFocus
			and self:IsMouseMotionFocus() == true or nil
		updateCopyInputState(self)
	end)

	updateCopyInputState(shell)
	return shell, edit
end

function UI.ConfigureReadonlyCopyEdit(dialog, input, edit)
	if not dialog or not input or not edit then
		return
	end
	edit:SetScript("OnEscapePressed", function()
		dialog:Hide()
	end)
	edit:SetScript("OnEditFocusGained", function(self)
		updateCopyInputState(input)
		self:HighlightText()
	end)
	edit:SetScript("OnEditFocusLost", function()
		updateCopyInputState(input)
	end)
	edit:SetScript("OnMouseUp", function(self)
		self:HighlightText()
	end)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self._gfExpectedText and self:GetText() ~= self._gfExpectedText then
			self:SetText(self._gfExpectedText)
			self:SetCursorPosition(0)
			self:HighlightText()
		end
	end)
end

local function centerPanelButtonText(button)
	if not button or not button.GetFontString then
		return
	end
	local fontString = button:GetFontString()
	if not fontString then
		return
	end
	fontString:ClearAllPoints()
	fontString:SetPoint("CENTER", button, "CENTER", 0, 0)
	fontString:SetJustifyH("CENTER")
	if fontString.SetJustifyV then
		fontString:SetJustifyV("MIDDLE")
	end
	fontString:SetWidth(math.max(1, button:GetWidth() or GF.PANEL_BUTTON_STANDARD_W or 72))
	fontString:SetHeight(math.max(1, button:GetHeight() or GF.PANEL_BUTTON_H or 24))
end

local function isCopyShortcutKey(key)
	if type(key) ~= "string" or string.upper(key) ~= "C" then
		return false
	end
	local ctrlDown = IsControlKeyDown and IsControlKeyDown()
	local metaDown = IsMetaKeyDown and IsMetaKeyDown()
	return ctrlDown or metaDown
end

local function raiseDialogToTop(dialog)
	if UI.ApplySatelliteFrameLayers then
		UI.ApplySatelliteFrameLayers()
	end
	if UI.RaiseFrame then
		UI.RaiseFrame(dialog)
	elseif dialog and dialog.Raise then
		dialog:Raise()
	end
end

local function ensureCharacterNameCopyDialog()
	if UI.characterNameCopyDialog then
		return UI.characterNameCopyDialog
	end
	local L = GF.L or {}
	local dialog = UI.CreateSatelliteSettingsFrame({
		name = "GroupFinderAddonCharacterNameCopyDialog",
		width = CHARACTER_NAME_COPY_DIALOG_STYLE.DIALOG_W,
		height = CHARACTER_NAME_COPY_DIALOG_STYLE.DIALOG_H,
		title = L.CHARACTER_NAME_COPY_DIALOG_TITLE or L.APPLICANT_COPY_NAME or "复制角色名称",
		levelOffset = CHARACTER_NAME_COPY_DIALOG_STYLE.DIALOG_LEVEL_OFFSET,
		backgroundColor = SHARED_DIALOG_STYLE.BACKGROUND_COLOR
			or GF.PLAYER_CONTEXT_DIALOG_BACKGROUND_COLOR,
	})
	if dialog.SetToplevel then
		dialog:SetToplevel(true)
	end
	dialog.contentHost = UI.CreatePlayerContextDialogContentHost(dialog)

	dialog.hint = UI.CreateFontString(dialog, "OVERLAY", "GameFontHighlightSmall")
	if UI.ApplyPlayerContextDialogTextStyle then
		UI.ApplyPlayerContextDialogTextStyle(dialog.hint, "secondary")
	else
		applyFontStringSizeOverride(
			dialog.hint,
			"GameFontHighlightSmall",
			CHARACTER_NAME_COPY_DIALOG_STYLE.HINT_FONT_SIZE,
			"")
	end
	dialog.hint:SetJustifyH("CENTER")
	if dialog.hint.SetWordWrap then
		dialog.hint:SetWordWrap(false)
	end
	if dialog.hint.SetMaxLines then
		dialog.hint:SetMaxLines(1)
	end
	dialog.hint:SetText(L.CHARACTER_NAME_COPY_DIALOG_HINT or "角色名称已选中，请使用快捷键复制名称")

	dialog.copyInput, dialog.copyEdit = UI.CreateSelectableCopyInput(
		dialog,
		CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_W,
		{
			height = CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_H,
			fontSize = CHARACTER_NAME_COPY_DIALOG_STYLE.NAME_FONT_SIZE,
		}
	)
	dialog.copyInput:SetPoint(
		"CENTER",
		dialog.contentHost,
		"CENTER",
		0,
		CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_CENTER_OFFSET_Y
	)
	dialog.hint:SetPoint(
		"LEFT",
		dialog.contentHost,
		"LEFT",
		0,
		0)
	dialog.hint:SetPoint(
		"RIGHT",
		dialog.contentHost,
		"RIGHT",
		0,
		0)
	dialog.hint:SetPoint(
		"BOTTOM",
		dialog.copyInput,
		"TOP",
		0,
		CHARACTER_NAME_COPY_DIALOG_STYLE.HINT_TO_INPUT_GAP)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(
			dialog.hint,
			CHARACTER_NAME_COPY_DIALOG_STYLE.DIALOG_W
				- (CHARACTER_NAME_COPY_DIALOG_STYLE.CONTENT_INSET_X * 2),
			CHARACTER_NAME_COPY_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE)
	end
	UI.ConfigureReadonlyCopyEdit(dialog, dialog.copyInput, dialog.copyEdit)
	dialog.copyEdit:SetScript("OnKeyDown", function(_, key)
		if not isCopyShortcutKey(key) or dialog._gfCopyClosePending then
			return
		end
		dialog._gfCopyClosePending = true
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				dialog._gfCopyClosePending = nil
				if dialog:IsShown() then
					dialog:Hide()
				end
			end)
		else
			dialog._gfCopyClosePending = nil
			dialog:Hide()
		end
	end)

	dialog.closeButton = UI.CreatePanelButton(
		dialog,
		CLOSE or "Close",
		SHARED_DIALOG_STYLE.BUTTON_WIDTH or GF.PANEL_BUTTON_STANDARD_W or 72)
	if UI.ApplyPlayerContextDialogButtonFont then
		UI.ApplyPlayerContextDialogButtonFont(dialog.closeButton)
	end
	dialog.closeButton:SetPoint(
		"BOTTOM",
		dialog,
		"BOTTOM",
		0,
		CHARACTER_NAME_COPY_DIALOG_STYLE.CONTENT_BOTTOM_INSET
	)
	centerPanelButtonText(dialog.closeButton)
	dialog.closeButton:SetScript("OnClick", function()
		dialog:Hide()
	end)

	UI.characterNameCopyDialog = dialog
	return dialog
end

function UI.ShowCharacterNameCopyDialog(name)
	if type(GF.NormalizeExternalFullPlayerName) ~= "function" then
		return false
	end
	name = GF.NormalizeExternalFullPlayerName(name)
	if not name then
		return false
	end
	local blacklistDialog = GF.BlacklistMenu and GF.BlacklistMenu.dialog
	if blacklistDialog and blacklistDialog.IsShown and blacklistDialog:IsShown() then
		blacklistDialog:Hide()
	end
	local L = GF.L or {}
	local dialog = ensureCharacterNameCopyDialog()
	UI.PresentSatelliteFrame(dialog, {
		title = L.CHARACTER_NAME_COPY_DIALOG_TITLE or L.APPLICANT_COPY_NAME or "复制角色名称",
		offsetY = CHARACTER_NAME_COPY_DIALOG_STYLE.DIALOG_PRESENT_OFFSET_Y,
		prepare = function(frame)
			frame.hint:SetText(L.CHARACTER_NAME_COPY_DIALOG_HINT or "角色名称已选中，请使用快捷键复制名称")
			if GF.Font and GF.Font.SetFitWidth then
				GF.Font.SetFitWidth(
					frame.hint,
					CHARACTER_NAME_COPY_DIALOG_STYLE.DIALOG_W
						- (CHARACTER_NAME_COPY_DIALOG_STYLE.CONTENT_INSET_X * 2),
					CHARACTER_NAME_COPY_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE)
			end
			frame._gfCopyClosePending = nil
			frame.copyEdit._gfExpectedText = name
			frame.copyEdit:SetText(name)
			frame.copyEdit:SetCursorPosition(0)
		end,
		onShown = function(frame)
			frame.copyEdit:SetFocus()
			frame.copyEdit:HighlightText()
		end,
	})
	raiseDialogToTop(dialog)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if dialog:IsShown() then
				dialog.copyEdit:SetFocus()
				dialog.copyEdit:HighlightText()
			end
		end)
	end
	return true
end
