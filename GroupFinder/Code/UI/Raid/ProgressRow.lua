local _, GF = ...

local UI, P, S = GF.UI, GF.RaidSeekingProtocol, GF.RAID_SEEKING_STYLE
local ProgressRow = {}
GF.RaidSeekingProgressRow = ProgressRow
local function label(key) return (GF.L or {})["SEEK_" .. key] or (GF.L or {})[key] or key end

local function progressText(parent, fontFlags)
	local value = UI.CreateFontString(parent, "OVERLAY", "GameFontHighlightSmall")
	value:SetJustifyH("LEFT")
	value:SetJustifyV("MIDDLE"); value:SetWordWrap(false); value:SetMaxLines(1)
	value:SetHeight(S.progressRowHeight); value:SetTextColor(unpack(S.accentColor))
	value:SetShadowColor(unpack(S.targetNameShadowColor))
	value:SetShadowOffset(S.targetNameShadowX, S.targetNameShadowY)
	value._gfFontSizeOverride = S.progressTextSize
	value._gfFontFlagsOverride = fontFlags
	if GF.Font and GF.Font.ApplyToFontString then GF.Font.ApplyToFontString(value, "GameFontHighlightSmall") end
	return value
end

local function renderProgressBackground(row, group, width)
	local height, imageWidth = S.progressRowHeight, math.min(S.targetImageWidth, width)
	local margin = GF.CONTROL_FRAME_DISPLAY_MARGIN
	if width <= margin * 2 then
		for _, piece in ipairs(row.backgroundPieces) do piece:Hide() end
		return
	end
	local xs = { 0, margin, width - margin, width }
	local coords = group.texCoords or { 0, 1, 0, 1 }
	local center = (coords[3] + coords[4]) / 2
	local cropHeight = (coords[4] - coords[3]) * math.min(1, height / S.targetImageHeight)
	for i = 1, 3 do
		local piece = row.backgroundPieces[i]
		if not piece then
			-- Each full-height strip has one complete mask. Bake the corner
			-- shape into the asset instead of cropping or stacking mask UVs.
			piece = row:CreateTexture(nil, "ARTWORK", nil, 0)
			piece:SetAlpha(S.targetImageAlpha)
			piece.edgeMask = row:CreateMaskTexture()
			-- Extend the opaque horizontal seam texels instead of sampling a
			-- transparent border between adjoining masks. Outer texels are clear.
			piece.edgeMask:SetTexture(S.progressMaskTextures[i], "CLAMP", "CLAMPTOBLACKADDITIVE")
			piece:AddMaskTexture(piece.edgeMask)
			row.backgroundPieces[i] = piece
		end
		local right = math.min(xs[i + 1], imageWidth)
		piece.edgeMask:ClearAllPoints()
		piece.edgeMask:SetPoint("TOPLEFT", row, "TOPLEFT", xs[i], 0)
		piece.edgeMask:SetSize(xs[i + 1] - xs[i], height)
		piece:ClearAllPoints(); piece:SetPoint("TOPLEFT", row, "TOPLEFT", xs[i], 0)
		piece:SetSize(math.max(1, right - xs[i]), height)
		piece:SetTexture(group.texture)
		if group.texture and right > xs[i] then
			piece:SetTexCoord(coords[1] + (coords[2] - coords[1]) * xs[i] / imageWidth,
				coords[1] + (coords[2] - coords[1]) * right / imageWidth,
				center - cropHeight / 2, center + cropHeight / 2)
			-- A single continuous vertex-alpha gradient multiplies the inner
			-- contour without a second mask or a change at strip boundaries.
			piece:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1 - xs[i] / imageWidth),
				CreateColor(1, 1, 1, 1 - right / imageWidth))
		else piece:SetTexCoord(0, 1, 0, 1) end
		piece:SetShown(group.texture ~= nil and right > xs[i])
	end
end

local function hideProgressTooltip(row)
	if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function showProgressTooltip(row)
	if (row.canShowProgressTooltip and not row.canShowProgressTooltip())
		or not (row:IsVisible() and GameTooltip and row.tooltipEntries and #row.tooltipEntries > 0) then return end
	UI.BeginGameTooltip(row, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddDoubleLine(row.tooltipTitle, label(row.progressHeadingKey or "PROGRESS"),
		S.accentColor[1], S.accentColor[2], S.accentColor[3], S.accentColor[1], S.accentColor[2], S.accentColor[3])
	for _, entry in ipairs(row.tooltipEntries) do
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(entry.name, S.accentColor[1], S.accentColor[2], S.accentColor[3])
		local bosses = row.getProgressBosses and row.getProgressBosses(entry.data) or {}
		for _, boss in ipairs(bosses) do
			local defeated = boss.defeated
			local nameColor = defeated == true and S.progressBossDeadNameColor or S.progressBossNameColor
			local statusColor = defeated == true and S.progressBossDeadColor
				or defeated == false and S.progressBossAliveColor or S.progressBossDeadNameColor
			local status = defeated == true and BOSS_DEAD or defeated == false and BOSS_ALIVE or label("UNKNOWN")
			GameTooltip:AddDoubleLine(P.Display(boss.name), status,
				nameColor[1], nameColor[2], nameColor[3], statusColor[1], statusColor[2], statusColor[3])
		end
		if #bosses == 0 then GameTooltip:AddLine(label("BOSS_DETAILS_UNAVAILABLE"), unpack(S.progressBossDeadNameColor)) end
	end
	UI.ShowGameTooltip(GameTooltip)
end

function ProgressRow.Render(row, group, parent, width, y, options)
	options = options or {}
	if not row then
		row = CreateFrame("Frame", nil, parent)
		row:SetClipsChildren(true)
		row.backgroundPieces = {}
		row.label, row.values, row.dividers = progressText(row, "OUTLINE"), {}, {}
		row.label:SetPoint("LEFT", S.progressInset, 0)
		row:EnableMouse(true)
		row:SetScript("OnEnter", showProgressTooltip)
		row:SetScript("OnLeave", hideProgressTooltip)
		row:SetScript("OnHide", hideProgressTooltip)
	end
	row.canShowProgressTooltip = options.canShowTooltip
	row.getProgressBosses = options.getBosses
	row.progressHeadingKey = options.headingKey
	row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetSize(width, S.progressRowHeight)
	UI.ApplyControlCardChrome(row)
	renderProgressBackground(row, group, width)
	local name = P.Display(group.activityGroupName or group.name)
	row.label:SetText(name)
	local count, totalWidth, dividerWidth, widths = #group.difficulties, 0, 0, {}
	row.tooltipTitle = name
	row.tooltipEntries = {}
	for i, entry in ipairs(group.difficulties) do
		local value = row.values[i]
		if not value then value = progressText(row); value:SetJustifyH("RIGHT"); row.values[i] = value end
		local difficulty = P.Display(entry.name or label("UNKNOWN"))
		local valueFormat = entry.done == 0 and S.progressZeroValueFormat or S.progressValueFormat
		local progress = entry.done ~= nil and entry.total ~= nil
			and string.format(valueFormat, entry.done, entry.total) or label("UNKNOWN")
		value:SetText(string.format(options.difficultyValueFormat or "%s: %s", difficulty, progress))
		widths[i] = value:GetStringWidth()
		local activityName = P.Text(entry.activityName)
		if not activityName or activityName == "" then activityName = "#" .. tostring(entry.activityID) end
		row.tooltipEntries[i] = { name = P.Display(activityName), data = entry }
		totalWidth = totalWidth + widths[i]
		if i > 1 then
			local divider = row.dividers[i - 1]
			if not divider then
				divider = GF.ColumnHeaderBar:CreateDivider(row, S.progressDividerHeight)
				GF.ColumnHeaderBar:TintDivider(divider, S.mutedColor)
				row.dividers[i - 1] = divider
			end
			dividerWidth = dividerWidth + divider:GetWidth() + S.progressDividerGap * 2
		end
	end
	local textWidth = math.max(1, width - S.progressInset * 2 - S.progressTextGap)
	local available = math.max(1, textWidth - S.progressMinNameWidth - dividerWidth)
	local scale = math.min(1, available / math.max(1, totalWidth))
	local nameWidth = math.max(1, textWidth - totalWidth * scale - dividerWidth)
	row.label:SetWidth(nameWidth)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(row.label, nameWidth, S.progressMinTextSize)
	end
	local offset = S.progressInset
	for i = count, 1, -1 do
		local value, valueWidth = row.values[i], widths[i] * scale
		value:ClearAllPoints(); value:SetPoint("RIGHT", row, "RIGHT", -offset, 0); value:SetWidth(valueWidth)
		if GF.Font and GF.Font.SetFitWidth then GF.Font.SetFitWidth(value, valueWidth, S.progressMinTextSize) end
		value:Show(); offset = offset + valueWidth
		if i > 1 then
			local divider = row.dividers[i - 1]
			divider:ClearAllPoints(); divider:SetPoint("RIGHT", row, "RIGHT", -offset - S.progressDividerGap, 0)
			divider:Show(); offset = offset + S.progressDividerGap * 2 + divider:GetWidth()
		end
	end
	for i = count + 1, #row.values do row.values[i]:Hide(); row.values[i]:SetText("") end
	for i = math.max(1, count), #row.dividers do row.dividers[i]:Hide() end
	row:Show()
	if GameTooltip and GameTooltip:IsShown() and GameTooltip:IsOwned(row) then showProgressTooltip(row) end
	return row
end

ProgressRow.CreateText = progressText
ProgressRow.RenderBackground = renderProgressBackground
ProgressRow.HideTooltip = hideProgressTooltip
