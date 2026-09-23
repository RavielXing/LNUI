local _, GF = ...

GF.MythicPlusCarpoolDivider = {}

-- Project an authored inset through the same atlas slicing as the outer frame.
-- Without slice data SetAtlas stretches the entire image, including its edges.
local function projectInset(inset, size, sourceSize, nearMargin, farMargin)
	if not nearMargin or not farMargin then return inset * size / sourceSize end
	local edgeScale = math.min(1, size / math.max(1, nearMargin + farMargin))
	if inset <= nearMargin then return inset * edgeScale end
	if inset >= sourceSize - farMargin then return size - (sourceSize - inset) * edgeScale end
	return nearMargin * edgeScale + (inset - nearMargin)
		* math.max(0, size - (nearMargin + farMargin) * edgeScale)
		/ math.max(1, sourceSize - nearMargin - farMargin)
end

local function findBorder(parent)
	local owner = parent
	while owner do
		if owner._gfPanelBorderFrame then return owner._gfPanelBorderFrame end
		owner = owner:GetParent()
	end
end

function GF.MythicPlusCarpoolDivider.Create(parent, style)
	local host = CreateFrame("Frame", nil, parent)
	host:EnableMouse(false)
	host:SetWidth(style.lineWidth)
	local line = host:CreateTexture(nil, "BORDER")
	line:SetAllPoints(host)
	line:SetBlendMode("BLEND")
	GF.UI.SetNativeAtlasSampling(line, false)
	host.pieces = { line }
	local ornamentStyle = style.ornament
	local ornament = host:CreateTexture(nil, "OVERLAY")
	ornament:SetBlendMode("BLEND")
	ornament:SetDesaturated(true)
	local tint = ornamentStyle.color
	ornament:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
	GF.UI.SetNativeAtlasSampling(ornament, false)
	ornament:Hide()
	host.ornament = ornament
	local ornamentLoaded = false
	local border = findBorder(parent)
	local appliedInfo
	local color = GF.TABLE_HEADER_STYLE.dividerColor
	line:SetColorTexture(color[1], color[2], color[3], 0.35)

	function host:Layout(centerX)
		if not ornamentLoaded then
			ornamentLoaded = GF.UI.TrySetAtlas(ornament, ornamentStyle.atlas, true)
			ornament:SetShown(ornamentLoaded)
		end
		local info = GF.UI.GetNativeAtlasInfo(style.atlas)
		if info and appliedInfo ~= info then
			local region = style.lineRegion
			if GF.UI.SetNativeAtlasPieceRegion(line, info,
				region[1], region[2], region[3], region[4], true, false)
			then
				appliedInfo = info
			else
				line:SetTexture(nil)
				line:SetTexCoord(0, 1, 0, 1)
				line:SetColorTexture(color[1], color[2], color[3], 0.35)
			end
		end
		local topOffset, bottomOffset = -style.fallbackTopInset, style.fallbackBottomInset
		local ornamentOffset = ornamentStyle.fallbackOffsetY
		border = border or findBorder(parent)
		if border and info then
			local top, bottom = border:GetTop(), border:GetBottom()
			local parentTop, parentBottom = parent:GetTop(), parent:GetBottom()
			if top and bottom and parentTop and parentBottom then
				local scale = border:GetEffectiveScale() / parent:GetEffectiveScale()
				local height = math.max(0, top - bottom)
				local sourceHeight = info.logicalHeight
				local slice = info.sliceData or {}
				local innerTop = projectInset(style.topInnerEdge * sourceHeight,
					height, sourceHeight, slice.marginTop, slice.marginBottom)
				local innerBottom = projectInset(style.bottomInnerEdge * sourceHeight,
					height, sourceHeight, slice.marginBottom, slice.marginTop)
				local ornamentCenter = projectInset(ornamentStyle.centerFromBottom * sourceHeight,
					height, sourceHeight, slice.marginBottom, slice.marginTop)
				ornamentOffset = (ornamentCenter - innerBottom) * scale
				-- Bound the texture itself to the two inner edges. It cannot cover
				-- either horizontal stroke even above the roster header artwork.
				topOffset = (top - innerTop) * scale - parentTop
				bottomOffset = (bottom + innerBottom) * scale - parentBottom
			end
		end
		self:SetPoint("TOP", parent, "TOPLEFT", centerX, topOffset)
		self:SetPoint("BOTTOM", parent, "BOTTOMLEFT", centerX, bottomOffset)
		ornament:SetPoint("CENTER", self, "BOTTOM", 0, ornamentOffset)
	end
	return host
end
