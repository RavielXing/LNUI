local _, GF = ...
GF = GF.GF or GF

GF.MainFrame = GF.MainFrame or {}
local MF = GF.MainFrame

local function requestWorkspaceUI()
	local module = GF.WorkspaceUIModule
	if module and type(module.EnsureLoaded) == "function" then
		return module:EnsureLoaded()
	end
	return true
end

local function workspaceRouter()
	local router = GF.WorkspaceRouter
	if not router then
		error("GroupFinder WorkspaceRouter must load before MainFrame", 2)
	end
	return router
end

local function shellPresenter()
	local presenter = GF.WindowShellPresenter
	if not presenter then
		error("GroupFinder WindowShellPresenter must load before MainFrame", 2)
	end
	if presenter._view ~= MF and presenter.BindView then
		presenter:BindView(MF)
	end
	return presenter
end

local function surfaceReady(surfaceKey)
	return shellPresenter():IsSurfaceReady(surfaceKey)
end

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if method then
		return method(owner, ...)
	end
end

local function getFindGroupTab()
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.GetBrowseSurface then
		return GF.LFGWorkspaceView:GetBrowseSurface()
	end
	return GF.FindGroupTab
end

local function scheduleApplicantsRelayout()
	if GF.ApplicantsPanel and GF.ApplicantsPanel.RefreshLayoutIfReady then
		MF:ScheduleWhenShown(0, function()
			if GF.ApplicantsPanel then
				GF.ApplicantsPanel:RefreshLayoutIfReady()
			end
		end)
	end
end

function MF:IsSurfacePreloadActive()
	return shellPresenter():IsSurfacePreloadActive()
end

function MF:IsUserVisible()
	return shellPresenter():IsUserVisible()
end

function MF:CanApplyPresentationAlpha()
	return shellPresenter():CanApplyPresentationAlpha()
end

function MF:IsShowActive(gen)
	return shellPresenter():IsShowActive(gen)
end

function MF:ScheduleWhenShown(delay, fn)
	return shellPresenter():ScheduleWhenShown(delay, fn)
end

function MF:CancelShowDeferredWork()
	return shellPresenter():CancelShowDeferredWork()
end

function MF:ScheduleDeferredShowLayout()
	return shellPresenter():ScheduleDeferredShowLayout()
end

local function refreshCreateTabIfActive(opts)
	if MF._windowSurfacesReady ~= true or not MF:IsUserVisible()
		or MF._initializingWindow == true
		or not GF.TabBar or GF.TabBar:GetCurrent() ~= GF.TAB_CREATE then
		return
	end
	MF:UpdateCreateTab(opts)
	scheduleApplicantsRelayout()
end

local function activateMainFrameFocus()
	-- Release the follow-teleport dialog's alpha ownership before any create
	-- drawer focus transition applies its own foreground projection.
	invoke(GF.MythicPlusTeleportDialog, "ActivateMainFrame")
	invoke(GF.StarredLeadersPanel, "ActivateMainFrame")
	local currentTab = GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar:GetCurrent()
	if currentTab == GF.TAB_CREATE
		and GF.CreateDrawer and GF.CreateDrawer.IsOpen and GF.CreateDrawer:IsOpen()
		and GF.CreateDrawer.ActivateMainFrame then
		GF.CreateDrawer:ActivateMainFrame()
	end
	return currentTab
end

function MF:ActivateFocus()
	return activateMainFrameFocus()
end

local ROLE_BUTTON_SPECS = {
	{ key = "tank", role = "TANK", name = "Tank" },
	{ key = "healer", role = "HEALER", name = "Healer" },
	{ key = "damager", role = "DAMAGER", name = "Damager" },
}

local function getLfgRoles()
	if not GetLFGRoles then
		return false, false, false, false
	end
	local ok, leader, tank, healer, damager = pcall(GetLFGRoles)
	if not ok then
		return false, false, false, false
	end
	return leader, tank, healer, damager
end

local function getAvailableLfgRoles()
	if not (C_LFGList and C_LFGList.GetAvailableRoles) then
		return false, false, false
	end
	local ok, tank, healer, damager = pcall(C_LFGList.GetAvailableRoles)
	if not ok then
		return false, false, false
	end
	return tank == true, healer == true, damager == true
end

local function setRoleButtonChecked(button, checked)
	if button and button.checkButton and button.checkButton.SetChecked then
		button.checkButton:SetChecked(checked == true)
	end
end

local function setRoleButtonCheckHidden(button)
	if not button or not button.checkButton then
		return
	end
	button.checkButton:Hide()
	if button.checkButton.SetMouseClickEnabled then
		button.checkButton:SetMouseClickEnabled(false)
	end
end

local function setRoleButtonAtlas(button, muted)
	if not button or not button.role then
		return
	end
	if GetIconForRole and button.SetNormalAtlas then
		local ok, atlas = pcall(GetIconForRole, button.role, muted == true)
		if ok and atlas then
			button:SetNormalAtlas(atlas, TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
		end
	end
	local texture = button.GetNormalTexture and button:GetNormalTexture()
	if texture and texture.SetDesaturated then
		texture:SetDesaturated(muted == true)
	end
	if texture and texture.SetVertexColor then
		texture:SetVertexColor(1, 1, 1, 1)
	end
end

local function applyRoleButtonVisual(button, available, checked)
	if not button then
		return
	end
	setRoleButtonCheckHidden(button)
	if button.lockedIndicator then
		button.lockedIndicator:Hide()
	end
	setRoleButtonAtlas(button, not (available == true and checked == true))
end

local function createRoleButton(parent, spec, onClick)
	local button = CreateFrame("Button", "GroupFinderAddonRoleButton" .. spec.name, parent, "LFGRoleButtonTemplate")
	button.role = spec.role
	button:SetSize(GF.MAIN_WINDOW_ROLE_BUTTON_SIZE or 48, GF.MAIN_WINDOW_ROLE_BUTTON_SIZE or 48)
	if LFGRoleButtonTemplate_OnLoad then
		pcall(LFGRoleButtonTemplate_OnLoad, button)
	else
		local atlas = GF.ROLE_ICON_ATLAS and GF.ROLE_ICON_ATLAS[spec.role]
		if atlas and button.SetNormalAtlas then
			button:SetNormalAtlas(atlas, TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
		end
	end
	if button.checkButton then
		button.checkButton.onClick = onClick
	end
	button:SetScript("OnClick", function(self)
		if self._gfRoleAvailable ~= true or not self.checkButton or not self.checkButton:IsEnabled() then
			return
		end
		local checked = self.checkButton:GetChecked() == true
		self.checkButton:SetChecked(not checked)
		if PlaySound then
			PlaySound((not checked) and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		end
		if onClick then
			onClick(self.checkButton, "LeftButton")
		end
	end)
	setRoleButtonCheckHidden(button)
	return button
end

function MF:CreateRoleSelectionButtons()
	if self.roleButtonHost then
		return
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	local buttonSize = GF.MAIN_WINDOW_ROLE_BUTTON_SIZE or 48
	local gap = GF.MAIN_WINDOW_ROLE_BUTTON_GAP or 15
	local hostW = (#ROLE_BUTTON_SPECS * buttonSize) + ((#ROLE_BUTTON_SPECS - 1) * gap)
	local host = CreateFrame("Frame", "GroupFinderAddonRoleButtonHost", self.frame)
	host:SetSize(hostW, buttonSize)
	host:SetPoint(
		"TOPRIGHT",
		self.frame,
		"TOPRIGHT",
		-(GF.MAIN_WINDOW_ROLE_BUTTON_RIGHT_INSET or 64),
		-(GF.MAIN_WINDOW_ROLE_BUTTON_TOP_OFFSET or 42)
	)
	host:SetFrameLevel(self.frame:GetFrameLevel() + 80)
	self.roleButtonHost = host
	self.roleButtons = {}

	local previous
	for _, spec in ipairs(ROLE_BUTTON_SPECS) do
		local button = createRoleButton(host, spec, function()
			MF:SaveRoleSelection()
		end)
		if previous then
			button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
		else
			button:SetPoint("LEFT", host, "LEFT", 0, 0)
		end
		self.roleButtons[spec.key] = button
		previous = button
	end
	self:RefreshRoleSelectionButtons()
end

function MF:SaveRoleSelection()
	local leader = getLfgRoles()
	if SetLFGRoles then
		pcall(SetLFGRoles,
			leader,
			self.roleButtons and self.roleButtons.tank and self.roleButtons.tank.checkButton and self.roleButtons.tank.checkButton:GetChecked() == true,
			self.roleButtons and self.roleButtons.healer and self.roleButtons.healer.checkButton and self.roleButtons.healer.checkButton:GetChecked() == true,
			self.roleButtons and self.roleButtons.damager and self.roleButtons.damager.checkButton and self.roleButtons.damager.checkButton:GetChecked() == true)
	end
	self:RefreshRoleSelectionButtons()
end

function MF:RefreshRoleSelectionButtons()
	if not self.roleButtons then
		return
	end
	local canTank, canHealer, canDamager = getAvailableLfgRoles()
	if LFG_UpdateAvailableRoles then
		pcall(LFG_UpdateAvailableRoles, self.roleButtons.tank, self.roleButtons.healer, self.roleButtons.damager)
	else
		for key, canRole in pairs({ tank = canTank, healer = canHealer, damager = canDamager }) do
			local button = self.roleButtons[key]
			if button then
				button:SetEnabled(canRole == true)
				if button.checkButton then
					button.checkButton:SetShown(canRole == true)
					button.checkButton:SetEnabled(canRole == true)
				end
			end
		end
	end
	local _, tank, healer, damager = getLfgRoles()
	local roleStates = {
		tank = { available = canTank, checked = tank },
		healer = { available = canHealer, checked = healer },
		damager = { available = canDamager, checked = damager },
	}
	for key, state in pairs(roleStates) do
		local button = self.roleButtons[key]
		if button then
			button._gfRoleAvailable = state.available == true
			setRoleButtonChecked(button, state.available and state.checked)
			applyRoleButtonVisual(button, state.available, state.checked)
		end
	end
end

local function getPremadeCreateBlockMessage()
	if GF.Availability and GF.Availability.GetPremadeBlockMessage then
		return GF.Availability:GetPremadeBlockMessage()
	end
	return nil
end

function MF:UpdateNavInteractionState(tabID)
	tabID = tabID or (GF.TabBar and GF.TabBar:GetCurrent())
	if not (GF.NavTree and GF.NavTree.SetInteractionEnabled) then
		return
	end
	local enabled = true
	if tabID == GF.TAB_CREATE then
		local listing = GF.RecruitmentSession
		local hasActive = listing and listing.HasActive and listing:HasActive()
		if hasActive then
			enabled = listing and listing.CanManageApplicants and listing:CanManageApplicants()
		else
			enabled = listing and listing.CanPublish and listing:CanPublish()
		end
	end
	GF.NavTree:SetInteractionEnabled(enabled == true)
	if tabID == GF.TAB_CREATE and not enabled and self.SyncReadOnlyCreateNavSelection then
		self:SyncReadOnlyCreateNavSelection()
	end
end

function MF:SyncReadOnlyCreateNavSelection()
	if not (GF.NavTree and GF.NavTree.SetSelectedSilently) then
		return
	end
	local node, path
	local listing = GF.RecruitmentSession
	local hasActive = listing and listing.HasActive and listing:HasActive()
	if hasActive and listing.GetActiveActivityID then
		local activityID = listing:GetActiveActivityID()
		if GF.LFGWorkspaceView and GF.LFGWorkspaceView.IsMythicPlusActive
			and GF.LFGWorkspaceView:IsMythicPlusActive()
			and GF.NavData and GF.NavData.FindSeasonDungeonNodeByActivityID then
			node = GF.NavData.FindSeasonDungeonNodeByActivityID(activityID)
			if node and GF.NavTree.FindNodePathByKey then
				node, path = GF.NavTree:FindNodePathByKey(node.key)
			end
		else
			node, path = GF.NavTree:FindNodePathByActivityID(activityID)
		end
		if node and GF.LFGWorkspaceView and GF.LFGWorkspaceView.IsNodeAllowed
			and not GF.LFGWorkspaceView:IsNodeAllowed(node) then
			node, path = nil, nil
		end
		if path and path[1] then
			node = path[1]
			path = { node }
		end
	end
	if not node and GF.NavTree.FindNodePathByKey then
		node, path = GF.NavTree:FindNodePathByKey("season_dungeon")
	end
	if node then
		GF.NavTree:SetSelectedSilently(node, path)
	end
end

local zoneEventFrame

local function onZoneOrInstanceChanged()
	local frame, availability = MF.frame, GF.Availability
	if frame == nil or not frame:IsShown() or availability == nil then
		return
	end
	local blockMessage = availability:GetBlockMessage()
	if blockMessage then
		MF:HideFrame(true)
		availability:NotifyBlocked(blockMessage)
	end
end

function MF:SetZoneListenerEnabled(enable)
	if zoneEventFrame == nil then
		zoneEventFrame = CreateFrame("Frame")
		zoneEventFrame:SetScript("OnEvent", onZoneOrInstanceChanged)
	end
	local operation = enable and zoneEventFrame.RegisterEvent or zoneEventFrame.UnregisterEvent
	operation(zoneEventFrame, "PLAYER_ENTERING_WORLD")
end

local function markResizeState(owner, enabled, allowed)
	if allowed and owner then
		owner._frameResizing = enabled
	end
end

local function onMainResizeProgress(_, _, _, isActive)
	local active = isActive ~= false
	if active and MF._navDragFrozenW then
		invoke(MF, "NavWidthDragEnd", false)
	end
	GF._frameResizing = active

	local tabID = MF:GetCurrentTabID()
	local browseSurface = getFindGroupTab()
	if tabID == GF.TAB_BROWSE then
		invoke(browseSurface, "SetFrameResizing", active)
	end
	markResizeState(GF.NavTree, active, MF:NavVisibleForTab(tabID))
	markResizeState(GF.BlocklistPanel, active,
		tabID == GF.TAB_BLOCKLIST and surfaceReady("blocklist"))
	markResizeState(GF.SettingsPanel, active,
		tabID == GF.TAB_SETTINGS and surfaceReady("settings"))
	markResizeState(GF.CreatePanel, active,
		tabID == GF.TAB_CREATE and surfaceReady("create"))
	markResizeState(GF.ApplicantsPanel, active,
		tabID == GF.TAB_CREATE and surfaceReady("applicants"))
end

local function resetResizeOwner(owner, cancelMethod, initialized)
	if not (owner and initialized) then
		return
	end
	owner._frameResizing = false
	if cancelMethod then
		invoke(owner, cancelMethod)
	end
end

local function onMainResizeStopped(frame)
	GF._frameResizing = false
	local browseSurface = getFindGroupTab()
	invoke(browseSurface, "SetFrameResizing", false)
	invoke(browseSurface, "CancelRelayoutDebounce")
	if GF.NavTree then
		GF.NavTree._frameResizing = false
	end
	resetResizeOwner(GF.BlocklistPanel, nil, surfaceReady("blocklist"))
	resetResizeOwner(GF.SettingsPanel, "CancelUpdateScrollDebounce",
		surfaceReady("settings"))
	resetResizeOwner(GF.CreatePanel, "CancelUpdateScrollLayoutDebounce",
		surfaceReady("create"))
	resetResizeOwner(GF.ApplicantsPanel, "CancelRelayoutDebounce",
		surfaceReady("applicants"))
	GF.SaveFrameLayout(frame)
	MF:OnFrameResized()
end

local function mainWindowMouseDown(frame)
	GF.UI.RaiseFrame(frame)
	local tabID = activateMainFrameFocus()
	local clearOptions = tabID == GF.TAB_BROWSE and { preserveSelectedRoot = true } or nil
	invoke(GF.NavTree, "ClearActiveRoot", nil, clearOptions)
	if tabID == GF.TAB_CREATE and GF.CreatePanel and GF.CreatePanel.ActivateCreateChannel then
		GF.CreatePanel:ActivateCreateChannel()
	elseif GF.BlizzardBorrow and GF.BlizzardBorrow.SetActiveOwner then
		GF.BlizzardBorrow.SetActiveOwner("groupfinder")
	end
end

local function mainWindowHidden()
	return shellPresenter():OnViewHidden()
end

local createTitleAboutButton

local function createWindowShell(owner, locale)
	local templates = { "PortraitFrameTemplate", "SettingsFrameTemplate", "DefaultPanelTemplate" }
	local frame = GF.UI.CreateFrameWithTemplateOptions(
		"Frame", "GroupFinderAddonFrame", UIParent, templates)
	owner.frame = frame
	frame.frame = frame
	frame:SetSize(GF.FRAME_W, GF.FRAME_H)
	frame:SetFrameStrata(GF.FRAME_STRATA_DEFAULT or "MEDIUM")
	frame:SetFrameLevel(10)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:SetToplevel(true)
	frame:HookScript("OnMouseDown", mainWindowMouseDown)
	frame:SetScript("OnHide", mainWindowHidden)
	GF.ApplyFrameLayout(frame)

	GF.UI.ApplySettingsFrameChrome(frame, locale.ADDON_NAME or "GroupFinder")
	GF.UI.InstallMainWindowSkin(frame)
	local generatedName = (frame:GetName() or "") .. "CloseButton"
	local closeButton = frame.ClosePanelButton or frame.CloseButton or _G[generatedName]
	if closeButton == nil then
		closeButton = CreateFrame(
			"Button", "GroupFinderAddonMainCloseButton", frame, "UIPanelCloseButtonDefaultAnchors")
	end
	frame.ClosePanelButton = closeButton
	closeButton:Show()
	if GF.UI.ApplyCommonCloseButtonSkin then
		GF.UI.ApplyCommonCloseButtonSkin(closeButton)
	end
	closeButton:SetScript("OnClick", function()
		MF:HideFrame()
	end)
	-- 皮肤先用 HookScript 安装 hover 状态；Tooltip 也必须追加，不能以
	-- SetScript 覆盖主窗口独有的背景与 X 高光状态链。
	closeButton:HookScript("OnEnter", function(button)
		local text = (GF.L or {}).CLOSE or CLOSE or "Close"
		GF.UI.BeginGameTooltip(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 0.82, 0)
		GF.UI.ShowGameTooltip()
	end)
	closeButton:HookScript("OnLeave", GameTooltip_Hide)
	createTitleAboutButton(owner, closeButton)

	local dragBar = GF.UI.SetupTitleDragBar(frame, GF.SaveFrameLayout, function()
		invoke(GF.NavFlyout, "ReanchorOpenPanelPositions")
	end)
	if dragBar then
		dragBar:HookScript("OnMouseDown", activateMainFrameFocus)
	end
	if GF.UI.InstallRecruitEyeLogo then
		GF.UI.InstallRecruitEyeLogo(frame)
	end
	owner:CreateRoleSelectionButtons()
end

createTitleAboutButton = function(owner, closeButton)
	if not (owner and owner.frame and closeButton) then
		return nil
	end
	local frame = owner.frame
	local aboutButton = frame.AboutButton
		or CreateFrame("Button", "GroupFinderAddonMainAboutButton", frame)
	local buttonSize = closeButton.GetWidth and closeButton:GetWidth() or 24
	if not buttonSize or buttonSize <= 0 then
		buttonSize = 24
	end
	aboutButton:SetSize(buttonSize, buttonSize)
	aboutButton:SetFrameLevel(closeButton:GetFrameLevel())
	aboutButton:ClearAllPoints()
	aboutButton:SetPoint(
		"RIGHT",
		closeButton,
		"LEFT",
		-(GF.TITLE_ACTION_BUTTON_GAP or 2),
		0)
	GF.UI.ApplyCommonTitleActionButtonSkin(aboutButton, {
		iconTexture = GF.TITLE_ABOUT_BUTTON_ICON_TEXTURE
			or GF.COMMON_ATLAS_TEXTURE,
		iconTexCoords = GF.TITLE_ABOUT_BUTTON_ICON_TEXCOORD,
		iconScale = GF.TITLE_ABOUT_BUTTON_ICON_SCALE or (11.5 / 22),
		iconAspectRatio = GF.TITLE_ABOUT_BUTTON_ICON_ASPECT_RATIO or (13 / 29),
		iconShadow = GF.TITLE_ABOUT_BUTTON_ICON_SHADOW,
	})
	local versionBadge = aboutButton.versionDiscoveryBadge
		or aboutButton:CreateTexture(nil, "OVERLAY", nil, 7)
	versionBadge:ClearAllPoints()
	versionBadge:SetPoint("TOPRIGHT", aboutButton, "TOPRIGHT", 1, 1)
	versionBadge:SetSize(
		GF.VERSION_DISCOVERY_BADGE_SIZE or 11,
		GF.VERSION_DISCOVERY_BADGE_SIZE or 11)
	if not (GF.UI.TrySetAtlas and GF.UI.TrySetAtlas(
		versionBadge,
		GF.VERSION_DISCOVERY_BADGE_ATLAS
			or "communities-icon-notification",
		false))
	then
		versionBadge:SetColorTexture(1, 0.16, 0.12, 1)
	end
	versionBadge:Hide()
	aboutButton.versionDiscoveryBadge = versionBadge
	aboutButton:SetScript("OnClick", function()
		local dialog = GF.UsageGuideDialog
		if dialog and type(dialog.Show) == "function" then
			dialog:Show()
		end
	end)
	aboutButton:HookScript("OnEnter", function(button)
		local text = (GF.L or {}).USAGE_GUIDE_BTN
			or (GF.L or {}).USAGE_GUIDE_TITLE
			or "About"
		GF.UI.BeginGameTooltip(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 0.82, 0)
		local versionService = GF.VersionDiscoveryService
		local status = versionService and versionService.GetStatus
			and versionService:GetStatus() or nil
		if status and status.state == "confirmed" then
			GameTooltip:AddLine(string.format(
				(GF.L or {}).VERSION_DISCOVERY_BUTTON_CONFIRMED_FMT
					or "New version found: |cff00ff00%s|r",
				status.discoveredVersion), 1, 0.82, 0, true)
		end
		GF.UI.ShowGameTooltip()
	end)
	aboutButton:HookScript("OnLeave", function()
		GameTooltip_Hide()
	end)
	aboutButton:HookScript("OnHide", function()
		GameTooltip_Hide()
	end)

	owner.aboutButton = aboutButton
	frame.AboutButton = aboutButton
	local versionService = GF.VersionDiscoveryService
	if not owner._versionDiscoveryListenerBound
		and versionService and versionService.AddListener
	then
		versionService:AddListener(function()
			owner:RefreshVersionDiscoveryIndicator()
		end)
		owner._versionDiscoveryListenerBound = true
	end
	owner:RefreshVersionDiscoveryIndicator()
	return aboutButton
end

function MF:RefreshVersionDiscoveryIndicator()
	local button = self.aboutButton
	local badge = button and button.versionDiscoveryBadge
	if not badge then
		return
	end
	local service = GF.VersionDiscoveryService
	local status = service and service.GetStatus and service:GetStatus() or nil
	if status and status.state == "confirmed" then
		badge:Show()
	else
		badge:Hide()
	end
end

local function createFooter(owner)
	local frame = owner.frame
	local footer = CreateFrame("Frame", nil, frame)
	local footerBottom = GF.FRAME_FOOTER_BOTTOM_INSET or 2
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, footerBottom)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, footerBottom)
	footer:SetHeight(GF.FRAME_BODY_BOTTOM or 33)
	footer:SetFrameLevel(frame:GetFrameLevel() + 20)
	footer:EnableMouse(false)
	owner.footerHost, frame.footerHost = footer, footer
end

local function layoutHeaderActions(owner)
	local relative = owner.roleButtonHost
	local gap = -(GF.MAIN_WINDOW_ACTION_ROLE_GAP or 16)
	for index = #owner.headerActionButtons, 1, -1 do
		local button = owner.headerActionButtons[index]
		if button:IsShown() then
			button:ClearAllPoints()
			button:SetPoint("RIGHT", relative, "LEFT", gap, 0)
			relative = button
			gap = -(GF.FOOTER_ACTION_BUTTON_GAP or 0)
		end
	end
end

local function createHeaderActions(owner)
	local host = owner.roleButtonHost
	if not host then
		return
	end

	owner.headerActionButtons = {}
	local function addButton(field, factory)
		if not factory then return end
		local button = factory(host)
		if not button then return end
		owner[field] = button
		owner.headerActionButtons[#owner.headerActionButtons + 1] = button
	end
	addButton("greatVaultButton", GF.UI.CreateGreatVaultButton)
	addButton("keystoneLootButton", GF.UI.CreateKeystoneLootButton)
	addButton("seasonRatingButton", GF.UI.CreateSeasonRatingButton)
	if owner.keystoneLootButton then
		local function relayout() layoutHeaderActions(owner) end
		owner.keystoneLootButton:HookScript("OnShow", relayout)
		owner.keystoneLootButton:HookScript("OnHide", relayout)
	end
	if #owner.headerActionButtons > 0 and GF.ColumnHeaderBar then
		local divider = GF.ColumnHeaderBar:CreateDivider(host, GF.TABLE_HEADER_STYLE.dividerHeight)
		divider:SetPoint("CENTER", host, "LEFT", -(GF.MAIN_WINDOW_ACTION_ROLE_GAP or 16) / 2, 0)
		divider:EnableMouse(false)
		owner.headerActionDivider = divider
	end
	layoutHeaderActions(owner)
end

local function createContentHosts(owner, horizontalPadding, topPadding, bottomPadding)
	local frame = owner.frame
	local backplate = GF.UI.CreatePanelBackplate(frame)
	owner.panelBackplate, owner.layoutHost = backplate, backplate
	frame.panelBackplate = backplate
	createFooter(owner)
	createHeaderActions(owner)

	local navigation = CreateFrame("Frame", nil, backplate)
	navigation:SetPoint("TOPLEFT", backplate, "TOPLEFT", horizontalPadding, -topPadding)
	navigation:SetPoint("BOTTOMLEFT", backplate, "BOTTOMLEFT", horizontalPadding, bottomPadding)
	navigation:SetWidth(GF.GetNavWidth())
	navigation:SetClipsChildren(true)
	navigation:SetFrameLevel(backplate:GetFrameLevel() + 5)
	owner.navHost = navigation

	local clip = CreateFrame("Frame", nil, backplate)
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(backplate:GetFrameLevel() + 5)
	local content = GF.UI.CreateContentPanel(clip)
	local contentInset = -math.min(0, GF.LFG_LIST_CHROME_LEFT_INSET or 0)
	content:SetPoint("TOPLEFT", clip, "TOPLEFT", contentInset, 0)
	content:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
	local body = CreateFrame("Frame", nil, content)
	body:SetFrameLevel(content:GetFrameLevel() + 1)
	owner.contentClip, owner.content, owner.contentBody = clip, content, body

	local auxiliaryClip = CreateFrame("Frame", nil, backplate)
	auxiliaryClip:SetClipsChildren(true)
	auxiliaryClip:SetFrameLevel(backplate:GetFrameLevel() + 5)
	auxiliaryClip:Hide()
	local auxiliary = GF.UI.CreateContentPanel(auxiliaryClip)
	auxiliary:SetAllPoints(auxiliaryClip)
	local auxiliaryBody = CreateFrame("Frame", nil, auxiliary)
	auxiliaryBody:SetAllPoints(auxiliary)
	auxiliaryBody:SetFrameLevel(auxiliary:GetFrameLevel() + 1)
	owner.auxContentClip, owner.auxContent, owner.auxContentBody = auxiliaryClip, auxiliary, auxiliaryBody
	owner:LayoutAuxContent()

	local block = CreateFrame("Frame", nil, backplate)
	block:SetClipsChildren(true)
	block:SetFrameLevel(backplate:GetFrameLevel() + 5)
	block:Hide()
	owner.blockContent = block
end

local function initializeWindowSurfaces(owner, initialRoute)
	GF.SubtitleBar:Init(owner.content, 0)
	GF.NavTree:Init(owner.navHost)

	local filterState = GF.MythicPlusBrowseFilter
	if not owner._mythicPlusBrowseFilterListenerBound and filterState and filterState.AddListener then
		filterState:AddListener(function(_, reason)
			MF:OnMythicPlusBrowseFilterChanged(reason)
		end)
		owner._mythicPlusBrowseFilterListenerBound = true
	end
	owner:LayoutContent(false)

	local initialWorkspaceID = initialRoute and initialRoute.workspaceID
	GF.TabBar:Init(owner.frame, {
		workspaceID = initialWorkspaceID,
	})
	GF.WorkspaceBar:Init(owner.frame, owner, {
		workspaceID = initialWorkspaceID,
	})
	invoke(GF.BlocklistPanel, "ApplyModuleVisibility")
	owner.frame.OnTabChanged = function(_, tabID)
		owner:OnTabChanged(tabID)
	end
end

local function createFooterStatus(owner)
	local activity = GF.UI.CreateFontString(owner.footerHost, "OVERLAY", "GameFontDisableSmall")
	activity:SetPoint("RIGHT", owner.footerHost, "RIGHT", -(GF.ACTIVITY_COUNT_RIGHT or 28), 0)
	activity:SetJustifyH("RIGHT")
	activity:Hide()
	owner.activityCount = activity

	local hint = GF.UI.CreateFontString(owner.footerHost, "OVERLAY", "GameFontHighlight")
	hint:SetPoint("CENTER", owner.footerHost, "CENTER", 48, 0)
	hint:SetTextColor(1, 0.82, 0)
	hint:SetJustifyH("CENTER")
	hint:Hide()
	owner.browseStatusHint = hint
end

local function finishWindowInitialization(owner)
	GF.UI.AttachResizeController(owner.frame, {
		minW = GF.FRAME_MIN_W,
		minH = GF.FRAME_MIN_H,
		onResize = onMainResizeProgress,
		onResizeStopped = onMainResizeStopped,
	})
	owner.frame:Hide()
	if UISpecialFrames then
		tinsert(UISpecialFrames, owner.frame:GetName())
	end
	if GF.ApplyFrameStrata then
		GF.ApplyFrameStrata()
	end
	if GF.ApplyPanelScale then
		GF.ApplyPanelScale()
	end
	owner:RefreshRecruitEyeLogo()
end

function MF:Init(initialRoute, opts)
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	-- An explicit component load may have completed before this first window
	-- action. Preserve the initial selection before constructing its surfaces.
	local nav = GF.NavData
	if nav and type(nav.GetLoadedTree) == "function"
		and nav.GetLoadedTree() == nil and type(nav.GetTree) == "function"
	then nav.GetTree() end
	opts = opts or {}
	if self._windowInited == true then
		return true
	end
	if self._windowInitState == "initializing" then
		return false
	end
	if self.frame ~= nil then
		error("GroupFinder main window initialization is incomplete", 0)
	end
	self._windowInitState = "initializing"
	self._initializingWindow = true
	local ok, initError = pcall(function()
		if GF.EnsureBlizzardAddons then
			GF.EnsureBlizzardAddons()
		end
		shellPresenter():ResetSelection()
		invoke(GF.CreatePanel, "InstallEntryCreationHooks")
		createWindowShell(self, GF.L or {})
		createContentHosts(
			self,
			GF.MAIN_PANEL_CONTENT_PADDING_X or 18,
			GF.MAIN_PANEL_CONTENT_PADDING_TOP or 24,
			GF.MAIN_PANEL_CONTENT_PADDING_BOTTOM or 16)
		initializeWindowSurfaces(self, initialRoute)
		createFooterStatus(self)
		finishWindowInitialization(self)
	end)
	self._initializingWindow = nil
	self._windowInitState = nil
	if not ok then
		error(initError, 0)
	end
	self._windowInited = true
	self._windowSurfacesReady = true
	local workspaceBar = GF.WorkspaceBar
	if workspaceBar and workspaceBar.GetCurrent then
		self:OnWorkspaceChanged(workspaceBar:GetCurrent(), nil, {
			silent = true,
			targetTabID = initialRoute and initialRoute.tabID,
			deferSurface = opts.deferInitialSurface == true,
		})
	end
	return true
end

function MF:GetCurrentTabID()
	return workspaceRouter():GetCurrentTabID()
end

function MF:GetCurrentWorkspaceID()
	return workspaceRouter():GetWorkspaceID()
end

function MF:NavVisibleForTab(tabID)
	tabID = tabID or self:GetCurrentTabID()
	if GF.MythicPlusWorkspace and GF.MythicPlusWorkspace.IsWorkspaceTab
		and GF.MythicPlusWorkspace:IsWorkspaceTab(tabID) then
		return false
	end
	return tabID ~= GF.TAB_SETTINGS and tabID ~= GF.TAB_BLOCKLIST
		and tabID ~= GF.TAB_STARRED_LEADERS
		and tabID ~= GF.TAB_RAID_SEEK and tabID ~= GF.TAB_RAID_SQUARE
end

function MF:IsMythicPlusBrowseFilterVisible(tabID)
	tabID = tabID or self:GetCurrentTabID()
	return tabID == GF.TAB_BROWSE
		and self:GetCurrentWorkspaceID() == GF.WORKSPACE_MYTHIC_PLUS
end

function MF:IsMythicPlusCreateManagerVisible(tabID)
	tabID = tabID or self:GetCurrentTabID()
	if tabID ~= GF.TAB_CREATE then
		return false
	end
	local createManager = GF.MythicPlusCreateManagerPanel
	if createManager and createManager.ShouldUse then
		return createManager:ShouldUse(
			tabID,
			self:GetCurrentWorkspaceID()
		)
	end
	return self:GetCurrentWorkspaceID() == GF.WORKSPACE_MYTHIC_PLUS
end

function MF:UpdateBrowseSidePanel(tabID, showNav)
	showNav = showNav ~= false
	local wantsCreateManager = showNav
		and self:IsMythicPlusCreateManagerVisible(tabID)
	local raidPanel = GF.RaidBrowsePanel
	local wantsRaid = showNav and not wantsCreateManager and raidPanel and raidPanel:ShouldUse(
		tabID or self:GetCurrentTabID(), self:GetCurrentWorkspaceID())
	if wantsRaid and not raidPanel.frame and self.navHost then
		raidPanel:Init(self.navHost)
	end
	local showRaid = wantsRaid and raidPanel.frame ~= nil or false
	local filterPanel = GF.MythicPlusBrowseFilterPanel
	local wantsFilter = showNav
		and self:IsMythicPlusBrowseFilterVisible(tabID)
	local createManager = GF.MythicPlusCreateManagerPanel
	if wantsFilter and filterPanel and not filterPanel.frame
		and filterPanel.Init and self.navHost
	then
		filterPanel:Init(self.navHost)
	end
	if wantsCreateManager and createManager and not createManager.frame
		and createManager.Init and self.navHost
	then
		createManager:Init(self.navHost)
	end
	local showFilter = wantsFilter
		and filterPanel
		and filterPanel.frame
		and true
		or false
	local showCreateManager = wantsCreateManager
		and createManager
		and createManager.frame
		and true
		or false
	if (showFilter or showCreateManager or showRaid)
		and GF.NavFlyout and GF.NavFlyout.HideAll
	then
		GF.NavFlyout:HideAll()
	end
	if GF.NavTree and GF.NavTree.SetVisible then
		GF.NavTree:SetVisible(
			showNav and not showFilter and not showCreateManager and not showRaid
		)
	end
	if GF.SubtitleBar and GF.SubtitleBar.SetMythicPlusSidebarMode then
		GF.SubtitleBar:SetMythicPlusSidebarMode(showFilter)
	end
	if filterPanel and filterPanel.SetVisible then
		filterPanel:SetVisible(showFilter)
	end
	if createManager and createManager.SetVisible then
		createManager:SetVisible(showCreateManager)
	end
	if raidPanel then raidPanel:SetVisible(showRaid) end
	return showFilter
end

function MF:AuxContentVisibleForTab(tabID)
	tabID = tabID or self:GetCurrentTabID()
	return tabID == GF.TAB_SETTINGS
		or tabID == GF.TAB_STARRED_LEADERS
		or tabID == GF.TAB_RAID_SEEK or tabID == GF.TAB_RAID_SQUARE
		or (GF.MythicPlusWorkspace and GF.MythicPlusWorkspace.IsWorkspaceTab
			and GF.MythicPlusWorkspace:IsWorkspaceTab(tabID))
end

function MF:IsAuxPanelHost(hostKey)
	return hostKey == "settingsHost" or hostKey == "starredHost" or hostKey == "seekingHost"
end

function MF:EnsurePanelHost(hostKey)
	local existing = self[hostKey]
	if existing ~= nil then
		return existing
	end
	local auxiliary = self:IsAuxPanelHost(hostKey)
	local parent = auxiliary and self.auxContentBody or (self.contentBody or self.content)
	local created = CreateFrame("Frame", nil, parent)
	created:SetAllPoints()
	created:SetFrameLevel((parent:GetFrameLevel() or self.content:GetFrameLevel()) + 2)
	created:Hide()
	self[hostKey] = created
	return created
end

function MF:EnsureBrowseSurface()
	return shellPresenter():EnsureBrowseSurface()
end

function MF:EnsureCreatePanel(opts)
	return shellPresenter():EnsureCreatePanel(opts)
end

function MF:EnsureCreateDrawer()
	return shellPresenter():EnsureCreateDrawer()
end

function MF:EnsureApplicantsPanel()
	return shellPresenter():EnsureApplicantsPanel()
end

function MF:EnsureMythicPlusWorkspace()
	return shellPresenter():EnsureMythicPlusWorkspace()
end

function MF:EnsureSettingsPanel()
	return shellPresenter():EnsureSettingsPanel()
end

function MF:EnsureBlocklistPanel()
	return shellPresenter():EnsureBlocklistPanel()
end

function MF:EnsureCreateTabPanels(opts)
	return shellPresenter():EnsureCreateTabPanels(opts)
end

function MF:EnsureMythicPlusSidePanels()
	return shellPresenter():EnsureMythicPlusSidePanels()
end

function MF:UpdateActivityCount(count)
	local label = self.activityCount
	if label == nil then
		return
	end
	if invoke(GF.TabBar, "GetCurrent") ~= GF.TAB_BROWSE then
		label:Hide()
		return
	end
	local visibleCount = count or 0
	local totalCount = invoke(GF.Result, "GetRawCount") or visibleCount
	local locale = GF.L or {}
	if totalCount > visibleCount then
		local formatText = locale.ACTIVITY_COUNT_TOTAL_FMT or "活动总数：%d/%d"
		label:SetText(string.format(formatText, visibleCount, totalCount))
	else
		local formatText = locale.ACTIVITY_COUNT_FMT or "当前活动数：%d"
		label:SetText(string.format(formatText, visibleCount))
	end
	label:Show()
end

function MF:UpdateBrowseStatusHint(text)
	local hint = self.browseStatusHint
	if hint == nil then
		return
	end
	local shouldShow = text ~= nil and text ~= "" and GF.TabBar ~= nil
		and invoke(GF.TabBar, "GetCurrent") == GF.TAB_BROWSE
	if not shouldShow then
		hint:Hide()
		return
	end
	hint:SetText(text)
	hint:Show()
end

function MF:LayoutContentBody()
	local body, content = self.contentBody, self.content
	if body == nil or content == nil then
		return
	end
	local subtitle = GF.SubtitleBar
	local subtitleFrame = subtitle and subtitle.frame
	local header = subtitle and subtitle.columnHeaderHost
	local browseHeaderVisible = subtitle and subtitle._browseMode and subtitleFrame
		and subtitleFrame:IsShown()
	body:ClearAllPoints()
	if browseHeaderVisible then
		if header then
			local gap = -(GF.BROWSE_HEADER_LIST_GAP or 4)
			body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, gap)
		else
			body:SetPoint("TOPLEFT", content, "TOPLEFT")
		end
		-- The header reserves space for its refresh button. Only borrow its
		-- top/left; the full-width footer shares the blacklist's right edge.
		body:SetPoint("BOTTOMRIGHT", subtitleFrame, "TOPRIGHT", 0,
			GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
	else
		body:SetPoint("TOPLEFT", content, "TOPLEFT")
		body:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT")
	end
	invoke(GF.CreateDrawer, "Layout")
end

function MF:LayoutAuxContent()
	local clip = self.auxContentClip
	if clip == nil or self.auxContent == nil or self.auxContentBody == nil
		or self._auxContentLayoutApplied then
		return
	end
	local host = self.layoutHost or self.frame
	if host == nil then
		return
	end
	clip:SetPoint("TOPLEFT", host, "TOPLEFT",
		GF.MAIN_PANEL_BACKPLATE_BG_INSET_LEFT or 5,
		-(GF.MAIN_PANEL_BACKPLATE_BG_INSET_TOP or 2))
	clip:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT",
		-(GF.MAIN_PANEL_BACKPLATE_BG_INSET_RIGHT or 5),
		GF.MAIN_PANEL_BACKPLATE_BG_INSET_BOTTOM or 10)
	self._auxContentLayoutApplied = true
end

function MF:LayoutBlockContent()
	local block = self.blockContent
	if block == nil then
		return
	end
	local host = self.layoutHost or self.frame
	local anchor = host and host._gfPanelBackground or host
	if anchor == nil then
		return
	end
	block:ClearAllPoints()
	block:SetAllPoints(anchor)
end

function MF:NavWidthDragBegin()
	local content, clip, frame = self.content, self.contentClip, self.frame
	if content == nil or clip == nil or frame == nil then
		return
	end
	local frozenWidth = GF.GetNavContentWidth(frame:GetWidth() or GF.FRAME_W or 900, GF.GetNavWidth())
	self._navDragFrozenW = frozenWidth
	local contentInset = -math.min(0, GF.LFG_LIST_CHROME_LEFT_INSET or 0)
	content:ClearAllPoints()
	content:SetPoint("TOPLEFT", clip, "TOPLEFT", contentInset, 0)
	content:SetPoint("TOPRIGHT", clip, "TOPLEFT", contentInset + frozenWidth, 0)
	content:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", contentInset, 0)
	content:SetPoint("BOTTOMRIGHT", clip, "BOTTOMLEFT", contentInset + frozenWidth, 0)
	GF._frameResizing = true
end

function MF:NavWidthDragPreview(w)
	local navigation = self.navHost
	if navigation == nil then
		return
	end
	local width = GF.ClampNavWidth(w)
	if self._navDragPreviewW == width then
		return
	end
	self._navDragPreviewW = width
	navigation:SetWidth(width)
end

function MF:NavWidthDragEnd(save, previewW)
	if self._navDragFrozenW == nil then
		return
	end
	local candidate = previewW or self._navDragPreviewW or GF.GetNavWidth()
	local width = GF.ClampNavWidth(candidate)
	self._navDragPreviewW, self._navDragFrozenW = nil, nil
	GF._frameResizing = false
	if save then
		width = GF.SaveNavWidth(width)
	else
		width = GF.GetNavWidth()
	end
	self.navHost:SetWidth(width)
	self:LayoutContent(false)
	if save then
		invoke(GF.NavTree, "SyncAfterHostWidth", width)
		self:ApplyFrameResize()
	end
end

function MF:LayoutContent(fullWidth)
	local clip, content, frame, navigation = self.contentClip, self.content, self.frame, self.navHost
	if clip == nil or content == nil or frame == nil or navigation == nil then
		return
	end
	local layoutHost = self.layoutHost or frame
	local padX = GF.MAIN_PANEL_CONTENT_PADDING_X or GF.FRAME_PAD or 4
	local padTop = GF.MAIN_PANEL_CONTENT_PADDING_TOP or (GF.FRAME_TITLE_TOP + 2)
	local padBottom = GF.MAIN_PANEL_CONTENT_PADDING_BOTTOM or GF.FRAME_CONTENT_BOTTOM
	-- Include the footer atlas's left overhang in the same clipping surface
	-- as its controls. Counter-inset content to preserve all page geometry.
	local contentInset = -math.min(0, GF.LFG_LIST_CHROME_LEFT_INSET or 0)
	clip:ClearAllPoints()
	if fullWidth then
		clip:SetPoint("TOPLEFT", layoutHost, "TOPLEFT", padX - contentInset, -padTop)
		clip:SetPoint("BOTTOMRIGHT", layoutHost, "BOTTOMRIGHT", -padX, padBottom)
	else
		clip:SetPoint("TOPLEFT", navigation, "TOPRIGHT", (GF.CONTENT_NAV_OFFSET_X or 0) - contentInset, 0)
		clip:SetPoint("BOTTOMRIGHT", layoutHost, "BOTTOMRIGHT", -padX, padBottom)
	end
	if not self._navDragFrozenW then
		content:ClearAllPoints()
		content:SetPoint("TOPLEFT", clip, "TOPLEFT", contentInset, 0)
		content:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
	end
	self:LayoutContentBody()
end

function MF:UpdateCreateTab(opts)
	if self._windowSurfacesReady ~= true or not self:IsUserVisible()
		or self._initializingWindow == true
		or not GF.TabBar or GF.TabBar:GetCurrent() ~= GF.TAB_CREATE then
		return
	end
	opts = opts or {}
	if not self:EnsureCreateTabPanels() then
		return
	end
	self:UpdateBrowseSidePanel(
		GF.TAB_CREATE,
		self:NavVisibleForTab(GF.TAB_CREATE)
	)
	local hasActive = GF.RecruitmentSession
		and GF.RecruitmentSession.HasActivePresentation
		and GF.RecruitmentSession:HasActivePresentation()
	if hasActive == nil then
		hasActive = GF.RecruitmentSession and GF.RecruitmentSession:HasActive()
	end
	if self.applicantsHost then
		self.applicantsHost:Show()
	end
	GF.ApplicantsPanel:Show()
	self:UpdateNavInteractionState(GF.TAB_CREATE)
	if GF.CreateDrawer then
		GF.CreateDrawer:SetTabActive(true)
		local createManager = GF.MythicPlusCreateManagerPanel
		if createManager and createManager.ShouldUse
			and createManager:ShouldUse()
		then
			createManager:Open({
				forceEdit = opts.forceEdit == true,
			})
		elseif not hasActive and getPremadeCreateBlockMessage() then
			GF.CreateDrawer:Close(true)
		else
			GF.CreateDrawer:SyncDefaultState(hasActive, {
				allowOccupiedPrompt = opts.allowOccupiedPrompt == true,
				allowCreateAutoOpen = opts.allowCreateAutoOpen == true,
				suppressCreateAutoOpen = opts.suppressCreateAutoOpen == true,
			})
		end
	end
	if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateToolbarForListed then
		GF.ApplicantsPanel:UpdateToolbarForListed()
	end
end

function MF:RefreshListingPanels()
	self:UpdateNavInteractionState()
	if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateManageState then
		GF.ApplicantsPanel:UpdateManageState()
	end
	if GF.CreatePanel and GF.CreatePanel.UpdateManageState then
		GF.CreatePanel:UpdateManageState()
	end
end

function MF:RefreshRecruitEyeLogo(hasActive)
	if not self.frame or not GF.UI or not GF.UI.SetRecruitEyeLogoActive then
		return
	end
	if hasActive == nil then
		hasActive = self:HasActiveListing()
	end
	GF.UI.SetRecruitEyeLogoActive(self.frame, hasActive == true)
end

function MF:CancelRecruitmentEventBatch()
	return shellPresenter():CancelRecruitmentEventBatch()
end

function MF:FlushRecruitmentEventBatch(batch)
	return shellPresenter():FlushRecruitmentEventBatch(batch)
end

function MF:QueueRecruitmentEvent(event)
	return shellPresenter():QueueRecruitmentEvent(event)
end

function MF:OnGroupRosterChanged(event)
	return shellPresenter():OnGroupRosterChanged(event)
end

function MF:OnMythicPlusBrowseFilterChanged(reason)
	return shellPresenter():OnMythicPlusBrowseFilterChanged(reason)
end

function MF:FlushPendingMythicPlusBrowseFilterChange()
	return shellPresenter():FlushPendingMythicPlusBrowseFilterChange()
end

function MF:OnTabChanged(tabID, opts)
	return shellPresenter():OnTabChanged(tabID, opts)
end

function MF:OnWorkspaceChanged(workspaceID, previousWorkspaceID, opts)
	return shellPresenter():OnWorkspaceChanged(
		workspaceID, previousWorkspaceID, opts)
end

function MF:OnSelectionChanged(node, opts)
	return shellPresenter():OnSelectionChanged(node, opts)
end

function MF:OnFrameResized()
	invoke(self._resizeDebounce, "Cancel")
	local timers = C_Timer
	if not (timers and timers.NewTimer) then
		self:ApplyFrameResize()
		return
	end
	self._resizeDebounce = timers.NewTimer(GF.LAYOUT_RESIZE_DEBOUNCE or 0.1, function()
		MF._resizeDebounce = nil
		MF:ApplyFrameResize()
	end)
end

local function resizeBrowseSurface(surface)
	if not (surface and surface.Relayout) then
		return
	end
	invoke(surface, "SuppressRelayout", 0.25)
	invoke(surface, "CancelRelayoutDebounce")
	surface:Relayout()
	local browsePanel = invoke(surface, "GetPanel")
	invoke(browsePanel, "FlushRowVisibility")
end

local function resizeCreateSurfaces(owner)
	local applicants = GF.ApplicantsPanel
	if applicants and surfaceReady("applicants") and applicants.Relayout then
		applicants._relayoutSuppressUntil = GetTime() + 0.25
		invoke(applicants, "CancelRelayoutDebounce")
		applicants:Relayout()
	end
	if not (GF.CreatePanel and surfaceReady("create")) then
		return
	end
	local manager = GF.MythicPlusCreateManagerPanel
	if manager and manager.IsShown and manager:IsShown() then
		invoke(manager, "Layout")
	end
	invoke(GF.CreatePanel, "CancelUpdateScrollLayoutDebounce")
	invoke(GF.CreatePanel, "UpdateScrollLayout")
end

function MF:ApplyFrameResize()
	local tabID = self:GetCurrentTabID()
	if self:AuxContentVisibleForTab(tabID) then
		self:LayoutAuxContent()
	end
	if tabID == GF.TAB_BLOCKLIST then
		self:LayoutBlockContent()
	end
	if tabID == GF.TAB_BROWSE and surfaceReady("browse") then
		resizeBrowseSurface(getFindGroupTab())
	end
	local plainNavigation = self:NavVisibleForTab(tabID)
		and not self:IsMythicPlusBrowseFilterVisible(tabID)
		and not self:IsMythicPlusCreateManagerVisible(tabID)
		and not (GF.RaidBrowsePanel and GF.RaidBrowsePanel:ShouldUse(
			tabID, self:GetCurrentWorkspaceID()))
	if plainNavigation then
		invoke(GF.NavTree, "CancelLayoutDebounce")
		invoke(GF.NavTree, "ScheduleLayoutRows")
	end
	if tabID == GF.TAB_SETTINGS and surfaceReady("settings") then
		invoke(GF.SettingsPanel, "UpdateScroll")
	end
	local filterPanel = GF.FilterPanel
	if filterPanel and filterPanel.IsShown and filterPanel:IsShown() then
		invoke(filterPanel, "AnchorToMain")
	end
	if tabID == GF.TAB_CREATE then
		resizeCreateSurfaces(self)
	end
	if tabID == GF.TAB_BLOCKLIST and surfaceReady("blocklist") then
		invoke(GF.BlocklistPanel, "Refresh")
	end
end

function MF:OnSearchResults()
	invoke(GF.FindGroupTab, "OnSearchResults")
end

function MF:OnSearchFailed()
	invoke(GF.FindGroupTab, "OnSearchFailed")
end

function MF:OnAvailabilityUpdate(opts)
	return shellPresenter():OnAvailabilityUpdate(opts)
end

function MF:OnPremadePermissionUpdate()
	return shellPresenter():OnPremadePermissionUpdate()
end

function MF:ResetCreateAfterManualRemove()
	return shellPresenter():ResetCreateAfterManualRemove()
end

function MF:OnActiveEntryUpdate(opts)
	return shellPresenter():OnActiveEntryUpdate(opts)
end

function MF:OnApplicantsUpdate(event)
	return shellPresenter():OnApplicantsUpdate(event)
end

function MF:FlushDeferredNavigationBeforeShow()
	return shellPresenter():FlushDeferredNavigationBeforeShow()
end

function MF:WarmPreloadedSurfaceLayouts(phase)
	return shellPresenter():WarmPreloadedSurfaceLayouts(phase)
end

function MF:FinishSurfacePreload(ticket, completed)
	return shellPresenter():FinishSurfacePreload(ticket, completed)
end

function MF:CancelSurfacePreload()
	return shellPresenter():CancelSurfacePreload()
end

function MF:RunSurfacePreloadPass(ticket, phase)
	return shellPresenter():RunSurfacePreloadPass(ticket, phase)
end

function MF:BeginSurfacePreload()
	return shellPresenter():BeginSurfacePreload()
end

function MF:Preload()
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():Preload()
end

function MF:RequestPreload(delay)
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():RequestPreload(delay)
end

function MF:ResumePreload()
	return shellPresenter():ResumePreload()
end

function MF:BeginFirstPresentationGate(surfaceKey, options)
	return shellPresenter():BeginFirstPresentationGate(surfaceKey, options)
end

function MF:ReleaseFirstPresentationGateInteraction()
	return shellPresenter():ReleaseFirstPresentationGateInteraction()
end

function MF:HoldFirstPresentationGate(ticket)
	return shellPresenter():HoldFirstPresentationGate(ticket)
end

function MF:FinishFirstPresentationGate(ticket, completed)
	return shellPresenter():FinishFirstPresentationGate(ticket, completed)
end

function MF:CancelFirstPresentationGate()
	return shellPresenter():CancelFirstPresentationGate()
end

function MF:RunFirstPresentationGate(ticket)
	return shellPresenter():RunFirstPresentationGate(ticket)
end

function MF:ScheduleFirstPresentationGate(ticket)
	return shellPresenter():ScheduleFirstPresentationGate(ticket)
end

function MF:ApplyOpenRoute(route, opts)
	return shellPresenter():ApplyOpenRoute(route, opts)
end

function MF:ShowFrame(route)
	return shellPresenter():ShowFrame(route)
end

function MF:RefreshLocale()
	invoke(GF.StarredLeadersPanel, "Refresh")
	invoke(GF.RaidSeekingPanel, "Refresh", true)
	local L = GF.L or {}
	if self.frame then
		GF.UI.ApplySettingsFrameChrome(self.frame, L.ADDON_NAME or "GroupFinder")
	end
	-- Header labels are late-bound locale values. Repaint every created shared
	-- header immediately, including hidden/cold surfaces whose layout cannot run.
	if GF.ColumnHeaderBar and GF.ColumnHeaderBar.RefreshLocale then
		GF.ColumnHeaderBar:RefreshLocale()
	end
	if GF.BlacklistConfirmDialog
		and GF.BlacklistConfirmDialog.RefreshLocale
	then
		GF.BlacklistConfirmDialog:RefreshLocale()
	end
	if self.greatVaultButton and GF.UI.RefreshGreatVaultButton then
		GF.UI.RefreshGreatVaultButton(self.greatVaultButton, true)
	end
	if self.keystoneLootButton and GF.UI.RefreshKeystoneLootButton then
		GF.UI.RefreshKeystoneLootButton(self.keystoneLootButton, true)
	end
	if GF.TabBar and GF.TabBar.RefreshLocale then
		GF.TabBar:RefreshLocale()
	end
	if GF.WorkspaceBar and GF.WorkspaceBar.RefreshLocale then
		GF.WorkspaceBar:RefreshLocale()
	end
	if surfaceReady("mythicPlusWorkspace")
		and GF.MythicPlusWorkspace and GF.MythicPlusWorkspace.RefreshLocale
	then
		GF.MythicPlusWorkspace:RefreshLocale()
	end
	if GF.MythicPlusBrowseFilterPanel
		and GF.MythicPlusBrowseFilterPanel.RefreshLocale
	then
		GF.MythicPlusBrowseFilterPanel:RefreshLocale()
	end
	if GF.MythicPlusCreateManagerPanel
		and GF.MythicPlusCreateManagerPanel.RefreshLocale
	then
		GF.MythicPlusCreateManagerPanel:RefreshLocale()
	end
	local fg = getFindGroupTab()
	if surfaceReady("browse") and fg then
		if fg.UpdateTitle then
			fg:UpdateTitle()
		end
		if fg.UpdateSearchHint then
			fg:UpdateSearchHint()
		end
		if fg.RefreshResults then
			fg:RefreshResults({ preserveScroll = true })
		end
	end
	if GF.SubtitleBar then
		if GF.SubtitleBar.RefreshLocale then
			GF.SubtitleBar:RefreshLocale()
		else
			if GF.SubtitleBar.UpdateRefreshButtonState then
				GF.SubtitleBar:UpdateRefreshButtonState()
			end
			if GF.SubtitleBar.UpdateResetButtonState then
				GF.SubtitleBar:UpdateResetButtonState()
			end
			if GF.SubtitleBar.UpdateSignUpButtonState then
				GF.SubtitleBar:UpdateSignUpButtonState()
			end
		end
	end
	if GF.FilterPanel and GF.FilterPanel.RebuildIfNeeded then
		GF.FilterPanel:RebuildIfNeeded(true)
		if GF.FilterPanel.UpdateSearchButtonState then
			GF.FilterPanel:UpdateSearchButtonState()
		end
	end
	if GF.NavData and GF.NavData.RefreshLocaleLabels then
		GF.NavData.RefreshLocaleLabels()
	end
	invoke(GF.RaidBrowsePanel, "RefreshLocale")
	if GF.NavTree and GF.NavTree.Refresh then
		GF.NavTree:Refresh()
	end
	if GF.NavFlyout and GF.NavFlyout.RefreshLocale then
		GF.NavFlyout:RefreshLocale()
	end
	if surfaceReady("create")
		and GF.CreatePanel and GF.CreatePanel.RefreshLocale
	then
		GF.CreatePanel:RefreshLocale()
	end
	if GF.CensoredActiveEntryDialog
		and GF.CensoredActiveEntryDialog.RefreshLocale
	then
		GF.CensoredActiveEntryDialog:RefreshLocale()
	end
	if GF.FavoriteActivityDialog
		and GF.FavoriteActivityDialog.RefreshLocale
	then
		GF.FavoriteActivityDialog:RefreshLocale()
	end
	if surfaceReady("applicants")
		and GF.ApplicantsPanel
	then
		if GF.ApplicantsPanel.RefreshLocale then
			GF.ApplicantsPanel:RefreshLocale()
		end
		if GF.ApplicantsPanel.Refresh then
			GF.ApplicantsPanel:Refresh({ preserveScroll = true })
		end
	end
	if surfaceReady("blocklist")
		and GF.BlocklistPanel and GF.BlocklistPanel.RefreshLocale
	then
		GF.BlocklistPanel:RefreshLocale()
	elseif surfaceReady("blocklist")
		and GF.BlocklistPanel and GF.BlocklistPanel.Refresh
	then
		GF.BlocklistPanel:Refresh()
	end
	if GF.BlacklistMenu and GF.BlacklistMenu.RefreshLocale then
		GF.BlacklistMenu:RefreshLocale()
	end
	if surfaceReady("settings")
		and GF.SettingsPanel and GF.SettingsPanel.RefreshLocale
	then
		GF.SettingsPanel:RefreshLocale()
	end
	invoke(GF.UserLetterDialog, "RefreshLocale")
	if GF.UsageGuideDialog and GF.UsageGuideDialog.RefreshLocale then
		GF.UsageGuideDialog:RefreshLocale()
	end
	if GF.FloatButton and GF.FloatButton.Refresh then
		GF.FloatButton:Refresh()
	end
	if GF.MinimapButton and GF.MinimapButton.Apply then
		GF.MinimapButton:Apply()
	end
end

function MF:ApplyHideSideEffects()
	return shellPresenter():ApplyHideSideEffects()
end

function MF:HideFrame(immediate)
	return shellPresenter():HideFrame(immediate)
end

function MF:HasActiveListing()
	return shellPresenter():HasActiveListing()
end

function MF:ApplyOpenTabPolicy()
	return shellPresenter():ApplyOpenTabPolicy()
end

function MF:OpenFrame()
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():OpenFrame()
end

function MF:OpenRoute(route, opts)
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():OpenRoute(route, opts)
end

function MF:OpenBrowseTab()
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():OpenBrowseTab()
end

function MF:OpenCreateTab()
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():OpenCreateTab()
end

function MF:OpenRaidConversation(key)
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():OpenRaidConversation(key)
end

function MF:OpenMythicPlusTab(tabID)
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():OpenMythicPlusTab(tabID)
end

function MF:ToggleRoute(route)
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():ToggleRoute(route)
end

function MF:ToggleSeasonRating()
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	if self:Init(nil, { deferInitialSurface = true }) ~= true then return false end
	if self:EnsureMythicPlusWorkspace() ~= true then return false end
	local page = GF.MythicPlusWorkspace:EnsurePage(GF.TAB_MPLUS_CHARACTER)
	local panel = page and page.bestRunsPanel
	if not panel then return false end
	if panel:IsShown() and not panel.Closing then
		panel:Hide()
	else
		-- ShowFor reads the shared current rating cache and owns main-window
		-- restoration. Do not change the selected workspace or show a default page.
		panel:ShowFor()
	end
	return true
end

function MF:Toggle()
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():Toggle()
end

function MF:OpenSettingsTab()
	local allowed, reason = requestWorkspaceUI()
	if allowed ~= true then return false, reason end
	return shellPresenter():OpenSettingsTab()
end

-- Keep the legacy read-only selection field without storing a second copy on
-- the shell view.  Workspace selection lifecycle belongs to the presenter.
local legacySurfaceStateKeys = {
	_browseInited = "browse",
	_createDrawerInited = "createDrawer",
	_createInited = "create",
	_applicantsInited = "applicants",
	_mythicPlusWorkspaceInited = "mythicPlusWorkspace",
	_settingsInited = "settings",
	_blocklistInited = "blocklist",
	_mythicPlusBrowseFilterInited = "mythicPlusBrowseFilter",
	_mythicPlusCreateManagerInited = "mythicPlusCreateManager",
}
local legacySurfaceProgressKeys = {
	_browseInitedState = "browse",
	_createDrawerInitedState = "createDrawer",
	_createInitedState = "create",
	_applicantsInitedState = "applicants",
	_mythicPlusWorkspaceInitedState = "mythicPlusWorkspace",
	_settingsInitedState = "settings",
	_blocklistInitedState = "blocklist",
	_mythicPlusBrowseFilterInitedState = "mythicPlusBrowseFilter",
	_mythicPlusCreateManagerInitedState = "mythicPlusCreateManager",
}
local legacyLifecycleStateKeys = {
	_showGen = "_showGeneration",
	_surfacePreloadPreparing = "_surfacePreloadPreparing",
	_surfacePreloadState = "_surfacePreloadState",
	_surfacePreloadTicket = "_surfacePreloadTicket",
	_surfacesPrewarmed = "_surfacesPrewarmed",
	_preloadWaitingForCombat = "_preloadWaitingForCombat",
	_preloadQueued = "_preloadQueued",
	_preloadTicket = "_preloadTicket",
	_firstPresentationGate = "_firstPresentationGate",
	_firstPresentationTicket = "_firstPresentationTicket",
	_presentationReadyByKey = "_presentationReadyByKey",
	_navDirty = "_navDirty",
	_navDebounce = "_navDebounce",
	_navPermissionDebounce = "_navPermissionDebounce",
	_recruitmentEventBatch = "_recruitmentEventBatch",
	_recruitmentEventGeneration = "_recruitmentEventGeneration",
	_applicantEntryStateKnown = "_applicantEntryStateKnown",
	_applicantEntryWasActive = "_applicantEntryWasActive",
	_everShown = "_everShown",
	_suppressNextShowSound = "_suppressNextShowSound",
	_suppressNextHideSound = "_suppressNextHideSound",
}
setmetatable(MF, {
	__index = function(_, key)
		if key == "selection" then
			return shellPresenter():GetSelection()
		end
		local surfaceKey = legacySurfaceStateKeys[key]
		if surfaceKey then
			local presenter = shellPresenter()
			return presenter:IsSurfaceReady(surfaceKey) and true or nil
		end
		surfaceKey = legacySurfaceProgressKeys[key]
		if surfaceKey then
			local presenter = shellPresenter()
			return presenter._surfaceInitializing
				and presenter._surfaceInitializing[surfaceKey] == true
				and "initializing" or nil
		end
		local presenterKey = legacyLifecycleStateKeys[key]
		if presenterKey then
			local presenter = shellPresenter()
			return presenter[presenterKey]
		end
	end,
	__newindex = function(owner, key, value)
		if key == "selection" then
			shellPresenter()._selection = value
			return
		end
		local surfaceKey = legacySurfaceStateKeys[key]
		if surfaceKey then
			local presenter = shellPresenter()
			presenter._surfaceReady = presenter._surfaceReady or {}
			presenter._surfaceReady[surfaceKey] = value == true and true or nil
			return
		end
		surfaceKey = legacySurfaceProgressKeys[key]
		if surfaceKey then
			local presenter = shellPresenter()
			presenter._surfaceInitializing =
				presenter._surfaceInitializing or {}
			presenter._surfaceInitializing[surfaceKey] =
				value == "initializing" and true or nil
			return
		end
		local presenterKey = legacyLifecycleStateKeys[key]
		if presenterKey then
			local presenter = shellPresenter()
			presenter[presenterKey] = value
			return
		end
		rawset(owner, key, value)
	end,
})

if GF.WindowShellPresenter then
	GF.WindowShellPresenter:BindView(MF)
end
