local _, GF = ...

GF.NetEaseIdentityService = GF.NetEaseIdentityService or {}
local Service = GF.NetEaseIdentityService

local REFRESH_DELAY = 0.12
local CONNECTION_GRACE_SECONDS = 30
local MANUAL_API_REFRESH_COOLDOWN_SECONDS = 10

local function isSupportedClient()
	local activity = GF.NetEaseActivity
	if not (activity and type(activity.IsSupportedClient) == "function") then
		return false
	end
	local ok, supported = pcall(activity.IsSupportedClient, activity)
	return ok and supported == true
end

local function runtimeNow()
	if type(GetTime) == "function" then
		local ok, value = pcall(GetTime)
		if ok and type(value) == "number" then
			return value
		end
	end
	return GF.NetEaseActivity and GF.NetEaseActivity:GetTimestamp() or 0
end

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return not ok or secret == true
end

local function strictFullName(value)
	if isSecret(value) then
		return nil
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible == false then
			return nil
		end
	end
	if type(value) ~= "string" then
		return nil
	end
	local ok, name = pcall(function()
		return value:gsub("^%s+", ""):gsub("%s+$", "")
	end)
	if not ok or isSecret(name) then
		return nil
	end
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local character, realm = name:match("^([^-]+)%-(.+)$")
	if not character then
		if name:find("-", 1, true) then
			return nil
		end
		if type(GetRealmName) ~= "function" then
			return nil
		end
		local realmOK, currentRealm = pcall(GetRealmName)
		if not realmOK or type(currentRealm) ~= "string"
			or currentRealm:match("^%s*$")
		then
			return nil
		end
		character = name
		realm = currentRealm
		name = character .. "-" .. realm
	end
	if character:match("^%s*$") or realm:match("^%s*$") then
		return nil
	end
	return name
end

local function readMemberName(member)
	if type(member) ~= "table" then
		return nil
	end
	if type(issecretvaluekey) == "function" then
		local ok, secret = pcall(issecretvaluekey, member, "name")
		if not ok or secret == true then
			return nil
		end
	end
	local ok, name = pcall(function()
		return member.name
	end)
	return ok and strictFullName(name) or nil
end

local function positiveLevel(value)
	if value == nil then
		return nil, false
	end
	if isSecret(value) then
		return nil, true
	end
	local number = tonumber(value)
	if not number then
		return nil, true
	end
	if number <= 0 then
		return nil, false
	end
	if number ~= math.floor(number) then
		return nil, true
	end
	return number, false
end

local function identityIsFresh(api, identity)
	if type(identity) ~= "table"
		or type(identity.isNewbie) ~= "boolean"
		or type(identity.updatedAt) ~= "number"
		or identity.updatedAt < GF.NetEaseActivity.START_AT
		or type(api.IsCacheFresh) ~= "function"
	then
		return false
	end
	if identity.newbieExpireTime ~= nil
		and tonumber(identity.newbieExpireTime) == nil
	then
		return false
	end
	local ok, fresh = pcall(api.IsCacheFresh, api, identity)
	return ok and fresh == true
end

local function serviceProjectionStatus(api, name, queryStatus, reason)
	local serviceStatus, _, serviceReason, diagnostic
	if type(api.GetServiceStatus) == "function" then
		local ok
		ok, serviceStatus, _, serviceReason, diagnostic =
			pcall(api.GetServiceStatus, api, name)
		if not ok then
			serviceStatus = "fault"
			serviceReason = "api-error"
		end
	end
	if serviceStatus == "offline" then
		local waitingSeconds = type(diagnostic) == "table"
			and tonumber(diagnostic.waitingSeconds) or nil
		if queryStatus == "pending"
			and (serviceReason == "waiting_connection"
				or reason == "waiting_connection")
			and (waitingSeconds == nil
				or waitingSeconds < CONNECTION_GRACE_SECONDS)
		then
			return "loading", "connecting", serviceReason or reason
		end
		return "offline", serviceStatus, serviceReason or reason
	end
	if serviceStatus == "fault" or serviceStatus == "no_response"
		or queryStatus == "failed" or queryStatus == "unsupported"
	then
		return "fault", serviceStatus, serviceReason or reason
	end
	return "loading", serviceStatus or "starting", reason or serviceReason
end

local function buildResolvedProjection(name, identity)
	local locomotiveLevel, malformedLocomotive = positiveLevel(identity.level)
	local starLevel, malformedStar = positiveLevel(identity.starLevel)
	if malformedLocomotive or malformedStar then
		return {
			name = name,
			status = "fault",
			primaryType = GF.NETEASE_IDENTITY_FAULT,
			fresh = false,
			reason = "invalid-role-level",
		}
	end
	local now = GF.NetEaseActivity:GetTimestamp()
	local newbieExpireTime = tonumber(identity.newbieExpireTime)
	local isNewbie = identity.isNewbie == true
		and (not newbieExpireTime or now < newbieExpireTime)
	local primaryType
	if isNewbie then
		primaryType = GF.NETEASE_IDENTITY_NEWBIE
	elseif locomotiveLevel then
		primaryType = GF.NETEASE_IDENTITY_LOCOMOTIVE
	elseif starLevel then
		primaryType = GF.NETEASE_IDENTITY_STAR
	else
		primaryType = GF.NETEASE_IDENTITY_VETERAN
	end
	local isVeteran = not isNewbie
		and locomotiveLevel == nil and starLevel == nil
	return {
		name = name,
		status = "fresh",
		primaryType = primaryType,
		isNewbie = isNewbie,
		isVeteran = isVeteran,
		locomotiveLevel = locomotiveLevel,
		starLevel = starLevel,
		fresh = true,
		updatedAt = identity.updatedAt,
	}
end

function Service:GetAPI()
	if self.api then
		return self.api
	end
	local api = GF.NetEaseIdentityProvider
	if type(api) == "table" then
		self.api = api
	end
	return self.api
end

function Service:IsUserEnabled()
	local db = GF.GetDB and GF.GetDB()
	return isSupportedClient()
		and db and db.neteaseIdentityEnabled == true
		and db.neteaseIdentityActivityId == GF.NetEaseActivity.ID
end

function Service:IsEnabled()
	return self:IsUserEnabled() and GF.NetEaseActivity:IsActive()
end

function Service:CanEnable()
	local api = self:GetAPI()
	if not (isSupportedClient()
		and GF.NetEaseActivity:IsActive() and api)
	then
		return false
	end
	if type(api.IsAvailable) ~= "function" then
		return true
	end
	local ok, available = pcall(api.IsAvailable, api)
	return ok and available == true
end

function Service:EnforceClientLocale()
	if isSupportedClient() then
		return false
	end
	local db = GF.GetDB and GF.GetDB()
	if not db then
		return false
	end
	local changed = db.neteaseIdentityEnabled == true
	db.neteaseIdentityEnabled = false
	db.neteaseIdentityActivityId = GF.NetEaseActivity.ID
	local filter = GF.MythicPlusBrowseFilter
	if filter and type(filter.SetNewbieOnly) == "function"
		and (type(filter.IsNewbieOnly) ~= "function"
			or filter:IsNewbieOnly() == true)
	then
		filter:SetNewbieOnly(false)
		changed = true
	end
	return changed
end

function Service:ResetForActivityIfNeeded()
	local db = GF.GetDB and GF.GetDB()
	if not db or db.neteaseIdentityActivityId == GF.NetEaseActivity.ID then
		return false
	end
	db.neteaseIdentityEnabled = false
	db.neteaseIdentityActivityId = GF.NetEaseActivity.ID
	local filter = GF.MythicPlusBrowseFilter
	if filter and type(filter.ResetNewbieActivity) == "function" then
		filter:ResetNewbieActivity(GF.NetEaseActivity.ID)
	end
	return true
end

function Service:SetEnabled(enabled)
	local db = GF.GetDB and GF.GetDB()
	if not db then
		return false
	end
	enabled = enabled == true and self:CanEnable()
	db.neteaseIdentityActivityId = GF.NetEaseActivity.ID
	db.neteaseIdentityEnabled = enabled
	if enabled then
		local api = self:GetAPI()
		if api and type(api.RefreshSession) == "function" then
			pcall(api.RefreshSession, api)
		elseif api and type(api.Start) == "function" then
			pcall(api.Start, api)
		end
	else
		local api = self:GetAPI()
		if api and type(api.CancelQueries) == "function" then
			pcall(api.CancelQueries, api)
		end
		local filter = GF.MythicPlusBrowseFilter
		if filter and type(filter.SetNewbieOnly) == "function" then
			filter:SetNewbieOnly(false)
		end
	end
	self:ScheduleRefresh("setting")
	return enabled
end

function Service:GetServiceStatus(name)
	if not self:IsEnabled() then
		return "disabled", "identity-query-disabled"
	end
	local api = self:GetAPI()
	if not api or type(api.GetServiceStatus) ~= "function" then
		return "fault", "missing-api"
	end
	local ok, status, _, reason, diagnostic = pcall(
		api.GetServiceStatus, api, strictFullName(name))
	if not ok then
		return "fault", "api-error"
	end
	local waitingSeconds = type(diagnostic) == "table"
		and tonumber(diagnostic.waitingSeconds) or nil
	if status == "offline" and reason == "waiting_connection"
		and (waitingSeconds == nil
			or waitingSeconds < CONNECTION_GRACE_SECONDS)
	then
		return "starting", reason
	end
	return status, reason
end

function Service:GetAPIStatusProjection()
	if not self:IsEnabled() then
		return {
			status = "disabled",
			reason = "identity-query-disabled",
		}
	end
	local status, reason = self:GetServiceStatus()
	local indicator = "offline"
	if status == "ok" then
		indicator = "online"
	elseif status == "fault" or status == "no_response" then
		indicator = "fault"
	elseif status == "starting" then
		indicator = "refreshing"
	end
	local projection = {
		status = indicator,
		reason = reason,
	}
	if indicator ~= "refreshing" then
		return projection
	end
	local api = self:GetAPI()
	if not api or type(api.GetHealthCheckCountdown) ~= "function" then
		return projection
	end
	local ok, remaining, phase = pcall(
		api.GetHealthCheckCountdown, api)
	if ok and type(remaining) == "number" then
		projection.remaining = math.max(0, math.ceil(remaining))
		projection.phase = phase
	end
	return projection
end

function Service:GetAPIStatusIndicator()
	return self:GetAPIStatusProjection().status
end

function Service:GetAPIStatusCountdown()
	local projection = self:GetAPIStatusProjection()
	return projection.remaining, projection.phase
end

function Service:CanRefreshAPIStatus()
	if not self:IsEnabled() then
		return false, "identity-query-disabled"
	end
	local api = self:GetAPI()
	if not api or type(api.RefreshSession) ~= "function" then
		return false, "refresh-unavailable"
	end
	if self:GetAPIStatusIndicator() == "refreshing" then
		return false, "refresh-pending"
	end
	if runtimeNow() < (tonumber(self.manualAPIRefreshAvailableAt) or 0) then
		return false, "refresh-cooldown"
	end
	return true
end

function Service:RefreshAPIStatus()
	local available, reason = self:CanRefreshAPIStatus()
	if not available then
		return false, reason
	end
	self.manualAPIRefreshAvailableAt =
		runtimeNow() + MANUAL_API_REFRESH_COOLDOWN_SECONDS
	local api = self:GetAPI()
	local ok, refreshed, refreshReason = pcall(api.RefreshSession, api)
	self:ScheduleRefresh("manual-api-status-refresh")
	if not ok then
		return false, "refresh-error"
	end
	if refreshed == false then
		return false, refreshReason or "refresh-failed"
	end
	return true
end

function Service:IsQueryPending()
	local api = self:GetAPI()
	if not (api and type(api.GetStats) == "function") then
		return false
	end
	local ok, stats = pcall(api.GetStats, api)
	return ok and type(stats) == "table"
		and (tonumber(stats.pendingCount) or 0) > 0
end

function Service:GetIdentityProjection(name, options)
	name = strictFullName(name)
	if not self:IsEnabled() or not name then
		return nil
	end
	local api = self:GetAPI()
	if not api then
		return {
			name = name,
			status = "fault",
			primaryType = GF.NETEASE_IDENTITY_FAULT,
			fresh = false,
			reason = "missing-api",
		}
	end
	local identity
	if type(api.GetPlayerIdentity) == "function" then
		local ok
		ok, identity = pcall(api.GetPlayerIdentity, api, name)
		if not ok then
			return {
				name = name,
				status = "fault",
				primaryType = GF.NETEASE_IDENTITY_FAULT,
				fresh = false,
				reason = "api-error",
			}
		end
	end
	if identityIsFresh(api, identity) then
		return buildResolvedProjection(name, identity)
	end
	local needsActivityRefresh = type(identity) == "table"
		and type(identity.updatedAt) == "number"
		and identity.updatedAt < GF.NetEaseActivity.START_AT
		and type(api.IsCacheFresh) == "function"
	if needsActivityRefresh then
		local freshOK, fresh = pcall(api.IsCacheFresh, api, identity)
		needsActivityRefresh = freshOK and fresh == true
	end
	local queryStatus, reason
	if type(api.GetPlayerIdentityStatus) == "function" then
		local statusOK
		statusOK, queryStatus, reason = pcall(
			api.GetPlayerIdentityStatus, api, name)
		if not statusOK then
			queryStatus = "failed"
			reason = "api-error"
		end
	end
	if needsActivityRefresh then
		queryStatus = "stale"
		reason = "activity-stale"
	end
	if options and options.queue == true
		and type(api.QueryPlayerIdentity) == "function"
	then
		local queueOK, _, queuedStatus, queueReason = pcall(
			api.QueryPlayerIdentity, api, name, needsActivityRefresh)
		if queueOK then
			queryStatus = queuedStatus or queryStatus
			reason = queueReason or reason
		else
			queryStatus = "failed"
			reason = "api-error"
		end
	end
	local status, serviceStatus, finalReason =
		serviceProjectionStatus(api, name, queryStatus, reason)
	return {
		name = name,
		status = status,
		primaryType = status == "offline" and GF.NETEASE_IDENTITY_OFFLINE
			or status == "fault" and GF.NETEASE_IDENTITY_FAULT
			or GF.NETEASE_IDENTITY_LOADING,
		fresh = false,
		queryStatus = queryStatus,
		serviceStatus = serviceStatus,
		reason = finalReason,
	}
end

function Service:GetGroupProjection(resultID, info, entry, options)
	if not self:IsEnabled() then
		return nil
	end
	local snapshot = GF.SearchResultSnapshot
	if not snapshot or type(snapshot.GetPlayers) ~= "function" then
		return nil
	end
	local players, complete = snapshot.GetPlayers(resultID, info, entry)
	if type(players) ~= "table" then
		return {
			complete = false,
			members = {},
			status = "loading",
			primaryType = GF.NETEASE_IDENTITY_LOADING,
		}
	end
	local members = {}
	local namesToQueue = {}
	local namesToForce = {}
	local allFreshVeterans = complete == true and #players > 0
	local hasNewbie, hasLocomotive, hasStar = false, false, false
	local hasLoading, hasOffline, hasFault = false, false, false
	for index = 1, #players do
		local name = readMemberName(players[index])
		local projection = name and self:GetIdentityProjection(name) or nil
		if name and projection and projection.fresh ~= true
			and options and options.queue == true
		then
			local target = projection.reason == "activity-stale"
				and namesToForce or namesToQueue
			target[#target + 1] = name
		end
		projection = projection or {
			name = name,
			status = name and "loading" or "unavailable",
			primaryType = name and GF.NETEASE_IDENTITY_LOADING or nil,
			fresh = false,
			reason = name and nil or "incomplete-name",
		}
		members[#members + 1] = projection
		hasNewbie = hasNewbie or projection.isNewbie == true
		hasLocomotive = hasLocomotive or projection.locomotiveLevel ~= nil
		hasStar = hasStar or projection.starLevel ~= nil
		hasLoading = hasLoading or projection.status == "loading"
		hasOffline = hasOffline or projection.status == "offline"
		hasFault = hasFault or projection.status == "fault"
		allFreshVeterans = allFreshVeterans
			and projection.fresh == true and projection.isVeteran == true
	end
	if #namesToQueue > 0 then
		local api = self:GetAPI()
		if api and type(api.QueryPlayerIdentities) == "function" then
			pcall(api.QueryPlayerIdentities, api, namesToQueue)
		end
	end
	if #namesToForce > 0 then
		local api = self:GetAPI()
		if api and type(api.QueryPlayerIdentities) == "function" then
			pcall(api.QueryPlayerIdentities, api, namesToForce, true)
		end
	end
	local primaryType
	if hasNewbie then
		primaryType = GF.NETEASE_IDENTITY_NEWBIE
	elseif hasLocomotive then
		primaryType = GF.NETEASE_IDENTITY_LOCOMOTIVE
	elseif hasStar then
		primaryType = GF.NETEASE_IDENTITY_STAR
	elseif allFreshVeterans then
		primaryType = GF.NETEASE_IDENTITY_VETERAN
	elseif hasOffline then
		primaryType = GF.NETEASE_IDENTITY_OFFLINE
	elseif hasFault then
		primaryType = GF.NETEASE_IDENTITY_FAULT
	elseif hasLoading then
		primaryType = GF.NETEASE_IDENTITY_LOADING
	end
	return {
		allVeteran = allFreshVeterans,
		complete = complete == true,
		hasNewbie = hasNewbie,
		hasLocomotive = hasLocomotive,
		hasStar = hasStar,
		members = members,
		primaryType = primaryType,
		status = hasNewbie and "fresh"
			or hasOffline and "offline"
			or hasFault and "fault"
			or hasLoading and "loading"
			or "fresh",
	}
end

function Service:AddListener(callback)
	if type(callback) ~= "function" then
		return false
	end
	self.listeners = self.listeners or {}
	self.listeners[#self.listeners + 1] = callback
	return true
end

function Service:ScheduleRefresh(reason)
	self.pendingRefreshReason = reason or self.pendingRefreshReason or "identity"
	if self.refreshPending then
		return
	end
	self.refreshPending = true
	local function refresh()
		Service.refreshPending = false
		local detail = Service.pendingRefreshReason
		Service.pendingRefreshReason = nil
		if Service:IsEnabled() then
			if GF.FindGroupTab and GF.FindGroupTab.RequestRefreshResults then
				GF.FindGroupTab:RequestRefreshResults({
					preserveScroll = true,
					reason = "netease-identity",
				})
			end
			if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
				GF.ApplicantsPanel:Refresh({ preserveScroll = true })
			end
		end
		for _, callback in ipairs(Service.listeners or {}) do
			pcall(callback, detail)
		end
	end
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		C_Timer.NewTimer(REFRESH_DELAY, refresh)
	else
		refresh()
	end
end

function Service:OnIdentityEvent(eventName)
	if self:IsEnabled() then
		self:ScheduleRefresh(eventName)
	end
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self:ResetForActivityIfNeeded()
	self:EnforceClientLocale()
	local api = self:GetAPI()
	if not api then
		return
	end
	if type(api.SetClientInfo) == "function" then
		pcall(api.SetClientInfo, api, {
			addonName = GF.addonName or "GroupFinder",
			version = GF.NetEaseActivity.PROTOCOL_VERSION,
			loginQueryData = {},
		})
	end
	for _, eventName in ipairs({
		"PlayerIdentityQueued",
		"PlayerIdentityUpdated",
		"PlayerIdentityBatchUpdated",
		"PlayerIdentityFailed",
		"ServerStatusChanged",
	}) do
		if type(api.RegisterCallback) == "function" then
			pcall(api.RegisterCallback, api, self, eventName, "OnIdentityEvent")
		end
	end
	if self:IsEnabled() and type(api.Start) == "function" then
		pcall(api.Start, api)
	end
end

function Service:OnPlayerLogin()
	self:ResetForActivityIfNeeded()
	self:EnforceClientLocale()
	if self:IsEnabled() then
		local api = self:GetAPI()
		if api and type(api.Start) == "function" then
			pcall(api.Start, api)
		end
	else
		local api = self:GetAPI()
		if api and type(api.CancelQueries) == "function" then
			pcall(api.CancelQueries, api)
		end
		local filter = GF.MythicPlusBrowseFilter
		if filter and type(filter.SetNewbieOnly) == "function"
			and filter:IsNewbieOnly() == true
		then
			filter:SetNewbieOnly(false)
		end
	end
end
