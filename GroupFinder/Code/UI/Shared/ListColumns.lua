local _, GF = ...

GF.ListColumns = {}
local Columns = GF.ListColumns

-- ColumnDisplayTemplate anchors its first header two pixels from the left and
-- overlaps adjacent header buttons by two pixels. Row cells use this same
-- geometry so text and header boundaries stay aligned.
local HEADER_ORIGIN_X = 2
local HEADER_OVERLAP = 2

local browseColumns = {
	title = { minWidth = 120, weight = 1.20, noHide = true },
	activity = { minWidth = 140, weight = 1.40, sortable = true, noHide = true },
	type = { minWidth = 80, weight = 0.80, noHide = true, align = "CENTER" },
	roles = { minWidth = 140, weight = 1.40, sortable = true, noHide = true },
	ilvl = { minWidth = 60, weight = 0.60, sortable = true, noHide = true, align = "CENTER" },
	leader = { minWidth = 80, weight = 0.80, noHide = true, align = "CENTER" },
	score = { minWidth = 60, weight = 0.60, sortable = true, noHide = true, align = "CENTER" },
	comment = { minWidth = 160, weight = 1.60, noHide = true },
}

local browseOrder = {
	"title", "activity", "type", "roles", "ilvl", "leader", "score", "comment",
}

local applicantColumns = {
	type = { minWidth = 70, weight = 0.70, noHide = true, align = "CENTER" },
	name = { minWidth = 146, weight = 1.46, align = "CENTER" },
	detail = { minWidth = 266, weight = 2.66 },
	role = { minWidth = 70, weight = 0.70, sortable = true, align = "CENTER" },
	class = { minWidth = 45, weight = 0.45, align = "CENTER" },
	ilvl = { minWidth = 45, weight = 0.45, sortable = true, align = "CENTER" },
	score = { minWidth = 128, weight = 1.28, sortable = true, align = "CENTER" },
	actions = { minWidth = 70, weight = 0.70, noHide = true, align = "CENTER" },
}

local applicantOrder = {
	"type", "name", "role", "class", "score", "ilvl", "detail", "actions",
}

local browseLabels = {
	title = "COL_TITLE",
	activity = "COL_ACTIVITY",
	type = "COL_TYPE",
	roles = "COL_ROLES",
	ilvl = "COL_REQUIREMENT",
	leader = "COL_LEADER",
	score = "COL_SCORE",
	comment = "COL_DETAIL",
}

local pvpBrowseLabels = {
	title = "COL_TITLE",
	activity = "COL_ACTIVITY",
	type = "COL_TYPE",
	roles = "COL_ROLES",
	ilvl = "COL_REQUIREMENT",
	leader = "COL_LEADER",
	score = "COL_PVP_SCORE",
	comment = "COL_DETAIL",
}

local applicantLabels = {
	actions = "COL_APP_ACTIONS",
	class = "COL_APP_CLASS",
	detail = "COL_APP_DETAIL",
	ilvl = "COL_ILVL",
	name = "COL_APP_NAME",
	role = "COL_APP_ROLE",
	score = "COL_APP_SCORE",
	type = "COL_APP_TYPE",
}

local browseSortHints = {
	activity = "COL_SORT_ACTIVITY_TIP",
	roles = "COL_SORT_ROLES_TIP",
	ilvl = "COL_SORT_ILVL_TIP",
	score = "COL_SORT_SCORE_TIP",
}

local pvpCategories = {
	[6] = true,
	[7] = true,
	[8] = true,
	[9] = true,
}

local function isApplicant(profile)
	return profile == "applicant"
end

local function schemaFor(profile)
	if isApplicant(profile) then
		return applicantColumns, applicantOrder
	end
	return browseColumns, browseOrder
end

local function database()
	return GF.GetDB and GF.GetDB() or {}
end

local function arrayCopy(source)
	local result = {}
	for index, value in ipairs(source or {}) do
		result[index] = value
	end
	return result
end

local function normalizedOrder(candidate, definitions, defaults)
	local result, present = {}, {}
	local source = type(candidate) == "table" and candidate or defaults
	for _, columnID in ipairs(source) do
		if definitions[columnID] and not present[columnID] then
			present[columnID] = true
			result[#result + 1] = columnID
		end
	end
	for _, columnID in ipairs(defaults) do
		if not present[columnID] then
			present[columnID] = true
			result[#result + 1] = columnID
		end
	end
	return result
end

local function indexOf(list, value)
	for index, current in ipairs(list or {}) do
		if current == value then
			return index
		end
	end
	return nil
end

local function fontScaleSignature()
	if GF.GetFontScalePct then
		return tostring(GF.GetFontScalePct())
	end
	return "100"
end

local function shouldScaleIconColumn(profile, columnID)
	if isApplicant(profile) then
		return columnID == "type" or columnID == "role" or columnID == "class"
	end
	return columnID == "type" or columnID == "roles"
end

local function scaledMinimum(profile, columnID, minimum)
	local scale = GF.GetFontScale and GF.GetFontScale() or 1
	if scale <= 1 or not shouldScaleIconColumn(profile, columnID) then
		return minimum
	end
	return math.max(1, math.floor(minimum * scale + 0.5))
end

local function savedOrder(db, profile)
	if isApplicant(profile) then
		return db.applicantColumnOrder
	end
	local profiles = db.browseColumnOrder
	return type(profiles) == "table" and profiles[profile] or nil
end

local function savedVisibility(db, profile)
	if isApplicant(profile) then
		return db.applicantColumnVisible
	end
	local profiles = db.browseColumnVisible
	return type(profiles) == "table" and profiles[profile] or nil
end

local function ensureBrowseProfileStore(db, field)
	if type(db[field]) ~= "table" then
		db[field] = {}
	end
	return db[field]
end

local function layoutOverrides(db, profile)
	local profiles = db.browseColumnLayout
	if type(profiles) ~= "table" then
		return nil
	end
	local overrides = profiles[profile]
	return type(overrides) == "table" and overrides or nil
end

local function overridesSignature(profile)
	local overrides = layoutOverrides(database(), profile)
	if not overrides then
		return ""
	end
	local entries = {}
	for columnID, values in pairs(overrides) do
		if type(values) == "table" then
			entries[#entries + 1] = table.concat({
				tostring(columnID),
				tostring(values.minWidth or ""),
				tostring(values.weight or ""),
			}, ":")
		end
	end
	table.sort(entries)
	return table.concat(entries, ";")
end

function Columns:IsPvpBrowseContext(node)
	if not node and GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		node = GF.FindGroupTab:GetSelection()
	end
	if not node and GF.MainFrame then
		node = GF.MainFrame.selection
	end
	if type(node) ~= "table" then
		return false
	end
	local pvpFilter = Enum and Enum.LFGListFilter and Enum.LFGListFilter.PvP
	if pvpFilter ~= nil and node.preferredFilters == pvpFilter then
		return true
	end
	if pvpCategories[node.categoryID] then
		return true
	end
	return node.groupID == "pvp" or node.groupID == "custom_pvp"
end

function Columns:GetBrowseProfile(node)
	if self:IsPvpBrowseContext(node) then
		return "browse_pvp"
	end
	return "browse_pve"
end

function Columns:GetDefaultColumnOrder(profile)
	local _, defaults = schemaFor(profile)
	return arrayCopy(defaults)
end

function Columns:GetDefaultColumnVisible(profile)
	local _, defaults = schemaFor(profile)
	local result = {}
	for _, columnID in ipairs(defaults) do
		result[columnID] = true
	end
	return result
end

function Columns:IsColumnNoHide(profile, columnID)
	local definitions = schemaFor(profile)
	local definition = definitions[columnID]
	return definition ~= nil and definition.noHide == true
end

function Columns:GetColumnOrder(profile)
	local definitions, defaults = schemaFor(profile)
	return normalizedOrder(savedOrder(database(), profile), definitions, defaults)
end

function Columns:SetColumnOrder(profile, order)
	local definitions, defaults = schemaFor(profile)
	local normalized = normalizedOrder(order, definitions, defaults)
	local db = database()
	if isApplicant(profile) then
		db.applicantColumnOrder = normalized
	else
		ensureBrowseProfileStore(db, "browseColumnOrder")[profile] = normalized
	end
	self:InvalidateCache()
end

function Columns:GetColumnVisible(profile)
	local definitions, defaults = schemaFor(profile)
	local result = self:GetDefaultColumnVisible(profile)
	local stored = savedVisibility(database(), profile)
	if type(stored) == "table" then
		for columnID, visible in pairs(stored) do
			if definitions[columnID] then
				result[columnID] = visible ~= false
			end
		end
	end
	for _, columnID in ipairs(defaults) do
		if definitions[columnID].noHide then
			result[columnID] = true
		end
	end
	return result
end

function Columns:SetColumnVisible(profile, columnID, shown)
	local definitions = schemaFor(profile)
	if not definitions[columnID] or definitions[columnID].noHide then
		return false
	end
	local db = database()
	local target
	if isApplicant(profile) then
		if type(db.applicantColumnVisible) ~= "table" then
			db.applicantColumnVisible = self:GetDefaultColumnVisible(profile)
		end
		target = db.applicantColumnVisible
	else
		local profiles = ensureBrowseProfileStore(db, "browseColumnVisible")
		if type(profiles[profile]) ~= "table" then
			profiles[profile] = self:GetDefaultColumnVisible(profile)
		end
		target = profiles[profile]
	end
	target[columnID] = shown == true
	self:InvalidateCache()
	return true
end

function Columns:GetHeaderLabel(columnID, profile)
	local labels
	if isApplicant(profile) then
		labels = applicantLabels
	elseif profile == "browse_pvp" then
		labels = pvpBrowseLabels
	else
		labels = browseLabels
	end
	local localeKey = labels[columnID]
	local locale = GF.L or {}
	return localeKey and locale[localeKey] or columnID
end

function Columns:IsSortable(columnID, profile)
	local definitions = schemaFor(profile)
	local definition = definitions[columnID]
	return definition ~= nil and definition.sortable == true
end

function Columns:GetSortTooltip(columnID, profile)
	if isApplicant(profile) then
		return nil
	end
	local localeKey = browseSortHints[columnID]
	return localeKey and (GF.L or {})[localeKey] or nil
end

function Columns:InvalidateCache()
	self._layoutCache = nil
	self._layoutSig = nil
end

function Columns:ClampMinWidth(value)
	local lower = GF.COL_MIN_WIDTH_MIN or 20
	local upper = GF.COL_MIN_WIDTH_MAX or 300
	local rounded = math.floor((tonumber(value) or lower) + 0.5)
	return math.max(lower, math.min(upper, rounded))
end

function Columns:ClampWeight(value)
	local lower = GF.COL_WEIGHT_MIN or 0
	local upper = GF.COL_WEIGHT_MAX or 3
	local number = tonumber(value)
	if number == nil then
		return lower
	end
	local rounded = math.floor(number * 100 + 0.5) / 100
	return math.max(lower, math.min(upper, rounded))
end

function Columns:ParseMinWidthText(text)
	local number = tonumber(text)
	if number == nil then
		return nil
	end
	local rounded = math.floor(number + 0.5)
	local lower = GF.COL_MIN_WIDTH_MIN or 20
	local upper = GF.COL_MIN_WIDTH_MAX or 300
	if rounded < lower or rounded > upper then
		return nil
	end
	return rounded
end

function Columns:ParseWeightText(text)
	local number = tonumber(text)
	if number == nil then
		return nil
	end
	local lower = GF.COL_WEIGHT_MIN or 0
	local upper = GF.COL_WEIGHT_MAX or 3
	if number < lower or number > upper then
		return nil
	end
	return math.floor(number * 100 + 0.5) / 100
end

function Columns:FormatMinWidth(value)
	return tostring(self:ClampMinWidth(value))
end

function Columns:FormatWeight(value)
	return string.format("%.2f", self:ClampWeight(value))
end

function Columns:GetColumnDef(profile, columnID)
	local definitions = schemaFor(profile)
	local base = definitions[columnID]
	if not base then
		return nil
	end
	local override = layoutOverrides(database(), profile)
	override = override and override[columnID] or nil
	return {
		minWidth = type(override) == "table" and override.minWidth or base.minWidth,
		weight = type(override) == "table" and override.weight or base.weight,
		sortable = base.sortable,
		noHide = base.noHide,
		align = base.align,
	}
end

function Columns:GetEffectiveColumnDef(profile, columnID)
	local definition = self:GetColumnDef(profile, columnID)
	if not definition then
		return nil
	end
	definition.minWidth = scaledMinimum(
		profile,
		columnID,
		self:ClampMinWidth(definition.minWidth)
	)
	definition.weight = self:ClampWeight(definition.weight)
	return definition
end

function Columns:SetColumnLayout(profile, columnID, minWidth, weight)
	local definitions = schemaFor(profile)
	if definitions[columnID] == nil then
		return false
	end
	local db = database()
	local layouts = db.browseColumnLayout
	if type(layouts) ~= "table" then
		layouts = {}
		db.browseColumnLayout = layouts
	end
	local profileLayout = layouts[profile]
	if type(profileLayout) ~= "table" then
		profileLayout = {}
		layouts[profile] = profileLayout
	end
	profileLayout[columnID] = {
		minWidth = self:ClampMinWidth(minWidth),
		weight = self:ClampWeight(weight),
	}
	self:InvalidateCache()
	return true
end

function Columns:ResetColumnLayout(profile, columnID)
	local overrides = layoutOverrides(database(), profile)
	if overrides then
		overrides[columnID] = nil
	end
	self:InvalidateCache()
end

function Columns:LayoutOverrideSig(profile)
	return overridesSignature(profile)
end

function Columns:BuildActiveIds(profile)
	local definitions = schemaFor(profile)
	local visible = self:GetColumnVisible(profile)
	local result = {}
	for _, columnID in ipairs(self:GetColumnOrder(profile)) do
		if definitions[columnID] and visible[columnID] ~= false then
			result[#result + 1] = columnID
		end
	end
	return result
end

local function layoutSignature(width, profile, active)
	return table.concat({
		tostring(width),
		tostring(profile or "browse_pve"),
		table.concat(active, ","),
		overridesSignature(profile),
		fontScaleSignature(),
	}, "|")
end

function Columns:GetRelayoutSig(layoutWidth, profile)
	if not layoutWidth or layoutWidth <= 1 then
		return nil
	end
	profile = profile or "browse_pve"
	return layoutSignature(layoutWidth, profile, self:BuildActiveIds(profile))
end

local function collectLayoutInputs(owner, profile, active)
	local definitions = {}
	local minimumTotal, weightTotal = 0, 0
	for _, columnID in ipairs(active) do
		local definition = owner:GetEffectiveColumnDef(profile, columnID)
		definitions[columnID] = definition
		minimumTotal = minimumTotal + definition.minWidth
		weightTotal = weightTotal + definition.weight
	end
	return definitions, minimumTotal, weightTotal
end

local function distributeWidths(active, definitions, available, minimumTotal, weightTotal)
	local widths = {}
	if available <= minimumTotal then
		local ratio = available / minimumTotal
		for _, columnID in ipairs(active) do
			widths[columnID] = math.max(1, math.floor(definitions[columnID].minWidth * ratio))
		end
		return widths, ratio
	end

	for _, columnID in ipairs(active) do
		widths[columnID] = definitions[columnID].minWidth
	end
	if weightTotal <= 0 then
		return widths, 1
	end

	local spare = available - minimumTotal
	local allocated = 0
	local weighted = {}
	for _, columnID in ipairs(active) do
		local weight = definitions[columnID].weight
		if weight > 0 then
			weighted[#weighted + 1] = columnID
			local addition = math.floor(spare * weight / weightTotal)
			widths[columnID] = widths[columnID] + addition
			allocated = allocated + addition
		end
	end

	local remainder = spare - allocated
	local cursor = 1
	while remainder > 0 and #weighted > 0 do
		local columnID = weighted[cursor]
		widths[columnID] = widths[columnID] + 1
		remainder = remainder - 1
		cursor = cursor == #weighted and 1 or cursor + 1
	end
	return widths, 1
end

function Columns:ResolveLayout(totalWidth, profile)
	profile = profile or "browse_pve"
	totalWidth = math.max(1, math.floor(tonumber(totalWidth) or 0))
	local active = self:BuildActiveIds(profile)
	local signature = layoutSignature(totalWidth, profile, active)
	if self._layoutSig == signature and self._layoutCache then
		return self._layoutCache
	end

	local definitions, minimumTotal, weightTotal = collectLayoutInputs(self, profile, active)
	local layout = {
		active = active,
		byId = {},
		headerLayout = {},
		contentWidth = totalWidth,
		scale = 1,
	}
	if minimumTotal > 0 then
		local available = math.max(1, totalWidth - HEADER_ORIGIN_X - HEADER_OVERLAP)
		local widths
		widths, layout.scale = distributeWidths(
			active,
			definitions,
			available,
			minimumTotal,
			weightTotal
		)
		local x = HEADER_ORIGIN_X
		for index, columnID in ipairs(active) do
			local width = widths[columnID]
			layout.byId[columnID] = {
				id = columnID,
				index = index,
				x = x,
				width = width,
				align = definitions[columnID].align,
			}
			layout.headerLayout[index] = { width = width + HEADER_OVERLAP }
			x = x + width
		end
	end

	self._layoutSig = signature
	self._layoutCache = layout
	return layout
end

function Columns:MoveColumn(profile, columnID, delta)
	local order = self:GetColumnOrder(profile)
	local current = indexOf(order, columnID)
	local destination = current and current + (tonumber(delta) or 0) or nil
	if not destination or destination < 1 or destination > #order then
		return false
	end
	order[current], order[destination] = order[destination], order[current]
	self:SetColumnOrder(profile, order)
	return true
end

function Columns:GetBrowseSort()
	local saved = database().browseSort
	local columnID = type(saved) == "table" and saved.column or nil
	if self:IsSortable(columnID) ~= true then
		return { column = "title", asc = true }
	end
	return {
		column = columnID,
		asc = saved.asc ~= false,
	}
end

function Columns:SetBrowseSort(columnID, ascending)
	if self:IsSortable(columnID) ~= true then
		return false
	end
	local db = database()
	db.browseSort = {
		asc = ascending == true,
		column = columnID,
	}
	return true
end

function Columns:ToggleBrowseSort(columnID)
	local current = self:GetBrowseSort()
	if current.column == columnID then
		return self:SetBrowseSort(columnID, not current.asc)
	end
	return self:SetBrowseSort(columnID, columnID == "title" or columnID == "activity")
end

function Columns:GetApplicantSort()
	local sort = database().applicantSort
	if type(sort) ~= "table" or not self:IsSortable(sort.column, "applicant") then
		return nil
	end
	return { column = sort.column, asc = sort.asc ~= false }
end

function Columns:SetApplicantSort(columnID, ascending)
	if not self:IsSortable(columnID, "applicant") then
		return false
	end
	database().applicantSort = { column = columnID, asc = ascending == true }
	return true
end

function Columns:ToggleApplicantSort(columnID)
	local current = self:GetApplicantSort()
	if current and current.column == columnID then
		return self:SetApplicantSort(columnID, not current.asc)
	end
	return self:SetApplicantSort(columnID, columnID == "role")
end
