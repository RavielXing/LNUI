local _, GF = ...

-- Preserve native text, links, reply targets and window routing. Only a native
-- AddMessage that actually displayed this incoming line may skip its tell sound.
local Bridge = {}
Bridge.__index = Bridge
GF.RaidSeekingChatSoundBridge = Bridge
local P = GF.RaidSeekingProtocol

local function accessible(value)
	return not GF.Compat or GF.Compat.IsAccessibleValue(value)
end
local function secure(object, key)
	return type(issecurevariable) == "function" and not not issecurevariable(object, key)
end
function Bridge:IsViewingConversation(key)
	local main = GF.MainFrame
	if not main then return false end
	local shown
	if main.IsUserVisible then shown = main:IsUserVisible()
	else shown = main.frame and main.frame:IsShown() end
	if not shown then return false end
	local view = GF.RaidSeekingPanel and GF.RaidSeekingPanel.chat
	return view and view:IsViewingConversation(key) or false
end
function Bridge:CheckFrame(frame)
	if not accessible(frame) or not frame or (frame.IsForbidden and frame:IsForbidden()) then return false end
	if frame.CanBeAccessedInContext and not frame:CanBeAccessedInContext() then return false end
	if not accessible(frame.tellTimer) or (frame.tellTimer ~= nil and type(frame.tellTimer) ~= "number") then return false end
	if not accessible(frame.AddMessage) or type(frame.AddMessage) ~= "function" then return false end
	local state = self.frames[frame]
	if state and frame.AddMessage == state.addMessage then return true end
	-- Chat log/formatting addons legitimately wrap both AddMessage and the
	-- event entry points. The native filter + matching event/line arguments
	-- establish the delivery path; equality with a mixin method does not.
	-- If another addon wraps the method later, attach to the current chain.
	-- Nested post-hooks are harmless: OnDisplayed consumes pending only once.
	state = state or {}
	hooksecurefunc(frame, "AddMessage", function(target, _, _, _, _, _, _, _, event, args)
		local ok = pcall(self.OnDisplayed, self, target, event, args)
		if not ok and state.pending then state.pending.blocked = true; state.pending = nil end
	end)
	state.addMessage = frame.AddMessage
	self.frames[frame] = state
	return true
end
function Bridge:CanReplace()
	if not self.installed or not ChatFrameMixin or not ChatFrameUtil or not FloatingChatFrameMixin
		or type(CHAT_FRAMES) ~= "table" or #CHAT_FRAMES == 0
		or type(GetTime) ~= "function" or type(PlaySound) ~= "function"
		or not secure(_G, "PlaySound") or not secure(ChatFrameMixin, "MessageEventHandler")
		or ChatFrameMixin.MessageEventHandler ~= self.messageHandler
		or ChatFrameUtil.ProcessMessageEventFilters ~= self.processFilters
		or not secure(ChatFrameUtil, "ProcessMessageEventFilters") then return false end
	for _, name in ipairs(CHAT_FRAMES) do
		local frame = _G[name]
		if not accessible(frame) or not frame or not frame.IsEventRegistered then return false end
		local registered = frame:IsEventRegistered("CHAT_MSG_WHISPER")
		if not accessible(registered) then return false end
		if registered and not self:CheckFrame(frame) then return false end
	end
	return true
end
function Bridge:Filter(frame, event, message, sender, ...)
	if event ~= "CHAT_MSG_WHISPER" then return false end
	local ok, supported = pcall(self.CheckFrame, self, frame)
	if not ok or not supported then return false end
	local contact, id = self.chat:GetIncomingAlertContact(message, sender, select(9, ...))
	if contact then
		local receipt = self.alerts:Prepare(contact, id)
		if receipt and receipt.live then self.frames[frame].pending = receipt end
	end
	-- Always leave the original text and every event argument untouched.
	return false
end
function Bridge:OnDisplayed(frame, event, args)
	local state = self.frames[frame]
	local receipt = state and state.pending
	if not receipt or not receipt.live or not accessible(event) or event ~= "CHAT_MSG_WHISPER"
		or not accessible(args) or type(args) ~= "table" then return end
	local id = P.Integer(args[11], 1, 9007199254740991)
	local sender = self.chat:NormalizeName(args[2])
	if id ~= receipt.id or not sender or sender:lower() ~= receipt.name:lower() then return end
	state.pending = nil
	if not accessible(frame.tellTimer) or (frame.tellTimer ~= nil and type(frame.tellTimer) ~= "number") then
		receipt.blocked = true
		return
	end
	local now = GetTime()
	if self.alerts:Play(receipt) then
		-- This is after routing/filtering and actual AddMessage, immediately
		-- before Blizzard's tellTimer check. Its normal +300 update still runs.
		-- A window which rejected the line never reaches here and is untouched.
		if not frame.tellTimer or now > frame.tellTimer then frame.tellTimer = now + 1 end
	end
end
function Bridge:ClearPending()
	for _, state in pairs(self.frames) do state.pending = nil end
end
function Bridge:Init(chat)
	if chat.alerts or not GF.RaidSeekingChatAlerts then return end
	local bridge = setmetatable({ chat = chat, frames = setmetatable({}, { __mode = "k" }) }, Bridge)
	local alerts = GF.RaidSeekingChatAlerts.New(chat, bridge)
	chat.alerts, bridge.alerts = alerts, alerts
	if type(hooksecurefunc) ~= "function" or not ChatFrameMixin or not FloatingChatFrameMixin
		or not ChatFrameUtil or type(ChatFrameUtil.AddMessageEventFilter) ~= "function"
		or not secure(ChatFrameMixin, "MessageEventHandler") then return end
	bridge.messageHandler = ChatFrameMixin.MessageEventHandler
	bridge.processFilters = ChatFrameUtil.ProcessMessageEventFilters
	bridge.callback = function(...)
		-- An optional sound enhancement cannot interrupt native chat rendering.
		local ok = pcall(bridge.Filter, bridge, ...)
		if not ok then
			for _, receipt in ipairs(alerts.pending) do receipt.blocked = true end
			bridge:ClearPending()
		end
		return false
	end
	local ok = pcall(ChatFrameUtil.AddMessageEventFilter, "CHAT_MSG_WHISPER", bridge.callback)
	bridge.installed = ok
	if GF.RaidSeekingChatWhisperPopBridge then GF.RaidSeekingChatWhisperPopBridge:Init(chat, alerts) end
end
