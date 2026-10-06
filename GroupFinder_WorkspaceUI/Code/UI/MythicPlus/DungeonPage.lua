local _, GF = ...
GF = GF.GF or GF

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
local IMAGE_LEFT = 0
local IMAGE_TOP = 0
local IMAGE_WIDTH = TILE_WIDTH
local IMAGE_HEIGHT = TILE_HEIGHT
local EJ_LORE_IMAGE_TEX_COORDS = { 0.052734375, 0.703125, 0.091796875, 0.556640625 }

-- Rectangle geometry keeps its original UI anchor and native pixel offsets.
-- Other views supply their own geometry to the shared effect lifecycle.
local DUNGEON_PORTAL_STYLE = {
	width = IMAGE_WIDTH,
	height = IMAGE_HEIGHT,
	fallbackWidth = 86,
	fallbackHeight = 92,
	offsetX = 0,
	offsetY = 0,
	anchorX = 45.5,
	anchorY = 20,
	interruptedAnchorX = 45.5,
	effectScale = 1,
	hoverOffsetX = -35,
	hoverOffsetY = -15,
	interruptedOffsetX = -36,
	interruptedOffsetY = -15,
	roundSize = true,
}

local TILE_UI = {
	topMaskAtlas = "housing-basic-panel-gradient-header-bg",
	topMaskHeight = 24,
	keystoneIconTexture = "Interface\\Icons\\INV_Relics_Hourglass_02",
	keystoneIconSize = 14,
	keystoneIconInset = 2,
	keystoneIconBorderTexture = "Interface\\Buttons\\UI-Quickslot2",
	keystoneIconOuterBorderPadding = 9,
	keystoneIconGap = 4,
	keySummaryHeight = 18,
	keySummaryMaxWidth = IMAGE_WIDTH - 24,
	keySummaryOffsetY = 0,
	bestBadgeTexture = GF.MYTHIC_PLUS_BEST_BADGE_TEXTURE,
	bestBadgeTexCoord = GF.MYTHIC_PLUS_BEST_BADGE_TEXCOORD,
	bestBadgeWidth = 64,
	bestBadgeHeight = 64,
	bestBadgeOffsetX = 0,
	bestBadgeOffsetY = 0,
	bestTextOffsetX = 0,
	bestTextOffsetY = 0,
	bestTextWidth = 64,
	bestTextHeight = 64,
	bestFontSize = GF.MYTHIC_PLUS_BEST_LEVEL_STYLE.fontSize,
	portalEffectFallbackAtlas =
		"evergreen-weeklyrewards-reward-unlocked-fx-swirl",
	portalHoverEffect = {
		effectID = 179,
	},
	portalInterruptedEffect = {
		effectID = 180,
	},
	portalInterruptedEffectSeconds = 1.2,
	portalBackdropAlpha = 0.58,
	portalEffectFadeInSeconds = 0.18,
	portalEffectFadeOutSeconds = 0.14,
	portalBackdropFadeInSeconds = 0.16,
	portalBackdropFadeOutSeconds = 0.14,
	bestLevelFadeInSeconds = 0.16,
	bestLevelFadeOutSeconds = 0.12,
	nameBackgroundAtlas = "shop-card-label-bg",
	nameBackgroundSourceCapRatio = UI.LABEL_CAP_SOURCE_RATIO or (30 / 695),
	nameBackgroundOffsetX = 1,
	nameBackgroundOffsetY = 2,
	nameBackgroundExtraWidth = 6,
	nameBackgroundFallbackWidth = TILE_WIDTH - 18,
	nameBackgroundFallbackHeight = 30,
	nameContentOffsetY = -2,
	teleportBadgeSize = 22,
	teleportBadgeRight = -12,
	teleportBadgeOffsetY = -2,
}

local TILE_NAME_TEXT_WIDTH = 104
local TILE_NAME_TEXT_HEIGHT = 32
local TILE_NAME_FONT_SIZE = 14
local TILE_SCORE_TEXT_WIDTH = 48
local TILE_SCORE_TEXT_HEIGHT = 20
local TILE_SCORE_TEXT_LEFT = 9
local TILE_SCORE_FONT_SIZE = 14
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

local function applyFixedCardFontSize(fontString, template, size, fallbackFlags)
	if not fontString then
		return
	end
	fontString._gfFontSizeOverride = size
	fontString._gfIgnoreFontScale = true
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template)
	else
		applyFont(fontString, size, fallbackFlags)
	end
end

local function formatDuration(milliseconds)
	local totalSeconds = math.floor((tonumber(milliseconds) or 0) / 1000)
	if totalSeconds <= 0 then
		return "--"
	end
	return string.format("%d:%02d", math.floor(totalSeconds / 60), totalSeconds % 60)
end

local function getSingleDungeonScoreColor(score, fallback)
	local cache = GF.MythicPlusRatingCache
	local rules = GF.MYTHIC_PLUS_SCORE_COLOR_RULE or {}
	if cache and cache.GetScoreColor then
		return cache:GetScoreColor(score, rules.SINGLE_DUNGEON) or fallback
	end
	return fallback
end

local function createAlphaAnimationGroup(region, fromAlpha, toAlpha, duration, smoothing)
	if not (region and region.CreateAnimationGroup) then
		return nil
	end
	local group = region:CreateAnimationGroup()
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetOrder(1)
	alpha:SetFromAlpha(fromAlpha)
	alpha:SetToAlpha(toAlpha)
	group.Alpha = alpha
	group.FromAlpha, group.ToAlpha = fromAlpha, toAlpha
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
		return string.format("%s %s", levelText, trackLabel)
	end
	return levelText
end

local function formatKeyHolders(entries)
	if type(entries) ~= "table" or #entries == 0 then
		return colorizeEmptyKeyText(
			(GF.L and GF.L.MPLUS_NO_KEY_AVAILABLE) or "暂无钥石")
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
			(GF.L and GF.L.MPLUS_NO_KEY_AVAILABLE) or "暂无钥石")
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

-- Preserve the displayed alpha when a hover reverses before its fade finishes.
local function transitionAlpha(region, fadeIn, fadeOut, visible, maximum, immediate)
	local current = region:GetAlpha()
	for _, group in ipairs({ fadeIn, fadeOut }) do
		if group:IsPlaying() then
			local progress = group.Alpha:GetSmoothProgress()
			current = group.FromAlpha + (group.ToAlpha - group.FromAlpha) * progress
		end
		stopAnimationGroup(group)
	end
	local target = visible and maximum or 0
	if immediate or math.abs(current - target) < 0.001 then
		region:SetAlpha(target)
		return
	end
	local group = visible and fadeIn or fadeOut
	region:SetAlpha(current)
	group.FromAlpha, group.ToAlpha = current, target
	group.Alpha:SetFromAlpha(current)
	group.Alpha:SetToAlpha(target)
	group:Play()
end

local function setBestLevelAlpha(tile, visible, immediate)
	if tile and tile.BestLevelFrame then
		transitionAlpha(tile.BestLevelFrame, tile.BestLevelFadeIn, tile.BestLevelFadeOut,
			visible and tile.BestLevelAvailable, 1, immediate)
	end
end

function DungeonPage.UpdateBestLevelText(tile, text, level, timed)
	local available = UI.ApplyBestRunLevelText(text, level, timed)
	if tile.BestLevelAvailable ~= available then
		tile.BestLevelAvailable = available
		setBestLevelAlpha(tile, not tile.PortalEffectActive, true)
	end
	return available
end

local function setPortalBackdropAlpha(tile, visible, immediate)
	if tile and tile.PortalEffectBackdrop then
		transitionAlpha(tile.PortalEffectBackdrop, tile.PortalBackdropFadeIn,
			tile.PortalBackdropFadeOut, visible, TILE_UI.portalBackdropAlpha, immediate)
	end
end

local function clearPortalDynamicEffect(tile)
	if not tile then
		return
	end
	tile.PortalEffectRequest = (tile.PortalEffectRequest or 0) + 1
	if tile.PortalDynamicEffect and tile.PortalDynamicEffect.CancelEffect then
		pcall(tile.PortalDynamicEffect.CancelEffect, tile.PortalDynamicEffect)
	end
	tile.PortalDynamicEffect = nil
	tile.PortalDynamicEffectScale = nil
	tile.PortalDynamicEffectInfo = nil
	local modelScene = tile.PortalEffectModelScene
	if modelScene and modelScene.ClearEffects then
		pcall(modelScene.ClearEffects, modelScene)
	end
	if modelScene then
		modelScene:Hide()
	end
	if tile.PortalEffectFallback then
		tile.PortalEffectFallback:Hide()
	end
end

local function positionPortalEffectAnchor(tile, effectInfo)
	local style = tile.PortalPresentationStyle
	local scale = tile.LayoutScale or 1
	local anchorX = effectInfo == TILE_UI.portalInterruptedEffect
		and style.interruptedAnchorX or style.anchorX
	tile.PortalEffectAnchor:ClearAllPoints()
	tile.PortalEffectAnchor:SetPoint("CENTER", tile.PortalEffectFrame, "CENTER",
		anchorX * scale, style.anchorY * scale)
end

local function scaledPortalSize(size, scale, roundSize)
	size = size * scale
	return math.max(1, roundSize and math.floor(size + 0.5) or size)
end

local function layoutPortalPresentation(tile)
	local style = tile.PortalPresentationStyle
	local scale = tile.LayoutScale or 1
	tile.PortalEffectFrame:ClearAllPoints()
	tile.PortalEffectFrame:SetPoint("CENTER", tile, "CENTER",
		style.offsetX * scale, style.offsetY * scale)
	tile.PortalEffectFrame:SetSize(
		scaledPortalSize(style.width, scale, style.roundSize),
		scaledPortalSize(style.height, scale, style.roundSize))
	tile.PortalEffectFallback:ClearAllPoints()
	tile.PortalEffectFallback:SetPoint("CENTER", tile.PortalEffectFrame, "CENTER")
	tile.PortalEffectFallback:SetSize(
		scaledPortalSize(style.fallbackWidth, scale, style.roundSize),
		scaledPortalSize(style.fallbackHeight, scale, style.roundSize))
	positionPortalEffectAnchor(tile, tile.PortalEffectInfo or tile.PortalDynamicEffectInfo)
end

local function setPortalDynamicEffect(tile, effectInfo)
	if not (tile and effectInfo) then
		clearPortalDynamicEffect(tile)
		return
	end
	tile.PortalEffectRequest = (tile.PortalEffectRequest or 0) + 1
	local request = tile.PortalEffectRequest
	local function apply()
		if request ~= tile.PortalEffectRequest
			or tile.PortalEffectInfo ~= effectInfo
		then
			return
		end
		local modelScene = tile.PortalEffectModelScene
		local anchor = tile.PortalEffectAnchor
		local style = tile.PortalPresentationStyle
		local effectScale = style.effectScale * (tile.LayoutScale or 1)
		local interrupted = effectInfo == TILE_UI.portalInterruptedEffect
		positionPortalEffectAnchor(tile, effectInfo)
		if modelScene
			and modelScene.RefreshModelScene
			and modelScene.ClearEffects
			and modelScene.AddDynamicEffect
		then
			local ok, effect = pcall(function()
				if tile.PortalDynamicEffect
					and tile.PortalDynamicEffect.CancelEffect
				then
					tile.PortalDynamicEffect:CancelEffect()
				end
				tile.PortalDynamicEffect = nil
				modelScene:RefreshModelScene()
				modelScene:ClearEffects()
				return modelScene:AddDynamicEffect({
					effectID = effectInfo.effectID,
					offsetX = interrupted and style.interruptedOffsetX or style.hoverOffsetX,
					offsetY = interrupted and style.interruptedOffsetY or style.hoverOffsetY,
				}, anchor, nil, nil, nil, effectScale)
			end)
			if ok and effect then
				tile.PortalDynamicEffect = effect
				tile.PortalDynamicEffectScale = effectScale
				tile.PortalDynamicEffectInfo = effectInfo
				modelScene:Show()
				tile.PortalEffectFallback:Hide()
				return
			end
			modelScene:Hide()
		end
		tile.PortalDynamicEffectScale = effectScale
		tile.PortalDynamicEffectInfo = effectInfo
		tile.PortalEffectFallback:Show()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, apply)
	else
		apply()
	end
end

local function setPortalEffectAlpha(tile, visible, immediate)
	if tile and tile.PortalEffectFrame then
		transitionAlpha(tile.PortalEffectFrame, tile.PortalEffectFadeIn,
			tile.PortalEffectFadeOut, visible, 1, immediate)
	end
end

local function setPortalHover(tile, active, immediate)
	if not tile then
		return
	end
	-- A caller may suppress interaction feedback while another destination is
	-- casting. Invalidate old interrupt callbacks as well as current hover.
	local blocked = tile.PortalInteractionBlocked == true
	if blocked and tile.PortalInterruptActive then
		tile.PortalInterruptToken = (tile.PortalInterruptToken or 0) + 1
		tile.PortalInterruptActive = nil
	end
	local hoverReady = active == true and tile.TeleportStatus == "ready"
		and tile.TeleportSecureReady ~= false
		and not UI.IsTeleportCombatLocked()
	local castActive = tile.TeleportCastActive == true
	local effectInfo
	if not blocked then
		effectInfo = tile.PortalInterruptActive == true
			and TILE_UI.portalInterruptedEffect
			or ((hoverReady or castActive) and TILE_UI.portalHoverEffect or nil)
	end
	local shouldShow = effectInfo ~= nil
	local effectChanged = tile.PortalEffectInfo ~= effectInfo
	if not effectChanged and tile.PortalEffectActive == shouldShow
		and not immediate
	then
		return
	end
	tile.PortalEffectActive = shouldShow
	tile.PortalEffectInfo = effectInfo
	if effectChanged then
		if effectInfo or immediate then
			setPortalDynamicEffect(tile, effectInfo)
		else
			-- Invalidate deferred setup now; keep the scene alive through fade-out.
			tile.PortalEffectRequest = (tile.PortalEffectRequest or 0) + 1
		end
	end
	setPortalBackdropAlpha(tile, shouldShow, immediate)
	setBestLevelAlpha(tile, not shouldShow, immediate)
	setPortalEffectAlpha(tile, shouldShow, immediate)
end

local function playPortalInterruptedEffect(tile, interruptSerial)
	if not (tile and interruptSerial) then
		return
	end
	tile.PortalInterruptToken = (tile.PortalInterruptToken or 0) + 1
	local token = tile.PortalInterruptToken
	tile.PortalInterruptActive = true
	setPortalHover(tile, tile.IsMouseOver and tile:IsMouseOver(), false)
	local function finish()
		if not tile or token ~= tile.PortalInterruptToken then
			return
		end
		tile.PortalInterruptActive = nil
		setPortalHover(tile, tile.IsMouseOver and tile:IsMouseOver(), false)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(TILE_UI.portalInterruptedEffectSeconds, finish)
	else
		finish()
	end
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
			size = TILE_UI.teleportBadgeSize,
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
	if not DungeonPage.UpdateBestLevelText(tile, tile.BestText, level, timed) then
		stopAnimationGroup(tile.BestLevelFadeIn)
		stopAnimationGroup(tile.BestLevelFadeOut)
		tile.BestLevelFrame:SetAlpha(0)
		tile.BestBadge:Hide()
		tile.BestText:Hide()
		return
	end

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
	applyFont(tile.BestText, math.max(1, math.floor(TILE_UI.bestFontSize * scale + 0.5)),
		GF.MYTHIC_PLUS_BEST_LEVEL_STYLE.fontFlags)
	tile.BestBadge:Show()
	tile.BestText:Show()
end

local NAME_BACKGROUND_PIECE_KEYS = { "left", "center", "right" }

local function layoutNameBackgroundCrop(background)
	if not (background and background.Pieces) then
		return
	end
	local pieces = background.Pieces
	local targetWidth = math.max(1, tonumber(background:GetWidth()) or 1)
	local targetHeight = math.max(1, tonumber(background:GetHeight()) or 1)
	if not (background.AtlasInfo and background.SourceCapWidth) then
		pieces.left:Hide()
		pieces.right:Hide()
		pieces.center:ClearAllPoints()
		pieces.center:SetAllPoints(background)
		pieces.center:Show()
		return
	end

	local sourceHeight = tonumber(background.AtlasInfo.logicalHeight) or 0
	local displayCapWidth = sourceHeight > 0
		and background.SourceCapWidth * targetHeight / sourceHeight
		or 0
	displayCapWidth = math.max(1, math.min(displayCapWidth, targetWidth / 2))

	pieces.left:ClearAllPoints()
	pieces.left:SetPoint("TOPLEFT", background, "TOPLEFT")
	pieces.left:SetPoint("BOTTOMLEFT", background, "BOTTOMLEFT")
	pieces.left:SetWidth(displayCapWidth)
	pieces.left:Show()
	pieces.right:ClearAllPoints()
	pieces.right:SetPoint("TOPRIGHT", background, "TOPRIGHT")
	pieces.right:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT")
	pieces.right:SetWidth(displayCapWidth)
	pieces.right:Show()
	pieces.center:ClearAllPoints()
	pieces.center:SetPoint("TOPLEFT", pieces.left, "TOPRIGHT")
	pieces.center:SetPoint("BOTTOMRIGHT", pieces.right, "BOTTOMLEFT")
	pieces.center:Show()
end

local function createNameBackground(tile)
	local background = CreateFrame("Frame", nil, tile)
	background:SetFrameLevel(tile:GetFrameLevel())
	background.BaseWidth = TILE_UI.nameBackgroundFallbackWidth
	background.BaseHeight = TILE_UI.nameBackgroundFallbackHeight

	local function createPiece()
		local texture = tile:CreateTexture(nil, "ARTWORK", nil, 1)
		if GF.UI.SetNativeAtlasSampling then
			GF.UI.SetNativeAtlasSampling(texture, true)
		end
		return texture
	end
	local pieces = {
		left = createPiece(),
		center = createPiece(),
		right = createPiece(),
	}
	background.Pieces = pieces

	local atlasInfo = GF.UI.GetNativeAtlasInfo
		and GF.UI.GetNativeAtlasInfo(TILE_UI.nameBackgroundAtlas)
	local sourceWidth = atlasInfo and tonumber(atlasInfo.logicalWidth) or 0
	local sourceCapWidth = sourceWidth * TILE_UI.nameBackgroundSourceCapRatio
	local capRatio = sourceWidth > 0 and sourceCapWidth / sourceWidth or 0
	if atlasInfo
		and capRatio > 0 and capRatio < 0.5
		and GF.UI.SetNativeAtlasPieceRegion
	then
		local ranges = {
			left = { 0, capRatio },
			center = { capRatio, 1 - capRatio },
			right = { 1 - capRatio, 1 },
		}
		local applied = true
		for _, key in ipairs(NAME_BACKGROUND_PIECE_KEYS) do
			local range = ranges[key]
			applied = GF.UI.SetNativeAtlasPieceRegion(
				pieces[key],
				atlasInfo,
				range[1],
				range[2],
				0,
				1,
				true
			) and applied
		end
		if applied then
			background.AtlasInfo = atlasInfo
			background.SourceCapWidth = sourceCapWidth
		end
	end

	if not background.AtlasInfo then
		pieces.left:SetTexture(nil)
		pieces.right:SetTexture(nil)
		if not GF.UI.TrySetAtlas(
			pieces.center,
			TILE_UI.nameBackgroundAtlas,
			false
		) then
			pieces.center:SetTexture(GF.WHITE_TEXTURE)
			pieces.center:SetVertexColor(0, 0, 0, 0.72)
		end
	end

	background:SetSize(
		background.BaseWidth + TILE_UI.nameBackgroundExtraWidth,
		background.BaseHeight)
	background:SetPoint("BOTTOM", tile, "BOTTOM",
		TILE_UI.nameBackgroundOffsetX, TILE_UI.nameBackgroundOffsetY)
	layoutNameBackgroundCrop(background)
	return background
end

-- Shared visual presentation only; TeleportService remains the action/state owner.
function DungeonPage.AttachPortalPresentation(tile, image, bestLevelFrame, scale, imageMask, style)
	scale = scale or 1
	style = style or DUNGEON_PORTAL_STYLE
	tile.PortalPresentationStyle = style
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
	local portalEffectFrame = CreateFrame("Frame", nil, tile)
	portalEffectFrame:SetFrameLevel(tile:GetFrameLevel() + 7)
	portalEffectFrame:SetPoint("CENTER", tile, "CENTER",
		style.offsetX, style.offsetY)
	portalEffectFrame:SetSize(style.width, style.height)
	portalEffectFrame:SetAlpha(0)
	portalEffectFrame:EnableMouse(false)
	local portalEffectFallback = portalEffectFrame:CreateTexture(nil, "OVERLAY")
	portalEffectFallback:SetPoint("CENTER")
	portalEffectFallback:SetSize(
		style.fallbackWidth,
		style.fallbackHeight)
	portalEffectFallback:SetBlendMode("ADD")
	if not GF.UI.TrySetAtlas(
		portalEffectFallback,
		TILE_UI.portalEffectFallbackAtlas,
		false)
	then
		portalEffectFallback:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
		portalEffectFallback:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	portalEffectFallback:Hide()
	local portalEffectAnchor = CreateFrame("Frame", nil, portalEffectFrame)
	portalEffectAnchor:SetPoint("CENTER", portalEffectFrame, "CENTER",
		style.anchorX, style.anchorY)
	portalEffectAnchor:SetSize(1, 1)
	portalEffectAnchor:EnableMouse(false)
	local portalEffectModelScene
	local modelSceneCreated, createdModelScene = pcall(
		CreateFrame,
		"ModelScene",
		nil,
		portalEffectFrame,
		"ScriptAnimatedModelSceneTemplate")
	if modelSceneCreated and createdModelScene then
		portalEffectModelScene = createdModelScene
		portalEffectModelScene:SetAllPoints(portalEffectFrame)
		portalEffectModelScene:SetFrameLevel(portalEffectFrame:GetFrameLevel() + 1)
		portalEffectModelScene:EnableMouse(false)
		portalEffectModelScene:Hide()
	end
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
			if not tile.PortalEffectActive then clearPortalDynamicEffect(tile) end
		end)
	end

	tile.PortalEffectBackdrop = portalBackdrop
	tile.PortalBackdropFadeIn = portalBackdropFadeIn
	tile.PortalBackdropFadeOut = portalBackdropFadeOut
	tile.BestLevelFrame = bestLevelFrame
	tile.BestLevelFadeIn = bestLevelFadeIn
	tile.BestLevelFadeOut = bestLevelFadeOut
	tile.PortalEffectFrame = portalEffectFrame
	tile.PortalEffectFallback = portalEffectFallback
	tile.PortalEffectAnchor = portalEffectAnchor
	tile.PortalEffectModelScene = portalEffectModelScene
	tile.PortalEffectFadeIn = portalEffectFadeIn
	tile.PortalEffectFadeOut = portalEffectFadeOut
	tile.LayoutScale = scale
	if imageMask then
		portalBackdrop:AddMaskTexture(imageMask)
	end
	layoutPortalPresentation(tile)
end

DungeonPage.SetPortalHover = setPortalHover
DungeonPage.PlayPortalInterruptedEffect = playPortalInterruptedEffect

function DungeonPage.ClearPortalPresentation(tile)
	tile.PortalInterruptToken = (tile.PortalInterruptToken or 0) + 1
	tile.PortalInterruptActive, tile.TeleportCastActive = nil, nil
	setPortalHover(tile, false, true)
	clearPortalDynamicEffect(tile)
end

local function addDungeonTooltipLines(tooltip, data, secureReady)
	tooltip:AddLine(data.name or "-", 1, 0.82, 0)
	local run = data.bestRun
	local rating = GF.MythicPlusRatingCache
	local highestLevel = rating and rating.GetHighestCompletedLevel
		and rating:GetHighestCompletedLevel(data.challengeModeID or data.mapID)
	if not run and not highestLevel then
		tooltip:AddLine((GF.L and GF.L.MPLUS_NO_COMPLETION_RECORD)
			or "暂无通关记录", 0.58, 0.58, 0.58, true)
	end
	local scoreText = "--"
	if run then
		local roundedScore = math.floor((tonumber(run.score) or 0) + 0.5)
		scoreText = string.format("|c%s%d|r",
			UI.ColorToARGBHex(getSingleDungeonScoreColor(run.score, run.scoreColor)),
			roundedScore)
	end
	tooltip:AddDoubleLine((GF.L and GF.L.MPLUS_BEST_RUN_SCORE_LABEL) or "最佳评分",
		scoreText, 1, 0.82, 0, 1, 0.82, 0)
	tooltip:AddDoubleLine((GF.L and GF.L.MPLUS_TOOLTIP_BEST_COMPLETION) or "最佳通关",
		run and formatDuration(run.durationMS) or "--", 1, 0.82, 0, 1, 1, 1)
	tooltip:AddDoubleLine((GF.L and GF.L.MPLUS_TOOLTIP_BEST_LEVEL) or "最佳层数",
		highestLevel and tostring(highestLevel) or "--", 1, 0.82, 0, 1, 1, 1)
	tooltip:AddLine(" ")
	if GF.MythicPlusTeleportService then
		GF.MythicPlusTeleportService:AddTooltipLines(tooltip, data, {
			includeDestinationTitle = false,
			secureReady = secureReady == true,
		})
	end
	if #(data.keyHolders or {}) == 0 then
		tooltip:AddLine((GF.L and GF.L.MPLUS_GROUP_HAS_NO_KEYS)
			or "队伍中没有钥石", 0.85, 0.85, 0.85, true)
	else
		for _, character in ipairs(data.keyHolders) do
			local r, g, b = UI.GetClassColor(character.classFile or character.class, 1, 1, 1)
			tooltip:AddDoubleLine(character.fullName or character.name or "-",
				formatKeyHolderDetail(character), r, g, b, 1, 1, 1)
		end
	end
end

DungeonPage.AddTooltipLines = addDungeonTooltipLines
DungeonPage.GetTooltipKeyHolders = getKeyHolders

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


	local topMask = tile:CreateTexture(nil, "ARTWORK", nil, 1)
	if not GF.UI.TrySetAtlas(topMask, TILE_UI.topMaskAtlas, false) then
		topMask:SetColorTexture(0, 0, 0, 0.72)
	end
	topMask:SetPoint("TOPLEFT", image, "TOPLEFT")
	topMask:SetPoint("TOPRIGHT", image, "TOPRIGHT")
	topMask:SetHeight(TILE_UI.topMaskHeight)

	local nameBackground = createNameBackground(tile)

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
	applyFixedCardFontSize(
		title,
		"GameFontHighlight",
		TILE_NAME_FONT_SIZE,
		""
	)
	title:SetPoint(
		"CENTER",
		nameBackground,
		"CENTER",
		0,
		TILE_UI.nameContentOffsetY
	)
	title:SetSize(TILE_NAME_TEXT_WIDTH, TILE_NAME_TEXT_HEIGHT)
	title:SetJustifyH("CENTER")
	title:SetTextColor(1, 1, 1)
	title:SetWordWrap(true)
	if title.SetSpacing then
		title:SetSpacing(2)
	end

	local score = createText(tile, "GameFontHighlightSmall")
	applyFixedCardFontSize(
		score,
		"GameFontHighlightSmall",
		TILE_SCORE_FONT_SIZE,
		"OUTLINE"
	)
	score:SetPoint(
		"LEFT",
		nameBackground,
		"LEFT",
		TILE_SCORE_TEXT_LEFT,
		TILE_UI.nameContentOffsetY
	)
	score:SetSize(TILE_SCORE_TEXT_WIDTH, TILE_SCORE_TEXT_HEIGHT)
	score:SetJustifyH("LEFT")
	score:SetWordWrap(false)

	local bestLevelFrame = CreateFrame("Frame", nil, tile)
	bestLevelFrame:SetFrameLevel(tile:GetFrameLevel() + 6)
	bestLevelFrame:SetPoint("CENTER")
	bestLevelFrame:SetSize(TILE_UI.bestBadgeWidth, TILE_UI.bestBadgeHeight)
	bestLevelFrame:SetAlpha(0)

	local bestBadge = bestLevelFrame:CreateTexture(nil, "OVERLAY", nil, 0)
	bestBadge:SetTexture(TILE_UI.bestBadgeTexture)
	bestBadge:SetTexCoord(
		TILE_UI.bestBadgeTexCoord[1], TILE_UI.bestBadgeTexCoord[2],
		TILE_UI.bestBadgeTexCoord[3], TILE_UI.bestBadgeTexCoord[4])
	bestBadge:SetAllPoints()
	bestBadge:Hide()
	local bestText = createText(bestLevelFrame, GF.MYTHIC_PLUS_BEST_LEVEL_STYLE.fontTemplate)
	bestText:SetPoint("CENTER")
	bestText:SetSize(TILE_UI.bestTextWidth, TILE_UI.bestTextHeight)
	bestText:SetJustifyH("CENTER")
	bestText:SetTextColor(1, 1, 1)
	applyFont(bestText, TILE_UI.bestFontSize, GF.MYTHIC_PLUS_BEST_LEVEL_STYLE.fontFlags)
	bestText:Hide()


	DungeonPage.AttachPortalPresentation(tile, image, bestLevelFrame)

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
	tile.TopMask = topMask
	tile.NameBackground = nameBackground
	tile.Border = border
	tile.HighlightTexture = highlight
	tile.SelectedBorder = selectedBorder
	tile.SelectedBorderFadeIn = selectedBorderFadeIn
	tile.Title = title
	tile.Score = score
	tile.BestBadge = bestBadge
	tile.BestText = bestText
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
		DungeonPage.AddTooltipLines(GameTooltip, data,
			frame.gfTeleportSecureReady == true and frame.gfTeleportSecurePending ~= true)
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
	layoutNameBackgroundCrop(tile.NameBackground)
	for _, texture in ipairs({ tile.Border, tile.HighlightTexture, tile.SelectedBorder }) do
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", tile, "TOPLEFT",
			TILE_BORDER_LEFT * scale, TILE_BORDER_TOP * scale)
		texture:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT",
			TILE_BORDER_RIGHT * scale, TILE_BORDER_BOTTOM * scale)
	end
	tile.Title:ClearAllPoints()
	tile.Title:SetPoint(
		"CENTER",
		tile.NameBackground,
		"CENTER",
		0,
		TILE_UI.nameContentOffsetY * scale
	)
	tile.Title:SetSize(
		math.max(1, math.floor(TILE_NAME_TEXT_WIDTH * scale + 0.5)),
		math.max(1, math.floor(TILE_NAME_TEXT_HEIGHT * scale + 0.5)))
	tile.Score:ClearAllPoints()
	tile.Score:SetPoint("LEFT", tile.NameBackground, "LEFT",
		TILE_SCORE_TEXT_LEFT * scale,
		TILE_UI.nameContentOffsetY * scale)
	tile.Score:SetSize(
		math.max(1, math.floor(TILE_SCORE_TEXT_WIDTH * scale + 0.5)),
		math.max(1, math.floor(TILE_SCORE_TEXT_HEIGHT * scale + 0.5)))
	layoutPortalPresentation(tile)
	local nextEffectScale = tile.PortalPresentationStyle.effectScale * scale
	if tile.PortalEffectInfo
		and tile.PortalDynamicEffectScale ~= nextEffectScale
	then
		setPortalDynamicEffect(tile, tile.PortalEffectInfo)
	end
	positionTeleportBadge(tile, tile.TeleportBadgePressed)
	updateBestLevel(tile, tile.PlayerBestLevel, tile.PlayerBestTimed)
	applyFont(tile.KeyText, 11, "OUTLINE")
	updateKeySummary(tile)
end

local function bindTile(tile, data)
	local previousChallengeModeID = tonumber(
		tile.Data and tile.Data.challengeModeID)
	local nextChallengeModeID = tonumber(data and data.challengeModeID)
	if previousChallengeModeID ~= nextChallengeModeID then
		tile.PortalInterruptToken = (tile.PortalInterruptToken or 0) + 1
		tile.PortalInterruptActive = nil
	end
	tile.Data = data
	if data.teleportInterrupted then
		tile.PortalInterruptActive = true
	end
	tile.TeleportCastActive = data.teleportSelected == true
	tile.TeleportBadgePressed = false
	tile._gfTeleportVisualState = "fallback"
	positionTeleportBadge(tile, false)
	tile.PlayerBestLevel = data.bestRun and tonumber(data.bestRun.level) or nil
	-- Preserve false: false means the matched best run was overtime, while nil
	-- means its timing state could not be verified and should stay neutral.
	tile.PlayerBestTimed = data.bestRun and data.bestRun.timed
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
	local dungeonScore = tonumber(data.bestRun and data.bestRun.score) or 0
	if dungeonScore > 0 then
		local scoreColor = getSingleDungeonScoreColor(
			dungeonScore, data.bestRun and data.bestRun.scoreColor)
		tile.Score:SetText(tostring(math.floor(dungeonScore + 0.5)))
		tile.Score:SetTextColor(
			tonumber(scoreColor and scoreColor.r) or 1,
			tonumber(scoreColor and scoreColor.g) or 1,
			tonumber(scoreColor and scoreColor.b) or 1,
			tonumber(scoreColor and scoreColor.a) or 1)
	else
		tile.Score:SetText((GF.L and GF.L.MPLUS_NO_DUNGEON_SCORE) or "无评分")
		tile.Score:SetTextColor(0.5, 0.5, 0.5, 0.92)
	end

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
	setPortalHover(tile, tile.IsMouseOver and tile:IsMouseOver(),
		previousChallengeModeID ~= nextChallengeModeID)
	updateSelectedState(tile, tile.TeleportCastActive)
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
	tile.PortalInterruptToken = (tile.PortalInterruptToken or 0) + 1
	tile.PortalInterruptActive = nil
	tile.TeleportCastActive = nil
	tile.TeleportSecureReady = nil
	tile.TeleportBadgePressed = false
	tile._gfTeleportVisualState = "fallback"
	setPortalHover(tile, false, true)
	updateSelectedState(tile, false)
	tile.Title:SetText("")
	tile.Title:SetTextColor(1, 1, 1)
	tile.Score:SetText("")
	tile.Score:SetTextColor(1, 1, 1)
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
		local teleportService = GF.MythicPlusTeleportService
		local activeTeleportChallengeModeID = teleportService
			and teleportService.GetActiveChallengeModeID
			and teleportService:GetActiveChallengeModeID() or nil
		local interruptedChallengeModeID, interruptSerial
		if teleportService and teleportService.GetInterruptedCastPulse then
			interruptedChallengeModeID, interruptSerial =
				teleportService:GetInterruptedCastPulse()
		end
		local shouldPlayInterrupt = interruptSerial ~= nil
			and interruptSerial ~= self.lastTeleportInterruptSerial

		for sourceOrder, dungeon in ipairs(sourceDungeons) do
			local data = {}
			for key, value in pairs(dungeon) do
				data[key] = value
			end
			data.sourceOrder = sourceOrder
			data.bestRun = dungeon.challengeModeID and bestRuns[tonumber(dungeon.challengeModeID)] or nil
			data.keyHolders = dungeon.challengeModeID and holders[tonumber(dungeon.challengeModeID)] or nil
			if teleportService then
				data.teleportStatus = teleportService:GetStatus(data)
				data.teleportSelected = activeTeleportChallengeModeID
					== tonumber(data.challengeModeID)
				data.teleportInterrupted = shouldPlayInterrupt
					and interruptedChallengeModeID
						== tonumber(data.challengeModeID)
				data.teleportInterruptSerial = data.teleportInterrupted
					and interruptSerial or nil
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
				if dungeons[index].teleportInterrupted then
					playPortalInterruptedEffect(
						tile,
						dungeons[index].teleportInterruptSerial)
				end
			else
				clearTile(tile)
			end
		end
		if shouldPlayInterrupt then
			self.lastTeleportInterruptSerial = interruptSerial
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
		for _, tile in ipairs(self.tiles or {}) do
			tile.PortalInterruptToken = (tile.PortalInterruptToken or 0) + 1
			tile.PortalInterruptActive = nil
			tile.TeleportCastActive = nil
			setPortalHover(tile, false, true)
		end
		self.frame:Hide()
	end

	page:RefreshLocale()
	self.page = page
	return page
end
