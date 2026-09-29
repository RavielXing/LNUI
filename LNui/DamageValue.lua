U1PLUG["DamageValue"] = function()
--by:简繁,伤害统计始终简化数值

local NumberData = {
	config = CreateAbbreviateConfig({
		{
			breakpoint = 1e10,--123亿
			abbreviation = LOCALE_zhCN and "亿" or "億",
			significandDivisor = 1e8,
			fractionDivisor = 1,
			abbreviationIsGlobal = false
		},
		{
			breakpoint = 1e9,--12.3亿
			abbreviation = LOCALE_zhCN and "亿" or "億",
			significandDivisor = 1e7,
			fractionDivisor = 10,
			abbreviationIsGlobal = false
		},
		{
			breakpoint = 1e8,--1.23亿
			abbreviation = LOCALE_zhCN and "亿" or "億",
			significandDivisor = 1e6,
			fractionDivisor = 100,
			abbreviationIsGlobal = false
		},
		{
			breakpoint = 1e6,--123万
			abbreviation = LOCALE_zhCN and "万" or "萬",
			significandDivisor = 1e4,
			fractionDivisor = 1,
			abbreviationIsGlobal = false
		},
		{
			breakpoint = 1e4,--1.2万
			abbreviation = LOCALE_zhCN and "万" or "萬",
			significandDivisor = 1e3,
			fractionDivisor = 10,
			abbreviationIsGlobal = false
		},
		{
			breakpoint = 1,
			abbreviation = "",
			significandDivisor = 1,
			fractionDivisor = 1,
			abbreviationIsGlobal = false
		},
	}),
}
local function GetMainValue(entry)
	if entry.valuePerSecond and entry:ShowsValuePerSecondAsPrimary() then
		return entry.valuePerSecond;
	end

	if entry.value then
		return entry.value;
	end

	return 0;
end
local function GetParentheticalValue(entry)
	if entry.value and entry:ShowsValuePerSecondAsPrimary() then
		return entry.value;
	end

	if entry.valuePerSecond then
		return entry.valuePerSecond;
	end

	return 0;
end
local function GetPercentageValue(entry)
	if entry.value and entry.sessionTotalValue and entry.sessionTotalValue > 0 then
		return entry.value / entry.sessionTotalValue;
	end

	return 0;
end
local function GetEntryValueText(value, parentheticalValue, percentageValue)
	if percentageValue then
		return DAMAGE_METER_ENTRY_FORMAT_COMPLETE:format(AbbreviateNumbers(value,NumberData), AbbreviateNumbers(parentheticalValue,NumberData), Round(percentageValue * 100));
	elseif parentheticalValue then
		return DAMAGE_METER_ENTRY_FORMAT_COMPACT:format(AbbreviateNumbers(value,NumberData), AbbreviateNumbers(parentheticalValue,NumberData));
	else
		return DAMAGE_METER_ENTRY_FORMAT_MINIMAL:format(AbbreviateNumbers(value,NumberData));
	end
end
local numberDisplayTypeFormatters =
{
	[Enum.DamageMeterNumbers.Minimal] = function(entry) return GetEntryValueText(GetMainValue(entry)); end,
	[Enum.DamageMeterNumbers.Compact] = function(entry) return GetEntryValueText(GetMainValue(entry), GetParentheticalValue(entry)); end,
	[Enum.DamageMeterNumbers.Complete] = function(entry) return GetEntryValueText(GetMainValue(entry), GetParentheticalValue(entry), GetPercentageValue(entry)); end,
}
local function GetValueText(self)
	return numberDisplayTypeFormatters[self:GetNumberDisplayType()](self);
end
hooksecurefunc(DamageMeterEntryMixin, "Init", function(self)
	if self.MYHOOK then return end
	self.MYHOOK = true
	hooksecurefunc(self, "UpdateValue", function(bar)
		if bar:GetNumberDisplayType() == Enum.DamageMeterNumbers.Complete then
			return
		end
		local text = GetValueText(bar)
		local valueText = bar:GetValue()
		valueText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
		valueText:SetText(text);
	end)
end)

--============ 伤害统计窗口拖动 + 位置保存 ============
--拖动时移动伤害统计的容器框架(DamageMeterFrame),窗口作为子框架刚性跟随,
--编辑模式的蓝色选框锚定在容器上,因此始终与窗口重合,可同步移动/缩放。
--位置保存在官方角色存档表 DamageMeterPerCharacterSettings 内。
--编辑模式:打开时不移动窗口(蓝框自然跟过来),期间只记录官方操作不干预,
--退出时若改过则以官方配置为准收养,没改过则恢复插件保存的拖动位置。

local METER_KEY = "meter"

local function IsEditModeOpen()
	local f = _G.EditModeManagerFrame
	return f and f:IsShown() or false
end

local function GetSaveTable()
	local db = _G.DamageMeterPerCharacterSettings
	if type(db) ~= "table" then return nil end
	if type(db.U1WindowPosV2) ~= "table" then db.U1WindowPosV2 = {} end
	return db.U1WindowPosV2
end

--读取框架的完整锚点+尺寸(尺寸可能由两个对角锚点撑出,必须全部记录)
local function BuildPos(frame)
	local pos = { points = {}, w = select(1, frame:GetSize()), h = select(2, frame:GetSize()) }
	for i = 1, frame:GetNumPoints() do
		local point, relTo, relPoint, x, y = frame:GetPoint(i)
		pos.points[i] = {
			point = point,
			rel = relTo and relTo.GetName and relTo:GetName() or nil,
			relPoint = relPoint,
			x = x,
			y = y,
		}
	end
	return pos
end

local function SetPos(frame, pos)
	if not pos or not pos.points then return end
	frame.U1ApplyingPos = true
	frame:ClearAllPoints()
	if pos.w then frame:SetSize(pos.w, pos.h) end
	for _, p in ipairs(pos.points) do
		frame:SetPoint(p.point, (p.rel and _G[p.rel]) or UIParent, p.relPoint, p.x, p.y)
	end
	frame.U1ApplyingPos = false
end

--取伤害统计的容器框架(编辑模式选框锚定的对象);取不到则退回窗口本身
local function GetContainer(window)
	if window.U1MeterContainer then return window.U1MeterContainer end
	local c = _G.DamageMeterFrame or _G.DamageMeter
	if not (c and c.IsObjectType and c:IsObjectType("Frame")) then
		c = window:GetParent()
		local pname = (c and c.GetName and c:GetName()) or ""
		if not c or c == UIParent or not pname:find("DamageMeter") then
			c = window
		end
	end
	window.U1MeterContainer = c
	return c
end

local function ApplyPosition(window)
	local c = window.U1MeterContainer
	if not c then return end
	local save = GetSaveTable()
	local pos = save and save[METER_KEY]
	if not pos then return end
	if not pos.points then save[METER_KEY] = nil return end
	SetPos(c, pos)
end

local function FindTitleBar(window)
	if window.TitleBar and window.TitleBar.RegisterForDrag then
		return window.TitleBar
	end
	local queue = { window }
	while #queue > 0 do
		local f = table.remove(queue, 1)
		for _, child in ipairs({ f:GetChildren() }) do
			local debugName = child.GetDebugName and child:GetDebugName() or ""
			if debugName:lower():find("titlebar") and child.RegisterForDrag then
				return child
			end
			queue[#queue + 1] = child
		end
	end
	return nil
end

--把标题行上的按钮抬到指定层级之上,防止被拖动条挡住点击
local function RaiseAbove(frame, level)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.GetObjectType and child:GetObjectType() == "Button" and child.SetFrameLevel then
			child:SetFrameLevel(level)
			RaiseAbove(child, level)
		end
	end
end

--比较框架当前配置和给定配置是否一致(尺寸+首锚点)
local function IsSameConfig(frame, pos)
	if not pos or not pos.points then return true end
	local w, h = frame:GetSize()
	if pos.w and (math.abs(w - pos.w) > 0.5 or math.abs(h - pos.h) > 0.5) then return false end
	if frame:GetNumPoints() ~= #pos.points then return false end
	local p1, _, _, x1, y1 = frame:GetPoint(1)
	local sp = pos.points[1]
	if p1 ~= sp.point then return false end
	if math.abs((x1 or 0) - (sp.x or 0)) > 0.5 then return false end
	if math.abs((y1 or 0) - (sp.y or 0)) > 0.5 then return false end
	return true
end

local foundWindows = {}

local function AttachDrag(dragFrame, window, container)
	dragFrame:RegisterForDrag("LeftButton")
	--拖动开始时记录容器完整锚点结构(StartMoving会把多锚点塌缩成单锚点)
	dragFrame:HookScript("OnDragStart", function()
		if IsEditModeOpen() then return end
		if container.SetMovable then container:SetMovable(true) end	--编辑模式退出后官方会重置可移动标志
		local info = { points = BuildPos(container).points }
		info.w, info.h = container:GetSize()
		info.left, info.top = container:GetLeft() or 0, container:GetTop() or 0
		window.U1DragInfo = info
		container:StartMoving()
	end)
	dragFrame:HookScript("OnDragStop", function()
		container:StopMovingOrSizing()
		local info = window.U1DragInfo
		window.U1DragInfo = nil
		local save = GetSaveTable()
		if not save then return end
		if info and #info.points > 1 then
			--多锚点:按位移刚性还原全部锚点,保持原生结构
			local dx = (container:GetLeft() or 0) - info.left
			local dy = (container:GetTop() or 0) - info.top
			local pos = { points = {}, w = info.w, h = info.h }
			for i, p in ipairs(info.points) do
				pos.points[i] = {
					point = p.point, rel = p.rel, relPoint = p.relPoint,
					x = (p.x or 0) + dx, y = (p.y or 0) + dy,
				}
			end
			save[METER_KEY] = pos
		else
			save[METER_KEY] = BuildPos(container)
		end
	end)
end

--============ 常驻缩放手柄 ============
--复用编辑模式游戏自带的缩放标志(同款贴图/尺寸/位置),平时完全隐藏,
--鼠标悬停在窗口右下角区域时才显示;按住即可拖改大小,无需进编辑模式。
--松手后把最终锚点+尺寸写入官方角色存档,与拖动走同一条存档路径。

local function CreateResizeHandle(window, container)
	if window.U1ResizeHandle then return window.U1ResizeHandle end
	local base = window:GetFrameLevel()

	--热区:平时完全透明,鼠标进入窗口右下角这块区域才亮出手柄
	local zone = CreateFrame("Frame", nil, window)
	zone:SetSize(60, 60)
	zone:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 10, -10)
	zone:SetFrameLevel(base + 40)
	zone:EnableMouse(true)

	--手柄本体:与编辑模式EditModeResizeButton同款(60x60,同款atlas,同款偏移)
	local handle = CreateFrame("Button", nil, window)
	handle:SetSize(60, 60)
	handle:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 10, -10)
	handle:SetFrameLevel(base + 41)
	handle:SetNormalAtlas("damagemeters-scalehandle")
	handle:SetHighlightAtlas("damagemeters-scalehandle-hover")
	handle:SetPushedAtlas("damagemeters-scalehandle-pressed")
	handle:Hide()

	local hideTimer
	local function RefreshHandleVisibility()
		if window.U1Resizing then return end	--拖动过程中不隐藏
		if hideTimer then hideTimer:Cancel() end
		hideTimer = C_Timer.NewTimer(0.15, function()
			hideTimer = nil
			if IsEditModeOpen() then return end
			if zone:IsMouseOver() or handle:IsMouseOver() then return end
			handle:Hide()
		end)
	end

	zone:SetScript("OnEnter", function()
		if hideTimer then hideTimer:Cancel() hideTimer = nil end
		if IsEditModeOpen() then return end
		handle:Show()
	end)
	zone:SetScript("OnLeave", RefreshHandleVisibility)
	handle:SetScript("OnEnter", function()
		if hideTimer then hideTimer:Cancel() hideTimer = nil end
	end)
	handle:SetScript("OnLeave", RefreshHandleVisibility)

	--与官方EditModeResizeButton同一套交互:按下StartSizing,松手结算存档
	handle:SetScript("OnMouseDown", function(_, btn)
		if btn ~= "LeftButton" or IsEditModeOpen() then return end
		if container.SetResizable then container:SetResizable(true) end	--编辑模式退出后官方会重置可缩放标志
		container.U1ApplyingPos = true	--缩放期间逐帧的SetPoint/SetSize不写存档
		window.U1Resizing = true
		handle:GetHighlightTexture():Hide()
		container:StartSizing("BOTTOMRIGHT")
	end)
	handle:SetScript("OnMouseUp", function(_, btn)
		if btn ~= "LeftButton" or not window.U1Resizing then return end
		container:StopMovingOrSizing()
		window.U1Resizing = nil
		container.U1ApplyingPos = false
		container:SetUserPlaced(false)
		handle:GetHighlightTexture():Show()
		--StartSizing会把多锚点塌缩成单锚点,直接以塌缩后的锚点+新尺寸存档
		local save = GetSaveTable()
		if save then save[METER_KEY] = BuildPos(container) end
		container.U1NativePos = BuildPos(container)
		RefreshHandleVisibility()
	end)

	window.U1ResizeZone = zone
	window.U1ResizeHandle = handle
	return handle
end

--容器的挂钩只安装一次(多个窗口共享一个容器)
local function SetupContainer(container)
	if container.U1MeterHooked then return end
	container.U1MeterHooked = true

	if container.SetMovable then container:SetMovable(true) end
	if container.SetResizable then container:SetResizable(true) end
	container.U1NativePos = BuildPos(container)

	--官方给容器重新设锚点时:
	--常规:记录官方新锚点,再把插件保存的位置盖回去(防拉回)
	--编辑模式:只记录官方操作(pending),第一次(进入时的布局应用)后不再干预,
	--          让选框自由编辑,退出时统一结算
	pcall(hooksecurefunc, container, "SetPoint", function()
		if container.U1ApplyingPos then return end
		if IsEditModeOpen() then
			container.U1EditPendingPos = BuildPos(container)
			if not container.U1EditHandled then
				container.U1EditHandled = true
				local save = GetSaveTable()
				if save and save[METER_KEY] then SetPos(container, save[METER_KEY]) end
			end
			return
		end
		container.U1NativePos = BuildPos(container)
		local save = GetSaveTable()
		if not save or not save[METER_KEY] then return end
		SetPos(container, save[METER_KEY])
	end)

	--官方改尺寸时:
	--编辑模式:只记录不干涉(退出时由pending机制统一结算)
	--非编辑模式且插件已有存档:以插件尺寸为准——官方在登录/切换布局时会重新
	--          应用它自己存的宽高(SetSize),若此时收养就会把插件存的尺寸覆盖掉
	--          (重载后缩放回退的根因),所以要把尺寸拉回插件保存的值
	--没有插件存档:记录官方尺寸
	local function AdoptSize(w, h)
		if container.U1ApplyingPos then return end
		local save = GetSaveTable()
		if IsEditModeOpen() then
			if save and save[METER_KEY] then
				save[METER_KEY].w, save[METER_KEY].h = w, h
			end
			if container.U1NativePos then
				container.U1NativePos.w, container.U1NativePos.h = w, h
			end
			return
		end
		if save and save[METER_KEY] then
			local pos = save[METER_KEY]
			if math.abs(w - (pos.w or w)) > 0.5 or math.abs(h - (pos.h or h)) > 0.5 then
				SetPos(container, pos)
			end
			return
		end
		if container.U1NativePos then
			container.U1NativePos.w, container.U1NativePos.h = w, h
		end
	end
	pcall(hooksecurefunc, container, "SetSize", function(_, w, h) AdoptSize(w, h) end)
	pcall(hooksecurefunc, container, "SetWidth", function(_, w) AdoptSize(w, select(2, container:GetSize())) end)
	pcall(hooksecurefunc, container, "SetHeight", function(_, h) AdoptSize(select(1, container:GetSize()), h) end)

	container:HookScript("OnShow", function()
		if IsEditModeOpen() then return end
		local save = GetSaveTable()
		local pos = save and save[METER_KEY]
		if pos then SetPos(container, pos) end
	end)
end

--只有主窗口锚定在伤害统计容器上(位置/尺寸由编辑模式控制,由本插件代理拖动和缩放);
--新建的副窗口直接锚定在UIParent上,原生就支持自己拖动/缩放(悬停窗口时右下角
--会出现原生缩放按钮)。副窗口若也挂拖动条/缩放手柄,操作会被拦截转发到共享容器上,
--结果变成第一个窗口在动、副窗口动不了
local function IsPrimaryWindow(window)
	local owner = window.GetDamageMeterOwner and window:GetDamageMeterOwner()
	if owner and owner.GetPrimarySessionWindow then
		return owner:GetPrimarySessionWindow() == window
	end
	local name = (window.GetName and window:GetName()) or ""
	local n = tonumber(name:match("(%d+)$"))
	return n == nil or n == 1
end

local function SetupWindow(window, index)
	if not window or window.U1DragHooked then return end
	window.U1DragHooked = true

	local container = GetContainer(window)
	SetupContainer(container)

	--副窗口:完全不干预,交给暴雪原生拖动/缩放(若被下拉菜单设成了"锁定"则原生也不允许动)
	if not IsPrimaryWindow(window) then
		return
	end

	--拖动条/标题栏挂在窗口上,拖动时移动容器,窗口刚性跟随
	local titleBar = FindTitleBar(window)
	if titleBar then
		AttachDrag(titleBar, window, container)
	else
		--自建隐形拖动条,覆盖窗口顶部约26像素
		--层级:窗口 < 原生子元素 < 拖动条 < 按钮,保证能接到鼠标又不挡按钮
		local base = window:GetFrameLevel()
		local strip = CreateFrame("Frame", nil, window)
		strip:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
		strip:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
		strip:SetHeight(26)
		strip:SetFrameLevel(base + 10)
		strip:EnableMouse(true)
		window.U1DragStrip = strip
		RaiseAbove(window, base + 20)
		AttachDrag(strip, window, container)
	end

	--常驻右下角缩放手柄(免编辑模式直接缩放)
	CreateResizeHandle(window, container)

	window:HookScript("OnShow", function()
		if IsEditModeOpen() then return end
		ApplyPosition(window)
	end)

	ApplyPosition(window)
end

local function CollectWindows()
	for i = 1, 5 do
		local w = _G["DamageMeterSessionWindow" .. i]
		if w then foundWindows[w] = i end
	end
	for name, obj in pairs(_G) do
		if type(obj) == "table" and type(name) == "string"
			and name:find("^DamageMeterSessionWindow%d+$")
			and obj.GetObjectType and obj:GetObjectType() == "Frame" then
			local n = tonumber(name:match("%d+"))
			if n then foundWindows[obj] = foundWindows[obj] or n end
		end
	end
	return foundWindows
end

--编辑模式:打开时禁用拖动条、重置编辑状态(不移动窗口,蓝框跟过来);
--退出时:改过则收养官方配置,没改过则恢复插件保存的拖动位置
local editModeHooked = false
local function HookEditMode()
	if editModeHooked then return end
	local em = _G.EditModeManagerFrame
	if not em then return end
	editModeHooked = true
	em:HookScript("OnShow", function()
		for w in pairs(foundWindows) do
			if w.U1DragStrip then w.U1DragStrip:EnableMouse(false) end
			if w.U1ResizeHandle then w.U1ResizeHandle:Hide() end
			if w.U1ResizeZone then w.U1ResizeZone:Hide() end	--热区藏起来,不挡官方手柄
			local c = w.U1MeterContainer
			if c then
				c.U1EditPendingPos = nil
				c.U1EditHandled = false
			end
		end
	end)
	em:HookScript("OnHide", function()
		for w, i in pairs(foundWindows) do
			if w.U1DragStrip then w.U1DragStrip:EnableMouse(true) end
			if w.U1ResizeZone then w.U1ResizeZone:Show() end
			--手柄平时保持隐藏,只有鼠标正悬停在右下角热区上才亮出
			if w.U1ResizeHandle and w.U1ResizeZone and w.U1ResizeZone:IsMouseOver() then
				w.U1ResizeHandle:Show()
			end
			local c = w.U1MeterContainer
			if c then
				local pending = c.U1EditPendingPos
				c.U1EditPendingPos = nil
				c.U1EditHandled = false
				local save = GetSaveTable()
				if pending and save and not IsSameConfig(c, c.U1NativePos) then
					--用户在编辑模式里改过:以官方配置为准
					save[METER_KEY] = pending
					c.U1NativePos = pending
					SetPos(c, pending)
				elseif save and save[METER_KEY] then
					--没动过:恢复插件保存的拖动位置
					SetPos(c, save[METER_KEY])
				end
			end
		end
	end)
end

local function SetupAllWindows()
	CollectWindows()
	HookEditMode()
	for w, i in pairs(foundWindows) do
		pcall(SetupWindow, w, i)
	end
end

local dragEvent = CreateFrame("Frame")
dragEvent:RegisterEvent("ADDON_LOADED")
dragEvent:RegisterEvent("PLAYER_LOGIN")
dragEvent:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 ~= "Blizzard_DamageMeter" then return end
	C_Timer.After(0.5, SetupAllWindows)
	if event == "PLAYER_LOGIN" then
		C_Timer.After(3, SetupAllWindows)
		dragEvent:UnregisterEvent("PLAYER_LOGIN")
	end
end)
SetupAllWindows()
C_Timer.NewTicker(5, SetupAllWindows)

end
