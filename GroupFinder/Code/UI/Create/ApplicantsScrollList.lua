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
			or (GF.ApplicantModel and GF.ApplicantModel:BuildApplicant(applicantID))
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
	opts = opts or {}
	local ac = GF.ApplicantCard
	return GF.UI.ScrollList.Create(parent, {
		assignedKey = "elementKey",
		barParent = opts.barParent or parent,
		keepNativeScrollBar = true,
		frameType = "Frame",
		extentCalculator = function(_, elementData)
			return memberRowH()
		end,
		elementInitializer = function(card, elementData)
			if ac and ac.EnsureCard then
				ac:EnsureCard(card)
			end
			if ac and ac.BindElement then
				ac:BindElement(card, elementData, panel)
			end
		end,
	})
end

function ASL.RelayoutVisible(panel)
	if not panel or not panel.scrollList then
		return
	end
	local width = panel.scrollList:GetLayoutWidth()
	local ac = GF.ApplicantCard
	panel.scrollList:ForEachFrame(function(card)
		if ac and ac.LayoutOnly then
			ac:LayoutOnly(card, width)
		end
	end)
end
