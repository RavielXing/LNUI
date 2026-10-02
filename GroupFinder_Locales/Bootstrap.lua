local _, Addon = ...
Addon.GF = assert(_G.GroupFinder, "GroupFinder must load before language resources")
assert(Addon.GF.Locale and Addon.GF.Locale.resourceAPIVersion == 1,
	"GroupFinder language API version is incompatible")
Addon.apiVersion = 1
