local _, GF = ...

GF.BlocklistPanel = {}
local BP = GF.BlocklistPanel

local WHITE = GF.WHITE_TEXTURE

local BLOCK_NAV_TOP_OFFSET = GF.TABLE_HEADER_STYLE.topOffset or -20
local BLOCK_NAV_BOTTOM_OFFSET = GF.BROWSE_HEADER_BOTTOM_OFFSET or -46
local BLOCK_LIST_GAP = GF.TABLE_HEADER_STYLE.listGap or 4
local HEADER_CONTENT_INSET_X = GF.TABLE_HEADER_STYLE.contentInsetX or 4
local HEADER_CONTENT_OFFSET_Y = GF.TABLE_HEADER_STYLE.contentOffsetY or 4
local HEADER_HEIGHT = GF.TABLE_HEADER_STYLE.height
	or math.abs(BLOCK_NAV_BOTTOM_OFFSET - BLOCK_NAV_TOP_OFFSET)
local TABLE_STYLE = GF.PLAYER_MANAGEMENT_STYLE
local ROW_HEIGHT = TABLE_STYLE.rowHeight
local ROW_TEXT_INSET = TABLE_STYLE.textInset
local ROW_COLUMN_OFFSET_X = HEADER_CONTENT_INSET_X
local NOTE_INPUT_HEIGHT = 24
local SCROLLBAR_GAP = 2
local SCROLL_BOTTOM_INSET = 2

local ROW_TEXTURE_PROFILE = GF.ROW_BACKGROUND_PROFILE or {}
local ROW_TEXTURE_SOURCE_WIDTH = ROW_TEXTURE_PROFILE.sourceWidth
	or GF.ROW_BACKGROUND_SOURCE_WIDTH
	or 564
local ROW_TEXTURE_SOURCE_HEIGHT = ROW_TEXTURE_PROFILE.sourceHeight
	or GF.ROW_BACKGROUND_SOURCE_HEIGHT
	or 52
local ROW_TEXTURE_SOURCE_CAP_WIDTH = ROW_TEXTURE_PROFILE.sourceCapWidth
	or GF.ROW_BACKGROUND_SOURCE_CAP_WIDTH
	or 18
local ROW_TEXTURE_EFFECTIVE_SOURCE_HEIGHT = math.max(
	1,
	ROW_TEXTURE_SOURCE_HEIGHT
		- (tonumber(ROW_TEXTURE_PROFILE.cropTopPixels) or 0)
		- (tonumber(ROW_TEXTURE_PROFILE.cropBottomPixels) or 0))
local ROW_TEXTURE_DISPLAY_HEIGHT = tonumber(
	ROW_TEXTURE_PROFILE.maxDisplayHeight) or 32
local ROW_TEXTURE_DISPLAY_CAP_WIDTH = math.max(
	1,
	math.floor(
		ROW_TEXTURE_DISPLAY_HEIGHT
			* ROW_TEXTURE_SOURCE_CAP_WIDTH
			/ ROW_TEXTURE_EFFECTIVE_SOURCE_HEIGHT
			+ 0.5))
local REASON_BADGE_HEIGHT = 19
local REASON_BADGE_MIN_WIDTH = 62
local REASON_BADGE_MAX_WIDTH = 112
local BODY_TEXT_COLOR = { 1, 0.94, 0.82, 1 }
local SECONDARY_TEXT_COLOR = { 0.72, 0.66, 0.5, 1 }
local BLACKLIST_DEFAULT_SORT_KEY = "updated"
local BLACKLIST_CATEGORY_SORT_KEY = "reason"

local REASON_BADGE_STYLE = {
	ad = { text = { 1, 0.84, 0.42, 1 }, border = { 0.72, 0.45, 0.16, 0.64 }, bg = { 0.12, 0.075, 0.028, 0.78 }, glow = { 0.90, 0.34, 0.04, 0.16 } },
	title_parent = { text = { 1, 0.88, 0.50, 1 }, border = { 0.82, 0.58, 0.18, 0.72 }, bg = { 0.14, 0.09, 0.03, 0.82 }, glow = { 1.00, 0.58, 0.05, 0.18 } },
	same_title_ad = { text = { 1, 0.84, 0.42, 1 }, border = { 0.72, 0.45, 0.16, 0.64 }, bg = { 0.12, 0.075, 0.028, 0.78 }, glow = { 0.90, 0.34, 0.04, 0.16 } },
	manual = { text = { 1, 0.54, 0.42, 1 }, border = { 0.96, 0.18, 0.10, 0.78 }, bg = { 0.20, 0.025, 0.020, 0.84 }, glow = { 1, 0.05, 0.02, 0.26 } },
}
local function T(key, fallback)
	local L = GF.L or {}
	return L[key] or fallback or key
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

local function createLabel(parent, text, size, justify)
	local label = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontHighlight")
	label:SetText(text or "")
	label:SetJustifyH(justify or "LEFT")
	label:SetJustifyV("MIDDLE")
	label:SetWordWrap(false)
	setFontSize(label, size or 12)
	return label
end

local function styleBlacklistInputBox(editBox)
	if not editBox or editBox._gfBlacklistInputStyled then
		return
	end
	editBox._gfBlacklistInputStyled = true
	editBox:SetTextColor(1, 0.96, 0.86, 1)
	editBox:SetShadowColor(0, 0, 0, 0.8)
	editBox:SetShadowOffset(1, -1)
	if editBox.SetTextInsets then
		editBox:SetTextInsets(10, 10, 0, 0)
	end
	GF.UI.StyleFilterNumberBox(editBox, {
		height = NOTE_INPUT_HEIGHT,
		justifyH = "LEFT",
		enabledTextColor = { 1, 0.96, 0.86, 1 },
	})
	if editBox.SetTextInsets then
		editBox:SetTextInsets(10, 10, 0, 0)
	end
	editBox:HookScript("OnEditFocusGained", function(self)
		self:HighlightText(0, 0)
		if self.SetCursorPosition then
			local text = self:GetText() or ""
			self:SetCursorPosition(strlen and strlen(text) or string.len(text))
		end
	end)
end

local function formatDateShort(timestamp)
	timestamp = tonumber(timestamp) or 0
	if timestamp > 0 and date then
		return date("%m-%d", timestamp)
	end
	return "-"
end

local function formatDateFull(timestamp)
	timestamp = tonumber(timestamp) or 0
	if timestamp > 0 and date then
		return date("%Y-%m-%d %H:%M", timestamp)
	end
	return "-"
end

local function getColumnLayout(width)
	local layout = GF.ColumnLayoutModel:ResolvePlayerManagementLayout(width)
	layout.reason = layout.category
	layout.category = nil
	return layout
end

local function applyColumnFrame(frame, layout)
	for _, key in ipairs({ "player", "reason", "note", "updated", "action" }) do
		local cell = frame[key]
		local slot = layout[key]
		cell:ClearAllPoints()
		cell:SetPoint("LEFT", frame, "LEFT", slot.x, 0)
		cell:SetSize(slot.width, frame:GetHeight() or HEADER_HEIGHT)
	end
end

local function addTooltipDoubleLine(label, value)
	if not (GameTooltip and value and value ~= "") then
		return
	end
	GameTooltip:AddDoubleLine(label, tostring(value), 1, 0.82, 0, 0.9, 0.82, 0.64)
end

local function showEntryTooltip(anchor, entry)
	if not (anchor and GameTooltip and entry) then
		return
	end
	local note = tostring(entry.note or "")
	GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(entry.displayName or entry.name or entry.key or "", 1, 0.82, 0, true)
	addTooltipDoubleLine(
		T("BLOCKLIST_COL_REASON", "Category"),
		entry.reasonText or entry.reason or "")
	addTooltipDoubleLine(
		T("BLOCKLIST_SOURCE", "Source"),
		entry.sourceText or "")
	addTooltipDoubleLine(T("BLOCKLIST_REALM", "Realm"), entry.realm)
	addTooltipDoubleLine(T("BLOCKLIST_COL_UPDATED", "Updated"), formatDateFull(entry.updatedAt or entry.addedAt))
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(T("BLOCKLIST_COL_NOTE", "Note"), 1, 0.82, 0, true)
	GameTooltip:AddLine(note ~= "" and note or T("BLOCKLIST_NO_NOTE", "No note"), 0.9, 0.82, 0.64, true)
	GameTooltip:Show()
end

local function hideTooltip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

local function createRowBackgroundPieces(row, subLevel)
	local pieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(row, "BACKGROUND", subLevel or 0)
		or nil
	if not (pieces and pieces.left and pieces.middle and pieces.right) then
		pieces = {}
		for _, key in ipairs({ "left", "middle", "right" }) do
			pieces[key] = row:CreateTexture(nil, "BACKGROUND", nil, subLevel or 0)
		end
	end
	return pieces
end

local function applyRowBackgroundPieces(row, pieces)
	if GF.UI and GF.UI.ApplyRowBackgroundPieces then
		return GF.UI.ApplyRowBackgroundPieces(row, pieces, {
			state = "red",
			mode = "full",
			alpha = GF.GetListBackgroundAlpha and GF.GetListBackgroundAlpha("red") or (GF.BROWSE_ROW_BACKGROUND_ALPHA or 0.92),
			fallbackTexture = WHITE,
			defaultHeight = ROW_HEIGHT,
		})
	end
	local capWidth = ROW_TEXTURE_DISPLAY_CAP_WIDTH
	local leftCoord = ROW_TEXTURE_SOURCE_CAP_WIDTH / ROW_TEXTURE_SOURCE_WIDTH
	local rightCoord = 1 - leftCoord
	local left = pieces and pieces.left
	local right = pieces and pieces.right
	local middle = pieces and pieces.middle
	if not (left and right and middle) then
		return false
	end
	left:ClearAllPoints()
	left:SetPoint("LEFT", row, "LEFT", 0, 0)
	left:SetSize(capWidth, ROW_TEXTURE_DISPLAY_HEIGHT)
	left:SetTexture(WHITE)
	left:SetTexCoord(0, leftCoord, 0, 1)
	right:ClearAllPoints()
	right:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	right:SetSize(capWidth, ROW_TEXTURE_DISPLAY_HEIGHT)
	right:SetTexture(WHITE)
	right:SetTexCoord(rightCoord, 1, 0, 1)
	middle:ClearAllPoints()
	middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
	middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
	middle:SetHeight(ROW_TEXTURE_DISPLAY_HEIGHT)
	middle:SetTexture(WHITE)
	middle:SetTexCoord(leftCoord, rightCoord, 0, 1)
	local color = GF.ROW_BACKGROUND_STATE_COLORS and GF.ROW_BACKGROUND_STATE_COLORS.red or { 1, 0.16, 0.12, 1 }
	for _, piece in ipairs({ left, middle, right }) do
		piece:SetVertexColor(color[1] or 1, color[2] or 0.16, color[3] or 0.12, color[4] or 1)
		piece:SetAlpha(GF.GetListBackgroundAlpha and GF.GetListBackgroundAlpha("red") or (GF.BROWSE_ROW_BACKGROUND_ALPHA or 0.92))
		piece:Show()
	end
	return true
end

local function applyRowHoverPieces(row)
	if not (row and row.HoverPieces
		and GF.UI and GF.UI.ApplyRowBackgroundPieces)
	then
		return false
	end
	local color = GF.GetListBackgroundOverlayColor
		and GF.GetListBackgroundOverlayColor("red", "hover")
		or { 1, 0.08, 0.05, 0.18 }
	return GF.UI.ApplyRowBackgroundPieces(row, row.HoverPieces, {
		state = "red",
		mode = "full",
		alpha = GF.BROWSE_ROW_SELECTED_ALPHA or 1,
		vertexColor = color,
		desaturated = true,
		fallbackTexture = WHITE,
		defaultHeight = ROW_HEIGHT,
	})
end

local function setRowHover(row, shown)
	row._hoverShown = shown == true
	if GF.UI and GF.UI.SetRowBackgroundPiecesShown then
		GF.UI.SetRowBackgroundPiecesShown(row.HoverPieces, row._hoverShown)
		return
	end
	for _, piece in pairs(row.HoverPieces or {}) do
		piece:SetShown(row._hoverShown)
	end
end

local function setReasonBadgeStyle(reasonFrame, reason)
	local style = REASON_BADGE_STYLE[reason] or REASON_BADGE_STYLE.manual
	local bg = style.bg
	local border = style.border
	local glow = style.glow
	local text = style.text
	reasonFrame.Shadow:SetVertexColor(0, 0, 0, 0.52)
	reasonFrame.Background:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
	reasonFrame.Glow:SetVertexColor(glow[1], glow[2], glow[3], glow[4])
	reasonFrame.Sheen:SetVertexColor(1, 0.86, 0.44, 0.10)
	reasonFrame.TopLine:SetVertexColor(border[1], border[2], border[3], border[4])
	reasonFrame.BottomLine:SetVertexColor(border[1], border[2], border[3], math.min((border[4] or 0.44) * 0.6, 1))
	reasonFrame.LeftLine:SetVertexColor(border[1], border[2], border[3], math.min((border[4] or 0.44) * 0.75, 1))
	reasonFrame.RightLine:SetVertexColor(border[1], border[2], border[3], math.min((border[4] or 0.44) * 0.45, 1))
	reasonFrame.Label:SetTextColor(text[1], text[2], text[3], text[4])
end

local function createActionButton(parent, text)
	return GF.UI.CreatePlayerManagementButton(parent, text)
end

local function setActionButtonClick(button, handler)
	if not button then
		return
	end
	button:SetScript("OnClick", function(...)
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		if handler then
			handler(...)
		end
	end)
end

local function setSaveButtonEnabled(row, enabled)
	if not row or not row.SaveButton then
		return
	end
	row.SaveButton:SetEnabled(enabled == true)
end

local function createReasonFrame(parent)
	local reasonFrame = CreateFrame("Frame", nil, parent)
	reasonFrame.Shadow = reasonFrame:CreateTexture(nil, "BACKGROUND", nil, -2)
	reasonFrame.Shadow:SetPoint("TOPLEFT", reasonFrame, "TOPLEFT", -1, 1)
	reasonFrame.Shadow:SetPoint("BOTTOMRIGHT", reasonFrame, "BOTTOMRIGHT", 1, -1)
	reasonFrame.Shadow:SetTexture(WHITE)
	reasonFrame.Background = reasonFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
	reasonFrame.Background:SetAllPoints(reasonFrame)
	reasonFrame.Background:SetTexture(WHITE)
	reasonFrame.Glow = reasonFrame:CreateTexture(nil, "BORDER", nil, 0)
	reasonFrame.Glow:SetPoint("TOPLEFT", reasonFrame, "TOPLEFT", 1, -1)
	reasonFrame.Glow:SetPoint("BOTTOMRIGHT", reasonFrame, "BOTTOMRIGHT", -1, 1)
	reasonFrame.Glow:SetTexture(WHITE)
	reasonFrame.Sheen = reasonFrame:CreateTexture(nil, "BORDER", nil, 1)
	reasonFrame.Sheen:SetPoint("TOPLEFT", reasonFrame, "TOPLEFT", 1, -1)
	reasonFrame.Sheen:SetPoint("TOPRIGHT", reasonFrame, "TOPRIGHT", -1, -1)
	reasonFrame.Sheen:SetHeight(7)
	reasonFrame.Sheen:SetTexture(WHITE)
	for _, key in ipairs({ "TopLine", "BottomLine", "LeftLine", "RightLine" }) do
		reasonFrame[key] = reasonFrame:CreateTexture(nil, "BORDER")
		reasonFrame[key]:SetTexture(WHITE)
	end
	reasonFrame.TopLine:SetPoint("TOPLEFT", reasonFrame, "TOPLEFT", 1, -1)
	reasonFrame.TopLine:SetPoint("TOPRIGHT", reasonFrame, "TOPRIGHT", -1, -1)
	reasonFrame.TopLine:SetHeight(1)
	reasonFrame.BottomLine:SetPoint("BOTTOMLEFT", reasonFrame, "BOTTOMLEFT", 1, 1)
	reasonFrame.BottomLine:SetPoint("BOTTOMRIGHT", reasonFrame, "BOTTOMRIGHT", -1, 1)
	reasonFrame.BottomLine:SetHeight(1)
	reasonFrame.LeftLine:SetPoint("TOPLEFT", reasonFrame, "TOPLEFT", 1, -1)
	reasonFrame.LeftLine:SetPoint("BOTTOMLEFT", reasonFrame, "BOTTOMLEFT", 1, 1)
	reasonFrame.LeftLine:SetWidth(1)
	reasonFrame.RightLine:SetPoint("TOPRIGHT", reasonFrame, "TOPRIGHT", -1, -1)
	reasonFrame.RightLine:SetPoint("BOTTOMRIGHT", reasonFrame, "BOTTOMRIGHT", -1, 1)
	reasonFrame.RightLine:SetWidth(1)
	reasonFrame.Label = createLabel(reasonFrame, "", 12, "CENTER")
	reasonFrame.Label:SetPoint("LEFT", reasonFrame, "LEFT", 6, 0)
	reasonFrame.Label:SetPoint("RIGHT", reasonFrame, "RIGHT", -6, 0)
	reasonFrame.Label:SetHeight(REASON_BADGE_HEIGHT)
	return reasonFrame
end

local function initializeRow(row)
	if not row or row._gfBlacklistRowInitialized then
		return
	end
	row._gfBlacklistRowInitialized = true
	row:SetHeight(ROW_HEIGHT)
	row.Background = row:CreateTexture(nil, "BACKGROUND")
	row.Background:SetAllPoints(row)
	row.Background:SetTexture(WHITE)
	row.Background:SetVertexColor(0, 0, 0, 0.22)
	row.BackgroundPieces = createRowBackgroundPieces(row, -1)
	applyRowBackgroundPieces(row, row.BackgroundPieces)

	row.HoverPieces = GF.UI.CreateRowBackgroundPieces(row, "BORDER", 3)
	for _, piece in pairs(row.HoverPieces) do
		if piece.SetBlendMode then
			piece:SetBlendMode("ADD")
		end
	end
	applyRowHoverPieces(row)
	setRowHover(row, false)

	row.Name = createLabel(row, "", 13, "LEFT")
	row.Name:SetTextColor(BODY_TEXT_COLOR[1], BODY_TEXT_COLOR[2], BODY_TEXT_COLOR[3], BODY_TEXT_COLOR[4])
	row.NameHitBox = CreateFrame("Frame", nil, row)
	row.NameHitBox:EnableMouse(true)
	row.Reason = createReasonFrame(row)
	row.NoteText = createLabel(row, "", 12, "LEFT")
	row.NoteText:SetTextColor(BODY_TEXT_COLOR[1], BODY_TEXT_COLOR[2], BODY_TEXT_COLOR[3], BODY_TEXT_COLOR[4])
	row.NoteHitBox = CreateFrame("Button", nil, row)
	row.NoteHitBox:EnableMouse(true)
	row.NoteBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	row.NoteBox:SetAutoFocus(false)
	row.NoteBox:SetMaxLetters(140)
	row.NoteBox:SetHeight(NOTE_INPUT_HEIGHT)
	row.NoteBox:SetTextColor(1, 0.96, 0.86, 1)
	row.NoteBox:SetJustifyH("LEFT")
	row.NoteBox:SetJustifyV("MIDDLE")
	GF.UI.TrackEditBox(row.NoteBox, "GameFontHighlightSmall")
	styleBlacklistInputBox(row.NoteBox)
	row.NoteBox:Hide()
	row.DateFrame = CreateFrame("Frame", nil, row)
	row.DateFrame:EnableMouse(true)
	row.Date = createLabel(row.DateFrame, "", 12, "CENTER")
	row.Date:SetAllPoints(row.DateFrame)
	row.Date:SetTextColor(SECONDARY_TEXT_COLOR[1], SECONDARY_TEXT_COLOR[2], SECONDARY_TEXT_COLOR[3], SECONDARY_TEXT_COLOR[4])
	row.EditButton = createActionButton(row, T("BLOCKLIST_EDIT", "Edit"))
	row.RemoveButton = createActionButton(row, T("BLOCKLIST_REMOVE", "Remove"))
	row.SaveButton = createActionButton(row, T("BLOCKLIST_SAVE", "Save"))
	row.CancelButton = createActionButton(row, T("CANCEL", "Cancel"))
	row:SetScript("OnEnter", function(self) setRowHover(self, true) end)
	row:SetScript("OnLeave", function(self) setRowHover(self, false) end)
	for _, child in ipairs({ row.NameHitBox, row.NoteHitBox, row.DateFrame }) do
		child:SetScript("OnEnter", function()
			setRowHover(row, true)
		end)
		child:SetScript("OnLeave", function()
			setRowHover(row, false)
			hideTooltip()
		end)
	end
	for _, button in ipairs({ row.EditButton, row.RemoveButton, row.SaveButton, row.CancelButton }) do
		button:HookScript("OnEnter", function()
			setRowHover(row, true)
		end)
		button:HookScript("OnLeave", function()
			setRowHover(row, false)
		end)
	end
end

local function layoutRow(row, layout, width)
	row:SetWidth(math.max(width or layout.totalWidth or 1, 1))
	local offsetX = ROW_COLUMN_OFFSET_X
	row.Name:ClearAllPoints()
	row.Name:SetPoint("LEFT", row, "LEFT", offsetX + layout.player.x + ROW_TEXT_INSET, 0)
	row.Name:SetSize(math.max(layout.player.width - ROW_TEXT_INSET * 2, 1), ROW_HEIGHT)
	row.NameHitBox:ClearAllPoints()
	row.NameHitBox:SetPoint("LEFT", row, "LEFT", offsetX + layout.player.x, 0)
	row.NameHitBox:SetSize(layout.player.width, ROW_HEIGHT)
	row.Reason:ClearAllPoints()
	row.Reason:SetPoint("CENTER", row, "LEFT", offsetX + layout.reason.x + layout.reason.width / 2, 0)
	local reasonWidth = math.min(math.max(layout.reason.width - ROW_TEXT_INSET * 2, REASON_BADGE_MIN_WIDTH), REASON_BADGE_MAX_WIDTH)
	row.Reason:SetSize(reasonWidth, REASON_BADGE_HEIGHT)
	row.NoteText:ClearAllPoints()
	row.NoteText:SetPoint("LEFT", row, "LEFT", offsetX + layout.note.x + ROW_TEXT_INSET, 0)
	row.NoteText:SetSize(math.max(layout.note.width - ROW_TEXT_INSET * 2, 1), ROW_HEIGHT)
	row.NoteHitBox:ClearAllPoints()
	row.NoteHitBox:SetPoint("LEFT", row, "LEFT", offsetX + layout.note.x, 0)
	row.NoteHitBox:SetSize(layout.note.width, ROW_HEIGHT)
	row.NoteBox:ClearAllPoints()
	row.NoteBox:SetPoint("LEFT", row, "LEFT", offsetX + layout.note.x + ROW_TEXT_INSET, 0)
	row.NoteBox:SetSize(math.max(layout.note.width - ROW_TEXT_INSET * 2, 1), NOTE_INPUT_HEIGHT)
	row.DateFrame:ClearAllPoints()
	row.DateFrame:SetPoint("LEFT", row, "LEFT", offsetX + layout.updated.x, 0)
	row.DateFrame:SetSize(layout.updated.width, ROW_HEIGHT)
	local action = { x = offsetX + layout.action.x, width = layout.action.width }
	GF.UI.LayoutPlayerManagementActions(row, row.EditButton, row.RemoveButton, action)
	GF.UI.LayoutPlayerManagementActions(row, row.SaveButton, row.CancelButton, action)
end

local function beginRowEdit(widgets, row, entry)
	local presenter = GF.BlacklistPresenter
	if not presenter or not presenter:BeginNoteEdit(entry.key) then
		return
	end
	BP:Refresh()
	local activeRow = widgets.virtualList
		and widgets.virtualList:FindFrameByKey(entry.key) or row
	if activeRow and activeRow.NoteBox
		and activeRow._entryKey == entry.key
	then
		activeRow.NoteBox:SetFocus()
		activeRow.NoteBox:HighlightText()
	end
end

local function cancelRowEdit(widgets)
	local presenter = GF.BlacklistPresenter
	if presenter then
		presenter:CancelNoteEdit()
	end
	BP:Refresh()
end

local function saveRowEdit(widgets)
	local presenter = GF.BlacklistPresenter
	local plan = presenter and presenter:PlanSaveNote()
	if not plan then
		return
	end
	if presenter:ConfirmSaveNote(plan) ~= true then
		BP:Refresh()
	end
end

local function showRemoveConfirm(entry)
	local presenter = GF.BlacklistPresenter
	local plan = presenter and entry
		and presenter:PlanRemove(entry.key) or nil
	if not plan then
		return
	end
	local dialog = GF.BlacklistConfirmDialog
	if not (dialog and type(dialog.Show) == "function") then
		presenter:CancelRemove(plan.ticket)
		return
	end
	dialog:Show({
		messageKey = "BLOCKLIST_REMOVE_PLAYER_CONFIRM",
		messageFallback = "Remove this player from the blacklist?",
		onAccept = function()
			return presenter:ConfirmRemove(plan) == true
		end,
		onCancel = function()
			presenter:CancelRemove(plan.ticket)
		end,
	})
end

local function refreshRow(widgets, row, entry)
	local presenter = GF.BlacklistPresenter
	row._entryKey = entry.key
	local isEditing = presenter
		and presenter:IsSelected(entry.key, "edit-note") == true
	applyRowBackgroundPieces(row, row.BackgroundPieces)
	applyRowHoverPieces(row)
	setRowHover(row, false)
	row.Name:SetText(entry.displayName or entry.name or entry.key or "")
	row.EditButton:SetText(T("BLOCKLIST_EDIT", "Edit"))
	row.RemoveButton:SetText(T("BLOCKLIST_REMOVE", "Remove"))
	row.SaveButton:SetText(T("BLOCKLIST_SAVE", "Save"))
	row.CancelButton:SetText(T("CANCEL", "Cancel"))
	row.NameHitBox:SetScript("OnEnter", function()
		setRowHover(row, true)
		showEntryTooltip(row.NameHitBox, entry)
	end)
	local reason = entry.reason or "manual"
	row.Reason.Label:SetText(entry.reasonText or reason)
	setReasonBadgeStyle(row.Reason, reason)
	local note = entry.note or ""
	local noteText = note ~= "" and note or T("BLOCKLIST_NO_NOTE", "No note")
	row.NoteText:SetText(noteText)
	if note ~= "" then
		row.NoteText:SetTextColor(BODY_TEXT_COLOR[1], BODY_TEXT_COLOR[2], BODY_TEXT_COLOR[3], 1)
	else
		row.NoteText:SetTextColor(SECONDARY_TEXT_COLOR[1], SECONDARY_TEXT_COLOR[2], SECONDARY_TEXT_COLOR[3], 1)
	end
	row.NoteHitBox:SetScript("OnClick", function()
		beginRowEdit(widgets, row, entry)
	end)
	row.NoteHitBox:SetScript("OnEnter", function()
		setRowHover(row, true)
		showEntryTooltip(row.NoteHitBox, entry)
	end)
	row.Date:SetText(formatDateShort(entry.updatedAt or entry.addedAt))
	row.DateFrame:SetScript("OnEnter", function()
		setRowHover(row, true)
		showEntryTooltip(row.DateFrame, entry)
	end)
	setActionButtonClick(row.EditButton, function()
		beginRowEdit(widgets, row, entry)
	end)
	setActionButtonClick(row.RemoveButton, function()
		showRemoveConfirm(entry)
	end)
	setActionButtonClick(row.CancelButton, function()
		cancelRowEdit(widgets)
	end)
	setActionButtonClick(row.SaveButton, function()
		if presenter and presenter:CanSaveNote() then
			saveRowEdit(widgets)
		end
	end)
	row.NoteText:SetShown(not isEditing)
	row.NoteHitBox:SetShown(not isEditing)
	row.EditButton:SetShown(not isEditing)
	row.RemoveButton:SetShown(not isEditing)
	row.NoteBox:SetShown(isEditing)
	row.CancelButton:SetShown(isEditing)
	if isEditing then
		row.SaveButton:Show()
		local draft = presenter:GetNoteDraft(entry.key) or note
		if row.NoteBox:GetText() ~= draft then
			row.NoteBox:SetText(draft)
		end
		row.NoteBox:SetScript("OnTextChanged", function(self)
			if not presenter:IsSelected(entry.key, "edit-note") then
				return
			end
			presenter:UpdateNoteDraft(self:GetText() or "")
			setSaveButtonEnabled(row, presenter:CanSaveNote())
		end)
		row.NoteBox:SetScript("OnEscapePressed", function()
			cancelRowEdit(widgets)
		end)
		row.NoteBox:SetScript("OnEnterPressed", function()
			if presenter:CanSaveNote() then
				saveRowEdit(widgets)
			else
				cancelRowEdit(widgets)
			end
		end)
		setSaveButtonEnabled(row, presenter:CanSaveNote())
	else
		row.NoteBox:ClearFocus()
		row.NoteBox:SetScript("OnTextChanged", nil)
		row.NoteBox:SetScript("OnEscapePressed", nil)
		row.NoteBox:SetScript("OnEnterPressed", nil)
		row.SaveButton:Hide()
		setSaveButtonEnabled(row, true)
	end
	row:Show()
end

local function relayoutVisibleRows(widgets)
	local list = widgets and widgets.virtualList
	if not list then
		return
	end
	local layout = widgets.columnLayout
		or getColumnLayout(list:GetLayoutWidth())
	local width = math.max(list:GetLayoutWidth(), layout.totalWidth or 1)
	list:ForEachFrame(function(row)
		initializeRow(row)
		layoutRow(row, layout, width)
	end)
end

local function createVirtualList(parent, widgets)
	local owner = GF.UI and GF.UI.VirtualList
	if not owner or type(owner.Create) ~= "function" then
		return nil
	end
	local list = owner.Create(parent, {
		assignedKey = "key",
		rowHeight = ROW_HEIGHT,
		smoothWheel = true,
		barParent = parent,
		barOffsetX = SCROLLBAR_GAP,
		keepNativeScrollBar = true,
		elementFactory = function(factory)
			factory("Frame", initializeRow)
		end,
	})
	if not list then
		return nil
	end
	local scrollFrame = list:GetScrollBox()
	local scrollBar = list:GetScrollBar()
	if scrollBar and GF.UI.ApplyCommonScrollBarSkin then
		GF.UI.ApplyCommonScrollBarSkin(scrollBar)
	end
	if ScrollUtil and type(ScrollUtil.AddInitializedFrameCallback) == "function" then
		ScrollUtil.AddInitializedFrameCallback(
			scrollFrame,
			function(_, row, entry)
				initializeRow(row)
				local layout = widgets.columnLayout
					or getColumnLayout(list:GetLayoutWidth())
				layoutRow(
					row,
					layout,
					math.max(list:GetLayoutWidth(), layout.totalWidth or 1))
				refreshRow(widgets, row, entry)
			end,
			widgets,
			false)
	end
	return list
end

local HEADER_COLUMNS = { "player", "reason", "note", "updated", "action" }
local HEADER_LABELS = {
	player = "BLOCKLIST_COL_PLAYER", reason = "BLOCKLIST_COL_REASON", note = "BLOCKLIST_COL_NOTE",
	updated = "BLOCKLIST_COL_UPDATED", action = "BLOCKLIST_COL_ACTION",
}

local function applyHeaderLayout(widgets)
	local width = widgets.scrollFrame and widgets.scrollFrame:GetWidth() or widgets.header:GetWidth()
	GF.ColumnHeaderBar:Layout(widgets.header, width)
end

local function addColumnHeader(blockNav, widgets)
	GF.UI.InstallBrowseHeaderChrome(blockNav, { backgroundInsetLeft = 0 })
	local header = GF.ColumnHeaderBar:Create(blockNav, {
		mode = "custom", profile = "blacklist", contentHeight = HEADER_HEIGHT,
		alignColumns = true,
		resolveLayout = function(width)
			local columns = getColumnLayout(math.max(width - TABLE_STYLE.layoutWidthInset, 1))
			local layout = { active = HEADER_COLUMNS, byId = columns, headerLayout = {} }
			for index, key in ipairs(HEADER_COLUMNS) do
				layout.headerLayout[index] = { width = columns[key].width }
			end
			return layout
		end,
		getHeaderLabel = function(key) return T(HEADER_LABELS[key]) end,
		isSortable = function(key)
			return key == BLACKLIST_CATEGORY_SORT_KEY or key == BLACKLIST_DEFAULT_SORT_KEY
		end,
		onColumnClick = function(key)
			local presenter = GF.BlacklistPresenter
			if not presenter then return end
			presenter:ToggleSort(key)
			presenter:CancelNoteEdit()
		end,
		onSort = function() BP:Refresh(true) end,
		getSortState = function()
			local presenter = GF.BlacklistPresenter
			if not presenter then return nil end
			local sort = presenter:GetSortState()
			-- Only category sorting displays a direction arrow.
			return sort.column == BLACKLIST_CATEGORY_SORT_KEY and sort or nil
		end,
		updateHeader = function(cell, key, _, _, bar)
			cell.Text = cell:GetFontString()
			bar[key] = cell
		end,
		onLayoutResolved = function(layout, bar)
			widgets.columnLayout = layout.byId
			bar.accents = bar._columnDividers
			if widgets.footer then
				local action = layout.byId.action
				widgets.footer:Layout({ x = ROW_COLUMN_OFFSET_X + action.x, width = action.width })
			end
		end,
	})
	header:SetPoint("TOPLEFT", blockNav, "TOPLEFT", HEADER_CONTENT_INSET_X, HEADER_CONTENT_OFFSET_Y)
	header:SetPoint("BOTTOMRIGHT", blockNav, "BOTTOMRIGHT", -HEADER_CONTENT_INSET_X, HEADER_CONTENT_OFFSET_Y)
	header:SetHeight(HEADER_HEIGHT)
	header:SetFrameLevel(blockNav:GetFrameLevel() + 3)
	return header
end

local function refreshHeaderLocale(widgets)
	if widgets and widgets.header then GF.ColumnHeaderBar:RefreshLocale(widgets.header) end
end

local function cancelClearConfirmation()
	local request = BP.clearRequest
	BP.clearRequest = nil
	if request then
		GF.BlacklistPresenter:CancelClear(request.ticket)
		GF.BlacklistConfirmDialog:Hide(request)
	end
end

local function confirmClear()
	local presenter, confirmation = GF.BlacklistPresenter, GF.BlacklistConfirmDialog
	if not presenter or not confirmation or not BP.blockContent:IsShown() then return end
	cancelClearConfirmation()
	local ticket = presenter:PlanClear()
	if not ticket then return end
	if GF.BlacklistMenu.dialog then GF.BlacklistMenu.dialog:Hide() end
	BP.footer.searchEdit:ClearFocus()
	local request = { ticket = ticket, messageKey = "SET_BLACKLIST_CLEAR_CONFIRM" }
	request.onAccept = function()
		if BP.clearRequest ~= request or not BP.blockContent:IsShown() then return false end
		if not presenter:ConfirmClear(ticket) then return false end
		BP.clearRequest = nil
		BP.footer.searchEdit:SetText("")
		BP:Refresh(true)
		return true
	end
	request.onCancel = function()
		presenter:CancelClear(ticket)
		if BP.clearRequest == request then BP.clearRequest = nil end
	end
	BP.clearRequest = request
	confirmation:Show(request)
end

function BP:Init(parent)
	if self.blockContent then
		return
	end
	self.parent = parent
	self.blockContent = parent
	local footer = GF.UI.CreatePlayerManagementFooter(parent)
	self.footer = footer
	footer.searchEdit:HookScript("OnTextChanged", function()
		if GF.BlacklistPresenter then GF.BlacklistPresenter:CancelNoteEdit() end
		BP:Refresh(true)
	end)
	footer.primaryButton:SetScript("OnClick", function()
		cancelClearConfirmation()
		footer.searchEdit:ClearFocus()
		GF.BlacklistMenu:OpenManualAddDialog()
	end)
	footer.secondaryButton:SetScript("OnClick", confirmClear)
	parent:HookScript("OnHide", function()
		cancelClearConfirmation()
		if GF.BlacklistMenu and GF.BlacklistMenu.dialog then GF.BlacklistMenu.dialog:Hide() end
	end)

	local blockNav = CreateFrame("Frame", nil, parent)
	blockNav:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, BLOCK_NAV_TOP_OFFSET)
	blockNav:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, BLOCK_NAV_TOP_OFFSET)
	blockNav:SetHeight(HEADER_HEIGHT)
	blockNav:SetFrameLevel(parent:GetFrameLevel() + 2)

	local blocklist = CreateFrame("Frame", nil, parent)
	blocklist:SetPoint("TOPLEFT", blockNav, "BOTTOMLEFT", 0, -BLOCK_LIST_GAP)
	blocklist:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, BLOCK_LIST_GAP)
	blocklist:SetFrameLevel(parent:GetFrameLevel() + 1)

	local widgets = { footer = footer }
	local header = addColumnHeader(blockNav, widgets)
	local virtualList = createVirtualList(blocklist, widgets)
	local scrollFrame = virtualList and virtualList:GetScrollBox()
	local scrollBar = virtualList and virtualList:GetScrollBar()
	if scrollFrame then
		scrollFrame:SetPoint("TOPLEFT", blocklist, "TOPLEFT", 0, 0)
		scrollFrame:SetPoint(
			"BOTTOMRIGHT",
			blocklist,
			"BOTTOMRIGHT",
			0,
			SCROLL_BOTTOM_INSET)
	end
	if scrollFrame and scrollFrame.SetClipsChildren then
		scrollFrame:SetClipsChildren(true)
	end
	local empty = GF.UI.CreateFontString(blocklist, "OVERLAY", "GameFontDisable")
	empty:SetPoint("LEFT", blocklist, "LEFT", 0, 0)
	empty:SetPoint("RIGHT", blocklist, "RIGHT", 0, 0)
	empty:SetHeight(32)
	empty:SetJustifyH("CENTER")
	empty:SetJustifyV("MIDDLE")
	empty:SetTextColor(1, 0.82, 0, 1)
	if GF.UI and GF.UI.ApplyEmptyPromptFont then
		GF.UI.ApplyEmptyPromptFont(empty, "GameFontDisable")
	end
	widgets.blockContent = parent
	widgets.blockNav = blockNav
	widgets.blocklist = blocklist
	widgets.header = header
	widgets.scrollFrame = scrollFrame
	widgets.scrollBar = scrollBar
	widgets.virtualList = virtualList
	widgets.empty = empty
	local function onScrollSizeChanged()
		if not BP.blockContent or not BP.blockContent:IsShown() then
			return
		end
		applyHeaderLayout(widgets)
		relayoutVisibleRows(widgets)
	end
	if scrollFrame then
		scrollFrame:HookScript("OnSizeChanged", onScrollSizeChanged)
	end
	self.blockNav = blockNav
	self.blocklist = blocklist
	self.widgets = widgets
	if virtualList then
		if scrollBar then
			scrollBar:SetWidth(TABLE_STYLE.scrollBarWidth)
			scrollBar:ClearAllPoints()
			scrollBar:SetPoint("TOPRIGHT", blocklist, "TOPRIGHT", -TABLE_STYLE.scrollBarRightInset, 0)
			scrollBar:SetPoint("BOTTOMRIGHT", blocklist, "BOTTOMRIGHT", -TABLE_STYLE.scrollBarRightInset, SCROLL_BOTTOM_INSET)
		end
		virtualList:BindDynamicScrollBar({
			gutter = TABLE_STYLE.scrollBarGutter,
			duration = TABLE_STYLE.scrollBarDuration,
			overflowEpsilon = TABLE_STYLE.scrollBarOverflowEpsilon,
			onInsetChanged = function(inset)
				scrollFrame:SetPoint("BOTTOMRIGHT", blocklist, "BOTTOMRIGHT", -inset, SCROLL_BOTTOM_INSET)
			end,
		})
	end
	self:Refresh()
end

function BP:Refresh(resetScroll)
	local widgets = self.widgets
	if not widgets or not widgets.virtualList then
		return
	end
	if self.blockContent and not self.blockContent:IsShown() then
		return
	end
	local presenter = GF.BlacklistPresenter
	local rows, total = {}, 0
	local query = self.footer.searchEdit:GetText()
	if presenter then
		local revision
		rows, revision, total = presenter:RefreshProjection(query)
		total = total or #rows
	end
	self.footer.heading:SetText(string.format(T("BLOCKLIST_TITLE_FMT", "Blacklist (%d)"), total))
	self.footer.hint:SetText(T("BLOCKLIST_HINT"))
	self.footer.primaryButton:SetText(T("BLOCKLIST_ADD", "Add"))
	self.footer.secondaryButton:SetText(T("BLOCKLIST_CLEAR", "Clear"))
	self.footer.primaryButton:SetEnabled(presenter and presenter:CanAddManualPlayer() or false)
	self.footer.secondaryButton:SetEnabled(total > 0)
	self.footer.searchEdit.Instructions:SetText(T("BLOCKLIST_SEARCH_HINT"))
	self.footer.searchEdit.Instructions:SetShown(query == "")
	refreshHeaderLocale(widgets)
	applyHeaderLayout(widgets)
	if widgets.empty then
		widgets.empty:SetText(query:find("%S") and T("BLOCKLIST_NO_MATCHES") or T("BLOCKLIST_EMPTY", "No blacklist records"))
		widgets.empty:SetShown(#rows == 0)
	end
	widgets.virtualList:SetElements(rows, {
		retainIdentity = resetScroll ~= true,
		retainScroll = resetScroll ~= true,
	})
	relayoutVisibleRows(widgets)
end

function BP:RefreshList()
	self:Refresh()
end

function BP:RefreshLocale()
	self:Refresh()
end

function BP:Show()
	if self.blockContent then
		self.blockContent:Show()
	end
	self:Refresh()
end

function BP:Hide()
	hideTooltip()
	local content = self.blockContent
	if content and content.Hide then
		content:Hide()
	end
end

function BP:ApplyModuleVisibility()
	local presenter = GF.BlacklistPresenter
	local enabled = presenter and presenter:IsEnabled() or false
	local tabs = GF.TabBar
	if tabs and tabs.SetBlocklistTabVisible then
		tabs:SetBlocklistTabVisible(enabled)
	end
end
