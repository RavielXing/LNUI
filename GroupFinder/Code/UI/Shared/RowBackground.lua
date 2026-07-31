local _, GF = ...

GF.UI = GF.UI or {}
local WHITE = GF.WHITE_TEXTURE

-- 共享三段式列表行背景渲染。

local ROW_BACKGROUND_ATLAS = GF.ROW_BACKGROUND_ATLAS or "UI-QuestTracker-Secondary-Objective-Header"
local ROW_BACKGROUND_STATE_COLORS = GF.ROW_BACKGROUND_STATE_COLORS or {
	red = { 1, 0.16, 0.12, 1 },
	blue = { 0.36, 0.68, 1, 1 },
	green = { 0.14, 0.95, 0.24, 1 },
	grey = { 0.52, 0.52, 0.52, 1 },
}

function GF.UI.CreateRowBackgroundPieces(parent, layer, subLevel)
	local pieces = {}
	if not (parent and parent.CreateTexture) then
		return pieces
	end
	for _, key in ipairs({ "left", "middle", "right" }) do
		local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or -2)
		pieces[key] = tex
	end
	return pieces
end

local function setRowBackgroundPiecesShown(pieces, shown)
	for _, piece in pairs(pieces or {}) do
		if piece.SetShown then
			piece:SetShown(shown == true)
		end
	end
end

function GF.UI.SetRowBackgroundPiecesShown(pieces, shown)
	setRowBackgroundPiecesShown(pieces, shown)
end

local function getRowBackgroundProfile(opts)
	if type(opts) == "table" and opts.useGlobalProfile == false then
		return {}
	end
	return type(GF.ROW_BACKGROUND_PROFILE) == "table"
		and GF.ROW_BACKGROUND_PROFILE
		or {}
end

local function getRowBackgroundOption(opts, profile, key, fallback)
	if type(opts) == "table" and opts[key] ~= nil then
		return opts[key]
	end
	if type(profile) == "table" and profile[key] ~= nil then
		return profile[key]
	end
	return fallback
end

local function getRowBackgroundMetrics(opts)
	opts = type(opts) == "table" and opts or {}
	local profile = getRowBackgroundProfile(opts)
	local sourceW = math.max(
		1,
		tonumber(getRowBackgroundOption(
			opts,
			profile,
			"sourceWidth",
			GF.ROW_BACKGROUND_SOURCE_WIDTH or 564)) or 564)
	local sourceH = math.max(
		1,
		tonumber(getRowBackgroundOption(
			opts,
			profile,
			"sourceHeight",
			GF.ROW_BACKGROUND_SOURCE_HEIGHT or 52)) or 52)
	local sourceCapW = math.max(
		0,
		tonumber(getRowBackgroundOption(
			opts,
			profile,
			"sourceCapWidth",
			GF.ROW_BACKGROUND_SOURCE_CAP_WIDTH or 18)) or 18)
	local topSourceH = math.max(
		0,
		tonumber(getRowBackgroundOption(
			opts,
			profile,
			"topSourceHeight",
			GF.ROW_BACKGROUND_TOP_SOURCE_HEIGHT or 8)) or 8)
	local cropTop = math.max(
		0,
		tonumber(getRowBackgroundOption(
			opts,
			profile,
			"cropTopPixels",
			0)) or 0)
	local cropBottom = math.max(
		0,
		tonumber(getRowBackgroundOption(
			opts,
			profile,
			"cropBottomPixels",
			0)) or 0)
	cropTop = math.min(cropTop, math.max(sourceH - 1, 0))
	cropBottom = math.min(
		cropBottom,
		math.max(sourceH - cropTop - 1, 0))

	local visibleTop = cropTop
	local visibleBottom = sourceH - cropBottom
	local effectiveSourceH = math.max(1, visibleBottom - visibleTop)
	local split = math.max(
		visibleTop,
		math.min(visibleTop + topSourceH, visibleBottom))
	return {
		profile = profile,
		sourceWidth = sourceW,
		sourceHeight = sourceH,
		sourceCapWidth = sourceCapW,
		topSourceHeight = topSourceH,
		cropTopPixels = cropTop,
		cropBottomPixels = cropBottom,
		visibleTopPixels = visibleTop,
		visibleBottomPixels = visibleBottom,
		effectiveSourceHeight = effectiveSourceH,
		splitPixels = split,
	}
end

local function getRowBackgroundAtlasInfo(atlas)
	atlas = atlas or ROW_BACKGROUND_ATLAS
	if C_Texture and C_Texture.GetAtlasInfo then
		local info = C_Texture.GetAtlasInfo(atlas)
		if info
			and type(info.leftTexCoord) == "number"
			and type(info.rightTexCoord) == "number"
			and type(info.topTexCoord) == "number"
			and type(info.bottomTexCoord) == "number" then
			return info
		end
	end
	return nil
end

local function setRowBackgroundPieceTexture(piece, atlas, atlasInfo)
	if not piece then
		return false
	end
	if atlasInfo then
		local file = atlasInfo.file or atlasInfo.filename
		if file then
			piece:SetTexture(file)
			return true
		end
	end
	return atlasInfo ~= nil and GF.UI.TrySetAtlas(piece, atlas or ROW_BACKGROUND_ATLAS, false)
end

local function setRowBackgroundPieceCoords(piece, texLeft, texRight, texTop, texBottom, opts)
	local atlas = opts and opts.atlas or ROW_BACKGROUND_ATLAS
	local atlasInfo = getRowBackgroundAtlasInfo(atlas)
	if setRowBackgroundPieceTexture(piece, atlas, atlasInfo) then
		local left = atlasInfo and atlasInfo.leftTexCoord or 0
		local right = atlasInfo and atlasInfo.rightTexCoord or 1
		local top = atlasInfo and atlasInfo.topTexCoord or 0
		local bottom = atlasInfo and atlasInfo.bottomTexCoord or 1
		local atlasW = right - left
		local atlasH = bottom - top
		piece:SetTexCoord(
			left + (atlasW * texLeft),
			left + (atlasW * texRight),
			top + (atlasH * texTop),
			top + (atlasH * texBottom)
		)
		return true
	end
	local fallbackTexture = opts and opts.fallbackTexture
	if fallbackTexture then
		piece:SetTexture(fallbackTexture)
		piece:SetTexCoord(texLeft, texRight, texTop, texBottom)
		return false
	end
	piece:SetTexture(WHITE)
	piece:SetTexCoord(0, 1, 0, 1)
	return false
end

local function applyRowBackgroundTint(piece, state, alpha, atlasApplied, opts)
	if not piece then
		return
	end
	opts = type(opts) == "table" and opts or {}
	alpha = tonumber(alpha) or 1
	local vertexColor = opts.vertexColor
	if type(vertexColor) ~= "table" and GF.GetListBackgroundColor then
		vertexColor = GF.GetListBackgroundColor(state)
	end
	if type(vertexColor) == "table" then
		if atlasApplied and piece.SetDesaturated then
			local desaturated = opts.desaturated
			if desaturated == nil then
				desaturated = state ~= nil and state ~= "normal"
			end
			piece:SetDesaturated(desaturated == true)
		elseif piece.SetDesaturated then
			piece:SetDesaturated(false)
		end
		piece:SetVertexColor(vertexColor[1] or 1, vertexColor[2] or 1, vertexColor[3] or 1, vertexColor[4] or 1)
	elseif atlasApplied and state and state ~= "normal" then
		local color = ROW_BACKGROUND_STATE_COLORS[state]
		if color then
			if piece.SetDesaturated then
				piece:SetDesaturated(true)
			end
			piece:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
		else
			if piece.SetDesaturated then
				piece:SetDesaturated(false)
			end
			piece:SetVertexColor(1, 1, 1, 1)
		end
	else
		if piece.SetDesaturated then
			piece:SetDesaturated(false)
		end
		piece:SetVertexColor(1, 1, 1, 1)
	end
	piece:SetAlpha(alpha)
end

local function resolveRowBackgroundLayout(row, opts, metrics)
	opts = type(opts) == "table" and opts or {}
	metrics = metrics or getRowBackgroundMetrics(opts)
	local rowH = row and row.GetHeight and row:GetHeight() or 0
	if rowH <= 0 then
		rowH = tonumber(opts and opts.defaultHeight) or GF.LIST_ROW_H_DEFAULT or GF.LIST_ROW_H or 32
	end
	local insetTop = tonumber(opts.insetTop) or 0
	local insetBottom = tonumber(opts.insetBottom) or 0
	local pixelAligned = getRowBackgroundOption(
		opts,
		metrics.profile,
		"pixelAligned",
		false) == true
	if pixelAligned then
		rowH = math.max(1, math.floor(rowH + 0.5))
		insetTop = math.max(0, math.floor(insetTop + 0.5))
		insetBottom = math.max(0, math.floor(insetBottom + 0.5))
		local maxInsetTotal = math.max(0, rowH - 1)
		if insetTop + insetBottom > maxInsetTotal then
			insetBottom = math.max(0, maxInsetTotal - insetTop)
			insetTop = math.min(insetTop, maxInsetTotal)
		end
	end
	local availableH = math.max(1, rowH - insetTop - insetBottom)
	local maxDisplayHeight = getRowBackgroundOption(
		opts,
		metrics.profile,
		"maxDisplayHeight",
		nil)
	if maxDisplayHeight == false then
		maxDisplayHeight = nil
	else
		maxDisplayHeight = tonumber(maxDisplayHeight)
	end
	local displayH = maxDisplayHeight and math.min(availableH, maxDisplayHeight)
		or availableH
	if pixelAligned then
		displayH = math.max(1, math.floor(displayH + 0.5))
	end
	local extraH = math.max(0, availableH - displayH)
	local verticalAlign = tostring(getRowBackgroundOption(
		opts,
		metrics.profile,
		"verticalAlign",
		"CENTER")):upper()
	local extraTop
	local extraBottom
	if verticalAlign == "TOP" then
		extraTop = 0
		extraBottom = extraH
	elseif verticalAlign == "BOTTOM" then
		extraTop = extraH
		extraBottom = 0
	elseif pixelAligned then
		extraTop = math.floor(extraH / 2)
		extraBottom = extraH - extraTop
		local oddPixelBias = tostring(getRowBackgroundOption(
			opts,
			metrics.profile,
			"oddPixelBias",
			"UP")):upper()
		if oddPixelBias == "DOWN" and extraTop ~= extraBottom then
			extraTop, extraBottom = extraBottom, extraTop
		end
	else
		extraTop = extraH / 2
		extraBottom = extraH - extraTop
	end
	return {
		displayHeight = displayH,
		insetTop = insetTop + extraTop,
		insetBottom = insetBottom + extraBottom,
		insetLeft = tonumber(opts.insetLeft) or 0,
		insetRight = tonumber(opts.insetRight)
			or tonumber(opts.insetLeft)
			or 0,
	}
end

local function getRowBackgroundDisplayHeights(layout, metrics)
	local displayH = layout.displayHeight
	local visibleTopHeight = math.max(
		0,
		metrics.splitPixels - metrics.visibleTopPixels)
	local topH = math.floor(
		(displayH * visibleTopHeight / metrics.effectiveSourceHeight)
		+ 0.5)
	if displayH > 1 then
		topH = math.max(1, math.min(displayH - 1, topH))
	else
		topH = 1
	end
	local bottomH = math.max(0, displayH - topH)
	return displayH, topH, bottomH
end

local function getRowBackgroundCapWidth(layout, metrics)
	return math.max(
		1,
		math.floor(
			(layout.displayHeight
				* metrics.sourceCapWidth
				/ metrics.effectiveSourceHeight)
			+ 0.5))
end

local function layoutRowBackgroundPiece(row, pieces, piece, key, height, texLeft, texRight, texTop, texBottom, verticalMode, opts, layout, metrics)
	if not (row and pieces and piece) then
		return
	end
	local insetLeft = layout.insetLeft
	local insetRight = layout.insetRight
	local insetTop = layout.insetTop
	local insetBottom = layout.insetBottom
	local capWidth = getRowBackgroundCapWidth(layout, metrics)
	piece:ClearAllPoints()
	if key == "left" then
		piece:SetPoint(verticalMode == "bottom" and "BOTTOMLEFT" or "TOPLEFT", row, verticalMode == "bottom" and "BOTTOMLEFT" or "TOPLEFT", insetLeft, verticalMode == "bottom" and insetBottom or -insetTop)
		piece:SetSize(capWidth, height)
	elseif key == "right" then
		piece:SetPoint(verticalMode == "bottom" and "BOTTOMRIGHT" or "TOPRIGHT", row, verticalMode == "bottom" and "BOTTOMRIGHT" or "TOPRIGHT", -insetRight, verticalMode == "bottom" and insetBottom or -insetTop)
		piece:SetSize(capWidth, height)
	else
		piece:SetPoint("LEFT", pieces.left, "RIGHT", 0, 0)
		piece:SetPoint("RIGHT", pieces.right, "LEFT", 0, 0)
		if verticalMode == "bottom" then
			piece:SetPoint("BOTTOM", row, "BOTTOM", 0, insetBottom)
		else
			piece:SetPoint("TOP", row, "TOP", 0, -insetTop)
		end
		piece:SetHeight(height)
	end
	local atlasApplied = setRowBackgroundPieceCoords(piece, texLeft, texRight, texTop, texBottom, opts)
	applyRowBackgroundTint(piece, opts and opts.state or "normal", opts and opts.alpha or 1, atlasApplied, opts)
	piece:Show()
end

function GF.UI.ApplyRowBackgroundPieces(row, pieces, opts)
	if not pieces then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	local mode = opts.mode or "full"
	if mode == "hidden" then
		setRowBackgroundPiecesShown(pieces, false)
		return true
	end
	local metrics = getRowBackgroundMetrics(opts)
	local layout = resolveRowBackgroundLayout(row, opts, metrics)
	local leftTexCoord = metrics.sourceCapWidth / metrics.sourceWidth
	local rightTexCoord = 1 - leftTexCoord
	local visibleTexTop = metrics.visibleTopPixels / metrics.sourceHeight
	local visibleTexBottom = metrics.visibleBottomPixels / metrics.sourceHeight
	local splitTexCoord = metrics.splitPixels / metrics.sourceHeight
	local displayH, topH, bottomH = getRowBackgroundDisplayHeights(
		layout,
		metrics)
	if mode == "top" then
		layoutRowBackgroundPiece(row, pieces, pieces.left, "left", topH, 0, leftTexCoord, visibleTexTop, splitTexCoord, "top", opts, layout, metrics)
		layoutRowBackgroundPiece(row, pieces, pieces.middle, "middle", topH, leftTexCoord, rightTexCoord, visibleTexTop, splitTexCoord, "top", opts, layout, metrics)
		layoutRowBackgroundPiece(row, pieces, pieces.right, "right", topH, rightTexCoord, 1, visibleTexTop, splitTexCoord, "top", opts, layout, metrics)
		return true
	end
	if mode == "bottom" then
		layoutRowBackgroundPiece(row, pieces, pieces.left, "left", bottomH, 0, leftTexCoord, splitTexCoord, visibleTexBottom, "bottom", opts, layout, metrics)
		layoutRowBackgroundPiece(row, pieces, pieces.middle, "middle", bottomH, leftTexCoord, rightTexCoord, splitTexCoord, visibleTexBottom, "bottom", opts, layout, metrics)
		layoutRowBackgroundPiece(row, pieces, pieces.right, "right", bottomH, rightTexCoord, 1, splitTexCoord, visibleTexBottom, "bottom", opts, layout, metrics)
		return true
	end
	layoutRowBackgroundPiece(row, pieces, pieces.left, "left", displayH, 0, leftTexCoord, visibleTexTop, visibleTexBottom, "top", opts, layout, metrics)
	layoutRowBackgroundPiece(row, pieces, pieces.middle, "middle", displayH, leftTexCoord, rightTexCoord, visibleTexTop, visibleTexBottom, "top", opts, layout, metrics)
	layoutRowBackgroundPiece(row, pieces, pieces.right, "right", displayH, rightTexCoord, 1, visibleTexTop, visibleTexBottom, "top", opts, layout, metrics)
	return true
end
