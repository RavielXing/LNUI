local _, GF = ...

GF.MythicPlusSpecializationCache = GF.MythicPlusSpecializationCache or {}
local Cache = GF.MythicPlusSpecializationCache

local function normalizeClassFile(classFile)
	if type(classFile) ~= "string" or classFile == "" then
		return nil
	end
	return classFile:upper()
end

local function hasUsableIcon(icon)
	if icon == nil or icon == "" then
		return false
	end
	local numericIcon = tonumber(icon)
	return numericIcon == nil or numericIcon > 0
end

function Cache:GetInfo(specID)
	specID = tonumber(specID)
	if not specID then
		return nil
	end
	local cached = self.entries and self.entries[specID]
	if cached and hasUsableIcon(cached.specIcon) then
		return cached
	end
	if not GetSpecializationInfoByID then
		return cached
	end
	local ok, resolvedSpecID, specName, _, specIcon, specRole, classFile =
		pcall(GetSpecializationInfoByID, specID)
	if not ok or tonumber(resolvedSpecID) ~= specID then
		return cached
	end
	local info = {
		specID = specID,
		specName = specName,
		specIcon = hasUsableIcon(specIcon) and specIcon or nil,
		specRole = specRole,
		classFile = normalizeClassFile(classFile),
	}
	self.entries = self.entries or {}
	self.entries[specID] = info
	return info
end

function Cache:NormalizeCharacter(character)
	if type(character) ~= "table" then
		return false
	end
	local specID = tonumber(character.specID)
	if not specID then
		return false
	end
	local needsName = type(character.specName) ~= "string"
		or character.specName == ""
	local needsRole = type(character.specRole) ~= "string"
		or character.specRole == ""
	local info
	if not hasUsableIcon(character.specIcon) or needsName or needsRole then
		info = self:GetInfo(specID)
	end
	if not info then
		return false
	end
	local characterClass = normalizeClassFile(
		character.classFile or character.classFilename or character.class)
	if characterClass and info.classFile and characterClass ~= info.classFile then
		return false
	end
	local changed = false
	if not hasUsableIcon(character.specIcon) and hasUsableIcon(info.specIcon) then
		character.specIcon = info.specIcon
		changed = true
	end
	if needsName
		and type(info.specName) == "string" and info.specName ~= ""
	then
		character.specName = info.specName
		changed = true
	end
	if needsRole
		and type(info.specRole) == "string" and info.specRole ~= ""
	then
		character.specRole = info.specRole
		changed = true
	end
	return changed, info
end
