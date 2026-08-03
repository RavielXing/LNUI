local _, GF = ...

GF.MythicPlusDebugService = GF.MythicPlusDebugService or {}
local Service = GF.MythicPlusDebugService
local Util = GF.MythicPlusServiceUtil

local LOCAL_CHARACTER_TEMPLATES = {
	{ id = "tank", nameKey = "localTank", classFile = "WARRIOR", specID = 73, keyLevel = 12, keyUpgradeTrack = "mythic", rating = 2140, roles = { "TANK" }, keyMode = "ready", bestRunCount = 3 },
	{ id = "healer", nameKey = "localHealer", classFile = "PRIEST", specID = 257, rating = 2465, roles = { "HEAL" }, keyMode = "empty", bestRunCount = 2, carpoolEnabled = false },
	{ id = "damage", nameKey = "localDamage", classFile = "MAGE", specID = 64, roles = { "DPS" }, keyMode = "unknown", ratingMode = "unknown", bestRunCount = 0 },
	{ id = "flex", nameKey = "localFlex", classFile = "DRUID", specID = 104, keyLevel = 16, keyUpgradeTrack = "iron", rating = 2785, roles = { "TANK", "HEAL", "DPS" }, keyMode = "ready", bestRunCount = 4 },
}

local ROSTER_MEMBER_TEMPLATES = {
	{ id = "tank", nameKey = "rosterTank", classFile = "WARRIOR", specID = 73, keyLevel = 18, keyUpgradeTrack = "mythic", debugKeystonePayload = "link", rating = 2865, role = "TANK", roles = { "TANK" }, keyMode = "ready", bestRunCount = 3 },
	{ id = "healer", nameKey = "rosterHealer", classFile = "PRIEST", specID = 257, rating = 2580, role = "HEAL", roles = { "HEAL", "DPS" }, keyMode = "empty", bestRunCount = 2 },
	{ id = "melee", nameKey = "rosterMelee", classFile = "ROGUE", specID = 260, keyLevel = 20, keyUpgradeTrack = "iron", debugKeystonePayload = "plain", rating = 3120, role = "DPS", roles = { "DPS" }, keyMode = "ready", bestRunCount = 4 },
	{ id = "ranged", nameKey = "rosterRanged", classFile = "SHAMAN", specID = 262, role = "DPS", roles = { "HEAL", "DPS" }, keyMode = "unknown", ratingMode = "unknown", bestRunCount = 0 },
	{ id = "offline", nameKey = "rosterOffline", classFile = "MAGE", specID = 64, keyLevel = 15, keyUpgradeTrack = "mythic", debugKeystonePayload = "link", rating = 2260, role = "DPS", roles = { "DPS" }, keyMode = "ready", bestRunCount = 1, connected = false },
	{ id = "unknown", nameKey = "rosterUnknown", classFile = "EVOKER", role = nil, roles = {}, keyMode = "unknown", ratingMode = "unknown", bestRunCount = 0, isRosterOnly = true },
}

local CARPOOL_GROUP_TEMPLATES = {
	{
		ownerKey = "ownerMorning",
		ownerClass = "DEMONHUNTER",
		warbandKey = "morning",
		characters = {
			{ id = "morningCurrent", nameKey = "ownerMorning", classFile = "DEMONHUNTER", specID = 577, keyLevel = 14, keyUpgradeTrack = "mythic", rating = 2520, roles = { "DPS" }, keyMode = "ready", bestRunCount = 2, isCurrent = true },
			{ id = "morningBalance", nameKey = "morningBalance", classFile = "DRUID", specID = 102, rating = 2010, roles = { "DPS", "HEAL" }, keyMode = "empty", bestRunCount = 1 },
		},
	},
	{
		ownerKey = "ownerWeekend",
		ownerClass = "ROGUE",
		warbandKey = "weekend",
		characters = {
			{ id = "weekendCurrent", nameKey = "ownerWeekend", classFile = "ROGUE", specID = 260, keyLevel = 19, keyUpgradeTrack = "iron", rating = 2875, roles = { "DPS" }, keyMode = "ready", bestRunCount = 3, isCurrent = true },
			{ id = "weekendMonk", nameKey = "weekendMonk", classFile = "MONK", specID = 268, roles = { "TANK", "HEAL", "DPS" }, keyMode = "unknown", ratingMode = "unknown", bestRunCount = 0 },
		},
	},
	{
		ownerKey = "ownerNight",
		ownerClass = "HUNTER",
		warbandKey = "night",
		characters = {
			{ id = "nightCurrent", nameKey = "ownerNight", classFile = "HUNTER", specID = 254, keyLevel = 17, keyUpgradeTrack = "mythic", rating = 2680, roles = { "DPS" }, keyMode = "ready", bestRunCount = 3, isCurrent = true },
			{ id = "nightShaman", nameKey = "nightShaman", classFile = "SHAMAN", specID = 264, keyLevel = 19, keyUpgradeTrack = "iron", rating = 2910, roles = { "HEAL", "DPS" }, keyMode = "ready", bestRunCount = 4 },
			{ id = "nightPaladin", nameKey = "nightPaladin", classFile = "PALADIN", specID = 66, rating = 3235, roles = { "TANK", "HEAL" }, keyMode = "empty", bestRunCount = 2 },
			{ id = "nightEvoker", nameKey = "nightEvoker", classFile = "EVOKER", specID = 1473, roles = {}, keyMode = "unknown", ratingMode = "unknown", bestRunCount = 0 },
		},
	},
}

local function now()
	return Util and Util.Now and Util.Now() or (time and time() or 0)
end

local function notify(reason)
	if Util and Util.Notify then
		Util.Notify(Service, reason)
	end
end

local function showStatus(message)
	if GF.ShowStatusMessage then
		GF.ShowStatusMessage(message, { semantic = true })
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(tostring(message or ""))
	end
end

local function getFixtureSection(section)
	local fixtures = GF.L and GF.L.DEBUG_MPLUS_FIXTURES
	local value = type(fixtures) == "table" and fixtures[section] or nil
	return type(value) == "table" and value or {}
end

local function fixtureText(section, key, fallback)
	local value = getFixtureSection(section)[key]
	if type(value) == "string" and value ~= "" then
		return value
	end
	return fallback or tostring(key or "")
end

local function getRealm()
	local realm = GetRealmName and GetRealmName() or nil
	return type(realm) == "string" and realm ~= "" and realm
		or fixtureText("meta", "realm", "TestRealm")
end

local function getMaxLevel()
	local effectiveGetter = GameRulesUtil
		and GameRulesUtil.GetEffectiveMaxLevelForPlayer
	if type(effectiveGetter) == "function" then
		local ok, level = pcall(effectiveGetter)
		level = ok and tonumber(level) or nil
		if level and level > 0 then
			return level
		end
	end
	if GetMaxPlayerLevel then
		local ok, level = pcall(GetMaxPlayerLevel)
		level = ok and tonumber(level) or nil
		if level and level > 0 then
			return level
		end
	end
	return tonumber(_G.MAX_PLAYER_LEVEL) or 80
end

local function getCurrentSeasonID()
	local getter = GF.MythicPlusSeason and GF.MythicPlusSeason.GetSeasonID
	if type(getter) ~= "function" then
		return nil
	end
	local ok, seasonID = pcall(getter, GF.MythicPlusSeason)
	seasonID = ok and tonumber(seasonID) or nil
	return seasonID and seasonID > 0 and seasonID or nil
end

local function getSeasonDungeons()
	local source = GF.MythicPlusSeason and GF.MythicPlusSeason.GetDungeons
		and GF.MythicPlusSeason:GetDungeons() or {}
	local dungeons = {}
	for _, dungeon in ipairs(source) do
		if tonumber(dungeon.challengeModeID) then
			dungeons[#dungeons + 1] = dungeon
		end
	end
	if #dungeons == 0 then
		for _, dungeon in ipairs(source) do
			dungeons[#dungeons + 1] = dungeon
		end
	end
	return dungeons
end

local function getDungeon(dungeons, index)
	if #dungeons == 0 then
		return nil
	end
	return dungeons[((index - 1) % #dungeons) + 1]
end

local function resolveSpecInfo(template)
	local specID = tonumber(template.specID)
	local specName = template.specName
	local classFile = template.classFile
	local role = template.role
	if specID and type(GetSpecializationInfoByID) == "function" then
		local ok, _, name, _, _, apiRole, apiClassFile =
			pcall(GetSpecializationInfoByID, specID, UnitSex and UnitSex("player") or nil)
		if ok then
			specName = type(name) == "string" and name ~= "" and name or specName
			classFile = type(apiClassFile) == "string" and apiClassFile ~= ""
				and apiClassFile or classFile
			if not role and type(apiRole) == "string" then
				role = Util and Util.NormalizeRole and Util.NormalizeRole(apiRole) or apiRole
			end
		end
	end
	return specID, specName, classFile, role
end

local function buildBestRuns(template, dungeons, ordinal)
	local count = math.max(0, math.floor(tonumber(template.bestRunCount) or 0))
	local runs = {}
	for runIndex = 1, math.min(count, #dungeons) do
		local dungeon = getDungeon(dungeons, ordinal + runIndex - 1)
		local mapID = dungeon and (
			tonumber(dungeon.challengeModeID)
			or tonumber(dungeon.mapID)
		) or nil
		if mapID then
			local level = math.max(
				2,
				(tonumber(template.keyLevel) or 10) - runIndex + 1
			)
			runs[#runs + 1] = {
				mapID = mapID,
				level = level,
				score = math.max(
					1,
					math.floor((tonumber(template.rating) or 1600) / 8)
						- ((runIndex - 1) * 7)
				),
				durationMS = (1450 + ((ordinal + runIndex) * 37)) * 1000,
				timed = runIndex % 3 ~= 0,
			}
		end
	end
	return runs
end

local function buildCharacter(template, realm, dungeons, source, ordinal)
	local name = fixtureText(
		"names",
		template.nameKey,
		template.name or template.nameKey or "TestPlayer"
	)
	local fullName = string.format("%s-%s", name, realm)
	local dungeon = getDungeon(dungeons, ordinal)
	local rawChallengeModeID = dungeon and tonumber(dungeon.challengeModeID) or nil
	local keyMode = template.keyMode or "ready"
	if keyMode == "ready" and not rawChallengeModeID then
		keyMode = "unknown"
	end
	local hasReadyKey = keyMode == "ready"
	local specID, specName, classFile, specRole = resolveSpecInfo(template)
	local timestamp = now()
	local rating = template.ratingMode == "unknown"
		and nil or tonumber(template.rating)
	local ratingSeasonID = rating and getCurrentSeasonID() or nil
	local character = {
		key = fullName,
		elementKey = string.format(
			"debug:%s:%s:%d",
			source,
			tostring(template.id or template.nameKey or "character"),
			ordinal or 0
		),
		fullName = fullName,
		name = name,
		realm = realm,
		level = getMaxLevel(),
		class = classFile,
		classFile = classFile,
		specID = specID,
		specName = specName,
		roles = Util.CopyRoles(template.roles, specRole),
		role = template.role or specRole,
		specRole = specRole,
		rating = rating,
		ratingSeasonID = ratingSeasonID,
		ratingState = template.ratingMode == "unknown" and "unknown" or "ready",
		keyLevel = hasReadyKey and tonumber(template.keyLevel) or nil,
		challengeModeID = hasReadyKey and rawChallengeModeID or nil,
		mapID = hasReadyKey and dungeon and tonumber(dungeon.mapID) or nil,
		dungeonName = hasReadyKey and dungeon and dungeon.name or nil,
		activityID = hasReadyKey and dungeon and tonumber(dungeon.activityID) or nil,
		groupID = hasReadyKey and dungeon and tonumber(dungeon.groupID) or nil,
		keyUpgradeTrack = hasReadyKey and template.keyUpgradeTrack or nil,
		keyState = keyMode,
		keystoneKnown = keyMode ~= "unknown",
		hasKeystone = hasReadyKey,
		isCurrent = template.isCurrent == true,
		carpoolEnabled = template.carpoolEnabled ~= false,
		connected = template.connected ~= false,
		isRosterOnly = template.isRosterOnly == true,
		source = "test",
		isTest = true,
		isDebugTest = true,
		debugActionPreview = source == "roster",
		debugKeystonePayload = hasReadyKey
			and (template.debugKeystonePayload or "plain") or nil,
		debugSource = source,
		debugCase = string.format(
			"%s/%s/%s",
			source,
			keyMode,
			template.ratingMode == "unknown" and "rating-unknown" or "rating-ready"
		),
		updatedAt = timestamp,
		lastSeen = timestamp,
		lastKeyCheckedAt = keyMode ~= "unknown" and timestamp or nil,
		lastKeySeenAt = hasReadyKey and timestamp or nil,
		keyObservedAt = keyMode ~= "unknown" and timestamp or nil,
	}
	if template.bestRunCount ~= nil then
		character.bestRuns = buildBestRuns(template, dungeons, ordinal or 1)
	end
	return character
end

function Service:AddListener(callback)
	if Util and Util.AddListener then
		Util.AddListener(self, callback)
	end
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	if GF.MythicPlusSeason and GF.MythicPlusSeason.AddListener then
		GF.MythicPlusSeason:AddListener(function()
			if Service.enabled then
				Service:Rebuild("debug-season")
			end
		end)
	end
end

function Service:IsEnabled()
	return self.enabled == true
end

function Service:GetStatus()
	return {
		enabled = self.enabled == true,
		localCharacters = #(self.localCharacters or {}),
		rosterMembers = #(self.rosterMembers or {}),
		carpoolGroups = #(self.carpoolGroups or {}),
	}
end

function Service:GetLocalCharacters()
	return self.localCharacters or {}
end

function Service:GetRosterMembers()
	return self.rosterMembers or {}
end

function Service:GetCarpoolGroups()
	return self.carpoolGroups or {}
end

function Service:Rebuild(reason)
	if not self.enabled then
		return false
	end
	local realm = getRealm()
	local dungeons = getSeasonDungeons()
	local ordinal = 0
	local localCharacters = {}
	local localByKey = {}
	for _, template in ipairs(LOCAL_CHARACTER_TEMPLATES) do
		ordinal = ordinal + 1
		local character = buildCharacter(
			template, realm, dungeons, "local", ordinal)
		localCharacters[#localCharacters + 1] = character
		localByKey[character.key] = character
	end

	local rosterMembers = {}
	for index, template in ipairs(ROSTER_MEMBER_TEMPLATES) do
		ordinal = ordinal + 1
		local character = buildCharacter(
			template, realm, dungeons, "roster", ordinal)
		character.rosterIndex = 1000 + index
		rosterMembers[#rosterMembers + 1] = character
	end

	local carpoolGroups = {}
	for groupIndex = 1, self.additionalGroupCount or 0 do
		local template = CARPOOL_GROUP_TEMPLATES[groupIndex]
		if template then
			local ownerName = fixtureText(
				"names",
				template.ownerKey,
				template.owner or template.ownerKey or "TestOwner"
			)
			local warbandTag = fixtureText(
				"warbands",
				template.warbandKey,
				template.warbandTag or template.warbandKey or "Test Warband"
			)
			local ownerFullName = string.format("%s-%s", ownerName, realm)
			local group = {
				ownerKey = ownerFullName,
				ownerFullName = ownerFullName,
				ownerName = ownerName,
				ownerClass = template.ownerClass,
				warbandTag = warbandTag,
				characters = {},
				source = "test",
				isTest = true,
			}
			for _, characterTemplate in ipairs(template.characters) do
				ordinal = ordinal + 1
				local character = buildCharacter(
					characterTemplate,
					realm,
					dungeons,
					"carpool",
					ordinal
				)
				character.ownerKey = ownerFullName
				character.ownerName = ownerName
				character.warbandSourceName = warbandTag
				group.characters[#group.characters + 1] = character
			end
			carpoolGroups[#carpoolGroups + 1] = group
		end
	end

	self.localCharacters = localCharacters
	self.localByKey = localByKey
	self.rosterMembers = rosterMembers
	self.carpoolGroups = carpoolGroups
	self.updatedAt = now()
	notify(reason or "debug-data")
	return true
end

function Service:Enable(additionalGroupCount)
	self.enabled = true
	if additionalGroupCount == nil then
		additionalGroupCount = 3
	end
	self.additionalGroupCount = math.max(0, math.min(3,
		math.floor(tonumber(additionalGroupCount) or 0)))
	self:Rebuild("debug-data-enabled")
	local L = GF.L or {}
	showStatus(string.format(
		L.MPLUS_DEBUG_TEST_ENABLED_FMT
			or "大秘境临时测试数据已启用：角色 %d、队伍成员 %d、车队 %d 组。",
		#(self.localCharacters or {}),
		#(self.rosterMembers or {}),
		#(self.carpoolGroups or {})
	))
	return true
end

function Service:Disable()
	self.enabled = false
	self.additionalGroupCount = nil
	self.localCharacters = nil
	self.localByKey = nil
	self.rosterMembers = nil
	self.carpoolGroups = nil
	self.updatedAt = now()
	notify("debug-data-disabled")
	showStatus((GF.L and GF.L.MPLUS_DEBUG_TEST_DISABLED)
		or "大秘境临时测试数据已清理。")
	return true
end

function Service:SetLocalRole(key, roleKey, enabled)
	local character = self.localByKey and self.localByKey[key]
	if not (character and (roleKey == "TANK" or roleKey == "HEAL" or roleKey == "DPS")) then
		return false
	end
	local roles = character.roles or {}
	local newValue = enabled == true
	if (roles[roleKey] == true) == newValue then
		return false
	end
	if not newValue then
		local remaining = 0
		for currentRole, selected in pairs(roles) do
			if currentRole ~= roleKey and selected == true then
				remaining = remaining + 1
			end
		end
		if remaining == 0 then
			return false
		end
	end
	roles[roleKey] = newValue and true or nil
	character.roles = roles
	character.updatedAt = now()
	notify("debug-role")
	return true
end

function Service:SetLocalCarpoolEnabled(key, enabled)
	local character = self.localByKey and self.localByKey[key]
	if not character then
		return false
	end
	local newValue = enabled == true
	if character.carpoolEnabled == newValue then
		return false
	end
	character.carpoolEnabled = newValue
	character.updatedAt = now()
	notify("debug-carpool")
	return true
end

local function trimText(value)
	value = tostring(value or "")
	if strtrim then
		return strtrim(value)
	end
	return value:match("^%s*(.-)%s*$") or value
end

local function findSeasonDungeonByID(dungeons, mapID)
	for _, dungeon in ipairs(dungeons or {}) do
		if tonumber(dungeon.challengeModeID) == mapID
			or tonumber(dungeon.mapID) == mapID
		then
			return dungeon
		end
	end
	return nil
end

local function resolveTeleportPreview(payload)
	local raw = trimText(payload)
	local requestedID
	if raw ~= "" then
		requestedID = tonumber(raw)
		if not requestedID
			or requestedID <= 0
			or requestedID ~= math.floor(requestedID)
		then
			return nil, "invalid-id"
		end
	end

	local teleport = GF.MythicPlusTeleportService
	local season = GF.MythicPlusSeason
	local dungeons = season and season.GetDungeons
		and season:GetDungeons() or {}
	local entry
	local dungeon
		if requestedID then
			entry = teleport and teleport.GetByMapID
				and teleport:GetByMapID(requestedID) or nil
			dungeon = entry and entry.dungeon
				or findSeasonDungeonByID(dungeons, requestedID)
			dungeon = dungeon or {
				challengeModeID = requestedID,
				mapID = requestedID,
				name = tostring(requestedID),
			}
	else
		for _, candidate in ipairs(teleport and teleport.entries or {}) do
			if type(candidate.dungeon) == "table" then
				entry = candidate
				dungeon = candidate.dungeon
				break
			end
		end
		dungeon = dungeon or dungeons[1]
		if dungeon and not entry and teleport and teleport.GetByMapID then
			entry = teleport:GetByMapID(
				tonumber(dungeon.challengeModeID)
					or tonumber(dungeon.mapID))
		end
	end
	if type(dungeon) ~= "table" then
		return nil, "no-cache"
	end

	local current = GF.MythicPlusCharacterStore
		and GF.MythicPlusCharacterStore.GetCurrent
		and GF.MythicPlusCharacterStore:GetCurrent() or nil
	local L = GF.L or {}
	return {
		mapID = requestedID
			or tonumber(dungeon.challengeModeID)
			or tonumber(dungeon.mapID),
			dungeonName = dungeon.name or tostring(requestedID or "-"),
		senderName = current
			and (current.fullName or current.name)
			or L.MPLUS_CURRENT_CHARACTER
			or "Current Character",
			classFile = current and (current.classFile or current.class) or nil,
	}, nil
end

function Service:ShowTeleportDialogPreview(payload)
	local L = GF.L or {}
	local snapshot, reason = resolveTeleportPreview(payload)
	if not snapshot then
		if reason == "invalid-id" then
			showStatus(
				L.MPLUS_DEBUG_TELEPORT_PREVIEW_INVALID_ID
					or "请输入有效的 mapID。")
		else
			showStatus(
				L.MPLUS_DEBUG_TELEPORT_PREVIEW_NO_CACHE
					or "传送弹窗预览不可用：当前赛季暂无缓存的地下城数据。")
		end
		return false
	end

	local dialog = GF.MythicPlusTeleportDialog
	if not (dialog and dialog.ShowPreview) then
		showStatus(
			L.MPLUS_DEBUG_TELEPORT_PREVIEW_UNAVAILABLE
				or "传送弹窗预览模块尚未加载。")
		return false
	end
	local opened, openReason = dialog:ShowPreview(snapshot)
	if not opened then
		if openReason == "combat" then
			showStatus(
				L.MPLUS_DEBUG_TELEPORT_PREVIEW_COMBAT
					or "战斗中无法预览传送弹窗。")
		else
			showStatus(
				L.MPLUS_DEBUG_TELEPORT_PREVIEW_UNAVAILABLE
					or "传送弹窗预览模块尚未加载。")
		end
		return false
	end
	showStatus(string.format(
		L.MPLUS_DEBUG_TELEPORT_PREVIEW_OPENED_FMT
			or "传送弹窗预览已打开：%s（mapID=%s）。",
		tostring(snapshot.dungeonName or "-"),
		tostring(snapshot.mapID or "-")))
	return true
end

function Service:DumpTeleportDiagnostics()
	local teleport = GF.MythicPlusTeleportService
	local snapshot = teleport and teleport.GetDiagnosticSnapshot
		and teleport:GetDiagnosticSnapshot() or nil
	local entries = snapshot and snapshot.entries or {}
	local L = GF.L or {}
	if #entries == 0 then
		showStatus(L.MPLUS_DEBUG_TELEPORT_EMPTY
			or "英雄之路传送诊断暂无缓存数据。")
		return false
	end
	showStatus(string.format(
		L.MPLUS_DEBUG_TELEPORT_SUMMARY_FMT
			or "英雄之路传送诊断：当前赛季 %d 个地下城，缓存原因 %s。",
		#entries,
		tostring(snapshot.reason or "-")
	))
	for index, entry in ipairs(entries) do
		local mappingState = entry.spellID
			and (L.MPLUS_DEBUG_MAPPING_READY or "已映射")
			or (L.MPLUS_DEBUG_MAPPING_MISSING or "缺失映射")
		local learnedState
		local cooldownState
		if not entry.spellID then
			learnedState = L.MPLUS_DEBUG_UNKNOWN or "未知"
			cooldownState = L.MPLUS_DEBUG_UNKNOWN or "未知"
		else
			learnedState = entry.learned
				and (L.MPLUS_DEBUG_LEARNED or "已学习")
				or (L.MPLUS_DEBUG_NOT_LEARNED or "未学习")
			cooldownState = entry.onCooldown
				and (L.MPLUS_DEBUG_COOLDOWN or "冷却中")
				or (L.MPLUS_DEBUG_READY or "可用")
		end
		showStatus(string.format(
			L.MPLUS_DEBUG_TELEPORT_LINE_FMT
				or "#%02d %s | challengeModeID=%s | mapID=%s | spellID=%s | %s | %s | %s | macro=%s",
			index,
			tostring(entry.name or "-"),
			tostring(entry.challengeModeID or "-"),
			tostring(entry.mapID or "-"),
			tostring(entry.spellID or "-"),
			mappingState,
			learnedState,
			cooldownState,
			entry.macroReady
				and (L.MPLUS_DEBUG_YES or "是")
				or (L.MPLUS_DEBUG_NO or "否")
		))
	end
	return true
end
