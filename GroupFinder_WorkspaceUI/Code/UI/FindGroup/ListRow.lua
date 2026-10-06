local _, GF = ...
GF = GF.GF or GF

local APPLICATION_TIMEOUT_SECONDS = 5 * 60
local APPLICATION_PENDING_TEXT_COLOR = { r = 0.12, g = 1, b = 0.25, a = 1 }
local APPLICATION_DECLINED_TEXT_COLOR = { r = 1, g = 0.18, b = 0.12, a = 1 }
local APPLICATION_CANCELLED_TEXT_COLOR = { r = 0.55, g = 0.55, b = 0.55, a = 1 }
local APPLICATION_ALERT_ICON_TEXTURE = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew.blp"
local APPLICATION_CANCEL_BUTTON_SIZE = GF.COMMON_BUTTON_STYLE.iconButtonSize
local APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE = APPLICATION_CANCEL_BUTTON_SIZE
local APPLICATION_CANCEL_BUTTON_ICON_SIZE = GF.COMMON_BUTTON_STYLE.iconSize
local APPLICATION_CANCEL_BUTTON_GAP = 4
local APPLICATION_CANCEL_BUTTON_ATLAS = GF.APPLICANT_DECLINE_ICON_ATLAS
local APPLICATION_STATUS_ICON_SIZE = 16
local APPLICATION_STATUS_ICON_GAP = 3
local APPLICATION_PENDING_SPINNER_SIZE = 18
local TEXT_STYLE = GF.BROWSE_ROW_TEXT_STYLE or {
	title = { r = 1, g = 0.82, b = 0 },
	activity = { r = 1, g = 0.82, b = 0 },
	comment = { r = 1, g = 1, b = 1 },
	itemLevel = { r = 0.1, g = 1, b = 0.1 },
}
local lastTooltipResultID
local cancelHoverTooltipHide
local hideApplicationCountdown

local function getTextStyle()
	local scheme = GF.GetTeamListColorScheme and GF.GetTeamListColorScheme()
	return (GF.BROWSE_ROW_TEXT_STYLES and GF.BROWSE_ROW_TEXT_STYLES[scheme])
		or TEXT_STYLE
end

local function presentationPort()
	return GF.ResultPresentationPort
end

local function clearReusableTable(values)
	values = type(values) == "table" and values or {}
	for key in pairs(values) do
		values[key] = nil
	end
	return values
end

local function rowPresentationOptions(row, source)
	local options = row._gfRowPresentationOptions or {}
	row._gfRowPresentationOptions = options
	source = type(source) == "table" and source or {}
	options.resultID = source.resultID
	options.deferRoles = source.deferRoles
	options.currentGroupProjection = source.currentGroupProjection
	options.displayComment = source.displayComment
	options.displayVoiceChat = source.displayVoiceChat
	options.displayVoiceShown = source.displayVoiceShown
	options.displayCommentProvided = source.displayCommentProvided
	options.displayVoiceChatProvided = source.displayVoiceChatProvided
	options.displayVoiceShownProvided = source.displayVoiceShownProvided
	return options
end

local function buildRowPresentation(row, port, index, categoryID, entry, source)
	if not (row and port and type(port.BuildRowPresentation) == "function") then
		return nil
	end
	local reusable = row._gfRowPresentation or {}
	row._gfRowPresentation = reusable
	return port:BuildRowPresentation(
		index,
		categoryID,
		entry,
		rowPresentationOptions(row, source),
		reusable
	)
end

local function trySetTextureAtlas(texture, atlas)
	if not texture or not texture.SetAtlas or not atlas then
		return false
	end
	local ok = pcall(texture.SetAtlas, texture, atlas)
	return ok == true
end

local function CreateApplicationPendingSpinner(parent)
	if GF.UI and GF.UI.CreatePendingSpinner then
		return GF.UI.CreatePendingSpinner(parent, APPLICATION_PENDING_SPINNER_SIZE)
	end
end

local function StopApplicationPendingSpinner(spinner)
	if GF.UI and GF.UI.StopPendingSpinner then
		GF.UI.StopPendingSpinner(spinner)
	end
end

local function StartApplicationPendingSpinner(spinner)
	if GF.UI and GF.UI.StartPendingSpinner then
		GF.UI.StartPendingSpinner(spinner, APPLICATION_PENDING_SPINNER_SIZE)
	end
end

local function StopApplicationFeedbackTimer(row)
	if row._appFeedbackTimer then row._appFeedbackTimer:Cancel() end
	row._appFeedbackTimer, row._appFeedbackRequest = nil, nil
end

local function UpdateApplicationCancelButtonState(button)
	GF.UI.RefreshCommonTitleActionButtonSkin(button)
end

local function CreateApplicationCancelButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(APPLICATION_CANCEL_BUTTON_SIZE, APPLICATION_CANCEL_BUTTON_SIZE)
	button:SetFrameLevel((parent:GetFrameLevel() or 1) + 4)
	button:SetPoint("CENTER", parent, "CENTER", 0, 0)
	button:RegisterForClicks("LeftButtonUp")
	button:SetText("")
	button:Hide()
	local label = button.Text or (button.GetFontString and button:GetFontString())
	if label then
		label:SetText("")
		label:Hide()
	end

	local icon = button:CreateTexture(nil, "OVERLAY", nil, 2)
	icon:SetSize(APPLICATION_CANCEL_BUTTON_ICON_SIZE, APPLICATION_CANCEL_BUTTON_ICON_SIZE)
	icon:SetVertexColor(1, 1, 1, 1)
	if not trySetTextureAtlas(icon, APPLICATION_CANCEL_BUTTON_ATLAS) then
		icon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
		icon:SetTexCoord(0, 1, 0, 1)
	end
	button._gfCancelIcon = icon
	button:SetScript("OnEnter", function(self)
		self._gfCancelHovered = true
		UpdateApplicationCancelButtonState(self)
		if GF.ListRow and GF.ListRow.ClearHoverTooltip then
			GF.ListRow:ClearHoverTooltip()
		end
		local L = GF.L or {}
		if GameTooltip then
			GameTooltip:Hide()
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self._gfCancelReason == "unempowered"
				and (L.APPLY_CANCEL_NO_PERMISSION or "无权取消")
				or (L.APPLY_CANCEL_APPLICATION or LFG_LIST_CANCEL_APPLICATION or "取消申请"))
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		self._gfCancelHovered = nil
		UpdateApplicationCancelButtonState(self)
		if GameTooltip and GameTooltip.GetOwner then
			if GameTooltip:GetOwner() == self then
				GameTooltip:Hide()
			end
		elseif GameTooltip_Hide then
			GameTooltip_Hide()
		end
	end)
	button:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton" then
			local port = presentationPort()
			self._gfCancelInteraction = port and port.CaptureApplicationInteraction
				and port:CaptureApplicationInteraction(self._gfRow, self.resultID)
			UpdateApplicationCancelButtonState(self)
		end
	end)
	button:SetScript("OnEnable", UpdateApplicationCancelButtonState)
	button:SetScript("OnDisable", UpdateApplicationCancelButtonState)
	button:SetScript("OnClick", function(self)
		local row = self._gfRow
		local resultID = tonumber(self.resultID or (row and row.resultID))
		if not resultID then
			return
		end
		local port = presentationPort()
		if not port then return end
		local expected = self._gfCancelInteraction
		self._gfCancelInteraction = nil
		if not expected or not port.MatchesApplicationInteraction
			or not port:MatchesApplicationInteraction(expected, row, resultID) then return end
		port:CancelApplication(resultID)
		-- The row owns cancellation feedback; do not duplicate it in a toast.
		if GF.ListRow then GF.ListRow:ApplyApplicationState(row, resultID) end
		if self._gfCancelHovered and self.GetScript then
			local onEnter = self:GetScript("OnEnter")
			if onEnter then onEnter(self) end
		end
	end)
	local skin = GF.UI.ApplyCommonSmallButtonSkin(button, icon, {
		iconWidth = APPLICATION_CANCEL_BUTTON_ICON_SIZE,
		iconHeight = APPLICATION_CANCEL_BUTTON_ICON_SIZE,
	})
	button._gfCancelBg = skin.background
	return button
end


GF.ListingRowView = {}
GF.ListRow = GF.ListingRowView -- compatibility facade
local LR = GF.ListingRowView

local NETEASE_NEWBIE = GF.NETEASE_IDENTITY_NEWBIE or "netease_newbie"
local NETEASE_LOCOMOTIVE = GF.NETEASE_IDENTITY_LOCOMOTIVE or "netease_locomotive"
local NETEASE_STAR = GF.NETEASE_IDENTITY_STAR or "netease_star"
local NETEASE_VETERAN = GF.NETEASE_IDENTITY_VETERAN or "netease_veteran"
local NETEASE_LOADING = GF.NETEASE_IDENTITY_LOADING or "netease_loading"
local NETEASE_OFFLINE = GF.NETEASE_IDENTITY_OFFLINE or "netease_offline"
local NETEASE_FAULT = GF.NETEASE_IDENTITY_FAULT or "netease_fault"
local STARRED_LEADER = GF.STARRED_LEADER_DISPLAY_TYPE or "starred_leader"

-- 结果行外壳与 GF 固定行视觉
local ROW_BACKGROUND_FALLBACK_TEXTURE = GF.ROW_BACKGROUND_FALLBACK_TEXTURE
local ROW_BACKGROUND_ALPHA = GF.BROWSE_ROW_BACKGROUND_ALPHA or 0.92
local ROW_BACKGROUND_FADE_SECONDS = GF.BROWSE_ROW_BACKGROUND_FADE_SECONDS or 0.16
local ROW_TEXT_FADE_SECONDS = GF.BROWSE_ROW_TEXT_FADE_SECONDS or 0.18
local ROW_HOVER_COLOR = GF.BROWSE_ROW_HOVER_COLOR or { 1, 0.74, 0.18, 0.13 }
local ROW_HOVER_RED_COLOR = GF.BROWSE_ROW_HOVER_RED_COLOR or { 1, 0.12, 0.08, 0.18 }
local ROW_HOVER_BLUE_COLOR = GF.BROWSE_ROW_HOVER_BLUE_COLOR or { 0.35, 0.75, 1, 0.16 }
local ROW_HOVER_GREY_COLOR = GF.BROWSE_ROW_HOVER_GREY_COLOR or { 0.65, 0.65, 0.65, 0.18 }
local ROW_SELECTED_ALPHA = GF.BROWSE_ROW_SELECTED_ALPHA or 1
local TYPE_ICON_GAP = 3
local TYPE_ICON_TEXTURE = {
	[STARRED_LEADER] = GF.STARRED_LEADER_TYPE_ICON_TEXTURE,
	blacklist = GF.BLACKLIST_ICON_TEXTURE,
	leaver = GF.LEAVER_ICON_TEXTURE,
	[GF.RESULT_TYPE_CENSORED or "censored"] = GF.CENSORED_RESULT_ICON_TEXTURE,
}
for identityType, texture in pairs(GF.NETEASE_IDENTITY_ICON or {}) do
	TYPE_ICON_TEXTURE[identityType] = texture
end
TYPE_ICON_TEXTURE[NETEASE_OFFLINE] = GF.NETEASE_SERVICE_ICON_TEXTURE
TYPE_ICON_TEXTURE[NETEASE_FAULT] = GF.NETEASE_SERVICE_ICON_TEXTURE
for socialType, texture in pairs(GF.SOCIAL_TYPE_ICON_TEXTURE or {}) do
	TYPE_ICON_TEXTURE[socialType] = texture
end
for playstyleType, texture in pairs(GF.RESULT_PLAYSTYLE_ICON_TEXTURE or {}) do
	TYPE_ICON_TEXTURE[playstyleType] = texture
end
local TYPE_TEXT_COLOR = {
	[STARRED_LEADER] = GF.COMMON_BUTTON_VISUALS and GF.COMMON_BUTTON_VISUALS.normal.textColor
		or { 1, 0.82, 0, 1 },
	blacklist = { r = 1, g = 0.08, b = 0.05 },
	leaver = { r = 1, g = 0.08, b = 0.05 },
	[GF.RESULT_TYPE_CENSORED or "censored"] = GF.CENSORED_RESULT_TEXT_COLOR
		or { r = 216 / 255, g = 180 / 255, b = 254 / 255 },
}
TYPE_TEXT_COLOR[NETEASE_NEWBIE] = { r = 0.16, g = 1, b = 0.28 }
TYPE_TEXT_COLOR[NETEASE_LOCOMOTIVE] = { r = 1, g = 0.82, b = 0 }
TYPE_TEXT_COLOR[NETEASE_STAR] = { r = 1, g = 0.82, b = 0 }
TYPE_TEXT_COLOR[NETEASE_VETERAN] = { r = 1, g = 0.82, b = 0 }
TYPE_TEXT_COLOR[NETEASE_OFFLINE] = { r = 0.55, g = 0.55, b = 0.55 }
TYPE_TEXT_COLOR[NETEASE_FAULT] = { r = 1, g = 0.12, b = 0.08 }
for socialType in pairs(GF.SOCIAL_TYPE_ICON_TEXTURE or {}) do
	TYPE_TEXT_COLOR[socialType] = (GF.GetSocialTypeTextColor and GF.GetSocialTypeTextColor(socialType))
		or GF.SOCIAL_TEXT_COLOR
end
for playstyleType, color in pairs(GF.RESULT_PLAYSTYLE_TEXT_COLOR or {}) do
	TYPE_TEXT_COLOR[playstyleType] = color
end
local SOCIAL_SEARCH_RESULT_LABEL_FALLBACK = GF.SOCIAL_SEARCH_RESULT_LABEL_FALLBACK

local function getTypeIconSize()
	return (GF.GetNonRoleListIconSize and GF.GetNonRoleListIconSize()) or GF.NON_ROLE_ICON_SIZE or 18
end

function LR:ApplyDivider(row)
	if not row or not row.divider then
		return
	end
	row.divider:Hide()
end

local ROW_SELECTED_COLOR =
	GF.BROWSE_ROW_SELECTED_COLOR or { 1, 0.9, 0.08, 0.82 }
local ROW_SELECTED_BLUE_COLOR = { 0.18, 0.86, 1, 0.78 }
local ROW_SELECTED_RED_COLOR = { 1, 0.05, 0.03, 0.86 }
local ROW_SELECTED_GREY_COLOR = { 0.82, 0.82, 0.82, 0.68 }
local function getRowContentOffsetY()
	return tonumber(GF.BROWSE_ROW_CONTENT_OFFSET_Y) or -2
end
local function getAppLineY(row)
	return getRowContentOffsetY()
end
local VOICE_W = 16
local LC = GF.ListColumns

local function isSecretLfgText(text)
	local port = presentationPort()
	if port and port.IsSecretText then
		return port:IsSecretText(text)
	end
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, text)
	return ok and secret == true
end

local function hasRenderableListingComment(comment)
	local port = presentationPort()
	if port and port.HasRenderableComment then
		return port:HasRenderableComment(comment)
	end
	if isSecretLfgText(comment) then
		return true
	end
	return comment ~= nil and comment ~= ""
end

local function isVoiceHiddenByFilter()
	local tab = GF.FindGroupTab
	local selection = tab and tab.GetSelection and tab:GetSelection()
	local spec = selection and GF.FilterSpec
		and GF.FilterSpec:ResolveSpec(selection)
	local db = GF.Filter and GF.Filter.GetGlobalFilters
		and GF.Filter:GetGlobalFilters(spec)
	if not db and GF.GetDB then
		db = GF.GetDB()
	end
	return db and db.hideVoice == true or false
end

local function applyVoicePresentation(row, presentation)
	local currentGroup = presentation.resultType == (GF.RESULT_TYPE_CURRENT_GROUP or "current_group")
	local allowed = not currentGroup and row._isCensored ~= true and not isVoiceHiddenByFilter()
	row._hasVoice = (allowed and presentation.hasVoice == true) or nil
	local opaqueProvided = allowed
		and presentation.voiceShownProvided == true
	row._gfVoiceShownProvided = opaqueProvided or nil
	if opaqueProvided then
		-- May be a secret boolean. Assignment is allowed; inspection is not.
		row._gfVoiceShown = presentation.voiceShown
	else
		row._gfVoiceShown = nil
	end
end

local function clearCommentText(fontString)
	if not fontString then
		return
	end
	if fontString.ClearText then
		fontString:ClearText()
	else
		fontString:SetText("")
	end
end

local function setRowEllipsis(fontString, text, width)
	if not fontString then
		return
	end
	if isSecretLfgText(text) then
		fontString:SetWordWrap(false)
		fontString:SetMaxLines(1)
		if width and width > 0 then
			fontString:SetWidth(width)
		end
		fontString:SetText(text)
	elseif GF.UI and GF.UI.SetEllipsisText then
		GF.UI.SetEllipsisText(fontString, text, width)
	else
		fontString:SetText(text or "")
	end
end

local function isRenderedBadListingText(text)
	if isSecretLfgText(text) then
		return true
	end
	if text == nil or text == "" then
		return true
	end
	local textType = type(text)
	if textType ~= "string" and textType ~= "number" then
		return true
	end
	local port = presentationPort()
	if port and port:IsRenderedUnreadableText(text) then
		return true
	end
	text = tostring(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	if strtrim then
		text = strtrim(text)
	end
	if text == "" then
		return true
	end
	if text == "|Kr0|k" or text == "?" or text == "未知目标" or text == "未知目標" or text == "Unknown Target" then
		return true
	end
	if _G.UNKNOWNOBJECT and text == _G.UNKNOWNOBJECT then
		return true
	end
	if _G.UNKNOWNBEING and text == _G.UNKNOWNBEING then
		return true
	end
	return false
end

local function rowHasRenderedBadListingText(row)
	if not row then
		return false
	end
	if row._isCensored == true then
		return false
	end
	if row.title and isRenderedBadListingText(row.title:GetText()) then
		return true
	end
	local port = presentationPort()
	if row.title and row.resultID and port then
		local text = row.title:GetText()
		if type(text) == "string" and text:find("|K", 1, true)
			and not port:IsLiveResult(row.resultID) then
			return true
		end
	end
	return false
end

local function dropRenderedBadResult(panel, resultID)
	if not panel or not resultID then
		return
	end
	panel._dropRenderedBadResultPending = panel._dropRenderedBadResultPending or {}
	if panel._dropRenderedBadResultPending[resultID] then
		return
	end
	panel._dropRenderedBadResultPending[resultID] = true
	local function drop()
		if panel._dropRenderedBadResultPending then
			panel._dropRenderedBadResultPending[resultID] = nil
		end
		if panel.DropFrozenResult and panel:DropFrozenResult(resultID) then
			if panel.RefreshList then
				panel:RefreshList({ preserveScroll = true })
			end
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, drop)
	else
		drop()
	end
end

-- 结果列投影与单元格绘制（布局来自 GF.ListColumns）

local function resolveBrowseLayout(rowW)
	local tab = GF.FindGroupTab
	local selection = tab and tab.GetSelection and tab:GetSelection() or nil
	local profile = LC:GetBrowseProfile(selection)
	return LC:ResolveLayout(rowW, profile)
end

local function rowCol(row, colID)
	local columns = row and row._columnLayout and row._columnLayout.byId
	return columns and columns[colID] or nil
end

local COLUMN_JUSTIFY = { CENTER = true, RIGHT = true }

local function applyColumnJustify(fontString, col, forceLeft)
	if fontString then
		-- The badge and fitted name are centered together; no extra gap inside the name.
		local requested = forceLeft and "LEFT" or col and col.align
		fontString:SetJustifyH(COLUMN_JUSTIFY[requested] and requested or "LEFT")
	end
end

local BROWSE_TEXT_INSET_COLS = { title = true, activity = true, leader = true, comment = true }
local STARRED_ICON_FIELDS = { title = "starredIcon", leader = "starredLeaderIcon" }
local BROWSE_LAYOUT_TEXT_CELLS = {
	{ field = "title", column = "title" },
	{ field = "activity", column = "activity" },
	{ field = "typeText", column = "type" },
	{ field = "metaLeader", column = "leader" },
	{ field = "metaIL", column = "ilvl" },
	{ field = "metaScore", column = "score" },
}

local function getTextCellInset(colID)
	if BROWSE_TEXT_INSET_COLS[colID] then
		return GF.BROWSE_TEXT_CELL_INSET_X or 0
	end
	return 0
end

local function getTextCellWidth(row, colID, col)
	local cached = row and row._colWidths and row._colWidths[colID]
	if cached then
		return cached
	end
	local column = col or rowCol(row, colID)
	if not column then
		return 1
	end
	return math.max(1, (column.width or 1) - (2 * getTextCellInset(colID)))
end

local function paintColText(row, colID, fontString, text)
	local col = rowCol(row, colID)
	if not (col and fontString) then
		return false
	end
	setRowEllipsis(fontString, text, getTextCellWidth(row, colID, col))
	applyColumnJustify(fontString, col, colID == "leader" and row._starredLeader)
	return true
end

local layoutCommentCell

local function hideComment(row)
	if row and row.comment then
		clearCommentText(row.comment)
		row.comment:Hide()
	end
end

local function displayComment(row, text, width, color)
	if not (row and row.comment and width and hasRenderableListingComment(text)) then
		hideComment(row)
		return false
	end
	clearCommentText(row.comment)
	setRowEllipsis(row.comment, text, width)
	local tint = color or getTextStyle().comment
	row.comment:SetTextColor(tint.r, tint.g, tint.b)
	row.comment:Show()
	return true
end

local function relayoutCommentText(row, dc)
	local width = rowCol(row, "comment") and layoutCommentCell(row) or nil
	local tint = dc
	if not tint and row and row._isDelisted then
		tint = LFG_LIST_DELISTED_FONT_COLOR or GRAY
	end
	if not tint and row and row._isCensored == true then
		tint = GF.CENSORED_RESULT_COMMENT_COLOR
	end
	displayComment(row, row and row._commentText, width, tint)
end

local function refreshCommentCell(row, comment, dc)
	local width = rowCol(row, "comment") and layoutCommentCell(row) or nil
	displayComment(row, comment, width, dc)
end

local function hideStarredIcon(icon)
	if not icon then return end
	local transition = icon._gfBrowseColorTransition
	if transition then
		transition:Stop()
		transition._gfIdentityKey = nil
	end
	icon._gfStarredVisible = false
	icon:Hide()
end

local function setStarredIconsDisabled(row, disabled)
	if not row then return end
	for _, field in pairs(STARRED_ICON_FIELDS) do
		local icon = row[field]
		if icon then
			icon:SetDesaturated(disabled == true)
			icon:SetVertexColor(1, 1, 1,
				disabled and (GF.STARRED_LEADER_DISABLED_ALPHA or 0.5) or 1)
		end
	end
end

local function fitStarredLeaderWidth(fontString, text, availableWidth)
	if isSecretLfgText(text) or type(text) ~= "string"
		or type(fontString.GetUnboundedStringWidthForText) ~= "function"
	then
		return availableWidth
	end
	local ok, measured = pcall(fontString.GetUnboundedStringWidthForText, fontString, text)
	if not ok or isSecretLfgText(measured) or type(measured) ~= "number"
		or measured < 0 or measured ~= measured or measured == math.huge
	then
		return availableWidth
	end
	return math.min(availableWidth, math.max(1, math.ceil(measured)))
end

local function placeTextCell(row, fontString, colID, y)
	local lineY = tonumber(y) or getRowContentOffsetY()
	local col = rowCol(row, colID)
	local iconField = STARRED_ICON_FIELDS[colID]
	if not (col and fontString) then
		if iconField then hideStarredIcon(row[iconField]) end
		if fontString then
			fontString:Hide()
		end
		if row and row._colWidths then
			row._colWidths[colID] = nil
		end
		return nil
	end
	row._colWidths = row._colWidths or {}
	local inset = getTextCellInset(colID)
	local width = math.max(1, col.width - 2 * inset)
	local left = col.x + inset
	local badgeOffset = 0
	if iconField and row._starredLeader then
		local icon = row[iconField]
		if not icon then
			icon = row:CreateTexture(nil, "ARTWORK")
			row[iconField] = icon
			icon:SetAtlas(GF.STARRED_LEADER_ICON_ATLAS or "campcollection-icon-star")
			icon:SetSize(GF.STARRED_LEADER_ICON_SIZE, GF.STARRED_LEADER_ICON_SIZE)
			icon._gfStarredBadge = true
		end
		local gap = colID == "leader" and GF.BROWSE_STARRED_LEADER_NAME_GAP
			or GF.BROWSE_STARRED_TITLE_GAP
		badgeOffset = GF.STARRED_LEADER_ICON_SIZE + (gap or 4)
		width = math.max(1, width - badgeOffset)
		if colID == "leader" then
			local fittedWidth = fitStarredLeaderWidth(fontString, row._metaLeaderText, width)
			left = left + (width - fittedWidth) * 0.5
			width = fittedWidth
		end
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", row, "LEFT", left, lineY)
		icon._gfStarredVisible = true
		icon:Show()
	elseif iconField then
		hideStarredIcon(row[iconField])
	end
	fontString:ClearAllPoints()
	fontString:SetPoint("LEFT", row, "LEFT", left + badgeOffset, lineY)
	fontString:SetWidth(width)
	applyColumnJustify(fontString, col, colID == "leader" and row._starredLeader)
	fontString:Show()
	row._colWidths[colID] = width
	return width
end

layoutCommentCell = function(row, y)
	local col = rowCol(row, "comment")
	if not (col and row and row.comment) then
		hideComment(row)
		if row.voiceIcon then
			row.voiceIcon:Hide()
		end
		return nil
	end
	row._colWidths = row._colWidths or {}
	local inset = getTextCellInset("comment")
	local left = col.x + inset
	local width = col.width - (row._appReservedW or 0) - 2 * inset
	local lineY = tonumber(y) or getRowContentOffsetY()
	local voice = row.voiceIcon
	local opaqueVoice = row._gfVoiceShownProvided == true
	if voice and (row._hasVoice or opaqueVoice) then
		voice:ClearAllPoints()
		voice:SetPoint("LEFT", row, "LEFT", left, lineY)
		voice:Show()
		if opaqueVoice then
			-- SetAlphaFromBoolean is the 12.1 tainted-safe sink for a secret
			-- boolean. The row always reserves the icon slot, so Lua never
			-- branches on the opaque value. A malformed projection can still
			-- omit the token; contain that API error and fail closed.
			if type(voice.SetAlphaFromBoolean) == "function" then
				local applied = pcall(
					voice.SetAlphaFromBoolean,
					voice,
					row._gfVoiceShown,
					1,
					0)
				if not applied then
					if type(voice.SetAlpha) == "function" then
						voice:SetAlpha(0)
					else
						voice:Hide()
					end
				end
			elseif type(voice.SetAlpha) == "function" then
				voice:SetAlpha(0)
			else
				voice:Hide()
			end
		else
			if type(voice.SetAlpha) == "function" then
				voice:SetAlpha(1)
			end
		end
		row.comment:ClearAllPoints()
		row.comment:SetPoint("LEFT", voice, "RIGHT", 2, 0)
		width = width - VOICE_W - 2
	else
		if voice then
			if type(voice.SetAlpha) == "function" then
				voice:SetAlpha(1)
			end
			voice:Hide()
		end
		row.comment:ClearAllPoints()
		row.comment:SetPoint("LEFT", row, "LEFT", left, lineY)
	end
	width = math.max(1, width)
	row.comment:SetWidth(width)
	row.comment:Show()
	row._colWidths.comment = width
	return width
end

function LR:LayoutRow(row, layoutW)
	if not row or not row.title then
		return
	end
	local requestedWidth = tonumber(layoutW) or row:GetWidth() or 0
	local rowW = requestedWidth > 0 and requestedWidth or 400
	row._columnLayout = resolveBrowseLayout(rowW)
	for _, cell in ipairs(BROWSE_LAYOUT_TEXT_CELLS) do
		placeTextCell(row, row[cell.field], cell.column)
	end
	layoutCommentCell(row)

	local roleColumn = rowCol(row, "roles")
	if row.roles and roleColumn then
		GF.RoleDisplay:Layout(row.roles)
		row.roles:ClearAllPoints()
		row.roles:SetPoint("CENTER", row, "LEFT", roleColumn.x + roleColumn.width * 0.5, getRowContentOffsetY())
		row.roles:Show()
	elseif row.roles then
		row.roles:Hide()
	end
end

-- 悬停投影、标题视觉与虚拟行生命周期

function LR:IsHoverTooltipEnabled()
	return true
end

function LR:IsHoverHighlightEnabled()
	return true
end

local GOLD, GRAY =
	{ r = 1, g = 0.82, b = 0 },
	{ r = 0.5, g = 0.5, b = 0.5 }

function LR:ClearApplicantHighlights()
	local ap = GF.ApplicantsPanel
	if ap and ap.ForEachVisibleRow then
		ap:ForEachVisibleRow(function(card)
			local members = card and card.members or {}
			for index = 1, #members do
				local highlight = members[index] and members[index].highlight
				if highlight then
					highlight:Hide()
				end
			end
		end)
	end
end

local hoverTooltipHideSeq = 0
local HOVER_TOOLTIP_HIDE_DELAY = GF.LIST_HOVER_TOOLTIP_HIDE_DELAY or 0.1

local function isListHoverTooltipEnabled()
	return LR:IsHoverTooltipEnabled()
end

local function isListHoverHighlightEnabled()
	return LR:IsHoverHighlightEnabled()
end

cancelHoverTooltipHide = function()
	hoverTooltipHideSeq = hoverTooltipHideSeq + 1
end

local function hideHoverTooltipNow()
	cancelHoverTooltipHide()
	lastTooltipResultID = nil
	if GameTooltip then
		GameTooltip:Hide()
	end
end

local function scheduleHoverTooltipHide(owner)
	cancelHoverTooltipHide()
	local scheduled = hoverTooltipHideSeq
	C_Timer.After(HOVER_TOOLTIP_HIDE_DELAY, function()
		if scheduled ~= hoverTooltipHideSeq then
			return
		end
		local tooltipOwner = GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()
		if owner and tooltipOwner ~= owner then
			return
		end
		lastTooltipResultID = nil
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
end

function LR:ClearHoverTooltip()
	hideHoverTooltipNow()
end

-- Row reuse must clear the native tooltip before GroupFinder's delayed tooltip can claim it.
local setRowHoverShown

function LR:ClearHoverHighlight()
	local tab = GF.FindGroupTab
	if tab and tab.ForEachVisibleRow then
		tab:ForEachVisibleRow(function(row)
			setRowHoverShown(row, false)
		end)
	end
	self:ClearApplicantHighlights()
end

local LEADER_RETRY_MAX = 2

local function canRetryLeaderForRow(row, index, token)
	if row._leaderRetrySeq ~= token or row.resultIndex ~= index then
		return false
	end
	if not row:IsShown() then
		return false
	end
	local currentText = row._metaLeaderText
	return not currentText or currentText == "?"
end

local function resolveLeaderPresentation(index, fallbackEntry)
	local port = presentationPort()
	return port and port:GetLeaderPresentation(index, fallbackEntry)
		or { text = "?", color = { r = 1, g = 1, b = 1 }, entry = fallbackEntry }
end

function LR:RefreshLeaderColumn(row, index, entry)
	if not row or not index then
		return false
	end
	local presentation = resolveLeaderPresentation(index, entry)
	if presentation.text == "?" then
		return false
	end
	row._metaLeaderText = presentation.text
	row._starredLeader = presentation.starred == true
	placeTextCell(row, row.title, "title")
	placeTextCell(row, row.metaLeader, "leader")
	if paintColText(row, "leader", row.metaLeader, row._metaLeaderText) then
		local delisted = row._titleInfo and row._titleInfo.isDelisted
		local terminal = row._applicationVisualState == "cancelled"
			or row._applicationVisualState == "declined"
		local tint = delisted and (LFG_LIST_DELISTED_FONT_COLOR or GRAY)
			or terminal and APPLICATION_CANCELLED_TEXT_COLOR
			or presentation.color
		row.metaLeader:SetTextColor(tint.r, tint.g, tint.b)
	end
	self:UpdateRowBackgrounds(row)
	return true, presentation.entry
end

function LR:ScheduleLeaderRetry(row, index)
	if not row or not index or not C_Timer or not C_Timer.After then
		return
	end
	row._leaderRetrySeq = (row._leaderRetrySeq or 0) + 1
	local token = row._leaderRetrySeq
	local attemptsRemaining = LEADER_RETRY_MAX
	local function retry()
		if not canRetryLeaderForRow(row, index, token) then
			return
		end
		if self:RefreshLeaderColumn(row, index) then
			return
		end
		attemptsRemaining = attemptsRemaining - 1
		if attemptsRemaining > 0 then
			C_Timer.After(0, retry)
		end
	end
	C_Timer.After(0, retry)
end

local function setDelistedOrColor(fontString, dc, r, g, b)
	local tint = dc or { r = r, g = g, b = b }
	fontString:SetTextColor(tint.r, tint.g, tint.b)
end

local function plainScoreText(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function applyUnavailableRowContentColor(row)
	setStarredIconsDisabled(row, true)
	local fields = {
		"title", "activity", "typeText", "metaIL", "metaLeader", "metaScore", "comment",
	}
	for _, field in ipairs(fields) do
		local fontString = row and row[field]
		if fontString then
			if field == "metaScore" then
				local text = fontString:GetText()
				if text then fontString:SetText(plainScoreText(text)) end
			end
			local color = APPLICATION_CANCELLED_TEXT_COLOR
			fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
		end
	end
	if row and row.typeIcon then
		row.typeIcon:SetDesaturated(true)
		row.typeIcon:SetAlpha(0.5)
	end
end

local function createRowOverlayPieces(row, subLevel)
	local pieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(row, "BORDER", subLevel or -1)
		or nil
	if not (pieces and pieces.left and pieces.middle and pieces.right) then
		pieces = {}
		for _, key in ipairs({ "left", "middle", "right" }) do
			pieces[key] = row:CreateTexture(nil, "BORDER", nil, subLevel or -1)
		end
	end
	return pieces
end

local function setRowOverlayShown(pieces, shown)
	if GF.UI and GF.UI.SetRowBackgroundPiecesShown then
		GF.UI.SetRowBackgroundPiecesShown(pieces, shown == true)
		return
	end
	for _, piece in pairs(pieces or {}) do
		if piece.SetShown then
			piece:SetShown(shown == true)
		end
	end
end

local function applyRowOverlayPieces(row, pieces, color)
	if not (row and pieces and GF.UI and GF.UI.ApplyRowBackgroundPieces) then
		return false
	end
	return GF.UI.ApplyRowBackgroundPieces(row, pieces, {
		state = "normal",
		mode = "full",
		profile = GF.LIST_ROW_STYLE and GF.LIST_ROW_STYLE.background,
		alpha = ROW_SELECTED_ALPHA,
		vertexColor = color or ROW_HOVER_COLOR,
		desaturated = true,
		fallbackTexture = ROW_BACKGROUND_FALLBACK_TEXTURE,
		defaultHeight = row and row.GetHeight and row:GetHeight() or (GF.GetBrowseRowH and GF.GetBrowseRowH() or GF.BROWSE_ROW_H or 34),
	})
end

local function setRowHoverTextureColor(row, color)
	if not row then
		return
	end
	color = color or ROW_HOVER_COLOR
	row._gfHoverColor = color
	applyRowOverlayPieces(row, row.hoverPieces, color)
	setRowOverlayShown(row.hoverPieces, row._gfHoverShown == true)
end

local function getRowSelectedColorForState(state)
	if GF.GetListBackgroundOverlayColor then
		return GF.GetListBackgroundOverlayColor(state, "selected")
	end
	if state == "blue" then
		return ROW_SELECTED_BLUE_COLOR
	end
	if state == "red" then
		return ROW_SELECTED_RED_COLOR
	end
	if state == "grey" then
		return ROW_SELECTED_GREY_COLOR
	end
	return ROW_SELECTED_COLOR
end

local function setRowSelectedTextureState(row, state)
	if not row then
		return
	end
	row._gfSelectedState = state or "normal"
	applyRowOverlayPieces(row, row.selectedHighlightPieces, getRowSelectedColorForState(state))
	setRowOverlayShown(row.selectedHighlightPieces, row._gfSelectedShown == true)
end

function setRowHoverShown(row, shown)
	if not row then
		return
	end
	row._gfHoverShown = shown == true
	setRowOverlayShown(row.hoverPieces, row._gfHoverShown)
end

local function setRowSelectedShown(row, shown)
	if row then
		row._gfSelectedShown = shown == true
	end
	setRowOverlayShown(row and row.selectedHighlightPieces, row and row._gfSelectedShown)
end

local function layoutRowSelectedTexture(row)
	if row and row.selectedHighlightPieces then
		applyRowOverlayPieces(row, row.selectedHighlightPieces, getRowSelectedColorForState(row._gfSelectedState))
		setRowOverlayShown(row.selectedHighlightPieces, row._gfSelectedShown == true)
	end
end

local function layoutRowHoverTextures(row)
	if row and row.hoverPieces then
		applyRowOverlayPieces(row, row.hoverPieces, row._gfHoverColor or ROW_HOVER_COLOR)
		setRowOverlayShown(row.hoverPieces, row._gfHoverShown == true)
	end
end

local function createRowSelectedTexture(row)
	local pieces = createRowOverlayPieces(row, 1)
	for _, piece in pairs(pieces) do
		if piece.SetBlendMode then
			piece:SetBlendMode("ADD")
		end
		piece:SetAlpha(ROW_SELECTED_ALPHA)
	end
	row.selectedHighlightPieces = pieces
	setRowSelectedTextureState(row, "normal")
	setRowSelectedShown(row, false)
	layoutRowSelectedTexture(row)
end

local function createRowHoverTextures(row)
	local pieces = createRowOverlayPieces(row, -1)
	for _, piece in pairs(pieces) do
		if piece.SetBlendMode then
			piece:SetBlendMode("ADD")
		end
	end
	row.hoverPieces = pieces
	layoutRowHoverTextures(row)
	setRowHoverTextureColor(row, ROW_HOVER_COLOR)
	setRowHoverShown(row, false)
end

local function getRowBackgroundAlpha(state)
	return GF.GetListBackgroundAlpha and GF.GetListBackgroundAlpha(state or "normal") or ROW_BACKGROUND_ALPHA
end

local function createBrowseRowBackgroundPieces(row, subLevel)
	local pieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(row, "BACKGROUND", subLevel or -2)
		or nil
	if not (pieces and pieces.left and pieces.middle and pieces.right) then
		pieces = {}
		for _, key in ipairs({ "left", "middle", "right" }) do
			pieces[key] = row:CreateTexture(nil, "BACKGROUND", nil, subLevel or -2)
		end
	end
	for _, piece in pairs(pieces) do
		piece:SetAlpha(getRowBackgroundAlpha("normal"))
	end
	return pieces
end

local function setBrowseRowBackgroundPiecesShown(pieces, shown)
	if GF.UI and GF.UI.SetRowBackgroundPiecesShown then
		GF.UI.SetRowBackgroundPiecesShown(pieces, shown)
		return
	end
	for _, piece in pairs(pieces or {}) do
		if piece.SetShown then
			piece:SetShown(shown == true)
		end
	end
end

local function stopBrowseBackgroundPieceFade(piece)
	if not piece then
		return
	end
	piece._gfBackgroundFadeToken = (piece._gfBackgroundFadeToken or 0) + 1
	if piece._gfBackgroundFade then
		piece._gfBackgroundFade:Stop()
	end
	piece:SetAlpha(0)
	piece:Hide()
end

local function ensureBrowseBackgroundPieceFade(piece)
	if not (piece and piece.CreateAnimationGroup) then
		return nil
	end
	if piece._gfBackgroundFade then
		return piece._gfBackgroundFade
	end
	local fade = piece:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(getRowBackgroundAlpha())
	alpha:SetToAlpha(0)
	alpha:SetDuration(ROW_BACKGROUND_FADE_SECONDS)
	alpha:SetSmoothing("OUT")
	fade:SetScript("OnFinished", function(group)
		if piece._gfBackgroundFadeToken ~= group._gfToken then
			return
		end
		piece:SetAlpha(0)
		piece:Hide()
	end)
	piece._gfBackgroundFade = fade
	piece._gfBackgroundFadeAlpha = alpha
	return fade
end

local function playBrowseBackgroundPieceFade(piece, alphaValue)
	if not piece then
		return
	end
	piece._gfBackgroundFadeToken = (piece._gfBackgroundFadeToken or 0) + 1
	local token = piece._gfBackgroundFadeToken
	local fade = ensureBrowseBackgroundPieceFade(piece)
	if fade then
		fade:Stop()
	end
	piece:SetAlpha(alphaValue)
	piece:Show()
	if fade and piece._gfBackgroundFadeAlpha then
		piece._gfBackgroundFadeAlpha:SetFromAlpha(alphaValue)
		piece._gfBackgroundFadeAlpha:SetToAlpha(0)
		piece._gfBackgroundFadeAlpha:SetDuration(ROW_BACKGROUND_FADE_SECONDS)
		fade._gfToken = token
		fade:Play()
	else
		piece:SetAlpha(0)
		piece:Hide()
	end
end

local function stopBrowseRowBackgroundTransition(row)
	if not row then
		return
	end
	for _, piece in pairs(row.backgroundTransitionPieces or {}) do
		stopBrowseBackgroundPieceFade(piece)
	end
	row._gfBrowseTransitionIdentityKey = nil
	row._gfBrowseTransitionTargetState = nil
end

local function getBrowseVisualIdentity(row)
	local identity = row and (row._gfProjectionKey or row.resultID)
	if identity == nil then
		return nil
	end
	local panel = GF.BrowsePanel
	local context = tostring(panel and panel._searchToken or "")
		.. "\031" .. tostring(panel and panel.activeSearchKey or "")
	if LR._gfBrowseVisualContext ~= context then
		LR._gfBrowseVisualContext = context
		LR._gfBrowseVisualStateByIdentity = {}
		LR._gfBrowseTextStateByIdentity = {}
	end
	return context .. "\031" .. tostring(identity)
end

local getBrowseRowVisualState

local ROW_CONTENT_TEXT_FIELDS = {
	"title", "activity", "typeText", "metaIL", "metaLeader", "metaScore", "comment",
	"starredIcon", "starredLeaderIcon",
}

local function copyTextColor(region)
	if not region or (region._gfStarredBadge and not region._gfStarredVisible) then
		return nil
	end
	local getColor = region.GetTextColor or region.GetVertexColor
	if not getColor then return nil end
	local r, g, b, a = getColor(region)
	return { r = r or 1, g = g or 1, b = b or 1, a = a or 1 }
end

local function setContentColor(region, color)
	local setColor = region.SetTextColor or region.SetVertexColor
	setColor(region, color.r, color.g, color.b, color.a)
end

local function captureRowContentColors(row)
	local colors = {}
	for _, field in ipairs(ROW_CONTENT_TEXT_FIELDS) do
		local color = copyTextColor(row and row[field])
		if color then
			colors[field] = color
		end
	end
	return colors
end

local function stopFontStringColorTransition(fontString)
	local group = fontString and fontString._gfBrowseColorTransition
	if group then
		group:Stop()
		group._gfIdentityKey = nil
		group._gfTargetState = nil
	end
end

local function stopBrowseRowTextTransitions(row)
	for _, field in ipairs(ROW_CONTENT_TEXT_FIELDS) do
		stopFontStringColorTransition(row and row[field])
	end
	row._gfBrowseTextTransitionIdentityKey = nil
	row._gfBrowseTextTransitionTargetState = nil
end

local function ensureFontStringColorTransition(row, fontString)
	if not (fontString and fontString.CreateAnimationGroup and type(CreateColor) == "function") then
		return nil
	end
	if fontString._gfBrowseColorTransition then
		return fontString._gfBrowseColorTransition
	end
	local group = fontString:CreateAnimationGroup()
	local animation = group:CreateAnimation("VertexColor")
	if not (animation and animation.SetStartColor and animation.SetEndColor) then
		return nil
	end
	animation:SetDuration(ROW_TEXT_FADE_SECONDS)
	if animation.SetSmoothing then
		animation:SetSmoothing("IN_OUT")
	end
	group:SetScript("OnFinished", function(completed)
		local target = completed._gfTargetColor
		if target
			and getBrowseVisualIdentity(row) == completed._gfIdentityKey
			and getBrowseRowVisualState(row) == completed._gfTargetState
		then
			setContentColor(fontString, target)
		end
	end)
	fontString._gfBrowseColorTransition = group
	fontString._gfBrowseColorAnimation = animation
	return group
end

local function playFontStringColorTransition(row, fontString, fromColor, targetColor, identityKey, state)
	if not (fontString and fromColor and targetColor) then
		return
	end
	local group = ensureFontStringColorTransition(row, fontString)
	local animation = fontString._gfBrowseColorAnimation
	if not (group and animation) then
		return
	end
	group:Stop()
	animation:SetStartColor(CreateColor(
		fromColor.r, fromColor.g, fromColor.b, fromColor.a))
	animation:SetEndColor(CreateColor(
		targetColor.r, targetColor.g, targetColor.b, targetColor.a))
	animation:SetDuration(ROW_TEXT_FADE_SECONDS)
	group._gfIdentityKey = identityKey
	group._gfTargetState = state
	group._gfTargetColor = targetColor
	setContentColor(fontString, targetColor)
	group:Play()
end

local function updateBrowseRowTextTransitions(row, identityKey, state)
	if not identityKey then
		stopBrowseRowTextTransitions(row)
		return
	end
	LR._gfBrowseTextStateByIdentity = LR._gfBrowseTextStateByIdentity or {}
	local targetColors = captureRowContentColors(row)
	local remembered = LR._gfBrowseTextStateByIdentity[identityKey]
	local continuesCurrentTransition =
		row._gfBrowseTextTransitionIdentityKey == identityKey
		and row._gfBrowseTextTransitionTargetState == state
	if remembered and remembered.state ~= state then
		stopBrowseRowTextTransitions(row)
		for _, field in ipairs(ROW_CONTENT_TEXT_FIELDS) do
			playFontStringColorTransition(
				row,
				row[field],
				remembered.colors and remembered.colors[field],
				targetColors[field],
				identityKey,
				state)
		end
		row._gfBrowseTextTransitionIdentityKey = identityKey
		row._gfBrowseTextTransitionTargetState = state
	elseif not continuesCurrentTransition then
		stopBrowseRowTextTransitions(row)
	end
	LR._gfBrowseTextStateByIdentity[identityKey] = {
		state = state,
		colors = targetColors,
	}
end

local function getBrowseRowBackgroundOptions(row, state)
	return {
		state = state or "normal",
		mode = "full",
		profile = GF.LIST_ROW_STYLE and GF.LIST_ROW_STYLE.background,
		alpha = getRowBackgroundAlpha(state),
		fallbackTexture = ROW_BACKGROUND_FALLBACK_TEXTURE,
		defaultHeight = row and row.GetHeight and row:GetHeight() or (GF.GetBrowseRowH and GF.GetBrowseRowH() or GF.BROWSE_ROW_H or 34),
	}
end

local function applyBrowseRowBackgroundPieces(row, pieces, state)
	if GF.UI and GF.UI.ApplyRowBackgroundPieces then
		return GF.UI.ApplyRowBackgroundPieces(row, pieces, getBrowseRowBackgroundOptions(row, state))
	end
	local color = GF.GetListBackgroundColor and GF.GetListBackgroundColor(state) or nil
	for _, piece in pairs(pieces or {}) do
		piece:ClearAllPoints()
		piece:SetAllPoints(row)
		piece:SetTexture(ROW_BACKGROUND_FALLBACK_TEXTURE)
		piece:SetTexCoord(0, 1, 0, 1)
		if color then
			piece:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
		else
			piece:SetVertexColor(1, 1, 1, 1)
		end
		piece:SetAlpha(getRowBackgroundAlpha(state))
		piece:Show()
	end
	return true
end

local function setBrowseRowBackground(row, state)
	if not row or not row.backgroundPieces then
		return
	end
	state = state or "normal"
	local identityKey = getBrowseVisualIdentity(row)
	local sameElement = identityKey
		and row._gfBrowseBackgroundIdentityKey == identityKey
	local rememberedState = identityKey
		and LR._gfBrowseVisualStateByIdentity
		and LR._gfBrowseVisualStateByIdentity[identityKey]
	local previousState = sameElement
		and row._gfBrowseBackgroundState or rememberedState
	local transitionAlpha = getRowBackgroundAlpha(previousState)
	local shouldFade = not row._gfSuppressBackgroundTransition
		and identityKey
		and previousState
		and previousState ~= state
	if shouldFade then
		stopBrowseRowBackgroundTransition(row)
		applyBrowseRowBackgroundPieces(row, row.backgroundTransitionPieces, previousState)
		for _, piece in pairs(row.backgroundTransitionPieces or {}) do
			if piece.IsShown and piece:IsShown() then
				playBrowseBackgroundPieceFade(piece, transitionAlpha)
			else
				stopBrowseBackgroundPieceFade(piece)
			end
		end
		row._gfBrowseTransitionIdentityKey = identityKey
		row._gfBrowseTransitionTargetState = state
	else
		local continuesCurrentTransition = identityKey
			and row._gfBrowseTransitionIdentityKey == identityKey
			and row._gfBrowseTransitionTargetState == state
		if not continuesCurrentTransition then
			stopBrowseRowBackgroundTransition(row)
		end
	end
	applyBrowseRowBackgroundPieces(row, row.backgroundPieces, state)
	if identityKey then
		LR._gfBrowseVisualStateByIdentity[identityKey] = state
	end
	row._gfBrowseBackgroundIdentityKey = identityKey
	row._gfBrowseBackgroundState = state
end

local function isFixedApplicationRow(row)
	local element = row._gfFixedApplicationElement
	return element ~= nil and element.fixedApplication == true
		and row._isAppActive == true
end

local function selectionSuppressesListRowHover(row)
	return isFixedApplicationRow(row)
		or (row._isSelected == true and row._isAppActive ~= true)
end

local function shouldShowListRowHover(row)
	return row ~= nil and not selectionSuppressesListRowHover(row)
end

local function shouldKeepListRowHover(_row)
	return false
end

local function shouldShowRowSelected(row)
	return row
		and row._isDelisted ~= true
		and (isFixedApplicationRow(row)
			or (row._isSelected == true and row._hasApplication ~= true))
end

function LR:DetachRow(row)
	if not row then
		return
	end
	row._gfBindingGeneration = (row._gfBindingGeneration or 0) + 1
	row._gfBoundResultID = nil
	row._gfBoundSearchToken = nil
	row._gfBoundSearchKey = nil
	for _, field in ipairs({
		"resultIndex", "resultID", "_hasVoice", "_gfProjectionKey",
		"_gfCensoredDebugPreview", "_gfDebugResultPreview",
		"_gfCurrentGroupProjection", "_gfCurrentGroupElement",
		"_gfVoiceShown", "_gfVoiceShownProvided",
	}) do
		row[field] = nil
	end
	if row.voiceIcon then
		if type(row.voiceIcon.SetAlpha) == "function" then
			row.voiceIcon:SetAlpha(1)
		end
		row.voiceIcon:Hide()
	end
	if row.typeSpinner and GF.UI and GF.UI.StopPendingSpinner then
		GF.UI.StopPendingSpinner(row.typeSpinner)
	end
	local managedByScrollBox = type(row.GetElementData) == "function"
	if not managedByScrollBox then
		row:Hide()
	end
	self:ReleaseRow(row)
end

function LR:ReleaseRow(row)
	if not row then
		return
	end
	StopApplicationFeedbackTimer(row)
	StopApplicationPendingSpinner(row.appSpinner)
	if row.appPending then row.appPending:Hide() end
	hideApplicationCountdown(row)
	if row._appCommentLayout then clearReusableTable(row._appCommentLayout) end
	if row.appStatusIcon then row.appStatusIcon:Hide() end
	if row.appCancelHost then row.appCancelHost:Hide() end
	if row.appRetry then row.appRetry:Hide(); row.appRetry._intent = nil end
	if row.appCancel then row.appCancel:Hide(); row.appCancel._gfCancelInteraction = nil end
	if row.typeSpinner and GF.UI and GF.UI.StopPendingSpinner then
		GF.UI.StopPendingSpinner(row.typeSpinner)
	end
	if self.ResetExpiredRemovalFade then
		self:ResetExpiredRemovalFade(row)
	end
	if row._gfResultRowIntroIdentity ~= nil then
		if GF.UI and GF.UI.StopPopupOpenAnimation then
			GF.UI.StopPopupOpenAnimation(row)
		end
		row._gfResultRowIntroIdentity = nil
	end
	local transientFields = {
		"_starredLeader",
		"_isSelected", "_isDelisted", "_isAppActive", "_hasApplication",
		"_applicationVisualState", "_resultType", "_resultDisplayType",
		"_commentText", "_listMouseOver", "_gfBlocklistRetiring", "_isCensored",
		"_gfExpiredRetiring", "_gfExpiredRetirement",
		"_gfCensoredDebugPreview", "_gfDebugResultPreview", "_gfProjectionKey",
		"_gfCurrentGroupProjection", "_gfCurrentGroupElement",
		"_gfVoiceShown", "_gfVoiceShownProvided",
	}
	for _, field in ipairs(transientFields) do
		row[field] = nil
	end
	row._gfRowPresentation = clearReusableTable(row._gfRowPresentation)
	row._gfRowPresentationOptions = clearReusableTable(
		row._gfRowPresentationOptions)
	row._gfPresentationSourceOptions = clearReusableTable(
		row._gfPresentationSourceOptions)
	row._gfSetDataOptions = clearReusableTable(row._gfSetDataOptions)
	row._gfPaintOptions = clearReusableTable(row._gfPaintOptions)
	stopBrowseRowTextTransitions(row)
	for _, field in pairs(STARRED_ICON_FIELDS) do hideStarredIcon(row[field]) end
	hideComment(row)
	if row.voiceIcon then
		if type(row.voiceIcon.SetAlpha) == "function" then
			row.voiceIcon:SetAlpha(1)
		end
		row.voiceIcon:Hide()
	end
	setRowHoverShown(row, false)
	setRowSelectedShown(row, false)
	row._gfSuppressBackgroundTransition = true
	self:UpdateRowBackgrounds(row)
	for _, field in ipairs({
		"_gfSuppressBackgroundTransition",
		"_gfBrowseBackgroundIdentityKey", "_gfBrowseBackgroundState",
	}) do
		row[field] = nil
	end
end

local function isInfoDelisted(info)
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.ReadField) == "function" then
		return snapshot.ReadField(info, "isDelisted") == true
	end
	local compat = GF.Compat
	if compat and type(compat.ReadAccessibleField) == "function" then
		return compat.ReadAccessibleField(info, "isDelisted") == true
	end
	return false
end

local function getTitleDelistedColor(info)
	if not isInfoDelisted(info) then
		return nil
	end
	return LFG_LIST_DELISTED_FONT_COLOR or GRAY
end

local function resolveResultType(row, info, entry)
	local resultID = row and row.resultID or entry and entry.resultID
	local port = presentationPort()
	return port and port:GetResultTypes(
		info,
		entry,
		resultID,
		row and row._gfCurrentGroupProjection == true) or nil
end

local function resolveResultDisplayType(row, info, entry, resultType)
	local port = presentationPort()
	if port then
		if type(port.GetResultDisplayType) == "function" then
			return port:GetResultDisplayType(info, resultType, entry)
		end
		if type(port.IsCensored) == "function" and port:IsCensored(info) then
			return GF.RESULT_TYPE_CENSORED or "censored"
		end
		if resultType ~= nil then
			return resultType
		end
		local _, displayType = port:GetResultTypes(
			info, entry,
			row and row.resultID or entry and entry.resultID,
			row and row._gfCurrentGroupProjection == true)
		return displayType
	end
	return resultType or resolveResultType(row, info, entry)
end

local function getResultTypeLabel(resultType)
	local L = GF.L or {}
	if resultType == STARRED_LEADER then
		return L.TAB_STARRED_LEADERS or "星标团长"
	end
	if resultType == "blacklist" then
		return L.TYPE_BLACKLIST or "黑名单"
	end
	if resultType == "leaver" then
		return L.TYPE_LEAVER or "大秘逃兵"
	end
	if resultType == NETEASE_NEWBIE then
		return L.TYPE_NETEASE_NEWBIE or "大秘新兵"
	end
	if resultType == NETEASE_LOCOMOTIVE then
		return L.TYPE_NETEASE_LOCOMOTIVE or "认证车头"
	end
	if resultType == NETEASE_STAR then
		return L.TYPE_NETEASE_STAR or "星级团长"
	end
	if resultType == NETEASE_VETERAN then
		return L.TYPE_NETEASE_VETERAN or "魔兽老兵"
	end
	if resultType == NETEASE_OFFLINE then
		return L.BROWSE_TYPE_NETEASE_OFFLINE or "服务离线"
	end
	if resultType == NETEASE_FAULT then
		return L.BROWSE_TYPE_NETEASE_FAULT or "服务故障"
	end
	if resultType == NETEASE_LOADING then
		return ""
	end
	if resultType == (GF.RESULT_TYPE_CENSORED or "censored") then
		return L.TYPE_CENSORED or "信息隐匿"
	end
	local socialLabelKey = GF.SOCIAL_SEARCH_RESULT_LABEL_KEY
		and GF.SOCIAL_SEARCH_RESULT_LABEL_KEY[resultType]
	if socialLabelKey then
		return L[socialLabelKey] or SOCIAL_SEARCH_RESULT_LABEL_FALLBACK[resultType] or ""
	end
	if GF.GetResultPlaystyleLabel then
		return GF.GetResultPlaystyleLabel(resultType)
	end
	return ""
end

local function measureTypeLabel(fontString, text)
	if fontString.GetUnboundedStringWidthForText then
		return fontString:GetUnboundedStringWidthForText(text or "") or 0
	end

	local previousText = fontString:GetText()
	fontString:SetText(text or "")
	local width
	if fontString.GetUnboundedStringWidth then
		width = fontString:GetUnboundedStringWidth()
	else
		width = fontString:GetStringWidth()
	end
	fontString:SetText(previousText or "")
	return width or 0
end

local function getResultTypeVisualState(resultType)
	if resultType == "blacklist" or resultType == "leaver" then
		return "red"
	end
	if resultType == NETEASE_NEWBIE then
		return "newbie"
	end
	local socialState = GF.GetSocialTypeVisualState and GF.GetSocialTypeVisualState(resultType)
	if socialState then
		return socialState
	end
	return nil
end

getBrowseRowVisualState = function(row)
	if not row then
		return "normal"
	end
	if row._isDelisted == true or row._applicationVisualState == "cancelled" or row._applicationVisualState == "declined" then
		return "grey"
	end
	local titleEntry = row._titleEntry
	if row._gfBlocklistRetiring == true then
		return "red"
	end
	if row._resultType == "blacklist"
		or (titleEntry and titleEntry._gfNetEaseHasBlocklist == true)
	then
		return "red"
	end
	-- Operational feedback and warnings must survive relationship changes.
	if row._resultType == "leaver" or (titleEntry and titleEntry.hasLeaver == true) then
		return "red"
	end
	if row._applicationVisualState == "green" then
		return "green"
	end
	-- Application rows retain their existing operational background instead of
	-- being recolored merely because their content is censored.
	if row._isCensored == true and row._hasApplication == true then
		return getResultTypeVisualState(row._resultType) or "normal"
	end
	if row._isCensored == true then
		return "censored"
	end
	local identityProjection = titleEntry
		and titleEntry._gfNetEaseGroupProjection
	if row._resultType == NETEASE_NEWBIE
		or (identityProjection and identityProjection.hasNewbie == true)
	then
		return "newbie"
	end
	if row._resultType == GF.RESULT_TYPE_CURRENT_GROUP then
		return "blue"
	end
	-- An explicit leader preference outranks a friend anywhere in the group.
	if row._starredLeader == true then
		return "starred"
	end
	return getResultTypeVisualState(row._resultType) or "normal"
end

local function getBrowseRowHoverColorForState(state)
	if GF.GetListBackgroundOverlayColor then
		return GF.GetListBackgroundOverlayColor(state, "hover")
	end
	if state == "red" then
		return ROW_HOVER_RED_COLOR
	end
	if state == "blue" then
		return ROW_HOVER_BLUE_COLOR
	end
	if state == "grey" then
		return ROW_HOVER_GREY_COLOR
	end
	return ROW_HOVER_COLOR
end

local function paintTitleCol(row, text, dc, applyColors)
	if row._starredLeader or row.starredIcon then placeTextCell(row, row.title, "title") end
	local col = rowCol(row, "title")
	if not col or not row.title then
		return false
	end
	setRowEllipsis(row.title, text, getTextCellWidth(row, "title", col))
	if applyColors then
		if row._isCensored == true and not dc then
			local color = GF.CENSORED_RESULT_REVEAL_COLOR
				or { r = 233 / 255, g = 213 / 255, b = 255 / 255 }
			setDelistedOrColor(row.title, nil, color.r, color.g, color.b)
		else
			local color = getTextStyle().title
			setDelistedOrColor(row.title, dc, color.r, color.g, color.b)
		end
	end
	return true
end

local function paintTypeCol(row, col, dc)
	if not row or not col then
		return
	end
	local resultType = row._resultDisplayType or row._resultType
	local text = row._typeText or ""
	if resultType == NETEASE_LOADING then
		if row.typeIcon then
			row.typeIcon:Hide()
		end
		if row.typeText then
			row.typeText:SetText("")
			row.typeText:Hide()
		end
		if row.typeSpinner and col then
			row.typeSpinner:ClearAllPoints()
			row.typeSpinner:SetPoint(
				"CENTER", row, "LEFT", col.x + (col.width / 2), getRowContentOffsetY())
			GF.UI.StartPendingSpinner(row.typeSpinner, getTypeIconSize())
		end
		return
	end
	if row.typeSpinner and GF.UI and GF.UI.StopPendingSpinner then
		GF.UI.StopPendingSpinner(row.typeSpinner)
	end
	if not resultType or text == "" then
		if row.typeIcon then
			row.typeIcon:Hide()
		end
		if row.typeText then
			row.typeText:SetText("")
			row.typeText:Hide()
		end
		return
	end

	local icon = row.typeIcon
	local fontString = row.typeText
	if not fontString then
		return
	end
	fontString:Show()
	fontString:SetText(text)
	fontString:SetJustifyH("LEFT")
	local typeDisabledColor = dc
	if resultType == GF.RESULT_TYPE_CURRENT_GROUP then
		typeDisabledColor = nil
	end
	local color = typeDisabledColor or TYPE_TEXT_COLOR[resultType] or HIGHLIGHT_FONT_COLOR
	if color then
		fontString:SetTextColor(color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, color.a or color[4] or 1)
	end

	local hasIcon = icon and TYPE_ICON_TEXTURE[resultType]
	local typeIconSize = getTypeIconSize()
	local iconW = hasIcon and typeIconSize or 0
	local gap = hasIcon and TYPE_ICON_GAP or 0
	local maxTextW = math.max(1, col.width - iconW - gap)
	-- Center only the content visible in this row; unrelated long labels must
	-- not shift this icon-text group away from the column center.
	local textW = measureTypeLabel(fontString, text)
	textW = math.min(math.max(1, math.ceil(textW or 0)), maxTextW)
	local groupW = iconW + gap + textW
	local x = col.x + math.max(0, math.floor((col.width - groupW) / 2))

	if hasIcon then
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", row, "LEFT", x, getRowContentOffsetY())
		icon:SetSize(typeIconSize, typeIconSize)
		icon:SetTexture(TYPE_ICON_TEXTURE[resultType])
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetDesaturated(typeDisabledColor ~= nil)
		icon:SetAlpha(typeDisabledColor and 0.5 or 1)
		icon:Show()
	elseif icon then
		icon:Hide()
	end

	fontString:ClearAllPoints()
	fontString:SetPoint("LEFT", row, "LEFT", x + iconW + gap, getRowContentOffsetY())
	setRowEllipsis(fontString, text, math.max(1, col.x + col.width - (x + iconW + gap)))
end

function LR:RefreshTitleFromEntry(row, entry)
	local info = entry and entry.info
	if not (row and info) then
		return
	end
	row._titleEntry = entry
	row._titleInfo = info
	local port = presentationPort()
	row._isCensored = port and port:IsCensored(info) or nil
	if port and port.GetStarredLeader then row._starredLeader = port:GetStarredLeader(info) ~= nil end
	row._resultType = resolveResultType(row, info, entry)
	row._resultDisplayType = resolveResultDisplayType(row, info, entry, row._resultType)
	row._typeText = getResultTypeLabel(row._resultDisplayType)
	local disabledColor = getTitleDelistedColor(info)
	paintTitleCol(row, row._titleText or "", disabledColor, true)
	paintTypeCol(row, rowCol(row, "type"), disabledColor)
	self:UpdateRowBackgrounds(row)
end

local function paintCachedCell(row, field, columnID, text, color)
	local fontString = row[field]
	if paintColText(row, columnID, fontString, text) and color then
		fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
	end
end

local function paintRowFromCache(row, opts)
	opts = opts or {}
	local dc = opts.dc
	paintTitleCol(row, row._titleText, dc, opts.applyColors)
	local typeCol = rowCol(row, "type")
	if typeCol then
		paintTypeCol(row, typeCol, dc)
	else
		row.typeText:SetText("")
		row.typeText:Hide()
		row.typeIcon:Hide()
	end

	local applicationPainted
	if opts.applyAppState
		and row._gfCurrentGroupProjection ~= true
		and rowCol(row, "comment") and row.resultID
	then
		applicationPainted = LR:ApplyApplicationState(
			row,
			row.resultID,
			dc,
			opts.deferVisual,
			opts.deferRoleUpdate
		)
	end
	if rowCol(row, "comment") and not applicationPainted then
		local commentColor = dc
		if not commentColor and row._isCensored == true then
			commentColor = GF.CENSORED_RESULT_COMMENT_COLOR
		end
		refreshCommentCell(row, row._commentText, commentColor)
	end

	local colorize = opts.applyColors
	local activityTint = colorize and (dc or getTextStyle().activity) or nil
	local itemLevelTint = colorize and (dc or TEXT_STYLE.itemLevel) or nil
	paintCachedCell(row, "activity", "activity", row._activityText, activityTint)
	paintCachedCell(row, "metaIL", "ilvl", row._metaILText, itemLevelTint)

	local scoreTint
	if colorize then
		scoreTint = dc or opts.scoreColor or GOLD
	end
	local scoreCol = rowCol(row, "score")
	if scoreCol and row._metaScoreText then
		local scoreText = row._metaScoreText
		if dc or row._applicationDisplayState == "declined"
			or row._applicationDisplayState == "cancelled"
			or row._applicationDisplayState == "departed" then
			scoreText = plainScoreText(scoreText)
		end
		setRowEllipsis(row.metaScore, scoreText, scoreCol.width)
		applyColumnJustify(row.metaScore, scoreCol)
		if scoreTint then
			row.metaScore:SetTextColor(scoreTint.r, scoreTint.g, scoreTint.b)
		end
		row.metaScore:Show()
	elseif row.metaScore then
		row.metaScore:SetText("")
		row.metaScore:Hide()
	end

	if row._starredLeader or row.starredLeaderIcon then
		placeTextCell(row, row.metaLeader, "leader")
	end
	paintCachedCell(row, "metaLeader", "leader", row._metaLeaderText, colorize and (dc or opts.leaderColor) or nil)
	if row._applicationDisplayState == "declined"
		or row._applicationDisplayState == "cancelled"
		or row._applicationDisplayState == "departed"
	then
		applyUnavailableRowContentColor(row)
	end
end

function LR:LayoutOnly(row, width)
	if not (row and row.title) then
		return
	end
	if tonumber(width) and width > 0 then
		row:SetWidth(width)
	end
	local height = GF.GetBrowseRowH and GF.GetBrowseRowH() or GF.BROWSE_ROW_H or 34
	row:SetHeight(height)
	layoutRowSelectedTexture(row)
	layoutRowHoverTextures(row)
	self:LayoutRow(row)
	local disabledColor = getTitleDelistedColor(row._titleInfo)
	local paintOptions = clearReusableTable(row._gfPaintOptions)
	row._gfPaintOptions = paintOptions
	paintOptions.applyAppState = row.resultID ~= nil
		and row._gfCurrentGroupProjection ~= true
	paintOptions.applyColors = disabledColor ~= nil
	paintOptions.dc = disabledColor
	paintRowFromCache(row, paintOptions)
end


-- 结果行构建、申请交互与快照绑定入口

local ROW_TEXT_FIELDS = {
	{ field = "title", template = "GameFontNormal" },
	{ field = "typeText", template = "GameFontHighlightSmall" },
	{ field = "metaIL", template = "GameFontDisableSmall" },
	{ field = "comment", template = "GameFontHighlightSmall" },
	{ field = "activity", template = "GameFontDisableSmall" },
	{ field = "metaScore", template = "GameFontDisableSmall" },
	{ field = "metaLeader", template = "GameFontDisableSmall" },
}

local function createOneLineText(row, template, justify)
	local fontString = GF.UI.CreateFontString(row, "OVERLAY", template)
	fontString:SetJustifyH(justify or "LEFT")
	fontString:SetMaxLines(1)
	fontString:SetWordWrap(false)
	return fontString
end

hideApplicationCountdown = function(row)
	local clock = row and row.appCountdown
	if not clock then return end
	for _, character in ipairs(clock.characters) do character:Hide() end
	if clock.suffix then clock.suffix:Hide() end
	clock.layoutLeft = nil
	row._appCountdownVisible = nil
end

local function createHiddenTexture(owner, layer)
	local texture = owner:CreateTexture(nil, layer)
	texture:Hide()
	return texture
end

local function showFallbackListTooltip(row, resultID)
	local port = presentationPort()
	if not port or not port:IsLiveResult(resultID) then
		return false
	end
	if GF.Font and GF.Font.BeginTooltipFont then
		GF.Font.BeginTooltipFont(GameTooltip)
	end
	if not port:ShowNativeTooltip(GameTooltip, row, resultID) then
		return false
	end
	if GF.Font and GF.Font.ApplyTooltipFont then
		GF.Font.ApplyTooltipFont(GameTooltip)
	end
	return true
end

local function listRowOnEnter(row)
	if row._gfBlocklistRetiring == true
		or row._gfExpiredRetiring == true
	then
		return
	end
	row._listMouseOver = true
	if isListHoverHighlightEnabled() and shouldShowListRowHover(row) then
		setRowHoverShown(row, true)
	end
	local resultID = row.resultID
	if row._gfCurrentGroupProjection ~= true then
		if not resultID then
			return
		end
		LR:SyncDelistedFromAPI(row)
		if row._gfExpiredRetiring == true then
			return
		end
	end
	if not isListHoverTooltipEnabled() then
		return
	end
	cancelHoverTooltipHide()
	local tooltipIdentity = row._gfProjectionKey or resultID
	if lastTooltipResultID == tooltipIdentity and GameTooltip:IsShown() then
		return
	end
	local shown = false
	if row._gfCurrentGroupProjection == true
		and GF.ListTooltip
		and GF.ListTooltip.ShowCurrentGroupProjection
	then
		shown = GF.ListTooltip:ShowCurrentGroupProjection(
			GameTooltip, row._gfCurrentGroupElement, row) == true
	elseif resultID and GF.ListTooltip and GF.ListTooltip.Show then
		GF.ListTooltip:Show(GameTooltip, resultID, row)
		shown = true
	elseif resultID then
		shown = showFallbackListTooltip(row, resultID)
	end
	if shown then
		lastTooltipResultID = tooltipIdentity
	end
end

local function listRowOnLeave(row)
	row._listMouseOver = nil
	setRowHoverShown(row, shouldKeepListRowHover(row))
	if isListHoverTooltipEnabled() then
		scheduleHoverTooltipHide(row)
	end
end

local function listRowOnHide(row)
	StopApplicationFeedbackTimer(row)
	StopApplicationPendingSpinner(row.appSpinner)
	hideApplicationCountdown(row)
	if row._appCommentLayout then row._appCommentLayout.state = nil end
	if row.appCancel then row.appCancel._gfCancelInteraction = nil end
	if row.appRetry then row.appRetry._pressedIntent = nil end
end

local function listRowOnShow(row)
	if row.resultID and not row._gfCurrentGroupProjection then
		LR:ApplyApplicationState(row, row.resultID, nil, true, true)
	end
end

function LR:Create(parent, index, existingRow)
	local row = existingRow or CreateFrame("Button", "GroupFinderAddonListRow" .. (index or 0), parent)
	if row._gfInited then
		return row
	end
	local measuredWidth = parent and parent:GetWidth() or row:GetWidth() or 0
	local initialWidth = measuredWidth > 0 and measuredWidth or 400
	local initialHeight = GF.GetBrowseRowH and GF.GetBrowseRowH() or GF.BROWSE_ROW_H or 34
	row:SetSize(initialWidth, initialHeight)

	row.backgroundPieces = createBrowseRowBackgroundPieces(row, -2)
	row.backgroundTransitionPieces = createBrowseRowBackgroundPieces(row, -1)
	setBrowseRowBackgroundPiecesShown(row.backgroundTransitionPieces, false)
	setBrowseRowBackground(row, "normal")

	createRowHoverTextures(row)
	createRowSelectedTexture(row)

	row.appPending = createOneLineText(row, "GameFontHighlight", "CENTER")
	row.appPending:SetJustifyH("CENTER")
	row.appPending:SetJustifyV("MIDDLE")
	row.appPending:Hide()
	if GF.Font and GF.Font.Track then
		GF.Font.Track(row.appPending, "GameFontHighlight")
	end
	row.appStatusIcon = row:CreateTexture(nil, "OVERLAY")
	row.appStatusIcon:SetSize(APPLICATION_STATUS_ICON_SIZE, APPLICATION_STATUS_ICON_SIZE)
	row.appStatusIcon:Hide()
	row.appSpinner = CreateApplicationPendingSpinner(row)
	row.appCancelHost = CreateFrame("Frame", nil, row)
	row.appCancelHost:SetSize(APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE, APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE)
	row.appCancelHost:SetFrameLevel(row:GetFrameLevel() + 4)
	row.appCancelHost:Hide()
	row.appCancel = CreateApplicationCancelButton(row.appCancelHost)
	row.appCancel._gfRow = row
	if row.appSpinner then
		row.appSpinner:Hide()
	end

	for _, definition in ipairs(ROW_TEXT_FIELDS) do
		local fontString = createOneLineText(row, definition.template, definition.justify)
		fontString._gfFontSizeOverride = GF.BROWSE_ROW_TEXT_SIZE or 13
		if GF.Font and GF.Font.ApplyToFontString then
			GF.Font.ApplyToFontString(fontString, definition.template)
		end
		row[definition.field] = fontString
	end

	row.typeIcon = createHiddenTexture(row, "ARTWORK")
	if row.typeIcon.SetTexelSnappingBias then
		row.typeIcon:SetTexelSnappingBias(0)
	end
	if row.typeIcon.SetSnapToPixelGrid then
		row.typeIcon:SetSnapToPixelGrid(false)
	end
	local initialTypeIconSize = getTypeIconSize()
	row.typeIcon:SetSize(initialTypeIconSize, initialTypeIconSize)
	row.typeSpinner = GF.UI and GF.UI.CreatePendingSpinner
		and GF.UI.CreatePendingSpinner(row, initialTypeIconSize) or nil
	if row.typeSpinner then
		row.typeSpinner:Hide()
	end

	row.voiceIcon = createHiddenTexture(row, "ARTWORK")
	row.voiceIcon:SetSize(16, 14)
	row.voiceIcon:SetAtlas("groupfinder-icon-voice")

	row.roles = GF.RoleDisplay:Create(row)
	for _, field in ipairs({ "resultIndex", "resultID", "categoryID" }) do
		row[field] = nil
	end
	row:SetScript("OnEnter", listRowOnEnter)
	row:SetScript("OnLeave", listRowOnLeave)
	row:HookScript("OnHide", listRowOnHide)
	row:HookScript("OnShow", listRowOnShow)

	row._gfInited = true
	return row
end

function LR:EnsureRow(row)
	if row == nil or row._gfInited then
		return row
	end
	return self:Create(row:GetParent(), 0, row)
end

local function resolveBoundResult(elementData)
	local resultID = elementData.resultID
	local index = elementData.dataIndex
	if resultID then
		-- Wrapper dataIndex is a layout hint.  resultID owns identity and must be
		-- resolved again because a stable wrapper can move while ScrollBox still
		-- holds a previously initialized physical frame.
		index = GF.Result:GetIndexForResultID(resultID)
	elseif not resultID and index then
		resultID = GF.Result:GetResultID(index)
	end
	return resultID, index
end

local function loadBoundEntry(resultID, index, loadPlayers)
	local port = presentationPort()
	if not port then
		return nil, index
	end
	return port:GetEntry(index, resultID, { loadPlayers = loadPlayers })
end

function LR:BindElement(row, elementData, panel, opts)
	opts = opts or {}
	if not (row and elementData and panel) then
		return false
	end
	row._gfCurrentGroupProjection = nil
	row._gfCurrentGroupElement = nil
	row._gfProjectionKey = elementData.projectionKey
	local resultID, index = resolveBoundResult(elementData)
	row._gfCensoredDebugPreview = nil
	row._gfDebugResultPreview = nil
	local measuredWidth = panel.scrollList and panel.scrollList:GetLayoutWidth() or panel._lastLayoutW or 0
	local layoutW = measuredWidth > 0 and measuredWidth or 400
	panel._lastLayoutW = layoutW
	row:SetWidth(layoutW)

	local loadPlayers = opts.loadPlayers == true and not opts.deferRoles
	local entry
	entry, index = loadBoundEntry(resultID, index, loadPlayers)
	if not entry or not entry.info or not index then
		return false
	end
	local fallbackCategory = panel.selection and panel.selection.categoryID
	local port = presentationPort()
	local rowCat = port and port:ResolveRowCategory(index, fallbackCategory)
		or fallbackCategory
	local dataOptions = clearReusableTable(row._gfSetDataOptions)
	row._gfSetDataOptions = dataOptions
	dataOptions.deferRoles = opts.deferRoles ~= false
	dataOptions.deferFinalVisual = true
	dataOptions.skipLayout = opts.skipLayout
	dataOptions.layoutW = layoutW
	local wasBound = self:SetData(row, index, rowCat, entry, dataOptions)
	if wasBound ~= true then
		return false
	end
	if rowHasRenderedBadListingText(row) then
		row:Hide()
		dropRenderedBadResult(panel, resultID)
		return false
	end
	local selected = panel.selectedResultID ~= nil and row.resultID == panel.selectedResultID
	row._isSelected = selected or nil
	if selected then
		panel._selectedRow = row
		panel.selectedResult = row.resultIndex
	elseif panel._selectedRow == row then
		panel._selectedRow = nil
	end
	row:SetWidth(layoutW)
	if panel.WireOneRow then
		panel:WireOneRow(row)
	end
	if row._deferRoles == true then
		self:UpdateRoles(row, entry, row.categoryID, true)
	end
	self:UpdateRowBackgrounds(row)
	return true
end

function LR:BindCurrentGroupProjection(row, elementData, panel, opts)
	opts = opts or {}
	if not (row and type(elementData) == "table" and panel) then
		return false
	end
	local entry = elementData.entry
	if not (type(entry) == "table" and type(entry.info) == "table") then
		return false
	end
	entry._gfCurrentGroupProjection = true
	row._gfCensoredDebugPreview = nil
	row._gfDebugResultPreview = nil
	row._gfCurrentGroupProjection = true
	row._gfCurrentGroupElement = elementData
	row._gfProjectionKey = elementData.projectionKey
	local measuredWidth = panel.scrollList
		and panel.scrollList:GetLayoutWidth() or panel._lastLayoutW or 0
	local layoutW = measuredWidth > 0 and measuredWidth or 400
	panel._lastLayoutW = layoutW
	row:SetWidth(layoutW)
	local dataOptions = clearReusableTable(row._gfSetDataOptions)
	row._gfSetDataOptions = dataOptions
	dataOptions.deferRoles = opts.deferRoles ~= false
	dataOptions.deferFinalVisual = true
	dataOptions.layoutW = layoutW
	dataOptions.displayComment = elementData.displayComment
	dataOptions.displayVoiceChat = elementData.displayVoiceChat
	dataOptions.displayVoiceShown = elementData.displayVoiceShown
	dataOptions.displayCommentProvided = elementData.displayCommentProvided
	dataOptions.displayVoiceChatProvided =
		elementData.displayVoiceChatProvided
	dataOptions.displayVoiceShownProvided =
		elementData.displayVoiceShownProvided
	local bound = self:SetData(
		row,
		nil,
		elementData.categoryID or entry.categoryID,
		entry,
		dataOptions)
	if bound ~= true then
		return false
	end
	row.resultIndex = nil
	row.resultID = elementData.resultID or entry.resultID
	row._gfCurrentGroupProjection = true
	row._gfCurrentGroupElement = elementData
	row._gfProjectionKey = elementData.projectionKey
	local displayName = elementData.displayName
	if isSecretLfgText(displayName) or displayName ~= nil then
		row._titleText = displayName
		row._titleEntry = entry
		row._titleInfo = entry.info
		paintTitleCol(
			row,
			displayName,
			getTitleDelistedColor(entry.info),
			true)
	end
	local displayComment = elementData.displayComment
	if isSecretLfgText(displayComment) or displayComment ~= nil then
		row._commentText = displayComment
		refreshCommentCell(row, displayComment)
	end
	row._gfBlocklistRetiring = nil
	self:ResetExpiredRemovalFade(row)
	row._isSelected = nil
	self:ApplyApplicationState(row, nil, nil, true, true)
	self:UpdateRoles(row, entry, row.categoryID, true)
	self:UpdateRowBackgrounds(row)
	row:SetWidth(layoutW)
	if panel.WireOneRow then
		panel:WireOneRow(row)
	end
	return true
end

local function isDeclinedApplicationStatus(status)
	return status == "declined" or status == "declined_delisted" or status == "declined_full"
end

local function isCancelledApplicationStatus(status)
	return status == "cancelled" or status == "failed" or status == "timedout" or status == "invitedeclined"
end

local function getApplicationDisplayState(state)
	local port = presentationPort()
	if port and port.ResolveApplicationDisplayState then
		return port:ResolveApplicationDisplayState(state)
	end
	if not state or not state.isApplication then
		return nil
	end
	if state.isDepartedApplication == true then
		return "departed"
	end
	local a, p = state.appStatus, state.pendingStatus
	if a == "inviteaccepted" or p == "inviteaccepted" then
		return "joined"
	end
	if a == "invited" or p == "invited" then
		return "invited"
	end
	if state.isActiveApp then
		return "pending"
	end
	if state.isDeclined or isDeclinedApplicationStatus(a) or isDeclinedApplicationStatus(p) then
		return "declined"
	end
	if isCancelledApplicationStatus(a) or isCancelledApplicationStatus(p) then
		return "cancelled"
	end
	return nil
end

local function FormatApplicationCountdown(seconds)
	seconds = math.max(0, math.ceil(tonumber(seconds) or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function getApplicationRemainingSeconds(state)
	local duration = tonumber(state and state.appDuration)
	if duration and duration >= 0 and duration <= APPLICATION_TIMEOUT_SECONDS then
		return duration
	end
	return APPLICATION_TIMEOUT_SECONDS
end

local function getApplicationText(displayState, remainingSeconds)
	local L = GF.L or {}
	local actionText = {
		cancelling = L.APP_STATE_CANCELLING or "正在取消",
		waiting_confirm = L.APP_STATE_WAITING_CONFIRM or "等待确认",
		waiting_update = L.APP_STATE_WAITING_UPDATE or "等待更新",
		auto_cancelling = L.APP_STATE_AUTO_CANCELLING or "自动取消",
		cancel_failed = L.APPLY_CANCEL_FAILED or "取消失败",
		retry = L.APPLY_RETRY or "重新申请",
	}
	if actionText[displayState] then return actionText[displayState] end
	if displayState == "pending" then
		return string.format(L.APP_STATE_PENDING_FMT or "待定 %s", FormatApplicationCountdown(remainingSeconds))
	end
	if displayState == "declined" then
		return L.APP_STATE_DECLINED or "被拒绝"
	end
	if displayState == "cancelled" then
		return L.APP_STATE_CANCELLED or "已取消"
	end
	if displayState == "joined" then
		return L.APP_STATE_JOINED or "已加入"
	end
	if displayState == "invited" then
		return L.APP_STATE_INVITED or "待接受"
	end
	if displayState == "departed" then
		return L.APP_STATE_LEFT_GROUP or "已离队"
	end
	return nil
end

local function getApplicationTextColor(displayState)
	if displayState == "pending" or displayState == "invited"
		or displayState == "joined"
	then
		return APPLICATION_PENDING_TEXT_COLOR
	end
	if displayState == "declined" or displayState == "cancel_failed" then
		return APPLICATION_DECLINED_TEXT_COLOR
	end
	if displayState == "cancelled" or displayState == "departed" then
		return APPLICATION_CANCELLED_TEXT_COLOR
	end
	return APPLICATION_PENDING_TEXT_COLOR
end

local function prepareApplicationCountdown(row, remainingSeconds)
	-- A bounded, per-physical-row pool. Glyph widths never determine anchors.
	local clock = row.appCountdown
	if not clock then
		clock = { characters = {} }
		row.appCountdown = clock
	end
	local format = (GF.L or {}).APP_STATE_PENDING_FMT or "待定 %s"
	local fontPath, fontSize, fontFlags = row.appPending:GetFont()
	if clock.format ~= format or clock.fontPath ~= fontPath
		or clock.fontSize ~= fontSize or clock.fontFlags ~= fontFlags
	then
		local first, last = format:find("%s", 1, true)
		clock.prefix = first and format:sub(1, first - 1) or format
		clock.suffixText = last and format:sub(last + 1) or ""
		clock.prefixWidth = math.ceil(measureTypeLabel(row.appPending, clock.prefix))
		clock.suffixWidth = math.ceil(measureTypeLabel(row.appPending, clock.suffixText))
		local digitWidth = 1
		for digit = 0, 9 do
			digitWidth = math.max(digitWidth,
				math.ceil(measureTypeLabel(row.appPending, tostring(digit))))
		end
		clock.digitWidth = digitWidth
		clock.colonWidth = math.max(1, math.ceil(measureTypeLabel(row.appPending, ":")))
		clock.format, clock.fontPath = format, fontPath
		clock.fontSize, clock.fontFlags = fontSize, fontFlags
		clock.layoutLeft = nil
	end
	local text = FormatApplicationCountdown(remainingSeconds)
	clock.width = 0
	clock.count = #text
	for index = 1, clock.count do
		local character = clock.characters[index]
		if not character then
			character = createOneLineText(row, "GameFontHighlight", "CENTER")
			character:SetJustifyV("MIDDLE")
			local color = APPLICATION_PENDING_TEXT_COLOR
			character:SetTextColor(color.r, color.g, color.b, color.a)
			clock.characters[index] = character
			clock.layoutLeft = nil
		end
		local value = text:sub(index, index)
		if character:GetText() ~= value then character:SetText(value) end
		clock.width = clock.width + (value == ":" and clock.colonWidth or clock.digitWidth)
	end
	for index = clock.count + 1, #clock.characters do clock.characters[index]:Hide() end
	if clock.suffixText ~= "" and not clock.suffix then
		clock.suffix = createOneLineText(row, "GameFontHighlight", "LEFT")
		clock.suffix:SetJustifyV("MIDDLE")
		local color = APPLICATION_PENDING_TEXT_COLOR
		clock.suffix:SetTextColor(color.r, color.g, color.b, color.a)
	end
	if clock.suffix then clock.suffix:SetText(clock.suffixText) end
	row.appPending:SetText(clock.prefix)
	row._appCountdownVisible = true
	return clock
end

local function layoutApplicationCountdown(row, clock, left, right, lineY, prefixWidth)
	row.appPending:SetShown(prefixWidth > 0)
	if clock.layoutLeft == left and clock.layoutRight == right
		and clock.layoutY == lineY and clock.layoutPrefixWidth == prefixWidth
		and clock.layoutCount == clock.count
	then return end
	clock.layoutLeft, clock.layoutRight, clock.layoutY = left, right, lineY
	clock.layoutPrefixWidth, clock.layoutCount = prefixWidth, clock.count
	row.appPending:ClearAllPoints()
	row.appPending:SetPoint("LEFT", row, "LEFT", left, lineY)
	row.appPending:SetSize(math.max(1, prefixWidth), 18)
	row.appPending:SetJustifyH("LEFT")
	local x = left + prefixWidth
	for index = 1, clock.count do
		local character = clock.characters[index]
		local width = character:GetText() == ":" and clock.colonWidth or clock.digitWidth
		local visibleWidth = math.min(width, math.max(0, right - x))
		character:ClearAllPoints()
		character:SetPoint("LEFT", row, "LEFT", x, lineY)
		character:SetSize(math.max(1, visibleWidth), 18)
		character:SetShown(visibleWidth > 0)
		x = x + width
	end
	if clock.suffix then
		local width = math.min(clock.suffixWidth, math.max(0, right - x))
		clock.suffix:ClearAllPoints()
		clock.suffix:SetPoint("LEFT", row, "LEFT", x, lineY)
		clock.suffix:SetSize(math.max(1, width), 18)
		clock.suffix:SetShown(width > 0)
	end
end

local function LayoutApplicationComment(row, displayState, remainingSeconds)
	local col = rowCol(row, "comment")
	if not row or not row.appPending or not col then
		return
	end
	local layout = row._appCommentLayout
	if not layout then
		layout = {}
		row._appCommentLayout = layout
	end
	local lineY = getAppLineY(row)
	local showCancelButton = row._appShowCancel == true
	local spinning = displayState == "pending" or displayState == "cancelling"
		or displayState == "waiting_confirm" or displayState == "waiting_update"
		or displayState == "auto_cancelling"
	local buttonHost = row.appCancelHost or row.appCancel
	local button = row.appCancel
	local reservedWidth = showCancelButton and (APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE + APPLICATION_CANCEL_BUTTON_GAP) or 0
	local fullWidth = math.max(1, col.width - 4)
	local availableWidth = math.max(1, fullWidth - reservedWidth)
	-- Every status shares the full column center; the action is independent.
	-- Symmetric clearance limits oversized content before it reaches the action.
	local contentWidth = math.max(1, fullWidth - reservedWidth * 2)

	if row.comment then
		clearCommentText(row.comment)
		row.comment:Hide()
	end
	if row.voiceIcon then
		row.voiceIcon:Hide()
	end
	if buttonHost then
		local right = col.x + col.width - 2
		if layout.buttonHost ~= buttonHost or layout.buttonRight ~= right or layout.buttonY ~= lineY then
			buttonHost:ClearAllPoints()
			buttonHost:SetPoint("RIGHT", row, "LEFT", right, lineY)
			layout.buttonHost, layout.buttonRight, layout.buttonY = buttonHost, right, lineY
		end
		buttonHost:SetShown(showCancelButton)
	end
	if button then
		button.resultID = row.resultID
		button:SetShown(showCancelButton)
	end

	local statusIcon = row.appStatusIcon
	local pendingSpinner = row.appSpinner
	if displayState ~= "pending" then hideApplicationCountdown(row) end
	if not displayState then
		layout.state = nil
		if statusIcon then
			statusIcon:Hide()
		end
		StopApplicationPendingSpinner(pendingSpinner)
		row.appPending:ClearAllPoints()
		row.appPending:SetPoint("LEFT", row, "LEFT", col.x + 2, lineY)
		row.appPending:SetSize(availableWidth, 18)
		row.appPending:SetJustifyH("CENTER")
		return
	end

	local statusFrame
	if spinning then
		statusFrame = pendingSpinner
		if statusIcon then
			statusIcon:Hide()
		end
	else
		StopApplicationPendingSpinner(pendingSpinner)
		if statusIcon and displayState ~= "joined" then
			statusIcon:SetTexture(APPLICATION_ALERT_ICON_TEXTURE)
			statusIcon:SetTexCoord(0, 1, 0, 1)
			statusIcon:SetSize(APPLICATION_STATUS_ICON_SIZE, APPLICATION_STATUS_ICON_SIZE)
			statusFrame = statusIcon
		elseif statusIcon then
			statusIcon:Hide()
		end
	end

	local statusSize = statusFrame and (spinning and APPLICATION_PENDING_SPINNER_SIZE or APPLICATION_STATUS_ICON_SIZE) or 0
	local statusGap = statusFrame and APPLICATION_STATUS_ICON_GAP or 0
	local contentLeft = col.x + 2
	local maxTextWidth = math.max(1, contentWidth - statusSize - statusGap)
	local clock = displayState == "pending" and prepareApplicationCountdown(row, remainingSeconds) or nil
	local prefixWidth = clock and math.max(0,
		math.min(clock.prefixWidth, maxTextWidth - clock.width - clock.suffixWidth)) or nil
	local measuredTextWidth
	if clock then
		measuredTextWidth = prefixWidth + clock.width + clock.suffixWidth
	else
		local text = row.appPending:GetText() or ""
		local fontPath, fontSize, fontFlags = row.appPending:GetFont()
		if layout.text ~= text or layout.fontPath ~= fontPath
			or layout.fontSize ~= fontSize or layout.fontFlags ~= fontFlags
		then
			layout.textWidth = math.max(1, math.ceil(measureTypeLabel(row.appPending, text)))
			layout.text, layout.fontPath = text, fontPath
			layout.fontSize, layout.fontFlags = fontSize, fontFlags
		end
		measuredTextWidth = layout.textWidth
	end
	local visualTextWidth = math.min(measuredTextWidth, maxTextWidth)
	local groupWidth = visualTextWidth + statusSize + statusGap
	local textLeftOffset = contentLeft
		+ (fullWidth - groupWidth) / 2
		+ statusSize
		+ statusGap
	local minTextLeft = contentLeft + statusSize + statusGap
	local maxTextLeft = contentLeft + availableWidth - visualTextWidth
	textLeftOffset = math.max(minTextLeft, math.min(maxTextLeft, textLeftOffset))
	local relayout = layout.state ~= displayState or layout.left ~= textLeftOffset
		or layout.width ~= visualTextWidth or layout.y ~= lineY or layout.statusFrame ~= statusFrame

	if clock then
		layoutApplicationCountdown(row, clock, textLeftOffset,
			contentLeft + availableWidth, lineY, prefixWidth)
	elseif relayout then
		row.appPending:ClearAllPoints()
		row.appPending:SetPoint("LEFT", row, "LEFT", textLeftOffset, lineY)
		row.appPending:SetSize(visualTextWidth, 18)
		row.appPending:SetJustifyH("LEFT")
	end
	if statusFrame then
		if relayout then
			statusFrame:ClearAllPoints()
			statusFrame:SetPoint("RIGHT", row.appPending, "LEFT", -statusGap, 0)
		end
		if spinning then
			StartApplicationPendingSpinner(statusFrame)
		else
			statusFrame:Show()
		end
	end
	layout.state, layout.left, layout.width = displayState, textLeftOffset, visualTextWidth
	layout.y, layout.statusFrame = lineY, statusFrame
end

local function hideAppCluster(row)
	StopApplicationFeedbackTimer(row)
	hideApplicationCountdown(row)
	if row._appCommentLayout then clearReusableTable(row._appCommentLayout) end
	if row.appRetry then row.appRetry:Hide(); row.appRetry._intent = nil end
	row._appShowCancel = nil
	if row.appPending then
		row.appPending:SetText("")
		row.appPending:Hide()
	end
	if row.appStatusIcon then
		row.appStatusIcon:Hide()
	end
	if row.appSpinner then
		StopApplicationPendingSpinner(row.appSpinner)
	end
	if row.appCancelHost then
		row.appCancelHost:Hide()
	end
	if row.appCancel then
		row.appCancel.resultID = nil
		row.appCancel:Hide()
	end
	row._isAppActive = nil
	row._hasApplication = nil
	row._applicationVisualState = nil
	row._applicationDisplayState = nil
	row._appExpiryShown = nil
	row._appExpiration = nil
	row._appReservedW = nil
end

local function resolveApplicationVisualState(state)
	local displayState = getApplicationDisplayState(state)
	if displayState == "declined" then
		return "declined"
	end
	if displayState == "cancelled" or displayState == "departed" then
		return "cancelled"
	end
	return nil
end

function LR:TickExpiry(row)
	if not (row and row._appExpiryShown and row.appPending) then
		return
	end
	local left = math.max(0, (row._appExpiration or 0) - GetTime())
	local displayState = left > 0 and "pending" or "waiting_update"
	row.appPending:SetText(getApplicationText(displayState, left))
	row.appPending:Show()
	if left <= 0 then row._appExpiryShown = nil end
	LayoutApplicationComment(row, displayState, left)
end

local function clearApplicationPresentation(row, delistedColor, restoreComment)
	if row and row.appPending then
		hideAppCluster(row)
		if restoreComment then
			relayoutCommentText(row, delistedColor)
		end
	end
	return false
end

function LR:ShowApplicationRetry(row, resultID, intent, col)
	if not row.appRetry then
		local button = GF.UI.CreatePanelButton(row, "", GF.PANEL_BUTTON_STANDARD_W)
		button:SetFrameLevel(row:GetFrameLevel() + 5)
		button:SetScript("OnMouseDown", function(self)
			self._pressedIntent = self._intent
			self._pressedGeneration = row._gfBindingGeneration
		end)
		button:SetScript("OnClick", function(self)
			if self._pressedIntent ~= self._intent or self._pressedGeneration ~= row._gfBindingGeneration then return end
			local expected = self._intent
			self._pressedIntent = nil
			self:SetEnabled(false)
			local port = presentationPort()
			if port then port:RetryApplication(row.resultID, expected) end
			LR:ApplyApplicationState(row, row.resultID)
		end)
		button:HookScript("OnHide", function(self) self._pressedIntent = nil end)
		row.appRetry = button
	end
	row.appRetry._intent = intent
	row.appRetry:SetText((GF.L or {}).APPLY_RETRY or "重新申请")
	local width = math.min(GF.PANEL_BUTTON_STANDARD_W or 100, math.max(1, col.width - 4))
	local x, y = col.x + col.width / 2, getAppLineY(row)
	if row.appRetry._gfLayoutWidth ~= width then
		row.appRetry:SetWidth(width)
		row.appRetry._gfLayoutWidth = width
	end
	if row.appRetry._gfLayoutX ~= x or row.appRetry._gfLayoutY ~= y then
		row.appRetry:ClearAllPoints()
		row.appRetry:SetPoint("CENTER", row, "LEFT", x, y)
		row.appRetry._gfLayoutX, row.appRetry._gfLayoutY = x, y
	end
	row.appRetry:SetEnabled(true)
	row.appRetry:Show()
end

local function ScheduleApplicationFeedback(row, projection)
	if row._appFeedbackRequest == projection.feedbackRequest and row._appFeedbackTimer then return end
	StopApplicationFeedbackTimer(row)
	if not projection.feedbackAt or not C_Timer or not C_Timer.NewTimer
		or (row.IsVisible and not row:IsVisible()) then return end
	local resultID, generation = row.resultID, row._gfBindingGeneration
	local request = projection.feedbackRequest
	row._appFeedbackRequest = request
	row._appFeedbackTimer = C_Timer.NewTimer(math.max(0, projection.feedbackAt - GetTime()), function()
		if row._appFeedbackRequest ~= request then return end
		row._appFeedbackTimer, row._appFeedbackRequest = nil, nil
		if row.resultID == resultID and row._gfBindingGeneration == generation
			and not (row.IsVisible and not row:IsVisible()) then
			LR:ApplyApplicationState(row, resultID, nil, true, true)
		end
	end)
end

function LR:ApplyApplicationState(
	row, resultID, delistedColor, deferVisual, deferRoleUpdate)
	local port = presentationPort()
	if not (row and resultID and port) then
		return clearApplicationPresentation(row, delistedColor, true)
	end
	local projection = port:GetApplicationPresentation(resultID)
	if not projection then
		return clearApplicationPresentation(row, delistedColor, true)
	end
	local state = projection.state
	local displayState = projection.displayState
		or getApplicationDisplayState(state)
	local remainingSeconds = projection.remainingSeconds
		or (displayState == "pending"
			and getApplicationRemainingSeconds(state) or nil)
	local text = getApplicationText(displayState, remainingSeconds)
	local color = getApplicationTextColor(displayState)
	if not text then
		return clearApplicationPresentation(row, delistedColor, true)
	end
	local col = rowCol(row, "comment")
	if not col then
		return clearApplicationPresentation(row, delistedColor, false)
	end
	if row.appRetry and displayState ~= "retry" then row.appRetry:Hide() end
	ScheduleApplicationFeedback(row, projection)
	row._appShowCancel = projection.showCancel
	row.appPending:SetText(text)
	row.appPending:SetTextColor(color.r, color.g, color.b, color.a or 1)
	row.appPending:Show()
	LayoutApplicationComment(row, displayState, remainingSeconds)
	if displayState == "retry" then
		row.appPending:Hide()
		if row.appStatusIcon then row.appStatusIcon:Hide() end
		StopApplicationPendingSpinner(row.appSpinner)
		self:ShowApplicationRetry(row, resultID, projection.retryIntent, col)
	end
	row._appReservedW = col.width
	row._appExpiryShown = displayState == "pending" or nil
	row._appExpiration = row._appExpiryShown and (projection.appExpiration or (GetTime() + (remainingSeconds or 0))) or nil
	if row._appExpiryShown then
		port:EnsureApplicationExpiryTicker()
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if row.appCancel then
		row.appCancel._gfCancelReason = projection.cancelReason
		row.appCancel:SetEnabled(projection.canCancel == true)
	end
	row._isAppActive = state and state.isActiveApp == true or nil
	row._hasApplication = true
	row._applicationDisplayState = displayState
	row._applicationVisualState = projection.visualState
		or resolveApplicationVisualState(state)
	if displayState == "declined"
		or displayState == "cancelled"
		or displayState == "departed"
	then
		applyUnavailableRowContentColor(row)
		if deferRoleUpdate ~= true
			and row.roles and row.resultIndex and LR.UpdateRoles
		then
			LR:UpdateRoles(row, nil, row.categoryID, deferVisual)
		end
	end
	return true
end

function LR:UpdateRowBackgrounds(row)
	if not row then
		return
	end
	local visualState = getBrowseRowVisualState(row)
	if row._starredLeader or row.starredIcon or row.starredLeaderIcon then
		placeTextCell(row, row.title, "title")
		placeTextCell(row, row.metaLeader, "leader")
	end
	setStarredIconsDisabled(row, visualState == "grey"
		or row._applicationDisplayState == "departed")
	setBrowseRowBackground(row, visualState)
	updateBrowseRowTextTransitions(
		row, getBrowseVisualIdentity(row), visualState)
	local overlayState = row._applicationVisualState == "declined" and "red" or visualState
	setRowHoverTextureColor(row, getBrowseRowHoverColorForState(overlayState))
	setRowSelectedTextureState(row, overlayState)
	local mouseHover = row._listMouseOver == true
		and isListHoverHighlightEnabled()
		and shouldShowListRowHover(row)
	setRowHoverShown(row, shouldKeepListRowHover(row) or mouseHover)
	setRowSelectedShown(row, shouldShowRowSelected(row))
end

function LR:BeginBlocklistRetirement(row)
	if not row then
		return false
	end
	if self.ResetExpiredRemovalFade then
		self:ResetExpiredRemovalFade(row)
	end
	row._gfBlocklistRetiring = true
	row._listMouseOver = nil
	if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row) then
		GameTooltip:Hide()
	end
	self:UpdateRowBackgrounds(row)
	return true
end

function LR:ClearBlocklistRetirement(row)
	if not (row and row._gfBlocklistRetiring) then
		return false
	end
	row._gfBlocklistRetiring = nil
	self:UpdateRowBackgrounds(row)
	return true
end

function LR:ResetExpiredRemovalFade(row)
	if not row then
		return false
	end
	local fade = row._gfExpiredRemovalFade
	if fade and fade.IsPlaying and fade:IsPlaying() then
		fade:Stop()
	end
	row._gfExpiredRemovalFadeToken =
		(row._gfExpiredRemovalFadeToken or 0) + 1
	row._gfExpiredRetiring = nil
	row._gfExpiredRetirement = nil
	if row.SetAlpha then
		row:SetAlpha(1)
	end
	return true
end

local function ensureExpiredRemovalFade(row)
	if row._gfExpiredRemovalFade then
		return row._gfExpiredRemovalFade
	end
	if not (row and row.CreateAnimationGroup) then
		return nil
	end
	local fade = row:CreateAnimationGroup()
	local hold = fade:CreateAnimation("Alpha")
	local alpha = fade:CreateAnimation("Alpha")
	if not (hold and alpha) then
		return nil
	end
	hold:SetOrder(1)
	alpha:SetOrder(2)
	alpha:SetSmoothing("IN")
	fade:SetScript("OnFinished", function(group)
		if row._gfExpiredRemovalFadeToken == group._gfToken
			and row._gfExpiredRetirement == group._gfRetirement
		then
			row:SetAlpha(0)
		end
	end)
	fade._gfHold = hold
	fade._gfAlpha = alpha
	row._gfExpiredRemovalFade = fade
	return fade
end

function LR:PlayExpiredRemovalFade(row, retirement)
	if not (row and type(retirement) == "table") then
		return false
	end
	if row._gfBlocklistRetiring == true then
		self:ResetExpiredRemovalFade(row)
		return false
	end
	local existing = row._gfExpiredRetirement == retirement
	local existingFade = row._gfExpiredRemovalFade
	if existing and ((existingFade and existingFade.IsPlaying
		and existingFade:IsPlaying()) or row.GetAlpha and row:GetAlpha() <= 0)
	then
		return true
	end
	if row._gfResultRowIntroIdentity ~= nil
		and GF.UI and GF.UI.StopPopupOpenAnimation
	then
		GF.UI.StopPopupOpenAnimation(row)
		row._gfResultRowIntroIdentity = nil
	end
	self:ResetExpiredRemovalFade(row)
	row._gfExpiredRetiring = true
	row._gfExpiredRetirement = retirement
	row._listMouseOver = nil
	if row.appCancel and row.appCancel.SetEnabled then
		row.appCancel:SetEnabled(false)
	end
	if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row) then
		GameTooltip:Hide()
	end
	setRowHoverShown(row, false)
	setRowSelectedShown(row, false)
	local now = type(GetTime) == "function" and GetTime()
		or (retirement.startedAt or 0)
	local elapsed = math.max(0, now - (retirement.startedAt or now))
	local graySeconds = math.max(0, tonumber(retirement.graySeconds) or 0)
	local fadeSeconds = math.max(0.01,
		tonumber(retirement.fadeSeconds) or 0.01)
	local fadeElapsed = math.max(0, elapsed - graySeconds)
	if fadeElapsed >= fadeSeconds then
		row:SetAlpha(0)
		return true
	end
	local holdRemaining = math.max(0, graySeconds - elapsed)
	local startingAlpha = holdRemaining > 0
		and 1 or math.max(0, 1 - (fadeElapsed / fadeSeconds))
	local fadeRemaining = holdRemaining > 0
		and fadeSeconds or math.max(0.01, fadeSeconds - fadeElapsed)
	local fade = ensureExpiredRemovalFade(row)
	if not (fade and fade._gfHold and fade._gfAlpha) then
		row:SetAlpha(startingAlpha)
		return false
	end
	row._gfExpiredRemovalFadeToken =
		(row._gfExpiredRemovalFadeToken or 0) + 1
	local token = row._gfExpiredRemovalFadeToken
	row:SetAlpha(startingAlpha)
	fade._gfHold:SetFromAlpha(startingAlpha)
	fade._gfHold:SetToAlpha(startingAlpha)
	fade._gfHold:SetDuration(math.max(0.01, holdRemaining))
	fade._gfAlpha:SetFromAlpha(startingAlpha)
	fade._gfAlpha:SetToAlpha(0)
	fade._gfAlpha:SetDuration(fadeRemaining)
	fade._gfToken = token
	fade._gfRetirement = retirement
	fade:Play()
	return true
end

function LR:SetDelistedState(row, isDelisted, deferVisual)
	if row then
		row._isDelisted = isDelisted == true and true or nil
		if deferVisual ~= true then
			self:UpdateRowBackgrounds(row)
		end
	end
end

local function dropResultAndRefresh(resultID)
	local tab = GF.FindGroupTab
	local retire = tab and (tab.RetireExpiredResult or tab.DropFrozenResult)
	if not (retire and retire(tab, resultID)) then
		return false
	end
	if tab.RefreshList then
		tab:RefreshList({ preserveScroll = true })
	end
	return true
end

function LR:SyncDelistedFromAPI(row)
	if not (row and row.resultID) then
		return
	end
	local resultID = row.resultID
	local port = presentationPort()
	if not port then
		return
	end
	local entry, infoState, cached = port:RefreshLiveRow(resultID)
	if not entry then
		if cached and GF.IsCurrentGroupSearchResult
			and GF.IsCurrentGroupSearchResult(cached, resultID)
		then
			return
		end
		local autoRemoveExpired = infoState == "unavailable"
			and type(GF.ShouldRetainExpiredGroups) == "function"
			and GF.ShouldRetainExpiredGroups() ~= true
		if autoRemoveExpired then
			local tab = GF.FindGroupTab
			local begin = tab and tab.BeginExpiredResultRetirement
			if begin then
				begin(tab, resultID, cached)
			end
		elseif infoState ~= "not_current" and infoState ~= "unavailable" then
			dropResultAndRefresh(resultID)
		end
		return
	end
	if infoState == "unavailable" then
		self:RepaintRowState(row, entry, row.categoryID)
		return
	end
	local isDelisted = isInfoDelisted(entry.info)
	local stateChanged = isDelisted ~= (row._isDelisted == true)
	if not stateChanged or not row.resultIndex then
		return
	end
	self:RepaintRowState(row, entry, row.categoryID)
end

function LR:UpdateRoles(row, entry, categoryID, deferVisual)
	if not (row and row.roles and rowCol(row, "roles")) then
		return
	end
	if row._gfCurrentGroupProjection == true then
		local currentGroup = row._gfCurrentGroupElement
		entry = currentGroup and currentGroup.entry
		if not entry then
			return
		end
	end
	local index = row.resultIndex
	local port = presentationPort()
	if not (port and type(port.BuildRoleDisplaySnapshot) == "function") then
		return
	end
	local roleSnapshot, resolvedEntry =
		port:BuildRoleDisplaySnapshot(index, entry)
	if not (roleSnapshot and resolvedEntry and resolvedEntry.info) then
		return
	end
	row._deferRoles = nil
	local resolvedCategory = categoryID or row.categoryID
	local applicationUnavailable = row._applicationVisualState == "cancelled"
		or row._applicationVisualState == "declined"
	GF.RoleDisplay:Update(row.roles, roleSnapshot, resolvedCategory, {
		disabled = roleSnapshot.info.isDelisted or applicationUnavailable,
	})
	row._titleEntry = resolvedEntry
	row._titleInfo = resolvedEntry.info
	row._isCensored = port and port:IsCensored(resolvedEntry.info) or nil
	row._resultType = resolveResultType(row, resolvedEntry.info, resolvedEntry)
	row._resultDisplayType = resolveResultDisplayType(row, resolvedEntry.info, resolvedEntry, row._resultType)
	row._typeText = getResultTypeLabel(row._resultDisplayType)
	paintTypeCol(row, rowCol(row, "type"), getTitleDelistedColor(resolvedEntry.info))
	if deferVisual ~= true then
		self:UpdateRowBackgrounds(row)
	end
end

function LR:RepaintRowState(row, entry, categoryID)
	local info = entry and entry.info
	if not (row and info) then
		return
	end
	local index = row.resultIndex
	local port = presentationPort()
	local currentGroupElement = row._gfCurrentGroupElement
	local projectionOptions = clearReusableTable(row._gfSetDataOptions)
	row._gfSetDataOptions = projectionOptions
	projectionOptions.deferRoles = true
	projectionOptions.currentGroupProjection =
		row._gfCurrentGroupProjection == true
	projectionOptions.displayComment = currentGroupElement
		and currentGroupElement.displayComment
	projectionOptions.displayVoiceChat = currentGroupElement
		and currentGroupElement.displayVoiceChat
	projectionOptions.displayVoiceShown = currentGroupElement
		and currentGroupElement.displayVoiceShown
	projectionOptions.displayCommentProvided = currentGroupElement
		and currentGroupElement.displayCommentProvided
	projectionOptions.displayVoiceChatProvided = currentGroupElement
		and currentGroupElement.displayVoiceChatProvided
	projectionOptions.displayVoiceShownProvided = currentGroupElement
		and currentGroupElement.displayVoiceShownProvided
	local presentation = buildRowPresentation(
		row,
		port,
		index,
		categoryID or row.categoryID,
		entry,
		projectionOptions)
	if not presentation then
		return
	end
	entry, info = presentation.entry, presentation.info
	local disabledColor = getTitleDelistedColor(info)
	row._isDelisted = presentation.isDelisted and true or nil
	row._starredLeader = presentation.starredLeader == true
	row._isCensored = presentation.isCensored and true or nil
	applyVoicePresentation(row, presentation)
	row._titleText = presentation.title
	row._titleEntry = entry
	row._titleInfo = info
	row._resultType = presentation.resultType
	row._resultDisplayType = presentation.displayType
	row._typeText = getResultTypeLabel(row._resultDisplayType)
	row._commentText = presentation.comment
	row._metaScoreText = presentation.scoreText
	row._metaLeaderText = presentation.leaderText
	local paintOptions = clearReusableTable(row._gfPaintOptions)
	row._gfPaintOptions = paintOptions
	paintOptions.applyColors = true
	paintOptions.dc = disabledColor
	paintOptions.scoreColor = presentation.scoreColor
	paintOptions.leaderColor = presentation.leaderColor
	paintOptions.applyAppState = true
	paintOptions.deferVisual = true
	paintOptions.deferRoleUpdate = true
	paintRowFromCache(row, paintOptions)
	self:SetDelistedState(row, presentation.isDelisted, true)
	local roleCategory = categoryID or row.categoryID
	self:UpdateRoles(row, entry, roleCategory, true)
	self:UpdateRowBackgrounds(row)
end

local function updateRolePresentation(row, entry, rowCategory, info, shouldDefer, wantsPlayers)
	local hasRoleColumn = row.roles and rowCol(row, "roles")
	local waitingForPlayers = shouldDefer and wantsPlayers and not entry.players
	row._deferRoles = waitingForPlayers or nil
	if hasRoleColumn and not waitingForPlayers then
		local applicationUnavailable = row._applicationVisualState == "cancelled"
			or row._applicationVisualState == "declined"
		local port = presentationPort()
		if not (port and type(port.BuildRoleDisplaySnapshot) == "function") then
			return
		end
		local roleSnapshot =
			port:BuildRoleDisplaySnapshot(row.resultIndex, entry)
		GF.RoleDisplay:Update(row.roles, roleSnapshot, rowCategory, {
			disabled = roleSnapshot and roleSnapshot.info
				and roleSnapshot.info.isDelisted or applicationUnavailable,
		})
	end
end

function LR:SetData(row, index, categoryID, entry, opts)
	local options = opts or {}
	local port = presentationPort()
	local projectionOptions = clearReusableTable(
		row._gfPresentationSourceOptions)
	row._gfPresentationSourceOptions = projectionOptions
	projectionOptions.deferRoles = options.deferRoles
	projectionOptions.currentGroupProjection = entry
		and entry._gfCurrentGroupProjection == true
	projectionOptions.displayComment = options.displayComment
	projectionOptions.displayVoiceChat = options.displayVoiceChat
	projectionOptions.displayVoiceShown = options.displayVoiceShown
	projectionOptions.displayCommentProvided = options.displayCommentProvided
	projectionOptions.displayVoiceChatProvided =
		options.displayVoiceChatProvided
	projectionOptions.displayVoiceShownProvided =
		options.displayVoiceShownProvided
	local presentation = buildRowPresentation(
		row,
		port,
		index,
		categoryID,
		entry,
		projectionOptions)
	if not presentation then
		self:DetachRow(row)
		return false
	end
	entry = presentation.entry
	local info = presentation.info
	index = presentation.index or index
	local rowCat = presentation.categoryID
	local wantsPlayers = presentation.wantsPlayers
	local browsePanel = GF.BrowsePanel
	local boundResultID = entry.resultID
	local boundSearchToken = browsePanel and browsePanel._searchToken or nil
	local boundSearchKey = browsePanel and browsePanel.activeSearchKey or nil
	local bindingChanged = row._gfBoundResultID ~= boundResultID
		or row._gfBoundSearchToken ~= boundSearchToken
		or row._gfBoundSearchKey ~= boundSearchKey
	if bindingChanged then
		if self.ResetExpiredRemovalFade then
			self:ResetExpiredRemovalFade(row)
		end
		row._gfBindingGeneration = (row._gfBindingGeneration or 0) + 1
		row._gfBoundResultID = boundResultID
		row._gfBoundSearchToken = boundSearchToken
		row._gfBoundSearchKey = boundSearchKey
	end
	row.resultIndex = index
	row.resultID = entry.resultID
	row.categoryID = rowCat
	row._gfBlocklistRetiring = browsePanel
		and browsePanel.IsBlocklistResultRetiring
		and browsePanel:IsBlocklistResultRetiring(entry.resultID) or nil

	row._starredLeader = presentation.starredLeader == true
	row._isCensored = presentation.isCensored and true or nil
	applyVoicePresentation(row, presentation)

	if not options.skipLayout then
		self:LayoutRow(row, options.layoutW)
	end

	local activityInfo = presentation.activity
	local disabledColor = presentation.isDelisted
		and (LFG_LIST_DELISTED_FONT_COLOR or GRAY) or nil
	row._isDelisted = presentation.isDelisted and true or nil
	row._titleText = presentation.title
	row._titleEntry = entry
	row._titleInfo = info
	row._resultType = presentation.resultType
	row._resultDisplayType = presentation.displayType
	row._typeText = getResultTypeLabel(presentation.displayType)
	row._metaILText = tostring(math.floor(presentation.requiredItemLevel))
	row._commentText = presentation.comment
	if row._isCensored == true and row._commentText == nil then
		row._commentText = (GF.L or {}).CENSORED_RESULT_LIST_COMMENT
			or "队伍信息已被暴雪隐匿"
	end
	row._activityText = presentation.activityName
	row._metaScoreText = presentation.scoreText
	row._metaLeaderText = presentation.leaderText

	local paintOptions = clearReusableTable(row._gfPaintOptions)
	row._gfPaintOptions = paintOptions
	paintOptions.applyColors = true
	paintOptions.dc = disabledColor
	paintOptions.scoreColor = presentation.scoreColor
	paintOptions.leaderColor = presentation.leaderColor
	paintOptions.applyAppState = true
	paintOptions.deferVisual = true
	paintOptions.deferRoleUpdate = true
	paintRowFromCache(row, paintOptions)

	if presentation.leaderText == "?" then
		self:ScheduleLeaderRetry(row, index)
	end
	updateRolePresentation(row, entry, rowCat, info, options.deferRoles, wantsPlayers)
	self:SetDelistedState(row, presentation.isDelisted, true)
	if options.deferFinalVisual ~= true then
		self:UpdateRowBackgrounds(row)
	end
	local retirement = browsePanel
		and browsePanel.GetExpiredResultRetirement
		and browsePanel:GetExpiredResultRetirement(entry.resultID) or nil
	if retirement and row._gfBlocklistRetiring ~= true then
		self:PlayExpiredRemovalFade(row, retirement)
	elseif row._gfExpiredRetiring then
		self:ResetExpiredRemovalFade(row)
	end
	local shouldShow = not options.skipShow
	if shouldShow then
		row:Show()
	end
	return true
end
