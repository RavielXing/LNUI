local _, GF = ...

GF.NavFlyout = {}
local NF = GF.NavFlyout

local PANEL_COUNT = 3
local SIG_SEP = "\31"

local function flyoutMinPanelWidth()
	return GF.NAV_FLYOUT_PANEL_MIN_W or 120
end

local function flyoutMaxPanelWidth()
	return math.max(GF.NAV_FLYOUT_PANEL_MAX_W or 260, flyoutMinPanelWidth())
end

local function flyoutPanelGap(panelIdx)
	if panelIdx == 1 then
		return GF.NAV_FLYOUT_ROOT_GAP or 0
	end
	return GF.NAV_FLYOUT_PANEL_GAP or 0
end

local function flyoutPanelAnchorGap(panelIdx)
	return flyoutPanelGap(panelIdx)
end

local function flyoutRootAnchorGapX()
	return GF.NAV_FLYOUT_ROOT_ANCHOR_GAP_X or 4
end

local function flyoutRootAnchorGapY()
	return GF.NAV_FLYOUT_ROOT_ANCHOR_GAP_Y or 2
end

local function flyoutStairStepY()
	return GF.NAV_FLYOUT_STAIR_STEP_Y or 0
end

local function flyoutRowHeight(level)
	local heights = GF.NAV_FLYOUT_ROW_H or GF.NAV_ROW_H
	return (heights and heights[level]) or GF.NAV_FLYOUT_ROW_H_DEFAULT or GF.NAV_ROW_H_DEFAULT or 30
end

local function flyoutContentInsets()
	return GF.NAV_FLYOUT_CONTENT_INSET_L or 8,
		GF.NAV_FLYOUT_CONTENT_INSET_R or 8,
		GF.NAV_FLYOUT_CONTENT_INSET_T or 8,
		GF.NAV_FLYOUT_CONTENT_INSET_B or 15
end

local function applyFlyoutPanelChrome(panel)
	if not panel then
		return
	end
	if not panel.menuBg then
		panel.menuBg = panel:CreateTexture(nil, "BACKGROUND", nil, -5)
	end
	local atlas = GF.NAV_FLYOUT_BG_ATLAS or "common-dropdown-bg"
	local success = false
	if panel.menuBg.SetAtlas then
		local callOK, atlasOK = pcall(panel.menuBg.SetAtlas, panel.menuBg, atlas)
		success = callOK and atlasOK ~= false
	end
	if not success then
		panel.menuBg:SetColorTexture(0, 0, 0, GF.NAV_FLYOUT_BG_ALPHA or 0.925)
	end
	panel.menuBg:ClearAllPoints()
	panel.menuBg:SetPoint("TOPLEFT", panel, "TOPLEFT", -(GF.NAV_FLYOUT_BG_EXTEND_X or 10), GF.NAV_FLYOUT_BG_EXTEND_TOP or 3)
	panel.menuBg:SetPoint(
		"BOTTOMRIGHT",
		panel,
		"BOTTOMRIGHT",
		GF.NAV_FLYOUT_BG_EXTEND_X or 10,
		-(GF.NAV_FLYOUT_BG_EXTEND_BOTTOM or 3)
	)
	panel.menuBg:SetAlpha(GF.NAV_FLYOUT_BG_ALPHA or 0.925)
	panel.menuBg:Show()
end

local function getFlyoutWindowBounds()
	local top = UIParent and UIParent.GetTop and UIParent:GetTop()
	local bottom = UIParent and UIParent.GetBottom and UIParent:GetBottom()
	if not top and UIParent and UIParent.GetHeight then
		top = UIParent:GetHeight()
	end
	top = top or (GetScreenHeight and GetScreenHeight()) or 768
	bottom = bottom or 0
	local mainFrame = GF.MainFrame
	local boundFrame = mainFrame and mainFrame.layoutHost
	boundFrame = (boundFrame and boundFrame._gfPanelBackground) or boundFrame or (mainFrame and mainFrame.frame)
	if boundFrame then
		local frameTop = boundFrame.GetTop and boundFrame:GetTop()
		local frameBottom = boundFrame.GetBottom and boundFrame:GetBottom()
		if frameTop then
			top = math.min(top, frameTop)
		end
		if frameBottom then
			bottom = math.max(bottom, frameBottom + (GF.NAV_FLYOUT_WINDOW_BOTTOM_GAP or 0))
		end
	end
	return top - (GF.NAV_FLYOUT_SCREEN_MARGIN_TOP or 12), bottom
end

local function setFlyoutPanelVisibleHeight(panel, height, resetScroll)
	if not panel then
		return
	end
	local naturalH = math.max(panel._fullHeight or height or 1, 1)
	local visibleH = math.min(math.max(height or naturalH, 1), naturalH)
	panel._visibleHeight = visibleH
	panel:SetHeight(visibleH)
	if not panel.scroll then
		return
	end
	if resetScroll then
		panel.scroll:SetVerticalScroll(0)
	end
	GF.UI.UpdateScrollFrame(panel.scroll)
	local range = panel.scroll.GetVerticalScrollRange and (panel.scroll:GetVerticalScrollRange() or 0) or 0
	if range <= 0 then
		panel.scroll:SetVerticalScroll(0)
	else
		local current = panel.scroll:GetVerticalScroll() or 0
		if current > range then
			panel.scroll:SetVerticalScroll(range)
		end
	end
end

local function resolvePanelHeightAndTop(panel, desiredTop)
	local naturalH = math.max(panel and panel._fullHeight or 1, 1)
	local windowTop, windowBottom = getFlyoutWindowBounds()
	desiredTop = math.min(desiredTop or windowTop, windowTop)
	local availableH = math.max(desiredTop - windowBottom, 1)
	local visibleH = math.min(naturalH, availableH)
	return visibleH, desiredTop
end

local function frameHasBounds(frame)
	return frame and frame.GetLeft and frame:GetLeft() and frame.GetRight and frame:GetRight()
		and frame.GetTop and frame:GetTop() and frame.GetBottom and frame:GetBottom()
end

local function frameIsUsable(frame)
	if not frameHasBounds(frame) then
		return false
	end
	if frame.IsVisible then
		return frame:IsVisible()
	end
	if frame.IsShown then
		return frame:IsShown()
	end
	return true
end

local function getVisibleHeaderFrame(frame)
	if not frameIsUsable(frame) then
		return nil
	end
	local background = frame._gfBrowseHeaderBackgroundFrame
	if frameHasBounds(background) then
		return background
	end
	return frame
end

local function getRootFlyoutHeaderFrame()
	local tabID = GF.MainFrame and GF.MainFrame.GetCurrentTabID and GF.MainFrame:GetCurrentTabID()
	local browseHeader = GF.SubtitleBar and getVisibleHeaderFrame(GF.SubtitleBar.columnHeaderHost)
	local applicantHeader = GF.ApplicantsPanel and getVisibleHeaderFrame(GF.ApplicantsPanel.columnHeaderHost)
	if tabID == GF.TAB_CREATE then
		return applicantHeader or browseHeader
	end
	return browseHeader or applicantHeader
end

local function resolveRootFlyoutAnchor(navTree)
	local header = getRootFlyoutHeaderFrame()
	local divider = navTree and navTree.dividerHost
	if not (frameHasBounds(header) and frameHasBounds(divider)) then
		return nil
	end
	local dividerRight = divider:GetRight()
	local headerLeft = header:GetLeft()
	local headerBottom = header:GetBottom()
	if not (dividerRight and headerLeft and headerBottom) then
		return nil
	end
	local baseLeft = dividerRight + flyoutRootAnchorGapX()
	local baseTop = headerBottom - flyoutRootAnchorGapY()
	return {
		frame = header,
		baseLeft = baseLeft,
		baseTop = baseTop,
		offsetX = baseLeft - headerLeft,
		offsetY = -flyoutRootAnchorGapY(),
	}
end

local function nodeCanExpand(n)
	return GF.NavTree and GF.NavTree.NodeCanExpand and GF.NavTree.NodeCanExpand(n)
end

local function panelIndexForNode(node)
	local level = node and node.level or 0
	if level >= PANEL_COUNT then
		return nil
	end
	return level + 1
end

local function panelLayoutSig(navTree, children, contentW)
	local sel = navTree and navTree.selectedKey or ""
	local n = #children
	local sig = sel .. SIG_SEP .. contentW .. SIG_SEP .. n
	for i = 1, n do
		local child = children[i]
		sig = sig .. SIG_SEP .. (child and child.key or "")
	end
	return sig
end

local function nodeVisibleForCurrentTab(node)
	if not node then
		return false
	end
	local mainFrame = GF.MainFrame
	local currentTab = mainFrame and mainFrame.GetCurrentTabID and mainFrame:GetCurrentTabID()
	if currentTab == GF.TAB_CREATE and node.browseOnly then
		return false
	end
	return true
end

local function filterChildrenForCurrentTab(children)
	if not children then
		return {}
	end
	local filtered
	for i = 1, #children do
		local child = children[i]
		if nodeVisibleForCurrentTab(child) then
			if filtered then
				filtered[#filtered + 1] = child
			end
		elseif not filtered then
			filtered = {}
			for j = 1, i - 1 do
				filtered[#filtered + 1] = children[j]
			end
		end
	end
	return filtered or children
end

local function measureLabelWidth(panel, text)
	if not panel then
		return 0
	end
	if not panel.measureLabel then
		panel.measureLabel = GF.UI.CreateFontString(panel, "BACKGROUND", "GameFontNormal")
		panel.measureLabel:Hide()
	end
	GF.Font.ApplyToFontString(panel.measureLabel, "GameFontNormal")
	panel.measureLabel:SetText(text or "")
	return panel.measureLabel:GetStringWidth() or 0
end

local function resolvePanelWidth(panel, children)
	local insetL, insetR = flyoutContentInsets()
	local maxLabelW = 0
	local hasExpandable = false
	for i = 1, #(children or {}) do
		local n = children[i]
		maxLabelW = math.max(maxLabelW, measureLabelWidth(panel, n and n.label))
		if nodeCanExpand(n) then
			hasExpandable = true
		end
	end
	local rowExtra = (GF.NAV_FLYOUT_ROW_TEXT_L or 12)
		+ (GF.NAV_FLYOUT_ROW_TEXT_R or 10)
		+ (GF.NAV_FLYOUT_LABEL_EXTRA_W or 8)
	if hasExpandable then
		rowExtra = rowExtra + (GF.NAV_FLYOUT_ARROW_RESERVE_W or 28)
	end
	local desired = insetL + insetR + maxLabelW + rowExtra
	return math.min(math.max(desired, flyoutMinPanelWidth()), flyoutMaxPanelWidth())
end

local function ensureFlyoutRowParts(row, prefix, drawLayer, subLevel)
	if not row then
		return nil
	end
	if row.hover then
		row.hover:Hide()
	end
	local partsKey = prefix .. "Parts"
	if not row[partsKey] then
		if GF.UI and GF.UI.CreateRowBackgroundPieces then
			row[partsKey] = GF.UI.CreateRowBackgroundPieces(row, drawLayer or "BORDER", subLevel or 2)
		else
			row[partsKey] = {
				left = row:CreateTexture(nil, drawLayer or "BORDER", nil, subLevel or 2),
				middle = row:CreateTexture(nil, drawLayer or "BORDER", nil, subLevel or 2),
				right = row:CreateTexture(nil, drawLayer or "BORDER", nil, subLevel or 2),
			}
		end
		for _, tex in pairs(row[partsKey]) do
			if tex.SetBlendMode then
				tex:SetBlendMode("BLEND")
			end
			tex:Hide()
		end
	end
	return row[partsKey]
end

local function setFlyoutRowPartsShown(row, prefix, shown)
	local parts = row and row[prefix .. "Parts"]
	if not parts then
		return
	end
	shown = shown == true
	for _, tex in pairs(parts) do
		tex:SetShown(shown)
	end
end

local function getFlyoutHighlightAtlasInfo()
	local atlas = GF.NAV_FLYOUT_HIGHLIGHT_ATLAS or GF.ROW_BACKGROUND_ATLAS or "UI-QuestTracker-Secondary-Objective-Header"
	if C_Texture and C_Texture.GetAtlasInfo then
		local info = C_Texture.GetAtlasInfo(atlas)
		if info
			and type(info.leftTexCoord) == "number"
			and type(info.rightTexCoord) == "number"
			and type(info.topTexCoord) == "number"
			and type(info.bottomTexCoord) == "number" then
			return atlas, info
		end
	end
	return atlas, nil
end

local function applyFlyoutHighlightPiece(tex, atlas, info, u1, u2)
	if not tex then
		return
	end
	if tex.SetBlendMode then
		tex:SetBlendMode("BLEND")
	end
	if tex.SetDesaturated then
		tex:SetDesaturated(false)
	end
	tex:SetAlpha(1)
	tex:SetVertexColor(1, 1, 1, 1)
	if info then
		local file = info.file or info.filename
		if file then
			local left = info.leftTexCoord or 0
			local right = info.rightTexCoord or 1
			local top = info.topTexCoord or 0
			local bottom = info.bottomTexCoord or 1
			local atlasW = right - left
			tex:SetTexture(file)
			tex:SetTexCoord(left + (atlasW * u1), left + (atlasW * u2), top, bottom)
			return
		end
	end
	if tex.SetAtlas and pcall(tex.SetAtlas, tex, atlas, false) then
		tex:SetTexCoord(u1, u2, 0, 1)
		return
	end
	tex:SetTexture(GF.WHITE_TEXTURE)
	tex:SetTexCoord(0, 1, 0, 1)
end

local function layoutFlyoutRowParts(row, prefix, width, height, offsetX, offsetY, drawLayer, subLevel)
	local parts = ensureFlyoutRowParts(row, prefix, drawLayer, subLevel)
	if not parts then
		return
	end
	width = math.max(width or 1, 1)
	height = math.max(height or 1, 1)
	offsetX = offsetX or 0
	offsetY = offsetY or 0
	local displayH = math.max(1, math.min(height, GF.NAV_FLYOUT_HIGHLIGHT_DISPLAY_H or height))
	local sourceW = GF.ROW_BACKGROUND_SOURCE_WIDTH or 564
	local sourceH = GF.ROW_BACKGROUND_SOURCE_HEIGHT or 52
	local sourceCapW = GF.ROW_BACKGROUND_SOURCE_CAP_WIDTH or 18
	local capUV = math.max(0.001, math.min(0.45, sourceCapW / sourceW))
	local capW = math.max(1, math.min(width * 0.5, math.floor((sourceCapW * displayH / sourceH) + 0.5)))
	local left = parts.left
	local mid = parts.middle
	local right = parts.right
	local atlas, atlasInfo = getFlyoutHighlightAtlasInfo()
	applyFlyoutHighlightPiece(left, atlas, atlasInfo, 0, capUV)
	applyFlyoutHighlightPiece(mid, atlas, atlasInfo, capUV, 1 - capUV)
	applyFlyoutHighlightPiece(right, atlas, atlasInfo, 1 - capUV, 1)

	left:ClearAllPoints()
	left:SetPoint("LEFT", row, "LEFT", offsetX, offsetY)
	left:SetSize(capW, displayH)

	right:ClearAllPoints()
	right:SetPoint("RIGHT", row, "LEFT", offsetX + width, offsetY)
	right:SetSize(capW, displayH)

	mid:ClearAllPoints()
	mid:SetPoint("LEFT", left, "RIGHT", 0, 0)
	mid:SetPoint("RIGHT", right, "LEFT", 0, 0)
	mid:SetHeight(displayH)
end

local function setFlyoutHoverShown(row, shown)
	if row and row._flyoutSelected then
		shown = false
	end
	setFlyoutRowPartsShown(row, "flyoutHover", shown)
end

local function setFlyoutSelectedShown(row, shown)
	setFlyoutRowPartsShown(row, "flyoutSelected", shown)
end

local function layoutFlyoutHover(row, width, height, offsetX, offsetY)
	layoutFlyoutRowParts(row, "flyoutHover", width, height, offsetX, offsetY, "BORDER", 2)
end

local function layoutFlyoutSelected(row, width, height, offsetX, offsetY)
	layoutFlyoutRowParts(row, "flyoutSelected", width, height, offsetX, offsetY, "BORDER", 3)
end

function NF:RowIsAnchor(row)
	if not row or not self.panels then
		return false
	end
	for _, panel in ipairs(self.panels) do
		if panel._anchorRow == row then
			return true
		end
	end
	return false
end

local function rowIsDescendantOf(row, frame)
	if not row or not frame then
		return false
	end
	local p = row:GetParent()
	while p do
		if p == frame then
			return true
		end
		p = p:GetParent()
	end
	return false
end

function NF:BeginPanelLayout(panel)
	if not panel then
		return
	end
	panel:Hide()
	panel:ClearAllPoints()
	panel._positioned = nil
end

function NF:HideFromLevel(level)
	if not self.panels then
		return
	end
	if self.openKeys then
		for nodeLevel = math.max(0, (level or 1) - 1), PANEL_COUNT do
			self.openKeys[nodeLevel] = nil
		end
	end
	for i = PANEL_COUNT, level, -1 do
		local panel = self.panels[i]
		if panel then
			panel:Hide()
			panel._openKey = nil
			panel._anchorRow = nil
			panel._layoutSig = nil
			panel._positioned = nil
			self:ReleasePanelRows(panel)
		end
	end
end

function NF:HideAll()
	self.openKeys = nil
	self:HideFromLevel(1)
end

function NF:IsNodeOpen(node)
	if not node or not self.openKeys then
		return false
	end
	return self.openKeys[node.level or 0] == node.key
end

function NF:CloseChildPanelsForRow(row)
	local n = row and row.nodeData
	if not n then
		return
	end
	local panelIdx = panelIndexForNode(n)
	if panelIdx then
		self:HideFromLevel(panelIdx)
	end
	if self.RefreshVisibleRows then
		self:RefreshVisibleRows()
	end
end

local function layoutFlyoutRow(row, n, navTree, width, h)
	row.bg:Hide()
	row.cover:Hide()
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", row, "LEFT", GF.NAV_FLYOUT_ROW_TEXT_L or 12, 0)
	local hasArrow = GF.NavTree and GF.NavTree.ApplyExpandArrow and GF.NavTree.ApplyExpandArrow(row, n)
	if hasArrow then
		row.arrow:ClearAllPoints()
		row.arrow:SetPoint("RIGHT", row, "RIGHT", -(GF.NAV_FLYOUT_ARROW_R or 8), 0)
		row.label:SetPoint("RIGHT", row.arrow, "LEFT", -4, 0)
	else
		row.label:SetPoint("RIGHT", row, "RIGHT", -(GF.NAV_FLYOUT_ROW_TEXT_R or 10), 0)
	end
	row.label:SetText(n.label or "")
	row.label:SetJustifyH("LEFT")
	row.label:SetJustifyV("MIDDLE")
	row.label:SetWordWrap(false)
	row.label:SetShown(true)
	GF.Font.ApplyToFontString(row.label, "GameFontNormal")
	if n.historyClear then
		row.label:SetTextColor(0.75, 0.75, 0.75)
	else
		row.label:SetTextColor(1, 1, 1)
	end
	local isSel = (navTree and navTree.selectedKey == n.key) or (GF.NavFlyout and GF.NavFlyout:IsNodeOpen(n))
	local hlX = GF.NAV_FLYOUT_HIGHLIGHT_INSET_X or 6
	local hlTop = GF.NAV_FLYOUT_HIGHLIGHT_INSET_TOP or 3
	local hlBottom = GF.NAV_FLYOUT_HIGHLIGHT_INSET_BOTTOM or 1
	local textureExtendX = GF.NAV_FLYOUT_ROW_TEXTURE_EXTEND_X or 0
	local hlW = width - (hlX * 2) + (textureExtendX * 2)
	local hlH = h - hlTop - hlBottom
	local hlOffsetX = hlX - textureExtendX
	local hlY = (hlBottom - hlTop) / 2
	row._flyoutSelected = isSel
	layoutFlyoutHover(row, hlW, hlH, hlOffsetX, hlY)
	layoutFlyoutSelected(row, hlW, hlH, hlOffsetX, hlY)
	setFlyoutSelectedShown(row, isSel)
	if row.sel then
		row.sel:Hide()
	end
	setFlyoutHoverShown(row, false)
	row.hit:SetFrameLevel(row:GetFrameLevel() + 2)
	row._gfNavLevel = n.level or 1
end

function NF:RefreshVisibleRows()
	if not self.panels then
		return
	end
	for _, panel in ipairs(self.panels) do
		for _, row in ipairs(panel.rows or {}) do
			if row and row:IsShown() and row.nodeData then
				layoutFlyoutRow(row, row.nodeData, self.navTree, row:GetWidth(), row:GetHeight())
			end
		end
	end
end

function NF:LayoutPanelRows(panel, children, navTree)
	local insetL, insetR, insetT, insetB = flyoutContentInsets()
	local panelW = resolvePanelWidth(panel, children or {})
	panel:SetWidth(panelW)
	panel.panelW = panelW
	local contentW = math.max(panelW - insetL - insetR, 80)
	children = children or {}
	local sig = panelLayoutSig(navTree, children, contentW)
	if panel._layoutSig == sig then
		return
	end
	panel._layoutSig = sig
	self:BeginPanelLayout(panel)

	local needed = #children
	local estH = 0
	for i = 1, needed do
		local n = children[i]
		local level = n.level or 1
		estH = estH + flyoutRowHeight(level)
	end
	panel.content:SetSize(contentW, math.max(estH, 1))

	local y = 0
	for i = 1, needed do
		local n = children[i]
		local row = panel.rows[i]
		if row and row._gfFlyoutPanel and row._gfFlyoutPanel ~= panel then
			row = nil
			panel.rows[i] = nil
		end
		if not row then
			row = self:AcquireRow(panel.content, panel)
			panel.rows[i] = row
		elseif row:GetParent() ~= panel.content then
			row:ClearAllPoints()
			row:SetParent(panel.content)
		end
		local level = n.level or 1
		local h = flyoutRowHeight(level)
		row:SetHeight(h)
		row:SetWidth(contentW)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -y)
		row.nodeData = n
		row:Show()
		layoutFlyoutRow(row, n, navTree, contentW, h)
		y = y + h
	end
	self:ReleasePanelRows(panel, needed + 1)
	panel.content:SetSize(contentW, math.max(y, 1))
	local totalH = y + insetT + insetB
	panel._fullHeight = totalH
	setFlyoutPanelVisibleHeight(panel, totalH, true)
end

function NF:PositionPanel(panel, anchorRow, panelIdx)
	if panel._anchorRow == anchorRow and panel._positioned then
		return
	end
	panel:ClearAllPoints()
	local gap = flyoutPanelAnchorGap(panelIdx)
	local parentPanel
	if panelIdx and panelIdx > 1 then
		parentPanel = self.panels and self.panels[panelIdx - 1]
	end
	local desiredTop
	local rootAnchor
	if panelIdx == 1 then
		rootAnchor = resolveRootFlyoutAnchor(self.navTree)
		if rootAnchor then
			desiredTop = rootAnchor.baseTop
		end
	end
	if not desiredTop and panelIdx and panelIdx > 1 and self.panels and self.panels[1] then
		local rootPanel = self.panels[1]
		desiredTop = rootPanel.GetTop and rootPanel:GetTop()
		if desiredTop then
			desiredTop = desiredTop - (flyoutStairStepY() * (panelIdx - 1))
		end
	end
	if not desiredTop then
		desiredTop = anchorRow and anchorRow.GetTop and anchorRow:GetTop()
	end
	local visibleH, resolvedTop = resolvePanelHeightAndTop(panel, desiredTop)
	setFlyoutPanelVisibleHeight(panel, visibleH, false)
	if panelIdx and panelIdx > 1 then
		if parentPanel then
			local parentTop = parentPanel.GetTop and parentPanel:GetTop()
			if parentTop and resolvedTop then
				panel:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", gap, resolvedTop - parentTop)
			else
				panel:SetPoint("TOP", anchorRow, "TOP", 0, 0)
				panel:SetPoint("LEFT", parentPanel, "RIGHT", gap, 0)
			end
			panel._positioned = true
			return
		end
	end
	if rootAnchor then
		panel:SetPoint("TOPLEFT", rootAnchor.frame, "BOTTOMLEFT", rootAnchor.offsetX, rootAnchor.offsetY + (resolvedTop - rootAnchor.baseTop))
		panel._positioned = true
		return
	end
	local anchorRight = anchorRow and anchorRow.GetRight and anchorRow:GetRight()
	if anchorRight and resolvedTop and UIParent then
		panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", anchorRight + gap, resolvedTop)
	else
		panel:SetPoint("TOPLEFT", anchorRow, "TOPRIGHT", gap, 0)
	end
	panel._positioned = true
end

function NF:PrepareNode(node, navTree)
	if not node or not navTree then
		return
	end
	if navTree.PrepareBranch then
		navTree:PrepareBranch(node)
	end
end

function NF:OpenFrom(anchorRow, node)
	if not anchorRow or not node or node.disabled then
		return
	end
	if not nodeCanExpand(node) then
		return
	end
	local panelIdx = panelIndexForNode(node)
	if not panelIdx then
		return
	end
	local navTree = self.navTree
	self:PrepareNode(node, navTree)
	local children = filterChildrenForCurrentTab(node.children)
	if #children == 0 then
		return
	end
	local panel = self.panels and self.panels[panelIdx]
	if not panel then
		return
	end
	if rowIsDescendantOf(anchorRow, panel) then
		return
	end
	self:HideFromLevel(panelIdx + 1)
	self.openKeys = self.openKeys or {}
	self.openKeys[node.level or 0] = node.key
	panel._openKey = node.key
	self:BeginPanelLayout(panel)
	self:LayoutPanelRows(panel, children, navTree)
	panel._anchorRow = anchorRow
	self:PositionPanel(panel, anchorRow, panelIdx)
	panel:Show()
	self:RefreshVisibleRows()
end

function NF:OpenFromHover(row)
	local n = row and row.nodeData
	if not n or n.disabled then
		return false
	end
	if self.navTree and self.navTree.IsInteractionEnabled and not self.navTree:IsInteractionEnabled() then
		return false
	end
	if not nodeCanExpand(n) then
		self:CloseChildPanelsForRow(row)
		return false
	end
	if self:IsNodeOpen(n) then
		return true
	end
	self:OpenFrom(row, n)
	return true
end

local function shouldAutoSearchNode(node)
	if not node then
		return false
	end
	if (node.level or 0) == 0 then
		return false
	end
	local mainFrame = GF.MainFrame
	if not (mainFrame and mainFrame.GetCurrentTabID and mainFrame:GetCurrentTabID() == GF.TAB_BROWSE) then
		return false
	end
	if GF.FindGroupTab and GF.FindGroupTab.IsSearchableSelection then
		return GF.FindGroupTab:IsSearchableSelection(node) == true
	end
	return GF.NavData and GF.NavData.IsSearchable and GF.NavData.IsSearchable(node) == true
end

local function autoSearchSelectedNode(node)
	if not shouldAutoSearchNode(node) then
		return
	end
	if GF.FindGroupTab and GF.FindGroupTab.DoSearch then
		GF.FindGroupTab:DoSearch({ source = "navFlyoutClick" })
	end
end

function NF:OnRowClick(row)
	local n = row and row.nodeData
	if not n or n.disabled then
		return false
	end
	if self.navTree and self.navTree.IsInteractionEnabled and not self.navTree:IsInteractionEnabled() then
		return false
	end
	if n.historyClear then
		if GF.History and GF.History.Clear then
			GF.History.Clear()
		end
		if self.navTree and self.navTree.Refresh then
			self.navTree:Refresh()
		end
		self:HideAll()
		return true
	end
	local navTree = self.navTree
	if nodeCanExpand(n) then
		if navTree and navTree.SetSelected and GF.NavData.AcceptsBrowseSelection(n) then
			navTree:SetSelected(n, true, { keepFlyouts = true })
		end
		self:OpenFrom(row, n)
		self:RefreshVisibleRows()
		autoSearchSelectedNode(n)
		return true
	end
	local canBrowse = GF.NavData.AcceptsBrowseSelection(n)
	if canBrowse then
		if navTree and navTree.SetSelected then
			navTree:SetSelected(n)
		end
		autoSearchSelectedNode(n)
		self:HideAll()
		return true
	end
	return false
end

local function wireRow(row, flyout)
	row.hit:SetScript("OnEnter", function()
		if row.nodeData and not row.nodeData.disabled then
			flyout:OpenFromHover(row)
			setFlyoutHoverShown(row, true)
		end
	end)
	row.hit:SetScript("OnLeave", function()
		setFlyoutHoverShown(row, false)
	end)
	row.hit:SetScript("OnClick", function()
		flyout:OnRowClick(row)
	end)
end

local function createFlyoutRow(parent, index, flyout)
	local row = GF.NavTree.CreateNavRowFrame(parent, "GroupFinderAddonNavFlyoutRow" .. index)
	wireRow(row, flyout)
	row:Hide()
	return row
end

local rowNameSeq = 0

local function invalidateFlyoutRow(row)
	if row.arrow then
		row.arrow:Hide()
	end
	row.nodeData = nil
	row._gfHlW = nil
	row._gfHlH = nil
	row._gfHlX = nil
	if row.hover then
		row.hover:Hide()
	end
	row._flyoutSelected = nil
	setFlyoutHoverShown(row, false)
	setFlyoutSelectedShown(row, false)
	if row.sel then
		row.sel:Hide()
	end
	row:Hide()
end

function NF:ReleaseRow(row)
	if not row then
		return
	end
	invalidateFlyoutRow(row)
	row._gfFlyoutPanel = nil
	if self:RowIsAnchor(row) then
		return
	end
	row:ClearAllPoints()
	if self.rowPoolHost then
		row:SetParent(self.rowPoolHost)
	end
	self.freeRows[#self.freeRows + 1] = row
end

function NF:ReleasePanelRows(panel, fromIdx)
	if not panel or not panel.rows then
		return
	end
	fromIdx = fromIdx or 1
	for j = #panel.rows, fromIdx, -1 do
		local row = panel.rows[j]
		panel.rows[j] = nil
		self:ReleaseRow(row)
	end
end

function NF:AcquireRow(parent, panel)
	local row
	for idx = #self.freeRows, 1, -1 do
		local candidate = self.freeRows[idx]
		if candidate and not self:RowIsAnchor(candidate) then
			row = table.remove(self.freeRows, idx)
			break
		end
	end
	if row then
		row:ClearAllPoints()
		row:SetParent(parent)
	else
		rowNameSeq = rowNameSeq + 1
		row = createFlyoutRow(parent, rowNameSeq, self)
	end
	row._gfFlyoutPanel = panel
	return row
end

local function createPanel(parent, index)
	local panel = CreateFrame("Frame", "GroupFinderAddonNavFlyout" .. index, parent)
	applyFlyoutPanelChrome(panel)
	panel:SetFrameStrata("DIALOG")
	panel:EnableMouse(true)
	panel:Hide()
	local insetL, insetR, insetT, insetB = flyoutContentInsets()
	panel.scroll = GF.UI.CreateScrollFrame(panel, { rowHeight = GF.NAV_WHEEL_ROW_H or 28 })
	panel.scroll:SetFrameLevel(panel:GetFrameLevel() + 2)
	panel.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", insetL, -insetT)
	panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -insetR, insetB)
	panel.content = CreateFrame("Frame", nil, panel.scroll)
	panel.scroll:SetScrollChild(panel.content)
	panel.rows = {}
	return panel
end

function NF:RefreshPanelChrome()
	if not self.panels then
		return
	end
	for _, panel in ipairs(self.panels) do
		panel._layoutSig = nil
		applyFlyoutPanelChrome(panel)
	end
end

function NF:Init(anchorParent, navTree)
	if self.panels then
		self.navTree = navTree
		return
	end
	self.navTree = navTree
	self.freeRows = {}
	self.openKeys = {}
	self.rowPoolHost = CreateFrame("Frame", nil, anchorParent)
	self.rowPoolHost:Hide()
	self.panels = {}
	local panelW = flyoutMinPanelWidth()
	for i = 1, PANEL_COUNT do
		local panel = createPanel(anchorParent, i)
		panel:SetWidth(panelW)
		panel.panelW = panelW
		panel:SetFrameLevel((anchorParent:GetFrameLevel() or 1) + 30 + i)
		self.panels[i] = panel
	end
end

function NF:SyncPanelWidth()
	if not self.panels then
		return
	end
	for _, panel in ipairs(self.panels) do
		panel._layoutSig = nil
	end
end

function NF:ReanchorOpenPanels()
	if not self.panels then
		return
	end
	for index, panel in ipairs(self.panels) do
		if panel and panel:IsShown() and panel._anchorRow then
			local node = panel._openKey and GF.NavData.FindNodeByKey and GF.NavData.FindNodeByKey(panel._openKey)
			if node then
				self:PrepareNode(node, self.navTree)
				local children = filterChildrenForCurrentTab(node.children)
				if #children == 0 then
					self:HideFromLevel(index)
					return
				end
				self:LayoutPanelRows(panel, children, self.navTree)
			end
			panel._positioned = nil
			self:PositionPanel(panel, panel._anchorRow, index)
			panel:Show()
		end
	end
end
