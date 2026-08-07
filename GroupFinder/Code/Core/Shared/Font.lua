local _, GF = ...

GF.Font = {}

local Font = GF.Font

local DEFAULT_FONT_KEY = "GameFontNormal"
local DEFAULT_FONT_SIZE = 12
local TOOLTIP_LINE_LIMIT = 30
local LEGACY_DROPDOWN_BUTTON_LIMIT = _G.UIDROPDOWNMENU_MAXBUTTONS or 8

local BUILTIN_FONT_CHOICES = {
	"GameFontNormal",
	"ChatFontNormal",
	"NumberFontNormalLarge",
}

local BUILTIN_FONT_ALIASES = {
	NumberFontNormalLarge = "NumberFontNormal",
}

local MENU_ITEM_TEMPLATES = {
	{ "CreateRadio", "GameFontHighlightSmall" },
	{ "CreateCheckbox", "GameFontHighlightSmall" },
	{ "CreateButton", "GameFontHighlightSmall" },
	{ "CreateTitle", "GameFontNormalSmall" },
}

local BUTTON_TEXT_REGIONS = {
	"NormalText",
	"DisabledText",
	"HighlightText",
}

local OUTLINE_CHOICES = {
	{ "NONE", "FONT_OUTLINE_NONE", "No outline" },
	{ "OUTLINE", "FONT_OUTLINE_NORMAL", "Outline" },
	{ "THICKOUTLINE", "FONT_OUTLINE_THICK", "Thick outline" },
}

local function newWeakKeyTable()
	return setmetatable({}, { __mode = "k" })
end

local registry = {
	fontStrings = newWeakKeyTable(),
	editBoxes = newWeakKeyTable(),
	dropdowns = newWeakKeyTable(),
}

local menuSessions = newWeakKeyTable()
local menuOwnersHooked = newWeakKeyTable()
local tooltipSessions = newWeakKeyTable()
local tooltipOwnersHooked = newWeakKeyTable()

local ownedMenuFonts = {}
local menuFontRevision = 1
local baselineTemplateSize

local function hasMethod(owner, methodName)
	return owner and type(owner[methodName]) == "function"
end

local function callSetFont(owner, path, size, flags)
	if not hasMethod(owner, "SetFont") or type(path) ~= "string" or path == "" then
		return false
	end
	size = tonumber(size)
	if not size or size <= 0 then
		return false
	end
	local ok, result = pcall(owner.SetFont, owner, path, size, flags or "")
	return ok and result ~= false
end

local function readFontState(owner)
	if not hasMethod(owner, "GetFont") then
		return nil
	end
	local ok, path, size, flags = pcall(owner.GetFont, owner)
	if not ok then
		return nil
	end
	local fontObject
	if hasMethod(owner, "GetFontObject") then
		local objectOk, object = pcall(owner.GetFontObject, owner)
		if objectOk then
			fontObject = object
		end
	end
	if not fontObject and (type(path) ~= "string" or path == "") then
		return nil
	end
	return {
		fontObject = fontObject,
		path = path,
		size = size,
		flags = flags,
	}
end

local function restoreFontState(owner, state)
	if not owner or not state then
		return false
	end
	if state.fontObject and hasMethod(owner, "SetFontObject") then
		local ok = pcall(owner.SetFontObject, owner, state.fontObject)
		if ok then
			return true
		end
	end
	return callSetFont(owner, state.path, state.size, state.flags)
end

local function nativeFontObject(name, fallbackName)
	local object = type(name) == "string" and _G[name] or nil
	if object and hasMethod(object, "GetFont") then
		return object
	end
	object = type(fallbackName) == "string" and _G[fallbackName] or nil
	if object and hasMethod(object, "GetFont") then
		return object
	end
	return _G.GameFontNormal or _G.ChatFontNormal
end

local function nativeFontPath(name, fallbackName)
	local object = nativeFontObject(name, fallbackName)
	if not object then
		return nil
	end
	local ok, path = pcall(object.GetFont, object)
	return ok and type(path) == "string" and path ~= "" and path or nil
end

local function templateFontSize(template)
	local object = nativeFontObject(template, DEFAULT_FONT_KEY)
	if object then
		local ok, _, size = pcall(object.GetFont, object)
		if ok and tonumber(size) then
			return tonumber(size)
		end
	end
	return DEFAULT_FONT_SIZE
end

local function normalTemplateSize()
	if not baselineTemplateSize then
		baselineTemplateSize = templateFontSize(DEFAULT_FONT_KEY)
	end
	return baselineTemplateSize
end

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function fontScaleMultiplier()
	local minimumPct = tonumber(GF.FONT_SCALE_MIN_PCT) or 100
	local maximumPct = tonumber(GF.FONT_SCALE_MAX_PCT) or 150
	local pct
	if type(GF.GetFontScale) == "function" then
		local ok, multiplier = pcall(GF.GetFontScale)
		if ok and tonumber(multiplier) then
			pct = tonumber(multiplier) * 100
		end
	end
	if not pct and type(GF.GetFontScalePct) == "function" then
		local ok, value = pcall(GF.GetFontScalePct)
		if ok then
			pct = tonumber(value)
		end
	end
	if not pct then
		local db = type(GF.GetDB) == "function" and GF.GetDB() or nil
		pct = tonumber(db and db.fontScalePct) or tonumber(GF.FONT_SCALE_DEFAULT_PCT) or 100
	end
	return clamp(pct, minimumPct, maximumPct) / 100
end

local function requestedFlags(owner)
	if owner and owner._gfFontFlagsOverride ~= nil then
		return owner._gfFontFlagsOverride or ""
	end
	local db = type(GF.GetDB) == "function" and GF.GetDB() or nil
	local flags = db and db.fontOutline or "NONE"
	return (flags == "" or flags == "NONE") and "" or flags
end

local function requestedSize(owner, template, ignoreScale)
	local size
	if owner and owner._gfFontSizeOverride ~= nil then
		size = tonumber(owner._gfFontSizeOverride) or DEFAULT_FONT_SIZE
	else
		size = DEFAULT_FONT_SIZE + templateFontSize(template) - normalTemplateSize()
		if owner and owner._gfFontSizeExtra ~= nil then
			size = size + (tonumber(owner._gfFontSizeExtra) or 0)
		end
	end
	if not ignoreScale and not (owner and owner._gfIgnoreFontScale) then
		size = size * fontScaleMultiplier()
	end
	return math.max(1, size)
end

local function sharedMediaFontPath(storageKey)
	if not (type(GF.IsLSMFontKey) == "function" and GF.IsLSMFontKey(storageKey)) then
		return nil
	end
	local library = type(GF.GetSharedMedia) == "function" and GF.GetSharedMedia() or nil
	local name = type(GF.GetLSMFontNameFromKey) == "function"
		and GF.GetLSMFontNameFromKey(storageKey)
		or nil
	if not (library and name and type(library.Fetch) == "function") then
		return nil
	end
	local ok, path = pcall(library.Fetch, library, "font", name, true)
	return ok and type(path) == "string" and path ~= "" and path or nil
end

local function fontPathForKey(key)
	local mediaPath = sharedMediaFontPath(key)
	if mediaPath then
		return mediaPath
	end
	local object = type(key) == "string" and _G[key] or nil
	if object and hasMethod(object, "GetFont") then
		local ok, path = pcall(object.GetFont, object)
		if ok then
			local usablePath = type(path) == "string" and #path > 0
			if usablePath then
				return path
			end
		end
	end
	return nil
end

local function selectedFontPath()
	return fontPathForKey(Font.GetFontObjectKey())
end

local function applySelectedFont(owner, template, options)
	if not hasMethod(owner, "SetFont") then
		return false
	end
	template = template or DEFAULT_FONT_KEY
	options = options or {}
	local size = requestedSize(owner, template, options.ignoreScale == true)
	local flags = options.flags
	if flags == nil then
		flags = requestedFlags(owner)
	end
	if callSetFont(owner, selectedFontPath(), size, flags) then
		return true
	end
	local fallbackPath = nativeFontPath(template, options.fallbackTemplate or DEFAULT_FONT_KEY)
	if callSetFont(owner, fallbackPath, size, flags) then
		return true
	end
	local fallbackObject = nativeFontObject(template, options.fallbackTemplate or DEFAULT_FONT_KEY)
	if fallbackObject and hasMethod(owner, "SetFontObject") then
		return pcall(owner.SetFontObject, owner, fallbackObject)
	end
	return false
end

local function isUsableFontString(fontString)
	if not hasMethod(fontString, "SetFont") then
		return false
	end
	if not hasMethod(fontString, "GetObjectType") then
		return true
	end
	local ok, objectType = pcall(fontString.GetObjectType, fontString)
	return not ok or objectType == "FontString"
end

local function measureUnboundedWidth(fontString)
	local method = fontString and (fontString.GetUnboundedStringWidth or fontString.GetStringWidth)
	if type(method) ~= "function" then
		return nil
	end
	local ok, rawWidth = pcall(method, fontString)
	if not ok then
		return nil
	end
	local numberOk, width = pcall(tonumber, rawWidth)
	return numberOk and width or nil
end

local function fitCurrentFontToWidth(fontString)
	local maximumWidth = tonumber(fontString and fontString._gfFitWidth)
	if not maximumWidth or maximumWidth <= 0 then
		if fontString then
			fontString._gfFittedFontSize = nil
		end
		return
	end
	local width = measureUnboundedWidth(fontString)
	if not width or width <= maximumWidth then
		fontString._gfFittedFontSize = nil
		return
	end
	local ok, path, size, flags = pcall(fontString.GetFont, fontString)
	size = ok and tonumber(size) or nil
	if type(path) ~= "string" or path == "" or not size or size <= 0 then
		return
	end
	local minimum = math.max(1, tonumber(fontString._gfFitMinSize) or 6)
	local fitted = math.max(minimum, math.floor(size * maximumWidth / width * 100) / 100)
	if fitted >= size then
		fontString._gfFittedFontSize = nil
		return
	end
	if callSetFont(fontString, path, fitted, flags) then
		fontString._gfFittedFontSize = fitted
	end
end

function Font.GetFontOptions()
	local L = GF.L or {}
	local options = {}
	for _, requestedName in ipairs(BUILTIN_FONT_CHOICES) do
		local actualName = requestedName
		if not fontPathForKey(actualName) and BUILTIN_FONT_ALIASES[actualName] then
			actualName = BUILTIN_FONT_ALIASES[actualName]
		end
		if fontPathForKey(actualName) then
			options[#options + 1] = {
				value = actualName,
				label = L["FONTOBJECT_" .. requestedName]
					or L["FONTOBJECT_" .. actualName]
					or actualName,
			}
		end
	end
	if #options == 0 then
		options[1] = {
			value = DEFAULT_FONT_KEY,
			label = L.FONTOBJECT_GameFontNormal or DEFAULT_FONT_KEY,
		}
	end
	if type(GF.AppendLSMFontOptions) == "function" then
		GF.AppendLSMFontOptions(options)
	end
	return options
end

function Font.GetOutlineOptions()
	local L = GF.L or {}
	local options = {}
	for index, choice in ipairs(OUTLINE_CHOICES) do
		options[index] = {
			value = choice[1],
			label = L[choice[2]] or choice[3],
		}
	end
	return options
end

function Font.ResolveFontObjectKey(key)
	if type(key) ~= "string" then
		return DEFAULT_FONT_KEY
	end
	if type(GF.IsLSMFontKey) == "function" and GF.IsLSMFontKey(key) then
		return key
	end
	if fontPathForKey(key) then
		return key
	end
	local alias = BUILTIN_FONT_ALIASES[key]
	if alias and fontPathForKey(alias) then
		return alias
	end
	for _, option in ipairs(Font.GetFontOptions()) do
		if option.value == key then
			return key
		end
	end
	return DEFAULT_FONT_KEY
end

function Font.GetFontObjectKey()
	local db = type(GF.GetDB) == "function" and GF.GetDB() or nil
	return Font.ResolveFontObjectKey(db and db.fontKey or DEFAULT_FONT_KEY)
end

local function menuFontGlobalName(template)
	return "GroupFinderMenuFont_" .. tostring(template or "Default"):gsub("[^%w_]", "_")
end

local function configureOwnedMenuFont(fontObject, template)
	local baseObject = nativeFontObject(template, "GameFontHighlightSmall")
	if baseObject and hasMethod(fontObject, "CopyFontObject") then
		pcall(fontObject.CopyFontObject, fontObject, baseObject)
	end
	local size = requestedSize(nil, template, false)
	local path = selectedFontPath() or nativeFontPath(template, "GameFontHighlightSmall")
	return callSetFont(fontObject, path, size, "")
end

local function menuFontObject(template)
	template = template or "GameFontHighlightSmall"
	local slot = ownedMenuFonts[template]
	if not slot then
		local globalName = menuFontGlobalName(template)
		local object = _G[globalName]
		if not object and type(CreateFont) == "function" then
			local ok, created = pcall(CreateFont, globalName)
			if ok then
				object = created
			end
		end
		if not object then
			return nativeFontObject(template, "GameFontHighlightSmall")
		end
		slot = { object = object, revision = 0 }
		ownedMenuFonts[template] = slot
	end
	if slot.revision ~= menuFontRevision then
		configureOwnedMenuFont(slot.object, template)
		slot.revision = menuFontRevision
	end
	return slot.object
end

local function applyMenuFontString(fontString, template)
	if not fontString or not hasMethod(fontString, "SetFontObject") then
		return
	end
	local object = menuFontObject(template or "GameFontHighlightSmall")
	if object then
		pcall(fontString.SetFontObject, fontString, object)
	end
end

function Font.ApplyToMenuFontString(fontString, template)
	applyMenuFontString(fontString, template)
end

function Font.ApplyToDropdownButton(button, template)
	if not button then
		return
	end
	template = template or "GameFontHighlightSmall"
	local normalObject = menuFontObject(template)
	local disabledObject = menuFontObject("GameFontDisableSmall")
	if normalObject and hasMethod(button, "SetNormalFontObject") then
		pcall(button.SetNormalFontObject, button, normalObject)
	end
	if normalObject and hasMethod(button, "SetHighlightFontObject") then
		pcall(button.SetHighlightFontObject, button, normalObject)
	end
	if disabledObject and hasMethod(button, "SetDisabledFontObject") then
		pcall(button.SetDisabledFontObject, button, disabledObject)
	end
	for _, regionName in ipairs(BUTTON_TEXT_REGIONS) do
		local region = button[regionName]
		if region then
			applyMenuFontString(
				region,
				regionName == "DisabledText" and "GameFontDisableSmall" or template
			)
		end
	end
end

local function snapshotButtonObjects(button)
	local snapshot = {}
	for _, row in ipairs({
		{ getter = "GetNormalFontObject", setter = "SetNormalFontObject" },
		{ getter = "GetHighlightFontObject", setter = "SetHighlightFontObject" },
		{ getter = "GetDisabledFontObject", setter = "SetDisabledFontObject" },
	}) do
		if hasMethod(button, row.getter) and hasMethod(button, row.setter) then
			local ok, object = pcall(button[row.getter], button)
			if ok then
				snapshot[#snapshot + 1] = { setter = row.setter, object = object }
			end
		end
	end
	return snapshot
end

local function beginMenuSession(owner)
	if not owner then
		return nil
	end
	local session = menuSessions[owner]
	if session then
		return session
	end
	session = {
		regions = newWeakKeyTable(),
		buttons = newWeakKeyTable(),
	}
	menuSessions[owner] = session
	if not menuOwnersHooked[owner] and hasMethod(owner, "HookScript") then
		menuOwnersHooked[owner] = true
		owner:HookScript("OnHide", function(hiddenOwner)
			local active = menuSessions[hiddenOwner]
			if not active then
				return
			end
			for button, states in pairs(active.buttons) do
				for _, state in ipairs(states) do
					if state.object and hasMethod(button, state.setter) then
						pcall(button[state.setter], button, state.object)
					end
				end
			end
			for region, state in pairs(active.regions) do
				restoreFontState(region, state)
			end
			menuSessions[hiddenOwner] = nil
		end)
	end
	return session
end

local function rememberMenuRegion(session, region)
	if session and region and session.regions[region] == nil then
		session.regions[region] = readFontState(region) or false
	end
end

local function rememberMenuButton(session, button)
	if not session or not button or session.buttons[button] then
		return
	end
	session.buttons[button] = snapshotButtonObjects(button)
	for _, regionName in ipairs(BUTTON_TEXT_REGIONS) do
		rememberMenuRegion(session, button[regionName])
	end
end

local function contextMenuSize()
	return requestedSize(nil, DEFAULT_FONT_KEY, true) + (tonumber(GF.CONTEXT_MENU_TEXT_SIZE_EXTRA) or 4)
end

local function applyContextMenuFontString(fontString, template)
	if not hasMethod(fontString, "SetFont") then
		return
	end
	template = template or "GameFontHighlight"
	local size = contextMenuSize()
	local flags = requestedFlags(fontString)
	if callSetFont(fontString, selectedFontPath(), size, flags) then
		return
	end
	callSetFont(fontString, nativeFontPath(template, "GameFontHighlight"), size, flags)
end

function Font.BeginContextDropdownFonts(list)
	beginMenuSession(list)
end

function Font.ApplyToContextMenuDropdownButton(button, template)
	if not button then
		return
	end
	local owner = hasMethod(button, "GetParent") and button:GetParent() or nil
	local session = owner and menuSessions[owner] or nil
	rememberMenuButton(session, button)
	for _, regionName in ipairs(BUTTON_TEXT_REGIONS) do
		local region = button[regionName]
		if region then
			applyContextMenuFontString(region, template or "GameFontHighlight")
		end
	end
end

function Font.ApplyToEditBox(editBox, template)
	if not hasMethod(editBox, "SetFont") then
		return
	end
	applySelectedFont(editBox, template or "GameFontNormal", {
		fallbackTemplate = "GameFontNormal",
	})
end

function Font.TrackEditBox(editBox, template)
	if not editBox then
		return
	end
	template = template or "GameFontNormal"
	editBox._gfFontTemplate = template
	editBox._gfEditTracked = true
	registry.editBoxes[editBox] = template
	Font.ApplyToEditBox(editBox, template)
end

function Font.ApplyToFontString(fontString, template)
	if not isUsableFontString(fontString) then
		return
	end
	template = template or fontString._gfFontTemplate or DEFAULT_FONT_KEY
	if applySelectedFont(fontString, template, { fallbackTemplate = DEFAULT_FONT_KEY }) then
		fitCurrentFontToWidth(fontString)
	end
end

function Font.SetFitWidth(fontString, maximumWidth, minimumSize)
	if not fontString then
		return
	end
	fontString._gfFitWidth = tonumber(maximumWidth)
	fontString._gfFitMinSize = tonumber(minimumSize)
	local template = registry.fontStrings[fontString]
		or fontString._gfFontTemplate
		or DEFAULT_FONT_KEY
	registry.fontStrings[fontString] = template
	fontString._gfFontTracked = true
	Font.ApplyToFontString(fontString, template)
end

function Font.Track(fontString, template)
	if not fontString then
		return
	end
	template = template or "GameFontNormal"
	fontString._gfFontTemplate = template
	fontString._gfFontTracked = true
	registry.fontStrings[fontString] = template
	Font.ApplyToFontString(fontString, template)
end

function Font.TrackButton(button, template)
	if not (button and hasMethod(button, "GetFontString")) then
		return
	end
	local fontString = button:GetFontString()
	if fontString then
		Font.Track(fontString, template or "GameFontNormal")
	end
end

local function tooltipLineFontString(tooltip, index, side)
	local fieldName = side .. index
	local fontString = tooltip and tooltip[fieldName]
	if fontString then
		return fontString
	end
	if tooltip and hasMethod(tooltip, "GetName") then
		local ok, name = pcall(tooltip.GetName, tooltip)
		if ok and type(name) == "string" and name ~= "" then
			return _G[name .. fieldName]
		end
	end
	return nil
end

local function forEachTooltipFontString(tooltip, callback)
	if not (tooltip and callback) then
		return
	end
	for index = 1, TOOLTIP_LINE_LIMIT do
		for _, side in ipairs({ "TextLeft", "TextRight" }) do
			local fontString = tooltipLineFontString(tooltip, index, side)
			if fontString then
				callback(fontString, index, side)
			end
		end
	end
end

local function captureTooltipState(tooltip)
	local session = {
		frame = readFontState(tooltip),
		lines = newWeakKeyTable(),
	}
	forEachTooltipFontString(tooltip, function(fontString)
		session.lines[fontString] = readFontState(fontString) or false
	end)
	return session
end

local function restoreTooltipState(tooltip, session)
	if not session then
		return
	end
	if session.frame then
		restoreFontState(tooltip, session.frame)
	end
	for fontString, state in pairs(session.lines) do
		if state then
			restoreFontState(fontString, state)
		end
	end
end

local function ensureTooltipLineSnapshot(tooltip, fontString)
	local session = tooltipSessions[tooltip]
	if session and session.lines[fontString] == nil then
		session.lines[fontString] = readFontState(fontString) or false
	end
end

local function defaultTooltipFontObject(index, side)
	if index == 1 and side == "TextLeft" then
		return nativeFontObject("GameTooltipHeaderText", "GameFontNormalLarge")
	end
	return nativeFontObject("GameTooltipText", "GameFontHighlightSmall")
end

local function applyNativeTooltipLine(fontString, index, side)
	local object = defaultTooltipFontObject(index, side)
	if object and hasMethod(fontString, "SetFontObject") then
		local ok = pcall(fontString.SetFontObject, fontString, object)
		if ok then
			return
		end
	end
	if object then
		local state = readFontState(object)
		if state then
			callSetFont(fontString, state.path, state.size, state.flags)
		end
	end
end

local function applyNativeTooltipFrame(tooltip)
	local object = nativeFontObject("GameTooltipText", "GameFontHighlightSmall")
	local state = object and readFontState(object) or nil
	if state then
		callSetFont(tooltip, state.path, state.size, state.flags)
	end
end

function Font.BeginTooltipFont(tooltip)
	tooltip = tooltip or GameTooltip
	if not tooltip or tooltipSessions[tooltip] then
		return
	end
	tooltipSessions[tooltip] = captureTooltipState(tooltip)
	tooltip._gfFontOwned = true
	tooltip._gfFontSnapshot = tooltipSessions[tooltip]
	if not tooltipOwnersHooked[tooltip] and hasMethod(tooltip, "HookScript") then
		tooltipOwnersHooked[tooltip] = true
		tooltip:HookScript("OnHide", function(hiddenTooltip)
			local session = tooltipSessions[hiddenTooltip]
			if session then
				restoreTooltipState(hiddenTooltip, session)
			end
			tooltipSessions[hiddenTooltip] = nil
			hiddenTooltip._gfFontOwned = nil
			hiddenTooltip._gfFontSnapshot = nil
		end)
	end
end

function Font.ApplyTooltipFont(tooltip)
	tooltip = tooltip or GameTooltip
	if not tooltip then
		return
	end
	applyNativeTooltipFrame(tooltip)
	forEachTooltipFontString(tooltip, function(fontString, index, side)
		ensureTooltipLineSnapshot(tooltip, fontString)
		applyNativeTooltipLine(fontString, index, side)
	end)
	if hasMethod(tooltip, "IsShown") and tooltip:IsShown() and hasMethod(tooltip, "Show") then
		tooltip:Show()
	end
end

function Font.ApplyDropdownMenuFont()
	local list = _G.DropDownList1
	local session = beginMenuSession(list)
	for index = 1, LEGACY_DROPDOWN_BUTTON_LIMIT do
		local button = _G["DropDownList1Button" .. index]
		if button and (not hasMethod(button, "IsShown") or button:IsShown()) then
			rememberMenuButton(session, button)
			Font.ApplyToDropdownButton(button, "GameFontHighlightSmall")
		end
	end
	local title = _G.DropDownList1Title
	if title then
		rememberMenuRegion(session, title)
		Font.ApplyToMenuFontString(title, "GameFontNormalSmall")
	end
end

local function walkFrameFontStrings(frame, callback, visited)
	if not (frame and callback) then
		return
	end
	visited = visited or newWeakKeyTable()
	if visited[frame] then
		return
	end
	visited[frame] = true
	if hasMethod(frame, "GetRegions") then
		for _, region in ipairs({ frame:GetRegions() }) do
			if region and hasMethod(region, "GetObjectType") then
				local ok, objectType = pcall(region.GetObjectType, region)
				if ok and objectType == "FontString" then
					callback(region)
				end
			end
		end
	end
	if hasMethod(frame, "GetChildren") then
		for _, child in ipairs({ frame:GetChildren() }) do
			walkFrameFontStrings(child, callback, visited)
		end
	end
end

local function addMenuFontInitializer(item, template)
	if not (item and type(item.AddInitializer) == "function") then
		return
	end
	local function initializeTypography(initializedButton)
		local fontString = initializedButton and initializedButton.fontString
		if fontString then
			applyMenuFontString(fontString, template)
		end
	end
	item:AddInitializer(initializeTypography)
end

local function installMenuMethodWrapper(rootDescription, definition, fallbackTemplate)
	local methodName, preferredTemplate = definition[1], definition[2]
	local original = rootDescription[methodName]
	if type(original) ~= "function" then
		return
	end
	rootDescription[methodName] = function(self, ...)
		local item = original(self, ...)
		addMenuFontInitializer(item, preferredTemplate or fallbackTemplate)
		return item
	end
end

function Font.WrapMenuRoot(rootDescription, template)
	if not rootDescription then
		return
	end
	if rootDescription._fontWrapperInstalled == true then
		return
	end
	rootDescription._fontWrapperInstalled = true
	template = template or "GameFontHighlightSmall"
	for _, definition in ipairs(MENU_ITEM_TEMPLATES) do
		installMenuMethodWrapper(rootDescription, definition, template)
	end
end

function Font.TrackDropdownButton(button, template)
	if not button then
		return
	end
	template = template or "GameFontHighlightSmall"
	button._gfDropdownTracked = true
	registry.dropdowns[button] = template
	walkFrameFontStrings(button, function(fontString)
		Font.Track(fontString, template)
	end)
end

function Font.RefreshAll()
	menuFontRevision = menuFontRevision + 1
	for template, slot in pairs(ownedMenuFonts) do
		if slot and slot.object then
			configureOwnedMenuFont(slot.object, template)
			slot.revision = menuFontRevision
		end
	end

	for fontString, template in pairs(registry.fontStrings) do
		if isUsableFontString(fontString) then
			Font.ApplyToFontString(fontString, template)
		else
			registry.fontStrings[fontString] = nil
		end
	end

	for editBox, template in pairs(registry.editBoxes) do
		if hasMethod(editBox, "SetFont") then
			Font.ApplyToEditBox(editBox, template)
		else
			registry.editBoxes[editBox] = nil
		end
	end

	for dropdown, template in pairs(registry.dropdowns) do
		if dropdown then
			walkFrameFontStrings(dropdown, function(fontString)
				Font.Track(fontString, template)
			end)
		else
			registry.dropdowns[dropdown] = nil
		end
	end

	if GF.TabBar and type(GF.TabBar.RefreshFonts) == "function" then
		GF.TabBar:RefreshFonts()
	end
end
