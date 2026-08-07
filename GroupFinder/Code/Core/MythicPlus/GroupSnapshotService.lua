local _, GF = ...

GF.MythicPlusGroupSnapshotService = GF.MythicPlusGroupSnapshotService or {}
local Service = GF.MythicPlusGroupSnapshotService
local Util = GF.MythicPlusServiceUtil
local Transport = GF.AddonMessageTransport

local PREFIX = "GFMP2"
local VERSION = "2"
local MAX_CHARACTERS = 25
local MAX_MESSAGE_BYTES = 250
local MAX_PENDING_AGE = 30
local MAX_SNAPSHOT_AGE = 15 * 60
local MAX_BEST_RUNS = 16
local MAX_EXTENSION_PARTS = 8
local MAX_EXTENSION_PAYLOAD_BYTES = 180
local MAX_PENDING_BATCHES_PER_OWNER = 2
local MAX_PENDING_BATCHES = 32
local MAX_EXTENSION_BATCHES_PER_OWNER = 2
local MAX_EXTENSION_BATCHES = 32
local MAX_EXTENSION_BYTES_PER_BATCH = 80 * 1024
local MAX_KEYSTONE_LINK_BYTES = 512
local MAX_RUN_DURATION_MS = 7 * 24 * 60 * 60 * 1000
local RENEW_INTERVAL = 5 * 60
local PEER_RESPONSE_DELAY = 1

-- RequestSync is also used for local semantic refreshes. Only acquisition
-- paths may re-query genuinely missing peer snapshots.
local MISSING_SNAPSHOT_REQUEST_REASONS = {
	["init"] = true,
	["PLAYER_ENTERING_WORLD"] = true,
	["GROUP_ROSTER_UPDATE"] = true,
	["UNIT_CONNECTION"] = true,
	["snapshot-expired"] = true,
	["group-page"] = true,
	["carpool"] = true,
	["carpool-page"] = true,
}

Service.PREFIX = PREFIX
Service.VERSION = VERSION

local ROLE_TO_KEY = {
	TANK = "TANK",
	HEALER = "HEAL",
	HEAL = "HEAL",
	DAMAGER = "DPS",
	DPS = "DPS",
}

local function encode(value)
	if value == nil then
		return ""
	end
	return tostring(value)
		:gsub("%%", "%%25")
		:gsub("|", "%%7C")
		:gsub("\r", "%%0D")
		:gsub("\n", "%%0A")
		:gsub("%z", "")
end

local function decode(value)
	return (tostring(value or ""):gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local function split(value)
	local parts = {}
	for part in (tostring(value or "") .. "|"):gmatch("(.-)|") do
		parts[#parts + 1] = part
	end
	return parts
end

local function cleanString(value, maxBytes)
	value = decode(value)
	if value == "" or #value > (maxBytes or 100) then
		return nil
	end
	return value
end

local function canonical(value)
	value = type(value) == "string" and value or ""
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("%s+", "")
	return value ~= "" and string.lower(value) or nil
end

local function shortCanonical(value)
	local normalized = canonical(value)
	return normalized and normalized:match("^([^-]+)") or nil
end

local function identifiersMatch(left, right)
	local leftFull = canonical(left)
	local rightFull = canonical(right)
	if not (leftFull and rightFull) then
		return false
	end
	if leftFull == rightFull then
		return true
	end
	return not leftFull:find("-", 1, true)
		and shortCanonical(leftFull) == shortCanonical(rightFull)
		or not rightFull:find("-", 1, true)
			and shortCanonical(leftFull) == shortCanonical(rightFull)
end

local function senderMatchesUnit(sender, fullName, shortName)
	local senderKey = canonical(sender)
	if not senderKey then
		return false
	end
	if senderKey:find("-", 1, true) then
		return senderKey == canonical(fullName)
	end
	return senderKey == shortCanonical(fullName)
		or senderKey == canonical(shortName)
end

local function collectUnits()
	local units = {}
	if IsInRaid and IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			units[#units + 1] = "raid" .. index
		end
	else
		units[1] = "player"
		if IsInGroup and IsInGroup() then
			for index = 1, GetNumSubgroupMembers() do
				units[#units + 1] = "party" .. index
			end
		end
	end
	return units
end

local function isCurrentGroupSender(sender)
	if not canonical(sender) then
		return false
	end
	for _, unit in ipairs(collectUnits()) do
		local fullName, name = Util.GetUnitFullName(unit)
		if senderMatchesUnit(sender, fullName, name) then
			return true
		end
	end
	return false
end

local function isSelfSender(sender)
	local fullName, name = Util.GetUnitFullName("player")
	return senderMatchesUnit(sender, fullName, name)
end

local function hasFreshOwnerSnapshot(service, fullName)
	local currentTime = Util.Now()
	for ownerKey, snapshot in pairs(service.snapshots or {}) do
		if currentTime - (tonumber(snapshot and snapshot.updatedAt) or 0)
				<= MAX_SNAPSHOT_AGE
			and (identifiersMatch(ownerKey, fullName)
				or identifiersMatch(snapshot and snapshot.ownerFullName, fullName))
		then
			return true
		end
	end
	return false
end

local function hasMissingPeerSnapshot(service)
	for _, unit in ipairs(collectUnits()) do
		local fullName, name = Util.GetUnitFullName(unit)
		local identifier = fullName or name
		if identifier and not isSelfSender(identifier)
			and not hasFreshOwnerSnapshot(service, identifier)
		then
			return true
		end
	end
	return false
end

local function canRequestMissingSnapshots(reason)
	return MISSING_SNAPSHOT_REQUEST_REASONS[tostring(reason or "")] == true
end

local function getCurrentSeasonID()
	if not (GF.MythicPlusSeason and GF.MythicPlusSeason.GetSeasonID) then
		return nil
	end
	local ok, seasonID = pcall(
		GF.MythicPlusSeason.GetSeasonID,
		GF.MythicPlusSeason)
	seasonID = ok and tonumber(seasonID) or nil
	return seasonID and seasonID > 0 and seasonID or nil
end

local function cancelPeerResponse(service)
	if service.peerResponseTimer and service.peerResponseTimer.Cancel then
		service.peerResponseTimer:Cancel()
	end
	service.peerResponseTimer = nil
	service.peerResponseGeneration = nil
end

local function roleTable(character)
	local roles = {}
	if type(character and character.roles) == "table" then
		for role, enabled in pairs(character.roles) do
			local key = ROLE_TO_KEY[role]
			if key and enabled == true then
				roles[key] = true
			end
		end
	end
	local key = ROLE_TO_KEY[character and character.role]
	if key then
		roles[key] = true
	end
	return roles
end

local function encodeRoles(character)
	local roles = roleTable(character)
	return (roles.TANK and "T" or "")
		.. (roles.HEAL and "H" or "")
		.. (roles.DPS and "D" or "")
end

local function encodeCurrentSelectedRoles()
	local snapshot = GF.MythicPlusCurrentRoleService
		and GF.MythicPlusCurrentRoleService.GetSnapshot
		and GF.MythicPlusCurrentRoleService:GetSnapshot()
	if not (snapshot and snapshot.rolesReady == true) then
		return ""
	end
	return encodeRoles({ roles = snapshot.roles })
end

local function decodeRoles(value)
	value = tostring(value or "")
	return {
		TANK = value:find("T", 1, true) ~= nil,
		HEAL = value:find("H", 1, true) ~= nil,
		DPS = value:find("D", 1, true) ~= nil,
	}
end

local WIRE_ROLE_BY_ROLE = {
	TANK = "TANK",
	HEAL = "HEALER",
	DPS = "DAMAGER",
}

local function firstRole(roles)
	return WIRE_ROLE_BY_ROLE[Util.FirstRole(roles)] or "NONE"
end

local function keyStateFor(character, isCurrent)
	local hasReadyKey = tonumber(character and (character.challengeModeID or character.mapID))
		and tonumber(character and character.keyLevel)
	if isCurrent and GF.MythicPlusKeystoneCache and GF.MythicPlusKeystoneCache.GetSnapshot then
		local snapshot = GF.MythicPlusKeystoneCache:GetSnapshot()
		local resetAt = Util.GetLastWeeklyResetTimestamp
			and Util.GetLastWeeklyResetTimestamp() or 0
		local updatedAt = tonumber(snapshot and snapshot.updatedAt) or 0
		if resetAt > 0 and updatedAt < resetAt then
			return "unknown"
		end
		if snapshot and snapshot.state == "ready" then
			return hasReadyKey and "ready" or "unknown"
		end
		if snapshot and snapshot.state == "empty" then
			return "empty"
		end
		return "unknown"
	end
	if character and character.keyState == "ready" then
		return hasReadyKey and "ready" or "unknown"
	end
	if character and character.keyState == "empty"
		and character.keystoneKnown == true
	then
		local resetAt = Util.GetLastWeeklyResetTimestamp
			and Util.GetLastWeeklyResetTimestamp() or 0
		local checkedAt = tonumber(character.lastKeyCheckedAt) or 0
		if resetAt <= 0 or checkedAt >= resetAt then
			return "empty"
		end
		return "unknown"
	end
	if character and character.keyState == "unknown" then
		return "unknown"
	end
	if hasReadyKey then
		return "ready"
	end
	return "unknown"
end

local function hasCurrentSeasonRating(character)
	local currentSeasonID = getCurrentSeasonID()
	local ratingSeasonID = tonumber(character and character.ratingSeasonID)
	return currentSeasonID ~= nil
		and ratingSeasonID == currentSeasonID
		and tonumber(character and character.rating) ~= nil
end

local function colorComponent(color, key)
	local value = type(color) == "table" and tonumber(color[key]) or nil
	return value and string.format("%.4f", math.max(0, math.min(1, value))) or ""
end

local function outgoingFields(character, isCurrent)
	Util.NormalizeSpecialization(character)
	local fullName = character.fullName or character.key or character.name
	local name = character.name or (type(fullName) == "string" and fullName:match("^([^-]+)"))
	local realm = character.realm
	local keyState = keyStateFor(character, isCurrent)
	local hasReadyKey = keyState == "ready"
	local hasReadyRating = hasCurrentSeasonRating(character)
	local fields = {
		fullName,
		name,
		realm,
		character.classFile or character.class,
		character.classID,
		character.specID,
		character.specName,
		character.specIcon,
		-- The current-character record carries only a successful GetLFGRoles
		-- snapshot. Alternate characters keep their stored Carpool role set.
		isCurrent and encodeCurrentSelectedRoles() or encodeRoles(character),
		character.carpoolEnabled == true and "1" or "0",
		isCurrent and "1" or "0",
		keyState == "ready" and "R"
			or keyState == "empty" and "E"
			or "U",
		hasReadyKey and (character.challengeModeID or character.mapID) or nil,
		hasReadyKey and character.keyLevel or nil,
		hasReadyKey and character.dungeonName or nil,
		hasReadyKey and character.activityID or nil,
		hasReadyKey and character.groupID or nil,
		hasReadyKey and character.keyUpgradeTrack or nil,
		hasReadyRating and character.rating or nil,
		hasReadyRating and colorComponent(character.ratingColor, "r") or nil,
		hasReadyRating and colorComponent(character.ratingColor, "g") or nil,
		hasReadyRating and colorComponent(character.ratingColor, "b") or nil,
		character.level,
		character.lastKeySeenAt,
		hasReadyRating and character.ratingSeasonID or nil,
	}
	for index = 1, 25 do
		fields[index] = encode(fields[index])
	end
	return fields
end

local function buildMessage(batchID, index, count, character, isCurrent)
	local header = { "S", VERSION, batchID, tostring(index), tostring(count) }
	local fields = outgoingFields(character, isCurrent)
	for fieldIndex = 1, 25 do
		header[#header + 1] = fields[fieldIndex]
	end
	local message = table.concat(header, "|")
	if #message <= MAX_MESSAGE_BYTES then
		return message
	end
	fields[7] = ""
	fields[15] = ""
	header = { "S", VERSION, batchID, tostring(index), tostring(count) }
	for fieldIndex = 1, 25 do
		header[#header + 1] = fields[fieldIndex]
	end
	message = table.concat(header, "|")
	return #message <= MAX_MESSAGE_BYTES and message or nil
end

local function normalizeInteger(value, minimum, maximum)
	value = tonumber(value)
	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	value = math.floor(value + 0.5)
	if minimum and value < minimum or maximum and value > maximum then
		return nil
	end
	return value
end

local function normalizeNumber(value, minimum, maximum)
	value = tonumber(value)
	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if minimum and value < minimum or maximum and value > maximum then
		return nil
	end
	return value
end

local function getBestRunSource(character)
	local bestRuns = type(character) == "table" and character.bestRuns or nil
	if type(bestRuns) == "table" and type(bestRuns.runs) == "table" then
		return bestRuns.runs
	end
	return type(bestRuns) == "table" and bestRuns or nil
end

local function buildBestRunRecords(character)
	local records = {}
	local seenMapIDs = {}
	for _, run in ipairs(getBestRunSource(character) or {}) do
		local mapID = normalizeInteger(
			run and (run.mapID or run.challengeModeID or run.mapChallengeModeID),
			1, 100000)
		local level = normalizeInteger(run and (run.level or run.bestRunLevel), 1, 1000)
		local score = normalizeNumber(
			run and (run.score or run.mapScore or run.runScore), 0, 100000)
		local durationMS = normalizeInteger(
			run and (run.durationMS or run.bestRunDurationMS
				or ((tonumber(run.durationSec) or 0) * 1000)),
			0, MAX_RUN_DURATION_MS)
		if mapID and level and score and durationMS and not seenMapIDs[mapID] then
			seenMapIDs[mapID] = true
			records[#records + 1] = table.concat({
				mapID,
				level,
				score,
				durationMS,
				(run.timed == true or run.finishedSuccess == true) and "1" or "0",
			}, ",")
			if #records >= MAX_BEST_RUNS then
				break
			end
		end
	end
	table.sort(records, function(left, right)
		return (tonumber(left:match("^(%d+)")) or 0)
			< (tonumber(right:match("^(%d+)")) or 0)
	end)
	return records
end

local function hasAuthoritativeBestRuns(character)
	local bestRuns = type(character) == "table" and character.bestRuns or nil
	if type(bestRuns) ~= "table" then
		return false
	end
	return bestRuns.state == nil
		or bestRuns.state == "ready"
		or bestRuns.state == "empty"
end

local function buildBestRunPayloadRecords(character)
	if not hasCurrentSeasonRating(character) then
		return nil
	end
	local records = buildBestRunRecords(character)
	if #records > 0 then
		return records
	end
	-- "0" is an optional R-stream empty marker. Older version-2 receivers
	-- reject only this extension and keep consuming the unchanged S record.
	return hasAuthoritativeBestRuns(character) and { "0" } or nil
end

local function splitExtensionPayload(records)
	local payloads = {}
	local current = ""
	for _, record in ipairs(records or {}) do
		local candidate = current == "" and record or (current .. ";" .. record)
		if #candidate > MAX_EXTENSION_PAYLOAD_BYTES then
			if current == "" then
				return nil
			end
			payloads[#payloads + 1] = current
			current = record
		else
			current = candidate
		end
	end
	if current ~= "" then
		payloads[#payloads + 1] = current
	end
	return #payloads <= MAX_EXTENSION_PARTS and payloads or nil
end

local function splitEncodedPayload(payload)
	if type(payload) ~= "string" or payload == "" then
		return nil
	end
	local payloads = {}
	for offset = 1, #payload, MAX_EXTENSION_PAYLOAD_BYTES do
		payloads[#payloads + 1] =
			payload:sub(offset, offset + MAX_EXTENSION_PAYLOAD_BYTES - 1)
		if #payloads > MAX_EXTENSION_PARTS then
			return nil
		end
	end
	return payloads
end

local function buildExtensionMessages(kind, batchID, index, count, payloads)
	if type(payloads) ~= "table" or #payloads == 0
		or #payloads > MAX_EXTENSION_PARTS
	then
		return {}
	end
	local messages = {}
	for partIndex, payload in ipairs(payloads) do
		local message = table.concat({
			kind,
			VERSION,
			batchID,
			tostring(index),
			tostring(count),
			tostring(partIndex),
			tostring(#payloads),
			payload,
		}, "|")
		if #message > MAX_MESSAGE_BYTES then
			return {}
		end
		messages[#messages + 1] = message
	end
	return messages
end

local function buildBestRunMessages(batchID, index, count, character)
	local records = buildBestRunPayloadRecords(character)
	if not records then
		return {}
	end
	return buildExtensionMessages(
		"R", batchID, index, count, splitExtensionPayload(records))
end

local function sanitizeKeystoneLink(value)
	if type(value) ~= "string" or value == ""
		or #value > MAX_KEYSTONE_LINK_BYTES
		or value:find("[%z\1-\31\127]")
	then
		return nil
	end
	local hyperlinkStart = value:find("|Hkeystone:", 1, true)
	if not hyperlinkStart or not value:find("|h", hyperlinkStart, true) then
		return nil
	end
	return value
end

local function buildKeystoneLinkMessages(batchID, index, count, character, isCurrent)
	if keyStateFor(character, isCurrent) ~= "ready" then
		return {}
	end
	local keystoneLink = sanitizeKeystoneLink(character and character.keystoneLink)
	if not keystoneLink then
		return {}
	end
	return buildExtensionMessages(
		"K", batchID, index, count, splitEncodedPayload(encode(keystoneLink)))
end

local function parseExtensionHeader(parts)
	local batchID = tostring(parts[3] or "")
	local index = normalizeInteger(parts[4], 1, MAX_CHARACTERS)
	local count = normalizeInteger(parts[5], 1, MAX_CHARACTERS)
	local partIndex = normalizeInteger(parts[6], 1, MAX_EXTENSION_PARTS)
	local partCount = normalizeInteger(parts[7], 1, MAX_EXTENSION_PARTS)
	local payload = tostring(parts[8] or "")
	if not batchID:match("^[%da-f]+$") or #batchID > 24
		or not index or not count or index > count
		or not partIndex or not partCount or partIndex > partCount
		or payload == "" or #payload > MAX_EXTENSION_PAYLOAD_BYTES
	then
		return nil
	end
	return batchID, index, count, partIndex, partCount, payload
end

local function parseBestRunPayload(payload)
	if payload == "0" then
		return {}
	end
	local runs = {}
	local seenMapIDs = {}
	for record in tostring(payload or ""):gmatch("[^;]+") do
		local mapText, levelText, scoreText, durationText, timedText =
			record:match("^(%d+),(%d+),(%d+%.?%d*),(%d+),([01])$")
		local mapID = normalizeInteger(mapText, 1, 100000)
		local level = normalizeInteger(levelText, 1, 1000)
		local score = normalizeNumber(scoreText, 0, 100000)
		local durationMS = normalizeInteger(durationText, 0, MAX_RUN_DURATION_MS)
		if not (mapID and level and score and durationMS and timedText)
			or seenMapIDs[mapID]
		then
			return nil
		end
		seenMapIDs[mapID] = true
		runs[#runs + 1] = {
			mapID = mapID,
			level = level,
			score = score,
			durationMS = durationMS,
			timed = timedText == "1",
		}
		if #runs > MAX_BEST_RUNS then
			return nil
		end
	end
	return #runs > 0 and runs or nil
end

local function localCharacters()
	local store = GF.MythicPlusCharacterStore
	local current = store and store.GetCurrent and store:GetCurrent()
	if not current then
		return {}
	end
	local broadcastCurrent = {}
	for key, value in pairs(current) do
		broadcastCurrent[key] = value
	end
	local rating = GF.MythicPlusRatingCache
		and GF.MythicPlusRatingCache.GetCurrent
		and GF.MythicPlusRatingCache:GetCurrent()
	local currentSeasonID = getCurrentSeasonID()
	local ratingSeasonID = tonumber(rating and rating.seasonID)
	if rating
		and rating.state == "ready"
		and rating.score ~= nil
		and currentSeasonID
		and ratingSeasonID == currentSeasonID
	then
		broadcastCurrent.rating = rating.score
		broadcastCurrent.ratingColor = rating.scoreColor
		broadcastCurrent.bestRuns = Util.CopyRuns(rating.runs)
		broadcastCurrent.ratingSeasonID = ratingSeasonID
	else
		-- CharacterStore is persistent and may still contain the prior season.
		-- Never advertise that value while the current-season cache is unresolved.
		broadcastCurrent.rating = nil
		broadcastCurrent.ratingColor = nil
		broadcastCurrent.bestRuns = nil
		broadcastCurrent.ratingSeasonID = nil
	end
	local entries = {
		{ data = broadcastCurrent, isCurrent = true },
	}
	local seen = {
		[canonical(current.fullName or current.key or current.name)] = true,
	}
	for _, character in ipairs(store.GetCarpoolCharacters and store:GetCarpoolCharacters() or {}) do
		local isDebugTest = character.isDebugTest == true
			or character.isTest == true
			or character.source == "test"
		if not isDebugTest then
			local identifier = canonical(character.fullName or character.key or character.name)
			if identifier and not seen[identifier] and #entries < MAX_CHARACTERS then
				seen[identifier] = true
				entries[#entries + 1] = { data = character, isCurrent = false }
			end
		end
	end
	return entries
end

local function appendFingerprintField(parts, label, value)
	value = tostring(value or "")
	parts[#parts + 1] = table.concat({
		label,
		tostring(#value),
		value,
	}, ":")
end

local function keyFreshnessFingerprint(character, isCurrent)
	if keyStateFor(character, isCurrent) ~= "ready" then
		return ""
	end
	local seenAt = tonumber(character and character.lastKeySeenAt) or 0
	if seenAt <= 0 then
		return "missing"
	end
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
	if resetAt <= 0 then
		return "seen"
	end
	return seenAt >= resetAt and "current" or "stale"
end

local function buildPayloadFingerprint(entries)
	local parts = {}
	for index, entry in ipairs(entries or {}) do
		appendFingerprintField(parts, "I", index)
		local fields = outgoingFields(entry.data, entry.isCurrent)
		-- The wire still carries the observation timestamp for receiver-side
		-- reset validation. The semantic fingerprint only tracks its weekly
		-- freshness class so same-week refresh metadata cannot cause an echo.
		fields[24] = keyFreshnessFingerprint(
			entry.data, entry.isCurrent)
		appendFingerprintField(parts, "S",
			table.concat(fields, "|"))
		local bestRunRecords = buildBestRunPayloadRecords(entry.data)
		appendFingerprintField(parts, "R",
			bestRunRecords and table.concat(bestRunRecords, ";") or "")
		appendFingerprintField(parts, "K",
			keyStateFor(entry.data, entry.isCurrent) == "ready"
				and sanitizeKeystoneLink(entry.data and entry.data.keystoneLink)
				or nil)
	end
	return table.concat(parts, "\031")
end

local function parseNumber(value, minimum, maximum)
	local number = tonumber(decode(value))
	if not number then
		return nil
	end
	if minimum and number < minimum or maximum and number > maximum then
		return nil
	end
	return number
end

local function parseCharacter(parts)
	local fullName = cleanString(parts[6], 80)
	local name = cleanString(parts[7], 48)
	if not (fullName and name) then
		return nil
	end
	local roles = decodeRoles(decode(parts[14]))
	local stateCode = decode(parts[17])
	local keyState = stateCode == "R" and "ready" or stateCode == "E" and "empty" or "unknown"
	local challengeModeID = parseNumber(parts[18], 1, 100000)
	local keyLevel = parseNumber(parts[19], 1, 1000)
	if keyState == "ready" and not (challengeModeID and keyLevel) then
		keyState = "unknown"
	end
	local r = parseNumber(parts[25], 0, 1)
	local g = parseNumber(parts[26], 0, 1)
	local b = parseNumber(parts[27], 0, 1)
	local ratingSeasonID = parseNumber(parts[30], 1, 100000)
	local currentSeasonID = getCurrentSeasonID()
	local ratingIsCurrent = ratingSeasonID
		and currentSeasonID
		and ratingSeasonID == currentSeasonID
	local rating = ratingIsCurrent
		and parseNumber(parts[24], 0, 100000) or nil
	local character = {
		key = fullName,
		fullName = fullName,
		name = name,
		realm = cleanString(parts[8], 48),
		classFile = cleanString(parts[9], 20),
		classID = parseNumber(parts[10], 1, 100),
		specID = parseNumber(parts[11], 1, 100000),
		specName = cleanString(parts[12], 80),
		specIcon = parseNumber(parts[13], 1, 1000000000),
		roles = roles,
		role = firstRole(roles),
		carpoolEnabled = decode(parts[15]) == "1",
		isCurrent = decode(parts[16]) == "1",
		keyState = keyState,
		challengeModeID = challengeModeID,
		mapID = challengeModeID,
		keyLevel = keyLevel,
		dungeonName = cleanString(parts[20], 100),
		activityID = parseNumber(parts[21], 1, 1000000),
		groupID = parseNumber(parts[22], 1, 1000000),
		keyUpgradeTrack = cleanString(parts[23], 40),
		rating = rating,
		ratingColor = rating
			and r and g and b
			and { r = r, g = g, b = b, a = 1 }
			or nil,
		ratingSeasonID = ratingSeasonID,
		level = parseNumber(parts[28], 1, 1000),
		lastKeySeenAt = parseNumber(parts[29], 0, 99999999999),
		updatedAt = Util.Now(),
		source = "group-snapshot",
	}
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and Util.GetLastWeeklyResetTimestamp() or 0
	if character.keyState == "ready" and resetAt > 0
		and (tonumber(character.lastKeySeenAt) or 0) < resetAt
	then
		character.keyState = "unknown"
	end
	if character.keyState ~= "ready" then
		character.challengeModeID = nil
		character.mapID = nil
		character.keyLevel = nil
		character.dungeonName = nil
		character.activityID = nil
		character.groupID = nil
		character.keyUpgradeTrack = nil
	end
	Util.NormalizeSpecialization(character)
	return character
end

local function ownerShortName(sender)
	return type(sender) == "string" and sender:match("^([^-]+)") or sender
end

local function makePendingRoom(pendingTable, ownerKey, perOwnerLimit, globalLimit)
	local ownerEntries = {}
	local allEntries = {}
	for key, pending in pairs(pendingTable or {}) do
		local entry = {
			key = key,
			createdAt = tonumber(pending.createdAt) or 0,
		}
		allEntries[#allEntries + 1] = entry
		if pending.ownerKey == ownerKey then
			ownerEntries[#ownerEntries + 1] = entry
		end
	end
	local function sortOldest(left, right)
		if left.createdAt == right.createdAt then
			return tostring(left.key) < tostring(right.key)
		end
		return left.createdAt < right.createdAt
	end
	table.sort(ownerEntries, sortOldest)
	while #ownerEntries >= perOwnerLimit do
		local entry = table.remove(ownerEntries, 1)
		if pendingTable[entry.key] then
			pendingTable[entry.key] = nil
			for index = #allEntries, 1, -1 do
				if allEntries[index].key == entry.key then
					table.remove(allEntries, index)
					break
				end
			end
		end
	end
	table.sort(allEntries, sortOldest)
	while #allEntries >= globalLimit do
		pendingTable[table.remove(allEntries, 1).key] = nil
	end
end

local function prunePending(service)
	local currentTime = Util.Now()
	local generation = tonumber(service.groupGeneration) or 0
	local channel = service.groupChannel
	local signature = service.groupSignature
	for pendingKey, pending in pairs(service.pending or {}) do
		if currentTime - (tonumber(pending.createdAt) or currentTime) >= MAX_PENDING_AGE
			or pending.groupGeneration ~= generation
			or pending.groupChannel ~= channel
			or pending.groupSignature ~= signature
			or not isCurrentGroupSender(pending.ownerFullName or pending.ownerKey)
		then
			service.pending[pendingKey] = nil
		end
	end
	for pendingKey, pending in pairs(service.extensionPending or {}) do
		if currentTime - (tonumber(pending.createdAt) or currentTime) >= MAX_PENDING_AGE
			or pending.groupGeneration ~= generation
			or pending.groupChannel ~= channel
			or pending.groupSignature ~= signature
			or not isCurrentGroupSender(pending.ownerFullName or pending.ownerKey)
		then
			service.extensionPending[pendingKey] = nil
		end
	end
end

local function getExtensionPending(service, sender, batchID, count)
	local ownerKey = canonical(sender)
	if not ownerKey then
		return nil
	end
	local pendingKey = ownerKey .. "\031" .. batchID
	service.extensionPending = service.extensionPending or {}
	local pending = service.extensionPending[pendingKey]
	if pending and pending.count ~= count then
		return nil
	end
	if not pending then
		makePendingRoom(
			service.extensionPending,
			ownerKey,
			MAX_EXTENSION_BATCHES_PER_OWNER,
			MAX_EXTENSION_BATCHES)
		pending = {
			ownerKey = ownerKey,
			ownerFullName = sender,
			batchID = batchID,
			count = count,
			characters = {},
			createdAt = Util.Now(),
			payloadBytes = 0,
			groupGeneration = service.groupGeneration,
			groupChannel = service.groupChannel,
			groupSignature = service.groupSignature,
		}
		service.extensionPending[pendingKey] = pending
		service:SchedulePendingExpiry()
	end
	return pending, pendingKey
end

local function storeExtensionPart(pending, characterIndex, kind,
		partIndex, partCount, payload)
	if pending.invalid then
		return false
	end
	local character = pending.characters[characterIndex]
	if not character then
		character = {}
		pending.characters[characterIndex] = character
	end
	local streamKey = kind == "R" and "bestRuns" or "keystoneLink"
	local stream = character[streamKey]
	if stream and stream.partCount ~= partCount then
		stream.invalid = true
		return false
	end
	if not stream then
		stream = {
			partCount = partCount,
			parts = {},
			received = 0,
		}
		character[streamKey] = stream
	end
	if stream.invalid or stream.applied then
		return false
	end
	local previous = stream.parts[partIndex]
	if previous ~= nil then
		if previous ~= payload then
			stream.invalid = true
		end
		return false
	end
	if (tonumber(pending.payloadBytes) or 0) + #payload
		> MAX_EXTENSION_BYTES_PER_BATCH
	then
		pending.invalid = true
		return false
	end
	stream.parts[partIndex] = payload
	stream.received = stream.received + 1
	pending.payloadBytes = (tonumber(pending.payloadBytes) or 0) + #payload
	return true
end

local function assembleExtensionStream(stream, separator)
	if not stream or stream.invalid or stream.received ~= stream.partCount then
		return nil
	end
	local parts = {}
	for partIndex = 1, stream.partCount do
		local payload = stream.parts[partIndex]
		if type(payload) ~= "string" or payload == "" then
			return nil
		end
		parts[partIndex] = payload
	end
	return table.concat(parts, separator or "")
end

local function primeRunScoreColors(runs)
	local cache = GF.MythicPlusRatingCache
	if cache and cache.PrimeRunScoreColors then
		pcall(cache.PrimeRunScoreColors, cache, runs)
	end
end

local function applyExtensionPending(service, pending, snapshot)
	if not (pending and snapshot) or pending.invalid
		or snapshot._gfmpBatchID ~= pending.batchID
		or snapshot._gfmpCharacterCount ~= pending.count
		or Util.Now() - (tonumber(pending.createdAt) or 0) >= MAX_PENDING_AGE
		or Util.Now() - (tonumber(snapshot.updatedAt) or 0) > MAX_SNAPSHOT_AGE
		or pending.groupGeneration ~= service.groupGeneration
		or pending.groupChannel ~= service.groupChannel
		or pending.groupSignature ~= service.groupSignature
		or snapshot._gfmpGroupGeneration ~= pending.groupGeneration
		or snapshot._gfmpGroupChannel ~= pending.groupChannel
		or snapshot._gfmpGroupSignature ~= pending.groupSignature
	then
		return false
	end
	local changed = false
	for characterIndex, extension in pairs(pending.characters or {}) do
		local character = snapshot.characters and snapshot.characters[characterIndex]
		if character then
				local bestRunStream = extension.bestRuns
				if bestRunStream and not bestRunStream.applied and not bestRunStream.invalid then
					local payload = assembleExtensionStream(bestRunStream, ";")
					if payload then
						local currentSeasonID = getCurrentSeasonID()
						if currentSeasonID
							and tonumber(character.ratingSeasonID) == currentSeasonID
							and character.rating ~= nil
						then
							local runs = parseBestRunPayload(payload)
							if runs then
								character.bestRuns = runs
								bestRunStream.applied = true
								primeRunScoreColors(runs)
								changed = true
							else
								bestRunStream.invalid = true
							end
						else
							-- Version-2 peers predating the optional season field
							-- may still send R records. Consume but never attach
							-- unscoped records to the current-season snapshot.
							bestRunStream.applied = true
						end
					end
				end
			local linkStream = extension.keystoneLink
			if linkStream and not linkStream.applied and not linkStream.invalid then
				local payload = assembleExtensionStream(linkStream)
				if payload then
					local keystoneLink = sanitizeKeystoneLink(decode(payload))
					if keystoneLink then
						linkStream.applied = true
						if character.keyState == "ready"
							and character.keystoneLink ~= keystoneLink
						then
							character.keystoneLink = keystoneLink
							changed = true
						end
					else
						linkStream.invalid = true
					end
				end
			end
		end
	end
	return changed
end

local function notifyExtensionApplied(service, reason)
	Util.Notify(service, reason)
	if GF.MythicPlusRosterCache and GF.MythicPlusRosterCache.RequestRefresh then
		GF.MythicPlusRosterCache:RequestRefresh(reason)
	end
end

local function applyCurrentSnapshotRating(snapshot, reason)
	local current = snapshot and snapshot.currentCharacter
	local currentSeasonID = getCurrentSeasonID()
	if current
		and current.rating ~= nil
		and currentSeasonID
		and tonumber(current.ratingSeasonID) == currentSeasonID
		and GF.MythicPlusRatingCache
		and GF.MythicPlusRatingCache.ApplyPeerRating
	then
		GF.MythicPlusRatingCache:ApplyPeerRating(
			current.fullName or snapshot.ownerFullName,
			{
				score = current.rating,
				runs = current.bestRuns,
				seasonID = current.ratingSeasonID,
				fullName = current.fullName,
				reason = reason or "group-snapshot",
				source = "group-snapshot",
			})
	end
end

local function receiveExtension(service, kind, parts, sender)
	local batchID, characterIndex, count, partIndex, partCount, payload =
		parseExtensionHeader(parts)
	if not batchID then
		return
	end
	local pending = getExtensionPending(service, sender, batchID, count)
	if not pending
		or not storeExtensionPart(
			pending, characterIndex, kind, partIndex, partCount, payload)
	then
		return
	end
	local snapshot = service.snapshots and service.snapshots[pending.ownerKey]
	if applyExtensionPending(service, pending, snapshot) then
		local reason = kind == "R"
			and "received-best-runs" or "received-keystone-link"
		if kind == "R" then
			applyCurrentSnapshotRating(snapshot, "group-snapshot-best-runs")
		end
		notifyExtensionApplied(service, reason)
	end
end

function Service:AddListener(callback)
	Util.AddListener(self, callback)
end

function Service:ApplyGroupContext(
	channel, signature, generation, reason)
	local changed = not self.groupContextInitialized
		or generation ~= self.groupGeneration
	self.groupContextInitialized = true
	local snapshotsChanged = false
	if changed then
		self.groupGeneration = tonumber(generation) or 0
		self.groupChannel = channel
		self.groupSignature = signature
		self.pending = {}
		self.extensionPending = {}
		self.lastPayloadFingerprint = nil
		-- A transport generation is a new delivery context. Acquire peer
		-- snapshots once even when an older owner snapshot was preserved.
		self.peerRequestNeededGeneration =
			channel and self.groupGeneration or nil
		self.lastPeerRequestGeneration = nil
		self.lastPeerRequestAt = nil
		cancelPeerResponse(self)
		if self.pendingExpiryTimer and self.pendingExpiryTimer.Cancel then
			self.pendingExpiryTimer:Cancel()
		end
		self.pendingExpiryTimer = nil
		for ownerKey in pairs(self.snapshots or {}) do
			if not isCurrentGroupSender(ownerKey) then
				self.snapshots[ownerKey] = nil
				snapshotsChanged = true
			end
		end
	else
		self.groupChannel = channel
		self.groupSignature = signature
	end
	if snapshotsChanged then
		Util.Notify(self, reason or "group-context-prune")
		if GF.MythicPlusRosterCache and GF.MythicPlusRosterCache.RequestRefresh then
			GF.MythicPlusRosterCache:RequestRefresh("group-snapshot-prune")
		end
		self:ScheduleSnapshotExpiry()
	end
	return channel, signature, self.groupGeneration, changed
end

function Service:RefreshGroupContext()
	local channel, signature, generation
	if self.transport and self.transport.GetGroupContext then
		channel, signature, generation =
			self.transport:GetGroupContext("gfmp-context")
	end
	return self:ApplyGroupContext(
		channel, signature, generation, "group-context-prune")
end

function Service:SchedulePendingExpiry()
	if self.pendingExpiryTimer and self.pendingExpiryTimer.Cancel then
		self.pendingExpiryTimer:Cancel()
	end
	self.pendingExpiryTimer = nil
	if not (C_Timer and C_Timer.NewTimer) then
		return
	end
	local currentTime = Util.Now()
	local nextDelay
	for _, pendingTable in ipairs({
		self.pending or {},
		self.extensionPending or {},
	}) do
		for _, pending in pairs(pendingTable) do
			local delay = MAX_PENDING_AGE
				- (currentTime - (tonumber(pending.createdAt) or currentTime))
			if not nextDelay or delay < nextDelay then
				nextDelay = delay
			end
		end
	end
	if nextDelay then
		self.pendingExpiryTimer = C_Timer.NewTimer(
			math.max(0.1, nextDelay + 0.05),
			function()
				Service.pendingExpiryTimer = nil
				prunePending(Service)
				Service:SchedulePendingExpiry()
			end)
	end
end

function Service:GetOwnerSnapshots()
	local entries = {}
	local currentTime = Util.Now()
	for _, snapshot in pairs(self.snapshots or {}) do
		if currentTime - (tonumber(snapshot.updatedAt) or 0) <= MAX_SNAPSHOT_AGE then
			entries[#entries + 1] = snapshot
		end
	end
	table.sort(entries, function(left, right)
		return tostring(left.ownerName or left.ownerKey) < tostring(right.ownerName or right.ownerKey)
	end)
	return entries
end

function Service:GetAllSnapshots()
	return self:GetOwnerSnapshots()
end

function Service:GetCurrentCharacterForMember(fullName)
	for _, snapshot in pairs(self.snapshots or {}) do
		local current = snapshot.currentCharacter
		if Util.Now() - (tonumber(snapshot.updatedAt) or 0) <= MAX_SNAPSHOT_AGE
			and current and identifiersMatch(current.fullName or current.name, fullName)
		then
			return current, snapshot
		end
	end
	return nil
end

function Service:Prune(reason)
	self:RefreshGroupContext()
	local changed = false
	for ownerKey in pairs(self.snapshots or {}) do
		local snapshot = self.snapshots[ownerKey]
		if not isCurrentGroupSender(ownerKey)
			or Util.Now() - (tonumber(snapshot and snapshot.updatedAt) or 0) > MAX_SNAPSHOT_AGE
		then
			self.snapshots[ownerKey] = nil
			changed = true
		end
	end
	prunePending(self)
	self:SchedulePendingExpiry()
	if changed then
		Util.Notify(self, reason or "prune")
		if GF.MythicPlusRosterCache and GF.MythicPlusRosterCache.RequestRefresh then
			GF.MythicPlusRosterCache:RequestRefresh("group-snapshot-prune")
		end
		if reason == "snapshot-expired"
			and hasMissingPeerSnapshot(self)
			and self.QueuePeerRequest
		then
			-- A generation normally asks only once. An actually expired lease
			-- earns one recovery request; a non-addon member cannot keep page
			-- refreshes sending Q forever.
			self.peerRequestNeededGeneration = self.groupGeneration
			self:QueuePeerRequest(reason)
		end
	end
	self:ScheduleSnapshotExpiry()
end

function Service:ScheduleSnapshotExpiry()
	if self.snapshotExpiryTimer and self.snapshotExpiryTimer.Cancel then
		self.snapshotExpiryTimer:Cancel()
	end
	self.snapshotExpiryTimer = nil
	if not (C_Timer and C_Timer.NewTimer) then
		return
	end
	local currentTime = Util.Now()
	local nextDelay
	for _, snapshot in pairs(self.snapshots or {}) do
		local delay = MAX_SNAPSHOT_AGE - (currentTime - (tonumber(snapshot.updatedAt) or 0))
		if delay > 0 and (not nextDelay or delay < nextDelay) then
			nextDelay = delay
		end
	end
	if nextDelay then
		self.snapshotExpiryTimer = C_Timer.NewTimer(nextDelay + 0.1, function()
			Service.snapshotExpiryTimer = nil
			Service:Prune("snapshot-expired")
		end)
	end
end

function Service:ScheduleRenewal()
	local channel, _, generation = self:RefreshGroupContext()
	if not channel then
		if self.renewTimer and self.renewTimer.Cancel then
			self.renewTimer:Cancel()
		end
		self.renewTimer = nil
		self.renewGeneration = nil
		return
	end
	if self.renewTimer and self.renewGeneration == generation then
		return
	end
	if self.renewTimer and self.renewTimer.Cancel then
		self.renewTimer:Cancel()
	end
	self.renewTimer = nil
	self.renewGeneration = generation
	if not (C_Timer and C_Timer.NewTimer) then
		self.renewGeneration = nil
		return
	end
	local timer
	timer = C_Timer.NewTimer(RENEW_INTERVAL, function()
		if Service.renewTimer ~= timer
			or Service.renewGeneration ~= generation
		then
			return
		end
		Service.renewTimer = nil
		Service.renewGeneration = nil
		-- Renew only our lease; peers do not need to answer a Q every five
		-- minutes.
		Service:QueueBroadcast("lease-renew")
		Service:ScheduleRenewal()
	end)
	self.renewTimer = timer
end

function Service:QueueMessages(messages, kind)
	local channel, signature = self:RefreshGroupContext()
	if not (channel and signature and self.prefixRegistered
		and self.transport and self.transport.QueueMessages)
	then
		return false
	end
	return self.transport:QueueMessages(messages, {
		maxBytes = MAX_MESSAGE_BYTES,
		replaceKey = kind,
		priority = kind == "request" and "normal" or "bulk",
		onFinish = function(status, reason)
			if kind == "snapshot"
				and (status == "failed"
					or status == "discarded" and reason ~= "replaced")
			then
				Service.lastPayloadFingerprint = nil
			end
		end,
	})
end

function Service:Broadcast(reason, force)
	if not self.prefixRegistered then
		return false
	end
	local channel = self:RefreshGroupContext()
	if not channel then
		return false
	end
	local entries = localCharacters()
	if #entries == 0 then
		return false
	end
	local fingerprint = buildPayloadFingerprint(entries)
	force = force == true
		or reason == "peer-request"
		or reason == "lease-renew"
		or reason == "request"
	-- CharacterStore/RatingCache also gate semantic changes. This stable wire
	-- fingerprint is the final guard against a receive -> refresh -> send echo.
	if not force and fingerprint == self.lastPayloadFingerprint then
		self.lastSuppressedBroadcastAt = Util.Now()
		self.lastSuppressedBroadcastReason = reason
		return false
	end
	self.sequence = (tonumber(self.sequence) or 0) + 1
	local batchID = string.format("%x%x", Util.Now() % 1048576, self.sequence % 4096)
	local baseMessages = {}
	local extensionMessages = {}
	local function appendMessages(source)
		for _, message in ipairs(source or {}) do
			extensionMessages[#extensionMessages + 1] = message
		end
	end
	for index, entry in ipairs(entries) do
		local message = buildMessage(batchID, index, #entries, entry.data, entry.isCurrent)
		if not message then
			return false
		end
		baseMessages[index] = message
		appendMessages(buildBestRunMessages(
			batchID, index, #entries, entry.data))
		appendMessages(buildKeystoneLinkMessages(
			batchID, index, #entries, entry.data, entry.isCurrent))
	end
	local messages = baseMessages
	-- Base S records are required by both old and new receivers, so keep them at
	-- the front of the paced queue. Optional extensions can arrive later and
	-- attach only to this exact batch.
	for _, message in ipairs(extensionMessages) do
		messages[#messages + 1] = message
	end
	local sent = self:QueueMessages(messages, "snapshot")
	if sent then
		self.lastPayloadFingerprint = fingerprint
		self.lastBroadcastAt = Util.Now()
		self.lastBroadcastReason = reason
		if self.peerResponseGeneration == self.groupGeneration then
			cancelPeerResponse(self)
		end
	end
	return sent
end

function Service:ShouldRequestPeers(reason)
	local generation = tonumber(self.groupGeneration) or 0
	if self.peerRequestNeededGeneration == generation then
		return true
	end
	if not canRequestMissingSnapshots(reason)
		or not hasMissingPeerSnapshot(self)
	then
		return false
	end
	return self.lastPeerRequestGeneration ~= generation
end

function Service:QueuePeerRequest(reason)
	if not self:ShouldRequestPeers(reason) then
		return false
	end
	local sent = self:QueueMessages(
		{ table.concat({ "Q", VERSION }, "|") },
		"request")
	if sent then
		self.lastPeerRequestGeneration =
			tonumber(self.groupGeneration) or 0
		self.lastPeerRequestAt = Util.Now()
		self.lastPeerRequestReason = reason
		if self.peerRequestNeededGeneration == self.groupGeneration then
			self.peerRequestNeededGeneration = nil
		end
	end
	return sent
end

function Service:RequestSync(reason)
	local channel = self:RefreshGroupContext()
	if not channel then
		if self.transport and self.transport.ClearQueue then
			self.transport:ClearQueue(nil, "left-group")
		end
		self.pending = {}
		self.extensionPending = {}
		self.peerRequestNeededGeneration = nil
		self.lastPeerRequestGeneration = nil
		self.lastPeerRequestAt = nil
		cancelPeerResponse(self)
		self:SchedulePendingExpiry()
		self:ScheduleRenewal()
		if self.snapshots and next(self.snapshots) then
			self.snapshots = {}
			Util.Notify(self, reason or "left-group")
		end
		self:ScheduleSnapshotExpiry()
		return false
	end
	local requested = self:QueuePeerRequest(reason)
	self:ScheduleRenewal()
	return self:Broadcast(reason or "request") or requested
end

function Service:QueueSync(reason)
	if self.syncQueued then
		return
	end
	self.syncQueued = true
	local function run()
		self.syncQueued = nil
		self:Prune(reason)
		self:RequestSync(reason)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(1, run)
	else
		run()
	end
end

function Service:QueuePeerResponse()
	local channel, _, generation = self:RefreshGroupContext()
	if not channel then
		cancelPeerResponse(self)
		return false
	end
	if self.peerResponseTimer
		and self.peerResponseGeneration == generation
	then
		return true
	end
	cancelPeerResponse(self)
	self.peerResponseGeneration = generation
	-- One delayed channel response satisfies every Q received in this window.
	local function run()
		Service.peerResponseTimer = nil
		if Service.peerResponseGeneration ~= Service.groupGeneration then
			Service.peerResponseGeneration = nil
			return
		end
		Service:Broadcast("peer-request", true)
		Service.peerResponseGeneration = nil
	end
	if C_Timer and C_Timer.NewTimer then
		self.peerResponseTimer =
			C_Timer.NewTimer(PEER_RESPONSE_DELAY, run)
	else
		run()
	end
	return true
end

function Service:Receive(text, sender, distribution)
	local channel = self:RefreshGroupContext()
	if distribution ~= "PARTY"
		and distribution ~= "RAID"
		and distribution ~= "INSTANCE_CHAT"
	then
		return
	end
	if not channel or distribution ~= channel then
		return
	end
	prunePending(self)
	self:SchedulePendingExpiry()
	if not (isCurrentGroupSender(sender) and not isSelfSender(sender)) then
		return
	end
	if type(text) ~= "string" or #text > MAX_MESSAGE_BYTES then
		return
	end
	local parts = split(text)
	if parts[2] ~= VERSION then
		return
	end
	if parts[1] == "Q" then
		self:QueuePeerResponse()
		return
	end
	if parts[1] == "R" or parts[1] == "K" then
		receiveExtension(self, parts[1], parts, sender)
		return
	end
	if parts[1] ~= "S" then
		return
	end
	local batchID = tostring(parts[3] or "")
	local index = normalizeInteger(parts[4], 1, MAX_CHARACTERS)
	local count = normalizeInteger(parts[5], 1, MAX_CHARACTERS)
	if not batchID:match("^[%da-f]+$") or #batchID > 24
		or not index or not count
		or index < 1 or index > count
	then
		return
	end
	local character = parseCharacter(parts)
	if not character then
		return
	end
	if character.isCurrent then
		if not identifiersMatch(character.fullName, sender) then
			return
		end
	elseif not character.carpoolEnabled then
		return
	end

	local ownerKey = canonical(sender)
	local pendingKey = ownerKey .. "\031" .. batchID
	self.pending = self.pending or {}
	local pending = self.pending[pendingKey]
	if not pending or pending.count ~= count then
		if pending then
			self.pending[pendingKey] = nil
		end
		makePendingRoom(
			self.pending,
			ownerKey,
			MAX_PENDING_BATCHES_PER_OWNER,
			MAX_PENDING_BATCHES)
		pending = {
			ownerKey = ownerKey,
			ownerFullName = sender,
			ownerName = ownerShortName(sender),
			batchID = batchID,
			count = count,
			entries = {},
			received = 0,
			createdAt = Util.Now(),
			groupGeneration = self.groupGeneration,
			groupChannel = self.groupChannel,
			groupSignature = self.groupSignature,
		}
		self.pending[pendingKey] = pending
		self:SchedulePendingExpiry()
	end
	if not pending.entries[index] then
		pending.received = pending.received + 1
	end
	pending.entries[index] = character
	if pending.received ~= count then
		return
	end

	local current
	local characters = {}
	for entryIndex = 1, count do
		local entry = pending.entries[entryIndex]
		if not entry then
			return
		end
		entry.ownerKey = ownerKey
		entry.ownerFullName = pending.ownerFullName
		entry.ownerName = pending.ownerName
		if entry.isCurrent then
			if current then
				self.pending[pendingKey] = nil
				return
			end
			current = entry
		end
		characters[#characters + 1] = entry
	end
	self.pending[pendingKey] = nil
	self:SchedulePendingExpiry()
	if not current then
		return
	end
	local ownerClass = current.classFile
	for _, entry in ipairs(characters) do
		entry.warbandSourceName = pending.ownerName
		entry.warbandSourceClass = ownerClass
	end
	self.snapshots = self.snapshots or {}
	local snapshot = {
		ownerKey = ownerKey,
		ownerFullName = pending.ownerFullName,
		ownerName = pending.ownerName,
		ownerClass = ownerClass,
		currentCharacter = current,
		characters = characters,
		updatedAt = Util.Now(),
		source = "group-snapshot",
		_gfmpBatchID = batchID,
		_gfmpCharacterCount = count,
		_gfmpGroupGeneration = self.groupGeneration,
		_gfmpGroupChannel = self.groupChannel,
		_gfmpGroupSignature = self.groupSignature,
	}
	self.snapshots[ownerKey] = snapshot
	local extensionPending = self.extensionPending
		and self.extensionPending[pendingKey] or nil
	applyExtensionPending(self, extensionPending, snapshot)
	applyCurrentSnapshotRating(snapshot, "group-snapshot")
	for extensionKey, extension in pairs(self.extensionPending or {}) do
		if extension.ownerKey == ownerKey and extensionKey ~= pendingKey then
			self.extensionPending[extensionKey] = nil
		end
	end
	self:ScheduleSnapshotExpiry()
	Util.Notify(self, "received")
	if GF.MythicPlusRosterCache and GF.MythicPlusRosterCache.RequestRefresh then
		GF.MythicPlusRosterCache:RequestRefresh("group-snapshot")
	end
end

function Service:QueueBroadcast(reason)
	if self.broadcastQueued then
		if reason == "lease-renew" then
			self.broadcastQueuedReason = reason
		end
		return
	end
	self.broadcastQueued = true
	self.broadcastQueuedReason = reason
	local function run()
		self.broadcastQueued = nil
		local queuedReason = self.broadcastQueuedReason
		self.broadcastQueuedReason = nil
		self:Broadcast(queuedReason)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.2, run)
	else
		run()
	end
end

function Service:OnSeasonChanged(reason, seasonID)
	seasonID = tonumber(seasonID) or getCurrentSeasonID()
	if not seasonID then
		return false
	end
	local previousSeasonID = tonumber(self.seasonID)
	self.seasonID = seasonID
	if previousSeasonID == seasonID then
		return false
	end
	if not previousSeasonID then
		-- Ratings received before the season service became ready were
		-- intentionally ignored. Reacquire scoped snapshots once the first
		-- authoritative season ID arrives.
		self.lastPayloadFingerprint = nil
		self.peerRequestNeededGeneration =
			self.groupChannel and self.groupGeneration or nil
		self:QueueSync(reason or "season")
		return true
	end
	local hadSnapshots = self.snapshots and next(self.snapshots) ~= nil
	self.snapshots = {}
	self.pending = {}
	self.extensionPending = {}
	self.lastPayloadFingerprint = nil
	self.peerRequestNeededGeneration =
		self.groupChannel and self.groupGeneration or nil
	cancelPeerResponse(self)
	self:SchedulePendingExpiry()
	self:ScheduleSnapshotExpiry()
	if hadSnapshots then
		Util.Notify(self, reason or "season")
		if GF.MythicPlusRosterCache
			and GF.MythicPlusRosterCache.RequestRefresh
		then
			GF.MythicPlusRosterCache:RequestRefresh("group-snapshot-season")
		end
	end
	self:QueueSync(reason or "season")
	return true
end

function Service:OnRosterChanged(reason, _, isConnected)
	self:RefreshGroupContext()
	if reason == "UNIT_CONNECTION"
		and isConnected == true
		and hasMissingPeerSnapshot(self)
	then
		self.peerRequestNeededGeneration = self.groupGeneration
	end
	self:QueueSync(reason or "roster")
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self.snapshots = self.snapshots or {}
	self.pending = self.pending or {}
	self.extensionPending = self.extensionPending or {}
	self.seasonID = getCurrentSeasonID() or self.seasonID
	if not (Transport and Transport.RegisterProtocol) then
		return
	end
	self.transport = Transport:RegisterProtocol(PREFIX,
		function(_, text, distribution, sender)
			Service:Receive(text, sender, distribution)
		end, {
			channelPolicy = Transport.CHANNEL_POLICY
				and Transport.CHANNEL_POLICY.INSTANCE_FIRST,
			onContextChanged = function(
				channel, signature, generation, reason)
				Service:ApplyGroupContext(
					channel,
					signature,
					generation,
					reason)
			end,
		})
	self.prefixRegistered = self.transport
		and self.transport:IsRegistered() == true
	if not self.prefixRegistered then
		return
	end
	self:RefreshGroupContext()
	if GF.MythicPlusCharacterStore and GF.MythicPlusCharacterStore.AddListener then
		GF.MythicPlusCharacterStore:AddListener(function(_, reason)
			self:QueueBroadcast(reason or "character")
		end)
	end
	self:QueueSync("init")
end
