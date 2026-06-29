local _, GF = ...

GF.History = {}
local HIST_MAX = 10

function GF.History.Add(entry)
	local db = GF.GetDB()
	local h = db.history
	local key = string.format("%s:%s:%s", entry.categoryID or 0, entry.activityID or 0, entry.name or "")
	for i, item in ipairs(h) do
		if item.key == key then
			table.remove(h, i)
			break
		end
	end
	table.insert(h, 1, {
		key = key,
		label = entry.label,
		categoryID = entry.categoryID,
		filters = entry.filters,
		preferredFilters = entry.preferredFilters,
		groupID = entry.groupID,
		activityID = entry.activityID,
		time = time(),
	})
	while #h > HIST_MAX do
		table.remove(h)
	end
	if GF.NavData and GF.NavData.RefreshHistory then
		GF.NavData.RefreshHistory()
	end
end

function GF.History.Clear()
	local db = GF.GetDB()
	wipe(db.history)
	if GF.NavTree and GF.NavTree.selectedKey and GF.NavTree.selectedKey:match("^hist_") then
		GF.NavTree.selectedKey = nil
	end
	if GF.NavData and GF.NavData.RefreshHistory then
		GF.NavData.RefreshHistory()
	end
end

function GF.History.BuildNodes()
	local out = {}
	local L = GF.L or {}
	local hist = GF.GetDB().history or {}
	if #hist > 0 then
		out[#out + 1] = {
			key = "hist_clear",
			level = 1,
			label = L.HISTORY_CLEAR or "Clear history",
			isLeaf = true,
			navKind = "history",
			historyClear = true,
		}
	end
	for i, item in ipairs(hist) do
		out[#out + 1] = {
			key = "hist_" .. i,
			level = 1,
			label = item.label or "?",
			isLeaf = true,
			categoryID = item.categoryID,
			filters = item.filters or 0,
			preferredFilters = item.preferredFilters,
			groupID = item.groupID,
			activityID = item.activityID,
			navKind = "history",
		}
	end
	if #hist == 0 then
		out[#out + 1] = {
			key = "hist_empty",
			level = 1,
			label = L.HISTORY_EMPTY or "—",
			isLeaf = false,
			disabled = true,
		}
	end
	return out
end
