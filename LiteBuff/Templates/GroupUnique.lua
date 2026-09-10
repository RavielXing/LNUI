------------------------------------------------------------
-- GroupUnique.lua
--
-- Abin
-- 2012/1/26
------------------------------------------------------------

local UnitIsUnit = UnitIsUnit
local NONE = "|cff808080"..NONE.."|r"

local _, addon = ...
local L = addon.L
local templates = addon.templates

local function Button_OnTooltipText(self, tooltip)
	tooltip:AddLine(L["affected target"]..(addon:GetColoredUnitName(self.affectedUnit) or NONE), 1, 1, 1, 1)
end

local function Button_OnUpdateTimer(self, spell)
    if self.alertIcon then self.alertIcon:Hide() end
	self.affectedUnit = nil
	local allowSelf = self.allowSelf
	if allowSelf then
		local expires = addon:GetUnitBuffTimer("player", spell, 1)
		if expires then
			self.affectedUnit = "player"
			return "NONE", expires
		end
	end

	local key, count = addon:IsGrouped()
	if key then
		local i
		for i = 1, count do
			local unit = key..i
			if allowSelf or not UnitIsUnit(unit, "player") then
				local expires = addon:GetUnitBuffTimer(unit, spell, 1)
				if expires then
					self.affectedUnit = unit
					return "NONE", expires
				end
			end
		end
    end

    if self.alertMissing and U1GetCfgValue and U1GetCfgValue("LiteBuff", "alertMissing") then
        if self.alertMissing ~= 1 and addon:GetUnitBuffTimer("player", self.alertMissing) then return end
        if not self.alertIcon then
            local alertName = self:GetName() and self:GetName().."AlertFrame" or nil
            self.alertIcon = CreateFrame("CheckButton", alertName, self, "ActionButtonTemplate")
            self.alertIcon:EnableMouse(false)
            self.alertIcon:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        self.alertIcon.icon:SetTexture(self.icon.icon:GetTexture())
        self.alertIcon:Show()
    end

    return "R"
end

local function Button_AllowSelf(self)
	self.allowSelf = 1
end

local function Button_AlertIfMissing(self, spellId)
    local spellInfo = spellId and C_Spell.GetSpellInfo(spellId)
    self.alertMissing = spellInfo and spellInfo.name or 1
end

templates.RegisterTemplate("GROUP_UNIQUE", function(button)
	button.OnUpdateTimer = Button_OnUpdateTimer
	button.OnTooltipText = Button_OnTooltipText
	button.AllowSelf = Button_AllowSelf
    button.AlertIfMissing = Button_AlertIfMissing
end, "GROUP")