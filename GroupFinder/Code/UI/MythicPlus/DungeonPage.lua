local _, GF = ...

GF.MythicPlusDungeonPage = GF.MythicPlusDungeonPage or {}
local DungeonPage = GF.MythicPlusDungeonPage
local UI = GF.MythicPlusUI

local TILE_WIDTH = 215
local TILE_HEIGHT = 173
local TILE_COLUMNS = 4
local TILE_BASE_ROWS = 2
local TILE_GAP_X = 14
local TILE_GAP_Y = 14
local GRID_PADDING_X = 24
local GRID_PADDING_Y = 10
local TILE_MAX_SCALE = 1.25
local TILE_BORDER_LEFT = -4
local TILE_BORDER_TOP = 5
local TILE_BORDER_RIGHT = 5
local TILE_BORDER_BOTTOM = -5
local IMAGE_LEFT = 2
local IMAGE_TOP = 2
local IMAGE_WIDTH = 211
local IMAGE_HEIGHT = 169
local EJ_LORE_IMAGE_TEX_COORDS = { 0.052734375, 0.703125, 0.091796875, 0.556640625 }

local TILE_UI = {
	topMaskTexture = UI.ART_ROOT .. "InfoTips.png",
	topMaskHeight = math.floor((IMAGE_WIDTH * 88 / 659) + 0.5),
	keystoneIconTexture = "Interface\\Icons\\INV_Relics_Hourglass_02",
	keystoneIconSize = 14,
	keystoneIconInset = 2,
	keystoneIconBorderTexture = "Interface\\Buttons\\UI-Quickslot2",
	keystoneIconOuterBorderPadding = 9,
	keystoneIconGap = 4,
	keySummaryHeight = 18,
	keySummaryMaxWidth = IMAGE_WIDTH - 24,
	keySummaryOffsetY = 3,
	bestBadgeTexture = UI.ART_ROOT .. "Chakram.png",
	bestBadgeWidth = 64,
	bestBadgeHeight = 64,
	bestBadgeOffsetX = 0,
	bestBadgeOffsetY = 0,
	bestTextOffsetX = 0,
	bestTextOffsetY = 0,
	bestTextWidth = 64,
	bestTextHeight = 64,
	bestFontSize = 18,
	portalEffectTexture = UI.ART_ROOT .. "DungeonPortalEffect.png",
	portalEffectWidth = 86,
	portalEffectHeight = 92,
	portalEffectOffsetX = 0,
	portalEffectOffsetY = 0,
	portalEffectFrameColumns = 7,
	portalEffectFrameRows = 4,
	portalEffectFrameCount = 28,
	portalEffectFrameSeconds = 0.04,
	portalBackdropAlpha = 0.58,
	portalEffectFadeInSeconds = 0.18,
	portalEffectFadeOutSeconds = 0.14,
	portalBackdropFadeInSeconds = 0.16,
	portalBackdropFadeOutSeconds = 0.14,
	bestLevelFadeInSeconds = 0.16,
	bestLevelFadeOutSeconds = 0.12,
	nameBackgroundOffsetX = 1,
	nameBackgroundOffsetY = 2,
	nameBackgroundExtraWidth = 2,
	nameBackgroundFallbackWidth = TILE_WIDTH - 18,
	nameBackgroundFallbackHeight = 40,
	teleportBadgeRight = -12,
	teleportBadgeOffsetY = 0,
}

local TILE_NAME_TEXT_WIDTH = 200
local TILE_NAME_TEXT_HEIGHT = 32
local TILE_NAME_FONT_SIZE = 14
local KEY_COLOR_IRON = "ffffd100"
local KEY_COLOR_MYTHIC = "ff1eff00"

local function createText(parent, template)
	local text = GF.UI.CreateFontString(parent, "OVERLAY", template or "GameFontHighlight")
	text:SetJustifyV("MIDDLE")
	return text
end

local function applyFont(fontString, size, flags)
	if not (fontString and fontString.SetFont) then
		return
	end
	local fontPath = STANDARD_TEXT_FONT
	if type(fontPath) ~= "string" or fontPath == "" then
		fontPath = _G.GameFontNormal and _G.GameFontNormal:GetFont() or "Fonts\\FRIZQT__.TTF"
	end
	fontString:SetFont(fontPath, size, flags or "")
end

local function formatDuration(milliseconds)
	local totalSeconds = math.floor((tonumber(milliseconds) or 0) / 1000)
	if totalSeconds <= 0 then
		return "--"
	end
	return string.format("%d : %02d", math.floor(totalSeconds / 60), totalSeconds % 60)
end

local function createAlphaAnimationGroup(region, fromAlpha, toAlpha, duration, smoothing)
	if not (region and region.CreateAnimationGroup) then
		return nil
	end
	local group = region:CreateAnimationGroup()
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetFromAlpha(fromAlpha)
	alpha:SetToAlpha(toAlpha)
	alpha:SetDuration(duration or 0.15)
	if smoothing and alpha.SetSmoothing then
		alpha:SetSmoothing(smoothing)
	end
	return group
end

local function stopAnimationGroup(group)
	if group and group.Stop then
		group:Stop()
	end
end

local function getBestRuns()
	local runs = {}
	local rating = GF.MythicPlusRatingCache and GF.MythicPlusRatingCache:GetCurrent()
	for _, run in ipairs(rating and rating.runs or {}) do
		if run.mapID then
			runs[tonumber(run.mapID)] = run
		end
	end
	return runs
end

local function getKeyHolders()
	local holders = {}
	local characters = {}
	local seen = {}
	local function append(entries)
		for _, character in ipairs(entries or {}) do
			local identity = string.lower(tostring(
				character.fullName or character.key or character.name or ""))
			if not seen[identity] then
				seen[identity] = true
				characters[#characters + 1] = character
			end
		end
	end
	append(GF.MythicPlusRosterCache and GF.MythicPlusRosterCache:GetMembers() or {})
	if GF.MythicPlusCarpoolView then
		if GF.MythicPlusCarpoolView.GetCharacters then
			append(GF.MythicPlusCarpoolView:GetCharacters())
		end
	elseif GF.MythicPlusCharacterStore then
		append(GF.MythicPlusCharacterStore:GetCarpoolCharacters())
	end
	for _, character in ipairs(characters) do
		local challengeModeID = tonumber(character.challengeModeID)
		local level = tonumber(character.keyLevel)
		if challengeModeID and level and level > 0 then
			holders[challengeModeID] = holders[challengeModeID] or {}
			holders[challengeModeID][#holders[challengeModeID] + 1] = character
		end
	end
	for _, entries in pairs(holders) do
		table.sort(entries, function(left, right)
			local leftLevel = tonumber(left.keyLevel) or 0
			local rightLevel = tonumber(right.keyLevel) or 0
			if leftLevel ~= rightLevel then
				return leftLevel > rightLevel
			end
			return tostring(left.fullName or left.name or "")
				< tostring(right.fullName or right.name or "")
		end)
	end
	return holders
end

local function colorizeKeyLevel(text, track)
	local color = track == "iron" and KEY_COLOR_IRON or KEY_COLOR_MYTHIC
	return string.format("|c%s%s|r", color, text or "")
end

local function colorizeEmptyKeyText(text)
	return string.format("|c%s%s|r", KEY_COLOR_IRON, text or "")
end

local function getKeyTrackLabel(track)
	if track == "mythic" then
		return (GF.L and GF.L.MPLUS_KEY_TRACK_MYTHIC) or "史诗"
	end
	if track == "iron" then
		return (GF.L and GF.L.MPLUS_KEY_TRACK_IRON) or "坚韧"
	end
	return nil
end

local function formatKeyHolderDetail(character)
	local levelText = colorizeKeyLevel(
		tostring(character and character.keyLevel or "-"),
		character and character.keyUpgradeTrack)
	local trackLabel = getKeyTrackLabel(
		character and character.keyUpgradeTrack)
	if trackLabel then
		return string.format("%s  %s", levelText, trackLabel)
	end
	return levelText
end

local function formatKeyHolders(entries)
	if type(entries) ~= "table" or #entries == 0 then
		return colorizeEmptyKeyText(
			(GF.L and GF.L.MPLUS_NO_KEY_AVAILABLE) or "暂无钥匙")
	end

	local levels = {}
	for _, character in ipairs(entries) do
		local level = tonumber(character.keyLevel)
		if level and level > 0 then
			levels[#levels + 1] = {
				level = level,
				track = character.keyUpgradeTrack,
			}
		end
	end
	table.sort(levels, function(left, right)
		return left.level > right.level
	end)

	if #levels == 0 then
		return colorizeEmptyKeyText(
			(GF.L and GF.L.MPLUS_NO_KEY_AVAILABLE) or "暂无钥匙")
	end

	local parts = {}
	local visibleEntries = math.min(#levels, 6)
	for index = 1, visibleEntries do
		local entry = levels[index]
		parts[#parts + 1] = colorizeKeyLevel(tostring(entry.level), entry.track)
	end
	if #levels > visibleEntries then
		parts[#parts + 1] = string.format("|cffcccccc%d|r", #levels - visibleEntries)
	end
	return table.concat(parts, " / ")
end

local function applyImageTexCoords(image, texCoords)
	if not image then
		return
	end
	texCoords = type(texCoords) == "table" and texCoords or { 0, 1, 0, 1 }
	if #texCoords == 4 then
		image:SetTexCoord(texCoords[1], texCoords[2], texCoords[3], texCoords[4])
	else
		image:SetTexCoord(0, 1, 0, 1)
	end
end

local function updateKeySummary(tile)
	if not (tile and tile.KeySummary and tile.KeyIcon and tile.KeyText) then
		return
	end
	local text = tile.KeyText:GetText()
	if type(text) ~= "string" or text == "" then
		tile.KeySummary:Hide()
		tile.KeyIcon:Hide()
		tile.KeyIconOuterBorder:Hide()
		tile.KeyText:Hide()
		return
	end

	local scale = tile.LayoutScale or 1
	local iconSize = math.max(1,
		math.floor((TILE_UI.keystoneIconSize - TILE_UI.keystoneIconInset) * scale + 0.5))
	local outerSize = math.max(iconSize,
		math.floor((TILE_UI.keystoneIconSize + TILE_UI.keystoneIconOuterBorderPadding) * scale + 0.5))
	local iconGap = math.max(0, math.floor(TILE_UI.keystoneIconGap * scale + 0.5))
	local summaryHeight = math.max(iconSize, math.floor(TILE_UI.keySummaryHeight * scale + 0.5))
	local maxSummaryWidth = math.max(1, math.floor(TILE_UI.keySummaryMaxWidth * scale + 0.5))
	local maxTextWidth = math.max(1, maxSummaryWidth - ((outerSize + iconGap) * 2))

	tile.KeyText:SetWidth(maxTextWidth)
	local measuredWidth = tile.KeyText:GetStringWidth() or 0
	if measuredWidth <= 0 then
		measuredWidth = maxTextWidth
	end
	local textWidth = math.max(1, math.min(maxTextWidth, math.ceil(measuredWidth)))

	tile.KeySummary:ClearAllPoints()
	tile.KeySummary:SetPoint("CENTER", tile.TopMask or tile, "CENTER", 0, TILE_UI.keySummaryOffsetY * scale)
	tile.KeySummary:SetSize(maxSummaryWidth, summaryHeight)

	tile.KeyText:ClearAllPoints()
	tile.KeyText:SetPoint("CENTER", tile.KeySummary, "CENTER", 0, 0)
	tile.KeyText:SetSize(textWidth, summaryHeight)
	tile.KeyText:SetJustifyH("CENTER")
	tile.KeyText:SetJustifyV("MIDDLE")

	tile.KeyIcon:ClearAllPoints()
	tile.KeyIcon:SetPoint("RIGHT", tile.KeyText, "LEFT", -iconGap, 0)
	tile.KeyIcon:SetSize(iconSize, iconSize)

	tile.KeyIconOuterBorder:ClearAllPoints()
	tile.KeyIconOuterBorder:SetPoint("CENTER", tile.KeyIcon, "CENTER", 0, 0)
	tile.KeyIconOuterBorder:SetSize(outerSize, outerSize)

	tile.KeySummary:Show()
	tile.KeyIconOuterBorder:Show()
	tile.KeyIcon:Show()
	tile.KeyText:Show()
end

local function setBestLevelAlpha(tile, visible, immediate)
	local frame = tile and tile.BestLevelFrame
	if not frame then
		return
	end
	stopAnimationGroup(tile.BestLevelFadeIn)
	stopAnimationGroup(tile.BestLevelFadeOut)
	if not tile.BestLevelAvailable then
		frame:SetAlpha(0)
	elseif immediate then
		frame:SetAlpha(visible and 1 or 0)
	elseif visible then
		frame:SetAlpha(0)
		if tile.BestLevelFadeIn then
			tile.BestLevelFadeIn:Play()
		else
			frame:SetAlpha(1)
		end
	else
		frame:SetAlpha(1)
		if tile.BestLevelFadeOut then
			tile.BestLevelFadeOut:Play()
		else
			frame:SetAlpha(0)
		end
	end
end

local function setPortalBackdropAlpha(tile, visible, immediate)
	local backdrop = tile and tile.PortalEffectBackdrop
	if not backdrop then
		return
	end
	stopAnimationGroup(tile.PortalBackdropFadeIn)
	stopAnimationGroup(tile.PortalBackdropFadeOut)
	if immediate then
		backdrop:SetAlpha(visible and TILE_UI.portalBackdropAlpha or 0)
	elseif visible then
		backdrop:SetAlpha(0)
		if tile.PortalBackdropFadeIn then
			tile.PortalBackdropFadeIn:Play()
		else
			backdrop:SetAlpha(TILE_UI.portalBackdropAlpha)
		end
	else
		backdrop:SetAlpha(TILE_UI.portalBackdropAlpha)
		if tile.PortalBackdropFadeOut then
			tile.PortalBackdropFadeOut:Play()
		else
			backdrop:SetAlpha(0)
		end
	end
end

local function setPortalSpriteFrame(tile, frameIndex)
	local texture = tile and tile.PortalEffectTexture
	if not texture then
		return
	end
	local index = math.max(1, math.min(TILE_UI.portalEffectFrameCount, tonumber(frameIndex) or 1))
	local zeroIndex = index - 1
	local column = zeroIndex % TILE_UI.portalEffectFrameColumns
	local row = math.floor(zeroIndex / TILE_UI.portalEffectFrameColumns)
	texture:SetTexCoord(
		column / TILE_UI.portalEffectFrameColumns,
		(column + 1) / TILE_UI.portalEffectFrameColumns,
		row / TILE_UI.portalEffectFrameRows,
		(row + 1) / TILE_UI.portalEffectFrameRows)
	tile.PortalEffectSpriteFrame = index
end

local function resetPortalSprite(tile)
	tile.PortalEffectSpriteElapsed = 0
	setPortalSpriteFrame(tile, 1)
end

local function updatePortalSprite(tile, elapsed)
	if not (tile and tile.PortalEffectActive and tile.PortalEffectTexture) then
		return
	end
	local spriteElapsed = (tile.PortalEffectSpriteElapsed or 0) + (elapsed or 0)
	if spriteElapsed < TILE_UI.portalEffectFrameSeconds then
		tile.PortalEffectSpriteElapsed = spriteElapsed
		return
	end
	local steps = math.floor(spriteElapsed / TILE_UI.portalEffectFrameSeconds)
	tile.PortalEffectSpriteElapsed = spriteElapsed - (steps * TILE_UI.portalEffectFrameSeconds)
	setPortalSpriteFrame(tile,
		(((tile.PortalEffectSpriteFrame or 1) - 1 + steps) % TILE_UI.portalEffectFrameCount) + 1)
end

local function setPortalEffectAlpha(tile, visible, immediate)
	local frame = tile and tile.PortalEffectFrame
	if not frame then
		return
	end
	stopAnimationGroup(tile.PortalEffectFadeIn)
	stopAnimationGroup(tile.PortalEffectFadeOut)
	resetPortalSprite(tile)
	if immediate then
		frame:SetAlpha(visible and 1 or 0)
	elseif visible then
		frame:SetAlpha(0)
		if tile.PortalEffectFadeIn then
			tile.PortalEffectFadeIn:Play()
		else
			frame:SetAlpha(1)
		end
	else
		frame:SetAlpha(1)
		if tile.PortalEffectFadeOut then
			tile.PortalEffectFadeOut:Play()
		else
			frame:SetAlpha(0)
		end
	end
end

local function setPortalHover(tile, active, immediate)
	if not tile then
		return
	end
	local shouldShow = active == true and tile.TeleportStatus == "ready"
		and tile.TeleportSecureReady ~= false
		and not UI.IsTeleportCombatLocked()
	if tile.PortalEffectActive == shouldShow and not immediate then
		return
	end
	tile.PortalEffectActive = shouldShow
	setPortalBackdropAlpha(tile, shouldShow, immediate)
	setBestLevelAlpha(tile, not shouldShow, immediate)
	setPortalEffectAlpha(tile, shouldShow, immediate)
end

local function updateSelectedState(tile, selected)
	if not tile then
		return
	end
	local wasSelected = tile.IsSelected
	tile.IsSelected = selected == true
	if tile.IsSelected then
		tile.SelectedBorder:Show()
		if not wasSelected and tile.SelectedBorderFadeIn then
			tile.SelectedBorderFadeIn:Stop()
			tile.SelectedBorder:SetAlpha(0)
			tile.SelectedBorderFadeIn:Play()
		else
			tile.SelectedBorder:SetAlpha(1)
		end
	else
		if tile.SelectedBorderFadeIn then
			tile.SelectedBorderFadeIn:Stop()
		end
		tile.SelectedBorder:SetAlpha(0)
		tile.SelectedBorder:Hide()
	end
	tile.HighlightTexture:SetAlpha((not tile.DungeonAvailable or tile.IsSelected) and 0 or 1)
	tile:SetHighlightTexture(tile.HighlightTexture)
end

local function positionTeleportBadge(tile, pressed)
	local scale = tile.LayoutScale or 1
	pressed = pressed == true and tile._gfTeleportVisualState == "ready"
	UI.ApplyTeleportIconVisual(
		tile.TeleportBadge,
		tile._gfTeleportVisualState,
		{
			profile = "dungeon",
			pressed = pressed,
			scale = scale,
			roundSize = true,
			anchor = tile.NameBackground or tile,
			point = "RIGHT",
			relativePoint = "RIGHT",
			anchorOffsetX = TILE_UI.teleportBadgeRight,
			anchorOffsetY = TILE_UI.teleportBadgeOffsetY,
		})
end

local function updateTeleportBadge(tile)
	local badge = tile and tile.TeleportBadge
	if not badge then
		return
	end
	local status = tile.TeleportStatus
	if status == "ready"
		and (tile.TeleportSecureReady ~= false or UI.IsTeleportCombatLocked())
	then
		tile._gfTeleportVisualState = "ready"
		positionTeleportBadge(tile, tile.TeleportBadgePressed)
		badge:Show()
	elseif status == "cooldown" then
		tile._gfTeleportVisualState = "cooldown"
		positionTeleportBadge(tile, false)
		badge:Show()
	elseif status == "not_learned" then
		tile._gfTeleportVisualState = "not_learned"
		positionTeleportBadge(tile, false)
		badge:Show()
	elseif tile.DungeonAvailable == false then
		tile._gfTeleportVisualState = "unavailable"
		positionTeleportBadge(tile, false)
		badge:Show()
	else
		tile._gfTeleportVisualState = "fallback"
		positionTeleportBadge(tile, false)
		badge:Hide()
	end
end

local function setTeleportBadgePressed(tile, pressed)
	if not tile then
		return
	end
	if pressed and (tile.TeleportStatus ~= "ready"
		or tile.TeleportSecureReady == false
		or UI.IsTeleportCombatLocked())
	then
		pressed = false
	end
	tile.TeleportBadgePressed = pressed == true
	positionTeleportBadge(tile, tile.TeleportBadgePressed)
end

local function updateBestLevel(tile, level, timed)
	local bestLevel = tonumber(level) or 0
	if bestLevel <= 0 then
		tile.BestLevelAvailable = false
		stopAnimationGroup(tile.BestLevelFadeIn)
		stopAnimationGroup(tile.BestLevelFadeOut)
		tile.BestLevelFrame:SetAlpha(0)
		tile.BestBadge:Hide()
		tile.BestText:Hide()
		return
	end

	tile.BestLevelAvailable = true
	local scale = tile.LayoutScale or 1
	tile.BestLevelFrame:ClearAllPoints()
	tile.BestLevelFrame:SetPoint("CENTER", tile, "CENTER",
		TILE_UI.bestBadgeOffsetX * scale, TILE_UI.bestBadgeOffsetY * scale)
	tile.BestLevelFrame:SetSize(
		math.max(1, math.floor(TILE_UI.bestBadgeWidth * scale + 0.5)),
		math.max(1, math.floor(TILE_UI.bestBadgeHeight * scale + 0.5)))
	tile.BestBadge:ClearAllPoints()
	tile.BestBadge:SetAllPoints(tile.BestLevelFrame)
	tile.BestText:ClearAllPoints()
	tile.BestText:SetPoint("CENTER", tile.BestLevelFrame, "CENTER",
		TILE_UI.bestTextOffsetX * scale, TILE_UI.bestTextOffsetY * scale)
	tile.BestText:SetSize(
		math.max(1, math.floor(TILE_UI.bestTextWidth * scale + 0.5)),
		math.max(1, math.floor(TILE_UI.bestTextHeight * scale + 0.5)))
	tile.BestText:SetText(tostring(bestLevel))
	tile.BestText:SetTextColor(1, timed == false and 0.22 or 1, timed == false and 0.18 or 1)
	applyFont(tile.BestText, math.max(1, math.floor(TILE_UI.bestFontSize * scale + 0.5)), "OUTLINE")
	tile.BestBadge:Show()
	tile.BestText:Show()
	setBestLevelAlpha(tile, not tile.PortalEffectActive, true)
end

local function createTile(parent)
	local tile = CreateFrame("Button", nil, parent, "InsecureActionButtonTemplate")
	tile:SetSize(TILE_WIDTH, TILE_HEIGHT)
	tile:RegisterForClicks("AnyUp", "AnyDown")
	tile:Hide()

	local image = tile:CreateTexture(nil, "BACKGROUND")
	image:SetPoint("TOPLEFT", tile, "TOPLEFT", IMAGE_LEFT, -IMAGE_TOP)
	image:SetSize(IMAGE_WIDTH, IMAGE_HEIGHT)
	image:SetTexture(GF.WHITE_TEXTURE)
	image:SetVertexColor(0.08, 0.08, 0.08, 0.95)

	local portalBackdrop = tile:CreateTexture(nil, "ARTWORK", nil, 0)
	portalBackdrop:SetPoint("TOPLEFT", image, "TOPLEFT")
	portalBackdrop:SetPoint("BOTTOMRIGHT", image, "BOTTOMRIGHT")
	portalBackdrop:SetColorTexture(0, 0, 0, 1)
	portalBackdrop:SetAlpha(0)

	local portalBackdropFadeIn = createAlphaAnimationGroup(portalBackdrop, 0,
		TILE_UI.portalBackdropAlpha, TILE_UI.portalBackdropFadeInSeconds, "OUT")
	if portalBackdropFadeIn then
		portalBackdropFadeIn:SetScript("OnFinished", function()
			portalBackdrop:SetAlpha(TILE_UI.portalBackdropAlpha)
		end)
	end
	local portalBackdropFadeOut = createAlphaAnimationGroup(portalBackdrop,
		TILE_UI.portalBackdropAlpha, 0, TILE_UI.portalBackdropFadeOutSeconds, "IN")
	if portalBackdropFadeOut then
		portalBackdropFadeOut:SetScript("OnFinished", function()
			portalBackdrop:SetAlpha(0)
		end)
	end

	local topMask = tile:CreateTexture(nil, "ARTWORK", nil, 1)
	topMask:SetTexture(TILE_UI.topMaskTexture)
	topMask:SetPoint("TOPLEFT", image, "TOPLEFT")
	topMask:SetPoint("TOPRIGHT", image, "TOPRIGHT")
	topMask:SetHeight(TILE_UI.topMaskHeight)

	local nameBackground = tile:CreateTexture(nil, "ARTWORK", nil, 1)
	if not GF.UI.TrySetAtlas(nameBackground, "campcollection-bg-text", true) then
		nameBackground:SetTexture(GF.WHITE_TEXTURE)
		nameBackground:SetVertexColor(0, 0, 0, 0.72)
	end
	nameBackground.BaseWidth = nameBackground:GetWidth() or TILE_UI.nameBackgroundFallbackWidth
	nameBackground.BaseHeight = nameBackground:GetHeight() or TILE_UI.nameBackgroundFallbackHeight
	if nameBackground.BaseWidth <= 0 then
		nameBackground.BaseWidth = TILE_UI.nameBackgroundFallbackWidth
	end
	if nameBackground.BaseHeight <= 0 then
		nameBackground.BaseHeight = TILE_UI.nameBackgroundFallbackHeight
	end
	nameBackground:SetSize(nameBackground.BaseWidth + TILE_UI.nameBackgroundExtraWidth, nameBackground.BaseHeight)
	nameBackground:SetPoint("BOTTOM", tile, "BOTTOM",
		TILE_UI.nameBackgroundOffsetX, TILE_UI.nameBackgroundOffsetY)

	local border = tile:CreateTexture(nil, "ARTWORK", nil, 2)
	GF.UI.TrySetAtlas(border, "campcollection-frame", false)
	border:SetPoint("TOPLEFT", tile, "TOPLEFT", TILE_BORDER_LEFT, TILE_BORDER_TOP)
	border:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", TILE_BORDER_RIGHT, TILE_BORDER_BOTTOM)

	local highlight = tile:CreateTexture(nil, "HIGHLIGHT")
	GF.UI.TrySetAtlas(highlight, "campcollection-frame-hover", false)
	highlight:SetPoint("TOPLEFT", tile, "TOPLEFT", TILE_BORDER_LEFT, TILE_BORDER_TOP)
	highlight:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", TILE_BORDER_RIGHT, TILE_BORDER_BOTTOM)
	highlight:SetBlendMode("ADD")
	tile:SetHighlightTexture(highlight)

	local selectedBorder = tile:CreateTexture(nil, "ARTWORK", nil, 3)
	GF.UI.TrySetAtlas(selectedBorder, "campcollection-frame-hover", false)
	selectedBorder:SetPoint("TOPLEFT", tile, "TOPLEFT", TILE_BORDER_LEFT, TILE_BORDER_TOP)
	selectedBorder:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", TILE_BORDER_RIGHT, TILE_BORDER_BOTTOM)
	selectedBorder:SetBlendMode("ADD")
	selectedBorder:SetVertexColor(1, 0.72, 0.05, 1)
	selectedBorder:SetAlpha(0)
	selectedBorder:Hide()
	local selectedBorderFadeIn = selectedBorder:CreateAnimationGroup()
	local selectedBorderFade = selectedBorderFadeIn:CreateAnimation("Alpha")
	selectedBorderFade:SetFromAlpha(0)
	selectedBorderFade:SetToAlpha(1)
	selectedBorderFade:SetDuration(0.18)
	selectedBorderFade:SetSmoothing("OUT")
	selectedBorderFadeIn:SetScript("OnFinished", function()
		selectedBorder:SetAlpha(1)
	end)

	local title = createText(tile, "GameFontHighlight")
	title._gfFontSizeOverride = TILE_NAME_FONT_SIZE
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(title, "GameFontHighlight")
	else
		applyFont(title, TILE_NAME_FONT_SIZE, "")
	end
	title:SetPoint("CENTER", nameBackground, "CENTER")
	title:SetSize(TILE_NAME_TEXT_WIDTH, TILE_NAME_TEXT_HEIGHT)
	title:SetJustifyH("CENTER")
	title:SetTextColor(1, 1, 1)
	title:SetWordWrap(true)
	if title.SetSpacing then
		title:SetSpacing(2)
	end

	local bestLevelFrame = CreateFrame("Frame", nil, tile)
	bestLevelFrame:SetFrameLevel(tile:GetFrameLevel() + 6)
	bestLevelFrame:SetPoint("CENTER")
	bestLevelFrame:SetSize(TILE_UI.bestBadgeWidth, TILE_UI.bestBadgeHeight)
	bestLevelFrame:SetAlpha(0)
	local bestLevelFadeIn = createAlphaAnimationGroup(bestLevelFrame, 0, 1,
		TILE_UI.bestLevelFadeInSeconds, "OUT")
	if bestLevelFadeIn then
		bestLevelFadeIn:SetScript("OnFinished", function()
			bestLevelFrame:SetAlpha(1)
		end)
	end
	local bestLevelFadeOut = createAlphaAnimationGroup(bestLevelFrame, 1, 0,
		TILE_UI.bestLevelFadeOutSeconds, "IN")
	if bestLevelFadeOut then
		bestLevelFadeOut:SetScript("OnFinished", function()
			bestLevelFrame:SetAlpha(0)
		end)
	end
	local bestBadge = bestLevelFrame:CreateTexture(nil, "OVERLAY", nil, 0)
	bestBadge:SetTexture(TILE_UI.bestBadgeTexture)
	bestBadge:SetAllPoints()
	bestBadge:Hide()
	local bestText = createText(bestLevelFrame, "GameFontHighlightLarge")
	bestText:SetPoint("CENTER")
	bestText:SetSize(TILE_UI.bestTextWidth, TILE_UI.bestTextHeight)
	bestText:SetJustifyH("CENTER")
	bestText:SetTextColor(1, 1, 1)
	applyFont(bestText, TILE_UI.bestFontSize, "OUTLINE")
	bestText:Hide()

	local portalEffectFrame = CreateFrame("Frame", nil, tile)
	portalEffectFrame:SetFrameLevel(tile:GetFrameLevel() + 7)
	portalEffectFrame:SetPoint("CENTER", tile, "CENTER",
		TILE_UI.portalEffectOffsetX, TILE_UI.portalEffectOffsetY)
	portalEffectFrame:SetSize(TILE_UI.portalEffectWidth, TILE_UI.portalEffectHeight)
	portalEffectFrame:SetAlpha(0)
	local portalEffectTexture = portalEffectFrame:CreateTexture(nil, "OVERLAY")
	portalEffectTexture:SetAllPoints()
	portalEffectTexture:SetTexture(TILE_UI.portalEffectTexture, false)
	portalEffectTexture:SetTexCoord(0, 1 / TILE_UI.portalEffectFrameColumns,
		0, 1 / TILE_UI.portalEffectFrameRows)
	local portalEffectFadeIn = createAlphaAnimationGroup(portalEffectFrame, 0, 1,
		TILE_UI.portalEffectFadeInSeconds, "OUT")
	if portalEffectFadeIn then
		portalEffectFadeIn:SetScript("OnFinished", function()
			portalEffectFrame:SetAlpha(1)
		end)
	end
	local portalEffectFadeOut = createAlphaAnimationGroup(portalEffectFrame, 1, 0,
		TILE_UI.portalEffectFadeOutSeconds, "IN")
	if portalEffectFadeOut then
		portalEffectFadeOut:SetScript("OnFinished", function()
			portalEffectFrame:SetAlpha(0)
		end)
	end

	local teleportBadge = tile:CreateTexture(nil, "OVERLAY", nil, 2)
	if not GF.UI.TrySetAtlas(
		teleportBadge,
		GF.MYTHIC_PLUS_TELEPORT_ICON_ATLAS,
		false)
	then
		teleportBadge:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	end
	teleportBadge:Hide()

	local keySummary = CreateFrame("Frame", nil, tile)
	keySummary:SetPoint("CENTER", topMask, "CENTER", 0, TILE_UI.keySummaryOffsetY)
	keySummary:SetSize(TILE_UI.keySummaryMaxWidth, TILE_UI.keySummaryHeight)
	keySummary:Hide()
	local keyIconOuterBorder = keySummary:CreateTexture(nil, "OVERLAY", nil, 2)
	keyIconOuterBorder:SetTexture(TILE_UI.keystoneIconBorderTexture)
	keyIconOuterBorder:SetVertexColor(1, 0.82, 0, 1)
	keyIconOuterBorder:SetSize(
		TILE_UI.keystoneIconSize + TILE_UI.keystoneIconOuterBorderPadding,
		TILE_UI.keystoneIconSize + TILE_UI.keystoneIconOuterBorderPadding)
	keyIconOuterBorder:Hide()
	local keyIcon = keySummary:CreateTexture(nil, "OVERLAY", nil, 1)
	keyIcon:SetTexture(TILE_UI.keystoneIconTexture)
	keyIcon:SetSize(
		TILE_UI.keystoneIconSize - TILE_UI.keystoneIconInset,
		TILE_UI.keystoneIconSize - TILE_UI.keystoneIconInset)
	keyIcon:Hide()
	local keyText = createText(keySummary, "GameFontHighlightSmall")
	keyText:SetPoint("CENTER")
	keyText:SetSize(
		TILE_UI.keySummaryMaxWidth - ((TILE_UI.keystoneIconSize + TILE_UI.keystoneIconGap) * 2),
		TILE_UI.keySummaryHeight)
	keyText:SetJustifyH("CENTER")
	keyText:SetTextColor(1, 1, 1)
	keyText:SetWordWrap(false)
	applyFont(keyText, 11, "OUTLINE")
	keyText:Hide()

	tile.Image = image
	tile.PortalEffectBackdrop = portalBackdrop
	tile.PortalBackdropFadeIn = portalBackdropFadeIn
	tile.PortalBackdropFadeOut = portalBackdropFadeOut
	tile.TopMask = topMask
	tile.NameBackground = nameBackground
	tile.Border = border
	tile.HighlightTexture = highlight
	tile.SelectedBorder = selectedBorder
	tile.SelectedBorderFadeIn = selectedBorderFadeIn
	tile.Title = title
	tile.BestLevelFrame = bestLevelFrame
	tile.BestLevelFadeIn = bestLevelFadeIn
	tile.BestLevelFadeOut = bestLevelFadeOut
	tile.BestBadge = bestBadge
	tile.BestText = bestText
	tile.PortalEffectFrame = portalEffectFrame
	tile.PortalEffectTexture = portalEffectTexture
	tile.PortalEffectFadeIn = portalEffectFadeIn
	tile.PortalEffectFadeOut = portalEffectFadeOut
	tile.TeleportBadge = teleportBadge
	tile.KeySummary = keySummary
	tile.KeyIconOuterBorder = keyIconOuterBorder
	tile.KeyIcon = keyIcon
	tile.KeyText = keyText
	tile.LayoutScale = 1

	tile:SetScript("OnEnter", function(frame)
		local data = frame.Data
		if not data then
			return
		end
		setPortalHover(frame, true)
			GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(data.name or "-", 1, 0.82, 0)
			if data.bestRun then
				local roundedScore = math.floor((tonumber(data.bestRun.score) or 0) + 0.5)
				GameTooltip:AddLine(string.format("|cffffd100%s|r|c%s%d|r|cffffd100%s|r",
					(GF.L and GF.L.MPLUS_SCORE_LABEL) or "评分：",
					UI.ColorToARGBHex(data.bestRun.scoreColor),
					roundedScore,
					(GF.L and GF.L.MPLUS_SCORE_SUFFIX) or " 分"), 1, 1, 1)
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(string.format("|cffffd100%s|r|cffffffff%s|r",
					(GF.L and GF.L.MPLUS_BEST_RESULT_LABEL) or "最佳成绩：",
					formatDuration(data.bestRun.durationMS)), 1, 1, 1)
				GameTooltip:AddLine(" ")
			else
				GameTooltip:AddLine((GF.L and GF.L.MPLUS_NO_COMPLETION_RECORD)
					or "暂无通关记录", 0.58, 0.58, 0.58, true)
				GameTooltip:AddLine(string.format("|cffffd100%s|r|cffffffff--|r",
					(GF.L and GF.L.MPLUS_SCORE_LABEL) or "评分："), 1, 1, 1)
				GameTooltip:AddLine(string.format("|cffffd100%s|r|cffffffff--|r",
					(GF.L and GF.L.MPLUS_BEST_RESULT_LABEL) or "最佳成绩："), 1, 1, 1)
				GameTooltip:AddLine(" ")
			end
			if GF.MythicPlusTeleportService then
				GF.MythicPlusTeleportService:AddTooltipLines(GameTooltip, data, {
					includeDestinationTitle = false,
					secureReady = frame.gfTeleportSecureReady == true
						and frame.gfTeleportSecurePending ~= true,
				})
			end
		if #(data.keyHolders or {}) == 0 then
			GameTooltip:AddLine((GF.L and GF.L.MPLUS_GROUP_HAS_NO_KEYS)
				or "队伍中没有钥石", 0.85, 0.85, 0.85, true)
		else
			for _, character in ipairs(data.keyHolders) do
				local r, g, b = UI.GetClassColor(
					character.classFile or character.class,
					1, 1, 1)
				GameTooltip:AddDoubleLine(
					character.fullName or character.name or "-",
					formatKeyHolderDetail(character),
					r, g, b, 1, 1, 1)
			end
		end
		GameTooltip:Show()
	end)
	tile:SetScript("OnLeave", function(frame)
		setPortalHover(frame, false)
		setTeleportBadgePressed(frame, false)
		GameTooltip:Hide()
	end)
	tile:SetScript("OnMouseDown", function(frame, mouseButton)
		if mouseButton == "LeftButton" then
			setTeleportBadgePressed(frame, true)
		end
	end)
	tile:SetScript("OnMouseUp", function(frame, mouseButton)
		if mouseButton == "LeftButton" then
			setTeleportBadgePressed(frame, false)
		end
	end)
	tile:SetScript("OnUpdate", updatePortalSprite)
	UI.InstallTeleportCombatFeedback(tile, function(frame)
		frame.TeleportSecureReady = frame.gfTeleportSecureReady == true
			and frame.gfTeleportSecurePending ~= true
		setTeleportBadgePressed(frame, false)
		setPortalHover(frame, frame.IsMouseOver and frame:IsMouseOver(), true)
	end)
	return tile
end

local function applyTileLayout(tile, width, height, scale)
	tile:SetSize(width, height)
	tile.LayoutScale = scale
	tile.Image:ClearAllPoints()
	tile.Image:SetPoint("TOPLEFT", tile, "TOPLEFT", IMAGE_LEFT * scale, -IMAGE_TOP * scale)
	tile.Image:SetSize(
		math.max(1, math.floor(IMAGE_WIDTH * scale + 0.5)),
		math.max(1, math.floor(IMAGE_HEIGHT * scale + 0.5)))
	tile.PortalEffectBackdrop:ClearAllPoints()
	tile.PortalEffectBackdrop:SetPoint("TOPLEFT", tile.Image, "TOPLEFT")
	tile.PortalEffectBackdrop:SetPoint("BOTTOMRIGHT", tile.Image, "BOTTOMRIGHT")
	tile.TopMask:ClearAllPoints()
	tile.TopMask:SetPoint("TOPLEFT", tile.Image, "TOPLEFT")
	tile.TopMask:SetPoint("TOPRIGHT", tile.Image, "TOPRIGHT")
	tile.TopMask:SetHeight(math.max(1, math.floor(TILE_UI.topMaskHeight * scale + 0.5)))
	tile.NameBackground:ClearAllPoints()
	tile.NameBackground:SetPoint("BOTTOM", tile, "BOTTOM",
		TILE_UI.nameBackgroundOffsetX * scale, TILE_UI.nameBackgroundOffsetY * scale)
	tile.NameBackground:SetSize(
		math.max(1, math.floor((tile.NameBackground.BaseWidth + TILE_UI.nameBackgroundExtraWidth) * scale + 0.5)),
		math.max(1, math.floor(tile.NameBackground.BaseHeight * scale + 0.5)))
	for _, texture in ipairs({ tile.Border, tile.HighlightTexture, tile.SelectedBorder }) do
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", tile, "TOPLEFT",
			TILE_BORDER_LEFT * scale, TILE_BORDER_TOP * scale)
		texture:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT",
			TILE_BORDER_RIGHT * scale, TILE_BORDER_BOTTOM * scale)
	end
	tile.Title:ClearAllPoints()
	tile.Title:SetPoint("CENTER", tile.NameBackground, "CENTER")
	tile.Title:SetSize(
		math.max(1, math.floor(TILE_NAME_TEXT_WIDTH * scale + 0.5)),
		math.max(1, math.floor(TILE_NAME_TEXT_HEIGHT * scale + 0.5)))
	tile.PortalEffectFrame:ClearAllPoints()
	tile.PortalEffectFrame:SetPoint("CENTER", tile, "CENTER",
		TILE_UI.portalEffectOffsetX * scale, TILE_UI.portalEffectOffsetY * scale)
	tile.PortalEffectFrame:SetSize(
		math.max(1, math.floor(TILE_UI.portalEffectWidth * scale + 0.5)),
		math.max(1, math.floor(TILE_UI.portalEffectHeight * scale + 0.5)))
	positionTeleportBadge(tile, tile.TeleportBadgePressed)
	updateBestLevel(tile, tile.PlayerBestLevel, tile.PlayerBestTimed)
	applyFont(tile.KeyText, 11, "OUTLINE")
	updateKeySummary(tile)
end

local function bindTile(tile, data)
	tile.Data = data
	tile.TeleportBadgePressed = false
	tile._gfTeleportVisualState = "fallback"
	positionTeleportBadge(tile, false)
	tile.PlayerBestLevel = data.bestRun and tonumber(data.bestRun.level) or nil
	tile.PlayerBestTimed = data.bestRun and data.bestRun.timed or nil
	tile.DungeonAvailable = data.bestRun ~= nil
		and ((tonumber(data.bestRun.score) or 0) > 0 or (tonumber(data.bestRun.level) or 0) > 0)
	tile.TeleportStatus = data.teleportStatus
	tile.TeleportSecureReady = tile.TeleportStatus == "ready"
	if GF.MythicPlusTeleportService then
		tile.TeleportStatus = GF.MythicPlusTeleportService:GetStatus(data)
		local secureReady, pending =
			GF.MythicPlusTeleportService:ApplySecureButton(tile, data)
		tile.TeleportSecureReady = secureReady == true and pending ~= true
	end
	tile.Title:SetText(data.name or "-")
	tile.Title:SetTextColor(
		tile.DungeonAvailable and 1 or 0.58,
		tile.DungeonAvailable and 1 or 0.58,
		tile.DungeonAvailable and 1 or 0.58)

	local texture = data.visualTexture or data.journalTexture or data.backgroundTexture or data.texture
	if texture then
		tile.Image:SetTexture(texture)
		local texCoords = data.visualTexCoords or data.texCoords
		if not texCoords and data.visualSource == "loreImage" then
			texCoords = EJ_LORE_IMAGE_TEX_COORDS
		end
		applyImageTexCoords(tile.Image, texCoords)
		if tile.Image.SetDesaturated then
			tile.Image:SetDesaturated(not tile.DungeonAvailable)
		end
		if tile.DungeonAvailable then
			tile.Image:SetVertexColor(1, 1, 1, 1)
		else
			tile.Image:SetVertexColor(0.42, 0.42, 0.42, 0.9)
		end
	else
		tile.Image:SetTexture(GF.WHITE_TEXTURE)
		applyImageTexCoords(tile.Image, { 0, 1, 0, 1 })
		if tile.Image.SetDesaturated then
			tile.Image:SetDesaturated(false)
		end
		tile.Image:SetVertexColor(0.08, 0.08, 0.08, 0.95)
	end

	tile.KeyText:SetText(formatKeyHolders(data.keyHolders))
	updateKeySummary(tile)
	updateBestLevel(tile, tile.PlayerBestLevel, tile.PlayerBestTimed)
	updateTeleportBadge(tile)
	setPortalHover(tile, tile.IsMouseOver and tile:IsMouseOver(), true)
	updateSelectedState(tile, data.teleportSelected == true)
	tile:Show()
end

local function clearTile(tile)
	if GF.MythicPlusTeleportService then
		GF.MythicPlusTeleportService:ApplySecureButton(tile, nil)
	end
	tile.Data = nil
	tile.PlayerBestLevel = nil
	tile.PlayerBestTimed = nil
	tile.DungeonAvailable = nil
	tile.TeleportStatus = nil
	tile.TeleportSecureReady = nil
	tile.TeleportBadgePressed = false
	tile._gfTeleportVisualState = "fallback"
	setPortalHover(tile, false, true)
	updateSelectedState(tile, false)
	tile.Title:SetText("")
	tile.Title:SetTextColor(1, 1, 1)
	tile.KeyText:SetText("")
	updateKeySummary(tile)
	updateBestLevel(tile, nil, nil)
	tile.Image:SetTexture(GF.WHITE_TEXTURE)
	applyImageTexCoords(tile.Image, { 0, 1, 0, 1 })
	if tile.Image.SetDesaturated then
		tile.Image:SetDesaturated(false)
	end
	tile.Image:SetVertexColor(0.08, 0.08, 0.08, 0.95)
	tile.TeleportBadge:Hide()
	tile:Hide()
end

function DungeonPage:Create(parent)
	if self.page then
		return self.page
	end

	local page = {}
	page.frame = CreateFrame("Frame", nil, parent)
	page.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, -24)
	page.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -18, 16)
	page.frame:Hide()
	page.container = CreateFrame("Frame", nil, page.frame)
	page.container:SetPoint("CENTER")
	page.container:SetSize(1, 1)
	page.tiles = {}
	page.visibleTileCount = 0

	page.emptyContainer = CreateFrame("Frame", nil, page.frame)
	page.emptyContainer:SetPoint("TOPLEFT", page.container, "BOTTOMLEFT", 0, -12)
	page.emptyContainer:SetPoint("TOPRIGHT", page.frame, "TOPRIGHT", -8, -12)
	page.emptyContainer:SetHeight(28)
	page.emptyText = createText(page.emptyContainer, "GameFontHighlight")
	page.emptyText:SetPoint("TOPLEFT")
	page.emptyText:SetPoint("TOPRIGHT")
	page.emptyText:SetJustifyH("LEFT")
	page.emptyText:SetJustifyV("TOP")
	applyFont(page.emptyText, 12, "")

	local function layout()
		local tileCount = page.visibleTileCount
		if tileCount <= 0 then
			page.container:ClearAllPoints()
			page.container:SetPoint("CENTER", page.frame, "CENTER")
			page.container:SetSize(1, 1)
			return
		end

		local availableWidth = math.max(page.frame:GetWidth() or 0, 1)
		local availableHeight = math.max(page.frame:GetHeight() or 0, 1)
		local rows = math.max(1, math.ceil(tileCount / TILE_COLUMNS))
		local sizingRows = math.max(TILE_BASE_ROWS, rows)
		local maxTileWidth = math.max(1, math.floor((
			availableWidth
			- (GRID_PADDING_X * 2)
			- ((TILE_COLUMNS - 1) * TILE_GAP_X)
		) / TILE_COLUMNS))
		local maxTileHeight = math.max(1, math.floor((
			availableHeight
			- (GRID_PADDING_Y * 2)
			- ((sizingRows - 1) * TILE_GAP_Y)
		) / sizingRows))
		local scale = math.max(0.01, math.min(
			TILE_MAX_SCALE,
			maxTileWidth / TILE_WIDTH,
			maxTileHeight / TILE_HEIGHT))
		local tileWidth = math.max(1, math.floor(TILE_WIDTH * scale + 0.5))
		local tileHeight = math.max(1, math.floor(TILE_HEIGHT * scale + 0.5))
		local gridWidth = TILE_COLUMNS * tileWidth
			+ (TILE_COLUMNS - 1) * TILE_GAP_X
		local totalHeight = rows * tileHeight
			+ math.max(0, rows - 1) * TILE_GAP_Y
		local startX = math.floor(((availableWidth - gridWidth) * 0.5) + 0.5)
		local startY = -math.floor(((availableHeight - totalHeight) * 0.5) + 0.5)

		page.container:ClearAllPoints()
		page.container:SetSize(gridWidth, totalHeight)
		page.container:SetPoint("TOPLEFT", page.frame, "TOPLEFT", startX, startY)
		for index = 1, tileCount do
			local tile = page.tiles[index]
			local column = (index - 1) % TILE_COLUMNS
			local row = math.floor((index - 1) / TILE_COLUMNS)
			local rowTileCount = math.min(TILE_COLUMNS, tileCount - (row * TILE_COLUMNS))
			local rowWidth = rowTileCount * tileWidth
				+ math.max(0, rowTileCount - 1) * TILE_GAP_X
			local rowOffsetX = math.floor(((gridWidth - rowWidth) * 0.5) + 0.5)
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", page.frame, "TOPLEFT",
				startX + rowOffsetX + column * (tileWidth + TILE_GAP_X),
				startY - row * (tileHeight + TILE_GAP_Y))
			applyTileLayout(tile, tileWidth, tileHeight, scale)
		end
	end
	page.frame:HookScript("OnSizeChanged", layout)

	function page:RefreshLocale()
		self.emptyText:SetText((GF.L and GF.L.MPLUS_TOOLTIP_SEASON_UNAVAILABLE)
			or "无法加载当前赛季。")
	end

	function page:RefreshView()
		local sourceDungeons = GF.MythicPlusSeason and GF.MythicPlusSeason:GetDungeons() or {}
		local bestRuns = getBestRuns()
		local holders = getKeyHolders()
		local dungeons = {}

		for sourceOrder, dungeon in ipairs(sourceDungeons) do
			local data = {}
			for key, value in pairs(dungeon) do
				data[key] = value
			end
			data.sourceOrder = sourceOrder
			data.bestRun = dungeon.challengeModeID and bestRuns[tonumber(dungeon.challengeModeID)] or nil
			data.keyHolders = dungeon.challengeModeID and holders[tonumber(dungeon.challengeModeID)] or nil
			if GF.MythicPlusTeleportService then
				data.teleportStatus = GF.MythicPlusTeleportService:GetStatus(data)
				data.teleportSelected = GF.MythicPlusTeleportService:GetActiveChallengeModeID()
					== tonumber(data.challengeModeID)
			end
			dungeons[#dungeons + 1] = data
		end
		local sorter = GF.MythicPlusSeasonDungeonSort
		if sorter and sorter.Sort then
			dungeons = sorter:Sort(dungeons)
		end

		while #self.tiles < #dungeons do
			self.tiles[#self.tiles + 1] = createTile(self.frame)
		end
		self.visibleTileCount = #dungeons
		layout()
		for index, tile in ipairs(self.tiles) do
			if dungeons[index] then
				bindTile(tile, dungeons[index])
			else
				clearTile(tile)
			end
		end
		self.emptyContainer:SetShown(#dungeons == 0)
		self.emptyText:SetShown(#dungeons == 0)
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
	self.page = page
	return page
end
