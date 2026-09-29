local _, GF = ...

local BrowseScrollList = GF.BrowseScrollList or {}
GF.BrowseScrollList = BrowseScrollList

local ACTION_ELEMENT_KIND = "quick_create"
local CENSORED_DEBUG_ELEMENT_KIND = "censored_debug"
local CURRENT_GROUP_ELEMENT_KIND = "current_group"
local TEAM_LIST_DEBUG_ELEMENT_KIND = "team_list_debug"

local function resultProjectionKey(resultID)
	return "result:" .. tostring(resultID)
end

function BrowseScrollList.GetResultProjectionKey(resultID)
	return resultID ~= nil and resultProjectionKey(resultID) or nil
end

local function browseRowHeight()
	if GF.GetBrowseRowH then
		return GF.GetBrowseRowH()
	end
	return GF.BROWSE_ROW_H or 34
end

local function makeResultElement(resultID, index)
	return {
		resultID = resultID,
		dataIndex = index,
		projectionKey = resultProjectionKey(resultID),
	}
end

local function clearReusableTable(values)
	values = type(values) == "table" and values or {}
	for key in pairs(values) do
		values[key] = nil
	end
	return values
end

local function isActionElement(elementData)
	return type(elementData) == "table"
		and elementData.kind == ACTION_ELEMENT_KIND
end

local function isCensoredDebugElement(elementData)
	return type(elementData) == "table"
		and elementData.kind == CENSORED_DEBUG_ELEMENT_KIND
end

local function isTeamListDebugElement(elementData)
	return type(elementData) == "table"
		and elementData.kind == TEAM_LIST_DEBUG_ELEMENT_KIND
end

local function isDebugEntryElement(elementData)
	return isCensoredDebugElement(elementData)
		or isTeamListDebugElement(elementData)
end

local function isCurrentGroupElement(elementData)
	return type(elementData) == "table"
		and elementData.kind == CURRENT_GROUP_ELEMENT_KIND
end

function BrowseScrollList.BuildCensoredDebugElements(entry, categoryID)
	return {
		{
			kind = CENSORED_DEBUG_ELEMENT_KIND,
			projectionKey = "censored-debug",
			entry = entry,
			categoryID = categoryID,
		},
	}
end

function BrowseScrollList.BuildTeamListDebugElements(entries)
	local elements = {}
	for index, entry in ipairs(entries or {}) do
		local context = entry and entry._gfTeamListTestContext
		if context and context.currentGroup == true then
			elements[#elements + 1] = {
				kind = CURRENT_GROUP_ELEMENT_KIND,
				projectionKey = "team-list-debug:" .. tostring(entry.debugCase or index),
				entry = entry,
				displayName = entry.info and entry.info.name,
				displayComment = entry.info and entry.info.comment,
				displayCommentProvided = true,
				displayVoiceChatProvided = true,
				displayVoiceShown = false,
				displayVoiceShownProvided = true,
				categoryID = entry.categoryID,
				debugPreview = true,
			}
		else
			elements[#elements + 1] = {
				kind = TEAM_LIST_DEBUG_ELEMENT_KIND,
				projectionKey = "team-list-debug:" .. tostring(entry and entry.debugCase or index),
				entry = entry,
				categoryID = entry and entry.categoryID,
				debugPreview = true,
			}
		end
	end
	return elements
end

local function actionRowMinimumHeight()
	return tonumber(GF.BROWSE_RESULT_ACTION_ROW_MIN_HEIGHT) or 36
end

function BrowseScrollList.CalculateResultActionExtent(visibleExtent, resultCount)
	local minimumHeight = actionRowMinimumHeight()
	local availableHeight = tonumber(visibleExtent) or 0
	local count = math.max(0, math.floor(tonumber(resultCount) or 0))
	if availableHeight <= 0 then
		return minimumHeight, false
	end
	local extent = math.max(
		minimumHeight,
		availableHeight - 2 * (GF.LFG_LIST_EDGE_PADDING or 2) - (count * browseRowHeight())
	)
	return extent, extent > minimumHeight
end

function BrowseScrollList.GetResultActionButtonOffsetY(rowExtent, isExpanded)
	if isExpanded == nil then
		isExpanded = (tonumber(rowExtent) or 0) > actionRowMinimumHeight()
	end
	if isExpanded == true then
		return tonumber(GF.BROWSE_RESULT_ACTION_SHORT_OFFSET_Y) or 10
	end
	return 0
end

function BrowseScrollList.BuildElements(resultIDs, action, cache, currentGroupElement)
	cache = type(cache) == "table" and cache or {}
	local elements = clearReusableTable(cache.elements)
	local byResultID = type(cache.byResultID) == "table"
		and cache.byResultID or {}
	local freeElements = type(cache.freeElements) == "table"
		and cache.freeElements or {}
	local currentResultIDs = clearReusableTable(cache.currentResultIDs)
	local uniqueResultIDs = clearReusableTable(cache.uniqueResultIDs)
	local diagnostics = GF.SearchMemoryDiagnostics
	local diagnosticActive = diagnostics and diagnostics.current ~= nil
	local wrappersCreated, wrappersReused, wrappersPruned = 0, 0, 0
	local generation = (tonumber(cache.generation) or 0) + 1
	cache.elements = elements
	cache.byResultID = byResultID
	cache.freeElements = freeElements
	cache.currentResultIDs = currentResultIDs
	cache.uniqueResultIDs = uniqueResultIDs
	cache.generation = generation
	local hiddenResultIDs = isCurrentGroupElement(currentGroupElement)
		and currentGroupElement.hiddenResultIDs or nil
	for index = 1, type(resultIDs) == "table" and #resultIDs or 0 do
		local resultID = resultIDs[index]
		if resultID ~= nil
			and not (hiddenResultIDs and hiddenResultIDs[resultID])
			and currentResultIDs[resultID] == nil
		then
			currentResultIDs[resultID] = index
			uniqueResultIDs[#uniqueResultIDs + 1] = resultID
		end
	end
	for resultID, element in pairs(byResultID) do
		if not currentResultIDs[resultID] then
			byResultID[resultID] = nil
			element.resultID = nil
			element.dataIndex = nil
			element.projectionKey = nil
			element._gfBrowseProjection = nil
			freeElements[#freeElements + 1] = element
			if diagnosticActive then
				wrappersPruned = wrappersPruned + 1
			end
		end
	end
	if type(resultIDs) ~= "table" then
		if cache.actionElement then
			cache.actionElement.kind = nil
			cache.actionElement.action = nil
			cache.actionElement.resultCount = nil
		end
		if diagnosticActive and diagnostics.RecordWrappers then
			diagnostics:RecordWrappers(0, 0, wrappersPruned)
		end
		return elements, cache
	end
	local elementOffset = 0
	if isCurrentGroupElement(currentGroupElement) then
		local currentElement = cache.currentGroupElement or {}
		currentElement.kind = CURRENT_GROUP_ELEMENT_KIND
		currentElement.projectionKey = currentGroupElement.projectionKey
		currentElement.revision = currentGroupElement.revision
		currentElement.resultID = currentGroupElement.resultID
		currentElement.entry = currentGroupElement.entry
		currentElement.displayName = currentGroupElement.displayName
		currentElement.displayComment = currentGroupElement.displayComment
		currentElement.displayVoiceChat = currentGroupElement.displayVoiceChat
		currentElement.displayVoiceShown = currentGroupElement.displayVoiceShown
		currentElement.displayCommentProvided =
			currentGroupElement.displayCommentProvided
		currentElement.displayVoiceChatProvided =
			currentGroupElement.displayVoiceChatProvided
		currentElement.displayVoiceShownProvided =
			currentGroupElement.displayVoiceShownProvided
		currentElement.categoryID = currentGroupElement.categoryID
		currentElement.hiddenResultIDs = currentGroupElement.hiddenResultIDs
		currentElement._gfBrowseProjection = generation
		cache.currentGroupElement = currentElement
		elements[1] = currentElement
		elementOffset = 1
	elseif cache.currentGroupElement then
		cache.currentGroupElement.kind = nil
		cache.currentGroupElement.entry = nil
		cache.currentGroupElement.displayName = nil
		cache.currentGroupElement.displayComment = nil
		cache.currentGroupElement.displayVoiceChat = nil
		cache.currentGroupElement.displayVoiceShown = nil
		cache.currentGroupElement.displayCommentProvided = nil
		cache.currentGroupElement.displayVoiceChatProvided = nil
		cache.currentGroupElement.displayVoiceShownProvided = nil
		cache.currentGroupElement.hiddenResultIDs = nil
	end
	for index = 1, #uniqueResultIDs do
		local resultID = uniqueResultIDs[index]
		local element = byResultID[resultID]
		if not element then
			local freeIndex = #freeElements
			element = freeElements[freeIndex]
			if element then
				freeElements[freeIndex] = nil
			else
				element = makeResultElement(resultID, index)
			end
			byResultID[resultID] = element
			if diagnosticActive then
				if freeIndex > 0 then
					wrappersReused = wrappersReused + 1
				else
					wrappersCreated = wrappersCreated + 1
				end
			end
		else
			if diagnosticActive then
				wrappersReused = wrappersReused + 1
			end
		end
		element.resultID = resultID
		element.dataIndex = currentResultIDs[resultID]
		element.projectionKey = resultProjectionKey(resultID)
		element._gfBrowseProjection = generation
		elements[index + elementOffset] = element
	end
	if diagnosticActive and diagnostics.RecordWrappers then
		diagnostics:RecordWrappers(
			wrappersCreated, wrappersReused, wrappersPruned)
	end
	if type(action) == "table" then
		local actionElement = cache.actionElement or {}
		actionElement.kind = ACTION_ELEMENT_KIND
		actionElement.projectionKey = "action:" .. tostring(action.kind or "quick_create")
		actionElement.action = action
		actionElement.resultCount = #uniqueResultIDs
		cache.actionElement = actionElement
		elements[#elements + 1] = actionElement
	elseif cache.actionElement then
		cache.actionElement.kind = nil
		cache.actionElement.projectionKey = nil
		cache.actionElement.action = nil
		cache.actionElement.resultCount = nil
	end
	return elements, cache
end

local function ensureBrowseRow(row)
	local rowModule = GF.ListRow
	if rowModule and rowModule.EnsureRow then
		rowModule:EnsureRow(row)
	end
end

local RESULT_ROW_INTRO_SEPARATOR = "\031"

local function resultRowIntroContext(panel)
	local presenter = GF.BrowsePresenter
	if presenter and presenter.GetResultIntroContext then
		return presenter:GetResultIntroContext(panel)
	end
	return tostring(panel and panel._searchToken or "")
		.. RESULT_ROW_INTRO_SEPARATOR
		.. tostring(panel and panel.activeSearchKey or "")
end

function BrowseScrollList.ConsumeResultRowIntro(panel, resultID)
	if not panel or resultID == nil then
		return false, nil
	end
	local context = resultRowIntroContext(panel)
	if panel._gfResultRowIntroContext ~= context
		or type(panel._gfAnimatedResultIDs) ~= "table"
	then
		panel._gfResultRowIntroContext = context
		panel._gfAnimatedResultIDs = {}
	end
	local seen = panel._gfAnimatedResultIDs
	local identity = context
		.. RESULT_ROW_INTRO_SEPARATOR
		.. tostring(resultID)
	if seen[resultID] then
		return false, identity
	end
	seen[resultID] = true
	return true, identity
end

function BrowseScrollList.ResetResultRowIntro(row)
	if not row then
		return false
	end
	local hadIdentity = row._gfResultRowIntroIdentity ~= nil
	if hadIdentity and GF.UI and GF.UI.StopPopupOpenAnimation then
		GF.UI.StopPopupOpenAnimation(row)
	end
	row._gfResultRowIntroIdentity = nil
	return hadIdentity
end

function BrowseScrollList.PlayResultRowIntro(row, elementData, panel)
	local resultID = row and row.resultID
	if row and (row._gfExpiredRetiring == true
		or (panel and panel.IsExpiredResultRetiring
			and panel:IsExpiredResultRetiring(resultID)))
	then
		BrowseScrollList.ResetResultRowIntro(row)
		return false
	end
	if resultID == nil
		or (elementData and elementData.resultID ~= nil
			and elementData.resultID ~= resultID)
	then
		BrowseScrollList.ResetResultRowIntro(row)
		return false
	end
	local shouldPlay, identity =
		BrowseScrollList.ConsumeResultRowIntro(panel, resultID)
	if row._gfResultRowIntroIdentity ~= identity then
		BrowseScrollList.ResetResultRowIntro(row)
		row._gfResultRowIntroIdentity = identity
	end
	if not shouldPlay
		or not (GF.UI and GF.UI.PlayPopupOpenAnimation)
	then
		return false
	end
	return GF.UI.PlayPopupOpenAnimation(row, { preset = "resultRow" })
end

function BrowseScrollList.BindResultRow(row, elementData, panel, opts)
	opts = opts or {}
	if row then
		row._gfCensoredDebugPreview = nil
		row._gfDebugResultPreview = nil
	end
	local rowModule = GF.ListRow
	if rowModule and rowModule.BindElement then
		local bound = rowModule:BindElement(
			row, elementData, panel, { deferRoles = true })
		if bound == true then
			local presenter = GF.BrowsePresenter
			if presenter and presenter.ClearFailedResultBinding then
				presenter:ClearFailedResultBinding(
					panel,
					elementData and elementData.resultID,
					elementData
				)
			elseif panel and panel.ClearFailedResultBinding then
				panel:ClearFailedResultBinding(
					elementData and elementData.resultID, elementData)
			end
			if row and row.Show then
				row:Show()
			end
			BrowseScrollList.PlayResultRowIntro(row, elementData, panel)
			return true
		end
	end
	BrowseScrollList.ResetResultRowIntro(row)
	if rowModule and rowModule.DetachRow then
		rowModule:DetachRow(row)
	end
	if row and row.Hide then
		row:Hide()
	end
	-- The initialized frame has already consumed its fixed ScrollBox extent.
	-- Hiding stale recycled content is necessary, but leaving the element in
	-- the provider forever would expose that extent as a blank row.  Defer one
	-- authoritative retry outside the initialization callback; a persistent
	-- failure is then retired by the presenter with its identity anchor kept.
	if opts.suppressRecovery ~= true then
		local presenter = GF.BrowsePresenter
		if presenter and presenter.QueueFailedResultBinding then
			presenter:QueueFailedResultBinding(panel, row, elementData)
		elseif panel and panel.QueueFailedResultBinding then
			panel:QueueFailedResultBinding(row, elementData)
		end
	end
	return false
end

function BrowseScrollList.BindCurrentGroupRow(row, elementData, panel, opts)
	opts = opts or {}
	BrowseScrollList.ResetResultRowIntro(row)
	if row then
		row._gfCensoredDebugPreview = nil
		row._gfDebugResultPreview = nil
	end
	local rowModule = GF.ListRow
	if rowModule and rowModule.BindCurrentGroupProjection then
		local bound = rowModule:BindCurrentGroupProjection(
			row, elementData, panel, { deferRoles = true })
		if bound == true then
			if elementData and elementData.debugPreview == true then
				row._gfDebugResultPreview = true
			end
			if row and row.Show then
				row:Show()
			end
			return true
		end
	end
	if rowModule and rowModule.DetachRow then
		rowModule:DetachRow(row)
	end
	if row and row.Hide then
		row:Hide()
	end
	return false
end

local function bindDebugEntryRow(row, elementData, panel)
	BrowseScrollList.ResetResultRowIntro(row)
	local rowModule = GF.ListRow
	local entry = elementData and elementData.entry
	if not (row and rowModule and rowModule.SetData and entry and entry.info) then
		return false
	end
	local measuredWidth = panel and panel.scrollList
		and panel.scrollList:GetLayoutWidth() or 0
	local layoutW = measuredWidth > 0 and measuredWidth
		or panel and panel._lastLayoutW or 400
	if panel then
		panel._lastLayoutW = layoutW
	end
	-- Debug fixtures reuse the same physical ScrollBox rows as the live list.
	-- A row that previously represented the current-group projection must become
	-- an ordinary result before SetData paints or resolves any type/tooltip state.
	row._gfCurrentGroupProjection = nil
	row._gfCurrentGroupElement = nil
	row._gfProjectionKey = elementData.projectionKey
	row._gfCensoredDebugPreview = nil
	row._gfDebugResultPreview = nil
	row:SetWidth(layoutW)
	local bound = rowModule:SetData(
		row,
		0,
		elementData.categoryID,
		entry,
		{
			deferRoles = false,
			layoutW = layoutW,
		})
	if bound ~= true then
		if rowModule.DetachRow then
			rowModule:DetachRow(row)
		end
		row:Hide()
		return false
	end
	row.resultIndex = nil
	row.resultID = nil
	row._gfCensoredDebugPreview = isCensoredDebugElement(elementData)
		and true or nil
	row._gfDebugResultPreview = true
	row:Show()
	return true
end

function BrowseScrollList.BindCensoredDebugRow(row, elementData, panel)
	return bindDebugEntryRow(row, elementData, panel)
end

function BrowseScrollList.BindTeamListDebugRow(row, elementData, panel)
	return bindDebugEntryRow(row, elementData, panel)
end

local function layoutActionButton(row)
	local button = row and row.actionButton
	if not button then
		return
	end
	local rowExtent = row.GetHeight and row:GetHeight() or 0
	local elementData = row._gfBrowseActionElement
	local isExpanded = row._gfBrowseActionExpanded
	if type(elementData) == "table" then
		isExpanded = elementData.actionRowExpanded == true
	end
	button:ClearAllPoints()
	button:SetPoint(
		"CENTER",
		row,
		"CENTER",
		0,
		BrowseScrollList.GetResultActionButtonOffsetY(
			rowExtent,
			isExpanded
		)
	)
end

local function ensureActionRow(row)
	if row.actionButton then
		layoutActionButton(row)
		return
	end
	row._gfBrowseActionRow = true
	local button = GF.UI.CreatePanelButton(
		row,
		"",
		GF.BROWSE_EMPTY_ACTION_MIN_WIDTH or 120
	)
	button:SetScript("OnClick", function()
		local panel = row._gfBrowsePanel
		local presenter = GF.BrowsePresenter
		if presenter and presenter.ExecuteResultAction then
			presenter:ExecuteResultAction(panel, row._gfBrowseAction)
		elseif panel and panel.ExecuteResultAction then
			panel:ExecuteResultAction(row._gfBrowseAction)
		end
	end)
	row.actionButton = button
	row:HookScript("OnSizeChanged", layoutActionButton)
	layoutActionButton(row)
end

local function bindActionRow(row, elementData, panel)
	ensureActionRow(row)
	row._gfBrowsePanel = panel
	row._gfBrowseAction = elementData.action
	row._gfBrowseActionElement = elementData
	row._gfBrowseActionExpanded = elementData.actionRowExpanded == true
	layoutActionButton(row)
	local presenter = GF.BrowsePresenter
	if presenter and presenter.ConfigureActionButton then
		presenter:ConfigureActionButton(
			panel, row.actionButton, elementData.action)
	elseif panel and panel.ConfigureQuickCreateButton then
		panel:ConfigureQuickCreateButton(row.actionButton, elementData.action)
	end
end

local function installRowBinding(scrollList, panel)
	if not scrollList or not ScrollUtil or not ScrollUtil.AddInitializedFrameCallback then
		return
	end
	local scrollBox = scrollList:GetScrollBox()
	if not scrollBox then
		return
	end
	ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, row, elementData)
		if isActionElement(elementData) then
			bindActionRow(row, elementData, panel)
		elseif isCensoredDebugElement(elementData) then
			BrowseScrollList.BindCensoredDebugRow(row, elementData, panel)
		elseif isTeamListDebugElement(elementData) then
			BrowseScrollList.BindTeamListDebugRow(row, elementData, panel)
		elseif isCurrentGroupElement(elementData) then
			BrowseScrollList.BindCurrentGroupRow(row, elementData, panel)
		else
			BrowseScrollList.BindResultRow(row, elementData, panel)
		end
	end, panel, false)
end

function BrowseScrollList.Create(panel, parent, opts)
	opts = opts or {}
	local scrollList
	local listAdapter = assert(
		GF.BrowseVirtualListAdapter,
		"BrowseVirtualListAdapter must load before BrowseScrollList"
	)
	scrollList = listAdapter.Create(parent, {
		rowHeight = browseRowHeight(),
		padding = { GF.LFG_LIST_EDGE_PADDING or 2, GF.LFG_LIST_EDGE_PADDING or 2, 0, 0, 0 },
		edgeFadeLength = GF.LFG_LIST_EDGE_FADE,
		smoothWheel = true,
		extentCalculator = function(_, elementData)
			if isDebugEntryElement(elementData) then
				return browseRowHeight()
			end
			if isActionElement(elementData) then
				local scrollBox = scrollList and scrollList:GetScrollBox()
				local visibleExtent = scrollBox and scrollBox.GetVisibleExtent
					and scrollBox:GetVisibleExtent() or 0
				local extent, isExpanded =
					BrowseScrollList.CalculateResultActionExtent(
					visibleExtent,
					elementData.resultCount
				)
				elementData.actionRowExpanded = isExpanded == true
				return extent
			end
			return browseRowHeight()
		end,
		barParent = opts.barParent or parent,
		keepNativeScrollBar = true,
		elementFactory = function(factory, elementData)
			if isActionElement(elementData) then
				factory("Frame", ensureActionRow)
			else
				factory("Button", ensureBrowseRow)
			end
		end,
	})
	installRowBinding(scrollList, panel)
	return scrollList
end

local function getLayoutWidth(panel)
	local scrollList = panel and panel.scrollList
	if not scrollList then
		return nil
	end
	local width = scrollList:GetLayoutWidth()
	if width <= 0 then
		return panel._lastLayoutW or 400
	end
	return width
end

function BrowseScrollList.RelayoutVisible(panel)
	if not panel or not panel.scrollList then
		return
	end
	local layoutW = getLayoutWidth(panel)
	panel._lastLayoutW = layoutW
	local rowModule = GF.ListRow
	panel.scrollList:ForEachFrame(function(row)
		if not row._gfBrowseActionRow and rowModule and rowModule.LayoutOnly then
			rowModule:LayoutOnly(row, layoutW)
		end
	end)
end
