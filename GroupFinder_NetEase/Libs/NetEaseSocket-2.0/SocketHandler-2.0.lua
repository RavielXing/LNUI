
local CallbackHandler = LibStub('CallbackHandler-1.0')
local SocketMiddleware = LibStub('NetEaseSocketMiddleware-2.0')
local BroadMiddleware = LibStub('NetEaseBroadMiddleware-2.0')
local AceTimer = LibStub('AceTimer-3.0')
local AceEvent = LibStub('AceEvent-3.0')

local MAJOR, MINOR = 'SocketHandler-2.0', 25
local SocketHandler,oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not SocketHandler then return end

local random = fastrandom or random

local SOCKET_NORMAL  = 1
local SOCKET_CONNECT = 2
local SOCKET_READY   = 3

local CONNECT_DELAY = 3
local RETRY_DELAY = 3

local NOT_FOUND_MATCH = ERR_CHAT_PLAYER_NOT_FOUND_S:format('(.+)')

local SOCKET_BASE_CMD = {
    NETEASE_CONNECT_SUCCESS = true,
    NETEASE_CHANNEL_OWNER = true,
}

SocketHandler.EventHandler = SocketHandler.EventHandler or {}

SocketHandler.objects = SocketHandler.objects or {}
SocketHandler.channels = SocketHandler.channels or {}
SocketHandler.connectQueue = SocketHandler.connectQueue or {}
SocketHandler.connectStatus = SocketHandler.connectStatus or {}

SocketHandler.status = SOCKET_NORMAL
SocketHandler.isLoggedIn = false
SocketHandler._meta = {__index = SocketHandler}

local objects = SocketHandler.objects
local channels = SocketHandler.channels
local connectQueue = SocketHandler.connectQueue
local EventHandler = SocketHandler.EventHandler

local function inChatMessagingLockdown()
    local api = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    if type(api) ~= 'function' then
        return false
    end
    local ok, locked = pcall(api)
    return not ok or locked == true
end

local function readableString(value)
    if type(issecretvalue) == 'function' then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret == true then
            return false
        end
    end
    if type(canaccessvalue) == 'function' then
        local ok, accessible = pcall(canaccessvalue, value)
        if not ok or accessible == false then
            return false
        end
    end
    if type(value) ~= 'string' then
        return false
    end
    local ok, nonEmpty = pcall(function()
        return value ~= ''
    end)
    return ok and nonEmpty == true
end

local function safeAmbiguate(value)
    if not readableString(value) then
        return nil
    end
    local ok, result = pcall(Ambiguate, value, 'none')
    return ok and readableString(result) and result or nil
end

local function shortName(value)
    if not readableString(value) then
        return nil
    end
    local ok, result = pcall(string.match, value, '^([^-]+)')
    return ok and result or nil
end

local function samePlayerName(left, right)
    if not readableString(left) or not readableString(right) then
        return false
    end
    if left == right then
        return true
    end
    local leftShort, rightShort = shortName(left), shortName(right)
    return leftShort ~= nil and leftShort == rightShort
end

local function OnUsed(registry, target, cmd)
    target:RegisterCallback(cmd, 'OnSocket')
end

local _server
local function getServer()
    if not _server then
        if type(GetAutoCompleteRealms) == 'function' then
            local ok, realms = pcall(GetAutoCompleteRealms)
            if ok and type(realms) == 'table'
                and readableString(realms[1])
            then
                _server = realms[1]
            end
        end
        if not _server and type(GetRealmName) == 'function' then
            local ok, realm = pcall(GetRealmName)
            if ok and readableString(realm) then
                local normalizedOK, normalized = pcall(
                    string.gsub, realm, '%s+', '')
                if normalizedOK and readableString(normalized) then
                    _server = normalized
                end
            end
        end
        if not _server and type(GetNormalizedRealmName) == 'function' then
            local ok, realm = pcall(GetNormalizedRealmName)
            if ok and readableString(realm) then
                _server = realm
            end
        end
    end
    return _server
end

local function formatTarget(target)
    local server = getServer()
    if readableString(target) and readableString(server) then
        return safeAmbiguate(target .. '-' .. server)
    end
end

local function getChannelId(channelName)
    local id = GetChannelName(channelName)
    if id and id > 0 then
        return id
    end
end

function SocketHandler:New()
    local obj = setmetatable({}, self._meta)

    local socketRegistry = CallbackHandler:New(obj, 'RegisterSocket', 'UnregisterSocket', 'UnregisterAllSocket')
    local serverRegistry = CallbackHandler:New(obj, 'RegisterServer', 'UnregisterServer', 'UnregisterAllServer')

    local function OnUnused(registry, target, cmd)
        if SOCKET_BASE_CMD[cmd] then
            return
        end
        if next(socketRegistry.events[cmd]) or next(socketRegistry.events[cmd]) then
            return
        end
        target:UnregisterCallback(cmd)
    end

    socketRegistry.OnUsed = OnUsed
    socketRegistry.OnUnused = OnUnused
    serverRegistry.OnUsed = OnUsed
    serverRegistry.OnUnused = OnUnused

    obj.FireSocket = socketRegistry.Fire
    obj.FireServer = serverRegistry.Fire

    SocketMiddleware:Embed(obj)
    AceTimer:Embed(obj)

    tinsert(objects, obj)

    return obj
end

function SocketHandler:PreServer(cmd, distribution, sender, ...)
    if cmd == 'NETEASE_CONNECT_SUCCESS' then
        local key, channelName = ...
        local statusTable = self.statusTable
        local connectKey = statusTable and statusTable.connectKey
        local keyOK, keyMatches = pcall(function()
            return connectKey ~= nil and connectKey == key
        end)
        if keyOK and keyMatches then
            self:CancelTimer(statusTable.retryConnectTimer)
            self.target = safeAmbiguate(sender) or self.connectTarget
            statusTable.status = SOCKET_READY
            statusTable.retryConnectTimer = nil
			self.disconnectPending = false
			self.disconnectReason = nil

            self:SetChannel(channelName)

            self:FireServer('SERVER_CONNECTED')
        end
        return true
    end
    if cmd == 'NETEASE_CHANNEL_OWNER' then
        if self:IsServer(sender) or not self:IsReady() then
            SetChannelOwner(..., sender)
        end
        return true
    end
end

function SocketHandler:OnSocket(cmd, distribution, sender, ...)
    if self:PreServer(cmd, distribution, sender, ...) then
        return
    elseif self:IsReady()
        and (self:IsServer(sender) or not readableString(sender))
    then
        self:FireServer(cmd, ...)
    elseif not SOCKET_BASE_CMD[cmd] then
        self:FireSocket(cmd, sender, ...)
    end
end

function SocketHandler:ListenSocket(prefix, target)
    self.prefix = prefix
    self.connectTarget = formatTarget(target)
    self:UpdateStatusTable()
    self:Listen(prefix, 4)
end

function SocketHandler:CheckSendDistribution(target)
    if target == '@GROUP' then
        if IsInRaid(LE_PARTY_CATEGORY_HOME) then
            return 'RAID'
        elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
            return 'PARTY'
        end
    elseif target == '@CHANNEL' then
        if self.channelId then
            return 'CHANNEL', self.channelId
        end
    elseif target == '@GUILD' then
        return 'GUILD'
    elseif target == '@BATTLEGROUND' then
        return 'BATTLEGROUND'
    else
        return 'WHISPER', target
    end
end

function SocketHandler:SendSocket(target, cmd, ...)
    local distribution, target = self:CheckSendDistribution(target)
    if distribution then
        self:Send(distribution, target, cmd, ...)
    end
end

function SocketHandler:ConnectServer(target)
    if not self.prefix then
        error('Can`t found prefix in object', 4)
    end
    self.connectTarget = formatTarget(target) or self.connectTarget
    if not self.connectTarget then
        error('Can`t found connectTarget in object', 4)
    end

    self:UpdateStatusTable()
    self.statusTable.status = SOCKET_CONNECT
	self.disconnectPending = false
	self.disconnectReason = nil

    self:RegisterCallback('NETEASE_CONNECT_SUCCESS', 'OnSocket')
    self:RegisterCallback('NETEASE_CHANNEL_OWNER', 'OnSocket')

    self:TryConnect()
end

function SocketHandler:FireDisconnected(reason)
	self.disconnectPending = false
	self:FireServer('SERVER_DISCONNECTED', reason)
end

function SocketHandler:DisconnectServer(reason)
    if self.disconnectPending then
        return
    end
    self.target = nil
    local statusTable = self.statusTable
    if statusTable then
        self:CancelTimer(statusTable.retryConnectTimer)
        statusTable.retryConnectTimer = nil
        statusTable.status = SOCKET_NORMAL
    end
    self.disconnectPending = true
	self.disconnectReason = reason
    self:ScheduleTimer('FireDisconnected', 1, reason)
end

function SocketHandler:ConnectChannel()
    if self.channelName then
        local id = getChannelId(self.channelName)
        if id then
            self.channelId = id
            self:FireServer('CHANNEL_CONNECTED')
        else
            self.channelId = nil
            JoinTemporaryChannel(self.channelName)
        end
    end
end

function SocketHandler:SendServer(cmd, ...)
    if self.target then
        self:Send('WHISPER', self.target, cmd, ...)
    end
end

function SocketHandler:TryConnect()
    local statusTable = self.statusTable
    if not statusTable then
        return
    end
    if self:TimeLeft(statusTable.retryConnectTimer) > 0 then
        return
    end
    if self.isLoggedIn then
        self:Send('WHISPER', self.connectTarget, 'NETEASE_CONNECT', self:GetConnectKey())
        statusTable.retryConnectTimer = self:ScheduleTimer('TryConnect', RETRY_DELAY)
    else
        if not tContains(connectQueue, self) then
            tinsert(connectQueue, self)
        end
    end
end

function SocketHandler:UpdateStatusTable()
    if self.prefix and self.connectTarget then
        local key = self.prefix .. '.' .. self.connectTarget
        self.connectStatus[key] = self.connectStatus[key] or {}
        self.statusTable = self.connectStatus[key]
    else
        self.statusTable = nil
    end
end

function SocketHandler:GetConnectKey()
    local statusTable = self.statusTable
    if not statusTable.connectKey then
        statusTable.connectKey = tostring(random(0x100000, 0xFFFFFF))
    end
    return statusTable.connectKey
end

function SocketHandler:SetChannel(channelName)
    if self.channelName and self.channelName ~= channelName then
        if channels[self.channelName] then
            channels[self.channelName][self] = nil

            if next(channels[self.channelName]) then
                LeaveChannelByName(self.channelName)
            end
        end
    end

    self.channelName = channelName

    if self.channelName then
        channels[self.channelName] = channels[self.channelName] or {}
        channels[self.channelName][self] = true

        BroadMiddleware.Listen(self, self.channelName)

        self:ConnectChannel()
    end
end

function SocketHandler:IsReady()
    local statusTable = self.statusTable
    return statusTable and statusTable.status == SOCKET_READY
end

function SocketHandler:IsServer(sender)
    local normalized = safeAmbiguate(sender)
    return samePlayerName(self.target, normalized)
        or samePlayerName(self.connectTarget, normalized)
end

function SocketHandler:YOU_JOINED()
    self.channelId = getChannelId(self.channelName)
    self:ScheduleTimer('FireServer', 1, 'CHANNEL_CONNECTED', true)
end

function SocketHandler:YOU_LEFT()
    self.channelId = nil
    self:ScheduleTimer('FireServer', 1, 'CHANNEL_DISCONNECTED')
end

function SocketHandler:WRONG_PASSWORD()
    self.channelId = nil

    if self.channelName then
        self:SendServer('SCJF', self.channelName)
        self:ScheduleTimer('ConnectChannel', 10)
    end
end

SocketHandler.YOU_CHANGED = SocketHandler.YOU_JOINED
SocketHandler.BANNED = SocketHandler.WRONG_PASSWORD

---- EventHandler

AceEvent:Embed(EventHandler)
AceTimer:Embed(EventHandler)

function EventHandler:CHAT_MSG_CHANNEL_NOTICE(_, event, _, _, _, _, _, _, id, channelName)
    if inChatMessagingLockdown()
        or not readableString(event) or not readableString(channelName)
    then
        return
    end
    local callback = SocketHandler[event]
    if callback and channels[channelName] then
        for handler in pairs(channels[channelName]) do
            callback(handler)
        end
    end

    -- Retail's ChannelFrame handles CHANNEL_UI_UPDATE and OnShow itself.
    -- Socket notices must not depend on native UI or the removed legacy updater.
end

function EventHandler:PLAYER_LOGOUT()
    self:UnregisterAllEvents()
    self:CancelAllTimers()

    SocketHandler.isLoggedIn = false
    for _, handler in ipairs(objects) do
        handler:CancelAllTimers()
        handler.channelId = nil
        handler.disconnectPending = false
        handler.disconnectReason = nil
    end
    wipe(channels)
    wipe(connectQueue)
end

function EventHandler:PLAYER_LOGIN()
    SocketHandler.isLoggedIn = true

    self:RegisterEvent('PLAYER_LOGOUT')
    self:RegisterEvent('CHAT_MSG_SYSTEM')
    self:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE')

    for _, handler in ipairs(connectQueue) do
        handler:TryConnect()
    end
end

function EventHandler:CHAT_MSG_SYSTEM(_, msg)
    if inChatMessagingLockdown() or not readableString(msg) then
        return
    end

    -- Check if message processing is safe
    if InCombatLockdown() then
        return
    end

    local ok, name = pcall(string.match, msg, NOT_FOUND_MATCH)
    if not ok then
        return
    end
    if not name then
        return
    end

    name = safeAmbiguate(name)
    if not name then
        return
    end

    for _, handler in pairs(objects) do
        if handler:IsServer(name) then
            handler:DisconnectServer('service-target-not-found')
        end
    end
end

EventHandler:CancelAllTimers()
EventHandler:UnregisterAllEvents()

if IsLoggedIn() then
    EventHandler:ScheduleTimer('PLAYER_LOGIN', CONNECT_DELAY)
else
    EventHandler:RegisterEvent('PLAYER_LOGIN', function()
        EventHandler:UnregisterEvent('PLAYER_LOGIN')
        EventHandler:ScheduleTimer('PLAYER_LOGIN', CONNECT_DELAY)
    end)
end

---- ChatFilter

if not SocketHandler.chatFilter then
    ChatFrame_AddMessageEventFilter('CHAT_MSG_SYSTEM', function(_, _, msg)
        if inChatMessagingLockdown() or not readableString(msg) then
            return
        end
        local ok, name = pcall(string.match, msg, NOT_FOUND_MATCH)
        if not ok or not name then
            return
        end

        name = safeAmbiguate(name)
        if not name then
            return
        end

        for _, handler in pairs(objects) do
            if handler:IsServer(name) then
                return true
            end
        end
    end)
    SocketHandler.chatFilter = true
end

-- Keep native channel discovery and configuration entirely Blizzard-owned.
-- ChannelList:Update reads GetChannelDisplayInfo before calling the shared
-- CommunitiesList:PredictFavorites. Replacing that global to hide transport
-- channels can taint state later read by the protected C_Club.SetAvatarTexture.
-- Transport channels remain visible; connection and packet routing use our
-- own registry above. Do not try to restore globals/hooks from older copies:
-- writing them again cannot clean an already-tainted session. Reload instead.
