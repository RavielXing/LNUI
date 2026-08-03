local _, GF = ...

GF.DebugSurface = GF.DebugSurface or {}
local DebugSurface = GF.DebugSurface

local SCROLLBAR_WIDTH = GF.SETTINGS_SCROLLBAR_WIDTH or 17
local SCROLLBAR_GAP = GF.SETTINGS_SCROLLBAR_GAP or 2
local SCROLLBAR_RIGHT_INSET = GF.SETTINGS_SCROLLBAR_RIGHT_INSET or 10
local SCROLLBAR_TOP_INSET = GF.SETTINGS_SCROLLBAR_TOP_INSET or 8
local SCROLLBAR_BOTTOM_INSET = GF.SETTINGS_SCROLLBAR_BOTTOM_INSET or 8
local SCROLL_INSET_R = GF.SETTINGS_VISIBLE_CONTENT_INSET_R
	or (SCROLLBAR_WIDTH + SCROLLBAR_GAP + SCROLLBAR_RIGHT_INSET)
local SCROLL_INSET_L = GF.SETTINGS_LAYOUT_INSET_L or 0

-- Keep debug tables on the same visual grid as settings tables.
local CONTENT_TOP_OFFSET = 16
local CONTENT_BOTTOM_PADDING = 20
local SECTION_GAP = 14
local SECTION_TITLE_H = 36
local SECTION_TITLE_GAP = 10
local SECTION_BODY_INSET_X = 24
local SECTION_BODY_INSET_R = 24
local SECTION_TITLE_TEXT_INSET_X = 24
local SECTION_TITLE_TEXT_SIZE = 16
local SECTION_ROW_TEXT_SIZE = 14
local SECTION_ROW_TEXT_H = 28
local SECTION_ROW_H = 40
local SECTION_LABEL_X = 28
local SECTION_LABEL_W = 246
local SECTION_CONTROL_X = 314
local SECTION_CONTROL_INSET_R = 16
local STATUS_GRID_COLUMN_GAP = 24
local STATUS_GRID_LABEL_X = 24
local STATUS_GRID_LABEL_W = 208
local STATUS_GRID_VALUE_GAP = 10
local STATUS_GRID_VALUE_INSET_R = 20
local ACTION_BUTTON_W = 132
local ACTION_BUTTON_GAP = 10
local INPUT_W = 174
local INPUT_H = 28

local View = {}
View.__index = View

local function setTextureColor(texture, r, g, b, a)
	if not texture then
		return
	end
	if texture.SetColorTexture then
		texture:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
	else
		texture:SetTexture(GF.WHITE_TEXTURE)
		texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	end
end

local function styleFontString(fontString, template)
	if fontString and GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template or "GameFontNormal")
	end
end

local function applyFeaturePanelStyle(frame)
	if not frame then
		return
	end
	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end
	if GF.UI and GF.UI.ApplyControlCardChrome then
		GF.UI.ApplyControlCardChrome(frame, {
			state = "normal",
			displayMargin = GF.CONTROL_FRAME_DISPLAY_MARGIN or 8,
		})
	end
end

local function localizedText(localeKey, fallback)
	local L = GF.L or {}
	if localeKey and L[localeKey] ~= nil then
		return L[localeKey]
	end
	return fallback or localeKey or ""
end

function View:BindText(target, localeKey, fallback, setter)
	if not target then
		return
	end
	setter = setter or function(widget, value)
		widget:SetText(value)
	end
	local binding = {
		target = target,
		localeKey = localeKey,
		fallback = fallback,
		setter = setter,
	}
	self.localeBindings[#self.localeBindings + 1] = binding
	setter(target, localizedText(localeKey, fallback))
end

function View:RefreshLocale()
	for _, binding in ipairs(self.localeBindings or {}) do
		binding.setter(
			binding.target,
			localizedText(binding.localeKey, binding.fallback))
	end
end

function View:CreateSection(localeKey, fallback)
	local section = CreateFrame("Frame", nil, self.body)
	section._gfRowOffset = 0
	section:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, self.nextY)
	section:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, self.nextY)

	local title = CreateFrame("Frame", nil, section)
	title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
	title:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
	title:SetHeight(SECTION_TITLE_H)

	local titleBackground = title:CreateTexture(nil, "BACKGROUND")
	titleBackground:SetAllPoints(title)
	if GF.UI and GF.UI.TrySetAtlas
		and GF.UI.TrySetAtlas(
			titleBackground,
			GF.BROWSE_HEADER_BACKGROUND_ATLAS or "housefinder_header-bg-gradient",
			false)
	then
		titleBackground:SetVertexColor(1, 1, 1, 1)
	else
		setTextureColor(titleBackground, 0, 0, 0, 0.45)
	end

	local titleText = GF.UI.CreateFontString(title, "OVERLAY", "GameFontNormal")
	titleText._gfFontSizeOverride = SECTION_TITLE_TEXT_SIZE
	titleText._gfFontFlagsOverride = "OUTLINE"
	styleFontString(titleText, "GameFontNormal")
	titleText:SetTextColor(1, 0.82, 0, 1)
	titleText:SetPoint(
		"TOPLEFT",
		title,
		"TOPLEFT",
		SECTION_TITLE_TEXT_INSET_X,
		0)
	titleText:SetPoint(
		"BOTTOMRIGHT",
		title,
		"BOTTOMRIGHT",
		-SECTION_TITLE_TEXT_INSET_X,
		0)
	titleText:SetJustifyH("LEFT")
	titleText:SetJustifyV("MIDDLE")
	self:BindText(titleText, localeKey, fallback)

	local panel = CreateFrame("Frame", nil, section, "BackdropTemplate")
	panel:SetPoint(
		"TOPLEFT",
		section,
		"TOPLEFT",
		SECTION_BODY_INSET_X,
		-(SECTION_TITLE_H + SECTION_TITLE_GAP))
	panel:SetPoint(
		"TOPRIGHT",
		section,
		"TOPRIGHT",
		-SECTION_BODY_INSET_R,
		-(SECTION_TITLE_H + SECTION_TITLE_GAP))
	panel:SetHeight(1)
	applyFeaturePanelStyle(panel)

	section.title = title
	section.titleText = titleText
	section.panel = panel
	self.sections[#self.sections + 1] = section
	return section
end

function View:FinishSection(section)
	local rowsHeight = section and section._gfRowOffset or 0
	local height = SECTION_TITLE_H + SECTION_TITLE_GAP + math.max(rowsHeight, 0)
	if section then
		section:SetHeight(height)
		if section.panel then
			section.panel:SetHeight(math.max(rowsHeight, 1))
		end
	end
	self.nextY = self.nextY - height - SECTION_GAP
end

function View:AddRow(section, localeKey, fallback)
	local rowHeight = SECTION_ROW_H
	local offset = section._gfRowOffset or 0
	local panel = section.panel or section
	local row = CreateFrame("Frame", nil, panel)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -offset)
	row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -offset)
	row:SetHeight(rowHeight)

	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", row, "LEFT", SECTION_LABEL_X, 0)
	label:SetSize(SECTION_LABEL_W, SECTION_ROW_TEXT_H)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	label._gfFontSizeOverride = SECTION_ROW_TEXT_SIZE
	if label.SetTextColor then
		label:SetTextColor(0.92, 0.90, 0.84, 1)
	end
	styleFontString(label, "GameFontHighlight")
	self:BindText(
		label,
		localeKey,
		fallback,
		function(widget, text)
			widget:SetText(text)
			if GF.Font and GF.Font.SetFitWidth then
				GF.Font.SetFitWidth(
					widget,
					SECTION_LABEL_W,
					10
				)
			end
		end
	)

	local control = CreateFrame("Frame", nil, row)
	control:SetPoint("LEFT", row, "LEFT", SECTION_CONTROL_X, 0)
	control:SetPoint("RIGHT", row, "RIGHT", -SECTION_CONTROL_INSET_R, 0)
	control:SetHeight(rowHeight)

	row.label = label
	row.control = control
	section._gfRowOffset = offset + rowHeight
	if section.panel then
		section.panel:SetHeight(math.max(section._gfRowOffset, 1))
	end
	self.rows[#self.rows + 1] = row
	return row, control, label
end

function View:AddStatusRow(section, localeKey, fallback)
	local _, control = self:AddRow(section, localeKey, fallback)
	local value = GF.UI.CreateFontString(control, "OVERLAY", "GameFontHighlight")
	value:SetPoint("LEFT", control, "LEFT", 0, 0)
	value:SetPoint("RIGHT", control, "RIGHT", 0, 0)
	value:SetHeight(SECTION_ROW_TEXT_H)
	value:SetJustifyH("LEFT")
	value:SetJustifyV("MIDDLE")
	value._gfFontSizeOverride = SECTION_ROW_TEXT_SIZE
	styleFontString(value, "GameFontHighlight")
	return value
end

local function createStatusGridCell(view, row, column, entry)
	if not entry then
		return nil
	end

	local cell = CreateFrame("Frame", nil, row)
	if column == 1 then
		cell:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		cell:SetPoint(
			"BOTTOMRIGHT",
			row,
			"BOTTOM",
			-(STATUS_GRID_COLUMN_GAP / 2),
			0)
	else
		cell:SetPoint(
			"TOPLEFT",
			row,
			"TOP",
			STATUS_GRID_COLUMN_GAP / 2,
			0)
		cell:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	end

	local label = GF.UI.CreateFontString(
		cell,
		"OVERLAY",
		"GameFontHighlight")
	label:SetPoint("LEFT", cell, "LEFT", STATUS_GRID_LABEL_X, 0)
	label:SetSize(STATUS_GRID_LABEL_W, SECTION_ROW_TEXT_H)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	label:SetMaxLines(1)
	label:SetWordWrap(false)
	label._gfFontSizeOverride = SECTION_ROW_TEXT_SIZE
	if label.SetTextColor then
		label:SetTextColor(0.92, 0.90, 0.84, 1)
	end
	styleFontString(label, "GameFontHighlight")
	view:BindText(
		label,
		entry.localeKey,
		entry.fallback,
		function(widget, text)
			widget:SetText(text)
			if GF.Font and GF.Font.SetFitWidth then
				GF.Font.SetFitWidth(
					widget,
					STATUS_GRID_LABEL_W,
					11)
			end
		end)

	local value = GF.UI.CreateFontString(
		cell,
		"OVERLAY",
		"GameFontHighlight")
	value:SetPoint(
		"LEFT",
		cell,
		"LEFT",
		STATUS_GRID_LABEL_X
			+ STATUS_GRID_LABEL_W
			+ STATUS_GRID_VALUE_GAP,
		0)
	value:SetPoint(
		"RIGHT",
		cell,
		"RIGHT",
		-STATUS_GRID_VALUE_INSET_R,
		0)
	value:SetHeight(SECTION_ROW_TEXT_H)
	value:SetJustifyH("RIGHT")
	value:SetJustifyV("MIDDLE")
	value:SetMaxLines(1)
	value:SetWordWrap(false)
	value._gfFontSizeOverride = SECTION_ROW_TEXT_SIZE
	styleFontString(value, "GameFontHighlight")

	cell.label = label
	cell.value = value
	return value
end

function View:AddStatusGrid(section, columns)
	columns = columns or {}
	local leftColumn = columns.left or {}
	local rightColumn = columns.right or {}
	local rowCount = math.max(#leftColumn, #rightColumn)
	local values = {}
	local panel = section.panel or section

	for rowIndex = 1, rowCount do
		local offset = section._gfRowOffset or 0
		local row = CreateFrame("Frame", nil, panel)
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -offset)
		row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -offset)
		row:SetHeight(SECTION_ROW_H)

		local leftEntry = leftColumn[rowIndex]
		local leftValue = createStatusGridCell(
			self,
			row,
			1,
			leftEntry)
		if leftEntry and leftEntry.id then
			values[leftEntry.id] = leftValue
		end

		local rightEntry = rightColumn[rowIndex]
		local rightValue = createStatusGridCell(
			self,
			row,
			2,
			rightEntry)
		if rightEntry and rightEntry.id then
			values[rightEntry.id] = rightValue
		end

		section._gfRowOffset = offset + SECTION_ROW_H
		self.rows[#self.rows + 1] = row
	end

	if section.panel then
		section.panel:SetHeight(math.max(section._gfRowOffset, 1))
	end
	return values
end

function View:RunAction(actionID, payload)
	if self.onAction then
		self.onAction(actionID, payload)
	elseif GF.Debug and GF.Debug.RunAction then
		GF.Debug:RunAction(actionID, payload)
	end
	if self.onAfterAction then
		self.onAfterAction(actionID, payload)
	end
end

function View:CreateActionButton(parent, config)
	config = config or {}
	local button = GF.UI.CreatePanelButton(
		parent,
		localizedText(config.localeKey, config.fallback),
		ACTION_BUTTON_W)
	self:BindText(button, config.localeKey, config.fallback)
	button:SetScript("OnClick", function()
		local payload
		if config.getPayload then
			payload = config.getPayload()
		end
		self:RunAction(config.actionID, payload)
	end)
	self.buttons[#self.buttons + 1] = button
	return button
end

function View:AddButtonRow(section, rowLocaleKey, rowFallback, buttonConfigs)
	local row, control = self:AddRow(section, rowLocaleKey, rowFallback)
	for index, config in ipairs(buttonConfigs or {}) do
		local button = self:CreateActionButton(control, config)
		button:SetPoint(
			"LEFT",
			control,
			"LEFT",
			(index - 1) * (ACTION_BUTTON_W + ACTION_BUTTON_GAP),
			0)
	end
	return row
end

local function createInputHolder(parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(INPUT_W, INPUT_H)

	local editBox = CreateFrame("EditBox", nil, holder)
	editBox:SetPoint("TOPLEFT", holder, "TOPLEFT", 9, -1)
	editBox:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -8, 1)
	editBox:SetAutoFocus(false)
	editBox:SetMaxLetters(64)
	editBox:SetTextColor(1, 0.96, 0.86, 1)
	editBox._gfFontSizeOverride = 13
	if GF.Font and GF.Font.TrackEditBox then
		GF.Font.TrackEditBox(editBox, "GameFontHighlight")
	else
		styleFontString(editBox, "GameFontHighlight")
	end
	editBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	editBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	local function updateInputChrome()
		local active = editBox:HasFocus()
			or editBox._gfDebugInputHovered == true
		GF.UI.ApplyFilterInputChrome(
			holder,
			active and "hover" or "normal"
		)
	end
	editBox:HookScript("OnEditFocusGained", updateInputChrome)
	editBox:HookScript("OnEditFocusLost", updateInputChrome)
	editBox:HookScript("OnEnter", function()
		editBox._gfDebugInputHovered = true
		updateInputChrome()
	end)
	editBox:HookScript("OnLeave", function()
		editBox._gfDebugInputHovered = nil
		updateInputChrome()
	end)
	updateInputChrome()

	local placeholder = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	placeholder:SetPoint("LEFT", editBox, "LEFT", 0, 0)
	placeholder:SetPoint("RIGHT", editBox, "RIGHT", 0, 0)
	placeholder:SetJustifyH("LEFT")
	placeholder:SetTextColor(0.55, 0.55, 0.55, 0.88)
	placeholder._gfFontSizeOverride = 13
	styleFontString(placeholder, "GameFontDisable")
	editBox:HookScript("OnTextChanged", function(self)
		placeholder:SetShown(self:GetText() == "")
	end)

	holder.editBox = editBox
	holder.placeholder = placeholder
	function holder:GetText()
		return editBox:GetText() or ""
	end
	return holder
end

function View:AddInputActionRow(
	section,
	rowLocaleKey,
	rowFallback,
	placeholderLocaleKey,
	placeholderFallback,
	buttonConfig)
	local row, control = self:AddRow(section, rowLocaleKey, rowFallback)
	local input = createInputHolder(control)
	input:SetPoint("LEFT", control, "LEFT", 0, 0)
	self:BindText(input.placeholder, placeholderLocaleKey, placeholderFallback)

	buttonConfig = buttonConfig or {}
	buttonConfig.getPayload = function()
		return input:GetText()
	end
	local button = self:CreateActionButton(control, buttonConfig)
	button:SetPoint("LEFT", input, "RIGHT", ACTION_BUTTON_GAP, 0)
	return row, input, button
end

function View:Finalize()
	self.bodyH = -self.nextY - SECTION_GAP + CONTENT_BOTTOM_PADDING
	self:UpdateScroll()
end

function View:UpdateScroll()
	if not self.scroll or not self.body then
		return
	end
	local layoutWidth = self.scroll:GetWidth()
	if not layoutWidth or layoutWidth <= 0 then
		layoutWidth = self.parent and self.parent:GetWidth()
	end
	if not layoutWidth or layoutWidth <= 0 then
		return
	end
	local bodyHeight = self.bodyH or 1
	if self._lastLayoutW == layoutWidth and self._lastBodyH == bodyHeight then
		GF.UI.UpdateScrollFrame(self.scroll)
		return
	end
	self._lastLayoutW = layoutWidth
	self._lastBodyH = bodyHeight
	self.body:SetWidth(layoutWidth)
	self.body:SetHeight(bodyHeight)
	GF.UI.UpdateScrollFrame(self.scroll)
end

function View:Show()
	self.root:Show()
	self:UpdateScroll()
end

function View:Hide()
	self.root:Hide()
end

function DebugSurface:Create(parent, options)
	options = options or {}
	local view = setmetatable({
		parent = parent,
		onAction = options.onAction,
		onAfterAction = options.onAfterAction,
		localeBindings = {},
		sections = {},
		rows = {},
		buttons = {},
		nextY = -CONTENT_TOP_OFFSET,
	}, View)

	view.root = CreateFrame("Frame", nil, parent)
	view.root:SetAllPoints(parent)
	view.root:SetFrameLevel(parent:GetFrameLevel() + 1)

	view.scroll = GF.UI.CreateScrollFrame(
		view.root,
		{ rowHeight = GF.SETTINGS_WHEEL_ROW_H or 24 })
	view.scroll:SetPoint(
		"TOPLEFT",
		view.root,
		"TOPLEFT",
		SCROLL_INSET_L,
		0)
	view.scroll:SetPoint(
		"BOTTOMRIGHT",
		view.root,
		"BOTTOMRIGHT",
		-SCROLL_INSET_R,
		GF.CONTENT_SCROLL_INSET_B or 0)
	view.scroll:SetFrameLevel(view.root:GetFrameLevel() + 2)

	view.body = CreateFrame("Frame", nil, view.scroll)
	view.body:SetSize(1, 1)
	view.scroll:SetScrollChild(view.body)

	view.scrollBar = GF.UI.BindMinimalScrollBar(
		view.scroll,
		SCROLLBAR_GAP,
		view.root,
		true)
	if view.scrollBar then
		view.scrollBar:SetWidth(SCROLLBAR_WIDTH)
		view.scrollBar:ClearAllPoints()
		view.scrollBar:SetPoint(
			"TOPLEFT",
			view.scroll,
			"TOPRIGHT",
			SCROLLBAR_GAP,
			-SCROLLBAR_TOP_INSET)
		view.scrollBar:SetPoint(
			"BOTTOMLEFT",
			view.scroll,
			"BOTTOMRIGHT",
			SCROLLBAR_GAP,
			SCROLLBAR_BOTTOM_INSET)
	end

	view.root:HookScript("OnSizeChanged", function()
		view:UpdateScroll()
	end)
	return view
end
