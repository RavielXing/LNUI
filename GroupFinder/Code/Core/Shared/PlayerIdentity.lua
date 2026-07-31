local _, GF = ...

-- 社交关系与外部玩家名规范化。

GF.SOCIAL_TYPE_BNET = "bnet"
GF.SOCIAL_TYPE_GUILD = "guild"
GF.SOCIAL_TYPE_FRIEND = "friend"
GF.SOCIAL_TYPE_LAONONG = "laonong"
GF.SOCIAL_ROW_VISUAL_STATE = "blue"
GF.SOCIAL_SORT_PIN = 0
GF.NORMAL_SORT_PIN = 1
GF.SOCIAL_TEXT_COLOR = { r = 0.35, g = 0.75, b = 1 }
GF.LAONONG_TEXT_COLOR = { r = 1, g = 0.82, b = 0 }
GF.SOCIAL_ICON_TEXTURE = GF.ADDON_ART_ICON_PATH .. "BattleNet.png"
GF.LAONONG_ICON_TEXTURE = GF.ADDON_ART_ICON_PATH .. "Laonong.png"
GF.SOCIAL_TYPE_ICON_TEXTURE = {
	[GF.SOCIAL_TYPE_BNET] = GF.SOCIAL_ICON_TEXTURE,
	[GF.SOCIAL_TYPE_GUILD] = GF.SOCIAL_ICON_TEXTURE,
	[GF.SOCIAL_TYPE_FRIEND] = GF.SOCIAL_ICON_TEXTURE,
	[GF.SOCIAL_TYPE_LAONONG] = GF.LAONONG_ICON_TEXTURE,
}
GF.SOCIAL_TYPE_TEXT_COLOR = {
	[GF.SOCIAL_TYPE_BNET] = GF.SOCIAL_TEXT_COLOR,
	[GF.SOCIAL_TYPE_GUILD] = GF.SOCIAL_TEXT_COLOR,
	[GF.SOCIAL_TYPE_FRIEND] = GF.SOCIAL_TEXT_COLOR,
	[GF.SOCIAL_TYPE_LAONONG] = GF.LAONONG_TEXT_COLOR,
}
GF.SOCIAL_TYPE_VISUAL_STATE = {
	[GF.SOCIAL_TYPE_BNET] = GF.SOCIAL_ROW_VISUAL_STATE,
	[GF.SOCIAL_TYPE_GUILD] = GF.SOCIAL_ROW_VISUAL_STATE,
	[GF.SOCIAL_TYPE_FRIEND] = GF.SOCIAL_ROW_VISUAL_STATE,
}
GF.SOCIAL_SEARCH_RESULT_LABEL_KEY = {
	[GF.SOCIAL_TYPE_BNET] = "TYPE_BNET_FRIEND",
	[GF.SOCIAL_TYPE_GUILD] = "TYPE_GUILD_FRIEND",
	[GF.SOCIAL_TYPE_FRIEND] = "TYPE_CHAR_FRIEND",
	[GF.SOCIAL_TYPE_LAONONG] = "TYPE_LAONONG_FAN",
}
GF.SOCIAL_APPLICANT_LABEL_KEY = {
	[GF.SOCIAL_TYPE_BNET] = "APPLICANT_TYPE_BNET",
	[GF.SOCIAL_TYPE_GUILD] = "APPLICANT_TYPE_GUILD",
	[GF.SOCIAL_TYPE_FRIEND] = "APPLICANT_TYPE_FRIEND",
	[GF.SOCIAL_TYPE_LAONONG] = "APPLICANT_TYPE_LAONONG",
}
GF.SOCIAL_SEARCH_RESULT_LABEL_FALLBACK = {
	[GF.SOCIAL_TYPE_BNET] = "战网好友",
	[GF.SOCIAL_TYPE_GUILD] = "公会好友",
	[GF.SOCIAL_TYPE_FRIEND] = "角色好友",
	[GF.SOCIAL_TYPE_LAONONG] = "老农粉丝",
}
GF.SOCIAL_APPLICANT_LABEL_FALLBACK = {
	[GF.SOCIAL_TYPE_BNET] = "战网",
	[GF.SOCIAL_TYPE_GUILD] = "公会",
	[GF.SOCIAL_TYPE_FRIEND] = "好友",
	[GF.SOCIAL_TYPE_LAONONG] = "老农",
}
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
	if type(text) ~= "string" then
		return nil
	end
	if type(issecretvalue) == "function" and issecretvalue(text) then
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

local function countSearchResultFriends(list)
	if type(list) ~= "table" then
		return 0
	end
	return #list
end

function GF.ResolveSearchResultSocialCounts(info, resultID)
	if not info then
		return 0, 0, 0
	end
	local bnet = tonumber(info.numBNetFriends) or 0
	local guild = tonumber(info.numGuildMates) or 0
	local friend = tonumber(info.numCharFriends) or 0
	if bnet > 0 or guild > 0 or friend > 0 or info._gfSocialFriendsChecked then
		return bnet, guild, friend
	end
	if not resultID or not C_LFGList or not C_LFGList.GetSearchResultFriends then
		return bnet, guild, friend
	end

	info._gfSocialFriendsChecked = true
	local ok, bNetFriends, charFriends, guildMates = pcall(C_LFGList.GetSearchResultFriends, resultID)
	if not ok then
		return bnet, guild, friend
	end

	bnet = math.max(bnet, countSearchResultFriends(bNetFriends))
	guild = math.max(guild, countSearchResultFriends(guildMates))
	friend = math.max(friend, countSearchResultFriends(charFriends))
	info.numBNetFriends = bnet
	info.numGuildMates = guild
	info.numCharFriends = friend
	return bnet, guild, friend
end

function GF.GetSearchResultSocialType(info, resultID)
	if not info then
		return nil
	end
	local bnet, guild, friend = GF.ResolveSearchResultSocialCounts(info, resultID)
	if bnet > 0 then
		return GF.SOCIAL_TYPE_BNET
	end
	if guild > 0
		or info.isGuildListing == true then
		return GF.SOCIAL_TYPE_GUILD
	end
	if friend > 0
		or info.isFriendListing == true then
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

function GF.GetSearchResultSocialSortPin(info, resultID)
	return GF.GetSocialSortPin(GF.GetSearchResultSocialType(info, resultID))
end
