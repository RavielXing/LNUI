local _, GF = ...

GF.VersionDiscoveryService = GF.VersionDiscoveryService or {}
local Service = GF.VersionDiscoveryService

local PREFIX = "GFVER1"
local PROTOCOL_VERSION = "1"
local RELEASE_CHANNEL = "S"
local REQUIRED_CONFIRMATIONS = 2
local STATUS_TTL_SECONDS = 30 * 24 * 60 * 60
local RESPONSE_COOLDOWN_SECONDS = 10
local FALLBACK_ADDON_VERSION = "3.0.7"

local ALLOWED_DISTRIBUTIONS = {
	PARTY = true,
	RAID = true,
	INSTANCE_CHAT = true,
}

local function now()
	if type(time) ~= "function" then
		return 0
	end
	local ok, value = pcall(time)
	return ok and math.max(0, tonumber(value) or 0) or 0
end

local function normalizeVersion(value)
	if type(value) ~= "string" or #value > 20 then
		return nil
	end
	local major, minor, patch = value:match("^(%d+)%.(%d+)%.(%d+)$")
	major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
	if not (major and minor and patch)
		or major > 999 or minor > 999 or patch > 999
	then
		return nil
	end
	return string.format("%d.%d.%d", major, minor, patch),
		major, minor, patch
end

-- A release revision keeps the stable core for discovery and feature windows.
-- The wire parser remains x.y.z-only so existing GFVER1 clients stay compatible.
local function normalizeStableReleaseVersion(value)
	local version, major, minor, patch = normalizeVersion(value)
	if version then
		return version, major, minor, patch
	end
	if type(value) ~= "string" or #value > 20 then
		return nil
	end
	local core, revision = value:match("^(%d+%.%d+%.%d+)%-r(%d+)$")
	revision = tonumber(revision)
	if not revision or revision < 1 or revision > 999 then
		return nil
	end
	version, major, minor, patch = normalizeVersion(core)
	if version then
		return version, major, minor, patch, revision
	end
end

local function compareVersions(left, right)
	local leftVersion, leftMajor, leftMinor, leftPatch = normalizeStableReleaseVersion(left)
	local rightVersion, rightMajor, rightMinor, rightPatch = normalizeStableReleaseVersion(right)
	if not (leftVersion and rightVersion) then
		return nil
	end
	if leftMajor ~= rightMajor then
		return leftMajor < rightMajor and -1 or 1
	end
	if leftMinor ~= rightMinor then
		return leftMinor < rightMinor and -1 or 1
	end
	if leftPatch ~= rightPatch then
		return leftPatch < rightPatch and -1 or 1
	end
	return 0
end

-- Display/settings also preserve stable -rN revision labels.
-- Betas sort numerically within their core version, before its stable release.
-- Keep transport/version-discovery normalization stable-only; beta clients
-- must not announce themselves on the stable GFVER1 channel.
local function normalizeFeatureVersion(value)
	if type(value) ~= "string" or #value > 25 then
		return nil
	end
	local major, minor, patch, prerelease =
		value:match("^(%d+)%.(%d+)%.(%d+)(%-beta)$")
	local betaNumber, revisionNumber
	if not major then
		major, minor, patch, betaNumber =
			value:match("^(%d+)%.(%d+)%.(%d+)%.beta(%d+)$")
		if major then
			betaNumber = tonumber(betaNumber)
			if not betaNumber or betaNumber < 1 or betaNumber > 999 then
				return nil
			end
			prerelease = true
		end
	end
	if not major then
		local stableVersion
		stableVersion, major, minor, patch, revisionNumber =
			normalizeStableReleaseVersion(value)
		prerelease = nil
	end
	major, minor, patch =
		tonumber(major), tonumber(minor), tonumber(patch)
	if not (major and minor and patch)
		or major > 999 or minor > 999 or patch > 999
	then
		return nil
	end
	local canonical = string.format("%d.%d.%d", major, minor, patch)
	if betaNumber then
		canonical = canonical .. ".beta" .. betaNumber
	elseif prerelease then
		canonical = canonical .. "-beta"
	elseif revisionNumber then
		canonical = canonical .. "-r" .. revisionNumber
	end
	return canonical, major, minor, patch, prerelease and 0 or 1, betaNumber or 0
end

local function compareFeatureVersions(left, right)
	local leftVersion, leftMajor, leftMinor, leftPatch, leftRank, leftBeta =
		normalizeFeatureVersion(left)
	local rightVersion, rightMajor, rightMinor, rightPatch, rightRank, rightBeta =
		normalizeFeatureVersion(right)
	if not (leftVersion and rightVersion) then
		return nil
	end
	if leftMajor ~= rightMajor then
		return leftMajor < rightMajor and -1 or 1
	end
	if leftMinor ~= rightMinor then
		return leftMinor < rightMinor and -1 or 1
	end
	if leftPatch ~= rightPatch then
		return leftPatch < rightPatch and -1 or 1
	end
	if leftRank ~= rightRank then
		return leftRank < rightRank and -1 or 1
	end
	if leftBeta ~= rightBeta then
		return leftBeta < rightBeta and -1 or 1
	end
	return 0
end

local function getNextStableVersion(value)
	local _, major, minor, patch, prereleaseRank =
		normalizeFeatureVersion(value)
	if not major then
		return nil
	end
	if prereleaseRank == 0 then
		return string.format("%d.%d.%d", major, minor, patch)
	end
	if patch < 999 then
		patch = patch + 1
	elseif minor < 999 then
		minor = minor + 1
		patch = 0
	elseif major < 999 then
		major = major + 1
		minor = 0
		patch = 0
	else
		return nil
	end
	return string.format("%d.%d.%d", major, minor, patch)
end

local function readAddonVersionMetadata()
	local addonName = GF.addonName or "GroupFinder"
	local value
	if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
		local ok, result = pcall(
			C_AddOns.GetAddOnMetadata,
			addonName,
			"Version")
		if ok then
			value = result
		end
	elseif type(GetAddOnMetadata) == "function" then
		local ok, result = pcall(GetAddOnMetadata, addonName, "Version")
		if ok then
			value = result
		end
	end
	return value
end

local function getInstalledVersion()
	-- Callers that authorize version-scoped UI must be able to fail closed.
	local version = normalizeStableReleaseVersion(readAddonVersionMetadata())
	return version
end

local function getInstalledFeatureVersion()
	local version = normalizeFeatureVersion(readAddonVersionMetadata())
	return version
end

local function getAddonVersion()
	return getInstalledFeatureVersion() or FALLBACK_ADDON_VERSION
end

GF.GetAddonVersion = getAddonVersion
Service.NormalizeVersion = normalizeVersion
Service.CompareVersions = compareVersions
Service.GetInstalledVersion = getInstalledVersion
Service.NormalizeFeatureVersion = normalizeFeatureVersion
Service.CompareFeatureVersions = compareFeatureVersions
Service.GetInstalledFeatureVersion = getInstalledFeatureVersion
Service.PREFIX = PREFIX
Service.REQUIRED_CONFIRMATIONS = REQUIRED_CONFIRMATIONS
Service.STATUS_TTL_SECONDS = STATUS_TTL_SECONDS

local function canonicalSender(value)
	if type(value) ~= "string" then
		return nil
	end
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:match("^%s*(.-)%s*$") or ""
	return value ~= "" and string.lower(value) or nil
end

local function clearVersionState(store, versionKey, timeKey)
	store[versionKey] = nil
	store[timeKey] = nil
end

local function normalizeStoredVersion(store, versionKey, timeKey, localVersion, currentTime)
	local version = normalizeVersion(store[versionKey])
	local seenAt = tonumber(store[timeKey])
	local expired = version and currentTime > 0
		and (not seenAt or seenAt <= 0
			or currentTime - seenAt > STATUS_TTL_SECONDS)
	local obsolete = version
		and compareVersions(version, localVersion) ~= 1
	if not version or expired or obsolete then
		clearVersionState(store, versionKey, timeKey)
		return nil
	end
	store[versionKey] = version
	store[timeKey] = seenAt
	return version
end

function Service:GetStore()
	local db = GF.GetDB and GF.GetDB() or GF.db
	if type(db) ~= "table" then
		return nil
	end
	if type(db.versionDiscovery) ~= "table" then
		db.versionDiscovery = {}
	end
	local store = db.versionDiscovery
	local localVersion = getAddonVersion()
	local currentTime = now()
	local candidate = normalizeStoredVersion(
		store,
		"candidateVersion",
		"candidateSeenAt",
		localVersion,
		currentTime)
	local confirmed = normalizeStoredVersion(
		store,
		"confirmedVersion",
		"confirmedSeenAt",
		localVersion,
		currentTime)
	if candidate and confirmed
		and compareVersions(candidate, confirmed) ~= 1
	then
		clearVersionState(store, "candidateVersion", "candidateSeenAt")
		candidate = nil
	end
	local notified = normalizeVersion(store.notifiedVersion)
	if not notified or compareVersions(notified, localVersion) ~= 1 then
		store.notifiedVersion = nil
	else
		store.notifiedVersion = notified
	end
	return store
end

function Service:GetStatus()
	local currentVersion = getAddonVersion()
	local debugPreviewVersion = normalizeVersion(self.debugPreviewVersion)
	if debugPreviewVersion
		and compareFeatureVersions(debugPreviewVersion, currentVersion) == 1
	then
		return {
			state = "confirmed",
			currentVersion = currentVersion,
			discoveredVersion = debugPreviewVersion,
			isAuthoritative = false,
			isDebugPreview = true,
		}
	end
	self.debugPreviewVersion = nil
	local store = self:GetStore()
	local confirmed = store and normalizeVersion(store.confirmedVersion)
	local candidate = store and normalizeVersion(store.candidateVersion)
	if confirmed and compareVersions(confirmed, currentVersion) == 1 then
		return {
			state = "confirmed",
			currentVersion = currentVersion,
			discoveredVersion = confirmed,
			isAuthoritative = false,
		}
	end
	if candidate and compareVersions(candidate, currentVersion) == 1 then
		return {
			state = "candidate",
			currentVersion = currentVersion,
			discoveredVersion = candidate,
			isAuthoritative = false,
		}
	end
	return {
		state = "unknown",
		currentVersion = currentVersion,
		isAuthoritative = false,
	}
end

function Service:PreviewNewVersion()
	local version = getNextStableVersion(getAddonVersion())
	if not version then
		return false
	end
	self.debugPreviewVersion = version
	self:NotifyChanged("debug-preview")
	self:ShowVersionNotification(version)
	return true
end

function Service:ClearDebugPreview()
	if not self.debugPreviewVersion then
		return false
	end
	self.debugPreviewVersion = nil
	self:NotifyChanged("debug-preview-cleared")
	return true
end

function Service:AddListener(callback)
	if type(callback) ~= "function" then
		return false
	end
	self.listeners = self.listeners or {}
	self.listeners[#self.listeners + 1] = callback
	return true
end

function Service:NotifyChanged(reason)
	local status = self:GetStatus()
	for _, callback in ipairs(self.listeners or {}) do
		pcall(callback, status, reason)
	end
end

local function statusIdentity(status)
	return table.concat({
		tostring(status and status.state or "unknown"),
		tostring(status and status.discoveredVersion or ""),
	}, "|")
end

function Service:ShowVersionNotification(version)
	local currentVersion = getAddonVersion()
	local L = GF.L or {}
	local formatText = L.VERSION_DISCOVERY_CHAT_FMT
		or "New version %s found. Current version %s. Please update to the latest version!"
	local ok, message = pcall(
		string.format,
		formatText,
		version,
		currentVersion)
	if ok and type(GF.ShowStatusMessage) == "function" then
		GF.ShowStatusMessage(message)
		return true
	end
	return false
end

function Service:NotifyConfirmedVersion(version, store)
	local notified = store and normalizeVersion(store.notifiedVersion)
	if notified and compareVersions(version, notified) ~= 1 then
		return false
	end
	if store then
		store.notifiedVersion = version
	end
	return self:ShowVersionNotification(version)
end

function Service:ObservePeerVersion(version, sender)
	version = normalizeVersion(version)
	sender = canonicalSender(sender)
	local localVersion = getAddonVersion()
	if not (version and sender)
		or compareVersions(version, localVersion) ~= 1
	then
		return false
	end

	local before = statusIdentity(self:GetStatus())
	self.sourcesByVersion = self.sourcesByVersion or {}
	local sourceState = self.sourcesByVersion[version]
	if not sourceState then
		sourceState = { count = 0, senders = {} }
		self.sourcesByVersion[version] = sourceState
	end
	if not sourceState.senders[sender] then
		sourceState.senders[sender] = true
		sourceState.count = sourceState.count + 1
	end

	local store = self:GetStore()
	if not store then
		return false
	end
	local currentTime = now()
	local confirmed = normalizeVersion(store.confirmedVersion)
	if sourceState.count >= REQUIRED_CONFIRMATIONS then
		if not confirmed or compareVersions(version, confirmed) == 1 then
			store.confirmedVersion = version
			store.confirmedSeenAt = currentTime
			confirmed = version
		end
		local candidate = normalizeVersion(store.candidateVersion)
		if candidate and compareVersions(candidate, confirmed) ~= 1 then
			clearVersionState(store, "candidateVersion", "candidateSeenAt")
		end
		self:NotifyConfirmedVersion(version, store)
	elseif not confirmed or compareVersions(version, confirmed) == 1 then
		local candidate = normalizeVersion(store.candidateVersion)
		if not candidate or compareVersions(version, candidate) >= 0 then
			store.candidateVersion = version
			store.candidateSeenAt = currentTime
		end
	end

	local after = statusIdentity(self:GetStatus())
	if before ~= after then
		self:NotifyChanged("peer-version")
	end
	return true
end

local function encodeMessage(messageType, version)
	return table.concat({
		messageType,
		PROTOCOL_VERSION,
		version,
		RELEASE_CHANNEL,
	}, "|")
end

local function decodeMessage(text)
	if type(text) ~= "string" or #text > 80 then
		return nil
	end
	local messageType, protocolVersion, version, releaseChannel =
		text:match("^([QV])|(%d+)|([^|]+)|([A-Z])$")
	if protocolVersion ~= PROTOCOL_VERSION
		or releaseChannel ~= RELEASE_CHANNEL
	then
		return nil
	end
	version = normalizeVersion(version)
	if not version then
		return nil
	end
	return messageType, version
end

function Service:QueueVersionMessage(messageType, replaceKey)
	if not (self.handle and type(self.handle.QueueMessages) == "function") then
		return false
	end
	local installedVersion = getInstalledVersion()
	if not installedVersion then
		return false
	end
	return self.handle:QueueMessages(
		encodeMessage(messageType, installedVersion),
		{
			priority = "bulk",
			replaceKey = replaceKey,
			maxAge = 10,
		}) == true
end

function Service:HandleGroupContextChanged(channel, _, generation)
	if not (channel and self.handle) then
		return
	end
	generation = tonumber(generation) or 0
	if self.lastQueryGeneration == generation then
		return
	end
	if self:QueueVersionMessage("Q", "version-query") then
		self.lastQueryGeneration = generation
		self.currentGeneration = generation
		self.lastResponseAt = nil
	end
end

function Service:QueueResponse()
	if not (self.handle and type(self.handle.GetGroupContext) == "function") then
		return false
	end
	local channel, _, generation = self.handle:GetGroupContext("version-response")
	if not channel then
		return false
	end
	generation = tonumber(generation) or 0
	local currentTime = now()
	if self.lastResponseGeneration == generation
		and self.lastResponseAt
		and currentTime - self.lastResponseAt < RESPONSE_COOLDOWN_SECONDS
	then
		return false
	end
	if self:QueueVersionMessage("V", "version-response") then
		self.lastResponseGeneration = generation
		self.lastResponseAt = currentTime
		return true
	end
	return false
end

function Service:HandleMessage(_, text, distribution, sender)
	if ALLOWED_DISTRIBUTIONS[distribution] ~= true then
		return false
	end
	local messageType, version = decodeMessage(text)
	if not messageType then
		return false
	end
	self:ObservePeerVersion(version, sender)
	if messageType == "Q" then
		self:QueueResponse()
	end
	return true
end

function Service:Init()
	if self.initialized then
		return self.handle ~= nil
	end
	self.initialized = true
	self.sourcesByVersion = {}
	self:GetStore()
	-- GFVER1 is a stable-release protocol. A beta build may still use the
	-- display and settings feature-version paths, but it must not register
	-- transport callbacks that can query or answer with prerelease metadata.
	if not getInstalledVersion() then
		return false
	end

	local transport = GF.AddonMessageTransport
	if not (transport and type(transport.RegisterProtocol) == "function") then
		return false
	end
	local channelPolicy = transport.CHANNEL_POLICY
		and transport.CHANNEL_POLICY.NATIVE or nil
	self.handle = transport:RegisterProtocol(
		PREFIX,
		function(...)
			return self:HandleMessage(...)
		end,
		{
			channelPolicy = channelPolicy,
			onContextChanged = function(...)
				self:HandleGroupContextChanged(...)
			end,
		})
	if not self.handle then
		return false
	end
	local channel, signature, generation =
		self.handle:GetGroupContext("version-init")
	self:HandleGroupContextChanged(channel, signature, generation)
	return type(self.handle.IsRegistered) ~= "function"
		or self.handle:IsRegistered() == true
end
