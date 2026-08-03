local _, GF = ...

GF.MythicPlusKeystoneInteropService =
	GF.MythicPlusKeystoneInteropService or {}
local Service = GF.MythicPlusKeystoneInteropService
local Util = GF.MythicPlusServiceUtil
local Transport = GF.AddonMessageTransport

local LIBKEYSTONE_PREFIX = "LibKS"
local MAX_RECORD_AGE = 15 * 60
local RENEW_INTERVAL = 5 * 60
local REQUEST_COOLDOWN = 5
local MAX_KEY_LEVEL = 1000
local MAX_CHALLENGE_MODE_ID = 100000
local MAX_RATING = 100000
local MAX_KEYSTONE_LINK_BYTES = 512
local MAX_CHAT_TEXT_BYTES = 4096
local MAX_CHAT_LINK_FIELDS = 16
local KEYSTONE_LINK_MARKER = "|Hkeystone:"
local CHAT_LINK_SOURCE = "group-chat-claim"

local CHAT_KEYSTONE_EVENTS = {
	CHAT_MSG_PARTY = true,
	CHAT_MSG_PARTY_LEADER = true,
	CHAT_MSG_RAID = true,
	CHAT_MSG_RAID_LEADER = true,
	CHAT_MSG_INSTANCE_CHAT = true,
	CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}

local SOURCE_DEFS = {
	libkeystone = {
		priority = 1,
		label = "LibKeystone",
		acceptRating = true,
	},
	libopenraid = {
		priority = 2,
		label = "LibOpenRaid",
	},
	libopenkeystone = {
		priority = 3,
		label = "LibOpenKeystone",
	},
}

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return not ok or secret == true
end

local function canAccessValue(value)
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	return not isSecret(value)
end

local function getUnitGUIDKey(unit)
	if not (UnitGUID and unit) then
		return nil, nil
	end
	local ok, guid = pcall(UnitGUID, unit)
	if not ok or not canAccessValue(guid)
		or type(guid) ~= "string" or guid == ""
	then
		return nil, nil
	end
	return string.lower(guid), guid
end

local function getAccessibleUnitFullName(unit)
	if not (Util and type(Util.GetUnitFullName) == "function") then
		return nil, nil
	end
	local ok, fullName, name = pcall(Util.GetUnitFullName, unit)
	if not ok
		or not canAccessValue(fullName)
		or type(fullName) ~= "string" or fullName == ""
		or not canAccessValue(name)
		or type(name) ~= "string" or name == ""
	then
		return nil, nil
	end
	return fullName, name
end

local function canonical(value)
	if isSecret(value) or type(value) ~= "string" then
		return nil
	end
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("%s+", "")
	return value ~= "" and string.lower(value) or nil
end

local function shortCanonical(value)
	local normalized = canonical(value)
	return normalized and normalized:match("^([^-]+)") or nil
end

local function collectGroupMembers()
	local members = {}
	if not (IsInGroup and IsInGroup()) then
		return members
	end
	local units = {}
	if IsInRaid and IsInRaid() then
		for index = 1, math.min(
			40, tonumber(GetNumGroupMembers and GetNumGroupMembers()) or 0)
		do
			units[#units + 1] = "raid" .. index
		end
	else
		units[1] = "player"
		for index = 1, math.min(
			4, tonumber(GetNumSubgroupMembers
				and GetNumSubgroupMembers()) or 0)
		do
			units[#units + 1] = "party" .. index
		end
	end
	for _, unit in ipairs(units) do
		local fullName, name = getAccessibleUnitFullName(unit)
		local fullKey = canonical(fullName)
		local shortKey = shortCanonical(name or fullName)
		if fullKey and shortKey then
			local guidKey, guid = getUnitGUIDKey(unit)
			local isCurrent = unit == "player"
			local comparable = isCurrent
			if not isCurrent and UnitIsUnit then
				local ok, matches = pcall(UnitIsUnit, unit, "player")
				comparable = ok and canAccessValue(matches)
					and type(matches) == "boolean"
				if comparable then
					isCurrent = matches == true
				end
			end
			if comparable then
				members[#members + 1] = {
					unit = unit,
					fullName = fullName,
					fullKey = fullKey,
					shortKey = shortKey,
					guid = guid,
					guidKey = guidKey,
					isCurrent = isCurrent,
				}
			end
		end
	end
	return members
end

local function resolveCurrentGroupMemberByGUID(identifier)
	if not canAccessValue(identifier)
		or type(identifier) ~= "string" or identifier == ""
	then
		return nil
	end
	local identifierKey = string.lower(identifier)
	for _, member in ipairs(collectGroupMembers()) do
		if member.guidKey == identifierKey then
			return not member.isCurrent and member or nil
		end
	end
	return nil
end

local function resolveCurrentGroupMember(identifier)
	local identifierKey = canonical(identifier)
	if not identifierKey then
		return nil
	end
	local members = collectGroupMembers()
	if identifierKey:find("-", 1, true) then
		for _, member in ipairs(members) do
			if member.fullKey == identifierKey then
				return not member.isCurrent and member or nil
			end
		end
		return nil
	end
	local match
	for _, member in ipairs(members) do
		if member.shortKey == identifierKey then
			if match then
				-- A realm-less sender is unsafe when two current members have
				-- the same short name.
				return nil
			end
			match = member
		end
	end
	return match and not match.isCurrent and match or nil
end

local function normalizeInteger(value, minimum, maximum)
	if isSecret(value) then
		return nil
	end
	value = tonumber(value)
	if not value or value ~= value
		or value == math.huge or value == -math.huge
	then
		return nil
	end
	value = math.floor(value + 0.5)
	if minimum and value < minimum
		or maximum and value > maximum
	then
		return nil
	end
	return value
end

local function isChatMessagingLocked()
	if not (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) then
		return true
	end
	local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
	return not ok or not canAccessValue(locked) or locked ~= false
end

local function isChatLineCensored(lineID)
	if not (C_ChatInfo and C_ChatInfo.IsChatLineCensored) then
		return true
	end
	local ok, censored = pcall(C_ChatInfo.IsChatLineCensored, lineID)
	return not ok or not canAccessValue(censored) or censored ~= false
end

local function parseKeystoneLink(link, payload)
	if type(link) ~= "string" or link == ""
		or #link > MAX_KEYSTONE_LINK_BYTES
		or link:find("[%z\1-\31\127]")
		or type(payload) ~= "string"
		or payload == ""
		or payload:find("[^%d:]")
		or payload:sub(1, 1) == ":"
		or payload:sub(-1) == ":"
		or payload:find("::", 1, true)
		or not payload:find(":", 1, true)
	then
		return nil
	end

	local fields = {}
	for value in payload:gmatch("([^:]+)") do
		fields[#fields + 1] = value
		if #fields > MAX_CHAT_LINK_FIELDS then
			return nil
		end
	end
	if #fields < 3 then
		return nil
	end

	local itemID = normalizeInteger(fields[1], 1)
	local challengeModeID = normalizeInteger(
		fields[2], 1, MAX_CHALLENGE_MODE_ID)
	local mythicLevel = normalizeInteger(fields[3], 1, MAX_KEY_LEVEL)
	local alternateLevel = normalizeInteger(
		fields[#fields], 1, MAX_KEY_LEVEL)
	local keyLevel
	local keyUpgradeTrack
	if mythicLevel and alternateLevel then
		if mythicLevel > alternateLevel then
			keyLevel = mythicLevel
			keyUpgradeTrack = "mythic"
		else
			keyLevel = alternateLevel
			keyUpgradeTrack = "iron"
		end
	elseif mythicLevel then
		keyLevel = mythicLevel
		keyUpgradeTrack = "mythic"
	else
		keyLevel = alternateLevel
		keyUpgradeTrack = "iron"
	end
	if not (itemID and challengeModeID and keyLevel) then
		return nil
	end

	if not (C_Item and C_Item.GetItemInfoInstant
		and C_Item.IsItemKeystoneByID)
	then
		return nil
	end
	-- A bare keystone hyperlink core is not a regular item hyperlink. Resolve
	-- the explicit numeric payload field instead, while retaining the original
	-- fail-closed item identity and keystone-type checks.
	local itemOK, resolvedItemID = pcall(
		C_Item.GetItemInfoInstant, itemID)
	resolvedItemID = itemOK and canAccessValue(resolvedItemID)
		and normalizeInteger(resolvedItemID, 1) or nil
	if resolvedItemID ~= itemID then
		return nil
	end
	local keystoneOK, isKeystone = pcall(
		C_Item.IsItemKeystoneByID, resolvedItemID)
	if not keystoneOK or not canAccessValue(isKeystone)
		or isKeystone ~= true
	then
		return nil
	end

	return {
		keystoneLink = link,
		itemID = itemID,
		challengeModeID = challengeModeID,
		keyLevel = keyLevel,
		keyUpgradeTrack = keyUpgradeTrack,
	}
end

local function getExplicitKeystoneOwner(text)
	local linkStart = text:find(KEYSTONE_LINK_MARKER, 1, true)
	if not linkStart then
		return nil
	end
	local prefix = text:sub(1, linkStart - 1)
	-- Retail item-quality links can use either the legacy |cAARRGGBB
	-- opener or the named-color form |cnIQ4:. Strip only one syntactically
	-- valid opener that is immediately adjacent to the keystone hyperlink.
	prefix = prefix:gsub("|c%x%x%x%x%x%x%x%x$", "")
		:gsub("|cn[A-Za-z][A-Za-z0-9_]*:$", "")
		:gsub("%s+$", "")
	local owner = prefix:match("^(.+)的钥石信息：$")
		or prefix:match("^(.+)的鑰石資訊：$")
		or prefix:match("^(.+)'s keystone:$")
	if owner == "我" then
		-- Both Chinese self-message templates begin with “我的…”.
		return nil
	end
	return owner
end

local function nameMatchesResolvedMember(value, member)
	local valueKey = canonical(value)
	if not (valueKey and member) then
		return false
	end
	if valueKey == member.fullKey then
		return true
	end
	-- A short name can validate an already GUID-resolved live sender, but it
	-- is never used to select or resolve that sender.
	return not valueKey:find("-", 1, true)
		and valueKey == member.shortKey
end

local function explicitOwnerMatchesMember(owner, member)
	return nameMatchesResolvedMember(owner, member)
end

local function preserveKeystoneLinkColorWrapper(
	text, linkStart, linkEnd, coreLink)
	local prefix = text:sub(1, linkStart - 1)
	local opener = prefix:match("(|c%x%x%x%x%x%x%x%x)$")
		or prefix:match("(|cn[A-Za-z][A-Za-z0-9_]*:)$")
	if not opener
		or text:sub(linkEnd + 1, linkEnd + 2) ~= "|r"
	then
		return coreLink
	end
	local completeLink = opener .. coreLink .. "|r"
	return #completeLink <= MAX_KEYSTONE_LINK_BYTES
		and completeLink or coreLink
end

local function extractSingleKeystoneLink(text)
	if not canAccessValue(text)
		or type(text) ~= "string" or text == ""
		or #text > MAX_CHAT_TEXT_BYTES
		or text:find("[%z\1-\31\127]")
	then
		return nil
	end

	local distinct = {}
	local selected
	local searchFrom = 1
	while true do
		local linkStart = text:find(
			KEYSTONE_LINK_MARKER, searchFrom, true)
		if not linkStart then
			break
		end
		local optionsEnd = text:find(
			"|h", linkStart + #KEYSTONE_LINK_MARKER, true)
		if not optionsEnd then
			return nil
		end
		local displayEnd = text:find("|h", optionsEnd + 2, true)
		if not displayEnd then
			return nil
		end
		local payload = text:sub(
			linkStart + #KEYSTONE_LINK_MARKER,
			optionsEnd - 1)
		local displayText = text:sub(optionsEnd + 2, displayEnd - 1)
		if displayText == ""
			or displayText:find(KEYSTONE_LINK_MARKER, 1, true)
		then
			return nil
		end
		local linkEnd = displayEnd + 1
		local coreLink = text:sub(linkStart, linkEnd)
		local parsed = parseKeystoneLink(coreLink, payload)
		if not parsed then
			return nil
		end
		if not distinct[coreLink] then
			distinct[coreLink] = true
			if selected then
				return nil
			end
			-- LinkUtil accepts the bare |H...|h...|h core, but the local
			-- SendChatMessage path does not document reconstructing color
			-- markup. Preserve a complete adjacent wrapper for lossless
			-- re-sharing while keeping validation and deduplication core-only.
			parsed.keystoneLink = preserveKeystoneLinkColorWrapper(
				text,
				linkStart,
				linkEnd,
				coreLink)
			selected = parsed
		end
		searchFrom = displayEnd + 2
	end
	return selected
end

local function findRosterMemberByGUID(guidKey)
	local roster = GF.MythicPlusRosterCache
	if not (guidKey and roster and roster.GetMembers) then
		return nil
	end
	for _, member in ipairs(roster:GetMembers() or {}) do
		local key = member and member.key
		if canAccessValue(key) and type(key) == "string"
			and string.lower(key) == guidKey
		then
			return member
		end
	end
	return nil
end

local function getChatClaim(service, guidKey)
	local claim = guidKey and service.chatLinkClaims
		and service.chatLinkClaims[guidKey] or nil
	if not claim then
		return nil
	end
	local receivedAt = tonumber(claim.receivedAt) or 0
	if Util.Now() - receivedAt > MAX_RECORD_AGE then
		return nil
	end
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
	if resetAt > 0 and receivedAt < resetAt then
		return nil
	end
	return claim
end

local function getSelectedSource(entry)
	local selectedID
	local selected
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
	for sourceID, record in pairs(entry and entry.sources or {}) do
		local definition = SOURCE_DEFS[sourceID]
		if definition
			and Util.Now() - (tonumber(record.receivedAt) or 0)
				<= MAX_RECORD_AGE
			and (resetAt <= 0
				or (tonumber(record.receivedAt) or 0) >= resetAt)
			and (not selected
				or definition.priority
					< SOURCE_DEFS[selectedID].priority)
		then
			selectedID = sourceID
			selected = record
		end
	end
	return selectedID, selected
end

local function effectiveFingerprint(entry)
	local sourceID, record = getSelectedSource(entry)
	if not (sourceID and record) then
		return ""
	end
	return table.concat({
		sourceID,
		tostring(record.challengeModeID or ""),
		tostring(record.keyLevel or ""),
		tostring(record.rating or ""),
	}, "\031")
end

function Service:AddListener(callback)
	Util.AddListener(self, callback)
end

function Service:NotifyChanged(reason)
	Util.Notify(self, reason or "keystone-interop")
	if GF.MythicPlusRosterCache
		and GF.MythicPlusRosterCache.RequestRefresh
	then
		GF.MythicPlusRosterCache:RequestRefresh(
			reason or "keystone-interop")
	end
end

function Service:ClearChatLinkClaims(reason, suppressNotify)
	local changed = self.chatLinkClaims and next(self.chatLinkClaims) ~= nil
	self.chatLinkClaims = {}
	self.seenChatLines = {}
	self:ScheduleExpiry()
	if changed and not suppressNotify then
		self:NotifyChanged(reason or "group-chat-link-clear")
	end
	return changed
end

function Service:GetChatLinkForMember(
	memberKey, challengeModeID, keyLevel)
	if not canAccessValue(memberKey)
		or type(memberKey) ~= "string" or memberKey == ""
	then
		return nil
	end
	local guidKey = string.lower(memberKey)
	local claim = getChatClaim(self, guidKey)
	if not claim then
		return nil
	end
	if not resolveCurrentGroupMemberByGUID(guidKey) then
		return nil
	end
	challengeModeID = normalizeInteger(
		challengeModeID, 1, MAX_CHALLENGE_MODE_ID)
	keyLevel = normalizeInteger(keyLevel, 1, MAX_KEY_LEVEL)
	if not (claim and challengeModeID and keyLevel)
		or claim.challengeModeID ~= challengeModeID
		or claim.keyLevel ~= keyLevel
	then
		return nil
	end
	return {
		keystoneLink = claim.keystoneLink,
		challengeModeID = claim.challengeModeID,
		keyLevel = claim.keyLevel,
		keyUpgradeTrack = claim.keyUpgradeTrack,
		receivedAt = claim.receivedAt,
		lineID = claim.lineID,
		senderGUID = claim.senderGUID,
		fullName = claim.fullName,
		source = CHAT_LINK_SOURCE,
	}
end

function Service:HandleGroupChatMessage(event, ...)
	if not CHAT_KEYSTONE_EVENTS[event] or isChatMessagingLocked() then
		return false
	end
	local text, playerName = ...
	local lineID = select(11, ...)
	local senderGUID = select(12, ...)
	if not canAccessValue(text) or type(text) ~= "string"
		or not canAccessValue(playerName)
		or type(playerName) ~= "string" or playerName == ""
		or not canAccessValue(senderGUID)
		or type(senderGUID) ~= "string" or senderGUID == ""
		or not canAccessValue(lineID)
	then
		return false
	end
	local numericLineID = tonumber(lineID)
	if not numericLineID or numericLineID < 0
		or numericLineID ~= math.floor(numericLineID)
		or numericLineID == math.huge
	then
		return false
	end
	if isChatLineCensored(numericLineID) then
		return false
	end

	local member = resolveCurrentGroupMemberByGUID(senderGUID)
	if not member or not nameMatchesResolvedMember(playerName, member) then
		return false
	end
	local rosterMember = findRosterMemberByGUID(member.guidKey)
	if not rosterMember or rosterMember.isCurrent == true
		or rosterMember.keyState ~= "ready"
	then
		return false
	end
	local currentLink = rosterMember.keystoneLink
	if canAccessValue(currentLink)
		and type(currentLink) == "string" and currentLink ~= ""
		and rosterMember.keystoneLinkSource ~= CHAT_LINK_SOURCE
	then
		-- A GFMP2-provided link remains authoritative. Chat can only fill a
		-- missing link and never replace an existing snapshot link.
		return false
	end

	local parsed = extractSingleKeystoneLink(text)
	if not parsed then
		return false
	end
	local explicitOwner = getExplicitKeystoneOwner(text)
	if explicitOwner
		and not explicitOwnerMatchesMember(explicitOwner, member)
	then
		-- GroupFinder can send a selected character's link from another
		-- account character. Do not bind that explicitly attributed link to
		-- the event sender, even if map and level happen to match.
		return false
	end
	local existingChallengeModeID = normalizeInteger(
		rosterMember.challengeModeID or rosterMember.mapID,
		1,
		MAX_CHALLENGE_MODE_ID)
	local existingKeyLevel = normalizeInteger(
		rosterMember.keyLevel,
		1,
		MAX_KEY_LEVEL)
	if parsed.challengeModeID ~= existingChallengeModeID
		or parsed.keyLevel ~= existingKeyLevel
	then
		-- The link is only a self-asserted chat claim. Requiring it to agree
		-- with the member's already-known key prevents forwarded links from
		-- changing any authoritative key fields.
		return false
	end

	local lineKey = member.guidKey .. "\031" .. tostring(numericLineID)
	self.seenChatLines = self.seenChatLines or {}
	if self.seenChatLines[lineKey] then
		return false
	end
	local receivedAt = Util.Now()
	self.seenChatLines[lineKey] = receivedAt
	self.chatLinkClaims = self.chatLinkClaims or {}
	local previous = getChatClaim(self, member.guidKey)
	self.chatLinkClaims[member.guidKey] = {
		keystoneLink = parsed.keystoneLink,
		challengeModeID = parsed.challengeModeID,
		keyLevel = parsed.keyLevel,
		keyUpgradeTrack = parsed.keyUpgradeTrack,
		itemID = parsed.itemID,
		receivedAt = receivedAt,
		lineID = numericLineID,
		senderGUID = member.guid,
		fullName = member.fullName,
	}
	self:ScheduleExpiry()
	if not previous
		or previous.keystoneLink ~= parsed.keystoneLink
		or previous.challengeModeID ~= parsed.challengeModeID
		or previous.keyLevel ~= parsed.keyLevel
	then
		self:NotifyChanged("group-chat-link")
	end
	return true
end

function Service:AcceptRecord(
	sourceID, identifier, challengeModeID, keyLevel, rating, reason)
	local definition = SOURCE_DEFS[sourceID]
	local member = definition and resolveCurrentGroupMember(identifier)
	if not member then
		return false
	end
	challengeModeID = normalizeInteger(
		challengeModeID, 1, MAX_CHALLENGE_MODE_ID)
	keyLevel = normalizeInteger(keyLevel, 1, MAX_KEY_LEVEL)
	if definition.acceptRating then
		rating = normalizeInteger(rating, 0, MAX_RATING)
	else
		rating = nil
	end

	self.records = self.records or {}
	local entry = self.records[member.fullKey]
	if not entry then
		entry = {
			fullName = member.fullName,
			sources = {},
		}
		self.records[member.fullKey] = entry
	end
	local before = effectiveFingerprint(entry)
	if challengeModeID and keyLevel then
		entry.fullName = member.fullName
		entry.sources[sourceID] = {
			challengeModeID = challengeModeID,
			keyLevel = keyLevel,
			rating = rating,
			receivedAt = Util.Now(),
		}
	else
		-- External 0/0 means only that this source withdrew its fallback.
		-- It is not authoritative evidence that the player has no keystone.
		entry.sources[sourceID] = nil
	end
	if not next(entry.sources) then
		self.records[member.fullKey] = nil
	end
	local after = effectiveFingerprint(self.records[member.fullKey])
	if before ~= after then
		self:NotifyChanged(reason or sourceID)
	end
	self:ScheduleExpiry()
	return challengeModeID ~= nil and keyLevel ~= nil
end

function Service:GetForMember(fullName)
	local key = canonical(fullName)
	local entry = key and self.records and self.records[key] or nil
	local sourceID, record = getSelectedSource(entry)
	if not (sourceID and record) then
		return nil
	end
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
	if resetAt > 0
		and (tonumber(record.receivedAt) or 0) < resetAt
	then
		return nil
	end
	local dungeon = GF.MythicPlusSeason
		and GF.MythicPlusSeason.GetByChallengeModeID
		and GF.MythicPlusSeason:GetByChallengeModeID(
			record.challengeModeID)
		or nil
	return {
		keyState = "ready",
		challengeModeID = record.challengeModeID,
		mapID = record.challengeModeID,
		keyLevel = record.keyLevel,
		rating = record.rating,
		dungeonName = dungeon and dungeon.name or nil,
		activityID = dungeon and dungeon.activityID or nil,
		groupID = dungeon and dungeon.groupID or nil,
		keyObservedAt = record.receivedAt,
		receivedAt = record.receivedAt,
		keystoneLink = nil,
		keystoneReadOnly = true,
		isInteropFallback = true,
		isRosterOnly = true,
		interopSource = sourceID,
		interopLabel = SOURCE_DEFS[sourceID].label,
		source = sourceID,
	}
end

function Service:Clear(reason)
	local changed = self.records and next(self.records) ~= nil
		or self.chatLinkClaims and next(self.chatLinkClaims) ~= nil
	self.records = {}
	self.chatLinkClaims = {}
	self.seenChatLines = {}
	self:ScheduleExpiry()
	if changed then
		self:NotifyChanged(reason or "keystone-interop-clear")
	end
	return changed == true
end

function Service:Prune(reason)
	local members = {}
	local memberGUIDs = {}
	for _, member in ipairs(collectGroupMembers()) do
		if not member.isCurrent then
			members[member.fullKey] = true
			if member.guidKey then
				memberGUIDs[member.guidKey] = true
			end
		end
	end
	local changed = false
	local currentTime = Util.Now()
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
	for memberKey, entry in pairs(self.records or {}) do
		if not members[memberKey] then
			self.records[memberKey] = nil
			changed = true
		else
			local before = effectiveFingerprint(entry)
			local removedSource = false
			for sourceID, record in pairs(entry.sources or {}) do
				if currentTime - (tonumber(record.receivedAt) or 0)
					> MAX_RECORD_AGE
				then
					entry.sources[sourceID] = nil
					removedSource = true
				end
			end
			if not next(entry.sources) then
				self.records[memberKey] = nil
			end
			if removedSource
				or before ~= effectiveFingerprint(self.records[memberKey])
			then
				changed = true
			end
		end
	end
	for guidKey, claim in pairs(self.chatLinkClaims or {}) do
		local receivedAt = tonumber(claim.receivedAt) or 0
		if not memberGUIDs[guidKey]
			or currentTime - receivedAt > MAX_RECORD_AGE
			or resetAt > 0 and receivedAt < resetAt
		then
			self.chatLinkClaims[guidKey] = nil
			changed = true
		end
	end
	for lineKey, seenAt in pairs(self.seenChatLines or {}) do
		if currentTime - (tonumber(seenAt) or 0) > MAX_RECORD_AGE then
			self.seenChatLines[lineKey] = nil
		end
	end
	if changed then
		self:NotifyChanged(reason or "keystone-interop-prune")
	end
	self:ScheduleExpiry()
	return changed
end

function Service:ScheduleExpiry()
	if self.expiryTimer and self.expiryTimer.Cancel then
		self.expiryTimer:Cancel()
	end
	self.expiryTimer = nil
	if not (C_Timer and C_Timer.NewTimer) then
		return
	end
	local nextDelay
	local currentTime = Util.Now()
	for _, entry in pairs(self.records or {}) do
		for _, record in pairs(entry.sources or {}) do
			local delay = MAX_RECORD_AGE
				- (currentTime - (tonumber(record.receivedAt) or 0))
			if delay > 0 and (not nextDelay or delay < nextDelay) then
				nextDelay = delay
			end
		end
	end
	for _, claim in pairs(self.chatLinkClaims or {}) do
		local delay = MAX_RECORD_AGE
			- (currentTime - (tonumber(claim.receivedAt) or 0))
		if delay > 0 and (not nextDelay or delay < nextDelay) then
			nextDelay = delay
		end
	end
	if nextDelay then
		self.expiryTimer = C_Timer.NewTimer(nextDelay + 0.1, function()
			Service.expiryTimer = nil
			Service:Prune("keystone-interop-expired")
		end)
	end
end

function Service:OnChallengeLifecycle(reason)
	return self:ClearChatLinkClaims(
		reason or "challenge-mode-chat-link-clear")
end

local function getLoadedLibrary(name)
	local libStub = _G and _G.LibStub
	if type(libStub) ~= "table"
		or type(libStub.GetLibrary) ~= "function"
	then
		return nil
	end
	local ok, library = pcall(libStub.GetLibrary, libStub, name, true)
	return ok and type(library) == "table" and library or nil
end

local function getOpenRaidChallengeModeID(info)
	return type(info) == "table" and (
		info.challengeMapID
		or info.challengeModeID
		or info.mapChallengeModeID)
		or nil
end

local function getOpenKeystoneChallengeModeID(info)
	return type(info) == "table" and (
		info.challengeMapID
		or info.challengeModeID
		or info.mapChallengeModeID
		or info.mapID)
		or nil
end

function Service.OnLibOpenRaidKeystoneUpdate(unitName, info)
	Service:AcceptRecord(
		"libopenraid",
		unitName,
		getOpenRaidChallengeModeID(info),
		info and info.level,
		nil,
		"libopenraid")
end

local function onLibOpenKeystoneUpdate(_, unitName, info)
	Service:AcceptRecord(
		"libopenkeystone",
		unitName,
		getOpenKeystoneChallengeModeID(info),
		info and info.level,
		nil,
		"libopenkeystone")
end

function Service:TryAttachLibraries()
	local attached = false
	local openRaid = getLoadedLibrary("LibOpenRaid-1.0")
	if openRaid and self.openRaidLibrary ~= openRaid
		and type(openRaid.RegisterCallback) == "function"
	then
		local ok, result = pcall(
			openRaid.RegisterCallback,
			self,
			"KeystoneUpdate",
			"OnLibOpenRaidKeystoneUpdate")
		if ok and result == true then
			self.openRaidLibrary = openRaid
			attached = true
		end
	end

	local openKeystone = getLoadedLibrary("LibOpenKeystone-1.0")
	if openKeystone and self.openKeystoneLibrary ~= openKeystone then
		if type(openKeystone.SetEnabled) == "function" then
			pcall(openKeystone.SetEnabled, true)
		end
		if type(openKeystone.RegisterCallback) == "function" then
			local ok, result = pcall(
				openKeystone.RegisterCallback,
				self,
				"KeystoneUpdate",
				onLibOpenKeystoneUpdate)
			if ok and result == true then
				self.openKeystoneLibrary = openKeystone
				attached = true
			end
		end
	end
	return attached
end

local function isUnsafeToRequest()
	if InCombatLockdown and InCombatLockdown() then
		return true
	end
	if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
		local ok, active = pcall(
			C_ChallengeMode.IsChallengeModeActive)
		if ok and active == true then
			return true
		end
	end
	return false
end

local function getCurrentRating()
	local rating = GF.MythicPlusRatingCache
		and GF.MythicPlusRatingCache.GetCurrent
		and GF.MythicPlusRatingCache:GetCurrent()
	local score = normalizeInteger(
		rating and rating.score, 0, MAX_RATING)
	return score or 0
end

function Service:BuildOwnLibKeystonePayload()
	local snapshot = GF.MythicPlusKeystoneCache
		and GF.MythicPlusKeystoneCache.GetSnapshot
		and GF.MythicPlusKeystoneCache:GetSnapshot()
	if not snapshot or snapshot.state == "pending" then
		return nil
	end
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
	if resetAt > 0
		and (tonumber(snapshot.updatedAt) or 0) < resetAt
	then
		return nil
	end
	local level = snapshot.state == "ready"
		and normalizeInteger(snapshot.level, 1, MAX_KEY_LEVEL)
		or 0
	local challengeModeID = snapshot.state == "ready"
		and normalizeInteger(
			snapshot.challengeModeID, 1, MAX_CHALLENGE_MODE_ID)
		or 0
	if snapshot.state == "ready"
		and not (level and challengeModeID)
	then
		return nil
	end
	return string.format(
		"%d,%d,%d",
		level or 0,
		challengeModeID or 0,
		getCurrentRating())
end

function Service:QueueOwnLibKeystone()
	local payload = self:BuildOwnLibKeystonePayload()
	if not (payload and self.libKeystoneTransport) then
		local shouldRefresh =
			self.pendingOwnLibKeystoneResponse ~= true
		self.pendingOwnLibKeystoneResponse = true
		if shouldRefresh
			and GF.MythicPlusKeystoneCache
			and GF.MythicPlusKeystoneCache.RequestRefresh
		then
			GF.MythicPlusKeystoneCache:RequestRefresh(
				"libkeystone-peer-request")
		end
		return false
	end
	self.pendingOwnLibKeystoneResponse = nil
	if self.pendingOwnLibKeystoneResponseTimer
		and self.pendingOwnLibKeystoneResponseTimer.Cancel
	then
		self.pendingOwnLibKeystoneResponseTimer:Cancel()
	end
	self.pendingOwnLibKeystoneResponseTimer = nil
	return self.libKeystoneTransport:QueueMessages(payload, {
		replaceKey = "libkeystone-response",
		priority = "normal",
		maxAge = 10,
	})
end

function Service:RequestOwnLibKeystoneResponse()
	if self.pendingOwnLibKeystoneResponse == true then
		return false
	end
	self.pendingOwnLibKeystoneResponse = true
	if C_Timer and C_Timer.NewTimer then
		if self.pendingOwnLibKeystoneResponseTimer
			and self.pendingOwnLibKeystoneResponseTimer.Cancel
		then
			self.pendingOwnLibKeystoneResponseTimer:Cancel()
		end
		self.pendingOwnLibKeystoneResponseTimer =
			C_Timer.NewTimer(10, function()
				Service.pendingOwnLibKeystoneResponseTimer = nil
				Service.pendingOwnLibKeystoneResponse = nil
			end)
	end
	if GF.MythicPlusKeystoneCache
		and GF.MythicPlusKeystoneCache.RequestRefresh
	then
		GF.MythicPlusKeystoneCache:RequestRefresh(
			"libkeystone-peer-request")
		return true
	end
	return self:QueueOwnLibKeystone()
end

function Service:ReceiveLibKeystone(
	_, text, distribution, sender)
	if distribution ~= "PARTY"
		or IsInRaid and IsInRaid()
		or isSecret(text)
		or type(text) ~= "string"
		or #text > 64
	then
		return
	end
	local member = resolveCurrentGroupMember(sender)
	if not member then
		return
	end
	if text == "R" then
		self:RequestOwnLibKeystoneResponse()
		return
	end
	local level, challengeModeID, rating =
		text:match("^(%d+),(%d+),(%d+)$")
	if not level then
		return
	end
	self:AcceptRecord(
		"libkeystone",
		member.fullName,
		challengeModeID,
		level,
		rating,
		"libkeystone")
	self:ScheduleExpiry()
end

function Service:ScheduleRenewal()
	if self.renewTimer and self.renewTimer.Cancel then
		self.renewTimer:Cancel()
	end
	self.renewTimer = nil
	if not (IsInGroup and IsInGroup()
		and C_Timer and C_Timer.NewTimer)
	then
		return
	end
	self.renewTimer = C_Timer.NewTimer(RENEW_INTERVAL, function()
		Service.renewTimer = nil
		Service:RequestSync("keystone-interop-renew")
	end)
end

function Service:RequestSync(reason)
	self:TryAttachLibraries()
	self:Prune(reason)
	if not (IsInGroup and IsInGroup()) then
		self.pendingRequest = nil
		self:ScheduleRenewal()
		return false
	end
	if isUnsafeToRequest() then
		self.pendingRequest = reason or true
		self:ScheduleRenewal()
		return false
	end
	local currentTime = GetTime and GetTime() or 0
	if currentTime - (tonumber(self.lastRequestAt)
		or -REQUEST_COOLDOWN) < REQUEST_COOLDOWN
	then
		self:ScheduleRenewal()
		return false
	end
	self.pendingRequest = nil
	self.lastRequestAt = currentTime
	local requested = false
	if self.libKeystoneTransport
		and not (IsInRaid and IsInRaid())
	then
		requested = self.libKeystoneTransport:QueueMessages("R", {
			replaceKey = "libkeystone-request",
			priority = "normal",
			maxAge = 10,
		}) or requested
	end
	local openRaid = self.openRaidLibrary
	if openRaid then
		local method = IsInRaid and IsInRaid()
			and openRaid.RequestKeystoneDataFromRaid
			or openRaid.RequestKeystoneDataFromParty
		if type(method) == "function" then
			local ok, result = pcall(method)
			requested = ok and result ~= false or requested
		end
	end
	local openKeystone = self.openKeystoneLibrary
	if openKeystone
		and type(openKeystone.RequestKeystoneDataFromParty) == "function"
	then
		local ok, result = pcall(
			openKeystone.RequestKeystoneDataFromParty)
		requested = ok and result ~= false or requested
	end
	self:ScheduleRenewal()
	return requested
end

function Service:OnSafeToRequest(reason)
	if self.pendingRequest and not isUnsafeToRequest() then
		self.lastRequestAt = nil
		return self:RequestSync(reason or "keystone-interop-resume")
	end
	return false
end

function Service:OnRosterChanged(reason, _, isConnected)
	-- Protocols do not carry a group generation. Reset on every roster
	-- membership transition so delayed data from the previous party cannot
	-- survive. Role, leader, and connection-only events keep valid leases.
	if reason == "GROUP_ROSTER_UPDATE" then
		self:Clear(reason)
		self.lastRequestAt = nil
		self.pendingRequest = reason
		return self:RequestSync(reason)
	else
		self:Prune(reason)
	end
	if reason == "UNIT_CONNECTION" and isConnected == true then
		self.lastRequestAt = nil
		self.pendingRequest = reason
		return self:RequestSync(reason)
	end
	return false
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self.records = {}
	self.chatLinkClaims = {}
	self.seenChatLines = {}
	if Transport and Transport.RegisterProtocol then
		self.libKeystoneTransport = Transport:RegisterProtocol(
			LIBKEYSTONE_PREFIX,
			function(...)
				Service:ReceiveLibKeystone(...)
			end,
			{
				channelPolicy = Transport.CHANNEL_POLICY.PARTY_ONLY,
			})
	end
	if GF.MythicPlusKeystoneCache
		and GF.MythicPlusKeystoneCache.AddListener
	then
		GF.MythicPlusKeystoneCache:AddListener(function()
			if Service.pendingOwnLibKeystoneResponse then
				Service:QueueOwnLibKeystone()
			end
		end)
	end
	self:TryAttachLibraries()
end
