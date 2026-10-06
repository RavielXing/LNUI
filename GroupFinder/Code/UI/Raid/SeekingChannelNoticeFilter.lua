local _, GF = ...

local Filter = {}
GF.RaidSeekingChannelNoticeFilter = Filter
local NOTICES = { YOU_JOINED = true, YOU_LEFT = true, YOU_CHANGED = true }
local EVENT = "CHAT_MSG_CHANNEL_NOTICE"
local USER_EVENT = "CHAT_MSG_CHANNEL_NOTICE_USER"
local USER_NOTICES = { SET_MODERATOR = true, UNSET_MODERATOR = true, OWNER_CHANGED = true }
local TEXT_EVENT = "CHAT_MSG_CHANNEL"
local MEMBER_EVENTS = { CHAT_MSG_CHANNEL_JOIN = true, CHAT_MSG_CHANNEL_LEAVE = true }
local EVENTS = { EVENT, "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE", TEXT_EVENT, USER_EVENT }

local function accessible(value)
	return not GF.Compat or GF.Compat.IsAccessibleValue(value)
end

local function readableFrame(frame)
	return accessible(frame) and frame
		and not (frame.IsForbidden and frame:IsForbidden())
		and not (frame.CanBeAccessedInContext and not frame:CanBeAccessedInContext())
end

local function finishChannelLeave(frame, channel, channelIndex)
	if not readableFrame(frame) then return false end
	local names, zones = frame.channelList, frame.zoneChannelList
	if not accessible(names) or not accessible(zones)
		or type(names) ~= "table" or type(zones) ~= "table" then return false end
	local matches = {}
	for index, name in pairs(names) do
		if not accessible(index) or not accessible(name) then return false end
		if name == channel then matches[#matches + 1] = index end
	end
	-- The native message handler normally clears these caches after filters.
	-- Preserve that cleanup without changing saved chat-window subscriptions.
	for _, index in ipairs(matches) do names[index], zones[index] = nil, nil end
	local editBox = frame.editBox
	if #matches > 0 and readableFrame(editBox) and type(editBox.UpdateNewcomerEditBoxHint) == "function" then
		editBox:UpdateNewcomerEditBoxHint(channelIndex)
	end
	return true
end

function Filter:DetachChatWindow(frame)
	local transport = GF.RaidSeekingTransport
	if not transport or not readableFrame(frame) or type(frame.RemoveChannel) ~= "function" then return end
	local channel, names, zones = transport.CHANNEL, frame.channelList, frame.zoneChannelList
	if not accessible(names) or type(names) ~= "table"
		or not accessible(zones) or type(zones) ~= "table" then return end
	local attached = false
	for _, name in pairs(names) do
		if not accessible(name) then return end
		if name == channel then attached = true end
	end
	-- A join can update the saved window before its Lua cache is rebuilt.
	if type(GetChatWindowChannels) == "function" and type(frame.GetID) == "function" then
		local ok, id = pcall(frame.GetID, frame)
		if not ok or not accessible(id) or type(id) ~= "number" or id < 1 or id % 1 ~= 0 then return end
		local channels = { pcall(GetChatWindowChannels, id) }
		if not channels[1] then return end
		for index = 2, #channels, 2 do
			if not accessible(channels[index]) then return end
			if channels[index] == channel then attached = true end
		end
	end
	if attached then
		-- This removes only a chat-window display subscription. Native channel
		-- membership and CHAT_MSG_ADDON delivery are independent of this setting.
		pcall(frame.RemoveChannel, frame, channel)
	end
end

function Filter:PrepareChatWindow(frame)
	if not readableFrame(frame) then return end
	self.windowHooks = self.windowHooks or setmetatable({}, { __mode = "k" })
	local hooks = self.windowHooks[frame] or {}
	self.windowHooks[frame] = hooks
	if type(hooksecurefunc) == "function" then
		for _, method in ipairs({ "AddChannel", "RegisterForChannels" }) do
			if not hooks[method] and type(frame[method]) == "function" then
				hooks[method] = pcall(hooksecurefunc, frame, method, function()
					pcall(self.DetachChatWindow, self, frame)
				end)
			end
		end
	end
	self:DetachChatWindow(frame)
end

function Filter:RefreshChatWindows()
	if self.refreshingWindows then return end
	self.refreshingWindows = true
	local function prepare(frame) pcall(self.PrepareChatWindow, self, frame) end
	-- Include hidden windows: they can be shown later without being recreated.
	if type(CHAT_FRAMES) == "table" then
		for _, name in pairs(CHAT_FRAMES) do
			if accessible(name) and type(name) == "string" then prepare(_G[name]) end
		end
	elseif type(FCF_IterateActiveChatWindows) == "function" then
		pcall(FCF_IterateActiveChatWindows, prepare)
	end
	prepare(DEFAULT_CHAT_FRAME)
	self.refreshingWindows = nil
end

function Filter:InitChatWindows()
	self.displayHooks = self.displayHooks or {}
	if type(hooksecurefunc) == "function" then
		local function refresh() self:RefreshChatWindows() end
		for _, name in ipairs({ "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow" }) do
			if not self.displayHooks[name] and type(_G[name]) == "function" then
				self.displayHooks[name] = pcall(hooksecurefunc, name, refresh)
			end
		end
		local native = GF.RaidSeekingTransport and GF.RaidSeekingTransport.Native
		if not self.displayHooks.join and native and type(native.Join) == "function" then
			self.displayHooks.join = pcall(hooksecurefunc, native, "Join", refresh)
		end
	end
	if not self.windowEvents and type(CreateFrame) == "function" then
		local events = CreateFrame("Frame")
		events:RegisterEvent("PLAYER_ENTERING_WORLD")
		events:RegisterEvent("UPDATE_CHAT_WINDOWS")
		events:SetScript("OnEvent", function() self:RefreshChatWindows() end)
		self.windowEvents = events
	end
	self:RefreshChatWindows()
end

function Filter:Process(frame, event, notice, _, _, _, _, _, _, channelIndex, channelName)
	if event ~= EVENT and event ~= USER_EVENT and event ~= TEXT_EVENT and not MEMBER_EVENTS[event] then return false end
	local transport = GF.RaidSeekingTransport
	if not transport then return false end
	-- channelBaseName and channelIndex are NeverSecret in these native events.
	-- Keep display filtering active during boss/keystone chat restrictions;
	-- transport lockdown controls communication, not readable channel identity.
	if not accessible(channelName) or not accessible(channelIndex)
		or channelName ~= transport.CHANNEL
	then return false end
	-- This fallback only affects display, without inspecting text/senders or
	-- touching native channel membership and CHAT_MSG_ADDON traffic.
	if event == TEXT_EVENT or MEMBER_EVENTS[event] then return true end
	-- Role/owner changes use a separate native notice event. Filter only these
	-- routine notices; invites, moderation errors and own-leave cleanup differ.
	if event == USER_EVENT then
		return accessible(notice) and type(notice) == "string" and USER_NOTICES[notice] == true
	end
	if not accessible(notice) or type(notice) ~= "string" or not NOTICES[notice] then return false end
	if notice == "YOU_LEFT" then return finishChannelLeave(frame, channelName, channelIndex) end
	return true
end

function Filter:Init()
	-- Blizzard skips addon message filters when the first payload is secret.
	-- Detach display before combat instead of reading or rewriting that payload.
	self:InitChatWindows()
	if self.initialized then return end
	local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
	if type(addFilter) ~= "function" then return end
	self.callback = self.callback or function(...)
		local ok, hide = pcall(self.Process, self, ...)
		return ok and hide == true
	end
	-- Remain installed for the session: a leave notice can arrive after the
	-- transport has stopped, and native membership can survive a UI reload.
	self.registeredEvents = self.registeredEvents or {}
	local complete = true
	for _, event in ipairs(EVENTS) do
		if not self.registeredEvents[event] then
			self.registeredEvents[event] = pcall(addFilter, event, self.callback)
		end
		if not self.registeredEvents[event] then complete = false end
	end
	self.initialized = complete
end
