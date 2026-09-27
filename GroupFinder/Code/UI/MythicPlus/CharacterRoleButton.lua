local _, GF = ...

local RoleButton = {}
GF.MythicPlusCharacterRoleButton = RoleButton

local function refresh(button)
	local selected = button._available ~= false and button._cachedChecked == true
	local atlas = GetIconForRole and GetIconForRole(button.NativeRole, not selected)
	GF.UI.TrySetAtlas(button.RoleIcon, atlas or GF.ROLE_ICON_ATLAS[button.NativeRole], false)
	button.RoleIcon:SetDesaturated(not selected)
	button.RoleIcon:SetVertexColor(1, 1, 1, 1)
	button:SetAlpha(button._available ~= false and 1
		or GF.MYTHIC_PLUS_CHARACTER_CHECK_STYLE.unavailableRoleAlpha)
end

function RoleButton:Create(parent, roleKey, title, description)
	local button = CreateFrame("Button", nil, parent)
	local size = GF.MYTHIC_PLUS_CHARACTER_FOOTER_STYLE.roleSize
	button:SetSize(size, size)
	button.RoleKey = roleKey
	button.NativeRole = roleKey == "HEAL" and "HEALER" or roleKey == "DPS" and "DAMAGER" or roleKey
	button.RoleIcon = button:CreateTexture(nil, "ARTWORK")
	button.RoleIcon:SetAllPoints(button)
	function button:SetChecked(checked)
		self._cachedChecked = checked == true and self._available ~= false
		refresh(self)
	end
	function button:GetChecked() return self._cachedChecked == true end
	function button:SetAvailable(available)
		self._available = available ~= false
		if not self._available then self._cachedChecked = false end
		refresh(self)
	end
	button:SetScript("OnClick", function(self)
		if self._available == false then return end
		local card, enabled = self.OwnerCard, not self:GetChecked()
		local data = card and card._gfData
		local service = GF.MythicPlusCharacterStore
		local changed, roles
		if data and (data.isDebugTest or data.isTest) and GF.MythicPlusDebugService then
			changed, roles = GF.MythicPlusDebugService:SetLocalRole(data.key, self.RoleKey, enabled)
		elseif data and data.key and service then
			changed, roles = service:SetStoredRole(data.key, self.RoleKey, enabled)
		end
		-- The store may reject clearing the final role or rebind the card while
		-- notifying listeners. Always render its accepted state, not the click.
		if card and card._gfData == data then
			if type(roles) == "table" then
				self:SetChecked(roles[self.RoleKey] == true)
			elseif changed then
				self:SetChecked(enabled)
			end
		end
		if changed and GF.UI.PlayUISound then GF.UI.PlayUISound("check") end
	end)
	button:SetScript("OnEnter", function(self)
		local locale = GF.L or {}
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(locale["MPLUS_ROLE_" .. roleKey .. "_TITLE"] or title, 1, 0.82, 0)
		GameTooltip:AddLine(locale["MPLUS_ROLE_" .. roleKey .. "_DESC"] or description, 1, 1, 1, true)
		if self._available == false then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(locale.MPLUS_ROLE_UNAVAILABLE or "你的职业无法担任该职责。", 1, 0.1, 0.1, true)
		end
		GameTooltip:Show()
	end)
	local function hideTooltip(self)
		if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	end
	button:SetScript("OnLeave", hideTooltip)
	button:SetScript("OnHide", hideTooltip)
	refresh(button)
	return button
end
