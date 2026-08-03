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
local ROW_CTX_HIGHLIGHT_TEXTURE = GF.CONTEXT_MENU_HIGHLIGHT_TEXTURE or GF.WHITE_TEXTURE
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
		return false
	end
	local directTell = ChatFrameUtil and ChatFrameUtil.SendTell
	if type(directTell) == "function" then
		directTell(leaderName)
		return true
	end
	if type(ChatFrame_OpenChat) == "function" then
		local command = "/w " .. leaderName .. " "
		ChatFrame_OpenChat(command, SELECTED_DOCK_FRAME)
		return true
	end
	return false
end

local function applyRowFont(button, item)
	local fonts = GF.Font
	if not fonts then
		return
	end
	local template = item and item.isTitle
		and "GameFontNormal" or "GameFontHighlight"
	local apply = fonts.ApplyToContextMenuDropdownButton
		or fonts.ApplyToDropdownButton
	if apply then
		apply(button, template)
	end
end

local function collectVisibleRows(list, initialWidth)
	local rows = {}
	local measuredWidth = initialWidth
	local buttonLimit = _G.UIDROPDOWNMENU_MAXBUTTONS or 8
	for buttonIndex = 1, buttonLimit do
		local buttonName = "DropDownList1Button" .. buttonIndex
		local button = _G[buttonName]
		if button and button:IsShown() then
			local item = RCM.pendingItems and RCM.pendingItems[buttonIndex]
			local text = _G[buttonName .. "NormalText"]
			applyRowFont(button, item)
			applyMenuTextColor(text, item)
			if text then
				text:SetWordWrap(false)
				text:SetMaxLines(1)
				local textWidth = tonumber(text:GetStringWidth()) or 0
				measuredWidth = math.max(measuredWidth,
					math.ceil(textWidth) + ROW_CTX_TEXT_W_PAD)
			end
			rows[#rows + 1] = {
				button = button,
				buttonIndex = buttonIndex,
				item = item,
				text = text,
			}
		end
	end
	return rows, measuredWidth
end

local function placeMenuRow(list, row, width, topOffset)
	local button = row.button
	local item = row.item
	local height = item and item.isTitle
		and ROW_CTX_TITLE_ROW_H or ROW_CTX_ROW_H
	local _, _, _, existingX = button:GetPoint(1)
	local leftOffset = existingX or 17
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", leftOffset, topOffset)
	button:SetSize(width, height)
	button._gfContextMenuStyled = true
	button._gfContextMenuNoHover = item and (item.isTitle or item.disabled) or false
	snapshotContextMenuButtonVisual(list, button)
	if button.Highlight and button.Highlight.SetAlpha then
		button.Highlight:SetAlpha(0)
	end
	layoutContextMenuHighlight(button, width, height)
	setContextMenuHighlightShown(button, false)
	if row.text then
		row.text:SetWordWrap(false)
		row.text:SetMaxLines(1)
		row.text:SetWidth(width - ROW_CTX_TEXT_W_PAD)
	end
	return height
end

local function clampMenuWidth()
	local list = _G.DropDownList1
	if not (list and list:IsShown()) then
		return
	end
	local fonts = GF.Font
	if fonts and fonts.BeginContextDropdownFonts then
		fonts.BeginContextDropdownFonts(list)
	end
	local options = RCM.pendingOptions or {}
	local requestedMinimum = tonumber(options.minWidth) or ROW_CTX_MENU_MIN_W
	local minimum = math.min(ROW_CTX_MENU_MAX_W,
		math.max(ROW_CTX_MENU_MIN_W, requestedMinimum))
	local rows, measured = collectVisibleRows(list, minimum)
	local maxAllowed = tonumber(options.maxWidth) or ROW_CTX_MENU_MAX_W
	local maxWidth = math.min(measured, maxAllowed)
	list:SetWidth(maxWidth + ROW_CTX_CHROME_W)
	local cursorY = -ROW_CTX_TOP_GAP
	local contentHeight = 0
	for rowIndex = 1, #rows do
		local row = rows[rowIndex]
		local rowHeight = placeMenuRow(list, row, maxWidth, cursorY)
		local gap = buttonExtraAfter[row.buttonIndex] or 0
		cursorY = cursorY - rowHeight - gap
		contentHeight = contentHeight + rowHeight + gap
	end
	list:SetHeight(contentHeight + ROW_CTX_TOP_GAP + ROW_CTX_BOTTOM_GAP)
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

local function dropdownApiAvailable()
	return type(UIDropDownMenu_Initialize) == "function"
		and type(ToggleDropDownMenu) == "function"
		and type(UIDropDownMenu_CreateInfo) == "function"
		and type(UIDropDownMenu_AddButton) == "function"
end

local function populateDropdown(_, level)
	buttonExtraAfter = {}
	local entries = RCM.pendingItems or {}
	for entryIndex = 1, #entries do
		local entry = entries[entryIndex]
		local descriptor = UIDropDownMenu_CreateInfo()
		descriptor.text = entry.text
		descriptor.notCheckable = true
		descriptor.leftPadding = 2
		descriptor.topPadding = 0
		if entry.icon then
			descriptor.icon = entry.icon
			descriptor.iconXOffset = entry.iconXOffset
		end
		if entry.isTitle then
			descriptor.isTitle = true
			descriptor.notClickable = true
			descriptor.disabled = true
			buttonExtraAfter[entryIndex] = ROW_CTX_TITLE_BOTTOM_GAP
		else
			descriptor.func = entry.func
			descriptor.disabled = entry.disabled
		end
		UIDropDownMenu_AddButton(descriptor, level)
	end
end

local function ensureDropdownFrame()
	if not RCM.dropdown then
		RCM.dropdown = CreateFrame("Frame", "GroupFinderAddonRowContextMenu",
			UIParent, "UIDropDownMenuTemplate")
	end
	return RCM.dropdown
end

local function applyDropdownAnchor(frame, options)
	options = options or {}
	frame.point = options.point
	frame.relativePoint = options.relativePoint
	frame.relativeTo = options.relativeTo
	frame.xOffset = options.xOffset
	frame.yOffset = options.yOffset
	return options.anchorFrame or "cursor",
		type(options.xOffset) == "number" and options.xOffset or 0,
		type(options.yOffset) == "number" and options.yOffset or 0
end

function RCM:ShowMenu(menuItems, options)
	if not dropdownApiAvailable() then
		local onClose = options and options.onClose
		if type(onClose) == "function" then
			onClose()
		end
		return
	end
	local menuFrame = ensureDropdownFrame()
	if type(CloseMenus) == "function" then
		CloseMenus()
	end
	RCM.pendingItems = menuItems
	RCM.pendingOptions = options or {}
	RCM.pendingOnClose = options and options.onClose
	UIDropDownMenu_Initialize(menuFrame, populateDropdown, "MENU")
	local list = _G.DropDownList1
	ensureMenuHideHook(list)
	menuFrame.listFrameOnShow = clampMenuWidth
	local anchor, offsetX, offsetY = applyDropdownAnchor(menuFrame, options)
	ToggleDropDownMenu(1, nil, menuFrame, anchor, offsetX, offsetY)
	clampMenuWidth()
end

local function appendMenuItem(items, item)
	items[#items + 1] = item
end

local function canCopyCharacterName(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if type(issecretvalue) == "function" and issecretvalue(name) then
		return false
	end
	return GF.UI and type(GF.UI.ShowCharacterNameCopyDialog) == "function"
end

local function blocklistIsEnabled()
	local blocklist = GF.Blocklist
	local query = blocklist and blocklist.IsEnabled
	return type(query) == "function" and query(blocklist) == true
end

function RCM:BuildMenuItems(row, index, resultID, info)
	local L = GF.L or {}
	local displayTitle = getRowDisplayTitle(row)
	local titleText = displayTitle or (row and row._titleText) or info.name or "?"
	local leaderName = info.leaderName
	local apply = GF.Apply
	local selectionAllowed = not (apply and apply.CanSelectRow)
		or apply:CanSelectRow(index, resultID) == true
	local copyAllowed = canCopyCharacterName(leaderName)
	local items = {}
	appendMenuItem(items, { isTitle = true, text = titleText })
	appendMenuItem(items, {
		text = L.SIGN_UP or "Sign Up",
		textColor = ROW_CTX_SIGN_UP_COLOR,
		disabled = not selectionAllowed,
		func = function()
			local show = GF.Apply and GF.Apply.ShowDialogForIndex
			if show then
				show(GF.Apply, index, resultID)
			end
		end,
	})
	appendMenuItem(items, {
		text = L.CTX_WHISPER_LEADER or WHISPER_LEADER or "Whisper leader",
		disabled = not leaderName,
		func = function() whisperLeader(leaderName) end,
	})
	appendMenuItem(items, {
		text = L.CTX_COPY_LEADER_NAME or "复制队长名称",
		disabled = not copyAllowed,
		func = function()
			if copyAllowed then
				GF.UI.ShowCharacterNameCopyDialog(leaderName)
			end
		end,
	})
	if blocklistIsEnabled() then
		appendMenuItem(items, {
			text = L.CTX_BLOCK_LEADER or "Block leader",
			disabled = not leaderName,
			func = function()
				GF.Blocklist:BlockLeaderFromSearchResult(resultID, info)
			end,
		})
		appendMenuItem(items, {
			text = L.CTX_BLOCK_TITLE or "Block same-title group",
			disabled = not leaderName,
			func = function()
				GF.Blocklist:BlockSameTitleFromSearchResult(resultID, info, displayTitle)
			end,
		})
	end
	if type(LFGList_ReportListing) == "function" then
		appendMenuItem(items, {
			text = L.CTX_REPORT or LFG_LIST_REPORT_GROUP_FOR or "Report",
			func = function()
				LFGList_ReportListing(resultID, leaderName)
			end,
		})
	end
	if type(LFGList_ReportAdvertisement) == "function" then
		appendMenuItem(items, {
			text = L.CTX_REPORT_ADVERTISEMENT or "Report advertisement",
			func = function()
				LFGList_ReportAdvertisement(resultID)
				if blocklistIsEnabled() then
					GF.Blocklist:BlockAdvertisementFromSearchResult(resultID, info)
				end
			end,
		})
	end
	appendMenuItem(items, {
		text = L.CANCEL or "Cancel",
		func = closeMenu,
	})
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
