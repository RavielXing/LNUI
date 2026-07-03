local _, GF = ...

GF.RowContextMenu = {}
local RCM = GF.RowContextMenu

local ROW_CTX_MENU_MIN_W = GF.CONTEXT_MENU_MIN_W or 140
local ROW_CTX_MENU_MAX_W = GF.CONTEXT_MENU_MAX_W or 280
local ROW_CTX_ROW_H = GF.CONTEXT_MENU_ROW_H or 28
local ROW_CTX_TITLE_ROW_H = GF.CONTEXT_MENU_TITLE_ROW_H or ROW_CTX_ROW_H
local ROW_CTX_TITLE_BOTTOM_GAP = GF.CONTEXT_MENU_TITLE_BOTTOM_GAP or 4
local ROW_CTX_TOP_GAP = GF.CONTEXT_MENU_TOP_GAP or 10
local ROW_CTX_BOTTOM_GAP = GF.CONTEXT_MENU_BOTTOM_GAP or 10
local ROW_CTX_CHROME_W = GF.CONTEXT_MENU_CHROME_W or 25
local ROW_CTX_TEXT_W_PAD = GF.CONTEXT_MENU_TEXT_W_PAD or 32
local ROW_CTX_HIGHLIGHT_TEXTURE = GF.CONTEXT_MENU_HIGHLIGHT_TEXTURE or "Interface\\Buttons\\WHITE8X8"
local ROW_CTX_HIGHLIGHT_TEXTURE_W = GF.CONTEXT_MENU_HIGHLIGHT_TEXTURE_W or 1
local ROW_CTX_HIGHLIGHT_TEXTURE_H = GF.CONTEXT_MENU_HIGHLIGHT_TEXTURE_H or 1
local ROW_CTX_HIGHLIGHT_CAP_W = GF.CONTEXT_MENU_HIGHLIGHT_CAP_W or 1
local ROW_CTX_HIGHLIGHT_INSET_X = GF.CONTEXT_MENU_HIGHLIGHT_INSET_X or 2
local ROW_CTX_HIGHLIGHT_EXTEND_X = GF.CONTEXT_MENU_HIGHLIGHT_EXTEND_X or 8
local ROW_CTX_HIGHLIGHT_OFFSET_X = GF.CONTEXT_MENU_HIGHLIGHT_OFFSET_X or 0
local ROW_CTX_HIGHLIGHT_ALPHA = GF.CONTEXT_MENU_HIGHLIGHT_ALPHA or 1
local ROW_CTX_HIGHLIGHT_COLOR = GF.CONTEXT_MENU_HIGHLIGHT_COLOR or { 1, 0.74, 0.18, 0.18 }
local ROW_CTX_TITLE_COLOR = { 1, 0.82, 0, 1 }
local ROW_CTX_NORMAL_COLOR = { 1, 1, 1, 1 }
local ROW_CTX_DISABLED_COLOR = { 0.5, 0.5, 0.5, 1 }
local ROW_CTX_SIGN_UP_COLOR = { 0, 1, 0, 1 }

local buttonExtraAfter = {}

local function setContextMenuHighlightShown(button, shown)
	if not button or not button._gfContextMenuHighlightParts then
		return
	end
	shown = shown == true and not button._gfContextMenuNoHover
	for _, tex in ipairs(button._gfContextMenuHighlightParts) do
		tex:SetShown(shown)
	end
end

local function ensureContextMenuHighlightParts(button)
	if not button then
		return nil
	end
	if not button._gfContextMenuHighlightParts then
		local left = button:CreateTexture(nil, "BACKGROUND", nil, 1)
		local mid = button:CreateTexture(nil, "BACKGROUND", nil, 1)
		local right = button:CreateTexture(nil, "BACKGROUND", nil, 1)
		button._gfContextMenuHighlightParts = { left, mid, right }
		button._gfContextMenuHighlightLeft = left
		button._gfContextMenuHighlightMid = mid
		button._gfContextMenuHighlightRight = right
		for _, tex in ipairs(button._gfContextMenuHighlightParts) do
			tex:SetTexture(ROW_CTX_HIGHLIGHT_TEXTURE)
			if tex.SetBlendMode then
				tex:SetBlendMode("BLEND")
			end
			tex:SetVertexColor(
				ROW_CTX_HIGHLIGHT_COLOR[1] or 1,
				ROW_CTX_HIGHLIGHT_COLOR[2] or 1,
				ROW_CTX_HIGHLIGHT_COLOR[3] or 1,
				ROW_CTX_HIGHLIGHT_COLOR[4] or 1
			)
			tex:SetAlpha(ROW_CTX_HIGHLIGHT_ALPHA)
			tex:Hide()
		end
	end
	if not button._gfContextMenuHighlightHooked then
		button._gfContextMenuHighlightHooked = true
		button:HookScript("OnEnter", function(self)
			if self._gfContextMenuStyled then
				setContextMenuHighlightShown(self, true)
			end
		end)
		button:HookScript("OnLeave", function(self)
			if self._gfContextMenuStyled then
				setContextMenuHighlightShown(self, false)
			end
		end)
	end
	return button._gfContextMenuHighlightParts
end

local function layoutContextMenuHighlight(button, width, height)
	local parts = ensureContextMenuHighlightParts(button)
	if not parts then
		return
	end
	width = math.max(width or 1, 1)
	height = math.max(height or ROW_CTX_ROW_H, 1)
	local hlW = math.max(1, width - (ROW_CTX_HIGHLIGHT_INSET_X * 2) + (ROW_CTX_HIGHLIGHT_EXTEND_X * 2))
	local offsetX = ROW_CTX_HIGHLIGHT_INSET_X - ROW_CTX_HIGHLIGHT_EXTEND_X + ROW_CTX_HIGHLIGHT_OFFSET_X
	local capSrcW = math.min(ROW_CTX_HIGHLIGHT_CAP_W, ROW_CTX_HIGHLIGHT_TEXTURE_W * 0.45)
	local capUV = capSrcW / ROW_CTX_HIGHLIGHT_TEXTURE_W
	local capW = math.max(1, math.min(capSrcW * (height / ROW_CTX_HIGHLIGHT_TEXTURE_H), hlW * 0.5))
	local left = button._gfContextMenuHighlightLeft
	local mid = button._gfContextMenuHighlightMid
	local right = button._gfContextMenuHighlightRight
	for _, tex in ipairs(parts) do
		tex:SetTexture(ROW_CTX_HIGHLIGHT_TEXTURE)
		tex:SetAlpha(ROW_CTX_HIGHLIGHT_ALPHA)
		tex:SetVertexColor(
			ROW_CTX_HIGHLIGHT_COLOR[1] or 1,
			ROW_CTX_HIGHLIGHT_COLOR[2] or 1,
			ROW_CTX_HIGHLIGHT_COLOR[3] or 1,
			ROW_CTX_HIGHLIGHT_COLOR[4] or 1
		)
	end
	left:ClearAllPoints()
	left:SetPoint("LEFT", button, "LEFT", offsetX, 0)
	left:SetSize(capW, height)
	left:SetTexCoord(0, capUV, 0, 1)
	right:ClearAllPoints()
	right:SetPoint("RIGHT", button, "LEFT", offsetX + hlW, 0)
	right:SetSize(capW, height)
	right:SetTexCoord(1 - capUV, 1, 0, 1)
	mid:ClearAllPoints()
	mid:SetPoint("LEFT", left, "RIGHT", 0, 0)
	mid:SetPoint("RIGHT", right, "LEFT", 0, 0)
	mid:SetHeight(height)
	mid:SetTexCoord(capUV, 1 - capUV, 0, 1)
end

local function snapshotContextMenuButtonVisual(list, button)
	if not list or not button then
		return
	end
	if not list._gfContextMenuHighlightSnapshots then
		list._gfContextMenuHighlightSnapshots = {}
	end
	if list._gfContextMenuHighlightSnapshots[button] then
		return
	end
	local highlight = button.Highlight
	if not highlight then
		local name = button.GetName and button:GetName()
		highlight = name and _G[name .. "Highlight"]
	end
	list._gfContextMenuHighlightSnapshots[button] = {
		highlight = highlight,
		alpha = highlight and highlight.GetAlpha and highlight:GetAlpha() or nil,
	}
end

local function restoreContextMenuVisuals(list)
	local snapshots = list and list._gfContextMenuHighlightSnapshots
	if not snapshots then
		return
	end
	for button, state in pairs(snapshots) do
		if button then
			button._gfContextMenuStyled = nil
			button._gfContextMenuNoHover = nil
			setContextMenuHighlightShown(button, false)
		end
		local highlight = state and state.highlight
		if highlight and highlight.SetAlpha and state.alpha then
			highlight:SetAlpha(state.alpha)
		end
	end
	list._gfContextMenuHighlightSnapshots = nil
end

local function finishPendingMenu()
	restoreContextMenuVisuals(_G.DropDownList1)
	local onClose = RCM.pendingOnClose
	RCM.pendingOnClose = nil
	RCM.pendingItems = nil
	RCM.pendingOptions = nil
	if onClose then
		onClose()
	end
end

local function ensureMenuHideHook(list)
	if not list or list._gfRowContextMenuHideHooked then
		return
	end
	list._gfRowContextMenuHideHooked = true
	list:HookScript("OnHide", finishPendingMenu)
end

local function applyMenuTextColor(text, item)
	if not text or not text.SetTextColor then
		return
	end
	local color
	if item and item.disabled then
		color = ROW_CTX_DISABLED_COLOR
	elseif item and item.textColor then
		color = item.textColor
	elseif item and item.isTitle then
		color = ROW_CTX_TITLE_COLOR
	else
		color = ROW_CTX_NORMAL_COLOR
	end
	text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function whisperLeader(leaderName)
	if type(leaderName) ~= "string" or leaderName == "" then
		return
	end
	if ChatFrameUtil and ChatFrameUtil.SendTell then
		ChatFrameUtil.SendTell(leaderName)
	elseif ChatFrame_OpenChat then
		ChatFrame_OpenChat("/w " .. leaderName .. " ", SELECTED_DOCK_FRAME)
	end
end

local function clampMenuWidth()
	local list = _G.DropDownList1
	if not list or not list:IsShown() then
		return
	end
	if GF.Font and GF.Font.BeginContextDropdownFonts then
		GF.Font.BeginContextDropdownFonts(list)
	end
	local options = RCM.pendingOptions or {}
	local y = -ROW_CTX_TOP_GAP
	local contentH = 0
	local maxWidth = math.min(math.max(options.minWidth or ROW_CTX_MENU_MIN_W, ROW_CTX_MENU_MIN_W), ROW_CTX_MENU_MAX_W)
	local rows = {}
	for i = 1, _G.UIDROPDOWNMENU_MAXBUTTONS or 8 do
		local btn = _G["DropDownList1Button" .. i]
		if btn and btn:IsShown() then
			local item = RCM.pendingItems and RCM.pendingItems[i]
			local text = _G["DropDownList1Button" .. i .. "NormalText"]
			if GF.Font then
				local template = item and item.isTitle and "GameFontNormal" or "GameFontHighlight"
				if GF.Font.ApplyToContextMenuDropdownButton then
					GF.Font.ApplyToContextMenuDropdownButton(btn, template)
				elseif GF.Font.ApplyToDropdownButton then
					GF.Font.ApplyToDropdownButton(btn, template)
				end
			end
			applyMenuTextColor(text, item)
			if text then
				text:SetWordWrap(false)
				text:SetMaxLines(1)
				local textW = text:GetStringWidth()
				if textW and textW > 0 then
					maxWidth = math.max(maxWidth, math.ceil(textW) + ROW_CTX_TEXT_W_PAD)
				end
			end
			rows[#rows + 1] = { button = btn, text = text, item = item }
		end
	end
	maxWidth = math.min(maxWidth, options.maxWidth or ROW_CTX_MENU_MAX_W)
	list:SetWidth(maxWidth + ROW_CTX_CHROME_W)
	for idx, row in ipairs(rows) do
		local btn = row.button
		local item = row.item
		local rowH = item and item.isTitle and ROW_CTX_TITLE_ROW_H or ROW_CTX_ROW_H
		local x = 17
		local _, _, _, curX = btn:GetPoint(1)
		if curX then
			x = curX
		end
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", btn:GetParent(), "TOPLEFT", x, y)
		btn:SetHeight(rowH)
		btn:SetWidth(maxWidth)
		btn._gfContextMenuStyled = true
		btn._gfContextMenuNoHover = item and (item.isTitle or item.disabled) or false
		snapshotContextMenuButtonVisual(list, btn)
		if btn.Highlight and btn.Highlight.SetAlpha then
			btn.Highlight:SetAlpha(0)
		end
		layoutContextMenuHighlight(btn, maxWidth, rowH)
		setContextMenuHighlightShown(btn, false)
		if row.text then
			row.text:SetWordWrap(false)
			row.text:SetMaxLines(1)
			row.text:SetWidth(maxWidth - ROW_CTX_TEXT_W_PAD)
		end
		y = y - rowH
		contentH = contentH + rowH
		local extraAfter = buttonExtraAfter[idx] or 0
		if extraAfter > 0 then
			y = y - extraAfter
			contentH = contentH + extraAfter
		end
	end
	list:SetHeight(contentH + ROW_CTX_TOP_GAP + ROW_CTX_BOTTOM_GAP)
end

local function closeMenu()
	if CloseMenus then
		CloseMenus()
	end
end

local function getRowDisplayTitle(row)
	local text = row and row.title and row.title.GetText and row.title:GetText()
	if text and text ~= "" then
		return text
	end
	text = row and row._titleText
	if text and text ~= "" then
		return text
	end
	return nil
end

function RCM:ShowMenu(menuItems, options)
	if not (UIDropDownMenu_Initialize and ToggleDropDownMenu and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton) then
		if options and options.onClose then
			options.onClose()
		end
		return
	end
	local menuFrame = RCM.dropdown or CreateFrame("Frame", "GroupFinderAddonRowContextMenu", UIParent, "UIDropDownMenuTemplate")
	RCM.dropdown = menuFrame
	if CloseMenus then
		CloseMenus()
	end
	RCM.pendingItems = menuItems
	RCM.pendingOptions = options or {}
	RCM.pendingOnClose = options and options.onClose or nil
	local function initialize(_, level)
		local pending = RCM.pendingItems or {}
		buttonExtraAfter = {}
		for idx, item in ipairs(pending) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = item.text
			info.notCheckable = true
			info.leftPadding = 2
			info.topPadding = 0
			if item.icon then
				info.icon = item.icon
				info.iconXOffset = item.iconXOffset
			end
			if item.isTitle then
				info.isTitle = true
				info.notClickable = true
				info.disabled = true
				buttonExtraAfter[idx] = ROW_CTX_TITLE_BOTTOM_GAP
			else
				info.func = item.func
				info.disabled = item.disabled
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end
	UIDropDownMenu_Initialize(menuFrame, initialize, "MENU")
	local list = _G.DropDownList1
	if list then
		ensureMenuHideHook(list)
	end
	menuFrame.listFrameOnShow = clampMenuWidth
	menuFrame.point = options and options.point or nil
	menuFrame.relativePoint = options and options.relativePoint or nil
	menuFrame.relativeTo = options and options.relativeTo or nil
	menuFrame.xOffset = options and options.xOffset or nil
	menuFrame.yOffset = options and options.yOffset or nil
	local anchor = options and options.anchorFrame or "cursor"
	ToggleDropDownMenu(1, nil, menuFrame, anchor, options and options.xOffset or 0, options and options.yOffset or 0)
	clampMenuWidth()
end

function RCM:BuildMenuItems(row, index, resultID, info)
	local L = GF.L or {}
	local displayTitle = getRowDisplayTitle(row)
	local titleText = displayTitle or (row and row._titleText) or info.name or "?"
	local canApply = true
	if GF.Apply and GF.Apply.CanSelectRow then
		canApply = GF.Apply:CanSelectRow(index, resultID) == true
	end
	local items = {
		{
			isTitle = true,
			text = titleText,
		},
		{
			text = L.SIGN_UP or "Sign Up",
			textColor = ROW_CTX_SIGN_UP_COLOR,
			disabled = not canApply,
			func = function()
				if GF.Apply and GF.Apply.ShowDialogForIndex then
					GF.Apply:ShowDialogForIndex(index, resultID)
				end
			end,
		},
		{
			text = L.CTX_WHISPER_LEADER or WHISPER_LEADER or "Whisper leader",
			disabled = not info.leaderName,
			func = function()
				whisperLeader(info.leaderName)
			end,
		},
	}
	if GF.Blocklist and GF.Blocklist.IsEnabled and GF.Blocklist:IsEnabled() then
		items[#items + 1] = {
			text = L.CTX_BLOCK_LEADER or "Block leader",
			disabled = not info.leaderName,
			func = function()
				GF.Blocklist:BlockLeaderFromSearchResult(resultID, info)
			end,
		}
		items[#items + 1] = {
			text = L.CTX_BLOCK_TITLE or "Block same-title group",
			disabled = not info.leaderName,
			func = function()
				GF.Blocklist:BlockSameTitleFromSearchResult(resultID, info, displayTitle)
			end,
		}
	end
	if LFGList_ReportListing then
		items[#items + 1] = {
			text = L.CTX_REPORT or LFG_LIST_REPORT_GROUP_FOR or "Report",
			func = function()
				LFGList_ReportListing(resultID, info.leaderName)
			end,
		}
	end
	if LFGList_ReportAdvertisement then
		items[#items + 1] = {
			text = L.CTX_REPORT_ADVERTISEMENT or "Report advertisement",
			func = function()
				LFGList_ReportAdvertisement(resultID)
				if GF.Blocklist and GF.Blocklist.IsEnabled and GF.Blocklist:IsEnabled() then
					GF.Blocklist:BlockAdvertisementFromSearchResult(resultID, info)
				end
			end,
		}
	end
	items[#items + 1] = {
		text = L.CANCEL or "Cancel",
		func = closeMenu,
	}
	return items
end

function RCM:ShowForRow(row)
	if not row or not row.resultIndex then
		return
	end
	if GF.FindGroupTab and GF.FindGroupTab.SetSelectedRow then
		GF.FindGroupTab:SetSelectedRow(row)
	end
	local index = row.resultIndex
	local resultID = row.resultID or GF.Result:GetResultID(index)
	if not resultID then
		return
	end
	if GF.Apply and GF.Apply.ResolveApplyTarget then
		local resolvedIndex, resolvedID = GF.Apply:ResolveApplyTarget(index, resultID)
		if not resolvedIndex or not resolvedID then
			return
		end
		index, resultID = resolvedIndex, resolvedID
	end
	local info = GF.Result and GF.Result.GetAuthoritativeSearchResultInfo
		and GF.Result:GetAuthoritativeSearchResultInfo(resultID)
	if not info and C_LFGList and C_LFGList.GetSearchResultInfo then
		info = C_LFGList.GetSearchResultInfo(resultID)
	end
	if not info then
		return
	end
	self:ShowMenu(self:BuildMenuItems(row, index, resultID, info))
end
