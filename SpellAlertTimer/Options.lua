-- SpellAlertTimer 极简设置界面：控制倒计时文字缩放
local addonName, ns = ...

-- 保存变量：倒计时文字缩放（默认 30）、水平偏移（默认 5）与描边（默认细描边）
SpellAlertTimerDB = SpellAlertTimerDB or {}
SpellAlertTimerDB.scale = SpellAlertTimerDB.scale or 30
SpellAlertTimerDB.hOffset = SpellAlertTimerDB.hOffset or 15--lnui
SpellAlertTimerDB.outline = SpellAlertTimerDB.outline or "OUTLINE"

-- 中英客户端自动适配（zhCN/zhTW 均用中文）
local isCN = GetLocale():match("^zh")
local L = isCN and {
	title = "倒计时文本尺寸",
	outlineTitle = "倒计时文本描边",
	outlineNone = "无",
	outlineThin = "细",
	outlineThick = "粗",
	hOffsetTitle = "水平偏移",
	debugTitle = "调试模式",
	debugTip = "勾选后在聊天框打印每个法术警报的 ID-位置-尺寸",
	combatHint = "战斗中/M+等秘密环境无法修改,需脱战或M+结束后生效",
	openAfterCombat = "|cffff8c00SpellAlertTimer|r 设置界面将在脱战后打开",
} or {
	title = "Countdown Text Scale",
	outlineTitle = "Countdown Text Outline",
	outlineNone = "None",
	outlineThin = "Thin",
	outlineThick = "Thick",
	hOffsetTitle = "Horizontal Offset",
	debugTitle = "Debug Mode",
	debugTip = "Print the spellID-position-scale of each spell alert to chat when checked",
	combatHint = "Cannot change in combat or secret environments (e.g. M+); changes apply after leaving combat or M+ ends",
	openAfterCombat = "|cffff8c00SpellAlertTimer|r settings will open after leaving combat",
}

-- 懒构建：frame 首次显示时才执行 builder（只执行一次）
function ns.LazyBuild(frame, builder)
	local built = false
	frame:HookScript("OnShow", function()
		if built then return end
		built = true
		builder()
	end)
end

-- 注册到 ESC-选项-插件
local SATPanel = CreateFrame("Frame", "SpellAlertTimerOptionsPanel", UIParent)
local category = Settings.RegisterCanvasLayoutCategory(SATPanel, "SpellAlertTimer")
Settings.RegisterAddOnCategory(category)

ns.LazyBuild(SATPanel, function()
	-- 插件名
	local name = SATPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	name:SetPoint("TOPLEFT", 16, -16)
	name:SetFontHeight(33)
	name:SetText("|cffff8c00SpellAlertTimer|r")

	-- 横分割线（填满宽度）
	local divider = SATPanel:CreateTexture(nil, "ARTWORK")
	divider:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -10)
	divider:SetPoint("TOPRIGHT", SATPanel, "TOPRIGHT", -16, -10)
	divider:SetHeight(1)
	divider:SetColorTexture(1, 1, 1, 0.3)

	-- 版本号（分割线右上角）
	local version = C_AddOns.GetAddOnMetadata("SpellAlertTimer", "Version")
	local versionText = SATPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	versionText:SetPoint("BOTTOMRIGHT", divider, "TOPRIGHT", 0, 3)
	versionText:SetTextColor(0.8, 0.8, 0.8)
	versionText:SetText(version or "")

	-- 通用滑动条行：自动向下排布（每行固定 40px），结构为 label + slider + 右侧数值
	local rowY = -40
	local function CreateSliderRow(title, value, min, max, step, onChanged, formatter)
		local label = SATPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("TOPLEFT", divider, "TOPLEFT", 0, rowY)
		rowY = rowY - 40
		label:SetText(title)

		local slider = CreateFrame("Slider", nil, SATPanel, "MinimalSliderWithSteppersTemplate")
		slider:SetPoint("LEFT", label, "LEFT", 200, 0)
		slider:SetSize(220, 20)
		-- Init 第4参为"步数"=(max-min)/step，内部反推步长
		slider:Init(value, min, max, (max - min) / step)

		local valueText = SATPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
		valueText:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE")
		valueText:SetTextColor(1, 1, 1)
		valueText:SetText(tostring(value))

		slider:RegisterCallback("OnValueChanged", function(self, v)
			v = floor(v)
			valueText:SetText(formatter and formatter(v) or tostring(v))
			if onChanged then onChanged(v) end
		end)

		-- 返回行对象：SetValue 统一更新滑块与数值显示（供外部同步时调用）
		local row = { slider = slider }
		function row:SetValue(v)
			v = floor(v)
			slider:SetValue(v)
			valueText:SetText(formatter and formatter(v) or tostring(v))
		end
		return row
	end

	-- 法术激活覆盖透明度（读写 cvar，不保存本地；0-100 整数百分比映射 cvar 0-1）
	local opacityInit = floor((tonumber(C_CVar.GetCVar("spellActivationOverlayOpacity")) or 0.65) * 100)
	local opacityRow = CreateSliderRow(SPELL_ALERT_OPACITY, opacityInit, 0, 100, 1, function(value)
		C_CVar.SetCVar("spellActivationOverlayOpacity", value / 100)
	end)
	-- cvar 变化时同步滑条（如暴雪设置界面改动）
	Settings.SetOnValueChangedCallback("spellActivationOverlayOpacity", function(_, _, value)
		opacityRow:SetValue((tonumber(value) or 0) * 100)
	end)

	-- 统一鼠标提示：可传入文本与锚点，默认战斗中需脱战生效的提示
	local function AddToolTip(frame, text, anchor)
		text = text or L.combatHint
		anchor = anchor or "ANCHOR_TOP"
		frame:HookScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, anchor)
			GameTooltip:SetText(text, 1, 1, 1)
			GameTooltip:Show()
		end)
		frame:HookScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	-- 倒计时文本描边（循环按钮：无/细/粗）
	local outlineLabel = SATPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	outlineLabel:SetPoint("TOPLEFT", divider, "TOPLEFT", 0, rowY)
	outlineLabel:SetText(L.outlineTitle)

	local outlineButton = CreateFrame("Button", nil, SATPanel, "UIPanelButtonTemplate")
	outlineButton:SetPoint("LEFT", outlineLabel, "LEFT", 205, 0)
	outlineButton:SetSize(205, 24)
	local outlineOptions = {
		{ value = "", label = L.outlineNone },
		{ value = "OUTLINE", label = L.outlineThin },
		{ value = "THICKOUTLINE", label = L.outlineThick },
	}
	local outlineIdx = 1
	for i, opt in ipairs(outlineOptions) do
		if opt.value == (SpellAlertTimerDB.outline or "OUTLINE") then outlineIdx = i end
	end
	local function RefreshOutlineButton()
		outlineButton:SetText(outlineOptions[outlineIdx].label)
	end
	outlineButton:SetScript("OnClick", function()
		outlineIdx = outlineIdx % #outlineOptions + 1
		SpellAlertTimerDB.outline = outlineOptions[outlineIdx].value
		RefreshOutlineButton()
		-- 战斗中不实时应用到已创建文字，仅保存；退出战斗后新文字自动用新值
		if ns and ns.UpdateOutline and not InCombatLockdown() then
			ns.UpdateOutline(SpellAlertTimerDB.outline)
		end
	end)
	AddToolTip(outlineButton)
	RefreshOutlineButton()
	rowY = rowY - 40

	-- 倒计时文本尺寸
	local scaleRow = CreateSliderRow(L.title, SpellAlertTimerDB.scale, 10, 80, 1, function(value)
		SpellAlertTimerDB.scale = value
		-- 战斗中不实时应用到已创建文字，仅保存；退出战斗后新文字自动用新值
		if ns and ns.UpdateScale and not InCombatLockdown() then
			ns.UpdateScale(value)
		end
	end)
	-- 鼠标提示：MinimalSliderWithSteppersTemplate 是 Frame，真正的滑轨在内部子控件 Slider 上，需绑定到它才能整条滑轨触发
	local innerSlider = scaleRow.slider.Slider or scaleRow.slider
	AddToolTip(innerSlider)

	-- 水平偏移（像素）：正值为两侧外扩、负值为两侧内收
	CreateSliderRow(L.hOffsetTitle, SpellAlertTimerDB.hOffset, -25, 25, 1, function(value)
		SpellAlertTimerDB.hOffset = value
		-- 战斗中不实时移动已创建容器，仅保存；退出战斗后新容器自动用新值
		if ns and ns.UpdateOffset and not InCombatLockdown() then
			ns.UpdateOffset(value)
		end
	end)

	-- 调试模式勾选框：文本在左、勾选按钮与滑动条对齐（不保存，每次上线默认关闭）
	local debugLabel = SATPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	debugLabel:SetPoint("TOPLEFT", divider, "TOPLEFT", 0, rowY)
	debugLabel:SetText(L.debugTitle)

	local debugCheck = CreateFrame("CheckButton", nil, SATPanel, "UICheckButtonTemplate")
	debugCheck:SetPoint("LEFT", debugLabel, "LEFT", 200, 0)
	debugCheck:SetChecked(false)
	debugCheck:HookScript("OnClick", function(self)
		if ns then ns.Debug = self:GetChecked() end
	end)
	-- 鼠标提示：说明调试模式会在聊天框打印 ID-位置-尺寸
	AddToolTip(debugCheck, L.debugTip, "ANCHOR_RIGHT")
end)

-- /sat 打开设置界面（战斗中延迟到脱战后）
SLASH_SAT1 = "/sat"
SlashCmdList["SAT"] = function()
	if InCombatLockdown() then
		print(L.openAfterCombat)
		EventRegistry:RegisterFrameEventAndCallback("PLAYER_REGEN_ENABLED", function(ownerID)
			EventRegistry:UnregisterFrameEventAndCallback("PLAYER_REGEN_ENABLED", ownerID)
			Settings.OpenToCategory(category:GetID())
		end)
	else
		Settings.OpenToCategory(category:GetID())
	end
end