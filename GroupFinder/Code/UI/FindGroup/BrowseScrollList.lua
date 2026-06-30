local _, GF = ...

local BrowseScrollList = GF.BrowseScrollList or {}
GF.BrowseScrollList = BrowseScrollList

local function browseRowHeight()
	if GF.GetListRowH then
		return GF.GetListRowH()
	end
	return GF.LIST_ROW_H or 32
end

local function makeResultElement(resultID, index)
	return {
		resultID = resultID,
		dataIndex = index,
	}
end

function BrowseScrollList.BuildElements(resultIDs)
	local elements = {}
	if type(resultIDs) ~= "table" then
		return elements
	end
	for index = 1, #resultIDs do
		elements[index] = makeResultElement(resultIDs[index], index)
	end
	return elements
end

local function ensureBrowseRow(row)
	local rowModule = GF.ListRow
	if rowModule and rowModule.EnsureRow then
		rowModule:EnsureRow(row)
	end
end

local function bindBrowseRow(row, elementData, panel)
	local rowModule = GF.ListRow
	if rowModule and rowModule.BindElement then
		rowModule:BindElement(row, elementData, panel, { deferRoles = true })
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
		bindBrowseRow(row, elementData, panel)
	end, panel, false)
end

function BrowseScrollList.Create(panel, parent, opts)
	opts = opts or {}
	local scrollList = GF.UI.ScrollList.Create(parent, {
		rowHeight = browseRowHeight(),
		assignedKey = "resultID",
		barParent = opts.barParent or parent,
		keepNativeScrollBar = true,
		frameType = "BUTTON",
		elementInitializer = ensureBrowseRow,
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
		if rowModule and rowModule.LayoutOnly then
			rowModule:LayoutOnly(row, layoutW)
		end
	end)
end
