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

local ROLE_ATLAS = GF.SEASON_DUNGEON_ROLE_ATLAS

local BLACKLIST_ICON_TEXTURE = GF.BLACKLIST_ICON_TEXTURE
local LEAVER_ICON_TEXTURE = GF.LEAVER_ICON_TEXTURE
local BLACKLIST_MENU_MARKUP = string.format("|T%s:%d:%d:0:0|t ", BLACKLIST_ICON_TEXTURE, TYPE_STATUS_ICON_SIZE, TYPE_STATUS_ICON_SIZE)
local APPLICANT_QUERY_MENU_COLOR = { 1, 0.82, 0, 1 }
local SOCIAL_APPLICANT_LABEL_FALLBACK = GF.SOCIAL_APPLICANT_LABEL_FALLBACK
local TOOLTIP_FACTION_ICON_SIZE = 14
local TOOLTIP_FACTION_TEXTURES = GF.FACTION_ICON_TEXTURES

local ROW_BACKGROUND_FALLBACK_TEXTURE = GF.ROW_BACKGROUND_FALLBACK_TEXTURE
local ROW_BACKGROUND_ALPHA = GF.BROWSE_ROW_BACKGROUND_ALPHA or 0.92
local ROW_BACKGROUND_FADE_SECONDS = GF.BROWSE_ROW_BACKGROUND_FADE_SECONDS or 0.16
local ROW_BACKGROUND_SOURCE_WIDTH = GF.ROW_BACKGROUND_SOURCE_WIDTH or 564
local ROW_BACKGROUND_SOURCE_HEIGHT = GF.ROW_BACKGROUND_SOURCE_HEIGHT or 52
local ROW_BACKGROUND_SOURCE_CAP_WIDTH = GF.ROW_BACKGROUND_SOURCE_CAP_WIDTH or 18
local ROW_BACKGROUND_TOP_SOURCE_HEIGHT = GF.ROW_BACKGROUND_TOP_SOURCE_HEIGHT or 8
local ROW_BACKGROUND_INSET_TOP = GF.APPLICANT_ROW_BACKGROUND_INSET_TOP or 2
local ROW_BACKGROUND_INSET_BOTTOM = GF.APPLICANT_ROW_BACKGROUND_INSET_BOTTOM or 0
local ROW_CONTENT_OFFSET_Y = GF.APPLICANT_ROW_CONTENT_OFFSET_Y or -1
local ROW_HOVER_COLOR = GF.BROWSE_ROW_HOVER_COLOR or { 1, 0.74, 0.18, 0.13 }
local ROW_HOVER_RED_COLOR = GF.BROWSE_ROW_HOVER_RED_COLOR or { 1, 0.12, 0.08, 0.18 }
local ROW_HOVER_BLUE_COLOR = GF.BROWSE_ROW_HOVER_BLUE_COLOR or { 0.35, 0.75, 1, 0.16 }
local ROW_HOVER_GREY_COLOR = GF.BROWSE_ROW_HOVER_GREY_COLOR or { 0.65, 0.65, 0.65, 0.18 }
local ROW_SELECTED_ALPHA = GF.BROWSE_ROW_SELECTED_ALPHA or 1
local ROW_SELECTED_COLOR =
	GF.BROWSE_ROW_SELECTED_COLOR or { 1, 0.9, 0.08, 0.82 }
local ROW_SELECTED_BLUE_COLOR = { 0.18, 0.86, 1, 0.78 }
local ROW_SELECTED_RED_COLOR = { 1, 0.05, 0.03, 0.86 }
local ROW_SELECTED_GREY_COLOR = { 0.82, 0.82, 0.82, 0.68 }

local function applicantRowKey(applicantID, memberIdx)
	return tostring(applicantID or "") .. ":" .. tostring(memberIdx or 1)
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
	if memberData.isLaonongFan then
		return GF.SOCIAL_TYPE_LAONONG
	end
	local relationshipType = getRelationshipType(memberData.relationship)
	if relationshipType then
		return relationshipType
	end
	return nil
end

local function getMemberTooltipTypeKind(memberData)
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

local getMemberTypeLabelForKind

local function getMemberTypeLabel(memberData)
	if not memberData then
		return ""
	end
	local L = GF.L or {}
	local kind = getMemberTypeKind(memberData)
	return getMemberTypeLabelForKind(kind, L)
end

getMemberTypeLabelForKind = function(kind, localeTable)
	local L = localeTable or GF.L or {}
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
		return
	end
	local kind = getMemberTypeKind(memberData)
	if kind == "blacklist" or kind == "leaver" then
		fontString:SetTextColor(1, 0.08, 0.05)
	elseif kind then
		local c = (GF.GetSocialTypeTextColor and GF.GetSocialTypeTextColor(kind))
			or GF.SOCIAL_TEXT_COLOR
			or { r = 0.35, g = 0.75, b = 1 }
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
	if GF.UI and GF.UI.ResolveSpecializationIcon then
		return GF.UI.ResolveSpecializationIcon({
			specID = memberData.specID,
			specName = memberData.specName or memberData.specText,
			classFile = memberData.class,
			role = memberData.assignedRole or memberData.role,
		})
	end
	return nil
end

local function createRowOverlayPieces(row, subLevel)
	local pieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(row, "BORDER", subLevel or -1)
		or nil
	if not (pieces and pieces.left and pieces.middle and pieces.right) then
		pieces = {}
		for _, key in ipairs({ "left", "middle", "right" }) do
			pieces[key] = row:CreateTexture(nil, "BORDER", nil, subLevel or -1)
		end
	end
	return pieces
end

local function setRowOverlayShown(pieces, shown)
	if GF.UI and GF.UI.SetRowBackgroundPiecesShown then
		GF.UI.SetRowBackgroundPiecesShown(pieces, shown == true)
		return
	end
	for _, piece in pairs(pieces or {}) do
		if piece.SetShown then
			piece:SetShown(shown == true)
		end
	end
end

local function applyRowOverlayPieces(row, pieces, color)
	if not (row and pieces and GF.UI and GF.UI.ApplyRowBackgroundPieces) then
		return false
	end
	return GF.UI.ApplyRowBackgroundPieces(row, pieces, {
		state = "normal",
		mode = "full",
		alpha = ROW_SELECTED_ALPHA,
		vertexColor = color or ROW_HOVER_COLOR,
		desaturated = true,
		fallbackTexture = ROW_BACKGROUND_FALLBACK_TEXTURE,
		insetLeft = 3,
		insetRight = 3,
		insetTop = ROW_BACKGROUND_INSET_TOP,
		insetBottom = ROW_BACKGROUND_INSET_BOTTOM,
		sourceWidth = ROW_BACKGROUND_SOURCE_WIDTH,
		sourceHeight = ROW_BACKGROUND_SOURCE_HEIGHT,
		sourceCapWidth = ROW_BACKGROUND_SOURCE_CAP_WIDTH,
		topSourceHeight = ROW_BACKGROUND_TOP_SOURCE_HEIGHT,
		defaultHeight = memberRowH(),
	})
end

local function setRowHoverTextureColor(row, color)
	if not row then
		return
	end
	row._gfHoverColor = color or ROW_HOVER_COLOR
	applyRowOverlayPieces(row, row.hoverPieces, row._gfHoverColor)
	setRowOverlayShown(row.hoverPieces, row._gfHoverShown == true)
end

local function getRowSelectedColorForState(state)
	if GF.GetListBackgroundOverlayColor then
		return GF.GetListBackgroundOverlayColor(state, "selected")
	end
	if state == "blue" then
		return ROW_SELECTED_BLUE_COLOR
	end
	if state == "red" then
		return ROW_SELECTED_RED_COLOR
	end
	if state == "grey" then
		return ROW_SELECTED_GREY_COLOR
	end
	return ROW_SELECTED_COLOR
end

local function setRowSelectedTextureState(row, state)
	if not row then
		return
	end
	row._gfSelectedState = state or "normal"
	applyRowOverlayPieces(row, row.selectedHighlightPieces, getRowSelectedColorForState(state))
	setRowOverlayShown(row.selectedHighlightPieces, row._gfSelectedShown == true)
end

local function setMemberRowHover(row, shown)
	if row and row._applicantContextMenuLocked and shown ~= true then
		shown = true
	end
	shown = shown == true
	if row and row.highlight then
		row.highlight:SetShown(false)
	end
	if row then
		row._gfHoverShown = shown
	end
	setRowOverlayShown(row and row.hoverPieces, shown)
end

local function setMemberRowSelected(row, shown)
	if row then
		row._gfSelectedShown = shown == true
	end
	setRowOverlayShown(row and row.selectedHighlightPieces, row and row._gfSelectedShown)
end

local function createRowSelectedTexture(row)
	local pieces = createRowOverlayPieces(row, 1)
	for _, piece in pairs(pieces) do
		if piece.SetBlendMode then
			piece:SetBlendMode("ADD")
		end
		piece:SetAlpha(ROW_SELECTED_ALPHA)
	end
	row.selectedHighlightPieces = pieces
	setRowSelectedTextureState(row, "normal")
	setMemberRowSelected(row, false)
	AMB:LayoutHover(row)
end

local function createRowHoverTextures(row)
	local pieces = createRowOverlayPieces(row, -1)
	for _, piece in pairs(pieces) do
		if piece.SetBlendMode then
			piece:SetBlendMode("ADD")
		end
	end
	row.hoverPieces = pieces
	AMB:LayoutHover(row)
	setRowHoverTextureColor(row, ROW_HOVER_COLOR)
	setMemberRowHover(row, false)
end

function AMB:LayoutHover(row)
	if not row then
		return
	end
	if row.highlight then
		row.highlight:ClearAllPoints()
		row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -ROW_BACKGROUND_INSET_TOP)
		row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, ROW_BACKGROUND_INSET_BOTTOM)
	end
	applyRowOverlayPieces(row, row.hoverPieces, row._gfHoverColor or ROW_HOVER_COLOR)
	applyRowOverlayPieces(row, row.selectedHighlightPieces, getRowSelectedColorForState(row._gfSelectedState))
	setRowOverlayShown(row.hoverPieces, row._gfHoverShown == true)
	setRowOverlayShown(row.selectedHighlightPieces, row._gfSelectedShown == true)
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

local function getMemberRowHoverColor(state)
	if GF.GetListBackgroundOverlayColor then
		return GF.GetListBackgroundOverlayColor(state, "hover")
	end
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

local function getRowBackgroundAlpha(state)
	return GF.GetListBackgroundAlpha and GF.GetListBackgroundAlpha(state or "normal") or ROW_BACKGROUND_ALPHA
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
	local pieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(row, "BACKGROUND", subLevel or -2)
		or nil
	if not (pieces and pieces.left and pieces.middle and pieces.right) then
		pieces = {}
		for _, key in ipairs({ "left", "middle", "right" }) do
			pieces[key] = row:CreateTexture(nil, "BACKGROUND", nil, subLevel or -2)
		end
	end
	for _, piece in pairs(pieces) do
		piece:SetAlpha(getRowBackgroundAlpha("normal"))
	end
	return pieces
end

local function setRowBackgroundPieceLayout(row, pieces, piece, key, height, texLeft, texRight, texTop, texBottom, verticalMode, state)
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
	piece:SetAlpha(getRowBackgroundAlpha(state))
	piece:Show()
end

local function setRowBackgroundPiecesShown(pieces, shown)
	for _, piece in pairs(pieces or {}) do
		piece:SetShown(shown == true)
	end
end

local function applyRowBackgroundTexture(row, pieces, state, mode)
	if not pieces then
		return false
	end
	mode = mode or "full"
	state = state or "normal"
	if GF.UI and GF.UI.ApplyRowBackgroundPieces then
		return GF.UI.ApplyRowBackgroundPieces(row, pieces, {
			state = state,
			mode = mode,
			alpha = getRowBackgroundAlpha(state),
			fallbackTexture = ROW_BACKGROUND_FALLBACK_TEXTURE,
			insetLeft = 3,
			insetRight = 3,
			insetTop = ROW_BACKGROUND_INSET_TOP,
			insetBottom = ROW_BACKGROUND_INSET_BOTTOM,
			sourceWidth = ROW_BACKGROUND_SOURCE_WIDTH,
			sourceHeight = ROW_BACKGROUND_SOURCE_HEIGHT,
			sourceCapWidth = ROW_BACKGROUND_SOURCE_CAP_WIDTH,
			topSourceHeight = ROW_BACKGROUND_TOP_SOURCE_HEIGHT,
			defaultHeight = memberRowH(),
		})
	end
	for _, piece in pairs(pieces) do
		piece:SetTexture(ROW_BACKGROUND_FALLBACK_TEXTURE)
		local color = GF.GetListBackgroundColor and GF.GetListBackgroundColor(state) or nil
		if type(color) == "table" then
			piece:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
		else
			piece:SetVertexColor(1, 1, 1, 1)
		end
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
		setRowBackgroundPieceLayout(row, pieces, pieces.left, "left", height, 0, leftTexCoord, 0, topTexBottom, "top", state)
		setRowBackgroundPieceLayout(row, pieces, pieces.middle, "middle", height, leftTexCoord, rightTexCoord, 0, topTexBottom, "top", state)
		setRowBackgroundPieceLayout(row, pieces, pieces.right, "right", height, rightTexCoord, 1, 0, topTexBottom, "top", state)
		return true
	end
	if mode == "bottom" then
		local height = rowBackgroundBottomHeight(row)
		setRowBackgroundPieceLayout(row, pieces, pieces.left, "left", height, 0, leftTexCoord, topTexBottom, 1, "bottom", state)
		setRowBackgroundPieceLayout(row, pieces, pieces.middle, "middle", height, leftTexCoord, rightTexCoord, topTexBottom, 1, "bottom", state)
		setRowBackgroundPieceLayout(row, pieces, pieces.right, "right", height, rightTexCoord, 1, topTexBottom, 1, "bottom", state)
		return true
	end
	local height = rowBackgroundDisplayHeight(row)
	setRowBackgroundPieceLayout(row, pieces, pieces.left, "left", height, 0, leftTexCoord, 0, 1, "top", state)
	setRowBackgroundPieceLayout(row, pieces, pieces.middle, "middle", height, leftTexCoord, rightTexCoord, 0, 1, "top", state)
	setRowBackgroundPieceLayout(row, pieces, pieces.right, "right", height, rightTexCoord, 1, 0, 1, "top", state)
	return true
end

local function setRowBackgroundTexture(row, state, mode)
	local pieces = row and row.backgroundPieces
	if not pieces then
		return false
	end
	mode = mode or "full"
	state = state or "normal"
	local elementKey = row.applicantID and applicantRowKey(row.applicantID, row.memberIdx) or nil
	local backgroundKey = state .. ":" .. mode
	local shouldFade = not row._gfSuppressBackgroundTransition
		and row.backgroundTransitionPieces
		and elementKey
		and row._gfApplicantBackgroundElementKey == elementKey
		and row._gfApplicantBackgroundKey
		and row._gfApplicantBackgroundKey ~= backgroundKey
	if shouldFade then
		applyRowBackgroundTexture(row, row.backgroundTransitionPieces, row._gfApplicantBackgroundState, row._gfApplicantBackgroundMode)
		playRowBackgroundPiecesFade(row.backgroundTransitionPieces, getRowBackgroundAlpha(row._gfApplicantBackgroundState))
	else
		stopRowBackgroundPiecesFade(row.backgroundTransitionPieces)
	end
	local applied = applyRowBackgroundTexture(row, pieces, state, mode)
	row._gfApplicantBackgroundElementKey = elementKey
	row._gfApplicantBackgroundKey = backgroundKey
	row._gfApplicantBackgroundState = state
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
	row._gfApplicantBackgroundState = nil
	row._gfApplicantBackgroundMode = nil
end

local function applyMemberRowVisual(row, memberData, backgroundMode, overrideState)
	if not row then
		return
	end
	local state = overrideState or getMemberRowVisualState(memberData)
	if not setRowBackgroundTexture(row, state, backgroundMode) and row.background then
		row.background:SetTexture(ROW_BACKGROUND_FALLBACK_TEXTURE)
		local color = GF.GetListBackgroundColor and GF.GetListBackgroundColor(state) or nil
		if type(color) == "table" then
			row.background:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
		else
			row.background:SetVertexColor(1, 1, 1, 1)
		end
		row.background:SetAlpha(getRowBackgroundAlpha(state))
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

local function setFontStringTextColor(fontString, color, fallback)
	if not fontString or not fontString.SetTextColor then
		return
	end
	color = normalizedColor(color, fallback or TOOLTIP_TEXT_COLOR)
	fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
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
	local kind = getMemberTooltipTypeKind(memberData)
	if not kind then
		return nil
	end
	local label = getMemberTypeLabelForKind(kind)
	if not label or label == "" then
		return nil
	end
	local texture = getTypeStatusIconTexture(kind)
	local color = TOOLTIP_TEXT_COLOR
	if kind == "blacklist" or kind == "leaver" then
		color = TOOLTIP_DANGER_COLOR
	elseif kind then
		color = (GF.GetSocialTypeTextColor and GF.GetSocialTypeTextColor(kind)) or TOOLTIP_SOCIAL_COLOR
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
	if not (memberData and memberData.factionGroup) then
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
	local factionIcon = getApplicantFactionIconMarkup(memberData)
	if factionIcon ~= "" then
		title = title .. " " .. factionIcon
	end
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
	local classColor = beginApplicantMemberTooltip(member, memberData, true)
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
	if GF.ApplicantRaidTooltip and GF.ApplicantRaidTooltip.Append then
		GF.ApplicantRaidTooltip.Append(GameTooltip, memberData)
	end

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
	if not (pvpInfo and type(pvpInfo.rating) == "number" and pvpInfo.rating >= 0) then
		return nil
	end
	local activityName = pvpInfo.activityName or "PvP"
	local tierName = getPvpTierName(pvpInfo)
	local ratingColor = GF.GetPvpRatingColor(pvpInfo.rating)
	local text = wrapColor(TOOLTIP_GREEN_COLOR, tooltipLocaleFormat("APPLICANT_TIP_PVP_ACTIVITY_PREFIX_FMT", "%s: ", activityName))
		.. wrapColor(ratingColor, pvpInfo.rating)
	if tierName and tierName ~= "" then
		text = text .. wrapColor(ratingColor, "/" .. tierName)
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
	if not beginApplicantMemberTooltip(member, memberData, true) then
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
	if GF.UI and GF.UI.LayoutSpecializationIcon then
		GF.UI.LayoutSpecializationIcon(row.specIcon, { size = getSpecIconSize() })
	end
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
	local memberData = row._layoutMemberData
	local name = getApplicantMenuName(row)
	local hasName = type(name) == "string" and name ~= ""
	local characterInfo = GF.ApplicantCharacterInfo
	local characterLinks = hasName and characterInfo and characterInfo.BuildLinks
		and characterInfo:BuildLinks(name) or nil
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
				GF.UI.ShowCharacterNameCopyDialog(name)
			end,
		},
		{
			text = L.APPLICANT_QUERY_CHARACTER or "查询角色信息",
			textColor = APPLICANT_QUERY_MENU_COLOR,
			disabled = not (characterLinks and characterInfo and characterInfo.Open),
			func = function()
				characterInfo:Open(name, characterLinks, memberData)
			end,
		},
		{
			text = WHISPER or "密语",
			disabled = not (hasName and characterInfo and characterInfo.Whisper),
			func = function()
				characterInfo:Whisper(name)
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
	f.background:SetTexture(ROW_BACKGROUND_FALLBACK_TEXTURE)
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
		self._gfDismissedSoftUnavailable = nil
		if GF.ApplicantsPanel
			and GF.ApplicantsPanel.DismissSoftUnavailableApplicantRow
			and GF.ApplicantsPanel:DismissSoftUnavailableApplicantRow(self) then
			self._gfDismissedSoftUnavailable = true
			return
		end
		if GF.ApplicantsPanel and GF.ApplicantsPanel.SetSelectedApplicantRow then
			GF.ApplicantsPanel:SetSelectedApplicantRow(self)
		end
	end)
	f:SetScript("OnMouseUp", function(self, button)
		if self._gfDismissedSoftUnavailable then
			self._gfDismissedSoftUnavailable = nil
			return
		end
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
	local specIcon, specRole, specClassFile = getSpecIconTexture(memberData)
	member._specIcon = specIcon
	member._specIconRole = specRole
	member._specIconClass = specClassFile
	if specIcon then
		if GF.UI and GF.UI.SetSpecializationIcon then
			GF.UI.SetSpecializationIcon(member.specIcon, specIcon, {
				classFile = specClassFile or memberData.class,
				role = memberData.assignedRole or memberData.role or specRole,
				size = getSpecIconSize(),
				disabled = memberData.grayed == true,
			})
		else
			member.specIcon:SetTexture(specIcon)
			member.specIcon:SetTexCoord(0, 1, 0, 1)
			member.specIcon:SetDesaturated(memberData.grayed == true)
			member.specIcon:SetAlpha(memberData.grayed and 0.5 or 1)
			member.specIcon:Show()
		end
		member.classText:SetText("")
		member.classText:Hide()
	elseif spec ~= "" then
		if GF.UI and GF.UI.ClearSpecializationIcon then
			GF.UI.ClearSpecializationIcon(member.specIcon)
		else
			member.specIcon:Hide()
		end
		member.classText:Show()
		GF.UI.SetEllipsisText(member.classText, spec, self:GetColWidth(member, "class"))
	else
		if GF.UI and GF.UI.ClearSpecializationIcon then
			GF.UI.ClearSpecializationIcon(member.specIcon)
		else
			member.specIcon:Hide()
		end
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
			if GF.UI and GF.UI.SetSpecializationIcon then
				local memberData = member._layoutMemberData or {}
				GF.UI.SetSpecializationIcon(member.specIcon, member._specIcon, {
					classFile = member._specIconClass or memberData.class,
					role = memberData.assignedRole or memberData.role or member._specIconRole,
					size = getSpecIconSize(),
					disabled = memberData.grayed == true,
				})
			else
				member.specIcon:SetTexture(member._specIcon)
				member.specIcon:Show()
			end
			member.classText:SetText("")
			member.classText:Hide()
		else
			if GF.UI and GF.UI.ClearSpecializationIcon then
				GF.UI.ClearSpecializationIcon(member.specIcon)
			else
				member.specIcon:Hide()
			end
			member.classText:Show()
			GF.UI.SetEllipsisText(member.classText, member._classText, self:GetColWidth(member, "class"))
		end
	else
		if member.specIcon then
			if GF.UI and GF.UI.ClearSpecializationIcon then
				GF.UI.ClearSpecializationIcon(member.specIcon)
			else
				member.specIcon:Hide()
			end
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
