local _, GF = ...

-- 列表尺寸统一在这里投影；业务页只取结果，不复制缩放公式。
local DEFAULTS = {
	row = 32,
	applicantRow = 33,
	icon = 18,
	roleBadge = 12,
	largeRoleBadge = 14,
}

local function positiveNumber(value, fallback)
	value = tonumber(value)
	if value and value > 0 then
		return value
	end
	return fallback
end

local function nearestPixel(value)
	return math.max(1, math.floor(value + 0.5))
end

local function currentFontScale()
	if type(GF.GetFontScale) ~= "function" then
		return 1
	end
	return positiveNumber(GF.GetFontScale(), 1)
end

function GF.GetListRowH()
	return positiveNumber(GF.LIST_ROW_H_DEFAULT, positiveNumber(GF.LIST_ROW_H, DEFAULTS.row))
end

function GF.GetApplicantRowH()
	return positiveNumber(GF.APPLICANT_ROW_H, DEFAULTS.applicantRow)
end

function GF.GetScaledListIconSize(size)
	local base = positiveNumber(size, positiveNumber(GF.ROLE_ICON_SIZE, DEFAULTS.icon))
	return nearestPixel(base * currentFontScale())
end

function GF.GetNonRoleListIconSize()
	return GF.GetScaledListIconSize(positiveNumber(GF.NON_ROLE_ICON_SIZE, DEFAULTS.icon))
end

function GF.GetBrowseMemberIconSize()
	local base = positiveNumber(GF.BROWSE_ROW_MEMBER_ICON_SIZE, positiveNumber(GF.ROLE_ICON_SIZE, DEFAULTS.icon))
	return GF.GetScaledListIconSize(base)
end

function GF.GetBrowseMemberRoleBadgeSize()
	local normal = positiveNumber(GF.BROWSE_ROW_MEMBER_ROLE_BADGE_SIZE, DEFAULTS.roleBadge)
	local large = positiveNumber(GF.BROWSE_ROW_MEMBER_ROLE_BADGE_LARGE_SIZE, DEFAULTS.largeRoleBadge)
	local selectedMode = type(GF.GetMemberDisplayMode) == "function" and GF.GetMemberDisplayMode() or nil
	local largeMode = GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large"
	return GF.GetScaledListIconSize(selectedMode == largeMode and large or normal)
end

function GF.GetRoleCountIconSize()
	local base = positiveNumber(GF.ROLE_COUNT_ICON_DEFAULT, positiveNumber(GF.ROLE_ICON_SIZE, DEFAULTS.icon))
	return GF.GetScaledListIconSize(base)
end

function GF.GetListRowTextY(rowHeight, referenceY, referenceHeight)
	local baseline = tonumber(referenceY) or -6
	local baseHeight = positiveNumber(referenceHeight, GF.GetListRowH())
	local actualHeight = positiveNumber(rowHeight, GF.GetListRowH())
	return baseline + ((baseHeight - actualHeight) * 0.5)
end
