local _, GF = ...

GF.MythicPlusAnnouncementService = GF.MythicPlusAnnouncementService or {}
local Service = GF.MythicPlusAnnouncementService
local Util = GF.MythicPlusServiceUtil

local MAX_CHAT_MESSAGE_BYTES = 255
local MAX_TACTICAL_ANNOUNCEMENTS =
	GF.MYTHIC_PLUS_TACTICAL_MAX_MESSAGES or 5
local MAX_TACTICAL_INPUT_BYTES =
	GF.MYTHIC_PLUS_TACTICAL_INPUT_MAX_BYTES or 255
local TACTICAL_DEDUPE_SECONDS = 60
-- Keystone inventory changes may be published before the post-run replacement
-- has settled.  These are bounded confirmation windows, not polling loops.
local KEYSTONE_GENERIC_SETTLE_DELAY = 0.75
-- Begin comparing when the run completes, not when reward presentation
-- arrives.  These relative delays produce completion-relative reads at
-- 0.25 / 0.75 / 2.25 / 5.25 / 8.25 / 12.25 seconds.  They are a finite
-- convergence window for the owned-key APIs and bag hyperlink, not polling.
local KEYSTONE_COMPLETION_SETTLE_RETRY_DELAYS = { 0.25, 0.5, 1.5, 3, 3, 4 }
local KEYSTONE_WORLD_RECOVERY_DELAY = 1
local MAX_KEYSTONE_GENERIC_SETTLE_ATTEMPTS = 3
local KEYSTONE_DELIVERY_TIMEOUT = 30
local CHAT_QUEUE_INTERVAL_SECONDS = 0.25

local ASYNC_CHAT_CHANNELS = {
	PARTY = true,
	RAID = true,
	RAID_WARNING = true,
	INSTANCE_CHAT = true,
}

local MANUAL_TACTICAL_CHANNELS = {
	{
		channel = "PARTY",
		labelKey = "SET_MPLUS_TACTICAL_CHANNEL_PARTY",
		fallbackLabel = "Party",
	},
	{
		channel = "RAID",
		labelKey = "SET_MPLUS_TACTICAL_CHANNEL_RAID",
		fallbackLabel = "Raid",
	},
	{
		channel = "INSTANCE_CHAT",
		labelKey = "SET_MPLUS_TACTICAL_CHANNEL_INSTANCE",
		fallbackLabel = "Instance",
	},
	{
		channel = "RAID_WARNING",
		labelKey = "SET_MPLUS_TACTICAL_CHANNEL_RAID_WARNING",
		fallbackLabel = "Raid warning",
	},
}

local MANUAL_TACTICAL_CHANNEL_FALLBACKS = {
	PARTY = { "PARTY", "INSTANCE_CHAT", "RAID" },
	RAID = { "RAID", "INSTANCE_CHAT", "PARTY" },
	INSTANCE_CHAT = {
		"INSTANCE_CHAT", "RAID", "PARTY",
	},
	RAID_WARNING = {
		"RAID_WARNING", "INSTANCE_CHAT", "RAID", "PARTY",
	},
}

local MANUAL_TACTICAL_DEFAULT_PRIORITY = {
	"INSTANCE_CHAT", "RAID", "PARTY",
}

local function normalizeManualTacticalChannel(channel)
	local schema = GF.SettingsSchema
	if schema
		and type(schema.NormalizeManualTacticalChannel) == "function"
	then
		return schema:NormalizeManualTacticalChannel(channel)
	end
	channel = type(channel) == "string" and channel or ""
	for _, definition in ipairs(MANUAL_TACTICAL_CHANNELS) do
		if definition.channel == channel then
			return channel
		end
	end
	return "PARTY"
end

local ANNOUNCEABLE_KEYSTONE_REASONS = {
	BAG_UPDATE = true,
	BAG_UPDATE_DELAYED = true,
	ITEM_CHANGED = true,
	CHALLENGE_MODE_COMPLETED = true,
	CHALLENGE_MODE_COMPLETED_REWARDS = true,
	MYTHIC_PLUS_COMPLETION_RECHECK = true,
	CHALLENGE_MODE_RESET = true,
	INSTANCE_ABANDON_VOTE_FINISHED = true,
	ITEM_DATA_LOAD_RESULT = true,
	GOSSIP_CLOSED = true,
}

local COMPLETION_KEYSTONE_EVENTS = {
	CHALLENGE_MODE_COMPLETED = true,
	CHALLENGE_MODE_COMPLETED_REWARDS = true,
}

local COPY = {
	zhCN = {
		defaultTeleportMessage =
			"已施放[{spell}]，即将前往[{dungeon}]。",
		tacticalStart = "--------------- 战术通报 ---------------",
		tacticalEnd = "--------------- 通报结束 ---------------",
		keystoneUpdated = "钥石已更新：%s",
	},
	zhTW = {
		defaultTeleportMessage =
			"已施放[{spell}]，即將前往[{dungeon}]。",
		tacticalStart = "--------------- 戰術通報 ---------------",
		tacticalEnd = "--------------- 通報結束 ---------------",
		keystoneUpdated = "鑰石已更新：%s",
	},
	enUS = {
		defaultTeleportMessage =
			"Cast [{spell}], heading to [{dungeon}].",
		tacticalStart = "--------------- Tactical Report ---------------",
		tacticalEnd = "--------------- Report End ---------------",
		keystoneUpdated = "Keystone updated: %s",
	},
	ruRU = {
		defaultTeleportMessage =
			"Применено [{spell}], отправляюсь в [{dungeon}].",
		tacticalStart = "--------------- Тактика ---------------",
		tacticalEnd = "--------------- Конец тактики ---------------",
		keystoneUpdated = "Ключ обновлен: %s",
	},
}

local function getCopy()
	local locale = GetLocale and GetLocale() or "enUS"
	return COPY[locale] or COPY.enUS
end

local function now()
	return GetTime and GetTime() or 0
end

local function scheduleKeystoneCallback(delay, callback)
	if not (C_Timer and type(callback) == "function") then
		return false
	end
	if type(C_Timer.After) == "function" then
		local ok = pcall(C_Timer.After, delay, callback)
		return ok
	end
	if type(C_Timer.NewTimer) == "function" then
		local ok, timer = pcall(C_Timer.NewTimer, delay, callback)
		return ok and timer ~= nil
	end
	return false
end

local function getKeystoneIdentity(snapshot)
	if type(snapshot) ~= "table" or snapshot.state ~= "ready" then
		return nil
	end
	local challengeModeID = tonumber(snapshot.challengeModeID)
	local level = tonumber(snapshot.level)
	if not challengeModeID or challengeModeID <= 0
		or not level or level <= 0
	then
		return nil
	end
	-- Retain the full link as well as its visible map/level.  If item data is
	-- late, the unreadable identity is committed quietly and the later complete
	-- link can still produce the one real report.
	local link = type(snapshot.keystoneLink) == "string"
		and snapshot.keystoneLink ~= "" and snapshot.keystoneLink or ""
	return table.concat({
		tostring(challengeModeID),
		tostring(level),
		link:match("|H(keystone:[^|]+)|h") or link,
	}, "\031")
end

local function getCompleteKeystoneIdentity(snapshot)
	local identity = getKeystoneIdentity(snapshot)
	if not identity
		or snapshot.announcementReady == false
		or type(snapshot.keystoneLink) ~= "string"
		or snapshot.keystoneLink == ""
		or not snapshot.keystoneLink:find("|Hkeystone:", 1, true)
	then
		return nil
	end
	return identity
end

local function copyKeystoneSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return nil
	end
	return {
		state = snapshot.state,
		sampleID = snapshot.sampleID,
		announcementReady = snapshot.announcementReady,
		challengeModeID = tonumber(snapshot.challengeModeID),
		level = tonumber(snapshot.level),
		keystoneLink = type(snapshot.keystoneLink) == "string"
			and snapshot.keystoneLink ~= "" and snapshot.keystoneLink or nil,
	}
end

local function notify(owner, reason)
	if Util and Util.Notify then
		Util.Notify(owner, reason)
		return
	end
	for _, callback in ipairs(owner.listeners or {}) do
		pcall(callback, owner, reason)
	end
end

local function normalizeMessage(value, maxBytes)
	value = tostring(value or "")
	value = value:gsub("[%c\r\n]+", " ")
	value = value:match("^%s*(.-)%s*$") or ""
	value = Util.TruncateUtf8(
		value,
		maxBytes or MAX_CHAT_MESSAGE_BYTES
	)
	return value:match("^%s*(.-)%s*$") or ""
end

local function getTacticalAnnouncementLines(value)
	value = tostring(value or "")
	value = value:gsub("\r\n", "\n"):gsub("\r", "\n")
	local lines = {}
	local startAt = 1
	for _ = 1, MAX_TACTICAL_ANNOUNCEMENTS do
		local newlineAt = value:find("\n", startAt, true)
		local line = newlineAt
			and value:sub(startAt, newlineAt - 1)
			or value:sub(startAt)
		lines[#lines + 1] = normalizeMessage(
			line,
			MAX_TACTICAL_INPUT_BYTES
		)
		if not newlineAt then
			break
		end
		startAt = newlineAt + 1
	end
	while #lines > 0 and lines[#lines] == "" do
		table.remove(lines)
	end
	return lines
end

local function normalizeTacticalAnnouncements(value)
	return table.concat(getTacticalAnnouncementLines(value), "\n")
end

local function getMythicPlusDB()
	local mythicPlus
	if GF.GetMythicPlusDB then
		local ok, value = pcall(GF.GetMythicPlusDB)
		if ok and type(value) == "table" then
			mythicPlus = value
		end
	end
	if not mythicPlus then
		local db = GF.GetDB and GF.GetDB() or GF.db
		if type(db) ~= "table" then
			return nil
		end
		db.mythicPlus = type(db.mythicPlus) == "table"
			and db.mythicPlus or {}
		mythicPlus = db.mythicPlus
	end

	mythicPlus.settings = type(mythicPlus.settings) == "table"
		and mythicPlus.settings or {}
	local settings = mythicPlus.settings
	local schema = GF.SettingsSchema
	if schema and type(schema.NormalizeTeleportPromptSettings) == "function" then
		schema:NormalizeTeleportPromptSettings(settings)
	else
		if settings.groupReadyTeleportEnabled == nil then
			settings.groupReadyTeleportEnabled = true
		else
			settings.groupReadyTeleportEnabled =
				settings.groupReadyTeleportEnabled == true
		end
		if settings.teleportFollowEnabled == nil then
			settings.teleportFollowEnabled = false
		else
			settings.teleportFollowEnabled =
				settings.teleportFollowEnabled == true
		end
	end
	if settings.teleportAnnouncementEnabled == nil then
		settings.teleportAnnouncementEnabled = true
	else
		settings.teleportAnnouncementEnabled =
			settings.teleportAnnouncementEnabled == true
	end
	if settings.keystoneAnnouncementEnabled == nil then
		settings.keystoneAnnouncementEnabled = false
	else
		settings.keystoneAnnouncementEnabled =
			settings.keystoneAnnouncementEnabled == true
	end
	settings.manualTacticalChannel =
		normalizeManualTacticalChannel(
			settings.manualTacticalChannel)
	mythicPlus.characterSettings =
		type(mythicPlus.characterSettings) == "table"
			and mythicPlus.characterSettings or {}
	return mythicPlus
end

local function getCurrentCharacterKey()
	if Util and Util.GetUnitFullName then
		local fullName = Util.GetUnitFullName("player")
		if type(fullName) == "string" and fullName ~= "" then
			return fullName
		end
	end
	if GetUnitName then
		local ok, fullName = pcall(GetUnitName, "player", true)
		if ok and type(fullName) == "string" and fullName ~= "" then
			return fullName
		end
	end
	local name = UnitName and UnitName("player")
	local realm = GetRealmName and GetRealmName()
	if type(name) == "string" and name ~= "" then
		return type(realm) == "string" and realm ~= ""
			and (name .. "-" .. realm) or name
	end
	return "_current"
end

local function getCharacterSettings()
	local mythicPlus = getMythicPlusDB()
	if not mythicPlus then
		return nil
	end
	local key = getCurrentCharacterKey()
	local settings = mythicPlus.characterSettings[key]
	if type(settings) ~= "table" then
		settings = {}
		mythicPlus.characterSettings[key] = settings
	end
	if type(settings.teleportAnnouncementText) ~= "string" then
		settings.teleportAnnouncementText =
			type(settings.teleportMessage) == "string"
				and settings.teleportMessage or ""
	end
	if type(settings.tacticalAnnouncements) ~= "table" then
		settings.tacticalAnnouncements = {}
	end
	return settings
end

local function getGroupChannel()
	if IsInRaid and IsInRaid() then
		return "RAID"
	end
	if IsInGroup and LE_PARTY_CATEGORY_INSTANCE
		and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
	then
		return "INSTANCE_CHAT"
	end
	if IsInGroup and IsInGroup() then
		return "PARTY"
	end
	return nil
end

local function getChatSender()
	return C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
end

local function canSendChannelAsynchronously(channel)
	return ASYNC_CHAT_CHANNELS[channel] == true
end

local function isChatMessagingLocked()
	local api = C_ChatInfo
	local reader = type(api) == "table"
		and api.InChatMessagingLockdown or nil
	if type(reader) ~= "function" then
		return false
	end
	local ok, locked = pcall(reader)
	return ok and locked == true
end

local function sendChannelMessage(message, channel)
	message = normalizeMessage(message)
	local sender = getChatSender()
	if message == "" or not (channel and sender)
		or isChatMessagingLocked()
	then
		return false
	end
	local ok = pcall(sender, message, channel)
	return ok == true
end

local drainQueuedChatMessage

local function scheduleQueuedChatMessage(owner)
	if owner._chatMessageTimer ~= nil then
		return true
	end
	local timers = C_Timer
	if type(timers) ~= "table" then
		return false
	end
	local token = {}
	local function resume()
		if owner._chatMessageTimer ~= token then
			return
		end
		owner._chatMessageTimer = nil
		drainQueuedChatMessage(owner)
	end
	owner._chatMessageTimer = token
	if type(timers.NewTimer) == "function" then
		local ok, timer = pcall(
			timers.NewTimer,
			CHAT_QUEUE_INTERVAL_SECONDS,
			resume
		)
		if ok and timer then
			token.timer = timer
			return true
		end
	end
	if type(timers.After) == "function" then
		local ok = pcall(
			timers.After,
			CHAT_QUEUE_INTERVAL_SECONDS,
			resume
		)
		if ok then
			return true
		end
	end
	owner._chatMessageTimer = nil
	return false
end

drainQueuedChatMessage = function(owner)
	local queue = owner and owner._chatMessageQueue
	if type(queue) ~= "table"
		or owner._chatMessageDraining == true
		or owner._chatMessageTimer ~= nil
	then
		return
	end
	owner._chatMessageDraining = true
	while #queue > 0 do
		local entry = queue[1]
		local delivery = entry.keystoneDelivery
		local status = delivery and owner:ValidateKeystoneDelivery(delivery) or "send"
		if status == "drop" then
			table.remove(queue, 1)
		elseif status == "wait" or isChatMessagingLocked() then
			owner._chatMessageDraining = nil
			scheduleQueuedChatMessage(owner)
			return
		else
			local identity = GF.MythicPlusAnnouncementIdentity
			local teleport = entry.teleportDelivery
			local teleportStatus = teleport and identity:BeforeSend(teleport, entry.message, function()
				drainQueuedChatMessage(owner)
			end) or "send"
			if teleportStatus == "wait" then
				owner._chatMessageDraining = nil
				return
			end
			if teleportStatus == "drop" then
				table.remove(queue, 1)
			else
				if teleport then identity:BeforeSubmit(teleport) end
				local submitted = sendChannelMessage(entry.message, entry.channel)
				if teleport then identity:AfterSubmit(teleport, submitted) end
				if delivery then
					delivery.attempts = (delivery.attempts or 0) + 1
					if submitted then
						owner.lastSubmittedKeystoneIdentity = delivery.identity
						owner.lastKeystoneDeliveryOutcome = "submitted"
					elseif delivery.attempts >= 3 then
						owner.lastKeystoneDeliveryOutcome = "failed"
					end
				end
				if submitted or not delivery or delivery.attempts >= 3 then
					table.remove(queue, 1)
				end
				owner._chatMessageDraining = nil
				-- Preserve the shared FIFO cooldown, including between separate batches.
				if scheduleQueuedChatMessage(owner) then
					return
				end
				if delivery and not submitted then
					return
				end
				owner._chatMessageDraining = true
			end
		end
	end
	owner._chatMessageDraining = nil
end

local function queueChannelMessages(owner, messages, channel, keystoneDelivery, teleportAnnouncement)
	if type(owner) ~= "table"
		or type(messages) ~= "table"
		or not channel
		or not canSendChannelAsynchronously(channel)
		or not getChatSender()
		or not keystoneDelivery and isChatMessagingLocked()
	then
		return false, 0
	end
	local pending = {}
	for _, value in ipairs(messages) do
		local message = normalizeMessage(value)
		if message ~= "" then
			pending[#pending + 1] = {
				message = message,
				channel = channel,
				keystoneDelivery = keystoneDelivery,
				teleportDelivery = teleportAnnouncement and GF.MythicPlusAnnouncementIdentity
					and GF.MythicPlusAnnouncementIdentity:CreateDelivery(channel) or nil,
			}
		end
	end
	if #pending == 0 then
		return false, 0
	end
	owner._chatMessageQueue = type(owner._chatMessageQueue) == "table"
		and owner._chatMessageQueue or {}
	for _, entry in ipairs(pending) do
		owner._chatMessageQueue[#owner._chatMessageQueue + 1] = entry
	end
	drainQueuedChatMessage(owner)
	return true, #pending
end

local function queueGroupMessages(owner, messages, teleportAnnouncement)
	return queueChannelMessages(owner, messages, getGroupChannel(), nil, teleportAnnouncement)
end

local function readBoolean(callback, ...)
	if type(callback) ~= "function" then
		return false
	end
	local ok, value = pcall(callback, ...)
	return ok and value == true
end

local function isManualTacticalChannelAvailable(channel)
	local home = LE_PARTY_CATEGORY_HOME
	local instance = LE_PARTY_CATEGORY_INSTANCE
	local inHomeGroup = readBoolean(IsInGroup, home)
	local inHomeRaid = readBoolean(IsInRaid, home)
	local inInstanceGroup = readBoolean(IsInGroup, instance)
	local inAnyRaid = inHomeRaid
		or readBoolean(IsInRaid, instance)
		or readBoolean(IsInRaid)
	if channel == "PARTY" then
		return inHomeGroup and not inHomeRaid
	elseif channel == "RAID" then
		return inHomeRaid
	elseif channel == "INSTANCE_CHAT" then
		return inInstanceGroup
	elseif channel == "RAID_WARNING" then
		if not inAnyRaid then
			return false
		end
		return readBoolean(UnitIsGroupLeader, "player")
			or readBoolean(UnitIsGroupAssistant, "player")
			or readBoolean(UnitIsGroupLeader, "player", home)
			or readBoolean(UnitIsGroupAssistant, "player", home)
			or readBoolean(UnitIsGroupLeader, "player", instance)
			or readBoolean(UnitIsGroupAssistant, "player", instance)
	end
	return false
end

local function currentPlayerName()
	return getCurrentCharacterKey()
end

local function resolveTeleportData(challengeModeID)
	challengeModeID = tonumber(challengeModeID)
	if not challengeModeID then
		return nil, nil
	end
	local dungeon = GF.MythicPlusSeason
		and GF.MythicPlusSeason.GetByChallengeModeID
		and GF.MythicPlusSeason:GetByChallengeModeID(challengeModeID)
	local teleport = GF.MythicPlusTeleportService
		and GF.MythicPlusTeleportService.GetByChallengeModeID
		and GF.MythicPlusTeleportService:GetByChallengeModeID(challengeModeID)
	return dungeon, teleport
end

function Service:AddListener(callback)
	if type(callback) ~= "function" then
		return
	end
	if Util and Util.AddListener then
		Util.AddListener(self, callback)
		return
	end
	self.listeners = self.listeners or {}
	self.listeners[#self.listeners + 1] = callback
end

function Service:IsTeleportFollowEnabled()
	local mythicPlus = getMythicPlusDB()
	return mythicPlus ~= nil
		and mythicPlus.settings.teleportFollowEnabled == true
end

function Service:SetTeleportFollowEnabled(enabled)
	local mythicPlus = getMythicPlusDB()
	if not mythicPlus then
		return false
	end
	enabled = enabled == true
	if mythicPlus.settings.teleportFollowEnabled ~= enabled then
		mythicPlus.settings.teleportFollowEnabled = enabled
		notify(self, "teleport-follow")
	end
	if not enabled then
		local dialog = GF.MythicPlusTeleportDialog
		if dialog and type(dialog.HideFollow) == "function" then
			dialog:HideFollow("setting-disabled")
		end
	end
	if GF.MythicPlusTeleportFollowService
		and GF.MythicPlusTeleportFollowService.RefreshPeerWatcher
	then
		GF.MythicPlusTeleportFollowService:RefreshPeerWatcher(
			"teleport-follow-setting")
	end
	return enabled
end

function Service:IsTeleportAnnouncementEnabled()
	local mythicPlus = getMythicPlusDB()
	return mythicPlus ~= nil
		and mythicPlus.settings.teleportAnnouncementEnabled == true
end

function Service:SetTeleportAnnouncementEnabled(enabled)
	local mythicPlus = getMythicPlusDB()
	if not mythicPlus then
		return false
	end
	enabled = enabled == true
	if mythicPlus.settings.teleportAnnouncementEnabled ~= enabled then
		mythicPlus.settings.teleportAnnouncementEnabled = enabled
		notify(self, "teleport-announcement")
	end
	return enabled
end

function Service:GetDefaultTeleportMessage()
	local L = GF.L or {}
	return L.SET_MPLUS_TELEPORT_MESSAGE_DEFAULT
		or L.MPLUS_TELEPORT_ANNOUNCEMENT_DEFAULT
		or getCopy().defaultTeleportMessage
end

function Service:GetTeleportMessage()
	local settings = getCharacterSettings()
	local value = settings and settings.teleportAnnouncementText
	if type(value) == "string" and value ~= "" then
		return value
	end
	return self:GetDefaultTeleportMessage()
end

function Service:SetTeleportMessage(value)
	local settings = getCharacterSettings()
	if not settings then
		return ""
	end
	local normalized = normalizeMessage(value)
	if normalized == self:GetDefaultTeleportMessage() then
		normalized = ""
	end
	if settings.teleportAnnouncementText ~= normalized then
		settings.teleportAnnouncementText = normalized
		notify(self, "teleport-message")
	end
	return normalized ~= "" and normalized or self:GetDefaultTeleportMessage()
end

function Service:IsKeystoneAnnouncementEnabled()
	local mythicPlus = getMythicPlusDB()
	return mythicPlus ~= nil
		and mythicPlus.settings.keystoneAnnouncementEnabled == true
end

function Service:SetKeystoneAnnouncementEnabled(enabled)
	local mythicPlus = getMythicPlusDB()
	if not mythicPlus then
		return false
	end
	enabled = enabled == true
	if not enabled then
		self.keystoneSettingGeneration = (self.keystoneSettingGeneration or 0) + 1
		self.genericKeystoneTransaction = nil
		self.genericKeystoneTransactionTicket =
			(tonumber(self.genericKeystoneTransactionTicket) or 0) + 1
		self.completionKeystoneTransaction = nil
		self.completionKeystoneTransactionTicket =
			(tonumber(self.completionKeystoneTransactionTicket) or 0) + 1
	end
	if mythicPlus.settings.keystoneAnnouncementEnabled ~= enabled then
		mythicPlus.settings.keystoneAnnouncementEnabled = enabled
		notify(self, "keystone-announcement")
	end
	return enabled
end

function Service:GetTacticalAnnouncement(challengeModeID)
	challengeModeID = tonumber(challengeModeID)
	if not challengeModeID then
		return ""
	end
	local settings = getCharacterSettings()
	local messages = settings and settings.tacticalAnnouncements
	if type(messages) ~= "table" then
		return ""
	end
	local value = messages[tostring(challengeModeID)]
		or messages[challengeModeID]
	return type(value) == "string"
		and normalizeTacticalAnnouncements(value) or ""
end

function Service:SetTacticalAnnouncement(challengeModeID, value)
	challengeModeID = tonumber(challengeModeID)
	if not challengeModeID then
		return ""
	end
	local settings = getCharacterSettings()
	if not settings then
		return ""
	end
	local messages = settings.tacticalAnnouncements
	local key = tostring(challengeModeID)
	local normalized = normalizeTacticalAnnouncements(value)
	local current = normalizeTacticalAnnouncements(messages[key]
		or messages[challengeModeID] or "")
	messages[challengeModeID] = nil
	if normalized == "" then
		messages[key] = nil
	elseif current ~= normalized or messages[key] ~= normalized then
		messages[key] = normalized
	end
	if current ~= normalized then
		notify(self, "tactical-announcement")
	end
	return normalized
end

function Service:GetGroupChannel()
	return getGroupChannel()
end

function Service:IsManualTacticalChannelAvailable(channel)
	return isManualTacticalChannelAvailable(tostring(channel or ""))
end

function Service:GetManualTacticalChannelOptions()
	local L = GF.L or {}
	local options = {}
	for _, definition in ipairs(MANUAL_TACTICAL_CHANNELS) do
		options[#options + 1] = {
			channel = definition.channel,
			label = L[definition.labelKey]
				or definition.fallbackLabel,
		}
	end
	return options
end

function Service:GetManualTacticalChannel()
	local mythicPlus = getMythicPlusDB()
	return normalizeManualTacticalChannel(
		mythicPlus and mythicPlus.settings.manualTacticalChannel
	)
end

function Service:SetManualTacticalChannel(channel)
	local mythicPlus = getMythicPlusDB()
	if not mythicPlus then
		return "PARTY"
	end
	local normalized = normalizeManualTacticalChannel(channel)
	if mythicPlus.settings.manualTacticalChannel ~= normalized then
		mythicPlus.settings.manualTacticalChannel = normalized
		notify(self, "manual-tactical-channel")
	end
	return normalized
end

function Service:ResolveManualTacticalChannel(requestedChannel)
	requestedChannel = tostring(requestedChannel or "")
	local candidates = MANUAL_TACTICAL_CHANNEL_FALLBACKS[
		requestedChannel
	] or MANUAL_TACTICAL_DEFAULT_PRIORITY
	for _, channel in ipairs(candidates) do
		if isManualTacticalChannelAvailable(channel) then
			return channel
		end
	end
	return nil
end

function Service:FormatTeleportMessage(
	challengeModeID, messageTemplate, senderName)
	local dungeon, teleport = resolveTeleportData(challengeModeID)
	local template = type(messageTemplate) == "string"
		and messageTemplate or self:GetTeleportMessage()
	if template == "" then
		template = self:GetDefaultTeleportMessage()
	end
	local playerText = tostring(senderName or currentPlayerName())
	local dungeonText = tostring(dungeon and dungeon.name
		or (GF.L and GF.L.MPLUS_UNKNOWN_DUNGEON)
		or "Unknown dungeon")
	local spellText = tostring(teleport
		and (teleport.spellLink or teleport.spellName)
		or (GF.L and GF.L.MPLUS_TELEPORT_TO)
		or "Teleport")
	local message = template:gsub("{player}", function()
		return playerText
	end)
	message = message:gsub("{dungeon}", function()
		return dungeonText
	end)
	message = message:gsub("%[%{spell%}%]", function()
		return spellText
	end)
	message = message:gsub("{spell}", function()
		return spellText
	end)
	return normalizeMessage(message)
end

local function getTacticalSeparator(key, fallbackKey)
	local L = GF.L or {}
	return normalizeMessage(L[key] or getCopy()[fallbackKey])
end

local function buildTacticalMessageBatch(lines)
	local messages = {
		getTacticalSeparator(
			"SET_MPLUS_TACTICAL_START_LINE",
			"tacticalStart"
		),
	}
	local bodyCount = 0
	for _, line in ipairs(lines or {}) do
		local message = normalizeMessage(line)
		if message ~= "" then
			messages[#messages + 1] = message
			bodyCount = bodyCount + 1
		end
	end
	messages[#messages + 1] = getTacticalSeparator(
		"SET_MPLUS_TACTICAL_END_LINE",
		"tacticalEnd"
	)
	return messages, bodyCount
end

function Service:BroadcastTacticalAnnouncement(challengeModeID, reason)
	challengeModeID = tonumber(challengeModeID)
	local lines = challengeModeID
		and getTacticalAnnouncementLines(
			self:GetTacticalAnnouncement(challengeModeID)) or {}
	if #lines == 0 then
		return false
	end
	local currentTime = now()
	self.recentTacticalAnnouncements =
		self.recentTacticalAnnouncements or {}
	local key = tostring(challengeModeID)
	local previousAt = self.recentTacticalAnnouncements[key]
	if previousAt
		and currentTime - previousAt < TACTICAL_DEDUPE_SECONDS
	then
		return false
	end
	local messages, sentCount = buildTacticalMessageBatch(lines)
	local queued = queueGroupMessages(self, messages)
	if not queued then
		return false, 0
	end
	if sentCount > 0 then
		self.recentTacticalAnnouncements[key] = currentTime
	end
	return sentCount > 0, sentCount
end

function Service:BroadcastManualTacticalAnnouncement(
	value, requestedChannel)
	local lines = getTacticalAnnouncementLines(value)
	local channel = self:ResolveManualTacticalChannel(requestedChannel)
	if #lines == 0 or not channel then
		return false, 0, channel
	end
	local messages, sentCount = buildTacticalMessageBatch(lines)
	local queued = queueChannelMessages(self, messages, channel)
	if not queued then
		return false, 0, channel, nil
	end
	return sentCount > 0, sentCount, channel, nil
end

function Service:BroadcastTeleport(challengeModeID)
	challengeModeID = tonumber(challengeModeID)
	if not challengeModeID then
		return false, false
	end
	local announcementSent = false
	if self:IsTeleportAnnouncementEnabled() then
		announcementSent = queueGroupMessages(self, {
			self:FormatTeleportMessage(challengeModeID),
		}, true)
	end
	local tacticalSent =
		self:BroadcastTacticalAnnouncement(challengeModeID, "teleport")
	return announcementSent, tacticalSent
end

function Service:BroadcastWarbandKeystone(data)
	if type(data) ~= "table" then
		return false, nil, nil
	end
	local keystoneLink = type(data.keystoneLink) == "string"
		and data.keystoneLink ~= ""
		and data.keystoneLink or nil
	if not keystoneLink then
		return false, nil, nil
	end

	local formatText = GF.L and GF.L.MPLUS_WARBAND_KEYSTONE_ANNOUNCE_FMT
		or "战团角色持有钥石：%s"
	local message = string.format(formatText, keystoneLink)
	local channel = getGroupChannel() or "SAY"
	if channel == "SAY" then
		return sendChannelMessage(message, channel), channel, message
	end
	local queued = queueChannelMessages(self, { message }, channel)
	return queued == true, channel, message
end

local function readable(value)
	return not (issecretvalue and issecretvalue(value))
		and not (canaccessvalue and not canaccessvalue(value))
end

local function readKeystoneAPI(api, method)
	local fn = api and api[method]
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn)
	if ok and readable(value) then return value end
end

local function keystoneLinkCore(link)
	if not readable(link) or type(link) ~= "string" then return nil end
	return link:match("|H(keystone:[^|]+)|h")
end

local function sameKeystoneGroup(a, b)
	return type(a) == "table" and type(b) == "table"
		and a.generation == b.generation and a.channel == b.channel
end

function Service:GetKeystoneGroup()
	local channel = getGroupChannel()
	if not channel then return false end
	return { channel = channel, generation = self.keystoneGroupGeneration or 0 }
end

function Service:ValidateKeystoneDelivery(delivery)
	if not self:IsKeystoneAnnouncementEnabled()
		or delivery.settingGeneration ~= (self.keystoneSettingGeneration or 0)
		or not sameKeystoneGroup(delivery.group, self:GetKeystoneGroup())
		or now() >= delivery.expiresAt
	then
		self.lastKeystoneDeliveryOutcome = "cancelled"
		return "drop"
	end
	if self.worldKeystoneTransition or self.worldKeystoneRecoveryTicket then
		return "wait"
	end
	if GF.Availability and GF.Availability.IsRestricted
		and GF.Availability:IsRestricted()
	then
		return "wait"
	end
	return "send"
end

function Service:CommitStableKeystone(snapshot, suppressAnnouncement, group)
	local nextIdentity = getKeystoneIdentity(snapshot)
	local previousIdentity = self.stableKeystoneIdentity
	self.stableKeystoneIdentity = nextIdentity
	self.stableKeystoneSnapshot = copyKeystoneSnapshot(snapshot)
	self.inventoryKeystoneGroup = nil
	if previousIdentity == nextIdentity or suppressAnnouncement
		or not getCompleteKeystoneIdentity(snapshot)
		or not self:IsKeystoneAnnouncementEnabled()
	then
		return false
	end
	group = group == nil and self:GetKeystoneGroup() or group
	if not sameKeystoneGroup(group, self:GetKeystoneGroup()) then return false end
	local L = GF.L or {}
	local template = L.SET_MPLUS_KEYSTONE_UPDATED_MESSAGE
		or L.MPLUS_KEYSTONE_UPDATED_MESSAGE or getCopy().keystoneUpdated
	local ok, message = pcall(string.format, template, snapshot.keystoneLink)
	if not ok or type(message) ~= "string" then
		message = getCopy().keystoneUpdated:format(snapshot.keystoneLink)
	end
	self.lastKeystoneDeliveryOutcome = "queued"
	return queueChannelMessages(self, { message }, group.channel, {
		group = group,
		settingGeneration = self.keystoneSettingGeneration or 0,
		identity = nextIdentity,
		expiresAt = now() + KEYSTONE_DELIVERY_TIMEOUT,
	})
end

-- Only Cache:Refresh increments sampleID. A timer looking at the same cached
-- snapshot cannot be counted as a second observation.
function Service:ReadKeystoneSample()
	local cache = GF.MythicPlusKeystoneCache
	if not cache then return nil end
	if cache.Refresh then
		self.readingKeystoneSample = true
		local ok = pcall(cache.Refresh, cache, "KEYSTONE_ANNOUNCEMENT_RECHECK")
		self.readingKeystoneSample = nil
		if not ok then return nil end
	end
	return cache.GetSnapshot and cache:GetSnapshot() or nil
end

local function observeKeystoneCandidate(transaction, snapshot)
	local identity = getCompleteKeystoneIdentity(snapshot)
	local sampleID = snapshot and snapshot.sampleID
	if not identity or not sampleID then
		transaction.candidateIdentity = nil
		transaction.candidateReads = 0
		transaction.lastSampleID = nil
		return false
	end
	if transaction.candidateIdentity ~= identity then
		transaction.candidateIdentity = identity
		transaction.candidateReads = 0
		transaction.lastSampleID = nil
	end
	if transaction.lastSampleID ~= sampleID then
		transaction.candidateReads = (transaction.candidateReads or 0) + 1
		transaction.lastSampleID = sampleID
	end
	return transaction.candidateReads >= 2
end

function Service:CancelGenericKeystoneTransaction()
	self.genericKeystoneTransaction = nil
	self.genericKeystoneTransactionTicket =
		(self.genericKeystoneTransactionTicket or 0) + 1
end

local function scheduleGenericKeystone(transaction, ticket)
	transaction.scheduled = scheduleKeystoneCallback(KEYSTONE_GENERIC_SETTLE_DELAY, function()
		Service:ConfirmGenericKeystoneTransaction(transaction, ticket)
	end)
end

function Service:ConfirmGenericKeystoneTransaction(transaction, ticket)
	if self.genericKeystoneTransaction ~= transaction
		or self.genericKeystoneTransactionTicket ~= ticket then return false end
	transaction.scheduled = nil
	if self.worldKeystoneTransition or self.worldKeystoneRecoveryTicket then return false end
	local snapshot = self:ReadKeystoneSample()
	if observeKeystoneCandidate(transaction, snapshot) then
		self:CancelGenericKeystoneTransaction()
		return self:CommitStableKeystone(snapshot, false, transaction.group)
	end
	transaction.attempts = (transaction.attempts or 0) + 1
	if transaction.attempts < MAX_KEYSTONE_GENERIC_SETTLE_ATTEMPTS then
		scheduleGenericKeystone(transaction, ticket)
	end
	-- Incomplete reads retain both the before-key and the event's group. A later
	-- inventory/data-ready event may resume this bounded transaction.
	return false
end

function Service:BeginGenericKeystoneTransaction(snapshot, group)
	local identity = getKeystoneIdentity(snapshot)
	if not identity or identity == self.stableKeystoneIdentity then return false end
	local transaction = self.genericKeystoneTransaction
	if transaction and transaction.candidateIdentity ~= getCompleteKeystoneIdentity(snapshot) then
		self.genericKeystoneTransactionTicket = (self.genericKeystoneTransactionTicket or 0) + 1
		transaction.scheduled = nil
	end
	if not transaction then
		transaction = { group = group, attempts = 0 }
		if transaction.group == nil then
			transaction.group = self.inventoryKeystoneGroup
			if transaction.group == nil then transaction.group = self:GetKeystoneGroup() end
		end
		self.genericKeystoneTransaction = transaction
		self.genericKeystoneTransactionTicket =
			(self.genericKeystoneTransactionTicket or 0) + 1
	end
	-- Snapshot notifications seed evidence; only the timed fresh read commits it.
	observeKeystoneCandidate(transaction, snapshot)
	if not transaction.scheduled then
		transaction.attempts = 0
		scheduleGenericKeystone(transaction, self.genericKeystoneTransactionTicket)
	end
	return true
end

function Service:ReadKeystoneRunOwner(run)
	if self.keystoneRun ~= run or not run.active then return end
	local active = readKeystoneAPI(C_ChallengeMode, "IsChallengeModeActive")
	if active ~= true then return end
	local owner = readKeystoneAPI(C_PartyInfo, "IsChallengeModeKeystoneOwner")
	if type(owner) == "boolean" then
		-- A false value on the START stack may precede server ownership setup.
		if owner or now() - run.startedAt >= 0.5 then run.owner = owner end
	end
end

function Service:ReadKeystoneCompletion(transaction)
	if transaction.kind ~= "completed" or transaction.result then return end
	local info = readKeystoneAPI(C_ChallengeMode, "GetChallengeCompletionInfo")
	if type(info) ~= "table" or (issecrettable and issecrettable(info)) then return end
	for _, key in ipairs({ "level", "mapChallengeModeID", "onTime", "practiceRun", "keystoneUpgradeLevels" }) do
		if not readable(info[key]) then return end
	end
	if type(info.level) ~= "number" or info.level <= 0
		or type(info.mapChallengeModeID) ~= "number" or info.mapChallengeModeID <= 0
		or type(info.onTime) ~= "boolean" or type(info.practiceRun) ~= "boolean"
	then return end
	transaction.result = {
		level = info.level, onTime = info.onTime, practiceRun = info.practiceRun,
		upgradeLevels = tonumber(info.keystoneUpgradeLevels) or 0,
	}
end

local function completionCandidateAllowed(transaction, snapshot)
	if not getCompleteKeystoneIdentity(snapshot) then return false end
	if transaction.kind ~= "completed" then return true end
	local result = transaction.result
	if not result or result.practiceRun then return false end
	if transaction.run and transaction.run.owner == false then return true end
	-- An explicit subsequent conversion of an already upgraded key belongs to
	-- the NPC operation, even if it happened before our final confirmation.
	local conversion = transaction.conversion
	if conversion and conversion.newCore == keystoneLinkCore(snapshot.keystoneLink)
		and conversion.previousLevel and conversion.previousLevel > result.level
	then return true end
	if result.onTime then
		return snapshot.level >= result.level
			and (result.upgradeLevels <= 0 or snapshot.level > result.level)
	end
	return true
end

local function scheduleCompletionKeystoneFinalization(transaction, ticket)
	transaction.settleAttempt = (transaction.settleAttempt or 0) + 1
	local delay = KEYSTONE_COMPLETION_SETTLE_RETRY_DELAYS[transaction.settleAttempt]
	if not delay then return false end
	transaction.scheduled = scheduleKeystoneCallback(delay, function()
		Service:FinalizeCompletionKeystoneTransaction(transaction, ticket)
	end)
	return transaction.scheduled
end

function Service:FinalizeCompletionKeystoneTransaction(transaction, ticket)
	if self.completionKeystoneTransaction ~= transaction
		or self.completionKeystoneTransactionTicket ~= ticket then return false end
	transaction.scheduled = nil
	if self.worldKeystoneTransition or self.worldKeystoneRecoveryTicket then return false end
	self:ReadKeystoneCompletion(transaction)
	local snapshot = self:ReadKeystoneSample()
	local changed = getKeystoneIdentity(snapshot) ~= transaction.baselineIdentity
	if not changed and getCompleteKeystoneIdentity(snapshot)
		and transaction.result and transaction.run and transaction.run.owner == false then
		-- Another player's completed key does not hold our later NPC operation.
		self.completionKeystoneTransaction = nil
		return false
	end
	if changed and completionCandidateAllowed(transaction, snapshot) then
		if observeKeystoneCandidate(transaction, snapshot) then
			self.completionKeystoneTransaction = nil
			return self:CommitStableKeystone(snapshot, false, transaction.group)
		end
	else
		observeKeystoneCandidate(transaction, nil)
	end
	if transaction.result and transaction.result.practiceRun then
		self.completionKeystoneTransaction = nil
		return false
	end
	scheduleCompletionKeystoneFinalization(transaction, ticket)
	return false
end

function Service:BeginCompletionKeystoneTransaction(event)
	local transaction = self.completionKeystoneTransaction
	if event == "CHALLENGE_MODE_COMPLETED_REWARDS" then
		-- Auxiliary cache refresh only. Do not restart the deadline or consume the
		-- first comparison, and do not create a second completion transaction.
		return false
	end
	local kind = event == "CHALLENGE_MODE_COMPLETED" and "completed" or "reset"
	local run = self.keystoneRun
	if run and run.completionObserved then return false end
	if kind == "reset" and transaction then return false end
	if run then
		self:ReadKeystoneRunOwner(run)
		run.active = false
		if kind == "completed" then run.completionObserved = true end
	end
	transaction = {
		kind = kind,
		baselineIdentity = self.stableKeystoneIdentity,
		group = run and run.group or self:GetKeystoneGroup(),
		run = run,
	}
	if run then transaction.group = run.group end
	self.completionKeystoneTransaction = transaction
	self:CancelGenericKeystoneTransaction()
	self.completionKeystoneTransactionTicket =
		(self.completionKeystoneTransactionTicket or 0) + 1
	self:ReadKeystoneCompletion(transaction)
	if not self.worldKeystoneTransition and not self.worldKeystoneRecoveryTicket then
		local snapshot = self:ReadKeystoneSample()
		if getKeystoneIdentity(snapshot) ~= transaction.baselineIdentity
			and completionCandidateAllowed(transaction, snapshot) then
			observeKeystoneCandidate(transaction, snapshot)
		end
	end
	scheduleCompletionKeystoneFinalization(transaction, self.completionKeystoneTransactionTicket)
	return true
end

function Service:FinishWorldKeystoneRecovery(ticket)
	if self.worldKeystoneRecoveryTicket ~= ticket then return false end
	self.worldKeystoneRecoveryTicket = nil
	local transaction = self.completionKeystoneTransaction
	if transaction then
		transaction.settleAttempt = 0
		return self:FinalizeCompletionKeystoneTransaction(transaction, self.completionKeystoneTransactionTicket)
	end
	transaction = self.genericKeystoneTransaction
	if transaction then
		transaction.attempts = 0
		return self:ConfirmGenericKeystoneTransaction(transaction, self.genericKeystoneTransactionTicket)
	end
	-- A surviving change is compared with the pre-load baseline. Identical keys
	-- stay quiet; a transient empty bag during loading cannot erase that baseline.
	return self:HandleKeystoneSnapshot(self:ReadKeystoneSample(), "BAG_UPDATE_DELAYED")
end

function Service:HandleKeystoneGroupEvent(event, category, partyGUID)
	local channel = getGroupChannel()
	local boundary = event == "GROUP_JOINED" or event == "GROUP_LEFT"
	if boundary and readable(category) and category
		and category ~= LE_PARTY_CATEGORY_HOME
		and IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME)
	then return end
	if event == "GROUP_JOINED" and readable(partyGUID) and partyGUID
		and partyGUID == self.keystonePartyGUID then boundary = false end
	if boundary or channel ~= self.keystoneObservedGroupChannel then
		self.keystonePartyGUID = event == "GROUP_JOINED" and readable(partyGUID) and partyGUID or nil
		self.keystoneObservedGroupChannel = channel
		self.keystoneGroupGeneration = (self.keystoneGroupGeneration or 0) + 1
		self:CancelGenericKeystoneTransaction()
		self.completionKeystoneTransaction = nil
		self.completionKeystoneTransactionTicket =
			(self.completionKeystoneTransactionTicket or 0) + 1
		if self.keystoneRun then self.keystoneRun.group = false end
		self.inventoryKeystoneGroup = false
		self.absorbingKeystoneBaseline = true
		if not self.worldKeystoneTransition and not self.worldKeystoneRecoveryTicket then
			self:HandleKeystoneSnapshot(self:ReadKeystoneSample(), "group-baseline")
		end
	end
end

function Service:HandleKeystoneEvent(event, ...)
	if event == "GROUP_JOINED" or event == "GROUP_LEFT" or event == "GROUP_ROSTER_UPDATE" then
		self:HandleKeystoneGroupEvent(event, ...)
		return false
	elseif event == "CHALLENGE_MODE_START" then
		self:CancelGenericKeystoneTransaction()
		self.completionKeystoneTransaction = nil
		self.completionKeystoneTransactionTicket =
			(self.completionKeystoneTransactionTicket or 0) + 1
		local run = {
			active = true, startedAt = now(), group = self:GetKeystoneGroup(),
			before = copyKeystoneSnapshot(self.stableKeystoneSnapshot),
		}
		self.keystoneRun = run
		self:ReadKeystoneRunOwner(run)
		for _, delay in ipairs({ 0.1, 0.5, 1, 2 }) do
			scheduleKeystoneCallback(delay, function() Service:ReadKeystoneRunOwner(run) end)
		end
		return false
	elseif COMPLETION_KEYSTONE_EVENTS[event] or event == "CHALLENGE_MODE_RESET" then
		return self:BeginCompletionKeystoneTransaction(event)
	elseif event == "INSTANCE_ABANDON_VOTE_FINISHED" then
		local passed = ...
		if readable(passed) and passed == true then
			return self:BeginCompletionKeystoneTransaction(event)
		end
		return false
	elseif event == "PLAYER_LEAVING_WORLD" then
		self.worldKeystoneTransition = true
		self.worldKeystoneRecoveryTicket = nil
		-- Retain the transaction, not its old callbacks. Recovery starts one fresh
		-- sequence, even when loading finishes before a pre-load timer is due.
		self.genericKeystoneTransactionTicket = (self.genericKeystoneTransactionTicket or 0) + 1
		self.completionKeystoneTransactionTicket = (self.completionKeystoneTransactionTicket or 0) + 1
		if self.genericKeystoneTransaction then self.genericKeystoneTransaction.scheduled = nil end
		if self.completionKeystoneTransaction then self.completionKeystoneTransaction.scheduled = nil end
		return false
	elseif event == "PLAYER_ENTERING_WORLD" then
		self.worldKeystoneTransition = nil
		self.worldKeystoneRecoverySerial = (self.worldKeystoneRecoverySerial or 0) + 1
		local ticket = self.worldKeystoneRecoverySerial
		self.worldKeystoneRecoveryTicket = ticket
		scheduleKeystoneCallback(KEYSTONE_WORLD_RECOVERY_DELAY, function()
			Service:FinishWorldKeystoneRecovery(ticket)
		end)
		return false
	elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "ITEM_CHANGED" then
		if event == "ITEM_CHANGED" then
			local previousLink, newLink = ...
			local previousCore, newCore = keystoneLinkCore(previousLink), keystoneLinkCore(newLink)
			if not previousCore and not newCore then return false end
			local transaction = self.completionKeystoneTransaction
			if transaction and previousCore and newCore then
				transaction.conversion = {
					newCore = newCore,
					previousLevel = tonumber(previousCore:match("^keystone:%d+:%d+:(%d+)")),
				}
			end
		end
		-- Capture at the event edge, before Cache's deferred bag scan. In
		-- particular, joining during confirmation cannot resurrect a solo change.
		self.inventoryKeystoneGroup = self:GetKeystoneGroup()
	end
	return false
end

function Service:HandleKeystoneSnapshot(snapshot, reason)
	if self.readingKeystoneSample or type(snapshot) ~= "table" then return false end
	if snapshot.state == "pending" then return false end
	local complete = getCompleteKeystoneIdentity(snapshot)
	if not self.keystoneBaselineReady or self.absorbingKeystoneBaseline then
		if complete or snapshot.state == "empty" then
			self.keystoneBaselineReady = true
			self.absorbingKeystoneBaseline = nil
			return self:CommitStableKeystone(snapshot, true)
		end
		return false
	end
	if not self:IsKeystoneAnnouncementEnabled() then
		self:CancelGenericKeystoneTransaction()
		if complete or snapshot.state == "empty" then return self:CommitStableKeystone(snapshot, true) end
		return false
	end
	if self.worldKeystoneTransition or self.worldKeystoneRecoveryTicket then return false end
	local transaction = self.completionKeystoneTransaction
	if transaction then
		if not transaction.scheduled and ANNOUNCEABLE_KEYSTONE_REASONS[reason] then
			transaction.settleAttempt = 0
			self:FinalizeCompletionKeystoneTransaction(transaction, self.completionKeystoneTransactionTicket)
		end
		return false
	end
	local run = self.keystoneRun
	if run and run.active and run.owner ~= false then return false end
	if snapshot.state ~= "ready" then
		if not self.genericKeystoneTransaction then return self:CommitStableKeystone(snapshot, true) end
		return false
	end
	if getKeystoneIdentity(snapshot) == self.stableKeystoneIdentity then
		self:CancelGenericKeystoneTransaction()
		return false
	end
	local reasonKey = reason or snapshot.reason or ""
	if not ANNOUNCEABLE_KEYSTONE_REASONS[reasonKey] then return false end
	return self:BeginGenericKeystoneTransaction(snapshot)
end

function Service:Init()
	if self.initialized then return end
	self.initialized = true
	getMythicPlusDB()
	self.keystoneObservedGroupChannel = getGroupChannel()
	local cache = GF.MythicPlusKeystoneCache
	if cache and cache.GetSnapshot then self:HandleKeystoneSnapshot(cache:GetSnapshot(), "service-init") end
	if cache and cache.AddListener then
		cache:AddListener(function(owner, reason)
			Service:HandleKeystoneSnapshot(owner:GetSnapshot(), reason)
		end)
	end
	if GF.Availability and GF.Availability.AddListener then
		GF.Availability:AddListener(function()
			drainQueuedChatMessage(Service)
		end)
	end
end
