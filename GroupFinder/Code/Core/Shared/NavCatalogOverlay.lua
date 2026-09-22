local _, GF = ...

-- Account-wide, derived Encounter Journal structure. This cache is deliberately
-- separate from settings: it may be discarded at any time and never grants LFG
-- search authority. Packaged data remains the fallback; current C_LFGList data
-- remains the only authority for usable activities.
local Overlay = GF.NavCatalogOverlay or {}
GF.NavCatalogOverlay = Overlay

local SCHEMA_VERSION = 1
local MAX_BUCKETS_PER_LOCALE = 2
local MAX_INSTANCES_PER_EXPANSION = 300
local MAX_ARCHIVE_EXPANSION_INDEX = 31
local MAX_LABEL_BYTES = 256
local RETRY_SECONDS = 1
local MAX_RECONCILE_ATTEMPTS = 3
local MAX_PAUSED_RETRIES_PER_WAKE = 1

local state = {
	store = nil,
	queue = {},
	queued = {},
	runToken = 0,
	timerPending = false,
	timerSerial = 0,
	journalHideHooked = false,
}

local function tonumberPositive(value)
	value = tonumber(value)
	return value and value > 0 and value or nil
end

local function copyTable(source, seen)
	if type(source) ~= "table" then
		return source
	end
	seen = seen or {}
	if seen[source] then
		return seen[source]
	end
	local copy = {}
	seen[source] = copy
	for key, value in pairs(source) do
		copy[copyTable(key, seen)] = copyTable(value, seen)
	end
	return copy
end

local function currentEnvironment()
	local version, build, _, interfaceVersion
	if type(GetBuildInfo) == "function" then
		local ok
		ok, version, build, _, interfaceVersion = pcall(GetBuildInfo)
		if not ok then
			version, build, interfaceVersion = nil, nil, nil
		end
	end
	local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
	return {
		schemaVersion = SCHEMA_VERSION,
		dataRevision = tonumber(GF.NAV_CATALOG_DATA_REVISION) or 0,
		projectID = tonumber(_G and _G.WOW_PROJECT_ID) or 0,
		interface = tonumber(interfaceVersion)
			or tonumber(GF.Compat and GF.Compat.interface) or 0,
		build = tostring(build or GF.Compat and GF.Compat.build or "0"),
		version = tostring(version or GF.Compat and GF.Compat.version or ""),
		locale = tostring(locale or "enUS"),
	}
end

local function environmentKey(environment)
	return table.concat({
		tostring(environment.schemaVersion or 0),
		tostring(environment.dataRevision or 0),
		tostring(environment.projectID or 0),
		tostring(environment.interface or 0),
		tostring(environment.build or "0"),
		tostring(environment.locale or "enUS"),
	}, ":")
end

local function compatibleMeta(meta, environment)
	local metaInterface = tonumber(meta and meta.interface) or 0
	local currentInterface = tonumber(environment and environment.interface) or 0
	return type(meta) == "table"
		and tonumber(meta.schemaVersion) == environment.schemaVersion
		and tonumber(meta.dataRevision) == environment.dataRevision
		and tonumber(meta.projectID) == environment.projectID
		and math.floor(metaInterface / 10000)
			== math.floor(currentInterface / 10000)
		and tostring(meta.locale or "") == environment.locale
end

local function ensureStore(rawStore)
	if type(rawStore) ~= "table" then
		rawStore = {}
	end
	if type(rawStore.buckets) ~= "table" then
		rawStore.buckets = {}
	end
	rawStore.schemaVersion = SCHEMA_VERSION
	return rawStore
end

local function initialize(rawStore)
	if rawStore == nil and type(_G) == "table" then
		rawStore = _G.GroupFinderArchiveCache
	end
	state.store = ensureStore(rawStore)
	if type(_G) == "table" then
		_G.GroupFinderArchiveCache = state.store
	end
	return state.store
end

local function store()
	return state.store or initialize()
end

local function bucketStatus(environment)
	environment = environment or currentEnvironment()
	local buckets = store().buckets
	local exact = buckets[environmentKey(environment)]
	if type(exact) == "table" and compatibleMeta(exact.meta, environment) then
		return exact, "fresh"
	end
	local stale
	local staleBuild = -1
	local currentBuild = tonumber(environment.build) or 0
	for _, bucket in pairs(buckets) do
		local meta = type(bucket) == "table" and bucket.meta or nil
		if compatibleMeta(meta, environment) then
			local build = tonumber(meta.build) or 0
			-- Older structural facts are a safe fallback for a newer client. A
			-- future PTR snapshot is not safe after switching back to an older build.
			if build <= currentBuild and build > staleBuild then
				stale, staleBuild = bucket, build
			end
		end
	end
	if stale then
		return stale, "stale"
	end
	return nil, "missing"
end

local function cleanLabel(value)
	if type(value) ~= "string" or value == "" or #value > MAX_LABEL_BYTES then
		return nil
	end
	return value
end

local function sanitizeRecord(record)
	if type(record) ~= "table" then
		return nil
	end
	local journalInstanceID = tonumberPositive(record.journalInstanceID)
	local label = cleanLabel(record.label)
	if not journalInstanceID or not label then
		return nil
	end
	return {
		journalInstanceID = journalInstanceID,
		mapID = tonumberPositive(record.mapID),
		instanceMapID = tonumberPositive(record.instanceMapID),
		orderIndex = math.max(1, math.floor(tonumber(record.orderIndex) or 1)),
		label = label,
	}
end

local function validExpansionSnapshot(expansion, expansionIndex)
	if type(expansion) ~= "table" or expansion.complete ~= true
		or tonumber(expansion.schemaVersion) ~= SCHEMA_VERSION
		or tonumber(expansion.scanTier) ~= tonumber(expansionIndex) + 1
		or type(expansion.upserts) ~= "table"
	then
		return nil
	end
	local count = 0
	for identity, record in pairs(expansion.upserts) do
		local clean = sanitizeRecord(record)
		if not clean or identity ~= "j:" .. tostring(clean.journalInstanceID) then
			return nil
		end
		count = count + 1
	end
	if count ~= tonumber(expansion.count) then
		return nil
	end
	return expansion
end

local function snapshotCandidate(
	bucket,
	bucketKey,
	snapshot,
	preferredEnvironmentKey
)
	local meta = type(bucket) == "table" and bucket.meta or nil
	local sourceEnvironmentKey = snapshot and snapshot.sourceEnvironmentKey
		or bucketKey
	return {
		snapshot = snapshot,
		sourceBuild = tonumber(snapshot and snapshot.sourceBuild)
			or tonumber(meta and meta.build) or 0,
		sourceEnvironmentKey = sourceEnvironmentKey,
		preferredSource = sourceEnvironmentKey == preferredEnvironmentKey,
		directSource = sourceEnvironmentKey == bucketKey,
		containerBuild = tonumber(meta and meta.build) or 0,
		committedAt = tonumber(meta and meta.committedAt) or 0,
		bucketKey = tostring(bucketKey or ""),
	}
end

local function candidateComesBefore(left, right)
	if left.sourceBuild ~= right.sourceBuild then
		return left.sourceBuild < right.sourceBuild
	end
	if left.preferredSource ~= right.preferredSource then
		return left.preferredSource ~= true
	end
	if left.directSource ~= right.directSource then
		return left.directSource ~= true
	end
	if left.containerBuild ~= right.containerBuild then
		return left.containerBuild < right.containerBuild
	end
	if left.committedAt ~= right.committedAt then
		return left.committedAt < right.committedAt
	end
	return left.bucketKey < right.bucketKey
end

local function expansionOverlay(kind, expansionIndex, environment)
	environment = environment or currentEnvironment()
	local buckets = store().buckets
	local exactKey = environmentKey(environment)
	local function fromBucket(bucket)
		local kinds = type(bucket) == "table"
			and type(bucket.kinds) == "table" and bucket.kinds or nil
		local entries = type(kinds) == "table" and kinds[kind] or nil
		return validExpansionSnapshot(
			entries and entries[tonumber(expansionIndex)], expansionIndex)
	end
	-- Freshness is expansion-scoped. A new build may have reconciled one tier
	-- while another still has a valid last-known-good snapshot from an older
	-- compatible build; do not throw that independent tier away. A carried
	-- snapshot competes by the build that actually produced its structure, not
	-- by the newer bucket that happens to contain the copy.
	local candidates = {}
	local currentBuild = tonumber(environment.build) or 0
	for key, bucket in pairs(buckets) do
		local meta = type(bucket) == "table" and bucket.meta or nil
		if compatibleMeta(meta, environment) then
			local candidate = fromBucket(bucket)
			if candidate then
				candidate = snapshotCandidate(bucket, key, candidate, exactKey)
				if candidate.sourceBuild <= currentBuild then
					candidates[#candidates + 1] = candidate
				end
			end
		end
	end
	if #candidates == 0 then
		return nil, "missing"
	end
	table.sort(candidates, candidateComesBefore)
	local selected = candidates[#candidates]
	local status = selected.sourceEnvironmentKey == exactKey
		and selected.sourceBuild == currentBuild and "fresh" or "stale"
	return selected.snapshot, status
end

local function normalizedName(value)
	if type(value) ~= "string" then
		return nil
	end
	value = value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	return value ~= "" and string.lower(value) or nil
end

local function journalDescriptorMatches(left, right)
	local leftJournal = tonumber(left and left.journalInstanceID)
	local rightJournal = tonumber(right and right.journalInstanceID)
	return leftJournal and rightJournal and leftJournal == rightJournal
end

local function descriptorMapMatches(left, right)
	local leftMaps = {
		tonumber(left and left.mapID),
		tonumber(left and left.instanceMapID),
	}
	local rightMaps = {
		tonumber(right and right.mapID),
		tonumber(right and right.instanceMapID),
	}
	for _, leftMap in ipairs(leftMaps) do
		if leftMap then
			for _, rightMap in ipairs(rightMaps) do
				if rightMap and leftMap == rightMap then
					return true
				end
			end
		end
	end
	return false
end

local function uniquelyMappedDescriptor(descriptors, record)
	local match
	for _, descriptor in ipairs(descriptors or {}) do
		if descriptorMapMatches(descriptor, record) then
			if match then
				return nil
			end
			match = descriptor
		end
	end
	return match
end

local function uniquelyNamedDescriptor(descriptors, record)
	local name = normalizedName(record and record.label)
	if not name then
		return nil
	end
	local match
	for _, descriptor in ipairs(descriptors or {}) do
		if normalizedName(descriptor and descriptor.label) == name then
			if match then
				return nil
			end
			match = descriptor
		end
	end
	return match
end

local function mergeDescriptors(kind, expansionIndex, baseline, environment, options)
	options = options or {}
	local merged = copyTable(baseline or {})
	local overlay, status = expansionOverlay(kind, expansionIndex, environment)
	for _, record in pairs(overlay and overlay.upserts or {}) do
		local clean = sanitizeRecord(record)
		if clean then
			local target
			for _, descriptor in ipairs(merged) do
				if journalDescriptorMatches(descriptor, clean) then
					target = descriptor
					break
				end
			end
			-- Localized instance/group names distinguish structures that share one
			-- game map (Return to Karazhan, Lower, and Upper). Map-only enrichment
			-- is safe only when exactly one packaged descriptor owns that map.
			target = target or uniquelyNamedDescriptor(merged, clean)
			target = target or uniquelyMappedDescriptor(merged, clean)
			if target then
				for key, value in pairs(clean) do
					target[key] = value
				end
				target._metadataPending = nil
			elseif options.allowAdditions ~= false then
				clean.overlayOnly = true
				merged[#merged + 1] = clean
			end
		end
	end
	table.sort(merged, function(left, right)
		local leftOrder = tonumber(left and left.orderIndex) or math.huge
		local rightOrder = tonumber(right and right.orderIndex) or math.huge
		if leftOrder ~= rightOrder then
			return leftOrder < rightOrder
		end
		return tostring(left and left.label or "")
			< tostring(right and right.label or "")
	end)
	return merged, status
end

local function findExpansionForIdentity(
	kind,
	journalInstanceID,
	mapID,
	instanceMapID,
	environment
)
	environment = environment or currentEnvironment()
	journalInstanceID = tonumberPositive(journalInstanceID)
	local wantedMaps = {}
	for _, value in ipairs({ mapID, instanceMapID }) do
		value = tonumberPositive(value)
		if value then
			wantedMaps[value] = true
		end
	end
	local journalOwner, journalConflict
	local mapOwner, mapConflict
	for expansionIndex = 0, MAX_ARCHIVE_EXPANSION_INDEX do
		local snapshot = expansionOverlay(kind, expansionIndex, environment)
		for _, record in pairs(snapshot and snapshot.upserts or {}) do
			local clean = sanitizeRecord(record)
			if clean then
				if journalInstanceID
					and clean.journalInstanceID == journalInstanceID
				then
					if journalOwner ~= nil and journalOwner ~= expansionIndex then
						journalConflict = true
					else
						journalOwner = expansionIndex
					end
				end
				if next(wantedMaps) ~= nil then
					local matched = wantedMaps[tonumber(clean.mapID)]
						or wantedMaps[tonumber(clean.instanceMapID)]
					if matched then
						if mapOwner ~= nil and mapOwner ~= expansionIndex then
							mapConflict = true
						else
							mapOwner = expansionIndex
						end
					end
				end
			end
		end
	end
	if journalOwner ~= nil and not journalConflict then
		return journalOwner
	end
	if mapOwner ~= nil and not mapConflict then
		return mapOwner
	end
	return nil
end

local function journalLoaded()
	local checker = GF.Compat and GF.Compat.IsAddOnFullyLoaded
	if type(checker) ~= "function" then
		return false
	end
	return checker("Blizzard_EncounterJournal") == true
end

local function frameShown(frame)
	if not (frame and type(frame.IsShown) == "function") then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and shown == true
end

local function canRunReconcile()
	if not journalLoaded()
		or type(EJ_GetNumTiers) ~= "function"
		or type(EJ_GetTierInfo) ~= "function"
		or type(EJ_SelectTier) ~= "function"
		or type(EJ_GetInstanceByIndex) ~= "function"
	then
		return false
	end
	if type(InCombatLockdown) == "function" and InCombatLockdown() then
		return false
	end
	if frameShown(GF.MainFrame and GF.MainFrame.frame)
		or frameShown(_G and _G.EncounterJournal)
	then
		return false
	end
	return true
end

local function requestKey(kind, expansionIndex)
	return tostring(kind) .. ":" .. tostring(expansionIndex)
end

local function createJob(kind, expansionIndex)
	local environment = currentEnvironment()
	return {
		runToken = state.runToken,
		environment = environment,
		environmentKey = environmentKey(environment),
		kind = kind,
		expansionIndex = tonumber(expansionIndex),
		tier = tonumber(expansionIndex) and tonumber(expansionIndex) + 1 or nil,
		staging = {},
		scanComplete = false,
	}
end

local function runTierTransaction(job)
	if type(job) ~= "table" or not canRunReconcile() then
		return false, "paused"
	end
	job.staging = {}
	job.scanComplete = false
	if not job.tier or job.tier < 1 then
		return false, "tier"
	end
	local okTiers, value = pcall(EJ_GetNumTiers)
	local numTiers = okTiers and tonumber(value) or nil
	-- Journal readiness can briefly trail ADDON_LOADED. A short/zero tier list
	-- is retryable state, not proof that a valid packaged expansion vanished.
	if not numTiers or numTiers < job.tier then
		return false, "paused"
	end
	local previousTier
	if type(EJ_GetCurrentTier) == "function" then
		local ok, value = pcall(EJ_GetCurrentTier)
		previousTier = ok and value or nil
	end
	local selected = false
	local function scan()
		local ok = pcall(EJ_SelectTier, job.tier)
		if not ok then
			error("select-tier")
		end
		selected = true
		local function selectedTierMatches()
			if type(EJ_GetCurrentTier) ~= "function" then
				return true
			end
			local okCurrent, current = pcall(EJ_GetCurrentTier)
			return okCurrent and tonumber(current) == tonumber(job.tier)
		end
		-- EJ_SelectTier may silently no-op while Blizzard is changing/closing
		-- the Journal. Never publish the previous tier under this job's target.
		if not selectedTierMatches() then
			error("tier-not-selected")
		end
		for dataIndex = 1, MAX_INSTANCES_PER_EXPANSION do
			local okEntry, instanceID, name, _, _, _, _, _, dungeonAreaMapID,
				_, _, gameMapID = pcall(
					EJ_GetInstanceByIndex, dataIndex, job.kind == "raid")
			if not okEntry then
				error("instance")
			end
			if not instanceID then
				if not selectedTierMatches() then
					error("tier-not-selected")
				end
				job.scanComplete = true
				return
			end
			job.staging[#job.staging + 1] = {
				journalInstanceID = instanceID,
				label = name,
				mapID = dungeonAreaMapID,
				instanceMapID = gameMapID,
				orderIndex = dataIndex,
			}
		end
		error("instance-limit")
	end
	local ok, reason = xpcall(scan, function(message)
		return tostring(message)
	end)
	if selected and previousTier then
		pcall(EJ_SelectTier, previousTier)
	end
	if not ok and type(reason) == "string"
		and reason:find("tier-not-selected", 1, true)
	then
		return false, "paused"
	end
	return ok, reason
end

local function validateStaging(job)
	if type(job) ~= "table" or job.scanComplete ~= true
		or job.runToken ~= state.runToken
		or job.environmentKey ~= environmentKey(currentEnvironment())
		or #job.staging == 0
		or #job.staging >= MAX_INSTANCES_PER_EXPANSION
	then
		return nil
	end
	local upserts, seen = {}, {}
	for _, record in ipairs(job.staging) do
		local clean = sanitizeRecord(record)
		local identity = clean and "j:" .. tostring(clean.journalInstanceID)
		if not clean or seen[identity] then
			return nil
		end
		seen[identity] = true
		upserts[identity] = clean
	end
	return upserts
end

local function pruneBuckets(cache, environment)
	local matches = {}
	local currentKey = environmentKey(environment)
	local currentBuild = tonumber(environment.build) or 0
	for key, bucket in pairs(cache.buckets) do
		local meta = type(bucket) == "table" and bucket.meta or nil
		-- Old schemas/data revisions are unreadable, but they still occupy the
		-- account-wide SavedVariables file. Bound storage per project+locale even
		-- across addon upgrades instead of retaining two buckets per revision.
		if type(meta) == "table"
			and tonumber(meta.projectID) == environment.projectID
			and tostring(meta.locale or "") == environment.locale
		then
			matches[#matches + 1] = {
				key = key,
				build = tonumber(meta.build) or 0,
				committedAt = tonumber(meta.committedAt) or 0,
				current = key == currentKey,
				compatible = compatibleMeta(meta, environment),
			}
		end
	end
	table.sort(matches, function(left, right)
		if left.current ~= right.current then
			return left.current == true
		end
		local leftEligible = left.compatible and left.build <= currentBuild
		local rightEligible = right.compatible and right.build <= currentBuild
		if leftEligible ~= rightEligible then
			return leftEligible == true
		end
		if left.compatible ~= right.compatible then
			return left.compatible == true
		end
		if left.build ~= right.build then
			return left.build > right.build
		end
		return left.committedAt > right.committedAt
	end)
	for index = MAX_BUCKETS_PER_LOCALE + 1, #matches do
		cache.buckets[matches[index].key] = nil
	end
end

local function commit(job)
	local upserts = validateStaging(job)
	if not upserts then
		return false
	end
	local cache = store()
	-- The overlay is deliberately upsert-only. Encounter Journal may
	-- transiently stop enumeration part-way through a tier; replacing the
	-- expansion snapshot would turn that read failure into durable deletion.
	-- Start from the nearest valid last-known-good expansion (exact or stale),
	-- then overwrite only identities observed by this completed transaction.
	local previous = expansionOverlay(
		job.kind, job.expansionIndex, job.environment)
	local mergedUpserts = {}
	for identity, record in pairs(previous and previous.upserts or {}) do
		mergedUpserts[identity] = copyTable(record)
	end
	for identity, record in pairs(upserts) do
		mergedUpserts[identity] = copyTable(record)
	end
	local mergedCount = 0
	for _ in pairs(mergedUpserts) do
		mergedCount = mergedCount + 1
	end
	-- Roll every compatible older expansion into the current build before the
	-- bounded bucket prune. Without this, three builds that each learned a
	-- different tier would delete the only last-known-good copy of the oldest
	-- tier when the third bucket is published.
	local snapshotsByKind = {}
	local currentBuild = tonumber(job.environment.build) or 0
	for key, bucket in pairs(cache.buckets) do
		local meta = type(bucket) == "table" and bucket.meta or nil
		if compatibleMeta(meta, job.environment) then
			local kinds = type(bucket.kinds) == "table" and bucket.kinds or {}
			for kind, expansions in pairs(kinds) do
				snapshotsByKind[kind] = snapshotsByKind[kind] or {}
				local sourceExpansions = type(expansions) == "table"
					and expansions or {}
				for expansionIndex, snapshot in pairs(sourceExpansions) do
					local valid = validExpansionSnapshot(snapshot, expansionIndex)
					if valid then
						local candidate = snapshotCandidate(
							bucket, key, valid, job.environmentKey)
						if candidate.sourceBuild <= currentBuild then
							snapshotsByKind[kind][expansionIndex] =
								snapshotsByKind[kind][expansionIndex] or {}
							table.insert(
								snapshotsByKind[kind][expansionIndex], candidate)
						end
					end
				end
			end
		end
	end
	local nextBucket = { kinds = {} }
	for kind, expansions in pairs(snapshotsByKind) do
		nextBucket.kinds[kind] = {}
		for expansionIndex, candidates in pairs(expansions) do
			table.sort(candidates, candidateComesBefore)
			local combined
			for _, candidate in ipairs(candidates) do
				local valid = candidate.snapshot
				combined = combined or copyTable(valid)
				combined.upserts = type(combined.upserts) == "table"
					and combined.upserts or {}
				for identity, record in pairs(valid.upserts) do
					combined.upserts[identity] = copyTable(record)
				end
				combined.sourceBuild = candidate.sourceBuild
				combined.sourceEnvironmentKey =
					candidate.sourceEnvironmentKey
			end
			local count = 0
			for _ in pairs(combined.upserts) do
				count = count + 1
			end
			combined.count = count
			nextBucket.kinds[kind][expansionIndex] = combined
		end
	end
	nextBucket.meta = copyTable(job.environment)
	nextBucket.meta.committedAt = type(time) == "function" and time() or 0
	nextBucket.kinds[job.kind] = type(nextBucket.kinds[job.kind]) == "table"
		and nextBucket.kinds[job.kind] or {}
	nextBucket.kinds[job.kind][job.expansionIndex] = {
		schemaVersion = SCHEMA_VERSION,
		complete = true,
		scanTier = job.tier,
		sourceBuild = tonumber(job.environment.build) or 0,
		sourceEnvironmentKey = job.environmentKey,
		count = mergedCount,
		upserts = mergedUpserts,
	}
	-- Publish once. Readers either see the previous complete bucket or this one.
	cache.buckets[job.environmentKey] = nextBucket
	pruneBuckets(cache, job.environment)
	local catalog = GF.NavCatalog
	if catalog and type(catalog.InvalidateInstanceShells) == "function" then
		pcall(catalog.InvalidateInstanceShells, job.kind, job.expansionIndex)
	end
	local nav = GF.NavData
	if nav and type(nav.OnArchiveOverlayUpdated) == "function" then
		pcall(nav.OnArchiveOverlayUpdated, job.kind, job.expansionIndex)
	end
	return true
end

local runNext

local function schedule(delay)
	if state.timerPending or #state.queue == 0 then
		return false
	end
	local after = C_Timer and C_Timer.After
	if type(after) ~= "function" then
		return false
	end
	state.timerPending = true
	state.timerSerial = state.timerSerial + 1
	local serial = state.timerSerial
	after(delay or 0, function()
		if serial ~= state.timerSerial then
			return
		end
		state.timerPending = false
		runNext()
	end)
	return true
end

local function ensureJournalHideHook()
	if state.journalHideHooked then
		return true
	end
	local journal = _G and _G.EncounterJournal
	if not (journal and type(journal.HookScript) == "function") then
		return false
	end
	local ok = pcall(journal.HookScript, journal, "OnHide", function()
		Overlay:Resume()
	end)
	if ok then
		state.journalHideHooked = true
	end
	return ok
end

runNext = function()
	local request = state.queue[1]
	if not request then
		return false
	end
	-- Do not poll forever or load Blizzard's addon on our behalf. ADDON_LOADED
	-- resumes this queue after the player naturally opens Adventure Guide.
	if not journalLoaded() then
		return false
	end
	-- Blizzard_EncounterJournal may have loaded before GroupFinder registered
	-- ADDON_LOADED. Discover that ordering here as well so a visible guide can
	-- always resume its parked request when it later closes.
	ensureJournalHideHook()
	if not canRunReconcile() then
		-- Combat and the two visible windows have explicit Resume edges. Park the
		-- queue instead of waking once per second for the entire time they remain
		-- open.
		return false
	end
	local job = createJob(request.kind, request.expansionIndex)
	local ok, reason = runTierTransaction(job)
	local committed = ok and commit(job)
	if committed then
		table.remove(state.queue, 1)
		state.queued[request.key] = nil
	else
		if reason == "paused" then
			-- Journal data can become readable one frame after its window closes.
			-- Permit one delayed retry for that transition, then park until the next
			-- explicit close/combat event instead of entering a permanent poll loop.
			request.pausedRetries = (request.pausedRetries or 0) + 1
			if request.pausedRetries <= MAX_PAUSED_RETRIES_PER_WAKE then
				schedule(RETRY_SECONDS)
			end
			return false
		end
		request.attempts = (request.attempts or 0) + 1
		if reason == "tier" or request.attempts >= MAX_RECONCILE_ATTEMPTS then
			table.remove(state.queue, 1)
			state.queued[request.key] = nil
		else
			schedule(RETRY_SECONDS)
			return false
		end
	end
	if #state.queue > 0 then
		schedule(0)
	end
	return committed == true
end

local function requestReconcile(kind, expansionIndex)
	expansionIndex = tonumber(expansionIndex)
	if (kind ~= "dungeon" and kind ~= "raid") or expansionIndex == nil then
		return false
	end
	local existing, status = expansionOverlay(
		kind, expansionIndex, currentEnvironment())
	if existing and status == "fresh" then
		return false
	end
	local key = requestKey(kind, expansionIndex)
	if state.queued[key] then
		return false
	end
	state.queued[key] = true
	state.queue[#state.queue + 1] = {
		key = key,
		kind = kind,
		expansionIndex = expansionIndex,
		attempts = 0,
	}
	schedule(0)
	return true
end

function Overlay:Initialize(rawStore)
	return initialize(rawStore)
end

function Overlay:BuildEnvironment()
	return currentEnvironment()
end

function Overlay:BuildEnvironmentKey(environment)
	return environmentKey(environment or currentEnvironment())
end

function Overlay:GetBucketStatus(environment)
	return bucketStatus(environment)
end

function Overlay:MergeDescriptors(kind, expansionIndex, baseline, environment, options)
	return mergeDescriptors(kind, expansionIndex, baseline, environment, options)
end

function Overlay:FindExpansionForIdentity(
	kind,
	journalInstanceID,
	mapID,
	instanceMapID,
	environment
)
	return findExpansionForIdentity(
		kind, journalInstanceID, mapID, instanceMapID, environment)
end

function Overlay:RequestReconcile(kind, expansionIndex)
	return requestReconcile(kind, expansionIndex)
end

function Overlay:CanRunReconcile()
	return canRunReconcile()
end

function Overlay:CreateJob(kind, expansionIndex)
	return createJob(kind, expansionIndex)
end

function Overlay:RunTierTransaction(job)
	return runTierTransaction(job)
end

function Overlay:ValidateStaging(job)
	return validateStaging(job)
end

function Overlay:Commit(job)
	return commit(job)
end

function Overlay:CancelGeneration()
	state.runToken = state.runToken + 1
	state.timerSerial = state.timerSerial + 1
	state.queue = {}
	state.queued = {}
	state.timerPending = false
end

function Overlay:Purge()
	local cache = store()
	cache.buckets = {}
	self:CancelGeneration()
	local catalog = GF.NavCatalog
	if catalog and type(catalog.InvalidateAllInstanceShells) == "function" then
		catalog.InvalidateAllInstanceShells()
	end
	local nav = GF.NavData
	if nav and type(nav.OnArchiveOverlayPurged) == "function" then
		nav.OnArchiveOverlayPurged()
	end
	return true
end

function Overlay:OnAddonLoaded(addonName)
	if addonName == "Blizzard_EncounterJournal" then
		ensureJournalHideHook()
		schedule(0)
	end
end

function Overlay:Resume()
	local request = state.queue[1]
	if request then
		request.pausedRetries = 0
	end
	schedule(0)
end

return Overlay
