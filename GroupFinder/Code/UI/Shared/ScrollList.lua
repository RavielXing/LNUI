local _, GF = ...

GF.UI = GF.UI or {}

-- GF's single adapter around Blizzard's ScrollBox API. Business pages provide
-- row identity and rendering callbacks; this owner handles native frames,
-- providers, stable viewport anchoring, and no other page state.
local VirtualList = {}
VirtualList.__index = VirtualList

GF.UI.VirtualList = VirtualList
GF.UI.ScrollList = VirtualList -- compatibility for existing GF page owners

local function nativeScrollBoxAvailable()
	return type(CreateScrollBoxListLinearView) == "function"
		and type(CreateDataProvider) == "function"
		and type(ScrollUtil) == "table"
		and type(ScrollUtil.InitScrollBoxListWithScrollBar) == "function"
end

function VirtualList.IsAvailable()
	return nativeScrollBoxAvailable()
end

local function retainedPositionArgument(shouldRetain)
	if shouldRetain ~= true then
		return nil
	end
	local constants = ScrollBoxConstants
	if constants and constants.RetainScrollPosition ~= nil then
		return constants.RetainScrollPosition
	end
	return true
end

local function createLinearView(config)
	local padding = config.padding
	local view
	if type(padding) == "table" then
		view = CreateScrollBoxListLinearView(
			padding[1] or 0,
			padding[2] or 0,
			padding[3] or 0,
			padding[4] or 0,
			padding[5] or 0
		)
	else
		view = CreateScrollBoxListLinearView()
	end

	if type(config.extentCalculator) == "function" then
		view:SetElementExtentCalculator(config.extentCalculator)
	else
		local fixedExtent = tonumber(config.rowHeight)
		if fixedExtent then
			view:SetElementExtent(fixedExtent)
		end
	end

	if type(config.elementFactory) == "function" then
		view:SetElementFactory(config.elementFactory)
	elseif type(config.elementInitializer) == "function" then
		view:SetElementInitializer(
			config.frameType or "Frame",
			config.elementInitializer
		)
	end
	return view
end

local function createNativeFrames(parent, config)
	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	scrollBox:SetClipsChildren(true)
	if config.showScrollBar == false then
		return scrollBox
	end

	local scrollBar = CreateFrame(
		"EventFrame",
		nil,
		config.barParent or parent,
		"MinimalScrollBar"
	)
	local horizontalGap = tonumber(config.barOffsetX)
		or GF.CONTENT_SCROLLBAR_OFFSET_X
		or 9
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", horizontalGap, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", horizontalGap, 0)
	scrollBar:SetFrameLevel(scrollBox:GetFrameLevel() + 10)

	if GF.UI.ApplyCommonScrollBarSkin then
		GF.UI.ApplyCommonScrollBarSkin(scrollBar)
	elseif config.keepNativeScrollBar ~= true
		and GF.UI.StripMinimalScrollBarSteppers
	then
		GF.UI.StripMinimalScrollBarSteppers(scrollBar)
	end
	if scrollBar.SetHideIfUnscrollable then
		local hideIfUnscrollable = config.hideIfUnscrollable
		if hideIfUnscrollable == nil then
			hideIfUnscrollable = true
		end
		scrollBar:SetHideIfUnscrollable(hideIfUnscrollable == true)
	end
	scrollBar:Show()
	return scrollBox, scrollBar
end

function VirtualList.Create(parent, options)
	if not parent or not nativeScrollBoxAvailable() then
		return nil
	end
	local config = type(options) == "table" and options or {}
	local scrollBox, scrollBar = createNativeFrames(parent, config)
	local view = createLinearView(config)
	if scrollBar then
		ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	else
		-- Native ScrollBox owns wheel input even without a visible scrollbar.
		scrollBox:Init(view)
	end
	local edgeFadeLength = tonumber(config.edgeFadeLength) or 0
	if edgeFadeLength > 0 then
		-- Native Update applies these gradients to the fixed viewport after
		-- scrolling, resizing and provider changes. Use hidden UI units rather
		-- than the native percentage ramp so even very long lists fade by 24px.
		scrollBox.CalculateEdgeFade = function(box)
			local range = box:GetDerivedScrollRange()
			local offset = math.max(0, math.min(range, box:GetDerivedScrollOffset()))
			return math.min(1, offset / edgeFadeLength),
				math.min(1, (range - offset) / edgeFadeLength)
		end
		scrollBox:SetFlattensRenderLayers(true)
		scrollBox:SetEdgeFadeLength(edgeFadeLength)
		scrollBox:SetShadowsShown(false, false)
		scrollBox:ApplyEdgeFade(scrollBox:CalculateEdgeFade())
	end
	if config.smoothWheel == true and GF.UI.BindSmoothScrollBoxWheelScrolling then
		GF.UI.BindSmoothScrollBoxWheelScrolling(scrollBox, scrollBar, config.rowHeight)
	end

	return setmetatable({
		scrollBox = scrollBox,
		scrollBar = scrollBar,
		view = view,
		assignedKey = config.assignedKey,
		dataProvider = nil,
	}, VirtualList)
end

local function cancelSmoothWheel(list)
	if list.scrollBox and list.scrollBox._gfSmoothWheelActive
		and GF.UI.CancelSmoothWheelScrolling
	then
		GF.UI.CancelSmoothWheelScrolling(list.scrollBox)
	end
end

function VirtualList:GetScrollBox()
	return self.scrollBox
end

function VirtualList:GetScrollBar()
	return self.scrollBar
end

-- Share the transition between ScrollBox lists and page-owned ScrollFrames.
-- Callers may provide geometry-based overflow/input policies for a ScrollFrame.
function GF.UI.BindDynamicScrollBar(box, bar, options)
	if not box or not bar then return end
	if box._gfDynamicScrollBar then return box._gfDynamicScrollBar end
	local state = { progress = 0, options = options }
	box._gfDynamicScrollBar = state
	local controls = { bar:GetTrack(), bar:GetThumb(), bar:GetBackStepper(), bar:GetForwardStepper() }
	bar._gfHideIfUnscrollable = nil
	bar:SetHideIfUnscrollable(false)

	local function isScrollAllowed()
		if options.isScrollAllowed then return options.isScrollAllowed() end
		return box:IsScrollAllowed()
	end

	local function apply(progress)
		state.applying = true
		state.progress = progress
		local insetProgress = progress
		if options.reserveGutter == true then
			insetProgress = 1
		elseif options.animateInset == false then
			insetProgress = state.target or 0
		end
		if state.insetProgress ~= insetProgress then
			state.insetProgress = insetProgress
			options.onInsetChanged(options.gutter * insetProgress)
		end
		local interactive = state.target == 1 and progress == 1
			and box:IsVisible() and isScrollAllowed()
		-- SetScrollAllowed would propagate to ScrollBox and disable its wheel.
		-- Gate only the bar's hit regions during the transition.
		for _, control in ipairs(controls) do control:EnableMouse(interactive) end
		bar:EnableMouseWheel(interactive)
		if not interactive then bar:UnregisterUpdate() end
		bar:SetAlpha(progress)
		bar:SetShown(progress > 0 or state.target == 1)
		state.applying = nil
	end

	local function stop()
		if state.driver then state.driver:SetScript("OnUpdate", nil) end
		state.transition, state.target = nil, nil
		apply(0)
	end

	local function tick(_, elapsed)
		local transition = state.transition
		if not transition then return end
		transition.elapsed = transition.elapsed + math.max(0, elapsed)
		local fraction = math.min(1, transition.elapsed / options.duration)
		local eased = fraction * fraction * (3 - 2 * fraction)
		local progress = transition.from + (transition.target - transition.from) * eased
		if fraction == 1 then
			progress = transition.target
			state.transition = nil
			state.driver:SetScript("OnUpdate", nil)
		end
		apply(progress)
		-- Width-dependent content can change height during the inset callback.
		state.Refresh()
	end

	local function refresh()
		if state.applying or not box:IsVisible() then return end
		local scrollable
		if options.isScrollable then
			scrollable = options.isScrollable()
		else
			scrollable = box:GetDerivedScrollRange() > options.overflowEpsilon
		end
		local target = scrollable and 1 or 0
		if state.target ~= target then
			state.target = target
			if state.progress ~= target then
				state.transition = { from = state.progress, target = target, elapsed = 0 }
				if not state.driver then state.driver = CreateFrame("Frame", nil, box) end
				state.driver:SetScript("OnUpdate", tick)
			else
				state.transition = nil
				if state.driver then state.driver:SetScript("OnUpdate", nil) end
			end
		end
		apply(state.progress)
	end

	state.Refresh, state.Stop = refresh, stop
	box:HookScript("OnShow", refresh)
	box:HookScript("OnHide", stop)
	apply(0)
	refresh()
	return state
end

-- Lists whose row heights do not depend on width can reveal a right gutter.
-- Heavy row views may reserve it or opt out of width animation, keeping the fade.
function VirtualList:BindDynamicScrollBar(options)
	local box, bar = self.scrollBox, self.scrollBar
	if not box or not bar or self.dynamicScrollBar then return end
	local state = GF.UI.BindDynamicScrollBar(box, bar, options)
	self.dynamicScrollBar = state
	box:RegisterCallback(BaseScrollBoxEvents.OnScroll, state.Refresh, state)
	box:RegisterCallback(BaseScrollBoxEvents.OnSizeChanged, state.Refresh, state)
	box:RegisterCallback(BaseScrollBoxEvents.OnAllowScrollChanged, state.Refresh, state)
end

function VirtualList:ClearAllPoints()
	local frame = self.scrollBox
	if frame then
		frame:ClearAllPoints()
	end
end

-- Content lists share the settings/management scrollbar geometry. Anchor the
-- bar to the full host; callers can reserve its gutter before results appear.
-- Alpha frames must not repeat the expensive header and row layout.
function VirtualList:BindDynamicContentScrollBar(parent, onLayoutChanged, options)
	local box, bar = self.scrollBox, self.scrollBar
	if not parent or not box or not bar or self.dynamicScrollBar then return end
	local style = GF.PLAYER_MANAGEMENT_STYLE
	local bottomInset = GF.CONTENT_SCROLL_INSET_B or 0
	self.contentScrollParent, self.contentBottomInset = parent, bottomInset
	bar:ClearAllPoints()
	bar:SetWidth(style.scrollBarWidth)
	bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -style.scrollBarRightInset, 0)
	bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -style.scrollBarRightInset, bottomInset)
	self:BindDynamicScrollBar({
		gutter = style.scrollBarGutter,
		duration = style.scrollBarDuration,
		overflowEpsilon = style.scrollBarOverflowEpsilon,
		animateInset = false,
		reserveGutter = options and options.reserveGutter == true,
		onInsetChanged = function(inset)
			self.contentRightInset = inset
			box:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, self.contentBottomInset)
			if onLayoutChanged then onLayoutChanged(self:GetLayoutWidth()) end
		end,
	})
end

-- Temporary content footers reserve the same space in the viewport and bar.
-- Keep the inset in this owner so a later overflow transition cannot erase it.
function VirtualList:SetContentBottomInset(inset)
	local parent = self.contentScrollParent
	if not parent or self.contentBottomInset == inset then return end
	self.contentBottomInset = inset
	self.scrollBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT",
		-GF.PLAYER_MANAGEMENT_STYLE.scrollBarRightInset, inset)
	self.scrollBox:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(self.contentRightInset or 0), inset)
end

function VirtualList:SetPoint(...)
	local frame = self.scrollBox
	if frame then
		frame:SetPoint(...)
	end
end

function VirtualList:AnchorContentScroll(parent)
	local frame = self.scrollBox
	if not frame or not parent then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint(
		"TOPLEFT",
		parent,
		"TOPLEFT",
		GF.CONTENT_SCROLL_INSET_L or 0,
		0
	)
	if GF.UI.AnchorContentScrollBottomRight then
		GF.UI.AnchorContentScrollBottomRight(frame, parent)
	end
end

local function identityAnchorFor(list)
	local frame = list.scrollBox
	local provider = list.dataProvider
	local identityField = list.assignedKey
	if not (frame and provider and identityField) then
		return nil
	end
	if type(frame.GetDataIndexBegin) ~= "function"
		or type(frame.GetDerivedScrollOffset) ~= "function"
		or type(frame.GetExtentUntil) ~= "function"
		or type(provider.Find) ~= "function"
	then
		return nil
	end

	local firstVisibleIndex = frame:GetDataIndexBegin()
	local element = firstVisibleIndex and provider:Find(firstVisibleIndex)
	local identity = type(element) == "table" and element[identityField] or nil
	if identity == nil then
		return nil
	end
	return {
		key = identity,
		offset = frame:GetDerivedScrollOffset()
			- frame:GetExtentUntil(firstVisibleIndex),
	}
end

function VirtualList:CaptureIdentityAnchor()
	return identityAnchorFor(self)
end

local function findIdentityIndex(provider, field, identity)
	if type(provider.FindIndexByPredicate) ~= "function" then
		return nil
	end
	return provider:FindIndexByPredicate(function(element)
		return type(element) == "table" and element[field] == identity
	end)
end

function VirtualList:RestoreIdentityAnchor(anchor)
	cancelSmoothWheel(self)
	local frame = self.scrollBox
	local provider = self.dataProvider
	local identityField = self.assignedKey
	if type(anchor) ~= "table" or anchor.key == nil then
		return false
	end
	if not (frame and provider and identityField)
		or type(frame.GetExtentUntil) ~= "function"
		or type(frame.ScrollToOffset) ~= "function"
	then
		return false
	end

	local index = findIdentityIndex(provider, identityField, anchor.key)
	if not index then
		return false
	end
	local mode = ScrollBoxConstants
		and ScrollBoxConstants.NoScrollInterpolation
		or true
	frame:ScrollToOffset(
		frame:GetExtentUntil(index) + (tonumber(anchor.offset) or 0),
		mode
	)
	return true
end

-- Reassigning a native provider releases every row, even with retained scroll
-- position. For an unchanged set of unique identities, update its existing
-- element tables and sort in place so visible rows can finish their animations.
local function refreshRetainedFrames(list, elements)
	local provider, field = list.dataProvider, list.assignedKey
	local frame = list.scrollBox
	if not (provider and field and type(elements) == "table")
		or type(provider.GetSize) ~= "function"
		or type(provider.Find) ~= "function"
		or type(provider.Sort) ~= "function"
		or type(frame.ReinitializeFrames) ~= "function"
		or provider:GetSize() ~= #elements
	then
		return false
	end
	local positions, retained = {}, {}
	for index, entry in ipairs(elements) do
		local key = type(entry) == "table" and entry[field] or nil
		if key == nil or positions[key] then return false end
		positions[key] = index
	end
	for index = 1, provider:GetSize() do
		local entry = provider:Find(index)
		local key = type(entry) == "table" and entry[field] or nil
		if key == nil or not positions[key] or retained[key] then return false end
		retained[key] = entry
	end
	for _, entry in ipairs(elements) do
		local current = retained[entry[field]]
		if current ~= entry then
			for key in pairs(current) do current[key] = nil end
			for key, value in pairs(entry) do current[key] = value end
		end
	end
	provider:Sort(function(left, right)
		return positions[left[field]] < positions[right[field]]
	end)
	frame:ReinitializeFrames()
	return true
end

function VirtualList:SetElements(elements, options)
	cancelSmoothWheel(self)
	local frame = self.scrollBox
	if not frame or type(CreateDataProvider) ~= "function" then
		return nil
	end
	local config = type(options) == "table" and options or {}
	local anchor = config.retainIdentity == true
		and identityAnchorFor(self)
		or nil
	if config.retainFrames == true and refreshRetainedFrames(self, elements) then
		if config.retainScroll ~= true then self:ScrollToBegin() end
		if anchor then self:RestoreIdentityAnchor(anchor) end
		return self.dataProvider
	end
	local provider = CreateDataProvider(
		type(elements) == "table" and elements or {}
	)
	self.dataProvider = provider
	frame:SetDataProvider(
		provider,
		retainedPositionArgument(config.retainScroll)
	)
	if anchor then
		self:RestoreIdentityAnchor(anchor)
	end
	return provider
end

function VirtualList:ForEachFrame(visitor)
	local frame = self.scrollBox
	if type(visitor) == "function"
		and frame
		and type(frame.ForEachFrame) == "function"
	then
		frame:ForEachFrame(visitor)
	end
end

function VirtualList:FindFrameByPredicate(predicate)
	local frame = self.scrollBox
	if type(predicate) ~= "function"
		or not frame
		or type(frame.FindFrameByPredicate) ~= "function"
	then
		return nil
	end
	return frame:FindFrameByPredicate(predicate)
end

function VirtualList:FindFrameByKey(identity)
	local field = self.assignedKey
	if field == nil or identity == nil then
		return nil
	end
	return self:FindFrameByPredicate(function(_, element)
		return type(element) == "table" and element[field] == identity
	end)
end

function VirtualList:GetLayoutWidth()
	local frame = self.scrollBox
	local width = frame and type(frame.GetWidth) == "function"
		and tonumber(frame:GetWidth())
		or 0
	return math.max(1, math.floor(width or 0))
end

function VirtualList:RetainScrollPosition()
	cancelSmoothWheel(self)
	local frame = self.scrollBox
	local provider = self.dataProvider
	if not frame or not provider then
		return
	end
	local retain = retainedPositionArgument(true)
	if type(frame.Rebuild) == "function" then
		frame:Rebuild(retain)
	else
		frame:SetDataProvider(provider, retain)
	end
end

-- Animate variable extents without replacing the provider or releasing every
-- visible frame. Native FullUpdate recalculates ranges but does not resize
-- already-acquired frames, so update those through their view first.
function VirtualList:RefreshExtents()
	local frame, view = self.scrollBox, self.view
	if not (frame and view and self.dataProvider) then return end
	local anchor = self:CaptureIdentityAnchor()
	self:ForEachFrame(function(row)
		view:ResizeFrame(frame, row, row:GetOrderIndex(), row:GetElementData())
	end)
	frame:FullUpdate(ScrollBoxConstants.UpdateImmediately)
	if anchor then self:RestoreIdentityAnchor(anchor) end
end

function VirtualList:ScrollToBegin()
	cancelSmoothWheel(self)
	local frame = self.scrollBox
	if frame and type(frame.ScrollToBegin) == "function" then
		frame:ScrollToBegin()
	end
end

function VirtualList:GetElementData(frame)
	if frame and type(frame.GetElementData) == "function" then
		return frame:GetElementData()
	end
	return nil
end
