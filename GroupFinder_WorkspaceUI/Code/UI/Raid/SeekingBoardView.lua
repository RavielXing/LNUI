local _, GF = ...
GF = GF.GF or GF

local UI, P = GF.UI, GF.RaidSeekingProtocol
local S, C = GF.RAID_SEEKING_BOARD_STYLE, GF.RAID_SEEKING_STYLE
local View = {}
View.__index = View
GF.RaidSeekingBoardView = View

local ROLE_OPTIONS = { { name = "TANK", id = 1 }, { name = "HEALER", id = 2 }, { name = "DAMAGER", id = 4 } }
local function label(key) return (GF.L or {})["SEEK_" .. key] or (GF.L or {})[key] or key end
local function toggleChoice(selection, choices, id)
	local selected, all = {}, #choices > 0
	for _, option in ipairs(choices) do
		local checked = selection == nil or selection[option.id] == true
		if option.id == id then checked = not checked end
		if checked then selected[option.id] = true else all = false end
	end
	-- Keep an empty table as zero matches; nil represents all choices.
	if all then return nil end
	return selected
end
local function text(parent, normal)
	local value = UI.CreateFontString(parent, "OVERLAY", normal and "GameFontNormalSmall" or "GameFontHighlightSmall")
	value:SetJustifyH("LEFT"); value:SetJustifyV("MIDDLE"); value:SetWordWrap(false); value:SetMaxLines(1)
	return value
end
local function hint(owner, value)
	UI.BeginGameTooltip(owner, "ANCHOR_RIGHT"); GameTooltip:SetText(value, 1, 1, 1, 1, true); UI.ShowGameTooltip()
end
local function snapshot(record)
	return { key = record.key, revision = record.revision, session = record.session }
end
local function sameMenuMember(entry, target)
	return entry and target and not entry.detail and entry.recordKey == target.recordKey
		and entry.session == target.session and entry.revision == target.revision
		and entry.memberName == target.memberName
end

function View.Create(panel, card, helpers)
	local self = setmetatable({ panel = panel, card = card, helpers = helpers, expanded = {}, filters = {}, detailTransitions = {} }, View)
	self.service = GF.RaidSeekingService
	self.headerHost = CreateFrame("Frame", nil, card); self.headerHost:SetHeight(S.headerHeight)
	-- This card is opaque: keep the shared atlas above its own background.
	UI.InstallBrowseHeaderChrome(self.headerHost, {
		backgroundInsetLeft = GF.CARD_HEADER_STYLE.inset - S.inset, backgroundParent = self.headerHost,
	})
	self.columns = CreateFrame("Frame", nil, self.headerHost)
	self.columns:SetPoint("TOPLEFT"); self.columns:SetPoint("BOTTOMRIGHT")
	self.headerBar = GF.ColumnHeaderBar:Create(self.columns, {
		mode = "custom", getHeaderLabel = function(key) return label(key) end,
		resolveLayout = function(width) return self:ResolveColumns(width) end,
		updateHeader = function(header, key, _, layout, bar)
			local column = layout.byId[key]
			-- Native columns overlap by two pixels; align explicitly with our row cells.
			header:ClearAllPoints(); header:SetPoint("LEFT", bar.headers, "LEFT", column.x, 0)
			header:SetSize(column.width, S.headerHeight)
		end,
	})
	self.headerBar:SetAllPoints(self.columns)
	self.refresh = CreateFrame("Button", nil, card.header)
	self.refresh:SetSize(GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE, GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE)
	self.refresh:SetPoint("RIGHT", card.header, "RIGHT", GF.CARD_HEADER_STYLE.inset - S.inset, 0)
	self.refresh:SetFrameLevel(card.header:GetFrameLevel() + 1)
	card.header.titleReservedWidth = GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE + S.gap
	card.header.title:ClearAllPoints()
	card.header.title:SetPoint("LEFT", card.header.accent, "RIGHT", GF.CARD_HEADER_STYLE.titleGap, 0)
	card.header.title:SetPoint("RIGHT", self.refresh, "LEFT", -S.gap, 0)
	self.refresh:RegisterForClicks("LeftButtonUp"); self.refresh:SetMotionScriptsWhileDisabled(true)
	self.refresh.Icon = self.refresh:CreateTexture(nil, "OVERLAY")
	UI.SetRefreshIconAtlas(self.refresh.Icon)
	UI.SetHeaderRefreshIconState(self.refresh, GF.BUTTON_VISUAL_STATE.NORMAL, 0)
	self.refresh:SetScript("OnClick", function()
		if self.failed then panel:EnterFeature() else panel:Result(self.service:RequestQuery()) end
	end)
	-- Install shared click feedback after SetScript so it is not replaced.
	UI.InstallHeaderRefreshIconHoverGlow(self.refresh)
	self.refresh:HookScript("OnEnter", function()
		local value = label(self.failed and "RETRY" or "REFRESH")
		if self.message then value = value .. "\n" .. self.message end
		hint(self.refresh, value)
	end)
	self.refresh:HookScript("OnLeave", GameTooltip_Hide)
	self.refresh:HookScript("OnHide", function()
		self.refresh._gfHeaderRefreshPending = nil
		UI.SetButtonPendingSpinner(self.refresh, false)
	end)

	local footerStyle = GF.RAID_SEEKING_CHAT_STYLE
	self.footerBackground = CreateFrame("Frame", nil, card)
	self.footerBackground:SetPoint("BOTTOMLEFT", footerStyle.footerEdgeInset, footerStyle.footerEdgeInset)
	self.footerBackground:SetPoint("BOTTOMRIGHT", -footerStyle.footerEdgeInset, footerStyle.footerEdgeInset)
	self.footerBackground:SetHeight(footerStyle.footerHeight)
	UI.InstallBrowseControlBarChrome(self.footerBackground, {
		backgroundParent = self.footerBackground, leftInset = 0, rightInset = 0,
		topOffset = 0, height = footerStyle.footerHeight,
	})
	self.footer = CreateFrame("Frame", nil, card)
	self.footer:SetFrameLevel(self.footerBackground:GetFrameLevel() + 3)
	self.footer:SetPoint("TOPLEFT", self.footerBackground, "TOPLEFT", S.inset - footerStyle.footerEdgeInset, 0)
	self.footer:SetPoint("BOTTOMRIGHT", self.footerBackground, "BOTTOMRIGHT", footerStyle.footerEdgeInset - S.inset, 0)
	self:CreateFilters()
	self.list = UI.VirtualList.Create(card, { frameType = "Button", assignedKey = "key", smoothWheel = true, rowHeight = S.rowHeight,
		padding = { S.contentEdgeInset, S.contentEdgeInset, 0, 0, 0 },
		edgeFadeLength = S.scrollEdgeFade,
		extentCalculator = function(_, entry) return entry.height end,
		elementInitializer = function(row, entry) self:RenderRow(row, entry) end })
	local function clearSelectionOnBackground(_, mouseButton)
		if mouseButton == "LeftButton" then self:ClearSelection() end
	end
	-- Child rows and controls keep their own clicks; only exposed background clears selection.
	local scrollBox = self.list:GetScrollBox()
	scrollBox:EnableMouse(true)
	scrollBox:HookScript("OnMouseDown", clearSelectionOnBackground)
	card:EnableMouse(true)
	card:HookScript("OnMouseDown", clearSelectionOnBackground)
	self.empty = text(card)
	self.empty:SetPoint("CENTER", self.list:GetScrollBox(), "CENTER")
	self.empty:SetPoint("LEFT", self.list:GetScrollBox(), "LEFT", S.inset, 0)
	self.empty:SetPoint("RIGHT", self.list:GetScrollBox(), "RIGHT", -S.inset, 0)
	self.empty:SetJustifyH("CENTER"); self.empty:SetWordWrap(true); self.empty:SetMaxLines(0)
	UI.ApplyEmptyPromptFont(self.empty, "GameFontDisable")
	card:HookScript("OnSizeChanged", function() panel:RequestLayoutRefresh() end)
	card:HookScript("OnHide", function()
		self.memberMenuTarget = nil
		if self.loadingAnimation then self.loadingAnimation:Hide() end
		self.detailTransitions = {}
		self:UpdateDetailDriver()
		self.signature = nil
	end)
	local scrollBar = self.list:GetScrollBar()
	scrollBar:SetWidth(GF.PLAYER_MANAGEMENT_STYLE.scrollBarWidth)
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPRIGHT", self.headerHost, "BOTTOMRIGHT", 0, -S.scrollEdgeInset)
	scrollBar:SetPoint("BOTTOMRIGHT", self.footerBackground, "TOPRIGHT", footerStyle.footerEdgeInset - S.inset, S.scrollEdgeInset)
	self.list:BindDynamicScrollBar({
		gutter = S.scrollGutter,
		duration = GF.PLAYER_MANAGEMENT_STYLE.scrollBarDuration,
		overflowEpsilon = GF.PLAYER_MANAGEMENT_STYLE.scrollBarOverflowEpsilon,
		onInsetChanged = function(inset)
			self.scrollGutter = inset
			self:Layout()
			self.list:ForEachFrame(function(row) self:LayoutRow(row) end)
		end,
	})
	return self
end

function View:UpdateEmptyPrompt(isEmpty, filteredEmpty)
	local loading = isEmpty and self.busy and not self.failed or false
	local offsetY = loading and ((GF.BROWSE_LOADING_ICON_HEIGHT + GF.BROWSE_LOADING_TEXT_GAP) / 2) or 0
	local anchor = self.list:GetScrollBox()
	self.empty:ClearAllPoints()
	self.empty:SetPoint("CENTER", anchor, "CENTER", 0, offsetY)
	self.empty:SetPoint("LEFT", anchor, "LEFT", S.inset, offsetY)
	self.empty:SetPoint("RIGHT", anchor, "RIGHT", -S.inset, offsetY)
	self.empty:SetText(self.failed and self.message or label(self.failed and "LOAD_FAILED" or self.busy and "FINDING"
		or filteredEmpty and "NO_MATCHES" or "EMPTY"))
	self.empty:SetShown(isEmpty)
	if loading and not self.loadingAnimation then
		self.loadingAnimation = UI.CreateTeamUpLoadingAnimation(self.card)
		self.loadingAnimation:SetPoint("TOP", self.empty, "BOTTOM", 0, -GF.BROWSE_LOADING_TEXT_GAP)
	end
	if self.loadingAnimation then self.loadingAnimation:SetShown(loading) end
end

function View:SetSpecFilter(selected)
	if not self.card:IsShown() then return end
	local needs = GF.RaidRecruitmentNeeds
	selected = needs:CopySelection(selected)
	local all, total = true, 0
	for _, class in ipairs(needs:GetCatalog()) do
		for _, spec in ipairs(class.specs) do
			total = total + 1
			all = all and selected[spec.id] == true
		end
	end
	-- nil means unrestricted, including players whose spec is still unknown.
	-- An explicit empty selection matches nobody, rather than resetting the filter.
	if all and total > 0 then selected = nil end
	self.panel.filters.specIDs = selected
	self.panel.filters.classID, self.panel.filters.specID = nil, nil
	self.signature = nil
	self:Refresh(true)
end

function View:BuildSpecMenu(owner, root)
	owner:SetMenuAnchor(AnchorUtil.CreateAnchor("BOTTOMLEFT", owner, "TOPLEFT", 0, S.gap))
	local description = root:CreateFrame()
	description:AddInitializer(function(frame, _, menu)
		local needs = GF.RaidRecruitmentNeeds
		local selector = self.memberSelector
		if not selector then
			selector = UI.ClassSpecSelector:Create(self.card, {
				titleKey = "SEEK_BOARD_REQUIRED_SPECS",
				emptySelectionHintKey = "SEEK_BOARD_NO_SPECS",
				getSelection = function() return needs:ResolveSelection(self.panel.filters.specIDs) end,
				setSelected = function(specID, selected)
					if not needs:IsAvailableSpec(specID) then return end
					local selection = needs:ResolveSelection(self.panel.filters.specIDs)
					selection[specID] = selected and true or nil
					self:SetSpecFilter(selection)
				end,
				toggleRole = function(role)
					local selection = self.panel.filters.specIDs
					local count = needs:GetRoleCounts(selection)[role]
					if count and count.total > 0 then
						self:SetSpecFilter(needs:SetRoleSelected(selection, role, count.selected == 0))
					end
				end,
				isEnabled = function() return self.card:IsShown() and owner:IsEnabled() end,
			})
			self.memberSelector = selector
		end
		-- Own the selector frames ourselves; the native menu owns its pooled
		-- host, full-content layout, screen clamping and menu dismissal.
		selector.frame:Hide()
		selector.frame:SetParent(frame)
		selector.frame:SetFrameLevel(frame:GetFrameLevel() + 3)
		local scale = owner:GetEffectiveScale() / menu:GetEffectiveScale()
		selector.frame:SetScale(scale)
		selector.frame:ClearAllPoints(); selector.frame:SetPoint("TOPLEFT")
		selector.frame:Show()
		local height = selector:Layout(S.specMenuWidth)
		return S.specMenuWidth * scale, height * scale
	end)
	description:AddResetter(function(frame)
		-- Native scrolling temporarily hides the host during layout. Detach only
		-- when its description is discarded, before the compositor pools it.
		local content = self.memberSelector and self.memberSelector.frame
		if content and content:GetParent() == frame then
			content:Hide()
			content:ClearAllPoints()
			content:SetParent(self.card)
		end
	end)
end

function View:CreateFilters()
	local function choose(callback)
		return function()
			callback(); self.signature = nil; self:Refresh(true)
			return MenuResponse.Refresh
		end
	end
	for _, key in ipairs({ "activityID", "member", "role" }) do
		local control = UI.CreateDropdownButton(self.footer)
		self.filters[key] = control
		control:SetupMenu(function(owner, root)
			-- Show the entire class/spec table; only text menus need a scroll cap.
			if key ~= "member" then root:SetScrollMode(S.filterMenuHeight) end
			if key == "activityID" then
				root:CreateButton(label("SELECT_ALL_TARGETS"), choose(function() self.panel.filters.activityIDs = nil end))
				for _, item in ipairs(self.service:GetActivities()) do
					local id = item.id
					root:CreateCheckbox(item.name, function()
						local selected = self.panel.filters.activityIDs
						return selected == nil or selected[id] == true
					end, choose(function()
						self.panel.filters.activityIDs = toggleChoice(self.panel.filters.activityIDs, self.service:GetActivities(), id)
					end))
				end
				root:CreateButton(label("CLEAR_TARGETS"), choose(function() self.panel.filters.activityIDs = {} end))
			elseif key == "member" then
				self:BuildSpecMenu(owner, root)
			else
				for _, option in ipairs(ROLE_OPTIONS) do
					local id = option.id
					root:CreateCheckbox(label(option.name), function()
						local selected = self.panel.filters.roles
						return selected == nil or selected[id] == true
					end, choose(function()
						self.panel.filters.roles = toggleChoice(self.panel.filters.roles, ROLE_OPTIONS, id)
					end))
				end
			end
		end)
	end
	self.reset = UI.CreatePanelButton(self.footer, label("BOARD_RESET"), S.resetWidth)
	self.reset:SetScript("OnClick", choose(function() self.panel.filters = {} end))
end

function View:SetFeedback(message, failed, busy)
	self.failed, self.busy, self.message = failed, busy, message
	local pending = busy and not failed or false
	self.refresh._gfHeaderRefreshPending = pending or nil
	self.refresh:SetEnabled(not pending)
	UI.SetButtonPendingSpinner(self.refresh, pending, GF.BROWSE_HEADER_REFRESH_PENDING_SPINNER_SIZE)
	self.refresh.Icon:SetShown(not pending)
	UI.SetHeaderRefreshIconState(self.refresh, GF.BUTTON_VISUAL_STATE.NORMAL)
end

function View:ResolveColumns(width)
	local fixed = 0
	for _, column in ipairs(S.columns) do fixed = fixed + (column.width or 0) end
	local flexible = math.max(0, width - fixed)
	local layout = { active = {}, byId = {}, headerLayout = {} }
	self.layout = {}
	local x = 0
	for index, column in ipairs(S.columns) do
		local columnWidth = column.width or flexible * column.weight
		self.layout[index] = { x = x, width = columnWidth }
		layout.active[index], layout.byId[column.key] = column.key, self.layout[index]
		layout.headerLayout[index] = { width = columnWidth }
		x = x + columnWidth
	end
	return layout
end

function View:Layout()
	local card = self.card
	local gutter = self.scrollGutter or 0
	card.header:RefreshTitleFit()
	local headerInset = GF.CARD_HEADER_STYLE.inset
	self.headerHost:ClearAllPoints()
	self.headerHost:SetPoint("TOPLEFT", card.header, "BOTTOMLEFT", S.inset - headerInset, -S.gap)
	self.headerHost:SetPoint("TOPRIGHT", card.header, "BOTTOMRIGHT", headerInset - S.inset, -S.gap)
	self.columns:ClearAllPoints()
	self.columns:SetPoint("TOPLEFT"); self.columns:SetPoint("BOTTOMRIGHT", -gutter, 0)
	self.list:ClearAllPoints()
	self.list:SetPoint("TOPLEFT", self.columns, "BOTTOMLEFT", 0, -S.scrollEdgeInset)
	self.list:SetPoint("BOTTOMRIGHT", self.footerBackground, "TOPRIGHT",
		GF.RAID_SEEKING_CHAT_STYLE.footerEdgeInset - S.inset - gutter, S.scrollEdgeInset)
	GF.ColumnHeaderBar:Layout(self.headerBar, self.columns:GetWidth())
	local available = math.max(1, self.footer:GetWidth() - S.resetWidth - S.gap * 3)
	local x = 0
	for index, key in ipairs({ "activityID", "member", "role" }) do
		local control = self.filters[key]
		control:ClearAllPoints(); control:SetPoint("LEFT", self.footer, "LEFT", x, 0)
		local filterWidth = available * ({ 0.40, 0.40, 0.20 })[index]
		control:SetSize(filterWidth, S.filterHeight); x = x + filterWidth + S.gap
	end
	self.reset:ClearAllPoints(); self.reset:SetPoint("RIGHT", self.footer, "RIGHT", 0, 0)
end

function View:Live(entry)
	local record = entry and self.service:GetLive(entry.recordKey)
	return record and record.session == entry.session and record.revision == entry.revision and record or nil
end

function View:LiveMember(entry)
	local record = self:Live(entry)
	local member = record and not entry.detail and record.members[entry.memberIndex]
	if member and member.name:lower() == entry.memberName:lower() then return record, member end
end

function View:ShowMemberMenu(row)
	local record, member = self:LiveMember(row.entry)
	if not record or not self.card:IsShown() or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	-- Freeze the character, not the pooled row or the group's publisher.
	local target = { recordKey = record.key, revision = record.revision,
		session = record.session, memberName = member.name }
	local _, isSelf = self.service:GetMenuMember(target)
	if isSelf == nil then return end
	self.memberMenuTarget, row.memberMenuTarget = target, target
	self:HideMemberTooltip(row)
	local function current()
		if self.memberMenuTarget ~= target or row.memberMenuTarget ~= target
			or not self.card:IsShown() or not row:IsShown() then return nil end
		if not sameMenuMember(row.entry, target) then return nil end
		return self.service:GetMenuMember(target)
	end
	local menu = MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(P.Display(target.memberName:match("^[^-]+")))
		if not isSelf then
			root:CreateDivider()
			root:CreateTitle(label("MENU_INTERACT"))
			local function social(text, action)
				local button = root:CreateButton(text, function()
					if not current() then self.panel:Result(false, "expired"); return end
					local ok, reason = self.service:PerformMemberAction(target, action)
					if not ok then self.panel:Result(false, reason) end
				end)
				button:SetEnabled(function()
					return current() ~= nil and self.service:CanMemberAction(target, action) == true
				end)
			end
			local suggest = self.service:GetMemberInviteType(target) == "SUGGEST_INVITE"
			social(suggest and SUGGEST_INVITE or label("APPLICANT_INVITE"), suggest and "suggest_invite" or "invite")
			social(label("MENU_WHISPER"), "whisper")
			root:CreateDivider()
			root:CreateTitle(label("MENU_ENHANCEMENT"))
			social(label("STARRED_ADD_FRIEND"), "friend")
		end
		root:CreateDivider()
		root:CreateTitle(label("PLAYER_CONTEXT_MENU_TITLE"))
		local copy = root:CreateButton(label("APPLICANT_COPY_NAME"), function()
			if current() then UI.ShowCharacterNameCopyDialog(target.memberName) end
		end)
		copy:SetEnabled(function() return current() ~= nil end)
		if not isSelf then
			local value = label("APPLICANT_BLOCK_PLAYER")
			local red = RED_FONT_COLOR and RED_FONT_COLOR:WrapTextInColorCode(value) or "|cffff2020" .. value .. "|r"
			local function canBlock()
				return current() ~= nil and GF.BlacklistPresenter:CanAddManualPlayer()
			end
			local block = root:CreateButton(red, function()
				if not canBlock() then return end
				local live = current()
				local _, classFile = UI.ResolveClassIcon(live.classID)
				GF.BlacklistMenu:OpenManualAddDialog(target.memberName, {
					classFile = classFile, onAdded = function() self.panel:Refresh(true) end,
				})
			end)
			block:SetEnabled(canBlock)
		end
	end)
	if menu and InputUtil and InputUtil.AnchorRegionToCursor then
		-- Keep native cursor scaling and screen clamping; open above the click.
		InputUtil.AnchorRegionToCursor(menu, "BOTTOMLEFT")
	end
end

function View:Select(entry)
	local record = self:Live(entry)
	if not record then self.panel:Result(false, "expired"); return end
	self.panel.selectedKey, self.panel.selectedRevision, self.panel.selectedSession = record.key, record.revision, record.session
	self.list:ForEachFrame(function(row) self:PaintRow(row) end)
	return record
end

function View:ClearSelection()
	if self.expanded[self.panel.selectedKey] then return end
	self.panel.selectedKey, self.panel.selectedRevision, self.panel.selectedSession = nil, nil, nil
	self.list:ForEachFrame(function(row) self:PaintRow(row) end)
end

function View:Whisper(entry)
	local live, member = self:LiveMember(entry)
	if not live then self.panel:Result(false, "expired"); return end
	if member.name:lower() ~= live.owner:lower() then return end
	local record = self:Select(entry)
	if record then self.panel:Whisper() end
end

function View:ProfileRow(record, member)
	local data = self.service:BuildMemberTooltipData(member, { categoryID = GF.CAT_RAID })
	local roles = {}
	for index, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
		if P.HasRole(member.roles, 2 ^ (index - 1)) then roles[#roles + 1] = role end
	end
	data.role1, data.role2, data.role3 = roles[1], roles[2], roles[3]
	data.comment = P.Display(record.note ~= "" and record.note or label("NO_NOTE"))
	-- The shared presenter supports name-backed member data without an applicant ID.
	return { _layoutMemberData = data }
end

function View:Inspect(entry)
	local record, member = self:LiveMember(entry)
	if not record then self.panel:Result(false, "expired"); return end
	self:Select(entry)
	GF.ApplicantRosterPresenter.OpenMemberCharacterInfo(self:ProfileRow(record, member))
end

function View:Act(entry)
	local live, member = self:LiveMember(entry)
	if not live then self.panel:Result(false, "expired"); return end
	if member.name:lower() ~= live.owner:lower() then return end
	local record = self:Select(entry)
	if not record then return end
	if record.mode == "party" then
		local ok, reason, conversation = self.service:OfferListing(record.key, record.revision,
			self.service.adapter.ActiveActivity(), record.session)
		if ok and conversation then self.panel.chat:Select(conversation.key) end
		self.panel:Result(ok, reason, "OFFER_SENT")
		return
	end
	local ok, reason = self.service:Invite(record.key, record.revision, record.session)
	self.panel:Result(ok, reason, "INVITE_SENT")
end

function View:CanAct(record)
	return self.service:CanContact(record)
end

function View:HideMemberTooltip(row)
	if not GameTooltip then return end
	for _, owner in ipairs({ row, row.view, row.whisper, row.action }) do
		if GameTooltip:IsOwned(owner) then GameTooltip:Hide(); return end
	end
end

function View:ShowMemberTooltip(row)
	local record, member = self:LiveMember(row.entry)
	if not row:IsVisible() or not record or member ~= row.member then
		self:HideMemberTooltip(row)
		return
	end
	GF.ApplicantMemberBlock:ShowStandardTooltip(row, row.tooltipData)
end

function View:BuildDetail(record)
	local detail = snapshot(record)
	detail.key, detail.recordKey, detail.detail = record.key .. ":detail", record.key, true
	detail.progressGroups = self.service:GroupRequestedProgress(record.activityIDs, record.progress)
	local rows = math.ceil(#detail.progressGroups / 2)
	detail.fullHeight = S.detailTopPadding + S.detailBottomPadding
		+ rows * C.progressRowHeight + math.max(0, rows - 1) * C.progressRowGap
	local transition = self.detailTransitions[record.key]
	detail.reveal = transition and transition.progress or 1
	detail.height = math.max(1, detail.fullHeight * detail.reveal)
	return detail
end

function View:PaintDetailReveal(row)
	local entry = row.entry
	if not entry or not entry.detail then return end
	local reveal = entry.reveal
	row.progressHost:ClearAllPoints()
	row.progressHost:SetPoint("TOPLEFT", row.detailClip, "TOPLEFT", 0, S.detailSlideDistance * (1 - reveal))
	row.progressHost:SetSize(row:GetWidth(), entry.fullHeight)
	row.progressHost:SetAlpha(reveal)
	for _, progress in ipairs(row.progressRows) do
		progress:EnableMouse(reveal == 1)
		if reveal < 1 then GF.RaidSeekingProgressRow.HideTooltip(progress) end
	end
end

function View:RenderDetail(row, entry)
	row.gridWidth = row:GetWidth()
	local width = math.max(1, row:GetWidth() - S.detailInset * 2)
	for index, group in ipairs(entry.progressGroups) do
		local paired = index % 2 == 0 or index < #entry.progressGroups
		local cellWidth = paired and math.max(1, (width - S.detailColumnGap) / 2) or width
		local x = S.detailInset + (index % 2 == 0 and cellWidth + S.detailColumnGap or 0)
		local y = S.detailTopPadding + math.floor((index - 1) / 2) * (C.progressRowHeight + C.progressRowGap)
		local progress = GF.RaidSeekingProgressRow.Render(row.progressRows[index], group, row.progressHost,
			cellWidth, y, row.progressOptions)
		progress:ClearAllPoints(); progress:SetPoint("TOPLEFT", x, -y)
		row.progressRows[index] = progress
	end
	for index = #entry.progressGroups + 1, #row.progressRows do row.progressRows[index]:Hide() end
	self:PaintDetailReveal(row)
end

function View:UpdateDetailDriver()
	local active = next(self.detailTransitions) ~= nil and self.card:IsVisible()
	if active and not self.detailDriver then self.detailDriver = CreateFrame("Frame", nil, self.card) end
	if self.detailDriver then
		self.detailDriver:SetScript("OnUpdate", active and function(_, elapsed) self:TickDetails(elapsed) end or nil)
	end
end

function View:ToggleDetail(record)
	local key, previous = record.key, self.detailTransitions[record.key]
	local from = previous and previous.progress or (self.expanded[key] and 1 or 0)
	local target = self.expanded[key] and 0 or 1
	self.expanded[key] = target == 1 or nil
	self.detailTransitions[key] = { session = record.session, from = from, progress = from,
		target = target, elapsed = 0, duration = S.detailAnimationDuration * math.abs(target - from) }
	self:Refresh(true)
end

function View:RefreshAnimatedExtents()
	self.list:RefreshExtents()
	self.list:ForEachFrame(function(row)
		-- Newly acquired native rows receive their final anchors during layout.
		if row.entry.detail and row.gridWidth ~= row:GetWidth() then self:RenderDetail(row, row.entry)
		else self:PaintDetailReveal(row) end
	end)
end

function View:TickDetails(elapsed)
	if not self.card:IsVisible() then return end
	local completed = false
	for key, state in pairs(self.detailTransitions) do
		state.elapsed = state.elapsed + math.max(0, elapsed)
		local fraction = state.duration > 0 and math.min(1, state.elapsed / state.duration) or 1
		local eased = fraction * fraction * (3 - 2 * fraction)
		state.progress = state.from + (state.target - state.from) * eased
		for _, entry in ipairs(self.elements or {}) do
			if entry.detail and entry.recordKey == key then
				entry.reveal = state.progress
				entry.height = math.max(1, entry.fullHeight * state.progress)
			end
		end
		if fraction == 1 then self.detailTransitions[key] = nil; completed = true end
	end
	self:RefreshAnimatedExtents()
	if completed then self:Refresh(true) end
	self:UpdateDetailDriver()
end

function View:RenderIcons(row, member, expanded)
	local _, classFile = UI.ResolveClassIcon(member.classID)
	local ids = P.GetSpecIDs(member)
	local count = math.max(1, #ids)
	for index = 1, math.max(count, #row.specIcons) do
		local icon = row.specIcons[index]
		if not icon then icon = row:CreateTexture(nil, "ARTWORK"); row.specIcons[index] = icon end
		if not expanded and index <= count then
			local column = self.layout[2]
			icon:ClearAllPoints(); icon:SetPoint("CENTER", row, "LEFT", column.x + column.width / 2
				+ (index - (count + 1) / 2) * (S.iconSize + S.iconGap), GF.LIST_ROW_STYLE.contentOffsetY)
			UI.SetSpecializationIcon(icon, self.panel.specIcons[ids[index]] or C.memberUnknownIcon, {
				size = S.iconSize * GF.LIST_SPECIALIZATION_ICON_SCALE, outerSize = S.iconSize,
				ringStyle = GF.CLASS_SPECIALIZATION_RING_STYLE, classFile = classFile,
			})
		else UI.ClearSpecializationIcon(icon) end
	end
	local roles = {}
	for index, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
		if P.HasRole(member.roles, 2 ^ (index - 1)) then roles[#roles + 1] = role end
	end
	local slots = math.max(1, #roles)
	for index = 1, 3 do
		local icon = row.roleIcons[index]
		if not icon then icon = row:CreateTexture(nil, "ARTWORK"); row.roleIcons[index] = icon end
		icon:SetShown(not expanded and index <= slots)
		if not expanded and index <= slots then
			local column = self.layout[3]
			icon:ClearAllPoints(); icon:SetPoint("CENTER", row, "LEFT", column.x + column.width / 2
				+ (index - (slots + 1) / 2) * (S.roleIconSize + S.iconGap), GF.LIST_ROW_STYLE.contentOffsetY)
			local size = roles[index] and S.roleIconSize or S.iconSize
			icon:SetSize(size, size)
			if roles[index] then
				icon:SetAtlas(GF.ROLE_ICON_ATLAS[roles[index]])
			else
				icon:SetTexture(C.memberUnknownIcon); icon:SetTexCoord(0, 1, 0, 1)
			end
		end
	end
end

function View:PaintRow(row)
	local record = self:LiveMember(row.entry)
	if not record or not row.memberColor then
		for _, pieces in ipairs({ row.background, row.hoverPieces, row.selectedPieces }) do
			UI.SetRowBackgroundPiecesShown(pieces, false)
		end
		return
	end
	local mode = "full"
	if row.entry.memberCount > 1 then
		mode = row.entry.memberPosition == 1 and "top"
			or row.entry.memberPosition == row.entry.memberCount and "bottom" or "hidden"
	end
	UI.ApplyRowBackgroundPieces(row, row.background, {
		profile = GF.LIST_ROW_STYLE.background,
		mode = mode, state = "normal", defaultHeight = row.entry.height,
		alpha = GF.GetListBackgroundAlpha("normal"), vertexColor = GF.GetListBackgroundColor("normal"),
		desaturated = true, fallbackTexture = GF.ROW_BACKGROUND_FALLBACK_TEXTURE,
	})
	local selected = self.panel.selectedKey == record.key or self.expanded[record.key] == true
	for _, state in ipairs({ "hover", "selected" }) do
		local pieces = state == "hover" and row.hoverPieces or row.selectedPieces
		UI.ApplyRowBackgroundPieces(row, pieces, {
			profile = GF.LIST_ROW_STYLE.background,
			mode = state == "selected" and mode or "full", state = "normal", defaultHeight = row.entry.height,
			alpha = GF.BROWSE_ROW_SELECTED_ALPHA, vertexColor = GF.GetListBackgroundOverlayColor("normal", state),
			desaturated = true, fallbackTexture = GF.ROW_BACKGROUND_FALLBACK_TEXTURE,
		})
		UI.SetRowBackgroundPiecesShown(pieces, state == "selected" and selected and mode ~= "hidden"
			or state == "hover" and row.hovered and (not selected or row.entry.memberCount > 1))
	end
end

function View:SetRowHovered(row, hovered)
	row.hovered = hovered == true
	self:PaintRow(row)
end

-- Width animation only moves existing content; profile preparation and action
-- permissions remain part of normal data rendering, not each animation frame.
function View:LayoutRow(row)
	if row.entry.detail then self:RenderDetail(row, row.entry); return end
	local record, member = self:LiveMember(row.entry)
	if not record or not member then return end
	self:RenderIcons(row, member, false)
	for index, cell in ipairs(row.cells) do
		local column = self.layout[index]
		cell:ClearAllPoints(); cell:SetPoint("LEFT", column.x + S.rowInset, GF.LIST_ROW_STYLE.contentOffsetY)
		cell:SetSize(math.max(1, column.width - S.rowInset * 2), GF.LIST_ROW_STYLE.contentHeight)
		cell:SetJustifyH(index == 4 and "CENTER" or "LEFT")
	end
	local action = self.layout[6]
	UI.LayoutApplicantActionButtons(row, row.viewHolder, row.whisperHolder, row.actionHolder,
		action.x + action.width / 2, true)
end

function View:RenderRow(row, entry)
	if not row.cells then
		row.cells, row.specIcons, row.roleIcons = {}, {}, {}
		row.background = UI.CreateRowBackgroundPieces(row, "BACKGROUND", -2)
		row.hoverPieces = UI.CreateRowBackgroundPieces(row, "BORDER", -1)
		row.selectedPieces = UI.CreateRowBackgroundPieces(row, "BORDER", 0)
		for _, pieces in ipairs({ row.hoverPieces, row.selectedPieces }) do
			for _, piece in pairs(pieces) do piece:SetBlendMode("ADD") end
		end
		for index = 1, #S.columns - 1 do
			local cell = text(row)
			cell._gfFontSizeOverride = GF.LIST_ROW_STYLE.textSize
			if GF.Font and GF.Font.ApplyToFontString then GF.Font.ApplyToFontString(cell, "GameFontHighlightSmall") end
			row.cells[index] = cell
		end
		row.detailClip = CreateFrame("Frame", nil, row)
		row.detailClip:SetAllPoints(row); row.detailClip:SetClipsChildren(true)
		row.progressHost = CreateFrame("Frame", nil, row.detailClip)
		row.progressRows = {}
		row.progressOptions = {
			canShowTooltip = function() return row.entry.reveal == 1 and self:Live(row.entry) ~= nil end,
			getBosses = function(entry) return self.service:ProgressBosses(entry.activityID, entry) end,
		}
		row.viewHolder, row.view = UI.CreateApplicantViewButton(row)
		row.whisperHolder, row.whisper = UI.CreateApplicantWhisperButton(row)
		row.actionHolder, row.action = UI.CreateApplicantInviteButton(row)
		row.view:SetScript("OnClick", function() self:Inspect(row.entry) end)
		row.whisper:SetScript("OnClick", function() self:Whisper(row.entry) end)
		row.action:SetScript("OnClick", function() self:Act(row.entry) end)
		for _, button in ipairs({ row.view, row.whisper, row.action }) do
			button:HookScript("OnEnter", function()
				self:SetRowHovered(row, true)
				local record = self:LiveMember(row.entry)
				if not record or not button:IsVisible() then return end
				local value = button == row.view and GF.L.APPLICANT_QUERY_CHARACTER
					or button == row.whisper and label("WHISPER") or label("BOARD_INVITE")
				if button == row.action and record.mode == "party" then
					UI.BeginGameTooltipAbove(button)
					GameTooltip:ClearLines()
					GameTooltip:SetText(label("BOARD_OFFER"), UI.TOOLTIP_GOLD_R, UI.TOOLTIP_GOLD_G, UI.TOOLTIP_GOLD_B, 1, true)
					local color = S.offerHintColor
					GameTooltip:AddLine(label("BOARD_OFFER_HINT"), color[1], color[2], color[3], true)
					UI.ShowGameTooltip()
					return
				end
				UI.ShowSimpleTooltipAbove(button, value)
			end)
			button:HookScript("OnLeave", function() self:SetRowHovered(row, false); self:HideMemberTooltip(row) end)
		end
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnMouseDown", function(_, mouseButton)
			row.memberMenuPress = nil
			if mouseButton == "RightButton" and self:LiveMember(row.entry) then
				local entry = row.entry
				row.memberMenuPress = { recordKey = entry.recordKey, revision = entry.revision,
					session = entry.session, memberName = entry.memberName }
			end
		end)
		row:SetScript("OnClick", function(_, mouseButton)
			local pressed = row.memberMenuPress
			row.memberMenuPress = nil
			if mouseButton == "RightButton" then
				if sameMenuMember(row.entry, pressed) then self:ShowMemberMenu(row) end
				return
			end
			if not row.entry.detail and not self:LiveMember(row.entry) then return end
			local record = self:Select(row.entry)
			if record then self:ToggleDetail(record) end
		end)
		row:SetScript("OnEnter", function()
			self:SetRowHovered(row, true)
			self:ShowMemberTooltip(row)
		end)
		local function leave() self:SetRowHovered(row, false); self:HideMemberTooltip(row) end
		row:SetScript("OnLeave", leave)
		row:SetScript("OnHide", function()
			row.memberMenuTarget, row.memberMenuPress = nil, nil
			leave()
		end)
	end
	if not row.entry or row.entry.key ~= entry.key or row.entry.session ~= entry.session then
		self:HideMemberTooltip(row); row.hovered = false
	end
	row.entry = entry
	local record = self:Live(entry)
	local _, member = self:LiveMember(entry)
	if not record or (not entry.detail and not member) then
		row:SetHitRectInsets(0, 0, 0, 0)
		self:HideMemberTooltip(row)
		row.member, row.tooltipData = nil, nil
		row.detailClip:Hide()
		for _, progress in ipairs(row.progressRows) do progress:Hide() end
		for _, cell in ipairs(row.cells) do cell:Hide() end
		for _, icon in ipairs(row.specIcons) do UI.ClearSpecializationIcon(icon) end
		for _, icon in ipairs(row.roleIcons) do icon:Hide() end
		for _, holder in ipairs({ row.viewHolder, row.whisperHolder, row.actionHolder }) do holder:Hide() end
		for _, button in ipairs({ row.view, row.whisper, row.action }) do
			button:SetEnabled(false); button:RefreshApplicantActionState()
		end
		self:PaintRow(row)
		return
	end
	local expanded = entry.detail == true
	-- Keep member hover/clicks out of the operation column. Child action buttons
	-- retain their own hit rectangles, including for disabled-button tooltips.
	row:SetHitRectInsets(0, expanded and 0 or self.layout[6].width, 0, 0)
	local leader = member and member.name:lower() == record.owner:lower()
	if not expanded then for _, progress in ipairs(row.progressRows) do progress:Hide() end end
	for _, cell in ipairs(row.cells) do cell:SetShown(not expanded) end
	row.viewHolder:SetShown(not expanded)
	row.whisperHolder:SetShown(not expanded and leader)
	row.actionHolder:SetShown(not expanded and leader)
	row.detailClip:SetShown(expanded)
	row.progressOptions.difficultyValueFormat = label("BOARD_DIFFICULTY_PROGRESS_FMT")
	if expanded then
		self:RenderIcons(row, {}, true)
		self:HideMemberTooltip(row)
		row.member, row.tooltipData = nil, nil
		self:RenderDetail(row, entry)
	else
		if row.member and row.member.name ~= member.name then self:HideMemberTooltip(row); row.hovered = false end
		row.member = member
		local profile = self:ProfileRow(record, member)
		row.tooltipData = profile._layoutMemberData
		GF.ApplicantRaidTooltip.Prepare(row.tooltipData)
		local values = { P.Display(member.name), "", "", member.itemLevel > 0 and string.format(C.memberItemLevelValueFormat, member.itemLevel) or label("UNKNOWN"),
			leader and P.Display(record.note ~= "" and record.note or label("NO_NOTE")) or "" }
		for index, cell in ipairs(row.cells) do cell:SetText(values[index]) end
		self:LayoutRow(row)
		local _, classFile = UI.ResolveClassIcon(member.classID)
		local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
		row.memberColor = color and { color.r, color.g, color.b, 1 } or C.mutedColor
		row.cells[1]:SetTextColor(unpack(row.memberColor))
		row.view:SetEnabled(GF.ApplicantRosterPresenter.CanOpenMemberCharacterInfo(profile))
		row.whisper:SetEnabled(leader and self.panel:CanWhisper(record)); row.action:SetEnabled(leader and self:CanAct(record))
		for _, button in ipairs({ row.view, row.whisper, row.action }) do button:RefreshApplicantActionState() end
		if GameTooltip and GameTooltip:IsShown() and GameTooltip:IsOwned(row) then self:ShowMemberTooltip(row) end
	end
	self:PaintRow(row)
end

function View:BuildEntries(records)
	local elements, signature, visibleKeys, totalHeight = {}, {}, {}, 0
	for _, record in ipairs(records) do
		visibleKeys[record.key] = true
		signature[#signature + 1] = record.key .. ":" .. record.session .. ":" .. record.revision
		local ordered = {}
		for index, member in ipairs(record.members) do
			if member.name:lower() == record.owner:lower() then table.insert(ordered, 1, index)
			else ordered[#ordered + 1] = index end
		end
		for position, index in ipairs(ordered) do
			local member, entry = record.members[index], snapshot(record)
			local leader = member.name:lower() == record.owner:lower()
			entry.key = leader and record.key or record.key .. ":member:" .. member.name:lower()
			entry.recordKey, entry.height = record.key, S.rowHeight
			entry.memberName, entry.memberIndex = member.name, index
			entry.memberPosition, entry.memberCount = position, #ordered
			elements[#elements + 1] = entry
			totalHeight = totalHeight + entry.height
			signature[#signature + 1] = entry.key .. ":" .. index
		end
		if self.expanded[record.key] or self.detailTransitions[record.key] then
			local detail = self:BuildDetail(record)
			elements[#elements + 1] = detail
			signature[#signature + 1] = "detail:" .. detail.fullHeight
			for _, group in ipairs(detail.progressGroups) do
				signature[#signature + 1] = group.key .. ":" .. (group.activityGroupName or group.name) .. ":" .. tostring(group.texture)
				if group.texCoords then signature[#signature + 1] = table.concat(group.texCoords, ":") end
				for _, difficulty in ipairs(group.difficulties) do
					signature[#signature + 1] = tostring(difficulty.activityID) .. ":" .. tostring(difficulty.name) .. ":" .. tostring(difficulty.activityName)
						.. ":" .. tostring(difficulty.done) .. "/" .. tostring(difficulty.total)
					signature[#signature + 1] = P.BossData(difficulty) or "unknown-bosses"
				end
			end
			totalHeight = totalHeight + detail.height
		end
	end
	return elements, table.concat(signature, "|"), visibleKeys, totalHeight
end

function View:Refresh(force)
	if not self.card:IsShown() then return end
	if GF.RaidRecruitmentPolicy then GF.RaidRecruitmentPolicy:ApplyBoardDefaults(self) end
	local filters = self.panel.filters
	-- Only exposed filters can affect the new board; retired controls leave no hidden predicates.
	filters.mode, filters.maxMembers, filters.query = nil, nil, nil
	filters.classID, filters.specID = nil, nil
	if filters.activityID and filters.activityIDs == nil then filters.activityIDs = { [filters.activityID] = true } end
	if filters.role and filters.roles == nil then filters.roles = { [filters.role] = true } end
	filters.activityID, filters.role = nil, nil
	local activities = label("ALL_ACTIVITIES")
	if filters.activityIDs ~= nil then
		local count, only = 0, nil
		for _, option in ipairs(self.service:GetActivities()) do
			if filters.activityIDs[option.id] then count, only = count + 1, option.name end
		end
		activities = count == 0 and label("BOARD_NO_ACTIVITIES")
			or count == 1 and only or string.format(label("BOARD_SELECTED_ACTIVITIES"), count)
	end
	self.filters.activityID:OverrideText(activities)
	local member = label("BOARD_ALL_SPECS")
	if filters.specIDs ~= nil then
		local count, only = 0, nil
		for _, class in ipairs(GF.RaidRecruitmentNeeds:GetCatalog()) do
			for _, spec in ipairs(class.specs) do
				if filters.specIDs[spec.id] then count, only = count + 1, spec.name end
			end
		end
		member = count == 0 and label("BOARD_NO_SPECS")
			or count == 1 and only or string.format(label("BOARD_SELECTED_SPECS"), count)
	end
	self.filters.member:OverrideText(member)
	if self.memberSelector and self.memberSelector.frame:IsShown() then self.memberSelector:RefreshSelection() end
	local roles = label("ALL_ROLES")
	if filters.roles ~= nil then
		local names = {}
		for _, option in ipairs(ROLE_OPTIONS) do
			if filters.roles[option.id] then names[#names + 1] = label(option.name) end
		end
		roles = #names == 0 and label("BOARD_NO_ROLES")
			or string.format(label("BOARD_SELECTED_ROLES"), table.concat(names, label("BOARD_ROLE_SEPARATOR")))
	end
	self.filters.role:OverrideText(roles)
	self.reset:SetText(label("BOARD_RESET"))
	local records = self.service:List(filters)
	local sessions = {}
	for _, record in ipairs(records) do sessions[record.key] = record.session end
	for key, state in pairs(self.detailTransitions) do
		if sessions[key] ~= state.session then
			self.detailTransitions[key] = nil
			if sessions[key] then self.expanded[key] = nil end
		end
	end
	self:Layout()
	local elements, signature, visibleKeys = self:BuildEntries(records)
	local contacts, checked = {}, {}
	self.list:ForEachFrame(function(row)
		local key = row.entry and row.entry.recordKey
		if key and not checked[key] then
			checked[key] = true
			local record = self.service:GetLive(key)
			contacts[#contacts + 1] = key .. ":" .. tostring(self.service:CanContact(record))
				.. ":" .. tostring(self.panel:CanWhisper(record))
		end
	end)
	local contactSignature = table.concat(contacts, ":")
	local repaint = force or signature ~= self.signature or contactSignature ~= self.contactSignature
	self.contactSignature = contactSignature
	for key in pairs(self.expanded) do if not self.service:GetLive(key) then self.expanded[key] = nil end end
	if not visibleKeys[self.panel.selectedKey] then self.panel.selectedKey, self.panel.selectedRevision, self.panel.selectedSession = nil, nil, nil end
	local extentChanged = false
	if signature ~= self.signature then
		self.signature, self.elements = signature, elements
		self.list:SetElements(elements, { retainIdentity = true, retainScroll = true })
	else
		for index, entry in ipairs(self.elements or {}) do
			extentChanged = extentChanged or entry.height ~= elements[index].height
			entry.height, entry.reveal = elements[index].height, elements[index].reveal
		end
	end
	-- Heights change during reveal even when the provider identities stay stable.
	if extentChanged then self.list:RefreshExtents() end
	-- Maintenance still checks expiry, filters and permissions, but an unchanged
	-- board need not rebuild every visible member's icons, tooltip and controls.
	if repaint or extentChanged then self.list:ForEachFrame(function(row) self:RenderRow(row, row.entry) end) end
	local isEmpty = #records == 0
	local filteredEmpty = isEmpty and not self.busy and not self.failed
		and (filters.activityIDs ~= nil or filters.specIDs ~= nil or filters.roles ~= nil)
		and #self.service:List({}) > 0
	self:UpdateEmptyPrompt(isEmpty, filteredEmpty)
	self:UpdateDetailDriver()
end
