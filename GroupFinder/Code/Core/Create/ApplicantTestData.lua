local _, GF = ...

GF.ApplicantTestData = GF.ApplicantTestData or {}
local ATD = GF.ApplicantTestData

_G.GROUPFINDER_APPLICANT_TEST_ROWS_ENABLED = _G.GROUPFINDER_APPLICANT_TEST_ROWS_ENABLED == true
_G.GROUPFINDER_APPLICANT_SCROLL_TEST_EXTRA_ROWS = tonumber(_G.GROUPFINDER_APPLICANT_SCROLL_TEST_EXTRA_ROWS) or 12
_G.GROUPFINDER_APPLICANT_TEST_SCENARIO = _G.GROUPFINDER_APPLICANT_TEST_SCENARIO or "full"

local TEST_ID_PREFIX = "GF_TEST_"
local TEST_EXTRA_ID_PREFIX = TEST_ID_PREFIX .. "EXTRA_"
local TEST_GROUP_ID = TEST_ID_PREFIX .. "GROUP"

local function testRowID(index)
	return TEST_ID_PREFIX .. "ROW_" .. tostring(index)
end

local function testExtraID(index)
	return TEST_EXTRA_ID_PREFIX .. tostring(index)
end

local ACTIVITY_FIXTURES = {
	mplus = {
		isMythicPlusActivity = true,
		isRatedPvpActivity = false,
		isPvpActivity = false,
		isCurrentRaidActivity = false,
		maxNumPlayers = 5,
		nameKey = "mplus",
	},
	pvp = {
		isMythicPlusActivity = false,
		isRatedPvpActivity = true,
		isPvpActivity = true,
		isCurrentRaidActivity = false,
		maxNumPlayers = 10,
		nameKey = "pvp",
		groupFinderActivityGroupID = 4,
	},
	raid = {
		isMythicPlusActivity = false,
		isRatedPvpActivity = false,
		isPvpActivity = false,
		isCurrentRaidActivity = true,
		maxNumPlayers = 20,
		nameKey = "raid",
	},
	generic = {
		isMythicPlusActivity = false,
		isRatedPvpActivity = false,
		isPvpActivity = false,
		isCurrentRaidActivity = false,
		maxNumPlayers = 5,
		nameKey = "generic",
	},
	lowlevel = {
		isMythicPlusActivity = false,
		isRatedPvpActivity = false,
		isPvpActivity = false,
		isCurrentRaidActivity = false,
		maxNumPlayers = 5,
		nameKey = "lowlevel",
	},
}

local TEST_SPECS = {
	{ specID = 73, class = "WARRIOR", role = "TANK" },
	{ specID = 257, class = "PRIEST", role = "HEALER" },
	{ specID = 63, class = "MAGE", role = "DAMAGER" },
	{ specID = 1480, class = "DEMONHUNTER", role = "DAMAGER" },
	{ specID = 104, class = "DRUID", role = "TANK" },
	{ specID = 270, class = "MONK", role = "HEALER" },
	{ specID = 254, class = "HUNTER", role = "DAMAGER" },
	{ specID = 262, class = "SHAMAN", role = "DAMAGER" },
	{ specID = 70, class = "PALADIN", role = "DAMAGER" },
	{ specID = 250, class = "DEATHKNIGHT", role = "TANK" },
	{ specID = 1468, class = "EVOKER", role = "HEALER" },
	{ specID = 260, class = "ROGUE", role = "DAMAGER" },
}

local TEST_ROWS = {
	{
		id = testRowID(1),
		basic = true,
		nameKey = "veteran",
		activityKind = "mplus",
		specIndex = 4,
		score = 3186,
		mapScore = 3042,
		keyLevel = 15,
		ilvlDelta = 6,
		commentKey = "mplus",
		isNew = true,
	},
	{
		id = testRowID(2),
		basic = true,
		nameKey = "pvpLeader",
		activityKind = "pvp",
		specIndex = 9,
		pvpRating = 2300,
		pvpTier = 7,
		pvpIlvlDelta = 13,
		honorLevel = 146,
		ilvlDelta = 4,
		factionGroup = 0,
		showFactionIcon = true,
		relationship = "bnet",
		commentKey = "pvp",
	},
	{
		id = testRowID(3),
		basic = true,
		nameKey = "guildHealer",
		activityKind = "raid",
		specIndex = 11,
		ratingValue = 8,
		ilvlDelta = 1,
		relationship = "guild",
		commentKey = "raid",
	},
	{
		id = testRowID(4),
		basic = true,
		nameKey = "leaver",
		activityKind = "mplus",
		specIndex = 12,
		score = 3392,
		mapScore = 3218,
		keyLevel = 16,
		ilvlDelta = 8,
		isLeaver = true,
		commentKey = "leaver",
	},
	{
		id = testRowID(5),
		basic = true,
		nameKey = "blocked",
		activityKind = "generic",
		specIndex = 8,
		ratingValue = 0,
		ilvlDelta = -8,
		isBlacklisted = true,
		blacklistNoteKey = "blacklist",
		commentKey = "blocked",
	},
	{
		id = testRowID(6),
		nameKey = "flex",
		activityKind = "mplus",
		specIndex = 5,
		score = 2940,
		mapScore = 2685,
		keyLevel = 12,
		ilvlDelta = -2,
		roles = { "TANK", "HEALER", "DAMAGER" },
		commentKey = "flex",
	},
	{
		id = testRowID(7),
		nameKey = "lowlevel",
		activityKind = "lowlevel",
		specIndex = 3,
		levelOffset = -8,
		ilvlDelta = -95,
		commentKey = "lowlevel",
	},
	{
		id = testRowID(8),
		nameKey = "cancelled",
		activityKind = "mplus",
		specIndex = 2,
		score = 2866,
		mapScore = 2521,
		keyLevel = 10,
		ilvlDelta = -5,
		status = "cancelled",
		commentKey = "cancelled",
	},
	{
		id = testRowID(9),
		nameKey = "accepted",
		activityKind = "raid",
		specIndex = 1,
		ratingValue = 6,
		ilvlDelta = 3,
		status = "inviteaccepted",
		commentKey = "accepted",
	},
	{
		id = testRowID(10),
		nameKey = "invited",
		activityKind = "generic",
		specIndex = 6,
		ratingValue = 3,
		ilvlDelta = -1,
		status = "invited",
		commentKey = "invited",
	},
	{
		id = testRowID(11),
		nameKey = "timedout",
		activityKind = "mplus",
		specIndex = 7,
		score = 3014,
		mapScore = 2740,
		keyLevel = 13,
		ilvlDelta = 0,
		status = "timedout",
		commentKey = "timedout",
	},
	{
		id = testRowID(12),
		nameKey = "declined",
		activityKind = "generic",
		specIndex = 10,
		ratingValue = 2,
		ilvlDelta = -4,
		status = "declined",
		commentKey = "declined",
	},
	{
		id = testRowID(13),
		nameKey = "full",
		activityKind = "raid",
		specIndex = 3,
		ratingValue = 5,
		ilvlDelta = 2,
		status = "declined_full",
		commentKey = "full",
	},
	{
		id = testRowID(14),
		nameKey = "inviteDeclined",
		activityKind = "mplus",
		specIndex = 9,
		score = 2750,
		mapScore = 2490,
		keyLevel = 9,
		ilvlDelta = -7,
		status = "invitedeclined",
		commentKey = "inviteDeclined",
	},
	{
		id = testRowID(15),
		nameKey = "failed",
		activityKind = "pvp",
		specIndex = 8,
		pvpRating = 1950,
		ilvlDelta = -3,
		status = "failed",
		commentKey = "failed",
	},
	{
		id = testRowID(16),
		nameKey = "unknownSpec",
		activityKind = "generic",
		specIndex = 1,
		unknownSpec = true,
		ilvlDelta = -10,
		commentKey = "empty",
		relationship = "friend",
	},
	{
		id = testRowID(17),
		nameKey = "longNote",
		activityKind = "mplus",
		specIndex = 11,
		score = 3075,
		mapScore = 2810,
		keyLevel = 14,
		ilvlDelta = 5,
		commentKey = "long",
	},
	{
		id = testRowID(18),
		nameKey = "delisted",
		activityKind = "generic",
		specIndex = 4,
		ratingValue = 4,
		ilvlDelta = -6,
		status = "declined_delisted",
		commentKey = "delisted",
	},
	{
		id = testRowID(19),
		nameKey = "pending",
		activityKind = "mplus",
		specIndex = 7,
		score = 3120,
		mapScore = 2864,
		keyLevel = 14,
		ilvlDelta = 2,
		pendingApplicationStatus = "invited",
		commentKey = "pending",
	},
	{
		id = testRowID(20),
		nameKey = "loading",
		activityKind = "pvp",
		specIndex = 8,
		pvpRating = 2100,
		ilvlDelta = 0,
		applicantInfo = true,
		commentKey = "loading",
	},
	{
		id = testRowID(21),
		nameKey = "laonong",
		activityKind = "raid",
		specIndex = 10,
		ratingValue = 7,
		ilvlDelta = 3,
		isLaonongFan = true,
		commentKey = "laonong",
	},
}

local TEST_GROUP = {
	applicantID = TEST_GROUP_ID,
	activityKind = "mplus",
	commentKey = "group",
	members = {
		{ nameKey = "groupLeader", specIndex = 1, role = "TANK", score = 3350, mapScore = 3078, keyLevel = 15, ilvlDelta = 7 },
		{ nameKey = "groupHealer", specIndex = 2, role = "HEALER", score = 3290, mapScore = 3021, keyLevel = 14, ilvlDelta = 2, relationship = "guild" },
		{ nameKey = "groupDamage", specIndex = 3, role = "DAMAGER", score = 3318, mapScore = 2994, keyLevel = 14, ilvlDelta = 4 },
	},
}

local TEST_ROWS_BY_ID = {}
for _, row in ipairs(TEST_ROWS) do
	TEST_ROWS_BY_ID[row.id] = row
end

local GRAYED_STATUSES = {}
for _, status in ipairs({
	"failed", "cancelled", "declined", "declined_full",
	"declined_delisted", "invitedeclined", "timedout", "inviteaccepted",
}) do
	GRAYED_STATUSES[status] = true
end

local function getFixtureSection(section)
	local fixtures = GF.L and GF.L.DEBUG_APPLICANT_FIXTURES
	local value = type(fixtures) == "table" and fixtures[section] or nil
	return type(value) == "table" and value or {}
end

local function fixtureText(section, key, fallback)
	local value = getFixtureSection(section)[key]
	if type(value) == "string" and value ~= "" then
		return value
	end
	return fallback or tostring(key or "")
end

local function getRowName(row)
	return fixtureText("names", row and row.nameKey, row and row.name or "TestPlayer")
end

local function getRowComment(row)
	return fixtureText("comments", row and row.commentKey, row and row.comment or "")
end

local function getRowStatusText(row)
	local status = row and row.status
	if not status or status == "applied" then
		return nil
	end
	return fixtureText("statuses", status, row.statusText or status)
end

local function getRealm()
	local realm = GetRealmName and GetRealmName() or nil
	if type(realm) == "string" and realm ~= "" then
		return realm
	end
	return fixtureText("meta", "realm", "TestRealm")
end

local function cloneActivityFixture(kind)
	local source = ACTIVITY_FIXTURES[kind] or ACTIVITY_FIXTURES.mplus
	local copy = {}
	for key, value in pairs(source) do
		if key ~= "nameKey" then
			copy[key] = value
		end
	end
	local name = fixtureText("activities", source.nameKey, "Test Activity")
	copy.shortName = name
	copy.fullName = name
	return copy
end

local function getReferenceItemLevel()
	if type(GetAverageItemLevel) == "function" then
		local ok, equipped, overall = pcall(GetAverageItemLevel)
		if ok then
			local value = tonumber(overall) or tonumber(equipped)
			if value and value > 0 then
				return math.floor(value + 0.5)
			end
		end
	end
	return 700
end

local function getItemLevel(row)
	if tonumber(row and row.ilvl) then
		return tonumber(row.ilvl)
	end
	return math.max(1, getReferenceItemLevel() + (tonumber(row and row.ilvlDelta) or 0))
end

local function getLocalizedClassName(classFile)
	local sex = UnitSex and UnitSex("player") or nil
	local names = sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
	local value = type(names) == "table" and names[classFile] or nil
	if type(value) == "string" and value ~= "" then
		return value
	end
	return tostring(classFile or "")
end

local function resolveSpec(row)
	local template = TEST_SPECS[row.specIndex or 1] or TEST_SPECS[1]
	local classFile = row.class or template.class
	local role = row.role or template.role
	if row.unknownSpec == true then
		return {
			class = classFile,
			className = getLocalizedClassName(classFile),
			role = role,
		}
	end
	local specID = tonumber(row.specID) or template.specID
	local specName
	if type(GetSpecializationInfoByID) == "function" then
		local ok, _, name, _, _, apiRole, apiClassFile, apiClassName =
			pcall(GetSpecializationInfoByID, specID, UnitSex and UnitSex("player") or nil)
		if ok then
			specName = type(name) == "string" and name ~= "" and name or nil
			role = type(apiRole) == "string" and apiRole ~= "" and apiRole or role
			classFile = type(apiClassFile) == "string" and apiClassFile ~= ""
				and apiClassFile or classFile
			if type(apiClassName) == "string" and apiClassName ~= "" then
				return {
					specID = specID,
					specName = specName,
					class = classFile,
					className = apiClassName,
					role = role,
				}
			end
		end
	end
	return {
		specID = specID,
		specName = specName or tostring(specID),
		class = classFile,
		className = getLocalizedClassName(classFile),
		role = role,
	}
end

local function getSeasonDungeonName(index)
	local season = GF.MythicPlusSeason
	local source = season and season.GetDungeons and season:GetDungeons() or {}
	if #source > 0 then
		local dungeon = source[((index - 1) % #source) + 1]
		if dungeon and type(dungeon.name) == "string" and dungeon.name ~= "" then
			return dungeon.name
		end
	end
	return fixtureText("activities", index == 1 and "mplus" or "mplusAlternate", "Mythic+")
end

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

local function rowIncludedInScenario(row, scenario)
	if scenario == "basic" then
		return row.basic == true
	end
	return true
end

local function getExtraIndex(applicantID)
	if type(applicantID) ~= "string" then
		return nil
	end
	local value = applicantID:match("^" .. TEST_EXTRA_ID_PREFIX .. "(%d+)$")
	local index = tonumber(value)
	if not index or index < 1 or index ~= math.floor(index) then
		return nil
	end
	return index
end

function ATD:IsTestApplicantID(applicantID)
	if not self:IsEnabled() or type(applicantID) ~= "string" then
		return false
	end
	if applicantID == TEST_GROUP_ID then
		return true
	end
	local row = TEST_ROWS_BY_ID[applicantID]
	if row then
		return rowIncludedInScenario(row, self:GetScenario())
	end
	local extraIndex = getExtraIndex(applicantID)
	return extraIndex ~= nil and extraIndex <= self:GetExtraRowCount()
end

local function getMaxLevel()
	return (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or (MAX_PLAYER_LEVEL or 80)
end

local function getActiveActivityInfo()
	if not (C_LFGList and C_LFGList.GetActiveEntryInfo and C_LFGList.GetActivityInfoTable) then
		return cloneActivityFixture("mplus")
	end
	local activeInfo = C_LFGList.GetActiveEntryInfo()
	local activityID = activeInfo and activeInfo.activityIDs and activeInfo.activityIDs[1]
	if not activityID then
		return cloneActivityFixture("mplus")
	end
	return C_LFGList.GetActivityInfoTable(activityID, activeInfo.questID)
		or cloneActivityFixture("mplus")
end

local function resolveActivityInfo(row, activeActivityInfo)
	if row and row.activityKind == "active" then
		return activeActivityInfo or cloneActivityFixture("mplus")
	end
	local kind = row and row.activityKind or "mplus"
	return ACTIVITY_FIXTURES[kind] and cloneActivityFixture(kind)
		or activeActivityInfo or cloneActivityFixture("mplus")
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
		mapName = row.mapName or getSeasonDungeonName(1),
		bestRunLevel = row.keyLevel,
		bestLevelIncrement = row.keyLevel and row.keyLevel <= 10 and 1 or 0,
		finishedSuccess = row.finishedSuccess ~= false,
	}
	local bestOverallScore = {
		mapScore = row.bestMapScore or row.mapScore or row.score,
		mapName = row.bestMapName or getSeasonDungeonName(2),
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
		member.ratingColor = GF.GetPvpRatingColor(rating)
		member.ratingDetail = nil
		member.pvpItemLevel = row.pvpItemLevel
			or (getItemLevel(row) + (tonumber(row.pvpIlvlDelta) or 6))
		member.honorLevel = row.honorLevel or (80 + ((memberIdx or 1) * 5))
		member.pvpRatingInfo = {
			bracket = row.pvpBracket or (activityInfo and activityInfo.groupFinderActivityGroupID) or 0,
			activityName = (activityInfo and (activityInfo.shortName or activityInfo.fullName))
				or fixtureText("activities", "pvp", "Rated PvP"),
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
	local spec = resolveSpec(row)
	local role1, role2, role3 = cloneRoles(row.role or spec.role, row.roles)
	local blacklistEntry
	if row.isBlacklisted then
		blacklistEntry = {
			kind = "leader",
			note = fixtureText(
				"comments",
				row.blacklistNoteKey,
				row.blacklistNote or ""
			),
		}
	end
	local realm = getRealm()
	local maxLevel = getMaxLevel()
	local level = row.level or (row.levelOffset and math.max(1, maxLevel + row.levelOffset)) or maxLevel
	local name = getRowName(row)
	local member = {
		memberIdx = memberIdx or 1,
		name = name .. "-" .. realm,
		displayName = name,
		class = row.class or spec.class,
		localizedClass = row.localizedClass or spec.className,
		specID = row.unknownSpec ~= true and (row.specID or spec.specID) or nil,
		specName = row.unknownSpec ~= true and (row.specText or spec.specName) or nil,
		specText = row.unknownSpec ~= true and (row.specText or spec.specName) or nil,
		level = level,
		honorLevel = row.honorLevel,
		ilvl = getItemLevel(row),
		role1 = role1,
		role2 = role2,
		role3 = role3,
		assignedRole = row.assignedRole or role1,
		relationship = row.relationship,
		isLeaver = row.isLeaver == true,
		isBlacklisted = row.isBlacklisted == true,
		isLaonongFan = row.isLaonongFan == true,
		blacklistEntry = blacklistEntry,
		factionGroup = row.factionGroup,
		showFactionIcon = row.showFactionIcon == true,
		grayed = grayed == true,
		noTouchy = status == "invited",
		isTest = true,
		debugCase = row.debugCase or row.status or row.commentKey,
		comment = getRowComment(row),
	}
	return applyActivityRating(
		member,
		row,
		activityInfo or cloneActivityFixture("mplus"),
		memberIdx
	)
end

local function useCompactInvite(activityInfo)
	return activityInfo and (activityInfo.isMythicPlusActivity or activityInfo.isRatedPvpActivity)
end

local function buildApplicantFromRow(row, activeActivityInfo)
	local activityInfo = resolveActivityInfo(row, activeActivityInfo or getActiveActivityInfo())
	local status = row.status or "applied"
	local applicantInfo = row.applicantInfo == true
	local nativePending = status == "applied" and row.pendingApplicationStatus ~= nil
	local grayed = not nativePending and GRAYED_STATUSES[status] == true
	local showActions = not applicantInfo and status == "applied"
	local canManage = GF.RecruitmentSession and GF.RecruitmentSession.CanManageApplicants and GF.RecruitmentSession:CanManageApplicants()
	local comment = getRowComment(row)
	local statusText
	if not applicantInfo then
		statusText = getRowStatusText(row)
	end
	local statusColor
	if status == "invited" or status == "inviteaccepted" then
		statusColor = GREEN_FONT_COLOR or { r = 0, g = 1, b = 0 }
	elseif grayed then
		statusColor = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
	end
	return {
		applicantID = row.id,
		appInfo = {
			applicationStatus = status,
			applicantInfo = applicantInfo,
			numMembers = 1,
			pendingApplicationStatus = row.pendingApplicationStatus,
			comment = comment,
			isNew = row.isNew,
		},
		members = { buildMember(row, 1, grayed, activityInfo, status) },
		numMembers = 1,
		comment = comment,
		loading = applicantInfo or nativePending,
		isNew = row.isNew == true,
		status = status,
		statusText = statusText,
		statusColor = statusColor,
		grayed = grayed,
		showInvite = showActions,
		showDecline = showActions,
		declineIsAck = status ~= "applied" and status ~= "invited",
		canInvite = showActions and not nativePending and canManage,
		canDecline = showActions and not nativePending and canManage,
		useCompactInvite = useCompactInvite(activityInfo),
		activityInfo = activityInfo,
		isTest = true,
		debugCase = row.debugCase or row.status or row.commentKey,
	}
end

local function buildGroupApplicant(activeActivityInfo)
	local activityInfo = resolveActivityInfo(TEST_GROUP, activeActivityInfo or getActiveActivityInfo())
	local members = {}
	local comment = getRowComment(TEST_GROUP)
	for index, row in ipairs(TEST_GROUP.members) do
		members[index] = buildMember(row, index, false, activityInfo, "applied")
		members[index].comment = comment
	end
	local canManage = GF.RecruitmentSession and GF.RecruitmentSession.CanManageApplicants and GF.RecruitmentSession:CanManageApplicants()
	return {
		applicantID = TEST_GROUP.applicantID,
		appInfo = {
			applicationStatus = "applied",
			numMembers = #members,
			comment = comment,
		},
		members = members,
		numMembers = #members,
		comment = comment,
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
		debugCase = "multi-member",
	}
end

local EXTRA_ACTIVITY_KINDS = { "mplus", "pvp", "raid", "generic", "lowlevel" }
local PVP_COLOR_BOUNDARY_RATINGS = { 0, 500, 501, 1949, 1950, 2099, 2100, 2299, 2300 }

local function buildExtraRow(extraIndex)
	local specIndex = ((extraIndex - 1) % #TEST_SPECS) + 1
	local spec = TEST_SPECS[specIndex]
	local score = 2780 + (extraIndex * 41) % 760
	local kind = EXTRA_ACTIVITY_KINDS[((extraIndex - 1) % #EXTRA_ACTIVITY_KINDS) + 1]
	local pvpColorIndex = (math.floor((extraIndex - 1) / #EXTRA_ACTIVITY_KINDS) % #PVP_COLOR_BOUNDARY_RATINGS) + 1
	local status
	if extraIndex % 12 == 0 then
		status = "declined"
	elseif extraIndex % 9 == 0 then
		status = "cancelled"
	end
	local nameFormat = fixtureText("meta", "extraNameFmt", "Sample%02d")
	local ok, name = pcall(string.format, nameFormat, extraIndex)
	return {
		id = testExtraID(extraIndex),
		name = ok and name or string.format("Sample%02d", extraIndex),
		activityKind = kind,
		specIndex = specIndex,
		role = spec.role,
		score = score,
		mapScore = math.max(1, score - 260),
		keyLevel = 8 + (extraIndex % 9),
		pvpRating = PVP_COLOR_BOUNDARY_RATINGS[pvpColorIndex],
		pvpTier = 3 + (extraIndex % 6),
		ratingValue = (extraIndex % 7) + 1,
		ilvlDelta = -12 + (extraIndex % 25),
		levelOffset = kind == "lowlevel" and -(3 + (extraIndex % 12)) or nil,
		commentKey = "extra" .. tostring(((extraIndex - 1) % 5) + 1),
		relationship = extraIndex % 10 == 0 and "guild" or (extraIndex % 6 == 0 and "friend" or nil),
		isLeaver = extraIndex % 14 == 0,
		isBlacklisted = extraIndex % 17 == 0,
		blacklistNoteKey = extraIndex % 17 == 0 and "blacklist" or nil,
		factionGroup = kind == "pvp" and 0 or nil,
		showFactionIcon = kind == "pvp" and extraIndex % 2 == 0,
		status = status,
		debugCase = "scroll-" .. kind,
	}
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
		ids[#ids + 1] = testExtraID(i)
	end
	return ids
end

function ATD:BuildApplicant(applicantID)
	if not self:IsEnabled() then
		return nil
	end
	local activeActivityInfo = getActiveActivityInfo()
	local scenario = self:GetScenario()
	if applicantID == TEST_GROUP_ID then
		return buildGroupApplicant(activeActivityInfo)
	end
	local row = TEST_ROWS_BY_ID[applicantID]
	if row and rowIncludedInScenario(row, scenario) then
		return buildApplicantFromRow(row, activeActivityInfo)
	end
	local extraIndex = getExtraIndex(applicantID)
	if extraIndex and extraIndex <= self:GetExtraRowCount() then
		return buildApplicantFromRow(buildExtraRow(extraIndex), activeActivityInfo)
	end
	return nil
end
