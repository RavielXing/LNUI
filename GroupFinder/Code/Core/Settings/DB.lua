local _, GF = ...

local APPLY_OPTION_DEFAULT_VERSION = 1
local JOIN_ANNOUNCE_DEFAULT_VERSION = 1
local MEMBER_TOOLTIP_MODE_DEFAULT_VERSION = 1
local APPLICANT_ALERT_SOUND_DEFAULT_VERSION = 2

local function clampPanelScalePct(value)
	local minV = GF.PANEL_SCALE_MIN_PCT or 100
	local maxV = GF.PANEL_SCALE_MAX_PCT or 150
	local def = GF.PANEL_SCALE_DEFAULT_PCT or 100
	value = math.floor((tonumber(value) or def) + 0.5)
	return math.max(minV, math.min(maxV, value))
end

GF.ClampPanelScalePct = clampPanelScalePct

local function clampFontScalePct(value)
	local minV = GF.FONT_SCALE_MIN_PCT or 100
	local maxV = GF.FONT_SCALE_MAX_PCT or 150
	local def = GF.FONT_SCALE_DEFAULT_PCT or 100
	value = math.floor((tonumber(value) or def) + 0.5)
	return math.max(minV, math.min(maxV, value))
end

GF.ClampFontScalePct = clampFontScalePct

local function clampListBackgroundAlphaPct(value)
	local minV = GF.LIST_BACKGROUND_ALPHA_MIN_PCT or 30
	local maxV = GF.LIST_BACKGROUND_ALPHA_MAX_PCT or 100
	local def = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100
	value = math.floor((tonumber(value) or def) + 0.5)
	return math.max(minV, math.min(maxV, value))
end

GF.ClampListBackgroundAlphaPct = clampListBackgroundAlphaPct

local function clampColorComponent(value, fallback)
	value = tonumber(value)
	if value == nil then
		return fallback or 0
	end
	return math.max(0, math.min(1, value))
end

local function getListBackgroundStyleDefaults(styleKey)
	local defaults = GF.LIST_BACKGROUND_STYLE_DEFAULTS or {}
	styleKey = styleKey or "normal"
	return defaults[styleKey] or defaults.normal or { r = 1, g = 1, b = 1, alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100 }
end

local function normalizeListBackgroundStyleKey(styleKey)
	styleKey = tostring(styleKey or "normal")
	local stateMap = GF.LIST_BACKGROUND_STATE_TO_STYLE or {}
	styleKey = stateMap[styleKey] or styleKey
	local defaults = GF.LIST_BACKGROUND_STYLE_DEFAULTS or {}
	if defaults[styleKey] then
		return styleKey
	end
	return "normal"
end

local function normalizeListBackgroundStyle(styleKey, style, fallbackAlphaPct)
	styleKey = normalizeListBackgroundStyleKey(styleKey)
	local defaults = getListBackgroundStyleDefaults(styleKey)
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
		alphaPct = clampListBackgroundAlphaPct(alphaPct or defaults.alphaPct),
	}
end

local function normalizeListBackgroundStyles(db)
	if type(db) ~= "table" then
		return nil
	end
	local hadStyles = type(db.listBackgroundStyles) == "table"
	if not hadStyles then
		db.listBackgroundStyles = {}
	end
	local legacyAlphaPct = clampListBackgroundAlphaPct(db.listBackgroundAlphaPct)
	for _, styleKey in ipairs(GF.LIST_BACKGROUND_STYLE_ORDER or { "normal", "friend", "application", "warning", "disabled" }) do
		local fallbackAlphaPct = nil
		if not hadStyles or styleKey == "normal" then
			fallbackAlphaPct = legacyAlphaPct
		end
		db.listBackgroundStyles[styleKey] = normalizeListBackgroundStyle(styleKey, db.listBackgroundStyles[styleKey], fallbackAlphaPct)
	end
	db.listBackgroundAlphaPct = db.listBackgroundStyles.normal.alphaPct
	return db.listBackgroundStyles
end

local function getCurrentAverageItemLevelFloor()
	if not GetAverageItemLevel then
		return nil
	end
	local ok, averageItemLevel = pcall(GetAverageItemLevel)
	averageItemLevel = ok and tonumber(averageItemLevel) or nil
	if not averageItemLevel or averageItemLevel <= 0 then
		return nil
	end
	return math.floor(averageItemLevel)
end

GF.GetCurrentAverageItemLevelFloor = getCurrentAverageItemLevelFloor

local function clampDefaultRequiredItemLevel(value)
	local minV = GF.DEFAULT_REQUIRED_ITEM_LEVEL_MIN or 0
	local def = GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0
	value = math.floor(tonumber(value) or def)
	value = math.max(minV, value)

	local maxV = getCurrentAverageItemLevelFloor()
	if maxV and maxV >= minV then
		value = math.min(value, maxV)
	end
	return value
end

GF.ClampDefaultRequiredItemLevel = clampDefaultRequiredItemLevel

function GF.NormalizeMemberDisplayMode(mode)
	if mode == (GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large") then
		return GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large"
	end
	if mode == (GF.MEMBER_DISPLAY_MODE_SPEC or "spec") then
		return GF.MEMBER_DISPLAY_MODE_SPEC or "spec"
	end
	return GF.MEMBER_DISPLAY_MODE_ROLE or "role"
end

function GF.IsMemberDisplaySpecMode(mode)
	if mode == nil and GF.GetMemberDisplayMode then
		mode = GF.GetMemberDisplayMode()
	end
	local normalized = GF.NormalizeMemberDisplayMode(mode)
	return normalized == (GF.MEMBER_DISPLAY_MODE_SPEC or "spec")
		or normalized == (GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large")
end

function GF.IsMemberDisplaySpecLargeMode(mode)
	if mode == nil and GF.GetMemberDisplayMode then
		mode = GF.GetMemberDisplayMode()
	end
	return GF.NormalizeMemberDisplayMode(mode) == (GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large")
end

function GF.NormalizeMemberTooltipMode(mode)
	if mode == (GF.MEMBER_TOOLTIP_MODE_DETAILS or "details") then
		return GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
	end
	if mode == (GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count") then
		return GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count"
	end
	return GF.MEMBER_TOOLTIP_MODE_DEFAULT or GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
end

local applicantAlertSoundSet

function GF.GetApplicantAlertSoundOptions()
	return GF.APPLICANT_ALERT_SOUND_OPTIONS or {}
end

function GF.NormalizeApplicantAlertSoundFile(file)
	if not applicantAlertSoundSet then
		applicantAlertSoundSet = {}
		for _, option in ipairs(GF.GetApplicantAlertSoundOptions()) do
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

function GF.GetApplicantAlertSoundFile()
	local db = GF.GetDB and GF.GetDB()
	return GF.NormalizeApplicantAlertSoundFile(db and db.applicantAlertSoundFile)
end

function GF.SetApplicantAlertSoundFile(file)
	local db = GF.GetDB and GF.GetDB()
	if db then
		db.applicantAlertSoundFile = GF.NormalizeApplicantAlertSoundFile(file)
	end
end

function GF.GetApplicantAlertSoundPath(file)
	file = GF.NormalizeApplicantAlertSoundFile(file)
	if file == "" then
		return nil
	end
	return GF.ADDON_SOUNDS_PATH .. file
end

local function assignSameValue(target, keys, value)
	for index = 1, #keys do
		target[keys[index]] = value
	end
	return target
end

local function makeClientFilterDefaults()
	local defaults = {
		roleFilterMode = "all",
		minOpenSlots = 1,
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
	}, false)
	return defaults
end

GF.clientFilterDefaults = makeClientFilterDefaults()

local function makeMythicPlusDefaults()
	return {
		characters = {},
		characterSettings = {},
		seasonDungeonCache = { challengeModeIDs = {} },
		settings = {
			keystoneRotationReminderEnabled = false,
			keystoneAnnouncementEnabled = false,
			teleportAnnouncementEnabled = false,--lnui
			teleportFollowEnabled = true,
		},
	}
end

local function makeAccountDefaults()
	local defaults = {
		v = 1,
		frameW = GF.FRAME_W,
		frameH = GF.FRAME_H,
		frameFooterLayoutVersion = GF.FRAME_FOOTER_LAYOUT_VERSION or 3,
		navWidth = GF.NAV_WIDTH,
		minimapAngle = 225,
		joinAnnounceEnabled = false,--lnui
		joinAnnounceDefaultVersion = JOIN_ANNOUNCE_DEFAULT_VERSION,
		applicantAlertSoundFile = "" or GF.APPLICANT_ALERT_SOUND_DEFAULT,--lnui
		applicantAlertSoundDefaultVersion = APPLICANT_ALERT_SOUND_DEFAULT_VERSION,
		workspaceMode = GF.WORKSPACE_DEFAULT or GF.WORKSPACE_MEETING_STONE or "standard",
		memberDisplayMode = "spec_large" or GF.MEMBER_DISPLAY_MODE_DEFAULT,--lnui
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
		listWheelScrollRows = GF.LIST_WHEEL_ROWS_DEFAULT or 3,
		browseColumnPresetVersion = GF.BROWSE_COLUMN_PRESET_VERSION or 2,
		applicantColumnPresetVersion = GF.APPLICANT_COLUMN_PRESET_VERSION or 1,
		browseColumnLayout = {},
		applyMode = GF.APPLY_DBLCLICK_AUTO or "dblclick_auto",
		frameStrata = GF.FRAME_STRATA_DEFAULT or "MEDIUM",
		panelScalePct = GF.PANEL_SCALE_DEFAULT_PCT or 100,
		fontScalePct = 115 or GF.FONT_SCALE_DEFAULT_PCT,--lnui
		listBackgroundAlphaPct = 50 or GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT,--lnui
		listBackgroundStyles = GF.LIST_BACKGROUND_STYLE_DEFAULTS,
		fontKey = "GameFontNormal",
		fontOutline = "OUTLINE",--lnui
		blocklist = {},
		autoInviteMemberLimit = GF.AUTO_INVITE_MEMBER_LIMIT_DEFAULT or 40,
		history = {},
		mythicPlus = makeMythicPlusDefaults(),
	}
	assignSameValue(defaults, {
		"autoExpandFilter", "lockFloatButton", "minimapSquareOrbit",
		"rememberApplicationNote", "replaceOldestApplication", "debugModeEnabled",
		"showLeaderRealm", "sameClass", "zeroScore", "rangeAgeEn",
		"rangeIlvlEn", "rangeHonorEn", "hideVoice", "hideCrossRealm",
		"sameFactionOnly", "filterRoleMatchAll", "rangeMplusScoreEn",
		"autoInviteMemberLimitEnabled", "autoInviteEnabled",
	}, false)
	assignSameValue(defaults, {
		"preferOpen", "showFloatButton", "showMinimap", "autoAcceptInvite",
		"blacklistEnabled", "showBlacklistChatNotice",
		"playstyle1", "playstyle2", "playstyle3", "playstyle4",
		"showFriendGroups", "showGuildGroups", "showHousewarmingGroups",
	}, true)
	return defaults
end

GF.defaults = makeAccountDefaults()

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

local SETTINGS_CATEGORY_DEFAULT_KEYS = {
	appearance = {
		"showFloatButton",
		"lockFloatButton",
		"showMinimap",
		"minimapSquareOrbit",
		"preferOpen",
		"fontKey",
		"fontOutline",
		"fontScalePct",
		"frameStrata",
		"panelScalePct",
	},
	party_list = {
		"showLeaderRealm",
		"memberDisplayMode",
		"memberTooltipMode",
		"listWheelScrollRows",
	},
	notifications = {
		"applicantAlertSoundFile",
		"joinAnnounceEnabled",
	},
	find_group = {
		"autoExpandFilter",
		"autoInviteMemberLimitEnabled",
		"autoInviteMemberLimit",
		"applyMode",
		"autoAcceptInvite",
		"rememberApplicationNote",
		"replaceOldestApplication",
		"blacklistEnabled",
		"showBlacklistChatNotice",
	},
}

local SETTINGS_LIST_STYLE_KEYS = {
	"normal",
	"friend",
	"warning",
	"disabled",
}

local SETTINGS_NOTIFICATION_MYTHIC_PLUS_KEYS = {
	"keystoneRotationReminderEnabled",
	"teleportFollowEnabled",
	"teleportAnnouncementEnabled",
	"keystoneAnnouncementEnabled",
}

local function restoreDefaultValue(db, key)
	local value = GF.defaults[key]
	db[key] = type(value) == "table"
		and copyTable(value) or value
end

local function restoreVisibleListStyleDefaults(db)
	db.listBackgroundStyles =
		type(db.listBackgroundStyles) == "table"
			and db.listBackgroundStyles or {}
	local defaults = GF.defaults.listBackgroundStyles or {}
	for _, styleKey in ipairs(SETTINGS_LIST_STYLE_KEYS) do
		local style = defaults[styleKey]
			or getListBackgroundStyleDefaults(styleKey)
		db.listBackgroundStyles[styleKey] = copyTable(style)
	end
	db.listBackgroundAlphaPct =
		db.listBackgroundStyles.normal.alphaPct
end

local function restoreNotificationDefaults(db)
	db.mythicPlus = type(db.mythicPlus) == "table"
		and db.mythicPlus or {}
	local mythicPlus = db.mythicPlus
	mythicPlus.settings =
		type(mythicPlus.settings) == "table"
			and mythicPlus.settings or {}
	local defaults = GF.defaults.mythicPlus.settings
	for _, key in ipairs(
		SETTINGS_NOTIFICATION_MYTHIC_PLUS_KEYS
	) do
		mythicPlus.settings[key] = defaults[key]
	end
end

local function isLegacyFloatDefault(db)
	if type(db) ~= "table" then
		return false
	end
	local x = tonumber(db.floatX)
	local y = tonumber(db.floatY)
	return db.floatPoint == "TOP"
		and (db.floatRelPoint == nil or db.floatRelPoint == "TOP")
		and x ~= nil
		and y ~= nil
		and math.floor(x + 0.5) == 0
		and math.floor(y + 0.5) == -80
end

local function normalizeMythicPlusSettings(db)
	if type(db) ~= "table" then
		return nil
	end
	if type(db.mythicPlus) ~= "table" then
		db.mythicPlus = {}
	end
	local mythicPlus = db.mythicPlus
	if type(mythicPlus.characters) ~= "table" then
		mythicPlus.characters = {}
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
	if settings.keystoneRotationReminderEnabled == nil then
		settings.keystoneRotationReminderEnabled = false
	else
		settings.keystoneRotationReminderEnabled =
			settings.keystoneRotationReminderEnabled == true
	end
	if settings.teleportFollowEnabled == nil then
		settings.teleportFollowEnabled = true
	else
		settings.teleportFollowEnabled = settings.teleportFollowEnabled == true
	end
	if settings.teleportAnnouncementEnabled == nil then
		settings.teleportAnnouncementEnabled = true
	else
		settings.teleportAnnouncementEnabled = settings.teleportAnnouncementEnabled == true
	end
	if settings.keystoneAnnouncementEnabled == nil then
		settings.keystoneAnnouncementEnabled = false
	else
		settings.keystoneAnnouncementEnabled = settings.keystoneAnnouncementEnabled == true
	end
	settings.autoOpenOnCompletedRun = nil
	if type(mythicPlus.characterSettings) ~= "table" then
		mythicPlus.characterSettings = {}
	end
	return mythicPlus
end

local function isUsableCharacterKeyPart(value)
	if type(value) ~= "string" then
		return false
	end
	if type(issecretvalue) == "function"
		and issecretvalue(value)
	then
		return false
	end
	return value ~= ""
end

local function getCurrentCharacterSettingsKey()
	local name
	local realm
	if UnitFullName then
		local ok
		ok, name, realm = pcall(UnitFullName, "player")
		if not ok then
			name = nil
			realm = nil
		end
	end
	if not isUsableCharacterKeyPart(name) and UnitName then
		local ok
		ok, name, realm = pcall(UnitName, "player")
		if not ok then
			name = nil
			realm = nil
		end
	end
	if not isUsableCharacterKeyPart(name) then
		return nil
	end
	if not isUsableCharacterKeyPart(realm) and GetRealmName then
		local ok
		ok, realm = pcall(GetRealmName)
		if not ok then
			realm = nil
		end
	end
	if GF.NormalizeExternalFullPlayerName then
		local fullName =
			GF.NormalizeExternalFullPlayerName(name, realm)
		if isUsableCharacterKeyPart(fullName)
			and fullName:find("-", 1, true)
		then
			return fullName
		end
	end
	if isUsableCharacterKeyPart(realm) then
		return name .. "-" .. realm
	end
	return nil
end

local function getCurrentCharacterSettings(db, create)
	local key = getCurrentCharacterSettingsKey()
	if not key then
		return nil
	end
	local mythicPlus = normalizeMythicPlusSettings(db)
	local settings = mythicPlus
		and mythicPlus.characterSettings[key] or nil
	if type(settings) ~= "table" then
		if not create then
			return nil
		end
		settings = {}
		mythicPlus.characterSettings[key] = settings
	end
	return settings
end

local function migrateLegacyDefaultRequiredItemLevel(db)
	local migration = GF.LegacySettingsMigration
	if migration == nil
		or type(migration.UpgradeCharacterItemLevel) ~= "function"
	then
		return false
	end
	return migration:UpgradeCharacterItemLevel(
		db,
		getCurrentCharacterSettings,
		clampDefaultRequiredItemLevel)
end

function GF.GetMythicPlusDB()
	local db = GF.GetDB and GF.GetDB() or GF.db
	return normalizeMythicPlusSettings(db)
end

function GF.InitDB()
	if type(GroupFinderDB) ~= "table"
		and type(RallyStoneDB) == "table"
	then
		GroupFinderDB = copyTable(RallyStoneDB)
	end
	if type(GroupFinderDB) ~= "table" then
		GroupFinderDB = copyTable(GF.defaults)
	end
	local migration = GF.LegacySettingsMigration
	if migration and type(migration.UpgradeRootKeys) == "function" then
		migration:UpgradeRootKeys(GroupFinderDB)
	end
	local oldBrowseColumnPresetVersion = GroupFinderDB.browseColumnPresetVersion
	local oldApplicantColumnPresetVersion = GroupFinderDB.applicantColumnPresetVersion
	local oldFrameFooterLayoutVersion =
		tonumber(GroupFinderDB.frameFooterLayoutVersion) or 0
	local oldFrameH = tonumber(GroupFinderDB.frameH)
	local oldApplyOptionDefaultVersion = GroupFinderDB.applyOptionDefaultVersion
	local oldJoinAnnounceDefaultVersion = GroupFinderDB.joinAnnounceDefaultVersion
	local oldMemberTooltipModeDefaultVersion = GroupFinderDB.memberTooltipModeDefaultVersion
	local oldApplicantAlertSoundDefaultVersion = GroupFinderDB.applicantAlertSoundDefaultVersion
	mergeMissingValues(GroupFinderDB, GF.defaults)
	local frameFooterLayoutVersion = GF.FRAME_FOOTER_LAYOUT_VERSION or 3
	if oldFrameFooterLayoutVersion < frameFooterLayoutVersion then
		if oldFrameH then
			local migratedFrameH = oldFrameH
			if oldFrameFooterLayoutVersion < 2 then
				local frameHeightDelta
				if oldFrameFooterLayoutVersion == 1 then
					frameHeightDelta = (GF.MAIN_PANEL_INSET_BOTTOM or 36)
						- (GF.FRAME_INTERIM_PANEL_BOTTOM or 44)
				elseif math.floor(migratedFrameH + 0.5)
					== (GF.FRAME_INTERIM_DEFAULT_H or 560)
				then
					-- 兼容曾在开发版中短暂使用的 560/44px 几何。
					migratedFrameH =
						GF.FRAME_PREVIOUS_DEFAULT_H or 552
				else
					frameHeightDelta = (GF.MAIN_PANEL_INSET_BOTTOM or 36)
						- (GF.FRAME_LEGACY_PANEL_BOTTOM or 24)
				end
				if frameHeightDelta then
					migratedFrameH =
						migratedFrameH + frameHeightDelta
				end
			end
			if oldFrameFooterLayoutVersion < 3
				and math.floor(migratedFrameH + 0.5)
					== (GF.FRAME_PREVIOUS_DEFAULT_H or 552)
			then
				migratedFrameH = GF.FRAME_H or 550
			end
			GroupFinderDB.frameH = migratedFrameH
		end
		GroupFinderDB.frameFooterLayoutVersion = frameFooterLayoutVersion
	end
	if isLegacyFloatDefault(GroupFinderDB) then
		GroupFinderDB.floatPoint = nil
		GroupFinderDB.floatRelPoint = nil
		GroupFinderDB.floatX = nil
		GroupFinderDB.floatY = nil
	end
	if oldApplyOptionDefaultVersion ~= APPLY_OPTION_DEFAULT_VERSION then
		GroupFinderDB.applyMode = GF.APPLY_DBLCLICK_AUTO or "dblclick_auto"
		GroupFinderDB.autoAcceptInvite = true
		GroupFinderDB.applyOptionDefaultVersion = APPLY_OPTION_DEFAULT_VERSION
	end
	if oldJoinAnnounceDefaultVersion ~= JOIN_ANNOUNCE_DEFAULT_VERSION then
		GroupFinderDB.joinAnnounceEnabled = true
		GroupFinderDB.joinAnnounceDefaultVersion = JOIN_ANNOUNCE_DEFAULT_VERSION
	end
	if oldMemberTooltipModeDefaultVersion ~= MEMBER_TOOLTIP_MODE_DEFAULT_VERSION then
		GroupFinderDB.memberTooltipMode = GF.MEMBER_TOOLTIP_MODE_DEFAULT or GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
		GroupFinderDB.memberTooltipModeDefaultVersion = MEMBER_TOOLTIP_MODE_DEFAULT_VERSION
	end
	if oldApplicantAlertSoundDefaultVersion ~= APPLICANT_ALERT_SOUND_DEFAULT_VERSION then
		if GroupFinderDB.applicantAlertSoundFile == nil
			or GroupFinderDB.applicantAlertSoundFile == GF.APPLICANT_ALERT_SOUND_LEGACY_DEFAULT then
			GroupFinderDB.applicantAlertSoundFile = GF.APPLICANT_ALERT_SOUND_DEFAULT or "xalatath.mp3"
		end
		GroupFinderDB.applicantAlertSoundDefaultVersion = APPLICANT_ALERT_SOUND_DEFAULT_VERSION
	end
	if GroupFinderDB.sameClass == nil then
		GroupFinderDB.sameClass = false
	end
	if GroupFinderDB.zeroScore == nil then
		GroupFinderDB.zeroScore = false
	end
	GroupFinderDB.panelScalePct = clampPanelScalePct(GroupFinderDB.panelScalePct)
	GroupFinderDB.fontScalePct = clampFontScalePct(GroupFinderDB.fontScalePct)
	GroupFinderDB.listBackgroundAlphaPct = clampListBackgroundAlphaPct(GroupFinderDB.listBackgroundAlphaPct)
	normalizeListBackgroundStyles(GroupFinderDB)
	GroupFinderDB.memberDisplayMode = GF.NormalizeMemberDisplayMode(GroupFinderDB.memberDisplayMode)
	GroupFinderDB.memberTooltipMode = GF.NormalizeMemberTooltipMode(GroupFinderDB.memberTooltipMode)
	GroupFinderDB.applicantAlertSoundFile = GF.NormalizeApplicantAlertSoundFile(GroupFinderDB.applicantAlertSoundFile)
	normalizeMythicPlusSettings(GroupFinderDB)
	migrateLegacyDefaultRequiredItemLevel(GroupFinderDB)
	if GroupFinderDB.showFriendGroups == nil then
		GroupFinderDB.showFriendGroups = true
	end
	if GroupFinderDB.showGuildGroups == nil then
		GroupFinderDB.showGuildGroups = true
	end
	if GroupFinderDB.showHousewarmingGroups == nil then
		GroupFinderDB.showHousewarmingGroups = true
	end
	if GroupFinderDB.filterRoleMatchAll == nil then
		GroupFinderDB.filterRoleMatchAll = false
	end
	if type(GroupFinderDB.filterClientByCategory) ~= "table" then
		GroupFinderDB.filterClientByCategory = {}
	end
	if type(GroupFinderDB.filterGlobalByBucket) ~= "table" then
		GroupFinderDB.filterGlobalByBucket = {}
	end
	if type(GroupFinderDB.filterClientBucketMigrated) ~= "table" then
		GroupFinderDB.filterClientBucketMigrated = {}
	end
	if type(GroupFinderDB.history) ~= "table" then
		GroupFinderDB.history = {}
	end
	if type(GroupFinderDB.blocklist) ~= "table" then
		GroupFinderDB.blocklist = {}
	end
	local browseColumnPresetVersion = GF.BROWSE_COLUMN_PRESET_VERSION or 2
	if oldBrowseColumnPresetVersion ~= browseColumnPresetVersion then
		local frameW = tonumber(GroupFinderDB.frameW)
		local legacyFrameW = GF.FRAME_W_LEGACY_DEFAULT or 1024
		if not frameW or math.floor(frameW + 0.5) == legacyFrameW then
			GroupFinderDB.frameW = GF.FRAME_W
		end
		GroupFinderDB.browseColumnOrder = nil
		GroupFinderDB.browseColumnVisible = nil
		GroupFinderDB.browseColumnLayout = {}
		GroupFinderDB.browseSort = { column = "title", asc = true }
		GroupFinderDB.browseColumnPresetVersion = browseColumnPresetVersion
	end
	local applicantColumnPresetVersion = GF.APPLICANT_COLUMN_PRESET_VERSION or 1
	if oldApplicantColumnPresetVersion ~= applicantColumnPresetVersion then
		GroupFinderDB.applicantColumnOrder = nil
		GroupFinderDB.applicantColumnVisible = nil
		if type(GroupFinderDB.browseColumnLayout) == "table" then
			GroupFinderDB.browseColumnLayout.applicant = nil
		end
		GroupFinderDB.applicantColumnPresetVersion = applicantColumnPresetVersion
	end
	GF.db = GroupFinderDB
	return GroupFinderDB
end

function GF.ResetSettingsCategory(categoryID)
	local keys = SETTINGS_CATEGORY_DEFAULT_KEYS[categoryID]
	local db = GF.GetDB()
	if not keys then
		return db, false
	end
	for _, key in ipairs(keys) do
		restoreDefaultValue(db, key)
	end
	if categoryID == "party_list" then
		restoreVisibleListStyleDefaults(db)
	elseif categoryID == "notifications" then
		restoreNotificationDefaults(db)
	elseif categoryID == "find_group"
		and GF.SetDefaultRequiredItemLevel
	then
		GF.SetDefaultRequiredItemLevel(
			GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0)
	end
	return db, true
end

function GF.ResetAllSettings()
	local db = GF.GetDB()
	local savedBlocklist = type(db.blocklist) == "table"
		and db.blocklist or nil
	for key in next, db do
		db[key] = nil
	end
	local restored = copyTable(GF.defaults)
	for key, value in next, restored do
		db[key] = value
	end
	if savedBlocklist ~= nil then
		db.blocklist = savedBlocklist
	end
	normalizeListBackgroundStyles(db)
	normalizeMythicPlusSettings(db)
	return db
end

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) == "function" then
		return method(owner, ...)
	end
end

function GF.ApplyAllSettings()
	local mainFrame = GF.MainFrame
	if mainFrame and mainFrame.frame then
		GF.ApplyFrameLayout(mainFrame.frame)
		invoke(mainFrame, "ApplyFrameResize")
	end
	if GF.ApplyPanelScale then
		GF.ApplyPanelScale()
	end
	if GF.ApplyFrameStrata then
		GF.ApplyFrameStrata()
	end

	local simpleRefreshes = {
		{ GF.Hook, "Refresh" },
		{ GF.MinimapButton, "Apply" },
		{ GF.FloatButton, "Apply" },
		{ GF.Font, "RefreshAll" },
		{ GF.ListColumns, "InvalidateCache" },
		{ GF.Filter, "ApplyPersistedAdvancedFilter" },
		{ GF.BlocklistPanel, "ApplyModuleVisibility" },
	}
	for index = 1, #simpleRefreshes do
		local request = simpleRefreshes[index]
		invoke(request[1], request[2])
	end
	if type(GF.ValidateLSMFontKeyAfterLogin) == "function" then
		GF.ValidateLSMFontKeyAfterLogin()
	end
	local applyBackground = GF.ApplyListBackgroundStyles
		or GF.ApplyListBackgroundAlpha
	if applyBackground then
		applyBackground()
	end

	local browse = GF.FindGroupTab
	if browse then
		local refresh = browse.ApplyClientFilters
			or browse.RefreshResults
			or browse.RefreshLoadedMemberIcons
		if refresh then
			refresh(browse)
		end
	end
	invoke(GF.ApplicantsPanel, "UpdateInviteState")
	invoke(GF.CreatePanel, "ApplyDefaultRequiredItemLevel", false)
	invoke(GF.FilterPanel, "RebuildIfNeeded", true)
	invoke(GF.MythicPlusWorkspace, "QueueRefreshCurrent", "settings")
	invoke(GF.MythicPlusTeleportFollowService, "RefreshPeerWatcher", "settings")
end

function GF.GetDB()
	return GF.db or GF.InitDB()
end

function GF.GetMemberDisplayMode()
	local db = GF.GetDB()
	return GF.NormalizeMemberDisplayMode(db and db.memberDisplayMode)
end

function GF.SetMemberDisplayMode(mode)
	local db = GF.GetDB()
	local normalized = GF.NormalizeMemberDisplayMode(mode)
	db.memberDisplayMode = normalized
	return normalized
end

function GF.GetMemberTooltipMode()
	local db = GF.GetDB()
	return GF.NormalizeMemberTooltipMode(db and db.memberTooltipMode)
end

function GF.SetMemberTooltipMode(mode)
	local db = GF.GetDB()
	local normalized = GF.NormalizeMemberTooltipMode(mode)
	db.memberTooltipMode = normalized
	return normalized
end

function GF.GetPanelScalePct()
	local db = GF.GetDB()
	return clampPanelScalePct(db and db.panelScalePct)
end

function GF.SetPanelScalePct(value)
	local db = GF.GetDB()
	db.panelScalePct = clampPanelScalePct(value)
	return db.panelScalePct
end

function GF.GetPanelScale()
	return (GF.GetPanelScalePct() or (GF.PANEL_SCALE_DEFAULT_PCT or 100)) / 100
end

function GF.GetFontScalePct()
	local db = GF.GetDB()
	return clampFontScalePct(db and db.fontScalePct)
end

function GF.SetFontScalePct(value)
	local db = GF.GetDB()
	db.fontScalePct = clampFontScalePct(value)
	return db.fontScalePct
end

function GF.GetFontScale()
	return (GF.GetFontScalePct() or (GF.FONT_SCALE_DEFAULT_PCT or 100)) / 100
end

function GF.GetListBackgroundStyle(styleKey)
	local db = GF.GetDB()
	styleKey = normalizeListBackgroundStyleKey(styleKey)
	local styles = normalizeListBackgroundStyles(db)
	if styles and styles[styleKey] then
		return styles[styleKey]
	end
	return normalizeListBackgroundStyle(styleKey)
end

function GF.SetListBackgroundStyle(styleKey, style)
	local db = GF.GetDB()
	styleKey = normalizeListBackgroundStyleKey(styleKey)
	local styles = normalizeListBackgroundStyles(db)
	local current = styles and styles[styleKey] or normalizeListBackgroundStyle(styleKey)
	style = type(style) == "table" and style or {}
	local alphaPct = style.alphaPct
	if alphaPct == nil then
		alphaPct = style.aPct
	end
	local nextStyle = normalizeListBackgroundStyle(styleKey, {
		r = style.r ~= nil and style.r or current.r,
		g = style.g ~= nil and style.g or current.g,
		b = style.b ~= nil and style.b or current.b,
		alphaPct = alphaPct ~= nil and alphaPct or current.alphaPct,
	})
	if styles then
		styles[styleKey] = nextStyle
	end
	if styleKey == "normal" then
		db.listBackgroundAlphaPct = nextStyle.alphaPct
	end
	return nextStyle
end

function GF.SetListBackgroundStyleAlphaPct(styleKey, value)
	return GF.SetListBackgroundStyle(styleKey, { alphaPct = value })
end

function GF.GetListBackgroundAlphaPct(styleKey)
	local style = GF.GetListBackgroundStyle(styleKey or "normal")
	return clampListBackgroundAlphaPct(style and style.alphaPct)
end

function GF.GetListBackgroundColor(styleKey)
	local style = GF.GetListBackgroundStyle(styleKey)
	return { style.r or 1, style.g or 1, style.b or 1, 1 }
end

function GF.GetListBackgroundAlpha(styleKey)
	local baseAlpha = tonumber(GF.BROWSE_ROW_BACKGROUND_ALPHA) or 1
	return baseAlpha * ((GF.GetListBackgroundAlphaPct(styleKey) or (GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100)) / 100)
end

local function getListBackgroundOverlayAlpha(styleKey, usage)
	if usage == "hover" then
		if styleKey == "warning" or styleKey == "disabled" then
			return 0.18
		end
		if styleKey == "friend" then
			return 0.16
		end
		return 0.13
	end
	if styleKey == "warning" then
		return 0.86
	end
	if styleKey == "disabled" then
		return 0.68
	end
	if styleKey == "friend" then
		return 0.78
	end
	return 0.82
end

local function lightenColorComponent(value, amount)
	value = clampColorComponent(value, 1)
	amount = tonumber(amount) or 0
	return clampColorComponent(value + ((1 - value) * amount), value)
end

local function isDefaultListBackgroundColor(styleKey, style)
	local defaults = getListBackgroundStyleDefaults(styleKey)
	if not (style and defaults) then
		return false
	end
	return math.abs((style.r or 0) - (defaults.r or 0)) < 0.001
		and math.abs((style.g or 0) - (defaults.g or 0)) < 0.001
		and math.abs((style.b or 0) - (defaults.b or 0)) < 0.001
end

function GF.GetListBackgroundOverlayColor(styleKey, usage)
	styleKey = normalizeListBackgroundStyleKey(styleKey)
	usage = usage == "hover" and "hover" or "selected"
	local style = GF.GetListBackgroundStyle(styleKey)
	if styleKey == "normal" and isDefaultListBackgroundColor(styleKey, style) then
		if usage == "hover" then
			return GF.BROWSE_ROW_HOVER_COLOR or { 1, 0.74, 0.18, 0.13 }
		end
		return GF.BROWSE_ROW_SELECTED_COLOR
			or { 1, 0.9, 0.08, 0.82 }
	end
	if styleKey == "application" and isDefaultListBackgroundColor(styleKey, style) then
		if usage == "hover" then
			return GF.BROWSE_ROW_HOVER_COLOR or { 1, 0.74, 0.18, 0.13 }
		end
		return GF.BROWSE_ROW_SELECTED_COLOR
			or { 1, 0.9, 0.08, 0.82 }
	end
	local amount = usage == "hover" and 0.06 or 0.14
	return {
		lightenColorComponent(style.r, amount),
		lightenColorComponent(style.g, amount),
		lightenColorComponent(style.b, amount),
		getListBackgroundOverlayAlpha(styleKey, usage),
	}
end

function GF.ApplyListBackgroundStyles()
	if GF.FindGroupTab and GF.FindGroupTab.RelayoutRows then
		GF.FindGroupTab:RelayoutRows()
	end
	if GF.ApplicantsPanel and GF.ApplicantsPanel.RelayoutRows then
		GF.ApplicantsPanel:RelayoutRows()
	end
	if GF.BlocklistPanel and GF.BlocklistPanel.RefreshList then
		GF.BlocklistPanel:RefreshList()
	end
	if GF.MythicPlusWorkspace and GF.MythicPlusWorkspace.QueueRefreshCurrent then
		GF.MythicPlusWorkspace:QueueRefreshCurrent("list-background-style")
	end
end

function GF.ApplyListBackgroundAlpha()
	return GF.ApplyListBackgroundStyles()
end

function GF.GetDefaultRequiredItemLevel()
	local db = GF.GetDB()
	migrateLegacyDefaultRequiredItemLevel(db)
	local settings = getCurrentCharacterSettings(db, false)
	local value = clampDefaultRequiredItemLevel(
		settings and settings.defaultRequiredItemLevel)
	if settings then
		settings.defaultRequiredItemLevel = value
	end
	return value
end

function GF.SetDefaultRequiredItemLevel(value)
	local db = GF.GetDB()
	migrateLegacyDefaultRequiredItemLevel(db)
	local normalized = clampDefaultRequiredItemLevel(value)
	local settings = getCurrentCharacterSettings(db, true)
	if settings then
		settings.defaultRequiredItemLevel = normalized
	end
	return normalized
end

local PANEL_SCALE_EPSILON = 0.0001
local pendingPanelScale
local panelScaleEventFrame
local panelScaleEventRegistered = false

local function panelScalesMatch(a, b)
	a = tonumber(a)
	b = tonumber(b)
	return a ~= nil and b ~= nil and math.abs(a - b) <= PANEL_SCALE_EPSILON
end

local function isProtectedFrameInCombat(frame)
	if not frame or not frame.IsProtected
		or not InCombatLockdown or not InCombatLockdown() then
		return false
	end
	return frame:IsProtected() and true or false
end

function GF.TryApplyPanelScaleToFrame(frame, scale)
	if not (frame and frame.SetScale) then
		return true
	end
	scale = tonumber(scale) or GF.GetPanelScale()
	local currentScale = frame.GetScale and frame:GetScale()
	if panelScalesMatch(currentScale, scale) then
		return true
	end
	if isProtectedFrameInCombat(frame) then
		return false
	end
	frame:SetScale(scale)
	return true
end

local function ensurePanelScaleEvent()
	if not panelScaleEventFrame then
		panelScaleEventFrame = CreateFrame("Frame")
		panelScaleEventFrame:SetScript("OnEvent", function(self, event)
			if event ~= "PLAYER_REGEN_ENABLED" then
				return
			end
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			panelScaleEventRegistered = false
			local scale = pendingPanelScale
			pendingPanelScale = nil
			if scale ~= nil and GF.ApplyPanelScale then
				GF.ApplyPanelScale(scale)
			end
		end)
	end
	if not panelScaleEventRegistered then
		panelScaleEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		panelScaleEventRegistered = true
	end
end

local function queuePanelScale(scale)
	pendingPanelScale = scale
	ensurePanelScaleEvent()
end

local function clearPendingPanelScale()
	pendingPanelScale = nil
	if panelScaleEventFrame and panelScaleEventRegistered then
		panelScaleEventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
		panelScaleEventRegistered = false
	end
end

function GF.ApplyPanelScale(requestedScale)
	local scale = tonumber(requestedScale) or GF.GetPanelScale()
	local targets = {}
	local seen = {}
	local function addTarget(frame)
		if frame and frame.SetScale and not seen[frame] then
			seen[frame] = true
			targets[#targets + 1] = frame
		end
	end
	addTarget(_G.GroupFinderAddonFrame)
	if GF.MainFrame and GF.MainFrame.frame then
		addTarget(GF.MainFrame.frame)
	end

	local appliedAll = true
	for i = 1, #targets do
		local frame = targets[i]
		if not GF.TryApplyPanelScaleToFrame(frame, scale) then
			appliedAll = false
		end
	end

	if GF.UI and GF.UI.ApplySatelliteFrameScale then
		local satellitesApplied = GF.UI.ApplySatelliteFrameScale(scale)
		if satellitesApplied == false then
			appliedAll = false
		end
	end
	if not appliedAll then
		queuePanelScale(scale)
		return false
	end
	clearPendingPanelScale()
	return true
end

function GF.ClampNavWidth(w)
	local lower = GF.NAV_WIDTH_MIN or 100
	local upper = GF.NAV_WIDTH_MAX or 220
	local candidate = tonumber(w) or GF.NAV_WIDTH or 180
	return math.min(upper, math.max(lower, candidate))
end

local function accessNavigationWidth(proposed, persist)
	local db = GF.GetDB()
	local width = GF.ClampNavWidth(persist and proposed or db.navWidth)
	if persist then
		db.navWidth = width
	end
	return width
end

function GF.GetNavWidth()
	return accessNavigationWidth(nil, false)
end

function GF.SaveNavWidth(w)
	return accessNavigationWidth(w, true)
end

function GF.GetNavContentWidth(frameW, navW)
	local outerWidth = frameW or GF.FRAME_W or 900
	local navigationWidth = navW or GF.GetNavWidth()
	local horizontalInsets = (GF.FRAME_PAD or 4) * 2
		+ (GF.CONTENT_NAV_OFFSET_X or 0)
	return math.max(100, outerWidth - navigationWidth - horizontalInsets)
end

local function normalizeFrameSize(width, height)
	local minimumWidth = GF.FRAME_MIN_W or GF.FRAME_W or 780
	local minimumHeight = GF.FRAME_MIN_H or GF.FRAME_H or 380
	width = tonumber(width) or GF.FRAME_W or minimumWidth
	height = tonumber(height) or GF.FRAME_H or minimumHeight
	return math.max(minimumWidth, width), math.max(minimumHeight, height)
end

function GF.SaveFrameLayout(frame)
	if not frame then
		return
	end
	local point, _, relativePoint, offsetX, offsetY = frame:GetPoint(1)
	local db = GF.GetDB()
	if type(point) == "string" then
		db.framePoint, db.frameRelPoint = point, relativePoint
		db.frameX, db.frameY = offsetX, offsetY
	end
	db.frameW, db.frameH = normalizeFrameSize(frame:GetWidth(), frame:GetHeight())
end

function GF.ApplyFrameLayout(frame)
	if not frame then
		return
	end
	local db = GF.GetDB()
	local width, height = normalizeFrameSize(db.frameW, db.frameH)
	db.frameW, db.frameH = width, height
	frame:SetSize(width, height)
	frame:SetClampRectInsets(0, 0, 0, 40)
	frame:ClearAllPoints()
	if db.frameX and db.frameY and db.framePoint then
		local relativePoint = db.frameRelPoint or db.framePoint
		frame:SetPoint(db.framePoint, UIParent, relativePoint, db.frameX, db.frameY)
	else
		frame:SetPoint("CENTER")
	end
end

function GF.IsValidFrameStrata(str)
	if type(str) ~= "string" then
		return false
	end
	local choices = GF.FRAME_STRATA_CHOICES or {}
	for index = 1, #choices do
		if choices[index] == str then
			return true
		end
	end
	return false
end

function GF.GetFrameStrata()
	local db = GF.GetDB()
	local saved = db and db.frameStrata
	if GF.IsValidFrameStrata(saved) then
		return saved
	end
	return GF.FRAME_STRATA_DEFAULT or "MEDIUM"
end

function GF.ApplyFrameStrata(strata)
	local resolved = GF.IsValidFrameStrata(strata) and strata or GF.GetFrameStrata()
	local targets = {}
	local function include(frame)
		if frame then
			targets[#targets + 1] = frame
		end
	end
	include(_G.GroupFinderAddonFrame)
	include(GF.MainFrame and GF.MainFrame.frame)
	include(GF.FilterPanel and GF.FilterPanel.frame)
	include(_G.GroupFinderAddonFloatButton)
	include(GF.FloatButton and GF.FloatButton.dropdown)
	include(GF.RowContextMenu and GF.RowContextMenu.dropdown)
	-- Minimap launchers can be reparented by LibDBIcon collectors such as
	-- HidingBar. Their host must remain the authority for frame strata.
	for index = 1, #targets do
		local frame = targets[index]
		if frame and type(frame.SetFrameStrata) == "function" then
			frame:SetFrameStrata(resolved)
		end
	end
	if GF.UI and GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers(resolved)
	end
end
