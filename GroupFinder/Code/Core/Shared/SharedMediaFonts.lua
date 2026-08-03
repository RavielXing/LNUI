local _, GF = ...

local KEY_PREFIX = "LSM:"
local LOGIN_FALLBACK = "ChatFontNormal"
local NATIVE_FONT_OBJECTS = {
	"GameFontNormal",
	"ChatFontNormal",
	"NumberFontNormalLarge",
	"NumberFontNormal",
}

local function sharedMediaLibrary()
	local resolver = GF.GetOptionalLibrary
	if type(resolver) ~= "function" then
		return nil
	end
	return resolver("LibSharedMedia-3.0")
end

local function fontNameFromKey(value)
	if type(value) ~= "string" or value:sub(1, #KEY_PREFIX) ~= KEY_PREFIX then
		return nil
	end
	local name = value:sub(#KEY_PREFIX + 1)
	return name ~= "" and name or nil
end

local function canonicalPath(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return path:lower():gsub("\\", "/")
end

local function mediaFontPath(library, name)
	if type(library) ~= "table" then
		return nil
	end
	local fetch = library.Fetch
	if type(fetch) ~= "function" or not name then
		return nil
	end
	local ok, value = pcall(fetch, library, "font", name, true)
	if not ok then
		return nil
	end
	return type(value) == "string" and value ~= "" and value or nil
end

local function mediaFontIsValid(library, name)
	if type(library) ~= "table" then
		return nil
	end
	local isValid = library.IsValid
	if type(isValid) ~= "function" or not name then
		return nil
	end
	local ok, valid = pcall(isValid, library, "font", name)
	if not ok or type(valid) ~= "boolean" then
		return nil
	end
	return valid
end

local function nativeFontPaths()
	local paths = {}
	for _, objectName in ipairs(NATIVE_FONT_OBJECTS) do
		local object = _G[objectName]
		if object and type(object.GetFont) == "function" then
			local ok, value = pcall(object.GetFont, object)
			local path = ok and canonicalPath(value) or nil
			if path then
				paths[path] = true
			end
		end
	end
	return paths
end

function GF.GetSharedMedia()
	return sharedMediaLibrary()
end

function GF.IsLSMFontKey(value)
	return fontNameFromKey(value) ~= nil
end

function GF.GetLSMFontNameFromKey(value)
	return fontNameFromKey(value)
end

function GF.LSMFontStorageKey(name)
	return KEY_PREFIX .. tostring(name or "")
end

function GF.AppendLSMFontOptions(options)
	if type(options) ~= "table" then
		return
	end
	local library = sharedMediaLibrary()
	local list = type(library) == "table" and library.List or nil
	if type(list) ~= "function" then
		return
	end
	local ok, names = pcall(list, library, "font")
	if not ok or type(names) ~= "table" then
		return
	end

	local knownValues = {}
	for _, option in ipairs(options) do
		if type(option) == "table" then
			knownValues[option.value] = true
		end
	end
	local nativePaths = nativeFontPaths()

	for _, name in ipairs(names) do
		local storageKey = GF.LSMFontStorageKey(name)
		if not knownValues[storageKey] then
			local path = mediaFontPath(library, name)
			local normalized = canonicalPath(path)
			if path and not (normalized and nativePaths[normalized]) then
				options[#options + 1] = { value = storageKey, label = name }
				knownValues[storageKey] = true
			end
		end
	end
end

function GF.TryApplyLSMFont(fontString, storageKey, size, flags)
	if not fontString or type(fontString.SetFont) ~= "function" then
		return false
	end
	local path = mediaFontPath(sharedMediaLibrary(), fontNameFromKey(storageKey))
	if not path then
		return false
	end
	local ok, applied = pcall(
		fontString.SetFont,
		fontString,
		path,
		tonumber(size) or 12,
		flags or ""
	)
	return ok and applied ~= false
end

function GF.ResolveLSMFontKey(storageKey)
	local name = fontNameFromKey(storageKey)
	if mediaFontIsValid(sharedMediaLibrary(), name) == true then
		return storageKey
	end
	return nil
end

function GF.ValidateLSMFontKeyAfterLogin()
	local db = type(GF.GetDB) == "function" and GF.GetDB() or nil
	local name = db and fontNameFromKey(db.fontKey) or nil
	if not name then
		return
	end
	local valid = mediaFontIsValid(sharedMediaLibrary(), name)
	-- An optional library or media provider can be unavailable temporarily.
	-- Only a conclusive invalid result may replace the saved preference.
	if valid ~= false then
		return
	end
	db.fontKey = LOGIN_FALLBACK
	local manager = GF.Font
	if manager and type(manager.RefreshAll) == "function" then
		manager.RefreshAll()
	end
end
