local _, GF = ...

GF.UI = GF.UI or {}
local UI = GF.UI

local CHARACTER_NAME_COPY_DIALOG_STYLE = {
	DIALOG_W = 420,
	DIALOG_H = 164,
	DIALOG_LEVEL_OFFSET = 18,
	DIALOG_PRESENT_OFFSET_Y = 20,
	HINT_INSET_X = 34,
	HINT_OFFSET_Y = -54,
	HINT_FONT_SIZE = 13,
	HINT_LINE_SPACING = 2,
	HINT_TO_INPUT_GAP = 10,
	INPUT_W = 330,
	INPUT_H = 26,
	INPUT_ATLAS_TEXTURE = GF.FILTER_CHECK_ATLAS_TEXTURE,
	INPUT_ATLAS_CAP_W = 9,
	INPUT_EDIT_INSET_X = 10,
	INPUT_EDIT_TOP_OFFSET_Y = -3,
	INPUT_EDIT_BOTTOM_OFFSET_Y = 3,
	INPUT_TEXT_INSET_X = 6,
	NAME_FONT_SIZE = 14,
	INPUT_TO_CLOSE_BUTTON_GAP = 14,
}

local function snapCopyInputTexture(texture)
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

local function updateCopyInputAtlasFrame(frame, active)
	local pieces = frame and frame._gfCopyInputAtlas
	if not pieces then
		return
	end
	UI.SetFilterInputTextureState(pieces, active and "hover" or "normal")
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

function UI.CreateSelectableCopyInput(parent, width)
	local shell = CreateFrame("Frame", nil, parent)
	shell:SetSize(width or CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_W, CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_H)
	shell:EnableMouse(true)

	local left = shell:CreateTexture(nil, "BACKGROUND", nil, -6)
	left:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", 0, 0)
	left:SetWidth(CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_ATLAS_CAP_W)
	left:SetTexture(CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_ATLAS_TEXTURE)
	snapCopyInputTexture(left)

	local right = shell:CreateTexture(nil, "BACKGROUND", nil, -6)
	right:SetPoint("TOPRIGHT", shell, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_ATLAS_CAP_W)
	right:SetTexture(CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_ATLAS_TEXTURE)
	snapCopyInputTexture(right)

	local middle = shell:CreateTexture(nil, "BACKGROUND", nil, -6)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
	middle:SetTexture(CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_ATLAS_TEXTURE)
	snapCopyInputTexture(middle)

	shell._gfCopyInputAtlas = {
		left = left,
		middle = middle,
		right = right,
	}

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
	applyEditBoxSizeOverride(edit, "GameFontHighlightSmall", CHARACTER_NAME_COPY_DIALOG_STYLE.NAME_FONT_SIZE, "")
	shell.edit = edit

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
			self.edit:HighlightText()
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
	})
	dialog:SetFrameStrata("DIALOG")
	if dialog.SetToplevel then
		dialog:SetToplevel(true)
	end

	dialog.hint = UI.CreateFontString(dialog, "OVERLAY", "GameFontHighlightSmall")
	dialog.hint:SetPoint(
		"TOPLEFT",
		dialog,
		"TOPLEFT",
		CHARACTER_NAME_COPY_DIALOG_STYLE.HINT_INSET_X,
		CHARACTER_NAME_COPY_DIALOG_STYLE.HINT_OFFSET_Y
	)
	dialog.hint:SetPoint(
		"TOPRIGHT",
		dialog,
		"TOPRIGHT",
		-CHARACTER_NAME_COPY_DIALOG_STYLE.HINT_INSET_X,
		CHARACTER_NAME_COPY_DIALOG_STYLE.HINT_OFFSET_Y
	)
	dialog.hint:SetJustifyH("CENTER")
	if dialog.hint.SetSpacing then
		dialog.hint:SetSpacing(CHARACTER_NAME_COPY_DIALOG_STYLE.HINT_LINE_SPACING)
	end
	applyFontStringSizeOverride(
		dialog.hint,
		"GameFontHighlightSmall",
		CHARACTER_NAME_COPY_DIALOG_STYLE.HINT_FONT_SIZE,
		""
	)
	dialog.hint:SetText(L.CHARACTER_NAME_COPY_DIALOG_HINT or "角色名称已选中，请使用快捷键复制名称")

	dialog.copyInput, dialog.copyEdit = UI.CreateSelectableCopyInput(dialog)
	dialog.copyInput:SetPoint(
		"TOP",
		dialog.hint,
		"BOTTOM",
		0,
		-CHARACTER_NAME_COPY_DIALOG_STYLE.HINT_TO_INPUT_GAP
	)
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

	dialog.closeButton = UI.CreatePanelButton(dialog, CLOSE or "Close", GF.PANEL_BUTTON_STANDARD_W or 72)
	dialog.closeButton:SetPoint(
		"TOP",
		dialog.copyInput,
		"BOTTOM",
		0,
		-CHARACTER_NAME_COPY_DIALOG_STYLE.INPUT_TO_CLOSE_BUTTON_GAP
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
	local L = GF.L or {}
	local dialog = ensureCharacterNameCopyDialog()
	UI.PresentSatelliteFrame(dialog, {
		title = L.CHARACTER_NAME_COPY_DIALOG_TITLE or L.APPLICANT_COPY_NAME or "复制角色名称",
		offsetY = CHARACTER_NAME_COPY_DIALOG_STYLE.DIALOG_PRESENT_OFFSET_Y,
		prepare = function(frame)
			frame.hint:SetText(L.CHARACTER_NAME_COPY_DIALOG_HINT or "角色名称已选中，请使用快捷键复制名称")
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
