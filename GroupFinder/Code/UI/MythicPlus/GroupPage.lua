local _, GF = ...

GF.MythicPlusGroupPage = GF.MythicPlusGroupPage or {}
local GroupPage = GF.MythicPlusGroupPage
local UI = GF.MythicPlusUI

function GroupPage:Create(parent)
	if self.page then
		return self.page
	end
	self.page = UI.CreateRosterPage(parent, {
			listKind = "group",
			emptyKey = "MPLUS_GROUP_EMPTY",
			lastLabelKey = "MPLUS_COL_QUICK_ACTION",
			unknownKeyTextKey = "MPLUS_NO_INFO",
			getElements = function()
			return GF.MythicPlusRosterCache and GF.MythicPlusRosterCache:GetMembers() or {}
			end,
			quickAction = true,
		})
	return self.page
end
