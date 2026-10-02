local _, GF = ...
GF = GF.GF or GF

local View = {}
GF.UI.ClassSpecSelector = View
local UI = GF.UI
local STYLE = GF.RAID_RECRUITMENT_NEEDS_STYLE
local ROLES = {
	{ role = "TANK", label = "MPLUS_ROLE_TANK_TITLE" },
	{ role = "HEALER", label = "MPLUS_ROLE_HEAL_TITLE" },
	{ role = "DAMAGER", label = "MPLUS_ROLE_DPS_TITLE" },
}

local function applyRoleVisual(button)
	local amount = button.roleAmount
	button.icon:SetDesaturation(1 - amount)
	local tint = STYLE.roleInactiveTint + (1 - STYLE.roleInactiveTint) * amount
	button.icon:SetVertexColor(tint, tint, tint, 1)
	button.icon:SetAlpha(STYLE.roleInactiveAlpha + (1 - STYLE.roleInactiveAlpha) * amount)
end

local function stepRoleTransition(button, elapsed)
	local transition = button.roleTransition
	transition.elapsed = transition.elapsed + elapsed
	local progress = math.min(1, transition.elapsed / STYLE.roleFadeDuration)
	local eased = progress * progress * (3 - 2 * progress)
	button.roleAmount = transition.from + (button.roleTarget - transition.from) * eased
	applyRoleVisual(button)
	if progress == 1 then
		button.roleTransition = nil
		button:SetScript("OnUpdate", nil)
	end
end

-- SetAtlas restores the client's authored UVs and shader nine-slice data.
-- One pixel-snapped texture keeps thin borders intact at small UI scales.
local function applyOptionChrome(host, atlas)
	local chrome = host.optionChrome
	if not chrome then
		local texture = host:CreateTexture(nil, "BACKGROUND")
		texture:SetBlendMode("BLEND")
		texture:SetVertexColor(1, 1, 1, 1)
		UI.SetNativeAtlasSampling(texture, true)
		chrome = { texture = texture }
		host.optionChrome = chrome
	end
	local normalInfo = UI.GetNativeAtlasInfo(STYLE.optionAtlases.normal)
	local atlasInfo = UI.GetNativeAtlasInfo(atlas)
	if not normalInfo or not atlasInfo then
		chrome.atlas = nil
		chrome.texture:Hide()
		return false
	end
	-- Selected includes extra glow padding around the same button body.
	-- Native slicing preserves that padding, so extend only the art bounds.
	local padX = math.max(0, (atlasInfo.logicalWidth - normalInfo.logicalWidth) / 2)
	local padY = math.max(0, (atlasInfo.logicalHeight - normalInfo.logicalHeight) / 2)
	chrome.texture:ClearAllPoints()
	chrome.texture:SetPoint("TOPLEFT", host, "TOPLEFT", -padX, padY)
	chrome.texture:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", padX, -padY)
	local applied = UI.TrySetAtlas(chrome.texture, atlas, false, nil, true)
	chrome.atlas = applied and atlas or nil
	chrome.texture:SetShown(applied)
	return applied and chrome or false
end

local function attachPendingFX(option)
	if not option.TransmogPendingFX then
		option.TransmogPendingFX = UI.CreateButtonPendingFX(option.chromeFrame, STYLE.pendingFX)
	end
	return option.TransmogPendingFX
end

local function font(parent, size)
	local text = UI.CreateFontString(parent, "OVERLAY", "GameFontNormal")
	text._gfFontSizeOverride = size or STYLE.textSize
	text._gfFontFlagsOverride = "OUTLINE"
	if GF.Font and GF.Font.Track then GF.Font.Track(text, "GameFontNormal") end
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	return text
end

-- Selection and permissions belong to the caller; the shared view owns only UI.
function View:Create(parent, options)
	local instance = setmetatable({ options = options, rows = {} }, { __index = self })
	instance.frame = CreateFrame("Frame", nil, parent)
	instance.frame:SetFrameLevel(parent:GetFrameLevel() + 3)
	instance.title = font(instance.frame, STYLE.titleSize)
	instance.title:SetPoint("TOPLEFT", instance.frame, "TOPLEFT", 0, -(STYLE.headerHeight - STYLE.titleSize) / 2)
	local color = GF.CREATE_MANAGER_TITLE_TEXT_COLOR or GF.BROWSE_HEADER_TEXT_COLOR
	instance.title:SetTextColor(unpack(color))
	instance.roleButtons = {}
	for _, data in ipairs(ROLES) do
		instance.roleButtons[data.role] = instance:CreateRoleButton(data)
	end
	instance.listFrame = CreateFrame("Frame", nil, instance.frame)
	instance.listFrame:SetPoint("TOPLEFT", instance.frame, "TOPLEFT", 0, -STYLE.headerHeight - STYLE.titleGap)
	instance.empty = font(instance.listFrame)
	instance.empty:SetPoint("TOPLEFT", instance.listFrame, "TOPLEFT", STYLE.listInset, -STYLE.listInset)
	return instance
end

function View:CreateRoleButton(data)
	local button = CreateFrame("Button", nil, self.frame)
	button.role, button.labelKey = data.role, data.label
	button:RegisterForClicks("LeftButtonUp")
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetSize(STYLE.roleIconSize, STYLE.roleIconSize)
	button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	UI.TrySetAtlas(button.icon, GF.ROLE_ICON_ATLAS[data.role], false, nil, true)
	button:SetScript("OnEnter", function(control)
		control.hovered = control:IsEnabled()
		self:ShowRoleTooltip(control)
	end)
	local function leave(control)
		control.hovered = false
		if GameTooltip and GameTooltip:IsOwned(control) and GameTooltip_Hide then GameTooltip_Hide() end
	end
	button:SetScript("OnLeave", leave)
	local function settle(control)
		leave(control)
		self:RefreshRoleVisual(control, true)
	end
	button:SetScript("OnHide", settle)
	button:SetScript("OnDisable", settle)
	button:SetScript("OnShow", function(control) self:RefreshRoleVisual(control) end)
	button:SetScript("OnClick", function(control, mouseButton)
		if mouseButton == "LeftButton" and self:CanSelect(control) then
			self.options.toggleRole(control.role)
			self:RefreshSelection()
			if control.hovered then self:ShowRoleTooltip(control) end
		end
	end)
	self:RefreshRoleVisual(button, true)
	return button
end

function View:RefreshRoleVisual(button, immediate)
	local target = (button.selectedCount or 0) > 0 and 1 or 0
	if immediate or not button:IsVisible() or not button:IsEnabled() or button.roleAmount == target then
		button.roleTarget, button.roleAmount = target, target
		button.roleTransition = nil
		button:SetScript("OnUpdate", nil)
		applyRoleVisual(button)
	elseif button.roleTarget ~= target then
		button.roleTarget = target
		button.roleTransition = { from = button.roleAmount, elapsed = 0 }
		button:SetScript("OnUpdate", stepRoleTransition)
	end
	button:SetAlpha(button:IsEnabled() and 1 or STYLE.disabledAlpha)
end

function View:AddSelectionHint()
	local key = self.options.selectionHintKey
	local hint = key and (GF.L or {})[key]
	if hint then GameTooltip:AddLine(hint, 1, 0.82, 0, true) end
end

function View:ShowRoleTooltip(button)
	if not (UI.BeginGameTooltip and GameTooltip) then return end
	local labels = GF.L or {}
	UI.BeginGameTooltip(button, "ANCHOR_TOP")
	GameTooltip:SetText(labels[button.labelKey] or button.role)
	GameTooltip:AddLine(string.format(labels.RAID_REQUIRED_ROLE_COUNT or "%s specializations: %d / %d",
		labels[button.labelKey] or button.role, button.selectedCount or 0, button.totalCount or 0), 1, 1, 1)
	if button:IsEnabled() then
		local key = button.selectedCount == 0 and "RAID_REQUIRED_ROLE_ENABLE" or "RAID_REQUIRED_ROLE_BLOCK"
		GameTooltip:AddLine(labels[key], 1, 0.82, 0, true)
	end
	if next(self.options.getSelection() or {}) == nil and self.options.emptySelectionHintKey then
		GameTooltip:AddLine(labels[self.options.emptySelectionHintKey], 1, 0.3, 0.3, true)
	end
	self:AddSelectionHint()
	UI.ShowGameTooltip()
end

function View:RefreshRoles(selected, enabled)
	local counts = GF.RaidRecruitmentNeeds:GetRoleCounts(selected)
	for _, data in ipairs(ROLES) do
		local button, count = self.roleButtons[data.role], counts[data.role]
		button.selectedCount, button.totalCount = count.selected, count.total
		button:SetEnabled(enabled and count.total > 0)
		self:RefreshRoleVisual(button)
	end
end

function View:LayoutRoles()
	local width = self.frame:GetWidth()
	local gaps = STYLE.roleButtonGap * (#ROLES - 1)
	local buttonWidth = STYLE.roleIconSize
	self.roleBarWidth = buttonWidth * #ROLES + gaps + STYLE.roleRightInset
	for index, data in ipairs(ROLES) do
		local button = self.roleButtons[data.role]
		button:ClearAllPoints()
		button:SetSize(buttonWidth, STYLE.headerHeight)
		button:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT",
			-STYLE.roleRightInset - (#ROLES - index) * (buttonWidth + STYLE.roleButtonGap), 0)
	end
	self.title:SetWidth(math.max(1, width - self.roleBarWidth - STYLE.columnGap))
	if GF.Font and GF.Font.SetFitWidth then GF.Font.SetFitWidth(self.title, self.title:GetWidth(), 10) end
end

function View:CreateRow()
	local row = { specs = {} }
	row.frame = CreateFrame("Frame", nil, self.listFrame)
	row.icon = row.frame:CreateTexture(nil, "ARTWORK")
	row.label = font(row.frame)
	row.label:SetPoint("LEFT", row.icon, "RIGHT", STYLE.iconGap, 0)
	return row
end

function View:CreateSpec(row, specID)
	local option = CreateFrame("Button", nil, row.frame)
	option:SetFrameLevel(row.frame:GetFrameLevel() + 4)
	option:RegisterForClicks("LeftButtonUp")
	local iconOverhang = math.max(0, (STYLE.specIconSlotSize - STYLE.optionHeight) / 2)
	option:SetHitRectInsets(0, 0, -iconOverhang, -iconOverhang)
	option.specID = specID
	option.chromeFrame = CreateFrame("Frame", nil, option)
	option.chromeFrame:SetFrameLevel(option:GetFrameLevel() - 3)
	option.chromeFrame:SetPoint("TOPLEFT", option, "TOPLEFT", STYLE.optionBodyInset, 0)
	option.chromeFrame:SetPoint("BOTTOMRIGHT", option, "BOTTOMRIGHT", 0, 0)
	option.icon = option:CreateTexture(nil, "ARTWORK")
	-- The atlas's visible body sits slightly above its transparent canvas center.
	option.icon:SetPoint("CENTER", option.chromeFrame, "LEFT",
		STYLE.specIconSlotSize / 2 - STYLE.optionBodyInset, STYLE.specIconOffsetY)
	option.label = font(option)
	option.label:SetPoint("LEFT", option, "LEFT", STYLE.specIconSlotSize + STYLE.optionTextGap, 0)
	option:SetScript("OnEnter", function(button)
		button.hovered = button:IsEnabled()
		button.pressed = button.mouseDown and IsMouseButtonDown and IsMouseButtonDown("LeftButton") or false
		if not button.pressed then button.mouseDown = false end
		self:RefreshOption(button)
		if UI.BeginGameTooltip and GameTooltip then
			UI.BeginGameTooltip(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(button.fullName or button.label:GetText())
			self:AddSelectionHint()
			UI.ShowGameTooltip()
		end
	end)
	option:SetScript("OnLeave", function(button)
		button.hovered, button.pressed = false, false
		self:RefreshOption(button)
		if GameTooltip_Hide then GameTooltip_Hide() end
	end)
	option:SetScript("OnMouseDown", function(button, mouseButton)
		if mouseButton == "LeftButton" and self:CanSelect(button) then
			button.mouseDown, button.pressed = true, true
			self:RefreshOption(button)
		end
	end)
	option:SetScript("OnMouseUp", function(button, mouseButton)
		if mouseButton == "LeftButton" then
			button.mouseDown, button.pressed = false, false
			self:RefreshOption(button)
		end
	end)
	local function clearPointer(button)
		button.hovered, button.pressed, button.mouseDown = false, false, false
		self:RefreshOption(button)
		if GameTooltip and GameTooltip:IsOwned(button) and GameTooltip_Hide then GameTooltip_Hide() end
	end
	option:SetScript("OnHide", clearPointer)
	option:SetScript("OnDisable", clearPointer)
	option:SetScript("OnClick", function(button, mouseButton)
		button.mouseDown, button.pressed = false, false
		if mouseButton == "LeftButton" and self:CanSelect(button) then
			local selected = self.options.getSelection()
			self.options.setSelected(button.specID, selected[button.specID] ~= true)
		end
		self:RefreshSelection()
	end)
	return option
end

function View:CanSelect(button)
	return button:IsEnabled() and button:IsShown() and self.frame:IsShown()
		and self.options.isEnabled() == true
end

function View:RefreshOption(option, force)
	local enabled = option:IsEnabled()
	local selected = option.selected == true
	if option.specIcon and (force or option.iconSelected ~= selected or option.iconSource ~= option.specIcon) then
		UI.SetSpecializationIcon(option.icon, option.specIcon, {
			size = STYLE.specIconSize, disabled = not selected, preserveDisabledAlpha = true,
		})
		-- Selection grays only the artwork; retain the same default gold ring as class icons.
		UI.SetSpecializationIconHovered(option.icon, false)
		option.iconSelected = selected
		option.iconSource = option.specIcon
	end
	local state = enabled and option.pressed and "pressed"
		or selected and "selected"
		or enabled and option.hovered and "hover"
		or "normal"
	local fx = option.TransmogPendingFX
	if selected and not fx then fx = attachPendingFX(option) end
	if fx then fx:SetShown(selected) end
	local atlas = STYLE.optionAtlases[state == "selected" and fx and "normal" or state]
	if force or option.visualState ~= state or option.visualAtlas ~= atlas then
		local base = applyOptionChrome(option.chromeFrame, atlas)
		option.visualState = base and state or nil
		option.visualAtlas = base and atlas or nil
	end
	local textColor = selected and GF.COMMON_BUTTON_VISUALS.normal.textColor or STYLE.textNormalColor
	option.label:SetTextColor(unpack(textColor))
	option:SetAlpha(enabled and 1 or STYLE.disabledAlpha)
end

function View:RefreshSelection()
	local selected = self.options.getSelection() or {}
	local enabled = self.options.isEnabled() == true
	for _, row in ipairs(self.rows) do
		for _, option in ipairs(row.specs) do
			option.selected = selected[option.specID] == true
			option:SetEnabled(enabled)
			if not enabled then option.hovered, option.pressed, option.mouseDown = false, false, false end
			self:RefreshOption(option)
		end
	end
	self:RefreshRoles(selected, enabled)
end

function View:Layout(width)
	local catalog = GF.RaidRecruitmentNeeds:GetCatalog()
	local labels = GF.L or {}
	-- The empty-state label uses the same tracked font as the rows, without
	-- width fitting. It reflects font changes even while this view is hidden.
	local fontPath, fontSize, fontFlags = self.empty:GetFont()
	local scale = self.frame:GetEffectiveScale()
	local layout = self.layoutCache
	if layout and layout.width == width and layout.catalog == catalog and layout.labels == labels
		and layout.fontPath == fontPath and layout.fontSize == fontSize and layout.fontFlags == fontFlags
		and layout.scale == scale
	then
		-- Selection, permissions and optional atlas/template recovery remain live.
		self:RefreshSelection()
		return layout.height
	end
	local aliases = labels.RAID_REQUIRED_SPEC_SHORT_NAMES or {}
	local contentWidth = math.max(1, width - STYLE.listInset * 2)
	self.title:SetText(labels[self.options.titleKey] or "Class / spec")
	self.title:SetWidth(width)
	self.empty:SetText(labels.RAID_REQUIRED_CLASSES_UNAVAILABLE or "Class specializations are unavailable.")
	self.empty:SetWidth(contentWidth)
	self.empty:SetShown(#catalog == 0)
	local classWidth, maxSpecs = STYLE.classMinWidth, 1
	for index, data in ipairs(catalog) do
		local row = self.rows[index]
		if not row then row = self:CreateRow(); self.rows[index] = row end
		row.frame:Show()
		row.label:SetText(data.name)
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[data.classFile]
		row.label:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
		if row.classFile ~= data.classFile then
			UI.SetSpecializationIcon(row.icon, UI.ResolveClassIcon(data.classFile), { size = STYLE.iconSize })
			row.classFile = data.classFile
		end
		classWidth = math.max(classWidth, row.label:GetStringWidth() + STYLE.rowInset + STYLE.iconSize + STYLE.iconGap + STYLE.columnGap)
		row.count = #data.specs
		row.columns = data.classFile == "DRUID" and 2 or row.count
		maxSpecs = math.max(maxSpecs, row.columns)
		for specIndex, spec in ipairs(data.specs) do
			local check = row.specs[specIndex]
			if not check then check = self:CreateSpec(row, spec.id); row.specs[specIndex] = check end
			check.specID = spec.id
			check.fullName = spec.name
			check:Show()
			check.label:SetText(aliases[spec.id] or spec.name)
			check.specIcon = spec.icon
		end
		for index = #data.specs + 1, #row.specs do row.specs[index]:Hide() end
	end
	for index = #catalog + 1, #self.rows do self.rows[index].frame:Hide() end
	-- All classes share column starts; the druid's second line reuses the first
	-- two columns instead of reserving an empty fourth column for every class.
	classWidth = math.min(classWidth, math.max(STYLE.iconSize, contentWidth * 0.32))
	local available = math.max(1, contentWidth - classWidth - STYLE.rowInset + STYLE.optionGap)
	local specWidth = available / maxSpecs
	local optionWidth = math.max(1, specWidth - STYLE.optionGap)
	local y = STYLE.listInset
	for index = 1, #catalog do
		local row = self.rows[index]
		local height = math.ceil(row.count / row.columns) * STYLE.rowHeight
		row.frame:ClearAllPoints()
		row.frame:SetPoint("TOPLEFT", self.listFrame, "TOPLEFT", STYLE.listInset, -y)
		row.frame:SetSize(contentWidth, height)
		row.icon:ClearAllPoints()
		row.icon:SetPoint("LEFT", row.frame, "LEFT", STYLE.rowInset, 0)
		row.label:SetWidth(math.max(1, classWidth - STYLE.rowInset - STYLE.iconSize - STYLE.iconGap - STYLE.columnGap))
		if GF.Font and GF.Font.SetFitWidth then
			GF.Font.SetFitWidth(row.label, row.label:GetWidth(), 10)
		end
		for specIndex = 1, row.count do
			local check = row.specs[specIndex]
			check:SetSize(optionWidth, STYLE.optionHeight)
			check:ClearAllPoints()
			check:SetPoint("TOPLEFT", row.frame, "TOPLEFT",
				classWidth + ((specIndex - 1) % row.columns) * specWidth,
				-math.floor((specIndex - 1) / row.columns) * STYLE.rowHeight
					- (STYLE.rowHeight - STYLE.optionHeight) / 2)
			local textWidth = math.max(1, optionWidth - STYLE.specIconSlotSize - STYLE.optionTextGap - STYLE.optionTextRightInset)
			check.label:SetWidth(textWidth)
			if GF.Font and GF.Font.SetFitWidth then
				GF.Font.SetFitWidth(check.label, textWidth, 10)
			end
		end
		y = y + height + (index < #catalog and STYLE.rowGap or 0)
	end
	if #catalog == 0 then y = y + STYLE.rowHeight end
	local listHeight = y + STYLE.listInset
	self.listFrame:SetSize(width, listHeight)
	UI.ApplyFilterMultilineInputChrome(self.listFrame, "normal")
	local height = STYLE.headerHeight + STYLE.titleGap + listHeight
	self.frame:SetSize(width, height)
	self:LayoutRoles()
	self:RefreshSelection()
	self.layoutCache = {
		width = width, catalog = catalog, labels = labels, height = height + STYLE.bottomGap,
		fontPath = fontPath, fontSize = fontSize, fontFlags = fontFlags, scale = scale,
	}
	return height + STYLE.bottomGap
end
