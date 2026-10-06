local _, GF = ...

-- InstanceGateway is deliberately independent of the Mythic+ services.  It is
-- an entrance/lockout utility for every supported dungeon or raid, while the
-- Mythic+ workspace continues to own keystones and seasonal actions.
GF.InstanceGatewayService = GF.InstanceGatewayService or {}
local Service = GF.InstanceGatewayService

local SCAN_INTERVAL = 0.5
local FAR_SCAN_INTERVAL = 1
local PORTAL_READ_RETRY_LIMIT = 5
local HIDDEN_SNAPSHOT = { kind = "hidden" }
local MAP_EVENTS = {
	PLAYER_ENTERING_WORLD = true, PLAYER_MAP_CHANGED = true,
	ZONE_CHANGED = true, ZONE_CHANGED_NEW_AREA = true,
	ZONE_CHANGED_INDOORS = true, NEW_WMO_CHUNK = true,
	LOADING_SCREEN_DISABLED = true,
}
local STATUS_EVENTS = {
	"UPDATE_INSTANCE_INFO", "PLAYER_DIFFICULTY_CHANGED", "ENCOUNTER_END",
	"GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED",
}
local ENTRANCE_RANGE_YARDS = 32
-- Independent 2026-10-02 player capture at the Vault portal. Apply only to
-- this map/Journal pair while Blizzard still reports the captured bad pin;
-- a changed native pin automatically retires the correction. Never mutate
-- API-owned entrance records or add an entrance missing from the native list.
local ENTRANCE_POSITION_CORRECTIONS = {
	[2025] = {
		[1200] = { pinX = 0.74850535392761, pinY = 0.55114412307739,
			x = 0.72755181789398, y = 0.5595036149025 },
	},
}
local CORRECTION_PIN_TOLERANCE = 0.00001
-- Entrance-location facts from Plumber 1.9.6 b, accepted by the user on
-- 2026-10-02. GroupFinder owns the lookup, API guards and distance checks;
-- no Plumber module is loaded or required. The Vault keeps the user's capture.
local REFERENCE_ENTRANCE_LOCATIONS = {
	[74] = { x = 0.38465, y = 0.80562 },
	[75] = { x = 0.47643, y = 0.51756 },
	[184] = { x = 0.57381, y = 0.29142 },
	[187] = { x = 0.61534, y = 0.26397 },
	[251] = { x = 0.26814, y = 0.35114 },
	[255] = { x = 0.35972, y = 0.83893 },
	[279] = { x = 0.57488, y = 0.82711 },
	[285] = { x = 0.57287, y = 0.46811, indoors = true },
	[286] = { x = 0.57252, y = 0.46620, indoors = false },
	[726] = { x = 0.41068, y = 0.61744, indoors = true },
	[750] = { x = 0.35528, y = 0.15325 },
	[786] = { x = 0.44148, y = 0.59743, indoors = true },
	[1023] = { factions = {
		Alliance = { x = 0.71979, y = 0.15423 },
		Horde = { x = 0.88284, y = 0.51036 },
	} },
	[1304] = { x = 0.56979, y = 0.61049, indoors = false },
	[1317] = { x = 0.59800, y = 0.66200, uiMapID = 2512 },
}
-- Known missing markers are scoped to their entrance map. If Blizzard supplies
-- the Journal identity, retain that native marker instead of adding another.
local SUPPLEMENTAL_ENTRANCES = {
	[1528] = { journalInstanceID = 1179,
		position = { x = 0.47607, y = 0.32849 } }, -- Eternal Palace entrance.
	[2512] = { journalInstanceID = 1317,
		position = REFERENCE_ENTRANCE_LOCATIONS[1317] },
}
local POSITION_CHECK_SECONDS = 10
local POSITION_ERROR_YARDS = 0.25
local MAP_ORIGIN = { x = 0, y = 0 }
local MAP_X_AXIS = { x = 1, y = 0 }
local MAP_Y_AXIS = { x = 0, y = 1 }
local ARRIVAL_DELAY = 0.45
local ARRIVAL_SECONDS = 4
local INSIDE_READ_RETRY_DELAY = 0.5
local INSIDE_READ_RETRY_LIMIT = 20
-- A loading transition can briefly report both IsInInstance() == false and a
-- GetInstanceInfo() ``none`` / 0 placeholder.  Wait one normal outside scan
-- before treating that combination as a real departure, so the next readable
-- party/raid snapshot keeps the original arrival token.
local OUTSIDE_DEPARTURE_CONFIRM_SECONDS = SCAN_INTERVAL

local function finite(value)
	value = tonumber(value)
	if value == nil or value ~= value or value == math.huge
		or value == -math.huge
	then
		return nil
	end
	return value
end

local function safeCall(callback, ...)
	if type(callback) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n = pcall(callback, ...)
	if not ok then
		return nil
	end
	return a, b, c, d, e, f, g, h, i, j, k, l, m, n
end

local function tryCall(callback, ...)
	if type(callback) ~= "function" then
		return false, nil
	end
	return pcall(callback, ...)
end

local function copyBosses(bosses)
	if type(bosses) ~= "table" then
		return nil
	end
	local copied = {}
	for index, boss in ipairs(bosses) do
		copied[index] = {
			name = boss.name,
			defeated = boss.defeated,
		}
	end
	return copied
end

local function copyOption(option)
	return {
		difficultyID = option.difficultyID,
		name = option.name,
		done = option.done,
		total = option.total,
		progressReady = option.progressReady == true,
		selected = option.selected == true,
		enabled = option.enabled == true,
		disabledReason = option.disabledReason,
		legacy = option.legacy == true,
		playerCount = option.playerCount,
		canShareProgress = option.canShareProgress == true,
		bosses = copyBosses(option.bosses),
	}
end

local function copySnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return { kind = "hidden" }
	end
	local copied = {}
	for key, value in pairs(snapshot) do
		if key ~= "options" and key ~= "savedProgress" then
			copied[key] = value
		end
	end
	copied.options = {}
	for index, option in ipairs(snapshot.options or {}) do
		copied.options[index] = copyOption(option)
	end
	if snapshot.savedProgress then
		copied.savedProgress = { ready = snapshot.savedProgress.ready, entries = {},
			legacyLockoutState = snapshot.savedProgress.legacyLockoutState,
			legacyLockedDifficultyID = snapshot.savedProgress.legacyLockedDifficultyID }
		for index, entry in ipairs(snapshot.savedProgress.entries) do
			copied.savedProgress.entries[index] = {
				difficultyID = entry.difficultyID, name = entry.name,
				playerCount = entry.playerCount, done = entry.done, total = entry.total,
				extended = entry.extended, expiresAt = entry.expiresAt,
			}
		end
	end
	return copied
end

-- Only compare public data. Encounter IDs stay in Core and are deliberately
-- absent from listener copies. Unchanged publications allocate no new copy.
local PRIVATE_PROJECTION_KEYS = { encounters = true, index = true, revision = true,
	lockID = true, mostSig = true }
local function sameProjection(a, b)
	if a == b then return true end
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for key, value in pairs(a) do
		if not PRIVATE_PROJECTION_KEYS[key] and not sameProjection(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if not PRIVATE_PROJECTION_KEYS[key] and a[key] == nil then return false end
	end
	return true
end

local function getDatabase()
	return GF.GetDB and GF.GetDB() or GF.db
end

local function extractXY(value, second)
	local x = finite(value)
	local y = finite(second)
	if x and y then
		return x, y
	end
	if value and type(value.GetXY) == "function" then
		local pointX, pointY = safeCall(value.GetXY, value)
		return finite(pointX), finite(pointY)
	end
	if type(value) == "table" then
		return finite(value.x), finite(value.y)
	end
	return nil, nil
end

-- UnitPosition may be restricted. Never compare or calculate with a secret,
-- and keep these readers scalar-only on the frequent outside scan path.
local function publicNumber(value)
	if issecretvalue and issecretvalue(value) then return nil end
	if type(value) ~= "number" then return nil end
	return finite(value)
end

local function readPublicPoint(point)
	if issecretvalue and issecretvalue(point) then return nil end
	if type(point) ~= "table" and type(point) ~= "userdata" then return nil end
	return publicNumber(point.x), publicNumber(point.y)
end

local function readNativePosition(cache)
	-- MapDocumentation.lua: (uiMapID, unitToken), not the inverse order.
	local point = safeCall(C_Map.GetPlayerMapPosition, cache.uiMapID, "player")
	return safeCall(readPublicPoint, point)
end

local function readWorldPoint(uiMapID, point)
	local world, position = safeCall(C_Map.GetWorldPosFromMapPos, uiMapID, point)
	local x, y = safeCall(readPublicPoint, position)
	return publicNumber(world), x, y
end

local function buildPositionTransform(cache)
	-- Three official samples define the map's affine basis without assuming
	-- axis order, sign or orientation. Only the current entrance map owns it.
	local world, ox, oy = readWorldPoint(cache.uiMapID, MAP_ORIGIN)
	local xWorld, xx, xy = readWorldPoint(cache.uiMapID, MAP_X_AXIS)
	local yWorld, yx, yy = readWorldPoint(cache.uiMapID, MAP_Y_AXIS)
	if not (world and world == xWorld and world == yWorld
		and ox and oy and xx and xy and yx and yy) then return nil end
	xx, xy, yx, yy = xx - ox, xy - oy, yx - ox, yy - oy
	local determinant = publicNumber(xx * yy - xy * yx)
	if not determinant or math.abs(determinant) < 0.000001 then return nil end
	return { world = world, ox = ox, oy = oy,
		xx = yy / determinant, xy = -yx / determinant,
		yx = -xy / determinant, yy = xx / determinant }
end

local function positionMatches(cache, x, y, nativeX, nativeY)
	if not (nativeX and nativeY) then return false end
	local dx, dy = (x - nativeX) * cache.width, (y - nativeY) * cache.height
	return dx * dx + dy * dy <= POSITION_ERROR_YARDS ^ 2
end

local function readPlayerPosition(cache)
	if type(UnitPosition) ~= "function"
		or type(C_Map.GetWorldPosFromMapPos) ~= "function"
	then return readNativePosition(cache) end
	local now = finite(safeCall(GetTime)) or 0
	local wx, wy, wz, world = safeCall(UnitPosition, "player")
	wx, wy, wz, world = publicNumber(wx), publicNumber(wy), publicNumber(wz), publicNumber(world)
	if not (wx and wy and wz and world) then
		cache.positionTransform = nil
		return readNativePosition(cache)
	end
	local transform = cache.positionTransform
	if transform and transform.world ~= world then
		cache.positionTransform, cache.positionRetryAt = nil, nil
		transform = nil
	end
	if not transform then
		if cache.positionRetryAt and now < cache.positionRetryAt then
			return readNativePosition(cache)
		end
		cache.positionRetryAt = now + POSITION_CHECK_SECONDS
		transform = buildPositionTransform(cache)
		if not transform or transform.world ~= world then return readNativePosition(cache) end
		cache.positionTransform = transform
	end
	local dx, dy = wx - transform.ox, wy - transform.oy
	local x = publicNumber(transform.xx * dx + transform.xy * dy)
	local y = publicNumber(transform.yx * dx + transform.yy * dy)
	if not (x and y) or x < 0 or x > 1 or y < 0 or y > 1 then
		cache.positionTransform = nil
		return readNativePosition(cache)
	end
	-- Recheck periodically, after a large displacement or a vertical change.
	-- Map/floor/loading/settings events also discard the entire entrance cache.
	local moved = transform.x and (((x - transform.x) * cache.width) ^ 2
		+ ((y - transform.y) * cache.height) ^ 2 > 128 ^ 2
		or math.abs(wz - transform.z) > 16)
	transform.x, transform.y, transform.z = x, y, wz
	if not transform.checkAt or now >= transform.checkAt or moved then
		local nativeX, nativeY = readNativePosition(cache)
		if positionMatches(cache, x, y, nativeX, nativeY) then
			transform.checkAt = now + POSITION_CHECK_SECONDS
		else
			cache.positionTransform = nil
			cache.positionRetryAt = now + POSITION_CHECK_SECONDS
		end
		return nativeX, nativeY
	end
	return x, y, true
end

local function prepareEntranceList(uiMapID, nativeEntrances)
	local supplemental = SUPPLEMENTAL_ENTRANCES[uiMapID]
	local hasIndoors, hasFaction, hasSupplemental = false, false, false
	for _, entrance in ipairs(nativeEntrances) do
		local id = finite(entrance and entrance.journalInstanceID)
		local location = REFERENCE_ENTRANCE_LOCATIONS[id]
		if location then
			hasIndoors = hasIndoors or location.indoors ~= nil
			hasFaction = hasFaction or location.factions ~= nil
		end
		hasSupplemental = hasSupplemental or (supplemental and id == supplemental.journalInstanceID)
	end
	local entrances = nativeEntrances
	if supplemental and not hasSupplemental then
		-- Only known missing markers are supplemented. Copy the array before
		-- appending; Blizzard retains ownership of its list and native records.
		entrances = {}
		for index, entrance in ipairs(nativeEntrances) do entrances[index] = entrance end
		local location = supplemental.position
		entrances[#entrances + 1] = { journalInstanceID = supplemental.journalInstanceID,
			position = { x = location.x, y = location.y } }
	end
	return entrances, hasIndoors, hasFaction
end

local function readEntranceEnvironment(cache)
	local indoors, faction
	if cache.hasIndoorEntrances then
		local value = safeCall(IsIndoors)
		if not (issecretvalue and issecretvalue(value)) and type(value) == "boolean" then
			indoors = value
		end
	end
	if cache.hasFactionEntrances then
		local value = safeCall(UnitFactionGroup, "player")
		if not (issecretvalue and issecretvalue(value)) and type(value) == "string"
			and (value == "Alliance" or value == "Horde") then
			faction = value
		end
	end
	return indoors, faction
end

local function getEntrancePosition(cache, entrance, indoors, faction)
	local entranceX, entranceY = extractXY(entrance and entrance.position)
	local journalInstanceID = finite(entrance and entrance.journalInstanceID)
	if not (entranceX and entranceY and journalInstanceID) then return nil end
	local location = REFERENCE_ENTRANCE_LOCATIONS[journalInstanceID]
	if location and (not location.uiMapID or location.uiMapID == cache.uiMapID) then
		if location.factions then
			location = location.factions[faction]
			if not location then return nil end
		end
		-- false means outdoors, while nil means no indoor/outdoor restriction.
		-- Unknown/restricted values cannot select either of a nearby pair.
		if location.indoors ~= nil and location.indoors ~= indoors then return nil end
		return location.x, location.y
	end
	local corrections = ENTRANCE_POSITION_CORRECTIONS[cache.uiMapID]
	local correction = corrections and corrections[journalInstanceID]
	if correction and math.abs(entranceX - correction.pinX) <= CORRECTION_PIN_TOLERANCE
		and math.abs(entranceY - correction.pinY) <= CORRECTION_PIN_TOLERANCE then
		return correction.x, correction.y
	end
	return entranceX, entranceY
end

local function findClosestEntrance(cache, playerX, playerY, indoors, faction)
	local closest, closestDistance
	for _, entrance in ipairs(cache.entrances) do
		local entranceX, entranceY = getEntrancePosition(cache, entrance, indoors, faction)
		if entranceX and entranceY then
			local distanceX = cache.width * (playerX - entranceX)
			local distanceY = cache.height * (playerY - entranceY)
			local distance = distanceX * distanceX + distanceY * distanceY
			if not closestDistance or distance < closestDistance then
				closest, closestDistance = entrance, distance
			end
		end
	end
	return closest, closestDistance
end

local function getDifficultyIDs(isRaid)
	local ids = DifficultyUtil and DifficultyUtil.ID or {}
	if isRaid then
		-- The first three are the same set exposed by Blizzard's current raid
		-- difficulty menu.  Legacy values are retained only when the Encounter
		-- Journal proves that the entrance actually supports them.
		return {
			ids.PrimaryRaidNormal or 14,
			ids.PrimaryRaidHeroic or 15,
			ids.PrimaryRaidMythic or 16,
			ids.RaidTimewalker or 33,
			ids.Raid10Normal or 3,
			ids.Raid10Heroic or 5,
			ids.Raid25Normal or 4,
			ids.Raid25Heroic or 6,
			ids.Raid40 or 9,
			-- RaidWorld is a journal status difficulty used by a few special
			-- encounters.  It is deliberately display-only: it has no player
			-- selectable difficulty setter.
			ids.RaidWorld or 250,
		}
	end
	return {
		ids.DungeonNormal or 1,
		ids.DungeonHeroic or 2,
		ids.DungeonMythic or 23,
	}
end

local function isJournalVisible()
	local journal = _G.EncounterJournal
	return journal and safeCall(journal.IsShown, journal) ~= false
end

local function isInInstance()
	local inside = safeCall(IsInInstance)
	return inside == true
end

local function getDifficultyName(difficultyID)
	local name = safeCall(GetDifficultyInfo, difficultyID)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return DifficultyUtil and DifficultyUtil.GetDifficultyName
		and DifficultyUtil.GetDifficultyName(difficultyID)
		or tostring(difficultyID)
end

local function isPrimaryRaidDifficulty(difficultyID)
	if DifficultyUtil and type(DifficultyUtil.IsPrimaryRaid) == "function" then
		return safeCall(DifficultyUtil.IsPrimaryRaid, difficultyID) == true
	end
	local ids = DifficultyUtil and DifficultyUtil.ID or {}
	return difficultyID == (ids.PrimaryRaidNormal or 14)
		or difficultyID == (ids.PrimaryRaidHeroic or 15)
		or difficultyID == (ids.PrimaryRaidMythic or 16)
end

local function isRaidTimewalkingDifficulty(difficultyID)
	local ids = DifficultyUtil and DifficultyUtil.ID or {}
	return difficultyID == (ids.RaidTimewalker or 33)
end

local function isRaidWorldDifficulty(difficultyID)
	local ids = DifficultyUtil and DifficultyUtil.ID or {}
	return difficultyID == (ids.RaidWorld or 250)
end

local function getDifficultyDetails(difficultyID, isRaid)
	local name, _, _, _, _, _, _, _, _, maxPlayers = safeCall(
		GetDifficultyInfo, difficultyID)
	-- Blizzard's display names omit legacy raid sizes ("Normal" / "Heroic").
	-- The view adds the authoritative player count once, outside this name.
	local displayName = DifficultyUtil
		and safeCall(DifficultyUtil.GetDifficultyName, difficultyID)
	if type(displayName) == "string" and displayName ~= "" then
		name = displayName
	elseif type(name) ~= "string" or name == "" then
		name = getDifficultyName(difficultyID)
	end
	-- Match the current Blizzard Encounter Journal: primary flexible raids and
	-- raid Timewalking intentionally omit a fixed player cap; fixed dungeons and
	-- legacy raids retain it.  GetBaseDifficultyID avoids treating a derived
	-- difficulty as a different kind of raid merely because it has a new ID.
	local baseDifficultyID = C_EncounterJournal
		and safeCall(C_EncounterJournal.GetBaseDifficultyID, difficultyID)
		or difficultyID
	if not finite(baseDifficultyID) then
		baseDifficultyID = difficultyID
	end
	local playerCount
	if not (isRaid and (isPrimaryRaidDifficulty(baseDifficultyID)
		or isRaidTimewalkingDifficulty(baseDifficultyID)
		or isRaidWorldDifficulty(baseDifficultyID)))
	then
		playerCount = DifficultyUtil and type(DifficultyUtil.GetMaxPlayers) == "function"
			and finite(safeCall(DifficultyUtil.GetMaxPlayers, difficultyID))
			or finite(maxPlayers)
	end
	return name, playerCount
end

local function isJournalDifficultySupported(difficultyID)
	-- EJ_IsValidInstanceDifficulty uses an old bit mask on some Retail builds;
	-- its representable range does not cover every modern difficulty ID.  The
	-- current Blizzard Encounter Journal explicitly uses InstanceHasDifficultyID
	-- for those entries instead of guessing from the legacy bit mask.
	if difficultyID > 64 then
		local journal = C_EncounterJournal
		return journal and type(journal.InstanceHasDifficultyID) == "function"
			and safeCall(journal.InstanceHasDifficultyID, difficultyID) == true
	end
	return safeCall(EJ_IsValidInstanceDifficulty, difficultyID) == true
end

local journalReadActive = false
local JOURNAL_DIFFICULTY_EVENT = "EJ_DIFFICULTY_UPDATE"
local JOURNAL_LOOT_EVENT = "EJ_LOOT_DATA_RECIEVED"

local function restoreJournalEvent(frame, event, wasRegistered)
	if not wasRegistered then return true end
	-- A failed registration must not prevent the other event being restored.
	-- Verify the state even if a hook throws after the native call succeeded.
	for attempt = 1, 2 do
		if safeCall(frame.IsEventRegistered, frame, event) == true then return true end
		tryCall(frame.RegisterEvent, frame, event)
	end
	return safeCall(frame.IsEventRegistered, frame, event) == true
end

local function withJournalRead(read, ...)
	if journalReadActive or isJournalVisible() or not (EJ_GetEncounterInfoByIndex
		and EJ_GetEncounterInfo and EJ_SelectInstance and EJ_IsValidInstanceDifficulty
		and EJ_SetDifficulty and EJ_GetDifficulty)
	then
		return nil
	end
	-- Snapshot before any EJ write. These are Blizzard's own remembered browse
	-- IDs, not a guessed current instance derived from a map/name. An unloaded
	-- Journal has no UI selection to restore; its previous difficulty still does.
	local frame = _G.EncounterJournal
	local previousDifficulty = finite(safeCall(EJ_GetDifficulty))
	if not previousDifficulty then return nil end
	local previousInstance = frame and finite(frame.instanceID)
	local previousEncounter = frame and finite(frame.encounterID)
	if previousEncounter and (not previousInstance or not EJ_SelectEncounter) then return nil end
	local difficultyEvent, lootEvent
	if frame then
		if not (frame.RegisterEvent and frame.UnregisterEvent) then return nil end
		difficultyEvent = safeCall(frame.IsEventRegistered, frame, JOURNAL_DIFFICULTY_EVENT)
		lootEvent = safeCall(frame.IsEventRegistered, frame, JOURNAL_LOOT_EVENT)
		if type(difficultyEvent) ~= "boolean" or type(lootEvent) ~= "boolean" then return nil end
	end
	journalReadActive = true
	local paused = true
	if difficultyEvent then
		paused = tryCall(frame.UnregisterEvent, frame, JOURNAL_DIFFICULTY_EVENT)
			and safeCall(frame.IsEventRegistered, frame, JOURNAL_DIFFICULTY_EVENT) == false
	end
	if paused and lootEvent then
		paused = tryCall(frame.UnregisterEvent, frame, JOURNAL_LOOT_EVENT)
			and safeCall(frame.IsEventRegistered, frame, JOURNAL_LOOT_EVENT) == false
	end
	local ok, result = false, nil
	if paused then ok, result = pcall(read, ...) end
	local restored = true
	if paused then
		if previousInstance then
			restored = tryCall(EJ_SelectInstance, previousInstance)
		end
		if safeCall(EJ_GetDifficulty) ~= previousDifficulty then
			local changed = tryCall(EJ_SetDifficulty, previousDifficulty)
			restored = changed and restored
		end
		if previousEncounter then
			local selected = tryCall(EJ_SelectEncounter, previousEncounter)
			restored = selected and restored
		end
		restored = safeCall(EJ_GetDifficulty) == previousDifficulty and restored
	end
	-- Both generated EJ events are synchronous. Finish restoration before
	-- returning to the caller; no extra frame, timer or next-frame closure.
	local difficultyRestored = restoreJournalEvent(frame, JOURNAL_DIFFICULTY_EVENT, difficultyEvent)
	local lootRestored = restoreJournalEvent(frame, JOURNAL_LOOT_EVENT, lootEvent)
	journalReadActive = false
	if ok and restored and difficultyRestored and lootRestored then return result end
	return nil
end

local function readJournalEncounters(journalInstanceID, difficultyID)
	-- The Encounter Journal's difficulty validity and encounter list are both
	-- scoped to its selected instance.  Retail's own difficulty menu first
	-- selects that instance before asking EJ_IsValidInstanceDifficulty; merely
	-- calling EJ_SetDifficulty here could otherwise reuse whichever instance
	-- another UI last selected.  This is a journal data selection only, never a
	-- game difficulty change.  Missing any part of this validation chain is a
	-- failed read, not permission to infer support from an old Journal context.
	local selected = tryCall(EJ_SelectInstance, journalInstanceID)
	if selected ~= true then
		return nil
	end
	if not isJournalDifficultySupported(difficultyID) then
		return nil
	end
	if safeCall(EJ_GetDifficulty) ~= difficultyID
		and not tryCall(EJ_SetDifficulty, difficultyID) then
		return nil
	end
	if safeCall(EJ_GetDifficulty) ~= difficultyID then return nil end
	local encounters = {}
	local valid = true
	for index = 1, 65 do
		local readable, name, _, journalEncounterID = tryCall(
			EJ_GetEncounterInfoByIndex, index, journalInstanceID)
		if not readable then return nil end
		if not journalEncounterID then
			break
		end
		if index > 64 then return nil end
		local encounterName, _, _, _, _, owningInstanceID, dungeonEncounterID, mapID = safeCall(
			EJ_GetEncounterInfo, journalEncounterID)
		local resolvedName = type(encounterName) == "string" and encounterName
			or (type(name) == "string" and name or nil)
		dungeonEncounterID = finite(dungeonEncounterID)
		mapID = finite(mapID)
		-- A partial Journal record must not become a fabricated 0/N progress
		-- display.  C_RaidLocks needs both native IDs; fail closed until the
		-- actual instance data is available.
		if type(resolvedName) ~= "string" or resolvedName == ""
			or finite(owningInstanceID) ~= journalInstanceID
			or not dungeonEncounterID or dungeonEncounterID <= 0
			or not mapID or mapID <= 0
		then
			valid = false
			break
		end
		encounters[#encounters + 1] = {
			name = resolvedName,
			dungeonEncounterID = dungeonEncounterID,
			mapID = mapID,
		}
	end
	return valid and #encounters > 0 and safeCall(EJ_GetDifficulty) == difficultyID
		and encounters or nil
end

local function getJournalEncounters(journalInstanceID, difficultyID)
	return withJournalRead(readJournalEncounters, journalInstanceID, difficultyID)
end

-- Static catalogs outlive searches, result IDs, map changes and overlay
-- settings. Never put a player's lockout or a group's kill state here.
local encounterCatalogs = {}

local function positiveCatalogID(value)
	value = publicNumber(value)
	return value and value > 0 and value == math.floor(value) and value or nil
end

local function copyEncounterCatalog(encounters)
	local copied, seen = {}, {}
	for index, encounter in ipairs(encounters) do
		local id = positiveCatalogID(encounter.dungeonEncounterID)
		local mapID = positiveCatalogID(encounter.mapID)
		local name = encounter.name
		if not id or not mapID or seen[id] or index > 64
			or (issecretvalue and issecretvalue(name))
			or type(name) ~= "string" or name == "" then return nil end
		seen[id] = true
		copied[index] = { name = name, dungeonEncounterID = id, mapID = mapID }
	end
	return #copied > 0 and copied or nil
end

-- Static metadata only: browse results supply their own remote kill counts.
-- Reuse the guarded Journal transaction without reading the player's lockout
-- or requiring the entrance overlay to be enabled.
function Service:GetEncounterCatalog(mapID, difficultyID)
	mapID, difficultyID = positiveCatalogID(mapID), positiveCatalogID(difficultyID)
	if not mapID or not difficultyID then return nil end
	local key = tostring(mapID) .. ":" .. tostring(difficultyID)
	local record = encounterCatalogs[key]
	if record and record.encounters then
		-- Callers may retain/mutate their own projection, never the master copy.
		return copyEncounterCatalog(record.encounters)
	end
	local now = GetTime and GetTime() or 0
	if record and now < record.retryAt then return nil, record.retryAt - now end
	local journalInstanceID = C_EncounterJournal and positiveCatalogID(
		safeCall(C_EncounterJournal.GetInstanceForGameMap, mapID))
	local encounters = journalInstanceID and getJournalEncounters(journalInstanceID, difficultyID)
	local validated = encounters and copyEncounterCatalog(encounters)
	if validated then
		encounterCatalogs[key] = { encounters = validated }
		return encounters
	end
	local failures = math.min((record and record.failures or 0) + 1, 4)
	local delay = 2 ^ (failures - 1)
	encounterCatalogs[key] = { failures = failures, retryAt = now + delay }
	return nil, delay
end

function Service:GetEncounterCount(mapID, difficultyID)
	local encounters = self:GetEncounterCatalog(mapID, difficultyID)
	return encounters and #encounters or nil
end

local function makeUnknownBosses(encounters)
	if type(encounters) ~= "table" then
		return nil
	end
	local bosses = {}
	for index, encounter in ipairs(encounters) do
		bosses[index] = {
			name = encounter.name,
			-- Keep the nil state rather than converting it to false: the Tooltip
			-- must distinguish lockout data not yet readable from a living boss.
			defeated = nil,
		}
	end
	return bosses
end

local function collectProgress(encounters, difficultyID, lockoutsReady)
	if type(encounters) ~= "table" or #encounters == 0 then
		return nil, nil, false
	end
	-- C_RaidLocks.IsEncounterComplete only returns a bool.  Until the
	-- RequestRaidInfo -> UPDATE_INSTANCE_INFO cycle completes, a batch of
	-- false values cannot prove a real 0/N lockout instead of unloaded data.
	if lockoutsReady ~= true then
		return nil, #encounters, false, makeUnknownBosses(encounters)
	end
	local complete = 0
	local bosses = {}
	for index = 1, #encounters do
		local encounter = encounters[index]
		if not (encounter.mapID and encounter.dungeonEncounterID
			and C_RaidLocks and C_RaidLocks.IsEncounterComplete)
		then
			return nil, #encounters, false, makeUnknownBosses(encounters)
		end
		local defeated = safeCall(C_RaidLocks.IsEncounterComplete,
			encounter.mapID, encounter.dungeonEncounterID, difficultyID)
		if defeated ~= true and defeated ~= false then
			return nil, #encounters, false, makeUnknownBosses(encounters)
		end
		if defeated == true then
			complete = complete + 1
		end
		bosses[index] = {
			name = encounter.name,
			defeated = defeated == true,
		}
	end
	return complete, #encounters, true, bosses
end

local function getRaidSelection(difficultyID)
	-- Legacy raids have their own saved difficulty track.  The primary raid
	-- matcher intentionally consults GetRaidDifficultyID for normal non-dynamic
	-- contexts, so asking it first would leave a valid 10/25-player entry with
	-- no selected frame.
	if safeCall(IsLegacyDifficulty, difficultyID) == true then
		return safeCall(GetLegacyRaidDifficultyID) == difficultyID
	end
	if DifficultyUtil and type(DifficultyUtil.DoesCurrentRaidDifficultyMatch)
		== "function"
	then
		local matches = safeCall(
			DifficultyUtil.DoesCurrentRaidDifficultyMatch, difficultyID)
		if matches ~= nil then
			return matches == true
		end
	end
	local current = safeCall(GetRaidDifficultyID)
	local legacy = safeCall(GetLegacyRaidDifficultyID)
	return current == difficultyID or legacy == difficultyID
end

local function isEntranceDifficultySelected(isRaid, difficultyID)
	if isRaid then
		-- A group member's locally remembered raid setting must not look like
		-- an authoritative selection for the group's entrance.
		if safeCall(IsInGroup) == true and safeCall(UnitIsGroupLeader, "player") ~= true then
			return false
		end
		return getRaidSelection(difficultyID)
	end
	return safeCall(GetDungeonDifficultyID) == difficultyID
end

local function isLegacyRaidDifficulty(difficultyID)
	return safeCall(IsLegacyDifficulty, difficultyID) == true
end

local function isLegacyRaidDifficultyEnabled()
	-- DifficultyUtil.IsRaidDifficultyEnabled owns the shared in-instance,
	-- leader and LFG gates.  Legacy radio entries have two additional native
	-- UnitPopup restrictions: primary Mythic cannot coexist with a legacy
	-- choice, and a dynamic instance with its own toggle route owns the choice.
	local ids = DifficultyUtil and DifficultyUtil.ID or {}
	if safeCall(GetRaidDifficultyID) == (ids.PrimaryRaidMythic or 16) then
		return false
	end
	local _, _, currentDifficultyID, _, _, _, isDynamicInstance = safeCall(
		GetInstanceInfo)
	if isDynamicInstance == true
		and safeCall(CanChangePlayerDifficulty) == true
	then
		local _, _, _, _, _, _, toggleDifficultyID = safeCall(
			GetDifficultyInfo, currentDifficultyID)
		if toggleDifficultyID then
			return false
		end
	end
	return true
end

local function getPrimaryRaidDifficultyForce()
	-- Retain the one direct-setter detail from Blizzard's current UnitPopup
	-- primary branch.  In a dynamic instance whose toggle counterpart is legacy,
	-- the native setter needs force=true to affect the active difficulty rather
	-- than only the saved primary track.  We intentionally do *not* copy the
	-- helper's companion-track remapping: this overlay must preserve the row ID
	-- a player clicked for the legacy branch.
	local _, _, instanceDifficultyID, _, _, _, isDynamicInstance = safeCall(
		GetInstanceInfo)
	if isDynamicInstance ~= true
		or safeCall(CanChangePlayerDifficulty) ~= true
	then
		return false
	end
	local _, _, _, _, _, _, toggleDifficultyID = safeCall(
		GetDifficultyInfo, instanceDifficultyID)
	return toggleDifficultyID
		and safeCall(IsLegacyDifficulty, toggleDifficultyID) == true
		or false
end

local function setRaidDifficultyFromPhysicalClick(isLegacy, difficultyID)
	-- The native UnitPopup convenience helper maps only its own primary/legacy
	-- radio set.  In particular, passing legacy 5/6/9 through it can choose a
	-- companion mapping rather than the row the player clicked.  Plumber and the
	-- underlying Retail APIs both use the matching setter directly; preserve our
	-- stricter native eligibility gate in canChangeDifficulty and call this only
	-- from the physical Button OnClick stack.
	if not isLegacy and not isPrimaryRaidDifficulty(difficultyID) then
		return false
	end
	if isLegacy then
		return tryCall(SetLegacyRaidDifficultyID, difficultyID)
	end
	return tryCall(SetRaidDifficultyID, difficultyID,
		getPrimaryRaidDifficultyForce())
end

local function canChangeDifficulty(isRaid, difficultyID)
	if isInInstance() then
		return false, "inside-instance"
	end
	-- Mirror DifficultyUtil's group-leader gate so the view can explain this
	-- restriction without treating every native denial as a leadership issue.
	if safeCall(IsInGroup) == true and safeCall(UnitIsGroupLeader, "player") == false then
		return false, "not-group-leader"
	end
	if isRaid and DifficultyUtil
		and type(DifficultyUtil.IsRaidDifficultyEnabled) == "function"
	then
		if isRaidTimewalkingDifficulty(difficultyID)
			or isRaidWorldDifficulty(difficultyID)
		then
			return false, "raid-status-read-only"
		end
		local allowed = safeCall(DifficultyUtil.IsRaidDifficultyEnabled,
			difficultyID) == true
		if allowed and isLegacyRaidDifficulty(difficultyID) then
			allowed = isLegacyRaidDifficultyEnabled()
		end
		return allowed == true, "native-raid-gate"
	end
	if not isRaid and DifficultyUtil
		and type(DifficultyUtil.IsDungeonDifficultyEnabled) == "function"
	then
		return safeCall(DifficultyUtil.IsDungeonDifficultyEnabled, difficultyID)
			== true and true or false, "native-dungeon-gate"
	end
	return false, "native-gate-unavailable"
end

local function readOptions(journalInstanceID, isRaid, lockoutsReady)
	local options = {}
	local seen = {}
	for _, difficultyID in ipairs(getDifficultyIDs(isRaid)) do
		if not seen[difficultyID] then
			seen[difficultyID] = true
			local encounters = readJournalEncounters(journalInstanceID, difficultyID)
			if encounters then
				local done, total, progressReady, bosses = collectProgress(
					encounters, difficultyID, lockoutsReady)
				local enabled, disabledReason = canChangeDifficulty(isRaid, difficultyID)
				local name, playerCount = getDifficultyDetails(difficultyID, isRaid)
				options[#options + 1] = {
					difficultyID = difficultyID,
					name = name,
					playerCount = playerCount,
					done = done,
					total = total,
					progressReady = progressReady,
					selected = isEntranceDifficultySelected(isRaid, difficultyID),
					enabled = enabled == true,
					disabledReason = not enabled and disabledReason or nil,
					legacy = safeCall(IsLegacyDifficulty, difficultyID) == true,
					encounters = encounters,
					bosses = bosses,
				}
			end
		end
	end
	return options
end

local function buildOptions(journalInstanceID, isRaid, lockoutsReady)
	return withJournalRead(readOptions, journalInstanceID, isRaid, lockoutsReady)
end

local function getJournalInstanceInfo(journalInstanceID)
	-- Retail's EJ_GetInstanceInfo returns isRaid as item 12.  Item 11 is
	-- covenantID; treating it as isRaid made actual raid entrances follow the
	-- dungeon candidate path and hid their selectable raid difficulties.
	local name, _, _, _, _, _, _, _, _, _, _, isRaid = safeCall(
		EJ_GetInstanceInfo, journalInstanceID)
	return type(name) == "string" and name or nil, isRaid == true
end

function Service:IsEnabled()
	local database = getDatabase()
	return database and database.instanceGatewayEnabled == true
end

local function activeSavedInstance(index, current)
	-- Return 2 is a lockout ID, not the game map. Retail's map ID is return 14.
	local name, lockID, reset, difficultyID, locked, extended, mostSig, isRaid,
		_, _, total, done, _, instanceID = safeCall(GetSavedInstanceInfo, index)
	if type(name) ~= "string" or not finite(instanceID) or not finite(difficultyID) then
		return nil
	end
	reset = finite(reset)
	if isRaid ~= true or not (locked == true or extended == true)
		or not (extended == true or (reset and reset > 0)) then
		return false
	end
	local difficultyName, playerCount = getDifficultyDetails(difficultyID, true)
	return {
		index = index, instanceID = instanceID, difficultyID = difficultyID,
		lockID = lockID, mostSig = mostSig, name = difficultyName,
		playerCount = playerCount, done = finite(done), total = finite(total),
		extended = extended == true,
		expiresAt = reset and reset > 0 and current + reset or nil,
	}
end

function Service:GetSavedProgress(instanceID, force)
	local current = finite(GetTime and GetTime()) or 0
	local cache = self.savedProgressCache
	if not force and cache and cache.instanceID == instanceID
		and cache.revision == self._progressRevision
		and cache.ready == (self.raidInfoReady == true)
		and (not cache.expiresAt or current < cache.expiresAt) then
		return cache
	end
	cache = { instanceID = instanceID, revision = self._progressRevision,
		ready = false, entries = {} }
	self.savedProgressCache = cache
	if not instanceID or self.raidInfoReady ~= true then return cache end
	local count = finite(safeCall(GetNumSavedInstances))
	if not count or count < 0 or count > 500 or count % 1 ~= 0 then return cache end
	cache.ready = true
	for index = 1, count do
		local entry = activeSavedInstance(index, current)
		if entry == nil then
			-- An unreadable row can hide another matching record; no positive
			-- sharing/empty-state conclusion may be drawn from a partial list.
			cache.ready, cache.entries = false, {}
			return cache
		end
		if entry and entry.instanceID == instanceID then
			cache.entries[#cache.entries + 1] = entry
			if entry.expiresAt and (not cache.expiresAt or entry.expiresAt < cache.expiresAt) then
				cache.expiresAt = entry.expiresAt
			end
		end
	end
	-- The requested legacy warning names the one active saved difficulty with
	-- a confirmed kill. It is presentation only, never an extra setter gate.
	-- Multiple/partial saves cannot establish one difficulty: keep their list
	-- instead of picking whichever row happened to be enumerated last.
	local killedEntry, ambiguous, unreadable
	for _, entry in ipairs(cache.entries) do
		if isLegacyRaidDifficulty(entry.difficultyID) then
			if not entry.done or not entry.total or entry.total <= 0
				or entry.done < 0 or entry.done > entry.total then
				unreadable = true
			elseif entry.done > 0 then
				if killedEntry then ambiguous = true end
				killedEntry = entry
			end
		end
	end
	if unreadable then
		cache.legacyLockoutState = "unknown"
	elseif ambiguous then
		cache.legacyLockoutState = "ambiguous"
	elseif killedEntry then
		cache.legacyLockoutState = "locked"
		cache.legacyLockedDifficultyID = killedEntry.difficultyID
	else
		cache.legacyLockoutState = "clear"
	end
	return cache
end

local function uniqueSavedEntry(progress, difficultyID)
	if not progress or not progress.ready then return nil end
	local found
	for _, entry in ipairs(progress.entries) do
		if entry.difficultyID == difficultyID then
			if found then return nil end
			found = entry
		end
	end
	return found
end

function Service:ShareProgress(difficultyID)
	local snapshot = self.snapshot
	if not self:IsEnabled() or not snapshot or not snapshot.isRaid
		or (snapshot.kind ~= "entrance" and snapshot.kind ~= "arrival") then
		return false, "no-progress"
	end
	local option
	for _, candidate in ipairs(snapshot.options or {}) do
		if (difficultyID and candidate.difficultyID == difficultyID)
			or (not difficultyID and candidate.selected) then
			option = candidate
			break
		end
	end
	if not option then return false, "no-progress" end
	if self.raidInfoReady ~= true then return false, "not-ready" end
	-- Resolve the exact map/difficulty afresh on the physical click. A cached
	-- index may now point at another raid after a reset or list reorder.
	local progress = self:GetSavedProgress(snapshot.instanceID, true)
	if not progress.ready then return false, "not-ready" end
	local entry = uniqueSavedEntry(progress, option.difficultyID)
	if not entry then return false, "no-progress" end
	local chat = ChatFrameUtil and safeCall(ChatFrameUtil.GetActiveWindow)
	if not chat or safeCall(chat.IsShown, chat) ~= true
		or safeCall(chat.HasFocus, chat) ~= true then
		return false, "open-chat"
	end
	local link = safeCall(GetSavedInstanceChatLink, entry.index)
	if type(link) ~= "string" or link == "" then return false, "no-progress" end
	-- Insert directly into the verified chat input, matching the chat branch
	-- of ChatFrameUtil.InsertLink without routing into a focused macro editor.
	local inserted = tryCall(chat.Insert, chat, link)
	return inserted == true, inserted and nil or "insert-failed"
end

function Service:IsArrivalActive(token)
	return self.insideSessionKey ~= nil and token == self.arrivalToken
		and not self.insideArrivalDismissed and (self.insideArrivalPaused == true
			or (self.insideArrivalUntil ~= nil
				and (finite(GetTime and GetTime()) or 0) < self.insideArrivalUntil))
end

function Service:PublishArrivalLifetime()
	if not self.snapshot or self.snapshot.kind ~= "arrival"
		or self.snapshot.arrivalToken ~= self.arrivalToken then return end
	local snapshot = {}
	for key, value in pairs(self.snapshot) do snapshot[key] = value end
	snapshot.arrivalUntil = self.insideArrivalUntil
	snapshot.arrivalPaused = self.insideArrivalPaused == true
	snapshot.arrivalDismissed = self.insideArrivalDismissed == true
	self.snapshot = snapshot
	self:Notify("arrival-lifetime")
end

function Service:SetArrivalPaused(token, paused)
	paused = paused == true
	if not self:IsEnabled() or not self:IsArrivalActive(token)
		or (self.insideArrivalPaused == true) == paused then return false end
	local current = finite(GetTime and GetTime()) or 0
	if paused then
		self.insideArrivalRemaining = math.max(0, self.insideArrivalUntil - current)
	else
		self.insideArrivalUntil = current + math.max(1, self.insideArrivalRemaining or 0)
		self.insideArrivalRemaining = nil
	end
	self.insideArrivalPaused = paused
	self:PublishArrivalLifetime()
	return true
end

function Service:DismissArrival(token)
	if token ~= self.arrivalToken or not self.insideSessionKey
		or self.insideArrivalDismissed then return false end
	self.insideArrivalDismissed = true
	self.insideArrivalPaused, self.insideArrivalRemaining = nil, nil
	self:PublishArrivalLifetime()
	return true
end

function Service:ApplySettings(reason, previousEnabled)
	local enabled = self:IsEnabled()
	local appliedEnabled = self.appliedEnabled
	if appliedEnabled == nil and type(previousEnabled) == "boolean" then
		appliedEnabled = previousEnabled
	end
	local changed = appliedEnabled ~= nil and appliedEnabled ~= enabled
	self.appliedEnabled = enabled
	-- Settings can change the font/layout without changing the game snapshot.
	self._publishedSnapshot = nil
	self._entranceCache = nil
	self._departureChecks = 0
	if not enabled then
		self:DismissArrival(self.arrivalToken)
		self.savedProgressCache = nil
		self.snapshot = { kind = "hidden" }
		self.portalKey = nil
		self.portalModel = nil
		-- Closing the setting stops every visible projection immediately, but it
		-- must not turn a later re-enable in this same instance into a new entry.
		-- The entry identity/token is cleared only by a confirmed departure.
		-- Cancel an outstanding timer without erasing the entry's bounded retry
		-- budget.  Repeatedly toggling the setting during one loading transition
		-- must not turn a 20-attempt limit into an unbounded retry loop.
		self:ClearInsideReadRetry(true)
		self.raidInfoReady = false
	elseif changed and self.insideSessionKey and isInInstance() then
		-- Disabling intentionally clears the old lockout-read acknowledgement.
		-- Re-enabling inside that *same* entry retains its arrival token, but must
		-- issue one fresh read so the tooltip does not remain unknown forever.
		self:RequestRaidInfo(true)
	end
	self:Refresh(reason or "setting")
	if changed then
		self:Notify(reason or "setting")
	end
	return enabled
end

function Service:SetEnabled(enabled)
	local database = getDatabase()
	if not database then
		return false
	end
	enabled = enabled == true
	local previousEnabled = database.instanceGatewayEnabled == true
	database.instanceGatewayEnabled = enabled
	return self:ApplySettings("setting", previousEnabled)
end

function Service:ClearInsideReadRetry(preserveCount)
	-- Timers cannot be cancelled reliably across all supported Retail clients.
	-- A monotonically increasing generation makes any already queued read-only
	-- retry a no-op once its associated entry attempt has ended.
	self.insideReadRetryGeneration = (self.insideReadRetryGeneration or 0) + 1
	self.insideReadRetryPending = nil
	if preserveCount ~= true then
		self.insideReadRetryCount = nil
	end
end

function Service:ClearOutsideDepartureCandidate()
	self.outsideDepartureCandidateAt = nil
end

function Service:EndInsideSession()
	-- A session is ended by a readable non-party/raid state, or only after the
	-- same outside ``none`` / 0 state survives a full normal scan interval.
	-- One loading-screen placeholder is never enough evidence to discard an
	-- arrival token.
	self.insideSessionKey = nil
	self.insidePendingToken = nil
	self.insideArrivalUntil = nil
	self.insideArrivalPaused, self.insideArrivalRemaining = nil, nil
	self.insideArrivalDismissed = nil
	self:ClearOutsideDepartureCandidate()
	self:ClearInsideReadRetry()
end

function Service:ObserveOutsideDeparture()
	-- This helper is used both while enabled and while the feature is hidden by
	-- its setting.  It makes the departure decision from the same evidence in
	-- both modes, so toggling the setting cannot change an entry token's fate.
	local _, instanceType, difficultyID = safeCall(GetInstanceInfo)
	difficultyID = finite(difficultyID)
	if instanceType == "party" or instanceType == "raid" then
		-- IsInInstance() can lag GetInstanceInfo() around a portal boundary.  A
		-- readable old party/raid identity is not a departure.
		self:ClearOutsideDepartureCandidate()
		return false
	end
	local transient = type(instanceType) ~= "string" or instanceType == ""
		or instanceType == "none" or not difficultyID or difficultyID <= 0
	if transient then
		local current = finite(GetTime and GetTime()) or 0
		local candidateAt = self.outsideDepartureCandidateAt
		if not candidateAt or current < candidateAt then
			self.outsideDepartureCandidateAt = current
			return false
		end
		if current - candidateAt < OUTSIDE_DEPARTURE_CONFIRM_SECONDS then
			return false
		end
	end
	-- PvP, arena, scenario, and any other readable non-party/non-raid state
	-- are authoritative exclusions.  A stable outside placeholder becomes a
	-- confirmed leave only after the bounded grace period above.
	self:EndInsideSession()
	return true
end

function Service:ObserveDisabledLifecycle()
	-- Turning the feature off suppresses every projection and request, but it
	-- must still forget a *confirmed* departure.  Otherwise leave → re-enter
	-- the same map while disabled would retain the old session key and lose the
	-- next real arrival notice after the setting is restored.
	local reportedInside = isInInstance()
	local _, instanceType, difficultyID = safeCall(GetInstanceInfo)
	difficultyID = finite(difficultyID)
	if reportedInside then
		self:ClearOutsideDepartureCandidate()
		-- ``none`` / 0 and blank values are the loading state, not an
		-- authoritative departure.  A readable non-party/raid type (PvP,
		-- arena, scenario, ...) is authoritative and may close this session.
		if type(instanceType) ~= "string" or instanceType == ""
			or instanceType == "none" or not difficultyID or difficultyID <= 0
		then
			return false
		end
		if instanceType == "party" or instanceType == "raid" then
			return false
		end
		self:EndInsideSession()
		return true
	end
	if self.insideSessionKey or self.insidePendingToken then
		return self:ObserveOutsideDeparture()
	end
	return false
end

function Service:BeginPendingInsideToken()
	-- We know only that the player crossed into an instance at this point; its
	-- readable map identity can legitimately arrive a fraction later.  Reserve
	-- one token now so a brief IsInInstance/GetInstanceInfo disagreement cannot
	-- turn the first readable snapshot into two separate arrivals.
	if self.insideSessionKey or self.insidePendingToken then
		return false
	end
	self:ClearOutsideDepartureCandidate()
	self.arrivalToken = (self.arrivalToken or 0) + 1
	self.insidePendingToken = true
	return true
end

function Service:ScheduleInsideReadRetry()
	-- This retry exists only before the first readable party/raid snapshot of an
	-- entry.  It lets a transient loading-screen GetInstanceInfo() gap recover,
	-- but never creates another arrival token after one has been established.
	if self.insideSessionKey or self.insideReadRetryPending then
		return false
	end
	local count = self.insideReadRetryCount or 0
	if count >= INSIDE_READ_RETRY_LIMIT then
		return false
	end
	if not (C_Timer and type(C_Timer.After) == "function") then
		return false
	end
	self.insideReadRetryCount = count + 1
	self.insideReadRetryPending = true
	local generation = self.insideReadRetryGeneration or 0
	C_Timer.After(INSIDE_READ_RETRY_DELAY, function()
		if Service.insideReadRetryGeneration ~= generation then
			return
		end
		Service.insideReadRetryPending = nil
		if isInInstance() and not Service.insideSessionKey then
			Service:Refresh("inside-data-retry")
		end
	end)
	return true
end

function Service:GetPosition()
	local database = getDatabase()
	if not database or type(database.instanceGatewayPoint) ~= "string" then
		return nil
	end
	local x = finite(database.instanceGatewayX)
	local y = finite(database.instanceGatewayY)
	if not (x and y) then
		return nil
	end
	local relativePoint = type(database.instanceGatewayRelPoint) == "string"
		and database.instanceGatewayRelPoint or database.instanceGatewayPoint
	return database.instanceGatewayPoint, relativePoint, x, y
end

function Service:SetPosition(point, relativePoint, x, y)
	if type(point) ~= "string" or point == "" then
		return false
	end
	x, y = finite(x), finite(y)
	local database = x and y and getDatabase()
	if not database then
		return false
	end
	if type(relativePoint) ~= "string" or relativePoint == "" then
		relativePoint = nil
	end
	database.instanceGatewayPoint = point
	database.instanceGatewayRelPoint = relativePoint
	database.instanceGatewayX = x
	database.instanceGatewayY = y
	return true
end

function Service:ClearPosition()
	local database = getDatabase()
	if not database then
		return false
	end
	database.instanceGatewayPoint = nil
	database.instanceGatewayRelPoint = nil
	database.instanceGatewayX = nil
	database.instanceGatewayY = nil
	return true
end

function Service:AddListener(listener)
	if type(listener) ~= "function" then
		return false
	end
	self.listeners = self.listeners or {}
	self.listeners[listener] = true
	return true
end

function Service:Notify(reason)
	if sameProjection(self._publishedSnapshot, self.snapshot) then
		return false
	end
	self._publishedSnapshot = self.snapshot
	for listener in pairs(self.listeners or {}) do
		local ok = pcall(listener, copySnapshot(self.snapshot), reason)
		if not ok then
			self.listeners[listener] = nil
		end
	end
	return true
end

function Service:GetSnapshot()
	return copySnapshot(self.snapshot)
end

function Service:RequestRaidInfo(force)
	if not self:IsEnabled() then return false end
	local now = finite(GetTime and GetTime()) or 0
	if force ~= true and self.lastRaidInfoAt and now - self.lastRaidInfoAt < 1 then
		return false
	end
	self.lastRaidInfoAt = now
	self.raidInfoReady = false
	self._progressRevision = (self._progressRevision or 0) + 1
	safeCall(RequestRaidInfo)
	return true
end

function Service:BuildPortalModel(entrance)
	local journalInstanceID = finite(entrance and entrance.journalInstanceID)
	if not journalInstanceID then
		return nil
	end
	local journalName, isRaid = getJournalInstanceInfo(journalInstanceID)
	local options = buildOptions(journalInstanceID, isRaid, self.raidInfoReady)
	if not options or #options == 0 then
		return nil
	end
	return {
		journalInstanceID = journalInstanceID,
		instanceID = options[1].encounters[1].mapID,
		name = journalName or entrance.name or "",
		isRaid = isRaid,
		options = options,
	}
end

function Service:FindNearbyEntrance()
	if isInInstance() then
		return nil
	end
	local mapAPI = C_Map
	local journalAPI = C_EncounterJournal
	if not (mapAPI and journalAPI and mapAPI.GetBestMapForUnit
		and mapAPI.GetPlayerMapPosition and mapAPI.GetMapWorldSize
		and journalAPI.GetDungeonEntrancesForMap)
	then
		return nil
	end
	local uiMapID = publicNumber(safeCall(mapAPI.GetBestMapForUnit, "player"))
	if not uiMapID then
		self._entranceCache = nil
		return nil
	end
	local cache = self._entranceCache
	if not cache or cache.uiMapID ~= uiMapID then
		local mapSize, second = safeCall(mapAPI.GetMapWorldSize, uiMapID)
		local mapWidth, mapHeight = extractXY(mapSize, second)
		local entrances = safeCall(journalAPI.GetDungeonEntrancesForMap, uiMapID)
		if not (mapWidth and mapHeight and mapWidth > 0 and mapHeight > 0
			and type(entrances) == "table") then
			return nil
		end
		local hasIndoorEntrances, hasFactionEntrances
		entrances, hasIndoorEntrances, hasFactionEntrances = prepareEntranceList(uiMapID, entrances)
		cache = { uiMapID = uiMapID, width = mapWidth, height = mapHeight,
			entrances = entrances,
			hasIndoorEntrances = hasIndoorEntrances, hasFactionEntrances = hasFactionEntrances,
			hasFloors = safeCall(mapAPI.GetMapGroupID, uiMapID) ~= nil }
		self._entranceCache = cache
	end
	if #cache.entrances == 0 then return nil end
	local playerX, playerY, projected = readPlayerPosition(cache)
	if not (playerX and playerY) then return nil end
	local indoors, faction = readEntranceEnvironment(cache)
	local closest, closestDistance = findClosestEntrance(cache, playerX, playerY, indoors, faction)
	if projected and closestDistance and closestDistance <= (ENTRANCE_RANGE_YARDS + 1) ^ 2 then
		-- The native position remains authoritative at and inside the boundary.
		-- Saving idle allocations must not change which entrance can be selected.
		local nativeX, nativeY = readNativePosition(cache)
		if not positionMatches(cache, playerX, playerY, nativeX, nativeY) then
			cache.positionTransform = nil
		end
		if not (nativeX and nativeY) then return nil end
		closest, closestDistance = findClosestEntrance(cache, nativeX, nativeY, indoors, faction)
	end
	self._scanInterval = closestDistance and closestDistance < 60 ^ 2
		and SCAN_INTERVAL or FAR_SCAN_INTERVAL
	if closestDistance and closestDistance <= ENTRANCE_RANGE_YARDS ^ 2 then
		return closest
	end
	return nil
end

function Service:BuildInsideSnapshot()
	self:ClearOutsideDepartureCandidate()
	local instanceName, instanceType, difficultyID, difficultyName, _, _, _, mapID =
		safeCall(GetInstanceInfo)
	difficultyID = finite(difficultyID)
	-- GetInstanceInfo can be temporarily empty while a loading screen is
	-- resolving.  That is not evidence that the player left the current
	-- instance: clearing the token here would replay the one-time arrival
	-- presentation on the next readable UPDATE_INSTANCE_INFO.  Only a readable
	-- non-party/non-raid type is an authoritative exclusion.
	-- The loading screen can report a nonempty name together with a temporary
	-- ``none`` type / 0 difficulty.  Lua treats 0 as truthy, so reject it
	-- explicitly.  It is not an authoritative non-instance state while
	-- IsInInstance() still says true; retry it without consuming the arrival
	-- token.
	if type(instanceType) ~= "string" or instanceType == ""
		or instanceType == "none" or not difficultyID or difficultyID <= 0
		or type(instanceName) ~= "string" or instanceName == ""
	then
		return nil, "not-ready"
	end
	if instanceType ~= "party" and instanceType ~= "raid" then
		return nil, "unsupported"
	end
	local instanceID = finite(mapID)
	if not instanceID or instanceID <= 0 then
		-- A readable name/difficulty with mapID 0 is still the transition state.
		-- Do not build a temporary name-keyed session here: when the real map ID
		-- arrives it would otherwise look like a second entry and replay once.
		return nil, "not-ready"
	end
	local insideSessionKey = table.concat({
		tostring(instanceType),
		tostring(instanceID),
	}, ":")
	if self.insideSessionKey ~= insideSessionKey then
		self:ClearInsideReadRetry()
		self.insideSessionKey = insideSessionKey
		if not self.insidePendingToken then
			self.arrivalToken = (self.arrivalToken or 0) + 1
		end
		self.insidePendingToken = nil
		self.insideArrivalUntil = (finite(GetTime and GetTime()) or 0)
			+ ARRIVAL_SECONDS
		self.insideArrivalPaused, self.insideArrivalRemaining = nil, nil
		self.insideArrivalDismissed = nil
		-- Start exactly one lockout read cycle for this entry.  Later status
		-- events refresh the contents of this same snapshot; they never create
		-- a new arrival presentation.
		self:RequestRaidInfo(true)
	end
	-- Once the one-time notice expires, only the entry identity matters. Keep
	-- observing departures, but do not rebuild hidden Journal/boss projections.
	if self.snapshot and self.snapshot.kind == "arrival"
		and self.snapshot.arrivalToken == self.arrivalToken
		and not self:IsArrivalActive(self.arrivalToken) then
		return self.snapshot
	end
	local journalInstanceID = C_EncounterJournal
		and safeCall(C_EncounterJournal.GetInstanceForGameMap, mapID) or nil
	local encounters
	local previous = self.snapshot
	if previous and previous.instanceID == instanceID
		and previous.journalInstanceID == journalInstanceID then
		for _, option in ipairs(previous.options or {}) do
			if option.difficultyID == difficultyID then
				encounters = option.encounters
				break
			end
		end
	end
	-- Carry the current instance's metadata through entrance -> arrival and
	-- progress acknowledgements. Reuse the existing snapshot, not another cache.
	if not encounters and journalInstanceID then
		encounters = getJournalEncounters(journalInstanceID, difficultyID)
	end
	local done, total, progressReady, bosses = collectProgress(
		encounters, difficultyID, self.raidInfoReady)
	if not progressReady and GetInstanceLockTimeRemaining then
		local _, _, lockedTotal, lockedDone = safeCall(GetInstanceLockTimeRemaining)
		if finite(lockedTotal) and finite(lockedDone)
			and lockedTotal > 0 and lockedDone >= 0
		then
			done, total, progressReady = lockedDone, lockedTotal, true
		end
	end
	local savedProgress = instanceType == "raid" and self:GetSavedProgress(instanceID) or nil
	return {
		kind = "arrival",
		instanceID = instanceID,
		savedProgress = savedProgress,
		name = instanceName,
		isRaid = instanceType == "raid",
		journalInstanceID = journalInstanceID,
		arrivalToken = self.arrivalToken,
		arrivalUntil = self.insideArrivalUntil,
		arrivalPaused = self.insideArrivalPaused == true,
		arrivalDismissed = self.insideArrivalDismissed == true,
		options = {
			{
				difficultyID = difficultyID,
				name = type(difficultyName) == "string" and difficultyName
					or getDifficultyName(difficultyID),
				done = done,
				total = total,
				progressReady = progressReady,
				selected = true,
				enabled = false,
				legacy = isLegacyRaidDifficulty(difficultyID),
				canShareProgress = uniqueSavedEntry(savedProgress, difficultyID) ~= nil,
				encounters = encounters,
				bosses = bosses,
			},
		},
	}
end

local function refreshSnapshot(self, reason)
	if not self:IsEnabled() then
		self:ObserveDisabledLifecycle()
		self.snapshot = HIDDEN_SNAPSHOT
		-- Keep the current entry identity while disabled.  This is lifecycle
		-- bookkeeping only: the overlay is hidden and emits no entrance/arrival
		-- output until the setting is enabled again.
		self:ClearInsideReadRetry(true)
		self.raidInfoReady = false
		self:Notify(reason or "disabled")
		return self.snapshot
	end
	if isInInstance() then
		self:ClearOutsideDepartureCandidate()
		self.portalKey, self.portalModel = nil, nil
		local inside, state = self:BuildInsideSnapshot()
		if inside then
			self.snapshot = inside
		elseif state == "unsupported" then
			self:EndInsideSession()
			self.snapshot = { kind = "hidden" }
		else
			-- Retain the last arrival snapshot (and especially its stable token)
			-- during a transient loading read.  A later readable refresh updates
			-- its details without restarting or replaying the one-time notice.
			local newPendingToken = self:BeginPendingInsideToken()
			if newPendingToken then
				-- A stale entrance selector must not remain clickable while the
				-- player is already crossing the loading boundary.
				self.snapshot = { kind = "hidden" }
			else
				self.snapshot = self.snapshot or { kind = "hidden" }
			end
			self:ScheduleInsideReadRetry()
		end
		self:Notify(reason or "inside")
		return self.snapshot
	end
	-- During a portal/loading transition IsInInstance can briefly return false
	-- before GetInstanceInfo has become readable.  The F57 token is cleared only
	-- after a readable non-party/non-raid state proves that this entry ended;
	-- otherwise the later readable inside state would be mistaken for a second
	-- entry and replay its one-time presentation.
	if self.insideSessionKey or self.insidePendingToken then
		if not self:ObserveOutsideDeparture() then
			self:Notify(reason or "instance-transition")
			return self.snapshot or { kind = "hidden" }
		end
	end
	self:EndInsideSession()
	local entrance = self:FindNearbyEntrance()
	if not entrance then
		self.savedProgressCache = nil
		self.portalKey = nil
		self.portalModel = nil
		self.snapshot = HIDDEN_SNAPSHOT
		self:Notify(reason or "no-entrance")
		return self.snapshot
	end
	local portalKey = tostring(entrance.journalInstanceID)
	if self.portalKey ~= portalKey then
		self.portalKey = portalKey
		self.portalModel = nil
		self._portalReadAttempts, self._portalReadAt = 0, nil
		-- A new entrance must start with unknown lockout data, never reuse a
		-- previous portal's UPDATE_INSTANCE_INFO acknowledgement for a false 0/N.
		self:RequestRaidInfo(true)
	end
	local current = finite(GetTime and GetTime()) or 0
	local journalVisible = isJournalVisible()
	if self._portalJournalVisible and not journalVisible and not self.portalModel then
		-- Closing the visible Journal is a new opportunity to read its data,
		-- even when an earlier transient failure exhausted the bounded budget.
		self._portalReadAttempts, self._portalReadAt = 0, nil
	end
	self._portalJournalVisible = journalVisible
	if not self.portalModel and not journalVisible
		and (self._portalReadAttempts or 0) < PORTAL_READ_RETRY_LIMIT
		and (not self._portalReadAt or current >= self._portalReadAt) then
		self._portalReadAttempts = (self._portalReadAttempts or 0) + 1
		self._portalReadAt = current + 2 ^ (self._portalReadAttempts - 1)
		self.portalModel = self:BuildPortalModel(entrance)
		if self.portalModel then
			self._portalReadAttempts, self._portalReadAt = 0, nil
		end
	end
	if not self.portalModel then
		self.snapshot = HIDDEN_SNAPSHOT
		self:Notify(reason or "unsupported-entrance")
		return self.snapshot
	end
	local savedCache = self.savedProgressCache
	local savedExpired = self.portalModel.isRaid and savedCache
		and savedCache.instanceID == self.portalModel.instanceID
		and savedCache.expiresAt and current >= savedCache.expiresAt
	if savedExpired then self:RequestRaidInfo(true) end
	if reason == "position" and not savedExpired and self.snapshot and self.snapshot.kind == "entrance"
		and self.snapshot.journalInstanceID == self.portalModel.journalInstanceID
		and self._snapshotProgressRevision == self._progressRevision then
		return self.snapshot
	end
	local savedProgress = self.portalModel.isRaid
		and self:GetSavedProgress(self.portalModel.instanceID) or nil
	local options = {}
	for index, option in ipairs(self.portalModel.options) do
		local previous = self.snapshot and self.snapshot.kind == "entrance"
			and self.snapshot.journalInstanceID == self.portalModel.journalInstanceID
			and self.snapshot.options[index]
		local done, total, progressReady, bosses
		if previous and self._snapshotProgressRevision == self._progressRevision then
			done, total, progressReady, bosses = previous.done, previous.total,
				previous.progressReady, previous.bosses
		else
			done, total, progressReady, bosses = collectProgress(
				option.encounters, option.difficultyID, self.raidInfoReady)
		end
		local enabled, disabledReason = canChangeDifficulty(
			self.portalModel.isRaid, option.difficultyID)
		options[index] = {
			difficultyID = option.difficultyID,
			name = option.name,
			playerCount = option.playerCount,
			done = done,
			total = total or option.total,
			progressReady = progressReady,
			selected = isEntranceDifficultySelected(self.portalModel.isRaid, option.difficultyID),
			enabled = enabled == true,
			disabledReason = not enabled and disabledReason or nil,
			legacy = option.legacy,
			canShareProgress = uniqueSavedEntry(savedProgress, option.difficultyID) ~= nil,
			encounters = option.encounters,
			bosses = bosses,
		}
	end
	self.snapshot = {
		kind = "entrance",
		instanceID = self.portalModel.instanceID,
		savedProgress = savedProgress,
		name = self.portalModel.name,
		isRaid = self.portalModel.isRaid,
		journalInstanceID = self.portalModel.journalInstanceID,
		options = options,
	}
	self._snapshotProgressRevision = self._progressRevision
	self:Notify(reason or "entrance")
	return self.snapshot
end

local function onPositionUpdate(_, elapsed)
	Service.elapsed = (Service.elapsed or 0) + elapsed
	if Service.elapsed < (Service._scanInterval or SCAN_INTERVAL) then return end
	Service.elapsed = 0
	if Service.insideSessionKey or Service.insidePendingToken then
		Service._departureChecks = (Service._departureChecks or 0) + 1
	end
	Service:Refresh("position")
end

function Service:UpdateTracking()
	local frame = self.eventFrame
	if not frame then return end
	local enabled = self:IsEnabled()
	if self._statusEventsEnabled ~= enabled then
		self._statusEventsEnabled = enabled
		for _, event in ipairs(STATUS_EVENTS) do
			if enabled then frame:RegisterEvent(event)
			else frame:UnregisterEvent(event) end
		end
	end
	local outside = not isInInstance()
	local departing = (self.insideSessionKey or self.insidePendingToken)
		and (self._departureChecks or 0) < INSIDE_READ_RETRY_LIMIT
	local cache = self._entranceCache
	local track = outside and (departing or (enabled and not self.insideSessionKey
		and not self.insidePendingToken
		and (not cache or #cache.entrances > 0 or cache.hasFloors)))
	track = track == true
	if self._tracking ~= track then
		self._tracking = track
		self.elapsed = 0
		frame:SetScript("OnUpdate", track and onPositionUpdate or nil)
	end
end

function Service:Refresh(reason)
	local snapshot = refreshSnapshot(self, reason)
	self:UpdateTracking()
	return snapshot
end

local function selectedDifficultyID(snapshot)
	for _, option in ipairs(snapshot and snapshot.options or {}) do
		if option.selected == true and finite(option.difficultyID) then
			return option.difficultyID
		end
	end
	return nil
end

local function getLFGRestrictions()
	local utility = _G and _G.UnitPopupSharedUtil or UnitPopupSharedUtil
	if utility and type(utility.HasLFGRestrictions) == "function" then
		local restricted = safeCall(utility.HasLFGRestrictions)
		if restricted == true or restricted == false then
			return restricted
		end
	end
	-- The reset confirmation is an irreversible game action after the player
	-- accepts Blizzard's dialog.  Missing/failed native LFG eligibility is not
	-- evidence that reset is safe, so fail closed rather than presenting it.
	return nil
end

function Service:OpenAdventureGuide()
	local snapshot = self.snapshot
	local journalInstanceID = finite(snapshot and snapshot.journalInstanceID)
	if not journalInstanceID then
		return false, "journal-unavailable"
	end
	-- This is deliberately invoked only by the title Button's physical
	-- LeftButton click.  CanShowEncounterJournal is Blizzard's availability
	-- gate; ToggleEncounterJournal is intentionally avoided because it could
	-- close an already-open guide instead of opening this instance.
	if type(CanShowEncounterJournal) ~= "function"
		or safeCall(CanShowEncounterJournal) ~= true
	then
		return false, "guide-unavailable"
	end
	local loaded, result = tryCall(EncounterJournal_LoadUI)
	if not loaded or result == false or type(EncounterJournal_OpenJournal) ~= "function" then
		return false, "guide-load-failed"
	end
	local opened = tryCall(EncounterJournal_OpenJournal,
		selectedDifficultyID(snapshot), journalInstanceID)
	return opened == true, opened and nil or "guide-open-failed"
end

function Service:ShowResetInstancesConfirmation()
	-- Mirror Blizzard's own UnitPopup reset eligibility before presenting the
	-- native confirmation.  GroupFinder never calls ResetInstances itself;
	-- Blizzard only performs the reset after the player confirms the dialog.
	if isInInstance() then
		return false, "inside-instance"
	end
	if safeCall(IsInGroup) == true
		and safeCall(UnitIsGroupLeader, "player") ~= true
	then
		return false, "not-group-leader"
	end
	local hasRestrictions = getLFGRestrictions()
	if hasRestrictions == nil then
		return false, "lfg-gate-unavailable"
	end
	if hasRestrictions then
		return false, "lfg-restriction"
	end
	local shown = tryCall(StaticPopup_Show, "CONFIRM_RESET_INSTANCES")
	return shown == true, shown and nil or "confirmation-unavailable"
end

function Service:SelectDifficulty(difficultyID)
	difficultyID = finite(difficultyID)
	local snapshot = self.snapshot
	if not (difficultyID and snapshot and snapshot.kind == "entrance") then
		return false, "not-at-entrance"
	end
	local selected
	for _, option in ipairs(snapshot.options or {}) do
		if option.difficultyID == difficultyID then
			selected = option
			break
		end
	end
	if not selected then
		return false, "unlisted-difficulty"
	end
	local enabled = canChangeDifficulty(snapshot.isRaid == true, difficultyID)
	if not enabled then
		return false, "native-gate"
	end
	-- This method is only called synchronously by InstanceGatewayOverlay's
	-- OnClick.  Never call it from Refresh, an event handler, or a timer.
	local invoked
	if snapshot.isRaid then
		invoked = setRaidDifficultyFromPhysicalClick(selected.legacy == true,
			difficultyID)
	else
		invoked = tryCall(SetDungeonDifficultyID, difficultyID)
	end
	if invoked ~= true then
		return false, "setter-failed"
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.15, function()
			Service:Refresh("difficulty-click")
		end)
	else
		self:Refresh("difficulty-click")
	end
	return true
end

function Service:HandleEvent(event)
	if MAP_EVENTS[event] then
		self._entranceCache = nil
		self._departureChecks = 0
		self._scanInterval = SCAN_INTERVAL
		if not self.portalModel then
			self._portalReadAttempts, self._portalReadAt = 0, nil
		end
	end
	if not self:IsEnabled() then
		if MAP_EVENTS[event] then self:Refresh(event) end
		return
	end
	if event == "LOADING_SCREEN_DISABLED" then
		if C_Timer and C_Timer.After then
			if self._loadingRefreshPending then return end
			self._loadingRefreshPending = true
			C_Timer.After(ARRIVAL_DELAY, function()
				self._loadingRefreshPending = nil
				self:Refresh("loading-screen")
			end)
			return
		end
	elseif event == "UPDATE_INSTANCE_INFO" then
		-- This is the acknowledgement for the latest RequestRaidInfo read
		-- cycle.  Only after it arrives may false encounter values mean a real
		-- 0/N rather than not-yet-loaded lockout data.
		self.raidInfoReady = true
		self._progressRevision = (self._progressRevision or 0) + 1
	elseif event == "ENCOUNTER_END" then
		if not self.portalKey and not self.insideArrivalUntil then return end
		if isInInstance() and not self:IsArrivalActive(self.arrivalToken) then return end
		self:RequestRaidInfo()
	end
	self:Refresh(event)
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self.snapshot = self.snapshot or { kind = "hidden" }
	if not CreateFrame then
		return
	end
	local frame = CreateFrame("Frame")
	self.eventFrame = frame
	for event in pairs(MAP_EVENTS) do
		frame:RegisterEvent(event)
	end
	frame:SetScript("OnEvent", function(_, event)
		Service:HandleEvent(event)
	end)
	self:ApplySettings("init")
end
