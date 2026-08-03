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
	if data.grayed then
		return "grey"
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
	return hasRelationship and (GF.SOCIAL_ROW_VISUAL_STATE or "blue") or nil
end

local function isTestApplicantData(data)
	return data and (data.isTest == true
		or (GF.ApplicantTestData
			and GF.ApplicantTestData.IsTestApplicantID
			and GF.ApplicantTestData:IsTestApplicantID(data.applicantID)))
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
		local declineX = -(RIGHT_PAD + ACTION_BUTTON_SIZE * 0.5)
		local acceptX = declineX - ACTION_BUTTON_SIZE - BTN_GAP
		card.declineBar:ClearAllPoints()
		card.declineBar:SetPoint("CENTER", card, "TOPRIGHT", declineX, centerY)
		card.acceptBar:ClearAllPoints()
		card.acceptBar:SetPoint("CENTER", card, "TOPRIGHT", acceptX, centerY)
		return
	end
	local actionCenterX = actionsCol.x + actionsCol.width * 0.5
	local halfSeparation = (ACTION_BUTTON_SIZE + BTN_GAP) * 0.5
	for frame, offset in pairs({
		[card.acceptBar] = -halfSeparation,
		[card.declineBar] = halfSeparation,
	}) do
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", card, "TOPLEFT", actionCenterX + offset, centerY)
	end
	local spinner = card.spinner
	if spinner ~= nil then
		spinner:ClearAllPoints()
		spinner:SetPoint("CENTER", card, "TOPLEFT", actionCenterX, centerY)
	end
	local status = card.status
	if status ~= nil then
		status:ClearAllPoints()
		if card.decline:IsShown() then
			status:SetPoint("RIGHT", card.decline, "LEFT", -8, 0)
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
		[card.acceptBar] = 20,
		[card.declineBar] = 20,
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
		local reason = owner[reasonField]
		if reason ~= nil then
			GF.UI.ShowApplicantBlockTooltip(owner, reason)
		elseif owner._actionTooltip ~= nil then
			GF.UI.ShowSimpleTooltip(owner, owner._actionTooltip, "ANCHOR_RIGHT")
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

	local spinner = CreateFrame("Frame", nil, card, "SpinnerTemplate")
	spinner:SetSize(24, 24)
	spinner:Hide()
	card.spinner = spinner

	local declineBar, declineButton = GF.UI.CreateApplicantDeclineButton(card)
	local acceptBar, acceptButton = GF.UI.CreateApplicantInviteButton(card)
	card.declineBar, card.decline = declineBar, declineButton
	card.acceptBar, card.accept = acceptBar, acceptButton
	for _, button in ipairs({ card.accept, card.decline }) do
		if type(button.SetMotionScriptsWhileDisabled) == "function" then
			button:SetMotionScriptsWhileDisabled(true)
		end
	end
	installActionHover(card.accept, "_inviteBlockReason")
	installActionHover(card.decline, "_declineBlockReason")

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
	if data == nil and GF.ApplicantModel
		and GF.ApplicantModel.BuildApplicantSafely
	then
		data = GF.ApplicantModel:BuildApplicantSafely(elementData.applicantID)
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
	for _, member in ipairs(card.members) do
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
		local panel = GF.ApplicantsPanel
		if panel and panel.BeginApplicantAction then
			panel:BeginApplicantAction(data.applicantID, "invite")
		end
		local accepted, outcome = GF.Listing:Accept(data.applicantID)
		if (not accepted or outcome == "raid_conversion_popup")
			and panel and panel.ClearApplicantAction
		then
			panel:ClearApplicantAction(data.applicantID, true)
		end
	end)
	card.decline:SetScript("OnClick", function()
		if isTestApplicantData(data) then
			if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
				GF.ApplicantsPanel:Refresh({ preserveScroll = true })
			end
			return
		end
		local panel = GF.ApplicantsPanel
		if panel and panel.BeginApplicantAction then
			panel:BeginApplicantAction(data.applicantID, "decline")
		end
		local declined = GF.Listing:Decline(data.applicantID)
		if not declined and not GF.Listing:CanManageEntry() then
			GF.Listing:NotifyApplicantActionBlocked("unempowered")
		end
		if not declined and panel and panel.ClearApplicantAction then
			panel:ClearApplicantAction(data.applicantID, true)
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
	local showControls = shouldShowActionControls(elementData)
	local isGroup = isGroupedElement(elementData)
	local locale = GF.L or {}
	card.acceptBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)
	card.declineBar:SetSize(ACTION_BUTTON_SIZE, ACTION_BUTTON_SIZE)
	local actionPending = GF.ApplicantsPanel
		and GF.ApplicantsPanel.IsApplicantActionPending
		and GF.ApplicantsPanel:IsApplicantActionPending(data.applicantID)
	local loading = data.loading == true or actionPending == true
	card.spinner:SetShown(showControls and loading)
	card.accept:SetShown(showControls and data.showInvite == true and not loading)
	card.decline:SetShown(showControls and data.showDecline == true and not loading)
	local showStatus = showControls and data.statusText ~= nil and not loading
	if showStatus then
		card.status:SetText(data.statusText)
		local color = data.statusColor
		if color then
			card.status:SetTextColor(color.r, color.g, color.b)
		end
		card.status:Show()
	else
		card.status:Hide()
	end

	layoutActionStrip(card, width)
	raiseActionControls(card)

	local listing = GF.Listing
	local canManage = listing and type(listing.CanManageEntry) == "function"
		and listing:CanManageEntry() == true
	local blockReason
	if not isTestApplicantData(data)
		and listing and type(listing.GetApplicantInviteConstraint) == "function"
	then
		blockReason = listing:GetApplicantInviteConstraint(data.applicantID)
	end
	local blockedByPermission = showControls and canManage ~= true
	card.accept._inviteBlockReason = blockedByPermission and "unempowered" or blockReason
	card.decline._declineBlockReason = blockedByPermission and "unempowered" or nil
	if blockedByPermission then
		card.accept._actionTooltip = nil
		card.decline._actionTooltip = nil
	else
		card.accept._actionTooltip = isGroup
			and (locale.APPLICANT_GROUP_INVITE or "整队邀请")
			or (locale.APPLICANT_INVITE or locale.ACCEPT or "邀请")
		card.decline._actionTooltip = isGroup
			and (locale.APPLICANT_GROUP_DECLINE or "整队拒绝")
			or (locale.APPLICANT_DECLINE or locale.DECLINE or "拒绝")
	end
	for _, state in ipairs({
		{ button = card.accept, enabled = showControls and canManage and data.canInvite == true },
		{ button = card.decline, enabled = showControls and canManage and data.canDecline == true },
	}) do
		state.button:SetEnabled(state.enabled == true)
		if state.button.icon then
			state.button.icon:SetDesaturated(state.enabled ~= true)
			state.button.icon:SetAlpha(state.enabled and 1 or 0.45)
		end
		if type(state.button.RefreshApplicantActionState) == "function" then
			state.button:RefreshApplicantActionState()
		end
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
	layoutActionStrip(card, width)
	raiseActionControls(card)
end

function AC:RefreshDivider(card)
	if card and card.divider and GF.ListRow and GF.ListRow.ApplyDivider then
		GF.ListRow:ApplyDivider(card)
		card.divider:SetShown(shouldShowDivider(card._elementData) and card.divider:IsShown())
	end
end
