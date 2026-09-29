local _, GF = ...

local Orb = {}
GF.MythicPlusCharacterVaultOrb = Orb
local STYLE = GF.MYTHIC_PLUS_VAULT_ORB_STYLE

local function frame(parent, level)
	local result = CreateFrame("Frame", nil, parent)
	result:SetFrameLevel(parent:GetFrameLevel() + level)
	result:EnableMouse(false)
	return result
end

local function texture(parent, layer, sublevel)
	-- Use native pixel alignment for both the image and its circular mask.
	return parent:CreateTexture(nil, layer, nil, sublevel)
end

local function mask(parent, root)
	local result = parent:CreateMaskTexture()
	result:SetTexture(STYLE.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
	result:SetPoint("CENTER", root, "CENTER")
	return result
end

local function tintGold(target, color)
	-- Neutralize the native material before multiplying by gold.
	target:SetDesaturated(true)
	target:SetVertexColor(unpack(color))
end

local function applyAtlas(target, atlas, crop)
	local info = GF.UI.GetNativeAtlasInfo(atlas)
	if not info then target:Hide(); return false end
	local applied
	if crop then
		-- These crops lie strictly inside the atlas. Resolve their file UVs
		-- from client metadata, with explicit minification filtering.
		local ok, result = pcall(target.SetTexture, target,
			info.file or info.filename or info.texture, nil, nil, "TRILINEAR")
		applied = ok and result ~= false
		if applied then
			local width, height = info.right - info.left, info.bottom - info.top
			target:SetTexCoord(info.left + width * crop[1], info.left + width * crop[2],
				info.top + height * crop[3], info.top + height * crop[4])
		end
	else
		applied = GF.UI.TrySetAtlas(target, atlas, false, "TRILINEAR", true)
	end
	target:SetShown(applied == true)
	return applied == true, info
end

local function cloudCoordinates(info, crop)
	local width, height = info.right - info.left, info.bottom - info.top
	return {
		u = info.left + width * (crop[1] + crop[2]) / 2,
		v = info.top + height * (crop[3] + crop[4]) / 2,
		x = width * (crop[2] - crop[1]) / 2,
		y = height * (crop[4] - crop[3]) / 2,
	}
end

local function rotateCloud(target, uv, angle)
	-- Rotate sampling inside the atlas, not the masked texture's rectangle.
	-- Corner order is upper-left, lower-left, upper-right, lower-right.
	local c, s = math.cos(angle), math.sin(angle)
	local u, v, x, y = uv.u, uv.v, uv.x, uv.y
	target:SetTexCoord(
		u + (s - c) * x, v - (s + c) * y,
		u - (c + s) * x, v + (c - s) * y,
		u + (c + s) * x, v + (s - c) * y,
		u + (c - s) * x, v + (s + c) * y)
end

local function ensureWaveAssets(orb)
	local function load(target, path)
		local ok, result = pcall(target.SetTexture, target, path,
			"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
		return ok and result ~= false
	end
	orb.waveReady = load(orb.WaveCap, STYLE.waveCapTexture)
	orb.hasSurface = load(orb.Surface, STYLE.waveSurfaceTexture)
end

local function updateWave(orb)
	local partial = orb.waveReady and orb.fraction > 0 and orb.fraction < 1
	orb.Wave:SetShown(partial)
	orb.WaveCap:SetShown(partial)
	orb.Surface:SetShown(partial and orb.hasSurface)
	if partial then
		-- Pan within two identical periods; never wrap into an atlas neighbor.
		local left = 0.25 + STYLE.waveTravel * math.sin(orb.wavePhase)
		orb.WaveCap:SetTexCoord(left, left + 0.5, 0, 1)
		orb.Surface:SetTexCoord(left, left + 0.5, 0, 1)
	end
end

local function ensureAssets(orb)
	if orb.assetsReady then return end
	local empty = applyAtlas(orb.Empty, STYLE.glass, STYLE.glassCrop)
	local flow, flowInfo = applyAtlas(orb.Flow, STYLE.flow, STYLE.flowCrop)
	local drift, driftInfo = applyAtlas(orb.Drift, STYLE.flow, STYLE.driftCrop)
	local glass = applyAtlas(orb.Glass, STYLE.glass, STYLE.glassCrop)
	local glow = applyAtlas(orb.Glow, STYLE.glow)
	local ring = applyAtlas(orb.Ring, STYLE.ring)
		or applyAtlas(orb.Ring, STYLE.ringFallback)
	ensureWaveAssets(orb)
	orb.hasFlow, orb.hasDrift, orb.hasGlow = flow, drift, glow
	if flow then
		orb.flowUV = cloudCoordinates(flowInfo, STYLE.flowCrop)
		rotateCloud(orb.Flow, orb.flowUV, -orb.phase)
	end
	if drift then
		orb.driftUV = cloudCoordinates(driftInfo, STYLE.driftCrop)
		rotateCloud(orb.Drift, orb.driftUV, orb.driftPhase)
	end
	-- Decorative atlases are optional: the liquid must still move if one is
	-- unavailable on this client, and the next bind may retry the missing art.
	orb.ready = empty
	orb.assetsReady = orb.ready and flow and drift and glass and glow and ring
		and orb.waveReady and orb.hasSurface
end

function Orb:Resize(orb)
	local size = math.max(1, math.min(orb.cell:GetWidth(), orb.cell:GetHeight()))
	orb.Root:SetSize(size, size)
	orb.innerSize = size * STYLE.innerRatio
	orb.bottomInset = (size - orb.innerSize) / 2
	orb.Clip:SetWidth(size)
	local partial = orb.waveReady and orb.fraction > 0 and orb.fraction < 1
	local padding = partial and orb.innerSize * STYLE.wavePaddingRatio or 0
	orb.Clip:SetHeight(math.max(0.01,
		orb.bottomInset + orb.innerSize * (orb.fraction or 0) + padding))
	for _, wave in ipairs({ orb.WaveCap, orb.Surface }) do
		wave:SetSize(orb.innerSize, orb.innerSize * 2)
		wave:SetPoint("CENTER", orb.Root, "BOTTOM", 0,
			orb.bottomInset + orb.innerSize * (orb.fraction or 0))
	end
	local maskSize = orb.innerSize + STYLE.maskPadding
	for _, circleMask in ipairs({ orb.Mask, orb.ShellMask, orb.WaveCircle, orb.FaceMask }) do
		circleMask:SetSize(maskSize, maskSize)
	end
	orb.Ring:SetSize(size * STYLE.ringScale, size * STYLE.ringScale)
	orb.Ring:SetPoint("CENTER", orb.Root, "CENTER",
		size * STYLE.ringOffsetRatio, -size * STYLE.ringOffsetRatio)
	for _, image in ipairs({ orb.Background, orb.Empty, orb.Fill, orb.Flow, orb.Drift, orb.Glass, orb.Glow }) do
		image:SetSize(orb.innerSize, orb.innerSize)
	end
	updateWave(orb)
end

function Orb:Create(cell)
	local orb = { cell = cell, fraction = 0, phase = (cell.column or 1) * 1.7 }
	orb.driftPhase = orb.phase * 0.63 + 1.04
	orb.wavePhase = orb.phase * 0.77
	orb.Root = frame(cell, 1)
	orb.Root:SetPoint("CENTER", cell, "CENTER")
	-- Recorded progress gets an opaque backing; unknown glass stays transparent.
	orb.Background = texture(orb.Root, "BACKGROUND", -1)
	orb.Background:SetColorTexture(unpack(STYLE.backgroundColor))
	orb.Background:SetBlendMode("BLEND")
	orb.Background:Hide()
	orb.Empty = texture(orb.Root, "BACKGROUND", 0)
	tintGold(orb.Empty, STYLE.shellColor)
	-- This mask stays visible at zero progress, independently of the liquid.
	orb.ShellMask = mask(orb.Root, orb.Root)
	orb.Background:AddMaskTexture(orb.ShellMask)
	orb.Empty:AddMaskTexture(orb.ShellMask)
	orb.Clip = frame(orb.Root, 1)
	orb.Clip:SetPoint("BOTTOM", orb.Root, "BOTTOM")
	orb.Clip:SetClipsChildren(true)
	orb.Fill = texture(orb.Clip, "ARTWORK", 0)
	-- A continuous gold base prevents cloud gaps from exposing dark glass patches.
	orb.Fill:SetColorTexture(1, 1, 1, 1)
	orb.Fill:SetGradient("VERTICAL", CreateColor(unpack(STYLE.fillBottomColor)),
		CreateColor(unpack(STYLE.fillTopColor)))
	orb.Flow = texture(orb.Clip, "ARTWORK", 1)
	tintGold(orb.Flow, STYLE.effectColor)
	orb.Flow:SetBlendMode("ADD")
	orb.Flow:SetAlpha(STYLE.flowAlpha)
	orb.Drift = texture(orb.Clip, "ARTWORK", 2)
	tintGold(orb.Drift, STYLE.effectColor)
	orb.Drift:SetBlendMode("ADD")
	orb.Drift:SetAlpha(STYLE.driftAlpha)
	orb.Mask = mask(orb.Clip, orb.Root)
	orb.Fill:AddMaskTexture(orb.Mask)
	orb.Flow:AddMaskTexture(orb.Mask)
	orb.Drift:AddMaskTexture(orb.Mask)
	-- Paint the empty side of the waterline above the liquid, below the glass.
	-- A travelling non-circular mask on rotated clouds can cut the fill into
	-- blocks in the client. Ordinary textures keep the boundary in orb space;
	-- all liquid textures retain only their original circular mask.
	orb.Wave = frame(orb.Root, 2)
	orb.Wave:SetAllPoints(orb.Root)
	orb.WaveCircle = mask(orb.Wave, orb.Root)
	orb.WaveCap = texture(orb.Wave, "ARTWORK", 0)
	orb.WaveCap:SetVertexColor(unpack(STYLE.backgroundColor))
	orb.WaveCap:SetBlendMode("BLEND")
	orb.WaveCap:AddMaskTexture(orb.WaveCircle)
	orb.Surface = texture(orb.Wave, "ARTWORK", 1)
	orb.Surface:SetVertexColor(unpack(STYLE.waveSurfaceColor))
	orb.Surface:SetBlendMode("ADD")
	orb.Surface:AddMaskTexture(orb.WaveCircle)
	orb.Face = frame(orb.Root, 3)
	orb.Face:SetAllPoints(orb.Root)
	orb.FaceMask = mask(orb.Face, orb.Root)
	orb.Glass = texture(orb.Face, "ARTWORK", 0)
	tintGold(orb.Glass, STYLE.glassColor)
	orb.Glass:SetBlendMode("ADD")
	orb.Glass:AddMaskTexture(orb.FaceMask)
	orb.Glass:SetAlpha(STYLE.glassAlpha)
	orb.Glow = texture(orb.Face, "ARTWORK", 1)
	orb.Glow:SetBlendMode("ADD")
	tintGold(orb.Glow, STYLE.effectColor)
	orb.Glow:AddMaskTexture(orb.FaceMask)
	orb.Glow:SetAlpha(0)
	orb.Ring = texture(orb.Face, "ARTWORK", 2)
	tintGold(orb.Ring, STYLE.ringColor)
	orb.LabelHost = frame(orb.Root, 4)
	orb.LabelHost:SetAllPoints(orb.Root)
	for _, image in ipairs({ orb.Background, orb.Empty, orb.Fill, orb.Flow, orb.Drift, orb.Glass, orb.Glow, orb.Ring }) do
		image:SetPoint("CENTER", orb.Root, "CENTER")
	end
	ensureAssets(orb)
	self:Resize(orb)
	orb.Clip:Hide()
	return orb
end

local function refreshCompletionGlow(orb)
	local alpha = 0
	if orb.flashRemaining then
		local progress = 1 - orb.flashRemaining / STYLE.flashDuration
		local pulse = math.sin(math.pi * progress)
		-- One soft pulse with a smooth start/end; completed idle has no halo.
		alpha = STYLE.flashPeakAlpha * pulse * pulse
	end
	orb.Glow:SetAlpha(alpha)
end

function Orb:Pause(orb)
	-- Never replay a completion burst after returning from a hidden page.
	orb.flashRemaining = nil
	refreshCompletionGlow(orb)
end

function Orb:Bind(orb, slot, identity, resetAt)
	ensureAssets(orb)
	local fraction = slot and slot.threshold > 0
		and math.max(0, math.min(1, slot.progress / slot.threshold)) or 0
	local sameRecord = orb.identity == identity and orb.resetAt == resetAt
	local completedNow = sameRecord and orb.known and slot
		and orb.fraction < 1 and fraction == 1
	if not sameRecord or not slot or fraction < 1 then orb.flashRemaining = nil end
	if completedNow then orb.flashRemaining = STYLE.flashDuration end
	orb.identity, orb.resetAt = identity, resetAt
	orb.known, orb.fraction = slot ~= nil, fraction
	orb.Background:SetShown(orb.known)
	local brightness = fraction > 0 and 1 or STYLE.emptyBrightness
	for _, image in ipairs({ orb.Empty, orb.Glass }) do
		local r, g, b, a = 1, 1, 1, 1
		if orb.known then
			r, g, b, a = unpack(image == orb.Glass and STYLE.glassColor or STYLE.shellColor)
		end
		-- Dim the empty glass without making its dark body more transparent.
		image:SetVertexColor(r * brightness, g * brightness, b * brightness, a)
	end
	orb.Empty:SetAlpha(orb.known and 0.8 or 0.55)
	orb.Glass:SetAlpha(fraction > 0 and STYLE.glassAlpha or STYLE.emptyGlassAlpha)
	orb.Ring:SetDesaturated(true)
	if orb.known then
		orb.Ring:SetVertexColor(unpack(STYLE.ringColor))
	else
		orb.Ring:SetVertexColor(1, 1, 1, 1)
	end
	orb.Ring:SetAlpha(orb.known and 1 or 0.38)
	orb.Clip:SetShown(fraction > 0)
	refreshCompletionGlow(orb)
	self:Resize(orb)
end

function Orb:Advance(orb, elapsed)
	if not orb.ready or orb.fraction <= 0 then return end
	orb.phase = (orb.phase + elapsed * STYLE.phaseSpeed) % (2 * math.pi)
	orb.driftPhase = (orb.driftPhase + elapsed * STYLE.driftSpeed) % (2 * math.pi)
	if orb.waveReady and orb.fraction < 1 then
		orb.wavePhase = (orb.wavePhase + elapsed * STYLE.waveSpeed) % (2 * math.pi)
		updateWave(orb)
	end
	if orb.hasFlow then
		rotateCloud(orb.Flow, orb.flowUV, -orb.phase)
		orb.Flow:SetAlpha(STYLE.flowAlpha + STYLE.flowPulse * math.sin(orb.phase))
	end
	if orb.hasDrift then
		rotateCloud(orb.Drift, orb.driftUV, orb.driftPhase)
		orb.Drift:SetAlpha(STYLE.driftAlpha + STYLE.driftPulse * math.cos(orb.driftPhase))
	end
	if orb.flashRemaining then
		orb.flashRemaining = math.max(0, orb.flashRemaining - elapsed)
		if orb.flashRemaining == 0 then orb.flashRemaining = nil end
	end
	refreshCompletionGlow(orb)
end
