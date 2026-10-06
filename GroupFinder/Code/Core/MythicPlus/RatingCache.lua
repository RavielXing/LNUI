local _, GF = ...

GF.MythicPlusRatingCache = GF.MythicPlusRatingCache or {}
local Cache = GF.MythicPlusRatingCache
local Util = GF.MythicPlusServiceUtil

-- One immediate read followed by five finite retries.
local RETRY_DELAYS = { 0.75, 1.5, 3, 5, 8 }
local READ_BATCH_SIZE = 5
local READ_INTERVAL = 0.12
local BEST_RUN_DURATION_TOLERANCE_MS = 1500

local function readClock()
	return GetTime and GetTime() or Util.Now()
end

local function isDisconnected(unit)
	if not UnitIsConnected then return false end
	local ok, connected = pcall(UnitIsConnected, unit)
	return ok and (not GF.Compat or GF.Compat.IsAccessibleValue(connected))
		and connected == false
end

local function normalizeScore(value)
	value = tonumber(value)
	return value and math.max(0, math.floor(value + 0.5)) or nil
end

local function copyScoreColor(score)
	score = normalizeScore(score)
	if not (score and C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor) then
		return nil
	end
	Cache.scoreColors = Cache.scoreColors or {}
	if Cache.scoreColors[score] then
		return Cache.scoreColors[score]
	end
	local ok, color = pcall(C_ChallengeMode.GetDungeonScoreRarityColor, score)
	if not (ok and color) then
		return nil
	end
	if color.GetRGB then
		local colorOK, r, g, b = pcall(color.GetRGB, color)
		if colorOK and tonumber(r) and tonumber(g) and tonumber(b) then
			Cache.scoreColors[score] = { r = r, g = g, b = b, a = tonumber(color.a) or 1 }
			return Cache.scoreColors[score]
		end
	end
	if tonumber(color.r) and tonumber(color.g) and tonumber(color.b) then
		Cache.scoreColors[score] = {
			r = color.r,
			g = color.g,
			b = color.b,
			a = tonumber(color.a) or 1,
		}
		return Cache.scoreColors[score]
	end
	return nil
end

local function copySpecificScoreColor(score)
	score = tonumber(score)
	score = score and math.max(0, score) or nil
	if not (score and C_ChallengeMode
		and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor)
	then
		return nil
	end
	Cache.specificScoreColors = Cache.specificScoreColors or {}
	if Cache.specificScoreColors[score] then
		return Cache.specificScoreColors[score]
	end
	local ok, color = pcall(
		C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor, score)
	if not (ok and color) then
		return nil
	end
	if color.GetRGB then
		local colorOK, r, g, b = pcall(color.GetRGB, color)
		if colorOK and tonumber(r) and tonumber(g) and tonumber(b) then
			Cache.specificScoreColors[score] = {
				r = r,
				g = g,
				b = b,
				a = tonumber(color.a) or 1,
			}
			return Cache.specificScoreColors[score]
		end
	end
	if tonumber(color.r) and tonumber(color.g) and tonumber(color.b) then
		Cache.specificScoreColors[score] = {
			r = color.r,
			g = color.g,
			b = color.b,
			a = tonumber(color.a) or 1,
		}
		return Cache.specificScoreColors[score]
	end
	return nil
end

local function readSummary(unit)
	if not (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then
		return nil
	end
	local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
	return ok and type(summary) == "table" and summary or nil
end

local function readCurrentSeasonRunHistory(unit)
	-- GetRunHistory only describes the active player. Never use it to infer a
	-- party member's best-run state.
	if unit ~= "player"
		or not (C_MythicPlus and C_MythicPlus.GetRunHistory)
	then
		return nil
	end
	local ok, history = pcall(
		C_MythicPlus.GetRunHistory,
		true, -- include previous weeks
		true, -- include incomplete/overtime records
		true  -- current season only
	)
	return ok and type(history) == "table" and history or nil
end

local function validPositiveNumber(value)
	if issecretvalue and issecretvalue(value) then return nil end
	value = tonumber(value)
	return value and value == value and value > 0 and value < math.huge and value or nil
end

local function buildHighestCompletedLevels(summaryRuns, history, seasonID)
	local levels = {}
	local function include(mapID, level)
		mapID, level = validPositiveNumber(mapID), validPositiveNumber(level)
		if mapID and level and mapID % 1 == 0 and level % 1 == 0 then
			levels[mapID] = math.max(levels[mapID] or 0, level)
		end
	end
	for _, run in ipairs(summaryRuns or {}) do
		if type(run) == "table" then include(run.challengeModeID, run.bestRunLevel) end
	end
	for _, run in ipairs(history or {}) do
		-- Native history includes overtime completions. completed is the timer
		-- result, so false must not exclude a finished run with a valid duration.
		if type(run) == "table" and type(run.completed) == "boolean"
			and validPositiveNumber(run.durationSec)
			and (run.season == nil or not seasonID or tonumber(run.season) == seasonID)
		then
			include(run.mapChallengeModeID, run.level)
		end
	end
	return levels
end

local function completedLevelsEqual(left, right)
	left, right = left or {}, right or {}
	for mapID, level in pairs(left) do
		if level ~= right[mapID] then return false end
	end
	for mapID, level in pairs(right) do
		if level ~= left[mapID] then return false end
	end
	return true
end

local function retainKnownCompletedLevels(observed, previous)
	if not (observed and observed.unit == "player" and previous
		and previous.unit == "player" and observed.seasonID == previous.seasonID) then return end
	for mapID, level in pairs(previous.highestCompletedLevels or {}) do
		observed.highestCompletedLevels[mapID] = math.max(
			observed.highestCompletedLevels[mapID] or 0, level)
	end
end

local function findBestRunTimedState(summaryRun, history)
	if type(summaryRun) ~= "table" or type(history) ~= "table" then
		return nil
	end
	local mapID = tonumber(summaryRun.challengeModeID)
	local level = tonumber(summaryRun.bestRunLevel)
	local durationMS = tonumber(summaryRun.bestRunDurationMS)
	if not (mapID and level and durationMS and durationMS > 0) then
		return nil
	end

	local bestMatch
	local bestDelta
	for _, historyRun in ipairs(history) do
		if type(historyRun) == "table"
			and tonumber(historyRun.mapChallengeModeID) == mapID
			and tonumber(historyRun.level) == level
		then
			local historyDurationMS = tonumber(historyRun.durationSec)
			historyDurationMS = historyDurationMS and historyDurationMS * 1000 or nil
			if historyDurationMS then
				local delta = math.abs(historyDurationMS - durationMS)
				if bestDelta == nil or delta < bestDelta then
					bestMatch = historyRun
					bestDelta = delta
				end
			end
		end
	end

	if bestMatch
		and bestDelta <= BEST_RUN_DURATION_TOLERANCE_MS
		and type(bestMatch.completed) == "boolean"
	then
		return bestMatch.completed
	end
	-- Do not guess from finishedSuccess. Blizzard uses that field as a valid
	-- completed-score gate, while GetRunHistory().completed is the timer result.
	return nil
end

local function colorsEqual(left, right)
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	return tonumber(left.r) == tonumber(right.r)
		and tonumber(left.g) == tonumber(right.g)
		and tonumber(left.b) == tonumber(right.b)
		and tonumber(left.a or 1) == tonumber(right.a or 1)
end

local function runsEqual(left, right)
	left = type(left) == "table" and left or {}
	right = type(right) == "table" and right or {}
	if #left ~= #right then
		return false
	end
	for index, leftRun in ipairs(left) do
		local rightRun = right[index]
		if type(rightRun) ~= "table"
			or tonumber(leftRun.mapID) ~= tonumber(rightRun.mapID)
			or tonumber(leftRun.level) ~= tonumber(rightRun.level)
			or tonumber(leftRun.score) ~= tonumber(rightRun.score)
			or tonumber(leftRun.durationMS) ~= tonumber(rightRun.durationMS)
			or leftRun.timed ~= rightRun.timed
			or not colorsEqual(leftRun.scoreColor, rightRun.scoreColor)
		then
			return false
		end
	end
	return true
end

local function entriesEqual(left, right)
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	return left.key == right.key
		and left.fullName == right.fullName
		and left.state == right.state
		and tonumber(left.seasonID) == tonumber(right.seasonID)
		and tonumber(left.score) == tonumber(right.score)
		and colorsEqual(left.scoreColor, right.scoreColor)
		and runsEqual(left.runs, right.runs)
		and completedLevelsEqual(left.highestCompletedLevels, right.highestCompletedLevels)
end

local function retainKnownRunTiming(observed, previous)
	if not (observed and observed.timingPending
		and type(observed.runs) == "table"
		and type(previous) == "table"
		and type(previous.runs) == "table")
	then
		return
	end
	local unresolved = false
	for _, observedRun in ipairs(observed.runs) do
		if observedRun.timed == nil then
			for _, previousRun in ipairs(previous.runs) do
				if tonumber(previousRun.mapID) == tonumber(observedRun.mapID)
					and tonumber(previousRun.level) == tonumber(observedRun.level)
					and tonumber(previousRun.durationMS) == tonumber(observedRun.durationMS)
					and type(previousRun.timed) == "boolean"
				then
					observedRun.timed = previousRun.timed
					break
				end
			end
		end
		unresolved = observedRun.timed == nil or unresolved
	end
	observed.timingPending = unresolved or nil
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

local function copyEntry(entry)
	local copy = {}
	for key, value in pairs(entry or {}) do
		copy[key] = value
	end
	return copy
end

local function sortRuns(runs)
	table.sort(runs, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		if a.level ~= b.level then
			return a.level > b.level
		end
		return (tonumber(a.mapID) or 0) < (tonumber(b.mapID) or 0)
	end)
	return runs
end

local function copyPeerRuns(runs)
	if type(runs) == "table" and type(runs.runs) == "table" then
		runs = runs.runs
	end
	local copied = Util.CopyRuns(runs)
	for _, run in ipairs(copied) do
		run.scoreColor = copySpecificScoreColor(run.score) or run.scoreColor
	end
	return sortRuns(copied)
end

local function buildEntry(unit, key, reason)
	local fullName = Util.GetUnitFullName(unit)
	local summary = readSummary(unit)
	local runHistory = readCurrentSeasonRunHistory(unit)
	local seasonID = getCurrentSeasonID()
	local score = summary and normalizeScore(summary.currentSeasonScore) or nil
	if unit == "player" and C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
		local ok, overall = pcall(C_ChallengeMode.GetOverallDungeonScore)
		if ok and tonumber(overall) then
			score = normalizeScore(overall)
		end
	end
	local runs = {}
	local timingPending = false
	for _, run in ipairs(summary and summary.runs or {}) do
		if type(run) == "table" and tonumber(run.challengeModeID) then
			local timed = findBestRunTimedState(run, runHistory)
			if unit == "player" and timed == nil then
				timingPending = true
			end
			runs[#runs + 1] = {
				mapID = tonumber(run.challengeModeID),
				level = tonumber(run.bestRunLevel) or 0,
				score = tonumber(run.mapScore) or 0,
				scoreColor = copySpecificScoreColor(run.mapScore),
				durationMS = tonumber(run.bestRunDurationMS) or 0,
				timed = timed,
			}
		end
	end
	sortRuns(runs)
	return {
		key = key,
		unit = unit,
		fullName = fullName,
		-- OverallDungeonScore can become readable before the complete rating
		-- summary. Keep the score, but retry until the coherent runs[] source is
		-- available instead of treating that partial read as final.
		state = summary and "ready" or "missing",
		score = score,
		scoreColor = copyScoreColor(score),
		runs = runs,
		highestCompletedLevels = unit == "player"
			and buildHighestCompletedLevels(summary and summary.runs, runHistory, seasonID) or nil,
		timingPending = timingPending or nil,
		seasonID = seasonID,
		updatedAt = Util.Now(),
		reason = reason,
	}
end

function Cache:AddListener(callback)
	Util.AddListener(self, callback)
end

function Cache:GetUnit(unit)
	local key = Util.GetUnitKey(unit)
	return self:GetByKey(key)
end

function Cache:GetCurrent()
	return self:GetUnit("player")
end

function Cache:GetCurrentRevision()
	return self.currentRevision or 0
end

function Cache:GetHighestCompletedLevel(challengeModeID)
	local current = self:GetCurrent()
	local levels = current and current.highestCompletedLevels
	return levels and levels[tonumber(challengeModeID)] or nil
end

function Cache:GetByKey(key)
	local entry = key and self.entries and self.entries[key] or nil
	if not entry then
		return nil
	end
	local currentSeasonID = getCurrentSeasonID()
	if currentSeasonID
		and entry.seasonID
		and tonumber(entry.seasonID) ~= currentSeasonID
	then
		return nil
	end
	return entry
end

function Cache:GetStateByKey(key)
	local entry = self:GetByKey(key)
	return entry and entry.state or "missing"
end

function Cache:GetCachedScoreColor(score)
	score = normalizeScore(score)
	return score and self.scoreColors and self.scoreColors[score] or nil
end

function Cache:GetCachedSpecificScoreColor(score)
	score = tonumber(score)
	score = score and math.max(0, score) or nil
	return score and self.specificScoreColors and self.specificScoreColors[score] or nil
end

function Cache:GetScoreColor(score, rule)
	local rules = GF.MYTHIC_PLUS_SCORE_COLOR_RULE or {}
	if rule == rules.SINGLE_DUNGEON then
		return copySpecificScoreColor(score)
	end
	return copyScoreColor(score)
end

function Cache:PrimeRunScoreColors(runs)
	for _, run in ipairs(runs or {}) do
		copySpecificScoreColor(run and run.score)
	end
end

function Cache:PrimeStoredScoreColors()
	if not (GF.MythicPlusCharacterStore and GF.MythicPlusCharacterStore.GetCharacters) then
		return
	end
	for _, character in ipairs(GF.MythicPlusCharacterStore:GetCharacters()) do
		copyScoreColor(character and character.rating)
		self:PrimeRunScoreColors(character and character.bestRuns)
	end
end

local function isPeerSuppressed(unit)
	local policy = GF.MythicPlusCarpoolPolicy
	return policy and policy:IsRaidSilent() and not policy:IsLocalUnit(unit)
end

local function collectRosterUnits()
	local units = { "player" }
	if GF.MythicPlusCarpoolPolicy and GF.MythicPlusCarpoolPolicy:IsRaidSilent() then return units end
	if IsInRaid and IsInRaid() then
		local count = GetNumGroupMembers and GetNumGroupMembers() or 0
		for index = 1, count do
			units[#units + 1] = "raid" .. index
		end
	elseif IsInGroup and IsInGroup() then
		local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
		for index = 1, count do
			units[#units + 1] = "party" .. index
		end
	end
	return units
end

local function normalizedIdentity(value)
	return type(value) == "string" and string.lower(value) or nil
end

function Cache:_SetEntry(key, nextEntry, reason, deferNotify)
	self.entries = self.entries or {}
	local previous = self.entries[key]
	self.entries[key] = nextEntry
	local changed = not entriesEqual(previous, nextEntry)
	if changed and ((previous and previous.unit == "player")
		or (nextEntry and nextEntry.unit == "player"))
	then
		self.currentRevision = self:GetCurrentRevision() + 1
	end
	if changed and not deferNotify then
		Util.Notify(self, reason or "refresh")
	end
	return changed
end

function Cache:_NextTicket(key)
	self.requestTickets = self.requestTickets or {}
	self.requestTickets[key] = (tonumber(self.requestTickets[key]) or 0) + 1
	return self.requestTickets[key]
end

function Cache:CancelRetry(key)
	if not key then
		return
	end
	local record = self.retryTimers and self.retryTimers[key]
	if self.retryTimers then
		self.retryTimers[key] = nil
	end
	for index = #(self.readBatch or {}), 1, -1 do
		if self.readBatch[index] == record then
			table.remove(self.readBatch, index)
		end
	end
	self:_NextTicket(key)
	if not self.clearingReads then self:_ScheduleReadQueue() end
end

function Cache:_CancelAllRetries()
	self.clearingReads = true
	local keys = {}
	for key in pairs(self.retryTimers or {}) do
		keys[#keys + 1] = key
	end
	for _, key in ipairs(keys) do
		self:CancelRetry(key)
	end
	self.clearingReads = nil
	self.readBatch = nil
	self:_CancelReadTimer()
end

function Cache:_CancelReadTimer()
	if self.readTimer and self.readTimer.Cancel then self.readTimer:Cancel() end
	self.readTimer = nil
	self.readTimerAt = nil
	self.readTimerTicket = (self.readTimerTicket or 0) + 1
end

function Cache:_BuildReadBatch(now)
	local initial, retries = {}, {}
	for _, record in pairs(self.retryTimers or {}) do
		if record.nextReadAt <= now then
			local target = record.attempt == 0 and initial or retries
			target[#target + 1] = record
		end
	end
	local function inOrder(a, b)
		if a.priority ~= b.priority then return a.priority end
		return a.sequence < b.sequence
	end
	table.sort(initial, inOrder)
	table.sort(retries, function(a, b)
		if a.nextReadAt ~= b.nextReadAt then return a.nextReadAt < b.nextReadAt end
		return inOrder(a, b)
	end)
	local batch = {}
	local initialLimit = #retries > 0 and READ_BATCH_SIZE - 1 or READ_BATCH_SIZE
	for index = 1, math.min(#initial, initialLimit) do
		batch[#batch + 1] = initial[index]
	end
	for index = 1, math.min(#retries, READ_BATCH_SIZE - #batch) do
		batch[#batch + 1] = retries[index]
	end
	self.readBatch = batch
end

function Cache:_ScheduleReadQueue()
	if self.holdReads or self.pumpingRead or self.clearingReads then return end
	local wakeAt
	if #(self.readBatch or {}) > 0 then
		wakeAt = readClock()
	else
		for _, record in pairs(self.retryTimers or {}) do
			wakeAt = wakeAt and math.min(wakeAt, record.nextReadAt) or record.nextReadAt
		end
	end
	if not wakeAt then self:_CancelReadTimer(); return end
	wakeAt = math.max(wakeAt, self.readNotBefore or 0)
	if self.readTimerAt and self.readTimerAt <= wakeAt then return end
	self:_CancelReadTimer()
	if not (C_Timer and C_Timer.NewTimer) then return end
	local ticket = self.readTimerTicket
	self.readTimerAt = wakeAt
	self.readTimer = C_Timer.NewTimer(math.max(0, wakeAt - readClock()), function()
		if Cache.readTimerTicket ~= ticket then return end
		Cache.readTimer = nil
		Cache.readTimerAt = nil
		Cache:_PumpReadQueue(false)
	end)
end

function Cache:_PumpReadQueue(deferNotify)
	if self.holdReads or self.pumpingRead then return false end
	local now = readClock()
	if now < (self.readNotBefore or 0) then self:_ScheduleReadQueue(); return false end
	if #(self.readBatch or {}) == 0 then self:_BuildReadBatch(now) end
	self.pumpingRead = true
	local changed = false
	while #(self.readBatch or {}) > 0 do
		local record = table.remove(self.readBatch, 1)
		if self:_IsRecordCurrent(record) then
			if isPeerSuppressed(record.unit) then
				changed = self:RemoveByKey(record.key, record.reason, deferNotify) or changed
			elseif not self:_IsRecordIdentityCurrent(record) then
				changed = self:_AbandonRecord(record) or changed
			elseif isDisconnected(record.unit) then
				changed = self:OnUnitConnection(record.unit, false) or changed
			else
				-- One native read per dispatch. A failed read releases its batch
				-- position immediately and waits in the shared retry backlog.
				self.readNotBefore = now + READ_INTERVAL
				record.attempt = record.attempt + 1
				changed = self:_PerformRead(record, deferNotify) or changed
				break
			end
		end
	end
	self.pumpingRead = nil
	self:_ScheduleReadQueue()
	return changed
end

function Cache:_EnsureSeason(reason, seasonID)
	seasonID = tonumber(seasonID) or getCurrentSeasonID()
	if not seasonID then
		return false
	end
	if not self.seasonID then
		self.seasonID = seasonID
		for _, entry in pairs(self.entries or {}) do
			entry.seasonID = entry.seasonID or seasonID
		end
		return false
	end
	if tonumber(self.seasonID) == seasonID then
		return false
	end
	local hadEntries = next(self.entries or {}) ~= nil
	for _, entry in pairs(self.entries or {}) do
		if entry.unit == "player" then
			self.currentRevision = self:GetCurrentRevision() + 1
			break
		end
	end
	self:_CancelAllRetries()
	self.entries = {}
	self.rosterKeys = {}
	self.seasonID = seasonID
	self.lastSeasonReason = reason
	return hadEntries
end

function Cache:_IsRecordCurrent(record)
	return record
		and self.retryTimers
		and self.retryTimers[record.key] == record
		and self.requestTickets
		and self.requestTickets[record.key] == record.ticket
end

function Cache:_IsRecordIdentityCurrent(record)
	if not (record and UnitExists and UnitExists(record.unit)) then
		return false
	end
	if Util.GetUnitKey(record.unit) ~= record.key then
		return false
	end
	if record.guid
		and UnitGUID
		and UnitGUID(record.unit) ~= record.guid
	then
		return false
	end
	local fullName = Util.GetUnitFullName(record.unit)
	return not record.fullName or fullName == record.fullName
end

function Cache:_FinishRecord(record)
	if not self:_IsRecordCurrent(record) then
		return false
	end
	self.retryTimers[record.key] = nil
	return true
end

function Cache:_AbandonRecord(record)
	if not self:_FinishRecord(record) then
		return false
	end
	local nextEntry
	if record.baseReady then
		nextEntry = copyEntry(record.baseReady)
		nextEntry.refreshing = nil
	end
	return self:_SetEntry(
		record.key,
		nextEntry,
		"rating-identity-changed",
		false)
end

function Cache:_ScheduleRecord(record)
	local delay = RETRY_DELAYS[record.attempt]
	if not (delay and C_Timer and C_Timer.NewTimer) then
		return false
	end
	record.nextReadAt = readClock() + delay
	return true
end

function Cache:_RetainReadyWhileRefreshing(record, observed)
	local retained = copyEntry(record.baseReady)
	retained.unit = record.unit
	retained.fullName = observed.fullName or retained.fullName
	retained.refreshing = true
	retained.refreshStartedAt = record.startedAt
	retained.refreshReason = record.reason
	return retained
end

function Cache:_PerformRead(record, deferNotify)
	if isPeerSuppressed(record.unit) then
		return self:RemoveByKey(record.key, record.reason, deferNotify)
	end
	if not self:_IsRecordCurrent(record) then
		return false
	end
	local observed = buildEntry(record.unit, record.key, record.reason)
	observed.seasonID = record.seasonID or observed.seasonID
	retainKnownRunTiming(observed, record.baseReady)
	retainKnownCompletedLevels(observed, record.baseReady)
	if observed.state == "ready" then
		observed.source = "native"
		observed.refreshing = nil
		if observed.timingPending
			and record.attempt <= #RETRY_DELAYS
			and self:_ScheduleRecord(record)
		then
			-- Score/runs are already usable. Publish them immediately while the
			-- finite retry sequence waits only for authoritative timing history.
			observed.timingRefreshing = true
			return self:_SetEntry(
				record.key,
				observed,
				record.reason,
				deferNotify)
		end
		observed.timingRefreshing = nil
		self:_FinishRecord(record)
		return self:_SetEntry(
			record.key,
			observed,
			record.reason,
			deferNotify)
	end

	if record.attempt <= #RETRY_DELAYS and self:_ScheduleRecord(record) then
		local pending
		if record.baseReady then
			pending = self:_RetainReadyWhileRefreshing(record, observed)
		else
			pending = observed
			pending.state = "pending"
			pending.attempt = record.attempt
			pending.maxAttempts = #RETRY_DELAYS + 1
		end
		return self:_SetEntry(
			record.key,
			pending,
			record.reason,
			deferNotify)
	end

	self:_FinishRecord(record)
	local terminal
	if record.baseReady then
		terminal = copyEntry(record.baseReady)
		terminal.refreshing = nil
		terminal.lastRefreshFailedAt = Util.Now()
		terminal.lastRefreshReason = record.reason
	else
		terminal = observed
		terminal.state = "failed"
		terminal.attempt = record.attempt
		terminal.maxAttempts = #RETRY_DELAYS + 1
		terminal.failedAt = Util.Now()
	end
	return self:_SetEntry(
		record.key,
		terminal,
		record.reason,
		deferNotify)
end

function Cache:_StartUnitRequest(unit, reason, deferNotify, force)
	if isPeerSuppressed(unit) then return false end
	if not (unit and UnitExists and UnitExists(unit)) or isDisconnected(unit) then
		return false
	end
	local seasonReset = self:_EnsureSeason(reason)
	self.entries = self.entries or {}
	self.retryTimers = self.retryTimers or {}
	local key = Util.GetUnitKey(unit)
	if not key then
		return seasonReset
	end
	local previous = self.entries[key]
	local active = self.retryTimers[key]
	if active then
		-- Explicit events coalesce into the in-flight finite sequence instead of
		-- resetting its attempt counter.
		return seasonReset
	end
	if not force and previous
		and (previous.state == "pending"
			or previous.state == "ready"
			or previous.state == "failed")
	then
		return seasonReset
	end

	self:CancelRetry(key)
	self.readSequence = (self.readSequence or 0) + 1
	local fullName = Util.GetUnitFullName(unit)
	local record = {
		key = key,
		unit = unit,
		guid = UnitGUID and UnitGUID(unit) or nil,
		fullName = fullName,
		ticket = self.requestTickets[key],
		attempt = 0,
		sequence = self.readSequence,
		priority = unit == "player",
		nextReadAt = readClock(),
		reason = reason or "refresh",
		startedAt = Util.Now(),
		seasonID = self.seasonID or getCurrentSeasonID(),
		baseReady = previous and previous.state == "ready" and previous or nil,
	}
	self.retryTimers[key] = record
	if not (C_Timer and C_Timer.NewTimer) then
		record.attempt = 1
		return self:_PerformRead(record, deferNotify) or seasonReset
	end
	local pending = record.baseReady and self:_RetainReadyWhileRefreshing(record, {
		fullName = fullName,
	}) or {
		key = key, unit = unit, fullName = fullName, seasonID = record.seasonID,
		state = "pending", runs = {}, attempt = 0, maxAttempts = #RETRY_DELAYS + 1,
	}
	local changed = self:_SetEntry(key, pending, reason, true) or seasonReset
	local readChanged = self:_PumpReadQueue(deferNotify)
	if changed and not readChanged and not deferNotify then
		Util.Notify(self, reason or "refresh")
	end
	return changed or readChanged
end

-- Compatibility entry point: ordinary callers may populate a missing unit, but
-- cannot restart pending, ready, or failed terminal states.
function Cache:RequestUnit(unit, reason, deferNotify)
	return self:_StartUnitRequest(unit, reason, deferNotify, false)
end

-- Explicit refresh entry point for completion/reconnection flows. A failed
-- refresh of an existing ready entry keeps the last valid value.
function Cache:RefreshUnit(unit, reason, deferNotify)
	return self:_StartUnitRequest(unit, reason, deferNotify, true)
end

function Cache:_FindIdentity(identifier, fullNameHint)
	local identifierKey = normalizedIdentity(identifier)
	local fullNameKey = normalizedIdentity(fullNameHint)
	local seen = {}
	for _, unit in ipairs(collectRosterUnits()) do
		local key = Util.GetUnitKey(unit)
		if key and not seen[key] then
			seen[key] = true
			local fullName = Util.GetUnitFullName(unit)
			if unit == identifier
				or key == identifier
				or normalizedIdentity(fullName) == identifierKey
				or normalizedIdentity(fullName) == fullNameKey
			then
				return key, unit, fullName
			end
		end
	end
	if identifier and self.entries and self.entries[identifier] then
		local entry = self.entries[identifier]
		return identifier, entry.unit, entry.fullName
	end
	for key, entry in pairs(self.entries or {}) do
		local entryName = normalizedIdentity(entry.fullName)
		if entryName == identifierKey or entryName == fullNameKey then
			return key, entry.unit, entry.fullName
		end
	end
	return nil
end

function Cache:ApplyPeerRating(unitOrKey, scoreOrPayload, runs, reason, fullName)
	if GF.MythicPlusCarpoolPolicy and GF.MythicPlusCarpoolPolicy:IsRaidSilent() then return false end
	local payload = type(scoreOrPayload) == "table" and scoreOrPayload or nil
	local score = payload and (payload.score ~= nil and payload.score or payload.rating)
		or scoreOrPayload
	if payload then
		unitOrKey = unitOrKey or payload.unit or payload.key
			or payload.guid or payload.fullName
		fullName = fullName or payload.fullName
		reason = reason or payload.reason
		if runs == nil then
			runs = payload.runs
			if runs == nil then
				runs = payload.bestRuns
			end
		end
	end
	score = normalizeScore(score)
	if score == nil then
		return false
	end

	local incomingSeasonID = payload and tonumber(payload.seasonID) or nil
	local currentSeasonID = getCurrentSeasonID()
	if not incomingSeasonID
		or not currentSeasonID
		or incomingSeasonID ~= currentSeasonID
	then
		return false
	end
	local seasonReset = self:_EnsureSeason(
		reason or "peer-rating",
		currentSeasonID)
	local key, unit, resolvedName = self:_FindIdentity(unitOrKey, fullName)
	if not key then
		-- Never create a full-name side cache that a GUID-keyed roster cannot
		-- read. The next roster pass can apply the snapshot after identity exists.
		if seasonReset then
			Util.Notify(self, reason or "peer-rating")
		end
		return seasonReset
	end
	local previous = self.entries and self.entries[key] or nil
	local nextRuns
	if type(runs) == "table" then
		nextRuns = copyPeerRuns(runs)
	elseif previous and type(previous.runs) == "table" then
		nextRuns = previous.runs
	else
		nextRuns = {}
	end
	self:PrimeRunScoreColors(nextRuns)
	local nextEntry = {
		key = key,
		unit = unit or previous and previous.unit,
		fullName = resolvedName or fullName or previous and previous.fullName,
		state = "ready",
		score = score,
		scoreColor = copyScoreColor(score),
		runs = nextRuns,
		seasonID = incomingSeasonID,
		updatedAt = Util.Now(),
		reason = reason or "peer-rating",
		source = payload and payload.source or "peer",
	}
	self:CancelRetry(key)
	local changed = self:_SetEntry(
		key,
		nextEntry,
		reason or "peer-rating",
		false)
	return changed or seasonReset
end

function Cache:OnPeerSnapshot(...)
	return self:ApplyPeerRating(...)
end

function Cache:RemoveByKey(key, reason, deferNotify)
	if not (key and self.entries and self.entries[key]) then
		self:CancelRetry(key)
		return false
	end
	self:CancelRetry(key)
	return self:_SetEntry(key, nil, reason or "rating-removed", deferNotify)
end

function Cache:_RequestRoster(reason, force)
	local seasonReset = self:_EnsureSeason(reason)
	self.entries = self.entries or {}
	self.retryTimers = self.retryTimers or {}
	local previousHold = self.holdReads
	self.holdReads = true
	local seenKeys = {}
	local unitsByKey = {}
	local rosterUnits = collectRosterUnits()
	for _, unit in ipairs(rosterUnits) do
		local key = Util.GetUnitKey(unit)
		if key and not seenKeys[key] then
			seenKeys[key] = true
			unitsByKey[key] = unit
		end
	end

	local changed = seasonReset
	local removed = {}
	for key in pairs(self.entries) do
		if not seenKeys[key] then
			removed[#removed + 1] = key
		end
	end
	for _, key in ipairs(removed) do
		changed = self:RemoveByKey(key, reason, true) or changed
	end

	-- Preserve native roster order instead of hash iteration order; the whole
	-- first batch is admitted before its first member is read.
	for _, unit in ipairs(rosterUnits) do
		local key = Util.GetUnitKey(unit)
		if key and unitsByKey[key] == unit then
			unitsByKey[key] = nil
			local entry = self.entries[key]
			local active = self.retryTimers[key]
			if active and active.unit ~= unit then
				active.unit = unit
			end
			if entry and entry.unit ~= unit then
				entry.unit = unit
			end
			if force then
				changed = self:RefreshUnit(unit, reason, true) or changed
			else
				changed = self:RequestUnit(unit, reason, true) or changed
			end
		end
	end
	self.holdReads = previousHold
	changed = self:_PumpReadQueue(true) or changed
	self.rosterKeys = seenKeys
	if changed then
		Util.Notify(self, reason or "refresh")
	end
	return changed
end

function Cache:RequestRoster(reason)
	return self:_RequestRoster(reason, false)
end

function Cache:OnRosterChanged(reason)
	return self:RequestRoster(reason or "GROUP_ROSTER_UPDATE")
end

function Cache:RefreshRoster(reason)
	return self:_RequestRoster(reason, true)
end

function Cache:OnUnitConnection(unit, isConnected, reason)
	if isPeerSuppressed(unit) then return false end
	local key = self:_FindIdentity(unit)
	if not key then
		return false
	end
	local entry = self.entries and self.entries[key] or nil
	if isConnected == false then
		self:CancelRetry(key)
		if not entry then
			return false
		end
		if entry.state == "ready" then
			if entry.refreshing then
				local retained = copyEntry(entry)
				retained.refreshing = nil
				self.entries[key] = retained
			end
			return false
		end
		local failed = copyEntry(entry)
		failed.state = "failed"
		failed.failedAt = Util.Now()
		failed.reason = reason or "UNIT_CONNECTION"
		return self:_SetEntry(
			key,
			failed,
			reason or "UNIT_CONNECTION",
			false)
	end
	if isConnected == true and (not entry or entry.state ~= "ready") then
		return self:RefreshUnit(unit, reason or "UNIT_CONNECTION")
	end
	return false
end

function Cache:OnSeasonChanged(reason, seasonID)
	if type(reason) == "number" and seasonID == nil then
		seasonID = reason
		reason = "season"
	end
	seasonID = tonumber(seasonID) or getCurrentSeasonID()
	if not seasonID then
		return false
	end
	local changed = self:_EnsureSeason(reason or "season", seasonID)
	local rosterChanged = self:RequestRoster(reason or "season")
	if changed and not rosterChanged then
		Util.Notify(self, reason or "season")
	end
	return changed or rosterChanged
end
