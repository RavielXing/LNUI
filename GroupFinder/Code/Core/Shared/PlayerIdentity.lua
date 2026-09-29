local _, GF = ...

-- 社交关系与外部玩家名规范化。

local Compat = GF.Compat or {}

local function accessibleValue(value)
	if type(value) == "nil" then
		return true
	end
	if type(Compat.IsAccessibleValue) == "function" then
		return Compat.IsAccessibleValue(value) == true
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return false
		end
	end
	return true
end

local function readAccessibleField(owner, key)
	if type(Compat.ReadAccessibleField) == "function" then
		return Compat.ReadAccessibleField(owner, key)
	end
	if type(owner) ~= "table" then
		return nil, "unavailable"
	end
	if type(issecretvaluekey) == "function" then
		local ok, secret = pcall(issecretvaluekey, owner, key)
		if not ok then
			return nil, "error"
		end
		if secret == true then
			return nil, "secret"
		end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, "error"
	end
	if not accessibleValue(value) then
		return nil, "secret"
	end
	if type(value) == "nil" then
		return nil, "missing"
	end
	return value, "value"
end

local function accessibleNumber(value)
	if type(value) == "nil" then
		return nil
	end
	if type(Compat.ToAccessibleNumber) == "function" then
		return Compat.ToAccessibleNumber(value)
	end
	if not accessibleValue(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or not accessibleValue(number) or type(number) ~= "number" then
		return nil
	end
	return number
end

local function accessibleArrayLength(values)
	if type(Compat.GetAccessibleArrayLength) == "function" then
		return Compat.GetAccessibleArrayLength(values)
	end
	if not accessibleValue(values) or type(values) ~= "table" then
		return nil
	end
	local ok, length = pcall(function()
		return #values
	end)
	return ok and accessibleNumber(length) or nil
end

GF.LAONONG_FAN_TYPE = "laonong"
GF.LAONONG_FAN_ICON_TEXTURE = "Interface\\AddOns\\GroupFinder_Laonong\\Art\\UI\\Icon\\Laonong.png"
GF.LAONONG_FAN_TEXT_COLOR = { r = 1, g = 0.82, b = 0 }

GF.SOCIAL_TYPE_BNET = "bnet"
GF.SOCIAL_TYPE_GUILD = "guild"
GF.SOCIAL_TYPE_FRIEND = "friend"
GF.SOCIAL_TYPE_CURRENT_GROUP = "current_group"
GF.RESULT_TYPE_CURRENT_GROUP = GF.SOCIAL_TYPE_CURRENT_GROUP
GF.RESULT_TYPE_CENSORED = "censored"
GF.SOCIAL_ROW_VISUAL_STATE = "blue"
GF.SOCIAL_SORT_PIN = 0
GF.NORMAL_SORT_PIN = 1
GF.SOCIAL_TEXT_COLOR = { r = 0.35, g = 0.75, b = 1 }
GF.SOCIAL_ICON_TEXTURE = GF.ADDON_ART_ICON_PATH .. "BattleNet.png"
GF.SOCIAL_TYPE_ICON_TEXTURE = {
	[GF.LAONONG_FAN_TYPE] = GF.LAONONG_FAN_ICON_TEXTURE,
	[GF.SOCIAL_TYPE_BNET] = GF.SOCIAL_ICON_TEXTURE,
	[GF.SOCIAL_TYPE_GUILD] = GF.SOCIAL_ICON_TEXTURE,
	[GF.SOCIAL_TYPE_FRIEND] = GF.SOCIAL_ICON_TEXTURE,
	[GF.RESULT_TYPE_CURRENT_GROUP] = GF.SOCIAL_ICON_TEXTURE,
}
GF.SOCIAL_TYPE_TEXT_COLOR = {
	[GF.LAONONG_FAN_TYPE] = GF.LAONONG_FAN_TEXT_COLOR,
	[GF.SOCIAL_TYPE_BNET] = GF.SOCIAL_TEXT_COLOR,
	[GF.SOCIAL_TYPE_GUILD] = GF.SOCIAL_TEXT_COLOR,
	[GF.SOCIAL_TYPE_FRIEND] = GF.SOCIAL_TEXT_COLOR,
	[GF.RESULT_TYPE_CURRENT_GROUP] = GF.SOCIAL_TEXT_COLOR,
}
GF.SOCIAL_TYPE_VISUAL_STATE = {
	[GF.SOCIAL_TYPE_BNET] = GF.SOCIAL_ROW_VISUAL_STATE,
	[GF.SOCIAL_TYPE_GUILD] = GF.SOCIAL_ROW_VISUAL_STATE,
	[GF.SOCIAL_TYPE_FRIEND] = GF.SOCIAL_ROW_VISUAL_STATE,
	[GF.RESULT_TYPE_CURRENT_GROUP] = GF.SOCIAL_ROW_VISUAL_STATE,
}
GF.SOCIAL_SEARCH_RESULT_LABEL_KEY = {
	[GF.LAONONG_FAN_TYPE] = "TYPE_LAONONG_FAN",
	[GF.SOCIAL_TYPE_BNET] = "TYPE_BNET_FRIEND",
	[GF.SOCIAL_TYPE_GUILD] = "TYPE_GUILD_FRIEND",
	[GF.SOCIAL_TYPE_FRIEND] = "TYPE_CHAR_FRIEND",
	[GF.RESULT_TYPE_CURRENT_GROUP] = "TYPE_CURRENT_GROUP",
}
GF.SOCIAL_APPLICANT_LABEL_KEY = {
	[GF.LAONONG_FAN_TYPE] = "APPLICANT_TYPE_LAONONG",
	[GF.SOCIAL_TYPE_BNET] = "APPLICANT_TYPE_BNET",
	[GF.SOCIAL_TYPE_GUILD] = "APPLICANT_TYPE_GUILD",
	[GF.SOCIAL_TYPE_FRIEND] = "APPLICANT_TYPE_FRIEND",
}
GF.SOCIAL_SEARCH_RESULT_LABEL_FALLBACK = {
	[GF.LAONONG_FAN_TYPE] = "老农粉丝",
	[GF.SOCIAL_TYPE_BNET] = "战网好友",
	[GF.SOCIAL_TYPE_GUILD] = "公会好友",
	[GF.SOCIAL_TYPE_FRIEND] = "角色好友",
	[GF.RESULT_TYPE_CURRENT_GROUP] = "当前队伍",
}
GF.SOCIAL_APPLICANT_LABEL_FALLBACK = {
	[GF.LAONONG_FAN_TYPE] = "老农",
	[GF.SOCIAL_TYPE_BNET] = "战网",
	[GF.SOCIAL_TYPE_GUILD] = "公会",
	[GF.SOCIAL_TYPE_FRIEND] = "好友",
}

-- 搜索结果没有安全/社交身份时，类型列回退显示暴雪原生游戏风格。
-- 稳定字符串只用于插件内部投影；保存值和原生枚举仍保持分离。
GF.RESULT_PLAYSTYLE_LEARNING = "playstyle_learning"
GF.RESULT_PLAYSTYLE_FUN_RELAXED = "playstyle_fun_relaxed"
GF.RESULT_PLAYSTYLE_FUN_SERIOUS = "playstyle_fun_serious"
GF.RESULT_PLAYSTYLE_EXPERT = "playstyle_expert"
GF.RESULT_PLAYSTYLE_TYPES = {
	GF.RESULT_PLAYSTYLE_LEARNING,
	GF.RESULT_PLAYSTYLE_FUN_RELAXED,
	GF.RESULT_PLAYSTYLE_FUN_SERIOUS,
	GF.RESULT_PLAYSTYLE_EXPERT,
}

local generalPlaystyle = Enum and Enum.LFGEntryGeneralPlaystyle or {}
GF.RESULT_PLAYSTYLE_TYPE_BY_GENERAL = {
	[generalPlaystyle.Learning or 1] = GF.RESULT_PLAYSTYLE_LEARNING,
	[generalPlaystyle.FunRelaxed or 2] = GF.RESULT_PLAYSTYLE_FUN_RELAXED,
	[generalPlaystyle.FunSerious or 3] = GF.RESULT_PLAYSTYLE_FUN_SERIOUS,
	[generalPlaystyle.Expert or 4] = GF.RESULT_PLAYSTYLE_EXPERT,
}
GF.RESULT_PLAYSTYLE_LABEL_GLOBAL = {
	[GF.RESULT_PLAYSTYLE_LEARNING] = "GROUP_FINDER_GENERAL_PLAYSTYLE1",
	[GF.RESULT_PLAYSTYLE_FUN_RELAXED] = "GROUP_FINDER_GENERAL_PLAYSTYLE2",
	[GF.RESULT_PLAYSTYLE_FUN_SERIOUS] = "GROUP_FINDER_GENERAL_PLAYSTYLE3",
	[GF.RESULT_PLAYSTYLE_EXPERT] = "GROUP_FINDER_GENERAL_PLAYSTYLE4",
}
GF.RESULT_PLAYSTYLE_ICON_TEXTURE = {
	[GF.RESULT_PLAYSTYLE_LEARNING] = GF.ADDON_ART_ICON_PATH .. "Beginner.png",
	[GF.RESULT_PLAYSTYLE_FUN_RELAXED] = GF.ADDON_ART_ICON_PATH .. "Leisure.png",
	[GF.RESULT_PLAYSTYLE_FUN_SERIOUS] = GF.ADDON_ART_ICON_PATH .. "challenge.png",
	[GF.RESULT_PLAYSTYLE_EXPERT] = GF.ADDON_ART_ICON_PATH .. "Captain.png",
}
GF.RESULT_PLAYSTYLE_TEXT_COLOR = {
	[GF.RESULT_PLAYSTYLE_LEARNING] = { r = 0.1, g = 1, b = 0.1 },
	[GF.RESULT_PLAYSTYLE_FUN_RELAXED] = { r = 1, g = 0.82, b = 0 },
	[GF.RESULT_PLAYSTYLE_FUN_SERIOUS] = { r = 1, g = 0.82, b = 0 },
	[GF.RESULT_PLAYSTYLE_EXPERT] = { r = 1, g = 0.82, b = 0 },
}

function GF.GetResultPlaystyleType(value)
	value = accessibleNumber(value)
	if value == nil or value == generalPlaystyle.None then
		return nil
	end
	return GF.RESULT_PLAYSTYLE_TYPE_BY_GENERAL[value]
end

function GF.GetResultPlaystyleLabel(resultType)
	local globalKey = GF.RESULT_PLAYSTYLE_LABEL_GLOBAL[resultType]
	return globalKey and _G[globalKey] or ""
end

GF.SOCIAL_RELATIONSHIP_TYPE_BY_STRING = {
	bnet = GF.SOCIAL_TYPE_BNET,
	battlenet = GF.SOCIAL_TYPE_BNET,
	["battle.net"] = GF.SOCIAL_TYPE_BNET,
	["battle net"] = GF.SOCIAL_TYPE_BNET,
	friend = GF.SOCIAL_TYPE_FRIEND,
	charfriend = GF.SOCIAL_TYPE_FRIEND,
	characterfriend = GF.SOCIAL_TYPE_FRIEND,
	guild = GF.SOCIAL_TYPE_GUILD,
	club = GF.SOCIAL_TYPE_GUILD,
}

function GF.GetSocialRelationshipType(relationship)
	if not accessibleValue(relationship) then
		return nil
	end
	if relationship == nil or relationship == false then
		return nil
	end
	if type(relationship) == "string" then
		return GF.SOCIAL_RELATIONSHIP_TYPE_BY_STRING[relationship:lower()]
	end
	local relEnum = Enum and Enum.PartyRequestJoinRelation
	if relEnum then
		if relationship == relEnum.None then
			return nil
		end
		if relationship == relEnum.Guild or relationship == relEnum.Club then
			return GF.SOCIAL_TYPE_GUILD
		end
		if relationship == relEnum.Friend then
			return GF.SOCIAL_TYPE_FRIEND
		end
	end
	if relationship ~= 0 then
		return GF.SOCIAL_TYPE_FRIEND
	end
	return nil
end

function GF.IsSocialRelationship(relationship)
	return GF.GetSocialRelationshipType(relationship) ~= nil
end

function GF.GetSocialTypeTextColor(socialType)
	if socialType and GF.SOCIAL_TYPE_TEXT_COLOR then
		return GF.SOCIAL_TYPE_TEXT_COLOR[socialType] or GF.SOCIAL_TEXT_COLOR
	end
	return GF.SOCIAL_TEXT_COLOR
end

local function trimExternalPlayerText(text)
	if not accessibleValue(text) then
		return nil
	end
	if type(text) ~= "string" then
		return nil
	end
	text = text:match("^%s*(.-)%s*$")
	return text ~= "" and text or nil
end

local function cleanExternalRealmText(realm)
	realm = trimExternalPlayerText(realm)
	if not realm then
		return nil
	end
	realm = realm:gsub("%[.-%]", "")
	realm = realm:gsub("（", "("):gsub("）", ")")
	return trimExternalPlayerText(realm)
end

local function cleanExternalRealmTextForCopy(realm)
	realm = trimExternalPlayerText(realm)
	if not realm then
		return nil
	end
	realm = realm:gsub("%[.-%]", "")
	return trimExternalPlayerText(realm)
end

local function getCurrentRealmNameForExternalMatch()
	local realm = GetNormalizedRealmName and GetNormalizedRealmName()
	realm = trimExternalPlayerText(realm)
	if realm then
		return realm
	end
	realm = GetRealmName and GetRealmName()
	return trimExternalPlayerText(realm)
end

function GF.NormalizeExternalFullPlayerName(name, fallbackRealm)
	name = trimExternalPlayerText(name)
	if not name then
		return nil
	end
	local character, realm = name:match("^([^%-]+)%-(.+)$")
	if not character then
		realm = cleanExternalRealmText(fallbackRealm) or getCurrentRealmNameForExternalMatch()
		return realm and (name .. "-" .. realm) or name
	end
	character = trimExternalPlayerText(character)
	realm = cleanExternalRealmText(realm)
	if not character or not realm then
		return nil
	end
	return character .. "-" .. realm
end

function GF.FormatExternalFullPlayerNameForCopy(name, fallbackRealm)
	name = trimExternalPlayerText(name)
	if not name then
		return nil
	end
	local character, realm = name:match("^([^%-]+)%-(.+)$")
	if not character then
		realm = cleanExternalRealmTextForCopy(fallbackRealm)
			or getCurrentRealmNameForExternalMatch()
		return realm and (name .. "-" .. realm) or name
	end
	character = trimExternalPlayerText(character)
	realm = cleanExternalRealmTextForCopy(realm)
	if not character or not realm then
		return nil
	end
	return character .. "-" .. realm
end

local function countSearchResultFriends(list)
	if not accessibleValue(list) then
		return nil, false
	end
	if list == nil then
		return 0, true
	end
	local length = accessibleArrayLength(list)
	return length, length ~= nil
end

local function unreadableFieldState(state)
	return state == "secret" or state == "error" or state == "unavailable"
end

local function inChatMessagingLockdown()
	local checker = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
	if type(checker) ~= "function" then
		return false
	end
	local ok, locked = pcall(checker)
	return not ok or locked == true
end

function GF.ResolveSearchResultSocialCounts(info, resultID)
	if not info then
		return 0, 0, 0
	end
	local bnetValue, bnetState = readAccessibleField(info, "numBNetFriends")
	local guildValue, guildState = readAccessibleField(info, "numGuildMates")
	local friendValue, friendState = readAccessibleField(info, "numCharFriends")
	local bnet = accessibleNumber(bnetValue) or 0
	local guild = accessibleNumber(guildValue) or 0
	local friend = accessibleNumber(friendValue) or 0
	local checked = readAccessibleField(info, "_gfSocialFriendsChecked")
	if bnet > 0 or guild > 0 or friend > 0 or checked == true then
		return bnet, guild, friend
	end
	if unreadableFieldState(bnetState)
		or unreadableFieldState(guildState)
		or unreadableFieldState(friendState)
		or inChatMessagingLockdown()
	then
		-- Unknown social counts are not zero evidence.  Fail open without
		-- probing another API whose return values are secret in the same lock.
		return bnet, guild, friend
	end
	if not resultID or not C_LFGList or not C_LFGList.GetSearchResultFriends then
		return bnet, guild, friend
	end

	local ok, bNetFriends, charFriends, guildMates = pcall(C_LFGList.GetSearchResultFriends, resultID)
	if not ok then
		return bnet, guild, friend
	end
	local bnetCount, bnetReadable = countSearchResultFriends(bNetFriends)
	local guildCount, guildReadable = countSearchResultFriends(guildMates)
	local friendCount, friendReadable = countSearchResultFriends(charFriends)
	if not (bnetReadable and guildReadable and friendReadable) then
		return bnet, guild, friend
	end

	bnet = math.max(bnet, bnetCount)
	guild = math.max(guild, guildCount)
	friend = math.max(friend, friendCount)
	info._gfSocialFriendsChecked = true
	info.numBNetFriends = bnet
	info.numGuildMates = guild
	info.numCharFriends = friend
	return bnet, guild, friend
end

local function fallbackCurrentGroupResult(info)
	if type(info) ~= "table" then
		return false
	end
	if type(IsInGroup) == "function" then
		local ok, inGroup
		if LE_PARTY_CATEGORY_HOME ~= nil then
			ok, inGroup = pcall(IsInGroup, LE_PARTY_CATEGORY_HOME)
		else
			ok, inGroup = pcall(IsInGroup)
		end
		if ok and inGroup ~= true then
			return false
		end
	end
	local hasSelf = readAccessibleField(info, "hasSelf")
	return hasSelf == true
end

function GF.IsCurrentGroupSearchResult(info, resultID)
	local apply = GF.Apply
	if apply and type(apply.IsCurrentGroupResult) == "function" then
		return apply:IsCurrentGroupResult(resultID, info) == true
	end
	return fallbackCurrentGroupResult(info)
end

function GF.GetSearchResultSocialType(info, resultID)
	if not info then
		return nil
	end
	if GF.IsCurrentGroupSearchResult(info, resultID) then
		return nil
	end
	local bnet, guild, friend = GF.ResolveSearchResultSocialCounts(info, resultID)
	if bnet > 0 then
		return GF.SOCIAL_TYPE_BNET
	end
	local isGuildListing = readAccessibleField(info, "isGuildListing")
	local isFriendListing = readAccessibleField(info, "isFriendListing")
	if guild > 0
		or isGuildListing == true then
		return GF.SOCIAL_TYPE_GUILD
	end
	if friend > 0
		or isFriendListing == true then
		return GF.SOCIAL_TYPE_FRIEND
	end
	return nil
end

function GF.IsSocialSearchResult(info, resultID)
	return GF.GetSearchResultSocialType(info, resultID) ~= nil
end

function GF.GetSocialTypeVisualState(socialType)
	if socialType and GF.SOCIAL_TYPE_VISUAL_STATE then
		return GF.SOCIAL_TYPE_VISUAL_STATE[socialType]
	end
	return nil
end

function GF.GetSocialSortPin(socialType)
	return GF.GetSocialTypeVisualState(socialType) and GF.SOCIAL_SORT_PIN or GF.NORMAL_SORT_PIN
end
