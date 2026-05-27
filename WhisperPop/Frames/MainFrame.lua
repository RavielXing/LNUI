------------------------------------------------------------
-- MainFrame.lua
--
-- Abin
-- 2015-9-06
------------------------------------------------------------

local format = format
local CreateFrame = CreateFrame
local IsShiftKeyDown = IsShiftKeyDown
local IsAltKeyDown = IsAltKeyDown
local floor = floor

local addon = WhisperPop
local L = addon.L

local frame = addon.templates.CreateFrame("WhisperPopFrame", UIParent)
addon.frame = frame

function addon:ToggleFrame()
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

frame:HookScript("OnShow", function()
	addon:RefreshSearchListBinding()
end)

addon.OnClashCmd = addon.ToggleFrame

frame.text:SetText(LOCALE_zhCN and "密语管理" or "密語管理")--lnui
frame.defaultPos = {"CENTER", 0, -20}
frame:SetSize(200, 324)

local list = UICreateVirtualScrollList(frame:GetName().."List", frame, 1, nil, nil, "icon")
frame.list = list
list:SetPoint("TOPLEFT", 7, -34)
list:SetPoint("TOPRIGHT", -7, -34)
list:SetHeight(20)
list:SetScrollBarScale(0.75)

local delButton = CreateFrame("Button", list:GetName().."Delete", list, "UIPanelCloseButton")
addon.templates.RegisterDelayHideFrame(delButton)
delButton:SetSize(24, 24)
delButton:SetMotionScriptsWhileDisabled(true)
delButton:Hide()

local function DelButton_SetTooltip(self)
	GameTooltip:ClearLines()
	GameTooltip:AddLine(DELETE)
	GameTooltip:AddLine(format(L["delete player records"], addon:GetDisplayName(self.name)), 1, 1, 1, 1)
	GameTooltip:Show()
end

delButton:HookScript("OnEnter", function(self)
	addon.messageFrame:StopCounting()
	list:TextureButton("highlightTexture", self:GetParent())
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	DelButton_SetTooltip(self)
end)

delButton:HookScript("OnLeave", function(self)
	addon.messageFrame:StartCounting()
	GameTooltip:Hide()
	list:TextureButton("highlightTexture")
end)

local function DelButton_DoDelete(name)
	addon:Delete(name)
end

delButton:SetScript("OnClick", function(self)
	addon.messageFrame:Hide()
	local name = self.name
	if name and addon.db.deleteConfirm then
		addon:PopupShowConfirm(format(L["delete conversation confirm"], addon:GetDisplayName(name)), DelButton_DoDelete, name)
	else
		addon:Delete(name)
	end
end)

function list:OnButtonCreated(button)
	button:RegisterForClicks("AnyUp")

	button.lock = button:CreateIcon("Interface\\LFGFrame\\UI-LFG-ICON-LOCK", 0.75, 0.75, 1, 0.75)
	button.lock:SetPoint("RIGHT", -2, -1)
	button.lock:Hide()

	button.text:SetPoint("RIGHT", button.lock, "LEFT")

	local fo = _G[addon:GetContentFontObjectName()]
	if fo and button.text and button.text.SetFontObject then
		pcall(button.text.SetFontObject, button.text, fo)
	end
end

function list:OnButtonUpdate(button, data)
	addon.templates.ShowPlayerInfo(data, button.icon, button.text)
	if data.new then
		button.text:SetTextColor(0, 1, 0)
	elseif data.received then
		button.text:SetTextColor(1, 1, 1)
	else
		button.text:SetTextColor(0.5, 0.5, 0.5)
	end

	if data.protected then
		button.lock:Show()
	else
		button.lock:Hide()
	end

	if delButton:IsShown() and delButton:GetParent() == button then
		delButton.name = data.name
		DelButton_SetTooltip(delButton)
	end
end

function list:OnButtonEnter(button, data)
	if data.protected then
		delButton:Hide()
	else
		delButton:SetParent(button)
		delButton:ClearAllPoints()
		delButton:SetPoint("RIGHT", button, "RIGHT")
		delButton.data = data
		delButton.name = data.name
		delButton:StopCounting(1)
	end

	if addon.db.receiveOnly and not data.received then
		addon.messageFrame:Hide()
		return
	end

	if data.new then
		data.new = nil
		button.text:SetTextColor(1, 1, 1)
		-- Repaint this row only; skip full virtual list refresh (still notify LDB / notify button).
		local pos = list:FindData(data)
		if pos then
			list:UpdateData(pos)
		end
		addon._suppressNextListFullRefresh = true
		addon:BroadcastEvent("OnListUpdate")
		addon._suppressNextListFullRefresh = nil
	end

	addon.messageFrame:ClearAllPoints()

	if button:GetLeft() > 500 then
		addon.messageFrame:SetPoint("RIGHT", button, "LEFT", -6, 0)
	else
		addon.messageFrame:SetPoint("LEFT", button, "RIGHT", 18, 0)
	end

	addon.messageFrame:SetData(button, data)
	addon.messageFrame:StopCounting()
end

function list:OnButtonLeave(button, data)
	addon.messageFrame:StartCounting()
	delButton:StartCounting()
end

function list:OnButtonClick(button, data, flag)
	local action
	if flag == "RightButton" then
		action = "MENU"
	elseif flag == "LeftButton" then
		if IsShiftKeyDown() then
			action = "WHO"
		elseif IsAltKeyDown() then
			action = "INVITE"
		else
			action = "WHISPER"
		end
	end
	addon:HandleAction(data.name, action)
end

addon:RegisterEventCallback("OnInitialize", function(db)
	list:BindDataList(db.history)
	if list.SetMouseWheelLines then
		list:SetMouseWheelLines(db.listWheelLines)
	end
end)

addon:RegisterEventCallback("OnListUpdate", function()
	if addon._suppressNextListFullRefresh then
		return
	end
	if not frame:IsShown() then
		return
	end
	addon:RefreshSearchListBinding()
end)

addon:RegisterOptionCallback("showRealm", function(value)
	addon:BroadcastEvent("OnListUpdate")
end)

addon:RegisterOptionCallback("foreignOnly", function(value)
	addon:BroadcastEvent("OnListUpdate")
end)

addon:RegisterOptionCallback("listScale", function(value)
	frame:SetScale(value / 100)
end)

addon:RegisterOptionCallback("listWidth", function(value)
	frame:SetWidth(value)
end)

addon:RegisterOptionCallback("listHeight", function(value)
	frame:SetHeight(value + 4)
	local pageSize = floor((value - 40) / 20)
	list:SetHeight(pageSize * 20)
	list:SetPageSize(pageSize)
end)

addon:RegisterOptionCallback("listWheelLines", function(value)
	if list.SetMouseWheelLines then
		list:SetMouseWheelLines(value)
	end
end)

addon:RegisterEventCallback("OnResetFrames", function()
	frame:ClearAllPoints()
	frame:SetPoint(unpack(frame.defaultPos))
	addon:SavePosition(frame)
end)