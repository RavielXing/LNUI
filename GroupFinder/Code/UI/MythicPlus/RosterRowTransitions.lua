local _, GF = ...

-- Presentation-only snapshots: retiring entries never return to the services.
local Transitions = {}
GF.MythicPlusRosterRowTransitions = Transitions
local Controller = {}
Controller.__index = Controller

local function copy(entry)
	local result = {}
	for key, value in pairs(entry) do result[key] = value end
	return result
end

local function target(state, alpha)
	if state.target == alpha then return end
	state.from, state.target, state.elapsed = state.alpha, alpha, 0
end

function Controller:BindRow(row, entry)
	local state = self.states[entry.elementKey]
	row:SetAlpha(state and state.alpha or 1)
end

function Controller:Paint()
	if self.page.scrollList then
		self.page.scrollList:ForEachFrame(function(row)
			if row._gfData then self:BindRow(row, row._gfData) end
		end)
	end
end

function Controller:Publish()
	local elements = {}
	for _, key in ipairs(self.order) do
		local state = self.states[key]
		local entry = copy(state.data)
		entry._gfRosterRetiring = state.target == 0 or nil
		elements[#elements + 1] = entry
	end
	if self.page.scrollList then
		self.page.scrollList:SetElements(elements, { retainScroll = true, retainFrames = true })
	end
	self.page.emptyText:SetShown(#elements == 0)
end

function Controller:Start()
	local pending = false
	for _, state in pairs(self.states) do
		if state.alpha ~= state.target then pending = true; break end
	end
	self.driver:SetScript("OnUpdate", pending and self.onUpdate or nil)
end

function Controller:Tick(elapsed)
	local removed = false
	for key, state in pairs(self.states) do
		if state.alpha ~= state.target then
			state.elapsed = state.elapsed + elapsed
			local duration = state.target == 1 and self.style.fadeInDuration or self.style.fadeOutDuration
			local p = math.min(1, state.elapsed / duration)
			local eased = p * p * (3 - 2 * p)
			state.alpha = p == 1 and state.target or state.from + (state.target - state.from) * eased
		end
		if state.target == 0 and state.alpha == 0 then
			self.states[key], removed = nil, true
		end
	end
	if removed then
		local order = {}
		for _, key in ipairs(self.order) do
			if self.states[key] then order[#order + 1] = key end
		end
		self.order = order
		self:Publish()
	end
	self:Paint()
	self:Start()
end

function Controller:SetElements(elements)
	local visible = self.page.frame:IsVisible()
	local states, order = {}, {}
	for _, entry in ipairs(elements) do
		local key = entry.elementKey
		local state = self.states[key] or { alpha = visible and 0 or 1 }
		state.data = copy(entry)
		target(state, 1)
		if not visible then state.alpha = 1 end
		states[key], order[#order + 1] = state, key
	end
	-- Hold departing rows at their previous slots until their fade completes.
	-- Existing identities retain their progress through sorting and refreshes.
	if visible then
		for index, key in ipairs(self.order) do
			local state = self.states[key]
			if not states[key] and state.alpha > 0 then
				target(state, 0)
				states[key] = state
				table.insert(order, math.min(index, #order + 1), key)
			end
		end
	end
	self.states, self.order = states, order
	self:Publish()
	self:Start()
end

function Controller:Finish()
	self.driver:SetScript("OnUpdate", nil)
	local order, removed = {}, false
	for _, key in ipairs(self.order) do
		local state = self.states[key]
		if state.target == 0 then
			self.states[key], removed = nil, true
		else
			state.alpha, state.from, state.elapsed = 1, 1, 0
			order[#order + 1] = key
		end
	end
	self.order = order
	if removed then self:Publish() end
	self:Paint()
end

function Transitions.Create(page)
	local self = setmetatable({ page = page, states = {}, order = {},
		style = GF.MYTHIC_PLUS_ROSTER_ROW_TRANSITION_STYLE,
		driver = CreateFrame("Frame", nil, page.frame) }, Controller)
	self.onUpdate = function(_, elapsed) self:Tick(elapsed) end
	page.frame:HookScript("OnHide", function() self:Finish() end)
	page.frame:HookScript("OnShow", function()
		for _, state in pairs(self.states) do
			state.alpha, state.from, state.target, state.elapsed = 0, 0, 1, 0
		end
		self:Paint()
		self:Start()
	end)
	return self
end
