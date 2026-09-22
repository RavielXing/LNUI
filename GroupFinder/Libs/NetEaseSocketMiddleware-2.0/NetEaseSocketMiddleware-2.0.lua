
local AceComm = LibStub('AceComm-3.0')
local AceSerializer = LibStub('AceSerializer-3.0')
local CallbackHandler = LibStub('CallbackHandler-1.0')

local MAJOR, MINOR = 'NetEaseSocketMiddleware-2.0', 3
local SocketMiddleware,oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not SocketMiddleware then return end

SocketMiddleware.CommHandler = SocketMiddleware.CommHandler or {}
SocketMiddleware.prefixes = SocketMiddleware.prefixes or {}
SocketMiddleware.handlers = SocketMiddleware.handlers or setmetatable({}, {
    __index = function(o, k)
        o[k] = {}
        o[k].Fire = CallbackHandler:New(o[k]).Fire
        return o[k]
    end
})

local handlers = SocketMiddleware.handlers
local prefixes = SocketMiddleware.prefixes

local CommHandler = SocketMiddleware.CommHandler
AceComm:Embed(CommHandler)

local unpackValues = unpack or table.unpack

local function packValues(...)
    return { n = select('#', ...), ... }
end

function CommHandler:OnCommRecv(prefix, data, distribution, sender)
    -- Malformed or protected inbound payloads must not escape through the
    -- shared CHAT_MSG_ADDON callback and break every socket consumer.
    local result = packValues(pcall(
        AceSerializer.Deserialize, AceSerializer, data))
    if not result[1] then
        return
    end
    self:DealPacket(prefix, distribution, sender,
        unpackValues(result, 2, result.n))
end

function CommHandler:DealPacket(prefix, distribution, sender, ok, cmd, ...)
    if not ok then
        return
    end
    handlers[prefix]:Fire(cmd, distribution, sender, ...)
end

function SocketMiddleware:Listen(prefix, errorlvl)
    if prefixes[self] then
        error('Can`t listen more prefix', errorlvl or 2)
    end

    local handler = handlers[prefix]

    self.RegisterCallback = handler.RegisterCallback
    self.UnregisterCallback = handler.UnregisterCallback
    self.UnregisterAllCallbacks = handler.UnregisterAllCallbacks

    prefixes[self] = prefix

    CommHandler:RegisterComm(prefix, 'OnCommRecv')
end

function SocketMiddleware:Send(distribution, target, ...)
    CommHandler:SendCommMessage(prefixes[self], AceSerializer:Serialize(...), distribution, target)
end

local mixins = {
    'Send',
    'Listen',
}

function SocketMiddleware:Embed(target)
    for i, v in ipairs(mixins) do
        target[v] = self[v]
    end
end
