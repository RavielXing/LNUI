local _, GF = ...

GF.ColumnLayoutDialog = {}

local CLD = GF.ColumnLayoutDialog
local LC = GF.ListColumns

local DIALOG_W = 320
local DIALOG_H = 220
local EDIT_W = 120
local EDIT_H = 22

local function trim(s)
	if not s then
		return ""
	end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function notify(msg)
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(msg)
	end
end

local function decimalOnly(raw)
	local out, dot = {}, false
	for i = 1, #raw do
		local c = raw:sub(i, i)
		if c >= "0" and c <= "9" then
			out[#out + 1] = c
		elseif c == "." and not dot then
			dot = true
			out[#out + 1] = c
		end
	end
	return table.concat(out)
end

local function setBoxText(box, text)
	box._gfUpdating = true
	box:SetText(text or "")
	box._gfUpdating = false
end

local function revertBox(box, parseFn, formatFn)
	local t = trim(box:GetText())
	if parseFn(t) then
		local formatted = formatFn(t)
		box._gfLastGood = formatted
		setBoxText(box, formatted)
	else
		setBoxText(box, box._gfLastGood or "")
	end
end

local function parseMinWidth(t)
	return LC:ParseMinWidthText(t)
end

local function parseWeight(t)
	return LC:ParseWeightText(t)
end

local function formatMinWidthText(t)
	return LC:FormatMinWidth(LC:ParseMinWidthText(t))
end

local function formatWeightText(t)
	return LC:FormatWeight(LC:ParseWeightText(t))
end

local function bindMinWidthInput(box)
	box:SetNumeric(true)
	box:SetScript("OnEditFocusLost", function(self)
		revertBox(self, parseMinWidth, formatMinWidthText)
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
end

local function bindWeightInput(box)
	box:SetScript("OnTextChanged", function(self)
		if self._gfUpdating then
			return
		end
		local t = self:GetText() or ""
		local cleaned = decimalOnly(t)
		if cleaned ~= t then
			setBoxText(self, cleaned)
		end
	end)
	box:SetScript("OnEditFocusLost", function(self)
		revertBox(self, parseWeight, formatWeightText)
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
end

local function ensureFrame()
	if CLD.frame then
		return CLD.frame
	end
	local L = GF.L or {}
	local f = GF.UI.CreateSatelliteSettingsFrame({
		name = "GroupFinderAddonColumnLayoutDialog",
		width = DIALOG_W,
		height = DIALOG_H,
		title = L.COL_LAYOUT_DIALOG_TITLE or "Column layout",
		levelOffset = 5,
		onClose = function()
			CLD:Hide()
		end,
	})

	local body = CreateFrame("Frame", nil, f)
	body:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -36)
	body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 52)

	f.helpIcon = GF.UI.CreateHelpIcon(body, L.COL_LAYOUT_HELP_HINT or "", 40)
	f.helpIcon:SetPoint("TOPRIGHT", body, "TOPRIGHT", 5, 5)
	f.helpIcon:SetFrameLevel(body:GetFrameLevel() + 10)

	f.minLabel = GF.UI.CreateFontString(body, "OVERLAY", "GameFontNormal")
	f.minLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	f.minLabel:SetJustifyH("LEFT")

	f.minInput = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
	f.minInput:SetSize(EDIT_W, EDIT_H)
	f.minInput:SetPoint("TOPLEFT", f.minLabel, "BOTTOMLEFT", 8, -4)
	f.minInput:SetAutoFocus(false)
	GF.UI.TrackEditBox(f.minInput, "GameFontHighlightSmall")
	bindMinWidthInput(f.minInput)

	f.weightLabel = GF.UI.CreateFontString(body, "OVERLAY", "GameFontNormal")
	f.weightLabel:SetPoint("TOPLEFT", f.minInput, "BOTTOMLEFT", -8, -14)
	f.weightLabel:SetJustifyH("LEFT")

	f.weightInput = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
	f.weightInput:SetSize(EDIT_W, EDIT_H)
	f.weightInput:SetPoint("TOPLEFT", f.weightLabel, "BOTTOMLEFT", 8, -4)
	f.weightInput:SetAutoFocus(false)
	GF.UI.TrackEditBox(f.weightInput, "GameFontHighlightSmall")
	bindWeightInput(f.weightInput)

	f.okBtn = GF.UI.CreatePanelButton(f, L.COL_LAYOUT_OK or "OK", GF.PANEL_BUTTON_TWO_CHAR_W)
	f.okBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -112, 14)
	f.okBtn:SetScript("OnClick", function()
		CLD:OnConfirm()
	end)

	f.resetBtn = GF.UI.CreatePanelButton(f, L.COL_LAYOUT_RESET or "Reset", GF.PANEL_BUTTON_TWO_CHAR_W)
	f.resetBtn:SetPoint("RIGHT", f.okBtn, "LEFT", -8, 0)
	f.resetBtn:SetScript("OnClick", function()
		CLD:OnReset()
	end)

	f.cancelBtn = GF.UI.CreatePanelButton(f, L.COL_LAYOUT_CANCEL or "Cancel", GF.PANEL_BUTTON_TWO_CHAR_W)
	f.cancelBtn:SetPoint("LEFT", f.okBtn, "RIGHT", 8, 0)
	f.cancelBtn:SetScript("OnClick", function()
		CLD:Hide()
	end)

	CLD.frame = f
	return f
end

function CLD:Hide()
	if self.frame then
		self.frame:Hide()
	end
	self._ctx = nil
end

function CLD:Open(profile, colId, bar)
	if not profile or not colId or not LC then
		return
	end
	local f = ensureFrame()
	local L = GF.L or {}
	local colDef = LC:GetColumnDef(profile, colId)
	if not colDef then
		return
	end

	self._ctx = {
		profile = profile,
		colId = colId,
		bar = bar,
	}

	f.minLabel:SetText(L.COL_LAYOUT_MIN_WIDTH or "Min width")
	f.weightLabel:SetText(L.COL_LAYOUT_WEIGHT or "Weight")
	if f.helpIcon then
		f.helpIcon._gfTooltip = L.COL_LAYOUT_HELP_HINT or ""
	end
	local minText = LC:FormatMinWidth(colDef.minWidth or 0)
	local weightText = LC:FormatWeight(colDef.weight or 0)
	f.minInput._gfLastGood = minText
	f.weightInput._gfLastGood = weightText
	setBoxText(f.minInput, minText)
	setBoxText(f.weightInput, weightText)

	GF.UI.PresentSatelliteFrame(f, {
		title = L.COL_LAYOUT_DIALOG_TITLE or "Column layout",
		onShown = function()
			f.minInput:SetFocus()
			f.minInput:HighlightText()
		end,
	})
end

function CLD:OnReset()
	local ctx = self._ctx
	if not ctx or not LC then
		return
	end
	LC:ResetColumnLayout(ctx.profile, ctx.colId)
	self:ApplyChange(ctx)
	self:Hide()
end

function CLD:ApplyChange(ctx)
	if not ctx or not ctx.bar then
		return
	end
	local bar = ctx.bar
	if GF.ColumnHeaderBar and GF.ColumnHeaderBar.Layout then
		GF.ColumnHeaderBar:Layout(bar)
	end
	if bar._onLayoutChange then
		bar._onLayoutChange()
	end
end

function CLD:OnConfirm()
	local ctx = self._ctx
	if not ctx or not LC then
		return
	end
	local L = GF.L or {}
	revertBox(self.frame.minInput, parseMinWidth, formatMinWidthText)
	revertBox(self.frame.weightInput, parseWeight, formatWeightText)
	local minWidth = LC:ParseMinWidthText(trim(self.frame.minInput:GetText()))
	local weight = LC:ParseWeightText(trim(self.frame.weightInput:GetText()))
	if not minWidth or not weight then
		notify(L.COL_LAYOUT_INVALID or "Invalid column layout values.")
		return
	end

	LC:SetColumnLayout(ctx.profile, ctx.colId, minWidth, weight)
	self:ApplyChange(ctx)
	self:Hide()
end
