local _, GF = ...
GF = GF.GF or GF

GF.MythicPlusCarpoolPage = GF.MythicPlusCarpoolPage or {}
local CarpoolPage = GF.MythicPlusCarpoolPage
local UI = GF.MythicPlusUI

function CarpoolPage:Create(parent)
	if self.page then
		return self.page
	end
	local page = {}
	self.page = page
	page.frame = CreateFrame("Frame", nil, parent)
	page.frame:SetAllPoints(parent)
	page.frame:Hide()
	page.groupClip = CreateFrame("Frame", nil, page.frame)
	page.groupClip:SetClipsChildren(true)
	page.groupHost = CreateFrame("Frame", nil, page.groupClip)
	page.carpoolClip = CreateFrame("Frame", nil, page.frame)
	page.carpoolClip:SetClipsChildren(true)
	page.carpoolHost = CreateFrame("Frame", nil, page.carpoolClip)
	page.group = GF.MythicPlusGroupPage:Create(page.groupHost)
	page.carpool = UI.CreateRosterPage(page.carpoolHost, {
		listKind = "carpool",
		nameLabelKey = "MPLUS_COL_WARBAND_CHARACTER",
		announceKeystone = true,
		emptyKey = "MPLUS_CARPOOL_EMPTY",
		lastLabelKey = "MPLUS_COL_WARBAND",
		sortColumn = "last",
		getElements = function()
			return page.carpoolElements or {}
		end,
		getLastText = function(data)
			return data and data.warbandSourceName
				or ((GF.L and GF.L.MPLUS_NO_INFO) or "无信息")
		end,
	})
	local style = GF.MYTHIC_PLUS_CARPOOL_SPLIT_STYLE
	page.groupHost:SetPoint("TOPLEFT", page.groupClip, "TOPLEFT", 0, 0)
	page.groupHost:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOM", -style.gap / 2, 0)
	page.groupClip:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 0, 0)
	page.carpoolClip:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT", 0, 0)
	page.carpoolHost:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT", 0, 0)
	page.divider = GF.MythicPlusCarpoolDivider.Create(page.frame, style.divider)
	local dividerLevel = page.frame:GetFrameLevel()
	for _, roster in ipairs({ page.group, page.carpool }) do
		local header = roster.header
		local background = header._gfBrowseHeaderBackgroundFrame or header
		dividerLevel = math.max(dividerLevel, background:GetFrameLevel())
	end
	page.divider:SetFrameLevel(dividerLevel + 1)

	function page:ApplyLayoutProgress(progress)
		self.progress = progress
		local width = math.max(0, self.frame:GetWidth() or 0)
		local half = math.max(0, (width - style.gap) / 2)
		-- 0: solo carpool; 1: equal panes; 2: grouped with no candidates.
		local reveal = math.min(1, progress)
		local collapse = math.max(0, progress - 1)
		local groupWidth = half + (width - half) * collapse
		local boundary = groupWidth * reveal
		local dividerAlpha = math.min(reveal, 1 - collapse)
		local carpoolLeft = boundary + style.gap * dividerAlpha
		self.groupHost:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMLEFT", groupWidth, 0)
		self.groupClip:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMLEFT", boundary, 0)
		self.carpoolClip:SetPoint("TOPLEFT", self.frame, "TOPLEFT", carpoolLeft, 0)
		self.carpoolHost:SetPoint("TOPLEFT", self.carpoolClip, "TOPLEFT", 0, 0)
		-- Clip the retiring pane instead of squeezing its seven columns to zero.
		self.carpoolHost:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT",
			math.max(0, half - (width - carpoolLeft)), 0)
		self.groupClip:SetAlpha(reveal)
		self.groupClip:SetShown(progress > 0)
		self.carpoolClip:SetAlpha(1 - collapse)
		self.carpoolClip:SetShown(progress < 2)
		if progress == 0 then self.group:Hide() end
		if progress == 2 then self.carpool:Hide() end
		self.divider:Layout(boundary + style.gap * dividerAlpha / 2)
		self.divider:SetAlpha(dividerAlpha)
		self.divider:SetShown(dividerAlpha > 0)
		local header = self.carpool.header
		local background = header and header._gfBrowseHeaderBackgroundFrame
		if background then
			-- Extend only the atlas across the pane gap; row / column insets stay
			-- unchanged. At full split its left edge meets the center divider.
			background:SetPoint("TOPLEFT", header, "TOPLEFT",
				-(UI.ROSTER_HEADER_INSET_LEFT + style.gap / 2) * dividerAlpha, 0)
		end
	end

	function page:StopLayoutTransition()
		self.transition = nil
		self.frame:SetScript("OnUpdate", nil)
	end

	local function tick(_, elapsed)
		local transition = page.transition
		if not transition then return end
		transition.elapsed = transition.elapsed + math.max(0, elapsed)
		local fraction = math.min(1, transition.elapsed / transition.duration)
		local eased = fraction * fraction * (3 - 2 * fraction)
		page:ApplyLayoutProgress(transition.from + (transition.target - transition.from) * eased)
		if fraction == 1 then
			page:StopLayoutTransition()
			page:ApplyLayoutProgress(transition.target)
		end
	end

	function page:Layout(immediate)
		local cache = GF.MythicPlusRosterCache
		local grouped = cache and cache.IsGrouped and cache:IsGrouped() == true or false
		local view = GF.MythicPlusCarpoolView
		-- This projection contains complete, atomically published peer batches.
		-- Use the same snapshot for layout and rows; partial packets cannot flash
		-- an empty right pane or discard the previous completed candidates.
		self.carpoolElements = view and view.GetListCharacters and view:GetListCharacters() or {}
		local target = grouped and (#self.carpoolElements > 0 and 1 or 2) or 0
		self.split = target == 1
		if self.targetProgress == target and not immediate then return end
		self.targetProgress = target
		local from = self.progress or target
		self:StopLayoutTransition()
		if not immediate and self.frame:IsVisible() and from ~= target then
			self.transition = { from = from, target = target, elapsed = 0,
				duration = style.transitionDuration * math.min(1, math.abs(target - from)) }
			self.frame:SetScript("OnUpdate", tick)
		else
			self:ApplyLayoutProgress(target)
		end
	end

	function page:RefreshLocale()
		self.group:RefreshLocale()
		self.carpool:RefreshLocale()
	end

	function page:RefreshView()
		self:Layout()
		if self.targetProgress > 0 or self.progress > 0 then
			self.group:RefreshView()
			self.group.frame:Show()
		end
		if self.targetProgress < 2 or self.progress < 2 then
			self.carpool:RefreshView()
			self.carpool.frame:Show()
		end
	end

	function page:Show()
		self:RefreshLocale()
		self:RefreshView()
		self.frame:Show()
	end

	function page:Hide()
		self.frame:Hide()
	end
	page.frame:SetScript("OnSizeChanged", function()
		page:ApplyLayoutProgress(page.progress or 0)
	end)
	page.frame:SetScript("OnHide", function()
		page:StopLayoutTransition()
		page:ApplyLayoutProgress(page.targetProgress or 0)
	end)
	page:Layout(true)
	page:RefreshLocale()
	return page
end
