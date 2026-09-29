local _, GF = ...

local UI, P = GF.UI, GF.RaidSeekingProtocol
local S = GF.RAID_SEEKING_CHAT_STYLE
local View = {}
View.__index = View
GF.RaidSeekingChatView = View

local function label(key) return (GF.L or {})["SEEK_" .. key] or key end
local endLabels = {
	chat_cancelled = "CHAT_END_CANCELLED", chat_joined = "CHAT_END_JOINED", chat_party_changed = "CHAT_END_PARTY_CHANGED",
	chat_recruitment_stopped = "CHAT_END_RECRUITMENT_STOPPED", chat_permission_lost = "CHAT_END_PERMISSION_LOST",
	chat_activity_changed = "CHAT_END_ACTIVITY_CHANGED", chat_mismatch = "CHAT_END_MISMATCH",
	chat_recreated = "CHAT_END_RECREATED", chat_role_changed = "CHAT_END_ROLE_CHANGED",
	chat_capacity = "ERROR_CHAT_CAPACITY", chat_peer_capacity = "ERROR_CHAT_PEER_CAPACITY",
	chat_connect_failed = "ERROR_CHAT_CONNECT_FAILED",
	chat_login_ended = "CHAT_END_LOGIN",
}
local function endLabel(c)
	local key = endLabels[c.endReason]
	if c.endReason == "chat_seeking_stopped" then
		key = c.context == "board" and "CHAT_END_PEER_STOPPED" or "CHAT_END_SEEKING_STOPPED"
	elseif c.endReason == "chat_republished" then
		key = c.context == "board" and "CHAT_END_PEER_REPUBLISHED" or "CHAT_END_REPUBLISHED"
	end
	return label(key or (c.context == "board" and "CHAT_END_LOST_BOARD" or "CHAT_END_LOST_SEEKING"))
end
local function shortName(name) return P.Display((name or ""):match("^[^-]+") or name) end
local function colorText(text, color)
	return string.format("|cff%02x%02x%02x%s|r", math.floor(color[1] * 255 + 0.5),
		math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5), text)
end
local function styleActivityMenuTitle(frame)
	local text = frame.fontString
	-- Native menu text disallows SetFont; sample its font into an owned Font object.
	GF.Font.ApplyToMenuFontString(text, "GameFontNormalSmall", text:GetFontObject(), S.menuActivityFontScale)
	text:SetTextToFit(text:GetText())
end
local function catalogValue(view, values, key)
	local value = values and values[key]
	if key and not value then view.catalogPending = true end
	return value
end
local function headerActivity(view, activityID)
	local name = catalogValue(view, view.panel.activityNames, activityID)
	if not name then return label("CHAT_UNKNOWN_ACTIVITY") end
	return P.Display(name)
end
local function font(parent, template, sizeExtra)
	local value = UI.CreateFontString(parent, "OVERLAY", template or "GameFontHighlightSmall")
	if sizeExtra then
		value._gfFontSizeExtra = sizeExtra
		if GF.Font and GF.Font.ApplyToFontString then GF.Font.ApplyToFontString(value, template or "GameFontHighlightSmall") end
	end
	value:SetJustifyH("LEFT"); value:SetJustifyV("TOP"); value:SetWordWrap(true)
	return value
end
local function clearIcons(row)
	for _, icon in ipairs(row.specs) do UI.ClearSpecializationIcon(icon); icon:Hide() end
end
local function headerTextWidth(text)
	-- A recycled FontString's bounded width can still reflect its previous layout.
	return math.ceil(text:GetUnboundedStringWidth()) + 1
end
local function layoutBubble(bubble, leader, classColor)
	-- Match the supplemental-note input's active nine-slice, including its authored gold.
	local chrome = UI.ApplyFilterMultilineInputChrome(bubble, "focus")
	if not chrome then return end
	local r, g, b = 1, 1, 1
	if not leader and classColor then
		r, g, b = classColor.r, classColor.g, classColor.b
	end
	local function tint(texture)
		texture:SetDesaturated(not leader)
		texture:SetVertexColor(r, g, b, 1)
	end
	for _, key in ipairs({ "topLeft", "top", "topRight", "left", "right", "bottomLeft", "bottom", "bottomRight" }) do
		tint(chrome.border[key])
	end
	tint(chrome.center)
end
local function setTabPressed(tab, pressed)
	tab.pressed = pressed or nil
	local point = tab.textPoint
	if not point then return end
	tab.Text:ClearAllPoints()
	tab.Text:SetPoint(point[1], point[2], point[3],
		point[4] + (pressed and GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_X or 0),
		point[5] + (pressed and GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_Y or 0))
end
function View.Create(panel)
	local self = setmetatable({ panel = panel, service = GF.RaidSeekingChatService, context = "seeking", contextStates = {},
		tabs = {}, rows = {}, offsets = {}, firstTab = 1,
		selectionHistory = setmetatable({}, { __mode = "k" }), selectionSerial = 0,
		messageAppearances = setmetatable({}, { __mode = "k" }) }, View)
	local content = panel.contactContent
	self.frame = content
	self.tabBar = CreateFrame("Frame", nil, content)
	self.tabBar:SetPoint("TOPLEFT", 0, S.tabTopOffset)
	self.tabBar:SetPoint("TOPRIGHT", 0, S.tabTopOffset); self.tabBar:SetHeight(S.tabHeight)
	-- Match the title rule's size and horizontal bounds; only its Y position differs.
	local titleRule = panel.contactCard.header.rule
	local ruleOffsetY = S.tabTopOffset - GF.RAID_SEEKING_STYLE.contentTop - S.tabHeight
	self.tabRuleLayer = CreateFrame("Frame", nil, self.tabBar)
	self.tabRuleLayer:SetAllPoints(self.tabBar); self.tabRuleLayer:EnableMouse(false)
	self.tabDivider = UI.CreateOptionsTitleDivider(self.tabRuleLayer, "BACKGROUND")
	self.tabDivider:SetPoint("TOPLEFT", titleRule, "BOTTOMLEFT", 0, ruleOffsetY)
	self.tabDivider:SetPoint("TOPRIGHT", titleRule, "BOTTOMRIGHT", 0, ruleOffsetY)
	self.tabDivider:SetHeight(titleRule:GetHeight())
	-- End the tab body at the rule's upper edge; the rule and selected line render above it.
	self.tabClip = CreateFrame("Frame", nil, self.tabBar)
	self.tabClip:SetPoint("TOPLEFT", panel.contactCard, "TOPLEFT")
	self.tabClip:SetPoint("TOPRIGHT", panel.contactCard, "TOPRIGHT")
	self.tabClip:SetPoint("BOTTOM", self.tabDivider, "TOP")
	self.tabClip:SetClipsChildren(true)
	self.tabRuleLayer:SetFrameLevel(self.tabClip:GetFrameLevel() + 2)
	self.previous = CreateFrame("Button", nil, self.tabBar)
	UI.ApplyCommonArrowButtonSkin(self.previous, -1, {
		hitSize = S.tabArrowWidth, visualSize = GF.SETTINGS_SLIDER_STEPPER_SIZE, rotation = 0,
	})
	self.previous:SetPoint("LEFT"); self.previous:SetScript("OnClick", function() self:Page(-1) end)
	self.next = CreateFrame("Button", nil, self.tabBar)
	UI.ApplyCommonArrowButtonSkin(self.next, 1, {
		hitSize = S.tabArrowWidth, visualSize = GF.SETTINGS_SLIDER_STEPPER_SIZE, rotation = 0,
	})
	self.next:SetPoint("RIGHT"); self.next:SetScript("OnClick", function() self:Page(1) end)
	self.tabBar:EnableMouseWheel(true)
	self.tabBar:SetScript("OnMouseWheel", function(_, delta) self:Page(delta > 0 and -1 or 1) end)
	-- A fixed viewport clips the rising footer and keeps the message geometry stable.
	self.footerClip = CreateFrame("Frame", nil, panel.contactCard)
	self.footerClip:SetPoint("BOTTOMLEFT", S.footerEdgeInset, S.footerEdgeInset)
	self.footerClip:SetPoint("BOTTOMRIGHT", -S.footerEdgeInset, S.footerEdgeInset)
	self.footerClip:SetHeight(S.footerHeight); self.footerClip:SetClipsChildren(true)
	self.footer = CreateFrame("Frame", nil, self.footerClip)
	self.footer:SetHeight(S.footerHeight)
	UI.InstallBrowseControlBarChrome(self.footer, { backgroundParent = self.footer, leftInset = 0, rightInset = 0,
		topOffset = 0, height = S.footerHeight })
	-- Keep controls above the shared chrome's external background frame.
	self.controls = CreateFrame("Frame", nil, self.footer)
	self.controls:SetAllPoints(); self.controls:SetFrameLevel(self.footer:GetFrameLevel() + 3)
	self.inputShell, self.input = UI.CreateSelectableCopyInput(self.controls, 100,
		{ height = S.inputHeight, fontSize = S.messageTextSize, selectAllOnMouseDown = false })
	self.inputShell:SetPoint("LEFT", S.footerInset, 0)
	self.input:ClearAllPoints()
	self.input:SetPoint("TOPLEFT", self.inputShell, "TOPLEFT", S.inputTextInset, -3)
	self.input:SetPoint("BOTTOMRIGHT", self.inputShell, "BOTTOMRIGHT", -S.inputTextInset, 3)
	self.input:SetTextInsets(0, 0, 0, 0)
	self.input:SetMaxBytes(S.sendMaxBytes); self.input:SetAutoFocus(false)
	self.input:SetJustifyH("LEFT")
	self.input:SetScript("OnTextChanged", function(edit)
		if not self.loading then
			self.service:SetDraft(self.selectedKey, edit:GetText())
			local conversation = self.service:Get(self.selectedKey)
			self.inputDraft = conversation and conversation.draft or ""
		end
		self.placeholder:SetShown(edit:GetText() == "")
	end)
	self.input:SetScript("OnEnterPressed", function(edit)
		if not edit:IsEnabled() or edit:IsInIMECompositionMode() or not edit:GetText():find("%S") then return end
		self:Send()
	end)
	self.input:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
	self.placeholder = font(self.input)
	self.placeholder:SetPoint("LEFT", 0, 0); self.placeholder:SetPoint("RIGHT", 0, 0)
	self.placeholder:SetWordWrap(false); self.placeholder:SetMaxLines(1)
	self.placeholder:SetTextColor(unpack(GF.RAID_SEEKING_STYLE.mutedColor))
	self.openLeader = UI.CreatePanelButton(self.controls, label("OPEN_LEADER"), S.openLeaderWidth)
	self.openLeader:SetPoint("RIGHT", -S.footerInset, 0)
	self.openLeader:SetScript("OnClick", function() panel:OpenLeader(self.selectedKey) end)
	self.boardAction = UI.CreatePanelButton(self.controls, label("BOARD_INVITE"), S.openLeaderWidth)
	-- Both contexts share one fixed action slot, so incoming messages never
	-- change the editor's anchors or interrupt an unfinished IME composition.
	self.boardAction:SetAllPoints(self.openLeader)
	self.boardAction:SetScript("OnClick", function() self:InviteFromChat() end)
	self.boardAction:Hide()
	self.closeConversation = UI.CreatePanelButton(self.controls, label("CHAT_CLOSE"), S.openLeaderWidth)
	self.closeConversation:SetAllPoints(self.openLeader)
	self.closeConversation:SetScript("OnClick", function()
		local c = self.service:Get(self.selectedKey)
		if not self:IsPresenceInteractive() or not c or not c.ended or c.context ~= self.context then return end
		self.offsets[c.key] = self.scroll:GetVerticalScroll()
		self.service:Close(c.key)
	end)
	self.closeConversation:Hide()
	-- Show the end reason inside the existing input chrome without overwriting its draft.
	self.endNotice = CreateFrame("Frame", nil, self.inputShell)
	self.endNotice:SetAllPoints(self.inputShell); self.endNotice:EnableMouse(false)
	self.endText = font(self.endNotice)
	self.endText:SetPoint("TOPLEFT", S.inputTextInset, 0)
	self.endText:SetPoint("BOTTOMRIGHT", -S.inputTextInset, 0)
	self.endText:SetJustifyV("MIDDLE"); self.endText:SetMaxLines(2)
	self.endText:SetTextColor(unpack(GF.RAID_SEEKING_STYLE.mutedColor))
	self.endNotice:Hide()
	self.statusClip = CreateFrame("Frame", nil, content)
	self.statusClip:SetPoint("BOTTOMLEFT", self.footerClip, "TOPLEFT", 0, S.scrollEdgeInset)
	self.statusClip:SetClipsChildren(true); self.statusClip:EnableMouse(false)
	self.statusTexture = self.statusClip:CreateTexture(nil, "BACKGROUND")
	self.statusTexture:SetAtlas(S.statusAtlas); self.statusTexture:SetAllPoints()
	self.statusTexture:SetBlendMode("BLEND"); self.statusTexture:SetDesaturated(true)
	self.statusTexture:SetVertexColor(unpack(S.statusColor))
	self.statusBody = CreateFrame("Frame", nil, self.statusClip)
	self.statusBody:SetPoint("BOTTOMLEFT"); self.statusBody:EnableMouse(false)
	self.statusText = font(self.statusBody)
	self.statusText:SetPoint("LEFT", S.footerInset, 0)
	self.statusText:SetPoint("RIGHT", -S.footerInset, 0)
	self.statusText:SetJustifyV("MIDDLE")
	self.statusText:SetTextColor(unpack(S.activityColor)); self.statusText:Hide()
	self.applicantActions = CreateFrame("Frame", nil, self.statusBody)
	self.applicantActions:SetSize(GF.APPLICANT_ACTION_BUTTON_SIZE * 2 + GF.APPLICANT_ACTION_BUTTON_GAP,
		GF.APPLICANT_ACTION_BUTTON_SIZE)
	self.applicantActions:SetPoint("RIGHT", -S.footerInset, 0)
	self.applicantInviteHolder, self.applicantInvite = UI.CreateApplicantInviteButton(self.applicantActions)
	self.applicantDeclineHolder, self.applicantDecline = UI.CreateApplicantDeclineButton(self.applicantActions)
	self.applicantInviteHolder:SetPoint("LEFT"); self.applicantDeclineHolder:SetPoint("RIGHT")
	for action, button in pairs({ invite = self.applicantInvite, decline = self.applicantDecline }) do
		button:SetScript("OnClick", function() self:SubmitApplicantAction(action) end)
		button:HookScript("OnEnter", function()
			UI.ShowSimpleTooltipAbove(button, (GF.L or {})[action == "invite" and "APPLICANT_GROUP_INVITE" or "APPLICANT_GROUP_DECLINE"])
		end)
		button:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	end
	self.applicantActions:Hide()
	self.statusDriver = CreateFrame("Frame", nil, content)
	self.statusDriver:Hide(); self.statusClip:Hide()
	self.inputShell:SetPoint("RIGHT", self.openLeader, "LEFT", -S.gap, 0)
	self.scroll = UI.CreateScrollFrame(content)
	self:SetScrollProgress(0)
	-- ScrollFrame renders its child in a separate pass that bypasses Frame
	-- alpha gradients. Keep an unpainted extent for native input/range, and
	-- translate the visible messages inside an ordinary fixed clip host.
	self.messageViewport = CreateFrame("Frame", nil, content)
	self.messageViewport:SetAllPoints(self.scroll)
	self.messageViewport:SetClipsChildren(true)
	self.messageViewport:SetFlattensRenderLayers(true)
	self.child = CreateFrame("Frame", nil, self.messageViewport)
	self.child:SetSize(1, 1); self.child:SetUsingParentLevel(true)
	self.scrollExtent = CreateFrame("Frame", nil, self.scroll)
	self.scrollExtent:SetSize(1, 1); self.scroll:SetScrollChild(self.scrollExtent)
	local function refreshEdgeFade() self:RefreshEdgeFade() end
	self.scroll:HookScript("OnVerticalScroll", refreshEdgeFade)
	self.scroll:HookScript("OnScrollRangeChanged", refreshEdgeFade)
	self.scroll:HookScript("OnSizeChanged", refreshEdgeFade)
	self:RefreshEdgeFade()
	self:InitScrollBar()
	self.scroll._gfWheelAllow = function() return self:IsPresenceInteractive() end
	UI.BindSmoothWheelScrolling(self.scroll)
	UI.BindSmoothWheelScrollBar(self.scroll, self.scrollBar)
	self.conversationEmpty = font(self.scroll)
	self.conversationEmpty:SetPoint("CENTER"); self.conversationEmpty:SetPoint("LEFT", S.gap, 0)
	self.conversationEmpty:SetPoint("RIGHT", -S.gap, 0); self.conversationEmpty:SetJustifyH("CENTER")
	self.conversationEmpty:SetTextColor(unpack(GF.RAID_SEEKING_STYLE.mutedColor))
	self.presenceDriver = CreateFrame("Frame", nil, content)
	self.messageDriver = CreateFrame("Frame", nil, content)
	self:StopPresenceAnimation()
	content:HookScript("OnSizeChanged", function() self.dirty = true; panel:RequestLayoutRefresh() end)
	content:HookScript("OnHide", function()
		self.input:ClearFocus()
		if self.selectedKey then self.offsets[self.selectedKey] = self.scroll:GetVerticalScroll() end
		self:StopPresenceAnimation(); self:StopScrollAnimation(); self.renderedKey = nil; self.dirty = true
	end)
	self.service:Start()
	self.service:AddListener(function()
		self.dirty = true
		if content:IsVisible() then self:Refresh() end
	end)
	return self
end
function View:IsPresenceInteractive()
	return self.presenceTarget == 1 and self.presenceProgress == 1 and self.frame:IsVisible()
end
function View:IsViewingConversation(key)
	-- A bubble may still be fading in before MarkVisibleRead acknowledges it.
	-- Already watching this contact at the bottom must not flash the launcher.
	return key ~= nil and self.selectedKey == key and self:IsPresenceInteractive() and self:IsReadingBottom()
end
function View:LoadInputDraft(conversation)
	local draft = conversation and conversation.draft or ""
	self.inputConversation, self.inputDraft = conversation, draft
	self.loading = true
	if self.input:GetText() ~= draft then self.input:SetText(draft) end
	self.loading = nil
end
function View:SyncInputDraft(conversation)
	if self.inputConversation ~= conversation then
		self:LoadInputDraft(conversation)
	elseif conversation and conversation.draft ~= self.inputDraft
		and not self.input:IsInIMECompositionMode() and self.input:GetText() == self.inputDraft then
		-- Only an unchanged, committed draft may consume an asynchronous send echo.
		-- Native IME/caret state belongs to the editor until OnTextChanged commits it.
		self:LoadInputDraft(conversation)
	end
end
function View:SetContext(context)
	if self.context == context then return end
	self.contextStates[self.context] = { selectedKey = self.selectedKey, firstTab = self.firstTab }
	if self.selectedKey then self.offsets[self.selectedKey] = self.scroll:GetVerticalScroll() end
	self.input:ClearFocus()
	self:StopPresenceAnimation(); self:StopScrollAnimation()
	self.context = context
	self:RefreshEdgeFade()
	local state = self.contextStates[context] or {}
	self.selectedKey, self.firstTab = state.selectedKey, state.firstTab or 1
	local conversation = self.service:Get(self.selectedKey)
	self:LoadInputDraft(conversation)
	self.renderedKey, self.scrollConversation, self.dirty = nil, nil, true
end
function View:FinishMessageAnimations()
	for _, row in ipairs(self.rows) do
		if row.messageRecord then self.messageAppearances[row.messageRecord] = true end
		row:SetAlpha(1)
	end
	self.messageDriver:SetScript("OnUpdate", nil); self.messageDriver:Hide()
end
function View:SyncMessageAnimationDriver()
	local pending = false
	if self.presenceTarget == 1 and self.frame:IsVisible() then
		for _, row in ipairs(self.rows) do
			if row.messageRecord and type(self.messageAppearances[row.messageRecord]) == "table" then
				pending = true; break
			end
		end
	end
	if pending then
		if not self.messageDriver:GetScript("OnUpdate") then
			self.messageDriver:SetScript("OnUpdate", function(_, elapsed) self:TickMessageAnimations(elapsed) end)
		end
	else
		self.messageDriver:SetScript("OnUpdate", nil)
	end
	self.messageDriver:SetShown(pending)
end
function View:TickMessageAnimations(elapsed)
	for _, row in ipairs(self.rows) do
		local appearance = row.messageRecord and self.messageAppearances[row.messageRecord]
		if type(appearance) == "table" then
			appearance.elapsed = appearance.elapsed + math.max(0, elapsed)
			local p = math.min(1, appearance.elapsed / S.messageFadeDuration)
			appearance.alpha = p * p * (3 - 2 * p)
			row:SetAlpha(appearance.alpha)
			if p == 1 then self.messageAppearances[row.messageRecord] = true end
		end
	end
	self:SyncMessageAnimationDriver()
	self:MarkVisibleRead()
end
function View:ApplyMessageAppearance(row, message)
	local appearance = self.messageAppearances[message]
	if appearance == nil then
		appearance = self.frame:IsVisible() and { elapsed = 0, alpha = 0 } or true
		self.messageAppearances[message] = appearance
	end
	row.messageRecord = message
	row:SetAlpha(type(appearance) == "table" and appearance.alpha or 1)
end
function View:RefreshPresenceInteraction()
	local interactive = self:IsPresenceInteractive()
	self.tabBar:EnableMouseWheel(interactive)
	self.scroll:EnableMouseWheel(interactive)
	self.previous:SetEnabled(interactive and self.firstTab > 1)
	self.next:SetEnabled(interactive and self.firstTab + (self.pagingCapacity or 1) <= (self.pagingCount or 0))
	for _, tab in ipairs(self.tabs) do tab.hitButton:SetEnabled(interactive) end
	if not interactive then self.input:ClearFocus() end
	self:RefreshActions()
end
function View:SetPresenceProgress(progress)
	local wasInteractive = self:IsPresenceInteractive()
	self.presenceProgress = progress
	local shown = progress > 0 or self.presenceTarget == 1
	self.footerClip:SetShown(shown); self.tabBar:SetShown(shown); self.scroll:SetShown(shown)
	self.footer:SetAlpha(progress); self.tabBar:SetAlpha(progress); self.scroll:SetAlpha(progress)
	self.messageViewport:SetShown(shown); self.messageViewport:SetAlpha(progress)
	self:LayoutStatus()
	local offset = -S.footerHeight * (1 - progress)
	if self.footerOffset ~= offset then
		self.footerOffset = offset
		self.footer:ClearAllPoints()
		self.footer:SetPoint("BOTTOMLEFT", self.footerClip, "BOTTOMLEFT", 0, offset)
		self.footer:SetPoint("BOTTOMRIGHT", self.footerClip, "BOTTOMRIGHT", 0, offset)
	end
	local empty = progress < 1
	self.panel.contactEmptyGroup:SetAlpha(1 - progress)
	self.panel.contactEmptyGroup:SetShown(empty)
	self.panel.contactEmptyTitle:SetShown(empty); self.panel.contactEmpty:SetShown(empty)
	if wasInteractive ~= self:IsPresenceInteractive() then self:RefreshPresenceInteraction() end
	self:SyncScrollBar()
	self:MarkVisibleRead()
end
function View:StopPresenceAnimation()
	UI.CancelSmoothWheelScrolling(self.scroll)
	self:StopStatusAnimation()
	self.presenceFade, self.presenceTarget = nil, 0
	self:HideUnreadIndicators()
	self.presenceDriver:SetScript("OnUpdate", nil); self.presenceDriver:Hide()
	self:FinishMessageAnimations()
	self:SetPresenceProgress(0); self:RefreshPresenceInteraction()
end
function View:SetPresenceShown(shown)
	if not shown then UI.CancelSmoothWheelScrolling(self.scroll) end
	if not self.frame:IsVisible() then self:StopPresenceAnimation(); return end
	local target = shown and 1 or 0
	if self.presenceTarget ~= target then
		self.presenceTarget = target
		local from = self.presenceProgress or 0
		self.presenceFade = from ~= target and { from = from, target = target, elapsed = 0 } or nil
		self.presenceDriver:SetScript("OnUpdate", self.presenceFade and function(_, elapsed)
			self:TickPresenceAnimation(elapsed)
		end or nil)
		self.presenceDriver:SetShown(self.presenceFade ~= nil)
	end
	self:SetPresenceProgress(self.presenceProgress or 0)
	self:RefreshPresenceInteraction()
	self:SyncMessageAnimationDriver()
	if target == 0 and not self.presenceFade then self:StopScrollAnimation(); self.renderedKey = nil end
end
function View:TickPresenceAnimation(elapsed)
	local fade = self.presenceFade
	if not fade then return end
	fade.elapsed = fade.elapsed + math.max(0, elapsed)
	local p = math.min(1, fade.elapsed / S.presenceDuration)
	self:SetPresenceProgress(fade.from + (fade.target - fade.from) * p * p * (3 - 2 * p))
	if p == 1 then
		self.presenceFade = nil
		self.presenceDriver:SetScript("OnUpdate", nil); self.presenceDriver:Hide()
		if fade.target == 0 then
			self:StopScrollAnimation(); self:FinishMessageAnimations(); self.renderedKey = nil
		end
	end
end
function View:LayoutScrollBarBounds()
	local bar, reserved = self.scrollBar, self.statusHeight or 0
	if not bar or self.scrollBarStatusHeight == reserved then return end
	self.scrollBarStatusHeight = reserved
	-- Keep the horizontal position fixed while reserving the same status space as the messages.
	bar:ClearAllPoints()
	bar:SetPoint("TOPRIGHT", self.tabDivider, "BOTTOMRIGHT",
		GF.CARD_HEADER_STYLE.inset + GF.CARD_HEADER_STYLE.dividerInset - S.scrollRightInset, -S.scrollEdgeInset)
	bar:SetPoint("BOTTOMRIGHT", self.footerClip, "TOPRIGHT",
		S.footerEdgeInset - S.scrollRightInset, S.scrollEdgeInset + reserved)
end
function View:SetScrollProgress(progress)
	self.scrollProgress = progress
	self.scroll:ClearAllPoints()
	self.scroll:SetPoint("TOPLEFT", self.tabDivider, "BOTTOMLEFT",
		GF.RAID_SEEKING_STYLE.contentInset - GF.CARD_HEADER_STYLE.inset - GF.CARD_HEADER_STYLE.dividerInset, -S.scrollEdgeInset)
	self.scroll:SetPoint("BOTTOMRIGHT", self.footerClip, "TOPRIGHT",
		S.footerEdgeInset - GF.RAID_SEEKING_STYLE.contentInset - S.scrollGutter * progress, S.scrollEdgeInset + (self.statusHeight or 0))
	self:LayoutScrollBarBounds()
end
function View:RefreshEdgeFade()
	local range = self.scroll:GetVerticalScrollRange()
	local offset = math.max(0, math.min(range, self.scroll:GetVerticalScroll()))
	if self.messageOffset ~= offset then
		self.messageOffset = offset
		self.child:ClearAllPoints()
		self.child:SetPoint("TOPLEFT", self.messageViewport, "TOPLEFT", 0, offset)
	end
	local length = S.scrollEdgeFade
	local top, bottom = math.min(length, offset), math.min(length, range - offset)
	if self.fadeTopLength == top and self.fadeBottomLength == bottom then return end
	self.fadeTopLength, self.fadeBottomLength = top, bottom
	if top > 0 or bottom > 0 then
		self.messageViewport:SetAlphaGradient(0, CreateVector2D(0, top))
		self.messageViewport:SetAlphaGradient(1, CreateVector2D(0, bottom))
	else
		self.messageViewport:ClearAlphaGradient()
	end
end
function View:IsReadingBottom()
	local range = self.scroll:GetVerticalScrollRange()
	-- A wheel-up request counts as reading history before its first animation tick.
	return self.scroll:GetVerticalScroll() >= range - 2
		and (not self.scroll._gfSmoothWheelActive or (self.scroll._gfSmoothWheelTarget or 0) >= range - 2)
end
function View:SyncScrollBar()
	local bar = self.scrollBar
	if not bar or self.scrollSyncing then return end
	self.scrollSyncing = true
	local range = self.scroll:GetVerticalScrollRange()
	local progress, needed = self.scrollProgress or 0, self.scrollTarget == 1
	-- Keep the previous thumb geometry until fade-out completes.
	if needed or progress == 0 then
		local height = math.max(1, self.scroll:GetHeight())
		bar:SetVisibleExtentPercentage(height / (height + range))
		bar:SetPanExtentPercentage(range > 0 and math.min(1, GF.GetWheelScrollPixels(self.scroll._gfWheelRowH) / range) or 0)
		bar:SetScrollPercentage(range > 0 and self.scroll:GetVerticalScroll() / range or 0, true)
	end
	local presence = self.presenceProgress or 0
	local interactive = needed and progress == 1 and range > 0 and self:IsPresenceInteractive()
	bar:SetScrollAllowed(interactive); bar:GetTrack():EnableMouse(interactive); bar:EnableMouseWheel(interactive)
	bar:SetAlpha(progress * presence); bar:SetShown(presence > 0 and (progress > 0 or needed))
	self.scrollSyncing = nil
end
function View:InitScrollBar()
	local bar = CreateFrame("EventFrame", nil, self.panel.contactCard, "MinimalScrollBar")
	self.scrollBar = bar; self.scroll.ScrollBar = bar
	self:LayoutScrollBarBounds()
	bar:SetWidth(S.scrollBarWidth); bar:SetFrameLevel(self.scroll:GetFrameLevel() + 10)
	UI.ApplyCommonScrollBarSkin(bar)
	bar:SetHideIfUnscrollable(false); bar:SetInterpolateScroll(false)
	bar:RegisterCallback("OnScroll", function(_, percentage)
		if not self.scrollSyncing and self.scrollTarget == 1 and self.scrollProgress == 1 and self:IsPresenceInteractive() then
			UI.CancelSmoothWheelScrolling(self.scroll)
			self.scrollSyncing = true
			self.scroll:SetVerticalScroll(percentage * self.scroll:GetVerticalScrollRange())
			self.scrollSyncing = nil
			self:MarkVisibleRead()
		end
	end, self)
	bar:HookScript("OnHide", function() bar:UnregisterUpdate() end)
	self.scroll:HookScript("OnVerticalScroll", function() self:SyncScrollBar(); self:MarkVisibleRead() end)
	self.scrollDriver = CreateFrame("Frame", nil, self.frame)
	self.scrollDriver:SetScript("OnUpdate", function(_, elapsed) self:TickScrollAnimation(elapsed) end)
	self.scrollDriver:Hide(); self:SyncScrollBar()
end
function View:StopScrollAnimation()
	UI.CancelSmoothWheelScrolling(self.scroll)
	self.scrollFade, self.scrollConversation, self.scrollTarget = nil, nil, nil
	self.scrollDriver:Hide(); self.scrollBar:UnregisterUpdate()
	self:SetScrollProgress(0); self:SyncScrollBar()
end
function View:TickScrollAnimation(elapsed)
	local fade, conversation = self.scrollFade, self.scrollConversation
	if not fade or not conversation then return end
	local atBottom = self:IsReadingBottom()
	local offset = self.scroll:GetVerticalScroll()
	fade.elapsed = fade.elapsed + math.max(0, elapsed)
	local p = math.min(1, fade.elapsed / S.scrollDuration)
	self:SetScrollProgress(fade.from + (fade.target - fade.from) * p * p * (3 - 2 * p))
	self:LayoutMessages(conversation, math.max(1, self.scroll:GetWidth()))
	self.scroll:UpdateScrollChildRect()
	local range = self.scroll:GetVerticalScrollRange()
	self.scroll:SetVerticalScroll(atBottom and range or math.min(range, offset))
	self:SyncScrollBar()
	if p == 1 then self.scrollFade = nil; self.scrollDriver:Hide() end
end
function View:RememberSelection(conversation)
	if not conversation then return end
	self.selectionSerial = self.selectionSerial + 1
	self.selectionHistory[conversation] = self.selectionSerial
end
function View:RecentOpenConversation(list)
	local recent, rank = nil, 0
	-- The list is already filtered to visible, open contacts in this page.
	-- Object keys keep a new conversation from inheriting an old one's history.
	for _, conversation in ipairs(list) do
		local seen = self.selectionHistory[conversation] or 0
		if seen > rank then recent, rank = conversation, seen end
	end
	return recent or list[1]
end
function View:Select(key, revealLatest)
	local target = self.service:Get(key)
	if target and (target.context or "seeking") ~= self.context then return end
	self.service:Open(key)
	if self.selectedKey == key and not revealLatest then return end
	local previous = self.service:Get(self.selectedKey)
	if previous then self.offsets[previous.key] = self.scroll:GetVerticalScroll() end
	if revealLatest then self.offsets[key] = nil end
	self.selectedKey = key
	self:RememberSelection(target)
	local conversation = self.service:Get(key)
	self:LoadInputDraft(conversation)
	self.renderedKey = nil; self.dirty = true
	self:Refresh()
end
function View:ShowTabMenu(button)
	local key = button.key
	local conversation = self.service:Get(key)
	if not conversation or conversation.closed then return end
	local _, classFile = UI.ResolveClassIcon(conversation.classFile or conversation.profile and conversation.profile.classID)
	local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	local nameColor = classColor and { classColor.r, classColor.g, classColor.b } or S.menuTextColor
	local activity = catalogValue(self, self.panel.activityNames, conversation.activityID) or label("CHAT_UNKNOWN_ACTIVITY")
	local context = self.context
	local function current() return self.context == context and self.service:Get(key) == conversation and not conversation.closed end
	-- Capture the contact identity: paging can reuse this button while its menu is open.
	local items = {
		{ isTitle = true, text = shortName(conversation.name), textColor = nameColor, titleDivider = false },
		{ isTitle = true, text = P.Display(activity), textColor = S.activityColor, initializer = styleActivityMenuTitle },
		{ text = label("CHAT_CLOSE_TAB"), textColor = S.menuTextColor, func = function()
			if not current() then return end
			if self.selectedKey == key then self.offsets[key] = self.scroll:GetVerticalScroll() end
			self.service:Close(key)
		end },
		{ text = (GF.L or {}).CANCEL or "CANCEL", textColor = S.menuTextColor },
	}
	if context == "seeking" and not conversation.ended then
		table.insert(items, 3, { text = colorText(label("OPEN_LEADER"), S.activityColor), disabled = self.service:GetContact(key) == nil,
			func = function() if current() then self.panel:OpenLeader(key) end end })
	end
	GF.ListingContextMenu:ShowMenu(items, { owner = button })
end
function View:Page(direction)
	self.firstTab = self.firstTab + direction
	self:RefreshTabs()
end
function View:UpdateUnreadArrow(owner, count)
	owner.unreadCount = count
	local badge = owner.unreadBadge
	if count <= 0 then
		if badge then badge:Hide() end
		return
	end
	if not badge then
		-- Offscreen contacts retain the centered, numberless paging hint.
		badge = CreateFrame("Frame", nil, self.tabBar, "NewFeatureLabelTemplate")
		owner.unreadBadge = badge
		badge:SetSize(1, 1); badge:SetScale(S.unreadBadgeScale)
		badge:SetFrameLevel(owner:GetFrameLevel() - 1); badge:EnableMouse(false)
		badge:SetPoint("CENTER", owner, "CENTER", 0, 0)
		badge.Label:Hide(); badge.BGLabel:Hide()
		badge:SetFixedSize(1, 1)
		badge.Glow:SetDrawLayer("BACKGROUND")
		badge.Glow:ClearAllPoints(); badge.Glow:SetPoint("CENTER", badge, "CENTER")
		badge.Glow:SetSize(S.unreadArrowGlowWidth, S.unreadArrowGlowHeight)
	end
	if badge.count ~= count then
		badge.count, badge.label = count, ""
		badge.Label:SetTextToFit(badge.label); badge.BGLabel:SetTextToFit(badge.label)
		badge:MarkDirty()
	end
	badge:Show()
end
function View:HideUnreadIndicators()
	for _, tab in ipairs(self.tabs) do UI.SetNativeTabUnread(tab, false) end
	for _, arrow in ipairs({ self.previous, self.next }) do if arrow.unreadBadge then arrow.unreadBadge:Hide() end end
end
function View:RefreshTabHighlight(tab)
	if not tab._gfSelected and tab.hitButton:IsMouseOver() then
		tab:LockHighlight()
	else tab:UnlockHighlight() end
end
function View:CreateTab()
	local tab = UI.CreateNativeTabButton(self.tabClip, "")
	tab._gfUnreadGlowFrameLevel = self.tabRuleLayer:GetFrameLevel() - 1
	tab:SetScale(S.tabScale)
	if tab.SelectedHighlight then
		-- Keep the shared tab-relative anchors and scale, but escape the body's clip.
		tab.SelectedHighlight:SetParent(self.tabRuleLayer)
		tab.SelectedHighlight:SetScale(S.tabScale)
		tab.SelectedHighlight:SetFrameLevel(self.tabRuleLayer:GetFrameLevel() + 1)
		tab.SelectedHighlight:EnableMouse(false)
	end
	tab.Text:SetWordWrap(false); tab.Text:SetMaxLines(1); tab.Text:SetJustifyH("CENTER")
	-- Native art disables itself when selected. Keep it visual-only so refreshes
	-- cannot cancel the separate button's mouse capture between down and up.
	tab:EnableMouse(false)
	tab:SetScript("OnClick", nil); tab:SetScript("OnEnter", nil); tab:SetScript("OnLeave", nil)
	local hit = CreateFrame("Button", nil, self.tabBar)
	tab.hitButton = hit
	hit:SetScale(S.tabScale); hit:SetFrameLevel(tab:GetFrameLevel() + 11)
	hit:EnableMouse(true); hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	hit:SetScript("OnEnter", function() self:RefreshTabHighlight(tab) end)
	local function release()
		setTabPressed(tab, false); self:RefreshTabHighlight(tab)
	end
	hit:SetScript("OnLeave", release)
	hit:SetScript("OnHide", function() hit.pressKey = nil; release() end)
	hit:SetScript("OnMouseDown", function(button, mouseButton)
		button.pressKey = button.key
		if mouseButton == "LeftButton" then setTabPressed(tab, true) end
	end)
	hit:SetScript("OnMouseUp", function() setTabPressed(tab, false) end)
	hit:SetScript("OnClick", function(button, mouseButton)
		local pressKey = button.pressKey
		button.pressKey = nil
		if pressKey and pressKey ~= button.key then return end
		if mouseButton == "RightButton" then self:ShowTabMenu(button); return end
		if button.key ~= self.selectedKey then self:Select(button.key) end
		self:RefreshActions()
		if self.input:IsEnabled() then self.input:SetFocus() end
		UI.PlayUISound("tab")
	end)
	return tab
end
function View:RefreshTabs()
	local conversations = self.service:List(self.context)
	local width = math.max(1, self.tabBar:GetWidth())
	local minWidth, maxWidth = S.tabMinWidth * S.tabScale, S.tabMaxWidth * S.tabScale
	local fullCapacity = math.max(1, math.floor((width + S.tabGap) / (minWidth + S.tabGap)))
	local overflow = #conversations > fullCapacity
	local reserved = overflow and 2 * (S.tabArrowWidth + S.tabGap) or 0
	local pinned, paged = nil, conversations
	if overflow then
		-- Keep the reply target visible while paging through the other contacts.
		-- This is a view projection; the service's conversation order is unchanged.
		paged = {}
		for _, conversation in ipairs(conversations) do
			if conversation.key == self.selectedKey then pinned = conversation
			else paged[#paged + 1] = conversation end
		end
	end
	local pinnedCount = pinned and 1 or 0
	self.capacity = math.max(1 + pinnedCount, math.floor((width - reserved + S.tabGap) / (minWidth + S.tabGap)))
	self.pagingCapacity, self.pagingCount = self.capacity - pinnedCount, #paged
	self.firstTab = math.max(1, math.min(self.firstTab, math.max(1, #paged - self.pagingCapacity + 1)))
	self.previous:SetShown(overflow); self.next:SetShown(overflow)
	self.previous:SetEnabled(self.firstTab > 1)
	self.next:SetEnabled(self.firstTab + self.pagingCapacity <= #paged)
	local pagedCount = math.min(self.pagingCapacity, #paged)
	local visibleCount = pagedCount + pinnedCount
	local before, after = 0, 0
	for index, conversation in ipairs(paged) do
		if index < self.firstTab then before = before + conversation.unread
		elseif index >= self.firstTab + pagedCount then after = after + conversation.unread end
	end
	self:UpdateUnreadArrow(self.previous, before)
	self:UpdateUnreadArrow(self.next, after)
	local tabWidth = math.min(maxWidth, (width - reserved - math.max(0, visibleCount - 1) * S.tabGap) / math.max(1, visibleCount))
	for index = 1, math.max(visibleCount, #self.tabs) do
		local tab = self.tabs[index]
		if index <= visibleCount then
			if not tab then
				tab = self:CreateTab()
				self.tabs[index] = tab
			end
			local conversation = index <= pinnedCount and pinned or paged[self.firstTab + index - pinnedCount - 1]
			if tab.key ~= conversation.key then
				UI.SetNativeTabUnread(tab, false, true)
				setTabPressed(tab, false); tab:UnlockHighlight()
			end
			tab.key = conversation.key
			tab.hitButton.key = conversation.key
			UI.SetNativeTabText(tab, shortName(conversation.name))
			local localWidth = tabWidth / S.tabScale
			tab:SetSize(localWidth, S.tabHeight)
			tab.Text:SetWidth(math.max(1, localWidth - S.gap * 2))
			-- Align the visible gold highlight, not the native button's padded bottom.
			local baseline = 0
			if tab.SelectedHighlight then
				local _, _, _, _, y = tab.SelectedHighlight:GetPoint(1)
				baseline = y + tab.SelectedHighlight:GetHeight() / 2
			end
			local left = (overflow and S.tabArrowWidth + S.tabGap or 0) + (index - 1) * (tabWidth + S.tabGap)
			-- Anchoring offsets are in the scaled tab's own coordinate system.
			tab:ClearAllPoints(); tab:SetPoint("BOTTOMLEFT", self.tabBar, "BOTTOMLEFT", left / S.tabScale,
				-self.tabDivider:GetHeight() / (2 * S.tabScale) - baseline)
			tab:SetHitRectInsets(0, 0, 0, math.max(0, baseline - self.tabDivider:GetHeight() / (2 * S.tabScale)))
			UI.SetNativeTabSelected(tab, conversation.key == self.selectedKey)
			tab.textPoint = { tab.Text:GetPoint(1) }
			setTabPressed(tab, tab.pressed)
			local hit = tab.hitButton
			-- Cover the visible atlas, including its expanded cap, but stop at the gold rule.
			local left = tab._gfTopTabStyle and (tab._gfSelected and tab.RightActive or tab.Right) or tab
			local right = tab._gfTopTabStyle and (tab._gfSelected and tab.LeftActive or tab.Left) or tab
			if hit.anchorLeft ~= left or hit.anchorRight ~= right then
				hit:ClearAllPoints(); hit:SetPoint("TOPLEFT", left, "TOPLEFT"); hit:SetPoint("TOPRIGHT", right, "TOPRIGHT")
				hit:SetPoint("BOTTOM", self.tabDivider, "BOTTOM")
				hit.anchorLeft, hit.anchorRight = left, right
			end
			tab.unreadCount = conversation.unread
			UI.SetNativeTabUnread(tab, conversation.unread > 0)
			self:RefreshTabHighlight(tab)
			hit:Show()
			tab:Show()
		elseif tab then
			tab.unreadCount = 0
			UI.SetNativeTabUnread(tab, false)
			tab.hitButton:Hide(); tab:Hide()
			if tab.SelectedHighlight then tab.SelectedHighlight:Hide() end
		end
	end
end
function View:MarkVisibleRead()
	-- Cold/warm route construction must not read the previously selected sender
	-- before the explicit notification target has been projected.
	if self.panel.pendingConversationKey and self.panel.pendingConversationKey ~= self.selectedKey then return end
	local c = self.service:Get(self.selectedKey)
	if not c or c.unread == 0 or not self:IsPresenceInteractive() or self.refreshing
		or self.renderedKey ~= c.key or self.renderedRevision ~= c.revision
		or not self:IsReadingBottom() then return end
	local last = c.messages[#c.messages]
	if last and self.messageAppearances[last] ~= true then return end
	self.service:MarkRead(c.key); self:RefreshTabs()
end
function View:LayoutStatus()
	local width = math.max(1, self.footerClip:GetWidth())
	self.statusBody:SetWidth(width)
	local actionsShown = self.applicantActionsWanted == true
		and self.statusCurrent == label("OFFER_APPLIED") and self.statusWanted == self.statusCurrent
	self.applicantActions:SetShown(actionsShown)
	if self.statusHasActions ~= actionsShown then
		self.statusHasActions = actionsShown
		self.statusText:ClearAllPoints()
		self.statusText:SetPoint("LEFT", self.statusBody, "LEFT", S.footerInset, 0)
		self.statusText:SetPoint("RIGHT", self.statusBody, "RIGHT",
			-S.footerInset - (actionsShown and self.applicantActions:GetWidth() + S.gap or 0), 0)
	end
	local interactive = actionsShown and self:IsPresenceInteractive() and self.statusProgress == 1
	self.applicantInvite:SetEnabled(interactive and self.applicantCanInvite == true)
	self.applicantDecline:SetEnabled(interactive and self.applicantCanDecline == true)
	local height = math.max(S.statusMinHeight, self.statusText:GetStringHeight() + S.statusTextInsetY * 2)
	self.statusBody:SetHeight(height); self.statusClip:SetHeight(height)
	self.statusClip:SetWidth(math.max(0.01, width * (self.statusProgress or 0)))
	self.statusClip:SetAlpha((self.statusProgress or 0) * (self.presenceProgress or 0))
	local shown = self.statusCurrent ~= nil
	self.statusClip:SetShown(shown); self.statusText:SetShown(shown)
	-- Reserve the full line until its exit ends, so shrinking text never covers messages.
	local reserved = shown and height + S.gap or 0
	if self.statusHeight ~= reserved then
		self.statusHeight = reserved; self:SetScrollProgress(self.scrollProgress or 0); self.dirty = true
	end
end
function View:StopStatusAnimation()
	self.statusCurrent, self.statusWanted, self.statusOwner, self.statusFade = nil, nil, nil, nil
	self.statusProgress = 0
	self.statusDriver:SetScript("OnUpdate", nil); self.statusDriver:Hide()
	self.statusText:SetText(""); self:LayoutStatus()
end
function View:SetStatus(text, owner)
	if not self.frame:IsVisible() then return end
	if self.statusOwner ~= owner then self:StopStatusAnimation(); self.statusOwner = owner end
	self.statusWanted = text
	local progress = self.statusProgress or 0
	if progress == 0 then
		self.statusCurrent = text
		self.statusText:SetText(text or "")
	end
	local target = text and text == self.statusCurrent and 1 or 0
	if progress ~= target then
		if not self.statusFade or self.statusFade.target ~= target then
			self.statusFade = { from = progress, target = target, elapsed = 0 }
			self.statusDriver:SetScript("OnUpdate", function(_, elapsed) self:TickStatusAnimation(elapsed) end)
			self.statusDriver:Show()
		end
	else
		self.statusFade = nil
		self.statusDriver:SetScript("OnUpdate", nil); self.statusDriver:Hide()
	end
	self:LayoutStatus()
end
function View:TickStatusAnimation(elapsed)
	local fade = self.statusFade
	if not fade then return end
	fade.elapsed = fade.elapsed + math.max(0, elapsed)
	local p = math.min(1, fade.elapsed / S.statusDuration)
	self.statusProgress = fade.from + (fade.target - fade.from) * p * p * (3 - 2 * p)
	self:LayoutStatus()
	if p == 1 then
		self.statusFade = nil
		self.statusDriver:SetScript("OnUpdate", nil); self.statusDriver:Hide()
		self:SetStatus(self.statusWanted, self.statusOwner)
		self:Refresh()
	end
end
function View:RefreshActions()
	local c = self.service:Get(self.selectedKey)
	-- Native whisper confirmation must not disable the editor and drop keyboard focus.
	local enabled = self:IsPresenceInteractive() and c and not c.ended and not c.recovering
		and not self.service.seeking.transport.adapter.Locked()
	if self.input:IsEnabled() ~= (enabled == true) then
		self.input:SetEnabled(enabled == true)
		self.inputShell:RefreshVisualState()
	end
	local state = c and (c.ended and "CHAT_ENDED" or c.recovering and "CHAT_RECOVERING"
		or c.connecting and "CHAT_CONNECTING" or c.sendFailed and "CHAT_UNCONFIRMED")
	-- All ended reasons occupy the footer; never repeat them in the status strip.
	local ended = c and c.ended == true
	local unavailable = ended or c and c.recovering == true
	local statusText = not unavailable and state and label(state) or nil
	local applicant = not state and self.context == "board" and self.service:GetRequestedApplicant(self.selectedKey) or nil
	self.requestedApplicant = applicant
	local applied = applicant and applicant.status == "applied"
	local roster, actions = GF.ApplicantsPanel, GF.ApplicantActionService
	local pending = applied and roster and roster:IsApplicantActionPending(applicant.applicantID)
	self.applicantActionsWanted = applied == true
	self.applicantCanInvite = applied and not applicant.loading and not pending
		and actions:CanInvite(applicant.applicantID) == true
	self.applicantCanDecline = applied and not applicant.loading and not pending
		and actions:CanDecline(applicant.applicantID) == true
	if applicant then
		statusText = applied and label("OFFER_APPLIED") or actions:GetStatusText(applicant.status)
	end
	if not state and not statusText and c then
		if self.context == "seeking" and (c.applicationRequest or #c.messages == 0) and self.service:GetContact(c.key) then
			statusText = string.format(label("CONTACT_REQUEST"), catalogValue(self, self.panel.activityNames, c.activityID) or label("CHAT_UNKNOWN_ACTIVITY"))
		elseif self.context == "board" and c.applicationRequest and c.applicationConfirmed then statusText = label("OFFER_WAITING") end
	end
	self:SetStatus(statusText, c)
	-- Keep the input border visible; only conceal draft text beneath the end reason.
	self.inputShell:Show()
	self.input:SetAlpha(unavailable and 0 or 1)
	if unavailable then self.input:ClearFocus() end
	self.endNotice:SetShown(unavailable == true)
	self.endText:SetText(ended and endLabel(c) or unavailable and label("CHAT_RECOVERING") or "")
	self.closeConversation:SetText(label("CHAT_CLOSE"))
	self.closeConversation:SetShown(unavailable == true)
	self.closeConversation:SetEnabled(unavailable and self:IsPresenceInteractive() or false)
	self.placeholder:SetText(label(c and (c.ended and "CHAT_ENDED" or "CHAT_REPLY") or self.context == "board" and "BOARD_CHAT_HINT" or "CHAT_SELECT"))
	self.placeholder:SetShown(self.input:GetText() == "")
	self.openLeader:SetText(label("OPEN_LEADER"))
	local contact = self.service:GetContact(self.selectedKey)
	local showLeader = self.context == "seeking" and not unavailable
	self.openLeader:SetShown(showLeader)
	self.openLeader:SetEnabled(self:IsPresenceInteractive() and contact ~= nil)
	local showInvite = self.context == "board" and not unavailable
	local record = showInvite and self.service:GetBoardRecord(self.selectedKey) or nil
	local mode = record and record.mode or c and c.recordMode
	self.boardAction:SetText(label(mode == "party" and "BOARD_OFFER" or "BOARD_INVITE"))
	self.boardAction:SetShown(showInvite)
	self.boardAction:SetEnabled(self:IsPresenceInteractive() and record ~= nil
		and self.service:CanOpenRecord(record, true) == true)
end
function View:SubmitApplicantAction(action)
	local target = self.requestedApplicant
	if self.context ~= "board" or not self:IsPresenceInteractive() or self.statusProgress ~= 1
		or not target or self.selectedKey ~= target.key then return end
	local live = self.service:GetRequestedApplicant(target.key)
	if not live or live.status ~= "applied" or live.loading or live.applicantID ~= target.applicantID
		or live.request ~= target.request or live.token ~= target.token or live.members ~= target.members then
		self:RefreshActions(); return
	end
	local roster, presenter = GF.ApplicantsPanel, GF.ApplicantRosterPresenter
	if not roster or not presenter or roster:IsApplicantActionPending(live.applicantID) then return end
	-- Share the exact card transaction, including pending provenance, group-size
	-- checks, raid-conversion confirmation and terminal decline reconciliation.
	presenter.SubmitApplicantAction(roster, live, action)
	self:RefreshActions()
end
function View:InviteFromChat()
	if self.context ~= "board" or not self:IsPresenceInteractive() then return end
	local record = self.service:GetBoardRecord(self.selectedKey)
	if not record then self.panel:Result(false, "expired"); return end
	local seeking = self.service.seeking
	if record.mode == "party" then
		local ok, reason, conversation = seeking:OfferListing(record.key, record.revision,
			seeking.adapter.ActiveActivity(), record.session)
		if ok and conversation then self:Select(conversation.key) end
		self.panel:Result(ok, reason, "OFFER_SENT")
	else
		local ok, reason = seeking:Invite(record.key, record.revision, record.session)
		self.panel:Result(ok, reason, "INVITE_SENT")
	end
end
function View:Send()
	local ok, reason = self.service:Send(self.selectedKey, self.input:GetText())
	local c = self.service:Get(self.selectedKey)
	if not ok and reason ~= "chat_pending" and not (c and c.ended) then self.panel:Result(false, reason or "unavailable") end
	self:RefreshActions()
end
function View:CreateRow()
	local row = CreateFrame("Frame", nil, self.child)
	row.avatar = row:CreateTexture(nil, "ARTWORK")
	row.header = CreateFrame("Frame", nil, row); row.header:SetHeight(S.nameHeight)
	row.header:SetClipsChildren(true)
	row.name = font(row.header, "GameFontNormalSmall")
	row.name:SetWordWrap(false); row.name:SetMaxLines(1)
	row.detail = font(row.header, "GameFontNormalSmall", S.headerMetaFontExtra)
	row.detail:SetWordWrap(false); row.detail:SetMaxLines(1)
	row.name:SetJustifyV("MIDDLE"); row.detail:SetJustifyV("MIDDLE")
	row.divider = GF.ColumnHeaderBar:CreateDivider(row.header, S.headerDividerHeight)
	row.divider:SetWidth(S.headerDividerWidth)
	GF.ColumnHeaderBar:TintDivider(row.divider, S.headerDividerColor)
	row.specs = {}
	row.bubble = CreateFrame("Frame", nil, row)
	row.message = font(row.bubble)
	row.message:SetPoint("TOPLEFT", S.bubbleInset, -S.bubbleInset)
	row.message:SetPoint("TOPRIGHT", -S.bubbleInset, -S.bubbleInset)
	row.message:SetSpacing(S.messageSpacing)
	return row
end
function View:LayoutHeader(row, conversation, message, profile, textWidth, side, opposite, leader)
	row.header:ClearAllPoints()
	row.header:SetPoint("TOP" .. side, row.avatar, "TOP" .. opposite, message.incoming and S.gap or -S.gap, 0)
	row.name:SetText(shortName(profile.name))
	clearIcons(row)
	local specs = not leader and profile.specIDs or {}
	if leader then
		local activityID = message.activityID
		if conversation.context ~= "board" then activityID = activityID or conversation.activityID end
		row.detail:SetText(headerActivity(self, activityID))
		row.detail:SetTextColor(unpack(S.activityColor))
	else
		local itemLevel = profile.itemLevel and profile.itemLevel > 0 and tostring(profile.itemLevel) or label("UNKNOWN")
		row.detail:SetText(string.format(label("CHAT_ITEM_LEVEL"), colorText(itemLevel, S.itemLevelColor)))
		row.detail:SetTextColor(unpack(S.headerMetaColor))
	end
	local dividerSpan = S.headerGap * 2 + S.headerDividerWidth
	local nameNatural, detailNatural = headerTextWidth(row.name), headerTextWidth(row.detail)
	local showMeta = textWidth >= dividerSpan + 2
	local specWidth = #specs > 0 and #specs * (S.specSize + S.specGap) - S.specGap + S.headerGap or 0
	local nameWidth = nameNatural
	-- Use intrinsic widths first; share the space only when the entire header cannot fit.
	if nameNatural + dividerSpan + specWidth + detailNatural > textWidth then
		nameWidth = math.min(nameNatural, math.max(1, (textWidth - dividerSpan) / 2))
	end
	local metaBudget = math.max(0, textWidth - nameWidth - dividerSpan)
	local specCount = showMeta and math.min(#specs, math.max(0, math.floor((metaBudget - S.headerGap - 1) / (S.specSize + S.specGap)))) or 0
	specWidth = specCount > 0 and specCount * (S.specSize + S.specGap) - S.specGap + S.headerGap or 0
	local detailWidth = showMeta and math.min(detailNatural, math.max(1, metaBudget - specWidth)) or 0
	nameWidth = math.min(nameNatural, math.max(1, textWidth - specWidth - detailWidth - (showMeta and dividerSpan or 0)))
	row.name:SetWidth(nameWidth); row.name:SetHeight(0)
	row.detail:SetWidth(detailWidth); row.detail:SetHeight(0)
	local headerHeight = math.max(S.nameHeight, math.ceil(row.name:GetStringHeight()), math.ceil(row.detail:GetStringHeight()))
	row.name:SetHeight(headerHeight); row.detail:SetHeight(headerHeight)
	row.name:ClearAllPoints()
	if message.incoming then row.name:SetPoint("TOPLEFT") end
	local x = message.incoming and nameWidth + dividerSpan or 0
	for n = 1, specCount do
		local specID = specs[n]
		local icon = row.specs[n] or row.header:CreateTexture(nil, "ARTWORK"); row.specs[n] = icon
		icon:ClearAllPoints(); icon:SetPoint("TOPLEFT", x, -(headerHeight - S.specSize) / 2)
		UI.SetSpecializationIcon(icon, catalogValue(self, self.panel.specIcons, specID) or GF.RAID_SEEKING_STYLE.memberUnknownIcon, { size = S.specSize })
		x = x + S.specSize + (n == specCount and S.headerGap or S.specGap)
	end
	row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT", x, 0)
	row.detail:SetShown(showMeta); row.divider:SetShown(showMeta)
	local headerWidth = showMeta and x + detailWidth or nameWidth
	local dividerX = nameWidth + S.headerGap
	if not message.incoming then
		dividerX = x + detailWidth + S.headerGap
		local nameX = showMeta and x + detailWidth + dividerSpan or 0
		row.name:SetPoint("TOPLEFT", nameX, 0)
		headerWidth = nameX + nameWidth
	end
	row.divider:ClearAllPoints(); row.divider:SetPoint("TOPLEFT", dividerX, -(headerHeight - S.headerDividerHeight) / 2)
	row.header:SetSize(headerWidth, headerHeight)
end
function View:LayoutMessages(conversation, width)
	self.child:SetWidth(width)
	local y = S.messageEdgeInset
	for index, message in ipairs(conversation.messages) do
		local row = self.rows[index] or self:CreateRow(); self.rows[index] = row
		self:ApplyMessageAppearance(row, message)
		local incoming = message.incoming
		local profile = message.profile or (incoming and { name = conversation.name, classFile = conversation.classFile } or {})
		local leader = (conversation.context == "board") ~= incoming
		local side = incoming and "LEFT" or "RIGHT"
		local opposite = incoming and "RIGHT" or "LEFT"
		row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetWidth(width)
		row.avatar:ClearAllPoints(); row.avatar:SetPoint("TOP" .. side, 0, 0)
		local class = profile.classFile or profile.classID or (incoming and conversation.classFile)
		if not class and not incoming and UnitClass then
			local _, playerClass = UnitClass("player")
			class = P.Text(playerClass)
		end
		local classIcon, classFile = UI.ResolveClassIcon(class)
		UI.SetSpecializationIcon(row.avatar, classIcon or GF.RAID_SEEKING_STYLE.memberUnknownIcon, { size = S.avatarSize })
		local textWidth = math.max(1, width - S.avatarSize - S.gap)
		self:LayoutHeader(row, conversation, message, profile, textWidth, side, opposite, leader)
		local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
		row.name:SetTextColor(color and color.r or S.unknownNameColor[1], color and color.g or S.unknownNameColor[2], color and color.b or S.unknownNameColor[3])
		row.bubble:ClearAllPoints(); row.bubble:SetPoint("TOP" .. side, row.header, "BOTTOM" .. side, 0, -S.gap / 2)
		-- Escape inline markup: a stranger's message cannot inject textures or UI links.
		row.message:SetText(P.Display(message.text))
		row.message:SetWidth(math.max(1, textWidth - S.bubbleInset * 2))
		local bubbleWidth = math.min(textWidth, math.max(S.bubbleMinHeight * 2, row.message:GetStringWidth() + S.bubbleInset * 2))
		row.bubble:SetWidth(bubbleWidth)
		row.message:SetWidth(math.max(1, bubbleWidth - S.bubbleInset * 2))
		local bubbleHeight = math.max(S.bubbleMinHeight, row.message:GetStringHeight() + S.bubbleInset * 2)
		row.bubble:SetHeight(bubbleHeight)
		layoutBubble(row.bubble, leader, color)
		local height = math.max(S.avatarSize, row.header:GetHeight() + S.gap / 2 + bubbleHeight)
		row:SetHeight(height); row:Show(); y = y + height + S.messageGap
	end
	for index = #conversation.messages + 1, #self.rows do
		self.rows[index].messageRecord = nil; self.rows[index]:Hide()
	end
	self.child:SetHeight(#conversation.messages > 0 and y - S.messageGap + S.messageEdgeInset or 1)
	self.scrollExtent:SetSize(width, self.child:GetHeight())
	self:SyncMessageAnimationDriver()
	return self.child:GetHeight()
end
function View:RenderMessages(conversation)
	local fullWidth = math.max(1, self.frame:GetWidth())
	local switched = self.renderedKey ~= conversation.key
	if switched then UI.CancelSmoothWheelScrolling(self.scroll); self:FinishMessageAnimations() end
	local changed = self.renderedRevision ~= conversation.revision
	if not self.dirty and not switched and not changed and self.renderedWidth == fullWidth and self.renderedHeight == self.scroll:GetHeight() then return end
	local atBottom = self:IsReadingBottom()
	local previousOffset = self.scroll:GetVerticalScroll()
	-- Measure without a gutter so wrapping cannot keep an obsolete bar open.
	local fullHeight = self:LayoutMessages(conversation, fullWidth)
	local target = fullHeight > self.scroll:GetHeight() + S.scrollOverflowEpsilon and 1 or 0
	self.scrollConversation = conversation
	if self.scrollTarget ~= target then
		self.scrollTarget = target
		local from = self.scrollProgress or 0
		self.scrollFade = from ~= target and { from = from, target = target, elapsed = 0 } or nil
		self.scrollDriver:SetShown(self.scrollFade ~= nil)
	end
	self:SetScrollProgress(self.scrollProgress or 0)
	local width = math.max(1, self.scroll:GetWidth())
	if width ~= fullWidth then self:LayoutMessages(conversation, width) end
	self.scroll:UpdateScrollChildRect()
	local range = self.scroll:GetVerticalScrollRange()
	local offset = switched and (self.offsets[conversation.key] or range) or atBottom and range or previousOffset
	self.scroll:SetVerticalScroll(math.max(0, math.min(range, offset)))
	self:SyncScrollBar()
	self.renderedKey, self.renderedRevision, self.renderedWidth = conversation.key, conversation.revision, fullWidth
	self.renderedHeight = self.scroll:GetHeight()
end
function View:Refresh(force)
	if self.refreshing then return end
	if force or self.catalogPending then self.dirty = true end
	self.refreshing = true
	local ok, reason = pcall(self.Paint, self)
	self.refreshing, self.loading = nil, nil
	if not ok then
		self.dirty = true
		error(reason, 0)
	end
	self.dirty = nil
	self:MarkVisibleRead()
end
function View:Paint()
	self.catalogPending = nil
	self.service:SyncContacts()
	local list = self.service:List(self.context)
	local selected = self.service:Get(self.selectedKey)
	if not selected or selected.closed or selected.hidden or (selected.context or "seeking") ~= self.context then
		selected = self:RecentOpenConversation(list)
		self.selectedKey = selected and selected.key
		self:RememberSelection(selected)
	end
	local conversation = self.service:Get(self.selectedKey)
	self:SyncInputDraft(conversation)
	self:RefreshActions()
	if conversation then
		self:RefreshTabs()
		self.conversationEmpty:SetShown(#conversation.messages == 0 and not self.statusWanted)
		local emptyText = self.service:GetContact(conversation.key) and string.format(label("CONTACT_REQUEST"), catalogValue(self, self.panel.activityNames, conversation.activityID) or label("CHAT_UNKNOWN_ACTIVITY")) or label("CHAT_START")
		if self.context == "board" and conversation.applicationRequest and not conversation.ended then
			emptyText = label(conversation.applicationConfirmed and "OFFER_WAITING" or "CHAT_CONNECTING")
		end
		self.conversationEmpty:SetText(emptyText)
		self:RenderMessages(conversation)
	else
		-- Retain the last rendered tabs and messages until their fade-out completes.
		self:HideUnreadIndicators()
		self.scrollFade = nil; self.scrollDriver:Hide(); self.scrollBar:UnregisterUpdate()
	end
	self:SetPresenceShown(conversation ~= nil)
end
