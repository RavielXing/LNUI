local _, GF = ...

-- SettingsPresenter is the state and decision boundary for every settings
-- surface.  Widget modules render its projections; they do not own category
-- routing, persisted values, drafts, dependency policy, or refresh effects.
local Presenter = {}
GF.SettingsPresenter = Presenter

local Repository = assert(
	GF.SettingsRepository,
	"SettingsRepository must load before SettingsPresenter"
)
local Schema = assert(
	GF.SettingsSchema,
	"SettingsSchema must load before SettingsPresenter"
)

local CATEGORY_IDS = {
	"appearance",
	"party_list",
	"notifications",
	"tactical",
	"find_group",
	"netease_newbie",
}

local CATEGORY_SPECS = {
	appearance = {
		titleKeys = { "SET_CATEGORY_APPEARANCE", "SET_SECTION_VISUAL_FONT" },
		title = "Interface and appearance",
		descriptionKeys = { "SET_SECTION_VISUAL_FONT_DESC" },
		description = "Customize the floating window, minimap button, "
			.. "Premade Groups entry, panel size, and text size.",
	},
	party_list = {
		titleKeys = { "SET_CATEGORY_PARTY_LIST", "SET_SECTION_LISTING" },
		title = "List styles",
		descriptionKeys = { "SET_SECTION_LISTING_DESC" },
		description = "Customize group and applicant list styles, and show "
			.. "party members by specialization or role.",
	},
	notifications = {
		titleKeys = { "SET_CATEGORY_ALERTS", "SET_SECTION_ALERTS" },
		title = "Alerts and announcements",
		descriptionKeys = { "SET_SECTION_ALERTS_DESC" },
		description = "Customize applicant sounds, group-formed popups, "
			.. "Mythic+ teleport announcements, and keystone announcements.",
		newFeature = {
			featureID = "notificationsCategory",
			revision = 2,
			introducedInVersion = "2.1.10",
			hideAtVersion = "2.1.11",
		},
	},
	tactical = {
		titleKeys = { "SET_CATEGORY_TACTICAL", "SET_SECTION_MPLUS_TACTICAL" },
		title = "Tactical announcements",
		descriptionKeys = { "SET_SECTION_MPLUS_TACTICAL_DESC" },
		description = "Customize tactical announcements for current-season Mythic+ dungeons.",
		newFeature = {
			featureID = "tacticalAnnouncements",
			revision = 2,
			introducedInVersion = "2.1.4",
			hideAtVersion = "2.1.6",
		},
	},
	find_group = {
		titleKeys = { "SET_CATEGORY_FIND_GROUP", "SET_SECTION_FIND_GROUP" },
		title = "Featured features",
		descriptionKeys = { "SET_SECTION_FIND_GROUP_DESC" },
		description = "Instance difficulty tools, advanced filters, auto-join, "
			.. "auto-invite, default item level, blocklist, and more.",
		newFeature = {
			featureID = "instanceGateway",
			revision = 1,
			introducedInVersion = "2.2.1",
			hideAtVersion = "2.2.2",
		},
	},
	netease_newbie = {
		titleKeys = { "SET_CATEGORY_NETEASE_NEWBIE" },
		title = "NetEase Newbie Event",
		descriptionKeys = { "SET_CATEGORY_NETEASE_NEWBIE_DESC" },
		description = "NetEase player identities and Newbie Event filtering.",
		activityBadge = true,
	},
}

local state = {
	selectedCategoryID = CATEGORY_IDS[1],
	categoryScrollOffsets = {},
	drafts = {},
	refreshers = {},
	refresherOrder = {},
	nextRefresherID = 0,
	tactical = {},
}

local function isNetEaseActivityAvailable()
	local activity = GF.NetEaseActivity
	if not (activity and type(activity.IsSupportedClient) == "function") then
		return false
	end
	local ok, supported = pcall(activity.IsSupportedClient, activity)
	if not ok or supported ~= true then return false end
	local module = GF.NetEaseModule
	if not (module and type(module.IsAvailable) == "function") then
		return false
	end
	local available
	ok, available = pcall(module.IsAvailable, module)
	return ok and available == true
end

local function isCategoryAvailable(categoryID)
	return categoryID ~= "netease_newbie"
		or isNetEaseActivityAvailable()
end

local function copySequence(source)
	local result = {}
	for index = 1, #(source or {}) do
		result[index] = source[index]
	end
	return result
end

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return nil
	end
	return method(owner, ...)
end

local function call(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return false, nil
	end
	local ok, value, extra = pcall(method, owner, ...)
	return ok, value, extra
end

local function localized(locale, keys, fallback)
	locale = type(locale) == "table" and locale or GF.L or {}
	for index = 1, #(keys or {}) do
		local value = locale[keys[index]]
		if type(value) == "string" and value ~= "" then
			return value
		end
	end
	return fallback or ""
end

local function database()
	return Repository:Get()
end

local function readRoot(key)
	local db = database()
	return db and db[key] or nil
end

local function writeRoot(key, value)
	local db = database()
	if not db then
		return nil
	end
	db[key] = value
	return db[key]
end

local function writeNormalizedRoot(key, value)
	local db = database()
	if not db then
		return nil
	end
	db[key] = value
	Schema:NormalizeRoot(db)
	return db[key]
end

local function rootBoolean(key)
	return {
		read = function()
			return readRoot(key) == true
		end,
		write = function(value)
			return writeRoot(key, value == true)
		end,
	}
end

local function launcher()
	return GF.LauncherStateService
end

local function serviceWithMethods(serviceName, methods)
	local service = GF[serviceName]
	if type(service) ~= "table" then
		return nil
	end
	for index = 1, #(methods or {}) do
		if type(service[methods[index]]) ~= "function" then
			return nil
		end
	end
	return service
end

local function announcementService(...)
	return serviceWithMethods(
		"MythicPlusAnnouncementService",
		{ ... }
	)
end

local function rotationService(...)
	return serviceWithMethods(
		"MythicPlusKeystoneRotationReminderService",
		{ ... }
	)
end

local function teleportFollowService(...)
	return serviceWithMethods(
		"MythicPlusTeleportFollowService",
		{ ... }
	)
end

local function groupReadyTeleportService(...)
	return serviceWithMethods(
		"MythicPlusGroupReadyTeleportService",
		{ ... }
	)
end

local function readService(service, methodName, fallback, ...)
	local ok, value = call(service, methodName, ...)
	if not ok or value == nil then
		return fallback
	end
	return value
end

local function writeService(service, methodName, ...)
	local ok, value = call(service, methodName, ...)
	if not ok then
		return nil
	end
	return value == nil and true or value
end

local function rootField(key, category, options)
	options = options or {}
	local field = options
	field.category = category
	field.read = field.read or function()
		return readRoot(key)
	end
	field.write = field.write or function(value)
		return writeRoot(key, value)
	end
	return field
end

local FIELD_SPECS = {
	interfaceLocale = rootField("interfaceLocale", "appearance", {
		read = function()
			return GF.GetInterfaceLocale and GF.GetInterfaceLocale()
				or Schema:NormalizeInterfaceLocale(readRoot("interfaceLocale"))
		end,
		write = function(value)
			return GF.SetInterfaceLocale and GF.SetInterfaceLocale(value)
				or writeNormalizedRoot("interfaceLocale", value)
		end,
		refresh = { "interface-locale" },
	}),
	showFloatButton = rootField("showFloatButton", "appearance", {
		read = function()
			local service = launcher()
			if service and service.IsFloatVisible then
				return service:IsFloatVisible()
			end
			return readRoot("showFloatButton") == true
		end,
		write = function(value)
			local service = launcher()
			if service and service.SetFloatVisible then
				service:SetFloatVisible(value == true, "settings")
				return service:IsFloatVisible()
			end
			return writeRoot("showFloatButton", value == true)
		end,
		refresh = { "float-visibility" },
	}),
	instanceGatewayEnabled = rootField("instanceGatewayEnabled", "find_group", {
		read = function()
			local service = GF.InstanceGatewayService
			if service and type(service.IsEnabled) == "function" then
				return service:IsEnabled()
			end
			return readRoot("instanceGatewayEnabled") == true
		end,
		write = function(value)
			local service = GF.InstanceGatewayService
			if service and type(service.SetEnabled) == "function" then
				return service:SetEnabled(value == true)
			end
			return writeRoot("instanceGatewayEnabled", value == true)
		end,
		refresh = { "instance-gateway" },
	}),
	lockFloatButton = rootField("lockFloatButton", "appearance", {
		read = function()
			local service = launcher()
			if service and service.IsFloatDragLocked then
				return service:IsFloatDragLocked()
			end
			return readRoot("lockFloatButton") == true
		end,
		write = function(value)
			local service = launcher()
			if service and service.SetFloatDragLocked then
				service:SetFloatDragLocked(value == true, "settings")
				return service:IsFloatDragLocked()
			end
			return writeRoot("lockFloatButton", value == true)
		end,
		refresh = { "float-drag-lock" },
	}),
	showMinimap = rootField("showMinimap", "appearance", {
		read = function()
			local service = launcher()
			if service and service.IsMinimapVisible then
				return service:IsMinimapVisible()
			end
			return readRoot("showMinimap") == true
		end,
		write = function(value)
			local service = launcher()
			if service and service.SetMinimapVisible then
				service:SetMinimapVisible(value == true, "settings")
				return service:IsMinimapVisible()
			end
			return writeRoot("showMinimap", value == true)
		end,
		refresh = { "minimap" },
	}),
	minimapSquareOrbit = rootField("minimapSquareOrbit", "appearance", {
		read = function()
			local service = launcher()
			if service and service.UsesSquareMinimapOrbit then
				return service:UsesSquareMinimapOrbit()
			end
			return readRoot("minimapSquareOrbit") == true
		end,
		write = function(value)
			local service = launcher()
			if service and service.SetSquareMinimapOrbit then
				service:SetSquareMinimapOrbit(value == true, "settings")
				return service:UsesSquareMinimapOrbit()
			end
			return writeRoot("minimapSquareOrbit", value == true)
		end,
		refresh = { "minimap" },
	}),
	preferOpen = rootField("preferOpen", "appearance", {
		read = rootBoolean("preferOpen").read,
		write = rootBoolean("preferOpen").write,
		refresh = { "premade-hook" },
	}),
	workspaceTabPosition = rootField("workspaceTabPosition", "appearance", {
		read = function()
			return GF.GetWorkspaceTabPosition and GF.GetWorkspaceTabPosition()
				or Schema:NormalizeWorkspaceTabPosition(readRoot("workspaceTabPosition"))
		end,
		write = function(value)
			return GF.SetWorkspaceTabPosition and GF.SetWorkspaceTabPosition(value)
				or writeNormalizedRoot("workspaceTabPosition", value)
		end,
		refresh = { "workspace-tab-position" },
	}),
	floatScalePct = rootField("floatScalePct", "appearance", {
		read = function()
			return GF.GetFloatScalePct and GF.GetFloatScalePct()
				or readRoot("floatScalePct")
		end,
		write = function(value)
			return GF.SetFloatScalePct and GF.SetFloatScalePct(value)
				or writeNormalizedRoot("floatScalePct", value)
		end,
		refresh = { "floating-scale" },
	}),
	fontKey = rootField("fontKey", "appearance", {
		read = function()
			local saved = readRoot("fontKey")
			if GF.Font and GF.Font.ResolveFontObjectKey then
				return GF.Font.ResolveFontObjectKey(saved)
			end
			return saved
		end,
		write = function(value)
			return writeNormalizedRoot("fontKey", value)
		end,
		refresh = { "font-appearance" },
	}),
	fontOutline = rootField("fontOutline", "appearance", {
		read = function()
			return readRoot("fontOutline")
		end,
		write = function(value)
			return writeNormalizedRoot("fontOutline", value)
		end,
		refresh = { "font-appearance" },
	}),
	fontScalePct = rootField("fontScalePct", "appearance", {
		read = function()
			return GF.GetFontScalePct and GF.GetFontScalePct()
				or readRoot("fontScalePct")
		end,
		write = function(value)
			return GF.SetFontScalePct and GF.SetFontScalePct(value)
				or writeNormalizedRoot("fontScalePct", value)
		end,
		refresh = { "font-appearance" },
	}),
	frameStrata = rootField("frameStrata", "appearance", {
		read = function()
			return GF.GetFrameStrata and GF.GetFrameStrata()
				or readRoot("frameStrata")
		end,
		write = function(value)
			return writeNormalizedRoot("frameStrata", value)
		end,
		refresh = { "frame-strata" },
	}),
	panelSkin = rootField("panelSkin", "appearance", {
		read = function()
			return GF.GetPanelSkin and GF.GetPanelSkin()
				or Schema:NormalizePanelSkin(readRoot("panelSkin"))
		end,
		write = function(value)
			return GF.SetPanelSkin and GF.SetPanelSkin(value)
				or writeNormalizedRoot("panelSkin", value)
		end,
		refresh = { "panel-skin" },
	}),
	panelScalePct = rootField("panelScalePct", "appearance", {
		read = function()
			return GF.GetPanelScalePct and GF.GetPanelScalePct()
				or readRoot("panelScalePct")
		end,
		write = function(value)
			return GF.SetPanelScalePct and GF.SetPanelScalePct(value)
				or writeNormalizedRoot("panelScalePct", value)
		end,
		refresh = { "panel-scale" },
	}),

	showLeaderRealm = rootField("showLeaderRealm", "party_list", {
		read = rootBoolean("showLeaderRealm").read,
		write = rootBoolean("showLeaderRealm").write,
		refresh = { "leader-realm" },
	}),
	showGameType = rootField("showGameType", "party_list", {
		read = rootBoolean("showGameType").read,
		write = rootBoolean("showGameType").write,
		refresh = { "game-type" },
	}),
	memberDisplayMode = rootField("memberDisplayMode", "party_list", {
		read = function()
			return GF.GetMemberDisplayMode and GF.GetMemberDisplayMode()
				or Schema:NormalizeMemberDisplayMode(readRoot("memberDisplayMode"))
		end,
		write = function(value)
			return GF.SetMemberDisplayMode and GF.SetMemberDisplayMode(value)
				or writeRoot(
					"memberDisplayMode",
					Schema:NormalizeMemberDisplayMode(value)
				)
		end,
		refresh = { "member-display" },
	}),
	expiredGroupMode = rootField("expiredGroupMode", "party_list", {
		read = function()
			return GF.GetExpiredGroupMode and GF.GetExpiredGroupMode()
				or Schema:NormalizeExpiredGroupMode(
					readRoot("expiredGroupMode"))
		end,
		write = function(value)
			return GF.SetExpiredGroupMode and GF.SetExpiredGroupMode(value)
				or writeRoot(
					"expiredGroupMode",
					Schema:NormalizeExpiredGroupMode(value)
				)
		end,
		refresh = { "expired-groups" },
	}),
	memberTooltipMode = rootField("memberTooltipMode", "party_list", {
		read = function()
			return GF.GetMemberTooltipMode and GF.GetMemberTooltipMode()
				or Schema:NormalizeMemberTooltipMode(readRoot("memberTooltipMode"))
		end,
		write = function(value)
			return GF.SetMemberTooltipMode and GF.SetMemberTooltipMode(value)
				or writeRoot(
					"memberTooltipMode",
					Schema:NormalizeMemberTooltipMode(value)
				)
		end,
	}),
	listWheelScrollRows = rootField("listWheelScrollRows", "party_list", {
		write = function(value)
			return writeNormalizedRoot("listWheelScrollRows", value)
		end,
	}),
	listBackgroundStyle = {
		category = "party_list",
		read = function(context)
			local styleKey = context and context.styleKey or "normal"
			if GF.GetListBackgroundStyle then
				return GF.GetListBackgroundStyle(styleKey)
			end
			return Schema:NormalizeListBackgroundStyle(styleKey)
		end,
		write = function(value, context)
			local styleKey = context and context.styleKey or "normal"
			if GF.SetListBackgroundStyle then
				return GF.SetListBackgroundStyle(styleKey, value)
			end
			return nil
		end,
		refresh = { "list-background" },
	},

	applicantAlertSoundFile = rootField(
		"applicantAlertSoundFile", "notifications", {
			read = function()
				return GF.GetApplicantAlertSoundFile
					and GF.GetApplicantAlertSoundFile()
					or Schema:NormalizeApplicantAlertSoundFile(
						readRoot("applicantAlertSoundFile")
					)
			end,
			write = function(value)
				if GF.SetApplicantAlertSoundFile then
					GF.SetApplicantAlertSoundFile(value)
					return GF.GetApplicantAlertSoundFile()
				end
				return writeRoot(
					"applicantAlertSoundFile",
					Schema:NormalizeApplicantAlertSoundFile(value)
				)
			end,
			refresh = { "applicant-sound-preview" },
		}
	),
	joinAnnounceEnabled = rootField("joinAnnounceEnabled", "notifications", {
		read = rootBoolean("joinAnnounceEnabled").read,
		write = rootBoolean("joinAnnounceEnabled").write,
	}),
	keystoneRotationReminderEnabled = {
		category = "notifications",
		dependency = function()
			return rotationService("IsEnabled", "SetEnabled") ~= nil
		end,
		read = function()
			local service = rotationService("IsEnabled")
			return service and readService(service, "IsEnabled", false) == true
				or false
		end,
		write = function(value)
			return writeService(
				rotationService("SetEnabled"), "SetEnabled", value == true)
		end,
	},
	keystoneAnnouncementEnabled = {
		category = "notifications",
		dependency = function()
			return announcementService(
				"IsKeystoneAnnouncementEnabled",
				"SetKeystoneAnnouncementEnabled"
			) ~= nil
		end,
		read = function()
			local service = announcementService(
				"IsKeystoneAnnouncementEnabled")
			return service and readService(
				service, "IsKeystoneAnnouncementEnabled", false) == true or false
		end,
		write = function(value)
			return writeService(
				announcementService("SetKeystoneAnnouncementEnabled"),
				"SetKeystoneAnnouncementEnabled",
				value == true
			)
		end,
	},
	groupReadyTeleportEnabled = {
		category = "notifications",
		refresh = { "teleport-prompt-mode" },
		dependency = function()
			return groupReadyTeleportService("IsEnabled", "SetEnabled") ~= nil
		end,
		read = function()
			local service = groupReadyTeleportService("IsEnabled")
			return service and readService(service, "IsEnabled", false) == true
				or false
		end,
		write = function(value)
			return writeService(
				groupReadyTeleportService("SetEnabled"),
				"SetEnabled",
				value == true)
		end,
	},
	teleportFollowEnabled = {
		category = "notifications",
		refresh = { "teleport-prompt-mode" },
		dependency = function()
			return announcementService(
				"IsTeleportFollowEnabled", "SetTeleportFollowEnabled") ~= nil
		end,
		read = function()
			local service = announcementService("IsTeleportFollowEnabled")
			return service and readService(
				service, "IsTeleportFollowEnabled", false) == true or false
		end,
		write = function(value)
			return writeService(
				announcementService("SetTeleportFollowEnabled"),
				"SetTeleportFollowEnabled",
				value == true
			)
		end,
	},
	teleportAnnouncementEnabled = {
		category = "notifications",
		dependency = function()
			return announcementService(
				"IsTeleportAnnouncementEnabled",
				"SetTeleportAnnouncementEnabled"
			) ~= nil
		end,
		read = function()
			local service = announcementService(
				"IsTeleportAnnouncementEnabled")
			return service and readService(
				service, "IsTeleportAnnouncementEnabled", false) == true or false
		end,
		write = function(value)
			return writeService(
				announcementService("SetTeleportAnnouncementEnabled"),
				"SetTeleportAnnouncementEnabled",
				value == true
			)
		end,
	},
	teleportMessage = {
		category = "notifications",
		commitMode = "explicit",
		dependency = function()
			return announcementService(
				"GetTeleportMessage", "SetTeleportMessage") ~= nil
		end,
		read = function()
			local service = announcementService("GetTeleportMessage")
			return tostring(service and readService(
				service, "GetTeleportMessage", "") or "")
		end,
		write = function(value)
			return writeService(
				announcementService("SetTeleportMessage"),
				"SetTeleportMessage",
				tostring(value or "")
			)
		end,
	},

	autoExpandFilter = rootField("autoExpandFilter", "find_group", {
		read = rootBoolean("autoExpandFilter").read,
		write = rootBoolean("autoExpandFilter").write,
	}),
	defaultRequiredItemLevel = {
		category = "find_group",
		dependency = function()
			return type(GF.GetDefaultRequiredItemLevel) == "function"
				and type(GF.SetDefaultRequiredItemLevel) == "function"
		end,
		read = function()
			return GF.GetDefaultRequiredItemLevel
				and GF.GetDefaultRequiredItemLevel() or nil
		end,
		write = function(value)
			return GF.SetDefaultRequiredItemLevel
				and GF.SetDefaultRequiredItemLevel(value) or nil
		end,
		refresh = { "default-item-level" },
	},
	menuEnhancementEnabled = rootField(
		"menuEnhancementEnabled", "find_group", {
			read = rootBoolean("menuEnhancementEnabled").read,
			write = rootBoolean("menuEnhancementEnabled").write,
		}
	),
	autoInviteMemberLimitEnabled = rootField(
		"autoInviteMemberLimitEnabled", "find_group", {
			read = rootBoolean("autoInviteMemberLimitEnabled").read,
			write = rootBoolean("autoInviteMemberLimitEnabled").write,
			refresh = { "invite-controls" },
		}
	),
	autoInviteMemberLimit = rootField(
		"autoInviteMemberLimit", "find_group", {
			write = function(value)
				return writeNormalizedRoot("autoInviteMemberLimit", value)
			end,
			dependency = function()
				local enabled =
					readRoot("autoInviteMemberLimitEnabled") == true
				return {
					available = true,
					enabled = enabled,
					reason = enabled and nil or "dependency-disabled",
				}
			end,
			refresh = { "invite-controls" },
		}
	),
	applyMode = rootField("applyMode", "find_group", {
		read = function()
			local apply = GF.Apply
			return apply and apply.GetMode and apply:GetMode()
				or readRoot("applyMode")
		end,
		write = function(value)
			return writeNormalizedRoot("applyMode", value)
		end,
		refresh = { "browse-options" },
	}),
	autoAcceptInvite = rootField("autoAcceptInvite", "find_group", {
		read = rootBoolean("autoAcceptInvite").read,
		write = rootBoolean("autoAcceptInvite").write,
		refresh = { "auto-accept", "browse-options" },
	}),
	rememberApplicationNote = rootField(
		"rememberApplicationNote", "find_group", {
			read = rootBoolean("rememberApplicationNote").read,
			write = rootBoolean("rememberApplicationNote").write,
			refresh = { "application-note" },
		}
	),
	replaceOldestApplication = rootField(
		"replaceOldestApplication", "find_group", {
			read = rootBoolean("replaceOldestApplication").read,
			write = rootBoolean("replaceOldestApplication").write,
		}
	),
	blacklistEnabled = rootField("blacklistEnabled", "find_group", {
		read = rootBoolean("blacklistEnabled").read,
		write = rootBoolean("blacklistEnabled").write,
		refresh = { "blacklist" },
	}),
	showBlacklistChatNotice = rootField(
		"showBlacklistChatNotice", "find_group", {
			read = rootBoolean("showBlacklistChatNotice").read,
			write = rootBoolean("showBlacklistChatNotice").write,
		}
	),
	neteaseIdentityEnabled = {
		category = "netease_newbie",
		dependency = function()
			local service = GF.NetEaseIdentityService
			local localeSupported = isNetEaseActivityAvailable()
			local activityActive = GF.NetEaseActivity:IsActive()
			local canEnable = localeSupported and service ~= nil
				and service:CanEnable() == true
			return {
				available = localeSupported and service ~= nil,
				enabled = canEnable,
				reason = not localeSupported and "unsupported-locale"
					or (service == nil and "dependency-unavailable")
					or (not activityActive and "activity-ended")
					or (not canEnable and "dependency-unavailable")
					or nil,
			}
		end,
		read = function()
			local service = GF.NetEaseIdentityService
			return service and service:IsUserEnabled() == true or false
		end,
		write = function(value)
			local service = GF.NetEaseIdentityService
			if not service then
				return nil
			end
			service:SetEnabled(value == true)
			return service:IsUserEnabled()
		end,
		refresh = { "netease-identity" },
	},

	tacticalAnnouncement = {
		category = "tactical",
		commitMode = "explicit",
		dependency = function(context)
			local service = announcementService(
				"GetTacticalAnnouncement", "SetTacticalAnnouncement")
			local selected =
				context and tonumber(context.challengeModeID) ~= nil
			return {
				available = service ~= nil,
				enabled = service ~= nil and selected,
				reason = service == nil and "dependency-unavailable"
					or (not selected and "selection-required" or nil),
			}
		end,
		read = function(context)
			local service = announcementService("GetTacticalAnnouncement")
			local challengeModeID = context and tonumber(context.challengeModeID)
			return tostring(service and challengeModeID and readService(
				service,
				"GetTacticalAnnouncement",
				"",
				challengeModeID
			) or "")
		end,
		write = function(value, context)
			local challengeModeID = context and tonumber(context.challengeModeID)
			return challengeModeID and writeService(
				announcementService("SetTacticalAnnouncement"),
				"SetTacticalAnnouncement",
				challengeModeID,
				tostring(value or "")
			) or nil
		end,
	},
}

local OPTION_FACTORIES = {
	interfaceLocale = function(locale)
		local systemLocale = GF.Locale and GF.Locale.GetSystemLocaleKey
			and GF.Locale:GetSystemLocaleKey() or "enUS"
		local localeNames = {
			zhCN = locale.SET_INTERFACE_LANGUAGE_ZHCN or "简体中文",
			zhTW = locale.SET_INTERFACE_LANGUAGE_ZHTW or "繁體中文",
			enUS = locale.SET_INTERFACE_LANGUAGE_ENUS or "English",
			ruRU = locale.SET_INTERFACE_LANGUAGE_RURU or "Русский",
		}
		local systemTemplate = locale.SET_INTERFACE_LANGUAGE_SYSTEM_RESOLVED
			or "Follow System (%s)"
		local ok, systemLabel = pcall(
			string.format,
			systemTemplate,
			localeNames[systemLocale] or localeNames.enUS)
		if not ok then
			systemLabel = locale.SET_INTERFACE_LANGUAGE_SYSTEM
				or "Follow System"
		end
		return {
			{ value = "system", label = systemLabel },
			{ value = "zhCN", label = localeNames.zhCN },
			{ value = "zhTW", label = localeNames.zhTW },
			{ value = "enUS", label = localeNames.enUS },
			{ value = "ruRU", label = localeNames.ruRU },
		}
	end,
	applyMode = function(locale)
		return {
			{
				value = GF.APPLY_MANUAL or "manual",
				label = locale.SET_APPLY_MANUAL or "Manual",
			},
			{
				value = GF.APPLY_CLICK_CONFIRM or "click_confirm",
				label = locale.SET_APPLY_CLICK_CONFIRM or "Click row",
			},
			{
				value = GF.APPLY_DBLCLICK_AUTO or "dblclick_auto",
				label = locale.SET_APPLY_DBLCLICK_AUTO or "Double-click row",
			},
		}
	end,
	memberDisplayMode = function(locale)
		return {
			{
				value = GF.MEMBER_DISPLAY_MODE_ROLE or "role",
				label = locale.SET_MEMBER_DISPLAY_ROLE or "Role mode",
			},
			{
				value = GF.MEMBER_DISPLAY_MODE_SPEC or "spec",
				label = locale.SET_MEMBER_DISPLAY_SPEC
					or "Specialization mode",
			},
			{
				value = GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large",
				label = locale.SET_MEMBER_DISPLAY_SPEC_LARGE
					or "Specialization mode (large)",
			},
		}
	end,
	expiredGroupMode = function(locale)
		return {
			{
				value = GF.EXPIRED_GROUP_MODE_RETAIN_GRAY or "retain_gray",
				label = locale.SET_EXPIRED_GROUP_RETAIN_GRAY
					or "Keep expired groups grayed out",
			},
			{
				value = GF.EXPIRED_GROUP_MODE_AUTO_REMOVE or "auto_remove",
				label = locale.SET_EXPIRED_GROUP_AUTO_REMOVE
					or "Automatically remove expired groups",
			},
		}
	end,
	memberTooltipMode = function(locale)
		return {
			{
				value = GF.MEMBER_TOOLTIP_MODE_DETAILS or "details",
				label = locale.SET_MEMBER_TOOLTIP_DETAILS
					or "Member detail mode",
			},
			{
				value = GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count",
				label = locale.SET_MEMBER_TOOLTIP_SPEC_COUNT
					or "Specialization count mode",
			},
		}
	end,
	applicantAlertSoundFile = function(locale)
		local options = {}
		local source = GF.GetApplicantAlertSoundOptions
			and GF.GetApplicantAlertSoundOptions() or {}
		for index = 1, #source do
			local sound = source[index]
			options[index] = {
				value = sound.file,
				label = (sound.labelKey and locale[sound.labelKey])
					or sound.label or sound.file or "",
			}
		end
		return options
	end,
	frameStrata = function(locale)
		return {
			{ value = "LOW", label = locale.SET_FRAME_STRATA_LOW or "Low" },
			{ value = "MEDIUM", label = locale.SET_FRAME_STRATA_MEDIUM or "Medium" },
			{ value = "HIGH", label = locale.SET_FRAME_STRATA_HIGH or "High" },
			{ value = "DIALOG", label = locale.SET_FRAME_STRATA_DIALOG or "Dialog" },
		}
	end,
	workspaceTabPosition = function(locale)
		return {
			{ value = "right", label = locale.SET_WORKSPACE_TAB_RIGHT or "Panel right" },
			{ value = "left", label = locale.SET_WORKSPACE_TAB_LEFT or "Panel left" },
			{ value = "bottom", label = locale.SET_WORKSPACE_TAB_BOTTOM or "Panel bottom" },
		}
	end,
	panelSkin = function(locale)
		local options = {}
		local source = GF.GetPanelSkinOptions
			and GF.GetPanelSkinOptions() or GF.PANEL_SKIN_OPTIONS or {}
		for index = 1, #source do
			local skin = source[index]
			options[index] = {
				value = skin.value,
				label = (skin.labelKey and locale[skin.labelKey])
					or skin.label or skin.value or "",
			}
		end
		return options
	end,
	fontKey = function()
		return GF.Font and GF.Font.GetFontOptions
			and GF.Font.GetFontOptions() or {}
	end,
	fontOutline = function()
		return GF.Font and GF.Font.GetOutlineOptions
			and GF.Font.GetOutlineOptions() or {}
	end,
}

local ACTION_SPECS = {
	instanceGatewayEdit = {
		available = function()
			return GF.InstanceGatewayEditMode
				and GF.InstanceGatewayEditMode:CanOpen()
		end,
		run = function()
			return GF.InstanceGatewayEditMode:Open()
		end,
	},
	neteaseAPIRefresh = {
		available = function()
			local service = GF.NetEaseIdentityService
			return service
				and type(service.CanRefreshAPIStatus) == "function"
				and service:CanRefreshAPIStatus() == true
		end,
		run = function()
			local service = GF.NetEaseIdentityService
			if not service or type(service.RefreshAPIStatus) ~= "function" then
				return false, "unavailable"
			end
			return service:RefreshAPIStatus()
		end,
	},
	joinAnnouncePreview = {
		available = function()
			return GF.JoinAnnounce
				and type(GF.JoinAnnounce.Preview) == "function"
		end,
		run = function()
			return invoke(GF.JoinAnnounce, "Preview")
		end,
	},
	keystoneRotationPreview = {
		available = function()
			return rotationService("RequestPreview") ~= nil
		end,
		run = function()
			return invoke(rotationService("RequestPreview"), "RequestPreview")
		end,
	},
	teleportFollowPreview = {
		available = function()
			return teleportFollowService("RequestPreview") ~= nil
		end,
		run = function()
			local service = teleportFollowService("RequestPreview")
			if not service then
				return false, "unavailable"
			end
			local ok, opened, reason = pcall(service.RequestPreview, service)
			if not ok then
				return false, "unavailable"
			end
			return opened == true, reason
		end,
	},
	groupReadyTeleportPreview = {
		available = function()
			return groupReadyTeleportService("RequestPreview") ~= nil
		end,
		run = function()
			local service = groupReadyTeleportService("RequestPreview")
			if not service then
				return false, "unavailable"
			end
			local ok, opened, reason = pcall(service.RequestPreview, service)
			if not ok then
				return false, "unavailable"
			end
			return opened == true, reason
		end,
	},
}

local COMPATIBILITY_STATE_KEYS = {
	_selectedCategoryID = "selectedCategoryID",
	_categoryScrollOffsets = "categoryScrollOffsets",
	_tacticalSelectedChallengeModeID = "tactical.selectedChallengeModeID",
	_pendingTacticalChallengeModeID = "tactical.pendingChallengeModeID",
}

local function readStatePath(path)
	if path == "tactical.pendingChallengeModeID" then
		return state.tactical.pendingChallengeModeID
	elseif path == "tactical.selectedChallengeModeID" then
		return state.tactical.selectedChallengeModeID
	end
	return state[path]
end

local function writeStatePath(path, value)
	if path == "tactical.pendingChallengeModeID" then
		state.tactical.pendingChallengeModeID = value
	elseif path == "tactical.selectedChallengeModeID" then
		state.tactical.selectedChallengeModeID = value
	else
		state[path] = value
	end
end

function Presenter:BindView(view)
	if type(view) ~= "table" then
		return nil
	end
	local existing = getmetatable(view)
	if existing and existing._gfSettingsPresenter == self then
		return true
	end
	for key, path in pairs(COMPATIBILITY_STATE_KEYS) do
		local value = rawget(view, key)
		if value ~= nil then
			writeStatePath(path, value)
			rawset(view, key, nil)
		end
	end
	local previousIndex = existing and existing.__index
	local previousNewIndex = existing and existing.__newindex
	local meta = {}
	for key, value in pairs(existing or {}) do
		meta[key] = value
	end
	meta._gfSettingsPresenter = self
	meta.__index = function(target, key)
		local path = COMPATIBILITY_STATE_KEYS[key]
		if path then
			return readStatePath(path)
		end
		if type(previousIndex) == "function" then
			return previousIndex(target, key)
		elseif type(previousIndex) == "table" then
			return previousIndex[key]
		end
		return nil
	end
	meta.__newindex = function(target, key, value)
		local path = COMPATIBILITY_STATE_KEYS[key]
		if path then
			writeStatePath(path, value)
		elseif type(previousNewIndex) == "function" then
			previousNewIndex(target, key, value)
		elseif type(previousNewIndex) == "table" then
			previousNewIndex[key] = value
		else
			rawset(target, key, value)
		end
	end
	setmetatable(view, meta)
	return true
end

function Presenter:GetCategoryIDs()
	local result = {}
	for index = 1, #CATEGORY_IDS do
		local id = CATEGORY_IDS[index]
		if isCategoryAvailable(id) then
			result[#result + 1] = id
		end
	end
	return result
end

function Presenter:GetCategoryDefinitions(locale)
	local definitions = {}
	for index = 1, #CATEGORY_IDS do
		local id = CATEGORY_IDS[index]
		if isCategoryAvailable(id) then
			local spec = CATEGORY_SPECS[id]
			definitions[#definitions + 1] = {
				id = id,
				title = localized(locale, spec.titleKeys, spec.title),
				description = localized(
					locale, spec.descriptionKeys, spec.description),
				newFeature = spec.newFeature,
				activityBadge = spec.activityBadge and {
					phase = GF.NetEaseActivity and GF.NetEaseActivity:GetPhase()
						or "ended",
				} or nil,
			}
		end
	end
	return definitions
end

function Presenter:GetCategoryInfo(categoryID, locale)
	local spec = CATEGORY_SPECS[categoryID]
	if not spec or not isCategoryAvailable(categoryID) then
		return nil
	end
	return {
		id = categoryID,
		title = localized(locale, spec.titleKeys, spec.title),
		description = localized(
			locale, spec.descriptionKeys, spec.description),
		newFeature = spec.newFeature,
	}
end

function Presenter:ResolveCategory(categoryID, routes)
	if CATEGORY_SPECS[categoryID] and isCategoryAvailable(categoryID)
		and (routes == nil or routes[categoryID] ~= nil)
	then
		return categoryID
	end
	for index = 1, #CATEGORY_IDS do
		local fallback = CATEGORY_IDS[index]
		if isCategoryAvailable(fallback)
			and (routes == nil or routes[fallback] ~= nil)
		then
			return fallback
		end
	end
	return nil
end

function Presenter:SelectCategory(categoryID, routes, locale)
	local resolved = self:ResolveCategory(categoryID, routes)
	if not resolved then
		return nil
	end
	local previous = state.selectedCategoryID
	state.selectedCategoryID = resolved
	return {
		id = resolved,
		previousID = previous,
		changed = previous ~= resolved,
		category = self:GetCategoryInfo(resolved, locale),
		scrollOffset = state.categoryScrollOffsets[resolved] or 0,
	}
end

function Presenter:GetSelectedCategory(locale)
	local id = self:ResolveCategory(state.selectedCategoryID)
	state.selectedCategoryID = id
	return id, self:GetCategoryInfo(id, locale)
end

function Presenter:RememberCategoryScroll(categoryID, offset)
	categoryID = self:ResolveCategory(categoryID)
	if not categoryID then
		return nil
	end
	state.categoryScrollOffsets[categoryID] = tonumber(offset) or 0
	return state.categoryScrollOffsets[categoryID]
end

function Presenter:GetCategoryScroll(categoryID)
	categoryID = self:ResolveCategory(categoryID)
	return categoryID and state.categoryScrollOffsets[categoryID] or 0
end

function Presenter:GetTacticalSelection()
	return state.tactical.selectedChallengeModeID
end

function Presenter:SetTacticalSelection(challengeModeID)
	challengeModeID = tonumber(challengeModeID)
	local previousID = state.tactical.selectedChallengeModeID
	state.tactical.selectedChallengeModeID = challengeModeID
	return {
		challengeModeID = challengeModeID,
		previousID = previousID,
		changed = previousID ~= challengeModeID,
	}
end

function Presenter:GetPendingTacticalSelection()
	return state.tactical.pendingChallengeModeID
end

function Presenter:ClearTacticalSelectionPrompt()
	local previousID = state.tactical.pendingChallengeModeID
	state.tactical.pendingChallengeModeID = nil
	return previousID
end

local function fieldInstanceKey(fieldID, context)
	if fieldID == "listBackgroundStyle" then
		return fieldID .. ":" .. tostring(context and context.styleKey or "normal")
	elseif fieldID == "tacticalAnnouncement" then
		return fieldID .. ":" .. tostring(
			context and tonumber(context.challengeModeID) or "none")
	end
	return fieldID
end

local function valuesEqual(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return left == right
	end
	for key, value in pairs(left) do
		if right[key] ~= value then
			return false
		end
	end
	for key, value in pairs(right) do
		if left[key] ~= value then
			return false
		end
	end
	return true
end

function Presenter:ProjectDependency(fieldID, context)
	local spec = FIELD_SPECS[fieldID]
	if not spec then
		return {
			available = false,
			enabled = false,
			dimmed = true,
			reason = "unknown-field",
		}
	end
	local available = true
	local enabled = true
	local reason
	if type(spec.dependency) == "function" then
		local ok, resolved = pcall(spec.dependency, context)
		if not ok then
			available = false
			enabled = false
		elseif type(resolved) == "table" then
			available = resolved.available ~= false
			enabled = available and resolved.enabled ~= false
			reason = resolved.reason
		else
			available = resolved == true
			enabled = available
		end
	end
	return {
		available = available,
		enabled = enabled,
		dimmed = not enabled,
		reason = reason
			or (available and not enabled and "dependency-disabled")
			or (not available and "dependency-unavailable")
			or nil,
	}
end

function Presenter:ReadValue(fieldID, context)
	local spec = FIELD_SPECS[fieldID]
	if not spec or type(spec.read) ~= "function" then
		return nil
	end
	local ok, value = pcall(spec.read, context)
	if not ok then
		return nil
	end
	return value
end

function Presenter:ProjectField(fieldID, context)
	local spec = FIELD_SPECS[fieldID]
	local dependency = self:ProjectDependency(fieldID, context)
	local savedValue = self:ReadValue(fieldID, context)
	local key = fieldInstanceKey(fieldID, context)
	local draft = state.drafts[key]
	local value = draft ~= nil and draft.value or savedValue
	local dirty = draft ~= nil and not valuesEqual(value, savedValue)
	if draft ~= nil and not dirty then
		state.drafts[key] = nil
	end
	return {
		id = fieldID,
		categoryID = spec and spec.category or nil,
		value = value,
		savedValue = savedValue,
		dirty = dirty,
		available = dependency.available,
		enabled = dependency.enabled,
		dimmed = dependency.dimmed,
		disabledReason = dependency.reason,
		commitMode = spec and spec.commitMode or "immediate",
		reloadRequired = spec and spec.reloadRequired == true or false,
	}
end

local function validNewFeatureSpec(spec)
	return type(spec) == "table"
		and type(spec.featureID) == "string"
		and spec.featureID ~= ""
		and type(spec.revision) == "number"
		and spec.revision >= 1
		and spec.revision < math.huge
		and spec.revision == math.floor(spec.revision)
		and type(spec.introducedInVersion) == "string"
		and type(spec.hideAtVersion) == "string"
end

local function compareFeatureVersions(compare, left, right)
	local ok, result = pcall(compare, left, right)
	return ok and result or nil
end

local function isNewFeatureVersionEligible(spec)
	if not validNewFeatureSpec(spec) then
		return false
	end
	local service = GF.VersionDiscoveryService
	local compare = service and service.CompareFeatureVersions
	local getInstalledVersion = service and service.GetInstalledFeatureVersion
	if type(compare) ~= "function"
		or type(getInstalledVersion) ~= "function"
	then
		return false
	end
	local ok, currentVersion = pcall(getInstalledVersion)
	if not ok then
		return false
	end
	local windowOrder = compareFeatureVersions(
		compare, spec.introducedInVersion, spec.hideAtVersion)
	local fromStart = compareFeatureVersions(
		compare, currentVersion, spec.introducedInVersion)
	local beforeEnd = compareFeatureVersions(
		compare, currentVersion, spec.hideAtVersion)
	-- Version windows are half-open: [introducedInVersion, hideAtVersion).
	return windowOrder == -1
		and fromStart ~= nil and fromStart >= 0
		and beforeEnd ~= nil and beforeEnd < 0
end

function Presenter:ShouldShowNewFeature(spec)
	-- Keep the native badge visible for the entire declared release window.
	-- Setting interaction is intentionally not an acknowledgement signal.
	return isNewFeatureVersionEligible(spec)
end

function Presenter:StageValue(fieldID, value, context)
	local spec = FIELD_SPECS[fieldID]
	if not spec or not self:ProjectDependency(fieldID, context).enabled then
		return false, self:ProjectField(fieldID, context)
	end
	local key = fieldInstanceKey(fieldID, context)
	local savedValue = self:ReadValue(fieldID, context)
	if valuesEqual(value, savedValue) then
		state.drafts[key] = nil
	else
		state.drafts[key] = {
			fieldID = fieldID,
			value = value,
		}
	end
	return true, self:ProjectField(fieldID, context)
end

function Presenter:DiscardDraft(fieldID, context)
	state.drafts[fieldInstanceKey(fieldID, context)] = nil
	return self:ProjectField(fieldID, context)
end

function Presenter:DiscardCategoryDrafts(categoryID)
	local discarded = 0
	for key, draft in pairs(state.drafts) do
		local spec = draft and FIELD_SPECS[draft.fieldID]
		if spec and spec.category == categoryID then
			state.drafts[key] = nil
			discarded = discarded + 1
		end
	end
	return discarded
end

function Presenter:IsDirty(fieldID, context)
	return self:ProjectField(fieldID, context).dirty == true
end

function Presenter:GetRefreshPlan(fieldID)
	local spec = FIELD_SPECS[fieldID]
	return copySequence(spec and spec.refresh or {})
end

local REFRESH_STEPS = {
	["interface-locale"] = function()
		invoke(GF.MainFrame, "RefreshLocale")
		invoke(GF.InstanceGatewayOverlay, "Apply")
	end,
	["blocklist-visibility"] = function()
		invoke(GF.BlocklistPanel, "ApplyModuleVisibility")
	end,
	["float-visibility"] = function()
		invoke(GF.FloatButton, "Apply")
	end,
	["instance-gateway"] = function()
		invoke(GF.InstanceGatewayService, "Refresh", "settings")
		invoke(GF.InstanceGatewayOverlay, "Apply")
	end,
	["float-drag-lock"] = function()
		local button = GF.FloatButton
		if button and button.ApplyDragLock then
			button:ApplyDragLock()
		else
			invoke(button, "Apply")
		end
	end,
	minimap = function()
		invoke(GF.MinimapButton, "Apply")
	end,
	["premade-hook"] = function()
		invoke(GF.Hook, "Refresh")
	end,
	["workspace-tab-position"] = function()
		if GF.ApplyWorkspaceTabPosition then
			GF.ApplyWorkspaceTabPosition()
		end
	end,
	["floating-scale"] = function()
		local button = GF.FloatButton
		if button and button.ApplyScale then
			button:ApplyScale()
		else
			invoke(button, "Apply")
		end
	end,
	["font-appearance"] = function()
		invoke(GF.Font, "RefreshAll")
		invoke(GF.ListColumns, "InvalidateCache")
		invoke(GF.NavTree, "ScheduleLayoutRows")
		invoke(GF.FindGroupTab, "Relayout", { force = true })
		invoke(GF.ApplicantsPanel, "Relayout", { force = true })
	end,
	["frame-strata"] = function(value)
		if GF.ApplyFrameStrata then
			GF.ApplyFrameStrata(value)
		end
	end,
	["panel-skin"] = function(value)
		if GF.ApplyPanelSkin then
			GF.ApplyPanelSkin(value)
		end
	end,
	["panel-scale"] = function()
		if GF.ApplyPanelScale then
			GF.ApplyPanelScale()
		end
	end,
	["leader-realm"] = function()
		invoke(GF.FindGroupTab, "RefreshResults")
		invoke(GF.ApplicantsPanel, "Refresh", { preserveScroll = true })
		invoke(GF.MythicPlusWorkspace, "QueueRefreshCurrent", "showLeaderRealm")
	end,
	["game-type"] = function()
		invoke(GF.FindGroupTab, "RefreshResults", { preserveScroll = true })
	end,
	["member-display"] = function()
		invoke(GF.FindGroupTab, "RefreshResults", { preserveScroll = true })
	end,
	["expired-groups"] = function(value)
		invoke(GF.FindGroupTab, "ApplyExpiredGroupMode", value)
	end,
	["list-background"] = function()
		if GF.ApplyListBackgroundStyles then
			GF.ApplyListBackgroundStyles()
		elseif GF.ApplyListBackgroundAlpha then
			GF.ApplyListBackgroundAlpha()
		end
	end,
	["applicant-sound-preview"] = function(value)
		invoke(GF.ApplicantAlertService, "Preview", value)
	end,
	["default-item-level"] = function()
		invoke(GF.CreatePanel, "ApplyDefaultRequiredItemLevel", false)
	end,
	["invite-controls"] = function()
		invoke(GF.ApplicantsPanel, "UpdateInviteState")
	end,
	["browse-options"] = function()
		invoke(GF.SubtitleBar, "RefreshBrowseOptionToggles")
	end,
	["auto-accept"] = function(value)
		if value == true then
			invoke(GF.Apply, "QueueAutoAcceptInvite")
			invoke(GF.Apply, "QueueAutoConfirmLfgListRoleCheck")
		end
	end,
	["application-note"] = function(value)
		if value ~= true then
			invoke(GF.Apply, "ClearApplyNoteState")
		end
	end,
	["teleport-prompt-mode"] = function()
		Presenter:RefreshView({ categoryID = "notifications" })
	end,
	blacklist = function()
		invoke(GF.Blocklist, "RebuildMaps")
		invoke(GF.BlocklistPanel, "ApplyModuleVisibility")
		invoke(GF.FindGroupTab, "RefreshResults")
	end,
	["netease-identity"] = function()
		invoke(GF.NetEaseIdentityService, "OnPlayerLogin")
		invoke(GF.FindGroupTab, "RefreshResults", { preserveScroll = true })
		invoke(GF.ApplicantsPanel, "Refresh", { preserveScroll = true })
		invoke(GF.FilterPanel, "RebuildIfNeeded", true)
		invoke(GF.SubtitleBar, "RefreshBrowseOptionToggles")
	end,
}

function Presenter:RunRefreshPlan(fieldID, value, context)
	local plan = self:GetRefreshPlan(fieldID)
	for index = 1, #plan do
		local step = REFRESH_STEPS[plan[index]]
		if step then
			step(value, context)
		end
	end
	return plan
end

function Presenter:InitializeView()
	local plan = { "blocklist-visibility" }
	for index = 1, #plan do
		local step = REFRESH_STEPS[plan[index]]
		if step then
			step()
		end
	end
	return plan
end

function Presenter:SetValue(fieldID, value, context, options)
	local spec = FIELD_SPECS[fieldID]
	local dependency = self:ProjectDependency(fieldID, context)
	if not spec or type(spec.write) ~= "function" or not dependency.enabled then
		return false, self:ProjectField(fieldID, context), false
	end
	local before = self:ReadValue(fieldID, context)
	local ok, written = pcall(spec.write, value, context)
	if not ok or written == nil then
		return false, self:ProjectField(fieldID, context), false
	end
	state.drafts[fieldInstanceKey(fieldID, context)] = nil
	local after = self:ReadValue(fieldID, context)
	if after == nil then
		after = written
	end
	if not (options and options.skipRefresh) then
		self:RunRefreshPlan(fieldID, after, context)
	end
	return not valuesEqual(before, after),
		self:ProjectField(fieldID, context), true
end

function Presenter:ApplyField(fieldID, context)
	local projection = self:ProjectField(fieldID, context)
	if not projection.dirty then
		return true, projection
	end
	local _, updated, committed = self:SetValue(
		fieldID, projection.value, context)
	return committed == true and not updated.dirty, updated
end

function Presenter:ProjectReloadHint(fieldID, context, locale)
	local projection = self:ProjectField(fieldID, context)
	local required = projection.dirty and projection.reloadRequired
	local text
	if required then
		locale = type(locale) == "table" and locale or GF.L or {}
		text = locale.SET_RELOAD_REQUIRED
			or "Reload the UI to finish applying this change."
	end
	return {
		required = required,
		text = text,
		fieldID = fieldID,
	}
end

function Presenter:GetOptions(fieldID, locale)
	local factory = OPTION_FACTORIES[fieldID]
	return factory and factory(locale or GF.L or {}) or {}
end

function Presenter:ProjectOptionField(fieldID, locale)
	local projection = self:ProjectField(fieldID)
	local options = self:GetOptions(fieldID, locale)
	local label
	for index = 1, #options do
		if options[index].value == projection.value then
			label = options[index].label
			break
		end
	end
	if not label and fieldID == "fontKey" and GF.GetLSMFontNameFromKey then
		label = GF.GetLSMFontNameFromKey(readRoot("fontKey") or "")
	end
	projection.options = options
	projection.label = label or tostring(projection.value or "")
	return projection
end

function Presenter:ProjectAction(actionID)
	local spec = ACTION_SPECS[actionID]
	local available = spec ~= nil
	if available and type(spec.available) == "function" then
		local ok, resolved = pcall(spec.available)
		available = ok and resolved == true
	end
	return {
		id = actionID,
		available = available,
		enabled = available,
		dimmed = not available,
		disabledReason = available and nil or "dependency-unavailable",
	}
end

function Presenter:InvokeAction(actionID, ...)
	local spec = ACTION_SPECS[actionID]
	if not spec or not self:ProjectAction(actionID).available then
		return false, "unavailable"
	end
	return spec.run(...)
end

function Presenter:GetListBackgroundStyle(styleKey)
	return self:ReadValue("listBackgroundStyle", { styleKey = styleKey })
end

function Presenter:SetListBackgroundStyle(styleKey, style)
	return self:SetValue(
		"listBackgroundStyle", style, { styleKey = styleKey })
end

function Presenter:ResetListBackgroundColor(styleKey)
	local defaults = Schema:GetListBackgroundStyleDefaults(styleKey)
	return self:SetListBackgroundStyle(styleKey, {
		r = defaults.r,
		g = defaults.g,
		b = defaults.b,
	})
end

function Presenter:RegisterRefresher(callback, options)
	if type(callback) ~= "function" then
		return nil
	end
	state.nextRefresherID = state.nextRefresherID + 1
	local token = state.nextRefresherID
	state.refreshers[token] = {
		callback = callback,
		fieldID = options and options.fieldID or nil,
		categoryID = options and options.categoryID or nil,
	}
	state.refresherOrder[#state.refresherOrder + 1] = token
	return token
end

function Presenter:UnregisterRefresher(token)
	if state.refreshers[token] == nil then
		return false
	end
	state.refreshers[token] = nil
	return true
end

function Presenter:PlanViewRefresh(request)
	request = request or {}
	local plan = {}
	for index = 1, #state.refresherOrder do
		local token = state.refresherOrder[index]
		local entry = state.refreshers[token]
		if entry
			and (request.fieldID == nil or entry.fieldID == nil
				or entry.fieldID == request.fieldID)
			and (request.categoryID == nil or entry.categoryID == nil
				or entry.categoryID == request.categoryID)
		then
			plan[#plan + 1] = entry.callback
		end
	end
	return plan
end

function Presenter:RefreshView(request)
	local plan = self:PlanViewRefresh(request)
	for index = 1, #plan do
		plan[index](request or {})
	end
	return #plan
end

local function syncNotificationServicesFromRepository()
	local db = database()
	local settings = db and Schema:NormalizeMythicPlus(db)
	settings = settings and settings.settings or {}
	local announcement = announcementService()
	if announcement then
		writeService(
			announcement,
			"SetTeleportFollowEnabled",
			settings.teleportFollowEnabled == true
		)
		writeService(
			announcement,
			"SetTeleportAnnouncementEnabled",
			settings.teleportAnnouncementEnabled == true
		)
		writeService(
			announcement,
			"SetKeystoneAnnouncementEnabled",
			settings.keystoneAnnouncementEnabled == true
		)
		writeService(announcement, "SetTeleportMessage", "")
	end
	local rotation = rotationService("SetEnabled")
	if rotation then
		writeService(
			rotation,
			"SetEnabled",
			settings.keystoneRotationReminderEnabled == true
		)
	end
	local readyTeleport = groupReadyTeleportService("SetEnabled")
	if readyTeleport then
		writeService(
			readyTeleport,
			"SetEnabled",
			settings.groupReadyTeleportEnabled == true)
	end
end

function Presenter:ResetTacticalAnnouncements(challengeModeIDs)
	local resetCount = 0
	for _, challengeModeID in ipairs(challengeModeIDs or {}) do
		local context = { challengeModeID = challengeModeID }
		local _, _, committed = self:SetValue(
			"tacticalAnnouncement", "", context, { skipRefresh = true })
		if committed then
			resetCount = resetCount + 1
		end
		self:DiscardDraft("tacticalAnnouncement", context)
	end
	state.tactical.pendingChallengeModeID = nil
	return resetCount
end

function Presenter:ResetCategory(categoryID, options)
	categoryID = self:ResolveCategory(categoryID)
	if not categoryID then
		return false
	end
	options = options or {}
	local restored
	if categoryID == "tactical" then
		local ids = options.challengeModeIDs or {}
		self:ResetTacticalAnnouncements(ids)
		restored = true
	else
		local _, ok
		if type(GF.ResetSettingsCategory) == "function" then
			_, ok = GF.ResetSettingsCategory(categoryID)
		else
			_, ok = Repository:ResetCategory(categoryID)
		end
		restored = ok == true
	end
	if not restored then
		return false
	end
	self:DiscardCategoryDrafts(categoryID)
	if categoryID == "notifications" then
		syncNotificationServicesFromRepository()
	elseif categoryID == "party_list" then
		invoke(GF.ApplicantsPanel, "Refresh", { preserveScroll = true })
	elseif categoryID == "find_group" then
		invoke(GF.Apply, "ClearApplyNoteState")
		if readRoot("autoAcceptInvite") == true then
			invoke(GF.Apply, "QueueAutoAcceptInvite")
			invoke(GF.Apply, "QueueAutoConfirmLfgListRoleCheck")
		end
		invoke(GF.Blocklist, "RebuildMaps")
		invoke(GF.SubtitleBar, "RefreshBrowseOptionToggles")
	end
	if GF.ApplyAllSettings then
		GF.ApplyAllSettings()
	end
	self:RefreshView({ categoryID = categoryID, reason = "category-reset" })
	return true
end

function Presenter:FormatResetConfirmation(categoryID, locale)
	locale = type(locale) == "table" and locale or GF.L or {}
	local definition = self:GetCategoryInfo(categoryID, locale)
	local title = definition and definition.title or tostring(categoryID or "")
	local template
	if categoryID == "tactical" then
		template = locale.SET_RESET_TACTICAL_CONFIRM
			or "Reset seasonal notices and draft? Other settings unchanged."
	else
		template = locale.SET_RESET_CATEGORY_CONFIRM
			or "Reset \"%s\" to defaults? Other categories unchanged."
	end
	local ok, text = pcall(string.format, template, title)
	return ok and text or template
end

function Presenter:PlanTacticalSelection(currentID, nextID, currentText)
	currentID = tonumber(currentID)
	nextID = tonumber(nextID)
	if not nextID or nextID == currentID
		or state.tactical.pendingChallengeModeID ~= nil
	then
		return { action = "ignore" }
	end
	if currentID then
		self:StageValue(
			"tacticalAnnouncement",
			tostring(currentText or ""),
			{ challengeModeID = currentID }
		)
	end
	if not currentID or not self:IsDirty(
		"tacticalAnnouncement", { challengeModeID = currentID })
	then
		return { action = "select", challengeModeID = nextID }
	end
	state.tactical.pendingChallengeModeID = nextID
	return { action = "prompt", challengeModeID = nextID }
end

function Presenter:ResolveTacticalSelectionPrompt(action, currentID)
	local nextID = state.tactical.pendingChallengeModeID
	if not nextID then
		return { action = "ignore" }
	end
	local context = { challengeModeID = tonumber(currentID) }
	if action == "save" then
		local ok = self:ApplyField("tacticalAnnouncement", context)
		if not ok then
			state.tactical.pendingChallengeModeID = nil
			return { action = "failed" }
		end
	elseif action == "discard" then
		self:DiscardDraft("tacticalAnnouncement", context)
	else
		state.tactical.pendingChallengeModeID = nil
		return { action = "cancel" }
	end
	state.tactical.pendingChallengeModeID = nil
	return { action = "select", challengeModeID = nextID }
end

function Presenter:ResetRuntimeState()
	state.selectedCategoryID = CATEGORY_IDS[1]
	state.categoryScrollOffsets = {}
	state.drafts = {}
	state.tactical = {}
	return true
end
