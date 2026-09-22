local _, GF = ...

-- Account-local annotations. Never persist another character's account identity
-- or publish these records through addon/chat messages.
GF.StarredLeaders = {}
local Service = GF.StarredLeaders
local MAX_NOTE_BYTES = 800
-- Earlier stars stored the comparison spelling as the API/display name.
-- Restore this verified CN realm spelling without changing other realms.
local LEGACY_CN_REALM_NAMES = { ["丽丽(四川)"] = "丽丽（四川）" }

local function text(value)
	if GF.Compat and not GF.Compat.IsAccessibleValue(value) then return nil end
	if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
	return type(value) == "string" and value or nil
end

local function classFile(value)
	value = text(value)
	if not value then return nil end
	value = value:upper()
	return RAID_CLASS_COLORS and RAID_CLASS_COLORS[value] and value or nil
end

function Service:Identity(name)
	name = text(name)
	if not name or #name > 256 or name:find("[|%c]") then return nil end
	local formatName = GF.FormatExternalFullPlayerNameForCopy or GF.NormalizeExternalFullPlayerName
	name = formatName and formatName(name)
	if not name then return nil end
	local character, realm = name:match("^([^%-]+)%-(.+)$")
	if not character or character:find("%s") then return nil end
	realm = realm:gsub("%s", "")
	if realm == "" then return nil end
	local region = type(GetCurrentRegion) == "function" and GetCurrentRegion() or nil
	if type(region) ~= "number" or region <= 0 then return nil end
	if region == 5 then realm = LEGACY_CN_REALM_NAMES[realm] or realm end
	name = character .. "-" .. realm
	-- Keep legacy keys and punctuation-insensitive matching, but never send
	-- that comparison spelling to the UI, saved name, or native chat APIs.
	local identityName = GF.NormalizeExternalFullPlayerName and GF.NormalizeExternalFullPlayerName(name)
	if not identityName then return nil end
	return tostring(region) .. ":" .. identityName:lower(), name
end

local function records()
	local db = GF.GetDB and GF.GetDB()
	return db and type(db.starredLeaders) == "table" and db.starredLeaders or nil
end

function Service:IsRaidWorkspace()
	local view = GF.LFGWorkspaceView
	return view and view.GetWorkspaceID and view:GetWorkspaceID() == GF.WORKSPACE_RAID or false
end

function Service:Get(name)
	local key = self:Identity(name)
	local store = records()
	local record = key and store and store[key]
	if type(record) ~= "table" or type(record.name) ~= "string" then return nil end
	local recordKey, fullName = self:Identity(record.name)
	if recordKey ~= key then return nil end
	return {
		key = key, name = fullName, note = text(record.note) or "",
		addedAt = tonumber(record.addedAt),
		updatedAt = tonumber(record.updatedAt),
		contactInfo = text(record.contactInfo),
		classFilename = classFile(record.classFilename),
	}
end

local function rememberClass(name, value)
	value = classFile(value)
	if not value then return end
	local entry = Service:Get(name)
	if entry and not entry.classFilename then
		-- A verified class belongs to the character, not the current session.
		-- Fill only an existing star; preserve annotations, times and row identity.
		records()[entry.key].classFilename = value
		-- The caller is already building fresh display data. Notifying listeners
		-- here would recursively refresh the list while its snapshot is read.
	end
end

function Service:AddListener(callback)
	self.listeners = self.listeners or {}
	self.listeners[#self.listeners + 1] = callback
end

function Service:NotifyChanged()
	for _, callback in ipairs(self.listeners or {}) do callback() end
end

function Service:Save(name, note, contactInfo, replaceContact, classFilename)
	local key, fullName = self:Identity(name)
	note = text(note)
	if not key then return false, "STARRED_INVALID_NAME" end
	local characters = note and select(2, note:gsub("[^\128-\191]", "")) or 0
	if not note or #note > MAX_NOTE_BYTES or characters > 200 then return false, "STARRED_INVALID_NOTE" end
	note = note:gsub("[%c]", " "):match("^%s*(.-)%s*$")
	local store = records()
	if not store then return false, "STARRED_UNAVAILABLE" end
	local existing = self:Get(fullName)
	if existing and not replaceContact then
		-- A note-only save or a later listing must not replace the saved contact.
		contactInfo = existing.contactInfo
	else
		local supplied = contactInfo ~= nil
		contactInfo = text(contactInfo)
		if replaceContact and supplied and (not contactInfo or #contactInfo > 512) then
			return false, "STARRED_INVALID_CONTACT"
		end
		if contactInfo and #contactInfo <= 512 then
			contactInfo = contactInfo:gsub("[%c]", " "):match("^%s*(.-)%s*$")
			if contactInfo == "" then contactInfo = nil end
		else
			contactInfo = nil
		end
	end
	local now = type(GetServerTime) == "function" and GetServerTime() or nil
	local addedAt
	if existing then
		-- Editing must not turn an unknown legacy addition time into a new one.
		addedAt = existing.addedAt
	else
		addedAt = now
	end
	store[key] = {
		name = fullName, note = note,
		addedAt = addedAt, updatedAt = now,
		contactInfo = contactInfo,
		classFilename = (existing and existing.classFilename) or classFile(classFilename)
			or self:GetFriendClass(fullName),
		-- Keep legacy data inert; a raid name is never a contact address.
		instanceName = type(store[key]) == "table" and store[key].instanceName or nil,
	}
	self:NotifyChanged()
	return true
end

function Service:Remove(name)
	local key = self:Identity(name)
	local store = records()
	if not (key and store and store[key]) then return false end
	store[key] = nil
	self:NotifyChanged()
	return true
end

function Service:Clear()
	local store = records()
	if not store then return false end
	local changed = next(store) ~= nil
	for key in pairs(store) do store[key] = nil end
	if changed then self:NotifyChanged() end
	return true
end

local function sortTimestamp(value)
	if type(value) == "number" and value > 0 and value < math.huge then return value end
end

function Service:List(query, updatedSortDirection)
	query = (text(query) or ""):lower()
	local out = {}
	for key, record in pairs(records() or {}) do
		local entry = type(record) == "table" and self:Get(record.name)
		if entry and entry.key == key
			and (query == "" or entry.name:lower():find(query, 1, true)
				or entry.note:lower():find(query, 1, true)
				or (entry.contactInfo or ""):lower():find(query, 1, true)) then
			out[#out + 1] = entry
		end
	end
	local descending = updatedSortDirection ~= "asc"
	table.sort(out, function(a, b)
		local left, right = sortTimestamp(a.updatedAt), sortTimestamp(b.updatedAt)
		if left ~= right then
			-- Missing or invalid timestamps stay last in both directions.
			if left == nil then return false end
			if right == nil then return true end
			if descending then return left > right end
			return left < right
		end
		return a.key < b.key
	end)
	return out
end

-- Keep the selected time order within both groups; only online/away lead by default.
-- The UI supplies the same presence snapshot used by its icons and tooltips.
function Service:PrioritizeAvailable(entries)
	local available, remaining = {}, {}
	for _, entry in ipairs(entries) do
		local target = (entry.presence == "online" or entry.presence == "away") and available or remaining
		target[#target + 1] = entry
	end
	for _, entry in ipairs(remaining) do available[#available + 1] = entry end
	return available
end

-- UI supplies one coherent presence snapshot; this only sorts detached rows.
local PRESENCE_SORT_RANK = { online = 1, away = 2, busy = 3, offline = 4, unknown = 5 }
function Service:SortByPresence(entries, direction)
	if direction ~= "asc" and direction ~= "desc" then return entries end
	table.sort(entries, function(a, b)
		local left = PRESENCE_SORT_RANK[a.presence] or PRESENCE_SORT_RANK.unknown
		local right = PRESENCE_SORT_RANK[b.presence] or PRESENCE_SORT_RANK.unknown
		if left ~= right then
			if direction == "desc" then return left > right end
			return left < right
		end
		return a.key < b.key
	end)
	return entries
end

function Service:DisplayText(value)
	-- gsub also returns a replacement count; UI callers need only the string.
	local displayText = (text(value) or ""):gsub("|", "||")
	return displayText
end

local function nativeCall(callback, ...)
	if type(callback) ~= "function" then return nil end
	local ok, value = pcall(callback, ...)
	if not ok or not GF.Compat.IsAccessibleValue(value) then return nil end
	return value
end

function Service:GetListingClass(name, resultID)
	local key, fullName = self:Identity(name)
	if not key or not GF.Compat.IsAccessibleValue(resultID)
		or type(resultID) ~= "number" or resultID <= 0 or resultID >= math.huge
		or resultID % 1 ~= 0 then return nil end
	local api = C_LFGList or {}
	local read = GF.Compat.ReadAccessibleField
	local function currentListing()
		local info = nativeCall(api.GetSearchResultInfo, resultID)
		if self:Identity(read(info, "leaderName")) == key
			and read(info, "isDelisted") == false
			and read(info, "censored") ~= true then return info end
	end
	local listing = currentListing()
	if not listing then return nil end
	local function leaderClass(leader)
		local leaderName = text(read(leader, "name"))
		if leaderName then
			if leaderName:find("-", 1, true) then
				if self:Identity(leaderName) ~= key then return nil end
			elseif leaderName:lower() ~= fullName:match("^([^%-]+)"):lower() then
				return nil
			end
		end
		-- This record is explicitly the leader. A short or missing member name
		-- inherits the realm from the verified listing, never the local realm.
		return classFile(read(leader, "classFilename"))
	end
	local value = leaderClass(nativeCall(api.GetSearchResultLeaderInfo, resultID))
	if not value then
		local members = read(listing, "numMembers")
		if type(members) == "number" and members >= 1 and members <= 40 and members % 1 == 0 then
			for index = 1, members do
				local member = nativeCall(api.GetSearchResultPlayerInfo, resultID, index)
				if read(member, "isLeader") == true then
					value = leaderClass(member)
					break
				end
			end
		end
	end
	-- The menu may outlive its listing or a leadership change. Bind only a
	-- readable class from the exact current character to the editor snapshot.
	if value and currentListing() then
		rememberClass(fullName, value)
		return value
	end
end

local function count(callback, ...)
	local value = nativeCall(callback, ...)
	if type(value) ~= "number" or value < 0 or value >= math.huge or value % 1 ~= 0 then return 0 end
	return value
end

local function friendClass(info)
	local read = GF.Compat.ReadAccessibleField
	local value = classFile(read(info, "classFilename"))
	if value then return value end
	local localizedName = text(read(info, "className"))
	if not localizedName then return nil end
	for token in pairs(RAID_CLASS_COLORS or {}) do
		if localizedName == read(LOCALIZED_CLASS_NAMES_MALE, token)
			or localizedName == read(LOCALIZED_CLASS_NAMES_FEMALE, token) then return token end
	end
end

-- One ephemeral snapshot per visible-list refresh, with verified classes also
-- filling existing stars. Never persist presence or infer character identity
-- from a Battle.net account's display name.
local PRESENCE_PRIORITY = { offline = 1, online = 2, busy = 3, away = 4 }

local function whisperAPI(kind)
	local api
	if kind == "character" then
		api = ChatFrameUtil and ChatFrameUtil.SendTell or ChatFrame_SendTell
	elseif kind == "bnet" then
		api = ChatFrameUtil and ChatFrameUtil.SendBNetTell or ChatFrame_SendBNetTell
	end
	return type(api) == "function" and api or nil
end

function Service:IsOnlinePresence(status)
	return status == "online" or status == "away" or status == "busy"
end

function Service:GetPresenceSnapshot()
	local presence, classes, whispers = {}, {}, {}
	local read = GF.Compat.ReadAccessibleField
	local function add(name, connected, away, busy, classFilename, route)
		local key = self:Identity(name)
		if key and classFilename then
			classes[key] = classes[key] or classFilename
			rememberClass(name, classes[key])
		end
		if key and type(connected) == "boolean" then
			-- Match the native friends list: offline first, then AFK, DND, online.
			local status = not connected and "offline" or away == true and "away"
				or busy == true and "busy" or "online"
			if PRESENCE_PRIORITY[status] > (PRESENCE_PRIORITY[presence[key]] or 0) then
				presence[key] = status
			end
			-- Presence alone is not a chat destination. Prefer a confirmed
			-- character-friend route, otherwise use the exact Battle.net friend.
			if connected and route and (not whispers[key] or route.kind == "character") then
				whispers[key] = route
			end
		end
	end
	local friends = C_FriendList or {}
	for index = 1, count(friends.GetNumFriends) do
		local info = nativeCall(friends.GetFriendInfoByIndex, index)
		local name = read(info, "name")
		local _, fullName = self:Identity(name)
		local route = fullName and whisperAPI("character") and { kind = "character", target = fullName }
		add(name, read(info, "connected"), read(info, "afk"), read(info, "dnd"), friendClass(info), route)
	end
	local battleNet = C_BattleNet or {}
	local battleNetCount = nativeCall(BNConnected) == true and count(BNGetNumFriends) or 0
	for friendIndex = 1, battleNetCount do
		local account = nativeCall(battleNet.GetFriendAccountInfo, friendIndex)
		local accountAway = read(account, "isAFK") == true
		local accountBusy = read(account, "isDND") == true
		local appearOffline = read(account, "appearOffline") == true
		local accountID = read(account, "bnetAccountID")
		local accountName = text(read(account, "accountName"))
		local route
		if read(account, "isFriend") == true and type(accountID) == "number"
			and accountID > 0 and accountID < math.huge and accountID % 1 == 0
			and accountName and accountName:find("%S") and not accountName:find("[|%c]")
			and whisperAPI("bnet") then
			-- Use the same target as the native friends frame, never a character
			-- name or a guessed BattleTag. This data lives only in this snapshot.
			route = { kind = "bnet", target = accountName, accountID = accountID }
		end
		for accountIndex = 1, count(battleNet.GetFriendNumGameAccounts, friendIndex) do
			local info = nativeCall(battleNet.GetFriendGameAccountInfo, friendIndex, accountIndex)
			if read(info, "clientProgram") == "WoW"
				and type(WOW_PROJECT_MAINLINE) == "number"
				and read(info, "wowProjectID") == WOW_PROJECT_MAINLINE
				and read(info, "isInCurrentRegion") == true then
				local name, realm = text(read(info, "characterName")), text(read(info, "realmName"))
				if name and name ~= "" and realm and realm ~= "" then
					local online = read(info, "isOnline")
					if appearOffline or read(info, "isAppearOffline") == true then online = false end
					add(name .. "-" .. realm, online,
						accountAway or read(info, "isGameAFK") == true,
						accountBusy or read(info, "isGameBusy") == true, friendClass(info), route)
				end
			end
		end
	end
	return presence, classes, whispers
end

function Service:GetWhisperRoute(name, whispers, presence)
	local key, fullName = self:Identity(name)
	if not key then return nil end
	if not whispers or not presence then
		local currentPresence, _, currentWhispers = self:GetPresenceSnapshot()
		presence, whispers = currentPresence, currentWhispers
	end
	if presence[key] == "offline" then return nil end
	if whispers[key] then return whispers[key] end
	-- Unknown presence is not proof of being offline. Let the player try a
	-- character whisper without inventing an online state or a Battle.net ID.
	if whisperAPI("character") then return { kind = "character", target = fullName } end
end

function Service:GetFriendClass(name, classes)
	local key = self:Identity(name)
	if not key then return nil end
	if not classes then
		local _, snapshot = self:GetPresenceSnapshot()
		classes = snapshot
	end
	return classes[key]
end

function Service:GetPresence(name, snapshot)
	local key = self:Identity(name)
	if not key then return "unknown" end
	return (snapshot or self:GetPresenceSnapshot())[key] or "unknown"
end

function Service:AddFriend(name)
	local _, fullName = self:Identity(name)
	if not fullName or not self:Get(fullName) or self:GetPresence(fullName) ~= "unknown" then return false end
	local addFriend = C_FriendList and C_FriendList.AddFriend
	if type(addFriend) ~= "function" then return false end
	-- A click dispatches the native request. Only friend updates establish presence.
	return pcall(addFriend, fullName)
end

function Service:OpenWhisper(name)
	local _, fullName = self:Identity(name)
	if not fullName or not self:Get(fullName) then return false end
	-- Rebuild on click: block a newly offline character and discard stale
	-- Battle.net destinations; unknown characters may still be whispered.
	local route = self:GetWhisperRoute(fullName)
	local sendTell = route and whisperAPI(route.kind)
	if not sendTell then return false end
	-- Opens an empty native whisper input; only the player sends its contents.
	return pcall(sendTell, route.target)
end
