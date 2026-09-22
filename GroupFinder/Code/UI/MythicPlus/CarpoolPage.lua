local _, GF = ...

GF.MythicPlusCarpoolPage = GF.MythicPlusCarpoolPage or {}
local CarpoolPage = GF.MythicPlusCarpoolPage
local UI = GF.MythicPlusUI

function CarpoolPage:Create(parent)
	if self.page then
		return self.page
	end
	self.page = UI.CreateRosterPage(parent, {
		listKind = "carpool",
		emptyKey = "MPLUS_CARPOOL_EMPTY",
		lastLabelKey = "MPLUS_COL_WARBAND",
		sortColumn = "last",
		getElements = function()
			if GF.MythicPlusCarpoolView
				and GF.MythicPlusCarpoolView.GetCharacters
			then
				return GF.MythicPlusCarpoolView:GetCharacters()
			end
			return GF.MythicPlusCharacterStore
				and GF.MythicPlusCharacterStore:GetCarpoolCharacters() or {}
		end,
		getLastText = function(data)
			return data and data.warbandSourceName
				or ((GF.L and GF.L.MPLUS_NO_INFO) or "无信息")
		end,
	})
	return self.page
end
