local _, Addon = ...
local GF = Addon.GF
local Locale = GF.Locale
local key = Locale and Locale._resourceLocaleKey
local resources = key and GF["locale_" .. key]
if Locale and Addon.apiVersion == 1 and type(resources) == "table"
	and type(resources.ADDON_NAME) == "string" and resources.ADDON_NAME ~= "" then
	Locale._resourceLoadedKey = key
end
