local _, GF = ...

local CP = {}
GF.CreatePanel = CP

local BB = GF.BlizzardBorrow
local DEFAULT_PLAYSTYLE = Enum.LFGEntryGeneralPlaystyle.Learning
local DEFAULT_REQUIRED_DUNGEON_SCORE = 0

local PLAYSTYLE_OPTIONS = {
	{ id = Enum.LFGEntryGeneralPlaystyle.Learning, textKey = "GROUP_FINDER_GENERAL_PLAYSTYLE1" },
	{ id = Enum.LFGEntryGeneralPlaystyle.FunRelaxed, textKey = "GROUP_FINDER_GENERAL_PLAYSTYLE2" },
	{ id = Enum.LFGEntryGeneralPlaystyle.FunSerious, textKey = "GROUP_FINDER_GENERAL_PLAYSTYLE3" },
	{ id = Enum.LFGEntryGeneralPlaystyle.Expert, textKey = "GROUP_FINDER_GENERAL_PLAYSTYLE4" },
}

local function playstyleText(option)
	local translated = option and _G[option.textKey]
	return translated or tostring(option and option.id or "")
end

local function selectedPlaystyleText(styleID)
	for optionIndex = 1, #PLAYSTYLE_OPTIONS do
		local option = PLAYSTYLE_OPTIONS[optionIndex]
		if option.id == styleID then
			return playstyleText(option)
		end
	end
	return ""
end

local function trimName(text)
	local value = type(text) == "string" and text or ""
	return value:match("^%s*(.-)%s*$") or ""
end

-- Blizzard LFGList EntryCreation (LFGList.xml): Name 288×22, Description 283×46
local NATIVE_FIELD_SIZE = {
	name = { width = 288, height = 22 },
	description = { width = 283, height = 46 },
}
-- InputScrollFrame border textures extend 5px outside the frame bounds
local FIELD_EDGE_PAD = 6
local REQ_EDIT_W = 125
local REQ_EDIT_H = 26
local FIELD_GAP = 0
local LABEL_FIELD_GAP = 4
local DESC_FIELD_GAP = 0
local CONTENT_PAD = 4
local CREATE_PAD = 4
local FORM_LEFT_INSET = 4
local CREATE_FORM_INSET_X = 16
local CREATE_FORM_INSET_TOP = 8
local CREATE_FORM_ROW_H = 36
local CREATE_FORM_STACK_LABEL_GAP = 5
local CREATE_FORM_STACK_ROW_GAP = 10
local CREATE_FORM_TITLE_SIZE = GF.CREATE_MANAGER_TITLE_TEXT_SIZE
	or GF.SECTION_HEADER_TEXT_SIZE
	or 14
local CREATE_FORM_TITLE_COLOR = GF.CREATE_MANAGER_TITLE_TEXT_COLOR
	or GF.BROWSE_HEADER_TEXT_COLOR
	or { 1, 0.82, 0, 1 }
local CREATE_MANAGER_DISABLED_VISUAL =
	GF.CREATE_MANAGER_DISABLED_VISUAL or {}
local CREATE_FORM_DISABLED_TITLE_COLOR =
	CREATE_MANAGER_DISABLED_VISUAL.labelTextColor
	or { 0.72, 0.70, 0.64, 1 }
local CREATE_FORM_INPUT_TEXT_COLOR = { 1, 0.92, 0.64, 1 }
local CREATE_FORM_DISABLED_INPUT_TEXT_COLOR =
	CREATE_MANAGER_DISABLED_VISUAL.inputTextColor
	or { 0.78, 0.77, 0.72, 1 }
local CREATE_FORM_DISABLED_ATLAS_TINT =
	CREATE_MANAGER_DISABLED_VISUAL.atlasTint
	or GF.FILTER_DISABLED_ICON_TINT
	or 0.58
local CREATE_FORM_DISABLED_ATLAS_DESATURATED =
	CREATE_MANAGER_DISABLED_VISUAL.desaturated ~= false
local CREATE_FORM_DISABLED_ALPHA =
	tonumber(CREATE_MANAGER_DISABLED_VISUAL.alpha) or 1
local MPLUS_LFG_SIDEBAR_CONTROL_W =
	GF.MPLUS_LFG_SIDEBAR_CONTROL_W
	or ((GF.NAV_WIDTH or 180) - 16)
local CREATE_FORM_INPUT_H = 26
local CREATE_FORM_DESC_H = NATIVE_FIELD_SIZE.description.height
local CREATE_FORM_DESC_ATLAS_PAD_Y = 4
local CREATE_FORM_DESC_ATLAS_H = CREATE_FORM_DESC_H + (CREATE_FORM_DESC_ATLAS_PAD_Y * 2)
local CREATE_SIDEBAR_SECTION_TITLE_H = 16
local CREATE_SIDEBAR_LABEL_CONTROL_GAP = 4
local CREATE_SIDEBAR_BLOCK_GAP = 6
local CREATE_PLACEHOLDER_LEFT_INSET = 4
local BUTTON_BAR_H = 70
local LIST_BTN_BOTTOM = BUTTON_BAR_H - 5 - 22
local LIST_BTN_W = GF.PANEL_BUTTON_STANDARD_W or 72
local LIST_BTN_GAP = GF.FILTER_FOOTER_BUTTON_GAP or 10
local DROPDOWN_H = 26
local DROPDOWN_LEFT_NUDGE = 0
local REQ_FIELD_LEFT_NUDGE = 3
local CREATE_CHECK_SIZE = 20
local CREATE_CHECK_LABEL_GAP = 8
local CREATE_DESC_ATLAS_BORDER_KEYS = {
	"topLeft",
	"top",
	"topRight",
	"left",
	"right",
	"bottomLeft",
	"bottom",
	"bottomRight",
}
local GREEN = "|cff00ff00"
local COLOR_END = "|r"
local CREATE_FIELD_OWNER = "groupfinder"
local CREATE_FIELD_CHANNEL = "entryCreation"
local CREATE_BLOCKED_TEXT_INSET_X = 14

local function formatGreen(text)
	return GREEN .. tostring(text or "") .. COLOR_END
end

local function getLoadingCycleSeconds()
	return ((GF.BROWSE_LOADING_STEP_SECONDS or 0.28) * (GF.BROWSE_LOADING_ICON_COUNT or 3))
		+ (GF.BROWSE_LOADING_HOLD_SECONDS or 0.4)
		+ (GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45)
end

local function getLoadingIconAlpha(elapsed, iconIndex)
	local stepSeconds = GF.BROWSE_LOADING_STEP_SECONDS or 0.28
	local fadeInSeconds = GF.BROWSE_LOADING_FADE_IN_SECONDS or 0.16
	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local holdSeconds = GF.BROWSE_LOADING_HOLD_SECONDS or 0.4
	local fadeOutSeconds = GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45
	local appearAt = (iconIndex - 1) * stepSeconds
	if elapsed < appearAt then
		return 0
	end
	local fadeInEnd = appearAt + fadeInSeconds
	if elapsed < fadeInEnd then
		return math.max(0, math.min(1, (elapsed - appearAt) / fadeInSeconds))
	end
	local fadeOutStart = (stepSeconds * iconCount) + holdSeconds
	if elapsed < fadeOutStart then
		return 1
	end
	local fadeOutEnd = fadeOutStart + fadeOutSeconds
	if elapsed < fadeOutEnd then
		return math.max(0, math.min(1, 1 - ((elapsed - fadeOutStart) / fadeOutSeconds)))
	end
	return 0
end

local function refreshLoadingAnimation(animation)
	if not (animation and animation.icons) then
		return
	end
	local elapsed = animation.elapsed or 0
	for index, icon in ipairs(animation.icons) do
		local alpha = getLoadingIconAlpha(elapsed, index)
		icon:SetAlpha(alpha)
		if alpha > 0.02 then
			icon:Show()
		else
			icon:Hide()
		end
	end
end

local function getPlayerFactionName()
	local factionTag, localizedFaction = UnitFactionGroup("player")
	if localizedFaction and localizedFaction ~= "" then
		return localizedFaction
	end
	local L = GF.L or {}
	if factionTag == "Horde" then
		return L.FACTION_HORDE or "部落"
	end
	return L.FACTION_ALLIANCE or "联盟"
end

local function getFactionRestrictionLabel()
	local L = GF.L or {}
	return (L.CROSS_FACTION_FMT or "仅限%s"):format(getPlayerFactionName())
end

local function getFactionRestrictionTip()
	local L = GF.L or {}
	local faction = getPlayerFactionName()
	return (L.CROSS_FACTION_TIP_FMT or "仅%s玩家可以看到你的招募队伍，可能会减少申请数量。"):format(formatGreen(faction))
end

local function getDefaultRequiredItemLevel()
	if GF.GetDefaultRequiredItemLevel then
		return GF.GetDefaultRequiredItemLevel()
	end
	return GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0
end

local function showCreateOptionTooltip(owner, title, text)
	if not owner or not text or text == "" or not GameTooltip then
		return
	end
	GF.UI.BeginGameTooltip(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	if title and title ~= "" then
		GameTooltip:AddLine(title, 1, 0.82, 0, true)
	end
	GameTooltip:AddLine(text, 1, 1, 1, true)
	GF.UI.ShowGameTooltip()
end

local function setCheckHitRectToLabel(check, label)
	if not check or not label or not check.SetHitRectInsets then
		return
	end
	local width = label.GetStringWidth and label:GetStringWidth() or 0
	check:SetHitRectInsets(0, -math.ceil(width + CREATE_CHECK_LABEL_GAP + 4), 0, 0)
end

local function hideRegion(region)
	if not region then
		return
	end
	if region.Hide then
		region:Hide()
	end
	if region.SetAlpha then
		region:SetAlpha(0)
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
			hideRegion(region)
		end
	end
	hideRegion(editBox.Left)
	hideRegion(editBox.Middle)
	hideRegion(editBox.Right)
	hideRegion(editBox.LeftTexture)
	hideRegion(editBox.MiddleTexture)
	hideRegion(editBox.RightTexture)
end

local function getInputBoxChromeRegions(editBox)
	if not editBox then
		return {}
	end
	local regions = {}
	local function add(region)
		if region then
			regions[#regions + 1] = region
		end
	end
	local name = editBox.GetName and editBox:GetName()
	if name then
		add(_G[name .. "Left"])
		add(_G[name .. "Middle"])
		add(_G[name .. "Right"])
		add(_G[name .. "LeftTexture"])
		add(_G[name .. "MiddleTexture"])
		add(_G[name .. "RightTexture"])
	end
	add(editBox.Left)
	add(editBox.Middle)
	add(editBox.Right)
	add(editBox.LeftTexture)
	add(editBox.MiddleTexture)
	add(editBox.RightTexture)
	return regions
end

local function hideBorrowedNameChrome(editBox)
	if not editBox then
		return
	end
	if not editBox._gfNameChromeState then
		editBox._gfNameChromeState = {}
		for _, region in ipairs(getInputBoxChromeRegions(editBox)) do
			editBox._gfNameChromeState[region] = {
				shown = not region.IsShown or region:IsShown(),
				alpha = region.GetAlpha and region:GetAlpha() or nil,
			}
		end
	end
	for region in pairs(editBox._gfNameChromeState) do
		hideRegion(region)
	end
end

local function restoreBorrowedNameChrome(editBox)
	local state = editBox and editBox._gfNameChromeState
	if not state then
		return
	end
	for region, info in pairs(state) do
		if info.alpha ~= nil and region.SetAlpha then
			region:SetAlpha(info.alpha)
		end
		if info.shown and region.Show then
			region:Show()
		elseif region.Hide then
			region:Hide()
		end
	end
	editBox._gfNameChromeState = nil
end

local function hideBorrowedWidgetChrome(widget, stateKey)
	if not widget then
		return
	end
	stateKey = stateKey or "_gfBorrowedChromeState"
	if not widget[stateKey] then
		widget[stateKey] = {}
		for _, region in ipairs({ widget:GetRegions() }) do
			if region and region._gfCreatePlaceholder ~= true then
				widget[stateKey][region] = {
					shown = not region.IsShown or region:IsShown(),
					alpha = region.GetAlpha and region:GetAlpha() or nil,
				}
			end
		end
	end
	for region in pairs(widget[stateKey]) do
		hideRegion(region)
	end
end

local function restoreBorrowedWidgetChrome(widget, stateKey)
	stateKey = stateKey or "_gfBorrowedChromeState"
	local state = widget and widget[stateKey]
	if not state then
		return
	end
	for region, info in pairs(state) do
		if info.alpha ~= nil and region.SetAlpha then
			region:SetAlpha(info.alpha)
		end
		if info.shown and region.Show then
			region:Show()
		elseif region.Hide then
			region:Hide()
		end
	end
	widget[stateKey] = nil
end

local function captureBorrowedWidgetInteraction(widget)
	if not widget or widget._gfBorrowedInteractionState then
		return
	end
	local state = {}
	if widget.IsEnabled then
		state.enabled = widget:IsEnabled() == true
	end
	if widget.IsMouseEnabled then
		state.mouseEnabled = widget:IsMouseEnabled() == true
	end
	widget._gfBorrowedInteractionState = state
end

local function restoreBorrowedWidgetInteraction(widget)
	local state = widget and widget._gfBorrowedInteractionState
	if not state then
		return
	end
	if state.enabled ~= nil and widget.SetEnabled then
		widget:SetEnabled(state.enabled)
	end
	if state.mouseEnabled ~= nil and widget.EnableMouse then
		widget:EnableMouse(state.mouseEnabled)
	end
	widget._gfBorrowedInteractionState = nil
end

local function widgetShown(widget)
	return widget ~= nil and (
		type(widget.IsShown) ~= "function" or widget:IsShown() == true
	)
end

local function setWidgetShown(widget, shown)
	if widget ~= nil and type(widget.SetShown) == "function" then
		widget:SetShown(shown == true)
	end
end

local function applyGroupFinderProtectedFieldGate(widget, formEnabled)
	if widget ~= nil and formEnabled ~= true
		and type(widget.SetEnabled) == "function"
	then
		widget:SetEnabled(false)
	end
end

local function applyProtectedCreationGate(creation, formEnabled)
	if creation == nil then
		return
	end
	applyGroupFinderProtectedFieldGate(creation.Name, formEnabled)
	applyGroupFinderProtectedFieldGate(
		creation.Description and creation.Description.EditBox,
		formEnabled
	)
	applyGroupFinderProtectedFieldGate(
		creation.VoiceChat and creation.VoiceChat.EditBox,
		formEnabled
	)
end

local function captureFrameLayout(frame)
	if frame == nil or type(frame.GetParent) ~= "function" then
		return nil
	end
	local layout = {
		parent = frame:GetParent(),
		anchors = {},
	}
	local pointCount = type(frame.GetNumPoints) == "function"
		and frame:GetNumPoints() or 0
	for pointIndex = 1, pointCount do
		local point, relativeTo, relativePoint, offsetX, offsetY =
			frame:GetPoint(pointIndex)
		layout.anchors[pointIndex] = {
			point = point,
			relativeTo = relativeTo,
			relativePoint = relativePoint,
			offsetX = offsetX,
			offsetY = offsetY,
		}
	end
	if type(frame.GetSize) == "function" then
		layout.width, layout.height = frame:GetSize()
	end
	return layout
end

local function restoreFrameLayout(frame, layout, restoreParent)
	if frame == nil or layout == nil then
		return false
	end
	if restoreParent ~= false then
		frame:SetParent(layout.parent)
	elseif frame:GetParent() ~= layout.parent then
		return false
	end
	frame:ClearAllPoints()
	for pointIndex = 1, #layout.anchors do
		local anchor = layout.anchors[pointIndex]
		frame:SetPoint(
			anchor.point,
			anchor.relativeTo,
			anchor.relativePoint,
			anchor.offsetX,
			anchor.offsetY
		)
	end
	if type(layout.width) == "number" and layout.width > 0
		and type(layout.height) == "number" and layout.height > 0
	then
		frame:SetSize(layout.width, layout.height)
	end
	return true
end

local function captureProjectedField(field, stateKey)
	if field == nil or field[stateKey] ~= nil then
		return
	end
	field[stateKey] = {
		shown = widgetShown(field),
		layout = captureFrameLayout(field),
	}
end

local function restoreProjectedField(field, stateKey)
	local state = field and field[stateKey]
	if state == nil then
		return false
	end
	restoreFrameLayout(field, state.layout, false)
	setWidgetShown(field, state.shown)
	field[stateKey] = nil
	return true
end

local function captureEntryCreationProjection(creation)
	if creation == nil or creation._gfEntryCreationBorrowState ~= nil then
		return
	end
	local state = {
		shown = widgetShown(creation),
		layout = captureFrameLayout(creation),
	}
	if type(creation.GetFrameLevel) == "function" then
		state.frameLevel = creation:GetFrameLevel()
	end
	if type(creation.GetFrameStrata) == "function" then
		state.frameStrata = creation:GetFrameStrata()
	end
	creation._gfEntryCreationBorrowState = state
	captureProjectedField(creation.Name, "_gfCreateNameBorrowState")
	captureProjectedField(
		creation.Description,
		"_gfCreateDescriptionBorrowState"
	)
end

local function embedEntryCreationContainer(creation, host)
	if creation == nil or host == nil then
		return false
	end
	creation:SetParent(host)
	creation:ClearAllPoints()
	creation:SetPoint("TOPLEFT", host, "TOPLEFT")
	creation:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT")
	if type(creation.SetFrameLevel) == "function"
		and type(host.GetFrameLevel) == "function"
	then
		creation:SetFrameLevel(host:GetFrameLevel() + 2)
	end
	BB.MarkBorrowed(
		creation,
		CREATE_FIELD_OWNER,
		CREATE_FIELD_CHANNEL
	)
	return true
end

local function activitySelectionIsLive(activityID, categoryID, questID)
	if activityID == nil or categoryID == nil then
		return false
	end
	local readActivity = C_LFGList and C_LFGList.GetActivityInfoTable
	if type(readActivity) ~= "function" then
		return false
	end
	local activityOK, activityInfo = pcall(readActivity, activityID, questID)
	if not activityOK or type(activityInfo) ~= "table"
		or activityInfo.categoryID ~= categoryID
	then
		return false
	end
	if questID ~= nil then
		-- Blizzard's Name OnTextChanged path calls UpdateValidState, which reads
		-- selectedActivity without forwarding questID.  Refuse the temporary
		-- context unless that exact native validation lookup is also safe.
		local bareOK, bareActivity = pcall(readActivity, activityID)
		if not bareOK or type(bareActivity) ~= "table"
			or bareActivity.categoryID ~= categoryID
		then
			return false
		end
	end
	return true
end

local function showEntryCreationForAddon(creation)
	if creation == nil or creation.selectedActivity == nil
		or creation.selectedCategory == nil
		or type(creation.Show) ~= "function"
	then
		return false
	end
	if not activitySelectionIsLive(
		creation.selectedActivity,
		creation.selectedCategory
	) then
		return false
	end
	creation._gfShowingBorrowedEntryCreation = true
	local shown = pcall(creation.Show, creation)
	creation._gfShowingBorrowedEntryCreation = nil
	return shown
end

local function restoreEntryCreationContainer(creation)
	local state = creation and creation._gfEntryCreationBorrowState
	if state == nil then
		return nil
	end
	restoreFrameLayout(creation, state.layout)
	if state.frameStrata ~= nil
		and type(creation.SetFrameStrata) == "function"
	then
		creation:SetFrameStrata(state.frameStrata)
	end
	if state.frameLevel ~= nil
		and type(creation.SetFrameLevel) == "function"
	then
		creation:SetFrameLevel(state.frameLevel)
	end
	BB.ClearBorrowed(
		creation,
		CREATE_FIELD_OWNER,
		CREATE_FIELD_CHANNEL
	)
	creation._gfEntryCreationBorrowState = nil
	return state.shown
end

local function captureBorrowedVoiceProjection(voice)
	if voice == nil or voice._gfVoiceBorrowState ~= nil then
		return
	end
	local editBox = voice.EditBox
	local state = {
		shown = widgetShown(voice),
		editShown = widgetShown(editBox),
		checkShown = widgetShown(voice.CheckButton),
		labelShown = widgetShown(voice.Label),
		warningShown = widgetShown(voice.WarningFrame),
		layout = captureFrameLayout(voice),
		editLayout = captureFrameLayout(editBox),
	}
	if type(voice.GetFrameLevel) == "function" then
		state.frameLevel = voice:GetFrameLevel()
	end
	if type(voice.GetFrameStrata) == "function" then
		state.frameStrata = voice:GetFrameStrata()
	end
	voice._gfVoiceBorrowState = state
	captureBorrowedWidgetInteraction(voice)
	captureBorrowedWidgetInteraction(editBox)
	captureBorrowedWidgetInteraction(voice.CheckButton)
end

local function restoreBorrowedVoiceProjection(voice)
	local state = voice and voice._gfVoiceBorrowState
	if state == nil then
		return nil
	end
	local editBox = voice.EditBox
	restoreBorrowedNameChrome(editBox)
	restoreFrameLayout(editBox, state.editLayout, false)
	restoreBorrowedWidgetInteraction(editBox)
	restoreBorrowedWidgetInteraction(voice.CheckButton)
	restoreBorrowedWidgetInteraction(voice)
	setWidgetShown(editBox, state.editShown)
	setWidgetShown(voice.CheckButton, state.checkShown)
	setWidgetShown(voice.Label, state.labelShown)
	setWidgetShown(voice.WarningFrame, state.warningShown)
	if state.frameStrata ~= nil and type(voice.SetFrameStrata) == "function" then
		voice:SetFrameStrata(state.frameStrata)
	end
	if state.frameLevel ~= nil and type(voice.SetFrameLevel) == "function" then
		voice:SetFrameLevel(state.frameLevel)
	end
	restoreFrameLayout(voice, state.layout, false)
	voice._gfVoiceBorrowState = nil
	return state.shown
end

local function captureEntryCreationInteraction(ec)
	if not ec then
		return
	end
	captureBorrowedWidgetInteraction(ec.Name)
	captureBorrowedWidgetInteraction(ec.Description)
	captureBorrowedWidgetInteraction(
		ec.Description and ec.Description.EditBox
	)
	captureBorrowedWidgetInteraction(ec.VoiceChat)
	captureBorrowedWidgetInteraction(
		ec.VoiceChat and ec.VoiceChat.EditBox
	)
	captureBorrowedWidgetInteraction(
		ec.VoiceChat and ec.VoiceChat.CheckButton
	)
end

local function restoreEntryCreationInteraction(ec)
	if not ec then
		return
	end
	restoreBorrowedWidgetInteraction(ec.Name)
	restoreBorrowedWidgetInteraction(ec.Description)
	restoreBorrowedWidgetInteraction(
		ec.Description and ec.Description.EditBox
	)
	restoreBorrowedWidgetInteraction(ec.VoiceChat)
	restoreBorrowedWidgetInteraction(
		ec.VoiceChat and ec.VoiceChat.EditBox
	)
	restoreBorrowedWidgetInteraction(
		ec.VoiceChat and ec.VoiceChat.CheckButton
	)
	if ec.selectedActivity ~= nil
		and type(LFGListEntryCreation_UpdateAuthenticatedState) == "function"
	then
		pcall(LFGListEntryCreation_UpdateAuthenticatedState, ec)
	end
	if ec.Name and ec.Name.UpdateEnabledState then
		pcall(ec.Name.UpdateEnabledState, ec.Name)
	end
	if ec.Description and ec.Description.UpdateEnabledState then
		pcall(ec.Description.UpdateEnabledState, ec.Description)
	end
end

local function setCreateAtlasPieceVisual(piece, enabled)
	if not piece then
		return
	end
	local createManagerDisabled = not enabled
		and CP
		and CP.IsCreateManagerSurface
		and CP:IsCreateManagerSurface()
	if piece.SetDesaturated then
		piece:SetDesaturated(
			createManagerDisabled
				and CREATE_FORM_DISABLED_ATLAS_DESATURATED
				or false
		)
	end
	local tint = createManagerDisabled
		and CREATE_FORM_DISABLED_ATLAS_TINT
		or 1
	local alpha = createManagerDisabled
		and CREATE_FORM_DISABLED_ALPHA
		or (enabled and 1 or 0.45)
	piece:SetVertexColor(
		tint,
		tint,
		tint,
		alpha
	)
	if piece.SetAlpha then
		piece:SetAlpha(
			createManagerDisabled
				and CREATE_FORM_DISABLED_ALPHA
				or 1
		)
	end
end

local function setCreateControlChromeVisual(frame, chrome, enabled)
	if not chrome then
		return
	end
	local createManagerDisabled = not enabled
		and CP
		and CP.IsCreateManagerSurface
		and CP:IsCreateManagerSurface()
	if frame
		and GF.UI
		and GF.UI.SetControlCardChromeEnabledVisual
	then
		GF.UI.SetControlCardChromeEnabledVisual(frame, enabled, {
			disabledTint = createManagerDisabled
				and CREATE_FORM_DISABLED_ATLAS_TINT
				or 1,
			alpha = createManagerDisabled
				and CREATE_FORM_DISABLED_ALPHA
				or (enabled and 1 or 0.45),
			desaturated = createManagerDisabled
				and CREATE_FORM_DISABLED_ATLAS_DESATURATED
				or false,
			textureAlpha = createManagerDisabled
				and CREATE_FORM_DISABLED_ALPHA
				or 1,
		})
		return
	end
	for _, key in ipairs(CREATE_DESC_ATLAS_BORDER_KEYS) do
		setCreateAtlasPieceVisual(chrome.border and chrome.border[key], enabled)
	end
	setCreateAtlasPieceVisual(chrome.center, enabled)
end

local function updateCreateInputBox(box)
	if not box or not box._gfCreateInputStyled then
		return
	end
	local enabled = not box.IsEnabled or box:IsEnabled()
	local active = enabled and (box:HasFocus() or box._gfCreateInputHovered)
	local useDisabledText = not enabled
		and CP
		and CP.IsCreateManagerSurface
		and CP:IsCreateManagerSurface()
	local textColor = useDisabledText
		and CREATE_FORM_DISABLED_INPUT_TEXT_COLOR
		or CREATE_FORM_INPUT_TEXT_COLOR
	box:SetTextColor(
		textColor[1] or 1,
		textColor[2] or 1,
		textColor[3] or 1,
		textColor[4] or 1
	)
	local chrome = GF.UI.ApplyFilterInputChrome(
		box,
		active and "hover" or "normal"
	)
	setCreateControlChromeVisual(box, chrome, enabled)
end

local function updateCreateInputAtlasFrame(frame, active, enabled)
	if not frame then
		return
	end
	enabled = enabled ~= false
	local chrome = GF.UI.ApplyFilterInputChrome(
		frame,
		active and "hover" or "normal"
	)
	setCreateControlChromeVisual(frame, chrome, enabled)
end

local function updateCreateDescriptionAtlasFrame(frame, active, enabled)
	if not frame then
		return
	end
	enabled = enabled ~= false
	local chrome = GF.UI.ApplyFilterMultilineInputChrome(
		frame,
		active and "hover" or "normal",
		{
			layer = "BACKGROUND",
			subLevel = -6,
			centerLayer = "BACKGROUND",
			centerSubLevel = -7,
		}
	)
	if not chrome then
		return
	end
	frame._gfCreateDescAtlas = chrome
	setCreateControlChromeVisual(frame, chrome, enabled)
end

local function styleCreateInputAtlasFrame(frame)
	if not frame then
		return frame
	end
	updateCreateInputAtlasFrame(frame, false, true)
	return frame
end

local function styleCreateDescriptionAtlasFrame(frame)
	if not frame then
		return frame
	end
	updateCreateDescriptionAtlasFrame(frame, false, true)
	return frame
end

local function isDescriptionEnabled(descFrame)
	if not descFrame then
		return false
	end
	if descFrame.IsEnabled and not descFrame:IsEnabled() then
		return false
	end
	local editBox = descFrame.EditBox
	if editBox and editBox.IsEnabled and not editBox:IsEnabled() then
		return false
	end
	return true
end

local function updateBorrowedDescriptionAtlas(descFrame)
	local enabled = isDescriptionEnabled(descFrame)
	local editBox = descFrame and descFrame.EditBox
	local active = enabled and ((editBox and editBox.HasFocus and editBox:HasFocus()) or descFrame._gfCreateDescHovered)
	updateCreateDescriptionAtlasFrame(CP.descAtlasAnchor, active, enabled)
end

local function setCreateInputHovered(box, hovered)
	if not box then
		return
	end
	box._gfCreateInputHovered = hovered
	updateCreateInputBox(box)
end

local function styleCreateInputBox(box)
	if not box then
		return box
	end
	if box.SetTextInsets then
		box:SetTextInsets(6, 6, 0, 0)
	end
	box:SetTextColor(
		CREATE_FORM_INPUT_TEXT_COLOR[1],
		CREATE_FORM_INPUT_TEXT_COLOR[2],
		CREATE_FORM_INPUT_TEXT_COLOR[3],
		CREATE_FORM_INPUT_TEXT_COLOR[4]
	)
	box:SetShadowColor(0, 0, 0, 0.85)
	box:SetShadowOffset(1, -1)
	hideInputBoxChrome(box)
	if not box._gfCreateInputStyled then
		box:HookScript("OnEditFocusGained", updateCreateInputBox)
		box:HookScript("OnEditFocusLost", updateCreateInputBox)
		box:HookScript("OnShow", updateCreateInputBox)
		box:HookScript("OnEnable", updateCreateInputBox)
		box:HookScript("OnDisable", updateCreateInputBox)
		box:HookScript("OnEnter", function(self)
			setCreateInputHovered(self, true)
		end)
		box:HookScript("OnLeave", function(self)
			setCreateInputHovered(self, false)
		end)
		box._gfCreateInputStyled = true
	end
	updateCreateInputBox(box)
	return box
end

local function applyCreateTitleTextStyle(fs, color)
	if not fs then
		return
	end
	fs._gfFontSizeOverride = CREATE_FORM_TITLE_SIZE
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fs, fs._gfFontTemplate or "GameFontNormal")
	end
	color = color or CREATE_FORM_TITLE_COLOR
	fs:SetTextColor(
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		color[4] or 1
	)
end

local function getCreateDrawerFooter(parent)
	return parent and parent._gfCreateDrawerFooter
end

local function createDrawerScrollInsetR()
	return (GF.CONTENT_SCROLL_INSET_R or 18) + 2
end

local function createDrawerScrollBarOffsetX(scrollInsetR)
	return math.max(
		0,
		(scrollInsetR or createDrawerScrollInsetR())
			- (GF.FILTER_SCROLLBAR_RIGHT_INSET or 4)
			- (GF.FILTER_SCROLLBAR_WIDTH or 8)
	)
end

local function anchorCreateDrawerScrollBar(scroll, bar, offsetX)
	if not scroll or not bar then
		return
	end
	if bar.SetWidth then
		bar:SetWidth(GF.FILTER_SCROLLBAR_WIDTH or 8)
	end
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", offsetX, -(GF.FILTER_SCROLLBAR_TOP_INSET or 4))
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", offsetX, GF.FILTER_SCROLLBAR_BOTTOM_INSET or 4)
end

local function editBoxIsEmptyByLetterCount(editBox)
	local getNumLetters = editBox and editBox.GetNumLetters
	if type(getNumLetters) ~= "function" then
		return nil
	end
	local ok, count = pcall(getNumLetters, editBox)
	if not ok or type(count) ~= "number" then
		return nil
	end
	return count == 0
end

local function restoreNativeInstructions(editBox)
	local ins = editBox and editBox.Instructions
	if not ins then
		return
	end
	if ins._gfOriginalShow then
		ins.Show = ins._gfOriginalShow
		ins._gfOriginalShow = nil
	end
	editBox._gfUseCreatePlaceholder = nil
end

local function suppressNativeInstructions(editBox)
	local ins = editBox and editBox.Instructions
	if not ins then
		return
	end
	if not ins._gfOriginalShow then
		ins._gfOriginalShow = ins.Show
	end
	ins:Hide()
	ins.Show = function() end
	editBox._gfUseCreatePlaceholder = true
end

local function restoreDescriptionInstructions(editBox)
	restoreNativeInstructions(editBox)
	local instructions = editBox and editBox.Instructions
	if instructions == nil then
		return
	end
	local empty = editBoxIsEmptyByLetterCount(editBox)
	if empty ~= nil then
		instructions:SetShown(empty)
		return
	end
	if type(InputScrollFrame_OnTextChanged) == "function" then
		pcall(InputScrollFrame_OnTextChanged, editBox, false)
	end
end

local function resolveActivityID(node)
	local resolver = GF.NavData and GF.NavData.ResolveCreateActivityID
	if type(resolver) ~= "function" then
		return nil
	end
	return resolver(node)
end

local function buildActiveListingEditSelection(value)
	local activityID = tonumber(value)
	local reader = C_LFGList and C_LFGList.GetActivityInfoTable
	if activityID == nil or type(reader) ~= "function" then
		return nil
	end
	local succeeded, activity = pcall(reader, activityID)
	if not succeeded or type(activity) ~= "table"
		or activity.categoryID == nil
	then
		return nil
	end
	local title = activity.shortName
	if type(title) ~= "string" or title == "" then
		title = activity.fullName
	end
	return {
		key = ("active_listing_edit:%d"):format(activityID),
		label = title,
		categoryID = activity.categoryID,
		groupID = activity.groupFinderActivityGroupID,
		activityID = activityID,
		activityInfo = activity,
		filters = activity.filters,
		_editOnlyActiveListing = true,
	}
end

local function getEntryCreation()
	local root = LFGListFrame
	return root and root.EntryCreation or nil
end

local function frameReportsVisible(frame)
	return frame ~= nil and type(frame.IsVisible) == "function"
		and frame:IsVisible() == true
end

local function contextStillCurrent(context)
	local view = GF.LFGWorkspaceView
	if context == nil or view == nil
		or type(view.IsContextCurrent) ~= "function"
	then
		return true
	end
	return view:IsContextCurrent(context) == true
end

local function isCreateFieldSurfaceActive()
	local sidebar = GF.MythicPlusCreateManagerPanel
	if sidebar ~= nil and type(sidebar.IsSurfaceActive) == "function"
		and sidebar:IsSurfaceActive() == true
	then
		return contextStillCurrent(sidebar.workspaceContext)
	end
	local drawer = GF.CreateDrawer
	return drawer ~= nil and drawer.open == true
		and contextStillCurrent(drawer.workspaceContext)
end

local function isLfgFrameVisible()
	return frameReportsVisible(LFGListFrame)
end

local function isBlizzardCreateActive()
	local root = LFGListFrame
	local nativePanel = root and root.EntryCreation
	return isLfgFrameVisible() and nativePanel ~= nil
		and root.activePanel == nativePanel
end

local function frameHasForeignParent(frame, nativeParent, groupFinderParent, sink)
	if frame == nil or type(frame.GetParent) ~= "function" then
		return false
	end
	local parent = frame:GetParent()
	return parent ~= nil and parent ~= nativeParent
		and parent ~= groupFinderParent and parent ~= sink
end

local function entryCreationFieldsKeepNativeParents(creation)
	if creation == nil then
		return false
	end
	for _, fieldKey in ipairs({ "Name", "Description", "VoiceChat" }) do
		local field = creation[fieldKey]
		if field ~= nil and type(field.GetParent) == "function"
			and field:GetParent() ~= creation
		then
			return false
		end
	end
	return true
end

local function areCreateFieldsExternallyOwned()
	local nativePanel = getEntryCreation()
	if nativePanel == nil then
		return false
	end
	local targetParent = CP.GetEmbedParent and CP:GetEmbedParent() or nil
	local sink = BB and BB.GetHideSink and BB.GetHideSink() or nil
	if frameHasForeignParent(
		nativePanel,
		LFGListFrame,
		targetParent,
		sink
	) then
		return true
	end
	return not entryCreationFieldsKeepNativeParents(nativePanel)
end

local function nativeChannelOccupied()
	return isLfgFrameVisible() or isBlizzardCreateActive()
		or areCreateFieldsExternallyOwned()
end

local function isCreateChannelBlocked()
	return isCreateFieldSurfaceActive() and nativeChannelOccupied()
end

function CP:IsCreateChannelAutoOpenBlocked()
	return nativeChannelOccupied()
end

local function secretText(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

local function restoreInstructionShow(instructions)
	local original = instructions and instructions._gfOriginalShow
	if original ~= nil then
		instructions.Show = original
		instructions._gfOriginalShow = nil
	end
end

local function syncEditInstructions(editBox)
	if editBox == nil then
		return
	end
	if editBox._gfUseCreatePlaceholder == true then
		suppressNativeInstructions(editBox)
		return
	end
	local instructions = editBox.Instructions
	if instructions == nil then
		return
	end
	restoreInstructionShow(instructions)
	local empty = editBoxIsEmptyByLetterCount(editBox)
	if empty ~= nil then
		instructions:SetShown(empty)
		return
	end
	if type(InputBoxInstructions_OnTextChanged) == "function" then
		local ok = pcall(InputBoxInstructions_OnTextChanged, editBox)
		if ok then
			return
		end
	end
	local ok, text = false, nil
	if type(editBox.GetText) == "function" then
		ok, text = pcall(editBox.GetText, editBox)
	end
	local textIsSecret = secretText(text)
	if not ok or textIsSecret then
		instructions:Hide()
		return
	end
	local hasVisibleText = text ~= nil and trimName(text) ~= ""
	if hasVisibleText then
		instructions:Hide()
	else
		instructions:Show()
	end
end

local function restoreNameInstructions(editBox)
	if editBox == nil then
		return
	end
	restoreNativeInstructions(editBox)
	local instructions = editBox.Instructions
	if instructions ~= nil then
		instructions:ClearAllPoints()
		instructions:SetPoint("LEFT", editBox, "LEFT", 8, 0)
		instructions:SetPoint("RIGHT", editBox, "RIGHT", -4, 0)
	end
	syncEditInstructions(editBox)
end

local function ensureScrollingEditInitialized(editBox)
	if editBox == nil or type(ScrollingEdit_SetCursorOffsets) ~= "function" then
		return
	end
	local missingCursorState = editBox.cursorOffset == nil
		or editBox.cursorHeight == nil
	if missingCursorState then
		ScrollingEdit_SetCursorOffsets(editBox, 0, editBox.cursorHeight or 15)
	end
end

local function installDescriptionCursorGuard(nativePanel)
	local description = nativePanel and nativePanel.Description
	local editBox = description and description.EditBox
	if editBox == nil then
		return
	end
	ensureScrollingEditInitialized(editBox)
	if editBox._gfDescriptionCursorGuarded == true then
		return
	end
	if type(editBox.HookScript) == "function" then
		editBox:HookScript("OnUpdate", function(box)
			ensureScrollingEditInitialized(box)
		end)
	end
	editBox._gfDescriptionCursorGuarded = true
end

local function syncDescriptionEditBoxWidth(description)
	local editBox = description and description.EditBox
	if editBox == nil or type(description.GetWidth) ~= "function" then
		return
	end
	local frameWidth = tonumber(description:GetWidth()) or 0
	if frameWidth <= 0 then
		return
	end
	local bar = description.ScrollBar
	local reserve = bar ~= nil and type(bar.IsShown) == "function"
		and bar:IsShown() and 16 or 10
	editBox:SetWidth(math.max(1, frameWidth - reserve))
	if type(InputScrollFrame_OnTextChanged) == "function" then
		pcall(InputScrollFrame_OnTextChanged, editBox, false)
	end
end

local function safeDescriptionTextChanged(editBox, userInput)
	if editBox == nil then
		return
	end
	ensureScrollingEditInitialized(editBox)
	if type(InputScrollFrame_OnTextChanged) == "function" then
		pcall(InputScrollFrame_OnTextChanged, editBox, userInput)
	end
	syncEditInstructions(editBox)
	if type(CP.UpdateCustomPlaceholders) == "function" then
		CP:UpdateCustomPlaceholders()
	end
end

function CP:SyncEmbeddedFieldChrome(nativePanel)
	local creation = nativePanel or getEntryCreation()
	if creation == nil then
		return
	end
	syncEditInstructions(creation.Name)
	local descriptionEdit = creation.Description and creation.Description.EditBox
	syncEditInstructions(descriptionEdit)
	self:UpdateCustomPlaceholders()
end

local NATIVE_DUPLICATE_FIELDS = {
	"Label", "NameLabel", "DescriptionLabel", "Inset", "WorkingCover",
	"GroupDropdown", "ActivityDropdown", "ActivityFinder",
	"PlayStyleDropdown", "ItemLevel", "PvpItemLevel", "PVPRating",
	"MythicPlusRating", "PrivateGroup", "CrossFactionGroup",
	"ListGroupButton", "LeaverBadge", "CancelButton",
}

local function ignoreWidgetShow()
end

local function ignoreWidgetSetShown()
end

local function parkNativeWidget(panel, widget)
	if widget == nil or widget._gfSuppressed == true then
		return
	end
	widget._gfSuppressedState = {
		shown = widgetShown(widget),
		originalShow = widget.Show,
		originalSetShown = widget.SetShown,
	}
	widget._gfSuppressed = true
	widget.Show = ignoreWidgetShow
	widget.SetShown = ignoreWidgetSetShown
	widget:Hide()
	panel._suppressedWidgets[#panel._suppressedWidgets + 1] = widget
end

local function restoreParkedWidget(widget)
	if widget == nil or widget._gfSuppressed ~= true then
		return
	end
	local state = widget._gfSuppressedState or {}
	local originalShow = state.originalShow
	local originalSetShown = state.originalSetShown
	widget._gfSuppressedState = nil
	widget._gfSuppressed = nil
	if type(originalShow) == "function" then
		widget.Show = originalShow
	end
	if type(originalSetShown) == "function" then
		widget.SetShown = originalSetShown
	end
	setWidgetShown(widget, state.shown)
end

local function restoreParkedWidgets(panel)
	local parked = panel and panel._suppressedWidgets or {}
	for index = #parked, 1, -1 do
		restoreParkedWidget(parked[index])
	end
	if panel then
		panel._suppressedWidgets = {}
	end
end

local function parkNativeEntryShell(panel, nativePanel)
	if nativePanel == nil then
		return
	end
	for index = 1, #NATIVE_DUPLICATE_FIELDS do
		parkNativeWidget(panel, nativePanel[NATIVE_DUPLICATE_FIELDS[index]])
	end
end

local function releaseShouldExposeNative(reason)
	return reason == "blizzard" or reason == "addon"
end

local function nativeEntryPageSelected()
	local root = LFGListFrame
	local creation = getEntryCreation()
	return creation ~= nil and frameReportsVisible(root)
		and root.activePanel == creation
end

local function settleUnselectedEntryPage()
	local root, creation = LFGListFrame, getEntryCreation()
	if root ~= nil and creation ~= nil and root.activePanel ~= creation then
		creation:Hide()
	end
end

local function settleReleasedVisibility(nativePanel, reason, originalShown)
	if nativePanel == nil then
		return
	end
	local show = originalShown == true
	if releaseShouldExposeNative(reason) then
		show = nativeEntryPageSelected()
	end
	nativePanel:SetShown(show == true)
end

local function updateBorrowedVoiceAtlas(panel, voice)
	local editBox = voice and voice.EditBox
	local enabled = editBox ~= nil
		and (not editBox.IsEnabled or editBox:IsEnabled())
	local active = enabled and editBox ~= nil
		and type(editBox.HasFocus) == "function" and editBox:HasFocus()
	updateCreateInputAtlasFrame(panel and panel.voiceAnchor, active, enabled)
end

local function projectBorrowedVoiceField(panel, creation, voice)
	if panel == nil or creation == nil or voice == nil
		or panel.voiceAnchor == nil or voice.EditBox == nil
		or type(voice.GetParent) ~= "function"
		or voice:GetParent() ~= creation
	then
		return false
	end
	captureBorrowedVoiceProjection(voice)
	voice:ClearAllPoints()
	voice:SetPoint("TOPLEFT", panel.voiceAnchor, "TOPLEFT")
	voice:SetPoint("BOTTOMRIGHT", panel.voiceAnchor, "BOTTOMRIGHT")

	local editBox = voice.EditBox
	hideBorrowedNameChrome(editBox)
	editBox:ClearAllPoints()
	editBox:SetPoint("TOPLEFT", voice, "TOPLEFT", FIELD_EDGE_PAD, 0)
	editBox:SetPoint("BOTTOMRIGHT", voice, "BOTTOMRIGHT", -FIELD_EDGE_PAD, 0)
	setWidgetShown(voice.CheckButton, false)
	setWidgetShown(voice.Label, false)
	setWidgetShown(voice.WarningFrame, false)
	-- Keep the native VoiceChat and EditBox scripts untouched. Their secure
	-- text/change behavior remains Blizzard-owned across borrow and return.

	local visible = not panel:IsMythicPlusSidebarMode()
	setWidgetShown(voice, visible)
	setWidgetShown(editBox, visible)
	updateBorrowedVoiceAtlas(panel, voice)
	return true
end

local function returnBorrowedVoiceField(voice)
	if voice == nil then
		return
	end
	if voice._gfVoiceBorrowState == nil then
		return
	end
	local nativeShown = restoreBorrowedVoiceProjection(voice)
	setWidgetShown(voice, nativeShown == true)
end

local function returnOneBorrowedField(
	field,
	stateKey,
	restoreChrome,
	restoreInstructions
)
	if field == nil then
		return
	end
	if restoreInstructions then
		restoreInstructions(field)
	end
	if restoreChrome then
		restoreChrome(field)
	end
	restoreProjectedField(field, stateKey)
end

local function restoreEntryCreationToBlizzard(nativePanel, panel, reason)
	if nativePanel == nil then
		return false
	end
	nativePanel:Hide()
	returnOneBorrowedField(
		nativePanel.Name,
		"_gfCreateNameBorrowState",
		restoreBorrowedNameChrome,
		restoreNameInstructions
	)
	local description = nativePanel.Description
	returnOneBorrowedField(
		description,
		"_gfCreateDescriptionBorrowState",
		function(frame)
			restoreBorrowedWidgetChrome(frame, "_gfDescriptionChromeState")
		end,
		function(frame)
			restoreDescriptionInstructions(frame.EditBox)
		end
	)
	returnBorrowedVoiceField(nativePanel.VoiceChat)
	restoreEntryCreationInteraction(nativePanel)
	restoreParkedWidgets(panel)
	local originalShown = restoreEntryCreationContainer(nativePanel)
	nativePanel._gfRestoringBorrowedEntryCreation = true
	local visibilityRestored, visibilityError = pcall(
		settleReleasedVisibility,
		nativePanel,
		reason,
		originalShown
	)
	nativePanel._gfRestoringBorrowedEntryCreation = nil
	if not visibilityRestored then
		error(visibilityError, 0)
	end
	return originalShown ~= nil
end

local function precacheEntryCreationLayouts()
	local creation = getEntryCreation()
	if creation == nil then
		return
	end
	BB.CacheLayout(creation)
	BB.CacheLayout(creation.Name)
	BB.CacheLayout(creation.Description)
	BB.CacheLayout(creation.VoiceChat)
	BB.CacheLayout(creation.VoiceChat and creation.VoiceChat.EditBox)
	for index = 1, #NATIVE_DUPLICATE_FIELDS do
		BB.CacheLayout(creation[NATIVE_DUPLICATE_FIELDS[index]])
	end
end

function CP:GetCreateFieldWidths()
	local measured
	if self.scroll ~= nil and type(self.scroll.GetWidth) == "function" then
		measured = tonumber(self.scroll:GetWidth())
	end
	local usable = measured ~= nil and measured > 0
		and math.floor(measured) or nil
	if usable ~= nil and usable > 0 then
		return usable, usable
	end
	return NATIVE_FIELD_SIZE.name.width,
		NATIVE_FIELD_SIZE.description.width
end

function CP:GetCreateColumnWidth()
	local scrollW = self.scroll and self.scroll:GetWidth() or 0
	if not scrollW or scrollW <= 0 then
		return nil
	end
	local fullW = math.floor(scrollW)
	local minW = GF.CREATE_DRAWER_HORIZONTAL_MIN_W or 560
	if fullW < minW then
		return nil
	end
	local gap = GF.CREATE_FORM_COLUMN_GAP or 16
	return math.max(math.floor((fullW - gap) / 2), 1), gap, fullW
end

function CP:IsMythicPlusSidebarMode()
	return self._mythicPlusSidebarMode == true
end

function CP:IsMythicPlusSidebarReadOnly()
	return self:IsMythicPlusSidebarMode()
		and self._mythicPlusSidebarReadOnly == true
end

function CP:IsMythicPlusCreateManagerSurface()
	local panel = GF.MythicPlusCreateManagerPanel
	return self:IsMythicPlusSidebarMode()
		and panel
		and panel.IsMythicPlusSurface
		and panel:IsMythicPlusSurface()
		or false
end

function CP:IsMeetingStoneCreateManagerReadOnlySurface()
	local panel = GF.MythicPlusCreateManagerPanel
	return self:IsMythicPlusSidebarMode()
		and panel
		and panel.IsMeetingStoneReadOnlyMode
		and panel:IsMeetingStoneReadOnlyMode()
		or false
end

function CP:IsCreateManagerSurface()
	return self:IsMythicPlusCreateManagerSurface()
		or self:IsMeetingStoneCreateManagerReadOnlySurface()
end

function CP:ApplyCreateManagerDropdownDisabledVisual(dropdown, disabled)
	if not dropdown then
		return
	end
	local hadManagerOverride =
		dropdown._gfCreateManagerDisabledVisual == true
	if dropdown.OnButtonStateChanged then
		dropdown:OnButtonStateChanged()
	end
	local createManagerSurface = self:IsCreateManagerSurface()
	if disabled ~= true
		or not createManagerSurface
	then
		if hadManagerOverride
			or createManagerSurface
		then
			for _, texture in ipairs({
				dropdown.Background,
				dropdown.Arrow,
			}) do
				if texture then
					if texture.SetDesaturated then
						texture:SetDesaturated(false)
					end
					texture:SetVertexColor(1, 1, 1, 1)
					texture:SetAlpha(1)
				end
			end
			if dropdown.Text then
				dropdown.Text:SetAlpha(1)
			end
		end
		dropdown._gfCreateManagerDisabledVisual = nil
		return
	end
	local tint = CREATE_FORM_DISABLED_ATLAS_TINT
	if dropdown.Arrow and dropdown.Arrow.SetAtlas then
		dropdown.Arrow:SetAtlas(
			GF.CREATE_MANAGER_DROPDOWN_ARROW_ATLAS
				or "common-dropdown-a-button",
			true
		)
	end
	for _, texture in ipairs({
		dropdown.Background,
		dropdown.Arrow,
	}) do
		if texture then
			if texture.SetDesaturated then
				texture:SetDesaturated(
					CREATE_FORM_DISABLED_ATLAS_DESATURATED
				)
			end
			texture:SetVertexColor(
				tint,
				tint,
				tint,
				CREATE_FORM_DISABLED_ALPHA
			)
			texture:SetAlpha(CREATE_FORM_DISABLED_ALPHA)
		end
	end
	if dropdown.Text then
		dropdown.Text:SetTextColor(
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[1],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[2],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[3],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[4]
		)
		dropdown.Text:SetAlpha(CREATE_FORM_DISABLED_ALPHA)
	end
	dropdown._gfCreateManagerDisabledVisual = true
end

-- Compatibility entry point for code loaded against the previous helper name.
function CP:ApplyCreateManagerDropdownReadOnlyVisual(dropdown, readOnly)
	self:ApplyCreateManagerDropdownDisabledVisual(dropdown, readOnly)
end

local function captureBorrowedCreateManagerTextColor(editBox)
	if not (
		editBox
		and editBox.GetTextColor
		and not editBox._gfCreateManagerEnabledTextColor
	) then
		return
	end
	editBox._gfCreateManagerEnabledTextColor = {
		editBox:GetTextColor(),
	}
end

local function setBorrowedCreateManagerTextDisabled(editBox, disabled)
	if not (editBox and editBox.SetTextColor) then
		return
	end
	if disabled then
		captureBorrowedCreateManagerTextColor(editBox)
		editBox:SetTextColor(
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[1],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[2],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[3],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[4]
		)
		return
	end
	local color = editBox._gfCreateManagerEnabledTextColor
	if color then
		editBox:SetTextColor(
			color[1] or 1,
			color[2] or 1,
			color[3] or 1,
			color[4] or 1
		)
		editBox._gfCreateManagerEnabledTextColor = nil
	end
end

function CP:CaptureCreateManagerBorrowedFieldTextColors()
	captureBorrowedCreateManagerTextColor(self.nameEdit)
	captureBorrowedCreateManagerTextColor(
		self.commentScroll and self.commentScroll.EditBox
	)
end

function CP:ApplyCreateManagerBorrowedFieldTextVisual(disabled)
	setBorrowedCreateManagerTextDisabled(self.nameEdit, disabled == true)
	setBorrowedCreateManagerTextDisabled(
		self.commentScroll and self.commentScroll.EditBox,
		disabled == true
	)
end

function CP:ApplyMythicPlusSidebarTitleStyle()
	local color = self:IsCreateManagerSurface()
		and self._createManagerFormDisabled == true
		and CREATE_FORM_DISABLED_TITLE_COLOR
		or CREATE_FORM_TITLE_COLOR
	for _, label in ipairs({
		self.nameLabel,
		self.commentLabel,
		self.playLabel,
		self.ilvlLabel,
		self.mplusLabel,
		self.voiceLabel,
	}) do
		applyCreateTitleTextStyle(label, color)
	end
end

function CP:FitMythicPlusSidebarLabels()
	if not self:IsMythicPlusSidebarMode()
		or not (GF.Font and GF.Font.SetFitWidth) then
		return
	end
	local _, fieldW = self:GetCreateFieldWidths()
	for _, label in ipairs({
		self.nameLabel,
		self.commentLabel,
		self.playLabel,
		self.ilvlLabel,
		self.mplusLabel,
	}) do
		if label then
			GF.Font.SetFitWidth(label, fieldW, 8)
		end
	end
end

function CP:SetMythicPlusSidebarMode(enabled)
	enabled = enabled == true
	if self._mythicPlusSidebarMode == enabled then
		return
	end
	self._mythicPlusSidebarMode = enabled
	self._mythicPlusSidebarReadOnly = nil
	self._createManagerFormDisabled = nil
	self._mythicPlusHiddenDefaultsApplied = nil
	self._protectedCreationTextDraftPrepared = nil
	if not enabled then
		self:ApplyCreateManagerBorrowedFieldTextVisual(false)
		self:ApplyCreateManagerDropdownDisabledVisual(
			self.playDropdown,
			false
		)
		if GF.UI and GF.UI.SetCommonPanelButtonPreserveDisabledAlpha then
			GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
				self.listBtn,
				false
			)
			GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
				self.removeBtn,
				false
			)
		end
	end
	for _, widget in ipairs({
		self.voiceLabel,
		self.voiceAnchor,
		self.voiceFrame,
		self.voiceEdit,
		self.crossFactionCheck,
		self.crossFactionLabel,
		self.privateCheck,
		self.privateLabel,
	}) do
		if widget then
			widget:SetShown(not enabled)
		end
	end
	if not enabled then
		local activityID = resolveActivityID(self.selection)
		local activityInfo = activityID
			and C_LFGList
			and C_LFGList.GetActivityInfoTable
			and C_LFGList.GetActivityInfoTable(activityID)
		self:UpdateScoreRequirementVisibility(activityInfo)
		self:UpdateCrossFactionOption()
	end
	self:UpdateRequirementLayout()
	self:ApplyMythicPlusSidebarTitleStyle()
	self:FitMythicPlusSidebarLabels()
end

function CP:ClearProtectedCreationTextFieldsForNewDraft(force)
	if self.editMode or force ~= true then
		return false
	end
	local listing = GF.RecruitmentSession
	if listing ~= nil and type(listing.HasActive) == "function"
		and listing:HasActive() == true
	then
		return false
	end
	if self._protectedCreationTextDraftPrepared == true then
		return false
	end
	local clearTextFields = C_LFGList
		and C_LFGList.ClearCreationTextFields
	if type(clearTextFields) ~= "function" then
		return false
	end
	local cleared = pcall(clearTextFields)
	if not cleared then
		return false
	end
	local creation = getEntryCreation()
	local voiceToggle = creation and creation.VoiceChat
		and creation.VoiceChat.CheckButton
	if voiceToggle and type(voiceToggle.SetChecked) == "function" then
		voiceToggle:SetChecked(false)
	end
	self._protectedCreationTextDraftPrepared = true
	return true
end

function CP:ApplyMythicPlusHiddenCreateDefaults(force)
	if not self:IsMythicPlusSidebarMode() or self.editMode then
		return
	end
	if self._mythicPlusHiddenDefaultsApplied and not force then
		return
	end
	local voiceToggle = self.voiceFrame and self.voiceFrame.CheckButton
	if voiceToggle and type(voiceToggle.SetChecked) == "function" then
		voiceToggle:SetChecked(false)
	end
	if self.privateCheck then
		self.privateCheck:SetChecked(false)
	end
	if self.crossFactionCheck then
		-- Unchecked maps to the normal cross-faction-enabled listing state.
		self.crossFactionCheck:SetChecked(false)
	end
	self._mythicPlusHiddenDefaultsApplied = true
end

local function isEmptyEditText(editBox)
	if not editBox then
		return true
	end
	local empty = editBoxIsEmptyByLetterCount(editBox)
	if empty ~= nil then
		return empty
	end
	if type(editBox.GetText) ~= "function" then
		return true
	end
	local ok, text = pcall(editBox.GetText, editBox)
	if not ok or secretText(text) then
		return false
	end
	return text == nil or text == ""
end

function CP:LayoutCustomPlaceholders()
	if self.namePlaceholder and (self.nameEdit or self.nameAnchor) then
		if self.nameEdit and self.namePlaceholder.SetParent then
			self.namePlaceholder:SetParent(self.nameEdit)
		end
		local anchor = self.nameEdit or self.nameAnchor
		self.namePlaceholder:ClearAllPoints()
		self.namePlaceholder:SetPoint("LEFT", anchor, "LEFT", CREATE_PLACEHOLDER_LEFT_INSET, 0)
		self.namePlaceholder:SetPoint("RIGHT", anchor, "RIGHT", -6, 0)
	end
	local descriptionEdit = self.commentScroll and self.commentScroll.EditBox
	local descriptionAnchor = descriptionEdit or self.commentScroll or self.descAnchor
	if self.descPlaceholder and descriptionAnchor then
		local placeholderParent = descriptionEdit or self.formBody
		if placeholderParent and self.descPlaceholder.SetParent then
			self.descPlaceholder:SetParent(placeholderParent)
		end
		self.descPlaceholder:ClearAllPoints()
		self.descPlaceholder:SetPoint("TOPLEFT", descriptionAnchor, "TOPLEFT", CREATE_PLACEHOLDER_LEFT_INSET, -6)
		self.descPlaceholder:SetPoint("RIGHT", descriptionAnchor, "RIGHT", -6, 0)
	end
end

function CP:UpdateCustomPlaceholders()
	local L = GF.L or {}
	if self.namePlaceholder then
		self.namePlaceholder:SetAlpha(1)
		self.namePlaceholder:SetText(L.CREATE_NAME_PLACEHOLDER or "请输入队伍名称")
		self.namePlaceholder:SetShown(self.nameEdit ~= nil and isEmptyEditText(self.nameEdit))
	end
	local descEdit = self.commentScroll and self.commentScroll.EditBox
	if self.descPlaceholder then
		self.descPlaceholder:SetAlpha(1)
		self.descPlaceholder:SetText(L.CREATE_COMMENT_PLACEHOLDER or "请输入关于你的队伍的更多细节（可选）")
		self.descPlaceholder:SetShown(descEdit ~= nil and isEmptyEditText(descEdit))
	end
end

function CP:UpdateFieldLayout()
	local nameW, descW = self:GetCreateFieldWidths()
	local nativeNameW = math.max(nameW - (FIELD_EDGE_PAD * 2), 1)
	local nativeDescW = math.max(descW - (FIELD_EDGE_PAD * 2), 1)

	local nameSlot, nameChrome = self.nameAnchor, self.nameAtlasAnchor
	local descriptionSlot, descriptionChrome = self.descAnchor, self.descAtlasAnchor
	if nameSlot ~= nil then
		nameSlot:SetSize(nativeNameW, CREATE_FORM_INPUT_H)
	end
	if nameChrome ~= nil then
		nameChrome:SetSize(nameW, CREATE_FORM_INPUT_H)
		styleCreateInputAtlasFrame(nameChrome)
	end
	if descriptionSlot ~= nil then
		descriptionSlot:SetSize(nativeDescW, CREATE_FORM_DESC_H)
	end
	if descriptionChrome ~= nil then
		descriptionChrome:SetSize(descW, CREATE_FORM_DESC_ATLAS_H)
		styleCreateDescriptionAtlasFrame(descriptionChrome)
	end

	self:ApplyPlaystyleDropdownLayout()

	local fieldsAreBorrowed = self._attached == true
		and self:IsBorrowingBlizzardFields()
	if fieldsAreBorrowed then
		local creation, host = getEntryCreation(), self:GetEmbedParent()
		if creation ~= nil and host ~= nil
			and creation:GetParent() == host
		then
			local ec = creation
			local borrowedName = creation.Name
			if borrowedName ~= nil and self.nameAnchor ~= nil
				and borrowedName:GetParent() == ec
			then
				borrowedName:ClearAllPoints()
				borrowedName:SetPoint(
					"TOPLEFT",
					self.nameAnchor,
					"TOPLEFT"
				)
				borrowedName:SetSize(nativeNameW, CREATE_FORM_INPUT_H)
				borrowedName:Show()
				hideBorrowedNameChrome(borrowedName)
				if not borrowedName._gfCreateNameAtlasHooked then
					borrowedName:HookScript("OnEditFocusGained", function()
						local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, enabled, enabled)
					end)
					borrowedName:HookScript("OnEditFocusLost", function()
						local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, borrowedName._gfCreateNameHovered and enabled, enabled)
					end)
					borrowedName:HookScript("OnEnter", function()
						borrowedName._gfCreateNameHovered = true
						local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, enabled, enabled)
					end)
					borrowedName:HookScript("OnLeave", function()
						borrowedName._gfCreateNameHovered = false
						local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, borrowedName:HasFocus() and enabled, enabled)
					end)
					borrowedName:HookScript("OnEnable", function()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, borrowedName:HasFocus() or borrowedName._gfCreateNameHovered, true)
					end)
					borrowedName:HookScript("OnDisable", function()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, false, false)
					end)
					borrowedName._gfCreateNameAtlasHooked = true
				end
				local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
				updateCreateInputAtlasFrame(self.nameAtlasAnchor, enabled and (borrowedName:HasFocus() or borrowedName._gfCreateNameHovered), enabled)
				suppressNativeInstructions(borrowedName)
			end
			if ec.Description and self.descAnchor
				and ec.Description:GetParent() == ec
			then
				ec.Description:ClearAllPoints()
				ec.Description:SetPoint(
					"TOPLEFT",
					self.descAnchor,
					"TOPLEFT"
				)
				ec.Description:SetSize(nativeDescW, CREATE_FORM_DESC_H)
				ec.Description:Show()
				hideBorrowedWidgetChrome(ec.Description, "_gfDescriptionChromeState")
				if not ec.Description._gfCreateDescAtlasHooked then
					ec.Description:HookScript("OnEnter", function()
						ec.Description._gfCreateDescHovered = true
						updateBorrowedDescriptionAtlas(ec.Description)
					end)
					ec.Description:HookScript("OnLeave", function()
						ec.Description._gfCreateDescHovered = false
						updateBorrowedDescriptionAtlas(ec.Description)
					end)
					if ec.Description.EditBox then
						ec.Description.EditBox:HookScript("OnEditFocusGained", function()
							updateBorrowedDescriptionAtlas(ec.Description)
						end)
						ec.Description.EditBox:HookScript("OnEditFocusLost", function()
							updateBorrowedDescriptionAtlas(ec.Description)
						end)
						ec.Description.EditBox:HookScript("OnEnable", function()
							updateBorrowedDescriptionAtlas(ec.Description)
						end)
						ec.Description.EditBox:HookScript("OnDisable", function()
							updateBorrowedDescriptionAtlas(ec.Description)
						end)
					end
					ec.Description._gfCreateDescAtlasHooked = true
				end
				if ec.Description.EditBox then
					ensureScrollingEditInitialized(ec.Description.EditBox)
					syncDescriptionEditBoxWidth(ec.Description)
					suppressNativeInstructions(ec.Description.EditBox)
				end
				updateBorrowedDescriptionAtlas(ec.Description)
			end
			if ec.VoiceChat and self.voiceAnchor then
				projectBorrowedVoiceField(self, ec, ec.VoiceChat)
			end
		end
	end

	self:LayoutCustomPlaceholders()
	self:UpdateCustomPlaceholders()
end

function CP:ApplyHorizontalDrawerLayout()
	if not self.formColumn then
		return false
	end
	if not getCreateDrawerFooter(self.parent) then
		return false
	end
	local colW, colGap, fullW = self:GetCreateColumnWidth()
	if not colW then
		return false
	end
	local rowY = 0
	local rowH = CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + CREATE_FORM_INPUT_H + CREATE_FORM_STACK_ROW_GAP
	local rightX = colW + colGap

	local function placeField(label, anchor, x, y, w, controlHeight, sideInset)
		if not label or not anchor then
			return
		end
		sideInset = sideInset or 0
		controlHeight = controlHeight or CREATE_FORM_INPUT_H
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", x, -y)
		label:SetWidth(w)
		label:SetJustifyH("LEFT")
		anchor:ClearAllPoints()
		anchor:SetSize(math.max(w - (sideInset * 2), 1), controlHeight)
		anchor:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", x + sideInset, -y - CREATE_FORM_TITLE_SIZE - CREATE_FORM_STACK_LABEL_GAP)
	end

	local function placeCheckbox(check, label, x, y, w)
		if not check or not check:IsShown() then
			return false
		end
		check:ClearAllPoints()
		check:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", x, -y - math.floor((CREATE_FORM_ROW_H - CREATE_CHECK_SIZE) / 2))
		if label then
			label:ClearAllPoints()
			label:SetPoint("LEFT", check, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
			label:SetWidth(math.max(w - CREATE_CHECK_SIZE - CREATE_CHECK_LABEL_GAP - 4, 1))
			label:SetJustifyH("LEFT")
		end
		return true
	end

	self.formColumn:SetSize(fullW, 1)

	placeField(self.nameLabel, self.nameAtlasAnchor, 0, rowY, fullW, CREATE_FORM_INPUT_H)
	if self.nameAnchor and self.nameAtlasAnchor then
		self.nameAnchor:ClearAllPoints()
		self.nameAnchor:SetPoint("TOPLEFT", self.nameAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, 0)
		self.nameAnchor:SetSize(math.max(fullW - (FIELD_EDGE_PAD * 2), 1), CREATE_FORM_INPUT_H)
	end
	rowY = rowY + CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + CREATE_FORM_INPUT_H + CREATE_FORM_STACK_ROW_GAP

	placeField(self.commentLabel, self.descAtlasAnchor, 0, rowY, fullW, CREATE_FORM_DESC_ATLAS_H)
	if self.descAnchor and self.descAtlasAnchor then
		self.descAnchor:ClearAllPoints()
		self.descAnchor:SetPoint("TOPLEFT", self.descAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, -CREATE_FORM_DESC_ATLAS_PAD_Y)
		self.descAnchor:SetSize(math.max(fullW - (FIELD_EDGE_PAD * 2), 1), CREATE_FORM_DESC_H)
	end
	rowY = rowY + CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + CREATE_FORM_DESC_ATLAS_H + CREATE_FORM_STACK_ROW_GAP

	placeField(self.playLabel, self.playDropdownAnchor, 0, rowY, colW, CREATE_FORM_INPUT_H)
	placeField(self.ilvlLabel, self.ilvlAnchor, rightX, rowY, colW, CREATE_FORM_INPUT_H)
	rowY = rowY + rowH

	if self.mplusLabel and self.mplusLabel:IsShown() and self.mplusAnchor then
		placeField(self.voiceLabel, self.voiceAnchor, 0, rowY, colW, CREATE_FORM_INPUT_H)
		placeField(self.mplusLabel, self.mplusAnchor, rightX, rowY, colW, CREATE_FORM_INPUT_H)
		rowY = rowY + rowH
	else
		placeField(self.voiceLabel, self.voiceAnchor, 0, rowY, colW, CREATE_FORM_INPUT_H)
		rowY = rowY + rowH
	end

	local hasCheck = false
	local leftCheckUsed = placeCheckbox(self.crossFactionCheck, self.crossFactionLabel, 0, rowY, colW)
	if leftCheckUsed then
		hasCheck = true
	end
	local privateX = leftCheckUsed and rightX or 0
	if placeCheckbox(self.privateCheck, self.privateLabel, privateX, rowY, colW) then
		hasCheck = true
	end
	if hasCheck then
		rowY = rowY + CREATE_FORM_ROW_H
	end

	self._compactFormHeight = rowY
	self:ApplyPlaystyleDropdownLayout()
	self:LayoutCustomPlaceholders()
	return true
end

function CP:ApplyMythicPlusSidebarLayout()
	if not self.formColumn then
		return
	end
	local _, fieldW = self:GetCreateFieldWidths()
	local rowY = 0
	self.formColumn:SetSize(fieldW, 1)

	local function placeField(label, anchor, controlHeight, addGap)
		if not label or not anchor then
			return
		end
		controlHeight = controlHeight or CREATE_FORM_INPUT_H
		label:ClearAllPoints()
		label:SetPoint(
			"TOPLEFT",
			self.formColumn,
			"TOPLEFT",
			0,
			-rowY
		)
		label:SetSize(fieldW, CREATE_SIDEBAR_SECTION_TITLE_H)
		label:SetJustifyH("LEFT")
		label:SetJustifyV("MIDDLE")
		anchor:ClearAllPoints()
		anchor:SetPoint(
			"TOPLEFT",
			self.formColumn,
			"TOPLEFT",
			0,
			-rowY
				- CREATE_SIDEBAR_SECTION_TITLE_H
				- CREATE_SIDEBAR_LABEL_CONTROL_GAP
		)
		anchor:SetSize(fieldW, controlHeight)
		rowY = rowY
			+ CREATE_SIDEBAR_SECTION_TITLE_H
			+ CREATE_SIDEBAR_LABEL_CONTROL_GAP
			+ controlHeight
		if addGap then
			rowY = rowY + CREATE_SIDEBAR_BLOCK_GAP
		end
	end

	placeField(
		self.nameLabel,
		self.nameAtlasAnchor,
		CREATE_FORM_INPUT_H,
		true
	)
	if self.nameAnchor and self.nameAtlasAnchor then
		self.nameAnchor:ClearAllPoints()
		self.nameAnchor:SetPoint(
			"TOPLEFT",
			self.nameAtlasAnchor,
			"TOPLEFT",
			FIELD_EDGE_PAD,
			0
		)
		self.nameAnchor:SetSize(
			math.max(fieldW - (FIELD_EDGE_PAD * 2), 1),
			CREATE_FORM_INPUT_H
		)
	end

	placeField(
		self.commentLabel,
		self.descAtlasAnchor,
		CREATE_FORM_DESC_ATLAS_H,
		true
	)
	if self.descAnchor and self.descAtlasAnchor then
		self.descAnchor:ClearAllPoints()
		self.descAnchor:SetPoint(
			"TOPLEFT",
			self.descAtlasAnchor,
			"TOPLEFT",
			FIELD_EDGE_PAD,
			-CREATE_FORM_DESC_ATLAS_PAD_Y
		)
		self.descAnchor:SetSize(
			math.max(fieldW - (FIELD_EDGE_PAD * 2), 1),
			CREATE_FORM_DESC_H
		)
	end

	placeField(
		self.playLabel,
		self.playDropdownAnchor,
		CREATE_FORM_INPUT_H,
		true
	)
	placeField(
		self.ilvlLabel,
		self.ilvlAnchor,
		CREATE_FORM_INPUT_H,
		true
	)
	if self.mplusLabel and self.mplusAnchor then
		placeField(
			self.mplusLabel,
			self.mplusAnchor,
			CREATE_FORM_INPUT_H,
			false
		)
	end

	for _, widget in ipairs({
		self.voiceLabel,
		self.voiceAnchor,
		self.voiceFrame,
		self.voiceEdit,
		self.crossFactionCheck,
		self.crossFactionLabel,
		self.privateCheck,
		self.privateLabel,
	}) do
		if widget then
			widget:Hide()
		end
	end
	self._compactFormHeight = rowY
	self:ApplyPlaystyleDropdownLayout()
	self:LayoutCustomPlaceholders()
	self:FitMythicPlusSidebarLabels()
end

function CP:ApplyCompactRowLayout()
	if not self.formColumn then
		return
	end
	if self:IsMythicPlusSidebarMode() then
		self:ApplyMythicPlusSidebarLayout()
		return
	end
	if self:ApplyHorizontalDrawerLayout() then
		return
	end
	local _, fieldW = self:GetCreateFieldWidths()
	local rowY = 0
	self.formColumn:SetSize(fieldW, 1)
	local function placeStackedField(label, anchor, controlHeight, sideInset)
		if not label or not anchor then
			return
		end
		sideInset = sideInset or 0
		controlHeight = controlHeight or CREATE_FORM_INPUT_H
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", 0, -rowY)
		label:SetWidth(fieldW)
		label:SetJustifyH("LEFT")
		anchor:ClearAllPoints()
		anchor:SetSize(math.max(fieldW - (sideInset * 2), 1), controlHeight)
		anchor:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", sideInset, -rowY - CREATE_FORM_TITLE_SIZE - CREATE_FORM_STACK_LABEL_GAP)
		rowY = rowY + CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + controlHeight + CREATE_FORM_STACK_ROW_GAP
	end
	placeStackedField(self.nameLabel, self.nameAtlasAnchor, CREATE_FORM_INPUT_H)
	if self.nameAnchor and self.nameAtlasAnchor then
		self.nameAnchor:ClearAllPoints()
		self.nameAnchor:SetPoint("TOPLEFT", self.nameAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, 0)
		self.nameAnchor:SetSize(math.max(fieldW - (FIELD_EDGE_PAD * 2), 1), CREATE_FORM_INPUT_H)
	end
	placeStackedField(self.commentLabel, self.descAtlasAnchor, CREATE_FORM_DESC_ATLAS_H)
	if self.descAnchor and self.descAtlasAnchor then
		self.descAnchor:ClearAllPoints()
		self.descAnchor:SetPoint("TOPLEFT", self.descAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, -CREATE_FORM_DESC_ATLAS_PAD_Y)
		self.descAnchor:SetSize(math.max(fieldW - (FIELD_EDGE_PAD * 2), 1), CREATE_FORM_DESC_H)
	end
	placeStackedField(self.playLabel, self.playDropdownAnchor, CREATE_FORM_INPUT_H)
	placeStackedField(self.ilvlLabel, self.ilvlAnchor, CREATE_FORM_INPUT_H)
	if self.mplusLabel and self.mplusLabel:IsShown() and self.mplusAnchor then
		placeStackedField(self.mplusLabel, self.mplusAnchor, CREATE_FORM_INPUT_H)
	end
	placeStackedField(self.voiceLabel, self.voiceAnchor, CREATE_FORM_INPUT_H)

	if self.crossFactionCheck and self.crossFactionCheck:IsShown() then
		self.crossFactionCheck:ClearAllPoints()
		self.crossFactionCheck:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", 0, -rowY - math.floor((CREATE_FORM_ROW_H - CREATE_CHECK_SIZE) / 2))
		if self.crossFactionLabel then
			self.crossFactionLabel:ClearAllPoints()
			self.crossFactionLabel:SetPoint("LEFT", self.crossFactionCheck, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
			self.crossFactionLabel:SetJustifyH("LEFT")
		end
		rowY = rowY + CREATE_FORM_ROW_H
	end
	if self.privateCheck and self.privateCheck:IsShown() then
		self.privateCheck:ClearAllPoints()
		self.privateCheck:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", 0, -rowY - math.floor((CREATE_FORM_ROW_H - CREATE_CHECK_SIZE) / 2))
		if self.privateLabel then
			self.privateLabel:ClearAllPoints()
			self.privateLabel:SetPoint("LEFT", self.privateCheck, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
			self.privateLabel:SetJustifyH("LEFT")
		end
		rowY = rowY + CREATE_FORM_ROW_H
	end
	self._compactFormHeight = rowY
	self:ApplyPlaystyleDropdownLayout()
	self:LayoutCustomPlaceholders()
end

function CP:UpdateRequirementLayout()
	local complete = self.ilvlAnchor ~= nil and self.voiceLabel ~= nil
		and self.voiceAnchor ~= nil and self.formColumn ~= nil
	if not complete then
		return false
	end
	self:ApplyCompactRowLayout()
	self:UpdateScrollLayout()
	return true
end

function CP:GetEmbedParent()
	return self.formBody or self.parent
end

function CP:MeasureFormBodyHeight()
	local minimum = 100
	local compactHeight = tonumber(self._compactFormHeight)
	if compactHeight ~= nil and compactHeight > 0 then
		return math.max(minimum, compactHeight + CONTENT_PAD)
	end
	local first = self.nameLabel
	local last = self.privateCheck or self.privateLabel or self.voiceAnchor
	if self.formBody == nil or first == nil or last == nil
		or type(first.GetRect) ~= "function"
		or type(last.GetRect) ~= "function"
	then
		return minimum
	end
	local _, firstBottom, _, firstHeight = first:GetRect()
	local _, lastBottom = last:GetRect()
	if type(firstBottom) ~= "number" or type(firstHeight) ~= "number"
		or type(lastBottom) ~= "number" or firstHeight <= 0
	then
		return minimum
	end
	local measured = firstBottom + firstHeight - lastBottom + CONTENT_PAD
	return measured > minimum and measured or minimum
end

function CP:CancelUpdateScrollLayoutDebounce()
	local pending = self._scrollLayoutDebounce
	self._scrollLayoutDebounce = nil
	if pending ~= nil and type(pending.Cancel) == "function" then
		pending:Cancel()
	end
end

function CP:ScheduleUpdateScrollLayout()
	local host = self.parent
	if host ~= nil and type(host.IsShown) == "function"
		and not host:IsShown()
	then
		return
	end
	self:CancelUpdateScrollLayoutDebounce()
	local schedule = C_Timer and C_Timer.NewTimer
	if type(schedule) ~= "function" then
		self:UpdateScrollLayout()
		return
	end
	local delay = GF.LAYOUT_RESIZE_DEBOUNCE or 0.1
	self._scrollLayoutDebounce = schedule(delay, function()
		CP._scrollLayoutDebounce = nil
		CP:UpdateScrollLayout()
	end)
end

local function updateCreateScrollBar(panel)
	if getCreateDrawerFooter(panel.parent) == nil or panel.scrollBar == nil then
		return
	end
	local rightInset = createDrawerScrollInsetR()
	anchorCreateDrawerScrollBar(
		panel.scroll,
		panel.scrollBar,
		createDrawerScrollBarOffsetX(rightInset)
	)
end

function CP:UpdateScrollLayout()
	local scroll, body, host = self.scroll, self.formBody, self.parent
	if scroll == nil or body == nil or host == nil
		or (type(host.IsShown) == "function" and not host:IsShown())
	then
		return false
	end
	local availableWidth = tonumber(scroll:GetWidth())
	if availableWidth ~= nil and availableWidth > 0 then
		body:SetWidth(availableWidth)
	end
	if self._frameResizing == true or GF._frameResizing == true then
		return false
	end
	self:ApplyCompactRowLayout()
	self:UpdateFieldLayout()
	local contentHeight = self:MeasureFormBodyHeight()
	body:SetHeight(contentHeight)
	GF.UI.UpdateScrollFrame(scroll)
	updateCreateScrollBar(self)

	local viewportHeight = tonumber(scroll:GetHeight()) or 0
	local targetOffset = tonumber(scroll:GetVerticalScroll()) or 0
	if viewportHeight > 0 and contentHeight <= viewportHeight then
		targetOffset = 0
	else
		local maximum = tonumber(scroll:GetVerticalScrollRange()) or 0
		targetOffset = math.min(targetOffset, maximum)
	end
	if GF.UI.CancelSmoothWheelScrolling then
		GF.UI.CancelSmoothWheelScrolling(scroll)
	end
	scroll:SetVerticalScroll(math.max(0, targetOffset))
	return true
end

local blurCreationControls

function CP:UpdateBlockedOverlayLayout()
	local overlay = self.blockedOverlay
	local text = overlay and overlay.text
	if not text then
		return
	end
	local width = overlay.GetWidth and overlay:GetWidth() or 0
	if width <= 0 and self.parent and self.parent.GetWidth then
		width = self.parent:GetWidth() or 0
	end
	if width > 0 then
		text:SetWidth(math.max(
			width - (CREATE_BLOCKED_TEXT_INSET_X * 2),
			1
		))
		text:SetHeight(0)
	end
end

function CP:SyncBlockedOverlayFrameLevel()
	if self.blockedOverlay and self.parent then
		self.blockedOverlay:SetFrameLevel(
			(self.parent.GetFrameLevel
				and self.parent:GetFrameLevel() or 0) + 30
		)
	end
	self:UpdateBlockedOverlayLayout()
end

function CP:EnsureBlockedOverlay()
	if self.blockedOverlay then
		self:SyncBlockedOverlayFrameLevel()
		return self.blockedOverlay
	end
	if not self.parent then
		return self.blockedOverlay
	end
	local L = GF.L or {}
	local overlay = CreateFrame("Frame", nil, self.parent)
	overlay:SetAllPoints(self.parent)
	overlay:EnableMouse(false)

	local text = GF.UI.CreateFontString(overlay, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("CENTER", overlay, "CENTER", 0, 18)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(true)
	text:SetNonSpaceWrap(true)
	text:SetMaxLines(0)
	text:SetHeight(0)
	text:SetTextColor(1, 0.82, 0, 1)
	text:SetText(L.CREATE_CHANNEL_OCCUPIED or "系统预创建队伍正在占用招募通道")
	overlay.text = text
	overlay:SetScript("OnSizeChanged", function()
		CP:UpdateBlockedOverlayLayout()
	end)

	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local iconWidth = GF.BROWSE_LOADING_ICON_WIDTH or 27
	local iconHeight = GF.BROWSE_LOADING_ICON_HEIGHT or 25
	local iconGap = GF.BROWSE_LOADING_ICON_GAP or 6
	local width = (iconWidth * iconCount) + (iconGap * math.max(0, iconCount - 1))
	local animation = CreateFrame("Frame", nil, overlay)
	animation:SetSize(width, iconHeight)
	animation:SetPoint("TOP", text, "BOTTOM", 0, -(GF.BROWSE_LOADING_TEXT_GAP or 7))
	animation.icons = {}
	for index = 1, iconCount do
		local icon = animation:CreateTexture(nil, "ARTWORK")
		icon:SetTexture(GF.BROWSE_LOADING_TEAMUP_TEXTURE or GF.TEAMUP_TEXTURE)
		local coords = (GF.TEAMUP_TEXTURE_FRAME_COORDS or {})[index]
		if coords then
			icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			icon:SetTexCoord((index - 1) / iconCount, index / iconCount, 0, 1)
		end
		icon:SetSize(iconWidth, iconHeight)
		icon:SetPoint("LEFT", animation, "LEFT", (index - 1) * (iconWidth + iconGap), 0)
		icon:SetAlpha(0)
		icon:Hide()
		animation.icons[index] = icon
	end
	animation:SetScript("OnShow", function(frame)
		frame.elapsed = 0
		refreshLoadingAnimation(frame)
	end)
	animation:SetScript("OnUpdate", function(frame, elapsed)
		frame.elapsed = ((frame.elapsed or 0) + (elapsed or 0)) % getLoadingCycleSeconds()
		refreshLoadingAnimation(frame)
	end)
	overlay.animation = animation
	overlay:Hide()
	self.blockedOverlay = overlay
	self:SyncBlockedOverlayFrameLevel()
	return overlay
end

function CP:SetCreateChannelBlocked(blocked)
	blocked = blocked == true
	if self._createChannelBlocked == blocked then
		return false
	end
	self._createChannelBlocked = blocked
	if blocked then
		blurCreationControls(self)
	end
	local overlay = self:EnsureBlockedOverlay()
	if overlay then
		overlay:SetShown(blocked)
	end
	if self.scroll then
		self.scroll:SetShown(not blocked)
	end
	if self.scrollBar then
		self.scrollBar:SetShown(not blocked)
	end
	return true
end

function CP:UpdateOwnershipUI()
	local channelUnavailable = isCreateChannelBlocked()
	local visibilityChanged = self:SetCreateChannelBlocked(channelUnavailable)
	self:UpdateManageState()
	local sidebar = GF.MythicPlusCreateManagerPanel
	if visibilityChanged and sidebar ~= nil
		and type(sidebar.IsSurfaceActive) == "function"
		and sidebar:IsSurfaceActive() == true
		and type(sidebar.RefreshDungeonControlState) == "function"
	then
		sidebar:RefreshDungeonControlState()
	end
end

function CP:IsBorrowingBlizzardFields()
	local creation = getEntryCreation()
	local host = self:GetEmbedParent()
	if creation == nil or host == nil then
		return false
	end
	local containerOwned = creation:GetParent() == host
		or (BB.IsBorrowedBy and BB.IsBorrowedBy(
			creation,
			CREATE_FIELD_OWNER,
			CREATE_FIELD_CHANNEL
		))
	if not containerOwned then
		return false
	end
	return true
end

local function ownerAfterRelease(reason)
	return reason == "blizzard" and "blizzard" or nil
end

local function parkCreatePlaceholder(placeholder, parent)
	if placeholder == nil or parent == nil then
		return
	end
	placeholder:Hide()
	placeholder:SetAlpha(1)
	if placeholder.SetParent then
		placeholder:SetParent(parent)
	end
	placeholder:ClearAllPoints()
end

local function parkCreatePlaceholders(panel)
	local placeholderParent = panel and panel.formBody
	if placeholderParent == nil then
		return
	end
	parkCreatePlaceholder(panel.namePlaceholder, placeholderParent)
	parkCreatePlaceholder(panel.descPlaceholder, placeholderParent)
end

local function clearBorrowedHandles(panel, reason)
	parkCreatePlaceholders(panel)
	panel._attached = false
	panel.nameEdit = nil
	panel.commentScroll = nil
	panel.voiceFrame = nil
	panel.voiceEdit = nil
	GF.entryCreationOwner = ownerAfterRelease(reason)
end

local function captureSafeFieldDraft(panel, creation)
	local draft = {
		name = BB.ReadEditText(creation and creation.Name),
	}
	local descriptionEdit = creation and creation.Description
		and creation.Description.EditBox
	draft.desc = BB.ReadEditText(descriptionEdit)
	panel._fieldDraft = draft
end

function CP:ReleaseCreateFields(reason)
	local releaseReason = reason or "tab"
	self:ApplyCreateManagerBorrowedFieldTextVisual(false)
	parkCreatePlaceholders(self)
	if self:IsBorrowingBlizzardFields() then
		self._attached = true
		return self:ReleaseBlizzardFields(releaseReason)
	end
	clearBorrowedHandles(self, releaseReason)
	if releaseShouldExposeNative(releaseReason) then
		self:UpdateOwnershipUI()
	end
	return false
end

function CP:ReleaseBlizzardFields(reason)
	local releaseReason = reason or "tab"
	parkCreatePlaceholders(self)
	local currentlyBorrowed = self:IsBorrowingBlizzardFields()
	if not currentlyBorrowed then
		clearBorrowedHandles(self, releaseReason)
		self:UpdateOwnershipUI()
		return false
	end

	local creation = getEntryCreation()
	if creation == nil then
		clearBorrowedHandles(self, releaseReason)
		self:UpdateOwnershipUI()
		return false
	end
	captureSafeFieldDraft(self, creation)
	restoreEntryCreationToBlizzard(creation, self, releaseReason)
	clearBorrowedHandles(self, releaseReason)
	self:UpdateCustomPlaceholders()
	self:UpdateOwnershipUI()
	return true
end

function CP:AttachBlizzardFields()
	local creation = getEntryCreation()
	if creation == nil or self.parent == nil then
		return false
	end
	if isCreateChannelBlocked() then
		self:UpdateOwnershipUI()
		return false
	end
	self._suppressedWidgets = self._suppressedWidgets or {}
	local activityID = self.selection and resolveActivityID(self.selection)
	if activityID == nil or type(self.selection) ~= "table"
		or self.selection.categoryID == nil
		or not activitySelectionIsLive(
			activityID,
			self.selection.categoryID
		)
	then
		self:UpdateOwnershipUI()
		return false
	end
	if not self:SyncEntryCreationStateIfNeeded(self.selection, activityID)
		or creation.selectedActivity ~= activityID
	then
		self:UpdateOwnershipUI()
		return false
	end
	if self._attached == true and GF.entryCreationOwner == "gf" then
		if not self:IsBorrowingBlizzardFields()
			or not entryCreationFieldsKeepNativeParents(creation)
		then
			self:UpdateOwnershipUI()
			return false
		end
		parkNativeEntryShell(self, creation)
		self.nameEdit = creation.Name
		self.commentScroll = creation.Description
		self.voiceFrame = creation.VoiceChat
		self.voiceEdit = creation.VoiceChat and creation.VoiceChat.EditBox
		self:UpdateFieldLayout()
		if not widgetShown(creation)
			and not showEntryCreationForAddon(creation)
		then
			return false
		end
		self:UpdateOwnershipUI()
		return true
	end

	captureEntryCreationProjection(creation)
	captureEntryCreationInteraction(creation)
	creation:Hide()
	parkNativeEntryShell(self, creation)
	if not embedEntryCreationContainer(creation, self:GetEmbedParent()) then
		restoreEntryCreationToBlizzard(creation, self, "tab")
		return false
	end
	BB.CacheLayout(creation.VoiceChat)
	BB.CacheLayout(creation.VoiceChat and creation.VoiceChat.EditBox)
	self.nameEdit = creation.Name
	self.commentScroll = creation.Description
	self.voiceFrame = creation.VoiceChat
	self.voiceEdit = creation.VoiceChat and creation.VoiceChat.EditBox
	if self.nameEdit then
		suppressNativeInstructions(self.nameEdit)
	end
	if self.commentScroll and self.commentScroll.EditBox then
		suppressNativeInstructions(self.commentScroll.EditBox)
	end
	self.entryCreation = creation
	self._attached = true
	GF.entryCreationOwner = "gf"
	self:UpdateFieldLayout()
	self:UpdateRequirementLayout()
	self:InstallBlizzardFieldScripts(creation)
	if not showEntryCreationForAddon(creation) then
		restoreEntryCreationToBlizzard(creation, self, "tab")
		clearBorrowedHandles(self, "tab")
		self:UpdateOwnershipUI()
		return false
	end
	self:SyncEmbeddedFieldChrome(creation)
	self:LayoutCustomPlaceholders()
	self:UpdateCustomPlaceholders()
	self:UpdateOwnershipUI()
	return true
end

function CP:RefreshCreateFieldHandoff()
	self:InstallEntryCreationHooks()
	if not isCreateFieldSurfaceActive() then
		return false
	end
	local channelOwnedElsewhere = nativeChannelOccupied()
	if channelOwnedElsewhere then
		if self:IsBorrowingBlizzardFields() then
			self:ReleaseBlizzardFields("blizzard")
		else
			self:UpdateOwnershipUI()
		end
		return false
	end
	if type(self.ResumePendingOpenMode) == "function"
		and self:ResumePendingOpenMode() == true
	then
		return true
	end
	local attached = self:AttachBlizzardFields()
	local activityID = self.selection and resolveActivityID(self.selection)
	if attached and activityID ~= nil then
		self:SyncEntryCreationStateIfNeeded(self.selection, activityID)
	end
	return attached
end

function CP:TryAttachIfNeeded()
	return self:RefreshCreateFieldHandoff()
end

function CP:ActivateCreateChannel()
	if BB and type(BB.SetActiveOwner) == "function" then
		BB.SetActiveOwner(CREATE_FIELD_OWNER)
	end
	if isCreateFieldSurfaceActive() then
		return self:RefreshCreateFieldHandoff()
	end
	return false
end

function CP:StartCreateFieldOwnershipWatch()
	if self._createFieldOwnershipTicker ~= nil
		or C_Timer == nil or type(C_Timer.NewTicker) ~= "function"
	then
		return
	end
	local interval = GF.CREATE_FIELD_OWNERSHIP_POLL_SEC or 0.35
	self._createFieldOwnershipTicker = C_Timer.NewTicker(interval, function()
		if not isCreateFieldSurfaceActive() then
			CP:StopCreateFieldOwnershipWatch()
			return
		end
		if nativeChannelOccupied() then
			CP:UpdateOwnershipUI()
			return
		end
		if type(CP.ResumePendingOpenMode) == "function"
			and CP:ResumePendingOpenMode() == true
		then
			return
		end
		CP:AttachBlizzardFields()
	end)
end

function CP:StopCreateFieldOwnershipWatch()
	local ticker = self._createFieldOwnershipTicker
	self._createFieldOwnershipTicker = nil
	if ticker and type(ticker.Cancel) == "function" then
		ticker:Cancel()
	end
end

function CP:InstallEntryCreationHooks()
	if self._ecHooksInstalled == true then
		return true
	end
	local finder, nativePanel = LFGListFrame, getEntryCreation()
	if finder == nil or nativePanel == nil then
		return false
	end

	local function yieldFieldsToNativeUI()
		if BB ~= nil and type(BB.SetActiveOwner) == "function" then
			BB.SetActiveOwner("blizzard")
		end
		if isCreateFieldSurfaceActive() then
			CP:ReleaseCreateFields("blizzard")
		end
	end

	local function reclaimFieldsForAddon()
		if not isCreateFieldSurfaceActive() then
			return
		end
		if BB ~= nil and type(BB.SetActiveOwner) == "function" then
			BB.SetActiveOwner(CREATE_FIELD_OWNER)
		end
		CP:RefreshCreateFieldHandoff()
		CP:SyncEmbeddedFieldChrome()
	end

	local function reapplyGroupFinderReadOnlyGate()
		if CP._protectedFieldsFormEnabled == false
			and CP._attached == true
			and CP:IsBorrowingBlizzardFields()
		then
			applyProtectedCreationGate(nativePanel, false)
		end
	end

	installDescriptionCursorGuard(nativePanel)
	if type(nativePanel.HookScript) == "function" then
		nativePanel:HookScript("OnShow", function()
			if nativePanel._gfShowingBorrowedEntryCreation == true then
				reapplyGroupFinderReadOnlyGate()
				return
			end
			if nativePanel._gfRestoringBorrowedEntryCreation == true then
				return
			end
			installDescriptionCursorGuard(nativePanel)
			yieldFieldsToNativeUI()
		end)
	end

	if type(hooksecurefunc) == "function"
		and type(LFGListFrame_SetActivePanel) == "function"
	then
		hooksecurefunc("LFGListFrame_SetActivePanel", function(frame, selectedPanel)
			if isCreateFieldSurfaceActive() then
				CP:UpdateOwnershipUI()
				if frame == nil or selectedPanel ~= frame.EntryCreation then
					CP:RefreshCreateFieldHandoff()
				end
			end
		end)
	end

	if type(finder.HookScript) == "function" then
		finder:HookScript("OnEvent", function()
			-- Blizzard registers LFG events on the root and directly dispatches
			-- the selected panel's original handler.  This root post-hook runs
			-- after that dispatch and reapplies only GF's disabling gate.
			reapplyGroupFinderReadOnlyGate()
		end)
		finder:HookScript("OnHide", function()
			if not isCreateFieldSurfaceActive() then
				return
			end
			local timer = C_Timer and C_Timer.After
			if type(timer) == "function" then
				timer(0, reclaimFieldsForAddon)
			else
				reclaimFieldsForAddon()
			end
		end)
		finder:HookScript("OnShow", function()
			settleUnselectedEntryPage()
			if isCreateFieldSurfaceActive() then
				CP:RefreshCreateFieldHandoff()
			end
		end)
	end

	local viewer = finder.ApplicationViewer
	local editButton = viewer and viewer.EditButton
	if editButton ~= nil and type(editButton.HookScript) == "function"
		and editButton._gfReleaseCreateFieldsBeforeNativeEdit ~= true
	then
		editButton:HookScript("OnMouseDown", yieldFieldsToNativeUI)
		editButton._gfReleaseCreateFieldsBeforeNativeEdit = true
	end

	precacheEntryCreationLayouts()
	self._ecHooksInstalled = true
	return true
end

local function safeUpdateEntryCreationValidState(ec)
	local updater = LFGListEntryCreation_UpdateValidState
	if ec == nil or ec.selectedActivity == nil or type(updater) ~= "function" then
		return false
	end
	updater(ec)
	return true
end

function CP:InstallBlizzardFieldScripts(ec)
	if ec == nil or self._fieldScriptsInstalled == true then
		return false
	end
	local nameBox = ec.Name
	if nameBox ~= nil then
		GF.UI.TrackEditBox(nameBox, "GameFontHighlightSmall")
		nameBox:HookScript("OnTextChanged", function(box)
			syncEditInstructions(box)
			safeUpdateEntryCreationValidState(ec)
			CP:UpdateCustomPlaceholders()
			CP:UpdateManageState()
		end)
	end

	local descriptionBox = ec.Description and ec.Description.EditBox
	if descriptionBox ~= nil then
		installDescriptionCursorGuard(ec)
		GF.UI.TrackEditBox(descriptionBox, "GameFontHighlightSmall")
		descriptionBox:HookScript("OnTextChanged", function(box, userTyped)
			safeDescriptionTextChanged(box, userTyped)
			CP:UpdateManageState()
		end)
	end
	self._fieldScriptsInstalled = true
	return true
end

local function projectSelectionToEntryCreation(panel, node, activityID)
	local ec = getEntryCreation()
	if ec == nil or type(node) ~= "table" or activityID == nil
		or node.categoryID == nil
	then
		return false
	end
	if node._editOnlyActiveListing ~= true
		and type(LFGListEntryCreation_SetBaseFilters) == "function"
	then
		local preferred = node.preferredFilters
			or Enum.LFGListFilter.PvE
		LFGListEntryCreation_SetBaseFilters(ec, preferred)
	end
	local groupID = node.groupID
	if groupID == nil then
		local reader = C_LFGList and C_LFGList.GetActivityInfoTable
		local activity = type(reader) == "function"
			and reader(activityID, node.questID) or nil
		groupID = activity and activity.groupFinderActivityGroupID or nil
	end
	ec.selectedActivity = activityID
	ec.selectedCategory = node.categoryID
	ec.selectedGroup = groupID
	ec.selectedFilters = node.filters or 0
	local style = panel.generalPlaystyle
	if style ~= Enum.LFGEntryGeneralPlaystyle.None then
		ec.generalPlaystyle = style
	end
	return true
end

function CP:SyncEntryCreationState(node, activityID)
	return projectSelectionToEntryCreation(self, node, activityID)
end

function CP:SyncEntryCreationStateIfNeeded(node, activityID)
	if type(node) ~= "table" or activityID == nil
		or not isCreateFieldSurfaceActive() or isCreateChannelBlocked()
	then
		return false
	end
	local creation = getEntryCreation()
	local sameSelection = self._syncedActivityID == activityID
		and self._syncedNodeKey == node.key
		and creation ~= nil
		and creation.selectedActivity == activityID
		and creation.selectedCategory == node.categoryID
	if sameSelection then
		return true
	end
	local projected = projectSelectionToEntryCreation(self, node, activityID)
	if projected then
		self._syncedActivityID, self._syncedNodeKey = activityID, node.key
	end
	return projected
end

local QUEST_CREATE_CONTEXT_FIELDS = {
	"baseFilters",
	"selectedActivity",
	"selectedCategory",
	"selectedGroup",
	"selectedFilters",
	"selectedPlaystyle",
	"generalPlaystyle",
}

local function captureQuestCreateContext(creation)
	local state = {}
	for _, field in ipairs(QUEST_CREATE_CONTEXT_FIELDS) do
		state[field] = creation[field]
	end
	return state
end

local function restoreQuestCreateContext(creation, state)
	if creation == nil or type(state) ~= "table" then
		return false
	end
	for _, field in ipairs(QUEST_CREATE_CONTEXT_FIELDS) do
		creation[field] = state[field]
	end
	if creation.selectedActivity ~= nil then
		pcall(safeUpdateEntryCreationValidState, creation)
	end
	return true
end

function CP:CanAcquireQuestRecruitmentFieldLease()
	return not nativeChannelOccupied()
		and not self:IsBorrowingBlizzardFields()
end

function CP:AcquireQuestRecruitmentFieldLease(resolved)
	if type(resolved) ~= "table" or type(resolved.selection) ~= "table"
		or resolved.activityID == nil or resolved.categoryID == nil
		or not self:CanAcquireQuestRecruitmentFieldLease()
	then
		return nil
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	local creation = getEntryCreation()
	if creation == nil
		or not activitySelectionIsLive(
			resolved.activityID,
			resolved.categoryID,
			resolved.questID
		)
	then
		return nil
	end
	local state = captureQuestCreateContext(creation)
	if not projectSelectionToEntryCreation(
		self,
		resolved.selection,
		resolved.activityID
	) then
		restoreQuestCreateContext(creation, state)
		return nil
	end
	creation.selectedPlaystyle = nil
	local playstyles = Enum and Enum.LFGEntryGeneralPlaystyle
	creation.generalPlaystyle = playstyles and playstyles.None or 0
	local clearTextFields = C_LFGList and C_LFGList.ClearCreationTextFields
	local cleared = type(clearTextFields) == "function"
		and pcall(clearTextFields) == true
	if not cleared then
		restoreQuestCreateContext(creation, state)
		return nil
	end
	return {
		creation = creation,
		state = state,
	}
end

function CP:ReleaseQuestRecruitmentFieldLease(lease)
	if type(lease) ~= "table" or lease.released == true then
		return false
	end
	lease.released = true
	return restoreQuestCreateContext(lease.creation, lease.state)
end

local function hasCreationName(nameEdit, ec)
	if nameEdit == nil or type(nameEdit.GetText) ~= "function" then
		return false
	end
	local ok, text = pcall(nameEdit.GetText, nameEdit)
	if not ok then
		return false
	end
	if secretText(text) then
		return true
	end
	if trimName(text) ~= "" then
		return true
	end
	local sanitize = LFGListEntryCreation_GetSanitizedName
	if ec == nil or type(sanitize) ~= "function" then
		return false
	end
	local sanitizedOK, sanitized = pcall(sanitize, ec)
	return sanitizedOK and (secretText(sanitized) or trimName(sanitized) ~= "")
end

local function selectionRequiresProtectedPrebuiltTitle(panel)
	local selected = panel and panel.selection
	local activityID = selected and resolveActivityID(selected)
	if activityID == nil then
		return false
	end
	local activity = selected.activityInfo
	local reader = C_LFGList and C_LFGList.GetActivityInfoTable
	if selected.categoryID == nil and activity == nil
		and type(reader) == "function"
	then
		local ok, value = pcall(reader, activityID)
		activity = ok and value or nil
	end
	local lockedText = IsActivityLockedForCustomText
	if type(lockedText) ~= "function" then
		return false
	end
	local categoryID = selected.categoryID
		or (type(activity) == "table" and activity.categoryID)
	if categoryID == nil then
		return false
	end
	local ok, locked = pcall(lockedText, categoryID, activityID)
	if not ok or secretText(locked) then
		return false
	end
	return locked == true
end

local function isCreateableSelection(node)
	local workspaceID = CP.workspaceContext and CP.workspaceContext.workspaceID
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.CanCreateSelection then
		return GF.LFGWorkspaceView:CanCreateSelection(node, workspaceID)
	end
	if GF.NavData and GF.NavData.CanCreateFromNode then
		return GF.NavData.CanCreateFromNode(node)
	end
	return resolveActivityID(node) ~= nil
end

local function setWidgetEnabled(widget, enabled)
	if not widget then
		return
	end
	if widget.SetEnabled then
		widget:SetEnabled(enabled)
	end
	if widget.EnableMouse then
		widget:EnableMouse(enabled)
	end
end

local function refreshNativeProtectedFieldInteraction(creation)
	if creation == nil or creation.selectedActivity == nil then
		return false
	end
	if type(LFGListEntryCreation_UpdateAuthenticatedState) == "function" then
		pcall(LFGListEntryCreation_UpdateAuthenticatedState, creation)
	end
	if creation.Name and creation.Name.UpdateEnabledState then
		pcall(creation.Name.UpdateEnabledState, creation.Name)
	end
	if creation.Description and creation.Description.UpdateEnabledState then
		pcall(
			creation.Description.UpdateEnabledState,
			creation.Description
		)
	end
	return true
end

blurCreationControls = function(panel)
	local nativePanel = getEntryCreation()
	if nativePanel ~= nil and type(LFGListEntryCreation_ClearFocus) == "function" then
		LFGListEntryCreation_ClearFocus(nativePanel)
		return
	end
	local controls = {
		panel.nameEdit,
		panel.commentScroll and panel.commentScroll.EditBox,
		panel.voiceEdit,
		panel.ilvlEdit,
		panel.mplusEdit,
	}
	for controlIndex = 1, #controls do
		local control = controls[controlIndex]
		if control ~= nil and type(control.ClearFocus) == "function" then
			control:ClearFocus()
		end
	end
end

local function showCreateError(msg)
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(msg)
	end
end

local function createSizedFrame(parent, width, height)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(width, height)
	return frame
end

local function createFormTitle(parent, text)
	local label = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontNormal")
	label:SetText(text)
	applyCreateTitleTextStyle(label)
	return label
end

local function createPlaceholder(parent, verticalAlignment)
	local placeholder = GF.UI.CreateFontString(
		parent,
		"OVERLAY",
		"GameFontDisableSmall"
	)
	placeholder._gfCreatePlaceholder = true
	placeholder:SetJustifyH("LEFT")
	placeholder:SetWordWrap(verticalAlignment == "TOP")
	placeholder:SetTextColor(0.55, 0.55, 0.55, 1)
	if verticalAlignment ~= nil then
		placeholder:SetJustifyV(verticalAlignment)
	end
	placeholder:Hide()
	return placeholder
end

local function createRequirementEdit(parent, anchor, numeric)
	local editBox = CreateFrame("EditBox", nil, parent, "LFGListEditBoxTemplate")
	editBox:SetPoint("TOPLEFT", anchor, "TOPLEFT")
	editBox:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
	GF.UI.TrackEditBox(editBox, "GameFontHighlightSmall")
	if numeric == true then
		editBox:SetNumeric(true)
	end
	styleCreateInputBox(editBox)
	return editBox
end

local function addOptionHover(check, titleProvider, tipProvider)
	check:SetScript("OnEnter", function(button)
		GF.UI.SetFilterCheckButtonHovered(button, true)
		showCreateOptionTooltip(button, titleProvider(), tipProvider())
	end)
	check:SetScript("OnLeave", function(button)
		GF.UI.SetFilterCheckButtonHovered(button, false)
		GameTooltip_Hide()
	end)
end

local function createFormOption(parent, text, titleProvider, tipProvider)
	local check = GF.UI.CreateFilterCheckButton(parent, {
		size = CREATE_CHECK_SIZE,
		markSize = 16,
	})
	local label = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontNormal")
	label:SetPoint("LEFT", check, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	setCheckHitRectToLabel(check, label)
	addOptionHover(check, titleProvider, tipProvider)
	return check, label
end

local function createFormScroll(panel, parent)
	local footer = getCreateDrawerFooter(parent)
	local scroll = GF.UI.CreateScrollFrame(parent, {
		rowHeight = GF.CREATE_WHEEL_ROW_H or 24,
	})
	if footer ~= nil then
		scroll:SetPoint(
			"TOPLEFT",
			parent,
			"TOPLEFT",
			CREATE_FORM_INSET_X,
			-CREATE_FORM_INSET_TOP
		)
		scroll:SetPoint(
			"BOTTOMRIGHT",
			parent,
			"BOTTOMRIGHT",
			-CREATE_FORM_INSET_X,
			0
		)
		if scroll.ScrollBar ~= nil then
			scroll.ScrollBar:Hide()
		end
	else
		scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", CREATE_PAD, -4)
		scroll:SetPoint(
			"BOTTOMRIGHT",
			parent,
			"BOTTOMRIGHT",
			-(GF.CONTENT_SCROLL_INSET_R or 18),
			BUTTON_BAR_H
		)
		panel.scrollBar = GF.UI.CreateContentScrollBar(scroll, parent)
	end
	scroll:SetFrameLevel(parent:GetFrameLevel() + 2)
	if GF.UI.BindSmoothWheelScrolling then
		GF.UI.BindSmoothWheelScrolling(scroll)
	end
	return scroll, footer
end

local function createFormActions(panel, parent, footer, labels)
	local host = footer or parent
	local bottom = footer and (GF.FILTER_FOOTER_BUTTON_OFFSET_Y or 12)
		or LIST_BTN_BOTTOM
	local halfSpan = math.floor((LIST_BTN_W + LIST_BTN_GAP) / 2)
	panel.listBtn = GF.UI.CreatePanelButton(
		host,
		labels.CREATE_LISTING or "List Group",
		LIST_BTN_W
	)
	panel.removeBtn = GF.UI.CreatePanelButton(
		host,
		labels.REMOVE_LISTING or "Remove",
		LIST_BTN_W
	)
	panel.listBtn:SetPoint("BOTTOM", host, "BOTTOM", -halfSpan, bottom)
	panel.removeBtn:SetPoint("BOTTOM", host, "BOTTOM", halfSpan, bottom)
	GF.UI.AttachActionGuard(panel.listBtn, {
		capability = "listing_leader",
		tooltipPlacement = "aboveLeft",
		onClick = function()
			CP:SubmitListing()
		end,
	})
	GF.UI.AttachActionGuard(panel.removeBtn, {
		capability = "listing_leader",
		tooltipPlacement = "aboveLeft",
		onClick = function()
			local listing = GF.RecruitmentSession
			if listing ~= nil and type(listing.HasActive) == "function"
				and listing:HasActive()
			then
				listing:Remove()
			end
		end,
	})
end

local function prepareFormRoot(panel, parent, labels)
	panel.title = GF.UI.CreateFontString(parent, "OVERLAY", "QuestFont_Huge")
	panel.title:SetPoint("TOPLEFT", parent, "TOPLEFT", CREATE_PAD, -8)
	panel.title:Hide()
	local footer
	panel.scroll, footer = createFormScroll(panel, parent)
	local body = createSizedFrame(panel.scroll, 1, 1)
	panel.formBody = body
	body:SetClipsChildren(true)
	panel.scroll:SetScrollChild(body)
	panel.formColumn = createSizedFrame(body, 1, 1)
	panel.formColumn:SetPoint("TOPLEFT", body, "TOPLEFT")
	panel.formColumn:Hide()
	return body, footer
end

local function populateNativeFieldSlots(panel, form, labels)
	panel.nameLabel = createFormTitle(form, labels.NAME or "Name")
	panel.nameLabel:SetPoint(
		"TOPLEFT",
		form,
		"TOPLEFT",
		FORM_LEFT_INSET,
		0
	)
	panel.nameAtlasAnchor = createSizedFrame(
		form,
		NATIVE_FIELD_SIZE.name.width + FIELD_EDGE_PAD * 2,
		CREATE_FORM_INPUT_H
	)
	panel.nameAtlasAnchor:SetPoint(
		"TOP",
		panel.nameLabel,
		"BOTTOM",
		0,
		-LABEL_FIELD_GAP
	)
	panel.nameAtlasAnchor:SetPoint("LEFT", panel.formColumn, "LEFT")
	styleCreateInputAtlasFrame(panel.nameAtlasAnchor)
	panel.nameAnchor = createSizedFrame(
		form,
		NATIVE_FIELD_SIZE.name.width,
		NATIVE_FIELD_SIZE.name.height
	)
	panel.nameAnchor:SetPoint(
		"TOPLEFT",
		panel.nameAtlasAnchor,
		"TOPLEFT",
		FIELD_EDGE_PAD,
		0
	)
	panel.namePlaceholder = createPlaceholder(form)

	panel.commentLabel = createFormTitle(
		form,
		labels.COMMENT or "Description"
	)
	panel.commentLabel:SetPoint(
		"TOP",
		panel.nameAtlasAnchor,
		"BOTTOM",
		0,
		-FIELD_GAP
	)
	panel.commentLabel:SetPoint("LEFT", panel.formColumn, "LEFT")
	panel.descAtlasAnchor = createSizedFrame(
		form,
		NATIVE_FIELD_SIZE.description.width + FIELD_EDGE_PAD * 2,
		CREATE_FORM_DESC_ATLAS_H
	)
	panel.descAtlasAnchor:SetPoint(
		"TOP",
		panel.commentLabel,
		"BOTTOM",
		0,
		-DESC_FIELD_GAP
	)
	panel.descAtlasAnchor:SetPoint("LEFT", panel.formColumn, "LEFT")
	styleCreateDescriptionAtlasFrame(panel.descAtlasAnchor)
	panel.descAnchor = createSizedFrame(
		form,
		NATIVE_FIELD_SIZE.description.width,
		NATIVE_FIELD_SIZE.description.height
	)
	panel.descAnchor:SetPoint(
		"TOPLEFT",
		panel.descAtlasAnchor,
		"TOPLEFT",
		FIELD_EDGE_PAD,
		-CREATE_FORM_DESC_ATLAS_PAD_Y
	)
	panel.descPlaceholder = createPlaceholder(form, "TOP")
end

local function populatePreferenceControls(panel, form, labels)
	panel.playLabel = createFormTitle(
		form,
		labels.PLAYSTYLE or "Playstyle"
	)
	panel.playLabel:SetPoint(
		"TOP",
		panel.descAtlasAnchor,
		"BOTTOM",
		0,
		-FIELD_GAP
	)
	panel.playLabel:SetPoint("LEFT", panel.formColumn, "LEFT")
	panel.playDropdownAnchor = createSizedFrame(
		form,
		NATIVE_FIELD_SIZE.description.width + 10,
		DROPDOWN_H
	)
	panel.playDropdownAnchor:SetPoint(
		"TOP",
		panel.playLabel,
		"BOTTOM",
		0,
		-LABEL_FIELD_GAP
	)
	panel.playDropdownAnchor:SetPoint(
		"LEFT",
		panel.formColumn,
		"LEFT",
		DROPDOWN_LEFT_NUDGE,
		0
	)
	panel.playDropdown = GF.UI.CreateDropdownButton(form)
	panel:ApplyPlaystyleDropdownLayout()
	panel:SetupPlaystyleDropdown()

	panel.ilvlLabel = createFormTitle(
		form,
		labels.ITEM_LEVEL or "Item level"
	)
	panel.ilvlLabel:SetPoint(
		"TOP",
		panel.playDropdownAnchor,
		"BOTTOM",
		0,
		-FIELD_GAP
	)
	panel.ilvlLabel:SetPoint("LEFT", panel.formColumn, "LEFT")
	panel.ilvlAnchor = createSizedFrame(form, REQ_EDIT_W, REQ_EDIT_H)
	panel.ilvlAnchor:SetPoint(
		"TOP",
		panel.ilvlLabel,
		"BOTTOM",
		0,
		-LABEL_FIELD_GAP
	)
	panel.ilvlAnchor:SetPoint(
		"LEFT",
		panel.formColumn,
		"LEFT",
		REQ_FIELD_LEFT_NUDGE,
		0
	)
	panel.ilvlEdit = createRequirementEdit(form, panel.ilvlAnchor, true)

	panel.mplusLabel = createFormTitle(
		form,
		labels.MYTHIC_SCORE or "M+ score"
	)
	panel.mplusAnchor = createSizedFrame(form, REQ_EDIT_W, REQ_EDIT_H)
	panel.mplusEdit = createRequirementEdit(form, panel.mplusAnchor, true)
	panel.voiceLabel = createFormTitle(
		form,
		labels.VOICE_CHAT or LFG_LIST_VOICE_CHAT or "Voice chat"
	)
	panel.voiceAnchor = styleCreateInputAtlasFrame(
		createSizedFrame(form, REQ_EDIT_W, REQ_EDIT_H)
	)
	panel:UpdateRequirementLayout()
end

local function populateListingOptions(panel, form, labels)
	panel.crossFactionCheck, panel.crossFactionLabel = createFormOption(
		form,
		getFactionRestrictionLabel(),
		getFactionRestrictionLabel,
		getFactionRestrictionTip
	)
	panel.crossFactionCheck:SetPoint(
		"TOP",
		panel.voiceAnchor,
		"BOTTOM",
		0,
		-8
	)
	panel.crossFactionCheck:SetPoint("LEFT", panel.formColumn, "LEFT")
	panel.crossFactionLabel:SetTextColor(1, 0.82, 0)
	local function privateTitle()
		return (GF.L and GF.L.PRIVATE) or "Private"
	end
	local function privateTip()
		return (GF.L and GF.L.PRIVATE_TIP) or ""
	end
	panel.privateCheck, panel.privateLabel = createFormOption(
		form,
		labels.PRIVATE or "Private",
		privateTitle,
		privateTip
	)
	panel.privateCheck:SetPoint(
		"TOP",
		panel.crossFactionCheck,
		"BOTTOM",
		0,
		-8
	)
	panel.privateCheck:SetPoint("LEFT", panel.formColumn, "LEFT")
	panel:UpdateRequirementLayout()
end

local function handleCreatePanelSizeChanged()
	if CP._frameResizing ~= true then
		CP:ScheduleUpdateScrollLayout()
	end
end

local function initializeCreatePanelLifecycle(panel, parent)
	panel.editMode = false
	panel:UpdatePlaystyleDropdown()
	panel:InstallEntryCreationHooks()
	parent:SetScript("OnSizeChanged", handleCreatePanelSizeChanged)
	panel:UpdateScrollLayout()
end

function CP:Init(parent)
	if self.scroll ~= nil then
		return false
	end
	self.parent = parent
	self.selection = nil
	self.generalPlaystyle = DEFAULT_PLAYSTYLE
	local labels = GF.L or {}
	local form, footer = prepareFormRoot(self, parent, labels)
	populateNativeFieldSlots(self, form, labels)
	populatePreferenceControls(self, form, labels)
	populateListingOptions(self, form, labels)
	createFormActions(self, parent, footer, labels)
	initializeCreatePanelLifecycle(self, parent)
	return true
end



function CP:ApplyPlaystyleDropdownLayout()
	local button, anchor = self.playDropdown, self.playDropdownAnchor
	if button == nil or anchor == nil then
		return false
	end
	local anchorWidth = type(anchor.GetWidth) == "function"
		and tonumber(anchor:GetWidth()) or nil
	local _, descriptionWidth = self:GetCreateFieldWidths()
	local width = descriptionWidth
	if self:IsMythicPlusSidebarMode() then
		width = MPLUS_LFG_SIDEBAR_CONTROL_W
	elseif anchorWidth ~= nil and anchorWidth > 1 then
		width = anchorWidth
	end
	anchor:SetSize(width, DROPDOWN_H)
	button:SetSize(width, DROPDOWN_H)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", anchor, "TOPLEFT")
	return true
end

function CP:SetupPlaystyleDropdown()
	local dropdown = self.playDropdown
	if dropdown == nil or type(dropdown.SetupMenu) ~= "function" then
		return false
	end
	dropdown:SetupMenu(function(_, menu)
		menu:SetTag("MENU_GF_PLAYSTYLE")
		for optionIndex = 1, #PLAYSTYLE_OPTIONS do
			local option = PLAYSTYLE_OPTIONS[optionIndex]
			menu:CreateRadio(
				playstyleText(option),
				function(styleID)
					return CP.generalPlaystyle == styleID
				end,
				function(styleID)
					CP.generalPlaystyle = styleID
					CP:UpdatePlaystyleDropdown()
					local selected = CP.selection
					local activityID = selected and resolveActivityID(selected)
					if activityID ~= nil then
						CP:SyncEntryCreationState(selected, activityID)
					end
				end,
				option.id
			)
		end
	end)
	return true
end



function CP:UpdatePlaystyleDropdown()
	local dropdown = self.playDropdown
	if dropdown == nil then
		return false
	end
	local label = selectedPlaystyleText(self.generalPlaystyle)
	if self.generalPlaystyle == Enum.LFGEntryGeneralPlaystyle.None then
		label = GROUP_FINDER_PLAYSTYLE_REQUIRED
			or (GF.L and GF.L.PLAYSTYLE_REQUIRED)
			or "Select playstyle"
		local color = DISABLED_FONT_COLOR
		if color ~= nil and type(color.WrapTextInColorCode) == "function" then
			label = color:WrapTextInColorCode(label)
		end
	end
	dropdown:SetDefaultText(label)
	if type(dropdown.GenerateMenu) == "function" then
		dropdown:GenerateMenu()
	end
	self:ApplyPlaystyleDropdownLayout()
	return true
end



function CP:UpdateCrossFactionOption()
	local check, label = self.crossFactionCheck, self.crossFactionLabel
	if check == nil then
		return false
	end
	if self:IsMythicPlusSidebarMode() then
		check:Hide()
		if label ~= nil then
			label:Hide()
		end
		return true
	end

	if self._showCompleteDisabledForm == true then
		check._gfActivityDisabled = true
		check:SetEnabled(false)
		check:Show()
		if label ~= nil then
			label:SetText(getFactionRestrictionLabel())
			label:SetTextColor(1, 0.82, 0)
			label:Show()
		end
		self:ApplyCompactRowLayout()
		self:UpdateScrollLayout()
		return true
	end

	local selected = self.selection
	local activityID = selected and resolveActivityID(selected)
	local categoryReader = C_LFGList and C_LFGList.GetLfgCategoryInfo
	local category = selected and selected.categoryID
		and type(categoryReader) == "function"
		and categoryReader(selected.categoryID) or nil
	local activity = selected and selected.activityInfo
	local activityReader = C_LFGList and C_LFGList.GetActivityInfoTable
	if activity == nil and activityID ~= nil
		and type(activityReader) == "function"
	then
		activity = activityReader(activityID)
	end
	local available = activityID ~= nil and category ~= nil
		and category.allowCrossFaction == true
		and activity ~= nil and activity.allowCrossFaction == true
	if available then
		check._gfActivityDisabled = nil
	else
		check._gfActivityDisabled = true
	end
	check:SetEnabled(available)
	check:SetShown(available)
	if label ~= nil then
		label:SetShown(available)
		if available then
			label:SetTextColor(1, 0.82, 0)
		end
	end
	self:ApplyCompactRowLayout()
	self:UpdateScrollLayout()
	return true
end



function CP:UpdateScoreRequirementVisibility(activityInfo)
	if not self.mplusLabel then
		return
	end
	local show = self:IsMythicPlusSidebarMode()
		or self._showCompleteDisabledForm
		or (activityInfo and activityInfo.isMythicPlusActivity)
	self.mplusLabel:SetShown(show)
	self.mplusEdit:SetShown(show)
	if self.mplusAnchor then
		self.mplusAnchor:SetShown(show)
	end
end



function CP:ResetAfterListingRemoved()
	self._pendingOpenMode = nil
	self.editMode = false
	self._protectedCreationTextDraftPrepared = nil
	self.selection = nil
	self._syncedActivityID = nil
	self._syncedNodeKey = nil
	self:UpdateListButtonLabel()
	self:UpdateManageState()
end

function CP:SetSelection(node)
	self.selection = node
	if type(node) ~= "table" then
		self:UpdateManageState()
		return false
	end
	if isCreateFieldSurfaceActive() then
		self:TryAttachIfNeeded()
	else
		self:ReleaseCreateFields("tab")
	end
	local activityID = resolveActivityID(node)
	if activityID ~= nil then
		self:SyncEntryCreationStateIfNeeded(node, activityID)
	end
	local info = node.activityInfo
	local readActivity = C_LFGList and C_LFGList.GetActivityInfoTable
	if info == nil and activityID ~= nil and type(readActivity) == "function" then
		info = readActivity(activityID)
	end
	local drawer = GF.CreateDrawer
	if drawer ~= nil and type(drawer.SyncActivityTitle) == "function" then
		drawer:SyncActivityTitle()
	end
	self:UpdateScoreRequirementVisibility(info)
	self:UpdateRequirementLayout()
	self:UpdateCrossFactionOption()
	self:UpdateScrollLayout()
	self:UpdateManageState()
	return true
end

function CP:SetWorkspaceContext(context)
	self.workspaceContext = context
	if self.listBtn then
		self:UpdateManageState()
	end
end



local function listingProblemText(problem)
	local labels = GF.L or {}
	if problem and problem.detail then
		return problem.detail
	end
	local messages = {
		selection = labels.NO_SELECTION or "Select an activity.",
		active_listing = labels.CREATE_ALREADY_LISTED
			or LFG_LIST_CLEAR_ORPHANED_GROUP
			or "You already have an active listing.",
		activity = labels.CREATE_NEED_ACTIVITY
			or "Select a specific activity difficulty.",
		playstyle = labels.PLAYSTYLE_REQUIRED
			or GROUP_FINDER_PLAYSTYLE_REQUIRED
			or "Select playstyle.",
		workspace = labels.MPLUS_CREATE_SCOPE_ERROR
			or "Select a current-season Mythic+ dungeon.",
		keystone = LFG_AUTHENTICATOR_BUTTON_MYTHIC_PLUS_TOOLTIP
			or labels.CREATE_NEED_KEYSTONE
			or "M+ keystone required.",
		name = LFG_LIST_MUST_HAVE_NAME
			or labels.CREATE_NEED_NAME
			or "Name required.",
		cross_faction = labels.EDIT_CROSS_FACTION_BLOCKED
			or "Remove listing before changing cross-faction.",
	}
	return messages[problem and problem.code]
		or labels.CREATE_FAILED
		or "Listing failed. Please try again."
end

local function numericEditValue(editBox)
	if editBox == nil or type(editBox.GetText) ~= "function" then
		return 0
	end
	local ok, value = pcall(editBox.GetText, editBox)
	if not ok or secretText(value) then
		return 0
	end
	return tonumber(value) or 0
end

local function checkedValue(checkButton)
	return checkButton ~= nil and type(checkButton.GetChecked) == "function"
		and checkButton:GetChecked() == true
end

function CP:CaptureListingDraft(opts)
	opts = opts or {}
	local context = self.workspaceContext
	local prebuiltTitleReady = opts.prebuiltTitleReady == true
		and selectionRequiresProtectedPrebuiltTitle(self)
	return {
		selection = self.selection,
		editMode = self.editMode == true,
		workspaceID = context and context.workspaceID,
		generalPlaystyle = self.generalPlaystyle,
		hasCreationName = hasCreationName(
			self.nameEdit,
			getEntryCreation()
		) or prebuiltTitleReady,
		privateGroup = checkedValue(self.privateCheck),
		factionRestricted = checkedValue(self.crossFactionCheck),
		requiredItemLevel = numericEditValue(self.ilvlEdit),
		requiredDungeonScore = numericEditValue(self.mplusEdit),
	}
end

function CP:ValidateListing(opts)
	local policy = GF.RecruitmentDraftPolicy
	if policy == nil or type(policy.Validate) ~= "function" then
		showCreateError(listingProblemText({ code = "selection" }))
		return false
	end
	local draft = self:CaptureListingDraft(opts)
	local valid, problem = policy:Validate(draft)
	if valid == true then
		return true, draft
	end
	showCreateError(listingProblemText(problem))
	return false
end

function CP:BuildListingParams(draft)
	local policy = GF.RecruitmentDraftPolicy
	return policy ~= nil and type(policy.BuildParameters) == "function"
		and policy:BuildParameters(draft or self:CaptureListingDraft()) or nil
end



function CP:UpdateListButtonLabel()
	local button = self.listBtn
	if button == nil then
		return false
	end
	local labels = GF.L or {}
	local listing = GF.RecruitmentSession
	local active = listing ~= nil and type(listing.HasActive) == "function"
		and listing:HasActive() == true
	local text = labels.CREATE_LISTING or "List Group"
	if self.editMode == true or active then
		text = labels.SAVE_LISTING or "Save"
	end
	button:SetText(text)
	return true
end

function CP:ApplyDefaultRequiredItemLevel(force)
	if self.editMode then
		return
	end
	if not self.ilvlEdit then
		return
	end
	local defaultItemLevel = getDefaultRequiredItemLevel()
	if not defaultItemLevel then
		return
	end
	local defaultText = tostring(defaultItemLevel)
	local currentText = trimName(self.ilvlEdit:GetText())
	if force or currentText == "" or currentText == "0" or currentText == self._defaultRequiredItemLevelText then
		self.ilvlEdit:SetText(defaultText)
		self._defaultRequiredItemLevelText = defaultText
	end
end

function CP:ApplyDefaultRequiredDungeonScore(force)
	if self.editMode or force ~= true or not self.mplusEdit then
		return
	end
	self.mplusEdit:SetText(tostring(DEFAULT_REQUIRED_DUNGEON_SCORE))
end

function CP:RefreshLocale()
	local L = GF.L or {}
	if self.nameLabel then
		self.nameLabel:SetText(L.NAME or "Name")
	end
	if self.commentLabel then
		self.commentLabel:SetText(L.COMMENT or "Description")
	end
	if self.playLabel then
		self.playLabel:SetText(L.PLAYSTYLE or "Playstyle")
	end
	if self.ilvlLabel then
		self.ilvlLabel:SetText(L.ITEM_LEVEL or "Item level")
	end
	if self.mplusLabel then
		self.mplusLabel:SetText(L.MYTHIC_SCORE or "M+ score")
	end
	if self.voiceLabel then
		self.voiceLabel:SetText(L.VOICE_CHAT or LFG_LIST_VOICE_CHAT or "Voice chat")
	end
	if self.privateLabel then
		self.privateLabel:SetText(L.PRIVATE or "Private")
	end
	self:UpdateCustomPlaceholders()
	self:SetupPlaystyleDropdown()
	self:UpdatePlaystyleDropdown()
	self:UpdateCrossFactionOption()
	setCheckHitRectToLabel(self.crossFactionCheck, self.crossFactionLabel)
	setCheckHitRectToLabel(self.privateCheck, self.privateLabel)
	self:UpdateRequirementLayout()
	self:UpdateListButtonLabel()
	if self.removeBtn then
		self.removeBtn:SetText(L.REMOVE_LISTING or "Remove")
	end
	self:UpdateOwnershipUI()
	if GF.CreateDrawer and GF.CreateDrawer.SyncActivityTitle then
		GF.CreateDrawer:SyncActivityTitle()
	end
	self:FitMythicPlusSidebarLabels()
end

function CP:UpdateFormInteractionState(formEnabled)
	formEnabled = formEnabled == true
	self._protectedFieldsFormEnabled = formEnabled
	self._createManagerFormDisabled =
		self:IsCreateManagerSurface() and not formEnabled
	self._showCompleteDisabledForm = (not formEnabled) and (not isCreateChannelBlocked())
	local activityID = resolveActivityID(self.selection)
	local activityInfo = activityID and (self.selection.activityInfo or C_LFGList.GetActivityInfoTable(activityID))
	self:UpdateScoreRequirementVisibility(activityInfo)
	self:UpdateCrossFactionOption()
	self:ApplyMythicPlusSidebarTitleStyle()
	if self.formBody then
		self.formBody:SetAlpha(
			(formEnabled or self:IsMythicPlusSidebarMode())
				and 1
				or 0.45
		)
	end
	if not formEnabled then
		blurCreationControls(self)
	end
	if not formEnabled and self:IsMythicPlusSidebarMode() then
		self:CaptureCreateManagerBorrowedFieldTextColors()
	end
	local creation = getEntryCreation()
	local borrowedCreation = self._attached == true
		and self:IsBorrowingBlizzardFields()
		and creation or nil
	refreshNativeProtectedFieldInteraction(borrowedCreation)
	applyProtectedCreationGate(borrowedCreation, formEnabled)
	self:ApplyCreateManagerBorrowedFieldTextVisual(
		not formEnabled and self:IsMythicPlusSidebarMode()
	)
	setWidgetEnabled(self.playDropdown, formEnabled)
	self:ApplyCreateManagerDropdownDisabledVisual(
		self.playDropdown,
		not formEnabled
	)
	setWidgetEnabled(self.ilvlEdit, formEnabled)
	setWidgetEnabled(self.mplusEdit, formEnabled)
	setWidgetEnabled(self.privateCheck, formEnabled)
	if self.crossFactionCheck and (not self.crossFactionCheck._gfActivityDisabled) then
		setWidgetEnabled(self.crossFactionCheck, formEnabled)
	end
	local nameEnabled = self.nameEdit
		and (not self.nameEdit.IsEnabled or self.nameEdit:IsEnabled())
		or false
	updateCreateInputAtlasFrame(
		self.nameAtlasAnchor,
		nameEnabled
			and self.nameEdit
			and (
				self.nameEdit:HasFocus()
				or self.nameEdit._gfCreateNameHovered
			),
		nameEnabled
	)
	updateBorrowedDescriptionAtlas(self.commentScroll)
	updateCreateInputBox(self.ilvlEdit)
	updateCreateInputBox(self.mplusEdit)
	updateBorrowedVoiceAtlas(self, self.voiceFrame)
end

function CP:HasRequiredCreateFields()
	return hasCreationName(self.nameEdit, getEntryCreation())
		or selectionRequiresProtectedPrebuiltTitle(self)
end

function CP:UpdateManageState()
	if not self.listBtn then
		return
	end
	local listing = GF.RecruitmentSession
	local blocked = isCreateChannelBlocked()
	local bumpBusy = listing and listing.IsBusy
		and listing:IsBusy() or false
	local canLead = listing and listing.CanPublish
		and listing:CanPublish()
	local canManage = listing and listing.CanManageApplicants
		and listing:CanManageApplicants()
	local hasActive = listing and listing.HasActive
		and listing:HasActive()
	local premadeCreateBlocked =
		self:IsMythicPlusCreateManagerSurface()
		and not hasActive
		and GF.Availability
		and GF.Availability.GetPremadeBlockMessage
		and GF.Availability:GetPremadeBlockMessage()
	local selectionCreateable = self.editMode
		and resolveActivityID(self.selection) ~= nil
		or isCreateableSelection(self.selection)
	local requiredComplete = self:HasRequiredCreateFields()
	local formCanEdit = ((not self.editMode) or canManage)
		and not bumpBusy
	if self:IsMythicPlusSidebarMode() then
		formCanEdit = canLead and formCanEdit
	end
	local submitCanManage = ((not self.editMode) or canManage)
		and not bumpBusy
	self._mythicPlusSidebarReadOnly =
		self:IsMythicPlusSidebarMode() and not canLead
	local preserveDisabledButtonAlpha = self:IsCreateManagerSurface()
		and CREATE_MANAGER_DISABLED_VISUAL.preserveButtonAlpha ~= false
	if GF.UI and GF.UI.SetCommonPanelButtonPreserveDisabledAlpha then
		GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
			self.listBtn,
			preserveDisabledButtonAlpha
		)
		GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
			self.removeBtn,
			preserveDisabledButtonAlpha
		)
	end
	self:UpdateFormInteractionState(
		selectionCreateable
			and not blocked
			and not premadeCreateBlocked
			and formCanEdit
	)
	self.listBtn:SetEnabled(
		canLead and submitCanManage
			and not blocked
			and not premadeCreateBlocked
			and selectionCreateable and requiredComplete
	)
	if self.removeBtn then
		self.removeBtn:SetEnabled(
			canLead and hasActive and not blocked and not bumpBusy
		)
	end
end

local function resolveActiveListingEditSelection(activityID)
	local node = activityID and GF.NavData and GF.NavData.FindNodeByActivityID
		and GF.NavData.FindNodeByActivityID(activityID)
	if not (node and node.activityID == activityID and node.categoryID) then
		node = buildActiveListingEditSelection(activityID)
	end
	return node
end

function CP:PrepareForOccupiedEdit()
	if not GF.RecruitmentSession or not GF.RecruitmentSession:HasActive() then
		self._pendingOpenMode = nil
		self.editMode = false
		self.selection = nil
		self:UpdateManageState()
		return false
	end
	self._pendingOpenMode = "edit"
	self.editMode = true
	self._protectedCreationTextDraftPrepared = nil
	self.selection = resolveActiveListingEditSelection(GF.RecruitmentSession:GetActiveActivityID())
	self:UpdateListButtonLabel()
	self:UpdateManageState()
	if GF.CreateDrawer then
		GF.CreateDrawer:SyncActivityTitle()
	end
	return self.selection ~= nil
end

function CP:ResumePendingOpenMode()
	if self._pendingOpenMode ~= "edit" or isCreateChannelBlocked() then
		return false
	end
	self._pendingOpenMode = nil
	if BB and BB.SetActiveOwner then
		BB.SetActiveOwner(CREATE_FIELD_OWNER)
	end
	self:PrepareForEdit()
	return true
end

local function applyActiveListingDraft(panel, activeInfo)
	if type(activeInfo) ~= "table" then
		return
	end
	local style = activeInfo.generalPlaystyle
	if style ~= nil and style ~= Enum.LFGEntryGeneralPlaystyle.None then
		panel.generalPlaystyle = style
	end
	if panel.privateCheck ~= nil then
		panel.privateCheck:SetChecked(activeInfo.privateGroup == true)
	end
	if panel.crossFactionCheck ~= nil then
		local crossFaction = activeInfo.isCrossFactionListing == true
			or activeInfo.isCrossFaction == true
		panel.crossFactionCheck:SetChecked(not crossFaction)
	end
	if panel.ilvlEdit ~= nil then
		panel.ilvlEdit:SetText(tostring(activeInfo.requiredItemLevel or 0))
	end
	if panel.mplusEdit ~= nil then
		panel.mplusEdit:SetText(tostring(activeInfo.requiredDungeonScore or 0))
	end
end

local function repaintPreparedEdit(panel)
	panel:AttachBlizzardFields()
	panel:UpdatePlaystyleDropdown()
	panel:UpdateCrossFactionOption()
	panel:UpdateRequirementLayout()
	panel:UpdateListButtonLabel()
	panel:UpdateManageState()
	panel:RefreshCreateFieldHandoff()
	panel:SyncEmbeddedFieldChrome()
	panel:UpdateScrollLayout()
	local drawer = GF.CreateDrawer
	if drawer ~= nil and type(drawer.SyncActivityTitle) == "function" then
		drawer:SyncActivityTitle()
	end
end

function CP:PrepareForEdit()
	local listing = GF.RecruitmentSession
	if listing == nil or type(listing.HasActive) ~= "function"
		or not listing:HasActive()
	then
		self._pendingOpenMode = nil
		self.selection = nil
		self:UpdateManageState()
		return false
	end
	if isCreateChannelBlocked() then
		return self:PrepareForOccupiedEdit()
	end

	self._pendingOpenMode = nil
	self.editMode = true
	self._protectedCreationTextDraftPrepared = nil
	self._defaultRequiredItemLevelText = nil
	local copyActive = C_LFGList
		and C_LFGList.CopyActiveEntryInfoToCreationFields
	if type(copyActive) == "function" then
		copyActive()
	end
	local activeInfo = listing:GetActive()
	local originalActivityID = listing:GetActiveActivityID()
	local editSelection = resolveActiveListingEditSelection(
		originalActivityID
	)
	self.selection = editSelection
	applyActiveListingDraft(self, activeInfo)
	if editSelection ~= nil and originalActivityID ~= nil then
		self:SyncEntryCreationStateIfNeeded(
			editSelection,
			originalActivityID
		)
	end
	repaintPreparedEdit(self)
	return editSelection ~= nil
end

function CP:PrepareForCreate(opts)
	opts = opts or {}
	self._pendingOpenMode = nil
	local wasEditMode = self.editMode == true
	self.editMode = false
	local resetNewDraft = opts.resetDefaults == true or wasEditMode
	if resetNewDraft then
		-- Each explicit reset starts a distinct draft.  The prepared marker only
		-- suppresses duplicate clears while that same draft remains open.
		self._protectedCreationTextDraftPrepared = nil
	end
	self:ClearProtectedCreationTextFieldsForNewDraft(resetNewDraft)
	self:ApplyDefaultRequiredItemLevel(resetNewDraft)
	self:ApplyDefaultRequiredDungeonScore(resetNewDraft)
	self:ApplyMythicPlusHiddenCreateDefaults(resetNewDraft)
	self:UpdateListButtonLabel()
	self:UpdateManageState()
	if GF.CreateDrawer then
		GF.CreateDrawer:SyncActivityTitle()
	end
end

function CP:ClearFocus()
	blurCreationControls(self)
end

local function creationAvailabilityProblem(panel, labels)
	if panel.editMode == true then
		return nil
	end
	local availability = GF.Availability
	local reader = availability and availability.GetPremadeBlockMessage
	if type(reader) ~= "function" then
		return nil
	end
	return availability:GetPremadeBlockMessage()
end

local function closeCreateDrawerAfterSubmit(panel)
	local drawer = GF.CreateDrawer
	if drawer ~= nil and not panel:IsMythicPlusSidebarMode()
		and type(drawer.Close) == "function"
	then
		drawer:Close()
	end
end

local function performListingSubmission(panel, params)
	local listing = GF.RecruitmentSession
	if listing == nil or type(listing.CanPublish) ~= "function" then
		return false, "missing"
	end
	if not listing:CanPublish() then
		if type(listing.NotifyLeaderOnly) == "function" then
			listing:NotifyLeaderOnly()
		end
		return false, "leader"
	end
	local operation
	if panel.editMode == true then
		operation = listing.UpdateFromDraft
	else
		operation = listing.Create
	end
	if type(operation) ~= "function" then
		return false, "missing"
	end
	return operation(listing, params) == true, "submit"
end

local function refreshProtectedPrebuiltTitleForSubmission()
	local creation = getEntryCreation()
	local updateTitle = LFGListEntryCreation_SetTitleFromActivityInfo
	if creation == nil or creation.selectedActivity == nil
		or creation.selectedGroup == nil
		or creation.selectedCategory == nil
		or type(updateTitle) ~= "function"
	then
		return false
	end
	-- The native helper may call restricted C_LFGList.SetEntryTitle. This
	-- function is only reached from SubmitListing's hardware-event stack.
	local updated = pcall(updateTitle, creation)
	if not updated then
		return false
	end
	local matchesTitle = C_LFGList
		and C_LFGList.DoesEntryTitleMatchPrebuiltTitle
	if type(matchesTitle) ~= "function" then
		return false
	end
	local matched, result = pcall(
		matchesTitle,
		creation.selectedActivity,
		creation.selectedGroup,
		creation.selectedPlaystyle,
		creation.generalPlaystyle
	)
	return matched and result == true
end

function CP:SubmitListing()
	local labels = GF.L or {}
	local availabilityProblem = creationAvailabilityProblem(self, labels)
	if availabilityProblem ~= nil then
		showCreateError(availabilityProblem)
		return false
	end
	if isCreateChannelBlocked() then
		showCreateError(
			labels.CREATE_BLIZZARD_OWNS
				or "Premade group creation is open in the game UI."
		)
		return false
	end
	if self:AttachBlizzardFields() ~= true then
		showCreateError(
			labels.CREATE_BLIZZARD_UI_MISSING
				or "Premade group UI is not loaded."
		)
		return false
	end

	local selected = self.selection
	local activityID = selected and resolveActivityID(selected)
	if activityID ~= nil then
		self:SyncEntryCreationState(selected, activityID)
	end
	local prebuiltTitleReady = false
	if selectionRequiresProtectedPrebuiltTitle(self) then
		prebuiltTitleReady = refreshProtectedPrebuiltTitleForSubmission()
		if not prebuiltTitleReady then
			showCreateError(
				labels.CREATE_FAILED
					or "Listing failed. Please try again."
			)
			return false
		end
	end
	local valid, draft = self:ValidateListing({
		prebuiltTitleReady = prebuiltTitleReady,
	})
	if not valid then
		return false
	end
	local params = self:BuildListingParams(draft)
	if params == nil then
		return false
	end

	-- CreateListing/UpdateListing are protected. Keep this direct dispatch in
	-- the leader-only button's synchronous hardware-event call stack.
	local succeeded, outcome = performListingSubmission(self, params)
	if not succeeded then
		if outcome == "submit" or outcome == "missing" then
			showCreateError(
				labels.CREATE_FAILED
					or "Listing failed. Please try again."
			)
		end
		return false
	end
	-- Match Blizzard's native order: protected CreateListing/UpdateListing must
	-- consume the prepared title before clearing focus can commit field state.
	blurCreationControls(self)
	closeCreateDrawerAfterSubmit(self)
	return true
end

local function repaintVisibleCreateSurface(panel)
	if not isCreateFieldSurfaceActive() then
		return false
	end
	panel:RefreshCreateFieldHandoff()
	panel:UpdateRequirementLayout()
	panel:SyncEmbeddedFieldChrome()
	panel:UpdateManageState()
	panel:UpdateScrollLayout()
	return true
end

function CP:Show()
	local host = self.parent
	if host == nil or self.scroll == nil then
		return false
	end
	self:StartCreateFieldOwnershipWatch()
	self:RefreshCreateFieldHandoff()
	self:UpdateRequirementLayout()
	local selected = self.selection
	local activityID = selected and resolveActivityID(selected)
	if activityID ~= nil then
		self:SyncEntryCreationStateIfNeeded(selected, activityID)
	end
	self:SyncEmbeddedFieldChrome()
	host:Show()
	self:UpdateManageState()
	local defer = C_Timer and C_Timer.After
	if type(defer) == "function" then
		defer(0, function()
			repaintVisibleCreateSurface(CP)
		end)
	end
	self:UpdateScrollLayout()
	return true
end



function CP:Hide(reason)
	if not self.parent then
		return
	end
	self:StopCreateFieldOwnershipWatch()
	self._pendingOpenMode = nil
	self:ReleaseCreateFields(reason or "panel")
	self:SetCreateChannelBlocked(false)
	self.parent:Hide()
end

function CP:LeaveTab()
	self:Hide("tab")
end

if GF.QuestRecruitmentBridge
	and type(GF.QuestRecruitmentBridge.SetFieldBridge) == "function"
then
	GF.QuestRecruitmentBridge:SetFieldBridge({
		CanAcquire = function()
			return CP:CanAcquireQuestRecruitmentFieldLease()
		end,
		Acquire = function(_, resolved)
			return CP:AcquireQuestRecruitmentFieldLease(resolved)
		end,
		Release = function(_, lease)
			return CP:ReleaseQuestRecruitmentFieldLease(lease)
		end,
	})
end
