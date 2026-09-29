local _, GF = ...

-- 大秘境页面共享的视觉组件与名册布局工具。
GF.MythicPlusUI = GF.MythicPlusUI or {}
local UI = GF.MythicPlusUI
local ServiceUtil = GF.MythicPlusServiceUtil

UI.ART_ROOT = GF.ADDON_ART_UI_PATH
UI.FRAME_ATLASES = GF.MYTHIC_PLUS_FRAME_ATLASES
UI.FRAME_CAP_SOURCE_RATIO = 30 / 344
UI.FRAME_CAP_DISPLAY_WIDTH = 15
UI.LABEL_CAP_SOURCE_RATIO = 30 / 695

UI.TELEPORT_VISUALS = {
	ready = {
		r = 1,
		g = 1,
		b = 1,
		vertexAlpha = 0.92,
		alpha = 1,
		desaturated = false,
	},
	cooldown = {
		r = 0.45,
		g = 0.45,
		b = 0.45,
		vertexAlpha = 0.85,
		alpha = 0.82,
		desaturated = true,
	},
	not_learned = {
		r = 0.45,
		g = 0.45,
		b = 0.45,
		vertexAlpha = 0.72,
		alpha = 0.72,
		desaturated = true,
	},
	unavailable = {
		r = 0.52,
		g = 0.52,
		b = 0.52,
		vertexAlpha = 0.55,
		alpha = 0.45,
		desaturated = true,
	},
	combat_locked = {
		r = 0.5,
		g = 0.5,
		b = 0.5,
		vertexAlpha = 0.68,
		alpha = 0.62,
		desaturated = true,
	},
	fallback = {
		r = 1,
		g = 1,
		b = 1,
		vertexAlpha = 0.55,
		alpha = 0.7,
		desaturated = true,
	},
	pressed = {
		r = 0.78,
		g = 0.78,
		b = 0.78,
		vertexAlpha = 0.95,
		alpha = 1,
		desaturated = false,
	},
	profiles = {
		default = {
			size = 18,
			offsetX = 0,
			offsetY = 0,
			pressedOffsetX = 1,
			pressedOffsetY = -1,
		},
		roster = {},
		character = {
			size = 16,
			-- MagePortalAlliance: visible bounds [3,27) x [4,27) in 32x32.
			-- Center those bounds, preserving the complete atlas and its shadow.
			offsetX = (0.5 - 15 / 32) * 16,
			offsetY = (15.5 / 32 - 0.5) * 16,
			pressedVisual = {
				r = 1,
				g = 1,
				b = 1,
				vertexAlpha = 0.92,
				alpha = 1,
				desaturated = false,
			},
			visuals = {
				unavailable = {
					r = 1,
					g = 1,
					b = 1,
					vertexAlpha = 0.55,
					alpha = 0.45,
					desaturated = true,
				},
			},
		},
		dungeon = {
			size = 22,
			pressedOffsetX = 2,
			pressedOffsetY = -2,
			visuals = {
				ready = {
					r = 1,
					g = 1,
					b = 1,
					vertexAlpha = 0.95,
					alpha = 1,
					desaturated = false,
				},
				unavailable = {
					r = 0.45,
					g = 0.45,
					b = 0.45,
					vertexAlpha = 0.72,
					alpha = 0.72,
					desaturated = true,
				},
			},
		},
	},
}

local teleportCombatVisuals = setmetatable({}, { __mode = "k" })
local teleportCombatEventFrame

function UI.IsTeleportCombatLocked()
	local service = GF.MythicPlusTeleportService
	if service and service.IsCombatLocked then
		return service:IsCombatLocked()
	end
	return InCombatLockdown and InCombatLockdown() or false
end

function UI.GetTeleportCombatMessage()
	return (GF.L and GF.L.MPLUS_TELEPORT_COMBAT_LOCKED)
		or ERR_NOT_IN_COMBAT
		or "战斗中无法传送"
end

function UI.NotifyTeleportCombatLocked()
	local message = UI.GetTeleportCombatMessage()
	if type(GF.ShowWarningMessage) == "function" then
		GF.ShowWarningMessage(message)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(message, 1, 0.82, 0, 1)
	end
end

local function refreshTeleportCombatVisuals()
	for button, refreshVisual in pairs(teleportCombatVisuals) do
		if type(refreshVisual) == "function" then
			refreshVisual(button)
		end
		if GameTooltip and GameTooltip.GetOwner
			and GameTooltip:GetOwner() == button
			and button.GetScript
		then
			local onEnter = button:GetScript("OnEnter")
			if onEnter then
				onEnter(button)
			end
		end
	end
end

function UI.InstallTeleportCombatFeedback(button, refreshVisual)
	if not button then
		return
	end
	teleportCombatVisuals[button] = refreshVisual or true
	if not teleportCombatEventFrame then
		teleportCombatEventFrame = CreateFrame("Frame")
		teleportCombatEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		teleportCombatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		teleportCombatEventFrame:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_REGEN_ENABLED"
				and C_Timer and C_Timer.After
			then
				C_Timer.After(0, refreshTeleportCombatVisuals)
			else
				refreshTeleportCombatVisuals()
			end
		end)
	end
	if not button._gfTeleportCombatFeedbackInstalled then
		button._gfTeleportCombatFeedbackInstalled = true
		button:HookScript("PreClick", function(self, mouseButton, down)
			if mouseButton == "LeftButton"
				and down == true
				and self.gfTeleportDesiredReady == true
				and UI.IsTeleportCombatLocked()
			then
				UI.NotifyTeleportCombatLocked()
			end
		end)
	end
	if type(refreshVisual) == "function" then
		refreshVisual(button)
	end
end

function UI.ApplyTeleportIconVisual(icon, state, options)
	if not icon then
		return
	end
	options = options or {}
	local visualKey = UI.TELEPORT_VISUALS[state] and state or "fallback"
	local combatLocked = UI.IsTeleportCombatLocked()
	if combatLocked and visualKey == "ready" then
		visualKey = "combat_locked"
	end
	local pressed = options.pressed == true and not combatLocked
	local profiles = UI.TELEPORT_VISUALS.profiles
	local baseProfile = profiles.default
	local profile = type(options.profile) == "table"
		and options.profile
		or profiles[options.profile or "default"]
		or baseProfile
	local profileOverride = options.profileOverride
	local function profileValue(key)
		if type(profileOverride) == "table" and profileOverride[key] ~= nil then
			return profileOverride[key]
		end
		if profile[key] ~= nil then
			return profile[key]
		end
		return baseProfile[key]
	end

	local profileVisuals = profile.visuals
	local visual = type(profileVisuals) == "table" and profileVisuals[visualKey]
		or UI.TELEPORT_VISUALS[visualKey]
	if pressed then
		visualKey = "pressed"
		visual = options.pressedVisual
			or profile.pressedVisual
			or UI.TELEPORT_VISUALS.pressed
	end
	local visualOverride = options.visualOverride
	local function visualValue(key)
		if type(visualOverride) == "table" and visualOverride[key] ~= nil then
			return visualOverride[key]
		end
		return visual[key]
	end

	if icon.SetDesaturated then
		icon:SetDesaturated(visualValue("desaturated") == true)
	end
	icon:SetVertexColor(
		visualValue("r") or 1,
		visualValue("g") or 1,
		visualValue("b") or 1,
		visualValue("vertexAlpha") or 1)
	icon:SetAlpha(visualValue("alpha") or 1)

	local scale = tonumber(options.scale) or 1
	local size = tonumber(options.size) or tonumber(profileValue("size"))
	if size and options.applySize ~= false then
		local scaledSize = size * scale
		if options.roundSize then
			scaledSize = math.max(1, math.floor(scaledSize + 0.5))
		end
		icon:SetSize(scaledSize, scaledSize)
	end
	if options.anchor then
		local offsetX = (tonumber(options.anchorOffsetX) or 0)
			+ (tonumber(profileValue("offsetX")) or 0)
		local offsetY = (tonumber(options.anchorOffsetY) or 0)
			+ (tonumber(profileValue("offsetY")) or 0)
		if pressed then
			offsetX = offsetX + (tonumber(profileValue("pressedOffsetX")) or 0)
			offsetY = offsetY + (tonumber(profileValue("pressedOffsetY")) or 0)
		end
		local point = options.point or "CENTER"
		icon:ClearAllPoints()
		icon:SetPoint(
			point,
			options.anchor,
			options.relativePoint or point,
			offsetX * scale,
			offsetY * scale)
	end
	return visualKey
end

UI.ROSTER_ROW_HEIGHT = GF.LIST_ROW_STYLE.height
UI.ROSTER_HEADER_HEIGHT = GF.TABLE_HEADER_STYLE.height or 26
UI.ROSTER_LIST_WIDTH = 898
UI.ROSTER_ROWS_PADDING_X = GF.TABLE_HEADER_STYLE.contentInsetX or 4
-- Only the left edge retains the shared text inset. The right edge is filled
-- until actual overflow asks the dynamic scrollbar to reveal its gutter.
UI.ROSTER_ROWS_PADDING_RIGHT = GF.MYTHIC_PLUS_CARPOOL_SPLIT_STYLE.rowInsetRight
UI.ROSTER_HEADER_INSET_LEFT =
	GF.TABLE_HEADER_STYLE.panelInsetLeft or 5
UI.ROSTER_HEADER_INSET_RIGHT =
	GF.TABLE_HEADER_STYLE.panelInsetRight or 5
UI.ROSTER_HEADER_INSET_TOP =
	GF.TABLE_HEADER_STYLE.panelInsetTop or 22
UI.ROSTER_HEADER_CONTENT_OFFSET_Y = GF.TABLE_HEADER_STYLE.contentOffsetY or 4
UI.ROSTER_COLUMNS = {
	{ key = "name", labelKey = "MPLUS_COL_CHARACTER", width = 200, sortable = true },
	{ key = "armor", labelKey = "MPLUS_COL_ARMOR", width = 96, sortable = true },
	{ key = "key", labelKey = "MPLUS_COL_KEYSTONE", width = 211, sortable = true },
	{ key = "rating", labelKey = "MPLUS_COL_RATING", width = 96, sortable = true },
	{ key = "roles", labelKey = "MPLUS_COL_ROLE", width = 120, sortable = true },
	{ key = "teleport", labelKey = "MPLUS_COL_TELEPORT", width = 72 },
	{ key = "last", labelKey = "MPLUS_COL_QUICK_ACTION", width = 95 },
}

local ROSTER_CHARACTER_ICON_INSET_LEFT = 6
local ROSTER_CHARACTER_ICON_GAP_RIGHT = 6
local ROSTER_LEADER_ICON_ATLAS = "UI-HUD-UnitFrame-Player-Group-LeaderIcon"
local ROSTER_LEADER_ICON_OFFSET_Y = 1

local ARMOR_BY_CLASS = {
	DEATHKNIGHT = "PLATE",
	DEMONHUNTER = "LEATHER",
	DRUID = "LEATHER",
	EVOKER = "MAIL",
	HUNTER = "MAIL",
	MAGE = "CLOTH",
	MONK = "LEATHER",
	PALADIN = "PLATE",
	PRIEST = "CLOTH",
	ROGUE = "LEATHER",
	SHAMAN = "MAIL",
	WARLOCK = "CLOTH",
	WARRIOR = "PLATE",
}

local function getRosterClassIconSize()
	return (GF.GetBrowseMemberIconSize and GF.GetBrowseMemberIconSize())
		or GF.LIST_ROW_STYLE.memberIconSize
end

function UI.AnchorWorkspaceScrollBar(scrollBar, owner)
	if not (scrollBar and owner) then
		return
	end
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint(
		"TOPRIGHT",
		owner,
		"TOPRIGHT",
		GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_OFFSET_X,
		GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_TOP_OFFSET)
	scrollBar:SetPoint(
		"BOTTOMRIGHT",
		owner,
		"BOTTOMRIGHT",
		GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_OFFSET_X,
		GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_BOTTOM_OFFSET)
	scrollBar:SetWidth(GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_WIDTH)
	if scrollBar.SetHideIfUnscrollable then
		scrollBar:SetHideIfUnscrollable(true)
	end
end

local function createFontString(parent, template)
	local text = GF.UI.CreateFontString(parent, "OVERLAY", template or "GameFontHighlight")
	text:SetWordWrap(false)
	text:SetJustifyV("MIDDLE")
	return text
end

function UI.GetClassColor(classFile, fallbackR, fallbackG, fallbackB)
	classFile = type(classFile) == "string" and classFile:upper() or classFile
	local classColors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	local color = classFile and classColors and classColors[classFile]
	if color then
		return color.r, color.g, color.b
	end
	return fallbackR or 1, fallbackG or 0.82, fallbackB or 0
end

function UI.GetRoleAtlas(role)
	local normalized = ServiceUtil.NormalizeRole(role)
	if normalized == "HEAL" then
		return GF.ROLE_ICON_ATLAS.HEALER
	end
	if normalized == "DPS" then
		return GF.ROLE_ICON_ATLAS.DAMAGER
	end
	return normalized and GF.ROLE_ICON_ATLAS[normalized] or nil
end

function UI.GetArmorLabel(classFile)
	local armor = ARMOR_BY_CLASS[classFile]
	if not armor then
		return "-"
	end
	return (GF.L and GF.L["MPLUS_ARMOR_" .. armor]) or armor
end

local function colorByte(value)
	value = math.max(0, math.min(1, tonumber(value) or 0))
	return math.floor((value * 255) + 0.5)
end

function UI.ColorToARGBHex(color, fallback)
	if type(color) ~= "table" then
		return fallback or "ffffffff"
	end
	if type(color.colorStr) == "string" and color.colorStr ~= "" then
		local value = color.colorStr:gsub("^|c", ""):gsub("|r$", "")
		if #value == 6 then
			value = "ff" .. value
		end
		if #value >= 8 then
			return value:sub(1, 8)
		end
	end
	return string.format(
		"ff%02x%02x%02x",
		colorByte(color.r),
		colorByte(color.g),
		colorByte(color.b))
end

function UI.ColorText(text, color)
	return string.format(
		"|c%s%s|r",
		color or "ffffffff",
		tostring(text or ""))
end

function UI.GetClassColorCode(classFile, fallback)
	classFile = type(classFile) == "string" and classFile:upper() or classFile
	local classColors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	return UI.ColorToARGBHex(
		classFile and classColors and classColors[classFile],
		fallback or "ffffd100")
end

function UI.GetCharacterFullName(data)
	if type(data and data.fullName) == "string" and data.fullName ~= "" then
		return data.fullName
	end
	local name = data and (data.name or data.key)
	if type(name) ~= "string" or name == "" then
		return "-"
	end
	if name:find("-", 1, true) or not (data.realm and data.realm ~= "") then
		return name
	end
	return name .. "-" .. data.realm
end

local function getRosterCharacterIcon(data)
	local classValue = data and (data.classFile or data.classFilename or data.class)
	local cachedSpecIcon = data and data.specIcon
	local cachedSpecIconNumber = tonumber(cachedSpecIcon)
	if cachedSpecIcon
		and cachedSpecIcon ~= ""
		and (not cachedSpecIconNumber or cachedSpecIconNumber > 0)
	then
		return cachedSpecIcon, classValue
	end
	if GF.UI and GF.UI.ResolveClassIcon then
		return GF.UI.ResolveClassIcon(classValue)
	end
	return nil, classValue
end

function UI.FormatKey(data, includeDungeon)
	local level = tonumber(data and (data.keyLevel or data.level))
	if not level or level <= 0 then
		return "-"
	end
	if includeDungeon == false then
		return "+" .. tostring(level)
	end
	local dungeonName = data and data.dungeonName
	if type(dungeonName) ~= "string" or dungeonName == "" then
		dungeonName = "-"
	end
	return string.format(
		(GF.L and GF.L.MPLUS_KEYSTONE_FORMAT) or "钥石：%s (%d)",
		dungeonName,
		level)
end

function UI.FormatRating(value, state)
	value = tonumber(value)
	if value then
		return tostring(math.floor(value + 0.5))
	end
	if state == "failed" then
		return (GF.L and GF.L.MPLUS_QUERY_FAILED) or "查询失败"
	end
	if state == "pending" then
		return (GF.L and GF.L.MPLUS_QUERYING) or "查询中"
	end
	return "-"
end

function UI.UpdateMythicPlusButtonSkin(button)
	if GF.UI and GF.UI.RefreshCommonPanelButtonSkin then
		GF.UI.RefreshCommonPanelButtonSkin(button)
	end
end

function UI.ApplyMythicPlusButtonSkin(button, options)
	if GF.UI and GF.UI.ApplyCommonPanelButtonSkin then
		GF.UI.ApplyCommonPanelButtonSkin(button, options)
	end
end

function UI.BindKeystoneLinkButton(button, options)
	if not button then
		return
	end
	options = type(options) == "table" and options or {}
	button:RegisterForClicks("LeftButtonUp")
	button:SetScript("OnEnter", function(self)
		if options.onEnter then
			options.onEnter(self)
		end
		if self.keystoneLink then
			GameTooltip:SetOwner(self, options.tooltipAnchor or "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.keystoneLink)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		if options.onLeave then
			options.onLeave(self)
		end
		GameTooltip_Hide()
	end)
	button:SetScript("OnClick", function(self, mouseButton)
		if not self.keystoneLink then
			return
		end
		if HandleModifiedItemClick
			and HandleModifiedItemClick(self.keystoneLink)
		then
			return
		end
		if mouseButton == "LeftButton" and SetItemRef then
			SetItemRef(
				self.keystoneLink,
				self.keystoneLink,
				mouseButton,
				self)
		end
	end)
end

local ROSTER_COLUMN_ORIGIN_X = 2
local ROSTER_COLUMN_OVERLAP = 2

local function getRosterLayout(columns, totalWidth)
	totalWidth = math.max(1, math.floor(tonumber(totalWidth) or UI.ROSTER_LIST_WIDTH))
	local style = GF.MYTHIC_PLUS_CARPOOL_SPLIT_STYLE
	local blend = style and math.max(0, math.min(1,
		(style.compactWidth + style.compactBlendWidth - totalWidth) / style.compactBlendWidth)) or 0
	local compact = blend > 0
	local function columnWidth(column)
		local full = tonumber(column.width) or 1
		local narrow = tonumber(style and style.columnWidths[column.key]) or full
		return math.max(1, full + (narrow - full) * blend)
	end
	local baseWidth = 0
	for _, column in ipairs(columns) do
		baseWidth = baseWidth + columnWidth(column)
	end
	local contentWidth = math.max(#columns,
		totalWidth - ROSTER_COLUMN_ORIGIN_X - ROSTER_COLUMN_OVERLAP)
	local widths = {}
	local assigned = 0
	for index, column in ipairs(columns) do
		local width
		if index == #columns then
			width = math.max(1, contentWidth - assigned)
		else
			width = math.max(1,
				math.floor(contentWidth * (columnWidth(column) / baseWidth)))
			assigned = assigned + width
		end
		widths[column.key] = width
	end

	local active = {}
	local byId = {}
	local headerLayout = {}
	local x = ROSTER_COLUMN_ORIGIN_X
	for index, column in ipairs(columns) do
		local width = widths[column.key]
		active[index] = column.key
		byId[column.key] = {
			id = column.key,
			index = index,
			x = x,
			width = width,
		}
		headerLayout[index] = { width = width + ROSTER_COLUMN_OVERLAP }
		x = x + width
	end
	return {
		active = active,
		byId = byId,
		headerLayout = headerLayout,
		contentWidth = totalWidth,
		compact = compact,
		scale = baseWidth > 0 and (contentWidth / baseWidth) or 1,
	}
end

local function setRoleFrames(frames, data, availableWidth)
	local selected = {}
	if type(data.roles) == "table" then
		for role, enabled in pairs(data.roles) do
			if enabled then
				local normalizedRole = ServiceUtil.NormalizeRole(role)
				if normalizedRole then
					selected[normalizedRole] = true
				end
			end
		end
	else
		local normalizedRole = ServiceUtil.NormalizeRole(data.role)
		if normalizedRole then
			selected[normalizedRole] = true
		end
	end
	local visible = {}
	for _, role in ipairs(ServiceUtil.ROLE_ORDER) do
		if selected[role] and frames[role] then
			visible[#visible + 1] = frames[role]
		end
	end
	local gap = availableWidth and availableWidth < 62 and 2 or 4
	local baseSize = getRosterClassIconSize()
	local size = availableWidth and math.max(1, math.min(baseSize,
		math.floor((availableWidth - math.max(0, #visible - 1) * gap) / math.max(1, #visible)))) or baseSize
	local totalWidth = (#visible * size) + (math.max(0, #visible - 1) * gap)
	local x = -totalWidth / 2
	local inferred = data and data.roleInferred == true
		or data and data.roleSource == "specialization"
	for _, frame in pairs(frames) do
		frame:Hide()
		if frame.SetDesaturated then
			frame:SetDesaturated(inferred == true)
		end
		frame:SetVertexColor(1, 1, 1, inferred and 0.55 or 0.95)
		frame:SetAlpha(1)
	end
	for _, frame in ipairs(visible) do
		frame:ClearAllPoints()
		frame:SetSize(size, size)
		frame:SetPoint("LEFT", frame:GetParent(), "CENTER", x, 0)
		frame:Show()
		x = x + size + gap
	end
end

local function setFontSize(fontString, size)
	if not fontString then return end
	fontString._gfFontSizeOverride = size
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString)
		return
	end
	local path, _, flags = fontString:GetFont()
	if path then
		fontString:SetFont(path, size, flags or "")
	end
end

local function setRosterRowHover(row, shown)
	local widgets = row and row.Widgets
	if not widgets then
		return
	end
	row._gfRosterHoverShown = shown == true and not row._gfRosterRetiring
	if GF.UI and GF.UI.SetRowBackgroundPiecesShown then
		GF.UI.SetRowBackgroundPiecesShown(
			widgets.hoverPieces,
			row._gfRosterHoverShown)
		return
	end
	for _, piece in pairs(widgets.hoverPieces or {}) do
		piece:SetShown(row._gfRosterHoverShown)
	end
end

local function getRosterRowVisualState(page, data)
	if page and page.listKind == "carpool" then
		return data and (data.isOwnerCurrent == true
			or data.isLocalCurrent == true) and "normal" or "grey"
	end
	return data and data.connected == false and "grey" or "normal"
end

local function applyRosterRowAtlas(row, pieces, state, usage)
	if not (row and pieces and GF.UI and GF.UI.ApplyRowBackgroundPieces) then
		return false
	end
	local page = row._gfMPlusRosterPage
	local fixedCarpoolCurrent = state == "normal"
		and page
		and page.listKind == "carpool"
	local options = {
		state = state,
		mode = "full",
		profile = GF.LIST_ROW_STYLE.background,
		fallbackTexture = GF.ROW_BACKGROUND_FALLBACK_TEXTURE,
		defaultHeight = UI.ROSTER_ROW_HEIGHT,
	}
	if usage == "hover" then
		options.alpha = GF.BROWSE_ROW_SELECTED_ALPHA or 1
		options.desaturated = true
		if fixedCarpoolCurrent then
			options.vertexColor = GF.BROWSE_ROW_HOVER_COLOR
				or { 1, 0.74, 0.18, 0.13 }
		else
			options.vertexColor = GF.GetListBackgroundOverlayColor
				and GF.GetListBackgroundOverlayColor(state, "hover")
				or (state == "grey"
					and GF.BROWSE_ROW_HOVER_GREY_COLOR
					or GF.BROWSE_ROW_HOVER_COLOR)
		end
	elseif fixedCarpoolCurrent then
		-- Do not pass a color or alpha here: this row must show the atlas's
		-- authored gold color at its native, fully opaque presentation.
		options.preserveAtlasColor = true
	else
		options.alpha = GF.GetListBackgroundAlpha
			and GF.GetListBackgroundAlpha(state)
			or (GF.BROWSE_ROW_BACKGROUND_ALPHA or 0.92)
	end
	return GF.UI.ApplyRowBackgroundPieces(row, pieces, options)
end

local function setRosterRowVisualState(row, state)
	local widgets = row and row.Widgets
	if not widgets then
		return
	end
	state = state or "normal"
	row._gfRosterBackgroundState = state
	applyRosterRowAtlas(row, widgets.backgroundPieces, state)
	applyRosterRowAtlas(row, widgets.hoverPieces, state, "hover")
	setRosterRowHover(row, row._gfRosterHoverShown)
end

local function getUnknownKeystoneText(page)
	local localeKey = page and page.unknownKeyTextKey
	if localeKey and GF.L and GF.L[localeKey] then
		return GF.L[localeKey]
	end
	return "-"
end

local function getRosterDisplayName(data)
	local db = GF.GetDB and GF.GetDB()
	local fullName = UI.GetCharacterFullName(data)
	if db and db.showLeaderRealm == true then
		return fullName
	end
	local name = data and data.name
	if type(name) ~= "string" or name == "" then
		name = fullName
	end
	if type(name) ~= "string" or name == "" then
		return "-"
	end
	local dashPos = name:find("-", 1, true)
	if dashPos then
		return name:sub(1, dashPos - 1)
	end
	return name
end

local function getRosterKeyState(data)
	if data and (data.keyState == "ready"
		or data.keyState == "empty"
		or data.keyState == "unknown")
	then
		return data.keyState
	end
	local keyLevel = tonumber(data and data.keyLevel)
	if keyLevel and keyLevel > 0 then
		return "ready"
	end
	if data and (data.keystoneKnown == true
		or (data.unit == nil and data.updatedAt ~= nil))
	then
		return "empty"
	end
	return "unknown"
end

local function getRosterKeystoneText(page, data, keyState)
	keyState = keyState or getRosterKeyState(data)
	if keyState == "empty" then
		return (GF.L and GF.L.MPLUS_NO_KEYSTONE) or "无钥石"
	end
	if keyState == "unknown" then
		return getUnknownKeystoneText(page)
	end
	local level = tonumber(data and (data.keyLevel or data.level))
	if not level or level <= 0 then
		return "-"
	end
	local dungeonName = data and data.dungeonName
	if type(dungeonName) ~= "string" or dungeonName == "" then
		dungeonName = "-"
	end
	local text = string.format("%s（%d）", dungeonName, level)
	local link = data and data.keystoneLink
	if type(link) == "string" then
		-- Relabel only the displayed copy, keeping the native color and the
		-- original link on the row data for tooltips, clicks and announcements.
		local displayLink, count = link:gsub("|h.-|h", function()
			return "|h" .. text .. "|h"
		end, 1)
		if count > 0 then
			return displayLink
		end
	end
	return text
end

local function formatRosterRunTime(durationMS)
	local duration = tonumber(durationMS) or 0
	if duration <= 0 then
		return ""
	end
	local totalSeconds = duration / 1000
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds - (minutes * 60)
	return string.format("%d:%04.1f", minutes, seconds)
end

local ROSTER_TOOLTIP_HEADER_GREEN = { 3 / 255, 1, 154 / 255 }
local ROSTER_TOOLTIP_DUNGEON_GOLD = { 1, 0.82, 0 }

local function getRosterBestRuns(data, ratingEntry)
	local bestRuns = data and data.bestRuns
	if type(bestRuns) == "table" and type(bestRuns.runs) == "table" then
		bestRuns = bestRuns.runs
	end
	if type(bestRuns) == "table" and #bestRuns > 0 then
		return bestRuns, true
	end
	if ratingEntry and type(ratingEntry.runs) == "table" and #ratingEntry.runs > 0 then
		return ratingEntry.runs, true
	end
	return {}, type(data and data.bestRuns) == "table"
		or (ratingEntry and ratingEntry.state == "ready"
			and type(ratingEntry.runs) == "table")
end

local function getRosterRunsByMapID(runs)
	local byMapID = {}
	for _, run in ipairs(runs or {}) do
		local mapID = tonumber(run and (run.mapID
			or run.challengeModeID
			or run.mapChallengeModeID))
		if mapID then
			byMapID[mapID] = run
		end
	end
	return byMapID
end

local function getRosterOverallScoreColor(data, ratingEntry, score)
	if data and data.ratingColor then
		return data.ratingColor
	end
	if ratingEntry and ratingEntry.scoreColor then
		return ratingEntry.scoreColor
	end
	if GF.MythicPlusRatingCache and GF.MythicPlusRatingCache.GetCachedScoreColor then
		local color = GF.MythicPlusRatingCache:GetCachedScoreColor(score)
		if color then
			return color
		end
	end
	if GF.Result and GF.Result.GetDungeonScoreColor then
		return GF.Result:GetDungeonScoreColor(score)
	end
end

local function getRosterSpecificScoreColor(run)
	local cache = GF.MythicPlusRatingCache
	local rules = GF.MYTHIC_PLUS_SCORE_COLOR_RULE or {}
	if cache and cache.GetScoreColor then
		local color = cache:GetScoreColor(
			run and run.score, rules.SINGLE_DUNGEON)
		if color then
			return color
		end
	end
	return run and run.scoreColor
end

local function addRosterBestRunsFallback(
	tooltip, dungeons, runsByMapID, bestRuns, hasCachedBestRuns)
	local L = GF.L or {}
	if #dungeons == 0 then
		tooltip:AddLine(
			L.MPLUS_TOOLTIP_SEASON_UNAVAILABLE or "无法加载当前赛季。",
			0.58, 0.58, 0.58, true)
		return
	end
	if not hasCachedBestRuns then
		tooltip:AddLine(L.MPLUS_NO_INFO or "无信息", 0.58, 0.58, 0.58)
		return
	end
	if #bestRuns == 0 then
		tooltip:AddLine(
			L.MPLUS_NO_BEST_RUNS or "本赛季暂无地下城通关记录。",
			0.58, 0.58, 0.58, true)
		return
	end

	tooltip:AddDoubleLine(
		L.MPLUS_COL_DUNGEON or "地下城",
		string.format("%s / %s / %s",
			L.MPLUS_COL_KEY_LEVEL or "层数",
			L.MPLUS_RUN_TIME or "用时",
			L.MPLUS_COL_RATING or "评分"),
		ROSTER_TOOLTIP_HEADER_GREEN[1],
		ROSTER_TOOLTIP_HEADER_GREEN[2],
		ROSTER_TOOLTIP_HEADER_GREEN[3],
		ROSTER_TOOLTIP_HEADER_GREEN[1],
		ROSTER_TOOLTIP_HEADER_GREEN[2],
		ROSTER_TOOLTIP_HEADER_GREEN[3])
	for _, dungeon in ipairs(dungeons) do
		local mapID = tonumber(dungeon and dungeon.challengeModeID)
		local run = mapID and runsByMapID[mapID] or nil
		local dungeonName = dungeon and dungeon.name
			or (L.MPLUS_UNKNOWN_DUNGEON or "未知地下城")
		local level = tonumber(run and run.level) or 0
		local timeText = formatRosterRunTime(run and run.durationMS)
		local runScore = tonumber(run and run.score) or 0
		if run and (level > 0 or runScore > 0 or timeText ~= "") then
			local timedColor = run.timed == true and "ff1eff00" or "ffff4040"
			local levelText = level > 0
				and UI.ColorText(
					tostring(math.floor(level + 0.5)), timedColor)
				or "-"
			local displayTime = timeText ~= ""
				and UI.ColorText(timeText, timedColor)
				or "-"
			local scoreText = "-"
			if runScore > 0 then
				scoreText = UI.ColorText(
					tostring(math.floor(runScore + 0.5)),
					UI.ColorToARGBHex(
						getRosterSpecificScoreColor(run), "ffffffff"))
			end
			tooltip:AddDoubleLine(
				dungeonName,
				string.format("%s / %s / %s",
					levelText,
					displayTime,
					scoreText),
				ROSTER_TOOLTIP_DUNGEON_GOLD[1],
				ROSTER_TOOLTIP_DUNGEON_GOLD[2],
				ROSTER_TOOLTIP_DUNGEON_GOLD[3],
				1, 1, 1)
		else
			tooltip:AddDoubleLine(
				dungeonName,
				L.MPLUS_TOOLTIP_NO_RECORD or "无记录",
				ROSTER_TOOLTIP_DUNGEON_GOLD[1],
				ROSTER_TOOLTIP_DUNGEON_GOLD[2],
				ROSTER_TOOLTIP_DUNGEON_GOLD[3],
				0.48, 0.48, 0.48)
		end
	end
end

local function prepareRosterRowTooltip(owner)
	if not (owner and GameTooltip) then
		return nil
	end
	if GF.UI and GF.UI.BeginGameTooltip then
		GF.UI.BeginGameTooltip(owner, "ANCHOR_RIGHT")
	else
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	end
	GameTooltip:ClearLines()
	return GameTooltip
end

local function showRosterRowTooltip(row, anchor)
	local data = row and row._gfData
	if not data or row._gfRosterRetiring then
		return
	end
	local page = row._gfMPlusRosterPage
	local isCarpool = page and page.listKind == "carpool"
	local isOffline = not isCarpool and data.connected == false
	local tooltipData = isOffline and data.tooltipSnapshot or data
	tooltipData = tooltipData or data
	local isRosterOnly = not isCarpool and tooltipData.isRosterOnly == true
	local isInteropFallback = not isCarpool
		and tooltipData.isInteropFallback == true
	local hasChatKeystoneLink = not isCarpool
		and tooltipData.keystoneLinkSource == "group-chat-claim"
	local ratingEntry = not isOffline
		and tooltipData.key
		and GF.MythicPlusRatingCache
		and GF.MythicPlusRatingCache:GetByKey(tooltipData.key)
	local bestRuns, hasCachedBestRuns = getRosterBestRuns(
		tooltipData,
		ratingEntry)
	local runsByMapID = getRosterRunsByMapID(bestRuns)
	local rawScore = tonumber(tooltipData.rating)
		or tonumber(ratingEntry and ratingEntry.score)
	local hasScore = rawScore ~= nil
	local score = rawScore or 0
	local scoreColor = hasScore and score > 0
		and getRosterOverallScoreColor(tooltipData, ratingEntry, score)
		or nil
	local scoreR = tonumber(scoreColor and scoreColor.r) or 0.47
	local scoreG = tonumber(scoreColor and scoreColor.g) or 0.47
	local scoreB = tonumber(scoreColor and scoreColor.b) or 0.47
	local scoreText = hasScore
		and tostring(math.floor(score + 0.5))
		or ((GF.L and GF.L.MPLUS_NO_INFO) or "无信息")
	local classFile = tooltipData.classFile
		or tooltipData.classFilename
		or tooltipData.class
	local specText = type(tooltipData.specName) == "string"
		and tooltipData.specName ~= ""
		and tooltipData.specName
		or ((GF.L and GF.L.MPLUS_TOOLTIP_UNKNOWN) or "未知")

	local tooltip = prepareRosterRowTooltip(anchor or row)
	if not tooltip then
		return
	end
	local r, g, b = UI.GetClassColor(classFile)
	tooltip:AddLine(UI.GetCharacterFullName(data), r, g, b)
	if not isCarpool then
		local statusText = isOffline
			and ((GF.L and GF.L.MPLUS_OFFLINE) or "离线")
			or ((GF.L and GF.L.MPLUS_ONLINE) or "在线")
		tooltip:AddDoubleLine(
			(GF.L and GF.L.MPLUS_COL_STATUS) or "状态",
			UI.ColorText(statusText, isOffline and "ff888888" or "ff1eff00"),
			0.82, 0.82, 0.82, 1, 1, 1)
	end
	tooltip:AddDoubleLine(
		(GF.L and GF.L.MPLUS_TOOLTIP_CURRENT_KEYSTONE) or "当前钥石",
		getRosterKeystoneText(page, tooltipData),
		1, 1, 1, 1, 1, 1)
	tooltip:AddDoubleLine(
		(GF.L and GF.L.MPLUS_TOOLTIP_SEASON_RATING) or "赛季评分",
		scoreText,
		1, 1, 1, scoreR, scoreG, scoreB)
	tooltip:AddDoubleLine(
		(GF.L and GF.L.MPLUS_TOOLTIP_CURRENT_SPEC) or "当前专精",
		UI.ColorText(specText, UI.GetClassColorCode(classFile)),
		1, 1, 1, 1, 1, 1)

	if isInteropFallback then
		local template
		if hasChatKeystoneLink then
			template = GF.L
				and GF.L.MPLUS_TOOLTIP_INTEROP_CHAT_LINK_NOTE
		else
			template = (GF.L and GF.L.MPLUS_TOOLTIP_INTEROP_NOTE)
				or "钥石信息来自 %s 兼容协议，仅用于显示，未包含可发送的真实钥石链接。"
		end
		if type(template) == "string" and template ~= "" then
			local ok, note = pcall(
				string.format,
				template,
				tooltipData.interopLabel or "external")
			tooltip:AddLine(
				ok and note or template,
				0.58, 0.58, 0.58, true)
		end
	elseif hasChatKeystoneLink then
		local note = GF.L and GF.L.MPLUS_TOOLTIP_CHAT_LINK_NOTE
		if type(note) == "string" and note ~= "" then
			tooltip:AddLine(note, 0.58, 0.58, 0.58, true)
		end
	elseif isRosterOnly then
		tooltip:AddLine(
			(GF.L and GF.L.MPLUS_TOOLTIP_ROSTER_ONLY_NOTE)
				or "当前只能获得该玩家的队伍名册信息。",
			0.58, 0.58, 0.58, true)
	end

	tooltip:AddLine(
		(GF.L and GF.L.MPLUS_TOOLTIP_BEST_RUNS_TITLE) or "最佳副本记录",
		1, 0.82, 0)

	local dungeons = GF.MythicPlusSeason
		and GF.MythicPlusSeason.GetDungeons
		and GF.MythicPlusSeason:GetDungeons()
		or {}
	if GF.UI and GF.UI.ApplyGameTooltipFont then
		GF.UI.ApplyGameTooltipFont(tooltip)
	end
	-- Do not use GameTooltip_InsertFrame here. Once its child is anchored to a
	-- tooltip line, Retail can classify the child's geometry as secret; the
	-- native inserter then compares that width in addon-tainted execution.
	addRosterBestRunsFallback(
		tooltip,
		dungeons,
		runsByMapID,
		bestRuns,
		hasCachedBestRuns)
	if GF.UI and GF.UI.ShowGameTooltip then
		GF.UI.ShowGameTooltip(tooltip)
	else
		tooltip:Show()
	end
end

function UI.CreateRosterKeystoneAnnouncement(parent, row)
	local button = CreateFrame("Button", nil, parent)
	button:SetPoint("CENTER")
	button:SetSize(24, 24)
	button:RegisterForClicks("LeftButtonUp")
	button.Icon = button:CreateTexture(nil, "OVERLAY")
	button.Icon:SetSize(18, 18)
	if not GF.UI.TrySetAtlas(button.Icon, GF.MYTHIC_PLUS_KEYSTONE_ANNOUNCE_ATLAS, false) then
		button.Icon:SetTexture("Interface\\Icons\\INV_Misc_Horn_01")
		button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	function button:ApplyPressed(pressed)
		local active = pressed == true and self._announceEnabled == true
		self.Icon:ClearAllPoints()
		self.Icon:SetPoint("CENTER", self, "CENTER", active and 1 or 0, active and -1 or 0)
	end
	button:ApplyPressed(false)
	button:SetScript("OnMouseDown", function(self, mouseButton)
		self:ApplyPressed(mouseButton == "LeftButton")
	end)
	button:SetScript("OnMouseUp", function(self) self:ApplyPressed(false) end)
	button:SetScript("OnClick", function(self)
		local service = GF.MythicPlusAnnouncementService
		if not row._gfRosterRetiring and self._announceEnabled and service and service.BroadcastWarbandKeystone then
			service:BroadcastWarbandKeystone(self._announceData)
		end
	end)
	button:SetScript("OnEnter", function(self)
		if row._gfRosterRetiring then return end
		setRosterRowHover(row, true)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		local locale = GF.L or {}
		GameTooltip:AddLine(locale.MPLUS_WARBAND_KEYSTONE_ANNOUNCE or "通报钥石", 1, 0.82, 0)
		GameTooltip:AddLine(self._announceEnabled
			and (locale.MPLUS_KEYSTONE_ANNOUNCE_HINT or "点击通报该角色的钥石。")
			or (locale.MPLUS_KEYSTONE_ANNOUNCE_UNAVAILABLE or "暂无可通报的钥石。"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	local function clearHover(self)
		self:ApplyPressed(false)
		setRosterRowHover(row, false)
		if GameTooltip:GetOwner() == self then GameTooltip_Hide() end
	end
	button:SetScript("OnLeave", clearHover)
	button:SetScript("OnHide", clearHover)
	return button
end

function UI.BindRosterKeystoneAnnouncement(button, data, keyState)
	local enabled = keyState == "ready" and type(data.keystoneLink) == "string"
		and data.keystoneLink ~= "" and data.previewOnly ~= true
		and data.isDebugTest ~= true and data.isTest ~= true and data.source ~= "test"
	button._announceData = data
	button._announceEnabled = enabled
	button:SetEnabled(enabled)
	button.Icon:SetDesaturated(not enabled)
	local tint = enabled and 1 or 0.52
	button.Icon:SetVertexColor(tint, tint, tint, 1)
	button:ApplyPressed(false)
end

local layoutRosterRow

local function applyRosterTeleportVisual(button, pressed)
	if not (button and button.Icon) then
		return
	end
	UI.ApplyTeleportIconVisual(
		button.Icon,
		button._gfTeleportVisualState,
		{
			profile = "roster",
			pressed = pressed == true,
			anchor = button,
		})
end

local function stopRosterRatingSpinner(widgets)
	if widgets and widgets.ratingSpinner
		and GF.UI and GF.UI.StopPendingSpinner
	then
		GF.UI.StopPendingSpinner(widgets.ratingSpinner)
	end
end

local function updateRosterRatingCell(row, data)
	local widgets = row and row.Widgets
	if not (widgets and widgets.rating and data) then
		return
	end
	local rating = tonumber(data.rating)
	local pending = rating == nil and data.ratingState == "pending"
	local canShowSpinner = pending
		and not row._gfRosterRetiring
		and widgets.ratingSpinner
		and GF.UI
		and GF.UI.StartPendingSpinner
	if canShowSpinner then
		widgets.rating:SetText("")
		GF.UI.StartPendingSpinner(widgets.ratingSpinner, 18)
	else
		stopRosterRatingSpinner(widgets)
		widgets.rating:SetText(UI.FormatRating(rating, data.ratingState))
	end
	local color = data.ratingColor
		or (rating and GF.MythicPlusRatingCache
			and GF.MythicPlusRatingCache:GetCachedScoreColor(rating))
	if not color and rating and GF.Result and GF.Result.GetDungeonScoreColor then
		color = GF.Result:GetDungeonScoreColor(rating)
	end
	if rating and color then
		widgets.rating:SetTextColor(color.r or 1, color.g or 1, color.b or 1, 1)
	else
		widgets.rating:SetTextColor(0.52, 0.52, 0.52, 1)
	end
end

local function createRosterRow(page, row)
	if row._gfMPlusRosterPage == page then
		return
	end
	row._gfMPlusRosterPage = page
	row:SetHeight(UI.ROSTER_ROW_HEIGHT)
	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnEnter", function(self)
		setRosterRowHover(self, true)
	end)
	row:SetScript("OnLeave", function(self)
		setRosterRowHover(self, false)
	end)

	local backgroundPieces = GF.UI.CreateRowBackgroundPieces(
		row,
		"BACKGROUND",
		-2)
	local hoverPieces = GF.UI.CreateRowBackgroundPieces(
		row,
		"BORDER",
		-1)
	for _, piece in pairs(hoverPieces) do
		if piece.SetBlendMode then
			piece:SetBlendMode("ADD")
		end
	end

	local layout = page.layout
	local nameContainer = CreateFrame("Frame", nil, row)
	nameContainer:SetPoint("LEFT", row, "LEFT", layout.name.x, 0)
	nameContainer:SetSize(layout.name.width, GF.LIST_ROW_STYLE.contentHeight)
	local classIcon = nameContainer:CreateTexture(nil, "OVERLAY")
	classIcon:SetPoint("LEFT", nameContainer, "LEFT", ROSTER_CHARACTER_ICON_INSET_LEFT, 0)
	local classIconSize = getRosterClassIconSize()
	classIcon:SetSize(classIconSize, classIconSize)
	classIcon:SetTexCoord(0, 1, 0, 1)
	classIcon:Hide()
	local leaderIcon = nameContainer:CreateTexture(nil, "ARTWORK", nil, -7)
	leaderIcon:SetAtlas(ROSTER_LEADER_ICON_ATLAS, true)
	leaderIcon:SetPoint(
		"CENTER",
		classIcon,
		"TOP",
		0,
		ROSTER_LEADER_ICON_OFFSET_Y)
	leaderIcon:Hide()
	local name = createFontString(nameContainer, "GameFontHighlight")
	name:SetPoint("LEFT", nameContainer, "LEFT", 0, 0)
	name:SetPoint("RIGHT", nameContainer, "RIGHT", 0, 0)
	name:SetHeight(GF.LIST_ROW_STYLE.contentHeight)
	name:SetJustifyH("LEFT")
	setFontSize(name, GF.LIST_ROW_STYLE.textSize)
	local nameHoverFrame = CreateFrame(
		"Button",
		nil,
		row,
		"InsecureActionButtonTemplate")
	nameHoverFrame:SetPoint("LEFT", row, "LEFT", layout.name.x, 0)
	nameHoverFrame:SetSize(layout.name.width, UI.ROSTER_ROW_HEIGHT)
	nameHoverFrame:EnableMouse(true)
	nameHoverFrame:SetAttribute("useOnKeyDown", false)
	nameHoverFrame:RegisterForClicks("RightButtonUp")
	nameHoverFrame:SetFrameLevel(row:GetFrameLevel() + 3)
	nameHoverFrame:SetScript("OnEnter", function(self)
		setRosterRowHover(row, true)
		showRosterRowTooltip(row, self)
	end)
	nameHoverFrame:SetScript("OnLeave", function()
		setRosterRowHover(row, false)
		GameTooltip_Hide()
	end)
	nameHoverFrame:SetScript("PreClick", function(self, mouseButton)
		if not row._gfRosterRetiring and page.listKind == "group"
			and GF.BlacklistMenu
			and GF.BlacklistMenu.HandleRosterContextMenuClick
		then
			GF.BlacklistMenu:HandleRosterContextMenuClick(
				row._gfData,
				self,
				mouseButton)
		end
	end)

	local armor = createFontString(row, "GameFontHighlight")
	armor:SetPoint("LEFT", row, "LEFT", layout.armor.x, 0)
	armor:SetSize(layout.armor.width, GF.LIST_ROW_STYLE.contentHeight)
	armor:SetJustifyH("CENTER")
	setFontSize(armor, GF.LIST_ROW_STYLE.textSize)

	local keyButton = CreateFrame("Button", nil, row)
	keyButton:SetPoint("LEFT", row, "LEFT", layout.key.x, 0)
	keyButton:SetSize(layout.key.width, GF.LIST_ROW_STYLE.contentHeight)
	local keyText = createFontString(keyButton, "GameFontHighlight")
	keyText:SetAllPoints()
	keyText:SetJustifyH("LEFT")
	setFontSize(keyText, GF.LIST_ROW_STYLE.textSize)
	keyButton.Text = keyText
	UI.BindKeystoneLinkButton(keyButton, {
		onEnter = function()
			setRosterRowHover(row, true)
		end,
		onLeave = function()
			setRosterRowHover(row, false)
		end,
	})

	local ratingContainer = CreateFrame("Frame", nil, row)
	ratingContainer:SetPoint("LEFT", row, "LEFT", layout.rating.x, 0)
	ratingContainer:SetSize(layout.rating.width, GF.LIST_ROW_STYLE.contentHeight)
	local rating = createFontString(ratingContainer, "GameFontHighlight")
	rating:SetAllPoints()
	rating:SetJustifyH("CENTER")
	setFontSize(rating, GF.LIST_ROW_STYLE.textSize)
	local ratingSpinner = GF.UI and GF.UI.CreatePendingSpinner
		and GF.UI.CreatePendingSpinner(ratingContainer, 18)
	if ratingSpinner then
		ratingSpinner:SetPoint("CENTER", ratingContainer, "CENTER", 0, 0)
	end

	local rolesContainer = CreateFrame("Frame", nil, row)
	rolesContainer:SetPoint("LEFT", row, "LEFT", layout.roles.x, 0)
	rolesContainer:SetSize(layout.roles.width, GF.LIST_ROW_STYLE.contentHeight)
	local roles = {}
	for _, roleKey in ipairs(ServiceUtil.ROLE_ORDER) do
		local role = rolesContainer:CreateTexture(nil, "OVERLAY")
		role:SetSize(classIconSize, classIconSize)
		GF.UI.TrySetAtlas(role, UI.GetRoleAtlas(roleKey), false)
		role:SetVertexColor(1, 1, 1, 0.95)
		role:Hide()
		roles[roleKey] = role
	end
	local noRole = createFontString(rolesContainer, "GameFontHighlight")
	noRole:SetAllPoints()
	noRole:SetJustifyH("CENTER")
	noRole:SetText("-")
	noRole:SetTextColor(0.52, 0.52, 0.52, 1)
	setFontSize(noRole, GF.LIST_ROW_STYLE.textSize)

	local teleportContainer = CreateFrame("Frame", nil, row)
	teleportContainer:SetPoint("LEFT", row, "LEFT", layout.teleport.x, 0)
	teleportContainer:SetSize(layout.teleport.width, GF.LIST_ROW_STYLE.contentHeight)
	local teleportButton, teleport
	if page.announceKeystone then
		teleportButton = UI.CreateRosterKeystoneAnnouncement(teleportContainer, row)
		teleport = teleportButton.Icon
	else
		teleportButton = CreateFrame("Button", nil, teleportContainer, "InsecureActionButtonTemplate")
		teleportButton:SetPoint("CENTER")
		teleportButton:SetSize(18, 18)
		teleportButton:RegisterForClicks("AnyUp", "AnyDown")
		teleport = teleportButton:CreateTexture(nil, "OVERLAY")
		GF.UI.TrySetAtlas(teleport, GF.MYTHIC_PLUS_TELEPORT_ICON_ATLAS, false)
		teleportButton.Icon = teleport
		teleportButton._gfTeleportVisualState = "unavailable"
		applyRosterTeleportVisual(teleportButton, false)
		teleportButton:SetScript("OnMouseDown", function(self, mouseButton)
			if not row._gfRosterRetiring and mouseButton == "LeftButton"
				and self._gfTeleportVisualState == "ready"
				and not UI.IsTeleportCombatLocked()
			then
				applyRosterTeleportVisual(self, true)
			end
		end)
		teleportButton:SetScript("OnMouseUp", function(self)
			applyRosterTeleportVisual(self, false)
		end)
		teleportButton:SetScript("OnEnter", function(self)
			if row._gfRosterRetiring then return end
			setRosterRowHover(row, true)
			if self._gfTeleportDestination and GF.MythicPlusTeleportService then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:ClearLines()
				GF.MythicPlusTeleportService:AddTooltipLines(GameTooltip, self._gfTeleportDestination, {
					secureReady = self.gfTeleportSecureReady == true,
				})
				GameTooltip:Show()
			end
		end)
		teleportButton:SetScript("OnLeave", function(self)
			applyRosterTeleportVisual(self, false)
			setRosterRowHover(row, false)
			GameTooltip_Hide()
		end)
		UI.InstallTeleportCombatFeedback(teleportButton, function(button)
			applyRosterTeleportVisual(button, false)
		end)
	end

	local last = createFontString(row, "GameFontHighlight")
	last:SetPoint("LEFT", row, "LEFT", layout.last.x, 0)
	last:SetSize(layout.last.width, GF.LIST_ROW_STYLE.contentHeight)
	last:SetJustifyH("CENTER")
	setFontSize(last, GF.LIST_ROW_STYLE.textSize)

	local actionButton
	if page.quickAction then
		actionButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		actionButton:SetSize(
			GF.PANEL_BUTTON_STANDARD_W,
			GF.MYTHIC_PLUS_ACTION_BUTTON_HEIGHT)
		actionButton:SetPoint("CENTER", row, "LEFT", layout.last.x + (layout.last.width / 2), 0)
		actionButton:SetText((GF.L and GF.L.TAB_CREATE) or "创建招募")
		setFontSize(actionButton.Text or actionButton:GetFontString(), GF.PLAYER_MANAGEMENT_STYLE.buttonFontSize)
		UI.ApplyMythicPlusButtonSkin(actionButton)
		actionButton:SetScript("OnClick", function()
			local service = GF.MythicPlusQuickActionService
			if not row._gfRosterRetiring and service and service.Execute
				and actionButton._gfActionPreviewOnly ~= true
			then
				if GF.UI and GF.UI.PlayUISound then
					GF.UI.PlayUISound("check")
				end
				service:Execute(row._gfData, actionButton._gfActionID)
			end
		end)
		actionButton:HookScript("OnEnter", function()
			setRosterRowHover(row, true)
		end)
		actionButton:HookScript("OnLeave", function()
			setRosterRowHover(row, false)
		end)
		last:Hide()
	end

	row.Widgets = {
		backgroundPieces = backgroundPieces,
		hoverPieces = hoverPieces,
		nameContainer = nameContainer,
		classIcon = classIcon,
		leaderIcon = leaderIcon,
		name = name,
		nameHoverFrame = nameHoverFrame,
		armor = armor,
		keyButton = keyButton,
		keyText = keyText,
		ratingContainer = ratingContainer,
		rating = rating,
		ratingSpinner = ratingSpinner,
		rolesContainer = rolesContainer,
		roles = roles,
		noRole = noRole,
		teleportContainer = teleportContainer,
		teleportButton = teleportButton,
		teleport = teleport,
		last = last,
		actionButton = actionButton,
	}
	layoutRosterRow(page, row)
	setRosterRowHover(row, false)
	row:HookScript("OnHide", function(self)
		stopRosterRatingSpinner(self.Widgets)
	end)
	row:HookScript("OnShow", function(self)
		if self._gfData then
			updateRosterRatingCell(self, self._gfData)
		end
	end)
end

layoutRosterRow = function(page, row)
	local widgets = row and row.Widgets
	local layout = page and page.layout
	if not (widgets and layout) then
		return
	end

	local contentY = GF.LIST_ROW_STYLE.contentOffsetY
	local function applyColumn(frame, column, height, offsetY)
		if not (frame and column) then
			return
		end
		frame:ClearAllPoints()
		frame:SetPoint("LEFT", row, "LEFT", column.x, offsetY or contentY)
		frame:SetSize(math.max(1, column.width), height or GF.LIST_ROW_STYLE.contentHeight)
	end

	applyColumn(widgets.nameContainer, layout.name)
	-- Keep the full-row name hit region centered while moving its visible content.
	applyColumn(widgets.nameHoverFrame, layout.name, UI.ROSTER_ROW_HEIGHT, 0)
	applyColumn(widgets.armor, layout.armor)
	applyColumn(widgets.keyButton, layout.key)
	applyColumn(widgets.ratingContainer, layout.rating)
	applyColumn(widgets.rolesContainer, layout.roles)
	applyColumn(widgets.teleportContainer, layout.teleport)
	applyColumn(widgets.last, layout.last)
	if widgets.actionButton and layout.last then
		widgets.actionButton:ClearAllPoints()
		widgets.actionButton:SetPoint("CENTER", row, "LEFT",
			layout.last.x + (layout.last.width / 2), contentY)
		local width = page.compact and math.min(GF.PANEL_BUTTON_STANDARD_W,
			math.max(1, layout.last.width - 6)) or GF.PANEL_BUTTON_STANDARD_W
		widgets.actionButton:SetWidth(width)
		local text = widgets.actionButton.Text or widgets.actionButton:GetFontString()
		if text and GF.Font and GF.Font.SetFitWidth then
			GF.Font.SetFitWidth(text, math.max(1, width - 8), 10)
		end
	end
	if row._gfData and layout.roles then
		setRoleFrames(widgets.roles, row._gfData, layout.roles.width)
	end
end

local function bindRosterRow(page, row, data)
	createRosterRow(page, row)
	layoutRosterRow(page, row)
	row._gfData = data
	row._gfRosterRetiring = data._gfRosterRetiring == true
	local widgets = row.Widgets
	row:EnableMouse(not row._gfRosterRetiring)
	for _, key in ipairs({ "nameHoverFrame", "keyButton", "teleportButton" }) do
		widgets[key]:EnableMouse(not row._gfRosterRetiring)
	end
	setRosterRowVisualState(row, getRosterRowVisualState(page, data))
	setRosterRowHover(row, false)

	local characterIcon, resolvedClassFile = getRosterCharacterIcon(data)
	local classIconSize = getRosterClassIconSize()
	widgets.classIcon:ClearAllPoints()
	widgets.classIcon:SetPoint("CENTER", widgets.nameContainer, "LEFT",
		ROSTER_CHARACTER_ICON_INSET_LEFT + classIconSize / 2, 0)
	widgets.classIcon:SetSize(classIconSize, classIconSize)
	widgets.leaderIcon:ClearAllPoints()
	widgets.leaderIcon:SetPoint("CENTER", widgets.nameContainer, "LEFT",
		ROSTER_CHARACTER_ICON_INSET_LEFT + classIconSize / 2,
		classIconSize / 2 + ROSTER_LEADER_ICON_OFFSET_Y)
	local hasClassIcon = characterIcon and GF.UI and GF.UI.SetSpecializationIcon
		and GF.UI.SetSpecializationIcon(widgets.classIcon, characterIcon, {
			size = classIconSize * (GF.LIST_SPECIALIZATION_ICON_SCALE or 0.8),
			outerSize = classIconSize,
			ringStyle = GF.CLASS_SPECIALIZATION_RING_STYLE,
			classFile = resolvedClassFile
				or data.classFile
				or data.classFilename
				or data.class,
			disabled = data.connected == false,
		})
	if hasClassIcon then
		widgets.leaderIcon:SetShown(data.leader == true)
		widgets.name:ClearAllPoints()
		widgets.name:SetPoint("LEFT", widgets.nameContainer, "LEFT",
			ROSTER_CHARACTER_ICON_INSET_LEFT
				+ classIconSize
				+ ROSTER_CHARACTER_ICON_GAP_RIGHT,
			0)
		widgets.name:SetPoint("RIGHT", widgets.nameContainer, "RIGHT", 0, 0)
	else
		widgets.leaderIcon:Hide()
		if GF.UI and GF.UI.ClearSpecializationIcon then
			GF.UI.ClearSpecializationIcon(widgets.classIcon)
		else
			widgets.classIcon:SetTexture(nil)
			widgets.classIcon:Hide()
		end
		widgets.name:ClearAllPoints()
		widgets.name:SetPoint("LEFT", widgets.nameContainer, "LEFT",
			ROSTER_CHARACTER_ICON_INSET_LEFT, 0)
		widgets.name:SetPoint("RIGHT", widgets.nameContainer, "RIGHT", 0, 0)
	end
	widgets.name:SetHeight(GF.LIST_ROW_STYLE.contentHeight)
	widgets.name:SetText(getRosterDisplayName(data))
	local r, g, b = UI.GetClassColor(
		data.classFile or data.classFilename or data.class)
	widgets.name:SetTextColor(r, g, b)
	widgets.armor:SetText(UI.GetArmorLabel(data.classFile))
	local keyLevel = tonumber(data.keyLevel)
	local keyState = getRosterKeyState(data)
	if keyState == "empty" then
		widgets.keyText:SetText((GF.L and GF.L.MPLUS_NO_KEYSTONE) or "无钥石")
		widgets.keyText:SetTextColor(0.52, 0.52, 0.52, 1)
		widgets.keyButton.keystoneLink = nil
	elseif keyState == "ready" then
		widgets.keyText:SetText(getRosterKeystoneText(page, data, keyState))
		widgets.keyText:SetTextColor(1, 1, 1, 1)
		widgets.keyButton.keystoneLink = data.keystoneLink
	else
		widgets.keyText:SetText(getUnknownKeystoneText(page))
		widgets.keyText:SetTextColor(0.52, 0.52, 0.52, 1)
		widgets.keyButton.keystoneLink = nil
	end
	updateRosterRatingCell(row, data)
	setRoleFrames(widgets.roles, data, page.layout.roles.width)
	local selectedRole = ServiceUtil.NormalizeRole(data.role)
	local hasRoles = selectedRole and selectedRole ~= "NONE"
	if type(data.roles) == "table" then
		hasRoles = false
		for _, enabled in pairs(data.roles) do
			if enabled then
				hasRoles = true
				break
			end
		end
	end
	widgets.noRole:SetShown(not hasRoles)
	local hasKey = keyState == "ready" and keyLevel and keyLevel > 0
	if page.announceKeystone then
		UI.BindRosterKeystoneAnnouncement(widgets.teleportButton, data, keyState)
	else
		local teleportDestination = hasKey and (data.challengeModeID or data.mapID) or nil
		local teleportStatus = data.teleportStatus
		local teleportSecureReady = teleportStatus == "ready"
		if GF.MythicPlusTeleportService then
			teleportStatus = GF.MythicPlusTeleportService:GetStatus(teleportDestination)
			local secureReady, pending = GF.MythicPlusTeleportService:ApplySecureButton(
				widgets.teleportButton, teleportDestination)
			teleportSecureReady = secureReady == true and pending ~= true
		end
		widgets.teleportButton._gfTeleportDestination = teleportDestination
		local teleportVisualState
		if not hasKey then
			teleportVisualState = "unavailable"
		elseif teleportStatus == "ready"
			and (teleportSecureReady or UI.IsTeleportCombatLocked())
		then
			teleportVisualState = "ready"
		elseif teleportStatus == "cooldown" then
			teleportVisualState = "cooldown"
		elseif teleportStatus == "not_learned" then
			teleportVisualState = "not_learned"
		else
			teleportVisualState = "fallback"
		end
		widgets.teleportButton._gfTeleportVisualState = teleportVisualState
		applyRosterTeleportVisual(widgets.teleportButton, false)
	end
	widgets.last:SetText(page.getLastText and page.getLastText(data) or "-")
	if page.listKind == "carpool" and (data.warbandSourceClass or data.ownerClass) then
		local sr, sg, sb = UI.GetClassColor(data.warbandSourceClass or data.ownerClass)
		widgets.last:SetTextColor(sr, sg, sb, 1)
	else
		widgets.last:SetTextColor(1, 1, 1, 1)
	end
	if widgets.actionButton then
		local action = GF.MythicPlusQuickActionService
			and GF.MythicPlusQuickActionService.Resolve
			and GF.MythicPlusQuickActionService:Resolve(data)
		local showAction = type(action) == "table"
		widgets.actionButton._gfActionID = showAction
			and (action.id or action.actionID) or nil
		widgets.actionButton._gfActionPreviewOnly = showAction
			and action.previewOnly == true or nil
		widgets.actionButton:SetText(showAction
			and (action.label or action.text)
			or ((GF.L and GF.L.MPLUS_SEND_KEYSTONE) or "发送钥石"))
		widgets.actionButton:SetEnabled(showAction and action.enabled ~= false)
		widgets.actionButton:EnableMouse(not row._gfRosterRetiring and showAction and action.enabled ~= false)
		UI.UpdateMythicPlusButtonSkin(widgets.actionButton)
		widgets.actionButton:SetShown(showAction)
		if not showAction
			and not hasKey
			and data.isRosterOnly ~= true
			and data.isDebugTest ~= true
			and data.isTest ~= true
			and data.source ~= "test"
		then
			widgets.last:SetText("")
		end
		widgets.last:SetShown(not showAction)
	end
	if row._gfRosterRetiring then
		-- Preserve the last visual snapshot, but discard link/announcement input
		-- immediately. Insecure spell/menu buttons also lose mouse input above.
		widgets.keyButton.keystoneLink = nil
		widgets.teleportButton._announceEnabled = false
		local owner = GameTooltip and GameTooltip:GetOwner()
		if owner and (owner == row or owner == widgets.nameHoverFrame
			or owner == widgets.keyButton or owner == widgets.teleportButton
			or owner == widgets.actionButton) then GameTooltip_Hide() end
	end
	if page.rowTransitions then page.rowTransitions:BindRow(row, data) end
end

function UI.CreateRosterPage(parent, options)
	local page = {
		columns = {},
		announceKeystone = options.announceKeystone == true,
			getElements = options.getElements,
			getLastText = options.getLastText,
			quickAction = options.quickAction == true,
			listKind = options.listKind or "group",
		unknownKeyTextKey = options.unknownKeyTextKey,
	}
	for index, source in ipairs(UI.ROSTER_COLUMNS) do
		local column = {}
		for key, value in pairs(source) do
			column[key] = value
		end
		if column.key == "last" and options.lastLabelKey then
			column.labelKey = options.lastLabelKey
		elseif column.key == "name" and options.nameLabelKey then
			column.labelKey = options.nameLabelKey
		elseif column.key == "teleport" and page.announceKeystone then
			column.labelKey = "MPLUS_COL_ANNOUNCE"
		end
		page.columns[index] = column
	end
	local initialLayout = getRosterLayout(page.columns,
		UI.ROSTER_LIST_WIDTH - UI.ROSTER_ROWS_PADDING_X - UI.ROSTER_ROWS_PADDING_RIGHT)
	page.layout = initialLayout.byId
	page.compact = initialLayout.compact
	page.localSort = {
		column = options.sortColumn == "last" and "last" or "roster",
		asc = true,
	}

	local function getColumn(columnID)
		for _, column in ipairs(page.columns) do
			if column.key == columnID then
				return column
			end
		end
	end

	local function toggleSort(columnID)
		if GF.MythicPlusRosterSort and GF.MythicPlusRosterSort.Toggle then
			GF.MythicPlusRosterSort:Toggle(page.listKind, columnID)
			return
		end
		if page.localSort.column == columnID then
			page.localSort.asc = not page.localSort.asc
		else
			page.localSort.column = columnID
			page.localSort.asc = columnID ~= "key" and columnID ~= "rating"
		end
	end

	local function applyResolvedLayout(layout)
		if not (layout and layout.byId) then
			return
		end
		page.layout = layout.byId
		page.compact = layout.compact
		if page.scrollList and page.scrollList.ForEachFrame then
			page.scrollList:ForEachFrame(function(row)
				layoutRosterRow(page, row)
			end)
		end
	end

	page.frame = CreateFrame("Frame", nil, parent)
	page.frame:SetAllPoints(parent)
	page.frame:Hide()

	page.itemList = CreateFrame("Frame", nil, page.frame)
	page.itemList:SetAllPoints(page.frame)

	page.header = CreateFrame("Frame", nil, page.itemList)
	page.header:SetPoint("TOPLEFT", page.frame, "TOPLEFT",
		UI.ROSTER_HEADER_INSET_LEFT, -UI.ROSTER_HEADER_INSET_TOP)
	page.header:SetPoint("TOPRIGHT", page.frame, "TOPRIGHT",
		-UI.ROSTER_HEADER_INSET_RIGHT, -UI.ROSTER_HEADER_INSET_TOP)
	page.header:SetHeight(UI.ROSTER_HEADER_HEIGHT)
	if GF.UI and GF.UI.InstallBrowseHeaderChrome then
		GF.UI.InstallBrowseHeaderChrome(page.header, {
			backgroundInsetLeft = 0,
			-- Keep roster chrome inside its pane so split-page clipping, fading
			-- and hiding also apply to the header background.
			backgroundParent = page.itemList,
		})
	end
	page.columnHeaderBar = GF.ColumnHeaderBar:Create(page.header, {
		mode = "custom",
		profile = "mythic_roster",
		contentHeight = UI.ROSTER_HEADER_HEIGHT,
		resolveLayout = function(width)
			return getRosterLayout(page.columns, width)
		end,
		getHeaderLabel = function(columnID)
			local column = getColumn(columnID)
			return column and ((GF.L and GF.L[column.labelKey]) or column.key) or columnID
		end,
		isSortable = function(columnID)
			local column = getColumn(columnID)
			return column and (column.sortable == true
				or (column.key == "last" and options.sortColumn == "last")) or false
		end,
		onColumnClick = function(columnID)
			toggleSort(columnID)
		end,
		onSort = function()
			if page.RefreshView then
				page:RefreshView()
			end
		end,
		-- Keep header clicks sortable without requesting a visible sort arrow.
		alignColumns = true,
		onLayoutResolved = applyResolvedLayout,
	})
	page.columnHeaderBar:SetPoint("TOPLEFT", page.header, "TOPLEFT",
		UI.ROSTER_ROWS_PADDING_X, UI.ROSTER_HEADER_CONTENT_OFFSET_Y)
	page.columnHeaderBar:SetPoint("BOTTOMRIGHT", page.header, "BOTTOMRIGHT",
		-UI.ROSTER_ROWS_PADDING_RIGHT, UI.ROSTER_HEADER_CONTENT_OFFSET_Y)

	page.scrollList = GF.UI.ScrollList.Create(page.itemList, {
		assignedKey = "elementKey",
		barParent = page.frame,
		barOffsetX = GF.SETTINGS_SCROLLBAR_GAP or 2,
		keepNativeScrollBar = true,
		frameType = "Button",
		rowHeight = UI.ROSTER_ROW_HEIGHT,
		smoothWheel = true,
		edgeFadeLength = GF.MYTHIC_PLUS_SCROLL_EDGE_FADE,
		-- Share the management lists' scrolling leading/trailing space.
		padding = { GF.PLAYER_MANAGEMENT_STYLE.listEdgePadding, GF.PLAYER_MANAGEMENT_STYLE.listEdgePadding,
			UI.ROSTER_ROWS_PADDING_X, UI.ROSTER_ROWS_PADDING_RIGHT, 0 },
		elementInitializer = function(row, data)
			bindRosterRow(page, row, data)
		end,
	})
	if page.scrollList then
		local scrollBox = page.scrollList:GetScrollBox()
		-- This page has no footer; its viewport ends at the panel's inner background.
		local bottomInset = GF.MAIN_PANEL_BACKPLATE_BG_INSET_BOTTOM
		scrollBox:ClearAllPoints()
		scrollBox:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT",
			0, 0)
		scrollBox:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT",
			-UI.ROSTER_HEADER_INSET_RIGHT, bottomInset)
		local scrollBar = page.scrollList:GetScrollBar()
		if scrollBar then
			local scrollStyle = GF.PLAYER_MANAGEMENT_STYLE
			scrollBar:ClearAllPoints()
			scrollBar:SetWidth(scrollStyle.scrollBarWidth)
			-- Roster pages use full-backplate coordinates; the header already
			-- includes the inner-background inset used by the blacklist host.
			scrollBar:SetPoint("TOPRIGHT", page.header, "BOTTOMRIGHT",
				-scrollStyle.scrollBarRightInset, 0)
			scrollBar:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT",
				-UI.ROSTER_HEADER_INSET_RIGHT - scrollStyle.scrollBarRightInset, bottomInset)
			page.scrollList:BindDynamicScrollBar({
				gutter = scrollStyle.scrollBarGutter,
				duration = scrollStyle.scrollBarDuration,
				overflowEpsilon = scrollStyle.scrollBarOverflowEpsilon,
				reserveGutter = false,
				animateInset = true,
				onInsetChanged = function(inset)
					scrollBox:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT",
						-UI.ROSTER_HEADER_INSET_RIGHT - inset, bottomInset)
					page.columnHeaderBar:SetPoint("BOTTOMRIGHT", page.header, "BOTTOMRIGHT",
						-UI.ROSTER_ROWS_PADDING_RIGHT - inset, UI.ROSTER_HEADER_CONTENT_OFFSET_Y)
					GF.ColumnHeaderBar:Layout(page.columnHeaderBar,
						math.max(1, scrollBox:GetWidth() - UI.ROSTER_ROWS_PADDING_X - UI.ROSTER_ROWS_PADDING_RIGHT))
				end,
			})
		end
	end

	page.emptyText = createFontString(page.itemList, "GameFontDisable")
	page.emptyText:SetPoint("CENTER", page.scrollList and page.scrollList:GetScrollBox() or page.itemList, "CENTER")
	page.emptyText:SetJustifyH("CENTER")
	page.emptyText:SetTextColor(1, 0.82, 0, 1)
	if GF.UI and GF.UI.ApplyEmptyPromptFont then
		GF.UI.ApplyEmptyPromptFont(page.emptyText, "GameFontDisable")
	end
	page.rowTransitions = GF.MythicPlusRosterRowTransitions.Create(page)

	page.itemList:SetScript("OnSizeChanged", function()
		if page.columnHeaderBar and GF.ColumnHeaderBar then
			GF.ColumnHeaderBar:Layout(page.columnHeaderBar,
				math.max(1, page.columnHeaderBar:GetWidth() or 1))
		end
	end)

	function page:RefreshLocale()
		self.emptyText:SetText((GF.L and GF.L[options.emptyKey]) or "暂无数据")
		if self.scrollList and self.scrollList:GetScrollBox()
			and self.scrollList:GetScrollBox().ForEachFrame then
			self.scrollList:GetScrollBox():ForEachFrame(function(row)
				if row.Widgets and row._gfData then
					updateRosterRatingCell(row, row._gfData)
				end
				local actionButton = row.Widgets and row.Widgets.actionButton
				if actionButton and row._gfData then
					local action = GF.MythicPlusQuickActionService
						and GF.MythicPlusQuickActionService.Resolve
						and GF.MythicPlusQuickActionService:Resolve(row._gfData)
					actionButton:SetText(type(action) == "table"
						and (action.label or action.text)
						or ((GF.L and GF.L.MPLUS_SEND_KEYSTONE) or "发送钥石"))
				end
			end)
		end
		if self.columnHeaderBar and GF.ColumnHeaderBar then
			GF.ColumnHeaderBar:Layout(self.columnHeaderBar,
				math.max(1, self.columnHeaderBar:GetWidth() or 1))
		end
	end

	function page:RefreshView()
		local elements = self.getElements and self.getElements() or {}
		if GF.MythicPlusRosterSort and GF.MythicPlusRosterSort.Sort then
			elements = GF.MythicPlusRosterSort:Sort(self.listKind, elements)
		end
		for index, element in ipairs(elements) do
			element.elementKey = element.elementKey or element.key or tostring(index)
		end
		self.rowTransitions:SetElements(elements)
		if self.columnHeaderBar and GF.ColumnHeaderBar then
			GF.ColumnHeaderBar:Layout(self.columnHeaderBar,
				math.max(1, self.columnHeaderBar:GetWidth() or 1))
		end
	end

	function page:Show()
		self:RefreshLocale()
		self:RefreshView()
		self.frame:Show()
	end

	function page:Hide()
		self.frame:Hide()
	end

	page:RefreshLocale()
	return page
end
