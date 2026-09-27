local _, GF = ...

local Bar = {}
GF.MythicPlusCharacterCurrencyBar = Bar
local STYLE = GF.MYTHIC_PLUS_CHARACTER_FOOTER_STYLE

local function layoutIconBorder(frame, size)
	if frame.borderSize == size then return end
	local style = GF.MYTHIC_PLUS_CHARACTER_CONTROL_STYLE
	local corner = style.cornerSize * size / style.referenceHeight
	local border = GF.UI.ApplyControlFrameBorder(frame, {
		atlas = style.atlas, sliceRatios = style.sliceRatios,
		displayMargins = { left = corner, right = corner, top = corner, bottom = corner },
		layer = "OVERLAY", subLevel = 0, color = style.normal,
		continuousInternalUV = true, halfTexelInset = true,
	})
	if border then
		for _, key in ipairs({ "topLeft", "top", "topRight", "left", "right",
			"bottomLeft", "bottom", "bottomRight" }) do
			border[key]:SetDesaturated(true)
		end
		frame.borderSize = size
	end
end

local function hideTooltip(button)
	if GameTooltip and GameTooltip:GetOwner() == button then GameTooltip:Hide() end
end

local function showCrestTooltip(entry)
	local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality]
	GameTooltip:SetText(entry.name or UNKNOWN, color and color.r or 1, color and color.g or 1,
		color and color.b or 1)
	if entry.description then GameTooltip:AddLine(entry.description, 1, 0.82, 0, true) end
	GameTooltip:AddLine(" ")
	local quantity = entry.quantity ~= nil and tostring(entry.quantity) or "-"
	local quantityColor = entry.quantity ~= nil and STYLE.capColors.owned or STYLE.capColors.unknown
	GameTooltip:AddLine(string.format(GF.L.MPLUS_CREST_QUANTITY_FMT,
		"|c" .. quantityColor .. quantity .. "|r"), 1, 0.82, 0, true)
	if entry.capState ~= "unlimited" then
		local earned, maximum = entry.totalEarned, entry.seasonMax
		local colorCode = STYLE.capColors.unknown
		if earned ~= nil and maximum ~= nil then
			colorCode = earned >= maximum and STYLE.capColors.reached or STYLE.capColors.below
		end
		local progress = (earned ~= nil and tostring(earned) or "-") .. "/"
			.. (maximum ~= nil and tostring(maximum) or "-")
		GameTooltip:AddLine(string.format(GF.L.MPLUS_CREST_SEASON_CAP_FMT,
			"|c" .. colorCode .. progress .. "|r"), 1, 0.82, 0, true)
	end
end

local function showTooltip(button)
	if not (GameTooltip and button.entry and button.entry.currencyID) then return end
	-- Refresh the live denominator on every hover, including a new weekly reset.
	button.entry = GF.MythicPlusCharacterCrests:GetEntry(button.character, button.entry.currencyID)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	if button.entry.isSeasonCurrency then
		-- Keep native text, but never show the logged-in character's totals on an alt card.
		showCrestTooltip(button.entry)
	else
		GameTooltip:SetCurrencyByID(button.entry.currencyID)
	end
	if button.character then
		local updatedAt = button.entry.updatedAt
		if button.entry.isSeasonCurrency and button.entry.capState ~= "unlimited" then
			updatedAt = button.entry.progressUpdatedAt
		end
		local text = GF.L.MPLUS_CREST_UNSYNCED
		if updatedAt and updatedAt > 0 and date then
			local parts = date("*t", updatedAt)
			text = string.format("%d/%d/%02d:%02d", parts.month, parts.day, parts.hour, parts.min)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(string.format(GF.L.MPLUS_CREST_UPDATED_AT_FMT, text), 1, 0.94, 0.82, true)
	end
	GameTooltip:Show()
end

function Bar:Layout(bar)
	local count = bar.count or 0
	if count == 0 then return end
	local gap = bar.compactRow and STYLE.compactCurrencyGap or STYLE.currencyGap
	local iconSize = bar.compactRow and STYLE.compactCurrencyIconSize or STYLE.currencyIconSize
	local frameSize = iconSize + 2 * STYLE.currencyIconInset
	local widths, naturalWidth = {}, (count - 1) * gap
	for index = 1, count do
		local quantity = bar.Cells[index].Quantity
		quantity:SetScale(1)
		widths[index] = math.max(1, quantity:GetStringWidth()) + STYLE.currencyTextGap + frameSize
		naturalWidth = naturalWidth + widths[index]
	end
	local available = math.max(1, bar:GetWidth())
	local scale = math.min(1, available / naturalWidth)
	local offset = math.max(0, available - naturalWidth * scale)
	for index = 1, count do
		local button = bar.Cells[index]
		button:ClearAllPoints()
		button:SetPoint("LEFT", bar, "LEFT", offset, 0)
		button:SetSize(widths[index] * scale, frameSize * scale)
		button.IconFrame:ClearAllPoints()
		button.IconFrame:SetPoint("RIGHT", button, "RIGHT", 0, 0)
		button.IconFrame:SetSize(frameSize * scale, frameSize * scale)
		button.Icon:ClearAllPoints()
		button.Icon:SetSize(iconSize * scale, iconSize * scale)
		button.Quantity:ClearAllPoints()
		button.Icon:SetPoint("CENTER", button.IconFrame, "CENTER", 0, 0)
		button.Quantity:SetPoint("RIGHT", button.IconFrame, "LEFT", -STYLE.currencyTextGap * scale, 0)
		button.Quantity:SetJustifyH("RIGHT")
		button.Quantity:SetScale(scale)
		layoutIconBorder(button.IconFrame, frameSize * scale)
		offset = offset + (widths[index] + gap) * scale
	end
end

function Bar:Create(parent, createText)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(STYLE.currencyIconSize + 2 * STYLE.currencyIconInset)
	bar.Cells = {}
	for index = 1, 5 do
		local button = CreateFrame("Button", nil, bar)
		button.IconFrame = CreateFrame("Frame", nil, button)
		button.IconFrame:EnableMouse(false)
		button.Icon = button.IconFrame:CreateTexture(nil, "ARTWORK")
		local crop = STYLE.currencyIconCrop
		button.Icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		local mask = button.IconFrame:CreateMaskTexture()
		mask:SetTexture(STYLE.currencyIconMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(button.Icon)
		button.Icon:AddMaskTexture(mask)
		button.IconMask = mask
		button.Quantity = createText(button, "GameFontHighlightSmall", STYLE.currencyFontSize, "")
		button.Quantity:SetWordWrap(false)
		button:SetScript("OnEnter", showTooltip)
		button:SetScript("OnLeave", hideTooltip)
		button:SetScript("OnHide", hideTooltip)
		bar.Cells[index] = button
	end
	bar:HookScript("OnSizeChanged", function() self:Layout(bar) end)
	return bar
end

function Bar:Bind(bar, character)
	local crests = GF.MythicPlusCharacterCrests
	local ids = crests:GetCurrencyIDs()
	bar.count = #ids
	bar:SetShown(#ids > 0)
	for index, button in ipairs(bar.Cells) do
		local id = ids[index]
		button.entry = id and crests:GetEntry(character, id) or nil
		button.character = character
		button:SetShown(id ~= nil)
		if id then
			local entry = button.entry
			button.Icon:SetTexture(entry.iconFileID or 134400)
			button.Icon:SetDesaturated(entry.quantity == nil or entry.quantity == 0)
			button.Quantity:SetText(entry.quantity ~= nil and tostring(entry.quantity) or "-")
			local brightness = entry.quantity == nil and 0.5 or entry.quantity == 0 and 0.6 or 1
			button.Quantity:SetTextColor(brightness, brightness, brightness, 1)
			if GameTooltip and GameTooltip:GetOwner() == button and GameTooltip:IsShown() then showTooltip(button) end
		else
			hideTooltip(button)
		end
	end
	self:Layout(bar)
end

function Bar:SetMouseEnabled(bar, enabled)
	if not bar then return end
	for _, button in ipairs(bar.Cells) do
		button:EnableMouse(enabled)
		if not enabled then hideTooltip(button) end
	end
end
