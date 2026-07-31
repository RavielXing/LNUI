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
local ROLE_SUMMARY_W = GF.APPLICANT_ACTIVE_ROLE_SUMMARY_W or 168
local ROLE_SUMMARY_X = GF.APPLICANT_ACTIVE_ROLE_SUMMARY_X or 0
local ROLE_SUMMARY_H = GF.FRAME_BODY_BOTTOM or 41
local HEADER_REFRESH_TEXTURE = GF.BROWSE_HEADER_REFRESH_TEXTURE or GF.REFRESH_TEXTURE
local BUTTON_VISUAL_STATE = GF.BUTTON_VISUAL_STATE

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

local function applicantIDKey(applicantID)
	return tostring(applicantID or "")
end

local function applicantIDSet(applicantIDs)
	local set = {}
	for _, applicantID in ipairs(applicantIDs or {}) do
		set[applicantIDKey(applicantID)] = true
	end
	return set
end

local function applicantMemberCount(data)
	return math.max(1, tonumber(data and data.numMembers) or 1)
end

local function markApplicantDataUnavailable(data)
	if not data then
		return nil
	end
	local L = GF.L or {}
	data._gfSoftUnavailable = true
	data.loading = false
	data.isNew = false
	data.grayed = true
	data.showInvite = false
	data.showDecline = false
	data.canInvite = false
	data.canDecline = false
	data.status = data.status or "unavailable"
	data.statusText = L.APPLICANT_STATUS_UNAVAILABLE or "已失效"
	data.statusColor = { r = 0.5, g = 0.5, b = 0.5 }
	for _, memberData in ipairs(data.members or {}) do
		memberData.grayed = true
	end
	return data
end

local function controlCenterY()
	return GF.SUBTITLE_CONTROL_CENTER_OFFSET_Y or 0
end

local function normalizeAssignedRole(role)
	if type(role) ~= "string" then
		return nil
	end
	role = role:upper()
	if role == "DPS" then
		return "DAMAGER"
	end
	if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
		return role
	end
	return nil
end

local function getPlayerSpecializationRole()
	if not (GetSpecialization and GetSpecializationRole) then
		return nil
	end
	local specIndex = GetSpecialization()
	if not specIndex then
		return nil
	end
	return normalizeAssignedRole(GetSpecializationRole(specIndex))
end

local function normalizeRoleCounts(data)
	if type(data) ~= "table" then
		return nil
	end
	local counts = {
		TANK = tonumber(data.TANK) or 0,
		HEALER = tonumber(data.HEALER) or 0,
		DAMAGER = tonumber(data.DAMAGER) or 0,
	}
	local total = counts.TANK + counts.HEALER + counts.DAMAGER
	if total <= 0 then
		return nil
	end
	return counts, total
end

local function addUnitRoleCount(counts, unit)
	if not unit or (UnitExists and not UnitExists(unit)) then
		return false
	end
	local role = UnitGroupRolesAssigned and normalizeAssignedRole(UnitGroupRolesAssigned(unit))
	if not role and UnitIsUnit and UnitIsUnit(unit, "player") then
		role = getPlayerSpecializationRole()
	end
	role = role or "DAMAGER"
	counts[role] = (counts[role] or 0) + 1
	return true
end

local function readGroupMemberCountsFromUnits()
	local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
	local total = 0
	if IsInRaid and IsInRaid(LE_PARTY_CATEGORY_HOME) then
		local n = tonumber(GetNumGroupMembers and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)) or 0
		for index = 1, n do
			if addUnitRoleCount(counts, "raid" .. index) then
				total = total + 1
			end
		end
	elseif IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME) then
		if addUnitRoleCount(counts, "player") then
			total = total + 1
		end
		local n = tonumber(GetNumGroupMembers and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)) or 1
		for index = 1, math.max(0, n - 1) do
			if addUnitRoleCount(counts, "party" .. index) then
				total = total + 1
			end
		end
	else
		if addUnitRoleCount(counts, "player") then
			total = total + 1
		end
	end
	if total <= 0 then
		return nil
	end
	return counts, total
end

local function readGroupMemberCountsForDisplay()
	if GetGroupMemberCountsForDisplay then
		local ok, data = pcall(GetGroupMemberCountsForDisplay)
		if ok then
			local counts, total = normalizeRoleCounts(data)
			if counts then
				return counts, total
			end
		end
	end
	return readGroupMemberCountsFromUnits()
end

local function getActiveActivityInfo(activeInfo)
	if not activeInfo then
		return nil, nil
	end
	local snapshot = GF.SearchResultSnapshot
	local activityID = snapshot and snapshot.GetPrimaryActivityID and snapshot.GetPrimaryActivityID(activeInfo)
	if not activityID then
		activityID = activeInfo.activityID or (activeInfo.activityIDs and activeInfo.activityIDs[1])
	end
	if not activityID or not (C_LFGList and C_LFGList.GetActivityInfoTable) then
		return activityID, nil
	end
	local ok, activityInfo = pcall(C_LFGList.GetActivityInfoTable, activityID, activeInfo.questID, activeInfo.isWarMode)
	if ok then
		return activityID, activityInfo
	end
	return activityID, nil
end

local function getActiveRoleDisplayMode(activityInfo)
	local displayType = activityInfo and activityInfo.displayType
	local displayEnum = Enum and Enum.LFGListDisplayType
	if displayEnum then
		if displayType == displayEnum.HideAll then
			return nil
		end
		if displayType == displayEnum.RoleEnumerate or displayType == displayEnum.ClassEnumerate then
			return "enumerate_roles"
		end
		if displayType == displayEnum.RoleCount or displayType == displayEnum.PlayerCount then
			return "count"
		end
	end
	local maxPlayers = tonumber(activityInfo and activityInfo.maxNumPlayers) or 0
	if maxPlayers > 0 and maxPlayers <= 5 then
		return "enumerate_roles"
	end
	return "count"
end

local function buildActiveRoleSummaryEntry()
	if not (GF.Listing and GF.Listing.HasActive and GF.Listing:HasActive()) then
		return nil
	end
	local activeInfo = GF.Listing.GetActive and GF.Listing:GetActive()
	if not activeInfo then
		return nil
	end
	local activityID, activityInfo = getActiveActivityInfo(activeInfo)
	local mode = getActiveRoleDisplayMode(activityInfo)
	if not mode then
		return nil
	end
	local counts, total = readGroupMemberCountsForDisplay()
	if not counts then
		return nil
	end
	return {
		info = {
			numMembers = total,
			name = activeInfo.name,
			activityIDs = activityID and { activityID } or activeInfo.activityIDs,
		},
		activity = activityInfo,
		categoryID = activityInfo and activityInfo.categoryID,
		tanks = counts.TANK or 0,
		heals = counts.HEALER or 0,
		dps = counts.DAMAGER or 0,
		_displayCounts = counts,
		_displayCountsLoaded = true,
	}, mode
end

local function setHeaderRefreshButtonEnabled(button, enabled)
	if not button then
		return
	end
	enabled = enabled == true
	button:SetEnabled(enabled)
	GF.UI.SetHeaderRefreshIconState(
		button,
		enabled and BUTTON_VISUAL_STATE.NORMAL or BUTTON_VISUAL_STATE.DISABLED
	)
end

local function applyBumpButtonState(panel, canLead)
	local button = panel and panel.bumpBtn
	if not button then
		return
	end
	local listing = GF.Listing
	local remaining = listing and listing.GetBumpCooldownRemaining
		and listing:GetBumpCooldownRemaining() or 0
	local onCooldown = remaining > 0
	local busy = listing and listing.IsBumpBusy and listing:IsBumpBusy()
	local text
	if onCooldown and canLead == true then
		text = tostring(math.max(1, math.ceil(remaining)))
	else
		local L = GF.L or {}
		text = L.BUMP_LISTING or "Relist"
	end
	if button._gfBumpButtonText ~= text then
		button._gfBumpButtonText = text
		button:SetText(text)
	end
	button:SetEnabled(canLead == true and not onCooldown and not busy)
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
	local listing = GF.Listing
	local bumpBusy = listing and listing.IsBumpBusy
		and listing:IsBumpBusy()
	if panel.editBtn then
		panel.editBtn:SetEnabled(canLead and not bumpBusy)
	end
	if panel.refreshBtn then
		setHeaderRefreshButtonEnabled(panel.refreshBtn, canManage and not bumpBusy)
	end
	applyBumpButtonState(panel, canLead)
	if panel.removeBtn then
		panel.removeBtn:SetEnabled(canLead and not bumpBusy)
	end
	if panel.autoCheck then
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

function AP:UpdateBumpButtonState()
	local listing = GF.Listing
	local canLead = listing and listing.CanLeadListing and listing:CanLeadListing()
	applyBumpButtonState(self, canLead)
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
	GF.UI.SetHeaderRefreshIconState(
		self.refreshBtn,
		BUTTON_VISUAL_STATE.NORMAL,
		GF.APPLICANT_HEADER_REFRESH_BUTTON_OFFSET_Y or 0
	)
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
		GF.UI.SetHeaderRefreshIconState(btn, BUTTON_VISUAL_STATE.HOVER)
		GF.UI.BeginGameTooltip(btn, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L.REFRESH_LISTING or "刷新列表", 1, 0.82, 0, true)
		GameTooltip:AddLine(L.REFRESH_LISTING_TIP or "刷新当前招募的申请者列表", 1, 1, 1, true)
		GF.UI.ShowGameTooltip()
	end)
	self.refreshBtn:SetScript("OnMouseDown", function(btn, mouseButton)
		if mouseButton == "LeftButton" and (not btn.IsEnabled or btn:IsEnabled()) then
			GF.UI.SetHeaderRefreshIconState(btn, BUTTON_VISUAL_STATE.PRESSED)
		end
	end)
	self.refreshBtn:SetScript("OnMouseUp", function(btn)
		GF.UI.SetHeaderRefreshIconState(
			btn,
			(not btn.IsEnabled or btn:IsEnabled()) and BUTTON_VISUAL_STATE.HOVER or BUTTON_VISUAL_STATE.DISABLED
		)
	end)
	self.refreshBtn:SetScript("OnLeave", function(btn)
		GF.UI.SetHeaderRefreshIconState(
			btn,
			(not btn.IsEnabled or btn:IsEnabled()) and BUTTON_VISUAL_STATE.NORMAL or BUTTON_VISUAL_STATE.DISABLED
		)
		if GameTooltip and GameTooltip:GetOwner() == btn then
			GameTooltip:Hide()
		end
	end)
	self.refreshBtn:SetScript("OnDisable", function(btn)
		GF.UI.SetHeaderRefreshIconState(btn, BUTTON_VISUAL_STATE.DISABLED)
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

	self.editBtn = GF.UI.CreatePanelButton(self.toolbar, L.EDIT_LISTING or "Edit", MANAGE_BUTTON_W)
	self.editBtn:SetPoint("LEFT", self.toolbar, "LEFT", LEFT_PAD, controlCenterY())
	GF.UI.BindLeaderOnlyButton(self.editBtn, function()
		if GF.CreateDrawer then
			GF.CreateDrawer:Open({ mode = "edit", allowOccupiedPrompt = true })
		end
	end, nil, "aboveLeft")

	self.removeBtn = GF.UI.CreatePanelButton(self.toolbar, L.REMOVE_LISTING or "Remove", MANAGE_BUTTON_W)
	self.removeBtn:SetPoint("RIGHT", self.toolbar, "RIGHT", -RIGHT_PAD, controlCenterY())
	GF.UI.BindLeaderOnlyButton(self.removeBtn, function()
		GF.Listing:Remove()
	end, nil, "aboveLeft")

	self.bumpBtn = GF.UI.CreatePanelButton(self.toolbar, L.BUMP_LISTING or "Relist", MANAGE_BUTTON_W)
	self.bumpBtn:SetPoint("RIGHT", self.removeBtn, "LEFT", -6, 0)
	GF.UI.BindLeaderOnlyButton(self.bumpBtn, function()
		if not (GF.Listing and GF.Listing.RelistForBump) then
			return
		end
		GF.Listing:RelistForBump()
		AP:UpdateManageState()
		if GF.CreatePanel and GF.CreatePanel.UpdateManageState then
			GF.CreatePanel:UpdateManageState()
		end
		local inlinePanel = GF.MythicPlusCreateManagerPanel
		if inlinePanel and inlinePanel.IsSurfaceActive
			and inlinePanel:IsSurfaceActive()
			and inlinePanel.RefreshDungeonControlState
		then
			inlinePanel:RefreshDungeonControlState()
		end
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

	local roleSummaryParent = (GF.MainFrame and GF.MainFrame.footerHost)
		or (GF.MainFrame and GF.MainFrame.frame)
		or parent
	self.roleSummaryHost = CreateFrame("Frame", nil, roleSummaryParent)
	self.roleSummaryHost:SetSize(ROLE_SUMMARY_W, ROLE_SUMMARY_H)
	self.roleSummaryHost:SetFrameLevel((roleSummaryParent:GetFrameLevel() or parent:GetFrameLevel() or 1) + 20)
	self.roleSummaryHost:SetPoint(
		"RIGHT",
		roleSummaryParent,
		"RIGHT",
		-(GF.ACTIVITY_COUNT_RIGHT or 28) + ROLE_SUMMARY_X,
		0)
	self.roleSummaryHost:EnableMouse(false)
	if GF.RoleDisplay and GF.RoleDisplay.Create then
		self.activeRoleDisplay = GF.RoleDisplay:Create(self.roleSummaryHost)
		self.activeRoleDisplay:ClearAllPoints()
		self.activeRoleDisplay:SetPoint("CENTER", self.roleSummaryHost, "CENTER", 0, 0)
		self.activeRoleDisplay:Hide()
	end
	self.roleSummaryHost:Hide()

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

function AP:SetManagementControlsShown(shown)
	shown = shown == true
	local inlineManager = GF.MythicPlusCreateManagerPanel
	local manageFromSidebar = inlineManager
		and inlineManager.ShouldUse
		and inlineManager:ShouldUse()
		or false
	for _, frame in ipairs({
		self.editBtn,
		self.removeBtn,
		self.bumpBtn,
		self.autoCheck,
		self.autoLabel,
	}) do
		if frame then
			local sidebarOwned = frame == self.editBtn
				or frame == self.removeBtn
			frame:SetShown(shown and not (
				manageFromSidebar and sidebarOwned
			))
		end
	end
	if self.bumpBtn then
		self.bumpBtn:ClearAllPoints()
		if manageFromSidebar then
			self.bumpBtn:SetPoint(
				"RIGHT",
				self.toolbar,
				"RIGHT",
				-RIGHT_PAD,
				controlCenterY()
			)
		else
			self.bumpBtn:SetPoint("RIGHT", self.editBtn, "LEFT", -GAP, 0)
		end
	end
	if GameTooltip then
		for _, frame in ipairs({ self.editBtn, self.removeBtn, self.bumpBtn, self.autoCheck }) do
			local hiddenForSidebar = manageFromSidebar
				and (frame == self.editBtn or frame == self.removeBtn)
			if frame and (not shown or hiddenForSidebar)
				and GameTooltip:GetOwner() == frame
			then
				GameTooltip:Hide()
				return
			end
		end
	end
end

function AP:UpdateActiveRoleSummary()
	if not self.roleSummaryHost then
		return
	end
	local currentTab = GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar:GetCurrent()
	if (currentTab and currentTab ~= GF.TAB_CREATE)
		or (self.parent and not self.parent:IsShown())
		or not (GF.Listing and GF.Listing.HasActive and GF.Listing:HasActive())
	then
		self.roleSummaryHost:Hide()
		if self.activeRoleDisplay then
			self.activeRoleDisplay:Hide()
		end
		return
	end
	local entry, mode = buildActiveRoleSummaryEntry()
	if not (entry and mode and self.activeRoleDisplay and GF.RoleDisplay and GF.RoleDisplay.Update) then
		self.roleSummaryHost:Hide()
		if self.activeRoleDisplay then
			self.activeRoleDisplay:Hide()
		end
		return
	end
	self.roleSummaryHost:Show()
	GF.RoleDisplay:Update(self.activeRoleDisplay, entry, entry.categoryID, { mode = mode })
	self.activeRoleDisplay:ClearAllPoints()
	self.activeRoleDisplay:SetPoint("CENTER", self.roleSummaryHost, "CENTER", 0, 0)
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
	if not C_Timer or not C_Timer.NewTimer then
		self:Relayout()
		return
	end
	self._relayoutDebounce = C_Timer.NewTimer(0.1, function()
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
		local entryNameIsSecret = issecretvalue
			and issecretvalue(entryName)
		if not entryNameIsSecret
			and entryName
			and entryName ~= ""
		then
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
			if GF.LFGWorkspaceView and GF.LFGWorkspaceView.IsMythicPlusActive
				and GF.LFGWorkspaceView:IsMythicPlusActive() then
				local activityIDs = GF.LFGWorkspacePolicy
					and GF.LFGWorkspacePolicy.GetSeasonActivityIDs
					and GF.LFGWorkspacePolicy:GetSeasonActivityIDs() or {}
				if #activityIDs == 0 then
					prompt = L.MPLUS_LFG_SCOPE_UNAVAILABLE
						or "Level restricted: Seasonal Mythic+ mode has not been unlocked."
				else
					prompt = L.CREATE_EMPTY_PROMPT
						or L.NO_LISTING
						or "请创建集合石招募"
				end
			else
				prompt = L.CREATE_EMPTY_PROMPT or L.NO_LISTING or "请创建集合石招募"
			end
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
	self.applicantDataCache = {}
	self.applicantElementCounts = {}
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

	local elements = self:BuildApplicantElements()
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

function AP:GetApplicantDisplayData(applicantID, forceFresh)
	local key = applicantIDKey(applicantID)
	if key == "" then
		return nil
	end
	self.applicantDataCache = self.applicantDataCache or {}
	local cached = self.applicantDataCache[key]
	if cached and cached._gfSoftUnavailable and not forceFresh then
		return cached
	end
	local data = GF.ApplicantModel and GF.ApplicantModel:BuildApplicant(applicantID)
	if data then
		self.applicantDataCache[key] = data
		return data
	end
	return markApplicantDataUnavailable(self.applicantDataCache[key])
end

function AP:BuildApplicantElements()
	self.applicantElementCounts = self.applicantElementCounts or {}
	return ASL.BuildElements(self.applicantIDs, function(applicantID)
		local data = self:GetApplicantDisplayData(applicantID)
		self.applicantElementCounts[applicantIDKey(applicantID)] = applicantMemberCount(data)
		return data
	end)
end

function AP:RebuildApplicantElements(opts)
	opts = opts or {}
	if not self.scrollList then
		return
	end
	self.totalCount = #(self.applicantIDs or {})
	self:UpdateEmptyHint()
	if self.totalCount == 0 then
		self.scrollList:SetElements({})
		self:UpdateInviteState()
		return
	end
	self.scrollList:SetElements(self:BuildApplicantElements(), {
		retainScroll = opts.preserveScroll == true,
	})
	self:UpdateInviteState()
end

function AP:OnLaonongFanSourceChanged(revision)
	if self._laonongFanRevision == revision then
		return
	end
	self._laonongFanRevision = revision
	self.applicantDataCache = {}
	self.applicantElementCounts = {}
	if not self.scrollList or not self.parent then
		return
	end
	if self.parent.IsVisible and not self.parent:IsVisible() then
		return
	end
	if not self.parent.IsVisible and self.parent.IsShown and not self.parent:IsShown() then
		return
	end
	self:RebuildApplicantElements({ preserveScroll = true })
end

function AP:RefreshApplicant(applicantID, forceFresh)
	if not self.scrollList or not applicantID then
		return
	end
	local data = self:GetApplicantDisplayData(applicantID, forceFresh)
	if not data then
		return false
	end
	local key = applicantIDKey(applicantID)
	local previousCount = self.applicantElementCounts and self.applicantElementCounts[key]
	if previousCount and previousCount ~= applicantMemberCount(data) then
		return false
	end
	local width = self.scrollList:GetLayoutWidth()
	local updated = false
	self:ForEachVisibleRow(function(card)
		if card and applicantIDKey(card.applicantID) == key and card:IsShown() then
			GF.ApplicantCard:SetData(card, data, width, card._elementData)
			updated = true
		end
	end)
	if not updated then
		return false
	end
	self.applicantElementCounts = self.applicantElementCounts or {}
	self.applicantElementCounts[key] = applicantMemberCount(data)
	self:UpdateInviteState()
	return true
end

function AP:DismissSoftUnavailableApplicant(applicantID)
	local key = applicantIDKey(applicantID)
	local cached = self.applicantDataCache and self.applicantDataCache[key]
	if not (cached and cached._gfSoftUnavailable) then
		return false
	end
	local nextIDs = {}
	for _, id in ipairs(self.applicantIDs or {}) do
		if applicantIDKey(id) ~= key then
			nextIDs[#nextIDs + 1] = id
		end
	end
	self.applicantIDs = nextIDs
	if self.selectedApplicantRowKey and selectedApplicantIDFromKey(self.selectedApplicantRowKey) == key then
		self.selectedApplicantRowKey = nil
	end
	if self.applicantDataCache then
		self.applicantDataCache[key] = nil
	end
	if self.applicantElementCounts then
		self.applicantElementCounts[key] = nil
	end
	self:RebuildApplicantElements({ preserveScroll = true })
	return true
end

function AP:DismissSoftUnavailableApplicantRow(row)
	return row and row.applicantID and self:DismissSoftUnavailableApplicant(row.applicantID) or false
end

function AP:OnApplicantUpdated(applicantID)
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	self:UpdateManageState()
	if not applicantID then
		return
	end
	if not applicantIDInList(self.applicantIDs, applicantID) then
		local data = self:GetApplicantDisplayData(applicantID, true)
		if not data then
			return
		end
		self.applicantIDs = self.applicantIDs or {}
		self.applicantIDs[#self.applicantIDs + 1] = applicantID
		self:RebuildApplicantElements({ preserveScroll = true })
		return
	end
	if not self:RefreshApplicant(applicantID, true) then
		local data = self:GetApplicantDisplayData(applicantID, true)
		local key = applicantIDKey(applicantID)
		local previousCount = self.applicantElementCounts and self.applicantElementCounts[key]
		if data and previousCount and previousCount ~= applicantMemberCount(data) then
			self:RebuildApplicantElements({ preserveScroll = true })
		else
			self:UpdateInviteState()
		end
	end
end

function AP:OnApplicantListUpdated()
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	self:UpdateManageState()
	if not self.scrollList then
		return
	end
	self.applicantIDs = self.applicantIDs or {}
	self.applicantDataCache = self.applicantDataCache or {}
	local currentIDs = GF.ApplicantModel:GetSortedApplicantIDs()
	local currentSet = applicantIDSet(currentIDs)
	local previousSet = applicantIDSet(self.applicantIDs)
	local nextIDs = {}
	local needsRebuild = false
	for _, applicantID in ipairs(self.applicantIDs) do
		local key = applicantIDKey(applicantID)
		if currentSet[key] then
			nextIDs[#nextIDs + 1] = applicantID
			local data = self:GetApplicantDisplayData(applicantID, true)
			local previousCount = self.applicantElementCounts and self.applicantElementCounts[key]
			if data and previousCount and previousCount ~= applicantMemberCount(data) then
				needsRebuild = true
			else
				self:RefreshApplicant(applicantID, true)
			end
		elseif self.applicantDataCache[key] then
			nextIDs[#nextIDs + 1] = applicantID
			markApplicantDataUnavailable(self.applicantDataCache[key])
			self:RefreshApplicant(applicantID)
		else
			needsRebuild = true
		end
	end
	for _, applicantID in ipairs(currentIDs) do
		if not previousSet[applicantIDKey(applicantID)] then
			nextIDs[#nextIDs + 1] = applicantID
			self:GetApplicantDisplayData(applicantID, true)
			needsRebuild = true
		end
	end
	local previousVisibleCount = #(self.applicantIDs or {})
	self.applicantIDs = nextIDs
	self.totalCount = #nextIDs
	if self.selectedApplicantRowKey
		and not applicantIDInList(self.applicantIDs, selectedApplicantIDFromKey(self.selectedApplicantRowKey))
	then
		self.selectedApplicantRowKey = nil
	end
	self:UpdateEmptyHint()
	if needsRebuild or previousVisibleCount ~= #nextIDs then
		self:RebuildApplicantElements({ preserveScroll = true })
	else
		self:UpdateInviteState()
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
	if GF.UI and GF.UI.ApplyEmptyPromptFont then
		GF.UI.ApplyEmptyPromptFont(self.empty, "GameFontHighlight")
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
		icon:SetTexture(GF.BROWSE_LOADING_TEAMUP_TEXTURE or GF.TEAMUP_TEXTURE)
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
	local listing = GF.Listing
	local relisting = listing and listing.IsBumpRelisting and listing:IsBumpRelisting()
	local listed = (listing and listing.HasActive and listing:HasActive()) or relisting
	local canManage = listing and listing.CanManageEntry and listing:CanManageEntry()
	if relisting and not canManage then
		canManage = listing and listing.CanLeadListing and listing:CanLeadListing()
	end
	self:SetBottomControlsShown(listed == true and canManage == true)
	self:SetHeaderRefreshButtonShown(listed == true and canManage == true)
	self:SetManagementControlsShown(canManage == true)
	if not relisting then
		self:UpdateActiveRoleSummary()
	end
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
	local relisting = listing and listing.IsBumpRelisting and listing:IsBumpRelisting()
	local listed = (listing and listing.HasActive and listing:HasActive()) or relisting
	local effectiveCanManage = canManage or (relisting and canLead)
	self:SetBottomControlsShown(listed == true and effectiveCanManage == true)
	self:SetHeaderRefreshButtonShown(listed == true and effectiveCanManage == true)
	self:SetManagementControlsShown(effectiveCanManage == true)
	applyManageState(self, canLead, effectiveCanManage)
	if relisting then
		return
	end
	self:UpdateActiveRoleSummary()
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
	if GF.Listing and GF.Listing.IsBumpRelisting and GF.Listing:IsBumpRelisting() then
		return
	end
	if GF.Listing and GF.Listing.RefreshApplicants then
		GF.Listing:RefreshApplicants()
	end
	self:Refresh()
end

function AP:Hide()
	if self.parent then
		self.parent:Hide()
	end
	if self.roleSummaryHost then
		self.roleSummaryHost:Hide()
	end
	if self.activeRoleDisplay then
		self.activeRoleDisplay:Hide()
	end
end
