local _, GF = ...

GF.ListingContextMenu = {}
GF.RowContextMenu = GF.ListingContextMenu -- compatibility facade
local RCM = GF.ListingContextMenu

local function presentationPort()
	return GF.ResultPresentationPort
end

local ROW_CTX_CENSORED_TITLE_COLOR = { 1, 0.1, 0.1, 1 }
local ROW_CTX_SIGN_UP_COLOR = { 0, 1, 0, 1 }
local ROW_CTX_REPORT_AD_COLOR = { 1, 0.1, 0.1, 1 }
local ROW_CTX_BLOCK_LEADER_COLOR = { 1, 0.82, 0, 1 }
local ROW_CTX_TITLE_DIVIDER_ATLAS = "levelup-bar-gold"
local ROW_CTX_TITLE_DIVIDER_COLOR = { 1, 0.82, 0 }
local ROW_CTX_TITLE_DIVIDER_ALPHA = 0.62
local ROW_CTX_TITLE_DIVIDER_SLOT_HEIGHT = 10
local ROW_CTX_TITLE_DIVIDER_VISUAL_OFFSET_Y = 2
local ROW_CTX_TITLE_DIVIDER_ACTION_GAP = 2

local function closeMenu()
	local manager = Menu and type(Menu.GetManager) == "function"
		and Menu.GetManager() or nil
	if manager and type(manager.CloseMenus) == "function" then
		manager:CloseMenus()
		return
	end
	if type(CloseMenus) == "function" then
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

local function nativeMenuApiAvailable()
	return MenuUtil and type(MenuUtil.CreateContextMenu) == "function"
end

local function colorByte(value)
	value = math.max(0, math.min(1, tonumber(value) or 1))
	return math.floor((value * 255) + 0.5)
end

local function colorizeText(text, color)
	text = tostring(text or "")
	if type(color) ~= "table" then
		return text
	end
	return string.format(
		"|c%02x%02x%02x%02x%s|r",
		colorByte(color[4]),
		colorByte(color[1]),
		colorByte(color[2]),
		colorByte(color[3]),
		text)
end

function RCM:CreateTitleDivider(rootDescription)
	local created = false
	if rootDescription and type(rootDescription.CreateFrame) == "function" then
		local dividerDescription = rootDescription:CreateFrame()
		if dividerDescription and type(dividerDescription.AddInitializer) == "function" then
			dividerDescription:AddInitializer(function(frame)
				local divider = frame:AttachTexture()
				divider:SetPoint(
					"LEFT", frame, "LEFT", 0,
					ROW_CTX_TITLE_DIVIDER_VISUAL_OFFSET_Y)
				divider:SetPoint(
					"RIGHT", frame, "RIGHT", 0,
					ROW_CTX_TITLE_DIVIDER_VISUAL_OFFSET_Y)
				divider:SetAtlas(ROW_CTX_TITLE_DIVIDER_ATLAS, true)
				divider:SetVertexColor(
					ROW_CTX_TITLE_DIVIDER_COLOR[1],
					ROW_CTX_TITLE_DIVIDER_COLOR[2],
					ROW_CTX_TITLE_DIVIDER_COLOR[3])
				divider:SetAlpha(ROW_CTX_TITLE_DIVIDER_ALPHA)
				return 1, ROW_CTX_TITLE_DIVIDER_SLOT_HEIGHT
			end)
			created = true
		end
	end
	if not created
		and rootDescription
		and type(rootDescription.CreateDivider) == "function"
	then
		rootDescription:CreateDivider()
	end
	if rootDescription and type(rootDescription.CreateSpacer) == "function" then
		rootDescription:CreateSpacer(ROW_CTX_TITLE_DIVIDER_ACTION_GAP)
	end
end

local function createNativeMenuItem(rootDescription, item)
	if type(item) ~= "table" then
		return
	end
	local text = item.disabled and tostring(item.text or "")
		or colorizeText(item.text, item.textColor)
	if item.isTitle then
		local description = rootDescription:CreateTitle(text)
		if item.initializer and description and type(description.AddInitializer) == "function" then
			description:AddInitializer(item.initializer)
		end
		if item.titleDivider ~= false then RCM:CreateTitleDivider(rootDescription) end
		return
	end
	local description = rootDescription:CreateButton(text, function()
		if type(item.func) == "function" then
			item.func()
		end
	end)
	if description and type(description.SetEnabled) == "function" then
		description:SetEnabled(item.disabled ~= true)
	end
end

function RCM:ShowMenu(menuItems, options)
	options = type(options) == "table" and options or {}
	self._activeMenuToken = (self._activeMenuToken or 0) + 1
	local menuToken = self._activeMenuToken
	self._activeResultID = options.resultID
	local requestedOnClose = type(options.onClose) == "function"
		and options.onClose or nil
	local function onClose()
		if self._activeMenuToken == menuToken then
			self._activeResultID = nil
		end
		if requestedOnClose then
			requestedOnClose()
		end
	end
	local released = false
	local function finishMenu()
		if released then
			return
		end
		released = true
		if onClose then
			onClose()
		end
	end
	if not nativeMenuApiAvailable() then
		finishMenu()
		return false
	end
	closeMenu()
	local releaseRegistered = false
	local motionRegistered = false
	local owner = options.owner or options.anchorFrame or UIParent
	local menu = MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		if type(rootDescription.SetTag) == "function" then
			rootDescription:SetTag("MENU_GROUPFINDER_CONTEXT")
		end
		if GF.UI and GF.UI.InstallMenuOpenAnimation then
			motionRegistered = GF.UI.InstallMenuOpenAnimation(
				rootDescription,
				{ preset = "menu", groupFinderOwned = true })
		end
		if onClose and type(rootDescription.AddMenuReleasedCallback) == "function" then
			releaseRegistered = true
			rootDescription:AddMenuReleasedCallback(finishMenu)
		end
		for itemIndex = 1, #(menuItems or {}) do
			createNativeMenuItem(rootDescription, menuItems[itemIndex])
		end
	end)
	if not menu then
		finishMenu()
		return false
	end
	if not motionRegistered and GF.UI and GF.UI.PlayPopupOpenAnimation then
		GF.UI.PlayPopupOpenAnimation(
			menu,
			{ preset = "menu", groupFinderOwned = true })
	end
	if onClose and not releaseRegistered then
		finishMenu()
	end
	return true
end

function RCM:CloseForResult(resultID)
	if resultID == nil or self._activeResultID ~= resultID then
		return false
	end
	self._activeResultID = nil
	closeMenu()
	return true
end

local function appendMenuItem(items, item)
	items[#items + 1] = item
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
	local port = presentationPort()
	return port and port:IsBlacklistEnabled() == true
end

local function getLiveCurrentGroupTarget(elementData)
	local port = presentationPort()
	if port then
		return port:GetCurrentGroupActionTarget(elementData)
	end
	return nil
end

local function appendStarredActions(items, snapshot)
	local stars = GF.StarredLeaders
	if not (stars and stars:IsRaidWorkspace() and stars:Identity(snapshot.leaderName)) then return end
	local L = GF.L or {}
	local existing = stars:Get(snapshot.leaderName)
	appendMenuItem(items, {
		text = existing and L.STARRED_EDIT or L.STARRED_ADD,
		textColor = GF.COMMON_BUTTON_VISUALS.normal.textColor,
		func = function()
			local classFilename = stars:GetListingClass(snapshot.leaderName, snapshot.resultID)
			GF.StarredLeadersPanel:OpenEditor(snapshot.leaderName, classFilename, snapshot.resultID)
		end,
	})
	if existing then
		appendMenuItem(items, {
			text = L.STARRED_REMOVE,
			textColor = GF.COMMON_BUTTON_VISUALS.normal.textColor,
			func = function() stars:Remove(snapshot.leaderName) end,
		})
	end
end

function RCM:BuildMenuItems(row, index, resultID, info)
	local L = GF.L or {}
	local displayTitle = getRowDisplayTitle(row)
	local port = presentationPort()
	local snapshot = port and port:BuildMenuSnapshot(
		index,
		resultID,
		info,
		displayTitle or (row and row._titleText))
	if not snapshot then
		return nil
	end
	local censored = snapshot.isCensored
	local titleText = snapshot.title
	local leaderName = snapshot.leaderName
	local selectionAllowed = snapshot.canApply == true
	local copyAllowed = canCopyCharacterName(leaderName)
	local items = {}
	appendMenuItem(items, {
		isTitle = true,
		text = titleText,
		textColor = censored and ROW_CTX_CENSORED_TITLE_COLOR or nil,
	})
	appendMenuItem(items, {
		text = L.SIGN_UP or "Sign Up",
		textColor = ROW_CTX_SIGN_UP_COLOR,
		disabled = not selectionAllowed,
		func = function()
			port:OpenApplication(snapshot.index, snapshot.resultID)
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
	appendStarredActions(items, snapshot)
	if snapshot.blacklistEnabled then
		appendMenuItem(items, {
			text = L.CTX_BLOCK_TITLE or "Block same-title group",
			disabled = censored or not leaderName,
			func = function()
				port:BlockTitle(snapshot)
			end,
		})
	end
	if snapshot.supportsReportListing then
		appendMenuItem(items, {
			text = L.CTX_REPORT or LFG_LIST_REPORT_GROUP_FOR or "Report",
			func = function()
				port:ReportListing(snapshot)
			end,
		})
	end
	if snapshot.supportsReportAdvertisement then
		appendMenuItem(items, {
			text = L.CTX_REPORT_ADVERTISEMENT or "Report advertisement",
			textColor = ROW_CTX_REPORT_AD_COLOR,
			func = function()
				port:ReportAdvertisement(snapshot)
			end,
		})
	end
	if snapshot.blacklistEnabled then
		appendMenuItem(items, {
			text = L.CTX_BLOCK_LEADER or "Block leader",
			textColor = ROW_CTX_BLOCK_LEADER_COLOR,
			disabled = not leaderName,
			func = function()
				port:BlockLeader(snapshot)
			end,
		})
	end
	appendMenuItem(items, {
		text = L.CANCEL or "Cancel",
		func = closeMenu,
	})
	return items
end

function RCM:BuildCurrentGroupMenuItems(row, elementData)
	local entry = elementData and elementData.entry
	local info = entry and entry.info
	if type(info) ~= "table" then
		return nil
	end
	local L = GF.L or {}
	local displayTitle = getRowDisplayTitle(row)
	local port = presentationPort()
	local snapshot = port and port:BuildMenuSnapshot(
		nil, nil, info, displayTitle)
	if not snapshot then
		return nil
	end
	local censored = snapshot.isCensored
	local titleText = snapshot.title
	local leaderName = snapshot.leaderName
	local copyAllowed = canCopyCharacterName(leaderName)
	local _, liveResultID = getLiveCurrentGroupTarget(elementData)
	local canReport = liveResultID ~= nil
	local function liveActionSnapshot()
		local _, resultID, liveInfo = getLiveCurrentGroupTarget(elementData)
		if not resultID then
			return nil
		end
		return port:BuildMenuSnapshot(
			nil, resultID, liveInfo or info, displayTitle)
	end
	local items = {}
	appendMenuItem(items, {
		isTitle = true,
		text = titleText,
		textColor = censored and ROW_CTX_CENSORED_TITLE_COLOR or nil,
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
	if snapshot.blacklistEnabled then
		appendMenuItem(items, {
			text = L.CTX_BLOCK_TITLE or "Block same-title group",
			disabled = censored or not leaderName,
			func = function()
				port:BlockTitle(snapshot)
			end,
		})
	end
	if snapshot.supportsReportListing then
		appendMenuItem(items, {
			text = L.CTX_REPORT or LFG_LIST_REPORT_GROUP_FOR or "Report",
			disabled = not canReport,
			func = function()
				port:ReportListing(liveActionSnapshot())
			end,
		})
	end
	if snapshot.supportsReportAdvertisement then
		appendMenuItem(items, {
			text = L.CTX_REPORT_ADVERTISEMENT or "Report advertisement",
			textColor = ROW_CTX_REPORT_AD_COLOR,
			disabled = not canReport,
			func = function()
				port:ReportAdvertisement(liveActionSnapshot())
			end,
		})
	end
	if snapshot.blacklistEnabled then
		appendMenuItem(items, {
			text = L.CTX_BLOCK_LEADER or "Block leader",
			textColor = ROW_CTX_BLOCK_LEADER_COLOR,
			disabled = not leaderName,
			func = function()
				port:BlockLeader(snapshot)
			end,
		})
	end
	appendStarredActions(items, snapshot)
	appendMenuItem(items, {
		text = L.CANCEL or "Cancel",
		func = closeMenu,
	})
	return items
end

function RCM:ShowForRow(row)
	if not row then
		return
	end
	if row._gfCurrentGroupProjection == true then
		local items = self:BuildCurrentGroupMenuItems(
			row, row._gfCurrentGroupElement)
		if items then
			self:ShowMenu(items, { owner = row })
		end
		return
	end
	if not row.resultIndex then
		return
	end
	if GF.FindGroupTab and GF.FindGroupTab.SetSelectedRow then
		GF.FindGroupTab:SetSelectedRow(row)
	end
	local port = presentationPort()
	if not port then
		return
	end
	local index = row.resultIndex
	local resultID = row.resultID or port:GetResultID(index)
	if not resultID then
		return
	end
	local resolvedIndex, resolvedID = port:ResolveIdentity(
		index, resultID, true)
	if not resolvedIndex or not resolvedID then
		return
	end
	index, resultID = resolvedIndex, resolvedID
	local info = port:GetAuthoritativeInfo(resultID)
	if not info then
		return
	end
	local items = self:BuildMenuItems(row, index, resultID, info)
	if not items then
		return
	end
	self:ShowMenu(items, {
		owner = row,
		resultID = resultID,
	})
end
