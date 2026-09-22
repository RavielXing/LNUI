local _, GF = ...

-- NativeSearchGateway is the only module that mutates Blizzard's premade-group
-- search store.  Search.lua owns GroupFinder's request/session policy; this
-- gateway owns the narrow, protected transition into C_LFGList.
GF.NativeSearchGateway = GF.NativeSearchGateway or {}
local Gateway = GF.NativeSearchGateway

local function nativeFunction(name)
	local api = C_LFGList
	local value = api and api[name]
	return type(value) == "function" and value or nil
end

local function callNative(callback, ...)
	if type(callback) ~= "function" then
		return false
	end
	return pcall(callback, ...)
end

function Gateway:CanSearch()
	return nativeFunction("Search") ~= nil
end

function Gateway:CanSearchForQuest()
	return self:CanSearch()
		and nativeFunction("ClearSearchResults") ~= nil
		and nativeFunction("ClearSearchTextFields") ~= nil
		and nativeFunction("SetSearchToQuestID") ~= nil
end

function Gateway:GetActiveQuestID()
	return self.activeQuestID
end

function Gateway:SetActiveQuestID(activeQuestID)
	self.activeQuestID = activeQuestID
end

function Gateway:ReleaseSearchSelection()
	local finderFrame = _G and _G.LFGListFrame
	local searchPanel = finderFrame and finderFrame.SearchPanel
	if not searchPanel then
		return false
	end
	searchPanel.selectedResult = nil
	return true
end

function Gateway:ClearResults()
	local clearResults = nativeFunction("ClearSearchResults")
	if not clearResults then
		return false
	end
	self:ReleaseSearchSelection()
	return callNative(clearResults)
end

function Gateway:ClearText()
	return callNative(nativeFunction("ClearSearchTextFields"))
end

function Gateway:ClearResultsAndText()
	local clearResults = nativeFunction("ClearSearchResults")
	local clearText = nativeFunction("ClearSearchTextFields")
	if not clearResults or not clearText then
		return false
	end
	self:ReleaseSearchSelection()
	local resultsOK = callNative(clearResults)
	local textOK = callNative(clearText)
	return resultsOK and textOK
end

function Gateway:ClearQuestSearch()
	if self.activeQuestID == nil then
		return true
	end
	if not self:ClearResultsAndText() then
		return false
	end
	self.activeQuestID = nil
	return true
end

function Gateway:SuspendQuestSearch()
	if self.activeQuestID == nil then
		return true
	end
	-- Hiding Browse releases only the borrowed quest field.  The native result
	-- store remains alive so the same completed GroupFinder session is usable
	-- when its view is shown again.
	return self:ClearText()
end

function Gateway:ReleaseQuestSearchForKeyword()
	if self.activeQuestID == nil then
		return true
	end
	-- The player has already replaced the task title inside Blizzard's protected
	-- edit box.  Clearing native text here would destroy that hardware-authored
	-- keyword.  Release only GroupFinder's task ownership; StartSearch will
	-- release the stale native row selection immediately before the new request.
	self.activeQuestID = nil
	return true
end

function Gateway:PrepareQuestSearch(questID)
	if questID == nil or nativeFunction("SetSearchToQuestID") == nil then
		return false
	end
	if self.activeQuestID ~= questID then
		if nativeFunction("ClearSearchResults") == nil
			or nativeFunction("ClearSearchTextFields") == nil
			or not self:ClearResultsAndText()
		then
			return false
		end
	end
	if not callNative(nativeFunction("SetSearchToQuestID"), questID) then
		return false
	end
	self.activeQuestID = questID
	return true
end

function Gateway:ReadResults(useFiltered)
	local reader
	if useFiltered == true then
		reader = nativeFunction("GetFilteredSearchResults")
	else
		reader = nativeFunction("GetSearchResults")
	end
	if not reader then
		return 0, {}, false
	end
	local ok, total, resultIDs = pcall(reader)
	if not ok then
		return 0, {}, false
	end
	return tonumber(total) or 0,
		type(resultIDs) == "table" and resultIDs or {},
		true
end

function Gateway:CanReadResults(useFiltered)
	local methodName = useFiltered == true
		and "GetFilteredSearchResults" or "GetSearchResults"
	return nativeFunction(methodName) ~= nil
end

function Gateway:CanReadSearchResultInfo()
	return nativeFunction("GetSearchResultInfo") ~= nil
end

function Gateway:GetSearchResultInfo(resultID)
	local reader = nativeFunction("GetSearchResultInfo")
	if not reader or resultID == nil then
		return nil
	end
	local ok, info = pcall(reader, resultID)
	return ok and info or nil
end

function Gateway:_ReadLanguages()
	local reader = nativeFunction("GetLanguageSearchFilter")
	if not reader then
		return true, nil
	end
	local ok, languages = pcall(reader)
	return ok, languages
end

function Gateway:StartSearch(scope)
	if type(scope) ~= "table" or scope.categoryID == nil then
		return false
	end
	local search = nativeFunction("Search")
	if not search then
		return false
	end
	local languagesOK, languages = self:_ReadLanguages()
	if not languagesOK then
		return false
	end

	if scope.questID ~= nil then
		if not self:PrepareQuestSearch(scope.questID) then
			return false
		end
	elseif self.activeQuestID ~= nil and not self:ClearQuestSearch() then
		return false
	end

	-- Clear again immediately before Search. ClearSearchResults can cause the
	-- hidden Blizzard panel to choose another row synchronously.
	self:ReleaseSearchSelection()
	local ok = callNative(
		search,
		scope.categoryID,
		scope.filters or 0,
		scope.preferredFilters or Enum.LFGListFilter.PvE,
		languages,
		nil,
		nil,
		scope.activityIDsFilter
	)
	if not ok and scope.questID ~= nil then
		self:ClearQuestSearch()
	end
	return ok
end
