local _, GF = ...

GF.MythicPlusBrowseFilterPanel = GF.MythicPlusBrowseFilterPanel or {}
local Panel = GF.MythicPlusBrowseFilterPanel

local PANEL_INSET_X = 8
local PANEL_CONTENT_W = (GF.NAV_WIDTH or 180) - PANEL_INSET_X * 2
local FILTER_OUTER_W = GF.MPLUS_BROWSE_FILTER_OUTER_W
	or PANEL_CONTENT_W
local CARD_FRAME_OUTSET_X = math.floor(
	(FILTER_OUTER_W - PANEL_CONTENT_W) / 2
)
local CARD_FRAME_LAYOUT_X =
	PANEL_INSET_X - CARD_FRAME_OUTSET_X
local CARD_FRAME_W = FILTER_OUTER_W
local NATIVE_CONTROL_W = math.max(
	1,
	GF.MPLUS_LFG_SIDEBAR_CONTROL_W or PANEL_CONTENT_W
)
local NATIVE_CONTROL_OFFSET_X = math.floor(
	(PANEL_CONTENT_W - NATIVE_CONTROL_W) / 2
)
local HEADER_TOP_OFFSET = GF.BROWSE_HEADER_TOP_OFFSET or -20
local HEADER_H = GF.SUBTITLE_HEADER_H or 26
local HEADER_TEXT_SIZE = GF.BROWSE_HEADER_TEXT_SIZE or 14
local HEADER_TEXT_OFFSET_Y = GF.BROWSE_HEADER_TEXT_CENTER_OFFSET_Y or 4
local CONTENT_TOP_GAP = 5
local PANEL_BOTTOM_INSET = 10
local CONTENT_OFFSET_X = -1
local DUNGEON_MATCH_GAP = 9
local MATCH_PRESENCE_GAP = 9
local PRESENCE_THRESHOLD_GAP = 8
local SEARCH_ACTION_GAP = 9
local SECTION_TITLE_H = 16
local PRESENCE_TITLE_TO_CARDS_GAP = 4
local PRESENCE_TITLE_SLOT_H = MATCH_PRESENCE_GAP
	+ SECTION_TITLE_H
	+ PRESENCE_TITLE_TO_CARDS_GAP
local SECTION_TITLE_TEXT_SIZE = GF.CREATE_MANAGER_TITLE_TEXT_SIZE
	or GF.BROWSE_HEADER_TEXT_SIZE
	or 14
local CONTROL_H = 26
local ROLE_ICON_SIZE = GF.ROLE_ICON_SIZE or 18
local ROLE_CARD_HEADER_ICON_SIZE = 22
local ROLE_CARD_TEXT_SIZE = 11
local PRESENCE_CHOICE_TEXT_SIZE = 11
local MATCH_SLOT_SIZE = GF.MPLUS_BROWSE_PROJECTION_SLOT_SIZE or 17
local MATCH_ROLE_ICON_SIZE =
	GF.MPLUS_BROWSE_ROLE_PROJECTION_ICON_SIZE or 17
local MATCH_SPEC_ICON_SIZE =
	GF.MPLUS_BROWSE_SPEC_PROJECTION_ICON_SIZE or 15
local MATCH_SPEC_ICON_INSET =
	GF.MPLUS_BROWSE_SPEC_PROJECTION_ICON_INSET or 1.875
local MATCH_ICON_START_GAP = GF.MPLUS_BROWSE_PROJECTION_START_GAP or 2
local MATCH_ICON_GAP = GF.MPLUS_BROWSE_PROJECTION_ICON_GAP or 1
local MATCH_LABEL_W = GF.MPLUS_BROWSE_MATCH_LABEL_W or 45
local MATCH_LABEL_FIT_W = GF.MPLUS_BROWSE_MATCH_LABEL_FIT_W
	or math.max(1, MATCH_LABEL_W - 1)
local MATCH_LABEL_MIN_FONT_SIZE =
	GF.MPLUS_BROWSE_MATCH_LABEL_MIN_FONT_SIZE or 7
local MAX_PROJECTION_MEMBERS = GF.MPLUS_BROWSE_PROJECTION_MAX_MEMBERS or 5
local SMALL_CHECK_SIZE = 16
local MATCH_CHECK_W = GF.MPLUS_BROWSE_MATCH_CHECK_W or SMALL_CHECK_SIZE
local MATCH_CHECK_H = GF.MPLUS_BROWSE_MATCH_CHECK_H or SMALL_CHECK_SIZE
local MATCH_CHECK_ATLAS_OFFSET_X =
	GF.MPLUS_BROWSE_MATCH_CHECK_ATLAS_OFFSET_X or 0
local MATCH_CHECK_ATLAS_OFFSET_Y =
	GF.MPLUS_BROWSE_MATCH_CHECK_ATLAS_OFFSET_Y or 0
local MATCH_CHECK_MARK_OFFSET_X =
	GF.MPLUS_BROWSE_MATCH_CHECK_MARK_OFFSET_X or 0
local MATCH_CHECK_MARK_OFFSET_Y =
	GF.MPLUS_BROWSE_MATCH_CHECK_MARK_OFFSET_Y or 0
local MATCH_CHECK_ATLAS = GF.MPLUS_BROWSE_MATCH_CHECK_ATLAS or {
	normal = "keybind-bg",
	hover = "keybind-bg_active",
	checked = "keybind-bg_active",
}
local MATCH_CHECK_LABEL_GAP = 3
local MATCH_ROW_CONTENT_W =
	MATCH_CHECK_W
	+ MATCH_CHECK_LABEL_GAP
	+ MATCH_LABEL_W
	+ MATCH_ICON_START_GAP
	+ MATCH_SLOT_SIZE * MAX_PROJECTION_MEMBERS
	+ MATCH_ICON_GAP * math.max(0, MAX_PROJECTION_MEMBERS - 1)
local DUNGEON_BLOCK_H = 46
local MATCH_BLOCK_H = 72
local PRESENCE_BLOCK_H = 98
local THRESHOLD_BLOCK_H = 70
local THRESHOLD_CONTROL_BOTTOM = 14
local SEARCH_BLOCK_H = GF.SUBTITLE_SEARCH_H or 26
local ACTION_BLOCK_H = GF.PANEL_BUTTON_H or 24
local ROLE_CARD_GAP = GF.MPLUS_BROWSE_ROLE_CARD_GAP or 2
local ROLE_CARD_WIDTHS = GF.MPLUS_BROWSE_ROLE_CARD_WIDTHS
	or { 53, 54, 53 }
local ROLE_CARD_H = 78
local ACTION_BUTTON_GAP = GF.SUBTITLE_CONTROL_GAP or 7
local ACTION_BUTTON_W = GF.PANEL_BUTTON_TWO_CHAR_W or 72
local DUNGEON_DROPDOWN_TEXT_W = math.max(
	1,
	NATIVE_CONTROL_W - 44
)
local MATCH_EMPTY_ICON_ALPHA = GF.MPLUS_BROWSE_PROJECTION_EMPTY_ALPHA
	or 0.72
local MATCH_EMPTY_DISABLED_ICON_TINT =
	GF.MPLUS_BROWSE_PROJECTION_EMPTY_DISABLED_TINT or 0.72
local FILTER_DISABLED_ICON_TINT =
	GF.MPLUS_BROWSE_FILTER_DISABLED_ICON_TINT or 0.58
local FILTER_DISABLED_TEXT_COLOR = GF.MPLUS_BROWSE_FILTER_DISABLED_TEXT_COLOR
	or { 0.48, 0.47, 0.44, 1 }
local FILTER_ENABLED_TEXT_COLOR = GF.BROWSE_HEADER_TEXT_COLOR
	or { 1, 0.82, 0, 1 }
local DUNGEON_DISABLED_TITLE_COLOR =
	(GF.CREATE_MANAGER_DISABLED_VISUAL or {}).labelTextColor
	or FILTER_DISABLED_TEXT_COLOR
local CHECK_DISABLED_TINT =
	GF.MPLUS_BROWSE_CHECK_DISABLED_TINT or 0.72
local CHECK_DISABLED_ALPHA =
	GF.MPLUS_BROWSE_CHECK_DISABLED_ALPHA or 1
local ROLE_PROJECTION_PRIORITY = {
	TANK = 1,
	HEALER = 2,
	DAMAGER = 3,
	DEFAULT = 4,
	NONE = 4,
}

local ROLE_DEFS = {
	{
		key = "TANK",
		stateKey = "tankPresence",
	},
	{
		key = "HEALER",
		stateKey = "healerPresence",
	},
	{
		key = "DAMAGER",
		stateKey = "damagerPresence",
	},
}

local function localized(key, fallback, ...)
	local value = GF.L and GF.L[key]
	if type(value) ~= "string" or value == "" then
		value = fallback
	end
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, value, ...)
		return ok and formatted or value
	end
	return value
end

local function getLeaderScoreTooltipText()
	local comparison = localized(
		"MPLUS_BROWSE_FILTER_LEADER_SCORE_COMPARISON",
		"大于"
	)
	if GREEN_FONT_COLOR and GREEN_FONT_COLOR.WrapTextInColorCode then
		comparison = GREEN_FONT_COLOR:WrapTextInColorCode(comparison)
	end
	return localized(
		"MPLUS_BROWSE_FILTER_LEADER_SCORE_TIP",
		"队长的大秘境总评分需%s筛选数值。",
		comparison
	)
end

local function showLeaderScoreTooltip(owner)
	if not (
		owner
		and GameTooltip
		and GameTooltip.SetText
		and GF.UI.BeginGameTooltipAbove
		and GF.UI.ShowGameTooltip
	) then
		return
	end
	GF.UI.BeginGameTooltipAbove(owner, "LEFT")
	local r, g, b = 1, 1, 1
	local baseColor = WHITE_FONT_COLOR or HIGHLIGHT_FONT_COLOR
	if baseColor and baseColor.GetRGB then
		r, g, b = baseColor:GetRGB()
	end
	GameTooltip:SetText(getLeaderScoreTooltipText(), r, g, b, 1, true)
	GF.UI.ShowGameTooltip()
end

local function applyFontSize(fontString, template, size)
	if not fontString then
		return
	end
	fontString._gfFontSizeOverride = size
	fontString._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(
			fontString,
			template or "GameFontNormal"
		)
	elseif fontString.GetFont and fontString.SetFont then
		local path = fontString:GetFont()
		if path then
			fontString:SetFont(path, size, "")
		end
	end
end

local function fitFontToWidth(fontString, width, minimumSize)
	if not fontString then
		return
	end
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(fontString, width, minimumSize)
	end
end

local function setDropdownText(dropdown, text)
	if not dropdown then
		return
	end
	if dropdown.SetText then
		dropdown:SetText(text or "")
	elseif dropdown.SetDefaultText then
		dropdown:SetDefaultText(text or "")
	end
	if dropdown.Text then
		fitFontToWidth(
			dropdown.Text,
			DUNGEON_DROPDOWN_TEXT_W,
			8
		)
	end
end

local function normalizeBool(value)
	return value == true or value == 1
end

local function normalizePresence(value)
	if value == "missing" or value == "existing" then
		return value
	end
	return nil
end

local function normalizeNumber(value, maximum)
	value = math.floor((tonumber(value) or 0) + 0.0001)
	if value < 0 then
		value = 0
	elseif maximum and value > maximum then
		value = maximum
	end
	return value
end

local function normalizeOpenSlots(value)
	value = math.floor((tonumber(value) or 1) + 0.0001)
	if value < 1 then
		return 1
	elseif value > 4 then
		return 4
	end
	return value
end

local function setEnabledTextColor(fontString, enabled)
	if not fontString then
		return
	end
	local color = enabled and FILTER_ENABLED_TEXT_COLOR
		or FILTER_DISABLED_TEXT_COLOR
	fontString:SetTextColor(unpack(color))
end

local function setIconEnabledVisual(texture, enabled)
	if not texture then
		return
	end
	if texture.SetDesaturated then
		texture:SetDesaturated(not enabled)
	end
	if texture.SetVertexColor then
		if enabled then
			texture:SetVertexColor(1, 1, 1, 1)
		else
			texture:SetVertexColor(
				FILTER_DISABLED_ICON_TINT,
				FILTER_DISABLED_ICON_TINT,
				FILTER_DISABLED_ICON_TINT,
				1
			)
		end
	end
end

local function setCardChromeEnabledVisual(frame, enabled)
	if not frame then
		return
	end
	if GF.UI.SetControlCardChromeEnabledVisual then
		GF.UI.SetControlCardChromeEnabledVisual(frame, enabled, {
			disabledTint = CHECK_DISABLED_TINT,
			alpha = 1,
		})
	end
end

local function setInputEnabled(input, enabled)
	if not input then
		return
	end
	if not enabled and input.HasFocus and input:HasFocus()
		and input.ClearFocus then
		input._gfSuppressCommit = true
		input:ClearFocus()
		input._gfSuppressCommit = nil
	end
	if input.SetEnabled then
		input:SetEnabled(enabled)
	end
	if input.EnableMouse then
		input:EnableMouse(enabled)
	end
	if GF.UI.SetFilterNumberBoxVisualEnabled then
		GF.UI.SetFilterNumberBoxVisualEnabled(input, enabled)
	elseif GF.UI.UpdateFilterNumberBox then
		GF.UI.UpdateFilterNumberBox(input)
	end
end

local function normalizeRoleToken(role)
	if type(role) ~= "string" then
		return nil
	end
	role = role:upper()
	if role == "HEAL" then
		return "HEALER"
	end
	if role == "DPS" then
		return "DAMAGER"
	end
	if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
		return role
	end
	return nil
end

local function getCurrentSpecializationRole()
	local specIndex
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
		local ok, value = pcall(C_SpecializationInfo.GetSpecialization)
		if ok then
			specIndex = value
		end
	elseif GetSpecialization then
		local ok, value = pcall(GetSpecialization)
		if ok then
			specIndex = value
		end
	end
	if not specIndex then
		return nil
	end
	if GetSpecializationRole then
		local ok, role = pcall(GetSpecializationRole, specIndex)
		if ok then
			return normalizeRoleToken(role)
		end
	end
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRole then
		local ok, role = pcall(
			C_SpecializationInfo.GetSpecializationRole,
			specIndex
		)
		if ok then
			return normalizeRoleToken(role)
		end
	end
	return nil
end

local function optionKey(option, index)
	if type(option) ~= "table" then
		return tostring(option or index)
	end
	return tostring(
		option.key
			or option.dungeonKey
			or option.activityID
			or option.groupID
			or option.mapID
			or index
	)
end

local function optionLabel(option, index)
	if type(option) ~= "table" then
		return tostring(option or index)
	end
	return option.label
		or option.name
		or option.shortName
		or (option.source and (option.source.label or option.source.name))
		or localized(
			"MPLUS_BROWSE_FILTER_DUNGEON_FALLBACK_FMT",
			"地下城 %d",
			index
		)
end

local function tableContainsKey(values, key)
	if type(values) ~= "table" then
		return false
	end
	if values[key] ~= nil then
		return values[key] == true or values[key] == 1
	end
	for storedKey, selected in pairs(values) do
		if tostring(storedKey) == tostring(key)
			and (selected == true or selected == 1) then
			return true
		end
	end
	for _, value in ipairs(values) do
		if tostring(value) == tostring(key) then
			return true
		end
	end
	return false
end

local function createSectionContainer(parent, height)
	local block = CreateFrame("Frame", nil, parent)
	block:SetSize(PANEL_CONTENT_W, height)
	return block
end

local function createCardBlock(parent, height)
	local block = createSectionContainer(parent, height)
	block:SetWidth(CARD_FRAME_W)
	if block.SetClipsChildren then
		block:SetClipsChildren(true)
	end
	block._gfLayoutX = CARD_FRAME_LAYOUT_X
	block._gfLayoutWidth = CARD_FRAME_W
	if GF.UI.ApplyControlCardChrome then
		GF.UI.ApplyControlCardChrome(block, {
			state = "normal",
			displayMargin = GF.CONTROL_FRAME_DISPLAY_MARGIN or 8,
		})
	end
	return block
end

local function createSectionTitle(parent, text, horizontalInset)
	horizontalInset = tonumber(horizontalInset) or 0
	local title = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", parent, "TOPLEFT", 2 + horizontalInset, 0)
	title:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(2 + horizontalInset), 0)
	title:SetHeight(SECTION_TITLE_H)
	title:SetJustifyH("LEFT")
	title:SetMaxLines(1)
	title:SetWordWrap(false)
	title:SetText(text)
	title:SetTextColor(1, 0.82, 0)
	applyFontSize(title, "GameFontNormal", SECTION_TITLE_TEXT_SIZE)
	return title
end

local function createSmallCheck(parent, opts)
	opts = type(opts) == "table" and opts or {}
	return GF.UI.CreateFilterCheckButton(parent, {
		size = opts.size or SMALL_CHECK_SIZE,
		width = opts.width,
		height = opts.height,
		markSize = 13,
		showMark = opts.showMark,
		atlasStates = opts.atlasStates,
		atlasWidth = opts.atlasWidth,
		atlasHeight = opts.atlasHeight,
		atlasOffsetX = opts.atlasOffsetX,
		atlasOffsetY = opts.atlasOffsetY,
		markOffsetX = opts.markOffsetX,
		markOffsetY = opts.markOffsetY,
		disabledTint = opts.disabledTint,
		disabledAlpha = opts.disabledAlpha,
	})
end

local function createRoleTexture(parent, role)
	local texture = parent:CreateTexture(nil, "ARTWORK")
	texture:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
	local atlas = GF.ROLE_ICON_ATLAS and GF.ROLE_ICON_ATLAS[role]
	if atlas then
		if GF.UI.TrySetAtlas then
			GF.UI.TrySetAtlas(texture, atlas, false)
		elseif texture.SetAtlas then
			pcall(texture.SetAtlas, texture, atlas, false)
		end
	end
	return texture
end

local function createMatchRow(parent, y, labelText, onClick)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(MATCH_ROW_CONTENT_W, 28)
	row:SetPoint("TOP", parent, "TOP", 0, y)

	local check = createSmallCheck(row, {
		width = MATCH_CHECK_W,
		height = MATCH_CHECK_H,
		showMark = true,
		atlasStates = MATCH_CHECK_ATLAS,
		atlasWidth = MATCH_CHECK_W,
		atlasHeight = MATCH_CHECK_H,
		atlasOffsetX = MATCH_CHECK_ATLAS_OFFSET_X,
		atlasOffsetY = MATCH_CHECK_ATLAS_OFFSET_Y,
		markOffsetX = MATCH_CHECK_MARK_OFFSET_X,
		markOffsetY = MATCH_CHECK_MARK_OFFSET_Y,
		disabledTint = CHECK_DISABLED_TINT,
		disabledAlpha = CHECK_DISABLED_ALPHA,
	})
	check:SetPoint("LEFT", row, "LEFT", 0, 0)
	check:SetScript("OnClick", function(self)
		onClick(self:GetChecked() == true)
	end)

	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint(
		"LEFT",
		check,
		"RIGHT",
		MATCH_CHECK_LABEL_GAP,
		0
	)
	label:SetWidth(MATCH_LABEL_W)
	label:SetMaxLines(1)
	label:SetWordWrap(false)
	label:SetText(labelText)
	label:SetTextColor(1, 0.82, 0)
	applyFontSize(label, "GameFontHighlightSmall", ROLE_CARD_TEXT_SIZE)
	fitFontToWidth(
		label,
		MATCH_LABEL_FIT_W,
		MATCH_LABEL_MIN_FONT_SIZE
	)

	row.check = check
	row.label = label
	return row
end

local function updatePresenceChoice(choice)
	if not choice then
		return
	end
	local enabled = not choice.IsEnabled or choice:IsEnabled()
	local checked = choice:GetChecked() == true or choice:GetChecked() == 1
	if choice.indicator then
		choice.indicator:SetEnabled(enabled)
		choice.indicator:SetChecked(checked)
		if GF.UI.SetFilterCheckButtonHovered then
			GF.UI.SetFilterCheckButtonHovered(
				choice.indicator,
				enabled and choice._gfHovered and not checked
			)
		end
	end
	if choice.label then
		if not enabled then
			choice.label:SetTextColor(unpack(FILTER_DISABLED_TEXT_COLOR))
		elseif checked then
			choice.label:SetTextColor(1, 0.82, 0)
		elseif choice._gfHovered then
			choice.label:SetTextColor(1, 0.96, 0.58)
		else
			choice.label:SetTextColor(0.7, 0.68, 0.62)
		end
	end
end

local function syncPresenceChoiceHover(choice)
	if not choice then
		return
	end
	local enabled = not choice.IsEnabled or choice:IsEnabled()
	local hovered = enabled
		and choice.IsMouseMotionFocus
		and choice:IsMouseMotionFocus() == true
	choice._gfHovered = hovered and true or nil
	updatePresenceChoice(choice)
end

local function clearPresenceChoiceHover(choice)
	if not choice then
		return
	end
	choice._gfHovered = nil
	updatePresenceChoice(choice)
end

local function createPresenceChoice(parent, text, width, height)
	local choice = CreateFrame("CheckButton", nil, parent)
	choice:SetSize(width, height)
	local indicator = createSmallCheck(choice, {
		disabledTint = CHECK_DISABLED_TINT,
		disabledAlpha = CHECK_DISABLED_ALPHA,
	})
	indicator:EnableMouse(false)
	local label = GF.UI.CreateFontString(
		choice,
		"OVERLAY",
		"GameFontHighlightSmall"
	)
	local labelGap = 2
	label:SetPoint(
		"CENTER",
		choice,
		"CENTER",
		(SMALL_CHECK_SIZE + labelGap) / 2,
		0
	)
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")
	label:SetMaxLines(1)
	label:SetWordWrap(false)
	label:SetText(text)
	applyFontSize(
		label,
		"GameFontHighlightSmall",
		PRESENCE_CHOICE_TEXT_SIZE
	)
	fitFontToWidth(label, math.max(1, width - 21), 7)
	indicator:SetPoint("RIGHT", label, "LEFT", -labelGap, 0)

	choice.indicator = indicator
	choice.label = label
	choice._gfNativeSetChecked = choice.SetChecked
	choice.SetChecked = function(self, checked, ...)
		self:_gfNativeSetChecked(checked, ...)
		updatePresenceChoice(self)
	end
	choice:HookScript("OnShow", syncPresenceChoiceHover)
	choice:HookScript("OnHide", clearPresenceChoiceHover)
	choice:HookScript("OnEnable", syncPresenceChoiceHover)
	choice:HookScript("OnDisable", clearPresenceChoiceHover)
	choice:HookScript("OnEnter", syncPresenceChoiceHover)
	choice:HookScript("OnLeave", clearPresenceChoiceHover)
	updatePresenceChoice(choice)
	return choice
end

local function createPresenceCard(parent, definition, cardWidth)
	local card = createCardBlock(parent, ROLE_CARD_H)
	cardWidth = tonumber(cardWidth) or ROLE_CARD_WIDTHS[2]
	card:SetWidth(cardWidth)
	card._gfLayoutX = nil
	card._gfLayoutWidth = nil

	local icon = createRoleTexture(card, definition.key)
	icon:SetSize(ROLE_CARD_HEADER_ICON_SIZE, ROLE_CARD_HEADER_ICON_SIZE)
	icon:SetPoint("TOP", card, "TOP", 0, -5)

	local optionGap = 2
	local optionInset = 4
	local optionWidth = cardWidth - optionInset * 2
	local optionHeight = 22
	local existingCheck = createPresenceChoice(
		card,
		localized("MPLUS_BROWSE_FILTER_EXISTING", "已有"),
		optionWidth,
		optionHeight
	)
	existingCheck:SetPoint("BOTTOM", card, "BOTTOM", 0, 5)
	local missingCheck = createPresenceChoice(
		card,
		localized("MPLUS_BROWSE_FILTER_MISSING", "需求"),
		optionWidth,
		optionHeight
	)
	missingCheck:SetPoint(
		"BOTTOM",
		existingCheck,
		"TOP",
		0,
		optionGap
	)

	card.icon = icon
	card.missingCheck = missingCheck
	card.missingLabel = missingCheck.label
	card.existingCheck = existingCheck
	card.existingLabel = existingCheck.label
	card.stateKey = definition.stateKey
	return card
end

local function createNumberColumn(
	parent,
	x,
	width,
	inputWidth,
	labelText,
	maximum,
	centerOffsetX,
	onCommit
)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
	row:SetSize(width, THRESHOLD_BLOCK_H)
	centerOffsetX = tonumber(centerOffsetX) or 0

	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOP", row, "TOP", centerOffsetX, -7)
	label:SetWidth(math.max(1, width - 4))
	label:SetHeight(18)
	label:SetJustifyH("CENTER")
	label:SetText(labelText)
	label:SetTextColor(1, 0.82, 0)
	applyFontSize(label, "GameFontHighlightSmall", ROLE_CARD_TEXT_SIZE)
	fitFontToWidth(label, math.max(1, width - 4), 8)

	local input = GF.UI.CreateInputBox(
		row,
		inputWidth,
		GF.FILTER_NUMBER_INPUT_H or 20
	)
	if GF.UI.StyleFilterNumberBox then
		GF.UI.StyleFilterNumberBox(input, {
			width = inputWidth,
			height = GF.FILTER_NUMBER_INPUT_H or 20,
			disabledTint = CHECK_DISABLED_TINT,
			disabledAlpha = 1,
			disabledTextColor = FILTER_DISABLED_TEXT_COLOR,
		})
	end
	input:SetPoint(
		"BOTTOM",
		row,
		"BOTTOM",
		centerOffsetX,
		THRESHOLD_CONTROL_BOTTOM
	)
	input:SetNumeric(true)
	input:SetMaxLetters(maximum and #tostring(maximum) or 4)
	input:SetJustifyH("CENTER")
	input:SetScript("OnEnterPressed", function(self)
		onCommit(normalizeNumber(self:GetText(), maximum))
		self:ClearFocus()
	end)
	input:SetScript("OnEditFocusLost", function(self)
		if self._gfSuppressCommit then
			return
		end
		onCommit(normalizeNumber(self:GetText(), maximum))
	end)
	input:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	row.label = label
	row.input = input
	return row
end

local function createOpenSlotsColumn(parent, x, width, inputWidth, onCommit)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
	row:SetSize(width, THRESHOLD_BLOCK_H)
	local columnCenterOffsetX =
		GF.MPLUS_BROWSE_THRESHOLD_OPEN_COLUMN_CENTER_OFFSET_X
			or 2

	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOP", row, "TOP", columnCenterOffsetX, -7)
	label:SetWidth(math.max(1, width - 4))
	label:SetHeight(18)
	label:SetJustifyH("CENTER")
	label:SetText(localized("MPLUS_BROWSE_FILTER_MIN_OPEN_SLOTS", "至少空位"))
	label:SetTextColor(1, 0.82, 0)
	applyFontSize(label, "GameFontHighlightSmall", ROLE_CARD_TEXT_SIZE)
	fitFontToWidth(label, math.max(1, width - 4), 8)

	local buttonWidth = GF.FILTER_STEP_BUTTON_SIZE or 20
	local controlGap = GF.FILTER_STEP_BUTTON_GAP or 2
	local controlWidth = buttonWidth * 2
		+ controlGap * 2
		+ inputWidth
	local controlOffsetX = math.floor((width - controlWidth) / 2)
		+ columnCenterOffsetX
	local stepButtonOffsetY =
		GF.MPLUS_BROWSE_THRESHOLD_STEP_BUTTON_OFFSET_Y or -0.5
	local decrement = GF.UI.CreateFilterStepButton(row, "left", {
		size = buttonWidth,
		arrowWidth = GF.MPLUS_BROWSE_THRESHOLD_ARROW_W or 8,
		arrowHeight = GF.MPLUS_BROWSE_THRESHOLD_ARROW_H or 13,
	})
	decrement:SetPoint(
		"BOTTOMLEFT",
		row,
		"BOTTOMLEFT",
		controlOffsetX,
		THRESHOLD_CONTROL_BOTTOM + stepButtonOffsetY
	)

	local input = GF.UI.CreateInputBox(
		row,
		inputWidth,
		GF.FILTER_NUMBER_INPUT_H or 20
	)
	if GF.UI.StyleFilterNumberBox then
		GF.UI.StyleFilterNumberBox(input, {
			width = inputWidth,
			height = GF.FILTER_NUMBER_INPUT_H or 20,
			disabledTint = CHECK_DISABLED_TINT,
			disabledAlpha = 1,
			disabledTextColor = FILTER_DISABLED_TEXT_COLOR,
		})
	end
	input:SetPoint(
		"BOTTOMLEFT",
		row,
		"BOTTOMLEFT",
		controlOffsetX + buttonWidth + controlGap,
		THRESHOLD_CONTROL_BOTTOM
	)
	input:SetNumeric(true)
	input:SetMaxLetters(1)
	input:SetJustifyH("CENTER")

	local increment = GF.UI.CreateFilterStepButton(row, "right", {
		size = buttonWidth,
		arrowWidth = GF.MPLUS_BROWSE_THRESHOLD_ARROW_W or 8,
		arrowHeight = GF.MPLUS_BROWSE_THRESHOLD_ARROW_H or 13,
	})
	increment:SetPoint(
		"LEFT",
		input,
		"RIGHT",
		controlGap,
		stepButtonOffsetY
	)

	local function commit(value)
		value = normalizeOpenSlots(value)
		input:SetText(tostring(value))
		decrement:SetEnabled(value > 1)
		increment:SetEnabled(value < 4)
		onCommit(value)
	end
	decrement:SetScript("OnClick", function()
		commit(normalizeOpenSlots(input:GetText()) - 1)
	end)
	increment:SetScript("OnClick", function()
		commit(normalizeOpenSlots(input:GetText()) + 1)
	end)
	input:SetScript("OnEnterPressed", function(self)
		commit(self:GetText())
		self:ClearFocus()
	end)
	input:SetScript("OnEditFocusLost", function(self)
		if self._gfSuppressCommit then
			return
		end
		commit(self:GetText())
	end)
	input:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	row.label = label
	row.input = input
	row.decrement = decrement
	row.increment = increment
	return row
end

local function getLocalMemberProjection()
	local _, classFile = UnitClass("player")
	local specID
	local specName
	local specIcon
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
		and C_SpecializationInfo.GetSpecializationInfo then
		local okIndex, specIndex = pcall(C_SpecializationInfo.GetSpecialization)
		if okIndex and specIndex then
			local okInfo, currentSpecID, currentSpecName, _, currentSpecIcon = pcall(
				C_SpecializationInfo.GetSpecializationInfo,
				specIndex,
				false,
				false,
				nil,
				UnitSex and UnitSex("player") or nil
			)
			if okInfo then
				specID = currentSpecID
				specName = currentSpecName
				specIcon = currentSpecIcon
			end
		end
	end
	if not specID and GetSpecialization and GetSpecializationInfo then
		local okIndex, specIndex = pcall(GetSpecialization)
		if okIndex and specIndex then
			local okInfo, currentSpecID, currentSpecName, _, currentSpecIcon =
				pcall(GetSpecializationInfo, specIndex)
			if okInfo then
				specID = currentSpecID
				specName = currentSpecName
				specIcon = currentSpecIcon
			end
		end
	end
	local assignedRole = UnitGroupRolesAssigned
		and UnitGroupRolesAssigned("player") or "NONE"
	local role = normalizeRoleToken(assignedRole)
		or getCurrentSpecializationRole()
		or "NONE"
	return {
		unit = "player",
		classFile = classFile,
		specID = specID,
		specName = specName,
		specIcon = specIcon,
		role = role,
		primaryRole = role,
		isCurrent = true,
	}
end

local function normalizeMemberArray(projection)
	if type(projection) ~= "table" then
		return {}
	end
	if type(projection.members) == "table" then
		projection = projection.members
	end
	local members = {}
	for _, member in ipairs(projection) do
		if type(member) == "table" then
			members[#members + 1] = member
		end
	end
	if #members == 0 then
		local dictionaryMembers = {}
		for key, member in pairs(projection) do
			if type(member) == "table" then
				dictionaryMembers[#dictionaryMembers + 1] = {
					member = member,
					sourceKey = type(key) .. ":" .. tostring(key),
				}
			end
		end
		table.sort(dictionaryMembers, function(left, right)
			local leftMember = left.member
			local rightMember = right.member
			local leftIndex = tonumber(leftMember.rosterIndex) or math.huge
			local rightIndex = tonumber(rightMember.rosterIndex) or math.huge
			if leftIndex ~= rightIndex then
				return leftIndex < rightIndex
			end
			local leftName = tostring(
				leftMember.key or leftMember.fullName or leftMember.name or ""
			)
			local rightName = tostring(
				rightMember.key or rightMember.fullName or rightMember.name or ""
			)
			if leftName ~= rightName then
				return leftName < rightName
			end
			return left.sourceKey < right.sourceKey
		end)
		for _, entry in ipairs(dictionaryMembers) do
			members[#members + 1] = entry.member
		end
	end
	return members
end

local function normalizeMemberRole(member)
	local role = normalizeRoleToken(member and (
		member.primaryRole
			or member.assignedRole
			or member.role
	))
	if role then
		return role
	end
	if member and type(member.roles) == "table" then
		local bestRole
		local bestPriority = math.huge
		for key, value in pairs(member.roles) do
			local rawRole = type(key) == "number" and value or key
			local enabled = type(key) == "number"
				or value == true
				or value == 1
			local candidate = enabled and normalizeRoleToken(rawRole) or nil
			local priority = candidate
				and ROLE_PROJECTION_PRIORITY[candidate] or math.huge
			if priority < bestPriority then
				bestRole = candidate
				bestPriority = priority
			end
		end
		if bestRole then
			return bestRole
		end
	end
	local isLocal = member and (
		member.isCurrent == true
			or member.unit == "player"
			or (member.unit and UnitIsUnit
				and UnitIsUnit(member.unit, "player"))
	)
	if isLocal then
		return getCurrentSpecializationRole() or "DEFAULT"
	end
	return "DEFAULT"
end

local function sortMembersByRole(members)
	local decorated = {}
	for index, member in ipairs(members or {}) do
		decorated[#decorated + 1] = {
			member = member,
			role = normalizeMemberRole(member),
			sourceIndex = index,
		}
	end
	table.sort(decorated, function(left, right)
		local leftPriority = ROLE_PROJECTION_PRIORITY[left.role] or 4
		local rightPriority = ROLE_PROJECTION_PRIORITY[right.role] or 4
		if leftPriority ~= rightPriority then
			return leftPriority < rightPriority
		end
		return left.sourceIndex < right.sourceIndex
	end)
	local sorted = {}
	local sortedRoles = {}
	for index = 1, math.min(#decorated, MAX_PROJECTION_MEMBERS) do
		local entry = decorated[index]
		sorted[index] = entry.member
		sortedRoles[index] = entry.role
	end
	return sorted, sortedRoles
end

local function resolveMemberSpecializationIcon(member)
	member = type(member) == "table" and member or {}
	local source = member
	local isLocal = member.isCurrent == true
		or member.unit == "player"
		or (member.unit and UnitIsUnit
			and UnitIsUnit(member.unit, "player"))
	if isLocal and not (member.specID or member.specName) then
		local current = getLocalMemberProjection()
		source = {
			specID = current.specID,
			specName = current.specName,
			specIcon = current.specIcon,
			classFile = member.classFile
				or member.classFilename
				or member.class
				or current.classFile,
			primaryRole = member.primaryRole
				or member.role
				or current.primaryRole,
			role = member.role or current.role,
		}
	end
	if GF.UI.ResolveSpecializationIcon then
		local icon, _, resolvedClassFile = GF.UI.ResolveSpecializationIcon({
			specID = source.specID,
			specName = source.specName,
			classFile = source.classFile
				or source.classFilename
				or source.class,
			fallbackIcon = (source.specID or source.specName)
				and source.specIcon or nil,
			role = source.primaryRole or source.role,
		})
		if icon then
			return icon, resolvedClassFile
		end
	end
	local classFile = source.classFile
		or source.classFilename
		or source.class
	if GF.UI.ResolveClassIcon then
		local icon = GF.UI.ResolveClassIcon(classFile)
		if icon then
			return icon, classFile
		end
	end
	return nil, classFile
end

function Panel:GetController()
	return GF.MythicPlusBrowseFilter
end

function Panel:BindController()
	local controller = self:GetController()
	local controllerRelaysRoster = controller
		and type(controller.AddListener) == "function"
	if not controllerRelaysRoster and not self._rosterListenerBound then
		local roster = GF.MythicPlusRosterCache
		if roster and type(roster.AddListener) == "function" then
			local ok = pcall(roster.AddListener, roster, function()
				Panel:Refresh()
			end)
			self._rosterListenerBound = ok == true
		end
	end
	if not controller or self._boundController == controller then
		return
	end
	self._boundController = controller
	if type(controller.AddListener) == "function" then
		local ok, token = pcall(controller.AddListener, controller, function()
			Panel:Refresh()
		end)
		if ok then
			self._controllerListenerToken = token
		end
	end
end

function Panel:GetApplicantMembers()
	local controller = self:GetController()
	if controller then
		for _, methodName in ipairs({ "GetApplicantMembers", "GetPartyProjection" }) do
			local method = controller[methodName]
			if type(method) == "function" then
				local ok, projection = pcall(method, controller)
				if ok then
					local members = normalizeMemberArray(projection)
					if #members > 0 then
						return members
					end
				end
			end
		end
	end
	local roster = GF.MythicPlusRosterCache
	if roster and type(roster.GetMembers) == "function" then
		local ok, projection = pcall(roster.GetMembers, roster)
		if ok then
			local members = normalizeMemberArray(projection)
			if #members > 0 then
				return members
			end
		end
	end
	return { getLocalMemberProjection() }
end

function Panel:GetState()
	local controller = self:GetController()
	if controller and type(controller.GetState) == "function" then
		local ok, state = pcall(controller.GetState, controller)
		if ok and type(state) == "table" then
			return state
		end
	end
	if controller and type(controller.state) == "table" then
		return controller.state
	end
	self._fallbackState = self._fallbackState or {
		matchPartyRoles = false,
		matchPartySpecs = false,
		minOpenSlots = 1,
		leaderScoreMin = 0,
	}
	return self._fallbackState
end

function Panel:NotifyControllerChanged()
	local controller = self:GetController()
	if controller and type(controller.NotifyChanged) == "function" then
		pcall(controller.NotifyChanged, controller)
	end
end

function Panel:SetStateValue(methodName, field, value, ...)
	local controller = self:GetController()
	local method = controller and controller[methodName]
	if type(method) == "function" then
		local ok = pcall(method, controller, ...)
		if ok then
			self:Refresh()
			return true
		end
	end
	if controller and type(controller.SetValue) == "function" then
		local ok = pcall(controller.SetValue, controller, field, value)
		if ok then
			self:Refresh()
			return true
		end
	end
	local state
	if controller and type(controller.state) == "table" then
		state = controller.state
	else
		state = self:GetState()
	end
	state[field] = value
	self:NotifyControllerChanged()
	self:Refresh(state)
	return false
end

function Panel:GetDungeonOptions()
	local controller = self:GetController()
	if controller and type(controller.GetDungeonOptions) == "function" then
		local ok, options = pcall(controller.GetDungeonOptions, controller)
		if ok and type(options) == "table" then
			return options
		end
	end
	local scope = GF.MythicPlusLFGScope
	if scope and type(scope.GetDungeons) == "function" then
		local ok, options = pcall(scope.GetDungeons, scope)
		if ok and type(options) == "table" then
			return options
		end
	end
	return {}
end

function Panel:HasDungeonOptions()
	local controller = self:GetController()
	if controller and type(controller.HasDungeonOptions) == "function" then
		local ok, hasOptions = pcall(
			controller.HasDungeonOptions,
			controller
		)
		if ok then
			return hasOptions == true
		end
	end
	return #self:GetDungeonOptions() > 0
end

function Panel:IsDungeonSelected(key, state)
	local controller = self:GetController()
	if controller and type(controller.IsDungeonSelected) == "function" then
		local ok, selected = pcall(controller.IsDungeonSelected, controller, key)
		if ok then
			return selected == true
		end
	end
	state = state or self:GetState()
	if state.selectedDungeonKeys == nil then
		return true
	end
	return tableContainsKey(state.selectedDungeonKeys, key)
end

function Panel:SetDungeonSelected(key, selected)
	local controller = self:GetController()
	if controller and type(controller.SetDungeonSelected) == "function" then
		local ok = pcall(controller.SetDungeonSelected, controller, key, selected == true)
		if ok then
			self:Refresh()
			return
		end
	end
	local state = self:GetState()
	local selectedKeys = {}
	for _, option in ipairs(self:GetDungeonOptions()) do
		local candidateKey = optionKey(option, _)
		if self:IsDungeonSelected(candidateKey, state) then
			selectedKeys[candidateKey] = true
		end
	end
	selectedKeys[tostring(key)] = selected and true or nil
	state.selectedDungeonKeys = selectedKeys
	self:NotifyControllerChanged()
	self:Refresh(state)
end

function Panel:SetAllDungeonsSelected(selected)
	local controller = self:GetController()
	local methodName = selected and "SelectAllDungeons" or "ClearDungeons"
	if controller and type(controller[methodName]) == "function" then
		local ok = pcall(controller[methodName], controller)
		if ok then
			self:Refresh()
			return
		end
	end
	local state = self:GetState()
	if selected then
		state.selectedDungeonKeys = nil
	else
		state.selectedDungeonKeys = {}
	end
	self:NotifyControllerChanged()
	self:Refresh(state)
end

function Panel:SetMatchPartyRoles(enabled)
	self:SetStateValue(
		"SetMatchPartyRoles",
		"matchPartyRoles",
		enabled == true,
		enabled == true
	)
end

function Panel:SetMatchPartySpecs(enabled)
	self:SetStateValue(
		"SetMatchPartySpecs",
		"matchPartySpecs",
		enabled == true,
		enabled == true
	)
end

function Panel:SetRolePresence(role, mode)
	mode = normalizePresence(mode)
	local field = role == "TANK" and "tankPresence"
		or role == "HEALER" and "healerPresence"
		or "damagerPresence"
	self:SetStateValue(
		"SetRolePresence",
		field,
		mode,
		role,
		mode
	)
end

function Panel:SetMinimumOpenSlots(value)
	value = normalizeOpenSlots(value)
	self:SetStateValue(
		"SetMinimumOpenSlots",
		"minOpenSlots",
		value,
		value
	)
end

function Panel:SetLeaderScoreMin(value)
	value = normalizeNumber(value, 9999)
	self:SetStateValue(
		"SetLeaderScoreMin",
		"leaderScoreMin",
		value,
		value
	)
end

function Panel:Reset()
	local controller = self:GetController()
	if controller and type(controller.Reset) == "function" then
		local ok = pcall(controller.Reset, controller)
		if ok then
			self:Refresh()
			return
		end
	end
	self._fallbackState = {
		matchPartyRoles = false,
		matchPartySpecs = false,
		minOpenSlots = 1,
		leaderScoreMin = 0,
		selectedDungeonKeys = nil,
	}
	self:NotifyControllerChanged()
	self:Refresh(self._fallbackState)
end

function Panel:SetSearchCallbacks(onSearch, onReset)
	self._onSearch = type(onSearch) == "function" and onSearch or nil
	self._onReset = type(onReset) == "function" and onReset or nil
	if self.fallbackSearchButton then
		self.fallbackSearchButton:SetEnabled(
			self._onSearch ~= nil
				and self._filterInteractionEnabled ~= false
		)
	end
end

function Panel:RequestSearch()
	if self._filterInteractionEnabled == false then
		return false
	end
	if self._onSearch then
		self._onSearch()
		return true
	end
	return false
end

function Panel:RequestReset()
	if self._onReset then
		self._onReset()
	else
		self:Reset()
	end
	return true
end

function Panel:SetExternalSearchControlsAttached(attached)
	self._externalSearchControlsAttached = attached == true
	if self.searchPlaceholder then
		self.searchPlaceholder:SetShown(not self._externalSearchControlsAttached)
	end
	if self.fallbackSearchButton then
		self.fallbackSearchButton:SetShown(not self._externalSearchControlsAttached)
	end
	if self.fallbackResetButton then
		self.fallbackResetButton:SetShown(not self._externalSearchControlsAttached)
	end
end

function Panel:GetSearchBoxHost()
	return self.searchBoxHost
end

function Panel:GetSearchButtonHost()
	return self.searchButtonHost
end

function Panel:GetResetButtonHost()
	return self.resetButtonHost
end

function Panel:GetSearchControlHosts()
	return self.searchBoxHost, self.searchButtonHost, self.resetButtonHost
end

function Panel:SetSearchButtonState(enabled, searching, label)
	if not self.fallbackSearchButton then
		return
	end
	self._fallbackSearchRequestedEnabled = enabled == true
	self._fallbackSearchRequestedSearching = searching == true
	self._fallbackSearchRequestedLabel = label
	self.fallbackSearchButton:SetText(label or ((GF.L and GF.L.SEARCH) or "搜索"))
	self.fallbackSearchButton:SetEnabled(
		enabled == true
			and searching ~= true
			and self._onSearch ~= nil
			and self._filterInteractionEnabled ~= false
	)
	if GF.UI.SetButtonPendingSpinner then
		GF.UI.SetButtonPendingSpinner(
			self.fallbackSearchButton,
			searching == true
				and self._filterInteractionEnabled ~= false,
			GF.SEARCH_BUTTON_PENDING_SPINNER_SIZE or 18
		)
	end
end

function Panel:GetDungeonDropdownText(state)
	local options = self:GetDungeonOptions()
	local selectedCount = 0
	local selectedLabel
	for index, option in ipairs(options) do
		local key = optionKey(option, index)
		if self:IsDungeonSelected(key, state) then
			selectedCount = selectedCount + 1
			selectedLabel = optionLabel(option, index)
		end
	end
	local label
	if #options == 0 then
		label = localized("MPLUS_BROWSE_FILTER_NO_DUNGEONS", "暂无赛季地下城")
	elseif selectedCount == #options then
		label = localized("MPLUS_BROWSE_FILTER_ALL_DUNGEONS", "全部赛季地下城")
	elseif selectedCount == 0 then
		label = localized(
			"MPLUS_BROWSE_FILTER_NONE_DUNGEONS",
			"未选择赛季地下城"
		)
	elseif selectedCount == 1 then
		label = selectedLabel
	else
		label = localized(
			"MPLUS_BROWSE_FILTER_SELECTED_FMT",
			"已选择 %d 个地下城",
			selectedCount
		)
	end
	return label
end

function Panel:GetDungeonFooterText(state)
	local options = self:GetDungeonOptions()
	local selectedLabels = {}
	for index, option in ipairs(options) do
		local key = optionKey(option, index)
		if self:IsDungeonSelected(key, state) then
			selectedLabels[#selectedLabels + 1] = optionLabel(option, index)
		end
	end
	if #selectedLabels == 0 or #selectedLabels == #options then
		return localized("NAV_SEASON_DUNGEON", "赛季地下城")
	end
	return table.concat(
		selectedLabels,
		localized("MPLUS_BROWSE_FILTER_NAME_SEPARATOR", "、")
	)
end

function Panel:UpdateDungeonFooter(state)
	local subtitle = GF.SubtitleBar
	if not subtitle or not subtitle.IsMythicPlusSidebarMode
		or not subtitle:IsMythicPlusSidebarMode()
		or not subtitle.SetCategoryLabel
	then
		return
	end
	subtitle:SetCategoryLabel(self:GetDungeonFooterText(state))
end

function Panel:UpdateDungeonDropdown(state, hasDungeonOptions)
	hasDungeonOptions = hasDungeonOptions == true
	if self.dungeonBlockTitle then
		self.dungeonBlockTitle:SetTextColor(unpack(
			hasDungeonOptions and FILTER_ENABLED_TEXT_COLOR
				or DUNGEON_DISABLED_TITLE_COLOR
		))
	end
	if self.dungeonDropdown and self.dungeonDropdown.SetEnabled then
		self.dungeonDropdown:SetEnabled(hasDungeonOptions)
	end
	setDropdownText(
		self.dungeonDropdown,
		self:GetDungeonDropdownText(state)
	)
	if self.dungeonDropdown and self.dungeonDropdown.GenerateMenu then
		self.dungeonDropdown:GenerateMenu()
	end
	if GF.UI.ApplyDropdownDisabledVisual then
		GF.UI.ApplyDropdownDisabledVisual(
			self.dungeonDropdown,
			not hasDungeonOptions,
			GF.CREATE_MANAGER_DISABLED_VISUAL,
			"_gfMythicPlusBrowseScopeDisabledVisual"
		)
	end
end

function Panel:EnsureMatchProjectionIcon(row, pool, index, iconSize)
	local icon = pool[index]
	if icon then
		return icon
	end
	icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(iconSize, iconSize)
	pool[index] = icon
	return icon
end

function Panel:LayoutMatchProjectionIcons(row, pool, iconSize)
	local slotOffset = (MATCH_SLOT_SIZE - iconSize) / 2
	for index = 1, MAX_PROJECTION_MEMBERS do
		local icon = self:EnsureMatchProjectionIcon(
			row,
			pool,
			index,
			iconSize
		)
		icon:ClearAllPoints()
		icon:SetSize(iconSize, iconSize)
		local offset = MATCH_ICON_START_GAP
			+ (index - 1) * (MATCH_SLOT_SIZE + MATCH_ICON_GAP)
			+ slotOffset
		icon:SetPoint("LEFT", row.label, "RIGHT", offset, 0)
	end
end

function Panel:SetProjectionAtlas(
	icon,
	atlas,
	interactionEnabled,
	isEmpty,
	iconSize
)
	if not icon then
		return false
	end
	if GF.UI.ClearSpecializationIcon then
		GF.UI.ClearSpecializationIcon(icon)
	end
	icon:SetSize(iconSize, iconSize)
	local applied = atlas and GF.UI.TrySetAtlas
		and GF.UI.TrySetAtlas(icon, atlas, false)
	if not applied and atlas and icon.SetAtlas then
		local ok, result = pcall(icon.SetAtlas, icon, atlas, false)
		applied = ok and result ~= false
	end
	setIconEnabledVisual(icon, interactionEnabled == true)
	if not interactionEnabled and isEmpty and icon.SetVertexColor then
		icon:SetVertexColor(
			MATCH_EMPTY_DISABLED_ICON_TINT,
			MATCH_EMPTY_DISABLED_ICON_TINT,
			MATCH_EMPTY_DISABLED_ICON_TINT,
			1
		)
	end
	icon:SetAlpha(isEmpty and MATCH_EMPTY_ICON_ALPHA or 1)
	icon:SetShown(applied == true)
	return applied == true
end

function Panel:UpdatePartyProjection(interactionEnabled)
	if not (self.matchRoleRow and self.matchSpecRow) then
		return
	end
	interactionEnabled = interactionEnabled == true
	local members, memberRoles = sortMembersByRole(self:GetApplicantMembers())
	self.matchRoleRow.projectionIcons = self.matchRoleRow.projectionIcons or {}
	self.matchSpecRow.projectionIcons = self.matchSpecRow.projectionIcons or {}
	local emptyAtlas = GF.ROLE_ICON_ATLAS and GF.ROLE_ICON_ATLAS.DEFAULT
	for index = 1, MAX_PROJECTION_MEMBERS do
		local member = members[index]
		local roleIcon = self:EnsureMatchProjectionIcon(
			self.matchRoleRow,
			self.matchRoleRow.projectionIcons,
			index,
			MATCH_ROLE_ICON_SIZE
		)
		local role = member and memberRoles[index] or nil
		local roleAtlas = role and GF.ROLE_ICON_ATLAS
			and GF.ROLE_ICON_ATLAS[role] or emptyAtlas
		self:SetProjectionAtlas(
			roleIcon,
			roleAtlas or emptyAtlas,
			interactionEnabled,
			member == nil or role == "DEFAULT" or role == "NONE",
			MATCH_ROLE_ICON_SIZE
		)

		local specIcon = self:EnsureMatchProjectionIcon(
			self.matchSpecRow,
			self.matchSpecRow.projectionIcons,
			index,
			MATCH_SPEC_ICON_SIZE
		)
		local resolvedIcon
		local resolvedClassFile
		if member then
			resolvedIcon, resolvedClassFile =
				resolveMemberSpecializationIcon(member)
		end
		local applied = resolvedIcon and GF.UI.SetSpecializationIcon
			and GF.UI.SetSpecializationIcon(specIcon, resolvedIcon, {
				size = MATCH_SPEC_ICON_SIZE,
				iconInset = MATCH_SPEC_ICON_INSET,
				outerSize = MATCH_SPEC_ICON_SIZE,
				classFile = resolvedClassFile,
				disabled = not interactionEnabled,
				preserveDisabledAlpha = not interactionEnabled,
			})
		if applied then
			specIcon:SetAlpha(1)
			specIcon:Show()
		else
			self:SetProjectionAtlas(
				specIcon,
				emptyAtlas,
				interactionEnabled,
				true,
				MATCH_SPEC_ICON_SIZE
			)
		end
	end
	self:LayoutMatchProjectionIcons(
		self.matchRoleRow,
		self.matchRoleRow.projectionIcons,
		MATCH_ROLE_ICON_SIZE
	)
	self:LayoutMatchProjectionIcons(
		self.matchSpecRow,
		self.matchSpecRow.projectionIcons,
		MATCH_SPEC_ICON_SIZE
	)
end

function Panel:IsFilterInteractionEnabled(state)
	local controller = self:GetController()
	if controller and type(controller.IsSearchEnabled) == "function" then
		local ok, enabled = pcall(controller.IsSearchEnabled, controller)
		if ok then
			return enabled == true
		end
	end
	for index, option in ipairs(self:GetDungeonOptions()) do
		if self:IsDungeonSelected(optionKey(option, index), state) then
			return true
		end
	end
	return false
end

function Panel:ApplyFilterInteractionState(enabled, state)
	enabled = enabled == true
	self._filterInteractionEnabled = enabled
	if not enabled and GameTooltip then
		GameTooltip:Hide()
	end

	for _, row in ipairs({ self.matchRoleRow, self.matchSpecRow }) do
		if row then
			row.check:SetEnabled(enabled)
			setEnabledTextColor(row.label, enabled)
		end
	end
	if self.matchBlock then
		self.matchBlock:SetAlpha(1)
		setCardChromeEnabledVisual(self.matchBlock, enabled)
	end

	setEnabledTextColor(self.presenceBlockTitle, enabled)
	for _, definition in ipairs(ROLE_DEFS) do
		local row = self.presenceRows and self.presenceRows[definition.key]
		if row then
			row:SetAlpha(1)
			setCardChromeEnabledVisual(row, enabled)
			setIconEnabledVisual(row.icon, enabled)
			row.missingCheck:SetEnabled(enabled)
			row.existingCheck:SetEnabled(enabled)
			updatePresenceChoice(row.missingCheck)
			updatePresenceChoice(row.existingCheck)
		end
	end

	if self.thresholdBlock then
		self.thresholdBlock:SetAlpha(1)
		setCardChromeEnabledVisual(self.thresholdBlock, enabled)
	end
	if self.openSlotsRow then
		local openSlots = normalizeOpenSlots(
			state and state.minOpenSlots
				or self.openSlotsRow.input:GetText()
		)
		setEnabledTextColor(self.openSlotsRow.label, enabled)
		if not enabled then
			self.openSlotsRow.input:SetText(tostring(openSlots))
		end
		setInputEnabled(self.openSlotsRow.input, enabled)
		if GF.UI.SetFilterStepButtonPreserveDisabledAlpha then
			GF.UI.SetFilterStepButtonPreserveDisabledAlpha(
				self.openSlotsRow.decrement,
				not enabled
			)
			GF.UI.SetFilterStepButtonPreserveDisabledAlpha(
				self.openSlotsRow.increment,
				not enabled
			)
		end
		self.openSlotsRow.decrement:SetEnabled(
			enabled and openSlots > 1
		)
		self.openSlotsRow.increment:SetEnabled(
			enabled and openSlots < 4
		)
	end
	if self.scoreRow then
		local score = normalizeNumber(
			state and state.leaderScoreMin
				or self.scoreRow.input:GetText(),
			9999
		)
		setEnabledTextColor(self.scoreRow.label, enabled)
		if not enabled then
			self.scoreRow.input:SetText(tostring(score))
		end
		setInputEnabled(self.scoreRow.input, enabled)
		self.scoreRow:EnableMouse(enabled)
	end
	if self.thresholdDividerTop then
		self.thresholdDividerTop:SetAlpha(1)
	end
	if self.thresholdDividerBottom then
		self.thresholdDividerBottom:SetAlpha(1)
	end
	if self._applyThresholdDividerVisual then
		self._applyThresholdDividerVisual(enabled)
	end

	if self.searchBlock then
		self.searchBlock:SetAlpha(1)
	end
	if self.searchButtonHost then
		self.searchButtonHost:SetAlpha(1)
	end
	if self.searchPlaceholder then
		local placeholderColor = enabled
			and (GF.SUBTITLE_SEARCH_PLACEHOLDER_COLOR
				or { 0.55, 0.55, 0.55, 1 })
			or FILTER_DISABLED_TEXT_COLOR
		self.searchPlaceholder:SetTextColor(unpack(placeholderColor))
	end
	if self.fallbackSearchButton then
		if GF.UI.SetCommonPanelButtonPreserveDisabledAlpha then
			GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
				self.fallbackSearchButton,
				not enabled
			)
		end
		if self._fallbackSearchRequestedEnabled ~= nil then
			self:SetSearchButtonState(
				self._fallbackSearchRequestedEnabled,
				self._fallbackSearchRequestedSearching,
				self._fallbackSearchRequestedLabel
			)
		else
			self.fallbackSearchButton:SetEnabled(
				enabled and self._onSearch ~= nil
			)
		end
	end
	if GF.SubtitleBar
		and GF.SubtitleBar.SetMythicPlusFilterInteractionEnabled
	then
		GF.SubtitleBar:SetMythicPlusFilterInteractionEnabled(enabled)
	end
end

function Panel:Refresh(state)
	if not self.frame then
		return
	end
	self:BindController()
	state = type(state) == "table" and state or self:GetState()

	local roleMatchEnabled = normalizeBool(state.matchPartyRoles)
	local specMatchEnabled = normalizeBool(state.matchPartySpecs)
	if self.matchRoleRow then
		self.matchRoleRow.check:SetChecked(roleMatchEnabled)
	end
	if self.matchSpecRow then
		self.matchSpecRow.check:SetChecked(specMatchEnabled)
	end

	for _, definition in ipairs(ROLE_DEFS) do
		local row = self.presenceRows and self.presenceRows[definition.key]
		if row then
			local mode = normalizePresence(state[definition.stateKey])
			row.missingCheck:SetChecked(mode == "missing")
			row.existingCheck:SetChecked(mode == "existing")
		end
	end

	if self.openSlotsRow and not self.openSlotsRow.input:HasFocus() then
		local openSlots = normalizeOpenSlots(state.minOpenSlots)
		self.openSlotsRow.input:SetText(tostring(openSlots))
		self.openSlotsRow.decrement:SetEnabled(openSlots > 1)
		self.openSlotsRow.increment:SetEnabled(openSlots < 4)
	end
	if self.scoreRow and not self.scoreRow.input:HasFocus() then
		self.scoreRow.input:SetText(tostring(normalizeNumber(state.leaderScoreMin, 9999)))
	end
	local hasDungeonOptions = self:HasDungeonOptions()
	self:UpdateDungeonDropdown(state, hasDungeonOptions)
	self:UpdateDungeonFooter(state)
	local interactionEnabled = self:IsFilterInteractionEnabled(state)
	self:ApplyFilterInteractionState(interactionEnabled, state)
	self:UpdatePartyProjection(interactionEnabled)
end

function Panel:SetupDungeonMenu()
	if not self.dungeonDropdown or not self.dungeonDropdown.SetupMenu then
		return
	end
	if self.dungeonDropdown.SetSelectionText then
		self.dungeonDropdown:SetSelectionText(function()
			return Panel:GetDungeonDropdownText()
		end)
	end
	self.dungeonDropdown:SetupMenu(function(_, root)
		if root.SetTag then
			root:SetTag("MENU_GF_MYTHIC_PLUS_BROWSE_DUNGEONS")
		end
		if root.CreateTitle then
			root:CreateTitle(localized(
				"MPLUS_BROWSE_FILTER_DUNGEONS",
				"选择赛季地下城"
			))
		end
		local options = Panel:GetDungeonOptions()
		if #options == 0 then
			if root.CreateTitle then
				root:CreateTitle(localized(
					"MPLUS_BROWSE_FILTER_NO_DUNGEONS",
					"暂无赛季地下城"
				))
			end
			return
		end
		root:CreateButton(localized("MPLUS_BROWSE_FILTER_SELECT_ALL", "全选"), function()
			Panel:SetAllDungeonsSelected(true)
			if MenuResponse then
				return MenuResponse.Refresh
			end
		end)
		root:CreateButton(localized("MPLUS_BROWSE_FILTER_CLEAR", "清空"), function()
			Panel:SetAllDungeonsSelected(false)
			if MenuResponse then
				return MenuResponse.Refresh
			end
		end)
		for index, option in ipairs(options) do
			local key = optionKey(option, index)
			local label = optionLabel(option, index)
			local dungeonKey = key
			root:CreateCheckbox(label, function()
				return Panel:IsDungeonSelected(dungeonKey)
			end, function()
				Panel:SetDungeonSelected(
					dungeonKey,
					not Panel:IsDungeonSelected(dungeonKey)
				)
				if MenuResponse then
					return MenuResponse.Refresh
				end
			end)
		end
	end)
end

function Panel:CreateHeader(host)
	self.header = CreateFrame("Frame", nil, host)
	self.header:SetPoint("TOPLEFT", host, "TOPLEFT", 0, HEADER_TOP_OFFSET)
	self.header:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, HEADER_TOP_OFFSET)
	self.header:SetHeight(HEADER_H)
	self.header:SetFrameLevel(host:GetFrameLevel() + 4)
	if GF.UI.InstallBrowseHeaderChrome then
		GF.UI.InstallBrowseHeaderChrome(self.header, {
			backgroundInsetLeft = 0,
		})
	end

	self.headerTitle = GF.UI.CreateFontString(self.header, "OVERLAY", "GameFontNormal")
	self.headerTitle:SetPoint(
		"TOPLEFT",
		self.header,
		"TOPLEFT",
		0,
		HEADER_TEXT_OFFSET_Y
	)
	self.headerTitle:SetPoint(
		"BOTTOMRIGHT",
		self.header,
		"BOTTOMRIGHT",
		0,
		HEADER_TEXT_OFFSET_Y
	)
	self.headerTitle:SetJustifyH("CENTER")
	self.headerTitle:SetJustifyV("MIDDLE")
	applyFontSize(self.headerTitle, "GameFontNormal", HEADER_TEXT_SIZE)
	self.headerTitle:SetText(localized(
		"MPLUS_BROWSE_FILTER_TITLE",
		"寻找队伍"
	))
	self.headerTitle:SetTextColor(1, 0.82, 0)
	self.header:Hide()
end

function Panel:CreateDungeonBlock(parent)
	local block = createSectionContainer(parent, DUNGEON_BLOCK_H)
	self.dungeonBlockTitle = createSectionTitle(block, localized(
		"MPLUS_BROWSE_FILTER_DUNGEONS",
		"选择赛季地下城"
	))
	local dropdownHost = createSectionContainer(block, CONTROL_H)
	dropdownHost:SetWidth(NATIVE_CONTROL_W)
	dropdownHost:SetPoint(
		"BOTTOMLEFT",
		block,
		"BOTTOMLEFT",
		NATIVE_CONTROL_OFFSET_X,
		0
	)
	self.dungeonDropdownHost = dropdownHost

	local dropdown = GF.UI.CreateDropdownButton(dropdownHost)
	dropdown:SetAllPoints(dropdownHost)
	self.dungeonDropdown = dropdown
	self:SetupDungeonMenu()
	return block
end

function Panel:CreateMatchBlock(parent)
	local block = createCardBlock(parent, MATCH_BLOCK_H)
	self.matchRoleRow = createMatchRow(block, -7, localized(
		"MPLUS_BROWSE_FILTER_MATCH_ROLES",
		"匹配职责"
	), function(enabled)
		Panel:SetMatchPartyRoles(enabled)
	end)
	self.matchSpecRow = createMatchRow(block, -37, localized(
		"MPLUS_BROWSE_FILTER_MATCH_SPECS",
		"匹配职业"
	), function(enabled)
		Panel:SetMatchPartySpecs(enabled)
	end)
	return block
end

function Panel:CreatePresenceBlock(parent)
	local block = createSectionContainer(parent, PRESENCE_BLOCK_H)
	block:SetWidth(CARD_FRAME_W)
	block._gfLayoutX = CARD_FRAME_LAYOUT_X
	block._gfLayoutWidth = CARD_FRAME_W
	self.presenceBlockTitle = createSectionTitle(block, localized(
		"MPLUS_BROWSE_FILTER_ROLE_TITLE",
		"筛选职责"
	), CARD_FRAME_OUTSET_X)
	self.presenceBlockTitle:ClearAllPoints()
	self.presenceBlockTitle:SetPoint(
		"TOPLEFT",
		block,
		"TOPLEFT",
		2 + CARD_FRAME_OUTSET_X,
		MATCH_PRESENCE_GAP
	)
	self.presenceBlockTitle:SetPoint(
		"TOPRIGHT",
		block,
		"TOPRIGHT",
		-(2 + CARD_FRAME_OUTSET_X),
		MATCH_PRESENCE_GAP
	)
	self.presenceBlockTitle:SetHeight(PRESENCE_TITLE_SLOT_H)
	self.presenceBlockTitle:SetJustifyV("MIDDLE")
	self.presenceRows = {}
	local cardOffsetX = 0
	for index, definition in ipairs(ROLE_DEFS) do
		local role = definition.key
		local cardWidth = ROLE_CARD_WIDTHS[index]
		local row = createPresenceCard(block, definition, cardWidth)
		row:SetPoint(
			"TOPLEFT",
			block,
			"TOPLEFT",
			cardOffsetX,
			-(SECTION_TITLE_H + PRESENCE_TITLE_TO_CARDS_GAP)
		)
		cardOffsetX = cardOffsetX + cardWidth + ROLE_CARD_GAP
		row.missingCheck:SetScript("OnClick", function(self)
			Panel:SetRolePresence(
				role,
				self:GetChecked() == true and "missing" or nil
			)
		end)
		row.existingCheck:SetScript("OnClick", function(self)
			Panel:SetRolePresence(
				role,
				self:GetChecked() == true and "existing" or nil
			)
		end)
		self.presenceRows[role] = row
	end
	return block
end

function Panel:CreateThresholdBlock(parent)
	local block = createCardBlock(parent, THRESHOLD_BLOCK_H)
	local columnGap = GF.MPLUS_BROWSE_THRESHOLD_COLUMN_GAP or 8
	local columnWidth = math.floor((PANEL_CONTENT_W - columnGap) / 2)
	local openInputWidth = GF.MPLUS_BROWSE_THRESHOLD_OPEN_INPUT_W or 24
	local scoreInputWidth = GF.MPLUS_BROWSE_THRESHOLD_SCORE_INPUT_W or 70
	self.openSlotsRow = createOpenSlotsColumn(
		block,
		CARD_FRAME_OUTSET_X,
		columnWidth,
		openInputWidth,
		function(value)
			Panel:SetMinimumOpenSlots(value)
		end
	)
	self.scoreRow = createNumberColumn(
		block,
		CARD_FRAME_OUTSET_X + columnWidth + columnGap,
		PANEL_CONTENT_W - columnWidth - columnGap,
		scoreInputWidth,
		localized("MPLUS_BROWSE_FILTER_LEADER_SCORE", "最低评分"),
		9999,
		GF.MPLUS_BROWSE_THRESHOLD_SCORE_COLUMN_CENTER_OFFSET_X or -2,
		function(value)
			Panel:SetLeaderScoreMin(value)
		end
	)
	local function applyDividerGradient(
		texture,
		startAlpha,
		endAlpha,
		enabled
	)
		local color = enabled == false
			and {
				FILTER_DISABLED_ICON_TINT,
				FILTER_DISABLED_ICON_TINT,
				FILTER_DISABLED_ICON_TINT,
				1,
			}
			or GF.MPLUS_BROWSE_THRESHOLD_DIVIDER_COLOR
			or { 0.42, 0.34, 0.2, 1 }
		local r, g, b = color[1], color[2], color[3]
		texture:SetAlpha(1)
		texture:SetColorTexture(r, g, b, 1)
		if texture.SetGradient and CreateColor then
			local ok = pcall(
				texture.SetGradient,
				texture,
				"VERTICAL",
				CreateColor(r, g, b, startAlpha),
				CreateColor(r, g, b, endAlpha)
			)
			if ok then
				return
			end
		end
		if texture.SetGradientAlpha then
			texture:SetGradientAlpha(
				"VERTICAL",
				r, g, b, startAlpha,
				r, g, b, endAlpha
			)
		else
			texture:SetVertexColor(
				r,
				g,
				b,
				math.max(startAlpha, endAlpha)
			)
		end
	end
	local dividerInset = GF.MPLUS_BROWSE_THRESHOLD_DIVIDER_INSET or 8
	local dividerAlpha = GF.MPLUS_BROWSE_THRESHOLD_DIVIDER_ALPHA or 0.72
	local dividerTop = block:CreateTexture(nil, "ARTWORK")
	dividerTop:SetPoint("TOP", block, "TOP", 0, -dividerInset)
	dividerTop:SetPoint("BOTTOM", block, "CENTER", 0, 0)
	dividerTop:SetWidth(1)
	applyDividerGradient(dividerTop, dividerAlpha, 0)
	local dividerBottom = block:CreateTexture(nil, "ARTWORK")
	dividerBottom:SetPoint("TOP", block, "CENTER", 0, 0)
	dividerBottom:SetPoint("BOTTOM", block, "BOTTOM", 0, dividerInset)
	dividerBottom:SetWidth(1)
	applyDividerGradient(dividerBottom, 0, dividerAlpha)
	self._applyThresholdDividerVisual = function(interactionEnabled)
		applyDividerGradient(
			dividerTop,
			dividerAlpha,
			0,
			interactionEnabled
		)
		applyDividerGradient(
			dividerBottom,
			0,
			dividerAlpha,
			interactionEnabled
		)
	end
	self.thresholdDividerTop = dividerTop
	self.thresholdDividerBottom = dividerBottom
	self.scoreRow.input:HookScript("OnEnter", function(owner)
		showLeaderScoreTooltip(owner)
	end)
	self.scoreRow.input:HookScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return block
end

function Panel:CreateSearchBlock(parent)
	local block = createSectionContainer(parent, SEARCH_BLOCK_H)
	self.searchBoxHost = CreateFrame("Frame", nil, block)
	self.searchBoxHost:SetPoint(
		"TOPLEFT",
		block,
		"TOPLEFT",
		NATIVE_CONTROL_OFFSET_X,
		0
	)
	self.searchBoxHost:SetPoint(
		"BOTTOMRIGHT",
		block,
		"BOTTOMRIGHT",
		-NATIVE_CONTROL_OFFSET_X,
		0
	)

	self.searchPlaceholder = GF.UI.CreateFontString(
		self.searchBoxHost,
		"OVERLAY",
		"GameFontDisableSmall"
	)
	self.searchPlaceholder:SetPoint("LEFT", self.searchBoxHost, "LEFT", 7, 0)
	self.searchPlaceholder:SetPoint("RIGHT", self.searchBoxHost, "RIGHT", -7, 0)
	self.searchPlaceholder:SetJustifyH("LEFT")
	self.searchPlaceholder:SetMaxLines(1)
	self.searchPlaceholder:SetWordWrap(false)
	self.searchPlaceholder:SetText(
		(GF.L and GF.L.MPLUS_BROWSE_FILTER_SEARCH_PLACEHOLDER)
			or "名称、层数或说明"
	)
	fitFontToWidth(
		self.searchPlaceholder,
		math.max(1, NATIVE_CONTROL_W - 14),
		GF.MPLUS_BROWSE_SEARCH_MIN_TEXT_SIZE or 9
	)
	return block
end

function Panel:CreateActionBlock(parent)
	local block = createSectionContainer(parent, ACTION_BLOCK_H)
	local actionGroupW = ACTION_BUTTON_W * 2 + ACTION_BUTTON_GAP
	local actionOffsetX = math.floor((PANEL_CONTENT_W - actionGroupW) / 2)
	self.searchButtonHost = CreateFrame("Frame", nil, block)
	self.searchButtonHost:SetPoint(
		"TOPLEFT",
		block,
		"TOPLEFT",
		actionOffsetX,
		0
	)
	self.searchButtonHost:SetSize(ACTION_BUTTON_W, ACTION_BLOCK_H)
	self.resetButtonHost = CreateFrame("Frame", nil, block)
	self.resetButtonHost:SetPoint(
		"TOPLEFT",
		self.searchButtonHost,
		"TOPRIGHT",
		ACTION_BUTTON_GAP,
		0
	)
	self.resetButtonHost:SetSize(ACTION_BUTTON_W, ACTION_BLOCK_H)

	self.fallbackSearchButton = GF.UI.CreatePanelButton(
		self.searchButtonHost,
		(GF.L and GF.L.SEARCH) or "搜索",
		ACTION_BUTTON_W
	)
	self.fallbackSearchButton:SetAllPoints()
	self.fallbackSearchButton:SetScript("OnClick", function()
		Panel:RequestSearch()
	end)
	self.fallbackSearchButton:SetEnabled(false)

	self.fallbackResetButton = GF.UI.CreatePanelButton(
		self.resetButtonHost,
		(GF.L and (GF.L.RESET or GF.L.FILTER_RESET)) or "重置",
		ACTION_BUTTON_W
	)
	self.fallbackResetButton:SetAllPoints()
	self.fallbackResetButton:SetScript("OnClick", function()
		Panel:RequestReset()
	end)
	return block
end

function Panel:Layout()
	if not (self.frame and self.layoutBlocks) or self._layoutBusy then
		return
	end
	self._layoutBusy = true
	local contentTop = -(HEADER_TOP_OFFSET - HEADER_H - CONTENT_TOP_GAP)
	local topOffset = -contentTop
	local topGaps = {
		DUNGEON_MATCH_GAP,
		MATCH_PRESENCE_GAP,
		PRESENCE_THRESHOLD_GAP,
	}
	for index = 1, 4 do
		local entry = self.layoutBlocks[index]
		local block = entry.frame
		local layoutX = tonumber(block._gfLayoutX) or PANEL_INSET_X
		local layoutWidth = tonumber(block._gfLayoutWidth)
			or PANEL_CONTENT_W
		block:ClearAllPoints()
		block:SetPoint(
			"TOPLEFT",
			self.frame,
			"TOPLEFT",
			layoutX + CONTENT_OFFSET_X,
			topOffset
		)
		block:SetSize(layoutWidth, entry.height)
		topOffset = topOffset - entry.height
		if topGaps[index] then
			topOffset = topOffset - topGaps[index]
		end
	end

	local actionEntry = self.layoutBlocks[6]
	local actionBlock = actionEntry.frame
	local actionX = tonumber(actionBlock._gfLayoutX) or PANEL_INSET_X
	local actionWidth = tonumber(actionBlock._gfLayoutWidth)
		or PANEL_CONTENT_W
	actionBlock:ClearAllPoints()
	actionBlock:SetPoint(
		"BOTTOMLEFT",
		self.frame,
		"BOTTOMLEFT",
		actionX + CONTENT_OFFSET_X,
		PANEL_BOTTOM_INSET
	)
	actionBlock:SetSize(actionWidth, actionEntry.height)

	local searchEntry = self.layoutBlocks[5]
	local searchBlock = searchEntry.frame
	local searchX = tonumber(searchBlock._gfLayoutX) or PANEL_INSET_X
	local searchWidth = tonumber(searchBlock._gfLayoutWidth)
		or PANEL_CONTENT_W
	searchBlock:ClearAllPoints()
	searchBlock:SetPoint(
		"BOTTOMLEFT",
		self.frame,
		"BOTTOMLEFT",
		searchX + CONTENT_OFFSET_X,
		PANEL_BOTTOM_INSET + actionEntry.height + SEARCH_ACTION_GAP
	)
	searchBlock:SetSize(searchWidth, searchEntry.height)

	self._resolvedTopBlockGaps = topGaps
	self._resolvedSearchActionGap = SEARCH_ACTION_GAP
	self._layoutBusy = nil
end

function Panel:Init(host)
	if self.frame or not host then
		return
	end
	self.host = host
	self.frame = CreateFrame("Frame", "GroupFinderAddonMythicPlusBrowseFilterPanel", host)
	self.frame:SetAllPoints(host)
	self.frame:SetFrameLevel(host:GetFrameLevel() + 3)
	self.frame:Hide()
	self:CreateHeader(host)

	self.dungeonBlock = self:CreateDungeonBlock(self.frame)
	self.matchBlock = self:CreateMatchBlock(self.frame)
	self.presenceBlock = self:CreatePresenceBlock(self.frame)
	self.thresholdBlock = self:CreateThresholdBlock(self.frame)
	self.searchBlock = self:CreateSearchBlock(self.frame)
	self.actionBlock = self:CreateActionBlock(self.frame)
	self.layoutBlocks = {
		{ frame = self.dungeonBlock, height = DUNGEON_BLOCK_H },
		{ frame = self.matchBlock, height = MATCH_BLOCK_H },
		{ frame = self.presenceBlock, height = PRESENCE_BLOCK_H },
		{ frame = self.thresholdBlock, height = THRESHOLD_BLOCK_H },
		{ frame = self.searchBlock, height = SEARCH_BLOCK_H },
		{ frame = self.actionBlock, height = ACTION_BLOCK_H },
	}
	self.frame:SetScript("OnSizeChanged", function()
		Panel:Layout()
	end)
	self:Layout()

	self.frame:SetScript("OnShow", function()
		Panel:BindController()
		Panel:Layout()
		Panel:Refresh()
	end)
	self.frame:SetScript("OnHide", function()
		if Panel.openSlotsRow and Panel.openSlotsRow.input then
			Panel.openSlotsRow.input:ClearFocus()
		end
		if Panel.scoreRow and Panel.scoreRow.input then
			Panel.scoreRow.input:ClearFocus()
		end
	end)
	self:BindController()
	self:Refresh()
end

function Panel:SetSelection(selection)
	self.selection = selection
	if self.frame and self.frame:IsShown() then
		self:Refresh()
	end
end

function Panel:RefreshLocale()
	if not self.frame then
		return
	end
	if self.headerTitle then
		self.headerTitle:SetText(localized(
			"MPLUS_BROWSE_FILTER_TITLE",
			"寻找队伍"
		))
	end
	if self.dungeonBlockTitle then
		self.dungeonBlockTitle:SetText(localized(
			"MPLUS_BROWSE_FILTER_DUNGEONS",
			"选择赛季地下城"
		))
	end
	if self.matchRoleRow then
		self.matchRoleRow.label:SetText(localized(
			"MPLUS_BROWSE_FILTER_MATCH_ROLES",
			"匹配职责"
		))
		fitFontToWidth(
			self.matchRoleRow.label,
			MATCH_LABEL_FIT_W,
			MATCH_LABEL_MIN_FONT_SIZE
		)
	end
	if self.matchSpecRow then
		self.matchSpecRow.label:SetText(localized(
			"MPLUS_BROWSE_FILTER_MATCH_SPECS",
			"匹配职业"
		))
		fitFontToWidth(
			self.matchSpecRow.label,
			MATCH_LABEL_FIT_W,
			MATCH_LABEL_MIN_FONT_SIZE
		)
	end
	if self.presenceBlockTitle then
		self.presenceBlockTitle:SetText(localized(
			"MPLUS_BROWSE_FILTER_ROLE_TITLE",
			"筛选职责"
		))
	end
	for _, definition in ipairs(ROLE_DEFS) do
		local row = self.presenceRows and self.presenceRows[definition.key]
		if row then
			row.missingLabel:SetText(localized(
				"MPLUS_BROWSE_FILTER_MISSING",
				"需求"
			))
			fitFontToWidth(
				row.missingLabel,
				math.max(1, row:GetWidth() - 29),
				7
			)
			row.existingLabel:SetText(localized(
				"MPLUS_BROWSE_FILTER_EXISTING",
				"已有"
			))
			fitFontToWidth(
				row.existingLabel,
				math.max(1, row:GetWidth() - 29),
				7
			)
		end
	end
	if self.openSlotsRow then
		self.openSlotsRow.label:SetText(localized(
			"MPLUS_BROWSE_FILTER_MIN_OPEN_SLOTS",
			"至少空位"
		))
		fitFontToWidth(
			self.openSlotsRow.label,
			math.max(1, self.openSlotsRow:GetWidth() - 4),
			8
		)
	end
	if self.scoreRow then
		self.scoreRow.label:SetText(localized(
			"MPLUS_BROWSE_FILTER_LEADER_SCORE",
			"最低评分"
		))
		fitFontToWidth(
			self.scoreRow.label,
			math.max(1, self.scoreRow:GetWidth() - 4),
			8
		)
	end
	if self.searchPlaceholder then
		self.searchPlaceholder:SetText(
			(GF.L and GF.L.MPLUS_BROWSE_FILTER_SEARCH_PLACEHOLDER)
				or "名称、层数或说明"
		)
		fitFontToWidth(
			self.searchPlaceholder,
			math.max(1, NATIVE_CONTROL_W - 14),
			GF.MPLUS_BROWSE_SEARCH_MIN_TEXT_SIZE or 9
		)
	end
	if self.fallbackSearchButton then
		self.fallbackSearchButton:SetText(
			(GF.L and GF.L.SEARCH) or "搜索"
		)
	end
	if self.fallbackResetButton then
		self.fallbackResetButton:SetText(
			(GF.L and (GF.L.RESET or GF.L.FILTER_RESET))
				or "重置"
		)
	end
	self:Refresh()
end

function Panel:SetVisible(visible)
	if not self.frame then
		return
	end
	if visible then
		self.frame:Show()
		if self.header then
			self.header:Show()
		end
	else
		self.frame:Hide()
		if self.header then
			self.header:Hide()
		end
	end
end

function Panel:IsShown()
	return self.frame and self.frame:IsShown() or false
end
