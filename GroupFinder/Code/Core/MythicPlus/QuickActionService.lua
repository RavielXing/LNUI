local _, GF = ...

GF.MythicPlusQuickActionService = GF.MythicPlusQuickActionService or {}
local Service = GF.MythicPlusQuickActionService
local Util = GF.MythicPlusServiceUtil

local MAX_CHAT_MESSAGE_BYTES = 255

local COPY = {
	zhCN = {
		create = "创建招募",
		send = "发送钥石",
		mine = "我的钥石信息：%s",
		other = "%s的钥石信息：%s",
	},
	zhTW = {
		create = "建立招募",
		send = "發送鑰石",
		mine = "我的鑰石資訊：%s",
		other = "%s的鑰石資訊：%s",
	},
	enUS = {
		create = "Create",
		send = "Send Key",
		mine = "My keystone: %s",
		other = "%s's keystone: %s",
	},
}

local function getCopy()
	local locale = GetLocale and GetLocale() or "enUS"
	return COPY[locale] or COPY.enUS
end

local function characterOf(entry)
	return entry and (entry.data or entry) or nil
end

local function canonical(value)
	value = type(value) == "string" and value or ""
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("%s+", "")
	return value ~= "" and string.lower(value) or nil
end

local function identifierAliases(value)
	local aliases = {}
	local normalized = canonical(value)
	if normalized then
		aliases[normalized] = true
		aliases[normalized:match("^([^-]+)") or normalized] = true
	end
	return aliases
end

local function identifiersMatch(left, right)
	local rightAliases = identifierAliases(right)
	for alias in pairs(identifierAliases(left)) do
		if rightAliases[alias] then
			return true
		end
	end
	return false
end

local function entryIdentifiers(entry)
	local character = characterOf(entry) or {}
	local identifiers = {}
	for _, value in pairs({
		character.fullName,
		character.name,
		character.key,
		entry and entry.key,
		entry and entry.owner,
		entry and entry.fullName,
	}) do
		if type(value) == "string" and value ~= "" then
			identifiers[#identifiers + 1] = value
		end
	end
	return identifiers
end

local function entryMatchesIdentifier(entry, identifier)
	if type(identifier) ~= "string" or identifier == "" then
		return false
	end
	for _, candidate in ipairs(entryIdentifiers(entry)) do
		if identifiersMatch(candidate, identifier) then
			return true
		end
	end
	return false
end

local function isCurrentPlayerEntry(entry)
	local playerFullName
	if GetUnitName then
		playerFullName = GetUnitName("player", true)
	end
	if type(playerFullName) ~= "string" or playerFullName == "" then
		local name = UnitName and UnitName("player")
		local realm = GetRealmName and GetRealmName()
		if type(name) == "string" and name ~= "" then
			playerFullName = type(realm) == "string" and realm ~= ""
				and (name .. "-" .. realm) or name
		end
	end
	return entryMatchesIdentifier(entry, playerFullName)
		or entryMatchesIdentifier(entry, UnitName and UnitName("player"))
end

local function isCurrentGroupMember(entry)
	local character = characterOf(entry)
	if character and type(character.unit) == "string"
		and UnitExists and UnitExists(character.unit)
	then
		return true
	end
	local cache = GF.MythicPlusRosterCache
	for _, member in ipairs(cache and cache.GetMembers and cache:GetMembers() or {}) do
		for _, identifier in pairs({
			member.fullName,
			member.name,
			member.key,
		}) do
			if entryMatchesIdentifier(entry, identifier) then
				return true
			end
		end
	end
	return false
end

local function isManagementAvailable()
	return C_LFGList
		and C_LFGList.GetActivityInfoTable
		and C_LFGList.CreateListing
		and C_LFGList.UpdateListing
		and C_LFGList.HasActiveEntryInfo
		and C_LFGList.GetApplicants
		and true
		or false
end

local function isInManagedGroup()
	if IsInGroup then
		local okHome, inHome = pcall(IsInGroup, LE_PARTY_CATEGORY_HOME)
		local okInstance, inInstance = pcall(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)
		local okAny, inAny = pcall(IsInGroup)
		if (okHome and inHome) or (okInstance and inInstance)
			or (okAny and inAny)
		then
			return true
		end
	end
	if GetNumGroupMembers then
		local ok, count = pcall(GetNumGroupMembers)
		if ok and tonumber(count) and tonumber(count) > 0 then
			return true
		end
	end
	if UnitExists then
		for index = 1, 4 do
			local ok, exists = pcall(UnitExists, "party" .. index)
			if ok and exists then
				return true
			end
		end
		for index = 1, 40 do
			local ok, exists = pcall(UnitExists, "raid" .. index)
			if ok and exists then
				return true
			end
		end
	end
	return false
end

local function isPlayerGroupLeader()
	if UnitIsGroupLeader then
		local okHome, homeLeader =
			pcall(UnitIsGroupLeader, "player", LE_PARTY_CATEGORY_HOME)
		local okInstance, instanceLeader =
			pcall(UnitIsGroupLeader, "player", LE_PARTY_CATEGORY_INSTANCE)
		local okAny, anyLeader = pcall(UnitIsGroupLeader, "player")
		if (okHome and homeLeader) or (okInstance and instanceLeader)
			or (okAny and anyLeader)
		then
			return true
		end
	end
	if IsGroupLeader then
		local ok, leader = pcall(IsGroupLeader)
		if ok and leader then
			return true
		end
	end
	return false
end

local function canManageListing()
	return not isInManagedGroup() or isPlayerGroupLeader()
end

local function getGroupChannel()
	if IsInRaid and IsInRaid() then
		return "RAID"
	end
	if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
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

local function fullCharacterName(character)
	local name = character and (character.name or character.fullName
		or character.key) or "Unknown"
	if type(name) ~= "string" or name == "" then
		name = "Unknown"
	end
	if name:find("-", 1, true) then
		return name
	end
	local realm = character and character.realm
	return type(realm) == "string" and realm ~= ""
		and (name .. "-" .. realm) or name
end

local function makeAction(actionID, label, enabled)
	return {
		id = actionID,
		actionID = actionID,
		label = label,
		text = label,
		enabled = enabled == true,
	}
end

function Service:GetGroupChannel()
	return getGroupChannel()
end

function Service:CanSendGroupKeystoneInfo(entry)
	local character = characterOf(entry)
	local keystoneLink = character and character.keystoneLink
	return character and character.keystoneReadOnly ~= true
		and type(keystoneLink) == "string"
		and keystoneLink ~= ""
		and getGroupChannel() ~= nil
		and getChatSender() ~= nil
end

function Service:SendGroupKeystoneInfo(entry)
	local character = characterOf(entry)
	local keystoneLink = character and character.keystoneLink
	if type(keystoneLink) ~= "string" or keystoneLink == "" then
		return false
	end
	local channel = getGroupChannel()
	local sender = getChatSender()
	if not (channel and sender) then
		return false
	end
	local copy = getCopy()
	local template
	local currentPlayerEntry = isCurrentPlayerEntry(entry)
	local ok
	local message
	if currentPlayerEntry then
		template = (GF.L and GF.L.MPLUS_MY_KEYSTONE_MESSAGE) or copy.mine
		ok, message = pcall(string.format, template, keystoneLink)
	else
		template = (GF.L and GF.L.MPLUS_CHARACTER_KEYSTONE_MESSAGE) or copy.other
		ok, message = pcall(
			string.format, template, fullCharacterName(character), keystoneLink)
	end
	if not ok or type(message) ~= "string" then
		message = currentPlayerEntry
			and ("我的钥石信息：" .. tostring(keystoneLink))
			or (fullCharacterName(character) .. "的钥石信息："
				.. tostring(keystoneLink))
	end
	message = Util.TruncateUtf8(message, MAX_CHAT_MESSAGE_BYTES)
	return message ~= "" and pcall(sender, message, channel) == true
end

function Service:Resolve(entry)
	local character = characterOf(entry)
	local mapID = tonumber(character
		and (character.challengeModeID or character.mapID))
	local keyLevel = tonumber(character and character.keyLevel)
	if not (mapID and mapID > 0 and keyLevel and keyLevel > 0)
		or character.isRosterOnly == true
		or entry and entry.isRosterOnly == true
		or character.keystoneReadOnly == true
		or entry and entry.keystoneReadOnly == true
		or character.isCarpoolEntry == true
		or entry and entry.isCarpoolEntry == true
	then
		return nil
	end

	local copy = getCopy()
	local bridge = GF.MythicPlusCreateBridge
	local canCreate = isManagementAvailable()
		and isCurrentGroupMember(entry)
		and canManageListing()
		and bridge
		and bridge.CanOpenForRosterEntry
		and bridge:CanOpenForRosterEntry(character) == true
	if canCreate then
		return makeAction(
			"createListing",
			(GF.L and (GF.L.MPLUS_QUICK_CREATE or GF.L.TAB_CREATE))
				or copy.create,
			true
		)
	end

	return makeAction(
		"sendKeystone",
		(GF.L and GF.L.MPLUS_SEND_KEYSTONE) or copy.send,
		self:CanSendGroupKeystoneInfo(entry)
	)
end

function Service:Execute(entry, actionID)
	local action = self:Resolve(entry)
	actionID = actionID or action and action.id
	if not action or action.enabled == false or action.id ~= actionID then
		return false
	end
	if actionID == "createListing" then
		local bridge = GF.MythicPlusCreateBridge
		return bridge and bridge.OpenForRosterEntry
			and bridge:OpenForRosterEntry(characterOf(entry)) == true
	end
	if actionID == "sendKeystone" then
		return self:SendGroupKeystoneInfo(entry)
	end
	return false
end
