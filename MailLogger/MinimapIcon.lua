local _, Addon = ...
local L = Addon.L
local MinimapIcon = Addon.MinimapIcon
local Output = Addon.Output
local IsButtonDown = false

-- 初始化标志，防止动态加载时重复创建
MinimapIcon.initialized = false

if LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true) and LibStub:GetLibrary("LibDBIcon-1.0", true) then
	Addon.LDB = LibStub("LibDataBroker-1.1")
	Addon.LDBIcon = LibStub("LibDBIcon-1.0")
else
	Addon.LDB = nil
	Addon.LDBIcon = nil
end
local LDB = Addon.LDB
local LDBIcon = Addon.LDBIcon

if LDB and LDBIcon then
	-- LDB 小地图图标
	function MinimapIcon:InitBroker()
        if MinimapIcon.initialized then return end
		local texture = "Interface\\MINIMAP\\TRACKING\\Mailbox"
		MinimapIcon.Broker = LDB:NewDataObject("MailLogger", {
			type = "launcher",
			text = "MailLogger",
			icon = texture,
			OnClick = MinimapIcon.MinimapOnClick,
			OnTooltipShow = MinimapIcon.MinimapOnEnter,
		})
		MinimapIcon.minimap = MinimapIcon.minimap or {hide = false}
		MinimapIcon.minimap.minimapPos = Addon.Config.MinimapIconAngle or 345
		LDBIcon:Register("MailLogger", MinimapIcon.Broker, MinimapIcon.minimap)
		MinimapIcon:ShowMinimap()
        MinimapIcon.initialized = true
	end

	function MinimapIcon:ShowMinimap()
		if Addon.Config.ShowMinimapIcon then
			LDBIcon:Show("MailLogger")
		else
			LDBIcon:Hide("MailLogger")
		end
	end

	function MinimapIcon:MinimapOnClick(button)
		if not Output.background then
			Addon.SetWindow:Initialize()
			Addon.Output:Initialize()
			Addon.Calendar:Initialize()
		end
		
		if IsShiftKeyDown() then
			if button == "LeftButton" then
				Output.background:ClearAllPoints()
				Output.background:SetPoint("RIGHT", nil, "RIGHT", -20, 0)
				Addon.Calendar.background:ClearAllPoints()
				Addon.Calendar.background:SetPoint("TOPRIGHT", Addon.Output.background, "TOPLEFT", 1, 0)
				Addon.SetWindow.background:ClearAllPoints()
				Addon.SetWindow.background:SetPoint("CENTER", -210, 0)
			elseif button == "RightButton" then
				LDBIcon:Hide("MailLogger")
				MinimapIcon.minimap.minimapPos = 345
				Addon.Config.MinimapIconAngle = 345
				LDBIcon:Show("MailLogger")
			end
		else
			if button == "LeftButton" then
				if Output.background:IsShown() and Output.export:GetParent():IsShown() then
					Output.export:GetParent():Hide()
					Output.background:Hide()
					Addon.Calendar.background:Hide()
				else
					Output.dropdowntitle:Show()
					Output.dropdownlist:Show()
					Output.dropdownbutton:Show()
					Addon:PrintTradeLog("ALL", nil)
					if Addon.Config.EnableCalendar then
						Addon:GetAvailableDate()
						Addon.Calendar.background:Show()
						Addon:RefreshCalendar()
					end
				end
			elseif button == "RightButton" then
				if Addon.SetWindow.background:IsShown() then
					Addon.SetWindow.background:Hide()
				else
					Addon.SetWindow.background:Show()
				end
			end
		end
	end

	-- ========== LDB 提示框：紧贴按钮右侧 ==========
	function MinimapIcon:MinimapOnEnter(tooltip)
		local tip = tooltip or GameTooltip
		tip:ClearLines()
		-- 固定锚点：图标右侧，紧贴显示
		tip:SetOwner(self, "ANCHOR_RIGHT", 2, 0)
		tip:AddLine("MailLogger", 1, 1, 1)
		tip:AddLine("邮件、交易自动记录", 0.8, 0.8, 0.8)
		tip:AddLine(" ")
		tip:AddLine("|cFF00FF00左键点击|r 进入交易历史记录")
		tip:AddLine("|cFF00FF00右键点击|r 进入设置界面")
		tip:AddLine("|cFF00FF00Shift+左键|r 恢复日志窗口位置")
		tip:AddLine("|cFF00FF00Shift+右键|r 恢复小地图图标位置")
		tip:Show()
	end	
else
	-- 原生可拖动小地图按钮
	function Addon:UpdatePosition(pos)
		local angle = math.rad(pos or 345)
		local x, y = math.cos(angle), math.sin(angle)
		local MinimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
		local w = (Minimap:GetWidth() / 2) + 5
		local h = (Minimap:GetHeight() / 2) + 5
		if MinimapShape == "ROUND" then
			x, y = x * w, y * h
		else
			local diagRadiusW = math.sqrt(2 * (w) ^ 2) - 10
			local diagRadiusH = math.sqrt(2 * (h) ^ 2) - 10
			x = math.max(-w, math.min(x * diagRadiusW, w))
			y = math.max(-h, math.min(y * diagRadiusH, h))
		end
		MinimapIcon.Minimap:ClearAllPoints()
		MinimapIcon.Minimap:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end

	local function UpdateMapBtn()
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		px, py = px / scale, py / scale
		local pos = math.deg(math.atan2(py - my, px - mx)) % 360
		Addon.Config.MinimapIconAngle = pos
		Addon:UpdatePosition(pos)
	end

	function MinimapIcon:Initialize()
        if MinimapIcon.initialized then return end
		local b = CreateFrame("Button", "MailLoggerMinimapIcon", Minimap, "SecureActionButtonTemplate")
		b:SetFrameStrata("HIGH")
		b:SetToplevel(true)
		if b.SetFixedFrameStrata then
			b:SetFixedFrameStrata(true)
		end
		b:SetFrameLevel(8)
		if b.SetFixedFrameLevel then
			b:SetFixedFrameLevel(true)
		end
		b:SetSize(31, 31)
		b:SetHighlightTexture(136477)
		b.overlay = b:CreateTexture(nil, "OVERLAY")
		b.overlay:SetSize(53, 53)
		b.overlay:SetTexture(136430)
		b.overlay:SetPoint("TOPLEFT")
		b.background = b:CreateTexture(nil, "BACKGROUND")
		b.background:SetSize(20, 20)
		b.background:SetTexture(136467)
		b.background:SetPoint("TOPLEFT", 7, -5)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(17, 17)
		b.icon:SetTexture("Interface\\MINIMAP\\TRACKING\\Mailbox")
		b.icon:SetPoint("TOPLEFT", 7, -6)

		b:EnableMouse(true)
		b:SetMovable(true)
		b:RegisterForDrag("LeftButton")
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		b:SetScript("OnDragStart", function()
			b:StartMoving()
			IsButtonDown = true
			b:SetScript("OnUpdate", UpdateMapBtn)
			GameTooltip:Hide()
		end)
		b:SetScript("OnDragStop", function()
			b:StopMovingOrSizing()
			IsButtonDown = false
			b:SetScript("OnUpdate", nil)
			UpdateMapBtn()
		end)
		b:SetScript("OnMouseDown", function(self)
			b.background:SetTexCoord(0.075, 0.925, 0.075, 0.925)
			IsButtonDown = true
		end)
		b:SetScript("OnMouseUp", function(self)
			b.background:SetTexCoord(0, 1, 0, 1)
			IsButtonDown = false
		end)

		-- ========== 原生按钮提示框：紧贴按钮右侧 ==========
		b:SetScript("OnEnter", function(self)
			if not self:IsMouseOver() then return end
			GameTooltip:ClearLines()
			-- 固定在按钮右侧，偏移极小，紧贴显示
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 2, 0)
			GameTooltip:AddLine("MailLogger", 1, 1, 1)
			GameTooltip:AddLine("邮件、交易自动记录", 0.8, 0.8, 0.8)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("|cFF00FF00左键点击|r 进入交易历史记录")
			GameTooltip:AddLine("|cFF00FF00右键点击|r 进入设置界面")
			GameTooltip:AddLine("|cFF00FF00Shift+左键|r 恢复日志窗口位置")
			GameTooltip:AddLine("|cFF00FF00Shift+右键|r 恢复小地图图标位置")
			GameTooltip:Show()
		end)

		b:SetScript("OnLeave", function(self)
			C_Timer.After(0.1, function()
				if not self:IsMouseOver() then
					GameTooltip:Hide()
				end
			end)
		end)

		b:SetScript("OnClick", function(self, button)
			if not Output.background then
				Addon.SetWindow:Initialize()
				Addon.Output:Initialize()
				Addon.Calendar:Initialize()
			end
			
			if IsShiftKeyDown() then
				if button == "LeftButton" then
					Output.background:ClearAllPoints()
					Output.background:SetPoint("RIGHT", nil, "RIGHT", -20, 0)
					Addon.Calendar.background:ClearAllPoints()
					Addon.Calendar.background:SetPoint("TOPRIGHT", Addon.Output.background, "TOPLEFT", 1, 0)
					Addon.SetWindow.background:ClearAllPoints()
					Addon.SetWindow.background:SetPoint("CENTER", -210, 0)
				elseif button == "RightButton" then
					Addon.Config.MinimapIconAngle = 345
					Addon:UpdatePosition(Addon.Config.MinimapIconAngle)
				end
			else
				if button == "LeftButton" then
					if Output.background:IsShown() and Output.export:GetParent():IsShown() then
						Output.export:GetParent():Hide()
						Output.background:Hide()
						Addon.Calendar.background:Hide()
					else
						Output.dropdowntitle:Show()
						Output.dropdownlist:Show()
						Output.dropdownbutton:Show()
						Addon:PrintTradeLog("ALL", nil)
						if Addon.Config.EnableCalendar then
							Addon:GetAvailableDate()
							Addon.Calendar.background:Show()
							Addon:RefreshCalendar()
						end
					end
				elseif button == "RightButton" then
					if Addon.SetWindow.background:IsShown() then
						Addon.SetWindow.background:Hide()
					else
						Addon.SetWindow.background:Show()
					end
				end
			end
		end)
		self.Minimap = b
        MinimapIcon.initialized = true
	end
end