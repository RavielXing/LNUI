local _, GF = ...

local Migration = {}
GF.LegacySettingsMigration = Migration

local RENAMED_ROOT_KEYS = {
	inviteCapEnabled = "autoInviteMemberLimitEnabled",
	inviteCap = "autoInviteMemberLimit",
	persistApplyNote = "rememberApplicationNote",
	cancelOldestApply = "replaceOldestApplication",
	moduleBlocklist = "blacklistEnabled",
	blockTipsEnabled = "showBlacklistChatNotice",
}

local REMOVED_ROOT_KEYS = {
	"listMemberStyle",
	"showSpecIcons",
	"showClassColorBar",
	"showRoleBadge",
	"showLeaderCrown",
	"bodyBgStyle",
	"bodyBgTexAlpha",
	"bodyBgCustomEnabled",
	"bodyBgR",
	"bodyBgG",
	"bodyBgB",
	"bodyBgA",
	"bodyBgHex",
	"fontSize",
	"delistedAction",
	"defaultRequiredItemLevelOffset",
	"moduleListFilter",
	"titleContagionEnabled",
}

function Migration:UpgradeRootKeys(database)
	if type(database) ~= "table" then
		return false
	end

	local changed = false
	for legacyKey, currentKey in pairs(RENAMED_ROOT_KEYS) do
		local legacyValue = database[legacyKey]
		if legacyValue ~= nil and database[currentKey] == nil then
			database[currentKey] = legacyValue
			changed = true
		end
		if legacyValue ~= nil then
			database[legacyKey] = nil
			changed = true
		end
	end

	for index = 1, #REMOVED_ROOT_KEYS do
		local key = REMOVED_ROOT_KEYS[index]
		if database[key] ~= nil then
			database[key] = nil
			changed = true
		end
	end
	return changed
end

function Migration:UpgradeCharacterItemLevel(database, resolveSettings, normalizeValue)
	if type(database) ~= "table"
		or database.defaultRequiredItemLevel == nil
		or type(resolveSettings) ~= "function"
	then
		return false
	end

	local settings = resolveSettings(database, true)
	if type(settings) ~= "table" then
		-- Character identity can be unavailable during early login. Keep the
		-- legacy value until the first getter or setter can resolve an owner.
		return false
	end

	if settings.defaultRequiredItemLevel == nil then
		local value = database.defaultRequiredItemLevel
		if type(normalizeValue) == "function" then
			value = normalizeValue(value)
		end
		settings.defaultRequiredItemLevel = value
	end
	database.defaultRequiredItemLevel = nil
	return true
end
