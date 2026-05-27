-- Deja PRFader，隐藏团队管理边框，https://www.curseforge.com/wow/addons/dejaprfader
U1PLUG["DejaPRFader"] = function()

local function WaitForMouseToGoAway(self)
	if not self:IsMouseOver() then
		self:SetScript("OnUpdate", nil)
		self:SetAlpha(0)
	end
end

CompactRaidFrameManager:HookScript("OnEnter", function(self)
	self:SetScript("OnUpdate", nil)
	self:SetAlpha(1)
end)

CompactRaidFrameManager:HookScript("OnLeave", function(self)
	if self.collapsed then
		self:SetScript("OnUpdate", WaitForMouseToGoAway)
	end
end)

local function CheckMouseOver(self)
	if self:IsMouseOver() and not self.collapsed then
		self:GetScript("OnEnter")(self)
	else
		self:GetScript("OnLeave")(self)
	end
end

hooksecurefunc("CompactRaidFrameManager_Collapse", function(self) CheckMouseOver(CompactRaidFrameManager) end)
hooksecurefunc("CompactRaidFrameManager_Expand", function(self) CheckMouseOver(CompactRaidFrameManager) end)

CompactRaidFrameManager:HookScript("OnShow", function(self) CheckMouseOver(CompactRaidFrameManager) end)

local function CRFCUpdate(self)
	if InCombatLockdown() then 
		CompactRaidFrameContainer:UnregisterAllEvents();
	elseif not InCombatLockdown() then
		CompactRaidFrameContainer:RegisterEvent("DISPLAY_SIZE_CHANGED");
		CompactRaidFrameContainer:RegisterEvent("UI_SCALE_CHANGED");
		CompactRaidFrameContainer:RegisterEvent("GROUP_ROSTER_UPDATE");
		CompactRaidFrameContainer:RegisterEvent("UNIT_FLAGS");
		CompactRaidFrameContainer:RegisterEvent("PLAYER_FLAGS_CHANGED");
		CompactRaidFrameContainer:RegisterEvent("PLAYER_ENTERING_WORLD");
		CompactRaidFrameContainer:RegisterEvent("PARTY_LEADER_CHANGED");
		CompactRaidFrameContainer:RegisterEvent("RAID_TARGET_UPDATE");
		CompactRaidFrameContainer:RegisterEvent("PLAYER_TARGET_CHANGED");
		CompactRaidFrameContainer:SetParent(UIParent)
	end
end

hooksecurefunc("CompactUnitFrame_UpdateVisible", CRFCUpdate)
hooksecurefunc("CompactUnitFrame_UpdateAll", CRFCUpdate)

end