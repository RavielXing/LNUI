local _, GF = ...

GF.MainFrame = {}
local MF = GF.MainFrame

local function getFindGroupTab()
	return GF.FindGroupTab
end

local function scheduleApplicantsRelayout()
	if GF.ApplicantsPanel and GF.ApplicantsPanel.RelayoutWhenReady then
		MF:ScheduleWhenShown(0, function()
			if GF.ApplicantsPanel then
				GF.ApplicantsPanel:RelayoutWhenReady()
			end
		end)
	end
end

function MF:IsShowActive(gen)
	gen = gen or 0
	local cur = self._showGen or 0
	return gen == cur and self.frame and self.frame:IsShown()
end

function MF:ScheduleWhenShown(delay, fn)
	local gen = self._showGen or 0
	if not C_Timer or not C_Timer.After then
		if self:IsShowActive(gen) and fn then
			fn()
		end
		return
	end
	C_Timer.After(delay, function()
		if MF:IsShowActive(gen) and fn then
			fn()
		end
	end)
end

function MF:CancelShowDeferredWork()
	self._showGen = (self._showGen or 0) + 1
	if self._navDebounce and self._navDebounce.Cancel then
		self._navDebounce:Cancel()
	end
	self._navDebounce = nil
	if GF.NavTree and GF.NavTree.CancelLayoutDebounce then
		GF.NavTree:CancelLayoutDebounce()
	end
	local fg = getFindGroupTab()
	if fg and fg.CancelDeferredWork then
		fg:CancelDeferredWork()
	end
	local ap = GF.ApplicantsPanel
	if ap and ap.CancelRelayoutDebounce then
		ap:CancelRelayoutDebounce()
	end
end

function MF:ScheduleDeferredShowLayout()
	self:ScheduleWhenShown(0, function()
		local tabID = GF.TabBar and GF.TabBar:GetCurrent()
		if MF:NavVisibleForTab(tabID) and GF.NavTree then
			GF.NavTree:DeferredRefresh()
		end
		local fg = getFindGroupTab()
		if tabID == GF.TAB_BROWSE and fg then
			fg:OnBrowseShown()
		elseif tabID == GF.TAB_CREATE and GF.ApplicantsPanel then
			GF.ApplicantsPanel:RelayoutWhenReady()
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

local function activateCreateMainFrameFocus()
	local currentTab = GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar:GetCurrent()
	if currentTab == GF.TAB_CREATE
		and GF.CreateDrawer and GF.CreateDrawer.IsOpen and GF.CreateDrawer:IsOpen()
		and GF.CreateDrawer.ActivateMainFrame then
		GF.CreateDrawer:ActivateMainFrame()
	end
	return currentTab
end

function MF:RecenterFrame()
	if not self.frame then
		return
	end
	self.frame:ClearAllPoints()
	self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

function MF:UpdateNavInteractionState(tabID)
	tabID = tabID or (GF.TabBar and GF.TabBar:GetCurrent())
	if not (GF.NavTree and GF.NavTree.SetInteractionEnabled) then
		return
	end
	local enabled = true
	if tabID == GF.TAB_CREATE then
		local listing = GF.Listing
		local hasActive = listing and listing.HasActive and listing:HasActive()
		if hasActive then
			enabled = listing and listing.CanManageEntry and listing:CanManageEntry()
		else
			enabled = listing and listing.CanLeadListing and listing:CanLeadListing()
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
	local listing = GF.Listing
	local hasActive = listing and listing.HasActive and listing:HasActive()
	if hasActive and listing.GetActiveActivityID then
		node, path = GF.NavTree:FindNodePathByActivityID(listing:GetActiveActivityID())
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

local function getActivityDifficultyIndex(info, label, includeMplus)
	if info then
		if includeMplus and info.isMythicPlusActivity then
			return 4
		end
		if info.isNormalActivity then
			return 1
		end
		if info.isHeroicActivity then
			return 2
		end
		if info.isMythicActivity then
			return 3
		end
	end
	local text = table.concat({
		label or "",
		info and info.fullName or "",
		info and info.shortName or "",
	}, " ")
	if includeMplus and (text:find("史诗钥石", 1, true) or text:find("钥石", 1, true)
		or text:find("Mythic+", 1, true) or text:find("Mythic Plus", 1, true)
		or text:find("Keystone", 1, true) or text:find("M+", 1, true)) then
		return 4
	end
	if text:find("史诗", 1, true) or text:find("Mythic", 1, true) then
		return 3
	end
	if text:find("英雄", 1, true) or text:find("Heroic", 1, true) then
		return 2
	end
	if text:find("普通", 1, true) or text:find("Normal", 1, true) then
		return 1
	end
	return 0
end

local function getDungeonDifficultyIndex(node)
	if not node or node.categoryID ~= GF.CAT_DUNGEON then
		return nil
	end
	if node.navKind == "season_dungeon" then
		return nil
	end
	if not node.activityID then
		return getActivityDifficultyIndex(nil, node.label, true)
	end
	return getActivityDifficultyIndex(getActivityInfoForNode(node), node.label, true)
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
	return getActivityDifficultyIndex(getActivityInfoForNode(node), node.label, false)
end

local function syncSelectedDifficultyFilter(node)
	if not (GF.Filter and GF.FilterSpec) then
		return
	end

	local dungeonDiffIndex = getDungeonDifficultyIndex(node)
	if dungeonDiffIndex ~= nil then
		local clientKey = GF.FilterSpec:GetClientFilterKey(node)
		local client = GF.Filter:GetClientFilters(clientKey)
		if GF.Filter:GetClientDifficultyIndex(client, true) ~= dungeonDiffIndex then
			GF.Filter:ApplyDifficultyToClient(client, dungeonDiffIndex, true)
			GF.Filter:SaveCategoryClientFilters(clientKey, client)
		end
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
	if not MF.frame or not MF.frame:IsShown() or not GF.Availability then
		return
	end
	local msg = GF.Availability:GetBlockMessage()
	if msg then
		MF:HideFrame()
		GF.Availability:NotifyBlocked(msg)
	end
end

function MF:SetZoneListenerEnabled(enable)
	if not zoneEventFrame then
		zoneEventFrame = CreateFrame("Frame")
		zoneEventFrame:SetScript("OnEvent", onZoneOrInstanceChanged)
	end
	if enable then
		zoneEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	else
		zoneEventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
end

function MF:Init()
	if self.frame then
		return
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if GF.CreatePanel and GF.CreatePanel.InstallEntryCreationHooks then
		GF.CreatePanel:InstallEntryCreationHooks()
	end
	local L = GF.L or {}
	local contentPadX = GF.MAIN_PANEL_CONTENT_PADDING_X or 18
	local contentPadTop = GF.MAIN_PANEL_CONTENT_PADDING_TOP or 24
	local contentPadBottom = GF.MAIN_PANEL_CONTENT_PADDING_BOTTOM or 16

	self.frame = GF.UI.CreateFrameWithTemplateOptions("Frame", "GroupFinderAddonFrame", UIParent, {
		"PortraitFrameTemplate",
		"SettingsFrameTemplate",
		"DefaultPanelTemplate",
	})
	self.frame.frame = self.frame
	self.frame:SetSize(GF.FRAME_W, GF.FRAME_H)
	self.frame:SetFrameStrata(GF.FRAME_STRATA_DEFAULT or "MEDIUM")
	self.frame:SetFrameLevel(10)
	self.frame:EnableMouse(true)
	self.frame:SetClampedToScreen(true)
	self.frame:SetToplevel(true)
	self.frame:HookScript("OnMouseDown", function(f)
		GF.UI.RaiseFrame(f)
		local currentTab = activateCreateMainFrameFocus()
		if GF.NavTree and GF.NavTree.ClearActiveRoot then
			local opts
			if currentTab == GF.TAB_BROWSE then
				opts = {
					clearSelection = true,
					clearSelectionInActiveRoot = true,
					preserveBrowseResults = true,
				}
			end
			GF.NavTree:ClearActiveRoot(nil, opts)
		end
		if currentTab == GF.TAB_CREATE
			and GF.CreatePanel and GF.CreatePanel.ActivateCreateChannel then
			GF.CreatePanel:ActivateCreateChannel()
		elseif GF.BlizzardBorrow and GF.BlizzardBorrow.SetActiveOwner then
			GF.BlizzardBorrow.SetActiveOwner("groupfinder")
		end
	end)
	self.frame:SetScript("OnHide", function()
		local wasEverShown = MF._everShown == true
		MF:SetZoneListenerEnabled(false)
		GF.SaveFrameLayout(self.frame)
		if wasEverShown then
			MF:ApplyHideSideEffects()
			if MF._suppressNextHideSound then
				MF._suppressNextHideSound = nil
			elseif GF.UI and GF.UI.PlayUISound then
				GF.UI.PlayUISound("close")
			end
		end
		if GF.FloatButton and GF.FloatButton.RefreshAlert then
			GF.FloatButton:RefreshAlert()
		end
	end)
	GF.ApplyFrameLayout(self.frame)

	GF.UI.ApplySettingsFrameChrome(self.frame, L.ADDON_NAME or "GroupFinder")
	GF.UI.InstallMainWindowSkin(self.frame)
	local closeButton = self.frame.ClosePanelButton
		or self.frame.CloseButton
		or _G[(self.frame:GetName() or "") .. "CloseButton"]
	if not closeButton then
		closeButton = CreateFrame("Button", "GroupFinderAddonMainCloseButton", self.frame, "UIPanelCloseButtonDefaultAnchors")
	end
	closeButton:Show()
	self.frame.ClosePanelButton = closeButton
	closeButton:SetScript("OnClick", function()
		self:HideFrame()
	end)
	closeButton:SetScript("OnEnter", function(button)
		local LL = GF.L or {}
		GF.UI.BeginGameTooltip(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(LL.CLOSE or CLOSE or "Close", 1, 0.82, 0)
		GF.UI.ShowGameTooltip()
	end)
	closeButton:SetScript("OnLeave", GameTooltip_Hide)
	local dragBar = GF.UI.SetupTitleDragBar(self.frame, GF.SaveFrameLayout)
	if dragBar then
		dragBar:HookScript("OnMouseDown", activateCreateMainFrameFocus)
	end

	if GF.UI.InstallRecruitEyeLogo then
		GF.UI.InstallRecruitEyeLogo(self.frame)
	end

	self.panelBackplate = GF.UI.CreatePanelBackplate(self.frame)
	self.frame.panelBackplate = self.panelBackplate
	self.layoutHost = self.panelBackplate

	self.navHost = CreateFrame("Frame", nil, self.layoutHost)
	self.navHost:SetPoint("TOPLEFT", self.layoutHost, "TOPLEFT", contentPadX, -contentPadTop)
	self.navHost:SetPoint("BOTTOMLEFT", self.layoutHost, "BOTTOMLEFT", contentPadX, contentPadBottom)
	self.navHost:SetWidth(GF.GetNavWidth())
	self.navHost:SetClipsChildren(true)
	self.navHost:SetFrameLevel(self.layoutHost:GetFrameLevel() + 5)
	GF.UI.InstallBrowseSidePanelChrome(self.navHost)

	self.contentClip = CreateFrame("Frame", nil, self.layoutHost)
	self.contentClip:SetClipsChildren(true)
	self.contentClip:SetFrameLevel(self.layoutHost:GetFrameLevel() + 5)
	GF.UI.InstallTransmogTabsFrameBackground(self.contentClip)

	self.content = GF.UI.CreateContentPanel(self.contentClip)
	self.content:SetAllPoints(self.contentClip)

	self.contentBody = CreateFrame("Frame", nil, self.content)
	self.contentBody:SetFrameLevel(self.content:GetFrameLevel() + 1)

	self.auxContentClip = CreateFrame("Frame", nil, self.layoutHost)
	self.auxContentClip:SetClipsChildren(true)
	self.auxContentClip:SetFrameLevel(self.layoutHost:GetFrameLevel() + 5)
	GF.UI.InstallTransmogTabsFrameBackground(self.auxContentClip)
	self.auxContentClip:Hide()

	self.auxContent = GF.UI.CreateContentPanel(self.auxContentClip)
	self.auxContent:SetAllPoints(self.auxContentClip)

	self.auxContentBody = CreateFrame("Frame", nil, self.auxContent)
	self.auxContentBody:SetAllPoints(self.auxContent)
	self.auxContentBody:SetFrameLevel(self.auxContent:GetFrameLevel() + 1)

	self.blockContent = CreateFrame("Frame", nil, self.layoutHost)
	self.blockContent:SetClipsChildren(true)
	self.blockContent:SetFrameLevel(self.layoutHost:GetFrameLevel() + 5)
	self.blockContent:Hide()

	GF.CreateDrawer:Init(self.content, self.contentBody)

	GF.SubtitleBar:Init(self.content, 0)

	GF.NavTree:Init(self.navHost)

	self:LayoutContent(false)

	self.browseHost = CreateFrame("Frame", nil, self.contentBody)
	self.browseHost:SetAllPoints()
	self.browseHost:SetFrameLevel(self.content:GetFrameLevel() + 2)
	GF.FindGroupTab:Init(self.browseHost)

	GF.FilterPanel:Init(self.frame)

	GF.TabBar:Init(self.frame)
	if GF.BlocklistPanel and GF.BlocklistPanel.ApplyModuleVisibility then
		GF.BlocklistPanel:ApplyModuleVisibility()
	end
	self.frame.OnTabChanged = function(_, tabID)
		self:OnTabChanged(tabID)
	end

	self.activityCount = GF.UI.CreateFontString(self.frame, "OVERLAY", "GameFontDisableSmall")
	self.activityCount:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -(GF.ACTIVITY_COUNT_RIGHT or 28), GF.FRAME_BODY_BAR_Y)
	self.activityCount:SetJustifyH("RIGHT")
	self.activityCount:Hide()

	self.browseStatusHint = GF.UI.CreateFontString(self.frame, "OVERLAY", "GameFontHighlight")
	self.browseStatusHint:SetPoint("BOTTOM", self.frame, "BOTTOM", 48, GF.FRAME_BODY_BAR_Y)
	self.browseStatusHint:SetTextColor(1, 0.82, 0)
	self.browseStatusHint:SetJustifyH("CENTER")
	self.browseStatusHint:Hide()

	GF.UI.SetupResizeHandle(self.frame, {
		minW = GF.FRAME_MIN_W,
		minH = GF.FRAME_MIN_H,
		onResize = function(_, _width, _height, isActive)
			if isActive ~= false and MF._navDragFrozenW and MF.NavWidthDragEnd then
				MF:NavWidthDragEnd(false)
			end
			GF._frameResizing = isActive ~= false
			local tabID = MF:GetCurrentTabID()
			local fg = getFindGroupTab()
			if tabID == GF.TAB_BROWSE and fg and fg.SetFrameResizing then
				fg:SetFrameResizing(isActive ~= false)
			end
			if MF:NavVisibleForTab(tabID) and GF.NavTree then
				GF.NavTree._frameResizing = isActive ~= false
			end
			if tabID == GF.TAB_BLOCKLIST and GF.BlocklistPanel and MF._blocklistInited then
				GF.BlocklistPanel._frameResizing = isActive ~= false
			end
			if tabID == GF.TAB_SETTINGS and GF.SettingsPanel and MF._settingsInited then
				GF.SettingsPanel._frameResizing = isActive ~= false
			end
			if tabID == GF.TAB_CREATE then
				if GF.CreatePanel and MF._createInited then
					GF.CreatePanel._frameResizing = isActive ~= false
				end
				if GF.ApplicantsPanel and MF._applicantsInited then
					GF.ApplicantsPanel._frameResizing = isActive ~= false
				end
			end
		end,
		onResizeStopped = function(f)
			GF._frameResizing = false
			local fg = getFindGroupTab()
			if fg and fg.SetFrameResizing then
				fg:SetFrameResizing(false)
				if fg.CancelRelayoutDebounce then
					fg:CancelRelayoutDebounce()
				end
			end
			if GF.NavTree then
				GF.NavTree._frameResizing = false
			end
			if GF.BlocklistPanel and MF._blocklistInited then
				GF.BlocklistPanel._frameResizing = false
			end
			if GF.SettingsPanel and MF._settingsInited then
				GF.SettingsPanel._frameResizing = false
				if GF.SettingsPanel.CancelUpdateScrollDebounce then
					GF.SettingsPanel:CancelUpdateScrollDebounce()
				end
			end
			if GF.CreatePanel and MF._createInited then
				GF.CreatePanel._frameResizing = false
				if GF.CreatePanel.CancelUpdateScrollLayoutDebounce then
					GF.CreatePanel:CancelUpdateScrollLayoutDebounce()
				end
			end
			if GF.ApplicantsPanel and MF._applicantsInited then
				GF.ApplicantsPanel._frameResizing = false
				if GF.ApplicantsPanel.CancelRelayoutDebounce then
					GF.ApplicantsPanel:CancelRelayoutDebounce()
				end
			end
			GF.SaveFrameLayout(f)
			self:OnFrameResized()
		end,
	})

	self.selection = nil
	self.frame:Hide()
	if UISpecialFrames then
		tinsert(UISpecialFrames, self.frame:GetName())
	end
	if GF.ApplyFrameStrata then
		GF.ApplyFrameStrata()
	end
	if GF.ApplyPanelScale then
		GF.ApplyPanelScale()
	end
	self:RefreshRecruitEyeLogo()
end

function MF:GetCurrentTabID()
	if GF.TabBar and GF.TabBar.GetCurrent then
		return GF.TabBar:GetCurrent()
	end
	return GF.TAB_BROWSE
end

function MF:NavVisibleForTab(tabID)
	tabID = tabID or self:GetCurrentTabID()
	return tabID ~= GF.TAB_SETTINGS and tabID ~= GF.TAB_BLOCKLIST and tabID ~= GF.TAB_DEBUG
end

function MF:AuxContentVisibleForTab(tabID)
	tabID = tabID or self:GetCurrentTabID()
	return tabID == GF.TAB_SETTINGS or tabID == GF.TAB_DEBUG
end

function MF:IsAuxPanelHost(hostKey)
	return hostKey == "settingsHost" or hostKey == "debugHost"
end

function MF:EnsurePanelHost(hostKey)
	local host = self[hostKey]
	if host then
		return host
	end
	local parent = self:IsAuxPanelHost(hostKey) and self.auxContentBody or self.contentBody or self.content
	host = CreateFrame("Frame", nil, parent)
	host:SetAllPoints()
	host:SetFrameLevel((parent:GetFrameLevel() or self.content:GetFrameLevel()) + 2)
	host:Hide()
	self[hostKey] = host
	return host
end

function MF:EnsureCreatePanel()
	if self._createInited then
		return
	end
	self._createInited = true
	GF.CreatePanel:Init(GF.CreateDrawer.panelHost)
	if self.selection and GF.CreatePanel.SetSelection then
		GF.CreatePanel:SetSelection(self.selection)
	end
end

function MF:EnsureApplicantsPanel()
	if self._applicantsInited then
		return
	end
	self._applicantsInited = true
	GF.ApplicantsPanel:Init(self:EnsurePanelHost("applicantsHost"))
end

function MF:EnsureSettingsPanel()
	if self._settingsInited then
		return
	end
	self._settingsInited = true
	GF.SettingsPanel:Init(self:EnsurePanelHost("settingsHost"))
end

function MF:EnsureDebugPanel()
	if self._debugInited then
		return
	end
	self._debugInited = true
	GF.DebugPanel:Init(self:EnsurePanelHost("debugHost"))
end

function MF:EnsureBlocklistPanel()
	if self._blocklistInited then
		return
	end
	self._blocklistInited = true
	self:LayoutBlockContent()
	GF.BlocklistPanel:Init(self.blockContent)
end

function MF:EnsureCreateTabPanels()
	self:EnsureCreatePanel()
	self:EnsureApplicantsPanel()
end

function MF:UpdateActivityCount(count)
	if not self.activityCount then
		return
	end
	local L = GF.L or {}
	if GF.TabBar:GetCurrent() ~= GF.TAB_BROWSE then
		self.activityCount:Hide()
		return
	end
	local filtered = count or 0
	local raw = GF.Result and GF.Result:GetRawCount() or filtered
	local text
	if raw > filtered then
		local fmt = L.ACTIVITY_COUNT_TOTAL_FMT or "活动总数：%d/%d"
		text = string.format(fmt, filtered, raw)
	else
		local fmt = L.ACTIVITY_COUNT_FMT or "当前活动数：%d"
		text = string.format(fmt, filtered)
	end
	self.activityCount:SetText(text)
	self.activityCount:Show()
end

function MF:UpdateBrowseStatusHint(text)
	if not self.browseStatusHint then
		return
	end
	if not text or text == "" or not GF.TabBar or GF.TabBar:GetCurrent() ~= GF.TAB_BROWSE then
		self.browseStatusHint:Hide()
		return
	end
	self.browseStatusHint:SetText(text)
	self.browseStatusHint:Show()
end

function MF:LayoutContentBody()
	if not self.contentBody or not self.content then
		return
	end
	local subtitle = GF.SubtitleBar
	local sbFrame = subtitle and subtitle.frame
	local headerFrame = subtitle and subtitle.columnHeaderHost
	local subtitleShown = subtitle and subtitle._browseMode and sbFrame and sbFrame:IsShown()
	self.contentBody:ClearAllPoints()
	if subtitleShown and sbFrame then
		if headerFrame then
			self.contentBody:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 4))
			self.contentBody:SetPoint("TOPRIGHT", headerFrame, "BOTTOMRIGHT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 4))
		else
			self.contentBody:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, 0)
			self.contentBody:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, 0)
		end
		self.contentBody:SetPoint("BOTTOMRIGHT", sbFrame, "TOPRIGHT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
	else
		self.contentBody:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, 0)
		self.contentBody:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", 0, 0)
	end
	if GF.CreateDrawer and GF.CreateDrawer.Layout then
		GF.CreateDrawer:Layout()
	end
end

function MF:LayoutAuxContent()
	if not self.auxContentClip or not self.auxContent or not self.auxContentBody then
		return
	end
	local layoutHost = self.layoutHost or self.frame
	local anchor = layoutHost and layoutHost._gfPanelBackground or layoutHost
	if not anchor then
		return
	end
	self.auxContentClip:ClearAllPoints()
	self.auxContentClip:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
	self.auxContentClip:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
	self.auxContent:ClearAllPoints()
	self.auxContent:SetAllPoints(self.auxContentClip)
	self.auxContentBody:ClearAllPoints()
	self.auxContentBody:SetAllPoints(self.auxContent)
end

function MF:LayoutBlockContent()
	if not self.blockContent then
		return
	end
	local layoutHost = self.layoutHost or self.frame
	local anchor = layoutHost and layoutHost._gfPanelBackground or layoutHost
	if not anchor then
		return
	end
	self.blockContent:ClearAllPoints()
	self.blockContent:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
	self.blockContent:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
end

function MF:NavWidthDragBegin()
	if not self.content or not self.contentClip or not self.frame then
		return
	end
	local frameW = self.frame:GetWidth() or GF.FRAME_W or 900
	self._navDragFrozenW = GF.GetNavContentWidth(frameW, GF.GetNavWidth())
	self.content:ClearAllPoints()
	self.content:SetPoint("TOPLEFT", self.contentClip, "TOPLEFT", 0, 0)
	self.content:SetPoint("TOPRIGHT", self.contentClip, "TOPLEFT", self._navDragFrozenW, 0)
	self.content:SetPoint("BOTTOMLEFT", self.contentClip, "BOTTOMLEFT", 0, 0)
	self.content:SetPoint("BOTTOMRIGHT", self.contentClip, "BOTTOMLEFT", self._navDragFrozenW, 0)
	GF._frameResizing = true
end

function MF:NavWidthDragPreview(w)
	if not self.navHost then
		return
	end
	w = GF.ClampNavWidth(w)
	if self._navDragPreviewW == w then
		return
	end
	self._navDragPreviewW = w
	self.navHost:SetWidth(w)
end

function MF:NavWidthDragEnd(save, previewW)
	if not self._navDragFrozenW then
		return
	end
	local w = GF.ClampNavWidth(previewW or self._navDragPreviewW or GF.GetNavWidth())
	self._navDragPreviewW = nil
	self._navDragFrozenW = nil
	GF._frameResizing = false
	if save then
		w = GF.SaveNavWidth(w)
	else
		w = GF.GetNavWidth()
	end
	self.navHost:SetWidth(w)
	self:LayoutContent(false)
	if save then
		if GF.NavTree and GF.NavTree.SyncAfterHostWidth then
			GF.NavTree:SyncAfterHostWidth(w)
		end
		self:ApplyFrameResize()
	end
end

function MF:LayoutContent(fullWidth)
	if not self.contentClip or not self.content or not self.frame or not self.navHost then
		return
	end
	local layoutHost = self.layoutHost or self.frame
	local padX = GF.MAIN_PANEL_CONTENT_PADDING_X or GF.FRAME_PAD or 4
	local padTop = GF.MAIN_PANEL_CONTENT_PADDING_TOP or (GF.FRAME_TITLE_TOP + 2)
	local padBottom = GF.MAIN_PANEL_CONTENT_PADDING_BOTTOM or GF.FRAME_CONTENT_BOTTOM
	local ox = GF.CONTENT_NAV_OFFSET_X or 0
	self.contentClip:ClearAllPoints()
	if fullWidth then
		self.contentClip:SetPoint("TOPLEFT", layoutHost, "TOPLEFT", padX, -padTop)
		self.contentClip:SetPoint("BOTTOMRIGHT", layoutHost, "BOTTOMRIGHT", -padX, padBottom)
	else
		self.contentClip:SetPoint("TOPLEFT", self.navHost, "TOPRIGHT", ox, 0)
		self.contentClip:SetPoint("BOTTOMRIGHT", layoutHost, "BOTTOMRIGHT", -padX, padBottom)
	end
	if not self._navDragFrozenW then
		self.content:ClearAllPoints()
		self.content:SetAllPoints(self.contentClip)
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
	local hasActive = GF.Listing and GF.Listing:HasActive()
	if self.applicantsHost then
		self.applicantsHost:Show()
	end
	GF.ApplicantsPanel:Show()
	self:UpdateNavInteractionState(GF.TAB_CREATE)
	if GF.CreateDrawer then
		GF.CreateDrawer:SetTabActive(true)
		GF.CreateDrawer:SyncDefaultState(hasActive, {
			allowOccupiedPrompt = opts.allowOccupiedPrompt == true,
		})
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
	if GF.Listing and GF.Listing.OnGroupRosterChanged then
		GF.Listing:OnGroupRosterChanged()
	end
	self:RefreshListingPanels()
	refreshCreateTabIfActive()
	if GF.FloatButton and GF.FloatButton.RefreshAlert then
		GF.FloatButton:RefreshAlert()
	end
end

function MF:OnTabChanged(tabID, opts)
	opts = opts or {}
	if not self.browseHost then
		return
	end
	local showAuxContent = self:AuxContentVisibleForTab(tabID)
	local showBlockContent = tabID == GF.TAB_BLOCKLIST
	local showNav = self:NavVisibleForTab(tabID)
	if not showNav and GF.NavFlyout and GF.NavFlyout.HideAll then
		GF.NavFlyout:HideAll()
	end
	if self.navHost then
		self.navHost:SetShown(showNav)
	end
	if GF.NavTree and GF.NavTree.SetVisible then
		GF.NavTree:SetVisible(showNav)
	end
	self:UpdateNavInteractionState(tabID)
	if self.contentClip then
		self.contentClip:SetShown(not showAuxContent and not showBlockContent)
	end
	if self.auxContentClip then
		self.auxContentClip:SetShown(showAuxContent)
	end
	if self.blockContent then
		self.blockContent:SetShown(showBlockContent)
	end
	if showAuxContent then
		self:LayoutAuxContent()
	elseif showBlockContent then
		self:LayoutBlockContent()
	else
		self:LayoutContent(false)
	end
	if GF.SubtitleBar then
		if tabID == GF.TAB_BROWSE then
			GF.SubtitleBar:SetBrowseVisible(true)
		else
			GF.SubtitleBar:SetBrowseVisible(false)
		end
	end
	if GF.FilterPanel and tabID ~= GF.TAB_BROWSE then
		GF.FilterPanel:Hide()
	end

	if GF.CreateDrawer then
		GF.CreateDrawer:SetTabActive(tabID == GF.TAB_CREATE)
	end

	self.browseHost:SetShown(tabID == GF.TAB_BROWSE)
	if tabID == GF.TAB_CREATE then
		self:EnsureCreateTabPanels()
		if self.selection and GF.CreatePanel and GF.CreatePanel.SetSelection then
			GF.CreatePanel:SetSelection(self.selection)
		end
	end
	if tabID == GF.TAB_SETTINGS then
		self:EnsureSettingsPanel()
	end
	if tabID == GF.TAB_DEBUG then
		self:EnsureDebugPanel()
	end
	if tabID == GF.TAB_BLOCKLIST then
		self:EnsureBlocklistPanel()
	end
	if self.settingsHost then
		self.settingsHost:SetShown(tabID == GF.TAB_SETTINGS)
	end
	if self.debugHost then
		self.debugHost:SetShown(tabID == GF.TAB_DEBUG)
	end

	local fg = getFindGroupTab()
	if tabID == GF.TAB_BROWSE then
		fg:Show()
		if GF.CreatePanel and GF.CreatePanel.LeaveTab then
			GF.CreatePanel:LeaveTab()
		elseif GF.CreatePanel then
			GF.CreatePanel:Hide()
		end
		GF.ApplicantsPanel:Hide()
		GF.SettingsPanel:Hide()
		GF.BlocklistPanel:Hide()
		if GF.DebugPanel and self._debugInited then
			GF.DebugPanel:Hide()
		end
		if not opts.skipDeferredLayout then
			self:ScheduleDeferredShowLayout()
		end
	elseif tabID == GF.TAB_CREATE then
		fg:Hide()
		GF.SettingsPanel:Hide()
		GF.BlocklistPanel:Hide()
		if GF.DebugPanel and self._debugInited then
			GF.DebugPanel:Hide()
		end
		refreshCreateTabIfActive({ allowOccupiedPrompt = not opts.skipDeferredLayout })
	elseif tabID == GF.TAB_BLOCKLIST then
		fg:Hide()
		if GF.CreatePanel and GF.CreatePanel.LeaveTab then
			GF.CreatePanel:LeaveTab()
		elseif GF.CreatePanel then
			GF.CreatePanel:Hide()
		end
		GF.ApplicantsPanel:Hide()
		GF.SettingsPanel:Hide()
		if GF.DebugPanel and self._debugInited then
			GF.DebugPanel:Hide()
		end
		GF.BlocklistPanel:Show()
	elseif tabID == GF.TAB_SETTINGS then
		fg:Hide()
		if GF.CreatePanel and GF.CreatePanel.LeaveTab then
			GF.CreatePanel:LeaveTab()
		elseif GF.CreatePanel then
			GF.CreatePanel:Hide()
		end
		GF.ApplicantsPanel:Hide()
		GF.BlocklistPanel:Hide()
		if GF.DebugPanel and self._debugInited then
			GF.DebugPanel:Hide()
		end
		GF.SettingsPanel:Show()
	elseif tabID == GF.TAB_DEBUG then
		fg:Hide()
		if GF.CreatePanel and GF.CreatePanel.LeaveTab then
			GF.CreatePanel:LeaveTab()
		elseif GF.CreatePanel then
			GF.CreatePanel:Hide()
		end
		GF.ApplicantsPanel:Hide()
		GF.BlocklistPanel:Hide()
		GF.SettingsPanel:Hide()
		GF.DebugPanel:Show()
	end
	if self.activityCount then
		if tabID == GF.TAB_BROWSE then
			local n = GF.Result and GF.Result:GetCount() or 0
			self:UpdateActivityCount(n)
			local fg = getFindGroupTab()
			if fg and fg.UpdateSearchHint then
				fg:UpdateSearchHint()
			end
		else
			self.activityCount:Hide()
			self:UpdateBrowseStatusHint(nil)
		end
	end
	if showNav and GF.NavFlyout and GF.NavFlyout.ReanchorOpenPanels then
		GF.NavFlyout:ReanchorOpenPanels()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if self.frame and self.frame:IsShown() and self:NavVisibleForTab(self:GetCurrentTabID()) then
					GF.NavFlyout:ReanchorOpenPanels()
				end
			end)
		end
	end
end

function MF:OnSelectionChanged(node, opts)
	opts = opts or {}
	self.selection = node
	syncSelectedDifficultyFilter(node)
	local fg = getFindGroupTab()
	if fg then
		fg:SetSelection(node, opts)
	end
	if self:GetCurrentTabID() == GF.TAB_CREATE and GF.CreatePanel then
		GF.CreatePanel:SetSelection(node)
		if not (self.frame and self.frame:IsShown()) then
			return
		end
		local hasActive = GF.Listing and GF.Listing.HasActive and GF.Listing:HasActive()
		local canLead = GF.Listing and GF.Listing.CanLeadListing and GF.Listing:CanLeadListing()
		local canCreate = GF.NavData and GF.NavData.IsCreateable and GF.NavData.IsCreateable(node)
		local drawer = GF.CreateDrawer
		if not hasActive and drawer and drawer.IsOpen and drawer:IsOpen()
			and (not canLead or not canCreate) then
			drawer:Close(true)
		end
		if not hasActive and canLead and canCreate and drawer then
			local wasOpen = drawer.IsOpen and drawer:IsOpen()
			if drawer.Open then
				drawer:Open({ mode = "create", silent = wasOpen == true, allowOccupiedPrompt = true })
			end
		end
	end
	if GF.SubtitleBar then
		if GF.SubtitleBar.SyncFromSelection then
			GF.SubtitleBar:SyncFromSelection(node)
		end
		if GF.SubtitleBar.UpdateFilterState then
			GF.SubtitleBar:UpdateFilterState()
		end
		if GF.SubtitleBar.UpdateRefreshButtonState then
			GF.SubtitleBar:UpdateRefreshButtonState()
		end
	end
	if GF.FilterPanel then
		local db = GF.GetDB and GF.GetDB()
		local onBrowse = self:GetCurrentTabID() == GF.TAB_BROWSE
		local searchable = node and fg and fg:IsSearchableSelection(node)
		if db and db.autoExpandFilter and onBrowse and searchable then
			GF.FilterPanel:Show()
		elseif node and GF.FilterPanel:IsShown() then
			GF.FilterPanel:AnchorToMain()
			if GF.FilterPanel.RebuildIfNeeded then
				GF.FilterPanel:RebuildIfNeeded(false)
			end
		end
	end
end

function MF:OnFrameResized()
	if self._resizeDebounce and self._resizeDebounce.Cancel then
		self._resizeDebounce:Cancel()
	end
	if not C_Timer or not C_Timer.After then
		self:ApplyFrameResize()
		return
	end
	self._resizeDebounce = C_Timer.After(GF.LAYOUT_RESIZE_DEBOUNCE or 0.1, function()
		self._resizeDebounce = nil
		self:ApplyFrameResize()
	end)
end

function MF:ApplyFrameResize()
	local tabID = self:GetCurrentTabID()
	if self:AuxContentVisibleForTab(tabID) then
		self:LayoutAuxContent()
	end
	if tabID == GF.TAB_BLOCKLIST then
		self:LayoutBlockContent()
	end
	local fg = getFindGroupTab()
	if tabID == GF.TAB_BROWSE and fg and fg.Relayout then
		if fg.SuppressRelayout then
			fg:SuppressRelayout(0.25)
		end
		if fg.CancelRelayoutDebounce then
			fg:CancelRelayoutDebounce()
		end
		fg:Relayout()
		local bp = fg.GetPanel and fg:GetPanel()
		if bp and bp.FlushRowVisibility then
			bp:FlushRowVisibility()
		end
	end
	if self:NavVisibleForTab(tabID) and GF.NavTree then
		if GF.NavTree.CancelLayoutDebounce then
			GF.NavTree:CancelLayoutDebounce()
		end
		if GF.NavTree.ScheduleLayoutRows then
			GF.NavTree:ScheduleLayoutRows()
		end
	end
	if tabID == GF.TAB_SETTINGS and GF.SettingsPanel and self._settingsInited and GF.SettingsPanel.UpdateScroll then
		GF.SettingsPanel:UpdateScroll()
	end
	if tabID == GF.TAB_DEBUG and GF.DebugPanel and self._debugInited and GF.DebugPanel.UpdateScroll then
		GF.DebugPanel:UpdateScroll()
	end
	if GF.FilterPanel and GF.FilterPanel.IsShown and GF.FilterPanel:IsShown() then
		GF.FilterPanel:AnchorToMain()
	end
	if tabID == GF.TAB_CREATE and GF.ApplicantsPanel and self._applicantsInited and GF.ApplicantsPanel.Relayout then
		local ap = GF.ApplicantsPanel
		ap._relayoutSuppressUntil = GetTime() + 0.25
		if ap.CancelRelayoutDebounce then
			ap:CancelRelayoutDebounce()
		end
		ap:Relayout()
	end
	if tabID == GF.TAB_CREATE and GF.CreatePanel and self._createInited then
		if GF.CreatePanel.CancelUpdateScrollLayoutDebounce then
			GF.CreatePanel:CancelUpdateScrollLayoutDebounce()
		end
		if GF.CreatePanel.UpdateScrollLayout then
			GF.CreatePanel:UpdateScrollLayout()
		end
	end
	if tabID == GF.TAB_BLOCKLIST and GF.BlocklistPanel and self._blocklistInited and GF.BlocklistPanel.Refresh then
		GF.BlocklistPanel:Refresh()
	end
end

function MF:OnSearchResults()
	if GF.FindGroupTab and GF.FindGroupTab.OnSearchResults then
		GF.FindGroupTab:OnSearchResults()
	end
end

function MF:OnSearchFailed()
	if GF.FindGroupTab and GF.FindGroupTab.OnSearchFailed then
		GF.FindGroupTab:OnSearchFailed()
	end
end

function MF:OnAvailabilityUpdate()
	if not self.frame or not self.frame:IsShown() then
		self._navDirty = true
		return
	end
	if self._navDebounce and self._navDebounce.Cancel then
		self._navDebounce:Cancel()
	end
	local function apply()
		local expanded = GF.NavTree and GF.NavTree.expanded
		local rebuilt = GF.NavData.OnAvailabilityChanged and GF.NavData.OnAvailabilityChanged(expanded)
		if rebuilt and GF.NavTree then
			if GF.NavFlyout and GF.NavFlyout.HideAll then
				GF.NavFlyout:HideAll()
			end
			GF.NavTree:Refresh()
		end
	end
	if not C_Timer or not C_Timer.After then
		apply()
		return
	end
	self._navDebounce = C_Timer.After(0.3, function()
		self._navDebounce = nil
		apply()
	end)
end

function MF:OnActiveEntryUpdate()
	if not self.browseHost then
		return
	end
	local hasActive = GF.Listing and GF.Listing:HasActive()
	if GF.Listing and GF.Listing.SyncActiveEntryOwnership then
		GF.Listing:SyncActiveEntryOwnership(hasActive == true)
	end
	if not hasActive then
		if GF.Listing and GF.Listing.ClearAutoInviteForSession then
			GF.Listing:ClearAutoInviteForSession()
		end
	end
	self:RefreshListingPanels()
	self:RefreshRecruitEyeLogo(hasActive == true)
	refreshCreateTabIfActive()
	local fg = getFindGroupTab()
	if fg then
		fg:UpdateBlocked()
	end
	if GF.FloatButton and GF.FloatButton.RefreshAlert then
		GF.FloatButton:RefreshAlert()
	end
end

function MF:OnApplicantsUpdate()
	if GF.Listing and GF.Listing.QueueAutoInvite then
		GF.Listing:QueueAutoInvite()
	end
	if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
		GF.ApplicantsPanel:Refresh()
	end
	if GF.FloatButton and GF.FloatButton.RefreshAlert then
		GF.FloatButton:RefreshAlert()
	end
end

function MF:ShowFrame()
	if GF.Availability then
		local msg = GF.Availability:GetBlockMessage()
		if msg then
			GF.Availability:NotifyBlocked(msg)
			return
		end
	end
	if GF.UsageGuideDialog and GF.UsageGuideDialog.CloseForMainFrameOpen then
		GF.UsageGuideDialog:CloseForMainFrameOpen()
	end
	self:Init()
	if GF.ApplyPanelScale then
		GF.ApplyPanelScale()
	end
	local wasShown = self.frame and self.frame:IsShown()
	if not wasShown then
		self:RecenterFrame()
	end
	local reshow = self._everShown == true
	self._everShown = true
	local L = GF.L or {}
	local title = L.ADDON_NAME or "GroupFinder"
	GF.UI.ApplySettingsFrameChrome(self.frame, title)
	self:RefreshRecruitEyeLogo()
	if GF.navTree then
		GF.NavData.RefreshHistory()
	elseif not reshow then
		GF.NavData.Rebuild()
	end
	if not reshow then
		if GF.NavTree then
			GF.NavTree:Refresh()
		end
		self:OnTabChanged(GF.TabBar:GetCurrent(), { skipDeferredLayout = true })
	end
	if self._navDirty then
		self._navDirty = false
		local expanded = GF.NavTree and GF.NavTree.expanded
		local rebuilt = GF.NavData.OnAvailabilityChanged and GF.NavData.OnAvailabilityChanged(expanded)
		if rebuilt and GF.NavTree then
			if GF.NavFlyout and GF.NavFlyout.HideAll then
				GF.NavFlyout:HideAll()
			end
			GF.NavTree:Refresh()
		end
	end
	self.frame:Show()
	if GF.SubtitleBar and GF.SubtitleBar.ReclaimSearchBoxForBrowse then
		GF.SubtitleBar:ReclaimSearchBoxForBrowse()
	end
	if GF.FloatButton and GF.FloatButton.RefreshAlert then
		GF.FloatButton:RefreshAlert()
	end
	if GF.TabBar and GF.TabBar:GetCurrent() == GF.TAB_CREATE then
		self:UpdateCreateTab({ allowOccupiedPrompt = true })
	end
	if not wasShown and self._suppressNextShowSound then
		self._suppressNextShowSound = nil
	elseif not wasShown and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("open")
	end
	self:SetZoneListenerEnabled(true)
	self:ScheduleDeferredShowLayout()
	local fg = getFindGroupTab()
	if fg and fg.UpdateTitle then
		fg:UpdateTitle()
		if fg.UpdateSearchHint then
			fg:UpdateSearchHint()
		end
	end
	if GF.SubtitleBar and GF.SubtitleBar.UpdateFilterState then
		GF.SubtitleBar:UpdateFilterState()
	end
	if reshow and GF.TabBar and GF.TabBar:GetCurrent() == GF.TAB_BROWSE and self.activityCount then
		local n = GF.Result and GF.Result:GetCount() or 0
		self:UpdateActivityCount(n)
	end
end

function MF:RefreshLocale()
	local L = GF.L or {}
	if self.frame then
		GF.UI.ApplySettingsFrameChrome(self.frame, L.ADDON_NAME or "GroupFinder")
	end
	if GF.TabBar and GF.TabBar.RefreshLocale then
		GF.TabBar:RefreshLocale()
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
	if GF.NavFlyout and GF.NavFlyout.HideAll then
		GF.NavFlyout:HideAll()
	end
	if GF.FilterPanel then
		GF.FilterPanel:Hide()
	end
	if GF.CreateDrawer then
		GF.CreateDrawer:Close(true)
	end
	local fg = getFindGroupTab()
	if fg and fg.OnFrameHidden then
		fg:OnFrameHidden()
	end
	if GF.SubtitleBar and GF.SubtitleBar.ReleaseBlizzardSearchBox then
		GF.SubtitleBar:ReleaseBlizzardSearchBox()
	end
	if GF.CreatePanel and GF.CreatePanel.ReleaseCreateFields then
		GF.CreatePanel:ReleaseCreateFields("addon")
	end
	if GF.Hook and GF.Hook.OnGFUIClosed then
		GF.Hook.OnGFUIClosed()
	end
end

function MF:HideFrame()
	if self.frame and self.frame:IsShown() then
		self.frame:Hide()
	end
end

function MF:HasActiveListing()
	if not C_LFGList then
		return false
	end
	if C_LFGList.HasActiveEntryInfo then
		return C_LFGList.HasActiveEntryInfo()
	end
	if C_LFGList.GetActiveEntryInfo then
		return C_LFGList.GetActiveEntryInfo() ~= nil
	end
	return false
end

function MF:ApplyOpenTabPolicy()
	if not self:HasActiveListing() then
		return
	end
	if GF.TabBar and GF.TabBar.SelectTab then
		GF.TabBar:SelectTab(GF.TAB_CREATE)
	end
end

function MF:OpenFrame()
	self:ShowFrame()
	if self.frame and self.frame:IsShown() then
		self:ApplyOpenTabPolicy()
	end
end

function MF:OpenBrowseTab()
	self:ShowFrame()
	if self.frame and self.frame:IsShown() and GF.TabBar and GF.TabBar.SelectTab then
		GF.TabBar:SelectTab(GF.TAB_BROWSE)
	end
end

function MF:OpenCreateTab()
	self:ShowFrame()
	if self.frame and self.frame:IsShown() and GF.TabBar then
		if GF.TabBar.Select then
			GF.TabBar:Select(GF.TAB_CREATE)
		elseif GF.TabBar.SelectTab then
			GF.TabBar:SelectTab(GF.TAB_CREATE)
		end
	end
end

function MF:Toggle()
	if self.frame and self.frame:IsShown() then
		self:HideFrame()
	else
		self:OpenFrame()
	end
end

function MF:OpenSettingsTab()
	self:ShowFrame()
	if self.frame and self.frame:IsShown() then
		GF.TabBar:SelectTab(GF.TAB_SETTINGS)
	end
end

function MF:OpenDebugTab()
	self:ShowFrame()
	if self.frame and self.frame:IsShown() and GF.TabBar and GF.TabBar.SelectTab then
		GF.TabBar:SelectTab(GF.TAB_DEBUG)
	end
end
