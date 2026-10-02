local _, GF = ...
GF = GF.GF or GF

local View = {}
View.__index = View
GF.RaidLeaderLookupView = View

local function text(key) return (GF.L or {})["SEEK_LOOKUP_" .. key] or key end

function View.Status(panel, target)
	if not GF.RaidLeaderLookup:IsCurrent(target) then return "EXPIRED" end
	if panel.awaitingGFSearch then return "SEARCHING" end
	if panel._searchFailed then return "FAILED" end
	if not GF.BrowsePresenter:IsCompletedSearchProjectionCurrent(panel) then return "READY" end
	return (panel._displayedResultCount or 0) > 0 and "FOUND" or "MISSING"
end

function View.EmptyStatus(panel, target)
	local status = View.Status(panel, target)
	return { text = text(status .. "_HINT"), loading = status == "SEARCHING" }
end

function View:SetActive(active)
	local panel, style = self.panel, GF.RAID_LEADER_LOOKUP_STYLE
	active = active == true
	self.frame:SetShown(active)
	if not active then self.retry:SetEnabled(false) end
	-- This decoration lives outside the content clip. Always set its own state;
	-- a hidden ancestor can suppress the frame's OnShow/OnHide notifications.
	self.backgroundFrame:SetShown(active and self.frame:IsVisible())
	if self.active ~= active then
		self.active = active
		panel.scrollList:SetContentBottomInset((GF.CONTENT_SCROLL_INSET_B or 0)
			+ (active and style.height + style.footerGap or 0))
		if GF.SubtitleBar then GF.SubtitleBar:ApplyBrowseInteractionState() end
	end
end

function View:Refresh()
	local panel, lookup = self.panel, GF.RaidLeaderLookup
	local target = lookup:GetTarget(panel.selection)
	local visible = self.frame:GetParent():IsVisible()
	local main = GF.MainFrame
	visible = visible and main:GetCurrentWorkspaceID() == GF.WORKSPACE_RAID
		and main:GetCurrentTabID() == GF.TAB_BROWSE
	self.driver:SetShown(target ~= nil and visible)
	if not target or not visible then
		self.label:SetText("")
		self:SetActive(false)
		return
	end
	local pendingRequest, reason = lookup:ShouldShowRequest(target)
	local status = View.Status(panel, target)
	if reason == "fulfilled" or status == "EXPIRED" then
		self.label:SetText("")
		self:SetActive(false)
		self.driver:Hide()
		panel:EndRaidLeaderLookup(reason == "fulfilled")
		if status == "EXPIRED" then panel:SetEmptyPrompt(text("EXPIRED_HINT")) end
		return
	end
	if self.locale ~= GF.L then
		self.locale = GF.L
		for key, button in pairs({ RETRY = self.retry, BACK = self.back }) do
			button:SetText(text(key))
		end
	end
	local name = GF.RaidSeekingProtocol.Display(target.name)
	local format = text(status)
	-- View Team also opens these controls for ordinary private conversations.
	-- Request-based lookups retain their existing fulfillment lifecycle.
	local showControls = target.applicationRequest == nil or pendingRequest
	local label = showControls and name:find("%S") and format:find("%S") and string.format(format, name) or ""
	self.label:SetText(label)
	self.retry:SetEnabled(lookup:IsCurrent(target)
		and panel:CanStartSelectionSearch(panel.selection, { source = "raidLeaderRetry" }) == true)
	self:SetActive(label:find("%S") ~= nil)
	if status == "FOUND" and panel._displayedResultCount == 1 then
		-- Virtual rows may materialize after SetElements; the short visible-only
		-- update also covers that case without applying or invoking a row click.
		panel:ForEachVisibleRow(function(row)
			if row.resultID and (row.resultID ~= panel.selectedResultID or row ~= panel._selectedRow) then
				GF.BrowsePresenter:SetSelectedRow(panel, row)
			end
		end)
	end
end

function View.Create(panel, parent)
	local self = setmetatable({ panel = panel }, View)
	local style, ui = GF.RAID_LEADER_LOOKUP_STYLE, GF.UI
	local frame = CreateFrame("Frame", nil, parent)
	self.frame = frame
	frame:Hide()
	frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", style.inset, style.footerGap)
	frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -style.inset, style.footerGap)
	frame:SetHeight(style.height)
	-- Like the native header chrome, escape the content clip to reach the nav rule.
	self.backgroundFrame = CreateFrame("Frame", nil, GF.MainFrame and GF.MainFrame.layoutHost or parent)
	self.backgroundFrame:Hide()
	self.backgroundFrame:SetFrameLevel(math.max(1, frame:GetFrameLevel() - 1))
	local subtitle = GF.SubtitleBar
	local footerBackground = subtitle.frame._gfBrowseControlBackgroundFrame
	if footerBackground then
		self.backgroundFrame:SetPoint("BOTTOMLEFT", footerBackground, "TOPLEFT", 0, style.footerGap)
	else
		self.backgroundFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT",
			-style.inset + GF.TABLE_HEADER_STYLE.backgroundInsetLeft, 0)
	end
	self.backgroundFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", style.inset, 0)
	self.backgroundFrame:SetHeight(style.height)
	self.background = self.backgroundFrame:CreateTexture(nil, "BACKGROUND")
	self.background:SetAtlas(style.backgroundAtlas)
	self.background:SetBlendMode("BLEND"); self.background:SetDesaturated(true)
	self.background:SetVertexColor(unpack(style.backgroundColor)); self.background:SetAllPoints()
	frame:HookScript("OnHide", function() self.backgroundFrame:Hide() end)
	-- The body ends at the footer artwork's top. Match the native button columns
	-- directly, including their widths and any subsequent horizontal relayout.
	local buttonOffset = subtitle.frame:GetHeight() / 2 + (GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
		- (GF.SUBTITLE_CONTROL_CENTER_OFFSET_Y or 0) + style.footerGap + style.height / 2
	local function button(key, lower, callback)
		local value = ui.CreatePanelButton(frame, text(key), lower:GetWidth())
		value:SetHeight(style.buttonHeight)
		value:SetPoint("LEFT", lower, "LEFT", 0, buttonOffset)
		value:SetPoint("RIGHT", lower, "RIGHT", 0, buttonOffset)
		value:SetScript("OnClick", callback)
		return value
	end
	self.back = button("BACK", subtitle.filterBtn, function() GF.FindGroupTab:ReturnToRaidLeaderChat() end)
	self.retry = button("RETRY", subtitle.signUpBtn, function() GF.FindGroupTab:DoSearch({ source = "raidLeaderRetry" }); self:Refresh() end)
	self.label = ui.CreateFontString(frame, "OVERLAY", "GameFontNormal")
	self.label:SetPoint("LEFT", frame, "LEFT", 0, 0)
	self.label:SetPoint("RIGHT", self.retry, "LEFT", -style.gap, 0)
	self.label:SetJustifyH("LEFT")
	self.label:SetWordWrap(false)
	self.label:SetMaxLines(1)
	-- Lookup selection may still need updates while its request strip is collapsed.
	-- Parent visibility and the target lifetime bound this existing half-second tick.
	self.driver = CreateFrame("Frame", nil, parent)
	local elapsed = 0
	self.driver:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed < 0.5 then return end
		elapsed = 0; self:Refresh()
	end)
	self.driver:Hide()
	parent:HookScript("OnShow", function() self:Refresh() end)
	parent:HookScript("OnHide", function()
		self.driver:Hide()
		self.label:SetText("")
		self:SetActive(false)
	end)
	return self
end
