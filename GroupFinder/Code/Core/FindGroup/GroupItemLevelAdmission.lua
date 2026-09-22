local _, GF = ...

-- GroupItemLevelAdmission owns the one native source used by the optional
-- lower-bound admission filter. C_PartyInfo resolves the active party on the
-- client, so this module must not inspect members or build a parallel roster.
local Admission = {}
GF.GroupItemLevelAdmission = Admission

local FILTER_KEY = "groupMinimumItemLevelAdmission"

local function finiteNumber(value)
	local ok, number = pcall(tonumber, value)
	if not ok or not number or number ~= number
		or number == math.huge or number == -math.huge
	then
		return nil
	end
	return number
end

local function equippedBaseCategory()
	local categories = Enum and Enum.AvgItemLevelCategories
	return categories and categories.EquippedBase
end

function Admission:GetMinimumEquippedItemLevel()
	local reader = C_PartyInfo and C_PartyInfo.GetMinItemLevel
	local category = equippedBaseCategory()
	if type(reader) ~= "function" or type(category) ~= "number" then
		return nil
	end
	local ok, itemLevel = pcall(reader, category)
	itemLevel = ok and finiteNumber(itemLevel) or nil
	if not itemLevel or itemLevel < 0 then
		return nil
	end
	return math.floor(itemLevel)
end

function Admission:AllowsRequiredItemLevel(requiredItemLevel, minimumItemLevel)
	requiredItemLevel = finiteNumber(requiredItemLevel)
	minimumItemLevel = finiteNumber(minimumItemLevel)
	if requiredItemLevel == nil or minimumItemLevel == nil then
		-- An unavailable native value must never hide a potentially eligible
		-- listing. The server remains authoritative at application time.
		return true
	end
	return requiredItemLevel <= minimumItemLevel
end

local function activeGlobalFilters()
	local tab = GF.FindGroupTab
	local filterSpec = GF.FilterSpec
	local filter = GF.Filter
	if not (tab and type(tab.GetSelection) == "function"
		and filterSpec and type(filterSpec.ResolveSpec) == "function"
		and filter and type(filter.GetGlobalFilters) == "function")
	then
		return nil
	end
	local selection = tab:GetSelection()
	if type(selection) ~= "table" then
		return nil
	end
	local spec = filterSpec:ResolveSpec(selection)
	return type(spec) == "table" and filter:GetGlobalFilters(spec) or nil
end

function Admission:OnSourceChanged()
	local current = self:GetMinimumEquippedItemLevel()
	if self._lastMinimumItemLevel == current then
		return false
	end
	self._lastMinimumItemLevel = current
	local filters = activeGlobalFilters()
	if filters and filters[FILTER_KEY] == true then
		local filter = GF.Filter
		if filter and type(filter.ApplyClientFilterRefresh) == "function" then
			filter:ApplyClientFilterRefresh()
		end
	end
	return true
end
