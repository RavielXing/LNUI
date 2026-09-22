local _, GF = ...

GF.WorkspaceBar = GF.WorkspaceBar or {}
local WB = GF.WorkspaceBar

local function workspaceRouter()
	local router = GF.WorkspaceRouter
	if not router then
		error("GroupFinder WorkspaceRouter must load before WorkspaceBar", 2)
	end
	return router
end

local WORKSPACE_ORDER = {
	GF.WORKSPACE_MEETING_STONE,
	GF.WORKSPACE_MYTHIC_PLUS,
	GF.WORKSPACE_RAID,
}

local function getWorkspaceLabel(workspaceID)
	local L = GF.L or {}
	if workspaceID == GF.WORKSPACE_MYTHIC_PLUS then
		return L.WORKSPACE_MYTHIC_PLUS or "Mythic+"
	end
	if workspaceID == GF.WORKSPACE_RAID then
		return L.WORKSPACE_RAID or "Seasonal Raids"
	end
	return L.WORKSPACE_MEETING_STONE or L.WORKSPACE_STANDARD or "Meeting Stone"
end

local function setTextureAtlas(texture, atlas)
	if texture and atlas then
		texture:SetAtlas(atlas, true)
		texture._gfWorkspaceTexCoords = { texture:GetTexCoord() }
		texture._gfWorkspaceWidth = texture:GetWidth()
		texture._gfWorkspaceHeight = texture:GetHeight()
	end
end

local function getTabPosition()
	return GF.GetWorkspaceTabPosition and GF.GetWorkspaceTabPosition()
		or GF.WORKSPACE_TAB_POSITION_DEFAULT or "right"
end

local function orientBorder(texture, position)
	local uv = texture._gfWorkspaceTexCoords
	local width, height = texture._gfWorkspaceWidth, texture._gfWorkspaceHeight
	if position == "bottom" then
		-- 顺时针 90 度：仅重排原 Atlas 四角，避免采到同图集其他区域。
		texture:SetSize(height, width)
		texture:SetTexCoord(uv[3], uv[4], uv[7], uv[8], uv[1], uv[2], uv[5], uv[6])
	elseif position == "left" then
		texture:SetSize(width, height)
		texture:SetTexCoord(uv[5], uv[6], uv[7], uv[8], uv[1], uv[2], uv[3], uv[4])
	else
		texture:SetSize(width, height)
		texture:SetTexCoord(uv[1], uv[2], uv[3], uv[4], uv[5], uv[6], uv[7], uv[8])
	end
end

local function setIconPoint(button, pressed)
	local icon = button and button.Icon
	if not icon then
		return
	end
	local x = GF.WORKSPACE_TAB_ICON_OFFSET_X or -3
	local y = GF.WORKSPACE_TAB_ICON_OFFSET_Y or 0
	if button._gfWorkspacePosition == "left" then
		x = -x
	elseif button._gfWorkspacePosition == "bottom" then
		x, y = y, -x
	end
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", button, "CENTER", x + (pressed and 1 or 0),
		y + (pressed and -1 or 0))
end

local function setIconColor(icon, color)
	color = color or { 1, 1, 1, 1 }
	icon:SetVertexColor(color[1] or 1, color[2] or 1,
		color[3] or 1, color[4] or 1)
end

local function applyWorkspaceTabState(button, state)
	if not button then
		return
	end
	button._gfWorkspaceState = state
	button.SelectedTexture:SetShown(state == "selected")
	if state == "disabled" then
		button:Disable()
	else
		button:Enable()
	end
	setIconPoint(button, false)
	if state == "selected" then
		button.Icon:SetDesaturated(false)
		setIconColor(button.Icon)
	elseif state == "disabled" then
		button.Icon:SetDesaturated(true)
		setIconColor(button.Icon, GF.WORKSPACE_TAB_DISABLED_ICON_COLOR)
	else
		button.Icon:SetDesaturated(true)
		setIconColor(button.Icon, GF.WORKSPACE_TAB_NORMAL_ICON_COLOR)
	end
	if GF.UI.RefreshVersionedNewFeatureBadgeAnchor then
		GF.UI.RefreshVersionedNewFeatureBadgeAnchor(button)
	end
end

local function showWorkspaceTooltip(button)
	local L = GF.L or {}
	GF.UI.BeginGameTooltip(button, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	local gap = GF.WORKSPACE_TAB_TOOLTIP_GAP or 4
	if button._gfWorkspacePosition == "left" then
		GameTooltip:SetPoint("RIGHT", button, "LEFT", -gap, 0)
	elseif button._gfWorkspacePosition == "bottom" then
		GameTooltip:SetPoint("TOP", button, "BOTTOM", 0, -gap)
	else
		GameTooltip:SetPoint("LEFT", button, "RIGHT", gap, 0)
	end
	GameTooltip:SetText(button.tooltipText or getWorkspaceLabel(button.workspaceID),
		1, 0.82, 0)

	GF.UI.ShowGameTooltip()
end

local function createWorkspaceButton(parent, index, workspaceID)
	local button = CreateFrame(
		"Button",
		("GroupFinderAddonWorkspaceTab%d"):format(index),
		parent
	)
	button:SetID(index)
	button.workspaceID = workspaceID
	button:SetSize(GF.WORKSPACE_TAB_WIDTH or 43,
		GF.WORKSPACE_TAB_HEIGHT or 55)
	button:RegisterForClicks("LeftButtonUp")
	button:SetMotionScriptsWhileDisabled(true)

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("CENTER")
	setTextureAtlas(background, GF.WORKSPACE_TAB_NORMAL_ATLAS or "common-sidetab")
	button.Background = background

	local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
	icon:SetSize(GF.WORKSPACE_TAB_ICON_SIZE or 24,
		GF.WORKSPACE_TAB_ICON_SIZE or 24)
	icon:SetTexture((GF.WORKSPACE_TAB_ICON_TEXTURES or {})[workspaceID])
	button.Icon = icon
	setIconPoint(button, false)

	local selectedTexture = button:CreateTexture(nil, "OVERLAY", nil, 1)
	selectedTexture:SetPoint("CENTER")
	setTextureAtlas(selectedTexture,
		GF.WORKSPACE_TAB_SELECTED_ATLAS or "common-sidetab-selected")
	selectedTexture:Hide()
	button.SelectedTexture = selectedTexture

	local highlightTexture = button:CreateTexture(nil, "HIGHLIGHT")
	highlightTexture:SetPoint("CENTER")
	setTextureAtlas(highlightTexture,
		GF.WORKSPACE_TAB_HOVER_ATLAS or "common-sidetab-hover")
	button:SetHighlightTexture(highlightTexture)
	button.HighlightTexture = highlightTexture

	-- 旧版本的“新功能”角标仍需要一个文字测量宿主；当前版本窗口已结束，
	-- 该透明文字只保留历史版本投影能力，实际标签文案由 Tooltip 呈现。
	local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", icon, "CENTER")
	text:SetSize(GF.WORKSPACE_TAB_ICON_SIZE or 24,
		GF.WORKSPACE_TAB_ICON_SIZE or 24)
	text:SetAlpha(0)
	text:SetText(getWorkspaceLabel(workspaceID))
	button.Text = text
	button.tooltipText = getWorkspaceLabel(workspaceID)

	if workspaceID == GF.WORKSPACE_RAID then
		-- A persistent beta marker, independent of the historical New windows.
		local badge = CreateFrame("Frame", nil, button, "NewFeatureLabelTemplate")
		badge:SetSize(1, 1)
		badge:SetScale(GF.WORKSPACE_TAB_BETA_BADGE_SCALE or 0.8)
		badge:SetFrameLevel(button:GetFrameLevel() + 8)
		badge:EnableMouse(false)
		-- Anchor by the label's center, with a small inset from the corner;
		-- ResizeLayout's Glow padding must not determine the text position.
		badge:SetPoint("CENTER", button, "TOPRIGHT",
			GF.WORKSPACE_TAB_BETA_BADGE_OFFSET_X or -6,
			GF.WORKSPACE_TAB_BETA_BADGE_OFFSET_Y or -4)
		badge.label = "BETA"
		badge.Label:SetTextToFit(badge.label)
		badge.BGLabel:SetTextToFit(badge.label)
		badge:Show()
		button.BetaBadge = badge
	end

	button:SetScript("OnMouseDown", function(tab, mouseButton)
		if mouseButton == "LeftButton" then
			setIconPoint(tab, true)
		end
	end)
	button:SetScript("OnMouseUp", function(tab)
		setIconPoint(tab, false)
	end)
	button:SetScript("OnLeave", function(tab)
		setIconPoint(tab, false)
		GameTooltip_Hide()
	end)
	button:SetScript("OnEnter", showWorkspaceTooltip)
	button:SetScript("OnClick", function(tab)
		if tab.workspaceID == WB:GetCurrent()
		then
			return
		end
		WB:Select(tab.workspaceID)
	end)
	return button
end

function WB:RelayoutTabs()
	if not self.frame or not self.buttons then
		return
	end
	local tabWidth = GF.WORKSPACE_TAB_WIDTH or 43
	local tabHeight = GF.WORKSPACE_TAB_HEIGHT or 55
	local gap = GF.WORKSPACE_TAB_GAP or 3
	local position = getTabPosition()
	local horizontal = position == "bottom"
	if horizontal then
		tabWidth, tabHeight = tabHeight, tabWidth
	end
	if horizontal then
		self.frame:SetSize(tabWidth * #WORKSPACE_ORDER + gap * (#WORKSPACE_ORDER - 1), tabHeight)
	else
		self.frame:SetSize(tabWidth, tabHeight * #WORKSPACE_ORDER + gap * (#WORKSPACE_ORDER - 1))
	end
	local previous
	for _, workspaceID in ipairs(WORKSPACE_ORDER) do
		local button = self.buttons[workspaceID]
		if button then
			button._gfWorkspacePosition = position
			button:ClearAllPoints()
			button:SetSize(tabWidth, tabHeight)
			if previous then
				if horizontal then
					button:SetPoint("TOPLEFT", previous, "TOPRIGHT", gap, 0)
				else
					button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -gap)
				end
			else
				button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
			end
			orientBorder(button.Background, position)
			orientBorder(button.SelectedTexture, position)
			orientBorder(button.HighlightTexture, position)
			previous = button
		end
	end
	self.tabWidth = tabWidth
	self:RefreshAnchor()
	self:RefreshStates()
end

function WB:AnchorToHost(host)
	local frame, mainFrame = self.frame, self.mainFrame
	if not (frame and mainFrame) then
		return false
	end
	self.rightAnchorHost = host or mainFrame
	local position = getTabPosition()
	host = position == "right" and self.rightAnchorHost or mainFrame
	self.anchorHost = host
	frame:ClearAllPoints()
	if position == "left" then
		frame:SetPoint("TOPRIGHT", mainFrame, "TOPLEFT", 0,
			GF.WORKSPACE_TAB_TOP_OFFSET or -64)
	elseif position == "bottom" then
		frame:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT",
			GF.WORKSPACE_TAB_BOTTOM_OFFSET_X or 24, 0)
	else
		frame:SetPoint("TOPLEFT", host, "TOPRIGHT", 0,
			GF.WORKSPACE_TAB_TOP_OFFSET or -64)
	end
	local hostLevel = host.GetFrameLevel and host:GetFrameLevel()
		or mainFrame:GetFrameLevel()
	frame:SetFrameLevel((hostLevel or 0) + 40)
	return true
end

function WB:RefreshAnchor()
	return self:AnchorToHost(self.rightAnchorHost or self.mainFrame)
end

function WB:Init(mainFrame, controller, opts)
	if self.frame then
		return
	end
	opts = opts or {}
	self.mainFrame = mainFrame
	self.controller = controller
	self.frame = CreateFrame("Frame", "GroupFinderAddonWorkspaceBar", mainFrame)
	local tabWidth = GF.WORKSPACE_TAB_WIDTH or 43
	self.frame:SetSize(tabWidth, 1)
	self:AnchorToHost(mainFrame)
	self.buttons = {}

	for index, workspaceID in ipairs(WORKSPACE_ORDER) do
		local button = createWorkspaceButton(self.frame, index, workspaceID)
		if workspaceID == GF.WORKSPACE_MYTHIC_PLUS
			and GF.UI.InstallVersionedNewFeatureBadge
		then
			GF.UI.InstallVersionedNewFeatureBadge(button, button.Text, {
				introducedInVersion = "2.1.6",
				hideAtVersion = "2.1.7",
			})
		end
		self.buttons[workspaceID] = button
	end

	local db = GF.GetDB and GF.GetDB()
	local initial = opts.workspaceID
		or (db and db.workspaceMode)
		or GF.WORKSPACE_DEFAULT
	initial = workspaceRouter():NormalizeWorkspaceID(initial)
	local router = workspaceRouter()
	router:Init({ workspaceID = initial })
	local current = router:GetWorkspaceID()
	if db and opts.workspaceID ~= nil then
		db.workspaceMode = current
	end
	self:RelayoutTabs()
end

function WB:RefreshStates()
	local current = self:GetCurrent()
	for workspaceID, button in pairs(self.buttons or {}) do
		local selected = workspaceID == current
		applyWorkspaceTabState(button, selected and "selected" or "normal")
	end
end

function WB:Select(workspaceID, opts)
	opts = opts or {}
	local router = workspaceRouter()
	local transition = opts._routerTransition
	if type(transition) ~= "table"
		or transition.workspaceID ~= router:NormalizeWorkspaceID(workspaceID)
	then
		local _, committed = router:SetWorkspace(workspaceID, {
			targetTabID = opts.targetTabID,
		})
		transition = committed
	end
	workspaceID = transition.workspaceID
	local previous = transition.previousWorkspaceID
	local db = GF.GetDB and GF.GetDB()
	if db then
		db.workspaceMode = workspaceID
	end
	self:RefreshStates()
	if previous ~= workspaceID and not opts.silent and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("tab")
	end
	if self.controller and self.controller.OnWorkspaceChanged then
		opts.targetTabID = transition.tabID
		opts._routerTransition = transition
		self.controller:OnWorkspaceChanged(workspaceID, previous, opts)
	end
	return true
end

function WB:GetCurrent()
	return workspaceRouter():GetWorkspaceID()
end

function WB:RefreshLocale()
	for workspaceID, button in pairs(self.buttons or {}) do
		local label = getWorkspaceLabel(workspaceID)
		button.tooltipText = label
		if button.Text then
			button.Text:SetText(label)
		end
	end
	self:RelayoutTabs()
end

function WB:RefreshFonts()
	self:RelayoutTabs()
end
