local _, GF = ...

GF.BlocklistPanel = {}
local BP = GF.BlocklistPanel

local WHITE = GF.WHITE_TEXTURE
local REMOVE_DIALOG_ICON_TEXTURE = GF.BLACKLIST_ICON_TEXTURE

local BLOCK_NAV_TOP_OFFSET = GF.BROWSE_HEADER_TOP_OFFSET or -20
local BLOCK_NAV_BOTTOM_OFFSET = GF.BROWSE_HEADER_BOTTOM_OFFSET or -46
local BLOCK_LIST_GAP = GF.SHARED_TABLE_HEADER_LIST_GAP or 4
local HEADER_CONTENT_INSET_X = GF.BROWSE_HEADER_CONTENT_INSET_X or 4
local HEADER_CONTENT_OFFSET_Y = GF.BROWSE_HEADER_CONTENT_OFFSET_Y or 4
local HEADER_HEIGHT = GF.SHARED_TABLE_HEADER_HEIGHT
	or math.abs(BLOCK_NAV_BOTTOM_OFFSET - BLOCK_NAV_TOP_OFFSET)
local HEADER_TEXT_SIZE = GF.BROWSE_HEADER_TEXT_SIZE or 14
local HEADER_TEXT_INSET_X = GF.BROWSE_HEADER_TEXT_INSET_X or 3
local HEADER_TEXT_PRESSED_OFFSET_X = GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_X or 1
local HEADER_TEXT_PRESSED_OFFSET_Y = GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_Y or -1
local HEADER_NORMAL_TEXT_COLOR = GF.BROWSE_HEADER_TEXT_COLOR or { 1, 0.82, 0, 1 }
local HEADER_HOVER_TEXT_COLOR = GF.BROWSE_HEADER_HOVER_TEXT_COLOR or { 1, 0.96, 0.58, 1 }
local HEADER_PRESSED_TEXT_COLOR = GF.BROWSE_HEADER_PRESSED_TEXT_COLOR or { 0.95, 0.68, 0.18, 1 }
local HEADER_ACCENT_WIDTH = GF.BROWSE_HEADER_ACCENT_WIDTH or 1.5
local HEADER_ACCENT_HEIGHT = GF.BROWSE_HEADER_ACCENT_HEIGHT or 22
local HEADER_ACCENT_COLOR = GF.BROWSE_HEADER_ACCENT_COLOR or { 126 / 255, 112 / 255, 82 / 255 }
local HEADER_ACCENT_ALPHA = GF.BROWSE_HEADER_ACCENT_ALPHA or 0.6

local ROW_HEIGHT = 36
local ROW_TEXT_INSET = 10
local ROW_COLUMN_OFFSET_X = HEADER_CONTENT_INSET_X
local NOTE_INPUT_HEIGHT = 24
local ACTION_BUTTON_WIDTH = 64
local ACTION_BUTTON_HEIGHT = 26
local ACTION_BUTTON_GAP = 6
local ACTION_COLUMN_MIN_WIDTH = ACTION_BUTTON_WIDTH * 2 + ACTION_BUTTON_GAP + ROW_TEXT_INSET * 2
local SCROLLBAR_WIDTH = 17
local SCROLLBAR_GAP = 2
local SCROLLBAR_RIGHT_INSET = 10
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

local REMOVE_DIALOG_WIDTH = 520
local REMOVE_DIALOG_HEIGHT = 132
local REMOVE_DIALOG_ICON_SIZE = 64
local REMOVE_DIALOG_MESSAGE_MAX_WIDTH = REMOVE_DIALOG_WIDTH - REMOVE_DIALOG_ICON_SIZE * 2
local REMOVE_DIALOG_MESSAGE_PADDING = 8
local REMOVE_DIALOG_MESSAGE_TOP = -24
local REMOVE_DIALOG_MESSAGE_HEIGHT = 34
local REMOVE_DIALOG_BUTTON_WIDTH = GF.PANEL_CONFIRM_BUTTON_W or GF.PANEL_BUTTON_STANDARD_W or 72
local REMOVE_DIALOG_BUTTON_HEIGHT = 26
local REMOVE_DIALOG_BUTTON_GAP = 36
local REMOVE_DIALOG_BUTTON_TOP_GAP = -16
local REMOVE_DIALOG_MAIN_WINDOW_ALPHA = 0.64

local REASON_BADGE_STYLE = {
	ad = { text = { 1, 0.84, 0.42, 1 }, border = { 0.72, 0.45, 0.16, 0.64 }, bg = { 0.12, 0.075, 0.028, 0.78 }, glow = { 0.90, 0.34, 0.04, 0.16 } },
	title_parent = { text = { 1, 0.88, 0.50, 1 }, border = { 0.82, 0.58, 0.18, 0.72 }, bg = { 0.14, 0.09, 0.03, 0.82 }, glow = { 1.00, 0.58, 0.05, 0.18 } },
	same_title_ad = { text = { 1, 0.84, 0.42, 1 }, border = { 0.72, 0.45, 0.16, 0.64 }, bg = { 0.12, 0.075, 0.028, 0.78 }, glow = { 0.90, 0.34, 0.04, 0.16 } },
	manual = { text = { 1, 0.54, 0.42, 1 }, border = { 0.96, 0.18, 0.10, 0.78 }, bg = { 0.20, 0.025, 0.020, 0.84 }, glow = { 1, 0.05, 0.02, 0.26 } },
}
local REASON_SORT_ORDER = {
	ad = 1,
	title_parent = 2,
	same_title_ad = 3,
	manual = 4,
}

local INPUT_BACKGROUND_COLOR = { 0, 0, 0, 0.55 }
local INPUT_BORDER_ATLAS = "common-dropdown-textholder"
local INPUT_BORDER_OFFSET_LEFT = -8
local INPUT_BORDER_OFFSET_TOP = 7
local INPUT_BORDER_OFFSET_RIGHT = 8
local INPUT_BORDER_OFFSET_BOTTOM = -9

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

local function hideFrameRegion(region)
	if not region then
		return
	end
	if region.SetTexture then
		region:SetTexture(nil)
	end
	if region.SetAtlas then
		region:SetAtlas(nil)
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
	if region.Hide then
		region:Hide()
	end
end

local function hideInputBoxChrome(editBox)
	if not editBox then
		return
	end
	local name = editBox.GetName and editBox:GetName()
	if name then
		for _, region in ipairs({
			_G[name .. "Left"],
			_G[name .. "Middle"],
			_G[name .. "Right"],
			_G[name .. "LeftTexture"],
			_G[name .. "MiddleTexture"],
			_G[name .. "RightTexture"],
		}) do
			hideFrameRegion(region)
		end
	end
	hideFrameRegion(editBox.Left)
	hideFrameRegion(editBox.Middle)
	hideFrameRegion(editBox.Right)
	hideFrameRegion(editBox.LeftTexture)
	hideFrameRegion(editBox.MiddleTexture)
	hideFrameRegion(editBox.RightTexture)
end

local function addInputBackground(editBox)
	if not editBox or editBox._gfBlacklistInputBackground then
		return
	end
	local background = editBox:CreateTexture(nil, "BACKGROUND", nil, -2)
	background:SetPoint("TOPLEFT", editBox, "TOPLEFT", 0, -2)
	background:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 0, 2)
	background:SetTexture(WHITE)
	background:SetVertexColor(INPUT_BACKGROUND_COLOR[1], INPUT_BACKGROUND_COLOR[2], INPUT_BACKGROUND_COLOR[3], INPUT_BACKGROUND_COLOR[4])
	local border = editBox:CreateTexture(nil, "BORDER", nil, -1)
	border:SetPoint("TOPLEFT", editBox, "TOPLEFT", INPUT_BORDER_OFFSET_LEFT, INPUT_BORDER_OFFSET_TOP)
	border:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", INPUT_BORDER_OFFSET_RIGHT, INPUT_BORDER_OFFSET_BOTTOM)
	if not (GF.UI and GF.UI.TrySetAtlas and GF.UI.TrySetAtlas(border, INPUT_BORDER_ATLAS, false)) then
		border:SetTexture(WHITE)
		border:SetVertexColor(0.35, 0.35, 0.35, 1)
	end
	editBox._gfBlacklistInputBackground = background
	editBox._gfBlacklistInputBorder = border
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
	hideInputBoxChrome(editBox)
	addInputBackground(editBox)
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

local function setHeaderTextPressed(cell, pressed)
	local text = cell and cell.Text
	if not text then
		return
	end
	cell._pressed = pressed == true
	local offsetX = pressed and HEADER_TEXT_PRESSED_OFFSET_X or 0
	local offsetY = pressed and HEADER_TEXT_PRESSED_OFFSET_Y or 0
	local color = pressed and HEADER_PRESSED_TEXT_COLOR or (cell._hovered and HEADER_HOVER_TEXT_COLOR or HEADER_NORMAL_TEXT_COLOR)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", cell, "TOPLEFT", HEADER_TEXT_INSET_X + offsetX, offsetY)
	text:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -HEADER_TEXT_INSET_X + offsetX, offsetY)
	text:SetTextColor(color[1], color[2], color[3], color[4])
end

local function createHeaderCell(parent, text, sortableKey)
	local frame = CreateFrame(sortableKey and "Button" or "Frame", nil, parent)
	frame:SetHeight(HEADER_HEIGHT)
	frame.Text = createLabel(frame, text, HEADER_TEXT_SIZE, "CENTER")
	frame.Text._gfFontSizeOverride = HEADER_TEXT_SIZE
	frame.Text._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.Track then
		GF.Font.Track(frame.Text, "GameFontHighlight")
	end
	frame.Text:SetJustifyH("CENTER")
	frame.Text:SetJustifyV("MIDDLE")
	setHeaderTextPressed(frame, false)
	if sortableKey then
		frame.sortableKey = sortableKey
		frame:RegisterForClicks("LeftButtonUp")
		frame:SetScript("OnEnter", function(self)
			self._hovered = true
			setHeaderTextPressed(self, self._pressed)
		end)
		frame:SetScript("OnLeave", function(self)
			self._hovered = nil
			setHeaderTextPressed(self, false)
		end)
		frame:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				setHeaderTextPressed(self, true)
			end
		end)
		frame:SetScript("OnMouseUp", function(self)
			setHeaderTextPressed(self, false)
		end)
		frame:SetScript("OnClick", function(self)
			local widgets = parent.widgets
			if not widgets then
				return
			end
			widgets.sortKey = self.sortableKey or BLACKLIST_DEFAULT_SORT_KEY
			widgets.editingRow = nil
			BP:Refresh()
		end)
	end
	return frame
end

local function setHeaderAccentGradient(texture, startAlpha, endAlpha)
	if not texture then
		return
	end
	if texture.SetGradient and CreateColor then
		local ok = pcall(texture.SetGradient, texture, "VERTICAL",
			CreateColor(HEADER_ACCENT_COLOR[1], HEADER_ACCENT_COLOR[2], HEADER_ACCENT_COLOR[3], startAlpha),
			CreateColor(HEADER_ACCENT_COLOR[1], HEADER_ACCENT_COLOR[2], HEADER_ACCENT_COLOR[3], endAlpha))
		if ok then
			return
		end
	end
	if texture.SetGradientAlpha then
		texture:SetGradientAlpha(
			"VERTICAL",
			HEADER_ACCENT_COLOR[1], HEADER_ACCENT_COLOR[2], HEADER_ACCENT_COLOR[3], startAlpha,
			HEADER_ACCENT_COLOR[1], HEADER_ACCENT_COLOR[2], HEADER_ACCENT_COLOR[3], endAlpha
		)
	else
		texture:SetVertexColor(HEADER_ACCENT_COLOR[1], HEADER_ACCENT_COLOR[2], HEADER_ACCENT_COLOR[3], math.max(startAlpha or 0, endAlpha or 0))
	end
end

local function createHeaderAccent(parent)
	local accent = CreateFrame("Frame", nil, parent)
	accent:SetSize(HEADER_ACCENT_WIDTH, HEADER_ACCENT_HEIGHT)
	local top = accent:CreateTexture(nil, "OVERLAY")
	top:SetTexture(WHITE)
	top:SetPoint("TOPLEFT", accent, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", accent, "TOPRIGHT", 0, 0)
	top:SetHeight(HEADER_ACCENT_HEIGHT / 2)
	setHeaderAccentGradient(top, HEADER_ACCENT_ALPHA, 0)
	local bottom = accent:CreateTexture(nil, "OVERLAY")
	bottom:SetTexture(WHITE)
	bottom:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", accent, "BOTTOMRIGHT", 0, 0)
	setHeaderAccentGradient(bottom, 0, HEADER_ACCENT_ALPHA)
	return accent
end

local function getColumnLayout(width)
	width = math.max(1, math.floor(tonumber(width) or 1))
	local player = math.min(math.max(260, math.floor(width * 0.28)), 430)
	local reason = math.min(math.max(112, math.floor(width * 0.11)), 150)
	local updated = math.min(math.max(86, math.floor(width * 0.08)), 116)
	local action = math.min(math.max(ACTION_COLUMN_MIN_WIDTH, math.floor(width * 0.10)), ACTION_COLUMN_MIN_WIDTH + 16)
	local note = width - player - reason - updated - action
	if note < 260 then
		local shortage = 260 - note
		player = math.max(180, player - shortage)
		note = width - player - reason - updated - action
	end
	note = math.max(220, note)
	return {
		player = { x = 0, width = player },
		reason = { x = player, width = reason },
		note = { x = player + reason, width = note },
		updated = { x = player + reason + note, width = updated },
		action = { x = player + reason + note + updated, width = action },
		totalWidth = player + reason + note + updated + action,
	}
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
	local blocklist = GF.Blocklist
	local reason = entry.reason or (blocklist and blocklist:GetEntryReason(entry._row))
	local note = tostring(entry.note or "")
	GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(entry.displayName or entry.name or entry.key or "", 1, 0.82, 0, true)
	addTooltipDoubleLine(T("BLOCKLIST_COL_REASON", "Category"), blocklist and blocklist:GetEntryReasonText(reason) or reason)
	addTooltipDoubleLine(T("BLOCKLIST_SOURCE", "Source"), blocklist and blocklist:GetEntrySourceText(reason) or "")
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

local function configureActionButtonLabel(button)
	local label = button and button:GetFontString()
	if not label then
		return
	end
	label:ClearAllPoints()
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")
	label:SetWordWrap(false)
	label._gfFontSizeOverride = 12
	label._gfFontFlagsOverride = nil
	if GF.Font and GF.Font.Track then
		GF.Font.Track(label, "GameFontNormal")
	else
		setFontSize(label, 12)
	end
	if label.SetDrawLayer then
		label:SetDrawLayer("OVERLAY", 7)
	end
end

local function createActionButton(parent, text)
	local button = GF.UI.CreatePanelButton(parent, text, ACTION_BUTTON_WIDTH)
	button:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
	button:SetText(text or "")
	configureActionButtonLabel(button)
	return button
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

local function createRow(parent)
	local row = CreateFrame("Frame", nil, parent)
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
	return row
end

local function createScrollContainer(parent)
	local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
	scrollFrame:EnableMouseWheel(true)
	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
	content:SetSize(1, 1)
	scrollFrame:SetScrollChild(content)
	local scrollBar = GF.UI.CreateFrameWithTemplateOptions("EventFrame", nil, parent, { "MinimalScrollBar" })
	if not scrollBar or (not scrollBar.SetValue and not scrollBar.SetScrollPercentage) then
		scrollBar = CreateFrame("Slider", nil, parent)
		scrollBar:SetOrientation("VERTICAL")
		scrollBar:SetValueStep(1)
		if scrollBar.SetObeyStepOnDrag then
			scrollBar:SetObeyStepOnDrag(true)
		end
	end
	scrollBar:SetWidth(SCROLLBAR_WIDTH)
	if scrollBar.SetMinMaxValues then
		scrollBar:SetMinMaxValues(0, 0)
	end
	scrollBar:Hide()
	local useNative = scrollBar.Init and ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar
	if useNative then
		ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollBar)
	end
	local isSyncing = false
	local minValue, maxValue = 0, 0
	local function setRange(min, max)
		minValue, maxValue = min or 0, max or 0
		if scrollBar.SetMinMaxValues then
			scrollBar:SetMinMaxValues(minValue, maxValue)
		elseif scrollBar.SetScrollPercentage then
			scrollBar:SetScrollPercentage(0)
		end
	end
	scrollBar._setRange = setRange
	local function getValue()
		if useNative and scrollBar.GetScrollPercentage then
			return (scrollBar:GetScrollPercentage() or 0) * maxValue
		end
		if scrollBar.GetValue then
			return scrollBar:GetValue() or 0
		end
		if scrollBar.GetScrollPercentage then
			return (scrollBar:GetScrollPercentage() or 0) * maxValue
		end
		return 0
	end
	scrollBar._getValue = getValue
	local function setValue(value)
		value = math.min(math.max(value or 0, minValue), maxValue)
		if useNative and scrollBar.SetScrollPercentage then
			scrollBar:SetScrollPercentage(maxValue > 0 and value / maxValue or 0, ScrollBoxConstants and ScrollBoxConstants.NoScrollInterpolation)
		elseif scrollBar.SetValue then
			scrollBar:SetValue(value)
		elseif scrollBar.SetScrollPercentage then
			scrollBar:SetScrollPercentage(maxValue > 0 and value / maxValue or 0)
		end
	end
	scrollBar._setValue = setValue
	local function applyValue(value)
		local nextValue = math.min(math.max(value or 0, minValue), maxValue)
		isSyncing = true
		scrollFrame:SetVerticalScroll(nextValue)
		if math.abs(getValue() - nextValue) > 0.5 then
			setValue(nextValue)
		end
		isSyncing = false
		if scrollFrame._onScroll then
			scrollFrame._onScroll()
		end
	end
	scrollFrame._applyValue = applyValue
	if scrollBar.SetScrollPercentage and scrollBar.RegisterCallback and scrollBar.Event and scrollBar.Event.OnScroll then
		scrollBar:RegisterCallback(scrollBar.Event.OnScroll, function(_, percentage)
			if not isSyncing then
				applyValue((percentage or 0) * maxValue)
			end
		end)
	elseif scrollBar.SetScript and scrollBar.SetValue then
		scrollBar:SetScript("OnValueChanged", function(_, value)
			if not isSyncing then
				applyValue(value or getValue())
			end
		end)
	end
	scrollFrame:SetScript("OnMouseWheel", function(_, delta)
		applyValue(getValue() - (delta or 0) * ROW_HEIGHT)
	end)
	scrollFrame:SetScript("OnSizeChanged", function(self)
		content:SetWidth(math.max((self:GetWidth() or 1), 1))
		if self._onSizeChanged then
			self._onSizeChanged()
		end
	end)
	return scrollFrame, content, scrollBar
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
	local actionCenterX = offsetX + layout.action.x + layout.action.width / 2
	row.EditButton:ClearAllPoints()
	row.RemoveButton:ClearAllPoints()
	row.SaveButton:ClearAllPoints()
	row.CancelButton:ClearAllPoints()
	row.EditButton:SetPoint("RIGHT", row, "LEFT", actionCenterX - ACTION_BUTTON_GAP / 2, 0)
	row.RemoveButton:SetPoint("LEFT", row, "LEFT", actionCenterX + ACTION_BUTTON_GAP / 2, 0)
	row.SaveButton:SetPoint("RIGHT", row, "LEFT", actionCenterX - ACTION_BUTTON_GAP / 2, 0)
	row.CancelButton:SetPoint("LEFT", row, "LEFT", actionCenterX + ACTION_BUTTON_GAP / 2, 0)
end

local function ensureRows(widgets, count)
	widgets.rows = widgets.rows or {}
	for index = #widgets.rows + 1, count do
		widgets.rows[index] = createRow(widgets.content)
	end
end

local function beginRowEdit(widgets, row, entry)
	widgets.editingRow = entry._row
	widgets.editingOriginalNote = entry.note or ""
	widgets.editingDraft = entry.note or ""
	BP:Refresh()
	if row and row.NoteBox and row._entryRow == entry._row then
		row.NoteBox:SetFocus()
		row.NoteBox:HighlightText()
	end
end

local function cancelRowEdit(widgets)
	widgets.editingRow = nil
	widgets.editingOriginalNote = nil
	widgets.editingDraft = nil
	BP:Refresh()
end

local function saveRowEdit(widgets)
	local row = widgets.editingRow
	if not row then
		return
	end
	local nextNote = widgets.editingDraft or ""
	local originalNote = widgets.editingOriginalNote or ""
	widgets.editingRow = nil
	widgets.editingOriginalNote = nil
	widgets.editingDraft = nil
	if nextNote ~= originalNote and GF.Blocklist and GF.Blocklist.SetBlacklistNote then
		GF.Blocklist:SetBlacklistNote(row, nextNote)
	else
		BP:Refresh()
	end
end

local function getRemoveDialogMainWindow(dialog)
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	if mainFrame and mainFrame.SetAlpha then
		return mainFrame
	end
	return nil
end

local function setRemoveDialogMainWindowAlpha(dialog, transparent)
	local mainFrame = getRemoveDialogMainWindow(dialog)
	if not mainFrame then
		return
	end
	if transparent then
		if dialog._previousMainAlpha == nil then
			dialog._previousMainAlpha = mainFrame.GetAlpha and mainFrame:GetAlpha() or 1
		end
		mainFrame:SetAlpha(REMOVE_DIALOG_MAIN_WINDOW_ALPHA)
	elseif dialog._previousMainAlpha ~= nil then
		local previous = tonumber(dialog._previousMainAlpha) or 1
		dialog._previousMainAlpha = nil
		mainFrame:SetAlpha(previous)
	end
end

local function layoutRemoveDialog(dialog)
	local message = dialog.Message
	local icon = dialog.Icon
	local yes = dialog.YesButton
	local no = dialog.NoButton
	local dialogWidth = dialog:GetWidth() or REMOVE_DIALOG_WIDTH
	local textWidth = REMOVE_DIALOG_MESSAGE_MAX_WIDTH
	if message and message.GetStringWidth then
		textWidth = math.ceil(message:GetStringWidth() or 0)
		if textWidth <= 0 then
			textWidth = REMOVE_DIALOG_MESSAGE_MAX_WIDTH
		end
	end
	textWidth = math.min(textWidth, REMOVE_DIALOG_MESSAGE_MAX_WIDTH)
	message:ClearAllPoints()
	message:SetPoint("TOP", dialog, "TOP", 0, REMOVE_DIALOG_MESSAGE_TOP)
	message:SetSize(textWidth + REMOVE_DIALOG_MESSAGE_PADDING * 2, REMOVE_DIALOG_MESSAGE_HEIGHT)
	local leftBorderX = -dialogWidth / 2
	local textLeftX = -textWidth / 2
	local iconCenterX = (leftBorderX + textLeftX) / 2
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", dialog, "CENTER", iconCenterX, 0)
	yes:ClearAllPoints()
	yes:SetPoint("TOP", message, "BOTTOM", -((REMOVE_DIALOG_BUTTON_WIDTH + REMOVE_DIALOG_BUTTON_GAP) / 2), REMOVE_DIALOG_BUTTON_TOP_GAP)
	no:ClearAllPoints()
	no:SetPoint("TOP", message, "BOTTOM", (REMOVE_DIALOG_BUTTON_WIDTH + REMOVE_DIALOG_BUTTON_GAP) / 2, REMOVE_DIALOG_BUTTON_TOP_GAP)
end

local function refreshRemoveDialogLocale(dialog)
	if not dialog then
		return
	end
	if dialog.Message then
		dialog.Message:SetText(T("BLOCKLIST_REMOVE_PLAYER_CONFIRM", "Remove this player from the blacklist?"))
	end
	if dialog.YesButton then
		dialog.YesButton:SetText(T("BLOCKLIST_CONFIRM_YES", "Yes"))
	end
	if dialog.NoButton then
		dialog.NoButton:SetText(T("BLOCKLIST_CONFIRM_NO", "No"))
	end
	layoutRemoveDialog(dialog)
end

local function createRemoveDialog()
	local dialog = CreateFrame("Frame", "GroupFinderAddonBlacklistRemoveDialog", UIParent, "BackdropTemplate")
	dialog:SetSize(REMOVE_DIALOG_WIDTH, REMOVE_DIALOG_HEIGHT)
	dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetFrameLevel(1000)
	dialog:SetToplevel(true)
	dialog:EnableMouse(true)
	dialog:Hide()
	if dialog.SetBackdrop then
		dialog:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
		dialog:SetBackdropColor(0, 0, 0, 0.9)
		dialog:SetBackdropBorderColor(0.82, 0.82, 0.82, 1)
	else
		dialog.Background = dialog:CreateTexture(nil, "BACKGROUND")
		dialog.Background:SetAllPoints(dialog)
		dialog.Background:SetTexture(WHITE)
		dialog.Background:SetVertexColor(0, 0, 0, 0.9)
	end
	dialog.Icon = dialog:CreateTexture(nil, "ARTWORK")
	dialog.Icon:SetSize(REMOVE_DIALOG_ICON_SIZE, REMOVE_DIALOG_ICON_SIZE)
	dialog.Icon:SetTexture(REMOVE_DIALOG_ICON_TEXTURE)
	dialog.Message = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	dialog.Message:SetJustifyH("CENTER")
	dialog.Message:SetJustifyV("MIDDLE")
	dialog.Message:SetTextColor(1, 1, 1, 1)
	dialog.Message:SetWordWrap(false)
	setFontSize(dialog.Message, 20)
	dialog.YesButton = GF.UI.CreatePanelButton(dialog, T("BLOCKLIST_CONFIRM_YES", "Yes"), REMOVE_DIALOG_BUTTON_WIDTH)
	dialog.YesButton:SetSize(REMOVE_DIALOG_BUTTON_WIDTH, REMOVE_DIALOG_BUTTON_HEIGHT)
	dialog.NoButton = GF.UI.CreatePanelButton(dialog, T("BLOCKLIST_CONFIRM_NO", "No"), REMOVE_DIALOG_BUTTON_WIDTH)
	dialog.NoButton:SetSize(REMOVE_DIALOG_BUTTON_WIDTH, REMOVE_DIALOG_BUTTON_HEIGHT)
	dialog.YesButton:SetScript("OnClick", function()
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		local row = dialog.entryRow
		dialog:Hide()
		if row and GF.Blocklist and GF.Blocklist.RemovePlayerFromBlacklist then
			GF.Blocklist:RemovePlayerFromBlacklist(row)
		end
	end)
	dialog.NoButton:SetScript("OnClick", function()
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		dialog:Hide()
	end)
	dialog:SetScript("OnShow", function(self)
		layoutRemoveDialog(self)
		setRemoveDialogMainWindowAlpha(self, true)
		if self.EnableKeyboard then
			self:EnableKeyboard(true)
		end
	end)
	dialog:SetScript("OnHide", function(self)
		setRemoveDialogMainWindowAlpha(self, false)
		self.entryRow = nil
		if self.EnableKeyboard then
			self:EnableKeyboard(false)
		end
	end)
	dialog:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:Hide()
		end
	end)
	return dialog
end

local function showRemoveConfirm(entry)
	if not entry then
		return
	end
	if not BP.removeDialog then
		BP.removeDialog = createRemoveDialog()
	end
	local dialog = BP.removeDialog
	dialog.entryRow = entry._row
	refreshRemoveDialogLocale(dialog)
	dialog:ClearAllPoints()
	dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	dialog:Show()
	if dialog.Raise then
		dialog:Raise()
	end
end

local function refreshRow(widgets, row, entry)
	row._entryRow = entry._row
	local isEditing = widgets.editingRow == entry._row
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
	local blocklist = GF.Blocklist
	local reason = entry.reason or (blocklist and blocklist:GetEntryReason(entry._row)) or "manual"
	row.Reason.Label:SetText(blocklist and blocklist:GetEntryReasonText(reason) or reason)
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
		if (widgets.editingDraft or "") ~= (widgets.editingOriginalNote or "") then
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
		local draft = widgets.editingDraft or note
		if row.NoteBox:GetText() ~= draft then
			row.NoteBox:SetText(draft)
		end
		row.NoteBox:SetScript("OnTextChanged", function(self)
			if widgets.editingRow ~= entry._row then
				return
			end
			widgets.editingDraft = self:GetText() or ""
			setSaveButtonEnabled(row, widgets.editingDraft ~= (widgets.editingOriginalNote or ""))
		end)
		row.NoteBox:SetScript("OnEscapePressed", function()
			cancelRowEdit(widgets)
		end)
		row.NoteBox:SetScript("OnEnterPressed", function()
			if widgets.editingDraft ~= (widgets.editingOriginalNote or "") then
				saveRowEdit(widgets)
			else
				cancelRowEdit(widgets)
			end
		end)
		setSaveButtonEnabled(row, (widgets.editingDraft or "") ~= (widgets.editingOriginalNote or ""))
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

local function compareByUpdated(left, right)
	local leftTime = tonumber(left and (left.updatedAt or left.addedAt)) or 0
	local rightTime = tonumber(right and (right.updatedAt or right.addedAt)) or 0
	if leftTime ~= rightTime then
		return leftTime > rightTime
	end
	return tostring(left and (left.displayName or left.name or left.key) or "") < tostring(right and (right.displayName or right.name or right.key) or "")
end

local function buildEntries(widgets)
	local entries = GF.Blocklist and GF.Blocklist.GetBlacklistEntries and GF.Blocklist:GetBlacklistEntries() or {}
	if widgets.sortKey == BLACKLIST_CATEGORY_SORT_KEY then
		table.sort(entries, function(a, b)
			local aOrder = REASON_SORT_ORDER[a.reason or "manual"] or 999
			local bOrder = REASON_SORT_ORDER[b.reason or "manual"] or 999
			if aOrder ~= bOrder then
				return aOrder < bOrder
			end
			return compareByUpdated(a, b)
		end)
	else
		table.sort(entries, compareByUpdated)
	end
	return entries
end

local function renderVisibleRows(widgets)
	if not widgets or not widgets.scrollFrame or not widgets.content then
		return
	end
	local entries = widgets.entries or {}
	local totalRows = #entries
	local viewportHeight = math.max(widgets.scrollFrame:GetHeight() or ROW_HEIGHT, ROW_HEIGHT)
	local visibleCount = math.min(totalRows, math.max(1, math.ceil(viewportHeight / ROW_HEIGHT) + 2))
	ensureRows(widgets, visibleCount)
	local scrollOffset = widgets.scrollFrame:GetVerticalScroll() or 0
	local firstIndex = math.floor(scrollOffset / ROW_HEIGHT) + 1
	local layout = widgets.columnLayout or getColumnLayout(widgets.scrollFrame:GetWidth() or 1)
	local width = math.max(widgets.scrollFrame:GetWidth() or layout.totalWidth or 1, layout.totalWidth or 1)
	for poolIndex, row in ipairs(widgets.rows or {}) do
		local entryIndex = firstIndex + poolIndex - 1
		local entry = entries[entryIndex]
		if entry and poolIndex <= visibleCount then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", widgets.content, "TOPLEFT", 0, -((entryIndex - 1) * ROW_HEIGHT))
			row:SetPoint("TOPRIGHT", widgets.content, "TOPRIGHT", 0, -((entryIndex - 1) * ROW_HEIGHT))
			layoutRow(row, layout, width)
			refreshRow(widgets, row, entry)
		else
			row:Hide()
		end
	end
end

local function updateScrollState(widgets, totalRows)
	local scrollFrame = widgets.scrollFrame
	local content = widgets.content
	local scrollBar = widgets.scrollBar
	local viewportHeight = math.max(scrollFrame:GetHeight() or 1, 1)
	local contentHeight = math.max(totalRows * ROW_HEIGHT + SCROLL_BOTTOM_INSET, viewportHeight)
	content:SetWidth(math.max(scrollFrame:GetWidth() or 1, 1))
	content:SetHeight(contentHeight)
	local maxScroll = math.max(contentHeight - viewportHeight, 0)
	if scrollBar._setRange then
		scrollBar._setRange(0, maxScroll)
	elseif scrollBar.SetMinMaxValues then
		scrollBar:SetMinMaxValues(0, maxScroll)
	end
	if maxScroll > 0 then
		scrollBar:Show()
	else
		if scrollBar._setValue then
			scrollBar._setValue(0)
		elseif scrollBar.SetValue then
			scrollBar:SetValue(0)
		end
		scrollBar:Hide()
	end
	local current = scrollBar._getValue and scrollBar._getValue() or (scrollBar.GetValue and scrollBar:GetValue()) or 0
	current = math.min(current or 0, maxScroll)
	if scrollBar._setValue then
		scrollBar._setValue(current)
	elseif scrollBar.SetValue then
		scrollBar:SetValue(current)
	end
	scrollFrame:SetVerticalScroll(current)
end

local function applyHeaderLayout(widgets)
	local header = widgets.header
	local width = widgets.scrollFrame and widgets.scrollFrame:GetWidth() or header:GetWidth()
	width = math.max((width or 1) - 12, 1)
	local layout = getColumnLayout(width)
	widgets.columnLayout = layout
	applyColumnFrame(header, layout)
	for _, accent in ipairs(header.accents or {}) do
		accent:Hide()
	end
	header.accents = {}
	for _, x in ipairs({
		layout.player.x + layout.player.width,
		layout.reason.x + layout.reason.width,
		layout.note.x + layout.note.width,
		layout.updated.x + layout.updated.width,
	}) do
		local accent = createHeaderAccent(header)
		accent:SetPoint("CENTER", header, "LEFT", math.floor(x + 0.5), 0)
		accent:Show()
		header.accents[#header.accents + 1] = accent
	end
end

local function addColumnHeader(blockNav, widgets)
	local background = blockNav:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetAllPoints(blockNav)
	if not (GF.UI and GF.UI.TrySetAtlas and GF.UI.TrySetAtlas(background, GF.BROWSE_HEADER_BACKGROUND_ATLAS or "housefinder_header-bg-gradient", false)) then
		background:SetTexture(WHITE)
		background:SetVertexColor(0.12, 0.08, 0.03, 0.92)
	end
	blockNav.HeaderBackground = background
	local header = CreateFrame("Frame", nil, blockNav)
	header:SetPoint("TOPLEFT", background, "TOPLEFT", HEADER_CONTENT_INSET_X, HEADER_CONTENT_OFFSET_Y)
	header:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", -HEADER_CONTENT_INSET_X, HEADER_CONTENT_OFFSET_Y)
	header:SetHeight(HEADER_HEIGHT)
	header:SetFrameLevel(blockNav:GetFrameLevel() + 3)
	header.widgets = widgets
	header.player = createHeaderCell(header, T("BLOCKLIST_COL_PLAYER", "Player"))
	header.reason = createHeaderCell(header, T("BLOCKLIST_COL_REASON", "Category"), BLACKLIST_CATEGORY_SORT_KEY)
	header.note = createHeaderCell(header, T("BLOCKLIST_COL_NOTE", "Note"))
	header.updated = createHeaderCell(header, T("BLOCKLIST_COL_UPDATED", "Updated"), BLACKLIST_DEFAULT_SORT_KEY)
	header.action = createHeaderCell(header, T("BLOCKLIST_COL_ACTION", "Action"))
	return header
end

local function refreshHeaderLocale(widgets)
	local header = widgets and widgets.header
	if not header then
		return
	end
	header.player.Text:SetText(T("BLOCKLIST_COL_PLAYER", "Player"))
	header.reason.Text:SetText(T("BLOCKLIST_COL_REASON", "Category"))
	header.note.Text:SetText(T("BLOCKLIST_COL_NOTE", "Note"))
	header.updated.Text:SetText(T("BLOCKLIST_COL_UPDATED", "Updated"))
	header.action.Text:SetText(T("BLOCKLIST_COL_ACTION", "Action"))
end

function BP:Init(parent)
	if self.blockContent then
		return
	end
	self.parent = parent
	self.blockContent = parent

	local blockNav = CreateFrame("Frame", nil, parent)
	blockNav:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, BLOCK_NAV_TOP_OFFSET)
	blockNav:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, BLOCK_NAV_TOP_OFFSET)
	blockNav:SetHeight(HEADER_HEIGHT)
	blockNav:SetFrameLevel(parent:GetFrameLevel() + 2)

	local blocklist = CreateFrame("Frame", nil, parent)
	blocklist:SetPoint("TOPLEFT", blockNav, "BOTTOMLEFT", 0, -BLOCK_LIST_GAP)
	blocklist:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	blocklist:SetFrameLevel(parent:GetFrameLevel() + 1)

	local widgets = {
		sortKey = BLACKLIST_DEFAULT_SORT_KEY,
		rows = {},
	}
	local header = addColumnHeader(blockNav, widgets)
	local scrollFrame, content, scrollBar = createScrollContainer(blocklist)
	scrollFrame:SetPoint("TOPLEFT", blocklist, "TOPLEFT", 0, 0)
	scrollFrame:SetPoint("BOTTOMRIGHT", blocklist, "BOTTOMRIGHT", -(SCROLLBAR_WIDTH + SCROLLBAR_GAP + SCROLLBAR_RIGHT_INSET), SCROLL_BOTTOM_INSET)
	scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", SCROLLBAR_GAP, -2)
	scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", SCROLLBAR_GAP, 2)
	if scrollFrame.SetClipsChildren then
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
	widgets.content = content
	widgets.scrollBar = scrollBar
	widgets.empty = empty
	scrollFrame._onScroll = function()
		renderVisibleRows(widgets)
	end
	scrollFrame._onSizeChanged = function()
		if BP._frameResizing or not BP.blockContent or not BP.blockContent:IsShown() then
			return
		end
		BP:Refresh()
	end
	self.blockNav = blockNav
	self.blocklist = blocklist
	self.widgets = widgets
	self:Refresh()
end

function BP:Refresh()
	local widgets = self.widgets
	if not widgets or not widgets.content then
		return
	end
	if self.blockContent and not self.blockContent:IsShown() then
		return
	end
	widgets.entries = buildEntries(widgets)
	refreshHeaderLocale(widgets)
	applyHeaderLayout(widgets)
	if widgets.empty then
		widgets.empty:SetText(T("BLOCKLIST_EMPTY", "No blacklist records"))
		widgets.empty:SetShown(#widgets.entries == 0)
	end
	updateScrollState(widgets, #widgets.entries)
	renderVisibleRows(widgets)
end

function BP:RefreshList()
	self:Refresh()
end

function BP:RefreshLocale()
	if self.removeDialog then
		refreshRemoveDialogLocale(self.removeDialog)
	end
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
	local blocklist = GF.Blocklist
	local enabled = blocklist and blocklist:IsEnabled() or false
	local tabs = GF.TabBar
	if tabs and tabs.SetBlocklistTabVisible then
		tabs:SetBlocklistTabVisible(enabled)
	end
end
