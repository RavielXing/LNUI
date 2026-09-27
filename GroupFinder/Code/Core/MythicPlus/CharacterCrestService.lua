local _, GF = ...

local Crests = {}
GF.MythicPlusCharacterCrests = Crests

local function number(value)
	if issecretvalue and issecretvalue(value) then return nil end
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then return nil end
	return math.floor(value)
end

local function publicString(value)
	if issecretvalue and issecretvalue(value) then return nil end
	return type(value) == "string" and value ~= "" and value or nil
end

local function publicBoolean(value)
	if issecretvalue and issecretvalue(value) then return nil end
	if type(value) == "boolean" then return value end
end

local function read(method, ...)
	if type(method) ~= "function" then return nil end
	local ok, result = pcall(method, ...)
	if ok then return result end
end

local function savedEntry(snapshot, seasonID, currencyID)
	if type(snapshot) ~= "table" or snapshot.seasonID ~= seasonID
		or type(snapshot.currencies) ~= "table" then return nil end
	local entry = snapshot.currencies[currencyID]
	return type(entry) == "table" and entry or nil
end

local function copyProgress(entry)
	local progress = type(entry) == "table" and entry.seasonProgress
	local earned = type(progress) == "table" and number(progress.totalEarned) or nil
	if earned ~= nil then return { totalEarned = earned, updatedAt = number(progress.updatedAt) } end
end

local function seasonCap(info)
	if type(info) == "table" then
		local capped, maximum = publicBoolean(info.useTotalEarnedForMaxQty), number(info.maxQuantity)
		if capped == true and maximum and maximum > 0 then return "capped", maximum end
		-- Low-level / undiscovered currencies can return false and zero before their limits are available.
		local level, maxLevel = number(read(UnitLevel, "player")), number(read(GetMaxLevelForLatestExpansion))
		if maximum == 0 and capped ~= nil and publicBoolean(info.discovered) == true
			and level and maxLevel and maxLevel > 0 and level >= maxLevel then
			return "unlimited"
		end
	end
	return "unknown"
end

function Crests:UsesSeasonCap(currencyID)
	return GF.MYTHIC_PLUS_SEASON_CAPPED_CURRENCIES[currencyID] == true
end

function Crests:GetCurrencyIDs()
	local season = GF.MythicPlusSeason
	local id = season and number(read(season.GetSeasonID, season))
	return id and GF.MYTHIC_PLUS_CREST_CURRENCIES[id] or {}, id
end

function Crests:IsRelevantCurrency(currencyID)
	if currencyID == nil then return true end
	currencyID = number(currencyID)
	for _, id in ipairs(self:GetCurrencyIDs()) do
		if id == currencyID then return true end
	end
	return false
end

function Crests:GetSeasonCap(currencyID, info)
	local state, maximum = seasonCap(info)
	local _, seasonID = self:GetCurrencyIDs()
	local util = GF.MythicPlusServiceUtil
	local resetAt, now = number(read(util.GetLastWeeklyResetTimestamp)), number(util.Now())
	-- Persist only a verified current-week limit, shared by the account's characters.
	local db = read(GF.GetDB)
	if not (seasonID and resetAt and resetAt > 0 and now and now >= resetAt
		and now < resetAt + 7 * 24 * 60 * 60 and type(db) == "table") then
		return state, maximum
	end
	local mythic = type(db.mythicPlus) == "table" and db.mythicPlus
	local cache = mythic and mythic.currencySeasonCaps
	local sameSeason = type(cache) == "table" and cache.seasonID == seasonID
	if state ~= "unknown" then
		if not mythic then mythic = {}; db.mythicPlus = mythic end
		if not sameSeason or type(cache.currencies) ~= "table" then
			cache = { seasonID = seasonID, currencies = {} }
			mythic.currencySeasonCaps = cache
		end
		cache.currencies[currencyID] = { state = state, maximum = maximum, updatedAt = now }
		return state, maximum
	end
	local saved = sameSeason and type(cache.currencies) == "table" and cache.currencies[currencyID]
	local updatedAt = type(saved) == "table" and number(saved.updatedAt)
	if updatedAt and updatedAt >= resetAt and updatedAt <= now then
		local savedMax = number(saved.maximum)
		if saved.state == "capped" and savedMax and savedMax > 0 then return "capped", savedMax end
		if saved.state == "unlimited" then return "unlimited" end
	end
	return "unknown"
end

function Crests:MergeCurrent(previous)
	local ids, seasonID = self:GetCurrencyIDs()
	local previousAccounts = self.accountSignature
	local signature, caps = {}, { tostring(seasonID or "") }
	self.metadata, self.accountQuantities = {}, {}
	self.accountSeasonID = seasonID
	self.accountChanged, self.capChanged = false, false
	if #ids == 0 then
		self.capChanged = self.capSignature ~= nil
		self.capSignature = nil
		return previous
	end
	local api = C_CurrencyInfo or {}
	local accountReady = read(api.IsAccountCharacterCurrencyDataReady) == true
	local snapshot = { seasonID = seasonID, currencies = {}, updatedAt = GF.MythicPlusServiceUtil.Now() }
	self.accountUpdatedAt = snapshot.updatedAt
	for _, id in ipairs(ids) do
		local info = read(api.GetCurrencyInfo, id)
		if self:UsesSeasonCap(id) then
			local state, maximum = self:GetSeasonCap(id, info)
			caps[#caps + 1] = id .. ":" .. state .. ":" .. tostring(maximum or "")
		end
		local entry
		if type(info) == "table" then
			local name, icon = publicString(info.name), number(info.iconFileID)
			if name and icon and icon > 0 then
				self.metadata[id] = { name = name, iconFileID = icon,
					description = publicString(info.description), quality = number(info.quality) }
				local quantity = number(info.quantity)
				if quantity then
					entry = { quantity = quantity, name = name, iconFileID = icon, updatedAt = snapshot.updatedAt }
				end
			end
		end
		-- A temporary failed read must not turn a recorded balance into zero.
		local saved = savedEntry(previous, seasonID, id)
		if not entry and type(saved) == "table" and number(saved.quantity) then
			entry = { quantity = number(saved.quantity), name = publicString(saved.name),
				iconFileID = number(saved.iconFileID),
				updatedAt = number(saved.updatedAt) or number(previous.updatedAt) }
		end
		if entry and self:UsesSeasonCap(id) then
			entry.seasonProgress = copyProgress(saved)
			local earned = type(info) == "table" and publicBoolean(info.useTotalEarnedForMaxQty) == true
				and number(info.totalEarned) or nil
			if earned ~= nil then
				entry.seasonProgress = { totalEarned = earned, updatedAt = snapshot.updatedAt }
			end
		end
		snapshot.currencies[id] = entry
		if not self.metadata[id] and entry then
			self.metadata[id] = { name = entry.name, iconFileID = entry.iconFileID }
		end
		if accountReady then
			local entries = read(api.FetchCurrencyDataFromAccountCharacters, id)
			local quantities = {}
			for _, character in ipairs(type(entries) == "table" and entries or {}) do
				if type(character) == "table" then
					local guid, quantity = publicString(character.characterGUID), number(character.quantity)
					if guid and quantity and number(character.currencyID) == id then
						quantities[guid] = quantity
						signature[#signature + 1] = id .. ":" .. guid .. ":" .. quantity
					end
				end
			end
			self.accountQuantities[id] = quantities
		end
	end
	table.sort(signature)
	self.accountSignature = table.concat(signature, ";")
	self.accountChanged = previousAccounts ~= self.accountSignature
	local capSignature = table.concat(caps, ";")
	self.capChanged = self.capSignature ~= capSignature
	self.capSignature = capSignature
	return snapshot
end

function Crests:GetEntry(character, currencyID)
	local _, seasonID = self:GetCurrencyIDs()
	local saved = savedEntry(character and character.crests, seasonID, currencyID)
	local metadata = self.metadata and self.metadata[currencyID] or saved
	local isSeasonCurrency = self:UsesSeasonCap(currencyID) and self:IsRelevantCurrency(currencyID)
	local currentGUID = read(UnitGUID, "player")
	local isCurrent = currentGUID and character and character.guid == currentGUID
		and not character.isDebugTest and not character.isTest
	-- The denominator is current client data, never another character's saved cap.
	-- Refresh every current-character balance, including currencies without a season cap.
	local info = self:IsRelevantCurrency(currencyID) and (isSeasonCurrency or isCurrent)
		and read((C_CurrencyInfo or {}).GetCurrencyInfo, currencyID)
	if type(info) ~= "table" then info = nil end
	local capState, seasonMax = "unknown", nil
	if isSeasonCurrency then capState, seasonMax = self:GetSeasonCap(currencyID, info) end
	local progress = isSeasonCurrency and copyProgress(saved) or nil
	local quantity, source, updatedAt
	if character and character.guid ~= currentGUID
		and not character.isDebugTest and not character.isTest and self.accountSeasonID == seasonID then
		local balances = self.accountQuantities and self.accountQuantities[currencyID]
		quantity = balances and character.guid and balances[character.guid]
		if quantity ~= nil then source, updatedAt = "account", number(self.accountUpdatedAt) end
	end
	if quantity == nil and saved then
		quantity, source = number(saved.quantity), "saved"
		if quantity ~= nil then updatedAt = number(saved.updatedAt) or number(character.crests.updatedAt) end
	end
	if info and isCurrent then
		local liveQuantity = number(info.quantity)
		if liveQuantity ~= nil then
			quantity, source, updatedAt = liveQuantity, "current", GF.MythicPlusServiceUtil.Now()
		end
		local earned = isSeasonCurrency and publicBoolean(info.useTotalEarnedForMaxQty) == true
			and number(info.totalEarned) or nil
		if earned ~= nil then progress = { totalEarned = earned, updatedAt = GF.MythicPlusServiceUtil.Now() } end
	end
	return { currencyID = currencyID,
		name = info and publicString(info.name) or metadata and metadata.name,
		iconFileID = info and number(info.iconFileID) or metadata and metadata.iconFileID,
		quantity = quantity, source = source, updatedAt = updatedAt,
		description = info and publicString(info.description) or metadata and metadata.description,
		quality = info and number(info.quality) or metadata and metadata.quality,
		isSeasonCurrency = isSeasonCurrency, capState = capState, seasonMax = seasonMax,
		totalEarned = progress and progress.totalEarned, progressUpdatedAt = progress and progress.updatedAt }
end
