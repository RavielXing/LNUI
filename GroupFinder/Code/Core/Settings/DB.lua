local _, GF = ...

local Schema = assert(GF.SettingsSchema, "SettingsSchema must load before DB")
local Repository = assert(
	GF.SettingsRepository, "SettingsRepository must load before DB")

local function clampPanelScalePct(value)
	return Schema:ClampPanelScalePct(value)
end

local function clampFloatScalePct(value)
	return Schema:ClampFloatScalePct(value)
end

local function clampFontScalePct(value)
	return Schema:ClampFontScalePct(value)
end

local function clampListBackgroundAlphaPct(value)
	return Schema:ClampListBackgroundAlphaPct(value)
end

local function clampDefaultRequiredItemLevel(value)
	return Schema:ClampDefaultRequiredItemLevel(value)
end

local function normalizeListBackgroundStyleKey(styleKey)
	return Schema:NormalizeListBackgroundStyleKey(styleKey)
end

local function normalizeListBackgroundStyle(styleKey, style, fallbackAlphaPct)
	return Schema:NormalizeListBackgroundStyle(
		styleKey, style, fallbackAlphaPct)
end

local function normalizeListBackgroundStyles(database)
	return Schema:NormalizeListBackgroundStyles(database)
end

local function getListBackgroundStyleDefaults(styleKey)
	return Schema:GetListBackgroundStyleDefaults(styleKey)
end

local function clampColorComponent(value, fallback)
	return Schema:ClampColorComponent(value, fallback)
end

GF.ClampPanelScalePct = clampPanelScalePct
GF.ClampFloatScalePct = clampFloatScalePct
GF.ClampFontScalePct = clampFontScalePct
GF.ClampListBackgroundAlphaPct = clampListBackgroundAlphaPct
GF.GetCurrentAverageItemLevelFloor = function()
	return Schema:GetCurrentAverageItemLevelFloor()
end
GF.ClampDefaultRequiredItemLevel = clampDefaultRequiredItemLevel

function GF.NormalizeMemberDisplayMode(mode)
	return Schema:NormalizeMemberDisplayMode(mode)
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
	return Schema:NormalizeMemberTooltipMode(mode)
end

function GF.NormalizeExpiredGroupMode(mode)
	return Schema:NormalizeExpiredGroupMode(mode)
end

function GF.NormalizePanelSkin(panelSkin)
	return Schema:NormalizePanelSkin(panelSkin)
end

function GF.NormalizeInterfaceLocale(interfaceLocale)
	return Schema:NormalizeInterfaceLocale(interfaceLocale)
end

function GF.GetPanelSkinOptions()
	return GF.PANEL_SKIN_OPTIONS or {}
end

function GF.GetApplicantAlertSoundOptions()
	return GF.APPLICANT_ALERT_SOUND_OPTIONS or {}
end

function GF.NormalizeApplicantAlertSoundFile(file)
	return Schema:NormalizeApplicantAlertSoundFile(file)
end

function GF.GetApplicantAlertSoundFile()
	local db = GF.GetDB and GF.GetDB()
	return GF.NormalizeApplicantAlertSoundFile(db and db.applicantAlertSoundFile)
end

local function refreshApplicantAlertSoundMode()
	local alerts = GF.ApplicantAlertService
	if alerts and type(alerts.RefreshSoundMode) == "function" then
		alerts:RefreshSoundMode()
	end
end

function GF.SetApplicantAlertSoundFile(file)
	local db = GF.GetDB and GF.GetDB()
	if db then
		db.applicantAlertSoundFile = GF.NormalizeApplicantAlertSoundFile(file)
		refreshApplicantAlertSoundMode()
	end
end

function GF.GetApplicantAlertSoundPath(file)
	file = GF.NormalizeApplicantAlertSoundFile(file)
	if file == "" or file == (GF.APPLICANT_ALERT_SOUND_NATIVE or "native") then
		return nil
	end
	return GF.ADDON_SOUNDS_PATH .. file
end

local function normalizeMythicPlusSettings(db)
	return Schema:NormalizeMythicPlus(db)
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

-- Character-scoped business data (for example Activity Favorites) must use
-- the same stable Name-Realm identity as Mythic+ character settings. Keep the
-- resolver public so those domains do not grow subtly different key formats.
function GF.GetCurrentCharacterKey()
	return getCurrentCharacterSettingsKey()
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

local repositoryContext = {
	getCurrentCharacterKey = getCurrentCharacterSettingsKey,
	migrateLegacyDefaultRequiredItemLevel =
		migrateLegacyDefaultRequiredItemLevel,
	resetDefaultRequiredItemLevel = function(value)
		if GF.SetDefaultRequiredItemLevel then
			return GF.SetDefaultRequiredItemLevel(value)
		end
	end,
}

function GF.InitDB()
	local database = Repository:Initialize(repositoryContext)
	if GF.Locale and GF.Locale.InitializeUserLocalePreference then
		GF.Locale:InitializeUserLocalePreference(database.interfaceLocale)
	elseif GF.Locale and GF.Locale.SetUserLocalePreference then
		GF.Locale:SetUserLocalePreference(database.interfaceLocale)
	end
	refreshApplicantAlertSoundMode()
	return database
end

function GF.ResetSettingsCategory(categoryID)
	local database, changed = Repository:ResetCategory(categoryID, repositoryContext)
	refreshApplicantAlertSoundMode()
	return database, changed
end

function GF.ResetAllSettings()
	local database = Repository:ResetAll(repositoryContext)
	refreshApplicantAlertSoundMode()
	return database
end

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) == "function" then
		return method(owner, ...)
	end
end

function GF.ApplyAllSettings()
	refreshApplicantAlertSoundMode()
	invoke(GF.MythicPlusCarpoolPolicy, "Refresh", "settings-all")
	if GF.Locale and GF.Locale.SetUserLocalePreference then
		local before = GF.Locale:GetCurrentLocaleKey()
		GF.Locale:SetUserLocalePreference(
			GF.GetInterfaceLocale and GF.GetInterfaceLocale() or "system")
		if before ~= GF.Locale:GetCurrentLocaleKey() then
			invoke(GF.MainFrame, "RefreshLocale")
		end
	end
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
	if GF.ApplyPanelSkin then
		GF.ApplyPanelSkin()
	end
	if GF.ApplyWorkspaceTabPosition then
		GF.ApplyWorkspaceTabPosition()
	end

	local simpleRefreshes = {
		{ GF.Hook, "Refresh" },
		{ GF.MinimapButton, "Apply" },
		{ GF.FloatButton, "Apply" },
		{ GF.Font, "RefreshAll" },
		{ GF.ListColumns, "InvalidateCache" },
		{ GF.BlocklistPanel, "ApplyModuleVisibility" },
		{ GF.NetEaseIdentityService, "OnPlayerLogin" },
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
	-- Category/all-settings reset bypasses the individual SettingsPresenter field
	-- refresh plan.  Reproject the entrance overlay here too, so restoring the
	-- F57 default takes effect immediately instead of waiting for movement or a
	-- later instance event.
	invoke(GF.InstanceGatewayService, "ApplySettings", "settings-reset")
	-- Clearing the saved anchor must also move an already-visible frame.
	-- Keep custom anchors and active drags protected by the overlay's guard.
	invoke(GF.InstanceGatewayOverlay, "RefreshDefaultPosition")
	invoke(GF.InstanceGatewayOverlay, "Apply")
end

function GF.GetDB()
	return Repository:Get(repositoryContext)
end

local function normalizeSettingsFeatureRevision(revision)
	revision = tonumber(revision)
	if type(revision) ~= "number"
		or revision ~= revision
		or revision == math.huge
		or revision == -math.huge
		or revision < 1
	then
		return nil
	end
	return math.floor(revision)
end

local function getSettingsFeatureSeenVersions(create)
	local database = GF.GetDB()
	if type(database) ~= "table" then
		return nil
	end
	local seenVersions = database.settingsFeatureSeenVersions
	if type(seenVersions) ~= "table" then
		if not create then
			return nil
		end
		seenVersions = {}
		database.settingsFeatureSeenVersions = seenVersions
	end
	return seenVersions
end

function GF.ShouldShowSettingsNewFeature(featureID, revision)
	revision = normalizeSettingsFeatureRevision(revision)
	if type(featureID) ~= "string" or featureID == "" or not revision then
		return false
	end
	local seenVersions = getSettingsFeatureSeenVersions(false)
	local seenRevision = seenVersions
		and normalizeSettingsFeatureRevision(seenVersions[featureID]) or nil
	return seenRevision == nil or seenRevision < revision
end

function GF.MarkSettingsNewFeatureSeen(featureID, revision)
	revision = normalizeSettingsFeatureRevision(revision)
	if type(featureID) ~= "string" or featureID == "" or not revision then
		return false
	end
	local seenVersions = getSettingsFeatureSeenVersions(true)
	if not seenVersions then
		return false
	end
	local seenRevision =
		normalizeSettingsFeatureRevision(seenVersions[featureID])
	if seenRevision and seenRevision >= revision then
		return false
	end
	seenVersions[featureID] = revision
	return true
end

function GF.GetTeamListColorScheme()
	local db = GF.GetDB()
	return Schema:NormalizeTeamListColorScheme(db and db.teamListColorScheme)
end

function GF.SetTeamListColorScheme(scheme)
	local db = GF.GetDB()
	local normalized = Schema:NormalizeTeamListColorScheme(scheme)
	db.teamListColorScheme = normalized
	return normalized
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

function GF.GetExpiredGroupMode()
	local db = GF.GetDB()
	return GF.NormalizeExpiredGroupMode(db and db.expiredGroupMode)
end

function GF.SetExpiredGroupMode(mode)
	local db = GF.GetDB()
	local normalized = GF.NormalizeExpiredGroupMode(mode)
	db.expiredGroupMode = normalized
	return normalized
end

function GF.ShouldRetainExpiredGroups()
	return GF.GetExpiredGroupMode()
		~= (GF.EXPIRED_GROUP_MODE_AUTO_REMOVE or "auto_remove")
end

function GF.GetPanelSkin()
	local db = GF.GetDB()
	return GF.NormalizePanelSkin(db and db.panelSkin)
end

function GF.GetWorkspaceTabPosition()
	local db = GF.GetDB()
	return Schema:NormalizeWorkspaceTabPosition(db and db.workspaceTabPosition)
end

function GF.SetWorkspaceTabPosition(position)
	local db = GF.GetDB()
	db.workspaceTabPosition = Schema:NormalizeWorkspaceTabPosition(position)
	return db.workspaceTabPosition
end

function GF.ApplyWorkspaceTabPosition()
	invoke(GF.WorkspaceBar, "RelayoutTabs")
end

function GF.GetInterfaceLocale()
	local db = GF.GetDB()
	return GF.NormalizeInterfaceLocale(db and db.interfaceLocale)
end

function GF.SetInterfaceLocale(interfaceLocale)
	local db = GF.GetDB()
	db.interfaceLocale = GF.NormalizeInterfaceLocale(interfaceLocale)
	if GF.Locale and GF.Locale.SetUserLocalePreference then
		GF.Locale:SetUserLocalePreference(db.interfaceLocale)
	end
	return db.interfaceLocale
end

function GF.SetPanelSkin(panelSkin)
	local db = GF.GetDB()
	db.panelSkin = GF.NormalizePanelSkin(panelSkin)
	return db.panelSkin
end

function GF.ApplyPanelSkin(panelSkin)
	local mainFrame = GF.MainFrame
	local frame = mainFrame and (mainFrame.frame or mainFrame)
	if not (frame and GF.UI and GF.UI.ApplyMainWindowBodySkin) then
		return false
	end
	if panelSkin == nil then
		panelSkin = GF.GetPanelSkin()
	end
	local applied, resolvedSkin =
		GF.UI.ApplyMainWindowBodySkin(frame, panelSkin)
	if GF.UI.ApplySatellitePanelSkins then
		GF.UI.ApplySatellitePanelSkins(panelSkin)
	end
	if GF.UsageGuideDialog and GF.UsageGuideDialog.RefreshTheme then
		GF.UsageGuideDialog:RefreshTheme(panelSkin)
	end
	return applied, resolvedSkin
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

function GF.GetFloatScalePct()
	local db = GF.GetDB()
	return clampFloatScalePct(db and db.floatScalePct)
end

function GF.SetFloatScalePct(value)
	local db = GF.GetDB()
	db.floatScalePct = clampFloatScalePct(value)
	return db.floatScalePct
end

function GF.GetFloatScale()
	return (GF.GetFloatScalePct() or (GF.FLOAT_SCALE_DEFAULT_PCT or 100)) / 100
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
	-- Transient row colors share list styling without entering saved settings.
	if type(styleKey) == "table" then
		return normalizeListBackgroundStyle("normal", styleKey)
	end
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
		if styleKey == "warning" or styleKey == "censored" or styleKey == "disabled" then
			return 0.18
		end
		if styleKey == "friend" then
			return 0.16
		end
		return 0.13
	end
	if styleKey == "warning" or styleKey == "censored" then
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
	local customStyle = type(styleKey) == "table"
	local style = GF.GetListBackgroundStyle(styleKey)
	styleKey = normalizeListBackgroundStyleKey(styleKey)
	usage = usage == "hover" and "hover" or "selected"
	if not customStyle and styleKey == "normal" and isDefaultListBackgroundColor(styleKey, style) then
		if usage == "hover" then
			return GF.BROWSE_ROW_HOVER_COLOR or { 1, 0.74, 0.18, 0.13 }
		end
		return GF.BROWSE_ROW_SELECTED_COLOR
			or { 1, 0.9, 0.08, 0.82 }
	end
	if not customStyle and styleKey == "application" and isDefaultListBackgroundColor(styleKey, style) then
		if usage == "hover" then
			return GF.BROWSE_ROW_HOVER_COLOR or { 1, 0.74, 0.18, 0.13 }
		end
		return GF.BROWSE_ROW_SELECTED_COLOR
			or { 1, 0.9, 0.08, 0.82 }
	end
	if not customStyle and styleKey == "newbie" and isDefaultListBackgroundColor(styleKey, style) then
		if usage == "hover" then
			return GF.BROWSE_ROW_HOVER_NEWBIE_COLOR
				or { 0.2, 1, 0.32, 0.18 }
		end
		return GF.BROWSE_ROW_SELECTED_NEWBIE_COLOR
			or { 0.18, 1, 0.3, 0.82 }
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
	if GF.RaidSeekingPanel and GF.RaidSeekingPanel.RefreshListBackgroundStyles then
		GF.RaidSeekingPanel:RefreshListBackgroundStyles()
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
	return Schema:ClampNavWidth(w)
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
	return Schema:NormalizeFrameSize(width, height)
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
	return Schema:IsValidFrameStrata(str)
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
