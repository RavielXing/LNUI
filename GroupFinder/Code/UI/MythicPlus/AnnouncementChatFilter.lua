local _, GF = ...

GF.MythicPlusAnnouncementChatFilter = GF.MythicPlusAnnouncementChatFilter or {}
local Filter = GF.MythicPlusAnnouncementChatFilter
local CHANNELS = {
	CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
	CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
	CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
}

local function canReadFont(frame)
	if issecretvalue and issecretvalue(frame) then return false end
	if canaccessvalue and not canaccessvalue(frame) then return false end
	if not frame then return false end
	if frame.CanBeAccessedInContext then return frame:CanBeAccessedInContext() end
	return not (frame.IsForbidden and frame:IsForbidden())
end

function Filter:Process(frame, event, message, sender, ...)
	local channel = CHANNELS[event]
	local identity = GF.MythicPlusAnnouncementIdentity
	if not channel or not identity or not CreateSimpleTextureMarkup
		or not GF.ADDON_CHAT_LOGO_TEXTURE then return false end
	local matched = identity:MatchMessage(message, sender, channel, select(9, ...))
	if not matched then return false end
	local size = 14
	if canReadFont(frame) then
		local ok, _, fontSize = pcall(function() return frame:GetFont() end)
		if ok and not (issecretvalue and issecretvalue(fontSize))
			and (not canaccessvalue or canaccessvalue(fontSize))
			and type(fontSize) == "number" then size = fontSize end
	end
	size = math.max(1, math.min(64, math.floor(size * GF.ADDON_CHAT_LOGO_SCALE + 0.5)))
	local logo = CreateSimpleTextureMarkup(GF.ADDON_CHAT_LOGO_TEXTURE, size, size, 0, 0)
	return false, logo .. " " .. message, sender, ...
end

function Filter:Init()
	if self.initialized then return end
	local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter
		or ChatFrame_AddMessageEventFilter
	if type(addFilter) ~= "function" then return end
	self.callback = self.callback or function(...) return self:Process(...) end
	for event in pairs(CHANNELS) do addFilter(event, self.callback) end
	self.initialized = true
end
