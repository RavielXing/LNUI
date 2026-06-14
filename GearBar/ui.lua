local _, SELFAQ = ...

local debug = SELFAQ.debug
local clone = SELFAQ.clone
local diff = SELFAQ.diff
local L = SELFAQ.L
local player = SELFAQ.player
local GetItemTexture = SELFAQ.GetItemTexture
local otherSlot = SELFAQ.otherSlot

function SELFAQ.customSlots()
	local new = {}
	for k,v in pairs(AQSV.enableItemBarSlot) do
		if v then
			table.insert(new, k)
		end
	end
	-- 饰品(13,14)排最前，其余按数字排序
	table.sort(new, function(a, b)
		local aT = (a == 13 or a == 14) and 0 or 1
		local bT = (b == 13 or b == 14) and 0 or 1
		if aT ~= bT then return aT < bT end
		return a < b
	end)
	SELFAQ.slots = new
end

function SELFAQ.createItemBar()

	if SELFAQ.bar ~= nil then
		return
	end

	-- 选择BUTTON类似，才能触发鼠标事件
	local f = CreateFrame("Button", "GearBar_ItemBar", UIParent)
	SELFAQ.bar = f
	SELFAQ.list = {}
	SELFAQ.itemButtons = {}

	SELFAQ.customSlots()

	f:SetFrameStrata("MEDIUM")
	f:SetWidth(#SELFAQ.slots * (40 + AQSV.buttonSpacingNew) - AQSV.buttonSpacingNew)
	f:SetHeight(40)
	f:SetScale(AQSV.barZoom)

	-- 可以使用鼠标
	f:EnableMouse(true)

	SELFAQ.bar:SetMovable(not AQSV.locked)
	if AQSV.locked then
		-- 关闭拖动，同时不影响右键单击
		SELFAQ.bar:RegisterForDrag("")
	else
		SELFAQ.bar:RegisterForDrag("LeftButton")
	end

	-- 实现拖动
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint()
		AQSV.point = point
		AQSV.x = x
		AQSV.y = y
	end)

    local t = f:CreateTexture(nil, "BACKGROUND")
    f.texture = t
    -- 暴雪风格：标准UI背景
	t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
	t:SetAllPoints(f)
	t:SetVertexColor(0, 0, 0, 0.6)

	-- 右上角标题背景
	local titleBg = CreateFrame("Frame", nil, f)
	titleBg:SetFrameLevel(1)
	titleBg:EnableMouse(true)
	f.titleBg = titleBg

	-- 标题背景拖动（拖动整个装备栏）
	titleBg:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not AQSV.locked then
			f:StartMoving()
		end
	end)
	titleBg:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			f:StopMovingOrSizing()
			local point, _, _, x, y = f:GetPoint()
			AQSV.point = point
			AQSV.x = x
			AQSV.y = y
		end
	end)

	-- 右上角标题文字
	local title = titleBg:CreateFontString(nil, "OVERLAY")
	title:SetFont(AQSV.fontPath or [[Fonts\FRIZQT__.TTF]], 10, "OUTLINE")
	title:SetText(" ")
	title:SetTextColor(1, 1, 1, 0.6)
	title:SetPoint("CENTER", titleBg, 0, 0)
	f.title = title

	-- 标题背景尺寸：宽度为一个按钮宽度(40)，高度自适应文字
	titleBg:SetWidth(10)
	titleBg:SetHeight(10)
	titleBg:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 0)

	-- 初始化背景和标题显隐状态
	SELFAQ.hideBackdrop()

  	f:SetFrameLevel(1)

  	-- 初始化位置
	f:SetPoint(AQSV.point, AQSV.x, AQSV.y)

	-- 创建右键菜单
	SELFAQ.createMenu()

	-- 绘制冷却时间
	f.TimeSinceLastUpdate = 0
	-- 函数执行间隔时间
	f.Interval = 0.1
	f:SetScript("OnUpdate", SELFAQ.cooldownUpdate)

	-- 创建按钮
	for k,v in pairs(SELFAQ.slots) do
		SELFAQ.createItemButton( v, k )
	end

	-- 设置里是否启用装备栏
	if AQSV.enableItemBar then
		f:Show()
	else
		f:Hide()
	end

	SELFAQ.bindingSlot()

end

-- 重新布局按钮间距
function SELFAQ.relayoutBar()
	if not SELFAQ.bar or not SELFAQ.slotFrames then return end
	local spacing = AQSV.buttonSpacingNew
	SELFAQ.bar:SetWidth(#SELFAQ.slots * (40 + spacing) - spacing)
	for k, v in pairs(SELFAQ.slots) do
		local button = SELFAQ.slotFrames[v]
		if button then
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", SELFAQ.bar, (k - 1) * (40 + spacing), 0)
		end
	end
end

function SELFAQ.createMenu()
	local menuFrame = CreateFrame("Frame", nil, SELFAQ.bar, "UIDropDownMenuTemplate")

	local menu = {}

	menu[1] = {}
	menu[1]["text"] = L[" Settings"]
	menu[1]["func"] = function()
		InterfaceOptionsFrame_OpenToCategory(SELFAQ.top);
		InterfaceOptionsFrame_OpenToCategory(SELFAQ.top);
	end

	menu[2] = {}
	menu[2]["text"] = L[" Lock frame"]
	menu[2]["checked"] = AQSV.locked
	menu[2]["func"] = function()
		AQSV.locked = not AQSV.locked
		SELFAQ.lockItemBar()
	end

	menu[3] = {}
	menu[3]["text"] = L[" Close"]
	menu[3]["func"] = function()
	end

	SELFAQ.menuList = menu

	local function Menu_Initialize(self, level)
		for i=1, #SELFAQ.menuList do
			local info = UIDropDownMenu_CreateInfo()
			info.text = SELFAQ.menuList[i]["text"]
			info.func = SELFAQ.menuList[i]["func"]
			info.checked = SELFAQ.menuList[i]["checked"]
			info.notCheckable = not SELFAQ.menuList[i]["checked"]
			UIDropDownMenu_AddButton(info, level)
		end
	end

	SELFAQ.bar:RegisterForClicks("RightButtonDown");
	SELFAQ.bar:SetScript('OnClick', function(self, button)
		if button == "RightButton" then
			UIDropDownMenu_Initialize(menuFrame, Menu_Initialize)
			ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
		end
	end)
end

function SELFAQ.lockItemBar()
	
	SELFAQ.menuList[2]["checked"] = AQSV.locked

	SELFAQ.bar:SetMovable(not AQSV.locked)
	if AQSV.locked then
		SELFAQ.bar:RegisterForDrag("")
	else
		SELFAQ.bar:RegisterForDrag("LeftButton")
	end

	SELFAQ.f.checkbox["locked"]:SetChecked(AQSV.locked)
end

function SELFAQ.createItemButton( slot_id, position )

	local itemId = GetInventoryItemID("player", slot_id)
	local itemTexture = ""
	if itemId then
		itemTexture = GetItemTexture(itemId)
	else
		_, itemTexture = GetInventorySlotInfo(SELFAQ.slotName[slot_id])
	end

	local button = CreateFrame("Button", "AQButton"..slot_id, SELFAQ.bar, "SecureActionButtonTemplate")

	button:SetSize(40, 40)
	button.itemId = itemId

   	button:EnableMouse(true)
   	button:RegisterForClicks("AnyDown", "AnyUp")

	-- 设置为使用装备栏物品
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", "/use "..slot_id)

  	button:SetFrameLevel(2)
  	
  	-- 暴雪风格：空槽背景
  	local bg = button:CreateTexture(nil, "BACKGROUND", nil, -1)
  	bg:SetTexture("Interface\\Buttons\\UI-Quickslot")
  	bg:SetPoint("TOPLEFT", -5, 5)
  	bg:SetPoint("BOTTOMRIGHT", 5, -5)
  	button.bg = bg

  	-- 暴雪风格：高亮
  	local hl = button:CreateTexture(nil, "HIGHLIGHT")
  	hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  	hl:SetBlendMode("ADD")
  	hl:SetAllPoints(button)

  	-- 暴雪风格：按下效果
  	local push = button:CreateTexture(nil, "ARTWORK")
  	push:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  	push:SetAllPoints(button)
  	button:SetPushedTexture(push)

    local t = button:CreateTexture(nil, "ARTWORK")
	t:SetTexture(itemTexture)
	t:SetAllPoints(button)
	button.texture = t

	-- 文字单独一个frame，因为要盖住冷却动画
	local tf = CreateFrame("Frame", nil, button)
	tf:SetAllPoints(button)
	tf:SetFrameLevel(4)

	-- 暴雪风格：计时文字 - 居中
	local text = tf:CreateFontString(nil, "OVERLAY")
	text:SetFont(AQSV.fontPath or [[Fonts\FRIZQT__.TTF]], 16, "OUTLINE")
    text:SetPoint("CENTER", button, 0, 0)
    text:SetText("")
    button.text = text

    -- 快捷键文字
    local shortcut = tf:CreateFontString(nil, "OVERLAY")
	shortcut:SetFont(AQSV.fontPath or [[Fonts\FRIZQT__.TTF]], AQSV.hotkeyFontSize or 8, "OUTLINE")
    shortcut:SetPoint("TOPRIGHT", button, -2, -2)
    shortcut:SetJustifyH("RIGHT")
    shortcut:SetText("")
    shortcut:Hide()
    button.shortcut = shortcut

    -- 漩涡状冷却效果
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    button.cooldown = cooldown

	-- 按钮定位
   	button:SetPoint("TOPLEFT", SELFAQ.bar, (position - 1) * (40 + AQSV.buttonSpacingNew), 0)
   	button:Show()

   	-- 鼠标悬停显示下拉框
   	button:SetScript("OnEnter", function(self)
		SELFAQ.showDropdown(slot_id, position)
		-- 显示物品提示（如果启用）
		if AQSV.enableTooltip and self.itemId then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
			GameTooltip:SetInventoryItem("player", slot_id)
			GameTooltip:Show()
		end
	end)
   	button:SetScript("OnLeave", function( self )
   		SELFAQ.hideItemDropdown( 0.5 )
   		if AQSV.enableTooltip then
   			GameTooltip:Hide()
   		end
   	end)

   	-- 缓存
   	SELFAQ.slotFrames[slot_id] = button
end

function SELFAQ.hideBackdrop()
	if AQSV.hideBackdrop then
		if SELFAQ.bar.texture then SELFAQ.bar.texture:Hide() end
		if SELFAQ.bar.titleBg then SELFAQ.bar.titleBg:Hide() end
	else
		if SELFAQ.bar.texture then SELFAQ.bar.texture:Show() end
		if SELFAQ.bar.titleBg then SELFAQ.bar.titleBg:Show() end
	end
end

function SELFAQ.showDropdown(slot_id, position, force, pass_id)

	if not pass_id then
		pass_id = slot_id
	end

	if not SELFAQ.items then
		return
	end

	if not SELFAQ.items[slot_id] then
		return
	end

	-- 停掉隐藏下拉框的计时器
	SELFAQ.itemDropdownTimestamp = nil

	SELFAQ.showingSlot = slot_id
	SELFAQ.showingPosition = position

	local index = 1
	local itemId1 = GetInventoryItemID("player", slot_id)
	local itemId2 = GetInventoryItemID("player", otherSlot(slot_id))

	for k,v in pairs(SELFAQ.items[slot_id]) do
		-- 推算出真实id
		local rid = SELFAQ.reverseId(v)

		-- 跳过当前已装备的
		if rid ~= itemId1 and rid ~= itemId2 then
			SELFAQ.createItemDropdown(v, (position - 1) * (40 + AQSV.buttonSpacingNew), index, pass_id)
			index = index + 1
		end
	end

	-- 隐藏多余的
	for k,v in pairs(SELFAQ.itemButtons) do
		if not tContains(SELFAQ.items[slot_id], k) then
			v:Hide()
		end
	end
end

function SELFAQ.hideItemDropdown( delay )
	-- 设置计时
	SELFAQ.itemDropdownTimestamp = GetTime()
	SELFAQ.itemDropdownDelay =  delay
end

-- 在update里执行
function SELFAQ.doHideItemDropdown()
	if SELFAQ.itemDropdownTimestamp then
		if GetTime() - SELFAQ.itemDropdownTimestamp > SELFAQ.itemDropdownDelay then
			for k,v in pairs(SELFAQ.itemButtons) do
	   		v:Hide()
	   	end
	   	SELFAQ.itemDropdownTimestamp = nil
			SELFAQ.showingSlot = nil
			SELFAQ.showingPosition = nil
		end
	end
end

-- 创建饰品下拉框
function SELFAQ.createItemDropdown(item_id, x, position, slot_id)

	if item_id == 0 then
		return
	end

	local pass_id = slot_id

	local rid = SELFAQ.reverseId(item_id)

	-- 分列，计算位置（固定4列）
	position = position - 1
		
	local newX = math.floor(position / 4)
	local newY = position % 4 + 1

   	local button

   	if SELFAQ.itemButtons[item_id] then
   		button = SELFAQ.itemButtons[item_id]
   	else
   		button = CreateFrame("Button", nil, UIParent)
   	end

   	button.pass_id = pass_id

	button:SetPoint("TOPLEFT", SELFAQ.bar, x + newX * (40 + AQSV.buttonSpacingNew), 5+(40 + AQSV.buttonSpacingNew) * newY)
	button:SetScale(AQSV.barZoom)

   	button:Show()

   	if SELFAQ.itemButtons[item_id] then
   		SELFAQ.itemButtons[item_id].inSlot = slot_id
		return
   	end

	
	button:SetFrameStrata("HIGH")

	button:SetSize(40, 40)

	local itemTexture = GetItemTexture(rid)

  	-- 暴雪风格：空槽背景
  	local bg = button:CreateTexture(nil, "BACKGROUND", nil, -1)
  	bg:SetTexture("Interface\\Buttons\\UI-Quickslot")
  	bg:SetPoint("TOPLEFT", -5, 5)
  	bg:SetPoint("BOTTOMRIGHT", 5, -5)

  	-- 暴雪风格：高亮
  	local hl = button:CreateTexture(nil, "HIGHLIGHT")
  	hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  	hl:SetBlendMode("ADD")
  	hl:SetAllPoints(button)

  	-- 暴雪风格：按下效果
  	local push = button:CreateTexture(nil, "ARTWORK")
  	push:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  	push:SetAllPoints(button)
  	button:SetPushedTexture(push)

    local t = button:CreateTexture(nil, "ARTWORK")
	t:SetTexture(itemTexture)
	t:SetAllPoints(button)

	-- 文字单独一个frame
	local tf = CreateFrame("Frame", nil, button)
	tf:SetAllPoints(button)
	tf:SetFrameLevel(101)

	-- 暴雪风格：计时文字
	local text = tf:CreateFontString(nil, "OVERLAY")
	text:SetFont(AQSV.fontPath or [[Fonts\FRIZQT__.TTF]], 16, "OUTLINE")
    text:SetPoint("CENTER", button, 0, 0)
    text:SetText("")
    button.text = text

	-- 按钮定位

   	button:SetScript("OnEnter", function(self)
   		-- 停掉隐藏下拉框的计时器
		SELFAQ.itemDropdownTimestamp = nil
		-- 显示物品提示（如果启用）
		if AQSV.enableTooltip then
			local rid = SELFAQ.reverseId(item_id)
			if rid then
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
				GameTooltip:SetItemByID(rid)
				GameTooltip:Show()
			end
		end
	end)
   	button:SetScript("OnLeave", function( self )
   		-- 开启隐藏计时
   		SELFAQ.hideItemDropdown( 0.5 )
   		if AQSV.enableTooltip then
   			GameTooltip:Hide()
   		end
   	end)

	button.inSlot = slot_id

   	button:EnableMouse(true)
   	button:RegisterForClicks("AnyDown");
	button:SetScript('OnClick', function(self, b)

		-- 点击后立即隐藏下拉框
	    for k,v in pairs(SELFAQ.itemButtons) do
   		v:Hide()
   	end

   		local slot = button.inSlot

        if not SELFAQ.playerCanEquip() then
            return 
        else
        	SELFAQ.equipByID(item_id, slot)
        end
       
	end)

   	-- 缓存
   	SELFAQ.itemButtons[item_id] = button
end

-- 更新按钮材质
function SELFAQ.updateItemButton( slot_id )
	local itemId = GetInventoryItemID("player", slot_id)
	local button = SELFAQ.slotFrames[slot_id]

	if not button then return end

	button.itemId = itemId

	local itemTexture = ""
	if itemId then
		itemTexture = GetItemTexture(itemId)
	else
		_, itemTexture = GetInventorySlotInfo(SELFAQ.slotName[slot_id])
	end

	if button.texture then
		button.texture:SetTexture(itemTexture)
	end
end

function SELFAQ.bindingSlot( )
	if UnitAffectingCombat("player") then return end

	for k,v in pairs(SELFAQ.slotFrames) do
		ClearOverrideBindings(v)

		v.shortcut:SetText("")
		v.shortcut:Hide()

		local keys = {GetBindingKey("GEARBAR_BUTTON"..k)}

		for k1,v1 in pairs(keys) do

			if v1 and v1 ~= "" then
				SetOverrideBindingClick(v, false, v1, "AQButton"..k)

				v.shortcut:SetText(v1)
				v.shortcut:Show()
			end
		end
	end

end

-- 绘制下方的饰品队列
function SELFAQ.cooldownUpdate( self, elapsed )
	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;  

    if (self.TimeSinceLastUpdate > self.Interval) then
    	-- 重新计时
        self.TimeSinceLastUpdate = 0

        SELFAQ.doHideItemDropdown()

		-- 计算饰品下拉框的冷却时间
		for k,v in pairs(SELFAQ.itemButtons) do
				-- 获取饰品的冷却状态
				local rid = SELFAQ.reverseId(k)

			    local start, duration, enable = C_Container.GetItemCooldown(rid)
                if not start or not duration or not enable then
                    return
                end
			    -- 剩余冷却时间
			    local rest =(duration - GetTime() + start)

			    -- 在队列中的显示冷却时间
			    if duration > 0 and rest > 0 then
			    	-- 设置冷却时间
			    	v.text:SetText(math.floor(rest))
			    else
			    	v.text:SetText("")
			    end
		end

		-- 计算装备栏的冷却时间
    	for key, value in pairs(SELFAQ.slots) do

    		local button = SELFAQ.slotFrames[value]

    		if button == nil then
    			return
    		end

    		local itemId = GetInventoryItemID("player", value)

    		if itemId then
			    local start, duration, enable = C_Container.GetItemCooldown(itemId)
                if not start or not duration or not enable then
                    return
                end
			    local rest = duration - GetTime() + start

			    if duration > 0 and rest > 0 then
			    	button.cooldown:SetCooldown(start, duration)
			    	button.cooldown:Show()
			    else
			    	button.cooldown:Hide()
			    end
			else
				local button = SELFAQ.slotFrames[value]
				-- 装备被换下，清空倒计时
				button.cooldown:Hide()
    		end


    		-- 判断是否是需要更换的slot（冷却队列已移除）

    	end

    end
end