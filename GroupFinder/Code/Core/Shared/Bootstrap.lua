local addonName, GF = ...

GF.addonName = addonName
GF.searching = false

-- Bootstrap is deliberately the final assembly point. RuntimeLifecycle owns
-- startup order, event semantics, and public facades; this file owns the one
-- authoritative LFG dispatcher and forwards its events without interpretation.
local lifecycle = assert(GF.RuntimeLifecycle,
	"GroupFinder RuntimeLifecycle must load before Bootstrap")
local dispatcher = CreateFrame("Frame")
GF.LFGEventDispatcher = dispatcher

lifecycle:AttachDispatcher(dispatcher)
dispatcher:SetScript("OnEvent", function(_, eventName, ...)
	lifecycle:HandleEvent(eventName, ...)
end)

lifecycle:InstallGlobalFacade()
