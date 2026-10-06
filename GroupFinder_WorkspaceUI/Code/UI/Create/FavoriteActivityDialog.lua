local _, GF = ...
GF = GF.GF or GF

GF.FavoriteActivityDialog = GF.FavoriteActivityDialog or {}
local Dialog = GF.FavoriteActivityDialog

local STYLE = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}
local DIALOG_NAME = "GroupFinderAddonFavoriteActivityDialog"
local DIALOG_WIDTH = 480
local DIALOG_HEIGHT = 232
local CONTENT_INSET_X = STYLE.CONTENT_INSET_X or 36
local CONTENT_TOP = STYLE.CONTENT_TOP_INSET or 38
local INPUT_HEIGHT = STYLE.INPUT_HEIGHT or 30
local ACTIVITY_NAME_FONT_SIZE = 16
local FIELD_LABEL_FONT_SIZE = 13
local NOTE_FONT_SIZE = 11
local ACTIVITY_HEADER_ATLAS = "housing-basic-panel-gradient-header-bg"
local ACTIVITY_HEADER_HEIGHT = 40
local HEADER_TO_FIELD_GAP = 8
local BUTTON_WIDTH = 104
local BUTTON_HEIGHT = STYLE.BUTTON_HEIGHT or GF.PANEL_BUTTON_H or 22
local BUTTON_GAP = 14
local BOTTOM_INSET = STYLE.CONTENT_BOTTOM_INSET or 18
local DIALOG_BACKGROUND_COLOR = { 0.012, 0.01, 0.008, 1 }
local NOTE_TEXT_COLOR = { 0.68, 0.66, 0.60, 1 }
local DIM_ALPHA = 0.64
local DIALOG_FRAME_LEVEL = 1000

local function localeText(key, fallback)
	local locale = GF.L or {}
	return locale[key] or fallback
end

local function trim(value)
	if type(value) ~= "string" then
		return ""
	end
	return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function applyTextRole(
	fontString, role, justifyH, wordWrap, maxLines, fontSize)
	if GF.UI and GF.UI.ApplyPlayerContextDialogTextStyle then
		GF.UI.ApplyPlayerContextDialogTextStyle(fontString, role)
	end
	if fontSize then
		fontString._gfFontSizeOverride = fontSize
		if GF.Font and GF.Font.ApplyToFontString then
			GF.Font.ApplyToFontString(
				fontString,
				fontString._gfFontTemplate or "GameFontNormal")
		end
	end
	fontString:SetJustifyH(justifyH or "LEFT")
	if fontString.SetJustifyV then
		fontString:SetJustifyV("MIDDLE")
	end
	if fontString.SetWordWrap then
		fontString:SetWordWrap(wordWrap == true)
	end
	if fontString.SetMaxLines then
		fontString:SetMaxLines(maxLines or 1)
	end
end

local function setMainWindowDimmed(frame, dimmed)
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	if not (mainFrame and type(mainFrame.SetAlpha) == "function") then
		return
	end
	if dimmed then
		if frame._previousMainAlpha == nil then
			frame._previousMainAlpha = mainFrame.GetAlpha
				and mainFrame:GetAlpha() or 1
		end
		mainFrame:SetAlpha(DIM_ALPHA)
	elseif frame._previousMainAlpha ~= nil then
		mainFrame:SetAlpha(frame._previousMainAlpha)
		frame._previousMainAlpha = nil
	end
end

local function setCreateDrawerSuspended(frame, suspended)
	local drawer = GF.CreateDrawer
	if suspended then
		if frame._drawerSuspended ~= true
			and drawer and drawer.SuspendForModal
			and drawer:SuspendForModal(frame)
		then
			frame._drawerSuspended = true
		end
	elseif frame._drawerSuspended == true then
		frame._drawerSuspended = nil
		if drawer and drawer.ResumeFromModal then
			drawer:ResumeFromModal(frame)
		end
	end
end

local function applyTopLayer(frame)
	if frame.SetFrameStrata then
		frame:SetFrameStrata("DIALOG")
	end
	if frame.SetFrameLevel then
		frame:SetFrameLevel(DIALOG_FRAME_LEVEL)
	end
	if frame.ClosePanelButton and frame.ClosePanelButton.SetFrameLevel then
		frame.ClosePanelButton:SetFrameLevel(DIALOG_FRAME_LEVEL + 20)
	end
	if frame.Raise then
		frame:Raise()
	end
end

local function updatePlaceholder(frame)
	if not (frame and frame.nameEdit and frame.namePlaceholder) then
		return
	end
	frame.namePlaceholder:SetShown(trim(frame.nameEdit:GetText()) == "")
end

local function refreshFrame(frame)
	if not frame then
		return
	end
	local updating = frame._recordIdentity ~= nil
	local title = updating
		and localeText("FAVORITE_ACTIVITY_DIALOG_UPDATE_TITLE", "Update Favorite")
		or localeText("FAVORITE_ACTIVITY_DIALOG_ADD_TITLE", "Add to Activity Favorites")
	if GF.UI and GF.UI.ApplySettingsFrameChrome then
		GF.UI.ApplySettingsFrameChrome(frame, title)
	end
	local activityName = frame._activityName or ""
	frame.activityValue:SetText(activityName)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(
			frame.activityValue,
			math.max(1, DIALOG_WIDTH - CONTENT_INSET_X * 2),
			10)
	end
	frame.nameLabel:SetText(localeText(
		"FAVORITE_ACTIVITY_DIALOG_NAME_LABEL", "Custom alias (optional)"))
	frame.namePlaceholder:SetText(localeText(
		"FAVORITE_ACTIVITY_DIALOG_NAME_PLACEHOLDER",
		"The activity name will be used when left empty"))
	frame.securityNote:SetText(localeText(
		"FAVORITE_ACTIVITY_DIALOG_SECURITY_NOTE",
		"Due to Blizzard API limitations, group name, description, and voice chat cannot be saved."))
	frame.characterButton:SetText(localeText(
		"FAVORITE_ACTIVITY_DIALOG_CHARACTER", "Character Favorite"))
	frame.warbandButton:SetText(localeText(
		"FAVORITE_ACTIVITY_DIALOG_WARBAND", "Warband Favorite"))
	if GF.Font and GF.Font.SetFitWidth then
		for _, button in ipairs({ frame.characterButton, frame.warbandButton }) do
			local label = button.Label
				or (button.GetFontString and button:GetFontString())
			if label then
				GF.Font.SetFitWidth(label, math.max(1, BUTTON_WIDTH - 10), 8)
			end
		end
	end
	updatePlaceholder(frame)
end

local function ensureFrame()
	if Dialog.frame then
		return Dialog.frame
	end
	local UI = GF.UI
	if not (UI and UI.CreateSatelliteSettingsFrame
		and UI.CreateFontString and UI.CreatePanelButton
		and UI.CreateSelectableCopyInput)
	then
		return nil
	end
	local frame = UI.CreateSatelliteSettingsFrame({
		name = DIALOG_NAME,
		width = DIALOG_WIDTH,
		height = DIALOG_HEIGHT,
		title = localeText(
			"FAVORITE_ACTIVITY_DIALOG_ADD_TITLE",
			"Add to Activity Favorites"),
		levelOffset = STYLE.LEVEL_OFFSET or 18,
		backgroundColor = DIALOG_BACKGROUND_COLOR,
	})
	if not frame then
		return nil
	end
	frame._gfFollowMainFrameRaise = true
	frame._gfOnSatelliteFrameLayersApplied = function(self)
		applyTopLayer(self)
	end
	applyTopLayer(frame)
	frame:SetToplevel(true)

	frame.activityHeader = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
	local hasHeaderAtlas = UI.TrySetAtlas
		and UI.TrySetAtlas(frame.activityHeader, ACTIVITY_HEADER_ATLAS, false)
	if not hasHeaderAtlas then
		frame.activityHeader:SetColorTexture(0, 0, 0, 0.72)
	end
	frame.activityHeader:SetPoint(
		"TOPLEFT", frame, "TOPLEFT", CONTENT_INSET_X, -CONTENT_TOP)
	frame.activityHeader:SetPoint(
		"TOPRIGHT", frame, "TOPRIGHT", -CONTENT_INSET_X, -CONTENT_TOP)
	frame.activityHeader:SetHeight(ACTIVITY_HEADER_HEIGHT)

	frame.activityValue = UI.CreateFontString(frame, "OVERLAY", "GameFontNormal")
	applyTextRole(
		frame.activityValue,
		"primary",
		"CENTER",
		false,
		1,
		ACTIVITY_NAME_FONT_SIZE)
	frame.activityValue:SetAllPoints(frame.activityHeader)

	frame.nameLabel = UI.CreateFontString(
		frame, "OVERLAY", "GameFontNormal")
	applyTextRole(
		frame.nameLabel,
		"accent",
		"LEFT",
		false,
		1,
		FIELD_LABEL_FONT_SIZE)
	frame.nameLabel:SetPoint(
		"TOPLEFT",
		frame.activityHeader,
		"BOTTOMLEFT",
		0,
		-HEADER_TO_FIELD_GAP)
	frame.nameLabel:SetHeight(16)

	frame.nameInput, frame.nameEdit = UI.CreateSelectableCopyInput(
		frame,
		DIALOG_WIDTH - CONTENT_INSET_X * 2,
		{
			selectAllOnMouseDown = false,
			height = INPUT_HEIGHT,
			fontSize = STYLE.INPUT_EDIT_FONT_SIZE or 14,
		}
	)
	frame.nameInput:SetPoint(
		"TOPLEFT", frame.nameLabel, "BOTTOMLEFT", 0, -6)
	frame.nameInput:SetPoint(
		"RIGHT", frame, "RIGHT", -CONTENT_INSET_X, 0)
	frame.nameEdit:SetJustifyH("LEFT")
	frame.nameEdit:SetMaxLetters(48)
	frame.namePlaceholder = UI.CreateFontString(
		frame.nameInput, "OVERLAY", "GameFontDisableSmall")
	applyTextRole(frame.namePlaceholder, "secondary", "LEFT", false, 1)
	frame.namePlaceholder:SetPoint("LEFT", frame.nameInput, "LEFT", 16, 0)
	frame.namePlaceholder:SetPoint("RIGHT", frame.nameInput, "RIGHT", -16, 0)
	frame.nameEdit:HookScript("OnTextChanged", function()
		updatePlaceholder(frame)
	end)

	frame.securityNote = UI.CreateFontString(
		frame, "OVERLAY", "GameFontDisableSmall")
	applyTextRole(
		frame.securityNote,
		"secondary",
		"LEFT",
		true,
		2,
		NOTE_FONT_SIZE)
	frame.securityNote:SetTextColor(
		NOTE_TEXT_COLOR[1],
		NOTE_TEXT_COLOR[2],
		NOTE_TEXT_COLOR[3],
		NOTE_TEXT_COLOR[4])
	frame.securityNote:SetPoint(
		"TOPLEFT", frame.nameInput, "BOTTOMLEFT", 0, -8)
	frame.securityNote:SetPoint(
		"TOPRIGHT", frame.nameInput, "BOTTOMRIGHT", 0, -8)
	frame.securityNote:SetHeight(32)
	frame.securityNote:SetJustifyV("TOP")

	frame.characterButton = UI.CreatePanelButton(frame, "", BUTTON_WIDTH)
	frame.warbandButton = UI.CreatePanelButton(frame, "", BUTTON_WIDTH)
	frame.characterButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	frame.warbandButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	if UI.ApplyPlayerContextDialogButtonFont then
		UI.ApplyPlayerContextDialogButtonFont(frame.characterButton)
		UI.ApplyPlayerContextDialogButtonFont(frame.warbandButton)
	end
	frame.characterButton:SetPoint(
		"BOTTOMRIGHT", frame, "BOTTOM", -(BUTTON_GAP / 2), BOTTOM_INSET)
	frame.warbandButton:SetPoint(
		"BOTTOMLEFT", frame, "BOTTOM", BUTTON_GAP / 2, BOTTOM_INSET)

	local function selectScope(scope)
		local callback = frame._onSelectScope
		if type(callback) ~= "function" then
			return
		end
		if callback(scope, trim(frame.nameEdit:GetText())) == true then
			Dialog:Hide("confirmed")
		end
	end
	frame.characterButton:SetScript("OnClick", function()
		selectScope("character")
	end)
	frame.warbandButton:SetScript("OnClick", function()
		selectScope("warband")
	end)
	frame.nameEdit:SetScript("OnEnterPressed", function()
		-- With two affirmative destinations there is no implicit default scope.
		frame.nameEdit:ClearFocus()
	end)
	frame.nameEdit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		Dialog:Hide("cancelled")
	end)
	if frame.ClosePanelButton then
		frame.ClosePanelButton:SetScript("OnClick", function()
			Dialog:Hide("cancelled")
		end)
	end
	frame:HookScript("OnShow", function(self)
		setCreateDrawerSuspended(self, true)
		setMainWindowDimmed(self, true)
		applyTopLayer(self)
	end)
	frame:HookScript("OnHide", function(self)
		setMainWindowDimmed(self, false)
		setCreateDrawerSuspended(self, false)
		self.nameEdit:ClearFocus()
		self._activityName = nil
		self._recordIdentity = nil
		self._onSelectScope = nil
	end)

	Dialog.frame = frame
	refreshFrame(frame)
	return frame
end

function Dialog:Show(options)
	options = options or {}
	if type(options.activityName) ~= "string"
		or options.activityName == ""
		or type(options.onSelectScope) ~= "function"
	then
		return false
	end
	local frame = ensureFrame()
	if not frame then
		return false
	end
	frame._activityName = options.activityName
	frame._recordIdentity = options.recordIdentity
	frame._onSelectScope = options.onSelectScope
	frame.nameEdit:SetText(options.customName or "")
	refreshFrame(frame)
	if GF.UI and GF.UI.PresentSatelliteFrame then
		GF.UI.PresentSatelliteFrame(frame, {
			centerOnUIParent = true,
			offsetY = 20,
			refreshBackground = true,
			onShown = function()
				frame.nameEdit:SetFocus()
			end,
		})
	else
		frame:Show()
		frame.nameEdit:SetFocus()
	end
	applyTopLayer(frame)
	return frame:IsShown() == true
end

function Dialog:Hide()
	local frame = self.frame
	if frame and frame:IsShown() then
		frame:Hide()
	end
end

function Dialog:RefreshLocale()
	if self.frame then
		refreshFrame(self.frame)
	end
end
