local _, GF = ...

GF.UI = GF.UI or {}

local ScrollList = {}
GF.UI.ScrollList = ScrollList

local function scrollBoxReady()
	return CreateScrollBoxListLinearView
		and ScrollUtil
		and ScrollUtil.InitScrollBoxListWithScrollBar
end

function ScrollList.IsAvailable()
	return scrollBoxReady()
end

function ScrollList.Create(parent, opts)
	if not scrollBoxReady() then
		return nil
	end
	opts = opts or {}

	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	scrollBox:SetClipsChildren(true)

	local barParent = opts.barParent or parent
	local offsetX = opts.barOffsetX
	if offsetX == nil then
		offsetX = GF.CONTENT_SCROLLBAR_OFFSET_X or 9
	end

	local scrollBar = CreateFrame("EventFrame", nil, barParent, "MinimalScrollBar")
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", offsetX, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", offsetX, 0)
	scrollBar:SetFrameLevel(scrollBox:GetFrameLevel() + 10)
	if not opts.keepNativeScrollBar then
		GF.UI.StripMinimalScrollBarSteppers(scrollBar)
	end
	if scrollBar.SetHideIfUnscrollable then
		scrollBar:SetHideIfUnscrollable(true)
	end
	scrollBar:Show()

	local view
	local pad = opts.padding
	if pad then
		view = CreateScrollBoxListLinearView(pad[1], pad[2], pad[3], pad[4], pad[5])
	else
		view = CreateScrollBoxListLinearView()
	end

	if opts.extentCalculator then
		view:SetElementExtentCalculator(opts.extentCalculator)
	elseif opts.rowHeight then
		view:SetElementExtent(opts.rowHeight)
	end

	if opts.elementInitializer then
		view:SetElementInitializer(opts.frameType or "Frame", opts.elementInitializer)
	end

	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	local sl = setmetatable({
		scrollBox = scrollBox,
		scrollBar = scrollBar,
		view = view,
		assignedKey = opts.assignedKey,
		dataProvider = nil,
	}, { __index = ScrollList })

	return sl
end

function ScrollList:GetScrollBox()
	return self.scrollBox
end

function ScrollList:GetScrollBar()
	return self.scrollBar
end

function ScrollList:ClearAllPoints()
	if self.scrollBox then
		self.scrollBox:ClearAllPoints()
	end
end

function ScrollList:SetPoint(...)
	if self.scrollBox then
		self.scrollBox:SetPoint(...)
	end
end

function ScrollList:AnchorContentScroll(parent)
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", parent, "TOPLEFT", GF.CONTENT_SCROLL_INSET_L or 0, 0)
	GF.UI.AnchorContentScrollBottomRight(self.scrollBox, parent)
end

function ScrollList:SetElements(elements, opts)
	opts = opts or {}
	if not self.scrollBox then
		return
	end

	local list = elements or {}
	if not CreateDataProvider then
		return
	end
	local provider = CreateDataProvider(list)
	local retainScroll = opts.retainScroll
		and (ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition or true)

	self.dataProvider = provider
	self.scrollBox:SetDataProvider(provider, retainScroll)
end

function ScrollList:ForEachFrame(fn)
	if self.scrollBox and self.scrollBox.ForEachFrame and fn then
		self.scrollBox:ForEachFrame(fn)
	end
end

function ScrollList:FindFrameByPredicate(pred)
	if self.scrollBox and self.scrollBox.FindFrameByPredicate and pred then
		return self.scrollBox:FindFrameByPredicate(pred)
	end
	return nil
end

function ScrollList:FindFrameByKey(key)
	if not self.assignedKey or key == nil then
		return nil
	end
	local field = self.assignedKey
	return self:FindFrameByPredicate(function(_, elementData)
		return elementData and elementData[field] == key
	end)
end

function ScrollList:GetLayoutWidth()
	local w = self.scrollBox and self.scrollBox:GetWidth()
	return math.max(1, math.floor(w or 1))
end

function ScrollList:RetainScrollPosition()
	if not self.scrollBox then
		return
	end
	local retain = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition or true
	if self.scrollBox.Rebuild and self.dataProvider then
		self.scrollBox:Rebuild(retain)
	elseif self.dataProvider then
		self.scrollBox:SetDataProvider(self.dataProvider, retain)
	end
end

function ScrollList:ScrollToBegin()
	if self.scrollBox and self.scrollBox.ScrollToBegin then
		self.scrollBox:ScrollToBegin()
	end
end

function ScrollList:GetElementData(frame)
	if frame and frame.GetElementData then
		return frame:GetElementData()
	end
	return nil
end
