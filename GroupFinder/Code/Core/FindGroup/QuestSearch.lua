local _, GF = ...

GF.QuestSearch = GF.QuestSearch or {}
local QuestSearch = GF.QuestSearch

local function canAccessValue(value)
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return false
		end
	end
	return true
end

local function readableText(value)
	if not canAccessValue(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	if value:find("|K", 1, true) then
		return nil
	end
	if (_G.UNKNOWNOBJECT and value == _G.UNKNOWNOBJECT)
		or (_G.UNKNOWNBEING and value == _G.UNKNOWNBEING)
	then
		return nil
	end
	return value
end

local function safeInteger(value, allowZero)
	if not canAccessValue(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or type(number) ~= "number" or number ~= math.floor(number) then
		return nil
	end
	if allowZero then
		return number >= 0 and number or nil
	end
	return number > 0 and number or nil
end

local function copyNode(node)
	local copy = {}
	for key, value in pairs(node or {}) do
		copy[key] = value
	end
	return copy
end

function QuestSearch:NormalizeQuestID(questID)
	return safeInteger(questID, false)
end

function QuestSearch:Resolve(questID)
	questID = self:NormalizeQuestID(questID)
	if not questID then
		return nil, "invalid_quest"
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	local resolver = _G.LFGListUtil_GetQuestCategoryData
	if type(resolver) ~= "function" then
		return nil, "resolver_unavailable"
	end
	local ok, activityID, categoryID, filters, questName = pcall(resolver, questID)
	if not ok then
		return nil, "resolver_failed"
	end
	activityID = safeInteger(activityID, false)
	categoryID = safeInteger(categoryID, false)
	filters = safeInteger(filters, true)
	if not activityID or not categoryID or filters == nil then
		return nil, "mapping_unavailable"
	end
	if not (C_LFGList and type(C_LFGList.ClearSearchResults) == "function"
		and type(C_LFGList.ClearSearchTextFields) == "function"
		and type(C_LFGList.SetSearchToQuestID) == "function"
		and type(C_LFGList.Search) == "function")
	then
		return nil, "search_api_unavailable"
	end

	local baseNode = GF.NavData and GF.NavData.FindNodeByActivityID
		and GF.NavData.FindNodeByActivityID(activityID) or nil
	local selection = copyNode(baseNode)
	selection.key = baseNode and baseNode.key
		or ("quest_activity:" .. tostring(activityID))
	selection.searchKey = selection.key .. ":quest:" .. tostring(questID)
	selection.label = readableText(questName)
		or ((GF.L or {}).NAV_QUEST or _G.QUESTS_LABEL or "Quest")
	selection.categoryID = categoryID
	selection.filters = filters
	selection.preferredFilters = Enum.LFGListFilter.PvE
	selection.categoryBrowse = true
	selection.activityID = nil
	selection.activityInfo = nil
	selection.activityIDsFilter = nil
	selection.resultActivityIDsFilter = nil
	selection.groupID = nil
	selection.children = nil
	selection.disabled = false
	selection.questID = questID
	selection.questActivityID = activityID
	selection._gfQuestSearch = true

	return {
		questID = questID,
		activityID = activityID,
		categoryID = categoryID,
		filters = filters,
		baseNode = baseNode,
		selection = selection,
	}
end
