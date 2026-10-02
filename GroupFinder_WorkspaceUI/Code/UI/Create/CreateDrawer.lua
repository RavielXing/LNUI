local _, GF = ...
GF = GF.GF or GF

-- CreateDrawer owns only the meeting-stone satellite shell. Recruitment state
-- comes from RecruitmentFormPresenter, protected fields remain CreatePanel's
-- adapter, and listing mutations remain RecruitmentSession's responsibility.
GF.CreateDrawer = {}
local CD = GF.CreateDrawer
local FormPresenter = assert(
	GF.RecruitmentFormPresenter,
	"RecruitmentFormPresenter must load before CreateDrawer"
)

local PANEL_W = GF.CREATE_DRAWER_W or 760
local PANEL_H = GF.CREATE_DRAWER_H or 390
local PHASE_CLOSED = "closed"
local PHASE_OPEN = "open"
local PHASE_SUSPENDED = "suspended"
local FOREGROUND_DRAWER = "drawer"
local FOREGROUND_MAIN = "main"

local state = {
	phase = PHASE_CLOSED,
	foreground = FOREGROUND_DRAWER,
	tabActive = false,
	userClosedCreate = false,
	modalOwner = nil,
	userPositioned = false,
}

local function syncCompatibilityFields()
	CD.open = state.phase ~= PHASE_CLOSED
	CD._tabActive = state.tabActive
	CD._userClosedCreate = state.userClosedCreate
	CD._modalOwner = state.modalOwner
	CD._userPositioned = state.userPositioned
	CD._mainFrameForeground = state.foreground == FOREGROUND_MAIN
end

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return nil
	end
	return method(owner, ...)
end

local function closeCreateFromTitleButton()
	local panel = GF.CreatePanel
	local clearSelection = panel == nil or panel.editMode ~= true
	local closed = CD:Close()
	if closed and clearSelection then
		invoke(GF.NavTree, "ClearActiveRoot", false, {
			clearSelection = true,
			clearSelectionInActiveRoot = true,
			suppressCreateDrawer = true,
		})
	end
	return closed
end

local function filterFooterAtlasTopOffset()
	local offset = GF.FILTER_FOOTER_ATLAS_TOP_OFFSET
	if offset == nil then
		offset = GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0
	end
	return offset or 0
end

local function applyDrawerTitleStyle(frame)
	local title = frame and frame.titletext
	if not title then
		return
	end
	title._gfFontSizeOverride = 14
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(title, title._gfFontTemplate or "GameFontNormal")
	end
end

local function isFrameResizing()
	if GF._frameResizing then
		return true
	end
	local panel = GF.CreatePanel
	return panel and panel._frameResizing == true
end

local function isMainFrameShown()
	local controller = GF.MainFrame
	if controller and controller.IsUserVisible then
		return controller:IsUserVisible()
	end
	local frame = controller and controller.frame
	return frame and frame.IsShown and frame:IsShown() or false
end

local function canApplyPresentationAlpha()
	local controller = GF.MainFrame
	if controller and controller.CanApplyPresentationAlpha then
		return controller:CanApplyPresentationAlpha() == true
	end
	return true
end

local function getMythicPlusInlinePanel()
	return GF.MythicPlusCreateManagerPanel
end

local function isMythicPlusInlineSurfaceActive()
	local panel = getMythicPlusInlinePanel()
	return panel and panel.IsSurfaceActive
		and panel:IsSurfaceActive() or false
end

local function shouldUseMythicPlusInlineSurface()
	local panel = getMythicPlusInlinePanel()
	return panel and panel.ShouldUse and panel:ShouldUse() or false
end

local function activateCreateChannel()
	if GF.CreatePanel and GF.CreatePanel.ActivateCreateChannel then
		return GF.CreatePanel:ActivateCreateChannel()
	end
	if GF.BlizzardBorrow and GF.BlizzardBorrow.SetActiveOwner then
		GF.BlizzardBorrow.SetActiveOwner("groupfinder")
		return true
	end
	return false
end

local function getAvoidAlpha()
	return GF.CREATE_DRAWER_AVOID_ALPHA or GF.CREATE_DRAWER_MAIN_ALPHA or 0.64
end

local function canRestoreHiddenAlpha(frame, dimmed, allowHiddenRestore)
	return allowHiddenRestore == true
		and dimmed ~= true
		and frame ~= nil
		and type(frame.IsShown) == "function"
		and frame:IsShown() ~= true
end

function CD:SetMainFrameDimmed(dimmed, allowHiddenRestore)
	local mainFrame = self.mainFrame or (GF.MainFrame and GF.MainFrame.frame)
	if not mainFrame or not mainFrame.SetAlpha then
		return false
	end
	if not canApplyPresentationAlpha()
		and not canRestoreHiddenAlpha(
			mainFrame, dimmed, allowHiddenRestore)
	then
		return false
	end
	mainFrame:SetAlpha(dimmed and getAvoidAlpha() or 1)
	return true
end

function CD:SetDrawerDimmed(dimmed, allowHiddenRestore)
	if not self.frame or not self.frame.SetAlpha then
		return false
	end
	if not canApplyPresentationAlpha()
		and not canRestoreHiddenAlpha(
			self.frame, dimmed, allowHiddenRestore)
	then
		return false
	end
	self.frame:SetAlpha(dimmed and getAvoidAlpha() or 1)
	return true
end

function CD:SyncChildFrameLevels()
	if not self.frame then
		return
	end
	if isMythicPlusInlineSurfaceActive() then
		local panel = getMythicPlusInlinePanel()
		if panel and panel.SyncMountedFrameLevels then
			panel:SyncMountedFrameLevels()
		end
		return
	end
	local baseLevel = self.frame.GetFrameLevel
		and self.frame:GetFrameLevel() or 0
	local mainForeground = state.foreground == FOREGROUND_MAIN
	local contentLevel = baseLevel + (mainForeground and 0 or 5)
	if self.footer and self.footer.SetFrameLevel then
		self.footer:SetFrameLevel(contentLevel)
	end
	if self.panelHost and self.panelHost.SetFrameLevel then
		self.panelHost:SetFrameLevel(contentLevel)
	end
	if self.frame.gfDragBar and self.frame.gfDragBar.SetFrameLevel then
		self.frame.gfDragBar:SetFrameLevel(
			contentLevel + (mainForeground and 0 or 50)
		)
	end
end

local function applyForeground(drawer, foreground)
	if not drawer.frame then
		return false
	end
	state.foreground = foreground
	syncCompatibilityFields()
	local drawerWins = foreground == FOREGROUND_DRAWER
	drawer.frame._gfLevelOffset = drawerWins
		and (drawer._drawerLevelOffset or drawer.frame._gfLevelOffset or 10)
		or -2
	if drawer.frame.SetToplevel then
		drawer.frame:SetToplevel(drawerWins)
	end
	drawer:SetMainFrameDimmed(drawerWins)
	drawer:SetDrawerDimmed(not drawerWins)
	if GF.UI and GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
	local raiseTarget = drawerWins and drawer.frame
		or (drawer.mainFrame or (GF.MainFrame and GF.MainFrame.frame))
	if raiseTarget and GF.UI and GF.UI.RaiseFrame then
		GF.UI.RaiseFrame(raiseTarget)
	end
	drawer:SyncChildFrameLevels()
	return true
end

function CD:ApplyDrawerForeground()
	return applyForeground(self, FOREGROUND_DRAWER)
end

function CD:ApplyMainFrameForeground()
	return applyForeground(self, FOREGROUND_MAIN)
end

function CD:ActivateDrawer()
	if not self:IsOpen() then
		return false
	end
	local panel = GF.CreatePanel
	if panel and panel.debugCensoredPreviewMode == true then
		return self:ApplyDrawerForeground()
	end
	if panel and panel.IsCreateChannelAutoOpenBlocked
		and panel:IsCreateChannelAutoOpenBlocked()
	then
		self:ApplyDrawerForeground()
		invoke(panel, "UpdateOwnershipUI")
		return true
	end
	activateCreateChannel()
	return self:ApplyDrawerForeground()
end

function CD:ActivateMainFrame()
	if not self:IsOpen() then
		return false
	end
	return self:ApplyMainFrameForeground()
end

function CD:MountCreatePanel()
	local panel = GF.CreatePanel
	if panel == nil or self.panelHost == nil then
		return false
	end
	if panel.parent == nil and type(panel.Init) == "function" then
		panel:Init(self.panelHost)
	end
	return panel.parent ~= nil
end

function CD:Init(content, contentBody)
	if self.frame then
		return true
	end
	self.content = content
	self.host = contentBody or content
	self.mainFrame = GF.MainFrame and GF.MainFrame.frame
	state.phase = PHASE_CLOSED
	state.foreground = FOREGROUND_DRAWER
	state.tabActive = false
	state.userClosedCreate = false
	state.modalOwner = nil
	state.userPositioned = false
	syncCompatibilityFields()

	local L = GF.L or {}
	self.frame = CreateFrame(
		"Frame",
		"GroupFinderAddonCreateListingFrame",
		UIParent,
		"SettingsFrameTemplate"
	)
	self.frame:SetSize(PANEL_W, PANEL_H)
	self.frame:EnableMouse(true)
	self.frame:SetClampedToScreen(true)
	self.frame:Hide()
	self.frame:HookScript("OnMouseDown", function()
		CD:ActivateDrawer()
	end)
	GF.UI.InstallSatelliteFrame(self.frame, {
		levelOffset = 10,
		raise = true,
		toplevel = true,
	})
	self._drawerLevelOffset = self.frame._gfLevelOffset or 10
	local dragBar = GF.UI.SetupTitleDragBar(self.frame, function()
		state.userPositioned = true
		syncCompatibilityFields()
		CD:ApplyDrawerForeground()
		CD:SyncChildFrameLevels()
	end)
	if dragBar then
		dragBar:HookScript("OnMouseDown", function()
			CD:ActivateDrawer()
		end)
	end
	GF.UI.ApplySettingsFrameChrome(self.frame, L.TAB_CREATE or "Create Listing")
	applyDrawerTitleStyle(self.frame)
	GF.UI.InstallBodyBackground(self.frame, {
		layout = "filter",
		style = "panelBackplate",
	})
	if self.frame.ClosePanelButton then
		self.frame.ClosePanelButton:SetScript("OnClick", function()
			closeCreateFromTitleButton()
		end)
	end
	self.frame:HookScript("OnHide", function()
		if CD.open and not CD._closing and CD._modalOwner == nil then
			CD:Close()
		end
	end)

	local contentLevel = self.frame:GetFrameLevel() + 5
	local footerH = GF.FILTER_FOOTER_H or GF.SUBTITLE_H or 42
	local footerInsetL = GF.FILTER_FOOTER_INSET_L
		or GF.FRAME_BG_INSET_LEFT or 7
	local footerInsetR = GF.FILTER_FOOTER_INSET_R
		or GF.FRAME_BG_INSET_RIGHT or -2
	local footerInsetB = GF.FILTER_FOOTER_INSET_B
		or GF.FRAME_BG_INSET_BOTTOM or 3
	self.footer = CreateFrame("Frame", nil, self.frame)
	self.footer:SetPoint(
		"BOTTOMLEFT",
		self.frame,
		"BOTTOMLEFT",
		footerInsetL,
		footerInsetB
	)
	self.footer:SetPoint(
		"BOTTOMRIGHT",
		self.frame,
		"BOTTOMRIGHT",
		footerInsetR,
		footerInsetB
	)
	self.footer:SetHeight(footerH)
	self.footer:SetFrameLevel(contentLevel)
	if GF.UI.InstallBrowseControlBarChrome then
		GF.UI.InstallBrowseControlBarChrome(self.footer, {
			backgroundParent = self.footer,
			leftInset = 0,
			rightInset = 0,
			height = GF.BROWSE_CONTROL_BACKGROUND_H
				or GF.SUBTITLE_HEADER_H or 26,
			topOffset = GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0,
		})
	end

	self.panelHost = CreateFrame("Frame", nil, self.frame)
	self.panelHost:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, -28)
	self.panelHost:SetPoint(
		"BOTTOMRIGHT",
		self.frame,
		"BOTTOMRIGHT",
		0,
		footerH + footerInsetB + filterFooterAtlasTopOffset()
	)
	self.panelHost:SetFrameLevel(contentLevel)
	self.panelHost._gfCreateDrawerFooter = self.footer
	self.panelHost:EnableMouse(true)
	self.panelHost:HookScript("OnMouseDown", function()
		CD:ActivateDrawer()
	end)

	local function requestLayout()
		CD:Layout()
	end
	if self.mainFrame then
		self.mainFrame:HookScript("OnSizeChanged", requestLayout)
	end
	if content and content.HookScript then
		content:HookScript("OnSizeChanged", requestLayout)
	end
	if UISpecialFrames and self.frame.GetName and self.frame:GetName() then
		tinsert(UISpecialFrames, self.frame:GetName())
	end
	self:MountCreatePanel()
	return true
end

function CD:IsOpen()
	return state.phase ~= PHASE_CLOSED and self.frame ~= nil
		and (self.frame:IsShown() or state.modalOwner ~= nil)
end

function CD:SuspendForModal(owner)
	if owner == nil or state.modalOwner ~= nil
		or state.phase ~= PHASE_OPEN
		or not (self.frame and self.frame:IsShown())
	then
		return false
	end
	state.modalOwner = owner
	state.phase = PHASE_SUSPENDED
	syncCompatibilityFields()
	invoke(GF.CreatePanel, "CancelEditFieldReveal")
	self.frame:Hide()
	return true
end

function CD:ResumeFromModal(owner)
	if owner == nil or state.modalOwner ~= owner then
		return false
	end
	state.modalOwner = nil
	if not state.tabActive or not isMainFrameShown() or not self.frame then
		syncCompatibilityFields()
		self:Close(true)
		return false
	end
	state.phase = PHASE_OPEN
	syncCompatibilityFields()
	local popupMotionSuppressed = GF.UI
		and GF.UI.SuppressNextPopupOpenAnimation
		and GF.UI.SuppressNextPopupOpenAnimation(self.frame) == true
	self.frame:Show()
	if not popupMotionSuppressed and GF.UI
		and GF.UI.StopPopupOpenAnimation
	then
		GF.UI.StopPopupOpenAnimation(self.frame)
	end
	self:ApplyDrawerForeground()
	self:Layout()
	return true
end

function CD:AnchorToMain()
	if not self.frame then
		return
	end
	local mainFrame = self.mainFrame or (GF.MainFrame and GF.MainFrame.frame)
	if not mainFrame then
		return
	end
	self.mainFrame = mainFrame
	local width, height = self:GetPreferredSize()
	self.frame:SetWidth(width)
	self.frame:SetHeight(height)
	if not state.userPositioned then
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
	end
	self:SyncChildFrameLevels()
end

function CD:GetPreferredSize()
	local style = GF.RAID_CREATE_DRAWER_STYLE
	if style and self.workspaceContext
		and self.workspaceContext.workspaceID == GF.WORKSPACE_RAID
	then
		return style.width, style.height
	end
	return PANEL_W, PANEL_H
end

function CD:SyncActivityTitle()
	if not self.frame then
		return
	end
	local title = FormPresenter:GetDrawerTitle(GF.CreatePanel, GF.L)
	GF.UI.ApplySettingsFrameChrome(self.frame, title)
	applyDrawerTitleStyle(self.frame)
end

function CD:Layout(immediate)
	if not self.frame then
		return
	end
	self:AnchorToMain()
	if state.phase == PHASE_CLOSED or not GF.CreatePanel then
		return
	end
	if state.foreground == FOREGROUND_MAIN then
		self:ApplyMainFrameForeground()
	else
		self:ApplyDrawerForeground()
	end
	if isFrameResizing() then
		return
	end
	local panel = GF.CreatePanel
	if immediate == true and panel.CancelUpdateScrollLayoutDebounce then
		panel:CancelUpdateScrollLayoutDebounce()
	end
	local updateLayout = immediate == true and panel.UpdateScrollLayout
		or panel.ScheduleUpdateScrollLayout or panel.UpdateScrollLayout
	if updateLayout then
		updateLayout(panel)
	end
end

function CD:SetTabActive(active)
	state.tabActive = active and isMainFrameShown() and true or false
	syncCompatibilityFields()
	if not state.tabActive then
		self:Close(true)
		state.userClosedCreate = false
		syncCompatibilityFields()
		return
	end
	self:Layout()
end

function CD:SetWorkspaceContext(context)
	local previousKey = self.workspaceContext and self.workspaceContext.key
	local nextKey = context and context.key
	if previousKey and previousKey ~= nextKey
		and state.phase ~= PHASE_CLOSED
	then
		self:Close(true)
	end
	-- Resolve the new shell dimensions before the presenter lays out fields.
	self.workspaceContext = context
	self:AnchorToMain()
	self.workspaceContext = FormPresenter:SetWorkspaceContext(
		GF.CreatePanel,
		context
	)
	return self.workspaceContext
end

function CD:ResetAfterListingRemoved()
	self._lastActiveListingWasGroupFinder = nil
	state.userClosedCreate = false
	syncCompatibilityFields()
	self:Close(true)
end

function CD:SyncDefaultState(hasActive, opts)
	if not state.tabActive or not isMainFrameShown() then
		return
	end
	opts = opts or {}
	local session = GF.RecruitmentSession
	if not hasActive and session and session.IsRelisting
		and session:IsRelisting()
	then
		return
	end
	if not hasActive and opts.suppressCreateAutoOpen then
		self._lastActiveListingWasGroupFinder = nil
		if state.phase ~= PHASE_CLOSED then
			self:Close(true)
		end
		state.userClosedCreate = true
		syncCompatibilityFields()
		return
	end
	if hasActive then
		if session and session.IsActiveEntryOwned then
			self._lastActiveListingWasGroupFinder =
				session:IsActiveEntryOwned() == true
		end
		state.userClosedCreate = false
		syncCompatibilityFields()
		if session and session.CanManageApplicants
			and not session:CanManageApplicants()
		then
			self:Close(true)
			return
		end
		if state.phase == PHASE_CLOSED and GF.CreatePanel then
			GF.CreatePanel:Hide()
		end
		return
	end
	if self._lastActiveListingWasGroupFinder == false then
		self._lastActiveListingWasGroupFinder = nil
		self:Close(true)
		return
	end
	self._lastActiveListingWasGroupFinder = nil
	if session and session.CanPublish and not session:CanPublish() then
		self:Close(true)
		return
	end
	local allowOccupiedPrompt = opts.allowOccupiedPrompt == true
	local panel = GF.CreatePanel
	if not allowOccupiedPrompt and panel
		and panel.IsCreateChannelAutoOpenBlocked
		and panel:IsCreateChannelAutoOpenBlocked()
	then
		self:Close(true)
		return
	end
	if state.userClosedCreate or state.phase ~= PHASE_CLOSED
		or opts.allowCreateAutoOpen ~= true
	then
		return
	end
	local plan = FormPresenter:PlanDrawerOpen(panel, {
		mode = FormPresenter.MODE_CREATE,
	})
	if plan.allowed ~= true then
		self:Close(true)
		return
	end
	self:Open({
		mode = FormPresenter.MODE_CREATE,
		silent = true,
		allowOccupiedPrompt = allowOccupiedPrompt,
		-- SyncDefaultState is the positive surface-restoration route used
		-- after the create tab/main window returns.  Activity-selection opens
		-- call Open directly and intentionally keep the ordinary drawer motion.
		restoreCreateSurface = true,
	})
end

local CLOSE_ON_DENIAL = {
	cannot_manage = true,
	availability = true,
	selection = true,
}

local function handleOpenDenial(drawer, plan)
	if plan.denial == "censored_dialog" then
		invoke(GF.CensoredActiveEntryDialog, "Show")
		return false
	end
	if CLOSE_ON_DENIAL[plan.denial] then
		drawer:Close(true)
	end
	return false
end

local function executeOpenPlan(panel, plan, opts, wasShown, occupied)
	if panel == nil then
		return false
	end
	if plan.debugPreview == true then
		return type(panel.PrepareForCensoredDebugPreview) == "function"
			and panel:PrepareForCensoredDebugPreview(opts) == true
	end
	if plan.mode == FormPresenter.MODE_CREATE then
		if type(panel.PrepareForCreate) ~= "function" then
			return false
		end
		-- Reopening a hidden surface resumes the same Blizzard-backed draft.
		-- Visibility is not a draft boundary: tabs, workspaces and the native
		-- LFG window all temporarily hide this drawer.
		panel:PrepareForCreate({
			resetDefaults = opts.resetDefaults == true,
		})
		return true
	end
	if plan.mode == FormPresenter.MODE_EDIT then
		if occupied and type(panel.PrepareForOccupiedEdit) == "function"
			and opts.censoredResolution ~= true
		then
			return panel:PrepareForOccupiedEdit() ~= false
		end
		return type(panel.PrepareForEdit) == "function"
			and panel:PrepareForEdit(opts) ~= false
	end
	return false
end

local function cancelPresentationGate(mainController, ticket, created)
	if not ticket or not mainController then
		return
	end
	if created and mainController.CancelFirstPresentationGate then
		mainController:CancelFirstPresentationGate()
	elseif mainController.ScheduleFirstPresentationGate then
		mainController:ScheduleFirstPresentationGate(ticket)
	end
end

function CD:Open(opts)
	opts = opts or {}
	if state.modalOwner ~= nil or not state.tabActive
		or not isMainFrameShown()
	then
		return false
	end
	local debugCensoredPreview = opts.debugCensoredPreview == true
	if not debugCensoredPreview and opts.censoredResolution ~= true
		and shouldUseMythicPlusInlineSurface()
	then
		local panel = getMythicPlusInlinePanel()
		return panel and panel.Open and panel:Open(opts) or false
	end
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.GetContext then
		self:SetWorkspaceContext(GF.LFGWorkspaceView:GetContext())
	end
	self:MountCreatePanel()
	local panel = GF.CreatePanel
	local planned, openPlan = pcall(function()
		return FormPresenter:PlanDrawerOpen(panel, opts)
	end)
	if not planned or type(openPlan) ~= "table" then
		return false
	end
	if openPlan.allowed ~= true then
		return handleOpenDenial(self, openPlan)
	end

	local occupied = not openPlan.debugPreview and panel
		and panel.IsCreateChannelAutoOpenBlocked
		and panel:IsCreateChannelAutoOpenBlocked() or false
	if occupied and opts.censoredResolution == true then
		invoke(panel, "PrepareForEdit", opts)
		return false
	end
	if occupied and opts.allowOccupiedPrompt ~= true then
		self:Close(true)
		return false
	end
	if not occupied and not openPlan.debugPreview then
		activateCreateChannel()
	end

	local wasShown = self.frame and self.frame:IsShown() or false
	if not wasShown or opts.resetPosition then
		state.userPositioned = false
	end
	state.phase = PHASE_OPEN
	state.foreground = FOREGROUND_DRAWER
	state.userClosedCreate = false
	syncCompatibilityFields()
	-- Establish the target foreground alpha before the transparent first-show
	-- gate captures it. Calls made while the gate is active leave alpha at zero.
	self:SetMainFrameDimmed(true)
	self:SetDrawerDimmed(false)

	local presentationTicket
	local createdPresentationGate = false
	-- Active-listing edits and hidden returns to an already presented create
	-- draft open atomically. In both cases Blizzard-owned text already exists;
	-- replaying the satellite translation while those native fields are being
	-- reprojected makes their glyphs visibly jump. A genuinely new draft keeps
	-- the ordinary first-presentation gate and satellite motion.
	local instantEditOpen = openPlan.mode == FormPresenter.MODE_EDIT
	local continuingCreateDraft = openPlan.mode == FormPresenter.MODE_CREATE
		and invoke(panel, "IsResumingProtectedCreateDraft", opts) == true
	local resumeCreateDraft = not wasShown and continuingCreateDraft
		and opts.restoreCreateSurface == true
	local instantProtectedTextOpen = instantEditOpen
		or continuingCreateDraft
	-- Atomic field projection and outer-shell motion are separate concerns.
	-- Every continuing Blizzard draft is laid out synchronously, but only an
	-- edit or an explicit hidden-surface restoration suppresses the popup.
	-- This keeps activity-selection/X reopens animated and prevents a visible
	-- reentrant Open from stopping a cold create animation already in flight.
	local suppressOuterPopupMotion = instantEditOpen or resumeCreateDraft
	local mainController = GF.MainFrame
	if not instantProtectedTextOpen and not wasShown and mainController
		and mainController.BeginFirstPresentationGate
	then
		mainController:ReleaseFirstPresentationGateInteraction()
		presentationTicket, createdPresentationGate =
			mainController:BeginFirstPresentationGate("create-drawer")
	end
	self:Layout(instantProtectedTextOpen)
	local executed, prepared = pcall(
		executeOpenPlan,
		panel,
		openPlan,
		opts,
		wasShown,
		occupied
	)
	if not executed or prepared ~= true then
		cancelPresentationGate(
			mainController,
			presentationTicket,
			createdPresentationGate
		)
		-- Preparation may already have mounted or borrowed protected fields.
		-- Drive the normal close path so every partial open is recoverable.
		self:Close(true)
		return false
	end
	panel:Show({
		atomicReveal = instantProtectedTextOpen,
		resumeCreateDraft = resumeCreateDraft,
	})
	self:SyncActivityTitle()
	if self.frame then
		local popupMotionSuppressed = false
		local applyBackground = GF.UI and GF.UI.ApplyBodyBackground
		if type(applyBackground) == "function" then
			applyBackground(self.frame)
		end
		if suppressOuterPopupMotion and not wasShown and GF.UI
			and GF.UI.SuppressNextPopupOpenAnimation
		then
			popupMotionSuppressed =
				GF.UI.SuppressNextPopupOpenAnimation(self.frame) == true
		end
		self.frame:Show()
		if (presentationTicket or (suppressOuterPopupMotion and not wasShown
			and not popupMotionSuppressed)) and GF.UI
			and GF.UI.StopPopupOpenAnimation
		then
			GF.UI.StopPopupOpenAnimation(self.frame)
		end
	end
	if occupied then
		invoke(panel, "UpdateOwnershipUI")
		self:ApplyDrawerForeground()
	else
		self:ActivateDrawer()
	end
	self:Layout(instantProtectedTextOpen)
	if (instantEditOpen or resumeCreateDraft) and not occupied then
		invoke(panel, "PlayEditFieldReveal")
	end
	if openPlan.mode == FormPresenter.MODE_CREATE and not occupied then
		invoke(panel, "MarkProtectedCreateDraftPresented")
	end
	if not wasShown and not opts.silent and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("open")
	end
	if presentationTicket and mainController
		and mainController.ScheduleFirstPresentationGate
	then
		mainController:ScheduleFirstPresentationGate(presentationTicket)
	end
	return true
end

function CD:Reopen(opts)
	opts = opts or {}
	opts.resetPosition = true
	opts.silent = opts.silent ~= false
	return self:Open(opts)
end

function CD:Close(force)
	if not state.tabActive and not force then
		self:SetMainFrameDimmed(false, true)
		self:SetDrawerDimmed(false, true)
		return false
	end
	local wasShown = self.frame and self.frame:IsShown() or false
	local wasCreateMode = GF.CreatePanel and GF.CreatePanel.editMode ~= true
	local modalOwner = self._modalOwner
	state.modalOwner = nil
	syncCompatibilityFields()
	if modalOwner and modalOwner.IsShown and modalOwner:IsShown()
		and modalOwner.Hide
	then
		modalOwner:Hide()
	end
	state.phase = PHASE_CLOSED
	if force then
		state.userClosedCreate = false
	elseif wasCreateMode then
		state.userClosedCreate = true
	end
	syncCompatibilityFields()
	if GF.CreatePanel then
		GF.CreatePanel:ClearFocus()
		if not isMythicPlusInlineSurfaceActive() then
			GF.CreatePanel:Hide("panel")
		end
	end
	if self.frame then
		self._closing = true
		self.frame:Hide()
		self._closing = nil
		self.frame._gfLevelOffset = self._drawerLevelOffset
			or self.frame._gfLevelOffset or 10
		if self.frame.SetToplevel then
			self.frame:SetToplevel(true)
		end
	end
	-- ESC may hide the main UISpecialFrame before this satellite teardown
	-- runs.  Hidden-frame restoration is safe and prevents the drawer's
	-- avoid alpha from becoming the next open's presentation target; a visible
	-- first-presentation gate remains authoritative.
	self:SetMainFrameDimmed(false, true)
	self:SetDrawerDimmed(false, true)
	state.foreground = FOREGROUND_DRAWER
	state.userPositioned = false
	syncCompatibilityFields()
	if wasShown and not force and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("close")
	end
	return wasShown
end

function CD:Toggle()
	if self:IsOpen() then
		return self:Close()
	end
	return self:Open()
end

syncCompatibilityFields()
