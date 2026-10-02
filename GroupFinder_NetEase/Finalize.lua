local _, Addon = ...
local GF = Addon.GF
if GF and GF.NetEaseIdentityProvider and GF.NetEaseSettingsPage
	and GF.NetEaseModule.serviceReady == true
then
	GF.NetEaseModule.ready = true
end
