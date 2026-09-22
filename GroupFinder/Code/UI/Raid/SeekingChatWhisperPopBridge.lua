local _, GF = ...

-- WhisperPop's notification is independent of Blizzard's tellTimer. Scope the
-- optional sound handoff to its synchronous incoming event, never its database
-- preference, message collection or the global sound APIs.
local Bridge = {}
GF.RaidSeekingChatWhisperPopBridge = Bridge

function Bridge:Prepare(event, message, sender, ...)
	if event ~= "CHAT_MSG_WHISPER" then return nil end
	local contact, id = self.chat:GetIncomingAlertContact(message, sender, select(9, ...))
	if contact then return self.alerts:Prepare(contact, id) end
end

function Bridge:Install()
	local addon = WhisperPop
	if not self.chat or type(addon) ~= "table" or type(addon.OnNewMessage) ~= "function" then return end
	local list = addon.list
	if not list or not list.GetScript or not list.SetScript or (list.IsForbidden and list:IsForbidden())
		or (list.IsProtected and list:IsProtected()) then return end
	local originalEvent, originalNotice = list:GetScript("OnEvent"), addon.OnNewMessage
	if type(originalEvent) ~= "function" then return end
	local installed = self.installed
	if installed and installed.list == list and originalEvent == installed.event and originalNotice == installed.notice then return end
	local activeReceipt
	local function onEvent(frame, event, ...)
		local previous = activeReceipt
		local ok, receipt = pcall(self.Prepare, self, event, ...)
		activeReceipt = ok and receipt or nil
		-- Always run WhisperPop's own message storage, unread marks and UI.
		local succeeded, result = pcall(originalEvent, frame, event, ...)
		activeReceipt = previous
		if not succeeded then error(result, 0) end
		return result
	end
	local function onNotice(target, inform, ...)
		if target == addon and not inform and activeReceipt and activeReceipt.live then
			local ok, played = pcall(self.alerts.Play, self.alerts, activeReceipt)
			if ok and played then return end
		end
		-- Ordinary/Battle.net whispers, missing IDs and failed replacement keep
		-- the original notification, including the user's WhisperPop setting.
		return originalNotice(target, inform, ...)
	end
	list:SetScript("OnEvent", onEvent)
	addon.OnNewMessage = onNotice
	self.installed = { list = list, event = onEvent, notice = onNotice }
end

function Bridge:Init(chat, alerts)
	self.chat, self.alerts = chat, alerts
	pcall(self.Install, self)
end

function Bridge:OnAddonLoaded(name)
	if name == "WhisperPop" then pcall(self.Install, self) end
end
