local _, GF = ...

GF.Locale = GF.Locale or {}
local Locale = GF.Locale

local appliedLocaleKeys = Locale._appliedLocaleKeys or {}
Locale._appliedLocaleKeys = appliedLocaleKeys
local appliedLocaleValues = Locale._appliedLocaleValues or {}
Locale._appliedLocaleValues = appliedLocaleValues

local function normalizeLocale(locale)
	if locale == "enUS" or locale == "zhCN" or locale == "zhTW" then
		return locale
	end
	return nil
end

local function getSystemLocaleKey()
	local locale = GetLocale and GetLocale() or "enUS"
	if locale == "zhCN" then
		return "zhCN"
	end
	if locale == "zhTW" then
		return "zhTW"
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
	return GF.locale_enUS, "enUS"
end

local function finalizeLocale(L)
	if L and L.USAGE_GUIDE_TEXT and L.COL_LAYOUT_HELP_HINT then
		L.USAGE_GUIDE_TEXT = L.USAGE_GUIDE_TEXT:gsub("{COL_LAYOUT_HELP}", L.COL_LAYOUT_HELP_HINT, 1)
	end
end

local function publishLocale(L)
	for key, oldValue in pairs(appliedLocaleValues) do
		if GF[key] == oldValue then
			GF[key] = nil
		end
		appliedLocaleKeys[key] = nil
		appliedLocaleValues[key] = nil
	end
	for k, v in pairs(L or {}) do
		if GF[k] == nil then
			GF[k] = v
			appliedLocaleKeys[k] = true
			appliedLocaleValues[k] = v
		end
	end
end

function Locale:ApplyLocale(locale)
	local L, localeKey = getLocaleTable(locale)
	GF.L = L
	self._currentLocaleKey = localeKey
	finalizeLocale(GF.L)
	publishLocale(GF.L)
	BINDING_HEADER_GROUPFINDER_TITLE = (GF.L and GF.L.ADDON_NAME) or "GroupFinder"
	BINDING_NAME_GROUPFINDER_TOGGLE = (GF.L and GF.L.BINDING_TOGGLE) or "Toggle window"
	return localeKey, GF.L
end

function Locale:GetSystemLocaleKey()
	return getSystemLocaleKey()
end

function Locale:GetCurrentLocaleKey()
	return self._currentLocaleKey or getSystemLocaleKey()
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
	self:ApplyLocale(getSystemLocaleKey())
	return true
end

function Locale:IsDebugLocaleActive()
	return self._debugLocaleKey ~= nil
end

function Locale:ClearSavedDebugLocale()
	if type(GroupFinderDB) == "table" then
		GroupFinderDB.debugForceLocale = nil
	end
end

Locale:ClearSavedDebugLocale()
Locale:ClearDebugLocale()

BINDING_HEADER_GROUPFINDER_TITLE = (GF.L and GF.L.ADDON_NAME) or "GroupFinder"
BINDING_NAME_GROUPFINDER_TOGGLE = (GF.L and GF.L.BINDING_TOGGLE) or "Toggle window"
