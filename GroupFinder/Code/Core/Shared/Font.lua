local _, GF = ...

GF.Font = {}

local F = GF.Font

local FONT_CANDIDATES = {
	"GameFontNormal",
	"ChatFontNormal",
	"NumberFontNormalLarge",
}

local FONT_FALLBACKS = {
	NumberFontNormalLarge = "NumberFontNormal",
}

local DEFAULT_KEY = "GameFontNormal"
local DEFAULT_SIZE = 12
local TOOLTIP_MAX_LINES = 30
local DROPDOWN_MAX_BUTTONS = _G.UIDROPDOWNMENU_MAXBUTTONS or 8
local baselineTemplateSize

local tracked = {}
local trackedEditBoxes = {}
local menuFontByTemplate = {}
local menuFontCacheKey

local MENU_ITEM_METHODS = {
	CreateRadio = "GameFontHighlightSmall",
	CreateCheckbox = "GameFontHighlightSmall",
	CreateButton = "GameFontHighlightSmall",
	CreateTitle = "GameFontNormalSmall",
}

local function copyFontState(fs)
	if not fs or not fs.GetFont then
		return nil
	end
	local path, size, flags = fs:GetFont()
	if type(path) ~= "string" or path == "" then
		return nil
	end
	local fontObject = fs.GetFontObject and fs:GetFontObject()
	return { path, size, flags, fontObject }
end

local function restoreFontState(fs, state)
	if not fs or not state then
		return
	end
	if state[4] and fs.SetFontObject then
		local ok = pcall(fs.SetFontObject, fs, state[4])
		if ok then
			return
		end
	end
	if fs.SetFont and state[1] then
		pcall(fs.SetFont, fs, state[1], state[2], state[3] or "")
	end
end

local function getTemplateFontSize(template)
	local obj = _G[template or "GameFontNormal"]
	if obj and obj.GetFont then
		local _, size = obj:GetFont()
		if size then
			return size
		end
	end
	return 12
end

local function getBaselineTemplateSize()
	if not baselineTemplateSize then
		baselineTemplateSize = getTemplateFontSize(DEFAULT_KEY)
	end
	return baselineTemplateSize
end

local function getFontScaleMultiplier()
	if GF.GetFontScale then
		return GF.GetFontScale()
	end
	local db = GF.GetDB and GF.GetDB()
	local pct = tonumber(db and db.fontScalePct) or (GF.FONT_SCALE_DEFAULT_PCT or 100)
	local minV = GF.FONT_SCALE_MIN_PCT or 100
	local maxV = GF.FONT_SCALE_MAX_PCT or 150
	pct = math.max(minV, math.min(maxV, pct))
	return pct / 100
end

local function resolveOutlineFlags(fs)
	if fs and fs._gfFontFlagsOverride then
		return fs._gfFontFlagsOverride
	end
	local db = GF.GetDB and GF.GetDB()
	local fo = db and db.fontOutline or "NONE"
	if fo == "" or fo == "NONE" then
		return ""
	end
	return fo
end

local function resolveFontSize(fs, template, opts)
	opts = opts or {}
	if fs and fs._gfFontSizeOverride then
		local overrideSize = tonumber(fs._gfFontSizeOverride) or DEFAULT_SIZE
		if opts.ignoreFontScale or fs._gfIgnoreFontScale then
			return overrideSize
		end
		return overrideSize * getFontScaleMultiplier()
	end
	local templateSize = getTemplateFontSize(template)
	local size = DEFAULT_SIZE + (templateSize - getBaselineTemplateSize())
	if fs and fs._gfFontSizeExtra then
		size = size + (tonumber(fs._gfFontSizeExtra) or 0)
	end
	if not opts.ignoreFontScale and not (fs and fs._gfIgnoreFontScale) then
		size = size * getFontScaleMultiplier()
	end
	return size
end

local function getFontPath(fontKey)
	if GF.IsLSMFontKey and GF.IsLSMFontKey(fontKey) then
		local LSM = GF.GetSharedMedia and GF.GetSharedMedia()
		local name = GF.GetLSMFontNameFromKey and GF.GetLSMFontNameFromKey(fontKey)
		if LSM and name then
			local path = LSM:Fetch("font", name, true)
			if type(path) == "string" and path ~= "" then
				return path
			end
		end
		return nil
	end
	local baseObj = _G[fontKey]
	if baseObj and baseObj.GetFont then
		local path = baseObj:GetFont()
		if type(path) == "string" and path ~= "" then
			return path
		end
	end
	return nil
end

local function applyFontFallback(fs, size, flags)
	local fallback = _G.ChatFontNormal or _G.GameFontNormal
	if not fallback then
		return false
	end
	if fallback.GetFont then
		local path, fbSize, fbFlags = fallback:GetFont()
		if type(path) == "string" and path ~= "" then
			pcall(fs.SetFont, fs, path, size or fbSize or 14, flags ~= nil and flags or (fbFlags or ""))
			return true
		end
	end
	if fs.SetFontObject then
		fs:SetFontObject(fallback)
		return true
	end
	return false
end

local function fitFontStringToWidth(fs)
	if not (fs and fs.GetFont and fs.SetFont) then
		return
	end
	local maxWidth = tonumber(fs._gfFitWidth)
	if not maxWidth or maxWidth <= 0 then
		return
	end
	local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
	if not measure then
		return
	end
	local okWidth, textWidth = pcall(measure, fs)
	textWidth = okWidth and tonumber(textWidth) or nil
	if not textWidth or textWidth <= maxWidth then
		fs._gfFittedFontSize = nil
		return
	end
	local path, size, flags = fs:GetFont()
	size = tonumber(size)
	if type(path) ~= "string" or path == "" or not size or size <= 0 then
		return
	end
	local minimum = math.max(1, tonumber(fs._gfFitMinSize) or 6)
	local fitted = math.max(
		minimum,
		math.floor((size * maxWidth / textWidth) * 100) / 100
	)
	if fitted >= size then
		fs._gfFittedFontSize = nil
		return
	end
	if pcall(fs.SetFont, fs, path, fitted, flags or "") then
		fs._gfFittedFontSize = fitted
	end
end

function F.GetFontOptions()
	local L = GF.L or {}
	local out = {}
	for _, name in ipairs(FONT_CANDIDATES) do
		local value = name
		local fo = _G[value]
		if not fo and FONT_FALLBACKS[name] then
			value = FONT_FALLBACKS[name]
			fo = _G[value]
		end
		if fo then
			local label = L["FONTOBJECT_" .. name] or L["FONTOBJECT_" .. value] or value
			out[#out + 1] = { value = value, label = label }
		end
	end
	if #out == 0 then
		out[1] = { value = "GameFontNormal", label = L.FONTOBJECT_GameFontNormal or "GameFontNormal" }
	end
	if GF.AppendLSMFontOptions then
		GF.AppendLSMFontOptions(out)
	end
	return out
end

function F.GetOutlineOptions()
	local L = GF.L or {}
	return {
		{ value = "NONE", label = L.FONT_OUTLINE_NONE or "No outline" },
		{ value = "OUTLINE", label = L.FONT_OUTLINE_NORMAL or "Outline" },
		{ value = "THICKOUTLINE", label = L.FONT_OUTLINE_THICK or "Thick outline" },
	}
end

function F.ResolveFontObjectKey(key)
	if type(key) ~= "string" then
		return DEFAULT_KEY
	end
	if GF.IsLSMFontKey and GF.IsLSMFontKey(key) then
		if GF.ResolveLSMFontKey and GF.ResolveLSMFontKey(key) then
			return key
		end
		return key
	end
	if _G[key] then
		return key
	end
	local fb = FONT_FALLBACKS[key]
	if fb and _G[fb] then
		return fb
	end
	for _, row in ipairs(F.GetFontOptions()) do
		if row.value == key then
			return key
		end
	end
	return DEFAULT_KEY
end

function F.GetFontObjectKey()
	local db = GF.GetDB and GF.GetDB()
	return F.ResolveFontObjectKey(db and db.fontKey or DEFAULT_KEY)
end

local function getMenuFontCacheKey()
	local scalePct = GF.GetFontScalePct and GF.GetFontScalePct() or (GF.FONT_SCALE_DEFAULT_PCT or 100)
	return tostring(F.GetFontObjectKey()) .. ":" .. tostring(scalePct)
end

local function ensureMenuFontObject(template)
	template = template or "GameFontHighlightSmall"
	local cacheKey = getMenuFontCacheKey()
	if menuFontCacheKey ~= cacheKey then
		menuFontByTemplate = {}
		menuFontCacheKey = cacheKey
	end
	local obj = menuFontByTemplate[template]
	if obj then
		return obj
	end
	local globalName = "GF_MenuFont_" .. template:gsub("[^%w]", "_")
	obj = _G[globalName]
	if not obj then
		obj = CreateFont(globalName)
	end
	local path = getFontPath(F.GetFontObjectKey())
	local size = resolveFontSize(nil, template)
	if path then
		obj:SetFont(path, size, "")
	else
		local fo = _G[template] or _G.GameFontHighlightSmall
		if fo and fo.GetFont then
			local fallbackPath = fo:GetFont()
			if type(fallbackPath) == "string" and fallbackPath ~= "" then
				obj:SetFont(fallbackPath, size, "")
			end
		end
	end
	menuFontByTemplate[template] = obj
	return obj
end

local function applyMenuFontString(fs, template)
	if not fs then
		return
	end
	template = template or "GameFontHighlightSmall"
	local fontObj = ensureMenuFontObject(template)
	if fontObj and fs.SetFontObject then
		pcall(fs.SetFontObject, fs, fontObj)
	end
end

local function addMenuFontInitializer(item, template)
	if not item or not item.AddInitializer then
		return
	end
	item:AddInitializer(function(button)
		if button and button.fontString then
			applyMenuFontString(button.fontString, template)
		end
	end)
end

function F.ApplyToMenuFontString(fs, template)
	applyMenuFontString(fs, template)
end

function F.GetMenuFontObject(template)
	return ensureMenuFontObject(template)
end

function F.ApplyToDropdownButton(btn, template)
	if not btn then
		return
	end
	template = template or "GameFontHighlightSmall"
	local fontObj = ensureMenuFontObject(template)
	if not fontObj then
		return
	end
	if btn.SetNormalFontObject then
		btn:SetNormalFontObject(fontObj)
	end
	if btn.SetHighlightFontObject then
		btn:SetHighlightFontObject(fontObj)
	end
	local disabledObj = ensureMenuFontObject("GameFontDisableSmall")
	if btn.SetDisabledFontObject and disabledObj then
		btn:SetDisabledFontObject(disabledObj)
	end
	for _, suffix in ipairs({ "NormalText", "DisabledText", "HighlightText" }) do
		local fs = btn[suffix]
		if fs then
			local t = suffix == "DisabledText" and "GameFontDisableSmall" or template
			applyMenuFontString(fs, t)
		end
	end
end

local function applyContextMenuFontString(fs, template)
	if not fs or not fs.SetFont then
		return
	end
	template = template or "GameFontHighlight"
	local size = resolveFontSize(nil, DEFAULT_KEY, { ignoreFontScale = true }) + (GF.CONTEXT_MENU_TEXT_SIZE_EXTRA or 4)
	local flags = resolveOutlineFlags(fs)
	local path = getFontPath(F.GetFontObjectKey())
	if path then
		local ok = pcall(fs.SetFont, fs, path, size, flags)
		if ok then
			return
		end
	end
	local fo = _G[template] or _G.GameFontHighlight
	if fo and fo.GetFont then
		local fbPath = fo:GetFont()
		if type(fbPath) == "string" and fbPath ~= "" then
			pcall(fs.SetFont, fs, fbPath, size, flags)
		end
	end
end

local function restoreContextDropdownFonts(list)
	local snapshots = list and list._gfContextMenuFontSnapshots
	if not snapshots then
		return
	end
	for button, bySuffix in pairs(snapshots) do
		if button and bySuffix then
			for suffix, state in pairs(bySuffix) do
				restoreFontState(button[suffix], state)
			end
		end
	end
	list._gfContextMenuFontSnapshots = nil
end

local function ensureContextDropdownRestore(list)
	if not list or list._gfContextMenuFontRestoreHooked then
		return
	end
	list._gfContextMenuFontRestoreHooked = true
	list:HookScript("OnHide", restoreContextDropdownFonts)
end

local function snapshotContextDropdownButton(btn)
	local list = btn and btn.GetParent and btn:GetParent()
	if not list or not list._gfContextMenuFontSnapshots or list._gfContextMenuFontSnapshots[btn] then
		return
	end
	local snap = {}
	local hasSnapshot = false
	for _, suffix in ipairs({ "NormalText", "DisabledText", "HighlightText" }) do
		local state = copyFontState(btn[suffix])
		if state then
			snap[suffix] = state
			hasSnapshot = true
		end
	end
	if hasSnapshot then
		list._gfContextMenuFontSnapshots[btn] = snap
	end
end

function F.BeginContextDropdownFonts(list)
	if not list then
		return
	end
	ensureContextDropdownRestore(list)
	if not list._gfContextMenuFontSnapshots then
		list._gfContextMenuFontSnapshots = {}
	end
end

function F.ApplyToContextMenuFontString(fs, template)
	applyContextMenuFontString(fs, template)
end

function F.ApplyToContextMenuDropdownButton(btn, template)
	if not btn then
		return
	end
	snapshotContextDropdownButton(btn)
	template = template or "GameFontHighlight"
	for _, suffix in ipairs({ "NormalText", "DisabledText", "HighlightText" }) do
		local fs = btn[suffix]
		if fs then
			applyContextMenuFontString(fs, template)
		end
	end
end

function F.ApplyToEditBox(box, template)
	if not box or not box.SetFont then
		return
	end
	template = template or "GameFontNormal"
	local fontKey = F.GetFontObjectKey()
	local size = resolveFontSize(box, template)
	local flags = resolveOutlineFlags(box)
	local path = getFontPath(fontKey)
	if path then
		local ok = pcall(box.SetFont, box, path, size, flags)
		if ok then
			return
		end
	end
	local fo = _G[template] or _G.GameFontNormal
	if fo and fo.GetFont then
		local fbPath = fo:GetFont()
		if type(fbPath) == "string" and fbPath ~= "" then
			pcall(box.SetFont, box, fbPath, size, flags)
		end
	end
end

function F.TrackEditBox(box, template)
	if not box then
		return
	end
	template = template or "GameFontNormal"
	box._gfFontTemplate = template
	if box._gfEditTracked then
		F.ApplyToEditBox(box, template)
		return
	end
	box._gfEditTracked = true
	trackedEditBoxes[#trackedEditBoxes + 1] = box
	F.ApplyToEditBox(box, template)
end

function F.ApplyToFontString(fs, template)
	if not fs or not fs.SetFont then
		return
	end
	template = template or fs._gfFontTemplate or "GameFontNormal"
	local fontKey = F.GetFontObjectKey()
	local size = resolveFontSize(fs, template)
	local flags = resolveOutlineFlags(fs)
	local path = getFontPath(fontKey)
	local applied = false
	if path then
		local ok = pcall(fs.SetFont, fs, path, size, flags)
		if ok then
			applied = true
		end
	end
	if not applied then
		applied = applyFontFallback(fs, size, flags)
	end
	if applied then
		fitFontStringToWidth(fs)
	end
end

function F.SetFitWidth(fs, maxWidth, minimumSize)
	if not fs then
		return
	end
	fs._gfFitWidth = tonumber(maxWidth)
	fs._gfFitMinSize = tonumber(minimumSize)
	F.ApplyToFontString(fs, fs._gfFontTemplate)
end

function F.Track(fs, template)
	if not fs then
		return
	end
	template = template or "GameFontNormal"
	if fs._gfFontTracked then
		fs._gfFontTemplate = template
		F.ApplyToFontString(fs, template)
		return
	end
	fs._gfFontTracked = true
	fs._gfFontTemplate = template
	tracked[#tracked + 1] = fs
	F.ApplyToFontString(fs, template)
end

function F.TrackButton(btn, template)
	if not btn or not btn.GetFontString then
		return
	end
	F.Track(btn:GetFontString(), template or "GameFontNormal")
end

local function forEachTooltipFontString(tooltip, visit)
	if not tooltip or not visit then
		return
	end
	for i = 1, TOOLTIP_MAX_LINES do
		for _, suffix in ipairs({ "TextLeft", "TextRight" }) do
			local fs = tooltip[suffix .. i]
			if fs then
				visit(fs, i, suffix)
			end
		end
	end
end

local function snapshotTooltipFonts(tooltip)
	local snap = { lines = {} }
	if tooltip.GetFont then
		snap.frame = copyFontState(tooltip)
	end
	forEachTooltipFontString(tooltip, function(fs, i, suffix)
		local key = suffix .. i
		snap.lines[key] = copyFontState(fs)
	end)
	return snap
end

local function restoreTooltipFonts(tooltip, snap)
	if not tooltip or not snap then
		return
	end
	if snap.frame and tooltip.SetFont then
		if snap.frame[4] and tooltip.SetFontObject then
			pcall(tooltip.SetFontObject, tooltip, snap.frame[4])
		else
			tooltip:SetFont(snap.frame[1], snap.frame[2], snap.frame[3])
		end
	end
	for key, state in pairs(snap.lines or {}) do
		local fs = tooltip[key]
		if fs and state then
			if state[4] and fs.SetFontObject then
				pcall(fs.SetFontObject, fs, state[4])
			else
				fs:SetFont(state[1], state[2], state[3])
			end
		end
	end
end

local function defaultTooltipFontObject(index, suffix)
	if index == 1 and suffix == "TextLeft" then
		return _G.GameTooltipHeaderText or _G.GameFontNormalLarge or _G.GameFontNormal
	end
	return _G.GameTooltipText or _G.GameFontHighlightSmall or _G.GameFontNormal
end

local function applyDefaultTooltipFont(fs, index, suffix)
	if not fs then
		return
	end
	local fontObject = defaultTooltipFontObject(index, suffix)
	if fontObject and fs.SetFontObject then
		local ok = pcall(fs.SetFontObject, fs, fontObject)
		if ok then
			return
		end
	end
	if fontObject and fontObject.GetFont and fs.SetFont then
		local path, size, flags = fontObject:GetFont()
		if type(path) == "string" and path ~= "" then
			pcall(fs.SetFont, fs, path, size, flags or "")
		end
	end
end

local function applyDefaultTooltipFrameFont(tooltip)
	if not tooltip or not tooltip.SetFont then
		return
	end
	local fontObject = _G.GameTooltipText or _G.GameFontHighlightSmall or _G.GameFontNormal
	if fontObject and fontObject.GetFont then
		local path, size, flags = fontObject:GetFont()
		if type(path) == "string" and path ~= "" then
			pcall(tooltip.SetFont, tooltip, path, size, flags or "")
		end
	end
end

local function ensureTooltipHideHook(tooltip)
	if not tooltip or tooltip._gfTooltipHideHooked then
		return
	end
	tooltip._gfTooltipHideHooked = true
	tooltip:HookScript("OnHide", function(self)
		if self._gfFontOwned and self._gfFontSnapshot then
			restoreTooltipFonts(self, self._gfFontSnapshot)
			self._gfFontSnapshot = nil
			self._gfFontOwned = nil
		end
	end)
end

function F.BeginTooltipFont(tooltip)
	tooltip = tooltip or GameTooltip
	if not tooltip then
		return
	end
	ensureTooltipHideHook(tooltip)
	if tooltip._gfFontOwned then
		return
	end
	tooltip._gfFontSnapshot = snapshotTooltipFonts(tooltip)
	tooltip._gfFontOwned = true
end

function F.ApplyTooltipFont(tooltip)
	tooltip = tooltip or GameTooltip
	if not tooltip then
		return
	end
	applyDefaultTooltipFrameFont(tooltip)
	forEachTooltipFontString(tooltip, function(fs, i, suffix)
		applyDefaultTooltipFont(fs, i, suffix)
	end)
	if tooltip.IsShown and tooltip:IsShown() and tooltip.Show then
		tooltip:Show()
	end
end

function F.ApplyDropdownMenuFont()
	for i = 1, DROPDOWN_MAX_BUTTONS do
		local btn = _G["DropDownList1Button" .. i]
		if btn and (not btn.IsShown or btn:IsShown()) then
			F.ApplyToDropdownButton(btn, "GameFontHighlightSmall")
		end
	end
	local title = _G.DropDownList1Title
	if title then
		F.ApplyToMenuFontString(title, "GameFontNormalSmall")
	end
end

local function walkMenuFrameFontStrings(frame, visit)
	if not frame or not visit then
		return
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region and region.GetObjectType and region:GetObjectType() == "FontString" then
			visit(region)
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		walkMenuFrameFontStrings(child, visit)
	end
end

function F.WrapMenuRoot(rootDescription, template)
	if not rootDescription or rootDescription._gfMenuFontWrapped then
		return
	end
	rootDescription._gfMenuFontWrapped = true
	template = template or "GameFontHighlightSmall"
	for methodName, itemTemplate in pairs(MENU_ITEM_METHODS) do
		local orig = rootDescription[methodName]
		if type(orig) == "function" then
			rootDescription[methodName] = function(self, ...)
				local item = orig(self, ...)
				addMenuFontInitializer(item, itemTemplate or template)
				return item
			end
		end
	end
end

function F.TrackDropdownButton(btn, template)
	if not btn or btn._gfDropdownTracked then
		return
	end
	btn._gfDropdownTracked = true
	template = template or "GameFontHighlightSmall"
	walkMenuFrameFontStrings(btn, function(fs)
		F.Track(fs, template)
	end)
end

function F.RefreshAll()
	for i = #tracked, 1, -1 do
		local fs = tracked[i]
		if not fs or not fs.GetObjectType or fs:GetObjectType() ~= "FontString" then
			table.remove(tracked, i)
		else
			F.ApplyToFontString(fs, fs._gfFontTemplate)
		end
	end
	for i = #trackedEditBoxes, 1, -1 do
		local box = trackedEditBoxes[i]
		if not box or not box.SetFont then
			table.remove(trackedEditBoxes, i)
		else
			F.ApplyToEditBox(box, box._gfFontTemplate)
		end
	end
	if GF.TabBar and GF.TabBar.RefreshFonts then
		GF.TabBar:RefreshFonts()
	end
end
