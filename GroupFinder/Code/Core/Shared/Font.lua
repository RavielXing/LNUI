local _, GF = ...

-- Compatibility facade. New code may depend on TypographyService directly;
-- existing UI modules keep their stable GF.Font entry points.
local Font = GF.Font or {}
GF.Font = Font

local PUBLIC_METHODS = {
	"GetFontOptions",
	"GetOutlineOptions",
	"ResolveFontObjectKey",
	"GetFontObjectKey",
	"ApplyToMenuFontString",
	"ApplyToDropdownButton",
	"ApplyToEditBox",
	"TrackEditBox",
	"ApplyToFontString",
	"SetFitWidth",
	"Track",
	"TrackButton",
	"BeginTooltipFont",
	"ApplyTooltipFont",
	"WrapMenuRoot",
	"TrackDropdownButton",
	"RefreshAll",
}

local function serviceFacade(methodName)
	return function(...)
		local service = GF.TypographyService
		local callback = service and service[methodName]
		if type(callback) == "function" then
			return callback(...)
		end
		return nil
	end
end

for _, methodName in ipairs(PUBLIC_METHODS) do
	Font[methodName] = serviceFacade(methodName)
end

Font.Service = GF.TypographyService
