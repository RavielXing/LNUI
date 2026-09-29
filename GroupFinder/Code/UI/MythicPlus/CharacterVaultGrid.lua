local _, GF = ...

GF.MythicPlusCharacterVaultGrid = {}
local Grid = GF.MythicPlusCharacterVaultGrid

local LAYOUT = GF.MYTHIC_PLUS_VAULT_GRID_LAYOUT
local FIRST_CELL_X = LAYOUT.categoryWidth + LAYOUT.categoryGap
local GRID_WIDTH = FIRST_CELL_X + 2 * LAYOUT.columnStep + LAYOUT.cellWidth
Grid.RIGHT_INSET = LAYOUT.rightInset + GRID_WIDTH + LAYOUT.dividerGap
local ROWS = {
	{ key = "raid", label = "MPLUS_VAULT_RAID", fallback = "团队副本" },
	{ key = "dungeons", label = "MPLUS_VAULT_DUNGEONS", fallback = "地下城" },
	{ key = "world", label = "MPLUS_VAULT_WORLD", fallback = "世界" },
}

local function text(key, fallback)
	return GF.L and GF.L[key] or fallback
end

local function hideTooltip(cell)
	if GameTooltip and GameTooltip:GetOwner() == cell then
		GameTooltip:Hide()
	end
end

local function showTooltip(cell)
	GF.MythicPlusCharacterVaultTooltip:Show(cell)
end

local function showCategoryTooltip(category)
	if not GameTooltip then return end
	local definition = category.rowDefinition
	GF.UI.BeginGameTooltipAbove(category)
	GameTooltip:SetPoint("BOTTOM", category.Icon, "TOP", 0, GF.TOOLTIP_BUTTON_TOP_GAP or 4)
	GameTooltip:SetText(text(definition.label, definition.fallback), 1, 0.82, 0)
	GF.UI.ShowGameTooltip()
end

local function refreshCategory(category)
	local definition = category.rowDefinition
	local style = GF.MYTHIC_PLUS_VAULT_CATEGORY_STYLE
	local ready = GF.UI.TrySetAtlas(category.Icon, style.atlases[definition.key], false)
	local tint = style.tints[definition.key]
	category.Icon:SetDesaturated(tint ~= nil)
	if tint then
		category.Icon:SetVertexColor(unpack(tint))
	else
		category.Icon:SetVertexColor(1, 1, 1, 1)
	end
	category.Icon:SetShown(ready)
	category.Fallback:SetText(text(definition.label, definition.fallback))
	category.Fallback:SetShown(not ready)
	if GameTooltip and GameTooltip:GetOwner() == category and GameTooltip:IsShown() then
		showCategoryTooltip(category)
	end
end

local function pauseAnimations(grid)
	grid.animationElapsed = 0
	for _, cell in ipairs(grid.Cells) do
		GF.MythicPlusCharacterVaultOrb:Pause(cell.Orb)
	end
end

local function inViewport(cell, viewport)
	if not viewport then return true end
	local top, bottom = cell:GetTop(), cell:GetBottom()
	local viewTop, viewBottom = viewport:GetTop(), viewport:GetBottom()
	if not (top and bottom and viewTop and viewBottom) then return false end
	local scale, viewScale = cell:GetEffectiveScale(), viewport:GetEffectiveScale()
	return top * scale > viewBottom * viewScale
		and bottom * scale < viewTop * viewScale
end

function Grid:UpdateAnimations(grid, elapsed)
	grid.animationElapsed = (grid.animationElapsed or 0) + elapsed
	if grid.animationElapsed < GF.MYTHIC_PLUS_VAULT_ORB_STYLE.tick then return end
	local step = math.min(grid.animationElapsed, 0.1)
	grid.animationElapsed = 0
	for _, cell in ipairs(grid.Cells) do
		if cell:IsVisible() and inViewport(cell, grid.viewport) then
			GF.MythicPlusCharacterVaultOrb:Advance(cell.Orb, step)
		else
			GF.MythicPlusCharacterVaultOrb:Pause(cell.Orb)
		end
	end
end

local function refreshAnimationDriver(grid)
	local animate = false
	if grid:IsVisible() and not grid.animationPaused then
		for _, cell in ipairs(grid.Cells) do
			if cell.Orb.ready and cell.Orb.fraction > 0 then animate = true; break end
		end
	end
	if animate then
		grid:SetScript("OnUpdate", function(self, elapsed)
			Grid:UpdateAnimations(self, elapsed)
		end)
	else
		grid:SetScript("OnUpdate", nil)
		pauseAnimations(grid)
	end
end

function Grid:Create(card, createText)
	local grid = CreateFrame("Frame", nil, card)
	local rowHeight = GF.MYTHIC_PLUS_VAULT_ORB_STYLE.diameter
	grid:SetPoint("RIGHT", card, "RIGHT", -LAYOUT.rightInset, 0)
	grid:SetSize(GRID_WIDTH, rowHeight + 2 * LAYOUT.rowStep)
	grid:SetFrameLevel(card:GetFrameLevel() + 5)
	grid:EnableMouse(false)
	grid.Cells = {}
	grid.Categories = {}
	local divider = GF.ColumnHeaderBar:CreateDivider(grid, LAYOUT.dividerHeight)
	divider:SetPoint("CENTER", grid, "LEFT", -LAYOUT.dividerGap, 0)
	divider:EnableMouse(false)
	GF.ColumnHeaderBar:TintDivider(divider, GF.MYTHIC_PLUS_CHARACTER_BORDER_COLOR)
	grid.Divider = divider
	for rowIndex, definition in ipairs(ROWS) do
		local y = -(rowIndex - 1) * LAYOUT.rowStep
		local category = CreateFrame("Button", nil, grid)
		category:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y)
		category:SetSize(LAYOUT.categoryWidth, rowHeight)
		category.rowDefinition = definition
		category.Icon = category:CreateTexture(nil, "ARTWORK")
		category.Icon:SetPoint("CENTER")
		local iconSize = GF.MYTHIC_PLUS_VAULT_CATEGORY_STYLE.size
		category.Icon:SetSize(iconSize, iconSize)
		category.Fallback = createText(category, "GameFontHighlight", 11, "")
		category.Fallback:SetAllPoints(category)
		category.Fallback:SetJustifyH("CENTER")
		category.Fallback:SetJustifyV("MIDDLE")
		category.Fallback:SetTextColor(1, 1, 1, 1)
		category:SetScript("OnEnter", showCategoryTooltip)
		category:SetScript("OnLeave", hideTooltip)
		category:SetScript("OnHide", hideTooltip)
		refreshCategory(category)
		grid.Categories[rowIndex] = category
		for column = 1, 3 do
			local cell = CreateFrame("Button", nil, grid)
			cell:SetPoint("TOPLEFT", grid, "TOPLEFT", FIRST_CELL_X + (column - 1) * LAYOUT.columnStep, y)
			cell:SetSize(LAYOUT.cellWidth, rowHeight)
			cell.column = column
			cell.Orb = GF.MythicPlusCharacterVaultOrb:Create(cell)
			cell:SetScript("OnSizeChanged", function(self)
				GF.MythicPlusCharacterVaultOrb:Resize(self.Orb)
			end)
			cell.Text = createText(cell.Orb.LabelHost, "GameFontHighlightSmall", 11, "OUTLINE")
			cell.Text:SetPoint("CENTER")
			cell.card = card
			cell.rowDefinition = definition
			cell.column = column
			cell:SetScript("OnEnter", showTooltip)
			cell:SetScript("OnLeave", hideTooltip)
			cell:SetScript("OnHide", hideTooltip)
			grid.Cells[#grid.Cells + 1] = cell
		end
	end
	grid:SetScript("OnShow", refreshAnimationDriver)
	grid:SetScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
		pauseAnimations(self)
	end)
	return grid
end

function Grid:Bind(grid, data)
	local cache = GF.MythicPlusWeeklyCache
	local colors = GF.MYTHIC_PLUS_VAULT_ORB_STYLE.textColors
	for rowIndex, definition in ipairs(ROWS) do
		refreshCategory(grid.Categories[rowIndex])
		local row, state
		if cache and cache.GetCharacterVaultRow then
			row, state = cache:GetCharacterVaultRow(data.greatVault, definition.key)
		end
		for column = 1, 3 do
			local cell = grid.Cells[(rowIndex - 1) * 3 + column]
			local slot = row and row.slots[column]
			cell.slot, cell.state = slot, state or "missing"
			cell.vaultRow = row
			cell.updatedAt = row and row.updatedAt
			cell.complete = slot ~= nil and slot.progress >= slot.threshold
			local reward = row and row.details and row.details.slots[column]
			local itemLevel = cell.complete and reward and reward.itemLevel
			if itemLevel and itemLevel > 0 then
				cell.Text:SetText(string.format("%d", itemLevel))
			else
				cell.Text:SetText(slot and string.format("%d/%d",
					math.min(slot.progress, slot.threshold), slot.threshold) or "")
			end
			local color = cell.complete and colors.complete
				or (slot and colors.progress or colors.unknown)
			cell.Text:SetTextColor(unpack(color))
			GF.MythicPlusCharacterVaultOrb:Bind(cell.Orb, slot,
				data.guid or data.key or data.fullName or data.name or data,
				row and row.resetAt)
			if GameTooltip and GameTooltip:GetOwner() == cell
				and GameTooltip:IsShown()
			then
				showTooltip(cell)
			end
		end
	end
	refreshAnimationDriver(grid)
end

function Grid:SetMouseEnabled(grid, enabled)
	if not grid then return end
	grid.animationPaused = not enabled
	for _, cell in ipairs(grid and grid.Cells or {}) do
		cell:EnableMouse(enabled)
		if not enabled then hideTooltip(cell) end
	end
	for _, category in ipairs(grid.Categories) do
		category:EnableMouse(enabled)
		if not enabled then hideTooltip(category) end
	end
	refreshAnimationDriver(grid)
end

function Grid:LayoutCard(card)
	if not card.VaultGrid then return end
	local nameWidth = math.max(40, card.TopSection:GetWidth() - 58 - 122)
	GF.Font.SetFitWidth(card.Name, nameWidth, 10)
	local measuredWidth = card.Name.GetUnboundedStringWidth
		and card.Name:GetUnboundedStringWidth() or card.Name:GetStringWidth()
	card.Name:SetWidth(math.min(nameWidth, math.max(1, measuredWidth)))
end
