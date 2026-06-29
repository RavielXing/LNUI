local _, GF = ...

local LSM_PREFIX = "LSM:"

local BUILTIN_FONT_OBJECTS = {
	"GameFontNormal",
	"ChatFontNormal",
	"NumberFontNormalLarge",
	"NumberFontNormal",
}

local function normalizeFontPath(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return path:lower():gsub("/", "\\")
end

local function getBuiltinFontPathSet()
	local set = {}
	for i = 1, #BUILTIN_FONT_OBJECTS do
		local fo = _G[BUILTIN_FONT_OBJECTS[i]]
		if fo and fo.GetFont then
			local p = normalizeFontPath(fo:GetFont())
			if p then
				set[p] = true
			end
		end
	end
	return set
end

function GF.GetSharedMedia()
	if not LibStub then
		return nil
	end
	return LibStub("LibSharedMedia-3.0", true)
end

function GF.IsLSMFontKey(key)
	return type(key) == "string" and key:sub(1, #LSM_PREFIX) == LSM_PREFIX and #key > #LSM_PREFIX
end

function GF.GetLSMFontNameFromKey(key)
	if not GF.IsLSMFontKey(key) then
		return nil
	end
	return key:sub(#LSM_PREFIX + 1)
end

function GF.LSMFontStorageKey(name)
	return LSM_PREFIX .. name
end

function GF.AppendLSMFontOptions(out)
	local LSM = GF.GetSharedMedia()
	if not LSM or type(out) ~= "table" then
		return
	end
	local list = LSM:List("font")
	if not list then
		return
	end
	local seen = {}
	for i = 1, #out do
		seen[out[i].value] = true
	end
	local builtinPaths = getBuiltinFontPathSet()
	for i = 1, #list do
		local name = list[i]
		local key = GF.LSMFontStorageKey(name)
		if not seen[key] then
			local path = LSM:Fetch("font", name, true)
			local norm = normalizeFontPath(path)
			if type(path) == "string" and path ~= "" and (not norm or not builtinPaths[norm]) then
				out[#out + 1] = { value = key, label = name }
				seen[key] = true
			end
		end
	end
end

function GF.TryApplyLSMFont(fs, fontKey, sz, flags)
	if not fs or not GF.IsLSMFontKey(fontKey) then
		return false
	end
	local name = GF.GetLSMFontNameFromKey(fontKey)
	local LSM = GF.GetSharedMedia()
	if not LSM or not name then
		return false
	end
	local path = LSM:Fetch("font", name, true)
	if type(path) ~= "string" or path == "" then
		return false
	end
	fs:SetFont(path, sz or 12, flags or "")
	return true
end

function GF.ResolveLSMFontKey(key)
	if GF.IsLSMFontKey(key) then
		local LSM = GF.GetSharedMedia()
		local name = GF.GetLSMFontNameFromKey(key)
		if LSM and name and LSM:IsValid("font", name) then
			return key
		end
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
	db.fontKey = "ChatFontNormal"
	if GF.Font and GF.Font.RefreshAll then
		GF.Font.RefreshAll()
	end
end
