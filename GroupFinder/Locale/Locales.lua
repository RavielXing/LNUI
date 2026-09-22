local _, GF = ...

GF.Locale = GF.Locale or {}
local Locale = GF.Locale

local appliedLocaleValues = Locale._appliedLocaleValues or {}
Locale._appliedLocaleValues = appliedLocaleValues

local function normalizeLocale(locale)
	if locale == "enUS" or locale == "zhCN" or locale == "zhTW" or locale == "ruRU" then
		return locale
	end
	return nil
end

local function normalizeUserLocalePreference(preference)
	if preference == "system" then
		return preference
	end
	return normalizeLocale(preference) or "system"
end

local function getSystemLocaleKey()
	local locale = GetLocale and GetLocale() or "enUS"
	if locale == "zhCN" then
		return "zhCN"
	end
	if locale == "zhTW" then
		return "zhTW"
	end
	if locale == "ruRU" then
		return "ruRU"
	end
	return "enUS"
end

local function getLocaleTable(locale)
	locale = normalizeLocale(locale) or getSystemLocaleKey()
	if locale == "zhCN" then
		return GF.locale_zhCN or GF.locale_enUS, "zhCN"
	end
	if locale == "zhTW" then
		return GF.locale_zhTW or GF.locale_zhCN or GF.locale_enUS, "zhTW"
	end
	if locale == "ruRU" then
		return GF.locale_ruRU or GF.locale_enUS, "ruRU"
	end
	return GF.locale_enUS, "enUS"
end

local function publishLocale(L)
	for key, oldValue in pairs(appliedLocaleValues) do
		if GF[key] == oldValue then
			GF[key] = nil
		end
		appliedLocaleValues[key] = nil
	end
	for k, v in pairs(L or {}) do
		if GF[k] == nil then
			GF[k] = v
			appliedLocaleValues[k] = v
		end
	end
end

local function publishBindingLabels(L)
	L = L or {}
	BINDING_HEADER_GROUPFINDER_TITLE = L.ADDON_NAME or "GroupFinder"
	BINDING_NAME_GROUPFINDER_TOGGLE =
		L.BINDING_FIND_GROUP or "Find a Group"
	BINDING_NAME_GROUPFINDER_CREATE =
		L.BINDING_CREATE or "Start a Group"
	BINDING_NAME_GROUPFINDER_MPLUS_CHARACTER =
		L.BINDING_MPLUS_CHARACTER or "Mythic+ Characters"
	BINDING_NAME_GROUPFINDER_MPLUS_CARPOOL =
		L.BINDING_MPLUS_CARPOOL or "Mythic+ Carpool"
	BINDING_NAME_GROUPFINDER_MPLUS_TELEPORT =
		L.BINDING_MPLUS_TELEPORT or "Mythic+ Quick Teleport"
end

function Locale:ApplyLocale(locale)
	local L, localeKey = getLocaleTable(locale)
	GF.L = L
	self._currentLocaleKey = localeKey
	publishLocale(GF.L)
	publishBindingLabels(GF.L)
	return localeKey, GF.L
end

function Locale:GetSystemLocaleKey()
	return getSystemLocaleKey()
end

function Locale:GetCurrentLocaleKey()
	return self._currentLocaleKey or getSystemLocaleKey()
end

function Locale:GetUserLocalePreference()
	return normalizeUserLocalePreference(self._userLocalePreference)
end

function Locale:GetEffectiveLocaleKey()
	if self._debugLocaleKey ~= nil then
		return self._debugLocaleKey
	end
	local preference = self:GetUserLocalePreference()
	if preference == "system" then
		return getSystemLocaleKey()
	end
	return preference
end

function Locale:ApplyEffectiveLocale()
	return self:ApplyLocale(self:GetEffectiveLocaleKey())
end

function Locale:SetUserLocalePreference(preference)
	preference = normalizeUserLocalePreference(preference)
	self._userLocalePreference = preference
	self:ApplyEffectiveLocale()
	return preference
end

function Locale:SetDebugLocale(locale)
	local localeKey = normalizeLocale(locale)
	if not localeKey then
		return false
	end
	self._debugLocaleKey = localeKey
	self:ApplyLocale(localeKey)
	return true
end

function Locale:ClearDebugLocale()
	self._debugLocaleKey = nil
	self:ApplyEffectiveLocale()
	return true
end

function Locale:IsDebugLocaleActive()
	return self._debugLocaleKey ~= nil
end

-- Blizzard 的专精 API 只返回客户端当前语言。调试语言预览开启时，
-- 以稳定专精 ID 覆盖可见名称；正式运行继续原样使用客户端 API。
function Locale:ResolveSpecializationName(specID, fallback)
	if self._debugLocaleKey ~= nil then
		local numericSpecID
		local compat = GF.Compat
		if compat and type(compat.ToAccessibleNumber) == "function" then
			numericSpecID = compat.ToAccessibleNumber(specID)
		else
			local ok, value = pcall(tonumber, specID)
			if ok and type(value) == "number" then
				numericSpecID = value
			end
		end
		local names = GF.L and GF.L.DEBUG_SPECIALIZATION_NAMES_BY_ID
		local name = type(names) == "table" and numericSpecID
			and names[numericSpecID] or nil
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	return fallback
end

Locale._userLocalePreference = normalizeUserLocalePreference(
	Locale._userLocalePreference)
Locale:ClearDebugLocale()
