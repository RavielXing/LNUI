local _, Addon = ...
local GF = _G.GroupFinder
if not (GF and GF.NetEaseModule and GF.NetEaseModule.apiVersion == 1) then
	return
end
Addon.GF = GF
