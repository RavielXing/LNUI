local _, GF = ...

GF.SettingsTacticalPage = GF.SettingsTacticalPage or {}
local Page = GF.SettingsTacticalPage

local TACTICAL_UNSAVED_POPUP = "GF_SETTINGS_TACTICAL_UNSAVED"
local WHITE = GF.WHITE_TEXTURE
local DD_W = GF.SETTINGS_DROPDOWN_W or 260
local DD_H = GF.SETTINGS_DROPDOWN_H or 26
local TITLE_TEXT_SIZE = 16
local META_TEXT_SIZE = 12
local TACTICAL_PENDING_ATLAS = "UI-LFG-PendingMark"
local TACTICAL_READY_ATLAS = "UI-LFG-ReadyMark"

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

local PUBLIC_METHODS = {
	"ScheduleMythicPlusTacticalRebuild",
	"EnsureMythicPlusSeasonListener",
	"IsTacticalDraftDirty",
	"CaptureTacticalDraft",
	"UpdateTacticalDungeonRows",
	"UpdateTacticalEditorState",
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
	owner.tacticalPlaceholder = nil
	owner.tacticalConfirmButton = nil
	owner.tacticalClearButton = nil
	owner.tacticalEditorStatus = nil
	owner.tacticalDungeonRows = nil
	owner.tacticalDungeonByID = nil
	owner._tacticalSavedText = nil
	owner._syncingTacticalMessage = nil
	owner._pendingTacticalChallengeModeID = nil
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
	if not self._tacticalSelectedChallengeModeID
		or not self.tacticalMessageBox
	then
		return false
	end
	return (self.tacticalMessageBox:GetText() or "")
		~= (self._tacticalSavedText or "")
end

function Page:CaptureTacticalDraft()
	local challengeModeID =
		self._tacticalSelectedChallengeModeID
	if not challengeModeID or not self.tacticalMessageBox then
		return
	end
	self._tacticalDrafts = self._tacticalDrafts or {}
	local text = self.tacticalMessageBox:GetText() or ""
	if text == (self._tacticalSavedText or "") then
		self._tacticalDrafts[challengeModeID] = nil
	else
		self._tacticalDrafts[challengeModeID] = text
	end
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
	local selectedID = self._tacticalSelectedChallengeModeID
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
			local saved =
				dependencies.getMythicPlusAnnouncementValue(
					"GetTacticalAnnouncement",
					"",
					challengeModeID
				)
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

function Page:UpdateTacticalEditorState()
	local L = GF.L or {}
	local challengeModeID =
		self._tacticalSelectedChallengeModeID
	local available = challengeModeID ~= nil
		and dependencies.getMythicPlusAnnouncementService(
			"GetTacticalAnnouncement",
			"SetTacticalAnnouncement"
		) ~= nil
	local currentText = self.tacticalMessageBox
		and (self.tacticalMessageBox:GetText() or "")
		or ""
	local dirty = available
		and currentText ~= (self._tacticalSavedText or "")

	dependencies.setSettingsWidgetEnabled(
		self.tacticalMessageBox,
		available
	)
	dependencies.setSettingsWidgetEnabled(
		self.tacticalConfirmButton,
		dirty
	)
	dependencies.setSettingsWidgetEnabled(
		self.tacticalClearButton,
		available and currentText ~= ""
	)
	if self.tacticalPlaceholder then
		self.tacticalPlaceholder:SetShown(
			available
				and currentText == ""
				and not self.tacticalMessageBox:HasFocus()
		)
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
		elseif (self._tacticalSavedText or "") ~= "" then
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
end

function Page:LoadTacticalDungeon(challengeModeID)
	challengeModeID = tonumber(challengeModeID)
	local previousChallengeModeID =
		self._tacticalSelectedChallengeModeID
	self._tacticalSelectedChallengeModeID = challengeModeID
	local saved = ""
	if challengeModeID then
		saved =
			dependencies.getMythicPlusAnnouncementValue(
				"GetTacticalAnnouncement",
				"",
				challengeModeID
			)
	end
	self._tacticalSavedText = tostring(saved or "")

	local draft
	if challengeModeID and self._tacticalDrafts then
		draft = self._tacticalDrafts[challengeModeID]
	end
	if draft == nil then
		draft = self._tacticalSavedText
	end

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
	if self.tacticalMessageBox then
		self._syncingTacticalMessage = true
		self.tacticalMessageBox:SetText(draft or "")
		self._syncingTacticalMessage = nil
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
	local challengeModeID =
		self._tacticalSelectedChallengeModeID
	if not challengeModeID then
		return false
	end
	if value == nil and self.tacticalMessageBox then
		value = self.tacticalMessageBox:GetText() or ""
	end
	local ok =
		dependencies.setMythicPlusAnnouncementValue(
			"SetTacticalAnnouncement",
			challengeModeID,
			value or ""
		)
	if not ok then
		return false
	end
	self._tacticalDrafts = self._tacticalDrafts or {}
	self._tacticalDrafts[challengeModeID] = nil
	self:LoadTacticalDungeon(
		self:GetAvailableTacticalDungeonID(challengeModeID)
	)
	return true
end

function Page:DiscardTacticalDraft()
	local challengeModeID =
		self._tacticalSelectedChallengeModeID
	if not challengeModeID then
		return
	end
	self._tacticalDrafts = self._tacticalDrafts or {}
	self._tacticalDrafts[challengeModeID] = nil
	self:LoadTacticalDungeon(
		self:GetAvailableTacticalDungeonID(challengeModeID)
	)
end

function Page:ResetCurrentTacticalAnnouncements()
	Page.HideUnsavedPopup()
	self._pendingTacticalChallengeModeID = nil
	self._tacticalDrafts = {}
	local resetCount = 0
	for challengeModeID in pairs(
		self.tacticalDungeonByID or {}
	) do
		local ok =
			dependencies.setMythicPlusAnnouncementValue(
				"SetTacticalAnnouncement",
				challengeModeID,
				""
			)
		if ok then
			resetCount = resetCount + 1
		end
	end
	self:LoadTacticalDungeon(
		self:GetAvailableTacticalDungeonID(
			self._tacticalSelectedChallengeModeID
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
			settingsPanel._pendingTacticalChallengeModeID =
				nil
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
	if not challengeModeID
		or challengeModeID
			== self._tacticalSelectedChallengeModeID
		or self._pendingTacticalChallengeModeID ~= nil
	then
		return
	end
	self:CaptureTacticalDraft()
	if not self:IsTacticalDraftDirty() then
		if self.tacticalMessageBox then
			self.tacticalMessageBox:ClearFocus()
		end
		self:LoadTacticalDungeon(challengeModeID)
		return
	end

	if self.tacticalMessageBox then
		self.tacticalMessageBox:ClearFocus()
	end
	self._pendingTacticalChallengeModeID = challengeModeID
	ensureTacticalUnsavedPopup()
	if StaticPopup_Show then
		StaticPopup_Show(TACTICAL_UNSAVED_POPUP)
	end
end

function Page:ResolveTacticalSelectionPrompt(action)
	local nextChallengeModeID =
		self._pendingTacticalChallengeModeID
	if not nextChallengeModeID then
		return
	end
	if action == "save" then
		if not self:CommitTacticalDraft() then
			self._pendingTacticalChallengeModeID = nil
			return
		end
	elseif action == "discard" then
		self:DiscardTacticalDraft()
	else
		self._pendingTacticalChallengeModeID = nil
		return
	end
	if not (self.tacticalDungeonByID
		and self.tacticalDungeonByID[nextChallengeModeID])
	then
		nextChallengeModeID =
			self._tacticalFirstChallengeModeID
	end
	self._pendingTacticalChallengeModeID = nil
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
	local previousChallengeModeID =
		self._tacticalSelectedChallengeModeID
	local preservedDraft = previousChallengeModeID
		and self._tacticalDrafts
		and self._tacticalDrafts[previousChallengeModeID]
	local previousDirty = skipDraftCapture
		and preservedDraft ~= nil
		or self:IsTacticalDraftDirty()
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
				0
			)
			label:SetPoint(
				"RIGHT",
				row,
				"RIGHT",
				-LAYOUT.rowLabelInsetX,
				0
			)
			label:SetHeight(LAYOUT.rowH)
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
				0
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
				if owner._gfTooltip
					and owner._gfTooltip ~= ""
					and GF.UI
					and GF.UI.ShowSimpleTooltip
				then
					GF.UI.ShowSimpleTooltip(
						owner,
						owner._gfTooltip,
						"ANCHOR_RIGHT"
					)
				end
			end)
			row:SetScript("OnLeave", function(owner)
				owner._gfHovered = nil
				self:UpdateTacticalDungeonRows()
				GameTooltip_Hide()
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
		row._gfTooltip = row.label:GetText() or ""
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
	local section = dependencies.createSettingsSection(
		tacticalPage,
		L.SET_SECTION_MPLUS_TACTICAL
			or "Tactical announcements",
		tacticalY
	)
	dependencies.styleVisualAppearancePanel(section, true)
	section._gfRowOffset = LAYOUT.panelH
	dependencies.updateSettingsSectionHeights(section)

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
		-LAYOUT.editorInset,
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

	owner.tacticalMessageBox = CreateFrame(
		"EditBox",
		nil,
		owner.tacticalEditorPanel,
		"InputBoxTemplate"
	)
	owner.tacticalMessageBox:SetAutoFocus(false)
	owner.tacticalMessageBox:SetMultiLine(false)
	owner.tacticalMessageBox:SetMaxLetters(255)
	GF.UI.TrackEditBox(
		owner.tacticalMessageBox,
		"GameFontHighlightSmall"
	)
	dependencies.styleSettingsNumberBox(
		owner.tacticalMessageBox,
		DD_W,
		DD_H,
		false
	)
	owner.tacticalMessageBox:ClearAllPoints()
	owner.tacticalMessageBox:SetPoint(
		"TOPLEFT",
		tacticalScope,
		"BOTTOMLEFT",
		0,
		-14
	)
	owner.tacticalMessageBox:SetPoint(
		"TOPRIGHT",
		tacticalScope,
		"BOTTOMRIGHT",
		0,
		-14
	)
	owner.tacticalMessageBox:SetHeight(DD_H)
	owner.tacticalMessageBox:SetJustifyH("LEFT")
	if owner.tacticalMessageBox.SetTextInsets then
		owner.tacticalMessageBox:SetTextInsets(8, 8, 0, 0)
	end
	dependencies.bindSettingsControlTooltip(
		owner.tacticalMessageBox,
		L.SET_MPLUS_TACTICAL_HINT or ""
	)

	owner.tacticalPlaceholder = GF.UI.CreateFontString(
		owner.tacticalMessageBox,
		"OVERLAY",
		"GameFontDisableSmall"
	)
	owner.tacticalPlaceholder:SetPoint(
		"LEFT",
		owner.tacticalMessageBox,
		"LEFT",
		8,
		0
	)
	owner.tacticalPlaceholder:SetPoint(
		"RIGHT",
		owner.tacticalMessageBox,
		"RIGHT",
		-8,
		0
	)
	owner.tacticalPlaceholder:SetHeight(DD_H)
	owner.tacticalPlaceholder:SetJustifyH("LEFT")
	owner.tacticalPlaceholder:SetJustifyV("MIDDLE")
	owner.tacticalPlaceholder:SetWordWrap(false)
	owner.tacticalPlaceholder:SetText(
		L.SET_MPLUS_TACTICAL_PLACEHOLDER or ""
	)
	owner.tacticalPlaceholder:SetTextColor(
		0.48,
		0.46,
		0.42,
		1
	)
	owner.tacticalPlaceholder._gfFontSizeOverride =
		META_TEXT_SIZE
	dependencies.styleSettingsLabel(
		owner.tacticalPlaceholder,
		"GameFontDisableSmall"
	)
	dependencies.bindSettingsLocaleText(
		owner.tacticalPlaceholder,
		L.SET_MPLUS_TACTICAL_PLACEHOLDER or ""
	)
	dependencies.bindSettingsTextFit(
		owner.tacticalMessageBox,
		owner.tacticalPlaceholder,
		16,
		9
	)

	local tacticalHint = GF.UI.CreateFontString(
		owner.tacticalEditorPanel,
		"OVERLAY",
		"GameFontHighlightSmall"
	)
	tacticalHint:SetPoint(
		"TOPLEFT",
		owner.tacticalMessageBox,
		"BOTTOMLEFT",
		0,
		-10
	)
	tacticalHint:SetPoint(
		"TOPRIGHT",
		owner.tacticalMessageBox,
		"BOTTOMRIGHT",
		0,
		-10
	)
	tacticalHint:SetHeight(42)
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

	owner.tacticalMessageBox:SetScript(
		"OnEnterPressed",
		function(box)
			if owner:CommitTacticalDraft() then
				box:ClearFocus()
			end
		end
	)
	owner.tacticalMessageBox:SetScript(
		"OnEscapePressed",
		function(box)
			owner:DiscardTacticalDraft()
			box:ClearFocus()
		end
	)
	owner.tacticalMessageBox:HookScript(
		"OnEditFocusGained",
		function()
			owner:UpdateTacticalEditorState()
		end
	)
	owner.tacticalMessageBox:HookScript(
		"OnEditFocusLost",
		function()
			owner:UpdateTacticalEditorState()
		end
	)
	owner.tacticalMessageBox:HookScript(
		"OnTextChanged",
		function()
			if not owner._syncingTacticalMessage then
				owner:CaptureTacticalDraft()
				owner:UpdateTacticalEditorState()
			end
		end
	)
	owner.tacticalConfirmButton:SetScript(
		"OnClick",
		function()
			if owner.tacticalConfirmButton:IsEnabled()
				and owner:CommitTacticalDraft()
				and owner.tacticalMessageBox
			then
				owner.tacticalMessageBox:ClearFocus()
			end
		end
	)
	owner.tacticalClearButton:SetScript(
		"OnClick",
		function()
			if owner.tacticalClearButton:IsEnabled()
				and owner:CommitTacticalDraft("")
				and owner.tacticalMessageBox
			then
				owner.tacticalMessageBox:ClearFocus()
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
				owner._tacticalSelectedChallengeModeID
			)
		end
	end)
	return tacticalY
end
