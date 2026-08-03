local _, GF = ...

GF.ApplicantsScrollList = {}
local ASL = GF.ApplicantsScrollList

local function memberRowH()
	if GF.GetApplicantRowH then
		return GF.GetApplicantRowH()
	end
	if GF.APPLICANT_ROW_H then
		return GF.APPLICANT_ROW_H
	end
	return GF.GetListRowH and GF.GetListRowH() or (GF.LIST_ROW_H or 32)
end

local function makeElementKey(applicantID, memberIdx)
	return tostring(applicantID or "") .. ":" .. tostring(memberIdx or 1)
end

function ASL.BuildElements(applicantIDs, dataResolver)
	local elements = {}
	local ids = applicantIDs or {}
	for i = 1, #ids do
		local applicantID = ids[i]
		local data = dataResolver and dataResolver(applicantID)
			or (GF.ApplicantModel and GF.ApplicantModel.BuildApplicantSafely
				and GF.ApplicantModel:BuildApplicantSafely(applicantID))
		local numMembers = math.max(1, tonumber(data and data.numMembers) or 1)
		local groupActionIndex = (numMembers > 1) and math.ceil(numMembers / 2) or 1
		for memberIdx = 1, numMembers do
			elements[#elements + 1] = {
				elementKey = makeElementKey(applicantID, memberIdx),
				applicantID = applicantID,
				memberIdx = memberIdx,
				groupIndex = memberIdx,
				groupSize = numMembers,
				groupActionIndex = groupActionIndex,
				applicantData = data,
			}
		end
	end
	return elements
end

function ASL.Create(panel, parent, opts)
	local options = type(opts) == "table" and opts or {}
	local cards = GF.ApplicantCard
	local function initializeCard(card, elementData)
		if cards and type(cards.EnsureCard) == "function" then
			cards:EnsureCard(card)
		end
		if cards and type(cards.BindElement) == "function" then
			cards:BindElement(card, elementData, panel)
		end
	end
	return GF.UI.ScrollList.Create(parent, {
		assignedKey = "elementKey",
		barParent = options.barParent or parent,
		elementInitializer = initializeCard,
		extentCalculator = function()
			return memberRowH()
		end,
		frameType = "Frame",
		keepNativeScrollBar = true,
	})
end

function ASL.RelayoutVisible(panel)
	local list = panel and panel.scrollList
	if list == nil then
		return
	end
	local width = list:GetLayoutWidth()
	local cards = GF.ApplicantCard
	list:ForEachFrame(function(card)
		if cards and type(cards.LayoutOnly) == "function" then
			cards:LayoutOnly(card, width)
		end
	end)
end
