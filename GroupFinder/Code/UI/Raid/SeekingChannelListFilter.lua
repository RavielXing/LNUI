local _, GF = ...

-- Keep Blizzard's channel IDs, button pools and selection data intact. Only
-- collapse the rendered communication-channel row after its native setup.
local Filter = {}
GF.RaidSeekingChannelListFilter = Filter

local function accessible(value)
	return not GF.Compat or GF.Compat.IsAccessibleValue(value)
end

local function writable(frame)
	return accessible(frame) and frame
		and not (frame.IsForbidden and frame:IsForbidden())
		and not (frame.IsProtected and frame:IsProtected())
		and not (frame.CanBeAccessedInContext and not frame:CanBeAccessedInContext())
end

local function isTarget(button)
	if not writable(button) or type(button.GetChannelName) ~= "function"
		or type(button.GetCategory) ~= "function" or type(button.ChannelSupportsText) ~= "function"
		or type(button.ChannelIsCommunity) ~= "function" then return nil end
	local name, category = button:GetChannelName(), button:GetCategory()
	local text, community = button:ChannelSupportsText(), button:ChannelIsCommunity()
	if not accessible(name) or not accessible(category) or not accessible(text) or not accessible(community)
		or type(name) ~= "string" or type(category) ~= "string" then return nil end
	return GF.RaidSeekingTransport and name == GF.RaidSeekingTransport.CHANNEL
		and category == "CHANNEL_CATEGORY_CUSTOM" and text == true and not community
end

local function restoreHeight(button, record)
	if record.height and writable(button) then
		button:SetHeight(record.height)
		record.height = nil
	end
end

function Filter:UpdateRow(button, record)
	if not writable(button) then return end
	if isTarget(button) then
		local height = button:GetHeight()
		if not accessible(height) or type(height) ~= "number" then return end
		record.height = record.height or height
		button:SetHeight(0)
		button:Hide()
	else
		restoreHeight(button, record)
	end
end

local function hook(record, key, object, method, callback)
	if record[key] then return true end
	if type(object[method]) ~= "function" then return false end
	record[key] = pcall(hooksecurefunc, object, method, function(...)
		-- An optional UI adaptation must never break the native update chain.
		pcall(callback, ...)
	end)
	return record[key]
end

function Filter:AttachRow(state, button)
	if not writable(button) or type(button.GetHeight) ~= "function"
		or type(button.SetHeight) ~= "function" or type(button.Hide) ~= "function" then return end
	local record = state.rows[button]
	if not record then record = {}; state.rows[button] = record end
	-- Reset must restore geometry before the pool reuses this frame for another
	-- channel. Never release/remove a native pool entry or edit list.buttons.
	if not hook(record, "reset", button, "Reset", function(row) restoreHeight(row, record) end) then return end
	if not hook(record, "update", button, "Update", function(row) self:UpdateRow(row, record) end) then return end
	self:UpdateRow(button, record)
end

function Filter:UpdateRoster(state, fresh)
	if not writable(state.roster) or not writable(state.list) then return end
	local selected = state.list:GetSelectedChannelButton()
	if isTarget(selected) then
		local record = state.rows[selected]
		if not record or record.height == nil then return end
		local shown = state.roster:IsShown()
		if not accessible(shown) then return end
		if shown then state.rosterHidden = true; state.roster:Hide() end
	elseif fresh and selected and isTarget(selected) == false and state.rosterHidden then
		-- Wait for native content to refresh before restoring the roster, so the
		-- previous hidden channel's title and member menu cannot flash on screen.
		state.rosterHidden = nil
		state.roster:Show()
	end
end

function Filter:Install()
	if not self.enabled or type(hooksecurefunc) ~= "function" then return end
	local frame = ChannelFrame
	if not writable(frame) then return end
	local list, roster = frame.ChannelList, frame.ChannelRoster
	if not writable(list) or not writable(roster) or type(list.GetSelectedChannelButton) ~= "function"
		or type(roster.IsShown) ~= "function" or type(roster.Hide) ~= "function" or type(roster.Show) ~= "function"
	then return end
	local state = self.state
	if not state or state.list ~= list or state.roster ~= roster then
		state = { list = list, roster = roster, rows = setmetatable({}, { __mode = "k" }) }
		self.state = state
	end
	-- This instance hook runs after native Setup and before native UpdateScrollBar
	-- measures the rows. Blizzard still owns ordering, scrolling and selection.
	local selectionReady = hook(state, "selectionHook", list, "SetSelectedChannel", function()
		if state.ready then self:UpdateRoster(state, false) end
	end)
	local rosterReady = hook(state, "rosterHook", roster, "Update", function()
		if state.ready then self:UpdateRoster(state, true) end
	end)
	if not selectionReady or not rosterReady then return end
	if not hook(state, "addHook", list, "AddTextChannelButton", function(target)
		if not state.ready then return end
		local buttons = target.buttons
		if accessible(buttons) and type(buttons) == "table" then self:AttachRow(state, buttons[#buttons]) end
	end) then return end
	state.ready = true
	-- Also cover a channel UI that was already constructed before allowed startup.
	local buttons = list.buttons
	if accessible(buttons) and type(buttons) == "table" then
		for _, button in ipairs(buttons) do
			if isTarget(button) then self:AttachRow(state, button) end
		end
	end
	self:UpdateRoster(state, false)
end

function Filter:Init()
	self.enabled = true
	pcall(self.Install, self)
end

function Filter:OnAddonLoaded(name)
	if name == "Blizzard_Channels" then pcall(self.Install, self) end
end
