local _, GF = ...

GF.MainFrame = {}
local MF = GF.MainFrame

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

function MF:IsShowActive(gen)
	local generation = gen or 0
	local frame = self.frame
	return generation == (self._showGen or 0) and frame ~= nil and frame:IsShown()
end

function MF:ScheduleWhenShown(delay, fn)
	local scheduledGeneration = self._showGen or 0
	local function runIfCurrent()
		if fn and MF:IsShowActive(scheduledGeneration) then
			fn()
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(delay, runIfCurrent)
	else
		runIfCurrent()
	end
end

function MF:CancelShowDeferredWork()
	self._showGen = (self._showGen or 0) + 1
	if self._navDebounce or self._navPermissionDebounce then
		-- Closing during either pending projection must not discard the native
		-- availability change. The next show performs one full rebuild.
		self._navDirty = true
	end
	invoke(self._navDebounce, "Cancel")
	self._navDebounce = nil
	invoke(self._navPermissionDebounce, "Cancel")
	self._navPermissionDebounce = nil
	invoke(GF.NavTree, "CancelLayoutDebounce")
	invoke(getFindGroupTab(), "CancelDeferredWork")
	invoke(GF.ApplicantsPanel, "CancelRelayoutDebounce")
end

function MF:ScheduleDeferredShowLayout()
	self:ScheduleWhenShown(0, function()
		local activeTab = invoke(GF.TabBar, "GetCurrent")
		local plainNavigation = MF:NavVisibleForTab(activeTab)
			and not MF:IsMythicPlusBrowseFilterVisible(activeTab)
			and not MF:IsMythicPlusCreateManagerVisible(activeTab)
		if plainNavigation then
			invoke(GF.NavTree, "DeferredRefresh")
		end
		if activeTab == GF.TAB_BROWSE then
			invoke(getFindGroupTab(), "OnBrowseShown")
		elseif activeTab == GF.TAB_CREATE then
			invoke(GF.ApplicantsPanel, "RefreshLayoutIfReady")
		end
	end)
end

local function refreshCreateTabIfActive(opts)
	if not MF.browseHost or not MF.frame or not MF.frame:IsShown()
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

local function getActivityInfoForNode(node)
	if not node or not node.activityID then
		return nil
	end
	return node.activityInfo or C_LFGList.GetActivityInfoTable(node.activityID)
end

local function getActivityDifficultyIndex(info, includeMplus)
	return GF.ActivityInfo and GF.ActivityInfo.GetDifficultyIndex(info, { includeMplus = includeMplus }) or 0
end

local function getSeasonRaidDifficultyIndex(node)
	if not node or node.categoryID ~= GF.CAT_RAID then
		return nil
	end
	local isSeasonRaid = node.navKind == "season_raid"
		or (type(node.key) == "string" and node.key:match("^season_raid"))
	if not isSeasonRaid then
		return nil
	end
	if not node.activityID then
		return 0
	end
	return getActivityDifficultyIndex(getActivityInfoForNode(node), false)
end

local function syncSelectedDifficultyFilter(node)
	if not (GF.Filter and GF.FilterSpec) then
		return
	end
	if node and node._gfQuestSearch == true then
		return
	end

	if GF.Filter:SyncSelectionDungeonDifficulty(node) then
		return
	end

	local diffIndex = getSeasonRaidDifficultyIndex(node)
	if diffIndex == nil then
		return
	end
	local clientKey = GF.FilterSpec:GetClientFilterKey(node)
	local client = GF.Filter:GetClientFilters(clientKey)
	if GF.Filter:GetRaidDifficultyIndex(client) == diffIndex then
		return
	end
	GF.Filter:ApplyRaidDifficultyToClient(client, diffIndex)
	GF.Filter:SaveCategoryClientFilters(clientKey, client)
end

local zoneEventFrame

local function onZoneOrInstanceChanged()
	local frame, availability = MF.frame, GF.Availability
	if frame == nil or not frame:IsShown() or availability == nil then
		return
	end
	local blockMessage = availability:GetBlockMessage()
	if blockMessage then
		MF:HideFrame()
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
	markResizeState(GF.BlocklistPanel, active, tabID == GF.TAB_BLOCKLIST and MF._blocklistInited)
	markResizeState(GF.SettingsPanel, active, tabID == GF.TAB_SETTINGS and MF._settingsInited)
	markResizeState(GF.CreatePanel, active, tabID == GF.TAB_CREATE and MF._createInited)
	markResizeState(GF.ApplicantsPanel, active, tabID == GF.TAB_CREATE and MF._applicantsInited)
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
	resetResizeOwner(GF.BlocklistPanel, nil, MF._blocklistInited)
	resetResizeOwner(GF.SettingsPanel, "CancelUpdateScrollDebounce", MF._settingsInited)
	resetResizeOwner(GF.CreatePanel, "CancelUpdateScrollLayoutDebounce", MF._createInited)
	resetResizeOwner(GF.ApplicantsPanel, "CancelRelayoutDebounce", MF._applicantsInited)
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
	local hadOpened = MF._everShown == true
	MF:SetZoneListenerEnabled(false)
	GF.SaveFrameLayout(MF.frame)
	if hadOpened then
		MF:ApplyHideSideEffects()
		if MF._suppressNextHideSound then
			MF._suppressNextHideSound = nil
		elseif GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("close")
		end
	end
	invoke(GF.FloatButton, "RefreshAlert")
end

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
	closeButton:SetScript("OnClick", function()
		MF:HideFrame()
	end)
	closeButton:SetScript("OnEnter", function(button)
		local text = (GF.L or {}).CLOSE or CLOSE or "Close"
		GF.UI.BeginGameTooltip(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 0.82, 0)
		GF.UI.ShowGameTooltip()
	end)
	closeButton:SetScript("OnLeave", GameTooltip_Hide)

	local dragBar = GF.UI.SetupTitleDragBar(frame, GF.SaveFrameLayout)
	if dragBar then
		dragBar:HookScript("OnMouseDown", activateMainFrameFocus)
	end
	if GF.UI.InstallRecruitEyeLogo then
		GF.UI.InstallRecruitEyeLogo(frame)
	end
	owner:CreateRoleSelectionButtons()
end

local function createFooter(owner)
	local frame = owner.frame
	local footer = CreateFrame("Frame", nil, frame)
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
	footer:SetHeight(GF.FRAME_BODY_BOTTOM or 41)
	footer:SetFrameLevel(frame:GetFrameLevel() + 20)
	footer:EnableMouse(false)
	owner.footerHost, frame.footerHost = footer, footer

	if GF.UI.CreateGreatVaultButton then
		local vault = GF.UI.CreateGreatVaultButton(footer)
		vault:SetPoint("LEFT", footer, "LEFT",
			GF.GREAT_VAULT_BUTTON_OFFSET_X or 32, GF.GREAT_VAULT_BUTTON_OFFSET_Y or 2)
		owner.greatVaultButton = vault
	end
	if owner.greatVaultButton and GF.UI.CreateKeystoneLootButton then
		local keystone = GF.UI.CreateKeystoneLootButton(footer)
		keystone:SetPoint("LEFT", owner.greatVaultButton, "RIGHT", GF.KEYSTONE_LOOT_BUTTON_GAP or 0, 0)
		owner.keystoneLootButton = keystone
	end
end

local function createContentHosts(owner, horizontalPadding, topPadding, bottomPadding)
	local frame = owner.frame
	local backplate = GF.UI.CreatePanelBackplate(frame)
	owner.panelBackplate, owner.layoutHost = backplate, backplate
	frame.panelBackplate = backplate
	createFooter(owner)

	local navigation = CreateFrame("Frame", nil, backplate)
	navigation:SetPoint("TOPLEFT", backplate, "TOPLEFT", horizontalPadding, -topPadding)
	navigation:SetPoint("BOTTOMLEFT", backplate, "BOTTOMLEFT", horizontalPadding, bottomPadding)
	navigation:SetWidth(GF.GetNavWidth())
	navigation:SetClipsChildren(true)
	navigation:SetFrameLevel(backplate:GetFrameLevel() + 5)
	GF.UI.InstallBrowseSidePanelChrome(navigation)
	owner.navHost = navigation

	local clip = CreateFrame("Frame", nil, backplate)
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(backplate:GetFrameLevel() + 5)
	GF.UI.InstallTransmogTabsFrameBackground(clip)
	local content = GF.UI.CreateContentPanel(clip)
	content:SetAllPoints(clip)
	local body = CreateFrame("Frame", nil, content)
	body:SetFrameLevel(content:GetFrameLevel() + 1)
	owner.contentClip, owner.content, owner.contentBody = clip, content, body

	local auxiliaryClip = CreateFrame("Frame", nil, backplate)
	auxiliaryClip:SetClipsChildren(true)
	auxiliaryClip:SetFrameLevel(backplate:GetFrameLevel() + 5)
	GF.UI.InstallTransmogTabsFrameBackground(auxiliaryClip)
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

local function initializeWindowSurfaces(owner)
	GF.CreateDrawer:Init(owner.content, owner.contentBody)
	GF.SubtitleBar:Init(owner.content, 0)
	GF.NavTree:Init(owner.navHost)
	invoke(GF.MythicPlusBrowseFilterPanel, "Init", owner.navHost)
	invoke(GF.MythicPlusCreateManagerPanel, "Init", owner.navHost)

	local filterState = GF.MythicPlusBrowseFilter
	if not owner._mythicPlusBrowseFilterListenerBound and filterState and filterState.AddListener then
		filterState:AddListener(function(_, reason)
			MF:OnMythicPlusBrowseFilterChanged(reason)
		end)
		owner._mythicPlusBrowseFilterListenerBound = true
	end
	owner:LayoutContent(false)

	local browseHost = CreateFrame("Frame", nil, owner.contentBody)
	browseHost:SetAllPoints()
	browseHost:SetFrameLevel(owner.content:GetFrameLevel() + 2)
	owner.browseHost = browseHost
	GF.FindGroupTab:Init(browseHost)
	GF.FilterPanel:Init(owner.frame)
	GF.TabBar:Init(owner.frame)
	GF.WorkspaceBar:Init(owner.frame, owner)
	invoke(GF.BlocklistPanel, "ApplyModuleVisibility")
	owner.frame.OnTabChanged = function(_, tabID)
		owner:OnTabChanged(tabID)
	end
	local workspaceBar = GF.WorkspaceBar
	if workspaceBar and workspaceBar.GetCurrent then
		owner:OnWorkspaceChanged(workspaceBar:GetCurrent(), nil, { silent = true })
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
	owner.selection = nil
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

function MF:Init()
	if self.frame ~= nil then
		return
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	invoke(GF.CreatePanel, "InstallEntryCreationHooks")
	createWindowShell(self, GF.L or {})
	createContentHosts(
		self,
		GF.MAIN_PANEL_CONTENT_PADDING_X or 18,
		GF.MAIN_PANEL_CONTENT_PADDING_TOP or 24,
		GF.MAIN_PANEL_CONTENT_PADDING_BOTTOM or 16)
	initializeWindowSurfaces(self)
	createFooterStatus(self)
	finishWindowInitialization(self)
end

function MF:GetCurrentTabID()
	local tabBar = GF.TabBar
	if tabBar and tabBar.GetCurrent then
		return tabBar:GetCurrent()
	end
	return GF.TAB_BROWSE
end

function MF:GetCurrentWorkspaceID()
	local workspaceView = GF.LFGWorkspaceView
	if workspaceView and workspaceView.GetWorkspaceID then
		return workspaceView:GetWorkspaceID()
	end
	local workspaceBar = GF.WorkspaceBar
	if workspaceBar and workspaceBar.GetCurrent then
		return workspaceBar:GetCurrent()
	end
	return GF.WORKSPACE_MEETING_STONE
end

function MF:NavVisibleForTab(tabID)
	tabID = tabID or self:GetCurrentTabID()
	if GF.MythicPlusWorkspace and GF.MythicPlusWorkspace.IsWorkspaceTab
		and GF.MythicPlusWorkspace:IsWorkspaceTab(tabID) then
		return false
	end
	return tabID ~= GF.TAB_SETTINGS and tabID ~= GF.TAB_BLOCKLIST and tabID ~= GF.TAB_DEBUG
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
	local filterPanel = GF.MythicPlusBrowseFilterPanel
	if filterPanel and not filterPanel.frame and filterPanel.Init and self.navHost then
		filterPanel:Init(self.navHost)
	end
	local createManager = GF.MythicPlusCreateManagerPanel
	if createManager and not createManager.frame
		and createManager.Init and self.navHost
	then
		createManager:Init(self.navHost)
	end
	local showFilter = showNav
		and self:IsMythicPlusBrowseFilterVisible(tabID)
		and filterPanel
		and filterPanel.frame
		and true
		or false
	local showCreateManager = showNav
		and self:IsMythicPlusCreateManagerVisible(tabID)
		and createManager
		and createManager.frame
		and true
		or false
	if (showFilter or showCreateManager)
		and GF.NavFlyout and GF.NavFlyout.HideAll
	then
		GF.NavFlyout:HideAll()
	end
	if GF.NavTree and GF.NavTree.SetVisible then
		GF.NavTree:SetVisible(
			showNav and not showFilter and not showCreateManager
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
	return showFilter
end

function MF:AuxContentVisibleForTab(tabID)
	tabID = tabID or self:GetCurrentTabID()
	return tabID == GF.TAB_SETTINGS
		or tabID == GF.TAB_DEBUG
		or (GF.MythicPlusWorkspace and GF.MythicPlusWorkspace.IsWorkspaceTab
			and GF.MythicPlusWorkspace:IsWorkspaceTab(tabID))
end

function MF:IsAuxPanelHost(hostKey)
	return hostKey == "settingsHost" or hostKey == "debugHost"
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

local function beginOneTimeInitialization(owner, flag)
	if owner[flag] then
		return false
	end
	owner[flag] = true
	return true
end

function MF:EnsureCreatePanel()
	if not beginOneTimeInitialization(self, "_createInited") then
		return
	end
	GF.CreatePanel:Init(GF.CreateDrawer.panelHost)
	local workspaceView = GF.LFGWorkspaceView
	if workspaceView and workspaceView.GetContext then
		invoke(GF.CreatePanel, "SetWorkspaceContext", workspaceView:GetContext())
	end
	if self.selection then
		invoke(GF.CreatePanel, "SetSelection", self.selection)
	end
end

function MF:EnsureApplicantsPanel()
	if beginOneTimeInitialization(self, "_applicantsInited") then
		GF.ApplicantsPanel:Init(self:EnsurePanelHost("applicantsHost"))
	end
end

function MF:EnsureMythicPlusWorkspace()
	if beginOneTimeInitialization(self, "_mythicPlusWorkspaceInited") then
		GF.MythicPlusWorkspace:Init(self.auxContentBody)
	end
end

function MF:EnsureSettingsPanel()
	if beginOneTimeInitialization(self, "_settingsInited") then
		GF.SettingsPanel:Init(self:EnsurePanelHost("settingsHost"))
	end
end

function MF:EnsureDebugPanel()
	if beginOneTimeInitialization(self, "_debugInited") then
		GF.DebugPanel:Init(self:EnsurePanelHost("debugHost"))
	end
end

function MF:EnsureBlocklistPanel()
	if beginOneTimeInitialization(self, "_blocklistInited") then
		self:LayoutBlockContent()
		GF.BlocklistPanel:Init(self.blockContent)
	end
end

function MF:EnsureCreateTabPanels()
	self:EnsureCreatePanel()
	self:EnsureApplicantsPanel()
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
			body:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, gap)
		else
			body:SetPoint("TOPLEFT", content, "TOPLEFT")
			body:SetPoint("TOPRIGHT", content, "TOPRIGHT")
		end
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
	content:ClearAllPoints()
	content:SetPoint("TOPLEFT", clip, "TOPLEFT")
	content:SetPoint("TOPRIGHT", clip, "TOPLEFT", frozenWidth, 0)
	content:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT")
	content:SetPoint("BOTTOMRIGHT", clip, "BOTTOMLEFT", frozenWidth, 0)
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
	clip:ClearAllPoints()
	if fullWidth then
		clip:SetPoint("TOPLEFT", layoutHost, "TOPLEFT", padX, -padTop)
		clip:SetPoint("BOTTOMRIGHT", layoutHost, "BOTTOMRIGHT", -padX, padBottom)
	else
		clip:SetPoint("TOPLEFT", navigation, "TOPRIGHT", GF.CONTENT_NAV_OFFSET_X or 0, 0)
		clip:SetPoint("BOTTOMRIGHT", layoutHost, "BOTTOMRIGHT", -padX, padBottom)
	end
	if not self._navDragFrozenW then
		content:ClearAllPoints()
		content:SetAllPoints(clip)
	end
	self:LayoutContentBody()
end

function MF:UpdateCreateTab(opts)
	if not self.browseHost or not self.frame or not self.frame:IsShown()
		or not GF.TabBar or GF.TabBar:GetCurrent() ~= GF.TAB_CREATE then
		return
	end
	opts = opts or {}
	self:EnsureCreateTabPanels()
	self:UpdateBrowseSidePanel(
		GF.TAB_CREATE,
		self:NavVisibleForTab(GF.TAB_CREATE)
	)
	local hasActive = GF.RecruitmentSession and GF.RecruitmentSession:HasActive()
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

function MF:OnGroupRosterChanged()
	invoke(GF.InvitationScheduler, "HandleRosterChanged")
	invoke(GF.ApplicantAlertService, "HandleManagementPermissionChanged")
	invoke(GF.ApplicantsPanel, "OnGroupRosterChanged")
	self:RefreshRoleSelectionButtons()
	self:RefreshListingPanels()
	refreshCreateTabIfActive()
	invoke(getFindGroupTab(), "UpdateBlocked")
	invoke(GF.FloatButton, "RefreshAlert")
end

function MF:OnMythicPlusBrowseFilterChanged(reason)
	if GF.MythicPlusBrowseFilterPanel
		and GF.MythicPlusBrowseFilterPanel.Refresh then
		GF.MythicPlusBrowseFilterPanel:Refresh()
	end
	if not self:IsMythicPlusBrowseFilterVisible() then
		if reason == "dungeons" or reason == "season" or reason == "reset" then
			self._mythicPlusBrowseScopeDirty = true
		else
			self._mythicPlusBrowseClientFilterDirty = true
		end
		return
	end
	if reason == "dungeons" or reason == "season" then
		if GF.FindGroupTab and GF.FindGroupTab.ResetBrowsePage then
			GF.FindGroupTab:ResetBrowsePage()
		end
	elseif reason ~= "reset"
		and GF.FindGroupTab and GF.FindGroupTab.ApplyClientFilters
	then
		GF.FindGroupTab:ApplyClientFilters()
	end
	if GF.SubtitleBar and GF.SubtitleBar.UpdateRefreshButtonState then
		GF.SubtitleBar:UpdateRefreshButtonState()
	end
end

function MF:FlushPendingMythicPlusBrowseFilterChange()
	if not self:IsMythicPlusBrowseFilterVisible() then
		return
	end
	local scopeDirty = self._mythicPlusBrowseScopeDirty == true
	local clientDirty = self._mythicPlusBrowseClientFilterDirty == true
	self._mythicPlusBrowseScopeDirty = nil
	self._mythicPlusBrowseClientFilterDirty = nil
	if scopeDirty then
		if GF.FindGroupTab and GF.FindGroupTab.ResetBrowsePage then
			GF.FindGroupTab:ResetBrowsePage()
		end
	elseif clientDirty and GF.FindGroupTab
		and GF.FindGroupTab.ApplyClientFilters
	then
		GF.FindGroupTab:ApplyClientFilters()
	end
	if (scopeDirty or clientDirty) and GF.SubtitleBar
		and GF.SubtitleBar.UpdateRefreshButtonState
	then
		GF.SubtitleBar:UpdateRefreshButtonState()
	end
end

local function leaveCreatePanel()
	if GF.CreatePanel and GF.CreatePanel.LeaveTab then
		GF.CreatePanel:LeaveTab()
	else
		invoke(GF.CreatePanel, "Hide")
	end
end

local function setOrdinaryPanelVisibility(owner, tabID)
	local browseSurface = getFindGroupTab()
	if tabID == GF.TAB_BROWSE then
		invoke(browseSurface, "Show")
	else
		invoke(browseSurface, "Hide")
	end
	if tabID ~= GF.TAB_CREATE then
		leaveCreatePanel()
		invoke(GF.ApplicantsPanel, "Hide")
	end
	if tabID == GF.TAB_SETTINGS then
		invoke(GF.SettingsPanel, "Show")
	else
		invoke(GF.SettingsPanel, "Hide")
	end
	if tabID == GF.TAB_BLOCKLIST then
		invoke(GF.BlocklistPanel, "Show")
	else
		invoke(GF.BlocklistPanel, "Hide")
	end
	if owner._debugInited then
		if tabID == GF.TAB_DEBUG then
			invoke(GF.DebugPanel, "Show")
		else
			invoke(GF.DebugPanel, "Hide")
		end
	end
end

local function initializeSurfaceForTab(owner, tabID)
	if tabID == GF.TAB_CREATE then
		owner:EnsureCreateTabPanels()
		if owner.selection then
			invoke(GF.CreatePanel, "SetSelection", owner.selection)
		end
	elseif tabID == GF.TAB_SETTINGS then
		owner:EnsureSettingsPanel()
	elseif tabID == GF.TAB_DEBUG then
		owner:EnsureDebugPanel()
	elseif tabID == GF.TAB_BLOCKLIST then
		owner:EnsureBlocklistPanel()
	end
end

function MF:OnTabChanged(tabID, opts)
	if self.browseHost == nil then
		return
	end
	opts = opts or {}
	local showAuxiliary = self:AuxContentVisibleForTab(tabID)
	local showBlocklist = tabID == GF.TAB_BLOCKLIST
	local showNavigation = self:NavVisibleForTab(tabID)
	if not showNavigation then
		invoke(GF.NavFlyout, "HideAll")
	end
	if self.navHost then
		self.navHost:SetShown(showNavigation)
	end
	self:UpdateBrowseSidePanel(tabID, showNavigation)
	self:UpdateNavInteractionState(tabID)
	if self.contentClip then
		self.contentClip:SetShown(not showAuxiliary and not showBlocklist)
	end
	if self.auxContentClip then
		self.auxContentClip:SetShown(showAuxiliary)
	end
	if self.blockContent then
		self.blockContent:SetShown(showBlocklist)
	end
	if showAuxiliary then
		self:LayoutAuxContent()
	elseif showBlocklist then
		self:LayoutBlockContent()
	else
		self:LayoutContent(false)
	end

	invoke(GF.SubtitleBar, "SetBrowseVisible", tabID == GF.TAB_BROWSE)
	if tabID ~= GF.TAB_BROWSE then
		invoke(GF.FilterPanel, "Hide")
	end
	invoke(GF.CreateDrawer, "SetTabActive", tabID == GF.TAB_CREATE)
	self.browseHost:SetShown(tabID == GF.TAB_BROWSE)
	initializeSurfaceForTab(self, tabID)

	local mythicWorkspace = GF.MythicPlusWorkspace
	local showMythic = mythicWorkspace and mythicWorkspace.IsWorkspaceTab
		and mythicWorkspace:IsWorkspaceTab(tabID)
	if showMythic then
		self:EnsureMythicPlusWorkspace()
	end
	if self.settingsHost then
		self.settingsHost:SetShown(tabID == GF.TAB_SETTINGS)
	end
	if self.debugHost then
		self.debugHost:SetShown(tabID == GF.TAB_DEBUG)
	end
	if showMythic then
		mythicWorkspace:ShowTab(tabID)
	else
		invoke(mythicWorkspace, "Hide")
	end
	setOrdinaryPanelVisibility(self, tabID)

	if tabID == GF.TAB_BROWSE then
		self:FlushPendingMythicPlusBrowseFilterChange()
		if not opts.skipDeferredLayout then
			self:ScheduleDeferredShowLayout()
		end
	elseif tabID == GF.TAB_CREATE then
		refreshCreateTabIfActive({
			allowOccupiedPrompt = not opts.skipDeferredLayout,
			allowCreateAutoOpen = true,
		})
	end

	if self.activityCount then
		if tabID == GF.TAB_BROWSE then
			self:UpdateActivityCount(invoke(GF.Result, "GetCount") or 0)
			invoke(getFindGroupTab(), "UpdateSearchHint")
		else
			self.activityCount:Hide()
			self:UpdateBrowseStatusHint(nil)
		end
	end
	if showNavigation and GF.NavFlyout and GF.NavFlyout.ReanchorOpenPanels then
		GF.NavFlyout:ReanchorOpenPanels()
		self:ScheduleWhenShown(0, function()
			if self:NavVisibleForTab(self:GetCurrentTabID()) then
				invoke(GF.NavFlyout, "ReanchorOpenPanels")
			end
		end)
	end
end

function MF:OnWorkspaceChanged(workspaceID, _previousWorkspaceID, opts)
	opts = opts or {}
	local previousWorkspaceID = _previousWorkspaceID
	local targetWorkspaceID = workspaceID
	if GF.LFGWorkspacePolicy and GF.LFGWorkspacePolicy.NormalizeWorkspaceID then
		targetWorkspaceID = GF.LFGWorkspacePolicy:NormalizeWorkspaceID(workspaceID)
	elseif targetWorkspaceID ~= GF.WORKSPACE_MYTHIC_PLUS then
		targetWorkspaceID = GF.WORKSPACE_MEETING_STONE
	end
	local normalizedPreviousWorkspaceID = previousWorkspaceID
	if normalizedPreviousWorkspaceID == nil and GF.LFGWorkspaceView
		and GF.LFGWorkspaceView.activeWorkspaceID then
		normalizedPreviousWorkspaceID = GF.LFGWorkspaceView.activeWorkspaceID
	end
	if previousWorkspaceID ~= nil and GF.LFGWorkspacePolicy
		and GF.LFGWorkspacePolicy.NormalizeWorkspaceID then
		normalizedPreviousWorkspaceID = GF.LFGWorkspacePolicy:NormalizeWorkspaceID(
			previousWorkspaceID)
	end
	if GF.MythicPlusCreateManagerPanel
		and GF.MythicPlusCreateManagerPanel.IsSurfaceActive
		and GF.MythicPlusCreateManagerPanel:IsSurfaceActive()
		and normalizedPreviousWorkspaceID ~= nil
		and normalizedPreviousWorkspaceID ~= targetWorkspaceID
	then
		-- Release the outgoing native EntryCreation owner before changing the
		-- active workspace generation/context.
		GF.MythicPlusCreateManagerPanel:SetVisible(false)
	end
	if GF.CreateDrawer and GF.CreateDrawer.IsOpen and GF.CreateDrawer:IsOpen()
		and normalizedPreviousWorkspaceID ~= nil
		and normalizedPreviousWorkspaceID ~= targetWorkspaceID then
		-- Release the outgoing native EntryCreation owner before changing the
		-- active workspace generation/context.
		GF.CreateDrawer:Close(true)
	end

	local context
	local node
	local path
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.Activate then
		context, node, path = GF.LFGWorkspaceView:Activate(
			targetWorkspaceID,
			previousWorkspaceID,
			self.selection
		)
		workspaceID = context.workspaceID
	else
		workspaceID = targetWorkspaceID
	end

	if GF.CreateDrawer and GF.CreateDrawer.SetWorkspaceContext then
		GF.CreateDrawer:SetWorkspaceContext(context)
	end

	local fg = getFindGroupTab()
	if fg and fg.SetWorkspaceContext then
		fg:SetWorkspaceContext(context or {
			workspaceID = workspaceID,
			generation = 1,
			key = tostring(workspaceID) .. ":1",
		})
	end
	if GF.CreatePanel and self._createInited and GF.CreatePanel.SetWorkspaceContext then
		GF.CreatePanel:SetWorkspaceContext(context)
	end

	if GF.NavTree then
		if GF.LFGWorkspaceView and GF.LFGWorkspaceView.ApplyNavState then
			GF.LFGWorkspaceView:ApplyNavState(workspaceID, node, path)
		elseif node and GF.NavTree.SetSelectedSilently then
			GF.NavTree:SetSelectedSilently(node, path)
		else
			GF.NavTree.selectedKey = nil
			GF.NavTree.activeRootKey = nil
			if GF.NavTree.Refresh then
				GF.NavTree:Refresh()
			end
		end
	end
	self:OnSelectionChanged(node, {
		workspaceSwitch = true,
		suppressCreateDrawer = true,
	})

	if GF.NavFlyout and GF.NavFlyout.HideAll then
		GF.NavFlyout:HideAll()
	end
	if GF.TabBar and GF.TabBar.SetWorkspace then
		local tabID = GF.TabBar:SetWorkspace(workspaceID, { silent = true })
		self:OnTabChanged(tabID, { skipDeferredLayout = opts.silent == true })
	end
end

function MF:OnSelectionChanged(node, opts)
	opts = opts or {}
	if node and node.disabled then
		return false
	end
	local workspaceID = self:GetCurrentWorkspaceID()
	if node and GF.LFGWorkspaceView and GF.LFGWorkspaceView.IsNodeAllowed
		and not GF.LFGWorkspaceView:IsNodeAllowed(node, workspaceID) then
		return false
	end
	self.selection = node
	if GF.MythicPlusBrowseFilterPanel
		and GF.MythicPlusBrowseFilterPanel.SetSelection then
		GF.MythicPlusBrowseFilterPanel:SetSelection(node)
	end
	if GF.MythicPlusCreateManagerPanel
		and GF.MythicPlusCreateManagerPanel.SetSelection
	then
		GF.MythicPlusCreateManagerPanel:SetSelection(node)
	end
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.RememberSelection then
		GF.LFGWorkspaceView:RememberSelection(workspaceID, node)
	end
	-- Availability refreshes replace runtime-backed navigation objects, but do
	-- not represent a new user choice. Preserve the workspace's manually chosen
	-- difficulty while rebinding the equivalent node.
	if not opts.availabilityRefresh then
		syncSelectedDifficultyFilter(node)
	end
	local fg = getFindGroupTab()
	if fg then
		fg:SetSelection(node, opts)
	end
	if self:GetCurrentTabID() == GF.TAB_CREATE and GF.CreatePanel then
		if GF.CreatePanel.SetWorkspaceContext and GF.LFGWorkspaceView
			and GF.LFGWorkspaceView.GetContext then
			GF.CreatePanel:SetWorkspaceContext(GF.LFGWorkspaceView:GetContext())
		end
		GF.CreatePanel:SetSelection(node)
		if not (self.frame and self.frame:IsShown()) then
			return true
		end
		local createManager = GF.MythicPlusCreateManagerPanel
		if createManager and createManager.ShouldUse
			and createManager:ShouldUse()
		then
			createManager:Open()
		else
			local hasActive = GF.RecruitmentSession and GF.RecruitmentSession.HasActive
				and GF.RecruitmentSession:HasActive()
			local canLead = GF.RecruitmentSession and GF.RecruitmentSession.CanPublish
				and GF.RecruitmentSession:CanPublish()
			local canCreate
			if GF.LFGWorkspaceView
				and GF.LFGWorkspaceView.CanCreateSelection
			then
				canCreate = GF.LFGWorkspaceView:CanCreateSelection(
					node,
					workspaceID
				)
			else
				canCreate = GF.NavData and GF.NavData.CanCreateFromNode
					and GF.NavData.CanCreateFromNode(node)
			end
			local premadeBlocked = getPremadeCreateBlockMessage() ~= nil
			local drawer = GF.CreateDrawer
			local relisting = GF.RecruitmentSession and GF.RecruitmentSession.IsRelisting
				and GF.RecruitmentSession:IsRelisting()
			if not hasActive and drawer and drawer.IsOpen
				and drawer:IsOpen()
				and (not canLead or not canCreate or premadeBlocked)
			then
				drawer:Close(true)
			end
			if not opts.suppressCreateDrawer
				and not hasActive and not relisting
				and canLead and canCreate and not premadeBlocked
				and drawer
			then
				local wasOpen = drawer.IsOpen and drawer:IsOpen()
				if drawer.Open then
					drawer:Open({
						mode = "create",
						silent = wasOpen == true,
						allowOccupiedPrompt = true,
					})
				end
			end
		end
	end
	local subtitle = GF.SubtitleBar
	invoke(subtitle, "SyncFromSelection", node)
	invoke(subtitle, "UpdateFilterState")
	invoke(subtitle, "UpdateRefreshButtonState")

	local filterPanel = GF.FilterPanel
	if filterPanel then
		local database = GF.GetDB and GF.GetDB()
		local shouldOpen = database and database.autoExpandFilter
			and self:GetCurrentTabID() == GF.TAB_BROWSE
			and node and fg and fg:IsSearchableSelection(node)
		if shouldOpen then
			filterPanel:Show()
		elseif filterPanel:IsShown() then
			filterPanel:AnchorToMain()
			invoke(filterPanel, "RebuildIfNeeded", false)
		end
	end
	return true
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
	if applicants and owner._applicantsInited and applicants.Relayout then
		applicants._relayoutSuppressUntil = GetTime() + 0.25
		invoke(applicants, "CancelRelayoutDebounce")
		applicants:Relayout()
	end
	if not (GF.CreatePanel and owner._createInited) then
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
	if tabID == GF.TAB_BROWSE then
		resizeBrowseSurface(getFindGroupTab())
	end
	local plainNavigation = self:NavVisibleForTab(tabID)
		and not self:IsMythicPlusBrowseFilterVisible(tabID)
		and not self:IsMythicPlusCreateManagerVisible(tabID)
	if plainNavigation then
		invoke(GF.NavTree, "CancelLayoutDebounce")
		invoke(GF.NavTree, "ScheduleLayoutRows")
	end
	if tabID == GF.TAB_SETTINGS and self._settingsInited then
		invoke(GF.SettingsPanel, "UpdateScroll")
	end
	if tabID == GF.TAB_DEBUG and self._debugInited then
		invoke(GF.DebugPanel, "UpdateScroll")
	end
	local filterPanel = GF.FilterPanel
	if filterPanel and filterPanel.IsShown and filterPanel:IsShown() then
		invoke(filterPanel, "AnchorToMain")
	end
	if tabID == GF.TAB_CREATE then
		resizeCreateSurfaces(self)
	end
	if tabID == GF.TAB_BLOCKLIST and self._blocklistInited then
		invoke(GF.BlocklistPanel, "Refresh")
	end
end

function MF:OnSearchResults()
	invoke(GF.FindGroupTab, "OnSearchResults")
end

function MF:OnSearchFailed()
	invoke(GF.FindGroupTab, "OnSearchFailed")
end

local function rebuildNavigationForAvailability(refreshCreateManager, permissionsOnly)
	local navigation = GF.NavTree
	local expansionState = navigation and navigation.expanded
	local previousSelection = MF.selection
	local isQuestSelection = previousSelection
		and previousSelection._gfQuestSearch == true
	local selectionKey = previousSelection and previousSelection.key
	local visualSelectionKey = navigation and navigation.selectedKey
	local retainedPathKeys = {}
	local previousSelectionPath
	if selectionKey and not isQuestSelection
		and GF.NavData and GF.NavData.FindLoadedNodePathByKey
	then
		local _, path = GF.NavData.FindLoadedNodePathByKey(selectionKey)
		previousSelectionPath = path
		for _, pathNode in ipairs(path or {}) do
			if pathNode and pathNode.key then
				retainedPathKeys[pathNode.key] = true
			end
		end
	end
	local rebuild = permissionsOnly
		and GF.NavData.ApplyLfgRestrictions
		or GF.NavData.OnAvailabilityChanged
	local changed
	if rebuild then
		changed = permissionsOnly
			and rebuild(GF.navTree)
			or rebuild(expansionState, retainedPathKeys)
	end
	local reboundSelection = false
	if previousSelection then
		local findGroup = getFindGroupTab()
		if findGroup and findGroup.ResetBrowsePage then
			findGroup:ResetBrowsePage()
		end

		local node
		if isQuestSelection and GF.QuestSearch and GF.QuestSearch.Resolve then
			local resolved = GF.QuestSearch:Resolve(previousSelection.questID)
			if resolved then
				local baseNode = resolved.baseNode
				if not (baseNode and baseNode.disabled) then
					node = resolved.selection
				end
				if navigation and baseNode and not baseNode.disabled then
					local oldNavKey = navigation.selectedKey
					navigation.selectedKey = baseNode.key
					if oldNavKey ~= baseNode.key then
						navigation.activeRootKey = nil
					end
				end
			end
		end
		if not node and not isQuestSelection then
			local findReplacement = GF.NavData and GF.NavData.FindReplacementNode
			node = findReplacement
				and findReplacement(previousSelection, previousSelectionPath) or nil
		end
		if node and node.disabled then
			node = nil
		end
		if navigation and visualSelectionKey == selectionKey then
			navigation.selectedKey = node and node.key or nil
			if not node then
				navigation.activeRootKey = nil
			end
		end
		MF:OnSelectionChanged(node, {
			suppressCreateDrawer = true,
			availabilityRefresh = true,
		})
		reboundSelection = true
	end
	if navigation and visualSelectionKey then
		local findLoaded = GF.NavData and GF.NavData.FindNodeByKey
		local selectedNode = findLoaded and findLoaded(navigation.selectedKey)
		if not selectedNode or selectedNode.disabled then
			navigation.selectedKey = nil
			navigation.activeRootKey = nil
		end
	end
	if (changed or reboundSelection) and navigation then
		invoke(GF.NavFlyout, "HideAll")
		navigation:Refresh()
	end
	if refreshCreateManager then
		invoke(GF.MythicPlusCreateManagerPanel, "Refresh")
	end
end

function MF:OnAvailabilityUpdate()
	local frame = self.frame
	if frame == nil or not frame:IsShown() then
		self._navDirty = true
		return
	end
	self:RefreshRoleSelectionButtons()
	invoke(self._navDebounce, "Cancel")
	if not (C_Timer and C_Timer.NewTimer) then
		rebuildNavigationForAvailability(true)
		return
	end
	self._navDebounce = C_Timer.NewTimer(0.3, function()
		MF._navDebounce = nil
		rebuildNavigationForAvailability(true)
	end)
end

function MF:OnPremadePermissionUpdate()
	local frame = self.frame
	if frame == nil or not frame:IsShown() then
		self._navDirty = true
		return
	end
	self:RefreshRoleSelectionButtons()
	-- Keep the short global-permission projection independent from the slower
	-- activity-catalog rebuild. A level/trial event can arrive next to
	-- LFG_LIST_AVAILABILITY_UPDATE; sharing one timer would let either callback
	-- cancel the other and could leave a stale seasonal scope behind.
	invoke(self._navPermissionDebounce, "Cancel")
	if not (C_Timer and C_Timer.NewTimer) then
		rebuildNavigationForAvailability(true, true)
		return
	end
	self._navPermissionDebounce = C_Timer.NewTimer(0.1, function()
		MF._navPermissionDebounce = nil
		rebuildNavigationForAvailability(true, true)
	end)
end

function MF:ResetCreateAfterManualRemove()
	if GF.CreateDrawer and GF.CreateDrawer.ResetAfterListingRemoved then
		GF.CreateDrawer:ResetAfterListingRemoved()
	elseif GF.CreateDrawer then
		GF.CreateDrawer:Close(true)
	end
	if GF.CreatePanel and GF.CreatePanel.ResetAfterListingRemoved then
		GF.CreatePanel:ResetAfterListingRemoved()
	end

	local workspaceID = self:GetCurrentWorkspaceID()
	local node
	local path
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.ResetSelectionToDefault then
		node, path = GF.LFGWorkspaceView:ResetSelectionToDefault(workspaceID)
	end
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.ApplyNavState then
		GF.LFGWorkspaceView:ApplyNavState(workspaceID, node, path)
	elseif GF.NavTree then
		GF.NavTree.selectedKey = node and node.key or nil
		GF.NavTree.activeRootKey = path and path[1] and path[1].key or nil
		if GF.NavTree.Refresh then
			GF.NavTree:Refresh()
		end
	end
	if GF.NavFlyout and GF.NavFlyout.HideAll then
		GF.NavFlyout:HideAll()
	end
	self:OnSelectionChanged(node, {
		suppressCreateDrawer = true,
		listingRemoved = true,
	})
end

function MF:OnActiveEntryUpdate(opts)
	opts = opts or {}
	local hasActive = opts.hasActive
	if hasActive == nil then
		hasActive = GF.RecruitmentSession and GF.RecruitmentSession:HasActive()
	else
		hasActive = hasActive == true
	end
	local entryStateKnown = self._applicantEntryStateKnown == true
	local hadActive = self._applicantEntryWasActive == true
	self._applicantEntryStateKnown = true
	self._applicantEntryWasActive = hasActive == true
	local beganApplicantSession = entryStateKnown
		and hasActive == true and not hadActive
	local resetAfterManualRemove = not hasActive
		and GF.RecruitmentSession and GF.RecruitmentSession.ConsumeConfirmedUserRemoval
		and GF.RecruitmentSession:ConsumeConfirmedUserRemoval()
	local bumpFailed = (
		(opts.finalizeBump == true and opts.bumpSucceeded == false)
		or opts.bumpOutcome == "failed"
	)
	local failedBumpStage = bumpFailed and GF.RecruitmentSession
		and GF.RecruitmentSession.GetLastRelistFailure
		and GF.RecruitmentSession:GetLastRelistFailure()
	local failedBumpSession = bumpFailed
		and failedBumpStage ~= "remove_call_failed"
	if (hasActive and (opts.createdNew == true or beganApplicantSession))
		or resetAfterManualRemove or failedBumpSession
	then
		-- Applicant events can arrive before the main window has ever been opened.
		-- Rotate their session state independently from browseHost/UI ownership.
		invoke(GF.ApplicantsPanel, "ResetForNewApplicantSession")
	end
	if not self.browseHost then
		return
	end
	local bumpOutcome = opts.bumpOutcome
	if opts.bumpResolved ~= true
		and GF.RecruitmentSession and GF.RecruitmentSession.HandleRelistEntryChanged
	then
		bumpOutcome = GF.RecruitmentSession:HandleRelistEntryChanged(
			hasActive == true,
			opts.createdNew == true
		)
	end
	local relisting = GF.RecruitmentSession and GF.RecruitmentSession.IsRelisting
		and GF.RecruitmentSession:IsRelisting()
	if relisting and not hasActive and not opts.finalizeBump then
		return
	end
	if GF.RecruitmentSession and GF.RecruitmentSession.SyncEntryOwnership then
		GF.RecruitmentSession:SyncEntryOwnership(hasActive == true)
	end
	if not hasActive then
		if GF.InvitationScheduler and GF.InvitationScheduler.ClearSession then
			GF.InvitationScheduler:ClearSession()
		end
	end
	if resetAfterManualRemove then
		self:ResetCreateAfterManualRemove()
	end
	local bumpSucceeded = bumpOutcome == "success" or opts.bumpSucceeded == true
	local forceEdit = hasActive == true and (
		not bumpSucceeded
		or self:GetCurrentWorkspaceID() == GF.WORKSPACE_MYTHIC_PLUS
	)
	if bumpSucceeded and GF.CreateDrawer then
		GF.CreateDrawer:Close(true)
	end
	self:RefreshListingPanels()
	self:RefreshRecruitEyeLogo(hasActive == true)
	refreshCreateTabIfActive({
		-- A successful bump creates a new active entry with the same activity ID.
		-- Force the persistent Mythic+ manager to copy the complete new snapshot;
		-- its activity/mode fast path would otherwise leave the old draft mounted.
		forceEdit = forceEdit,
		suppressCreateAutoOpen = opts.suppressCreateAutoOpen == true
			or opts.fromActiveEntryEvent == true
			or resetAfterManualRemove == true
			or bumpOutcome == "failed",
	})
	invoke(getFindGroupTab(), "UpdateBlocked")
	invoke(GF.FloatButton, "RefreshAlert")
	if opts.questCreateOutcome == "success" then
		self:ScheduleWhenShown(0, function()
			local listing = GF.RecruitmentSession
			if listing and listing.HasActive and listing:HasActive() == true then
				MF:OpenCreateTab()
			end
		end)
	end
end

function MF:OnApplicantsUpdate()
	invoke(GF.InvitationScheduler, "Queue")
	local applicants = GF.ApplicantsPanel
	if applicants and applicants.OnApplicantListUpdated then
		applicants:OnApplicantListUpdated()
	else
		invoke(applicants, "Refresh")
	end
	invoke(GF.FloatButton, "RefreshAlert")
end

function MF:ShowFrame()
	local availability = GF.Availability
	if availability then
		local blockMessage = availability:GetBlockMessage()
		if blockMessage then
			availability:NotifyBlocked(blockMessage)
			return
		end
	end
	invoke(GF.UsageGuideDialog, "CloseForMainFrameOpen")
	self:Init()
	local frame = self.frame
	local wasShown = frame and frame:IsShown()
	local returning = self._everShown == true
	self._everShown = true
	GF.UI.ApplySettingsFrameChrome(frame, (GF.L or {}).ADDON_NAME or "GroupFinder")
	self:RefreshRecruitEyeLogo()
	if GF.navTree then
		GF.NavData.RefreshHistory()
	elseif not returning then
		GF.NavData.Rebuild()
	end
	if not returning then
		invoke(GF.NavTree, "Refresh")
		self:OnTabChanged(invoke(GF.TabBar, "GetCurrent"), { skipDeferredLayout = true })
	end
	if self._navDirty then
		self._navDirty = false
		rebuildNavigationForAvailability(false)
	end
	frame:Show()
	self:RefreshRoleSelectionButtons()
	invoke(GF.SubtitleBar, "ReclaimSearchBoxForBrowse")
	invoke(GF.FloatButton, "RefreshAlert")
	local currentTab = invoke(GF.TabBar, "GetCurrent")
	if currentTab == GF.TAB_CREATE then
		self:UpdateCreateTab({
			allowOccupiedPrompt = true,
			allowCreateAutoOpen = true,
		})
	end
	if not wasShown and self._suppressNextShowSound then
		self._suppressNextShowSound = nil
	elseif not wasShown and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("open")
	end
	self:SetZoneListenerEnabled(true)
	self:ScheduleDeferredShowLayout()
	local browseSurface = getFindGroupTab()
	invoke(browseSurface, "UpdateTitle")
	invoke(browseSurface, "UpdateSearchHint")
	invoke(GF.SubtitleBar, "UpdateFilterState")
	if returning and currentTab == GF.TAB_BROWSE and self.activityCount then
		self:UpdateActivityCount(invoke(GF.Result, "GetCount") or 0)
	end
end

function MF:RefreshLocale()
	local L = GF.L or {}
	if self.frame then
		GF.UI.ApplySettingsFrameChrome(self.frame, L.ADDON_NAME or "GroupFinder")
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
	if GF.MythicPlusWorkspace and GF.MythicPlusWorkspace.RefreshLocale then
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
	if fg then
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
	if GF.NavTree and GF.NavTree.Refresh then
		GF.NavTree:Refresh()
	end
	if GF.CreatePanel and GF.CreatePanel.RefreshLocale then
		GF.CreatePanel:RefreshLocale()
	end
	if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
		GF.ApplicantsPanel:Refresh({ preserveScroll = true })
	end
	if GF.BlocklistPanel and GF.BlocklistPanel.RefreshLocale then
		GF.BlocklistPanel:RefreshLocale()
	elseif GF.BlocklistPanel and GF.BlocklistPanel.Refresh then
		GF.BlocklistPanel:Refresh()
	end
	if GF.SettingsPanel and GF.SettingsPanel.RefreshLocale then
		GF.SettingsPanel:RefreshLocale()
	end
	if GF.DebugPanel and GF.DebugPanel.RefreshLocale then
		GF.DebugPanel:RefreshLocale()
	elseif GF.DebugPanel and GF.DebugPanel.Refresh then
		GF.DebugPanel:Refresh()
	end
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
	self:CancelShowDeferredWork()
	invoke(GF.NavFlyout, "HideAll")
	invoke(GF.FilterPanel, "Hide")
	invoke(GF.MythicPlusCreateManagerPanel, "SetVisible", false)
	invoke(GF.CreateDrawer, "Close", true)
	invoke(getFindGroupTab(), "OnFrameHidden")
	invoke(GF.SubtitleBar, "ReleaseBlizzardSearchBox")
	invoke(GF.CreatePanel, "ReleaseCreateFields", "addon")
	if GF.Hook and GF.Hook.OnGFUIClosed then
		GF.Hook.OnGFUIClosed()
	end
end

function MF:HideFrame()
	local frame = self.frame
	if frame and frame:IsShown() then
		frame:Hide()
	end
end

function MF:HasActiveListing()
	local api = C_LFGList
	if api == nil then
		return false
	end
	if api.HasActiveEntryInfo then
		return api.HasActiveEntryInfo()
	end
	if api.GetActiveEntryInfo then
		return api.GetActiveEntryInfo() ~= nil
	end
	return false
end

function MF:ApplyOpenTabPolicy()
	if self:HasActiveListing() then
		invoke(GF.TabBar, "SelectTab", GF.TAB_CREATE)
	end
end

local function mainWindowIsVisible(owner)
	return owner.frame ~= nil and owner.frame:IsShown()
end

function MF:OpenFrame()
	self:ShowFrame()
	if mainWindowIsVisible(self) then
		self:ApplyOpenTabPolicy()
	end
end

function MF:OpenBrowseTab()
	self:ShowFrame()
	if mainWindowIsVisible(self) then
		invoke(GF.TabBar, "SelectTab", GF.TAB_BROWSE)
	end
end

function MF:OpenCreateTab()
	self:ShowFrame()
	if mainWindowIsVisible(self) then
		local tabBar = GF.TabBar
		if tabBar and tabBar.Select then
			tabBar:Select(GF.TAB_CREATE)
		else
			invoke(tabBar, "SelectTab", GF.TAB_CREATE)
		end
	end
end

function MF:Toggle()
	if mainWindowIsVisible(self) then
		self:HideFrame()
	else
		self:OpenFrame()
	end
end

function MF:OpenSettingsTab()
	self:ShowFrame()
	if mainWindowIsVisible(self) then
		invoke(GF.TabBar, "SelectTab", GF.TAB_SETTINGS)
	end
end

function MF:OpenDebugTab()
	self:ShowFrame()
	if mainWindowIsVisible(self) then
		invoke(GF.TabBar, "SelectTab", GF.TAB_DEBUG)
	end
end
