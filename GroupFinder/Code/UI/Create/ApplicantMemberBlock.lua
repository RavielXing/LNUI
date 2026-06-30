local _, GF = ...

GF.ApplicantMemberBlock = {}
local AMB = GF.ApplicantMemberBlock

local LC = GF.ListColumns

local ROLE_W = 70
local TYPE_STATUS_ICON_SIZE = GF.NON_ROLE_ICON_SIZE or 18
local TYPE_STATUS_ICON_GAP = 3
local SPEC_ICON_SIZE = GF.NON_ROLE_ICON_SIZE or 18
local SCORE_PART_COUNT = 3
local ROLE_ICON_SIZE = GF.BROWSE_ROW_MEMBER_ICON_SIZE or GF.ROLE_ICON_SIZE or 18
local ROLE_ICON_GAP = GF.BROWSE_ROW_MEMBER_ICON_GAP or 2

local function getTypeStatusIconSize()
	return (GF.GetNonRoleListIconSize and GF.GetNonRoleListIconSize()) or TYPE_STATUS_ICON_SIZE
end

local function getSpecIconSize()
	return (GF.GetNonRoleListIconSize and GF.GetNonRoleListIconSize()) or SPEC_ICON_SIZE
end

local function getRoleIconSize()
	return (GF.GetBrowseMemberIconSize and GF.GetBrowseMemberIconSize()) or ROLE_ICON_SIZE
end

local function getRoleStripWidth(count)
	count = tonumber(count) or 3
	return (getRoleIconSize() * count) + (ROLE_ICON_GAP * math.max(0, count - 1))
end

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

local ROLE_ATLAS = GF.SEASON_DUNGEON_ROLE_ATLAS or GF.ROLE_ICON_ATLAS or {
	LEADER = "UI-LFG-RoleIcon-Leader",
	GUIDE = "UI-LFG-RoleIcon-Leader",
	TANK = "UI-LFG-RoleIcon-Tank",
	HEALER = "UI-LFG-RoleIcon-Healer",
	DAMAGER = "UI-LFG-RoleIcon-DPS",
	DPS = "UI-LFG-RoleIcon-DPS",
	NONE = "groupfinder-icon-emptyslot",
	DEFAULT = "groupfinder-icon-emptyslot",
}

local TYPE_ICON_PATH = "Interface\\AddOns\\GroupFinder\\Art\\UI\\Icon\\"
local BLACKLIST_ICON_TEXTURE = TYPE_ICON_PATH .. "Blacklist.png"
local LEAVER_ICON_TEXTURE = TYPE_ICON_PATH .. "isLeaver.png"
local BLACKLIST_MENU_MARKUP = string.format("|T%s:%d:%d:0:0|t ", BLACKLIST_ICON_TEXTURE, TYPE_STATUS_ICON_SIZE, TYPE_STATUS_ICON_SIZE)
local WCL_CHARACTER_URL_FMT = "https://%s.warcraftlogs.com/character/%s/%s/%s?utm_source=addon"
local CN_ARMORY_CHARACTER_URL_FMT = "https://wow.blizzard.cn/character/#/%s/%s"
local GLOBAL_ARMORY_CHARACTER_URL_FMT = "https://worldofwarcraft.com/%s/character/%s/%s/%s"
local CN_ARMORY_REALM_SLUGS = {
	["白银之手"] = "silver-hand",
}
local REGION_NAME_FALLBACK = {
	[1] = "US",
	[2] = "KR",
	[3] = "EU",
	[4] = "TW",
	[5] = "CN",
}
local DEFAULT_ARMORY_LOCALE_BY_REGION = {
	cn = "zh-cn",
	eu = "en-gb",
	kr = "ko-kr",
	tw = "zh-tw",
	us = "en-us",
}
local COPY_INPUT_ATLAS_TEXTURE = GF.FILTER_CHECK_ATLAS_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\FilterCheckAtlas.png"
local COPY_INPUT_ATLAS_INSET_X = 0.5 / 128
local COPY_INPUT_ATLAS_INSET_Y = 0.5 / 64
local COPY_INPUT_ATLAS_CAP_W = 9
local COPY_INPUT_LEFT_RATIO = 0.45
local COPY_INPUT_RIGHT_RATIO = 0.55
local CHARACTER_INFO_LINK_INPUT_W = 480
local APPLICANT_QUERY_MENU_COLOR = { 1, 0.82, 0, 1 }
local COPY_INPUT_ATLAS_COORDS = {
	hover = { COPY_INPUT_ATLAS_INSET_X, 0.5 - COPY_INPUT_ATLAS_INSET_X, COPY_INPUT_ATLAS_INSET_Y, 1 - COPY_INPUT_ATLAS_INSET_Y },
	normal = { 0.5 + COPY_INPUT_ATLAS_INSET_X, 1 - COPY_INPUT_ATLAS_INSET_X, COPY_INPUT_ATLAS_INSET_Y, 1 - COPY_INPUT_ATLAS_INSET_Y },
}
local SOCIAL_APPLICANT_LABEL_FALLBACK = {
	[GF.SOCIAL_TYPE_BNET or "bnet"] = "战网",
	[GF.SOCIAL_TYPE_GUILD or "guild"] = "公会",
	[GF.SOCIAL_TYPE_FRIEND or "friend"] = "好友",
}
local TOOLTIP_FACTION_ICON_SIZE = 14
local TOOLTIP_FACTION_TEXTURES = {
	Alliance = "Interface\\FriendsFrame\\PlusManz-Alliance",
	Horde = "Interface\\FriendsFrame\\PlusManz-Horde",
}

local ROW_TEXTURE_NORMAL = GF.BROWSE_ROW_TEXTURE_NORMAL or "Interface\\AddOns\\GroupFinder\\Art\\UI\\ApplicantRowNormal.png"
local ROW_TEXTURE_RED = GF.BROWSE_ROW_TEXTURE_RED or "Interface\\AddOns\\GroupFinder\\Art\\UI\\ApplicantRowRed.png"
local ROW_TEXTURE_BLUE = GF.BROWSE_ROW_TEXTURE_BLUE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\ApplicantRowBlue.png"
local ROW_TEXTURE_GREY = GF.BROWSE_ROW_TEXTURE_GREY or "Interface\\AddOns\\GroupFinder\\Art\\UI\\ApplicantRowGrey.png"
local ROW_BACKGROUND_ALPHA = GF.BROWSE_ROW_BACKGROUND_ALPHA or 0.92
local ROW_BACKGROUND_FADE_SECONDS = GF.BROWSE_ROW_BACKGROUND_FADE_SECONDS or 0.16
local ROW_BACKGROUND_SOURCE_WIDTH = 564
local ROW_BACKGROUND_SOURCE_HEIGHT = 52
local ROW_BACKGROUND_SOURCE_CAP_WIDTH = 18
local ROW_BACKGROUND_TOP_SOURCE_HEIGHT = 8
local ROW_BACKGROUND_INSET_TOP = GF.APPLICANT_ROW_BACKGROUND_INSET_TOP or 2
local ROW_BACKGROUND_INSET_BOTTOM = GF.APPLICANT_ROW_BACKGROUND_INSET_BOTTOM or 0
local ROW_CONTENT_OFFSET_Y = GF.APPLICANT_ROW_CONTENT_OFFSET_Y or -1
local ROW_HOVER_INSET_X = GF.BROWSE_ROW_HOVER_INSET_X or 2
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

local function applicantRowKey(applicantID, memberIdx)
	return tostring(applicantID or "") .. ":" .. tostring(memberIdx or 1)
end

local function memberHasSocialRelationship(relationship)
	return GF.IsSocialRelationship and GF.IsSocialRelationship(relationship)
end

local function memberIsBlacklisted(memberData)
	return memberData and (memberData.isBlacklisted == true or memberData.blacklistEntry ~= nil)
end

local function getRelationshipType(relationship)
	return GF.GetSocialRelationshipType and GF.GetSocialRelationshipType(relationship)
end

local function getMemberTypeKind(memberData)
	if not memberData then
		return nil
	end
	if memberIsBlacklisted(memberData) then
		return "blacklist"
	end
	if memberData.isLeaver then
		return "leaver"
	end
	return getRelationshipType(memberData.relationship)
end

local function getMemberTypeLabel(memberData)
	if not memberData then
		return ""
	end
	local L = GF.L or {}
	local kind = getMemberTypeKind(memberData)
	if kind == "blacklist" then
		return L.APPLICANT_TYPE_BLOCKED or "屏蔽"
	end
	if kind == "leaver" then
		return L.APPLICANT_TYPE_LEAVER or L.TYPE_LEAVER or "逃兵"
	end
	local socialLabelKey = GF.SOCIAL_APPLICANT_LABEL_KEY
		and GF.SOCIAL_APPLICANT_LABEL_KEY[kind]
	if socialLabelKey then
		return L[socialLabelKey] or SOCIAL_APPLICANT_LABEL_FALLBACK[kind] or ""
	end
	return ""
end

local function setTypeTextColor(fontString, memberData)
	if not fontString then
		return
	end
	if memberData and memberData.grayed then
		local g = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
		fontString:SetTextColor(g.r, g.g, g.b)
	elseif memberIsBlacklisted(memberData) or (memberData and memberData.isLeaver) then
		fontString:SetTextColor(1, 0.08, 0.05)
	elseif memberHasSocialRelationship(memberData and memberData.relationship) then
		local c = GF.SOCIAL_TEXT_COLOR or { r = 0.35, g = 0.75, b = 1 }
		fontString:SetTextColor(c.r or c[1] or 0.35, c.g or c[2] or 0.75, c.b or c[3] or 1)
	else
		fontString:SetTextColor(0.8, 0.8, 0.8)
	end
end

local function titleIconReserveWidth(memberData)
	return 0
end

local function setRoleAtlas(tex, role)
	if not tex or not role then
		return
	end
	local atlas = ROLE_ATLAS[role]
	if tex.SetAtlas and atlas then
		pcall(tex.SetAtlas, tex, atlas)
	end
end

local function canAssignRoles()
	return GF.Listing and GF.Listing.CanManageEntry and GF.Listing:CanManageEntry()
end

local function resolveLayout(rowW)
	return LC:ResolveLayout(rowW, "applicant")
end

local function memberRowH()
	if GF.GetApplicantRowH then
		return GF.GetApplicantRowH()
	end
	if GF.APPLICANT_ROW_H then
		return GF.APPLICANT_ROW_H
	end
	return GF.GetListRowH and GF.GetListRowH() or (GF.LIST_ROW_H or 32)
end

local function rowH(row)
	local h = row and row.GetHeight and row:GetHeight() or 0
	return (h and h > 0) and h or memberRowH()
end

local function rowBackgroundDisplayHeight(row)
	return math.max(1, rowH(row) - ROW_BACKGROUND_INSET_TOP - ROW_BACKGROUND_INSET_BOTTOM)
end

local function rowBackgroundTopHeight(row)
	return math.max(1, math.floor(rowBackgroundDisplayHeight(row) * ROW_BACKGROUND_TOP_SOURCE_HEIGHT / ROW_BACKGROUND_SOURCE_HEIGHT + 0.5))
end

local function rowBackgroundBottomHeight(row)
	return math.max(1, rowBackgroundDisplayHeight(row) - rowBackgroundTopHeight(row))
end

local function rowBackgroundCapWidth(row)
	return math.max(1, math.floor(rowBackgroundDisplayHeight(row) * ROW_BACKGROUND_SOURCE_CAP_WIDTH / ROW_BACKGROUND_SOURCE_HEIGHT + 0.5))
end

local function rowHoverHeight(row)
	return math.max(1, rowBackgroundDisplayHeight(row) - 2)
end

local function placeTextCell(row, fs, colID)
	local col = row._columnLayout and row._columnLayout.byId[colID]
	if not col or not fs then
		if fs then
			fs:Hide()
		end
		return
	end
	fs:ClearAllPoints()
	if colID == "detail" then
		fs:SetPoint("LEFT", row, "LEFT", col.x, ROW_CONTENT_OFFSET_Y)
		fs:SetJustifyH("LEFT")
	else
		fs:SetPoint("CENTER", row, "LEFT", col.x + (col.width / 2), ROW_CONTENT_OFFSET_Y)
		fs:SetJustifyH("CENTER")
	end
	fs:SetSize(col.width, 18)
	fs:Show()
end

local function getTypeStatusIconTexture(kind)
	if kind == "blacklist" then
		return BLACKLIST_ICON_TEXTURE
	end
	if kind == "leaver" then
		return LEAVER_ICON_TEXTURE
	end
	local socialTexture = GF.SOCIAL_TYPE_ICON_TEXTURE
		and GF.SOCIAL_TYPE_ICON_TEXTURE[kind]
	if socialTexture then
		return socialTexture
	end
	return nil
end

local function layoutTypeCell(row, kind, text)
	local col = row._columnLayout and row._columnLayout.byId.type
	if not col or not row.typeText then
		if row.typeGroup then
			row.typeGroup:Hide()
		end
		if row.typeText then
			row.typeText:Hide()
		end
		if row.typeIcon then
			row.typeIcon:Hide()
		end
		return
	end
	if not text or text == "" then
		if row.typeGroup then
			row.typeGroup:Hide()
		end
		if row.typeIcon then
			row.typeIcon:Hide()
		end
		row.typeText:SetText("")
		row.typeText:Hide()
		return
	end
	local iconTexture = getTypeStatusIconTexture(kind)
	local iconSize = getTypeStatusIconSize()
	if iconTexture and row.typeIcon and col.width > (iconSize + TYPE_STATUS_ICON_GAP + 8) then
		local textW = math.max(1, col.width - iconSize - TYPE_STATUS_ICON_GAP)
		row.typeIcon:SetTexture(iconTexture)
		row.typeText:SetText(text)
		row.typeText:SetWidth(textW)
		local measuredTextW = (row.typeText:GetStringWidth() or textW) + 1
		local naturalTextW = math.max(1, math.ceil(math.min(textW, measuredTextW)))
		local groupW = iconSize + TYPE_STATUS_ICON_GAP + naturalTextW
		local group = row.typeGroup
		if not group then
			return
		end
		group:ClearAllPoints()
		group:SetPoint("CENTER", row, "LEFT", col.x + (col.width / 2), ROW_CONTENT_OFFSET_Y)
		group:SetSize(groupW, math.max(iconSize, 18))
		group:Show()
		row.typeIcon:ClearAllPoints()
		row.typeIcon:SetPoint("LEFT", group, "LEFT", 0, 0)
		row.typeIcon:SetSize(iconSize, iconSize)
		row.typeIcon:Show()
		row.typeText:ClearAllPoints()
		row.typeText:SetPoint("LEFT", row.typeIcon, "RIGHT", TYPE_STATUS_ICON_GAP, 0)
		row.typeText:SetSize(naturalTextW, 18)
		row.typeText:SetJustifyH("LEFT")
		row.typeText:SetJustifyV("MIDDLE")
		row.typeText:Show()
		GF.UI.SetEllipsisText(row.typeText, text, naturalTextW)
		return
	end
	local group = row.typeGroup
	if not group then
		return
	end
	group:ClearAllPoints()
	group:SetPoint("CENTER", row, "LEFT", col.x + (col.width / 2), ROW_CONTENT_OFFSET_Y)
	group:SetSize(col.width, 18)
	group:Show()
	if row.typeIcon then
		row.typeIcon:Hide()
	end
	row.typeText:ClearAllPoints()
	row.typeText:SetAllPoints(group)
	row.typeText:SetJustifyH("CENTER")
	row.typeText:SetJustifyV("MIDDLE")
	GF.UI.SetEllipsisText(row.typeText, text or "", col.width)
end

local function placeIconCell(row, texture, colID, size)
	local col = row._columnLayout and row._columnLayout.byId[colID]
	if not col or not texture then
		if texture then
			texture:Hide()
		end
		return
	end
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", row, "LEFT", col.x + (col.width / 2), ROW_CONTENT_OFFSET_Y)
	texture:SetSize(size, size)
end

local function layoutScoreCell(row)
	local col = row._columnLayout and row._columnLayout.byId.score
	local scoreTexts = row.scoreTexts
	if not scoreTexts then
		return
	end
	if not col then
		for _, fs in ipairs(scoreTexts) do
			fs:Hide()
		end
		return
	end
	local partW = math.max(1, col.width / SCORE_PART_COUNT)
	for i, fs in ipairs(scoreTexts) do
		fs:ClearAllPoints()
		fs:SetPoint("CENTER", row, "LEFT", col.x + ((i - 0.5) * partW), ROW_CONTENT_OFFSET_Y)
		fs:SetSize(math.max(1, math.floor(partW)), 18)
		fs:SetJustifyH("CENTER")
		fs:SetJustifyV("MIDDLE")
		fs:Show()
	end
end

local function getSpecIconTexture(memberData)
	if not memberData then
		return nil
	end
	local specID = tonumber(memberData.specID)
	local specFile = specID and SPEC_ICON_BY_ID[specID]
	if specFile then
		return TYPE_ICON_PATH .. specFile
	end
	local classFile = memberData.class
	if type(classFile) == "string" and classFile ~= "" then
		return TYPE_ICON_PATH .. string.lower(classFile) .. "_flatborder2.tga"
	end
	return nil
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

local function setMemberRowHover(row, shown)
	if row and row._applicantContextMenuLocked and shown ~= true then
		shown = true
	end
	shown = shown == true
	if row and row.highlight then
		row.highlight:SetShown(false)
	end
	if row and row.hoverLeft then
		row.hoverLeft:SetShown(shown)
	end
	if row and row.hover then
		row.hover:SetShown(shown)
	end
	if row and row.hoverRight then
		row.hoverRight:SetShown(shown)
	end
end

local function setMemberRowSelected(row, shown)
	if row and row.selectedHighlight then
		row.selectedHighlight:SetShown(shown == true)
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
	AMB:LayoutHover(row)
end

local function createRowHoverTextures(row)
	local hoverLeft = row:CreateTexture(nil, "BORDER", nil, -1)
	hoverLeft:SetTexture("Interface\\Buttons\\WHITE8X8")

	local hoverRight = row:CreateTexture(nil, "BORDER", nil, -1)
	hoverRight:SetTexture("Interface\\Buttons\\WHITE8X8")

	local hover = row:CreateTexture(nil, "BORDER", nil, -1)
	hover:SetTexture("Interface\\Buttons\\WHITE8X8")

	row.hoverLeft = hoverLeft
	row.hover = hover
	row.hoverRight = hoverRight
	AMB:LayoutHover(row)
	setRowHoverTextureColor(row, ROW_HOVER_COLOR)
	setMemberRowHover(row, false)
end

function AMB:LayoutHover(row)
	if not row then
		return
	end
	local height = rowHoverHeight(row)
	if row.hoverLeft then
		row.hoverLeft:ClearAllPoints()
		row.hoverLeft:SetPoint("LEFT", row, "LEFT", ROW_HOVER_INSET_X, ROW_CONTENT_OFFSET_Y)
		row.hoverLeft:SetSize(ROW_HOVER_FADE_WIDTH, height)
	end
	if row.hoverRight then
		row.hoverRight:ClearAllPoints()
		row.hoverRight:SetPoint("RIGHT", row, "RIGHT", -ROW_HOVER_INSET_X, ROW_CONTENT_OFFSET_Y)
		row.hoverRight:SetSize(ROW_HOVER_FADE_WIDTH, height)
	end
	if row.hover then
		row.hover:ClearAllPoints()
		row.hover:SetPoint("LEFT", row.hoverLeft, "RIGHT", 0, 0)
		row.hover:SetPoint("RIGHT", row.hoverRight, "LEFT", 0, 0)
		row.hover:SetHeight(height)
	end
	if row.highlight then
		row.highlight:ClearAllPoints()
		row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -ROW_BACKGROUND_INSET_TOP)
		row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, ROW_BACKGROUND_INSET_BOTTOM)
	end
	if row.selectedHighlight then
		row.selectedHighlight:ClearAllPoints()
		row.selectedHighlight:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_SELECTED_INSET_X, ROW_SELECTED_TOP_OFFSET_Y)
		row.selectedHighlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -ROW_SELECTED_INSET_X, ROW_SELECTED_BOTTOM_OFFSET_Y)
	end
end

local function getMemberRowVisualState(memberData)
	if memberData and memberData.grayed then
		return "grey"
	end
	if memberIsBlacklisted(memberData) or (memberData and memberData.isLeaver) then
		return "red"
	end
	local socialState = GF.GetSocialTypeVisualState
		and GF.GetSocialTypeVisualState(getRelationshipType(memberData and memberData.relationship))
	if socialState then
		return socialState
	end
	return "normal"
end

local function getMemberRowTexture(state)
	if state == "red" then
		return ROW_TEXTURE_RED
	end
	if state == "blue" then
		return ROW_TEXTURE_BLUE
	end
	if state == "grey" then
		return ROW_TEXTURE_GREY
	end
	return ROW_TEXTURE_NORMAL
end

local function getMemberRowHoverColor(state)
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

local function getRowBackgroundAlpha()
	return GF.GetListBackgroundAlpha and GF.GetListBackgroundAlpha() or ROW_BACKGROUND_ALPHA
end

local function ensureTextureFade(texture)
	if not texture or not texture.CreateAnimationGroup then
		return nil
	end
	if texture._gfBackgroundFade then
		return texture._gfBackgroundFade
	end
	local fade = texture:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(getRowBackgroundAlpha())
	alpha:SetToAlpha(0)
	alpha:SetDuration(ROW_BACKGROUND_FADE_SECONDS)
	alpha:SetSmoothing("OUT")
	fade:SetScript("OnFinished", function(group)
		if texture._gfBackgroundFadeToken ~= group._gfToken then
			return
		end
		texture:SetAlpha(0)
		texture:Hide()
	end)
	texture._gfBackgroundFade = fade
	texture._gfBackgroundFadeAlpha = alpha
	return fade
end

local function stopTextureFade(texture)
	if not texture then
		return
	end
	texture._gfBackgroundFadeToken = (texture._gfBackgroundFadeToken or 0) + 1
	if texture._gfBackgroundFade then
		texture._gfBackgroundFade:Stop()
	end
	texture:SetAlpha(0)
	texture:Hide()
end

local function playTextureFadeOut(texture, alpha)
	if not texture then
		return
	end
	texture._gfBackgroundFadeToken = (texture._gfBackgroundFadeToken or 0) + 1
	local token = texture._gfBackgroundFadeToken
	local fade = ensureTextureFade(texture)
	if fade then
		fade:Stop()
	end
	texture:SetAlpha(alpha)
	texture:Show()
	if fade and texture._gfBackgroundFadeAlpha then
		texture._gfBackgroundFadeAlpha:SetFromAlpha(alpha)
		texture._gfBackgroundFadeAlpha:SetToAlpha(0)
		texture._gfBackgroundFadeAlpha:SetDuration(ROW_BACKGROUND_FADE_SECONDS)
		fade._gfToken = token
		fade:Play()
	else
		texture:SetAlpha(0)
		texture:Hide()
	end
end

local function stopRowBackgroundPiecesFade(pieces)
	for _, piece in pairs(pieces or {}) do
		stopTextureFade(piece)
	end
end

local function playRowBackgroundPiecesFade(pieces, alpha)
	for _, piece in pairs(pieces or {}) do
		if piece.IsShown and piece:IsShown() then
			playTextureFadeOut(piece, alpha)
		else
			stopTextureFade(piece)
		end
	end
end

local function createRowBackgroundPieces(row, subLevel)
	local pieces = {}
	for _, key in ipairs({ "left", "middle", "right" }) do
		local tex = row:CreateTexture(nil, "BACKGROUND", nil, subLevel or -2)
		tex:SetAlpha(getRowBackgroundAlpha())
		pieces[key] = tex
	end
	return pieces
end

local function setRowBackgroundPieceLayout(row, pieces, piece, key, height, texLeft, texRight, texTop, texBottom, verticalMode)
	if not (row and pieces and piece) then
		return
	end
	local capWidth = rowBackgroundCapWidth(row)
	piece:ClearAllPoints()
	if key == "left" then
		piece:SetPoint(verticalMode == "bottom" and "BOTTOMLEFT" or "TOPLEFT", row, verticalMode == "bottom" and "BOTTOMLEFT" or "TOPLEFT", 3, verticalMode == "bottom" and ROW_BACKGROUND_INSET_BOTTOM or -ROW_BACKGROUND_INSET_TOP)
		piece:SetSize(capWidth, height)
	elseif key == "right" then
		piece:SetPoint(verticalMode == "bottom" and "BOTTOMRIGHT" or "TOPRIGHT", row, verticalMode == "bottom" and "BOTTOMRIGHT" or "TOPRIGHT", -3, verticalMode == "bottom" and ROW_BACKGROUND_INSET_BOTTOM or -ROW_BACKGROUND_INSET_TOP)
		piece:SetSize(capWidth, height)
	else
		piece:SetPoint("LEFT", pieces.left, "RIGHT", 0, 0)
		piece:SetPoint("RIGHT", pieces.right, "LEFT", 0, 0)
		if verticalMode == "bottom" then
			piece:SetPoint("BOTTOM", row, "BOTTOM", 0, ROW_BACKGROUND_INSET_BOTTOM)
		else
			piece:SetPoint("TOP", row, "TOP", 0, -ROW_BACKGROUND_INSET_TOP)
		end
		piece:SetHeight(height)
	end
	piece:SetTexCoord(texLeft, texRight, texTop, texBottom)
	piece:SetAlpha(getRowBackgroundAlpha())
	piece:Show()
end

local function setRowBackgroundPiecesShown(pieces, shown)
	for _, piece in pairs(pieces or {}) do
		piece:SetShown(shown == true)
	end
end

local function applyRowBackgroundTexture(row, pieces, texturePath, mode)
	if not pieces then
		return false
	end
	mode = mode or "full"
	texturePath = texturePath or ROW_TEXTURE_NORMAL
	for _, piece in pairs(pieces) do
		piece:SetTexture(texturePath)
	end
	local leftTexCoord = ROW_BACKGROUND_SOURCE_CAP_WIDTH / ROW_BACKGROUND_SOURCE_WIDTH
	local rightTexCoord = 1 - leftTexCoord
	local topTexBottom = ROW_BACKGROUND_TOP_SOURCE_HEIGHT / ROW_BACKGROUND_SOURCE_HEIGHT
	if mode == "hidden" then
		setRowBackgroundPiecesShown(pieces, false)
		return true
	end
	if mode == "top" then
		local height = rowBackgroundTopHeight(row)
		setRowBackgroundPieceLayout(row, pieces, pieces.left, "left", height, 0, leftTexCoord, 0, topTexBottom, "top")
		setRowBackgroundPieceLayout(row, pieces, pieces.middle, "middle", height, leftTexCoord, rightTexCoord, 0, topTexBottom, "top")
		setRowBackgroundPieceLayout(row, pieces, pieces.right, "right", height, rightTexCoord, 1, 0, topTexBottom, "top")
		return true
	end
	if mode == "bottom" then
		local height = rowBackgroundBottomHeight(row)
		setRowBackgroundPieceLayout(row, pieces, pieces.left, "left", height, 0, leftTexCoord, topTexBottom, 1, "bottom")
		setRowBackgroundPieceLayout(row, pieces, pieces.middle, "middle", height, leftTexCoord, rightTexCoord, topTexBottom, 1, "bottom")
		setRowBackgroundPieceLayout(row, pieces, pieces.right, "right", height, rightTexCoord, 1, topTexBottom, 1, "bottom")
		return true
	end
	local height = rowBackgroundDisplayHeight(row)
	setRowBackgroundPieceLayout(row, pieces, pieces.left, "left", height, 0, leftTexCoord, 0, 1, "top")
	setRowBackgroundPieceLayout(row, pieces, pieces.middle, "middle", height, leftTexCoord, rightTexCoord, 0, 1, "top")
	setRowBackgroundPieceLayout(row, pieces, pieces.right, "right", height, rightTexCoord, 1, 0, 1, "top")
	return true
end

local function setRowBackgroundTexture(row, texturePath, mode)
	local pieces = row and row.backgroundPieces
	if not pieces then
		return false
	end
	mode = mode or "full"
	texturePath = texturePath or ROW_TEXTURE_NORMAL
	local elementKey = row.applicantID and applicantRowKey(row.applicantID, row.memberIdx) or nil
	local backgroundKey = texturePath .. ":" .. mode
	local shouldFade = not row._gfSuppressBackgroundTransition
		and row.backgroundTransitionPieces
		and elementKey
		and row._gfApplicantBackgroundElementKey == elementKey
		and row._gfApplicantBackgroundKey
		and row._gfApplicantBackgroundKey ~= backgroundKey
	if shouldFade then
		applyRowBackgroundTexture(row, row.backgroundTransitionPieces, row._gfApplicantBackgroundTexture, row._gfApplicantBackgroundMode)
		playRowBackgroundPiecesFade(row.backgroundTransitionPieces, getRowBackgroundAlpha())
	else
		stopRowBackgroundPiecesFade(row.backgroundTransitionPieces)
	end
	local applied = applyRowBackgroundTexture(row, pieces, texturePath, mode)
	row._gfApplicantBackgroundElementKey = elementKey
	row._gfApplicantBackgroundKey = backgroundKey
	row._gfApplicantBackgroundTexture = texturePath
	row._gfApplicantBackgroundMode = mode
	return applied
end

local function resetApplicantRowBackgroundTransition(row)
	if not row then
		return
	end
	stopRowBackgroundPiecesFade(row.backgroundTransitionPieces)
	row._gfApplicantBackgroundElementKey = nil
	row._gfApplicantBackgroundKey = nil
	row._gfApplicantBackgroundTexture = nil
	row._gfApplicantBackgroundMode = nil
end

local function applyMemberRowVisual(row, memberData, backgroundMode, overrideState)
	if not row then
		return
	end
	local state = overrideState or getMemberRowVisualState(memberData)
	if not setRowBackgroundTexture(row, getMemberRowTexture(state), backgroundMode) and row.background then
		row.background:SetTexture(getMemberRowTexture(state))
		row.background:SetVertexColor(1, 1, 1, 1)
		row.background:SetAlpha(getRowBackgroundAlpha())
		row.background:Show()
	end
	local hoverColor = getMemberRowHoverColor(state)
	setRowHoverTextureColor(row, hoverColor)
	setRowSelectedTextureState(row, state)
end

local function getBlacklistTooltipLine(memberData)
	if not memberIsBlacklisted(memberData) then
		return nil
	end
	local L = GF.L or {}
	local bl = GF.Blocklist
	local entry = memberData.blacklistEntry
	local note = ""
	if bl and bl.FormatEntryNote and type(entry) == "table" then
		note = bl:FormatEntryNote(entry)
	elseif type(entry) == "table" then
		note = entry.note or ""
	end
	if not note or note == "" then
		note = L.BLOCKLIST_NO_NOTE or "无备注"
	end
	local prefix = L.LIST_TIP_BLACKLIST_PREFIX or "黑名单："
	return prefix .. note
end

local function roleLabel(role)
	local L = GF.L or {}
	if role == "TANK" then
		return L.ROLE_TANK or "坦"
	end
	if role == "HEALER" then
		return L.ROLE_HEAL or "奶"
	end
	if role == "DAMAGER" then
		return L.ROLE_DPS or "DPS"
	end
	return nil
end

local function buildRoleText(memberData)
	if not memberData then
		return nil
	end
	local roles = {}
	for _, role in ipairs({ memberData.role1, memberData.role2, memberData.role3 }) do
		local label = roleLabel(role)
		if label then
			roles[#roles + 1] = label
		end
	end
	if #roles == 0 then
		return nil
	end
	return table.concat(roles, " / ")
end

local TOOLTIP_LABEL_COLOR = { r = 1, g = 0.82, b = 0 }
local TOOLTIP_SPEC_LABEL_COLOR = { r = 0, g = 1, b = 0 }
local TOOLTIP_TEXT_COLOR = { r = 1, g = 1, b = 1 }
local TOOLTIP_GRAY_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
local TOOLTIP_GREEN_COLOR = { r = 0, g = 1, b = 0 }
local TOOLTIP_SOCIAL_COLOR = { r = 0.35, g = 0.75, b = 1 }
local TOOLTIP_DANGER_COLOR = { r = 1, g = 0.08, b = 0.05 }

local function normalizedColor(color, fallback)
	fallback = fallback or TOOLTIP_TEXT_COLOR
	if color and color.r and color.g and color.b then
		return color
	end
	return fallback
end

local function wrapColor(color, text)
	text = tostring(text or "")
	color = normalizedColor(color)
	if color.WrapTextInColorCode then
		return color:WrapTextInColorCode(text)
	end
	return string.format("|cff%02x%02x%02x%s|r",
		math.floor((color.r or 1) * 255 + 0.5),
		math.floor((color.g or 1) * 255 + 0.5),
		math.floor((color.b or 1) * 255 + 0.5),
		text)
end

local function getClassColor(memberData)
	if memberData and memberData.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[memberData.class] then
		return RAID_CLASS_COLORS[memberData.class]
	end
	return TOOLTIP_TEXT_COLOR
end

local function getDungeonScoreColor(score)
	if score and score > 0 and C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
		return C_ChallengeMode.GetDungeonScoreRarityColor(score) or HIGHLIGHT_FONT_COLOR or TOOLTIP_TEXT_COLOR
	end
	return TOOLTIP_GRAY_COLOR
end

local function getSpecificDungeonScoreColor(score)
	if score and score > 0 and C_ChallengeMode and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor then
		return C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(score) or HIGHLIGHT_FONT_COLOR or TOOLTIP_TEXT_COLOR
	end
	return TOOLTIP_GRAY_COLOR
end

local function addTooltipDoubleLine(label, value, labelColor, valueColor)
	if not (GameTooltip and GameTooltip.AddDoubleLine) then
		return
	end
	labelColor = normalizedColor(labelColor, TOOLTIP_LABEL_COLOR)
	valueColor = normalizedColor(valueColor, TOOLTIP_TEXT_COLOR)
	GameTooltip:AddDoubleLine(label, value or "-", labelColor.r, labelColor.g, labelColor.b, valueColor.r, valueColor.g, valueColor.b)
end

local function inlineTexture(texture, size)
	if not texture or texture == "" then
		return ""
	end
	size = size or TYPE_STATUS_ICON_SIZE
	return string.format("|T%s:%d:%d:0:0|t", texture, size, size)
end

local function safeFormat(formatText, fallback, ...)
	if type(formatText) == "string" then
		local ok, text = pcall(string.format, formatText, ...)
		if ok and text then
			return text
		end
	end
	return string.format(fallback, ...)
end

local function tooltipLocaleText(key, fallback)
	local L = GF.L or {}
	return L[key] or fallback
end

local function tooltipLocaleFormat(key, fallback, ...)
	return safeFormat(tooltipLocaleText(key, fallback), fallback, ...)
end

local function formatTooltipKeyLevel(detail, includeSuffix)
	if not (detail and detail.bestRunLevel and detail.bestRunLevel > 0) then
		return wrapColor(TOOLTIP_GRAY_COLOR, "-")
	end
	if includeSuffix then
		local levelText = tooltipLocaleFormat("APPLICANT_TIP_KEY_LEVEL_FMT", "+%d", detail.bestRunLevel)
		local color = detail.finishedSuccess and TOOLTIP_GREEN_COLOR or TOOLTIP_GRAY_COLOR
		return wrapColor(color, levelText)
	end
	local levelText = tostring(detail.bestRunLevel)
	local color = detail.finishedSuccess and TOOLTIP_GREEN_COLOR or TOOLTIP_GRAY_COLOR
	return wrapColor(color, levelText)
end

local function formatTooltipDungeonName(detail)
	local name = detail and detail.mapName
	if not name or name == "" then
		return wrapColor(TOOLTIP_GRAY_COLOR, "-")
	end
	return wrapColor(getSpecificDungeonScoreColor(detail.mapScore), name)
end

local function formatCurrentDungeonValue(detail)
	if not detail then
		return wrapColor(TOOLTIP_GRAY_COLOR, "-")
	end
	local left = detail.mapScore and detail.mapScore > 0
		and wrapColor(getSpecificDungeonScoreColor(detail.mapScore), tostring(detail.mapScore))
		or wrapColor(TOOLTIP_GRAY_COLOR, "-")
	local right = formatTooltipKeyLevel(detail, true)
	return left .. " / " .. right
end

local function formatDungeonRunValue(detail)
	if not detail then
		return wrapColor(TOOLTIP_GRAY_COLOR, "-")
	end
	return formatTooltipKeyLevel(detail, false) .. " " .. formatTooltipDungeonName(detail)
end

local function getApplicantTypeMarkup(memberData)
	local label = getMemberTypeLabel(memberData)
	if not label or label == "" then
		return nil
	end
	local kind = getMemberTypeKind(memberData)
	local texture = getTypeStatusIconTexture(kind)
	local color = TOOLTIP_TEXT_COLOR
	if kind == "blacklist" or kind == "leaver" then
		color = TOOLTIP_DANGER_COLOR
	elseif GF.GetSocialTypeVisualState and GF.GetSocialTypeVisualState(kind) then
		color = TOOLTIP_SOCIAL_COLOR
	end
	local icon = texture and string.format("|T%s:%d:%d:0:0|t ", texture, TYPE_STATUS_ICON_SIZE, TYPE_STATUS_ICON_SIZE) or ""
	return icon .. wrapColor(color, label)
end

local function formatSpecClassLine(memberData)
	if not memberData then
		return ""
	end
	local prefix = ""
	if memberData and memberData.level and memberData.level > 0 then
		prefix = tooltipLocaleFormat("APPLICANT_TIP_LEVEL_FMT", "Level %d", memberData.level)
	end
	local specClass = ""
	if memberData.specName and memberData.specName ~= "" then
		specClass = specClass .. memberData.specName
	end
	if memberData.localizedClass and memberData.localizedClass ~= "" then
		specClass = specClass .. memberData.localizedClass
	end
	if prefix ~= "" and specClass ~= "" then
		return prefix .. " " .. specClass
	end
	return prefix ~= "" and prefix or specClass
end

local function getApplicantFactionIconMarkup(memberData)
	if not (memberData and memberData.showFactionIcon and memberData.factionGroup) then
		return ""
	end
	if not PLAYER_FACTION_GROUP then
		return ""
	end
	local factionKey = PLAYER_FACTION_GROUP[memberData.factionGroup]
	local texture = factionKey and TOOLTIP_FACTION_TEXTURES[factionKey]
	return inlineTexture(texture, TOOLTIP_FACTION_ICON_SIZE)
end

local function showMplusApplicantMemberTooltip(member, memberData)
	if not (member and memberData and memberData.ratingKind == "mplus" and memberData.ratingDetail and GameTooltip) then
		return false
	end
	local d = memberData.ratingDetail
	local currentDungeon = d.currentDungeon or d
	local bestOverall = d.bestOverallScore

	GF.UI.BeginGameTooltip(member, "ANCHOR_RIGHT")
	if GameTooltip.ClearLines then
		GameTooltip:ClearLines()
	end

	local title = memberData.displayName or memberData.name or member._nameText or ""
	local classColor = getClassColor(memberData)
	GameTooltip:AddLine(title, classColor.r, classColor.g, classColor.b, true)

	local specClassLine = formatSpecClassLine(memberData)
	if specClassLine ~= "" then
		GameTooltip:AddLine(specClassLine, 1, 1, 1, true)
	end
	if memberData.ilvl and memberData.ilvl > 0 then
		addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_ITEM_LEVEL_PREFIX", "Item Level: "), tostring(memberData.ilvl), TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	end
	if memberData.specName and memberData.specName ~= "" then
		addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_CURRENT_SPEC_PREFIX", "Current Specialization: "), wrapColor(classColor, memberData.specName), TOOLTIP_SPEC_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	end
	local typeMarkup = getApplicantTypeMarkup(memberData)
	if typeMarkup then
		GameTooltip:AddLine(typeMarkup, 1, 1, 1, true)
	end

	GameTooltip:AddLine(" ")
	local overallText = d.overall and d.overall > 0
		and wrapColor(getDungeonScoreColor(d.overall), tostring(d.overall))
		or wrapColor(TOOLTIP_GRAY_COLOR, "-")
	addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_MPLUS_SCORE_PREFIX", "Mythic+ Rating: "), overallText, TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_CURRENT_DUNGEON_PREFIX", "Current Dungeon: "), formatCurrentDungeonValue(currentDungeon), TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_BEST_RUN_PREFIX", "Best Run: "), formatDungeonRunValue(bestOverall), TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_BEST_DUNGEON_PREFIX", "Best Dungeon: "), formatDungeonRunValue(currentDungeon), TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)

	local comment = memberData.comment or member._detailText or ""
	if comment ~= "" then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(comment, 1, 1, 1, true)
	end

	local blacklistLine = getBlacklistTooltipLine(memberData)
	if blacklistLine then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(blacklistLine, 1, 0.08, 0.05, true)
	end
	GF.UI.ShowGameTooltip()
	return true
end

local function beginApplicantMemberTooltip(member, memberData, showFactionIcon)
	if not (member and memberData and GameTooltip) then
		return nil
	end
	GF.UI.BeginGameTooltip(member, "ANCHOR_RIGHT")
	if GameTooltip.ClearLines then
		GameTooltip:ClearLines()
	end
	local title = memberData.displayName or memberData.name or member._nameText or ""
	if showFactionIcon then
		local factionIcon = getApplicantFactionIconMarkup(memberData)
		if factionIcon ~= "" then
			title = title .. " " .. factionIcon
		end
	end
	local classColor = getClassColor(memberData)
	GameTooltip:AddLine(title, classColor.r, classColor.g, classColor.b, true)

	local specClassLine = formatSpecClassLine(memberData)
	if specClassLine ~= "" then
		GameTooltip:AddLine(specClassLine, 1, 1, 1, true)
	end
	return classColor
end

local function addApplicantTypeLine(memberData)
	local typeMarkup = getApplicantTypeMarkup(memberData)
	if typeMarkup then
		GameTooltip:AddLine(typeMarkup, 1, 1, 1, true)
	end
end

local function addApplicantCommentAndBlacklist(member, memberData)
	local comment = memberData.comment or member._detailText or ""
	if comment ~= "" then
		GameTooltip:AddLine(" ")
		local formatted = safeFormat(LFG_LIST_COMMENT_FORMAT, "%s", comment)
		local color = LFG_LIST_COMMENT_FONT_COLOR or TOOLTIP_TEXT_COLOR
		GameTooltip:AddLine(formatted, color.r or 1, color.g or 1, color.b or 1, true)
	end

	local blacklistLine = getBlacklistTooltipLine(memberData)
	if blacklistLine then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(blacklistLine, 1, 0.08, 0.05, true)
	end
end

local function isPvpApplicantActivity(memberData)
	local activityInfo = memberData and memberData.activityInfo
	return activityInfo and (activityInfo.isPvpActivity or activityInfo.isRatedPvpActivity)
end

local function showStandardApplicantMemberTooltip(member, memberData)
	if not (member and memberData and GameTooltip) then
		return false
	end
	if memberData.ratingKind == "mplus" or memberData.tooltipKind == "mplus" or isPvpApplicantActivity(memberData) then
		return false
	end
	local classColor = beginApplicantMemberTooltip(member, memberData, false)
	if not classColor then
		return false
	end
	if memberData.ilvl and memberData.ilvl > 0 then
		addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_ITEM_LEVEL_PREFIX", "Item Level: "), tostring(memberData.ilvl), TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	end
	if memberData.specName and memberData.specName ~= "" then
		addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_CURRENT_SPEC_PREFIX", "Current Specialization: "), wrapColor(classColor, memberData.specName), TOOLTIP_SPEC_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	end
	addApplicantTypeLine(memberData)

	local comment = memberData.comment or member._detailText or ""
	if comment ~= "" then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(comment, 1, 1, 1, true)
	end

	local blacklistLine = getBlacklistTooltipLine(memberData)
	if blacklistLine then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(blacklistLine, 1, 0.08, 0.05, true)
	end
	GF.UI.ShowGameTooltip()
	return true
end

local function getPvpTierName(pvpInfo)
	if not (pvpInfo and pvpInfo.tier and PVPUtil and PVPUtil.GetTierName) then
		return ""
	end
	local ok, tierName = pcall(PVPUtil.GetTierName, pvpInfo.tier)
	if ok and tierName then
		return tierName
	end
	return ""
end

local function formatPvpRatingInfo(pvpInfo)
	if not (pvpInfo and pvpInfo.rating) then
		return nil
	end
	local activityName = pvpInfo.activityName or "PvP"
	local tierName = getPvpTierName(pvpInfo)
	local text = wrapColor(TOOLTIP_GREEN_COLOR, tooltipLocaleFormat("APPLICANT_TIP_PVP_ACTIVITY_PREFIX_FMT", "%s: ", activityName))
		.. wrapColor(TOOLTIP_GREEN_COLOR, pvpInfo.rating)
	if tierName and tierName ~= "" then
		text = text .. wrapColor(TOOLTIP_GREEN_COLOR, "/" .. tierName)
	end
	return text
end

local function showPvpApplicantMemberTooltip(member, memberData)
	if not (member and memberData and GameTooltip and (memberData.tooltipKind == "pvp" or isPvpApplicantActivity(memberData))) then
		return false
	end
	local classColor = beginApplicantMemberTooltip(member, memberData, true)
	if not classColor then
		return false
	end
	local pvpItemLevel = memberData.pvpItemLevel or memberData.ilvl or 0
	if pvpItemLevel and pvpItemLevel > 0 then
		addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_PVP_ITEM_LEVEL_PREFIX", "PvP Item Level: "), tostring(pvpItemLevel), TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	end
	if memberData.specName and memberData.specName ~= "" then
		addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_CURRENT_SPEC_PREFIX", "Current Specialization: "), wrapColor(classColor, memberData.specName), TOOLTIP_SPEC_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	end
	if memberData.activityInfo and memberData.activityInfo.useHonorLevel and memberData.honorLevel and memberData.honorLevel > 0 then
		addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_HONOR_LEVEL_PREFIX", "Honor Level: "), wrapColor(HIGHLIGHT_FONT_COLOR or TOOLTIP_TEXT_COLOR, memberData.honorLevel), TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	end
	addApplicantTypeLine(memberData)

	local comment = memberData.comment or member._detailText or ""
	if comment ~= "" then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(comment, 1, 1, 1, true)
	end

	local blacklistLine = getBlacklistTooltipLine(memberData)
	if blacklistLine then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(blacklistLine, 1, 0.08, 0.05, true)
	end

	local pvpText = formatPvpRatingInfo(memberData.pvpRatingInfo or memberData.ratingDetail)
	if pvpText then
		GameTooltip:AddLine(" ")
		addTooltipDoubleLine(tooltipLocaleText("APPLICANT_TIP_PVP_RATING_PREFIX", "PvP Rating: "), pvpText, TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	end
	GF.UI.ShowGameTooltip()
	return true
end

local function showNonMplusTestApplicantMemberTooltip(member, memberData)
	if not (member and memberData and memberData.tooltipKind and memberData.tooltipKind ~= "mplus" and GameTooltip) then
		return false
	end
	if not beginApplicantMemberTooltip(member, memberData) then
		return false
	end
	if memberData.ilvl and memberData.ilvl > 0 then
		GameTooltip:AddLine(safeFormat(LFG_LIST_ITEM_LEVEL_CURRENT, tooltipLocaleText("APPLICANT_TIP_ITEM_LEVEL_FMT", "Item Level: %d"), memberData.ilvl), 1, 1, 1, true)
	end
	addApplicantTypeLine(memberData)
	addApplicantCommentAndBlacklist(member, memberData)
	GF.UI.ShowGameTooltip()
	return true
end

local function showTestApplicantMemberTooltip(member, memberData)
	if not (member and memberData and GameTooltip) then
		return
	end
	if showMplusApplicantMemberTooltip(member, memberData) then
		return
	end
	if showPvpApplicantMemberTooltip(member, memberData) then
		return
	end
	if showStandardApplicantMemberTooltip(member, memberData) then
		return
	end
	if showNonMplusTestApplicantMemberTooltip(member, memberData) then
		return
	end
	GF.UI.BeginGameTooltip(member, "ANCHOR_RIGHT")
	local title = memberData.displayName or memberData.name or member._nameText or ""
	GameTooltip:SetText(title, 1, 1, 1, 1, true)
	if memberData.specText and memberData.specText ~= "" then
		GameTooltip:AddLine(memberData.specText, 1, 0.82, 0, true)
	end
	local roleText = buildRoleText(memberData)
	if roleText and GameTooltip.AddDoubleLine then
		GameTooltip:AddDoubleLine((GF.L and GF.L.COL_APP_ROLE) or "职责", roleText, 0.8, 0.8, 0.8, 1, 1, 1)
	end
	if memberData.ilvl and memberData.ilvl > 0 and GameTooltip.AddDoubleLine then
		GameTooltip:AddDoubleLine(ITEM_LEVEL or (GF.L and GF.L.COL_ILVL) or "装等", tostring(memberData.ilvl), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	if member._scoreText and member._scoreText ~= "" then
		GameTooltip:AddLine(((GF.L and GF.L.COL_APP_SCORE) or "Rating / Level") .. tooltipLocaleText("APPLICANT_TIP_LABEL_SEPARATOR", ": ") .. member._scoreText, 0.8, 0.8, 0.8, true)
	end
	if member._detailText and member._detailText ~= "" then
		GameTooltip:AddLine(member._detailText, 0.8, 0.8, 0.8, true)
	end
	local blacklistLine = getBlacklistTooltipLine(memberData)
	if blacklistLine then
		GameTooltip:AddLine(blacklistLine, 1, 0.08, 0.05, true)
	end
	GF.UI.ShowGameTooltip()
end

local function showApplicantMemberTooltip(member)
	local memberData = member and member._layoutMemberData
	if memberData and memberData.isTest then
		showTestApplicantMemberTooltip(member, memberData)
		return
	end
	if showMplusApplicantMemberTooltip(member, memberData) then
		return
	end
	if showPvpApplicantMemberTooltip(member, memberData) then
		return
	end
	if showStandardApplicantMemberTooltip(member, memberData) then
		return
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if LFGListApplicantMember_OnEnter then
		LFGListApplicantMember_OnEnter(member)
	end
	if GF.Font and GameTooltip then
		GF.Font.BeginTooltipFont(GameTooltip)
		local blacklistLine = getBlacklistTooltipLine(memberData)
		if blacklistLine and GameTooltip.AddLine then
			GameTooltip:AddLine(blacklistLine, 1, 0.08, 0.05, true)
		end
		GF.Font.ApplyTooltipFont(GameTooltip)
		if GameTooltip.Show then
			GameTooltip:Show()
		end
	end
end

function AMB:LayoutMember(row)
	if not row or not row.title then
		return
	end
	local rowW = row:GetWidth() or 400
	row._columnLayout = resolveLayout(rowW)

	placeTextCell(row, row.typeText, "type")
	placeTextCell(row, row.title, "name")
	placeTextCell(row, row.detail, "detail")
	placeTextCell(row, row.classText, "class")
	placeIconCell(row, row.specIcon, "class", getSpecIconSize())
	placeTextCell(row, row.ilvlText, "ilvl")
	layoutScoreCell(row)

	if row.roles then
		local col = row._columnLayout.byId.role
		if col then
			local roleIconSize = getRoleIconSize()
			local roleFrameW = math.min(col.width, math.max(ROLE_W, getRoleStripWidth(3)))
			row.roles:ClearAllPoints()
			row.roles:SetPoint("CENTER", row, "LEFT", col.x + (col.width / 2), ROW_CONTENT_OFFSET_Y)
			row.roles:SetSize(roleFrameW, roleIconSize)
			row.roles:Show()
		else
			row.roles:Hide()
		end
	end
	self:LayoutHover(row)
end

function AMB:UpdateSelectedState(row)
	if not row then
		return
	end
	local selected = false
	local panel = GF.ApplicantsPanel
	if row.applicantID and row.memberIdx and panel and panel.GetSelectedApplicantRowKey then
		selected = panel:GetSelectedApplicantRowKey() == applicantRowKey(row.applicantID, row.memberIdx)
	end
	row._isSelected = selected or nil
	setMemberRowSelected(row, selected)
end

local function getApplicantMenuName(row)
	local memberData = row and row._layoutMemberData
	if memberData and memberData.name and memberData.name ~= "" then
		return memberData.name
	end
	if row and row.applicantID and row.memberIdx and C_LFGList and C_LFGList.GetApplicantMemberInfo then
		local name = C_LFGList.GetApplicantMemberInfo(row.applicantID, row.memberIdx)
		if name and name ~= "" then
			return name
		end
	end
	return nil
end

local function getApplicantMenuTitle(row, name)
	local memberData = row and row._layoutMemberData
	if memberData and memberData.displayName and memberData.displayName ~= "" then
		return memberData.displayName
	end
	if name and name ~= "" then
		return Ambiguate(name, "short")
	end
	return ""
end

local function trimApplicantText(text)
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text ~= "" then
		return text
	end
	return nil
end

local function currentApplicantMenuRealmName()
	local realm = GetNormalizedRealmName and GetNormalizedRealmName()
	if type(realm) ~= "string" or realm == "" then
		realm = GetRealmName and GetRealmName()
	end
	return trimApplicantText(realm)
end

local function splitApplicantCharacterName(name)
	name = trimApplicantText(name)
	if not name then
		return nil, nil
	end
	local characterName, realm = name:match("^([^%-]+)%-(.+)$")
	if not characterName then
		characterName = (Ambiguate and Ambiguate(name, "short")) or name
		realm = currentApplicantMenuRealmName()
	end
	characterName = trimApplicantText(characterName)
	realm = trimApplicantText(realm)
	return characterName, realm
end

local function urlEncodeComponent(text)
	text = tostring(text or "")
	return (text:gsub("([^%w%-%._~])", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

local function getCurrentRegionNameToken()
	local regionName = GetCurrentRegionName and GetCurrentRegionName()
	if type(regionName) == "string" and regionName ~= "" then
		return string.upper(regionName)
	end
	local regionID = GetCurrentRegion and GetCurrentRegion()
	regionName = REGION_NAME_FALLBACK[tonumber(regionID) or 0]
	if regionName then
		return regionName
	end
	return "US"
end

local function getCurrentRegionForLinks()
	local regionName = getCurrentRegionNameToken()
	local region = string.lower(regionName)
	return region, regionName == "CN"
end

local function getCurrentArmoryLocale(region)
	local locale = GetLocale and GetLocale()
	if type(locale) == "string" and locale ~= "" then
		local formatted = locale:gsub("^(%l%l)(%u%u)$", "%1-%2"):lower()
		if formatted:find("-", 1, true) then
			return formatted
		end
	end
	return DEFAULT_ARMORY_LOCALE_BY_REGION[region or "us"] or "en-us"
end

local function normalizeApplicantRealmForLink(realm)
	realm = trimApplicantText(realm)
	if realm then
		return realm:gsub("%s+", "")
	end
	return nil
end

local function getApplicantArmoryRealmSlug(realm)
	realm = normalizeApplicantRealmForLink(realm)
	if not realm then
		return nil
	end
	local mapped = CN_ARMORY_REALM_SLUGS[realm]
	if mapped then
		return mapped
	end
	local asciiSlug = realm
		:gsub("(%l)(%u)", "%1-%2")
		:gsub("%s+", "-")
		:gsub("_", "-")
		:gsub("[%'%.]", "")
		:lower()
	if asciiSlug:match("^[%w%-]+$") then
		return asciiSlug
	end
	return urlEncodeComponent(realm)
end

local function getApplicantWclRealm(realm)
	return normalizeApplicantRealmForLink(realm)
end

local function buildApplicantWclUrl(region, characterName, realm)
	local wclRealm = getApplicantWclRealm(realm)
	if not wclRealm then
		return nil
	end
	return string.format(WCL_CHARACTER_URL_FMT, region, region, wclRealm, characterName)
end

local function buildApplicantArmoryInfoUrl(region, isChina, characterName, realm)
	local armoryRealm = getApplicantArmoryRealmSlug(realm)
	if not armoryRealm then
		return nil
	end
	local encodedCharacterName = urlEncodeComponent(characterName)
	if isChina then
		return string.format(CN_ARMORY_CHARACTER_URL_FMT, armoryRealm, encodedCharacterName)
	end
	return string.format(GLOBAL_ARMORY_CHARACTER_URL_FMT, getCurrentArmoryLocale(region), region, armoryRealm, encodedCharacterName)
end

local function buildApplicantCharacterLinks(name)
	local characterName, realm = splitApplicantCharacterName(name)
	realm = normalizeApplicantRealmForLink(realm)
	if not characterName or not realm then
		return nil
	end
	local region, isChina = getCurrentRegionForLinks()
	local wclUrl = buildApplicantWclUrl(region, characterName, realm)
	local armoryInfoUrl = buildApplicantArmoryInfoUrl(region, isChina, characterName, realm)
	if not wclUrl or not armoryInfoUrl then
		return nil
	end
	return {
		wcl = wclUrl,
		armory = armoryInfoUrl,
	}
end

local function whisperApplicant(name)
	if not name or name == "" then
		return
	end
	if ChatFrameUtil and ChatFrameUtil.SendTell then
		ChatFrameUtil.SendTell(name)
	elseif ChatFrame_OpenChat then
		ChatFrame_OpenChat("/w " .. name .. " ", SELECTED_DOCK_FRAME)
	end
end

local function snapCopyInputTexture(texture)
	if not texture then
		return
	end
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(true)
	end
	if texture.SetTexelSnappingBias then
		texture:SetTexelSnappingBias(0)
	end
end

local function updateCopyInputAtlasFrame(frame, active)
	local pieces = frame and frame._gfCopyInputAtlas
	if not pieces then
		return
	end
	local state = active and COPY_INPUT_ATLAS_COORDS.hover or COPY_INPUT_ATLAS_COORDS.normal
	local left, right, top, bottom = state[1], state[2], state[3], state[4]
	local width = right - left
	local leftU = left + width * COPY_INPUT_LEFT_RATIO
	local rightU = left + width * COPY_INPUT_RIGHT_RATIO

	pieces.left:SetTexCoord(left, leftU, top, bottom)
	pieces.middle:SetTexCoord(leftU, rightU, top, bottom)
	pieces.right:SetTexCoord(rightU, right, top, bottom)
end

local function updateCopyInputState(frame)
	local edit = frame and frame.edit
	local focused = edit and edit.HasFocus and edit:HasFocus()
	updateCopyInputAtlasFrame(frame, frame and (frame._gfCopyInputHovered or focused))
end

local function applyFontStringSizeOverride(fontString, template, size, flags)
	if not fontString or not GF.Font then
		return
	end
	fontString._gfFontSizeOverride = size
	fontString._gfFontFlagsOverride = flags
	if GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template or fontString._gfFontTemplate or "GameFontNormal")
	end
end

local function applyEditBoxSizeOverride(editBox, template, size, flags)
	if not editBox or not GF.Font then
		return
	end
	editBox._gfFontSizeOverride = size
	editBox._gfFontFlagsOverride = flags
	if GF.Font.ApplyToEditBox then
		GF.Font.ApplyToEditBox(editBox, template or editBox._gfFontTemplate or "GameFontHighlightSmall")
	end
end

local function createCopyNameInput(parent, width)
	local shell = CreateFrame("Frame", nil, parent)
	shell:SetSize(width or 330, 26)
	shell:EnableMouse(true)

	local left = shell:CreateTexture(nil, "BACKGROUND", nil, -6)
	left:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", 0, 0)
	left:SetWidth(COPY_INPUT_ATLAS_CAP_W)
	left:SetTexture(COPY_INPUT_ATLAS_TEXTURE)
	snapCopyInputTexture(left)

	local right = shell:CreateTexture(nil, "BACKGROUND", nil, -6)
	right:SetPoint("TOPRIGHT", shell, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(COPY_INPUT_ATLAS_CAP_W)
	right:SetTexture(COPY_INPUT_ATLAS_TEXTURE)
	snapCopyInputTexture(right)

	local middle = shell:CreateTexture(nil, "BACKGROUND", nil, -6)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
	middle:SetTexture(COPY_INPUT_ATLAS_TEXTURE)
	snapCopyInputTexture(middle)

	shell._gfCopyInputAtlas = {
		left = left,
		middle = middle,
		right = right,
	}

	local edit = CreateFrame("EditBox", nil, shell)
	edit:SetPoint("TOPLEFT", shell, "TOPLEFT", 10, -3)
	edit:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -10, 3)
	edit:SetAutoFocus(false)
	edit:SetTextInsets(6, 6, 0, 0)
	edit:SetJustifyH("CENTER")
	if edit.SetTextColor then
		edit:SetTextColor(1, 1, 1, 1)
	end
	GF.UI.TrackEditBox(edit, "GameFontHighlightSmall")
	applyEditBoxSizeOverride(edit, "GameFontHighlightSmall", 14, "")
	shell.edit = edit

	shell:SetScript("OnEnter", function(self)
		self._gfCopyInputHovered = true
		updateCopyInputState(self)
	end)
	shell:SetScript("OnLeave", function(self)
		self._gfCopyInputHovered = nil
		updateCopyInputState(self)
	end)
	shell:SetScript("OnMouseDown", function(self)
		if self.edit then
			self.edit:SetFocus()
			self.edit:HighlightText()
		end
	end)
	edit:SetScript("OnEnter", function()
		shell._gfCopyInputHovered = true
		updateCopyInputState(shell)
	end)
	edit:SetScript("OnLeave", function()
		shell._gfCopyInputHovered = nil
		updateCopyInputState(shell)
	end)

	updateCopyInputState(shell)
	return shell, edit
end

local function configureReadonlyCopyEdit(dialog, input, edit)
	if not dialog or not input or not edit then
		return
	end
	edit:SetScript("OnEscapePressed", function()
		dialog:Hide()
	end)
	edit:SetScript("OnEditFocusGained", function(self)
		updateCopyInputState(input)
		self:HighlightText()
	end)
	edit:SetScript("OnEditFocusLost", function()
		updateCopyInputState(input)
	end)
	edit:SetScript("OnMouseUp", function(self)
		self:HighlightText()
	end)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self._gfExpectedText and self:GetText() ~= self._gfExpectedText then
			self:SetText(self._gfExpectedText)
			self:SetCursorPosition(0)
			self:HighlightText()
		end
	end)
end

local function centerPanelButtonText(button)
	if not button or not button.GetFontString then
		return
	end
	local fs = button:GetFontString()
	if not fs then
		return
	end
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", button, "CENTER", 0, 0)
	fs:SetJustifyH("CENTER")
	if fs.SetJustifyV then
		fs:SetJustifyV("MIDDLE")
	end
	fs:SetWidth(math.max(1, button:GetWidth() or GF.PANEL_BUTTON_STANDARD_W or 72))
	fs:SetHeight(math.max(1, button:GetHeight() or GF.PANEL_BUTTON_H or 24))
end

local function isCopyShortcutKey(key)
	if type(key) ~= "string" or string.upper(key) ~= "C" then
		return false
	end
	local ctrlDown = IsControlKeyDown and IsControlKeyDown()
	local metaDown = IsMetaKeyDown and IsMetaKeyDown()
	return ctrlDown or metaDown
end

local function ensureApplicantCopyNameDialog()
	if AMB.copyNameDialog then
		return AMB.copyNameDialog
	end
	local L = GF.L or {}
	local dialog = GF.UI.CreateSatelliteSettingsFrame({
		name = "GroupFinderAddonApplicantCopyNameDialog",
		width = 420,
		height = 164,
		title = L.APPLICANT_COPY_NAME_DIALOG_TITLE or L.APPLICANT_COPY_NAME or "复制角色名称",
		levelOffset = 18,
	})
	dialog:SetFrameStrata("DIALOG")
	if dialog.SetToplevel then
		dialog:SetToplevel(true)
	end

	dialog.hint = GF.UI.CreateFontString(dialog, "OVERLAY", "GameFontHighlightSmall")
	dialog.hint:SetPoint("TOPLEFT", dialog, "TOPLEFT", 34, -54)
	dialog.hint:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -34, -54)
	dialog.hint:SetJustifyH("CENTER")
	if dialog.hint.SetSpacing then
		dialog.hint:SetSpacing(2)
	end
	applyFontStringSizeOverride(dialog.hint, "GameFontHighlightSmall", 13, "")
	dialog.hint:SetText(L.APPLICANT_COPY_NAME_HINT or "角色名称已选中，请使用快捷键复制名称")

	dialog.copyInput, dialog.copyEdit = createCopyNameInput(dialog)
	dialog.copyInput:SetPoint("TOP", dialog.hint, "BOTTOM", 0, -10)
	dialog.copyEdit:SetScript("OnEscapePressed", function()
		dialog:Hide()
	end)
	dialog.copyEdit:SetScript("OnEditFocusGained", function(self)
		updateCopyInputState(dialog.copyInput)
		self:HighlightText()
	end)
	dialog.copyEdit:SetScript("OnEditFocusLost", function()
		updateCopyInputState(dialog.copyInput)
	end)
	dialog.copyEdit:SetScript("OnMouseUp", function(self)
		self:HighlightText()
	end)
	dialog.copyEdit:SetScript("OnKeyDown", function(_, key)
		if not isCopyShortcutKey(key) or dialog._gfCopyClosePending then
			return
		end
		dialog._gfCopyClosePending = true
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				dialog._gfCopyClosePending = nil
				if dialog:IsShown() then
					dialog:Hide()
				end
			end)
		else
			dialog._gfCopyClosePending = nil
			dialog:Hide()
		end
	end)
	dialog.copyEdit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self._gfExpectedText and self:GetText() ~= self._gfExpectedText then
			self:SetText(self._gfExpectedText)
			self:SetCursorPosition(0)
			self:HighlightText()
		end
	end)

	dialog.closeButton = GF.UI.CreatePanelButton(dialog, CLOSE or "Close", GF.PANEL_BUTTON_STANDARD_W or 72, true)
	dialog.closeButton:SetPoint("TOP", dialog.copyInput, "BOTTOM", 0, -14)
	centerPanelButtonText(dialog.closeButton)
	dialog.closeButton:SetScript("OnClick", function()
		dialog:Hide()
	end)

	AMB.copyNameDialog = dialog
	return dialog
end

local function ensureApplicantCharacterInfoDialog()
	if AMB.characterInfoDialog then
		return AMB.characterInfoDialog
	end
	local L = GF.L or {}
	local dialog = GF.UI.CreateSatelliteSettingsFrame({
		name = "GroupFinderAddonApplicantCharacterInfoDialog",
		width = 560,
		height = 222,
		title = L.APPLICANT_QUERY_CHARACTER or "查询角色信息",
		levelOffset = 18,
	})
	dialog:SetFrameStrata("DIALOG")
	if dialog.SetToplevel then
		dialog:SetToplevel(true)
	end

	dialog.wclLabel = GF.UI.CreateFontString(dialog, "OVERLAY", "GameFontNormal")
	dialog.wclLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 40, -54)
	dialog.wclLabel:SetText(L.APPLICANT_COPY_WCL_LINK or "复制 WCL 链接")
	applyFontStringSizeOverride(dialog.wclLabel, "GameFontNormal", 13, "")

	dialog.wclInput, dialog.wclEdit = createCopyNameInput(dialog, CHARACTER_INFO_LINK_INPUT_W)
	dialog.wclInput:SetPoint("TOPLEFT", dialog.wclLabel, "BOTTOMLEFT", 0, -6)
	dialog.wclEdit:SetJustifyH("LEFT")
	configureReadonlyCopyEdit(dialog, dialog.wclInput, dialog.wclEdit)

	dialog.armoryLabel = GF.UI.CreateFontString(dialog, "OVERLAY", "GameFontNormal")
	dialog.armoryLabel:SetPoint("TOPLEFT", dialog.wclInput, "BOTTOMLEFT", 0, -12)
	dialog.armoryLabel:SetText(L.APPLICANT_COPY_ARMORY_LINK or "复制英雄榜信息")
	applyFontStringSizeOverride(dialog.armoryLabel, "GameFontNormal", 13, "")

	dialog.armoryInput, dialog.armoryEdit = createCopyNameInput(dialog, CHARACTER_INFO_LINK_INPUT_W)
	dialog.armoryInput:SetPoint("TOPLEFT", dialog.armoryLabel, "BOTTOMLEFT", 0, -6)
	dialog.armoryEdit:SetJustifyH("LEFT")
	configureReadonlyCopyEdit(dialog, dialog.armoryInput, dialog.armoryEdit)

	dialog.closeButton = GF.UI.CreatePanelButton(dialog, CLOSE or "Close", GF.PANEL_BUTTON_STANDARD_W or 72, true)
	dialog.closeButton:SetPoint("TOP", dialog.armoryInput, "BOTTOM", 0, -14)
	centerPanelButtonText(dialog.closeButton)
	dialog.closeButton:SetScript("OnClick", function()
		dialog:Hide()
	end)

	AMB.characterInfoDialog = dialog
	return dialog
end

local function raiseApplicantDialogToTop(dialog)
	if GF.UI and GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
	if GF.UI and GF.UI.RaiseFrame then
		GF.UI.RaiseFrame(dialog)
	elseif dialog and dialog.Raise then
		dialog:Raise()
	end
end

local function openApplicantCharacterInfoDialog(name, links)
	links = links or buildApplicantCharacterLinks(name)
	if not links then
		return
	end
	local L = GF.L or {}
	local dialog = ensureApplicantCharacterInfoDialog()
	GF.UI.PresentSatelliteFrame(dialog, {
		title = L.APPLICANT_QUERY_CHARACTER or "查询角色信息",
		offsetY = 20,
		prepare = function(frame)
			frame.wclLabel:SetText(L.APPLICANT_COPY_WCL_LINK or "复制 WCL 链接")
			frame.armoryLabel:SetText(L.APPLICANT_COPY_ARMORY_LINK or "复制英雄榜信息")
			frame.wclEdit._gfExpectedText = links.wcl or ""
			frame.wclEdit:SetText(links.wcl or "")
			frame.wclEdit:SetCursorPosition(0)
			frame.armoryEdit._gfExpectedText = links.armory or ""
			frame.armoryEdit:SetText(links.armory or "")
			frame.armoryEdit:SetCursorPosition(0)
		end,
		onShown = function(frame)
			frame.wclEdit:SetFocus()
			frame.wclEdit:HighlightText()
		end,
	})
	raiseApplicantDialogToTop(dialog)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if dialog:IsShown() then
				dialog.wclEdit:SetFocus()
				dialog.wclEdit:HighlightText()
			end
		end)
	end
end

local function openApplicantNameCopyDialog(name)
	if not name or name == "" then
		return
	end
	local L = GF.L or {}
	local dialog = ensureApplicantCopyNameDialog()
	GF.UI.PresentSatelliteFrame(dialog, {
		title = L.APPLICANT_COPY_NAME_DIALOG_TITLE or L.APPLICANT_COPY_NAME or "复制角色名称",
		offsetY = 20,
		prepare = function(frame)
			frame.hint:SetText(L.APPLICANT_COPY_NAME_HINT or "角色名称已选中，请使用快捷键复制名称")
			frame._gfCopyClosePending = nil
			frame.copyEdit._gfExpectedText = name
			frame.copyEdit:SetText(name)
			frame.copyEdit:SetCursorPosition(0)
		end,
		onShown = function(frame)
			frame.copyEdit:SetFocus()
			frame.copyEdit:HighlightText()
		end,
	})
	raiseApplicantDialogToTop(dialog)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if dialog:IsShown() then
				dialog.copyEdit:SetFocus()
				dialog.copyEdit:HighlightText()
			end
		end)
	end
end

local function canUseApplicantBlocklist()
	local bl = GF.Blocklist
	return bl and bl.IsEnabled and bl:IsEnabled() and bl.AddLeader
end

local function addApplicantToBlocklist(row, name)
	local bl = GF.Blocklist
	if not name or name == "" or not canUseApplicantBlocklist() then
		return
	end
	local note = bl.GetBlacklistNoteManual and bl:GetBlacklistNoteManual() or nil
	local L = GF.L or {}
	local ok = bl:AddLeader(name, note, L.BLOCKLIST_SOURCE_MANUAL or "加入黑名单")
	if ok then
		if row and row._layoutMemberData then
			row._layoutMemberData.isBlacklisted = true
			row._layoutMemberData.blacklistEntry = bl.FindPlayerMatch and bl:FindPlayerMatch(name) or true
		end
		if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
			GF.ApplicantsPanel:Refresh({ preserveScroll = true })
		end
	end
end

local function lockApplicantContextMenu(row)
	if not row then
		return nil
	end
	local token = (tonumber(row._applicantContextMenuToken) or 0) + 1
	row._applicantContextMenuToken = token
	row._applicantContextMenuLocked = true
	setMemberRowHover(row, true)
	return token
end

local function finishApplicantContextMenu(row, token)
	if not row or row._applicantContextMenuToken ~= token then
		return
	end
	row._applicantContextMenuLocked = nil
	row._applicantContextMenuToken = nil
	setMemberRowHover(row, row.IsMouseOver and row:IsMouseOver())
end

function AMB:ShowContextMenu(row)
	if not row or not (GF.RowContextMenu and GF.RowContextMenu.ShowMenu) then
		return
	end
	if row._layoutMemberData and row._layoutMemberData.isTest then
		return
	end
	local name = getApplicantMenuName(row)
	local hasName = type(name) == "string" and name ~= ""
	local characterLinks = hasName and buildApplicantCharacterLinks(name) or nil
	local title = getApplicantMenuTitle(row, name)
	local token = lockApplicantContextMenu(row)
	local L = GF.L or {}
	if GameTooltip then
		GameTooltip:Hide()
	end
	local menuItems = {
		{
			isTitle = true,
			text = title or "",
		},
		{
			text = L.APPLICANT_COPY_NAME or "复制角色名称",
			disabled = not hasName,
			func = function()
				openApplicantNameCopyDialog(name)
			end,
		},
		{
			text = L.APPLICANT_QUERY_CHARACTER or "查询角色信息",
			textColor = APPLICANT_QUERY_MENU_COLOR,
			disabled = not characterLinks,
			func = function()
				openApplicantCharacterInfoDialog(name, characterLinks)
			end,
		},
		{
			text = WHISPER or "密语",
			disabled = not hasName,
			func = function()
				whisperApplicant(name)
			end,
		},
		{
			text = LFG_LIST_REPORT_PLAYER or REPORT_PLAYER or "举报玩家",
			disabled = not (hasName and LFGList_ReportApplicant),
			func = function()
				if LFGList_ReportApplicant then
					pcall(LFGList_ReportApplicant, row.applicantID, name or "")
				end
			end,
		},
		{
			text = BLACKLIST_MENU_MARKUP .. (L.BLOCKLIST_SOURCE_MANUAL or "加入黑名单"),
			textColor = { 1, 0.12, 0.12, 1 },
			disabled = not (hasName and canUseApplicantBlocklist()),
			func = function()
				addApplicantToBlocklist(row, name)
			end,
		},
	}
	GF.RowContextMenu:ShowMenu(menuItems, {
		onClose = function()
			finishApplicantContextMenu(row, token)
		end,
	})
end

function AMB:Create(parent)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(parent:GetWidth() or 400, memberRowH())

	f.background = f:CreateTexture(nil, "BACKGROUND", nil, -2)
	f.background:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -2)
	f.background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 0)
	f.background:SetTexture(ROW_TEXTURE_NORMAL)
	f.background:SetAlpha(getRowBackgroundAlpha())
	f.background:Hide()
	f.backgroundPieces = createRowBackgroundPieces(f, -2)
	f.backgroundTransitionPieces = createRowBackgroundPieces(f, -1)
	setRowBackgroundPiecesShown(f.backgroundTransitionPieces, false)

	f.highlight = f:CreateTexture(nil, "HIGHLIGHT")
	f.highlight:SetAtlas("groupfinder-highlightbar-blue")
	f.highlight:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
	f.highlight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, -1)
	f.highlight:SetBlendMode("ADD")
	f.highlight:Hide()
	createRowHoverTextures(f)
	createRowSelectedTexture(f)

	f.title = GF.UI.CreateFontString(f, "OVERLAY", "GameFontNormal")
	f.title:SetJustifyH("CENTER")
	f.title:SetJustifyV("MIDDLE")
	f.title:SetMaxLines(1)
	f.title:SetWordWrap(false)

	f.factionIcon = f:CreateTexture(nil, "ARTWORK")
	do
		local typeIconSize = getTypeStatusIconSize()
		f.factionIcon:SetSize(typeIconSize, typeIconSize)
	end
	f.factionIcon:Hide()

	f.leaverIcon = f:CreateTexture(nil, "ARTWORK")
	do
		local typeIconSize = getTypeStatusIconSize()
		f.leaverIcon:SetSize(typeIconSize, typeIconSize)
	end
	if f.leaverIcon.SetAtlas then
		f.leaverIcon:SetAtlas("groupfinder-icon-leaver")
	end
	f.leaverIcon:Hide()

	f.friendIcon = f:CreateTexture(nil, "ARTWORK")
	do
		local typeIconSize = getTypeStatusIconSize()
		f.friendIcon:SetSize(typeIconSize, typeIconSize)
	end
	if f.friendIcon.SetAtlas then
		f.friendIcon:SetAtlas("groupfinder-icon-friend")
	end
	f.friendIcon:Hide()

	f.typeGroup = CreateFrame("Frame", nil, f)
	f.typeGroup:SetSize(1, 18)
	f.typeGroup:Hide()

	f.typeText = GF.UI.CreateFontString(f.typeGroup, "OVERLAY", "GameFontDisableSmall")
	f.typeText:SetJustifyH("CENTER")
	f.typeText:SetJustifyV("MIDDLE")
	f.typeText:SetMaxLines(1)
	f.typeText:SetWordWrap(false)

	f.typeIcon = f.typeGroup:CreateTexture(nil, "ARTWORK")
	do
		local typeIconSize = getTypeStatusIconSize()
		f.typeIcon:SetSize(typeIconSize, typeIconSize)
	end
	f.typeIcon:Hide()

	f.detail = GF.UI.CreateFontString(f, "OVERLAY", "GameFontDisableSmall")
	f.detail:SetJustifyH("LEFT")
	f.detail:SetJustifyV("MIDDLE")
	f.detail:SetMaxLines(1)
	f.detail:SetWordWrap(false)

	f.roles = CreateFrame("Frame", nil, f)
	f.roles:SetSize(math.max(ROLE_W, getRoleStripWidth(3)), getRoleIconSize())

	f.roleBtns = {}
	for i = 1, 3 do
		local btn = CreateFrame("Button", nil, f.roles)
		do
			local roleIconSize = getRoleIconSize()
			btn:SetSize(roleIconSize, roleIconSize)
		end
		btn.normal = btn:CreateTexture(nil, "ARTWORK")
		btn.normal:SetAllPoints()
		btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
		btn.highlight:SetAllPoints()
		btn:SetScript("OnClick", function(self)
			if not canAssignRoles() or not self.role or not self.memberIdx then
				return
			end
			local row = self:GetParent():GetParent()
			if row and row._layoutMemberData and row._layoutMemberData.isTest then
				return
			end
			local card = row and row:GetParent()
			local applicantID = card and card.applicantID
			if applicantID and C_LFGList.SetApplicantMemberRole then
				C_LFGList.SetApplicantMemberRole(applicantID, self.memberIdx, self.role)
			end
		end)
		f.roleBtns[i] = btn
	end

	f.classText = GF.UI.CreateFontString(f, "OVERLAY", "GameFontHighlightSmall")
	f.classText:SetJustifyH("CENTER")
	f.classText:SetJustifyV("MIDDLE")
	f.classText:SetMaxLines(1)
	f.classText:SetWordWrap(false)

	f.specIcon = f:CreateTexture(nil, "ARTWORK")
	do
		local specIconSize = getSpecIconSize()
		f.specIcon:SetSize(specIconSize, specIconSize)
	end
	f.specIcon:Hide()

	f.ilvlText = GF.UI.CreateFontString(f, "OVERLAY", "GameFontDisableSmall")
	f.ilvlText:SetJustifyH("CENTER")
	f.ilvlText:SetJustifyV("MIDDLE")
	f.ilvlText:SetMaxLines(1)
	f.ilvlText:SetWordWrap(false)

	f.scoreTexts = {}
	for i = 1, SCORE_PART_COUNT do
		local fs = GF.UI.CreateFontString(f, "OVERLAY", "GameFontDisableSmall")
		fs:SetJustifyH("CENTER")
		fs:SetJustifyV("MIDDLE")
		fs:SetMaxLines(1)
		fs:SetWordWrap(false)
		f.scoreTexts[i] = fs
	end

	f:SetScript("OnEnter", function(self)
		if GF.ListRow and GF.ListRow.IsHoverHighlightEnabled and GF.ListRow:IsHoverHighlightEnabled() and self.highlight then
			setMemberRowHover(self, true)
		end
		if not (GF.ListRow and GF.ListRow.IsHoverTooltipEnabled and GF.ListRow:IsHoverTooltipEnabled()) then
			return
		end
		if not self.applicantID or not self.memberIdx then
			return
		end
		showApplicantMemberTooltip(self)
	end)
	f:SetScript("OnLeave", function(self)
		setMemberRowHover(self, false)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	f:SetScript("OnMouseDown", function(self)
		if GF.ApplicantsPanel and GF.ApplicantsPanel.SetSelectedApplicantRow then
			GF.ApplicantsPanel:SetSelectedApplicantRow(self)
		end
	end)
	f:SetScript("OnMouseUp", function(self, button)
		if button ~= "RightButton" then
			return
		end
		AMB:ShowContextMenu(self)
	end)

	return f
end

function AMB:GetColWidth(row, colID)
	local col = row._columnLayout and row._columnLayout.byId[colID]
	return col and col.width or 0
end

function AMB:LayoutIconsAfterTitle(member, memberData)
	member.factionIcon:Hide()
	member.leaverIcon:Hide()
	member.friendIcon:Hide()
end

function AMB:UpdateRoles(member, memberData)
	local roles = { memberData.role1, memberData.role2, memberData.role3 }
	local canManage = canAssignRoles() and not memberData.grayed and not memberData.noTouchy
	local visible = {}
	local roleIconSize = getRoleIconSize()
	for i = 1, 3 do
		local btn = member.roleBtns[i]
		local role = roles[i]
		btn.memberIdx = memberData.memberIdx
		btn.role = role
		if role and not memberData.grayed then
			btn:Show()
			btn:ClearAllPoints()
			btn:SetSize(roleIconSize, roleIconSize)
			setRoleAtlas(btn.normal, role)
			setRoleAtlas(btn.highlight, role)
			local assigned = memberData.assignedRole == role
			btn.normal:SetAlpha(assigned and 1 or 0.35)
			btn.highlight:SetAlpha(assigned and 1 or 0.35)
			btn:SetEnabled(canManage and not memberData.noTouchy and role ~= memberData.assignedRole)
			visible[#visible + 1] = btn
		else
			btn:Hide()
		end
	end
	local count = #visible
	if count > 0 then
		local totalW = (roleIconSize * count) + (ROLE_ICON_GAP * math.max(0, count - 1))
		local frameW = member.roles and member.roles:GetWidth() or ROLE_W
		local startX = math.max(0, (frameW - totalW) / 2)
		for i, btn in ipairs(visible) do
			btn:SetPoint("LEFT", member.roles, "LEFT", startX + ((i - 1) * (roleIconSize + ROLE_ICON_GAP)), 0)
		end
	end
end

local function wrapScoreColor(color, text)
	if color and color.WrapTextInColorCode then
		return color:WrapTextInColorCode(text)
	end
	return text
end

local function maybeWrapScoreColor(memberData, color, text)
	if memberIsBlacklisted(memberData) and not memberData.grayed then
		return text
	end
	return wrapScoreColor(color, text)
end

-- memberData.class 已在 ApplicantModel:BuildMember 缓存；这里只查 RAID_CLASS_COLORS，不额外调 API。
local function memberClassRGB(classFile, grayed, fallbackR, fallbackG, fallbackB)
	if grayed then
		local g = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
		return g.r, g.g, g.b
	end
	if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
		local c = RAID_CLASS_COLORS[classFile]
		return c.r, c.g, c.b
	end
	return fallbackR or 1, fallbackG or 1, fallbackB or 1
end

local function currentRealmName()
	local realm = GetNormalizedRealmName and GetNormalizedRealmName()
	if type(realm) ~= "string" or realm == "" then
		realm = GetRealmName and GetRealmName()
	end
	if type(realm) == "string" and realm ~= "" then
		return realm
	end
	return nil
end

local function fullPlayerName(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if name:find("-", 1, true) then
		return name
	end
	local realm = currentRealmName()
	if realm and realm ~= "" then
		return name .. "-" .. realm
	end
	return name
end

local function applicantListName(memberData)
	if not memberData then
		return "?"
	end
	local db = GF.GetDB and GF.GetDB()
	if db and db.showLeaderRealm == true then
		return fullPlayerName(memberData.name) or memberData.displayName or "?"
	end
	return memberData.displayName or memberData.name or "?"
end

local function formatMplusKeyLevel(detail, plain)
	local pluses = ""
	if detail.bestLevelIncrement and detail.bestLevelIncrement > 0 and GROUPFINDER_PLUS then
		for _ = 1, detail.bestLevelIncrement do
			pluses = pluses .. GROUPFINDER_PLUS
		end
	end
	local level = detail.bestRunLevel or 0
	local body = pluses .. level .. "层"
	if plain then
		return body
	end
	if detail.finishedSuccess then
		return "|cff00ff00" .. body .. "|r"
	end
	return "|cff7f7f7f" .. body .. "|r"
end

local function formatRatingValue(memberData)
	if not (memberData and memberData.ratingValue) then
		return nil
	end
	local text = tostring(memberData.ratingValue)
	if memberData.ratingColor and not memberIsBlacklisted(memberData) then
		local c = memberData.ratingColor
		local hex = string.format("|cff%02x%02x%02x",
			math.floor((c.r or 1) * 255 + 0.5),
			math.floor((c.g or 1) * 255 + 0.5),
			math.floor((c.b or 1) * 255 + 0.5))
		return hex .. text .. "|r"
	end
	return text
end

local function formatScoreParts(memberData)
	if memberData.ratingKind == "level" and memberData.ratingValue then
		return { "", tostring(memberData.ratingValue), "" }
	end
	if memberData.ratingKind == "mplus" and memberData.ratingDetail then
		local d = memberData.ratingDetail
		local parts = { "-", "-", "-" }
		if d.overall and d.overall > 0 then
			local c = (C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(d.overall))
				or HIGHLIGHT_FONT_COLOR
			parts[1] = maybeWrapScoreColor(memberData, c, tostring(d.overall))
		end
		if d.mapScore and d.mapScore > 0 then
			local c = (C_ChallengeMode and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(d.mapScore))
				or HIGHLIGHT_FONT_COLOR
			parts[2] = maybeWrapScoreColor(memberData, c, tostring(d.mapScore))
		end
		if d.bestRunLevel and d.bestRunLevel > 0 then
			parts[3] = formatMplusKeyLevel(d, memberIsBlacklisted(memberData) and not memberData.grayed)
		end
		return parts
	end
	if memberData.ratingKind == "rating" and memberData.ratingValue then
		return { "", formatRatingValue(memberData) or "", "" }
	end
	if memberData.ratingKind == "rating" then
		return { "", "-", "" }
	end
	return nil
end

local function formatScoreText(parts)
	local out = {}
	for _, text in ipairs(parts or {}) do
		if text and text ~= "" then
			out[#out + 1] = text
		end
	end
	return table.concat(out, " / ")
end

local function setScoreParts(member, parts)
	for i, fs in ipairs(member.scoreTexts or {}) do
		local text = parts and parts[i] or ""
		if text and text ~= "" then
			GF.UI.SetEllipsisText(fs, text, fs:GetWidth())
		else
			fs:SetText("")
		end
	end
end

local function forEachScoreText(member, fn)
	for _, fs in ipairs(member.scoreTexts or {}) do
		fn(fs)
	end
end

function AMB:SetData(member, applicantID, memberData, opts)
	opts = opts or {}
	if not member then
		return
	end
	if not memberData then
		resetApplicantRowBackgroundTransition(member)
		return
	end
	member.applicantID = applicantID
	member.memberIdx = memberData.memberIdx
	member._layoutMemberData = memberData
	member._backgroundMode = opts.backgroundMode
	member._groupVisualState = opts.groupVisualState

	if opts.width and opts.width > 0 then
		member:SetWidth(opts.width)
	end
	self:LayoutMember(member)
	applyMemberRowVisual(member, memberData, opts.backgroundMode, opts.groupVisualState)
	self:UpdateSelectedState(member)

	local name = applicantListName(memberData)
	member._nameText = name
	local nr, ng, nb = memberClassRGB(memberData.class, false, 1, 1, 1)
	if memberIsBlacklisted(memberData) and not memberData.grayed then
		nr, ng, nb = 1, 0.08, 0.05
	end
	member.title:SetTextColor(nr, ng, nb)
	local nameColW = math.max(1, self:GetColWidth(member, "name") - titleIconReserveWidth(memberData))
	GF.UI.SetEllipsisText(member.title, name, nameColW)
	self:LayoutIconsAfterTitle(member, memberData)
	self:UpdateRoles(member, memberData, applicantID)

	local typeText = getMemberTypeLabel(memberData)
	member._typeText = typeText
	member._typeKind = getMemberTypeKind(memberData)
	setTypeTextColor(member.typeText, memberData)
	if typeText ~= "" then
		layoutTypeCell(member, member._typeKind, typeText)
	else
		if member.typeGroup then
			member.typeGroup:Hide()
		end
		if member.typeIcon then
			member.typeIcon:Hide()
		end
		member.typeText:SetText("")
		member.typeText:Hide()
	end

	local detailText = opts.descriptionText or ""
	member._detailText = detailText
	if detailText ~= "" then
		GF.UI.SetEllipsisText(member.detail, detailText, self:GetColWidth(member, "detail"))
	else
		member.detail:SetText("")
	end

	local spec = memberData.specText or ""
	member._classText = spec
	local specIcon = getSpecIconTexture(memberData)
	member._specIcon = specIcon
	if specIcon then
		member.specIcon:SetTexture(specIcon)
		member.specIcon:SetTexCoord(0, 1, 0, 1)
		member.specIcon:SetDesaturated(memberData.grayed == true)
		member.specIcon:SetAlpha(memberData.grayed and 0.5 or 1)
		member.specIcon:Show()
		member.classText:SetText("")
		member.classText:Hide()
	elseif spec ~= "" then
		member.specIcon:Hide()
		member.classText:Show()
		GF.UI.SetEllipsisText(member.classText, spec, self:GetColWidth(member, "class"))
	else
		member.specIcon:Hide()
		member.classText:SetText("")
	end

	local ilvl = memberData.ilvl
	member._ilText = ilvl
	if ilvl and ilvl > 0 then
		local ir, ig, ib = GF.ApplicantModel.GetIlvlValueColor()
		if memberIsBlacklisted(memberData) and not memberData.grayed then
			ir, ig, ib = 1, 0.08, 0.05
		end
		member.ilvlText:SetTextColor(ir, ig, ib)
		GF.UI.SetEllipsisText(member.ilvlText, tostring(ilvl), self:GetColWidth(member, "ilvl"))
	else
		member.ilvlText:SetText("")
	end

	local scoreParts = formatScoreParts(memberData)
	local scoreText = formatScoreText(scoreParts)
	member._scoreText = scoreText
	member._scoreParts = scoreParts
	setScoreParts(member, scoreParts)

	local alpha = memberData.grayed and 0.5 or 1
	member.title:SetAlpha(alpha)
	member.typeText:SetAlpha(alpha)
	if member.typeIcon then
		member.typeIcon:SetAlpha(alpha)
		member.typeIcon:SetDesaturated(memberData.grayed == true)
	end
	member.detail:SetAlpha(alpha)
	member.classText:SetAlpha(alpha)
	if member.specIcon then
		member.specIcon:SetAlpha(alpha)
	end
	member.ilvlText:SetAlpha(alpha)
	forEachScoreText(member, function(fs)
		fs:SetAlpha(alpha)
	end)
	if memberData.grayed then
		local g = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
		member.detail:SetTextColor(g.r, g.g, g.b)
	elseif memberIsBlacklisted(memberData) then
		member.detail:SetTextColor(1, 0.08, 0.05)
	else
		member.detail:SetTextColor(0.8, 0.8, 0.8)
	end
	local cr, cg, cb = memberClassRGB(memberData.class, memberData.grayed, 0.8, 0.8, 0.8)
	if memberIsBlacklisted(memberData) and not memberData.grayed then
		cr, cg, cb = 1, 0.08, 0.05
	end
	member.classText:SetTextColor(cr, cg, cb)
	forEachScoreText(member, function(fs)
		if memberIsBlacklisted(memberData) and not memberData.grayed then
			fs:SetTextColor(1, 0.08, 0.05)
		else
			fs:SetTextColor(0.8, 0.8, 0.8)
		end
	end)
end

function AMB:LayoutOnly(member, width)
	if not member then
		return
	end
	if width and width > 0 then
		member:SetWidth(width)
	end
	self:LayoutMember(member)
	if member._nameText then
		local reserve = member._layoutMemberData and titleIconReserveWidth(member._layoutMemberData) or 0
		GF.UI.SetEllipsisText(member.title, member._nameText, math.max(1, self:GetColWidth(member, "name") - reserve))
	end
	if member._layoutMemberData then
		applyMemberRowVisual(member, member._layoutMemberData, member._backgroundMode, member._groupVisualState)
		self:LayoutIconsAfterTitle(member, member._layoutMemberData)
		self:UpdateRoles(member, member._layoutMemberData)
	end
	if member._typeText and member._typeText ~= "" then
		setTypeTextColor(member.typeText, member._layoutMemberData)
		layoutTypeCell(member, member._typeKind, member._typeText)
	else
		if member.typeGroup then
			member.typeGroup:Hide()
		end
		if member.typeIcon then
			member.typeIcon:Hide()
		end
		member.typeText:SetText("")
		member.typeText:Hide()
	end
	if member._detailText and member._detailText ~= "" then
		GF.UI.SetEllipsisText(member.detail, member._detailText, self:GetColWidth(member, "detail"))
	else
		member.detail:SetText("")
	end
	if member._classText and member._classText ~= "" then
		if member._specIcon then
			member.specIcon:SetTexture(member._specIcon)
			member.specIcon:Show()
			member.classText:SetText("")
			member.classText:Hide()
		else
			member.specIcon:Hide()
			member.classText:Show()
			GF.UI.SetEllipsisText(member.classText, member._classText, self:GetColWidth(member, "class"))
		end
	else
		if member.specIcon then
			member.specIcon:Hide()
		end
		member.classText:SetText("")
	end
	if member._ilText and member._ilText > 0 then
		GF.UI.SetEllipsisText(member.ilvlText, tostring(member._ilText), self:GetColWidth(member, "ilvl"))
	else
		member.ilvlText:SetText("")
	end
	setScoreParts(member, member._scoreParts)
end

function AMB:GetActionsColumnLayout(width)
	return resolveLayout(width)
end
