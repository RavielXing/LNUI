local _, GF = ...

GF.UI = GF.UI or {}

local ScrollList = {}
ScrollList.__index = ScrollList
GF.UI.ScrollList = ScrollList

local function hasScrollBoxRuntime()
	return CreateScrollBoxListLinearView
		and ScrollUtil
		and ScrollUtil.InitScrollBoxListWithScrollBar
end

function ScrollList.IsAvailable()
	return hasScrollBoxRuntime()
end

local function defaultScrollBarOffset()
	return GF.CONTENT_SCROLLBAR_OFFSET_X or 9
end

local function attachScrollBar(scrollBox, scrollBar, offsetX)
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", offsetX, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", offsetX, 0)
	scrollBar:SetFrameLevel(scrollBox:GetFrameLevel() + 10)
end

local function configureScrollBar(scrollBar, opts)
	if not opts.keepNativeScrollBar and GF.UI.StripMinimalScrollBarSteppers then
		GF.UI.StripMinimalScrollBarSteppers(scrollBar)
	end
	if scrollBar.SetHideIfUnscrollable then
		local hide = opts.hideIfUnscrollable
		if hide == nil then
			hide = true
		end
		scrollBar:SetHideIfUnscrollable(hide)
	end
	scrollBar:Show()
end

local function createScrollRegions(parent, opts)
	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	scrollBox:SetClipsChildren(true)

	local barParent = opts.barParent or parent
	local scrollBar = CreateFrame("EventFrame", nil, barParent, "MinimalScrollBar")
	local offsetX = opts.barOffsetX
	if offsetX == nil then
		offsetX = defaultScrollBarOffset()
	end
	attachScrollBar(scrollBox, scrollBar, offsetX)
	configureScrollBar(scrollBar, opts)
	return scrollBox, scrollBar
end

local function createLinearView(opts)
	local pad = opts.padding
	if pad then
		return CreateScrollBoxListLinearView(pad[1], pad[2], pad[3], pad[4], pad[5])
	end
	return CreateScrollBoxListLinearView()
end

local function configureView(view, opts)
	if opts.extentCalculator then
		view:SetElementExtentCalculator(opts.extentCalculator)
	elseif opts.rowHeight then
		view:SetElementExtent(opts.rowHeight)
	end

	if opts.elementInitializer then
		view:SetElementInitializer(opts.frameType or "Frame", opts.elementInitializer)
	end
end

local function scrollRetainFlag(enabled)
	if not enabled then
		return nil
	end
	return ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition or true
end

function ScrollList.Create(parent, opts)
	if not hasScrollBoxRuntime() then
		return nil
	end
	opts = opts or {}

	local scrollBox, scrollBar = createScrollRegions(parent, opts)
	local view = createLinearView(opts)
	configureView(view, opts)

	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	return setmetatable({
		scrollBox = scrollBox,
		scrollBar = scrollBar,
		view = view,
		assignedKey = opts.assignedKey,
		dataProvider = nil,
	}, ScrollList)
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
	local retainScroll = scrollRetainFlag(opts.retainScroll)

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
	local retain = scrollRetainFlag(true)
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
