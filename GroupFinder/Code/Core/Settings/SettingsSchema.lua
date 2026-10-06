local _, GF = ...

local Schema = {}
local Repository = {}

GF.SettingsSchema = Schema
GF.SettingsRepository = Repository

local APPLY_OPTION_DEFAULT_VERSION = 1
local JOIN_ANNOUNCE_DEFAULT_VERSION = 1
local MEMBER_TOOLTIP_MODE_DEFAULT_VERSION = 1
local APPLICANT_ALERT_SOUND_DEFAULT_VERSION = 2
local TELEPORT_PROMPT_MODE_DEFAULT_VERSION = 1
local CARPOOL_CANDIDATE_DEFAULT_VERSION = 1
local STARRED_BACKGROUND_DEFAULT_VERSION = 1
local NORMAL_BACKGROUND_DEFAULT_VERSION = 1

local MANUAL_TACTICAL_CHANNELS = {
	PARTY = true,
	RAID = true,
	INSTANCE_CHAT = true,
	RAID_WARNING = true,
}

Schema.VERSION = 1
Schema.RECENT_INSTANCE_LIMIT = 10
Schema.RECENT_INSTANCE_ROOT_KINDS = {
	season_dungeon = true, season_raid = true,
	dungeon = true, raid = true,
	delve = true, pvp = true, quest = true, custom = true,
}

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function toFiniteNumber(value)
	local ok, number = pcall(tonumber, value)
	if not ok or not isFiniteNumber(number) then
		return nil
	end
	return number
end

local function copyTable(source, copies)
	if type(source) ~= "table" then
		return source
	end
	copies = copies or {}
	if copies[source] then
		return copies[source]
	end
	local clone = {}
	copies[source] = clone
	for key, value in next, source do
		clone[copyTable(key, copies)] = copyTable(value, copies)
	end
	return clone
end

local function mergeMissingValues(target, source)
	for key, defaultValue in next, source do
		if target[key] == nil then
			target[key] = copyTable(defaultValue)
		end
	end
	return target
end

local function assignSameValue(target, keys, value)
	for index = 1, #keys do
		target[keys[index]] = value
	end
	return target
end

local function roundAndClamp(value, defaultValue, minimum, maximum)
	value = toFiniteNumber(value)
	if value == nil then
		value = defaultValue
	end
	value = math.floor(value + 0.5)
	if minimum ~= nil then
		value = math.max(minimum, value)
	end
	if maximum ~= nil then
		value = math.min(maximum, value)
	end
	return value
end

function Schema:Copy(value)
	return copyTable(value)
end

function Schema:ClampPanelScalePct(value)
	return roundAndClamp(
		value,
		GF.PANEL_SCALE_DEFAULT_PCT or 100,
		GF.PANEL_SCALE_MIN_PCT or 100,
		GF.PANEL_SCALE_MAX_PCT or 150)
end

function Schema:ClampFloatScalePct(value)
	return roundAndClamp(
		value,
		GF.FLOAT_SCALE_DEFAULT_PCT or 100,
		GF.FLOAT_SCALE_MIN_PCT or 50,
		GF.FLOAT_SCALE_MAX_PCT or 150)
end

function Schema:ClampFontScalePct(value)
	return roundAndClamp(
		value,
		GF.FONT_SCALE_DEFAULT_PCT or 100,
		GF.FONT_SCALE_MIN_PCT or 100,
		GF.FONT_SCALE_MAX_PCT or 150)
end

function Schema:ClampListBackgroundAlphaPct(value)
	return roundAndClamp(
		value,
		GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100,
		GF.LIST_BACKGROUND_ALPHA_MIN_PCT or 30,
		GF.LIST_BACKGROUND_ALPHA_MAX_PCT or 100)
end

function Schema:ClampNavWidth(value)
	local minimum = GF.NAV_WIDTH_MIN or 100
	local maximum = GF.NAV_WIDTH_MAX or 220
	local defaultValue = GF.NAV_WIDTH or 180
	local number = toFiniteNumber(value) or defaultValue
	return math.min(maximum, math.max(minimum, number))
end

function Schema:NormalizeFrameSize(width, height)
	local minimumWidth = GF.FRAME_MIN_W or GF.FRAME_W or 780
	local minimumHeight = GF.FRAME_MIN_H or GF.FRAME_H or 380
	width = toFiniteNumber(width) or GF.FRAME_W or minimumWidth
	height = toFiniteNumber(height) or GF.FRAME_H or minimumHeight
	return math.max(minimumWidth, width), math.max(minimumHeight, height)
end

function Schema:GetCurrentAverageItemLevelFloor()
	if not GetAverageItemLevel then
		return nil
	end
	local ok, averageItemLevel = pcall(GetAverageItemLevel)
	averageItemLevel = ok and toFiniteNumber(averageItemLevel) or nil
	if not averageItemLevel or averageItemLevel <= 0 then
		return nil
	end
	return math.floor(averageItemLevel)
end

function Schema:ClampDefaultRequiredItemLevel(value)
	local minimum = GF.DEFAULT_REQUIRED_ITEM_LEVEL_MIN or 0
	local defaultValue = GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0
	value = math.floor(toFiniteNumber(value) or defaultValue)
	value = math.max(minimum, value)
	local maximum = self:GetCurrentAverageItemLevelFloor()
	if maximum and maximum >= minimum then
		value = math.min(value, maximum)
	end
	return value
end

function Schema:NormalizeTeamListColorScheme(scheme)
	if scheme == (GF.TEAM_LIST_COLOR_SCHEME_LOW_SATURATION or "low_saturation") then
		return GF.TEAM_LIST_COLOR_SCHEME_LOW_SATURATION or "low_saturation"
	end
	return GF.TEAM_LIST_COLOR_SCHEME_DEFAULT or "default"
end

function Schema:NormalizeMemberDisplayMode(mode)
	if mode == (GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large") then
		return GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large"
	end
	if mode == (GF.MEMBER_DISPLAY_MODE_SPEC or "spec") then
		return GF.MEMBER_DISPLAY_MODE_SPEC or "spec"
	end
	return GF.MEMBER_DISPLAY_MODE_ROLE or "role"
end

function Schema:NormalizeExpiredGroupMode(mode)
	if mode == (GF.EXPIRED_GROUP_MODE_AUTO_REMOVE or "auto_remove") then
		return GF.EXPIRED_GROUP_MODE_AUTO_REMOVE or "auto_remove"
	end
	return GF.EXPIRED_GROUP_MODE_DEFAULT
		or GF.EXPIRED_GROUP_MODE_RETAIN_GRAY or "retain_gray"
end

function Schema:NormalizeMemberTooltipMode(mode)
	if mode == (GF.MEMBER_TOOLTIP_MODE_DETAILS or "details") then
		return GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
	end
	if mode == (GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count") then
		return GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count"
	end
	return GF.MEMBER_TOOLTIP_MODE_DEFAULT
		or GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
end

local applicantAlertSoundSet

function Schema:NormalizeApplicantAlertSoundFile(file)
	if not applicantAlertSoundSet then
		applicantAlertSoundSet = {}
		for _, option in ipairs(GF.APPLICANT_ALERT_SOUND_OPTIONS or {}) do
			if option.file then
				applicantAlertSoundSet[option.file] = true
			end
		end
	end
	file = type(file) == "string" and file or ""
	if applicantAlertSoundSet[file] then
		return file
	end
	return GF.APPLICANT_ALERT_SOUND_DEFAULT or "xalatath.mp3"
end

function Schema:NormalizeManualTacticalChannel(channel)
	if type(channel) == "string"
		and MANUAL_TACTICAL_CHANNELS[channel]
	then
		return channel
	end
	return "PARTY"
end

local function makeClientFilterDefaults()
	local defaults = {
		roleFilterMode = "all",
		minOpenSlots = 1,
		newbieOnlyActivityId = "",
	}
	assignSameValue(defaults, {
		"rangeTankMin", "rangeTankMax", "rangeHealMin", "rangeHealMax",
		"rangeDpsMin", "rangeDpsMax", "bloodlustMode", "leaderScoreMin",
		"raidMemberCount", "raidMemberCountMin", "raidMemberCountMax",
		"raidTankMin", "raidTankMax", "raidHealMin", "raidHealMax",
		"raidDpsMin", "raidDpsMax", "raidBossKills", "raidBossKillsMin",
		"raidBossKillsMax",
	}, 0)
	assignSameValue(defaults, {
		"rangeTankEn", "rangeHealEn", "rangeDpsEn", "matchMyRole",
		"notDeclined", "hasTank", "hasHeal", "alreadyHasTank",
		"alreadyHasHeal", "needsMyClass", "matchPartyRoles", "matchPartySpecs",
		"warmodeOnly", "dungeonDiffEn", "dungeonDifficultyNormal",
		"dungeonDifficultyHeroic", "dungeonDifficultyMythic",
		"dungeonDifficultyMythicPlus", "raidDiffEn", "raidDifficultyNormal",
		"raidDifficultyHeroic", "raidDifficultyMythic", "raidMemberCountEn",
		"raidTankEn", "raidHealEn", "raidDpsEn", "raidBossKillsEn",
		"newbieOnly",
	}, false)
	return defaults
end

local function makeMythicPlusDefaults()
	return {
		characters = {},
		carpoolCandidateDefaultVersion =
			CARPOOL_CANDIDATE_DEFAULT_VERSION,
		characterOrder = {
			carpool = {},
			other = {},
		},
		characterSettings = {},
		seasonDungeonCache = { challengeModeIDs = {} },
		settings = {
			groupReadyTeleportEnabled = false,--lnui
			keystoneRotationReminderEnabled = false,
			keystoneAnnouncementEnabled = false,
			manualTacticalChannel = "PARTY",
			teleportAnnouncementEnabled = false,--lnui
			teleportFollowEnabled = false,
		},
	}
end

local function makeAccountDefaults()
	local defaults = {
		v = Schema.VERSION,
		frameW = GF.FRAME_W,
		frameH = GF.FRAME_H,
		frameFooterLayoutVersion = GF.FRAME_FOOTER_LAYOUT_VERSION or 3,
		frameNavLayoutVersion = GF.FRAME_NAV_LAYOUT_VERSION or 2,
		navWidth = GF.NAV_WIDTH,
		favoriteInstances = {},
		recentInstances = {},
		starredLeaders = {},
		raidSeekingDrafts = {},
		raidSeekingReload = {},
		raidSeekingChats = {},
		raidRecruitmentRequirementsReload = {},
		favoriteInstanceOrders = {},
		versionDiscovery = {},
		userLetterReadVersion = "",
		settingsFeatureSeenVersions = {},
		minimapAngle = 225,
		joinAnnounceDefaultVersion = JOIN_ANNOUNCE_DEFAULT_VERSION,
		applicantAlertSoundFile = "Glass.aiff" or GF.APPLICANT_ALERT_SOUND_DEFAULT,--lnui
		applicantAlertSoundDefaultVersion = APPLICANT_ALERT_SOUND_DEFAULT_VERSION,
		teleportPromptModeDefaultVersion =
			TELEPORT_PROMPT_MODE_DEFAULT_VERSION,
		workspaceMode = GF.WORKSPACE_DEFAULT
			or GF.WORKSPACE_MEETING_STONE or "standard",
		interfaceLocale = "system",
		teamListColorScheme = "low_saturation" or GF.TEAM_LIST_COLOR_SCHEME_DEFAULT,--lnui
		memberDisplayMode = "spec_large" or GF.MEMBER_DISPLAY_MODE_DEFAULT,--lnui
		expiredGroupMode = GF.EXPIRED_GROUP_MODE_DEFAULT or "retain_gray",
		memberTooltipMode = "spec_count" or GF.MEMBER_TOOLTIP_MODE_DEFAULT,--lnui
		memberTooltipModeDefaultVersion = MEMBER_TOOLTIP_MODE_DEFAULT_VERSION,
		browseSort = { asc = true, column = "title" },
		maxAgeMin = 0,
		minIlvl = 0,
		rangeAgeMin = 0,
		rangeAgeMax = 0,
		rangeIlvlMin = 0,
		rangeIlvlMax = 0,
		rangeHonorMin = 0,
		rangeHonorMax = 0,
		rangeMplusScoreMin = 0,
		rangeMplusScoreMax = 0,
		filterGlobalByBucket = {},
		filterClientByCategory = {},
		filterClientBucketMigrated = {},
		browseColumnPresetVersion = GF.BROWSE_COLUMN_PRESET_VERSION or 2,
		applicantColumnPresetVersion = GF.APPLICANT_COLUMN_PRESET_VERSION or 1,
		applyMode = GF.APPLY_DBLCLICK_AUTO or "dblclick_auto",
		frameStrata = GF.FRAME_STRATA_DEFAULT or "MEDIUM",
		panelSkin = "system_settings" or GF.PANEL_SKIN_DEFAULT,--lnui
		workspaceTabPosition = GF.WORKSPACE_TAB_POSITION_DEFAULT or "right",
		panelScalePct = GF.PANEL_SCALE_DEFAULT_PCT or 100,
		floatScalePct = GF.FLOAT_SCALE_DEFAULT_PCT or 100,
		fontScalePct = 120 or GF.FONT_SCALE_DEFAULT_PCT,--lnui
		listBackgroundAlphaPct =
			GF.LIST_BACKGROUND_NORMAL_ALPHA_DEFAULT_PCT or 30,
		listBackgroundStyles = copyTable(GF.LIST_BACKGROUND_STYLE_DEFAULTS),
		starredBackgroundDefaultVersion = STARRED_BACKGROUND_DEFAULT_VERSION,
		normalBackgroundDefaultVersion = NORMAL_BACKGROUND_DEFAULT_VERSION,
		fontKey = "GameFontNormal",
		fontOutline = "OUTLINE",--lnui
		blocklist = {},
		neteaseIdentityActivityId = "",
		autoInviteMemberLimit = GF.AUTO_INVITE_MEMBER_LIMIT_DEFAULT or 40,
		mythicPlus = makeMythicPlusDefaults(),
	}
	assignSameValue(defaults, {
		"autoExpandFilter", "lockFloatButton", "minimapSquareOrbit",
		"rememberApplicationNote", "replaceOldestApplication",
		"showLeaderRealm", "showGameType", "sameClass", "zeroScore", "rangeAgeEn",
		"rangeIlvlEn", "rangeHonorEn", "hideVoice", "hideCrossRealm",
		"sameFactionOnly", "filterRoleMatchAll", "rangeMplusScoreEn",
		"groupMinimumItemLevelAdmission",
		"autoInviteMemberLimitEnabled", "autoInviteEnabled",
		"neteaseIdentityEnabled",
	}, false)
	assignSameValue(defaults, {
		"preferOpen", "showFloatButton", "showMinimap", "autoAcceptInvite",
		"lockApplicationList",
		"raidCarpoolSilent",
		"blacklistEnabled",--lnui
		-- "instanceGatewayEnabled",--lnui
		-- "showBlacklistChatNotice",--lnui
		"playstyle1", "playstyle2", "playstyle3", "playstyle4",
		"showFriendGroups", "showGuildGroups", "showHousewarmingGroups",
	}, true)
	return defaults
end

local DEFAULTS = makeAccountDefaults()
local CLIENT_FILTER_DEFAULTS = makeClientFilterDefaults()

function Schema:GetDefaults()
	return copyTable(DEFAULTS)
end

function Schema:GetClientFilterDefaults()
	return copyTable(CLIENT_FILTER_DEFAULTS)
end

local SAVED_SHAPE = {
	meta = {
		"v", "applyOptionDefaultVersion", "joinAnnounceDefaultVersion",
		"applicantAlertSoundDefaultVersion", "memberTooltipModeDefaultVersion",
		"teleportPromptModeDefaultVersion",
		"starredBackgroundDefaultVersion",
		"normalBackgroundDefaultVersion",
		"frameFooterLayoutVersion", "frameNavLayoutVersion",
		"browseColumnPresetVersion", "applicantColumnPresetVersion",
		"settingsFeatureSeenVersions",
	},
	workspace = { "workspaceMode" },
	locale = { "interfaceLocale", "debugInterfaceLocale" },
	frame = {
		"framePoint", "frameRelPoint", "frameX", "frameY", "frameW",
		"frameH", "frameStrata", "panelSkin", "panelScalePct",
		"workspaceTabPosition",
	},
	navigation = { "navWidth" },
	columns = {
		"browseColumnOrder", "browseColumnVisible",
		"applicantColumnOrder", "applicantColumnVisible", "browseSort",
		"applicantSort",
	},
	font = { "fontKey", "fontOutline", "fontScalePct" },
	launcher = {
		"showMinimap", "minimapAngle", "minimapSquareOrbit", "minimapIcon",
		"showFloatButton", "lockFloatButton", "floatPoint", "floatRelPoint",
		"floatX", "floatY", "floatScalePct", "preferOpen",
	},
	instanceGateway = {
		"instanceGatewayEnabled", "instanceGatewayPoint",
		"instanceGatewayRelPoint", "instanceGatewayX", "instanceGatewayY",
	},
	list = {
		"teamListColorScheme",
		"lockApplicationList",
		"raidCarpoolSilent",
		"showLeaderRealm", "showGameType", "memberDisplayMode", "expiredGroupMode",
		"memberTooltipMode",
		"listBackgroundAlphaPct", "listBackgroundStyles",
	},
	notifications = {
		"applicantAlertSoundFile", "joinAnnounceEnabled",
	},
	findGroup = {
		"autoExpandFilter", "menuEnhancementEnabled",
		"autoInviteMemberLimitEnabled", "autoInviteMemberLimit", "applyMode",
		"autoAcceptInvite", "rememberApplicationNote", "replaceOldestApplication",
		"autoInviteEnabled", "autoInviteEntrySig", "blacklistEnabled",
		"showBlacklistChatNotice",
	},
	neteaseIdentity = {
		"neteaseIdentityEnabled", "neteaseIdentityActivityId",
	},
	filters = {
		"maxAgeMin", "minIlvl", "sameClass", "zeroScore", "rangeAgeEn",
		"rangeAgeMin", "rangeAgeMax", "rangeIlvlEn", "rangeIlvlMin",
		"rangeIlvlMax", "rangeHonorEn", "rangeHonorMin", "rangeHonorMax",
		"rangeMplusScoreEn", "rangeMplusScoreMin", "rangeMplusScoreMax",
		"groupMinimumItemLevelAdmission",
		"hideVoice", "hideCrossRealm", "sameFactionOnly", "filterRoleMatchAll",
		"playstyle1", "playstyle2", "playstyle3", "playstyle4",
		"showFriendGroups", "showGuildGroups", "showHousewarmingGroups",
		"filterGlobalByBucket", "filterGlobalLegacyMigrated",
		"filterClientByCategory", "filterClientBucketMigrated",
		"filterDungeonActivities", "filterDungeonActivityKeys",
		"filterDungeonNone", "filterRaidActivities", "filterRaidActivityKeys",
		"filterRaidNone",
	},
	business = {
		"blocklist", "favoriteInstances", "favoriteInstanceOrders", "recentInstances", "starredLeaders",
		"userLetterReadVersion", "versionDiscovery", "raidSeekingDrafts", "raidSeekingReload", "raidSeekingChats",
		"raidRecruitmentRequirementsReload",
		"seasonRatingBindingDefaults",
	},
	mythicPlus = {
		"mythicPlus",
	},
}

function Schema:GetSavedShape()
	return copyTable(SAVED_SHAPE)
end

function Schema:GetKnownRootKeys()
	local keys = {}
	for _, group in pairs(SAVED_SHAPE) do
		for _, key in ipairs(group) do
			keys[key] = true
		end
	end
	return keys
end

local function appendSignature(parts, value)
	local valueType = type(value)
	if valueType ~= "table" then
		parts[#parts + 1] = valueType .. ":" .. tostring(value)
		return
	end
	parts[#parts + 1] = "table:{"
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(left, right)
		local leftType, rightType = type(left), type(right)
		if leftType == rightType then
			return tostring(left) < tostring(right)
		end
		return leftType < rightType
	end)
	for _, key in ipairs(keys) do
		appendSignature(parts, key)
		appendSignature(parts, value[key])
	end
	parts[#parts + 1] = "}"
end

function Schema:GetDefaultSignature()
	local parts = {}
	appendSignature(parts, DEFAULTS)
	return table.concat(parts, "|")
end

GF.defaults = Schema:GetDefaults()
GF.clientFilterDefaults = Schema:GetClientFilterDefaults()

local function clampColorComponent(value, fallback)
	value = toFiniteNumber(value)
	if value == nil then
		return fallback or 0
	end
	return math.max(0, math.min(1, value))
end

function Schema:ClampColorComponent(value, fallback)
	return clampColorComponent(value, fallback)
end

function Schema:GetListBackgroundStyleDefaults(styleKey)
	local defaults = GF.LIST_BACKGROUND_STYLE_DEFAULTS or {}
	styleKey = styleKey or "normal"
	return defaults[styleKey] or defaults.normal or {
		r = 1,
		g = 1,
		b = 1,
		alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100,
	}
end

function Schema:NormalizeListBackgroundStyleKey(styleKey)
	styleKey = tostring(styleKey or "normal")
	local stateMap = GF.LIST_BACKGROUND_STATE_TO_STYLE or {}
	styleKey = stateMap[styleKey] or styleKey
	local defaults = GF.LIST_BACKGROUND_STYLE_DEFAULTS or {}
	if defaults[styleKey] then
		return styleKey
	end
	return "normal"
end

function Schema:NormalizeListBackgroundStyle(styleKey, style, fallbackAlphaPct)
	styleKey = self:NormalizeListBackgroundStyleKey(styleKey)
	local defaults = self:GetListBackgroundStyleDefaults(styleKey)
	style = type(style) == "table" and style or {}
	local alphaPct = style.alphaPct
	if alphaPct == nil then
		alphaPct = style.aPct
	end
	if alphaPct == nil then
		alphaPct = fallbackAlphaPct
	end
	return {
		r = clampColorComponent(style.r, defaults.r or 1),
		g = clampColorComponent(style.g, defaults.g or 1),
		b = clampColorComponent(style.b, defaults.b or 1),
		alphaPct = self:ClampListBackgroundAlphaPct(
			alphaPct or defaults.alphaPct),
	}
end

function Schema:NormalizeListBackgroundStyles(database)
	if type(database) ~= "table" then
		return nil
	end
	local hadStyles = type(database.listBackgroundStyles) == "table"
	if not hadStyles then
		database.listBackgroundStyles = {}
	end
	local styles = database.listBackgroundStyles
	local legacyAlphaPct = self:ClampListBackgroundAlphaPct(
		database.listBackgroundAlphaPct)
	for _, styleKey in ipairs(GF.LIST_BACKGROUND_STYLE_ORDER or {
		"normal", "friend", "application", "censored", "warning", "disabled",
	}) do
		local fallbackAlphaPct
		if not hadStyles or styleKey == "normal" then
			fallbackAlphaPct = legacyAlphaPct
		end
		local current = styles[styleKey]
		local normalized = self:NormalizeListBackgroundStyle(
			styleKey, current, fallbackAlphaPct)
		if type(current) == "table" then
			current.r = normalized.r
			current.g = normalized.g
			current.b = normalized.b
			current.alphaPct = normalized.alphaPct
			current.aPct = nil
		else
			styles[styleKey] = normalized
		end
	end
	database.listBackgroundAlphaPct = styles.normal.alphaPct
	return styles
end

function Schema:NormalizeTeleportPromptSettings(settings)
	if type(settings) ~= "table" then
		return nil
	end
	local defaults = DEFAULTS.mythicPlus.settings
	if type(settings.groupReadyTeleportEnabled) ~= "boolean" then
		settings.groupReadyTeleportEnabled =
			defaults.groupReadyTeleportEnabled == true
	end
	if type(settings.teleportFollowEnabled) ~= "boolean" then
		settings.teleportFollowEnabled =
			defaults.teleportFollowEnabled == true
	end
	return settings
end

function Schema:NormalizeMythicPlus(database)
	if type(database) ~= "table" then
		return nil
	end
	if type(database.mythicPlus) ~= "table" then
		database.mythicPlus = {}
	end
	local mythicPlus = database.mythicPlus
	if type(mythicPlus.characters) ~= "table" then
		mythicPlus.characters = {}
	end
	for _, character in pairs(mythicPlus.characters) do
		if type(character) == "table" then
			character.carpoolEnabled = character.carpoolEnabled == true
		end
	end
	mythicPlus.carpoolCandidateDefaultVersion = math.max(
		0,
		math.floor(toFiniteNumber(
			mythicPlus.carpoolCandidateDefaultVersion) or 0))
	if type(mythicPlus.characterOrder) ~= "table" then
		mythicPlus.characterOrder = {}
	end
	local characterOrder = mythicPlus.characterOrder
	local seenCharacterKeys = {}
	for _, groupKey in ipairs({ "carpool", "other" }) do
		local source = type(characterOrder[groupKey]) == "table"
			and characterOrder[groupKey] or {}
		local numericKeys = {}
		for key in pairs(source) do
			if type(key) == "number" and key > 0 and key % 1 == 0 then
				numericKeys[#numericKeys + 1] = key
			end
		end
		table.sort(numericKeys)
		local normalized = {}
		for _, key in ipairs(numericKeys) do
			local characterKey = source[key]
			if type(characterKey) == "string"
				and characterKey ~= ""
				and not seenCharacterKeys[characterKey]
			then
				seenCharacterKeys[characterKey] = true
				normalized[#normalized + 1] = characterKey
			end
		end
		characterOrder[groupKey] = normalized
	end
	for key in pairs(characterOrder) do
		if key ~= "carpool" and key ~= "other" then
			characterOrder[key] = nil
		end
	end
	if type(mythicPlus.characterSettings) ~= "table" then
		mythicPlus.characterSettings = {}
	end
	if type(mythicPlus.seasonDungeonCache) ~= "table" then
		mythicPlus.seasonDungeonCache = {}
	end
	local seasonDungeonCache = mythicPlus.seasonDungeonCache
	if type(seasonDungeonCache.challengeModeIDs) ~= "table" then
		seasonDungeonCache.challengeModeIDs = {}
	end
	if type(mythicPlus.settings) ~= "table" then
		mythicPlus.settings = {}
	end
	local settings = mythicPlus.settings
	local settingDefaults = DEFAULTS.mythicPlus.settings
	for key, defaultValue in pairs(settingDefaults) do
		if type(settings[key]) ~= type(defaultValue) then
			settings[key] = defaultValue
		end
	end
	self:NormalizeTeleportPromptSettings(settings)
	settings.manualTacticalChannel =
		self:NormalizeManualTacticalChannel(
			settings.manualTacticalChannel)
	settings.autoOpenOnCompletedRun = nil
	return mythicPlus
end

local function normalizeFavoriteList(source)
	source = type(source) == "table" and source or {}
	local numericKeys = {}
	for key in pairs(source) do
		if type(key) == "number" and key > 0 and key % 1 == 0 then
			numericKeys[#numericKeys + 1] = key
		end
	end
	table.sort(numericKeys)
	local normalized, seen = {}, {}
	for _, key in ipairs(numericKeys) do
		local entry = source[key]
		local identity = type(entry) == "table" and entry.identity or nil
		if type(identity) == "string" and identity ~= "" and not seen[identity] then
			local identityCategory, identityActivity = identity:match(
				"^activity:(%d+):(%d+)$")
			local kind = entry.kind == "preset" and "preset"
				or (entry.kind == "activity" or identityCategory ~= nil)
					and "activity" or "instance"
			local categoryID = toFiniteNumber(entry.categoryID)
			local activityID = toFiniteNumber(entry.activityID)
			categoryID = categoryID and math.floor(categoryID) or nil
			activityID = activityID and math.floor(activityID) or nil
			if kind == "activity" and not (categoryID and activityID) then
				categoryID = categoryID or tonumber(identityCategory)
				activityID = activityID or tonumber(identityActivity)
			end
			local valid = kind == "instance"
				or (kind == "preset"
					and categoryID and categoryID > 0
					and activityID and activityID > 0)
				or (kind == "activity"
					and categoryID and categoryID > 0
					and activityID and activityID > 0
					and identity == string.format(
						"activity:%d:%d", categoryID, activityID))
			if valid then
				seen[identity] = true
				local record = {
					identity = identity,
					kind = kind,
					categoryID = kind ~= "instance" and categoryID or nil,
					activityID = kind ~= "instance" and activityID or nil,
					label = type(entry.label) == "string" and entry.label or nil,
					breadcrumb = type(entry.breadcrumb) == "string"
						and entry.breadcrumb or nil,
				}
				if kind == "preset" then
					local preset = type(entry.preset) == "table" and entry.preset or {}
					local groupID = toFiniteNumber(entry.groupID)
					record.groupID = groupID and math.floor(groupID) or nil
					record.instanceIdentity = type(entry.instanceIdentity) == "string"
						and entry.instanceIdentity or nil
					record.difficultyKey = type(entry.difficultyKey) == "string"
						and entry.difficultyKey or nil
					record.customName = type(entry.customName) == "string"
						and entry.customName ~= "" and entry.customName or nil
					record.preset = {
						generalPlaystyle = math.floor(
							toFiniteNumber(preset.generalPlaystyle) or 0),
						requiredItemLevel = math.max(
							0, toFiniteNumber(preset.requiredItemLevel) or 0),
						requiredDungeonScore = math.max(
							0, toFiniteNumber(preset.requiredDungeonScore) or 0),
						requiredPvpRating = math.max(
							0, toFiniteNumber(preset.requiredPvpRating) or 0),
						privateGroup = preset.privateGroup == true,
						factionRestricted = preset.factionRestricted == true,
					}
				end
				normalized[#normalized + 1] = record
			end
		end
	end
	for key in pairs(source) do
		source[key] = nil
	end
	for index, record in ipairs(normalized) do
		source[index] = record
	end
	return source
end

local function hasNumericFavoriteRecords(source)
	for key in pairs(source or {}) do
		if type(key) == "number" and key > 0 and key % 1 == 0 then
			return true
		end
	end
	return false
end

function Schema:NormalizeFavoriteInstances(database, characterKey)
	if type(database) ~= "table" then
		return nil
	end
	local source = type(database.favoriteInstances) == "table"
		and database.favoriteInstances or {}
	-- Before this change favoriteInstances was one account-wide dense array.
	-- Claim that legacy array for the first character whose stable identity is
	-- available. A partially migrated root may already contain character maps;
	-- preserve them and merge only the numeric legacy records into the current
	-- character instead of clearing the whole root.
	local legacyRecords
	if hasNumericFavoriteRecords(source) then
		legacyRecords = {}
		for key, record in pairs(source) do
			if type(key) == "number" and key > 0 and key % 1 == 0 then
				legacyRecords[key] = record
				source[key] = nil
			end
		end
		normalizeFavoriteList(legacyRecords)
	end
	for key, list in pairs(source) do
		if type(key) ~= "string" or key == "" or type(list) ~= "table" then
			source[key] = nil
		else
			normalizeFavoriteList(list)
		end
	end
	if legacyRecords then
		if type(characterKey) == "string" and characterKey ~= "" then
			local list = source[characterKey]
			if type(list) ~= "table" then
				list = {}
				source[characterKey] = list
			end
			for _, record in ipairs(legacyRecords) do
				list[#list + 1] = record
			end
			normalizeFavoriteList(list)
		else
			-- Identity is still warming up. Keep the normalized legacy array
			-- retryable at the root without inventing an account fallback key.
			for index, record in ipairs(legacyRecords) do
				source[index] = record
			end
		end
	end
	database.favoriteInstances = source
	return source
end

local function validRecentInstanceIdentity(identity)
	return type(identity) == "string" and #identity > 0 and #identity <= 512
		and not identity:find("%c")
end

function Schema:NormalizeRecentInstance(record)
	-- The retired string format only identified a dungeon, so its actual
	-- difficulty/scope cannot be recovered without inventing a past action.
	if type(record) ~= "table" or not validRecentInstanceIdentity(record.nodeKey)
		or not validRecentInstanceIdentity(record.label)
		or not self.RECENT_INSTANCE_ROOT_KINDS[record.rootKind]
		or type(record.path) ~= "table" or #record.path < 1 or #record.path > 8
	then return nil end
	local path = {}
	for _, key in ipairs(record.path) do
		if not validRecentInstanceIdentity(key) then return nil end
		path[#path + 1] = key
	end
	if path[#path] ~= record.nodeKey then return nil end
	local activityID
	if record.kind == "activity" then
		activityID = record.activityID
		if not isFiniteNumber(activityID) or activityID <= 0 or activityID % 1 ~= 0 then return nil end
	elseif record.kind ~= "scope" then return nil end
	return {
		kind = record.kind, nodeKey = record.nodeKey, rootKind = record.rootKind,
		label = record.label, path = path, activityID = activityID,
		identity = activityID and ("activity:" .. activityID)
			or ("scope:" .. record.rootKind .. ":" .. record.nodeKey),
	}
end

function Schema:NormalizeRecentInstances(database)
	local source = type(database.recentInstances) == "table"
		and database.recentInstances or {}
	for characterKey, list in pairs(source) do
		if type(characterKey) ~= "string" or characterKey == "" or type(list) ~= "table" then
			source[characterKey] = nil
		else
			local keys, normalized, seen = {}, {}, {}
			for key in pairs(list) do
				if isFiniteNumber(key) and key > 0 and key % 1 == 0 then
					keys[#keys + 1] = key
				end
			end
			table.sort(keys)
			for _, key in ipairs(keys) do
				local record = self:NormalizeRecentInstance(list[key])
				if record and not seen[record.identity] then
					normalized[#normalized + 1] = record
					seen[record.identity] = true
					if #normalized == self.RECENT_INSTANCE_LIMIT then break end
				end
			end
			source[characterKey] = normalized
		end
	end
	database.recentInstances = source
	return source
end

function Schema:GetCharacterRecentInstances(database, characterKey, create)
	if type(database) ~= "table" or type(characterKey) ~= "string" or characterKey == "" then
		return nil
	end
	local source = database.recentInstances
	if type(source) ~= "table" then
		if not create then return nil end
		source = self:NormalizeRecentInstances(database)
	end
	local list = source[characterKey]
	if type(list) ~= "table" then
		if not create then return nil end
		list = {}
		source[characterKey] = list
	end
	return list
end

function Schema:RecordRecentInstance(database, characterKey, record)
	record = self:NormalizeRecentInstance(record)
	if not record then return false end
	local list = self:GetCharacterRecentInstances(database, characterKey, true)
	if not list then return false end
	for index = #list, 1, -1 do
		if type(list[index]) ~= "table" or list[index].identity == record.identity then
			table.remove(list, index)
		end
	end
	table.insert(list, 1, record)
	for index = #list, self.RECENT_INSTANCE_LIMIT + 1, -1 do list[index] = nil end
	return true
end

function Schema:ClearCharacterRecentInstances(database, characterKey)
	local list = self:GetCharacterRecentInstances(database, characterKey, false)
	if not list then return false end
	database.recentInstances[characterKey] = nil
	return true
end

function Schema:GetCharacterFavoriteInstances(database, characterKey, create)
	if type(database) ~= "table" or type(characterKey) ~= "string"
		or characterKey == ""
	then
		return nil
	end
	local source = self:NormalizeFavoriteInstances(database, characterKey)
	local list = source and source[characterKey]
	if type(list) ~= "table" and create == true then
		list = {}
		source[characterKey] = list
	end
	return list
end

local function normalizeFavoriteOrder(source)
	source = type(source) == "table" and source or {}
	local normalized, seen = {}, {}
	for _, handle in ipairs(source) do
		local scope, identity
		if type(handle) == "string" then
			scope, identity = handle:match("^(character)::(.+)$")
			if not scope then
				scope, identity = handle:match("^(warband)::(.+)$")
			end
		end
		if identity and identity ~= "" and not seen[handle] then
			seen[handle] = true
			normalized[#normalized + 1] = handle
		end
	end
	for key in pairs(source) do
		source[key] = nil
	end
	for index, handle in ipairs(normalized) do
		source[index] = handle
	end
	return source
end

function Schema:NormalizeFavoriteInstanceOrders(database)
	if type(database) ~= "table" then
		return nil
	end
	local source = type(database.favoriteInstanceOrders) == "table"
		and database.favoriteInstanceOrders or {}
	for key, order in pairs(source) do
		if type(key) ~= "string" or key == "" or type(order) ~= "table" then
			source[key] = nil
		else
			normalizeFavoriteOrder(order)
		end
	end
	database.favoriteInstanceOrders = source
	return source
end

function Schema:GetCharacterFavoriteInstanceOrder(database, characterKey, create)
	if type(database) ~= "table" or type(characterKey) ~= "string"
		or characterKey == ""
	then
		return nil
	end
	local source = self:NormalizeFavoriteInstanceOrders(database)
	local order = source and source[characterKey]
	if type(order) ~= "table" and create == true then
		order = {}
		source[characterKey] = order
	end
	return order
end

local SETTINGS_CATEGORY_DEFAULT_KEYS = {
	appearance = {
		"showFloatButton", "lockFloatButton", "floatPoint", "floatRelPoint",
		"floatX", "floatY", "floatScalePct", "showMinimap", "minimapSquareOrbit", "preferOpen",
		"workspaceTabPosition",
		"instanceGatewayEnabled", "instanceGatewayPoint", "instanceGatewayRelPoint",
		"instanceGatewayX", "instanceGatewayY",
		"interfaceLocale",
		"fontKey", "fontOutline", "fontScalePct", "frameStrata", "panelSkin", "panelScalePct",
	},
	party_list = {
		"teamListColorScheme",
		"lockApplicationList",
		"raidCarpoolSilent",
		"showLeaderRealm", "showGameType", "memberDisplayMode", "expiredGroupMode",
		"memberTooltipMode",
	},
	notifications = { "applicantAlertSoundFile", "joinAnnounceEnabled" },
	find_group = {
		"autoInviteMemberLimitEnabled", "autoInviteMemberLimit", "applyMode",
		"autoAcceptInvite", "rememberApplicationNote", "replaceOldestApplication",
		"autoExpandFilter", "blacklistEnabled", "showBlacklistChatNotice", "menuEnhancementEnabled",
	},
	netease_newbie = {
		"neteaseIdentityEnabled", "neteaseIdentityActivityId",
	},
}

local SETTINGS_LIST_STYLE_KEYS = {
	"normal", "friend", "starred", "newbie", "censored", "warning", "disabled",
}

local SETTINGS_NOTIFICATION_MYTHIC_PLUS_KEYS = {
	"groupReadyTeleportEnabled", "keystoneRotationReminderEnabled",
	"teleportFollowEnabled",
	"teleportAnnouncementEnabled", "keystoneAnnouncementEnabled",
}

local function restoreDefaultValue(database, key)
	local value = DEFAULTS[key]
	database[key] = type(value) == "table" and copyTable(value) or value
end

function Schema:ResetCategory(database, categoryID, context)
	local keys = SETTINGS_CATEGORY_DEFAULT_KEYS[categoryID]
	if type(database) ~= "table" or not keys then
		return false
	end
	for _, key in ipairs(keys) do
		restoreDefaultValue(database, key)
	end
	if categoryID == "party_list" then
		database.listBackgroundStyles =
			type(database.listBackgroundStyles) == "table"
				and database.listBackgroundStyles or {}
		local styleDefaults = DEFAULTS.listBackgroundStyles or {}
		for _, styleKey in ipairs(SETTINGS_LIST_STYLE_KEYS) do
			local style = styleDefaults[styleKey]
				or self:GetListBackgroundStyleDefaults(styleKey)
			database.listBackgroundStyles[styleKey] = copyTable(style)
		end
		database.listBackgroundAlphaPct =
			database.listBackgroundStyles.normal.alphaPct
	elseif categoryID == "notifications" then
		local mythicPlus = self:NormalizeMythicPlus(database)
		for _, key in ipairs(SETTINGS_NOTIFICATION_MYTHIC_PLUS_KEYS) do
			mythicPlus.settings[key] = DEFAULTS.mythicPlus.settings[key]
		end
	elseif categoryID == "find_group"
		and context and type(context.resetDefaultRequiredItemLevel) == "function"
	then
		context.resetDefaultRequiredItemLevel(
			GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0)
	end
	return true
end

local BOOLEAN_KEYS = {
	"lockApplicationList",
	"raidCarpoolSilent",
	"autoExpandFilter", "lockFloatButton", "minimapSquareOrbit",
	"rememberApplicationNote", "replaceOldestApplication", "showLeaderRealm", "showGameType",
	"sameClass", "zeroScore", "rangeAgeEn", "rangeIlvlEn", "rangeHonorEn",
	"hideVoice", "hideCrossRealm", "sameFactionOnly", "filterRoleMatchAll",
	"rangeMplusScoreEn", "autoInviteMemberLimitEnabled", "autoInviteEnabled",
	"groupMinimumItemLevelAdmission",
	"preferOpen", "showFloatButton", "showMinimap", "autoAcceptInvite",
	"joinAnnounceEnabled", "menuEnhancementEnabled", "blacklistEnabled",
	"instanceGatewayEnabled",
	"showBlacklistChatNotice", "neteaseIdentityEnabled",
	"playstyle1", "playstyle2", "playstyle3", "playstyle4",
	"showFriendGroups", "showGuildGroups", "showHousewarmingGroups",
}

local NONNEGATIVE_INTEGER_KEYS = {
	"maxAgeMin", "minIlvl", "rangeAgeMin", "rangeAgeMax", "rangeIlvlMin",
	"rangeIlvlMax", "rangeHonorMin", "rangeHonorMax", "rangeMplusScoreMin",
	"rangeMplusScoreMax",
}

local OPTIONAL_TABLE_KEYS = {
	"browseColumnOrder", "browseColumnVisible", "applicantColumnOrder",
	"applicantColumnVisible", "applicantSort", "minimapIcon",
	"filterDungeonActivities", "filterDungeonActivityKeys",
	"filterRaidActivities", "filterRaidActivityKeys",
}

local VALID_ANCHOR_POINTS = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}

local function normalizeOptionalString(value)
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function normalizeBoolean(value, defaultValue)
	if type(value) == "boolean" then
		return value
	end
	return defaultValue == true
end

local function normalizeAnchor(database, prefix)
	local pointKey = prefix .. "Point"
	local relativePointKey = prefix .. "RelPoint"
	local xKey = prefix .. "X"
	local yKey = prefix .. "Y"
	local point = database[pointKey]
	local relativePoint = database[relativePointKey]
	local x = toFiniteNumber(database[xKey])
	local y = toFiniteNumber(database[yKey])
	if not VALID_ANCHOR_POINTS[point] or x == nil or y == nil then
		database[pointKey] = nil
		database[relativePointKey] = nil
		database[xKey] = nil
		database[yKey] = nil
		return
	end
	database[pointKey] = point
	database[relativePointKey] = VALID_ANCHOR_POINTS[relativePoint]
		and relativePoint or nil
	database[xKey] = x
	database[yKey] = y
end

local function normalizeWorkspaceMode(value)
	if value == (GF.WORKSPACE_RAID or "raid") then return GF.WORKSPACE_RAID or "raid" end
	if value == (GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus") then
		return GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus"
	end
	return GF.WORKSPACE_DEFAULT or GF.WORKSPACE_MEETING_STONE or "standard"
end

local function normalizeApplyMode(value)
	if value == (GF.APPLY_MANUAL or "manual") then
		return GF.APPLY_MANUAL or "manual"
	end
	if value == (GF.APPLY_CLICK_CONFIRM or "click_confirm") then
		return GF.APPLY_CLICK_CONFIRM or "click_confirm"
	end
	return GF.APPLY_DBLCLICK_AUTO or "dblclick_auto"
end

local function normalizeFrameStrata(value)
	local choices = GF.FRAME_STRATA_CHOICES or {}
	for index = 1, #choices do
		if choices[index] == value then
			return value
		end
	end
	return GF.FRAME_STRATA_DEFAULT or "MEDIUM"
end

function Schema:IsValidFrameStrata(value)
	local choices = GF.FRAME_STRATA_CHOICES or {}
	for index = 1, #choices do
		if choices[index] == value then
			return true
		end
	end
	return false
end

function Schema:NormalizeFrameStrata(value)
	return normalizeFrameStrata(value)
end

function Schema:NormalizePanelSkin(value)
	for _, option in ipairs(GF.PANEL_SKIN_OPTIONS or {}) do
		if option.value == value then
			return value
		end
	end
	return GF.PANEL_SKIN_DEFAULT or "default"
end

function Schema:NormalizeInterfaceLocale(value)
	if value == "zhCN" or value == "zhTW" or value == "enUS" or value == "ruRU" then
		return value
	end
	return "system"
end

function Schema:NormalizeWorkspaceTabPosition(value)
	if value == "left" or value == "bottom" then
		return value
	end
	return GF.WORKSPACE_TAB_POSITION_DEFAULT or "right"
end

local function normalizeFontOutline(value)
	if value == "OUTLINE" or value == "THICKOUTLINE" then
		return value
	end
	return "NONE"
end

local function normalizeSort(value, allowNil)
	if type(value) ~= "table" then
		return allowNil and nil or { column = "title", asc = true }
	end
	if type(value.column) ~= "string" or value.column == "" then
		return allowNil and nil or { column = "title", asc = true }
	end
	value.asc = value.asc == true
	return value
end

function Schema:NormalizeRoot(database, context)
	if type(database) ~= "table" then
		return nil
	end
	if type(database.userLetterReadVersion) ~= "string" then
		database.userLetterReadVersion = ""
	end
	if type(database.seasonRatingBindingDefaults) ~= "table" then
		database.seasonRatingBindingDefaults = nil
	else
		for profile, initialized in pairs(database.seasonRatingBindingDefaults) do
			if initialized ~= true or type(profile) ~= "string"
				or (profile ~= "account" and not profile:match("^Player%-.+")) then
				database.seasonRatingBindingDefaults[profile] = nil
			end
		end
	end
	local savedVersion = toFiniteNumber(database.v)
	database.v = savedVersion and math.max(
		Schema.VERSION, math.floor(savedVersion)) or Schema.VERSION
	database.frameFooterLayoutVersion = math.max(
		GF.FRAME_FOOTER_LAYOUT_VERSION or 3,
		math.floor(toFiniteNumber(database.frameFooterLayoutVersion)
			or (GF.FRAME_FOOTER_LAYOUT_VERSION or 3)))
	database.frameNavLayoutVersion = math.max(
		GF.FRAME_NAV_LAYOUT_VERSION or 2,
		math.floor(toFiniteNumber(database.frameNavLayoutVersion)
			or (GF.FRAME_NAV_LAYOUT_VERSION or 2)))
	for _, key in ipairs(BOOLEAN_KEYS) do
		database[key] = normalizeBoolean(database[key], DEFAULTS[key])
	end
	for _, key in ipairs(NONNEGATIVE_INTEGER_KEYS) do
		database[key] = roundAndClamp(database[key], DEFAULTS[key], 0)
	end
	-- Wheel distance is a shared internal default, no longer an account setting.
	database.listWheelScrollRows = nil
	database.autoInviteMemberLimit = roundAndClamp(
		database.autoInviteMemberLimit,
		DEFAULTS.autoInviteMemberLimit,
		GF.AUTO_INVITE_MEMBER_LIMIT_MIN or 1,
		GF.AUTO_INVITE_MEMBER_LIMIT_MAX or 40)
	database.panelScalePct = self:ClampPanelScalePct(database.panelScalePct)
	database.floatScalePct = self:ClampFloatScalePct(database.floatScalePct)
	database.fontScalePct = self:ClampFontScalePct(database.fontScalePct)
	database.listBackgroundAlphaPct = self:ClampListBackgroundAlphaPct(
		database.listBackgroundAlphaPct)
	database.navWidth = self:ClampNavWidth(database.navWidth)
	database.frameW, database.frameH = self:NormalizeFrameSize(
		database.frameW, database.frameH)
	database.minimapAngle = toFiniteNumber(database.minimapAngle)
		or DEFAULTS.minimapAngle
	database.starredLeaders = type(database.starredLeaders) == "table" and database.starredLeaders or {}
	database.raidSeekingDrafts = type(database.raidSeekingDrafts) == "table" and database.raidSeekingDrafts or {}
	database.raidSeekingReload = type(database.raidSeekingReload) == "table" and database.raidSeekingReload or {}
	database.raidSeekingChats = type(database.raidSeekingChats) == "table" and database.raidSeekingChats or {}
	database.raidRecruitmentRequirementsReload = type(database.raidRecruitmentRequirementsReload) == "table"
		and database.raidRecruitmentRequirementsReload or {}
	database.workspaceMode = normalizeWorkspaceMode(database.workspaceMode)
	database.workspaceTabPosition = self:NormalizeWorkspaceTabPosition(
		database.workspaceTabPosition)
	database.applyMode = normalizeApplyMode(database.applyMode)
	database.teamListColorScheme = self:NormalizeTeamListColorScheme(
		database.teamListColorScheme)
	database.memberDisplayMode = self:NormalizeMemberDisplayMode(
		database.memberDisplayMode)
	database.expiredGroupMode = self:NormalizeExpiredGroupMode(
		database.expiredGroupMode)
	database.memberTooltipMode = self:NormalizeMemberTooltipMode(
		database.memberTooltipMode)
	database.applicantAlertSoundFile = self:NormalizeApplicantAlertSoundFile(
		database.applicantAlertSoundFile)
	database.frameStrata = normalizeFrameStrata(database.frameStrata)
	database.panelSkin = self:NormalizePanelSkin(database.panelSkin)
	database.interfaceLocale = self:NormalizeInterfaceLocale(
		database.interfaceLocale)
	local debugLocale = self:NormalizeInterfaceLocale(database.debugInterfaceLocale)
	database.debugInterfaceLocale = debugLocale ~= "system" and debugLocale or nil
	database.fontKey = normalizeOptionalString(database.fontKey)
		or DEFAULTS.fontKey
	database.fontOutline = normalizeFontOutline(database.fontOutline)
	normalizeAnchor(database, "frame")
	normalizeAnchor(database, "float")
	normalizeAnchor(database, "instanceGateway")

	for _, key in ipairs({
		"filterClientByCategory", "filterGlobalByBucket",
		"filterClientBucketMigrated", "versionDiscovery",
		"settingsFeatureSeenVersions",
	}) do
		if type(database[key]) ~= "table" then
			database[key] = {}
		end
	end
	if type(database.blocklist) ~= "table" then
		database.blocklist = {}
	end
	for _, key in ipairs(OPTIONAL_TABLE_KEYS) do
		if database[key] ~= nil and type(database[key]) ~= "table" then
			database[key] = nil
		end
	end
	if type(database.minimapIcon) == "table" then
		local icon = database.minimapIcon
		if icon.hide ~= nil and type(icon.hide) ~= "boolean" then
			icon.hide = nil
		end
		icon.minimapPos = toFiniteNumber(icon.minimapPos)
	end
	database.autoInviteEntrySig = normalizeOptionalString(
		database.autoInviteEntrySig)
	database.neteaseIdentityActivityId =
		normalizeOptionalString(database.neteaseIdentityActivityId) or ""
	database.filterGlobalLegacyMigrated =
		type(database.filterGlobalLegacyMigrated) == "boolean"
			and database.filterGlobalLegacyMigrated or nil
	database.filterDungeonNone = database.filterDungeonNone == true
		and true or nil
	database.filterRaidNone = database.filterRaidNone == true and true or nil
	database.browseSort = normalizeSort(database.browseSort, false)
	database.applicantSort = normalizeSort(database.applicantSort, true)
	self:NormalizeListBackgroundStyles(database)
	self:NormalizeMythicPlus(database)
	local characterKey = context
		and type(context.getCurrentCharacterKey) == "function"
		and context.getCurrentCharacterKey() or nil
	self:NormalizeFavoriteInstances(database, characterKey)
	self:NormalizeFavoriteInstanceOrders(database)
	self:NormalizeRecentInstances(database)
	return database
end

local function isLegacyFloatDefault(database)
	if type(database) ~= "table" then
		return false
	end
	local x = toFiniteNumber(database.floatX)
	local y = toFiniteNumber(database.floatY)
	return database.floatPoint == "TOP"
		and (database.floatRelPoint == nil or database.floatRelPoint == "TOP")
		and x ~= nil and y ~= nil
		and math.floor(x + 0.5) == 0
		and math.floor(y + 0.5) == -80
end

local function migrateFrameFooterLayout(database, previous)
	local currentVersion = GF.FRAME_FOOTER_LAYOUT_VERSION or 3
	if previous.version >= currentVersion then
		return
	end
	if previous.height then
		local migratedHeight = previous.height
		if previous.version < 2 then
			local heightDelta
			if previous.version == 1 then
				heightDelta = (GF.FRAME_PREVIOUS_PANEL_BOTTOM or 36)
					- (GF.FRAME_INTERIM_PANEL_BOTTOM or 44)
			elseif math.floor(migratedHeight + 0.5)
				== (GF.FRAME_INTERIM_DEFAULT_H or 560)
			then
				migratedHeight = GF.FRAME_PREVIOUS_DEFAULT_H or 552
			else
				heightDelta = (GF.FRAME_PREVIOUS_PANEL_BOTTOM or 36)
					- (GF.FRAME_LEGACY_PANEL_BOTTOM or 24)
			end
			if heightDelta then
				migratedHeight = migratedHeight + heightDelta
			end
		end
		if previous.version < 3
			and math.floor(migratedHeight + 0.5)
				== (GF.FRAME_PREVIOUS_DEFAULT_H or 552)
		then
			migratedHeight = GF.FRAME_H or 550
		end
		database.frameH = migratedHeight
	end
	database.frameFooterLayoutVersion = currentVersion
end

local function migrateFrameNavigationLayout(database, previous)
	local currentVersion = GF.FRAME_NAV_LAYOUT_VERSION or 2
	if previous.version >= currentVersion then
		return
	end
	local currentWidth = toFiniteNumber(database.frameW)
		or previous.width or GF.FRAME_W
	local currentHeight = toFiniteNumber(database.frameH)
		or previous.height or GF.FRAME_H
	local previousDefaultWidth = GF.FRAME_PREVIOUS_DEFAULT_W or 1120
	local previousDefaultHeight = GF.FRAME_PREVIOUS_NAV_DEFAULT_H or 550
	local wasPreviousDefault = math.floor(currentWidth + 0.5)
		== previousDefaultWidth
		and math.floor(currentHeight + 0.5) == previousDefaultHeight
	local wasPreFooterDefault = previous.width
		and math.floor(previous.width + 0.5) == previousDefaultWidth
		and previous.height
		and (math.floor(previous.height + 0.5) == previousDefaultHeight
			or math.floor(previous.height + 0.5)
				== (GF.FRAME_PREVIOUS_DEFAULT_H or 552))
	if wasPreviousDefault or wasPreFooterDefault then
		database.frameW = GF.FRAME_W
		database.frameH = GF.FRAME_H
	else
		local minimumWidth = GF.FRAME_MIN_W or GF.FRAME_W or 1220
		local minimumHeight = GF.FRAME_MIN_H or GF.FRAME_H or 597
		if currentWidth < minimumWidth then
			database.frameW = minimumWidth
		end
		if currentHeight < minimumHeight then
			database.frameH = minimumHeight
		end
	end
	database.frameNavLayoutVersion = currentVersion
end

local function migrateDefaultVersions(database, previous)
	if previous.applyOption ~= APPLY_OPTION_DEFAULT_VERSION then
		database.applyMode = GF.APPLY_DBLCLICK_AUTO or "dblclick_auto"
		database.autoAcceptInvite = true
		database.applyOptionDefaultVersion = APPLY_OPTION_DEFAULT_VERSION
	end
	if previous.joinAnnounce ~= JOIN_ANNOUNCE_DEFAULT_VERSION then
		database.joinAnnounceEnabled = true
		database.joinAnnounceDefaultVersion = JOIN_ANNOUNCE_DEFAULT_VERSION
	end
	if previous.memberTooltip ~= MEMBER_TOOLTIP_MODE_DEFAULT_VERSION then
		database.memberTooltipMode = GF.MEMBER_TOOLTIP_MODE_DEFAULT
			or GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
		database.memberTooltipModeDefaultVersion =
			MEMBER_TOOLTIP_MODE_DEFAULT_VERSION
	end
	if previous.applicantAlertSound ~= APPLICANT_ALERT_SOUND_DEFAULT_VERSION then
		if database.applicantAlertSoundFile == nil
			or database.applicantAlertSoundFile
				== GF.APPLICANT_ALERT_SOUND_LEGACY_DEFAULT
		then
			database.applicantAlertSoundFile =
				GF.APPLICANT_ALERT_SOUND_DEFAULT or "xalatath.mp3"
		end
		database.applicantAlertSoundDefaultVersion =
			APPLICANT_ALERT_SOUND_DEFAULT_VERSION
	end
end

local function migrateNormalBackgroundDefault(database, previousVersion)
	previousVersion = math.max(0, math.floor(toFiniteNumber(previousVersion) or 0))
	local style = database.listBackgroundStyles and database.listBackgroundStyles.normal
	local defaults = GF.LIST_BACKGROUND_STYLE_DEFAULTS and GF.LIST_BACKGROUND_STYLE_DEFAULTS.normal
	if previousVersion < NORMAL_BACKGROUND_DEFAULT_VERSION
		and type(style) == "table" and defaults
		and style.r == 1 and style.g == 1 and style.b == 1
	then
		-- Legacy white revealed the atlas's gold. Preserve that meaning once;
		-- white chosen after migration must remain an actual white tint.
		style.r, style.g, style.b = defaults.r, defaults.g, defaults.b
	end
	database.normalBackgroundDefaultVersion = math.max(previousVersion, NORMAL_BACKGROUND_DEFAULT_VERSION)
end

local function migrateStarredBackgroundDefault(database, previousVersion)
	previousVersion = math.max(0, math.floor(toFiniteNumber(previousVersion) or 0))
	local style = database.listBackgroundStyles and database.listBackgroundStyles.starred
	local defaults = GF.LIST_BACKGROUND_STYLE_DEFAULTS and GF.LIST_BACKGROUND_STYLE_DEFAULTS.starred
	if previousVersion < STARRED_BACKGROUND_DEFAULT_VERSION
		and type(style) == "table" and defaults
		and math.abs((toFiniteNumber(style.r) or -1) - 1) < 0.5 / 255
		and math.abs((toFiniteNumber(style.g) or -1) - 196 / 255) < 0.5 / 255
		and math.abs((toFiniteNumber(style.b) or -1) - 77 / 255) < 0.5 / 255
	then
		-- Upgrade only the former amber default; retain opacity and custom colors.
		style.r, style.g, style.b = defaults.r, defaults.g, defaults.b
	end
	database.starredBackgroundDefaultVersion = math.max(previousVersion, STARRED_BACKGROUND_DEFAULT_VERSION)
end

local function migrateTeleportPromptModeDefault(database, previousVersion)
	previousVersion = math.max(
		0,
		math.floor(toFiniteNumber(previousVersion) or 0))
	-- Keep the rollout marker for compatibility, but never reinterpret an
	-- existing account's two independent prompt choices. Missing fields were
	-- already filled from the current defaults by mergeMissingValues().
	database.teleportPromptModeDefaultVersion = math.max(
		previousVersion,
		TELEPORT_PROMPT_MODE_DEFAULT_VERSION)
end

local function migrateCarpoolCandidateDefault(database, previousVersion)
	local mythicPlus = database.mythicPlus
	if type(mythicPlus) ~= "table" then
		return
	end
	previousVersion = math.max(
		0,
		math.floor(toFiniteNumber(previousVersion) or 0))
	if previousVersion < CARPOOL_CANDIDATE_DEFAULT_VERSION then
		for _, character in pairs(mythicPlus.characters or {}) do
			if type(character) == "table" then
				character.carpoolEnabled = false
			end
		end
		local characterOrder = mythicPlus.characterOrder or {}
		local nextOther = {}
		local seen = {}
		local function appendOrder(source)
			for _, characterKey in ipairs(
				type(source) == "table" and source or {})
			do
				if type(characterKey) == "string"
					and characterKey ~= ""
					and not seen[characterKey]
				then
					seen[characterKey] = true
					nextOther[#nextOther + 1] = characterKey
				end
			end
		end
		appendOrder(characterOrder.other)
		appendOrder(characterOrder.carpool)
		characterOrder.carpool = {}
		characterOrder.other = nextOther
		mythicPlus.characterOrder = characterOrder
	end
	mythicPlus.carpoolCandidateDefaultVersion = math.max(
		previousVersion,
		CARPOOL_CANDIDATE_DEFAULT_VERSION)
end

local function migrateColumnPresets(database, previous)
	local browseVersion = GF.BROWSE_COLUMN_PRESET_VERSION or 2
	if previous.browseColumnPreset ~= browseVersion then
		local frameWidth = toFiniteNumber(database.frameW)
		local legacyFrameWidth = GF.FRAME_W_LEGACY_DEFAULT or 1024
		if not frameWidth
			or math.floor(frameWidth + 0.5) == legacyFrameWidth
		then
			database.frameW = GF.FRAME_W
		end
		database.browseColumnOrder = nil
		database.browseColumnVisible = nil
		database.browseSort = { column = "title", asc = true }
		database.browseColumnPresetVersion = browseVersion
	end
	local applicantVersion = GF.APPLICANT_COLUMN_PRESET_VERSION or 1
	if previous.applicantColumnPreset ~= applicantVersion then
		database.applicantColumnOrder = nil
		database.applicantColumnVisible = nil
		database.applicantColumnPresetVersion = applicantVersion
	end
end

function Schema:MigrateAndNormalize(database, context)
	if type(database) ~= "table" then
		return nil
	end
	local legacyMigration = GF.LegacySettingsMigration
	if legacyMigration
		and type(legacyMigration.UpgradeRootKeys) == "function"
	then
		legacyMigration:UpgradeRootKeys(database)
	end
	local previous = {
		browseColumnPreset = database.browseColumnPresetVersion,
		applicantColumnPreset = database.applicantColumnPresetVersion,
		frameFooter = {
			version = toFiniteNumber(database.frameFooterLayoutVersion) or 0,
			height = toFiniteNumber(database.frameH),
		},
		frameNavigation = {
			version = toFiniteNumber(database.frameNavLayoutVersion) or 0,
			width = toFiniteNumber(database.frameW),
			height = toFiniteNumber(database.frameH),
		},
		applyOption = database.applyOptionDefaultVersion,
		joinAnnounce = database.joinAnnounceDefaultVersion,
		memberTooltip = database.memberTooltipModeDefaultVersion,
		applicantAlertSound = database.applicantAlertSoundDefaultVersion,
		teleportPromptMode = database.teleportPromptModeDefaultVersion,
		starredBackground = database.starredBackgroundDefaultVersion,
		normalBackground = database.normalBackgroundDefaultVersion,
		carpoolCandidateDefault = type(database.mythicPlus) == "table"
			and database.mythicPlus.carpoolCandidateDefaultVersion or nil,
	}
	mergeMissingValues(database, DEFAULTS)
	migrateFrameFooterLayout(database, previous.frameFooter)
	migrateFrameNavigationLayout(database, previous.frameNavigation)
	if isLegacyFloatDefault(database) then
		database.floatPoint = nil
		database.floatRelPoint = nil
		database.floatX = nil
		database.floatY = nil
	end
	migrateDefaultVersions(database, previous)
	migrateTeleportPromptModeDefault(database, previous.teleportPromptMode)
	self:NormalizeRoot(database, context)
	migrateNormalBackgroundDefault(database, previous.normalBackground)
	migrateStarredBackgroundDefault(database, previous.starredBackground)
	migrateCarpoolCandidateDefault(
		database,
		previous.carpoolCandidateDefault)
	if context
		and type(context.migrateLegacyDefaultRequiredItemLevel) == "function"
	then
		context.migrateLegacyDefaultRequiredItemLevel(database)
	end
	-- Navigation history was retired when Quick Search became session-only.
	database.history = nil
	-- Column widths now come only from the built-in layout definitions.
	database.browseColumnLayout = nil
	-- These names belong to the TabBar/LFGWorkspaceView runtime objects. If a
	-- development build ever leaked them into the account root, retire only the
	-- two explicit session fields while preserving all other unknown keys.
	database.currentByWorkspace = nil
	database.stateByWorkspace = nil
	migrateColumnPresets(database, previous)
	return database
end

function Schema:ResetAll(database)
	if type(database) ~= "table" then
		return nil
	end
	local savedUserLetterReadVersion = database.userLetterReadVersion
	local savedSeasonRatingBindingDefaults = database.seasonRatingBindingDefaults
	local savedStarredLeaders = type(database.starredLeaders) == "table" and database.starredLeaders or nil
	local savedSeekingDrafts = type(database.raidSeekingDrafts) == "table" and database.raidSeekingDrafts or nil
	local savedSeekingChats = type(database.raidSeekingChats) == "table" and database.raidSeekingChats or nil
	local savedBlocklist = type(database.blocklist) == "table"
		and database.blocklist or nil
	local savedFavoriteInstances = type(database.favoriteInstances) == "table"
		and database.favoriteInstances or nil
	local savedRecentInstances = type(database.recentInstances) == "table"
		and database.recentInstances or nil
	local savedFavoriteInstanceOrders =
		type(database.favoriteInstanceOrders) == "table"
			and database.favoriteInstanceOrders or nil
	local savedSettingsFeatureSeenVersions =
		type(database.settingsFeatureSeenVersions) == "table"
			and database.settingsFeatureSeenVersions or nil
	for key in next, database do
		database[key] = nil
	end
	local restored = self:GetDefaults()
	for key, value in next, restored do
		database[key] = value
	end
	database.userLetterReadVersion = savedUserLetterReadVersion
	database.seasonRatingBindingDefaults = savedSeasonRatingBindingDefaults
	if savedStarredLeaders ~= nil then database.starredLeaders = savedStarredLeaders end
	if savedSeekingDrafts ~= nil then database.raidSeekingDrafts = savedSeekingDrafts end
	if savedSeekingChats ~= nil then
		for _, history in pairs(savedSeekingChats) do
			if type(history) == "table" then history.continuity = nil end
		end
		database.raidSeekingChats = savedSeekingChats
	end
	if savedBlocklist ~= nil then
		database.blocklist = savedBlocklist
	end
	if savedFavoriteInstances ~= nil then
		database.favoriteInstances = savedFavoriteInstances
	end
	if savedRecentInstances ~= nil then
		database.recentInstances = savedRecentInstances
	end
	if savedFavoriteInstanceOrders ~= nil then
		database.favoriteInstanceOrders = savedFavoriteInstanceOrders
	end
	if savedSettingsFeatureSeenVersions ~= nil then
		database.settingsFeatureSeenVersions =
			savedSettingsFeatureSeenVersions
	end
	self:NormalizeRoot(database)
	database.history = nil
	return database
end

local function currentGlobal(name)
	if type(_G) ~= "table" then
		return nil
	end
	return _G[name]
end

local function setGlobal(name, value)
	if type(_G) == "table" then
		_G[name] = value
	end
end

function Repository:Initialize(context)
	local database = currentGlobal("GroupFinderDB")
	if type(database) ~= "table" then
		database = Schema:GetDefaults()
		setGlobal("GroupFinderDB", database)
	end
	Schema:MigrateAndNormalize(database, context)
	GF.db = database
	GF.DB = database
	return database
end

function Repository:Get(context)
	if type(GF.db) == "table" then
		if GF.DB ~= GF.db then
			GF.DB = GF.db
		end
		return GF.db
	end
	return self:Initialize(context)
end

function Repository:ResetCategory(categoryID, context)
	local database = self:Get(context)
	return database, Schema:ResetCategory(database, categoryID, context)
end

function Repository:ResetAll(context)
	local database = self:Get(context)
	Schema:ResetAll(database)
	GF.db = database
	GF.DB = database
	setGlobal("GroupFinderDB", database)
	return database
end
