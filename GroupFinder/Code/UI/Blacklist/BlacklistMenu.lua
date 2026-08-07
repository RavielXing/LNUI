local _, GF = ...

GF.BlacklistMenu = GF.BlacklistMenu or {}
local BlacklistMenu = GF.BlacklistMenu

local NOTE_MAX_LETTERS = 140
local SHARED_DIALOG_STYLE = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}
local NOTE_DIALOG_STYLE = {
	DIALOG_W = SHARED_DIALOG_STYLE.WIDTH or 420,
	DIALOG_H = SHARED_DIALOG_STYLE.HEIGHT or 176,
	DIALOG_LEVEL_OFFSET = SHARED_DIALOG_STYLE.LEVEL_OFFSET or 18,
	DIALOG_PRESENT_OFFSET_Y = SHARED_DIALOG_STYLE.SCREEN_OFFSET_Y or 20,
	CONTENT_INSET_X = SHARED_DIALOG_STYLE.CONTENT_INSET_X or 36,
	CONTENT_BOTTOM_INSET = SHARED_DIALOG_STYLE.CONTENT_BOTTOM_INSET or 18,
	INPUT_CENTER_OFFSET_Y = SHARED_DIALOG_STYLE.BLACKLIST_INPUT_CENTER_OFFSET_Y
		or -21,
	MESSAGE_PRIMARY_FONT_SIZE = SHARED_DIALOG_STYLE.PRIMARY_TEXT_FONT_SIZE or 15,
	MESSAGE_SECONDARY_FONT_SIZE = SHARED_DIALOG_STYLE.SECONDARY_TEXT_FONT_SIZE or 12,
	MESSAGE_LINE_GAP = SHARED_DIALOG_STYLE.TEXT_LINE_GAP or 5,
	MESSAGE_TO_INPUT_GAP = SHARED_DIALOG_STYLE.TEXT_TO_INPUT_GAP or 8,
	INPUT_W = SHARED_DIALOG_STYLE.INPUT_WIDTH or 330,
	INPUT_H = SHARED_DIALOG_STYLE.INPUT_HEIGHT or 30,
	INPUT_FONT_SIZE = SHARED_DIALOG_STYLE.INPUT_EDIT_FONT_SIZE or 14,
	PLACEHOLDER_FONT_SIZE = SHARED_DIALOG_STYLE.INPUT_PLACEHOLDER_FONT_SIZE or 12,
	MIN_FITTED_TEXT_SIZE = SHARED_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE or 10,
	BUTTON_W = SHARED_DIALOG_STYLE.BUTTON_WIDTH
		or GF.PANEL_BUTTON_STANDARD_W or 72,
	BUTTON_GAP = SHARED_DIALOG_STYLE.BUTTON_GAP or 12,
}
local GROUP_MENU_TAGS = {
	"MENU_UNIT_PARTY",
	"MENU_UNIT_RAID_PLAYER",
	"MENU_UNIT_RAID",
}
local activeUnitMenuCopyName

local function trim(text)
	if type(text) ~= "string" then
		return ""
	end
	return text:match("^%s*(.-)%s*$") or ""
end

local function isAccessibleValue(value)
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return false
		end
	end
	return true
end

local function readField(owner, key)
	if not isAccessibleValue(owner) or type(owner) ~= "table" then
		return nil
	end
	if type(canaccesstable) == "function" then
		local ok, accessible = pcall(canaccesstable, owner)
		if not ok or accessible ~= true then
			return nil
		end
	end
	if type(issecretvaluekey) == "function" then
		local ok, secret = pcall(issecretvaluekey, owner, key)
		if ok and secret == true then
			return nil
		end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok or not isAccessibleValue(value) then
		return nil
	end
	return value
end

local function normalizePlayerName(name, realm)
	if not isAccessibleValue(name) or type(name) ~= "string" or name == "" then
		return nil
	end
	if realm ~= nil
		and (not isAccessibleValue(realm) or type(realm) ~= "string")
	then
		return nil
	end
	if type(GF.NormalizeExternalFullPlayerName) ~= "function" then
		return nil
	end
	local ok, normalized = pcall(GF.NormalizeExternalFullPlayerName, name, realm)
	if not ok or not isAccessibleValue(normalized)
		or type(normalized) ~= "string" or normalized == ""
	then
		return nil
	end
	return normalized
end

local function playerNameKey(name)
	name = normalizePlayerName(name)
	if not name then
		return nil
	end
	return name:gsub("%s+", ""):lower()
end

local function callAccessible(api, ...)
	if type(api) ~= "function" then
		return nil
	end
	local ok, value = pcall(api, ...)
	if not ok or not isAccessibleValue(value) then
		return nil
	end
	return value
end

local function readUnitFullName(unit)
	if not isAccessibleValue(unit) or type(unit) ~= "string" or unit == "" then
		return nil
	end
	if type(UnitExists) == "function"
		and callAccessible(UnitExists, unit) ~= true
	then
		return nil
	end
	if type(UnitFullName) ~= "function" then
		return nil
	end
	local ok, name, realm = pcall(UnitFullName, unit)
	if not ok then
		return nil
	end
	return normalizePlayerName(name, realm)
end

local function isCurrentPlayerName(name)
	local currentName = readUnitFullName("player")
	local currentKey = playerNameKey(currentName)
	local candidateKey = playerNameKey(name)
	if not currentKey or not candidateKey then
		return nil
	end
	return currentKey == candidateKey
end

local function unitIsCurrentPlayer(unit)
	local value = callAccessible(UnitIsUnit, unit, "player")
	if value == nil then
		return nil
	end
	return value == true
end

local function inChatMessagingLockdown()
	if not (C_ChatInfo and type(C_ChatInfo.InChatMessagingLockdown) == "function") then
		return false
	end
	local restricted = callAccessible(C_ChatInfo.InChatMessagingLockdown)
	return restricted == nil or restricted == true
end

local function normalizeClassFile(classFile)
	if not isAccessibleValue(classFile)
		or type(classFile) ~= "string" or classFile == ""
	then
		return nil
	end
	classFile = classFile:upper()
	if type(RAID_CLASS_COLORS) ~= "table" or RAID_CLASS_COLORS[classFile] == nil then
		return nil
	end
	return classFile
end

local function readUnitClassFile(unit)
	if not isAccessibleValue(unit) or type(unit) ~= "string" or unit == "" then
		return nil
	end
	if type(UnitClassBase) == "function" then
		local ok, classFile = pcall(UnitClassBase, unit)
		if ok then
			classFile = normalizeClassFile(classFile)
			if classFile then
				return classFile
			end
		end
	end
	if type(UnitClass) == "function" then
		local ok, _, classFile = pcall(UnitClass, unit)
		if ok then
			return normalizeClassFile(classFile)
		end
	end
	return nil
end

local function readGuidClassFile(guid, expectedName)
	if not isAccessibleValue(guid)
		or type(guid) ~= "string" or guid == ""
	then
		return nil
	end
	if type(GetPlayerInfoByGUID) == "function" then
		local ok, _, classFile, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
		if ok then
			classFile = normalizeClassFile(classFile)
			if classFile then
				local resolvedName = normalizePlayerName(name, realm)
				if expectedName and resolvedName
					and playerNameKey(expectedName) ~= playerNameKey(resolvedName)
				then
					return nil, true
				end
				return classFile
			end
		end
	end
	if type(UnitClassFromGUID) == "function" then
		local ok, _, classFile = pcall(UnitClassFromGUID, guid)
		if ok then
			return normalizeClassFile(classFile)
		end
	end
	return nil
end

local function readChatLineClassFile(contextData, expectedName)
	if inChatMessagingLockdown()
		or not (C_ChatInfo and type(C_ChatInfo.GetChatLineSenderGUID) == "function")
	then
		return nil
	end
	local lineID = readField(contextData, "lineID")
	if type(lineID) ~= "number" and type(lineID) ~= "string" then
		return nil
	end
	local ok, numericLineID = pcall(tonumber, lineID)
	if not ok or not numericLineID or numericLineID <= 0 then
		return nil
	end
	if type(C_ChatInfo.IsValidChatLine) == "function"
		and callAccessible(C_ChatInfo.IsValidChatLine, numericLineID) ~= true
	then
		return nil
	end
	if type(C_ChatInfo.GetChatLineSenderName) == "function" then
		local senderName = callAccessible(C_ChatInfo.GetChatLineSenderName, numericLineID)
		local normalizedSender = normalizePlayerName(senderName)
		if normalizedSender and expectedName
			and playerNameKey(normalizedSender) ~= playerNameKey(expectedName)
		then
			return nil, true
		end
	end
	local guid = callAccessible(C_ChatInfo.GetChatLineSenderGUID, numericLineID)
	return readGuidClassFile(guid, expectedName)
end

local function readPlayerLocationClassFile(contextData)
	if not (C_PlayerInfo and type(C_PlayerInfo.GetClass) == "function") then
		return nil
	end
	local playerLocation = readField(contextData, "playerLocation")
	if playerLocation == nil then
		return nil
	end
	local ok, _, classFile = pcall(C_PlayerInfo.GetClass, playerLocation)
	if not ok then
		return nil
	end
	return normalizeClassFile(classFile)
end

local function resolveContextClassFile(contextData, playerName)
	local classFile, identityMismatch = readChatLineClassFile(contextData, playerName)
	if identityMismatch then
		return nil
	end
	if classFile then
		return classFile
	end
	classFile, identityMismatch = readGuidClassFile(
		readField(contextData, "guid"), playerName)
	if identityMismatch then
		return nil
	end
	return classFile or readPlayerLocationClassFile(contextData)
end

local function resolveContextPlayerName(contextData, requireUnit)
	if not isAccessibleValue(contextData) or type(contextData) ~= "table" then
		return nil
	end
	local unit = readField(contextData, "unit")
	if unit ~= nil then
		if not isAccessibleValue(unit) or type(unit) ~= "string" or unit == "" then
			return nil
		end
		if callAccessible(UnitIsHumanPlayer, unit) ~= true then
			return nil
		end
		local isSelf = unitIsCurrentPlayer(unit)
		if isSelf == nil or isSelf == true then
			return nil
		end
		return readUnitFullName(unit), readUnitClassFile(unit)
	end
	if requireUnit then
		return nil
	end
	local name = normalizePlayerName(
		readField(contextData, "name"),
		readField(contextData, "server"))
	local isSelf = name and isCurrentPlayerName(name)
	if isSelf == nil or isSelf == true then
		return nil
	end
	return name, resolveContextClassFile(contextData, name)
end

local function blocklistIsEnabled()
	local blocklist = GF.Blocklist
	return blocklist
		and type(blocklist.IsEnabled) == "function"
		and blocklist:IsEnabled() == true
		and type(blocklist.AddManualPlayer) == "function"
end

local function getRedMenuLabel()
	local label = (GF.L or {}).BLOCKLIST_SOURCE_MANUAL or "加入黑名单"
	if RED_FONT_COLOR and type(RED_FONT_COLOR.WrapTextInColorCode) == "function" then
		return RED_FONT_COLOR:WrapTextInColorCode(label)
	end
	return "|cffff2020" .. label .. "|r"
end

local function wrapPlayerNameForDialog(playerName, classFile)
	classFile = normalizeClassFile(classFile)
	local color = classFile and RAID_CLASS_COLORS[classFile]
	if color and type(color.WrapTextInColorCode) == "function" then
		return color:WrapTextInColorCode(playerName)
	end
	if RED_FONT_COLOR and type(RED_FONT_COLOR.WrapTextInColorCode) == "function" then
		return RED_FONT_COLOR:WrapTextInColorCode(playerName)
	end
	return "|cffff2020" .. playerName .. "|r"
end

local function centerDialogButtonText(button)
	local fontString = button and button.GetFontString and button:GetFontString()
	if not fontString then
		return
	end
	fontString:ClearAllPoints()
	fontString:SetPoint("CENTER", button, "CENTER", 0, 0)
	fontString:SetJustifyH("CENTER")
	if fontString.SetJustifyV then
		fontString:SetJustifyV("MIDDLE")
	end
	fontString:SetWidth(math.max(1, button:GetWidth() or NOTE_DIALOG_STYLE.BUTTON_W))
	fontString:SetHeight(math.max(1, button:GetHeight() or GF.PANEL_BUTTON_H or 24))
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(
			fontString,
			math.max(1, (button:GetWidth() or NOTE_DIALOG_STYLE.BUTTON_W) - 12),
			10
		)
	end
end

local function applyDialogFontSize(fontString, template, size)
	if not fontString then
		return
	end
	fontString._gfFontSizeOverride = size
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template)
	end
end

local function splitDialogBody(body)
	if type(body) ~= "string" then
		return "将 %s 加入黑名单", "手动填写备注："
	end
	local first, second = body:match("^(.-)\n(.*)$")
	if first then
		return first, second
	end
	return body, ""
end

local function refreshNotePlaceholder(dialog)
	local placeholder = dialog and dialog.notePlaceholder
	local editBox = dialog and dialog.noteEdit
	if not (placeholder and editBox) then
		return
	end
	placeholder:SetShown(editBox:GetText() == "")
end

local function getDialogEditBox(dialog)
	if not dialog then
		return nil
	end
	if dialog.noteEdit then
		return dialog.noteEdit
	end
	if type(dialog.GetEditBox) == "function" then
		return dialog:GetEditBox()
	end
	return nil
end

local function closeBlacklistDialog(dialog)
	if dialog then
		dialog:Hide()
	end
end

local function acceptBlacklistDialog(dialog)
	if not dialog then
		return
	end
	if BlacklistMenu:AcceptDialog(dialog, dialog._gfBlacklistData) then
		dialog:Hide()
	end
end

local function ensureBlacklistDialog()
	if BlacklistMenu.dialog then
		return BlacklistMenu.dialog
	end
	local UI = GF.UI
	if not (UI and type(UI.CreateSatelliteSettingsFrame) == "function"
		and type(UI.CreatePlayerContextDialogContentHost) == "function"
		and type(UI.CreateSelectableCopyInput) == "function"
		and type(UI.CreatePanelButton) == "function")
	then
		return nil
	end

	local L = GF.L or {}
	local dialog = UI.CreateSatelliteSettingsFrame({
		name = "GroupFinderAddonBlacklistNoteDialog",
		width = NOTE_DIALOG_STYLE.DIALOG_W,
		height = NOTE_DIALOG_STYLE.DIALOG_H,
		title = L.BLOCK_NOTE_DIALOG_TITLE or "加入黑名单",
		levelOffset = NOTE_DIALOG_STYLE.DIALOG_LEVEL_OFFSET,
		backgroundColor = SHARED_DIALOG_STYLE.BACKGROUND_COLOR
			or GF.PLAYER_CONTEXT_DIALOG_BACKGROUND_COLOR,
	})
	if dialog.SetToplevel then
		dialog:SetToplevel(true)
	end
	dialog.contentHost = UI.CreatePlayerContextDialogContentHost(dialog)

	dialog.messageLine1 = UI.CreateFontString(dialog, "OVERLAY", "GameFontHighlight")
	if UI.ApplyPlayerContextDialogTextStyle then
		UI.ApplyPlayerContextDialogTextStyle(dialog.messageLine1, "primary")
	else
		applyDialogFontSize(
			dialog.messageLine1,
			"GameFontHighlight",
			NOTE_DIALOG_STYLE.MESSAGE_PRIMARY_FONT_SIZE)
	end
	dialog.messageLine1:SetJustifyH("CENTER")
	dialog.messageLine1:SetWordWrap(false)
	dialog.messageLine1:SetMaxLines(1)

	dialog.messageLine2 = UI.CreateFontString(dialog, "OVERLAY", "GameFontHighlightSmall")
	if UI.ApplyPlayerContextDialogTextStyle then
		UI.ApplyPlayerContextDialogTextStyle(dialog.messageLine2, "secondary")
	else
		applyDialogFontSize(
			dialog.messageLine2,
			"GameFontHighlight",
			NOTE_DIALOG_STYLE.MESSAGE_SECONDARY_FONT_SIZE)
	end
	dialog.messageLine2:SetJustifyH("CENTER")
	dialog.messageLine2:SetWordWrap(false)
	dialog.messageLine2:SetMaxLines(1)

	dialog.noteInput, dialog.noteEdit = UI.CreateSelectableCopyInput(
		dialog,
		NOTE_DIALOG_STYLE.INPUT_W,
		{
			selectAllOnMouseDown = false,
			height = NOTE_DIALOG_STYLE.INPUT_H,
			fontSize = NOTE_DIALOG_STYLE.INPUT_FONT_SIZE,
		}
	)
	dialog.noteInput:SetPoint(
		"CENTER",
		dialog.contentHost,
		"CENTER",
		0,
		NOTE_DIALOG_STYLE.INPUT_CENTER_OFFSET_Y
	)
	dialog.messageLine2:SetPoint(
		"LEFT",
		dialog.contentHost,
		"LEFT",
		0,
		0)
	dialog.messageLine2:SetPoint(
		"RIGHT",
		dialog.contentHost,
		"RIGHT",
		0,
		0)
	dialog.messageLine2:SetPoint(
		"BOTTOM",
		dialog.noteInput,
		"TOP",
		0,
		NOTE_DIALOG_STYLE.MESSAGE_TO_INPUT_GAP)
	dialog.messageLine1:SetPoint(
		"LEFT",
		dialog.contentHost,
		"LEFT",
		0,
		0)
	dialog.messageLine1:SetPoint(
		"RIGHT",
		dialog.contentHost,
		"RIGHT",
		0,
		0)
	dialog.messageLine1:SetPoint(
		"BOTTOM",
		dialog.messageLine2,
		"TOP",
		0,
		NOTE_DIALOG_STYLE.MESSAGE_LINE_GAP)
	dialog.noteEdit:SetJustifyH("LEFT")
	dialog.noteEdit:SetMaxLetters(NOTE_MAX_LETTERS)
	dialog.noteEdit.Instructions = UI.CreateFontString(
		dialog.noteInput,
		"OVERLAY",
		"GameFontDisableSmall"
	)
	dialog.notePlaceholder = dialog.noteEdit.Instructions
	dialog.notePlaceholder:SetPoint("LEFT", dialog.noteInput, "LEFT", 16, 0)
	dialog.notePlaceholder:SetPoint("RIGHT", dialog.noteInput, "RIGHT", -16, 0)
	dialog.notePlaceholder:SetJustifyH("LEFT")
	dialog.notePlaceholder:SetMaxLines(1)
	applyDialogFontSize(
		dialog.notePlaceholder,
		"GameFontDisableSmall",
		NOTE_DIALOG_STYLE.PLACEHOLDER_FONT_SIZE
	)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(
			dialog.notePlaceholder,
			NOTE_DIALOG_STYLE.INPUT_W - 32,
			NOTE_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE
		)
	end

	dialog.confirmButton = UI.CreatePanelButton(
		dialog,
		L.BLOCK_NOTE_CONFIRM or "确认",
		NOTE_DIALOG_STYLE.BUTTON_W
	)
	dialog.cancelButton = UI.CreatePanelButton(
		dialog,
		L.BLOCK_NOTE_CANCEL or CANCEL or "取消",
		NOTE_DIALOG_STYLE.BUTTON_W
	)
	if UI.ApplyPlayerContextDialogButtonFont then
		UI.ApplyPlayerContextDialogButtonFont(dialog.confirmButton)
		UI.ApplyPlayerContextDialogButtonFont(dialog.cancelButton)
	end
	dialog.confirmButton:SetPoint(
		"BOTTOMRIGHT",
		dialog,
		"BOTTOM",
		-(NOTE_DIALOG_STYLE.BUTTON_GAP / 2),
		NOTE_DIALOG_STYLE.CONTENT_BOTTOM_INSET
	)
	dialog.cancelButton:SetPoint(
		"BOTTOMLEFT",
		dialog,
		"BOTTOM",
		NOTE_DIALOG_STYLE.BUTTON_GAP / 2,
		NOTE_DIALOG_STYLE.CONTENT_BOTTOM_INSET
	)
	centerDialogButtonText(dialog.confirmButton)
	centerDialogButtonText(dialog.cancelButton)

	dialog.confirmButton:SetScript("OnClick", function()
		acceptBlacklistDialog(dialog)
	end)
	dialog.cancelButton:SetScript("OnClick", function()
		closeBlacklistDialog(dialog)
	end)
	if dialog.ClosePanelButton then
		dialog.ClosePanelButton:SetScript("OnClick", function()
			closeBlacklistDialog(dialog)
		end)
	end
	dialog.noteEdit:SetScript("OnEnterPressed", function()
		acceptBlacklistDialog(dialog)
	end)
	dialog.noteEdit:SetScript("OnEscapePressed", function()
		closeBlacklistDialog(dialog)
	end)
	dialog.noteEdit:SetScript("OnTextChanged", function()
		refreshNotePlaceholder(dialog)
	end)
	dialog.noteEdit:SetScript("OnEditFocusGained", function()
		if dialog.noteInput.RefreshVisualState then
			dialog.noteInput:RefreshVisualState()
		end
		refreshNotePlaceholder(dialog)
	end)
	dialog.noteEdit:SetScript("OnEditFocusLost", function()
		if dialog.noteInput.RefreshVisualState then
			dialog.noteInput:RefreshVisualState()
		end
		refreshNotePlaceholder(dialog)
	end)
	dialog:HookScript("OnHide", function()
		dialog._gfBlacklistData = nil
		dialog.noteEdit:SetText("")
		dialog.noteEdit:ClearFocus()
		refreshNotePlaceholder(dialog)
		if ChatFrameUtil
			and type(ChatFrameUtil.FocusActiveWindow) == "function"
		then
			pcall(ChatFrameUtil.FocusActiveWindow)
		end
	end)

	BlacklistMenu.dialog = dialog
	return dialog
end

local function presentBlacklistDialog(dialog, data)
	local UI = GF.UI
	if not (dialog and UI and type(UI.PresentSatelliteFrame) == "function") then
		return false
	end
	local L = GF.L or {}
	local copyDialog = UI.characterNameCopyDialog
	if copyDialog and copyDialog.IsShown and copyDialog:IsShown() then
		copyDialog:Hide()
	end
	UI.PresentSatelliteFrame(dialog, {
		title = L.BLOCK_NOTE_DIALOG_TITLE or "加入黑名单",
		centerOnUIParent = true,
		offsetY = NOTE_DIALOG_STYLE.DIALOG_PRESENT_OFFSET_Y,
		prepare = function(frame)
			frame._gfBlacklistData = data
			local firstLine, secondLine = splitDialogBody(
				L.BLOCK_NOTE_DIALOG_TEXT
					or "将 %s 加入黑名单\n手动填写备注：")
			frame.messageLine1:SetFormattedText(firstLine, data.displayName or "")
			frame.messageLine2:SetText(secondLine)
			if GF.Font and GF.Font.SetFitWidth then
				local messageWidth = NOTE_DIALOG_STYLE.DIALOG_W
					- (NOTE_DIALOG_STYLE.CONTENT_INSET_X * 2)
				GF.Font.SetFitWidth(
					frame.messageLine1,
					messageWidth,
					NOTE_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE)
				GF.Font.SetFitWidth(
					frame.messageLine2,
					messageWidth,
					NOTE_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE)
			end
			frame.notePlaceholder:SetText(
				L.BLOCK_NOTE_INPUT_HINT or "请输入备注（可选）")
			if GF.Font and GF.Font.SetFitWidth then
				GF.Font.SetFitWidth(
					frame.notePlaceholder,
					NOTE_DIALOG_STYLE.INPUT_W - 32,
					NOTE_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE
				)
			end
			frame.confirmButton:SetText(L.BLOCK_NOTE_CONFIRM or "确认")
			frame.cancelButton:SetText(L.BLOCK_NOTE_CANCEL or CANCEL or "取消")
			centerDialogButtonText(frame.confirmButton)
			centerDialogButtonText(frame.cancelButton)
			frame.noteEdit:SetText("")
			refreshNotePlaceholder(frame)
		end,
		onShown = function(frame)
			frame.noteEdit:SetFocus()
		end,
	})
	if UI.RaiseFrame then
		UI.RaiseFrame(dialog)
	elseif dialog.Raise then
		dialog:Raise()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if dialog:IsShown() then
				dialog.noteEdit:SetFocus()
			end
		end)
	end
	return true
end

function BlacklistMenu:AcceptDialog(dialog, data)
	if type(data) ~= "table" or not blocklistIsEnabled() then
		return false
	end
	local playerName = normalizePlayerName(data.playerName)
	if not playerName or isCurrentPlayerName(playerName) ~= false then
		return false
	end
	local editBox = getDialogEditBox(dialog)
	local note = trim(editBox and editBox:GetText())
	if note == "" then
		local blocklist = GF.Blocklist
		note = blocklist.GetBlacklistNoteManual
			and blocklist:GetBlacklistNoteManual() or "手动拉黑"
	end
	local added = GF.Blocklist:AddManualPlayer(playerName, note)
	if added and type(data.onAdded) == "function" then
		data.onAdded(playerName)
	end
	return added == true
end

function BlacklistMenu:OpenManualAddDialog(playerName, options)
	if not blocklistIsEnabled() then
		return false
	end
	playerName = normalizePlayerName(playerName)
	if not playerName or isCurrentPlayerName(playerName) ~= false then
		return false
	end
	local dialog = ensureBlacklistDialog()
	if not dialog then
		return false
	end
	local data = {
		playerName = playerName,
		classFile = type(options) == "table" and normalizeClassFile(options.classFile) or nil,
		onAdded = type(options) == "table" and options.onAdded or nil,
	}
	data.displayName = wrapPlayerNameForDialog(playerName, data.classFile)
	return presentBlacklistDialog(dialog, data)
end

local function appendManualBlacklistButton(rootDescription, playerName, classFile)
	if not blocklistIsEnabled() or not playerName then
		return
	end
	rootDescription:CreateDivider()
	rootDescription:CreateButton(getRedMenuLabel(), function()
		BlacklistMenu:OpenManualAddDialog(playerName, { classFile = classFile })
	end)
end

local function modifyGroupUnitMenu(_, rootDescription, contextData)
	appendManualBlacklistButton(
		rootDescription,
		resolveContextPlayerName(contextData, true))
end

local function modifyChatPlayerMenu(_, rootDescription, contextData)
	if inChatMessagingLockdown() then
		return
	end
	if not isAccessibleValue(contextData) or type(contextData) ~= "table"
		or readField(contextData, "chatFrame") == nil then
		return
	end
	appendManualBlacklistButton(
		rootDescription,
		resolveContextPlayerName(contextData, false))
end

function BlacklistMenu:RegisterNativeMenus()
	if self._nativeMenusRegistered then
		return true
	end
	if not (Menu and type(Menu.ModifyMenu) == "function") then
		return false
	end
	for _, tag in ipairs(GROUP_MENU_TAGS) do
		Menu.ModifyMenu(tag, modifyGroupUnitMenu)
	end
	Menu.ModifyMenu("MENU_UNIT_FRIEND", modifyChatPlayerMenu)
	self._nativeMenusRegistered = true
	return true
end

local function resolveUnitMenuTarget(data, unitOverride, expectedNameOverride)
	if not isAccessibleValue(data) or type(data) ~= "table"
		or readField(data, "isCarpoolEntry") == true
		or readField(data, "isDebugTest") == true
		or readField(data, "isTest") == true
		or readField(data, "source") == "test"
	then
		return nil
	end
	local unit = unitOverride or readField(data, "unit")
	if callAccessible(UnitIsHumanPlayer, unit) ~= true then
		return nil
	end
	local isSelf = unitIsCurrentPlayer(unit)
	if isSelf == nil then
		return nil
	end
	local currentName = readUnitFullName(unit)
	local expectedName = normalizePlayerName(
		expectedNameOverride
			or readField(data, "fullName")
			or readField(data, "name"),
		readField(data, "realm"))
	if not currentName or not expectedName
		or playerNameKey(currentName) ~= playerNameKey(expectedName)
	then
		return nil
	end
	local raidIndex = callAccessible(UnitInRaid, unit)
	local inRaid = type(raidIndex) == "number" and raidIndex > 0
	local inParty = callAccessible(UnitInParty, unit) == true
	if isSelf ~= true and not inRaid and not inParty then
		return nil
	end
	return unit, currentName
end

local function clearUnitMenuAttributes(button)
	if not (button and type(button.SetAttribute) == "function") then
		return
	end
	button:SetAttribute("*type2", nil)
	button:SetAttribute("unit", nil)
end

local function replaceActiveUnitMenuCopyDescription(entry, rootDescription)
	if entry ~= UnitPopupCopyCharacterNameButtonMixin
		or type(activeUnitMenuCopyName) ~= "string"
		or activeUnitMenuCopyName == ""
		or not (rootDescription
			and type(rootDescription.EnumerateElementDescriptions) == "function")
	then
		return
	end
	local copyDescription
	for _, description in rootDescription:EnumerateElementDescriptions() do
		copyDescription = description
	end
	if not (copyDescription and type(copyDescription.SetResponder) == "function") then
		return
	end
	local copyName = activeUnitMenuCopyName
	activeUnitMenuCopyName = nil
	copyDescription:SetResponder(function()
		if GF.UI and type(GF.UI.ShowCharacterNameCopyDialog) == "function" then
			GF.UI.ShowCharacterNameCopyDialog(copyName)
		end
	end)
end

function BlacklistMenu:RegisterRosterCopyReplacement()
	if self._rosterCopyReplacementRegistered then
		return true
	end
	if type(hooksecurefunc) ~= "function"
		or type(UnitPopupCopyCharacterNameButtonMixin) ~= "table"
		or type(UnitPopupCopyCharacterNameButtonMixin.CreateMenuDescription) ~= "function"
	then
		return false
	end
	hooksecurefunc(
		UnitPopupCopyCharacterNameButtonMixin,
		"CreateMenuDescription",
		replaceActiveUnitMenuCopyDescription)
	self._rosterCopyReplacementRegistered = true
	return true
end

local function beginUnitMenu(data, button, mouseButton, unitOverride, expectedNameOverride)
	activeUnitMenuCopyName = nil
	clearUnitMenuAttributes(button)
	if mouseButton ~= "RightButton"
		or not (button and type(button.SetAttribute) == "function")
		or not (GF.UI
			and type(GF.UI.ShowCharacterNameCopyDialog) == "function")
	then
		return false
	end
	local unit, currentName = resolveUnitMenuTarget(
		data,
		unitOverride,
		expectedNameOverride)
	if not unit then
		return false
	end
	if GameTooltip then
		GameTooltip:Hide()
	end
	activeUnitMenuCopyName = currentName
	button:SetAttribute("unit", unit)
	button:SetAttribute("*type2", "togglemenu")
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, function()
			if activeUnitMenuCopyName == currentName then
				activeUnitMenuCopyName = nil
			end
		end)
	end
	return true
end

function BlacklistMenu:BeginRosterUnitMenu(data, button, mouseButton)
	return beginUnitMenu(data, button, mouseButton)
end

function BlacklistMenu:BeginCurrentCharacterUnitMenu(data, button, mouseButton)
	local expectedName = readField(data, "fullName")
		or readField(data, "key")
		or readField(data, "name")
	return beginUnitMenu(
		data,
		button,
		mouseButton,
		"player",
		expectedName)
end

function BlacklistMenu:EndRosterUnitMenu()
	activeUnitMenuCopyName = nil
end

BlacklistMenu.EndCurrentCharacterUnitMenu = BlacklistMenu.EndRosterUnitMenu

function BlacklistMenu:Init()
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	local nativeMenusReady = self:RegisterNativeMenus()
	local copyReplacementReady = self:RegisterRosterCopyReplacement()
	return nativeMenusReady and copyReplacementReady
end
