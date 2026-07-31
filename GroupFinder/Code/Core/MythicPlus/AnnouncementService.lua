local _, GF = ...

GF.MythicPlusAnnouncementService = GF.MythicPlusAnnouncementService or {}
local Service = GF.MythicPlusAnnouncementService
local Util = GF.MythicPlusServiceUtil

local MAX_CHAT_MESSAGE_BYTES = 255
local TACTICAL_DEDUPE_SECONDS = 60
-- Covers the final five-second completion recheck if the cache briefly
-- transitions through an authoritative empty snapshot.
local KEYSTONE_DEDUPE_SECONDS = 6

local ANNOUNCEABLE_KEYSTONE_REASONS = {
	BAG_UPDATE = true,
	BAG_UPDATE_DELAYED = true,
	ITEM_CHANGED = true,
	CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN = true,
	CHALLENGE_MODE_KEYSTONE_SLOTTED = true,
	CHALLENGE_MODE_COMPLETED = true,
	CHALLENGE_MODE_COMPLETED_REWARDS = true,
	MYTHIC_PLUS_COMPLETION_RECHECK = true,
}

local COPY = {
	zhCN = {
		defaultTeleportMessage =
			"{player} 正在使用传送[{spell}]，即将前往[{dungeon}]！",
		tacticalPrefix = "战术通报：",
		keystoneUpdated = "钥石已更新：%s",
	},
	zhTW = {
		defaultTeleportMessage =
			"{player} 正在使用傳送[{spell}]，即將前往[{dungeon}]！",
		tacticalPrefix = "戰術通報：",
		keystoneUpdated = "鑰石已更新：%s",
	},
	enUS = {
		defaultTeleportMessage =
			"{player} is teleporting to [{dungeon}] with [{spell}].",
		tacticalPrefix = "Tactical: ",
		keystoneUpdated = "Keystone updated: %s",
	},
}

local function getCopy()
	local locale = GetLocale and GetLocale() or "enUS"
	return COPY[locale] or COPY.enUS
end

local function now()
	return GetTime and GetTime() or 0
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

local function normalizeMessage(value)
	value = tostring(value or "")
	value = value:gsub("[%c\r\n]+", " ")
	value = value:match("^%s*(.-)%s*$") or ""
	value = Util.TruncateUtf8(value, MAX_CHAT_MESSAGE_BYTES)
	return value:match("^%s*(.-)%s*$") or ""
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
	if settings.teleportFollowEnabled == nil then
		settings.teleportFollowEnabled = true
	else
		settings.teleportFollowEnabled =
			settings.teleportFollowEnabled == true
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
	return SendChatMessage or C_ChatInfo and C_ChatInfo.SendChatMessage
end

local function sendGroupMessage(message)
	message = normalizeMessage(message)
	local channel = getGroupChannel()
	local sender = getChatSender()
	if message == "" or not (channel and sender) then
		return false
	end
	local ok = pcall(sender, message, channel)
	return ok == true
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
		self.pendingKeystoneAnnouncementLink = nil
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
	return type(value) == "string" and normalizeMessage(value) or ""
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
	local normalized = normalizeMessage(value)
	local current = normalizeMessage(messages[key]
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

local function formatTacticalMessage(value)
	local message = normalizeMessage(value)
	if message == "" then
		return ""
	end
	local L = GF.L or {}
	local prefix = L.SET_MPLUS_TACTICAL_PREFIX
		or L.MPLUS_TACTICAL_ANNOUNCEMENT_PREFIX
		or getCopy().tacticalPrefix
	if message:sub(1, #prefix) == prefix
		or message:match("^%s*战术通报[:：]")
		or message:match("^%s*戰術通報[:：]")
		or message:match("^%s*[Tt]actical%s*[:：]")
	then
		return message
	end
	return normalizeMessage(prefix .. message)
end

function Service:BroadcastTacticalAnnouncement(challengeModeID, reason)
	challengeModeID = tonumber(challengeModeID)
	local message = challengeModeID
		and formatTacticalMessage(
			self:GetTacticalAnnouncement(challengeModeID)) or ""
	if message == "" then
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
	local sent = sendGroupMessage(message)
	if sent then
		self.recentTacticalAnnouncements[key] = currentTime
	end
	return sent
end

function Service:BroadcastTeleport(challengeModeID)
	challengeModeID = tonumber(challengeModeID)
	if not challengeModeID then
		return false, false
	end
	local announcementSent = false
	if self:IsTeleportAnnouncementEnabled() then
		announcementSent = sendGroupMessage(
			self:FormatTeleportMessage(challengeModeID))
	end
	local tacticalSent =
		self:BroadcastTacticalAnnouncement(challengeModeID, "teleport")
	return announcementSent, tacticalSent
end

function Service:HandleKeystoneSnapshot(snapshot, reason)
	if type(snapshot) ~= "table" then
		return false
	end
	local state = snapshot.state
	if state == "pending" then
		return false
	end
	local nextLink = state == "ready"
		and type(snapshot.keystoneLink) == "string"
		and snapshot.keystoneLink ~= ""
		and snapshot.keystoneLink or nil
	if not self.keystoneBaselineReady then
		self.keystoneBaselineReady = true
		self.lastObservedKeystoneLink = nextLink
		return false
	end
	local previousLink = self.lastObservedKeystoneLink
	local changed = previousLink ~= nextLink
	if changed then
		self.lastObservedKeystoneLink = nextLink
	end
	if not nextLink then
		self.pendingKeystoneAnnouncementLink = nil
		return false
	end
	if not self:IsKeystoneAnnouncementEnabled() then
		self.pendingKeystoneAnnouncementLink = nil
		return false
	end
	if changed then
		self.pendingKeystoneAnnouncementLink = nextLink
	end
	local reasonKey = tostring(reason or snapshot.reason or "")
	if self.pendingKeystoneAnnouncementLink ~= nextLink
		or not ANNOUNCEABLE_KEYSTONE_REASONS[reasonKey]
	then
		return false
	end

	local currentTime = now()
	if self.lastKeystoneAnnouncementLink == nextLink
		and self.lastKeystoneAnnouncementAt
		and currentTime - self.lastKeystoneAnnouncementAt
			< KEYSTONE_DEDUPE_SECONDS
	then
		self.pendingKeystoneAnnouncementLink = nil
		return false
	end
	local L = GF.L or {}
	local template = L.SET_MPLUS_KEYSTONE_UPDATED_MESSAGE
		or L.MPLUS_KEYSTONE_UPDATED_MESSAGE
		or getCopy().keystoneUpdated
	local ok, message = pcall(string.format, template, nextLink)
	if not ok or type(message) ~= "string" then
		message = getCopy().keystoneUpdated:format(nextLink)
	end
	local sent = sendGroupMessage(message)
	if sent then
		self.pendingKeystoneAnnouncementLink = nil
		self.lastKeystoneAnnouncementLink = nextLink
		self.lastKeystoneAnnouncementAt = currentTime
	end
	return sent
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	getMythicPlusDB()
	local cache = GF.MythicPlusKeystoneCache
	if cache and cache.GetSnapshot then
		local snapshot = cache:GetSnapshot()
		if snapshot then
			self:HandleKeystoneSnapshot(snapshot, "service-init")
		end
	end
	if cache and cache.AddListener then
		cache:AddListener(function(owner, reason)
			local snapshot = owner and owner.GetSnapshot
				and owner:GetSnapshot() or nil
			Service:HandleKeystoneSnapshot(snapshot, reason)
		end)
	end
end
