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
		plain = "%s（%d）",
		unknownDungeon = "未知地下城",
	},
	zhTW = {
		create = "建立招募",
		send = "發送鑰石",
		mine = "我的鑰石資訊：%s",
		other = "%s的鑰石資訊：%s",
		plain = "%s（%d）",
		unknownDungeon = "未知地城",
	},
	enUS = {
		create = "Create",
		send = "Send Key",
		mine = "My keystone: %s",
		other = "%s's keystone: %s",
		plain = "%s (%d)",
		unknownDungeon = "Unknown dungeon",
	},
}

local function getCopy()
	local locale = GetLocale and GetLocale() or "enUS"
	return COPY[locale] or COPY.enUS
end

local function characterOf(entry)
	return entry and (entry.data or entry) or nil
end

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return not ok or secret == true
end

local function canAccessValue(value)
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	return not isSecret(value)
end

local function getAccessibleField(owner, field)
	if owner == nil then
		return nil, true
	end
	if not canAccessValue(owner) or type(owner) ~= "table" then
		return nil, false
	end
	local ok, value = pcall(function()
		return owner[field]
	end)
	if not ok or not canAccessValue(value) then
		return nil, false
	end
	return value, true
end

local ACTION_CHARACTER_FIELDS = {
	"unit",
	"key",
	"fullName",
	"name",
	"realm",
	"challengeModeID",
	"mapID",
	"keyLevel",
	"keystoneLink",
	"dungeonName",
	"activityID",
	"isCarpoolEntry",
	"isTest",
	"isDebugTest",
	"source",
	"debugActionPreview",
	"debugKeystonePayload",
}

local ACTION_ENTRY_FIELDS = {
	"unit",
	"key",
	"fullName",
	"name",
	"realm",
	"challengeModeID",
	"mapID",
	"keyLevel",
	"keystoneLink",
	"dungeonName",
	"activityID",
	"isCarpoolEntry",
	"isTest",
	"isDebugTest",
	"source",
	"debugActionPreview",
	"debugKeystonePayload",
}

local function actionFieldsAccessible(entry, character)
	for _, field in ipairs(ACTION_CHARACTER_FIELDS) do
		local _, accessible = getAccessibleField(character, field)
		if not accessible then
			return false
		end
	end
	if entry ~= character then
		for _, field in ipairs(ACTION_ENTRY_FIELDS) do
			local _, accessible = getAccessibleField(entry, field)
			if not accessible then
				return false
			end
		end
	end
	return true
end

local function canonical(value)
	if not canAccessValue(value) then
		return nil
	end
	value = type(value) == "string" and value or ""
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("%s+", "")
	return value ~= "" and string.lower(value) or nil
end

local function entryMatchesExactIdentifier(entry, identifier)
	local normalized = canonical(identifier)
	if not normalized then
		return false
	end
	local character = characterOf(entry) or {}
	for _, candidate in pairs({
		character.key,
		character.fullName,
		entry and entry.key,
		entry and entry.fullName,
	}) do
		if canonical(candidate) == normalized then
			return true
		end
	end
	return false
end

local function entryMatchesShortIdentifier(entry, identifier)
	local normalized = canonical(identifier)
	if not normalized then
		return false
	end
	local character = characterOf(entry) or {}
	for _, candidate in pairs({
		character.name,
		character.fullName,
		entry and entry.fullName,
	}) do
		local candidateName = canonical(candidate)
		candidateName = candidateName
			and (candidateName:match("^([^-]+)") or candidateName)
		if candidateName == normalized then
			return true
		end
	end
	return false
end

local function entryMatchesCurrentUnit(entry, unit)
	if not canAccessValue(unit)
		or type(unit) ~= "string" or unit == ""
		or type(UnitExists) ~= "function"
	then
		return false
	end
	local ok, exists = pcall(UnitExists, unit)
	if not ok or not canAccessValue(exists) or exists ~= true then
		return false
	end
	local unitGUID
	if type(UnitGUID) == "function" then
		ok, unitGUID = pcall(UnitGUID, unit)
		if not ok or not canAccessValue(unitGUID) then
			return false
		end
	end
	local unitKey
	if Util.GetUnitKey then
		ok, unitKey = pcall(Util.GetUnitKey, unit)
		if not ok or not canAccessValue(unitKey) then
			return false
		end
	end
	if unitKey and entryMatchesExactIdentifier(entry, unitKey) then
		return true
	end
	local fullName
	local name
	local realm
	if Util.GetUnitFullName then
		ok, fullName, name, realm = pcall(Util.GetUnitFullName, unit)
		if not ok
			or not canAccessValue(fullName)
			or not canAccessValue(name)
			or not canAccessValue(realm)
		then
			return false
		end
	end
	if fullName and entryMatchesExactIdentifier(entry, fullName) then
		return true
	end
	return (unitGUID == nil or unitGUID == "")
		and (realm == nil or realm == "")
		and entryMatchesShortIdentifier(entry, name)
end

local function isCurrentPlayerEntry(entry)
	return entryMatchesCurrentUnit(entry, "player")
end

local function isCurrentGroupMember(entry)
	local character = characterOf(entry)
	if character and entryMatchesCurrentUnit(entry, character.unit) then
		return true
	end
	local cache = GF.MythicPlusRosterCache
	for _, member in ipairs(cache and cache.GetMembers and cache:GetMembers() or {}) do
		if entryMatchesCurrentUnit(entry, member.unit) then
			return true
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
	local name
	for _, field in ipairs({ "fullName", "name", "key" }) do
		local value, accessible = getAccessibleField(character, field)
		if not accessible then
			return nil
		end
		if name == nil and type(value) == "string" and value ~= "" then
			name = value
		end
	end
	name = name or "Unknown"
	if name:find("-", 1, true) then
		return name
	end
	local realm, accessible = getAccessibleField(character, "realm")
	if not accessible then
		return nil
	end
	return type(realm) == "string" and realm ~= ""
		and (name .. "-" .. realm) or name
end

local function boundedPositiveInteger(value, maximum)
	if not canAccessValue(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or not canAccessValue(number) then
		return nil
	end
	value = number
	if not value or value ~= value
		or value == math.huge or value == -math.huge
		or value < 1 or value > maximum
		or value ~= math.floor(value)
	then
		return nil
	end
	return value
end

local function getKeystoneIdentity(character)
	local challengeModeID, challengeAccessible =
		getAccessibleField(character, "challengeModeID")
	local fallbackMapID, mapAccessible = getAccessibleField(character, "mapID")
	local rawKeyLevel, levelAccessible = getAccessibleField(character, "keyLevel")
	if not (challengeAccessible and mapAccessible and levelAccessible) then
		return nil
	end
	local rawMapID = challengeModeID
	if rawMapID == nil or rawMapID == false then
		rawMapID = fallbackMapID
	end
	local mapID = boundedPositiveInteger(rawMapID, 100000)
	local keyLevel = boundedPositiveInteger(rawKeyLevel, 1000)
	if not (mapID and keyLevel) then
		return nil
	end
	return mapID, keyLevel
end

local function getPlainKeystoneText(character)
	local mapID, keyLevel = getKeystoneIdentity(character)
	if not mapID then
		return nil
	end
	local dungeonName, accessible = getAccessibleField(character, "dungeonName")
	if not accessible then
		return nil
	end
	if type(dungeonName) ~= "string" or dungeonName == "" then
		local season = GF.MythicPlusSeason
		local dungeon = season and season.GetByChallengeModeID
			and season:GetByChallengeModeID(mapID) or nil
		if dungeon ~= nil then
			dungeonName, accessible = getAccessibleField(dungeon, "name")
			if not accessible then
				return nil
			end
		else
			dungeonName = nil
		end
	end
	local copy = getCopy()
	if type(dungeonName) ~= "string" or dungeonName == "" then
		dungeonName = (GF.L and GF.L.MPLUS_UNKNOWN_DUNGEON)
			or copy.unknownDungeon
	end
	local template = (GF.L and GF.L.MPLUS_KEYSTONE_PLAIN_FORMAT)
		or copy.plain
	local ok, text = pcall(
		string.format,
		template,
		dungeonName,
		math.floor(keyLevel + 0.5))
	if ok and type(text) == "string" and text ~= "" then
		return text
	end
	return string.format(
		copy.plain,
		dungeonName,
		math.floor(keyLevel + 0.5))
end

local function isSyntheticOrCarpoolEntry(entry)
	local character = characterOf(entry) or {}
	return character.isCarpoolEntry == true
		or entry and entry.isCarpoolEntry == true
		or character.isTest == true
		or entry and entry.isTest == true
		or character.isDebugTest == true
		or entry and entry.isDebugTest == true
		or character.source == "test"
		or entry and entry.source == "test"
end

local function isDebugActionPreview(entry, character)
	if not isSyntheticOrCarpoolEntry(entry) then
		return false
	end
	if character.isCarpoolEntry == true
		or entry and entry.isCarpoolEntry == true
	then
		return false
	end
	return character.debugActionPreview == true
		or entry and entry.debugActionPreview == true
end

local function hasKeystonePayload(character, allowDebugLink)
	local keystoneLink, accessible =
		getAccessibleField(character, "keystoneLink")
	if not accessible then
		return false
	end
	if type(keystoneLink) == "string" and keystoneLink ~= "" then
		return true
	end
	if allowDebugLink then
		local payloadKind, payloadAccessible =
			getAccessibleField(character, "debugKeystonePayload")
		if not payloadAccessible then
			return false
		end
		if payloadKind == "link" then
			return true
		end
	end
	return getPlainKeystoneText(character) ~= nil
end

local function makeAction(actionID, label, enabled, previewOnly)
	local action = {
		id = actionID,
		actionID = actionID,
		label = label,
		text = label,
		enabled = enabled == true,
	}
	if previewOnly then
		action.previewOnly = true
	end
	return action
end

function Service:GetGroupChannel()
	return getGroupChannel()
end

function Service:CanSendGroupKeystoneInfo(entry)
	local character = characterOf(entry)
	if not character or not actionFieldsAccessible(entry, character)
		or isSyntheticOrCarpoolEntry(entry)
		or not isCurrentGroupMember(entry)
	then
		return false
	end
	local keystoneLink, accessible =
		getAccessibleField(character, "keystoneLink")
	if not accessible then
		return false
	end
	local hasLink = type(keystoneLink) == "string" and keystoneLink ~= ""
	local hasPayload = hasLink
	if not hasPayload then
		hasPayload = getPlainKeystoneText(character) ~= nil
	end
	return hasPayload and getGroupChannel() ~= nil
		and getChatSender() ~= nil
end

function Service:SendGroupKeystoneInfo(entry)
	local character = characterOf(entry)
	if not character or not actionFieldsAccessible(entry, character)
		or isSyntheticOrCarpoolEntry(entry)
		or not isCurrentGroupMember(entry)
	then
		return false
	end
	local keystoneLink, accessible =
		getAccessibleField(character, "keystoneLink")
	if not accessible then
		return false
	end
	local payload
	if type(keystoneLink) == "string" and keystoneLink ~= "" then
		payload = keystoneLink
	else
		payload = getPlainKeystoneText(character)
	end
	if type(payload) ~= "string" or payload == "" then
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
	local characterName
	if not currentPlayerEntry then
		characterName = fullCharacterName(character)
		if type(characterName) ~= "string" or characterName == "" then
			return false
		end
	end
	local ok
	local message
	if currentPlayerEntry then
		template = (GF.L and GF.L.MPLUS_MY_KEYSTONE_MESSAGE) or copy.mine
		ok, message = pcall(string.format, template, payload)
	else
		template = (GF.L and GF.L.MPLUS_CHARACTER_KEYSTONE_MESSAGE) or copy.other
		ok, message = pcall(
			string.format, template, characterName, payload)
	end
	if not ok or type(message) ~= "string" then
		if currentPlayerEntry then
			message = copy.mine:format(payload)
		else
			message = copy.other:format(characterName, payload)
		end
	end
	message = Util.TruncateUtf8(message, MAX_CHAT_MESSAGE_BYTES)
	return message ~= "" and pcall(sender, message, channel) == true
end

function Service:Resolve(entry)
	local character = characterOf(entry)
	if not character or not actionFieldsAccessible(entry, character) then
		return nil
	end
	local previewOnly = isDebugActionPreview(entry, character)
	if isSyntheticOrCarpoolEntry(entry) and not previewOnly then
		return nil
	end
	if not previewOnly and not isCurrentGroupMember(entry) then
		return nil
	end

	local copy = getCopy()
	local bridge = GF.MythicPlusCreateBridge
	local canManage = isManagementAvailable()
		and canManageListing()
	if canManage then
		local canCreate = getKeystoneIdentity(character) ~= nil
			and bridge
			and bridge.CanOpenForRosterEntry
			and bridge:CanOpenForRosterEntry(character) == true
		return makeAction(
			"createListing",
			(GF.L and (GF.L.MPLUS_QUICK_CREATE or GF.L.TAB_CREATE))
				or copy.create,
			canCreate,
			previewOnly
		)
	end

	local canSend = previewOnly
		and hasKeystonePayload(character, true)
		and getGroupChannel() ~= nil
		and getChatSender() ~= nil
		or (not previewOnly and self:CanSendGroupKeystoneInfo(entry))
	return makeAction(
		"sendKeystone",
		(GF.L and GF.L.MPLUS_SEND_KEYSTONE) or copy.send,
		canSend,
		previewOnly
	)
end

function Service:Execute(entry, actionID)
	local character = characterOf(entry)
	if not character or isSyntheticOrCarpoolEntry(entry) then
		return false
	end
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
