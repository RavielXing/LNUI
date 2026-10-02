local _, Addon = ...
local GF = Addon.GF
local module = GF and GF.WorkspaceUIModule
assert(module and Addon.workspaceUIAPIVersion == 1,
    "GroupFinder workspace namespace is missing or incompatible")
local ready, reason = module:FinalizeDefinitions(Addon.workspaceUIAPIVersion)
assert(ready == true, reason or "GroupFinder workspace definitions incomplete")
-- Definition loading does not create a window or replay business events.
