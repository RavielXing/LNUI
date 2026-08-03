local _, GF = ...

GF.NavFlyout = {}
local NF = GF.NavFlyout

local PANEL_COUNT = 3
local SIG_SEP = "\31"

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if method then
		return method(owner, ...)
	end
end

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

local function nodeCanExpand(node)
	local expansionTest = GF.NavTree and GF.NavTree.NodeCanExpand
	return expansionTest and expansionTest(node) == true
end

local function nodeInteractionBlocked(node, navTree)
	if node == nil then
		return true
	end
	local checker = navTree and navTree.IsNodeInteractionBlocked
	if checker then
		return checker(navTree, node) == true
	end
	return node.disabled == true
end

local function panelIndexForNode(node)
	local depth = node and (node.level or 0)
	return depth and depth < PANEL_COUNT and (depth + 1) or nil
end

local function panelLayoutSig(navTree, children, contentW)
	local fields = {
		navTree and navTree.selectedKey or "",
		tostring(contentW),
		tostring(#children),
	}
	for _, child in ipairs(children) do
		fields[#fields + 1] = child and child.key or ""
		fields[#fields + 1] = child and child.disabled and "1" or "0"
	end
	return table.concat(fields, SIG_SEP)
end

local function nodeVisibleForCurrentTab(node)
	if node == nil then
		return false
	end
	local workspaceView = GF.LFGWorkspaceView
	if workspaceView and workspaceView.IsNodeAllowed and not workspaceView:IsNodeAllowed(node) then
		return false
	end
	local creationTab = invoke(GF.MainFrame, "GetCurrentTabID") == GF.TAB_CREATE
	return not (creationTab and node.browseOnly)
end

local function filterChildrenForCurrentTab(children)
	local visible = {}
	for _, child in ipairs(children or {}) do
		if nodeVisibleForCurrentTab(child) then
			visible[#visible + 1] = child
		end
	end
	return visible
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
	if row and (row._flyoutSelected or row._flyoutDisabled) then
		shown = false
	end
	setFlyoutRowPartsShown(row, "flyoutHover", shown)
end

local function setFlyoutSelectedShown(row, shown)
	if row and row._flyoutDisabled then
		shown = false
	end
	setFlyoutRowPartsShown(row, "flyoutSelected", shown)
end

local function layoutFlyoutHover(row, width, height, offsetX, offsetY)
	layoutFlyoutRowParts(row, "flyoutHover", width, height, offsetX, offsetY, "BORDER", 2)
end

local function layoutFlyoutSelected(row, width, height, offsetX, offsetY)
	layoutFlyoutRowParts(row, "flyoutSelected", width, height, offsetX, offsetY, "BORDER", 3)
end

function NF:RowIsAnchor(row)
	for index = 1, #(self.panels or {}) do
		if row and self.panels[index]._anchorRow == row then
			return true
		end
	end
	return false
end

local function rowIsDescendantOf(row, frame)
	local cursor = row and row:GetParent()
	while cursor and frame do
		if cursor == frame then
			return true
		end
		cursor = cursor:GetParent()
	end
	return false
end

function NF:BeginPanelLayout(panel)
	if panel == nil then
		return
	end
	panel._positioned = nil
	panel:Hide()
	panel:ClearAllPoints()
end

function NF:HideFromLevel(level)
	local panels = self.panels
	if panels == nil then
		return
	end
	level = level or 1
	if self.openKeys then
		local nodeDepth = math.max(0, level - 1)
		while nodeDepth <= PANEL_COUNT do
			self.openKeys[nodeDepth] = nil
			nodeDepth = nodeDepth + 1
		end
	end
	for panelIndex = PANEL_COUNT, level, -1 do
		local panel = panels[panelIndex]
		if panel then
			panel._openKey, panel._anchorRow = nil, nil
			panel._layoutSig, panel._positioned = nil, nil
			panel:Hide()
			self:ReleasePanelRows(panel)
		end
	end
end

function NF:HideAll()
	self:HideFromLevel(1)
	self.openKeys = nil
end

function NF:IsNodeOpen(node)
	local keys = self.openKeys
	return node ~= nil and keys ~= nil and keys[node.level or 0] == node.key
end

function NF:CloseChildPanelsForRow(row)
	local node = row and row.nodeData
	if node == nil then
		return
	end
	local firstChildPanel = panelIndexForNode(node)
	if firstChildPanel then
		self:HideFromLevel(firstChildPanel)
	end
	invoke(self, "RefreshVisibleRows")
end

local function setDisabledLabelColor(label)
	local state = GF.BUTTON_VISUAL_STATE and GF.BUTTON_VISUAL_STATE.DISABLED or "disabled"
	local visual = GF.COMMON_BUTTON_VISUALS and GF.COMMON_BUTTON_VISUALS[state]
	local color = visual and visual.textColor
	if color then
		label:SetTextColor(unpack(color))
	else
		label:SetTextColor(0.55, 0.55, 0.55, 1)
	end
end

local function layoutFlyoutRow(row, n, navTree, width, h)
	local disabled = nodeInteractionBlocked(n, navTree)
	local label = row.label
	row.bg:SetShown(false)
	row.cover:SetShown(false)
	label:ClearAllPoints()
	label:SetPoint("LEFT", row, "LEFT", GF.NAV_FLYOUT_ROW_TEXT_L or 12, 0)
	local applyArrow = GF.NavTree and GF.NavTree.ApplyExpandArrow
	local hasArrow = applyArrow and applyArrow(row, n)
	if hasArrow then
		row.arrow:ClearAllPoints()
		row.arrow:SetPoint("RIGHT", row, "RIGHT", -(GF.NAV_FLYOUT_ARROW_R or 8), 0)
		label:SetPoint("RIGHT", row.arrow, "LEFT", -4, 0)
	else
		label:SetPoint("RIGHT", row, "RIGHT", -(GF.NAV_FLYOUT_ROW_TEXT_R or 10), 0)
	end
	label:SetText(n.label or "")
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	label:SetWordWrap(false)
	label:Show()
	GF.Font.ApplyToFontString(label, "GameFontNormal")
	if disabled then
		setDisabledLabelColor(label)
	elseif n.historyClear then
		label:SetTextColor(0.75, 0.75, 0.75)
	else
		label:SetTextColor(1, 1, 1)
	end
	local isSel = not disabled
		and ((navTree and navTree.selectedKey == n.key) or (GF.NavFlyout and GF.NavFlyout:IsNodeOpen(n)))
	local hlX = GF.NAV_FLYOUT_HIGHLIGHT_INSET_X or 6
	local hlTop = GF.NAV_FLYOUT_HIGHLIGHT_INSET_TOP or 3
	local hlBottom = GF.NAV_FLYOUT_HIGHLIGHT_INSET_BOTTOM or 1
	local textureExtendX = GF.NAV_FLYOUT_ROW_TEXTURE_EXTEND_X or 0
	local hlW = width - (hlX * 2) + (textureExtendX * 2)
	local hlH = h - hlTop - hlBottom
	local hlOffsetX = hlX - textureExtendX
	local hlY = (hlBottom - hlTop) / 2
	row._flyoutDisabled = disabled
	row._flyoutSelected = isSel
	layoutFlyoutHover(row, hlW, hlH, hlOffsetX, hlY)
	layoutFlyoutSelected(row, hlW, hlH, hlOffsetX, hlY)
	setFlyoutSelectedShown(row, isSel)
	if row.sel then
		row.sel:Hide()
	end
	setFlyoutHoverShown(row, false)
	row.hit:SetFrameLevel(row:GetFrameLevel() + 2)
	row.hit:EnableMouse(not disabled)
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

local function rowForPanel(flyout, panel, index)
	local row = panel.rows[index]
	if row and row._gfFlyoutPanel and row._gfFlyoutPanel ~= panel then
		panel.rows[index] = nil
		row = nil
	end
	if row == nil then
		row = flyout:AcquireRow(panel.content, panel)
		panel.rows[index] = row
	elseif row:GetParent() ~= panel.content then
		row:ClearAllPoints()
		row:SetParent(panel.content)
	end
	return row
end

local function estimatedChildrenHeight(children)
	local total = 0
	for _, node in ipairs(children) do
		total = total + flyoutRowHeight(node.level or 1)
	end
	return math.max(total, 1)
end

function NF:LayoutPanelRows(panel, children, navTree)
	children = children or {}
	local insetL, insetR, insetT, insetB = flyoutContentInsets()
	local width = resolvePanelWidth(panel, children)
	local contentWidth = math.max(80, width - insetL - insetR)
	local signature = panelLayoutSig(navTree, children, contentWidth)
	panel:SetWidth(width)
	panel.panelW = width
	if signature == panel._layoutSig then
		return
	end
	panel._layoutSig = signature
	self:BeginPanelLayout(panel)
	panel.content:SetSize(contentWidth, estimatedChildrenHeight(children))

	local offset = 0
	for index, node in ipairs(children) do
		local row = rowForPanel(self, panel, index)
		local rowHeight = flyoutRowHeight(node.level or 1)
		row:SetSize(contentWidth, rowHeight)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offset)
		row.nodeData = node
		row:Show()
		layoutFlyoutRow(row, node, navTree, contentWidth, rowHeight)
		offset = offset + rowHeight
	end
	self:ReleasePanelRows(panel, #children + 1)
	panel.content:SetSize(contentWidth, math.max(offset, 1))
	panel._fullHeight = offset + insetT + insetB
	setFlyoutPanelVisibleHeight(panel, panel._fullHeight, true)
end

function NF:PositionPanel(panel, anchorRow, panelIdx)
	local positionIsCurrent = panel._positioned and panel._anchorRow == anchorRow
	if positionIsCurrent then
		return
	end
	local gap = flyoutPanelAnchorGap(panelIdx)
	local parentPanel = panelIdx and panelIdx > 1 and self.panels
		and self.panels[panelIdx - 1] or nil
	panel:ClearAllPoints()
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
	if node and navTree then
		invoke(navTree, "PrepareBranch", node)
	end
end

function NF:OpenFrom(anchorRow, node)
	if anchorRow == nil or nodeInteractionBlocked(node, self.navTree) or not nodeCanExpand(node) then
		return
	end
	local panelIndex = panelIndexForNode(node)
	local panel = panelIndex and self.panels and self.panels[panelIndex]
	if panel == nil or rowIsDescendantOf(anchorRow, panel) then
		return
	end

	local navTree = self.navTree
	self:PrepareNode(node, navTree)
	local children = filterChildrenForCurrentTab(node.children)
	if #children == 0 then
		return
	end

	self:HideFromLevel(panelIndex + 1)
	self.openKeys = self.openKeys or {}
	self.openKeys[node.level or 0] = node.key
	panel._openKey, panel._anchorRow = node.key, anchorRow
	self:BeginPanelLayout(panel)
	self:LayoutPanelRows(panel, children, navTree)
	self:PositionPanel(panel, anchorRow, panelIndex)
	panel:Show()
	self:RefreshVisibleRows()
end

function NF:OpenFromHover(row)
	local n = row and row.nodeData
	if nodeInteractionBlocked(n, self.navTree) then
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
	local node = row and row.nodeData
	if nodeInteractionBlocked(node, self.navTree) then
		return false
	end
	local navTree = self.navTree
	if navTree and navTree.IsInteractionEnabled and navTree:IsInteractionEnabled() == false then
		return false
	end
	if node.historyClear then
		if GF.History and GF.History.Clear then
			GF.History.Clear()
		end
		invoke(navTree, "Refresh")
		self:HideAll()
		return true
	end

	if nodeCanExpand(node) then
		if GF.NavData.AcceptsBrowseSelection(node) then
			invoke(navTree, "SetSelected", node, true, { keepFlyouts = true })
		end
		self:OpenFrom(row, node)
		self:RefreshVisibleRows()
		autoSearchSelectedNode(node)
		return true
	end

	if GF.NavData.AcceptsBrowseSelection(node) then
		invoke(navTree, "SetSelected", node)
		autoSearchSelectedNode(node)
		self:HideAll()
		return true
	end
	return false
end

local function wireRow(row, flyout)
	local hitTarget = row.hit
	hitTarget:SetScript("OnEnter", function()
		local node = row.nodeData
		if not node then
			return
		end
		if nodeInteractionBlocked(node, flyout.navTree) then
			setFlyoutHoverShown(row, false)
			return
		end
		flyout:OpenFromHover(row)
		setFlyoutHoverShown(row, true)
	end)
	hitTarget:SetScript("OnLeave", function()
		setFlyoutHoverShown(row, false)
	end)
	hitTarget:SetScript("OnClick", function()
		flyout:OnRowClick(row)
	end)
end

local function createFlyoutRow(parent, index, flyout)
	local createRow = GF.NavTree.CreateNavRowFrame
	local rowName = "GroupFinderAddonNavFlyoutRow" .. index
	local row = createRow(parent, rowName)
	wireRow(row, flyout)
	row:Hide()
	return row
end

local rowNameSeq = 0

local function invalidateFlyoutRow(row)
	local arrow, hover, selectedTexture = row.arrow, row.hover, row.sel
	if arrow then
		arrow:Hide()
	end
	if hover then
		hover:Hide()
	end
	row.nodeData, row._flyoutSelected, row._flyoutDisabled = nil, nil, nil
	row._gfHlW, row._gfHlH, row._gfHlX = nil, nil, nil
	setFlyoutHoverShown(row, false)
	setFlyoutSelectedShown(row, false)
	if selectedTexture then
		selectedTexture:Hide()
	end
	row:Hide()
end

function NF:ReleaseRow(row)
	if row == nil then
		return
	end
	invalidateFlyoutRow(row)
	row._gfFlyoutPanel = nil
	if self:RowIsAnchor(row) then
		return
	end
	row:ClearAllPoints()
	local poolHost = self.rowPoolHost
	if poolHost then
		row:SetParent(poolHost)
	end
	table.insert(self.freeRows, row)
end

function NF:ReleasePanelRows(panel, fromIdx)
	local rows = panel and panel.rows
	if rows == nil then
		return
	end
	for index = #rows, fromIdx or 1, -1 do
		local row = rows[index]
		rows[index] = nil
		self:ReleaseRow(row)
	end
end

function NF:AcquireRow(parent, panel)
	local pool, row = self.freeRows
	local index = #pool
	while index > 0 and row == nil do
		local candidate = pool[index]
		if not self:RowIsAnchor(candidate) then
			row = candidate
			table.remove(pool, index)
		end
		index = index - 1
	end
	if row == nil then
		rowNameSeq = rowNameSeq + 1
		row = createFlyoutRow(parent, rowNameSeq, self)
	else
		row:SetParent(parent)
		row:ClearAllPoints()
	end
	row["_gfFlyoutPanel"] = panel
	return row
end

local function createPanel(parent, index)
	local name = "GroupFinderAddonNavFlyout" .. index
	local panel = CreateFrame("Frame", name, parent)
	panel:SetFrameStrata("DIALOG")
	panel:EnableMouse(true)
	panel:Hide()
	applyFlyoutPanelChrome(panel)

	local insetL, insetR, insetT, insetB = flyoutContentInsets()
	local scroll = GF.UI.CreateScrollFrame(panel, { rowHeight = GF.NAV_WHEEL_ROW_H or 28 })
	scroll:SetFrameLevel(panel:GetFrameLevel() + 2)
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", insetL, -insetT)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -insetR, insetB)
	local content = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(content)
	panel.scroll, panel.content = scroll, content
	panel.rows = {}
	return panel
end

function NF:RefreshPanelChrome()
	for _, panel in ipairs(self.panels or {}) do
		panel._layoutSig = nil
		applyFlyoutPanelChrome(panel)
	end
end

function NF:Init(anchorParent, navTree)
	if self.panels then
		self.navTree = navTree
		return
	end

	local poolHost = CreateFrame("Frame", nil, anchorParent)
	poolHost:Hide()
	self.navTree, self.rowPoolHost = navTree, poolHost
	self.freeRows, self.openKeys, self.panels = {}, {}, {}

	local initialWidth = flyoutMinPanelWidth()
	local baseLevel = (anchorParent:GetFrameLevel() or 1) + 30
	for index = 1, PANEL_COUNT do
		local panel = createPanel(anchorParent, index)
		panel:SetWidth(initialWidth)
		panel.panelW = initialWidth
		panel:SetFrameLevel(baseLevel + index)
		self.panels[index] = panel
	end
end

function NF:SyncPanelWidth()
	for _, panel in ipairs(self.panels or {}) do
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
			if node and nodeInteractionBlocked(node, self.navTree) then
				self:HideFromLevel(index)
				return
			elseif node then
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
