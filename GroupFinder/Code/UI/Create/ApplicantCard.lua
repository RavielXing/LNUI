local _, GF = ...

GF.ApplicantCard = {}
local AC = GF.ApplicantCard

local AMB = GF.ApplicantMemberBlock

local function rowH()
	if GF.GetApplicantRowH then
		return GF.GetApplicantRowH()
	end
	if GF.APPLICANT_ROW_H then
		return GF.APPLICANT_ROW_H
	end
	return GF.GetListRowH and GF.GetListRowH() or (GF.LIST_ROW_H or 32)
end
local ACTION_BUTTON_SIZE = GF.APPLICANT_ACTION_BUTTON_SIZE or 24
local BTN_GAP = 4
local RIGHT_PAD = 3
local ROW_CONTENT_OFFSET_Y = GF.APPLICANT_ROW_CONTENT_OFFSET_Y or -1

local function groupSize(elementData)
	return math.max(1, tonumber(elementData and elementData.groupSize) or 1)
end

local function groupIndex(elementData)
	return math.max(1, tonumber(elementData and elementData.groupIndex) or tonumber(elementData and elementData.memberIdx) or 1)
end

local function groupActionIndex(elementData)
	return math.max(1, tonumber(elementData and elementData.groupActionIndex) or math.ceil(groupSize(elementData) / 2))
end

local function isGroupedElement(elementData)
	return groupSize(elementData) > 1
end

local function shouldShowActionControls(elementData)
	return not isGroupedElement(elementData) or groupIndex(elementData) == groupActionIndex(elementData)
end

local function shouldShowDivider(elementData)
	return not isGroupedElement(elementData) or groupIndex(elementData) == groupSize(elementData)
end

local function getGroupBackgroundMode(elementData)
	if not isGroupedElement(elementData) then
		return "full"
	end
	local idx = groupIndex(elementData)
	local size = groupSize(elementData)
	if idx == 1 then
		return "top"
	end
	if idx == size then
		return "bottom"
	end
	return "hidden"
end

local function memberHasSocialRelationship(relationship)
	return GF.IsSocialRelationship and GF.IsSocialRelationship(relationship)
end

local function memberIsBlacklisted(memberData)
	return memberData and (memberData.isBlacklisted == true or memberData.blacklistEntry ~= nil)
end

local function getGroupVisualState(data)
	if not data then
		return nil
	end
	local hasRelationship = false
	for _, memberData in ipairs(data.members or {}) do
		if memberIsBlacklisted(memberData) or (memberData and memberData.isLeaver) then
			return "red"
		end
		if memberHasSocialRelationship(memberData and memberData.relationship) then
			hasRelationship = true
		end
	end
	if data.grayed then
		return "grey"
	end
	return hasRelationship and (GF.SOCIAL_ROW_VISUAL_STATE or "blue") or nil
end

local function isTestApplicantData(data)
	return data and (data.isTest == true
		or (GF.ApplicantTestData
			and GF.ApplicantTestData.IsTestApplicantID
			and GF.ApplicantTestData:IsTestApplicantID(data.applicantID)))
end

local function layoutActionStrip(card, width)
	local layout = AMB:GetActionsColumnLayout(width)
	local centerY = (-(card:GetHeight() or rowH()) * 0.5) + ROW_CONTENT_OFFSET_Y
	local actionsCol = layout.byId.actions
	if not actionsCol then
		card.declineBar:ClearAllPoints()
		card.declineBar:SetPoint("CENTER", card, "TOPRIGHT", -(RIGHT_PAD + ACTION_BUTTON_SIZE / 2), centerY)
		card.acceptBar:ClearAllPoints()
		card.acceptBar:SetPoint("CENTER", card, "TOPRIGHT", -(RIGHT_PAD + ACTION_BUTTON_SIZE + BTN_GAP + ACTION_BUTTON_SIZE / 2), centerY)
		return
	end
	local actionCenterX = actionsCol.x + actionsCol.width * 0.5
	local offset = (ACTION_BUTTON_SIZE + BTN_GAP) * 0.5
	card.declineBar:ClearAllPoints()
	card.declineBar:SetPoint("CENTER", card, "TOPLEFT", actionCenterX + offset, centerY)
	card.acceptBar:ClearAllPoints()
	card.acceptBar:SetPoint("CENTER", card, "TOPLEFT", actionCenterX - offset, centerY)
	if card.spinner then
		card.spinner:ClearAllPoints()
		card.spinner:SetPoint("CENTER", card, "TOPLEFT", actionCenterX, centerY)
	end
	if card.status then
		card.status:ClearAllPoints()
		if card.decline:IsShown() then
			card.status:SetPoint("RIGHT", card.decline, "LEFT", -8, 0)
		else
			card.status:SetPoint("CENTER", card, "TOPLEFT", actionCenterX, centerY)
		end
	end
	if card.newBg then
		card.newBg:ClearAllPoints()
		card.newBg:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -2)
		card.newBg:SetPoint("BOTTOMRIGHT", card, "TOPLEFT", actionsCol.x - 2, 2)
	end
end

local function raiseActionControls(card)
	if not card or not card.GetFrameLevel then
		return
	end
	local base = card:GetFrameLevel() or 1
	if card.acceptBar and card.acceptBar.SetFrameLevel then
		card.acceptBar:SetFrameLevel(base + 20)
	end
	if card.declineBar and card.declineBar.SetFrameLevel then
		card.declineBar:SetFrameLevel(base + 20)
	end
	if card.accept and card.accept.SetFrameLevel then
		card.accept:SetFrameLevel(base + 21)
	end
	if card.decline and card.decline.SetFrameLevel then
		card.decline:SetFrameLevel(base + 21)
	end
end

local function setActionButtonHover(button, hovered)
	if not button then
		return
	end
	button._gfApplicantActionHovered = hovered and true or nil
	if not hovered then
		button._gfApplicantActionPressed = nil
	end
	if button.RefreshApplicantActionState then
		button:RefreshApplicantActionState()
	end
end

function AC:Create(parent, existingFrame)
	local card = existingFrame
	if not card then
		card = CreateFrame("Frame", nil, parent)
	end
	if card._gfInited then
		return card
	end
	card:SetSize(parent and parent:GetWidth() or card:GetWidth() or 400, rowH())

	card.newBg = card:CreateTexture(nil, "BACKGROUND", nil, 0)
	card.newBg:SetColorTexture(1, 0.9, 0.3, 0.08)
	card.newBg:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -2)
	card.newBg:SetPoint("BOTTOMRIGHT", card, "RIGHT", -120, 2)
	card.newBg:Hide()

	card.divider = card:CreateTexture(nil, "BORDER", nil, -1)
	card.divider:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 3, 0)
	card.divider:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -3, 0)
	if GF.ListRow and GF.ListRow.ApplyDivider then
		GF.ListRow:ApplyDivider(card)
	end

	card.members = {}
	card.memberPool = {}

	card.status = GF.UI.CreateFontString(card, "OVERLAY", "GameFontNormalSmall")
	card.status:SetJustifyH("RIGHT")
	card.status:Hide()

	card.spinner = CreateFrame("Frame", nil, card, "SpinnerTemplate")
	card.spinner:SetSize(24, 24)
	card.spinner:Hide()

	card.declineBar, card.decline = GF.UI.CreateApplicantDeclineButton(card)
	card.acceptBar, card.accept = GF.UI.CreateApplicantInviteButton(card)
	if card.accept.SetMotionScriptsWhileDisabled then
		card.accept:SetMotionScriptsWhileDisabled(true)
	end
	if card.decline.SetMotionScriptsWhileDisabled then
		card.decline:SetMotionScriptsWhileDisabled(true)
	end

	card.accept:SetScript("OnEnter", function(btn)
		setActionButtonHover(btn, true)
		local block = btn._inviteBlockReason
		if block then
			GF.UI.ShowApplicantBlockTooltip(btn, block)
		elseif btn._actionTooltip then
			GF.UI.ShowSimpleTooltip(btn, btn._actionTooltip, "ANCHOR_RIGHT")
		end
	end)
	card.accept:SetScript("OnLeave", function(btn)
		setActionButtonHover(btn, false)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	card.decline:SetScript("OnEnter", function(btn)
		setActionButtonHover(btn, true)
		local block = btn._declineBlockReason
		if block then
			GF.UI.ShowApplicantBlockTooltip(btn, block)
		elseif btn._actionTooltip then
			GF.UI.ShowSimpleTooltip(btn, btn._actionTooltip, "ANCHOR_RIGHT")
		end
	end)
	card.decline:SetScript("OnLeave", function(btn)
		setActionButtonHover(btn, false)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	card._gfInited = true
	return card
end

function AC:EnsureCard(card)
	if not card or card._gfInited then
		return card
	end
	local parent = card:GetParent()
	return self:Create(parent, card)
end

function AC:BindElement(card, elementData, panel)
	if not card or not elementData or not panel then
		return
	end
	local data = GF.ApplicantModel and GF.ApplicantModel:BuildApplicant(elementData.applicantID)
	if not data then
		card:Hide()
		return
	end
	local width = panel.scrollList and panel.scrollList:GetLayoutWidth() or card:GetWidth()
	self:SetData(card, data, width, elementData)
end

function AC:AcquireMember(card)
	local pool = card.memberPool
	local m = table.remove(pool)
	if not m then
		m = AMB:Create(card)
	end
	m:SetParent(card)
	m:Show()
	card.members[#card.members + 1] = m
	return m
end

function AC:ReleaseMembers(card)
	for _, m in ipairs(card.members) do
		m:Hide()
		m:ClearAllPoints()
		m.applicantID = nil
		m.memberIdx = nil
		card.memberPool[#card.memberPool + 1] = m
	end
	card.members = {}
end

function AC:SetData(card, data, width, elementData)
	if not card or not data then
		card:Hide()
		return
	end
	card.applicantID = data.applicantID
	card._elementData = elementData
	width = width or card:GetWidth() or 400
	card:SetWidth(width)

	self:ReleaseMembers(card)

	card:SetHeight(rowH())

	local memberIdx = math.max(1, tonumber(elementData and elementData.memberIdx) or 1)
	local memberData = data.members and (data.members[memberIdx] or data.members[1])
	if not memberData then
		card:Hide()
		return
	end
	local member = self:AcquireMember(card)
	member:ClearAllPoints()
	member:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
	member:SetSize(width, rowH())
	raiseActionControls(card)
	local descText = (memberIdx == 1) and data.comment or ""
	AMB:SetData(member, data.applicantID, memberData, {
		width = width,
		descriptionText = descText,
		backgroundMode = getGroupBackgroundMode(elementData),
		groupVisualState = isGroupedElement(elementData) and getGroupVisualState(data) or nil,
	})

	if card.newBg then
		card.newBg:SetShown(data.isNew == true and groupIndex(elementData) == 1)
	end
	if card.divider then
		if GF.ListRow and GF.ListRow.ApplyDivider then
			GF.ListRow:ApplyDivider(card)
		end
		card.divider:SetShown(shouldShowDivider(elementData) and card.divider:IsShown())
	end

	self:ApplyActionState(card, data, width, elementData)

	card.accept:SetScript("OnClick", function()
		if isTestApplicantData(data) then
			if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
				GF.ApplicantsPanel:Refresh({ preserveScroll = true })
			end
			return
		end
		GF.Listing:Accept(data.applicantID)
		if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
			GF.ApplicantsPanel:Refresh()
		end
	end)
	card.decline:SetScript("OnClick", function()
		if isTestApplicantData(data) then
			if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
				GF.ApplicantsPanel:Refresh({ preserveScroll = true })
			end
			return
		end
		if not GF.Listing:Decline(data.applicantID) and not GF.Listing:CanManageEntry() then
			GF.Listing:NotifyApplicantActionBlocked("unempowered")
		end
		if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
			GF.ApplicantsPanel:Refresh()
		end
	end)

	card:Show()
end

function AC:ApplyActionState(card, data, width, elementData)
	if not card or not data then
		return
	end
	width = width or card:GetWidth() or 400
	elementData = elementData or card._elementData
	local showControls = shouldShowActionControls(elementData)
	local isGroup = isGroupedElement(elementData)
	local L = GF.L or {}
	card.acceptBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)
	card.declineBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)

	card.spinner:SetShown(showControls and data.loading)
	card.accept:SetShown(showControls and data.showInvite and not data.loading)
	card.decline:SetShown(showControls and data.showDecline and not data.loading)

	if showControls and data.statusText and not data.loading then
		card.status:SetText(data.statusText)
		if data.statusColor then
			card.status:SetTextColor(data.statusColor.r, data.statusColor.g, data.statusColor.b)
		end
		card.status:Show()
	else
		card.status:Hide()
	end

	layoutActionStrip(card, width)
	raiseActionControls(card)

	local isTest = isTestApplicantData(data)
	local canManage = GF.Listing and GF.Listing.CanManageEntry and GF.Listing:CanManageEntry()
	local blockReason = (not isTest and GF.Listing and GF.Listing.GetApplicantInviteBlockReason)
		and GF.Listing:GetApplicantInviteBlockReason(data.applicantID)
		or nil
	local blockedByPermission = showControls and not canManage
	card.accept._inviteBlockReason = blockedByPermission and "unempowered" or blockReason
	card.decline._declineBlockReason = blockedByPermission and "unempowered" or nil
	card.accept._actionTooltip = blockedByPermission and nil
		or (isGroup and (L.APPLICANT_GROUP_INVITE or "整队邀请") or (L.APPLICANT_INVITE or L.ACCEPT or "邀请"))
	card.decline._actionTooltip = blockedByPermission and nil
		or (isGroup and (L.APPLICANT_GROUP_DECLINE or "整队拒绝") or (L.APPLICANT_DECLINE or L.DECLINE or "拒绝"))
	local actionAllowed = canManage
	card.accept:SetEnabled(showControls and actionAllowed and data.canInvite == true)
	card.decline:SetEnabled(showControls and actionAllowed and data.canDecline == true)
	if card.accept.icon then
		card.accept.icon:SetDesaturated(not (showControls and actionAllowed and data.canInvite == true))
		card.accept.icon:SetAlpha((showControls and actionAllowed and data.canInvite == true) and 1 or 0.45)
	end
	if card.decline.icon then
		card.decline.icon:SetDesaturated(not (showControls and actionAllowed and data.canDecline == true))
		card.decline.icon:SetAlpha((showControls and actionAllowed and data.canDecline == true) and 1 or 0.45)
	end
	if card.accept.RefreshApplicantActionState then
		card.accept:RefreshApplicantActionState()
	end
	if card.decline.RefreshApplicantActionState then
		card.decline:RefreshApplicantActionState()
	end
end

function AC:LayoutOnly(card, width)
	if not card or not card.applicantID then
		return
	end
	width = width or card:GetWidth()
	card:SetWidth(width)
	card:SetHeight(rowH())
	for i, member in ipairs(card.members) do
		member:ClearAllPoints()
		member:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
		member:SetSize(width, rowH())
		AMB:LayoutOnly(member, width)
	end
	card.acceptBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)
	card.declineBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)
	layoutActionStrip(card, width)
	raiseActionControls(card)
end

function AC:RefreshDivider(card)
	if card and card.divider and GF.ListRow and GF.ListRow.ApplyDivider then
		GF.ListRow:ApplyDivider(card)
		card.divider:SetShown(shouldShowDivider(card._elementData) and card.divider:IsShown())
	end
end
