local _, GF = ...
GF = GF.GF or GF

local LT = {}
GF.ListingTooltipView = LT
GF.ListTooltip = LT -- compatibility facade

local function presentationPort()
	return GF.ResultPresentationPort
end

local GOLD_R = 1
local GOLD_G = 0.82
local GOLD_B = 0

local function isRaidActivity(activity)
	local port = presentationPort()
	return port and port.IsRaidActivity and port:IsRaidActivity(activity) == true
end

local function getMembersHeader(activity)
	local L = GF.L or {}
	if isRaidActivity(activity) then
		return L.LIST_TIP_RAID_MEMBERS_HEADER or "团队成员"
	end
	return L.LIST_TIP_MEMBERS_HEADER or "队伍成员"
end

local TOOLTIP_ROLE_ICON_SIZE = GF.TOOLTIP_ROLE_ICON_SIZE or GF.ROLE_ICON_SIZE or 18
local TOOLTIP_LEADER_ICON_SIZE = TOOLTIP_ROLE_ICON_SIZE
local TOOLTIP_FACTION_ICON_SIZE = 14
local TOOLTIP_LEAVER_ICON_SIZE = TOOLTIP_ROLE_ICON_SIZE
local TOOLTIP_BLACKLIST_ICON_SIZE = GF.NON_ROLE_ICON_SIZE or 18
local TOOLTIP_SOCIAL_ICON_SIZE = TOOLTIP_ROLE_ICON_SIZE
local TOOLTIP_MEMBER_ICON_NAME_GAP = "  "
local TOOLTIP_LEADER_ATLAS = GF.TOOLTIP_LEADER_ICON_ATLAS
local TOOLTIP_LEAVER_TEXTURE = GF.LEAVER_ICON_TEXTURE
local TOOLTIP_BLACKLIST_TEXTURE = GF.BLACKLIST_ICON_TEXTURE
local TOOLTIP_SOCIAL_TEXTURE = GF.SOCIAL_ICON_TEXTURE
local TOOLTIP_ROLE_ATLAS = GF.SEASON_DUNGEON_ROLE_ATLAS
local TOOLTIP_ROLE_PRIORITY = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local TOOLTIP_FACTION_TEXTURES = GF.FACTION_ICON_TEXTURES

local function isSecretLfgText(text)
	local port = presentationPort()
	if port and port.IsSecretText then
		return port:IsSecretText(text)
	end
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, text)
	return ok and secret == true
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

local function appendMemberCountSummary(tooltip, info, members, activityInfo)
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
		tooltip:AddLine(getMembersHeader(activityInfo), GOLD_R, GOLD_G, GOLD_B)
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

local function getSocialIconMarkup(kind)
	local texture = GF.SOCIAL_TYPE_ICON_TEXTURE and GF.SOCIAL_TYPE_ICON_TEXTURE[kind]
	return getInlineTexture(texture or TOOLTIP_SOCIAL_TEXTURE, TOOLTIP_SOCIAL_ICON_SIZE) or ""
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

local function appendLaonongFanMembers(tooltip, info, members)
	local directory = GF.LaonongFanDirectory
	local fans = directory and directory:FindMembers(info, members)
	if not fans then return end
	tooltip:AddLine(" ")
	tooltip:AddLine((GF.L or {}).LIST_TIP_LAONONG_FANS or "老农粉丝",
		GOLD_R, GOLD_G, GOLD_B, true)
	local icon = getInlineTexture(GF.LAONONG_FAN_ICON_TEXTURE, TOOLTIP_ROLE_ICON_SIZE) or ""
	for _, name in ipairs(fans) do
		tooltip:AddLine(icon .. TOOLTIP_MEMBER_ICON_NAME_GAP .. name, GOLD_R, GOLD_G, GOLD_B, true)
	end
end

local function appendNetEaseIdentityMembers(tooltip, members)
	local service = GF.NetEaseIdentityService
	local finder = GF.FindGroup
	if not (tooltip and service and finder
		and type(finder.IsNetEaseIdentityBrowseEnabled) == "function"
		and finder:IsNetEaseIdentityBrowseEnabled() == true)
	then
		return
	end
	local rows = {}
	local L = GF.L or {}
	local goldColor = { r = GOLD_R, g = GOLD_G, b = GOLD_B }
	local function addIdentity(parts, icons, kind, text, color)
		local texture = GF.NETEASE_IDENTITY_ICON
			and GF.NETEASE_IDENTITY_ICON[kind]
		local icon = getInlineTexture(texture, TOOLTIP_ROLE_ICON_SIZE)
		if icon then
			icons[#icons + 1] = icon
		end
		parts[#parts + 1] = colorText(text, color)
	end
	for _, member in ipairs(members or {}) do
		local name = member and member.name
		local identity = service:GetIdentityProjection(
			name, { queue = true })
		if identity then
			local parts = {}
			local icons = {}
			if identity.fresh == true then
				if identity.isNewbie == true then
					addIdentity(parts, icons,
						GF.NETEASE_IDENTITY_NEWBIE,
						L.APPLICANT_TYPE_NETEASE_NEWBIE or "新兵",
						GREEN_FONT_COLOR or { r = 0, g = 1, b = 0 })
				end
				if identity.locomotiveLevel then
					addIdentity(parts, icons,
						GF.NETEASE_IDENTITY_LOCOMOTIVE,
						string.format(
							L.LIST_TIP_NETEASE_LOCOMOTIVE_LEVEL_FMT
								or "火车头 Lv%d",
							identity.locomotiveLevel), goldColor)
				end
				if identity.starLevel then
					addIdentity(parts, icons,
						GF.NETEASE_IDENTITY_STAR,
						string.format(
							L.LIST_TIP_NETEASE_STAR_LEVEL_FMT
								or "星团长 Lv%d",
							identity.starLevel), goldColor)
				end
				if identity.isVeteran == true then
					addIdentity(parts, icons,
						GF.NETEASE_IDENTITY_VETERAN,
						L.APPLICANT_TYPE_NETEASE_VETERAN or "老兵")
				end
			elseif identity.status == "offline" then
				parts[1] = colorText(
					L.TYPE_NETEASE_OFFLINE or "网易API离线",
					{ r = 0.55, g = 0.55, b = 0.55 })
			elseif identity.status == "fault" then
				parts[1] = colorText(
					L.TYPE_NETEASE_FAULT or "网易API故障",
					{ r = 1, g = 0.12, b = 0.08 })
			else
				parts[1] = L.TYPE_NETEASE_LOADING or "查询中"
			end
			if #icons == 0 then
				icons[1] = getInlineTexture(
					GF.NETEASE_SERVICE_ICON_TEXTURE, TOOLTIP_ROLE_ICON_SIZE)
			end
			local formattedName = colorText(
				member.displayName or getDisplayName(name) or name,
				getClassColor(member.classFilename))
			-- Use the member role/name layout so the left column reserves icon height.
			if #icons > 0 then
				formattedName = table.concat(icons, TOOLTIP_MEMBER_ICON_NAME_GAP)
					.. TOOLTIP_MEMBER_ICON_NAME_GAP .. formattedName
			end
			rows[#rows + 1] = {
				name = formattedName,
				identity = table.concat(parts, "  "),
			}
		end
	end
	if #rows == 0 then
		return
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(
		L.NETEASE_IDENTITY_TOOLTIP_TITLE or "网易玩家身份",
		GOLD_R, GOLD_G, GOLD_B)
	for _, row in ipairs(rows) do
		tooltip:AddDoubleLine(
			row.name, row.identity,
			1, 1, 1, 1, 1, 1)
	end
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

local function safeGetMemberCounts(resultID, entry, suppliedCounts)
	if type(suppliedCounts) == "table" then
		return suppliedCounts
	end
	local port = presentationPort()
	return port and port:GetMemberCounts(resultID, entry) or nil
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
	local port = presentationPort()
	local text, color
	if port then
		text, color = port:GetLeaderScorePresentation(info, activityInfo, delistedColor)
	end
	if text then
		if color then
			return text, color
		end
		if port then
			return text, port:GetDungeonScoreColor(text, delistedColor)
		end
		return text, delistedColor or HIGHLIGHT_FONT_COLOR
	end
	local raw = tonumber(info and info.leaderOverallDungeonScore)
	if raw then
		local fallbackColor = delistedColor
		if not fallbackColor and port then
			fallbackColor = port:GetDungeonScoreColor(raw)
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
	local port = presentationPort()
	if not info or not PLAYER_FACTION_GROUP or not (port and port.GetLeaderFactionGroup) then
		return nil
	end
	local factionGroup = port:GetLeaderFactionGroup(info)
	local factionKey = factionGroup ~= nil and PLAYER_FACTION_GROUP[factionGroup]
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
local appendFriendsInGroup
local appendMyKeyStoneComment

local function isPvpTooltipActivity(info, activityInfo)
	if activityInfo and (activityInfo.isPvpActivity or activityInfo.isRatedPvpActivity) then
		return true
	end
	local ratings = info and info.leaderPvpRatingInfo
	return type(ratings) == "table" and ratings[1] ~= nil
end

local function appendLeaderLine(tooltip, info, activityInfo, leaderText)
	local L = GF.L or {}
	local prefix = L.LIST_TIP_LEADER_PREFIX or "队长："
	local starred
	if isRaidActivity(activityInfo) then
		prefix = L.LIST_TIP_RAID_LEADER_PREFIX or "团长："
		local port = presentationPort()
		starred = port and port.GetStarredLeader and port:GetStarredLeader(info)
		if starred then prefix = GF.STARRED_LEADER_BADGE .. prefix end
	end
	addGoldDoubleLine(tooltip, prefix, leaderText)
	if starred and starred.note and starred.note ~= "" then
		tooltip:AddLine(GF.StarredLeaders:DisplayText(starred.note), 1, 1, 1, true)
	end
end

local function appendPvpLeaderLine(tooltip, info, activityInfo, leaderClassFilename)
	local leaderText = (info and info.leaderName and info.leaderName ~= "" and info.leaderName) or "-"
	appendLeaderLine(tooltip, info, activityInfo, formatLeaderNameWithFaction(info, leaderText, leaderClassFilename))
end

local function appendPvpRatingLine(tooltip, info, activityInfo)
	local ratingInfo, tierName
	local port = presentationPort()
	if port then
		ratingInfo, tierName = port:GetLeaderPvpRating(info, activityInfo)
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

local function appendPvpMemberSummary(
	tooltip, resultID, info, activityInfo, suppliedCounts)
	local L = GF.L or {}
	local counts = safeGetMemberCounts(
		resultID, nil, suppliedCounts) or {}
	local slots, totalMembers = getAvailableSlots(info, activityInfo, counts)
	addGoldDoubleLine(
		tooltip,
		L.LIST_TIP_MEMBERS_PREFIX or "成员：",
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

local function appendCensoredPvpRequirements(tooltip, info)
	local port = presentationPort()
	local censored = port and port:IsCensored(info)
	if not censored then
		return
	end
	local itemLevel = tonumber(info and info.requiredItemLevel)
	if itemLevel and itemLevel > 0 then
		local formatString = rawget(_G, "LFG_LIST_TOOLTIP_ILVL_PVP")
		tooltip:AddLine(
			formatString and formatString:format(itemLevel)
				or string.format("需要物品等级：%d", math.floor(itemLevel + 0.5)),
			1, 1, 1, true)
	end
	local pvpRating = tonumber(info and info.requiredPvpRating)
	if pvpRating and pvpRating > 0 then
		local formatString = rawget(_G, "GROUP_FINDER_PVP_RATING_REQ_TOOLTIP")
		tooltip:AddLine(
			formatString and formatString:format(pvpRating)
				or string.format("需要 PvP 评分：%d", math.floor(pvpRating + 0.5)),
			1, 1, 1, true)
	end
end

local function showPvpTooltip(
	tooltip,
	resultID,
	info,
	activityInfo,
	leaderClassFilename,
	members,
	hasLeaver,
	blockedMembers,
	roleDisplayMode,
	memberCounts,
	friendNames,
	friendRelationships)
	tooltip:ClearLines()
	tooltip._gfLeaderScoreTooltipLines = nil
	appendMyKeyStoneHeader(tooltip, info, activityInfo)
	appendPvpLeaderLine(tooltip, info, activityInfo, leaderClassFilename)
	appendPvpRatingLine(tooltip, info, activityInfo)
	appendPvpMemberSummary(
		tooltip, resultID, info, activityInfo, memberCounts)
	appendCensoredPvpRequirements(tooltip, info)
	appendPvpCreatedLine(tooltip, info)
	appendMyKeyStoneMembers(tooltip, info, members or {}, roleDisplayMode, activityInfo)
	appendNetEaseIdentityMembers(tooltip, members)
	appendLaonongFanMembers(tooltip, info, members)
	appendBlacklistMembers(tooltip, blockedMembers)
	appendLeaverMembers(tooltip, members, hasLeaver)
	appendFriendsInGroup(
		tooltip, resultID, info, members, friendNames, friendRelationships)
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

local function appendCompletedEncounters(tooltip, resultID, suppliedEncounters)
	local port = presentationPort()
	local encounters = type(suppliedEncounters) == "table"
		and suppliedEncounters
		or (port and port:GetCompletedEncounters(resultID) or nil)
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

local function appendRaidProgress(tooltip, progress)
	if not progress then return false end
	tooltip:AddLine(" ")
	addColoredDoubleLine(tooltip,
		(GF.L or {}).LIST_TIP_INSTANCE_PROGRESS or "Instance Progress", progress.text)
	local colors = GF.BROWSE_RAID_PROGRESS_COLORS
	for _, boss in ipairs(progress.bosses) do
		local status, statusColor = UNKNOWN or "?", colors.unknown
		if boss.defeated == true then
			status, statusColor = BOSS_DEAD, colors.killed
		elseif boss.defeated == false then
			status, statusColor = BOSS_ALIVE, colors.clear
		end
		local nameColor = boss.defeated == true and colors.defeatedName or colors.name
		tooltip:AddDoubleLine(nameColor .. boss.name .. "|r",
			statusColor .. (status or UNKNOWN or "?") .. "|r", 1, 1, 1, 1, 1, 1)
	end
	return true
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

local function collectSearchResultFriendNames(
	resultID, suppliedNames, suppliedRelationships)
	local port = presentationPort()
	local sourceNames, relationships = suppliedNames, suppliedRelationships
	if type(sourceNames) ~= "table" and port then
		sourceNames, relationships = port:GetFriendNames(resultID)
	end
	local list = {}
	local seen = {}
	local function appendNames(names)
		for i = 1, #(names or {}) do
			local name = names[i]
			if type(name) == "string" and name ~= "" and not seen[name] then
				seen[name] = true
				list[#list + 1] = name
			end
		end
	end
	appendNames(sourceNames)
	if #list == 0 then
		return nil
	end
	return list, relationships or {}
end

local function getFriendLineText(friendName, memberLookup, kind)
	local displayName = getDisplayName(friendName) or friendName
	if isUnknownMemberName(displayName) then
		return nil
	end
	local L = GF.L or {}
	local member = findTooltipMemberByName(memberLookup, friendName)
	kind = kind or (GF.GetSocialRelationshipType
		and GF.GetSocialRelationshipType(member and member.relationship))
		or GF.SOCIAL_TYPE_FRIEND
	local icon = getSocialIconMarkup(kind)
	local labelKey = GF.SOCIAL_APPLICANT_LABEL_KEY and GF.SOCIAL_APPLICANT_LABEL_KEY[kind]
	local label = labelKey and L[labelKey]
		or (GF.SOCIAL_APPLICANT_LABEL_FALLBACK and GF.SOCIAL_APPLICANT_LABEL_FALLBACK[kind])
		or L.APPLICANT_TYPE_FRIEND or "好友"
	local classColor = getClassColor(member and member.classFilename) or HIGHLIGHT_FONT_COLOR
	local socialColor = (GF.GetSocialTypeTextColor and GF.GetSocialTypeTextColor(kind))
		or GF.SOCIAL_TEXT_COLOR or { r = 0.35, g = 0.75, b = 1 }
	local nameText = (icon ~= "" and (icon .. TOOLTIP_MEMBER_ICON_NAME_GAP) or "")
		.. colorText(displayName, classColor)
	return nameText, colorText(label, socialColor)
end

function appendFriendsInGroup(
	tooltip, resultID, info, members, suppliedNames, suppliedRelationships)
	if not hasSocialMembers(resultID, info) then
		return
	end
	local friends, relationships = collectSearchResultFriendNames(
		resultID, suppliedNames, suppliedRelationships)
	if not friends then
		return
	end
	local memberLookup = buildTooltipMemberNameLookup(members)
	local addedSpacer = false
	for _, friendName in ipairs(friends) do
		local lineText, relationshipText = getFriendLineText(
			friendName, memberLookup, relationships[friendName])
		if lineText then
			if not addedSpacer then
				tooltip:AddLine(" ")
				addedSpacer = true
			end
			tooltip:AddDoubleLine(lineText, relationshipText, 1, 1, 1, 1, 1, 1)
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
	local classColor = getClassColor(member.classFilename) or HIGHLIGHT_FONT_COLOR
	local nameText = (icon ~= "" and (icon .. TOOLTIP_MEMBER_ICON_NAME_GAP) or "")
		.. colorText(memberName, classColor)
	return nameText, colorText(L.LIST_TIP_LEAVER_LABEL or "逃兵",
		RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 })
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
			local lineText, statusText = getLeaverLineText(member)
			if lineText then
				if not addedSpacer then
					tooltip:AddLine(" ")
					addedSpacer = true
				end
				tooltip:AddDoubleLine(lineText, statusText, 1, 1, 1, 1, 1, 1)
			end
		end
	end
end

local function appendPlaystyleAndFaction(tooltip, info, activityInfo)
	local port = presentationPort()
	local presentation = port
		and port:GetPlaystylePresentation(info, activityInfo) or nil
	if not presentation then
		return
	end
	local playstyle = presentation.text
	local faction = presentation.faction
	local color = GREEN_FONT_COLOR or { r = 0.2, g = 1, b = 0.2 }
	if faction and GROUP_FINDER_CROSS_FACTION_LISTING_WITH_PLAYSTLE then
		tooltip:AddLine(
			GROUP_FINDER_CROSS_FACTION_LISTING_WITH_PLAYSTLE:format(
				playstyle, faction),
			color.r, color.g, color.b, true)
	else
		tooltip:AddLine(playstyle, color.r, color.g, color.b, true)
	end
	if faction and GROUP_FINDER_CROSS_FACTION_LISTING_WITHOUT_PLAYSTLE then
		tooltip:AddLine(
			GROUP_FINDER_CROSS_FACTION_LISTING_WITHOUT_PLAYSTLE:format(faction),
			color.r, color.g, color.b, true)
	end
end

function appendMyKeyStoneHeader(tooltip, info, activityInfo)
	local port = presentationPort()
	local censored = port and port:IsCensored(info)
	local title
	if censored then
		local locale = GF.L or {}
		title = rawget(_G, "CENSORED_LFG_GROUP_NAME")
			or locale.CENSORED_RESULT_HIDDEN_TITLE
			or "招募内容已隐藏"
	else
		title = port and port:GetListingTitle(info) or (info and info.name)
	end
	if censored then
		tooltip:AddLine((title and title ~= "" and title) or "-", 1, 0.1, 0.1, true)
	else
		tooltip:AddLine((title and title ~= "" and title) or "-", 1, 1, 1, true)
	end
	local activityName = activityInfo and (activityInfo.fullName or activityInfo.shortName or activityInfo.name)
	if activityName and activityName ~= "" then
		tooltip:AddLine(activityName, 0.2, 1, 0.2, true)
	end
	local censored = port and port:IsCensored(info)
	if censored then
		appendPlaystyleAndFaction(tooltip, info, activityInfo)
	end
	tooltip:AddLine(" ")
end

local function appendMyKeyStoneDetails(
	tooltip,
	resultID,
	info,
	activityInfo,
	leaderClassFilename,
	suppliedCounts,
	showRaidProgress)
	local L = GF.L or {}
	local counts = safeGetMemberCounts(
		resultID, nil, suppliedCounts) or {}
	local slots, totalMembers = getAvailableSlots(info, activityInfo, counts)
	local leaderText = (info and info.leaderName and info.leaderName ~= "" and info.leaderName) or "-"
	appendLeaderLine(tooltip, info, activityInfo, formatLeaderNameWithFaction(info, leaderText, leaderClassFilename))

	local scoreText, scoreColor
	if not showRaidProgress then
		scoreText, scoreColor = getScoreTextAndColor(info, activityInfo)
	end
	if scoreText then
		local prefix = L.LIST_TIP_LEADER_SCORE_PREFIX or "队长大秘评分："
		if isRaidActivity(activityInfo) then
			prefix = L.LIST_TIP_RAID_LEADER_SCORE_PREFIX or "团长大秘评分："
		end
		addLeaderScoreLine(
			tooltip,
			prefix,
			scoreText,
			scoreColor
		)
	end

	addGoldDoubleLine(
		tooltip,
		L.LIST_TIP_MEMBERS_PREFIX or "成员：",
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

	local port = presentationPort()
	local censored = port and port:IsCensored(info)
	local requiredDungeonScore = censored
		and tonumber(info and info.requiredDungeonScore)
	if requiredDungeonScore and requiredDungeonScore > 0 then
		local formatString = rawget(_G, "GROUP_FINDER_MYTHIC_RATING_REQ_TOOLTIP")
		if formatString then
			tooltip:AddLine(formatString:format(requiredDungeonScore), 1, 1, 1, true)
		else
			addGoldDoubleLine(
				tooltip,
				L.LIST_TIP_REQUIRED_SCORE_PREFIX or "需要大秘境评分：",
				tostring(math.floor(requiredDungeonScore + 0.5)))
		end
	end

	local requiredPvpRating = censored
		and tonumber(info and info.requiredPvpRating)
	if requiredPvpRating and requiredPvpRating > 0 then
		local formatString = rawget(_G, "GROUP_FINDER_PVP_RATING_REQ_TOOLTIP")
		if formatString then
			tooltip:AddLine(formatString:format(requiredPvpRating), 1, 1, 1, true)
		else
			addGoldDoubleLine(
				tooltip,
				L.LIST_TIP_REQUIRED_PVP_RATING_PREFIX or "需要 PvP 评分：",
				tostring(math.floor(requiredPvpRating + 0.5)))
		end
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

function appendMyKeyStoneMembers(tooltip, info, members, roleDisplayMode, activityInfo)
	local L = GF.L or {}
	members = members or {}
	local defaultMemberTooltipMode = GF.MEMBER_TOOLTIP_MODE_DEFAULT or GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
	local memberTooltipMode = GF.GetMemberTooltipMode and GF.GetMemberTooltipMode() or defaultMemberTooltipMode
	if roleDisplayMode == "count" and memberTooltipMode == (GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count") then
		appendMemberCountSummary(tooltip, info, members, activityInfo)
		return
	end
	if #members > 0 then
		tooltip:AddLine(" ")
		tooltip:AddLine(getMembersHeader(activityInfo), GOLD_R, GOLD_G, GOLD_B)
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
	local port = presentationPort()
	local censored = port and port:IsCensored(info)
	if censored then
		local locale = GF.L or {}
		local comment = rawget(_G, "CENSORED_LFG_COMMENT")
			or locale.CENSORED_RESULT_COMMENT
			or "该招募内容需要点击查看。"
		local c = GREEN_FONT_COLOR or LFG_LIST_COMMENT_FONT_COLOR
			or { r = 0.2, g = 1, b = 0.2 }
		tooltip:AddLine(" ")
		tooltip:AddLine(comment, c.r, c.g, c.b, true)
		return
	end
	local comment = ""
	if port then
		comment = port:GetListingComment(info, resultID)
	end
	local hasComment
	if port then
		hasComment = port:HasRenderableComment(comment)
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

function LT:ShowMyKeyStoneStyle(tooltip, resultID, application, options)
	local port = presentationPort()
	if not port then
		return
	end
	local snapshot, _, directive = port:BuildTooltipSnapshot(resultID, application)
	if not snapshot then
		if directive and directive.retire
		and GF.FindGroupTab
		then
			if directive.expired == true
				and GF.FindGroupTab.BeginExpiredResultRetirement
			then
				GF.FindGroupTab:BeginExpiredResultRetirement(
					resultID, directive.info)
			else
				local retire = GF.FindGroupTab.RetireExpiredResult
					or GF.FindGroupTab.DropFrozenResult
				if retire and retire(GF.FindGroupTab, resultID)
					and GF.FindGroupTab.RefreshList
				then
					GF.FindGroupTab:RefreshList({ preserveScroll = true })
				end
			end
		end
		return
	end
	if snapshot.refreshRow and not (options and options.skipRowRefresh)
		and GF.FindGroupTab and GF.FindGroupTab.UpdateRowByResultID
	then
		self._refreshingRowFromTooltip = true
		local ok, changed = pcall(GF.FindGroupTab.UpdateRowByResultID,
			GF.FindGroupTab, resultID, snapshot.info)
		self._refreshingRowFromTooltip = nil
		if not ok then error(changed, 0) end
		if changed and GF.FindGroupTab.RefreshList then
			GF.FindGroupTab:RefreshList({ preserveScroll = true })
		end
	end
	local info = snapshot.info
	local roleDisplayMode = snapshot.roleDisplayMode
	local activityInfo = snapshot.activity
	local members = snapshot.members or {}
	local leaderClassFilename = snapshot.leaderClassFilename
	local hasLeaver = snapshot.hasLeaver == true
	local blockedMembers = snapshot.blockedMembers or {}

	if isPvpTooltipActivity(info, activityInfo) then
		showPvpTooltip(
			tooltip,
			resultID,
			info,
			activityInfo,
			leaderClassFilename,
			members,
			hasLeaver,
			blockedMembers,
			roleDisplayMode,
			snapshot.memberCounts,
			snapshot.friendNames,
			snapshot.friendRelationships)
		return true
	end

	tooltip:ClearLines()
	tooltip._gfLeaderScoreTooltipLines = nil
	appendMyKeyStoneHeader(tooltip, info, activityInfo)
	appendMyKeyStoneDetails(
		tooltip,
		resultID,
		info,
		activityInfo,
		leaderClassFilename,
		snapshot.memberCounts,
		snapshot.raidProgress ~= nil)
	appendMyKeyStoneBestRuns(tooltip, info, activityInfo)
	appendMyKeyStoneMembers(tooltip, info, members, roleDisplayMode, activityInfo)
	appendNetEaseIdentityMembers(tooltip, members)
	appendLaonongFanMembers(tooltip, info, members)
	appendBlacklistMembers(tooltip, blockedMembers)
	appendLeaverMembers(tooltip, members, hasLeaver)
	if not appendRaidProgress(tooltip, snapshot.raidProgress) then
		appendCompletedEncounters(tooltip, resultID, snapshot.completedEncounters)
	end
	appendFriendsInGroup(
		tooltip, resultID, info, members, snapshot.friendNames, snapshot.friendRelationships)
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
	return true
end

function LT:ShowFull(tooltip, resultID, application, options)
	return self:ShowMyKeyStoneStyle(tooltip, resultID, application, options)
end

function LT:Show(tooltip, resultID, owner, application, options)
	if not tooltip or not resultID or not owner then
		return
	end
	tooltip:SetOwner(owner, "ANCHOR_RIGHT", 25, 0)
	if GF.Font and GF.Font.BeginTooltipFont then
		GF.Font.BeginTooltipFont(tooltip)
	end
	return self:ShowFull(tooltip, resultID, application, options)
end

function LT:ShowCurrentGroupProjection(tooltip, elementData, owner)
	if not (tooltip and type(elementData) == "table" and owner) then
		return false
	end
	local projection = GF.CurrentGroupProjection
	if projection and type(projection.GetLiveActionTarget) == "function" then
		local _, liveResultID = projection:GetLiveActionTarget(elementData)
		if liveResultID then
			self:Show(tooltip, liveResultID, owner)
			return true
		end
	end
	local entry = elementData.entry
	local info = entry and entry.info
	if type(info) ~= "table" then
		return false
	end
	tooltip:SetOwner(owner, "ANCHOR_RIGHT", 25, 0)
	if GF.Font and GF.Font.BeginTooltipFont then
		GF.Font.BeginTooltipFont(tooltip)
	end
	tooltip:ClearLines()
	local title = elementData.displayName
	local titleIsSecret = isSecretLfgText(title)
	if not titleIsSecret and title == nil then
		-- The projection already owns the only safe snapshot fallback. Calling
		-- GetListingTitle without a live result ID would try to reinterpret an
		-- old search-scope kstring and can turn the real name into Unknown Target.
		title = info.name
		titleIsSecret = isSecretLfgText(title)
	end
	if titleIsSecret then
		tooltip:AddLine(title, GOLD_R, GOLD_G, GOLD_B, true)
	else
		local safeTitle = type(title) == "string" and title ~= "" and title
			or UNKNOWN or "?"
		tooltip:AddLine(safeTitle, GOLD_R, GOLD_G, GOLD_B, true)
	end
	local locale = GF.L or {}
	local currentLabel = locale.TYPE_CURRENT_GROUP or "当前队伍"
	local currentColor = GF.SOCIAL_TEXT_COLOR or { r = 0.35, g = 0.75, b = 1 }
	tooltip:AddLine(
		tostring(currentLabel),
		currentColor.r or currentColor[1] or 0.35,
		currentColor.g or currentColor[2] or 0.75,
		currentColor.b or currentColor[3] or 1)
	local activity = entry.activity
	local activityName = activity and (activity.fullName or activity.shortName)
	if type(activityName) == "string" and activityName ~= "" then
		addGoldDoubleLine(
			tooltip,
			locale.LIST_TIP_ACTIVITY or LFG_LIST_ACTIVITY or "活动",
			activityName)
	end
	local leaderName = info.leaderName
	if type(leaderName) == "string" and leaderName ~= ""
		and not isSecretLfgText(leaderName)
	then
		appendLeaderLine(tooltip, info, activity, leaderName)
	end
	local memberCount = tonumber(info.numMembers)
	if memberCount then
		addGoldDoubleLine(
			tooltip,
			getMembersHeader(activity),
			math.max(0, math.floor(memberCount + 0.0001)))
	end
	appendNetEaseIdentityMembers(
		tooltip,
		type(entry.players) == "table" and entry.players or {})
	appendLaonongFanMembers(tooltip, info, entry.players)
	local port = presentationPort()
	if port and port.GetRaidProgressPresentation then
		-- The snapshot fallback has no trustworthy result ID in this source.
		appendRaidProgress(tooltip, port:GetRaidProgressPresentation(nil, info, activity))
	end
	local comment = elementData.displayComment
	local commentIsSecret = isSecretLfgText(comment)
	if not commentIsSecret and comment == nil then
		comment = info.comment
		commentIsSecret = isSecretLfgText(comment)
	end
	local hasComment = commentIsSecret
	if not hasComment then
		hasComment = type(comment) == "string" and comment ~= ""
	end
	if hasComment then
		local color = GREEN_FONT_COLOR or { r = 0.2, g = 1, b = 0.2 }
		tooltip:AddLine(" ")
		tooltip:AddLine(comment, color.r, color.g, color.b, true)
	end
	if GF.Font and GF.Font.ApplyTooltipFont then
		GF.Font.ApplyTooltipFont(tooltip)
	end
	tooltip:Show()
	return true
end
