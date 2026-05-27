function PLH_CreateOptionsPanel()

	--[[ Main Panel ]]--
	local configFrame = CreateFrame('Frame', 'PLHConfigFrame', InterfaceOptionsFramePanelContainer)
	configFrame:Hide()
	configFrame.name = 'Personal Loot Helper'
	local category, layout = Settings.RegisterCanvasLayoutCategory(configFrame, configFrame.name, configFrame.name);
	category.ID = configFrame.name;
	Settings.RegisterAddOnCategory(category);

	--[[ Title ]]--
	local titleLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
	titleLabel:SetPoint('TOPLEFT', configFrame, 'TOPLEFT', 16, -16)
	titleLabel:SetText('Personal Loot Helper (PLH)')

	-- [[ Version ]] --
	local versionLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
	local metaVersion = C_AddOns.GetAddOnMetadata('PersonalLootHelper', 'Version')
	versionLabel:SetPoint('BOTTOMLEFT', titleLabel, 'BOTTOMRIGHT', 8, 0)
	versionLabel:SetText(((metaVersion:find("^v") ~= nil) and "" or "v") .. metaVersion)

	--[[ Author ]]--
	local authorLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
	authorLabel:SetPoint('TOPRIGHT', configFrame, 'TOPRIGHT', -16, -24)
	authorLabel:SetText(C_AddOns.GetAddOnMetadata('PersonalLootHelper', 'Author'))

	--[[ Display Options ]]--
	local displayLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	displayLabel:SetPoint('TOPLEFT', titleLabel, 'BOTTOMLEFT', 0, -20)
	displayLabel:SetText("显示选项")
	
	--[[ PLH_PREFS_AUTO_HIDE ]]--
--[[
	local autoHideCheckbox = CreateFrame('CheckButton', nil, configFrame, 'InterfaceOptionsCheckButtonTemplate')
	autoHideCheckbox:SetPoint('TOPLEFT', displayLabel, 'BOTTOMLEFT', 20, -5)
	autoHideCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_AUTO_HIDE])

	local autoHideLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	autoHideLabel:SetPoint('LEFT', autoHideCheckbox, 'RIGHT', 0, 0)
	autoHideLabel:SetText("Automatically hide PLH when there is no loot to trade")
]]--

	--[[ PLH_PREFS_SKIP_CONFIRMATION ]]--
	local skipConfirmationCheckbox = CreateFrame('CheckButton', nil, configFrame, 'InterfaceOptionsCheckButtonTemplate')
	skipConfirmationCheckbox:SetPoint('TOPLEFT', displayLabel, 'BOTTOMLEFT', 20, -5)
	skipConfirmationCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_SKIP_CONFIRMATION])
	skipConfirmationCheckbox:SetScript("OnClick", CheckBox_OnClick)


	local skipConfirmationLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	skipConfirmationLabel:SetPoint('LEFT', skipConfirmationCheckbox, 'RIGHT', 0, 0)
	skipConfirmationLabel:SetText("在提供或请求战利品时自动跳过确认")

	--[[ PLH_PREFS_ANNOUNCE_TRADES ]]--
	local announceTradesCheckbox = CreateFrame('CheckButton', nil, configFrame, 'InterfaceOptionsCheckButtonTemplate')
	announceTradesCheckbox:SetPoint('TOPLEFT', skipConfirmationCheckbox, 'BOTTOMLEFT', 0, -5)
	announceTradesCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_ANNOUNCE_TRADES])
	announceTradesCheckbox:SetScript("OnClick", CheckBox_OnClick)

	local announceTradeLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	announceTradeLabel:SetPoint('LEFT', announceTradesCheckbox, 'RIGHT', 0, 0)
	announceTradeLabel:SetText("宣布已完成的交易(仅限公会队伍)")
	
	--[[ Looter Options ]]--
	local looterLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	looterLabel:SetPoint('TOPLEFT', announceTradesCheckbox, 'BOTTOMLEFT', -20, -15)
	looterLabel:SetText("当我收到可交易的战利品时...")
	
	--[[ PLH_PREFS_ONLY_OFFER_IF_UPGRADE ]]
	local onlyOfferIfUpgradeCheckbox = CreateFrame('CheckButton', nil, configFrame, 'InterfaceOptionsCheckButtonTemplate')
	onlyOfferIfUpgradeCheckbox:SetPoint('TOPLEFT', looterLabel, 'BOTTOMLEFT', 20, -5)
	onlyOfferIfUpgradeCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_ONLY_OFFER_IF_UPGRADE])
	onlyOfferIfUpgradeCheckbox:SetScript("OnClick", CheckBox_OnClick)

	local onlyOfferIfUpgradeLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	onlyOfferIfUpgradeLabel:SetPoint('LEFT', onlyOfferIfUpgradeCheckbox, 'RIGHT', 0, 0)
	onlyOfferIfUpgradeLabel:SetText("仅在战利品为其他玩家提供装备等级升级时提示我进行交易")

	--[[ PLH_PREFS_NEVER_OFFER_BOE ]]--
	local neverOfferBOECheckbox = CreateFrame('CheckButton', nil, configFrame, 'InterfaceOptionsCheckButtonTemplate')
	neverOfferBOECheckbox:SetPoint('TOPLEFT', onlyOfferIfUpgradeCheckbox, 'BOTTOMLEFT', 0, -5)
	neverOfferBOECheckbox:SetChecked(PLH_PREFS[PLH_PREFS_NEVER_OFFER_BOE])
	neverOfferBOECheckbox:SetScript("OnClick", CheckBox_OnClick)

	local neverOfferBOELabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	neverOfferBOELabel:SetPoint('LEFT', neverOfferBOECheckbox, 'RIGHT', 0, 0)
	neverOfferBOELabel:SetText("永不提示我交易装备后绑定的战利品")

	-- [[ PLH_PREFS_SHOW_TRADEABLE_ALERT ]] --
	local showTradeableAlertCheckbox = CreateFrame('CheckButton', nil, configFrame, 'InterfaceOptionsCheckButtonTemplate')
	showTradeableAlertCheckbox:SetPoint('TOPLEFT', neverOfferBOECheckbox, 'BOTTOMLEFT', 0, -5)
	showTradeableAlertCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_SHOW_TRADEABLE_ALERT])
	showTradeableAlertCheckbox:SetScript("OnClick", CheckBox_OnClick)

	local showTradeableAlertLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	showTradeableAlertLabel:SetPoint('LEFT', showTradeableAlertCheckbox, 'RIGHT', 0, 0)
	showTradeableAlertLabel:SetText("向我显示可以使用该战利品的玩家列表")
	
	--[[ Non-looter Options ]]--
	local nonLooterLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	nonLooterLabel:SetPoint('TOPLEFT', showTradeableAlertCheckbox, 'BOTTOMLEFT', -20, -15)
	nonLooterLabel:SetText("当其他玩家收到可交易的战利品时...")

	--[[ PLH_PREFS_CURRENT_SPEC_ONLY ]]--
	local currentSpecOnlyCheckbox = CreateFrame('CheckButton', nil, configFrame, 'InterfaceOptionsCheckButtonTemplate')
	currentSpecOnlyCheckbox:SetPoint('TOPLEFT', nonLooterLabel, 'BOTTOMLEFT', 20, -5)
	currentSpecOnlyCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_CURRENT_SPEC_ONLY])
	currentSpecOnlyCheckbox:SetScript("OnClick", CheckBox_OnClick)

	local currentSpecOnlyLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	currentSpecOnlyLabel:SetPoint('LEFT', currentSpecOnlyCheckbox, 'RIGHT', 0, 0)
	currentSpecOnlyLabel:SetText("仅在我可以在当前天赋中装备时提示我")

	--[[ PLH_PREFS_ILVL_THRESHOLD ]]--

	local ilvlThresholdLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	ilvlThresholdLabel:SetPoint('TOPLEFT', currentSpecOnlyCheckbox, 'BOTTOMLEFT', 5, -10)
	ilvlThresholdLabel:SetText("仅在以下情况下提示我")

	local ilvlThresholdValue = {
		0,
		-1,
		-6,
		-11,
		-16,
		-21,
		-26,
		-31,
		-9999
	}

	local ilvlThresholdDescription = {
		"拾取的装备等级高于当前装备的等级",
		"拾取的装备等级至少等于当前装备的等级",
		"拾取的装备等级至少等于当前装备的等级减去5",
		"拾取的装备等级至少等于当前装备的等级减去10",
		"拾取的装备等级至少等于当前装备的等级减去15",
		"拾取的装备等级至少等于当前装备的等级减去20",
		"拾取的装备等级至少等于当前装备的等级减去25",
		"拾取的装备等级至少等于当前装备的等级减去30",
		"始终显示所有物品"
	}

	local ilvlThresholdMenu = MSA_DropDownMenu_Create('ilvlThresholdMenu', configFrame)
	ilvlThresholdMenu:SetPoint('LEFT', ilvlThresholdLabel, 'RIGHT', -5, 0)

	local function ilvlThresholdMenu_OnClick(self, arg1, arg2, checked)
		MSA_DropDownMenu_SetText(ilvlThresholdMenu, ilvlThresholdDescription[arg1])
	end

	local function ilvlThresholdMenu_Initialize(self, level)
		local info = MSA_DropDownMenu_CreateInfo()
		info.func = ilvlThresholdMenu_OnClick
		for i = 1, #ilvlThresholdValue do
			info.arg1 = i
			info.text = ilvlThresholdDescription[i]
			MSA_DropDownMenu_AddButton(info)
		end
	end

	MSA_DropDownMenu_Initialize(ilvlThresholdMenu, ilvlThresholdMenu_Initialize)
	MSA_DropDownMenu_SetWidth(ilvlThresholdMenu, 300);
	MSA_DropDownMenu_JustifyText(ilvlThresholdMenu, 'LEFT')

	local function GetILVLThresholdDescription(ilvlThreshold)
		for i = 1, #ilvlThresholdValue do
			if ilvlThresholdValue[i] == ilvlThreshold then
				return ilvlThresholdDescription[i]
			end
		end
		return ilvlThresholdDescription[2]  -- we couldn't find a match, so return default
	end

	local function GetILVLThresholdValue(description)
		for i = 1, #ilvlThresholdDescription do
			if ilvlThresholdDescription[i] == description then
				return ilvlThresholdValue[i]
			end
		end
		return ilvlThresholdValue[2]  -- we couldn't find a match, so return default
	end

	MSA_DropDownMenu_SetText(ilvlThresholdMenu, GetILVLThresholdDescription(PLH_PREFS[PLH_PREFS_ILVL_THRESHOLD]))
	
	--[[ PLH_PREFS_INCLUDE_XMOG ]]--
	
	local includeXMOGCheckbox = CreateFrame('CheckButton', nil, configFrame, 'InterfaceOptionsCheckButtonTemplate')
	includeXMOGCheckbox:SetPoint('TOPLEFT', neverOfferBOECheckbox, 'BOTTOMLEFT', 0, -120)
	includeXMOGCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_INCLUDE_XMOG])
	includeXMOGCheckbox:SetScript("OnClick", CheckBox_OnClick)

	local includeXMOGLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	includeXMOGLabel:SetPoint('LEFT', includeXMOGCheckbox, 'RIGHT', 0, 0)
	includeXMOGLabel:SetText("即使物品不是升级也请提示我进行幻化")

	-- [[ PLH_PREFS_WHISPER_MESSAGE ]]--
	
	local sampleItem = '\124cffa335ee\124Hitem:151981::::::::110::::2:1522:3610:\124h[Life-Bearing Footpads]\124h\124r'
	local whisperMessageLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	whisperMessageLabel:SetPoint('TOPLEFT', includeXMOGCheckbox, 'BOTTOMLEFT', -25, -15)
	whisperMessageLabel:SetText("输入在向未使用PLH的玩家请求战利品时要悄悄话的消息.\n" ..
		"你可以通过使用%item来包含拾取的物品. 例如:\n" ..
		"      \"" .. PLH_DEFAULT_PREFS[PLH_PREFS_WHISPER_MESSAGE] .. "\"可以显示为\n" ..
		"      \"" .. PLH_GetWhisperMessage(sampleItem, PLH_DEFAULT_PREFS[PLH_PREFS_WHISPER_MESSAGE]) .. "\"\n")
	whisperMessageLabel:SetWordWrap(true)
	whisperMessageLabel:SetJustifyH('LEFT')
	whisperMessageLabel:SetWidth(500)
	whisperMessageLabel:SetSpacing(3)

	local whisperMessageEditBox = CreateFrame('EditBox', nil, configFrame)
	whisperMessageEditBox:SetWidth(450)
	whisperMessageEditBox:SetHeight(30)
	whisperMessageEditBox:SetTextInsets(4, 4, 4, 4)
	whisperMessageEditBox:SetMaxLetters(100)
	whisperMessageEditBox:SetAutoFocus(false)
	whisperMessageEditBox:SetFont(STANDARD_TEXT_FONT, 14, "")--lnui
	whisperMessageEditBox:SetPoint('TOPLEFT', whisperMessageLabel, 'BOTTOMLEFT', 20, -10)
	whisperMessageEditBox:SetText(PLH_PREFS[PLH_PREFS_WHISPER_MESSAGE])
	
	local whisperMessageEditBoxBackdrop = {
		bgFile = nil, 
		edgeFile = 'Interface/Tooltips/UI-Tooltip-Border',
		tile = false,
		tileSize = 8,
		edgeSize = 8,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	}

	local whisperMessageEditBoxBorder = CreateFrame('Frame', nil, whisperMessageEditBox, BackdropTemplateMixin and "BackdropTemplate");
	whisperMessageEditBoxBorder:SetWidth(whisperMessageEditBox:GetWidth() + 5)
	whisperMessageEditBoxBorder:SetHeight(whisperMessageEditBox:GetHeight() + 5)
	whisperMessageEditBoxBorder:SetPoint('CENTER', whisperMessageEditBox, 'CENTER')
	whisperMessageEditBoxBorder:SetBackdrop(whisperMessageEditBoxBackdrop)

	--[[ Thank You Message ]] --
	local thankYouLabel = configFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
	thankYouLabel:SetPoint('BOTTOM', configFrame, 'BOTTOM', 0, 24)
	thankYouLabel:SetSpacing(5)
	thankYouLabel:SetWidth(500)
	thankYouLabel:SetWordWrap(true)
	
	local function UpdateThankYouLabel()
		local text = ''
--		if PLH_STATS[PLH_ITEMS_REQUESTED] > 0 or PLH_STATS[PLH_ITEMS_RECEIVED] > 0 then
--			text = text .. "You have requested " .. PLH_STATS[PLH_ITEMS_REQUESTED] .. " and received " .. PLH_STATS[PLH_ITEMS_RECEIVED] .. " item(s) through PLH\n"
--		end
--		if PLH_STATS[PLH_ITEMS_OFFERED] > 0 or PLH_STATS[PLH_ITEMS_GIVEN_AWAY] > 0 then
--			text = text .. "You have offered " .. PLH_STATS[PLH_ITEMS_OFFERED] .. " and given away " .. PLH_STATS[PLH_ITEMS_GIVEN_AWAY] .. " item(s) through PLH\n"
--		end
--		if PLH_GetNumberOfPLHUsers() > 0 then
--			text = text .. PLH_GetNumberOfPLHUsers() .. " of " .. GetNumGroupMembers() .. " group members are running PLH\n"
--		end
		text = text .. "\n如果你觉得PLH有用, 请告诉你的朋友和公会成员!"
		thankYouLabel:SetText(text)
	end
	
	--[[ OnShow Event]]
	configFrame:SetScript('OnShow', function(frame)
		-- autoHideCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_AUTO_HIDE])
		skipConfirmationCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_SKIP_CONFIRMATION])
		announceTradesCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_ANNOUNCE_TRADES])
		onlyOfferIfUpgradeCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_ONLY_OFFER_IF_UPGRADE])
		neverOfferBOECheckbox:SetChecked(PLH_PREFS[PLH_PREFS_NEVER_OFFER_BOE])
		showTradeableAlertCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_SHOW_TRADEABLE_ALERT])
		currentSpecOnlyCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_CURRENT_SPEC_ONLY])
		MSA_DropDownMenu_SetText(ilvlThresholdMenu, GetILVLThresholdDescription(PLH_PREFS[PLH_PREFS_ILVL_THRESHOLD]))
		includeXMOGCheckbox:SetChecked(PLH_PREFS[PLH_PREFS_INCLUDE_XMOG])
		whisperMessageEditBox:SetText(PLH_PREFS[PLH_PREFS_WHISPER_MESSAGE])
		UpdateThankYouLabel()
	end)

	--[[ Save config ]]--
    configFrame:SetScript("OnHide", function()
		-- PLH_PREFS[PLH_PREFS_AUTO_HIDE] = autoHideCheckbox:GetChecked()
		PLH_PREFS[PLH_PREFS_SKIP_CONFIRMATION] = skipConfirmationCheckbox:GetChecked()
		PLH_PREFS[PLH_PREFS_ANNOUNCE_TRADES] = announceTradesCheckbox:GetChecked()
		PLH_PREFS[PLH_PREFS_ONLY_OFFER_IF_UPGRADE] = onlyOfferIfUpgradeCheckbox:GetChecked()
		PLH_PREFS[PLH_PREFS_NEVER_OFFER_BOE] = neverOfferBOECheckbox:GetChecked()
		PLH_PREFS[PLH_PREFS_SHOW_TRADEABLE_ALERT] = showTradeableAlertCheckbox:GetChecked()
		PLH_PREFS[PLH_PREFS_CURRENT_SPEC_ONLY] = currentSpecOnlyCheckbox:GetChecked()
		PLH_PREFS[PLH_PREFS_ILVL_THRESHOLD] = GetILVLThresholdValue(MSA_DropDownMenu_GetText(ilvlThresholdMenu))
		PLH_PREFS[PLH_PREFS_INCLUDE_XMOG] = includeXMOGCheckbox:GetChecked()
		if PLH_PREFS[PLH_PREFS_WHISPER_MESSAGE] ~= whisperMessageEditBox:GetText() then
			PLH_PREFS[PLH_PREFS_WHISPER_MESSAGE] = whisperMessageEditBox:GetText()
			PLH_META[PLH_SHOW_WHISPER_WARNING] = true
		end
	end)

end
