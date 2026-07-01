local _, GF = ...

GF.ApplicantsPanel = {}
local AP = GF.ApplicantsPanel
local ASL = GF.ApplicantsScrollList

local HEADER_H = GF.SUBTITLE_HEADER_H or 22
local FOOTER_H = GF.SUBTITLE_H or 42
local GAP = GF.SUBTITLE_CONTROL_GAP or 7
local LEFT_PAD = GF.SUBTITLE_CONTROL_LEFT_PAD or 15
local RIGHT_PAD = GF.SUBTITLE_CONTROL_RIGHT_PAD or 10
local MANAGE_BUTTON_W = GF.APPLICANT_MANAGE_BUTTON_W or GF.PANEL_BUTTON_TWO_CHAR_W or 72
local HEADER_REFRESH_TEXTURE = GF.BROWSE_HEADER_REFRESH_TEXTURE or GF.REFRESH_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\Refresh.png"

local function applicantRowKey(applicantID, memberIdx)
	return tostring(applicantID or "") .. ":" .. tostring(memberIdx or 1)
end

local function selectedApplicantIDFromKey(key)
	return key and key:match("^([^:]+):") or nil
end

local function applicantIDInList(applicantIDs, applicantID)
	local target = tostring(applicantID or "")
	if target == "" then
		return false
	end
	for _, id in ipairs(applicantIDs or {}) do
		if tostring(id) == target then
			return true
		end
	end
	return false
end

local function controlCenterY()
	return GF.SUBTITLE_CONTROL_CENTER_OFFSET_Y or 0
end

local function setHeaderRefreshIconPressed(button, pressed)
	local icon = button and button.Icon
	if not icon then
		return
	end
	local normalSize = GF.BROWSE_HEADER_REFRESH_ICON_SIZE or 21
	local pressedSize = GF.BROWSE_HEADER_REFRESH_ICON_PRESSED_SIZE or 19
	local size = pressed and pressedSize or normalSize
	icon:ClearAllPoints()
	icon:SetSize(size, size)
	icon:SetPoint("CENTER", button, "CENTER", 0, GF.APPLICANT_HEADER_REFRESH_BUTTON_OFFSET_Y or 0)
end

local function setHeaderRefreshButtonEnabled(button, enabled)
	if not button then
		return
	end
	enabled = enabled == true
	button:SetEnabled(enabled)
	if button.Icon then
		if button.Icon.SetDesaturated then
			button.Icon:SetDesaturated(not enabled)
		end
		button.Icon:SetAlpha(enabled and 1 or 0.45)
	end
	if not enabled then
		setHeaderRefreshIconPressed(button, false)
	end
end

local function getLoadingCycleSeconds()
	return ((GF.BROWSE_LOADING_STEP_SECONDS or 0.28) * (GF.BROWSE_LOADING_ICON_COUNT or 3))
		+ (GF.BROWSE_LOADING_HOLD_SECONDS or 0.4)
		+ (GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45)
end

local function getLoadingIconAlpha(elapsed, iconIndex)
	local stepSeconds = GF.BROWSE_LOADING_STEP_SECONDS or 0.28
	local fadeInSeconds = GF.BROWSE_LOADING_FADE_IN_SECONDS or 0.16
	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local holdSeconds = GF.BROWSE_LOADING_HOLD_SECONDS or 0.4
	local fadeOutSeconds = GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45
	local appearAt = (iconIndex - 1) * stepSeconds
	if elapsed < appearAt then
		return 0
	end
	local fadeInEnd = appearAt + fadeInSeconds
	if elapsed < fadeInEnd then
		return math.max(0, math.min(1, (elapsed - appearAt) / fadeInSeconds))
	end
	local fadeOutStart = (stepSeconds * iconCount) + holdSeconds
	if elapsed < fadeOutStart then
		return 1
	end
	local fadeOutEnd = fadeOutStart + fadeOutSeconds
	if elapsed < fadeOutEnd then
		return math.max(0, math.min(1, 1 - ((elapsed - fadeOutStart) / fadeOutSeconds)))
	end
	return 0
end

local function refreshLoadingAnimation(animation)
	if not (animation and animation.icons) then
		return
	end
	local elapsed = animation.elapsed or 0
	for index, icon in ipairs(animation.icons) do
		local alpha = getLoadingIconAlpha(elapsed, index)
		icon:SetAlpha(alpha)
		if alpha > 0.02 then
			icon:Show()
		else
			icon:Hide()
		end
	end
end

local function applyManageState(panel, canLead, canManage)
	if panel.editBtn then
		panel.editBtn:SetEnabled(canLead)
	end
	if panel.refreshBtn then
		setHeaderRefreshButtonEnabled(panel.refreshBtn, canManage)
	end
	if panel.bumpBtn then
		local listing = GF.Listing
		local onCooldown = listing and listing.IsBumpOnCooldown and listing:IsBumpOnCooldown()
		local busy = listing and listing.IsBumpBusy and listing:IsBumpBusy()
		panel.bumpBtn:SetEnabled(canLead and not onCooldown and not busy)
	end
	if panel.removeBtn then
		panel.removeBtn:SetEnabled(canLead)
	end
	if panel.autoCheck then
		local listing = GF.Listing
		local canToggle = listing and listing.CanToggleAutoInvite and listing:CanToggleAutoInvite()
		panel.autoCheck:SetEnabled(true)
		if panel.autoCheck.SetDesaturated then
			panel.autoCheck:SetDesaturated(not canToggle)
		end
		if panel.autoLabel then
			if canToggle then
				panel.autoLabel:SetTextColor(1, 0.82, 0)
			else
				panel.autoLabel:SetTextColor(0.5, 0.5, 0.5)
			end
		end
		if listing and listing.IsAutoInviteEnabled then
			panel.autoCheck:SetChecked(listing:IsAutoInviteEnabled())
		end
	end
end

function AP:ForEachVisibleRow(fn)
	if self.scrollList and fn then
		self.scrollList:ForEachFrame(fn)
	end
end

function AP:GetSelectedApplicantRowKey()
	return self.selectedApplicantRowKey
end

function AP:RefreshSelectedApplicantRows()
	if not self.scrollList then
		return
	end
	self:ForEachVisibleRow(function(card)
		if card and card.members and GF.ApplicantMemberBlock and GF.ApplicantMemberBlock.UpdateSelectedState then
			for _, member in ipairs(card.members) do
				GF.ApplicantMemberBlock:UpdateSelectedState(member)
			end
		end
	end)
end

function AP:SetSelectedApplicantRow(row)
	local key = row and row.applicantID and applicantRowKey(row.applicantID, row.memberIdx) or nil
	if self.selectedApplicantRowKey == key then
		self:RefreshSelectedApplicantRows()
		return
	end
	self.selectedApplicantRowKey = key
	self:RefreshSelectedApplicantRows()
end

function AP:Init(parent)
	if self.scrollList then
		return
	end
	if not GF.UI.ScrollList or not GF.UI.ScrollList.IsAvailable() then
		return
	end

	self.parent = parent
	local L = GF.L or {}

	self.columnHeaderHost = CreateFrame("Frame", nil, parent)
	self.columnHeaderHost:SetPoint("TOPLEFT", parent, "TOPLEFT", GF.CONTENT_SCROLL_INSET_L or 0, GF.BROWSE_HEADER_TOP_OFFSET or -20)
	self.columnHeaderHost:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(GF.CONTENT_SCROLL_INSET_R or 18), GF.BROWSE_HEADER_TOP_OFFSET or -20)
	self.columnHeaderHost:SetHeight(HEADER_H)
	self.columnHeaderHost:SetFrameLevel(parent:GetFrameLevel() + 25)
	if GF.UI and GF.UI.InstallBrowseHeaderChrome then
		GF.UI.InstallBrowseHeaderChrome(self.columnHeaderHost)
	end

	self.refreshBtn = CreateFrame("Button", nil, parent)
	self.refreshBtn:SetSize(GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE or 35, GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE or 35)
	self.refreshBtn:SetFrameLevel(parent:GetFrameLevel() + 35)
	self.refreshBtn:RegisterForClicks("LeftButtonUp")
	local refreshIcon = self.refreshBtn:CreateTexture(nil, "OVERLAY")
	refreshIcon:SetTexture(GF.BROWSE_HEADER_REFRESH_TEXTURE or HEADER_REFRESH_TEXTURE)
	refreshIcon:SetTexCoord(0, 1, 0, 1)
	self.refreshBtn.Icon = refreshIcon
	setHeaderRefreshIconPressed(self.refreshBtn, false)
	self.refreshBtn:SetScript("OnClick", function()
		if not (GF.Listing and GF.Listing.CanManageEntry and GF.Listing:CanManageEntry()) then
			return
		end
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		if GF.Listing and GF.Listing.RefreshApplicants then
			GF.Listing:RefreshApplicants()
		end
		if AP.Refresh then
			AP:Refresh()
		end
	end)
	self.refreshBtn:SetScript("OnEnter", function(btn)
		if btn.IsEnabled and not btn:IsEnabled() then
			return
		end
		GF.UI.BeginGameTooltip(btn, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L.REFRESH_LISTING or "刷新列表", 1, 0.82, 0, true)
		GameTooltip:AddLine(L.REFRESH_LISTING_TIP or "刷新当前招募的申请者列表", 1, 1, 1, true)
		GF.UI.ShowGameTooltip()
	end)
	self.refreshBtn:SetScript("OnMouseDown", function(btn, mouseButton)
		if mouseButton == "LeftButton" then
			setHeaderRefreshIconPressed(btn, true)
		end
	end)
	self.refreshBtn:SetScript("OnMouseUp", function(btn)
		setHeaderRefreshIconPressed(btn, false)
	end)
	self.refreshBtn:SetScript("OnLeave", function(btn)
		setHeaderRefreshIconPressed(btn, false)
		if GameTooltip and GameTooltip:GetOwner() == btn then
			GameTooltip:Hide()
		end
	end)
	self.refreshBtn:SetScript("OnDisable", function(btn)
		setHeaderRefreshIconPressed(btn, false)
	end)
	self.refreshBtn:Hide()

	self.footer = CreateFrame("Frame", nil, parent)
	self.footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
	self.footer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	self.footer:SetHeight(FOOTER_H)
	self.footer:SetFrameLevel(parent:GetFrameLevel() + 30)
	if GF.UI and GF.UI.InstallBrowseControlBarChrome then
		GF.UI.InstallBrowseControlBarChrome(self.footer)
	end

	self.toolbar = CreateFrame("Frame", nil, self.footer)
	self.toolbar:SetAllPoints(self.footer)

	self.editBtn = GF.UI.CreatePanelButton(self.toolbar, L.EDIT_LISTING or "Edit", MANAGE_BUTTON_W, true)
	self.editBtn:SetPoint("LEFT", self.toolbar, "LEFT", LEFT_PAD, controlCenterY())
	GF.UI.BindLeaderOnlyButton(self.editBtn, function()
		if GF.CreateDrawer then
			GF.CreateDrawer:Open({ mode = "edit", allowOccupiedPrompt = true })
		end
	end, nil, "aboveLeft")

	self.removeBtn = GF.UI.CreatePanelButton(self.toolbar, L.REMOVE_LISTING or "Remove", MANAGE_BUTTON_W, true)
	self.removeBtn:SetPoint("RIGHT", self.toolbar, "RIGHT", -RIGHT_PAD, controlCenterY())
	GF.UI.BindLeaderOnlyButton(self.removeBtn, function()
		GF.Listing:Remove()
		if GF.MainFrame then
			GF.MainFrame:OnActiveEntryUpdate()
		end
	end, nil, "aboveLeft")

	self.bumpBtn = GF.UI.CreatePanelButton(self.toolbar, L.BUMP_LISTING or "Relist", MANAGE_BUTTON_W, true)
	self.bumpBtn:SetPoint("RIGHT", self.removeBtn, "LEFT", -6, 0)
	GF.UI.BindLeaderOnlyButton(self.bumpBtn, function()
		if not (GF.Listing and GF.Listing.RelistForBump) then
			return
		end
		if self.bumpBtn then
			self.bumpBtn:SetEnabled(false)
		end
		GF.Listing:RelistForBump()
		AP:UpdateManageState()
	end, function(btn)
		GF.UI.BeginGameTooltipAbove(btn, "LEFT")
		GF.UI.SetTooltipText(L.BUMP_LISTING_TIP or "")
		GF.UI.ShowGameTooltip()
	end, "aboveLeft")

	self.autoCheck = CreateFrame("CheckButton", nil, self.toolbar, "UICheckButtonTemplate")
	self.autoCheck:SetSize(22, 22)
	self.autoLabel = GF.UI.CreateFontString(self.toolbar, "OVERLAY", "GameFontNormal")
	self.autoLabel:SetText(L.AUTO_ACCEPT or "Auto invite")
	self.autoCheck:SetPoint("LEFT", self.toolbar, "LEFT", LEFT_PAD, controlCenterY())
	self.autoLabel:SetPoint("LEFT", self.autoCheck, "RIGHT", GF.SUBTITLE_OPTION_TEXT_GAP or 1, 0)
	self.autoCheck:SetScript("OnClick", function(btn)
		if not GF.Listing or not GF.Listing.SetAutoInviteEnabled then
			return
		end
		if not GF.Listing:CanToggleAutoInvite() then
			btn:SetChecked(GF.Listing:IsAutoInviteEnabled())
			if GF.Listing.NotifyLeaderOnly then
				GF.Listing:NotifyLeaderOnly()
			end
			return
		end
		GF.Listing:SetAutoInviteEnabled(btn:GetChecked())
	end)
	self.autoCheck:SetScript("OnEnter", function()
		AP:ShowAutoAcceptTooltip()
	end)
	self.autoCheck:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	self.removeBtn:ClearAllPoints()
	self.removeBtn:SetPoint("RIGHT", self.toolbar, "RIGHT", -RIGHT_PAD, controlCenterY())
	self.editBtn:ClearAllPoints()
	self.editBtn:SetPoint("RIGHT", self.removeBtn, "LEFT", -GAP, 0)
	self.bumpBtn:ClearAllPoints()
	self.bumpBtn:SetPoint("RIGHT", self.editBtn, "LEFT", -GAP, 0)

	self.columnHeaderBar = GF.ColumnHeaderBar:Create(self.columnHeaderHost, {
		mode = "applicant",
		profile = "applicant",
		onSort = function()
			if GF.ListColumns then
				GF.ListColumns:InvalidateCache()
			end
			AP:RefreshList()
			AP:LayoutColumnHeaders()
		end,
		onLayoutChange = function()
			if AP.RelayoutRows then
				AP:RelayoutRows()
			end
		end,
	})
	self.columnHeaderBar:SetPoint("TOPLEFT", self.columnHeaderHost, "TOPLEFT", 0, GF.BROWSE_HEADER_CONTENT_OFFSET_Y or 4)
	self.columnHeaderBar:SetPoint("BOTTOMRIGHT", self.columnHeaderHost, "BOTTOMRIGHT", 0, GF.BROWSE_HEADER_CONTENT_OFFSET_Y or 4)

	self.listBody = CreateFrame("Frame", nil, parent)
	self.listBody:SetPoint("TOPLEFT", self.columnHeaderHost, "BOTTOMLEFT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 0))
	self.listBody:SetPoint("TOPRIGHT", self.columnHeaderHost, "BOTTOMRIGHT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 0))
	self.listBody:SetPoint("BOTTOMLEFT", self.footer, "TOPLEFT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
	self.listBody:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
	self.listBody:SetFrameLevel(parent:GetFrameLevel() + 2)

	self.scrollList = ASL.Create(self, self.listBody, { barParent = parent })
	local scrollBox = self.scrollList:GetScrollBox()
	scrollBox:SetPoint("TOPLEFT", self.listBody, "TOPLEFT", 0, 0)
	GF.UI.AnchorContentScrollBottomRight(scrollBox, self.listBody)

	self._scrollLastW = 0
	self._scrollLastH = 0
	scrollBox:SetScript("OnSizeChanged", function(box, w, h)
		if AP._frameResizing then
			return
		end
		if AP.parent and not AP.parent:IsShown() then
			return
		end
		w = w or box:GetWidth()
		h = h or box:GetHeight()
		if not w or not h or w <= 0 or h <= 0 then
			return
		end
		if w == AP._scrollLastW and h == AP._scrollLastH then
			return
		end
		AP._scrollLastW = w
		AP._scrollLastH = h
		AP:ScheduleRelayout()
	end)

	self.empty = GF.UI.CreateFontString(self.listBody, "OVERLAY", "GameFontHighlight")
	self.empty:SetPoint("CENTER", scrollBox, "CENTER")
	self.empty:SetText(L.NO_APPLICANTS or "")
	self:ApplyEmptyPromptStyle()
	self.empty:Hide()
	self.emptyAnchor = scrollBox

	self.applicantIDs = {}
	self.totalCount = 0
	self:SetBottomControlsShown(false)
	self:SetHeaderRefreshButtonShown(false)
end

function AP:LayoutColumnHeaders(layoutWidth)
	if not self.columnHeaderHost or not self.columnHeaderHost:IsShown() then
		return
	end
	if not layoutWidth and GF.GetApplicantListLayoutWidth then
		layoutWidth = GF.GetApplicantListLayoutWidth()
	end
	GF.ColumnHeaderBar:LayoutHost(self.columnHeaderHost, self.columnHeaderBar, layoutWidth)
	self:AnchorHeaderRefreshButton()
	self:ScheduleHeaderRefreshButtonAnchor()
end

function AP:AnchorHeaderRefreshButton()
	if not self.refreshBtn then
		return
	end
	self.refreshBtn:ClearAllPoints()
	local scrollBar = self.scrollList
		and self.scrollList.GetScrollBar
		and self.scrollList:GetScrollBar()
	if scrollBar and self.columnHeaderBar then
		local barLeft = self.columnHeaderBar:GetLeft()
		local scrollLeft = scrollBar:GetLeft()
		local scrollW = scrollBar:GetWidth()
		if barLeft and scrollLeft and scrollW and scrollW > 0 then
			local x = (scrollLeft + (scrollW / 2)) - barLeft
			self.refreshBtn:SetPoint("CENTER", self.columnHeaderBar, "LEFT", math.floor(x + 0.5), 0)
			return
		end
	end
	if self.columnHeaderHost then
		self.refreshBtn:SetPoint("CENTER", self.columnHeaderHost, "RIGHT", GF.CONTENT_SCROLLBAR_OFFSET_X or 9, 0)
		return
	end
	if scrollBar then
		self.refreshBtn:SetPoint("CENTER", scrollBar, "CENTER", 0, 0)
	end
end

function AP:ScheduleHeaderRefreshButtonAnchor()
	if not self.refreshBtn then
		return
	end
	if not C_Timer or not C_Timer.After then
		self:AnchorHeaderRefreshButton()
		return
	end
	C_Timer.After(0, function()
		if AP.refreshBtn and AP.columnHeaderHost and AP.columnHeaderHost:IsShown() then
			AP:AnchorHeaderRefreshButton()
		end
	end)
end

function AP:SetHeaderRefreshButtonShown(shown)
	shown = shown == true
	if self.refreshBtn then
		self.refreshBtn:SetShown(shown)
		if shown then
			self:AnchorHeaderRefreshButton()
			self:ScheduleHeaderRefreshButtonAnchor()
		elseif GameTooltip and GameTooltip:GetOwner() == self.refreshBtn then
			GameTooltip:Hide()
		end
	end
end

function AP:RefreshScrollViewport()
	local sl = self.scrollList
	if not sl or not sl.dataProvider then
		return
	end
	if sl.RetainScrollPosition then
		sl:RetainScrollPosition()
	end
end

function AP:UpdateScrollWidth()
	self:RefreshScrollViewport()
end

function AP:CancelRelayoutDebounce()
	if self._relayoutDebounce and self._relayoutDebounce.Cancel then
		self._relayoutDebounce:Cancel()
	end
	self._relayoutDebounce = nil
end

function AP:ScheduleRelayout()
	if self._relayoutDebounce then
		return
	end
	if not C_Timer or not C_Timer.After then
		self:Relayout()
		return
	end
	self._relayoutDebounce = C_Timer.After(0.1, function()
		self._relayoutDebounce = nil
		self:Relayout()
	end)
end

function AP:RelayoutWhenReady(attempt)
	GF.UI.RelayoutWhenReady(self, attempt)
end

function AP:GetRelayoutSig()
	local layoutW = GF.GetApplicantListLayoutWidth and GF.GetApplicantListLayoutWidth() or 0
	return GF.ListColumns and GF.ListColumns.GetRelayoutSig and GF.ListColumns:GetRelayoutSig(layoutW, "applicant")
end

function AP:RelayoutRows()
	if self._frameResizing or GF._frameResizing then
		return
	end
	if self.parent and not self.parent:IsShown() then
		return
	end
	self:CancelRelayoutDebounce()
	self:LayoutColumnHeaders()
	if ASL then
		ASL.RelayoutVisible(self)
	end
	self:RefreshScrollViewport()
	GF.UI.CommitRelayoutSig(self)
end

function AP:Relayout(opts)
	opts = opts or {}
	if not self.scrollList then
		return
	end
	if self.parent and not self.parent:IsShown() then
		return
	end
	self:CancelRelayoutDebounce()
	local sig = self:GetRelayoutSig()
	if not opts.force and sig and sig == self._relayoutSig then
		self:RefreshScrollViewport()
		return
	end
	if GF.ListColumns then
		GF.ListColumns:InvalidateCache()
	end
	self:RelayoutRows()
end

function AP:UpdateInviteState()
	if not self.scrollList then
		return
	end
	self:ForEachVisibleRow(function(card)
		local applicantID = card and card.applicantID
		if card and applicantID and card:IsShown() then
			local data = GF.ApplicantModel:BuildApplicant(applicantID)
			if data then
				GF.ApplicantCard:ApplyActionState(card, data, card:GetWidth(), card._elementData)
				local blockReason = card.accept._inviteBlockReason
				if card.accept:IsMouseOver() and blockReason then
					GF.UI.ShowApplicantBlockTooltip(card.accept, blockReason)
				end
			end
		end
	end)
end

local function getActiveRecruitingPrompt(L)
	local title = GF.Listing and GF.Listing.GetActiveActivityTitle and GF.Listing:GetActiveActivityTitle()
	if title and title ~= "" then
		local entryName = GF.Listing and GF.Listing.GetActiveEntryName and GF.Listing:GetActiveEntryName()
		if entryName and entryName ~= "" then
			return string.format(L.CREATE_ACTIVE_RECRUITING_PROMPT_FMT or "|cffffd100%s|r |cffffffff%s|r |cffffd100正在招募中|r", title, entryName)
		end
		return string.format(L.CREATE_ACTIVE_RECRUITING_ACTIVITY_PROMPT_FMT or "|cffffd100%s正在招募中|r", title)
	end
	return L.NO_APPLICANTS or "队伍正在招募中"
end

function AP:UpdateEmptyHint()
	if not self.empty then
		return
	end
	local L = GF.L or {}
	local canLead = GF.Listing and GF.Listing.CanLeadListing and GF.Listing:CanLeadListing()
	local listed = GF.Listing and GF.Listing:HasActive()
	local hasTestApplicants = GF.ApplicantTestData
		and GF.ApplicantTestData.IsEnabled
		and GF.ApplicantTestData:IsEnabled()
	if not listed and not hasTestApplicants then
		local premadeBlockMessage = GF.Availability
			and GF.Availability.GetPremadeBlockMessage
			and GF.Availability:GetPremadeBlockMessage()
		local prompt
		if premadeBlockMessage then
			prompt = premadeBlockMessage
		elseif canLead then
			prompt = L.CREATE_EMPTY_PROMPT or L.NO_LISTING or "请创建集合石招募"
		else
			prompt = L.CREATE_LEADER_ONLY_PROMPT or "仅队长有权限创建队伍"
		end
		self:SetEmptyPrompt(prompt, true)
	elseif listed and not hasTestApplicants then
		self:SetEmptyPrompt((self.totalCount == 0) and getActiveRecruitingPrompt(L) or nil, self.totalCount == 0)
	elseif listed then
		self:SetEmptyPrompt((self.totalCount == 0) and (L.NO_APPLICANTS or "") or nil, self.totalCount == 0)
	else
		self:SetEmptyPrompt((self.totalCount == 0) and (L.NO_APPLICANTS or "") or nil, self.totalCount == 0)
	end
end

function AP:RefreshDividers()
	self:ForEachVisibleRow(function(card)
		if card then
			GF.ApplicantCard:RefreshDivider(card)
		end
	end)
end

function AP:RefreshList(opts)
	opts = opts or {}
	if not self.scrollList then
		return
	end
	local previousCount = self.totalCount or 0
	self.applicantIDs = GF.ApplicantModel:GetSortedApplicantIDs()
	if self.selectedApplicantRowKey
		and not applicantIDInList(self.applicantIDs, selectedApplicantIDFromKey(self.selectedApplicantRowKey))
	then
		self.selectedApplicantRowKey = nil
	end
	self.totalCount = #self.applicantIDs
	self:UpdateEmptyHint()

	if self.totalCount == 0 then
		self.scrollList:SetElements({})
		if not opts.preserveScroll and self.scrollList.ScrollToBegin then
			self.scrollList:ScrollToBegin()
		end
		self:UpdateInviteState()
		return
	end

	local elements = ASL.BuildElements(self.applicantIDs)
	local retainScroll = opts.preserveScroll == true and previousCount == self.totalCount
	self.scrollList:SetElements(elements, { retainScroll = retainScroll })
	if not retainScroll and self.scrollList.ScrollToBegin then
		self.scrollList:ScrollToBegin()
	end
	self:UpdateInviteState()
end

function AP:Refresh(opts)
	opts = opts or {}
	self:UpdateManageState()
	self:RefreshList(opts)
end

function AP:RefreshApplicant(applicantID)
	if not self.scrollList or not applicantID then
		return
	end
	local data = GF.ApplicantModel:BuildApplicant(applicantID)
	if not data then
		return false
	end
	local width = self.scrollList:GetLayoutWidth()
	local updated = false
	self:ForEachVisibleRow(function(card)
		if card and card.applicantID == applicantID and card:IsShown() then
			GF.ApplicantCard:SetData(card, data, width, card._elementData)
			updated = true
		end
	end)
	if not updated then
		return false
	end
	self:UpdateInviteState()
	return true
end

function AP:OnApplicantUpdated(applicantID)
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if not self:RefreshApplicant(applicantID) then
		self:Refresh({ preserveScroll = true })
	end
end

function AP:ShowAutoAcceptTooltip()
	local owner = self.autoCheck
	if not owner or not GameTooltip then
		return
	end
	local L = GF.L or {}
	local tip
	if GF.Listing and GF.Listing.CanToggleAutoInvite and not GF.Listing:CanToggleAutoInvite() then
		tip = GF.Listing.GetLeaderOnlyMessage and GF.Listing:GetLeaderOnlyMessage()
			or L.AUTO_ACCEPT_TIP_DISABLED
	elseif GF.Listing and GF.Listing.IsAutoInviteEnabled and GF.Listing:IsAutoInviteEnabled() then
		tip = L.AUTO_ACCEPT_TIP_ON
	else
		tip = L.AUTO_ACCEPT_TIP
	end
	if not tip or tip == "" then
		return
	end
	GF.UI.BeginGameTooltipAbove(owner, "LEFT")
	GF.UI.SetTooltipText(tip)
	GF.UI.ShowGameTooltip()
end

function AP:ApplyEmptyPromptStyle()
	if not self.empty then
		return
	end
	self.empty:SetTextColor(1, 0.82, 0, 1)
	self.empty._gfFontSizeOverride = GF.BROWSE_EMPTY_TEXT_SIZE or 14
	self.empty._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.Track then
		GF.Font.Track(self.empty, "GameFontHighlight")
	end
end

function AP:UpdateEmptyPromptLayout(showLoading)
	if not self.empty then
		return
	end
	local anchor = self.emptyAnchor or (self.scrollList and self.scrollList.GetScrollBox and self.scrollList:GetScrollBox())
	if not anchor then
		return
	end
	local offsetY = showLoading and (((GF.BROWSE_LOADING_ICON_HEIGHT or 25) + (GF.BROWSE_LOADING_TEXT_GAP or 7)) / 2) or 0
	self.empty:ClearAllPoints()
	self.empty:SetPoint("CENTER", anchor, "CENTER", 0, offsetY)
end

function AP:EnsureLoadingAnimation()
	if self.loadingAnimation then
		return self.loadingAnimation
	end
	local parent = self.emptyAnchor or (self.scrollList and self.scrollList.GetScrollBox and self.scrollList:GetScrollBox())
	if not parent then
		return nil
	end
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 5)
	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local iconWidth = GF.BROWSE_LOADING_ICON_WIDTH or 27
	local iconHeight = GF.BROWSE_LOADING_ICON_HEIGHT or 25
	local iconGap = GF.BROWSE_LOADING_ICON_GAP or 6
	local width = (iconWidth * iconCount) + (iconGap * math.max(0, iconCount - 1))
	frame:SetSize(width, iconHeight)
	frame.icons = {}
	for index = 1, iconCount do
		local icon = frame:CreateTexture(nil, "ARTWORK")
		icon:SetTexture(GF.BROWSE_LOADING_TEAMUP_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\TeamUp.png")
		icon:SetTexCoord((index - 1) / iconCount, index / iconCount, 0, 1)
		icon:SetSize(iconWidth, iconHeight)
		icon:SetPoint("LEFT", frame, "LEFT", (index - 1) * (iconWidth + iconGap), 0)
		icon:SetAlpha(0)
		icon:Hide()
		frame.icons[index] = icon
	end
	frame:SetScript("OnShow", function(animation)
		animation.elapsed = 0
		refreshLoadingAnimation(animation)
	end)
	frame:SetScript("OnUpdate", function(animation, elapsed)
		animation.elapsed = ((animation.elapsed or 0) + (elapsed or 0)) % getLoadingCycleSeconds()
		refreshLoadingAnimation(animation)
	end)
	frame:Hide()
	self.loadingAnimation = frame
	return frame
end

function AP:SetLoadingAnimationShown(shown)
	local animation = shown and self:EnsureLoadingAnimation() or self.loadingAnimation
	if not animation then
		return
	end
	animation:ClearAllPoints()
	if shown and self.empty then
		animation:SetPoint("TOP", self.empty, "BOTTOM", 0, -(GF.BROWSE_LOADING_TEXT_GAP or 7))
	end
	if shown then
		animation:Show()
	else
		animation:Hide()
	end
end

function AP:SetEmptyPrompt(text, showLoading)
	if not self.empty then
		return
	end
	showLoading = showLoading == true
	if text and text ~= "" then
		self:ApplyEmptyPromptStyle()
		self:UpdateEmptyPromptLayout(showLoading)
		self.empty:SetText(text)
		self.empty:Show()
		self:SetLoadingAnimationShown(showLoading)
	else
		self.empty:Hide()
		self:SetLoadingAnimationShown(false)
	end
end

function AP:SetBottomControlsShown(shown)
	shown = shown == true
	if self.footer then
		self.footer:SetShown(shown)
	end
	if self.toolbar then
		self.toolbar:SetShown(shown)
	end
	if self.listBody and self.columnHeaderHost then
		self.listBody:ClearAllPoints()
		self.listBody:SetPoint("TOPLEFT", self.columnHeaderHost, "BOTTOMLEFT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 0))
		self.listBody:SetPoint("TOPRIGHT", self.columnHeaderHost, "BOTTOMRIGHT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 0))
		if shown and self.footer then
			self.listBody:SetPoint("BOTTOMLEFT", self.footer, "TOPLEFT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
			self.listBody:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
		elseif self.parent then
			self.listBody:SetPoint("BOTTOMLEFT", self.parent, "BOTTOMLEFT", 0, 0)
			self.listBody:SetPoint("BOTTOMRIGHT", self.parent, "BOTTOMRIGHT", 0, 0)
		end
	end
	if GF.CreateDrawer and GF.CreateDrawer.Layout then
		GF.CreateDrawer:Layout()
	end
end

function AP:UpdateToolbarForListed()
	local listed = GF.Listing and GF.Listing:HasActive()
	local canManage = GF.Listing and GF.Listing.CanManageEntry and GF.Listing:CanManageEntry()
	self:SetBottomControlsShown(listed == true and canManage == true)
	self:SetHeaderRefreshButtonShown(listed == true and canManage == true)
	if self.columnHeaderHost then
		self.columnHeaderHost:Show()
		self:LayoutColumnHeaders()
	end
	if listed then
		self:UpdateManageState()
	end
end

function AP:UpdateManageState()
	local listing = GF.Listing
	local canLead = listing and listing.CanLeadListing and listing:CanLeadListing()
	local canManage = listing and listing.CanManageEntry and listing:CanManageEntry()
	local listed = listing and listing.HasActive and listing:HasActive()
	self:SetBottomControlsShown(listed == true and canManage == true)
	self:SetHeaderRefreshButtonShown(listed == true and canManage == true)
	applyManageState(self, canLead, canManage)
	self:UpdateEmptyHint()
	self:UpdateInviteState()
end

function AP:Show()
	if not self.parent then
		return
	end
	if not self.scrollList then
		self:Init(self.parent)
	end
	self.parent:Show()
	self:UpdateToolbarForListed()
	self:LayoutColumnHeaders()
	if GF.Listing and GF.Listing.RefreshApplicants then
		GF.Listing:RefreshApplicants()
	end
	self:Refresh()
end

function AP:Hide()
	if self.parent then
		self.parent:Hide()
	end
end
