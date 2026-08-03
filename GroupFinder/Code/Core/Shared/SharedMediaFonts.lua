local _, GF = ...

local FONT_MEDIA = {
	libraryName = "LibSharedMedia-3.0",
	mediaType = "font",
	storagePrefix = "LSM:",
	loginFallback = "ChatFontNormal",
	nativeObjects = {
		"ChatFontNormal",
		"NumberFontNormal",
		"GameFontNormal",
		"NumberFontNormalLarge",
	},
}

local PROVIDER_OPERATIONS = {
	list = {
		method = "List",
		invoke = function(callback, provider, mediaType)
			return callback(provider, mediaType)
		end,
		accept = function(value)
			return type(value) == "table"
		end,
	},
	fetch = {
		method = "Fetch",
		invoke = function(callback, provider, mediaType, name)
			return callback(provider, mediaType, name, true)
		end,
		accept = function(value)
			return type(value) == "string" and value ~= ""
		end,
	},
	validate = {
		method = "IsValid",
		invoke = function(callback, provider, mediaType, name)
			return callback(provider, mediaType, name)
		end,
		accept = function(value)
			return type(value) == "boolean"
		end,
	},
}

local function resolveProvider()
	local resolver = GF.GetOptionalLibrary
	if type(resolver) ~= "function" then
		return nil
	end
	local ok, provider = pcall(resolver, FONT_MEDIA.libraryName)
	return ok and provider or nil
end

local function readProvider(operationName, fontName, provider)
	local operation = PROVIDER_OPERATIONS[operationName]
	if operation == nil then
		return nil
	end
	provider = provider or resolveProvider()
	if type(provider) ~= "table" then
		return nil
	end
	local callback = provider[operation.method]
	if type(callback) ~= "function" then
		return nil
	end
	local ok, value = pcall(
		operation.invoke,
		callback,
		provider,
		FONT_MEDIA.mediaType,
		fontName
	)
	if not ok or not operation.accept(value) then
		return nil
	end
	return value
end

local function unpackStorageKey(value)
	if type(value) ~= "string" then
		return nil
	end
	local prefixLength = #FONT_MEDIA.storagePrefix
	if value:sub(1, prefixLength) ~= FONT_MEDIA.storagePrefix then
		return nil
	end
	local name = value:sub(prefixLength + 1)
	return name ~= "" and name or nil
end

local function makeStorageKey(name)
	return FONT_MEDIA.storagePrefix .. tostring(name or "")
end

local function comparablePath(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return path:lower():gsub("\\", "/")
end

local function nativeFontPathIndex()
	local paths = {}
	for index = 1, #FONT_MEDIA.nativeObjects do
		local fontObject = _G[FONT_MEDIA.nativeObjects[index]]
		local readFont = fontObject and fontObject.GetFont
		if type(readFont) == "function" then
			local ok, path = pcall(readFont, fontObject)
			local normalized = ok and comparablePath(path) or nil
			if normalized ~= nil then
				paths[normalized] = true
			end
		end
	end
	return paths
end

local function existingOptionValues(options)
	local values = {}
	for index = 1, #options do
		local option = options[index]
		if type(option) == "table" and option.value ~= nil then
			values[option.value] = true
		end
	end
	return values
end

local API = {
	storageKey = makeStorageKey,
	getProvider = resolveProvider,
	storageName = unpackStorageKey,
	isStorageKey = function(value)
		return unpackStorageKey(value) ~= nil
	end,
}

function API.appendOptions(options)
	if type(options) ~= "table" then
		return
	end
	local provider = resolveProvider()
	if type(provider) ~= "table" then
		return
	end
	local names = readProvider("list", nil, provider)
	if names == nil then
		return
	end

	local known = existingOptionValues(options)
	local nativePaths = nativeFontPathIndex()
	for index = 1, #names do
		local name = names[index]
		local key = makeStorageKey(name)
		if not known[key] then
			local path = readProvider("fetch", name, provider)
			local normalized = comparablePath(path)
			if path ~= nil and not (normalized and nativePaths[normalized]) then
				options[#options + 1] = { value = key, label = name }
				known[key] = true
			end
		end
	end
end

function API.apply(fontString, storageKey, size, flags)
	local name = unpackStorageKey(storageKey)
	local setFont = fontString and fontString.SetFont
	if type(setFont) ~= "function" or name == nil then
		return false
	end
	local path = readProvider("fetch", name)
	if path == nil then
		return false
	end
	local ok, applied = pcall(setFont, fontString, path, tonumber(size) or 12, flags or "")
	return ok and applied ~= false
end

function API.resolve(storageKey)
	local name = unpackStorageKey(storageKey)
	if name ~= nil and readProvider("validate", name) == true then
		return storageKey
	end
	return nil
end

function API.validateSavedPreference()
	local getDB = GF.GetDB
	local db = type(getDB) == "function" and getDB() or nil
	local name = type(db) == "table" and unpackStorageKey(db.fontKey) or nil
	if name == nil then
		return
	end

	local validity = readProvider("validate", name)
	if validity ~= false then
		return
	end
	db.fontKey = FONT_MEDIA.loginFallback
	local manager = GF.Font
	local refresh = manager and manager.RefreshAll
	if type(refresh) == "function" then
		refresh()
	end
end

local PUBLIC_ENTRIES = {
	LSMFontStorageKey = API.storageKey,
	GetSharedMedia = API.getProvider,
	AppendLSMFontOptions = API.appendOptions,
	GetLSMFontNameFromKey = API.storageName,
	ResolveLSMFontKey = API.resolve,
	IsLSMFontKey = API.isStorageKey,
	ValidateLSMFontKeyAfterLogin = API.validateSavedPreference,
	TryApplyLSMFont = API.apply,
}

for name, callback in pairs(PUBLIC_ENTRIES) do
	GF[name] = callback
end
