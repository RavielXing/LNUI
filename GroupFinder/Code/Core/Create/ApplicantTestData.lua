local _, GF = ...

GF.ApplicantTestData = GF.ApplicantTestData or {}
local ATD = GF.ApplicantTestData

_G.GROUPFINDER_APPLICANT_TEST_ROWS_ENABLED = _G.GROUPFINDER_APPLICANT_TEST_ROWS_ENABLED == true
_G.GROUPFINDER_APPLICANT_SCROLL_TEST_EXTRA_ROWS = tonumber(_G.GROUPFINDER_APPLICANT_SCROLL_TEST_EXTRA_ROWS) or 12
_G.GROUPFINDER_APPLICANT_TEST_SCENARIO = _G.GROUPFINDER_APPLICANT_TEST_SCENARIO or "full"

local TEST_ID_BASE = 2000000000
local TEST_EXTRA_ID_BASE = TEST_ID_BASE + 100
local TEST_GROUP_ID = TEST_ID_BASE + 9001

local ACTIVITY_FIXTURES = {
	mplus = {
		isMythicPlusActivity = true,
		isRatedPvpActivity = false,
		isPvpActivity = false,
		isCurrentRaidActivity = false,
		maxNumPlayers = 5,
		shortName = "千丝之城",
		fullName = "千丝之城",
	},
	pvp = {
		isMythicPlusActivity = false,
		isRatedPvpActivity = true,
		isPvpActivity = true,
		isCurrentRaidActivity = false,
		maxNumPlayers = 10,
		shortName = "评级战场",
		fullName = "评级战场",
		groupFinderActivityGroupID = 4,
	},
	raid = {
		isMythicPlusActivity = false,
		isRatedPvpActivity = false,
		isPvpActivity = false,
		isCurrentRaidActivity = true,
		maxNumPlayers = 20,
		shortName = "法力熔炉：欧米伽",
		fullName = "法力熔炉：欧米伽",
	},
	generic = {
		isMythicPlusActivity = false,
		isRatedPvpActivity = false,
		isPvpActivity = false,
		isCurrentRaidActivity = false,
		maxNumPlayers = 5,
		shortName = "自定义队伍",
		fullName = "自定义队伍",
	},
	lowlevel = {
		isMythicPlusActivity = false,
		isRatedPvpActivity = false,
		isPvpActivity = false,
		isCurrentRaidActivity = false,
		maxNumPlayers = 5,
		shortName = "时空漫游地下城",
		fullName = "时空漫游地下城",
	},
}

local DEFAULT_ACTIVITY_INFO = ACTIVITY_FIXTURES.mplus

local TEST_SPECS = {
	{ specID = 73, specText = "防护", className = "战士", class = "WARRIOR", role = "TANK" },
	{ specID = 257, specText = "神圣", className = "牧师", class = "PRIEST", role = "HEALER" },
	{ specID = 63, specText = "火焰", className = "法师", class = "MAGE", role = "DAMAGER" },
	{ specID = 1480, specText = "噬灭", className = "恶魔猎手", class = "DEMONHUNTER", role = "DAMAGER" },
	{ specID = 104, specText = "守护", className = "德鲁伊", class = "DRUID", role = "TANK" },
	{ specID = 270, specText = "织雾", className = "武僧", class = "MONK", role = "HEALER" },
	{ specID = 254, specText = "射击", className = "猎人", class = "HUNTER", role = "DAMAGER" },
	{ specID = 262, specText = "元素", className = "萨满祭司", class = "SHAMAN", role = "DAMAGER" },
	{ specID = 70, specText = "惩戒", className = "圣骑士", class = "PALADIN", role = "DAMAGER" },
	{ specID = 250, specText = "鲜血", className = "死亡骑士", class = "DEATHKNIGHT", role = "TANK" },
	{ specID = 1468, specText = "恩护", className = "唤魔师", class = "EVOKER", role = "HEALER" },
	{ specID = 260, specText = "狂徒", className = "潜行者", class = "ROGUE", role = "DAMAGER" },
}

local TEST_ROWS = {
	{
		id = TEST_ID_BASE + 1,
		basic = true,
		name = "钥石老兵",
		activityKind = "mplus",
		specIndex = 4,
		score = 3186,
		mapScore = 3042,
		keyLevel = 15,
		ilvl = 712,
		comment = "熟路线，能开麦，来稳定限时。",
		isNew = true,
	},
	{
		id = TEST_ID_BASE + 2,
		basic = true,
		name = "评级指挥",
		activityKind = "pvp",
		specIndex = 9,
		pvpRating = 2210,
		pvpTier = 7,
		pvpItemLevel = 724,
		honorLevel = 146,
		ilvl = 711,
		factionGroup = 0,
		showFactionIcon = true,
		relationship = "bnet",
		comment = "评级场，听指挥，可语音。",
	},
	{
		id = TEST_ID_BASE + 3,
		basic = true,
		name = "公会治疗",
		activityKind = "raid",
		specIndex = 11,
		ratingValue = 8,
		ilvl = 708,
		relationship = "guild",
		comment = "公会成员申请，测试蓝色行与团本 tooltip。",
	},
	{
		id = TEST_ID_BASE + 4,
		basic = true,
		name = "跳车刺客",
		activityKind = "mplus",
		specIndex = 12,
		score = 3392,
		mapScore = 3218,
		keyLevel = 16,
		ilvl = 714,
		isLeaver = true,
		comment = "逃兵标记测试：类型列与红色底纹。",
	},
	{
		id = TEST_ID_BASE + 5,
		basic = true,
		name = "屏蔽对象",
		activityKind = "generic",
		specIndex = 8,
		ratingValue = 0,
		ilvl = 697,
		isBlacklisted = true,
		blacklistNote = "调试备注：本地黑名单 UI 测试",
		comment = "黑名单 tooltip 与红色行测试。",
	},
	{
		id = TEST_ID_BASE + 6,
		name = "三职责德",
		activityKind = "mplus",
		specIndex = 5,
		score = 2940,
		mapScore = 2685,
		keyLevel = 12,
		ilvl = 705,
		roles = { "TANK", "HEALER", "DAMAGER" },
		comment = "三职责申请：坦克、治疗、输出。",
	},
	{
		id = TEST_ID_BASE + 7,
		name = "时空小号",
		activityKind = "lowlevel",
		specIndex = 3,
		levelOffset = -8,
		ilvl = 612,
		comment = "低等级申请，评分列显示等级。",
	},
	{
		id = TEST_ID_BASE + 8,
		name = "已取消者",
		activityKind = "mplus",
		specIndex = 2,
		score = 2866,
		mapScore = 2521,
		keyLevel = 10,
		ilvl = 699,
		status = "cancelled",
		statusText = "已取消",
		comment = "灰色保留态：已取消申请。",
	},
	{
		id = TEST_ID_BASE + 9,
		name = "已接受者",
		activityKind = "raid",
		specIndex = 1,
		ratingValue = 6,
		ilvl = 710,
		status = "inviteaccepted",
		statusText = "已加入队伍",
		comment = "灰色保留态：已接受邀请。",
	},
	{
		id = TEST_ID_BASE + 10,
		name = "等待邀请",
		activityKind = "generic",
		specIndex = 6,
		ratingValue = 3,
		ilvl = 704,
		status = "invited",
		statusText = "已邀请",
		comment = "已邀请状态，不显示真实操作按钮。",
	},
	{
		id = TEST_ID_BASE + 11,
		name = "超时猎人",
		activityKind = "mplus",
		specIndex = 7,
		score = 3014,
		mapScore = 2740,
		keyLevel = 13,
		ilvl = 707,
		status = "timedout",
		statusText = "已超时",
		comment = "灰色保留态：超时申请。",
	},
}

local TEST_GROUP = {
	applicantID = TEST_GROUP_ID,
	activityKind = "mplus",
	comment = "三人组队申请：坦克、治疗、输出齐全。",
	members = {
		{ name = "三人队长", specIndex = 1, role = "TANK", score = 3350, mapScore = 3078, keyLevel = 15, ilvl = 713 },
		{ name = "三人治疗", specIndex = 2, role = "HEALER", score = 3290, mapScore = 3021, keyLevel = 14, ilvl = 709, relationship = "guild" },
		{ name = "三人输出", specIndex = 3, role = "DAMAGER", score = 3318, mapScore = 2994, keyLevel = 14, ilvl = 711 },
	},
}

local COMMENTS = {
	"可语音，熟路线。",
	"自备合剂和爆发药水。",
	"熟练打断，能开麦。",
	"测试动态列宽和省略号。",
	"真实环境样式：带装等、评分与说明。",
}

local GRAYED_STATUSES = {
	failed = true,
	cancelled = true,
	declined = true,
	declined_full = true,
	declined_delisted = true,
	invitedeclined = true,
	timedout = true,
	inviteaccepted = true,
}

local function normalizeScenario(value)
	value = tostring(value or "full")
	value = string.lower(value)
	if value == "basic" or value == "scroll" then
		return value
	end
	return "full"
end

function ATD:IsEnabled()
	return _G.GROUPFINDER_APPLICANT_TEST_ROWS_ENABLED == true
end

function ATD:SetEnabled(enabled)
	_G.GROUPFINDER_APPLICANT_TEST_ROWS_ENABLED = enabled == true
end

function ATD:GetScenario()
	return normalizeScenario(_G.GROUPFINDER_APPLICANT_TEST_SCENARIO)
end

function ATD:SetScenario(scenario)
	_G.GROUPFINDER_APPLICANT_TEST_SCENARIO = normalizeScenario(scenario)
end

function ATD:GetExtraRowCount()
	return math.max(0, math.floor(tonumber(_G.GROUPFINDER_APPLICANT_SCROLL_TEST_EXTRA_ROWS) or 0))
end

function ATD:SetExtraRowCount(count)
	_G.GROUPFINDER_APPLICANT_SCROLL_TEST_EXTRA_ROWS = math.max(0, math.floor(tonumber(count) or 0))
end

function ATD:IsTestApplicantID(applicantID)
	applicantID = tonumber(applicantID)
	return applicantID and applicantID >= TEST_ID_BASE
end

local function getMaxLevel()
	return (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or (MAX_PLAYER_LEVEL or 80)
end

local function getActiveActivityInfo()
	if not (C_LFGList and C_LFGList.GetActiveEntryInfo and C_LFGList.GetActivityInfoTable) then
		return DEFAULT_ACTIVITY_INFO
	end
	local activeInfo = C_LFGList.GetActiveEntryInfo()
	local activityID = activeInfo and activeInfo.activityIDs and activeInfo.activityIDs[1]
	if not activityID then
		return DEFAULT_ACTIVITY_INFO
	end
	return C_LFGList.GetActivityInfoTable(activityID, activeInfo.questID) or DEFAULT_ACTIVITY_INFO
end

local function resolveActivityInfo(row, activeActivityInfo)
	if row and row.activityKind == "active" then
		return activeActivityInfo or DEFAULT_ACTIVITY_INFO
	end
	local kind = row and row.activityKind or "mplus"
	return ACTIVITY_FIXTURES[kind] or activeActivityInfo or DEFAULT_ACTIVITY_INFO
end

local function getActivityKind(activityInfo)
	if activityInfo and activityInfo.isMythicPlusActivity then
		return "mplus"
	end
	if activityInfo and (activityInfo.isRatedPvpActivity or activityInfo.isPvpActivity) then
		return "pvp"
	end
	if activityInfo and (activityInfo.isCurrentRaidActivity or ((activityInfo.maxNumPlayers or 0) > 5)) then
		return "raid"
	end
	return "generic"
end

local function getPvpRating(row, memberIdx)
	return row.pvpRating or math.max(1000, 1500 + ((row.score or 2600) % 900) + ((memberIdx or 1) * 7))
end

local function getPvpTier(row, memberIdx, rating)
	if row.pvpTier then
		return row.pvpTier
	end
	return math.max(1, math.min(13, math.floor(((rating or 1000) - 1000) / 200) + 1 + ((memberIdx or 1) % 2)))
end

local function cloneRoles(role, roles)
	if type(roles) == "table" then
		return roles[1], roles[2], roles[3]
	end
	if role == "TANK" then
		return "TANK", nil, nil
	end
	if role == "HEALER" then
		return "HEALER", nil, nil
	end
	return "DAMAGER", nil, nil
end

local function buildRatingDetail(row)
	local currentDungeon = {
		mapScore = row.mapScore,
		mapName = row.mapName or "千丝之城",
		bestRunLevel = row.keyLevel,
		bestLevelIncrement = row.keyLevel and row.keyLevel <= 10 and 1 or 0,
		finishedSuccess = row.finishedSuccess ~= false,
	}
	local bestOverallScore = {
		mapScore = row.bestMapScore or row.mapScore or row.score,
		mapName = row.bestMapName or "艾拉-卡拉，回响之城",
		bestRunLevel = row.bestKeyLevel or row.keyLevel,
		bestLevelIncrement = row.bestLevelIncrement or 0,
		finishedSuccess = row.bestFinishedSuccess ~= false,
	}
	return {
		overall = row.score,
		mapScore = currentDungeon.mapScore,
		bestRunLevel = currentDungeon.bestRunLevel,
		bestLevelIncrement = currentDungeon.bestLevelIncrement,
		finishedSuccess = currentDungeon.finishedSuccess,
		mapName = currentDungeon.mapName,
		currentDungeon = currentDungeon,
		bestOverallScore = bestOverallScore,
	}
end

local function applyActivityRating(member, row, activityInfo, memberIdx)
	local activityKind = getActivityKind(activityInfo)
	member.activityInfo = activityInfo
	member.activityKind = activityKind
	if member.level and member.level < getMaxLevel() then
		member.tooltipKind = activityKind
		member.ratingKind = "level"
		member.ratingValue = member.level
		member.ratingColor = HIGHLIGHT_FONT_COLOR
		member.ratingDetail = nil
		return member
	end
	if activityKind == "mplus" then
		member.tooltipKind = "mplus"
		member.ratingKind = "mplus"
		member.ratingValue = nil
		member.ratingColor = nil
		member.ratingDetail = buildRatingDetail(row)
		return member
	end
	if activityKind == "pvp" then
		local rating = getPvpRating(row, memberIdx)
		local tier = getPvpTier(row, memberIdx, rating)
		member.tooltipKind = "pvp"
		member.ratingKind = "rating"
		member.ratingValue = rating
		member.ratingColor = HIGHLIGHT_FONT_COLOR
		member.ratingDetail = nil
		member.pvpItemLevel = row.pvpItemLevel or ((row.ilvl or 710) + 6)
		member.honorLevel = row.honorLevel or (80 + ((memberIdx or 1) * 5))
		member.pvpRatingInfo = {
			bracket = row.pvpBracket or (activityInfo and activityInfo.groupFinderActivityGroupID) or 0,
			activityName = (activityInfo and (activityInfo.shortName or activityInfo.fullName)) or "评级 PvP",
			rating = rating,
			tier = tier,
		}
		return member
	end
	member.tooltipKind = activityKind == "raid" and "raid" or "generic"
	member.ratingKind = "rating"
	member.ratingValue = row.ratingValue
	member.ratingColor = row.ratingValue and HIGHLIGHT_FONT_COLOR or nil
	member.ratingDetail = nil
	return member
end

local function buildMember(row, memberIdx, grayed, activityInfo, status)
	local spec = TEST_SPECS[row.specIndex or 1] or TEST_SPECS[1]
	local role1, role2, role3 = cloneRoles(row.role or spec.role, row.roles)
	local blacklistEntry
	if row.isBlacklisted then
		blacklistEntry = {
			kind = "leader",
			note = row.blacklistNote,
		}
	end
	local realm = (GetRealmName and GetRealmName()) or "测试服"
	local maxLevel = getMaxLevel()
	local level = row.level or (row.levelOffset and math.max(1, maxLevel + row.levelOffset)) or maxLevel
	local member = {
		memberIdx = memberIdx or 1,
		name = row.name .. "-" .. realm,
		displayName = row.name,
		class = row.class or spec.class,
		localizedClass = row.localizedClass or spec.className,
		specID = row.specID or spec.specID,
		specName = row.specText or spec.specText,
		specText = row.specText or spec.specText,
		level = level,
		honorLevel = row.honorLevel,
		ilvl = row.ilvl or 710,
		role1 = role1,
		role2 = role2,
		role3 = role3,
		assignedRole = row.assignedRole or role1,
		relationship = row.relationship,
		isLeaver = row.isLeaver == true,
		isBlacklisted = row.isBlacklisted == true,
		blacklistEntry = blacklistEntry,
		factionGroup = row.factionGroup,
		showFactionIcon = row.showFactionIcon == true,
		grayed = grayed == true,
		noTouchy = status == "invited",
		isTest = true,
		comment = row.comment or "",
	}
	return applyActivityRating(member, row, activityInfo or DEFAULT_ACTIVITY_INFO, memberIdx)
end

local function useCompactInvite(activityInfo)
	return activityInfo and (activityInfo.isMythicPlusActivity or activityInfo.isRatedPvpActivity)
end

local function buildApplicantFromRow(row, activeActivityInfo)
	local activityInfo = resolveActivityInfo(row, activeActivityInfo or getActiveActivityInfo())
	local status = row.status or "applied"
	local grayed = GRAYED_STATUSES[status] == true
	local showActions = status == "applied"
	local canManage = GF.Listing and GF.Listing.CanManageEntry and GF.Listing:CanManageEntry()
	return {
		applicantID = row.id,
		appInfo = {
			applicationStatus = status,
			numMembers = 1,
			comment = row.comment,
			isNew = row.isNew,
		},
		members = { buildMember(row, 1, grayed, activityInfo, status) },
		numMembers = 1,
		comment = row.comment or "",
		loading = false,
		isNew = row.isNew == true,
		status = status,
		statusText = status ~= "applied" and (row.statusText or status) or nil,
		statusColor = grayed and { r = 0.5, g = 0.5, b = 0.5 } or nil,
		grayed = grayed,
		showInvite = showActions,
		showDecline = showActions,
		declineIsAck = false,
		canInvite = showActions and canManage,
		canDecline = showActions and canManage,
		useCompactInvite = useCompactInvite(activityInfo),
		activityInfo = activityInfo,
		isTest = true,
	}
end

local function buildGroupApplicant(activeActivityInfo)
	local activityInfo = resolveActivityInfo(TEST_GROUP, activeActivityInfo or getActiveActivityInfo())
	local members = {}
	for index, row in ipairs(TEST_GROUP.members) do
		members[index] = buildMember(row, index, false, activityInfo, "applied")
		members[index].comment = TEST_GROUP.comment
	end
	local canManage = GF.Listing and GF.Listing.CanManageEntry and GF.Listing:CanManageEntry()
	return {
		applicantID = TEST_GROUP.applicantID,
		appInfo = {
			applicationStatus = "applied",
			numMembers = #members,
			comment = TEST_GROUP.comment,
		},
		members = members,
		numMembers = #members,
		comment = TEST_GROUP.comment,
		loading = false,
		isNew = false,
		status = "applied",
		statusText = nil,
		statusColor = nil,
		grayed = false,
		showInvite = true,
		showDecline = true,
		declineIsAck = false,
		canInvite = canManage,
		canDecline = canManage,
		useCompactInvite = useCompactInvite(activityInfo),
		activityInfo = activityInfo,
		isTest = true,
	}
end

local EXTRA_ACTIVITY_KINDS = { "mplus", "pvp", "raid", "generic", "lowlevel" }

local function buildExtraRow(extraIndex)
	local specIndex = ((extraIndex - 1) % #TEST_SPECS) + 1
	local spec = TEST_SPECS[specIndex]
	local score = 2780 + (extraIndex * 41) % 760
	local kind = EXTRA_ACTIVITY_KINDS[((extraIndex - 1) % #EXTRA_ACTIVITY_KINDS) + 1]
	local status
	local statusText
	if extraIndex % 12 == 0 then
		status = "declined"
		statusText = "已拒绝"
	elseif extraIndex % 9 == 0 then
		status = "cancelled"
		statusText = "已取消"
	end
	return {
		id = TEST_EXTRA_ID_BASE + extraIndex,
		name = string.format("真实样本%02d", extraIndex),
		activityKind = kind,
		specIndex = specIndex,
		role = spec.role,
		score = score,
		mapScore = math.max(1, score - 260),
		keyLevel = 8 + (extraIndex % 9),
		pvpRating = 1500 + ((extraIndex * 73) % 900),
		pvpTier = 3 + (extraIndex % 6),
		ratingValue = (extraIndex % 7) + 1,
		ilvl = 690 + (extraIndex % 28),
		levelOffset = kind == "lowlevel" and -(3 + (extraIndex % 12)) or nil,
		comment = COMMENTS[((extraIndex - 1) % #COMMENTS) + 1],
		relationship = extraIndex % 10 == 0 and "guild" or (extraIndex % 6 == 0 and "friend" or nil),
		isLeaver = extraIndex % 14 == 0,
		isBlacklisted = extraIndex % 17 == 0,
		blacklistNote = extraIndex % 17 == 0 and "调试备注：滚动样本黑名单" or nil,
		factionGroup = kind == "pvp" and 0 or nil,
		showFactionIcon = kind == "pvp" and extraIndex % 2 == 0,
		status = status,
		statusText = statusText,
	}
end

local function rowIncludedInScenario(row, scenario)
	if scenario == "basic" then
		return row.basic == true
	end
	return true
end

function ATD:GetApplicantIDs()
	if not self:IsEnabled() then
		return {}
	end
	local scenario = self:GetScenario()
	local ids = {}
	ids[#ids + 1] = TEST_GROUP_ID
	for _, row in ipairs(TEST_ROWS) do
		if rowIncludedInScenario(row, scenario) then
			ids[#ids + 1] = row.id
		end
	end
	for i = 1, self:GetExtraRowCount() do
		ids[#ids + 1] = TEST_EXTRA_ID_BASE + i
	end
	return ids
end

function ATD:BuildApplicant(applicantID)
	if not self:IsEnabled() then
		return nil
	end
	applicantID = tonumber(applicantID)
	local activeActivityInfo = getActiveActivityInfo()
	local scenario = self:GetScenario()
	if applicantID == TEST_GROUP_ID then
		return buildGroupApplicant(activeActivityInfo)
	end
	for _, row in ipairs(TEST_ROWS) do
		if row.id == applicantID and rowIncludedInScenario(row, scenario) then
			return buildApplicantFromRow(row, activeActivityInfo)
		end
	end
	if applicantID and applicantID > TEST_EXTRA_ID_BASE and applicantID < TEST_GROUP_ID then
		local extraIndex = applicantID - TEST_EXTRA_ID_BASE
		if extraIndex >= 1 and extraIndex <= self:GetExtraRowCount() then
			return buildApplicantFromRow(buildExtraRow(extraIndex), activeActivityInfo)
		end
	end
	return nil
end
