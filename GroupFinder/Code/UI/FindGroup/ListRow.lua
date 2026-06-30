local _, GF = ...

GF.RoleDisplay = {}
local RD = GF.RoleDisplay

-- [ListRow] 1/5 RoleDisplay：职责区、成员图标与申请者职责条

local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local SEASON_DUNGEON_ROLE_ATLAS = GF.SEASON_DUNGEON_ROLE_ATLAS or GF.ROLE_ICON_ATLAS or {
	LEADER = "UI-LFG-RoleIcon-Leader",
	GUIDE = "UI-LFG-RoleIcon-Leader",
	TANK = "UI-LFG-RoleIcon-Tank",
	HEALER = "UI-LFG-RoleIcon-Healer",
	DAMAGER = "UI-LFG-RoleIcon-DPS",
	DPS = "UI-LFG-RoleIcon-DPS",
	NONE = "groupfinder-icon-emptyslot",
	DEFAULT = "groupfinder-icon-emptyslot",
}
local ROLE_MICRO = SEASON_DUNGEON_ROLE_ATLAS
local ROLE_MICRO_FALLBACK = SEASON_DUNGEON_ROLE_ATLAS
local MEETINGSTONE_EMPTY_SLOT_ATLAS = GF.BROWSE_ROW_MEMBER_EMPTY_SLOT_ATLAS or SEASON_DUNGEON_ROLE_ATLAS.DEFAULT or "groupfinder-icon-emptyslot"
local MEMBER_ROLE_PRIORITY = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local ROLE_COUNT_GAP = 0
local ROLE_COUNT_NUM_SLOT = 20
local ROLE_COUNT_NUM_PAD = GF.ROLE_COUNT_NUM_ICON_GAP or 5
local MEMBER_ICON_PATH = "Interface\\AddOns\\GroupFinder\\Art\\UI\\Icon\\"
local MEMBER_ROLE_BADGE_OFFSET_X = GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_X or GF.BROWSE_ROW_MEMBER_LEADER_BADGE_OFFSET_X or 2
local MEMBER_ROLE_BADGE_OFFSET_Y = GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_Y or GF.BROWSE_ROW_MEMBER_LEADER_BADGE_OFFSET_Y or 2
local APPLICATION_TIMEOUT_SECONDS = 5 * 60
local APPLICATION_PENDING_TEXT_COLOR = { r = 0.12, g = 1, b = 0.25, a = 1 }
local APPLICATION_DECLINED_TEXT_COLOR = { r = 1, g = 0.18, b = 0.12, a = 1 }
local APPLICATION_CANCELLED_TEXT_COLOR = { r = 0.55, g = 0.55, b = 0.55, a = 1 }
local APPLICATION_ALERT_ICON_TEXTURE = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew.blp"
local APPLICATION_CANCEL_BUTTON_SIZE = 24
local APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE = APPLICATION_CANCEL_BUTTON_SIZE
local APPLICATION_CANCEL_BUTTON_ICON_SIZE = 16
local APPLICATION_CANCEL_BUTTON_GAP = 4
local APPLICATION_CANCEL_BUTTON_ATLAS = "UI-LFG-DeclineMark"
local APPLICATION_CANCEL_BUTTON_TEXTURE = GF.COMMON_BUTTON_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\RedButton.png"
local APPLICATION_CANCEL_BUTTON_ATLAS_W = 392
local APPLICATION_CANCEL_BUTTON_ATLAS_H = 168
local APPLICATION_CANCEL_BUTTON_SLICE = { 344 / APPLICATION_CANCEL_BUTTON_ATLAS_W, 392 / APPLICATION_CANCEL_BUTTON_ATLAS_W }
local APPLICATION_CANCEL_BUTTON_STATES = {
	normal = { 0, 48 / APPLICATION_CANCEL_BUTTON_ATLAS_H },
	highlight = { 60 / APPLICATION_CANCEL_BUTTON_ATLAS_H, 108 / APPLICATION_CANCEL_BUTTON_ATLAS_H },
	pressed = { 120 / APPLICATION_CANCEL_BUTTON_ATLAS_H, 168 / APPLICATION_CANCEL_BUTTON_ATLAS_H },
}
local APPLICATION_STATUS_ICON_SIZE = 16
local APPLICATION_STATUS_ICON_GAP = 3
local APPLICATION_STATUS_TEXT_OFFSET_X = -6
local APPLICATION_PENDING_SPINNER_SIZE = 18
local lastTooltipResultID
local cancelHoverTooltipHide

local function getMeetingStoneMemberMetrics()
	local iconSize = (GF.GetBrowseMemberIconSize and GF.GetBrowseMemberIconSize())
		or GF.BROWSE_ROW_MEMBER_ICON_SIZE or GF.ROLE_ICON_SIZE or 18
	local iconGap = GF.BROWSE_ROW_MEMBER_ICON_GAP or 2
	local maxIcons = GF.BROWSE_ROW_MEMBER_MAX_ICONS or 5
	return iconSize, iconGap, maxIcons, (iconSize * maxIcons) + (iconGap * math.max(0, maxIcons - 1))
end

local function getMemberRoleBadgeSize()
	return (GF.GetBrowseMemberRoleBadgeSize and GF.GetBrowseMemberRoleBadgeSize())
		or GF.BROWSE_ROW_MEMBER_ROLE_BADGE_SIZE
		or GF.BROWSE_ROW_MEMBER_LEADER_BADGE_SIZE
		or 9
end

local function getRoleCountMetrics()
	local iconSize = (GF.GetRoleCountIconSize and GF.GetRoleCountIconSize()) or GF.ROLE_COUNT_ICON_DEFAULT or GF.ROLE_ICON_SIZE or 18
	local numSlot = ROLE_COUNT_NUM_SLOT
	local numPad = ROLE_COUNT_NUM_PAD
	local groupW = numSlot + numPad + iconSize
	local totalW = groupW * 3 + ROLE_COUNT_GAP * 2
	return iconSize, numSlot, numPad, groupW, totalW
end
local groupFinderReady = false

local CLASS_ID_BY_FILE = {
	WARRIOR = 1,
	PALADIN = 2,
	HUNTER = 3,
	ROGUE = 4,
	PRIEST = 5,
	DEATHKNIGHT = 6,
	SHAMAN = 7,
	MAGE = 8,
	WARLOCK = 9,
	MONK = 10,
	DRUID = 11,
	DEMONHUNTER = 12,
	EVOKER = 13,
}

local SPEC_ICON_BY_ID = {
	[62] = "Mage_Arcane_Spell_Holy_MagicalSentry.png",
	[63] = "Mage_Fire_Spell_Fire_FireBolt02.png",
	[64] = "Mage_Frost_Spell_Frost_FrostBolt02.png",
	[65] = "Paladin_Holy_Spell_Holy_HolyBolt.png",
	[66] = "Paladin_Protection_Ability_Paladin_ShieldoftheTemplar.png",
	[70] = "Paladin_Retribution_Spell_Holy_AuraOfLight.png",
	[71] = "Warrior_Arms_Ability_Warrior_SavageBlow.png",
	[72] = "Warrior_Fury_Ability_Warrior_InnerRage.png",
	[73] = "Warrior_Protection_Ability_Warrior_DefensiveStance.png",
	[102] = "Druid_Balance_Spell_Nature_StarFall.png",
	[103] = "Druid_Feral_Ability_Druid_CatForm.png",
	[104] = "Druid_Guardian_Ability_Racial_BearForm.png",
	[105] = "Druid_Restoration_SPELL_NATURE_HEALINGTOUCH.png",
	[250] = "DeathKnight_Blood_Spell_Deathknight_BloodPresence.png",
	[251] = "DeathKnight_Frost_Spell_Deathknight_FrostPresence.png",
	[252] = "DeathKnight_Unholy_Spell_Deathknight_UnholyPresence.png",
	[253] = "Hunter_BeastMastery_Ability_Hunter_BeastTaming.png",
	[254] = "Hunter_Marksmanship_Ability_Hunter_FocusedAim.png",
	[255] = "Hunter_Survival_Ability_Hunter_Camouflage.png",
	[256] = "Priest_Discipline_Spell_Holy_PowerWordShield.png",
	[257] = "Priest_Holy_Spell_Holy_GuardianSpirit.png",
	[258] = "Priest_Shadow_Spell_Shadow_ShadowWordPain.png",
	[259] = "Rogue_Assassination_Ability_Rogue_DeadlyBrew.png",
	[260] = "Rogue_Outlaw_INV_Sword_30.png",
	[261] = "Rogue_Subtlety_Ability_Stealth.png",
	[262] = "Shaman_Elemental_Spell_Nature_Lightning.png",
	[263] = "Shaman_Enhancement_Spell_Nature_LightningShield.png",
	[264] = "Shaman_Restoration_Spell_Nature_MagicImmunity.png",
	[265] = "Warlock_Affliction_Spell_Shadow_DeathCoil.png",
	[266] = "Warlock_Demonology_Spell_Shadow_Metamorphosis.png",
	[267] = "Warlock_Destruction_Spell_Shadow_RainOfFire.png",
	[268] = "Monk_Brewmaster_Spell_Monk_Brewmaster_Spec.png",
	[269] = "Monk_Windwalker_Spell_Monk_WindWalker_Spec.png",
	[270] = "Monk_Mistweaver_Spell_Monk_MistWeaver_Spec.png",
	[577] = "DemonHunter_Havoc_Ability_DemonHunter_SpecDPS.png",
	[581] = "DemonHunter_Vengeance_Ability_DemonHunter_SpecTank.png",
	[1467] = "Evoker_Devastation_ClassIcon_Evoker_Devastation.png",
	[1468] = "Evoker_Preservation_ClassIcon_Evoker_Preservation.png",
	[1473] = "Evoker_Augmentation_ClassIcon_Evoker_Augmentation.png",
	[1480] = "DemonHunter_Devourer_Classicon_DemonHunter_Void.png",
}

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
		tex:SetAtlas("groupfinder-icon-emptyslot")
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
	if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
		return role
	end
end

local function getMemberRolePriority(member)
	local role = normalizeMemberRole(member and (member.assignedRole or member.role))
	return MEMBER_ROLE_PRIORITY[role] or 99
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

local function getClassFallbackIcon(classFile)
	if type(classFile) ~= "string" or classFile == "" then
		return nil
	end
	return MEMBER_ICON_PATH .. string.lower(classFile) .. "_flatborder2.tga"
end

local function resolveMemberSpecIcon(member)
	if not member then
		return nil
	end
	local classFile = type(member.classFilename) == "string" and member.classFilename:upper() or nil
	local specName = type(member.specName) == "string" and member.specName or nil
	if classFile and specName and specName ~= "" then
		local cacheKey = classFile .. "|" .. specName
		if specIconCache[cacheKey] ~= nil then
			return specIconCache[cacheKey]
		end
		local classID = CLASS_ID_BY_FILE[classFile]
		if classID and GetSpecializationInfoForClassID then
			for i = 1, 4 do
				local ok, specID, localizedName, _, apiIcon = pcall(GetSpecializationInfoForClassID, classID, i)
				if ok and localizedName == specName then
					local localIcon = SPEC_ICON_BY_ID[tonumber(specID)]
					local resolved = localIcon and (MEMBER_ICON_PATH .. localIcon) or apiIcon
					specIconCache[cacheKey] = resolved or false
					return resolved
				end
			end
		end
		local fallbackIcon = getClassFallbackIcon(classFile)
		specIconCache[cacheKey] = fallbackIcon or false
		return fallbackIcon
	end
	return getClassFallbackIcon(classFile)
end

local function setMemberSpecSlot(slot, member, disabled)
	if not slot or not slot.icon then
		return
	end
	local icon = resolveMemberSpecIcon(member)
	if icon then
		slot.icon:SetTexture(icon)
		slot.icon:SetTexCoord(0, 1, 0, 1)
	else
		SetMeetingStoneEmptySlotIcon(slot.icon)
	end
	slot.icon:SetDesaturated(disabled)
	slot.icon:SetAlpha(disabled and 0.5 or 1)
	slot.icon:Show()
	if slot.roleBadge then
		local role = normalizeMemberRole(member and (member.assignedRole or member.role))
		if role then
			SetMeetingStoneRoleIcon(slot.roleBadge, role)
			slot.roleBadge:SetDesaturated(disabled)
			slot.roleBadge:Show()
			slot.roleBadge:SetAlpha(disabled and 0.5 or 1)
		else
			slot.roleBadge:Hide()
		end
	end
end

local function CreateApplicationPendingSpinner(parent)
	if GF.UI and GF.UI.CreatePendingSpinner then
		return GF.UI.CreatePendingSpinner(parent, APPLICATION_PENDING_SPINNER_SIZE)
	end
end

local function StopApplicationPendingSpinner(spinner)
	if GF.UI and GF.UI.StopPendingSpinner then
		GF.UI.StopPendingSpinner(spinner)
	end
end

local function StartApplicationPendingSpinner(spinner)
	if GF.UI and GF.UI.StartPendingSpinner then
		GF.UI.StartPendingSpinner(spinner, APPLICATION_PENDING_SPINNER_SIZE)
	end
end

local function AnchorApplicationCancelButtonIcon(button, x, y)
	local icon = button and button._gfCancelIcon
	if not icon then
		return
	end
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", button, "CENTER", x or 0, y or 0)
end

local function SetApplicationCancelButtonTexture(button, state)
	local bg = button and button._gfCancelBg
	if not bg then
		return
	end
	local y = APPLICATION_CANCEL_BUTTON_STATES[state or "normal"] or APPLICATION_CANCEL_BUTTON_STATES.normal
	bg:SetTexCoord(APPLICATION_CANCEL_BUTTON_SLICE[1], APPLICATION_CANCEL_BUTTON_SLICE[2], y[1], y[2])
end

local function UpdateApplicationCancelButtonState(button)
	if not button then
		return
	end
	local enabled = not button.IsEnabled or button:IsEnabled()
	local state = "normal"
	if enabled and button._gfCancelPressed then
		state = "pressed"
	elseif enabled and button._gfCancelHovered then
		state = "highlight"
	end
	SetApplicationCancelButtonTexture(button, state)
	if button._gfCancelBg then
		button._gfCancelBg:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
	end
	if button._gfCancelIcon then
		button._gfCancelIcon:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
	end
end

local function CreateApplicationCancelButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(APPLICATION_CANCEL_BUTTON_SIZE, APPLICATION_CANCEL_BUTTON_SIZE)
	button:SetFrameLevel((parent:GetFrameLevel() or 1) + 4)
	button:SetPoint("CENTER", parent, "CENTER", 0, 0)
	button:RegisterForClicks("LeftButtonUp")
	button:SetText("")
	button:Hide()
	local label = button.Text or (button.GetFontString and button:GetFontString())
	if label then
		label:SetText("")
		label:Hide()
	end
	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(button)
	bg:SetTexture(APPLICATION_CANCEL_BUTTON_TEXTURE)
	bg:SetVertexColor(1, 1, 1, 1)
	bg:SetAlpha(1)
	bg:Show()
	button._gfCancelBg = bg
	SetApplicationCancelButtonTexture(button, "normal")

	local icon = button:CreateTexture(nil, "OVERLAY", nil, 2)
	icon:SetSize(APPLICATION_CANCEL_BUTTON_ICON_SIZE, APPLICATION_CANCEL_BUTTON_ICON_SIZE)
	icon:SetVertexColor(1, 1, 1, 1)
	if not trySetTextureAtlas(icon, APPLICATION_CANCEL_BUTTON_ATLAS) then
		icon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
		icon:SetTexCoord(0, 1, 0, 1)
	end
	button._gfCancelIcon = icon
	AnchorApplicationCancelButtonIcon(button, 0, 0)
	button:SetScript("OnEnter", function(self)
		self._gfCancelHovered = true
		UpdateApplicationCancelButtonState(self)
		if cancelHoverTooltipHide then
			cancelHoverTooltipHide()
		end
		lastTooltipResultID = nil
		local L = GF.L or {}
		if GameTooltip then
			GameTooltip:Hide()
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.APPLY_CANCEL_APPLICATION or LFG_LIST_CANCEL_APPLICATION or "取消申请")
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		self._gfCancelHovered = nil
		self._gfCancelPressed = nil
		UpdateApplicationCancelButtonState(self)
		AnchorApplicationCancelButtonIcon(self, 0, 0)
		if GameTooltip and GameTooltip.GetOwner then
			if GameTooltip:GetOwner() == self then
				GameTooltip:Hide()
			end
		elseif GameTooltip_Hide then
			GameTooltip_Hide()
		end
	end)
	button:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton" then
			self._gfCancelPressed = true
			UpdateApplicationCancelButtonState(self)
			AnchorApplicationCancelButtonIcon(self, 1, -1)
		end
	end)
	button:SetScript("OnMouseUp", function(self)
		self._gfCancelPressed = nil
		UpdateApplicationCancelButtonState(self)
		AnchorApplicationCancelButtonIcon(self, 0, 0)
	end)
	button:SetScript("OnEnable", UpdateApplicationCancelButtonState)
	button:SetScript("OnDisable", UpdateApplicationCancelButtonState)
	button:SetScript("OnClick", function(self)
		local row = self._gfRow
		local resultID = tonumber(self.resultID or (row and row.resultID))
		if not resultID then
			return
		end
		local ok, reason
		if GF.Apply and GF.Apply.CancelApplication then
			ok, reason = GF.Apply:CancelApplication(resultID)
		elseif C_LFGList and C_LFGList.CancelApplication then
			ok, reason = pcall(C_LFGList.CancelApplication, resultID)
		end
		if ok == false and reason and GF.ShowWarningMessage then
			GF.ShowWarningMessage(tostring(reason))
		end
	end)
	UpdateApplicationCancelButtonState(button)
	return button
end

local function AddMeetingStoneRoleEntries(entries, role, count, maxIcons)
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
	local counts = GF.Result and GF.Result.GetDisplayMemberCounts and GF.Result:GetDisplayMemberCounts(entry)
	AddMeetingStoneRoleEntries(entries, "TANK", counts and counts.TANK, maxIcons)
	AddMeetingStoneRoleEntries(entries, "HEALER", counts and counts.HEALER, maxIcons)
	AddMeetingStoneRoleEntries(entries, "DAMAGER", counts and counts.DAMAGER, maxIcons)
	local known = (tonumber(counts and counts.TANK) or 0) + (tonumber(counts and counts.HEALER) or 0) + (tonumber(counts and counts.DAMAGER) or 0)
	local total = entry and entry.info and tonumber(entry.info.numMembers) or known
	if known < total then
		AddMeetingStoneRoleEntries(entries, "DAMAGER", total - known, maxIcons)
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
	local iconSize, numSlot, numPad, groupW = getRoleCountMetrics()
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
		icon:SetPoint("LEFT", f, "LEFT", x + numSlot + numPad, 0)
		icon:Show()
	end
end

local function layoutRoleCountFrame(f)
	if not f then
		return
	end
	if f.TankCount and f.TankIcon then
		layoutRoleCountGroup(f, f.TankCount, f.TankIcon, 1)
		layoutRoleCountGroup(f, f.HealerCount, f.HealerIcon, 2)
		layoutRoleCountGroup(f, f.DamagerCount, f.DamagerIcon, 3)
		return
	end
	if f.parts then
		for i, role in ipairs(ROLE_ORDER) do
			local slot = f.parts[role]
			if slot then
				layoutRoleCountGroup(f, slot.num, slot.icon, i)
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
		slot.num = GF.UI.CreateFontString(f, "OVERLAY", "GameFontHighlightSmall")
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
	for _, key in ipairs({ "TankCount", "HealerCount", "DamagerCount" }) do
		local fs = f[key]
		if fs then
			GF.Font.Track(fs, "GameFontHighlightSmall")
		end
	end
end

local function CreateRoleCount(parent)
	EnsureGroupFinder()
	local f = CreateFrame("Frame", nil, parent, "RoleCountNoScriptsTemplate")
	if f and f.TankCount and f.DamagerCount then
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		local iconSize, _, _, _, totalW = getRoleCountMetrics()
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
	local memberIconSize, memberIconGap, maxIcons, memberRoleW = getMeetingStoneMemberMetrics()
	local totalW = math.max(countW, memberRoleW)
	local totalH = math.max(countH, memberIconSize, 18)

	if display.roleCount then
		display.roleCount:ClearAllPoints()
		display.roleCount:SetSize(countW, countH)
		display.roleCount:SetPoint("CENTER", display, "CENTER", 0, 0)
		layoutRoleCountFrame(display.roleCount)
	end

	if display.meetingStoneRoles and display.meetingStoneRoles.icons then
		display.meetingStoneRoles:ClearAllPoints()
		display.meetingStoneRoles:SetSize(memberRoleW, memberIconSize)
		display.meetingStoneRoles:SetPoint("CENTER", display, "CENTER", 0, 0)
		for i = 1, maxIcons do
			local icon = display.meetingStoneRoles.icons[i]
			if icon then
				icon:ClearAllPoints()
				icon:SetSize(memberIconSize, memberIconSize)
				icon:SetPoint("LEFT", display.meetingStoneRoles, "LEFT", (i - 1) * (memberIconSize + memberIconGap), 0)
			end
		end
	end

	if display.memberSpecs and display.memberSpecs.slots then
		display.memberSpecs:ClearAllPoints()
		display.memberSpecs:SetSize(memberRoleW, memberIconSize)
		display.memberSpecs:SetPoint("CENTER", display, "CENTER", 0, 0)
		for i = 1, maxIcons do
			local slot = display.memberSpecs.slots[i]
			if slot and slot.icon then
				slot.icon:ClearAllPoints()
				slot.icon:SetSize(memberIconSize, memberIconSize)
				slot.icon:SetPoint("LEFT", display.memberSpecs, "LEFT", (i - 1) * (memberIconSize + memberIconGap), 0)
				if slot.roleBadge then
					local badgeSize = getMemberRoleBadgeSize()
					slot.roleBadge:ClearAllPoints()
					slot.roleBadge:SetSize(badgeSize, badgeSize)
					slot.roleBadge:SetPoint("TOPRIGHT", slot.icon, "TOPRIGHT", MEMBER_ROLE_BADGE_OFFSET_X, MEMBER_ROLE_BADGE_OFFSET_Y)
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
	root.meetingStoneRoles = CreateFrame("Frame", nil, root)
	root.meetingStoneRoles:SetPoint("LEFT", root, "LEFT", 0, 0)
	root.meetingStoneRoles.icons = {}
	local _, _, maxIcons = getMeetingStoneMemberMetrics()
	for i = 1, maxIcons do
		local tex = root.meetingStoneRoles:CreateTexture(nil, "OVERLAY")
		tex:Hide()
		root.meetingStoneRoles.icons[i] = tex
	end
	root.meetingStoneRoles:Hide()
	root.memberSpecs = CreateFrame("Frame", nil, root)
	root.memberSpecs:SetPoint("LEFT", root, "LEFT", 0, 0)
	root.memberSpecs.slots = {}
	for i = 1, maxIcons do
		local slot = {}
		slot.icon = root.memberSpecs:CreateTexture(nil, "OVERLAY")
		slot.icon:Hide()
		slot.roleBadge = root.memberSpecs:CreateTexture(nil, "OVERLAY", nil, 2)
		slot.roleBadge:Hide()
		root.memberSpecs.slots[i] = slot
	end
	root.memberSpecs:Hide()
	layoutRoleDisplay(root)
	return root
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
	local mode = GF.Result:GetRoleDisplayMode(entry)
	display:Show()
	if GF.Result.IsSpecEnumerateMode and GF.Result:IsSpecEnumerateMode(mode) then
		display.roleCount:Hide()
		if display.meetingStoneRoles then
			display.meetingStoneRoles:Hide()
		end
		display.memberSpecs:Show()
		local _, _, maxIcons = getMeetingStoneMemberMetrics()
		local players = buildRoleSortedMembers(entry.players)
		for i = 1, maxIcons do
			local item = players[i]
			setMemberSpecSlot(display.memberSpecs.slots[i], item and item.member, disabled)
		end
	elseif GF.Result:IsEnumerateMode(mode) then
		display.roleCount:Hide()
		if display.memberSpecs then
			display.memberSpecs:Hide()
		end
		display.meetingStoneRoles:Show()
		local _, _, maxIcons = getMeetingStoneMemberMetrics()
		local entries = BuildMeetingStoneRoleEntries(entry, maxIcons)
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
				rc.TankIcon:SetAlpha(disabled and 0.5 or 0.85)
			end
			if rc.HealerIcon then
				rc.HealerIcon:SetDesaturated(disabled)
				rc.HealerIcon:SetAlpha(disabled and 0.5 or 0.85)
			end
			if rc.DamagerIcon then
				rc.DamagerIcon:SetDesaturated(disabled)
				rc.DamagerIcon:SetAlpha(disabled and 0.5 or 0.85)
			end
		elseif rc.parts then
			for _, role in ipairs(ROLE_ORDER) do
				local part = rc.parts[role]
				if part and part.num then
					local n = role == "TANK" and entry.tanks or (role == "HEALER" and entry.heals or entry.dps)
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
	local iconSize = (GF.GetBrowseMemberIconSize and GF.GetBrowseMemberIconSize())
		or GF.BROWSE_ROW_MEMBER_ICON_SIZE or GF.ROLE_ICON_SIZE or 18
	local iconGap = GF.BROWSE_ROW_MEMBER_ICON_GAP or 2
	f:SetSize((iconSize * 3) + (iconGap * 2), iconSize)
	f.icons = {}
	for i, role in ipairs(ROLE_ORDER) do
		local tex = f:CreateTexture(nil, "ARTWORK")
		tex:SetSize(iconSize, iconSize)
		tex:SetPoint("LEFT", f, "LEFT", (i - 1) * (iconSize + iconGap), 0)
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
	local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
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

GF.ListRow = {}
local LR = GF.ListRow

-- [ListRow] 2/5 ListRow 模块与固定行视觉
local ROW_TEXTURE_NORMAL = GF.BROWSE_ROW_TEXTURE_NORMAL or "Interface\\AddOns\\GroupFinder\\Art\\UI\\ApplicantRowNormal.png"
local ROW_TEXTURE_GREEN = GF.BROWSE_ROW_TEXTURE_GREEN or "Interface\\AddOns\\GroupFinder\\Art\\UI\\ApplicantRowGreen.png"
local ROW_TEXTURE_RED = GF.BROWSE_ROW_TEXTURE_RED or "Interface\\AddOns\\GroupFinder\\Art\\UI\\ApplicantRowRed.png"
local ROW_TEXTURE_BLUE = GF.BROWSE_ROW_TEXTURE_BLUE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\ApplicantRowBlue.png"
local ROW_TEXTURE_GREY = GF.BROWSE_ROW_TEXTURE_GREY or "Interface\\AddOns\\GroupFinder\\Art\\UI\\ApplicantRowGrey.png"
local ROW_BACKGROUND_ALPHA = GF.BROWSE_ROW_BACKGROUND_ALPHA or 0.92
local ROW_BACKGROUND_FADE_SECONDS = GF.BROWSE_ROW_BACKGROUND_FADE_SECONDS or 0.16
local ROW_HOVER_HEIGHT = GF.BROWSE_ROW_HOVER_HEIGHT or 28
local ROW_HOVER_INSET_X = GF.BROWSE_ROW_HOVER_INSET_X or 2
local ROW_HOVER_OFFSET_Y = GF.BROWSE_ROW_HOVER_OFFSET_Y or 0
local ROW_HOVER_FADE_WIDTH = GF.BROWSE_ROW_HOVER_FADE_WIDTH or 96
local ROW_HOVER_COLOR = GF.BROWSE_ROW_HOVER_COLOR or { 1, 0.74, 0.18, 0.13 }
local ROW_HOVER_RED_COLOR = GF.BROWSE_ROW_HOVER_RED_COLOR or { 1, 0.12, 0.08, 0.18 }
local ROW_HOVER_BLUE_COLOR = GF.BROWSE_ROW_HOVER_BLUE_COLOR or { 0.35, 0.75, 1, 0.16 }
local ROW_HOVER_GREY_COLOR = GF.BROWSE_ROW_HOVER_GREY_COLOR or { 0.65, 0.65, 0.65, 0.18 }
local ROW_SELECTED_ATLAS = GF.BROWSE_ROW_SELECTED_ATLAS or GF.NAV_FLYOUT_SELECTED_ATLAS or "groupfinder-highlightbar-yellow"
local ROW_SELECTED_BLUE_ATLAS = GF.BROWSE_ROW_SELECTED_BLUE_ATLAS or "groupfinder-highlightbar-blue"
local ROW_SELECTED_RED_ATLAS = GF.BROWSE_ROW_SELECTED_RED_ATLAS or "groupfinder-highlightbar-red"
local ROW_SELECTED_ALPHA = GF.BROWSE_ROW_SELECTED_ALPHA or 1
local ROW_SELECTED_INSET_X = GF.BROWSE_ROW_SELECTED_INSET_X or 3
local ROW_SELECTED_TOP_OFFSET_Y = GF.BROWSE_ROW_SELECTED_TOP_OFFSET_Y or -3
local ROW_SELECTED_BOTTOM_OFFSET_Y = GF.BROWSE_ROW_SELECTED_BOTTOM_OFFSET_Y or 1
local TYPE_ICON_PATH = "Interface\\AddOns\\GroupFinder\\Art\\UI\\Icon\\"
local TYPE_ICON_GAP = 3
local TYPE_ICON_TEXTURE = {
	blacklist = TYPE_ICON_PATH .. "Blacklist.png",
	leaver = TYPE_ICON_PATH .. "isLeaver.png",
}
for socialType, texture in pairs(GF.SOCIAL_TYPE_ICON_TEXTURE or {}) do
	TYPE_ICON_TEXTURE[socialType] = texture
end
local TYPE_TEXT_COLOR = {
	blacklist = { r = 1, g = 0.08, b = 0.05 },
	leaver = { r = 1, g = 0.08, b = 0.05 },
}
for socialType in pairs(GF.SOCIAL_TYPE_ICON_TEXTURE or {}) do
	TYPE_TEXT_COLOR[socialType] = GF.SOCIAL_TEXT_COLOR
end
local SOCIAL_SEARCH_RESULT_LABEL_FALLBACK = {
	[GF.SOCIAL_TYPE_BNET or "bnet"] = "战网好友",
	[GF.SOCIAL_TYPE_GUILD or "guild"] = "公会好友",
	[GF.SOCIAL_TYPE_FRIEND or "friend"] = "角色好友",
}

local function getTypeIconSize()
	return (GF.GetNonRoleListIconSize and GF.GetNonRoleListIconSize()) or GF.NON_ROLE_ICON_SIZE or 18
end

function LR:ApplyDivider(row)
	if not row or not row.divider then
		return
	end
	row.divider:Hide()
end

local ROW_BG_INSET_TL = { 3, -2 }
local ROW_BG_INSET_BR = { -3, 0 }
local ROW_HIGHLIGHT_INSET_TL = { ROW_SELECTED_INSET_X, ROW_SELECTED_TOP_OFFSET_Y }
local ROW_HIGHLIGHT_INSET_BR = { -ROW_SELECTED_INSET_X, ROW_SELECTED_BOTTOM_OFFSET_Y }
local function getAppLineY(row)
	return 0
end
local VOICE_W = 16
local LC = GF.ListColumns

local function entryHasVoice(voiceChat)
	return (voiceChat or "") ~= ""
end

local function setRowEllipsis(fontString, text, width)
	if GF.UI and GF.UI.SetEllipsisText then
		GF.UI.SetEllipsisText(fontString, text, width)
	elseif fontString then
		fontString:SetText(text or "")
	end
end

-- [ListRow] 3/5 九列布局与单元格绘制（依赖 ListColumns）

local function getBrowseProfile()
	local node = GF.FindGroupTab and GF.FindGroupTab.GetSelection and GF.FindGroupTab:GetSelection()
	return LC:GetBrowseProfile(node)
end

local function resolveBrowseLayout(rowW)
	return LC:ResolveLayout(rowW, getBrowseProfile())
end

local function rowCol(row, colID)
	local layout = row._columnLayout
	return layout and layout.byId and layout.byId[colID]
end

local function applyColumnJustify(fontString, col)
	if not fontString then
		return
	end
	local align = col and col.align
	if align ~= "CENTER" and align ~= "RIGHT" then
		align = "LEFT"
	end
	fontString:SetJustifyH(align)
end

local BROWSE_TEXT_INSET_COLS = {
	title = true,
	activity = true,
	leader = true,
	comment = true,
}

local function getTextCellInset(colID)
	return BROWSE_TEXT_INSET_COLS[colID] and (GF.BROWSE_TEXT_CELL_INSET_X or 0) or 0
end

local function getTextCellWidth(row, colID, col)
	if row and row._colWidths and row._colWidths[colID] then
		return row._colWidths[colID]
	end
	col = col or rowCol(row, colID)
	if not col then
		return 1
	end
	local inset = getTextCellInset(colID)
	return math.max(1, (col.width or 1) - (inset * 2))
end

local function paintColText(row, colID, fontString, text)
	local col = rowCol(row, colID)
	if not col or not fontString then
		return false
	end
	applyColumnJustify(fontString, col)
	setRowEllipsis(fontString, text, getTextCellWidth(row, colID, col))
	return true
end

local layoutCommentCell

local function relayoutCommentText(row, dc)
	if not rowCol(row, "comment") then
		return
	end
	local commentW = layoutCommentCell(row)
	local comment = row._commentText or ""
	if comment ~= "" and row.comment then
		setRowEllipsis(row.comment, comment, commentW)
		if dc then
			row.comment:SetTextColor(dc.r, dc.g, dc.b)
		elseif row._isDelisted then
			local delisted = LFG_LIST_DELISTED_FONT_COLOR or GRAY
			row.comment:SetTextColor(delisted.r, delisted.g, delisted.b)
		else
			row.comment:SetTextColor(1, 1, 1)
		end
		row.comment:Show()
	elseif row.comment then
		row.comment:SetText("")
		row.comment:Hide()
	end
end

local function refreshCommentCell(row, comment, dc)
	local col = rowCol(row, "comment")
	if not col or not row.comment then
		return
	end
	local commentW = layoutCommentCell(row)
	if comment ~= "" then
		setRowEllipsis(row.comment, comment, commentW)
		if dc then
			row.comment:SetTextColor(dc.r, dc.g, dc.b)
		else
			row.comment:SetTextColor(1, 1, 1)
		end
		row.comment:Show()
	else
		row.comment:SetText("")
		row.comment:Hide()
	end
end

local function placeTextCell(row, fontString, colID, y)
	local col = rowCol(row, colID)
	if not col or not fontString then
		if fontString then
			fontString:Hide()
		end
		if row._colWidths and colID then
			row._colWidths[colID] = nil
		end
		return nil
	end
	fontString:Show()
	fontString:ClearAllPoints()
	local inset = getTextCellInset(colID)
	local textW = math.max(1, col.width - (inset * 2))
	fontString:SetPoint("LEFT", row, "LEFT", col.x + inset, y or 0)
	fontString:SetWidth(textW)
	applyColumnJustify(fontString, col)
	if not row._colWidths then
		row._colWidths = {}
	end
	row._colWidths[colID] = textW
	return textW
end

layoutCommentCell = function(row, y)
	y = y or 0
	local col = rowCol(row, "comment")
	if not col or not row.comment then
		if row.comment then
			row.comment:Hide()
		end
		if row.voiceIcon then
			row.voiceIcon:Hide()
		end
		return nil
	end
	if not row._colWidths then
		row._colWidths = {}
	end
	row._colWidths.comment = col.width

	local reserved = row._appReservedW or 0
	local inset = getTextCellInset("comment")
	local textW = math.max(1, col.width - reserved - (inset * 2))
	if row.voiceIcon then
		if row._hasVoice then
			row.voiceIcon:Show()
			row.voiceIcon:ClearAllPoints()
			row.voiceIcon:SetPoint("LEFT", row, "LEFT", col.x + inset, y or 0)
			row.comment:ClearAllPoints()
			row.comment:SetPoint("LEFT", row.voiceIcon, "RIGHT", 2, 0)
			textW = math.max(1, textW - VOICE_W - 2)
		else
			row.voiceIcon:Hide()
			row.comment:ClearAllPoints()
			row.comment:SetPoint("LEFT", row, "LEFT", col.x + inset, y or 0)
		end
	else
		row.comment:ClearAllPoints()
		row.comment:SetPoint("LEFT", row, "LEFT", col.x + inset, y or 0)
	end
	row.comment:SetWidth(textW)
	row.comment:Show()
	row._colWidths.comment = textW
	return textW
end

function LR:LayoutRow(row, layoutW)
	if not row or not row.title then
		return
	end
	local rowW = layoutW or row:GetWidth() or 0
	if rowW <= 0 then
		rowW = 400
	end
	row._columnLayout = resolveBrowseLayout(rowW)
	placeTextCell(row, row.title, "title")
	layoutCommentCell(row)
	placeTextCell(row, row.activity, "activity")
	placeTextCell(row, row.typeText, "type")
	placeTextCell(row, row.metaLeader, "leader")
	placeTextCell(row, row.metaIL, "ilvl")
	placeTextCell(row, row.metaScore, "score")

	if row.roles then
		local col = row._columnLayout.byId.roles
		if col then
			layoutRoleDisplay(row.roles)
			row.roles:ClearAllPoints()
			row.roles:SetPoint("CENTER", row, "LEFT", col.x + (col.width / 2), 0)
			row.roles:Show()
		else
			row.roles:Hide()
		end
	end
end

-- [ListRow] 4/5 悬停提示、高亮、标题绘制与行池（Detach/Release）

function LR:IsHoverTooltipEnabled()
	return true
end

function LR:IsHoverHighlightEnabled()
	return true
end

function LR:ClearApplicantHighlights()
	local ap = GF.ApplicantsPanel
	if not ap or not ap.ForEachVisibleRow then
		return
	end
	ap:ForEachVisibleRow(function(card)
		if card and card.members then
			for _, member in ipairs(card.members) do
				if member.highlight then
					member.highlight:Hide()
				end
			end
		end
	end)
end

local GOLD = { r = 1, g = 0.82, b = 0 }
local GRAY = { r = 0.5, g = 0.5, b = 0.5 }
local IL_GREEN = { r = 0.1, g = 1, b = 0.1 }
local hoverTooltipHideSeq = 0
local HOVER_TOOLTIP_HIDE_DELAY = GF.LIST_HOVER_TOOLTIP_HIDE_DELAY or 0.1

local function isListHoverTooltipEnabled()
	return LR:IsHoverTooltipEnabled()
end

local function isListHoverHighlightEnabled()
	return LR:IsHoverHighlightEnabled()
end

cancelHoverTooltipHide = function()
	hoverTooltipHideSeq = hoverTooltipHideSeq + 1
end

local function hideHoverTooltipNow()
	cancelHoverTooltipHide()
	GameTooltip:Hide()
	lastTooltipResultID = nil
end

local function scheduleHoverTooltipHide(owner)
	cancelHoverTooltipHide()
	local seq = hoverTooltipHideSeq
	C_Timer.After(HOVER_TOOLTIP_HIDE_DELAY, function()
		if seq ~= hoverTooltipHideSeq then
			return
		end
		if owner and GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() ~= owner then
			return
		end
		GameTooltip:Hide()
		lastTooltipResultID = nil
	end)
end

function LR:ClearHoverTooltip()
	hideHoverTooltipNow()
end

-- ?? 10.2.7+ ? LFGListUtil_SetSearchEntryTooltip ???? age???/??? UI/ListTooltip.lua
local setRowHoverShown

function LR:ClearHoverHighlight()
	if GF.FindGroupTab and GF.FindGroupTab.ForEachVisibleRow then
		GF.FindGroupTab:ForEachVisibleRow(function(row)
			setRowHoverShown(row, false)
		end)
	end
	self:ClearApplicantHighlights()
end

local function FormatLeaderName(fullName, showRealm)
	if not fullName or fullName == "" then
		return "?"
	end
	if showRealm then
		return fullName
	end
	local dashPos = fullName:find("-", 1, true)
	if dashPos then
		return fullName:sub(1, dashPos - 1)
	end
	return fullName
end

local LEADER_RETRY_MAX = 2

local function resolveLeaderDisplay(index, entry)
	if index then
		entry = GF.Result:GetEntry(index, { loadLeader = true }) or entry
	end
	if not entry or not entry.info then
		return "?", nil, entry, { r = 1, g = 1, b = 1 }
	end
	local info = entry.info
	local leader = entry.leader
	local leaderName = info.leaderName or (leader and leader.name) or "?"
	leaderName = FormatLeaderName(leaderName, GF.GetDB().showLeaderRealm == true)
	local leaderColor = { r = 1, g = 1, b = 1 }
	local classFile = leader and leader.classFilename
	if classFile and RAID_CLASS_COLORS[classFile] then
		leaderColor = RAID_CLASS_COLORS[classFile]
	end
	return leaderName, leader, entry, leaderColor
end

function LR:RefreshLeaderColumn(row, index, entry)
	if not row or not index then
		return false
	end
	local leaderName, _, updatedEntry, leaderColor = resolveLeaderDisplay(index, entry)
	if not leaderName or leaderName == "?" then
		return false
	end
	row._metaLeaderText = leaderName
	if paintColText(row, "leader", row.metaLeader, row._metaLeaderText) then
		local info = row._titleInfo
		if info and info.isDelisted then
			local dc = LFG_LIST_DELISTED_FONT_COLOR or GRAY
			row.metaLeader:SetTextColor(dc.r, dc.g, dc.b)
		elseif leaderColor then
			row.metaLeader:SetTextColor(leaderColor.r, leaderColor.g, leaderColor.b)
		end
	end
	return true, updatedEntry
end

function LR:ScheduleLeaderRetry(row, index)
	if not row or not index or not C_Timer or not C_Timer.After then
		return
	end
	local token = (row._leaderRetrySeq or 0) + 1
	row._leaderRetrySeq = token
	local attempt = 0
	local function retry()
		if not row:IsShown() or row.resultIndex ~= index or row._leaderRetrySeq ~= token then
			return
		end
		if row._metaLeaderText and row._metaLeaderText ~= "?" then
			return
		end
		if self:RefreshLeaderColumn(row, index) then
			return
		end
		attempt = attempt + 1
		if attempt < LEADER_RETRY_MAX then
			C_Timer.After(0, retry)
		end
	end
	C_Timer.After(0, retry)
end

local function setDelistedOrColor(fontString, dc, r, g, b)
	if dc then
		fontString:SetTextColor(dc.r, dc.g, dc.b)
	else
		fontString:SetTextColor(r, g, b)
	end
end

local function applyCancelledRowTextColor(row)
	if not row then
		return
	end
	for _, fontString in ipairs({
		row.title,
		row.activity,
		row.typeText,
		row.metaIL,
		row.metaLeader,
		row.metaScore,
	}) do
		if fontString then
			fontString:SetTextColor(
				APPLICATION_CANCELLED_TEXT_COLOR.r,
				APPLICATION_CANCELLED_TEXT_COLOR.g,
				APPLICATION_CANCELLED_TEXT_COLOR.b,
				APPLICATION_CANCELLED_TEXT_COLOR.a or 1
			)
		end
	end
end

local function anchorRowBar(tex, row, insetTL, insetBR)
	if not tex or not row then
		return
	end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", row, "TOPLEFT", insetTL[1], insetTL[2])
	tex:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", insetBR[1], insetBR[2])
end

local function setRowHoverTextureColor(row, color)
	if not row then
		return
	end
	color = color or ROW_HOVER_COLOR
	local r, g, b = color[1] or 1, color[2] or 0.74, color[3] or 0.18
	local alpha = color[4] or 0.13
	if row.hoverLeft then
		if row.hoverLeft.SetGradient and CreateColor then
			row.hoverLeft:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, alpha))
		else
			row.hoverLeft:SetVertexColor(r, g, b, alpha * 0.6)
		end
	end
	if row.hoverRight then
		if row.hoverRight.SetGradient and CreateColor then
			row.hoverRight:SetGradient("HORIZONTAL", CreateColor(r, g, b, alpha), CreateColor(r, g, b, 0))
		else
			row.hoverRight:SetVertexColor(r, g, b, alpha * 0.6)
		end
	end
	if row.hover then
		row.hover:SetVertexColor(r, g, b, alpha)
	end
end

local function getRowSelectedAtlasForState(state)
	if state == "blue" then
		return ROW_SELECTED_BLUE_ATLAS
	end
	if state == "red" then
		return ROW_SELECTED_RED_ATLAS
	end
	return ROW_SELECTED_ATLAS
end

local function setRowSelectedTextureState(row, state)
	if not (row and row.selectedHighlight) then
		return
	end
	local selected = row.selectedHighlight
	local atlas = getRowSelectedAtlasForState(state)
	if selected._gfSelectedAtlas ~= atlas then
		local ok = selected.SetAtlas and pcall(selected.SetAtlas, selected, atlas)
		if not ok then
			selected:SetTexture("Interface\\Buttons\\WHITE8X8")
		end
		selected._gfSelectedAtlas = ok and atlas or nil
	end
	selected:SetVertexColor(1, 1, 1, 1)
end

function setRowHoverShown(row, shown)
	if not row then
		return
	end
	shown = shown == true
	if row.hoverLeft then
		row.hoverLeft:SetShown(shown)
	end
	if row.hover then
		row.hover:SetShown(shown)
	end
	if row.hoverRight then
		row.hoverRight:SetShown(shown)
	end
end

local function setRowSelectedShown(row, shown)
	if row and row.selectedHighlight then
		row.selectedHighlight:SetShown(shown == true)
	end
end

local function layoutRowSelectedTexture(row)
	if row and row.selectedHighlight then
		anchorRowBar(row.selectedHighlight, row, ROW_HIGHLIGHT_INSET_TL, ROW_HIGHLIGHT_INSET_BR)
	end
end

local function createRowSelectedTexture(row)
	local selected = row:CreateTexture(nil, "BORDER", nil, 1)
	if selected.SetBlendMode then
		selected:SetBlendMode("ADD")
	end
	selected:SetAlpha(ROW_SELECTED_ALPHA)
	selected:Hide()
	row.selectedHighlight = selected
	setRowSelectedTextureState(row, "normal")
	layoutRowSelectedTexture(row)
end

local function createRowHoverTextures(row)
	local hoverLeft = row:CreateTexture(nil, "BORDER", nil, -1)
	hoverLeft:SetPoint("LEFT", row, "LEFT", ROW_HOVER_INSET_X, ROW_HOVER_OFFSET_Y)
	hoverLeft:SetSize(ROW_HOVER_FADE_WIDTH, ROW_HOVER_HEIGHT)
	hoverLeft:SetTexture("Interface\\Buttons\\WHITE8X8")

	local hoverRight = row:CreateTexture(nil, "BORDER", nil, -1)
	hoverRight:SetPoint("RIGHT", row, "RIGHT", -ROW_HOVER_INSET_X, ROW_HOVER_OFFSET_Y)
	hoverRight:SetSize(ROW_HOVER_FADE_WIDTH, ROW_HOVER_HEIGHT)
	hoverRight:SetTexture("Interface\\Buttons\\WHITE8X8")

	local hover = row:CreateTexture(nil, "BORDER", nil, -1)
	hover:SetPoint("LEFT", hoverLeft, "RIGHT", 0, 0)
	hover:SetPoint("RIGHT", hoverRight, "LEFT", 0, 0)
	hover:SetHeight(ROW_HOVER_HEIGHT)
	hover:SetTexture("Interface\\Buttons\\WHITE8X8")

	row.hoverLeft = hoverLeft
	row.hover = hover
	row.hoverRight = hoverRight
	setRowHoverTextureColor(row, ROW_HOVER_COLOR)
	setRowHoverShown(row, false)
end

local function getRowBackgroundAlpha()
	return GF.GetListBackgroundAlpha and GF.GetListBackgroundAlpha() or ROW_BACKGROUND_ALPHA
end

local function stopBrowseRowBackgroundTransition(row)
	if not row then
		return
	end
	row._gfBackgroundFadeToken = (row._gfBackgroundFadeToken or 0) + 1
	if row.backgroundTransitionFade then
		row.backgroundTransitionFade:Stop()
	end
	if row.backgroundTransition then
		row.backgroundTransition:SetAlpha(0)
		row.backgroundTransition:Hide()
	end
end

local function ensureBrowseRowBackgroundFade(row)
	local texture = row and row.backgroundTransition
	if not texture or not texture.CreateAnimationGroup then
		return nil
	end
	if row.backgroundTransitionFade then
		return row.backgroundTransitionFade
	end
	local fade = texture:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(getRowBackgroundAlpha())
	alpha:SetToAlpha(0)
	alpha:SetDuration(ROW_BACKGROUND_FADE_SECONDS)
	alpha:SetSmoothing("OUT")
	fade:SetScript("OnFinished", function(group)
		if row._gfBackgroundFadeToken ~= group._gfToken then
			return
		end
		texture:SetAlpha(0)
		texture:Hide()
	end)
	row.backgroundTransitionFade = fade
	row.backgroundTransitionAlpha = alpha
	return fade
end

local function playBrowseRowBackgroundTransition(row, texturePath, alpha)
	local texture = row and row.backgroundTransition
	if not (texture and texturePath) then
		stopBrowseRowBackgroundTransition(row)
		return
	end
	row._gfBackgroundFadeToken = (row._gfBackgroundFadeToken or 0) + 1
	local token = row._gfBackgroundFadeToken
	local fade = ensureBrowseRowBackgroundFade(row)
	if fade then
		fade:Stop()
	end
	texture:SetTexture(texturePath)
	texture:SetVertexColor(1, 1, 1, 1)
	texture:SetAlpha(alpha)
	texture:Show()
	if fade and row.backgroundTransitionAlpha then
		row.backgroundTransitionAlpha:SetFromAlpha(alpha)
		row.backgroundTransitionAlpha:SetToAlpha(0)
		row.backgroundTransitionAlpha:SetDuration(ROW_BACKGROUND_FADE_SECONDS)
		fade._gfToken = token
		fade:Play()
	else
		texture:SetAlpha(0)
		texture:Hide()
	end
end

local function setBrowseRowBackground(row, texturePath)
	if not row or not row.background then
		return
	end
	local texture = texturePath or ROW_TEXTURE_NORMAL
	local alpha = getRowBackgroundAlpha()
	local elementKey = row.resultID and tostring(row.resultID) or nil
	local shouldFade = not row._gfSuppressBackgroundTransition
		and elementKey
		and row._gfBrowseBackgroundElementKey == elementKey
		and row._gfBrowseBackgroundTexture
		and row._gfBrowseBackgroundTexture ~= texture
	if shouldFade then
		playBrowseRowBackgroundTransition(row, row._gfBrowseBackgroundTexture, alpha)
	else
		stopBrowseRowBackgroundTransition(row)
	end
	row.background:SetTexture(texture)
	row.background:SetVertexColor(1, 1, 1, 1)
	row.background:SetAlpha(alpha)
	row._gfBrowseBackgroundElementKey = elementKey
	row._gfBrowseBackgroundTexture = texture
end

local function shouldShowListRowHover(row)
	if not row then
		return false
	end
	return not row._isSelected or row._isAppActive == true
end

local function shouldKeepListRowHover(row)
	return false
end

local function shouldShowRowSelected(row)
	return row
		and row._isSelected == true
		and row._hasApplication ~= true
		and row._isDelisted ~= true
end

function LR:DetachRow(row)
	if not row then
		return
	end
	row.resultIndex = nil
	row.resultID = nil
	row._hasVoice = nil
	if row.voiceIcon then
		row.voiceIcon:Hide()
	end
	if row.GetElementData then
		self:ReleaseRow(row)
		return
	end
	row:Hide()
	self:ReleaseRow(row)
end

function LR:ReleaseRow(row)
	if not row then
		return
	end
	row._isSelected = nil
	row._isDelisted = nil
	row._isAppActive = nil
	row._hasApplication = nil
	row._applicationVisualState = nil
	row._resultType = nil
	row._listMouseOver = nil
	setRowHoverShown(row, false)
	setRowSelectedShown(row, false)
	row._gfSuppressBackgroundTransition = true
	self:UpdateRowBackgrounds(row)
	row._gfSuppressBackgroundTransition = nil
	row._gfBrowseBackgroundElementKey = nil
	row._gfBrowseBackgroundTexture = nil
end

local function getTitleDelistedColor(info)
	if not info or not info.isDelisted then
		return nil
	end
	return LFG_LIST_DELISTED_FONT_COLOR or GRAY
end

local function resolveResultType(row, info, entry)
	local resultID = row and row.resultID or entry and entry.resultID
	return GF.FindGroup and GF.FindGroup:GetResultType(info, entry, resultID) or nil
end

local function getResultTypeLabel(resultType)
	local L = GF.L or {}
	if resultType == "blacklist" then
		return L.TYPE_BLACKLIST or "黑名单"
	end
	if resultType == "leaver" then
		return L.TYPE_LEAVER or "逃兵"
	end
	local socialLabelKey = GF.SOCIAL_SEARCH_RESULT_LABEL_KEY
		and GF.SOCIAL_SEARCH_RESULT_LABEL_KEY[resultType]
	if socialLabelKey then
		return L[socialLabelKey] or SOCIAL_SEARCH_RESULT_LABEL_FALLBACK[resultType] or ""
	end
	return ""
end

local function getResultTypeVisualState(resultType)
	if resultType == "blacklist" or resultType == "leaver" then
		return "red"
	end
	local socialState = GF.GetSocialTypeVisualState and GF.GetSocialTypeVisualState(resultType)
	if socialState then
		return socialState
	end
	return nil
end

local function getBrowseRowVisualState(row)
	if not row then
		return "normal"
	end
	if row._isDelisted == true or row._applicationVisualState == "cancelled" or row._applicationVisualState == "declined" then
		return "grey"
	end
	local typeState = getResultTypeVisualState(row._resultType)
	if typeState then
		return typeState
	end
	if row._applicationVisualState == "green" then
		return "green"
	end
	return "normal"
end

local function getBrowseRowTextureForState(state)
	if state == "red" then
		return ROW_TEXTURE_RED
	end
	if state == "blue" then
		return ROW_TEXTURE_BLUE
	end
	if state == "green" then
		return ROW_TEXTURE_GREEN
	end
	if state == "grey" then
		return ROW_TEXTURE_GREY
	end
	return ROW_TEXTURE_NORMAL
end

local function getBrowseRowHoverColorForState(state)
	if state == "red" then
		return ROW_HOVER_RED_COLOR
	end
	if state == "blue" then
		return ROW_HOVER_BLUE_COLOR
	end
	if state == "grey" then
		return ROW_HOVER_GREY_COLOR
	end
	return ROW_HOVER_COLOR
end

local function paintTitleCol(row, text, dc, applyColors)
	local col = rowCol(row, "title")
	if not col or not row.title then
		return false
	end
	setRowEllipsis(row.title, text, getTextCellWidth(row, "title", col))
	if applyColors then
		setDelistedOrColor(row.title, dc, GOLD.r, GOLD.g, GOLD.b)
	end
	return true
end

local function paintTypeCol(row, col, dc)
	if not row or not col then
		return
	end
	local resultType = row._resultType
	local text = row._typeText or ""
	if not resultType or text == "" then
		if row.typeIcon then
			row.typeIcon:Hide()
		end
		if row.typeText then
			row.typeText:SetText("")
			row.typeText:Hide()
		end
		return
	end

	local icon = row.typeIcon
	local fontString = row.typeText
	if not fontString then
		return
	end
	fontString:Show()
	fontString:SetText(text)
	fontString:SetJustifyH("LEFT")
	local color = dc or TYPE_TEXT_COLOR[resultType] or HIGHLIGHT_FONT_COLOR
	if color then
		fontString:SetTextColor(color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, color.a or color[4] or 1)
	end

	local hasIcon = icon and TYPE_ICON_TEXTURE[resultType]
	local typeIconSize = getTypeIconSize()
	local iconW = hasIcon and typeIconSize or 0
	local gap = hasIcon and TYPE_ICON_GAP or 0
	local maxTextW = math.max(1, col.width - iconW - gap)
	local textW = math.min(math.max(1, math.ceil(fontString:GetStringWidth() or 0)), maxTextW)
	local groupW = iconW + gap + textW
	local x = col.x + math.max(0, math.floor((col.width - groupW) / 2))

	if hasIcon then
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", row, "LEFT", x, 0)
		icon:SetSize(typeIconSize, typeIconSize)
		icon:SetTexture(TYPE_ICON_TEXTURE[resultType])
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetDesaturated(dc ~= nil)
		icon:SetAlpha(dc and 0.5 or 1)
		icon:Show()
	elseif icon then
		icon:Hide()
	end

	fontString:ClearAllPoints()
	fontString:SetPoint("LEFT", row, "LEFT", x + iconW + gap, 0)
	setRowEllipsis(fontString, text, math.max(1, col.x + col.width - (x + iconW + gap)))
end

function LR:RefreshTitleFromEntry(row, entry)
	if not row or not entry or not entry.info then
		return
	end
	row._titleEntry = entry
	row._titleInfo = entry.info
	local dc = getTitleDelistedColor(entry.info)
	row._resultType = resolveResultType(row, entry.info, entry)
	row._typeText = getResultTypeLabel(row._resultType)
	paintTitleCol(row, row._titleText or "", dc, true)
	paintTypeCol(row, rowCol(row, "type"), dc)
	self:UpdateRowBackgrounds(row)
end

local function paintRowFromCache(row, opts)
	opts = opts or {}
	local dc = opts.dc

	if paintTitleCol(row, row._titleText, dc, opts.applyColors) then
		-- title
	end

	local typeCol = rowCol(row, "type")
	if typeCol then
		paintTypeCol(row, typeCol, dc)
	elseif row.typeText then
		row.typeText:SetText("")
		row.typeText:Hide()
		if row.typeIcon then
			row.typeIcon:Hide()
		end
	end

	local hasAppState = false
	if opts.applyAppState and rowCol(row, "comment") and row.resultID then
		hasAppState = LR:ApplyApplicationState(row, row.resultID, dc)
	end

	if rowCol(row, "comment") and not hasAppState then
		refreshCommentCell(row, row._commentText or "", dc)
	end

	if paintColText(row, "activity", row.activity, row._activityText) and opts.applyColors then
		setDelistedOrColor(row.activity, dc, GOLD.r, GOLD.g, GOLD.b)
	end

	if paintColText(row, "ilvl", row.metaIL, row._metaILText) and opts.applyColors then
		setDelistedOrColor(row.metaIL, dc, IL_GREEN.r, IL_GREEN.g, IL_GREEN.b)
	end

	local scoreCol = rowCol(row, "score")
	if scoreCol then
		applyColumnJustify(row.metaScore, scoreCol)
		if row._metaScoreText then
			setRowEllipsis(row.metaScore, row._metaScoreText, scoreCol.width)
			if opts.applyColors then
				if dc then
					row.metaScore:SetTextColor(dc.r, dc.g, dc.b)
				elseif opts.scoreColor then
					row.metaScore:SetTextColor(opts.scoreColor.r, opts.scoreColor.g, opts.scoreColor.b)
				else
					row.metaScore:SetTextColor(1, 0.82, 0)
				end
			end
			row.metaScore:Show()
		else
			row.metaScore:SetText("")
			row.metaScore:Hide()
		end
	end

	if paintColText(row, "leader", row.metaLeader, row._metaLeaderText) and opts.applyColors then
		if dc then
			setDelistedOrColor(row.metaLeader, dc, 1, 1, 1)
		elseif opts.leaderColor then
			row.metaLeader:SetTextColor(opts.leaderColor.r, opts.leaderColor.g, opts.leaderColor.b)
		end
	end

	if opts.applyColors and row._applicationDisplayState == "cancelled" then
		applyCancelledRowTextColor(row)
	end
end

function LR:LayoutOnly(row, width)
	if not row or not row.title then
		return
	end
	if width and width > 0 then
		row:SetWidth(width)
	end
	row:SetHeight(GF.GetListRowH and GF.GetListRowH() or (GF.LIST_ROW_H or 32))
	layoutRowSelectedTexture(row)
	self:LayoutRow(row)
	paintRowFromCache(row, { applyAppState = row.resultID ~= nil })
end


-- [ListRow] 5/5 行框架创建、申请控件与 SetData 入口

function LR:Create(parent, index, existingRow)
	local row = existingRow
	if not row then
		row = CreateFrame("Button", "GroupFinderAddonListRow" .. (index or 0), parent)
	end
	if row._gfInited then
		return row
	end
	local initW = parent and parent:GetWidth() or row:GetWidth() or 0
	if initW <= 0 then
		initW = 400
	end
	row:SetSize(initW, GF.GetListRowH and GF.GetListRowH() or (GF.LIST_ROW_H or 32))

	row.background = row:CreateTexture(nil, "BACKGROUND", nil, -2)
	row.background:SetAllPoints(row)
	setBrowseRowBackground(row, ROW_TEXTURE_NORMAL)

	row.backgroundTransition = row:CreateTexture(nil, "BACKGROUND", nil, -1)
	row.backgroundTransition:SetAllPoints(row)
	row.backgroundTransition:SetAlpha(0)
	row.backgroundTransition:Hide()

	createRowHoverTextures(row)
	createRowSelectedTexture(row)

	row.appBg = row:CreateTexture(nil, "BACKGROUND", nil, 0)
	row.appBg:SetAllPoints(row)
	row.appBg:SetTexture(ROW_TEXTURE_GREEN)
	row.appBg:SetAlpha(GF.GetListBackgroundAlpha and GF.GetListBackgroundAlpha() or ROW_BACKGROUND_ALPHA)
	row.appBg:Hide()
	row.appPending = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlight")
	row.appPending:SetJustifyH("CENTER")
	row.appPending:SetJustifyV("MIDDLE")
	row.appPending:SetMaxLines(1)
	row.appPending:SetWordWrap(false)
	row.appPending:Hide()
	if GF.Font and GF.Font.Track then
		GF.Font.Track(row.appPending, "GameFontHighlight")
	end
	row.appStatusIcon = row:CreateTexture(nil, "OVERLAY")
	row.appStatusIcon:SetSize(APPLICATION_STATUS_ICON_SIZE, APPLICATION_STATUS_ICON_SIZE)
	row.appStatusIcon:Hide()
	row.appSpinner = CreateApplicationPendingSpinner(row)
	row.appCancelHost = CreateFrame("Frame", nil, row)
	row.appCancelHost:SetSize(APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE, APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE)
	row.appCancelHost:SetFrameLevel(row:GetFrameLevel() + 4)
	row.appCancelHost:Hide()
	row.appCancel = CreateApplicationCancelButton(row.appCancelHost)
	row.appCancel._gfRow = row
	if row.appSpinner then
		row.appSpinner:Hide()
	end

	row.title = GF.UI.CreateFontString(row, "OVERLAY", "GameFontNormal")
	row.title:SetJustifyH("LEFT")
	row.title:SetMaxLines(1)
	row.title:SetWordWrap(false)

	row.typeIcon = row:CreateTexture(nil, "ARTWORK")
	do
		local typeIconSize = getTypeIconSize()
		row.typeIcon:SetSize(typeIconSize, typeIconSize)
	end
	row.typeIcon:Hide()

	row.typeText = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	row.typeText:SetJustifyH("LEFT")
	row.typeText:SetMaxLines(1)
	row.typeText:SetWordWrap(false)

	row.metaIL = GF.UI.CreateFontString(row, "OVERLAY", "GameFontDisableSmall")
	row.metaIL:SetJustifyH("LEFT")
	row.metaIL:SetMaxLines(1)
	row.metaIL:SetWordWrap(false)

	row.comment = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	row.comment:SetJustifyH("LEFT")
	row.comment:SetMaxLines(1)
	row.comment:SetWordWrap(false)

	row.voiceIcon = row:CreateTexture(nil, "ARTWORK")
	row.voiceIcon:SetSize(16, 14)
	row.voiceIcon:SetAtlas("groupfinder-icon-voice")
	row.voiceIcon:Hide()

	row.activity = GF.UI.CreateFontString(row, "OVERLAY", "GameFontDisableSmall")
	row.activity:SetJustifyH("LEFT")
	row.activity:SetMaxLines(1)
	row.activity:SetWordWrap(false)

	row.metaScore = GF.UI.CreateFontString(row, "OVERLAY", "GameFontDisableSmall")
	row.metaScore:SetJustifyH("LEFT")
	row.metaScore:SetMaxLines(1)
	row.metaScore:SetWordWrap(false)

	row.metaLeader = GF.UI.CreateFontString(row, "OVERLAY", "GameFontDisableSmall")
	row.metaLeader:SetJustifyH("LEFT")
	row.metaLeader:SetMaxLines(1)
	row.metaLeader:SetWordWrap(false)

	row.roles = GF.RoleDisplay:Create(row)
	row.resultIndex = nil
	row.resultID = nil
	row.categoryID = nil

	row:SetScript("OnEnter", function(self)
		self._listMouseOver = true
		if isListHoverHighlightEnabled() and shouldShowListRowHover(self) then
			setRowHoverShown(self, true)
		end
		local resultID = self.resultID
		if not resultID then
			return
		end
		LR:SyncDelistedFromAPI(self)
		if not isListHoverTooltipEnabled() then
			return
		end
		cancelHoverTooltipHide()
		if GF.ListTooltip and GF.ListTooltip.Show then
			if lastTooltipResultID == resultID and GameTooltip:IsShown() then
				return
			end
			GF.ListTooltip:Show(GameTooltip, resultID, self)
			lastTooltipResultID = resultID
		elseif LFGListUtil_SetSearchEntryTooltip and C_LFGList.GetSearchResultInfo(resultID) then
			if lastTooltipResultID == resultID and GameTooltip:IsShown() then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 25, 0)
			if GF.Font and GF.Font.BeginTooltipFont then
				GF.Font.BeginTooltipFont(GameTooltip)
			end
			LFGListUtil_SetSearchEntryTooltip(GameTooltip, resultID)
			if GF.Font and GF.Font.ApplyTooltipFont then
				GF.Font.ApplyTooltipFont(GameTooltip)
			end
			lastTooltipResultID = resultID
		end
	end)
	row:SetScript("OnLeave", function(self)
		self._listMouseOver = nil
		setRowHoverShown(self, shouldKeepListRowHover(self))
		if isListHoverTooltipEnabled() then
			scheduleHoverTooltipHide(self)
		end
	end)

	row._gfInited = true
	return row
end

function LR:EnsureRow(row)
	if not row or row._gfInited then
		return row
	end
	local parent = row:GetParent()
	return self:Create(parent, 0, row)
end

function LR:BindElement(row, elementData, panel, opts)
	opts = opts or {}
	if not row or not elementData or not panel then
		return false
	end
	local resultID = elementData.resultID
	local index = elementData.dataIndex
	if not index and resultID then
		index = GF.Result:GetIndexForResultID(resultID)
	end
	if not resultID and index then
		resultID = GF.Result:GetResultID(index)
	end
	local fallbackCategory = panel.selection and panel.selection.categoryID
	local layoutW = panel.scrollList and panel.scrollList:GetLayoutWidth() or panel._lastLayoutW or 0
	if layoutW <= 0 then
		layoutW = 400
	end
	panel._lastLayoutW = layoutW
	row:SetWidth(layoutW)

	local loadPlayers = opts.loadPlayers == true and not opts.deferRoles
	local entry
	if index then
		entry = GF.Result:GetEntry(index, { loadPlayers = loadPlayers })
	end
	if (not entry or not entry.info) and resultID then
		entry = GF.Result:GetEntryByResultID(resultID)
		index = index or GF.Result:GetIndexForResultID(resultID)
	end
	if not entry or not entry.info or not index then
		return false
	end
	if GF.Result:ShouldHideDelisted(entry.info) then
		return false
	end
	local rowCat = GF.Result:ResolveRowCategory(index, fallbackCategory)
	local ok = self:SetData(row, index, rowCat, entry, {
		deferRoles = opts.deferRoles ~= false,
		skipLayout = opts.skipLayout,
		layoutW = layoutW,
	})
	if ok == false then
		return false
	end
	if panel.selectedResultID and row.resultID == panel.selectedResultID then
		row._isSelected = true
		panel._selectedRow = row
		panel.selectedResult = row.resultIndex
	elseif row._isSelected then
		row._isSelected = nil
		if panel._selectedRow == row then
			panel._selectedRow = nil
		end
	end
	self:UpdateRowBackgrounds(row)
	row:SetWidth(layoutW)
	if panel.WireOneRow then
		panel:WireOneRow(row)
	end
	if row._deferRoles then
		self:UpdateRoles(row, entry, row.categoryID)
	end
	return true
end

local function isDeclinedApplicationStatus(status)
	return status == "declined" or status == "declined_delisted" or status == "declined_full"
end

local function isCancelledApplicationStatus(status)
	return status == "cancelled" or status == "failed" or status == "timedout" or status == "invitedeclined"
end

local function isJoinedApplicationStatus(status)
	return status == "invited" or status == "inviteaccepted"
end

local function getApplicationDisplayState(state)
	if not state or not state.isApplication then
		return nil
	end
	local a, p = state.appStatus, state.pendingStatus
	if isJoinedApplicationStatus(a) or isJoinedApplicationStatus(p) then
		return "joined"
	end
	if state.isActiveApp then
		return "pending"
	end
	if state.isDeclined or isDeclinedApplicationStatus(a) or isDeclinedApplicationStatus(p) then
		return "declined"
	end
	if isCancelledApplicationStatus(a) or isCancelledApplicationStatus(p) then
		return "cancelled"
	end
	return nil
end

local function FormatApplicationCountdown(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function getApplicationRemainingSeconds(state)
	local duration = tonumber(state and state.appDuration)
	if duration and duration >= 0 and duration <= APPLICATION_TIMEOUT_SECONDS then
		return duration
	end
	return APPLICATION_TIMEOUT_SECONDS
end

local function getApplicationText(displayState, remainingSeconds)
	local L = GF.L or {}
	if displayState == "pending" then
		return string.format(L.APP_STATE_PENDING_FMT or "待定 %s", FormatApplicationCountdown(remainingSeconds))
	end
	if displayState == "declined" then
		return L.APP_STATE_DECLINED or "被拒绝"
	end
	if displayState == "cancelled" then
		return L.APP_STATE_CANCELLED or "已取消"
	end
	if displayState == "joined" then
		return L.APP_STATE_JOINED or "已加入"
	end
	return nil
end

local function getApplicationTextColor(displayState)
	if displayState == "pending" or displayState == "joined" then
		return APPLICATION_PENDING_TEXT_COLOR
	end
	if displayState == "declined" then
		return APPLICATION_DECLINED_TEXT_COLOR
	end
	if displayState == "cancelled" then
		return APPLICATION_CANCELLED_TEXT_COLOR
	end
	return nil
end

local function LayoutApplicationComment(row, displayState)
	local col = rowCol(row, "comment")
	if not row or not row.appPending or not col then
		return
	end
	local showCancelButton = displayState == "pending"
	local buttonHost = row.appCancelHost or row.appCancel
	local button = row.appCancel
	local reservedWidth = showCancelButton and (APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE + APPLICATION_CANCEL_BUTTON_GAP) or 0
	local availableWidth = math.max(1, col.width - 4 - reservedWidth)

	if row.comment then
		row.comment:SetText("")
		row.comment:Hide()
	end
	if row.voiceIcon then
		row.voiceIcon:Hide()
	end
	if buttonHost then
		buttonHost:ClearAllPoints()
		buttonHost:SetPoint("RIGHT", row, "LEFT", col.x + col.width - 2, getAppLineY(row))
		buttonHost:SetShown(showCancelButton)
	end
	if button then
		button.resultID = row.resultID
		button:SetShown(showCancelButton)
	end

	local statusIcon = row.appStatusIcon
	local pendingSpinner = row.appSpinner
	if not displayState then
		if statusIcon then
			statusIcon:Hide()
		end
		StopApplicationPendingSpinner(pendingSpinner)
		row.appPending:ClearAllPoints()
		row.appPending:SetPoint("LEFT", row, "LEFT", col.x + 2, getAppLineY(row))
		row.appPending:SetSize(availableWidth, 18)
		row.appPending:SetJustifyH("CENTER")
		return
	end

	local statusFrame
	if displayState == "pending" then
		statusFrame = pendingSpinner
		if statusIcon then
			statusIcon:Hide()
		end
	else
		StopApplicationPendingSpinner(pendingSpinner)
		if statusIcon and displayState ~= "joined" then
			statusIcon:SetTexture(APPLICATION_ALERT_ICON_TEXTURE)
			statusIcon:SetTexCoord(0, 1, 0, 1)
			statusIcon:SetSize(APPLICATION_STATUS_ICON_SIZE, APPLICATION_STATUS_ICON_SIZE)
			statusFrame = statusIcon
		elseif statusIcon then
			statusIcon:Hide()
		end
	end

	local measuredTextWidth = math.max(1, math.ceil(row.appPending:GetStringWidth() or 0))
	local statusSize = statusFrame and (displayState == "pending" and APPLICATION_PENDING_SPINNER_SIZE or APPLICATION_STATUS_ICON_SIZE) or 0
	local statusGap = statusFrame and APPLICATION_STATUS_ICON_GAP or 0
	local contentLeft = col.x + 2
	local maxTextWidth = math.max(1, availableWidth - statusSize - statusGap)
	local visualTextWidth = math.min(measuredTextWidth, maxTextWidth)
	local groupWidth = visualTextWidth + statusSize + statusGap
	local textLeftOffset = contentLeft
		+ math.floor((availableWidth - groupWidth) / 2)
		+ statusSize
		+ statusGap
		+ APPLICATION_STATUS_TEXT_OFFSET_X
	local minTextLeft = contentLeft + statusSize + statusGap
	local maxTextLeft = contentLeft + availableWidth - visualTextWidth
	textLeftOffset = math.max(minTextLeft, math.min(maxTextLeft, textLeftOffset))
	local textAreaWidth = math.max(1, contentLeft + availableWidth - textLeftOffset)

	row.appPending:ClearAllPoints()
	row.appPending:SetPoint("LEFT", row, "LEFT", textLeftOffset, getAppLineY(row))
	row.appPending:SetSize(textAreaWidth, 18)
	row.appPending:SetJustifyH("LEFT")
	if statusFrame then
		statusFrame:ClearAllPoints()
		statusFrame:SetPoint("RIGHT", row.appPending, "LEFT", -statusGap, 0)
		if displayState == "pending" then
			StartApplicationPendingSpinner(statusFrame)
		else
			statusFrame:Show()
		end
	end
end

local function hideAppCluster(row)
	if row.appPending then
		row.appPending:SetText("")
		row.appPending:Hide()
	end
	if row.appStatusIcon then
		row.appStatusIcon:Hide()
	end
	if row.appSpinner then
		StopApplicationPendingSpinner(row.appSpinner)
	end
	if row.appCancelHost then
		row.appCancelHost:Hide()
	end
	if row.appCancel then
		row.appCancel.resultID = nil
		row.appCancel:Hide()
	end
	row._isAppActive = nil
	row._hasApplication = nil
	row._applicationVisualState = nil
	row._applicationDisplayState = nil
	row._appExpiryShown = nil
	row._appExpiration = nil
	row._appReservedW = nil
end

local function resolveApplicationVisualState(state)
	local displayState = getApplicationDisplayState(state)
	if displayState == "declined" then
		return "declined"
	end
	if displayState == "cancelled" then
		return "cancelled"
	end
	return nil
end

function LR:TickExpiry(row)
	if not row or not row._appExpiryShown or not row.appPending then
		return
	end
	local left = (row._appExpiration or 0) - GetTime()
	if left < 0 then
		left = 0
	end
	row.appPending:SetText(getApplicationText("pending", left))
	LayoutApplicationComment(row, "pending")
end

function LR:ApplyApplicationState(row, resultID, delistedColor)
	if not row or not resultID or not GF.Apply then
		if row and row.appPending then
			hideAppCluster(row)
			relayoutCommentText(row, delistedColor)
		end
		return false
	end
	local state = GF.Apply:GetApplicationState(resultID)
	if not state or not state.isApplication then
		hideAppCluster(row)
		relayoutCommentText(row, delistedColor)
		return false
	end
	local displayState = getApplicationDisplayState(state)
	local remainingSeconds = displayState == "pending" and getApplicationRemainingSeconds(state) or nil
	local text = getApplicationText(displayState, remainingSeconds)
	local color = getApplicationTextColor(displayState)
	if not text then
		hideAppCluster(row)
		relayoutCommentText(row, delistedColor)
		return false
	end
	local col = rowCol(row, "comment")
	if not col then
		hideAppCluster(row)
		return false
	end
	row.appPending:SetText(text)
	row.appPending:SetTextColor(color.r, color.g, color.b, color.a or 1)
	row.appPending:Show()
	LayoutApplicationComment(row, displayState)
	row._appReservedW = col.width
	row._appExpiryShown = displayState == "pending" or nil
	row._appExpiration = row._appExpiryShown and (GetTime() + (remainingSeconds or 0)) or nil
	if row._appExpiryShown then
		if GF.Apply.EnsureExpiryTicker then
			GF.Apply:EnsureExpiryTicker()
		end
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if row.appCancel and row.appCancel:IsShown() and LFGListUtil_IsAppEmpowered then
		row.appCancel:SetEnabled(LFGListUtil_IsAppEmpowered())
	end
	row._isAppActive = displayState == "pending" or nil
	row._hasApplication = true
	row._applicationDisplayState = displayState
	row._applicationVisualState = resolveApplicationVisualState(state)
	if displayState == "cancelled" then
		applyCancelledRowTextColor(row)
	end
	return true
end

function LR:UpdateRowBackgrounds(row)
	if not row then
		return
	end
	if row.appBg then
		row.appBg:Hide()
	end

	local visualState = getBrowseRowVisualState(row)
	setBrowseRowBackground(row, getBrowseRowTextureForState(visualState))
	local hoverState = row._applicationVisualState == "declined" and "red" or visualState
	local hoverColor = getBrowseRowHoverColorForState(hoverState)
	setRowHoverTextureColor(row, hoverColor)
	setRowSelectedTextureState(row, hoverState)

	local showHover = shouldKeepListRowHover(row)
		or (row._listMouseOver == true and isListHoverHighlightEnabled() and shouldShowListRowHover(row))
	setRowHoverShown(row, showHover)
	setRowSelectedShown(row, shouldShowRowSelected(row))
end

function LR:SetDelistedState(row, isDelisted)
	if not row then
		return
	end
	row._isDelisted = isDelisted or nil
	self:UpdateRowBackgrounds(row)
end

function LR:SyncDelistedFromAPI(row)
	if not row or not row.resultID or not C_LFGList.GetSearchResultInfo then
		return
	end
	local resultID = row.resultID
	local info = C_LFGList.GetSearchResultInfo(resultID)
	if not info then
		if GF.FindGroupTab and GF.FindGroupTab.DropFrozenResult then
			if GF.FindGroupTab:DropFrozenResult(resultID) then
				GF.FindGroupTab:RefreshList({ preserveScroll = true })
			end
		end
		return
	end
	if GF.Result and GF.Result.ShouldHideUnavailableResult and GF.Result:ShouldHideUnavailableResult(resultID, info) then
		if GF.FindGroupTab and GF.FindGroupTab.DropFrozenResult then
			if GF.FindGroupTab:DropFrozenResult(resultID) then
				GF.FindGroupTab:RefreshList({ preserveScroll = true })
			end
		end
		return
	end
	local isDelisted = info.isDelisted == true
	if isDelisted == (row._isDelisted == true) then
		return
	end
	local entry = GF.Result and GF.Result:RefreshEntryInfo(resultID, info)
	if entry and row.resultIndex then
		self:RepaintRowState(row, entry, row.categoryID)
	end
end

function LR:UpdateRoles(row, entry, categoryID)
	if not row or not row.roles or not rowCol(row, "roles") then
		return
	end
	local index = row.resultIndex
	entry = entry or (index and GF.Result:GetEntry(index))
	if not entry or not entry.info then
		return
	end
	local mode = GF.Result:GetRoleDisplayMode(entry)
	if GF.Result:IsEnumerateMode(mode) and index and not entry.players then
		entry = GF.Result:GetEntry(index, { loadPlayers = true }) or entry
	end
	row._deferRoles = nil
	GF.RoleDisplay:Update(row.roles, entry, categoryID or row.categoryID, { disabled = entry.info.isDelisted })
	row._titleEntry = entry
	row._titleInfo = entry.info
	row._resultType = resolveResultType(row, entry.info, entry)
	row._typeText = getResultTypeLabel(row._resultType)
	paintTypeCol(row, rowCol(row, "type"), getTitleDelistedColor(entry.info))
	self:UpdateRowBackgrounds(row)
end

function LR:RepaintRowState(row, entry, categoryID)
	if not row or not entry or not entry.info then
		return
	end
	local index = row.resultIndex
	if index and row._metaLeaderText == "?" then
		self:RefreshLeaderColumn(row, index, entry)
	end
	local info = entry.info
	local activityInfo = entry.activity
	local dc = getTitleDelistedColor(info)
	row._titleText = GF.Result:GetListingTitle(info, entry.resultID)
	row._titleInfo = info
	row._titleEntry = entry
	row._resultType = resolveResultType(row, info, entry)
	row._typeText = getResultTypeLabel(row._resultType)
	local scoreText, scoreColor = GF.Result:GetBrowseScoreDisplay(info, activityInfo, dc)
	row._metaScoreText = scoreText
	paintRowFromCache(row, {
		applyColors = true,
		dc = dc,
		scoreColor = scoreColor,
		applyAppState = true,
	})
	self:SetDelistedState(row, info.isDelisted)
	self:UpdateRoles(row, entry, categoryID or row.categoryID)
end

function LR:SetData(row, index, categoryID, entry, opts)
	opts = opts or {}
	local rowCat = GF.Result:ResolveRowCategory(index, categoryID)
	entry = entry or GF.Result:GetEntry(index)
	local wantPlayers = GF.Result:ShouldLoadPlayersForEntry(entry)
	if wantPlayers and not entry.players and not opts.deferRoles then
		entry = GF.Result:GetEntry(index, { loadPlayers = true })
	end
	local info = entry and entry.info
	if not info then
		self:DetachRow(row)
		return false
	end
	if GF.Result:ShouldHideDelisted(info) then
		self:DetachRow(row)
		return false
	end
	row.resultIndex = index
	row.resultID = entry.resultID
	row.categoryID = rowCat

	local db = GF.GetDB()
	local showVoice = entryHasVoice(info.voiceChat) and db.hideVoice ~= true
	row._hasVoice = showVoice or nil

	if not opts.skipLayout then
		self:LayoutRow(row, opts.layoutW)
	end

	local activityInfo = entry.activity
	local activityName = ""
	if activityInfo then
		activityName = activityInfo.fullName or activityInfo.shortName or ""
	elseif info.activityIDs and info.activityIDs[1] then
		activityName = C_LFGList.GetActivityFullName(info.activityIDs[1]) or ""
	end

	local dc = getTitleDelistedColor(info)

	row._titleText = GF.Result:GetListingTitle(info, entry.resultID)
	row._titleInfo = info
	row._titleEntry = entry

	local resultType = resolveResultType(row, info, entry)
	row._resultType = resultType
	row._typeText = getResultTypeLabel(resultType)

	row._metaILText = tostring(math.floor(info.requiredItemLevel or 0))

	local comment = GF.Result and GF.Result.GetListingComment and GF.Result:GetListingComment(info, entry.resultID) or ""
	row._commentText = comment ~= "" and comment or ""

	row._activityText = activityName

	local scoreText, scoreColor = GF.Result:GetBrowseScoreDisplay(info, activityInfo, dc)
	row._metaScoreText = scoreText

	local leaderName, _, leaderEntry, leaderColor = resolveLeaderDisplay(index, entry)
	if leaderEntry then
		entry = leaderEntry
		info = entry.info or info
		activityInfo = entry.activity or activityInfo
	end
	row._metaLeaderText = leaderName

	paintRowFromCache(row, {
		applyColors = true,
		dc = dc,
		scoreColor = scoreColor,
		leaderColor = leaderColor,
		applyAppState = true,
	})

	if leaderName == "?" then
		self:ScheduleLeaderRetry(row, index)
	end

	if row.roles and rowCol(row, "roles") then
		local defer = opts.deferRoles and wantPlayers and not entry.players
		row._deferRoles = defer or nil
		if not row._deferRoles then
			GF.RoleDisplay:Update(row.roles, entry, rowCat, { disabled = info.isDelisted })
		end
	elseif opts.deferRoles and wantPlayers and not entry.players then
		row._deferRoles = true
	else
		row._deferRoles = nil
	end
	self:SetDelistedState(row, info.isDelisted)
	self:UpdateRowBackgrounds(row)
	if not opts.skipShow then
		row:Show()
	end
	return true
end
