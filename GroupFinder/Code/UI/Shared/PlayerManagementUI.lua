local _, GF = ...

local UI = GF.UI
local FORM, FOOTER = GF.PLAYER_MANAGEMENT_DIALOG_STYLE, GF.PLAYER_MANAGEMENT_FOOTER_STYLE
local DIALOG, TABLE = GF.PLAYER_CONTEXT_DIALOG_STYLE, GF.PLAYER_MANAGEMENT_STYLE

function UI.SetPlayerManagementDialogTitle(dialog, title)
	UI.ApplySettingsFrameChrome(dialog, title)
	local text = dialog.systemTitleText or dialog.titletext
	if not text then return end
	local width = FORM.width - FORM.titleInset * 2
	text._gfFontSizeOverride = FORM.titleFontSize
	text._gfIgnoreFontScale = true
	text:SetWidth(width)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(text, width, FORM.minFontSize)
	end
end

function UI.CreatePlayerManagementDialogField(dialog, maxLetters, multiline)
	local width = FORM.width - FORM.contentInset * 2
	local label = UI.CreateFontString(dialog, "OVERLAY", "GameFontHighlightSmall")
	UI.ApplyPlayerContextDialogTextStyle(label, "secondary")
	label._gfFontSizeOverride = FORM.labelFontSize
	local color = FORM.labelColor
	label:SetTextColor(color[1], color[2], color[3], color[4])
	label:SetJustifyH("LEFT"); label:SetWordWrap(false); label:SetMaxLines(1)
	local shell, edit = UI.CreateSelectableCopyInput(dialog, width, {
		selectAllOnMouseDown = false, multiline = multiline,
		height = multiline and FORM.noteHeight or FORM.inputHeight,
		fontSize = FORM.inputFontSize, contentInsetX = FORM.inputTextInset,
	})
	edit:SetJustifyH("LEFT"); edit:SetMaxLetters(maxLetters)
	local placeholder = UI.CreateFontString(shell, "OVERLAY", "GameFontDisableSmall")
	edit.Instructions = placeholder
	local inset = multiline and FORM.noteTextInset or FORM.inputTextInset
	if multiline then
		placeholder:SetPoint("TOPLEFT", shell, "TOPLEFT", inset, -inset)
		placeholder:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -inset, -inset)
	else
		placeholder:SetPoint("LEFT", shell, "LEFT", inset, 0)
		placeholder:SetPoint("RIGHT", shell, "RIGHT", -inset, 0)
	end
	placeholder:SetJustifyH("LEFT"); placeholder:SetWordWrap(false); placeholder:SetMaxLines(1)
	placeholder._gfFontSizeOverride = FORM.placeholderFontSize
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(label, "GameFontHighlightSmall")
		GF.Font.ApplyToFontString(placeholder, "GameFontDisableSmall")
	end
	return label, shell, edit, placeholder
end

function UI.RefreshPlayerManagementDialogButton(button)
	local text = button:GetFontString()
	text._gfFontSizeOverride = FORM.buttonFontSize
	text:ClearAllPoints()
	text:SetPoint("CENTER", button, "CENTER", 0, 0)
	text:SetJustifyH("CENTER"); text:SetJustifyV("MIDDLE")
	text:SetSize(FORM.buttonWidth, FORM.buttonHeight)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(text, FORM.buttonWidth - 12, FORM.minFontSize)
	end
end

function UI.CreatePlayerManagementDialogActions(dialog, confirmText, cancelText)
	local bar = CreateFrame("Frame", nil, dialog)
	bar:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 0, FORM.actionBarBottomInset)
	bar:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", 0, FORM.actionBarBottomInset)
	bar:SetHeight(FORM.actionBarHeight)
	bar:SetFrameLevel(dialog:GetFrameLevel() + 3)
	UI.InstallBrowseControlBarChrome(bar, {
		backgroundParent = dialog, topOffset = 0,
		leftInset = GF.FRAME_BG_INSET_LEFT, rightInset = -GF.FRAME_BG_INSET_RIGHT,
		height = FORM.actionBarHeight,
	})
	local confirm = UI.CreatePanelButton(bar, confirmText, FORM.buttonWidth)
	local cancel = UI.CreatePanelButton(bar, cancelText, FORM.buttonWidth)
	confirm:SetPoint("RIGHT", bar, "CENTER", -FORM.buttonGap / 2, 0)
	cancel:SetPoint("LEFT", bar, "CENTER", FORM.buttonGap / 2, 0)
	for _, button in ipairs({ confirm, cancel }) do
		button:SetSize(FORM.buttonWidth, FORM.buttonHeight)
		UI.RefreshPlayerManagementDialogButton(button)
	end
	return bar, confirm, cancel
end

function UI.LayoutPlayerManagementDialog(dialog, notice, fields, errorText, style)
	local form = style or FORM
	local width, y = form.width - form.contentInset * 2, DIALOG.TEXT_LINE_GAP
	local function place(region, height)
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", dialog.contentHost, "TOP", -width / 2, -y)
		region:SetWidth(width)
		y = y + height
	end
	local showNotice = notice and (notice:GetText() or "") ~= ""
	if notice then notice:SetShown(showNotice) end
	if showNotice then
		place(notice, math.max(DIALOG.SECONDARY_TEXT_FONT_SIZE, notice:GetStringHeight()))
		y = y + form.noticeToFormGap
	end
	for _, field in ipairs(fields) do
		local shown = field.shown ~= false
		local labelShown = shown and field.labelShown ~= false
		field.label:SetShown(labelShown); field.input:SetShown(shown)
		if shown then
			local inputHeight = field.height or form.inputHeight
			if labelShown then
				local labelHeight = math.max(DIALOG.SECONDARY_TEXT_FONT_SIZE, field.label:GetStringHeight())
				place(field.label, labelHeight)
				y = y + form.labelGap
			end
			place(field.input, inputHeight)
			y = y + form.rowGap
		end
	end
	y = y - form.rowGap
	if errorText then
		local shown = (errorText:GetText() or "") ~= ""
		errorText:SetShown(shown)
		if shown then
			y = y + DIALOG.TEXT_TO_INPUT_GAP
			place(errorText, math.max(DIALOG.SECONDARY_TEXT_FONT_SIZE, errorText:GetStringHeight()))
		end
	end
	local actionHeight = form.actionBarHeight
		and (form.actionBarHeight + form.actionBarBottomInset)
		or (DIALOG.BUTTON_HEIGHT + DIALOG.CONTENT_BOTTOM_INSET)
	dialog:SetSize(form.width, DIALOG.CONTENT_TOP_INSET + y + form.actionGap + actionHeight)
end

function UI.LayoutPlayerManagementActions(parent, first, second, action, offsetY)
	local center = action.x + action.width / 2
	first:ClearAllPoints()
	first:SetPoint("RIGHT", parent, "LEFT", center - TABLE.buttonGap / 2, offsetY or 0)
	second:ClearAllPoints()
	second:SetPoint("LEFT", parent, "LEFT", center + TABLE.buttonGap / 2, offsetY or 0)
	return center - TABLE.buttonGap / 2 - TABLE.buttonWidth
end

function UI.CreatePlayerManagementFooter(parent)
	local footer = CreateFrame("Frame", nil, parent)
	footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
	footer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	footer:SetHeight(FOOTER.minHeight)
	footer:SetFrameLevel(parent:GetFrameLevel() + 3)
	UI.InstallBrowseControlBarChrome(footer, {
		backgroundParent = parent, leftInset = 0, rightInset = 0, topOffset = 0,
	})
	footer.primaryButton = UI.CreatePlayerManagementButton(footer, "")
	footer.secondaryButton = UI.CreatePlayerManagementButton(footer, "")
	footer.searchEdit = CreateFrame("EditBox", nil, footer, "SearchBoxTemplate")
	footer.searchEdit:SetPoint("RIGHT", footer.primaryButton, "LEFT", -FOOTER.sectionGap, 0)
	footer.searchEdit:SetSize(FOOTER.searchWidth, GF.SUBTITLE_SEARCH_H)
	footer.searchEdit:SetMaxLetters(100)
	UI.StyleBrowseSearchBox(footer.searchEdit, "")
	footer.searchEdit:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
	footer.info = CreateFrame("Frame", nil, footer)
	footer.info:SetPoint("LEFT", footer, "LEFT", GF.SUBTITLE_CONTROL_LEFT_PAD, 0)
	footer.info:SetPoint("RIGHT", footer.searchEdit, "LEFT", -FOOTER.sectionGap, 0)
	footer.heading = UI.CreateFontString(footer.info, "OVERLAY", "GameFontNormalLarge")
	footer.heading:SetPoint("LEFT", footer.info, "LEFT", 0, 0)
	footer.hint = UI.CreateFontString(footer.info, "OVERLAY", "GameFontHighlightSmall")
	footer.hint:SetPoint("LEFT", footer.heading, "RIGHT", FOOTER.sectionGap, 0)
	footer.hint:SetPoint("RIGHT", footer.info, "RIGHT", 0, 0)
	local color = FOOTER.hintColor
	footer.hint:SetTextColor(color[1], color[2], color[3], color[4])
	for _, text in ipairs({ footer.heading, footer.hint }) do
		text:SetJustifyH("LEFT"); text:SetWordWrap(false); text:SetMaxLines(1)
	end
	function footer:Layout(action)
		local actionLeft = UI.LayoutPlayerManagementActions(self, self.primaryButton, self.secondaryButton, action)
		local width = math.max(1, actionLeft - FOOTER.searchWidth - FOOTER.sectionGap * 2 - GF.SUBTITLE_CONTROL_LEFT_PAD)
		local titleLimit = math.max(1, width * FOOTER.titleWidthRatio)
		if GF.Font and GF.Font.SetFitWidth then GF.Font.SetFitWidth(self.heading, titleLimit, FOOTER.minFontSize) end
		local titleWidth = math.max(1, math.min(titleLimit, math.ceil(self.heading:GetUnboundedStringWidth())))
		self.heading:SetWidth(titleWidth)
		if GF.Font and GF.Font.SetFitWidth then
			GF.Font.SetFitWidth(self.hint, math.max(1, width - titleWidth - FOOTER.sectionGap), FOOTER.minFontSize)
		end
		local textHeight = math.max(self.heading:GetStringHeight(), self.hint:GetStringHeight())
		self.info:SetHeight(textHeight)
		self:SetHeight(math.max(FOOTER.minHeight, textHeight + FOOTER.paddingY * 2))
	end
	footer:HookScript("OnHide", function() footer.searchEdit:ClearFocus() end)
	return footer
end
