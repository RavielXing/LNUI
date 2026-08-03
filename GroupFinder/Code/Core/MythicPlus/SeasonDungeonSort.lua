local _, GF = ...

GF.MythicPlusSeasonDungeonSort = GF.MythicPlusSeasonDungeonSort or {}
local Sort = GF.MythicPlusSeasonDungeonSort

local function getRule()
	local rule = GF.MYTHIC_PLUS_SEASON_DUNGEON_SORT_RULE
	return type(rule) == "table" and rule or nil
end

local function getRun(entry)
	if type(entry) ~= "table" then
		return nil
	end
	return type(entry.bestRun) == "table" and entry.bestRun
		or type(entry.run) == "table" and entry.run
		or nil
end

local function getScore(entry, rule)
	local run = getRun(entry)
	local missingScore = tonumber(rule.missingScore) or 0
	return math.max(missingScore, tonumber(run and run.score) or missingScore)
end

local function getOrderValue(entry, field)
	if type(entry) ~= "table" then
		return math.huge
	end
	local value = entry[field]
	if value == nil and type(entry.dungeon) == "table" then
		value = entry.dungeon[field]
	end
	return tonumber(value) or math.huge
end

local function compareNumber(left, right, direction)
	if left == right then
		return nil
	end
	if direction == "DESC" then
		return left > right
	end
	return left < right
end

local function compareDecorated(left, right, rule)
	local scoreOrder = compareNumber(
		getScore(left.entry, rule),
		getScore(right.entry, rule),
		rule.scoreDirection)
	if scoreOrder ~= nil then
		return scoreOrder
	end

	for _, field in ipairs(type(rule.orderFields) == "table" and rule.orderFields or {}) do
		local fieldOrder = compareNumber(
			getOrderValue(left.entry, field),
			getOrderValue(right.entry, field),
			rule.orderDirection)
		if fieldOrder ~= nil then
			return fieldOrder
		end
	end

	if rule.preserveInputOrder ~= false then
		return left.inputOrder < right.inputOrder
	end
	return false
end

function Sort:GetRule()
	return getRule()
end

function Sort:Sort(source)
	local decorated = {}
	for inputOrder, entry in ipairs(type(source) == "table" and source or {}) do
		decorated[#decorated + 1] = {
			entry = entry,
			inputOrder = inputOrder,
		}
	end

	local rule = getRule()
	if not rule then
		local unchanged = {}
		for index, item in ipairs(decorated) do
			unchanged[index] = item.entry
		end
		return unchanged
	end
	table.sort(decorated, function(left, right)
		return compareDecorated(left, right, rule)
	end)

	local sorted = {}
	for index, item in ipairs(decorated) do
		sorted[index] = item.entry
	end
	return sorted
end
