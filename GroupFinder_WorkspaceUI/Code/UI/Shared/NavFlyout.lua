local _, GF = ...
GF = GF.GF or GF

GF.NavFlyout = {}
local NF = GF.NavFlyout
local ROW_STYLE = GF.LIST_ROW_STYLE or {}
local ROW_TEXT_INSET_Y = GF.NAV_FLYOUT_ROW_TEXT_INSET_Y or 2

local function presenter()
	return GF.NavigationPresenter
end

local Presenter = presenter()
if Presenter and Presenter.BindFlyout then
	Presenter:BindFlyout(NF)
end

local PANEL_COUNT = 3
local SIG_SEP = "\31"
local QUICK_SEARCH_PANEL_WIDTH = 260
local QUICK_SEARCH_HEADER_HEIGHT = 70
local QUICK_SEARCH_TITLE_HEIGHT = 22
local QUICK_SEARCH_BOX_HEIGHT = 26
local QUICK_SEARCH_TOP_DIVIDER_TO_BOX_GAP = 7
local QUICK_SEARCH_BOX_TO_BOTTOM_DIVIDER_GAP = 5
local FAVORITE_REORDER_FOOTER_HEIGHT = 54
local FAVORITE_REORDER_BUTTON_SIZE = 20
local FAVORITE_REORDER_BUTTON_GAP = 2
local FAVORITE_REORDER_ACTION_BUTTON_WIDTH = 72
local FAVORITE_REORDER_ACTION_BUTTON_HEIGHT = GF.PANEL_BUTTON_H
local FAVORITE_REORDER_ACTION_BUTTON_GAP = 8
local FAVORITE_REORDER_HINT_HEIGHT = 16
local FAVORITE_REORDER_HINT_TOP_GAP = 4
local FAVORITE_REORDER_HINT_BUTTON_GAP = 4
local FAVORITE_REORDER_DIVIDER_ALPHA = 0.7
local FLYOUT_GOLDEN_DIVIDER_ATLAS = "levelup-bar-gold"
local FLYOUT_GOLDEN_DIVIDER_SLOT_HEIGHT = 4
local FLYOUT_GOLDEN_DIVIDER_VISUAL_OFFSET_Y = 2
local FLYOUT_LOADING_SPINNER_SIZE = 16
local FLYOUT_LOADING_SPINNER_GAP = 5

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if method then
		return method(owner, ...)
	end
end

local function playFlyoutOpenAnimation(panel, panelIndex)
	if GF.UI and GF.UI.PlayPopupOpenAnimation then
		local options = { preset = "flyout" }
		if panel._anchorRow and panel._anchorRow._gfNavStandaloneAnchor then
			-- Settle from the content side without crossing the divider.
			options.translateX = 10
			options.translateY = 0
		elseif panelIndex == 1 then
			-- The root hangs below the navigation row, so it settles downward
			-- from that row. Deeper levels settle rightward from their parent.
			options.translateX = 0
			options.translateY = 9
		end
		GF.UI.PlayPopupOpenAnimation(panel, options)
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

local function flyoutRowBackgroundInsetX()
	return (GF.NAV_FLYOUT_HIGHLIGHT_INSET_X or 6)
		- (GF.NAV_FLYOUT_ROW_TEXTURE_EXTEND_X or 0)
end

local function flyoutScrollPaddingX()
	return math.max(0, -flyoutRowBackgroundInsetX())
end

local function anchorFlyoutScroll(panel, headerHeight, footerHeight)
	local insetL, insetR, insetT, insetB = flyoutContentInsets()
	local paddingX = flyoutScrollPaddingX()
	-- Include the complete fading endcaps in the viewport. Rows compensate for
	-- this extra space, preserving their screen positions and click widths.
	panel.scroll:ClearAllPoints()
	panel.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT",
		insetL - paddingX, -(insetT + (headerHeight or 0)))
	panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT",
		-insetR + paddingX, insetB + (footerHeight or 0))
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

local function stopFlyoutHeightAnimation(panel)
	if panel._heightTween then
		panel._heightTween = nil
		panel:SetScript("OnUpdate", nil)
	end
end

local function applyFlyoutPanelVisibleHeight(panel, height, resetScroll)
	panel._visibleHeight = height
	panel:SetHeight(height)
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

local function updateFlyoutHeightAnimation(panel, elapsed)
	local tween = panel._heightTween
	if not tween then
		return
	end
	tween.elapsed = tween.elapsed + math.max(0, elapsed)
	local progress = math.min(1, tween.elapsed / tween.duration)
	local eased = progress * progress * (3 - 2 * progress)
	local height = tween.from + (tween.target - tween.from) * eased
	if progress == 1 then
		height = tween.target
		stopFlyoutHeightAnimation(panel)
	end
	-- While shrinking, the displayed frame can still be taller than the new
	-- content. Only the destination is capped to its natural height.
	applyFlyoutPanelVisibleHeight(panel, height, false)
end

local function setFlyoutPanelVisibleHeight(panel, height, resetScroll, animate)
	if not panel then
		return
	end
	local naturalH = math.max(panel._fullHeight or height or 1, 1)
	local visibleH = math.min(math.max(height or naturalH, 1), naturalH)
	local duration = GF.NAV_SEARCH_RESIZE_DURATION or 0.20
	local currentH = panel:GetHeight() or 0
	if not animate or not panel:IsVisible() or currentH <= 0
		or duration <= 0 or math.abs(currentH - visibleH) < 0.5
	then
		stopFlyoutHeightAnimation(panel)
		applyFlyoutPanelVisibleHeight(panel, visibleH, resetScroll)
		return
	end
	local tween = panel._heightTween
	if not tween or tween.target ~= visibleH then
		-- Repeated input redirects from the currently drawn height; refreshing
		-- the same destination keeps its original completion time.
		panel._heightTween = {
			from = currentH, target = visibleH, elapsed = 0, duration = duration,
		}
		panel:SetScript("OnUpdate", updateFlyoutHeightAnimation)
	end
	applyFlyoutPanelVisibleHeight(panel, currentH, resetScroll)
end

local function resolvePanelHeightAndTop(panel, desiredTop)
	local naturalH = math.max(panel and panel._fullHeight or 1, 1)
	local windowTop, windowBottom = getFlyoutWindowBounds()
	desiredTop = math.min(desiredTop or windowTop, windowTop)
	local availableH = math.max(desiredTop - windowBottom, 1)
	local visibleH = math.min(naturalH, availableH)
	return visibleH, desiredTop
end

local function getEffectiveScale(frame)
	local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
	if type(scale) ~= "number" or scale <= 0 then
		return nil
	end
	return scale
end

local function getScaledFrameRect(frame)
	if not frame then
		return nil
	end
	if frame.GetScaledRect then
		local left, bottom, width, height = frame:GetScaledRect()
		if type(left) == "number" and type(bottom) == "number"
			and type(width) == "number" and type(height) == "number" then
			return left, bottom, width, height
		end
	end
	local scale = getEffectiveScale(frame)
	local left = frame.GetLeft and frame:GetLeft()
	local bottom = frame.GetBottom and frame:GetBottom()
	local width = frame.GetWidth and frame:GetWidth()
	local height = frame.GetHeight and frame:GetHeight()
	if scale and type(left) == "number" and type(bottom) == "number"
		and type(width) == "number" and type(height) == "number" then
		return left * scale, bottom * scale, width * scale, height * scale
	end
	return nil
end

local function resolveDeepPanelVerticalPlacement(defaultTop, naturalHeight, uiBottom, uiTop, bottomMargin)
	if type(defaultTop) ~= "number" or type(naturalHeight) ~= "number"
		or type(uiBottom) ~= "number" or type(uiTop) ~= "number" then
		return nil
	end
	naturalHeight = math.max(naturalHeight, 1)
	bottomMargin = math.max(tonumber(bottomMargin) or 0, 0)
	local safeBottom = uiBottom + bottomMargin
	local availableHeight = math.max(uiTop - safeBottom, 1)
	if naturalHeight > availableHeight then
		return availableHeight, uiTop, true
	end
	local minimumTop = safeBottom + naturalHeight
	return naturalHeight, math.max(defaultTop, minimumTop), false
end

NF.ResolveDeepPanelVerticalPlacement = resolveDeepPanelVerticalPlacement

local function shouldAlignDeepPanelToParentRow(panelIdx)
	if type(panelIdx) ~= "number" or panelIdx < 2 then
		return false
	end
	local mainFrame = GF.MainFrame
	local tabID = mainFrame and mainFrame.GetCurrentTabID and mainFrame:GetCurrentTabID()
	if tabID ~= GF.TAB_BROWSE and tabID ~= GF.TAB_CREATE then
		return false
	end
	local workspaceID = mainFrame.GetCurrentWorkspaceID and mainFrame:GetCurrentWorkspaceID()
	return workspaceID == (GF.WORKSPACE_MEETING_STONE or "meeting_stone")
end

NF.ShouldAlignDeepPanelToParentRow = shouldAlignDeepPanelToParentRow

local function resolveDeepPanelHeightAndOffset(panel, anchorRow, parentPanel, maxVisibleHeight)
	local panelScale = getEffectiveScale(panel)
	local uiScale = getEffectiveScale(UIParent)
	local _, uiBottom, _, uiHeight = getScaledFrameRect(UIParent)
	local _, rowBottom, _, rowHeight = getScaledFrameRect(anchorRow)
	local _, parentBottom, _, parentHeight = getScaledFrameRect(parentPanel)
	if not (panelScale and uiScale and uiBottom and uiHeight
		and rowBottom and rowHeight and parentBottom and parentHeight) then
		return nil
	end
	local naturalHeight = math.max(panel._fullHeight or panel:GetHeight() or 1, 1)
	local cappedHeight = math.min(naturalHeight, math.max(tonumber(maxVisibleHeight) or naturalHeight, 1))
	local visibleHeightScaled, resolvedTopScaled = resolveDeepPanelVerticalPlacement(
		rowBottom + rowHeight,
		cappedHeight * panelScale,
		uiBottom,
		uiBottom + uiHeight,
		(GF.NAV_FLYOUT_SCREEN_MARGIN_BOTTOM or 12) * uiScale
	)
	if not (visibleHeightScaled and resolvedTopScaled) then
		return nil
	end
	local parentTopScaled = parentBottom + parentHeight
	return visibleHeightScaled / panelScale, (resolvedTopScaled - parentTopScaled) / panelScale
end

NF.ResolveDeepPanelHeightAndOffset = resolveDeepPanelHeightAndOffset

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

local function resolveSecondLevelMaxVisibleHeight(navTree)
	local rootAnchor = resolveRootFlyoutAnchor(navTree)
	if not rootAnchor then
		return nil
	end
	local windowTop, windowBottom = getFlyoutWindowBounds()
	local resolvedTop = math.min(rootAnchor.baseTop, windowTop)
	return math.max(resolvedTop - windowBottom, 1)
end

NF.ResolveSecondLevelMaxVisibleHeight = resolveSecondLevelMaxVisibleHeight

local function resolveQuickSearchVisibleHeight(naturalHeight, maxVisibleHeight)
	naturalHeight = math.max(tonumber(naturalHeight) or 1, 1)
	maxVisibleHeight = tonumber(maxVisibleHeight)
	if not maxVisibleHeight or maxVisibleHeight <= 0 then
		return naturalHeight
	end
	return math.min(naturalHeight, maxVisibleHeight)
end

NF.ResolveQuickSearchVisibleHeight = resolveQuickSearchVisibleHeight

local function nodeCanExpand(node)
	local owner = presenter()
	return owner and owner:NodeCanExpand(node) == true or false
end

local function nodeInteractionBlocked(node, navTree)
	local owner = presenter()
	return owner == nil or owner:IsNodeInteractionBlocked(node)
end

local function panelLayoutSig(navTree, children, contentW)
	local owner = presenter()
	local fields = {
		owner and owner:GetSelectedKey() or "",
		tostring(contentW),
		tostring(#children),
		children and children[1] and children[1]._gfQuickSearchProxy and "quick" or "standard",
		owner and owner:IsFavoriteReorderMode() and "reorder" or "normal",
	}
	for _, child in ipairs(children) do
		fields[#fields + 1] = child and child.key or ""
		fields[#fields + 1] = child and child.label or ""
		fields[#fields + 1] = child and child.disabled and "1" or "0"
		fields[#fields + 1] = child and child.childrenLoaded and "1" or "0"
		fields[#fields + 1] = child and child.isLeaf and "1" or "0"
		fields[#fields + 1] = child and child.navLoading and "1" or "0"
		fields[#fields + 1] = tostring(child and child.level or 0)
		fields[#fields + 1] = tostring(
			child and child._gfQuickSearchGeneration or "")
	end
	return table.concat(fields, SIG_SEP)
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
	local hasFavoriteIcon = false
	local hasLoadingSpinner = false
	for i = 1, #(children or {}) do
		local n = children[i]
		maxLabelW = math.max(maxLabelW, measureLabelWidth(panel, n and n.label))
		if nodeCanExpand(n) then
			hasExpandable = true
		end
		hasFavoriteIcon = hasFavoriteIcon or n and n.favoriteResult == true
		hasLoadingSpinner = hasLoadingSpinner or n and n.navLoading == true
	end
	local rowExtra = (GF.NAV_FLYOUT_ROW_TEXT_L or 12)
		+ (GF.NAV_FLYOUT_ROW_TEXT_R or 10)
		+ (GF.NAV_FLYOUT_LABEL_EXTRA_W or 8)
	if hasExpandable then
		rowExtra = rowExtra + (GF.NAV_FLYOUT_ARROW_RESERVE_W or 28)
	end
	if hasFavoriteIcon then
		rowExtra = rowExtra + (GF.FAVORITE_INSTANCE_ICON_SIZE or 14)
			+ (GF.FAVORITE_INSTANCE_ICON_GAP or 3)
	end
	if hasLoadingSpinner then
		rowExtra = rowExtra + FLYOUT_LOADING_SPINNER_SIZE
			+ FLYOUT_LOADING_SPINNER_GAP
	end
	local owner = presenter()
	if owner and owner:IsFavoriteReorderMode() and hasFavoriteIcon then
		rowExtra = rowExtra + (FAVORITE_REORDER_BUTTON_SIZE * 2)
			+ FAVORITE_REORDER_BUTTON_GAP + 4
	end
	local desired = insetL + insetR + maxLabelW + rowExtra
	if owner and owner:IsFavoriteReorderMode() and hasFavoriteIcon then
		desired = math.max(desired, 210)
	end
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

local function layoutFlyoutRowParts(row, prefix, insetX, drawLayer, subLevel)
	local parts = ensureFlyoutRowParts(row, prefix, drawLayer, subLevel)
	if not (parts and GF.UI and GF.UI.ApplyRowBackgroundPieces) then
		return
	end
	local _, layout = GF.UI.ApplyRowBackgroundPieces(row, parts, {
		atlas = GF.NAV_FLYOUT_HIGHLIGHT_ATLAS or GF.ROW_BACKGROUND_ATLAS,
		profile = GF.NAV_FLYOUT_ROW_BACKGROUND_PROFILE or ROW_STYLE.background,
		mode = "full",
		alpha = 1,
		preserveAtlasColor = true,
		insetLeft = insetX,
		insetRight = insetX,
		fallbackTexture = GF.ROW_BACKGROUND_FALLBACK_TEXTURE,
	})
	return layout
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

function NF:IsRowSelected(node)
	if not node or node._gfNavSuppressSelection then return false end
	local owner = presenter()
	return ((owner and owner:GetSelectedKey() == node.key) or self:IsNodeOpen(node)) == true
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

function NF:RenderHideFromLevel(level)
	local panels = self.panels
	if panels == nil then
		return
	end
	level = level or 1
	for panelIndex = PANEL_COUNT, level, -1 do
		local panel = panels[panelIndex]
		if panel then
			if panel.quickSearchBox and panel.quickSearchBox.ClearFocus then
				panel.quickSearchBox:ClearFocus()
			end
			panel._openKey, panel._anchorRow = nil, nil
			panel._layoutSig, panel._positioned = nil, nil
			panel:Hide()
			self:ReleasePanelRows(panel)
		end
	end
end

function NF:RenderHideAll()
	self:RenderHideFromLevel(1)
end

function NF:HideFromLevel(level)
	local owner = presenter()
	return owner and owner:HideFromLevel(level) or nil
end

function NF:HideAll()
	local owner = presenter()
	return owner and owner:HideAll() or self:RenderHideAll()
end

function NF:IsNodeOpen(node)
	local owner = presenter()
	return owner and owner:IsNodeOpen(node) == true or false
end

function NF:CloseChildPanelsForRow(row)
	local owner = presenter()
	return owner and owner:CloseChildPanelsForRow(row) or false
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

local function disabledTooltipText(node, navTree)
	if not (node and node.disabled == true and node.disabledTooltip == true)
		or node._gfLfgRestrictionState ~= nil
	then
		return nil
	end
	if navTree and navTree.IsInteractionEnabled
		and navTree:IsInteractionEnabled() == false
	then
		return nil
	end
	local text = node.disabledReason or node.tooltip
	return type(text) == "string" and text ~= "" and text or nil
end

local function showDisabledTooltip(owner, node, navTree)
	local text = disabledTooltipText(node, navTree)
	if not text or not (GF.UI and GF.UI.BeginGameTooltip) or not GameTooltip then
		return false
	end
	GF.UI.BeginGameTooltip(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(text, 1, 0.82, 0, 1, true)
	GameTooltip:Show()
	return true
end

local function createFavoriteOrderButton(row, direction)
	local button = CreateFrame("Button", nil, row)
	if GF.UI and GF.UI.ApplyCommonArrowButtonSkin then
		GF.UI.ApplyCommonArrowButtonSkin(button, direction, {
			hitSize = FAVORITE_REORDER_BUTTON_SIZE,
			visualSize = 16,
		})
	else
		button:SetSize(FAVORITE_REORDER_BUTTON_SIZE, FAVORITE_REORDER_BUTTON_SIZE)
	end
	button._gfFavoriteOrderDirection = direction
	button:SetScript("OnClick", function(owner)
		local node = row.nodeData
		if node and node.favoriteIdentity then
			NF:MoveFavoriteDraft(
				node.favoriteIdentity,
				owner._gfFavoriteOrderDirection)
		end
	end)
	button:SetScript("OnEnter", function(owner)
		if not (GF.UI and GF.UI.BeginGameTooltip and GameTooltip) then
			return
		end
		GF.UI.BeginGameTooltip(owner, "ANCHOR_RIGHT")
		local L = GF.L or {}
		GameTooltip:SetText(direction < 0
			and (L.FAVORITE_INSTANCE_MOVE_UP or "Move Up")
			or (L.FAVORITE_INSTANCE_MOVE_DOWN or "Move Down"),
			1, 0.82, 0, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		if GameTooltip_Hide then
			GameTooltip_Hide()
		end
	end)
	button:Hide()
	return button
end

local function layoutFavoriteOrderButtons(row, node, label, contentOffsetY)
	local owner = presenter()
	local visible = owner and owner:IsFavoriteReorderMode()
		and node.favoriteResult == true
	if not visible then
		if row.favoriteMoveUp then row.favoriteMoveUp:Hide() end
		if row.favoriteMoveDown then row.favoriteMoveDown:Hide() end
		return false
	end
	if not row.favoriteMoveUp then
		row.favoriteMoveUp = createFavoriteOrderButton(row, -1)
		row.favoriteMoveDown = createFavoriteOrderButton(row, 1)
		row.favoriteMoveUp:SetPoint(
			"RIGHT", row.favoriteMoveDown, "LEFT", -FAVORITE_REORDER_BUTTON_GAP, 0)
	end
	row.favoriteMoveDown:ClearAllPoints()
	row.favoriteMoveDown:SetPoint(
		"RIGHT", row, "RIGHT", -(GF.NAV_FLYOUT_ROW_TEXT_R or 10), contentOffsetY)
	row.favoriteMoveUp:SetShown(visible)
	row.favoriteMoveDown:SetShown(visible)
	if not visible then
		return false
	end
	local order = tonumber(node.favoriteOrder) or 1
	local reorderOrder = owner and owner:GetFavoriteReorderOrder()
	local count = reorderOrder and #reorderOrder or order
	row.favoriteMoveUp:SetEnabled(order > 1)
	row.favoriteMoveDown:SetEnabled(order < count)
	row.favoriteMoveUp:SetFrameLevel(row:GetFrameLevel() + 5)
	row.favoriteMoveDown:SetFrameLevel(row:GetFrameLevel() + 5)
	if row.arrow then
		row.arrow:Hide()
	end
	label:SetPoint("RIGHT", row.favoriteMoveUp, "LEFT", -4, 0)
	return true
end

local function layoutFlyoutRow(row, n, navTree)
	-- Business restrictions are stamped onto every loaded node by NavData.
	-- Painting a row must stay O(1); the pointer/click handlers still perform the
	-- full path validation before any action is allowed.
	local disabled = n and n.disabled == true
	local hlInsetX = flyoutRowBackgroundInsetX()
	local backgroundLayout = layoutFlyoutRowParts(row, "flyoutHover", hlInsetX, "BORDER", 2)
	layoutFlyoutRowParts(row, "flyoutSelected", hlInsetX, "BORDER", 3)
	-- Start from the drawn atlas center, then compensate for the font's visual
	-- baseline. Keep this optical adjustment independent of row/label height.
	local contentOffsetY = backgroundLayout
		and (backgroundLayout.insetBottom - backgroundLayout.insetTop) / 2 or 0
	contentOffsetY = contentOffsetY + (GF.NAV_FLYOUT_CONTENT_OPTICAL_OFFSET_Y or 0)
	local label = row.label
	row.bg:SetShown(false)
	row.cover:SetShown(false)
	label:ClearAllPoints()
	local textLeft = GF.NAV_FLYOUT_ROW_TEXT_L or 12
	local favoriteIcon = row.favoriteIcon
	if n.favoriteResult then
		if not favoriteIcon then
			favoriteIcon = row:CreateTexture(nil, "OVERLAY", nil, 6)
			row.favoriteIcon = favoriteIcon
		end
		favoriteIcon:ClearAllPoints()
		local iconOffsetY = GF.NAV_FLYOUT_FAVORITE_ICON_OFFSET_Y or 0
		favoriteIcon:SetPoint("LEFT", row, "LEFT", textLeft, contentOffsetY + iconOffsetY)
		local iconSize = GF.FAVORITE_INSTANCE_ICON_SIZE or 14
		local atlas = GF.FAVORITE_INSTANCE_ICON_ATLAS
			or "campcollection-icon-star"
		local hasIcon = GF.UI and GF.UI.SetAtlasFit
			and GF.UI.SetAtlasFit(favoriteIcon, atlas, iconSize, iconSize)
		if hasIcon then
			favoriteIcon:SetDesaturated(disabled)
			favoriteIcon:SetAlpha(disabled and 0.55 or 1)
			favoriteIcon:SetVertexColor(1, 1, 1, 1)
			favoriteIcon:Show()
			label:SetPoint(
				"LEFT",
				favoriteIcon,
				"RIGHT",
				GF.FAVORITE_INSTANCE_ICON_GAP or 3,
				-iconOffsetY)
		else
			favoriteIcon:Hide()
			label:SetPoint("LEFT", row, "LEFT", textLeft, contentOffsetY)
		end
	else
		if favoriteIcon then
			favoriteIcon:Hide()
		end
		label:SetPoint("LEFT", row, "LEFT", textLeft, contentOffsetY)
	end
	local loadingSpinner = row.loadingSpinner
	local loadingLabelCentered = false
	if n.navLoading == true then
		if not loadingSpinner and GF.UI and GF.UI.CreatePendingSpinner then
			loadingSpinner = GF.UI.CreatePendingSpinner(
				row, FLYOUT_LOADING_SPINNER_SIZE)
			row.loadingSpinner = loadingSpinner
		end
		if loadingSpinner then
			label:ClearAllPoints()
			label:SetPoint("CENTER", row, "CENTER", 0, contentOffsetY)
			loadingSpinner:ClearAllPoints()
			loadingSpinner:SetPoint(
				"RIGHT", label, "LEFT", -FLYOUT_LOADING_SPINNER_GAP, 0)
			GF.UI.StartPendingSpinner(
				loadingSpinner, FLYOUT_LOADING_SPINNER_SIZE)
			loadingLabelCentered = true
		end
	elseif loadingSpinner then
		if GF.UI and GF.UI.StopPendingSpinner then
			GF.UI.StopPendingSpinner(loadingSpinner)
		else
			loadingSpinner:Hide()
		end
	end
	local applyArrow = GF.NavTree and GF.NavTree.ApplyExpandArrow
	local hasArrow = applyArrow and applyArrow(row, n)
	if hasArrow then
		row.arrow:ClearAllPoints()
		row.arrow:SetPoint("RIGHT", row, "RIGHT", -(GF.NAV_FLYOUT_ARROW_R or 8), contentOffsetY)
		label:SetPoint("RIGHT", row.arrow, "LEFT", -4, 0)
	elseif not loadingLabelCentered then
		label:SetPoint("RIGHT", row, "RIGHT", -(GF.NAV_FLYOUT_ROW_TEXT_R or 10), contentOffsetY)
	end
	label:SetText(n.label or "")
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	-- Read the assigned row height in every paint path; a caller-supplied width
	-- here can enlarge the label beyond the scroll child's last row.
	label:SetHeight(math.max(1, row:GetHeight() - 2 * ROW_TEXT_INSET_Y))
	label:SetWordWrap(false)
	label:Show()
	GF.Font.ApplyToFontString(label, "GameFontNormal")
	if disabled then
		setDisabledLabelColor(label)
	else
		label:SetTextColor(1, 1, 1)
	end
	local isSel = not disabled and NF:IsRowSelected(n)
	row._flyoutDisabled = disabled
	row._flyoutSelected = isSel
	setFlyoutSelectedShown(row, isSel)
	if row.sel then
		row.sel:Hide()
	end
	setFlyoutHoverShown(row, false)
	row.hit:SetFrameLevel(row:GetFrameLevel() + 2)
	layoutFavoriteOrderButtons(row, n, label, contentOffsetY)
	row._flyoutDisabledTooltip = disabledTooltipText(n, navTree) ~= nil
	-- Disabled rows still need pointer entry events so they can close a stale
	-- sibling submenu. Business actions remain blocked by the row handlers.
	row.hit:EnableMouse(true)
	if n.favoriteResult then
		-- Unavailable favorites remain manageable through Remove/Reorder even
		-- though their normal left-click action is disabled.
		row.hit:EnableMouse(true)
	end
	row._gfNavLevel = n.level or 1
end

function NF:RefreshVisibleRows(skipPanel)
	if not self.panels then
		return
	end
	for _, panel in ipairs(self.panels) do
		if panel ~= skipPanel and panel:IsShown() then
			for _, row in ipairs(panel.rows or {}) do
				if row and row:IsShown() and row.nodeData then
					layoutFlyoutRow(row, row.nodeData, self.navTree)
				end
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

local function createFlyoutGoldenDivider(parent, alpha)
	local slot = CreateFrame("Frame", nil, parent)
	slot:SetHeight(FLYOUT_GOLDEN_DIVIDER_SLOT_HEIGHT)

	local texture = slot:CreateTexture(nil, "ARTWORK")
	local color = GF.HEADER_ACCENT_COLOR or { 1, 0.82, 0, 1 }
	local hasAtlas = GF.UI and GF.UI.TrySetAtlas
		and GF.UI.TrySetAtlas(texture, FLYOUT_GOLDEN_DIVIDER_ATLAS, true)
	texture:ClearAllPoints()
	if not hasAtlas then
		texture:SetColorTexture(
			color[1] or 1,
			color[2] or 0.82,
			color[3] or 0,
			1)
		texture:SetPoint("LEFT", slot, "LEFT", 0, 0)
		texture:SetPoint("RIGHT", slot, "RIGHT", 0, 0)
		texture:SetHeight(1)
	else
		-- Blizzard keeps this atlas at native height and excludes it from
		-- layout. The compact slot does the same job here; the small offset
		-- centers the visible gold stroke rather than its transparent canvas.
		texture:SetPoint(
			"LEFT", slot, "LEFT", 0,
			FLYOUT_GOLDEN_DIVIDER_VISUAL_OFFSET_Y)
		texture:SetPoint(
			"RIGHT", slot, "RIGHT", 0,
			FLYOUT_GOLDEN_DIVIDER_VISUAL_OFFSET_Y)
		texture:SetVertexColor(1, 1, 1, 1)
	end
	texture:SetAlpha(alpha or 1)
	slot.texture = texture
	return slot
end

local function hideQuickSearchClearTooltip(button)
	if button._clearTooltipShown then
		if GameTooltip_Hide then GameTooltip_Hide() end
		button._clearTooltipShown = nil
	end
end

local function setQuickSearchClearIconScale(button, scale)
	button._clearIconScale = scale
	local size = (GF.NAV_QUICK_SEARCH_CLEAR_ICON_SIZE or 16) * scale
	for _, texture in ipairs(button._clearTextures) do
		texture:SetSize(size, size)
	end
end

local function resetQuickSearchClearButton(button)
	button:SetScript("OnUpdate", nil)
	button._clearFade, button._clearRelease = nil, nil
	button._clearTargetShown = nil
	button:SetAlpha(0)
	button:SetEnabled(false)
	setQuickSearchClearIconScale(button, 1)
	hideQuickSearchClearTooltip(button)
end

local function updateQuickSearchClearButton(button, elapsed)
	local fade = button._clearFade
	if fade then
		fade.elapsed = fade.elapsed + elapsed
		local progress = math.min(fade.elapsed / (GF.NAV_QUICK_SEARCH_CLEAR_FADE_DURATION or 0.18), 1)
		local eased = progress * progress * (3 - 2 * progress)
		button:SetAlpha(fade.from + (fade.to - fade.from) * eased)
		if progress == 1 then
			button._clearFade = nil
			if fade.to == 0 then button:Hide(); return end
		end
	end
	local release = button._clearRelease
	if release then
		release.elapsed = release.elapsed + elapsed
		local progress = math.min(release.elapsed / (GF.NAV_QUICK_SEARCH_CLEAR_RELEASE_DURATION or 0.12), 1)
		local eased = 1 - (1 - progress) * (1 - progress)
		setQuickSearchClearIconScale(button, release.from + (1 - release.from) * eased)
		if progress == 1 then button._clearRelease = nil end
	end
	if not (button._clearFade or button._clearRelease) then
		button:SetScript("OnUpdate", nil)
	end
end

local function releaseQuickSearchClearButton(button)
	if button._clearIconScale ~= 1 then
		button._clearRelease = { from = button._clearIconScale, elapsed = 0 }
		button:SetScript("OnUpdate", updateQuickSearchClearButton)
	end
end

local function refreshQuickSearchClearButton(panel)
	local button = panel.quickSearchClearButton
	if not button then return end
	if not panel._quickSearchMode or panel._favoriteSearchMode then
		resetQuickSearchClearButton(button)
		button:Hide()
		return
	end
	local shown = invoke(presenter(), "HasQuickSearchHistory") == true
	if button._clearTargetShown == shown then return end
	button._clearTargetShown = shown
	button:SetEnabled(shown)
	if shown then
		button:Show()
	else
		hideQuickSearchClearTooltip(button)
		releaseQuickSearchClearButton(button)
	end
	-- Retarget from the current opacity so interrupted fades never jump.
	local targetAlpha = shown and 1 or 0
	local alpha = button:GetAlpha()
	if alpha == targetAlpha then
		button._clearFade = nil
		if not shown then button:Hide() end
	else
		button._clearFade = { from = alpha, to = targetAlpha, elapsed = 0 }
		button:SetScript("OnUpdate", updateQuickSearchClearButton)
	end
end

local function refreshQuickSearchHeaderLocale(panel)
	if not panel then
		return
	end
	local L = GF.L or {}
	refreshQuickSearchClearButton(panel)
	if panel.quickSearchTitle then
		panel.quickSearchTitle:SetText(panel._favoriteSearchMode
			and (L.FAVORITE_SEARCH_TITLE or "Quick Search")
			or (L.QUICK_SEARCH_TITLE or "Quick Search"))
	end
	if panel.quickSearchBox and panel.quickSearchBox.Instructions then
		panel.quickSearchBox.Instructions:SetText(
			panel._favoriteSearchMode
				and (L.FAVORITE_SEARCH_PLACEHOLDER
					or "Search instance names and aliases")
				or (L.QUICK_SEARCH_PLACEHOLDER
					or "Enter an instance name"))
	end
end

local function panelUsesSearchHeader(panel)
	return panel and (panel._quickSearchMode or panel._favoriteSearchMode)
end

local function ensureQuickSearchHeader(panel)
	if not panel or panel.quickSearchHeader then
		return panel and panel.quickSearchHeader
	end
	local insetL, insetR, insetT = flyoutContentInsets()
	local header = CreateFrame("Frame", nil, panel)
	header:SetPoint("TOPLEFT", panel, "TOPLEFT", insetL, -insetT)
	header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -insetR, -insetT)
	header:SetHeight(QUICK_SEARCH_HEADER_HEIGHT)
	header:SetFrameLevel(panel:GetFrameLevel() + 3)

	local title = GF.UI.CreateFontString(header, "OVERLAY", "GameFontNormal")
	local clearSize = GF.NAV_QUICK_SEARCH_CLEAR_SIZE or 22
	local titleInset = clearSize + (GF.NAV_QUICK_SEARCH_CLEAR_GAP or 4)
	title:SetPoint("TOPLEFT", header, "TOPLEFT", titleInset, 0)
	title:SetPoint("TOPRIGHT", header, "TOPRIGHT", -titleInset, 0)
	title:SetHeight(QUICK_SEARCH_TITLE_HEIGHT)
	title:SetJustifyH("CENTER")
	title:SetJustifyV("MIDDLE")
	title:SetTextColor(1, 0.82, 0, 1)
	title._gfFontSizeOverride = 14
	if GF.Font and GF.Font.Track then
		GF.Font.Track(title, "GameFontNormal")
	end

	local clearButton = CreateFrame("Button", nil, header)
	clearButton:SetSize(clearSize, clearSize)
	clearButton:SetPoint("RIGHT", header, "TOPRIGHT", 0, -QUICK_SEARCH_TITLE_HEIGHT / 2)
	clearButton:RegisterForClicks("LeftButtonUp")
	local clearAtlas = GF.NAV_QUICK_SEARCH_CLEAR_ATLAS or "common-icon-delete"
	clearButton:SetNormalAtlas(clearAtlas)
	clearButton:SetHighlightAtlas(clearAtlas, "ADD")
	clearButton:SetPushedAtlas(clearAtlas)
	clearButton:SetDisabledAtlas(clearAtlas)
	clearButton._clearTextures = {
		clearButton:GetNormalTexture(), clearButton:GetHighlightTexture(),
		clearButton:GetPushedTexture(), clearButton:GetDisabledTexture(),
	}
	for _, texture in ipairs(clearButton._clearTextures) do
		texture:ClearAllPoints()
		texture:SetPoint("CENTER", clearButton, "CENTER", 0, 0)
	end
	resetQuickSearchClearButton(clearButton)
	clearButton:SetScript("OnMouseDown", function(button, mouseButton)
		if mouseButton == "LeftButton" and button:IsEnabled() and button._clearTargetShown then
			button._clearRelease = nil
			setQuickSearchClearIconScale(button, GF.NAV_QUICK_SEARCH_CLEAR_PRESSED_SCALE or 0.82)
		end
	end)
	clearButton:SetScript("OnMouseUp", function(button, mouseButton)
		if mouseButton == "LeftButton" then releaseQuickSearchClearButton(button) end
	end)
	clearButton:SetScript("OnClick", function(button)
		if button:IsEnabled() and button._clearTargetShown
			and panel._quickSearchMode and not panel._favoriteSearchMode
			and invoke(presenter(), "ClearQuickSearchHistory", panel)
		then
			if GF.UI and GF.UI.PlayUISound then GF.UI.PlayUISound("check") end
		end
	end)
	clearButton:SetScript("OnEnter", function(button)
		if button:IsEnabled() and GF.UI and GF.UI.BeginGameTooltip and GameTooltip then
			GF.UI.BeginGameTooltip(button, "ANCHOR_RIGHT")
			GameTooltip:SetText((GF.L or {}).QUICK_SEARCH_CLEAR_HISTORY
				or "Clear search history", 1, 0.82, 0, 1, true)
			GameTooltip:Show()
			button._clearTooltipShown = true
		end
	end)
	clearButton:SetScript("OnLeave", function(button)
		hideQuickSearchClearTooltip(button)
		releaseQuickSearchClearButton(button)
	end)
	clearButton:SetScript("OnHide", resetQuickSearchClearButton)
	clearButton:SetScript("OnShow", function() refreshQuickSearchClearButton(panel) end)
	panel.quickSearchClearButton = clearButton

	local dividerTop = createFlyoutGoldenDivider(header, 1)
	dividerTop:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -(QUICK_SEARCH_TITLE_HEIGHT + 1))
	dividerTop:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, -(QUICK_SEARCH_TITLE_HEIGHT + 1))

	local searchBox = CreateFrame("EditBox", nil, header, "SearchBoxTemplate")
	searchBox:SetPoint(
		"TOPLEFT", dividerTop, "BOTTOMLEFT", 0,
		-QUICK_SEARCH_TOP_DIVIDER_TO_BOX_GAP)
	searchBox:SetPoint(
		"TOPRIGHT", dividerTop, "BOTTOMRIGHT", 0,
		-QUICK_SEARCH_TOP_DIVIDER_TO_BOX_GAP)
	searchBox:SetHeight(QUICK_SEARCH_BOX_HEIGHT)
	if GF.UI and GF.UI.StyleBrowseSearchBox then
		GF.UI.StyleBrowseSearchBox(
			searchBox,
			(GF.L or {}).QUICK_SEARCH_PLACEHOLDER or "Enter an instance name")
	end

	local dividerBottom = createFlyoutGoldenDivider(header, 0.7)
	dividerBottom:SetPoint(
		"TOPLEFT", searchBox, "BOTTOMLEFT", 0,
		-QUICK_SEARCH_BOX_TO_BOTTOM_DIVIDER_GAP)
	dividerBottom:SetPoint(
		"TOPRIGHT", searchBox, "BOTTOMRIGHT", 0,
		-QUICK_SEARCH_BOX_TO_BOTTOM_DIVIDER_GAP)

	panel.quickSearchHeader = header
	panel.quickSearchTitle = title
	panel.quickSearchBox = searchBox
	panel.quickSearchDividerTop = dividerTop
	panel.quickSearchDividerBottom = dividerBottom
	searchBox._gfQuickSearchPanel = panel
	searchBox:SetScript("OnTextChanged", function(box)
		if SearchBoxTemplate_OnTextChanged then
			SearchBoxTemplate_OnTextChanged(box)
		end
		local owner = box._gfQuickSearchPanel
		if owner and not owner._suppressQuickSearchTextChanged then
			if owner._favoriteSearchMode then
				NF:RefreshFavoriteSearchPanel(owner, box:GetText() or "")
			else
				NF:RefreshQuickSearchPanel(owner, box:GetText() or "")
			end
		end
	end)
	searchBox:SetScript("OnEscapePressed", function(box)
		if box:GetText() ~= "" then
			box:SetText("")
		else
			box:ClearFocus()
			NF:HideAll()
			invoke(NF.navTree, "Refresh")
		end
	end)
	searchBox:SetScript("OnEnterPressed", function(box)
		box:ClearFocus()
	end)
	refreshQuickSearchHeaderLocale(panel)
	return header
end

local function refreshFavoriteReorderFooterLocale(panel)
	local footer = panel and panel.favoriteReorderFooter
	if not footer then
		return
	end
	local L = GF.L or {}
	footer.hint:SetText(
		L.FAVORITE_INSTANCE_REORDER_HINT
			or "Use arrows to adjust order")
	footer.cancelButton:SetText(L.CANCEL or CANCEL or "Cancel")
	footer.doneButton:SetText(
		L.FAVORITE_INSTANCE_REORDER_DONE or "Confirm")
end

local function ensureFavoriteReorderFooter(panel)
	if not panel or panel.favoriteReorderFooter then
		return panel and panel.favoriteReorderFooter
	end
	local insetL, insetR, _, insetB = flyoutContentInsets()
	local footer = CreateFrame("Frame", nil, panel)
	footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", insetL, insetB)
	footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -insetR, insetB)
	footer:SetHeight(FAVORITE_REORDER_FOOTER_HEIGHT)
	footer:SetFrameLevel(panel:GetFrameLevel() + 4)

	local divider = createFlyoutGoldenDivider(
		footer, FAVORITE_REORDER_DIVIDER_ALPHA)
	divider:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
	divider:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)

	local hint = GF.UI.CreateFontString(footer, "OVERLAY", "GameFontNormalSmall")
	hint:SetPoint(
		"TOPLEFT", divider, "BOTTOMLEFT", 0,
		-FAVORITE_REORDER_HINT_TOP_GAP)
	hint:SetPoint(
		"TOPRIGHT", divider, "BOTTOMRIGHT", 0,
		-FAVORITE_REORDER_HINT_TOP_GAP)
	hint:SetHeight(FAVORITE_REORDER_HINT_HEIGHT)
	hint:SetJustifyH("CENTER")
	hint:SetJustifyV("MIDDLE")
	hint:SetTextColor(0.72, 0.68, 0.55, 1)
	hint:SetWordWrap(false)
	hint._gfFontSizeOverride = 12
	if GF.Font and GF.Font.Track then
		GF.Font.Track(hint, "GameFontNormalSmall")
	end

	local cancelButton = GF.UI.CreatePanelButton(
		footer, "", FAVORITE_REORDER_ACTION_BUTTON_WIDTH)
	cancelButton:SetHeight(FAVORITE_REORDER_ACTION_BUTTON_HEIGHT)
	cancelButton:SetPoint(
		"TOPRIGHT", hint, "BOTTOM",
		-(FAVORITE_REORDER_ACTION_BUTTON_GAP / 2),
		-FAVORITE_REORDER_HINT_BUTTON_GAP)
	local doneButton = GF.UI.CreatePanelButton(
		footer, "", FAVORITE_REORDER_ACTION_BUTTON_WIDTH)
	doneButton:SetHeight(FAVORITE_REORDER_ACTION_BUTTON_HEIGHT)
	doneButton:SetPoint(
		"TOPLEFT", hint, "BOTTOM",
		FAVORITE_REORDER_ACTION_BUTTON_GAP / 2,
		-FAVORITE_REORDER_HINT_BUTTON_GAP)
	doneButton:SetScript("OnClick", function()
		NF:ExitFavoriteReorderMode(true)
	end)
	cancelButton:SetScript("OnClick", function()
		NF:ExitFavoriteReorderMode(false)
	end)

	footer.hint = hint
	footer.doneButton = doneButton
	footer.cancelButton = cancelButton
	panel.favoriteReorderFooter = footer
	refreshFavoriteReorderFooterLocale(panel)
	footer:Hide()
	return footer
end

local function updatePanelModeAnchors(panel)
	if not panel or not panel.scroll then
		return
	end
	if panelUsesSearchHeader(panel) then
		local header = ensureQuickSearchHeader(panel)
		header:Show()
	else
		if panel.quickSearchHeader then
			panel.quickSearchHeader:Hide()
		end
	end
	local footer = panel.favoriteReorderFooter
	if panel._favoriteReorderMode then
		footer = footer or ensureFavoriteReorderFooter(panel)
		footer:Show()
	else
		if footer then
			footer:Hide()
		end
	end
	anchorFlyoutScroll(panel,
		panelUsesSearchHeader(panel) and QUICK_SEARCH_HEADER_HEIGHT or 0,
		panel._favoriteReorderMode and FAVORITE_REORDER_FOOTER_HEIGHT or 0)
end

local function setQuickSearchPanelMode(panel, enabled)
	if not panel then
		return
	end
	if (panel._quickSearchMode == true) == (enabled == true) then return end
	panel._quickSearchMode = enabled == true
	if enabled then
		panel._favoriteSearchMode = nil
	end
	panel._layoutSig = nil
	updatePanelModeAnchors(panel)
end

local function setFavoriteSearchPanelMode(panel, enabled)
	if not panel then
		return
	end
	if (panel._favoriteSearchMode == true) == (enabled == true) then return end
	panel._favoriteSearchMode = enabled == true
	if enabled then
		panel._quickSearchMode = nil
	end
	panel._layoutSig = nil
	updatePanelModeAnchors(panel)
end

local function setFavoriteReorderPanelMode(panel, enabled)
	if not panel then
		return
	end
	if (panel._favoriteReorderMode == true) == (enabled == true) then return end
	panel._favoriteReorderMode = enabled == true
	panel._layoutSig = nil
	updatePanelModeAnchors(panel)
end

function NF:ResolvePanelChildren(panel, children)
	local anchor = panel and panel._anchorRow
	local provider = anchor and anchor._gfNavSelectionProvider
	if provider and provider.GetFlyoutChoices then
		return provider:GetFlyoutChoices(panel._openKey)
	end
	return children or {}
end

function NF:LayoutPanelRows(panel, children, navTree, options)
	options = options or {}
	children = self:ResolvePanelChildren(panel, children)
	local insetL, insetR, insetT, insetB = flyoutContentInsets()
	local width = panelUsesSearchHeader(panel)
		and QUICK_SEARCH_PANEL_WIDTH or resolvePanelWidth(panel, children)
	local contentWidth = math.max(80, width - insetL - insetR)
	local paddingX = flyoutScrollPaddingX()
	local scrollChildWidth = contentWidth + 2 * paddingX
	local signature = panelLayoutSig(navTree, children, contentWidth)
	panel:SetWidth(width)
	panel.panelW = width
	anchorFlyoutScroll(panel,
		panelUsesSearchHeader(panel) and QUICK_SEARCH_HEADER_HEIGHT or 0,
		panel._favoriteReorderMode and FAVORITE_REORDER_FOOTER_HEIGHT or 0)
	if signature == panel._layoutSig then
		-- A refreshed projection can retain identical labels/keys. Always rebind
		-- row targets even when its geometry and visual state are unchanged.
		for index, child in ipairs(children) do
			local row = panel.rows[index]
			if row and row.nodeData ~= child then
				row.nodeData = child
				layoutFlyoutRow(row, child, navTree)
			end
		end
		return false
	end
	panel._layoutSig = signature
	if not options.preservePanel then
		self:BeginPanelLayout(panel)
	end
	panel.content:SetSize(scrollChildWidth, estimatedChildrenHeight(children))

	local offset = 0
	for index, node in ipairs(children) do
		local row = rowForPanel(self, panel, index)
		local rowHeight = flyoutRowHeight(node.level or 1)
		row:SetSize(contentWidth, rowHeight)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", paddingX, -offset)
		row.nodeData = node
		row:Show()
		layoutFlyoutRow(row, node, navTree)
		offset = offset + rowHeight
	end
	self:ReleasePanelRows(panel, #children + 1)
	panel.content:SetSize(scrollChildWidth, math.max(offset, 1))
	panel._fullHeight = offset + insetT + insetB
		+ (panelUsesSearchHeader(panel) and QUICK_SEARCH_HEADER_HEIGHT or 0)
		+ (panel._favoriteReorderMode
			and FAVORITE_REORDER_FOOTER_HEIGHT or 0)
	local visibleHeight = panel._fullHeight
	if panelUsesSearchHeader(panel) then
		visibleHeight = resolveQuickSearchVisibleHeight(
			visibleHeight,
			resolveSecondLevelMaxVisibleHeight(navTree))
	end
	setFlyoutPanelVisibleHeight(panel, visibleHeight, true,
		options.preservePanel and panelUsesSearchHeader(panel))
	return true
end

function NF:PositionPanel(panel, anchorRow, panelIdx)
	local positionIsCurrent = panel._positioned and panel._anchorRow == anchorRow
	if positionIsCurrent then
		return
	end
	local gap = flyoutPanelAnchorGap(panelIdx)
	-- A raid banner opens the existing difficulty level directly, with no
	-- visible ancestor panel. Anchor to the banner, not a hidden old menu.
	local standalone = anchorRow and anchorRow._gfNavStandaloneAnchor == true
	local parentPanel = not standalone and panelIdx and panelIdx > 1 and self.panels
		and self.panels[panelIdx - 1] or nil
	panel:ClearAllPoints()
	if parentPanel and shouldAlignDeepPanelToParentRow(panelIdx) then
		local maxVisibleH = resolveSecondLevelMaxVisibleHeight(self.navTree)
		local visibleH, offsetY = resolveDeepPanelHeightAndOffset(panel, anchorRow, parentPanel, maxVisibleH)
		if visibleH and offsetY then
			setFlyoutPanelVisibleHeight(panel, visibleH, false)
			panel:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", gap, offsetY)
			panel._positioned = true
			return
		end
	end
	local desiredTop
	local rootAnchor
	if not standalone and panelIdx == 1 then
		rootAnchor = resolveRootFlyoutAnchor(self.navTree)
		if rootAnchor then
			desiredTop = rootAnchor.baseTop
		end
	end
	if not standalone and not desiredTop and panelIdx and panelIdx > 1
		and self.panels and self.panels[1] then
		local rootPanel = self.panels[1]
		desiredTop = rootPanel.GetTop and rootPanel:GetTop()
		if desiredTop then
			desiredTop = desiredTop - (flyoutStairStepY() * (panelIdx - 1))
		end
	end
	if not desiredTop then
		desiredTop = anchorRow and anchorRow.GetTop and anchorRow:GetTop()
	end
	local visibleH, resolvedTop
	if standalone then
		local windowTop, windowBottom = getFlyoutWindowBounds()
		visibleH, resolvedTop = resolveDeepPanelVerticalPlacement(
			desiredTop or windowTop, panel._fullHeight or panel:GetHeight() or 1,
			windowBottom, windowTop, 0)
	else
		visibleH, resolvedTop = resolvePanelHeightAndTop(panel, desiredTop)
	end
	if panelUsesSearchHeader(panel) then
		visibleH = resolveQuickSearchVisibleHeight(
			visibleH,
			resolveSecondLevelMaxVisibleHeight(self.navTree))
	end
	setFlyoutPanelVisibleHeight(panel, visibleH, false)
	if standalone then
		local anchorTop = anchorRow.GetTop and anchorRow:GetTop()
		local anchorRight = anchorRow.GetRight and anchorRow:GetRight()
		local divider = self.navTree and self.navTree.dividerHost
		local dividerRight = divider and divider.GetRight and divider:GetRight()
		if anchorRight and dividerRight then
			-- Match the root navigation flyout's horizontal origin. Both menus
			-- already share the same background overhang and border artwork.
			gap = dividerRight - anchorRight + flyoutRootAnchorGapX()
		end
		panel:SetPoint("TOPLEFT", anchorRow, "TOPRIGHT", gap,
			anchorTop and resolvedTop and (resolvedTop - anchorTop) or 0)
		panel._positioned = true
		return
	end
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
	local owner = presenter()
	return owner and owner:PrepareNode(node) or nil
end

function NF:CanRenderPanel(panelIndex)
	return self.panels ~= nil and self.panels[panelIndex] ~= nil
end

function NF:CanRenderOpenFrom(anchorRow, panelIndex)
	local panel = self.panels and self.panels[panelIndex]
	return panel ~= nil and not rowIsDescendantOf(anchorRow, panel)
end

function NF:RenderRefreshQuickSearch(panel, children)
	panel = panel or (self.panels and self.panels[1])
	if not panel then
		return false
	end
	refreshQuickSearchHeaderLocale(panel)
	panel._layoutSig = nil
	self:LayoutPanelRows(panel, children, self.navTree, { preservePanel = true })
	self:RefreshVisibleRows()
	return true
end

function NF:RenderOpenQuickSearch(anchorRow, node, children, query)
	local panel = self.panels and self.panels[1]
	if not panel then
		return false
	end
	panel._openKey, panel._anchorRow = node.key, anchorRow
	panel._quickSearchRoot = node
	panel._quickSearchAnchorRow = anchorRow
	setQuickSearchPanelMode(panel, true)
	refreshQuickSearchHeaderLocale(panel)
	local searchBox = panel.quickSearchBox
	if searchBox and searchBox:GetText() ~= query then
		panel._suppressQuickSearchTextChanged = true
		searchBox:SetText(query)
		panel._suppressQuickSearchTextChanged = nil
	end
	self:BeginPanelLayout(panel)
	self:LayoutPanelRows(panel, children, self.navTree)
	self:PositionPanel(panel, anchorRow, 1)
	panel:Show()
	playFlyoutOpenAnimation(panel, 1)
	self:RefreshVisibleRows()
	if searchBox and searchBox.SetFocus then
		searchBox:SetFocus()
	end
	return true
end

function NF:RenderLocale()
	local panel = self.panels and self.panels[1]
	if not panel then
		return false
	end
	refreshQuickSearchHeaderLocale(panel)
	refreshFavoriteReorderFooterLocale(panel)
	return true
end

function NF:RenderOpenFrom(anchorRow, node, children, panelIndex)
	local panel = panelIndex and self.panels and self.panels[panelIndex]
	if panel == nil then
		return false
	end
	panel._openKey, panel._anchorRow = node.key, anchorRow
	panel._quickSearchRoot, panel._quickSearchAnchorRow = nil, nil
	setQuickSearchPanelMode(panel, false)
	local owner = presenter()
	local favoriteSearchMode = node.favoriteInstancesRoot == true
		and owner and owner.GetFavoriteCount
		and owner:GetFavoriteCount() > 0
		and not owner:IsFavoriteReorderMode()
	setFavoriteSearchPanelMode(panel, favoriteSearchMode)
	local searchBox = panel.quickSearchBox
	if favoriteSearchMode then
		refreshQuickSearchHeaderLocale(panel)
		local query = owner:GetFavoriteSearchQuery()
		if searchBox and searchBox:GetText() ~= query then
			panel._suppressQuickSearchTextChanged = true
			searchBox:SetText(query)
			panel._suppressQuickSearchTextChanged = nil
		end
	end
	self:BeginPanelLayout(panel)
	local laidOut = self:LayoutPanelRows(panel, children, self.navTree, { preservePanel = true })
	self:PositionPanel(panel, anchorRow, panelIndex)
	panel:Show()
	playFlyoutOpenAnimation(panel, panelIndex)
	self:RefreshVisibleRows(laidOut and panel or nil)
	if favoriteSearchMode and searchBox and searchBox.SetFocus then
		searchBox:SetFocus()
	end
	return true
end

function NF:RefreshQuickSearchPanel(panel, query)
	local owner = presenter()
	return owner and owner:RefreshQuickSearchPanel(panel, query) or false
end

function NF:RefreshFavoriteSearchPanel(panel, query)
	local owner = presenter()
	return owner and owner:RefreshFavoriteSearchPanel(panel, query) or false
end

function NF:OpenQuickSearch(anchorRow, node)
	local owner = presenter()
	return owner and owner:OpenQuickSearch(anchorRow, node) or false
end

function NF:RefreshLocale()
	local owner = presenter()
	return owner and owner:RefreshLocale() or self:RenderLocale()
end

function NF:OpenFrom(anchorRow, node)
	local owner = presenter()
	return owner and owner:OpenFrom(anchorRow, node) or false
end

function NF:OpenFromHover(row)
	local owner = presenter()
	return owner and owner:OpenFromHover(row) or false
end

function NF:OnRowClick(row)
	local node = row and row.nodeData
	local provider = node and node._gfNavSelectionProvider
	if provider and provider.SelectFlyoutChoice then
		return provider:SelectFlyoutChoice(node)
	end
	local owner = presenter()
	return owner and owner:ActivateFlyoutRow(row) or false
end

function NF:CancelQuickSearchHover()
	local owner = presenter()
	return owner and owner:CancelQuickSearchHover() or nil
end

function NF:QueueQuickSearchHover(row)
	local owner = presenter()
	return owner and owner:QueueQuickSearchHover(row) or false
end

function NF:RenderRowHover(row, shown)
	setFlyoutHoverShown(row, shown == true)
end

function NF:RenderDisabledTooltip(row)
	return row and showDisabledTooltip(row.hit, row.nodeData, self.navTree)
		or false
end

function NF:HandleRowPointerEnter(row)
	local owner = presenter()
	return owner and owner:HandleRowPointerEnter(row) or false
end

function NF:RenderFavoritePanel(root, children, requestedPanel)
	local panel = requestedPanel or (self.panels and self.panels[1])
	if not (root and panel and self:IsNodeOpen(root)
		and panel.IsShown and panel:IsShown())
	then
		return false
	end
	local owner = presenter()
	local searchEnabled = owner and owner.GetFavoriteCount
		and owner:GetFavoriteCount() > 0
		and not owner:IsFavoriteReorderMode()
	setFavoriteSearchPanelMode(panel, searchEnabled)
	if searchEnabled then
		refreshQuickSearchHeaderLocale(panel)
		local searchBox = panel.quickSearchBox
		local query = owner:GetFavoriteSearchQuery()
		if searchBox and searchBox:GetText() ~= query then
			panel._suppressQuickSearchTextChanged = true
			searchBox:SetText(query)
			panel._suppressQuickSearchTextChanged = nil
		end
	end
	panel._layoutSig = nil
	self:LayoutPanelRows(
		panel,
		children,
		self.navTree,
		{ preservePanel = true })
	self:RefreshVisibleRows()
	return true
end

function NF:RenderFavoriteReorderMode(enabled)
	local panel = self.panels and self.panels[1]
	if panel then
		if enabled then
			setFavoriteSearchPanelMode(panel, false)
		end
		setFavoriteReorderPanelMode(panel, enabled == true)
		panel:EnableKeyboard(enabled == true)
		if enabled and panel.SetPropagateKeyboardInput then
			panel:SetPropagateKeyboardInput(true)
		end
		panel:SetScript("OnKeyDown", enabled and function(owner, key)
			if key == "ESCAPE" then
				if owner.SetPropagateKeyboardInput then
					owner:SetPropagateKeyboardInput(false)
				end
				NF:ExitFavoriteReorderMode(false)
			elseif owner.SetPropagateKeyboardInput then
				owner:SetPropagateKeyboardInput(true)
			end
		end or nil)
	end
	return true
end

function NF:RefreshFavoritePanel(root)
	local owner = presenter()
	return owner and owner:RefreshFavoritePanel(root) or false
end

function NF:EnterFavoriteReorderMode()
	local owner = presenter()
	return owner and owner:EnterFavoriteReorderMode() or false
end

function NF:MoveFavoriteDraft(identity, direction)
	local owner = presenter()
	return owner and owner:MoveFavoriteDraft(identity, direction) or false
end

function NF:ExitFavoriteReorderMode(commit)
	local owner = presenter()
	return owner and owner:ExitFavoriteReorderMode(commit) or false
end

function NF:OpenRowContextMenu(row)
	local navigation = presenter()
	if not navigation or not MenuUtil or not MenuUtil.CreateContextMenu then
		return false
	end
	local node = row and row.nodeData
	local hitTarget = row and row.hit
	if not (node and hitTarget and navigation:CanOpenFavoriteContextMenu(node)) then
		return false
	end
	self:CancelQuickSearchHover()
	self:CloseChildPanelsForRow(row)
	local L = GF.L or {}
	local identity = node.favoriteIdentity
	local motionRegistered = false
	local menu = MenuUtil.CreateContextMenu(hitTarget, function(_, rootDescription)
		rootDescription:SetTag("MENU_GROUPFINDER_FAVORITE_INSTANCE")
		if GF.UI and GF.UI.InstallMenuOpenAnimation then
			motionRegistered = GF.UI.InstallMenuOpenAnimation(
				rootDescription,
				{ preset = "menu", groupFinderOwned = true })
		end
		rootDescription:CreateButton(
			L.FAVORITE_INSTANCE_REMOVE or "Remove",
			function()
				navigation:RemoveFavorite(identity)
			end)
		local reorder = rootDescription:CreateButton(
			L.FAVORITE_INSTANCE_REORDER or "Adjust Order",
			function()
				navigation:EnterFavoriteReorderMode()
			end)
		reorder:SetEnabled(navigation:GetFavoriteCount() > 1)
	end)
	if menu and not motionRegistered
		and GF.UI and GF.UI.PlayPopupOpenAnimation
	then
		GF.UI.PlayPopupOpenAnimation(
			menu,
			{ preset = "menu", groupFinderOwned = true })
	end
	return true
end

local function wireRow(row, flyout)
	local hitTarget = row.hit
	hitTarget:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	hitTarget:SetScript("OnEnter", function()
		flyout:HandleRowPointerEnter(row)
	end)
	hitTarget:SetScript("OnLeave", function()
		-- Quick-search results and cold archive-instance shells share the same
		-- cancellable stable-hover scheduler. Cancelling unconditionally also
		-- prevents a pending row from resolving after recycled-row pointer travel.
		flyout:CancelQuickSearchHover()
		setFlyoutHoverShown(row, false)
		if GameTooltip_Hide then
			GameTooltip_Hide()
		end
	end)
	hitTarget:SetScript("OnClick", function(_, button)
		flyout:CancelQuickSearchHover()
		if row.nodeData and row.nodeData._gfNavSelectionProvider then
			flyout:OnRowClick(row)
			return
		end
		if button == "RightButton" then
			local node = row.nodeData
			if nodeInteractionBlocked(node, flyout.navTree)
				and not (node and node.favoriteResult)
			then
				return
			end
			flyout:OpenRowContextMenu(row)
			return
		end
		local navigation = presenter()
		if navigation and navigation:IsFavoriteReorderMode() then
			return
		end
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
	if row.favoriteIcon then
		row.favoriteIcon:Hide()
	end
	if row.loadingSpinner then
		if GF.UI and GF.UI.StopPendingSpinner then
			GF.UI.StopPendingSpinner(row.loadingSpinner)
		else
			row.loadingSpinner:Hide()
		end
	end
	if row.favoriteMoveUp then
		row.favoriteMoveUp:Hide()
		row.favoriteMoveDown:Hide()
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
	panel:SetScript("OnHide", stopFlyoutHeightAnimation)
	panel:Hide()
	applyFlyoutPanelChrome(panel)

	local scroll = GF.UI.CreateScrollFrame(panel, { rowHeight = GF.NAV_WHEEL_ROW_H or 28 })
	scroll:SetFrameLevel(panel:GetFrameLevel() + 2)
	local content = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(content)
	panel.scroll, panel.content = scroll, content
	anchorFlyoutScroll(panel)
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
	local navigation = presenter()
	if navigation then
		navigation:BindFlyout(self)
	end
	if self.panels then
		self.navTree = navTree
		return
	end

	local poolHost = CreateFrame("Frame", nil, anchorParent)
	poolHost:Hide()
	self.navTree, self.rowPoolHost = navTree, poolHost
	self.freeRows, self.panels = {}, {}

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

function NF:ReanchorOpenPanelPositions()
	if not self.panels then
		return
	end
	for index, panel in ipairs(self.panels) do
		if panel and panel:IsShown() and panel._anchorRow then
			panel._positioned = nil
			self:PositionPanel(panel, panel._anchorRow, index)
		end
	end
end

function NF:CollectOpenPanelDescriptors()
	local descriptors = {}
	for index, panel in ipairs(self.panels or {}) do
		if panel and panel:IsShown() and panel._anchorRow then
			descriptors[#descriptors + 1] = {
				index = index,
				panel = panel,
				anchorRow = panel._anchorRow,
				openKey = panel._openKey,
				quickSearchMode = panel._quickSearchMode == true,
			}
		end
	end
	return descriptors
end

function NF:RenderReanchorOpenPanels(plan)
	for _, item in ipairs(plan or {}) do
		local panel = item.panel
		local owner = presenter()
		local favoriteSearchMode = item.node
			and item.node.favoriteInstancesRoot == true
			and owner and owner.GetFavoriteCount
			and owner:GetFavoriteCount() > 0
			and not owner:IsFavoriteReorderMode()
		setFavoriteSearchPanelMode(panel, favoriteSearchMode)
		if favoriteSearchMode then
			refreshQuickSearchHeaderLocale(panel)
		end
		self:LayoutPanelRows(panel, item.children, self.navTree)
		panel._positioned = nil
		self:PositionPanel(panel, item.anchorRow, item.index)
		panel:Show()
	end
end

function NF:ReanchorOpenPanels()
	local owner = presenter()
	return owner and owner:ReanchorOpenPanels() or false
end
