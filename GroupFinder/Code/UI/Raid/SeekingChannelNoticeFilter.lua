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

function Filter:Process(frame, event, notice, _, _, _, _, _, _, channelIndex, channelName)
	if event ~= EVENT and event ~= USER_EVENT and event ~= TEXT_EVENT and not MEMBER_EVENTS[event] then return false end
	local transport = GF.RaidSeekingTransport
	if not transport or transport.Native.Locked() then return false end
	if not accessible(channelName) or not accessible(channelIndex)
		or channelName ~= transport.CHANNEL
	then return false end
	-- Channel text and member notices only affect display. Keep subscriptions
	-- intact, without inspecting text/senders or touching CHAT_MSG_ADDON traffic.
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
