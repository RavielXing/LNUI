local _, GF = ...
GF = GF.GF or GF

local UI = GF.UI
local STYLE = GF.SHOP_CARD_BANNER_STYLE
local Banner = {}
UI.ShopCardBanner = Banner

local function frameScale(width, height)
	local slice = STYLE.frameSlice
	return math.min(slice.scale, width / (slice.corner * 2), height / (slice.corner * 2))
end

-- Source coordinates are in the authored wide-card canvas, not the full
-- texture sheet. Every piece uses the same X/Y scale, including partial tiles.
local function sliceAxis(size, sourceSize, corner, scale)
	local spans = {}
	local capSize = corner * scale
	local function add(position, source, length)
		if length > 0 then
			spans[#spans + 1] = {
				position = position, source = source, size = length, sourceSize = length / scale,
			}
		end
	end
	add(0, 0, capSize)
	local position, finish = capSize, size - capSize
	local period = (sourceSize - corner * 2) * scale
	while position < finish do
		local length = math.min(period, finish - position)
		add(position, corner, length)
		position = position + length
	end
	add(finish, sourceSize - corner, capSize)
	return spans
end

local FrameSlices = {}
FrameSlices.__index = FrameSlices

function FrameSlices:SetShown(shown)
	self.shown = shown == true
	for index, texture in ipairs(self.pieces) do
		texture:SetShown(self.shown and index <= self.activeCount)
	end
end

function FrameSlices:Hide() self:SetShown(false) end
function FrameSlices:IsShown() return self.shown end

function FrameSlices:Layout()
	local width, height = self.owner:GetWidth(), self.owner:GetHeight()
	if not self.info or width <= 0 or height <= 0 then
		self.width, self.height, self.activeCount = nil, nil, 0
		self:SetShown(self.shown)
		return
	end
	if self.width == width and self.height == height then return end
	self.width, self.height = width, height
	local info, slice = self.info, STYLE.frameSlice
	-- Keep complete corners even on a very small button: reduce both axes by
	-- one uniform factor rather than clipping or independently squeezing caps.
	local scale = frameScale(width, height)
	self.scale = scale
	local columns = sliceAxis(width, slice.width, slice.corner, scale)
	local rows = sliceAxis(height, slice.height, slice.corner, scale)
	local count = 0
	for _, row in ipairs(rows) do
		for _, column in ipairs(columns) do
			count = count + 1
			local texture = self.pieces[count]
			if not texture then
				texture = self.owner:CreateTexture(nil, "OVERLAY", nil, self.subLevel)
				texture:ClearTextureSlice()
				UI.SetNativeAtlasSampling(texture, false)
				self.pieces[count] = texture
			end
			texture:ClearAllPoints()
			texture:SetPoint("TOPLEFT", self.owner, "TOPLEFT", column.position, -row.position)
			texture:SetSize(column.size, row.size)
			-- A partial edge tile crops its source by the same amount. It never
			-- resizes a complete edge, and never samples the corner as a repeat.
			local ok = UI.SetNativeAtlasPieceRegion(texture, info,
				column.source / slice.width, (column.source + column.sourceSize) / slice.width,
				row.source / slice.height, (row.source + row.sourceSize) / slice.height,
				true, false)
			if not ok then
				self.width, self.height, self.activeCount = nil, nil, 0
				self:SetShown(self.shown)
				return
			end
		end
	end
	self.activeCount = count
	self:SetShown(self.shown)
end

function FrameSlices:SetAtlas(atlas)
	if self.atlas ~= atlas or not self.info then
		self.atlas, self.info = atlas, UI.GetNativeAtlasInfo(atlas)
		self.width, self.height = nil, nil
	end
	self:Layout()
end

local function createFrameSlices(button, subLevel)
	return setmetatable({ owner = button, subLevel = subLevel, pieces = {}, activeCount = 0, shown = true }, FrameSlices)
end

-- Five rectangles and four triangles form the frame's octagonal aperture.
-- The picture and neutral fill share actual vertices, so neither can draw
-- outside its bevel. UVs follow those vertices in ONE continuous picture.
local ImageSurface = {}
ImageSurface.__index = ImageSurface

function ImageSurface:GetAlpha() return self.alpha end
function ImageSurface:IsShown() return self.visible == true end

function ImageSurface:SetAlpha(alpha)
	self.alpha = alpha
	for _, piece in ipairs(self.pieces) do piece.image:SetAlpha(alpha) end
end

function ImageSurface:SetDesaturated(value)
	self.desaturated = value
	for _, piece in ipairs(self.pieces) do piece.image:SetDesaturated(value) end
end

function ImageSurface:SetVertexColor(...)
	self.tint = { ... }
	for _, piece in ipairs(self.pieces) do piece.image:SetVertexColor(...) end
end

function ImageSurface:RefreshImages()
	if self.atlas and not self.sourceInfo then self.sourceInfo = UI.GetNativeAtlasInfo(self.atlas) end
	self.visible = false
	for _, piece in ipairs(self.pieces) do
		local ok = false
		if self.valid then
			local coords = self.coords
			if self.atlas then
				ok = UI.SetNativeAtlasPieceRegion(piece.image, self.sourceInfo,
					0, 1, 0, 1, true, false)
				if ok then
					local info = self.sourceInfo
					coords = { info.left, info.right, info.top, info.bottom }
				end
			elseif self.texture then
				ok = piece.image:SetTexture(self.texture) ~= false
			end
			if ok then
				local uv, inset = {}, STYLE.imageContentInset
				for index = 1, 8, 2 do
					uv[index] = coords[1] + (coords[2] - coords[1])
						* (inset + (1 - 2 * inset) * piece.imageUV[index])
					uv[index + 1] = coords[3] + (coords[4] - coords[3])
						* (inset + (1 - 2 * inset) * piece.imageUV[index + 1])
				end
				piece.image:SetTexCoord(unpack(uv))
			end
		end
		piece.image:SetShown(self.shown and ok)
		self.visible = self.visible or (self.shown and ok)
		piece.background:SetShown(self.valid == true)
	end
end

local function imageAxis(size, corner, scale)
	local cap = corner * scale
	return {
		{ position = 0, size = cap },
		{ position = cap, size = size - 2 * cap },
		{ position = size - cap, size = cap },
	}
end

function ImageSurface:Layout()
	local width, height = self.owner:GetWidth(), self.owner:GetHeight()
	if width <= 0 or height <= 0 then
		self.width, self.height, self.valid = nil, nil, false
		self:RefreshImages()
		return
	end
	if self.width == width and self.height == height then return end
	self.width, self.height, self.valid = width, height, true
	local clip, scale = STYLE.imageClip, frameScale(width, height)
	local insetX, insetY = clip.left * scale, clip.top * scale
	local imageWidth = width - (clip.left + clip.right) * scale
	local imageHeight = height - (clip.top + clip.bottom) * scale
	self.bounds = { insetX, insetY, imageWidth, imageHeight }
	local columns = imageAxis(imageWidth, clip.corner, scale)
	local rows = imageAxis(imageHeight, clip.corner, scale)
	local index = 0
	for rowIndex, row in ipairs(rows) do
		for columnIndex, column in ipairs(columns) do
			index = index + 1
			local piece = self.pieces[index]
			if not piece then
				piece = {
					image = self.owner:CreateTexture(nil, "ARTWORK"),
					background = self.owner:CreateTexture(nil, "BACKGROUND"),
				}
				piece.background:SetColorTexture(unpack(STYLE.backgroundColor))
				piece.image:SetAlpha(self.alpha)
				piece.image:SetDesaturated(self.desaturated == true)
				piece.image:SetVertexColor(unpack(self.tint))
				for _, texture in ipairs({ piece.image, piece.background }) do
					texture:ClearTextureSlice()
					UI.SetNativeAtlasSampling(texture, false)
				end
				self.pieces[index] = piece
			end
			-- Native vertex order is upper-left, lower-left, upper-right,
			-- lower-right. Collapse the outer corner onto its horizontal
			-- neighbour: one degenerate triangle, one exact bevel triangle.
			local vertices = { 0, 0, 0, row.size, column.size, 0, column.size, row.size }
			local base = { unpack(vertices) }
			if columnIndex ~= 2 and rowIndex ~= 2 then
				local vertex = (columnIndex == 1 and 1 or 3) + (rowIndex == 3 and 1 or 0)
				vertices[vertex * 2 - 1] = columnIndex == 1 and column.size or 0
			end
			for _, texture in ipairs({ piece.image, piece.background }) do
				texture:ClearAllPoints()
				texture:SetPoint("TOPLEFT", self.owner, "TOPLEFT", insetX + column.position, -insetY - row.position)
				texture:SetSize(column.size, row.size)
				for vertex = 1, 4 do
					local component = vertex * 2 - 1
					texture:SetVertexOffset(vertex, vertices[component] - base[component],
						base[component + 1] - vertices[component + 1])
				end
			end
			piece.imageUV = {}
			for component = 1, 8, 2 do
				piece.imageUV[component] = (column.position + vertices[component]) / imageWidth
				piece.imageUV[component + 1] = (row.position + vertices[component + 1]) / imageHeight
			end
		end
	end
	self:RefreshImages()
end

function ImageSurface:SetData(data)
	if self.atlas ~= data.atlas then self.sourceInfo = nil end
	self.atlas, self.texture = data.atlas, not data.atlas and data.texture or nil
	self.coords = data.texCoords or { 0, 1, 0, 1 }
	self.shown = data.atlas ~= nil or data.texture ~= nil
	self:Layout()
	self:RefreshImages()
end

local function createImageSurface(button)
	return setmetatable({ owner = button, pieces = {}, alpha = 1, tint = { 1, 1, 1 }, shown = false }, ImageSurface)
end

local function imageTargetAlpha(button)
	return button:IsEnabled() and (button.selected or button.hovered)
		and STYLE.imageActiveAlpha or STYLE.imageNormalAlpha
end

local function stopImageFade(button)
	button._imageFade = nil
	button:SetScript("OnUpdate", nil)
end

local function updateImageFade(button, elapsed)
	local fade = button._imageFade
	if not fade then return end
	fade.elapsed = math.min(fade.elapsed + elapsed, STYLE.imageFadeDuration)
	local progress = fade.elapsed / STYLE.imageFadeDuration
	local eased = progress * progress * (3 - 2 * progress)
	button.Image:SetAlpha(progress >= 1 and fade.to or (fade.from + (fade.to - fade.from) * eased))
	if progress >= 1 then stopImageFade(button) end
end

local function setImageAlpha(button, instant)
	local target = imageTargetAlpha(button)
	if instant then
		stopImageFade(button)
		button.Image:SetAlpha(target)
	elseif not button._imageFade or button._imageFade.to ~= target then
		local current = button.Image:GetAlpha()
		stopImageFade(button)
		if math.abs(current - target) < 0.001 then
			button.Image:SetAlpha(target)
		else
			-- A rapid pointer/selection reversal continues from the visible alpha.
			button._imageFade = { from = current, to = target, elapsed = 0 }
			button:SetScript("OnUpdate", updateImageFade)
		end
	end
end

function Banner:Refresh(button, instant)
	button.Image:Layout()
	button.Border:SetAtlas(button.selected and STYLE.selectedAtlas or STYLE.normalAtlas)
	button.Hover:SetAtlas(STYLE.highlightAtlas)
	-- Selected uses only the selected frame, including while the mouse is over it.
	button.Hover:SetShown(button.hovered == true and not button.selected and button:IsEnabled())
	button.Image:SetDesaturated(not button:IsEnabled())
	local tint = button:IsEnabled() and STYLE.imageTint or STYLE.disabledImageTint
	button.Image:SetVertexColor(tint, tint, tint)
	button.Label:SetTextColor(unpack(STYLE.textColor))
	setImageAlpha(button, instant)
end

function Banner:SetData(button, data, selected)
	local identity = data.key or data.atlas or data.texture or false
	local instant = button._imageIdentity ~= identity
	button._imageIdentity = identity
	button.selected = selected == true
	button:SetEnabled(data.enabled == true)
	button.Label:SetText(data.label or "")
	button.Image:SetData(data)
	self:Refresh(button, instant)
end

function Banner:Create(parent)
	local button = CreateFrame("Button", nil, parent)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetMotionScriptsWhileDisabled(true)
	button.Image = createImageSurface(button)
	button.Border = createFrameSlices(button, 1)
	button.Hover = createFrameSlices(button, 2)
	button:HookScript("OnSizeChanged", function()
		button.Image:Layout()
		button.Border:Layout()
		button.Hover:Layout()
	end)
	button.Label = UI.CreateFontString(button, "OVERLAY", "GameFontNormal")
	button.Label._gfFontSizeOverride = STYLE.textSize
	button.Label._gfFontFlagsOverride = STYLE.textFlags
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(button.Label, "GameFontNormal")
	end
	button.Label:SetPoint("TOPLEFT", STYLE.textInset, -STYLE.textInsetY)
	button.Label:SetPoint("BOTTOMRIGHT", -STYLE.textInset, STYLE.textInsetY)
	button.Label:SetJustifyH("CENTER")
	button.Label:SetJustifyV("MIDDLE")
	button.Label:SetWordWrap(true)
	button.Label:SetMaxLines(2)
	button.Label:SetShadowColor(0, 0, 0, 1)
	button.Label:SetShadowOffset(1, -1)
	button:HookScript("OnEnter", function()
		button.hovered = true
		Banner:Refresh(button)
	end)
	button:HookScript("OnLeave", function()
		button.hovered = nil
		Banner:Refresh(button)
	end)
	button:HookScript("OnHide", function()
		button.hovered = nil
		button.Hover:Hide()
		setImageAlpha(button, true)
	end)
	return button
end
