
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC and C_Seasons.GetActiveSeason() ~= 2 and C_Seasons.GetActiveSeason() ~= 11 and C_Seasons.GetActiveSeason() ~= 12 then return end

local MAJOR, MINOR = "LibDualSpec-1.0", 28
assert(LibStub, MAJOR.." requires LibStub")
local lib, minor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- ----------------------------------------------------------------------------
-- Library data
-- ----------------------------------------------------------------------------

lib.eventFrame = lib.eventFrame or CreateFrame("Frame")

lib.registry = lib.registry or {}
lib.options = lib.options or {}
lib.mixin = lib.mixin or {}
lib.upgrades = lib.upgrades or {}
lib.currentSpec = tonumber(lib.currentSpec) or 0

if minor and minor < 15 then
	lib.talentsLoaded, lib.talentGroup = nil, nil
	lib.specLoaded, lib.specGroup = nil, nil
	lib.eventFrame:UnregisterAllEvents()
	wipe(lib.options)
end

-- ----------------------------------------------------------------------------
-- Locals
-- ----------------------------------------------------------------------------

local registry = lib.registry
local options = lib.options
local mixin = lib.mixin
local upgrades = lib.upgrades

-- "Externals"
local AceDB3 = LibStub('AceDB-3.0', true)
local AceDBOptions3 = LibStub('AceDBOptions-3.0', true)
local AceConfigRegistry3 = LibStub('AceConfigRegistry-3.0', true)

local isSpecBased = ClassicExpansionAtLeast(LE_EXPANSION_MISTS_OF_PANDARIA)
local numSpecs
local specNames = {}
if isSpecBased then
	-- class id specialization functions don't require player data to be loaded
	local _, classId = UnitClassBase("player")
	numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classId)
	for i = 1, numSpecs do
		local _, name = GetSpecializationInfoForClassID(classId, i)
		specNames[i] = name
	end
else -- Primary/secondary system
	numSpecs = 2
	specNames[1] = TALENT_SPEC_PRIMARY
	specNames[2] = TALENT_SPEC_SECONDARY
end

local GetSpecialization = isSpecBased and GetSpecialization or C_SpecializationInfo.GetActiveSpecGroup
local CanPlayerUseTalentSpecUI = C_SpecializationInfo.CanPlayerUseTalentSpecUI or function()
	return true, HELPFRAME_CHARACTER_BULLET5
end

local L_ENABLED = "Enable spec profiles"
local L_ENABLED_DESC = "When enabled, your profile will be set to the specified profile when you change specialization."
local L_CURRENT = "%s - Active"

do
	local locale = GetLocale()
	if locale == "deDE" then
		L_ENABLED = "Spezialisierungsprofile aktivieren"
		L_ENABLED_DESC = "Falls diese Option aktiviert ist, wird dein Profil auf das angegebene Profil gesetzt, wenn du die Spezialisierung wechselst."
		L_CURRENT = "%s - Aktiv"
	elseif locale == "zhCN" then
		L_ENABLED = "启用专精配置文件"
		L_ENABLED_DESC = "当启用后，当切换专精时配置文件将设置为专精配置文件。"
		L_CURRENT = "%s - 开启"
	elseif locale == "zhTW" then
		L_ENABLED = "啟用專精設定檔"
		L_ENABLED_DESC = "當啟用後，當你切換專精時設定檔會設定為專精設定檔。"
		L_CURRENT = "%s - 啟動"
	end
end

function mixin:IsDualSpecEnabled()
	return lib.currentSpec > 0 and registry[self].db.char.enabled
end

function mixin:SetDualSpecEnabled(enabled)
	local db = registry[self].db.char
	db.enabled = not not enabled

	local currentProfile = self:GetCurrentProfile()
	for i = 1, numSpecs do
		db[i] = enabled and (db[i] or currentProfile) or nil
	end

	self:CheckDualSpecState()
end

function mixin:GetDualSpecProfile(spec)
	return registry[self].db.char[spec or lib.currentSpec] or self:GetCurrentProfile()
end

function mixin:SetDualSpecProfile(profileName, spec)
	spec = spec or lib.currentSpec
	if spec < 1 or spec > numSpecs then return end

	registry[self].db.char[spec] = profileName
	self:CheckDualSpecState()
end

function mixin:CheckDualSpecState()
	if not registry[self].db.char.enabled then return end
	if lib.currentSpec == 0 then return end

	local profileName = self:GetDualSpecProfile()
	if profileName ~= self:GetCurrentProfile() then
		self:SetProfile(profileName)
	end
end

local function EmbedMixin(target)
	for k,v in next, mixin do
		rawset(target, k, v)
	end
end

local function UpgradeDatabase(target)
	if lib.currentSpec == 0 then
		upgrades[target] = true
		return
	end

	local db = target:GetNamespace(MAJOR, true)
	if db and db.char.profile then
		for i = 1, numSpecs do
			if i == lib.currentSpec then
				db.char[i] = target:GetCurrentProfile()
			else
				db.char[i] = db.char.profile
			end
		end
		db.char.profile = nil
		db.char.specGroup = nil
	end
end

function lib:OnProfileDeleted(event, target, profileName)
	local db = registry[target].db.char
	if not db.enabled then return end

	for i = 1, numSpecs do
		if db[i] == profileName then
			db[i] = target:GetCurrentProfile()
		end
	end
end

function lib:_EnhanceDatabase(event, target)
	registry[target].db = target:GetNamespace(MAJOR, true) or target:RegisterNamespace(MAJOR)
	EmbedMixin(target)
	target:CheckDualSpecState()
end

function lib:EnhanceDatabase(target, name)
	AceDB3 = AceDB3 or LibStub('AceDB-3.0', true)
	if type(target) ~= "table" then
		error("Usage: LibDualSpec:EnhanceDatabase(target, name): target should be a table.", 2)
	elseif type(name) ~= "string" then
		error("Usage: LibDualSpec:EnhanceDatabase(target, name): name should be a string.", 2)
	elseif not AceDB3 or not AceDB3.db_registry[target] then
		error("Usage: LibDualSpec:EnhanceDatabase(target, name): target should be an AceDB-3.0 database.", 2)
	elseif target.parent then
		error("Usage: LibDualSpec:EnhanceDatabase(target, name): cannot enhance a namespace.", 2)
	elseif registry[target] then
		return
	end
	registry[target] = { name = name }
	UpgradeDatabase(target)
	lib:_EnhanceDatabase("EnhanceDatabase", target)
	target.RegisterCallback(lib, "OnDatabaseReset", "_EnhanceDatabase")
	target.RegisterCallback(lib, "OnProfileDeleted")
end

options.new = {
	name = "New",
	type = "input",
	order = 30,
	get = false,
	set = function(info, value)
		local db = info.handler.db
		if db:IsDualSpecEnabled() then
			db:SetDualSpecProfile(value, lib.currentSpec)
		else
			db:SetProfile(value)
		end
	end,
}

options.choose = {
	name = "Existing Profiles",
	type = "select",
	order = 40,
	get = "GetCurrentProfile",
	set = "SetProfile",
	values = "ListProfiles",
	arg = "common",
	disabled = function(info)
		return info.handler.db:IsDualSpecEnabled()
	end
}

options.enabled = {
	type = "toggle",
	name = "|cffffd200"..L_ENABLED.."|r",
	desc = function()
		local desc = L_ENABLED_DESC
		if lib.currentSpec == 0 then
			local _, reason = CanPlayerUseTalentSpecUI()
			if not reason or reason == "" or reason == "LEVEL_TOO_LOW" then
				reason = isSpecBased and "TALENT_MICRO_BUTTON_NO_SPEC" or "INSTANCE_UNAVAILABLE_SELF_LEVEL_TOO_LOW"
			end
			desc = desc .. "\n\n" .. RED_FONT_COLOR:WrapTextInColorCode(_G[reason])
		end
		return desc
	end,
	descStyle = "inline",
	order = 41,
	width = "full",
	get = function(info) return info.handler.db:IsDualSpecEnabled() end,
	set = function(info, value) info.handler.db:SetDualSpecEnabled(value) end,
	disabled = function() return lib.currentSpec == 0 end,
}

local points = {}
for i = 1, numSpecs do
	options["specProfile" .. i] = {
		type = "select",
		name = function(info)
			local specIndex = tonumber(info[#info]:sub(-1))
			return lib.currentSpec == specIndex and L_CURRENT:format(specNames[specIndex]) or specNames[specIndex]
		end,
		desc = ClassicExpansionAtMost(LE_EXPANSION_SHADOWLANDS) and function(info)
			if lib.currentSpec == 0 then
				return nil
			end
			if ClassicExpansionAtMost(LE_EXPANSION_CATACLYSM) then -- Pre-5.0
				local specIndex = tonumber(info[#info]:sub(-1))
				local highPointsSpentIndex = nil
				for treeIndex = 1, 3 do
					local _, name, _, _, pointsSpent, _, previewPointsSpent = GetTalentTabInfo(treeIndex, nil, nil, specIndex)
					if name then
						local displayPointsSpent = pointsSpent + previewPointsSpent
						points[treeIndex] = displayPointsSpent
						if displayPointsSpent > 0 and (not highPointsSpentIndex or displayPointsSpent > points[highPointsSpentIndex]) then
							highPointsSpentIndex = treeIndex
						end
					else
						points[treeIndex] = 0
					end
				end
				if highPointsSpentIndex then
					points[highPointsSpentIndex] = GREEN_FONT_COLOR:WrapTextInColorCode(points[highPointsSpentIndex])
				end
				return ("|cffffffff%s / %s / %s|r"):format(unpack(points))
			elseif C_SpecializationInfo.GetSpecialization then -- 5.0 - 9.x
				local specGroup = tonumber(info[#info]:sub(-1))
				local specIndex = C_SpecializationInfo.GetSpecialization(nil, nil, specGroup)
				if specIndex then
					local sex = UnitSex("player")
					local _, specName = C_SpecializationInfo.GetSpecializationInfo(specIndex, nil, nil, sex)
					return ("|cffffffff%s|r"):format(specName)
				end
			end
		end or nil,
		order = 42 + i,
		get = function(info)
			local specIndex = tonumber(info[#info]:sub(-1))
			return info.handler.db:GetDualSpecProfile(specIndex)
		end,
		set = function(info, value)
			local specIndex = tonumber(info[#info]:sub(-1))
			info.handler.db:SetDualSpecProfile(value, specIndex)
		end,
		values = "ListProfiles",
		arg = "common",
		disabled = function(info) return not info.handler.db:IsDualSpecEnabled() end,
	}
end

function lib:EnhanceOptions(optionTable, target)
	AceDBOptions3 = AceDBOptions3 or LibStub('AceDBOptions-3.0', true)
	AceConfigRegistry3 = AceConfigRegistry3 or LibStub('AceConfigRegistry-3.0', true)
	if type(optionTable) ~= "table" then
		error("Usage: LibDualSpec:EnhanceOptions(optionTable, target): optionTable should be a table.", 2)
	elseif type(target) ~= "table" then
		error("Usage: LibDualSpec:EnhanceOptions(optionTable, target): target should be a table.", 2)
	elseif not AceDBOptions3 or not AceDBOptions3.optionTables[target] then
		error("Usage: LibDualSpec:EnhanceOptions(optionTable, target): optionTable is not an AceDBOptions-3.0 table.", 2)
	elseif optionTable.handler.db ~= target then
		error("Usage: LibDualSpec:EnhanceOptions(optionTable, target): optionTable must be the option table of target.", 2)
	elseif not registry[target] then
		error("Usage: LibDualSpec:EnhanceOptions(optionTable, target): EnhanceDatabase should be called before EnhanceOptions(optionTable, target).", 2)
	end

	-- localize our replacements
	options.new.name = optionTable.args.new.name
	options.new.desc = optionTable.args.new.desc
	options.choose.name = optionTable.args.choose.name
	options.choose.desc = optionTable.args.choose.desc

	-- add our new options
	if not optionTable.plugins then
		optionTable.plugins = {}
	end
	optionTable.plugins[MAJOR] = options
end

-- ----------------------------------------------------------------------------
-- Upgrade existing
-- ----------------------------------------------------------------------------

for target in next, registry do
	UpgradeDatabase(target)
	EmbedMixin(target)
	target:CheckDualSpecState()
	local optionTable = AceDBOptions3 and AceDBOptions3.optionTables[target]
	if optionTable then
		lib:EnhanceOptions(optionTable, target)
	end
end

-- ----------------------------------------------------------------------------
-- Inspection
-- ----------------------------------------------------------------------------

do
	local function iterator(t, key)
		local data
		key, data = next(t, key)
		if key then
			return key, data.name
		end
	end

	function lib:IterateDatabases()
		return iterator, lib.registry
	end
end

-- ----------------------------------------------------------------------------
-- Switching logic
-- ----------------------------------------------------------------------------

local function eventHandler(self, event)
	local spec = GetSpecialization() or 0
	-- Newly created characters start at 5 instead of 1 in 9.0.1.
	if spec == 5 or not CanPlayerUseTalentSpecUI() then
		spec = 0
	end
	lib.currentSpec = spec

	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent(event)
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		if isSpecBased then
			self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
			self:RegisterEvent("PLAYER_LEVEL_CHANGED")
		else
			self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
		end
	end

	if spec > 0 and next(upgrades) then
		for target in next, upgrades do
			UpgradeDatabase(target)
		end
		wipe(upgrades)
	end

	for target in next, registry do
		target:CheckDualSpecState()
	end

	if AceConfigRegistry3 and next(registry) then
		for appName in AceConfigRegistry3:IterateOptionsTables() do
			AceConfigRegistry3:NotifyChange(appName)
		end
	end
end

lib.eventFrame:SetScript("OnEvent", eventHandler)
if IsLoggedIn() then
	eventHandler(lib.eventFrame, "PLAYER_LOGIN")
else
	lib.eventFrame:RegisterEvent("PLAYER_LOGIN")
end

