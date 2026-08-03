local _, GF = ...

GF.MythicPlusTeleportDialog = GF.MythicPlusTeleportDialog or {}
local Dialog = GF.MythicPlusTeleportDialog
local UI = GF.MythicPlusUI
local SHARED_DIALOG_STYLE = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}

local DIALOG_NAME = "GroupFinderAddonMythicPlusTeleportPreviewDialog"
local DIALOG_WIDTH = SHARED_DIALOG_STYLE.WIDTH or 420
local DIALOG_HEIGHT = SHARED_DIALOG_STYLE.HEIGHT or 176
local DIALOG_LEVEL_OFFSET = SHARED_DIALOG_STYLE.LEVEL_OFFSET or 18
local DIALOG_SCREEN_OFFSET_Y = SHARED_DIALOG_STYLE.SCREEN_OFFSET_Y or 20
local BUTTON_WIDTH = SHARED_DIALOG_STYLE.BUTTON_WIDTH
	or GF.PANEL_BUTTON_STANDARD_W or 72
local BUTTON_HEIGHT = SHARED_DIALOG_STYLE.BUTTON_HEIGHT
	or GF.PANEL_BUTTON_H or 24
local BUTTON_GAP = SHARED_DIALOG_STYLE.BUTTON_GAP or 12
local BUTTON_BOTTOM_OFFSET = SHARED_DIALOG_STYLE.CONTENT_BOTTOM_INSET or 18
local MESSAGE_CENTER_OFFSET_Y =
	SHARED_DIALOG_STYLE.TELEPORT_MESSAGE_CENTER_OFFSET_Y or 4
local MESSAGE_LINE_SPACING = SHARED_DIALOG_STYLE.TELEPORT_TEXT_LINE_GAP or 7
local MESSAGE_FIT_WIDTH = DIALOG_WIDTH
	- ((SHARED_DIALOG_STYLE.CONTENT_INSET_X or 36) * 2)
local MESSAGE_MIN_FONT_SIZE = SHARED_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE or 10
local MAIN_WINDOW_ALPHA = 0.64

local function styleFontString(fontString, template)
	if fontString and GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template or "GameFontNormal")
	end
end

local function styleDialogText(fontString, role)
	if GF.UI.ApplyPlayerContextDialogTextStyle then
		GF.UI.ApplyPlayerContextDialogTextStyle(fontString, role)
		return
	end
	local accent = role == "accent"
	fontString._gfFontSizeOverride = accent
		and (SHARED_DIALOG_STYLE.ACCENT_TEXT_FONT_SIZE or 15)
		or (SHARED_DIALOG_STYLE.PRIMARY_TEXT_FONT_SIZE or 15)
	fontString._gfFontFlagsOverride = ""
	styleFontString(fontString, "GameFontHighlight")
	local color = accent and SHARED_DIALOG_STYLE.ACCENT_TEXT_COLOR
		or SHARED_DIALOG_STYLE.PRIMARY_TEXT_COLOR
	if color and fontString.SetTextColor then
		fontString:SetTextColor(
			color[1] or 1,
			color[2] or 1,
			color[3] or 1,
			color[4] or 1)
	end
end

local function fitDialogText(fontString)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(
			fontString,
			MESSAGE_FIT_WIDTH,
			MESSAGE_MIN_FONT_SIZE)
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
	button.Label = label
	UI.ApplyMythicPlusButtonSkin(button, {
		label = label,
	})
	if GF.UI.ApplyPlayerContextDialogButtonFont then
		GF.UI.ApplyPlayerContextDialogButtonFont(button)
	else
		label._gfFontSizeOverride = SHARED_DIALOG_STYLE.BUTTON_FONT_SIZE or 15
		styleFontString(label, "GameFontNormal")
	end
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

local function activateDialogFrame(frame)
	setMainWindowDimmed(frame, true)
	if GF.UI and GF.UI.RaiseFrame then
		GF.UI.RaiseFrame(frame)
	elseif frame and frame.Raise then
		frame:Raise()
	end
end

local function regionBelongsToFrame(region, targetFrame)
	local depth = 0
	while region and depth < 100 do
		if region == targetFrame then
			return true
		end
		local getParent = region.GetParent
		if type(getParent) ~= "function" then
			return false
		end
		local ok, parent = pcall(getParent, region)
		if not ok or parent == region then
			return false
		end
		region = parent
		depth = depth + 1
	end
	return false
end

local function activateMouseFocus(frame)
	if type(GetMouseFoci) ~= "function" then
		return
	end
	local ok, mouseFoci = pcall(GetMouseFoci)
	if not (ok and type(mouseFoci) == "table") then
		return
	end
	local focus = mouseFoci[1]
	if not focus then
		return
	end
	local mainWindow = getMainWindow()
	if regionBelongsToFrame(focus, frame) then
		activateDialogFrame(frame)
		return
	end
	if mainWindow and regionBelongsToFrame(focus, mainWindow) then
		local mainController = GF.MainFrame
		if mainController and type(mainController.ActivateFocus) == "function" then
			mainController:ActivateFocus()
		else
			setMainWindowDimmed(frame, false)
		end
		return
	end
	local createDrawer = GF.CreateDrawer
	local drawerFrame = createDrawer and createDrawer.frame
	if drawerFrame and regionBelongsToFrame(focus, drawerFrame) then
		-- The drawer owns its own main-window alpha projection. Drop the
		-- teleport snapshot without restoring it before handing off focus.
		frame._gfPreviousMainAlpha = nil
		if type(createDrawer.ActivateDrawer) == "function" then
			createDrawer:ActivateDrawer()
		end
	end
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

local function centerDialog(frame)
	if GF.UI.CenterOnUIParent then
		GF.UI.CenterOnUIParent(frame, DIALOG_SCREEN_OFFSET_Y)
	else
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, DIALOG_SCREEN_OFFSET_Y)
	end
end

function Dialog:EnsureFrame()
	if self.frame then
		return self.frame
	end

	local L = GF.L or {}
	local frame = GF.UI.CreateSatelliteSettingsFrame({
		name = DIALOG_NAME,
		width = DIALOG_WIDTH,
		height = DIALOG_HEIGHT,
		title = L.MPLUS_TELEPORT_DIALOG_TITLE or "Follow Teleport",
		levelOffset = DIALOG_LEVEL_OFFSET,
		backgroundColor = SHARED_DIALOG_STYLE.BACKGROUND_COLOR
			or GF.PLAYER_CONTEXT_DIALOG_BACKGROUND_COLOR,
	})
	centerDialog(frame)
	frame:HookScript("OnShow", function(self)
		setMainWindowDimmed(self, true)
		if self.RegisterEvent then
			self:RegisterEvent("GLOBAL_MOUSE_DOWN")
		end
	end)
	frame:HookScript("OnEvent", function(self, event)
		if event == "GLOBAL_MOUSE_DOWN"
			and (not self.IsShown or self:IsShown())
		then
			activateMouseFocus(self)
		end
	end)
	frame:HookScript("OnMouseDown", function(self)
		activateDialogFrame(self)
	end)
	if frame.gfDragBar then
		frame.gfDragBar:HookScript("OnMouseDown", function()
			activateDialogFrame(frame)
		end)
	end
	frame:HookScript("OnHide", function(self)
		if self.UnregisterEvent then
			self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		end
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
	frame.TitleLabel = frame.systemTitleText or frame.titletext
	if frame.ClosePanelButton then
		frame.ClosePanelButton:SetScript("OnClick", function()
			frame._gfHideReason = "closed"
			frame:Hide()
		end)
	end
	frame.ContentHost = GF.UI.CreatePlayerContextDialogContentHost(frame)

	local message = GF.UI.CreateFontString(
		frame,
		"OVERLAY",
		"GameFontHighlight")
	message:SetPoint(
		"LEFT",
		frame.ContentHost,
		"LEFT",
		0,
		0)
	message:SetPoint(
		"RIGHT",
		frame.ContentHost,
		"RIGHT",
		0,
		0)
	message:SetPoint(
		"BOTTOM",
		frame.ContentHost,
		"CENTER",
		0,
		MESSAGE_CENTER_OFFSET_Y)
	styleDialogText(message, "primary")
	frame.Message = message

	local prompt = GF.UI.CreateFontString(
		frame,
		"OVERLAY",
		"GameFontNormal")
	prompt:SetPoint("LEFT", frame.ContentHost, "LEFT", 0, 0)
	prompt:SetPoint("RIGHT", frame.ContentHost, "RIGHT", 0, 0)
	prompt:SetPoint("TOP", message, "BOTTOM", 0, -MESSAGE_LINE_SPACING)
	styleDialogText(prompt, "accent")
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

function Dialog:ActivateMainFrame()
	local frame = self.frame
	if not (frame and frame.IsShown and frame:IsShown()) then
		return false
	end
	setMainWindowDimmed(frame, false)
	return true
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

local function setDialogMessage(frame, sender, dungeon)
	local L = GF.L or {}
	frame.Message:SetText(string.format(
		L.MPLUS_TELEPORT_DIALOG_ROUTE_FMT
			or "%s is teleporting to [%s].",
		sender,
		dungeon))
	frame.Prompt:SetText(
		L.MPLUS_TELEPORT_DIALOG_FOLLOW_PROMPT or "Follow the teleport?")
	fitDialogText(frame.Message)
	fitDialogText(frame.Prompt)
	frame.Prompt:Show()
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
	setDialogMessage(frame, sender, dungeon)
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
	setDialogMessage(frame, sender, dungeon)
	frame.mapID = tonumber(snapshot.mapID)
	frame.dungeonName = snapshot.dungeonName
	frame.senderName = snapshot.senderName
	frame.classFile = snapshot.classFile
	frame.challengeModeID = tonumber(snapshot.challengeModeID or snapshot.mapID)
	centerDialog(frame)
	frame:Show()
	activateDialogFrame(frame)
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
	if not refreshFollowMessage(frame) then
		return false, "missing-data"
	end
	centerDialog(frame)
	frame:Show()
	if not sameDestination then
		activateDialogFrame(frame)
	end
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
