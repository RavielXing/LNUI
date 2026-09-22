local _, GF = ...

local ApplicantsPanel = {}
GF.ApplicantsPanel = ApplicantsPanel
local AP = ApplicantsPanel
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

local RosterPresenter = GF.ApplicantRosterPresenter
if RosterPresenter and type(RosterPresenter.Attach) == "function" then
	RosterPresenter.Attach(AP)
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
	local service = GF.SpecializationInfo
	if not (service and type(service.GetCurrentSnapshot) == "function") then
		return nil
	end
	local ok, snapshot = pcall(service.GetCurrentSnapshot)
	if not ok or type(snapshot) ~= "table" then
		return nil
	end
	return normalizeAssignedRole(snapshot.specRole)
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
	if not activityID then
		return activityID, nil
	end
	local presenter = GF.ApplicantRosterPresenter
	local activityInfo = presenter
		and type(presenter.GetActiveActivityInfo) == "function"
		and presenter.GetActiveActivityInfo(activeInfo, activityID) or nil
	return activityID, activityInfo
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

local function buildActiveRoleSummarySnapshot()
	if not (GF.RecruitmentSession and GF.RecruitmentSession.HasActive and GF.RecruitmentSession:HasActive()) then
		return nil
	end
	local activeInfo = GF.RecruitmentSession.GetActive and GF.RecruitmentSession:GetActive()
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
		},
		counts = {
			TANK = counts.TANK or 0,
			HEALER = counts.HEALER or 0,
			DAMAGER = counts.DAMAGER or 0,
		},
		mode = mode,
		memberDisplayMode = type(GF.GetMemberDisplayMode) == "function"
			and GF.GetMemberDisplayMode() or nil,
	}, activityInfo and activityInfo.categoryID
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
	local listing = GF.RecruitmentSession
	local remaining = listing and listing.GetRelistCooldownRemaining
		and listing:GetRelistCooldownRemaining() or 0
	local onCooldown = remaining > 0
	local busy = listing and listing.IsBusy and listing:IsBusy()
	local safeRelistUnavailable = listing
		and listing.HasSafeRelistSubmission
		and listing:HasSafeRelistSubmission() ~= true
	local censorState = listing and listing.GetActiveCensoredPresentationState
		and listing:GetActiveCensoredPresentationState()
	local censorBlocked = censorState and (
		censorState.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
		or censorState.state == listing.ACTIVE_CENSOR_STATE_UNKNOWN
	)
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
	button:SetEnabled(canLead == true and not onCooldown and not busy
		and not censorBlocked and not safeRelistUnavailable)
end

local AUTO_INVITE_CONTROL_MODE_PLUGIN = "plugin_auto_invite"

local function resolveAutoInviteControlState()
	local listing = GF.RecruitmentSession
	local presentation = listing and listing.GetActiveCensoredPresentationState
		and listing:GetActiveCensoredPresentationState()
	if presentation and presentation.preview == true then
		return {
			mode = AUTO_INVITE_CONTROL_MODE_PLUGIN,
			checked = false,
			canToggle = false,
			disabledReason = "preview",
		}
	end
	if listing and type(listing.GetActiveAutoAcceptControlState) == "function" then
		local nativeState = listing:GetActiveAutoAcceptControlState()
		if type(nativeState) == "table" then
			return nativeState
		end
	end
	local scheduler = GF.InvitationScheduler
	local isTaskAutoInvite = listing ~= nil
		and type(listing.IsActiveQuestListing) == "function"
		and listing:IsActiveQuestListing() == true
		and type(listing.CanPluginOwnAutoInvite) == "function"
		and listing:CanPluginOwnAutoInvite() == true
	local checked = scheduler ~= nil
		and type(scheduler.IsEnabled) == "function"
		and scheduler:IsEnabled() == true
	return {
		mode = AUTO_INVITE_CONTROL_MODE_PLUGIN,
		checked = checked,
		isTaskAutoInvite = isTaskAutoInvite,
		canToggle = not isTaskAutoInvite and scheduler ~= nil
			and type(scheduler.CanToggle) == "function"
			and scheduler:CanToggle() == true,
	}
end

local function applyAutoInviteState(panel)
	local check = panel.autoCheck
	if not check then
		return
	end
	local state = resolveAutoInviteControlState()
	local canToggle = state.canToggle == true
	local taskAutomatic = state.isTaskAutoInvite == true
		and state.checked == true
	check:SetEnabled(true)
	if GF.UI and GF.UI.SetFilterCheckButtonVisualEnabled then
		GF.UI.SetFilterCheckButtonVisualEnabled(
			check, canToggle or taskAutomatic)
	elseif check.SetDesaturated then
		check:SetDesaturated(not (canToggle or taskAutomatic))
	end
	local label = panel.autoLabel
	if label then
		local r, g, b = 0.5, 0.5, 0.5
		if canToggle or taskAutomatic then
			r, g, b = 1, 0.82, 0
		end
		label:SetTextColor(r, g, b)
	end
	check:SetChecked(state.checked == true)
end

local function applyManageState(panel, canLead, canManage)
	local listing = GF.RecruitmentSession
	local bumpBusy = listing and listing.IsBusy
		and listing:IsBusy()
	local presentation = listing and listing.GetActiveCensoredPresentationState
		and listing:GetActiveCensoredPresentationState()
	local preview = presentation and presentation.preview == true
	if panel.editBtn then
		local pending = presentation and listing
			and presentation.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
		local L = GF.L or {}
		local text = pending
			and (L.CENSORED_ACTIVE_ENTRY_HANDLE or "Resolve")
			or (L.EDIT_LISTING or "Edit")
		if panel.editBtn._gfListingButtonText ~= text then
			panel.editBtn._gfListingButtonText = text
			panel.editBtn:SetText(text)
		end
		panel.editBtn:SetEnabled(canLead and not bumpBusy)
	end
	if panel.refreshBtn then
		local actions = GF.ApplicantActionService
		local canRefresh = actions and actions.CanRefresh
			and actions:CanRefresh() == true
		setHeaderRefreshButtonEnabled(panel.refreshBtn,
			canRefresh and not bumpBusy and not preview)
	end
	applyBumpButtonState(panel, canLead)
	if panel.removeBtn then
		panel.removeBtn:SetEnabled(canLead and not bumpBusy and not preview)
	end
	applyAutoInviteState(panel)
end

function AP:UpdateBumpButtonState()
	local listing = GF.RecruitmentSession
	local canLead = listing and listing.CanPublish and listing:CanPublish()
	applyBumpButtonState(self, canLead)
end


local function requestListingBump()
	local listing = GF.RecruitmentSession
	if not (listing and listing.Relist) then
		return
	end
	listing:Relist()
	AP:UpdateManageState()
	local createPanel = GF.CreatePanel
	if createPanel and createPanel.UpdateManageState then
		createPanel:UpdateManageState()
	end
	local inlinePanel = GF.MythicPlusCreateManagerPanel
	local isInlineActive = inlinePanel
		and inlinePanel.IsSurfaceActive
		and inlinePanel:IsSurfaceActive()
	if isInlineActive and inlinePanel.RefreshDungeonControlState then
		inlinePanel:RefreshDungeonControlState()
	end
end

local function showListingBumpTooltip(button)
	GF.UI.BeginGameTooltipAbove(button, "LEFT")
	local L = GF.L or {}
	local listing = GF.RecruitmentSession
	local state = listing and listing.GetActiveCensoredPresentationState
		and listing:GetActiveCensoredPresentationState()
	local blocked = state and (
		state.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
		or state.state == listing.ACTIVE_CENSOR_STATE_UNKNOWN
	)
	local safeRelistUnavailable = listing
		and listing.HasSafeRelistSubmission
		and listing:HasSafeRelistSubmission() ~= true
	GF.UI.SetTooltipText(blocked
		and (L.CENSORED_ACTIVE_ENTRY_BUMP_BLOCKED_TOOLTIP
			or "This group is pending Blizzard review and cannot be relisted yet.")
		or safeRelistUnavailable
		and (L.BUMP_LISTING_SAFE_SNAPSHOT_UNAVAILABLE_TOOLTIP
			or "This listing has no safe relist snapshot. Recreate it with GroupFinder first.")
		or (L.BUMP_LISTING_TIP or ""))
	GF.UI.ShowGameTooltip()
end

local function toggleAutoInvite(button)
	local state = resolveAutoInviteControlState()
	local listing = GF.RecruitmentSession
	local scheduler = GF.InvitationScheduler
	if state.mode == (listing and listing.AUTO_ACCEPT_CONTROL_MODE_NATIVE_QUEST) then
		-- Native quest auto-accept is an authoritative, read-only projection.
		-- Keep the CheckButton mouse-enabled for its tooltip, but never use it to
		-- transfer ownership or submit a restricted listing update.
		button:SetChecked(state.checked == true)
		return
	end
	if state.canToggle then
		local accepted = scheduler and scheduler.SetEnabled
			and scheduler:SetEnabled(button:GetChecked())
		if accepted ~= true then
			button:SetChecked(state.checked == true)
		end
		return
	end
	button:SetChecked(state.checked == true)
	if state.isTaskAutoInvite == true and state.checked == true then
		local locale = GF.L or {}
		if type(GF.ShowWarningMessage) == "function" then
			GF.ShowWarningMessage(locale.AUTO_ACCEPT_TASK_LOCKED_NOTICE
				or "Auto Invite cannot be disabled in quest group mode")
		end
		return
	end
	if state.disabledReason == "unempowered"
		and listing and listing.NotifyLeaderOnly
	then
		listing:NotifyLeaderOnly()
	elseif state.mode == AUTO_INVITE_CONTROL_MODE_PLUGIN
		and listing and listing.NotifyLeaderOnly
	then
		listing:NotifyLeaderOnly()
	end
end

local function hideGameTooltip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

local function onApplicantListSizeChanged(box, width, height)
	local dynamic = AP.scrollList and AP.scrollList.dynamicScrollBar
	if dynamic and dynamic.applying then return end
	if AP._frameResizing or (AP.parent and not AP.parent:IsShown()) then
		return
	end
	width = width or box:GetWidth()
	height = height or box:GetHeight()
	if not (width and height and width > 0 and height > 0) then
		return
	end
	if AP._scrollLastW == width and AP._scrollLastH == height then
		return
	end
	AP._scrollLastW, AP._scrollLastH = width, height
	AP:ScheduleRelayout()
end

function AP:Init(parent)
	local scrollAPI = GF.UI and GF.UI.ScrollList
	if self.scrollList or not (scrollAPI and scrollAPI.IsAvailable()) then
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
	local refreshTexCoord = GF.REFRESH_TEXTURE_TEXCOORD
	if refreshTexCoord then
		refreshIcon:SetTexCoord(
			refreshTexCoord[1],
			refreshTexCoord[2],
			refreshTexCoord[3],
			refreshTexCoord[4])
	else
		refreshIcon:SetTexCoord(0, 1, 0, 1)
	end
	self.refreshBtn.Icon = refreshIcon
	GF.UI.InstallHeaderRefreshIconHoverGlow(self.refreshBtn)
	GF.UI.SetHeaderRefreshIconState(
		self.refreshBtn,
		BUTTON_VISUAL_STATE.NORMAL,
		GF.APPLICANT_HEADER_REFRESH_BUTTON_OFFSET_Y or 0
	)
	self.refreshBtn:SetScript("OnClick", function()
		local actions = GF.ApplicantActionService
		if not (actions and actions.CanRefresh and actions:CanRefresh())
		then
			return
		end
		local refreshed = actions.Refresh and actions:Refresh() == true
		if not refreshed then
			return
		end
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		if AP.Refresh then
			AP:Refresh({ preserveScroll = true })
		end
	end)
	self.refreshBtn:HookScript("OnEnter", function(btn)
		local locale = GF.L or {}
		GF.UI.BeginGameTooltip(btn, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(
			locale.REFRESH_LISTING or "刷新列表", 1, 0.82, 0, true)
		GameTooltip:AddLine(
			locale.REFRESH_LISTING_TIP
				or "刷新当前招募的申请者列表",
			1, 1, 1, true)
		GF.UI.ShowGameTooltip()
	end)
	self.refreshBtn:HookScript("OnLeave", function(btn)
		if GameTooltip and GameTooltip:GetOwner() == btn then
			GameTooltip:Hide()
		end
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
	GF.UI.AttachActionGuard(self.editBtn, {
		capability = "listing_leader",
		tooltipPlacement = "aboveLeft",
		onClick = function()
			local listing = GF.RecruitmentSession
			local state = listing and listing.GetActiveCensoredPresentationState
				and listing:GetActiveCensoredPresentationState()
			if state and state.state == listing.ACTIVE_CENSOR_STATE_UNKNOWN
				and state.preview ~= true
			then
				if GF.ShowWarningMessage then
					GF.ShowWarningMessage((GF.L or {}).CENSORED_ACTIVE_ENTRY_UNKNOWN
						or "The pending state cannot be confirmed yet")
				end
				return
			end
			if state and (
				state.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
				or state.state == listing.ACTIVE_CENSOR_STATE_UNKNOWN
			) then
				if GF.CensoredActiveEntryDialog then
					GF.CensoredActiveEntryDialog:Show()
				end
				return
			end
			if GF.CreateDrawer then
				GF.CreateDrawer:Open({ mode = "edit", allowOccupiedPrompt = true })
			end
		end,
	})

	self.removeBtn = GF.UI.CreatePanelButton(self.toolbar, L.REMOVE_LISTING or "Remove", MANAGE_BUTTON_W)
	self.removeBtn:SetPoint("RIGHT", self.toolbar, "RIGHT", -RIGHT_PAD, controlCenterY())
	GF.UI.AttachActionGuard(self.removeBtn, {
		capability = "listing_leader",
		tooltipPlacement = "aboveLeft",
		onClick = function()
			GF.RecruitmentSession:Remove()
		end,
	})

	local bumpButton = GF.UI.CreatePanelButton(self.toolbar, L.BUMP_LISTING or "Relist", MANAGE_BUTTON_W)
	bumpButton:SetPoint("RIGHT", self.removeBtn, "LEFT", -6, 0)
	self.bumpBtn = bumpButton
	GF.UI.AttachActionGuard(bumpButton, {
		capability = "listing_leader",
		tooltipPlacement = "aboveLeft",
		onClick = requestListingBump,
		onAllowedHover = showListingBumpTooltip,
	})

	local autoCheck = CreateFrame("CheckButton", nil, self.toolbar, "UICheckButtonTemplate")
	local autoCheckSize = GF.SUBTITLE_OPTION_CHECK_SIZE or 20
	autoCheck:SetSize(autoCheckSize, autoCheckSize)
	autoCheck:SetPoint("LEFT", self.toolbar, "LEFT", LEFT_PAD, controlCenterY())
	self.autoCheck = autoCheck
	local autoLabel = GF.UI.CreateFontString(self.toolbar, "OVERLAY", "GameFontNormal")
	autoLabel:SetText(L.AUTO_ACCEPT or "Auto invite")
	autoLabel:SetPoint("LEFT", autoCheck, "RIGHT", GF.SUBTITLE_OPTION_TEXT_GAP or 1, 0)
	self.autoLabel = autoLabel
	autoCheck:SetScript("OnClick", toggleAutoInvite)
	autoCheck:SetScript("OnEnter", function()
		AP:ShowAutoAcceptTooltip()
	end)
	autoCheck:SetScript("OnLeave", hideGameTooltip)
	if GF.UI and GF.UI.StyleFilterCheckButton then
		GF.UI.StyleFilterCheckButton(autoCheck, { size = autoCheckSize })
	end

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
			AP:RefreshList({ forceFull = true, preserveScroll = true })
			AP:LayoutColumnHeaders()
		end,
		onLayoutChange = function()
			if AP.RelayoutRows then
				AP:RelayoutRows()
			end
		end,
		onSizeChanged = function()
			AP:AnchorHeaderRefreshButton()
			if AP.RelayoutVisibleRows then
				AP:RelayoutVisibleRows()
			end
		end,
	})
	self.columnHeaderBar:SetPoint("TOPLEFT", self.columnHeaderHost, "TOPLEFT", 0, GF.BROWSE_HEADER_CONTENT_OFFSET_Y or 4)
	self.columnHeaderBar:SetPoint("BOTTOMRIGHT", self.columnHeaderHost, "BOTTOMRIGHT", 0, GF.BROWSE_HEADER_CONTENT_OFFSET_Y or 4)

	self.listBody = CreateFrame("Frame", nil, parent)
	self.listBody:SetPoint("TOPLEFT", self.columnHeaderHost, "BOTTOMLEFT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 0))
	-- Keep the header's refresh-button reserve out of the list/bar geometry.
	self.listBody:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
	self.listBody:SetFrameLevel(parent:GetFrameLevel() + 2)

	self.scrollList = ASL.Create(self, self.listBody, { barParent = parent })
	local scrollBox = self.scrollList:GetScrollBox()
	scrollBox:SetPoint("TOPLEFT", self.listBody, "TOPLEFT", 0, 0)
	scrollBox:SetPoint("BOTTOMRIGHT", self.listBody, "BOTTOMRIGHT", 0, GF.CONTENT_SCROLL_INSET_B or 0)

	self._scrollLastW = 0
	self._scrollLastH = 0
	scrollBox:HookScript("OnSizeChanged", onApplicantListSizeChanged)
	self.scrollList:BindDynamicContentScrollBar(self.listBody, function(width)
		GF.ColumnHeaderBar:Layout(self.columnHeaderBar, width)
		self:AnchorHeaderRefreshButton()
		self:RelayoutVisibleRows()
	end, { reserveGutter = true })

	local emptyPrompt = GF.UI.CreateFontString(self.listBody, "OVERLAY", "GameFontHighlight")
	emptyPrompt:SetPoint("CENTER", scrollBox, "CENTER")
	emptyPrompt:SetJustifyH("CENTER")
	emptyPrompt:SetWordWrap(true)
	emptyPrompt:SetText(L.NO_APPLICANTS or "")
	self.empty = emptyPrompt
	self:ApplyEmptyPromptStyle()
	emptyPrompt:Hide()
	self.emptyAnchor = scrollBox

	self.applicantIDs = {}
	self.totalCount = 0
	self:SetBottomControlsShown(false)
	self:SetHeaderRefreshButtonShown(false)
end

local function anchorListBodyBelowHeader(panel)
	if not (panel and panel.listBody and panel.columnHeaderHost) then
		return
	end
	panel.listBody:ClearAllPoints()
	panel.listBody:SetPoint("TOPLEFT", panel.columnHeaderHost, "BOTTOMLEFT", 0,
		-(GF.BROWSE_HEADER_LIST_GAP or 0))
	if panel.footer and panel.footer:IsShown() then
		panel.listBody:SetPoint("BOTTOMRIGHT", panel.footer, "TOPRIGHT", 0,
			GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
	elseif panel.parent then
		panel.listBody:SetPoint("BOTTOMRIGHT", panel.parent, "BOTTOMRIGHT", 0, 0)
	end
end

function AP:LayoutColumnHeaders(layoutWidth)
	local host = self.columnHeaderHost
	if not (host and host:IsShown()) then
		return
	end
	local resolvedWidth = layoutWidth
	if resolvedWidth == nil and GF.GetApplicantListLayoutWidth then
		resolvedWidth = GF.GetApplicantListLayoutWidth()
	end
	GF.ColumnHeaderBar:LayoutHost(host, self.columnHeaderBar, resolvedWidth)
	self:AnchorHeaderRefreshButton()
	self:ScheduleHeaderRefreshButtonAnchor()
end

function AP:OnLaonongFanSourceChanged()
	if not (self.IsPresentationVisible and self:IsPresentationVisible()) then return end
	self:ForEachVisibleRow(function(card)
		for _, member in ipairs(card.members or {}) do
			if member._layoutMemberData then
				GF.ApplicantMemberBlock:RefreshType(member, member._layoutMemberData)
			end
		end
	end)
end

function AP:RefreshLocale()
	local L = GF.L or {}
	if self.removeBtn then
		self.removeBtn:SetText(L.REMOVE_LISTING or "Remove")
	end
	if self.autoLabel then
		self.autoLabel:SetText(L.AUTO_ACCEPT or "Auto invite")
	end
	-- The edit/relist captions have state-dependent variants and their helpers
	-- deduplicate writes. Drop only the old-language memoized values before the
	-- ordinary management projection recomputes them.
	if self.editBtn then
		self.editBtn._gfListingButtonText = nil
	end
	if self.bumpBtn then
		self.bumpBtn._gfBumpButtonText = nil
	end
	if self.columnHeaderBar and GF.ColumnHeaderBar
		and GF.ColumnHeaderBar.RefreshLocale
	then
		GF.ColumnHeaderBar:RefreshLocale(self.columnHeaderBar)
	end
	self:UpdateManageState()
	self:UpdateEmptyHint()
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

function AP:UpdateFromActiveRoleSummary()
	if not self.roleSummaryHost then
		return
	end
	local currentTab = GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar:GetCurrent()
	if (currentTab and currentTab ~= GF.TAB_CREATE)
		or (self.parent and not self.parent:IsShown())
		or not (GF.RecruitmentSession and GF.RecruitmentSession.HasActive and GF.RecruitmentSession:HasActive())
	then
		self.roleSummaryHost:Hide()
		if self.activeRoleDisplay then
			self.activeRoleDisplay:Hide()
		end
		return
	end
	local snapshot, categoryID = buildActiveRoleSummarySnapshot()
	if not (snapshot and self.activeRoleDisplay and GF.RoleDisplay and GF.RoleDisplay.Update) then
		self.roleSummaryHost:Hide()
		if self.activeRoleDisplay then
			self.activeRoleDisplay:Hide()
		end
		return
	end
	self.roleSummaryHost:Show()
	GF.RoleDisplay:Update(self.activeRoleDisplay, snapshot, categoryID)
	self.activeRoleDisplay:ClearAllPoints()
	self.activeRoleDisplay:SetPoint("CENTER", self.roleSummaryHost, "CENTER", 0, 0)
end

function AP:RefreshScrollViewport()
	local list = self.scrollList
	local retain = list and list.dataProvider and list.RetainScrollPosition
	if retain then
		retain(list)
	end
end

function AP:UpdateScrollWidth()
	self:RefreshScrollViewport()
end

function AP:CancelRelayoutDebounce()
	local pending = self._relayoutDebounce
	self._relayoutDebounce = nil
	if pending and pending.Cancel then
		pending:Cancel()
	end
end

function AP:ScheduleRelayout()
	if self._relayoutDebounce then
		return
	end
	local newTimer = C_Timer and C_Timer.NewTimer
	if not newTimer then
		self:Relayout()
		return
	end
	self._relayoutDebounce = newTimer(0.1, function()
		self._relayoutDebounce = nil
		self:Relayout()
	end)
end

function AP:RefreshLayoutIfReady(attempt)
	GF.UI.RefreshListLayoutIfReady(self, attempt)
end

function AP:GetRelayoutSig()
	local widthGetter = GF.GetApplicantListLayoutWidth
	local width = widthGetter and widthGetter() or 0
	local columns = GF.ListColumns
	if columns and columns.GetRelayoutSig then
		return columns:GetRelayoutSig(width, "applicant")
	end
	return nil
end

local function panelIsVisible(panel)
	return not panel.parent or panel.parent:IsShown()
end

local function panelCanRelayout(panel)
	return not panel._frameResizing
		and not GF._frameResizing
		and panelIsVisible(panel)
end

local function applyApplicantRelayoutPipeline(panel)
	panel:LayoutColumnHeaders()
	panel:RelayoutVisibleRows()
	panel:RefreshScrollViewport()
	GF.UI.CommitRelayoutSig(panel)
end

function AP:RelayoutVisibleRows()
	if not self.scrollList or not panelIsVisible(self) then
		return false
	end
	if not (ASL and ASL.RelayoutVisible) then
		return false
	end
	-- The header has already resolved the current applicant-list width.
	-- Project it into existing cards without retaining the viewport or
	-- committing an intermediate signature for every resize event.
	ASL.RelayoutVisible(self)
	return true
end

function AP:RelayoutRows()
	if not panelCanRelayout(self) then
		return
	end
	self:CancelRelayoutDebounce()
	applyApplicantRelayoutPipeline(self)
end

function AP:Relayout(opts)
	local options = type(opts) == "table" and opts or {}
	if not self.scrollList or not panelIsVisible(self) then
		return
	end
	self:CancelRelayoutDebounce()
	local nextSignature = self:GetRelayoutSig()
	local unchanged = nextSignature ~= nil and nextSignature == self._relayoutSig
	if options.force ~= true and unchanged then
		self:RefreshScrollViewport()
		return
	end
	local columns = GF.ListColumns
	if columns and columns.InvalidateCache then
		columns:InvalidateCache()
	end
	self:RelayoutRows()
end


local function getActiveRecruitingPrompt(L)
	local title = GF.RecruitmentSession and GF.RecruitmentSession.GetActiveActivityTitle and GF.RecruitmentSession:GetActiveActivityTitle()
	if title and title ~= "" then
		local entryName = GF.RecruitmentSession and GF.RecruitmentSession.GetActiveEntryName and GF.RecruitmentSession:GetActiveEntryName()
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
	local canLead = GF.RecruitmentSession and GF.RecruitmentSession.CanPublish and GF.RecruitmentSession:CanPublish()
	local listed = GF.RecruitmentSession
		and GF.RecruitmentSession.HasActivePresentation
		and GF.RecruitmentSession:HasActivePresentation()
	if listed == nil then
		listed = GF.RecruitmentSession and GF.RecruitmentSession:HasActive()
	end
	local hasTestApplicants = GF.ApplicantTestData
		and GF.ApplicantTestData.IsEnabled
		and GF.ApplicantTestData:IsEnabled()
	if not listed and not hasTestApplicants then
		local premadeBlockMessage = GF.Availability
			and GF.Availability.GetPremadeBlockMessage
			and GF.Availability:GetPremadeBlockMessage()
		local policy = GF.RecruitmentDraftPolicy
		local queueMessage = not premadeBlockMessage and policy
			and policy.GetActiveQueueMessage and policy:GetActiveQueueMessage()
		local prompt
		if premadeBlockMessage then
			prompt = premadeBlockMessage
		elseif queueMessage then
			prompt = queueMessage
		elseif canLead then
			if GF.LFGWorkspaceView and GF.LFGWorkspaceView.IsMythicPlusActive
				and GF.LFGWorkspaceView:IsMythicPlusActive() then
				local activityIDs = GF.LFGWorkspacePolicy
					and GF.LFGWorkspacePolicy.GetSeasonActivityIDs
					and GF.LFGWorkspacePolicy:GetSeasonActivityIDs() or {}
				if #activityIDs == 0 then
					prompt = GF.LFGWorkspacePolicy.GetSeasonUnavailableMessage
						and GF.LFGWorkspacePolicy:GetSeasonUnavailableMessage(L)
						or L.MPLUS_LFG_SCOPE_UNAVAILABLE
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


function AP:ShowAutoAcceptTooltip()
	local owner = self.autoCheck
	if not (owner and GameTooltip) then
		return
	end
	local locale = GF.L or {}
	local listing = GF.RecruitmentSession
	local state = resolveAutoInviteControlState()
	local nativeMode = state.mode == (listing
		and listing.AUTO_ACCEPT_CONTROL_MODE_NATIVE_QUEST)
	local tooltipText
	if nativeMode and state.checked == true then
		tooltipText = locale.AUTO_ACCEPT_NATIVE_TIP_ON
	elseif nativeMode then
		tooltipText = locale.AUTO_ACCEPT_NATIVE_TIP_DISABLED
	elseif state.isTaskAutoInvite == true and state.checked == true then
		tooltipText = locale.AUTO_ACCEPT_TASK_TIP
	elseif state.canToggle ~= true then
		local messageGetter = listing and listing.GetLeaderOnlyMessage
		tooltipText = messageGetter and messageGetter(listing)
			or locale.AUTO_ACCEPT_TIP_DISABLED
	elseif state.checked == true then
		tooltipText = locale.AUTO_ACCEPT_TIP_ON
	else
		tooltipText = locale.AUTO_ACCEPT_TIP
	end
	if not tooltipText or tooltipText == "" then
		return
	end
	GF.UI.BeginGameTooltipAbove(owner, "LEFT")
	GF.UI.SetTooltipText(tooltipText)
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
	self.empty:SetPoint("LEFT", anchor, "LEFT", 16, offsetY)
	self.empty:SetPoint("RIGHT", anchor, "RIGHT", -16, offsetY)
end

function AP:EnsureLoadingAnimation()
	if self.loadingAnimation then
		return self.loadingAnimation
	end
	local parent = self.emptyAnchor or (self.scrollList and self.scrollList.GetScrollBox and self.scrollList:GetScrollBox())
	if not parent then
		return nil
	end
	local frame = GF.UI.CreateTeamUpLoadingAnimation(parent)
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
	anchorListBodyBelowHeader(self)
	if GF.CreateDrawer and GF.CreateDrawer.Layout then
		GF.CreateDrawer:Layout()
	end
end

local function readToolbarManagementLifecycle()
	local listing = GF.RecruitmentSession
	local presentation = listing and listing.GetActiveCensoredPresentationState
		and listing:GetActiveCensoredPresentationState()
	local preview = presentation and presentation.preview == true
	local relisting = listing and listing.IsRelisting and listing:IsRelisting()
	local listed = (listing and listing.HasActive and listing:HasActive())
		or relisting or preview
	local hasManagementAccess = listing and listing.CanManageApplicants and listing:CanManageApplicants()
	hasManagementAccess = hasManagementAccess or preview
	if relisting and not hasManagementAccess then
		hasManagementAccess = listing and listing.CanPublish and listing:CanPublish()
	end
	return relisting, listed, hasManagementAccess
end

local function readCurrentManagementLifecycle()
	local listing = GF.RecruitmentSession
	local presentation = listing and listing.GetActiveCensoredPresentationState
		and listing:GetActiveCensoredPresentationState()
	local preview = presentation and presentation.preview == true
	local canLead = listing ~= nil
		and listing.CanPublish ~= nil
		and listing:CanPublish() == true
	canLead = canLead or preview
	local canManage = listing ~= nil
		and listing.CanManageApplicants ~= nil
		and listing:CanManageApplicants() == true
	local relisting = listing ~= nil
		and listing.IsRelisting ~= nil
		and listing:IsRelisting() == true
	local activeListing = listing ~= nil
		and listing.HasActive ~= nil
		and listing:HasActive() == true
	local listed = relisting
		or activeListing
		or preview
	return canLead, relisting, listed,
		canManage or (relisting and canLead) or preview,
		activeListing
end

local function refreshColumnHeaderLifecycle(panel)
	if panel.columnHeaderHost then
		panel.columnHeaderHost:Show()
		panel:LayoutColumnHeaders()
	end
end


function AP:UpdateToolbarForListed()
	local relisting, listed, hasManagementAccess = readToolbarManagementLifecycle()
	self:SetBottomControlsShown(listed == true and hasManagementAccess == true)
	self:SetHeaderRefreshButtonShown(listed == true)
	self:SetManagementControlsShown(hasManagementAccess == true)
	if not relisting then
		self:UpdateFromActiveRoleSummary()
	end
	refreshColumnHeaderLifecycle(self)
	if listed then
		self:UpdateManageState()
	end
end

function AP:UpdateManageState()
	local canLead, isRelisting, hasListing, hasManagementAccess,
		hasAuthoritativeListing = readCurrentManagementLifecycle()
	if not hasAuthoritativeListing and self.RetireInactiveApplicantSnapshot then
		-- The active-entry truth, not the possibly stale applicant provider, closes
		-- the previous row generation.  The presenter keeps only bounded terminal
		-- and invited feedback that still owns an explicit completion lifecycle.
		self:RetireInactiveApplicantSnapshot()
	end
	local preservingTerminalAcknowledgement =
		next(self._terminalApplicantLifecycles or {}) ~= nil
	local awaitingInvitedTerminal =
		next(self._retainedInvitedApplicants or {}) ~= nil
	local hasRosterCandidates =
		next(self._applicantRosterCandidates or {}) ~= nil
	if hasListing then
		self:CancelListingLossCleanup()
	elseif preservingTerminalAcknowledgement
		or awaitingInvitedTerminal or hasRosterCandidates
	then
		-- A group becoming full can remove the active listing before Blizzard's
		-- inviteaccepted/roster event arrives.  Keep unresolved candidates for one
		-- short ordering window; completed joined acknowledgements do not survive.
		self:ScheduleListingLossCleanup()
	end
	if not hasListing
		and not preservingTerminalAcknowledgement
		and not awaitingInvitedTerminal
		and not hasRosterCandidates
	then
		-- Applicant IDs are scoped to the active recruitment session.  Clear
		-- unresolved retention, but keep consumed terminal tombstones until an
		-- explicit session rotation or a newer authoritative status changes them;
		-- inactive native providers can otherwise re-emit the same stale ID.
		self:ResetApplicantTransientState()
		self._retainedInvitedApplicants = nil
	end
	local showControls = hasListing and hasManagementAccess
	self:SetBottomControlsShown(showControls)
	self:SetHeaderRefreshButtonShown(hasListing)
	self:SetManagementControlsShown(hasManagementAccess)
	applyManageState(self, canLead, hasManagementAccess)
	if isRelisting then
		return
	end
	self:UpdateFromActiveRoleSummary()
	self:UpdateEmptyHint()
	self:UpdateInviteState()
end

function AP:Show()
	local host = self.parent
	if not host then
		return
	end
	if not self.scrollList then
		self:Init(host)
		self._requiresInitialProviderRefresh = true
	end
	host:Show()
	self:UpdateToolbarForListed()
	self:LayoutColumnHeaders()
	local listing = GF.RecruitmentSession
	if listing and listing.IsRelisting and listing:IsRelisting() then
		return
	end
	local requiresInitialRefresh = self._requiresInitialProviderRefresh ~= false
	if not requiresInitialRefresh then
		if self._applicantElementsDirty then
			self:RebuildApplicantElements({ preserveScroll = true })
		else
			self:UpdateManageState()
			self:UpdateFromActiveRoleSummary()
			self:UpdateEmptyHint()
			self:UpdateInviteState()
		end
		return
	end
	self._requiresInitialProviderRefresh = false
	local actions = GF.ApplicantActionService
	if actions and actions.Refresh then
		actions:Refresh()
	end
	self:Refresh({ preserveScroll = true })
	if self._applicantElementsDirty and self:IsPresentationVisible() then
		-- A hidden session reset may have emptied the model while the ScrollBox
		-- still owns the old cards. An inactive/unreadable provider cannot commit
		-- that change; finish it from the current model before clearing the flag.
		self:RebuildApplicantElements({ preserveScroll = true })
	end
end

local function cancelRaidProfilePreparation()
	local tooltip = GF.ApplicantRaidTooltip
	if tooltip and type(tooltip.CancelPending) == "function" then
		tooltip.CancelPending()
	end
end

function AP:PausePresentation()
	-- The parent window can hide without changing this child's shown flag. Mark
	-- the next real presentation as an initial provider sync while preserving the
	-- current recruitment lifecycle and cached viewport in the meantime.
	cancelRaidProfilePreparation()
	self._requiresInitialProviderRefresh = true
end

function AP:DeferProviderRefresh()
	-- A background layout pass may make the raw host effectively visible. Keep
	-- applicant-provider reads attached to the first real Create presentation.
	self._requiresInitialProviderRefresh = true
	self._applicantElementsDirty = true
end

function AP:Hide()
	cancelRaidProfilePreparation()
	self:CancelListingLossCleanup()
	self:ResetApplicantTransientState()
	self._requiresInitialProviderRefresh = true
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
