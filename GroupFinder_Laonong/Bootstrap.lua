local _, Addon = ...
local GF = _G.GroupFinder
if not (GF and GF.LaonongModule and GF.LaonongModule.apiVersion == 1) then return end
Addon.GF = GF
