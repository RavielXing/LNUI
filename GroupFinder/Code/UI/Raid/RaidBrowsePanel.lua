local _, GF = ...

GF.RaidBrowsePanel = {}
local Panel = GF.RaidBrowsePanel
local UI = GF.UI
local STYLE = GF.RAID_BROWSE_PANEL_STYLE
local function text(key) return (GF.L or {})[key] or key end

function Panel:ShouldUse(tabID, workspaceID)
	return (tabID == GF.TAB_BROWSE or tabID == GF.TAB_CREATE)
		and workspaceID == GF.WORKSPACE_RAID
end

local function currentTabID()
	local main = GF.MainFrame
	return main and main:GetCurrentTabID()
end

function Panel:IsCreateMode()
	return currentTabID() == GF.TAB_CREATE
end

local function seasonRoot()
	local nav = GF.NavData
	local root = nav and nav.FindNodeByKey and nav.FindNodeByKey("season_raid")
	if root and nav.EnsureChildren then nav.EnsureChildren(root) end
	return root
end

local function searchable(node)
	return node ~= nil and GF.NavData and GF.NavData.IsSearchable
		and GF.NavData.IsSearchable(node) == true
end

local function creatable(node)
	if not node or node.disabled or node.isLeaf ~= true then return false end
	local view = GF.LFGWorkspaceView
	if view and view.CanCreateSelection then
		return view:CanCreateSelection(node, GF.WORKSPACE_RAID) == true
	end
	return GF.NavData and GF.NavData.CanCreateFromNode
		and GF.NavData.CanCreateFromNode(node) == true or false
end

local function canSelect(node, createMode)
	if createMode then return creatable(node) end
	return searchable(node)
end

local function canChooseDifficulty(node)
	if node.disabled then return false end
	for _, child in ipairs(node.children or {}) do
		if child.navKind == "season_raid" and creatable(child) then return true end
	end
	return false
end

local function unavailableReason(node)
	if node and node.disabledReason then return node.disabledReason end
	for _, child in ipairs(node and node.children or {}) do
		if child.disabledReason then return child.disabledReason end
	end
	return text("NAV_ACTIVITY_UNAVAILABLE")
end

function Panel:GetEntries()
	local root = seasonRoot()
	if not root then return {} end
	local entries, createMode = {}, self:IsCreateMode()
	if not createMode then
		entries[1] = { key = root.key, label = text("RAID_BROWSE_ALL"), enabled = searchable(root),
			texture = STYLE.allRaidsTexture, texCoords = STYLE.allRaidsTexCoords }
	end
	for _, node in ipairs(root.children or {}) do
		if node.journalInstanceID and node.navKind == "season_raid" then
			entries[#entries + 1] = {
				key = node.key, label = node.label,
				enabled = createMode and canChooseDifficulty(node) or (not createMode and searchable(node)),
				texture = node.visualTexture, texCoords = node.visualTexCoords,
			}
		end
	end
	return entries
end

function Panel:IsSelected(key)
	local selection = self.selection
	if not selection then return false end
	if selection.key == key then return true end
	if key == "season_raid" then return false end
	local node = GF.NavData.FindNodeByKey(key)
	for _, child in ipairs(node and node.children or {}) do
		if child.key == selection.key then return true end
	end
	return false
end

function Panel:Select(key)
	if not self.frame or not self.frame:IsShown() then return false end
	local main = GF.MainFrame
	if not (main and self:ShouldUse(main:GetCurrentTabID(), main:GetCurrentWorkspaceID())) then
		return false
	end
	seasonRoot()
	local node = GF.NavData.FindNodeByKey(key)
	local createMode = self:IsCreateMode()
	if not node or node.navKind ~= "season_raid" or not canSelect(node, createMode) then return false end
	if createMode then
		-- The shared selection owner updates the creation form and opens its
		-- existing drawer. Creation never enters the Browse search pipeline.
		return GF.NavTree and GF.NavTree:SetSelected(node) == true or false
	end
	local browse = GF.FindGroupTab
	if browse and browse.CanStartSelectionSearch then
		local allowed, reason = browse:CanStartSelectionSearch(node, { source = "raidBannerClick" })
		if allowed ~= true then
			if browse.NotifySelectionSearchBlocked then browse:NotifySelectionSearchBlocked(reason) end
			return false
		end
	end
	if not (GF.NavTree and GF.NavTree:SetSelected(node)) then return false end
	if browse and browse.DoSearch then browse:DoSearch({ source = "raidBannerClick" }) end
	return true
end

-- These rows are presentation choices. Their keys always resolve back to
-- canonical season nodes before selection; the catalog is not mutated.
function Panel:GetFlyoutChoices(scopeKey)
	local root = seasonRoot()
	local scope = root and GF.NavData.FindNodeByKey(scopeKey)
	if not scope or scope == root or scope.navKind ~= "season_raid"
		or not scope.journalInstanceID then return {} end
	local choices, createMode = {}, self:IsCreateMode()
	local function add(node, label)
		choices[#choices + 1] = {
			key = node.key, label = label, level = (scope.level or 0) + 1,
			isLeaf = true, navKind = "season_raid",
			disabled = not canSelect(node, createMode), disabledTooltip = true,
			disabledReason = unavailableReason(node),
			_gfNavSelectionProvider = Panel, _gfNavSelectionScopeKey = scopeKey,
			_gfNavSelectionTabID = currentTabID(),
			-- Aggregate commands must not inherit the banner/open-branch highlight.
			_gfNavSuppressSelection = node.isLeaf ~= true,
		}
	end
	if not createMode then
		add(scope, string.format(text("RAID_BROWSE_INSTANCE_ALL_FORMAT"), scope.label))
	end
	for _, node in ipairs(scope.children or {}) do
		if node.navKind == "season_raid" and (not createMode or node.isLeaf == true) then
			add(node, node.label)
		end
	end
	return choices
end

function Panel:SelectFlyoutChoice(choice)
	if not choice or choice._gfNavSelectionProvider ~= self
		or choice._gfNavSelectionTabID ~= currentTabID()
		or not self.menuOwner or not GF.NavFlyout:RowIsAnchor(self.menuOwner)
		or choice._gfNavSelectionScopeKey ~= self.menuOwner.nodeData.key
	then return false end
	-- A live menu can outlast a directory update. Rebuild its membership and
	-- permissions rather than trusting a captured target or disabled flag.
	for _, current in ipairs(self:GetFlyoutChoices(choice._gfNavSelectionScopeKey)) do
		if current.key == choice.key and not current.disabled then
			return self:Select(current.key)
		end
	end
	return false
end

function Panel:OpenDifficultyFlyout(owner, key)
	local main = GF.MainFrame
	if not self.frame or not self.frame:IsShown() or not main
		or not self:ShouldUse(main:GetCurrentTabID(), main:GetCurrentWorkspaceID())
	then return false end
	seasonRoot()
	local node = GF.NavData.FindNodeByKey(key)
	if not node or node.navKind ~= "season_raid" or not GF.NavFlyout
		or not GF.NavTree or #self:GetFlyoutChoices(key) == 0
	then return false end
	if GF.NavTree.IsInteractionEnabled and not GF.NavTree:IsInteractionEnabled() then
		return false
	end
	if not GF.NavFlyout:CanRenderOpenFrom(owner, (node.level or 0) + 1) then
		return false
	end
	local createMode = self:IsCreateMode()
	-- Card clicks use the same foreground/alpha owner as the main window shell.
	if createMode and main.ActivateFocus then main:ActivateFocus() end
	-- Browse keeps its selection/results when reopening the same raid. Create
	-- only opens the menu; a concrete difficulty must be chosen before changing
	-- the form or opening its drawer.
	if not createMode and not self:IsSelected(key) then
		if not GF.NavTree:SetSelected(node) then return false end
		if GF.FindGroupTab and GF.FindGroupTab.ResetBrowsePage then
			GF.FindGroupTab:ResetBrowsePage()
		end
	end
	self.menuOwner = owner
	owner.nodeData = node
	owner._gfNavStandaloneAnchor = true
	owner._gfNavSelectionProvider = self
	GameTooltip_Hide()
	GF.NavFlyout:HideAll()
	return GF.NavFlyout:OpenFrom(owner, node)
end

local function closeAnchoredFlyout(button)
	if GF.NavFlyout and GF.NavFlyout:RowIsAnchor(button) then
		GF.NavFlyout:HideAll()
	end
end

local function renderRow(row, entry)
	if not row.banner then
		row.banner = UI.ShopCardBanner:Create(row)
		row.banner:SetPoint("TOPLEFT")
		row.banner:SetPoint("BOTTOMRIGHT", 0, STYLE.gap)
		row.banner:SetScript("OnClick", function(button, mouseButton)
			if Panel:IsCreateMode() then
				Panel:OpenDifficultyFlyout(button, button.entry.key)
			elseif mouseButton == "RightButton" or button.entry.key == "season_raid" then
				Panel:Select(button.entry.key)
			else
				Panel:OpenDifficultyFlyout(button, button.entry.key)
			end
		end)
		row.banner:HookScript("OnHide", closeAnchoredFlyout)
	end
	if row.banner.entry and row.banner.entry.key ~= entry.key then
		closeAnchoredFlyout(row.banner)
	end
	row.banner.entry = entry
	UI.ShopCardBanner:SetData(row.banner, entry, Panel:IsSelected(entry.key))
end

function Panel:CreateHeader(host)
	self.header = CreateFrame("Frame", nil, host)
	self.header:SetPoint("TOPLEFT", host, "TOPLEFT", 0, GF.BROWSE_HEADER_TOP_OFFSET)
	self.header:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, GF.BROWSE_HEADER_TOP_OFFSET)
	self.header:SetHeight(GF.SUBTITLE_HEADER_H)
	self.header:SetFrameLevel(host:GetFrameLevel() + 4)
	UI.InstallBrowseHeaderChrome(self.header, { backgroundInsetLeft = 0 })
	self.headerTitle = UI.CreateFontString(self.header, "OVERLAY", "GameFontNormal")
	self.headerTitle:SetPoint("TOPLEFT", 0, GF.BROWSE_HEADER_TEXT_CENTER_OFFSET_Y)
	self.headerTitle:SetPoint("BOTTOMRIGHT", 0, GF.BROWSE_HEADER_TEXT_CENTER_OFFSET_Y)
	self.headerTitle:SetJustifyH("CENTER")
	self.headerTitle:SetJustifyV("MIDDLE")
	self.headerTitle._gfFontSizeOverride = GF.BROWSE_HEADER_TEXT_SIZE
	self.headerTitle._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(self.headerTitle, "GameFontNormal")
	end
	self.headerTitle:SetTextColor(unpack(GF.BROWSE_HEADER_TEXT_COLOR))
	self.header:Hide()
end

local function configurePlayerModelCamera(model)
	if not model:IsVisible() then
		model._cameraDirty = true
		model:SetPaused(true)
		return
	end
	local style = STYLE.playerModel
	model:SetCamera(0)
	model:SetPortraitZoom(style.portraitZoom)
	model:SetPosition(0, 0, style.positionZ)
	model:SetFacing(style.facing)
	model:SetAnimation(0)
	model:RefreshCamera()
	model._cameraDirty = nil
end

local function refreshPlayerModel(model)
	-- One visible frame coalesces equipment/appearance event bursts. There is
	-- no recurring Lua update, and normal result/layout refreshes never SetUnit.
	model:SetScript("OnUpdate", nil)
	if not model:IsVisible() then return end
	model._appearanceDirty = nil
	local ok, success = pcall(model.SetUnit, model, "player", false, true)
	if not ok or not success then
		model:ClearModel()
		model:SetAlpha(0)
		model._appearanceDirty = true
		return
	end
	configurePlayerModelCamera(model)
	model:SetAlpha(STYLE.playerModel.alpha)
	model:SetPaused(false)
end

local function queuePlayerModelRefresh(model)
	model._appearanceDirty = true
	if model:IsVisible() then model:SetScript("OnUpdate", refreshPlayerModel) end
end

function Panel:EnsurePlayerModel()
	if self.playerModelHost then return self.playerModelHost end
	local host = CreateFrame("Frame", nil, self.frame)
	host:Hide()
	host:SetClipsChildren(true)
	host:EnableMouse(false)
	local model = CreateFrame("PlayerModel", nil, host)
	model:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
	model:EnableMouse(false)
	model:SetKeepModelOnHide(true)
	model:SetPaused(true)
	model:SetAlpha(0)
	model._appearanceDirty = true
	model:SetScript("OnShow", function(frame)
		if frame._appearanceDirty then
			queuePlayerModelRefresh(frame)
		else
			if frame._cameraDirty then configurePlayerModelCamera(frame) end
			frame:SetPaused(false)
		end
	end)
	model:SetScript("OnHide", function(frame)
		frame:SetScript("OnUpdate", nil)
		frame:SetPaused(true)
	end)
	model:SetScript("OnModelLoaded", configurePlayerModelCamera)
	model:SetScript("OnSizeChanged", configurePlayerModelCamera)
	model:SetScript("OnEvent", queuePlayerModelRefresh)
	-- Hidden events only invalidate the retained appearance; GPU/model work
	-- waits until the sidebar is visible again. No unit payload is inspected.
	model:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
	model:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	model:RegisterEvent("TRANSMOGRIFY_SUCCESS")
	model:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.playerModelHost, self.playerModel = host, model
	return host
end

function Panel:LayoutPlayerModel()
	local raidCount = self._raidCount or 0
	local style = STYLE.playerModel
	local rightInset = math.max(0, GF.NAV_DIVIDER_W / 2 - GF.NAV_DIVIDER_OFFSET_X)
	local width = self.frame:GetWidth() - rightInset
	-- Reserve Browse's extra "all raids" row in both tabs. A shared camera
	-- still changes apparent scale if Create gets a taller native canvas.
	local height = self.frame:GetHeight() + GF.BROWSE_HEADER_TOP_OFFSET
		- GF.SUBTITLE_HEADER_H - STYLE.topGap
		- (raidCount + 1) * (STYLE.height + STYLE.gap) - style.gap - style.bottomInset
	-- Never cover cards or a loading/unavailable hint. Models are only created
	-- when the user actually opens a sidebar with enough free space.
	if not self.frame:IsVisible() or raidCount == 0
		or width < style.minWidth or height < style.minHeight
	then
		if self.playerModelHost then self.playerModelHost:Hide() end
		return
	end
	local host = self:EnsurePlayerModel()
	host:SetSize(width, height)
	host:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, style.bottomInset)
	-- Use the full space between the sidebar borders, with the same top edge
	-- below Browse's cards in both tabs. A top-aligned canvas crops only at the
	-- bottom rim; the camera leaves extra room above the head and weapons.
	local overflow = math.min(width * style.bottomOverflowRatio, style.maxBottomOverflow)
	self.playerModel:SetSize(width, height + overflow)
	host:Show()
end

function Panel:Init(host)
	if self.frame or not host then return end
	if UI.VirtualList.IsAvailable and not UI.VirtualList.IsAvailable() then return end
	self.frame = CreateFrame("Frame", "GroupFinderAddonRaidBrowsePanel", host)
	self.frame:SetAllPoints(host)
	self.frame:SetFrameLevel(host:GetFrameLevel() + 3)
	self.frame:Hide()
	self:CreateHeader(host)
	self.list = UI.VirtualList.Create(self.frame, {
		rowHeight = STYLE.height + STYLE.gap, assignedKey = "key",
		showScrollBar = false, elementInitializer = renderRow,
	})
	self.list:SetPoint("TOPLEFT", STYLE.inset,
		GF.BROWSE_HEADER_TOP_OFFSET - GF.SUBTITLE_HEADER_H - STYLE.topGap)
	self.list:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -STYLE.inset, STYLE.inset)
	self.empty = UI.CreateFontString(self.frame, "OVERLAY", "GameFontDisable")
	self.empty:SetPoint("TOPLEFT", STYLE.inset, -STYLE.emptyTop)
	self.empty:SetPoint("TOPRIGHT", -STYLE.inset, -STYLE.emptyTop)
	self.empty:SetWordWrap(true)
	self.frame:HookScript("OnSizeChanged", function() Panel:LayoutPlayerModel() end)
	self.frame:HookScript("OnShow", function() Panel:Refresh() end)
end

function Panel:Refresh()
	if not self.frame or not self.frame:IsShown() then return end
	self.headerTitle:SetText(text("WORKSPACE_RAID"))
	local entries = self:GetEntries()
	local root = seasonRoot()
	local placeholder = root and root.children and root.children[1]
	self.empty:SetText(placeholder and placeholder.disabledReason or text("NAV_LOADING"))
	self.empty:SetShown(#entries == 0 or (not self:IsCreateMode() and #entries == 1))
	self.list:SetElements(entries, { retainIdentity = true })
	self._raidCount = math.max(0, #entries - (self:IsCreateMode() and 0 or 1))
	self:LayoutPlayerModel()
end

function Panel:SetSelection(selection)
	self.selection = selection
	if not self.frame or not self.frame:IsShown() or not self.list then return end
	-- Selection only changes visible state. Replacing the ScrollBox provider
	-- would recycle the clicked anchor and interrupt its image transition.
	self.list:ForEachFrame(function(row)
		local button = row.banner
		if button and button.entry then
			button.selected = self:IsSelected(button.entry.key)
			UI.ShopCardBanner:Refresh(button)
		end
	end)
end

function Panel:SetVisible(visible)
	if not self.frame then return end
	if not visible or self._tabID ~= currentTabID() then self.menuOwner = nil end
	self._tabID = currentTabID()
	self.frame:SetShown(visible == true)
	self.header:SetShown(visible == true)
	if visible then self:Refresh() end
end

function Panel:RefreshLocale()
	self:Refresh()
end
