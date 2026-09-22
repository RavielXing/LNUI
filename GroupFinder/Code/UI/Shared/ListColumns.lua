local _, GF = ...

-- GroupFinder owns list-column policy in one model. The historical global is
-- kept as an identity alias so callbacks captured by older GF builds continue
-- to resolve the same owner.
local ColumnLayoutModel = {}
GF.ColumnLayoutModel = ColumnLayoutModel
GF.ListColumns = ColumnLayoutModel

local PROFILE_BROWSE_PVE = "browse_pve"
local PROFILE_BROWSE_PVP = "browse_pvp"
local PROFILE_APPLICANT = "applicant"

ColumnLayoutModel.PROFILE_BROWSE_PVE = PROFILE_BROWSE_PVE
ColumnLayoutModel.PROFILE_BROWSE_PVP = PROFILE_BROWSE_PVP
ColumnLayoutModel.PROFILE_APPLICANT = PROFILE_APPLICANT

local LAYOUT_ORIGIN_X = 2
local HEADER_OVERLAP = 2

ColumnLayoutModel.LAYOUT_ORIGIN_X = LAYOUT_ORIGIN_X
ColumnLayoutModel.HEADER_OVERLAP = HEADER_OVERLAP

-- Base management grid; starred leaders retain its date and action geometry.
function ColumnLayoutModel:ResolvePlayerManagementLayout(width)
	local style = GF.PLAYER_MANAGEMENT_STYLE
	width = math.max(1, math.floor(tonumber(width) or 1))
	local player = math.min(math.max(260, math.floor(width * 0.28)), 430)
	local category = math.min(math.max(style.categoryMinWidth,
		math.floor(width * style.categoryRatio)), style.categoryMaxWidth)
	local updated = math.min(math.max(86, math.floor(width * 0.08)), 116)
	local actionMin = style.buttonWidth * 2 + style.buttonGap + style.textInset * 2
	local action = math.min(math.max(actionMin, math.floor(width * style.actionRatio)),
		actionMin + style.actionExtraWidth)
	local note = width - player - category - updated - action
	if note < 260 then
		player = math.max(180, player - (260 - note))
		note = width - player - category - updated - action
	end
	note = math.max(220, note)
	return {
		player = { x = 0, width = player },
		category = { x = player, width = category },
		note = { x = player + category, width = note },
		updated = { x = player + category + note, width = updated },
		action = { x = player + category + note + updated, width = action },
		totalWidth = player + category + note + updated + action,
	}
end

function ColumnLayoutModel:ResolveStarredLeadersLayout(width)
	width = math.max(1, math.floor(tonumber(width) or 1))
	local columns = self:ResolvePlayerManagementLayout(width)
	local style = GF.STARRED_LEADERS_STYLE
	local remaining = math.max(3, width - columns.updated.width - columns.action.width
		- style.statusWidth - style.whisperWidth)
	local player = math.floor(remaining * style.playerRatio)
	local contact = math.floor(remaining * style.contactRatio)
	return {
		player = { width = player }, contact = { width = contact },
		note = { width = remaining - player - contact },
		status = { width = style.statusWidth }, whisper = { width = style.whisperWidth },
		updated = columns.updated, action = columns.action,
	}
end

local function browseColumns(scoreLabelKey)
	return {
		{
			id = "title", labelKey = "COL_TITLE", fallbackLabel = "Title",
			minWidth = 120, weight = 1.20, align = "LEFT", noHide = true,
		},
		{
			id = "activity", labelKey = "COL_ACTIVITY",
			fallbackLabel = "Activity", minWidth = 140, weight = 1.40,
			align = "LEFT", sortable = true, noHide = true,
		},
		{
			id = "type", labelKey = "COL_TYPE", fallbackLabel = "Type",
			minWidth = 80, weight = 0.80, align = "CENTER", noHide = true,
		},
		{
			id = "roles", labelKey = "COL_ROLES", fallbackLabel = "Members",
			minWidth = 140, weight = 1.40, align = "CENTER",
			sortable = true, noHide = true,
		},
		{
			id = "ilvl", labelKey = "COL_REQUIREMENT", fallbackLabel = "Requirement",
			minWidth = 60, weight = 0.60, align = "CENTER",
			sortable = true, noHide = true,
		},
		{
			id = "leader", labelKey = "COL_LEADER", fallbackLabel = "Leader",
			minWidth = 80, weight = 0.80, align = "CENTER", noHide = true,
		},
		{
			id = "score", labelKey = scoreLabelKey, fallbackLabel = "Rating",
			minWidth = 60, weight = 0.60, align = "CENTER",
			sortable = true, noHide = true,
		},
		{
			id = "comment", labelKey = "COL_DETAIL", fallbackLabel = "Details",
			minWidth = 160, weight = 1.60, align = "LEFT", noHide = true,
		},
	}
end

local SCHEMAS = {
	[PROFILE_BROWSE_PVE] = {
		id = PROFILE_BROWSE_PVE,
		kind = "browse",
		columns = browseColumns("COL_SCORE"),
	},
	[PROFILE_BROWSE_PVP] = {
		id = PROFILE_BROWSE_PVP,
		kind = "browse",
		columns = browseColumns("COL_PVP_SCORE"),
	},
	[PROFILE_APPLICANT] = {
		id = PROFILE_APPLICANT,
		kind = "applicant",
		columns = {
			{
				id = "type", labelKey = "COL_APP_TYPE", fallbackLabel = "Type",
				minWidth = 56, weight = 0.56, align = "CENTER", noHide = true,
			},
			{
				id = "name", labelKey = "COL_APP_NAME", fallbackLabel = "Character",
				minWidth = 146, weight = 1.46, align = "CENTER",
			},
			{
				id = "role", labelKey = "COL_APP_ROLE", fallbackLabel = "Role",
				minWidth = 70, weight = 0.70, align = "CENTER", sortable = true,
			},
			{
				id = "class", labelKey = "COL_APP_CLASS", fallbackLabel = "Spec",
				minWidth = 45, weight = 0.45, align = "CENTER",
			},
			{
				id = "score", labelKey = "COL_APP_SCORE",
				fallbackLabel = "Rating / Level", minWidth = 128, weight = 1.28,
				align = "CENTER", sortable = true,
			},
			{
				id = "ilvl", labelKey = "COL_ILVL", fallbackLabel = "Item Level",
				minWidth = 45, weight = 0.45, align = "CENTER", sortable = true,
			},
			{
				id = "detail", labelKey = "COL_APP_DETAIL", fallbackLabel = "Note",
				minWidth = 266, weight = 2.66, align = "LEFT",
			},
			{
				id = "actions", labelKey = "COL_APP_ACTIONS", fallbackLabel = "Actions",
				minWidth = 84, weight = 0.84, align = "CENTER", noHide = true,
			},
		},
	},
}

local function indexSchemas()
	for _, schema in pairs(SCHEMAS) do
		schema.byId = {}
		for index, definition in ipairs(schema.columns) do
			definition.index = index
			schema.byId[definition.id] = definition
		end
	end
end
indexSchemas()

local function canonicalProfile(profile)
	if profile == PROFILE_APPLICANT then
		return PROFILE_APPLICANT
	end
	if profile == PROFILE_BROWSE_PVP or profile == "pvp" then
		return PROFILE_BROWSE_PVP
	end
	return PROFILE_BROWSE_PVE
end

local function schemaFor(profile)
	local canonical = canonicalProfile(profile)
	return SCHEMAS[canonical], canonical
end

local function copyDefinition(definition)
	if not definition then
		return nil
	end
	local copy = {}
	for key, value in pairs(definition) do
		if key ~= "index" then
			copy[key] = value
		end
	end
	copy.index = definition.index
	return copy
end

local function isRaidProgressProfile(profile)
	local snapshot = GF.SearchResultSnapshot
	return canonicalProfile(profile) == PROFILE_BROWSE_PVE
		and snapshot and snapshot.IsSeasonRaidContext
		and snapshot.IsSeasonRaidContext() == true
end

local function isRaidLeaderProfile(profile)
	local snapshot = GF.SearchResultSnapshot
	return canonicalProfile(profile) == PROFILE_BROWSE_PVE
		and snapshot and snapshot.IsRaidContext
		and snapshot.IsRaidContext() == true
end

local function displayDefinition(definition, profile)
	local copy = copyDefinition(definition)
	if copy and copy.id == "score" and isRaidProgressProfile(profile) then
		copy.labelKey, copy.fallbackLabel = "COL_PROGRESS", "Progress"
	end
	if copy and copy.id == "leader" and isRaidLeaderProfile(profile) then
		copy.labelKey, copy.fallbackLabel = "COL_RAID_LEADER", "Raid Leader"
	end
	return copy
end

local function copyArray(values)
	local copy = {}
	for index, value in ipairs(values or {}) do
		copy[index] = value
	end
	return copy
end

local function copyBooleanMap(values)
	local copy = {}
	for key, value in pairs(values or {}) do
		copy[key] = value == true
	end
	return copy
end

local function database()
	local db
	if type(GF.GetDB) == "function" then
		local ok, value = pcall(GF.GetDB)
		if ok and type(value) == "table" then
			db = value
		end
	end
	if type(db) ~= "table" and type(GF.db) == "table" then
		db = GF.db
	end
	if type(db) ~= "table" and type(_G) == "table"
		and type(_G.GroupFinderDB) == "table"
	then
		db = _G.GroupFinderDB
	end
	if type(db) ~= "table" then
		db = {}
		GF.db = db
		if type(_G) == "table" then
			_G.GroupFinderDB = db
		end
	end
	return db
end

local function finiteNumber(value)
	local ok, number = pcall(tonumber, value)
	if not ok or number == nil or number ~= number
		or number == math.huge or number == -math.huge
	then
		return nil
	end
	return number
end

local function denseArrayValues(raw)
	local values = {}
	local indices = {}
	if type(raw) == "table" then
		for key in pairs(raw) do
			if type(key) == "number" and key > 0 and key == math.floor(key) then
				indices[#indices + 1] = key
			end
		end
	end
	table.sort(indices)
	for _, index in ipairs(indices) do
		values[#values + 1] = raw[index]
	end
	return values
end

local function normalizeOrder(raw, schema)
	local order = {}
	local seen = {}
	for _, columnID in ipairs(denseArrayValues(raw)) do
		if type(columnID) == "string" and schema.byId[columnID]
			and not seen[columnID]
		then
			seen[columnID] = true
			order[#order + 1] = columnID
		end
	end
	for _, definition in ipairs(schema.columns) do
		if not seen[definition.id] then
			seen[definition.id] = true
			order[#order + 1] = definition.id
		end
	end
	return order
end

local function sameDenseArray(raw, normalized)
	if type(raw) ~= "table" then
		return false
	end
	local count = 0
	for key in pairs(raw) do
		if type(key) ~= "number" or key <= 0 or key ~= math.floor(key) then
			return false
		end
		count = count + 1
	end
	if count ~= #normalized then
		return false
	end
	for index, value in ipairs(normalized) do
		if raw[index] ~= value then
			return false
		end
	end
	return true
end

local function ensureBrowseStore(db, field)
	if type(db[field]) ~= "table" then
		db[field] = {}
	end
	return db[field]
end

local function rawOrder(db, profile)
	if profile == PROFILE_APPLICANT then
		return db.applicantColumnOrder
	end
	local profiles = db.browseColumnOrder
	return type(profiles) == "table" and profiles[profile] or nil
end

local function writeOrder(db, profile, order)
	local saved = copyArray(order)
	if profile == PROFILE_APPLICANT then
		db.applicantColumnOrder = saved
	else
		ensureBrowseStore(db, "browseColumnOrder")[profile] = saved
	end
end

local function ownedOrder(db, profile, schema)
	local raw = rawOrder(db, profile)
	local normalized = normalizeOrder(raw, schema)
	if not sameDenseArray(raw, normalized) then
		writeOrder(db, profile, normalized)
	end
	return normalized
end

local function defaultVisibility(schema)
	local visible = {}
	for _, definition in ipairs(schema.columns) do
		visible[definition.id] = true
	end
	return visible
end

local function rawVisibility(db, profile)
	if profile == PROFILE_APPLICANT then
		return db.applicantColumnVisible
	end
	local profiles = db.browseColumnVisible
	return type(profiles) == "table" and profiles[profile] or nil
end

local function normalizeVisibility(raw, schema)
	local visible = defaultVisibility(schema)
	if type(raw) == "table" then
		for _, definition in ipairs(schema.columns) do
			if raw[definition.id] == false and definition.noHide ~= true then
				visible[definition.id] = false
			end
		end
	end
	return visible
end

local function sameVisibility(raw, normalized, schema)
	if type(raw) ~= "table" then
		return false
	end
	local count = 0
	for key, value in pairs(raw) do
		if not schema.byId[key] or type(value) ~= "boolean" then
			return false
		end
		count = count + 1
	end
	if count ~= #schema.columns then
		return false
	end
	for _, definition in ipairs(schema.columns) do
		if raw[definition.id] ~= normalized[definition.id] then
			return false
		end
	end
	return true
end

local function writeVisibility(db, profile, visible)
	local saved = copyBooleanMap(visible)
	if profile == PROFILE_APPLICANT then
		db.applicantColumnVisible = saved
	else
		ensureBrowseStore(db, "browseColumnVisible")[profile] = saved
	end
end

local function ownedVisibility(db, profile, schema)
	local raw = rawVisibility(db, profile)
	local normalized = normalizeVisibility(raw, schema)
	if not sameVisibility(raw, normalized, schema) then
		writeVisibility(db, profile, normalized)
	end
	return normalized
end

local layoutCache = {}
local layoutCacheEntries = 0

function ColumnLayoutModel:InvalidateCache()
	layoutCache = {}
	layoutCacheEntries = 0
end

function ColumnLayoutModel:GetProfileIDs()
	return {
		PROFILE_BROWSE_PVE,
		PROFILE_BROWSE_PVP,
		PROFILE_APPLICANT,
	}
end

function ColumnLayoutModel:GetSchema(profile)
	local schema, canonical = schemaFor(profile)
	local snapshot = {
		id = canonical,
		kind = schema.kind,
		columns = {},
		byId = {},
	}
	for index, definition in ipairs(schema.columns) do
		local copy = displayDefinition(definition, canonical)
		snapshot.columns[index] = copy
		snapshot.byId[copy.id] = copy
	end
	return snapshot
end

function ColumnLayoutModel:GetDefaultColumnOrder(profile)
	local schema = schemaFor(profile)
	local order = {}
	for index, definition in ipairs(schema.columns) do
		order[index] = definition.id
	end
	return order
end

function ColumnLayoutModel:GetDefaultColumnVisible(profile)
	local schema = schemaFor(profile)
	return defaultVisibility(schema)
end

function ColumnLayoutModel:GetColumnOrder(profile)
	local schema, canonical = schemaFor(profile)
	return copyArray(ownedOrder(database(), canonical, schema))
end

function ColumnLayoutModel:SetColumnOrder(profile, requestedOrder)
	local schema, canonical = schemaFor(profile)
	if type(requestedOrder) ~= "table" then
		return false
	end
	local db = database()
	local current = ownedOrder(db, canonical, schema)
	local normalized = normalizeOrder(requestedOrder, schema)
	if sameDenseArray(current, normalized) then
		return false
	end
	writeOrder(db, canonical, normalized)
	self:InvalidateCache()
	return true
end

function ColumnLayoutModel:ResetColumnOrder(profile)
	return self:SetColumnOrder(profile, self:GetDefaultColumnOrder(profile))
end

function ColumnLayoutModel:GetColumnVisible(profile)
	local schema, canonical = schemaFor(profile)
	return copyBooleanMap(ownedVisibility(database(), canonical, schema))
end

function ColumnLayoutModel:SetColumnVisible(profile, columnID, visible)
	local schema, canonical = schemaFor(profile)
	local definition = schema.byId[columnID]
	if not definition or (definition.noHide == true and visible == false) then
		return false
	end
	local db = database()
	local current = ownedVisibility(db, canonical, schema)
	local requested = visible ~= false
	if current[columnID] == requested then
		return false
	end
	current[columnID] = requested
	writeVisibility(db, canonical, current)
	self:InvalidateCache()
	return true
end

function ColumnLayoutModel:ResetColumnVisibility(profile)
	local schema, canonical = schemaFor(profile)
	local db = database()
	local current = ownedVisibility(db, canonical, schema)
	local defaults = defaultVisibility(schema)
	if sameVisibility(current, defaults, schema) then
		return false
	end
	writeVisibility(db, canonical, defaults)
	self:InvalidateCache()
	return true
end

function ColumnLayoutModel:IsColumnNoHide(profile, columnID)
	local schema = schemaFor(profile)
	local definition = schema.byId[columnID]
	return definition ~= nil and definition.noHide == true
end

function ColumnLayoutModel:MoveColumn(profile, columnID, delta)
	local schema, canonical = schemaFor(profile)
	if not schema.byId[columnID] then
		return false
	end
	delta = finiteNumber(delta)
	if delta == nil then
		return false
	end
	delta = delta < 0 and math.ceil(delta) or math.floor(delta)
	if delta == 0 then
		return false
	end
	local db = database()
	local order = ownedOrder(db, canonical, schema)
	local source
	for index, current in ipairs(order) do
		if current == columnID then
			source = index
			break
		end
	end
	if source == nil then
		return false
	end
	local destination = source + delta
	if destination < 1 or destination > #order or destination == source then
		return false
	end
	order[source], order[destination] = order[destination], order[source]
	writeOrder(db, canonical, order)
	self:InvalidateCache()
	return true
end

function ColumnLayoutModel:GetColumnDef(profile, columnID)
	local schema = schemaFor(profile)
	local definition = schema.byId[columnID]
	if not definition then
		return nil
	end
	return displayDefinition(definition, profile)
end

local function shouldScaleMinimum(profile, columnID)
	if canonicalProfile(profile) == PROFILE_APPLICANT then
		return columnID == "type" or columnID == "role" or columnID == "class"
	end
	return columnID == "type" or columnID == "roles"
end

local function scaledMinimum(profile, columnID, minimum)
	local scale = 1
	if type(GF.GetFontScale) == "function" then
		local ok, value = pcall(GF.GetFontScale)
		if ok and finiteNumber(value) then
			scale = value
		end
	end
	if scale <= 1 or not shouldScaleMinimum(profile, columnID) then
		return minimum
	end
	return math.max(1, math.floor(minimum * scale + 0.5))
end

function ColumnLayoutModel:GetEffectiveColumnDef(profile, columnID)
	local definition = self:GetColumnDef(profile, columnID)
	if not definition then
		return nil
	end
	definition.minWidth = scaledMinimum(
		profile, columnID, definition.minWidth)
	return definition
end

function ColumnLayoutModel:GetHeaderLabel(columnID, profile)
	local definition = self:GetColumnDef(profile, columnID)
	if not definition then
		return tostring(columnID or "")
	end
	local locale = GF.L or {}
	return locale[definition.labelKey]
		or definition.fallbackLabel
		or definition.id
end

function ColumnLayoutModel:IsSortable(columnID, profile)
	local schema = schemaFor(profile)
	local definition = schema.byId[columnID]
	return definition ~= nil and definition.sortable == true
end

local BROWSE_SORT_HINTS = {
	activity = "COL_SORT_ACTIVITY_TIP",
	roles = "COL_SORT_ROLES_TIP",
	ilvl = "COL_SORT_ILVL_TIP",
	score = "COL_SORT_SCORE_TIP",
}

function ColumnLayoutModel:GetSortHint(columnID, profile)
	if canonicalProfile(profile) == PROFILE_APPLICANT
		or not self:IsSortable(columnID, profile)
	then
		return nil
	end
	local localeKey = BROWSE_SORT_HINTS[columnID]
	if columnID == "score" and isRaidProgressProfile(profile) then
		localeKey = "COL_SORT_PROGRESS_TIP"
	end
	local locale = GF.L or {}
	return localeKey and locale[localeKey] or nil
end

ColumnLayoutModel.GetSortTooltip = ColumnLayoutModel.GetSortHint

local function isPvpCategory(categoryID)
	if categoryID == 6 or categoryID == 7
		or categoryID == 8 or categoryID == 9
	then
		return true
	end
	for _, category in ipairs(GF.PVP_CATEGORIES or {}) do
		if categoryID == category.id then
			return true
		end
	end
	return false
end

function ColumnLayoutModel:IsPvpBrowseContext(node)
	if not node and GF.FindGroupTab
		and type(GF.FindGroupTab.GetSelection) == "function"
	then
		node = GF.FindGroupTab:GetSelection()
	end
	if not node and GF.MainFrame then
		node = GF.MainFrame.selection
	end
	if type(node) ~= "table" then
		return false
	end
	local pvpFilter = Enum and Enum.LFGListFilter
		and Enum.LFGListFilter.PvP
	return node.isPvp == true or node.isPvP == true
		or (pvpFilter ~= nil and node.preferredFilters == pvpFilter)
		or isPvpCategory(node.categoryID)
		or node.activityID == (GF.ACTIVITY_CUSTOM_PVP or 17)
		or node.navKind == "pvp"
		or node.groupID == "pvp"
		or node.groupID == "custom_pvp"
		or false
end

function ColumnLayoutModel:GetBrowseProfile(node)
	return self:IsPvpBrowseContext(node)
		and PROFILE_BROWSE_PVP or PROFILE_BROWSE_PVE
end

local function layoutWidth(value)
	local number = finiteNumber(value) or 1
	return math.max(1, math.floor(number + 0.5))
end

local function stateSnapshot(profile)
	local schema, canonical = schemaFor(profile)
	local db = database()
	local order = ownedOrder(db, canonical, schema)
	local visible = ownedVisibility(db, canonical, schema)
	local fontScale = 100
	if type(GF.GetFontScalePct) == "function" then
		local ok, value = pcall(GF.GetFontScalePct)
		if ok and finiteNumber(value) then
			fontScale = value
		end
	end
	local signature = { canonical, "font=" .. tostring(fontScale) }
	if isRaidProgressProfile(canonical) then signature[#signature + 1] = "raid-progress" end
	if isRaidLeaderProfile(canonical) then signature[#signature + 1] = "raid-leader" end
	for _, columnID in ipairs(order) do
		local definition = schema.byId[columnID]
		signature[#signature + 1] = table.concat({
			columnID,
			visible[columnID] and "1" or "0",
			tostring(definition.minWidth),
			tostring(definition.weight),
		}, ",")
	end
	return {
		profile = canonical,
		schema = schema,
		order = order,
		visible = visible,
		signature = table.concat(signature, ";"),
	}
end

function ColumnLayoutModel:BuildActiveIds(profile)
	local state = stateSnapshot(profile)
	local active = {}
	for _, columnID in ipairs(state.order) do
		if state.visible[columnID] ~= false then
			active[#active + 1] = columnID
		end
	end
	return active
end

local function calculateWidths(definitions, availableWidth)
	local minimumTotal = 0
	local weightTotal = 0
	for _, definition in ipairs(definitions) do
		minimumTotal = minimumTotal + definition.minWidth
		weightTotal = weightTotal + definition.weight
	end
	local widths = {}
	if minimumTotal <= 0 then
		return widths, minimumTotal, 1
	end
	if availableWidth < minimumTotal then
		local compression = availableWidth / minimumTotal
		for index, definition in ipairs(definitions) do
			widths[index] = math.max(
				1, math.floor(definition.minWidth * compression))
		end
		return widths, minimumTotal, compression
	end

	for index, definition in ipairs(definitions) do
		widths[index] = definition.minWidth
	end
	if weightTotal <= 0 then
		return widths, minimumTotal, 1
	end
	local spare = availableWidth - minimumTotal
	local allocated = 0
	local weighted = {}
	for index, definition in ipairs(definitions) do
		if definition.weight > 0 then
			weighted[#weighted + 1] = index
			local addition = math.floor(spare * definition.weight / weightTotal)
			widths[index] = widths[index] + addition
			allocated = allocated + addition
		end
	end
	local remainder = spare - allocated
	local cursor = 1
	while remainder > 0 and #weighted > 0 do
		local index = weighted[cursor]
		widths[index] = widths[index] + 1
		remainder = remainder - 1
		cursor = cursor == #weighted and 1 or cursor + 1
	end
	return widths, minimumTotal, 1
end

function ColumnLayoutModel:ResolveLayout(width, profile)
	local requestedWidth = layoutWidth(width)
	local state = stateSnapshot(profile)
	local cacheKey = table.concat({
		state.profile,
		tostring(requestedWidth),
		state.signature,
	}, "\031")
	local cached = layoutCache[cacheKey]
	if cached then
		return cached
	end

	local definitions = {}
	for _, columnID in ipairs(state.order) do
		if state.visible[columnID] ~= false then
			local definition = displayDefinition(state.schema.byId[columnID], state.profile)
			definition.minWidth = scaledMinimum(
				state.profile,
				columnID,
				definition.minWidth
			)
			definitions[#definitions + 1] = definition
		end
	end
	local availableWidth = math.max(
		1, requestedWidth - LAYOUT_ORIGIN_X - HEADER_OVERLAP)
	local widths, minimumTotal, scale = calculateWidths(definitions, availableWidth)
	local layout = {
		profile = state.profile,
		active = {},
		byId = {},
		headerLayout = {},
		contentWidth = requestedWidth,
		availableWidth = availableWidth,
		usedWidth = 0,
		minimumWidth = minimumTotal + LAYOUT_ORIGIN_X + HEADER_OVERLAP,
		scale = scale,
		signature = state.signature,
	}
	local x = LAYOUT_ORIGIN_X
	for index, definition in ipairs(definitions) do
		local columnWidth = widths[index]
		local column = copyDefinition(definition)
		column.index = index
		column.x = x
		column.width = columnWidth
		column.visible = true
		layout.active[index] = column.id
		layout.byId[column.id] = column
		layout.headerLayout[index] = { width = columnWidth + HEADER_OVERLAP }
		layout.usedWidth = layout.usedWidth + columnWidth
		x = x + columnWidth
	end

	if layoutCacheEntries >= 64 then
		layoutCache = {}
		layoutCacheEntries = 0
	end
	layoutCache[cacheKey] = layout
	layoutCacheEntries = layoutCacheEntries + 1
	return layout
end

function ColumnLayoutModel:GetRelayoutSig(width, profile)
	if not finiteNumber(width) or width <= 1 then
		return nil
	end
	local layout = self:ResolveLayout(width, profile)
	local signature = {
		layout.profile,
		tostring(layout.contentWidth),
		layout.signature,
	}
	for _, columnID in ipairs(layout.active) do
		local column = layout.byId[columnID]
		signature[#signature + 1] = columnID .. "=" .. tostring(column.width)
	end
	return table.concat(signature, "|")
end

local function validBrowseSortColumn(columnID)
	return SCHEMAS[PROFILE_BROWSE_PVE].byId[columnID] ~= nil
		and SCHEMAS[PROFILE_BROWSE_PVE].byId[columnID].sortable == true
end

local function validApplicantSortColumn(columnID)
	return SCHEMAS[PROFILE_APPLICANT].byId[columnID] ~= nil
		and SCHEMAS[PROFILE_APPLICANT].byId[columnID].sortable == true
end

function ColumnLayoutModel:GetBrowseSort()
	local saved = database().browseSort
	local columnID = type(saved) == "table" and saved.column or nil
	if not validBrowseSortColumn(columnID) then
		return { column = "title", asc = true }
	end
	return { column = columnID, asc = saved.asc ~= false }
end

function ColumnLayoutModel:SetBrowseSort(columnID, ascending)
	if not validBrowseSortColumn(columnID) then
		return false
	end
	database().browseSort = { column = columnID, asc = ascending == true }
	return true
end

function ColumnLayoutModel:ToggleBrowseSort(columnID)
	if not validBrowseSortColumn(columnID) then
		return false
	end
	local current = self:GetBrowseSort()
	local ascending
	if current.column == columnID then
		ascending = not current.asc
	else
		ascending = columnID == "title" or columnID == "activity"
	end
	return self:SetBrowseSort(columnID, ascending)
end

function ColumnLayoutModel:GetApplicantSort()
	local saved = database().applicantSort
	if type(saved) ~= "table" or not validApplicantSortColumn(saved.column) then
		return nil
	end
	return { column = saved.column, asc = saved.asc ~= false }
end

function ColumnLayoutModel:SetApplicantSort(columnID, ascending)
	if not validApplicantSortColumn(columnID) then
		return false
	end
	database().applicantSort = {
		column = columnID,
		asc = ascending == true,
	}
	return true
end

function ColumnLayoutModel:ToggleApplicantSort(columnID)
	if not validApplicantSortColumn(columnID) then
		return false
	end
	local current = self:GetApplicantSort()
	local ascending
	if current and current.column == columnID then
		ascending = not current.asc
	else
		ascending = columnID == "role"
	end
	return self:SetApplicantSort(columnID, ascending)
end
