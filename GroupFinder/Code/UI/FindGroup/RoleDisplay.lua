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
	local iconSize, numSlot, numPad, groupW =
		getRoleCountMetrics()
	local x = (index - 1) * (groupW + ROLE_COUNT_GAP)
	if count then
		count:ClearAllPoints()
		fixRoleCountFontString(count)
		count:SetPoint("RIGHT", f, "LEFT", x + numSlot, 0)
		count:Show()
	end
	if icon then
		icon:ClearAllPoints()
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint(
			"LEFT",
			f,
			"LEFT",
			x + numSlot + numPad,
			0)
		icon:Show()
	end
end

local function layoutRoleCountFrame(f)
	if not f then
		return
	end
	if f.TankCount and f.TankIcon then
		layoutRoleCountGroup(f, f.TankCount, f.TankIcon, 1)
		layoutRoleCountGroup(
			f,
			f.HealerCount,
			f.HealerIcon,
			2)
		layoutRoleCountGroup(
			f,
			f.DamagerCount,
			f.DamagerIcon,
			3)
		return
	end
	if f.parts then
		for i, role in ipairs(ROLE_ORDER) do
			local slot = f.parts[role]
			if slot then
				layoutRoleCountGroup(
					f,
					slot.num,
					slot.icon,
					i)
			end
		end
	end
end

local function CreateRoleCountManual(parent)
	local iconSize, _, _, _, totalW = getRoleCountMetrics()
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(totalW, iconSize)
	f.parts = {}
	for _, role in ipairs(ROLE_ORDER) do
		local slot = {}
		slot.num =
			GF.UI.CreateFontString(
				f,
				"OVERLAY",
				"GameFontHighlightSmall")
		slot.icon = f:CreateTexture(nil, "ARTWORK")
		SetRoleMicroIcon(slot.icon, role)
		f.parts[role] = slot
	end
	layoutRoleCountFrame(f)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	return f
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

	display:SetSize(totalW, totalH)
end

function RD:Create(parent)
	local root = CreateFrame("Frame", nil, parent)
	root:SetFrameLevel(parent:GetFrameLevel() + 4)
	root.roleCount = CreateRoleCount(root)
	root.roleCount:Hide()
	root.meetingStoneRoles =
		CreateFrame("Frame", nil, root)
	root.meetingStoneRoles:SetPoint(
		"LEFT",
		root,
		"LEFT",
		0,
		0)
	root.meetingStoneRoles.icons = {}
	local _, _, maxIcons = getMeetingStoneMemberMetrics()
	for i = 1, maxIcons do
		local tex =
			root.meetingStoneRoles:CreateTexture(
				nil,
				"OVERLAY")
		tex:Hide()
		root.meetingStoneRoles.icons[i] = tex
	end
	root.meetingStoneRoles:Hide()
	root.memberSpecs = CreateFrame("Frame", nil, root)
	root.memberSpecs:SetPoint("LEFT", root, "LEFT", 0, 0)
	root.memberSpecs.slots = {}
	for i = 1, maxIcons do
		local slot = {}
		slot.icon =
			root.memberSpecs:CreateTexture(nil, "OVERLAY")
		slot.icon:Hide()
		slot.roleBadge =
			root.memberSpecs:CreateTexture(
				nil,
				"OVERLAY",
				nil,
				2)
		slot.roleBadge:Hide()
		root.memberSpecs.slots[i] = slot
	end
	root.memberSpecs:Hide()
	layoutRoleDisplay(root)
	return root
end

function RD:Layout(display)
	if not display then
		return
	end
	layoutRoleDisplay(display)
end

function RD:Update(display, entry, categoryID, opts)
	if not display or not entry or not entry.info then
		if display then
			display:Hide()
		end
		return
	end
	opts = type(opts) == "table" and opts or {}
	EnsureGroupFinder()
	local info = entry.info
	local disabled = opts.disabled or info.isDelisted
	local mode =
		opts.mode
		or opts.displayMode
		or GF.Result:GetRoleDisplayMode(entry)
	display:Show()
	if GF.Result.IsSpecEnumerateMode
		and GF.Result:IsSpecEnumerateMode(mode)
	then
		display.roleCount:Hide()
		if display.meetingStoneRoles then
			display.meetingStoneRoles:Hide()
		end
		display.memberSpecs:Show()
		local _, _, maxIcons =
			getMeetingStoneMemberMetrics()
		local players = buildRoleSortedMembers(entry.players)
		for i = 1, maxIcons do
			local item = players[i]
			setMemberSpecSlot(
				display.memberSpecs.slots[i],
				item and item.member,
				disabled)
		end
	elseif GF.Result:IsEnumerateMode(mode) then
		display.roleCount:Hide()
		if display.memberSpecs then
			display.memberSpecs:Hide()
		end
		display.meetingStoneRoles:Show()
		local _, _, maxIcons =
			getMeetingStoneMemberMetrics()
		local entries =
			BuildMeetingStoneRoleEntries(entry, maxIcons)
		for i = 1, maxIcons do
			local icon = display.meetingStoneRoles.icons[i]
			local role = entries[i]
			if icon and role then
				SetMeetingStoneRoleIcon(icon, role)
				icon:SetDesaturated(disabled)
				icon:SetAlpha(disabled and 0.5 or 1)
				icon:Show()
			elseif icon then
				SetMeetingStoneEmptySlotIcon(icon)
				icon:SetDesaturated(disabled)
				icon:SetAlpha(disabled and 0.5 or 1)
				icon:Show()
			end
		end
	else
		if display.meetingStoneRoles then
			display.meetingStoneRoles:Hide()
		end
		if display.memberSpecs then
			display.memberSpecs:Hide()
		end
		local rc = display.roleCount
		rc:Show()
		GF.Result:EnsureMemberCounts(entry)
		if rc.TankCount then
			rc.TankCount:SetText(tostring(entry.tanks))
			rc.HealerCount:SetText(tostring(entry.heals))
			rc.DamagerCount:SetText(tostring(entry.dps))
			if rc.TankIcon then
				rc.TankIcon:SetDesaturated(disabled)
				rc.TankIcon:SetAlpha(
					disabled and 0.5 or 0.85)
			end
			if rc.HealerIcon then
				rc.HealerIcon:SetDesaturated(disabled)
				rc.HealerIcon:SetAlpha(
					disabled and 0.5 or 0.85)
			end
			if rc.DamagerIcon then
				rc.DamagerIcon:SetDesaturated(disabled)
				rc.DamagerIcon:SetAlpha(
					disabled and 0.5 or 0.85)
			end
		elseif rc.parts then
			for _, role in ipairs(ROLE_ORDER) do
				local part = rc.parts[role]
				if part and part.num then
					local n =
						role == "TANK"
							and entry.tanks
						or (role == "HEALER"
							and entry.heals
							or entry.dps)
					part.num:SetText(tostring(n))
					part.num:Show()
					if part.icon then
						part.icon:Show()
					end
				end
			end
		end
	end
end

function RD:CreateApplicantRoleStrip(parent)
	local f = CreateFrame("Frame", nil, parent)
	local iconSize =
		(GF.GetBrowseMemberIconSize
			and GF.GetBrowseMemberIconSize())
		or GF.BROWSE_ROW_MEMBER_ICON_SIZE
		or GF.ROLE_ICON_SIZE
		or 18
	local iconGap = GF.BROWSE_ROW_MEMBER_ICON_GAP or 2
	f:SetSize((iconSize * 3) + (iconGap * 2), iconSize)
	f.icons = {}
	for i, role in ipairs(ROLE_ORDER) do
		local tex = f:CreateTexture(nil, "ARTWORK")
		tex:SetSize(iconSize, iconSize)
		tex:SetPoint(
			"LEFT",
			f,
			"LEFT",
			(i - 1) * (iconSize + iconGap),
			0)
		SetRoleMicroIcon(tex, role)
		tex:Hide()
		f.icons[role] = tex
	end
	return f
end

function RD:UpdateApplicantRoles(strip, members)
	if not strip or not strip.icons then
		return
	end
	local counts = {
		TANK = 0,
		HEALER = 0,
		DAMAGER = 0,
	}
	for _, member in ipairs(members or {}) do
		if member.tank then
			counts.TANK = counts.TANK + 1
		end
		if member.healer then
			counts.HEALER = counts.HEALER + 1
		end
		if member.damage then
			counts.DAMAGER = counts.DAMAGER + 1
		end
	end
	for _, role in ipairs(ROLE_ORDER) do
		local tex = strip.icons[role]
		if tex then
			local n = counts[role] or 0
			tex:SetShown(n > 0)
			if n > 0 then
				tex:SetDesaturated(false)
				tex:SetAlpha(1)
			end
		end
	end
end
