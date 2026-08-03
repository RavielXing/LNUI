local _, GF = ...

GF.UI = GF.UI or {}

GF.UI.TOOLTIP_GOLD_R = 1
GF.UI.TOOLTIP_GOLD_G = 0.82
GF.UI.TOOLTIP_GOLD_B = 0

local WHITE = GF.WHITE_TEXTURE
local COMMON_BUTTON_PATH = GF.COMMON_BUTTON_TEXTURE
local BUTTON_VISUAL_STATE = GF.BUTTON_VISUAL_STATE
local FILTER_CHECK_ATLAS_STATES = GF.FILTER_CHECK_ATLAS_STATES
local FILTER_CHECK_ATLAS_TEXTURE = GF.FILTER_CHECK_ATLAS_TEXTURE
local FILTER_CHECK_ATLAS_WIDTH = GF.FILTER_CHECK_ATLAS_WIDTH or 128
local FILTER_CHECK_ATLAS_HEIGHT = GF.FILTER_CHECK_ATLAS_HEIGHT or 64
local FILTER_CHECK_ATLAS_REGIONS = GF.FILTER_CHECK_ATLAS_REGIONS or {}
local FILTER_CHECK_ATLAS_COORDS = GF.FILTER_CHECK_ATLAS_COORDS or {}
local FILTER_INPUT_SLICE_RATIOS = GF.FILTER_INPUT_SLICE_RATIOS
	or { 0.45, 0.55 }
local FILTER_DISABLED_ICON_TINT = GF.FILTER_DISABLED_ICON_TINT or 0.58
local OPTIONS_TAB_ATLASES = {
	up = {
		left = "Options_Tab_Left",
		middle = "Options_Tab_Middle",
		right = "Options_Tab_Right",
	},
	selected = {
		left = "Options_Tab_Active_Left",
		middle = "Options_Tab_Active_Middle",
		right = "Options_Tab_Active_Right",
	},
}

local function paint(texture, r, g, b, a)
	if not texture then
		return
	end
	if texture.SetColorTexture then
		texture:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
	else
		texture:SetTexture(WHITE)
		texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	end
end

function GF.UI.GetPixelTextureCoords(region, atlasWidth, atlasHeight)
	if type(region) ~= "table" then
		return nil
	end
	atlasWidth = tonumber(atlasWidth)
	atlasHeight = tonumber(atlasHeight)
	if not (atlasWidth and atlasWidth > 0 and atlasHeight and atlasHeight > 0) then
		return nil
	end
	local x = tonumber(region[1]) or 0
	local y = tonumber(region[2]) or 0
	local width = tonumber(region[3]) or 0
	local height = tonumber(region[4]) or 0
	return x / atlasWidth,
		(x + width) / atlasWidth,
		y / atlasHeight,
		(y + height) / atlasHeight
end

function GF.UI.SetPixelTextureRegion(texture, texturePath, region, atlasWidth, atlasHeight)
	if not (texture and texturePath) then
		return false
	end
	local left, right, top, bottom = GF.UI.GetPixelTextureCoords(
		region,
		atlasWidth,
		atlasHeight)
	if not left then
		return false
	end
	texture:SetTexture(texturePath)
	texture:SetTexCoord(left, right, top, bottom)
	return true
end

local CONTROL_FRAME_BORDER_PIECES = {
	"topLeft",
	"top",
	"topRight",
	"left",
	"right",
	"bottomLeft",
	"bottom",
	"bottomRight",
}

local FILTER_INPUT_PIECES = {
	"left",
	"middle",
	"right",
}

local NATIVE_ATLAS_INFO_CACHE = {}

local function getAtlasRawSize(info)
	local rawSize = info and info.rawSize
	if rawSize and type(rawSize.GetXY) == "function" then
		local ok, width, height = pcall(rawSize.GetXY, rawSize)
		if ok and tonumber(width) and tonumber(height) then
			return tonumber(width), tonumber(height)
		end
	end
	local width = tonumber(rawSize and rawSize.x)
	local height = tonumber(rawSize and rawSize.y)
	return width, height
end

local function getNativeAtlasInfo(atlasName)
	if type(atlasName) ~= "string" or atlasName == "" then
		return nil
	end
	local cached = NATIVE_ATLAS_INFO_CACHE[atlasName]
	if cached then
		return cached
	end
	if not (C_Texture and C_Texture.GetAtlasInfo) then
		return nil
	end
	local ok, info = pcall(C_Texture.GetAtlasInfo, atlasName)
	if not (ok and type(info) == "table") then
		return nil
	end
	local left = tonumber(info.leftTexCoord)
	local right = tonumber(info.rightTexCoord)
	local top = tonumber(info.topTexCoord)
	local bottom = tonumber(info.bottomTexCoord)
	local logicalWidth = tonumber(info.width)
	local logicalHeight = tonumber(info.height)
	local texture = info.file or info.filename
	if not (
		texture
		and logicalWidth and logicalWidth > 0
		and logicalHeight and logicalHeight > 0
		and left and left >= 0
		and right and right <= 1 and right > left
		and top and top >= 0
		and bottom and bottom <= 1 and bottom > top
	) then
		return nil
	end
	local rawWidth, rawHeight = getAtlasRawSize(info)
	rawWidth = tonumber(rawWidth)
	rawHeight = tonumber(rawHeight)
	if not (rawWidth and rawWidth > 0 and rawHeight and rawHeight > 0) then
		return nil
	end
	cached = {
		name = atlasName,
		texture = texture,
		file = info.file,
		filename = info.filename,
		left = left,
		right = right,
		top = top,
		bottom = bottom,
		rawWidth = rawWidth,
		rawHeight = rawHeight,
		logicalWidth = logicalWidth,
		logicalHeight = logicalHeight,
	}
	NATIVE_ATLAS_INFO_CACHE[atlasName] = cached
	return cached
end

local function trySetNativeAtlasTexture(texture, atlasInfo)
	local function tryAsset(asset)
		if not asset then
			return false
		end
		local ok, result = pcall(texture.SetTexture, texture, asset)
		return ok == true and result ~= false
	end
	return tryAsset(atlasInfo and atlasInfo.file)
		or tryAsset(atlasInfo and atlasInfo.filename)
		or tryAsset(atlasInfo and atlasInfo.texture)
end

local function setNativeAtlasAbsoluteRegion(
	texture,
	atlasInfo,
	left,
	right,
	top,
	bottom
)
	if not (texture and atlasInfo) then
		return false
	end
	left = math.max(0, math.min(1, tonumber(left) or 0))
	right = math.max(0, math.min(1, tonumber(right) or 1))
	top = math.max(0, math.min(1, tonumber(top) or 0))
	bottom = math.max(0, math.min(1, tonumber(bottom) or 1))
	if right <= left or bottom <= top then
		return false
	end
	if not trySetNativeAtlasTexture(texture, atlasInfo) then
		return false
	end
	local atlasWidth = atlasInfo.right - atlasInfo.left
	local atlasHeight = atlasInfo.bottom - atlasInfo.top
	texture:SetTexCoord(
		atlasInfo.left + atlasWidth * left,
		atlasInfo.left + atlasWidth * right,
		atlasInfo.top + atlasHeight * top,
		atlasInfo.top + atlasHeight * bottom
	)
	return true
end

local function setNativeAtlasPieceRegion(
	texture,
	atlasInfo,
	left,
	right,
	top,
	bottom,
	continuousInternalUV,
	halfTexelInset
)
	if not (texture and atlasInfo) then
		return false
	end
	left = math.max(0, math.min(1, tonumber(left) or 0))
	right = math.max(0, math.min(1, tonumber(right) or 1))
	top = math.max(0, math.min(1, tonumber(top) or 0))
	bottom = math.max(0, math.min(1, tonumber(bottom) or 1))
	if right <= left or bottom <= top then
		return false
	end
	if halfTexelInset == false then
		return setNativeAtlasAbsoluteRegion(
			texture,
			atlasInfo,
			left,
			right,
			top,
			bottom
		)
	end
	-- Default to the 2.0.1 per-piece half-texel guard. Callers that own a
	-- continuous virtual slice may opt into shared internal UV boundaries.
	local halfU = math.min(
		0.5 / atlasInfo.rawWidth,
		(right - left) * 0.25
	)
	local halfV = math.min(
		0.5 / atlasInfo.rawHeight,
		(bottom - top) * 0.25
	)
	local insetLeft = halfU
	local insetRight = halfU
	local insetTop = halfV
	local insetBottom = halfV
	if continuousInternalUV == true then
		insetLeft = left == 0 and halfU or 0
		insetRight = right == 1 and halfU or 0
		insetTop = top == 0 and halfV or 0
		insetBottom = bottom == 1 and halfV or 0
	end
	return setNativeAtlasAbsoluteRegion(
		texture,
		atlasInfo,
		left + insetLeft,
		right - insetRight,
		top + insetTop,
		bottom - insetBottom
	)
end

local function setNativeAtlasSampling(texture, snapToPixelGrid)
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(snapToPixelGrid ~= false)
	end
	if texture.SetTexelSnappingBias then
		texture:SetTexelSnappingBias(0)
	end
end

local function createControlFrameBorderPieces(frame, layer, subLevel)
	local pieces = {}
	for _, key in ipairs(CONTROL_FRAME_BORDER_PIECES) do
		local texture = frame:CreateTexture(
			nil,
			layer or "BORDER",
			nil,
			subLevel or 0
		)
		setNativeAtlasSampling(texture, true)
		pieces[key] = texture
	end
	frame._gfControlFrameBorder = pieces
	return pieces
end

local function resolveControlFrameSliceRatios(opts, state)
	local states = opts.sliceRatios or GF.CONTROL_FRAME_SLICE_RATIOS
	if type(states) ~= "table" then
		return nil
	end
	local ratios = states.left and states
		or states[state]
		or (state ~= "normal" and states.highlighted)
		or states.normal
	if type(ratios) ~= "table" then
		return nil
	end
	local left = tonumber(ratios.left)
	local right = tonumber(ratios.right)
	local top = tonumber(ratios.top)
	local bottom = tonumber(ratios.bottom)
	if not (
		left and right and left > 0 and right < 1 and left < right
		and top and bottom and top > 0 and bottom < 1 and top < bottom
	) then
		return nil
	end
	return {
		left = left,
		right = right,
		top = top,
		bottom = bottom,
	}
end

local function resolveControlFrameDisplayMargins(opts)
	local configured = opts.displayMargins
		or opts.displayMargin
		or GF.CONTROL_FRAME_DISPLAY_MARGIN
		or 8
	local function margin(key, index)
		local value = type(configured) == "table"
			and (configured[key] or configured[index])
			or configured
		return math.max(1, tonumber(value) or 8)
	end
	return {
		left = margin("left", 1),
		top = margin("top", 2),
		right = margin("right", 3),
		bottom = margin("bottom", 4),
	}
end

local function resolveControlFrameSourceBounds(opts, atlasInfo, ratios)
	local configured = opts.sourceCrop
	local function crop(key, index, logicalSize, maximum)
		local value = type(configured) == "table"
			and (configured[key] or configured[index])
			or configured
		value = math.max(0, tonumber(value) or 0)
		local ratio = logicalSize and logicalSize > 0
			and (value / logicalSize)
			or 0
		return math.min(ratio, math.max(0, maximum - 1e-6))
	end
	return {
		left = crop("left", 1, atlasInfo.logicalWidth, ratios.left),
		top = crop("top", 2, atlasInfo.logicalHeight, ratios.top),
		right = 1 - crop(
			"right",
			3,
			atlasInfo.logicalWidth,
			1 - ratios.right
		),
		bottom = 1 - crop(
			"bottom",
			4,
			atlasInfo.logicalHeight,
			1 - ratios.bottom
		),
	}
end

function GF.UI.ApplyControlFrameBorder(frame, opts)
	if not frame then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	local states = opts.atlasStates or GF.CONTROL_FRAME_ATLAS_STATES
	local state = opts.state or "normal"
	local atlasName = opts.atlas
		or (type(states) == "table" and (states[state] or states.normal))
	local atlasInfo = type(opts.atlasInfo) == "table"
		and opts.atlasInfo
		or getNativeAtlasInfo(atlasName)
	local ratios = resolveControlFrameSliceRatios(opts, state)
	if not (atlasInfo and ratios) then
		local existing = frame._gfControlFrameBorder
		if existing then
			for _, key in ipairs(CONTROL_FRAME_BORDER_PIECES) do
				if existing[key] then
					existing[key]:SetTexture(nil)
					existing[key]:Hide()
				end
			end
		end
		return false
	end
	local displayMargins = resolveControlFrameDisplayMargins(opts)
	local sourceBounds = resolveControlFrameSourceBounds(
		opts,
		atlasInfo,
		ratios
	)
	local layer = opts.layer or "BORDER"
	local subLevel = tonumber(opts.subLevel) or 0
	local pieces = frame._gfControlFrameBorder
		or createControlFrameBorderPieces(frame, layer, subLevel)

	for _, key in ipairs(CONTROL_FRAME_BORDER_PIECES) do
		local texture = pieces[key]
		texture:SetDrawLayer(layer, subLevel)
		setNativeAtlasSampling(texture, opts.snapToPixelGrid)
	end

	local regions = {
		topLeft = {
			sourceBounds.left,
			ratios.left,
			sourceBounds.top,
			ratios.top,
		},
		top = {
			ratios.left,
			ratios.right,
			sourceBounds.top,
			ratios.top,
		},
		topRight = {
			ratios.right,
			sourceBounds.right,
			sourceBounds.top,
			ratios.top,
		},
		left = {
			sourceBounds.left,
			ratios.left,
			ratios.top,
			ratios.bottom,
		},
		right = {
			ratios.right,
			sourceBounds.right,
			ratios.top,
			ratios.bottom,
		},
		bottomLeft = {
			sourceBounds.left,
			ratios.left,
			ratios.bottom,
			sourceBounds.bottom,
		},
		bottom = {
			ratios.left,
			ratios.right,
			ratios.bottom,
			sourceBounds.bottom,
		},
		bottomRight = {
			ratios.right,
			sourceBounds.right,
			ratios.bottom,
			sourceBounds.bottom,
		},
	}
	local atlasApplied = true
	for _, key in ipairs(CONTROL_FRAME_BORDER_PIECES) do
		local region = regions[key]
		atlasApplied = setNativeAtlasPieceRegion(
			pieces[key],
			atlasInfo,
			region[1],
			region[2],
			region[3],
			region[4],
			opts.continuousInternalUV,
			opts.halfTexelInset
		) and atlasApplied
	end
	if not atlasApplied then
		for _, key in ipairs(CONTROL_FRAME_BORDER_PIECES) do
			pieces[key]:SetTexture(nil)
			pieces[key]:Hide()
		end
		return false
	end

	pieces.topLeft:ClearAllPoints()
	pieces.topLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	pieces.topLeft:SetSize(displayMargins.left, displayMargins.top)
	pieces.topRight:ClearAllPoints()
	pieces.topRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	pieces.topRight:SetSize(displayMargins.right, displayMargins.top)
	pieces.bottomLeft:ClearAllPoints()
	pieces.bottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	pieces.bottomLeft:SetSize(displayMargins.left, displayMargins.bottom)
	pieces.bottomRight:ClearAllPoints()
	pieces.bottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	pieces.bottomRight:SetSize(displayMargins.right, displayMargins.bottom)

	pieces.top:ClearAllPoints()
	pieces.top:SetPoint("TOPLEFT", pieces.topLeft, "TOPRIGHT", 0, 0)
	pieces.top:SetPoint("BOTTOMRIGHT", pieces.topRight, "BOTTOMLEFT", 0, 0)
	pieces.bottom:ClearAllPoints()
	pieces.bottom:SetPoint(
		"TOPLEFT",
		pieces.bottomLeft,
		"TOPRIGHT",
		0,
		0
	)
	pieces.bottom:SetPoint(
		"BOTTOMRIGHT",
		pieces.bottomRight,
		"BOTTOMLEFT",
		0,
		0
	)
	pieces.left:ClearAllPoints()
	pieces.left:SetPoint("TOPLEFT", pieces.topLeft, "BOTTOMLEFT", 0, 0)
	pieces.left:SetPoint(
		"BOTTOMRIGHT",
		pieces.bottomLeft,
		"TOPRIGHT",
		0,
		0
	)
	pieces.right:ClearAllPoints()
	pieces.right:SetPoint(
		"TOPLEFT",
		pieces.topRight,
		"BOTTOMLEFT",
		0,
		0
	)
	pieces.right:SetPoint(
		"BOTTOMRIGHT",
		pieces.bottomRight,
		"TOPRIGHT",
		0,
		0
	)

	local color = type(opts.color) == "table" and opts.color or nil
	local red = tonumber(color and color[1]) or 1
	local green = tonumber(color and color[2]) or 1
	local blue = tonumber(color and color[3]) or 1
	local alpha = tonumber(color and color[4])
		or tonumber(opts.alpha)
		or 1
	for _, key in ipairs(CONTROL_FRAME_BORDER_PIECES) do
		pieces[key]:SetVertexColor(red, green, blue, alpha)
		pieces[key]:SetShown(opts.shown ~= false)
	end
	pieces.state = state
	pieces.atlas = atlasName
	pieces.atlasInfo = atlasInfo
	pieces.localTexture = opts.localTexture == true
	pieces.sliceRatios = ratios
	pieces.sourceBounds = sourceBounds
	pieces.displayMargins = displayMargins
	pieces.displayMargin = displayMargins.left == displayMargins.top
		and displayMargins.left == displayMargins.right
		and displayMargins.left == displayMargins.bottom
		and displayMargins.left
		or nil
	return pieces
end

function GF.UI.SetControlFrameBorderShown(frame, shown)
	local pieces = frame and frame._gfControlFrameBorder
	if not pieces then
		return false
	end
	for _, key in ipairs(CONTROL_FRAME_BORDER_PIECES) do
		pieces[key]:SetShown(shown == true)
	end
	return true
end

function GF.UI.ApplyControlCardChrome(frame, opts)
	if not frame then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	local existingChrome = frame._gfControlCardChrome
	if existingChrome then
		-- Clear the public references up front as well. If the requested native
		-- atlas is unavailable, a later SetControlCardChromeShown(true) must not
		-- expose the hidden renderer that this call just replaced.
		for _, key in ipairs(FILTER_INPUT_PIECES) do
			local texture = existingChrome.inputPieces
				and existingChrome.inputPieces[key]
			if texture then
				texture:SetTexture(nil)
				texture:Hide()
			end
		end
		if existingChrome.squareTexture then
			existingChrome.squareTexture:SetTexture(nil)
			existingChrome.squareTexture:Hide()
		end
		existingChrome.border = nil
		existingChrome.center = nil
		existingChrome.inputPieces = nil
		existingChrome.squareTexture = nil
		existingChrome.state = nil
		existingChrome.pixel = false
		existingChrome.localTexture = false
		existingChrome.input = false
		existingChrome.square = false
		existingChrome.centerAtlasApplied = false
		existingChrome.shown = false
	end
	local border = GF.UI.ApplyControlFrameBorder(frame, opts)
	if not border then
		local existingCenter = frame._gfControlCardCenter
		if existingCenter then
			existingCenter:SetTexture(nil)
			existingCenter:Hide()
		end
		return false
	end

	local ratios = border.sliceRatios
	if not ratios then
		GF.UI.SetControlFrameBorderShown(frame, false)
		return false
	end

	local center = frame._gfControlCardCenter
	if not center then
		center = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
		frame._gfControlCardCenter = center
	end
	setNativeAtlasSampling(center, opts.snapToPixelGrid)
	center:SetDrawLayer(
		opts.centerLayer or "BACKGROUND",
		tonumber(opts.centerSubLevel) or -7
	)
	local centerApplied = setNativeAtlasPieceRegion(
		center,
		border.atlasInfo,
		ratios.left,
		ratios.right,
		ratios.top,
		ratios.bottom,
		opts.continuousInternalUV,
		opts.halfTexelInset
	)
	if not centerApplied then
		GF.UI.SetControlFrameBorderShown(frame, false)
		center:SetTexture(nil)
		center:Hide()
		return false
	end
	center:ClearAllPoints()
	center:SetPoint("TOPLEFT", border.topLeft, "BOTTOMRIGHT", 0, 0)
	center:SetPoint(
		"BOTTOMRIGHT",
		border.bottomRight,
		"TOPLEFT",
		0,
		0
	)

	local color = type(opts.centerColor) == "table"
		and opts.centerColor
		or (type(opts.color) == "table" and opts.color or nil)
	center:SetVertexColor(
		tonumber(color and color[1]) or 1,
		tonumber(color and color[2]) or 1,
		tonumber(color and color[3]) or 1,
		tonumber(color and color[4])
			or tonumber(opts.centerAlpha)
			or tonumber(opts.alpha)
			or 1
	)
	center:SetShown(opts.shown ~= false)

	local chrome = existingChrome or {}
	chrome.border = border
	chrome.center = center
	chrome.inputPieces = nil
	chrome.squareTexture = nil
	chrome.state = border.state
	chrome.pixel = false
	chrome.localTexture = opts.localTexture == true
	chrome.input = false
	chrome.square = false
	chrome.centerAtlasApplied = true
	chrome.shown = opts.shown ~= false
	frame._gfControlCardChrome = chrome
	return chrome
end

local function getFrameDimension(frame, methodName)
	local method = frame and frame[methodName]
	if type(method) ~= "function" then
		return nil
	end
	local ok, value = pcall(method, frame)
	value = ok and tonumber(value) or nil
	return value and value > 0 and value or nil
end

local function getCompactControlDimensions(frame, opts)
	local width = tonumber(opts.width)
	local height = tonumber(opts.height)
	width = width and width > 0 and width
		or getFrameDimension(frame, "GetWidth")
	height = height and height > 0 and height
		or getFrameDimension(frame, "GetHeight")
	return width, height
end

local function usesFilterCheckTexture(atlasStates)
	return atlasStates == GF.COMPACT_CONTROL_ATLAS_STATES
		or atlasStates == GF.FILTER_CHECK_ATLAS_STATES
		or atlasStates == GF.FILTER_INPUT_ATLAS_STATES
end

local FILTER_CHECK_ATLAS_INFO_CACHE = {}

local function getFilterCheckAtlasInfo(regionKey)
	regionKey = type(regionKey) == "string" and regionKey or "normal"
	local cached = FILTER_CHECK_ATLAS_INFO_CACHE[regionKey]
	if cached then
		return cached
	end
	local region = FILTER_CHECK_ATLAS_REGIONS[regionKey]
	local x = tonumber(region and region[1])
	local y = tonumber(region and region[2])
	local width = tonumber(region and region[3])
	local height = tonumber(region and region[4])
	if not (
		FILTER_CHECK_ATLAS_TEXTURE
		and x and y and width and height
		and width > 0 and height > 0
		and x >= 0 and y >= 0
		and x + width <= FILTER_CHECK_ATLAS_WIDTH
		and y + height <= FILTER_CHECK_ATLAS_HEIGHT
	) then
		return nil
	end
	cached = {
		name = regionKey,
		texture = FILTER_CHECK_ATLAS_TEXTURE,
		left = x / FILTER_CHECK_ATLAS_WIDTH,
		right = (x + width) / FILTER_CHECK_ATLAS_WIDTH,
		top = y / FILTER_CHECK_ATLAS_HEIGHT,
		bottom = (y + height) / FILTER_CHECK_ATLAS_HEIGHT,
		rawWidth = width,
		rawHeight = height,
		logicalWidth = width,
		logicalHeight = height,
	}
	FILTER_CHECK_ATLAS_INFO_CACHE[regionKey] = cached
	return cached
end

local function resolveCompactControlDisplayMargins(frame, opts)
	if opts.displayMargins ~= nil or opts.displayMargin ~= nil then
		return resolveControlFrameDisplayMargins(opts)
	end
	local width, height = getCompactControlDimensions(frame, opts)
	local margin = math.max(
		1,
		tonumber(GF.FILTER_MULTILINE_INPUT_DISPLAY_MARGIN)
			or tonumber(GF.FILTER_CHECK_ATLAS_DISPLAY_MARGIN)
			or 5
	)
	if width then
		margin = math.min(margin, math.max(1, width / 2))
	end
	if height then
		margin = math.min(margin, math.max(1, height / 2))
	end
	return {
		left = margin,
		top = margin,
		right = margin,
		bottom = margin,
	}
end

function GF.UI.GetCompactControlDisplayMargins(frame, opts)
	opts = type(opts) == "table" and opts or {}
	return resolveCompactControlDisplayMargins(frame, opts)
end

function GF.UI.ApplyCompactControlChrome(frame, state, opts)
	if not frame then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	local resolvedState = state or "normal"
	local atlasStates = opts.atlasStates
		or GF.COMPACT_CONTROL_ATLAS_STATES
		or GF.FILTER_CHECK_ATLAS_STATES
	local localTexture = usesFilterCheckTexture(atlasStates)
	local atlasName = opts.atlas
		or (type(atlasStates) == "table"
			and (atlasStates[resolvedState] or atlasStates.normal))
	local atlasInfo = localTexture
		and getFilterCheckAtlasInfo(atlasName)
		or nil
	local shown = opts.shown
	local existingChrome = frame._gfControlCardChrome
	if shown == nil
		and localTexture
		and existingChrome
		and existingChrome.localTexture == true
	then
		shown = existingChrome.shown
	end
	local snapToPixelGrid = opts.snapToPixelGrid
	if snapToPixelGrid == nil then
		snapToPixelGrid = localTexture
	end
	local continuousInternalUV = opts.continuousInternalUV
	if continuousInternalUV == nil and localTexture then
		-- The local region already excludes the weak outer fringe. Each
		-- declared nine-slice piece then samples its own first/last source
		-- pixel centres so stretched corners and edges remain stable.
		continuousInternalUV = false
	end
	local halfTexelInset = opts.halfTexelInset
	if halfTexelInset == nil and localTexture then
		-- This inset belongs to the individual nine-slice pieces, not to the
		-- direct square/three-slice projection of the effective state region.
		halfTexelInset = true
	end
	return GF.UI.ApplyControlCardChrome(frame, {
		state = resolvedState,
		atlas = atlasName,
		atlasStates = atlasStates,
		atlasInfo = atlasInfo,
		localTexture = localTexture,
		sliceRatios = opts.sliceRatios or (localTexture
			and (GF.FILTER_MULTILINE_INPUT_SLICE_RATIOS
				or GF.FILTER_CHECK_ATLAS_SLICE_RATIOS)
			or GF.CONTROL_FRAME_SLICE_RATIOS),
		displayMargins = localTexture
			and resolveCompactControlDisplayMargins(frame, opts)
			or (opts.displayMargins or opts.displayMargin),
		layer = opts.layer,
		subLevel = opts.subLevel,
		centerLayer = opts.centerLayer,
		centerSubLevel = opts.centerSubLevel,
		color = opts.color,
		centerColor = opts.centerColor,
		alpha = opts.alpha,
		centerAlpha = opts.centerAlpha,
		shown = shown,
		snapToPixelGrid = snapToPixelGrid,
		continuousInternalUV = continuousInternalUV,
		halfTexelInset = halfTexelInset,
		sourceCrop = opts.sourceCrop,
	})
end

function GF.UI.SetControlCardChromeShown(frame, shown)
	local chrome = frame and frame._gfControlCardChrome
	if not chrome then
		return false
	end
	for _, key in ipairs(CONTROL_FRAME_BORDER_PIECES) do
		if chrome.border and chrome.border[key] then
			chrome.border[key]:SetShown(shown == true)
		end
	end
	if chrome.center then
		chrome.center:SetShown(shown == true)
	end
	for _, key in ipairs(FILTER_INPUT_PIECES) do
		if chrome.inputPieces and chrome.inputPieces[key] then
			chrome.inputPieces[key]:SetShown(shown == true)
		end
	end
	if chrome.squareTexture then
		chrome.squareTexture:SetShown(shown == true)
	end
	chrome.shown = shown == true
	return true
end

function GF.UI.SetControlCardChromeEnabledVisual(frame, enabled, opts)
	local chrome = frame and frame._gfControlCardChrome
	if not chrome then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	enabled = enabled == true
	local disabledTint = tonumber(opts.disabledTint)
		or FILTER_DISABLED_ICON_TINT
	local alpha = tonumber(opts.alpha) or 1
	local desaturated = opts.desaturated
	if desaturated == nil then
		desaturated = not enabled
	else
		desaturated = desaturated == true
	end
	local textureAlpha = tonumber(opts.textureAlpha)
	chrome.enabledVisual = {
		enabled = enabled,
		disabledTint = disabledTint,
		alpha = alpha,
		desaturated = desaturated,
		textureAlpha = textureAlpha,
	}
	local function apply(texture)
		if not texture then
			return
		end
		if texture.SetDesaturated then
			texture:SetDesaturated(desaturated)
		end
		if texture.SetVertexColor then
			if enabled then
				texture:SetVertexColor(1, 1, 1, alpha)
			else
				texture:SetVertexColor(
					disabledTint,
					disabledTint,
					disabledTint,
					alpha
				)
			end
		end
		if textureAlpha and texture.SetAlpha then
			texture:SetAlpha(textureAlpha)
		end
	end
	for _, key in ipairs(CONTROL_FRAME_BORDER_PIECES) do
		apply(chrome.border and chrome.border[key])
	end
	apply(chrome.center)
	for _, key in ipairs(FILTER_INPUT_PIECES) do
		apply(chrome.inputPieces and chrome.inputPieces[key])
	end
	apply(chrome.squareTexture)
	return true
end

local function resolveFilterCheckRegionKey(state, atlasStates)
	atlasStates = type(atlasStates) == "table"
		and atlasStates
		or FILTER_CHECK_ATLAS_STATES
	return atlasStates
		and (atlasStates[state] or atlasStates.normal)
		or nil
end

local function getFilterCheckTextureCoords(regionKey)
	local coords = FILTER_CHECK_ATLAS_COORDS[regionKey]
	if type(coords) == "table"
		and coords[1] and coords[2] and coords[3] and coords[4]
	then
		return coords
	end
	local info = getFilterCheckAtlasInfo(regionKey)
	if not info then
		return nil
	end
	return { info.left, info.right, info.top, info.bottom }
end

local function applyFilterCheckTextureCoords(texture, regionKey, coords)
	local atlasInfo = getFilterCheckAtlasInfo(regionKey)
	if not (
		texture
		and atlasInfo
		and type(coords) == "table"
		and trySetNativeAtlasTexture(texture, atlasInfo)
	) then
		if texture and texture.SetTexture then
			texture:SetTexture(nil)
		end
		return false
	end
	texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	return true
end

function GF.UI.SetFilterCheckTextureState(texture, state, atlasStates)
	local regionKey = resolveFilterCheckRegionKey(state, atlasStates)
	local coords = regionKey and getFilterCheckTextureCoords(regionKey)
	local applied = applyFilterCheckTextureCoords(
		texture,
		regionKey,
		coords
	)
	return applied
end

function GF.UI.ApplyFilterSquareControlChrome(frame, state, opts)
	if not frame then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	local layer = opts.layer or "BACKGROUND"
	local subLevel = tonumber(opts.subLevel) or -6
	local texture = frame._gfFilterSquareChromeTexture
	if not texture then
		texture = frame:CreateTexture(nil, layer, nil, subLevel)
		if not texture then
			return false
		end
		frame._gfFilterSquareChromeTexture = texture
	end
	texture:SetDrawLayer(layer, subLevel)
	setNativeAtlasSampling(texture, true)
	texture:ClearAllPoints()
	texture:SetAllPoints(frame)

	GF.UI.SetControlFrameBorderShown(frame, false)
	if frame._gfControlCardCenter then
		frame._gfControlCardCenter:SetTexture(nil)
		frame._gfControlCardCenter:Hide()
	end
	local existingChrome = frame._gfControlCardChrome
	if existingChrome and existingChrome.inputPieces then
		for _, key in ipairs(FILTER_INPUT_PIECES) do
			local inputTexture = existingChrome.inputPieces[key]
			if inputTexture then
				inputTexture:SetTexture(nil)
				inputTexture:Hide()
			end
		end
	end
	local shown = opts.shown
	if shown == nil and existingChrome
		and existingChrome.squareTexture == texture
	then
		shown = existingChrome.shown
	end
	if shown == nil then
		shown = true
	end
	local resolvedState = state or "normal"
	if not GF.UI.SetFilterCheckTextureState(
		texture,
		resolvedState,
		opts.atlasStates or FILTER_CHECK_ATLAS_STATES
	) then
		texture:Hide()
		return false
	end
	local color = type(opts.color) == "table" and opts.color or nil
	texture:SetVertexColor(
		tonumber(color and color[1]) or 1,
		tonumber(color and color[2]) or 1,
		tonumber(color and color[3]) or 1,
		tonumber(color and color[4]) or tonumber(opts.alpha) or 1
	)
	texture:SetShown(shown == true)

	local chrome = existingChrome or {}
	chrome.border = nil
	chrome.center = nil
	chrome.inputPieces = nil
	chrome.squareTexture = texture
	chrome.state = resolvedState
	chrome.pixel = false
	chrome.localTexture = true
	chrome.input = false
	chrome.square = true
	chrome.centerAtlasApplied = false
	chrome.shown = shown == true
	frame._gfControlCardChrome = chrome
	return chrome
end

function GF.UI.SetFilterInputTextureState(pieces, state, atlasStates)
	if not pieces then
		return false
	end
	local regionKey = resolveFilterCheckRegionKey(state, atlasStates)
	local coords = regionKey and getFilterCheckTextureCoords(regionKey)
	if not coords then
		return false
	end
	local leftRatio = tonumber(FILTER_INPUT_SLICE_RATIOS[1]) or 0.45
	local rightRatio = tonumber(FILTER_INPUT_SLICE_RATIOS[2]) or 0.55
	local sourceWidth = coords[2] - coords[1]
	local leftU = coords[1] + sourceWidth * leftRatio
	local rightU = coords[1] + sourceWidth * rightRatio
	local ranges = {
		left = { coords[1], leftU, coords[3], coords[4] },
		middle = { leftU, rightU, coords[3], coords[4] },
		right = { rightU, coords[2], coords[3], coords[4] },
	}
	local applied = true
	for _, key in ipairs(FILTER_INPUT_PIECES) do
		local texture = pieces[key]
		local range = ranges[key]
		applied = applyFilterCheckTextureCoords(
			texture,
			regionKey,
			range
		) and applied
	end
	if not applied then
		for _, key in ipairs(FILTER_INPUT_PIECES) do
			local texture = pieces[key]
			if texture then
				texture:SetTexture(nil)
				texture:Hide()
			end
		end
		return false
	end
	pieces.state = state
	pieces.region = regionKey
	return true
end

local function createFilterInputPieces(frame, layer, subLevel)
	local pieces = frame._gfFilterInputChromePieces
	if not pieces then
		pieces = {}
		for _, key in ipairs(FILTER_INPUT_PIECES) do
			local texture = frame:CreateTexture(
				nil,
				layer,
				nil,
				subLevel
			)
			if not texture then
				for _, createdKey in ipairs(FILTER_INPUT_PIECES) do
					local created = pieces[createdKey]
					if created then
						created:SetTexture(nil)
						created:Hide()
					end
				end
				return nil
			end
			setNativeAtlasSampling(texture, true)
			pieces[key] = texture
		end
		frame._gfFilterInputChromePieces = pieces
	end
	for _, key in ipairs(FILTER_INPUT_PIECES) do
		pieces[key]:SetDrawLayer(layer, subLevel)
		setNativeAtlasSampling(pieces[key], true)
	end
	return pieces
end

function GF.UI.ApplyFilterInputChrome(frame, state, opts)
	if not frame then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	local layer = opts.layer or "BACKGROUND"
	local subLevel = tonumber(opts.subLevel) or -6
	local pieces = createFilterInputPieces(frame, layer, subLevel)
	if not pieces then
		return false
	end

	-- Single-line and numeric fields use a horizontal three-slice over the
	-- measured visible-content rectangle. Internal UV boundaries stay
	-- continuous; the discarded raw-cell fringe must not be reintroduced or
	-- inset a second time here.
	GF.UI.SetControlFrameBorderShown(frame, false)
	if frame._gfControlCardCenter then
		frame._gfControlCardCenter:SetTexture(nil)
		frame._gfControlCardCenter:Hide()
	end
	local existingChrome = frame._gfControlCardChrome
	if existingChrome and existingChrome.squareTexture then
		existingChrome.squareTexture:SetTexture(nil)
		existingChrome.squareTexture:Hide()
	end
	local shown = opts.shown
	if shown == nil and existingChrome
		and existingChrome.inputPieces == pieces
	then
		shown = existingChrome.shown
	end
	if shown == nil then
		shown = true
	end

	local width = tonumber(opts.width)
		or getFrameDimension(frame, "GetWidth")
	local capWidth = math.max(
		1,
		tonumber(opts.capWidth)
			or tonumber(GF.FILTER_INPUT_CAP_W)
			or tonumber(GF.FILTER_NUMBER_INPUT_CAP_W)
			or 9
	)
	if width and width > 0 then
		capWidth = math.min(capWidth, math.max(1, width / 2))
	end
	pieces.left:ClearAllPoints()
	pieces.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	pieces.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	pieces.left:SetWidth(capWidth)
	pieces.right:ClearAllPoints()
	pieces.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	pieces.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	pieces.right:SetWidth(capWidth)
	pieces.middle:ClearAllPoints()
	pieces.middle:SetPoint("TOPLEFT", pieces.left, "TOPRIGHT", 0, 0)
	pieces.middle:SetPoint(
		"BOTTOMRIGHT",
		pieces.right,
		"BOTTOMLEFT",
		0,
		0
	)

	local resolvedState = state or "normal"
	if not GF.UI.SetFilterInputTextureState(
		pieces,
		resolvedState,
		opts.atlasStates or GF.FILTER_INPUT_ATLAS_STATES
	) then
		return false
	end
	local color = type(opts.color) == "table" and opts.color or nil
	local red = tonumber(color and color[1]) or 1
	local green = tonumber(color and color[2]) or 1
	local blue = tonumber(color and color[3]) or 1
	local alpha = tonumber(color and color[4])
		or tonumber(opts.alpha)
		or 1
	for _, key in ipairs(FILTER_INPUT_PIECES) do
		pieces[key]:SetVertexColor(red, green, blue, alpha)
		pieces[key]:SetShown(shown == true)
	end

	local chrome = existingChrome or {}
	chrome.border = nil
	chrome.center = nil
	chrome.inputPieces = pieces
	chrome.squareTexture = nil
	chrome.state = resolvedState
	chrome.pixel = false
	chrome.localTexture = true
	chrome.input = true
	chrome.square = false
	chrome.centerAtlasApplied = false
	chrome.capWidth = capWidth
	chrome.shown = shown == true
	frame._gfControlCardChrome = chrome
	return chrome
end

function GF.UI.ApplyFilterMultilineInputChrome(frame, state, opts)
	if not frame then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	return GF.UI.ApplyCompactControlChrome(frame, state, {
		atlasStates = opts.atlasStates or GF.FILTER_INPUT_ATLAS_STATES,
		sliceRatios = opts.sliceRatios
			or GF.FILTER_MULTILINE_INPUT_SLICE_RATIOS
			or GF.COMPACT_CONTROL_SLICE_RATIOS,
		displayMargins = opts.displayMargins,
		displayMargin = opts.displayMargin
			or GF.FILTER_MULTILINE_INPUT_DISPLAY_MARGIN,
		width = opts.width,
		height = opts.height,
		layer = opts.layer or "BACKGROUND",
		subLevel = tonumber(opts.subLevel) or -6,
		centerLayer = opts.centerLayer or "BACKGROUND",
		centerSubLevel = tonumber(opts.centerSubLevel) or -7,
		color = opts.color,
		centerColor = opts.centerColor,
		alpha = opts.alpha,
		centerAlpha = opts.centerAlpha,
		shown = opts.shown,
	})
end

local function createFrameWithTemplateOptions(frameType, name, parent, templates)
	for _, template in ipairs(templates or {}) do
		local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
		if ok and frame then
			return frame, template
		end
	end
	return CreateFrame(frameType, name, parent), nil
end

function GF.UI.CreateFrameWithTemplateOptions(frameType, name, parent, templates)
	return createFrameWithTemplateOptions(frameType, name, parent, templates)
end

local function trySetAtlas(texture, atlas, useAtlasSize, ...)
	if not texture or not texture.SetAtlas then
		return false
	end
	local ok, result = pcall(
		texture.SetAtlas,
		texture,
		atlas,
		useAtlasSize,
		...
	)
	return ok == true and result ~= false
end

function GF.UI.TrySetAtlas(texture, atlas, useAtlasSize, ...)
	return trySetAtlas(texture, atlas, useAtlasSize, ...)
end

function GF.UI.SetControlTextureState(texture, state, atlasStates)
	atlasStates = type(atlasStates) == "table"
		and atlasStates
		or GF.CONTROL_FRAME_ATLAS_STATES
	local atlasName = atlasStates
		and (atlasStates[state] or atlasStates.normal)
	if not atlasName or not getNativeAtlasInfo(atlasName) then
		if texture and texture.SetTexture then
			texture:SetTexture(nil)
		end
		return false
	end
	local applied = trySetAtlas(texture, atlasName, false, nil, true)
	if not applied then
		if texture and texture.SetTexture then
			texture:SetTexture(nil)
		end
		return false
	end
	if applied and texture.ClearTextureSlice then
		texture:ClearTextureSlice()
	end
	return true
end

local function unpackInsets(insets)
	if type(insets) == "number" then
		return insets, insets, insets, insets
	end
	if type(insets) ~= "table" then
		return 0, 0, 0, 0
	end
	return tonumber(insets.left or insets[1]) or 0,
		tonumber(insets.top or insets[2]) or 0,
		tonumber(insets.right or insets[3]) or 0,
		tonumber(insets.bottom or insets[4]) or 0
end

local function anchorWithinFrame(region, frame, insets)
	if not region or not frame then
		return
	end
	local left, top, right, bottom = unpackInsets(insets)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
	region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, bottom)
end

local function applyExplicitNineSlice(texture, margins)
	if not texture or type(margins) ~= "table"
		or not texture.SetTextureSliceMargins
	then
		return
	end
	local left, top, right, bottom = unpackInsets(margins)
	pcall(
		texture.SetTextureSliceMargins,
		texture,
		left,
		top,
		right,
		bottom
	)
	if texture.SetTextureSliceMode then
		local stretched = Enum
			and Enum.UITextureSliceMode
			and Enum.UITextureSliceMode.Stretched
			or 0
		pcall(texture.SetTextureSliceMode, texture, stretched)
	end
end

local function applyCardAtlas(texture, atlas, margins)
	local applied = trySetAtlas(texture, atlas, false)
	if applied then
		-- SetTextureSliceMargins 是引擎原生的九宫格渲染：四角保持
		-- atlas 原始像素尺寸，只延展四边与中心。
		applyExplicitNineSlice(texture, margins)
	end
	return applied
end

local function isMouseFocusWithin(frame)
	if not frame then
		return false
	end
	if frame.IsMouseOver and not frame:IsMouseOver() then
		return false
	end
	if GetMouseFoci then
		local foci = GetMouseFoci()
		if RegionUtil and RegionUtil.IsAnyDescendantOfOrSame then
			return RegionUtil.IsAnyDescendantOfOrSame(foci, frame)
		end
		for _, focus in ipairs(foci or {}) do
			local current = focus
			while current do
				if current == frame then
					return true
				end
				current = current.GetParent and current:GetParent()
			end
		end
		return false
	end
	return frame.IsMouseOver and frame:IsMouseOver() or false
end

local function applyStoreCardChromeState(frame, state)
	local chrome = frame and frame._gfStoreCardChrome
	if not chrome then
		return false
	end
	state = state or "normal"
	local frameAtlas = chrome.frameAtlas
	if state == "selected" then
		frameAtlas = chrome.selectedFrameAtlas
	elseif state == "hover" and not chrome.hoverOverlay then
		frameAtlas = chrome.hoverFrameAtlas
	end
	local backgroundAtlasApplied = trySetAtlas(
		chrome.background,
		chrome.backgroundAtlas,
		false
	)
	local backgroundApplied = backgroundAtlasApplied
		and chrome.maskApplied ~= false
	local frameApplied = applyCardAtlas(
		chrome.frame,
		frameAtlas,
		chrome.frameSliceMargins
	)
	local hoverApplied = true
	if chrome.hoverFrame then
		hoverApplied = applyCardAtlas(
			chrome.hoverFrame,
			chrome.hoverFrameAtlas,
			chrome.hoverFrameSliceMargins
		)
	end
	local shown = chrome.shown ~= false
	if chrome.fallback then
		chrome.fallback:SetShown(shown and not backgroundApplied)
	end
	if chrome.fallbackBorder then
		chrome.fallbackBorder:SetShown(shown and not frameApplied)
	end
	local color = chrome.backgroundColor
	chrome.background:SetVertexColor(
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		color[4] or 1
	)
	chrome.background:SetAlpha(chrome.backgroundAlpha)
	chrome.background:SetShown(shown and backgroundApplied)
	chrome.frame:SetAlpha(chrome.frameAlpha)
	chrome.frame:SetShown(shown and frameApplied)
	if chrome.hoverFrame then
		chrome.hoverFrame:SetAlpha(chrome.hoverFrameAlpha)
		chrome.hoverFrame:SetShown(
			shown
				and state == "hover"
				and chrome.hoverEnabled ~= false
				and hoverApplied
		)
	end
	chrome.state = state
	return backgroundApplied and frameApplied
end

function GF.UI.InstallStoreCardChrome(frame, opts)
	if not frame then
		return nil
	end
	if frame._gfStoreCardChrome then
		return frame._gfStoreCardChrome
	end
	opts = type(opts) == "table" and opts or {}
	local chrome = {
		backgroundAtlas = opts.backgroundAtlas
			or GF.STORE_CARD_BACKGROUND_ATLAS
			or "shop-card-bg",
		frameAtlas = opts.frameAtlas
			or GF.STORE_CARD_FRAME_ATLAS
			or "shop-card-small-frame-default",
		selectedFrameAtlas = opts.selectedFrameAtlas
			or GF.STORE_CARD_SELECTED_FRAME_ATLAS
			or "shop-card-small-frame-selected",
		hoverFrameAtlas = opts.hoverFrameAtlas
			or GF.STORE_CARD_HOVER_FRAME_ATLAS
			or "shop-card-small-frame-hover",
		backgroundAlpha = opts.backgroundAlpha
			or GF.STORE_CARD_BACKGROUND_ALPHA
			or 0.52,
		backgroundColor = opts.backgroundColor
			or GF.STORE_CARD_BACKGROUND_COLOR
			or { 0.72, 0.62, 0.42, 1 },
		frameAlpha = opts.frameAlpha or 0.95,
		hoverFrameAlpha = opts.hoverFrameAlpha or 1,
		frameSliceMargins = opts.frameSliceMargins,
		hoverFrameSliceMargins = opts.hoverFrameSliceMargins
			or opts.frameSliceMargins,
		hoverOverlay = opts.hoverOverlay == true,
		hoverEnabled = opts.enableHover == true,
		shown = opts.shown ~= false,
	}
	if frame.SetClipsChildren then
		frame:SetClipsChildren(true)
	end
	chrome.background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
	anchorWithinFrame(chrome.background, frame, opts.backgroundInsets)
	chrome.frame = frame:CreateTexture(nil, "BORDER", nil, 1)
	chrome.frame:SetAllPoints(frame)
	if chrome.hoverOverlay then
		chrome.hoverFrame = frame:CreateTexture(nil, "BORDER", nil, 2)
		anchorWithinFrame(chrome.hoverFrame, frame, opts.hoverFrameInsets)
		chrome.hoverFrame:SetBlendMode("ADD")
	end
	if frame.CreateMaskTexture then
		local mask = frame:CreateMaskTexture(nil, "BACKGROUND")
		anchorWithinFrame(mask, frame, opts.backgroundInsets)
		chrome.maskApplied = trySetAtlas(
			mask,
			opts.maskAtlas
				or GF.STORE_CARD_MASK_ATLAS
				or "shop-card-wide-mask",
			false,
			nil,
			true,
			"CLAMPTOBLACKADDITIVE",
			"CLAMPTOBLACKADDITIVE"
		)
		if chrome.maskApplied then
			chrome.background:AddMaskTexture(mask)
			chrome.mask = mask
		else
			mask:SetTexture(nil)
			mask:Hide()
		end
	else
		chrome.maskApplied = true
	end

	chrome.fallback = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	anchorWithinFrame(
		chrome.fallback,
		frame,
		opts.backgroundInsets or 2
	)
	chrome.fallback:SetColorTexture(0.07, 0.035, 0.01, 0.9)

	chrome.fallbackBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	chrome.fallbackBorder:SetAllPoints(frame)
	chrome.fallbackBorder:SetBackdrop({
		edgeFile = WHITE,
		edgeSize = 1,
	})
	chrome.fallbackBorder:SetBackdropBorderColor(0.48, 0.39, 0.22, 0.9)
	chrome.fallbackBorder:SetFrameLevel(frame:GetFrameLevel())

	frame._gfStoreCardChrome = chrome
	applyStoreCardChromeState(frame, opts.state)
	if opts.enableHover then
		if frame.EnableMouseMotion then
			frame:EnableMouseMotion(true)
		else
			frame:EnableMouse(true)
		end
		frame:HookScript("OnUpdate", function(self)
			local current = self._gfStoreCardChrome
			if not current then
				return
			end
			local hovered = current.hoverEnabled ~= false
				and isMouseFocusWithin(self)
			local nextState = hovered and "hover" or "normal"
			if nextState ~= current.state then
				applyStoreCardChromeState(self, nextState)
			end
		end)
	end
	return chrome
end

function GF.UI.SetStoreCardChromeState(frame, state)
	return applyStoreCardChromeState(frame, state)
end

function GF.UI.SetStoreCardChromeShown(frame, shown)
	local chrome = frame and frame._gfStoreCardChrome
	if not chrome then
		return
	end
	chrome.shown = shown == true
	applyStoreCardChromeState(frame, chrome.state)
end

function GF.UI.SetStoreCardChromeHoverEnabled(frame, enabled)
	local chrome = frame and frame._gfStoreCardChrome
	if not chrome then
		return
	end
	chrome.hoverEnabled = enabled == true
	if not chrome.hoverEnabled then
		applyStoreCardChromeState(frame, "normal")
	end
end

-- 列表行背景渲染见 RowBackground.lua。
-- 职业与专精图标渲染见 SpecializationIcon.lua。
local UI_SOUND_BY_KIND = {
	open = "IG_CHARACTER_INFO_OPEN",
	close = "IG_CHARACTER_INFO_CLOSE",
	tab = "IG_CHARACTER_INFO_TAB",
	check = "IG_MAINMENU_OPTION_CHECKBOX_ON",
}

function GF.UI.PlayUISound(kind)
	if not PlaySound then
		return
	end
	local key = UI_SOUND_BY_KIND[kind or ""]
	local sound = key and _G.SOUNDKIT and _G.SOUNDKIT[key]
	if sound then
		pcall(PlaySound, sound)
	end
end

local function snapCheckTexture(texture)
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

local function hideCheckButtonRegion(region)
	if not region then
		return
	end
	if region.SetTexture then
		region:SetTexture(nil)
	end
	if region.Hide then
		region:Hide()
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
end

local function hideCheckButtonChrome(cb)
	hideCheckButtonRegion(cb.GetNormalTexture and cb:GetNormalTexture())
	hideCheckButtonRegion(cb.GetPushedTexture and cb:GetPushedTexture())
	hideCheckButtonRegion(cb.GetHighlightTexture and cb:GetHighlightTexture())
	hideCheckButtonRegion(cb.GetCheckedTexture and cb:GetCheckedTexture())
	hideCheckButtonRegion(cb.GetDisabledTexture and cb:GetDisabledTexture())
	hideCheckButtonRegion(cb.GetDisabledCheckedTexture and cb:GetDisabledCheckedTexture())
end

local function updateStyledFilterCheckButton(cb)
	if not cb or not cb._gfSharedFilterCheckStyled then
		return
	end
	hideCheckButtonChrome(cb)
	local enabled = not cb.IsEnabled or cb:IsEnabled()
	local visuallyEnabled = enabled
		and cb._gfSharedFilterCheckVisualEnabled ~= false
	local checked = cb:GetChecked() == true or cb:GetChecked() == 1
	local disabledTint = tonumber(
		cb._gfSharedFilterCheckDisabledTint
	) or FILTER_DISABLED_ICON_TINT
	local disabledAlpha = tonumber(
		cb._gfSharedFilterCheckDisabledAlpha
	) or 0.45
	local visualState = "normal"
	if checked then
		visualState = "checked"
	elseif visuallyEnabled and cb._gfSharedFilterCheckHovered then
		visualState = "hover"
	end
	local atlasRequested = false
	local atlasApplied = false
	if cb._gfSharedFilterCheckAtlas then
		local atlasStates = cb._gfSharedFilterCheckAtlasStates
			or FILTER_CHECK_ATLAS_STATES
		local atlasName = type(atlasStates) == "table"
			and (atlasStates[visualState] or atlasStates.normal)
		atlasRequested = atlasName ~= nil
		local usesLocalStateCell =
			cb._gfSharedFilterCheckUsesLocalAtlas == true
		local usesControlFrameChrome =
			atlasStates == GF.CONTROL_FRAME_ATLAS_STATES
		if usesLocalStateCell then
			GF.UI.SetControlCardChromeShown(cb, false)
			atlasApplied = atlasName
				and GF.UI.SetFilterCheckTextureState
				and GF.UI.SetFilterCheckTextureState(
					cb._gfSharedFilterCheckAtlas,
					visualState,
					atlasStates
				)
			if not atlasApplied then
				cb._gfSharedFilterCheckAtlas:SetTexture(nil)
			end
			if cb._gfSharedFilterCheckAtlas.SetDesaturated then
				cb._gfSharedFilterCheckAtlas:SetDesaturated(
					not visuallyEnabled
				)
			end
			if visuallyEnabled then
				cb._gfSharedFilterCheckAtlas:SetVertexColor(1, 1, 1, 1)
			else
				cb._gfSharedFilterCheckAtlas:SetVertexColor(
					disabledTint,
					disabledTint,
					disabledTint,
					disabledAlpha
				)
			end
		elseif usesControlFrameChrome then
			cb._gfSharedFilterCheckAtlas:SetTexture(nil)
			atlasApplied = atlasName and GF.UI.ApplyCompactControlChrome
				and GF.UI.ApplyCompactControlChrome(cb, visualState, {
					atlasStates = atlasStates,
					width = cb._gfSharedFilterCheckWidth,
					height = cb._gfSharedFilterCheckHeight,
					layer = "BORDER",
					subLevel = -6,
					centerLayer = "BACKGROUND",
					centerSubLevel = -7,
				})
			if atlasApplied then
				GF.UI.SetControlCardChromeEnabledVisual(cb, visuallyEnabled, {
					disabledTint = disabledTint,
					alpha = visuallyEnabled and 1 or disabledAlpha,
				})
			end
		else
			GF.UI.SetControlCardChromeShown(cb, false)
			if cb._gfControlCardChrome then
				cb._gfControlCardChrome.localTexture = false
			end
			atlasApplied = atlasName and GF.UI.SetControlTextureState
				and GF.UI.SetControlTextureState(
					cb._gfSharedFilterCheckAtlas,
					visualState,
					atlasStates
				)
			if not atlasApplied then
				cb._gfSharedFilterCheckAtlas:SetTexture(nil)
			end
			if cb._gfSharedFilterCheckAtlas.SetDesaturated then
				cb._gfSharedFilterCheckAtlas:SetDesaturated(
					not visuallyEnabled
				)
			end
			if visuallyEnabled then
				cb._gfSharedFilterCheckAtlas:SetVertexColor(1, 1, 1, 1)
			else
				cb._gfSharedFilterCheckAtlas:SetVertexColor(
					disabledTint,
					disabledTint,
					disabledTint,
					disabledAlpha
				)
			end
		end
	end
	if cb._gfSharedFilterCheckMark then
		local showFallbackMark = atlasRequested and not atlasApplied
		cb._gfSharedFilterCheckMark:SetShown(
			checked and (
				cb._gfSharedFilterCheckShowMark ~= false
				or showFallbackMark
			)
		)
		if cb._gfSharedFilterCheckMark.SetDesaturated then
			cb._gfSharedFilterCheckMark:SetDesaturated(
				not visuallyEnabled
			)
		end
		if visuallyEnabled then
			cb._gfSharedFilterCheckMark:SetVertexColor(1, 0.86, 0.28, 1)
		else
			cb._gfSharedFilterCheckMark:SetVertexColor(
				disabledTint,
				disabledTint,
				disabledTint,
				disabledAlpha
			)
		end
	end
	if cb._gfSharedFilterCheckUpdateLabel then
		cb._gfSharedFilterCheckUpdateLabel(
			cb._gfSharedFilterCheckLabel,
			checked,
			visuallyEnabled,
			cb
		)
	end
end

function GF.UI.UpdateFilterCheckButton(cb)
	updateStyledFilterCheckButton(cb)
end

function GF.UI.SetFilterCheckButtonHovered(cb, hovered)
	if not cb then
		return
	end
	cb._gfSharedFilterCheckHovered = hovered and true or false
	updateStyledFilterCheckButton(cb)
end

function GF.UI.SetFilterCheckButtonVisualEnabled(cb, enabled)
	if not cb then
		return
	end
	cb._gfSharedFilterCheckVisualEnabled = enabled ~= false
	updateStyledFilterCheckButton(cb)
end

local function syncStyledFilterCheckButtonHover(cb)
	if not cb then
		return
	end
	local enabled = not cb.IsEnabled or cb:IsEnabled()
	local hovered = enabled
		and cb.IsMouseMotionFocus
		and cb:IsMouseMotionFocus() == true
	cb._gfSharedFilterCheckHovered = hovered and true or false
	updateStyledFilterCheckButton(cb)
end

local function clearStyledFilterCheckButtonHover(cb)
	if not cb then
		return
	end
	cb._gfSharedFilterCheckHovered = false
	updateStyledFilterCheckButton(cb)
end

local function layoutStyledFilterCheckButton(cb, width, height, markSize)
	local atlas = cb and cb._gfSharedFilterCheckAtlas
	if atlas then
		atlas:ClearAllPoints()
		atlas:SetSize(
			tonumber(cb._gfSharedFilterCheckAtlasWidth) or width,
			tonumber(cb._gfSharedFilterCheckAtlasHeight) or height
		)
		atlas:SetPoint(
			"CENTER",
			cb,
			"CENTER",
			tonumber(cb._gfSharedFilterCheckAtlasOffsetX) or 0,
			tonumber(cb._gfSharedFilterCheckAtlasOffsetY) or 0
		)
	end
	local mark = cb and cb._gfSharedFilterCheckMark
	if mark then
		mark:ClearAllPoints()
		mark:SetSize(markSize, markSize)
		mark:SetPoint(
			"CENTER",
			cb,
			"CENTER",
			tonumber(cb._gfSharedFilterCheckMarkOffsetX) or 0,
			tonumber(cb._gfSharedFilterCheckMarkOffsetY) or 0
		)
	end
end

function GF.UI.StyleFilterCheckButton(cb, opts)
	if not cb then
		return cb
	end
	opts = opts or {}
	local size = opts.size or 20
	local width = opts.width or size
	local height = opts.height or size
	local markSize = opts.markSize or 16
	cb:SetSize(width, height)
	if cb.SetHitRectInsets then
		cb:SetHitRectInsets(0, 0, 0, 0)
	end
	hideCheckButtonChrome(cb)
	if not cb._gfSharedFilterCheckStyled then
		local atlas = cb:CreateTexture(nil, "BORDER", nil, -6)
		atlas:SetAllPoints(cb)
		snapCheckTexture(atlas)
		cb._gfSharedFilterCheckAtlas = atlas

		local mark = cb:CreateTexture(nil, "ARTWORK")
		mark:SetPoint("CENTER", cb, "CENTER", 0, 0)
		mark:SetSize(markSize, markSize)
		mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		snapCheckTexture(mark)
		cb._gfSharedFilterCheckMark = mark

		cb._gfSharedFilterOrigSetChecked = cb.SetChecked
		cb.SetChecked = function(self, checked, ...)
			self:_gfSharedFilterOrigSetChecked(checked, ...)
			updateStyledFilterCheckButton(self)
		end
		cb:HookScript("OnClick", updateStyledFilterCheckButton)
		cb:HookScript("OnShow", syncStyledFilterCheckButtonHover)
		cb:HookScript("OnHide", clearStyledFilterCheckButtonHover)
		cb:HookScript("OnEnable", syncStyledFilterCheckButtonHover)
		cb:HookScript("OnDisable", clearStyledFilterCheckButtonHover)
		cb:HookScript("OnEnter", syncStyledFilterCheckButtonHover)
		cb:HookScript("OnLeave", clearStyledFilterCheckButtonHover)
		cb._gfSharedFilterCheckStyled = true
	end
	if opts.atlasStates ~= nil then
		cb._gfSharedFilterCheckAtlasStates = opts.atlasStates
	end
	if opts.localTexture ~= nil then
		cb._gfSharedFilterCheckUsesLocalAtlas =
			opts.localTexture == true
	elseif opts.atlasStates ~= nil then
		cb._gfSharedFilterCheckUsesLocalAtlas =
			usesFilterCheckTexture(opts.atlasStates)
	elseif cb._gfSharedFilterCheckUsesLocalAtlas == nil then
		cb._gfSharedFilterCheckUsesLocalAtlas = true
	end
	if opts.showMark ~= nil then
		cb._gfSharedFilterCheckShowMark = opts.showMark ~= false
	elseif cb._gfSharedFilterCheckShowMark == nil then
		cb._gfSharedFilterCheckShowMark = true
	end
	cb._gfSharedFilterCheckAtlasWidth =
		math.max(1, tonumber(opts.atlasWidth) or width)
	cb._gfSharedFilterCheckAtlasHeight =
		math.max(1, tonumber(opts.atlasHeight) or height)
	cb._gfSharedFilterCheckWidth = width
	cb._gfSharedFilterCheckHeight = height
	if opts.atlasOffsetX ~= nil then
		cb._gfSharedFilterCheckAtlasOffsetX =
			tonumber(opts.atlasOffsetX) or 0
	elseif cb._gfSharedFilterCheckAtlasOffsetX == nil then
		cb._gfSharedFilterCheckAtlasOffsetX = 0
	end
	if opts.atlasOffsetY ~= nil then
		cb._gfSharedFilterCheckAtlasOffsetY =
			tonumber(opts.atlasOffsetY) or 0
	elseif cb._gfSharedFilterCheckAtlasOffsetY == nil then
		cb._gfSharedFilterCheckAtlasOffsetY = 0
	end
	if opts.markOffsetX ~= nil then
		cb._gfSharedFilterCheckMarkOffsetX =
			tonumber(opts.markOffsetX) or 0
	elseif cb._gfSharedFilterCheckMarkOffsetX == nil then
		cb._gfSharedFilterCheckMarkOffsetX = 0
	end
	if opts.markOffsetY ~= nil then
		cb._gfSharedFilterCheckMarkOffsetY =
			tonumber(opts.markOffsetY) or 0
	elseif cb._gfSharedFilterCheckMarkOffsetY == nil then
		cb._gfSharedFilterCheckMarkOffsetY = 0
	end
	layoutStyledFilterCheckButton(cb, width, height, markSize)
	cb._gfSharedFilterCheckLabel = opts.label
	cb._gfSharedFilterCheckUpdateLabel = opts.updateLabel
	if opts.disabledTint ~= nil then
		cb._gfSharedFilterCheckDisabledTint =
			tonumber(opts.disabledTint)
	end
	if opts.disabledAlpha ~= nil then
		cb._gfSharedFilterCheckDisabledAlpha =
			tonumber(opts.disabledAlpha)
	end
	updateStyledFilterCheckButton(cb)
	return cb
end

function GF.UI.CreateFilterCheckButton(parent, opts)
	opts = opts or {}
	local cb = CreateFrame("CheckButton", opts.name, parent)
	return GF.UI.StyleFilterCheckButton(cb, opts)
end

local function tryLoadQueueStatusFrameUI()
	if _G.EyeTemplateMixin then
		return true
	end
	if LoadAddOnWithErrorHandling then
		local ok = pcall(LoadAddOnWithErrorHandling, "Blizzard_QueueStatusFrame")
		if ok and _G.EyeTemplateMixin then
			return true
		end
	end
	if C_AddOns and C_AddOns.LoadAddOn then
		local ok = pcall(C_AddOns.LoadAddOn, "Blizzard_QueueStatusFrame")
		if ok and _G.EyeTemplateMixin then
			return true
		end
	end
	if UIParentLoadAddOn then
		local ok = pcall(UIParentLoadAddOn, "Blizzard_QueueStatusFrame")
		if ok and _G.EyeTemplateMixin then
			return true
		end
	end
	if LoadAddOn then
		local ok = pcall(LoadAddOn, "Blizzard_QueueStatusFrame")
		if ok and _G.EyeTemplateMixin then
			return true
		end
	end
	return _G.EyeTemplateMixin ~= nil
end

function GF.UI.TryLoadQueueStatusFrameUI()
	return tryLoadQueueStatusFrameUI()
end

local function getClassColor()
	local classTag = select(2, UnitClass("player"))
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	local color = colors and classTag and colors[classTag]
	if color then
		return color.r or 1, color.g or 0.82, color.b or 0
	end
	return 1, 0.82, 0
end

function GF.UI.GetClassColor()
	return getClassColor()
end

local function applySystemPanelTitleStyle(fontString)
	if not fontString then
		return
	end
	if fontString.SetFontObject and _G.GameFontNormal then
		fontString:SetFontObject(_G.GameFontNormal)
	end
	if fontString.SetTextColor and _G.NORMAL_FONT_COLOR and _G.NORMAL_FONT_COLOR.GetRGB then
		fontString:SetTextColor(_G.NORMAL_FONT_COLOR:GetRGB())
	elseif fontString.SetTextColor then
		fontString:SetTextColor(1, 0.82, 0, 1)
	end
end

local function centerSystemPanelTitle(frame, fontString)
	if not frame or not fontString then
		return
	end
	fontString:ClearAllPoints()
	fontString:SetPoint("TOP", frame, "TOP", 0, GF.MAIN_WINDOW_TITLE_OFFSET_Y or -6)
	fontString:SetJustifyH("CENTER")
end

local function resolveSystemPanelTitleText(frame)
	if not frame then
		return nil
	end
	return (frame.NineSlice and frame.NineSlice.Text)
		or frame.TitleText
		or (frame.TitleContainer and frame.TitleContainer.TitleText)
		or (frame.GetName and _G[(frame:GetName() or "") .. "TitleText"])
end

-- 公共按钮皮肤与刷新图标见 ButtonSkin.lua。
function GF.UI.InstallMainWindowSkin(frame)
	if not frame or frame._gfMainWindowSkin then
		return
	end
	if frame.Bg and frame.Bg.Hide then
		frame.Bg:Hide()
	end
	local pieces = {}
	for index = 1, 3 do
		local piece = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		paint(piece, 0, 0, 0, 0.82)
		pieces[index] = piece
	end
	local cornerRadius = 1
	local inset = 2
	pieces[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + cornerRadius, -inset)
	pieces[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset + cornerRadius), -inset)
	pieces[1]:SetHeight(cornerRadius)
	pieces[2]:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -(inset + cornerRadius))
	pieces[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset + cornerRadius)
	pieces[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset + cornerRadius, inset)
	pieces[3]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + cornerRadius), inset)
	pieces[3]:SetHeight(cornerRadius)
	frame._gfMainWindowPieces = pieces
	frame._gfMainWindowSkin = true
end

function GF.UI.InstallPanelBackplate(panel)
	if not panel or panel._gfPanelBackplate then
		return
	end
	local background = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
	local decorativeBackground = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
	local borderFrame = CreateFrame("Frame", nil, panel)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	panel._gfPanelBackground = background
	panel._gfPanelDecorativeBackground = decorativeBackground
	panel._gfPanelBorderFrame = borderFrame
	panel._gfPanelBorder = border

	local insetL = GF.MAIN_PANEL_BACKPLATE_BG_INSET_LEFT or 5
	local insetR = GF.MAIN_PANEL_BACKPLATE_BG_INSET_RIGHT or 5
	local insetT = GF.MAIN_PANEL_BACKPLATE_BG_INSET_TOP or 2
	local insetB = GF.MAIN_PANEL_BACKPLATE_BG_INSET_BOTTOM or 10
	background:SetPoint("TOPLEFT", panel, "TOPLEFT", insetL, -insetT)
	background:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -insetR, insetB)
	local bgColor = GF.MAIN_PANEL_BACKPLATE_BG_COLOR or { 0, 0, 0, 1 }
	paint(background, bgColor[1] or 0, bgColor[2] or 0, bgColor[3] or 0, bgColor[4] or 1)

	borderFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", -8, 12)
	borderFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 8, -6)
	borderFrame:EnableMouse(false)
	borderFrame:SetFrameLevel(panel:GetFrameLevel() + 12)

	local decorativeInsetL = GF.MAIN_PANEL_DECORATIVE_BACKGROUND_INSET_LEFT or 15
	local decorativeInsetR = GF.MAIN_PANEL_DECORATIVE_BACKGROUND_INSET_RIGHT or 15
	local decorativeInsetT = GF.MAIN_PANEL_DECORATIVE_BACKGROUND_INSET_TOP or 16
	local decorativeInsetB = GF.MAIN_PANEL_DECORATIVE_BACKGROUND_INSET_BOTTOM or 14
	decorativeBackground:SetPoint(
		"TOPLEFT",
		borderFrame,
		"TOPLEFT",
		decorativeInsetL,
		-decorativeInsetT)
	decorativeBackground:SetPoint(
		"BOTTOMRIGHT",
		borderFrame,
		"BOTTOMRIGHT",
		-decorativeInsetR,
		decorativeInsetB)
	if trySetAtlas(
		decorativeBackground,
		GF.MAIN_PANEL_DECORATIVE_BACKGROUND_ATLAS or "transmog-tabs-frame-bg",
		false
	) then
		decorativeBackground:SetVertexColor(1, 1, 1, 1)
		decorativeBackground:SetAlpha(
			GF.MAIN_PANEL_DECORATIVE_BACKGROUND_ALPHA or 0.42)
	else
		decorativeBackground:Hide()
	end

	border:SetAllPoints(borderFrame)
	trySetAtlas(
		border,
		GF.MAIN_PANEL_DECORATIVE_BORDER_ATLAS or "transmog-tabs-frame",
		false)
	border:SetVertexColor(1, 1, 1, 1)

	panel._gfPanelBackplate = true
end

function GF.UI.InstallTransmogOutfitPanelBackground(panel)
	if not panel or panel._gfTransmogOutfitBackground then
		return
	end
	panel._gfTransmogOutfitBackground = true
end

function GF.UI.InstallBrowseSidePanelChrome(panel)
	if not panel or panel._gfBrowseSideChrome then
		return
	end
	panel._gfBrowseSideChrome = true
end

function GF.UI.InstallTransmogTabsFrameBackground(panel)
	if not panel or panel._gfTransmogTabsFrameBackground then
		return
	end
	panel._gfTransmogTabsFrameBackground = true
end

		local function setCollectionTexCoord(texture, left, right, top, bottom)
			texture:SetTexCoord(left, right, top, bottom)
	end

	local function createCollectionBackgroundTexture(panel, layer, subLevel, atlas, left, right, top, bottom)
		local texture = panel:CreateTexture(nil, layer, nil, subLevel)
		trySetAtlas(texture, atlas, true)
		if left then
			setCollectionTexCoord(texture, left, right, top, bottom)
		end
		texture:SetVertexColor(1, 1, 1, 1)
		return texture
	end

	function GF.UI.InstallCollectionsBackground(panel)
		if not panel or panel._gfCollectionsBackground then
			return
		end

		local bg = {}
		bg.BackgroundTile = createCollectionBackgroundTexture(panel, "BACKGROUND", nil, "collections-background-tile")
		bg.BackgroundTile:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
		bg.BackgroundTile:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
		if bg.BackgroundTile.SetHorizTile then
			bg.BackgroundTile:SetHorizTile(true)
		end
		if bg.BackgroundTile.SetVertTile then
			bg.BackgroundTile:SetVertTile(true)
		end

		bg.ShadowCornerTopLeft = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large")
		bg.ShadowCornerTopRight = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 1, 0, 0, 1)
		bg.ShadowCornerBottomLeft = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 0, 1, 1, 0)
		bg.ShadowCornerBottomRight = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 1, 0, 1, 0)
		bg.ShadowCornerTop = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 0.9999, 1, 0, 1)
		bg.ShadowCornerLeft = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 0, 1, 0.9999, 1)
		bg.ShadowCornerRight = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 1, 0, 0.9999, 1)
		bg.ShadowCornerBottom = createCollectionBackgroundTexture(panel, "BORDER", 2, "collections-background-shadow-large", 0.9999, 1, 1, 0)

		bg.ShadowCornerTopLeft:SetPoint("TOPLEFT", bg.BackgroundTile, "TOPLEFT")
		bg.ShadowCornerTopRight:SetPoint("TOPRIGHT", bg.BackgroundTile, "TOPRIGHT")
		bg.ShadowCornerBottomLeft:SetPoint("BOTTOMLEFT", bg.BackgroundTile, "BOTTOMLEFT")
		bg.ShadowCornerBottomRight:SetPoint("BOTTOMRIGHT", bg.BackgroundTile, "BOTTOMRIGHT")
		bg.ShadowCornerTop:SetPoint("TOPLEFT", bg.ShadowCornerTopLeft, "TOPRIGHT")
		bg.ShadowCornerTop:SetPoint("TOPRIGHT", bg.ShadowCornerTopRight, "TOPLEFT")
		bg.ShadowCornerLeft:SetPoint("TOPLEFT", bg.ShadowCornerTopLeft, "BOTTOMLEFT")
		bg.ShadowCornerLeft:SetPoint("BOTTOMLEFT", bg.ShadowCornerBottomLeft, "TOPLEFT")
		bg.ShadowCornerRight:SetPoint("TOPRIGHT", bg.ShadowCornerTopRight, "BOTTOMRIGHT")
		bg.ShadowCornerRight:SetPoint("BOTTOMRIGHT", bg.ShadowCornerBottomRight, "TOPRIGHT")
		bg.ShadowCornerBottom:SetPoint("BOTTOMLEFT", bg.ShadowCornerBottomLeft, "BOTTOMRIGHT")
		bg.ShadowCornerBottom:SetPoint("BOTTOMRIGHT", bg.ShadowCornerBottomRight, "BOTTOMLEFT")

		bg.OverlayShadowTopLeft = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small")
		bg.OverlayShadowTopRight = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 1, 0, 0, 1)
		bg.OverlayShadowBottomLeft = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 0, 1, 1, 0)
		bg.OverlayShadowBottomRight = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 1, 0, 1, 0)
		bg.OverlayShadowTop = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 0.9999, 1, 0, 1)
		bg.OverlayShadowLeft = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 0, 1, 0.9999, 1)
		bg.OverlayShadowRight = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 1, 0, 0.9999, 1)
		bg.OverlayShadowBottom = createCollectionBackgroundTexture(panel, "OVERLAY", nil, "collections-background-shadow-small", 0.9999, 1, 1, 0)

		bg.OverlayShadowTopLeft:SetPoint("TOPLEFT", bg.BackgroundTile, "TOPLEFT")
		bg.OverlayShadowTopRight:SetPoint("TOPRIGHT", bg.BackgroundTile, "TOPRIGHT")
		bg.OverlayShadowBottomLeft:SetPoint("BOTTOMLEFT", bg.BackgroundTile, "BOTTOMLEFT")
		bg.OverlayShadowBottomRight:SetPoint("BOTTOMRIGHT", bg.BackgroundTile, "BOTTOMRIGHT")
		bg.OverlayShadowTop:SetPoint("TOPLEFT", bg.OverlayShadowTopLeft, "TOPRIGHT", 0, 0)
		bg.OverlayShadowTop:SetPoint("TOPRIGHT", bg.OverlayShadowTopRight, "TOPLEFT", 0, 0)
		bg.OverlayShadowLeft:SetPoint("TOPLEFT", bg.OverlayShadowTopLeft, "BOTTOMLEFT")
		bg.OverlayShadowLeft:SetPoint("BOTTOMLEFT", bg.OverlayShadowBottomLeft, "TOPLEFT")
		bg.OverlayShadowRight:SetPoint("TOPRIGHT", bg.OverlayShadowTopRight, "BOTTOMRIGHT")
		bg.OverlayShadowRight:SetPoint("BOTTOMRIGHT", bg.OverlayShadowBottomRight, "TOPRIGHT")
		bg.OverlayShadowBottom:SetPoint("BOTTOMLEFT", bg.OverlayShadowBottomLeft, "BOTTOMRIGHT", 0, 0)
		bg.OverlayShadowBottom:SetPoint("BOTTOMRIGHT", bg.OverlayShadowBottomRight, "BOTTOMLEFT", 0, 0)

		bg.BGCornerTopLeft = createCollectionBackgroundTexture(panel, "ARTWORK", 2, "collections-background-corner")
		bg.BGCornerTopRight = createCollectionBackgroundTexture(panel, "ARTWORK", 2, "collections-background-corner", 1, 0, 0, 1)
		bg.BGCornerBottomLeft = createCollectionBackgroundTexture(panel, "ARTWORK", 2, "collections-background-corner", 0, 1, 1, 0)
		bg.BGCornerBottomRight = createCollectionBackgroundTexture(panel, "ARTWORK", 2, "collections-background-corner", 1, 0, 1, 0)
		bg.BGCornerTopLeft:SetPoint("TOPLEFT", bg.BackgroundTile, "TOPLEFT")
		bg.BGCornerTopRight:SetPoint("TOPRIGHT", bg.BackgroundTile, "TOPRIGHT")
		bg.BGCornerBottomLeft:SetPoint("BOTTOMLEFT", bg.BackgroundTile, "BOTTOMLEFT")
		bg.BGCornerBottomRight:SetPoint("BOTTOMRIGHT", bg.BackgroundTile, "BOTTOMRIGHT")

		panel._gfCollectionsBackground = bg
	end

local function isFrameEffectivelyShown(frame)
	if not frame then
		return false
	end
	if frame.IsVisible then
		return frame:IsVisible()
	end
	return frame:IsShown()
end

local function syncExternalChromeVisibility(frame, backgroundFrame, owner)
	if not frame or not backgroundFrame then
		return
	end
	local function sync()
		backgroundFrame:SetShown(isFrameEffectivelyShown(frame))
	end
	frame:HookScript("OnShow", sync)
	frame:HookScript("OnHide", sync)
	if owner and owner ~= frame and owner.HookScript then
		owner:HookScript("OnShow", sync)
		owner:HookScript("OnHide", sync)
	end
	sync()
end

function GF.UI.InstallBrowseHeaderChrome(frame, opts)
	if not frame or frame._gfBrowseHeaderChrome then
		return
	end
	opts = type(opts) == "table" and opts or {}
	frame._gfBrowseHeaderChrome = true
	local owner = frame:GetParent() or frame
	local backgroundParent = (GF.MainFrame and GF.MainFrame.layoutHost) or owner
	local backgroundFrame = CreateFrame("Frame", nil, backgroundParent)
	local backgroundInsetLeft = opts.backgroundInsetLeft
	if backgroundInsetLeft == nil then
		backgroundInsetLeft = GF.BROWSE_HEADER_BACKGROUND_INSET_L or 0
	end
	backgroundFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", backgroundInsetLeft, 0)
	backgroundFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	backgroundFrame:SetFrameLevel(math.max((backgroundParent:GetFrameLevel() or 1) + (GF.BROWSE_HEADER_BACKGROUND_FRAME_LEVEL_OFFSET or 1), 1))
	syncExternalChromeVisibility(frame, backgroundFrame, owner)
	local background = backgroundFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetAllPoints(backgroundFrame)
	if not trySetAtlas(background, GF.BROWSE_HEADER_BACKGROUND_ATLAS or "housefinder_header-bg-gradient", false) then
		background:SetTexture(WHITE)
		if background.SetGradientAlpha then
			background:SetGradientAlpha("VERTICAL", 0.22, 0.08, 0.02, 0.95, 0.04, 0.015, 0.005, 0.95)
		else
			background:SetVertexColor(0.12, 0.05, 0.01, 0.95)
		end
	end
	frame._gfBrowseHeaderBackgroundFrame = backgroundFrame
	frame._gfBrowseHeaderBackground = background
end

local function flipTextureVertically(texture)
	if not texture or not texture.GetTexCoord or not texture.SetTexCoord then
		return
	end
	local ulx, uly, llx, lly, urx, ury, lrx, lry = texture:GetTexCoord()
	if lry ~= nil then
		texture:SetTexCoord(llx, lly, ulx, uly, lrx, lry, urx, ury)
	elseif lly ~= nil then
		texture:SetTexCoord(ulx, uly, lly, llx)
	end
end

function GF.UI.InstallBrowseControlBarChrome(frame, opts)
	if not frame or frame._gfBrowseControlChrome then
		return
	end
	opts = opts or {}
	frame._gfBrowseControlChrome = true
	local owner = frame:GetParent() or frame
	local backgroundParent = opts.backgroundParent or (GF.MainFrame and GF.MainFrame.layoutHost) or owner
	local backgroundFrame = CreateFrame("Frame", nil, backgroundParent)
	local leftInset = opts.leftInset
	if leftInset == nil then
		leftInset = (GF.CONTENT_SCROLL_INSET_L or 0) + (GF.BROWSE_HEADER_BACKGROUND_INSET_L or 0)
	end
	local rightInset = opts.rightInset
	if rightInset == nil then
		rightInset = GF.CONTENT_SCROLL_INSET_R or 0
	end
	local h = opts.height or GF.BROWSE_CONTROL_BACKGROUND_H or GF.SUBTITLE_HEADER_H or frame:GetHeight()
	local y = opts.topOffset
	if y == nil then
		y = GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or GF.SUBTITLE_CONTROL_TOP_OFFSET or 0
	end
	backgroundFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", leftInset, y)
	backgroundFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rightInset, y)
	backgroundFrame:SetHeight(h)
	backgroundFrame:SetFrameLevel(math.max((backgroundParent:GetFrameLevel() or 1) + (opts.frameLevelOffset or GF.BROWSE_HEADER_BACKGROUND_FRAME_LEVEL_OFFSET or 1), 1))
	syncExternalChromeVisibility(frame, backgroundFrame, owner)
	local background = backgroundFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetAllPoints(backgroundFrame)
	if trySetAtlas(background, GF.BROWSE_CONTROL_BACKGROUND_ATLAS or GF.BROWSE_HEADER_BACKGROUND_ATLAS or "housefinder_header-bg-gradient", false) then
		flipTextureVertically(background)
		background:SetAlpha(GF.BROWSE_CONTROL_BACKGROUND_ALPHA or 1)
	else
		background:SetTexture(WHITE)
		if background.SetGradientAlpha then
			background:SetGradientAlpha("VERTICAL", 0.04, 0.015, 0.005, 0.95, 0.22, 0.08, 0.02, 0.95)
		else
			background:SetVertexColor(0.12, 0.05, 0.01, 0.95)
		end
	end
	frame._gfBrowseControlBackgroundFrame = backgroundFrame
	frame._gfBrowseControlBackground = background
end

function GF.UI.CreatePanelBackplate(parent)
	local panel = createFrameWithTemplateOptions("Frame", nil, parent, { "BackdropTemplate" })
	panel:SetPoint("TOPLEFT", parent, "TOPLEFT", GF.MAIN_PANEL_INSET_LEFT or 26, -(GF.MAIN_PANEL_INSET_TOP or 64))
	panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(GF.MAIN_PANEL_INSET_RIGHT or 26), GF.MAIN_PANEL_INSET_BOTTOM or 36)
	panel:SetFrameLevel(parent:GetFrameLevel() + 11)
	GF.UI.InstallPanelBackplate(panel)
	return panel
end

local function stopRecruitEyeAnimation(eye)
	if not eye then
		return
	end
	local nativeEye = eye.Eye or eye
	if nativeEye.StopAnimating then
		pcall(nativeEye.StopAnimating, nativeEye)
	elseif eye.StopAnimating then
		pcall(eye.StopAnimating, eye)
	end
	if nativeEye.texture then
		nativeEye.texture:Hide()
	end
	eye._gfRecruitEyeLooping = nil
end

local function startRecruitEyeAnimation(eye)
	if not eye then
		return false
	end
	local nativeEye = eye.Eye or eye
	if nativeEye.texture then
		nativeEye.texture:Hide()
	end
	if nativeEye.StartSearchingAnimation then
		local ok = pcall(nativeEye.StartSearchingAnimation, nativeEye)
		if ok then
			eye._gfRecruitEyeLooping = true
			return true
		end
	end
	if eye.StartSearchingAnimation then
		local ok = pcall(eye.StartSearchingAnimation, eye)
		if ok then
			eye._gfRecruitEyeLooping = true
			return true
		end
	end
	if nativeEye.StartFoundAnimationLoop then
		local ok = pcall(nativeEye.StartFoundAnimationLoop, nativeEye)
		if ok then
			eye._gfRecruitEyeLooping = true
			return true
		end
	end
	if eye.StartFoundAnimationLoop then
		local ok = pcall(eye.StartFoundAnimationLoop, eye)
		if ok then
			eye._gfRecruitEyeLooping = true
			return true
		end
	end
	return false
end

function GF.UI.InstallRecruitEyeLogo(frame)
	if not frame or frame._gfRecruitEyeLogo then
		return frame and frame._gfRecruitEyeLogo
	end
	local portraitContainer = frame.PortraitContainer
	local parent = portraitContainer or frame
	local anchor = portraitContainer and portraitContainer.portrait or parent
	if not parent or not anchor then
		return nil
	end
	if portraitContainer and portraitContainer.portrait then
		local portrait = portraitContainer.portrait
		portrait:SetTexture(nil)
		portrait:SetAlpha(0)
		portrait:Hide()
		portrait:ClearAllPoints()
		portrait:SetSize(63, 63)
		portrait:SetPoint("TOPLEFT", portraitContainer, "TOPLEFT", -6, 8.5)
		if portraitContainer.CircleMask then
			portraitContainer.CircleMask:ClearAllPoints()
			portraitContainer.CircleMask:SetPoint("TOPLEFT", portraitContainer, "TOPLEFT", -3, 7)
			portraitContainer.CircleMask:SetPoint("BOTTOMRIGHT", portraitContainer, "TOPLEFT", 55, -51)
		end
	end

	local host = CreateFrame("Frame", nil, parent)
	host:SetSize(GF.MAIN_WINDOW_EYE_HOST_SIZE or 68, GF.MAIN_WINDOW_EYE_HOST_SIZE or 68)
	host:SetPoint("CENTER", anchor, "CENTER", 0, 0)
	host:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or frame:GetFrameLevel()) + 30)
	host:EnableMouse(false)
	host._gfRecruitEyeLogo = true

	local blackFill = host:CreateTexture(nil, "BACKGROUND")
	blackFill:SetPoint("CENTER")
	blackFill:SetSize(GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54, GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54)
	paint(blackFill, 0, 0, 0, 1)
	if host.CreateMaskTexture and blackFill.AddMaskTexture then
		local mask = host:CreateMaskTexture()
		mask:SetTexture(GF.MAIN_WINDOW_EYE_BACKGROUND_MASK or "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetPoint("CENTER", blackFill, "CENTER", 0, 0)
		mask:SetSize(GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54, GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54)
		pcall(blackFill.AddMaskTexture, blackFill, mask)
		host.BlackFillMask = mask
	elseif portraitContainer and portraitContainer.CircleMask and blackFill.AddMaskTexture then
		pcall(blackFill.AddMaskTexture, blackFill, portraitContainer.CircleMask)
	end
	host.BlackFill = blackFill

	local staticEye = host:CreateTexture(nil, "ARTWORK")
	staticEye:SetPoint("CENTER", host, "CENTER", 0, 1)
	staticEye:SetSize(GF.MAIN_WINDOW_LOGO_SIZE or GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54, GF.MAIN_WINDOW_LOGO_SIZE or GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE or 54)
	local logoPath = GF.MAIN_WINDOW_LOGO_TEXTURE or GF.ADDON_LOGO_TEXTURE
	local logoOk = pcall(staticEye.SetTexture, staticEye, logoPath)
	if not logoOk and not trySetAtlas(staticEye, "groupfinder-eye-single", false) then
		staticEye:SetTexture(GF.ADDON_LOGO_TEXTURE)
	end
	staticEye:SetTexCoord(0, 1, 0, 1)
	staticEye:Show()
	host.StaticEye = staticEye

	if tryLoadQueueStatusFrameUI() then
		local ok, eye = pcall(CreateFrame, "Frame", nil, host, "EyeTemplate")
		if ok and eye then
			eye:SetSize(GF.MAIN_WINDOW_EYE_SIZE or 44, GF.MAIN_WINDOW_EYE_SIZE or 44)
			eye:SetPoint("CENTER", host, "CENTER", 0, 0)
			eye:SetFrameLevel(host:GetFrameLevel() + 5)
			eye:Hide()
			if eye.texture then
				eye.texture:Hide()
			end
			host.Eye = eye
		end
	end

	frame._gfRecruitEyeLogo = host
	return host
end

function GF.UI.SetRecruitEyeLogoActive(frame, active)
	local host = GF.UI.InstallRecruitEyeLogo(frame)
	if not host then
		return
	end
	active = active == true
	host:Show()
	if host.BlackFill then
		host.BlackFill:Show()
	end
	if active then
		if host.StaticEye then
			host.StaticEye:Hide()
		end
		if host.Eye then
			host.Eye:SetAlpha(1)
			host.Eye:SetScale(1)
			host.Eye:Show()
			if not host.Eye._gfRecruitEyeLooping and not startRecruitEyeAnimation(host.Eye) then
				host.Eye:Hide()
				if host.StaticEye then
					host.StaticEye:Show()
				end
			end
		elseif host.StaticEye then
			host.StaticEye:Show()
		end
	else
		if host.Eye then
			stopRecruitEyeAnimation(host.Eye)
			host.Eye:SetAlpha(1)
			host.Eye:SetScale(1)
			host.Eye:Hide()
		end
		if host.StaticEye then
			host.StaticEye:Show()
		end
	end
	host._gfRecruitEyeActive = active
end

local function assignOptionsTabAtlasKeys(button)
	button.upLeftTexture = OPTIONS_TAB_ATLASES.up.left
	button.upMiddleTexture = OPTIONS_TAB_ATLASES.up.middle
	button.upRightTexture = OPTIONS_TAB_ATLASES.up.right
	button.overLeftTexture = OPTIONS_TAB_ATLASES.up.left
	button.overMiddleTexture = OPTIONS_TAB_ATLASES.up.middle
	button.overRightTexture = OPTIONS_TAB_ATLASES.up.right
	button.selectedLeftTexture = OPTIONS_TAB_ATLASES.selected.left
	button.selectedMiddleTexture = OPTIONS_TAB_ATLASES.selected.middle
	button.selectedRightTexture = OPTIONS_TAB_ATLASES.selected.right
end

local function ensureNativeTabPieces(button)
	if not button.Left then
		button.Left = button:CreateTexture(nil, "BACKGROUND")
		button.Left:SetPoint("BOTTOMLEFT")
	end
	if not button.Right then
		button.Right = button:CreateTexture(nil, "BACKGROUND")
		button.Right:SetPoint("BOTTOMRIGHT")
	end
	if not button.Middle then
		button.Middle = button:CreateTexture(nil, "BACKGROUND")
		button.Middle:SetPoint("TOPLEFT", button.Left, "TOPRIGHT")
		button.Middle:SetPoint("TOPRIGHT", button.Right, "TOPLEFT")
	end
	if not button.Text then
		button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	end
	if button._gfTopTabStyle and not button.SelectedHighlight then
		local selectedHighlight = CreateFrame("Frame", nil, button)
		selectedHighlight:SetFrameLevel(button._gfSelectedHighlightFrameLevel or (button:GetFrameLevel() + 10))
		selectedHighlight:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 5)
		selectedHighlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 5)
		selectedHighlight:SetHeight(1)
		selectedHighlight:Hide()
		local highlight = selectedHighlight:CreateTexture(nil, "ARTWORK")
		highlight:SetAllPoints(selectedHighlight)
		trySetAtlas(highlight, "transmog-tab-hl", false)
		highlight:SetVertexColor(1, 1, 1, 1)
		selectedHighlight.Highlight = highlight
		button.SelectedHighlight = selectedHighlight
	end
end

local function updateNativeTabAtlas(button)
	if not button or button._gfTopTabStyle then
		return
	end
	local atlasSet = button._gfSelected and OPTIONS_TAB_ATLASES.selected or OPTIONS_TAB_ATLASES.up
	trySetAtlas(button.Left, atlasSet.left, true)
	trySetAtlas(button.Middle, atlasSet.middle, true)
	trySetAtlas(button.Right, atlasSet.right, true)
end

local function setNativeTabText(button, text)
	button.Text:SetText(text or "")
	button.Text:SetWidth(0)
	local textWidth = button.Text:GetStringWidth() or 0
	if button._gfTopTabStyle then
		local width = math.max(GF.MAIN_PANEL_TAB_MIN_WIDTH or 95, textWidth + 30)
		width = math.min(GF.MAIN_PANEL_TAB_MAX_WIDTH or 170, width)
		button:SetSize(width, GF.MAIN_PANEL_TAB_HEIGHT or 32)
		button.Text:SetWidth(math.max(1, width - 10))
	else
		button:SetSize(math.max(GF.MAIN_PANEL_TAB_MIN_WIDTH or 95, textWidth + 40), GF.MAIN_PANEL_TAB_HEIGHT or 32)
	end
end

function GF.UI.SetNativeTabText(button, text)
	if button and button.Text then
		setNativeTabText(button, text)
	end
end

function GF.UI.SetNativeTabSelected(button, selected)
	if not button or not button.Text then
		return
	end
	button._gfSelected = selected == true
	if button._gfTopTabStyle and button.SetTabSelected then
		local ok = pcall(button.SetTabSelected, button, selected == true)
		if ok then
			if button.SelectedHighlight then
				button.SelectedHighlight:SetShown(selected == true)
			end
			if selected then
				button.Text:SetTextColor(1, 1, 1, 1)
			else
				button.Text:SetTextColor(1, 0.82, 0, 1)
			end
			return
		end
	end
	if button.SetSelectedState and button.OnSelected then
		button:SetSelectedState(selected == true)
		button:OnSelected(selected == true)
	else
		updateNativeTabAtlas(button)
		button.Text:ClearAllPoints()
		button.Text:SetPoint("BOTTOM", button, "BOTTOM", 0, selected and 6 or 4)
		button.Text:SetFontObject(selected and "GameFontHighlightSmall" or "GameFontNormalSmall")
	end
end

function GF.UI.CreateNativeTabButton(parent, text, tabIndex)
	local name = ("GroupFinderAddonFrameTab%d"):format(tabIndex or 0)
	local button, template = createFrameWithTemplateOptions("Button", name, parent, {
		"TabSystemTopButtonTemplate",
		"MinimalTabTemplate",
	})
	button:SetID(tabIndex or 0)
	button._gfNativeTab = true
	button._gfTopTabStyle = template == "TabSystemTopButtonTemplate" and button.LeftActive and button.MiddleActive and button.RightActive
	button._gfSelectedHighlightFrameLevel = parent and parent.selectedHighlightFrameLevel
	if button._gfTopTabStyle then
		button:SetFrameLevel(parent:GetFrameLevel() + 1)
		button.isTabOnTop = true
		button.selectedFontObject = _G[GF.MAIN_PANEL_TAB_SELECTED_FONT_OBJECT or "GameFontHighlight"]
			or GameFontHighlight
		button.unselectedFontObject = _G[GF.MAIN_PANEL_TAB_UNSELECTED_FONT_OBJECT or "GameFontNormal"]
			or GameFontNormal
		button.textOffsetY = 3
		button.textPadding = 17
		if button.HandleRotation then
			pcall(button.HandleRotation, button)
		end
	else
		assignOptionsTabAtlasKeys(button)
	end
	ensureNativeTabPieces(button)
	setNativeTabText(button, text)
	GF.UI.SetNativeTabSelected(button, false)
	if not button._gfTopTabStyle then
		button:SetScript("OnEnter", function(tabButton)
			tabButton.over = true
			if tabButton.UpdateAtlas then
				tabButton:UpdateAtlas()
			else
				updateNativeTabAtlas(tabButton)
			end
		end)
		button:SetScript("OnLeave", function(tabButton)
			tabButton.over = nil
			if tabButton.UpdateAtlas then
				tabButton:UpdateAtlas()
			else
				updateNativeTabAtlas(tabButton)
			end
		end)
	end
	return button
end

function GF.UI.CreateFontString(parent, layer, template)
	local constructor = parent and parent.CreateFontString
	if constructor == nil then
		return nil
	end
	local fontString = constructor(parent, nil, layer or "OVERLAY", template)
	local tracker = GF.Font and GF.Font.Track
	if tracker then
		tracker(fontString, template)
	end
	return fontString
end

function GF.UI.ApplyEmptyPromptFont(fontString, template)
	if not fontString then
		return
	end
	local size = GF.EMPTY_PROMPT_TEXT_SIZE
		or GF.BROWSE_EMPTY_TEXT_SIZE
		or 14
	fontString._gfFontSizeOverride = size
	fontString._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.Track then
		GF.Font.Track(fontString, template or "GameFontHighlight")
		return
	end
	if not (fontString.GetFont and fontString.SetFont) then
		return
	end
	local path = fontString:GetFont()
	if path then
		fontString:SetFont(path, size, "")
	end
end

local DEFAULT_PENDING_SPINNER_SIZE = 18

local function createFallbackPendingSpinner(parent)
	if not parent then
		return nil
	end
	local spinner = CreateFrame("Frame", nil, parent)
	spinner.Ring = spinner:CreateTexture(nil, "ARTWORK")
	spinner.Ring:SetAllPoints(spinner)
	spinner.Ring:SetAtlas("Spinner_Ring")
	spinner.Sparks = spinner:CreateTexture(nil, "ARTWORK")
	spinner.Sparks:SetAllPoints(spinner)
	spinner.Sparks:SetAtlas("Spinner_Sparks")
	if spinner.Sparks.SetBlendMode then
		spinner.Sparks:SetBlendMode("ADD")
	end
	if spinner.Sparks.CreateAnimationGroup then
		local ok = pcall(function()
			local group = spinner.Sparks:CreateAnimationGroup()
			local rotation = group:CreateAnimation("Rotation")
			rotation:SetDuration(0.85)
			rotation:SetDegrees(360)
			group:SetLooping("REPEAT")
			spinner.Anim = group
		end)
		if not ok then
			spinner.Anim = nil
		end
	end
	return spinner
end

function GF.UI.CreatePendingSpinner(parent, size)
	if not parent then
		return nil
	end
	size = size or DEFAULT_PENDING_SPINNER_SIZE
	local ok, spinner = pcall(CreateFrame, "Frame", nil, parent, "SpinnerTemplate")
	spinner = ok and spinner or createFallbackPendingSpinner(parent)
	if spinner then
		spinner:SetSize(size, size)
		if spinner.SetFrameLevel and parent.GetFrameLevel then
			spinner:SetFrameLevel(parent:GetFrameLevel() + 2)
		end
		spinner:Hide()
	end
	return spinner
end

function GF.UI.StartPendingSpinner(spinner, size)
	if not spinner then
		return
	end
	size = size or DEFAULT_PENDING_SPINNER_SIZE
	spinner:SetSize(size, size)
	spinner:Show()
	if spinner.Anim and spinner.Anim.Play and (not spinner.Anim.IsPlaying or not spinner.Anim:IsPlaying()) then
		spinner.Anim:Play()
	end
end

function GF.UI.StopPendingSpinner(spinner)
	if not spinner then
		return
	end
	if spinner.Anim and spinner.Anim.Stop then
		spinner.Anim:Stop()
	end
	spinner:Hide()
end

function GF.UI.SetButtonPendingSpinner(button, shown, size)
	if not button then
		return
	end
	local fs = button.GetFontString and button:GetFontString()
	if shown then
		size = size or DEFAULT_PENDING_SPINNER_SIZE
		local currentText = button.GetText and button:GetText()
		if currentText and currentText ~= "" then
			button._gfPendingSpinnerText = currentText
		elseif button._gfPendingSpinnerText == nil then
			button._gfPendingSpinnerText = currentText or ""
		end
		if not button._gfPendingSpinner then
			button._gfPendingSpinner = GF.UI.CreatePendingSpinner(button, size)
			if button._gfPendingSpinner then
				button._gfPendingSpinner:SetPoint("CENTER", button, "CENTER", 0, 0)
			end
		end
		if button.SetText then
			button:SetText("")
		elseif fs and fs.SetText then
			fs:SetText("")
		end
		if fs and fs.SetAlpha then
			fs:SetAlpha(0)
		end
		GF.UI.StartPendingSpinner(button._gfPendingSpinner, size)
	else
		local restoreText = button._gfPendingSpinnerText
		button._gfPendingSpinnerText = nil
		if restoreText ~= nil then
			if button.SetText then
				button:SetText(restoreText)
			elseif fs and fs.SetText then
				fs:SetText(restoreText)
			end
		end
		if fs and fs.SetAlpha then
			fs:SetAlpha(1)
		end
		GF.UI.StopPendingSpinner(button._gfPendingSpinner)
	end
end

function GF.UI.TrackEditBox(box, template)
	local track = GF.Font and GF.Font.TrackEditBox
	if box and track then
		track(box, template or "GameFontHighlightSmall")
	end
	return box
end

function GF.UI.CreateInputBox(parent, width, height)
	local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	input:SetSize(width or 60, height or 18)
	input:SetAutoFocus(false)
	return GF.UI.TrackEditBox(input, "GameFontHighlightSmall")
end

local function hideInputBoxRegion(region)
	if not region then
		return
	end
	if region.Hide then
		region:Hide()
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
end

local function hideInputBoxChrome(editBox)
	if not editBox then
		return
	end
	local name = editBox.GetName and editBox:GetName()
	if name then
		for _, region in ipairs({
			_G[name .. "Left"],
			_G[name .. "Middle"],
			_G[name .. "Right"],
			_G[name .. "LeftTexture"],
			_G[name .. "MiddleTexture"],
			_G[name .. "RightTexture"],
		}) do
			hideInputBoxRegion(region)
		end
	end
	hideInputBoxRegion(editBox.Left)
	hideInputBoxRegion(editBox.Middle)
	hideInputBoxRegion(editBox.Right)
	hideInputBoxRegion(editBox.LeftTexture)
	hideInputBoxRegion(editBox.MiddleTexture)
	hideInputBoxRegion(editBox.RightTexture)
end

local function applyBrowseSearchDropdownChrome(editBox)
	if not editBox then
		return nil
	end
	GF.UI.SetControlCardChromeShown(editBox, false)
	for _, region in pairs(editBox._gfFilterInputChromePieces or {}) do
		if region.SetTexture then
			region:SetTexture(nil)
		end
		if region.Hide then
			region:Hide()
		end
	end
	hideInputBoxChrome(editBox)
	local background = editBox._gfBrowseSearchDropdownBackground
	if not background then
		background = editBox:CreateTexture(nil, "BACKGROUND", nil, -2)
		editBox._gfBrowseSearchDropdownBackground = background
	end
	background:ClearAllPoints()
	background:SetPoint("TOPLEFT", editBox, "TOPLEFT", -8, 7)
	background:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 8, -9)
	GF.UI.TrySetAtlas(background, "common-dropdown-textholder", true)
	background:Show()
	return background
end

local function updateSharedFilterNumberBox(box)
	if not (box and box._gfSharedFilterInputStyled) then
		return
	end
	local enabled = (not box.IsEnabled or box:IsEnabled())
		and box._gfSharedFilterInputVisualEnabled ~= false
	local active = enabled and ((box.HasFocus and box:HasFocus())
		or box._gfSharedFilterInputHovered == true
	)
	local chrome = GF.UI.ApplyFilterInputChrome(
		box,
		active and "hover" or "normal"
	)
	if chrome then
		local tintDisabled = box._gfSharedFilterInputDisabledTint ~= nil
		local chromeEnabled = enabled
		if not tintDisabled then
			chromeEnabled = true
		end
		GF.UI.SetControlCardChromeEnabledVisual(
			box,
			chromeEnabled,
			{
				disabledTint = box._gfSharedFilterInputDisabledTint,
				alpha = tintDisabled and not enabled
					and (box._gfSharedFilterInputDisabledAlpha or 1)
					or 1,
			}
		)
	end
	local enabledTextColor = box._gfSharedFilterInputEnabledTextColor
		or { 1, 0.92, 0.64, 1 }
	local disabledTextColor = box._gfSharedFilterInputDisabledTextColor
		or enabledTextColor
	local textColor = enabled and enabledTextColor or disabledTextColor
	if box.SetTextColor then
		box:SetTextColor(
			textColor[1] or 1,
			textColor[2] or 1,
			textColor[3] or 1,
			textColor[4] or 1
		)
	end
end

function GF.UI.UpdateFilterNumberBox(box)
	updateSharedFilterNumberBox(box)
end

function GF.UI.SetFilterNumberBoxVisualEnabled(box, enabled)
	if not box then
		return
	end
	box._gfSharedFilterInputVisualEnabled = enabled ~= false
	updateSharedFilterNumberBox(box)
end

function GF.UI.StyleFilterNumberBox(box, opts)
	if not box then
		return box
	end
	opts = type(opts) == "table" and opts or {}
	local width = tonumber(opts.width)
	local height = tonumber(opts.height)
		or GF.FILTER_NUMBER_INPUT_H
		or 20
	if width and width > 0 then
		box:SetSize(width, height)
	else
		box:SetHeight(height)
	end
	box:SetJustifyH(opts.justifyH or "CENTER")
	if box.SetTextInsets then
		box:SetTextInsets(2, 2, 0, 0)
	end
	box._gfSharedFilterInputEnabledTextColor =
		opts.enabledTextColor or { 1, 0.92, 0.64, 1 }
	if box._gfSharedFilterInputVisualEnabled == nil then
		box._gfSharedFilterInputVisualEnabled = true
	end
	box._gfSharedFilterInputDisabledTextColor =
		opts.disabledTextColor
	if opts.disabledTint ~= nil then
		box._gfSharedFilterInputDisabledTint =
			tonumber(opts.disabledTint)
	end
	if opts.disabledAlpha ~= nil then
		box._gfSharedFilterInputDisabledAlpha =
			tonumber(opts.disabledAlpha)
	end
	local textColor = box._gfSharedFilterInputEnabledTextColor
	box:SetTextColor(
		textColor[1] or 1,
		textColor[2] or 0.92,
		textColor[3] or 0.64,
		textColor[4] or 1
	)
	box:SetShadowColor(0, 0, 0, 0.85)
	box:SetShadowOffset(1, -1)
	hideInputBoxChrome(box)

	if not box._gfSharedFilterInputStyled then
		box:HookScript("OnEditFocusGained", updateSharedFilterNumberBox)
		box:HookScript("OnEditFocusLost", updateSharedFilterNumberBox)
		box:HookScript("OnShow", updateSharedFilterNumberBox)
		box:HookScript("OnEnable", updateSharedFilterNumberBox)
		box:HookScript("OnDisable", updateSharedFilterNumberBox)
		box:HookScript("OnEnter", function(self)
			self._gfSharedFilterInputHovered = true
			updateSharedFilterNumberBox(self)
		end)
		box:HookScript("OnLeave", function(self)
			self._gfSharedFilterInputHovered = nil
			updateSharedFilterNumberBox(self)
		end)
		box._gfSharedFilterInputStyled = true
	end
	updateSharedFilterNumberBox(box)
	return box
end

local function refreshFilterStepButtonIcon(button)
	local icon = button and button._gfFilterStepIcon
	if not icon then
		return
	end
	local enabled = not button.IsEnabled or button:IsEnabled()
	if icon.SetDesaturated then
		icon:SetDesaturated(not enabled)
	end
	if enabled then
		icon:SetVertexColor(1, 1, 1, 0.95)
	else
		local disabledAlpha = button._gfFilterStepPreserveDisabledAlpha
			and 0.95
			or button._gfFilterStepDisabledAlpha
			or 0.35
		icon:SetVertexColor(
			FILTER_DISABLED_ICON_TINT,
			FILTER_DISABLED_ICON_TINT,
			FILTER_DISABLED_ICON_TINT,
			disabledAlpha
		)
	end
end

function GF.UI.CreateFilterStepButton(parent, direction, opts)
	opts = type(opts) == "table" and opts or {}
	local size = tonumber(opts.size)
		or GF.FILTER_STEP_BUTTON_SIZE
		or 20
	local button = GF.UI.CreatePanelButton(parent, "", size)
	button:SetSize(size, size)
	button:SetText("")
	local fontString = button:GetFontString()
	if fontString then
		fontString:SetText("")
		fontString:Hide()
	end
	local icon = button:CreateTexture(nil, "OVERLAY", nil, 2)
	local atlas = opts.arrowAtlas
		or GF.NAV_FLYOUT_ARROW_ATLAS
		or "bag-arrow"
	if GF.UI.TrySetAtlas(icon, atlas, false) then
		icon:SetSize(
			opts.arrowWidth or GF.NAV_FLYOUT_ARROW_W or 10,
			opts.arrowHeight or GF.NAV_FLYOUT_ARROW_H or 16
		)
		local offsetX = (
			opts.arrowCenterOffsetX
				or GF.FILTER_STEP_ARROW_CENTER_OFFSET_X
				or 1
		) * (direction == "right" and 1 or -1)
		icon:SetPoint("CENTER", button, "CENTER", offsetX, 0)
		if icon.SetRotation then
			icon:SetRotation(direction == "right" and math.pi or 0)
		end
		button._gfFilterStepIcon = icon
	else
		icon:Hide()
	end
	button._gfFilterStepDisabledAlpha =
		tonumber(opts.disabledAlpha) or 0.35
	button:HookScript("OnEnable", refreshFilterStepButtonIcon)
	button:HookScript("OnDisable", refreshFilterStepButtonIcon)
	refreshFilterStepButtonIcon(button)
	return button
end

function GF.UI.SetFilterStepButtonPreserveDisabledAlpha(button, preserve)
	if not button then
		return
	end
	button._gfFilterStepPreserveDisabledAlpha =
		preserve == true or nil
	if GF.UI.SetCommonPanelButtonPreserveDisabledAlpha then
		GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
			button,
			preserve == true
		)
	end
	refreshFilterStepButtonIcon(button)
end

local function setBrowseSearchTextureEnabled(texture, enabled)
	if not texture then
		return
	end
	if texture.SetDesaturated then
		texture:SetDesaturated(not enabled)
	end
	if texture.SetVertexColor then
		local _, _, _, alpha = texture:GetVertexColor()
		if enabled then
			texture:SetVertexColor(1, 1, 1, alpha or 1)
		else
			texture:SetVertexColor(
				FILTER_DISABLED_ICON_TINT,
				FILTER_DISABLED_ICON_TINT,
				FILTER_DISABLED_ICON_TINT,
				alpha or 1
			)
		end
	end
end

local function updateBrowseSearchBoxEnabledVisual(editBox)
	if not editBox then
		return
	end
	local enabled = not editBox.IsEnabled or editBox:IsEnabled()
	local background = applyBrowseSearchDropdownChrome(editBox)
	setBrowseSearchTextureEnabled(background, enabled)
	setBrowseSearchTextureEnabled(editBox.searchIcon, enabled)
	local textColor = enabled
		and editBox._gfBrowseSearchEnabledTextColor
		or editBox._gfBrowseSearchDisabledTextColor
	if textColor and editBox.SetTextColor then
		editBox:SetTextColor(
			textColor[1] or 1,
			textColor[2] or 1,
			textColor[3] or 1,
			textColor[4] or 1
		)
	end
	local placeholderColor = enabled
		and editBox._gfBrowseSearchEnabledPlaceholderColor
		or editBox._gfBrowseSearchDisabledPlaceholderColor
	if editBox.Instructions and placeholderColor then
		editBox.Instructions:SetTextColor(
			placeholderColor[1] or 1,
			placeholderColor[2] or 1,
			placeholderColor[3] or 1,
			placeholderColor[4] or 1
		)
	end

	local clearButton = editBox.clearButton
	if not clearButton then
		return
	end
	if clearButton.EnableMouse then
		clearButton:EnableMouse(enabled)
	end
	for _, texture in pairs({
		clearButton.Icon,
		clearButton.icon,
		clearButton.GetNormalTexture and clearButton:GetNormalTexture(),
		clearButton.GetPushedTexture and clearButton:GetPushedTexture(),
		clearButton.GetHighlightTexture and clearButton:GetHighlightTexture(),
		clearButton.GetDisabledTexture and clearButton:GetDisabledTexture(),
	}) do
		setBrowseSearchTextureEnabled(texture, enabled)
	end
end

function GF.UI.StyleBrowseSearchBox(editBox, placeholder)
	if not editBox then
		return nil
	end
	editBox:SetAutoFocus(false)
	editBox._gfFontSizeOverride = GF.SUBTITLE_SEARCH_TEXT_SIZE or 12
	editBox._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.TrackEditBox then
		GF.Font.TrackEditBox(editBox, "GameFontHighlightSmall")
	end
	local textColor = GF.SUBTITLE_SEARCH_TEXT_COLOR or { 1, 0.96, 0.86, 1 }
	editBox._gfBrowseSearchEnabledTextColor = textColor
	editBox._gfBrowseSearchDisabledTextColor = textColor
	editBox:SetTextColor(textColor[1] or 1, textColor[2] or 0.96, textColor[3] or 0.86, textColor[4] or 1)
	editBox:SetShadowColor(0, 0, 0, 0.8)
	editBox:SetShadowOffset(1, -1)
	if editBox.SetTextInsets then
		editBox:SetTextInsets(GF.SUBTITLE_SEARCH_TEXT_INSET_LEFT or 27, GF.SUBTITLE_SEARCH_TEXT_INSET_RIGHT or 24, 0, 0)
	end

	applyBrowseSearchDropdownChrome(editBox)

	if editBox.searchIcon then
		editBox.searchIcon:ClearAllPoints()
		editBox.searchIcon:SetPoint("LEFT", editBox, "LEFT", GF.SUBTITLE_SEARCH_ICON_INSET or 8, 0)
		editBox.searchIcon:SetSize(GF.SUBTITLE_SEARCH_ICON_SIZE or 14, GF.SUBTITLE_SEARCH_ICON_SIZE or 14)
	end
	if editBox.clearButton then
		editBox.clearButton:ClearAllPoints()
		editBox.clearButton:SetPoint("RIGHT", editBox, "RIGHT", -(GF.SUBTITLE_SEARCH_CLEAR_INSET or 6), 0)
	end
	if editBox.Instructions then
		local placeholderColor = GF.SUBTITLE_SEARCH_PLACEHOLDER_COLOR or { 0.55, 0.55, 0.55, 1 }
		editBox._gfBrowseSearchEnabledPlaceholderColor = placeholderColor
		editBox._gfBrowseSearchDisabledPlaceholderColor =
			placeholderColor
		editBox.Instructions:ClearAllPoints()
		editBox.Instructions:SetPoint("LEFT", editBox, "LEFT", GF.SUBTITLE_SEARCH_TEXT_INSET_LEFT or 27, 0)
		editBox.Instructions:SetPoint("RIGHT", editBox, "RIGHT", -(GF.SUBTITLE_SEARCH_TEXT_INSET_RIGHT or 24), 0)
		editBox.Instructions:SetText(placeholder or "")
		editBox.Instructions:SetTextColor(
			placeholderColor[1] or 0.55,
			placeholderColor[2] or 0.55,
			placeholderColor[3] or 0.55,
			placeholderColor[4] or 1
		)
		if editBox.Instructions.SetWordWrap then
			editBox.Instructions:SetWordWrap(false)
		end
		editBox.Instructions._gfFontSizeOverride = GF.SUBTITLE_SEARCH_TEXT_SIZE or 12
		editBox.Instructions._gfFontFlagsOverride = ""
		if GF.Font and GF.Font.Track then
			GF.Font.Track(editBox.Instructions, "GameFontDisableSmall")
		end
	end
	if not editBox._gfBrowseSearchEnabledVisualHooks then
		editBox:HookScript("OnEditFocusGained", updateBrowseSearchBoxEnabledVisual)
		editBox:HookScript("OnEditFocusLost", updateBrowseSearchBoxEnabledVisual)
		editBox:HookScript("OnShow", function(box)
			local enabled = not box.IsEnabled or box:IsEnabled()
			box._gfBrowseSearchHovered = enabled
				and box.IsMouseMotionFocus
				and box:IsMouseMotionFocus() == true
			updateBrowseSearchBoxEnabledVisual(box)
		end)
		editBox:HookScript("OnHide", function(box)
			box._gfBrowseSearchHovered = false
			updateBrowseSearchBoxEnabledVisual(box)
		end)
		editBox:HookScript("OnEnter", function(box)
			box._gfBrowseSearchHovered = true
			updateBrowseSearchBoxEnabledVisual(box)
		end)
		editBox:HookScript("OnLeave", function(box)
			box._gfBrowseSearchHovered = false
			updateBrowseSearchBoxEnabledVisual(box)
		end)
		editBox:HookScript(
			"OnEnable",
			function(box)
				box._gfBrowseSearchHovered = box.IsMouseMotionFocus
					and box:IsMouseMotionFocus() == true
				updateBrowseSearchBoxEnabledVisual(box)
			end
		)
		editBox:HookScript(
			"OnDisable",
			function(box)
				box._gfBrowseSearchHovered = false
				updateBrowseSearchBoxEnabledVisual(box)
			end
		)
		editBox._gfBrowseSearchEnabledVisualHooks = true
	end
	updateBrowseSearchBoxEnabledVisual(editBox)
	return editBox
end

function GF.UI.SetBrowseSearchBoxDisabledColors(
	editBox,
	textColor,
	placeholderColor
)
	if not editBox then
		return
	end
	editBox._gfBrowseSearchDisabledTextColor =
		textColor or editBox._gfBrowseSearchEnabledTextColor
	editBox._gfBrowseSearchDisabledPlaceholderColor =
		placeholderColor
		or editBox._gfBrowseSearchEnabledPlaceholderColor
	updateBrowseSearchBoxEnabledVisual(editBox)
end

function GF.UI.CreateDropdownButton(parent)
	local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	local font = GF.Font
	if font and font.TrackDropdownButton then
		font.TrackDropdownButton(dropdown)
	end
	if dropdown.SetupMenu and font and font.WrapMenuRoot then
		local nativeSetup = dropdown.SetupMenu
		dropdown.SetupMenu = function(button, generator, ...)
			local function styledGenerator(owner, rootDescription, ...)
				font.WrapMenuRoot(rootDescription)
				return generator(owner, rootDescription, ...)
			end
			return nativeSetup(button, styledGenerator, ...)
		end
	end
	return dropdown
end

function GF.UI.ApplyDropdownDisabledVisual(
	dropdown,
	disabled,
	visual,
	stateKey
)
	if not dropdown then
		return
	end
	visual = type(visual) == "table"
		and visual
		or GF.CREATE_MANAGER_DISABLED_VISUAL
		or {}
	stateKey = type(stateKey) == "string" and stateKey
		or "_gfDropdownDisabledVisual"
	local hadOverride = dropdown[stateKey] == true
	if dropdown.OnButtonStateChanged then
		dropdown:OnButtonStateChanged()
	end
	if disabled ~= true then
		if hadOverride then
			for _, texture in ipairs({
				dropdown.Background,
				dropdown.Arrow,
			}) do
				if texture then
					if texture.SetDesaturated then
						texture:SetDesaturated(false)
					end
					texture:SetVertexColor(1, 1, 1, 1)
					texture:SetAlpha(1)
				end
			end
			if dropdown.Text then
				dropdown.Text:SetAlpha(1)
			end
		end
		dropdown[stateKey] = nil
		return
	end

	local tint = tonumber(visual.atlasTint)
		or GF.FILTER_DISABLED_ICON_TINT
		or 0.58
	local alpha = tonumber(visual.alpha) or 1
	if dropdown.Arrow and dropdown.Arrow.SetAtlas then
		dropdown.Arrow:SetAtlas(
			GF.CREATE_MANAGER_DROPDOWN_ARROW_ATLAS
				or "common-dropdown-a-button",
			true
		)
	end
	for _, texture in ipairs({
		dropdown.Background,
		dropdown.Arrow,
	}) do
		if texture then
			if texture.SetDesaturated then
				texture:SetDesaturated(visual.desaturated ~= false)
			end
			texture:SetVertexColor(tint, tint, tint, alpha)
			texture:SetAlpha(alpha)
		end
	end
	if dropdown.Text then
		local color = visual.inputTextColor
			or { 0.78, 0.77, 0.72, 1 }
		dropdown.Text:SetTextColor(
			color[1],
			color[2],
			color[3],
			color[4]
		)
		dropdown.Text:SetAlpha(alpha)
	end
	dropdown[stateKey] = true
end

function GF.UI.SetHoverTooltipOwner(owner, anchor)
	local tooltip = GameTooltip
	if owner == nil or tooltip == nil or tooltip.SetOwner == nil then
		return
	end
	if anchor then
		tooltip:SetOwner(owner, anchor)
		return
	end
	local leftEdge = owner.GetLeft and owner:GetLeft()
	local automaticAnchor = leftEdge and leftEdge > 500 and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
	tooltip:SetOwner(owner, automaticAnchor)
end

function GF.UI.BeginGameTooltip(owner, anchor)
	local tooltip = GameTooltip
	if owner == nil or tooltip == nil then
		return
	end
	GF.UI.SetHoverTooltipOwner(owner, anchor)
	local applyFont = GF.Font and GF.Font.BeginTooltipFont
	if applyFont then
		applyFont(tooltip)
	end
end

function GF.UI.BeginGameTooltipAbove(owner, align)
	local tooltip = GameTooltip
	if owner == nil or tooltip == nil then
		return
	end
	tooltip:SetOwner(owner, "ANCHOR_NONE")
	if tooltip.ClearAllPoints then
		tooltip:ClearAllPoints()
	end
	local gap = GF.TOOLTIP_BUTTON_TOP_GAP or 4
	local tooltipPoint, ownerPoint
	if align == "RIGHT" then
		tooltipPoint, ownerPoint = "BOTTOMRIGHT", "TOPRIGHT"
	elseif align == "LEFT" then
		tooltipPoint, ownerPoint = "BOTTOMLEFT", "TOPLEFT"
	else
		tooltipPoint, ownerPoint = "BOTTOM", "TOP"
	end
	tooltip:SetPoint(tooltipPoint, owner, ownerPoint, 0, gap)
	local applyFont = GF.Font and GF.Font.BeginTooltipFont
	if applyFont then
		applyFont(tooltip)
	end
end

function GF.UI.ApplyGameTooltipFont(tooltip)
	local target = tooltip or GameTooltip
	local apply = GF.Font and GF.Font.ApplyTooltipFont
	if apply then
		apply(target)
	end
end

function GF.UI.ShowGameTooltip(tooltip)
	local target = tooltip or GameTooltip
	GF.UI.ApplyGameTooltipFont(target)
	if target and target.Show then
		target:Show()
	end
end

local function showPlainTooltip(owner, text, anchor, above)
	local tooltip = GameTooltip
	if owner == nil or text == nil or text == "" or tooltip == nil or tooltip.SetText == nil then
		return
	end
	if above then
		GF.UI.BeginGameTooltipAbove(owner, anchor)
	else
		GF.UI.BeginGameTooltip(owner, anchor)
	end
	tooltip.SetText(tooltip, text, nil, nil, nil, nil, true)
	local showTooltip = GF.UI.ShowGameTooltip
	showTooltip(tooltip)
end

function GF.UI.ShowSimpleTooltip(owner, text, anchor)
	showPlainTooltip(owner, text, anchor, false)
end

function GF.UI.ShowSimpleTooltipAbove(owner, text, align)
	showPlainTooltip(owner, text, align, true)
end

function GF.UI.SetTooltipText(text, r, g, b)
	local tooltip = GameTooltip
	if tooltip == nil or tooltip.SetText == nil or text == nil or text == "" then
		return
	end
	local red = r or GF.UI.TOOLTIP_GOLD_R
	local green = g or GF.UI.TOOLTIP_GOLD_G
	local blue = b or GF.UI.TOOLTIP_GOLD_B
	tooltip:SetText(text, red, green, blue, 1, true)
end

function GF.UI.ShowApplicantBlockTooltip(btn, reason)
	if btn == nil or reason == nil then
		return
	end
	local actions = GF.ApplicantActionService
	local message = actions and actions.GetBlockReasonText
		and actions:GetBlockReasonText(reason)
	if message == nil or message == "" then
		return
	end
	GF.UI.BeginGameTooltip(btn)
	GF.UI.SetTooltipText(message)
	GF.UI.ShowGameTooltip()
end

local function beginBoundButtonTooltip(btn, placement)
	if placement == "aboveRight" then
		GF.UI.BeginGameTooltipAbove(btn, "RIGHT")
	elseif placement == "aboveLeft" then
		GF.UI.BeginGameTooltipAbove(btn, "LEFT")
	elseif placement == "above" then
		GF.UI.BeginGameTooltipAbove(btn)
	else
		GF.UI.BeginGameTooltip(btn)
	end
end

local ACTION_GUARDS = {
	listing_leader = {
		allowed = function(listing)
			return listing and listing.CanPublish and listing:CanPublish()
		end,
		message = function(listing)
			return listing and listing.GetLeaderOnlyMessage and listing:GetLeaderOnlyMessage()
		end,
		notify = function(listing)
			if listing and listing.NotifyLeaderOnly then
				listing:NotifyLeaderOnly()
			end
		end,
	},
	manage_entry = {
		allowed = function(listing)
			return listing and listing.CanManageApplicants and listing:CanManageApplicants()
		end,
		message = function()
			local actions = GF.ApplicantActionService
			return actions and actions.GetBlockReasonText
				and actions:GetBlockReasonText("unempowered")
		end,
		notify = function()
			local actions = GF.ApplicantActionService
			if actions and actions.NotifyBlocked then
				actions:NotifyBlocked("unempowered")
			end
		end,
	},
}

function GF.UI.AttachActionGuard(btn, spec)
	if btn == nil then
		return
	end
	local options = spec or {}
	local policy = ACTION_GUARDS[options.capability]
	if policy == nil then
		return
	end
	if btn.SetMotionScriptsWhileDisabled then
		btn:SetMotionScriptsWhileDisabled(true)
	end
	local function evaluate()
		local listing = GF.RecruitmentSession
		return policy.allowed(listing) == true, listing
	end
	local function onEnter(self)
		if GF.UI.SetCommonPanelButtonHovered then
			GF.UI.SetCommonPanelButtonHovered(self, true)
		end
		local permitted, listing = evaluate()
		if not permitted then
			local message = policy.message(listing)
			if message and message ~= "" then
				beginBoundButtonTooltip(self, options.tooltipPlacement)
				GF.UI.SetTooltipText(message)
				GF.UI.ShowGameTooltip()
			end
			return
		end
		if options.onAllowedHover then
			options.onAllowedHover(self)
		end
	end
	local function onLeave(self)
		if GF.UI.SetCommonPanelButtonHovered then
			GF.UI.SetCommonPanelButtonHovered(self, false)
		end
		if GameTooltip then
			GameTooltip:Hide()
		end
	end
	local function click(self)
		local permitted, listing = evaluate()
		if not permitted then
			policy.notify(listing)
			return
		end
		if options.onClick then
			options.onClick(self)
		end
	end
	btn:SetScript("OnEnter", onEnter)
	btn:SetScript("OnLeave", onLeave)
	btn:SetScript("OnClick", click)
end

function GF.UI.CreatePanelButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width or 80, GF.PANEL_BUTTON_H or 24)
	button:SetText(text or "")
	local tracker = GF.Font and GF.Font.TrackButton
	if tracker then
		tracker(button, "GameFontNormal")
	end
	GF.UI.ApplyCommonPanelButtonSkin(button)
	return button
end

function GF.UI.ApplyPlayerContextDialogButtonFont(button)
	if not button then
		return
	end
	local fontString = button.Label
		or (button.GetFontString and button:GetFontString())
	if not fontString then
		return
	end
	local style = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}
	fontString._gfFontSizeOverride = style.BUTTON_FONT_SIZE or 15
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(
			fontString,
			fontString._gfFontTemplate or "GameFontNormal")
	end
end

function GF.UI.ApplyPlayerContextDialogTextStyle(fontString, role)
	if not fontString then
		return
	end
	local style = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}
	local accent = role == "accent"
	local primary = role == "primary" or accent
	local size = accent and style.ACCENT_TEXT_FONT_SIZE
		or (primary and style.PRIMARY_TEXT_FONT_SIZE
			or style.SECONDARY_TEXT_FONT_SIZE)
	local color = accent and style.ACCENT_TEXT_COLOR
		or (primary and style.PRIMARY_TEXT_COLOR
			or style.SECONDARY_TEXT_COLOR)
	fontString._gfFontSizeOverride = size or (primary and 15 or 12)
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(
			fontString,
			fontString._gfFontTemplate
				or (primary and "GameFontHighlight" or "GameFontHighlightSmall"))
	end
	fontString:SetJustifyH("CENTER")
	if fontString.SetJustifyV then
		fontString:SetJustifyV("MIDDLE")
	end
	if fontString.SetWordWrap then
		fontString:SetWordWrap(false)
	end
	if fontString.SetMaxLines then
		fontString:SetMaxLines(1)
	end
	if color and fontString.SetTextColor then
		fontString:SetTextColor(
			color[1] or 1,
			color[2] or 1,
			color[3] or 1,
			color[4] or 1)
	end
end

function GF.UI.CreatePlayerContextDialogContentHost(parent)
	if not parent then
		return nil
	end
	local style = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}
	local horizontalInset = style.CONTENT_INSET_X or 36
	local topInset = style.CONTENT_TOP_INSET or 38
	local actionTopInset = (style.CONTENT_BOTTOM_INSET or 18)
		+ (style.BUTTON_HEIGHT or GF.PANEL_BUTTON_H or 24)
		+ (style.CONTENT_ACTION_GAP or 12)
	local host = CreateFrame("Frame", nil, parent)
	host:SetPoint(
		"TOPLEFT",
		parent,
		"TOPLEFT",
		horizontalInset,
		-topInset)
	host:SetPoint(
		"BOTTOMRIGHT",
		parent,
		"BOTTOMRIGHT",
		-horizontalInset,
		actionTopInset)
	return host
end

function GF.UI.CreateHelpIcon(parent, tooltipText, size)
	local extent = size or 30
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(extent, extent)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Common\\help-i")
	icon:SetSize(extent, extent)
	icon:SetPoint("CENTER")
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Common\\help-i")
	highlight:SetBlendMode("ADD")
	highlight:SetSize(extent, extent)
	highlight:SetPoint("CENTER")
	button:SetScript("OnEnter", function(self)
		local text = self._gfTooltip or tooltipText
		if text and text ~= "" then
			GF.UI.ShowSimpleTooltip(self, text, "ANCHOR_RIGHT")
		end
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button._gfTooltip = tooltipText
	return button
end

-- FontString 定宽 + 引擎省略（申请者 / 组队 Browse 共用）
function GF.UI.SetEllipsisText(fontString, text, width)
	if fontString == nil then
		return
	end
	local availableWidth = width or fontString:GetWidth() or 0
	fontString:SetWordWrap(false)
	fontString:SetMaxLines(1)
	if availableWidth > 0 then
		fontString:SetWidth(availableWidth)
	end
	fontString:SetText(text or "")
end

-- 申请者卡片：MyKeyStone-style 1:1 icon action buttons.
local function setApplicantActionButtonTexture(button, state)
	local bg = button and button.applicantActionBg
	if not bg then
		return
	end
	GF.UI.SetCommonButtonTextureState(bg, state or BUTTON_VISUAL_STATE.NORMAL, "square")
end

local function refreshApplicantActionButtonState(button)
	if not button then
		return
	end
	local enabled = not button.IsEnabled or button:IsEnabled()
	local state = BUTTON_VISUAL_STATE.NORMAL
	if not enabled then
		state = BUTTON_VISUAL_STATE.DISABLED
	elseif button._gfApplicantActionPressed then
		state = BUTTON_VISUAL_STATE.PRESSED
	elseif enabled and button._gfApplicantActionHovered then
		state = BUTTON_VISUAL_STATE.HOVER
	end
	local visual = GF.UI.GetCommonButtonVisual(state)
	setApplicantActionButtonTexture(button, state)
	if button.applicantActionBg then
		if button.applicantActionBg.SetDesaturated then
			button.applicantActionBg:SetDesaturated(visual.desaturated == true)
		end
		button.applicantActionBg:SetVertexColor(
			visual.textureColor[1],
			visual.textureColor[2],
			visual.textureColor[3],
			visual.textureColor[4])
		button.applicantActionBg:SetAlpha(1)
	end
	local iconR, iconG, iconB, iconAlpha = unpack(visual.iconColor)
	if button.icon then
		button.icon:SetVertexColor(iconR, iconG, iconB, 1)
		button.icon:SetAlpha(iconAlpha)
	end
	if button.fallback then
		button.fallback:SetAlpha(iconAlpha)
		if button.fallback.SetTextColor then
			button.fallback:SetTextColor(iconR, iconG, iconB, 1)
		end
	end
end

local function createApplicantActionButton(parent, atlas, fallbackText)
	local size = GF.APPLICANT_ACTION_BUTTON_SIZE or 24
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(size, size)
	local btn = CreateFrame("Button", nil, holder)
	btn:SetSize(size, size)
	btn:SetAllPoints(holder)
	btn:SetMotionScriptsWhileDisabled(true)
	btn:SetText("")
	GF.UI.ClearButtonStateTexture(btn, "Normal")
	GF.UI.ClearButtonStateTexture(btn, "Pushed")
	GF.UI.ClearButtonStateTexture(btn, "Highlight")
	GF.UI.ClearButtonStateTexture(btn, "Disabled")
	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(btn)
	bg:SetTexture(COMMON_BUTTON_PATH)
	bg:SetVertexColor(1, 1, 1, 1)
	bg:SetAlpha(1)
	if bg.SetBlendMode then
		bg:SetBlendMode("BLEND")
	end
	btn.applicantActionBg = bg
	setApplicantActionButtonTexture(btn, BUTTON_VISUAL_STATE.NORMAL)
	local label = btn.Text or (btn.GetFontString and btn:GetFontString())
	if label then
		label:SetText("")
		label:Hide()
	end
	local icon = btn:CreateTexture(nil, "OVERLAY", nil, 2)
	if not trySetAtlas(icon, atlas, false) then
		icon:Hide()
		local fallback = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fallback:SetPoint("CENTER", btn, "CENTER", 0, 0)
		fallback:SetText(fallbackText or "")
		fallback:SetJustifyH("CENTER")
		fallback:SetJustifyV("MIDDLE")
		if GF.Font and GF.Font.Track then
			fallback._gfFontSizeOverride = 18
			fallback._gfFontFlagsOverride = "OUTLINE"
			GF.Font.Track(fallback, "GameFontHighlight")
		end
		btn.fallback = fallback
	else
		icon:SetSize(GF.APPLICANT_ACTION_ICON_SIZE or 12, GF.APPLICANT_ACTION_ICON_SIZE or 12)
		icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
		btn.icon = icon
	end
	holder.button = btn
	btn:HookScript("OnEnter", function(self)
		self._gfApplicantActionHovered = true
		refreshApplicantActionButtonState(self)
	end)
	btn:HookScript("OnLeave", function(self)
		self._gfApplicantActionHovered = nil
		self._gfApplicantActionPressed = nil
		refreshApplicantActionButtonState(self)
	end)
	btn:HookScript("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton" and (not self.IsEnabled or self:IsEnabled()) then
			self._gfApplicantActionPressed = true
			refreshApplicantActionButtonState(self)
		end
	end)
	btn:HookScript("OnMouseUp", function(self)
		self._gfApplicantActionPressed = nil
		if not (self.IsMouseOver and self:IsMouseOver()) then
			self._gfApplicantActionHovered = nil
		end
		refreshApplicantActionButtonState(self)
	end)
	btn:HookScript("OnEnable", refreshApplicantActionButtonState)
	btn:HookScript("OnDisable", refreshApplicantActionButtonState)
	btn.RefreshApplicantActionState = refreshApplicantActionButtonState
	refreshApplicantActionButtonState(btn)
	return holder, btn
end

function GF.UI.CreateApplicantInviteButton(parent)
	local holder, button = createApplicantActionButton(parent, "UI-LFG-ReadyMark", "✓")
	return holder, button
end

function GF.UI.CreateApplicantDeclineButton(parent)
	local holder, button = createApplicantActionButton(parent, "UI-LFG-DeclineMark", "×")
	return holder, button
end

function GF.UI.GetCategoryTitle(categoryID, activityInfo)
	local activity = activityInfo
	if activity then
		for _, field in ipairs({ "fullName", "shortName" }) do
			local value = activity[field]
			if value and value ~= "" then
				return value
			end
		end
	end
	local category = categoryID and C_LFGList.GetLfgCategoryInfo(categoryID)
	return category and category.name or ""
end

function GF.UI.ApplySettingsFrameChrome(frame, title)
	if frame == nil then
		return
	end
	if frame.Bg then
		frame.Bg:Hide()
	end
	local titleText = title or "GroupFinder"
	local fontString = resolveSystemPanelTitleText(frame)
	if fontString then
		applySystemPanelTitleStyle(fontString)
		frame.systemTitleText, frame.titletext = fontString, fontString
	end
	if frame.SetTitle then
		pcall(frame.SetTitle, frame, titleText)
		fontString = frame.systemTitleText or resolveSystemPanelTitleText(frame)
	end
	if fontString then
		fontString:SetText(titleText)
		applySystemPanelTitleStyle(fontString)
		centerSystemPanelTitle(frame, fontString)
		frame.systemTitleText, frame.titletext = fontString, fontString
	end
end

function GF.UI.GetMainFrame()
	local controller = GF.MainFrame
	return controller and controller.frame or nil
end

local satelliteFrames = {}

function GF.UI.RegisterSatelliteFrame(frame)
	if frame == nil then
		return
	end
	for _, registered in ipairs(satelliteFrames) do
		if registered == frame then
			return
		end
	end
	table.insert(satelliteFrames, frame)
	if GF.ApplyPanelScale then
		GF.ApplyPanelScale()
	elseif GF.GetPanelScale and frame.SetScale then
		local desiredScale = GF.GetPanelScale()
		local current = frame.GetScale and frame:GetScale()
		if current == nil or math.abs(current - desiredScale) > 0.0001 then
			frame:SetScale(desiredScale)
		end
	end
	local applyLayers = GF.UI.ApplySatelliteFrameLayers
	if applyLayers then applyLayers() end
end

function GF.UI.RaiseFrame(frame)
	if frame and frame.Raise then
		frame:Raise()
		if frame == GF.UI.GetMainFrame() and GF.UI.RaiseMainFrameSatelliteGroup then
			GF.UI.RaiseMainFrameSatelliteGroup()
		end
	end
end

-- UIParent 独立窗 + 跟随主框 strata/level；需要浮在主框上方的窗口可设置 levelOffset/raise。
function GF.UI.ApplySatelliteFrameLayers(strataOverride)
	local mainFrame = GF.UI.GetMainFrame()
	local strata = strataOverride
		or (mainFrame and mainFrame.GetFrameStrata and mainFrame:GetFrameStrata())
		or (GF.GetFrameStrata and GF.GetFrameStrata())
		or "MEDIUM"
	local mainLevel = mainFrame and mainFrame.GetFrameLevel and mainFrame:GetFrameLevel()
	for i = 1, #satelliteFrames do
		local f = satelliteFrames[i]
		if f and f.SetFrameStrata then
			f:SetFrameStrata(strata)
		end
		if f and f.SetFrameLevel and mainLevel then
			f:SetFrameLevel(mainLevel + (f._gfLevelOffset or 5))
		end
		if f and f._gfOnSatelliteFrameLayersApplied then
			f:_gfOnSatelliteFrameLayersApplied(strata, mainLevel)
		end
	end
end

function GF.UI.RaiseMainFrameSatelliteGroup()
	local mainFrame = GF.UI.GetMainFrame()
	if not mainFrame then
		return
	end
	if mainFrame.Raise then
		mainFrame:Raise()
	end
	if GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
	for i = 1, #satelliteFrames do
		local f = satelliteFrames[i]
		if f and f._gfFollowMainFrameRaise
			and (not f.IsShown or f:IsShown()) then
			if f.Raise then
				f:Raise()
			end
			if f._gfOnSatelliteFrameLayersApplied then
				f:_gfOnSatelliteFrameLayersApplied(
					f.GetFrameStrata and f:GetFrameStrata(),
					mainFrame.GetFrameLevel and mainFrame:GetFrameLevel()
				)
			end
		end
	end
end

function GF.UI.ApplySatelliteFrameScale(scale)
	scale = tonumber(scale) or (GF.GetPanelScale and GF.GetPanelScale()) or 1
	local appliedAll = true
	for i = 1, #satelliteFrames do
		local f = satelliteFrames[i]
		if f and f.SetScale then
			if GF.TryApplyPanelScaleToFrame then
				if not GF.TryApplyPanelScaleToFrame(f, scale) then
					appliedAll = false
				end
			else
				local currentScale = f.GetScale and f:GetScale()
				if currentScale == nil or math.abs(currentScale - scale) > 0.0001 then
					local protectedInCombat = InCombatLockdown and InCombatLockdown()
						and f.IsProtected and f:IsProtected()
					if protectedInCombat then
						appliedAll = false
					else
						f:SetScale(scale)
					end
				end
			end
		end
	end
	return appliedAll
end

function GF.UI.InstallSatelliteFrame(frame, opts)
	if frame == nil then
		return
	end
	local options = opts or {}
	frame._gfLevelOffset = options.levelOffset or 5
	frame._gfRaiseSatelliteFrame = options.raise ~= false
	frame._gfFollowMainFrameRaise = options.followMainRaise == true
	if frame.SetToplevel then
		frame:SetToplevel(options.toplevel ~= false)
	end
	GF.UI.RegisterSatelliteFrame(frame)
	if frame._gfSatelliteStackingInstalled then
		return
	end
	frame._gfSatelliteStackingInstalled = true
	local function raiseConfiguredWindow()
		if frame._gfFollowMainFrameRaise and GF.UI.RaiseMainFrameSatelliteGroup then
			GF.UI.RaiseMainFrameSatelliteGroup()
		elseif frame._gfRaiseSatelliteFrame then
			GF.UI.RaiseFrame(frame)
		else
			GF.UI.ApplySatelliteFrameLayers()
		end
	end
	local function shown()
		GF.UI.ApplySatelliteFrameLayers()
		if GF.ApplyPanelScale then
			GF.ApplyPanelScale()
		else
			GF.UI.ApplySatelliteFrameScale()
		end
		raiseConfiguredWindow()
	end
	frame:HookScript("OnShow", shown)
	frame:HookScript("OnMouseDown", raiseConfiguredWindow)
end

function GF.UI.CenterOnMainFrame(frame, offsetY)
	if frame == nil then
		return
	end
	local verticalOffset = offsetY or 0
	local anchor = GF.UI.GetMainFrame()
	frame:ClearAllPoints()
	local parent = anchor or UIParent
	local finalOffset = anchor and verticalOffset or (verticalOffset + 40)
	frame:SetPoint("CENTER", parent, "CENTER", 0, finalOffset)
end

function GF.UI.CenterOnUIParent(frame, offsetY)
	if frame == nil then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY or 0)
end

function GF.UI.CreateSatelliteSettingsFrame(opts)
	local options = opts or {}
	local frame = CreateFrame(
		"Frame", options.name or "GroupFinderAddonSatelliteDialog", UIParent, "SettingsFrameTemplate")
	frame:SetSize(options.width or 480, options.height or 400)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()
	GF.UI.InstallSatelliteFrame(frame, { levelOffset = options.levelOffset or 5 })
	GF.UI.InstallBodyBackground(frame, {
		layout = "main",
		color = options.backgroundColor,
	})
	GF.UI.ApplySettingsFrameChrome(frame, options.title or "")
	GF.UI.SetupTitleDragBar(frame)
	if frame.ClosePanelButton and options.onClose then
		frame.ClosePanelButton:SetScript("OnClick", options.onClose)
	end
	local name = frame.GetName and frame:GetName()
	if UISpecialFrames and name then
		tinsert(UISpecialFrames, name)
	end
	return frame
end

function GF.UI.PresentSatelliteFrame(frame, opts)
	if frame == nil then
		return
	end
	local options = opts or {}
	if options.title then
		GF.UI.ApplySettingsFrameChrome(frame, options.title)
	end
	if options.prepare then
		options.prepare(frame)
	end
	if options.refreshBackground ~= false then
		GF.UI.ApplyBodyBackground(frame)
	end
	if options.centerOnUIParent == true then
		GF.UI.CenterOnUIParent(frame, options.offsetY or 0)
	else
		GF.UI.CenterOnMainFrame(frame, options.offsetY or 0)
	end
	frame:Show()
	if options.onShown then
		options.onShown(frame)
	end
end

function GF.UI.SetupTitleDragBar(frame, onDragStop)
	if frame == nil or frame.gfDragBar then
		return frame and frame.gfDragBar
	end
	frame:SetMovable(true)
	local dragTarget = CreateFrame("Frame", nil, frame)
	dragTarget:SetPoint("TOPLEFT", frame, "TOPLEFT",
		GF.MAIN_WINDOW_DRAG_HANDLE_LEFT_INSET or 76,
		GF.MAIN_WINDOW_DRAG_HANDLE_TOP_OFFSET or 0)
	dragTarget:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT",
		-(GF.MAIN_WINDOW_DRAG_HANDLE_RIGHT_INSET or 78),
		GF.MAIN_WINDOW_DRAG_HANDLE_BOTTOM_OFFSET or -40)
	dragTarget:EnableMouse(true)
	dragTarget:RegisterForDrag("LeftButton")
	local function startMove()
		GF.UI.RaiseFrame(frame)
		if not frame._gfTitleMoving then
			frame._gfTitleMoving = true
			frame:StartMoving()
		end
	end
	local function stopMove()
		if not frame._gfTitleMoving then
			return
		end
		frame._gfTitleMoving = false
		frame:StopMovingOrSizing()
		if onDragStop then
			onDragStop(frame)
		end
	end
	dragTarget:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			startMove()
		else
			GF.UI.RaiseFrame(frame)
		end
	end)
	for _, eventName in ipairs({ "OnMouseUp", "OnDragStop", "OnHide" }) do
		dragTarget:SetScript(eventName, stopMove)
	end
	dragTarget:SetScript("OnDragStart", startMove)
	dragTarget:SetFrameLevel(frame:GetFrameLevel() + 50)
	frame.gfDragBar = dragTarget
	return dragTarget
end

function GF.GetWheelScrollRows()
	local minimum = GF.LIST_WHEEL_ROWS_MIN or 1
	local maximum = GF.LIST_WHEEL_ROWS_MAX or 10
	local database = GF.GetDB()
	local fallback = GF.LIST_WHEEL_ROWS_DEFAULT or 3
	local configured = database and database.listWheelScrollRows
	local numeric = tonumber(configured == nil and fallback or configured) or fallback
	local rounded = math.floor(numeric + 0.5)
	return math.min(maximum, math.max(minimum, rounded))
end

function GF.GetWheelScrollPixels(rowHeight)
	local height = rowHeight or GF.LIST_ROW_H or 52
	return height * GF.GetWheelScrollRows()
end

function GF.UI.BindRowWheelScrolling(scroll, force)
	if not scroll then
		return
	end
	local rowHeight = scroll._gfWheelRowH or GF.LIST_ROW_H or 52
	scroll._gfWheelRowH = rowHeight
	if scroll._gfWheelInstalled and not force then
		return
	end
	scroll._gfWheelInstalled = true
	scroll:EnableMouseWheel(true)
	local initialStep = GF.GetWheelScrollPixels(rowHeight)
	if type(scroll.SetPanExtent) == "function" then
		scroll:SetPanExtent(initialStep)
	end

	local function onWheel(frame, direction)
		if type(direction) ~= "number" or direction == 0 then
			return
		end
		local allow = frame._gfWheelAllow
		if type(allow) == "function" and not allow() then
			return
		end
		local pixels = GF.GetWheelScrollPixels(frame._gfWheelRowH)
		if type(frame.SetPanExtent) == "function" then
			frame:SetPanExtent(pixels)
		end
		local current = tonumber(frame:GetVerticalScroll()) or 0
		local limit = tonumber(frame:GetVerticalScrollRange()) or 0
		local destination = current - direction * pixels
		destination = math.min(limit, math.max(0, destination))
		frame:SetVerticalScroll(destination)
		if type(frame._gfOnWheelScrolled) == "function" then
			frame._gfOnWheelScrolled(frame, destination, direction)
		end
	end
	scroll:SetScript("OnMouseWheel", onWheel)
end

function GF.UI.CreateScrollFrame(parent, opts)
	local options = opts or {}
	local frame = CreateFrame("ScrollFrame", nil, parent)
	frame._gfWheelRowH = options.rowHeight or GF.LIST_ROW_H or 52
	frame:SetClipsChildren(true)
	GF.UI.BindRowWheelScrolling(frame)
	return frame
end

function GF.UI.HideLegacyScrollBar(scroll)
	if scroll == nil then
		return
	end
	local attachedBar = scroll.ScrollBar
	if attachedBar and attachedBar.Hide then
		attachedBar:Hide()
	end
	local frameName = scroll.GetName and scroll:GetName()
	if frameName then
		local namedBar = _G[frameName .. "ScrollBar"]
		if namedBar and namedBar.Hide then
			namedBar:Hide()
		end
	end
end

local CHROME_LIGHT_A_HORZ = 0.22
local CHROME_LIGHT_A_VERT = 0.16

local function InstallBevelDivider(parent, orient)
	local shadow = parent:CreateTexture(nil, "OVERLAY")
	local highlight = parent:CreateTexture(nil, "OVERLAY")
	shadow:SetColorTexture(0, 0, 0, 0.58)
	local highlightAlpha = orient == "horiz" and CHROME_LIGHT_A_HORZ or CHROME_LIGHT_A_VERT
	highlight:SetColorTexture(0.82, 0.78, 0.68, highlightAlpha)
	if orient == "horiz" then
		local leftInset = GF.FRAME_PAD or 4
		highlight:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", leftInset, 0)
		highlight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
		highlight:SetHeight(1)
		shadow:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", leftInset, 1)
		shadow:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 1)
		shadow:SetHeight(1)
	else
		shadow:SetPoint("TOPLEFT", parent, "TOPLEFT")
		shadow:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT")
		shadow:SetWidth(1)
		highlight:SetPoint("TOPLEFT", shadow, "TOPRIGHT")
		highlight:SetPoint("BOTTOMLEFT", shadow, "BOTTOMRIGHT")
		highlight:SetWidth(1)
	end
end

function GF.UI.CommitRelayoutSig(panel)
	local signatureProvider = panel and panel.GetRelayoutSig
	if signatureProvider == nil then
		return
	end
	local signature = signatureProvider(panel)
	if signature then
		panel._relayoutSig = signature
	end
end

function GF.UI.RefreshListLayoutIfReady(panel, pass)
	local attempt = tonumber(pass) or 0
	if panel == nil or attempt > 5 then
		return
	end
	local list = panel.scrollList
	if list == nil or type(panel.GetRelayoutSig) ~= "function"
		or type(panel.Relayout) ~= "function" then
		return
	end
	local mainWindow = GF.MainFrame and GF.MainFrame.frame
	if mainWindow == nil or not mainWindow:IsShown() then
		return
	end
	local parent = panel.parent
	if parent and not parent:IsShown() then
		return
	end
	if panel._frameResizing or GF._frameResizing then
		return
	end
	if type(panel.UpdateScrollWidth) == "function" then
		panel:UpdateScrollWidth()
	end
	local width = tonumber(list:GetLayoutWidth()) or 0
	if width <= 1 then
		local controller = GF.MainFrame
		if controller and type(controller.ScheduleWhenShown) == "function" then
			controller:ScheduleWhenShown(0, function()
				GF.UI.RefreshListLayoutIfReady(panel, attempt + 1)
			end)
		end
		return
	end
	local signature = panel:GetRelayoutSig()
	if signature ~= nil and signature == panel._relayoutSig then
		if type(list.RetainScrollPosition) == "function" then
			list:RetainScrollPosition()
		end
		return
	end
	panel:Relayout({ force = true })
end

local function setTextureColor(texture, color)
	if not texture or not color then
		return
	end
	texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function setBrowseDividerAccentGradient(texture, startAlpha, endAlpha)
	if not texture then
		return
	end
	local color = GF.NAV_DIVIDER_CENTER_ACCENT_COLOR or { 1, 0.82, 0 }
	local r, g, b = color[1] or 1, color[2] or 0.82, color[3] or 0
	if texture.SetGradient and CreateColor then
		local ok = pcall(texture.SetGradient, texture, "VERTICAL", CreateColor(r, g, b, startAlpha), CreateColor(r, g, b, endAlpha))
		if ok then
			return
		end
	end
	if texture.SetGradientAlpha then
		texture:SetGradientAlpha("VERTICAL", r, g, b, startAlpha, r, g, b, endAlpha)
	else
		texture:SetVertexColor(r, g, b, math.max(startAlpha or 0, endAlpha or 0))
	end
end

local function createBrowseDividerCenterAccent(parent)
	local accent = CreateFrame("Frame", nil, parent)
	accent:SetPoint("TOP", parent, "TOP", 0, 0)
	accent:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
	accent:SetPoint("CENTER", parent, "CENTER", 0, 0)
	accent:SetWidth(GF.NAV_DIVIDER_CENTER_ACCENT_W or 1)

	local top = accent:CreateTexture(nil, "OVERLAY")
	top:SetTexture(WHITE)
	top:SetPoint("TOPLEFT", accent, "TOPLEFT", 0, 0)
	top:SetPoint("BOTTOMRIGHT", accent, "RIGHT", 0, 0)
	setBrowseDividerAccentGradient(top, 1, 0)

	local bottom = accent:CreateTexture(nil, "OVERLAY")
	bottom:SetTexture(WHITE)
	bottom:SetPoint("TOPLEFT", accent, "LEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", accent, "BOTTOMRIGHT", 0, 0)
	setBrowseDividerAccentGradient(bottom, 0, 1)

	accent.Top = top
	accent.Bottom = bottom
	return accent
end

function GF.UI.InstallNavColumnDivider(host)
	if not host or host._gfMeetingStoneDivider then
		return
	end
	host:SetWidth(GF.NAV_DIVIDER_W or 3)

	local function addLine(layer, subLevel, color)
		local tex = host:CreateTexture(nil, layer or "ARTWORK", nil, subLevel or 0)
		tex:SetTexture(GF.WHITE_TEXTURE)
		setTextureColor(tex, color)
		return tex
	end

	local leftShadow = addLine("ARTWORK", 1, GF.NAV_DIVIDER_SHADOW_COLOR)
	leftShadow:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
	leftShadow:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
	leftShadow:SetWidth(2)

	local center = addLine("ARTWORK", 2, GF.NAV_DIVIDER_COLOR)
	center:SetPoint("TOPLEFT", leftShadow, "TOPRIGHT", 0, 0)
	center:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 0)

	local highlight = addLine("ARTWORK", 3, GF.NAV_DIVIDER_HIGHLIGHT_COLOR)
	highlight:SetPoint("TOPLEFT", center, "TOPLEFT", 0, 0)
	highlight:SetPoint("BOTTOMLEFT", center, "BOTTOMLEFT", 0, 0)
	highlight:SetWidth(1)

	local rightShadow = addLine("ARTWORK", 1, GF.NAV_DIVIDER_SHADOW_COLOR)
	rightShadow:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
	rightShadow:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
	rightShadow:SetWidth(2)

	local centerAccent = createBrowseDividerCenterAccent(host)
	host.CenterAccent = centerAccent

	host._gfMeetingStoneDivider = {
		center = center,
		leftShadow = leftShadow,
		highlight = highlight,
		rightShadow = rightShadow,
		centerAccent = centerAccent,
	}
end

function GF.UI.LayoutNavColumnDivider(host)
	local leftPanel = host and host:GetParent()
	if not host or not leftPanel then
		return
	end
	host:ClearAllPoints()
	host:SetPoint("TOP", leftPanel, "TOPRIGHT", GF.NAV_DIVIDER_OFFSET_X or -3, -(GF.NAV_DIVIDER_TOP_OFFSET or 4))
	host:SetPoint("BOTTOM", leftPanel, "BOTTOMRIGHT", GF.NAV_DIVIDER_OFFSET_X or -3, GF.NAV_DIVIDER_BOTTOM_OFFSET or 2)
	host:SetWidth(GF.NAV_DIVIDER_W or 3)
	host:SetFrameLevel((leftPanel:GetFrameLevel() or 1) + 6)
end

function GF.UI.ApplySubtitleChrome(frame)
	if frame == nil or frame._gfSubtitleChrome then
		return
	end
	frame._gfSubtitleChrome = true
	InstallBevelDivider(frame, "horiz")
end

local function ResetBodyBgTexState(fill)
	fill:SetHorizTile(false)
	fill:SetVertTile(false)
	fill:SetTexCoord(0, 1, 0, 1)
end

function GF.UI.LayoutBodyBackground(frame)
	local background = frame and frame.gfBodyBg
	local fill = background and background.fill
	if fill == nil then
		return
	end
	local options = frame._gfBodyBgOpts or {}
	fill:ClearAllPoints()
	if options.layout == "fill" then
		fill:SetAllPoints(frame)
	else
		fill:SetPoint("TOPLEFT", frame, "TOPLEFT",
			GF.FRAME_BG_INSET_LEFT or 7, GF.FRAME_BG_INSET_TOP or -18)
		fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
			GF.FRAME_BG_INSET_RIGHT or -2, GF.FRAME_BG_INSET_BOTTOM or 3)
	end
end

local function bodyBackgroundCacheKey(prefix, color, defaults)
	return string.format(
		prefix .. ":%.4f:%.4f:%.4f:%.4f",
		color[1] or defaults[1], color[2] or defaults[2],
		color[3] or defaults[3], color[4] or defaults[4])
end

local function renderBodyBackgroundFill(fill, cacheKey, color, defaults)
	if fill._gfBodyBgCache == cacheKey then
		fill:Show()
		return
	end
	fill._gfBodyBgCache = cacheKey
	fill:SetAtlas(nil)
	fill:SetTexture(nil)
	ResetBodyBgTexState(fill)
	fill:SetColorTexture(
		color[1] or defaults[1], color[2] or defaults[2],
		color[3] or defaults[3], color[4] or defaults[4])
	fill:Show()
end

function GF.UI.ApplyBodyBackground(frame)
	local background = frame and frame.gfBodyBg
	local options = frame and frame._gfBodyBgOpts
	local fill = background and background.fill
	if fill == nil or options == nil then
		return
	end
	if frame.Bg then
		frame.Bg:Hide()
	end
	GF.UI.LayoutBodyBackground(frame)
	local panelStyle = options.style == "panelBackplate"
	local defaults = panelStyle and { 0, 0, 0, 1 } or { 0.05, 0.05, 0.08, 0.75 }
	local color = options.color
		or (panelStyle and (GF.MAIN_PANEL_BACKPLATE_BG_COLOR or defaults)
			or (GF.BODY_BACKGROUND_COLOR or defaults))
	local prefix = panelStyle and "panelBackplate" or "body"
	renderBodyBackgroundFill(fill, bodyBackgroundCacheKey(prefix, color, defaults), color, defaults)
end

function GF.UI.InstallBodyBackground(frame, opts)
	if frame == nil then
		return
	end
	frame._gfBodyBgOpts = opts or {}
	if frame.gfBodyBg == nil then
		local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		frame.gfBodyBg = { fill = fill }
	end
	GF.UI.ApplyBodyBackground(frame)
end

function GF.UI.CreateContentPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	return panel
end

function GF.UI.StripMinimalScrollBarSteppers(bar)
	if bar == nil then
		return
	end
	local controls = {
		bar.GetBackStepper and bar:GetBackStepper() or bar.Back,
		bar.GetForwardStepper and bar:GetForwardStepper() or bar.Forward,
	}
	for _, control in pairs(controls) do
		if control and control.Hide then
			control:Hide()
		end
	end
	local trackGetter = bar.GetTrack
	local track = trackGetter and trackGetter(bar) or bar.Track
	if track and track.ClearAllPoints then
		track:ClearAllPoints()
		for _, point in ipairs({ "TOP", "BOTTOM" }) do
			track:SetPoint(point, bar, point)
		end
	end
end

function GF.UI.CreateContentScrollBar(scroll, barParent)
	local owner = barParent or scroll:GetParent() or scroll
	return GF.UI.BindMinimalScrollBar(scroll, GF.CONTENT_SCROLLBAR_OFFSET_X or 9, owner)
end

function GF.UI.AnchorContentScrollBottomRight(scroll, parent)
	local rightInset = -(GF.CONTENT_SCROLL_INSET_R or 0)
	local bottomInset = GF.CONTENT_SCROLL_INSET_B or 0
	scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", rightInset, bottomInset)
end

local function connectScrollBar(scroll, bar)
	local initializer = ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar
	if initializer then
		initializer(scroll, bar)
	elseif scroll.UpdateScrollChildRect then
		scroll:UpdateScrollChildRect()
	end
end

function GF.UI.BindMinimalScrollBar(scroll, offsetX, barParent, keepNativeChrome)
	local horizontalOffset = offsetX or 4
	local owner = barParent or scroll:GetParent() or scroll
	GF.UI.HideLegacyScrollBar(scroll)
	local bar = CreateFrame("EventFrame", nil, owner, "MinimalScrollBar")
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", horizontalOffset, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", horizontalOffset, 0)
	bar:SetFrameLevel(scroll:GetFrameLevel() + 10)
	if not keepNativeChrome then
		GF.UI.StripMinimalScrollBarSteppers(bar)
	end
	bar:Show()
	bar._gfHideIfUnscrollable = true
	scroll.ScrollBar = bar
	if bar.SetHideIfUnscrollable then bar:SetHideIfUnscrollable(true) end
	connectScrollBar(scroll, bar)
	-- ScrollUtil 会安装自己的滚轮脚本，初始化后再恢复按行滚动。
	local restoreWheel = GF.UI.BindRowWheelScrolling
	restoreWheel(scroll, true)
	return bar
end

function GF.UI.UpdateScrollFrame(scroll)
	if scroll == nil then
		return
	end
	if scroll.UpdateScrollChildRect then
		scroll:UpdateScrollChildRect()
	end
	local rangeChanged = scroll:GetScript("OnScrollRangeChanged")
	if rangeChanged then
		rangeChanged(scroll, scroll:GetHorizontalScrollRange(), scroll:GetVerticalScrollRange())
	end
	local bar = scroll.ScrollBar
	if bar and bar.Update then
		bar:Update()
	end
	if bar and bar._gfHideIfUnscrollable and scroll.GetVerticalScrollRange then
		bar:SetShown((scroll:GetVerticalScrollRange() or 0) > 0)
	end
end

function GF.UI.AttachResizeController(frame, opts)
	if frame == nil then
		return nil
	end
	if frame._gfResizeController then
		return frame._gfResizeController
	end
	local options = opts or {}
	local controller = {
		target = frame,
		onProgress = options.onResize,
		onStopped = options.onResizeStopped,
	}
	frame:SetResizable(true)
	local handle = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
	handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
	handle:SetFrameLevel(frame:GetFrameLevel() + 30)
	if handle.Init then
		handle:Init(
			frame,
			options.minW or GF.FRAME_MIN_W,
			options.minH or GF.FRAME_MIN_H,
			nil,
			nil
		)
	end
	if controller.onProgress then
		handle:SetOnResizeCallback(function(_, width, height, isActive)
			controller.onProgress(controller.target, width, height, isActive)
		end)
	end
	if controller.onStopped then
		handle:SetOnResizeStoppedCallback(function()
			controller.onStopped(controller.target)
		end)
	end
	controller.handle = handle
	frame._gfResizeController = controller
	return controller
end
