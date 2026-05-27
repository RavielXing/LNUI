------------------------------------------------------------
-- WhisperPopAppearance.lua
-- UI style (classic / borderless) and backdrop colors.
------------------------------------------------------------

local type = type
local tonumber = tonumber

local addon = WhisperPop

-- Reset defaults (also used when SavedVars lack appearance* tables): hex RGB + alpha as opaque fraction.
addon.APPEARANCE_COLOR_DEFAULTS = {
	appearanceMain = { 0, 0, 0, 61 / 100 }, -- #000000, 61% opaque
	appearancePreview = { 0, 0, 0, 61 / 100 }, -- #000000, 61% opaque
	appearanceBorder = { 252 / 255, 252 / 255, 255 / 255, 55 / 100 }, -- #FCFCFF, 55% opaque
}

local function copyAppearanceDefault(key)
	local t = addon.APPEARANCE_COLOR_DEFAULTS[key]
	if type(t) == "table" then
		return { t[1], t[2], t[3], t[4] }
	end
	return { 1, 1, 1, 1 }
end

local DEFAULT_RGBA = { 1, 1, 1, 1 }

-- Classic: border only. Interior fill is a flat ColorTexture (wpAppearanceFill) so RGB matches
-- the color picker; dialog bg blp tiles are dark and multiply vertex color, so tint looked "broken".
local backdropClassicEdge = {
	edgeFile = addon.BORDER,
	edgeSize = 16,
	tileEdge = true,
	insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

-- NineSlice border inner edge vs. our flat fill rarely matches the backdrop inset pixel-perfect;
-- a 1px outward nudge removes the hairline seam (classic UI only).
local CLASSIC_FILL_INSET = 4

local function clamp01(x)
	if x ~= x then
		return 1
	end
	if x < 0 then
		return 0
	end
	if x > 1 then
		return 1
	end
	return x
end

function addon:NormalizeAppearanceRGBA(t)
	if type(t) ~= "table" then
		return { 1, 1, 1, 1 }
	end
	return {
		clamp01(tonumber(t[1]) or 1),
		clamp01(tonumber(t[2]) or 1),
		clamp01(tonumber(t[3]) or 1),
		clamp01(tonumber(t[4]) ~= nil and t[4] or 1),
	}
end

function addon:GetAppearanceRGBA(key)
	local db = self.db
	if not db or type(db[key]) ~= "table" then
		local t = addon.APPEARANCE_COLOR_DEFAULTS[key]
		if type(t) == "table" then
			return t[1], t[2], t[3], t[4]
		end
		return DEFAULT_RGBA[1], DEFAULT_RGBA[2], DEFAULT_RGBA[3], DEFAULT_RGBA[4]
	end
	local n = self:NormalizeAppearanceRGBA(db[key])
	return n[1], n[2], n[3], n[4]
end

function addon:IsUIStyleBorderless()
	local s = self.db and self.db.uiStyle
	if s == self.UI_STYLE_BORDERLESS then
		return true
	end
	--- numeric legacy
	if s == 2 or s == "2" then
		return true
	end
	return false
end

local function applyFrameAppearance(fr, classic, fillR, fillG, fillB, fillA, borderR, borderG, borderB, borderA)
	if not fr then
		return
	end
	local fill = fr.wpAppearanceFill
	if not fill then
		fill = fr:CreateTexture(nil, "BACKGROUND", nil, -8)
		fr.wpAppearanceFill = fill
	end
	fill:SetColorTexture(fillR, fillG, fillB, fillA)

	if fr.SetBackdrop then
		if classic then
			fr:SetBackdrop(backdropClassicEdge)
			if fr.SetBackdropBorderColor then
				fr:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
			end
		else
			fr:SetBackdrop(nil)
		end
	end
	if classic then
		fill:ClearAllPoints()
		local inset = CLASSIC_FILL_INSET
		fill:SetPoint("TOPLEFT", fr, "TOPLEFT", inset, -inset)
		fill:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -inset, inset)
	else
		fill:ClearAllPoints()
		fill:SetAllPoints(fr)
	end
	fill:Show()
end

local function setTopLineVisible(fr, show)
	if not fr then
		return
	end
	local tl = fr.topLine
	if tl and tl.SetShown then
		tl:SetShown(show and true or false)
	end
end

function addon:ApplyAppearance()
	local db = self.db
	if not db then
		return
	end

	local classic = not self:IsUIStyleBorderless()
	local mr, mg, mb, ma = self:GetAppearanceRGBA("appearanceMain")
	local pr, pg, pb, pa = self:GetAppearanceRGBA("appearancePreview")
	local br, bg, bb, ba = self:GetAppearanceRGBA("appearanceBorder")

	local mainF = self.frame
	local msgF = self.messageFrame
	local searchF = self.searchStrip

	applyFrameAppearance(mainF, classic, mr, mg, mb, ma, br, bg, bb, ba)
	applyFrameAppearance(msgF, classic, pr, pg, pb, pa, br, bg, bb, ba)
	if searchF then
		applyFrameAppearance(searchF, classic, mr, mg, mb, ma, br, bg, bb, ba)
	end

	setTopLineVisible(mainF, classic)
	setTopLineVisible(msgF, classic)

	self:BroadcastEvent("OnAppearanceChanged")
end

local appearanceApplyScheduled

function addon:RequestAppearanceApplyNextFrame()
	if appearanceApplyScheduled then
		return
	end
	appearanceApplyScheduled = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			appearanceApplyScheduled = nil
			addon:ApplyAppearance()
		end)
	else
		appearanceApplyScheduled = nil
		addon:ApplyAppearance()
	end
end

function addon:ResetAppearanceColors()
	local db = self.db
	if not db then
		return
	end
	db.appearanceMain = copyAppearanceDefault("appearanceMain")
	db.appearancePreview = copyAppearanceDefault("appearancePreview")
	db.appearanceBorder = copyAppearanceDefault("appearanceBorder")
	self:ApplyAppearance()
end

-- Retail ColorPickerFrame calls swatchFunc/opacityFunc from SimpleColorSelect's OnColorSelect.
-- In some builds, GetColorRGB() is not reliable inside those callbacks; OnColorSelect always
-- receives correct r,g,b — capture them here (one-time script wrap, no per-frame cost).
local function whisperPopEnsureColorPickerRGBHook()
	local cp = ColorPickerFrame
	if not cp or not cp.Content or not cp.Content.ColorPicker then
		return
	end
	local picker = cp.Content.ColorPicker
	if picker.__WhisperPopRGBHook then
		return
	end
	local orig = picker:GetScript("OnColorSelect")
	if type(orig) ~= "function" then
		return
	end
	picker.__WhisperPopRGBHook = true
	picker:SetScript("OnColorSelect", function(self, r, g, b, ...)
		if type(r) == "number" and type(g) == "number" and type(b) == "number" then
			addon._appearancePickerRGB = { r, g, b }
		end
		return orig(self, r, g, b, ...)
	end)
end

local function whisperPopReadPickerRGBA()
	local r, g, b
	local cap = addon._appearancePickerRGB
	if type(cap) == "table" and type(cap[1]) == "number" and type(cap[2]) == "number" and type(cap[3]) == "number" then
		r, g, b = cap[1], cap[2], cap[3]
	end
	if r == nil then
		local cp = ColorPickerFrame
		if cp and cp.GetColorRGB then
			r, g, b = cp:GetColorRGB()
		end
	end
	r, g, b = tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1

	local cp = ColorPickerFrame
	local a = 1
	if cp and cp.GetColorAlpha then
		local ok, v = pcall(cp.GetColorAlpha, cp)
		if ok and v ~= nil then
			a = v
		end
	end
	return r, g, b, a
end

function addon:ShowAppearanceColorPicker(dbKey)
	local db = self.db
	if not db or type(dbKey) ~= "string" or type(db[dbKey]) ~= "table" then
		return
	end

	local initR, initG, initB, initA = self:GetAppearanceRGBA(dbKey)
	local cp = ColorPickerFrame
	if not cp then
		return
	end

	whisperPopEnsureColorPickerRGBHook()
	addon._appearancePickerRGB = { initR, initG, initB }

	local function applyFromPicker()
		local r, g, b, a = whisperPopReadPickerRGBA()
		local t = db[dbKey]
		t[1], t[2], t[3], t[4] = r, g, b, clamp01(a)
		self:RequestAppearanceApplyNextFrame()
	end

	if cp.SetupColorPickerAndShow then
		cp:SetupColorPickerAndShow({
			r = initR,
			g = initG,
			b = initB,
			hasOpacity = true,
			opacity = initA,
			swatchFunc = applyFromPicker,
			opacityFunc = applyFromPicker,
			cancelFunc = function(values)
				if type(values) == "table" then
					db[dbKey][1] = values.r
					db[dbKey][2] = values.g
					db[dbKey][3] = values.b
					db[dbKey][4] = clamp01(values.a ~= nil and values.a or initA)
				else
					db[dbKey][1] = initR
					db[dbKey][2] = initG
					db[dbKey][3] = initB
					db[dbKey][4] = initA
				end
				self:RequestAppearanceApplyNextFrame()
			end,
		})
		return
	end

	cp.hasOpacity = true
	cp.opacity = 1 - initA
	cp.previousValues = { initR, initG, initB, 1 - initA }
	cp.func = function()
		local r, g, b = cp:GetColorRGB()
		local op = (_G.OpacitySliderFrame and _G.OpacitySliderFrame:GetValue()) or (1 - initA)
		local t = db[dbKey]
		t[1], t[2], t[3] = r, g, b
		t[4] = clamp01(1 - op)
		self:RequestAppearanceApplyNextFrame()
	end
	cp.opacityFunc = cp.func
	cp.cancelFunc = function(prev)
		local r, g, b, op = prev[1], prev[2], prev[3], prev[4]
		local t = db[dbKey]
		t[1], t[2], t[3], t[4] = r, g, b, clamp01(1 - op)
		self:RequestAppearanceApplyNextFrame()
	end
	cp:SetColorRGB(initR, initG, initB)
	ShowUIPanel(cp)
end

-- Only the main list frame: message preview shows/hides often; re-applying there would spam OnAppearanceChanged.
local function WhisperPop_HookAppearanceOnShow()
	local fr = addon.frame
	if not fr or fr.wpAppearanceOnShowHook then
		return
	end
	fr.wpAppearanceOnShowHook = true
	fr:HookScript("OnShow", function()
		addon:ApplyAppearance()
	end)
end

addon:RegisterEventCallback("OnInitialize", function()
	addon:ApplyAppearance()
	WhisperPop_HookAppearanceOnShow()
end)

addon:RegisterOptionCallback("uiStyle", function()
	addon:ApplyAppearance()
end)
