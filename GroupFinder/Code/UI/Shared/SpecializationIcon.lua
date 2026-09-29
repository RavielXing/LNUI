local _, GF = ...

GF.UI = GF.UI or {}
local WHITE = GF.WHITE_TEXTURE

-- 共享职业与专精图标解析、遮罩和辉光渲染。

local CLASS_FILE_ORDER = {
	"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
	"DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
	"DRUID", "DEMONHUNTER", "EVOKER",
}
local CLASS_ID_BY_FILE = {}
local CLASS_FILE_BY_ID = {}
for classID = 1, #CLASS_FILE_ORDER do
	local classFile = CLASS_FILE_ORDER[classID]
	CLASS_ID_BY_FILE[classFile] = classID
	CLASS_FILE_BY_ID[classID] = classFile
end

local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CharacterCreate\\UI-CharacterCreate-Classes"
local FALLBACK_CLASS_ICON_TCOORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE = { 0.25, 0.5, 0, 0.25 },
	ROGUE = { 0.5, 0.75, 0, 0.25 },
	DRUID = { 0.75, 1, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 },
	SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
	PRIEST = { 0.5, 0.75, 0.25, 0.5 },
	WARLOCK = { 0.75, 1, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
	DEATHKNIGHT = { 0.25, 0.5, 0.5, 0.75 },
	MONK = { 0.5, 0.75, 0.5, 0.75 },
	DEMONHUNTER = { 0.75, 1, 0.5, 0.75 },
	EVOKER = { 0, 0.25, 0.75, 1 },
}
local SPEC_ICON_CACHE = {}
local SPEC_MASK_TEXTURE = GF.SPEC_ICON_MASK_TEXTURE or GF.MAIN_WINDOW_EYE_BACKGROUND_MASK or "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SPEC_ICON_TEXCOORD_INSET = tonumber(GF.SPEC_ICON_TEXCOORD_INSET) or 0.06
local SPEC_ICON_GLOW_PADDING = tonumber(GF.SPEC_ICON_GLOW_PADDING) or 2
local SPEC_ICON_MASK_INSET = tonumber(GF.SPEC_ICON_MASK_INSET) or SPEC_ICON_GLOW_PADDING
local SPEC_ICON_DISABLED_ALPHA = 0.48
local SPEC_ICON_DISABLED_TINT = 0.58
local SPEC_GLOW_DISABLED_ALPHA = 0.2
local SPEC_GLOW_DISABLED_TINT = 0.48
local SPEC_SEPARATOR_R = 0.055
local SPEC_SEPARATOR_G = 0.04
local SPEC_SEPARATOR_B = 0.018
local SPEC_SEPARATOR_ALPHA = 0.96
local SPEC_HOVER_GLOW_ALPHA = 0.96

local function normalizeClassFile(classFile)
	if type(classFile) ~= "string" or classFile == "" then
		return nil
	end
	return classFile:upper()
end

local function normalizeSpecRole(role)
	if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
		return role
	end
	if role == "DPS" then
		return "DAMAGER"
	end
	return nil
end

local function normalizeClassValue(classValue)
	if type(classValue) == "number" then
		return CLASS_FILE_BY_ID[classValue]
	end
	return normalizeClassFile(classValue)
end

local function getClassFallbackIcon(classFile)
	classFile = normalizeClassFile(classFile)
	if not classFile then
		return nil
	end
	return {
		atlas = "classicon-" .. string.lower(classFile),
		texture = CLASS_ICON_TEXTURE,
		texCoords = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]) or FALLBACK_CLASS_ICON_TCOORDS[classFile],
		classFile = classFile,
		isClassFallback = true,
	}
end

function GF.UI.ResolveClassIcon(classValue)
	local classFile = normalizeClassValue(classValue)
	return getClassFallbackIcon(classFile), classFile
end

local function resolveSpecIconByID(specID)
	specID = tonumber(specID)
	if not specID then
		return nil
	end
	local cacheKey = "id:" .. tostring(specID)
	local cached = SPEC_ICON_CACHE[cacheKey]
	if cached ~= nil then
		return cached.icon, cached.role, cached.classFile
	end
	local icon, role, classFile
	if GetSpecializationInfoByID then
		local ok, _, _, _, apiIcon, apiRole, apiClass = pcall(GetSpecializationInfoByID, specID)
		if ok then
			icon = apiIcon
			role = normalizeSpecRole(apiRole)
			classFile = normalizeClassValue(apiClass)
		end
	end
	SPEC_ICON_CACHE[cacheKey] = { icon = icon or false, role = role, classFile = classFile }
	return icon, role, classFile
end

local function resolveSpecIconByClassAndName(classFile, specName, targetSpecID)
	classFile = normalizeClassFile(classFile)
	if not classFile or type(specName) ~= "string" or specName == "" then
		return nil
	end
	local cacheKey = "name:" .. classFile .. "|" .. specName .. "|" .. tostring(targetSpecID or "")
	local cached = SPEC_ICON_CACHE[cacheKey]
	if cached ~= nil then
		return cached.icon, cached.role, cached.classFile
	end
	local classID = CLASS_ID_BY_FILE[classFile]
	local icon, role, resolvedClassFile
	if classID and GetSpecializationInfoForClassID then
		local numSpecs = 4
		if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
			local ok, count = pcall(C_SpecializationInfo.GetNumSpecializationsForClassID, classID)
			if ok and tonumber(count) and tonumber(count) > 0 then
				numSpecs = tonumber(count)
			end
		end
		for index = 1, numSpecs do
			local ok, specID, localizedName, _, apiIcon, apiRole = pcall(GetSpecializationInfoForClassID, classID, index)
			if ok and ((targetSpecID and tonumber(specID) == tonumber(targetSpecID)) or localizedName == specName) then
				icon = apiIcon
				role = normalizeSpecRole(apiRole)
				resolvedClassFile = classFile
				break
			end
		end
	end
	SPEC_ICON_CACHE[cacheKey] = { icon = icon or false, role = role, classFile = resolvedClassFile }
	return icon, role, resolvedClassFile
end

function GF.UI.ResolveSpecializationIcon(data)
	data = type(data) == "table" and data or {}
	local classFile = data.classFile or data.classFilename or data.class
	local specID = tonumber(data.specID)
	local icon, role, resolvedClassFile = resolveSpecIconByID(specID)
	if icon then
		return icon, role, resolvedClassFile or normalizeClassValue(classFile)
	end
	icon, role, resolvedClassFile = resolveSpecIconByClassAndName(classFile, data.specName or data.specText, specID)
	if icon then
		return icon, role, resolvedClassFile or normalizeClassValue(classFile)
	end
	local fallbackClassFile = normalizeClassValue(classFile)
	return data.fallbackIcon or getClassFallbackIcon(fallbackClassFile), normalizeSpecRole(data.role or data.assignedRole), fallbackClassFile
end

local function getSpecGlowColor(opts, disabledOverride)
	opts = type(opts) == "table" and opts or {}
	local classFile = normalizeClassValue(opts.classFile or opts.classFilename or opts.class or opts.resolvedClass)
	local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	local normalAlpha = classColor and 0.96 or 0.86
	local disabled = opts.disabled == true
	if disabledOverride ~= nil then
		disabled = disabledOverride == true
	end
	if opts.ringStyle and not opts.ringStyle.classColored then
		local color = disabled and opts.ringStyle.disabledColor or opts.ringStyle.color
		return color[1], color[2], color[3], color[4]
	end
	if disabled then
		local disabledAlpha = opts.preserveDisabledAlpha
			and (tonumber(opts.glowAlpha) or normalAlpha)
			or SPEC_GLOW_DISABLED_ALPHA
		return SPEC_GLOW_DISABLED_TINT,
			SPEC_GLOW_DISABLED_TINT,
			SPEC_GLOW_DISABLED_TINT,
			disabledAlpha
	end
	if classColor then
		return classColor.r or 1,
			classColor.g or 0.82,
			classColor.b or 0,
			normalAlpha
	end
	return 1, 0.82, 0, normalAlpha
end

local function removeMask(texture, mask)
	if texture and mask and texture.RemoveMaskTexture then
		return pcall(texture.RemoveMaskTexture, texture, mask)
	end
	return false
end

local function ensureCircleMask(texture, size, opts)
	local parent = texture and texture:GetParent()
	if not (parent and parent.CreateMaskTexture and texture.AddMaskTexture) then
		return nil
	end
	opts = type(opts) == "table" and opts or {}
	if not texture._gfSpecCircleMask then
		local mask = parent:CreateMaskTexture()
		mask:SetTexture(SPEC_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		texture._gfSpecCircleMask = mask
	end
	local mask = texture._gfSpecCircleMask
	mask:ClearAllPoints()
	mask:SetPoint("CENTER", texture, "CENTER", 0, 0)
	local maskSize = math.max(1, size - (tonumber(opts.iconInset) or SPEC_ICON_MASK_INSET))
	mask:SetSize(maskSize, maskSize)
	if not texture._gfSpecCircleMaskAdded then
		local ok = pcall(texture.AddMaskTexture, texture, mask)
		texture._gfSpecCircleMaskAdded = ok == true
	end
	return mask
end

local function ensureSpecGlow(texture, size, opts)
	local parent = texture and texture:GetParent()
	if not (parent and parent.CreateTexture) then
		return nil
	end
	if not texture._gfSpecGlow then
		local glow = parent:CreateTexture(nil, "ARTWORK", nil, -2)
		glow:SetTexture(WHITE)
		if glow.SetBlendMode then
			glow:SetBlendMode("ADD")
		end
		texture._gfSpecGlow = glow
	end
	local glow = texture._gfSpecGlow
	local glowSize = math.max(1, tonumber(opts.outerSize) or size)
	glow:ClearAllPoints()
	glow:SetPoint("CENTER", texture, "CENTER", 0, 0)
	glow:SetSize(glowSize, glowSize)
	if opts.updateColor == true or not glow._gfSpecColorInitialized then
		local r, g, b, a = getSpecGlowColor(opts)
		glow:SetVertexColor(r, g, b, (opts.disabled and a) or (opts.glowAlpha or a))
		glow._gfSpecColorInitialized = true
		glow._gfSpecHovered = nil
	end
	if parent.CreateMaskTexture and glow.AddMaskTexture then
		if not texture._gfSpecGlowMask then
			local mask = parent:CreateMaskTexture()
			mask:SetTexture(SPEC_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			texture._gfSpecGlowMask = mask
		end
		local mask = texture._gfSpecGlowMask
		mask:ClearAllPoints()
		mask:SetPoint("CENTER", glow, "CENTER", 0, 0)
		mask:SetSize(glowSize, glowSize)
		if not texture._gfSpecGlowMaskAdded then
			local ok = pcall(glow.AddMaskTexture, glow, mask)
			texture._gfSpecGlowMaskAdded = ok == true
		end
	end
	glow:SetShown(texture._gfSpecIconActive == true and texture._gfSpecCircleMaskAdded == true)
	return glow
end

local function tintSpecRing(ring, r, g, b, a, desaturation)
	ring:SetVertexColor(r, g, b, a)
	if ring.SetDesaturation then
		ring:SetDesaturation(desaturation)
	else
		ring:SetDesaturated(desaturation > 0.5)
	end
end

local function setSpecBorderColor(border, r, g, b, a, activeAmount)
	if border._gfStyle then
		-- Class tinting removes the source yellow; the talent ring keeps native color.
		local desaturation = border._gfStyle.desaturated and 1 or (1 - activeAmount)
		tintSpecRing(border, r, g, b, a, desaturation)
		if border._gfInnerRing then
			tintSpecRing(border._gfInnerRing, r, g, b, a, desaturation)
		end
	else
		border:SetVertexColor(r, g, b, a)
	end
end

local function setSpecAtlasRingShown(ring, shown)
	ring:SetShown(shown)
	if ring._gfInnerRing then
		ring._gfInnerRing:SetShown(shown and (ring._gfStyle.innerInset or 0) > 0)
	end
end

local function ensureSpecAtlasRing(texture, size, opts)
	local parent = texture:GetParent()
	if not (parent and parent.CreateTexture) then return end
	local style = opts.ringStyle
	local ring = texture._gfSpecAtlasRing
	if not ring then
		ring = parent:CreateTexture(nil, "OVERLAY")
		ring:SetBlendMode("BLEND")
		texture._gfSpecAtlasRing = ring
	end
	local innerInset = style.innerInset or 0
	if innerInset > 0 and not ring._gfInnerRing then
		local inner = parent:CreateTexture(nil, "OVERLAY", nil, 1)
		-- Reinforce the inward edge with the same material and class tint.
		inner:SetBlendMode("ADD")
		ring._gfInnerRing = inner
		ring._gfAtlasReady = false
	end
	if ring._gfStyle ~= style or not ring._gfAtlasReady then
		local function apply(atlas)
			return GF.UI.GetNativeAtlasInfo(atlas) ~= nil
				and GF.UI.TrySetAtlas(ring, atlas, false, nil, true)
				and (innerInset <= 0
					or GF.UI.TrySetAtlas(ring._gfInnerRing, atlas, false, nil, true))
		end
		ring._gfAtlasReady = apply(style.atlas)
			or (style.fallbackAtlas and apply(style.fallbackAtlas))
		ring._gfStyle = style
	end
	local outerSize = math.max(1, tonumber(opts.outerSize) or size)
	local offset = outerSize * style.offsetRatio
	ring:ClearAllPoints()
	ring:SetPoint("CENTER", texture, "CENTER", offset, -offset)
	ring:SetSize(outerSize * style.scale, outerSize * style.scale)
	if innerInset > 0 then
		local innerSize = math.max(1, outerSize - 2 * innerInset)
		local innerOffset = innerSize * style.offsetRatio
		local inner = ring._gfInnerRing
		inner:ClearAllPoints()
		inner:SetPoint("CENTER", texture, "CENTER", innerOffset, -innerOffset)
		inner:SetSize(innerSize * style.scale, innerSize * style.scale)
	end
	if opts.updateColor == true then
		local r, g, b, a = getSpecGlowColor(opts)
		setSpecBorderColor(ring, r, g, b, a, opts.disabled and 0 or 1)
	end
	setSpecAtlasRingShown(ring, ring._gfAtlasReady == true
		and texture._gfSpecIconActive == true
		and texture._gfSpecCircleMaskAdded == true)
	return ring
end

local function getSpecBorder(texture)
	if not texture then return end
	if texture._gfSpecRingStyle then return texture._gfSpecAtlasRing end
	return texture._gfSpecGlow
end

local function ensureSpecSeparator(texture, size, opts)
	local parent = texture and texture:GetParent()
	if not (parent and parent.CreateTexture) then
		return nil
	end
	if not texture._gfSpecSeparator then
		local separator = parent:CreateTexture(nil, "ARTWORK", nil, -1)
		separator:SetTexture(WHITE)
		texture._gfSpecSeparator = separator
	end
	local separator = texture._gfSpecSeparator
	local separatorSize = math.max(
		1,
		tonumber(opts.separatorSize) or size
	)
	separator:ClearAllPoints()
	separator:SetPoint("CENTER", texture, "CENTER", 0, 0)
	separator:SetSize(separatorSize, separatorSize)
	separator:SetVertexColor(
		tonumber(opts.separatorR) or SPEC_SEPARATOR_R,
		tonumber(opts.separatorG) or SPEC_SEPARATOR_G,
		tonumber(opts.separatorB) or SPEC_SEPARATOR_B,
		tonumber(opts.separatorAlpha) or SPEC_SEPARATOR_ALPHA
	)
	if parent.CreateMaskTexture and separator.AddMaskTexture then
		if not texture._gfSpecSeparatorMask then
			local mask = parent:CreateMaskTexture()
			mask:SetTexture(
				SPEC_MASK_TEXTURE,
				"CLAMPTOBLACKADDITIVE",
				"CLAMPTOBLACKADDITIVE"
			)
			texture._gfSpecSeparatorMask = mask
		end
		local mask = texture._gfSpecSeparatorMask
		mask:ClearAllPoints()
		mask:SetPoint("CENTER", separator, "CENTER", 0, 0)
		mask:SetSize(separatorSize, separatorSize)
		if not texture._gfSpecSeparatorMaskAdded then
			local ok = pcall(
				separator.AddMaskTexture,
				separator,
				mask
			)
			texture._gfSpecSeparatorMaskAdded = ok == true
		end
	end
	separator:SetShown(
		texture._gfSpecIconActive == true
			and texture._gfSpecSeparatorMaskAdded == true
	)
	return separator
end

local function setSpecializationTexture(texture, icon)
	if type(icon) == "table" then
		if icon.atlas and texture.SetAtlas then
			local ok, result = pcall(texture.SetAtlas, texture, icon.atlas, false)
			if ok and result ~= false then
				texture:SetTexCoord(0, 1, 0, 1)
				return true
			end
		end
		if icon.texture and icon.texCoords then
			local coords = icon.texCoords
			texture:SetTexture(icon.texture)
			texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
			return true
		end
		return false
	end
	texture:SetTexture(icon)
	texture:SetTexCoord(SPEC_ICON_TEXCOORD_INSET, 1 - SPEC_ICON_TEXCOORD_INSET, SPEC_ICON_TEXCOORD_INSET, 1 - SPEC_ICON_TEXCOORD_INSET)
	return true
end

function GF.UI.LayoutSpecializationIcon(texture, opts)
	if not texture then
		return
	end
	opts = type(opts) == "table" and opts or {}
	local width, height = texture:GetSize()
	local size = math.max(1, tonumber(opts.size) or width or height or GF.NON_ROLE_ICON_SIZE or 18)
	texture:SetSize(size, size)
	texture._gfSpecRingStyle = opts.ringStyle
	if ensureCircleMask(texture, size, opts) then
		if opts.ringStyle then
			if texture._gfSpecGlow then texture._gfSpecGlow:Hide() end
			ensureSpecAtlasRing(texture, size, opts)
		else
			if texture._gfSpecAtlasRing then
				setSpecAtlasRingShown(texture._gfSpecAtlasRing, false)
			end
			ensureSpecGlow(texture, size, opts)
		end
		if opts.separator == true then
			ensureSpecSeparator(texture, size, opts)
		elseif texture._gfSpecSeparator then
			texture._gfSpecSeparator:Hide()
		end
	end
end

function GF.UI.SetSpecializationIcon(texture, icon, opts)
	if not texture or not icon then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	texture._gfSpecIconActive = true
	texture._gfSpecTransitionActive = nil
	opts.updateColor = true
	GF.UI.LayoutSpecializationIcon(texture, opts)
	if not setSpecializationTexture(texture, icon) then
		GF.UI.ClearSpecializationIcon(texture)
		return false
	end
	if texture.SetDesaturation then
		texture:SetDesaturation(opts.disabled == true and 1 or 0)
	elseif texture.SetDesaturated then
		texture:SetDesaturated(opts.disabled == true)
	end
	if texture.SetVertexColor then
		if opts.disabled == true then
			texture:SetVertexColor(SPEC_ICON_DISABLED_TINT, SPEC_ICON_DISABLED_TINT, SPEC_ICON_DISABLED_TINT, 1)
		else
			texture:SetVertexColor(1, 1, 1, 1)
		end
	end
	local alpha = tonumber(opts.alpha) or 1
	if opts.disabled and not opts.preserveDisabledAlpha then
		alpha = SPEC_ICON_DISABLED_ALPHA
	end
	texture:SetAlpha(alpha)
	texture:Show()
	if texture._gfSpecGlow then
		texture._gfSpecGlow:SetShown(not opts.ringStyle
			and texture._gfSpecCircleMaskAdded == true)
	end
	if texture._gfSpecSeparator then
		texture._gfSpecSeparator:SetShown(
			opts.separator == true
				and texture._gfSpecSeparatorMaskAdded == true
		)
	end
	return true
end

local function clampNormalized(value)
	value = tonumber(value) or 0
	if value <= 0 then
		return 0
	end
	if value >= 1 then
		return 1
	end
	return value
end

local function interpolate(fromValue, toValue, amount)
	return fromValue + (toValue - fromValue) * amount
end

function GF.UI.SetSpecializationIconHovered(texture, hovered, opts, hoverAmount)
	local glow = getSpecBorder(texture)
	if not (
		glow
		and texture._gfSpecIconActive == true
		and texture._gfSpecTransitionActive ~= true
	) then
		return
	end
	opts = type(opts) == "table" and opts or {}
	if opts.ringStyle then
		local amount = hoverAmount == nil and (hovered == true and 1 or 0)
			or clampNormalized(hoverAmount)
		local r, g, b, a = getSpecGlowColor(opts)
		a = opts.disabled and a or (tonumber(opts.glowAlpha) or a)
		local hoverR, hoverG, hoverB, hoverA = getSpecGlowColor(opts, false)
		local color = opts.ringStyle.hoverColor
		if color then
			hoverR, hoverG, hoverB, hoverA = color[1], color[2], color[3], color[4]
		end
		setSpecBorderColor(glow,
			interpolate(r, hoverR, amount),
			interpolate(g, hoverG, amount),
			interpolate(b, hoverB, amount),
			interpolate(a, hoverA, amount),
			opts.disabled and amount or 1)
		glow._gfSpecHovered = amount > 0 or nil
		return
	end
	if hovered == true then
		glow:SetVertexColor(
			tonumber(opts.hoverGlowR) or 1,
			tonumber(opts.hoverGlowG) or 0.82,
			tonumber(opts.hoverGlowB) or 0,
			tonumber(opts.hoverGlowAlpha) or SPEC_HOVER_GLOW_ALPHA
		)
		glow._gfSpecHovered = true
		return
	end
	local r, g, b, a = getSpecGlowColor(opts)
	setSpecBorderColor(glow,
		r,
		g,
		b,
		(opts.disabled and a) or (tonumber(opts.glowAlpha) or a),
		opts.disabled and 0 or 1
	)
	glow._gfSpecHovered = nil
end

function GF.UI.SetSpecializationIconTransition(
	texture,
	activeAmount,
	opts
)
	if not (texture and texture._gfSpecIconActive == true) then
		return false
	end
	opts = type(opts) == "table" and opts or {}
	activeAmount = clampNormalized(activeAmount)
	texture._gfSpecTransitionActive = true
	if texture.SetDesaturation then
		texture:SetDesaturation(1 - activeAmount)
	elseif texture.SetDesaturated then
		texture:SetDesaturated(activeAmount < 0.5)
	end
	local inactiveTint =
		tonumber(opts.disabledTint) or SPEC_ICON_DISABLED_TINT
	local tint = interpolate(inactiveTint, 1, activeAmount)
	if texture.SetVertexColor then
		texture:SetVertexColor(tint, tint, tint, 1)
	end
	local activeAlpha = tonumber(opts.alpha) or 1
	local inactiveAlpha = opts.preserveDisabledAlpha
		and activeAlpha
		or (tonumber(opts.disabledAlpha) or SPEC_ICON_DISABLED_ALPHA)
	texture:SetAlpha(
		interpolate(inactiveAlpha, activeAlpha, activeAmount)
	)
	local glow = getSpecBorder(texture)
	if glow then
		-- Hover can restore the ring while leaving an unselected icon desaturated.
		local glowAmount = opts.glowActiveAmount == nil
			and activeAmount or clampNormalized(opts.glowActiveAmount)
		local inactiveR, inactiveG, inactiveB, inactiveGlowAlpha =
			getSpecGlowColor(opts, true)
		local activeR, activeG, activeB, activeGlowAlpha =
			getSpecGlowColor(opts, false)
		activeGlowAlpha =
			tonumber(opts.glowAlpha) or activeGlowAlpha
		setSpecBorderColor(glow,
			interpolate(inactiveR, activeR, glowAmount),
			interpolate(inactiveG, activeG, glowAmount),
			interpolate(inactiveB, activeB, glowAmount),
			interpolate(
				inactiveGlowAlpha,
				activeGlowAlpha,
				glowAmount
			),
			glowAmount
		)
		glow._gfSpecHovered = nil
	end
	return true
end

function GF.UI.ClearSpecializationIcon(texture)
	if not texture then
		return
	end
	if texture._gfSpecGlow then
		texture._gfSpecGlow:Hide()
	end
	if texture._gfSpecAtlasRing then
		setSpecAtlasRingShown(texture._gfSpecAtlasRing, false)
	end
	texture._gfSpecRingStyle = nil
	if texture._gfSpecSeparator then
		texture._gfSpecSeparator:Hide()
	end
	texture._gfSpecIconActive = nil
	texture._gfSpecTransitionActive = nil
	if removeMask(texture, texture._gfSpecCircleMask) then
		texture._gfSpecCircleMaskAdded = nil
	end
	if texture._gfSpecGlow and texture._gfSpecGlowMask then
		if removeMask(texture._gfSpecGlow, texture._gfSpecGlowMask) then
			texture._gfSpecGlowMaskAdded = nil
		end
	end
	if texture._gfSpecSeparator and texture._gfSpecSeparatorMask then
		if removeMask(
			texture._gfSpecSeparator,
			texture._gfSpecSeparatorMask
		) then
			texture._gfSpecSeparatorMaskAdded = nil
		end
	end
	if texture.SetDesaturation then
		texture:SetDesaturation(0)
	elseif texture.SetDesaturated then
		texture:SetDesaturated(false)
	end
	if texture.SetVertexColor then
		texture:SetVertexColor(1, 1, 1, 1)
	end
	texture:SetAlpha(1)
	texture:Hide()
end
