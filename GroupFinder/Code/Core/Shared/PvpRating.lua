local _, GF = ...

-- PvP 评分颜色分级。

GF.PVP_RATING_COLORS = {
	GRAY = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5, a = 1 },
	WHITE = HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1, a = 1 },
	GREEN = UNCOMMON_GREEN_COLOR or { r = 0.12, g = 1, b = 0, a = 1 },
	PURPLE = EPIC_PURPLE_COLOR or { r = 0.64, g = 0.21, b = 0.93, a = 1 },
	ORANGE = LEGENDARY_ORANGE_COLOR or { r = 1, g = 0.5, b = 0, a = 1 },
}
GF.PVP_RATING_GRAY_MAX = 500
GF.PVP_RATING_WHITE_MAX = 1949
GF.PVP_RATING_GREEN_MAX = 2099
GF.PVP_RATING_PURPLE_MAX = 2299

function GF.GetPvpRatingColor(rating)
	local value = tonumber(rating)
	if not value or value < 0 then
		return nil
	end
	if value <= GF.PVP_RATING_GRAY_MAX then
		return GF.PVP_RATING_COLORS.GRAY
	end
	if value <= GF.PVP_RATING_WHITE_MAX then
		return GF.PVP_RATING_COLORS.WHITE
	end
	if value <= GF.PVP_RATING_GREEN_MAX then
		return GF.PVP_RATING_COLORS.GREEN
	end
	if value <= GF.PVP_RATING_PURPLE_MAX then
		return GF.PVP_RATING_COLORS.PURPLE
	end
	return GF.PVP_RATING_COLORS.ORANGE
end
