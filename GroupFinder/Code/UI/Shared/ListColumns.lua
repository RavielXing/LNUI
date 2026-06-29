local _, GF = ...

GF.ListColumns = {}
local LC = GF.ListColumns

-- Blizzard ColumnDisplayTemplate: first column at x=2, each next overlaps previous by 2px
local COL_ORIGIN_X = 2
local COL_OVERLAP = 2

local BROWSE_DEF = {
	title = { minWidth = 120, weight = 1.2, noHide = true },
	activity = { minWidth = 140, weight = 1.4, sortable = true, noHide = true },
	type = { minWidth = 80, weight = 0.8, noHide = true, align = "CENTER" },
	roles = { minWidth = 140, weight = 1.4, sortable = true, noHide = true },
	ilvl = { minWidth = 60, weight = 0.6, sortable = true, noHide = true, align = "CENTER" },
	leader = { minWidth = 80, weight = 0.8, noHide = true, align = "CENTER" },
	score = { minWidth = 60, weight = 0.6, sortable = true, noHide = true, align = "CENTER" },
	comment = { minWidth = 160, weight = 1.6, noHide = true },
}

local BROWSE_DEFAULT_ORDER = {
	"title", "activity", "type", "roles", "ilvl", "leader", "score", "comment",
}

local APPLICANT_DEF = {
	type = { minWidth = 70, weight = 0.70, noHide = true, align = "CENTER" },
	name = { minWidth = 146, weight = 1.46, align = "CENTER" },
	detail = { minWidth = 266, weight = 2.66 },
	role = { minWidth = 70, weight = 0.70, sortable = true, align = "CENTER" },
	class = { minWidth = 45, weight = 0.45, align = "CENTER" },
	ilvl = { minWidth = 45, weight = 0.45, sortable = true, align = "CENTER" },
	score = { minWidth = 128, weight = 1.28, sortable = true, align = "CENTER" },
	actions = { minWidth = 70, weight = 0.70, noHide = true, align = "CENTER" },
}

local APPLICANT_DEFAULT_ORDER = {
	"type", "name", "role", "class", "score", "ilvl", "detail", "actions",
}

local HEADER_KEY_PVE = {
	title = "COL_TITLE",
	comment = "COL_DETAIL",
	activity = "COL_ACTIVITY",
	type = "COL_TYPE",
	leader = "COL_LEADER",
	ilvl = "COL_REQUIREMENT",
	score = "COL_SCORE",
	roles = "COL_ROLES",
}

local HEADER_KEY_PVP = {
	title = "COL_TITLE",
	comment = "COL_DETAIL",
	activity = "COL_ACTIVITY",
	type = "COL_TYPE",
	leader = "COL_LEADER",
	ilvl = "COL_REQUIREMENT",
	score = "COL_PVP_SCORE",
	roles = "COL_ROLES",
}

local HEADER_KEY_APPLICANT = {
	type = "COL_APP_TYPE",
	name = "COL_APP_NAME",
	detail = "COL_APP_DETAIL",
	role = "COL_APP_ROLE",
	class = "COL_APP_CLASS",
	ilvl = "COL_ILVL",
	score = "COL_APP_SCORE",
	actions = "COL_APP_ACTIONS",
}

local SORT_TOOLTIP_KEY = {
	activity = "COL_SORT_ACTIVITY_TIP",
	ilvl = "COL_SORT_ILVL_TIP",
	score = "COL_SORT_SCORE_TIP",
	roles = "COL_SORT_ROLES_TIP",
}

local PVP_CATEGORY_IDS = {
	[6] = true,
	[7] = true,
	[8] = true,
	[9] = true,
}

local function isApplicantProfile(profile)
	return profile == "applicant"
end

local function getProfileDef(profile)
	if isApplicantProfile(profile) then
		return APPLICANT_DEF, APPLICANT_DEFAULT_ORDER
	end
	return BROWSE_DEF, BROWSE_DEFAULT_ORDER
end

local function fontScaleSig()
	if GF.GetFontScalePct then
		return tostring(GF.GetFontScalePct())
	end
	return "100"
end

local function getIconScaledMinWidth(profile, colId, minWidth)
	local scale = (GF.GetFontScale and GF.GetFontScale()) or 1
	if scale <= 1 then
		return minWidth
	end
	local shouldScale = false
	if isApplicantProfile(profile) then
		shouldScale = colId == "type" or colId == "role" or colId == "class"
	else
		shouldScale = colId == "type" or colId == "roles"
	end
	if not shouldScale then
		return minWidth
	end
	return math.max(1, math.floor((minWidth * scale) + 0.5))
end

local function copyOrder(list, def, defaultOrder)
	local out = {}
	for _, id in ipairs(list or defaultOrder) do
		if def[id] then
			out[#out + 1] = id
		end
	end
	for _, id in ipairs(defaultOrder) do
		if not tContains(out, id) then
			out[#out + 1] = id
		end
	end
	return out
end

function LC:IsPvpBrowseContext(node)
	node = node or (GF.FindGroupTab and GF.FindGroupTab.GetSelection and GF.FindGroupTab:GetSelection())
		or (GF.MainFrame and GF.MainFrame.selection)
	if not node then
		return false
	end
	if node.preferredFilters == Enum.LFGListFilter.PvP then
		return true
	end
	if node.categoryID and PVP_CATEGORY_IDS[node.categoryID] then
		return true
	end
	if node.groupID == "pvp" or node.groupID == "custom_pvp" then
		return true
	end
	return false
end

function LC:GetBrowseProfile(node)
	return self:IsPvpBrowseContext(node) and "browse_pvp" or "browse_pve"
end

function LC:GetDefaultColumnOrder(profile)
	local _, defaultOrder = getProfileDef(profile)
	local order = {}
	for i, id in ipairs(defaultOrder) do
		order[i] = id
	end
	return order
end

function LC:GetDefaultColumnVisible(profile)
	local def, defaultOrder = getProfileDef(profile)
	local vis = {}
	for _, id in ipairs(defaultOrder) do
		vis[id] = true
	end
	if def.actions then
		vis.actions = true
	end
	return vis
end

function LC:IsColumnNoHide(profile, columnID)
	local def = getProfileDef(profile)
	local colDef = def[columnID]
	return colDef and colDef.noHide == true
end

function LC:GetColumnOrder(profile)
	local def, defaultOrder = getProfileDef(profile)
	local db = GF.GetDB()
	local order
	if isApplicantProfile(profile) then
		order = db.applicantColumnOrder
	else
		local store = db.browseColumnOrder
		order = store and store[profile]
	end
	if type(order) ~= "table" or #order == 0 then
		order = defaultOrder
	end
	return copyOrder(order, def, defaultOrder)
end

function LC:SetColumnOrder(profile, order)
	local def, defaultOrder = getProfileDef(profile)
	local db = GF.GetDB()
	order = copyOrder(order, def, defaultOrder)
	if isApplicantProfile(profile) then
		db.applicantColumnOrder = order
	else
		if type(db.browseColumnOrder) ~= "table" then
			db.browseColumnOrder = {}
		end
		db.browseColumnOrder[profile] = order
	end
	self:InvalidateCache()
end

function LC:GetColumnVisible(profile)
	local def, defaultOrder = getProfileDef(profile)
	local db = GF.GetDB()
	local vis
	if isApplicantProfile(profile) then
		vis = db.applicantColumnVisible
	else
		local store = db.browseColumnVisible
		vis = store and store[profile]
	end
	if type(vis) ~= "table" then
		vis = self:GetDefaultColumnVisible(profile)
	end
	local out = self:GetDefaultColumnVisible(profile)
	for id, on in pairs(vis) do
		if def[id] then
			out[id] = on ~= false
		end
	end
	for _, id in ipairs(defaultOrder) do
		if self:IsColumnNoHide(profile, id) then
			out[id] = true
		end
	end
	if def.actions then
		out.actions = true
	end
	return out
end

function LC:SetColumnVisible(profile, columnID, shown)
	if self:IsColumnNoHide(profile, columnID) then
		return
	end
	local db = GF.GetDB()
	if isApplicantProfile(profile) then
		if type(db.applicantColumnVisible) ~= "table" then
			db.applicantColumnVisible = self:GetDefaultColumnVisible(profile)
		end
		db.applicantColumnVisible[columnID] = shown and true or false
	else
		if type(db.browseColumnVisible) ~= "table" then
			db.browseColumnVisible = {}
		end
		if type(db.browseColumnVisible[profile]) ~= "table" then
			db.browseColumnVisible[profile] = self:GetDefaultColumnVisible(profile)
		end
		db.browseColumnVisible[profile][columnID] = shown and true or false
	end
	self:InvalidateCache()
end

function LC:GetHeaderLabel(columnID, profile)
	local L = GF.L or {}
	if isApplicantProfile(profile) then
		local key = HEADER_KEY_APPLICANT[columnID]
		return (key and L[key]) or columnID
	end
	local keys = (profile == "browse_pvp") and HEADER_KEY_PVP or HEADER_KEY_PVE
	local key = keys[columnID]
	return (key and L[key]) or columnID
end

function LC:IsSortable(columnID, profile)
	if isApplicantProfile(profile) then
		local def = APPLICANT_DEF[columnID]
		return def and def.sortable == true
	end
	local def = BROWSE_DEF[columnID]
	return def and def.sortable == true
end

function LC:GetSortTooltip(columnID, profile)
	if isApplicantProfile(profile) then
		return nil
	end
	local L = GF.L or {}
	local key = SORT_TOOLTIP_KEY[columnID]
	return key and L[key] or nil
end

function LC:InvalidateCache()
	self._layoutCache = nil
	self._layoutSig = nil
end

local function layoutOverrideSig(profile)
	local db = GF.GetDB()
	local store = db.browseColumnLayout and db.browseColumnLayout[profile]
	if type(store) ~= "table" then
		return ""
	end
	local parts = {}
	for id, ov in pairs(store) do
		if type(ov) == "table" then
			parts[#parts + 1] = id .. ":" .. tostring(ov.minWidth or "") .. ":" .. tostring(ov.weight or "")
		end
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function LC:GetColumnDef(profile, colId)
	local def = getProfileDef(profile)
	local base = def[colId]
	if not base then
		return nil
	end
	local db = GF.GetDB()
	local store = db.browseColumnLayout and db.browseColumnLayout[profile]
	local ov = store and store[colId]
	return {
		minWidth = (ov and ov.minWidth) or base.minWidth,
		weight = (ov and ov.weight) or base.weight,
		sortable = base.sortable,
		noHide = base.noHide,
		align = base.align,
	}
end

function LC:GetEffectiveColumnDef(profile, colId)
	local colDef = self:GetColumnDef(profile, colId)
	if not colDef then
		return nil
	end
	colDef.minWidth = getIconScaledMinWidth(profile, colId, colDef.minWidth)
	return colDef
end

function LC:ClampMinWidth(v)
	local minV = GF.COL_MIN_WIDTH_MIN or 20
	local maxV = GF.COL_MIN_WIDTH_MAX or 300
	v = math.floor((tonumber(v) or minV) + 0.5)
	return math.max(minV, math.min(maxV, v))
end

function LC:ClampWeight(v)
	local minV = GF.COL_WEIGHT_MIN or 0
	local maxV = GF.COL_WEIGHT_MAX or 3
	v = tonumber(v)
	if not v then
		return minV
	end
	v = math.floor(v * 100 + 0.5) / 100
	return math.max(minV, math.min(maxV, v))
end

function LC:ParseMinWidthText(text)
	local n = tonumber(text)
	if not n then
		return nil
	end
	n = math.floor(n + 0.5)
	local minV = GF.COL_MIN_WIDTH_MIN or 20
	local maxV = GF.COL_MIN_WIDTH_MAX or 300
	if n < minV or n > maxV then
		return nil
	end
	return n
end

function LC:ParseWeightText(text)
	local n = tonumber(text)
	if not n then
		return nil
	end
	local minV = GF.COL_WEIGHT_MIN or 0
	local maxV = GF.COL_WEIGHT_MAX or 3
	if n < minV or n > maxV then
		return nil
	end
	return math.floor(n * 100 + 0.5) / 100
end

function LC:FormatMinWidth(v)
	return tostring(self:ClampMinWidth(v))
end

function LC:FormatWeight(v)
	return string.format("%.2f", self:ClampWeight(v))
end

function LC:SetColumnLayout(profile, colId, minWidth, weight)
	local db = GF.GetDB()
	if type(db.browseColumnLayout) ~= "table" then
		db.browseColumnLayout = {}
	end
	if type(db.browseColumnLayout[profile]) ~= "table" then
		db.browseColumnLayout[profile] = {}
	end
	db.browseColumnLayout[profile][colId] = {
		minWidth = self:ClampMinWidth(minWidth),
		weight = self:ClampWeight(weight),
	}
	self:InvalidateCache()
end

function LC:ResetColumnLayout(profile, colId)
	local db = GF.GetDB()
	local store = db.browseColumnLayout and db.browseColumnLayout[profile]
	if store then
		store[colId] = nil
	end
	self:InvalidateCache()
end

function LC:LayoutOverrideSig(profile)
	return layoutOverrideSig(profile)
end

function LC:BuildActiveIds(profile)
	local def = getProfileDef(profile)
	local order = self:GetColumnOrder(profile)
	local visible = self:GetColumnVisible(profile)
	local active = {}
	for _, id in ipairs(order) do
		if visible[id] ~= false and def[id] then
			active[#active + 1] = id
		end
	end
	return active
end

function LC:GetRelayoutSig(layoutW, profile)
	if not layoutW or layoutW <= 1 then
		return nil
	end
	return layoutW .. "|" .. (profile or "browse_pve") .. "|" .. table.concat(self:BuildActiveIds(profile), ",") .. "|" .. layoutOverrideSig(profile) .. "|" .. fontScaleSig()
end

function LC:ResolveLayout(totalWidth, profile)
	totalWidth = math.max(1, math.floor(totalWidth or 0))
	profile = profile or "browse_pve"
	local active = self:BuildActiveIds(profile)
	local sig = totalWidth .. "|" .. profile .. "|" .. table.concat(active, ",") .. "|" .. layoutOverrideSig(profile) .. "|" .. fontScaleSig()
	if self._layoutSig == sig and self._layoutCache then
		return self._layoutCache
	end

	local minSum = 0
	local weightSum = 0
	for _, id in ipairs(active) do
		local colDef = self:GetEffectiveColumnDef(profile, id)
		minSum = minSum + colDef.minWidth
		weightSum = weightSum + (colDef.weight or 0)
	end

	local widths = {}
	local scale = 1
	if minSum <= 0 then
		local layout = { active = active, byId = {}, headerLayout = {} }
		self._layoutSig = sig
		self._layoutCache = layout
		return layout
	end

	local contentPool = math.max(1, totalWidth - COL_ORIGIN_X - COL_OVERLAP)

	if contentPool <= minSum then
		scale = contentPool / minSum
		for _, id in ipairs(active) do
			local colDef = self:GetEffectiveColumnDef(profile, id)
			widths[id] = math.max(1, math.floor(colDef.minWidth * scale))
		end
	else
		local extra = contentPool - minSum
		for _, id in ipairs(active) do
			local colDef = self:GetEffectiveColumnDef(profile, id)
			widths[id] = colDef.minWidth
		end
		if weightSum > 0 and extra > 0 then
			local assigned = 0
			for _, id in ipairs(active) do
				local colDef = self:GetEffectiveColumnDef(profile, id)
				local w = colDef.weight or 0
				if w > 0 then
					local add = math.floor(extra * w / weightSum)
					widths[id] = widths[id] + add
					assigned = assigned + add
				end
			end
			local remain = extra - assigned
			local idx = 1
			while remain > 0 and #active > 0 do
				local id = active[idx]
				local colDef = self:GetEffectiveColumnDef(profile, id)
				if (colDef.weight or 0) > 0 then
					widths[id] = widths[id] + 1
					remain = remain - 1
				end
				idx = idx + 1
				if idx > #active then
					idx = 1
				end
			end
		end
	end

	local byId = {}
	local headerLayout = {}
	local x = COL_ORIGIN_X
	for i, id in ipairs(active) do
		local cw = widths[id]
		local colDef = self:GetEffectiveColumnDef(profile, id)
		byId[id] = { id = id, index = i, x = x, width = cw, align = colDef and colDef.align or nil }
		headerLayout[i] = { width = cw + COL_OVERLAP }
		x = x + cw
	end

	local layout = {
		active = active,
		byId = byId,
		headerLayout = headerLayout,
		contentWidth = totalWidth,
		scale = scale,
	}
	self._layoutSig = sig
	self._layoutCache = layout
	return layout
end

function LC:MoveColumn(profile, columnID, delta)
	local order = self:GetColumnOrder(profile)
	local idx = tIndexOf(order, columnID)
	if not idx then
		return false
	end
	local newIdx = idx + delta
	if newIdx < 1 or newIdx > #order then
		return false
	end
	order[idx], order[newIdx] = order[newIdx], order[idx]
	self:SetColumnOrder(profile, order)
	return true
end

function LC:GetBrowseSort()
	local db = GF.GetDB()
	local sort = db.browseSort
	if type(sort) ~= "table" or not self:IsSortable(sort.column) then
		return { column = "title", asc = true }
	end
	return { column = sort.column, asc = sort.asc ~= false }
end

function LC:SetBrowseSort(columnID, asc)
	if not self:IsSortable(columnID) then
		return
	end
	local db = GF.GetDB()
	db.browseSort = { column = columnID, asc = asc and true or false }
end

function LC:ToggleBrowseSort(columnID)
	local cur = self:GetBrowseSort()
	if cur.column == columnID then
		self:SetBrowseSort(columnID, not cur.asc)
	else
		local defAsc = (columnID == "title" or columnID == "activity")
		self:SetBrowseSort(columnID, defAsc)
	end
end

function LC:GetApplicantSort()
	local db = GF.GetDB()
	local sort = db.applicantSort
	if type(sort) ~= "table" or not self:IsSortable(sort.column, "applicant") then
		return nil
	end
	return { column = sort.column, asc = sort.asc ~= false }
end

function LC:SetApplicantSort(columnID, asc)
	if not self:IsSortable(columnID, "applicant") then
		return
	end
	local db = GF.GetDB()
	db.applicantSort = { column = columnID, asc = asc and true or false }
end

function LC:ToggleApplicantSort(columnID)
	local cur = self:GetApplicantSort()
	if cur and cur.column == columnID then
		self:SetApplicantSort(columnID, not cur.asc)
	else
		local defAsc = columnID == "role"
		self:SetApplicantSort(columnID, defAsc)
	end
end
