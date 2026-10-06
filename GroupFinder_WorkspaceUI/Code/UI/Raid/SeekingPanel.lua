local _, GF = ...
GF = GF.GF or GF

local UI, P = GF.UI, GF.RaidSeekingProtocol
local S = GF.RAID_SEEKING_STYLE
local FORM_STATE_EVENTS = {
	GROUP_ROSTER_UPDATE = true, GROUP_JOINED = true, GROUP_LEFT = true,
	PARTY_LEADER_CHANGED = true, LFG_LIST_ACTIVE_ENTRY_UPDATE = true,
	PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true,
}
local Panel = { filters = {} }
GF.RaidSeekingPanel = Panel
local function service() return GF.RaidSeekingService end
local function label(key) return (GF.L or {})["SEEK_" .. key] or (GF.L or {})[key] or key end
local function errorText(reason)
	if reason == "offline_member" then return P.Text(LFG_LIST_OFFLINE_MEMBER) or label("ERROR_OFFLINE_MEMBER") end
	local key = "ERROR_" .. (reason or "unavailable"):upper()
	if reason and reason:match("^chat_") and not (GF.L or {})["SEEK_" .. key] then key = "ERROR_CHAT_ENDED" end
	return label(key)
end
local function channelErrorText(reason)
	return string.format(label("CHANNEL_ERROR_FMT"), errorText(reason))
end
local function partyFailureHint()
	local t = service().transport
	if t.state == "ready" and t.echoAt then return label("PARTY_CHANNEL_READY_HINT") end
	if t.state == "error" then return channelErrorText(t.reason) .. "\n" .. label("PARTY_ACTIVITY_RETRY_HINT") end
	return label("PARTY_ACTIVITY_RETRY_HINT")
end
local function visible(frame)
	if not frame then return false end
	if frame.IsVisible then return frame:IsVisible() end
	return frame:IsShown()
end
local function text(parent, template)
	local value = UI.CreateFontString(parent, "OVERLAY", template or "GameFontHighlightSmall")
	value:SetJustifyH("LEFT"); value:SetJustifyV("TOP"); value:SetWordWrap(true)
	return value
end
local function subheading(parent)
	local value = text(parent, "GameFontNormal")
	value:SetSpacing(S.lineSpacing)
	value._gfFontSizeOverride = S.subheadingTextSize
	if GF.Font and GF.Font.ApplyToFontString then GF.Font.ApplyToFontString(value, "GameFontNormal") end
	return value
end
local function fill(parent, color)
	local texture = parent:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints(); texture:SetColorTexture(unpack(color))
	return texture
end
local function caption(parent, key, y)
	local value = subheading(parent)
	if y then value:SetPoint("TOPLEFT", S.inset, -y); value:SetPoint("TOPRIGHT", -S.inset, -y) end
	value.localeKey = key
	value:SetText(label(key))
	Panel.captions[#Panel.captions + 1] = value
	return value
end
local function button(parent, key, callback, width)
	local value = UI.CreatePanelButton(parent, label(key), width or S.buttonWidth)
	value.localeKey = key; Panel.buttons[#Panel.buttons + 1] = value
	value:SetScript("OnClick", callback)
	return value
end
local function dropdown(parent, y, build)
	local value = UI.CreateDropdownButton(parent)
	if y then value:SetPoint("TOPLEFT", S.inset, -y) end
	value:SetWidth(S.fieldWidth)
	local defaultAnchor = value.menuAnchor
	value:SetupMenu(function(owner, root)
		owner:SetMenuAnchor(defaultAnchor)
		build(root, owner)
		-- Reposition an already-open menu when its empty/normal state changes.
		if owner.menu then owner.menuAnchor:SetPoint(owner.menu, true) end
	end)
	return value
end
local function showEmptyMenu(root, owner, key)
	local message = label(key)
	owner:SetMenuAnchor(AnchorUtil.CreateAnchor("TOP", owner, "BOTTOM", 0, 0))
	root:CreateTitle(message):AddInitializer(function(frame, _, menu)
		local notice = frame.fontString
		local menuScale = menu:GetEffectiveScale()
		local sample = Panel.notePlaceholder
		GF.Font.ApplyToMenuFontString(notice, "GameFontHighlightSmall", sample,
			sample:GetEffectiveScale() / menuScale)
		notice:SetTextToFit(message)
		local lineHeight = notice:GetStringHeight()
		local height = math.max(notice:GetHeight(), lineHeight)
		-- Menus use the top-level UI scale, not necessarily the dropdown's scale.
		-- Match the Background atlas quad, including both controls' native outsets.
		local ratio = owner:GetEffectiveScale() / menuScale
		local width = math.max(1, math.floor(owner.Background:GetWidth() * ratio - 2 * S.emptyMenuBackgroundOutsetX + 0.5))
		root:SetMinimumWidth(width); root:SetMaximumWidth(width)
		local insets, padding = menu:GetInset(), menu:GetChildExtentPadding()
		notice:SetTextColor(unpack(S.emptyMenuTextColor))
		-- The rendered glyphs sit slightly below the line box's center. Apply
		-- a small screen-pixel correction without changing the popup geometry.
		notice:ClearAllPoints(); notice:SetPoint("CENTER", menu, "CENTER", 0, S.emptyMenuTextOffsetYPixels / menuScale)
		notice:SetSize(math.max(1, width - insets.left - insets.right), lineHeight)
		notice:SetJustifyH("CENTER"); notice:SetJustifyV("MIDDLE"); notice:SetWordWrap(false)
		return math.max(1, width - insets.left - insets.right - padding.width), height
	end)
end
local function showMissingLeaderPublication(root, owner)
	local s = service()
	if not s:CanEditForm() and not s:GetLeaderPublication() then
		local _, _, state = s:GetActivityView()
		showEmptyMenu(root, owner, state == "empty" and "LEADER_PUBLICATION_UNAVAILABLE"
			or state == "loading" and "PARTY_ACTIVITY_LOADING" or "PARTY_ACTIVITY_UNAVAILABLE")
		return true
	end
	return false
end
local function radio(root, name, isSelected, select)
	return root:CreateRadio(name, isSelected, function() select(); Panel:Refresh(true) end)
end
local function activityNames(ids)
	local names, map = {}, Panel.activityNames or {}
	for _, id in ipairs(ids or {}) do names[#names + 1] = map[id] or ("#" .. id) end
	return table.concat(names, " / ")
end
local function roleNames(mask)
	local names = {}
	for index, bit in ipairs({ 1, 2, 4 }) do
		if P.HasRole(mask, bit) then names[#names + 1] = label(({ "TANK", "HEALER", "DAMAGER" })[index]) end
	end
	return #names > 0 and table.concat(names, "/") or label("UNKNOWN")
end
function Panel:Result(ok, reason, success)
	if ok then self.message = success and label(success) or nil
	else self.message = errorText(reason) end
	self.messageAt = service():Now()
	if not ok and reason == "not_max_level" and GF.ShowTopNotice then
		GF.ShowTopNotice(label("LEVEL_RESTRICTED"), { source = "warning", subtitle = self.message })
	elseif not ok and (reason == "offline_member" or reason == "not_max_level" or reason == "member_data_timeout") and GF.ShowWarningMessage then
		GF.ShowWarningMessage(self.message)
	elseif self.frame and (not self.frame:IsShown() or self.tabID == GF.TAB_RAID_SQUARE)
		and self.message and GF.ShowStatusMessage then
		GF.ShowStatusMessage(self.message, { semantic = true })
	end
	self:Refresh(true)
end
function Panel:Selected()
	local record = self.selectedKey and service():GetLive(self.selectedKey)
	return record and record.revision == self.selectedRevision and record.session == self.selectedSession and record or nil
end
function Panel:RequestPublish(action)
	local s = service()
	if s.pendingRequest or s.pendingAt then return end
	if (action == "PUBLISH" and s.current) or (action == "UPDATE" and not s.current) then return end
	local ok, reason = s:RequestPublish()
	self.pendingAction = ok and (s.pendingRequest or s.pendingAt) and action or nil
	if ok then
		self.activityAttention = nil
		if action == "UPDATE" and self.frame:IsShown() and self.tabID == GF.TAB_RAID_SEEK then
			self:RefreshActivityBadge(s:GetMyActivity() ~= nil, true)
		end
	end
	self:Result(ok, reason)
end
function Panel:CanWhisper(record)
	return GF.RaidSeekingChatService:CanOpenRecord(record)
end
function Panel:Whisper()
	local record = self:Selected()
	if not record then self:Result(false, "expired"); return end
	if service():IsOwn(record) then self:Result(false, "own_post"); return end
	local activityID
	for _, id in ipairs(record.activityIDs) do
		if self.filters.activityIDs == nil or self.filters.activityIDs[id] == true then activityID = id; break end
	end
	local conversation, reason = GF.RaidSeekingChatService:OpenRecord(record.key, record.revision, record.session, activityID)
	if not conversation then self:Result(false, reason); return end
	self.chat:Select(conversation.key)
	self.chat:Refresh(true)
end
function Panel:OpenLeader(key)
	local ok, reason = GF.FindGroupTab:FindRaidLeader(key)
	if not ok then self:Result(false, reason or "search_busy") end
end

function Panel:EnterFeature()
	self:Result(service():EnterFeature(self.tabID == GF.TAB_RAID_SQUARE))
end
local function card(parent)
	local value = CreateFrame("Frame", nil, parent)
	UI.ApplyControlCardChrome(value)
	value:HookScript("OnSizeChanged", function() UI.ApplyControlCardChrome(value) end)
	return value
end
local function section(parent, key)
	local value = card(parent)
	local header = UI.CreateCardHeader(value, label(key))
	header:SetFrameLevel(value:GetFrameLevel() + 4)
	local title = header.title
	title.localeKey = key; Panel.captions[#Panel.captions + 1] = title
	value.header, value.title = header, title
	return value
end
local function cardContent(parent, bottomInset, topInset)
	bottomInset = bottomInset or S.contentInset
	local content = CreateFrame("Frame", nil, parent)
	content:SetPoint("TOP", parent.header.rule, "BOTTOM", 0, -(topInset or S.contentTop))
	content:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", S.contentInset, bottomInset)
	content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -S.contentInset, bottomInset)
	return content
end

local function centeredPrompt(parent)
	local group = CreateFrame("Frame", nil, parent)
	group:SetPoint("CENTER"); group:SetPoint("LEFT"); group:SetPoint("RIGHT")
	local title = subheading(group)
	title:SetPoint("TOPLEFT"); title:SetPoint("TOPRIGHT")
	title:SetJustifyH("CENTER"); title:SetTextColor(unpack(S.mutedColor))
	local body = text(group)
	body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -S.titleGap)
	body:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -S.titleGap)
	body:SetJustifyH("CENTER"); body:SetSpacing(S.lineSpacing)
	body:SetTextColor(unpack(S.mutedColor))
	return group, title, body
end

local function refreshCenteredPrompt(group, title, body, heading, description)
	title:SetText(heading); body:SetText(description)
	title:SetHeight(title:GetStringHeight()); body:SetHeight(body:GetStringHeight())
	group:SetHeight(title:GetHeight() + S.titleGap + body:GetHeight())
end

function Panel:CancelLayoutRefresh()
	local request = self.layoutRequest
	self.layoutRequest = nil
	if request and request.timer then request.timer:Cancel() end
end

function Panel:CancelDataRefresh()
	local request = self.dataRequest
	self.dataRequest = nil
	if request and request.timer then request.timer:Cancel() end
end

function Panel:RequestDataRefresh(force)
	if not self.initialized or not visible(self.frame) then return end
	if self.dataRequest then self.dataRequest.force = self.dataRequest.force or force; return end
	if not (C_Timer and C_Timer.NewTimer) then self:Refresh(force); return end
	-- Merge a burst into the next frame, without adding a fixed wait to results
	-- or moving native whisper sends out of their original click handler.
	local request = { force = force }
	self.dataRequest = request
	request.timer = C_Timer.NewTimer(0, function()
		if self.dataRequest ~= request then return end
		self.dataRequest = nil
		if visible(self.frame) then self:Refresh(request.force) end
	end)
end

function Panel:ApplyTabVisibility()
	-- Page ownership cannot depend on geometry or on a successful data read.
	-- Both subtrees exist from Init, including while their first layout waits.
	local seek, square = self.tabID == GF.TAB_RAID_SEEK, self.tabID == GF.TAB_RAID_SQUARE
	local history = seek and GF.WorkspaceRouter and GF.WorkspaceRouter:IsSeekingHistory() or false
	if self.historyOnly ~= history then self.historyOnly, self.layoutDirty = history, true end
	self.left:SetShown(seek and not history); self.form:SetShown(seek and not history)
	self.activityCard:SetShown(seek and not history); self.contactCard:SetShown(seek or square)
	self.board.card:SetShown(square)
	self.contactCard.title.localeKey = history and "CHAT_HISTORY" or "CONTACTS"
end

function Panel:RequestLayoutRefresh()
	-- Size callbacks from our own anchor changes belong to this layout pass.
	if self.layingOut or self.adjustingActivityViewport then return end
	self.layoutDirty = true
	if not self.initialized or not visible(self.frame) or self.refreshing or self.layoutRequest then return end
	if not (C_Timer and C_Timer.NewTimer) then return end
	local request = {}
	self.layoutRequest = request
	request.timer = C_Timer.NewTimer(0, function()
		if self.layoutRequest ~= request then return end
		self.layoutRequest = nil
		if not visible(self.frame) then return end
		-- Re-read native geometry after Show/anchor callbacks have settled.
		-- A zero-sized host waits for its next size/show event, without polling.
		if self:Layout() then self:Refresh(true) end
	end)
end

function Panel:Layout()
	if not self.initialized or self.layingOut or self.refreshing then return false end
	if self.frame:GetWidth() <= S.inset * 2 + S.columnGap * 2 or self.frame:GetHeight() <= 0 then
		self.layoutDirty = true
		return false
	end
	self.layingOut = true
	local ok, ready = pcall(function()
		self:LayoutControls()
		if self.tabID == GF.TAB_RAID_SEEK and not self.historyOnly and (self.activityContent:GetWidth() <= 0 or self.activityContent:GetHeight() <= 0) then
			return false
		end
		self:RefreshActivityHeader()
		return true
	end)
	self.layingOut = nil
	self.layoutDirty = not (ok and ready)
	if not ok then error(ready, 0) end
	return ready
end

function Panel:LayoutControls()
	local seek = self.tabID == GF.TAB_RAID_SEEK
	local columnWidth = self.frame:GetWidth() - S.inset * 2 - S.columnGap * 2
	local formWidth = (self.frame:GetWidth() - S.formWidthReserve) * S.formRatio
	local cardWidth = (columnWidth - formWidth) / 2
	self.left:ClearAllPoints(); self.right:ClearAllPoints()
	if self.historyOnly then
		self.right:SetPoint("TOPLEFT", self.frame, "TOPLEFT", S.inset, -S.inset)
		self.right:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -S.inset, S.inset)
		self.contactCard:ClearAllPoints(); self.contactCard:SetAllPoints(self.right)
	elseif seek then
		self.left:SetPoint("TOPLEFT", S.inset, -S.inset)
		self.left:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", S.inset, S.inset)
		self.left:SetWidth(formWidth)
		self.right:SetPoint("TOPLEFT", self.left, "TOPRIGHT", S.columnGap, 0)
		self.right:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -S.inset, S.inset)
		self.contactCard:ClearAllPoints()
		self.contactCard:SetPoint("TOPRIGHT", self.right, "TOPRIGHT")
		self.contactCard:SetPoint("BOTTOMRIGHT", self.right, "BOTTOMRIGHT")
		self.contactCard:SetWidth(cardWidth)
		self.activityCard:ClearAllPoints()
		self.activityCard:SetPoint("TOPLEFT", self.right, "TOPLEFT")
		self.activityCard:SetPoint("BOTTOMLEFT", self.right, "BOTTOMLEFT")
		self.activityCard:SetWidth(cardWidth)
		self:SetActivityScrollProgress(self.activityScrollProgress or 0)
	else
		-- Span the form and activity columns so chat stays aligned across tabs.
		local boardWidth = formWidth + S.columnGap + cardWidth
		local card = self.board.card
		card:ClearAllPoints(); card:SetPoint("TOPLEFT", self.frame, "TOPLEFT", S.inset, -S.inset)
		card:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", S.inset, S.inset); card:SetWidth(boardWidth)
		self.right:SetPoint("TOPLEFT", card, "TOPRIGHT", S.columnGap, 0)
		self.right:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -S.inset, S.inset)
		self.contactCard:ClearAllPoints(); self.contactCard:SetAllPoints(self.right)
		self.board:Layout()
	end
	if not self.historyOnly then self:LayoutForm() end
end

local function applySpecChoiceVisual(button)
	button.icon:SetDesaturation(1 - button.colorAmount)
	button.normalChrome:SetAlpha(1 - button.chromeAmount)
	button.highlightChrome:SetAlpha(button.chromeAmount)
end

local function stepSpecChoiceTransition(button, elapsed)
	local transition = button.transition
	if not transition then button:SetScript("OnUpdate", nil); return end
	transition.elapsed = transition.elapsed + elapsed
	local progress = math.min(1, transition.elapsed / S.roleFadeDuration)
	local eased = progress * progress * (3 - 2 * progress)
	button.colorAmount = transition.colorFrom + (button.colorTarget - transition.colorFrom) * eased
	button.chromeAmount = transition.chromeFrom + (button.chromeTarget - transition.chromeFrom) * eased
	applySpecChoiceVisual(button)
	if progress == 1 then button.transition = nil; button:SetScript("OnUpdate", nil) end
end

local function refreshSpecChoiceVisual(button, immediate)
	local enabled = button:IsEnabled()
	local colorTarget = enabled and button.selected and 1 or 0
	local chromeTarget = enabled and (button.selected or button.hovered) and 1 or 0
	if immediate or button.colorAmount == nil or not button:IsShown() then
		button.colorTarget, button.chromeTarget = colorTarget, chromeTarget
		button.colorAmount, button.chromeAmount = colorTarget, chromeTarget
		button.transition = nil; button:SetScript("OnUpdate", nil)
		applySpecChoiceVisual(button)
	elseif button.colorTarget ~= colorTarget or button.chromeTarget ~= chromeTarget then
		button.colorTarget, button.chromeTarget = colorTarget, chromeTarget
		button.transition = { colorFrom = button.colorAmount, chromeFrom = button.chromeAmount, elapsed = 0 }
		button:SetScript("OnUpdate", stepSpecChoiceTransition)
	end
end

local function hideSpecChoice(button)
	button.hovered = nil
	refreshSpecChoiceVisual(button, true)
end

function Panel:LayoutNoteHeight()
	if not self.noteLayoutY then return end
	local feedbackHeight = self.feedbackHeight or 0
	local exit = self.feedbackExit
	if exit then
		local p = math.max(0, math.min(1,
			(exit.elapsed - S.form.feedbackFadeDuration) / S.form.feedbackExpandDuration))
		feedbackHeight = feedbackHeight * (1 - p * p * (3 - 2 * p))
	end
	local noteHeight = math.max(S.form.noteMinHeight,
		self.formContent:GetHeight() - self.noteLayoutY - self.publish:GetHeight() - S.blockGap - feedbackHeight)
	if math.abs(self.noteShell:GetHeight() - noteHeight) > 0.001 then self.noteShell:SetHeight(noteHeight) end
end

function Panel:LayoutForm()
	local fieldWidth = math.max(1, self.formContent:GetWidth())
	local y = 0
	local function placeTitle(value)
		value:ClearAllPoints(); value:SetPoint("TOPLEFT", 0, -y); value:SetWidth(fieldWidth)
		y = y + value:GetStringHeight() + S.titleGap
	end
	local function placeControl(value)
		value:ClearAllPoints(); value:SetPoint("TOPLEFT", 0, -y); value:SetWidth(fieldWidth)
		y = y + value:GetHeight() + S.blockGap
	end
	placeTitle(self.modeTitle)
	local modeInset = GF.FILTER_MULTILINE_INPUT_CONTENT_INSET
	self.mode:SetWidth(math.max(1, fieldWidth - S.modeTextLeftInset - modeInset)); self.mode:SetHeight(self.mode:GetStringHeight())
	self.modeShell:SetHeight(self.mode:GetHeight() + modeInset * 2)
	placeControl(self.modeShell)
	placeTitle(self.raidTitle); placeControl(self.activities)
	placeTitle(self.rolesTitle)
	local party = service().draft.mode == "party"
	self.partyRoles:SetShown(party); self.soloSpecContainer:SetShown(not party)
	local count = self.soloSpecCount or 0
	local columns = math.max(1, count)
	local roleWidth = (fieldWidth - S.roleGap * (columns - 1)) / columns
	self.soloSpecContainer:SetHeight(S.roleHeight)
	for index, button in ipairs(self.roles) do
		button.tile:SetShown(index <= count)
		button.tile:ClearAllPoints()
		button.tile:SetPoint("TOPLEFT", (index - 1) * (roleWidth + S.roleGap), 0)
		button.tile:SetSize(roleWidth, S.roleHeight)
		if party or index > count then hideSpecChoice(button) end
	end
	placeControl(party and self.partyRoles or self.soloSpecContainer)
	placeTitle(self.noteTitle)
	-- Background paints must not detach or resize the live multiline editor.
	if self.noteLayoutY ~= y then
		self.noteLayoutY = y
		self.noteShell:ClearAllPoints(); self.noteShell:SetPoint("TOPLEFT", 0, -y)
	end
	if math.abs(self.noteShell:GetWidth() - fieldWidth) > 0.001 then self.noteShell:SetWidth(fieldWidth) end
	local actionCount = self.feedbackFailed and 3 or 2
	for _, control in ipairs({ self.publish, self.stop, self.retry }) do
		control:ClearAllPoints(); control:SetWidth((fieldWidth - S.actionGap * (actionCount - 1)) / actionCount)
	end
	self.publish:SetPoint("BOTTOMLEFT")
	self.stop:SetPoint("LEFT", self.publish, "RIGHT", S.actionGap, 0)
	self.retry:SetPoint("LEFT", self.stop, "RIGHT", S.actionGap, 0)
	self.messageText:SetWidth(fieldWidth)
	self.feedbackHeight = (self.feedbackMessage or self.feedbackExit) and self.messageText:GetStringHeight() + S.actionGap or 0
	self.messageText:SetHeight(math.max(1, self.feedbackHeight - S.actionGap))
	self:LayoutNoteHeight()
end

function Panel:RefreshSpecChoices()
	local s = service()
	local member = s.adapter.Member and s.adapter.Member("player")
	local specs = member and s:GetMemberSpecs(member) or {}
	local selected = member and s:GetSelectedSpecIDs(member) or {}
	self.soloSpecCount = #specs
	for index, spec in ipairs(specs) do
		local button = self.roles[index]
		if not button then
			local tile = CreateFrame("Frame", nil, self.soloSpecContainer)
			button = CreateFrame("Button", nil, tile)
			button.tile = tile; button:SetAllPoints(tile)
			local frameSize = S.roleIconSize + S.roleIconFrameInset * 2
			local function createChrome(state, level)
				local chrome = CreateFrame("Frame", nil, button)
				chrome:SetPoint("CENTER"); chrome:SetSize(frameSize, frameSize)
				chrome:SetFrameLevel(level); chrome:EnableMouse(false)
				UI.ApplyFilterMultilineInputChrome(chrome, state)
				return chrome
			end
			button.normalChrome = createChrome("normal", button:GetFrameLevel() + 1)
			UI.SetControlCardChromeEnabledVisual(button.normalChrome, false, { disabledTint = 1 })
			button.highlightChrome = createChrome("hover", button:GetFrameLevel() + 2)
			-- Keep the square image above both atlas states, including their center slices.
			button.iconHost = CreateFrame("Frame", nil, button)
			button.iconHost:SetAllPoints(button.normalChrome)
			button.iconHost:SetFrameLevel(button:GetFrameLevel() + 3); button.iconHost:EnableMouse(false)
			button.icon = button.iconHost:CreateTexture(nil, "ARTWORK")
			button.icon:SetPoint("CENTER")
			button.icon:SetSize(S.roleIconSize, S.roleIconSize); button.icon:SetAlpha(1)
			local inset = S.roleIconTexCoordInset
			button.icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
			-- Match the input frame's cut corners without reducing the image fill.
			button.iconMask = button.iconHost:CreateMaskTexture()
			button.iconMask:SetTexture(S.roleIconMaskTexture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			button.iconMask:SetAllPoints(button.icon)
			button.icon:AddMaskTexture(button.iconMask)
			button:SetScript("OnEnter", function(self)
				self.hovered = true; refreshSpecChoiceVisual(self)
				UI.ShowSimpleTooltip(self, self.specName, "ANCHOR_RIGHT")
			end)
			button:SetScript("OnLeave", function(self)
				self.hovered = nil; refreshSpecChoiceVisual(self); GameTooltip_Hide()
			end)
			button:SetScript("OnHide", hideSpecChoice)
			button:SetScript("OnShow", function(self) refreshSpecChoiceVisual(self, true) end)
			button:SetScript("OnDisable", function(self) refreshSpecChoiceVisual(self, true) end)
			button:SetScript("OnEnable", function(self) refreshSpecChoiceVisual(self) end)
			button:SetScript("OnClick", function(self)
				if self:IsEnabled() and service():ToggleMemberSpec(self.memberName, self.classID, self.specID, "solo") then
					UI.PlayUISound("check")
					Panel:Refresh(true)
				end
			end)
			self.roles[index] = button
		end
		local changed = button.memberName ~= member.name or button.classID ~= member.classID
			or button.specID ~= spec.id or button.iconTexture ~= spec.icon
		button.memberName, button.classID, button.specID, button.specName = member.name, member.classID, spec.id, spec.name
		button.selected = false
		for _, id in ipairs(selected) do if id == spec.id then button.selected = true; break end end
		if changed then
			button.iconTexture, button.hovered = spec.icon, nil
			button.icon:SetTexture(spec.icon)
		end
		button:SetEnabled(s:CanEditMemberSpecs(member.name, member.classID, "solo"))
		refreshSpecChoiceVisual(button, changed)
	end
end

function Panel:RefreshFormPreferences()
	local preferences, readOnly = service():GetFormPreferences()
	local editable = not readOnly
	if self.noteEditable ~= editable then
		self.noteEditable = editable
		self.note:SetEnabled(editable)
		self.note:EnableMouse(editable)
		self.noteShell:EnableMouse(editable)
		self.noteShell.scroll:EnableMouse(editable)
		self.noteShell.scroll:EnableMouseWheel(editable)
		if readOnly then
			self.note:ClearFocus()
			self.noteShell._gfCopyInputHovered = nil
			self.noteShell:RefreshVisualState()
		end
	end
	-- While editing, the native input owns its text, selection and caret (also
	-- during IME composition). Only real read-only transitions may replace it.
	if not (editable and self.note:HasFocus()) and self.note:GetText() ~= preferences.note then
		self.loading = true
		self.note:SetText(preferences.note)
		self.note:SetCursorPosition(0)
		self.noteShell.scroll:SetVerticalScroll(0)
		self.loading = nil
	end
	return preferences, readOnly
end

function Panel:RefreshPublishTooltip(reason)
	if self.publishHovered and visible(self.publish) and reason == "faction" then
		UI.ShowSimpleTooltipAbove(self.publish, label("PUBLISH_CROSS_FACTION_TOOLTIP"))
	elseif GameTooltip and GameTooltip:IsOwned(self.publish) then
		GameTooltip:Hide()
	end
end

function Panel:InitForm(parent)
	local form = section(parent, "FORM_TITLE"); form:SetAllPoints(); self.form = form
	form = cardContent(form); self.formContent = form
	self.raidTitle = caption(form, "STEP_RAID")
	self.activities = dropdown(form, nil, function(root, owner)
		if showMissingLeaderPublication(root, owner) then return end
		local activities = service():GetActivities()
		if #activities == 0 then
			showEmptyMenu(root, owner, "RAID_MENU_UNAVAILABLE")
			return
		end
		if service():CanEditForm() then
			root:CreateButton(label("SELECT_ALL_TARGETS"), function()
				if not service():CanEditForm() then return end
				local ids, seen = {}, {}
				for _, entry in ipairs(service():GetActivities()) do
					if #ids < 24 and not seen[entry.id] then
						ids[#ids + 1], seen[entry.id] = entry.id, true
					end
				end
				service().draft.activityIDs = ids; service():SaveDraft(); Panel:Refresh(true)
			end)
		end
		for _, entry in ipairs(activities) do
			local id = entry.id
			local item = root:CreateCheckbox(entry.name, function()
				for _, chosen in ipairs(service():GetFormPreferences().activityIDs) do if chosen == id then return true end end
				return false
			end, function()
				if not service():CanEditForm() then return end
				local ids, removed = service().draft.activityIDs, false
				for index, chosen in ipairs(ids) do if chosen == id then table.remove(ids, index); removed = true; break end end
				if not removed and #ids < 24 then ids[#ids + 1] = id end
				service():SaveDraft(); Panel:Refresh(true)
			end)
			item:SetEnabled(function() return service():CanEditForm() end)
		end
		if service():CanEditForm() then
			root:CreateButton(label("CLEAR_TARGETS"), function()
				if not service():CanEditForm() then return end
				service().draft.activityIDs = {}; service():SaveDraft(); Panel:Refresh(true)
			end)
		end
	end)
	self.modeTitle = caption(form, "MODE")
	self.modeShell = CreateFrame("Frame", nil, form)
	local modeBackground = S.modeBackground
	self.modeShell.Background = self.modeShell:CreateTexture(nil, "BACKGROUND")
	self.modeShell.Background:SetPoint("TOPLEFT", self.modeShell, "TOPLEFT", modeBackground.left, modeBackground.top)
	self.modeShell.Background:SetPoint("BOTTOMRIGHT", self.modeShell, "BOTTOMRIGHT", modeBackground.right, modeBackground.bottom)
	UI.TrySetAtlas(self.modeShell.Background, modeBackground.atlas, true)
	self.mode = text(self.modeShell, "GameFontHighlight")
	self.mode:SetPoint("TOPLEFT", S.modeTextLeftInset, -GF.FILTER_MULTILINE_INPUT_CONTENT_INSET)
	self.rolesTitle = caption(form, "INTENDED_SPECS")
	self.roles = {}
	self.soloSpecContainer = CreateFrame("Frame", nil, form)
	self.partyRoles = dropdown(form, nil, function(root, owner)
		if showMissingLeaderPublication(root, owner) then return end
		root:SetScrollMode(S.partySpecMenuHeight)
		for _, member in ipairs(service():GetPartySpecChoices()) do
			local name, classID = member.name, member.classID
			root:CreateTitle(P.Display(name))
			for _, spec in ipairs(service():GetMemberSpecs(member)) do
				local specID = spec.id
				local item = root:CreateCheckbox(spec.name, function()
					for _, current in ipairs(service():GetPartySpecChoices()) do
						if current.name == name and current.classID == classID then
							for _, id in ipairs(current.specIDs) do if id == specID then return true end end
						end
					end
					return false
				end, function()
					if service():ToggleMemberSpec(name, classID, specID, "party") then Panel:Refresh(true) end
				end)
				item:SetEnabled(function() return service():CanEditMemberSpecs(name, classID, "party") end)
			end
		end
	end)
	self.noteTitle = caption(form, "NOTE")
	self.noteShell, self.note = UI.CreateSelectableCopyInput(form, S.fieldWidth,
		{ height = S.form.noteHeight, fontSize = S.noteTextSize, multiline = true, selectAllOnMouseDown = false })
	self.note:SetJustifyH("LEFT"); self.note:SetMultiLine(true); self.note:SetMaxBytes(P.MAX_NOTE_BYTES)
	self.note:SetScript("OnTextChanged", function(edit)
		if not Panel.loading then
			if not service():CanEditForm() then Panel:RefreshFormPreferences(); return end
			service().draft.note = edit:GetText(); service():SaveDraft(); Panel:Refresh(true)
		end
	end)
	local focusNote = self.noteShell:GetScript("OnMouseDown")
	self.noteShell:SetScript("OnMouseDown", function(shell, ...)
		if service():CanEditForm() then focusNote(shell, ...) end
	end)
	self.note:HookScript("OnEditFocusGained", function(edit)
		if not service():CanEditForm() then edit:ClearFocus() end
	end)
	self.note:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
	self.note:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
	self.notePlaceholder = text(self.noteShell.scroll, "GameFontDisableSmall")
	self.notePlaceholder._gfFontSizeOverride = self.note._gfFontSizeOverride
	self.notePlaceholder._gfFontFlagsOverride = self.note._gfFontFlagsOverride
	if GF.Font and GF.Font.Track then
		GF.Font.Track(self.notePlaceholder, self.note._gfFontTemplate)
	end
	self.notePlaceholder:SetAllPoints(self.noteShell.scroll)
	self.publish = button(form, "PUBLISH", function()
		Panel:RequestPublish(service().current and "UPDATE" or "PUBLISH")
	end)
	self.publish:SetMotionScriptsWhileDisabled(true)
	self.publish:HookScript("OnEnter", function()
		self.publishHovered = true
		local _, reason = service():BuildRecord()
		self:RefreshPublishTooltip(reason)
	end)
	local function leavePublish()
		self.publishHovered = nil
		self:RefreshPublishTooltip()
	end
	self.publish:HookScript("OnLeave", leavePublish)
	self.publish:HookScript("OnHide", leavePublish)
	self.stop = button(form, "STOP", function()
		local s = service()
		if not s.current and not s.pendingRequest and not s.pendingAt then return end
		local ok, reason = s:Stop()
		if ok then UI.PlayUISound("cancelQueue") end
		Panel:Result(ok, reason, "STOPPED")
	end)
	self.retry = button(form, "RETRY", function() Panel.retrying = true; Panel:EnterFeature() end)
	self.retry:Hide()
	self.messageText = text(form)
	self.messageText:SetPoint("BOTTOMLEFT", self.publish, "TOPLEFT", 0, S.actionGap)
	self.messageText:Hide()
	self.form:HookScript("OnHide", function()
		Panel.feedbackPreparing = nil
		Panel:StopFeedbackExit()
	end)
end

function Panel:StopFeedbackExit()
	if not self.feedbackExit then return end
	self.feedbackExit = nil
	self.formContent:SetScript("OnUpdate", nil)
	self.messageText:SetAlpha(1)
	self.messageText:SetText(self.feedbackMessage or "")
	self.messageText:SetShown(self.feedbackMessage ~= nil and visible(self.form))
	self.feedbackHeight = self.feedbackMessage and self.messageText:GetStringHeight() + S.actionGap or 0
	self:LayoutNoteHeight()
end

function Panel:TickFeedbackExit(elapsed)
	local exit = self.feedbackExit
	if not exit then return end
	if not visible(self.form) then self:StopFeedbackExit(); return end
	exit.elapsed = exit.elapsed + elapsed
	local p = math.min(1, exit.elapsed / S.form.feedbackFadeDuration)
	self.messageText:SetAlpha(1 - p * p * (3 - 2 * p))
	-- Keep the full gap until the glyphs are gone, so the editor never sweeps
	-- across readable text. Only its bottom edge moves during the second stage.
	if p == 1 then self.messageText:Hide() end
	self:LayoutNoteHeight()
	if exit.elapsed >= S.form.feedbackFadeDuration + S.form.feedbackExpandDuration then
		self:StopFeedbackExit()
	end
end

function Panel:RefreshFeedback(message, failed, seek, preparing)
	local wasPreparing = self.feedbackPreparing
	self.feedbackMessage, self.feedbackFailed = message, failed
	self.feedbackPreparing = preparing
	if not message and seek and visible(self.form)
		and (self.feedbackExit or wasPreparing and self.messageText:IsShown()) then
		if not self.feedbackExit then
			self.feedbackExit = { elapsed = 0 }
			self.formContent:SetScript("OnUpdate", function(_, elapsed) Panel:TickFeedbackExit(elapsed) end)
		end
	else
		self:StopFeedbackExit()
		self.messageText:SetText(message or ""); self.messageText:SetAlpha(1)
		self.messageText:SetShown(seek and message ~= nil)
	end
	self.retry:SetShown(seek and failed)
	if seek then self:LayoutForm() end
end

function Panel:InitActivityContent()
	self.activityBlocks, self.targetTiles, self.memberRows, self.progressRows, self.awaitingRows = {}, {}, {}, {}, {}
	self.activityAppearances, self.activityAppearanceRows = {}, {}
	self.activityOpacity = 1
	self.awaitingDisplayRows = {}
	for _, key in ipairs({ "AWAITING", "TARGETS", "MEMBERS", "PROGRESS", "NOTE" }) do
		local block = CreateFrame("Frame", nil, self.activityContent)
		block:SetUsingParentLevel(true)
		block.title = subheading(block)
		block.title:SetPoint("TOPLEFT"); block.title:SetPoint("TOPRIGHT")
		block.title:SetTextColor(unpack(S.accentColor))
		if key == "NOTE" then block.bodyFrame = CreateFrame("Frame", nil, block) end
		block.body = text(block.bodyFrame or block)
		if key == "NOTE" then
			block.body._gfFontSizeOverride = S.noteTextSize
			if GF.Font and GF.Font.ApplyToFontString then GF.Font.ApplyToFontString(block.body, "GameFontHighlightSmall") end
		end
		block.body:SetSpacing(S.lineSpacing); block.body:SetTextColor(unpack(S.textColor))
		self.activityBlocks[key] = block
	end
	self.activityText = self.activityBlocks.NOTE.body
end

local function activityEase(progress)
	progress = math.min(1, math.max(0, progress))
	return progress * progress * (3 - 2 * progress)
end

function Panel:PaintActivityAppearance(item)
	local alpha = activityEase(item.state.elapsed / S.activityRowFadeDuration)
	item.frame:SetAlpha(alpha)
	if item.title then item.title:SetAlpha(alpha) end
	-- Member art lives in a separate clipped subtree behind the text.
	if item.frame.backgroundHost then item.frame.backgroundHost:SetAlpha(alpha) end
	if item.frame.member or item.frame.tooltipEntries then
		local interactive = alpha == 1 and self.activityOpacity == 1 and not self.activityRetiring
		item.frame:EnableMouse(interactive)
		if not interactive and GameTooltip and GameTooltip:IsOwned(item.frame) then GameTooltip:Hide() end
	end
end

function Panel:AddActivityAppearance(frame, key, title)
	local state = self.activityAppearances[key]
	if not state then
		state = { elapsed = visible(self.activityContent) and -self.activityNextDelay or S.activityRowFadeDuration }
		self.activityAppearances[key] = state
		self.activityNextDelay = self.activityNextDelay + S.activityRowStagger
	end
	self.activityAppearanceSeen[key] = true
	local item = { frame = frame, title = title, state = state }
	self.activityAppearanceRows[#self.activityAppearanceRows + 1] = item
	if state.elapsed < S.activityRowFadeDuration then self.activityRowsAnimating = true end
end

function Panel:PaintActivityTransition()
	for _, key in ipairs({ "TARGETS", "MEMBERS", "PROGRESS", "NOTE" }) do
		self.activityBlocks[key]:SetAlpha(self.activityOpacity)
	end
	self.activityBackgroundViewport:SetAlpha(self.activityOpacity)
	self.activityEmptyGroup:SetAlpha(self.activityEmptyAlpha or 0)
	self.activityEmptyGroup:SetShown((self.activityEmptyAlpha or 0) > 0 or self.activityEmptyTarget == 1)
	self.activityContent:EnableMouseWheel(not self.activityRetiring)
	for _, item in ipairs(self.activityAppearanceRows) do self:PaintActivityAppearance(item) end
end

function Panel:SetActivityEmptyTarget(empty)
	local loading = empty and self.activityMemberView and self.activityViewState == "loading"
	local target = empty and 1 or 0
	if self.activityEmptyTarget ~= target then
		local from = self.activityEmptyAlpha
		self.activityEmptyTarget = target
		if from == nil or not visible(self.activityContent) then from = target end
		self.activityEmptyAlpha = from
		self.activityEmptyFade = from ~= target and { from = from, target = target, elapsed = 0 } or nil
	end
	if empty then
		local titleKey, hintKey = "NO_ACTIVITY",
			service().recoveryNotice and "ERROR_" .. service().recoveryNotice:upper() or "NO_ACTIVITY_HINT"
		if self.activityMemberView then
			if self.activityViewState == "loading" then
				titleKey, hintKey = self.retrying and "PARTY_ACTIVITY_RETRYING" or "PARTY_ACTIVITY_LOADING", nil
			elseif self.activityViewState == "unavailable" then
				titleKey, hintKey = "PARTY_ACTIVITY_UNAVAILABLE", "PARTY_ACTIVITY_RETRY_HINT"
			else titleKey, hintKey = "NO_PARTY_ACTIVITY", "NO_PARTY_ACTIVITY_HINT" end
		end
		refreshCenteredPrompt(self.activityEmptyGroup, self.activityEmptyTitle, self.activityEmpty,
			label(titleKey), hintKey == "PARTY_ACTIVITY_RETRY_HINT" and partyFailureHint() or hintKey and label(hintKey) or "")
		self.activityEmpty:SetShown(not loading)
		if loading then
			if not self.activityLoadingAnimation then
				self.activityLoadingAnimation = UI.CreateTeamUpLoadingAnimation(self.activityEmptyGroup)
				self.activityLoadingAnimation:SetPoint("TOP", self.activityEmptyTitle, "BOTTOM", 0, -GF.BROWSE_LOADING_TEXT_GAP)
			end
			self.activityEmptyGroup:SetHeight(self.activityEmptyTitle:GetHeight()
				+ GF.BROWSE_LOADING_TEXT_GAP + GF.BROWSE_LOADING_ICON_HEIGHT)
		end
	end
	if self.activityLoadingAnimation then self.activityLoadingAnimation:SetShown(loading == true) end
end

function Panel:TickActivityAnimations(elapsed)
	if not (self.activityRowsAnimating or self.activityExitFade or self.activityEmptyFade) then return end
	local changed, finished = false, false
	self.activityRowsAnimating = false
	for _, item in ipairs(self.activityAppearanceRows) do
		if item.state.elapsed < S.activityRowFadeDuration and not self.activityRetiring then
			item.state.elapsed = math.min(S.activityRowFadeDuration, item.state.elapsed + math.max(0, elapsed))
			changed = true
		end
		if item.state.elapsed < S.activityRowFadeDuration then self.activityRowsAnimating = true end
	end
	for _, field in ipairs({ "activityExitFade", "activityEmptyFade" }) do
		local fade = self[field]
		if fade then
			fade.elapsed = fade.elapsed + math.max(0, elapsed)
			local progress = math.min(1, fade.elapsed / S.activityPresenceDuration)
			local value = fade.from + (fade.target - fade.from) * activityEase(progress)
			if field == "activityExitFade" then self.activityOpacity = value else self.activityEmptyAlpha = value end
			if progress == 1 then
				self[field] = nil
				finished = finished or (field == "activityExitFade" and self.activityRetiring)
			end
			changed = true
		end
	end
	if finished then
		-- Retire the visual snapshot only after its last frame has faded out.
		-- Reuse cached application data instead of querying native state on a tick.
		local snapshot = self.activityLayoutSnapshot
		self.activityRetiring, self.activityDisplayRecord = nil, nil
		self.activityOpacity = 1
		-- A publication-only scrollbar has already faded with the snapshot.
		-- Settle its gutter now so it cannot flash back before a second fade.
		if #self.awaitingDisplayRows == 0 then
			self.activityScrollFade, self.activityScrollTarget = nil, nil
			self:SetActivityScrollProgress(0)
		end
		self:LayoutActivitySnapshot(nil, snapshot.waiting, snapshot.entries)
	end
	if changed then self:PaintActivityTransition(); self:SyncActivityScrollBar() end
end

function Panel:StopActivityAnimations()
	if self.activityLoadingAnimation then self.activityLoadingAnimation:Hide() end
	self.activityRowsAnimating = false
	self.activityExitFade, self.activityEmptyFade = nil, nil
	self.activityRetiring, self.activityDisplayRecord = nil, nil
	self.activityOpacity, self.activityEmptyAlpha = 1, self.activityEmptyTarget or 0
	for _, state in pairs(self.activityAppearances) do state.elapsed = S.activityRowFadeDuration end
	self:PaintActivityTransition()
end

function Panel:StopActivityBadge()
	local badge = self.activityBadge
	if not badge then return end
	badge:SetScript("OnUpdate", nil)
	badge.targetVisible, badge.mode, badge.phase = false, nil, nil
	UI.StopPendingSpinner(badge.spinner)
	if badge.eye then badge.eye:StopAnimating(); badge.eye.GlowBackLoop:Hide(); badge.eye:Hide() end
	badge:SetAlpha(0)
	badge:Hide()
end

function Panel:InitActivityBadge()
	local card = self.activityCard
	local badge = CreateFrame("Frame", nil, card)
	badge:SetSize(S.activityBadgeSize, S.activityBadgeSize)
	badge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -S.inset, S.activityBadgeTop)
	badge:SetFrameLevel(card.header:GetFrameLevel() + 1)
	badge:EnableMouse(false)
	badge.flag = badge:CreateTexture(nil, "BACKGROUND")
	badge.flag:SetAllPoints(badge)
	UI.TrySetAtlas(badge.flag, GF.HOUSING_TASK_FLAG_ATLAS, false)
	badge.eyeAnchor = CreateFrame("Frame", nil, badge)
	badge.eyeAnchor:SetSize(S.activityBadgeEyeSize, S.activityBadgeEyeSize)
	badge.eyeAnchor:SetPoint("CENTER", badge, "CENTER", S.activityBadgeMarkX, S.activityBadgeMarkY)
	badge.spinner = UI.CreatePendingSpinner(badge, S.activityBadgeSpinnerSize)
	-- Align the visible ring with the cloth, excluding the swallowtail tips.
	badge.spinner:SetPoint("CENTER", badge, "CENTER", S.activityBadgeSpinnerX, S.activityBadgeSpinnerY)
	self.activityBadge = badge
	badge:HookScript("OnHide", function() Panel:StopActivityBadge() end)
	self:StopActivityBadge()
end

function Panel:RefreshActivityHeader()
	local header, style = self.activityCard.header, GF.CARD_HEADER_STYLE
	if header:GetWidth() <= style.fitInsets then return end
	local badgeWidth = S.activityBadgeSize + S.gap
	local available = math.max(1, header:GetWidth() - style.fitInsets - badgeWidth)
	local statusWidth = math.min(S.activityStatusMaxWidth, available * 0.5)
	self.activityStatus:SetWidth(statusWidth)
	self.activityStatus:ClearAllPoints()
	self.activityStatus:SetPoint("RIGHT", header, "RIGHT", -style.titleRight - badgeWidth, 0)
	header.titleReservedWidth = badgeWidth + statusWidth + S.gap
	header.title:ClearAllPoints()
	header.title:SetPoint("LEFT", header.accent, "RIGHT", style.titleGap, 0)
	header.title:SetPoint("RIGHT", header, "RIGHT", -style.titleRight - header.titleReservedWidth, 0)
	header.title:SetJustifyH("LEFT"); header.title:SetJustifyV("MIDDLE")
	header:Show(); header.accent:Show(); header.title:Show()
	header:RefreshTitleFit()
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(self.activityStatus, statusWidth, S.activityStatusMinTextSize)
	end
end

function Panel:EnsureActivityEye()
	local badge = self.activityBadge
	if badge.eye then return true end
	if not UI.TryLoadQueueStatusFrameUI() then return false end
	local ok, eye = pcall(CreateFrame, "Frame", nil, badge.eyeAnchor, "EyeTemplate")
	if not ok or not eye then return false end
	-- The template's flipbook textures have fixed native dimensions. Scale the
	-- complete template, not just its frame, to keep every animation in the flag.
	eye:SetSize(GF.QUEUE_STATUS_EYE_NATIVE_SIZE, GF.QUEUE_STATUS_EYE_NATIVE_SIZE)
	eye:SetScale(S.activityBadgeEyeSize / GF.QUEUE_STATUS_EYE_NATIVE_SIZE)
	eye:SetPoint("CENTER", badge.eyeAnchor, "CENTER")
	eye:SetFrameStrata(badge:GetFrameStrata())
	eye:SetFrameLevel(badge:GetFrameLevel() + 1)
	eye:EnableMouse(false)
	for _, child in ipairs({ eye:GetChildren() }) do
		-- EyeTemplate hard-codes MEDIUM; this instance belongs to our card.
		child:SetFrameStrata(badge:GetFrameStrata())
		child:SetFrameLevel(eye:GetFrameLevel() + 1)
		child:EnableMouse(false)
	end
	eye.EyeInitial.EyeInitialAnim:HookScript("OnFinished", function() Panel:FinishActivityEye("INITIAL") end)
	eye.EyePokeInitial.EyePokeInitialAnim:HookScript("OnFinished", function() Panel:FinishActivityEye("POKE_INITIAL") end)
	eye.EyePokeEnd.EyePokeEndAnim:HookScript("OnFinished", function() Panel:FinishActivityEye("POKE_END") end)
	eye.EyeFoundInitial.EyeFoundInitialAnim:SetLooping("REPEAT")
	badge.eye = eye
	return true
end

function Panel:PlayActivityEye(phase)
	local badge = self.activityBadge
	local eye = badge and badge.eye
	if not eye then return end
	badge.phase = phase
	-- Native FoundLoop registers the glow animation against EyeFoundLoop,
	-- so explicitly own the separate glow frame's visibility as well.
	eye.GlowBackLoop:Hide()
	eye:Show()
	if phase == "INITIAL" then eye:StartInitialAnimation()
	elseif phase == "POKE_INITIAL" then eye:StartPokeAnimationInitial()
	elseif phase == "POKE_LOOP" then eye:StartPokeAnimationLoop()
	elseif phase == "POKE_END" then eye:StartPokeAnimationEnd()
	elseif phase == "WHISPER" then eye:StartFoundAnimationLoop(); eye.GlowBackLoop:Show()
	elseif phase == "INVITE" then eye:StartFoundAnimationInit()
	else eye:StartSearchingAnimation() end
end

function Panel:FinishActivityEye(phase)
	local badge = self.activityBadge
	if not badge or not badge.targetVisible or not badge:IsShown() or badge.phase ~= phase then return end
	if phase == "POKE_INITIAL" then self:PlayActivityEye(badge.mode == "UPDATE" and "POKE_LOOP" or "POKE_END")
	else self:PlayActivityEye("SEARCHING") end
end

function Panel:FadeActivityBadge(visible)
	local badge = self.activityBadge
	if badge.targetVisible == visible then return end
	badge.targetVisible = visible
	local from, target, elapsed = badge:GetAlpha(), visible and 1 or 0, 0
	badge:Show()
	badge:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		local progress = math.min(1, elapsed / S.activityBadgeFadeDuration)
		local eased = progress * progress * (3 - 2 * progress)
		badge:SetAlpha(from + (target - from) * eased)
		if progress >= 1 then
			badge:SetScript("OnUpdate", nil)
			if not visible then Panel:StopActivityBadge() end
		end
	end)
end

function Panel:RefreshActivityBadge(published, updating)
	local badge = self.activityBadge
	if not badge then return end
	if not visible(self.frame) or self.tabID ~= GF.TAB_RAID_SEEK then self:StopActivityBadge(); return end
	local s = service()
	local loading = s:IsPublicationQueued() or (not published and (s.pendingRequest ~= nil or s.pendingAt ~= nil))
	local show = published == true or loading
	if show and not badge.targetVisible then badge.mode = nil end
	self:FadeActivityBadge(show)
	if not show then UI.StopPendingSpinner(badge.spinner); return end
	if loading then
		if badge.mode ~= "LOADING" then
			badge.mode, badge.phase = "LOADING", nil
			if badge.eye then badge.eye:StopAnimating(); badge.eye.GlowBackLoop:Hide(); badge.eye:Hide() end
		end
		UI.StartPendingSpinner(badge.spinner, S.activityBadgeSpinnerSize)
		return
	end
	UI.StopPendingSpinner(badge.spinner)
	if not self:EnsureActivityEye() then return end
	local mode = self.activityAttention or (updating and "UPDATE" or "LIVE")
	if badge.mode == mode then return end
	local previous = badge.mode
	badge.mode = mode
	if mode == "UPDATE" then self:PlayActivityEye("POKE_INITIAL")
	elseif mode == "WHISPER" or mode == "INVITE" then self:PlayActivityEye(mode)
	elseif previous == "UPDATE" and service().status == "published" and not service().lastError then
		-- Only confirmed success ends the waiting loop. Preserve the initial
		-- segment if a fast echo arrives before it finishes.
		if badge.phase ~= "POKE_INITIAL" then self:PlayActivityEye("POKE_END") end
	elseif previous == "LOADING" then self:PlayActivityEye("INITIAL")
	elseif previous then self:PlayActivityEye("SEARCHING")
	else self:PlayActivityEye("INITIAL") end
end

function Panel:OnActivityAttention(event)
	if not service():GetMyActivity() then return end
	if event == "PARTY_INVITE_REQUEST" then self.activityAttention = "INVITE"
	elseif (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER") and self.activityAttention ~= "INVITE" then
		self.activityAttention = "WHISPER"
	else return end
	-- Only the event kind is used; message text and sender data stay in chat.
	self:Refresh(true)
end

local function targetDifficultyText(group)
	local names = {}
	for _, difficulty in ipairs(group.difficulties) do
		names[#names + 1] = P.Display(difficulty.name or label("UNKNOWN"))
	end
	local locale = GF.Locale and GF.Locale:GetCurrentLocaleKey()
	return table.concat(names, (locale == "zhCN" or locale == "zhTW") and "、" or ", ")
end

function Panel:RenderTargetRow(index, group, parent, width, y)
	local row = self.targetTiles[index]
	if not row then
		row = CreateFrame("Frame", nil, parent)
		row:SetClipsChildren(true)
		row.background = fill(row, S.tileColor)
		row.image = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		row.image:SetPoint("LEFT")
		row.image:SetAlpha(S.targetImageAlpha)
		row.mask = row:CreateMaskTexture()
		if UI.TrySetAtlas(row.mask, S.targetMaskAtlas, true) then
			row.mask:SetPoint("LEFT", row, "LEFT", S.targetMaskOffsetX, 0)
			row.image:AddMaskTexture(row.mask)
		end
		row.topDivider, row.divider = row:CreateTexture(nil, "ARTWORK"), row:CreateTexture(nil, "ARTWORK")
		for _, divider in ipairs({ row.topDivider, row.divider }) do
			UI.TrySetAtlas(divider, S.targetDividerAtlas, false)
			divider:SetHeight(S.targetDividerHeight); divider:SetAlpha(S.targetDividerAlpha)
		end
		row.label, row.difficulty = text(row, "GameFontNormal"), text(row)
		row.label._gfFontFlagsOverride = "OUTLINE"
		for _, value in ipairs({ row.label, row.difficulty }) do
			value:SetJustifyV("MIDDLE"); value:SetWordWrap(false); value:SetMaxLines(1)
			value:SetHeight(S.targetRowHeight)
			value._gfFontSizeOverride = S.targetTextSize
			if GF.Font and GF.Font.ApplyToFontString then GF.Font.ApplyToFontString(value, "GameFontNormal") end
		end
		row.label:SetPoint("LEFT", S.targetInset, 0); row.label:SetTextColor(unpack(S.accentColor))
		row.label:SetShadowColor(0, 0, 0, 0)
		row.label:SetShadowOffset(0, 0)
		row.difficulty:SetPoint("RIGHT", -S.targetInset, 0); row.difficulty:SetJustifyH("RIGHT")
		row.difficulty:SetTextColor(unpack(S.targetDifficultyColor))
		self.targetTiles[index] = row
	end
	row:Show(); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y)
	row:SetSize(width, S.targetRowHeight)
	-- Close the atlas' transparent gap by one physical pixel on each side.
	local dividerInset = S.targetDividerInsetPixels
	local scale = row.GetEffectiveScale and row:GetEffectiveScale()
	if PixelUtil and PixelUtil.GetNearestPixelSize and scale and scale > 0 then
		dividerInset = PixelUtil.GetNearestPixelSize(0, scale, S.targetDividerInsetPixels)
	end
	row.topDivider:ClearAllPoints(); row.divider:ClearAllPoints()
	row.topDivider:SetPoint("TOPLEFT", 0, -dividerInset); row.topDivider:SetPoint("TOPRIGHT", 0, -dividerInset)
	row.divider:SetPoint("BOTTOMLEFT", 0, dividerInset); row.divider:SetPoint("BOTTOMRIGHT", 0, dividerInset)
	local contentWidth = math.max(1, width - S.targetInset * 2 - S.gap)
	local difficultyWidth = contentWidth * S.targetDifficultyRatio
	row.label:SetWidth(contentWidth - difficultyWidth); row.difficulty:SetWidth(difficultyWidth)
	row.label:SetText(P.Display(group.activityGroupName or group.name)); row.difficulty:SetText(targetDifficultyText(group))
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(row.label, contentWidth - difficultyWidth, S.targetMinTextSize)
		GF.Font.SetFitWidth(row.difficulty, difficultyWidth, S.targetMinTextSize)
	end
	row.image:SetSize(math.min(S.targetImageWidth, width), S.targetImageHeight)
	row.image:SetTexture(group.texture)
	row.image:SetTexCoord(unpack(group.texCoords or { 0, 1, 0, 1 }))
	row.image:SetShown(group.texture ~= nil)
end

function Panel:PaintMemberRow(row, hovered)
	row.hovered = hovered == true
	if not row.memberStyle then return end
	local hoverColor = GF.GetListBackgroundOverlayColor(row.memberStyle, "hover")
	local color = row.backgroundColor or {}
	for i = 1, 3 do color[i] = row.hovered and hoverColor[i] or row.memberColor[i] end
	color[4] = 1
	row.backgroundColor = color
	UI.ApplyRowBackgroundPieces(row.backgroundHost, row.backgroundPieces, {
		profile = GF.LIST_ROW_STYLE.background,
		mode = "full", state = "normal", alpha = GF.GetListBackgroundAlpha(row.memberStyle), vertexColor = row.memberColor,
		desaturated = true, fallbackTexture = GF.ROW_BACKGROUND_FALLBACK_TEXTURE,
	})
	UI.ApplyRowBackgroundPieces(row.backgroundHost, row.hoverPieces, {
		profile = GF.LIST_ROW_STYLE.background,
		mode = "full", state = "normal", alpha = GF.BROWSE_ROW_SELECTED_ALPHA, vertexColor = hoverColor,
		desaturated = true, fallbackTexture = GF.ROW_BACKGROUND_FALLBACK_TEXTURE,
	})
	UI.SetRowBackgroundPiecesShown(row.hoverPieces, row.hovered)
	for _, divider in ipairs(row.dividers) do GF.ColumnHeaderBar:TintDivider(divider, color) end
end

function Panel:HideMemberTooltip(row)
	if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

function Panel:ShowMemberTooltip(row)
	local record = service():GetActivityView()
	if self.activityRetiring or not row:IsShown() or not record or record.members[row.memberIndex] ~= row.member then
		self:HideMemberTooltip(row)
		return
	end
	GF.ApplicantMemberBlock:ShowStandardTooltip(row, row.tooltipData)
end

function Panel:RenderMemberRow(index, member, parent, width, y, activityInfo)
	local row = self.memberRows[index]
	if not row then
		row = CreateFrame("Frame", nil, parent)
		row:SetClipsChildren(true)
		-- Keep the fade outside the text bounds, within its own scrolling viewport.
		row.backgroundHost = CreateFrame("Frame", nil, self.activityBackgroundViewport)
		row.backgroundHost:SetFrameLevel(self.activityBackgroundViewport:GetFrameLevel() + 1)
		row.backgroundPieces = UI.CreateRowBackgroundPieces(row.backgroundHost, "BACKGROUND", -2)
		row.hoverPieces = UI.CreateRowBackgroundPieces(row.backgroundHost, "BORDER", -1)
		for _, piece in pairs(row.hoverPieces) do piece:SetBlendMode("ADD") end
		row.classIcon = row:CreateTexture(nil, "ARTWORK")
		row.classIcon:SetPoint("CENTER", row, "LEFT", S.memberInset + S.memberIconSize / 2, GF.LIST_ROW_STYLE.contentOffsetY)
		row.specIcon = row:CreateTexture(nil, "ARTWORK")
		row.specIcons = { row.specIcon }
		row.specColumn = CreateFrame("Frame", nil, row)
		row.specColumn:SetSize(S.memberIconSize, S.memberIconSize)
		row.specIcon:SetPoint("CENTER", row.specColumn, "CENTER")
		row.name, row.itemLevel = text(row), text(row)
		for _, value in ipairs({ row.name, row.itemLevel }) do
			value:SetJustifyV("MIDDLE"); value:SetWordWrap(false); value:SetMaxLines(1)
			value:SetHeight(math.max(1, S.memberRowHeight - 2 * math.abs(GF.LIST_ROW_STYLE.contentOffsetY)))
			value:SetTextColor(unpack(S.textColor))
			value._gfFontSizeOverride = S.memberTextSize
			if GF.Font and GF.Font.ApplyToFontString then GF.Font.ApplyToFontString(value, "GameFontHighlightSmall") end
		end
		-- Leave room for the complete atlas fade inside the row boundary.
		row.itemLevel:SetJustifyH("RIGHT")
		row.itemLevel:SetPoint("RIGHT", -S.memberRightInset, GF.LIST_ROW_STYLE.contentOffsetY)
		row.dividers, row.roleIcons = {}, {}
		for i = 1, 3 do
			row.dividers[i] = GF.ColumnHeaderBar:CreateDivider(row, S.memberDividerHeight)
			row.roleIcons[i] = row:CreateTexture(nil, "ARTWORK")
			-- Role atlases include more outer padding than the circular class/spec art.
			row.roleIcons[i]:SetSize(S.memberRoleIconSize, S.memberRoleIconSize)
		end
		row.roles = CreateFrame("Frame", nil, row)
		row.roles:SetSize(S.memberRoleIconSize, S.memberRoleIconSize)
		row.unknownRole = row:CreateTexture(nil, "ARTWORK")
		row.unknownRole:SetSize(S.memberIconSize, S.memberIconSize)
		row.unknownRole:SetPoint("CENTER", row.roles, "CENTER")
		row.unknownRole:SetTexture(S.memberUnknownIcon)
		row:EnableMouse(true)
		row:SetScript("OnEnter", function() Panel:PaintMemberRow(row, true); Panel:ShowMemberTooltip(row) end)
		local function leave() Panel:PaintMemberRow(row, false); Panel:HideMemberTooltip(row) end
		row:SetScript("OnLeave", leave)
		row:SetScript("OnShow", function() row.backgroundHost:Show() end)
		row:SetScript("OnHide", function() row.backgroundHost:Hide(); leave() end)
		self.memberRows[index] = row
	end
	if row.member ~= member then self:HideMemberTooltip(row); row.hovered = false end
	row.member, row.memberIndex = member, index
	row.tooltipData = service():BuildMemberTooltipData(member, activityInfo)
	GF.ApplicantRaidTooltip.Prepare(row.tooltipData)
	local rightOutset = S.memberBackgroundOutset * (1 - (self.activityScrollProgress or 0))
	row.backgroundHost:ClearAllPoints()
	row.backgroundHost:SetPoint("TOPLEFT", row, "TOPLEFT", -S.memberBackgroundOutset, 0)
	row.backgroundHost:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", rightOutset, 0)
	row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetSize(width, S.memberRowHeight); row:Show()
	local classIcon, classFile = UI.ResolveClassIcon(member.classID)
	local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	row.memberColor = color and { color.r, color.g, color.b, 1 } or S.mutedColor
	row.memberStyle = { r = row.memberColor[1], g = row.memberColor[2], b = row.memberColor[3],
		alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT }
	self:PaintMemberRow(row, row.hovered)
	UI.SetSpecializationIcon(row.classIcon, classIcon or S.memberUnknownIcon,
		{
			size = S.memberIconSize * GF.LIST_SPECIALIZATION_ICON_SCALE, outerSize = S.memberIconSize,
			ringStyle = GF.CLASS_SPECIALIZATION_RING_STYLE, classFile = classFile,
		})
	local ids = P.GetSpecIDs(member)
	local count = math.max(1, #ids)
	row.specWidth = count * S.memberIconSize + (count - 1) * S.memberIconGap
	row.specColumn:SetSize(row.specWidth, S.memberIconSize)
	for i = 1, math.max(count, #row.specIcons) do
		local icon = row.specIcons[i]
		if not icon then
			icon = row:CreateTexture(nil, "ARTWORK"); row.specIcons[i] = icon
		end
		if i <= count then
			icon:ClearAllPoints()
			icon:SetPoint("CENTER", row.specColumn, "CENTER",
				(i - (count + 1) / 2) * (S.memberIconSize + S.memberIconGap), 0)
			UI.SetSpecializationIcon(icon, self.specIcons[ids[i]] or S.memberUnknownIcon, {
				size = S.memberIconSize * GF.LIST_SPECIALIZATION_ICON_SCALE, outerSize = S.memberIconSize,
				ringStyle = GF.CLASS_SPECIALIZATION_RING_STYLE, classFile = classFile,
			})
		else UI.ClearSpecializationIcon(icon) end
	end
	row.name:SetText(P.Display(member.name))
	row.name:SetTextColor(unpack(row.memberColor))
	local itemValue = member.itemLevel > 0 and string.format(S.memberItemLevelValueFormat, member.itemLevel) or label("UNKNOWN")
	row.itemLevel:SetText(string.format(label("MEMBER_ITEM_LEVEL_FMT"), itemValue))
	local roleCount = 0
	for i, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
		local icon = row.roleIcons[i]
		local selected = P.HasRole(member.roles, 2 ^ (i - 1))
		icon:SetShown(selected)
		if selected then
			roleCount = roleCount + 1
			icon:SetAtlas(GF.ROLE_ICON_ATLAS[role])
		end
	end
	local roleSlots = math.max(1, roleCount)
	row.roleWidth = roleSlots * S.memberRoleIconSize + (roleSlots - 1) * S.memberRoleGap
	row.roles:SetWidth(row.roleWidth)
	local position = 0
	for _, icon in ipairs(row.roleIcons) do
		if icon:IsShown() then
			icon:ClearAllPoints()
			icon:SetPoint("CENTER", row.roles, "CENTER", (position - (roleCount - 1) / 2) * (S.memberRoleIconSize + S.memberRoleGap), 0)
			position = position + 1
		end
	end
	row.unknownRole:SetShown(roleCount == 0)
	return row.itemLevel:GetStringWidth()
end

function Panel:LayoutMemberRow(row, width, itemWidth)
	row.itemLevel:SetWidth(itemWidth)
	local roleWidth = row.roles:GetWidth()
	row.dividers[3]:ClearAllPoints(); row.dividers[3]:SetPoint("CENTER", row.itemLevel, "LEFT", -S.memberDividerGap, 0)
	row.roles:ClearAllPoints(); row.roles:SetPoint("RIGHT", row.dividers[3], "CENTER", -S.memberDividerGap, 0)
	row.dividers[2]:ClearAllPoints(); row.dividers[2]:SetPoint("CENTER", row.roles, "LEFT", -S.memberDividerGap, 0)
	row.specColumn:ClearAllPoints(); row.specColumn:SetPoint("RIGHT", row.dividers[2], "CENTER", -S.memberDividerGap, 0)
	row.dividers[1]:ClearAllPoints(); row.dividers[1]:SetPoint("CENTER", row.specColumn, "LEFT", -S.memberDividerGap, 0)
	local nameWidth = math.max(1, width - S.memberInset - S.memberRightInset - S.memberIconSize - row.specColumn:GetWidth()
		- S.memberIconGap - S.memberDividerGap * 6 - roleWidth - itemWidth)
	row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row, "LEFT", S.memberInset + S.memberIconSize + S.memberIconGap, GF.LIST_ROW_STYLE.contentOffsetY)
	row.name:SetWidth(nameWidth)
	if GF.Font and GF.Font.SetFitWidth then GF.Font.SetFitWidth(row.name, nameWidth, S.memberMinTextSize) end
end

function Panel:SetActivityOffset(offset)
	if self.activityRetiring then offset = self.activityOffset or 0 end
	local previous = self.activityOffset or 0
	local range = self.activityContent:GetVerticalScrollRange()
	self.activityOffset = math.min(range, math.max(0, offset))
	if range == 0 then
		UI.CancelSmoothWheelScrolling(self.activityContent)
	elseif self.activityOffset ~= previous then
		UI.NotifySmoothWheelScroll(self.activityContent, self.activityOffset)
	end
	for _, key in ipairs({ "AWAITING", "TARGETS", "MEMBERS", "PROGRESS", "NOTE" }) do
		local block = self.activityBlocks[key]
		block:ClearAllPoints()
		block:SetPoint("TOPLEFT", block.activityX or 0, self.activityOffset - (block.activityY or 0))
	end
	if self.activityEmptyGroup and self.activityEmptyGroup:IsShown() then
		local emptyOffset = self.activityRetiring and 0 or self.activityOffset
		local emptyOutset = self.activityRetiring and #self.awaitingDisplayRows == 0
			and S.activityScrollGutter * (self.activityScrollProgress or 0) or 0
		self.activityEmptyGroup:ClearAllPoints()
		self.activityEmptyGroup:SetPoint("TOPLEFT", 0, emptyOffset - (self.activityEmptyY or 0))
		self.activityEmptyGroup:SetPoint("TOPRIGHT", emptyOutset, emptyOffset - (self.activityEmptyY or 0))
	end
	self:RefreshActivityEdgeFade()
	self:SyncActivityScrollBar()
end

function Panel:RefreshActivityEdgeFade()
	local content = self.activityContent
	local range = content:GetVerticalScrollRange()
	local offset = math.max(0, math.min(range, self.activityOffset or 0))
	local top = math.min(S.activityScrollEdgeFade, offset)
	local bottom = math.min(S.activityScrollEdgeFade, range - offset)
	if self.activityFadeTopLength == top and self.activityFadeBottomLength == bottom then return end
	self.activityFadeTopLength, self.activityFadeBottomLength = top, bottom
	-- Fade only the existing clipped content subtree. Card chrome, member
	-- backgrounds and the native scrollbar remain in their separate layers.
	if top > 0 or bottom > 0 then
		content:SetAlphaGradient(0, CreateVector2D(0, top))
		content:SetAlphaGradient(1, CreateVector2D(0, bottom))
	else
		content:ClearAlphaGradient()
	end
end

function Panel:SyncActivityScrollBar()
	local bar = self.activityScrollBar
	if not bar or self.activityScrollSyncing then return end
	self.activityScrollSyncing = true
	local range = self.activityContent:GetVerticalScrollRange()
	local progress = self.activityScrollProgress or 0
	local needed = self.activityScrollTarget == 1
	-- Preserve the thumb while the whole bar fades away, even if the range
	-- has already collapsed. Native automatic visibility would cut this short.
	if needed or progress == 0 then
		local height = math.max(1, self.activityContent:GetHeight())
		bar:SetVisibleExtentPercentage(height / (height + range))
		bar:SetPanExtentPercentage(range > 0 and math.min(1, GF.GetWheelScrollPixels(S.memberRowHeight) / range) or 0)
		bar:SetScrollPercentage(range > 0 and (self.activityOffset or 0) / range or 0, true)
	end
	local interactive = needed and progress == 1 and range > 0 and visible(self.activityContent) and not self.activityRetiring
	bar:SetScrollAllowed(interactive)
	bar:GetTrack():EnableMouse(interactive)
	bar:EnableMouseWheel(interactive)
	bar:SetAlpha(progress * (self.activityRetiring and #self.awaitingDisplayRows == 0 and self.activityOpacity or 1))
	bar:SetShown(progress > 0 or needed)
	self.activityScrollSyncing = nil
end

function Panel:SetActivityScrollProgress(progress)
	self.activityScrollProgress = progress
	local gutter = S.activityScrollGutter * progress
	local content = self.activityContent
	self.adjustingActivityViewport = true
	content:ClearAllPoints()
	-- Use two corners on the owning card; a decorative header texture is not
	-- a reliable geometry dependency while a hidden page is first constructed.
	content:SetPoint("TOPLEFT", self.activityCard, "TOPLEFT", S.contentInset, -GF.CARD_HEADER_STYLE.height - S.activityScrollEdgeInset)
	content:SetPoint("BOTTOMRIGHT", self.activityCard, "BOTTOMRIGHT", -S.contentInset - gutter, S.activityScrollEdgeInset)
	-- Reclaim the extra background outset as the bar appears, so the complete
	-- fade can stay inside the tighter gutter without painting under the track.
	local rightOutset = S.memberBackgroundOutset * (1 - progress)
	self.activityBackgroundViewport:ClearAllPoints()
	self.activityBackgroundViewport:SetPoint("TOPLEFT", content, "TOPLEFT", -S.memberBackgroundOutset, 0)
	self.activityBackgroundViewport:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", rightOutset, 0)
	self.activityViewportWidth = math.max(1, content:GetWidth())
	self.activityViewportHeight = content:GetHeight()
	self.adjustingActivityViewport = nil
end

function Panel:TickActivityScrollAnimation(elapsed)
	local fade, snapshot = self.activityScrollFade, self.activityLayoutSnapshot
	if not fade or not snapshot then return end
	fade.elapsed = fade.elapsed + math.max(0, elapsed)
	local p = math.min(1, fade.elapsed / S.activityScrollDuration)
	local eased = p * p * (3 - 2 * p)
	local progress = fade.from + (fade.target - fade.from) * eased
	if p == 1 then progress = fade.target; self.activityScrollFade = nil end
	self:SetActivityScrollProgress(progress)
	-- Only reflow the existing snapshot during the short transition. Do not
	-- rebuild the publication draft or read native applications every frame.
	self:LayoutActivityContents(snapshot.shown, snapshot.waiting, self.activityViewportWidth, snapshot.entries)
	self:SetActivityOffset(self.activityOffset or 0)
end

function Panel:StopActivityScrollAnimation()
	UI.CancelSmoothWheelScrolling(self.activityContent)
	self.activityScrollFade, self.activityLayoutSnapshot, self.activityScrollTarget = nil, nil, nil
	self:SetActivityScrollProgress(0)
	self.activityScrollBar:UnregisterUpdate()
	self:SyncActivityScrollBar()
end

function Panel:InitActivityScrollBar()
	local bar = CreateFrame("EventFrame", nil, self.activityCard, "MinimalScrollBar")
	self.activityScrollBar = bar
	local style = GF.CARD_HEADER_STYLE
	bar:SetPoint("TOPRIGHT", self.activityCard.header.rule, "BOTTOMRIGHT",
		style.inset + style.dividerInset - S.activityScrollRightInset, -S.activityScrollEdgeInset)
	bar:SetPoint("BOTTOMRIGHT", self.activityCard, "BOTTOMRIGHT", -S.activityScrollRightInset, S.activityScrollEdgeInset)
	bar:SetWidth(S.activityScrollBarWidth)
	bar:SetFrameLevel(self.activityContent:GetFrameLevel() + 10)
	UI.ApplyCommonScrollBarSkin(bar)
	bar:SetHideIfUnscrollable(false)
	bar:SetInterpolateScroll(false)
	bar:RegisterCallback("OnScroll", function(_, percentage)
		if not self.activityScrollSyncing and self.activityScrollTarget == 1
			and self.activityScrollProgress == 1 and visible(self.activityContent) and not self.activityRetiring then
			UI.CancelSmoothWheelScrolling(self.activityContent)
			-- The native thumb already owns this percentage; avoid feeding its
			-- drag update back into itself while synchronizing the content.
			self.activityScrollSyncing = true
			self:SetActivityOffset(percentage * self.activityContent:GetVerticalScrollRange())
			self.activityScrollSyncing = nil
		end
	end, self)
	bar:SetScript("OnMouseWheel", function(_, delta)
		local onWheel = self.activityContent:GetScript("OnMouseWheel")
		if onWheel then onWheel(self.activityContent, delta) end
	end)
	bar:HookScript("OnHide", function() bar:UnregisterUpdate() end)
	self:SyncActivityScrollBar()
end

local progressText = GF.RaidSeekingProgressRow.CreateText
local renderProgressBackground = GF.RaidSeekingProgressRow.RenderBackground
local hideProgressTooltip = GF.RaidSeekingProgressRow.HideTooltip
local progressRowOptions = {
	canShowTooltip = function() return not Panel.activityRetiring end,
	getBosses = function(entry) return service():ProgressBosses(entry.activityID, entry) end,
}

function Panel:RenderProgressRow(index, group, parent, width, y)
	progressRowOptions.headingKey = self.activityDisplayReadOnly and "LEADER_PROGRESS" or "PROGRESS"
	self.progressRows[index] = GF.RaidSeekingProgressRow.Render(self.progressRows[index], group, parent, width, y, progressRowOptions)
end

local function awaitingName(entry)
	if entry.name then return P.Display(entry.name) .. "（" .. P.Display(entry.difficulty or label("UNKNOWN")) .. "）" end
	return P.Display(entry.fullName or label("UNKNOWN"))
end

local function awaitingStatus(entry)
	if entry.stale then return label("AWAITING_UNAVAILABLE") end
	if entry.cancelReason == "unempowered" then return label("APPLY_CANCEL_NO_PERMISSION") end
	local states = { cancelling = "APP_STATE_CANCELLING", auto_cancelling = "APP_STATE_CANCELLING",
		waiting_confirm = "APP_STATE_WAITING_CONFIRM", waiting_update = "APP_STATE_WAITING_UPDATE",
		cancel_failed = "APPLY_CANCEL_FAILED" }
	return states[entry.actionState] and label(states[entry.actionState]) or label("AWAITING_INVITE")
end

local function showAwaitingTooltip(row)
	local entry = row.entry
	if not entry or row.retiring or not visible(row) then return end
	if GF.ListTooltip and GF.ListTooltip:Show(GameTooltip, entry.resultID, row, entry) then return end
	UI.BeginGameTooltip(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(awaitingName(entry), S.accentColor[1], S.accentColor[2], S.accentColor[3], true)
	GameTooltip:AddLine(P.Display(entry.teamName or label("UNKNOWN")), 1, 1, 1)
	GameTooltip:AddLine(string.format(label("AWAITING_LEADER_FMT"), P.Display(entry.leaderName or label("UNKNOWN"))), 1, 1, 1)
	GameTooltip:AddLine(string.format(label("AWAITING_MEMBERS_FMT"), entry.numMembers or "—",
		entry.counts[1] or "—", entry.counts[2] or "—", entry.counts[3] or "—"), 1, 1, 1)
	GameTooltip:AddLine(string.format(label("AWAITING_PROGRESS_FMT"), entry.killed or "—", entry.total or "—"), 1, 1, 1)
	GameTooltip:AddLine(awaitingStatus(entry), S.mutedColor[1], S.mutedColor[2], S.mutedColor[3], true)
	UI.ShowGameTooltip(GameTooltip)
end

function Panel:RefreshAwaitingClock(row)
	local entry = row.entry
	if not entry then return end
	local remaining = not entry.stale and entry.expiration and math.max(0, math.ceil(entry.expiration - GetTime()))
	row.clock:SetText(remaining and string.format("%d:%02d", math.floor(remaining / 60), remaining % 60) or "—:—")
end

function Panel:RenderAwaitingRow(index, entry, parent, width, y)
	local row = self.awaitingRows[index]
	if not row then
		row = CreateFrame("Frame", nil, parent)
		row:SetClipsChildren(true)
		row.backgroundPieces, row.dividers = {}, {}
		row:SetAlpha(0)
		row.label, row.progress, row.clock = progressText(row, "OUTLINE"), progressText(row), progressText(row)
		row.members = CreateFrame("Frame", nil, row)
		row.members:SetHeight(S.progressRowHeight)
		row.roleCells = {}
		for i, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
			local cell = CreateFrame("Frame", nil, row.members)
			cell:SetSize(S.awaitingRoleIconSize + S.awaitingRoleTextGap + S.awaitingRoleTextWidth, S.progressRowHeight)
			cell.icon = cell:CreateTexture(nil, "OVERLAY")
			cell.icon:SetAtlas(GF.ROLE_ICON_ATLAS[role]); cell.icon:SetSize(S.awaitingRoleIconSize, S.awaitingRoleIconSize)
			cell.icon:SetPoint("LEFT")
			cell.value = progressText(cell)
			cell.value:SetPoint("LEFT", cell.icon, "RIGHT", S.awaitingRoleTextGap, 0)
			cell.value:SetWidth(S.awaitingRoleTextWidth); cell.value:SetJustifyH("CENTER")
			cell.value:SetTextColor(unpack(S.textColor))
			row.roleCells[i] = cell
		end
		for _, value in ipairs({ row.progress, row.clock }) do
			value:SetTextColor(unpack(S.textColor)); value:SetJustifyH("CENTER")
		end
		row.spinner = UI.CreatePendingSpinner(row, S.awaitingSpinnerSize)
		row.cancel = CreateFrame("Button", nil, row)
		row.cancel:SetSize(S.awaitingCancelWidth, S.awaitingCancelWidth)
		row.cancel.icon = row.cancel:CreateTexture(nil, "OVERLAY", nil, 2)
		row.cancel.icon:SetAtlas(GF.APPLICANT_DECLINE_ICON_ATLAS)
		UI.ApplyCommonSmallButtonSkin(row.cancel, row.cancel.icon)
		row.cancel:EnableMouse(true)
		row.cancel:SetFrameLevel(row:GetFrameLevel() + 4)
		row.cancel:RegisterForClicks("LeftButtonUp")
		row.cancel:HookScript("OnMouseDown", function(_, mouseButton)
			row.cancelEntry = mouseButton == "LeftButton" and row.cancel:IsEnabled() and row.entry or nil
		end)
		row.cancel:SetScript("OnClick", function()
			local pressed, current = row.cancelEntry, row.entry
			row.cancelEntry = nil
			if row.retiring or not row.cancel:IsEnabled() or not visible(row) or not pressed or not current
				or pressed.resultID ~= current.resultID
				or pressed.identity.generation ~= current.identity.generation
				or pressed.identity.partyGUID ~= current.identity.partyGUID then return end
			local ok, reason = GF.RaidAwaitingApplications:Cancel(pressed)
			if not ok and reason and GF.ShowStatusMessage then GF.ShowStatusMessage(reason, { semantic = true }) end
			Panel:Refresh(true)
		end)
		row.cancel:HookScript("OnEnter", function()
			if not row.retiring then UI.ShowSimpleTooltip(row.cancel, label("APPLY_CANCEL_APPLICATION"), "ANCHOR_RIGHT") end
		end)
		row.cancel:HookScript("OnLeave", function()
			row.cancelEntry = nil; GameTooltip_Hide()
		end)
		row.cancel:HookScript("OnHide", function() row.cancelEntry = nil end)
		for i = 1, 4 do
			row.dividers[i] = GF.ColumnHeaderBar:CreateDivider(row, S.progressDividerHeight)
			GF.ColumnHeaderBar:TintDivider(row.dividers[i], S.mutedColor)
		end
		row:EnableMouse(true)
		row:SetScript("OnEnter", showAwaitingTooltip)
		row:SetScript("OnLeave", hideProgressTooltip)
		row:SetScript("OnHide", function() row.cancelEntry = nil; UI.StopPendingSpinner(row.spinner); hideProgressTooltip(row) end)
		row:SetScript("OnShow", function()
			if row.entry and not row.retiring then UI.StartPendingSpinner(row.spinner, S.awaitingSpinnerSize) end
		end)
		self.awaitingRows[index] = row
	end
	row.entry = entry
	row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetSize(width, S.progressRowHeight)
	UI.ApplyControlCardChrome(row)
	renderProgressBackground(row, entry, width)
	row.label:SetText(awaitingName(entry))
	for i, cell in ipairs(row.roleCells) do cell.value:SetText(tostring(entry.counts[i] or "—")) end
	local progressFormat = entry.killed == 0 and S.progressZeroValueFormat or S.progressValueFormat
	row.progress:SetText(entry.killed and entry.total and string.format(progressFormat, entry.killed, entry.total)
		or (tostring(entry.killed or "—") .. "/" .. tostring(entry.total or "—")))
	row.cancel:SetEnabled(entry.canCancel == true and not row.retiring)
	local gap = S.awaitingColumnGap
	local available = math.max(1, width - S.progressInset * 2 - gap * 8 - row.dividers[1]:GetWidth() * 4)
	local fixedWidth = S.awaitingMembersWidth + S.awaitingProgressWidth + S.awaitingStatusWidth + S.awaitingCancelWidth
	local widths = { math.max(1, available - fixedWidth), S.awaitingMembersWidth,
		S.awaitingProgressWidth, S.awaitingStatusWidth, S.awaitingCancelWidth }
	local values, offset = { row.label, row.members, row.progress }, S.progressInset
	for i = 1, 5 do
		local columnWidth = widths[i]
		local value = values[i]
		if value then
			value:ClearAllPoints(); value:SetPoint("LEFT", row, "LEFT", offset, 0); value:SetWidth(columnWidth)
			if i ~= 2 and GF.Font and GF.Font.SetFitWidth then GF.Font.SetFitWidth(value, columnWidth, S.progressMinTextSize) end
		elseif i == 4 then
			row.spinner:ClearAllPoints(); row.spinner:SetPoint("LEFT", row, "LEFT", offset, 0)
			row.clock:ClearAllPoints(); row.clock:SetPoint("LEFT", row.spinner, "RIGHT", 1, 0)
			row.clock:SetWidth(math.max(1, columnWidth - S.awaitingSpinnerSize - 1))
			if GF.Font and GF.Font.SetFitWidth then GF.Font.SetFitWidth(row.clock, row.clock:GetWidth(), S.progressMinTextSize) end
		else
			row.cancel:ClearAllPoints(); row.cancel:SetPoint("LEFT", row, "LEFT", offset, 0)
			row.cancel:SetSize(columnWidth, columnWidth)
		end
		offset = offset + columnWidth
		if i < 5 then
			local divider = row.dividers[i]
			divider:ClearAllPoints(); divider:SetPoint("LEFT", row, "LEFT", offset + gap, 0)
			offset = offset + gap * 2 + divider:GetWidth()
		end
	end
	for i, cell in ipairs(row.roleCells) do
		cell:ClearAllPoints(); cell:SetPoint("CENTER", row.members, "LEFT", row.members:GetWidth() * (i - 0.5) / 3, 0)
		if GF.Font and GF.Font.SetFitWidth then GF.Font.SetFitWidth(cell.value, S.awaitingRoleTextWidth, S.progressMinTextSize) end
	end
	self:RefreshAwaitingClock(row)
	row:Show()
	if row.retiring then UI.StopPendingSpinner(row.spinner) else UI.StartPendingSpinner(row.spinner, S.awaitingSpinnerSize) end
	if GameTooltip and GameTooltip:IsOwned(row) then showAwaitingTooltip(row) end
	return row
end

local function fadeAwaitingRow(row, target)
	if row.fade and row.fade.target == target or row:GetAlpha() == target and not row.fade then return end
	row.fade = { from = row:GetAlpha(), target = target, elapsed = 0 }
end

function Panel:UpdateAwaitingRows(entries, block, width, titleHeight)
	local incoming, display, existing = {}, {}, {}
	for _, entry in ipairs(entries) do
		local key = entry.resultID .. ":" .. entry.identity.generation
		incoming[key] = entry
	end
	for _, row in ipairs(self.awaitingDisplayRows or {}) do
		if row.entry then
			local entry = incoming[row.applicationKey]
			row.retiring = entry == nil
			if entry then row.entry = entry; existing[row.applicationKey] = true end
			if row.retiring then
				row.cancelEntry = nil; hideProgressTooltip(row)
				if GameTooltip and GameTooltip:IsOwned(row.cancel) then GameTooltip_Hide() end
			end
			row:EnableMouse(not row.retiring)
			fadeAwaitingRow(row, row.retiring and 0 or 1)
			display[#display + 1] = row
		end
	end
	for _, entry in ipairs(entries) do
		local key = entry.resultID .. ":" .. entry.identity.generation
		if not existing[key] then
			local slot = #self.awaitingRows + 1
			for i, row in ipairs(self.awaitingRows) do if not row.entry then slot = i; break end end
			local row = self:RenderAwaitingRow(slot, entry, block, width, 0)
			row.applicationKey, row.retiring = key, nil
			row:SetAlpha(0); row:EnableMouse(true); fadeAwaitingRow(row, 1)
			display[#display + 1] = row
		end
	end
	self.awaitingDisplayRows = display
	local titleAlpha = 0
	for index, row in ipairs(display) do
		local slot
		for i, candidate in ipairs(self.awaitingRows) do if candidate == row then slot = i; break end end
		self:RenderAwaitingRow(slot, row.entry, block, width, titleHeight + (index - 1) * (S.progressRowHeight + S.progressRowGap))
		titleAlpha = math.max(titleAlpha, row:GetAlpha())
	end
	block.title:SetAlpha(titleAlpha)
	return #display
end

function Panel:TickAwaitingAnimations(elapsed)
	local removed, titleAlpha = false, 0
	for _, row in ipairs(self.awaitingDisplayRows or {}) do
		local fade = row.fade
		if fade then
			fade.elapsed = fade.elapsed + elapsed
			local p = math.min(1, fade.elapsed / S.awaitingFadeDuration)
			local eased = p * p * (3 - 2 * p)
			row:SetAlpha(fade.from + (fade.target - fade.from) * eased)
			if p >= 1 then
				row.fade = nil
				if fade.target == 0 then row:Hide(); row.entry, row.applicationKey = nil, nil; removed = true end
			end
		end
		if row.entry then titleAlpha = math.max(titleAlpha, row:GetAlpha()) end
	end
	self.activityBlocks.AWAITING.title:SetAlpha(titleAlpha)
	if removed then self:Refresh(true) end
end

function Panel:StopAwaitingAnimations()
	for _, row in ipairs(self.awaitingRows or {}) do
		row.fade, row.cancelEntry = nil, nil
		UI.StopPendingSpinner(row.spinner)
		hideProgressTooltip(row); row:SetAlpha(0)
		if row.retiring then row:Hide(); row.entry, row.applicationKey = nil, nil end
	end
end

function Panel:LayoutActivityContents(shown, waiting, width, entries)
	self.activityContent:Show()
	local empty = self.activityEmptyTarget == 1
	local restoring = waiting and service().restoring and true or false
	self.activityAppearanceRows, self.activityAppearanceSeen, self.activityNextDelay = {}, {}, 0
	self.activityRowsAnimating = false
	local block = self.activityBlocks.AWAITING
	block.title:SetText(label("AWAITING")); block:SetWidth(width)
	block.activityX, block.activityY = 0, S.activityContentTopInset
	local titleHeight = block.title:GetStringHeight() + S.titleGap
	local count = self:UpdateAwaitingRows(entries, block, width, titleHeight)
	block.body:Hide()
	local height = count > 0 and titleHeight + count * S.progressRowHeight + (count - 1) * S.progressRowGap or 0
	block:SetHeight(math.max(1, height)); block:SetShown(count > 0)
	local y = S.activityContentTopInset + (count > 0 and height + S.blockGap or 0)
	local emptyTop = y
	for _, key in ipairs({ "TARGETS", "MEMBERS", "PROGRESS", "NOTE" }) do
		local block = self.activityBlocks[key]
		local blockWidth = width
		block:SetShown(shown ~= nil or (key == "NOTE" and restoring))
		block.title:SetShown(shown ~= nil)
		block.activityX, block.activityY = 0, y; block:SetWidth(blockWidth)
		local titleKey = key == "MEMBERS" and shown and shown.mode:upper() or key == "NOTE" and "PREVIEW_NOTE" or key
		if key == "PROGRESS" and self.activityDisplayReadOnly then titleKey = "LEADER_PROGRESS" end
		block.title:SetText(label(titleKey))
		block.body:ClearAllPoints(); block.body:SetWidth(blockWidth)
		local titleHeight = shown and block.title:GetStringHeight() + S.titleGap or 0
		block.body:SetPoint("TOPLEFT", 0, -titleHeight)
		local bodyHeight = 0
		if key == "TARGETS" then
			block.body:Hide()
			local groups = service():GroupActivities(shown and shown.activityIDs, self.activityOptions)
			for i, group in ipairs(groups) do
				self:RenderTargetRow(i, group, block, width, titleHeight + (i - 1) * (S.targetRowHeight + S.targetRowGap))
				self:AddActivityAppearance(self.targetTiles[i], "target:" .. group.key, i == 1 and block.title or nil)
			end
			for i = #groups + 1, #self.targetTiles do self.targetTiles[i]:Hide() end
			bodyHeight = #groups > 0 and #groups * S.targetRowHeight + (#groups - 1) * S.targetRowGap or 0
		elseif key == "MEMBERS" then
			block.body:Hide()
			local members = shown and shown.members or {}
			local groups = service():GroupActivities(shown and shown.activityIDs, self.activityOptions)
			local activityInfo = { categoryID = GF.CAT_RAID, isCurrentRaidActivity = true,
				fullName = #groups == 1 and groups[1].name or label("APPLICANT_RAID_PROGRESS_TITLE") }
			local itemWidth, specWidth, roleWidth = S.memberItemLevelWidth, S.memberIconSize, S.memberRoleIconSize
			for i, member in ipairs(members) do
				itemWidth = math.max(itemWidth, self:RenderMemberRow(i, member, block, blockWidth,
					titleHeight + (i - 1) * (S.memberRowHeight + S.memberRowGap), activityInfo))
				specWidth = math.max(specWidth, self.memberRows[i].specWidth)
				roleWidth = math.max(roleWidth, self.memberRows[i].roleWidth)
				self:AddActivityAppearance(self.memberRows[i], "member:" .. member.name, i == 1 and block.title or nil)
			end
			for i = 1, #members do
				self.memberRows[i].specColumn:SetWidth(specWidth)
				self.memberRows[i].roles:SetWidth(roleWidth)
				self:LayoutMemberRow(self.memberRows[i], blockWidth, itemWidth)
			end
			for i = #members + 1, #self.memberRows do
				local row = self.memberRows[i]
				row:Hide(); row.member, row.tooltipData = nil, nil
			end
			bodyHeight = #members > 0 and #members * S.memberRowHeight + (#members - 1) * S.memberRowGap or 0
		elseif key == "PROGRESS" then
			local progress = service():GroupProgress(shown and shown.progress, self.activityOptions)
			for i, entry in ipairs(progress) do
				self:RenderProgressRow(i, entry, block, blockWidth,
					titleHeight + (i - 1) * (S.progressRowHeight + S.progressRowGap))
				self:AddActivityAppearance(self.progressRows[i], "progress:" .. entry.key, i == 1 and block.title or nil)
			end
			for i = #progress + 1, #self.progressRows do
				local row = self.progressRows[i]
				if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
				row:Hide(); row.tooltipTitle, row.tooltipEntries = nil, nil
			end
			block.body:SetText(#progress == 0 and label("UNKNOWN") or "")
			block.body:SetShown(shown ~= nil and #progress == 0)
			if shown and #progress == 0 then self:AddActivityAppearance(block.body, "progress:unknown", block.title) end
			bodyHeight = #progress > 0 and #progress * S.progressRowHeight + (#progress - 1) * S.progressRowGap
				or (shown and block.body:GetStringHeight() or 0)
		else
			block.body:Show()
			block.body:ClearAllPoints()
			block.body:SetPoint("TOPLEFT", block.bodyFrame, "TOPLEFT", S.noteInset, -S.noteInset)
			block.body:SetWidth(math.max(1, blockWidth - S.noteInset * 2))
			local lines = {}
			if shown then
				lines[1] = P.Display(shown.note ~= "" and shown.note or label("NO_NOTE"))
			elseif restoring then lines[1] = label("RESTORING") end
			block.body:SetText(table.concat(lines, "\n"))
			block.body:SetTextColor(unpack(shown and S.textColor or S.mutedColor))
			bodyHeight = math.max(S.progressRowHeight, block.body:GetStringHeight() + S.noteInset * 2)
			block.bodyFrame:ClearAllPoints(); block.bodyFrame:SetPoint("TOPLEFT", 0, -titleHeight)
			block.bodyFrame:SetSize(blockWidth, bodyHeight)
			UI.ApplyControlCardChrome(block.bodyFrame)
			if shown then self:AddActivityAppearance(block.bodyFrame, "note", block.title)
			else block.bodyFrame:SetAlpha(1) end
		end
		local height = titleHeight + bodyHeight
		block:SetHeight(math.max(1, height))
		if shown or (key == "NOTE" and restoring) then y = y + height + S.blockGap end
	end
	-- Center the empty message using the final empty viewport, even while the
	-- old, possibly scrolled publication is still retained for its exit fade.
	-- Content's leading padding does not shift the centered empty prompt.
	self.activityEmptyY = math.max(emptyTop, (emptyTop + self.activityContent:GetHeight()
		- S.activityContentTopInset - self.activityEmptyGroup:GetHeight()) / 2)
	if empty and not self.activityRetiring then
		y = self.activityEmptyY + self.activityEmptyGroup:GetHeight() + S.blockGap
	end
	for key in pairs(self.activityAppearances) do
		if not self.activityAppearanceSeen[key] then self.activityAppearances[key] = nil end
	end
	self:PaintActivityTransition()
	self.activityHeight = math.max(1, y - S.blockGap)
	return self.activityHeight
end

function Panel:LayoutActivitySnapshot(shown, waiting, entries)
	self.activityLayoutSnapshot = { shown = shown, waiting = waiting, entries = entries }
	-- Decide overflow at the full width. Measuring the narrowed viewport would
	-- let wrapped text keep an unnecessary gutter open after a resize/edit.
	local fullWidth = math.max(1, self.activityCard:GetWidth() - S.contentInset * 2)
	local fullHeight = self:LayoutActivityContents(shown, waiting, fullWidth, entries)
	local target = fullHeight > self.activityContent:GetHeight() + S.activityOverflowEpsilon and 1 or 0
	if self.activityScrollTarget ~= target then
		self.activityScrollTarget = target
		local from = self.activityScrollProgress or 0
		self.activityScrollFade = from ~= target and { from = from, target = target, elapsed = 0 } or nil
	end
	self:SetActivityScrollProgress(self.activityScrollProgress or 0)
	if self.activityViewportWidth ~= fullWidth then
		self:LayoutActivityContents(shown, waiting, self.activityViewportWidth, entries)
	end
	self:SetActivityOffset(self.activityOffset or 0)
end

function Panel:RefreshActivity(shown, waiting)
	local entries = GF.RaidAwaitingApplications and GF.RaidAwaitingApplications:GetEntries(self.activityOptions) or {}
	self:SetActivityEmptyTarget(not shown and not waiting)
	if shown then
		local identity = tostring(shown.owner) .. ":" .. tostring(shown.session)
		if self.activityIdentity ~= identity then self.activityAppearances = {} end
		self.activityIdentity, self.activityDisplayRecord = identity, shown
		self.activityDisplayReadOnly = self.activityMemberView
		if self.activityRetiring then
			self.activityRetiring = nil
			self.activityExitFade = { from = self.activityOpacity, target = 1, elapsed = 0 }
		end
	elseif self.activityDisplayRecord and visible(self.activityContent) then
		if not self.activityRetiring then
			self.activityRetiring = true
			self.activityExitFade = { from = self.activityOpacity, target = 0, elapsed = 0 }
			UI.CancelSmoothWheelScrolling(self.activityContent)
		end
	else
		self.activityIdentity, self.activityDisplayRecord, self.activityRetiring = nil, nil, nil
		self.activityExitFade, self.activityOpacity = nil, 1
	end
	self:LayoutActivitySnapshot(shown or self.activityDisplayRecord, waiting, entries)
end

function Panel:Init(parent)
	if self.frame then return end
	self.buttons, self.captions = {}, {}
	local frame = CreateFrame("Frame", nil, parent); frame:SetAllPoints(); frame:Hide(); self.frame = frame
	local left = CreateFrame("Frame", nil, frame)
	self.left = left
	left:SetPoint("TOPLEFT", S.inset, -S.inset)
	left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", S.inset, S.inset); left:SetWidth(S.sideWidth)
	self:InitForm(left)
	local right = CreateFrame("Frame", nil, frame)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", S.gap, 0); right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S.inset, S.inset)
	self.right = right
	self.board = GF.RaidSeekingBoardView.Create(self, section(frame, "BOARD_TITLE"), {
		activities = activityNames, roles = roleNames,
	})
	self.contactCard = section(right, "CONTACTS")
	self.activityCard = section(right, "MY_ACTIVITY")
	self:InitActivityBadge()
	self.activityStatus = text(self.activityCard.header, "GameFontNormal")
	self.activityStatus:SetHeight(GF.CARD_HEADER_STYLE.titleHeight)
	self.activityStatus:SetJustifyH("RIGHT"); self.activityStatus:SetJustifyV("MIDDLE")
	self.activityStatus:SetWordWrap(false); self.activityStatus:SetMaxLines(1)
	self.activityStatus._gfFontSizeOverride = S.activityStatusTextSize
	if GF.Font and GF.Font.ApplyToFontString then GF.Font.ApplyToFontString(self.activityStatus, "GameFontNormal") end
	self.activityCard.header:HookScript("OnSizeChanged", function() Panel:RequestLayoutRefresh() end)
	-- One clipped content frame owns the information blocks. Its right edge
	-- animates inward only while overflow needs room for the native scrollbar.
	self.activityContent = cardContent(self.activityCard, S.activityScrollEdgeInset, S.activityScrollEdgeInset)
	self.activityContent:SetClipsChildren(true)
	self.activityContent:SetFlattensRenderLayers(true)
	-- Only member backgrounds extend into the horizontal card padding. Match
	-- the content's vertical clip so their fades cannot scroll over the header.
	self.activityBackgroundViewport = CreateFrame("Frame", nil, self.activityCard)
	self.activityBackgroundViewport:SetPoint("TOPLEFT", self.activityContent, "TOPLEFT", -S.memberBackgroundOutset, 0)
	self.activityBackgroundViewport:SetPoint("BOTTOMRIGHT", self.activityContent, "BOTTOMRIGHT", S.memberBackgroundOutset, 0)
	self.activityBackgroundViewport:SetFrameLevel(self.activityContent:GetFrameLevel())
	self.activityBackgroundViewport:SetClipsChildren(true)
	-- These are separate clipped subtrees: texture draw layers alone cannot
	-- order them. Keep content above the viewport and its backgroundHost children.
	self.activityContent:SetFrameLevel(self.activityBackgroundViewport:GetFrameLevel() + 2)
	self.activityContent.GetVerticalScroll = function() return Panel.activityOffset or 0 end
	self.activityContent.GetVerticalScrollRange = function(content)
		return math.max(0, (Panel.activityHeight or 0) - content:GetHeight())
	end
	self.activityContent.SetVerticalScroll = function(_, offset) Panel:SetActivityOffset(offset) end
	self.activityContent._gfWheelRowH = S.memberRowHeight
	UI.BindRowWheelScrolling(self.activityContent)
	UI.BindSmoothWheelScrolling(self.activityContent, { manualScrollUpdates = true })
	self:InitActivityContent()
	self:InitActivityScrollBar()
	-- Keep application clocks current even while the publication channel is
	-- reconnecting. This driver only runs while the activity card is visible.
	self.activityContent:SetScript("OnUpdate", function(_, elapsed)
		Panel:TickActivityAnimations(elapsed)
		Panel:TickAwaitingAnimations(elapsed)
		Panel:TickActivityScrollAnimation(elapsed)
		Panel.awaitingElapsed = (Panel.awaitingElapsed or 0) + elapsed
		if Panel.awaitingElapsed < 1 then return end
		Panel.awaitingElapsed = 0
		Panel:Refresh()
	end)
	self.activityContent:HookScript("OnHide", function()
		Panel:StopActivityAnimations()
		Panel:StopAwaitingAnimations(); Panel:StopActivityScrollAnimation()
	end)
	self.activityEmptyGroup, self.activityEmptyTitle, self.activityEmpty = centeredPrompt(self.activityContent)
	self.activityEmptyGroup:SetUsingParentLevel(true)
	self.activityContent:HookScript("OnSizeChanged", function(content, width, height)
		Panel:RefreshActivityEdgeFade()
		width, height = width or content:GetWidth(), height or content:GetHeight()
		if Panel.activityViewportWidth and math.abs(width - Panel.activityViewportWidth) < 0.001
			and math.abs(height - (Panel.activityViewportHeight or 0)) < 0.001 then return end
		Panel:RequestLayoutRefresh()
	end)
	self.contactContent = cardContent(self.contactCard, GF.RAID_SEEKING_CHAT_STYLE.footerHeight + S.gap)
	-- Empty chat has no footer: center its prompt in the same full-height area as activity.
	self.contactEmptyContent = cardContent(self.contactCard, S.activityScrollEdgeInset, S.activityScrollEdgeInset)
	self.contactEmptyGroup, self.contactEmptyTitle, self.contactEmpty = centeredPrompt(self.contactEmptyContent)
	self.chat = GF.RaidSeekingChatView.Create(self)
	frame:HookScript("OnHide", function()
		Panel:CancelLayoutRefresh()
		Panel:CancelDataRefresh()
		Panel.feedbackPreparing = nil
		Panel:StopFeedbackExit()
		Panel.layoutDirty = true
		Panel.featureActive = nil
		Panel.retrying = nil
		Panel:StopActivityBadge()
		Panel:StopActivityAnimations()
		Panel:StopActivityScrollAnimation()
		for _, specButton in ipairs(Panel.roles) do hideSpecChoice(specButton) end
		UI.SetButtonPendingSpinner(Panel.publish, false)
		Panel.note:ClearFocus(); service():SaveDraft(); GameTooltip_Hide()
	end)
	for _, event in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "PARTY_INVITE_REQUEST",
		"LFG_LIST_APPLICATION_STATUS_UPDATED", "LFG_LIST_SEARCH_RESULT_UPDATED", "LFG_LIST_SEARCH_RESULTS_RECEIVED" }) do frame:RegisterEvent(event) end
	for event in pairs(FORM_STATE_EVENTS) do frame:RegisterEvent(event) end
	frame:SetScript("OnEvent", function(_, event)
		-- Form permissions follow the live roster even when the channel driver
		-- is stopped. Read after the event burst, bypassing the paint throttle;
		-- a late GROUP_LEFT must never force a newly joined roster back to solo.
		if FORM_STATE_EVENTS[event] then Panel:RequestDataRefresh(true)
		elseif event:find("LFG_LIST_", 1, true) then Panel:Refresh(true)
		else Panel:OnActivityAttention(event) end
	end)
	service():AddListener(function(event, action)
		if event == "publication_blocked" then Panel:Result(false, action); return end
		if event == "publication_confirmed" and (action == "publish" or action == "update") then
			UI.PlayUISound("success")
		end
		-- Contact views have their own immediate listener. Discovery probes and
		-- heartbeats do not change the board's visible content.
		if event == "message" and action ~= "U" and action ~= "B" and action ~= "X" then return end
		Panel:RequestDataRefresh(event ~= "tick")
	end)
	self.initialized = true
	self:ApplyTabVisibility()
	frame:HookScript("OnShow", function() Panel:RequestLayoutRefresh() end)
	frame:HookScript("OnSizeChanged", function() Panel:RequestLayoutRefresh() end)
end
function Panel:RefreshListBackgroundStyles()
	local board = self.board
	if board then board.list:ForEachFrame(function(row) board:PaintRow(row) end) end
end

function Panel:Refresh(force)
	if not self.initialized then return end
	if self.layingOut or self.refreshing then self.refreshPending = true; return end
	force = force or (self.dataRequest and self.dataRequest.force)
	self:CancelDataRefresh()
	self:ApplyTabVisibility()
	if visible(self.frame) and self.layoutDirty and not self:Layout() then return end
	force = force or self.refreshPending
	self.refreshPending, self.refreshing = nil, true
	local ok, reason = pcall(self.Paint, self, force)
	self.refreshing = nil
	if not ok then
		self.lastPaint, self.lastActivityRecord, self.lastActivityWaiting = nil, nil, nil
		error(reason, 0)
	end
	if self.refreshPending or self.layoutDirty then self:RequestLayoutRefresh() end
end

function Panel:RefreshChatCatalog()
	local s = service()
	self.activityNames, self.classNames, self.specNames, self.specIcons = {}, {}, {}, {}
	self.activityOptions = s:GetActivities()
	for _, entry in ipairs(self.activityOptions) do
		self.activityNames[entry.id] = entry.name
	end
	for _, class in ipairs(GF.RaidRecruitmentNeeds:GetCatalog()) do
		self.classNames[class.classID] = class.name
		for _, spec in ipairs(class.specs) do self.specNames[spec.id], self.specIcons[spec.id] = spec.name, spec.icon end
	end
end

function Panel:Paint(force)
	if self.historyOnly then
		self:RefreshChatCatalog()
		self.contactCard.title:SetText(label("CHAT_HISTORY")); self.contactCard.header:RefreshTitleFit()
		self:StopActivityBadge()
		self.chat:Refresh(force)
		return
	end
	local s = service()
	if not s.pendingRequest and not s.pendingAt then self.pendingAction = nil end
	local confirmed, memberView, activityState = s:GetActivityView()
	local t = s.transport
	if memberView and activityState ~= "loading" or not memberView
		and (t.state == "error" or t.state == "disconnected" or t.echoAt) then self.retrying = nil end
	if not confirmed or memberView then self.activityAttention = nil end
	if not visible(self.frame) then return end
	local seek = self.tabID == GF.TAB_RAID_SEEK
	local waiting = s.pendingRequest ~= nil or s.pendingAt ~= nil or s.memberDataWaitAt ~= nil
	local queued = s:IsPublicationQueued()
	local shown = seek and confirmed or nil
	local activityStatusKey = s.memberDataWaitAt and "WAITING_MEMBER_DATA" or s.restoring and "RESTORING" or queued and "PUBLISH_QUEUED" or waiting and (shown and "" or "PUBLISHING")
		or shown and (memberView and "LEADER_PUBLISHED" or "LIVE") or ""
	local now = s:Now()
	local connection = tostring(t.state) .. ":" .. tostring(t.reason) .. ":" .. tostring(t.echoAt ~= nil)
	local changed = shown ~= self.lastActivityRecord or waiting ~= self.lastActivityWaiting or queued ~= self.lastActivityQueued
		or s.restoring ~= self.lastActivityRestoring or s.recoveryNotice ~= self.lastRecoveryNotice
		or memberView ~= self.activityMemberView or activityState ~= self.activityViewState
		or connection ~= self.lastConnection
	self.activityMemberView, self.activityViewState = memberView, activityState
	if not force and not changed and self.lastPaint and now - self.lastPaint < 1 then
		self:RefreshActivityBadge(shown ~= nil, waiting and self.pendingAction == "UPDATE")
		return
	end
	self:RefreshChatCatalog()
	for _, value in ipairs(self.captions) do value:SetText(label(value.localeKey)) end
	local publishRecord, publishReason
	if seek then
		publishRecord, publishReason = s:BuildRecord()
		self.mode:SetText(label(s:SyncDraftMode():upper()))
		self:RefreshSpecChoices()
	end
	for _, value in ipairs({ self.form, self.activityCard, self.contactCard }) do value.header:RefreshTitleFit() end
	for _, value in ipairs(self.buttons) do value:SetText(label(value.localeKey)) end
	self.publish.localeKey = s.current and "UPDATE" or "PUBLISH"
	UI.SetButtonPendingSpinner(self.publish, seek and waiting)
	if not (seek and waiting) then self.publish:SetText(label(self.publish.localeKey)) end
	local failed = t.state == "error" or t.state == "disconnected" or s.lastError ~= nil
	local preparing = not failed and (t.state == "joining" or not t.echoAt)
	local finding = s:IsQuerying()
	local message = self.messageAt and now - self.messageAt < 8 and self.message
	local errorKey = s.recoveryNotice or (t.state == "error" and t.reason or s.lastError)
	if seek and memberView and s.partySync and s.partySync.started then
		-- The member's form has an independent PARTY connection. A failed or
		-- unopened public board channel does not make this activity unavailable.
		local unavailable = activityState == "unavailable"
		self:RefreshFeedback(unavailable and label("PARTY_ACTIVITY_UNAVAILABLE")
			or activityState == "loading" and label(self.retrying and "PARTY_ACTIVITY_RETRYING" or "PARTY_ACTIVITY_LOADING") or nil,
			unavailable, seek)
	else
		self:RefreshFeedback(t.state == "error" and channelErrorText(t.reason)
			or errorKey and errorText(errorKey)
			or s.memberDataWaitAt and label("WAITING_MEMBER_DATA")
			or message or failed and channelErrorText(t.reason or "channel_lost")
			or preparing and label(self.retrying and "CHANNEL_RETRYING" or "PREPARING") or nil, failed, seek,
			preparing and not errorKey and not message and not s.memberDataWaitAt)
	end
	if seek then
		local preferences, readOnly = self:RefreshFormPreferences()
		local selected = #preferences.activityIDs
		local leaderPublished = readOnly and s:GetLeaderPublication() ~= nil
		local signature = tostring(readOnly) .. ":" .. tostring(leaderPublished) .. ":" .. tostring(activityState)
			.. ":" .. table.concat(preferences.activityIDs, ",")
		for _, entry in ipairs(self.activityOptions) do signature = signature .. ":" .. entry.id .. ":" .. entry.name end
		if signature ~= self.formSelectionSignature then
			self.formSelectionSignature = signature
			if self.activities.GenerateMenu then self.activities:GenerateMenu() end
		end
		self.activities:OverrideText(selected == 0 and label("CHOOSE_RAID") or selected == 1 and activityNames(preferences.activityIDs)
			or string.format(label("CHOSEN_FMT"), selected))
		local group = s.adapter.Group()
		local party = group.grouped and not group.raid and not group.instance
		local choices, specsReadOnly = s:GetPartySpecChoices()
		local selectedMembers, specSignature = 0, { tostring(specsReadOnly), tostring(leaderPublished), tostring(activityState) }
		for _, member in ipairs(choices) do
			if member.hasSelection then selectedMembers = selectedMembers + 1 end
			specSignature[#specSignature + 1] = member.name .. ":" .. member.classID .. ":" .. table.concat(member.specIDs, ",")
		end
		specSignature = table.concat(specSignature, "|")
		if specSignature ~= self.partySpecSignature then
			self.partySpecSignature = specSignature
			if self.partyRoles.GenerateMenu then self.partyRoles:GenerateMenu() end
		end
		-- Editable drafts include unreadable roster members; read-only counts
		-- describe the exact published roster that supplies the menu choices.
		local totalMembers = specsReadOnly and #choices or party and (group.count or 0) + 1 or 0
		self.partyRoles:OverrideText(selectedMembers > 0
			and string.format(label("PARTY_SPECS_SELECTED_FMT"), selectedMembers, totalMembers) or label("PARTY_SPECS"))
		self.partyRoles:SetEnabled(party)
		self.notePlaceholder:SetText(label("NOTE_PLACEHOLDER"))
		-- Before the leader publishes, show the example as display-only text.
		-- An explicitly empty published note remains empty rather than an example.
		self.notePlaceholder:SetShown(self.note:GetText() == "" and (not readOnly or s:GetLeaderPublication() == nil))
		-- Keep roster rejections clickable so the shared toast can explain the block.
		self.publish:SetEnabled((publishRecord ~= nil or publishReason == "offline_member" or publishReason == "not_max_level") and not waiting)
		self:RefreshPublishTooltip(publishReason)
		self.stop:SetEnabled(s.current ~= nil or waiting)
		self.activityStatus:SetText(label(activityStatusKey))
		local statusColor = waiting and S.accentColor or shown and S.liveColor or S.mutedColor
		self.activityStatus:SetTextColor(unpack(statusColor))
		if GF.Font and GF.Font.SetFitWidth then
			GF.Font.SetFitWidth(self.activityStatus, self.activityStatus:GetWidth(), S.activityStatusMinTextSize)
		end
		self:RefreshActivity(shown, waiting)
		refreshCenteredPrompt(self.contactEmptyGroup, self.contactEmptyTitle, self.contactEmpty,
			label("NO_CONTACTS"), label(s.current and "WAIT_CONTACTS" or "BEFORE_CONTACTS"))
		self.chat:Refresh(force)

	else
		self.board:SetFeedback(self.feedbackMessage or (finding or preparing) and label("FINDING"), failed, finding or preparing)
		self.board:Refresh(force)
		refreshCenteredPrompt(self.contactEmptyGroup, self.contactEmptyTitle, self.contactEmpty,
			label("BOARD_CHAT_EMPTY"), label("BOARD_CHAT_HINT"))
		self.chat:Refresh(force)
	end
	-- Commit the details before updating optional decorative animation.
	self.lastPaint, self.lastActivityRecord, self.lastActivityWaiting = now, shown, waiting
	self.lastConnection = connection
	self.lastActivityQueued = queued
	self.lastActivityRestoring, self.lastRecoveryNotice = s.restoring, s.recoveryNotice
	self:RefreshActivityBadge(shown ~= nil, waiting and self.pendingAction == "UPDATE")
end
function Panel:RevealPendingConversation()
	local key = self.pendingConversationKey
	local c = key and GF.RaidSeekingChatService:Get(key)
	local context = self.tabID == GF.TAB_RAID_SQUARE and "board" or "seeking"
	if not self.chat or not c or c.closed or c.hidden or c.context ~= context then return false end
	self.chat:Select(key, true)
	self.pendingConversationKey = nil
	return true
end

function Panel:ShowTab(tabID)
	self:CancelLayoutRefresh()
	local entering = not self.featureActive or self.tabID ~= tabID
	if entering then UI.CancelSmoothWheelScrolling(self.activityContent) end
	self.tabID = tabID
	self.chat:SetContext(tabID == GF.TAB_RAID_SQUARE and "board" or "seeking")
	self:RevealPendingConversation()
	self:ApplyTabVisibility()
	if not self.historyOnly then
		service():LoadDraft()
		self:RefreshFormPreferences()
	end
	self.featureActive = true
	self:Layout()
	self.frame:Show()
	if entering and not self.historyOnly then self:EnterFeature() else self:Refresh(true) end
	self:RequestLayoutRefresh()
end
function Panel:Hide()
	if self.frame then self.frame:Hide() end
end
