local _, GF = ...

local Adapter = {}
GF.SharedMediaFontAdapter = Adapter

local LIBRARY_NAME = "LibSharedMedia-3.0"
local MEDIA_KIND = "font"
local STORAGE_PREFIX = "LSM:"
local INVALID_PREFERENCE_FALLBACK = "ChatFontNormal"

local NATIVE_FONT_OBJECTS = {
	"ChatFontNormal",
	"NumberFontNormal",
	"GameFontNormal",
	"NumberFontNormalLarge",
}

local function provider()
	local resolveLibrary = GF.GetOptionalLibrary
	if type(resolveLibrary) ~= "function" then
		return nil
	end
	local ok, library = pcall(resolveLibrary, LIBRARY_NAME)
	return ok and library or nil
end

local function invoke(library, methodName, ...)
	if type(library) ~= "table" then
		return false, nil
	end
	local callback = library and library[methodName]
	if type(callback) ~= "function" then
		return false, nil
	end
	local ok, value = pcall(callback, library, MEDIA_KIND, ...)
	if not ok then
		return false, nil
	end
	return true, value
end

local function fontNameFromStorageKey(value)
	if type(value) ~= "string" or value:sub(1, #STORAGE_PREFIX) ~= STORAGE_PREFIX then
		return nil
	end
	local name = value:sub(#STORAGE_PREFIX + 1)
	if name == "" then
		return nil
	end
	return name
end

local function normalizePath(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return path:lower():gsub("\\", "/")
end

local function fetchPath(library, name)
	local ok, path = invoke(library, "Fetch", name, true)
	if ok and type(path) == "string" and path ~= "" then
		return path
	end
	return nil
end

local function nativePathSet()
	local result = {}
	for _, globalName in ipairs(NATIVE_FONT_OBJECTS) do
		local fontObject = _G[globalName]
		local getFont = fontObject and fontObject.GetFont
		if type(getFont) == "function" then
			local ok, path = pcall(getFont, fontObject)
			local normalized = ok and normalizePath(path) or nil
			if normalized then
				result[normalized] = true
			end
		end
	end
	return result
end

local function optionValueSet(options)
	local result = {}
	for _, option in ipairs(options) do
		if type(option) == "table" and option.value ~= nil then
			result[option.value] = true
		end
	end
	return result
end

function Adapter.GetProvider()
	return provider()
end

function Adapter.StorageKey(name)
	return STORAGE_PREFIX .. tostring(name or "")
end

function Adapter.StorageName(value)
	return fontNameFromStorageKey(value)
end

function Adapter.IsStorageKey(value)
	return fontNameFromStorageKey(value) ~= nil
end

function Adapter.FetchPath(storageKey)
	local name = fontNameFromStorageKey(storageKey)
	if not name then
		return nil
	end
	return fetchPath(provider(), name)
end

function Adapter.AppendOptions(options)
	if type(options) ~= "table" then
		return
	end
	local library = provider()
	if not library then
		return
	end
	local ok, names = invoke(library, "List")
	if not ok or type(names) ~= "table" then
		return
	end

	local existing = optionValueSet(options)
	local nativePaths = nativePathSet()
	for _, name in ipairs(names) do
		local storageKey = Adapter.StorageKey(name)
		if not existing[storageKey] then
			local path = fetchPath(library, name)
			local normalized = normalizePath(path)
			if path and not (normalized and nativePaths[normalized]) then
				options[#options + 1] = { value = storageKey, label = name }
				existing[storageKey] = true
			end
		end
	end
end

function Adapter.Apply(fontString, storageKey, size, flags)
	if not (fontString and type(fontString.SetFont) == "function") then
		return false
	end
	local path = Adapter.FetchPath(storageKey)
	if not path then
		return false
	end
	local ok, result = pcall(
		fontString.SetFont,
		fontString,
		path,
		tonumber(size) or 12,
		flags or ""
	)
	return ok and result ~= false
end

function Adapter.Resolve(storageKey)
	local name = fontNameFromStorageKey(storageKey)
	local library = name and provider() or nil
	if not library then
		return nil
	end
	local ok, valid = invoke(library, "IsValid", name)
	if ok and valid == true then
		return storageKey
	end
	return nil
end

function Adapter.ValidateSavedPreference()
	local getDB = GF.GetDB
	local database = type(getDB) == "function" and getDB() or nil
	local name = type(database) == "table" and fontNameFromStorageKey(database.fontKey) or nil
	if not name then
		return
	end

	local library = provider()
	if not library then
		return
	end
	local ok, valid = invoke(library, "IsValid", name)
	if not ok or valid ~= false then
		return
	end

	database.fontKey = INVALID_PREFERENCE_FALLBACK
	local typography = GF.TypographyService or GF.Font
	local refresh = typography and typography.RefreshAll
	if type(refresh) == "function" then
		refresh()
	end
end

-- Compatibility surface retained for saved settings and existing GF modules.
local COMPATIBILITY = {
	LSMFontStorageKey = "StorageKey",
	GetSharedMedia = "GetProvider",
	AppendLSMFontOptions = "AppendOptions",
	GetLSMFontNameFromKey = "StorageName",
	ResolveLSMFontKey = "Resolve",
	IsLSMFontKey = "IsStorageKey",
	ValidateLSMFontKeyAfterLogin = "ValidateSavedPreference",
	TryApplyLSMFont = "Apply",
}

local function compatibilityFacade(adapterMethod)
	return function(...)
		return Adapter[adapterMethod](...)
	end
end

for publicName, adapterMethod in pairs(COMPATIBILITY) do
	GF[publicName] = compatibilityFacade(adapterMethod)
end
