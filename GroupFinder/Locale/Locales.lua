local _, GF = ...

GF.Locale = GF.Locale or {}
local Locale = GF.Locale
Locale.resourceAPIVersion = 1
local appliedLocaleValues = Locale._appliedLocaleValues or {}
Locale._appliedLocaleValues = appliedLocaleValues
local supportedLocales = { "enUS", "zhCN", "zhTW", "ruRU" }

local function normalizeLocale(locale)
	if locale == "enUS" or locale == "zhCN" or locale == "zhTW" or locale == "ruRU" then
		return locale
	end
end

local function normalizeUserLocalePreference(preference)
	if preference == "system" then return preference end
	return normalizeLocale(preference) or "system"
end

local function getSystemLocaleKey()
	return normalizeLocale(GetLocale and GetLocale() or "enUS") or "enUS"
end

local function resolvePreference(preference)
	return preference == "system" and getSystemLocaleKey() or preference
end

local function publishLocale(L)
	for key, oldValue in pairs(appliedLocaleValues) do
		if GF[key] == oldValue then GF[key] = nil end
		appliedLocaleValues[key] = nil
	end
	for key, value in pairs(L or {}) do
		if GF[key] == nil then
			GF[key] = value
			appliedLocaleValues[key] = value
		end
	end
end

local function publishBindingLabels(L)
	L = L or {}
	BINDING_HEADER_GROUPFINDER_TITLE = L.ADDON_NAME or "GroupFinder"
	BINDING_NAME_GROUPFINDER_TOGGLE = L.BINDING_FIND_GROUP or "Find a Group"
	BINDING_NAME_GROUPFINDER_CREATE = L.BINDING_CREATE or "Start a Group"
	BINDING_NAME_GROUPFINDER_MPLUS_CHARACTER = L.BINDING_MPLUS_CHARACTER or "Characters"
	BINDING_NAME_GROUPFINDER_MPLUS_CARPOOL = L.BINDING_MPLUS_CARPOOL or "Carpool"
	BINDING_NAME_GROUPFINDER_MPLUS_TELEPORT = L.BINDING_MPLUS_TELEPORT or "Teleport Map"
	BINDING_NAME_GROUPFINDER_RAID_SEEK = L.BINDING_RAID_SEEK or "Seek Raid"
	BINDING_NAME_GROUPFINDER_RAID_SQUARE = L.BINDING_RAID_SQUARE or "Player Board"
end

local function applyResources(resources, key)
	GF.L = resources
	Locale._currentLocaleKey = key
	publishLocale(resources)
	publishBindingLabels(resources)
	return key, resources
end

local function debugCompanionEnabled()
	if not (C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function"
		and type(UnitGUID) == "function") then return false end
	local ok, character = pcall(UnitGUID, "player")
	if not ok or not character then return false end
	local enabled
	ok, enabled = pcall(C_AddOns.GetAddOnEnableState, "GroupFinder_Debug", character)
	return ok and type(enabled) == "number" and enabled > 0
end

local function usableResources(resources)
	return type(resources) == "table" and type(resources.ADDON_NAME) == "string"
		and resources.ADDON_NAME ~= "" and type(resources.BINDING_FIND_GROUP) == "string"
end

-- Called only during database initialization, after WoW has restored the account
-- SavedVariables. No locale preference is inspected at file-definition time.
local function loadResources(localeKey)
	if localeKey == "enUS" and usableResources(GF.locale_enUS) then
		return GF.locale_enUS
	end
	local existing = GF["locale_" .. localeKey]
	if usableResources(existing) then return existing end
	if Locale._resourceLoading then return nil, "loading" end
	local compat = GF.Compat
	if not compat or type(compat.LoadAddOn) ~= "function" then
		return nil, "loader-unavailable"
	end
	Locale._resourceLocaleKey = localeKey
	Locale._resourceLoading = true
	local ok, loaded, reason = pcall(compat.LoadAddOn, "GroupFinder_Locales")
	Locale._resourceLoading = nil
	Locale._resourceLocaleKey = nil
	if not ok or loaded ~= true or Locale._resourceLoadedKey ~= localeKey then
		return nil, not ok and "load-error" or reason or "incompatible-resources"
	end
	existing = GF["locale_" .. localeKey]
	return usableResources(existing) and existing or nil, "incomplete-resources"
end

local function fillMissingTranslations(resources, english)
	for key, value in pairs(english or {}) do
		if resources[key] == nil then
			resources[key] = value
		elseif type(resources[key]) == "table" and type(value) == "table" then
			fillMissingTranslations(resources[key], value)
		end
	end
end

local function releaseOtherResources(activeKey)
	for index = 1, #supportedLocales do
		local key = supportedLocales[index]
		if key ~= activeKey then GF["locale_" .. key] = nil end
	end
end

function Locale:ShouldLoadResource(localeKey)
	return self._resourceLoading == true and self._initialized ~= true
		and normalizeLocale(localeKey) == self._resourceLocaleKey
end

function Locale:InitializeUserLocalePreference(preference)
	self:SetUserLocalePreference(preference)
	if self._initialized then return self:GetCurrentLocaleKey(), GF.L end
	local database = GF.db or _G.GroupFinderDB
	local debugKey = type(database) == "table" and normalizeLocale(database.debugInterfaceLocale)
	if debugKey and debugCompanionEnabled() then
		self._debugLocaleKey = debugKey
	end
	local desiredKey = self:GetEffectiveLocaleKey()
	local english = GF.locale_enUS
	local resources, reason = loadResources(desiredKey)
	if not resources then
		resources, desiredKey = english, "enUS"
		self._resourceFailureReason = reason or "resources-unavailable"
	else
		self._resourceFailureReason = nil
		-- Keep complete English fallback values only for untranslated keys. The
		-- complete English table itself is released after successful publication.
		fillMissingTranslations(resources, english)
	end
	if not usableResources(resources) then return false, "fallback-unavailable" end
	applyResources(resources, desiredKey)
	self._activeDebugLocaleKey = desiredKey == self._debugLocaleKey and desiredKey or nil
	self._initialized = true
	releaseOtherResources(desiredKey)
	if self._resourceFailureReason and not self._resourceFailureReported then
		local frame = DEFAULT_CHAT_FRAME
		if frame and type(frame.AddMessage) == "function" then
			local template = resources.LOCALE_RESOURCE_LOAD_FAILED
				or "Language resources could not be loaded; English is available (%s)."
			local reasonText = type(self._resourceFailureReason) == "string"
				and self._resourceFailureReason or "load-failed"
			frame:AddMessage(string.format(template, reasonText), 1, 0.82, 0)
			self._resourceFailureReported = true
		end
	end
	return desiredKey, resources
end

-- The legacy explicit entry point remains callable, but cannot load or retain a
-- second resource set after startup. Language changes use the reload boundary.
function Locale:ApplyLocale(localeKey)
	localeKey = normalizeLocale(localeKey) or getSystemLocaleKey()
	if self._initialized then
		if localeKey ~= self:GetCurrentLocaleKey() then return false, "reload-required" end
		return applyResources(GF.L, localeKey)
	end
	local resources = GF["locale_" .. localeKey]
	if not usableResources(resources) then resources, localeKey = GF.locale_enUS, "enUS" end
	return applyResources(resources or {}, localeKey)
end

function Locale:GetSystemLocaleKey() return getSystemLocaleKey() end
function Locale:GetCurrentLocaleKey() return self._currentLocaleKey or "enUS" end
function Locale:GetUserLocalePreference()
	return normalizeUserLocalePreference(self._userLocalePreference)
end
function Locale:GetEffectiveLocaleKey()
	return self._debugLocaleKey or resolvePreference(self:GetUserLocalePreference())
end
function Locale:IsReloadRequired()
	return self:GetEffectiveLocaleKey() ~= self:GetCurrentLocaleKey()
		or self._activeDebugLocaleKey ~= self._debugLocaleKey
end
function Locale:ApplyEffectiveLocale()
	return self:ApplyLocale(self:GetEffectiveLocaleKey())
end
function Locale:SetUserLocalePreference(preference)
	self._userLocalePreference = normalizeUserLocalePreference(preference)
	-- ResetAllSettings clears the account preview key through the repository.
	-- Reconcile its pending owner without changing the already loaded language.
	if self._initialized and type(GF.db) == "table" then
		self._debugLocaleKey = debugCompanionEnabled()
			and normalizeLocale(GF.db.debugInterfaceLocale) or nil
	end
	return self._userLocalePreference
end
function Locale:SetDebugLocale(localeKey)
	localeKey = normalizeLocale(localeKey)
	if not localeKey then return false end
	self._debugLocaleKey = localeKey
	local database = GF.db or _G.GroupFinderDB
	if type(database) == "table" then database.debugInterfaceLocale = localeKey end
	return true
end
function Locale:ClearDebugLocale()
	self._debugLocaleKey = nil
	local database = GF.db or _G.GroupFinderDB
	if type(database) == "table" then database.debugInterfaceLocale = nil end
	return true
end
function Locale:IsDebugLocaleActive()
	return self._debugLocaleKey ~= nil or self._activeDebugLocaleKey ~= nil
end

-- Blizzard specialization names keep their client language. Only a preview
-- actually applied at reload uses the stable-ID diagnostic translations.
function Locale:ResolveSpecializationName(specID, fallback)
	if self._activeDebugLocaleKey ~= nil then
		local numericSpecID
		local compat = GF.Compat
		if compat and type(compat.ToAccessibleNumber) == "function" then
			numericSpecID = compat.ToAccessibleNumber(specID)
		else
			local ok, value = pcall(tonumber, specID)
			if ok and type(value) == "number" then numericSpecID = value end
		end
		local names = GF.L and GF.L.DEBUG_SPECIALIZATION_NAMES_BY_ID
		local name = type(names) == "table" and numericSpecID and names[numericSpecID]
		if type(name) == "string" and name ~= "" then return name end
	end
	return fallback
end

Locale._userLocalePreference = normalizeUserLocalePreference(Locale._userLocalePreference)
-- English definitions make every Core/UI file safe before account data exists.
-- Real startup chooses exactly one full language and releases all others.
Locale:ApplyLocale(getSystemLocaleKey())
