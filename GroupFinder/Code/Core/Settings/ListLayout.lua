local _, GF = ...

function GF.GetListRowH()
	return GF.LIST_ROW_H_DEFAULT or GF.LIST_ROW_H or 32
end

function GF.GetApplicantRowH()
	return GF.APPLICANT_ROW_H or 33
end

function GF.GetScaledListIconSize(baseSize)
	local scale = (GF.GetFontScale and GF.GetFontScale()) or 1
	baseSize = tonumber(baseSize) or GF.ROLE_ICON_SIZE or 18
	return math.max(1, math.floor((baseSize * scale) + 0.5))
end

function GF.GetNonRoleListIconSize()
	return GF.GetScaledListIconSize(GF.NON_ROLE_ICON_SIZE or 18)
end

function GF.GetBrowseMemberIconSize()
	return GF.GetScaledListIconSize(GF.BROWSE_ROW_MEMBER_ICON_SIZE or GF.ROLE_ICON_SIZE or 18)
end

function GF.GetBrowseMemberRoleBadgeSize()
	return GF.GetScaledListIconSize(GF.BROWSE_ROW_MEMBER_ROLE_BADGE_SIZE or 12)
end

function GF.GetRoleCountIconSize()
	return GF.GetScaledListIconSize(GF.ROLE_COUNT_ICON_DEFAULT or GF.ROLE_ICON_SIZE or 18)
end

function GF.GetListRowTextY(rowH, baseY, baseH)
	baseH = baseH or GF.LIST_ROW_H_DEFAULT or GF.LIST_ROW_H or 32
	baseY = baseY or -6
	rowH = rowH or GF.GetListRowH()
	return baseY - (rowH - baseH) / 2
end

function GF.GetListRowTextYFromRow(row, baseY)
	local rowH = (row and row.GetHeight and row:GetHeight()) or 0
	if rowH <= 0 then
		rowH = GF.GetListRowH()
	end
	return GF.GetListRowTextY(rowH, baseY)
end
