local _, GF = ...

GF.CreateDrawer = {}
local CD = GF.CreateDrawer

local PANEL_W = GF.CREATE_DRAWER_W or 760
local PANEL_H = GF.CREATE_DRAWER_H or 390

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
	local cp = GF.CreatePanel
	return cp and cp._frameResizing
end

local function isMainFrameShown()
	local frame = GF.MainFrame and GF.MainFrame.frame
	return frame and frame.IsShown and frame:IsShown()
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

local function hasCreateableSelection()
	local cp = GF.CreatePanel
	local node = cp and cp.selection
	if not node then
		return false
	end
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.IsCreateableSelection then
		local workspaceID = cp.workspaceContext and cp.workspaceContext.workspaceID
		return GF.LFGWorkspaceView:IsCreateableSelection(node, workspaceID)
	end
	if GF.NavData and GF.NavData.IsCreateable then
		return GF.NavData.IsCreateable(node) == true
	end
	return node.activityID ~= nil
end

local function getPremadeCreateBlockMessage()
	if GF.Availability and GF.Availability.GetPremadeBlockMessage then
		return GF.Availability:GetPremadeBlockMessage()
	end
	return nil
end

local function activateCreateChannel()
	if GF.CreatePanel and GF.CreatePanel.ActivateCreateChannel then
		GF.CreatePanel:ActivateCreateChannel()
	elseif GF.BlizzardBorrow and GF.BlizzardBorrow.SetActiveOwner then
		GF.BlizzardBorrow.SetActiveOwner("groupfinder")
	end
end

local function getAvoidAlpha()
	return GF.CREATE_DRAWER_AVOID_ALPHA or GF.CREATE_DRAWER_MAIN_ALPHA or 0.64
end

function CD:SetMainFrameDimmed(dimmed)
	local mainFrame = self.mainFrame or (GF.MainFrame and GF.MainFrame.frame)
	if not mainFrame or not mainFrame.SetAlpha then
		return
	end
	if dimmed then
		mainFrame:SetAlpha(getAvoidAlpha())
		return
	end
	mainFrame:SetAlpha(1)
end

function CD:SetDrawerDimmed(dimmed)
	if not self.frame or not self.frame.SetAlpha then
		return
	end
	if dimmed then
		self.frame:SetAlpha(getAvoidAlpha())
		return
	end
	self.frame:SetAlpha(1)
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
	local baseLevel = self.frame.GetFrameLevel and self.frame:GetFrameLevel() or 0
	local contentOffset = self._mainFrameForeground and 0 or 5
	local contentLevel = baseLevel + contentOffset
	if self.footer and self.footer.SetFrameLevel then
		self.footer:SetFrameLevel(contentLevel)
	end
	if self.panelHost and self.panelHost.SetFrameLevel then
		self.panelHost:SetFrameLevel(contentLevel)
	end
	if self.frame.gfDragBar and self.frame.gfDragBar.SetFrameLevel then
		local dragOffset = self._mainFrameForeground and 0 or 50
		self.frame.gfDragBar:SetFrameLevel(contentLevel + dragOffset)
	end
end

function CD:ApplyDrawerForeground()
	if not self.frame then
		return
	end
	self._mainFrameForeground = false
	self.frame._gfLevelOffset = self._drawerLevelOffset or self.frame._gfLevelOffset or 10
	if self.frame.SetToplevel then
		self.frame:SetToplevel(true)
	end
	self:SetMainFrameDimmed(true)
	self:SetDrawerDimmed(false)
	if GF.UI and GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
	if GF.UI and GF.UI.RaiseFrame then
		GF.UI.RaiseFrame(self.frame)
	end
	self:SyncChildFrameLevels()
end

function CD:ApplyMainFrameForeground()
	if not self.frame then
		return
	end
	self._mainFrameForeground = true
	self.frame._gfLevelOffset = -2
	if self.frame.SetToplevel then
		self.frame:SetToplevel(false)
	end
	self:SetMainFrameDimmed(false)
	self:SetDrawerDimmed(true)
	if GF.UI and GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
	local mainFrame = self.mainFrame or (GF.MainFrame and GF.MainFrame.frame)
	if mainFrame and GF.UI and GF.UI.RaiseFrame then
		GF.UI.RaiseFrame(mainFrame)
	end
	self:SyncChildFrameLevels()
end

function CD:ActivateDrawer()
	if not self:IsOpen() then
		return
	end
	if GF.CreatePanel and GF.CreatePanel.IsCreateChannelAutoOpenBlocked and GF.CreatePanel:IsCreateChannelAutoOpenBlocked() then
		self:ApplyDrawerForeground()
		if GF.CreatePanel.UpdateOwnershipUI then
			GF.CreatePanel:UpdateOwnershipUI()
		end
		return
	end
	activateCreateChannel()
	self:ApplyDrawerForeground()
end

function CD:ActivateMainFrame()
	if not self:IsOpen() then
		return
	end
	self:ApplyMainFrameForeground()
end

function CD:Init(content, contentBody)
	if self.frame then
		return
	end
	self.content = content
	self.host = contentBody or content
	self.mainFrame = GF.MainFrame and GF.MainFrame.frame
	self.open = false
	self._tabActive = false
	self._userClosedCreate = false

	local L = GF.L or {}
	self.frame = CreateFrame("Frame", "GroupFinderAddonCreateListingFrame", UIParent, "SettingsFrameTemplate")
	self.frame:SetSize(PANEL_W, PANEL_H)
	self.frame:EnableMouse(true)
	self.frame:SetClampedToScreen(true)
	self.frame:Hide()
	self.frame:HookScript("OnMouseDown", function()
		CD:ActivateDrawer()
	end)
	GF.UI.InstallSatelliteFrame(self.frame, { levelOffset = 10, raise = true, toplevel = true })
	self._drawerLevelOffset = self.frame._gfLevelOffset or 10
	local dragBar = GF.UI.SetupTitleDragBar(self.frame, function()
		CD._userPositioned = true
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
	GF.UI.InstallBodyBackground(self.frame, { layout = "filter", style = "panelBackplate" })
	if self.frame.ClosePanelButton then
		self.frame.ClosePanelButton:SetScript("OnClick", function()
			CD:Close()
		end)
	end
	self.frame:HookScript("OnHide", function()
		if CD.open and not CD._closing then
			CD:Close()
		end
	end)

	local contentLevel = self.frame:GetFrameLevel() + 5
	local footerH = GF.FILTER_FOOTER_H or GF.SUBTITLE_H or 42
	local footerInsetL = GF.FILTER_FOOTER_INSET_L or GF.FRAME_BG_INSET_LEFT or 7
	local footerInsetR = GF.FILTER_FOOTER_INSET_R or GF.FRAME_BG_INSET_RIGHT or -2
	local footerInsetB = GF.FILTER_FOOTER_INSET_B or GF.FRAME_BG_INSET_BOTTOM or 3
	self.footer = CreateFrame("Frame", nil, self.frame)
	self.footer:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", footerInsetL, footerInsetB)
	self.footer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", footerInsetR, footerInsetB)
	self.footer:SetHeight(footerH)
	self.footer:SetFrameLevel(contentLevel)
	if GF.UI.InstallBrowseControlBarChrome then
		GF.UI.InstallBrowseControlBarChrome(self.footer, {
			backgroundParent = self.footer,
			leftInset = 0,
			rightInset = 0,
			height = GF.BROWSE_CONTROL_BACKGROUND_H or GF.SUBTITLE_HEADER_H or 26,
			topOffset = GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0,
		})
	end

	self.panelHost = CreateFrame("Frame", nil, self.frame)
	self.panelHost:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, -28)
	self.panelHost:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, footerH + footerInsetB + filterFooterAtlasTopOffset())
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
end

function CD:IsOpen()
	return self.open == true and self.frame and self.frame:IsShown()
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
	self.frame:SetWidth(PANEL_W)
	self.frame:SetHeight(PANEL_H)
	if not self._userPositioned then
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
	end
	self:SyncChildFrameLevels()
end

local function resolveCreateSelectionTitle()
	local panel = GF.CreatePanel
	local selected = panel and panel.selection
	if not selected then
		return nil
	end
	if selected.activityID and not selected.customBucket then
		local activity = selected.activityInfo
		local getActivity = C_LFGList and C_LFGList.GetActivityInfoTable
		if not activity and getActivity then
			activity = getActivity(selected.activityID)
		end
		return GF.UI.GetCategoryTitle(selected.categoryID, activity)
	end
	return selected.label
end

local function resolveDrawerTitle()
	local listing = GF.Listing
	local getActiveTitle = listing and listing.GetActiveActivityTitle
	local title = getActiveTitle and getActiveTitle(listing)
	if type(title) ~= "string" or title == "" then
		title = resolveCreateSelectionTitle()
	end
	if type(title) ~= "string" or title == "" then
		title = (GF.L and GF.L.TAB_CREATE) or "Create Listing"
	end
	return title
end

function CD:SyncActivityTitle()
	if not self.frame then
		return
	end
	GF.UI.ApplySettingsFrameChrome(self.frame, resolveDrawerTitle())
	applyDrawerTitleStyle(self.frame)
end

function CD:Layout()
	if not self.frame then
		return
	end
	self:AnchorToMain()
	if not self.open or not GF.CreatePanel then
		return
	end
	if self._mainFrameForeground then
		self:ApplyMainFrameForeground()
	else
		self:ApplyDrawerForeground()
	end
	if isFrameResizing() then
		return
	end
	local createPanel = GF.CreatePanel
	local updateLayout = createPanel.ScheduleUpdateScrollLayout
		or createPanel.UpdateScrollLayout
	if updateLayout then
		updateLayout(createPanel)
	end
end

function CD:SetTabActive(active)
	self._tabActive = active and isMainFrameShown() and true or false
	if not self._tabActive then
		self:Close(true)
		self._userClosedCreate = false
		return
	end
	self:Layout()
end

function CD:SetWorkspaceContext(context)
	local previousKey = self.workspaceContext and self.workspaceContext.key
	local nextKey = context and context.key
	if previousKey and previousKey ~= nextKey and self.open then
		self:Close(true)
	end
	self.workspaceContext = context
end

function CD:ResetAfterListingRemoved()
	self._lastActiveListingWasGroupFinder = nil
	self._userClosedCreate = false
	self:Close(true)
end

function CD:SyncDefaultState(hasActive, opts)
	if not self._tabActive or not isMainFrameShown() then
		return
	end
	opts = opts or {}
	if not hasActive and GF.Listing and GF.Listing.IsBumpRelisting
		and GF.Listing:IsBumpRelisting() then
		return
	end
	if not hasActive and opts.suppressCreateAutoOpen then
		self._lastActiveListingWasGroupFinder = nil
		if self.open then
			self:Close(true)
		end
		self._userClosedCreate = true
		return
	end
	if hasActive then
		if GF.Listing and GF.Listing.IsActiveEntryGroupFinderOwned then
			self._lastActiveListingWasGroupFinder = GF.Listing:IsActiveEntryGroupFinderOwned() == true
		end
		self._userClosedCreate = false
		local canManage = GF.Listing and GF.Listing.CanManageEntry and GF.Listing:CanManageEntry()
		if not canManage then
			self:Close(true)
			return
		end
		if not self.open and GF.CreatePanel then
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
	if GF.Listing and GF.Listing.CanLeadListing and not GF.Listing:CanLeadListing() then
		self:Close(true)
		return
	end
	if getPremadeCreateBlockMessage() then
		self:Close(true)
		return
	end
	local allowOccupiedPrompt = opts.allowOccupiedPrompt == true
	if not allowOccupiedPrompt and GF.CreatePanel and GF.CreatePanel.IsCreateChannelAutoOpenBlocked and GF.CreatePanel:IsCreateChannelAutoOpenBlocked() then
		self:Close(true)
		return
	end
	if self._userClosedCreate then
		return
	end
	if self.open then
		return
	end
	if opts.allowCreateAutoOpen ~= true then
		return
	end
	if not hasCreateableSelection() then
		self:Close(true)
		return
	end
	self:Open({ mode = "create", silent = true, allowOccupiedPrompt = allowOccupiedPrompt })
end

function CD:Open(opts)
	opts = opts or {}
	if not self._tabActive or not isMainFrameShown() then
		return
	end
	if shouldUseMythicPlusInlineSurface() then
		local panel = getMythicPlusInlinePanel()
		if panel and panel.Open then
			panel:Open(opts)
		end
		return
	end
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.GetContext then
		self:SetWorkspaceContext(GF.LFGWorkspaceView:GetContext())
	end
	local mode = opts.mode
	if not mode then
		mode = (GF.Listing and GF.Listing.HasActive and GF.Listing:HasActive()) and "edit" or "create"
	end
	if mode == "edit" and (not GF.Listing or not GF.Listing:HasActive()) then
		return
	end
	if mode == "edit" and GF.Listing and GF.Listing.CanManageEntry
		and not GF.Listing:CanManageEntry() then
		self:Close(true)
		return
	end
	if mode == "create" and getPremadeCreateBlockMessage() then
		self:Close(true)
		return
	end
	if mode == "create" and not hasCreateableSelection() then
		self:Close(true)
		return
	end
	local allowOccupiedPrompt = opts.allowOccupiedPrompt == true
	local occupied = GF.CreatePanel and GF.CreatePanel.IsCreateChannelAutoOpenBlocked and GF.CreatePanel:IsCreateChannelAutoOpenBlocked()
	if occupied and not allowOccupiedPrompt then
		self:Close(true)
		return
	end
	if not occupied then
		activateCreateChannel()
	end
	local wasShown = self.frame and self.frame:IsShown()
	if not wasShown or opts.resetPosition then
		self._userPositioned = false
	end
	self.open = true
	self._mainFrameForeground = false
	self._userClosedCreate = false
	self:Layout()
	if GF.CreatePanel then
		if mode == "create" then
			GF.CreatePanel:PrepareForCreate({ resetDefaults = not wasShown })
		elseif mode == "edit" or (GF.Listing and GF.Listing:HasActive()) then
			if occupied and GF.CreatePanel.PrepareForOccupiedEdit then
				GF.CreatePanel:PrepareForOccupiedEdit()
			else
				GF.CreatePanel:PrepareForEdit()
			end
		else
			GF.CreatePanel:PrepareForCreate({ resetDefaults = not wasShown })
		end
		GF.CreatePanel:Show()
	end
	self:SyncActivityTitle()
	if self.frame then
		local applyBackground = GF.UI and GF.UI.ApplyBodyBackground
		if applyBackground then
			applyBackground(self.frame)
		end
		self.frame:Show()
	end
	if occupied then
		if GF.CreatePanel and GF.CreatePanel.UpdateOwnershipUI then
			GF.CreatePanel:UpdateOwnershipUI()
		end
		self:ApplyDrawerForeground()
	else
		self:ActivateDrawer()
	end
	self:Layout()
	if not wasShown and not opts.silent and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("open")
	end
end

function CD:Reopen(opts)
	opts = opts or {}
	opts.resetPosition = true
	opts.silent = opts.silent ~= false
	self:Open(opts)
end

function CD:Close(force)
	if not self._tabActive and not force then
		self:SetMainFrameDimmed(false)
		self:SetDrawerDimmed(false)
		return
	end
	local wasShown = self.frame and self.frame:IsShown()
	local wasCreateMode = GF.CreatePanel and GF.CreatePanel.editMode ~= true
	self.open = false
	if force then
		self._userClosedCreate = false
	elseif wasCreateMode then
		self._userClosedCreate = true
	end
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
		self.frame._gfLevelOffset = self._drawerLevelOffset or self.frame._gfLevelOffset or 10
		if self.frame.SetToplevel then
			self.frame:SetToplevel(true)
		end
	end
	self:SetMainFrameDimmed(false)
	self:SetDrawerDimmed(false)
	self._mainFrameForeground = false
	self._userPositioned = false
	if wasShown and not force and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("close")
	end
end

function CD:Toggle()
	if self:IsOpen() then
		self:Close()
	else
		self:Open()
	end
end
