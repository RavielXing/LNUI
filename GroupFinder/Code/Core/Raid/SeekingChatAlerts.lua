local _, GF = ...

-- Ephemeral native-line receipts, deliberately separate from saved chat history.
-- Both the native display path and our event owner can arrive first.
local Alerts = {}
Alerts.__index = Alerts
GF.RaidSeekingChatAlerts = Alerts
local MAX_RECEIPTS = 128

function Alerts.New(chat, bridge)
	return setmetatable({ chat = chat, bridge = bridge, receipts = {}, order = {}, pending = {} }, Alerts)
end
function Alerts:CanReplace()
	local ok, supported = pcall(self.bridge.CanReplace, self.bridge)
	return ok and supported == true
end
function Alerts:CreateReceipt(contact)
	-- Capture reading intent before insertion/refresh can change selection,
	-- scroll position or unread counts. Every sound owner shares this choice.
	local viewed = self.bridge.IsViewingConversation and self.bridge:IsViewingConversation(contact.key)
	local style = GF.RAID_SEEKING_CHAT_STYLE
	return { name = contact.name, live = true, blocked = not self:CanReplace(),
		soundKitID = viewed and style.viewedIncomingSoundKitID or style.incomingSoundKitID }
end
function Alerts:Prepare(contact, lineID)
	local id = GF.RaidSeekingProtocol.Integer(lineID, 1, 9007199254740991)
	if not id or not contact or contact.ended or contact.recovering then return nil end
	local receipt = self.receipts[id]
	if receipt then return receipt.name == contact.name and receipt or nil end
	if not (C_Timer and type(C_Timer.After) == "function") or #self.pending >= MAX_RECEIPTS then return nil end
	-- An old retained/replayed chat line must never become a fresh notification.
	for _, c in pairs(self.chat.conversations) do
		for _, message in ipairs(c.messages) do
			if message.incoming and message.lineID == id then return nil end
		end
	end
	receipt = self:CreateReceipt(contact)
	receipt.id = id
	self.receipts[id] = receipt
	self.order[#self.order + 1] = id
	if #self.order > MAX_RECEIPTS then self.receipts[table.remove(self.order, 1)] = nil end
	self.pending[#self.pending + 1] = receipt
	if not self.scheduled then
		self.scheduled = true
		local ok = pcall(C_Timer.After, 0, function() self:Flush() end)
		if not ok then
			self.scheduled = nil
			for _, item in ipairs(self.pending) do item.blocked, item.live = true, nil end
			self.pending = {}
		end
	end
	return receipt
end
function Alerts:Receive(contact, message)
	-- Receive runs before insertion, so Prepare can reject historical line IDs.
	local receipt = message.incoming and self:Prepare(contact, message.lineID)
	if receipt then receipt.confirmed = true end
end
function Alerts:Play(receipt)
	if receipt.attempted then return receipt.played == true end
	receipt.attempted = true
	if receipt.blocked or not receipt.live or not self:CanReplace() then return false end
	-- Use the normal UI sound channel and the player's existing volume/mute.
	local ok, played = pcall(PlaySound, receipt.soundKitID)
	receipt.played = ok and played == true
	return receipt.played
end
function Alerts:Flush()
	local pending = self.pending
	self.pending, self.scheduled = {}, nil
	for _, receipt in ipairs(pending) do
		-- If native chat did not display this line, the real event owner still
		-- supplies the notification. Merely filtering/rendering history cannot.
		if receipt.confirmed then self:Play(receipt) end
		receipt.live = nil
	end
	self.bridge:ClearPending()
end
