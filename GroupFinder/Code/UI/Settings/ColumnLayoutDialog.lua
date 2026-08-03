local _, GF = ...

GF.ColumnLayoutDialog = {}
local Dialog = GF.ColumnLayoutDialog

local SIZE = {
	width = 320,
	height = 220,
	inputWidth = 120,
	inputHeight = 22,
}

local function columns()
	return GF.ListColumns
end

local function stripped(text)
	text = type(text) == "string" and text or ""
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function warning(text)
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(text)
	end
end

local function assignText(editBox, value)
	editBox._gfAssigningText = true
	editBox:SetText(value or "")
	editBox._gfAssigningText = nil
end

local function keepDecimalCharacters(value)
	local output = {}
	local hasDecimalPoint = false
	for index = 1, #(value or "") do
		local character = value:sub(index, index)
		if character:match("%d") then
			output[#output + 1] = character
		elseif character == "." and not hasDecimalPoint then
			hasDecimalPoint = true
			output[#output + 1] = character
		end
	end
	return table.concat(output)
end

local function normalizeInput(editBox, parser, formatter)
	local parsed = parser(stripped(editBox:GetText()))
	if parsed == nil then
		assignText(editBox, editBox._gfLastValidText or "")
		return nil
	end
	local canonical = formatter(parsed)
	editBox._gfLastValidText = canonical
	assignText(editBox, canonical)
	return parsed
end

local function parseMinimum(text)
	local owner = columns()
	return owner and owner:ParseMinWidthText(text) or nil
end

local function parseWeight(text)
	local owner = columns()
	return owner and owner:ParseWeightText(text) or nil
end

local function formatMinimum(value)
	local owner = columns()
	return owner and owner:FormatMinWidth(value) or tostring(value or "")
end

local function formatWeight(value)
	local owner = columns()
	return owner and owner:FormatWeight(value) or tostring(value or "")
end

local function installMinimumInput(editBox)
	editBox:SetNumeric(true)
	editBox:SetScript("OnEditFocusLost", function(box)
		normalizeInput(box, parseMinimum, formatMinimum)
	end)
	editBox:SetScript("OnEnterPressed", function(box)
		box:ClearFocus()
	end)
end

local function installWeightInput(editBox)
	editBox:SetScript("OnTextChanged", function(box)
		if box._gfAssigningText then
			return
		end
		local current = box:GetText() or ""
		local sanitized = keepDecimalCharacters(current)
		if current ~= sanitized then
			assignText(box, sanitized)
		end
	end)
	editBox:SetScript("OnEditFocusLost", function(box)
		normalizeInput(box, parseWeight, formatWeight)
	end)
	editBox:SetScript("OnEnterPressed", function(box)
		box:ClearFocus()
	end)
end

local function createInput(parent, anchor, offsetX, offsetY, installer)
	local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	editBox:SetSize(SIZE.inputWidth, SIZE.inputHeight)
	editBox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX, offsetY)
	editBox:SetAutoFocus(false)
	if GF.UI.TrackEditBox then
		GF.UI.TrackEditBox(editBox, "GameFontHighlightSmall")
	end
	installer(editBox)
	GF.UI.StyleFilterNumberBox(editBox, {
		width = SIZE.inputWidth,
		height = SIZE.inputHeight,
	})
	return editBox
end

local function createFrameOnce()
	if Dialog.frame then
		return Dialog.frame
	end
	local locale = GF.L or {}
	local frame = GF.UI.CreateSatelliteSettingsFrame({
		name = "GroupFinderAddonColumnLayoutDialog",
		width = SIZE.width,
		height = SIZE.height,
		title = locale.COL_LAYOUT_DIALOG_TITLE or "Column layout",
		levelOffset = 5,
		onClose = function()
			Dialog:Hide()
		end,
	})

	local form = CreateFrame("Frame", nil, frame)
	form:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)
	form:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 52)
	frame.form = form

	frame.helpIcon = GF.UI.CreateHelpIcon(
		form,
		locale.COL_LAYOUT_HELP_HINT or "",
		40
	)
	frame.helpIcon:SetPoint("TOPRIGHT", form, "TOPRIGHT", 5, 5)
	frame.helpIcon:SetFrameLevel(form:GetFrameLevel() + 10)

	frame.minLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")
	frame.minLabel:SetPoint("TOPLEFT", form, "TOPLEFT")
	frame.minLabel:SetJustifyH("LEFT")
	frame.minInput = createInput(form, frame.minLabel, 8, -4, installMinimumInput)

	frame.weightLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")
	frame.weightLabel:SetPoint("TOPLEFT", frame.minInput, "BOTTOMLEFT", -8, -14)
	frame.weightLabel:SetJustifyH("LEFT")
	frame.weightInput = createInput(form, frame.weightLabel, 8, -4, installWeightInput)

	frame.okBtn = GF.UI.CreatePanelButton(
		frame,
		locale.COL_LAYOUT_OK or "OK",
		GF.PANEL_BUTTON_TWO_CHAR_W
	)
	frame.okBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -112, 14)
	frame.okBtn:SetScript("OnClick", function()
		Dialog:OnConfirm()
	end)

	frame.resetBtn = GF.UI.CreatePanelButton(
		frame,
		locale.COL_LAYOUT_RESET or "Reset",
		GF.PANEL_BUTTON_TWO_CHAR_W
	)
	frame.resetBtn:SetPoint("RIGHT", frame.okBtn, "LEFT", -8, 0)
	frame.resetBtn:SetScript("OnClick", function()
		Dialog:OnReset()
	end)

	frame.cancelBtn = GF.UI.CreatePanelButton(
		frame,
		locale.COL_LAYOUT_CANCEL or "Cancel",
		GF.PANEL_BUTTON_TWO_CHAR_W
	)
	frame.cancelBtn:SetPoint("LEFT", frame.okBtn, "RIGHT", 8, 0)
	frame.cancelBtn:SetScript("OnClick", function()
		Dialog:Hide()
	end)

	Dialog.frame = frame
	return frame
end

local function refreshLocale(frame)
	local locale = GF.L or {}
	frame.minLabel:SetText(locale.COL_LAYOUT_MIN_WIDTH or "Min width")
	frame.weightLabel:SetText(locale.COL_LAYOUT_WEIGHT or "Weight")
	frame.okBtn:SetText(locale.COL_LAYOUT_OK or "OK")
	frame.resetBtn:SetText(locale.COL_LAYOUT_RESET or "Reset")
	frame.cancelBtn:SetText(locale.COL_LAYOUT_CANCEL or "Cancel")
	if frame.helpIcon then
		frame.helpIcon._gfTooltip = locale.COL_LAYOUT_HELP_HINT or ""
	end
end

function Dialog:Hide()
	if self.frame then
		self.frame:Hide()
	end
	self._ctx = nil
end

function Dialog:Open(profile, columnID, bar)
	local owner = columns()
	if not (owner and profile and columnID) then
		return
	end
	local definition = owner:GetColumnDef(profile, columnID)
	if not definition then
		return
	end
	local frame = createFrameOnce()
	refreshLocale(frame)
	self._ctx = {
		profile = profile,
		colId = columnID,
		bar = bar,
	}

	local minText = owner:FormatMinWidth(definition.minWidth)
	local weightText = owner:FormatWeight(definition.weight)
	frame.minInput._gfLastValidText = minText
	frame.weightInput._gfLastValidText = weightText
	assignText(frame.minInput, minText)
	assignText(frame.weightInput, weightText)

	GF.UI.PresentSatelliteFrame(frame, {
		title = (GF.L and GF.L.COL_LAYOUT_DIALOG_TITLE) or "Column layout",
		onShown = function()
			frame.minInput:SetFocus()
			frame.minInput:HighlightText()
		end,
	})
end

function Dialog:ApplyChange(context)
	local bar = context and context.bar
	if bar == nil then
		return
	end
	local headers = GF.ColumnHeaderBar
	if headers and type(headers.Layout) == "function" then
		headers:Layout(bar)
	end
	if type(bar._onLayoutChange) == "function" then
		bar._onLayoutChange()
	end
end

function Dialog:OnReset()
	local context = self._ctx
	local owner = columns()
	if not (context and owner) then
		return
	end
	owner:ResetColumnLayout(context.profile, context.colId)
	self:ApplyChange(context)
	self:Hide()
end

function Dialog:OnConfirm()
	local context = self._ctx
	local owner = columns()
	if not (context and owner and self.frame) then
		return
	end
	local minWidth = parseMinimum(stripped(self.frame.minInput:GetText()))
	local weight = parseWeight(stripped(self.frame.weightInput:GetText()))
	if minWidth == nil or weight == nil then
		warning((GF.L and GF.L.COL_LAYOUT_INVALID) or "Invalid column layout values.")
		return
	end
	if not owner:SetColumnLayout(context.profile, context.colId, minWidth, weight) then
		warning((GF.L and GF.L.COL_LAYOUT_INVALID) or "Invalid column layout values.")
		return
	end
	self:ApplyChange(context)
	self:Hide()
end
