local _, GF = ...

-- Converts the applicant group model into the one-member-per-row projection
-- consumed by GF's virtual list. It does not own applicant state or actions.
local ApplicantRosterAdapter = {}
GF.ApplicantRosterAdapter = ApplicantRosterAdapter
GF.ApplicantsScrollList = ApplicantRosterAdapter -- existing GF page contract

local function rowExtent()
	if type(GF.GetApplicantRowH) == "function" then
		return GF.GetApplicantRowH()
	end
	if tonumber(GF.APPLICANT_ROW_H) then
		return GF.APPLICANT_ROW_H
	end
	if type(GF.GetListRowH) == "function" then
		return GF.GetListRowH()
	end
	return GF.LIST_ROW_H or 32
end

local function snapshotFor(applicantID, resolver)
	if type(resolver) == "function" then
		return resolver(applicantID)
	end
	local builder = GF.ApplicantSnapshotBuilder
	if builder and type(builder.BuildApplicantSafely) == "function" then
		return builder:BuildApplicantSafely(applicantID)
	end
	return nil
end

local function appendApplicantRows(output, applicantID, snapshot)
	local memberCount = math.max(
		1,
		math.floor(tonumber(snapshot and snapshot.numMembers) or 1)
	)
	local actionMember = memberCount > 1 and math.ceil(memberCount / 2) or 1
	for memberIndex = 1, memberCount do
		output[#output + 1] = {
			elementKey = string.format("%s:%d", tostring(applicantID or ""), memberIndex),
			applicantID = applicantID,
			memberIdx = memberIndex,
			groupIndex = memberIndex,
			groupSize = memberCount,
			groupActionIndex = actionMember,
			applicantData = snapshot,
		}
	end
end

function ApplicantRosterAdapter.BuildElements(applicantIDs, dataResolver)
	local rows = {}
	local ids = type(applicantIDs) == "table" and applicantIDs or {}
	for index = 1, #ids do
		local applicantID = ids[index]
		appendApplicantRows(
			rows,
			applicantID,
			snapshotFor(applicantID, dataResolver)
		)
	end
	return rows
end

local function bindApplicantCard(panel, card, element)
	local cardView = GF.ApplicantCard
	if not cardView then
		return
	end
	if type(cardView.EnsureCard) == "function" then
		cardView:EnsureCard(card)
	end
	if type(cardView.BindElement) == "function" then
		cardView:BindElement(card, element, panel)
	end
end

function ApplicantRosterAdapter.Create(panel, parent, options)
	local config = type(options) == "table" and options or {}
	local listType = GF.UI and (GF.UI.VirtualList or GF.UI.ScrollList)
	if not (listType and type(listType.Create) == "function") then
		return nil
	end
	return listType.Create(parent, {
		assignedKey = "elementKey",
		barParent = config.barParent or parent,
		elementInitializer = function(card, element)
			bindApplicantCard(panel, card, element)
		end,
		extentCalculator = rowExtent,
		frameType = "Frame",
		keepNativeScrollBar = true,
	})
end

function ApplicantRosterAdapter.RelayoutVisible(panel)
	local list = panel and panel.scrollList
	if not list then
		return
	end
	local cardView = GF.ApplicantCard
	if not (cardView and type(cardView.LayoutOnly) == "function") then
		return
	end
	local width = list:GetLayoutWidth()
	list:ForEachFrame(function(card)
		cardView:LayoutOnly(card, width)
	end)
end
