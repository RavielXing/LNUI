local _, GF = ...
GF = GF.GF or GF

local View = {}
GF.RaidRecruitmentNeedsPanel = View

function View:ShouldShow(panel)
	local context = panel.workspaceContext
	return context ~= nil and context.workspaceID == GF.WORKSPACE_RAID
		and not panel:IsMythicPlusSidebarMode()
end

function View:Create(panel)
	return GF.UI.ClassSpecSelector:Create(panel.formBody, {
		titleKey = "RAID_REQUIRED_CLASSES",
		emptySelectionHintKey = "RAID_REQUIRED_SPECS_EMPTY",
		selectionHintKey = "RAID_REQUIRED_SPECS_POLICY_HINT",
		getSelection = function() return GF.RecruitmentFormPresenter:GetRaidRequiredSpecs(panel) end,
		setSelected = function(specID, selected)
			GF.RecruitmentFormPresenter:SetRaidRequiredSpec(panel, specID, selected)
		end,
		toggleRole = function(role) GF.RecruitmentFormPresenter:ToggleRaidRequiredRole(panel, role) end,
		isEnabled = function()
			return self:ShouldShow(panel) and panel._protectedFieldsFormEnabled == true
				and not panel.censoredResolutionMode
		end,
	})
end

function View:Place(panel, width, y, x)
	if not self:ShouldShow(panel) then
		if panel.raidNeedsUI then panel.raidNeedsUI.frame:Hide() end
		return 0
	end
	local instance = panel.raidNeedsUI
	if not instance then instance = self:Create(panel); panel.raidNeedsUI = instance end
	instance.frame:ClearAllPoints()
	instance.frame:SetPoint("TOPLEFT", panel.formColumn, "TOPLEFT", x or 0, -y)
	instance.frame:Show()
	return instance:Layout(width)
end
