local _, GF = ...

GF.BrowseScrollList = {}
local BSL = GF.BrowseScrollList

function BSL.BuildElements(resultIDs)
	local elements = {}
	local ids = resultIDs or {}
	for i = 1, #ids do
		elements[i] = {
			resultID = ids[i],
			dataIndex = i,
		}
	end
	return elements
end

function BSL.Create(panel, parent, opts)
	opts = opts or {}
	local lr = GF.ListRow
	local sl = GF.UI.ScrollList.Create(parent, {
		rowHeight = GF.GetListRowH and GF.GetListRowH() or (GF.LIST_ROW_H or 32),
		assignedKey = "resultID",
		barParent = opts.barParent or parent,
		keepNativeScrollBar = true,
		frameType = "BUTTON",
		elementInitializer = function(row, elementData)
			if lr and lr.EnsureRow then
				lr:EnsureRow(row)
			end
		end,
	})

	if sl and ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
		local scrollBox = sl:GetScrollBox()
		if scrollBox then
			ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, row, elementData)
				if lr and lr.BindElement then
					lr:BindElement(row, elementData, panel, { deferRoles = true })
				end
			end, panel, false)
		end
	end

	return sl
end

function BSL.RelayoutVisible(panel)
	if not panel or not panel.scrollList then
		return
	end
	local layoutW = panel.scrollList:GetLayoutWidth()
	if layoutW <= 0 then
		layoutW = panel._lastLayoutW or 400
	end
	panel._lastLayoutW = layoutW
	local lr = GF.ListRow
	panel.scrollList:ForEachFrame(function(row)
		if lr and lr.LayoutOnly then
			lr:LayoutOnly(row, layoutW)
		end
	end)
end
