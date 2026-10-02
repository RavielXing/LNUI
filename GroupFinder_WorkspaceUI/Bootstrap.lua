local addonName, Addon = ...
local GF = _G.GroupFinder
local module = GF and GF.WorkspaceUIModule
assert(module and module.apiVersion == 1 and module.addonName == addonName,
    "GroupFinder workspace facade is missing or incompatible")
Addon.GF = GF
Addon.workspaceUIAPIVersion = 1
-- No SavedVariables: the host retains the existing account database ownership.
