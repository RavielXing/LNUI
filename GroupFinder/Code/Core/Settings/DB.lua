local _, GF = ...

local APPLY_OPTION_DEFAULT_VERSION = 1
local JOIN_ANNOUNCE_DEFAULT_VERSION = 1
local MEMBER_TOOLTIP_MODE_DEFAULT_VERSION = 1
local APPLICANT_ALERT_SOUND_DEFAULT_VERSION = 2
local REMOVED_SETTING_KEYS = {
	listMemberStyle = true,
	showSpecIcons = true,
	showClassColorBar = true,
	showRoleBadge = true,
	showLeaderCrown = true,
	bodyBgStyle = true,
	bodyBgTexAlpha = true,
	bodyBgCustomEnabled = true,
	bodyBgR = true,
	bodyBgG = true,
	bodyBgB = true,
	bodyBgA = true,
	bodyBgHex = true,
	fontSize = true,
	delistedAction = true,
	defaultRequiredItemLevelOffset = true,
}

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
	if mode == (GF.MEMBER_DISPLAY_MODE_SPEC or "spec") then
		return GF.MEMBER_DISPLAY_MODE_SPEC or "spec"
	end
	return GF.MEMBER_DISPLAY_MODE_ROLE or "role"
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
	return (GF.ADDON_SOUNDS_PATH or "Interface\\AddOns\\GroupFinder\\Sounds\\") .. file
end

GF.clientFilterDefaults = {
	rangeTankEn = false,
	rangeTankMin = 0,
	rangeTankMax = 0,
	rangeHealEn = false,
	rangeHealMin = 0,
	rangeHealMax = 0,
	rangeDpsEn = false,
	rangeDpsMin = 0,
	rangeDpsMax = 0,
	matchMyRole = false,
	notDeclined = false,
	bloodlustMode = 0,
	hasTank = false,
	hasHeal = false,
	alreadyHasTank = false,
	alreadyHasHeal = false,
	needsMyClass = false,
	warmodeOnly = false,
	dungeonDiffEn = false,
	dungeonDifficultyNormal = false,
	dungeonDifficultyHeroic = false,
	dungeonDifficultyMythic = false,
	dungeonDifficultyMythicPlus = false,
	raidDiffEn = false,
	raidDifficultyNormal = false,
	raidDifficultyHeroic = false,
	raidDifficultyMythic = false,
	raidMemberCountEn = false,
	raidMemberCount = 0,
	raidMemberCountMin = 0,
	raidMemberCountMax = 0,
	raidBossKillsEn = false,
	raidBossKills = 0,
	raidBossKillsMin = 0,
	raidBossKillsMax = 0,
}

GF.defaults = {
	v = 1,
	frameW = GF.FRAME_W,
	frameH = GF.FRAME_H,
	navWidth = GF.NAV_WIDTH,
	frameX = nil,
	frameY = nil,
	preferOpen = true,
	autoExpandFilter = false,
	showFloatButton = true,
	lockFloatButton = false,
	showMinimap = true,
	minimapAngle = 225,
	minimapSquareOrbit = false,
	persistApplyNote = false,
	autoAcceptInvite = true,
	joinAnnounceEnabled = false,--lnui
	joinAnnounceDefaultVersion = JOIN_ANNOUNCE_DEFAULT_VERSION,
	applicantAlertSoundFile = "" or GF.APPLICANT_ALERT_SOUND_DEFAULT,--lnui
	applicantAlertSoundDefaultVersion = APPLICANT_ALERT_SOUND_DEFAULT_VERSION,
	defaultRequiredItemLevel = GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0,
	cancelOldestApply = false,
	debugModeEnabled = false,
	showLeaderRealm = false,
	memberDisplayMode = "spec" or GF.MEMBER_DISPLAY_MODE_DEFAULT,--lnui
	memberTooltipMode = "spec_count" or GF.MEMBER_TOOLTIP_MODE_DEFAULT,--lnui
	memberTooltipModeDefaultVersion = MEMBER_TOOLTIP_MODE_DEFAULT_VERSION,
	browseSort = { column = "title", asc = true },
	moduleBlocklist = true,
	moduleListFilter = true,
	blockTipsEnabled = true,
	titleContagionEnabled = true,
	sameClass = false,
	zeroScore = false,
	playstyle1 = true,
	playstyle2 = true,
	playstyle3 = true,
	playstyle4 = true,
	maxAgeMin = 0,
	minIlvl = 0,
	rangeAgeEn = false,
	rangeAgeMin = 0,
	rangeAgeMax = 0,
	rangeIlvlEn = false,
	rangeIlvlMin = 0,
	rangeIlvlMax = 0,
	rangeHonorEn = false,
	rangeHonorMin = 0,
	rangeHonorMax = 0,
	hideVoice = false,
	hideCrossRealm = false,
	sameFactionOnly = false,
	showFriendGroups = true,
	showGuildGroups = true,
	showHousewarmingGroups = true,
	filterRoleMatchAll = false,
	rangeMplusScoreEn = false,
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
	fontScalePct = 125 or GF.FONT_SCALE_DEFAULT_PCT,--lnui
	listBackgroundAlphaPct = 50 or GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT,--lnui
	fontKey = "GameFontNormal",
	fontOutline = "NONE",
	blocklist = {},
	inviteCapEnabled = false,
	inviteCap = GF.INVITE_CAP_DEFAULT or 40,
	history = {},
	autoInviteEnabled = false,
	autoInviteEntrySig = nil,
}

local function copyTable(src)
	local dst = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = copyTable(v)
		else
			dst[k] = v
		end
	end
	return dst
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

function GF.InitDB()
	if not GroupFinderDB and RallyStoneDB then
		GroupFinderDB = copyTable(RallyStoneDB)
	end
	if not GroupFinderDB then
		GroupFinderDB = copyTable(GF.defaults)
	end
	local oldBrowseColumnPresetVersion = GroupFinderDB.browseColumnPresetVersion
	local oldApplicantColumnPresetVersion = GroupFinderDB.applicantColumnPresetVersion
	local oldApplyOptionDefaultVersion = GroupFinderDB.applyOptionDefaultVersion
	local oldJoinAnnounceDefaultVersion = GroupFinderDB.joinAnnounceDefaultVersion
	local oldMemberTooltipModeDefaultVersion = GroupFinderDB.memberTooltipModeDefaultVersion
	local oldApplicantAlertSoundDefaultVersion = GroupFinderDB.applicantAlertSoundDefaultVersion
	for k, v in pairs(GF.defaults) do
		if GroupFinderDB[k] == nil then
			if type(v) == "table" then
				GroupFinderDB[k] = copyTable(v)
			else
				GroupFinderDB[k] = v
			end
		end
	end
	for k in pairs(REMOVED_SETTING_KEYS) do
		GroupFinderDB[k] = nil
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
			or GroupFinderDB.applicantAlertSoundFile == (GF.APPLICANT_ALERT_SOUND_LEGACY_DEFAULT or "Glass.aiff") then
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
	GroupFinderDB.defaultRequiredItemLevel = clampDefaultRequiredItemLevel(GroupFinderDB.defaultRequiredItemLevel)
	GroupFinderDB.memberDisplayMode = GF.NormalizeMemberDisplayMode(GroupFinderDB.memberDisplayMode)
	GroupFinderDB.memberTooltipMode = GF.NormalizeMemberTooltipMode(GroupFinderDB.memberTooltipMode)
	GroupFinderDB.applicantAlertSoundFile = GF.NormalizeApplicantAlertSoundFile(GroupFinderDB.applicantAlertSoundFile)
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
	if GroupFinderDB.filterClientByCategory == nil then
		GroupFinderDB.filterClientByCategory = {}
	end
	if GroupFinderDB.filterGlobalByBucket == nil then
		GroupFinderDB.filterGlobalByBucket = {}
	end
	if GroupFinderDB.filterClientBucketMigrated == nil then
		GroupFinderDB.filterClientBucketMigrated = {}
	end
	if not GroupFinderDB.history then
		GroupFinderDB.history = {}
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

function GF.ResetAllSettings()
	local db = GF.GetDB()
	for k in pairs(db) do
		if k ~= "blocklist" then
			db[k] = nil
		end
	end
	for k, v in pairs(GF.defaults) do
		if k ~= "blocklist" then
			if type(v) == "table" then
				db[k] = copyTable(v)
			else
				db[k] = v
			end
		end
	end
	return db
end

function GF.ApplyAllSettings()
	if GF.MainFrame and GF.MainFrame.frame then
		GF.ApplyFrameLayout(GF.MainFrame.frame)
		if GF.MainFrame.ApplyFrameResize then
			GF.MainFrame:ApplyFrameResize()
		end
	end
	if GF.ApplyPanelScale then
		GF.ApplyPanelScale()
	end
	if GF.ApplyFrameStrata then
		GF.ApplyFrameStrata()
	end
	if GF.Hook and GF.Hook.Refresh then
		GF.Hook.Refresh()
	end
	if GF.MinimapButton and GF.MinimapButton.Apply then
		GF.MinimapButton:Apply()
	end
	if GF.FloatButton and GF.FloatButton.Apply then
		GF.FloatButton:Apply()
	end
	if GF.ValidateLSMFontKeyAfterLogin then
		GF.ValidateLSMFontKeyAfterLogin()
	end
	if GF.Font and GF.Font.RefreshAll then
		GF.Font.RefreshAll()
	end
	if GF.ApplyListBackgroundAlpha then
		GF.ApplyListBackgroundAlpha()
	end
	if GF.ListColumns and GF.ListColumns.InvalidateCache then
		GF.ListColumns:InvalidateCache()
	end
	if GF.Filter and GF.Filter.ApplyPersistedAdvancedFilter then
		GF.Filter:ApplyPersistedAdvancedFilter()
	end
	if GF.BlocklistPanel and GF.BlocklistPanel.ApplyModuleVisibility then
		GF.BlocklistPanel:ApplyModuleVisibility()
	end
	if GF.FindGroupTab then
		if GF.FindGroupTab.ApplyClientFilters then
			GF.FindGroupTab:ApplyClientFilters()
		elseif GF.FindGroupTab.RefreshResults then
			GF.FindGroupTab:RefreshResults()
		elseif GF.FindGroupTab.RefreshLoadedMemberIcons then
			GF.FindGroupTab:RefreshLoadedMemberIcons()
		end
	end
	if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateInviteState then
		GF.ApplicantsPanel:UpdateInviteState()
	end
	if GF.CreatePanel and GF.CreatePanel.ApplyDefaultRequiredItemLevel then
		GF.CreatePanel:ApplyDefaultRequiredItemLevel(false)
	end
	if GF.FilterPanel and GF.FilterPanel.RebuildIfNeeded then
		GF.FilterPanel:RebuildIfNeeded(true)
	end
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

function GF.GetListBackgroundAlphaPct()
	local db = GF.GetDB()
	return clampListBackgroundAlphaPct(db and db.listBackgroundAlphaPct)
end

function GF.SetListBackgroundAlphaPct(value)
	local db = GF.GetDB()
	db.listBackgroundAlphaPct = clampListBackgroundAlphaPct(value)
	return db.listBackgroundAlphaPct
end

function GF.GetListBackgroundAlpha()
	local baseAlpha = tonumber(GF.BROWSE_ROW_BACKGROUND_ALPHA) or 1
	return baseAlpha * ((GF.GetListBackgroundAlphaPct() or (GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100)) / 100)
end

function GF.ApplyListBackgroundAlpha()
	if GF.FindGroupTab and GF.FindGroupTab.RelayoutRows then
		GF.FindGroupTab:RelayoutRows()
	end
	if GF.ApplicantsPanel and GF.ApplicantsPanel.RelayoutRows then
		GF.ApplicantsPanel:RelayoutRows()
	end
end

function GF.GetDefaultRequiredItemLevel()
	local db = GF.GetDB()
	return clampDefaultRequiredItemLevel(db and db.defaultRequiredItemLevel)
end

function GF.SetDefaultRequiredItemLevel(value)
	local db = GF.GetDB()
	db.defaultRequiredItemLevel = clampDefaultRequiredItemLevel(value)
	return db.defaultRequiredItemLevel
end

function GF.ApplyPanelScale()
	local scale = GF.GetPanelScale()
	local function apply(frame)
		if frame and frame.SetScale then
			frame:SetScale(scale)
		end
	end
	apply(_G.GroupFinderAddonFrame)
	if GF.MainFrame and GF.MainFrame.frame then
		apply(GF.MainFrame.frame)
	end
	if GF.UI and GF.UI.ApplySatelliteFrameScale then
		GF.UI.ApplySatelliteFrameScale(scale)
	end
end

function GF.ClampNavWidth(w)
	w = tonumber(w) or GF.NAV_WIDTH or 180
	local minW = GF.NAV_WIDTH_MIN or 100
	local maxW = GF.NAV_WIDTH_MAX or 220
	if w < minW then
		return minW
	end
	if w > maxW then
		return maxW
	end
	return w
end

function GF.GetNavWidth()
	local db = GF.GetDB()
	return GF.ClampNavWidth(db and db.navWidth)
end

function GF.SaveNavWidth(w)
	local db = GF.GetDB()
	db.navWidth = GF.ClampNavWidth(w)
	return db.navWidth
end

function GF.GetNavContentWidth(frameW, navW)
	local pad = GF.FRAME_PAD or 4
	local ox = GF.CONTENT_NAV_OFFSET_X or 0
	frameW = frameW or GF.FRAME_W or 900
	navW = navW or GF.GetNavWidth()
	return math.max(frameW - pad * 2 - navW - ox, 100)
end

local function ClampFrameSize(w, h)
	local minW = GF.FRAME_MIN_W or GF.FRAME_W or 780
	local minH = GF.FRAME_MIN_H or GF.FRAME_H or 380
	local defaultW = GF.FRAME_W or minW
	local defaultH = GF.FRAME_H or minH
	return math.max(tonumber(w) or defaultW, minW), math.max(tonumber(h) or defaultH, minH)
end

function GF.SaveFrameLayout(frame)
	if not frame then
		return
	end
	local db = GF.GetDB()
	local point, _, relPoint, x, y = frame:GetPoint(1)
	if point then
		db.framePoint = point
		db.frameRelPoint = relPoint
		db.frameX = x
		db.frameY = y
	end
	db.frameW, db.frameH = ClampFrameSize(frame:GetWidth(), frame:GetHeight())
end

function GF.ApplyFrameLayout(frame)
	if not frame then
		return
	end
	local db = GF.GetDB()
	local frameW, frameH = ClampFrameSize(db.frameW, db.frameH)
	db.frameW, db.frameH = frameW, frameH
	frame:SetSize(frameW, frameH)
	frame:SetClampRectInsets(0, 0, 0, 40)
	if db.frameX and db.frameY and db.framePoint then
		frame:ClearAllPoints()
		frame:SetPoint(db.framePoint, UIParent, db.frameRelPoint or db.framePoint, db.frameX, db.frameY)
	else
		frame:ClearAllPoints()
		frame:SetPoint("CENTER")
	end
end

function GF.IsValidFrameStrata(str)
	if type(str) ~= "string" then
		return false
	end
	for _, s in ipairs(GF.FRAME_STRATA_CHOICES or {}) do
		if str == s then
			return true
		end
	end
	return false
end

function GF.GetFrameStrata()
	local db = GF.GetDB()
	local s = db and db.frameStrata
	if GF.IsValidFrameStrata(s) then
		return s
	end
	return GF.FRAME_STRATA_DEFAULT or "MEDIUM"
end

function GF.ApplyFrameStrata(strata)
	local resolved = GF.IsValidFrameStrata(strata) and strata or GF.GetFrameStrata()
	local function apply(frame)
		if frame and frame.SetFrameStrata then
			frame:SetFrameStrata(resolved)
		end
	end
	apply(_G.GroupFinderAddonFrame)
	if GF.MainFrame and GF.MainFrame.frame then
		apply(GF.MainFrame.frame)
	end
	if GF.FilterPanel and GF.FilterPanel.frame then
		apply(GF.FilterPanel.frame)
	end
	if GF.MinimapButton and GF.MinimapButton.GetButtonFrame then
		apply(GF.MinimapButton:GetButtonFrame())
	else
		apply(_G.GroupFinderAddonMinimapButton)
	end
	apply(_G.GroupFinderAddonFloatButton)
	if GF.FloatButton and GF.FloatButton.dropdown then
		apply(GF.FloatButton.dropdown)
	end
	if GF.RowContextMenu and GF.RowContextMenu.dropdown then
		apply(GF.RowContextMenu.dropdown)
	end
	if GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers(resolved)
	end
end
