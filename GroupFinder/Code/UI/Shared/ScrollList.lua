local _, GF = ...

GF.UI = GF.UI or {}

local Adapter = {}
Adapter.__index = Adapter
GF.UI.ScrollList = Adapter

local function runtimeReady()
	return type(CreateScrollBoxListLinearView) == "function"
		and type(CreateDataProvider) == "function"
		and ScrollUtil
		and type(ScrollUtil.InitScrollBoxListWithScrollBar) == "function"
end

function Adapter.IsAvailable()
	return runtimeReady() == true
end

local function retainPositionToken(enabled)
	if enabled ~= true then
		return nil
	end
	if ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition ~= nil then
		return ScrollBoxConstants.RetainScrollPosition
	end
	return true
end

local function createListView(options)
	local insets = options.padding
	local view
	if type(insets) == "table" then
		view = CreateScrollBoxListLinearView(
			insets[1] or 0,
			insets[2] or 0,
			insets[3] or 0,
			insets[4] or 0,
			insets[5] or 0
		)
	else
		view = CreateScrollBoxListLinearView()
	end

	if type(options.extentCalculator) == "function" then
		view:SetElementExtentCalculator(options.extentCalculator)
	elseif tonumber(options.rowHeight) then
		view:SetElementExtent(tonumber(options.rowHeight))
	end

	if type(options.elementInitializer) == "function" then
		view:SetElementInitializer(options.frameType or "Frame", options.elementInitializer)
	end
	return view
end

local function placeScrollBar(scrollBox, scrollBar, options)
	local gap = tonumber(options.barOffsetX)
	if gap == nil then
		gap = GF.CONTENT_SCROLLBAR_OFFSET_X or 9
	end
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", gap, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", gap, 0)
	scrollBar:SetFrameLevel(scrollBox:GetFrameLevel() + 10)
end

local function prepareScrollBar(scrollBar, options)
	if options.keepNativeScrollBar ~= true
		and GF.UI.StripMinimalScrollBarSteppers
	then
		GF.UI.StripMinimalScrollBarSteppers(scrollBar)
	end
	if scrollBar.SetHideIfUnscrollable then
		local hideWhenIdle = options.hideIfUnscrollable
		if hideWhenIdle == nil then
			hideWhenIdle = true
		end
		scrollBar:SetHideIfUnscrollable(hideWhenIdle == true)
	end
	scrollBar:Show()
end

function Adapter.Create(parent, options)
	if not parent or not runtimeReady() then
		return nil
	end
	options = options or {}

	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	scrollBox:SetClipsChildren(true)
	local scrollBar = CreateFrame(
		"EventFrame",
		nil,
		options.barParent or parent,
		"MinimalScrollBar"
	)
	placeScrollBar(scrollBox, scrollBar, options)
	prepareScrollBar(scrollBar, options)

	local view = createListView(options)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	return setmetatable({
		scrollBox = scrollBox,
		scrollBar = scrollBar,
		view = view,
		assignedKey = options.assignedKey,
		dataProvider = nil,
	}, Adapter)
end

function Adapter:GetScrollBox()
	return self.scrollBox
end

function Adapter:GetScrollBar()
	return self.scrollBar
end

function Adapter:ClearAllPoints()
	if self.scrollBox then
		self.scrollBox:ClearAllPoints()
	end
end

function Adapter:SetPoint(...)
	if self.scrollBox then
		self.scrollBox:SetPoint(...)
	end
end

function Adapter:AnchorContentScroll(parent)
	if not (self.scrollBox and parent) then
		return
	end
	self.scrollBox:ClearAllPoints()
	self.scrollBox:SetPoint(
		"TOPLEFT",
		parent,
		"TOPLEFT",
		GF.CONTENT_SCROLL_INSET_L or 0,
		0
	)
	if GF.UI.AnchorContentScrollBottomRight then
		GF.UI.AnchorContentScrollBottomRight(self.scrollBox, parent)
	end
end

function Adapter:SetElements(elements, options)
	if not self.scrollBox or type(CreateDataProvider) ~= "function" then
		return nil
	end
	options = options or {}
	local source = type(elements) == "table" and elements or {}
	local provider = CreateDataProvider(source)
	self.dataProvider = provider
	self.scrollBox:SetDataProvider(
		provider,
		retainPositionToken(options.retainScroll)
	)
	return provider
end

function Adapter:ForEachFrame(visitor)
	if type(visitor) == "function"
		and self.scrollBox
		and self.scrollBox.ForEachFrame
	then
		self.scrollBox:ForEachFrame(visitor)
	end
end

function Adapter:FindFrameByPredicate(predicate)
	if type(predicate) ~= "function"
		or not self.scrollBox
		or not self.scrollBox.FindFrameByPredicate
	then
		return nil
	end
	return self.scrollBox:FindFrameByPredicate(predicate)
end

function Adapter:FindFrameByKey(key)
	local field = self.assignedKey
	if field == nil or key == nil then
		return nil
	end
	return self:FindFrameByPredicate(function(_, elementData)
		return type(elementData) == "table" and elementData[field] == key
	end)
end

function Adapter:GetLayoutWidth()
	local width = self.scrollBox and tonumber(self.scrollBox:GetWidth()) or 0
	return math.max(1, math.floor(width or 0))
end

function Adapter:RetainScrollPosition()
	if not (self.scrollBox and self.dataProvider) then
		return
	end
	local retain = retainPositionToken(true)
	if self.scrollBox.Rebuild then
		self.scrollBox:Rebuild(retain)
	else
		self.scrollBox:SetDataProvider(self.dataProvider, retain)
	end
end

function Adapter:ScrollToBegin()
	if self.scrollBox and self.scrollBox.ScrollToBegin then
		self.scrollBox:ScrollToBegin()
	end
end

function Adapter:GetElementData(frame)
	if frame and frame.GetElementData then
		return frame:GetElementData()
	end
	return nil
end
