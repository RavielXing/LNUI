local _, Addon = ...

local Output = Addon.Output
local Config = Addon.Config
local L = Addon.L

--初始化Export窗口
function Output:Initialize()
    local f = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
    f:SetWidth(360)
    f:SetHeight(510)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 8, right = 8, top = 10, bottom = 10}
    })
    f:SetBackdropColor(0, 0, 0)
    f:SetPoint(Config.OutputFramePos[1], nil, Config.OutputFramePos[3], Config.OutputFramePos[4], Config.OutputFramePos[5])
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            f:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        f:StopMovingOrSizing()
        Config.OutputFramePos[1], _, Config.OutputFramePos[3], Config.OutputFramePos[4], Config.OutputFramePos[5] = f:GetPoint()
    end)
    f:SetPropagateKeyboardInput(false)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            f:SetPropagateKeyboardInput(false)
            f:Hide()
            Addon.Calendar.background:Hide()
        else
            f:SetPropagateKeyboardInput(true)
        end
    end)
    f:Hide()
	self.background = f
    do -- 创建框体标题栏纹理
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetTexture("Interface/DialogFrame/UI-DialogBox-Header")
        t:SetWidth(360)
        t:SetHeight(64)
        t:SetPoint("TOP", f, 0, 12)
        f.texture = t
    end
    do -- 创建框体标题
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        t:SetText("")
        t:SetPoint("TOP", f.texture, 0, -12) -- 向上移动10像素
        self.title = t
    end
    do -- 下部按钮群
        local buttonWidth = 70 -- 缩小按钮宽度
        local buttonHeight = 36
        local spacing = 10 -- 按钮间距
        local totalWidth = f:GetWidth() - 40 -- 总宽度减去边距
        local startX = (totalWidth - (buttonWidth * 4 + spacing * 3)) / 2 + 20 -- 计算起始位置，使按钮居中并向右移动20像素
        
        local tl = CreateFrame("Button", nil, f, "GameMenuButtonTemplate") -- 显示交易
        tl:SetWidth(buttonWidth)
        tl:SetHeight(buttonHeight)
        tl:SetPoint("BOTTOMLEFT", startX, 10)
        tl:SetText(L["Trades"])
        tl:SetScript("OnClick", function(self) Addon.Config.Mode = "TRADE" Addon:PrintTradeLog(Config.Mode, (Config.OnlyThisCharacter and Config.SelectName or nil)) end)
        
        local ml = CreateFrame("Button", nil, f, "GameMenuButtonTemplate") -- 显示邮件
        ml:SetWidth(buttonWidth)
        ml:SetHeight(buttonHeight)
        ml:SetPoint("LEFT", tl, "RIGHT", spacing, 0)
        ml:SetText(L["Mails"])
        ml:SetScript("OnClick", function(self) Addon.Config.Mode = "MAIL" Addon:PrintTradeLog(Config.Mode, (Config.OnlyThisCharacter and Config.SelectName or nil)) end)
        
        local all = CreateFrame("Button", nil, f, "GameMenuButtonTemplate") -- 显示全部
        all:SetWidth(buttonWidth)
        all:SetHeight(buttonHeight)
        all:SetPoint("LEFT", ml, "RIGHT", spacing, 0)
        all:SetText(L["All"])
        all:SetScript("OnClick", function(self) Addon.Config.Mode = "ALL" Addon:PrintTradeLog(Config.Mode, (Config.OnlyThisCharacter and Config.SelectName or nil)) end)
        Addon.Config.OnlyThisCharacter = false
        
        local cls = CreateFrame("Button", nil, f, "GameMenuButtonTemplate") -- 关闭按钮
        cls:SetWidth(buttonWidth)
        cls:SetHeight(buttonHeight)
        cls:SetPoint("LEFT", all, "RIGHT", spacing, 0)
        cls:SetText(CLOSE)
        cls:SetScript("OnClick", function()
            f:Hide()
            Addon.Calendar.background:Hide()
        end)
    end
    do -- 角色筛选下拉菜单
        local d = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmallLeft")
        t:SetText(L["Alt Name"])
        t:SetPoint("LEFT", d, "LEFT", -60, 2) -- 向左移动标签，使其更靠左

        d:SetScript("OnShow", function(self)
            local value = {}
            local text = {}
            local index = 1

            for k in pairs(Addon.Config.AltList) do
                table.insert(value, index)
                table.insert(text, k)
                index = index + 1
            end

            UIDropDownMenu_Initialize(d, function(self, level, menuList)
                d.text = text
                for i = 1, #text do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = text[i]
                    info.value = value[i]
                    info.isNotRadio = false
                    info.checked = (Addon.Config.SelectName == text[i])
                    info.func = function(self)
                        Addon.Config.SelectName = text[self.value]
                        UIDropDownMenu_SetText(d, text[self.value])
                        CloseDropDownMenus()
                    end
                    info.arg1 = d
                    info.arg2 = value[i]
                    UIDropDownMenu_AddButton(info, level or 1)
                end
            end)
            d.SetValue = function(v) Addon.Config.SelectName = text[v] end
            UIDropDownMenu_SetText(self, Config.SelectName)
        end)
        UIDropDownMenu_JustifyText(d, "CENTER")
        UIDropDownMenu_SetWidth(d, 80) -- 缩小下拉菜单宽度一半
        UIDropDownMenu_SetButtonWidth(d, 80) -- 缩小下拉按钮宽度一半
        d:SetPoint("TOPLEFT", 100, -60)

        local sift = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
        sift:SetWidth(60) -- 缩小按钮宽度一半
        sift:SetHeight(36)
        sift:SetPoint("LEFT", d, "RIGHT", 10, 3) -- 调整按钮位置，与下拉列表保持间距
        if not Config.OnlyThisCharacter then
            sift:SetText(L["Sift"])
        else
            sift:SetText(L["Cancel Sift"])
        end
        sift:SetScript("OnClick", function()
            if not Config.OnlyThisCharacter then
                Addon.Config.OnlyThisCharacter = true
                sift:SetText(L["Cancel Sift"])
                Addon:PrintTradeLog(Config.Mode, Config.SelectName)
            else
                Addon.Config.OnlyThisCharacter = false
                sift:SetText(L["Sift"])
                Addon:PrintTradeLog(Config.Mode, nil)
            end
        end)

        self.dropdowntitle = t
        self.dropdownlist = d
        self.dropdownbutton = sift
    end
    do -- 带Scroll的可编辑输出窗口
        local t = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        t:SetPoint("TOPLEFT", f, 30, -120)
        t:SetWidth(280)
        t:SetHeight(320)

        local edit = CreateFrame("EditBox", nil, t)
        edit.cursorOffset = 0
        edit:SetWidth(280)
        edit:SetHeight(350)
        edit:SetPoint("TOPLEFT", t, 20, 0)
        edit:SetAutoFocus(false)
        edit:EnableMouse(true)
        edit:SetMaxLetters(99999999)
        edit:SetMultiLine(true)
        edit:SetFontObject(GameFontNormal)
        edit:SetScript("OnTextChanged", function(self)
            ScrollingEdit_OnTextChanged(self, t)
        end)
        edit:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
        edit:SetScript("OnEditFocusGained", function() edit:HighlightText() end)
        edit:SetScript("OnEscapePressed", function() f:Hide() Addon.Calendar.background:Hide() end)
        edit:Disable()

        edit:SetScript("OnEnter", function()
            if not InCombatLockdown() then
                edit:Enable()
            end
        end)
        edit:SetScript("OnLeave", function() edit:HighlightText(0, 0) edit:Disable() end)

        self.export = edit

        t:SetScrollChild(edit)

        t:Hide()
    end
end
