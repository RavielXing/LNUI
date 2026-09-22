local _, GF = ...

GF.StarredLeadersPanel = {}
local Panel = GF.StarredLeadersPanel
local UI = GF.UI
local STYLE = GF.STARRED_LEADERS_STYLE
local EDITOR_STYLE = GF.PLAYER_MANAGEMENT_DIALOG_STYLE
local TABLE_STYLE = GF.PLAYER_MANAGEMENT_STYLE
local DIALOG_STYLE = GF.PLAYER_CONTEXT_DIALOG_STYLE
local function label(key) return (GF.L or {})[key] or key end
local function service() return GF.StarredLeaders end

function Panel:CancelClearConfirmation()
	local request = self.clearRequest
	self.clearRequest = nil
	if request and GF.BlacklistConfirmDialog then GF.BlacklistConfirmDialog:Hide(request) end
end

function Panel:CancelRemoveConfirmation()
	local request = self.removeRequest
	self.removeRequest = nil
	if request and GF.BlacklistConfirmDialog then GF.BlacklistConfirmDialog:Hide(request) end
end

function Panel:ConfirmRemove(name)
	local confirmation = GF.BlacklistConfirmDialog
	if not (self.frame and self.frame:IsShown() and confirmation) then return false end
	local record = service():Get(name)
	if not record then return false end
	self:CancelClearConfirmation()
	self:CancelRemoveConfirmation()
	if self.editor then self.editor:Hide() end
	self.searchEdit:ClearFocus()
	-- Capture the target before a refresh or scroll reuses the clicked row.
	local targetName = record.name
	local request = {
		messageKey = "STARRED_REMOVE_CONFIRM",
		messageFallback = "Unstar this leader?",
		iconTexture = GF.STARRED_LEADER_TYPE_ICON_TEXTURE,
	}
	request.onAccept = function()
		if self.removeRequest ~= request or not self.frame:IsShown() then return false end
		if not service():Remove(targetName) then return false end
		self.removeRequest = nil
		return true
	end
	request.onCancel = function()
		if self.removeRequest == request then self.removeRequest = nil end
	end
	self.removeRequest = request
	return confirmation:Show(request)
end

function Panel:ConfirmClear()
	local confirmation = GF.BlacklistConfirmDialog
	if not (self.frame and self.frame:IsShown() and confirmation) then return false end
	self:CancelClearConfirmation()
	self:CancelRemoveConfirmation()
	if self.editor then self.editor:Hide() end
	self.searchEdit:ClearFocus()
	local request = {
		messageKey = "STARRED_CLEAR_CONFIRM",
		messageFallback = "Clear starred leaders?",
		iconTexture = GF.STARRED_LEADER_TYPE_ICON_TEXTURE,
	}
	request.onAccept = function()
		if self.clearRequest ~= request or not self.frame:IsShown() then return false end
		if not service():Clear() then return false end
		self.clearRequest = nil
		self.searchEdit:SetText("")
		self:Refresh(true)
		return true
	end
	request.onCancel = function()
		if self.clearRequest == request then self.clearRequest = nil end
	end
	self.clearRequest = request
	return confirmation:Show(request)
end

function Panel:ReleaseEditorFocus()
	local main = self.editorMainFrame
	local alpha = self.editorMainAlpha
	self.editorMainFrame, self.editorMainAlpha = nil, nil
	if main and alpha then main:SetAlpha(alpha) end
end

function Panel:ActivateEditorFocus()
	local main = GF.MainFrame and GF.MainFrame.frame
	if main and main:IsShown() and (not GF.MainFrame.CanApplyPresentationAlpha
		or GF.MainFrame:CanApplyPresentationAlpha()) then
		if not self.editorMainFrame then
			self.editorMainFrame, self.editorMainAlpha = main, main:GetAlpha()
		end
		main:SetAlpha(math.min(self.editorMainAlpha, EDITOR_STYLE.mainAlpha))
	end
	UI.ApplySatelliteFrameLayers()
	UI.RaiseFrame(self.editor)
end

function Panel:ActivateMainFrame()
	if not (self.editor and self.editor:IsShown()) then return false end
	self.editor:Hide()
	local main = GF.MainFrame and GF.MainFrame.frame
	if main and main:IsShown() then UI.RaiseFrame(main) end
	return true
end

local function regionBelongsToFrame(region, target)
	if not target then return false end
	for _ = 1, 100 do
		if GF.Compat and not GF.Compat.IsAccessibleValue(region) then return false end
		if not region then return false end
		if region.CanBeAccessedInContext and not region:CanBeAccessedInContext() then return false end
		if region.IsForbidden and region:IsForbidden() then return false end
		if region == target then return true end
		if not region.GetParent then return false end
		local ok, parent = pcall(region.GetParent, region)
		if not ok then return false end
		region = parent
	end
	return false
end

local function editorMouseDown()
	if type(GetMouseFoci) ~= "function" then return end
	local ok, foci = pcall(GetMouseFoci)
	if not ok or type(foci) ~= "table"
		or (GF.Compat and not GF.Compat.IsAccessibleTable(foci)) then return end
	local focus = foci[1]
	-- The add button owns its toggle on mouse-up; closing here would reopen it.
	if regionBelongsToFrame(focus, Panel.add) then return end
	if regionBelongsToFrame(focus, Panel.editor) then
		Panel:ActivateEditorFocus()
	elseif regionBelongsToFrame(focus, GF.MainFrame and GF.MainFrame.frame) then
		if GF.MainFrame.ActivateFocus then GF.MainFrame:ActivateFocus()
		else Panel:ActivateMainFrame() end
	end
end

local function fitEditorText(text, width)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(text, width, EDITOR_STYLE.minFontSize)
	end
end

local function editorContentWidth()
	return EDITOR_STYLE.width - EDITOR_STYLE.contentInset * 2
end

local function editorTitle(fixedName)
	return fixedName and service():DisplayText(fixedName) or label("STARRED_DIALOG_MANUAL_TEXT")
end

local function layoutEditor(dialog)
	UI.LayoutPlayerManagementDialog(dialog, nil, {
		{ label = dialog.nameLabel, input = dialog.nameShell, shown = dialog.fixedName == nil },
		{ label = dialog.contactLabel, input = dialog.contactShell },
		{ label = dialog.noteLabel, input = dialog.noteShell, height = EDITOR_STYLE.noteHeight },
	}, dialog.errorText, EDITOR_STYLE)
end

function Panel:RefreshEditor()
	local dialog = self.editor
	if not dialog then return end
	UI.SetPlayerManagementDialogTitle(dialog, editorTitle(dialog.fixedName))
	dialog.nameLabel:SetText(label("STARRED_NAME"))
	dialog.namePlaceholder:SetText(label("STARRED_NAME_INPUT_HINT"))
	dialog.contactLabel:SetText(label("STARRED_COL_CONTACT"))
	dialog.contactPlaceholder:SetText(label("STARRED_CONTACT_INPUT_HINT"))
	dialog.noteLabel:SetText(label("STARRED_NOTE"))
	dialog.notePlaceholder:SetText(label("STARRED_INPUT_HINT"))
	local inputWidth = editorContentWidth()
	for _, field in ipairs({ "name", "contact", "note" }) do
		dialog[field .. "Placeholder"]:SetShown(dialog[field .. "Edit"]:GetText() == "")
		local inset = field == "note" and EDITOR_STYLE.noteTextInset or EDITOR_STYLE.inputTextInset
		fitEditorText(dialog[field .. "Placeholder"], inputWidth - inset * 2)
		fitEditorText(dialog[field .. "Label"], inputWidth)
	end
	dialog.save:SetText(label("STARRED_SAVE"))
	dialog.cancel:SetText(label("CANCEL"))
	dialog.errorText:SetText(dialog.errorKey and label(dialog.errorKey) or "")
	for _, button in ipairs({ dialog.save, dialog.cancel }) do
		UI.RefreshPlayerManagementDialogButton(button)
	end
	layoutEditor(dialog)
end

function Panel:EnsureEditor()
	if self.editor then return self.editor end
	local dialog = UI.CreateSatelliteSettingsFrame({
		name = "GroupFinderAddonStarredLeaderDialog",
		width = EDITOR_STYLE.width, height = DIALOG_STYLE.HEIGHT,
		title = label("TAB_STARRED_LEADERS"),
		levelOffset = DIALOG_STYLE.LEVEL_OFFSET,
		backgroundColor = EDITOR_STYLE.backgroundColor,
	})
	self.editor = dialog
	dialog:HookScript("OnShow", function() dialog:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
	dialog:HookScript("OnEvent", function(_, event)
		if event == "GLOBAL_MOUSE_DOWN" and dialog:IsShown() then editorMouseDown() end
	end)
	dialog.contentHost = UI.CreatePlayerContextDialogContentHost(dialog)
	for _, spec in ipairs({ { "name", 100 }, { "contact", 512 }, { "note", 200 } }) do
		local field, maxLetters = spec[1], spec[2]
		local text, shell, edit, placeholder = UI.CreatePlayerManagementDialogField(
			dialog, maxLetters, field == "note")
		dialog[field .. "Label"], dialog[field .. "Shell"], dialog[field .. "Edit"] = text, shell, edit
		dialog[field .. "Placeholder"] = placeholder
	end
	dialog.errorText = UI.CreateFontString(dialog, "OVERLAY", "GameFontHighlightSmall")
	UI.ApplyPlayerContextDialogTextStyle(dialog.errorText, "secondary")
	dialog.errorText:SetWordWrap(true)
	dialog.errorText:SetMaxLines(0)
	dialog.errorText:SetWidth(editorContentWidth())
	dialog.errorText:SetJustifyH("LEFT")
	dialog.errorText:SetTextColor(1, 0.2, 0.2)
	dialog.actionBar, dialog.save, dialog.cancel = UI.CreatePlayerManagementDialogActions(
		dialog, label("STARRED_SAVE"), label("CANCEL"))
	dialog.cancel:SetScript("OnClick", function() dialog:Hide() end)
	local function save()
		local contact = dialog.contactEdit:GetText()
		if not dialog.classFilename and dialog.sourceResultID then
			dialog.classFilename = service():GetListingClass(dialog.fixedName, dialog.sourceResultID)
		end
		local ok, reason = service():Save(dialog.fixedName or dialog.nameEdit:GetText(),
			dialog.noteEdit:GetText(), contact, contact ~= dialog.initialContact, dialog.classFilename)
		if ok then dialog:Hide() else dialog.errorKey = reason; self:RefreshEditor() end
	end
	dialog.save:SetScript("OnClick", save)
	local function composing(edit)
		return edit.IsInIMECompositionMode and edit:IsInIMECompositionMode()
	end
	dialog.nameEdit:SetScript("OnEnterPressed", function(edit)
		if not composing(edit) then dialog.contactEdit:SetFocus() end
	end)
	dialog.contactEdit:SetScript("OnEnterPressed", function(edit)
		if not composing(edit) then dialog.noteEdit:SetFocus() end
	end)
	dialog.noteEdit:SetScript("OnEnterPressed", function(edit)
		if not composing(edit) then save() end
	end)
	for index, field in ipairs({ "name", "contact", "note" }) do
		local edit = dialog[field .. "Edit"]
		edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
		edit:SetScript("OnTabPressed", function()
			local edits = { dialog.nameEdit, dialog.contactEdit, dialog.noteEdit }
			local first = dialog.fixedName and 2 or 1
			local nextIndex = index + (IsShiftKeyDown() and -1 or 1)
			if nextIndex < first then nextIndex = #edits elseif nextIndex > #edits then nextIndex = first end
			edit:ClearFocus()
			edits[nextIndex]:SetFocus()
		end)
		edit:HookScript("OnTextChanged", function()
			dialog[field .. "Placeholder"]:SetShown(edit:GetText() == "")
			if dialog.errorKey then dialog.errorKey = nil; self:RefreshEditor() end
		end)
	end
	dialog:HookScript("OnHide", function()
		dialog:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		self:ReleaseEditorFocus()
		dialog.errorKey = nil
		dialog.initialContact = nil
		dialog.classFilename = nil
		dialog.sourceResultID = nil
		for _, field in ipairs({ "name", "contact", "note" }) do
			dialog[field .. "Edit"]:ClearFocus()
			dialog[field .. "Edit"]:SetText("")
		end
	end)
	return dialog
end

function Panel:OpenEditor(name, classFilename, sourceResultID)
	local fullName
	if name ~= nil then
		local key
		key, fullName = service():Identity(name)
		if not key then return false end
	end
	self:CancelClearConfirmation()
	self:CancelRemoveConfirmation()
	local record = fullName and service():Get(fullName)
	local dialog = self:EnsureEditor()
	if GF.MainFrame and GF.MainFrame.ActivateFocus then GF.MainFrame:ActivateFocus() end
	UI.PresentSatelliteFrame(dialog, {
		title = editorTitle(fullName),
		centerOnUIParent = true,
		offsetY = DIALOG_STYLE.SCREEN_OFFSET_Y,
		prepare = function()
			dialog.fixedName = fullName
			dialog.classFilename = fullName and classFilename or nil
			dialog.sourceResultID = fullName and sourceResultID or nil
			dialog.initialContact = (record and record.contactInfo) or ""
			dialog.errorKey = nil
			dialog.nameEdit:SetText(fullName or "")
			dialog.nameEdit:SetEnabled(fullName == nil)
			dialog.contactEdit:SetText(dialog.initialContact)
			dialog.noteEdit:SetText(record and record.note or "")
			self:RefreshEditor()
		end,
		onShown = function()
			self:ActivateEditorFocus()
			if fullName then dialog.noteEdit:SetFocus() else dialog.nameEdit:SetFocus() end
		end,
	})
	return true
end

local COLUMN_IDS = { "player", "contact", "status", "whisper", "note", "updated", "action" }
local COLUMN_LABELS = {
	player = "STARRED_NAME", note = "BLOCKLIST_COL_NOTE",
	contact = "STARRED_COL_CONTACT",
	status = "STARRED_COL_STATUS", whisper = "STARRED_COL_WHISPER",
	updated = "BLOCKLIST_COL_UPDATED", action = "BLOCKLIST_COL_ACTION",
}

local function formatDate(timestamp, full)
	if type(timestamp) == "number" and timestamp > 0 and timestamp < math.huge
		and type(date) == "function" then
		return date(full and "%Y-%m-%d %H:%M" or "%m-%d", timestamp)
	end
	return "—"
end

local function resolveColumns(width)
	-- Use the blacklist content origin for headers, dividers, and row cells.
	local columns = GF.ColumnLayoutModel:ResolveStarredLeadersLayout(width - TABLE_STYLE.layoutWidthInset)
	local layout = { active = COLUMN_IDS, byId = {}, headerLayout = {} }
	local x = GF.TABLE_HEADER_STYLE.contentInsetX
	for index, key in ipairs(COLUMN_IDS) do
		local columnWidth = columns[key].width
		layout.byId[key] = { x = x, width = columnWidth }
		layout.headerLayout[index] = { width = columnWidth }
		x = x + columnWidth
	end
	return layout
end

local layoutActionButtons = UI.LayoutPlayerManagementActions

local function layoutRow(row)
	local layout = Panel.columnLayout
	if not layout then return end
	for key, text in pairs({ player = row.nameText, contact = row.contactText, note = row.noteText,
		updated = row.updatedText }) do
		local column = layout.byId[key]
		local prefixWidth = key == "player"
			and GF.STARRED_LEADER_ICON_SIZE + STYLE.classIconSize + GF.STARRED_LEADER_ICON_GAP * 2 or 0
		text:ClearAllPoints()
		text:SetPoint("LEFT", row, "LEFT", column.x + STYLE.textInset + prefixWidth, 0)
		text:SetSize(math.max(1, column.width - STYLE.textInset * 2 - prefixWidth), STYLE.rowHeight)
	end
	row.starIcon:ClearAllPoints()
	row.starIcon:SetPoint("LEFT", row, "LEFT", layout.byId.player.x + STYLE.textInset, 0)
	row.classIcon:ClearAllPoints()
	row.classIcon:SetPoint("CENTER", row.starIcon, "RIGHT", GF.STARRED_LEADER_ICON_GAP + STYLE.classIconSize / 2, 0)
	local status = layout.byId.status
	row.statusHolder:ClearAllPoints()
	row.statusHolder:SetPoint("CENTER", row, "LEFT", status.x + status.width / 2, 0)
	local whisper = layout.byId.whisper
	row.whisperHolder:ClearAllPoints()
	row.whisperHolder:SetPoint("CENTER", row, "LEFT", whisper.x + whisper.width / 2, 0)
	layoutActionButtons(row, row.edit, row.remove, layout.byId.action)
end

local function setRowHover(row, shown)
	UI.SetRowBackgroundPiecesShown(row.hoverPieces, shown)
end

local function applyRowBackground(row)
	UI.ApplyRowBackgroundPieces(row, row.backgroundPieces, {
		state = "starred", mode = "full", defaultHeight = STYLE.rowHeight,
		alpha = GF.GetListBackgroundAlpha("starred"),
	})
	UI.ApplyRowBackgroundPieces(row, row.hoverPieces, {
		state = "starred", mode = "full", defaultHeight = STYLE.rowHeight,
		alpha = GF.BROWSE_ROW_SELECTED_ALPHA or 1, desaturated = true,
		vertexColor = GF.GetListBackgroundOverlayColor("starred", "hover"),
	})
	setRowHover(row, false)
end

local function showRowTooltip(row)
	local entry = row.entry
	if not entry then return end
	UI.BeginGameTooltip(row, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(service():DisplayText(entry.name), 1, 0.82, 0)
	local status = entry.presence or "unknown"
	local color = status == "unknown" and STYLE.offlineColor or STYLE[status .. "Color"]
	GameTooltip:AddDoubleLine(label("STARRED_COL_ONLINE"), label("STARRED_STATUS_" .. status:upper()),
		1, 0.82, 0, color[1], color[2], color[3])
	local contactColor = entry.contactInfo and STYLE.contactColor or STYLE.offlineColor
	GameTooltip:AddDoubleLine(label("STARRED_COL_CONTACT"),
		entry.contactInfo and service():DisplayText(entry.contactInfo) or label("STARRED_NO_CONTACT"),
		1, 0.82, 0, contactColor[1], contactColor[2], contactColor[3])
	local updatedColor = STYLE.updatedColor
	GameTooltip:AddDoubleLine(label("BLOCKLIST_COL_UPDATED"), formatDate(entry.updatedAt, true),
		1, 0.82, 0, updatedColor[1], updatedColor[2], updatedColor[3])
	GameTooltip:AddLine(" ")
	local noteColor = entry.note ~= "" and STYLE.noteTooltipColor or STYLE.offlineColor
	GameTooltip:AddLine(entry.note ~= "" and service():DisplayText(entry.note) or label("STARRED_NO_NOTE"),
		noteColor[1], noteColor[2], noteColor[3], true)
	UI.ShowGameTooltip()
end

local function showWhisperTooltip(row)
	if not row.entry then return end
	UI.BeginGameTooltip(row.whisper, "ANCHOR_TOP")
	GameTooltip:SetText(label(row.entry.canWhisper
		and (row.entry.presence == "unknown" and "STARRED_WHISPER_TRY" or "STARRED_WHISPER_AVAILABLE")
		or "STARRED_WHISPER_UNREACHABLE"))
	UI.ShowGameTooltip()
end

local function showStatusTooltip(row)
	if not row.entry then return end
	local status = row.entry.presence or "unknown"
	UI.BeginGameTooltip(row.statusHolder, "ANCHOR_TOP")
	GameTooltip:SetText(label(status == "unknown" and "STARRED_ADD_FRIEND"
		or "STARRED_STATUS_" .. status:upper()))
	if status == "unknown" then
		GameTooltip:AddLine(label("STARRED_STATUS_UNKNOWN_HINT"), 1, 1, 1, true)
	end
	UI.ShowGameTooltip()
end

local function stopActionFeedback(row)
	row.statusPressFeedback:Reset()
	row.whisperPressFeedback:Reset()
end

local function resetRowTransitions(row)
	stopActionFeedback(row)
	row.statusTransition:Reset()
	row.whisperTransition:Reset()
end

local function renderRow(row, entry)
	if not row.nameText then
		row.backgroundPieces = UI.CreateRowBackgroundPieces(row, "BACKGROUND", -1)
		row.hoverPieces = UI.CreateRowBackgroundPieces(row, "BORDER", 3)
		for _, piece in pairs(row.hoverPieces) do piece:SetBlendMode("ADD") end
		row.starIcon = row:CreateTexture(nil, "OVERLAY")
		row.starIcon:SetSize(GF.STARRED_LEADER_ICON_SIZE, GF.STARRED_LEADER_ICON_SIZE)
		UI.TrySetAtlas(row.starIcon, GF.STARRED_LEADER_ICON_ATLAS)
		row.classIcon = row:CreateTexture(nil, "OVERLAY")
		row.nameText = UI.CreateFontString(row, "OVERLAY", "GameFontNormal")
		row.contactText = UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
		row.noteText = UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
		row.statusHolder = CreateFrame("Button", nil, row)
		row.statusHolder:SetSize(STYLE.statusHitSize, STYLE.statusHitSize)
		row.statusHolder:EnableMouse(true)
		row.statusHolder:RegisterForClicks("LeftButtonUp")
		row.statusHolder:SetMotionScriptsWhileDisabled(true)
		row.statusIcon = row.statusHolder:CreateTexture(nil, "OVERLAY", nil, 2)
		row.statusIcon:SetSize(STYLE.statusIconSize, STYLE.statusIconSize)
		row.statusIcon:SetPoint("CENTER", row.statusHolder, "CENTER", 0, 0)
		row.statusIcon:SetVertexColor(1, 1, 1, 1)
		row.statusTransition = UI.CreateAtlasTransition(row.statusIcon, STYLE.stateTransitionDuration)
		row.updatedText = UI.CreateFontString(row, "OVERLAY", "GameFontDisableSmall")
		row.remove = UI.CreatePlayerManagementButton(row, label("BLOCKLIST_REMOVE"))
		row.edit = UI.CreatePlayerManagementButton(row, label("BLOCKLIST_EDIT"))
		row.whisperHolder, row.whisper = UI.CreateApplicantWhisperButton(row, true,
			STYLE.whisperAtlas, STYLE.whisperDisabledAtlas, false)
		row.whisperTransition = UI.EnableApplicantActionAtlasTransition(row.whisper,
			STYLE.whisperTransitionDuration, STYLE.whisperBlendOverlap)
		row.whisper:RegisterForClicks("LeftButtonUp")
		for _, text in ipairs({ row.nameText, row.contactText, row.noteText, row.updatedText }) do
			text:SetJustifyH("LEFT")
			text:SetJustifyV("MIDDLE")
			text:SetWordWrap(false)
			text:SetMaxLines(1)
		end
		row.updatedText:SetJustifyH("CENTER")
		row.contactText:SetJustifyH("CENTER")
		row.updatedText:SetTextColor(unpack(STYLE.updatedColor))
		for _, button in ipairs({ row.edit, row.remove, row.whisper }) do
			button:HookScript("OnEnter", function() setRowHover(row, true) end)
			button:HookScript("OnLeave", function() setRowHover(row, false) end)
		end
		row.whisper:HookScript("OnEnter", function() showWhisperTooltip(row) end)
		row.whisper:HookScript("OnLeave", function() GameTooltip_Hide() end)
		row.statusHolder:SetScript("OnEnter", function()
			setRowHover(row, true)
			showStatusTooltip(row)
		end)
		row.statusHolder:SetScript("OnLeave", function()
			setRowHover(row, false)
			GameTooltip_Hide()
		end)
		row.statusPressFeedback = UI.BindIconPressFeedback(row.statusHolder, row.statusIcon, STYLE.actionPressMotion)
		row.whisperPressFeedback = UI.BindIconPressFeedback(row.whisper, row.whisper.icon, STYLE.actionPressMotion)
		row.statusHolder:SetScript("OnClick", function(_, mouseButton)
			local entry = row.entry
			if mouseButton ~= "LeftButton" or not entry or entry.presence ~= "unknown" then return end
			local requested = service():AddFriend(entry.name)
			Panel:Refresh()
			if requested then UI.PlayUISound("check") end
		end)
		row.edit:SetScript("OnClick", function()
			GameTooltip_Hide()
			if row.entry then Panel:OpenEditor(row.entry.name) end
		end)
		row.remove:SetScript("OnClick", function()
			GameTooltip_Hide()
			if row.entry then Panel:ConfirmRemove(row.entry.name) end
		end)
		row.whisper:SetScript("OnClick", function(_, mouseButton)
			if mouseButton ~= "LeftButton" then return end
			GameTooltip_Hide()
			local entry = row.entry
			local opened = entry and service():OpenWhisper(entry.name)
			Panel:Refresh()
			if opened then UI.PlayUISound("check") end
		end)
		row:EnableMouse(true)
		row:SetScript("OnEnter", function()
			setRowHover(row, true)
			showRowTooltip(row)
		end)
		row:SetScript("OnLeave", function()
			setRowHover(row, false)
			GameTooltip_Hide()
		end)
		row:HookScript("OnHide", function()
			setRowHover(row, false)
			resetRowTransitions(row)
			if GameTooltip and (GameTooltip:IsOwned(row) or GameTooltip:IsOwned(row.whisper)
				or GameTooltip:IsOwned(row.statusHolder)) then GameTooltip_Hide() end
			row.entry = nil
			row.statusHolder:SetEnabled(false)
			row.whisper:SetEnabled(false)
		end)
	end
	if not row.entry or row.entry.key ~= entry.key then
		resetRowTransitions(row)
	elseif row.displayedPresence ~= entry.presence or row.displayedCanWhisper ~= entry.canWhisper then
		stopActionFeedback(row)
	end
	row.entry = entry
	-- Retained native elements are updated in place before reinitialization.
	-- Compare the last rendered values, not the already refreshed data table.
	row.displayedPresence, row.displayedCanWhisper = entry.presence, entry.canWhisper
	local classIcon = UI.ResolveClassIcon(entry.classFilename)
	local hasClassIcon = classIcon and classIcon.texCoords ~= nil
	local iconOptions = { size = STYLE.classIconSize, iconInset = STYLE.classIconInset }
	if not hasClassIcon then
		classIcon = { texture = STYLE.unknownClassTexture, texCoords = STYLE.unknownClassTexCoords }
		iconOptions.size = STYLE.unknownClassIconSize
		iconOptions.iconInset = 0
		iconOptions.outerSize = STYLE.classIconSize
		iconOptions.separator = true
		iconOptions.separatorSize = STYLE.classIconSize - STYLE.classIconInset
		iconOptions.separatorR, iconOptions.separatorG, iconOptions.separatorB = 0, 0, 0
		iconOptions.separatorAlpha = 1
	end
	UI.SetSpecializationIcon(row.classIcon, classIcon, iconOptions)
	row.nameText:SetText(service():DisplayText(entry.name))
	row.contactText:SetText(entry.contactInfo and service():DisplayText(entry.contactInfo) or label("STARRED_NO_CONTACT"))
	local contactColor = entry.contactInfo and STYLE.contactColor or STYLE.emptyTextColor
	row.contactText:SetTextColor(contactColor[1], contactColor[2], contactColor[3], contactColor[4])
	row.noteText:SetText(entry.note ~= "" and service():DisplayText(entry.note) or label("STARRED_NO_NOTE"))
	if entry.note ~= "" then row.noteText:SetTextColor(1, 0.94, 0.82, 1)
	else
		local color = STYLE.emptyTextColor
		row.noteText:SetTextColor(color[1], color[2], color[3], color[4])
	end
	row.updatedText:SetText(formatDate(entry.updatedAt))
	local status = entry.presence or "unknown"
	row.statusTransition:Set(STYLE.statusAtlases[status], 1)
	row.statusHolder:SetEnabled(status == "unknown")
	row.whisper:SetEnabled(entry.canWhisper == true)
	row.whisper:RefreshApplicantActionState()
	row.edit:SetText(label("BLOCKLIST_EDIT"))
	row.remove:SetText(label("BLOCKLIST_REMOVE"))
	applyRowBackground(row)
	layoutRow(row)
	if GameTooltip and GameTooltip:IsOwned(row) then showRowTooltip(row) end
	if GameTooltip and GameTooltip:IsOwned(row.whisper) then showWhisperTooltip(row) end
	if GameTooltip and GameTooltip:IsOwned(row.statusHolder) then showStatusTooltip(row) end
end

local function layoutFooter(layout)
	Panel.footer:Layout(layout.byId.action)
end

function Panel:Layout()
	if not self.list then return end
	GF.ColumnHeaderBar:Layout(self.header, self.list:GetLayoutWidth())
end

function Panel:Init(parent)
	if self.frame then return end
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:Hide()
	self.frame = frame
	self.footer = UI.CreatePlayerManagementFooter(frame)
	self.add, self.clear = self.footer.primaryButton, self.footer.secondaryButton
	self.searchEdit = self.footer.searchEdit
	self.searchPlaceholder = self.searchEdit.Instructions
	self.footerInfo, self.heading, self.hint = self.footer.info, self.footer.heading, self.footer.hint
	self.add:SetScript("OnClick", function()
		if not Panel:ActivateMainFrame() then Panel:OpenEditor() end
	end)
	self.clear:SetScript("OnClick", function() Panel:ConfirmClear() end)
	self.searchEdit:HookScript("OnTextChanged", function() Panel:Refresh() end)
	self.headerHost = CreateFrame("Frame", nil, frame)
	self.headerHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, GF.TABLE_HEADER_STYLE.topOffset)
	self.headerHost:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, GF.TABLE_HEADER_STYLE.topOffset)
	self.headerHost:SetHeight(GF.TABLE_HEADER_STYLE.height)
	UI.InstallBrowseHeaderChrome(self.headerHost, { backgroundInsetLeft = 0 })
	self.header = GF.ColumnHeaderBar:Create(self.headerHost, {
		mode = "custom", profile = "starred_leaders",
		contentHeight = GF.TABLE_HEADER_STYLE.height,
		resolveLayout = resolveColumns,
		getHeaderLabel = function(key) return label(COLUMN_LABELS[key]) end,
		isSortable = function(key) return key == "updated" or key == "status" end,
		onColumnClick = function(key)
			if key == "status" then
				Panel.statusSortDirection = Panel.statusSortDirection == "asc" and "desc" or "asc"
				Panel.updatedSortDirection = nil
			else
				Panel.updatedSortDirection = Panel.updatedSortDirection == "desc" and "asc" or "desc"
				Panel.statusSortDirection = nil
			end
		end,
		onSort = function() Panel:Refresh(true) end,
		getSortState = function()
			-- Update-time sorting remains interactive without a direction arrow.
			if Panel.statusSortDirection then
				return { column = "status", asc = Panel.statusSortDirection == "asc" }
			end
		end,
		alignColumns = true,
		onLayoutResolved = function(layout)
			Panel.columnLayout = layout
			layoutFooter(layout)
			if Panel.list then Panel.list:ForEachFrame(layoutRow) end
		end,
	})
	self.header:SetHeight(GF.TABLE_HEADER_STYLE.height)
	self.header:SetPoint("LEFT", self.headerHost, "LEFT", 0, GF.TABLE_HEADER_STYLE.contentOffsetY)
	self.header:SetPoint("RIGHT", self.headerHost, "RIGHT", 0, GF.TABLE_HEADER_STYLE.contentOffsetY)
	self.list = UI.VirtualList.Create(frame, {
		rowHeight = STYLE.rowHeight, assignedKey = "key", elementInitializer = renderRow,
		smoothWheel = true,
		barOffsetX = 2, keepNativeScrollBar = true,
	})
	self.list:SetPoint("TOPLEFT", self.headerHost, "BOTTOMLEFT", 0, -GF.TABLE_HEADER_STYLE.listGap)
	self.list:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", 0, GF.TABLE_HEADER_STYLE.listGap)
	self.empty = UI.CreateFontString(frame, "OVERLAY", "GameFontDisable")
	self.empty:SetPoint("CENTER", self.list:GetScrollBox(), "CENTER")
	self.empty:SetPoint("LEFT", self.list:GetScrollBox(), "LEFT", STYLE.textInset, 0)
	self.empty:SetPoint("RIGHT", self.list:GetScrollBox(), "RIGHT", -STYLE.textInset, 0)
	self.empty:SetJustifyH("CENTER")
	self.empty:SetWordWrap(true)
	UI.ApplyEmptyPromptFont(self.empty, "GameFontDisable")
	self.list:GetScrollBox():HookScript("OnSizeChanged", function()
		GF.ColumnHeaderBar:Layout(self.header, self.list:GetLayoutWidth())
	end)
	frame:HookScript("OnSizeChanged", function() Panel:Layout() end)
	local scrollBar = self.list:GetScrollBar()
	if scrollBar then
		scrollBar:SetWidth(TABLE_STYLE.scrollBarWidth)
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPRIGHT", self.headerHost, "BOTTOMRIGHT", -TABLE_STYLE.scrollBarRightInset, -GF.TABLE_HEADER_STYLE.listGap)
		scrollBar:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", -TABLE_STYLE.scrollBarRightInset, GF.TABLE_HEADER_STYLE.listGap)
	end
	self.list:BindDynamicScrollBar({
		gutter = TABLE_STYLE.scrollBarGutter,
		duration = TABLE_STYLE.scrollBarDuration,
		overflowEpsilon = TABLE_STYLE.scrollBarOverflowEpsilon,
		onInsetChanged = function(inset)
			self.list:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", -inset, GF.TABLE_HEADER_STYLE.listGap)
			self.header:SetPoint("RIGHT", self.headerHost, "RIGHT", -inset, GF.TABLE_HEADER_STYLE.contentOffsetY)
		end,
	})
	local presenceEvents = {
		"FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_LIST_SIZE_CHANGED",
		"BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_CONNECTED", "BN_DISCONNECTED",
		"PLAYER_ENTERING_WORLD",
	}
	frame:HookScript("OnShow", function()
		for _, event in ipairs(presenceEvents) do frame:RegisterEvent(event) end
		if C_FriendList and type(C_FriendList.ShowFriends) == "function" then pcall(C_FriendList.ShowFriends) end
		Panel:Refresh()
	end)
	frame:HookScript("OnEvent", function() Panel:Refresh() end)
	frame:HookScript("OnHide", function()
		for _, event in ipairs(presenceEvents) do frame:UnregisterEvent(event) end
		Panel.list:ForEachFrame(resetRowTransitions)
		GameTooltip_Hide()
		Panel:CancelClearConfirmation()
		Panel:CancelRemoveConfirmation()
		Panel.searchEdit:ClearFocus()
		if Panel.editor then Panel.editor:Hide() end
	end)
end

function Panel:Refresh(resetScroll)
	if self.editor and self.editor:IsShown() then self:RefreshEditor() end
	if not self.frame or not self.frame:IsShown() then return end
	local query = self.searchEdit:GetText()
	local entries = service():List(query, self.updatedSortDirection)
	local presence, classes, whispers = service():GetPresenceSnapshot()
	for _, entry in ipairs(entries) do
		entry.presence = service():GetPresence(entry.name, presence)
		entry.canWhisper = service():GetWhisperRoute(entry.name, whispers, presence) ~= nil
		entry.classFilename = entry.classFilename or service():GetFriendClass(entry.name, classes)
	end
	if not self.statusSortDirection and not self.updatedSortDirection then
		entries = service():PrioritizeAvailable(entries)
	else
		service():SortByPresence(entries, self.statusSortDirection)
	end
	local total = query == "" and #entries or #service():List()
	self.heading:SetText(string.format(label("STARRED_TITLE_FMT"), total))
	self.hint:SetText(label("STARRED_HINT"))
	self.add:SetText(label("STARRED_MANUAL_ADD"))
	self.clear:SetText(label("STARRED_CLEAR"))
	self.searchPlaceholder:SetText(label("STARRED_SEARCH_HINT"))
	self.searchPlaceholder:SetShown(query == "")
	self.empty:SetText(label(query:find("%S") and "STARRED_NO_MATCHES" or "STARRED_EMPTY"))
	self.empty:SetShown(#entries == 0)
	self:Layout()
	self.list:SetElements(entries, {
		retainIdentity = resetScroll ~= true, retainScroll = resetScroll ~= true,
		retainFrames = resetScroll ~= true,
	})
end

function Panel:Show()
	if self.frame then
		if self.frame:IsShown() then self:Refresh() else self.frame:Show() end
	end
end

function Panel:Hide()
	self:CancelClearConfirmation()
	self:CancelRemoveConfirmation()
	if self.frame then self.frame:Hide() end
	if self.editor then self.editor:Hide() end
end
