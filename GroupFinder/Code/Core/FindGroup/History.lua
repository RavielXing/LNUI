local _, GF = ...

local History = {}
GF.History = History

local MAX_SAVED_ENTRIES = 10
local NODE_KEY = {
	clear = "history::action::clear",
	empty = "history::state::empty",
	entryPrefix = "history::entry::",
	prefix = "history::",
}

local function savedEntries()
	local getDB = GF.GetDB
	local db = type(getDB) == "function" and getDB() or nil
	if type(db) ~= "table" then
		return nil
	end
	if type(db.history) ~= "table" then
		db.history = {}
	end
	return db.history
end

local function nonEmptyString(value)
	return type(value) == "string" and value ~= "" and value or nil
end

local function activityLabel(activityID)
	if activityID == nil or type(C_LFGList) ~= "table" then
		return nil
	end

	local readTable = C_LFGList.GetActivityInfoTable
	if type(readTable) == "function" then
		local ok, info = pcall(readTable, activityID)
		if ok and type(info) == "table" then
			local label = nonEmptyString(info.fullName) or nonEmptyString(info.shortName)
			if label ~= nil then
				return label
			end
		end
	end

	local readName = C_LFGList.GetActivityFullName
	if type(readName) == "function" then
		local ok, label = pcall(readName, activityID)
		if ok then
			return nonEmptyString(label)
		end
	end
	return nil
end

local function bestLabel(entry)
	return activityLabel(entry and entry.activityID)
		or nonEmptyString(entry and entry.label)
end

local function legacyIdentityParts(entry)
	local legacyKey = type(entry) == "table" and entry.key or nil
	if type(legacyKey) ~= "string" then
		return nil, nil, nil
	end
	return legacyKey:match("^([^:]*):([^:]*):(.*)$")
end

local function comparableParts(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local legacyCategory, legacyActivity, legacyName = legacyIdentityParts(entry)
	local categoryID = entry.categoryID
	local activityID = entry.activityID
	local name = entry.name
	if categoryID == nil then
		categoryID = legacyCategory
	end
	if activityID == nil then
		activityID = legacyActivity
	end
	if name == nil then
		name = legacyName
	end
	return tostring(categoryID or 0), tostring(activityID or 0), tostring(name or "")
end

local function entriesDescribeSameTarget(left, right)
	local leftCategory, leftActivity, leftName = comparableParts(left)
	local rightCategory, rightActivity, rightName = comparableParts(right)
	return leftCategory ~= nil
		and rightCategory ~= nil
		and leftCategory == rightCategory
		and leftActivity == rightActivity
		and leftName == rightName
end

local function removeMatchingEntries(entries, candidate)
	for index = #entries, 1, -1 do
		if entriesDescribeSameTarget(entries[index], candidate) then
			table.remove(entries, index)
		end
	end
end

local function snapshotEntry(source)
	return {
		label = bestLabel(source),
		name = source.name,
		categoryID = source.categoryID,
		filters = source.filters,
		searchFilters = source.searchFilters,
		preferredFilters = source.preferredFilters,
		searchPreferredFilters = source.searchPreferredFilters,
		groupID = source.groupID,
		activityID = source.activityID,
		time = type(time) == "function" and time() or 0,
	}
end

local function trimToCapacity(entries)
	while #entries > MAX_SAVED_ENTRIES do
		table.remove(entries)
	end
end

local function refreshHistoryBranch()
	local navigation = GF.NavData
	local refresh = navigation and navigation.RefreshHistory
	if type(refresh) == "function" then
		refresh()
	end
end

local function isHistoryChildKey(key)
	if type(key) ~= "string" then
		return false
	end
	return key:sub(1, #NODE_KEY.prefix) == NODE_KEY.prefix
end

function History.Add(entry)
	if type(entry) ~= "table" then
		return
	end
	local entries = savedEntries()
	if entries == nil then
		return
	end

	removeMatchingEntries(entries, entry)
	table.insert(entries, 1, snapshotEntry(entry))
	trimToCapacity(entries)
	refreshHistoryBranch()
end

function History.Clear()
	local entries = savedEntries()
	if entries ~= nil then
		if type(wipe) == "function" then
			wipe(entries)
		else
			for key in pairs(entries) do
				entries[key] = nil
			end
		end
	end

	local tree = GF.NavTree
	if tree and isHistoryChildKey(tree.selectedKey) then
		tree.selectedKey = nil
	end
	refreshHistoryBranch()
end

local function navigationFields(entry)
	return {
		level = 1,
		label = bestLabel(entry) or "?",
		isLeaf = true,
		categoryID = entry.categoryID,
		filters = entry.filters or 0,
		searchFilters = entry.searchFilters,
		preferredFilters = entry.preferredFilters,
		searchPreferredFilters = entry.searchPreferredFilters,
		groupID = entry.groupID,
		activityID = entry.activityID,
		navKind = "history",
	}
end

local function historyEntryNode(entry, ordinal)
	local node = navigationFields(entry)
	node.key = NODE_KEY.entryPrefix .. tostring(ordinal)
	return node
end

local function clearActionNode(locale)
	return {
		key = NODE_KEY.clear,
		level = 1,
		label = locale.HISTORY_CLEAR or "Clear history",
		isLeaf = true,
		navKind = "history",
		historyClear = true,
	}
end

local function emptyStateNode(locale)
	return {
		key = NODE_KEY.empty,
		level = 1,
		label = locale.HISTORY_EMPTY or "—",
		isLeaf = false,
		disabled = true,
		navKind = "history",
	}
end

function History.BuildNodes()
	local locale = GF.L or {}
	local entries = savedEntries() or {}
	local nodes = {}

	for index = 1, #entries do
		local entry = entries[index]
		if type(entry) == "table" then
			nodes[#nodes + 1] = historyEntryNode(entry, #nodes + 1)
		end
	end
	if #nodes == 0 then
		return { emptyStateNode(locale) }
	end

	table.insert(nodes, 1, clearActionNode(locale))
	return nodes
end
