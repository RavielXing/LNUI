local _, GF = ...

GF.SettingsTacticalPage = GF.SettingsTacticalPage or {}
local Page = GF.SettingsTacticalPage
local ROW_STYLE = GF.LIST_ROW_STYLE or {}
local ROW_CONTENT_OFFSET_Y = ROW_STYLE.contentOffsetY or -2
local Presenter = assert(
	GF.SettingsPresenter,
	"SettingsPresenter must load before SettingsTacticalPage"
)

local TACTICAL_UNSAVED_POPUP = "GF_SETTINGS_TACTICAL_UNSAVED"
local WHITE = GF.WHITE_TEXTURE
local DD_W = GF.SETTINGS_DROPDOWN_W or 260
local DD_H = GF.SETTINGS_DROPDOWN_H or 26
local TITLE_TEXT_SIZE = 16
local META_TEXT_SIZE = 12
local TACTICAL_MAX_LINES =
	GF.MYTHIC_PLUS_TACTICAL_MAX_MESSAGES or 5
local TACTICAL_INPUT_MAX_BYTES =
	GF.MYTHIC_PLUS_TACTICAL_INPUT_MAX_BYTES or 255
local TACTICAL_EDITOR_ROW_GAP = 6
local TACTICAL_HINT_H = 34
local TACTICAL_MANUAL_CONTROL_W = 150
local TACTICAL_MANUAL_DROPDOWN_W = TACTICAL_MANUAL_CONTROL_W
local TACTICAL_MANUAL_CONTROL_GAP = 38
local TACTICAL_PENDING_ATLAS = "UI-LFG-PendingMark"
local TACTICAL_READY_ATLAS = "UI-LFG-ReadyMark"

local TACTICAL_CHANNEL_FALLBACK_COLORS = {
	PARTY = { 0.67, 0.67, 1 },
	RAID = { 1, 0.50, 0 },
	INSTANCE_CHAT = { 1, 0.50, 0 },
	RAID_WARNING = { 1, 0.28, 0.04 },
}

local LAYOUT = {
	panelH = 328,
	listW = 240,
	rowH = 40,
	panelGap = 12,
	scrollInsetY = 4,
	scrollOverflowTolerance = 1,
	listInnerInsetX = 4,
	rowLabelInsetX = 56,
	rowStatusW = 44,
	rowStatusInsetR = 12,
	rowStatusIconSize = 32,
	editorInset = 18,
	rowBaseColor =
		GF.BROWSE_ROW_NORMAL_COLOR or { 1, 1, 1, 1 },
	rowSelectedColor =
		GF.BROWSE_ROW_SELECTED_COLOR
			or { 1, 0.9, 0.08, 0.82 },
	rowHoverColor =
		GF.BROWSE_ROW_HOVER_COLOR
			or { 1, 0.74, 0.18, 0.13 },
}

local dependencies = {}
local settingsPanel

local function isTacticalLinkTarget(box, requireFocus)
	return box
		and box.IsVisible and box:IsVisible()
		and box.IsEnabled and box:IsEnabled()
		and box.Insert
		and (not requireFocus
			or box.HasFocus and box:HasFocus())
end

local function getTacticalLinkTarget()
	for _, box in ipairs(
		settingsPanel and settingsPanel.tacticalMessageBoxes or {})
	do
		if isTacticalLinkTarget(box, true) then
			return box
		end
	end
	local pending = settingsPanel
		and settingsPanel._tacticalPendingLinkTarget
	if isTacticalLinkTarget(pending, false) then
		return pending
	end
	return nil
end

local function getTacticalLinkIdentity(link)
	if type(link) ~= "string" then
		return nil
	end
	return link:match("|h(%b[])|h")
		or link:match("|H([^|]+)|h")
		or link
end

local function tacticalLinkHandledThisTurn(box, link)
	local marker = Page._tacticalLinkTurnMarker
	if not marker or marker.box ~= box then
		return false
	end
	return link == nil
		or marker.identity == getTacticalLinkIdentity(link)
end

local function markTacticalLinkHandled(box, link)
	local marker = {
		box = box,
		identity = getTacticalLinkIdentity(link),
	}
	Page._tacticalLinkTurnMarker = marker
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, function()
			if Page._tacticalLinkTurnMarker == marker then
				Page._tacticalLinkTurnMarker = nil
			end
		end)
	end
end

local function updateTacticalByteCounter(box, rejected)
	local counter = box and box._gfTacticalByteCounter
	if not counter then
		return 0
	end
	local usedBytes = #(box:GetText() or "")
	counter:SetText(string.format(
		"%d/%d",
		usedBytes,
		TACTICAL_INPUT_MAX_BYTES
	))
	if rejected or usedBytes >= TACTICAL_INPUT_MAX_BYTES then
		counter:SetTextColor(1, 0.24, 0.20, 1)
	elseif usedBytes >= math.floor(TACTICAL_INPUT_MAX_BYTES * 0.8) then
		counter:SetTextColor(1, 0.72, 0.18, 1)
	else
		counter:SetTextColor(0.48, 0.46, 0.42, 1)
	end
	return usedBytes
end

local function showTacticalLinkByteLimit(box)
	updateTacticalByteCounter(box, true)
	local L = GF.L or {}
	local message = L.SET_MPLUS_TACTICAL_LINK_BYTE_LIMIT
		or "Not enough available bytes to insert the link"
	if type(GF.ShowTopNotice) == "function" then
		GF.ShowTopNotice(message, {
			source = "tactical_link_limit",
			playSound = true,
		})
	end
	if box and box.SetFocus then
		box:SetFocus()
	end
end

local function insertTacticalLink(link)
	if type(link) ~= "string" or link == "" then
		return false
	end
	local box = getTacticalLinkTarget()
	if not box then
		return false
	end
	if tacticalLinkHandledThisTurn(box, link) then
		return false
	end
	local currentText = box:GetText() or ""
	if #currentText + #link > TACTICAL_INPUT_MAX_BYTES then
		markTacticalLinkHandled(box, link)
		showTacticalLinkByteLimit(box)
		return false
	end
	markTacticalLinkHandled(box, link)
	box:Insert(link)
	box:SetFocus()
	return true
end

local function rememberTacticalLinkTarget(owner, box)
	owner._tacticalPendingLinkTarget = box
	owner._tacticalLinkTargetToken =
		(owner._tacticalLinkTargetToken or 0) + 1
end

local function releaseTacticalLinkTarget(owner, box)
	owner._tacticalLinkTargetToken =
		(owner._tacticalLinkTargetToken or 0) + 1
	local token = owner._tacticalLinkTargetToken
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, function()
			if owner._tacticalLinkTargetToken == token
				and owner._tacticalPendingLinkTarget == box
				and not (box.HasFocus and box:HasFocus())
			then
				owner._tacticalPendingLinkTarget = nil
			end
		end)
	else
		owner._tacticalPendingLinkTarget = nil
	end
end

local function getEncounterBossLink(button)
	local buttonLink = button and button.link
	if type(buttonLink) == "string" and buttonLink ~= "" then
		return buttonLink
	end
	if type(EJ_GetEncounterInfo) ~= "function" then
		return nil
	end
	local encounterID = tonumber(button
		and (button.encounterID or button.journalEncounterID))
	if not encounterID
		and button and type(button.GetID) == "function"
	then
		encounterID = tonumber(button:GetID())
	end
	if not encounterID then
		return nil
	end
	local ok, _, _, _, _, link =
		pcall(EJ_GetEncounterInfo, encounterID)
	return ok and type(link) == "string"
		and link ~= "" and link or nil
end

local function handleEncounterJournalLink(button)
	if type(IsModifiedClick) == "function"
		and not IsModifiedClick("CHATLINK")
	then
		return
	end
	local target = getTacticalLinkTarget()
	if not target then
		return
	end
	local activeWindow = ChatFrameUtil
		and type(ChatFrameUtil.GetActiveWindow)
		== "function" and ChatFrameUtil.GetActiveWindow() or nil
	if not activeWindow
		and not tacticalLinkHandledThisTurn(target)
	then
		local link = getEncounterBossLink(button)
		if link then
			if ChatFrameUtil
				and type(ChatFrameUtil.InsertLink) == "function"
			then
				ChatFrameUtil.InsertLink(link)
			elseif type(ChatEdit_InsertLink) == "function" then
				ChatEdit_InsertLink(link)
			end
		end
	end
end

local function ensureTacticalEncounterJournalHooks()
	if Page._tacticalEncounterJournalHooked
		or type(hooksecurefunc) ~= "function"
	then
		return
	end
	local hooked = false
	if type(EncounterJournal_OnClick) == "function" then
		hooksecurefunc(
			"EncounterJournal_OnClick",
			handleEncounterJournalLink
		)
		hooked = true
	end
	if type(EncounterJournalBossButton_OnClick) == "function" then
		hooksecurefunc(
			"EncounterJournalBossButton_OnClick",
			handleEncounterJournalLink
		)
		hooked = true
	end
	if hooked then
		Page._tacticalEncounterJournalHooked = true
		if Page._tacticalEncounterJournalEventFrame then
			Page._tacticalEncounterJournalEventFrame:
				UnregisterEvent("ADDON_LOADED")
		end
		return
	end
	if Page._tacticalEncounterJournalEventFrame
		or type(CreateFrame) ~= "function"
	then
		return
	end
	local eventFrame = CreateFrame("Frame")
	Page._tacticalEncounterJournalEventFrame = eventFrame
	eventFrame:RegisterEvent("ADDON_LOADED")
	eventFrame:SetScript("OnEvent", function(_, _, addonName)
		if addonName == "Blizzard_EncounterJournal" then
			ensureTacticalEncounterJournalHooks()
		end
	end)
end

local function ensureTacticalLinkInsertionHook()
	if Page._tacticalLinkInsertionHooked
		or type(hooksecurefunc) ~= "function"
	then
		return
	end
	local callback = function(link)
		insertTacticalLink(link)
	end
	if ChatFrameUtil
		and type(ChatFrameUtil.InsertLink) == "function"
	then
		hooksecurefunc(ChatFrameUtil, "InsertLink", callback)
	elseif type(ChatEdit_InsertLink) == "function" then
		hooksecurefunc("ChatEdit_InsertLink", callback)
	else
		return
	end
	Page._tacticalLinkInsertionHooked = true
end

local function splitTacticalEditorValue(value)
	value = tostring(value or "")
	value = value:gsub("\r\n", "\n"):gsub("\r", "\n")
	local lines = {}
	local startAt = 1
	for index = 1, TACTICAL_MAX_LINES do
		local newlineAt = value:find("\n", startAt, true)
		lines[index] = newlineAt
			and value:sub(startAt, newlineAt - 1)
			or value:sub(startAt)
		if not newlineAt then
			break
		end
		startAt = newlineAt + 1
	end
	return lines
end

local function getTacticalEditorValue(owner)
	local lines = {}
	for index = 1, TACTICAL_MAX_LINES do
		local box = owner.tacticalMessageBoxes
			and owner.tacticalMessageBoxes[index]
		lines[index] = box and (box:GetText() or "") or ""
	end
	local lastLine = TACTICAL_MAX_LINES
	while lastLine > 0 and lines[lastLine] == "" do
		lastLine = lastLine - 1
	end
	local savedLines = {}
	for index = 1, lastLine do
		savedLines[index] = lines[index]
	end
	return table.concat(savedLines, "\n")
end

local function setTacticalEditorValue(owner, value)
	local lines = splitTacticalEditorValue(value)
	owner._syncingTacticalMessage = true
	for index, box in ipairs(owner.tacticalMessageBoxes or {}) do
		box:SetText(lines[index] or "")
	end
	owner._syncingTacticalMessage = nil
end

local function clearTacticalEditorFocus(owner)
	for _, box in ipairs(owner.tacticalMessageBoxes or {}) do
		box:ClearFocus()
	end
end

local function getAnnouncementService()
	local service = GF.MythicPlusAnnouncementService
	return type(service) == "table" and service or nil
end

local function colorByte(value)
	value = math.max(0, math.min(1, tonumber(value) or 1))
	return math.floor((value * 255) + 0.5)
end

local function colorizeTacticalChannel(channel, label)
	local color = ChatTypeInfo and ChatTypeInfo[channel]
		or TACTICAL_CHANNEL_FALLBACK_COLORS[channel]
		or TACTICAL_CHANNEL_FALLBACK_COLORS.PARTY
	local red = color.r or color[1]
	local green = color.g or color[2]
	local blue = color.b or color[3]
	return string.format(
		"|cff%02x%02x%02x%s|r",
		colorByte(red),
		colorByte(green),
		colorByte(blue),
		tostring(label or channel or "")
	)
end

local function getTacticalManualChannelOptions()
	local service = getAnnouncementService()
	if not service
		or type(service.GetManualTacticalChannelOptions)
			~= "function"
	then
		return {}
	end
	local ok, options = pcall(
		service.GetManualTacticalChannelOptions,
		service
	)
	return ok and type(options) == "table" and options or {}
end

local function getTacticalManualChannelSelection()
	local service = getAnnouncementService()
	if not service
		or type(service.GetManualTacticalChannel) ~= "function"
	then
		return nil
	end
	local ok, channel = pcall(
		service.GetManualTacticalChannel,
		service
	)
	return ok and type(channel) == "string" and channel or nil
end

local function resolveTacticalManualChannel(channel)
	local service = getAnnouncementService()
	if not service
		or type(service.ResolveManualTacticalChannel) ~= "function"
	then
		return nil
	end
	local ok, resolved = pcall(
		service.ResolveManualTacticalChannel,
		service,
		channel
	)
	return ok and type(resolved) == "string" and resolved or nil
end

local function setTacticalManualChannelSelection(channel)
	local service = getAnnouncementService()
	if not service
		or type(service.SetManualTacticalChannel) ~= "function"
	then
		return channel
	end
	local ok, normalized = pcall(
		service.SetManualTacticalChannel,
		service,
		channel
	)
	return ok and type(normalized) == "string"
		and normalized or channel
end

local PUBLIC_METHODS = {
	"ScheduleMythicPlusTacticalRebuild",
	"EnsureMythicPlusSeasonListener",
	"IsTacticalDraftDirty",
	"CaptureTacticalDraft",
	"UpdateTacticalDungeonRows",
	"UpdateTacticalEditorState",
	"UpdateTacticalManualBroadcastState",
	"BroadcastCurrentTacticalAnnouncement",
	"LoadTacticalDungeon",
	"GetAvailableTacticalDungeonID",
	"CommitTacticalDraft",
	"DiscardTacticalDraft",
	"ResetCurrentTacticalAnnouncements",
	"RequestTacticalDungeonSelection",
	"ResolveTacticalSelectionPrompt",
	"RebuildTacticalDungeonList",
}

function Page:Install(owner, helpers)
	settingsPanel = owner
	dependencies = helpers or {}
	for _, methodName in ipairs(PUBLIC_METHODS) do
		owner[methodName] = Page[methodName]
	end
end

function Page.GetUnsavedPopupID()
	return TACTICAL_UNSAVED_POPUP
end

function Page.HideUnsavedPopup()
	if StaticPopup_Hide then
		StaticPopup_Hide(TACTICAL_UNSAVED_POPUP)
	end
end

function Page.ResetPopupDefinition()
	if StaticPopupDialogs then
		StaticPopupDialogs[TACTICAL_UNSAVED_POPUP] = nil
	end
end

function Page.ResetViewState(owner)
	owner.tacticalListPanel = nil
	owner.tacticalListScroll = nil
	owner.tacticalListBody = nil
	owner.tacticalListScrollBar = nil
	owner._tacticalDungeonRowCount = nil
	owner._tacticalListScrollable = nil
	owner.tacticalEmptyLabel = nil
	owner.tacticalEditorPanel = nil
	owner.tacticalDungeonName = nil
	owner.tacticalMessageBox = nil
	owner.tacticalMessageBoxes = nil
	owner.tacticalPlaceholder = nil
	owner.tacticalPlaceholders = nil
	owner.tacticalByteCounters = nil
	owner.tacticalConfirmButton = nil
	owner.tacticalClearButton = nil
	owner.tacticalManualBroadcastButton = nil
	owner.tacticalManualChannelDropdown = nil
	owner.tacticalManualChannelLabel = nil
	owner.tacticalEditorStatus = nil
	owner.tacticalDungeonRows = nil
	owner.tacticalDungeonByID = nil
	owner._syncingTacticalMessage = nil
	owner._tacticalPendingLinkTarget = nil
	owner._tacticalLinkTargetToken = nil
end

local function getMythicPlusTacticalDungeons()
	local season = GF.MythicPlusSeason
	if not season or type(season.GetDungeons) ~= "function" then
		return {}
	end
	local ok, dungeons = pcall(season.GetDungeons, season)
	return ok and type(dungeons) == "table" and dungeons or {}
end

function Page.RefreshLocale(owner)
	owner = owner or settingsPanel
	if not owner or not owner.tacticalListBody then
		return
	end
	Page.HideUnsavedPopup()
	Page.ResetPopupDefinition()
	owner:RebuildTacticalDungeonList(
		getMythicPlusTacticalDungeons()
	)
	owner:UpdateTacticalEditorState()
end

local function getMythicPlusTacticalDungeonSignature(dungeons)
	local parts = {}
	local seen = {}
	for _, dungeon in ipairs(
		type(dungeons) == "table" and dungeons or {}
	) do
		local challengeModeID =
			tonumber(dungeon and dungeon.challengeModeID)
		if challengeModeID and not seen[challengeModeID] then
			seen[challengeModeID] = true
			parts[#parts + 1] = string.format(
				"%d:%s",
				challengeModeID,
				tostring(dungeon and dungeon.name or "")
			)
		end
	end
	return table.concat(parts, ",")
end

local function updateTacticalListScrolling(owner)
	local scroll = owner and owner.tacticalListScroll
	local scrollBar = owner and owner.tacticalListScrollBar
	if not scroll then
		return
	end
	local viewportHeight = scroll:GetHeight() or 0
	if viewportHeight <= 0 then
		viewportHeight =
			LAYOUT.panelH - (LAYOUT.scrollInsetY * 2)
	end
	local contentHeight =
		(tonumber(owner._tacticalDungeonRowCount) or 0)
			* LAYOUT.rowH
	local scrollable = contentHeight
		> viewportHeight + LAYOUT.scrollOverflowTolerance
	owner._tacticalListScrollable = scrollable
	if not scrollable
		and scroll.GetVerticalScroll
		and (scroll:GetVerticalScroll() or 0) ~= 0
	then
		if GF.UI.CancelSmoothWheelScrolling then
			GF.UI.CancelSmoothWheelScrolling(scroll)
		end
		scroll:SetVerticalScroll(0)
	end
	if scrollBar then
		if scrollBar.SetScrollAllowed then
			scrollBar:SetScrollAllowed(scrollable)
		end
		scrollBar:SetShown(scrollable)
	end
end

function Page:ScheduleMythicPlusTacticalRebuild()
	if self._mythicPlusTacticalRebuildQueued then
		return
	end
	self._mythicPlusTacticalRebuildQueued = true
	local function rebuildIfChanged()
		self._mythicPlusTacticalRebuildQueued = nil
		if not self.scroll or not self.parent then
			return
		end
		local dungeons = getMythicPlusTacticalDungeons()
		local signature =
			getMythicPlusTacticalDungeonSignature(dungeons)
		if signature
			== (self._mythicPlusTacticalSignature or "")
		then
			return
		end
		self:RebuildTacticalDungeonList(dungeons)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, rebuildIfChanged)
	else
		rebuildIfChanged()
	end
end

function Page:EnsureMythicPlusSeasonListener()
	local season = GF.MythicPlusSeason
	if not season or type(season.AddListener) ~= "function" then
		return
	end
	if self._mythicPlusSeasonListenerSource == season then
		return
	end
	local callback = function()
		self:ScheduleMythicPlusTacticalRebuild()
	end
	local ok = pcall(season.AddListener, season, callback)
	if ok then
		self._mythicPlusSeasonListenerSource = season
		self._mythicPlusSeasonListener = callback
	end
end

function Page:IsTacticalDraftDirty()
	local challengeModeID = Presenter:GetTacticalSelection()
	if not challengeModeID then
		return false
	end
	return Presenter:IsDirty(
		"tacticalAnnouncement",
		{ challengeModeID = challengeModeID })
end

function Page:CaptureTacticalDraft()
	local challengeModeID = Presenter:GetTacticalSelection()
	if not challengeModeID or not self.tacticalMessageBoxes then
		return
	end
	Presenter:StageValue(
		"tacticalAnnouncement",
		getTacticalEditorValue(self),
		{ challengeModeID = challengeModeID })
end

local function createTacticalRowPieces(
	row,
	layer,
	subLevel,
	blendMode
)
	local pieces = GF.UI
		and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(
			row,
			layer,
			subLevel
		)
		or {}
	for _, piece in pairs(pieces) do
		if blendMode and piece.SetBlendMode then
			piece:SetBlendMode(blendMode)
		end
	end
	return pieces
end

local function createTacticalRowBasePieces(row)
	return createTacticalRowPieces(
		row,
		"BACKGROUND",
		-2,
		"BLEND"
	)
end

local function createTacticalRowOverlayPieces(row, subLevel)
	return createTacticalRowPieces(
		row,
		"BORDER",
		subLevel,
		"ADD"
	)
end

local function setTacticalRowOverlayShown(pieces, shown)
	if GF.UI and GF.UI.SetRowBackgroundPiecesShown then
		GF.UI.SetRowBackgroundPiecesShown(
			pieces,
			shown == true
		)
		return
	end
	for _, piece in pairs(pieces or {}) do
		if piece.SetShown then
			piece:SetShown(shown == true)
		end
	end
end

local function applyTacticalRowOverlay(row, pieces, color)
	if not (row
		and pieces
		and GF.UI
		and GF.UI.ApplyRowBackgroundPieces)
	then
		return false
	end
	return GF.UI.ApplyRowBackgroundPieces(row, pieces, {
		profile = GF.TACTICAL_ROW_BACKGROUND_PROFILE or ROW_STYLE.background,
		atlas = GF.ROW_BACKGROUND_ATLAS
			or "UI-QuestTracker-Secondary-Objective-Header",
		state = "normal",
		mode = "full",
		alpha = GF.BROWSE_ROW_SELECTED_ALPHA or 1,
		vertexColor = color,
		desaturated = true,
		fallbackTexture =
			GF.ROW_BACKGROUND_FALLBACK_TEXTURE or WHITE,
		defaultHeight = LAYOUT.rowH,
	})
end

local function applyTacticalRowBase(row, pieces)
	if not (row
		and pieces
		and GF.UI
		and GF.UI.ApplyRowBackgroundPieces)
	then
		return false
	end
	return GF.UI.ApplyRowBackgroundPieces(row, pieces, {
		profile = GF.TACTICAL_ROW_BACKGROUND_PROFILE or ROW_STYLE.background,
		atlas = GF.ROW_BACKGROUND_ATLAS
			or "UI-QuestTracker-Secondary-Objective-Header",
		state = "normal",
		mode = "full",
		alpha = GF.BROWSE_ROW_BACKGROUND_ALPHA or 0.92,
		vertexColor = LAYOUT.rowBaseColor,
		desaturated = false,
		fallbackTexture =
			GF.ROW_BACKGROUND_FALLBACK_TEXTURE or WHITE,
		defaultHeight = LAYOUT.rowH,
	})
end

function Page:UpdateTacticalDungeonRows()
	local selectedID = Presenter:GetTacticalSelection()
	local dirty = self:IsTacticalDraftDirty()
	for _, row in ipairs(self.tacticalDungeonRows or {}) do
		local challengeModeID = row.challengeModeID
		local selected = challengeModeID == selectedID
		row._gfSelected = selected
		if row.selectedBackgroundPieces then
			setTacticalRowOverlayShown(
				row.selectedBackgroundPieces,
				selected
			)
		end
		if row.hoverBackgroundPieces then
			setTacticalRowOverlayShown(
				row.hoverBackgroundPieces,
				row._gfHovered == true and not selected
			)
		end
		if row.label and row.label.SetTextColor then
			if selected then
				row.label:SetTextColor(1, 0.82, 0, 1)
			elseif row._gfHovered then
				row.label:SetTextColor(1, 0.92, 0.68, 1)
			else
				row.label:SetTextColor(
					0.84,
					0.82,
					0.76,
					1
				)
			end
		end
		if row.statusIcon then
			local saved = Presenter:ProjectField(
				"tacticalAnnouncement",
				{ challengeModeID = challengeModeID }).savedValue or ""
			local atlas
			if selected and dirty then
				atlas = TACTICAL_PENDING_ATLAS
			elseif saved ~= "" then
				atlas = TACTICAL_READY_ATLAS
			end
			if atlas
				and GF.UI
				and GF.UI.TrySetAtlas
				and GF.UI.TrySetAtlas(
					row.statusIcon,
					atlas,
					false
				)
			then
				row.statusIcon:Show()
			else
				row.statusIcon:Hide()
			end
		end
	end
end

function Page:UpdateTacticalManualBroadcastState()
	local options = getTacticalManualChannelOptions()
	local selected = getTacticalManualChannelSelection()
		or self._tacticalManualRequestedChannel
	local label
	for _, option in ipairs(options) do
		if option.channel == selected then
			label = option.label or selected
			break
		end
	end
	if not label and options[1] then
		selected = options[1].channel
		label = options[1].label or selected
		selected = setTacticalManualChannelSelection(selected)
	end
	self._tacticalManualRequestedChannel = selected
	if self.tacticalManualChannelDropdown then
		self.tacticalManualChannelDropdown:SetDefaultText(
			selected
				and colorizeTacticalChannel(selected, label)
				or ""
		)
		if self.tacticalManualChannelDropdown.GenerateMenu then
			self.tacticalManualChannelDropdown:GenerateMenu()
		end
		dependencies.setSettingsWidgetEnabled(
			self.tacticalManualChannelDropdown,
			selected ~= nil
		)
	end
	local currentText = getTacticalEditorValue(self)
	dependencies.setSettingsWidgetEnabled(
		self.tacticalManualBroadcastButton,
		selected ~= nil
			and currentText ~= ""
			and resolveTacticalManualChannel(selected) ~= nil
	)
end

function Page:BroadcastCurrentTacticalAnnouncement()
	local service = getAnnouncementService()
	if not service
		or type(service.BroadcastManualTacticalAnnouncement)
			~= "function"
	then
		return false, 0
	end
	local sent, sentCount, resolved =
		service:BroadcastManualTacticalAnnouncement(
			getTacticalEditorValue(self),
			self._tacticalManualRequestedChannel
		)
	self:UpdateTacticalManualBroadcastState()
	return sent, sentCount, resolved
end

function Page:UpdateTacticalEditorState()
	local L = GF.L or {}
	local challengeModeID = Presenter:GetTacticalSelection()
	local projection = Presenter:ProjectField(
		"tacticalAnnouncement",
		{ challengeModeID = challengeModeID })
	local available = projection.enabled
	local currentText = getTacticalEditorValue(self)
	local dirty = available and projection.dirty

	for _, box in ipairs(self.tacticalMessageBoxes or {}) do
		dependencies.setSettingsWidgetEnabled(box, available)
		updateTacticalByteCounter(box, false)
	end
	dependencies.setSettingsWidgetEnabled(
		self.tacticalConfirmButton,
		dirty
	)
	dependencies.setSettingsWidgetEnabled(
		self.tacticalClearButton,
		available and currentText ~= ""
	)
	for index, placeholder in ipairs(
		self.tacticalPlaceholders or {})
	do
		local box = self.tacticalMessageBoxes
			and self.tacticalMessageBoxes[index]
		placeholder:SetShown(
			available and box
				and (box:GetText() or "") == ""
				and not box:HasFocus())
	end
	if self.tacticalEditorStatus then
		if not available then
			self.tacticalEditorStatus:SetText("")
			self.tacticalEditorStatus:SetTextColor(
				0.52,
				0.50,
				0.46,
				1
			)
		elseif dirty then
			self.tacticalEditorStatus:SetText(
				L.SET_MPLUS_TACTICAL_UNSAVED
					or "Unsaved"
			)
			self.tacticalEditorStatus:SetTextColor(
				1,
				0.72,
				0.18,
				1
			)
		elseif (projection.savedValue or "") ~= "" then
			self.tacticalEditorStatus:SetText(
				L.SET_MPLUS_TACTICAL_CONFIGURED
					or "Set"
			)
			self.tacticalEditorStatus:SetTextColor(
				0.45,
				0.86,
				0.46,
				1
			)
		else
			self.tacticalEditorStatus:SetText(
				L.SET_MPLUS_TACTICAL_NOT_CONFIGURED
					or "Not set"
			)
			self.tacticalEditorStatus:SetTextColor(
				0.52,
				0.50,
				0.46,
				1
			)
		end
		dependencies.fitSettingsText(
			self.tacticalEditorStatus,
			120,
			8
		)
	end
	self:UpdateTacticalDungeonRows()
	self:UpdateTacticalManualBroadcastState()
end

function Page:LoadTacticalDungeon(challengeModeID)
	challengeModeID = tonumber(challengeModeID)
	local selection = Presenter:SetTacticalSelection(challengeModeID)
	local previousChallengeModeID = selection.previousID
	local projection = Presenter:ProjectField(
		"tacticalAnnouncement",
		{ challengeModeID = challengeModeID })

	local dungeon = self.tacticalDungeonByID
		and self.tacticalDungeonByID[challengeModeID]
	if dungeon and dungeon.name and dungeon.name ~= "" then
		self._tacticalSelectedDungeonName = dungeon.name
	elseif previousChallengeModeID ~= challengeModeID then
		self._tacticalSelectedDungeonName = nil
	end
	if self.tacticalDungeonName then
		self.tacticalDungeonName:SetText(
			not challengeModeID
				and ((GF.L
					and GF.L.SET_MPLUS_TACTICAL_NO_DUNGEONS)
					or "No current-season dungeons are available.")
				or dungeon and dungeon.name
				or self._tacticalSelectedDungeonName
				or ((GF.L and GF.L.MPLUS_UNKNOWN_DUNGEON)
					or "Unknown dungeon")
		)
		local titleWidth =
			self.tacticalDungeonName:GetWidth()
		if titleWidth and titleWidth > 20 then
			dependencies.fitSettingsText(
				self.tacticalDungeonName,
				titleWidth,
				11
			)
		end
	end
	if self.tacticalMessageBoxes then
		setTacticalEditorValue(self, projection.value or "")
	end
	self:UpdateTacticalEditorState()
end

function Page:GetAvailableTacticalDungeonID(challengeModeID)
	challengeModeID = tonumber(challengeModeID)
	if challengeModeID
		and self.tacticalDungeonByID
		and self.tacticalDungeonByID[challengeModeID]
	then
		return challengeModeID
	end
	return self._tacticalFirstChallengeModeID
end

function Page:CommitTacticalDraft(value)
	local challengeModeID = Presenter:GetTacticalSelection()
	if not challengeModeID then
		return false
	end
	if value == nil and self.tacticalMessageBoxes then
		value = getTacticalEditorValue(self)
	end
	local context = { challengeModeID = challengeModeID }
	Presenter:StageValue(
		"tacticalAnnouncement", value or "", context)
	local ok = Presenter:ApplyField(
		"tacticalAnnouncement", context)
	if not ok then
		return false
	end
	self:LoadTacticalDungeon(
		self:GetAvailableTacticalDungeonID(challengeModeID)
	)
	return true
end

function Page:DiscardTacticalDraft()
	local challengeModeID = Presenter:GetTacticalSelection()
	if not challengeModeID then
		return
	end
	Presenter:DiscardDraft(
		"tacticalAnnouncement",
		{ challengeModeID = challengeModeID })
	self:LoadTacticalDungeon(
		self:GetAvailableTacticalDungeonID(challengeModeID)
	)
end

function Page:ResetCurrentTacticalAnnouncements()
	Page.HideUnsavedPopup()
	Presenter:ClearTacticalSelectionPrompt()
	local challengeModeIDs = {}
	for challengeModeID in pairs(self.tacticalDungeonByID or {}) do
		challengeModeIDs[#challengeModeIDs + 1] = challengeModeID
	end
	local resetCount =
		Presenter:ResetTacticalAnnouncements(challengeModeIDs)
	self:LoadTacticalDungeon(
		self:GetAvailableTacticalDungeonID(
			Presenter:GetTacticalSelection()
		)
	)
	return resetCount
end

local function ensureTacticalUnsavedPopup()
	if not StaticPopupDialogs
		or StaticPopupDialogs[TACTICAL_UNSAVED_POPUP]
	then
		return
	end
	local L = GF.L or {}
	StaticPopupDialogs[TACTICAL_UNSAVED_POPUP] = {
		text = L.SET_MPLUS_TACTICAL_UNSAVED_CONFIRM
			or "The current tactical announcement has unsaved changes.",
		button1 = L.SET_MPLUS_TACTICAL_SAVE_AND_SWITCH
			or "Save",
		button2 = L.SET_MPLUS_TACTICAL_DISCARD_AND_SWITCH
			or "Discard",
		button3 = L.CANCEL or CANCEL or "Cancel",
		selectCallbackByIndex = true,
		OnAccept = function()
			settingsPanel:ResolveTacticalSelectionPrompt("save")
		end,
		OnCancel = function()
			settingsPanel:ResolveTacticalSelectionPrompt(
				"discard"
			)
		end,
		OnButton3 = function()
			settingsPanel:ResolveTacticalSelectionPrompt(
				"cancel"
			)
		end,
		OnHide = function()
			Presenter:ClearTacticalSelectionPrompt()
		end,
		timeout = 0,
		whileDead = true,
		exclusive = true,
		hideOnEscape = true,
		noCancelOnEscape = true,
	}
end

function Page:RequestTacticalDungeonSelection(challengeModeID)
	challengeModeID = tonumber(challengeModeID)
	local plan = Presenter:PlanTacticalSelection(
		Presenter:GetTacticalSelection(),
		challengeModeID,
		getTacticalEditorValue(self))
	if plan.action == "ignore" then
		return
	elseif plan.action == "select" then
		clearTacticalEditorFocus(self)
		self:LoadTacticalDungeon(plan.challengeModeID)
		return
	end

	clearTacticalEditorFocus(self)
	ensureTacticalUnsavedPopup()
	if StaticPopup_Show then
		StaticPopup_Show(TACTICAL_UNSAVED_POPUP)
	end
end

function Page:ResolveTacticalSelectionPrompt(action)
	local plan = Presenter:ResolveTacticalSelectionPrompt(
		action, Presenter:GetTacticalSelection())
	if plan.action ~= "select" then
		return
	end
	local nextChallengeModeID = plan.challengeModeID
	if not (self.tacticalDungeonByID
		and self.tacticalDungeonByID[nextChallengeModeID])
	then
		nextChallengeModeID =
			self._tacticalFirstChallengeModeID
	end
	self:LoadTacticalDungeon(nextChallengeModeID)
end

function Page:RebuildTacticalDungeonList(
	dungeons,
	skipDraftCapture
)
	if not self.tacticalListBody then
		return
	end
	if not skipDraftCapture then
		self:CaptureTacticalDraft()
	end
	local previousChallengeModeID = Presenter:GetTacticalSelection()
	local previousDirty = self:IsTacticalDraftDirty()
	dungeons = type(dungeons) == "table"
		and dungeons
		or getMythicPlusTacticalDungeons()
	self._mythicPlusTacticalSignature =
		getMythicPlusTacticalDungeonSignature(dungeons)
	self.tacticalDungeonByID = {}
	self.tacticalDungeonRows =
		self.tacticalDungeonRows or {}

	local ordered = {}
	local seen = {}
	for _, dungeon in ipairs(dungeons) do
		local challengeModeID =
			tonumber(dungeon and dungeon.challengeModeID)
		if challengeModeID and not seen[challengeModeID] then
			seen[challengeModeID] = true
			self.tacticalDungeonByID[challengeModeID] =
				dungeon
			ordered[#ordered + 1] = dungeon
		end
	end
	self._tacticalFirstChallengeModeID = ordered[1]
		and tonumber(ordered[1].challengeModeID)
		or nil

	for index, dungeon in ipairs(ordered) do
		local row = self.tacticalDungeonRows[index]
		if not row then
			row = CreateFrame(
				"Button",
				nil,
				self.tacticalListBody
			)
			row:SetHeight(LAYOUT.rowH)
			row:RegisterForClicks("LeftButtonUp")

			local baseBackgroundPieces =
				createTacticalRowBasePieces(row)
			applyTacticalRowBase(
				row,
				baseBackgroundPieces
			)

			local selectedBackgroundPieces =
				createTacticalRowOverlayPieces(row, 1)
			applyTacticalRowOverlay(
				row,
				selectedBackgroundPieces,
				LAYOUT.rowSelectedColor
			)
			setTacticalRowOverlayShown(
				selectedBackgroundPieces,
				false
			)

			local hoverBackgroundPieces =
				createTacticalRowOverlayPieces(row, -1)
			applyTacticalRowOverlay(
				row,
				hoverBackgroundPieces,
				LAYOUT.rowHoverColor
			)
			setTacticalRowOverlayShown(
				hoverBackgroundPieces,
				false
			)

			local label = GF.UI.CreateFontString(
				row,
				"OVERLAY",
				"GameFontHighlightSmall"
			)
			label:SetPoint(
				"LEFT",
				row,
				"LEFT",
				LAYOUT.rowLabelInsetX,
				ROW_CONTENT_OFFSET_Y
			)
			label:SetPoint(
				"RIGHT",
				row,
				"RIGHT",
				-LAYOUT.rowLabelInsetX,
				ROW_CONTENT_OFFSET_Y
			)
			label:SetHeight(LAYOUT.rowH - 2 * math.abs(ROW_CONTENT_OFFSET_Y))
			label:SetJustifyH("CENTER")
			label:SetJustifyV("MIDDLE")
			label:SetWordWrap(false)
			label._gfFontSizeOverride = 14
			dependencies.styleSettingsLabel(
				label,
				"GameFontHighlightSmall"
			)

			local statusIcon = row:CreateTexture(
				nil,
				"OVERLAY"
			)
			statusIcon:SetSize(
				LAYOUT.rowStatusIconSize,
				LAYOUT.rowStatusIconSize
			)
			statusIcon:SetPoint(
				"CENTER",
				row,
				"RIGHT",
				-(
					LAYOUT.rowStatusInsetR
					+ (LAYOUT.rowStatusW / 2)
				),
				ROW_CONTENT_OFFSET_Y
			)
			statusIcon:Hide()

			row.baseBackgroundPieces =
				baseBackgroundPieces
			row.selectedBackgroundPieces =
				selectedBackgroundPieces
			row.hoverBackgroundPieces =
				hoverBackgroundPieces
			row.label = label
			row.statusIcon = statusIcon
			row:SetScript("OnClick", function(owner)
				self:RequestTacticalDungeonSelection(
					owner.challengeModeID
				)
			end)
			row:SetScript("OnEnter", function(owner)
				owner._gfHovered = true
				self:UpdateTacticalDungeonRows()
			end)
			row:SetScript("OnLeave", function(owner)
				owner._gfHovered = nil
				self:UpdateTacticalDungeonRows()
			end)
			self.tacticalDungeonRows[index] = row
		end
		row.challengeModeID =
			tonumber(dungeon.challengeModeID)
		row.label:SetText(
			dungeon.name
				or ((GF.L and GF.L.MPLUS_UNKNOWN_DUNGEON)
					or "Unknown dungeon")
		)
		dependencies.fitSettingsText(
			row.label,
			LAYOUT.listW
				- (LAYOUT.listInnerInsetX * 2)
				- (LAYOUT.rowLabelInsetX * 2),
			8
		)
		row:ClearAllPoints()
		row:SetPoint(
			"TOPLEFT",
			self.tacticalListBody,
			"TOPLEFT",
			0,
			-((index - 1) * LAYOUT.rowH)
		)
		row:SetPoint(
			"TOPRIGHT",
			self.tacticalListBody,
			"TOPRIGHT",
			0,
			-((index - 1) * LAYOUT.rowH)
		)
		row:Show()
	end
	for index = #ordered + 1,
		#self.tacticalDungeonRows
	do
		self.tacticalDungeonRows[index]:Hide()
	end
	self.tacticalListBody:SetHeight(
		math.max(1, #ordered * LAYOUT.rowH)
	)
	self._tacticalDungeonRowCount = #ordered
	if self.tacticalEmptyLabel then
		self.tacticalEmptyLabel:SetShown(#ordered == 0)
	end
	if GF.UI
		and GF.UI.UpdateScrollFrame
		and self.tacticalListScroll
	then
		GF.UI.UpdateScrollFrame(self.tacticalListScroll)
	end
	updateTacticalListScrolling(self)

	if previousChallengeModeID
		and previousDirty
		and not self.tacticalDungeonByID[
			previousChallengeModeID]
	then
		self:LoadTacticalDungeon(previousChallengeModeID)
		return
	end
	local selectedID = previousChallengeModeID
	if not selectedID
		or not self.tacticalDungeonByID[selectedID]
	then
		selectedID = self._tacticalFirstChallengeModeID
	end
	self:LoadTacticalDungeon(selectedID)
end

function Page.Build(owner, tacticalPage, tacticalY)
	local L = GF.L or {}
	ensureTacticalLinkInsertionHook()
	ensureTacticalEncounterJournalHooks()
	tacticalPage._gfFillViewport = true
	local section = dependencies.createSettingsSection(
		tacticalPage,
		L.SET_SECTION_MPLUS_TACTICAL
			or "Tactical announcements",
		tacticalY
	)
	dependencies.styleVisualAppearancePanel(section, true)
	section._gfRowOffset = LAYOUT.panelH
	dependencies.updateSettingsSectionHeights(section)
	section:ClearAllPoints()
	section:SetPoint("LEFT", tacticalPage, "LEFT", 0, 0)
	section:SetPoint("RIGHT", tacticalPage, "RIGHT", 0, 0)

	owner.tacticalListPanel = CreateFrame(
		"Frame",
		nil,
		section.panel,
		"BackdropTemplate"
	)
	owner.tacticalListPanel:SetPoint(
		"TOPLEFT",
		section.panel,
		"TOPLEFT",
		0,
		0
	)
	owner.tacticalListPanel:SetPoint(
		"BOTTOMLEFT",
		section.panel,
		"BOTTOMLEFT",
		0,
		0
	)
	owner.tacticalListPanel:SetWidth(LAYOUT.listW)
	dependencies.applyOptionsFeaturePanelStyle(
		owner.tacticalListPanel
	)

	owner.tacticalListScroll = GF.UI.CreateScrollFrame(
		owner.tacticalListPanel,
		{ rowHeight = LAYOUT.rowH }
	)
	owner.tacticalListScroll:SetPoint(
		"TOPLEFT",
		owner.tacticalListPanel,
		"TOPLEFT",
		LAYOUT.listInnerInsetX,
		-LAYOUT.scrollInsetY
	)
	owner.tacticalListScroll:SetPoint(
		"BOTTOMRIGHT",
		owner.tacticalListPanel,
		"BOTTOMRIGHT",
		-LAYOUT.listInnerInsetX,
		LAYOUT.scrollInsetY
	)
	owner.tacticalListBody = CreateFrame(
		"Frame",
		nil,
		owner.tacticalListScroll
	)
	owner.tacticalListBody:SetSize(
		LAYOUT.listW - (LAYOUT.listInnerInsetX * 2),
		1
	)
	owner.tacticalListScroll:SetScrollChild(
		owner.tacticalListBody
	)
	owner.tacticalListScrollBar =
		GF.UI.BindMinimalScrollBar(
			owner.tacticalListScroll,
			2,
			owner.tacticalListPanel,
			true
		)
	if owner.tacticalListScrollBar then
		if owner.tacticalListScrollBar.SetHideIfUnscrollable then
			owner.tacticalListScrollBar:SetHideIfUnscrollable(false)
		end
		owner.tacticalListScrollBar._gfHideIfUnscrollable = nil
		owner.tacticalListScrollBar:SetWidth(10)
		owner.tacticalListScrollBar:ClearAllPoints()
		owner.tacticalListScrollBar:SetPoint(
			"TOPRIGHT",
			owner.tacticalListScroll,
			"TOPRIGHT",
			0,
			-2
		)
		owner.tacticalListScrollBar:SetPoint(
			"BOTTOMRIGHT",
			owner.tacticalListScroll,
			"BOTTOMRIGHT",
			0,
			2
		)
	end
	owner.tacticalListScroll._gfWheelAllow = function()
		return owner._tacticalListScrollable == true
	end
	if GF.UI.BindSmoothWheelScrolling then
		GF.UI.BindSmoothWheelScrolling(owner.tacticalListScroll)
	end
	if GF.UI.BindScrollFrameEdgeFade then
		GF.UI.BindScrollFrameEdgeFade(owner.tacticalListScroll, owner.tacticalListBody, GF.SETTINGS_SCROLL_EDGE_FADE)
	end
	owner.tacticalListScroll:HookScript(
		"OnSizeChanged",
		function()
			updateTacticalListScrolling(owner)
		end
	)

	owner.tacticalEmptyLabel = GF.UI.CreateFontString(
		owner.tacticalListPanel,
		"OVERLAY",
		"GameFontDisableSmall"
	)
	owner.tacticalEmptyLabel:SetPoint(
		"TOPLEFT",
		owner.tacticalListScroll,
		"TOPLEFT",
		10,
		-20
	)
	owner.tacticalEmptyLabel:SetPoint(
		"TOPRIGHT",
		owner.tacticalListScroll,
		"TOPRIGHT",
		-6,
		-20
	)
	owner.tacticalEmptyLabel:SetHeight(64)
	owner.tacticalEmptyLabel:SetJustifyH("CENTER")
	owner.tacticalEmptyLabel:SetJustifyV("MIDDLE")
	owner.tacticalEmptyLabel:SetWordWrap(true)
	owner.tacticalEmptyLabel:SetText(
		L.SET_MPLUS_TACTICAL_NO_DUNGEONS
			or "No current-season dungeons are available."
	)
	owner.tacticalEmptyLabel._gfFontSizeOverride =
		META_TEXT_SIZE
	dependencies.styleSettingsLabel(
		owner.tacticalEmptyLabel,
		"GameFontDisableSmall"
	)
	dependencies.bindSettingsLocaleText(
		owner.tacticalEmptyLabel,
		L.SET_MPLUS_TACTICAL_NO_DUNGEONS
			or "No current-season dungeons are available."
	)

	owner.tacticalEditorPanel = CreateFrame(
		"Frame",
		nil,
		section.panel,
		"BackdropTemplate"
	)
	owner.tacticalEditorPanel:SetPoint(
		"TOPLEFT",
		owner.tacticalListPanel,
		"TOPRIGHT",
		LAYOUT.panelGap,
		0
	)
	owner.tacticalEditorPanel:SetPoint(
		"BOTTOMRIGHT",
		section.panel,
		"BOTTOMRIGHT",
		0,
		0
	)
	dependencies.applyOptionsFeaturePanelStyle(
		owner.tacticalEditorPanel
	)

	owner.tacticalDungeonName = GF.UI.CreateFontString(
		owner.tacticalEditorPanel,
		"OVERLAY",
		"GameFontNormalLarge"
	)
	owner.tacticalDungeonName:SetPoint(
		"TOPLEFT",
		owner.tacticalEditorPanel,
		"TOPLEFT",
		LAYOUT.editorInset,
		-14
	)
	owner.tacticalDungeonName:SetPoint(
		"TOPRIGHT",
		owner.tacticalEditorPanel,
		"TOPRIGHT",
		-(LAYOUT.editorInset
			+ TACTICAL_MANUAL_CONTROL_W
			+ TACTICAL_MANUAL_CONTROL_GAP),
		-14
	)
	owner.tacticalDungeonName:SetHeight(28)
	owner.tacticalDungeonName:SetJustifyH("LEFT")
	owner.tacticalDungeonName:SetJustifyV("MIDDLE")
	owner.tacticalDungeonName:SetWordWrap(false)
	owner.tacticalDungeonName:SetTextColor(1, 0.82, 0, 1)
	owner.tacticalDungeonName._gfFontSizeOverride =
		TITLE_TEXT_SIZE
	owner.tacticalDungeonName._gfFontFlagsOverride = "OUTLINE"
	dependencies.styleSettingsLabel(
		owner.tacticalDungeonName,
		"GameFontNormalLarge"
	)
	dependencies.bindSettingsTextFit(
		owner.tacticalEditorPanel,
		owner.tacticalDungeonName,
		LAYOUT.editorInset * 2,
		11
	)

	local tacticalScope = GF.UI.CreateFontString(
		owner.tacticalEditorPanel,
		"OVERLAY",
		"GameFontHighlightSmall"
	)
	tacticalScope:SetPoint(
		"TOPLEFT",
		owner.tacticalDungeonName,
		"BOTTOMLEFT",
		0,
		-2
	)
	tacticalScope:SetPoint(
		"TOPRIGHT",
		owner.tacticalDungeonName,
		"BOTTOMRIGHT",
		0,
		-2
	)
	tacticalScope:SetHeight(20)
	tacticalScope:SetJustifyH("LEFT")
	tacticalScope:SetJustifyV("MIDDLE")
	tacticalScope:SetWordWrap(false)
	tacticalScope:SetText(
		L.SET_MPLUS_TACTICAL_CURRENT_CHARACTER
			or "Saved for the current character"
	)
	tacticalScope:SetTextColor(0.64, 0.62, 0.57, 1)
	tacticalScope._gfFontSizeOverride = META_TEXT_SIZE
	dependencies.styleSettingsLabel(
		tacticalScope,
		"GameFontHighlightSmall"
	)
	dependencies.bindSettingsLocaleText(
		tacticalScope,
		L.SET_MPLUS_TACTICAL_CURRENT_CHARACTER
			or "Saved for the current character"
	)
	dependencies.bindSettingsTextFit(
		owner.tacticalEditorPanel,
		tacticalScope,
		LAYOUT.editorInset * 2,
		10
	)

	owner.tacticalManualBroadcastButton = GF.UI.CreatePanelButton(
		owner.tacticalEditorPanel,
		L.SET_MPLUS_TACTICAL_MANUAL_BROADCAST
			or "Manual broadcast",
		TACTICAL_MANUAL_CONTROL_W
	)
	owner.tacticalManualBroadcastButton:SetPoint(
		"TOPRIGHT",
		owner.tacticalEditorPanel,
		"TOPRIGHT",
		-LAYOUT.editorInset,
		-10
	)
	dependencies.fitSettingsText(
		owner.tacticalManualBroadcastButton:GetFontString(),
		TACTICAL_MANUAL_CONTROL_W - 12,
		8
	)
	dependencies.bindSettingsLocaleText(
		owner.tacticalManualBroadcastButton,
		L.SET_MPLUS_TACTICAL_MANUAL_BROADCAST
			or "Manual broadcast",
		nil,
		function(target)
			dependencies.fitSettingsText(
				target:GetFontString(),
				TACTICAL_MANUAL_CONTROL_W - 12,
				8
			)
		end
	)
	owner.tacticalManualBroadcastButton._gfSettingsTooltipLabel =
		owner.tacticalManualBroadcastButton:GetFontString()
	dependencies.bindSettingsControlTooltip(
		owner.tacticalManualBroadcastButton,
		L.SET_MPLUS_TACTICAL_MANUAL_BROADCAST_HINT or ""
	)

	owner.tacticalManualChannelDropdown =
		GF.UI.CreateDropdownButton(owner.tacticalEditorPanel)
	owner.tacticalManualChannelDropdown:SetSize(
		TACTICAL_MANUAL_DROPDOWN_W,
		DD_H
	)
	owner.tacticalManualChannelDropdown:SetPoint(
		"TOPRIGHT",
		owner.tacticalEditorPanel,
		"TOPRIGHT",
		-LAYOUT.editorInset,
		-40
	)
	owner.tacticalManualChannelLabel = GF.UI.CreateFontString(
		owner.tacticalEditorPanel,
		"OVERLAY",
		"GameFontHighlightSmall"
	)
	owner.tacticalManualChannelLabel:SetPoint(
		"RIGHT",
		owner.tacticalManualChannelDropdown,
		"LEFT",
		-6,
		0
	)
	owner.tacticalManualChannelLabel:SetSize(20, DD_H)
	owner.tacticalManualChannelLabel:SetJustifyH("RIGHT")
	owner.tacticalManualChannelLabel:SetJustifyV("MIDDLE")
	owner.tacticalManualChannelLabel:SetText(
		L.SET_MPLUS_TACTICAL_MANUAL_TO or "to"
	)
	owner.tacticalManualChannelLabel._gfFontSizeOverride =
		META_TEXT_SIZE
	dependencies.styleSettingsLabel(
		owner.tacticalManualChannelLabel,
		"GameFontHighlightSmall"
	)
	dependencies.bindSettingsLocaleText(
		owner.tacticalManualChannelLabel,
		L.SET_MPLUS_TACTICAL_MANUAL_TO or "to"
	)
	owner.tacticalManualChannelDropdown:SetupMenu(
		function(_, rootDescription)
			for _, option in ipairs(
				getTacticalManualChannelOptions())
			do
				local channel = option.channel
				rootDescription:CreateRadio(
					colorizeTacticalChannel(
						channel,
						option.label
					),
					function(candidate)
						return owner._tacticalManualRequestedChannel
							== candidate
					end,
					function(candidate)
						owner._tacticalManualRequestedChannel =
							setTacticalManualChannelSelection(
								candidate)
						owner:UpdateTacticalManualBroadcastState()
					end,
					channel
				)
			end
		end
	)
	owner.tacticalManualBroadcastButton:SetScript(
		"OnClick",
		function()
			owner:BroadcastCurrentTacticalAnnouncement()
		end
	)
	owner.tacticalMessageBoxes = {}
	owner.tacticalPlaceholders = {}
	owner.tacticalByteCounters = {}
	local previousMessageBox
	for index = 1, TACTICAL_MAX_LINES do
		local box = CreateFrame(
			"EditBox",
			nil,
			owner.tacticalEditorPanel,
			"InputBoxTemplate"
		)
		box:SetAutoFocus(false)
		box:SetMultiLine(false)
		box:SetMaxLetters(255)
		if box.SetMaxBytes then
			box:SetMaxBytes(TACTICAL_INPUT_MAX_BYTES)
		end
		GF.UI.TrackEditBox(box, "GameFontHighlightSmall")
		dependencies.styleSettingsNumberBox(
			box,
			DD_W,
			DD_H,
			false
		)
		box:ClearAllPoints()
		if previousMessageBox then
			box:SetPoint(
				"TOPLEFT",
				previousMessageBox,
				"BOTTOMLEFT",
				0,
				-TACTICAL_EDITOR_ROW_GAP
			)
			box:SetPoint(
				"TOPRIGHT",
				previousMessageBox,
				"BOTTOMRIGHT",
				0,
				-TACTICAL_EDITOR_ROW_GAP
			)
		else
			box:SetPoint(
				"TOPLEFT",
				tacticalScope,
				"BOTTOMLEFT",
				0,
				-14
			)
			box:SetPoint(
				"TOPRIGHT",
				owner.tacticalEditorPanel,
				"TOPRIGHT",
				-LAYOUT.editorInset,
				-78
			)
		end
		box:SetHeight(DD_H)
		box:SetJustifyH("LEFT")
		if box.SetJustifyV then
			box:SetJustifyV("MIDDLE")
		end
		if box.SetTextInsets then
			box:SetTextInsets(8, 76, 0, 0)
		end
		dependencies.bindSettingsControlTooltip(
			box,
			L.SET_MPLUS_TACTICAL_INPUT_HINT or ""
		)

		local placeholder = GF.UI.CreateFontString(
			box,
			"OVERLAY",
			"GameFontDisableSmall"
		)
		placeholder:SetPoint("LEFT", box, "LEFT", 8, 0)
		placeholder:SetPoint("RIGHT", box, "RIGHT", -76, 0)
		placeholder:SetHeight(DD_H)
		placeholder:SetJustifyH("LEFT")
		placeholder:SetJustifyV("MIDDLE")
		placeholder:SetWordWrap(false)
		local placeholderKey =
			"SET_MPLUS_TACTICAL_PLACEHOLDER_" .. index
		local placeholderText = L[placeholderKey]
			or string.format("Announcement %d", index)
		placeholder:SetText(placeholderText)
		placeholder:SetTextColor(0.48, 0.46, 0.42, 1)
		placeholder._gfFontSizeOverride = META_TEXT_SIZE
		dependencies.styleSettingsLabel(
			placeholder,
			"GameFontDisableSmall"
		)
		dependencies.bindSettingsLocaleText(
			placeholder,
			placeholderText
		)
		box._gfSettingsTooltipLabel = placeholder
		dependencies.bindSettingsTextFit(
			box,
			placeholder,
			16,
			9
		)

		local byteCounter = GF.UI.CreateFontString(
			box,
			"OVERLAY",
			"GameFontDisableSmall"
		)
		byteCounter:SetPoint("RIGHT", box, "RIGHT", -9, 0)
		byteCounter:SetSize(60, DD_H)
		byteCounter:SetJustifyH("RIGHT")
		byteCounter:SetJustifyV("MIDDLE")
		byteCounter:SetWordWrap(false)
		byteCounter._gfFontSizeOverride = 10
		dependencies.styleSettingsLabel(
			byteCounter,
			"GameFontDisableSmall"
		)
		box._gfTacticalByteCounter = byteCounter
		updateTacticalByteCounter(box, false)

		owner.tacticalMessageBoxes[index] = box
		owner.tacticalPlaceholders[index] = placeholder
		owner.tacticalByteCounters[index] = byteCounter
		previousMessageBox = box
	end
	owner.tacticalMessageBox = owner.tacticalMessageBoxes[1]
	owner.tacticalPlaceholder = owner.tacticalPlaceholders[1]

	local tacticalHint = GF.UI.CreateFontString(
		owner.tacticalEditorPanel,
		"OVERLAY",
		"GameFontHighlightSmall"
	)
	tacticalHint:SetPoint(
		"TOPLEFT",
		previousMessageBox,
		"BOTTOMLEFT",
		0,
		-10
	)
	tacticalHint:SetPoint(
		"TOPRIGHT",
		previousMessageBox,
		"BOTTOMRIGHT",
		0,
		-10
	)
	tacticalHint:SetHeight(TACTICAL_HINT_H)
	tacticalHint:SetJustifyH("LEFT")
	tacticalHint:SetJustifyV("TOP")
	tacticalHint:SetWordWrap(true)
	tacticalHint:SetText(
		L.SET_MPLUS_TACTICAL_HINT or ""
	)
	tacticalHint:SetTextColor(0.58, 0.56, 0.51, 1)
	tacticalHint._gfFontSizeOverride = META_TEXT_SIZE
	dependencies.styleSettingsLabel(
		tacticalHint,
		"GameFontHighlightSmall"
	)
	dependencies.bindSettingsLocaleText(
		tacticalHint,
		L.SET_MPLUS_TACTICAL_HINT or ""
	)

	owner.tacticalEditorStatus = GF.UI.CreateFontString(
		owner.tacticalEditorPanel,
		"OVERLAY",
		"GameFontHighlightSmall"
	)
	owner.tacticalEditorStatus:SetPoint(
		"BOTTOMLEFT",
		owner.tacticalEditorPanel,
		"BOTTOMLEFT",
		LAYOUT.editorInset,
		13
	)
	owner.tacticalEditorStatus:SetWidth(120)
	owner.tacticalEditorStatus:SetHeight(DD_H)
	owner.tacticalEditorStatus:SetJustifyH("LEFT")
	owner.tacticalEditorStatus:SetJustifyV("MIDDLE")
	owner.tacticalEditorStatus:SetWordWrap(false)
	owner.tacticalEditorStatus._gfFontSizeOverride =
		META_TEXT_SIZE
	dependencies.styleSettingsLabel(
		owner.tacticalEditorStatus,
		"GameFontHighlightSmall"
	)

	local tacticalButtonWidth =
		GF.PANEL_BUTTON_STANDARD_W or 72
	owner.tacticalClearButton = GF.UI.CreatePanelButton(
		owner.tacticalEditorPanel,
		L.SET_MPLUS_SETTING_CLEAR or "Clear",
		tacticalButtonWidth
	)
	owner.tacticalClearButton:SetPoint(
		"BOTTOMRIGHT",
		owner.tacticalEditorPanel,
		"BOTTOMRIGHT",
		-LAYOUT.editorInset,
		14
	)
	dependencies.fitSettingsText(
		owner.tacticalClearButton:GetFontString(),
		math.max(
			1,
			owner.tacticalClearButton:GetWidth() - 12
		),
		8
	)
	dependencies.bindSettingsLocaleText(
		owner.tacticalClearButton,
		L.SET_MPLUS_SETTING_CLEAR or "Clear",
		nil,
		function(target)
			dependencies.fitSettingsText(
				target:GetFontString(),
				math.max(1, target:GetWidth() - 12),
				8
			)
		end
	)
	owner.tacticalClearButton._gfSettingsTooltipLabel =
		owner.tacticalClearButton:GetFontString()
	dependencies.bindSettingsControlTooltip(
		owner.tacticalClearButton,
		L.SET_MPLUS_TACTICAL_CLEAR_HINT or ""
	)
	owner.tacticalConfirmButton = GF.UI.CreatePanelButton(
		owner.tacticalEditorPanel,
		L.SET_MPLUS_SETTING_CONFIRM or "Confirm",
		tacticalButtonWidth
	)
	owner.tacticalConfirmButton:SetPoint(
		"RIGHT",
		owner.tacticalClearButton,
		"LEFT",
		-8,
		0
	)
	dependencies.fitSettingsText(
		owner.tacticalConfirmButton:GetFontString(),
		math.max(
			1,
			owner.tacticalConfirmButton:GetWidth() - 12
		),
		8
	)
	dependencies.bindSettingsLocaleText(
		owner.tacticalConfirmButton,
		L.SET_MPLUS_SETTING_CONFIRM or "Confirm",
		nil,
		function(target)
			dependencies.fitSettingsText(
				target:GetFontString(),
				math.max(1, target:GetWidth() - 12),
				8
			)
		end
	)

	owner.tacticalConfirmButton._gfSettingsTooltipLabel =
		owner.tacticalConfirmButton:GetFontString()
	dependencies.bindSettingsControlTooltip(
		owner.tacticalConfirmButton,
		L.SET_MPLUS_TACTICAL_CONFIRM_HINT or ""
	)

	for index, box in ipairs(owner.tacticalMessageBoxes) do
		local boxIndex = index
		local currentBox = box
		box:SetScript("OnEnterPressed", function()
			local nextBox = owner.tacticalMessageBoxes[boxIndex + 1]
			if nextBox then
				nextBox:SetFocus()
			else
				currentBox:ClearFocus()
			end
		end)
		box:SetScript("OnEscapePressed", function()
			owner:DiscardTacticalDraft()
			clearTacticalEditorFocus(owner)
		end)
		box:HookScript("OnEditFocusGained", function()
			rememberTacticalLinkTarget(owner, currentBox)
			owner:UpdateTacticalEditorState()
		end)
		box:HookScript("OnEditFocusLost", function()
			releaseTacticalLinkTarget(owner, currentBox)
			owner:UpdateTacticalEditorState()
		end)
		box:HookScript("OnTextChanged", function()
			if owner._syncingTacticalMessage then
				return
			end
			owner:CaptureTacticalDraft()
			owner:UpdateTacticalEditorState()
		end)
	end
	owner.tacticalConfirmButton:SetScript(
		"OnClick",
		function()
			if owner.tacticalConfirmButton:IsEnabled()
				and owner:CommitTacticalDraft()
			then
				clearTacticalEditorFocus(owner)
			end
		end
	)
	owner.tacticalClearButton:SetScript(
		"OnClick",
		function()
			if owner.tacticalClearButton:IsEnabled()
				and owner:CommitTacticalDraft("")
			then
				clearTacticalEditorFocus(owner)
			end
		end
	)

	tacticalY = dependencies.finishSettingsSection(
		section,
		tacticalY
	)
	owner:RebuildTacticalDungeonList(
		getMythicPlusTacticalDungeons(),
		owner._preserveTacticalDraftOnInit == true
	)
	dependencies.registerSettingsRefresher(function()
		if owner:IsTacticalDraftDirty() then
			owner:UpdateTacticalEditorState()
		else
			owner:LoadTacticalDungeon(
				Presenter:GetTacticalSelection()
			)
		end
	end)
	return tacticalY
end
