local _, GF = ...

-- 寻找队伍与申请者共用的职责数量、成员职责和专精图标投影。
GF.RoleDisplay = {}
local RD = GF.RoleDisplay

local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local SEASON_DUNGEON_ROLE_ATLAS = GF.SEASON_DUNGEON_ROLE_ATLAS
local ROLE_MICRO = SEASON_DUNGEON_ROLE_ATLAS
local ROLE_MICRO_FALLBACK = SEASON_DUNGEON_ROLE_ATLAS
local MEETINGSTONE_EMPTY_SLOT_ATLAS =
	GF.BROWSE_ROW_MEMBER_EMPTY_SLOT_ATLAS
	or SEASON_DUNGEON_ROLE_ATLAS.DEFAULT
local MEMBER_ROLE_PRIORITY = {
	TANK = 1,
	HEALER = 2,
	DAMAGER = 3,
}
local ROLE_COUNT_GAP = 0
local ROLE_COUNT_NUM_SLOT = 20
local ROLE_COUNT_NUM_PAD = GF.ROLE_COUNT_NUM_ICON_GAP or 5
local MEMBER_ROLE_BADGE_OFFSET_X =
	GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_X
	or GF.BROWSE_ROW_MEMBER_LEADER_BADGE_OFFSET_X
	or 2
local MEMBER_ROLE_BADGE_OFFSET_Y =
	GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_Y
	or GF.BROWSE_ROW_MEMBER_LEADER_BADGE_OFFSET_Y
	or 2

local function getMeetingStoneMemberMetrics()
	local iconSize =
		(GF.GetBrowseMemberIconSize and GF.GetBrowseMemberIconSize())
		or GF.BROWSE_ROW_MEMBER_ICON_SIZE
		or GF.ROLE_ICON_SIZE
		or 18
	local iconGap = GF.BROWSE_ROW_MEMBER_ICON_GAP or 2
	local maxIcons = GF.BROWSE_ROW_MEMBER_MAX_ICONS or 5
	return iconSize,
		iconGap,
		maxIcons,
		(iconSize * maxIcons)
			+ (iconGap * math.max(0, maxIcons - 1))
end

local function getMemberRoleBadgeSize()
	return
		(GF.GetBrowseMemberRoleBadgeSize
			and GF.GetBrowseMemberRoleBadgeSize())
		or GF.BROWSE_ROW_MEMBER_ROLE_BADGE_SIZE
		or GF.BROWSE_ROW_MEMBER_LEADER_BADGE_SIZE
		or 9
end

local function getRoleCountMetrics()
	local iconSize =
		(GF.GetRoleCountIconSize and GF.GetRoleCountIconSize())
		or GF.ROLE_COUNT_ICON_DEFAULT
		or GF.ROLE_ICON_SIZE
		or 18
	local numSlot = ROLE_COUNT_NUM_SLOT
	local numPad = ROLE_COUNT_NUM_PAD
	local groupW = numSlot + numPad + iconSize
	local totalW = groupW * 3 + ROLE_COUNT_GAP * 2
	return iconSize, numSlot, numPad, groupW, totalW
end

local groupFinderReady = false

local function EnsureGroupFinder()
	if groupFinderReady then
		return
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	groupFinderReady = true
end

local function SetRoleMicroIcon(tex, role)
	if not tex or not role then
		return
	end
	local atlas = ROLE_MICRO[role] or ROLE_MICRO_FALLBACK[role]
	if tex.SetAtlas and atlas then
		pcall(tex.SetAtlas, tex, atlas)
	end
end

local function trySetTextureAtlas(tex, atlas)
	if not tex or not tex.SetAtlas or not atlas then
		return false
	end
	local ok = pcall(tex.SetAtlas, tex, atlas)
	return ok == true
end

local function SetMeetingStoneRoleIcon(tex, role)
	if not tex or not role then
		return
	end
	SetRoleMicroIcon(tex, role)
end

local function SetMeetingStoneEmptySlotIcon(tex)
	if not tex then
		return
	end
	if not trySetTextureAtlas(tex, MEETINGSTONE_EMPTY_SLOT_ATLAS) then
		tex:SetAtlas(SEASON_DUNGEON_ROLE_ATLAS.DEFAULT)
	end
end

local function normalizeMemberRole(role)
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
	if role == "TANK"
		or role == "HEALER"
		or role == "DAMAGER"
	then
		return role
	end
end

local resolveMemberSpecIcon

local function getMemberRolePriority(member)
	local role =
		normalizeMemberRole(
			member and (member.assignedRole or member.role))
	if not role then
		local _, specRole = resolveMemberSpecIcon(member)
		role = specRole
	end
	return MEMBER_ROLE_PRIORITY[role] or 99
end

local function shouldShowSpecRoleBadge(role)
	if not role then
		return false
	end
	local mode =
		GF.GetMemberDisplayMode and GF.GetMemberDisplayMode()
	if (GF.IsMemberDisplaySpecLargeMode
			and GF.IsMemberDisplaySpecLargeMode(mode))
		or mode
			== (GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large")
	then
		return role == "TANK" or role == "HEALER"
	end
	return role == "TANK"
		or role == "HEALER"
		or role == "DAMAGER"
end

local function buildRoleSortedMembers(players)
	local sorted = {}
	for index, member in ipairs(players or {}) do
		sorted[#sorted + 1] = {
			index = index,
			member = member,
		}
	end
	table.sort(sorted, function(a, b)
		local aPriority = getMemberRolePriority(a.member)
		local bPriority = getMemberRolePriority(b.member)
		if aPriority ~= bPriority then
			return aPriority < bPriority
		end
		return a.index < b.index
	end)
	return sorted
end

local specIconCache = {}

resolveMemberSpecIcon = function(member)
	if not member then
		return nil
	end
	if GF.UI and GF.UI.ResolveSpecializationIcon then
		local cacheKey =
			tostring(member.classFilename or "")
				.. "|"
				.. tostring(member.specName or "")
		if specIconCache[cacheKey] ~= nil then
			local cached = specIconCache[cacheKey]
			return cached.icon, cached.role, cached.classFile
		end
		local icon, role, classFile =
			GF.UI.ResolveSpecializationIcon({
				classFile = member.classFilename,
				specName = member.specName,
				role = member.assignedRole or member.role,
			})
		specIconCache[cacheKey] = {
			icon = icon or false,
			role = role,
			classFile = classFile,
		}
		return icon, role, classFile
	end
	return nil
end

local function setMemberSpecSlot(slot, member, disabled)
	if not slot or not slot.icon then
		return
	end
	local icon, specRole, specClassFile =
		resolveMemberSpecIcon(member)
	if icon then
		if GF.UI and GF.UI.SetSpecializationIcon then
			GF.UI.SetSpecializationIcon(slot.icon, icon, {
				classFile =
					specClassFile
					or (member and member.classFilename),
				role =
					normalizeMemberRole(
						member
							and (member.assignedRole
								or member.role))
					or specRole,
				size =
					(GF.GetBrowseMemberIconSize
						and GF.GetBrowseMemberIconSize())
					or GF.BROWSE_ROW_MEMBER_ICON_SIZE
					or GF.ROLE_ICON_SIZE
					or 18,
				disabled = disabled,
			})
		else
			slot.icon:SetTexture(icon)
			slot.icon:SetTexCoord(0, 1, 0, 1)
		end
	else
		if GF.UI and GF.UI.ClearSpecializationIcon then
			GF.UI.ClearSpecializationIcon(slot.icon)
		end
		SetMeetingStoneEmptySlotIcon(slot.icon)
	end
	slot.icon:SetDesaturated(disabled)
	slot.icon:SetAlpha(disabled and 0.5 or 1)
	slot.icon:Show()
	if slot.roleBadge then
		local role =
			normalizeMemberRole(
				member
					and (member.assignedRole or member.role))
			or specRole
		if shouldShowSpecRoleBadge(role) then
			SetMeetingStoneRoleIcon(slot.roleBadge, role)
			slot.roleBadge:SetDesaturated(disabled)
			slot.roleBadge:Show()
			slot.roleBadge:SetAlpha(disabled and 0.5 or 1)
		else
			slot.roleBadge:Hide()
		end
	end
end

local function AddMeetingStoneRoleEntries(
	entries,
	role,
	count,
	maxIcons)
	count = tonumber(count) or 0
	for _ = 1, count do
		if #entries >= maxIcons then
			return
		end
		entries[#entries + 1] = role
	end
end

local function BuildMeetingStoneRoleEntries(entry, maxIcons)
	local entries = {}
	local counts =
		GF.Result
		and GF.Result.GetDisplayMemberCounts
		and GF.Result:GetDisplayMemberCounts(entry)
	if not counts and entry then
		counts = entry._displayCounts or {
			TANK = entry.tanks,
			HEALER = entry.heals,
			DAMAGER = entry.dps,
		}
	end
	AddMeetingStoneRoleEntries(
		entries,
		"TANK",
		counts and counts.TANK,
		maxIcons)
	AddMeetingStoneRoleEntries(
		entries,
		"HEALER",
		counts and counts.HEALER,
		maxIcons)
	AddMeetingStoneRoleEntries(
		entries,
		"DAMAGER",
		counts and counts.DAMAGER,
		maxIcons)
	local known =
		(tonumber(counts and counts.TANK) or 0)
		+ (tonumber(counts and counts.HEALER) or 0)
		+ (tonumber(counts and counts.DAMAGER) or 0)
	local total =
		entry
		and entry.info
		and tonumber(entry.info.numMembers)
		or known
	if known < total then
		AddMeetingStoneRoleEntries(
			entries,
			"DAMAGER",
			total - known,
			maxIcons)
	end
	return entries
end

local function fixRoleCountFontString(fs)
	if not fs then
		return
	end
	local iconSize, numSlot = getRoleCountMetrics()
	fs:SetWidth(numSlot)
	fs:SetHeight(iconSize)
	fs:SetJustifyH("RIGHT")
	if fs.SetJustifyV then
		fs:SetJustifyV("MIDDLE")
	end
	fs:SetMaxLines(1)
	fs:SetWordWrap(false)
end

local function layoutRoleCountGroup(f, count, icon, index)
	local iconSize, numberWidth, numberGap, groupWidth = getRoleCountMetrics()
	local left = (index - 1) * (groupWidth + ROLE_COUNT_GAP)
	if count ~= nil then
		count:ClearAllPoints()
		fixRoleCountFontString(count)
		count:SetPoint("RIGHT", f, "LEFT", left + numberWidth, 0)
		count:Show()
	end
	if icon ~= nil then
		icon:ClearAllPoints()
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("LEFT", f, "LEFT", left + numberWidth + numberGap, 0)
		icon:Show()
	end
end

local function layoutRoleCountFrame(f)
	if f == nil then
		return
	end
	local slots = f.parts
	if slots == nil then
		slots = {
			TANK = { num = f.TankCount, icon = f.TankIcon },
			HEALER = { num = f.HealerCount, icon = f.HealerIcon },
			DAMAGER = { num = f.DamagerCount, icon = f.DamagerIcon },
		}
	end
	for index, role in ipairs(ROLE_ORDER) do
		local slot = slots[role]
		if slot and (slot.num or slot.icon) then
			layoutRoleCountGroup(f, slot.num, slot.icon, index)
		end
	end
end

local function CreateRoleCountManual(parent)
	local iconSize, _, _, _, totalWidth = getRoleCountMetrics()
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(totalWidth, iconSize)
	frame.parts = {}
	for _, role in ipairs(ROLE_ORDER) do
		local slot = {
			num = GF.UI.CreateFontString(
				frame, "OVERLAY", "GameFontHighlightSmall"),
			icon = frame:CreateTexture(nil, "ARTWORK"),
		}
		SetRoleMicroIcon(slot.icon, role)
		frame.parts[role] = slot
	end
	layoutRoleCountFrame(frame)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT")
	return frame
end

local function trackRoleCountFonts(f)
	if not f or not GF.Font or not GF.Font.Track then
		return
	end
	for _, key in ipairs({
		"TankCount",
		"HealerCount",
		"DamagerCount",
	}) do
		local fs = f[key]
		if fs then
			GF.Font.Track(fs, "GameFontHighlightSmall")
		end
	end
end

local function CreateRoleCount(parent)
	EnsureGroupFinder()
	local f =
		CreateFrame(
			"Frame",
			nil,
			parent,
			"RoleCountNoScriptsTemplate")
	if f and f.TankCount and f.DamagerCount then
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		local iconSize, _, _, _, totalW =
			getRoleCountMetrics()
		f:SetSize(totalW, iconSize)
		SetRoleMicroIcon(f.TankIcon, "TANK")
		SetRoleMicroIcon(f.HealerIcon, "HEALER")
		SetRoleMicroIcon(f.DamagerIcon, "DAMAGER")
		layoutRoleCountFrame(f)
		trackRoleCountFonts(f)
		return f
	end
	return CreateRoleCountManual(parent)
end

local function layoutRoleDisplay(display)
	if not display then
		return
	end
	local countH, _, _, _, countW = getRoleCountMetrics()
	local memberIconSize, memberIconGap, maxIcons, memberRoleW =
		getMeetingStoneMemberMetrics()
	local totalW = math.max(countW, memberRoleW)
	local totalH = math.max(countH, memberIconSize, 18)

	if display.roleCount then
		display.roleCount:ClearAllPoints()
		display.roleCount:SetSize(countW, countH)
		display.roleCount:SetPoint(
			"CENTER",
			display,
			"CENTER",
			0,
			0)
		layoutRoleCountFrame(display.roleCount)
	end

	if display.meetingStoneRoles
		and display.meetingStoneRoles.icons
	then
		display.meetingStoneRoles:ClearAllPoints()
		display.meetingStoneRoles:SetSize(
			memberRoleW,
			memberIconSize)
		display.meetingStoneRoles:SetPoint(
			"CENTER",
			display,
			"CENTER",
			0,
			0)
		for i = 1, maxIcons do
			local icon = display.meetingStoneRoles.icons[i]
			if icon then
				icon:ClearAllPoints()
				icon:SetSize(memberIconSize, memberIconSize)
				icon:SetPoint(
					"LEFT",
					display.meetingStoneRoles,
					"LEFT",
					(i - 1)
						* (memberIconSize + memberIconGap),
					0)
			end
		end
	end

	if display.memberSpecs and display.memberSpecs.slots then
		display.memberSpecs:ClearAllPoints()
		display.memberSpecs:SetSize(
			memberRoleW,
			memberIconSize)
		display.memberSpecs:SetPoint(
			"CENTER",
			display,
			"CENTER",
			0,
			0)
		for i = 1, maxIcons do
			local slot = display.memberSpecs.slots[i]
			if slot and slot.icon then
				slot.icon:ClearAllPoints()
				slot.icon:SetSize(
					memberIconSize,
					memberIconSize)
				slot.icon:SetPoint(
					"LEFT",
					display.memberSpecs,
					"LEFT",
					(i - 1)
						* (memberIconSize + memberIconGap),
					0)
				if GF.UI and GF.UI.LayoutSpecializationIcon then
					GF.UI.LayoutSpecializationIcon(
						slot.icon,
						{ size = memberIconSize })
				end
				if slot.roleBadge then
					local badgeSize = getMemberRoleBadgeSize()
					slot.roleBadge:ClearAllPoints()
					slot.roleBadge:SetSize(
						badgeSize,
						badgeSize)
					slot.roleBadge:SetPoint(
						"TOPRIGHT",
						slot.icon,
						"TOPRIGHT",
						MEMBER_ROLE_BADGE_OFFSET_X,
						MEMBER_ROLE_BADGE_OFFSET_Y)
				end
			end
		end
	end

	display:SetWidth(totalW)
	display:SetHeight(totalH)
end

function RD:Create(parent)
	local root = CreateFrame("Frame", nil, parent)
	local parentLevel = parent:GetFrameLevel()
	root:SetFrameLevel(parentLevel + 4)
	root.roleCount = CreateRoleCount(root)
	root.roleCount:Hide()
	local meetingStoneRoles = CreateFrame("Frame", nil, root)
	meetingStoneRoles:SetPoint("LEFT", root, "LEFT")
	meetingStoneRoles.icons = {}
	root.meetingStoneRoles = meetingStoneRoles
	local _, _, maxIcons = getMeetingStoneMemberMetrics()
	for index = 1, maxIcons do
		local texture = meetingStoneRoles:CreateTexture(nil, "OVERLAY")
		texture:Hide()
		meetingStoneRoles.icons[index] = texture
	end
	meetingStoneRoles:Hide()
	local memberSpecs = CreateFrame("Frame", nil, root)
	memberSpecs:SetPoint("LEFT", root, "LEFT")
	memberSpecs.slots = {}
	root.memberSpecs = memberSpecs
	for index = 1, maxIcons do
		local slot = {
			icon = memberSpecs:CreateTexture(nil, "OVERLAY"),
			roleBadge = memberSpecs:CreateTexture(nil, "OVERLAY", nil, 2),
		}
		slot.icon:Hide()
		slot.roleBadge:Hide()
		memberSpecs.slots[index] = slot
	end
	memberSpecs:Hide()
	layoutRoleDisplay(root)
	return root
end

function RD:Layout(display)
	if display ~= nil then
		layoutRoleDisplay(display)
	end
end

local function showSpecializationMembers(display, entry, disabled)
	display.roleCount:Hide()
	display.meetingStoneRoles:Hide()
	display.memberSpecs:Show()
	local _, _, maxIcons = getMeetingStoneMemberMetrics()
	local players = buildRoleSortedMembers(entry.players)
	for index = 1, maxIcons do
		local item = players[index]
		setMemberSpecSlot(
			display.memberSpecs.slots[index],
			item and item.member,
			disabled)
	end
end

local function showEnumeratedRoles(display, entry, disabled)
	display.roleCount:Hide()
	display.memberSpecs:Hide()
	display.meetingStoneRoles:Show()
	local _, _, maxIcons = getMeetingStoneMemberMetrics()
	local roles = BuildMeetingStoneRoleEntries(entry, maxIcons)
	for index = 1, maxIcons do
		local icon = display.meetingStoneRoles.icons[index]
		if icon then
			local role = roles[index]
			if role then
				SetMeetingStoneRoleIcon(icon, role)
			else
				SetMeetingStoneEmptySlotIcon(icon)
			end
			icon:SetDesaturated(disabled == true)
			icon:SetAlpha(disabled and 0.5 or 1)
			icon:Show()
		end
	end
end

local function roleCountForEntry(entry, role)
	if role == "TANK" then return entry.tanks end
	if role == "HEALER" then return entry.heals end
	return entry.dps
end

local function showRoleCounts(display, entry, disabled)
	display.meetingStoneRoles:Hide()
	display.memberSpecs:Hide()
	local roleCount = display.roleCount
	roleCount:Show()
	GF.Result:EnsureMemberCounts(entry)
	local nativeSlots = {
		TANK = { num = roleCount.TankCount, icon = roleCount.TankIcon },
		HEALER = { num = roleCount.HealerCount, icon = roleCount.HealerIcon },
		DAMAGER = { num = roleCount.DamagerCount, icon = roleCount.DamagerIcon },
	}
	local slots = roleCount.TankCount and nativeSlots or roleCount.parts or {}
	for _, role in ipairs(ROLE_ORDER) do
		local slot = slots[role]
		if slot and slot.num then
			slot.num:SetText(tostring(roleCountForEntry(entry, role) or 0))
			slot.num:Show()
		end
		if slot and slot.icon then
			slot.icon:SetDesaturated(disabled == true)
			slot.icon:SetAlpha(disabled and 0.5 or 0.85)
			slot.icon:Show()
		end
	end
end

function RD:Update(display, entry, categoryID, opts)
	if display == nil or type(entry) ~= "table" or type(entry.info) ~= "table" then
		if display ~= nil then display:Hide() end
		return
	end
	local options = type(opts) == "table" and opts or {}
	EnsureGroupFinder()
	local disabled = options.disabled == true or entry.info.isDelisted == true
	local mode = options.mode or options.displayMode
		or GF.Result:GetRoleDisplayMode(entry)
	display:Show()
	if type(GF.Result.IsSpecEnumerateMode) == "function"
		and GF.Result:IsSpecEnumerateMode(mode)
	then
		showSpecializationMembers(display, entry, disabled)
	elseif GF.Result:IsEnumerateMode(mode) then
		showEnumeratedRoles(display, entry, disabled)
	else
		showRoleCounts(display, entry, disabled)
	end
end

function RD:CreateApplicantRoleStrip(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local iconSize = type(GF.GetBrowseMemberIconSize) == "function"
		and GF.GetBrowseMemberIconSize()
		or GF.BROWSE_ROW_MEMBER_ICON_SIZE
		or GF.ROLE_ICON_SIZE
		or 18
	local iconGap = GF.BROWSE_ROW_MEMBER_ICON_GAP or 2
	frame:SetSize(iconSize * #ROLE_ORDER + iconGap * (#ROLE_ORDER - 1), iconSize)
	frame.icons = {}
	for index, role in ipairs(ROLE_ORDER) do
		local texture = frame:CreateTexture(nil, "ARTWORK")
		texture:SetSize(iconSize, iconSize)
		texture:SetPoint("LEFT", frame, "LEFT", (index - 1) * (iconSize + iconGap), 0)
		SetRoleMicroIcon(texture, role)
		texture:Hide()
		frame.icons[role] = texture
	end
	return frame
end

function RD:UpdateApplicantRoles(strip, members)
	if strip == nil or type(strip.icons) ~= "table" then
		return
	end
	local counts = {}
	for _, role in ipairs(ROLE_ORDER) do
		counts[role] = 0
	end
	for _, member in ipairs(members or {}) do
		for flag, role in pairs({ tank = "TANK", healer = "HEALER", damage = "DAMAGER" }) do
			if member[flag] then
				counts[role] = counts[role] + 1
			end
		end
	end
	for _, role in ipairs(ROLE_ORDER) do
		local texture = strip.icons[role]
		if texture then
			local visible = counts[role] > 0
			texture:SetShown(visible)
			if visible then
				texture:SetDesaturated(false)
				texture:SetAlpha(1)
			end
		end
	end
end
