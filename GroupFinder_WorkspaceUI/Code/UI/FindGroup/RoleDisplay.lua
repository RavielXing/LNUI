local _, GF = ...
GF = GF.GF or GF

-- Pure UI projection for result-role snapshots and applicant-role snapshots.
-- Native/result/applicant ownership stays outside this renderer: Update only
-- reads the value snapshot supplied by its caller.
GF.RoleDisplay = {}
local RD = GF.RoleDisplay

local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local ROLE_PRIORITY = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local ROLE_ATLAS = GF.SEASON_DUNGEON_ROLE_ATLAS or {}
local ROLE_BADGE_ATLAS = GF.BROWSE_ROW_MEMBER_ROLE_BADGE_ATLAS or {}
local EMPTY_SLOT_ATLAS =
	GF.BROWSE_ROW_MEMBER_EMPTY_SLOT_ATLAS or ROLE_ATLAS.DEFAULT
local COUNT_NUMBER_WIDTH = 20
local COUNT_GROUP_GAP = 0
local COUNT_ICON_GAP = GF.ROLE_COUNT_NUM_ICON_GAP or 5
local ROLE_BADGE_OFFSET_X =
	GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_X
	or GF.BROWSE_ROW_MEMBER_LEADER_BADGE_OFFSET_X
	or 2
local ROLE_BADGE_OFFSET_Y =
	GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_Y
	or GF.BROWSE_ROW_MEMBER_LEADER_BADGE_OFFSET_Y
	or 2

local function memberMetrics()
	local iconSize =
		(type(GF.GetBrowseMemberIconSize) == "function"
			and GF.GetBrowseMemberIconSize())
		or GF.BROWSE_ROW_MEMBER_ICON_SIZE
		or GF.ROLE_ICON_SIZE
		or 18
	local gap = GF.BROWSE_ROW_MEMBER_ICON_GAP or 2
	local slots = GF.BROWSE_ROW_MEMBER_MAX_ICONS or 5
	local width = iconSize * slots + gap * math.max(0, slots - 1)
	return iconSize, gap, slots, width
end

local function badgeSize()
	return (type(GF.GetBrowseMemberRoleBadgeSize) == "function"
			and GF.GetBrowseMemberRoleBadgeSize())
		or GF.BROWSE_ROW_MEMBER_ROLE_BADGE_SIZE
		or GF.BROWSE_ROW_MEMBER_LEADER_BADGE_SIZE
		or 9
end

local function countMetrics()
	local iconSize =
		(type(GF.GetRoleCountIconSize) == "function"
			and GF.GetRoleCountIconSize())
		or GF.ROLE_COUNT_ICON_DEFAULT
		or GF.ROLE_ICON_SIZE
		or 18
	local groupWidth = COUNT_NUMBER_WIDTH + COUNT_ICON_GAP + iconSize
	local totalWidth = groupWidth * #ROLE_ORDER
		+ COUNT_GROUP_GAP * (#ROLE_ORDER - 1)
	return iconSize, COUNT_NUMBER_WIDTH, COUNT_ICON_GAP, groupWidth, totalWidth
end

local function normalizeRole(role)
	if type(role) ~= "string" then
		return nil
	end
	role = role:upper()
	if role == "HEAL" then
		return "HEALER"
	end
	if role == "DPS" or role == "DAMAGE" then
		return "DAMAGER"
	end
	return ROLE_PRIORITY[role] and role or nil
end

local function safeCount(value)
	local compat = GF.Compat
	if compat and type(compat.ToAccessibleNumber) == "function" then
		local number = compat.ToAccessibleNumber(value)
		if not number then
			return 0
		end
		return math.max(0, math.floor(number + 0.0001))
	end
	if type(canaccessvalue) == "function" then
		local accessibleOK, accessible = pcall(canaccessvalue, value)
		if not accessibleOK or accessible ~= true then
			return 0
		end
	end
	if type(issecretvalue) == "function" then
		local secretOK, secret = pcall(issecretvalue, value)
		if not secretOK or secret == true then
			return 0
		end
	end
	local ok, number = pcall(tonumber, value)
	if not ok or not number then
		return 0
	end
	return math.max(0, math.floor(number + 0.0001))
end

local function readCount(source, role, legacyField)
	if type(source) ~= "table" then
		return 0
	end
	local ok, value = pcall(rawget, source, role)
	if (not ok or value == nil) and legacyField then
		ok, value = pcall(rawget, source, legacyField)
	end
	return ok and safeCount(value) or 0
end

local function normalizeSnapshot(snapshot, options)
	if type(snapshot) ~= "table" then
		return nil
	end
	options = type(options) == "table" and options or {}
	local info = type(snapshot.info) == "table" and snapshot.info or {}
	local countSource = snapshot.counts
		or snapshot.memberCounts
		or snapshot._displayCounts
		or snapshot
	local counts = {
		TANK = readCount(countSource, "TANK", "tanks"),
		HEALER = readCount(countSource, "HEALER", "heals"),
		DAMAGER = readCount(countSource, "DAMAGER", "dps"),
	}
	local total = safeCount(snapshot.numMembers or info.numMembers)
	local known = counts.TANK + counts.HEALER + counts.DAMAGER
	if total < known then
		total = known
	end
	return {
		mode = options.mode or options.displayMode
			or snapshot.mode or snapshot.roleDisplayMode
			or snapshot.displayMode or "count",
		memberDisplayMode = options.memberDisplayMode
			or snapshot.memberDisplayMode,
		counts = counts,
		total = total,
		players = type(snapshot.players) == "table" and snapshot.players or {},
		disabled = options.disabled == true
			or snapshot.disabled == true
			or snapshot.isDelisted == true
			or info.isDelisted == true,
	}
end

local function tryAtlas(texture, atlas, useAtlasSize)
	if not texture or not atlas then
		return false
	end
	-- Pooled slots can retain specialization crops or class-sheet UVs. Role
	-- atlases always use their full region, independent of the previous member.
	if GF.UI and type(GF.UI.TrySetAtlas) == "function" then
		return GF.UI.TrySetAtlas(texture, atlas, useAtlasSize == true, nil, true) == true
	end
	if texture.SetAtlas then
		return pcall(texture.SetAtlas, texture, atlas, useAtlasSize == true, nil, true) == true
	end
	return false
end

local function setRoleIcon(texture, role)
	role = normalizeRole(role)
	return role and tryAtlas(texture, ROLE_ATLAS[role], false) or false
end

local function setEmptyIcon(texture)
	if tryAtlas(texture, EMPTY_SLOT_ATLAS, false) then
		return
	end
	tryAtlas(texture, ROLE_ATLAS.DEFAULT, false)
end

local nativeWidgetsPrepared = false

local function prepareNativeWidgets()
	if nativeWidgetsPrepared then
		return
	end
	nativeWidgetsPrepared = true
	if type(GF.EnsureBlizzardAddons) == "function" then
		pcall(GF.EnsureBlizzardAddons)
	end
end

local specCache = {}

local function memberClassFile(member)
	return member and (member.classFilename
		or member.classFileName or member.classFile or member.class)
end

local function resolveSpecIcon(member)
	if type(member) ~= "table"
		or not (GF.UI and type(GF.UI.ResolveSpecializationIcon) == "function")
	then
		return nil
	end
	local classFile = memberClassFile(member)
	local role = normalizeRole(member.assignedRole or member.role)
	local cacheKey = table.concat({
		tostring(classFile or ""),
		tostring(member.specID or member.specializationID or ""),
		tostring(member.specName or member.specText or ""),
		tostring(role or ""),
	}, "|")
	local cached = specCache[cacheKey]
	if cached then
		return cached.icon ~= false and cached.icon or nil,
			cached.role, cached.classFile
	end
	local icon, specRole, resolvedClass = GF.UI.ResolveSpecializationIcon({
		classFile = classFile,
		specID = member.specID or member.specializationID,
		specName = member.specName or member.specText,
		role = role,
	})
	specCache[cacheKey] = {
		icon = icon or false,
		role = normalizeRole(specRole),
		classFile = resolvedClass or classFile,
	}
	return icon, normalizeRole(specRole), resolvedClass or classFile
end

local function memberRole(member)
	local role = normalizeRole(
		member and (member.assignedRole or member.role))
	if role then
		return role
	end
	local _, resolvedRole = resolveSpecIcon(member)
	return resolvedRole
end

local function sortedMembers(players)
	local ordered = {}
	for index, member in ipairs(players or {}) do
		ordered[#ordered + 1] = { index = index, value = member }
	end
	table.sort(ordered, function(left, right)
		local leftPriority = ROLE_PRIORITY[memberRole(left.value)] or 99
		local rightPriority = ROLE_PRIORITY[memberRole(right.value)] or 99
		if leftPriority ~= rightPriority then
			return leftPriority < rightPriority
		end
		return left.index < right.index
	end)
	return ordered
end

local function showRoleBadge(role, memberDisplayMode)
	if not role then
		return false
	end
	if memberDisplayMode
		== (GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large")
	then
		return role == "TANK" or role == "HEALER"
	end
	return ROLE_PRIORITY[role] ~= nil
end

local function clearSpecializationTexture(texture)
	if GF.UI and type(GF.UI.ClearSpecializationIcon) == "function" then
		GF.UI.ClearSpecializationIcon(texture)
	end
end

local function setFallbackSpecTexture(texture, icon)
	if type(icon) == "table" then
		if icon.atlas and tryAtlas(texture, icon.atlas, false) then
			return
		end
		texture:SetTexture(icon.texture)
		local coords = icon.texCoords
		if type(coords) == "table" and coords[4] ~= nil then
			texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			texture:SetTexCoord(0, 1, 0, 1)
		end
	else
		texture:SetTexture(icon)
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

local function paintSpecSlot(slot, member, projection)
	if not (slot and slot.icon) then
		return
	end
	local disabled = projection.disabled == true
	local icon, specRole, classFile = resolveSpecIcon(member)
	local role = memberRole(member) or specRole
	local iconSize = select(1, memberMetrics())
	if icon then
		if GF.UI and type(GF.UI.SetSpecializationIcon) == "function" then
			GF.UI.SetSpecializationIcon(slot.icon, icon, {
				ringStyle = GF.CLASS_SPECIALIZATION_RING_STYLE,
				classFile = classFile or memberClassFile(member),
				role = role,
				size = iconSize * (GF.LIST_SPECIALIZATION_ICON_SCALE or 0.8),
				outerSize = iconSize,
				disabled = disabled,
			})
		else
			setFallbackSpecTexture(slot.icon, icon)
		end
	else
		clearSpecializationTexture(slot.icon)
		slot.icon:SetSize(iconSize, iconSize)
		setEmptyIcon(slot.icon)
	end
	slot.icon:SetDesaturated(disabled)
	slot.icon:SetAlpha(disabled and 0.5 or 1)
	slot.icon:Show()
	if slot.roleBadge then
		if showRoleBadge(role, projection.memberDisplayMode)
			and (tryAtlas(slot.roleBadge, ROLE_BADGE_ATLAS[role], false)
				or setRoleIcon(slot.roleBadge, role))
		then
			slot.roleBadge:SetDesaturated(disabled)
			slot.roleBadge:SetAlpha(disabled and 0.5 or 1)
			slot.roleBadge:Show()
		else
			slot.roleBadge:Hide()
		end
	end
end

local function roleCountSlots(frame)
	if frame.parts then
		return frame.parts
	end
	return {
		TANK = { num = frame.TankCount, icon = frame.TankIcon },
		HEALER = { num = frame.HealerCount, icon = frame.HealerIcon },
		DAMAGER = { num = frame.DamagerCount, icon = frame.DamagerIcon },
	}
end

local function formatCountFont(fontString)
	if not fontString then
		return
	end
	local iconSize, numberWidth = countMetrics()
	fontString:SetSize(numberWidth, iconSize)
	fontString:SetJustifyH("RIGHT")
	if fontString.SetJustifyV then
		fontString:SetJustifyV("MIDDLE")
	end
	fontString:SetMaxLines(1)
	fontString:SetWordWrap(false)
	if GF.Font and GF.Font.Track then
		GF.Font.Track(fontString, "GameFontHighlightSmall")
	end
end

local function layoutCountFrame(frame)
	if not frame then
		return
	end
	local iconSize, numberWidth, iconGap, groupWidth = countMetrics()
	local slots = roleCountSlots(frame)
	for index, role in ipairs(ROLE_ORDER) do
		local slot = slots[role]
		local left = (index - 1) * (groupWidth + COUNT_GROUP_GAP)
		if slot and slot.num then
			slot.num:ClearAllPoints()
			formatCountFont(slot.num)
			slot.num:SetPoint("RIGHT", frame, "LEFT", left + numberWidth, 0)
			slot.num:Show()
		end
		if slot and slot.icon then
			slot.icon:ClearAllPoints()
			slot.icon:SetSize(iconSize, iconSize)
			slot.icon:SetPoint(
				"LEFT", frame, "LEFT", left + numberWidth + iconGap, 0)
			slot.icon:Show()
		end
	end
end

local function createFontString(parent)
	if GF.UI and type(GF.UI.CreateFontString) == "function" then
		return GF.UI.CreateFontString(
			parent, "OVERLAY", "GameFontHighlightSmall")
	end
	return parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
end

local function createManualCountFrame(parent)
	local iconSize, _, _, _, totalWidth = countMetrics()
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(totalWidth, iconSize)
	frame.parts = {}
	for _, role in ipairs(ROLE_ORDER) do
		local slot = {
			num = createFontString(frame),
			icon = frame:CreateTexture(nil, "ARTWORK"),
		}
		setRoleIcon(slot.icon, role)
		frame.parts[role] = slot
	end
	layoutCountFrame(frame)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT")
	return frame
end

local function createCountFrame(parent)
	prepareNativeWidgets()
	local ok, frame = pcall(
		CreateFrame, "Frame", nil, parent, "RoleCountNoScriptsTemplate")
	if ok and frame and frame.TankCount and frame.DamagerCount then
		local iconSize, _, _, _, totalWidth = countMetrics()
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT")
		frame:SetSize(totalWidth, iconSize)
		setRoleIcon(frame.TankIcon, "TANK")
		setRoleIcon(frame.HealerIcon, "HEALER")
		setRoleIcon(frame.DamagerIcon, "DAMAGER")
		layoutCountFrame(frame)
		return frame
	end
	if ok and frame and frame.Hide then
		frame:Hide()
	end
	return createManualCountFrame(parent)
end

local function layoutDisplay(display)
	if not display then
		return
	end
	local countHeight, _, _, _, countWidth = countMetrics()
	local iconSize, iconGap, maxIcons, memberWidth = memberMetrics()
	local roleBadgeSize = badgeSize()
	local effectiveScale = display.GetEffectiveScale and display:GetEffectiveScale() or 1
	local layout = display._gfRoleLayout
	if layout and layout.countHeight == countHeight and layout.countWidth == countWidth
		and layout.iconSize == iconSize and layout.iconGap == iconGap
		and layout.maxIcons == maxIcons and layout.memberWidth == memberWidth
		and layout.roleBadgeSize == roleBadgeSize and layout.effectiveScale == effectiveScale
	then
		return
	end
	-- Row binding and role painting share this fixed geometry. Keep data updates
	-- immediate without reanchoring every icon and retracking every count font.
	display:SetSize(math.max(countWidth, memberWidth),
		math.max(countHeight, iconSize, 18))

	if display.roleCount then
		display.roleCount:ClearAllPoints()
		display.roleCount:SetSize(countWidth, countHeight)
		display.roleCount:SetPoint("CENTER", display, "CENTER", 0, 0)
		layoutCountFrame(display.roleCount)
	end
	if display.meetingStoneRoles then
		local host = display.meetingStoneRoles
		host:ClearAllPoints()
		host:SetSize(memberWidth, iconSize)
		host:SetPoint("CENTER", display, "CENTER", 0, 0)
		for index = 1, maxIcons do
			local icon = host.icons[index]
			if icon then
				icon:ClearAllPoints()
				icon:SetSize(iconSize, iconSize)
				icon:SetPoint(
					"LEFT", host, "LEFT", (index - 1) * (iconSize + iconGap), 0)
			end
		end
	end
	if display.memberSpecs then
		local host = display.memberSpecs
		host:ClearAllPoints()
		host:SetSize(memberWidth, iconSize)
		host:SetPoint("CENTER", display, "CENTER", 0, 0)
		for index = 1, maxIcons do
			local slot = host.slots[index]
			if slot and slot.icon then
				slot.icon:ClearAllPoints()
				slot.icon:SetSize(iconSize, iconSize)
				slot.icon:SetPoint(
					"CENTER", host, "LEFT", (index - 1) * (iconSize + iconGap) + iconSize / 2, 0)
				if GF.UI and type(GF.UI.LayoutSpecializationIcon) == "function" then
					GF.UI.LayoutSpecializationIcon(slot.icon, {
						size = iconSize * (GF.LIST_SPECIALIZATION_ICON_SCALE or 0.8),
						outerSize = iconSize,
						ringStyle = GF.CLASS_SPECIALIZATION_RING_STYLE,
					})
					if not slot.icon._gfSpecIconActive then
						slot.icon:SetSize(iconSize, iconSize)
					end
				end
				if slot.roleBadge then
					slot.roleBadge:ClearAllPoints()
					slot.roleBadge:SetSize(roleBadgeSize, roleBadgeSize)
					slot.roleBadge:SetPoint(
						"TOPRIGHT", host, "LEFT",
						(index - 1) * (iconSize + iconGap) + iconSize + ROLE_BADGE_OFFSET_X,
						iconSize / 2 + ROLE_BADGE_OFFSET_Y)
				end
			end
		end
	end
	layout = layout or {}
	layout.countHeight, layout.countWidth = countHeight, countWidth
	layout.iconSize, layout.iconGap = iconSize, iconGap
	layout.maxIcons, layout.memberWidth = maxIcons, memberWidth
	layout.roleBadgeSize, layout.effectiveScale = roleBadgeSize, effectiveScale
	display._gfRoleLayout = layout
end

function RD:Create(parent)
	local display = CreateFrame("Frame", nil, parent)
	local parentLevel = parent and parent.GetFrameLevel and parent:GetFrameLevel() or 0
	display:SetFrameLevel((parentLevel or 0) + 4)

	display.roleCount = createCountFrame(display)
	display.roleCount:Hide()

	display.meetingStoneRoles = CreateFrame("Frame", nil, display)
	display.meetingStoneRoles.icons = {}
	display.meetingStoneRoles:Hide()
	display.memberSpecs = CreateFrame("Frame", nil, display)
	display.memberSpecs.slots = {}
	display.memberSpecs:Hide()

	local _, _, maxIcons = memberMetrics()
	for index = 1, maxIcons do
		local roleIcon = display.meetingStoneRoles:CreateTexture(nil, "OVERLAY")
		roleIcon:Hide()
		display.meetingStoneRoles.icons[index] = roleIcon
		local slot = {
			icon = display.memberSpecs:CreateTexture(nil, "OVERLAY"),
			roleBadge = display.memberSpecs:CreateTexture(nil, "OVERLAY", nil, 2),
		}
		slot.icon:Hide()
		slot.roleBadge:Hide()
		display.memberSpecs.slots[index] = slot
	end
	layoutDisplay(display)
	return display
end

function RD:Layout(display)
	layoutDisplay(display)
end

local function showSpecMembers(display, projection)
	display.roleCount:Hide()
	display.meetingStoneRoles:Hide()
	display.memberSpecs:Show()
	local _, _, maxIcons = memberMetrics()
	local members = sortedMembers(projection.players)
	for index = 1, maxIcons do
		paintSpecSlot(
			display.memberSpecs.slots[index],
			members[index] and members[index].value,
			projection)
	end
end

local function enumeratedRoles(projection, maxIcons)
	local roles = {}
	local function append(role, count)
		for _ = 1, count do
			if #roles >= maxIcons then
				return
			end
			roles[#roles + 1] = role
		end
	end
	for _, role in ipairs(ROLE_ORDER) do
		append(role, projection.counts[role])
	end
	local known = projection.counts.TANK
		+ projection.counts.HEALER + projection.counts.DAMAGER
	if known < projection.total then
		append("DAMAGER", projection.total - known)
	end
	return roles
end

local function showRoleMembers(display, projection)
	display.roleCount:Hide()
	display.memberSpecs:Hide()
	display.meetingStoneRoles:Show()
	local _, _, maxIcons = memberMetrics()
	local roles = enumeratedRoles(projection, maxIcons)
	for index = 1, maxIcons do
		local icon = display.meetingStoneRoles.icons[index]
		if roles[index] then
			setRoleIcon(icon, roles[index])
		else
			setEmptyIcon(icon)
		end
		icon:SetDesaturated(projection.disabled)
		icon:SetAlpha(projection.disabled and 0.5 or 1)
		icon:Show()
	end
end

local function showCounts(display, projection)
	display.meetingStoneRoles:Hide()
	display.memberSpecs:Hide()
	display.roleCount:Show()
	local countColor = projection.disabled
		and (LFG_LIST_DELISTED_FONT_COLOR or { r = 0.3, g = 0.3, b = 0.3 })
		or (HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 })
	for _, role in ipairs(ROLE_ORDER) do
		local slot = roleCountSlots(display.roleCount)[role]
		if slot and slot.num then
			slot.num:SetText(tostring(projection.counts[role]))
			slot.num:SetTextColor(
				countColor.r or countColor[1] or 1,
				countColor.g or countColor[2] or 1,
				countColor.b or countColor[3] or 1,
				countColor.a or countColor[4] or 1)
			slot.num:Show()
		end
		if slot and slot.icon then
			slot.icon:SetDesaturated(projection.disabled)
			slot.icon:SetAlpha(projection.disabled and 0.5 or 0.85)
			slot.icon:Show()
		end
	end
end

function RD:Update(display, snapshot, categoryID, opts)
	if not display then
		return
	end
	local projection = normalizeSnapshot(snapshot, opts)
	if not projection then
		display._gfRoleSnapshot = nil
		display:Hide()
		return
	end
	prepareNativeWidgets()
	display._gfRoleSnapshot = snapshot
	display._gfRoleCategoryID = categoryID
	layoutDisplay(display)
	display:Show()
	if projection.mode == "enumerate_specs" then
		showSpecMembers(display, projection)
	elseif projection.mode == "enumerate_roles" then
		showRoleMembers(display, projection)
	else
		showCounts(display, projection)
	end
end

function RD:CreateApplicantRoleStrip(parent)
	local strip = CreateFrame("Frame", nil, parent)
	local iconSize = select(1, memberMetrics())
	local gap = GF.BROWSE_ROW_MEMBER_ICON_GAP or 2
	strip:SetSize(iconSize * #ROLE_ORDER + gap * (#ROLE_ORDER - 1), iconSize)
	strip.icons = {}
	for index, role in ipairs(ROLE_ORDER) do
		local icon = strip:CreateTexture(nil, "ARTWORK")
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint(
			"LEFT", strip, "LEFT", (index - 1) * (iconSize + gap), 0)
		setRoleIcon(icon, role)
		icon:Hide()
		strip.icons[role] = icon
	end
	return strip
end

function RD:UpdateApplicantRoles(strip, members)
	if not (strip and type(strip.icons) == "table") then
		return
	end
	local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
	for _, member in ipairs(type(members) == "table" and members or {}) do
		if type(member) == "table" then
			local hasAvailability = false
			for flag, role in pairs({
				tank = "TANK", healer = "HEALER", damage = "DAMAGER",
			}) do
				if member[flag] == true then
					counts[role] = counts[role] + 1
					hasAvailability = true
				end
			end
			if not hasAvailability then
				local role = normalizeRole(member.assignedRole or member.role)
				if role then
					counts[role] = counts[role] + 1
				end
			end
		end
	end
	for _, role in ipairs(ROLE_ORDER) do
		local icon = strip.icons[role]
		if icon then
			local shown = counts[role] > 0
			icon:SetShown(shown)
			if shown then
				icon:SetDesaturated(false)
				icon:SetAlpha(1)
			end
		end
	end
end
