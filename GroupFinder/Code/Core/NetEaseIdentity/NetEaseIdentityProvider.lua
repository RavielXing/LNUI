local _, GF = ...

GF.NetEaseIdentityProvider = GF.NetEaseIdentityProvider or {}
local Provider = GF.NetEaseIdentityProvider

-- The wire contract is verified against MeetingStone 12.2.2, but this client
-- owns its transport, cache and lifecycle and never reads MeetingStone state.
local SOCKET_PREFIX = "NERB"
local SERVER_PREFIX = "S1"
local CACHE_TTL_SECONDS = 24 * 60 * 60
local QUERY_COOLDOWN_SECONDS = 60
local FAILURE_COOLDOWN_SECONDS = 10 * 60
local RESPONSE_TIMEOUT_SECONDS = 30
local CONNECTION_GRACE_SECONDS = 30
local RECONNECT_DELAY_SECONDS = 3
local LOGIN_DELIVERY_TIMEOUT_SECONDS = 5
local LOGIN_QUERY_GRACE_SECONDS = 2
local HEALTH_DELIVERY_TIMEOUT_SECONDS = 30
local HEALTH_RESPONSE_TIMEOUT_SECONDS = 30
local BATCH_DELAY_SECONDS = 0.5
local MAX_BATCH_SIZE = 100
local MAX_CACHE_ENTRIES = 1000

local function wallNow()
	if type(GetServerTime) == "function" then
		local ok, value = pcall(GetServerTime)
		if ok and type(value) == "number" and value > 0 then
			return value
		end
	end
	if type(time) == "function" then
		local ok, value = pcall(time)
		if ok and type(value) == "number" then
			return value
		end
	end
	return 0
end

local function runtimeNow()
	if type(GetTime) == "function" then
		local ok, value = pcall(GetTime)
		if ok and type(value) == "number" then
			return value
		end
	end
	return wallNow()
end

local function resolveLibrary(major)
	if type(GF.GetOptionalLibrary) ~= "function" then
		return nil
	end
	local ok, library = pcall(GF.GetOptionalLibrary, major)
	return ok and library or nil
end

local function safeMethod(target, method, ...)
	if type(target) ~= "table" or type(target[method]) ~= "function" then
		return false
	end
	return pcall(target[method], target, ...)
end

local function cancelTimer(timer)
	if timer and type(timer.Cancel) == "function" then
		pcall(timer.Cancel, timer)
	end
end

local function countMap(value)
	local count = 0
	for _ in pairs(type(value) == "table" and value or {}) do
		count = count + 1
	end
	return count
end

local function splitQueryNames(value)
	local names = {}
	if type(value) ~= "string" then
		return names
	end
	for name in value:gmatch("[^,]+") do
		names[#names + 1] = name
	end
	return names
end

local function expectedAceCommCallbacks(payload)
	local length = type(payload) == "string" and #payload or 0
	local firstByte = length > 0 and payload:byte(1) or nil
	local forceMultipart = firstByte and firstByte >= 1
		and firstByte <= 9 and length + 1 > 255
	if not forceMultipart and length <= 255 then
		return 1
	end
	return math.max(1, math.ceil(length / 254))
end

local function currentRealmName()
	if type(GetRealmName) ~= "function" then
		return nil
	end
	local ok, realm = pcall(GetRealmName)
	return ok and type(realm) == "string" and realm ~= "" and realm or nil
end

local function normalizeName(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local ok, normalized = pcall(function()
		return name:gsub("^%s+", ""):gsub("%s+$", "")
	end)
	if not ok or normalized == "" then
		return nil
	end
	if type(Ambiguate) == "function" then
		local ambiguousOK, ambiguous = pcall(Ambiguate, normalized, "none")
		if ambiguousOK and type(ambiguous) == "string" and ambiguous ~= "" then
			normalized = ambiguous
		end
	end
	local character, realm = normalized:match("^([^-]+)%-(.+)$")
	if not character then
		if normalized:find("-", 1, true) then
			return nil
		end
		local realm = currentRealmName()
		if not realm then
			return nil
		end
		normalized = normalized .. "-" .. realm
	elseif character:match("^%s*$") or realm:match("^%s*$") then
		return nil
	end
	return normalized
end

local function currentPlayerFullName()
	if type(UnitName) ~= "function" then
		return nil
	end
	local ok, name, realm = pcall(UnitName, "player")
	if not ok or type(name) ~= "string" or name == "" then
		return nil
	end
	if type(realm) == "string" and realm ~= "" then
		return normalizeName(name .. "-" .. realm)
	end
	return normalizeName(name)
end

local function copyTable(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copyTable(item)
	end
	return result
end

local function ensureStorage()
	_G.GroupFinderNetEaseIdentityDB =
		type(_G.GroupFinderNetEaseIdentityDB) == "table"
		and _G.GroupFinderNetEaseIdentityDB or {}
	local storage = _G.GroupFinderNetEaseIdentityDB
	storage.identities = type(storage.identities) == "table"
		and storage.identities or {}
	storage.failed = type(storage.failed) == "table"
		and storage.failed or {}
	storage.meta = type(storage.meta) == "table" and storage.meta or {}
	storage.meta.protocolVersion = GF.NetEaseActivity
		and GF.NetEaseActivity.PROTOCOL_VERSION or "12.2.2"
	Provider.storage = storage
	Provider.cache = storage.identities
	Provider.failed = storage.failed
	return storage
end

local function getFactionGroup()
	if type(UnitFactionGroup) ~= "function" then
		return nil
	end
	local ok, faction = pcall(UnitFactionGroup, "player")
	return ok and type(faction) == "string" and faction ~= ""
		and faction or nil
end

local function addonIsLoaded(name)
	local checker = GF.Compat and GF.Compat.IsAddOnFullyLoaded
	if type(checker) ~= "function" then
		return false
	end
	return checker(name) == true
end

local function getAddonSource()
	for _, item in ipairs({
		{ "BigFoot", 1 },
		{ "!!!163UI!!!", 2 },
		{ "Duowan", 4 },
		{ "ElvUI", 8 },
	}) do
		if addonIsLoaded(item[1]) then
			return item[2]
		end
	end
	return 0
end

local function getBattleTag()
	if type(BNGetInfo) ~= "function" then
		return nil
	end
	local ok, _, battleTag = pcall(BNGetInfo)
	return ok and battleTag or nil
end

local function copyIdentity(name, data)
	if type(data) ~= "table" then
		return nil
	end
	return {
		name = name,
		level = data.level,
		starLevel = data.starLevel,
		isNewbie = data.isNewbie == true,
		newbieExpireTime = data.newbieExpireTime,
		bgID = data.bgID,
		roomID = data.roomID,
		medalMap = copyTable(data.medalMap),
		updatedAt = tonumber(data.updatedAt),
	}
end

function Provider:SetClientInfo(info)
	if type(info) ~= "table" then
		return false
	end
	self.clientAddonName = info.addonName or info.name or self.clientAddonName
	self.protocolVersion = info.version or self.protocolVersion
	self.clientSource = info.source
	self.loginQueryData = type(info.loginQueryData) == "table"
		and info.loginQueryData or self.loginQueryData
	return true
end

function Provider:Resolve()
	ensureStorage()
	if self.socketLibrary then
		return true
	end
	if type(IsTrialAccount) == "function" then
		local ok, trial = pcall(IsTrialAccount)
		if ok and trial == true then
			return false, "trial-account"
		end
	end
	if not getFactionGroup() then
		return false, "missing-faction"
	end
	local socket = resolveLibrary("NetEaseSocket-2.0")
	if type(socket) ~= "table" or type(socket.Embed) ~= "function" then
		return false, "netease-transport-unavailable"
	end
	self.socketLibrary = socket
	return true
end

function Provider:IsAvailable()
	return self:Resolve() == true
end

function Provider:IsServerOnline()
	return self.started == true and self.connected == true
end

function Provider:RegisterCallback(owner, eventName, method)
	if type(owner) ~= "table" or type(eventName) ~= "string"
		or (type(method) ~= "string" and type(method) ~= "function")
	then
		return false
	end
	self.callbacks = self.callbacks or {}
	self.callbacks[eventName] = self.callbacks[eventName] or {}
	self.callbacks[eventName][owner] = method
	return true
end

function Provider:FireCallback(eventName, ...)
	local callbacks = self.callbacks and self.callbacks[eventName]
	if type(callbacks) ~= "table" then
		return
	end
	for owner, method in pairs(callbacks) do
		local callback = type(method) == "string" and owner[method] or method
		if type(callback) == "function" then
			pcall(callback, owner, eventName, ...)
		end
	end
end

function Provider:PrepareClient()
	if self.client then
		return true
	end
	local available, reason = self:Resolve()
	if not available then
		return false, reason
	end
	local client = {}
	function client:OnServerConnected()
		Provider:OnServerConnected()
	end
	function client:OnServerDisconnected(eventName, reason)
		Provider:OnServerDisconnected(eventName, reason)
	end
	function client:OnServerVersion(eventName, ...)
		Provider:OnServerVersion(eventName, ...)
	end
	function client:OnBootstrapResponse(eventName, ...)
		Provider:OnBootstrapResponse(eventName, ...)
	end
	function client:OnPlayerIdentityResponse(eventName, maps)
		Provider:OnPlayerIdentityResponse(eventName, maps)
	end
	local ok, embedReason = pcall(self.socketLibrary.Embed,
		self.socketLibrary, client)
	if not ok or type(client.ListenSocket) ~= "function"
		or type(client.ConnectServer) ~= "function"
		or type(client.RegisterServer) ~= "function"
		or type(client.SendServer) ~= "function"
	then
		return false, embedReason or "netease-client-contract-unavailable"
	end
	self.client = client
	return true
end

function Provider:RegisterClientHandlers()
	if self.handlersRegistered then
		return true
	end
	-- NetEaseSocketMiddleware installs RegisterCallback only from Listen().
	-- RegisterServer must therefore run after ListenSocket, matching the
	-- transport's actual lifecycle rather than merely its embedded method set.
	for _, handler in ipairs({
		{ "SERVER_CONNECTED", "OnServerConnected" },
		{ "SERVER_DISCONNECTED", "OnServerDisconnected" },
		{ "SVERSION", "OnServerVersion" },
		{ "SQTB", "OnBootstrapResponse" },
		{ "SQGLIB", "OnPlayerIdentityResponse" },
	}) do
		if not safeMethod(self.client, "RegisterServer",
			handler[1], handler[2])
		then
			return false, "netease-handler-registration-failed"
		end
	end
	self.handlersRegistered = true
	return true
end

function Provider:Start()
	if self.sessionActive ~= true then
		self.sessionGeneration = (self.sessionGeneration or 0) + 1
		self.sessionActive = true
	end
	if self.started then
		-- ADDON_LOADED can connect before the player identity is readable.
		-- PLAYER_LOGIN calls Start again; recover the missing startup probe
		-- without duplicating a healthy or already queued session check.
		if self:IsServerOnline() and not self.healthProbeName then
			return self:SendLogin()
		end
		return true
	end
	local ready, reason = self:PrepareClient()
	if not ready then
		self.startFailureReason = reason
		return false, reason
	end
	local faction = getFactionGroup()
	local serverTarget = faction and SERVER_PREFIX .. faction or nil
	if not serverTarget then
		self.startFailureReason = "missing-server-target"
		return false, "missing-server-target"
	end
	self.started = true
	self.startedAt = runtimeNow()
	self.connectionStartedAt = self.startedAt
	self.connectionDeadlineAt =
		self.connectionStartedAt + CONNECTION_GRACE_SECONDS
	self.connected = false
	local listenOK = safeMethod(self.client, "ListenSocket",
		SOCKET_PREFIX, serverTarget)
	if not listenOK then
		self.started = false
		self.startFailureReason = "netease-listen-failed"
		return false, self.startFailureReason
	end
	local handlersOK, handlersReason = self:RegisterClientHandlers()
	if not handlersOK then
		self.started = false
		self.startFailureReason = handlersReason
		return false, handlersReason
	end
	local connectOK = safeMethod(self.client, "ConnectServer")
	if not connectOK then
		self.started = false
		self.startFailureReason = "netease-connect-failed"
		return false, self.startFailureReason
	end
	self.startFailureReason = nil
	return true
end

function Provider:ResetTransientFailures()
	ensureStorage()
	for name in pairs(self.failed or {}) do
		self.failed[name] = nil
	end
	self.lastTimeoutAt = nil
	self.lastInvalidResponseAt = nil
	self.lastSendFailureAt = nil
	self.lastSendFailureReason = nil
	self.lastDeliveryFailureAt = nil
	self.lastDeliveryFailureReason = nil
	self.healthProbeTimeoutAt = nil
	self.healthProbeFailureReason = nil
	self.bulkQueryCooldownUntil = nil
	self.serviceTargetUnavailableAt = nil
	self.serviceTargetUnavailableReason = nil
	return true
end

function Provider:RefreshSession()
	self:ResetTransientFailures()
	-- A manual refresh starts a new health-check generation. Old list work is
	-- deliberately discarded so the button can never trigger an immediate
	-- bulk replay before the identity endpoint proves that it responds.
	self:CancelQueries()
	self.sessionGeneration = (self.sessionGeneration or 0) + 1
	self.sessionActive = true
	if not self.started then
		return self:Start()
	end
	if self:IsServerOnline() then
		return self:SendLogin()
	end
	self.connectionStartedAt = runtimeNow()
	self.connectionDeadlineAt =
		self.connectionStartedAt + CONNECTION_GRACE_SECONDS
	local ok = safeMethod(self.client, "ConnectServer")
	if not ok then
		self.startFailureReason = "netease-connect-failed"
		return false, self.startFailureReason
	end
	self.startFailureReason = nil
	return true
end

function Provider:GetSocketHandler()
	local handlers = self.socketLibrary and self.socketLibrary.handlers
	if type(handlers) ~= "table" or type(self.client) ~= "table" then
		return nil
	end
	return rawget(handlers, self.client)
end

function Provider:RecordRuntimeDiagnostic(eventName, reason)
	local storage = ensureStorage()
	storage.meta.runtimeDiagnostic = {
		at = wallNow(),
		event = eventName,
		reason = reason,
		started = self.started == true,
		connected = self.connected == true,
		loginQueued = self.lastLoginAt ~= nil,
		loginDelivered = self.lastLoginDeliveredAt ~= nil,
		queryQueued = self.lastQueryAtBatch ~= nil,
		queryDelivered = self.lastQueryDeliveredAt ~= nil,
		bootstrapResponded = self.lastBootstrapResponseAt ~= nil,
		healthProbeStarted = self.healthProbeStartedAt ~= nil,
		healthProbeDelivered = self.healthProbeDeliveredAt ~= nil,
		healthProbeResponded = self.healthProbeResponseAt ~= nil,
		identityResponded = self.lastResponseAt ~= nil,
		timedOut = self.lastTimeoutAt ~= nil,
	}
end

function Provider:OnServerCommandDelivery(delivery, sent, total)
	if type(delivery) ~= "table" then
		return
	end
	if self.sessionActive ~= true
		or delivery.sessionGeneration ~= self.sessionGeneration
	then
		return
	end

	self.lastDeliveryProgressAt = runtimeNow()
	self.lastDeliveryProgressCommand = delivery.command
	self.lastDeliveryProgressSent = sent
	self.lastDeliveryProgressTotal = total

	local delivered
	if type(sent) == "boolean" then
		if not sent then
			delivered = false
		else
			delivery.completedCallbacks =
				(delivery.completedCallbacks or 0) + 1
			if delivery.completedCallbacks
				< (delivery.expectedCallbacks or 1)
			then
				return
			end
			delivered = true
		end
	elseif type(sent) == "number" then
		if type(total) == "number" and sent < total then
			return
		end
		delivered = true
	else
		delivered = sent ~= nil
	end

	if not delivered then
		delivery.failed = true
		self.lastDeliveryFailureAt = runtimeNow()
		self.lastDeliveryFailureReason = "chat-delivery-failed"
		if delivery.command == "CQGLIB" then
			self.identityServiceConfirmed = false
			self.bulkQueryCooldownUntil = runtimeNow()
				+ FAILURE_COOLDOWN_SECONDS
			for _, name in ipairs(delivery.names or {}) do
				if name == self.healthProbeName then
					if self.pending then
						self.pending[name] = nil
					end
					self.healthProbeFailureReason =
						"chat-delivery-failed"
					self.healthProbePhase = nil
					self.healthProbeDeadlineAt = nil
				end
			end
			self:FreezeBulkQueries("chat-delivery-failed")
		end
		self:RecordRuntimeDiagnostic("delivery-failed",
			self.lastDeliveryFailureReason)
		return
	end

	delivery.delivered = true
	local currentTime = runtimeNow()
	self.lastDeliveredAt = currentTime
	self.lastDeliveredCommand = delivery.command
	self.lastDeliveryFailureReason = nil

	if delivery.command == "SLOGIN" then
		self.lastLoginDeliveredAt = currentTime
		self.lastLoginDeliveredVersion = delivery.firstArg
		if self.lastLoginDeliveryHandledId ~= delivery.sendId then
			self.lastLoginDeliveryHandledId = delivery.sendId
			self:SendServerCommand("CQTB")
			-- A health probe may already be waiting on the conservative
			-- login-delivery fallback. Once SLOGIN is genuinely delivered,
			-- restart that flush from the shorter post-login grace so API
			-- status does not lag behind the real transport state.
			cancelTimer(self.flushTimer)
			self.flushTimer = nil
			self.flushPending = false
			self:ScheduleFlush(LOGIN_QUERY_GRACE_SECONDS)
		end
	elseif delivery.command == "CQTB" then
		self.lastBootstrapDeliveredAt = currentTime
	elseif delivery.command == "CQGLIB" then
		self.lastQueryDeliveredAt = currentTime
		local deliveredHealthProbe = false
		for _, name in ipairs(delivery.names or {}) do
			self.pending = self.pending or {}
			self.pending[name] = self.pending[name] or {}
			self.pending[name].sendId = delivery.sendId
			self.pending[name].sentAt = currentTime
			if name == self.healthProbeName
				and self.pending[name].healthProbeGeneration
					== self.healthProbeGeneration
			then
				deliveredHealthProbe = true
			end
		end
		if deliveredHealthProbe then
			self:ScheduleHealthProbeTimeout(
				delivery.sendId, currentTime)
		end
		self:ScheduleTimeoutCheck()
	end
	self:RecordRuntimeDiagnostic("delivered-" .. delivery.command)
end

function Provider:ScheduleHealthProbeTimeout(sendId, deliveredAt)
	cancelTimer(self.healthProbeTimer)
	self.healthProbeTimer = nil
	self.healthProbeDeliveredAt = deliveredAt
	self.healthProbeSendId = sendId
	self.healthProbePhase = "response"
	self.healthProbeDeadlineAt =
		deliveredAt + HEALTH_RESPONSE_TIMEOUT_SECONDS
	local generation = self.healthProbeGeneration
	local name = self.healthProbeName
	if not (C_Timer and type(C_Timer.NewTimer) == "function") then
		return
	end
	self.healthProbeTimer = C_Timer.NewTimer(
		HEALTH_RESPONSE_TIMEOUT_SECONDS, function()
			if Provider.healthProbeGeneration ~= generation
				or Provider.healthProbeSendId ~= sendId
				or (Provider.healthProbeResponseAt
					and Provider.healthProbeResponseAt >= deliveredAt)
			then
				return
			end
			local currentTime = runtimeNow()
			local pending = Provider.pending
				and Provider.pending[name]
			if pending
				and pending.healthProbeGeneration == generation
			then
				Provider.pending[name] = nil
			end
			if Provider.queue then
				Provider.queue[name] = nil
			end
			Provider.failed = Provider.failed or {}
			Provider.failed[name] = {
				reason = "health-check-timeout",
				updatedAt = wallNow(),
			}
			Provider.lastTimeoutAt = currentTime
			Provider.healthProbeTimeoutAt = currentTime
			Provider.healthProbeFailureReason =
				"health-check-timeout"
			Provider.healthProbePhase = nil
			Provider.healthProbeDeadlineAt = nil
			Provider.identityServiceConfirmed = false
			Provider.bulkQueryCooldownUntil = currentTime
				+ FAILURE_COOLDOWN_SECONDS
			Provider:FreezeBulkQueries("health-check-timeout")
			Provider:FireCallback(
				"PlayerIdentityFailed", name,
				"health-check-timeout")
			Provider:RecordRuntimeDiagnostic(
				"health-check-timeout", "health-check-timeout")
		end)
end

function Provider:ScheduleHealthProbeDeliveryTimeout()
	cancelTimer(self.healthProbeTimer)
	self.healthProbeTimer = nil
	local generation = self.healthProbeGeneration
	local name = self.healthProbeName
	local startedAt = self.healthProbeStartedAt or runtimeNow()
	self.healthProbePhase = "delivery"
	self.healthProbeDeadlineAt =
		startedAt + HEALTH_DELIVERY_TIMEOUT_SECONDS
	if not (C_Timer and type(C_Timer.NewTimer) == "function") then
		return
	end
	self.healthProbeTimer = C_Timer.NewTimer(
		HEALTH_DELIVERY_TIMEOUT_SECONDS, function()
			if Provider.healthProbeGeneration ~= generation
				or Provider.healthProbeDeliveredAt
				or Provider.healthProbeResponseAt
			then
				return
			end
			local currentTime = runtimeNow()
			if Provider.pending then
				Provider.pending[name] = nil
			end
			if Provider.queue then
				Provider.queue[name] = nil
			end
			Provider.failed = Provider.failed or {}
			Provider.failed[name] = {
				reason = "health-delivery-timeout",
				updatedAt = wallNow(),
			}
			Provider.healthProbeTimer = nil
			Provider.lastTimeoutAt = currentTime
			Provider.healthProbeTimeoutAt = currentTime
			Provider.healthProbeFailureReason =
				"health-delivery-timeout"
			Provider.healthProbePhase = nil
			Provider.healthProbeDeadlineAt = nil
			Provider.identityServiceConfirmed = false
			Provider.bulkQueryCooldownUntil = currentTime
				+ FAILURE_COOLDOWN_SECONDS
			Provider:FreezeBulkQueries("health-delivery-timeout")
			Provider:FireCallback(
				"PlayerIdentityFailed", name,
				"health-delivery-timeout")
			Provider:RecordRuntimeDiagnostic(
				"health-delivery-timeout", "health-delivery-timeout")
		end)
end

local function handleServerCommandDelivery(delivery, sent, total)
	Provider:OnServerCommandDelivery(delivery, sent, total)
end

function Provider:SendServerCommand(command, ...)
	if not self:IsServerOnline() then
		return false, "waiting_connection"
	end

	local handler = self:GetSocketHandler()
	local target = handler and handler.target
	if type(target) ~= "string" or target == "" then
		self.lastSendFailureAt = runtimeNow()
		self.lastSendFailureReason = "missing-server-target"
		self:RecordRuntimeDiagnostic("send-failed",
			self.lastSendFailureReason)
		return false, self.lastSendFailureReason
	end

	local aceComm = resolveLibrary("AceComm-3.0")
	local serializer = resolveLibrary("AceSerializer-3.0")
	if type(aceComm) ~= "table"
		or type(aceComm.SendCommMessage) ~= "function"
	then
		self.lastSendFailureAt = runtimeNow()
		self.lastSendFailureReason = "missing-AceComm-3.0"
		return false, self.lastSendFailureReason
	end
	if type(serializer) ~= "table"
		or type(serializer.Serialize) ~= "function"
	then
		self.lastSendFailureAt = runtimeNow()
		self.lastSendFailureReason = "missing-AceSerializer-3.0"
		return false, self.lastSendFailureReason
	end

	local serializedOK, payload = pcall(
		serializer.Serialize, serializer, command, ...)
	if not serializedOK or type(payload) ~= "string" then
		self.lastSendFailureAt = runtimeNow()
		self.lastSendFailureReason = "serialize-failed"
		return false, self.lastSendFailureReason
	end

	self.sendSequence = (self.sendSequence or 0) + 1
	local firstArg = ...
	local delivery = {
		command = command,
		sendId = self.sendSequence,
		sessionGeneration = self.sessionGeneration,
		firstArg = firstArg,
		names = command == "CQGLIB" and splitQueryNames(firstArg) or nil,
		expectedCallbacks = expectedAceCommCallbacks(payload),
	}
	local sendOK, sendReason = pcall(
		aceComm.SendCommMessage,
		aceComm,
		SOCKET_PREFIX,
		payload,
		"WHISPER",
		target,
		"NORMAL",
		handleServerCommandDelivery,
		delivery)
	if not sendOK or delivery.failed then
		self.lastSendFailureAt = runtimeNow()
		self.lastSendFailureReason = delivery.failed
			and "chat-delivery-failed" or "netease-send-failed"
		self:RecordRuntimeDiagnostic("send-failed",
			self.lastSendFailureReason)
		return false, self.lastSendFailureReason
	end

	self.lastOutboundAt = runtimeNow()
	self.lastOutboundCommand = command
	self.lastOutboundSendId = delivery.sendId
	self.lastSendFailureReason = nil
	return true, nil, delivery.sendId
end

function Provider:SendLogin()
	if self.sessionActive ~= true then
		return false, "session-inactive"
	end
	local guid
	if type(UnitGUID) == "function" then
		local ok, value = pcall(UnitGUID, "player")
		guid = ok and value or nil
	end
	local version = self.protocolVersion
		or (GF.NetEaseActivity and GF.NetEaseActivity.PROTOCOL_VERSION)
		or "12.2.2"
	local source = self.clientSource
	if source == nil then
		source = getAddonSource()
	end
	local loginData = type(self.loginQueryData) == "table"
		and self.loginQueryData or {}
	self.lastLoginAt = runtimeNow()
	self.lastLoginVersion = version
	self.lastLoginDeliveredAt = nil
	self.lastLoginDeliveryHandledId = nil
	self.identityServiceConfirmed = false
	local ok, reason, sendId = self:SendServerCommand(
		"SLOGIN", version, guid, source, getBattleTag(), loginData)
	if ok then
		self.lastLoginSendId = sendId
		local sessionGeneration = self.sessionGeneration
		cancelTimer(self.loginFallbackTimer)
		if C_Timer and type(C_Timer.NewTimer) == "function" then
			self.loginFallbackTimer = C_Timer.NewTimer(
				LOGIN_DELIVERY_TIMEOUT_SECONDS, function()
					if Provider.sessionActive == true
						and Provider.sessionGeneration == sessionGeneration
						and Provider.lastLoginSendId == sendId
						and not Provider.lastLoginDeliveredAt
					then
						Provider.lastLoginDeliveryTimeoutAt = runtimeNow()
						Provider:SendServerCommand("CQTB")
						Provider:ScheduleFlush(
							LOGIN_QUERY_GRACE_SECONDS)
						Provider:RecordRuntimeDiagnostic(
							"login-delivery-timeout")
					end
				end)
		end
		self:BeginHealthCheck()
	end
	return ok, reason
end

function Provider:BeginHealthCheck()
	if self.sessionActive ~= true then
		return false, "session-inactive"
	end
	cancelTimer(self.healthProbeTimer)
	self.healthProbeTimer = nil
	local previousName = self.healthProbeName
	if previousName then
		if self.pending then
			self.pending[previousName] = nil
		end
		if self.queue then
			self.queue[previousName] = nil
		end
	end
	self.healthProbeGeneration =
		(self.healthProbeGeneration or 0) + 1
	self.healthProbeStartedAt = runtimeNow()
	self.healthProbeDeliveredAt = nil
	self.healthProbeResponseAt = nil
	self.healthProbeTimeoutAt = nil
	self.healthProbeFailureReason = nil
	self.healthProbeSendId = nil
	self.healthProbePhase = nil
	self.healthProbeDeadlineAt = nil
	local name = currentPlayerFullName()
	self.healthProbeName = name
	if not name then
		return false, "missing-player-name"
	end
	local _, status, reason = self:QueuePlayer(name, true, {
		healthProbe = true,
	})
	if status ~= "pending" then
		self.healthProbeFailureReason =
			reason or "health-check-queue-failed"
		return false, self.healthProbeFailureReason
	end
	if self.pending and self.pending[name] then
		self.pending[name].healthProbeGeneration =
			self.healthProbeGeneration
	end
	self:ScheduleHealthProbeDeliveryTimeout()
	self:RecordRuntimeDiagnostic("health-check-queued")
	return true
end

function Provider:GetQuerySendDelay()
	if not self.lastLoginAt then
		return 0
	end
	local currentTime = runtimeNow()
	if not self.lastLoginDeliveredAt
		or self.lastLoginDeliveredAt < self.lastLoginAt
	then
		local required = LOGIN_DELIVERY_TIMEOUT_SECONDS
			+ LOGIN_QUERY_GRACE_SECONDS
		local elapsed = currentTime - self.lastLoginAt
		return elapsed < required and required - elapsed or 0
	end
	local elapsed = currentTime - self.lastLoginDeliveredAt
	return elapsed < LOGIN_QUERY_GRACE_SECONDS
		and LOGIN_QUERY_GRACE_SECONDS - elapsed or 0
end

function Provider:OnServerConnected()
	self.connected = true
	self.connectedAt = runtimeNow()
	self.connectionDeadlineAt = nil
	self.lastServerConnected = true
	self.lastServerStatusAt = self.connectedAt
	self.serviceTargetUnavailableAt = nil
	self.serviceTargetUnavailableReason = nil
	self:FireCallback("ServerStatusChanged", true)
	if self.sessionActive ~= true then
		self:RecordRuntimeDiagnostic("server-connected-idle")
		return
	end
	self:SendLogin()
	if next(self.queue or {}) then
		self:ScheduleFlush(BATCH_DELAY_SECONDS)
	end
	self:RecordRuntimeDiagnostic("server-connected")
end

function Provider:OnServerDisconnected(eventName, reason)
	local wasConnected = self.connected == true
	local disconnectedAt = runtimeNow()
	cancelTimer(self.loginFallbackTimer)
	cancelTimer(self.healthProbeTimer)
	self.loginFallbackTimer = nil
	self.healthProbeTimer = nil
	self.healthProbePhase = nil
	self.healthProbeDeadlineAt = nil
	self.connected = false
	self.identityServiceConfirmed = false
	-- A disconnect from a live session starts one new connection window.
	-- Repeated failures while already reconnecting must not move its deadline;
	-- otherwise the visible countdown can remain at 30 forever.
	if self.sessionActive ~= true then
		self.connectionStartedAt = nil
		self.connectionDeadlineAt = nil
	elseif wasConnected
		or type(self.connectionStartedAt) ~= "number"
		or type(self.connectionDeadlineAt) ~= "number"
	then
		self.connectionStartedAt = disconnectedAt
		self.connectionDeadlineAt =
			disconnectedAt + CONNECTION_GRACE_SECONDS
	end
	self.lastServerConnected = false
	self.lastServerStatusAt = disconnectedAt
	self:FireCallback("ServerStatusChanged", false)
	if reason == "service-target-not-found" then
		self.serviceTargetUnavailableAt = self.connectionStartedAt
		self.serviceTargetUnavailableReason = reason
	else
		self.serviceTargetUnavailableAt = nil
		self.serviceTargetUnavailableReason = nil
	end
	self:FreezeBulkQueries(reason or "netease-disconnected")
	if self.sessionActive == true
		and reason ~= "service-target-not-found"
		and C_Timer and type(C_Timer.After) == "function"
	then
		C_Timer.After(RECONNECT_DELAY_SECONDS, function()
			if Provider.sessionActive == true
				and Provider.started and not Provider.connected and Provider.client
			then
				safeMethod(Provider.client, "ConnectServer")
			end
		end)
	end
	self:RecordRuntimeDiagnostic("server-disconnected", reason)
end

function Provider:OnServerVersion(eventName, ...)
	local supported = select(3, ...)
	if supported ~= nil and supported == false then
		self.serverUnsupported = true
		self.unsupportedReason = "server-unsupported"
		self:FireCallback("PlayerIdentityFailed", nil,
			self.unsupportedReason)
	end
end

function Provider:OnBootstrapResponse(eventName, isDeal)
	self.lastBootstrapResponseAt = runtimeNow()
	self.lastBootstrapIsDeal = isDeal
	self:RecordRuntimeDiagnostic("bootstrap-response")
end

function Provider:BuildIdentity(name, data)
	if type(name) ~= "string" or name == "" or type(data) ~= "table" then
		return nil
	end
	-- MeetingStone 12.2.2 treats an omitted Newbie marker as false for a
	-- player row that the service actually returned. A missing row still never
	-- reaches this parser, so timeouts cannot be promoted to Veteran identity.
	local newbieFlag = data.n == nil and 0 or tonumber(data.n)
	if newbieFlag ~= 0 and newbieFlag ~= 1 then
		return nil
	end
	local remainCount = data.r == nil and 0 or tonumber(data.r)
	if not remainCount or remainCount < 0 then
		return nil
	end
	local function normalizedLevel(value)
		if value == nil then
			return nil, true
		end
		local level = tonumber(value)
		if not level or level ~= math.floor(level) then
			return nil, false
		end
		return level, true
	end
	local level, validLevel = normalizedLevel(data.l)
	local starLevel, validStarLevel = normalizedLevel(data.s)
	if not validLevel or not validStarLevel then
		return nil
	end
	local currentTime = wallNow()
	return {
		name = name,
		level = level,
		starLevel = starLevel,
		isNewbie = newbieFlag == 1,
		newbieExpireTime = newbieFlag == 1
			and currentTime + remainCount * 30 * 60 or nil,
		bgID = data.b or 0,
		roomID = data.c,
		medalMap = {
			acc_exp = data.ae,
			next_star_level_threshold = data.ne,
			medal = copyTable(data.m),
		},
		updatedAt = currentTime,
	}
end

function Provider:PruneCache()
	local entries = {}
	for name, data in pairs(self.cache or {}) do
		entries[#entries + 1] = {
			name = name,
			updatedAt = type(data) == "table" and data.updatedAt or 0,
		}
	end
	if #entries <= MAX_CACHE_ENTRIES then
		return
	end
	table.sort(entries, function(left, right)
		return (left.updatedAt or 0) < (right.updatedAt or 0)
	end)
	for index = 1, #entries - MAX_CACHE_ENTRIES do
		self.cache[entries[index].name] = nil
	end
end

function Provider:OnPlayerIdentityResponse(eventName, maps)
	if self.sessionActive ~= true then
		self:RecordRuntimeDiagnostic("identity-response-ignored",
			"session-inactive")
		return
	end
	self.lastResponseAt = runtimeNow()
	if type(maps) ~= "table" then
		self.lastInvalidResponseAt = self.lastResponseAt
		self.identityServiceConfirmed = false
		self.bulkQueryCooldownUntil = self.lastResponseAt
			+ FAILURE_COOLDOWN_SECONDS
		self:FreezeBulkQueries("invalid-response")
		self:RecordRuntimeDiagnostic("invalid-identity-response",
			"invalid-response")
		return
	end
	self.lastInvalidResponseAt = nil
	if self.healthProbeDeliveredAt
		and self.lastResponseAt >= self.healthProbeDeliveredAt
	then
		self.healthProbeResponseAt = self.lastResponseAt
		self.healthProbeFailureReason = nil
		self.healthProbeTimeoutAt = nil
		self.identityServiceConfirmed = true
		self.bulkQueryCooldownUntil = nil
		self.lastTimeoutAt = nil
		for failedName in pairs(self.failed or {}) do
			self.failed[failedName] = nil
		end
		self.lastQueryAt = {}
		cancelTimer(self.healthProbeTimer)
		self.healthProbeTimer = nil
		self.healthProbePhase = nil
		self.healthProbeDeadlineAt = nil
	end
	ensureStorage()
	self.pending = self.pending or {}
	self.queue = self.queue or {}
	local updatedNames = {}
	for rawName, data in pairs(maps) do
		local name = normalizeName(rawName)
		local identity = name and self:BuildIdentity(name, data) or nil
		if identity then
			self.cache[name] = identity
			self.pending[name] = nil
			self.queue[name] = nil
			self.failed[name] = nil
			updatedNames[#updatedNames + 1] = name
			self:FireCallback("PlayerIdentityUpdated", name,
				copyIdentity(name, identity))
		end
	end
	local healthProbeName = self.healthProbeName
	if healthProbeName and self.healthProbeResponseAt then
		self.pending[healthProbeName] = nil
		self.queue[healthProbeName] = nil
		self.failed[healthProbeName] = nil
	end
	self:PruneCache()
	self:FireCallback("PlayerIdentityBatchUpdated", updatedNames)
	if self.identityServiceConfirmed and next(self.queue or {}) then
		self:ScheduleFlush(BATCH_DELAY_SECONDS)
	end
	self:RecordRuntimeDiagnostic("identity-response")
end

function Provider:GetPlayerIdentity(name)
	name = normalizeName(name)
	if not name then
		return nil
	end
	ensureStorage()
	return copyIdentity(name, self.cache[name])
end

function Provider:IsCacheFresh(identity)
	return type(identity) == "table"
		and type(identity.updatedAt) == "number"
		and wallNow() - identity.updatedAt >= 0
		and wallNow() - identity.updatedAt < CACHE_TTL_SECONDS
end

function Provider:GetPlayerIdentityStatus(name)
	name = normalizeName(name)
	if not name then
		return "missing", "invalid-name"
	end
	local identity = self:GetPlayerIdentity(name)
	if self:IsCacheFresh(identity) then
		return "fresh"
	end
	if self.pending and self.pending[name] then
		return "pending", self:IsServerOnline()
			and nil or "waiting_connection"
	end
	local failure = self.failed and self.failed[name]
	if failure and wallNow() - (failure.updatedAt or 0)
		< FAILURE_COOLDOWN_SECONDS
	then
		return "failed", failure.reason
	end
	return identity and "stale" or "missing"
end

function Provider:CanQueueBulkQueries()
	local currentTime = runtimeNow()
	if self.bulkQueryCooldownUntil
		and currentTime < self.bulkQueryCooldownUntil
	then
		return false, "failed", "service-cooldown"
	end
	if self.identityServiceConfirmed ~= true then
		local serviceStatus, _, reason = self:GetServiceStatus()
		if serviceStatus == "starting" then
			return false, "pending", reason or "health-check-pending"
		end
		if serviceStatus == "offline" then
			return false, "failed", reason or "netease-disconnected"
		end
		return false, "failed", reason or "identity-api-unavailable"
	end
	return true
end

function Provider:FreezeBulkQueries(reason)
	self.queue = self.queue or {}
	self.pending = self.pending or {}
	self.failed = self.failed or {}
	local currentTime = wallNow()
	for name in pairs(self.pending) do
		self.pending[name] = nil
		self.queue[name] = nil
		self.failed[name] = {
			reason = reason or "identity-api-unavailable",
			updatedAt = currentTime,
		}
	end
	for name in pairs(self.queue) do
		self.queue[name] = nil
	end
	cancelTimer(self.flushTimer)
	self.flushTimer = nil
	self.flushPending = false
	return true
end

function Provider:QueuePlayer(rawName, force, options)
	local name = normalizeName(rawName)
	if not name then
		return nil, "missing", "invalid-name"
	end
	local available, reason = self:Resolve()
	if not available then
		return self:GetPlayerIdentity(name), "unsupported", reason
	end
	if not self.started then
		local startOK, startReason = self:Start()
		if not startOK then
			return self:GetPlayerIdentity(name), "unsupported", startReason
		end
	end
	local identity = self:GetPlayerIdentity(name)
	if force ~= true and self:IsCacheFresh(identity) then
		return identity, "fresh"
	end
	local isHealthProbe = type(options) == "table"
		and options.healthProbe == true
	if not isHealthProbe then
		local canQueue, blockedStatus, blockedReason =
			self:CanQueueBulkQueries()
		if not canQueue then
			return identity, blockedStatus, blockedReason
		end
	end
	self.pending = self.pending or {}
	self.queue = self.queue or {}
	self.failed = self.failed or {}
	self.lastQueryAt = self.lastQueryAt or {}
	local currentTime = runtimeNow()
	local currentWallTime = wallNow()
	if self.pending[name] then
		return identity, "pending"
	end
	local failure = self.failed[name]
	if force ~= true and failure
		and currentWallTime - (failure.updatedAt or 0)
			< FAILURE_COOLDOWN_SECONDS
	then
		return identity, "failed", failure.reason
	end
	local lastQueryAt = self.lastQueryAt[name]
	if force ~= true and lastQueryAt
		and currentTime - lastQueryAt < QUERY_COOLDOWN_SECONDS
	then
		return identity, identity and "stale" or "cooldown"
	end
	self.pending[name] = {
		queuedAt = currentTime,
		healthProbeGeneration = isHealthProbe
			and self.healthProbeGeneration or nil,
	}
	self.queue[name] = force == true
	self.lastQueryAt[name] = currentTime
	self.failed[name] = nil
	self:FireCallback("PlayerIdentityQueued", name)
	if self:IsServerOnline() then
		self:ScheduleFlush(BATCH_DELAY_SECONDS)
	end
	return identity, "pending",
		self:IsServerOnline() and nil or "waiting_connection"
end

function Provider:QueryPlayerIdentity(name, force)
	return self:QueuePlayer(name, force)
end

function Provider:QueryPlayerIdentities(names, force)
	if type(names) ~= "table" then
		return 0
	end
	local canQueue, status, reason = self:CanQueueBulkQueries()
	if not canQueue then
		return 0, status, reason
	end
	local count = 0
	for _, name in ipairs(names) do
		local _, status = self:QueuePlayer(name, force)
		if status == "pending" then
			count = count + 1
		end
	end
	return count
end

function Provider:ScheduleFlush(delay)
	if self.flushPending then
		return
	end
	self.flushPending = true
	local function flush()
		Provider.flushPending = false
		Provider:FlushQueries()
	end
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		self.flushTimer = C_Timer.NewTimer(delay or BATCH_DELAY_SECONDS, flush)
	else
		flush()
	end
end

function Provider:CancelQueries()
	cancelTimer(self.flushTimer)
	cancelTimer(self.timeoutTimer)
	cancelTimer(self.loginFallbackTimer)
	cancelTimer(self.healthProbeTimer)
	self.flushTimer = nil
	self.timeoutTimer = nil
	self.loginFallbackTimer = nil
	self.healthProbeTimer = nil
	self.sessionActive = false
	self.sessionGeneration = (self.sessionGeneration or 0) + 1
	self.healthProbeGeneration = (self.healthProbeGeneration or 0) + 1
	self.healthProbeName = nil
	self.healthProbeStartedAt = nil
	self.healthProbeDeliveredAt = nil
	self.healthProbeResponseAt = nil
	self.healthProbeTimeoutAt = nil
	self.healthProbeFailureReason = nil
	self.healthProbeSendId = nil
	self.healthProbePhase = nil
	self.healthProbeDeadlineAt = nil
	self.connectionStartedAt = nil
	self.connectionDeadlineAt = nil
	self.lastLoginSendId = nil
	self.flushPending = false
	self.timeoutPending = false
	self.queue = {}
	self.pending = {}
	self.identityServiceConfirmed = false
	return true
end

function Provider:FlushQueries()
	if not self:IsServerOnline() then
		return false
	end
	local querySendDelay = self:GetQuerySendDelay()
	if querySendDelay > 0 then
		self.lastQuerySendDelay = querySendDelay
		self.lastQuerySendDelayedAt = runtimeNow()
		self:ScheduleFlush(querySendDelay)
		return false
	end
	self.lastQuerySendDelay = 0
	local names = {}
	for name in pairs(self.queue or {}) do
		local pending = self.pending and self.pending[name]
		local isCurrentHealthProbe = name == self.healthProbeName
			and pending
			and pending.healthProbeGeneration == self.healthProbeGeneration
		if self.identityServiceConfirmed == true or isCurrentHealthProbe then
			names[#names + 1] = name
			if #names >= MAX_BATCH_SIZE then
				break
			end
		end
	end
	table.sort(names)
	if #names == 0 then
		return true
	end
	local currentTime = runtimeNow()
	local ok, reason, sendId = self:SendServerCommand(
		"CQGLIB", table.concat(names, ","))
	if not ok then
		self.lastSendFailureAt = currentTime
		self.lastSendFailureReason = reason
		self.identityServiceConfirmed = false
		self.bulkQueryCooldownUntil = currentTime
			+ FAILURE_COOLDOWN_SECONDS
		self:FreezeBulkQueries(reason or "netease-send-failed")
		return false
	end
	self.lastQueryAtBatch = currentTime
	self.lastQueryNames = table.concat(names, ",")
	for _, name in ipairs(names) do
		self.queue[name] = nil
		self.pending[name] = self.pending[name] or {}
		self.pending[name].sendId = sendId
		-- sentAt is intentionally assigned only by the AceComm delivery
		-- callback. Queueing is not proof that WoW sent the whisper.
	end
	if next(self.queue) then
		self:ScheduleFlush(BATCH_DELAY_SECONDS)
	end
	return true
end

function Provider:ScheduleTimeoutCheck()
	if self.timeoutPending then
		return
	end
	self.timeoutPending = true
	local function check()
		Provider.timeoutPending = false
		Provider:CheckTimeouts()
	end
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		self.timeoutTimer = C_Timer.NewTimer(
			RESPONSE_TIMEOUT_SECONDS, check)
	end
end

function Provider:CheckTimeouts()
	local currentTime = runtimeNow()
	local stillPending = false
	local anyTimedOut = false
	for name, pending in pairs(self.pending or {}) do
		if pending.sentAt
			and currentTime - pending.sentAt >= RESPONSE_TIMEOUT_SECONDS
		then
			local isHealthProbe = name == self.healthProbeName
				and pending.healthProbeGeneration
					== self.healthProbeGeneration
			self.pending[name] = nil
			self.failed[name] = {
				reason = "timeout",
				updatedAt = wallNow(),
			}
			self.lastTimeoutAt = currentTime
			anyTimedOut = true
			if isHealthProbe then
				self.healthProbeTimeoutAt = currentTime
				self.healthProbeFailureReason =
					"health-check-timeout"
				self.healthProbePhase = nil
				self.healthProbeDeadlineAt = nil
				cancelTimer(self.healthProbeTimer)
				self.healthProbeTimer = nil
			end
			self:FireCallback("PlayerIdentityFailed", name, "timeout")
		elseif pending.sentAt then
			stillPending = true
		end
	end
	if anyTimedOut then
		self.identityServiceConfirmed = false
		self.bulkQueryCooldownUntil = currentTime
			+ FAILURE_COOLDOWN_SECONDS
		self:FreezeBulkQueries("timeout")
	end
	if stillPending then
		self:ScheduleTimeoutCheck()
	end
	if self.lastTimeoutAt == currentTime then
		self:RecordRuntimeDiagnostic("identity-timeout", "timeout")
	end
end

function Provider:GetServiceStatus()
	local available, reason = self:Resolve()
	local currentTime = runtimeNow()
	if not available then
		return "fault", nil, reason, {
			provider = "GroupFinder",
			available = false,
		}
	end
	if self.serverUnsupported then
		return "fault", nil, self.unsupportedReason, {
			provider = "GroupFinder",
			available = true,
		}
	end
	if self.startFailureReason then
		return "fault", nil, self.startFailureReason, {
			provider = "GroupFinder",
			available = true,
		}
	end
	if self.sessionActive ~= true then
		return "idle", nil, "session-inactive", {
			provider = "GroupFinder",
			available = true,
		}
	end
	if not self.started then
		return "starting", nil, "not-started", {
			provider = "GroupFinder",
			available = true,
			waitingSeconds = 0,
		}
	end
	if not self:IsServerOnline() then
		local waitingSeconds = currentTime
			- (self.connectionStartedAt or self.startedAt or currentTime)
		local connectionDeadline = self.connectionDeadlineAt
		if type(connectionDeadline) ~= "number" then
			return "fault", nil, "missing-connection-deadline", {
				provider = "GroupFinder",
				available = true,
			}
		end
		local unavailableReason = self.serviceTargetUnavailableReason
		local offlineReason = unavailableReason
			or (currentTime < connectionDeadline
				and "waiting_connection" or "netease-disconnected")
		return "offline", nil, offlineReason, {
			provider = "GroupFinder",
			available = true,
			waitingSeconds = waitingSeconds,
		}
	end
	if self.lastSendFailureReason or self.lastDeliveryFailureReason then
		return "fault", nil,
			self.lastSendFailureReason or self.lastDeliveryFailureReason,
		{
			provider = "GroupFinder",
			available = true,
		}
	end
	if self.lastTimeoutAt
		and (not self.lastResponseAt or self.lastResponseAt < self.lastTimeoutAt)
	then
		return "no_response", nil,
			self.healthProbeFailureReason or "timeout", {
			provider = "GroupFinder",
			available = true,
		}
	end
	if self.lastInvalidResponseAt
		and (not self.lastResponseAt
			or self.lastInvalidResponseAt >= self.lastResponseAt)
	then
		return "fault", nil, "invalid-response", {
			provider = "GroupFinder",
			available = true,
		}
	end
	if not self.healthProbeStartedAt
		or not self.healthProbeResponseAt
		or self.healthProbeResponseAt < self.healthProbeStartedAt
	then
		return "starting", nil,
			self.healthProbeFailureReason or "health-check-pending",
		{
			provider = "GroupFinder",
			available = true,
			waitingSeconds = currentTime
				- (self.healthProbeStartedAt or currentTime),
		}
	end
	if self.identityServiceConfirmed ~= true then
		return "starting", nil, "health-check-pending", {
			provider = "GroupFinder",
			available = true,
			waitingSeconds = currentTime
				- (self.healthProbeStartedAt or currentTime),
		}
	end
	return "ok", nil, nil, {
		provider = "GroupFinder",
		available = true,
	}
end

function Provider:GetHealthCheckCountdown()
	if self.sessionActive ~= true then
		return nil
	end
	local status, _, reason = self:GetServiceStatus()
	if status ~= "starting"
		and not (status == "offline" and reason == "waiting_connection")
	then
		return nil
	end
	local deadline = self.healthProbeDeadlineAt
	local phase = self.healthProbePhase
	if not deadline and not self:IsServerOnline() then
		deadline = self.connectionDeadlineAt
		phase = "connection"
	end
	if type(deadline) ~= "number" then
		return nil
	end
	return math.max(0, math.ceil(deadline - runtimeNow())), phase
end

function Provider:GetStats()
	ensureStorage()
	local handler = self:GetSocketHandler()
	local status, _, reason = self:GetServiceStatus()
	return {
		provider = "GroupFinder",
		independent = true,
		started = self.started == true,
		connected = self.connected == true,
		pendingCount = countMap(self.pending),
		queuedCount = countMap(self.queue),
		cacheCount = countMap(self.cache),
		available = self:IsAvailable(),
		online = self:IsServerOnline(),
		serviceStatus = status,
		serviceReason = reason,
		bulkQueriesAllowed = self.identityServiceConfirmed == true,
		bulkQueryCooldownUntil = self.bulkQueryCooldownUntil,
		serviceTargetUnavailableReason =
			self.serviceTargetUnavailableReason,
		socketReady = handler and handler.target ~= nil or false,
		lastLoginAt = self.lastLoginAt,
		lastLoginDeliveredAt = self.lastLoginDeliveredAt,
		lastLoginDeliveryTimeoutAt = self.lastLoginDeliveryTimeoutAt,
		lastBootstrapDeliveredAt = self.lastBootstrapDeliveredAt,
		lastBootstrapResponseAt = self.lastBootstrapResponseAt,
		healthProbeStartedAt = self.healthProbeStartedAt,
		healthProbeDeliveredAt = self.healthProbeDeliveredAt,
		healthProbeResponseAt = self.healthProbeResponseAt,
		healthProbeTimeoutAt = self.healthProbeTimeoutAt,
		lastQueryAt = self.lastQueryAtBatch,
		lastQueryDeliveredAt = self.lastQueryDeliveredAt,
		lastResponseAt = self.lastResponseAt,
		lastTimeoutAt = self.lastTimeoutAt,
		lastSendFailureReason = self.lastSendFailureReason,
		lastDeliveryFailureReason = self.lastDeliveryFailureReason,
	}
end

function Provider:GetDiagnosticSummary()
	local stats = self:GetStats()
	local function yes(value)
		return value and "yes" or "no"
	end
	return table.concat({
		"status=" .. tostring(stats.serviceStatus),
		"reason=" .. tostring(stats.serviceReason),
		"started=" .. yes(stats.started),
		"connected=" .. yes(stats.connected),
		"socket=" .. yes(stats.socketReady),
		"login=" .. yes(stats.lastLoginAt),
		"loginDelivered=" .. yes(stats.lastLoginDeliveredAt),
		"bootstrap=" .. yes(stats.lastBootstrapResponseAt),
		"healthDelivered=" .. yes(stats.healthProbeDeliveredAt),
		"healthResponse=" .. yes(stats.healthProbeResponseAt),
		"query=" .. yes(stats.lastQueryAt),
		"queryDelivered=" .. yes(stats.lastQueryDeliveredAt),
		"response=" .. yes(stats.lastResponseAt),
		"timeout=" .. yes(stats.lastTimeoutAt),
		"sendFailure=" .. tostring(stats.lastSendFailureReason),
		"deliveryFailure=" .. tostring(
			stats.lastDeliveryFailureReason),
	}, " ")
end

ensureStorage()
Provider.pending = Provider.pending or {}
Provider.queue = Provider.queue or {}
Provider.lastQueryAt = Provider.lastQueryAt or {}
