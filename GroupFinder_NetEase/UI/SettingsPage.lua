local _, Addon = ...
local GF = Addon.GF
if not GF then return end
local Page = {}
GF.NetEaseSettingsPage = Page

function Page:Build(SP, context)
	if SP.pages.netease_newbie then return SP.pages.netease_newbie end
	local self = SP
	local Presenter = GF.SettingsPresenter
	local L = GF.L or {}
	local addSettingsRow = context.addSettingsRow
	local styleSettingsLabel = context.styleSettingsLabel
	local fitSettingsText = context.fitSettingsText
	local setSettingsWidgetEnabled = context.setSettingsWidgetEnabled
	local registerSettingsRefresher = context.registerSettingsRefresher
	local updateSettingsSectionHeights = context.updateSettingsSectionHeights
	local createSettingsPage = context.createSettingsPage
	local finishSettingsPage = context.finishSettingsPage
	local createSingleCardSettingsSection = context.createSingleCardSettingsSection
	local finishSingleCardSettingsSection = context.finishSingleCardSettingsSection
	local addCheckRow = context.addCheckRow
	local OPTIONS_CHECK_BUTTON_SIZE = context.OPTIONS_CHECK_BUTTON_SIZE
	local OPTIONS_ROW_HEIGHT = context.OPTIONS_ROW_HEIGHT
	local OPTIONS_CONTENT_TOP_OFFSET = context.OPTIONS_CONTENT_TOP_OFFSET
	local OPTIONS_CONTENT_BOTTOM_PADDING = context.OPTIONS_CONTENT_BOTTOM_PADDING
	local SECTION_GAP = context.SECTION_GAP
	local OPTIONS_VISUAL_GROUP_BODY_INSET_X = context.OPTIONS_VISUAL_GROUP_BODY_INSET_X
	local SETTINGS_INFO_CONTENT_INSET_X = 12
	local SETTINGS_INFO_CONTENT_INSET_TOP = 14
	local SETTINGS_INFO_CONTENT_INSET_BOTTOM = 14
	local SETTINGS_INFO_PARAGRAPH_GAP = 12
	local SETTINGS_INFO_ICON_SIZE = 16
	local SETTINGS_INFO_ICON_GAP = 6
	local SETTINGS_NOTICE_BULLET_ATLAS =
		"housing-dashboard-fillbar-pip-complete"

	local function splitSettingsParagraphs(text)
		local normalized = type(text) == "string" and text or ""
		normalized = normalized:gsub("\r\n", "\n")
		local paragraphs = {}
		for rawParagraph in (normalized .. "\n\n"):gmatch("(.-)\n\n") do
			local paragraph =
				rawParagraph:gsub("^%s+", ""):gsub("%s+$", "")
			if paragraph ~= "" then
				paragraphs[#paragraphs + 1] = paragraph
			end
		end
		return paragraphs
	end

	local function extractSettingsParagraphIcon(paragraph)
		local atlas, atlasBody = paragraph:match(
			"^|A:([^:]+):%d+:%d+[^|]*|a%s*(.*)$")
		if atlas then
			return atlas, atlasBody, true
		end
		local texture, textureBody = paragraph:match(
			"^|T([^:]+):%d+:%d+[^|]*|t%s*(.*)$")
		return texture, textureBody or paragraph, false
	end

	local function getSettingsParagraphFontHeight(body)
		local _, size = body:GetFont()
		size = tonumber(size) or 12
		return math.max(1, size)
	end

	local function ensureAdaptiveParagraphItem(row, index)
		row.items = row.items or {}
		local item = row.items[index]
		if item then
			return item
		end
		item = {}
		item.icon = row:CreateTexture(nil, "ARTWORK")
		item.body = GF.UI.CreateFontString(
			row, "OVERLAY", "GameFontHighlightSmall")
		item.body:SetJustifyH("LEFT")
		item.body:SetJustifyV("TOP")
		item.body:SetWordWrap(true)
		if item.body.SetMaxLines then
			item.body:SetMaxLines(0)
		end
		if item.body.SetNonSpaceWrap then
			item.body:SetNonSpaceWrap(true)
		end
		if item.body.SetSpacing then
			item.body:SetSpacing(2)
		end
		item.body:SetTextColor(0.82, 0.81, 0.77, 1)
		item.body._gfFontSizeOverride = 12
		styleSettingsLabel(item.body, "GameFontHighlightSmall")
		row.items[index] = item
		return item
	end

	local function layoutAdaptiveSettingsParagraph(row, text)
		if not row then
			return
		end
		row._gfParagraphText = type(text) == "string" and text or ""
		local paragraphs = splitSettingsParagraphs(row._gfParagraphText)
		local panel = row:GetParent()
		local owner = row._gfParagraphOwner
		local ownerWidth = owner and owner:GetWidth() or 0
		local width = math.max(
			0,
			ownerWidth - (OPTIONS_VISUAL_GROUP_BODY_INSET_X * 2))
		if width < 120 then
			width = panel and panel:GetWidth() or 0
		end
		if width < 120 then
			width = row:GetWidth() or 0
		end
		if width < 120 then
			width = 520
		end
		row._gfParagraphMeasuredWidth = width
		local contentWidth = math.max(
			120, width - (SETTINGS_INFO_CONTENT_INSET_X * 2))
		local cursor = SETTINGS_INFO_CONTENT_INSET_TOP

		for index, paragraph in ipairs(paragraphs) do
			local item = ensureAdaptiveParagraphItem(row, index)
			local icon, bodyText, iconIsAtlas
			local hasIcon = false
			if row._gfParagraphBulletAtlas then
				bodyText = paragraph
				item.icon:SetTexture(nil)
				item.icon:SetAtlas(
					row._gfParagraphBulletAtlas,
					TextureKitConstants
						and TextureKitConstants.IgnoreAtlasSize)
				hasIcon = true
			elseif row._gfParagraphLeadingTextures then
				icon, bodyText, iconIsAtlas =
					extractSettingsParagraphIcon(paragraph)
				if icon and icon ~= "" then
					if iconIsAtlas then
						item.icon:SetTexture(nil)
						item.icon:SetAtlas(
							icon,
							TextureKitConstants
								and TextureKitConstants.IgnoreAtlasSize)
					else
						item.icon:SetAtlas(nil)
						item.icon:SetTexture(icon)
					end
					hasIcon = true
				end
			else
				bodyText = paragraph
			end

			item.icon:ClearAllPoints()
			item.body:ClearAllPoints()
			local bodyWidth = contentWidth
			if hasIcon then
				bodyWidth = math.max(
					80,
					contentWidth
						- SETTINGS_INFO_ICON_SIZE
						- SETTINGS_INFO_ICON_GAP)
			end
			item.body:SetWidth(bodyWidth)
			item.body:SetText(bodyText or "")
			local bodyHeight = item.body:GetStringHeight() or 0
			bodyHeight = math.max(
				getSettingsParagraphFontHeight(item.body),
				math.ceil(bodyHeight))
			item.body:SetHeight(bodyHeight)

			local itemHeight = bodyHeight
			if hasIcon then
				local firstLineHeight =
					getSettingsParagraphFontHeight(item.body)
				local iconTop = math.max(
					0, (firstLineHeight - SETTINGS_INFO_ICON_SIZE) / 2)
				local textTop = math.max(
					0, (SETTINGS_INFO_ICON_SIZE - firstLineHeight) / 2)
				item.icon:SetSize(
					SETTINGS_INFO_ICON_SIZE,
					SETTINGS_INFO_ICON_SIZE)
				item.icon:SetPoint(
					"TOPLEFT",
					row,
					"TOPLEFT",
					SETTINGS_INFO_CONTENT_INSET_X,
					-(cursor + iconTop))
				item.body:SetPoint(
					"TOPLEFT",
					row,
					"TOPLEFT",
					SETTINGS_INFO_CONTENT_INSET_X
						+ SETTINGS_INFO_ICON_SIZE
						+ SETTINGS_INFO_ICON_GAP,
					-(cursor + textTop))
				itemHeight = math.max(
					iconTop + SETTINGS_INFO_ICON_SIZE,
					textTop + bodyHeight)
				item.icon:Show()
			else
				item.icon:Hide()
				item.body:SetPoint(
					"TOPLEFT",
					row,
					"TOPLEFT",
					SETTINGS_INFO_CONTENT_INSET_X,
					-cursor)
			end
			item.body:Show()
			cursor = cursor + itemHeight
			if index < #paragraphs then
				cursor = cursor + SETTINGS_INFO_PARAGRAPH_GAP
			end
		end

		for index = #paragraphs + 1, #(row.items or {}) do
			local item = row.items[index]
			item.icon:Hide()
			item.body:Hide()
		end

		local newHeight = math.max(
			1, math.ceil(cursor + SETTINGS_INFO_CONTENT_INSET_BOTTOM))
		local oldHeight = row._gfMeasuredHeight or 0
		row._gfMeasuredHeight = newHeight
		row:SetHeight(newHeight)
		local owner = row._gfParagraphOwner
		if owner then
			owner._gfRowOffset = math.max(
				0, (owner._gfRowOffset or 0) + newHeight - oldHeight)
			updateSettingsSectionHeights(owner)
			if oldHeight ~= newHeight
				and owner._gfAdaptiveHeightChanged
			then
				owner:_gfAdaptiveHeightChanged()
			end
		end
	end

	local function addAdaptiveSettingsParagraph(section, text, options)
		options = options or {}
		local panel = section.panel or section
		local offset = section._gfRowOffset or 0
		local row = CreateFrame("Frame", nil, panel)
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -offset)
		row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -offset)
		row:SetHeight(1)
		row._gfParagraphOwner = section
		row._gfParagraphBulletAtlas = options.bulletAtlas
		row._gfParagraphLeadingTextures =
			options.leadingTextures == true
		section._gfAdaptiveRows = section._gfAdaptiveRows or {}
		section._gfAdaptiveRows[#section._gfAdaptiveRows + 1] = row

		SP.LocaleBinding:BindText(
			row,
			text or "",
			function(target, localizedText)
				layoutAdaptiveSettingsParagraph(target, localizedText)
			end)
		row:HookScript("OnSizeChanged", function(owner, width)
			local previousWidth = owner._gfParagraphLayoutWidth or 0
			if math.abs((width or 0) - previousWidth) < 0.5 then
				return
			end
			owner._gfParagraphLayoutWidth = width or 0
			layoutAdaptiveSettingsParagraph(
				owner, owner._gfParagraphText)
		end)
		layoutAdaptiveSettingsParagraph(row, text or "")
		return row
	end

	local function installAdaptiveSettingsPageLayout(
		settingsPanel, page, entries)
		if not page or type(entries) ~= "table" then
			return
		end
		local layingOut = false
		local layoutPending = false
		local lastWidth = 0

		local function relayout()
			if layingOut then
				return
			end
			layingOut = true
			layoutPending = false
			local y = -OPTIONS_CONTENT_TOP_OFFSET
			for _, entry in ipairs(entries) do
				local section = entry.section
				local group = entry.group
				for _, row in ipairs(group._gfAdaptiveRows or {}) do
					layoutAdaptiveSettingsParagraph(
						row, row._gfParagraphText)
				end
				updateSettingsSectionHeights(group)
				local groupHeight =
					(group._gfHeightBase or 0)
					+ (group._gfRowOffset or 0)
					+ (group._gfHeightPaddingBottom or 0)
				section._gfRowOffset = groupHeight
				updateSettingsSectionHeights(section)
				section:ClearAllPoints()
				section:SetPoint(
					"TOPLEFT", page, "TOPLEFT", 0, y)
				section:SetPoint(
					"TOPRIGHT", page, "TOPRIGHT", 0, y)
				y = y - section:GetHeight() - SECTION_GAP
			end
			local height = math.max(
				1,
				-y - SECTION_GAP + OPTIONS_CONTENT_BOTTOM_PADDING)
			local changed = math.abs(
				(page._gfBodyH or 0) - height) >= 0.5
			page._gfBodyH = height
			page:SetHeight(height)
			layingOut = false
			if changed and settingsPanel.ScheduleUpdateScroll then
				settingsPanel:ScheduleUpdateScroll()
			end
		end

		local function scheduleRelayout()
			if layingOut or layoutPending then
				return
			end
			layoutPending = true
			if C_Timer and type(C_Timer.After) == "function" then
				C_Timer.After(0, relayout)
			else
				relayout()
			end
		end

		for _, entry in ipairs(entries) do
			entry.group._gfAdaptiveHeightChanged = scheduleRelayout
		end
		page:HookScript("OnSizeChanged", function(_, width)
			width = width or 0
			if math.abs(width - lastWidth) < 0.5 then
				return
			end
			lastWidth = width
			scheduleRelayout()
		end)
		page:HookScript("OnShow", scheduleRelayout)
		page._gfRelayoutAdaptiveContent = relayout
		scheduleRelayout()
	end

	local function addNetEaseAPIStatusRow(section, label, anchorControl)
		local row, control = addSettingsRow(section, label)
		local anchorWidth = anchorControl and anchorControl.GetWidth
			and anchorControl:GetWidth() or OPTIONS_CHECK_BUTTON_SIZE
		local statusGlyphCenterX = math.max(0, anchorWidth or 0) / 2
		local statusSpinner
		if GF.UI and type(GF.UI.CreatePendingSpinner) == "function" then
			statusSpinner = GF.UI.CreatePendingSpinner(control, 18)
			if statusSpinner then
				statusSpinner:SetPoint(
					"CENTER", control, "LEFT", statusGlyphCenterX, 0)
			end
		end
		local statusDot = control:CreateTexture(nil, "ARTWORK")
		statusDot:SetPoint(
			"CENTER", control, "LEFT", statusGlyphCenterX, 0)
		statusDot:SetSize(16, 16)
		statusDot:SetAtlas(
			SETTINGS_NOTICE_BULLET_ATLAS,
			TextureKitConstants
				and TextureKitConstants.IgnoreAtlasSize)
		statusDot:SetDesaturated(true)
		local statusRefreshButton = GF.UI.CreatePanelButton(
			control,
			(GF.L and GF.L.SET_NETEASE_API_STATUS_REFRESH) or "重新查询",
			GF.PANEL_BUTTON_STANDARD_W or 72)
		statusRefreshButton:ClearAllPoints()
		statusRefreshButton:SetPoint("RIGHT", control, "RIGHT", 0, 0)
		fitSettingsText(
			statusRefreshButton:GetFontString(),
			math.max(1, statusRefreshButton:GetWidth() - 12),
			8)
		SP.LocaleBinding:BindText(
			statusRefreshButton,
			(GF.L and GF.L.SET_NETEASE_API_STATUS_REFRESH) or "重新查询",
			nil,
			function(target)
				fitSettingsText(
					target:GetFontString(),
					math.max(1, target:GetWidth() - 12),
					8)
			end)

		local statusText = GF.UI.CreateFontString(
			control, "OVERLAY", "GameFontHighlightSmall")
		statusText:SetPoint("LEFT", statusDot, "RIGHT", 6, 0)
		statusText:SetPoint("RIGHT", statusRefreshButton, "LEFT", -12, 0)
		statusText:SetHeight(OPTIONS_ROW_HEIGHT)
		statusText:SetJustifyH("LEFT")
		statusText:SetJustifyV("MIDDLE")
		statusText:SetWordWrap(false)
		statusText._gfFontSizeOverride = 12
		styleSettingsLabel(statusText, "GameFontHighlightSmall")

		local function refreshStatus()
			local refreshProjection =
				Presenter:ProjectAction("neteaseAPIRefresh")
			setSettingsWidgetEnabled(
				statusRefreshButton, refreshProjection.enabled)
			local indicatorStatus = "fault"
			local apiStatusProjection
			local service = GF.NetEaseIdentityService
			if service
				and type(service.GetAPIStatusProjection) == "function"
			then
				local ok, value = pcall(
					service.GetAPIStatusProjection, service)
				if ok and type(value) == "table" then
					apiStatusProjection = value
					indicatorStatus = value.status or "fault"
				end
			elseif service
				and type(service.GetAPIStatusIndicator) == "function"
			then
				local ok, value = pcall(
					service.GetAPIStatusIndicator, service)
				indicatorStatus = ok and value or "fault"
			end
			local locale = GF.L or {}
			if indicatorStatus == "refreshing" then
				local remaining = apiStatusProjection
					and apiStatusProjection.remaining
				local phase = apiStatusProjection
					and apiStatusProjection.phase
				if not apiStatusProjection and service
					and type(service.GetAPIStatusCountdown) == "function"
				then
					local ok, seconds, currentPhase = pcall(
						service.GetAPIStatusCountdown, service)
					if ok then
						remaining, phase = seconds, currentPhase
					end
				end
				local countdownText =
					locale.SET_NETEASE_API_STATUS_QUERYING or "查询中…"
				if type(remaining) == "number" then
					local formatKey = phase == "connection"
						and "SET_NETEASE_API_STATUS_CONNECTING_FMT"
						or (phase == "delivery"
							and "SET_NETEASE_API_STATUS_SENDING_FMT"
							or "SET_NETEASE_API_STATUS_QUERYING_FMT")
					local countdownFormat = locale[formatKey]
						or (phase == "connection" and "连接中 %ds")
						or (phase == "delivery" and "发送中 %ds")
						or "查询中 %ds"
					local formatOK, formatted = pcall(
						string.format, countdownFormat, remaining)
					if formatOK then
						countdownText = formatted
					end
				end
				statusRefreshButton:SetText(countdownText)
				fitSettingsText(
					statusRefreshButton:GetFontString(),
					math.max(1, statusRefreshButton:GetWidth() - 12),
					8)
				statusDot:Hide()
				statusText:Hide()
				if statusSpinner and row:IsShown()
					and GF.UI
					and type(GF.UI.StartPendingSpinner) == "function"
				then
					GF.UI.StartPendingSpinner(statusSpinner, 18)
				end
				return
			end
			statusRefreshButton:SetText(
				locale.SET_NETEASE_API_STATUS_REFRESH or "重新查询")
			fitSettingsText(
				statusRefreshButton:GetFontString(),
				math.max(1, statusRefreshButton:GetWidth() - 12),
				8)
			if statusSpinner and GF.UI
				and type(GF.UI.StopPendingSpinner) == "function"
			then
				GF.UI.StopPendingSpinner(statusSpinner)
			end
			statusDot:Show()
			statusText:Show()
			local text
			local r, g, b
			if indicatorStatus == "disabled" then
				text = locale.SET_NETEASE_API_STATUS_DISABLED
					or "未启用"
				r, g, b = 0.55, 0.55, 0.55
			elseif indicatorStatus == "online" then
				text = locale.SET_NETEASE_API_STATUS_ONLINE
					or "当前在线"
				r, g, b = 0.20, 0.82, 0.38
			elseif indicatorStatus == "fault" then
				text = locale.SET_NETEASE_API_STATUS_FAULT
					or "网易 API 故障"
				r, g, b = 1.00, 0.24, 0.24
			else
				text = locale.SET_NETEASE_API_STATUS_OFFLINE
					or "网易 API 离线"
				r, g, b = 0.55, 0.55, 0.55
			end
			statusDot:SetDesaturated(true)
			statusDot:SetVertexColor(r, g, b, 1)
			statusText:SetTextColor(r, g, b, 1)
			statusText:SetText(text)
			fitSettingsText(
				statusText,
				math.max(20, statusText:GetWidth() or 0),
				8)
		end
		local statusTicker
		local function stopStatusTicker()
			if statusTicker and type(statusTicker.Cancel) == "function" then
				pcall(statusTicker.Cancel, statusTicker)
			end
			statusTicker = nil
		end
		local function startStatusTicker()
			if statusTicker or not row:IsShown()
				or not C_Timer
				or type(C_Timer.NewTicker) ~= "function"
			then
				return
			end
			local ok, ticker = pcall(C_Timer.NewTicker, 1, function()
				if not row:IsShown() then
					stopStatusTicker()
					return
				end
				refreshStatus()
			end)
			if ok then
				statusTicker = ticker
			end
		end
		statusRefreshButton:SetScript("OnClick", function()
			if not statusRefreshButton:IsEnabled() then
				return
			end
			Presenter:InvokeAction("neteaseAPIRefresh")
			refreshStatus()
		end)

		registerSettingsRefresher(
			refreshStatus, { categoryID = "netease_newbie" })
		local service = GF.NetEaseIdentityService
		if service and type(service.AddListener) == "function" then
			service:AddListener(refreshStatus)
		end
		row:SetScript("OnShow", function()
			refreshStatus()
			startStatusTicker()
		end)
		row:SetScript("OnHide", function()
			stopStatusTicker()
			if statusSpinner and GF.UI
				and type(GF.UI.StopPendingSpinner) == "function"
			then
				GF.UI.StopPendingSpinner(statusSpinner)
			end
		end)
		refreshStatus()
		startStatusTicker()
		row.statusDot = statusDot
		row.statusSpinner = statusSpinner
		row.statusText = statusText
		row.statusRefreshButton = statusRefreshButton
		return row
	end

	local neteaseNewbiePage, neteaseNewbieY =
		createSettingsPage(self, "netease_newbie")
	local section
	local sectionGroup
	local neteaseNewbieLayoutEntries = {}

	section, sectionGroup = createSingleCardSettingsSection(
		neteaseNewbiePage,
		L.SET_NETEASE_QUERY_TITLE or "网易 API 能力",
		neteaseNewbieY)
	local _, neteaseIdentityCheckbox = addCheckRow(
		sectionGroup,
		L.SET_NETEASE_QUERY_ENABLED or "玩家身份查询",
		L.SET_NETEASE_QUERY_ENABLED_HINT
			or "通过|cffffd100网易服务|r查询新兵、老兵及团长身份，用于大秘境中的|cffffd100身份显示和新兵搜索|r。",
		"neteaseIdentityEnabled")
	addNetEaseAPIStatusRow(
		sectionGroup,
		L.SET_NETEASE_API_STATUS_LABEL or "网易 API 状态",
		neteaseIdentityCheckbox)
	neteaseNewbieLayoutEntries[#neteaseNewbieLayoutEntries + 1] = {
		section = section,
		group = sectionGroup,
	}
	neteaseNewbieY = finishSingleCardSettingsSection(
		section, sectionGroup, neteaseNewbieY)

	section, sectionGroup = createSingleCardSettingsSection(
		neteaseNewbiePage,
		L.SET_NETEASE_NEWBIE_DEFINITION_TITLE or "新兵定义",
		neteaseNewbieY)
	addAdaptiveSettingsParagraph(
		sectionGroup,
		L.SET_NETEASE_NEWBIE_DEFINITION_BODY
			or "|TInterface\\AddOns\\GroupFinder\\Art\\Icon\\Newbie.png:16:16|t |cffffd100新兵|r：以战网账号为统计维度。当前赛季中，账号下所有角色累计|cffffd100限时完成 10 层及以上|r史诗钥石地下城|cffffd100不超过 10 次|r。\n\n|TInterface\\AddOns\\GroupFinder\\Art\\Icon\\Veteran.png:16:16|t |cffffd100老兵|r：同一战网账号累计|cffffd100限时通关大于 10 次|r后，账号身份转变为老兵。\n\n|A:housing-dashboard-fillbar-pip-complete:16:16|a 玩家身份由|cffffd100网易服务|r返回，插件不会自行统计通关次数；最终身份及生效时间以网易服务返回结果和当前活动规则为准。",
		{ leadingTextures = true })
	neteaseNewbieLayoutEntries[#neteaseNewbieLayoutEntries + 1] = {
		section = section,
		group = sectionGroup,
	}
	neteaseNewbieY = finishSingleCardSettingsSection(
		section, sectionGroup, neteaseNewbieY)

	section, sectionGroup = createSingleCardSettingsSection(
		neteaseNewbiePage,
		L.SET_NETEASE_NOTICE_TITLE or "注意事项",
		neteaseNewbieY)
	addAdaptiveSettingsParagraph(
		sectionGroup,
		L.SET_NETEASE_NOTICE_BODY
				or "与新兵玩家组队，并共同|cffffd100限时完成任意 10 层及以上|r史诗钥石地下城，即可获得任务进度。若队伍中唯一的新兵为|cffffd100玩家本人|r，则|cffffd100本人不会获得任务进度|r。\n\n老兵、新兵、星级团长和认证车头均为|cffffd100网易运营侧|r的玩家身份标识，并非游戏内置账号数据，因此相关身份查询需要依赖|cffffd100网易 API|r。\n\n网易 API 可能因|cffffd100维护、离线或服务异常|r暂时不可用，查询结果将受接口状态影响。开启玩家身份查询后，每次查询都会请求|cffffd100网易 API|r，可能造成|cffffd100短暂卡顿或查询耗时增加|r。|cffffd100建议活动完成后关闭此功能|r。\n\n开启玩家身份查询功能后，插件会向网易身份服务发送当前角色 GUID、BattleTag 和协议版本，用于查询新兵、老兵及团长身份。关闭后停止发送新的查询请求。",
		{ bulletAtlas = SETTINGS_NOTICE_BULLET_ATLAS })
	neteaseNewbieLayoutEntries[#neteaseNewbieLayoutEntries + 1] = {
		section = section,
		group = sectionGroup,
	}
	neteaseNewbieY = finishSingleCardSettingsSection(
		section, sectionGroup, neteaseNewbieY)
	installAdaptiveSettingsPageLayout(
		self, neteaseNewbiePage, neteaseNewbieLayoutEntries)

	finishSettingsPage(neteaseNewbiePage, neteaseNewbieY)
	if neteaseNewbiePage._gfRelayoutAdaptiveContent then
		neteaseNewbiePage:_gfRelayoutAdaptiveContent()
	end
	return neteaseNewbiePage
end
