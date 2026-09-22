local _, GF = ...

GF.ApplicantCard = {}
local AC = GF.ApplicantCard

local AMB = GF.ApplicantMemberBlock
local RosterPresenter = GF.ApplicantRosterPresenter

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
local RIGHT_PAD = 3
local ROW_CONTENT_OFFSET_Y = GF.APPLICANT_ROW_CONTENT_OFFSET_Y or -1

local function groupSize(elementData)
	return math.max(1, tonumber(elementData and elementData.groupSize) or 1)
end

local function groupIndex(elementData)
	return math.max(1, tonumber(elementData and elementData.groupIndex) or tonumber(elementData and elementData.memberIdx) or 1)
end

local function isGroupedElement(elementData)
	return groupSize(elementData) > 1
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
	if data.grayed then
		return "grey"
	end
	local hasBlacklisted = false
	local hasNewbie = false
	local hasRelationship = false
	local hasLeaver = false
	for _, memberData in ipairs(data.members or {}) do
		hasBlacklisted = hasBlacklisted or memberIsBlacklisted(memberData)
		hasNewbie = hasNewbie or (memberData
			and memberData.neteaseIdentity
			and memberData.neteaseIdentity.isNewbie == true)
		hasLeaver = hasLeaver or (memberData and memberData.isLeaver == true)
		if memberHasSocialRelationship(memberData and memberData.relationship) then
			hasRelationship = true
		end
	end
	if hasBlacklisted then
		return "red"
	end
	if hasNewbie then
		return "newbie"
	end
	if hasRelationship then
		return GF.SOCIAL_ROW_VISUAL_STATE or "blue"
	end
	return hasLeaver and "red" or nil
end

function AC:ResetRemovalFade(card)
	if not card then
		return
	end
	local fade = card._gfApplicantRemovalFade
	if fade and fade:IsPlaying() then
		fade:Stop()
	end
	card._gfApplicantRemovalFadeToken = nil
	card:SetAlpha(1)
end

function AC:PlayRemovalFade(card, token, duration)
	if not card then
		return false
	end
	self:ResetRemovalFade(card)
	card._gfApplicantRemovalFadeToken = token
	local fade = card._gfApplicantRemovalFade
	if not fade and card.CreateAnimationGroup then
		fade = card:CreateAnimationGroup()
		local alpha = fade:CreateAnimation("Alpha")
		alpha:SetFromAlpha(1)
		alpha:SetToAlpha(0)
		alpha:SetSmoothing("IN")
		fade._gfAlpha = alpha
		fade:SetScript("OnFinished", function(group)
			if card._gfApplicantRemovalFadeToken == group._gfToken then
				card:SetAlpha(0)
			end
		end)
		card._gfApplicantRemovalFade = fade
	end
	if not (fade and fade._gfAlpha) then
		card:SetAlpha(0)
		return false
	end
	fade._gfToken = token
	fade._gfAlpha:SetDuration(math.max(0.01, tonumber(duration) or 0.16))
	fade:Play()
	return true
end

local function layoutActionStrip(card, width)
	local layout = AMB:GetActionsColumnLayout(width)
	local centerY = (-(card:GetHeight() or rowH()) * 0.5) + ROW_CONTENT_OFFSET_Y
	local actionsCol = layout.byId.actions
	if actionsCol == nil then
		GF.UI.LayoutApplicantActionButtons(card, card.viewBar, card.acceptBar, card.declineBar,
			width - RIGHT_PAD - ACTION_BUTTON_SIZE * 1.5 - GF.APPLICANT_ACTION_BUTTON_GAP, true)
		return
	end
	local actionCenterX = actionsCol.x + actionsCol.width * 0.5
	local showsView = card.view and card.view:IsShown()
	local showsGroupButtons = card.accept:IsShown() or card.decline:IsShown()
	local showsStatus = card.status and card.status:IsShown()
	GF.UI.LayoutApplicantActionButtons(card, card.viewBar, card.acceptBar, card.declineBar,
		actionCenterX, showsView and (showsGroupButtons or isGroupedElement(card._elementData)))
	local spinner = card.spinner
	if spinner ~= nil then
		spinner:ClearAllPoints()
		spinner:SetPoint(
			"CENTER",
			card,
			"TOPLEFT",
			actionCenterX,
			centerY)
	end
	local status = card.status
	if status ~= nil then
		status:ClearAllPoints()
		if showsStatus and showsView then
			local viewX = actionsCol.x + (ACTION_BUTTON_SIZE * 0.5) + 2
			card.viewBar:ClearAllPoints()
			card.viewBar:SetPoint("CENTER", card, "TOPLEFT", viewX, centerY)
			status:SetPoint(
				"RIGHT",
				card,
				"TOPLEFT",
				actionsCol.x + actionsCol.width - 3,
				centerY)
			status:SetSize(
				math.max(1, actionsCol.width - ACTION_BUTTON_SIZE - 9),
				18)
		else
			status:SetPoint("CENTER", card, "TOPLEFT", actionCenterX, centerY)
		end
	end
	local background = card.newBg
	if background ~= nil then
		background:ClearAllPoints()
		background:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -2)
		background:SetPoint("BOTTOMRIGHT", card, "TOPLEFT", actionsCol.x - 2, 2)
	end
end

local function raiseActionControls(card)
	if card == nil or type(card.GetFrameLevel) ~= "function" then
		return
	end
	local base = card:GetFrameLevel() or 1
	for control, offset in pairs({
		[card.viewBar] = 20,
		[card.acceptBar] = 20,
		[card.declineBar] = 20,
		[card.view] = 21,
		[card.accept] = 21,
		[card.decline] = 21,
	}) do
		if control and type(control.SetFrameLevel) == "function" then
			control:SetFrameLevel(base + offset)
		end
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

local function installActionHover(button, reasonField)
	button:SetScript("OnEnter", function(owner)
		setActionButtonHover(owner, true)
		local reason = reasonField and owner[reasonField] or nil
		if reason ~= nil then
			GF.UI.ShowApplicantBlockTooltip(owner, reason)
		elseif owner._actionTooltip ~= nil then
			GF.UI.ShowSimpleTooltipAbove(owner, owner._actionTooltip)
		end
	end)
	button:SetScript("OnLeave", function(owner)
		setActionButtonHover(owner, false)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
end

function AC:Create(parent, existingFrame)
	local card = existingFrame or CreateFrame("Frame", nil, parent)
	if card._gfInited == true then
		return card
	end
	local initialWidth = parent and parent:GetWidth() or card:GetWidth() or 400
	card:SetSize(initialWidth, rowH())

	local newBackground = card:CreateTexture(nil, "BACKGROUND", nil, 0)
	newBackground:SetColorTexture(1, 0.9, 0.3, 0.08)
	newBackground:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -2)
	newBackground:SetPoint("BOTTOMRIGHT", card, "RIGHT", -120, 2)
	newBackground:Hide()
	card.newBg = newBackground

	local divider = card:CreateTexture(nil, "BORDER", nil, -1)
	divider:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 3, 0)
	divider:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -3, 0)
	card.divider = divider
	if GF.ListRow and type(GF.ListRow.ApplyDivider) == "function" then
		GF.ListRow:ApplyDivider(card)
	end

	card.members = {}
	card.memberPool = {}

	local status = GF.UI.CreateFontString(card, "OVERLAY", "GameFontNormalSmall")
	status:SetJustifyH("RIGHT")
	status:Hide()
	card.status = status

	local spinner = GF.UI and GF.UI.CreatePendingSpinner
		and GF.UI.CreatePendingSpinner(card, 24)
		or CreateFrame("Frame", nil, card, "SpinnerTemplate")
	spinner:SetSize(24, 24)
	spinner:Hide()
	card.spinner = spinner

	local viewBar, viewButton = GF.UI.CreateApplicantViewButton(card)
	local declineBar, declineButton = GF.UI.CreateApplicantDeclineButton(card)
	local acceptBar, acceptButton = GF.UI.CreateApplicantInviteButton(card)
	card.viewBar, card.view = viewBar, viewButton
	card.declineBar, card.decline = declineBar, declineButton
	card.acceptBar, card.accept = acceptBar, acceptButton
	for _, button in ipairs({ card.view, card.accept, card.decline }) do
		if type(button.SetMotionScriptsWhileDisabled) == "function" then
			button:SetMotionScriptsWhileDisabled(true)
		end
	end
	installActionHover(card.view)
	installActionHover(card.accept, "_inviteBlockReason")
	installActionHover(card.decline, "_declineBlockReason")
	card.view:SetScript("OnClick", function()
		local presenter = RosterPresenter or GF.ApplicantRosterPresenter
		if presenter
			and type(presenter.OpenMemberCharacterInfo) == "function"
		then
			presenter.OpenMemberCharacterInfo(card._viewMember)
		end
	end)

	card._gfInited = true
	return card
end

function AC:EnsureCard(card)
	if card == nil then
		return nil
	end
	if card._gfInited ~= true then
		card = self:Create(card:GetParent(), card)
	end
	return card
end

function AC:BindElement(card, elementData, panel)
	if card == nil or type(elementData) ~= "table" or panel == nil then
		return
	end
	local data
	if type(panel.GetApplicantDisplayData) == "function" then
		data = panel:GetApplicantDisplayData(elementData.applicantID)
	end
	data = data or elementData.applicantData
	if data == nil and GF.ApplicantSnapshotBuilder
		and GF.ApplicantSnapshotBuilder.BuildApplicantSafely
	then
		data = GF.ApplicantSnapshotBuilder:BuildApplicantSafely(elementData.applicantID)
	end
	if data == nil then
		card:Hide()
		return
	end
	local width = panel.scrollList
		and panel.scrollList:GetLayoutWidth() or card:GetWidth()
	self:SetData(card, data, width, elementData)
end

function AC:AcquireMember(card)
	local pool = card.memberPool
	local member = table.remove(pool)
	if member == nil then
		member = AMB:Create(card)
	end
	member:SetParent(card)
	member:Show()
	card.members[#card.members + 1] = member
	return member
end

function AC:ReleaseMembers(card)
	card._viewMember = nil
	for _, member in ipairs(card.members) do
		if member.typeSpinner and GF.UI and GF.UI.StopPendingSpinner then
			GF.UI.StopPendingSpinner(member.typeSpinner)
		end
		member:Hide()
		member:ClearAllPoints()
		member.applicantID = nil
		member.memberIdx = nil
		card.memberPool[#card.memberPool + 1] = member
	end
	card.members = {}
end

function AC:SetData(card, data, width, elementData)
	if not card or not data then
		card:Hide()
		return
	end
	local fadeToken = data._gfTerminalFadeToken
	local continuingFade = fadeToken ~= nil
		and card.applicantID == data.applicantID
		and card._gfApplicantRemovalFadeToken == fadeToken
	if not continuingFade then
		self:ResetRemovalFade(card)
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
	card._viewMember = member

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
		local presenter = RosterPresenter or GF.ApplicantRosterPresenter
		if presenter and type(presenter.SubmitApplicantAction) == "function" then
			presenter.SubmitApplicantAction(
				GF.ApplicantsPanel, data, "invite")
		end
	end)
	card.decline:SetScript("OnClick", function()
		local presenter = RosterPresenter or GF.ApplicantRosterPresenter
		if presenter and type(presenter.SubmitApplicantAction) == "function" then
			presenter.SubmitApplicantAction(
				GF.ApplicantsPanel, data, "decline")
		end
	end)

	card:Show()
	if fadeToken ~= nil
		and card._gfApplicantRemovalFadeToken ~= fadeToken
	then
		self:PlayRemovalFade(
			card,
			fadeToken,
			data._gfTerminalFadeSeconds
				or GF.BROWSE_ROW_BACKGROUND_FADE_SECONDS
				or 0.16
		)
	end
end

function AC:ApplyActionState(card, data, width, elementData)
	if card == nil or type(data) ~= "table" then
		return
	end
	width = width or card:GetWidth() or 400
	elementData = elementData or card._elementData
	local presenter = RosterPresenter or GF.ApplicantRosterPresenter
	local projection = presenter
		and type(presenter.ProjectActionState) == "function"
		and presenter.ProjectActionState(
			GF.ApplicantsPanel, data, elementData) or nil
	if not projection then
		return
	end
	card.acceptBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)
	card.declineBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)
	card.viewBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)
	if projection.showSpinner then
		if GF.UI and GF.UI.StartPendingSpinner then
			GF.UI.StartPendingSpinner(card.spinner, 24)
		else
			card.spinner:Show()
		end
	elseif GF.UI and GF.UI.StopPendingSpinner then
		GF.UI.StopPendingSpinner(card.spinner)
	else
		card.spinner:Hide()
	end
	card.accept:SetShown(projection.showInvite)
	card.decline:SetShown(projection.showDecline)
	card.view:SetShown(projection.showView == true and card._viewMember ~= nil)
	local canView = presenter
		and type(presenter.CanOpenMemberCharacterInfo) == "function"
		and presenter.CanOpenMemberCharacterInfo(card._viewMember) == true
	card.view:SetEnabled(canView)
	card.view._actionTooltip = (GF.L or {}).APPLICANT_QUERY_CHARACTER
		or "查询角色信息"
	if projection.showStatus then
		card.status:SetText(projection.statusText)
		local color = projection.statusColor
		if color then
			card.status:SetTextColor(color.r, color.g, color.b)
		end
		card.status:Show()
	else
		card.status:Hide()
	end

	layoutActionStrip(card, width)
	raiseActionControls(card)

	card.accept._inviteBlockReason = projection.inviteBlockReason
	card.decline._declineBlockReason = projection.declineBlockReason
	card.accept._actionTooltip = projection.inviteTooltip
	card.decline._actionTooltip = projection.declineTooltip
	for _, state in ipairs({
		{ button = card.accept, enabled = projection.inviteEnabled },
		{ button = card.decline, enabled = projection.declineEnabled },
	}) do
		state.button:SetEnabled(state.enabled == true)
		if type(state.button.RefreshApplicantActionState) == "function" then
			state.button:RefreshApplicantActionState()
		end
	end
	if type(card.view.RefreshApplicantActionState) == "function" then
		card.view:RefreshApplicantActionState()
	end
end

function AC:LayoutOnly(card, width)
	if card == nil or card.applicantID == nil then
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
	card.viewBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)
	layoutActionStrip(card, width)
	raiseActionControls(card)
end

function AC:RefreshDivider(card)
	if card and card.divider and GF.ListRow and GF.ListRow.ApplyDivider then
		GF.ListRow:ApplyDivider(card)
		card.divider:SetShown(shouldShowDivider(card._elementData) and card.divider:IsShown())
	end
end
