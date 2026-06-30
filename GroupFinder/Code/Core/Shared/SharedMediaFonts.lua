local _, GF = ...

local FONT_KEY_PREFIX = "LSM:"
local FALLBACK_FONT_KEY = "ChatFontNormal"

local BUILTIN_FONT_OBJECTS = {
	"GameFontNormal",
	"ChatFontNormal",
	"NumberFontNormalLarge",
	"NumberFontNormal",
}

local function normalizedPath(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return path:gsub("\\", "/"):lower()
end

local function collectBuiltinFontPaths()
	local set = {}
	for i = 1, #BUILTIN_FONT_OBJECTS do
		local fontObject = _G[BUILTIN_FONT_OBJECTS[i]]
		if fontObject and fontObject.GetFont then
			local path = normalizedPath(fontObject:GetFont())
			if path then
				set[path] = true
			end
		end
	end
	return set
end

local function getSharedMedia()
	if type(LibStub) ~= "function" then
		return nil
	end
	return LibStub("LibSharedMedia-3.0", true)
end

local function fontNameFromStorageKey(key)
	if type(key) ~= "string" then
		return nil
	end
	if key:sub(1, #FONT_KEY_PREFIX) ~= FONT_KEY_PREFIX then
		return nil
	end
	if #key <= #FONT_KEY_PREFIX then
		return nil
	end
	return key:sub(#FONT_KEY_PREFIX + 1)
end

local function markExistingOptionValues(options)
	local seen = {}
	for i = 1, #options do
		seen[options[i].value] = true
	end
	return seen
end

local function fetchFontPath(sharedMedia, name)
	if not sharedMedia or not name then
		return nil
	end
	local path = sharedMedia:Fetch("font", name, true)
	if type(path) == "string" and path ~= "" then
		return path
	end
	return nil
end

function GF.GetSharedMedia()
	return getSharedMedia()
end

function GF.IsLSMFontKey(key)
	return fontNameFromStorageKey(key) ~= nil
end

function GF.GetLSMFontNameFromKey(key)
	return fontNameFromStorageKey(key)
end

function GF.LSMFontStorageKey(name)
	return FONT_KEY_PREFIX .. name
end

function GF.AppendLSMFontOptions(out)
	if type(out) ~= "table" then
		return
	end
	local sharedMedia = getSharedMedia()
	local fonts = sharedMedia and sharedMedia:List("font")
	if not fonts then
		return
	end

	local seen = markExistingOptionValues(out)
	local builtinPath = collectBuiltinFontPaths()
	for i = 1, #fonts do
		local name = fonts[i]
		local key = GF.LSMFontStorageKey(name)
		if not seen[key] then
			local path = fetchFontPath(sharedMedia, name)
			local normalized = normalizedPath(path)
			if path and (not normalized or not builtinPath[normalized]) then
				out[#out + 1] = { value = key, label = name }
				seen[key] = true
			end
		end
	end
end

local function resolveFontPath(key)
	local name = fontNameFromStorageKey(key)
	local sharedMedia = getSharedMedia()
	return fetchFontPath(sharedMedia, name)
end

function GF.TryApplyLSMFont(fs, fontKey, sz, flags)
	if not fs then
		return false
	end
	local path = resolveFontPath(fontKey)
	if not path then
		return false
	end
	fs:SetFont(path, sz or 12, flags or "")
	return true
end

function GF.ResolveLSMFontKey(key)
	local name = fontNameFromStorageKey(key)
	local sharedMedia = getSharedMedia()
	if sharedMedia and name and sharedMedia:IsValid("font", name) then
		return key
	end
	return nil
end

function GF.ValidateLSMFontKeyAfterLogin()
	local db = GF.GetDB and GF.GetDB()
	if not db or not GF.IsLSMFontKey(db.fontKey) then
		return
	end
	if GF.ResolveLSMFontKey(db.fontKey) then
		return
	end
	db.fontKey = FALLBACK_FONT_KEY
	if GF.Font and GF.Font.RefreshAll then
		GF.Font.RefreshAll()
	end
end
