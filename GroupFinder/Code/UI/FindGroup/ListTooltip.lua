local _, GF = ...

local LT = {}
GF.ListTooltip = LT

local GOLD_R = 1
local GOLD_G = 0.82
local GOLD_B = 0

local TOOLTIP_ROLE_ICON_SIZE = GF.TOOLTIP_ROLE_ICON_SIZE or GF.ROLE_ICON_SIZE or 18
local TOOLTIP_LEADER_ICON_SIZE = TOOLTIP_ROLE_ICON_SIZE
local TOOLTIP_FACTION_ICON_SIZE = 14
local TOOLTIP_LEAVER_ICON_SIZE = GF.NON_ROLE_ICON_SIZE or 18
local TOOLTIP_BLACKLIST_ICON_SIZE = GF.NON_ROLE_ICON_SIZE or 18
local TOOLTIP_LAONONG_ICON_SIZE = GF.NON_ROLE_ICON_SIZE or 18
local TOOLTIP_SOCIAL_ICON_SIZE = GF.NON_ROLE_ICON_SIZE or 18
local TOOLTIP_MEMBER_ICON_NAME_GAP = "  "
local TOOLTIP_LEADER_ATLAS = GF.TOOLTIP_LEADER_ICON_ATLAS
local TOOLTIP_LEAVER_TEXTURE = GF.LEAVER_ICON_TEXTURE
local TOOLTIP_BLACKLIST_TEXTURE = GF.BLACKLIST_ICON_TEXTURE
local TOOLTIP_LAONONG_TEXTURE = GF.LAONONG_ICON_TEXTURE
local TOOLTIP_SOCIAL_TEXTURE = GF.SOCIAL_ICON_TEXTURE
local TOOLTIP_ROLE_ATLAS = GF.SEASON_DUNGEON_ROLE_ATLAS
local TOOLTIP_ROLE_PRIORITY = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local TOOLTIP_FACTION_TEXTURES = GF.FACTION_ICON_TEXTURES

local function isSecretLfgText(text)
	if GF.Result and GF.Result.IsSecretLfgText then
		return GF.Result:IsSecretLfgText(text)
	end
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, text)
	return ok and secret == true
end

local function getSearchResultInfo(resultID)
	if GF.Result and GF.Result.GetAuthoritativeSearchResultInfo then
		local info = GF.Result:GetAuthoritativeSearchResultInfo(resultID)
		if info then
			return info
		end
	end
	if not resultID or not C_LFGList or not C_LFGList.GetSearchResultInfo then
		return nil
	end
	return C_LFGList.GetSearchResultInfo(resultID)
end

local function colorText(text, color)
	text = tostring(text or "")
	if color and color.GenerateHexColorMarkup then
		return color:GenerateHexColorMarkup() .. text .. "|r"
	end
	if type(color) == "table" and color.colorStr then
		return "|c" .. color.colorStr .. text .. "|r"
	end
	if type(color) == "table" and color.r and color.g and color.b then
		return string.format(
			"|cff%02x%02x%02x%s|r",
			math.floor((color.r or 1) * 255 + 0.5),
			math.floor((color.g or 1) * 255 + 0.5),
			math.floor((color.b or 1) * 255 + 0.5),
			text
		)
	end
	return text
end

local function getColorRGB(color)
	if type(color) == "table" and color.GetRGB then
		local ok, r, g, b = pcall(color.GetRGB, color)
		if ok and r and g and b then
			return r, g, b
		end
	end
	if type(color) == "table" and color.GetRGBA then
		local ok, r, g, b = pcall(color.GetRGBA, color)
		if ok and r and g and b then
			return r, g, b
		end
	end
	if type(color) == "table" and color.r and color.g and color.b then
		return color.r, color.g, color.b
	end
end

local function makeTooltipColor(color, fallbackR, fallbackG, fallbackB)
	local r, g, b = getColorRGB(color)
	r, g, b = r or fallbackR or 1, g or fallbackG or 1, b or fallbackB or 1
	if CreateColor then
		return CreateColor(r, g, b, 1)
	end
	return {
		r = r,
		g = g,
		b = b,
		GetRGB = function(self)
			return self.r, self.g, self.b
		end,
	}
end

local function getTooltipFontString(tooltip, suffix, lineIndex)
	if not tooltip or not suffix or not lineIndex then
		return nil
	end
	local direct = tooltip[suffix .. lineIndex]
	if direct then
		return direct
	end
	local name = tooltip.GetName and tooltip:GetName()
	if name and name ~= "" then
		return _G[name .. suffix .. lineIndex]
	end
end

local function restoreLeaderScoreLines(tooltip)
	local lines = tooltip and tooltip._gfLeaderScoreTooltipLines
	if not lines then
		return
	end
	for lineIndex, line in pairs(lines) do
		local fs = getTooltipFontString(tooltip, "TextRight", lineIndex)
		local r, g, b = getColorRGB(line.color)
		if fs then
			if line.text and fs.SetText then
				fs:SetText(line.text)
			end
			if r and fs.SetTextColor then
				fs:SetTextColor(r, g, b, 1)
			end
		end
	end
end

local function addColoredDoubleLine(tooltip, label, value, rightColor)
	if not tooltip or not label or value == nil then
		return
	end
	local scoreColor = makeTooltipColor(rightColor, 1, 1, 1)
	if GameTooltip_AddColoredDoubleLine then
		GameTooltip_AddColoredDoubleLine(
			tooltip,
			tostring(label),
			tostring(value),
			makeTooltipColor(nil, GOLD_R, GOLD_G, GOLD_B),
			scoreColor,
			false
		)
		return
	end
	local r, g, b = getColorRGB(scoreColor)
	tooltip:AddDoubleLine(tostring(label), tostring(value), GOLD_R, GOLD_G, GOLD_B, r or 1, g or 1, b or 1)
end

local function addLeaderScoreLine(tooltip, label, scoreText, scoreColor)
	local displayText = colorText(scoreText, scoreColor)
	addColoredDoubleLine(tooltip, label, displayText, scoreColor)
	local lineIndex = tooltip.NumLines and tooltip:NumLines()
	if lineIndex then
		tooltip._gfLeaderScoreTooltipLines = tooltip._gfLeaderScoreTooltipLines or {}
		tooltip._gfLeaderScoreTooltipLines[lineIndex] = {
			text = displayText,
			color = scoreColor,
		}
	end
end

local function getClassColor(classFilename)
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	return classFilename and colors and colors[classFilename] or nil
end

local function addGoldDoubleLine(tooltip, label, value)
	if not tooltip or not label or value == nil then
		return
	end
	tooltip:AddDoubleLine(label, tostring(value), GOLD_R, GOLD_G, GOLD_B, 1, 1, 1)
end

local function getInlineAtlas(atlasName, size)
	if type(atlasName) ~= "string" or atlasName == "" then
		return nil
	end
	size = size or 16
	return string.format("|A:%s:%d:%d|a", atlasName, size, size)
end

local function getInlineTexture(texturePath, size)
	if type(texturePath) ~= "string" or texturePath == "" then
		return nil
	end
	size = size or 16
	return string.format("|T%s:%d:%d|t", texturePath, size, size)
end

local function normalizeTooltipRole(role)
	if type(role) ~= "string" then
		return nil
	end
	role = role:upper()
	if role == "HEAL" then
		return "HEALER"
	end
	if role == "DPS" then
		return "DAMAGER"
	end
	return role
end

local function getRoleIconMarkup(role)
	role = normalizeTooltipRole(role)
	local atlas = role and TOOLTIP_ROLE_ATLAS[role]
	return getInlineAtlas(atlas, TOOLTIP_ROLE_ICON_SIZE)
end

local function getMemberRolePriority(member)
	local role = normalizeTooltipRole(member and (member.assignedRole or member.role))
	return TOOLTIP_ROLE_PRIORITY[role] or 99
end

local function sortMembersByRole(members)
	local sorted = {}
	for index, member in ipairs(members or {}) do
		sorted[#sorted + 1] = {
			index = index,
			member = member,
		}
	end
	table.sort(sorted, function(a, b)
		local aPriority = getMemberRolePriority(a.member)
		local bPriority = getMemberRolePriority(b.member)
		if aPriority ~= bPriority then
			return aPriority < bPriority
		end
		return a.index < b.index
	end)
	for index, item in ipairs(sorted) do
		members[index] = item.member
	end
	return members
end

local function getMemberSpecName(member)
	local specName = member and member.specName
	if type(specName) == "string" and specName ~= "" then
		return specName
	end
	return UNKNOWN or "?"
end

local function getMemberCountSpecText(group)
	return string.format(
		"%s x%d",
		colorText(group and group.specName, group and group.classColor),
		tonumber(group and group.count) or 0
	)
end

local function getMemberCountRoleText(group)
	local rolePrefix = getRoleIconMarkup(group and group.role)
		or (group and group.role or "?")
	return string.format(
		"%s%s%s",
		rolePrefix,
		TOOLTIP_MEMBER_ICON_NAME_GAP,
		getMemberCountSpecText(group)
	)
end

local function appendMemberCountSummary(tooltip, info, members)
	local L = GF.L or {}
	members = members or {}
	if #members > 0 then
		local groups = {}
		local order = {}
		for _, member in ipairs(members) do
			local role = normalizeTooltipRole(member and (member.assignedRole or member.role))
			local specName = getMemberSpecName(member)
			local key = (role or "UNKNOWN") .. "\001" .. specName
			local group = groups[key]
			if not group then
				group = {
					role = role,
					specName = specName,
					count = 0,
					classColor = getClassColor(member and member.classFilename),
					index = #order + 1,
				}
				groups[key] = group
				order[#order + 1] = group
			end
			group.count = group.count + 1
			if not group.classColor then
				group.classColor = getClassColor(member and member.classFilename)
			end
		end
		table.sort(order, function(a, b)
			local aPriority = TOOLTIP_ROLE_PRIORITY[a.role] or 99
			local bPriority = TOOLTIP_ROLE_PRIORITY[b.role] or 99
			if aPriority ~= bPriority then
				return aPriority < bPriority
			end
			if a.specName ~= b.specName then
				return a.specName < b.specName
			end
			return a.index < b.index
		end)

		tooltip:AddLine(" ")
		tooltip:AddLine(L.LIST_TIP_MEMBERS_HEADER or "队伍成员", GOLD_R, GOLD_G, GOLD_B)
		if #order > 0 then
			local roleBuckets = {}
			local roleOrder = {}
			for _, group in ipairs(order) do
				local roleKey = group.role or "UNKNOWN"
				local bucket = roleBuckets[roleKey]
				if not bucket then
					bucket = {
						role = group.role,
						items = {},
					}
					roleBuckets[roleKey] = bucket
					roleOrder[#roleOrder + 1] = bucket
				end
				bucket.items[#bucket.items + 1] = group
			end
			for _, bucket in ipairs(roleOrder) do
				for index = 1, #bucket.items, 2 do
					local leftGroup = bucket.items[index]
					local rightGroup = bucket.items[index + 1]
					local leftText = getMemberCountRoleText(leftGroup)
					if rightGroup then
						tooltip:AddDoubleLine(leftText, getMemberCountSpecText(rightGroup), 1, 1, 1, 1, 1, 1)
					else
						tooltip:AddLine(leftText, 1, 1, 1, true)
					end
				end
			end
		else
			tooltip:AddLine(L.LIST_TIP_MEMBERS_LOADING or "成员信息加载中", 0.7, 0.7, 0.7, true)
		end
	elseif tonumber(info and info.numMembers) and (tonumber(info.numMembers) or 0) > 0 then
		tooltip:AddLine(" ")
		tooltip:AddLine(L.LIST_TIP_MEMBERS_LOADING or "成员信息加载中", 0.7, 0.7, 0.7, true)
	end
end

local function getLeaderIconMarkup()
	return getInlineAtlas(TOOLTIP_LEADER_ATLAS, TOOLTIP_LEADER_ICON_SIZE) or ""
end

local function getLeaverIconMarkup()
	return getInlineTexture(TOOLTIP_LEAVER_TEXTURE, TOOLTIP_LEAVER_ICON_SIZE) or ""
end

local function getBlacklistIconMarkup()
	return getInlineTexture(TOOLTIP_BLACKLIST_TEXTURE, TOOLTIP_BLACKLIST_ICON_SIZE) or ""
end

local function getLaonongIconMarkup()
	return getInlineTexture(TOOLTIP_LAONONG_TEXTURE, TOOLTIP_LAONONG_ICON_SIZE) or ""
end

local function getSocialIconMarkup()
	return getInlineTexture(TOOLTIP_SOCIAL_TEXTURE, TOOLTIP_SOCIAL_ICON_SIZE) or ""
end

local function findBlockedMemberRow(member)
	if not member or type(member.name) ~= "string" or member.name == "" then
		return nil
	end
	local bl = GF.Blocklist
	if not bl or not bl.IsEnabled or not bl:IsEnabled() or not bl.FindPlayerMatch then
		return nil
	end
	return bl:FindPlayerMatch(member.name)
end

local function isUnknownMemberName(name)
	name = strtrim and strtrim(tostring(name or "")) or tostring(name or "")
	if name == "" or name == "-" or name == "未知目标" or name == "Unknown" or name == "Unknown Target" then
		return true
	end
	if _G.UNKNOWNOBJECT and name == _G.UNKNOWNOBJECT then
		return true
	end
	if _G.UNKNOWN and name == _G.UNKNOWN then
		return true
	end
	if _G.UNKNOWNBEING and name == _G.UNKNOWNBEING then
		return true
	end
	return false
end

local function getDisplayName(name)
	if type(name) ~= "string" or name == "" then
		return "-"
	end
	if Ambiguate then
		return Ambiguate(name, "short")
	end
	return name:gsub("%-.+$", "")
end

local function splitMemberName(name)
	if type(name) ~= "string" or isSecretLfgText(name) then
		return nil, nil
	end
	if name == "" then
		return nil, nil
	end
	local shortName, realm = name:match("^([^-]+)%-(.+)$")
	if shortName and realm then
		return shortName, realm
	end
	return name, nil
end

local function getMemberLaonongFallbackRealm(info, member)
	if not member or type(member.name) ~= "string" or isSecretLfgText(member.name) then
		return nil
	end
	if member.name == "" then
		return nil
	end
	if member.name:find("-", 1, true) then
		return nil
	end
	if member.isLeader == true and info then
		local _, realm = splitMemberName(info.leaderName)
		return realm
	end
	return nil
end

local function isLeaderMember(info, member)
	if not member then
		return false
	end
	if member.isLeader == true then
		return true
	end
	local leaderName = info and info.leaderName
	if type(leaderName) ~= "string" or leaderName == "" then
		return false
	end
	if member.name == leaderName then
		return true
	end
	local leaderShortName = leaderName:match("^([^-]+)%-.+$") or leaderName
	local memberShortName = splitMemberName(member.name)
	return leaderShortName and memberShortName and memberShortName == leaderShortName
end

local function safeGetMemberCounts(resultID)
	if not resultID or not C_LFGList or not C_LFGList.GetSearchResultMemberCounts then
		return nil
	end
	local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, resultID)
	return ok and type(counts) == "table" and counts or nil
end

local function fetchMembersForTooltip(resultID, info)
	local members = {}
	local leaderClassFilename
	local hasLeaver = false
	local blockedMembers = {}
	local laonongMembers = {}
	local numMembers = tonumber(info and info.numMembers) or 0
	if not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then
		return members, nil, false, blockedMembers, laonongMembers
	end
	for i = 1, numMembers do
		local ok, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
		if ok and type(playerInfo) == "table" then
			playerInfo.displayName = playerInfo.displayName or getDisplayName(playerInfo.name)
			playerInfo.assignedRole = playerInfo.assignedRole or playerInfo.role
			playerInfo.classFilename = playerInfo.classFilename or playerInfo.classFileName or playerInfo.classFile
			if playerInfo.isLeaver then
				hasLeaver = true
			end
			if isLeaderMember(info, playerInfo) then
				leaderClassFilename = playerInfo.classFilename
			end
			local blockedRow = findBlockedMemberRow(playerInfo)
			if blockedRow then
				playerInfo._gfBlockedRow = blockedRow
				blockedMembers[#blockedMembers + 1] = playerInfo
			end
			if GF.IsLaonongFanName
				and GF.IsLaonongFanName(playerInfo.name, getMemberLaonongFallbackRealm(info, playerInfo), true)
			then
				playerInfo._gfLaonongFan = true
				laonongMembers[#laonongMembers + 1] = playerInfo
			end
			members[#members + 1] = playerInfo
		end
	end
	sortMembersByRole(members)
	sortMembersByRole(blockedMembers)
	sortMembersByRole(laonongMembers)
	return members, leaderClassFilename, hasLeaver, blockedMembers, laonongMembers
end

local function getAvailableSlots(info, activityInfo, counts)
	local maxMembers = tonumber(info and info.maxMembers)
	if not maxMembers or maxMembers <= 0 then
		maxMembers = tonumber(activityInfo and activityInfo.maxNumPlayers) or 5
	end
	if maxMembers <= 0 then
		maxMembers = 5
	end
	local total = (tonumber(counts and counts.TANK) or 0)
		+ (tonumber(counts and counts.HEALER) or 0)
		+ (tonumber(counts and counts.DAMAGER) or 0)
	if total <= 0 then
		total = tonumber(info and info.numMembers) or 0
	end
	return math.max(0, maxMembers - total), total, maxMembers
end

local function getScoreTextAndColor(info, activityInfo)
	local delistedColor = info and info.isDelisted and (LFG_LIST_DELISTED_FONT_COLOR or GRAY) or nil
	local text, color = GF.Result and GF.Result.GetBrowseScoreDisplay
		and GF.Result:GetBrowseScoreDisplay(info, activityInfo, delistedColor)
	if text then
		if color then
			return text, color
		end
		if GF.Result and GF.Result.GetDungeonScoreColor then
			return text, GF.Result:GetDungeonScoreColor(text, delistedColor)
		end
		return text, delistedColor or HIGHLIGHT_FONT_COLOR
	end
	local raw = tonumber(info and info.leaderOverallDungeonScore)
	if raw then
		local fallbackColor = delistedColor
		if not fallbackColor and GF.Result and GF.Result.GetDungeonScoreColor then
			fallbackColor = GF.Result:GetDungeonScoreColor(raw)
		end
		return tostring(math.floor(raw + 0.5)), fallbackColor or HIGHLIGHT_FONT_COLOR
	end
	return nil, nil
end

local function makeRunLevelWithIncrement(dungeonScoreInfo)
	if type(dungeonScoreInfo) ~= "table" or dungeonScoreInfo.bestRunLevel == nil then
		return nil
	end
	local plus = GROUPFINDER_PLUS or "+"
	local pluses = ""
	for _ = 1, math.max(0, tonumber(dungeonScoreInfo.bestLevelIncrement) or 0) do
		pluses = pluses .. plus
	end
	return pluses .. colorText(dungeonScoreInfo.bestRunLevel, HIGHLIGHT_FONT_COLOR)
end

local function getSpecificDungeonScoreColor(score, fallback)
	local cache = GF.MythicPlusRatingCache
	local rules = GF.MYTHIC_PLUS_SCORE_COLOR_RULE or {}
	if cache and cache.GetScoreColor then
		return cache:GetScoreColor(score, rules.SINGLE_DUNGEON) or fallback
	end
	return fallback
end

local function formatDungeonScoreInfo(dungeonScoreInfo, fallbackColor)
	local levelText = makeRunLevelWithIncrement(dungeonScoreInfo)
	if not levelText then
		return nil
	end
	local mapName = dungeonScoreInfo.mapName
	if type(mapName) == "string" and mapName ~= "" then
		local scoreColor = getSpecificDungeonScoreColor(
			dungeonScoreInfo.mapScore, fallbackColor)
		return levelText .. " " .. colorText(mapName, scoreColor)
	end
	return levelText
end

local function getRoleLabels()
	local L = GF.L or {}
	local labels = {}
	labels.DAMAGER = L.LIST_TIP_ROLE_DPS or DPS or "DPS"
	labels.HEALER = L.LIST_TIP_ROLE_HEALER or HEALER or "Healer"
	labels.TANK = L.LIST_TIP_ROLE_TANK or TANK or "Tank"
	return labels
end

local function getLeaderFactionIconMarkup(info)
	if not info or info.leaderFactionGroup == nil then
		return nil
	end
	if not PLAYER_FACTION_GROUP then
		return nil
	end
	local factionKey = PLAYER_FACTION_GROUP[info.leaderFactionGroup]
	if not factionKey then
		return nil
	end
	local texture = TOOLTIP_FACTION_TEXTURES[factionKey]
	return texture and getInlineTexture(texture, TOOLTIP_FACTION_ICON_SIZE)
end

local function colorizeLeaderName(leaderName, classFilename)
	if not leaderName then
		return nil
	end
	return colorText(leaderName, getClassColor(classFilename))
end

local function formatLeaderNameWithFaction(info, leaderName, classFilename)
	local text = colorizeLeaderName(leaderName, classFilename)
	local factionIcon = getLeaderFactionIconMarkup(info)
	if factionIcon and factionIcon ~= "" then
		text = (text or tostring(leaderName or "-")) .. " " .. factionIcon
	end
	return text
end

local appendMyKeyStoneHeader
local appendMyKeyStoneMembers
local appendLeaverMembers
local appendBlacklistMembers
local appendLaonongMembers
local appendFriendsInGroup
local appendMyKeyStoneComment

local function isPvpTooltipActivity(info, activityInfo)
	if activityInfo and (activityInfo.isPvpActivity or activityInfo.isRatedPvpActivity) then
		return true
	end
	local ratings = info and info.leaderPvpRatingInfo
	return type(ratings) == "table" and ratings[1] ~= nil
end

local function appendPvpLeaderLine(tooltip, info, leaderClassFilename)
	local L = GF.L or {}
	local leaderText = (info and info.leaderName and info.leaderName ~= "" and info.leaderName) or "-"
	local prefix = L.LIST_TIP_LEADER_PREFIX or "队长："
	addGoldDoubleLine(tooltip, prefix, formatLeaderNameWithFaction(info, leaderText, leaderClassFilename))
end

local function appendPvpRatingLine(tooltip, info, activityInfo)
	local ratingInfo, tierName
	if GF.Result and GF.Result.GetLeaderPvpRatingInfo then
		ratingInfo, tierName = GF.Result:GetLeaderPvpRatingInfo(info, activityInfo)
	end
	if not ratingInfo or not ratingInfo.rating then
		return
	end
	local L = GF.L or {}
	local activityName = ratingInfo.activityName
		or (activityInfo and (activityInfo.fullName or activityInfo.shortName or activityInfo.name))
		or L.PVP_RATING
		or "PVP"
	if activityName == "" then
		activityName = L.PVP_RATING or "PVP"
	end
	local ratingText = tostring(ratingInfo.rating)
	if tierName and tierName ~= "" then
		ratingText = string.format(L.LIST_TIP_PVP_RATING_TIER_FMT or "%s（%s）", ratingText, tierName)
	end
	local label = string.format(L.LIST_TIP_PVP_ACTIVITY_PREFIX_FMT or "%s：", activityName)
	addGoldDoubleLine(tooltip, label, colorText(ratingText, GF.GetPvpRatingColor(ratingInfo.rating)))
end

local function appendPvpMemberSummary(tooltip, resultID, info, activityInfo)
	local L = GF.L or {}
	local counts = safeGetMemberCounts(resultID) or {}
	local slots, totalMembers = getAvailableSlots(info, activityInfo, counts)
	addGoldDoubleLine(
		tooltip,
		L.LIST_TIP_MEMBERS_PREFIX or "队员：",
		string.format(
			"%d (%d/%d/%d)",
			totalMembers or tonumber(info and info.numMembers) or 0,
			tonumber(counts.TANK) or 0,
			tonumber(counts.HEALER) or 0,
			tonumber(counts.DAMAGER) or 0
		)
	)
	addGoldDoubleLine(tooltip, L.LIST_TIP_SLOTS_PREFIX or "空位：", slots or 0)
end

local function appendPvpCreatedLine(tooltip, info)
	local age = tonumber(info and info.age)
	if not age then
		return
	end
	local L = GF.L or {}
	local fmt = L.LIST_TIP_MINUTES_AGO_FMT or "%d 分钟前"
	local prefix = L.LIST_TIP_CREATED_PREFIX or "创建于："
	addGoldDoubleLine(tooltip, prefix, string.format(fmt, math.max(0, math.floor(age / 60))))
end

local function showPvpTooltip(tooltip, resultID, info, activityInfo, leaderClassFilename, members, hasLeaver, blockedMembers, laonongMembers, roleDisplayMode)
	tooltip:ClearLines()
	tooltip._gfLeaderScoreTooltipLines = nil
	appendMyKeyStoneHeader(tooltip, info, activityInfo)
	appendPvpLeaderLine(tooltip, info, leaderClassFilename)
	appendPvpRatingLine(tooltip, info, activityInfo)
	appendPvpMemberSummary(tooltip, resultID, info, activityInfo)
	appendPvpCreatedLine(tooltip, info)
	appendMyKeyStoneMembers(tooltip, info, members or {}, roleDisplayMode)
	appendBlacklistMembers(tooltip, blockedMembers)
	appendLeaverMembers(tooltip, members, hasLeaver)
	appendLaonongMembers(tooltip, laonongMembers)
	appendFriendsInGroup(tooltip, resultID, info, members)
	if info and info.isDelisted and LFG_LIST_ENTRY_DELISTED then
		tooltip:AddLine(" ")
		tooltip:AddLine(LFG_LIST_ENTRY_DELISTED, 1, 0.1, 0.1, true)
	end
	appendMyKeyStoneComment(tooltip, info, resultID)
	if GF.Font then
		GF.Font.ApplyTooltipFont(tooltip)
	end
	tooltip:Show()
end

local function appendCompletedEncounters(tooltip, resultID)
	local getEncounters = C_LFGList
		and C_LFGList.GetSearchResultEncounterInfo
	if type(getEncounters) ~= "function" then
		return
	end
	local encounters = getEncounters(resultID)
	if type(encounters) ~= "table" or next(encounters) == nil then
		return
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(LFG_LIST_BOSSES_DEFEATED)
	local color = RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }
	for encounterIndex = 1, #encounters do
		tooltip:AddLine(encounters[encounterIndex], color.r, color.g, color.b)
	end
end

local function hasSocialMembers(resultID, info)
	if not info then
		return false
	end
	if GF.ResolveSearchResultSocialCounts then
		local bnet, guild, friend = GF.ResolveSearchResultSocialCounts(info, resultID)
		return (bnet + guild + friend) > 0
	end
	local total = (info.numBNetFriends or 0) + (info.numCharFriends or 0)
	total = total + (info.numGuildMates or 0)
	return total > 0
end

local function findTooltipMemberByName(lookup, name)
	local usableLookup = type(lookup) == "table"
	local usableName = type(name) == "string" and name ~= ""
	if not usableLookup or not usableName then
		return nil
	end
	local direct = lookup[name]
	return direct or lookup[getDisplayName(name)]
end

local function buildTooltipMemberNameLookup(members)
	local lookup = {}
	for _, member in ipairs(members or {}) do
		if member and type(member.name) == "string" and member.name ~= "" then
			lookup[member.name] = member
			local displayName = getDisplayName(member.name)
			if displayName and displayName ~= "" then
				lookup[displayName] = member
			end
			if type(member.displayName) == "string" and member.displayName ~= "" then
				lookup[member.displayName] = member
			end
		end
	end
	return lookup
end

local function collectSearchResultFriendNames(resultID)
	local getFriends = C_LFGList and C_LFGList.GetSearchResultFriends
	if type(getFriends) ~= "function" then
		return nil
	end
	local bNetFriends, charFriends, guildMates = getFriends(resultID)
	local list = {}
	local seen = {}
	local function appendNames(names)
		for i = 1, #(names or {}) do
			local name = names[i]
			local seenKey = getDisplayName(name) or name
			if type(name) == "string" and name ~= "" and not seen[seenKey] then
				seen[seenKey] = true
				list[#list + 1] = name
			end
		end
	end
	appendNames(bNetFriends)
	appendNames(charFriends)
	appendNames(guildMates)
	if #list == 0 then
		return nil
	end
	return list
end

local function getFriendLineText(friendName, memberLookup)
	friendName = getDisplayName(friendName) or friendName
	if isUnknownMemberName(friendName) then
		return nil
	end
	local L = GF.L or {}
	local icon = getSocialIconMarkup()
	local prefix = L.LIST_TIP_FRIEND_PREFIX or "好友："
	local member = findTooltipMemberByName(memberLookup, friendName)
	local classColor = getClassColor(member and member.classFilename) or HIGHLIGHT_FONT_COLOR
	local socialColor = GF.SOCIAL_TEXT_COLOR or { r = 0.35, g = 0.75, b = 1 }
	return string.format(
		"%s%s%s",
		icon ~= "" and (icon .. " ") or "",
		colorText(prefix, socialColor),
		colorText(friendName, classColor)
	)
end

function appendFriendsInGroup(tooltip, resultID, info, members)
	if not hasSocialMembers(resultID, info) then
		return
	end
	local friends = collectSearchResultFriendNames(resultID)
	if not friends then
		return
	end
	local memberLookup = buildTooltipMemberNameLookup(members)
	local addedSpacer = false
	for _, friendName in ipairs(friends) do
		local lineText = getFriendLineText(friendName, memberLookup)
		if lineText then
			if not addedSpacer then
				tooltip:AddLine(" ")
				addedSpacer = true
			end
			tooltip:AddLine(lineText, 1, 1, 1, true)
		end
	end
end

local function getLeaverLineText(member)
	local memberName = member and (member.displayName or getDisplayName(member.name) or member.name)
	if isUnknownMemberName(memberName) then
		return nil
	end
	local L = GF.L or {}
	local icon = getLeaverIconMarkup()
	local prefix = L.LIST_TIP_LEAVER_PREFIX or L.TYPE_LEAVER or "逃兵："
	local classColor = getClassColor(member.classFilename) or HIGHLIGHT_FONT_COLOR
	return string.format(
		"%s%s%s",
		icon ~= "" and (icon .. " ") or "",
		colorText(prefix, RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }),
		colorText(memberName, classColor)
	)
end

local function getBlacklistLineText(member)
	local memberName = member and (member.displayName or getDisplayName(member.name) or member.name)
	if isUnknownMemberName(memberName) then
		return nil
	end
	local L = GF.L or {}
	local icon = getBlacklistIconMarkup()
	local prefix = L.LIST_TIP_BLACKLIST_PREFIX or L.TYPE_BLACKLIST or "黑名单："
	local classColor = getClassColor(member.classFilename) or HIGHLIGHT_FONT_COLOR
	return string.format(
		"%s%s%s",
		icon ~= "" and (icon .. " ") or "",
		colorText(prefix, RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }),
		colorText(memberName, classColor)
	)
end

local function getLaonongLineText(member)
	local memberName = member and (member.displayName or getDisplayName(member.name) or member.name)
	if isUnknownMemberName(memberName) then
		return nil
	end
	local L = GF.L or {}
	local icon = getLaonongIconMarkup()
	local prefix = L.LIST_TIP_LAONONG_PREFIX or "老农："
	local classColor = getClassColor(member.classFilename) or HIGHLIGHT_FONT_COLOR
	local laonongColor = GF.LAONONG_TEXT_COLOR or { r = GOLD_R, g = GOLD_G, b = GOLD_B }
	return string.format(
		"%s%s%s",
		icon ~= "" and (icon .. " ") or "",
		colorText(prefix, laonongColor),
		colorText(memberName, classColor)
	)
end

function appendBlacklistMembers(tooltip, members)
	if not members or #members == 0 then
		return
	end
	local addedSpacer = false
	for _, member in ipairs(members) do
		local lineText = getBlacklistLineText(member)
		if lineText then
			if not addedSpacer then
				tooltip:AddLine(" ")
				addedSpacer = true
			end
			tooltip:AddLine(lineText, 1, 1, 1, true)
		end
	end
end

function appendLeaverMembers(tooltip, members, hasLeaver)
	if not hasLeaver or not members then
		return
	end
	local addedSpacer = false
	for _, member in ipairs(members) do
		if member and member.isLeaver then
			local lineText = getLeaverLineText(member)
			if lineText then
				if not addedSpacer then
					tooltip:AddLine(" ")
					addedSpacer = true
				end
				tooltip:AddLine(lineText, 1, 1, 1, true)
			end
		end
	end
end

function appendLaonongMembers(tooltip, members)
	if not members or #members == 0 then
		return
	end
	local addedSpacer = false
	for _, member in ipairs(members) do
		local lineText = getLaonongLineText(member)
		if lineText then
			if not addedSpacer then
				tooltip:AddLine(" ")
				addedSpacer = true
			end
			tooltip:AddLine(lineText, 1, 1, 1, true)
		end
	end
end

local function rememberLaonongMembersForRow(resultID, entry, members)
	if not (resultID and members and members[1]) then
		return false
	end
	if not entry and GF.Result and GF.Result.GetEntryByResultID then
		entry = GF.Result:GetEntryByResultID(resultID)
	end
	if not (entry and GF.FindGroup and GF.FindGroup.CacheLaonongFanMember) then
		return false
	end
	return GF.FindGroup:CacheLaonongFanMember(entry, members[1]) == true
end

local function repaintLaonongTypeForRow(resultID, entry)
	if not (resultID and entry and GF.FindGroupTab and GF.FindGroupTab.ForEachVisibleRow
		and GF.ListRow and GF.ListRow.RepaintRowState)
	then
		return
	end
	GF.FindGroupTab:ForEachVisibleRow(function(row)
		if row and row.resultID == resultID then
			GF.ListRow:RepaintRowState(row, entry, row.categoryID)
		end
	end)
end

function appendMyKeyStoneHeader(tooltip, info, activityInfo)
	local title = info and info.name
	tooltip:AddLine((title and title ~= "" and title) or "-", 1, 1, 1, true)
	local activityName = activityInfo and (activityInfo.fullName or activityInfo.shortName or activityInfo.name)
	if activityName and activityName ~= "" then
		tooltip:AddLine(activityName, 0.2, 1, 0.2, true)
	end
	tooltip:AddLine(" ")
end

local function appendMyKeyStoneDetails(tooltip, resultID, info, activityInfo, leaderClassFilename)
	local L = GF.L or {}
	local counts = safeGetMemberCounts(resultID) or {}
	local slots, totalMembers = getAvailableSlots(info, activityInfo, counts)
	local leaderText = (info and info.leaderName and info.leaderName ~= "" and info.leaderName) or "-"
	addGoldDoubleLine(tooltip, L.LIST_TIP_LEADER_PREFIX or "队长：", formatLeaderNameWithFaction(info, leaderText, leaderClassFilename))

	local scoreText, scoreColor = getScoreTextAndColor(info, activityInfo)
	if scoreText then
		addLeaderScoreLine(
			tooltip,
			L.LIST_TIP_LEADER_SCORE_PREFIX or "队长大秘评分：",
			scoreText,
			scoreColor
		)
	end

	addGoldDoubleLine(
		tooltip,
		L.LIST_TIP_MEMBERS_PREFIX or "队员：",
		string.format(
			"%d (%d/%d/%d)",
			totalMembers or tonumber(info and info.numMembers) or 0,
			tonumber(counts.TANK) or 0,
			tonumber(counts.HEALER) or 0,
			tonumber(counts.DAMAGER) or 0
		)
	)
	addGoldDoubleLine(tooltip, L.LIST_TIP_SLOTS_PREFIX or "空位：", slots or 0)

	local requiredItemLevel = tonumber(info and info.requiredItemLevel)
	if requiredItemLevel and requiredItemLevel > 0 then
		addGoldDoubleLine(
			tooltip,
			L.LIST_TIP_REQUIRED_ILVL_PREFIX or "需要物品等级：",
			tostring(math.floor(requiredItemLevel + 0.5))
		)
	end

	local age = tonumber(info and info.age)
	if age then
		local fmt = L.LIST_TIP_MINUTES_AGO_FMT or "%d 分钟前"
		addGoldDoubleLine(
			tooltip,
			L.LIST_TIP_CREATED_PREFIX or "创建于：",
			string.format(fmt, math.max(0, math.floor(age / 60)))
		)
	end
end

local function appendMyKeyStoneBestRuns(tooltip, info, activityInfo)
	if not activityInfo or not activityInfo.isMythicPlusActivity then
		return
	end
	local bestDungeonScoreInfo = info and info.leaderDungeonScoreInfo and info.leaderDungeonScoreInfo[1]
	local _, scoreColor = getScoreTextAndColor(info, activityInfo)
	local bestDungeonText = formatDungeonScoreInfo(bestDungeonScoreInfo, scoreColor)
	local bestRunText = formatDungeonScoreInfo(info and info.leaderBestDungeonScoreInfo, scoreColor)
	if not bestDungeonText and not bestRunText then
		return
	end

	local L = GF.L or {}
	tooltip:AddLine(" ")
	if bestDungeonText then
		addGoldDoubleLine(tooltip, L.LIST_TIP_BEST_DUNGEON_PREFIX or "最佳副本：", bestDungeonText)
	end
	if bestRunText then
		addGoldDoubleLine(tooltip, L.LIST_TIP_BEST_RUN_PREFIX or "最佳成绩：", bestRunText)
	end
end

function appendMyKeyStoneMembers(tooltip, info, members, roleDisplayMode)
	local L = GF.L or {}
	members = members or {}
	local defaultMemberTooltipMode = GF.MEMBER_TOOLTIP_MODE_DEFAULT or GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
	local memberTooltipMode = GF.GetMemberTooltipMode and GF.GetMemberTooltipMode() or defaultMemberTooltipMode
	if roleDisplayMode == "count" and memberTooltipMode == (GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count") then
		appendMemberCountSummary(tooltip, info, members)
		return
	end
	if #members > 0 then
		tooltip:AddLine(" ")
		tooltip:AddLine(L.LIST_TIP_MEMBERS_HEADER or "队伍成员", GOLD_R, GOLD_G, GOLD_B)
		local shownMembers = 0
		local leaderIcon = getLeaderIconMarkup()
		for _, member in ipairs(members) do
			local memberName = member.displayName or member.name
			if not isUnknownMemberName(memberName) then
				local role = normalizeTooltipRole(member.assignedRole)
				local rolePrefix = getRoleIconMarkup(role)
					or (getRoleLabels()[role] or role or "?")
				local classColor = getClassColor(member.classFilename)
				local formattedName = colorText(memberName, classColor)
				if isLeaderMember(info, member) and leaderIcon ~= "" then
					formattedName = formattedName .. TOOLTIP_MEMBER_ICON_NAME_GAP .. leaderIcon
				end
				local leftText = rolePrefix .. TOOLTIP_MEMBER_ICON_NAME_GAP .. formattedName
				if member.specName and member.specName ~= "" then
					local r, g, b = getColorRGB(classColor)
					tooltip:AddDoubleLine(leftText, member.specName, 1, 1, 1, r or 1, g or 1, b or 1)
				else
					tooltip:AddLine(leftText, 1, 1, 1, true)
				end
				shownMembers = shownMembers + 1
			end
		end
		if shownMembers <= 0 then
			tooltip:AddLine(L.LIST_TIP_MEMBERS_LOADING or "成员信息加载中", 0.7, 0.7, 0.7, true)
		end
	elseif tonumber(info and info.numMembers) and (tonumber(info.numMembers) or 0) > 0 then
		tooltip:AddLine(" ")
		tooltip:AddLine(L.LIST_TIP_MEMBERS_LOADING or "成员信息加载中", 0.7, 0.7, 0.7, true)
	end
end

appendMyKeyStoneComment = function(tooltip, info, resultID)
	local comment = ""
	if GF.Result and GF.Result.GetListingComment then
		comment = GF.Result:GetListingComment(info, resultID)
	end
	local hasComment
	if GF.Result and GF.Result.HasRenderableListingComment then
		hasComment = GF.Result:HasRenderableListingComment(comment)
	elseif isSecretLfgText(comment) then
		hasComment = true
	else
		hasComment = comment ~= nil and comment ~= ""
	end
	if not hasComment then
		return
	end
	local c = GREEN_FONT_COLOR or LFG_LIST_COMMENT_FONT_COLOR or { r = 0.2, g = 1, b = 0.2 }
	tooltip:AddLine(" ")
	tooltip:AddLine(comment, c.r, c.g, c.b, true)
end

function LT:ShowMyKeyStoneStyle(tooltip, resultID)
	local info = getSearchResultInfo(resultID)
	local activities = info and info.activityIDs
	local primaryActivityID = activities and activities[1]
	if not primaryActivityID then
		return
	end
	local entry
	if GF.Result and GF.Result.GetSearchResultInvalidReason then
		local invalidReason = GF.Result:GetSearchResultInvalidReason(resultID, info)
		if invalidReason == "unavailable" and GF.Result.MarkSoftUnavailable then
			entry = GF.Result:MarkSoftUnavailable(resultID, info)
			if entry and entry.info then
				info = entry.info
			end
			if GF.FindGroupTab and GF.FindGroupTab.UpdateRowByResultID then
				GF.FindGroupTab:UpdateRowByResultID(resultID)
			end
		elseif invalidReason then
			if GF.FindGroupTab and GF.FindGroupTab.DropFrozenResult then
				if GF.FindGroupTab:DropFrozenResult(resultID) and GF.FindGroupTab.RefreshList then
					GF.FindGroupTab:RefreshList({ preserveScroll = true })
				end
			end
			return
		end
	end
	local shouldRefreshRow = false
	if GF.Result and GF.Result.IsUnreadableLfgText then
		local cached = GF.Result.entryCache and GF.Result.entryCache[resultID]
		local cachedInfo = cached and cached.info
		local commentBecameRenderable = cachedInfo
			and GF.Result.HasRenderableListingComment
			and not GF.Result:HasRenderableListingComment(cachedInfo.comment)
			and GF.Result:HasRenderableListingComment(info.comment)
		shouldRefreshRow = cachedInfo
			and (
				(GF.Result:IsUnreadableLfgText(cachedInfo.name) and not GF.Result:IsUnreadableLfgText(info.name))
				or (GF.Result:IsUnreadableLfgText(cachedInfo.comment) and not GF.Result:IsUnreadableLfgText(info.comment))
				or commentBecameRenderable
			)
	end
	if GF.Result and GF.Result.RefreshEntryInfo then
		entry = entry or GF.Result:RefreshEntryInfo(resultID, info)
		if entry and entry.info then
			info = entry.info
		else
			if GF.Result.IsDirtySearchResult and GF.Result:IsDirtySearchResult(resultID, info) then
				if GF.FindGroupTab and GF.FindGroupTab.DropFrozenResult then
					if GF.FindGroupTab:DropFrozenResult(resultID) and GF.FindGroupTab.RefreshList then
						GF.FindGroupTab:RefreshList({ preserveScroll = true })
					end
				end
			elseif GF.Result.MarkSoftUnavailable then
				entry = GF.Result:MarkSoftUnavailable(resultID, info)
				if entry and entry.info then
					info = entry.info
				end
			end
			return
		end
	end
	if shouldRefreshRow and GF.FindGroupTab and GF.FindGroupTab.UpdateRowByResultID then
		GF.FindGroupTab:UpdateRowByResultID(resultID)
	end
	if not entry and GF.Result and GF.Result.GetEntryByResultID then
		entry = GF.Result:GetEntryByResultID(resultID)
	end
	local roleDisplayMode = "count"
	if entry and GF.Result and GF.Result.GetRoleDisplayMode then
		roleDisplayMode = GF.Result:GetRoleDisplayMode(entry)
	end
	local activityInfo = C_LFGList.GetActivityInfoTable(info.activityIDs[1], nil, info.isWarMode)
	local members, leaderClassFilename, hasLeaver, blockedMembers, laonongMembers = fetchMembersForTooltip(resultID, info)
	if rememberLaonongMembersForRow(resultID, entry, laonongMembers) then
		repaintLaonongTypeForRow(resultID, entry)
	end

	if isPvpTooltipActivity(info, activityInfo) then
		showPvpTooltip(tooltip, resultID, info, activityInfo, leaderClassFilename, members, hasLeaver, blockedMembers, laonongMembers, roleDisplayMode)
		return
	end

	tooltip:ClearLines()
	tooltip._gfLeaderScoreTooltipLines = nil
	appendMyKeyStoneHeader(tooltip, info, activityInfo)
	appendMyKeyStoneDetails(tooltip, resultID, info, activityInfo, leaderClassFilename)
	appendMyKeyStoneBestRuns(tooltip, info, activityInfo)
	appendMyKeyStoneMembers(tooltip, info, members, roleDisplayMode)
	appendBlacklistMembers(tooltip, blockedMembers)
	appendLeaverMembers(tooltip, members, hasLeaver)
	appendLaonongMembers(tooltip, laonongMembers)
	appendCompletedEncounters(tooltip, resultID)
	appendFriendsInGroup(tooltip, resultID, info, members)
	if info.isDelisted and LFG_LIST_ENTRY_DELISTED then
		tooltip:AddLine(" ")
		tooltip:AddLine(LFG_LIST_ENTRY_DELISTED, 1, 0.1, 0.1, true)
	end
	appendMyKeyStoneComment(tooltip, info, resultID)

	if GF.Font then
		GF.Font.ApplyTooltipFont(tooltip)
	end
	tooltip:Show()
	restoreLeaderScoreLines(tooltip)
end

function LT:ShowFull(tooltip, resultID)
	self:ShowMyKeyStoneStyle(tooltip, resultID)
end

function LT:Show(tooltip, resultID, owner)
	if not tooltip or not resultID or not owner then
		return
	end
	tooltip:SetOwner(owner, "ANCHOR_RIGHT", 25, 0)
	if GF.Font and GF.Font.BeginTooltipFont then
		GF.Font.BeginTooltipFont(tooltip)
	end
	self:ShowFull(tooltip, resultID)
end
