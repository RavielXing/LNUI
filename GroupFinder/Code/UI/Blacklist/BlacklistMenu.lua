local _, GF = ...

GF.BlacklistMenu = GF.BlacklistMenu or {}
local BlacklistMenu = GF.BlacklistMenu

local NOTE_MAX_LETTERS = 140
local SHARED_DIALOG_STYLE = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}
local FORM_STYLE = GF.BLACKLIST_NOTE_DIALOG_STYLE
local function dialogInputWidth()
	return FORM_STYLE.width - FORM_STYLE.contentInset * 2
end
local NATIVE_PLAYER_MENU_TAGS = {
	"MENU_UNIT_SELF",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_RAID_PLAYER",
	"MENU_UNIT_RAID",
	"MENU_UNIT_PLAYER",
}
local nativeUnitMenuRestrictionPending = false
local nativeUnitMenuRegistrationDepth = 0

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

local function formatPlayerNameForCopy(name, realm)
	if not isAccessibleValue(name) or type(name) ~= "string" or name == "" then
		return nil
	end
	if realm ~= nil
		and (not isAccessibleValue(realm) or type(realm) ~= "string")
	then
		return nil
	end
	if type(GF.FormatExternalFullPlayerNameForCopy) ~= "function" then
		return nil
	end
	local ok, formatted = pcall(GF.FormatExternalFullPlayerNameForCopy, name, realm)
	if not ok or not isAccessibleValue(formatted)
		or type(formatted) ~= "string" or formatted == ""
	then
		return nil
	end
	return formatted
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
	return normalizePlayerName(name, realm),
		formatPlayerNameForCopy(name, realm)
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

local function resolveContextPlayer(contextData, requireUnit)
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
		if isSelf == nil then
			return nil
		end
		local playerName, copyPlayerName = readUnitFullName(unit)
		if not playerName then
			return nil
		end
		return playerName, readUnitClassFile(unit), isSelf,
			copyPlayerName
	end
	if requireUnit then
		return nil
	end
	local rawName = readField(contextData, "name")
	local rawServer = readField(contextData, "server")
	local name = normalizePlayerName(rawName, rawServer)
	local isSelf = name and isCurrentPlayerName(name)
	if isSelf == nil then
		return nil
	end
	return name, resolveContextClassFile(contextData, name), isSelf,
		formatPlayerNameForCopy(rawName, rawServer)
end

local function blocklistIsEnabled()
	local presenter = GF.BlacklistPresenter
	if presenter and type(presenter.CanAddManualPlayer) == "function" then
		return presenter:CanAddManualPlayer() == true
	end
	-- Compatibility for isolated menu mocks; the real TOC always loads the
	-- presenter first, so live action eligibility has one owner.
	return presenter == nil
end

local function getRedMenuLabel(labelOverride)
	local label = labelOverride
		or (GF.L or {}).BLOCKLIST_SOURCE_MANUAL
		or "加入黑名单"
	if RED_FONT_COLOR and type(RED_FONT_COLOR.WrapTextInColorCode) == "function" then
		return RED_FONT_COLOR:WrapTextInColorCode(label)
	end
	return "|cffff2020" .. label .. "|r"
end

local function getCopyMenuLabel()
	return (GF.L or {}).APPLICANT_COPY_NAME or "复制角色名"
end

local function menuEnhancementIsEnabled()
	if type(GF.GetDB) ~= "function" then
		-- The production load order initializes the settings repository before
		-- this menu. Keep isolated UI mocks compatible with the current default.
		return true
	end
	local ok, database = pcall(GF.GetDB)
	return ok
		and type(database) == "table"
		and database.menuEnhancementEnabled ~= false
end

local function contextActionPlan(playerName, classFile, isSelf, copyPlayerName)
	if not menuEnhancementIsEnabled() then
		return nil
	end
	local presenter = GF.BlacklistPresenter
	if presenter and type(presenter.BuildContextActionPlan) == "function" then
		return presenter:BuildContextActionPlan(playerName, {
			classFile = classFile,
			isSelf = isSelf,
			copyPlayerName = copyPlayerName,
		})
	end
	-- The production load order never enters this branch.  It keeps the menu
	-- adapter independently mockable without creating a second runtime owner.
	if type(playerName) ~= "string" or type(isSelf) ~= "boolean" then
		return nil
	end
	local plan = {
		title = (GF.L or {}).PLAYER_CONTEXT_MENU_TITLE or "GroupFinder",
		playerName = playerName,
		copyPlayerName = copyPlayerName or playerName,
		classFile = classFile,
		actions = {
			{ id = "copy-player-name", label = getCopyMenuLabel() },
		},
	}
	if isSelf == false and blocklistIsEnabled() then
		plan.actions[#plan.actions + 1] = {
			id = "add-player",
			label = (GF.L or {}).BLOCKLIST_SOURCE_MANUAL or "加入黑名单",
			danger = true,
		}
	end
	return plan
end

local function contextActionLabel(action)
	local presenter = GF.BlacklistPresenter
	local label = presenter
		and type(presenter.GetContextActionLabel) == "function"
		and presenter:GetContextActionLabel(action)
		or action and action.label
		or ""
	if action and action.danger == true then
		return getRedMenuLabel(label)
	end
	return label
end

local function contextActionCallback(plan, action)
	if not (plan and action) then
		return nil
	end
	if action.id == "copy-player-name" then
		return function()
			if not menuEnhancementIsEnabled() then
				return
			end
			GF.UI.ShowCharacterNameCopyDialog(
				plan.copyPlayerName or plan.playerName)
		end
	end
	if action.id == "add-player" then
		return function()
			if not menuEnhancementIsEnabled() then
				return
			end
			BlacklistMenu:OpenManualAddDialog(
				plan.playerName,
				{ classFile = plan.classFile })
		end
	end
	return nil
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
		width = FORM_STYLE.width,
		height = SHARED_DIALOG_STYLE.HEIGHT,
		title = L.BLOCK_NOTE_DIALOG_TITLE or "加入黑名单",
		levelOffset = SHARED_DIALOG_STYLE.LEVEL_OFFSET,
		backgroundColor = FORM_STYLE.backgroundColor,
	})
	if dialog.SetToplevel then
		dialog:SetToplevel(true)
	end
	dialog.contentHost = UI.CreatePlayerContextDialogContentHost(dialog)

	dialog.messageLine1 = UI.CreateFontString(dialog, "OVERLAY", "GameFontHighlightSmall")
	UI.ApplyPlayerContextDialogTextStyle(dialog.messageLine1, "secondary")
	dialog.messageLine1._gfFontSizeOverride = FORM_STYLE.noticeFontSize
	dialog.messageLine1._gfIgnoreFontScale = true
	dialog.messageLine1:SetTextColor(unpack(FORM_STYLE.noticeColor))
	dialog.messageLine1:SetJustifyH("CENTER")
	dialog.messageLine1:SetWordWrap(false)
	dialog.messageLine1:SetMaxLines(1)
	for _, field in ipairs({ "name", "note" }) do
		local label, shell, edit, placeholder = UI.CreatePlayerManagementDialogField(
			dialog, field == "name" and 100 or NOTE_MAX_LETTERS, field == "note")
		dialog[field .. "Label"], dialog[field .. "Input"], dialog[field .. "Edit"] = label, shell, edit
		dialog[field .. "Placeholder"] = placeholder
	end
	dialog.messageLine2 = dialog.noteLabel
	dialog.errorText = UI.CreateFontString(dialog, "OVERLAY", "GameFontHighlightSmall")
	UI.ApplyPlayerContextDialogTextStyle(dialog.errorText, "secondary")
	dialog.errorText:SetTextColor(1, 0.2, 0.2); dialog.errorText:SetJustifyH("LEFT")
	dialog.errorText:SetWordWrap(true); dialog.errorText:SetMaxLines(0)
	dialog.errorText:SetWidth(dialogInputWidth())

	dialog.actionBar, dialog.confirmButton, dialog.cancelButton = UI.CreatePlayerManagementDialogActions(
		dialog, L.BLOCK_NOTE_CONFIRM or "确认", L.BLOCK_NOTE_CANCEL or CANCEL or "取消")

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
	dialog.noteEdit:SetScript("OnEnterPressed", function(edit)
		if not (edit.IsIMEComposing and edit:IsIMEComposing()) then acceptBlacklistDialog(dialog) end
	end)
	dialog.nameEdit:SetScript("OnEnterPressed", function(edit)
		if not (edit.IsIMEComposing and edit:IsIMEComposing()) then dialog.noteEdit:SetFocus() end
	end)
	dialog.nameEdit:SetScript("OnEscapePressed", function() closeBlacklistDialog(dialog) end)
	for index, field in ipairs({ "name", "note" }) do
		dialog[field .. "Edit"]:SetScript("OnTabPressed", function()
			if dialog._gfBlacklistData and dialog._gfBlacklistData.manual then
				dialog[index == 1 and "noteEdit" or "nameEdit"]:SetFocus()
			end
		end)
	end
	dialog.nameEdit:SetScript("OnTextChanged", function(edit)
		dialog.namePlaceholder:SetShown(edit:GetText() == "")
		if dialog.errorKey then dialog.errorKey = nil; BlacklistMenu:RefreshLocale() end
	end)
	dialog.noteEdit:SetScript("OnEscapePressed", function()
		closeBlacklistDialog(dialog)
	end)
	dialog.noteEdit:SetScript("OnTextChanged", function()
		local presenter = GF.BlacklistPresenter
		local data = dialog._gfBlacklistData
		if presenter and data and data.ticket then
			presenter:UpdateAddDraft(
				data.ticket,
				dialog.noteEdit:GetText() or "")
		end
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
		local data = dialog._gfBlacklistData
		local presenter = GF.BlacklistPresenter
		if presenter and data and data.ticket then
			presenter:CancelManualAdd(data.ticket)
		end
		dialog._gfBlacklistData = nil
		dialog.errorKey = nil
		dialog.nameEdit:SetText(""); dialog.nameEdit:ClearFocus()
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
		offsetY = SHARED_DIALOG_STYLE.SCREEN_OFFSET_Y,
		prepare = function(frame)
			frame._gfBlacklistData = data
			frame.errorKey = nil
			frame.nameEdit:SetText("")
			BlacklistMenu:RefreshLocale()
			frame.noteEdit:SetText(data.draft or "")
			refreshNotePlaceholder(frame)
		end,
		onShown = function(frame)
			frame[data.manual and "nameEdit" or "noteEdit"]:SetFocus()
		end,
	})
	if UI.RaiseFrame then
		UI.RaiseFrame(dialog)
	elseif dialog.Raise then
		dialog:Raise()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if dialog:IsShown() and dialog._gfBlacklistData == data then
				dialog[data.manual and "nameEdit" or "noteEdit"]:SetFocus()
			end
		end)
	end
	return true
end

function BlacklistMenu:RefreshLocale()
	local dialog, L = self.dialog, GF.L or {}
	local data = dialog and dialog._gfBlacklistData
	if not data then return end
	local title = data.manual and L.BLOCKLIST_MANUAL_ADD_TEXT
		or L.BLOCK_NOTE_DIALOG_TITLE or "加入黑名单"
	dialog.messageLine1:SetText(data.manual and ""
		or string.format(L.BLOCK_NOTE_DIALOG_TEXT or "将 %s 加入黑名单", data.displayName or ""))
	dialog.nameLabel:SetText(L.BLOCKLIST_NAME)
	dialog.namePlaceholder:SetText(L.BLOCKLIST_NAME_HINT)
	dialog.noteLabel:SetText(L.BLOCKLIST_NOTE_LABEL)
	dialog.notePlaceholder:SetText(L.BLOCK_NOTE_INPUT_HINT)
	dialog.confirmButton:SetText(L.BLOCK_NOTE_CONFIRM or "确认")
	dialog.cancelButton:SetText(L.BLOCK_NOTE_CANCEL or "取消")
	dialog.errorText:SetText(dialog.errorKey and L[dialog.errorKey] or "")
	GF.UI.SetPlayerManagementDialogTitle(dialog, title)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(dialog.messageLine1, dialogInputWidth(), FORM_STYLE.noticeMinFontSize)
		for _, text in ipairs({ dialog.nameLabel, dialog.noteLabel }) do
			GF.Font.SetFitWidth(text, dialogInputWidth(), FORM_STYLE.minFontSize)
		end
		for _, field in ipairs({ "name", "note" }) do
			local inset = field == "note" and FORM_STYLE.noteTextInset or FORM_STYLE.inputTextInset
			GF.Font.SetFitWidth(dialog[field .. "Placeholder"], dialogInputWidth() - inset * 2, FORM_STYLE.minFontSize)
		end
	end
	GF.UI.RefreshPlayerManagementDialogButton(dialog.confirmButton)
	GF.UI.RefreshPlayerManagementDialogButton(dialog.cancelButton)
	GF.UI.LayoutPlayerManagementDialog(dialog, dialog.messageLine1, {
		{ label = dialog.nameLabel, input = dialog.nameInput, shown = data.manual == true },
		{ label = dialog.noteLabel, labelShown = false, input = dialog.noteInput, height = FORM_STYLE.noteHeight },
	}, dialog.errorText, FORM_STYLE)
end

function BlacklistMenu:AcceptDialog(dialog, data)
	local presenter = GF.BlacklistPresenter
	if not dialog or dialog._gfBlacklistData ~= data or type(data) ~= "table" or not presenter
		or type(presenter.ConfirmManualAdd) ~= "function" or not blocklistIsEnabled() then return false end
	local playerName = normalizePlayerName(data.manual and dialog.nameEdit:GetText() or data.playerName)
	if not playerName or isCurrentPlayerName(playerName) ~= false then
		dialog.errorKey = "BLOCKLIST_INVALID_PLAYER"; self:RefreshLocale(); return false
	end
	local editBox = getDialogEditBox(dialog)
	local note = editBox and editBox:GetText() or ""
	if data.manual then
		local plan = presenter:PlanManualAdd(playerName, { isSelf = false })
		if not plan then return false end
		data.ticket = plan.ticket
	end
	presenter:UpdateAddDraft(data.ticket, note)
	local accepted = presenter:ConfirmManualAdd(data.ticket, note) == true
	if not accepted then dialog.errorKey = "BLOCKLIST_ADD_FAILED"; self:RefreshLocale() end
	return accepted
end

function BlacklistMenu:OpenManualAddDialog(playerName, options)
	if not blocklistIsEnabled() then return false end
	local manual = playerName == nil
	if not manual then
		playerName = normalizePlayerName(playerName)
		if not playerName or isCurrentPlayerName(playerName) ~= false then return false end
	end
	local presenter = GF.BlacklistPresenter
	if not presenter or type(presenter.PlanManualAdd) ~= "function" then return false end
	local dialog = ensureBlacklistDialog()
	if not dialog then return false end
	if dialog:IsShown() then dialog:Hide() end
	local classFile = type(options) == "table" and normalizeClassFile(options.classFile) or nil
	local data = manual and { manual = true, draft = "" } or presenter:PlanManualAdd(playerName, {
		classFile = classFile, isSelf = false,
		onAdded = type(options) == "table" and options.onAdded or nil,
		displayName = wrapPlayerNameForDialog(playerName, classFile),
	})
	if not data then return false end
	if not presentBlacklistDialog(dialog, data) then
		if data.ticket then presenter:CancelManualAdd(data.ticket) end
		return false
	end
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
	local currentName, copyPlayerName = readUnitFullName(unit)
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
	return unit, currentName, isSelf, copyPlayerName
end

local function showRosterContextMenu(
	data,
	owner,
	mouseButton,
	unitOverride,
	expectedNameOverride)
	if not menuEnhancementIsEnabled()
		or mouseButton ~= "RightButton"
		or not (GF.RowContextMenu
			and type(GF.RowContextMenu.ShowMenu) == "function")
		or not (GF.UI
			and type(GF.UI.ShowCharacterNameCopyDialog) == "function")
	then
		return false
	end
	local unit, currentName, isSelf, copyPlayerName = resolveUnitMenuTarget(
		data,
		unitOverride,
		expectedNameOverride)
	if not unit then
		return false
	end
	local classFile = normalizeClassFile(
		readField(data, "classFile") or readField(data, "class"))
	local plan = contextActionPlan(
		currentName,
		classFile,
		isSelf,
		copyPlayerName)
	if not plan then
		return false
	end
	if GameTooltip then
		GameTooltip:Hide()
	end
	local menuItems = {
		{
			isTitle = true,
			text = plan.title,
		},
	}
	for _, action in ipairs(plan.actions or {}) do
		local callback = contextActionCallback(plan, action)
		if callback then
			menuItems[#menuItems + 1] = {
				text = contextActionLabel(action),
				func = callback,
			}
		end
	end
	return GF.RowContextMenu:ShowMenu(menuItems, { owner = owner }) == true
end

local function isUnitMenuRestricted()
	if nativeUnitMenuRestrictionPending then
		return true
	end
	if type(InCombatLockdown) ~= "function" then
		return true
	end
	local ok, restricted = pcall(InCombatLockdown)
	return not ok or restricted == true
end

local function appendNativePlayerActions(
	rootDescription,
	playerName,
	classFile,
	isSelf,
	copyPlayerName)
	if not playerName
		or type(isSelf) ~= "boolean"
		or not (GF.UI
			and type(GF.UI.ShowCharacterNameCopyDialog) == "function")
		or not (rootDescription
			and type(rootDescription.CreateButton) == "function")
	then
		return
	end
	local plan = contextActionPlan(
		playerName,
		classFile,
		isSelf,
		copyPlayerName)
	if not plan then
		return
	end
	if type(rootDescription.CreateDivider) == "function" then
		rootDescription:CreateDivider()
	end
	if type(rootDescription.CreateTitle) == "function" then
		rootDescription:CreateTitle(plan.title)
	end
	for _, action in ipairs(plan.actions or {}) do
		local callback = contextActionCallback(plan, action)
		if callback then
			rootDescription:CreateButton(
				contextActionLabel(action),
				callback)
		end
	end
end

local function modifyNativePlayerMenu(_, rootDescription, contextData)
	if nativeUnitMenuRegistrationDepth > 0
		or isUnitMenuRestricted()
		or not menuEnhancementIsEnabled()
	then
		return
	end
	local playerName, classFile, isSelf, copyPlayerName = resolveContextPlayer(
		contextData,
		true)
	appendNativePlayerActions(
		rootDescription,
		playerName,
		classFile,
		isSelf,
		copyPlayerName)
end

local function modifyChatPlayerMenu(_, rootDescription, contextData)
	if nativeUnitMenuRegistrationDepth > 0
		or isUnitMenuRestricted()
		or not menuEnhancementIsEnabled()
		or inChatMessagingLockdown()
		or not isAccessibleValue(contextData)
		or type(contextData) ~= "table"
		or readField(contextData, "chatFrame") == nil
	then
		return
	end
	local playerName, classFile, isSelf, copyPlayerName = resolveContextPlayer(
		contextData,
		false)
	appendNativePlayerActions(
		rootDescription,
		playerName,
		classFile,
		isSelf,
		copyPlayerName)
end

function BlacklistMenu:RegisterNativeMenus()
	if self._nativeMenusRegistered then
		return true
	end
	if isUnitMenuRestricted() then
		return false
	end
	if not (Menu and type(Menu.ModifyMenu) == "function") then
		return false
	end
	local handles = type(self._nativeMenuHandles) == "table"
		and self._nativeMenuHandles or {}
	local addedTags = {}
	local function preserveHandles()
		self._nativeMenuHandles = next(handles) and handles or nil
		self._nativeMenusRegistered = false
	end
	local function rollbackAddedHandles()
		for index = #addedTags, 1, -1 do
			local tag = addedTags[index]
			local handle = handles[tag]
			if type(handle) == "table"
				and type(handle.Unregister) == "function"
				and pcall(handle.Unregister)
			then
				handles[tag] = nil
			end
		end
		preserveHandles()
	end
	local function register(tag, callback)
		local existing = handles[tag]
		if type(existing) == "table"
			and type(existing.Unregister) == "function"
		then
			return true
		end
		handles[tag] = nil
		-- Menu.ModifyMenu synchronously invokes the callback against the last
		-- generated description for this tag before returning the new handle.
		-- Suppress only that registration-time replay; normal generated-menu
		-- callbacks run after this depth has been restored.
		local previousRegistrationDepth = nativeUnitMenuRegistrationDepth
		nativeUnitMenuRegistrationDepth = previousRegistrationDepth + 1
		local ok, handle = pcall(Menu.ModifyMenu, tag, callback)
		nativeUnitMenuRegistrationDepth = previousRegistrationDepth
		if not ok
			or type(handle) ~= "table"
			or type(handle.Unregister) ~= "function"
		then
			return false
		end
		handles[tag] = handle
		addedTags[#addedTags + 1] = tag
		return true
	end
	for _, tag in ipairs(NATIVE_PLAYER_MENU_TAGS) do
		if not register(tag, modifyNativePlayerMenu) then
			rollbackAddedHandles()
			return false
		end
	end
	if not register("MENU_UNIT_FRIEND", modifyChatPlayerMenu) then
		rollbackAddedHandles()
		return false
	end
	self._nativeMenuHandles = handles
	self._nativeMenusRegistered = true
	return true
end

function BlacklistMenu:UnregisterNativeMenus()
	local handles = self._nativeMenuHandles
	self._nativeMenusRegistered = false
	if type(handles) ~= "table" then
		self._nativeMenuHandles = nil
		return true
	end
	local unregistered = true
	for tag, handle in pairs(handles) do
		if type(handle) == "table"
			and type(handle.Unregister) == "function"
		then
			if pcall(handle.Unregister) then
				handles[tag] = nil
			else
				unregistered = false
			end
		else
			handles[tag] = nil
			unregistered = false
		end
	end
	self._nativeMenuHandles = next(handles) and handles or nil
	return unregistered
end

local function supportsCombatRestrictionLifecycle()
	if not (C_EventUtils
		and type(C_EventUtils.IsEventValid) == "function"
		and Enum
		and Enum.AddOnRestrictionType
		and Enum.AddOnRestrictionType.Combat ~= nil
		and Enum.AddOnRestrictionState
		and Enum.AddOnRestrictionState.Inactive ~= nil
		and Enum.AddOnRestrictionState.Activating ~= nil)
	then
		return false
	end
	local ok, valid = pcall(
		C_EventUtils.IsEventValid,
		"ADDON_RESTRICTION_STATE_CHANGED")
	return ok and valid == true
end

local function closeOpenNativeMenus()
	if not (Menu and type(Menu.GetManager) == "function") then
		return
	end
	local ok, manager = pcall(Menu.GetManager)
	if ok and manager and type(manager.CloseMenus) == "function" then
		pcall(manager.CloseMenus, manager)
	end
end

function BlacklistMenu:InstallNativeMenuCombatLifecycle()
	if self._nativeMenuCombatFrame then
		return true
	end
	if type(CreateFrame) ~= "function" then
		return false
	end
	local frame = CreateFrame("Frame")
	local usesRestrictionEvent = supportsCombatRestrictionLifecycle()
	if usesRestrictionEvent then
		frame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
	else
		frame:RegisterEvent("PLAYER_REGEN_DISABLED")
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	end
	frame:SetScript("OnEvent", function(_, event, restrictionType, state)
		if event == "ADDON_RESTRICTION_STATE_CHANGED" then
			if restrictionType ~= Enum.AddOnRestrictionType.Combat then
				return
			end
			if state == Enum.AddOnRestrictionState.Activating then
				nativeUnitMenuRestrictionPending = true
				-- Keep the modifier handles stable across combat. Re-registering a
				-- Menu.ModifyMenu callback immediately replays it against Blizzard's
				-- last generated description, which can carry addon ownership into
				-- the next protected unit-menu action. The callback-level lockdown
				-- guard suppresses injection while restricted; closing here discards
				-- any menu that was generated before the restriction activated.
				closeOpenNativeMenus()
			elseif state == Enum.AddOnRestrictionState.Inactive then
				nativeUnitMenuRestrictionPending = false
				if not BlacklistMenu._nativeMenusRegistered then
					-- This path is only needed when the addon initialized while already
					-- restricted and therefore could not perform its one-time install.
					BlacklistMenu:RegisterNativeMenus()
				end
			else
				nativeUnitMenuRestrictionPending = true
			end
		elseif event == "PLAYER_REGEN_DISABLED" then
			nativeUnitMenuRestrictionPending = true
			closeOpenNativeMenus()
		elseif event == "PLAYER_REGEN_ENABLED" then
			nativeUnitMenuRestrictionPending = false
			if not BlacklistMenu._nativeMenusRegistered then
				BlacklistMenu:RegisterNativeMenus()
			end
		end
	end)
	self._nativeMenuUsesRestrictionEvent = usesRestrictionEvent
	self._nativeMenuCombatFrame = frame
	return true
end

local function armNativeUnitMenu(
	data,
	button,
	mouseButton,
	unitOverride,
	expectedNameOverride)
	if mouseButton ~= "RightButton"
		or not (button and type(button.SetAttribute) == "function")
	then
		return false
	end
	if isUnitMenuRestricted() then
		-- InsecureActionButtonTemplate suppresses its togglemenu action during
		-- combat. Open only GroupFinder's non-protected menu and do not write any
		-- action attributes while locked down.
		return showRosterContextMenu(
			data,
			button,
			mouseButton,
			unitOverride,
			expectedNameOverride)
	end
	button:SetAttribute("*type2", nil)
	button:SetAttribute("unit", nil)
	local unit = resolveUnitMenuTarget(
		data,
		unitOverride,
		expectedNameOverride)
	if not unit then
		return false
	end
	button:SetAttribute("unit", unit)
	button:SetAttribute("*type2", "togglemenu")
	return true
end

function BlacklistMenu:ShowRosterContextMenu(data, owner, mouseButton)
	return showRosterContextMenu(data, owner, mouseButton)
end

function BlacklistMenu:ShowCurrentCharacterContextMenu(data, owner, mouseButton)
	local expectedName = readField(data, "fullName")
		or readField(data, "key")
		or readField(data, "name")
	return showRosterContextMenu(
		data,
		owner,
		mouseButton,
		"player",
		expectedName)
end

function BlacklistMenu:HandleRosterContextMenuClick(data, button, mouseButton)
	return armNativeUnitMenu(data, button, mouseButton)
end

function BlacklistMenu:HandleCurrentCharacterContextMenuClick(
	data,
	button,
	mouseButton)
	local expectedName = readField(data, "fullName")
		or readField(data, "key")
		or readField(data, "name")
	return armNativeUnitMenu(
		data,
		button,
		mouseButton,
		"player",
		expectedName)
end

function BlacklistMenu:Init()
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if not self:InstallNativeMenuCombatLifecycle() then
		return false
	end
	if isUnitMenuRestricted() then
		return true
	end
	return self:RegisterNativeMenus()
end
