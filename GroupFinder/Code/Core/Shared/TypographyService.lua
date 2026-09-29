local _, GF = ...

local Typography = {}
GF.TypographyService = Typography

local DEFAULT_TEMPLATE = "GameFontNormal"
local DEFAULT_SIZE = 12
local TOOLTIP_LINE_LIMIT = 30

local BUILTIN_FONTS = {
	{ key = "GameFontNormal" },
	{ key = "ChatFontNormal" },
	{ key = "NumberFontNormalLarge", fallback = "NumberFontNormal" },
}

local OUTLINES = {
	{ value = "NONE", localeKey = "FONT_OUTLINE_NONE", fallback = "No outline" },
	{ value = "OUTLINE", localeKey = "FONT_OUTLINE_NORMAL", fallback = "Outline" },
	{ value = "THICKOUTLINE", localeKey = "FONT_OUTLINE_THICK", fallback = "Thick outline" },
}

local MENU_BUILDERS = {
	{ method = "CreateRadio", template = "GameFontHighlightSmall" },
	{ method = "CreateCheckbox", template = "GameFontHighlightSmall" },
	{ method = "CreateButton", template = "GameFontHighlightSmall" },
	{ method = "CreateTitle", template = "GameFontNormalSmall" },
}

local BUTTON_FONT_REGIONS = {
	NormalText = "normal",
	DisabledText = "disabled",
	HighlightText = "normal",
}

local function weakKeys()
	return setmetatable({}, { __mode = "k" })
end

-- A single weak registry owns every refreshable control. Values never retain keys.
local controls = weakKeys()
local tooltipSessions = weakKeys()
local tooltipHooks = weakKeys()
local menuFonts = {}
local sampledMenuFonts = weakKeys()
local sampledMenuFontCount = 0
local menuRevision = 1
local normalTemplateBaseline

local function supports(owner, methodName)
	return owner ~= nil and type(owner[methodName]) == "function"
end

local function setFont(owner, path, size, flags)
	local numericSize = tonumber(size)
	if not supports(owner, "SetFont")
		or type(path) ~= "string"
		or path == ""
		or not numericSize
		or numericSize <= 0 then
		return false
	end
	local ok, result = pcall(owner.SetFont, owner, path, numericSize, flags or "")
	return ok and result ~= false
end

local function snapshotFont(owner)
	if not supports(owner, "GetFont") then
		return nil
	end
	local ok, path, size, flags = pcall(owner.GetFont, owner)
	if not ok then
		return nil
	end

	local fontObject
	if supports(owner, "GetFontObject") then
		local objectOK, object = pcall(owner.GetFontObject, owner)
		if objectOK then
			fontObject = object
		end
	end
	if not fontObject and (type(path) ~= "string" or path == "") then
		return nil
	end
	return {
		object = fontObject,
		path = path,
		size = size,
		flags = flags,
	}
end

local function restoreFont(owner, snapshot)
	if not owner or not snapshot then
		return false
	end
	if snapshot.object and supports(owner, "SetFontObject") then
		local ok = pcall(owner.SetFontObject, owner, snapshot.object)
		if ok then
			return true
		end
	end
	return setFont(owner, snapshot.path, snapshot.size, snapshot.flags)
end

local function nativeObject(primaryName, fallbackName)
	local primary = type(primaryName) == "string" and _G[primaryName] or nil
	if supports(primary, "GetFont") then
		return primary
	end
	local fallback = type(fallbackName) == "string" and _G[fallbackName] or nil
	if supports(fallback, "GetFont") then
		return fallback
	end
	return _G.GameFontNormal or _G.ChatFontNormal
end

local function nativePath(primaryName, fallbackName)
	local object = nativeObject(primaryName, fallbackName)
	if not object then
		return nil
	end
	local ok, path = pcall(object.GetFont, object)
	if ok and type(path) == "string" and path ~= "" then
		return path
	end
	return nil
end

local function templateSize(template)
	local object = nativeObject(template, DEFAULT_TEMPLATE)
	if object then
		local ok, _, size = pcall(object.GetFont, object)
		if ok and tonumber(size) then
			return tonumber(size)
		end
	end
	return DEFAULT_SIZE
end

local function normalTemplateSize()
	if normalTemplateBaseline == nil then
		normalTemplateBaseline = templateSize(DEFAULT_TEMPLATE)
	end
	return normalTemplateBaseline
end

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function selectedScale()
	local minimum = tonumber(GF.FONT_SCALE_MIN_PCT) or 100
	local maximum = tonumber(GF.FONT_SCALE_MAX_PCT) or 150
	local percentage

	if type(GF.GetFontScale) == "function" then
		local ok, multiplier = pcall(GF.GetFontScale)
		if ok and tonumber(multiplier) then
			percentage = tonumber(multiplier) * 100
		end
	end
	if percentage == nil and type(GF.GetFontScalePct) == "function" then
		local ok, value = pcall(GF.GetFontScalePct)
		if ok then
			percentage = tonumber(value)
		end
	end
	if percentage == nil then
		local database = type(GF.GetDB) == "function" and GF.GetDB() or nil
		percentage = tonumber(database and database.fontScalePct)
			or tonumber(GF.FONT_SCALE_DEFAULT_PCT)
			or 100
	end
	return clamp(percentage, minimum, maximum) / 100
end

local function selectedFlags(owner)
	if owner and owner._gfFontFlagsOverride ~= nil then
		return owner._gfFontFlagsOverride or ""
	end
	local database = type(GF.GetDB) == "function" and GF.GetDB() or nil
	local flags = database and database.fontOutline or "NONE"
	if flags == "" or flags == "NONE" then
		return ""
	end
	return flags
end

local function selectedSize(owner, template, ignoreScale)
	local size
	if owner and owner._gfFontSizeOverride ~= nil then
		size = tonumber(owner._gfFontSizeOverride) or DEFAULT_SIZE
	else
		local compat = GF.ElvUICompat
		local offset = compat and compat.GetNativeTemplateOffset(template)
		if offset == nil then
			offset = templateSize(template) - normalTemplateSize()
		end
		size = DEFAULT_SIZE + offset
		if owner and owner._gfFontSizeExtra ~= nil then
			size = size + (tonumber(owner._gfFontSizeExtra) or 0)
		end
	end
	if not ignoreScale and not (owner and owner._gfIgnoreFontScale) then
		size = size * selectedScale()
	end
	return math.max(1, size)
end

local function mediaAdapter()
	return GF.SharedMediaFontAdapter
end

local function isMediaKey(key)
	local adapter = mediaAdapter()
	if adapter and type(adapter.IsStorageKey) == "function" then
		return adapter.IsStorageKey(key)
	end
	return type(GF.IsLSMFontKey) == "function" and GF.IsLSMFontKey(key) or false
end

local function mediaPath(key)
	local adapter = mediaAdapter()
	if adapter and type(adapter.FetchPath) == "function" then
		return adapter.FetchPath(key)
	end
	if not isMediaKey(key) then
		return nil
	end
	local library = type(GF.GetSharedMedia) == "function" and GF.GetSharedMedia() or nil
	local name = type(GF.GetLSMFontNameFromKey) == "function"
		and GF.GetLSMFontNameFromKey(key)
		or nil
	if not (library and name and type(library.Fetch) == "function") then
		return nil
	end
	local ok, path = pcall(library.Fetch, library, "font", name, true)
	return ok and type(path) == "string" and path ~= "" and path or nil
end

local function pathForKey(key)
	local sharedPath = mediaPath(key)
	if sharedPath then
		return sharedPath
	end
	local object = type(key) == "string" and _G[key] or nil
	if supports(object, "GetFont") then
		local ok, path = pcall(object.GetFont, object)
		if ok and type(path) == "string" and path ~= "" then
			return path
		end
	end
	return nil
end

local function selectedPath()
	return pathForKey(Typography.GetFontObjectKey())
end

local function applyAppearance(owner, template, options)
	if not supports(owner, "SetFont") then
		return false
	end
	template = template or DEFAULT_TEMPLATE
	options = options or {}
	local size = selectedSize(owner, template, options.ignoreScale == true)
	local flags = options.flags
	if flags == nil then
		flags = selectedFlags(owner)
	end

	if setFont(owner, selectedPath(), size, flags) then
		return true
	end
	local fallbackTemplate = options.fallbackTemplate or DEFAULT_TEMPLATE
	if setFont(owner, nativePath(template, fallbackTemplate), size, flags) then
		return true
	end
	local fallbackObject = nativeObject(template, fallbackTemplate)
	if fallbackObject and supports(owner, "SetFontObject") then
		local ok = pcall(owner.SetFontObject, owner, fallbackObject)
		return ok
	end
	return false
end

local function isFontString(fontString)
	if not supports(fontString, "SetFont") then
		return false
	end
	if not supports(fontString, "GetObjectType") then
		return true
	end
	local ok, objectType = pcall(fontString.GetObjectType, fontString)
	return not ok or objectType == "FontString"
end

local function measuredWidth(fontString)
	local measure = fontString
		and (fontString.GetUnboundedStringWidth or fontString.GetStringWidth)
	if type(measure) ~= "function" then
		return nil
	end
	local ok, rawWidth = pcall(measure, fontString)
	if not ok then
		return nil
	end
	local numberOK, width = pcall(tonumber, rawWidth)
	return numberOK and width or nil
end

local function fitToWidth(fontString)
	local limit = tonumber(fontString and fontString._gfFitWidth)
	if not limit or limit <= 0 then
		if fontString then
			fontString._gfFittedFontSize = nil
		end
		return
	end
	local width = measuredWidth(fontString)
	if not width or width <= limit then
		fontString._gfFittedFontSize = nil
		return
	end
	local ok, path, size, flags = pcall(fontString.GetFont, fontString)
	size = ok and tonumber(size) or nil
	if type(path) ~= "string" or path == "" or not size or size <= 0 then
		return
	end
	local minimum = math.max(1, tonumber(fontString._gfFitMinSize) or 6)
	local fittedSize = math.max(minimum, math.floor(size * limit / width * 100) / 100)
	if fittedSize >= size then
		fontString._gfFittedFontSize = nil
		return
	end
	if setFont(fontString, path, fittedSize, flags) then
		fontString._gfFittedFontSize = fittedSize
	end
end

function Typography.GetFontOptions()
	local locale = GF.L or {}
	local options = {}
	for _, definition in ipairs(BUILTIN_FONTS) do
		local actualKey = definition.key
		if not pathForKey(actualKey) and definition.fallback then
			actualKey = definition.fallback
		end
		if pathForKey(actualKey) then
			options[#options + 1] = {
				value = actualKey,
				label = locale["FONTOBJECT_" .. definition.key]
					or locale["FONTOBJECT_" .. actualKey]
					or actualKey,
			}
		end
	end
	if #options == 0 then
		options[1] = {
			value = DEFAULT_TEMPLATE,
			label = locale.FONTOBJECT_GameFontNormal or DEFAULT_TEMPLATE,
		}
	end
	local adapter = mediaAdapter()
	if adapter and type(adapter.AppendOptions) == "function" then
		adapter.AppendOptions(options)
	elseif type(GF.AppendLSMFontOptions) == "function" then
		GF.AppendLSMFontOptions(options)
	end
	return options
end

function Typography.GetOutlineOptions()
	local locale = GF.L or {}
	local options = {}
	for index, definition in ipairs(OUTLINES) do
		options[index] = {
			value = definition.value,
			label = locale[definition.localeKey] or definition.fallback,
		}
	end
	return options
end

function Typography.ResolveFontObjectKey(key)
	if type(key) ~= "string" then
		return DEFAULT_TEMPLATE
	end
	if isMediaKey(key) then
		return key
	end
	if pathForKey(key) then
		return key
	end
	for _, definition in ipairs(BUILTIN_FONTS) do
		if definition.key == key
			and definition.fallback
			and pathForKey(definition.fallback) then
			return definition.fallback
		end
	end
	for _, option in ipairs(Typography.GetFontOptions()) do
		if option.value == key then
			return key
		end
	end
	return DEFAULT_TEMPLATE
end

function Typography.GetFontObjectKey()
	local database = type(GF.GetDB) == "function" and GF.GetDB() or nil
	return Typography.ResolveFontObjectKey(
		database and database.fontKey or DEFAULT_TEMPLATE
	)
end

local function menuFontName(template)
	local suffix = tostring(template or "Default"):gsub("[^%w_]", "_")
	return "GroupFinderMenuFont_" .. suffix
end

local function configureMenuFont(fontObject, template)
	local source = nativeObject(template, "GameFontHighlightSmall")
	if source and supports(fontObject, "CopyFontObject") then
		pcall(fontObject.CopyFontObject, fontObject, source)
	end
	local path = selectedPath() or nativePath(template, "GameFontHighlightSmall")
	return setFont(fontObject, path, selectedSize(nil, template, false), "")
end

local function menuFont(template)
	template = template or "GameFontHighlightSmall"
	local slot = menuFonts[template]
	if not slot then
		local globalName = menuFontName(template)
		local object = _G[globalName]
		if not object and type(CreateFont) == "function" then
			local ok, created = pcall(CreateFont, globalName)
			if ok then
				object = created
			end
		end
		if not object then
			return nativeObject(template, "GameFontHighlightSmall")
		end
		slot = { object = object, revision = 0 }
		menuFonts[template] = slot
	end
	if slot.revision ~= menuRevision then
		configureMenuFont(slot.object, template)
		slot.revision = menuRevision
	end
	return slot.object
end

local function applyMenuFont(fontString, template)
	if not supports(fontString, "SetFontObject") then
		return
	end
	local object = menuFont(template or "GameFontHighlightSmall")
	if object then
		pcall(fontString.SetFontObject, fontString, object)
	end
end

-- A persistent addon-owned source can supply exact typography for a menu.
-- Only owned Font objects receive SetFont; compositor FontStrings prohibit it.
local function sampledMenuFont(source, scale)
	local sample = snapshotFont(source)
	scale = tonumber(scale) or 1
	if not sample or type(sample.path) ~= "string" or sample.path == ""
		or type(sample.size) ~= "number" or sample.size <= 0 or scale <= 0 then
		return nil
	end
	local object = sampledMenuFonts[source]
	if not object and type(CreateFont) == "function" then
		sampledMenuFontCount = sampledMenuFontCount + 1
		local ok, created = pcall(CreateFont,
			"GroupFinderMenuFont_Sampled_" .. sampledMenuFontCount)
		if ok then
			object = created
			sampledMenuFonts[source] = object
		end
	end
	if object and setFont(object, sample.path, sample.size * scale, sample.flags) then
		return object
	end
end

function Typography.ApplyToMenuFontString(fontString, template, source, scale)
	local object = source and sampledMenuFont(source, scale)
	if object and supports(fontString, "SetFontObject") then
		pcall(fontString.SetFontObject, fontString, object)
	else
		applyMenuFont(fontString, template)
	end
end

function Typography.ApplyToDropdownButton(button, template)
	if not button then
		return
	end
	template = template or "GameFontHighlightSmall"
	local normal = menuFont(template)
	local disabled = menuFont("GameFontDisableSmall")
	if normal and supports(button, "SetNormalFontObject") then
		pcall(button.SetNormalFontObject, button, normal)
	end
	if normal and supports(button, "SetHighlightFontObject") then
		pcall(button.SetHighlightFontObject, button, normal)
	end
	if disabled and supports(button, "SetDisabledFontObject") then
		pcall(button.SetDisabledFontObject, button, disabled)
	end
	for regionName, role in pairs(BUTTON_FONT_REGIONS) do
		local fontString = button[regionName]
		if fontString then
			applyMenuFont(
				fontString,
				role == "disabled" and "GameFontDisableSmall" or template
			)
		end
	end
end

function Typography.ApplyToEditBox(editBox, template)
	if supports(editBox, "SetFont") then
		applyAppearance(editBox, template or DEFAULT_TEMPLATE, {
			fallbackTemplate = DEFAULT_TEMPLATE,
		})
	end
end

function Typography.TrackEditBox(editBox, template)
	if not editBox then
		return
	end
	template = template or DEFAULT_TEMPLATE
	editBox._gfFontTemplate = template
	editBox._gfEditTracked = true
	controls[editBox] = { kind = "editBox", template = template }
	Typography.ApplyToEditBox(editBox, template)
end

function Typography.ApplyToFontString(fontString, template)
	if not isFontString(fontString) then
		return
	end
	template = template or fontString._gfFontTemplate or DEFAULT_TEMPLATE
	if applyAppearance(fontString, template, { fallbackTemplate = DEFAULT_TEMPLATE }) then
		fitToWidth(fontString)
	end
end

function Typography.SetFitWidth(fontString, maximumWidth, minimumSize)
	if not fontString then
		return
	end
	fontString._gfFitWidth = tonumber(maximumWidth)
	fontString._gfFitMinSize = tonumber(minimumSize)
	local existing = controls[fontString]
	local template = existing and existing.template
		or fontString._gfFontTemplate
		or DEFAULT_TEMPLATE
	controls[fontString] = { kind = "fontString", template = template }
	fontString._gfFontTracked = true
	Typography.ApplyToFontString(fontString, template)
end

function Typography.Track(fontString, template)
	if not fontString then
		return
	end
	template = template or DEFAULT_TEMPLATE
	fontString._gfFontTemplate = template
	fontString._gfFontTracked = true
	controls[fontString] = { kind = "fontString", template = template }
	Typography.ApplyToFontString(fontString, template)
end

function Typography.TrackButton(button, template)
	if not supports(button, "GetFontString") then
		return
	end
	local ok, fontString = pcall(button.GetFontString, button)
	if ok and fontString then
		Typography.Track(fontString, template or DEFAULT_TEMPLATE)
	end
end

local function tooltipLine(tooltip, index, side)
	local fieldName = side .. index
	local direct = tooltip and tooltip[fieldName]
	if direct then
		return direct
	end
	if supports(tooltip, "GetName") then
		local ok, name = pcall(tooltip.GetName, tooltip)
		if ok and type(name) == "string" and name ~= "" then
			return _G[name .. fieldName]
		end
	end
	return nil
end

local function eachTooltipLine(tooltip, callback)
	if not tooltip or type(callback) ~= "function" then
		return
	end
	for index = 1, TOOLTIP_LINE_LIMIT do
		local left = tooltipLine(tooltip, index, "TextLeft")
		if left then
			callback(left, index, "TextLeft")
		end
		local right = tooltipLine(tooltip, index, "TextRight")
		if right then
			callback(right, index, "TextRight")
		end
	end
end

local function captureTooltip(tooltip)
	local session = {
		frame = snapshotFont(tooltip),
		lines = weakKeys(),
	}
	eachTooltipLine(tooltip, function(fontString)
		session.lines[fontString] = snapshotFont(fontString) or false
	end)
	return session
end

local function restoreTooltip(tooltip, session)
	if not session then
		return
	end
	if session.frame then
		restoreFont(tooltip, session.frame)
	end
	for fontString, snapshot in pairs(session.lines) do
		if snapshot then
			restoreFont(fontString, snapshot)
		end
	end
end

local function rememberLateTooltipLine(tooltip, fontString)
	local session = tooltipSessions[tooltip]
	if session and session.lines[fontString] == nil then
		session.lines[fontString] = snapshotFont(fontString) or false
	end
end

local function nativeTooltipObject(index, side)
	if index == 1 and side == "TextLeft" then
		return nativeObject("GameTooltipHeaderText", "GameFontNormalLarge")
	end
	return nativeObject("GameTooltipText", "GameFontHighlightSmall")
end

local function applyNativeTooltipLine(fontString, index, side)
	local fontObject = nativeTooltipObject(index, side)
	-- Font templates also carry a color. Keep the caller's current semantic
	-- color (including alpha) instead of replacing it with the template default.
	local colorOK, r, g, b, a
	if supports(fontString, "GetTextColor") and supports(fontString, "SetTextColor") then
		colorOK, r, g, b, a = pcall(fontString.GetTextColor, fontString)
	end
	local applied = false
	if fontObject and supports(fontString, "SetFontObject") then
		applied = pcall(fontString.SetFontObject, fontString, fontObject)
	end
	if not applied then
		local snapshot = fontObject and snapshotFont(fontObject) or nil
		if snapshot then
			setFont(fontString, snapshot.path, snapshot.size, snapshot.flags)
		end
	end
	if colorOK then
		pcall(fontString.SetTextColor, fontString, r, g, b, a)
	end
end

local function applyNativeTooltipFrame(tooltip)
	local object = nativeObject("GameTooltipText", "GameFontHighlightSmall")
	local snapshot = object and snapshotFont(object) or nil
	if snapshot then
		setFont(tooltip, snapshot.path, snapshot.size, snapshot.flags)
	end
end

local function closeTooltipSession(tooltip)
	local session = tooltipSessions[tooltip]
	if session then
		restoreTooltip(tooltip, session)
	end
	tooltipSessions[tooltip] = nil
	tooltip._gfFontOwned = nil
	tooltip._gfFontSnapshot = nil
end

function Typography.BeginTooltipFont(tooltip)
	tooltip = tooltip or GameTooltip
	if not tooltip or tooltipSessions[tooltip] then
		return
	end
	local session = captureTooltip(tooltip)
	tooltipSessions[tooltip] = session
	tooltip._gfFontOwned = true
	tooltip._gfFontSnapshot = session

	if not tooltipHooks[tooltip] and supports(tooltip, "HookScript") then
		local ok = pcall(tooltip.HookScript, tooltip, "OnHide", function(hiddenTooltip)
			closeTooltipSession(hiddenTooltip)
		end)
		if ok then
			tooltipHooks[tooltip] = true
		end
	end
end

function Typography.ApplyTooltipFont(tooltip)
	tooltip = tooltip or GameTooltip
	if not tooltip then
		return
	end
	applyNativeTooltipFrame(tooltip)
	eachTooltipLine(tooltip, function(fontString, index, side)
		rememberLateTooltipLine(tooltip, fontString)
		applyNativeTooltipLine(fontString, index, side)
	end)
	if supports(tooltip, "IsShown") and supports(tooltip, "Show") then
		local ok, shown = pcall(tooltip.IsShown, tooltip)
		if ok and shown then
			pcall(tooltip.Show, tooltip)
		end
	end
end

local function returnedObjects(owner, methodName)
	if not supports(owner, methodName) then
		return nil
	end
	local values = { pcall(owner[methodName], owner) }
	if not values[1] then
		return nil
	end
	table.remove(values, 1)
	return values
end

local function walkFontStrings(frame, callback, visited)
	if not frame or type(callback) ~= "function" then
		return
	end
	visited = visited or weakKeys()
	if visited[frame] then
		return
	end
	visited[frame] = true

	local regions = returnedObjects(frame, "GetRegions") or {}
	for _, region in ipairs(regions) do
		if supports(region, "GetObjectType") then
			local ok, objectType = pcall(region.GetObjectType, region)
			if ok and objectType == "FontString" then
				callback(region)
			end
		end
	end
	local children = returnedObjects(frame, "GetChildren") or {}
	for _, child in ipairs(children) do
		walkFontStrings(child, callback, visited)
	end
end

local function attachMenuInitializer(item, template)
	if not (item and type(item.AddInitializer) == "function") then
		return
	end
	item:AddInitializer(function(button)
		if button and button.fontString then
			applyMenuFont(button.fontString, template)
		end
	end)
end

local function wrapMenuBuilder(root, definition, fallbackTemplate)
	local original = root[definition.method]
	if type(original) ~= "function" then
		return
	end
	root[definition.method] = function(self, ...)
		local item = original(self, ...)
		attachMenuInitializer(item, definition.template or fallbackTemplate)
		return item
	end
end

function Typography.WrapMenuRoot(rootDescription, template)
	if not rootDescription or rootDescription._fontWrapperInstalled == true then
		return
	end
	rootDescription._fontWrapperInstalled = true
	template = template or "GameFontHighlightSmall"
	for _, definition in ipairs(MENU_BUILDERS) do
		wrapMenuBuilder(rootDescription, definition, template)
	end
end

function Typography.TrackDropdownButton(button, template)
	if not button then
		return
	end
	template = template or "GameFontHighlightSmall"
	button._gfDropdownTracked = true
	controls[button] = { kind = "dropdown", template = template }
	walkFontStrings(button, function(fontString)
		Typography.Track(fontString, template)
	end)
end

function Typography.RefreshAll()
	menuRevision = menuRevision + 1
	for template, slot in pairs(menuFonts) do
		if slot and slot.object then
			configureMenuFont(slot.object, template)
			slot.revision = menuRevision
		end
	end

	for control, record in pairs(controls) do
		if record.kind == "fontString" then
			if isFontString(control) then
				Typography.ApplyToFontString(control, record.template)
			else
				controls[control] = nil
			end
		elseif record.kind == "editBox" then
			if supports(control, "SetFont") then
				Typography.ApplyToEditBox(control, record.template)
			else
				controls[control] = nil
			end
		elseif record.kind == "dropdown" then
			walkFontStrings(control, function(fontString)
				Typography.Track(fontString, record.template)
			end)
		end
	end

	if GF.UsageGuideDialog and GF.UsageGuideDialog.RefreshLocale then
		GF.UsageGuideDialog:RefreshLocale()
	end
	if GF.UserLetterDialog and GF.UserLetterDialog.RefreshLocale then
		GF.UserLetterDialog:RefreshLocale()
	end
	if GF.TabBar and type(GF.TabBar.RefreshFonts) == "function" then
		GF.TabBar:RefreshFonts()
	end
	if GF.WorkspaceBar and type(GF.WorkspaceBar.RefreshFonts) == "function" then
		GF.WorkspaceBar:RefreshFonts()
	end
end
