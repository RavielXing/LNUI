local _, GF = ...

GF.MythicPlusTeleportDialog = GF.MythicPlusTeleportDialog or {}
local Dialog = GF.MythicPlusTeleportDialog
local UI = GF.MythicPlusUI

local DIALOG_NAME = "GroupFinderAddonMythicPlusTeleportPreviewDialog"
local DIALOG_WIDTH = 480
local DIALOG_HEIGHT = 210
local BUTTON_WIDTH = GF.PANEL_BUTTON_STANDARD_W
local BUTTON_HEIGHT = GF.MYTHIC_PLUS_ACTION_BUTTON_HEIGHT
local BUTTON_GAP = 36
local BUTTON_BOTTOM_OFFSET = 26
local BACKGROUND_ALPHA = 0.82
local BACKGROUND_LEFT_INSET = 6
local TITLE_OFFSET_Y = 1
local MESSAGE_INSET_X = 32
local MESSAGE_TOP_OFFSET = -58
local MESSAGE_HEIGHT = 72
local MESSAGE_LINE_SPACING = 4
local MAIN_WINDOW_ALPHA = 0.64

local function styleFontString(fontString, template)
	if fontString and GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template or "GameFontNormal")
	end
end

local function createDialogButton(parent, name, secure)
	local button = CreateFrame(
		"Button",
		name,
		parent,
		secure and "InsecureActionButtonTemplate" or nil)
	button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)

	local label = GF.UI.CreateFontString(
		button,
		"OVERLAY",
		"GameFontNormal")
	label:SetPoint("CENTER")
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")
	label._gfFontSizeOverride = 15
	styleFontString(label, "GameFontNormal")
	button.Label = label
	UI.ApplyMythicPlusButtonSkin(button, {
		label = label,
	})
	return button
end

local function getMainWindow()
	local mainWindow = GF.MainFrame and GF.MainFrame.frame
	if mainWindow and mainWindow.SetAlpha then
		return mainWindow
	end
	return nil
end

local function setMainWindowDimmed(frame, dimmed)
	local mainWindow = getMainWindow()
	if not mainWindow then
		return
	end
	if dimmed then
		if mainWindow.IsShown and not mainWindow:IsShown() then
			return
		end
		if frame._gfPreviousMainAlpha == nil then
			frame._gfPreviousMainAlpha = mainWindow.GetAlpha
				and mainWindow:GetAlpha() or 1
		end
		mainWindow:SetAlpha(MAIN_WINDOW_ALPHA)
		return
	end
	if frame._gfPreviousMainAlpha == nil then
		return
	end
	local previousAlpha = tonumber(frame._gfPreviousMainAlpha) or 1
	frame._gfPreviousMainAlpha = nil
	mainWindow:SetAlpha(previousAlpha)
end

local function addToSpecialFrames()
	if type(UISpecialFrames) ~= "table" then
		return
	end
	for _, frameName in ipairs(UISpecialFrames) do
		if frameName == DIALOG_NAME then
			return
		end
	end
	table.insert(UISpecialFrames, DIALOG_NAME)
end

local function clearFollowParticipants(frame)
	frame._gfParticipants = {}
	frame._gfParticipantOrder = {}
	frame._gfTimeoutTicket = (tonumber(frame._gfTimeoutTicket) or 0) + 1
end

local function applyDialogFrameStyle(frame)
	if frame.Bg and frame.Bg.Hide then
		frame.Bg:Hide()
	end
	if frame.Inset and frame.Inset.Hide then
		frame.Inset:Hide()
	end

	frame.BackgroundPieces = frame.BackgroundPieces or {}
	for index = 1, 3 do
		local texture = frame.BackgroundPieces[index]
		if not texture then
			texture = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
			frame.BackgroundPieces[index] = texture
		end
		texture:ClearAllPoints()
		texture:SetDrawLayer("BACKGROUND", -8)
		texture:SetColorTexture(0, 0, 0, BACKGROUND_ALPHA)
		texture:Show()
	end

	local cornerRadius = 1
	local inset = 2
	local top = frame.BackgroundPieces[1]
	top:SetPoint(
		"TOPLEFT",
		frame,
		"TOPLEFT",
		BACKGROUND_LEFT_INSET + cornerRadius,
		-inset)
	top:SetPoint(
		"TOPRIGHT",
		frame,
		"TOPRIGHT",
		-(inset + cornerRadius),
		-inset)
	top:SetHeight(cornerRadius)

	local middle = frame.BackgroundPieces[2]
	middle:SetPoint(
		"TOPLEFT",
		frame,
		"TOPLEFT",
		BACKGROUND_LEFT_INSET,
		-(inset + cornerRadius))
	middle:SetPoint(
		"BOTTOMRIGHT",
		frame,
		"BOTTOMRIGHT",
		-inset,
		inset + cornerRadius)

	local bottom = frame.BackgroundPieces[3]
	bottom:SetPoint(
		"BOTTOMLEFT",
		frame,
		"BOTTOMLEFT",
		BACKGROUND_LEFT_INSET + cornerRadius,
		inset)
	bottom:SetPoint(
		"BOTTOMRIGHT",
		frame,
		"BOTTOMRIGHT",
		-(inset + cornerRadius),
		inset)
	bottom:SetHeight(cornerRadius)

	if ButtonFrameTemplate_HidePortrait then
		pcall(ButtonFrameTemplate_HidePortrait, frame)
	end
	if ButtonFrameTemplate_HideButtonBar then
		pcall(ButtonFrameTemplate_HideButtonBar, frame)
	end
	if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
		pcall(
			NineSliceUtil.ApplyLayoutByName,
			frame,
			"ButtonFrameTemplateNoPortrait")
	end

	local titleText = frame.TitleText
		or (frame.TitleContainer and frame.TitleContainer.TitleText)
	if titleText then
		titleText:SetTextColor(1, 0.82, 0, 1)
		titleText._gfFontSizeOverride = 16
		titleText._gfFontFlagsOverride = "OUTLINE"
		styleFontString(titleText, "GameFontNormal")
		if not titleText._gfTeleportBasePoint then
			titleText._gfTeleportBasePoint = { titleText:GetPoint(1) }
		end
		local point = titleText._gfTeleportBasePoint
		if point and point[1] then
			titleText:ClearAllPoints()
			titleText:SetPoint(
				point[1],
				point[2],
				point[3],
				point[4] or 0,
				(point[5] or 0) + TITLE_OFFSET_Y)
		end
	end
	frame.TitleLabel = titleText
end

local function centerDialog(frame)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

function Dialog:EnsureFrame()
	if self.frame then
		return self.frame
	end

	local frame = CreateFrame(
		"Frame",
		DIALOG_NAME,
		UIParent,
		"ButtonFrameTemplate")
	frame:SetSize(DIALOG_WIDTH, DIALOG_HEIGHT)
	centerDialog(frame)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	frame:SetScript("OnShow", function(self)
		setMainWindowDimmed(self, true)
	end)
	frame:SetScript("OnHide", function(self)
		setMainWindowDimmed(self, false)
		local followMode = self._gfFollowMode == true
		local challengeModeID = self.challengeModeID
		local hideReason = self._gfHideReason or "dismissed"
		if followMode and challengeModeID
			and hideReason ~= "cancelled"
			and hideReason ~= "expired"
			and hideReason ~= "preview"
		then
			local followService = GF.MythicPlusTeleportFollowService
			if followService and followService.OnDialogDismissed then
				pcall(
					followService.OnDialogDismissed,
					followService,
					challengeModeID)
			end
		end
		self._gfHideReason = nil
		self._gfFollowMode = nil
		clearFollowParticipants(self)
	end)
	applyDialogFrameStyle(frame)
	if frame.CloseButton then
		frame.CloseButton:SetScript("OnClick", function()
			frame._gfHideReason = "closed"
			frame:Hide()
		end)
	end

	local message = GF.UI.CreateFontString(
		frame,
		"OVERLAY",
		"GameFontHighlight")
	message:SetPoint(
		"TOPLEFT",
		frame,
		"TOPLEFT",
		MESSAGE_INSET_X,
		MESSAGE_TOP_OFFSET)
	message:SetPoint(
		"TOPRIGHT",
		frame,
		"TOPRIGHT",
		-MESSAGE_INSET_X,
		MESSAGE_TOP_OFFSET)
	message:SetHeight(MESSAGE_HEIGHT)
	message:SetJustifyH("CENTER")
	message:SetJustifyV("MIDDLE")
	message:SetWordWrap(true)
	if message.SetSpacing then
		message:SetSpacing(MESSAGE_LINE_SPACING)
	end
	message._gfFontSizeOverride = 18
	message._gfFontFlagsOverride = "OUTLINE"
	styleFontString(message, "GameFontHighlight")
	frame.Message = message

	local prompt = GF.UI.CreateFontString(
		frame,
		"OVERLAY",
		"GameFontNormal")
	prompt:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -4)
	prompt:SetPoint("TOPRIGHT", message, "BOTTOMRIGHT", 0, -4)
	prompt:SetHeight(20)
	prompt:SetJustifyH("CENTER")
	prompt:SetJustifyV("MIDDLE")
	prompt._gfFontSizeOverride = 16
	prompt._gfFontFlagsOverride = "OUTLINE"
	styleFontString(prompt, "GameFontNormal")
	prompt:Hide()
	frame.Prompt = prompt

	local accept = createDialogButton(
		frame,
		DIALOG_NAME .. "AcceptButton",
		true)
	accept:SetPoint(
		"BOTTOM",
		frame,
		"BOTTOM",
		-((BUTTON_WIDTH + BUTTON_GAP) / 2),
		BUTTON_BOTTOM_OFFSET)
	accept:SetAttribute("useOnKeyDown", false)
	accept:RegisterForClicks("AnyUp", "AnyDown")
	accept:HookScript("OnClick", function(_, _, down)
		if UI.IsTeleportCombatLocked() or down == true then
			return
		end
		-- Confirmation happens on release so the pressed state remains visible
		-- while held and dragging away can still cancel the click.
		frame._gfHideReason = "accepted"
		frame:Hide()
	end)
	accept:HookScript("OnEnter", function(self)
		local service = GF.MythicPlusTeleportService
		local destination = self.gfTeleportDesiredChallengeModeID
			or self.gfTeleportEffectiveChallengeModeID
		if not (destination and service and service.AddTooltipLines) then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		service:AddTooltipLines(GameTooltip, destination, {
			secureReady = self.gfTeleportSecureReady == true,
		})
		GameTooltip:Show()
	end)
	accept:HookScript("OnLeave", GameTooltip_Hide)
	UI.InstallTeleportCombatFeedback(accept, function(button)
		button:SetAlpha(UI.IsTeleportCombatLocked() and 0.55 or 1)
	end)
	frame.AcceptButton = accept

	local decline = createDialogButton(
		frame,
		DIALOG_NAME .. "DeclineButton")
	decline:SetPoint(
		"BOTTOM",
		frame,
		"BOTTOM",
		(BUTTON_WIDTH + BUTTON_GAP) / 2,
		BUTTON_BOTTOM_OFFSET)
	decline:SetScript("OnClick", function()
		frame._gfHideReason = "declined"
		frame:Hide()
	end)
	frame.DeclineButton = decline

	addToSpecialFrames()
	frame:Hide()
	self.frame = frame
	return frame
end

local function normalizeParticipantKey(value)
	value = tostring(value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:match("^%s*(.-)%s*$") or ""
	return value ~= "" and value:lower() or nil
end

local function getCharacterShortName(value)
	value = tostring(value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:match("^%s*(.-)%s*$") or ""
	local shortName = value:match("^([^-]+)%-")
	return shortName and shortName ~= "" and shortName or value
end

local function setSecureDestination(frame, challengeModeID)
	local button = frame and frame.AcceptButton
	local service = GF.MythicPlusTeleportService
	if not (button and service and service.ApplySecureButton) then
		return false
	end
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	local ready, pending = service:ApplySecureButton(button, challengeModeID)
	return ready == true and pending ~= true
end

local function refreshFollowMessage(frame)
	local order = frame and frame._gfParticipantOrder or {}
	local participants = frame and frame._gfParticipants or {}
	local first = order[1] and participants[order[1]] or nil
	if not first then
		return false
	end
	local L = GF.L or {}
	local sender = UI.ColorText(
		getCharacterShortName(
			first.senderName
				or L.MPLUS_CURRENT_CHARACTER
				or "Current Character"),
		UI.GetClassColorCode(first.classFile))
	if #order > 1 then
		sender = string.format(
			L.MPLUS_TELEPORT_DIALOG_MULTI_SENDER_FMT or "%s 等 %d 人",
			sender,
			#order)
	end
	local dungeon = UI.ColorText(
		frame.dungeonName or L.MPLUS_UNKNOWN_DUNGEON or "Unknown Dungeon",
		"ff58d7ff")
	local prompt = UI.ColorText(
		L.MPLUS_TELEPORT_DIALOG_FOLLOW_PROMPT or "Follow the teleport?",
		"ffffd100")
	frame.Message:SetText(string.format(
		L.MPLUS_TELEPORT_DIALOG_MESSAGE_FMT
			or "%s is teleporting to [%s]. %s",
		sender,
		dungeon,
		prompt))
	return true
end

local function scheduleFollowTimeout(frame)
	if not (frame and C_Timer and C_Timer.After) then
		return
	end
	local nextExpiry
	for _, participant in pairs(frame._gfParticipants or {}) do
		local expiresAt = tonumber(participant and participant.expiresAt)
		if expiresAt and (not nextExpiry or expiresAt < nextExpiry) then
			nextExpiry = expiresAt
		end
	end
	if not nextExpiry then
		return
	end
	frame._gfTimeoutTicket = (tonumber(frame._gfTimeoutTicket) or 0) + 1
	local ticket = frame._gfTimeoutTicket
	local delay = math.max(0.1, nextExpiry - (GetTime and GetTime() or 0))
	C_Timer.After(delay, function()
		if not (frame._gfTimeoutTicket == ticket and frame._gfFollowMode
			and frame.IsShown and frame:IsShown())
		then
			return
		end
		local currentTime = GetTime and GetTime() or 0
		for index = #(frame._gfParticipantOrder or {}), 1, -1 do
			local key = frame._gfParticipantOrder[index]
			local participant = frame._gfParticipants and frame._gfParticipants[key]
			if not participant or (tonumber(participant.expiresAt) or 0) <= currentTime then
				if frame._gfParticipants then
					frame._gfParticipants[key] = nil
				end
				table.remove(frame._gfParticipantOrder, index)
			end
		end
		if not refreshFollowMessage(frame) then
			frame._gfHideReason = "expired"
			frame:Hide()
			return
		end
		scheduleFollowTimeout(frame)
	end)
end

function Dialog:ShowPreview(snapshot)
	if InCombatLockdown and InCombatLockdown() then
		return false, "combat"
	end
	if type(snapshot) ~= "table"
		or type(snapshot.dungeonName) ~= "string"
		or snapshot.dungeonName == ""
	then
		return false, "missing-data"
	end

	local frame = self:EnsureFrame()
	setSecureDestination(frame, nil)
	clearFollowParticipants(frame)
	frame._gfFollowMode = nil
	frame._gfHideReason = nil
	local L = GF.L or {}
	local title = L.MPLUS_TELEPORT_DIALOG_TITLE or "Follow Teleport"
	if frame.SetTitle then
		pcall(frame.SetTitle, frame, title)
	end
	if frame.TitleLabel then
		frame.TitleLabel:SetText(title)
	end
	frame.AcceptButton.Label:SetText(
		L.MPLUS_TELEPORT_DIALOG_ACCEPT or "Yes")
	frame.DeclineButton.Label:SetText(
		L.MPLUS_TELEPORT_DIALOG_DECLINE or "No")

	local sender = UI.ColorText(
		getCharacterShortName(
			snapshot.senderName
				or L.MPLUS_CURRENT_CHARACTER
				or "Current Character"),
		UI.GetClassColorCode(snapshot.classFile))
	local dungeon = UI.ColorText(snapshot.dungeonName, "ff58d7ff")
	local prompt = UI.ColorText(
		L.MPLUS_TELEPORT_DIALOG_FOLLOW_PROMPT or "Follow the teleport?",
		"ffffd100")
	frame.Message:SetText(string.format(
		L.MPLUS_TELEPORT_DIALOG_MESSAGE_FMT
			or "%s is teleporting to [%s]. %s",
		sender,
		dungeon,
		prompt))
	if frame.Message.SetSpacing then
		frame.Message:SetSpacing(MESSAGE_LINE_SPACING)
	end
	frame.Prompt:Hide()
	frame.mapID = tonumber(snapshot.mapID)
	frame.dungeonName = snapshot.dungeonName
	frame.senderName = snapshot.senderName
	frame.classFile = snapshot.classFile
	frame.challengeModeID = tonumber(snapshot.challengeModeID or snapshot.mapID)
	centerDialog(frame)
	frame:Show()
	return true
end

function Dialog:ShowFollow(snapshot)
	if InCombatLockdown and InCombatLockdown() then
		return false, "combat"
	end
	if type(snapshot) ~= "table" then
		return false, "missing-data"
	end
	local challengeModeID = tonumber(
		snapshot.challengeModeID or snapshot.mapID)
	if not challengeModeID then
		return false, "missing-data"
	end
	local dungeon = GF.MythicPlusSeason and GF.MythicPlusSeason.GetByChallengeModeID
		and GF.MythicPlusSeason:GetByChallengeModeID(challengeModeID) or nil
	local dungeonName = snapshot.dungeonName or (dungeon and dungeon.name)
	if type(dungeonName) ~= "string" or dungeonName == "" then
		return false, "missing-data"
	end

	local frame = self:EnsureFrame()
	if not setSecureDestination(frame, challengeModeID) then
		return false, "unavailable"
	end
	local sameDestination = frame._gfFollowMode and frame:IsShown()
		and frame.challengeModeID == challengeModeID
	if not sameDestination then
		clearFollowParticipants(frame)
	end

	local senderName = tostring(snapshot.senderName or "")
	local participantKey = normalizeParticipantKey(senderName)
	if not participantKey then
		return false, "missing-sender"
	end
	local timeoutSeconds = math.max(
		5,
		math.min(60, tonumber(snapshot.timeoutSeconds) or 45))
	local participant = frame._gfParticipants[participantKey]
	if not participant then
		participant = {}
		frame._gfParticipants[participantKey] = participant
		frame._gfParticipantOrder[#frame._gfParticipantOrder + 1] = participantKey
	end
	participant.senderName = senderName
	participant.classFile = snapshot.classFile or participant.classFile
	participant.castGUID = snapshot.castGUID or participant.castGUID
	participant.expiresAt = (GetTime and GetTime() or 0) + timeoutSeconds

	local L = GF.L or {}
	local title = L.MPLUS_TELEPORT_DIALOG_TITLE or "Follow Teleport"
	if frame.SetTitle then
		pcall(frame.SetTitle, frame, title)
	end
	if frame.TitleLabel then
		frame.TitleLabel:SetText(title)
	end
	frame.AcceptButton.Label:SetText(
		L.MPLUS_TELEPORT_DIALOG_ACCEPT or "Yes")
	frame.DeclineButton.Label:SetText(
		L.MPLUS_TELEPORT_DIALOG_DECLINE or "No")
	frame._gfFollowMode = true
	frame._gfHideReason = nil
	frame.challengeModeID = challengeModeID
	frame.mapID = tonumber(snapshot.mapID)
	frame.dungeonName = dungeonName
	frame.senderName = senderName
	frame.classFile = snapshot.classFile
	frame.Prompt:Hide()
	if not refreshFollowMessage(frame) then
		return false, "missing-data"
	end
	centerDialog(frame)
	frame:Show()
	scheduleFollowTimeout(frame)
	return true
end

function Dialog:CancelFollow(senderName, challengeModeID, castGUID)
	local frame = self.frame
	challengeModeID = tonumber(challengeModeID)
	if not (frame and frame._gfFollowMode and frame:IsShown()
		and frame.challengeModeID == challengeModeID)
	then
		return false
	end
	local targetKey
	if castGUID ~= nil then
		local normalizedCastGUID = tostring(castGUID)
		for key, participant in pairs(frame._gfParticipants or {}) do
			if tostring(participant.castGUID or "") == normalizedCastGUID then
				targetKey = key
				break
			end
		end
	end
	targetKey = targetKey or normalizeParticipantKey(senderName)
	if not (targetKey and frame._gfParticipants[targetKey]) then
		return false
	end
	frame._gfParticipants[targetKey] = nil
	for index = #(frame._gfParticipantOrder or {}), 1, -1 do
		if frame._gfParticipantOrder[index] == targetKey then
			table.remove(frame._gfParticipantOrder, index)
			break
		end
	end
	if not refreshFollowMessage(frame) then
		frame._gfHideReason = "cancelled"
		frame:Hide()
		return true
	end
	scheduleFollowTimeout(frame)
	return true
end

function Dialog:PruneFollowParticipants(isCurrentSender)
	local frame = self.frame
	if not (frame and frame._gfFollowMode and frame:IsShown()
		and type(isCurrentSender) == "function")
	then
		return false
	end
	local removed = false
	for index = #(frame._gfParticipantOrder or {}), 1, -1 do
		local key = frame._gfParticipantOrder[index]
		local participant = frame._gfParticipants
			and frame._gfParticipants[key]
		local keep = false
		if participant then
			local ok, result = pcall(
				isCurrentSender,
				participant.senderName)
			keep = ok and result == true
		end
		if not keep then
			if frame._gfParticipants then
				frame._gfParticipants[key] = nil
			end
			table.remove(frame._gfParticipantOrder, index)
			removed = true
		end
	end
	if not removed then
		return false
	end
	if not refreshFollowMessage(frame) then
		frame._gfHideReason = "cancelled"
		frame:Hide()
		return true
	end
	scheduleFollowTimeout(frame)
	return true
end

function Dialog:Hide(reason)
	if self.frame then
		if type(reason) == "string" and reason ~= "" then
			self.frame._gfHideReason = reason
		end
		self.frame:Hide()
	end
end
