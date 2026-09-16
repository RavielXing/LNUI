local CallbackHandler = LibStub("CallbackHandler-1.0")

local MAJOR, MINOR = "NumyAceEvent-3.0", 2

local AceEvent = LibStub:NewLibrary(MAJOR, MINOR)

if not AceEvent then return end

local pairs = pairs

AceEvent.frame = AceEvent.frame or CreateFrame("Frame") -- our event frame
AceEvent.embeds = AceEvent.embeds or {} -- what objects embed this lib

if not AceEvent.events then
    AceEvent.events = CallbackHandler:New(AceEvent,
        "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents")
end

function AceEvent.events:OnUsed(target, eventname)
    AceEvent.frame:RegisterEvent(eventname)
end

function AceEvent.events:OnUnused(target, eventname)
    AceEvent.frame:UnregisterEvent(eventname)
end

if not AceEvent.messages then
    AceEvent.messages = CallbackHandler:New(AceEvent,
        "RegisterMessage", "UnregisterMessage", "UnregisterAllMessages"
    )
    AceEvent.SendMessage = AceEvent.messages.Fire
end

local mixins = {
    "RegisterEvent", "UnregisterEvent",
    "RegisterMessage", "UnregisterMessage",
    "SendMessage",
    "UnregisterAllEvents", "UnregisterAllMessages",
}

function AceEvent:Embed(target)
    local instance = self.embeds[target] or {}
    if type(instance) ~= "table" then instance = {} end
    instance.frame = instance.frame or CreateFrame("Frame") -- our event frame

    if not instance.events then
        instance.events = CallbackHandler:New(instance,
            "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents")
    end

    function instance.events:OnUsed(_, eventname)
        instance.frame:RegisterEvent(eventname)
    end

    function instance.events:OnUnused(_, eventname)
        instance.frame:UnregisterEvent(eventname)
    end

    local events = instance.events
    instance.frame:SetScript("OnEvent", function(this, event, ...)
        events:Fire(event, ...)
    end)

    for k, v in pairs(mixins) do
        target[v] = instance[v] or self[v]
    end
    self.embeds[target] = instance
    return target
end

function AceEvent:OnEmbedDisable(target)
    target:UnregisterAllEvents()
    target:UnregisterAllMessages()
end

local events = AceEvent.events
AceEvent.frame:SetScript("OnEvent", function(this, event, ...)
    events:Fire(event, ...)
end)

for target, v in pairs(AceEvent.embeds) do
    AceEvent:Embed(target)
end
