local _, GF = ...

local History = {}
GF.History = History

local CAPACITY = 10

local function historyStore()
	local db = GF.GetDB and GF.GetDB()
	if not db then
		return nil
	end
	if type(db.history) ~= "table" then
		db.history = {}
	end
	return db.history
end

local function usableText(value)
	return type(value) == "string" and value ~= "" and value or nil
end

local function activityText(activityID)
	if not activityID or not C_LFGList then
		return nil
	end

	if type(C_LFGList.GetActivityInfoTable) == "function" then
		local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
		if ok and type(info) == "table" then
			local name = usableText(info.fullName) or usableText(info.shortName)
			if name then
				return name
			end
		end
	end

	if type(C_LFGList.GetActivityFullName) == "function" then
		local ok, name = pcall(C_LFGList.GetActivityFullName, activityID)
		if ok then
			return usableText(name)
		end
	end
	return nil
end

local function displayText(activityID, fallback)
	return activityText(activityID) or usableText(fallback)
end

local function identityFor(entry)
	return table.concat({
		tostring(entry.categoryID or 0),
		tostring(entry.activityID or 0),
		tostring(entry.name or ""),
	}, ":")
end

local function removeIdentity(items, identity)
	for index = #items, 1, -1 do
		if items[index].key == identity then
			table.remove(items, index)
		end
	end
end

local function savedEntry(source, identity)
	return {
		key = identity,
		label = displayText(source.activityID, source.label),
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

local function refreshNavigation()
	local nav = GF.NavData
	if nav and type(nav.RefreshHistory) == "function" then
		nav.RefreshHistory()
	end
end

function History.Add(entry)
	if type(entry) ~= "table" then
		return
	end
	local items = historyStore()
	if not items then
		return
	end

	local identity = identityFor(entry)
	removeIdentity(items, identity)
	table.insert(items, 1, savedEntry(entry, identity))
	for index = #items, CAPACITY + 1, -1 do
		table.remove(items, index)
	end
	refreshNavigation()
end

function History.Clear()
	local items = historyStore()
	if items then
		if type(wipe) == "function" then
			wipe(items)
		else
			for key in pairs(items) do
				items[key] = nil
			end
		end
	end

	local tree = GF.NavTree
	if tree and type(tree.selectedKey) == "string" and tree.selectedKey:find("hist_", 1, true) == 1 then
		tree.selectedKey = nil
	end
	refreshNavigation()
end

local function clearNode(L)
	local node = {}
	node.key = "hist_clear"
	node.level = 1
	node.label = L.HISTORY_CLEAR or "Clear history"
	node.isLeaf = true
	node.navKind = "history"
	node.historyClear = true
	return node
end

local function entryNode(item, index)
	return {
		key = "hist_" .. index,
		level = 1,
		label = displayText(item.activityID, item.label) or "?",
		isLeaf = true,
		categoryID = item.categoryID,
		filters = item.filters or 0,
		searchFilters = item.searchFilters,
		preferredFilters = item.preferredFilters,
		searchPreferredFilters = item.searchPreferredFilters,
		groupID = item.groupID,
		activityID = item.activityID,
		navKind = "history",
	}
end

function History.BuildNodes()
	local L = GF.L or {}
	local items = historyStore() or {}
	local nodes = {}

	if #items == 0 then
		nodes[1] = {
			key = "hist_empty",
			level = 1,
			label = L.HISTORY_EMPTY or "—",
			isLeaf = false,
			disabled = true,
		}
		return nodes
	end

	nodes[1] = clearNode(L)
	for index, item in ipairs(items) do
		nodes[#nodes + 1] = entryNode(item, index)
	end
	return nodes
end
