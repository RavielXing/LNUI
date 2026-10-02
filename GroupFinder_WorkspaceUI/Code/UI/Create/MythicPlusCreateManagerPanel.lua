local _, GF = ...
GF = GF.GF or GF

GF.MythicPlusCreateManagerPanel = GF.MythicPlusCreateManagerPanel or {}
local Panel = GF.MythicPlusCreateManagerPanel
local SPACING = GF.MPLUS_LFG_SIDEBAR_SPACING
local NativeCreation = assert(
	GF.NativeCreationGateway,
	"NativeCreationGateway must load before MythicPlusCreateManagerPanel"
)

local SURFACE_MYTHIC_PLUS = "mythic_plus"
local SURFACE_MEETING_STONE_READ_ONLY = "meeting_stone_read_only"

local PANEL_INSET_X = 8
local PANEL_CONTENT_W = (GF.NAV_WIDTH or 180) - (PANEL_INSET_X * 2)
local SIDEBAR_CONTROL_W =
	GF.MPLUS_LFG_SIDEBAR_CONTROL_W or PANEL_CONTENT_W
local SIDEBAR_CONTROL_OFFSET_X = math.floor(
	(PANEL_CONTENT_W - SIDEBAR_CONTROL_W) / 2
)
local CONTENT_OFFSET_X = -1
local HEADER_TOP_OFFSET = GF.BROWSE_HEADER_TOP_OFFSET or -20
local HEADER_H = GF.SUBTITLE_HEADER_H or 26
local TITLE_TEXT_SIZE = GF.CREATE_MANAGER_TITLE_TEXT_SIZE
	or GF.BROWSE_HEADER_TEXT_SIZE
	or 14
local TITLE_TEXT_COLOR = GF.CREATE_MANAGER_TITLE_TEXT_COLOR
	or GF.BROWSE_HEADER_TEXT_COLOR
	or { 1, 0.82, 0, 1 }
local DISABLED_VISUAL = GF.CREATE_MANAGER_DISABLED_VISUAL or {}
local DISABLED_TITLE_TEXT_COLOR =
	DISABLED_VISUAL.labelTextColor
	or { 0.72, 0.70, 0.64, 1 }
local HEADER_TEXT_OFFSET_Y = GF.BROWSE_HEADER_TEXT_CENTER_OFFSET_Y or 4
local CONTENT_TOP_GAP = 5
local SECTION_TITLE_H = GF.MPLUS_LFG_SIDEBAR_SECTION_TITLE_H or 16
local TITLE_CONTROL_GAP =
	GF.MPLUS_LFG_SIDEBAR_TITLE_CONTROL_GAP or 4
local BLOCK_GAP = GF.MPLUS_LFG_SIDEBAR_BLOCK_GAP or 10
local FORM_TOP_INSET = GF.MPLUS_LFG_SIDEBAR_FORM_TOP_INSET or 8
local FORM_HOST_TOP_GAP = math.max(0, BLOCK_GAP - FORM_TOP_INSET)
local CONTROL_H = 26
local DUNGEON_BLOCK_H = SECTION_TITLE_H + TITLE_CONTROL_GAP + CONTROL_H
local BUTTON_H = GF.PANEL_BUTTON_H or 24
local BUTTON_W = GF.PANEL_BUTTON_TWO_CHAR_W or 72
local BUTTON_GAP = GF.SUBTITLE_CONTROL_GAP or 7
local ACTION_STYLE = GF.MPLUS_LFG_SIDEBAR_ACTION_STYLE
local BUTTON_BOTTOM = 10
local FORM_HOST_OUTSET_LEFT = 16
local FORM_HOST_OUTSET_RIGHT = 7
local ACTIVITY_SELECTOR_COPY = {
	[SURFACE_MYTHIC_PLUS] = {
		key = "MPLUS_BROWSE_FILTER_DUNGEONS",
		fallback = "选择赛季地下城",
	},
	[SURFACE_MEETING_STONE_READ_ONLY] = {
		key = "CREATE_MANAGER_MODE_LABEL",
		fallback = "选择招募模式",
	},
}

local function localized(key, fallback)
	local value = GF.L and GF.L[key]
	if type(value) ~= "string" or value == "" then
		return fallback
	end
	return value
end

local function applyFontSize(fontString, template, size)
	if not fontString then
		return
	end
	fontString._gfFontSizeOverride = size
	fontString._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(
			fontString,
			template or "GameFontNormal"
		)
	end
end

local function fitFontToWidth(fontString, width, minimumSize)
	if fontString and GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(fontString, width, minimumSize)
	end
end

local function useNativeDropdownTextTruncation(dropdown)
	local text = dropdown and dropdown.Text
	if not text then
		return
	end
	-- Keep the configured dropdown font size. WowStyle1DropdownTemplate already
	-- owns a bounded, single-line text region and renders overlong text with an
	-- ellipsis; its mixin also exposes the full text in a native hover tooltip.
	text._gfFitWidth = nil
	text._gfFitMinSize = nil
	text._gfFittedFontSize = nil
	if text.SetWordWrap then
		text:SetWordWrap(false)
	end
	if text.SetNonSpaceWrap then
		text:SetNonSpaceWrap(false)
	end
	if text.SetMaxLines then
		text:SetMaxLines(1)
	end
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(
			text,
			text._gfFontTemplate or "GameFontHighlightSmall"
		)
	end
end

local function applyTextColor(fontString, color)
	if not (fontString and color) then
		return
	end
	fontString:SetTextColor(
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		color[4] or 1
	)
end

local function applyNormalHeaderVisual(panel)
	if not panel then
		return
	end
	-- “组队管理”标题条始终保持集合石普通态，不跟随正文门控。
	applyTextColor(panel.headerTitle, TITLE_TEXT_COLOR)
	local header = panel.header
	if header and header.SetAlpha then
		header:SetAlpha(1)
	end
	local backgroundFrame = header
		and header._gfBrowseHeaderBackgroundFrame
	if backgroundFrame and backgroundFrame.SetAlpha then
		backgroundFrame:SetAlpha(1)
	end
	local background = header and header._gfBrowseHeaderBackground
	if background then
		if background.SetDesaturated then
			background:SetDesaturated(false)
		end
		if background.SetAlpha then
			background:SetAlpha(1)
		end
	end
end

local function captureFrameLayout(frame)
	if not frame then
		return nil
	end
	local points = {}
	for index = 1, frame:GetNumPoints() do
		points[index] = { frame:GetPoint(index) }
	end
	return {
		parent = frame:GetParent(),
		frameLevel = frame:GetFrameLevel(),
		frameStrata = frame:GetFrameStrata(),
		width = frame:GetWidth(),
		height = frame:GetHeight(),
		shown = frame:IsShown(),
		points = points,
	}
end

local function captureFrameLayer(frame)
	if not frame then
		return nil
	end
	return {
		frameLevel = frame:GetFrameLevel(),
		frameStrata = frame:GetFrameStrata(),
	}
end

local function restoreFrameLayer(frame, state)
	if not frame or not state then
		return
	end
	if state.frameStrata then
		frame:SetFrameStrata(state.frameStrata)
	end
	if state.frameLevel then
		frame:SetFrameLevel(state.frameLevel)
	end
end

local function restoreFrameLayout(frame, state)
	if not frame or not state then
		return
	end
	frame:SetParent(state.parent)
	if state.frameStrata then
		frame:SetFrameStrata(state.frameStrata)
	end
	if state.frameLevel then
		frame:SetFrameLevel(state.frameLevel)
	end
	if state.width and state.height then
		frame:SetSize(state.width, state.height)
	end
	frame:ClearAllPoints()
	for _, point in ipairs(state.points or {}) do
		frame:SetPoint(unpack(point))
	end
	frame:SetShown(state.shown == true)
end

local function safeActivityInfo(activityID)
	activityID = tonumber(activityID)
	if activityID == nil then
		return nil
	end
	local ok, info = pcall(
		NativeCreation.GetActivityInfoTable,
		NativeCreation,
		activityID
	)
	return ok and type(info) == "table" and info or nil
end

local function nonEmptyText(value)
	return type(value) == "string" and value ~= "" and value or nil
end

local function getReadOnlyActivityLabel(activityID)
	local info = safeActivityInfo(activityID)
	if not info then
		return nil
	end
	return nonEmptyText(info.fullName) or nonEmptyText(info.shortName)
end

local function resolveCreateActivityID(node)
	if GF.NavData and GF.NavData.ResolveCreateActivityID then
		return GF.NavData.ResolveCreateActivityID(node)
	end
	return node and tonumber(node.activityID) or nil
end

local function optionContainsActivity(option, activityID)
	activityID = tonumber(activityID)
	if not activityID or type(option) ~= "table" then
		return false
	end
	if tonumber(option.activityID) == activityID then
		return true
	end
	for _, candidate in ipairs(option.activityIDs or {}) do
		if tonumber(candidate) == activityID then
			return true
		end
	end
	return false
end

local function optionLabel(option, index)
	if type(option) ~= "table" then
		return tostring(option or index)
	end
	return option.label
		or option.name
		or option.shortName
		or (option.source and (option.source.label or option.source.name))
		or string.format(
			localized(
				"MPLUS_BROWSE_FILTER_DUNGEON_FALLBACK_FMT",
				"地下城 %d"
			),
			index
		)
end

function Panel:GetSurfaceMode(tabID, workspaceID)
	local mainFrame = GF.MainFrame
	local presentation = GF.RecruitmentSession
		and GF.RecruitmentSession.GetActiveCensoredPresentationState
		and GF.RecruitmentSession:GetActiveCensoredPresentationState()
	workspaceID = workspaceID
		or mainFrame and mainFrame.GetCurrentWorkspaceID
			and mainFrame:GetCurrentWorkspaceID()
	tabID = tabID
		or mainFrame and mainFrame.GetCurrentTabID
			and mainFrame:GetCurrentTabID()
	if tabID ~= GF.TAB_CREATE then
		return nil
	end
	if workspaceID == GF.WORKSPACE_MYTHIC_PLUS then
		return SURFACE_MYTHIC_PLUS
	end
	if presentation and presentation.preview == true then
		return nil
	end
	if (workspaceID == GF.WORKSPACE_MEETING_STONE or workspaceID == GF.WORKSPACE_RAID)
		and GF.RecruitmentSession
		and GF.RecruitmentSession.HasActive
		and GF.RecruitmentSession:HasActive()
		and not self:CanPublish()
	then
		return SURFACE_MEETING_STONE_READ_ONLY
	end
	return nil
end

function Panel:ShouldUse(tabID, workspaceID)
	return self:GetSurfaceMode(tabID, workspaceID) ~= nil
end

function Panel:IsMeetingStoneReadOnlyMode()
	return self:GetSurfaceMode() == SURFACE_MEETING_STONE_READ_ONLY
end

function Panel:GetActivitySelectorTitle()
	local copy = ACTIVITY_SELECTOR_COPY[self:GetSurfaceMode()]
		or ACTIVITY_SELECTOR_COPY[SURFACE_MYTHIC_PLUS]
	return localized(copy.key, copy.fallback)
end

function Panel:IsSurfaceActive()
	if self._passiveWarmupMounted == true then
		return false
	end
	return self.mounted == true
		and self.frame
		and self.frame:IsVisible()
		and self:ShouldUse()
		or false
end

function Panel:IsMythicPlusSurface()
	return self:GetSurfaceMode() == SURFACE_MYTHIC_PLUS
end

function Panel:IsPresentationReady()
	if not self:IsSurfaceActive() then
		return false
	end
	local drawer = GF.CreateDrawer
	local createPanel = GF.CreatePanel
	if not (drawer and drawer.panelHost and drawer.footer and createPanel
		and createPanel.parent == drawer.panelHost
		and drawer.panelHost:GetParent() == self.frame
		and drawer.footer:GetParent() == self.frame
		and createPanel:IsPresentationReady({ requireActiveFields = true }))
	then
		return false
	end
	if self._createChannelOccupiedPresentation == true then
		return true
	end
	return self.dungeonBlock:IsVisible()
		and drawer.footer:IsVisible()
		and createPanel:_PresentationFrameReady(drawer.footer, true)
		and createPanel:_PresentationFrameVisible(createPanel.scroll)
		and createPanel:_PresentationFrameVisible(createPanel.listBtn)
		and createPanel:_PresentationFrameVisible(createPanel.removeBtn)
end

function Panel:IsCensoredDebugPreview()
	local presentation = GF.RecruitmentSession
		and GF.RecruitmentSession.GetActiveCensoredPresentationState
		and GF.RecruitmentSession:GetActiveCensoredPresentationState()
	return presentation ~= nil and presentation.preview == true
end

function Panel:IsCensoredDebugResolution()
	return self:IsCensoredDebugPreview()
		and self._censoredDebugResolutionRequested == true
end

function Panel:SetCreateChannelOccupiedPresentation(occupied)
	occupied = occupied == true and self:IsMythicPlusSurface()
	if self._createChannelOccupiedPresentation == occupied then
		return false
	end
	self._createChannelOccupiedPresentation = occupied
	self:LayoutMountedHosts()
	return true
end

function Panel:GetDungeonOptions()
	if self:IsMeetingStoneReadOnlyMode() then
		return {}
	end
	local scope = GF.MythicPlusLFGScope
	if not (scope and scope.GetDungeons) then
		return {}
	end
	local ok, dungeons = pcall(scope.GetDungeons, scope)
	if not ok or type(dungeons) ~= "table" then
		return {}
	end
	return dungeons
end

function Panel:CanPublish()
	return not GF.RecruitmentSession
		or not GF.RecruitmentSession.CanPublish
		or GF.RecruitmentSession:CanPublish()
end

function Panel:GetSelectedActivityID()
	if GF.RecruitmentSession and GF.RecruitmentSession.HasActive and GF.RecruitmentSession:HasActive()
		and GF.RecruitmentSession.GetActiveActivityID
	then
		return GF.RecruitmentSession:GetActiveActivityID()
	end
	return resolveCreateActivityID(GF.CreatePanel and GF.CreatePanel.selection)
end

function Panel:GetDungeonDropdownText()
	local activityID = self:GetSelectedActivityID()
	if activityID then
		local hasActive = GF.RecruitmentSession
			and GF.RecruitmentSession.HasActive
			and GF.RecruitmentSession:HasActive()
		if hasActive then
			-- An active entry locks this selector in both workspaces. Resolve its
			-- display name from the activity API before any navigation projection.
			return getReadOnlyActivityLabel(activityID)
				or self:GetActivitySelectorTitle()
		end
		for index, option in ipairs(self:GetDungeonOptions()) do
			if optionContainsActivity(option, activityID) then
				return optionLabel(option, index)
			end
		end
		local selection = GF.CreatePanel and GF.CreatePanel.selection
		if selection then
			local label = selection.label
			if type(label) == "string" and label ~= "" then
				return label
			end
		end
		local info = safeActivityInfo(activityID)
		if info then
			local label = nonEmptyText(info.shortName)
				or nonEmptyText(info.fullName)
			if label then
				return label
			end
		end
	end
	if self:IsMeetingStoneReadOnlyMode() then
		return self:GetActivitySelectorTitle()
	end
	if #self:GetDungeonOptions() == 0 then
		return localized(
			"MPLUS_BROWSE_FILTER_NO_DUNGEONS",
			"暂无赛季地下城"
		)
	end
	return localized(
		"MPLUS_BROWSE_FILTER_DUNGEONS",
		"选择赛季地下城"
	)
end

function Panel:SelectDungeonActivity(activityID, opts)
	opts = opts or {}
	if GF.RecruitmentSession and GF.RecruitmentSession.HasActive and GF.RecruitmentSession:HasActive() then
		return false
	end
	if opts.force ~= true and not self:CanPublish() then
		return false
	end
	local node = activityID
		and GF.NavData
		and GF.NavData.FindSeasonDungeonNodeByActivityID
		and GF.NavData.FindSeasonDungeonNodeByActivityID(activityID)
	if not node then
		return false
	end
	if GF.MainFrame and GF.MainFrame.OnSelectionChanged then
		GF.MainFrame:OnSelectionChanged(node, {
			suppressCreateDrawer = true,
			mythicPlusCreateManager = true,
		})
	elseif GF.CreatePanel and GF.CreatePanel.SetSelection then
		GF.CreatePanel:SetSelection(node)
	end
	self:Refresh()
	return true
end

function Panel:EnsureCanonicalDungeonSelection()
	if self._ensuringDungeonSelection then
		return false
	end
	if GF.RecruitmentSession and GF.RecruitmentSession.IsRelisting
		and GF.RecruitmentSession:IsRelisting()
	then
		return false
	end
	if GF.RecruitmentSession and GF.RecruitmentSession.HasActive and GF.RecruitmentSession:HasActive() then
		return false
	end

	local options = self:GetDungeonOptions()
	if #options == 0 then
		return false
	end

	-- MainFrame is updated before the sidebar and CreatePanel during a user
	-- selection. Prefer it so a still-mounted form cannot overwrite a fresh
	-- dungeon click with its previous activity.
	local currentSelection = GF.MainFrame and GF.MainFrame.selection
		or self.selection
		or GF.CreatePanel and GF.CreatePanel.selection
	local currentActivityID = resolveCreateActivityID(currentSelection)

	local firstActivityID
	local currentCanonicalActivityID
	for _, option in ipairs(options) do
		firstActivityID = firstActivityID or tonumber(option.activityID)
		if optionContainsActivity(option, currentActivityID) then
			currentCanonicalActivityID = tonumber(option.activityID)
		end
	end
	local targetActivityID
	if currentCanonicalActivityID then
		if currentCanonicalActivityID ~= tonumber(currentActivityID) then
			targetActivityID = currentCanonicalActivityID
		end
	else
		targetActivityID = firstActivityID
	end
	if not targetActivityID then
		return false
	end

	self._ensuringDungeonSelection = true
	local changed = self:SelectDungeonActivity(
		targetActivityID,
		{ force = true }
	)
	self._ensuringDungeonSelection = nil
	return changed == true
end

function Panel:SetupDungeonMenu()
	if not self.dungeonDropdown or not self.dungeonDropdown.SetupMenu then
		return
	end
	if self.dungeonDropdown.SetSelectionText then
		self.dungeonDropdown:SetSelectionText(function()
			return Panel:GetDungeonDropdownText()
		end)
	end
	self.dungeonDropdown:SetupMenu(function(_, root)
		local meetingStoneReadOnly =
			Panel:IsMeetingStoneReadOnlyMode()
		if root.SetTag then
			root:SetTag(
				meetingStoneReadOnly
					and "MENU_GF_MEETING_STONE_CREATE_MODE"
					or "MENU_GF_MYTHIC_PLUS_CREATE_DUNGEON"
			)
		end
		if root.CreateTitle then
			root:CreateTitle(Panel:GetActivitySelectorTitle())
		end
		if meetingStoneReadOnly then
			return
		end
		local options = Panel:GetDungeonOptions()
		if #options == 0 then
			if root.CreateTitle then
				root:CreateTitle(localized(
					"MPLUS_BROWSE_FILTER_NO_DUNGEONS",
					"暂无赛季地下城"
				))
			end
			return
		end
		for index, option in ipairs(options) do
			local activityID = tonumber(option.activityID)
			if activityID then
				root:CreateRadio(
					optionLabel(option, index),
					function(candidate)
						return tonumber(Panel:GetSelectedActivityID())
							== tonumber(candidate)
					end,
					function(candidate)
						Panel:SelectDungeonActivity(candidate)
					end,
					activityID
				)
			end
		end
	end)
end

function Panel:CreateHeader(host)
	self.header = CreateFrame("Frame", nil, host)
	self.header:SetPoint(
		"TOPLEFT",
		host,
		"TOPLEFT",
		0,
		HEADER_TOP_OFFSET
	)
	self.header:SetPoint(
		"TOPRIGHT",
		host,
		"TOPRIGHT",
		0,
		HEADER_TOP_OFFSET
	)
	self.header:SetHeight(HEADER_H)
	self.header:SetFrameLevel(host:GetFrameLevel() + 4)
	if GF.UI.InstallBrowseHeaderChrome then
		GF.UI.InstallBrowseHeaderChrome(self.header, {
			backgroundInsetLeft = 0,
		})
	end

	self.headerTitle = GF.UI.CreateFontString(
		self.header,
		"OVERLAY",
		"GameFontNormal"
	)
	self.headerTitle:SetPoint(
		"TOPLEFT",
		self.header,
		"TOPLEFT",
		0,
		HEADER_TEXT_OFFSET_Y
	)
	self.headerTitle:SetPoint(
		"BOTTOMRIGHT",
		self.header,
		"BOTTOMRIGHT",
		0,
		HEADER_TEXT_OFFSET_Y
	)
	self.headerTitle:SetJustifyH("CENTER")
	self.headerTitle:SetJustifyV("MIDDLE")
	applyTextColor(self.headerTitle, TITLE_TEXT_COLOR)
	applyFontSize(
		self.headerTitle,
		"GameFontNormal",
		TITLE_TEXT_SIZE
	)
	applyNormalHeaderVisual(self)
	self.header:Hide()
end

function Panel:CreateDungeonBlock(parent)
	local block = CreateFrame("Frame", nil, parent)
	block:SetSize(PANEL_CONTENT_W, DUNGEON_BLOCK_H)
	local titleInset = GF.MPLUS_LFG_SIDEBAR_SECTION_TITLE_INSET_X or 2

	self.dungeonTitle = GF.UI.CreateFontString(
		block,
		"OVERLAY",
		"GameFontNormal"
	)
	self.dungeonTitle:SetPoint("TOPLEFT", block, "TOPLEFT", titleInset, 0)
	self.dungeonTitle:SetPoint("TOPRIGHT", block, "TOPRIGHT", -titleInset, 0)
	self.dungeonTitle:SetHeight(SECTION_TITLE_H)
	self.dungeonTitle:SetJustifyH("LEFT")
	self.dungeonTitle:SetJustifyV("MIDDLE")
	self.dungeonTitle:SetMaxLines(1)
	self.dungeonTitle:SetWordWrap(false)
	applyTextColor(self.dungeonTitle, TITLE_TEXT_COLOR)
	applyFontSize(
		self.dungeonTitle,
		"GameFontNormal",
		TITLE_TEXT_SIZE
	)

	self.dungeonDropdownHost = CreateFrame("Frame", nil, block)
	self.dungeonDropdownHost:SetPoint(
		"BOTTOMLEFT",
		block,
		"BOTTOMLEFT",
		SIDEBAR_CONTROL_OFFSET_X,
		0
	)
	self.dungeonDropdownHost:SetSize(SIDEBAR_CONTROL_W, CONTROL_H)

	self.dungeonDropdown = GF.UI.CreateDropdownButton(
		self.dungeonDropdownHost
	)
	self.dungeonDropdown:SetAllPoints(self.dungeonDropdownHost)
	self:SetupDungeonMenu()
	return block
end

function Panel:Init(host)
	if self.frame or not host then
		return
	end
	self.host = host
	self.frame = CreateFrame(
		"Frame",
		"GroupFinderAddonMythicPlusCreateManagerPanel",
		host
	)
	self.frame:SetAllPoints(host)
	self.frame:SetFrameLevel(host:GetFrameLevel() + 3)
	self.frame:Hide()
	self:CreateHeader(host)
	self.dungeonBlock = self:CreateDungeonBlock(self.frame)
	self.frame:SetScript("OnSizeChanged", function()
		Panel:Layout()
	end)
	self:Layout()
	self:RefreshLocale()
end

function Panel:Layout()
	if not (self.frame and self.dungeonBlock) then
		return
	end
	local contentTopGap = self:IsMythicPlusSurface() and SPACING.contentTopGap or CONTENT_TOP_GAP
	local contentTop = -(
		HEADER_TOP_OFFSET
			- HEADER_H
			- contentTopGap
	)
	self.dungeonBlock:ClearAllPoints()
	self.dungeonBlock:SetPoint(
		"TOPLEFT",
		self.frame,
		"TOPLEFT",
		PANEL_INSET_X + CONTENT_OFFSET_X,
		-contentTop
	)
	self.dungeonBlock:SetSize(PANEL_CONTENT_W, DUNGEON_BLOCK_H)
	if self.dungeonDropdownHost then
		local width = self:IsMythicPlusSurface()
			and GF.MPLUS_LFG_SIDEBAR_NATIVE_CONTROL_W or SIDEBAR_CONTROL_W
		self.dungeonDropdownHost:ClearAllPoints()
		self.dungeonDropdownHost:SetPoint("BOTTOMLEFT", self.dungeonBlock, "BOTTOMLEFT",
			math.floor((PANEL_CONTENT_W - width) / 2), 0)
		self.dungeonDropdownHost:SetSize(width, CONTROL_H)
	end
	self:LayoutMountedHosts()
end

function Panel:SyncMountedFrameLevels()
	if not self.mounted or not self.frame then
		return
	end
	local baseLevel = self.frame:GetFrameLevel()
	local drawer = GF.CreateDrawer
	local panelHost = drawer and drawer.panelHost
	local footer = drawer and drawer.footer
	if panelHost then
		panelHost:SetFrameLevel(baseLevel + 2)
	end
	if GF.CreatePanel and GF.CreatePanel.scroll then
		GF.CreatePanel.scroll:SetFrameLevel(baseLevel + 3)
	end
	if GF.CreatePanel and GF.CreatePanel.SyncBlockedOverlayFrameLevel then
		GF.CreatePanel:SyncBlockedOverlayFrameLevel()
	end
	if footer then
		footer:SetFrameLevel(baseLevel + 6)
		if footer._gfBrowseControlBackgroundFrame then
			footer._gfBrowseControlBackgroundFrame:SetFrameLevel(
				baseLevel + 7
			)
		end
	end
	for _, button in ipairs({
		GF.CreatePanel and GF.CreatePanel.listBtn,
		GF.CreatePanel and GF.CreatePanel.removeBtn,
	}) do
		if button then
			button:SetFrameLevel(baseLevel + 8)
		end
	end
end

function Panel:LayoutMountedHosts()
	if not self.mounted then
		return
	end
	local drawer = GF.CreateDrawer
	local panelHost = drawer and drawer.panelHost
	local footer = drawer and drawer.footer
	if not (panelHost and footer and self.dungeonBlock) then
		return
	end
	local occupiedPresentation =
		self._createChannelOccupiedPresentation == true
			and self:IsMythicPlusSurface()
	local buttonW, buttonH, buttonGap = BUTTON_W, BUTTON_H, BUTTON_GAP
	local buttonBottom, formHostTopGap = BUTTON_BOTTOM, FORM_HOST_TOP_GAP
	local footerHeight = buttonBottom + buttonH
	if self:IsMythicPlusSurface() then
		buttonW, buttonH, buttonGap =
			ACTION_STYLE.buttonWidth, ACTION_STYLE.buttonHeight, ACTION_STYLE.gap
		buttonBottom = SPACING.contentBottomInset
		footerHeight = ACTION_STYLE.footerHeight
		-- The borrowed form scroll already contributes FORM_TOP_INSET.
		formHostTopGap = math.max(0, SPACING.sectionGap - FORM_TOP_INSET)
	end
	local buttonGroupOffsetX = PANEL_INSET_X + CONTENT_OFFSET_X
		+ math.floor((PANEL_CONTENT_W - (buttonW * 2 + buttonGap)) / 2)

	footer:ClearAllPoints()
	footer:SetPoint(
		"BOTTOMLEFT",
		self.frame,
		"BOTTOMLEFT",
		0,
		0
	)
	footer:SetPoint(
		"BOTTOMRIGHT",
		self.frame,
		"BOTTOMRIGHT",
		0,
		0
	)
	footer:SetHeight(footerHeight)
	footer:SetShown(not occupiedPresentation)
	self.dungeonBlock:SetShown(not occupiedPresentation)

	panelHost:ClearAllPoints()
	if occupiedPresentation then
		panelHost:SetPoint(
			"TOPLEFT",
			self.dungeonBlock,
			"TOPLEFT",
			-FORM_HOST_OUTSET_LEFT,
			0
		)
		panelHost:SetPoint(
			"BOTTOMRIGHT",
			self.frame,
			"BOTTOMRIGHT",
			FORM_HOST_OUTSET_RIGHT,
			0
		)
	else
		panelHost:SetPoint(
			"TOPLEFT",
			self.dungeonBlock,
			"BOTTOMLEFT",
			-FORM_HOST_OUTSET_LEFT,
			-formHostTopGap
		)
		panelHost:SetPoint(
			"BOTTOMRIGHT",
			footer,
			"TOPRIGHT",
			FORM_HOST_OUTSET_RIGHT,
			0
		)
	end

	if GF.CreatePanel and GF.CreatePanel.listBtn then
		GF.CreatePanel.listBtn:SetSize(buttonW, buttonH)
		GF.CreatePanel.listBtn:ClearAllPoints()
		GF.CreatePanel.listBtn:SetPoint(
			"BOTTOMLEFT",
			footer,
			"BOTTOMLEFT",
			buttonGroupOffsetX,
			buttonBottom
		)
	end
	if GF.CreatePanel and GF.CreatePanel.removeBtn
		and GF.CreatePanel.listBtn
	then
		GF.CreatePanel.removeBtn:SetSize(buttonW, buttonH)
		GF.CreatePanel.removeBtn:ClearAllPoints()
		GF.CreatePanel.removeBtn:SetPoint(
			"LEFT",
			GF.CreatePanel.listBtn,
			"RIGHT",
			buttonGap,
			0
		)
	end
	self:SyncMountedFrameLevels()
	if GF.CreatePanel and GF.CreatePanel.UpdateScrollLayout then
		GF.CreatePanel:UpdateScrollLayout()
	end
end

function Panel:Mount(opts)
	opts = opts or {}
	local drawer = GF.CreateDrawer
	local createPanel = GF.CreatePanel
	if not (
		drawer
		and drawer.panelHost
		and drawer.footer
		and createPanel
		and createPanel.scroll
	) then
		return false
	end
	if self.mounted then
		-- A cached mount is not proof that the shared hosts are still attached.
		if drawer.panelHost:GetParent() ~= self.frame then
			drawer.panelHost:SetParent(self.frame)
		end
		if drawer.footer:GetParent() ~= self.frame then
			drawer.footer:SetParent(self.frame)
		end
		drawer.panelHost:Show()
		self:LayoutMountedHosts()
		return true
	end
	if opts.passiveWarmup ~= true
		and drawer.IsOpen and drawer:IsOpen() and drawer.Close
	then
		drawer:Close(true)
	end

	self.savedLayouts = {
		panelHost = captureFrameLayout(drawer.panelHost),
		footer = captureFrameLayout(drawer.footer),
		listButton = captureFrameLayout(createPanel.listBtn),
		removeButton = captureFrameLayout(createPanel.removeBtn),
	}
	self.savedLayers = {
		scroll = captureFrameLayer(createPanel.scroll),
		footerBackground = captureFrameLayer(
			drawer.footer._gfBrowseControlBackgroundFrame
		),
	}
	self.mounted = true
	self._passiveWarmupMounted = opts.passiveWarmup == true
	drawer.panelHost:SetParent(self.frame)
	drawer.footer:SetParent(self.frame)
	if createPanel.SetMythicPlusSidebarMode then
		createPanel:SetMythicPlusSidebarMode(true)
	end
	drawer.panelHost:Show()
	drawer.footer:Show()
	self:LayoutMountedHosts()
	return true
end

function Panel:Unmount(opts)
	opts = opts or {}
	if not self.mounted then
		return
	end
	local drawer = GF.CreateDrawer
	local createPanel = GF.CreatePanel
	local passiveWarmup = opts.passiveWarmup == true
		or self._passiveWarmupMounted == true
	self._createChannelOccupiedPresentation = nil
	if self.dungeonBlock then
		self.dungeonBlock:Show()
	end
	if not passiveWarmup and createPanel and createPanel.ClearFocus then
		createPanel:ClearFocus()
	end
	if not passiveWarmup and createPanel and createPanel.Hide then
		createPanel:Hide("tab")
	end
	if createPanel
		and createPanel.ApplyCreateManagerDropdownDisabledVisual
	then
		createPanel:ApplyCreateManagerDropdownDisabledVisual(
			self.dungeonDropdown,
			false
		)
	end
	if drawer then
		restoreFrameLayout(
			drawer.panelHost,
			self.savedLayouts and self.savedLayouts.panelHost
		)
		restoreFrameLayout(
			drawer.footer,
			self.savedLayouts and self.savedLayouts.footer
		)
		restoreFrameLayout(
			createPanel and createPanel.listBtn,
			self.savedLayouts and self.savedLayouts.listButton
		)
		restoreFrameLayout(
			createPanel and createPanel.removeBtn,
			self.savedLayouts and self.savedLayouts.removeButton
		)
		restoreFrameLayer(
			createPanel and createPanel.scroll,
			self.savedLayers and self.savedLayers.scroll
		)
		restoreFrameLayer(
			drawer.footer._gfBrowseControlBackgroundFrame,
			self.savedLayers and self.savedLayers.footerBackground
		)
		if createPanel and createPanel.SyncBlockedOverlayFrameLevel then
			createPanel:SyncBlockedOverlayFrameLevel()
		end
	end
	if createPanel and createPanel.SetMythicPlusSidebarMode then
		createPanel:SetMythicPlusSidebarMode(false)
	end
	if createPanel and createPanel.UpdateRequirementLayout then
		createPanel:UpdateRequirementLayout()
	end
	if createPanel and createPanel.UpdateScrollLayout then
		createPanel:UpdateScrollLayout()
	end
	self.mounted = nil
	self._passiveWarmupMounted = nil
	self.mode = nil
	self._censoredDebugResolutionRequested = nil
	self.savedLayouts = nil
	self.savedLayers = nil
end

function Panel:BeginPassiveWarmup()
	if self.mounted == true and self._passiveWarmupMounted ~= true then
		return false
	end
	return self:Mount({ passiveWarmup = true }) == true
end

function Panel:EndPassiveWarmup()
	if self._passiveWarmupMounted ~= true then
		return false
	end
	self:Unmount({ passiveWarmup = true })
	return true
end

function Panel:Open(opts)
	opts = opts or {}
	if not self:ShouldUse() then
		return false
	end
	local mainController = GF.MainFrame
	local mainFrame = mainController and mainController.frame
	local userVisible = mainController and mainController.IsUserVisible
		and mainController:IsUserVisible()
		or (mainController and not mainController.IsUserVisible
			and mainFrame and mainFrame:IsShown())
	if not userVisible then
		return false
	end
	self:SetVisible(true)
	if not self:Mount() then
		return false
	end

	local createPanel = GF.CreatePanel
	if not createPanel then
		return false
	end
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.GetContext
		and createPanel.SetWorkspaceContext
	then
		self.workspaceContext = GF.LFGWorkspaceView:GetContext()
		createPanel:SetWorkspaceContext(self.workspaceContext)
	end
	local debugCensoredPreview = self:IsCensoredDebugPreview()
	local channelOccupied = not debugCensoredPreview
		and createPanel.IsCreateChannelAutoOpenBlocked
		and createPanel:IsCreateChannelAutoOpenBlocked()
	if not debugCensoredPreview
		and not channelOccupied
		and createPanel.ActivateCreateChannel
	then
		createPanel:ActivateCreateChannel()
	end

	local relisting = not debugCensoredPreview
		and GF.RecruitmentSession
		and GF.RecruitmentSession.IsRelisting
		and GF.RecruitmentSession:IsRelisting()
	if relisting then
		-- Preserve the edit form and Blizzard field lease across the temporary
		-- inactive event emitted by the synchronous bump transaction.
		createPanel:Show()
		self:Refresh()
		return true
	end

	local hasActive = not debugCensoredPreview
		and GF.RecruitmentSession
		and GF.RecruitmentSession.HasActive
		and GF.RecruitmentSession:HasActive()
	if debugCensoredPreview then
		self.mode = "debug-censored"
		if not createPanel.PrepareForCensoredDebugPreview
			or not createPanel:PrepareForCensoredDebugPreview({
				censoredResolution =
					self._censoredDebugResolutionRequested == true,
				resetText = opts.resetText == true,
			})
		then
			self:ClearCensoredDebugPreview()
			return false
		end
		-- Enter the local-field test mode before normalizing the dungeon so the
		-- selection callback cannot borrow Blizzard's EntryCreation fields.
		self:EnsureCanonicalDungeonSelection()
		createPanel:Show()
		self:Refresh()
		return true
	end
	if not hasActive then
		self:EnsureCanonicalDungeonSelection()
	end
	local targetMode = hasActive and "edit" or "create"
	local modeChanged = self.mode ~= targetMode
	self.mode = targetMode

	if hasActive then
		local activeActivityID = GF.RecruitmentSession.GetActiveActivityID
			and GF.RecruitmentSession:GetActiveActivityID()
		local currentActivityID = resolveCreateActivityID(
			createPanel.selection
		)
		if modeChanged
			or createPanel.editMode ~= true
			or tonumber(activeActivityID) ~= tonumber(currentActivityID)
			or opts.forceEdit == true
		then
			if channelOccupied and createPanel.PrepareForOccupiedEdit then
				createPanel:PrepareForOccupiedEdit()
			elseif createPanel.PrepareForEdit then
				local censorState = GF.RecruitmentSession
					and GF.RecruitmentSession.GetActiveCensoredState
					and GF.RecruitmentSession:GetActiveCensoredState()
				createPanel:PrepareForEdit({
					censoredReadOnly = censorState
						and censorState.state
						== GF.RecruitmentSession.ACTIVE_CENSOR_STATE_UNRESOLVED,
				})
			end
		end
	else
		if GF.MainFrame and GF.MainFrame.selection
			and createPanel.SetSelection
		then
			createPanel:SetSelection(GF.MainFrame.selection)
		end
		if createPanel.PrepareForCreate then
			createPanel:PrepareForCreate({
				-- Mounting a different projection of the shared form does not
				-- start a new draft.  Only an explicit caller may request one.
				resetDefaults = opts.resetDefaults == true,
			})
		end
	end

	createPanel:Show()
	if not hasActive and createPanel.MarkProtectedCreateDraftPresented then
		createPanel:MarkProtectedCreateDraftPresented()
	end
	self:Refresh()
	return true
end

function Panel:RefreshDungeonControlState()
	if not self.frame then
		return
	end
	local options = self:GetDungeonOptions()
	local hasActive = GF.RecruitmentSession
		and GF.RecruitmentSession.HasActive
		and GF.RecruitmentSession:HasActive()
	local debugCensoredPreview = self:IsCensoredDebugPreview()
	local relisting = GF.RecruitmentSession
		and GF.RecruitmentSession.IsRelisting
		and GF.RecruitmentSession:IsRelisting()
	local canLead = self:CanPublish()
	local channelOccupied = not debugCensoredPreview
		and GF.CreatePanel
		and GF.CreatePanel.IsCreateChannelAutoOpenBlocked
		and GF.CreatePanel:IsCreateChannelAutoOpenBlocked()
	self:SetCreateChannelOccupiedPresentation(channelOccupied)
	local createBlocked = not hasActive
		and GF.Availability
		and GF.Availability.GetPremadeBlockMessage
		and GF.Availability:GetPremadeBlockMessage()
	local enabled = not hasActive
		and not debugCensoredPreview
		and not relisting
		and not channelOccupied
		and canLead
		and not createBlocked
		and #options > 0
	local titleColor = enabled
		and TITLE_TEXT_COLOR
		or DISABLED_TITLE_TEXT_COLOR
	applyNormalHeaderVisual(self)
	applyTextColor(self.dungeonTitle, titleColor)

	if self.dungeonDropdown then
		if self.dungeonDropdown.SetEnabled then
			self.dungeonDropdown:SetEnabled(enabled)
		end
		if self.dungeonDropdown.SetDefaultText then
			self.dungeonDropdown:SetDefaultText(
				self:GetDungeonDropdownText()
			)
		end
		if self.dungeonDropdown.GenerateMenu then
			self.dungeonDropdown:GenerateMenu()
		end
		useNativeDropdownTextTruncation(self.dungeonDropdown)
		if GF.CreatePanel
			and GF.CreatePanel.ApplyCreateManagerDropdownDisabledVisual
		then
			GF.CreatePanel:ApplyCreateManagerDropdownDisabledVisual(
				self.dungeonDropdown,
				not enabled
			)
		end
	end
end

function Panel:BeginCensoredDebugResolution()
	if not self:IsCensoredDebugPreview() then
		return false
	end
	local mainFrame = GF.MainFrame
	if not (mainFrame and mainFrame.GetCurrentWorkspaceID
		and mainFrame:GetCurrentWorkspaceID() == GF.WORKSPACE_MYTHIC_PLUS)
	then
		return false
	end
	self._censoredDebugResolutionRequested = true
	if mainFrame.OpenCreateTab then
		mainFrame:OpenCreateTab()
	end
	return self:Open({ debugCensoredPreview = true }) == true
end

function Panel:ReturnToCensoredDebugReadOnly()
	if not self:IsCensoredDebugPreview() then
		return false
	end
	self._censoredDebugResolutionRequested = nil
	return self:Open({
		debugCensoredPreview = true,
		resetText = true,
	}) == true
end

function Panel:ClearCensoredDebugPreview()
	local changed = self._censoredDebugResolutionRequested ~= nil
		or (GF.CreatePanel
			and GF.CreatePanel.debugCensoredPreviewMode == true)
	self._censoredDebugResolutionRequested = nil
	if GF.CreatePanel and GF.CreatePanel.debugCensoredPreviewMode == true
		and GF.CreatePanel.ExitCensoredDebugPreview
	then
		GF.CreatePanel:ExitCensoredDebugPreview()
	end
	return changed == true
end

function Panel:Refresh()
	if self:IsSurfaceActive() then
		self:EnsureCanonicalDungeonSelection()
	end
	self:RefreshDungeonControlState()
	if GF.CreatePanel and GF.CreatePanel.UpdateManageState then
		GF.CreatePanel:UpdateManageState()
	end
end

function Panel:SetSelection(selection)
	self.selection = selection
	if self.frame and self.frame:IsShown() then
		self:Refresh()
	end
end

function Panel:RefreshLocale()
	if not self.frame then
		return
	end
	if self.headerTitle then
		self.headerTitle:SetText(localized(
			"MPLUS_CREATE_MANAGER_TITLE",
			"组队管理"
		))
	end
	if self.dungeonTitle then
		self.dungeonTitle:SetText(self:GetActivitySelectorTitle())
		fitFontToWidth(
			self.dungeonTitle,
			PANEL_CONTENT_W - 4,
			8
		)
	end
	self:SetupDungeonMenu()
	self:Refresh()
end

function Panel:SetVisible(visible)
	if not self.frame then
		return
	end
	if visible then
		self.frame:Show()
		if self.header then
			self.header:Show()
		end
		self:Layout()
		if self.dungeonTitle then
			self.dungeonTitle:SetText(self:GetActivitySelectorTitle())
			fitFontToWidth(
				self.dungeonTitle,
				PANEL_CONTENT_W - 4,
				8
			)
		end
		self:SetupDungeonMenu()
	else
		self:Unmount()
		self.frame:Hide()
		if self.header then
			self.header:Hide()
		end
	end
end

function Panel:IsShown()
	return self.frame and self.frame:IsShown() or false
end
