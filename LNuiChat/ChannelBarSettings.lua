local addonName = "LNuiChat"

-- 加载本地化模块
local L = _G.LNuiChat_L or {}
local locale = GetLocale()
local isZhTW = (locale == "zhTW")

-- 本地化辅助函数
local function GT(key)
    return L[key] or key
end

local NAMES = {
    newbie=GT("btn_newbie"), say=GT("btn_say"), yell=GT("btn_yell"), party=GT("btn_party"), raid=GT("btn_raid"), instance=GT("btn_instance"), guild=GT("btn_guild"),
    general=GT("btn_general"), lfg=GT("btn_lfg"), trade=GT("btn_trade"), world=GT("btn_world"), ready=GT("btn_ready"), countdown=GT("btn_countdown"),
    roll=GT("btn_roll"), copy=GT("btn_copy"), emote=GT("btn_emote"), reload=GT("btn_reload"),
    stats=GT("btn_stats"),
}

-- 局部化常用函数
local print, format, C_Timer = print, string.format, C_Timer
local UnitName, GetRealmName = UnitName, GetRealmName
local GetCVar, SetCVar = GetCVar, SetCVar
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
local ChatTypeInfo = ChatTypeInfo
local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local type = type
local math = math

-- 图标路径常量
local LN_ICON = "|TInterface/AddOns/LNuiChat/Media/Emotion/laonong:20|t|cff19CCF9[" .. GT("addon_name") .. "]:|r "

local function Print(msg)
    print(LN_ICON .. msg)
end

-- 获取全局设置（跨角色）
local function GetGlobalDB()
    if not _G.LNuiChatDB then _G.LNuiChatDB = {} end
    if not _G.LNuiChatDB.global then _G.LNuiChatDB.global = {} end
    return _G.LNuiChatDB.global
end

-- 获取角色特定设置
local function GetCharDB()
    if not _G.LNuiChatDB then _G.LNuiChatDB = {} end
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    if not _G.LNuiChatDB[charKey] then _G.LNuiChatDB[charKey] = {} end
    return _G.LNuiChatDB[charKey]
end

-- 缓存引用减少全局查找
local cbRef = nil
local function GetChannelBar()
    if cbRef then return cbRef end
    cbRef = _G.ChannelBar or _G.LNuiChat
    return cbRef
end

function _G.LNuiChatSettings_Update()
    local panel = _G.LNuiChatSettingsPanel
    if not panel or not panel.boxes then return end

    local cb = GetChannelBar()
    if not cb then return end

    local vis = cb.GetButtonVisibility and cb:GetButtonVisibility() or {}
    for key, box in pairs(panel.boxes) do
        if box and box.SetChecked then
            local v = vis[key]
            if v == nil then
                v = (key ~= "newbie" and key ~= "trade" and key ~= "lfg")
            end
            box:SetChecked(v)
        end
    end

    local globalDB = GetGlobalDB()
    local charDB = GetCharDB()

    local scheme = globalDB.colorScheme or "DEFAULT"
    if panel.colorDefault then panel.colorDefault:SetChecked(scheme == "DEFAULT") end
    if panel.colorColorful then panel.colorColorful:SetChecked(scheme == "COLORFUL") end

    if panel.whisperStickyCheck then
        panel.whisperStickyCheck:SetChecked(globalDB.whisperStickyEnabled or false)
    end

    if panel.iconModeCheck then
        local iconMode = globalDB.iconMode
        if iconMode == nil then iconMode = true end
        panel.iconModeCheck:SetChecked(iconMode)
    end

    local layout = globalDB.layout or "horizontal"
    if panel.layoutHorizontal then panel.layoutHorizontal:SetChecked(layout == "horizontal") end
    if panel.layoutVertical then panel.layoutVertical:SetChecked(layout == "vertical") end

    local skin = globalDB.skinStyle or "BLIZZARD"
    if panel.skinBlizzard then panel.skinBlizzard:SetChecked(skin == "BLIZZARD") end
    if panel.skinElvui then panel.skinElvui:SetChecked(skin == "ELVUI") end
    if panel.skinTransparent then panel.skinTransparent:SetChecked(skin == "TRANSPARENT") end
    if panel.skinDropdown then panel.skinDropdown:SetChecked(skin == "DROPDOWN") end

    if panel.inputAttachChatFrame and panel.inputAttachChannelBar then
        local attachTo = globalDB.inputAttachTo or "chatframe"
        panel.inputAttachChatFrame:SetChecked(attachTo == "chatframe")
        panel.inputAttachChannelBar:SetChecked(attachTo == "channelbar")
    end

    local scale = globalDB.scale or 1
    if panel.scaleSlider then
        panel.scaleSlider:SetValue(scale)
        if panel.scaleValueLabel then
            panel.scaleValueLabel:SetText(format("%.0f", scale * 100) .. "%")
        end
    end

    if panel.timestampCopyCheck then
        local timestampCopyEnabled = globalDB.timestampCopyEnabled
        if timestampCopyEnabled == nil then timestampCopyEnabled = true end
        panel.timestampCopyCheck:SetChecked(timestampCopyEnabled)
    end

    if panel.minimapCheck then
        local showMinimap = globalDB.showMinimapButton
        if showMinimap == nil then showMinimap = true end
        panel.minimapCheck:SetChecked(showMinimap)
    end

    if panel.altArrowCheck then
        local altArrowEnabled = true
        if _G.LNuiChat_GetAltArrowMode then
            altArrowEnabled = _G.LNuiChat_GetAltArrowMode()
        end
        panel.altArrowCheck:SetChecked(altArrowEnabled)
    end
end

local function CreatePanel()
    local f = CreateFrame("Frame")
    f.name = addonName
    _G.LNuiChatSettingsPanel = f

    f:SetSize(600, 480)

    local scrollFrame = CreateFrame("ScrollFrame", "LNuiChatSettingsScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -25, 5)

    local content = CreateFrame("Frame")
    content:SetSize(570, 1100)
    content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    scrollFrame:SetScrollChild(content)
    f.content = content
    f.boxes = {}

    local t = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("|cff19CCF9[" .. GT("addon_name") .. "]:|r " .. GT("settings"))

    local st = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    st:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    st:SetText(GT("btn_visibility_title"))

    local all = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    all:SetSize(80, 22)
    all:SetPoint("TOPRIGHT", -20, -20)
    all:SetText(GT("btn_select_all"))

    local none = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    none:SetSize(80, 22)
    none:SetPoint("RIGHT", all, "LEFT", -5, 0)
    none:SetText(GT("btn_select_none"))

    f:SetScript("OnShow", function()
        if f.created then 
            _G.LNuiChatSettings_Update()
            return 
        end
        f.created = true

        local cb = GetChannelBar()
        if not cb then return end

        local configs = cb.GetAllButtonConfigs and cb:GetAllButtonConfigs() or {}
        local y, col = -70, 0

        all:SetScript("OnClick", function()
            for _, cfg in ipairs(configs) do
                if cb.SetButtonVisible then cb:SetButtonVisible(cfg.key, true) end
            end
            for _, box in pairs(f.boxes) do 
                if box and box.SetChecked then box:SetChecked(true) end
            end
        end)

        none:SetScript("OnClick", function()
            for _, cfg in ipairs(configs) do
                if cb.SetButtonVisible then cb:SetButtonVisible(cfg.key, false) end
            end
            for _, box in pairs(f.boxes) do 
                if box and box.SetChecked then box:SetChecked(false) end
            end
        end)

        local colWidth = 130
        local rowHeight = 26

        for _, cfg in ipairs(configs) do
            local x = 20 + col * colWidth

            local box = CreateFrame("CheckButton", "LNSet_"..cfg.key, content, "InterfaceOptionsCheckButtonTemplate")
            box:SetPoint("TOPLEFT", x, y)
            box:SetSize(22, 22)

            local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lbl:SetPoint("LEFT", box, "RIGHT", 3, 0)
            lbl:SetText((NAMES[cfg.key] or cfg.text) .. " (" .. cfg.key .. ")")
            lbl:SetFontObject("GameFontHighlightSmall")

            box.key = cfg.key
            box:SetScript("OnClick", function(self)
                local checked = self:GetChecked()
                local bar = GetChannelBar()
                if bar and bar.SetButtonVisible then bar:SetButtonVisible(self.key, checked) end
            end)

            f.boxes[cfg.key] = box

            col = col + 1
            if col >= 4 then col = 0; y = y - rowHeight end
        end

        if col > 0 then y = y - rowHeight end
        y = y - 15

        -- ==================== 时间戳点击复制功能设置 ====================
        local timestampCopyTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        timestampCopyTitle:SetPoint("TOPLEFT", 16, y)
        timestampCopyTitle:SetText(GT("timestamp_title"))
        y = y - 25

        local globalDB = GetGlobalDB()
        if globalDB.timestampCopyEnabled == nil then globalDB.timestampCopyEnabled = true end

        local timestampCopyCheck = CreateFrame("CheckButton", "LNTimestampCopy", content, "InterfaceOptionsCheckButtonTemplate")
        timestampCopyCheck:SetPoint("TOPLEFT", 20, y)
        timestampCopyCheck:SetSize(24, 24)
        f.timestampCopyCheck = timestampCopyCheck

        local timestampCopyLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        timestampCopyLbl:SetPoint("LEFT", timestampCopyCheck, "RIGHT", 5, 0)
        timestampCopyLbl:SetText(GT("timestamp_enable"))

        timestampCopyCheck:SetChecked(globalDB.timestampCopyEnabled)

        timestampCopyCheck:SetScript("OnClick", function(self)
            local enabled = self:GetChecked()
            GetGlobalDB().timestampCopyEnabled = enabled
            if _G.ChatTimestampCopy then
                if enabled then _G.ChatTimestampCopy.Enable()
                else _G.ChatTimestampCopy.Disable() end
            end
            if enabled then
                local cvalue = GetCVar("showTimestamps")
                if cvalue == "none" then
                    local defaultFormat = TIMESTAMP_FORMAT_HHMM_24HR or "%H:%M"
                    SetCVar("showTimestamps", defaultFormat)
                end
                Print(GT("timestamp_enabled"))
            else
                Print(GT("timestamp_disabled"))
            end
        end)

        y = y - 25
        local timestampCopyHint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        timestampCopyHint:SetPoint("TOPLEFT", 20, y)
        timestampCopyHint:SetText(GT("timestamp_hint"))

        -- ==================== 皮肤风格设置 ====================
        y = y - 30
        local skinTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        skinTitle:SetPoint("TOPLEFT", 16, y)
        skinTitle:SetText(GT("skin_title"))
        y = y - 25

        local currentSkin = GetGlobalDB().skinStyle or "BLIZZARD"

        local blizzardBtn = CreateFrame("CheckButton", "LNSkinBlizzard", content, "InterfaceOptionsCheckButtonTemplate")
        blizzardBtn:SetPoint("TOPLEFT", 20, y)
        blizzardBtn:SetSize(24, 24)
        f.skinBlizzard = blizzardBtn

        local blizzardLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        blizzardLbl:SetPoint("LEFT", blizzardBtn, "RIGHT", 5, 0)
        blizzardLbl:SetText(GT("skin_blizzard"))

        local elvuiBtn = CreateFrame("CheckButton", "LNSkinElvui", content, "InterfaceOptionsCheckButtonTemplate")
        elvuiBtn:SetPoint("TOPLEFT", 220, y)
        elvuiBtn:SetSize(24, 24)
        f.skinElvui = elvuiBtn

        local elvuiLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        elvuiLbl:SetPoint("LEFT", elvuiBtn, "RIGHT", 5, 0)
        elvuiLbl:SetText(GT("skin_elvui"))

        local transparentBtn = CreateFrame("CheckButton", "LNSkinTransparent", content, "InterfaceOptionsCheckButtonTemplate")
        transparentBtn:SetPoint("TOPLEFT", 20, y - 25)
        transparentBtn:SetSize(24, 24)
        f.skinTransparent = transparentBtn

        local transparentLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        transparentLbl:SetPoint("LEFT", transparentBtn, "RIGHT", 5, 0)
        transparentLbl:SetText(GT("skin_transparent"))

        local dropdownBtn = CreateFrame("CheckButton", "LNSkinDropdown", content, "InterfaceOptionsCheckButtonTemplate")
        dropdownBtn:SetPoint("TOPLEFT", 220, y - 25)
        dropdownBtn:SetSize(24, 24)
        f.skinDropdown = dropdownBtn

        local dropdownLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dropdownLbl:SetPoint("LEFT", dropdownBtn, "RIGHT", 5, 0)
        dropdownLbl:SetText(GT("skin_dropdown") .. "（" .. GT("color_scheme_changed") .. "）")

        blizzardBtn:SetChecked(currentSkin == "BLIZZARD")
        elvuiBtn:SetChecked(currentSkin == "ELVUI")
        transparentBtn:SetChecked(currentSkin == "TRANSPARENT")
        dropdownBtn:SetChecked(currentSkin == "DROPDOWN")

        local function SetSkinStyle(style, selfBtn, otherBtns)
            if selfBtn:GetChecked() then
                for _, btn in ipairs(otherBtns) do btn:SetChecked(false) end
                GetGlobalDB().skinStyle = style
                local bar = GetChannelBar()
                if bar and bar.SetSkinStyle then bar:SetSkinStyle(style) end
            else
                selfBtn:SetChecked(true)
            end
        end

        blizzardBtn:SetScript("OnClick", function(self) SetSkinStyle("BLIZZARD", self, {elvuiBtn, transparentBtn, dropdownBtn}) end)
        elvuiBtn:SetScript("OnClick", function(self) SetSkinStyle("ELVUI", self, {blizzardBtn, transparentBtn, dropdownBtn}) end)
        transparentBtn:SetScript("OnClick", function(self) SetSkinStyle("TRANSPARENT", self, {blizzardBtn, elvuiBtn, dropdownBtn}) end)
        dropdownBtn:SetScript("OnClick", function(self) SetSkinStyle("DROPDOWN", self, {blizzardBtn, elvuiBtn, transparentBtn}) end)

        y = y - 25 - 25
        local skinHint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        skinHint:SetPoint("TOPLEFT", 20, y)
        skinHint:SetText(GT("skin_hint"))

        -- ==================== 布局方向设置 ====================
        y = y - 30
        local layoutTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        layoutTitle:SetPoint("TOPLEFT", 16, y)
        layoutTitle:SetText(GT("layout_title"))
        y = y - 25

        local currentLayout = GetGlobalDB().layout or "horizontal"

        local horizontalBtn = CreateFrame("CheckButton", "LNLayoutHorizontal", content, "InterfaceOptionsCheckButtonTemplate")
        horizontalBtn:SetPoint("TOPLEFT", 20, y)
        horizontalBtn:SetSize(24, 24)
        f.layoutHorizontal = horizontalBtn

        local horizontalLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        horizontalLbl:SetPoint("LEFT", horizontalBtn, "RIGHT", 5, 0)
        horizontalLbl:SetText(GT("layout_horizontal_default"))

        local verticalBtn = CreateFrame("CheckButton", "LNLayoutVertical", content, "InterfaceOptionsCheckButtonTemplate")
        verticalBtn:SetPoint("TOPLEFT", 220, y)
        verticalBtn:SetSize(24, 24)
        f.layoutVertical = verticalBtn

        local verticalLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        verticalLbl:SetPoint("LEFT", verticalBtn, "RIGHT", 5, 0)
        verticalLbl:SetText(GT("layout_vertical"))

        horizontalBtn:SetChecked(currentLayout == "horizontal")
        verticalBtn:SetChecked(currentLayout == "vertical")

        horizontalBtn:SetScript("OnClick", function(self)
            if self:GetChecked() then
                verticalBtn:SetChecked(false)
                GetGlobalDB().layout = "horizontal"
                local bar = GetChannelBar()
                if bar and bar.SetLayout then bar:SetLayout("horizontal") end
            else self:SetChecked(true) end
        end)

        verticalBtn:SetScript("OnClick", function(self)
            if self:GetChecked() then
                horizontalBtn:SetChecked(false)
                GetGlobalDB().layout = "vertical"
                local bar = GetChannelBar()
                if bar and bar.SetLayout then bar:SetLayout("vertical") end
            else self:SetChecked(true) end
        end)

        y = y - 25
        local layoutHint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        layoutHint:SetPoint("TOPLEFT", 20, y)
        layoutHint:SetText(GT("layout_hint"))

        -- ==================== 输入框位置设置 ====================
        y = y - 30
        local inputAttachTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        inputAttachTitle:SetPoint("TOPLEFT", 16, y)
        inputAttachTitle:SetText(GT("input_title"))
        y = y - 25

        local currentAttach = GetGlobalDB().inputAttachTo or "chatframe"

        local attachChatFrameBtn = CreateFrame("CheckButton", "LNInputAttachChatFrame", content, "InterfaceOptionsCheckButtonTemplate")
        attachChatFrameBtn:SetPoint("TOPLEFT", 20, y)
        attachChatFrameBtn:SetSize(24, 24)
        f.inputAttachChatFrame = attachChatFrameBtn

        local attachChatFrameLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        attachChatFrameLbl:SetPoint("LEFT", attachChatFrameBtn, "RIGHT", 5, 0)
        attachChatFrameLbl:SetText(GT("input_attach_chatframe"))

        local attachChannelBarBtn = CreateFrame("CheckButton", "LNInputAttachChannelBar", content, "InterfaceOptionsCheckButtonTemplate")
        attachChannelBarBtn:SetPoint("TOPLEFT", 220, y)
        attachChannelBarBtn:SetSize(24, 24)
        f.inputAttachChannelBar = attachChannelBarBtn

        local attachChannelBarLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        attachChannelBarLbl:SetPoint("LEFT", attachChannelBarBtn, "RIGHT", 5, 0)
        attachChannelBarLbl:SetText(GT("input_attach_channelbar"))

        attachChatFrameBtn:SetChecked(currentAttach == "chatframe")
        attachChannelBarBtn:SetChecked(currentAttach == "channelbar")

        attachChatFrameBtn:SetScript("OnClick", function(self)
            if self:GetChecked() then
                attachChannelBarBtn:SetChecked(false)
                GetGlobalDB().inputAttachTo = "chatframe"
                if _G.LNuiChat_UpdateInputPosition then _G.LNuiChat_UpdateInputPosition() end
                Print(GT("input_changed_chatframe"))
            else self:SetChecked(true) end
        end)

        attachChannelBarBtn:SetScript("OnClick", function(self)
            if self:GetChecked() then
                attachChatFrameBtn:SetChecked(false)
                GetGlobalDB().inputAttachTo = "channelbar"
                if _G.LNuiChat_UpdateInputPosition then _G.LNuiChat_UpdateInputPosition() end
                Print(GT("input_changed_channelbar"))
            else self:SetChecked(true) end
        end)

        y = y - 25
        local inputAttachHint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        inputAttachHint:SetPoint("TOPLEFT", 20, y)
        inputAttachHint:SetText(GT("input_hint"))

        -- ==================== 缩放设置 ====================
        y = y - 30
        local scaleTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        scaleTitle:SetPoint("TOPLEFT", 16, y)
        scaleTitle:SetText(GT("scale_title"))
        y = y - 30

        local currentScale = GetGlobalDB().scale or 1

        local scaleSlider = CreateFrame("Slider", "LNScaleSlider", content, "OptionsSliderTemplate")
        scaleSlider:SetPoint("TOPLEFT", 20, y)
        scaleSlider:SetSize(300, 20)
        scaleSlider:SetMinMaxValues(0.7, 2.0)
        scaleSlider:SetValueStep(0.1)
        scaleSlider:SetValue(currentScale)
        scaleSlider:SetObeyStepOnDrag(true)

        local sliderName = scaleSlider:GetName()
        if _G[sliderName .. "Text"] then _G[sliderName .. "Text"]:SetText("") end
        if _G[sliderName .. "Low"] then
            _G[sliderName .. "Low"]:SetText("70%")
            _G[sliderName .. "Low"]:SetPoint("BOTTOMLEFT", scaleSlider, "BOTTOMLEFT", 0, -10)
        end
        if _G[sliderName .. "High"] then
            _G[sliderName .. "High"]:SetText("200%")
            _G[sliderName .. "High"]:SetPoint("BOTTOMRIGHT", scaleSlider, "BOTTOMRIGHT", 0, -10)
        end

        local scaleValueLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        scaleValueLabel:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
        scaleValueLabel:SetText(format("%.0f", currentScale * 100) .. "%")
        f.scaleValueLabel = scaleValueLabel

        scaleSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value * 10 + 0.5) / 10
            self:SetValue(value)
            if f.scaleValueLabel then f.scaleValueLabel:SetText(format("%.0f", value * 100) .. "%") end
            GetGlobalDB().scale = value
            local bar = GetChannelBar()
            if bar and bar.SetBarScale then bar:SetBarScale(value) end
        end)

        f.scaleSlider = scaleSlider

        y = y - 35
        local scaleHint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        scaleHint:SetPoint("TOPLEFT", 20, y)
        scaleHint:SetText(GT("scale_hint"))

        -- ==================== 配色方案设置 ====================
        y = y - 30
        local colorTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        colorTitle:SetPoint("TOPLEFT", 16, y)
        colorTitle:SetText(GT("color_title"))
        y = y - 25

        local currentScheme = GetGlobalDB().colorScheme or "DEFAULT"

        local defaultBtn = CreateFrame("CheckButton", "LNColorDefault", content, "InterfaceOptionsCheckButtonTemplate")
        defaultBtn:SetPoint("TOPLEFT", 20, y)
        defaultBtn:SetSize(24, 24)
        f.colorDefault = defaultBtn

        local defaultLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        defaultLbl:SetPoint("LEFT", defaultBtn, "RIGHT", 5, 0)
        defaultLbl:SetText(GT("color_default_recommend"))

        local colorfulBtn = CreateFrame("CheckButton", "LNColorColorful", content, "InterfaceOptionsCheckButtonTemplate")
        colorfulBtn:SetPoint("TOPLEFT", 220, y)
        colorfulBtn:SetSize(24, 24)
        f.colorColorful = colorfulBtn

        local colorfulLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        colorfulLbl:SetPoint("LEFT", colorfulBtn, "RIGHT", 5, 0)
        colorfulLbl:SetText(GT("color_colorful"))

        defaultBtn:SetChecked(currentScheme == "DEFAULT")
        colorfulBtn:SetChecked(currentScheme == "COLORFUL")

        defaultBtn:SetScript("OnClick", function(self)
            if self:GetChecked() then
                colorfulBtn:SetChecked(false)
                GetGlobalDB().colorScheme = "DEFAULT"
                local bar = GetChannelBar()
                if bar and bar.UpdateColors then bar:UpdateColors() end
            else self:SetChecked(true) end
        end)

        colorfulBtn:SetScript("OnClick", function(self)
            if self:GetChecked() then
                defaultBtn:SetChecked(false)
                GetGlobalDB().colorScheme = "COLORFUL"
                local bar = GetChannelBar()
                if bar and bar.UpdateColors then bar:UpdateColors() end
            else self:SetChecked(true) end
        end)

        y = y - 25
        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        hint:SetPoint("TOPLEFT", 20, y)
        hint:SetText(GT("color_hint"))

        -- ==================== 密语设置 ====================
        y = y - 30
        local whisperTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        whisperTitle:SetPoint("TOPLEFT", 16, y)
        whisperTitle:SetText(GT("whisper_title"))
        y = y - 25

        if GetGlobalDB().whisperStickyEnabled == nil then GetGlobalDB().whisperStickyEnabled = false end
        local stickyEnabled = GetGlobalDB().whisperStickyEnabled

        local stickyCheck = CreateFrame("CheckButton", "LNWhisperSticky", content, "InterfaceOptionsCheckButtonTemplate")
        stickyCheck:SetPoint("TOPLEFT", 20, y)
        stickyCheck:SetSize(24, 24)
        f.whisperStickyCheck = stickyCheck

        local stickyLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        stickyLbl:SetPoint("LEFT", stickyCheck, "RIGHT", 5, 0)
        stickyLbl:SetText(GT("whisper_sticky"))

        stickyCheck:SetChecked(stickyEnabled)

        local function ApplyWhisperSticky(enabled)
            if enabled then
                ChatTypeInfo["WHISPER"].sticky = 1
                ChatTypeInfo["BN_WHISPER"].sticky = 1
            else
                ChatTypeInfo["WHISPER"].sticky = 0
                ChatTypeInfo["BN_WHISPER"].sticky = 0
            end
        end

        ApplyWhisperSticky(stickyEnabled)

        stickyCheck:SetScript("OnClick", function(self)
            local enabled = self:GetChecked()
            GetGlobalDB().whisperStickyEnabled = enabled
            ApplyWhisperSticky(enabled)
            Print(GT("whisper_sticky_enabled"))
        end)

        y = y - 20
        local whisperHint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        whisperHint:SetPoint("TOPLEFT", 20, y)
        whisperHint:SetText(GT("whisper_hint"))

        -- ==================== 图标模式设置 ====================
        y = y - 30
        local iconModeTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        iconModeTitle:SetPoint("TOPLEFT", 16, y)
        iconModeTitle:SetText(GT("display_title"))
        y = y - 25

        local iconModeEnabled = true
        if GetGlobalDB().iconMode ~= nil then iconModeEnabled = GetGlobalDB().iconMode end

        local iconModeCheck = CreateFrame("CheckButton", "LNIconMode", content, "InterfaceOptionsCheckButtonTemplate")
        iconModeCheck:SetPoint("TOPLEFT", 20, y)
        iconModeCheck:SetSize(24, 24)
        f.iconModeCheck = iconModeCheck

        local iconModeLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        iconModeLbl:SetPoint("LEFT", iconModeCheck, "RIGHT", 5, 0)
        iconModeLbl:SetText(GT("icon_mode"))

        iconModeCheck:SetChecked(iconModeEnabled)

        iconModeCheck:SetScript("OnClick", function(self)
            local enabled = self:GetChecked()
            GetGlobalDB().iconMode = enabled
            local bar = GetChannelBar()
            if bar and bar.SetIconMode then bar:SetIconMode(enabled) end
            Print(GT("icon_mode_changed_icon"))
        end)

        y = y - 20
        local iconModeHint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        iconModeHint:SetPoint("TOPLEFT", 20, y)
        iconModeHint:SetText(GT("icon_mode_hint"))

        -- ==================== 小地图按钮设置 ====================
        y = y - 30
        local minimapTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        minimapTitle:SetPoint("TOPLEFT", 16, y)
        minimapTitle:SetText(GT("minimap_title"))
        y = y - 25

        local minimapCheck = CreateFrame("CheckButton", "LNMinimapBtn", content, "InterfaceOptionsCheckButtonTemplate")
        minimapCheck:SetPoint("TOPLEFT", 20, y)
        minimapCheck:SetSize(24, 24)
        f.minimapCheck = minimapCheck

        local minimapLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        minimapLbl:SetPoint("LEFT", minimapCheck, "RIGHT", 5, 0)
        minimapLbl:SetText(GT("minimap_show"))

        minimapCheck:SetScript("OnClick", function(self)
            local enabled = self:GetChecked()
            GetGlobalDB().showMinimapButton = enabled
            if _G.LNuiChatMinimapBtn then
                if enabled then _G.LNuiChatMinimapBtn:Show()
                else _G.LNuiChatMinimapBtn:Hide() end
            end
            Print(GT("minimap_shown"))
        end)

        y = y - 20
        local minimapHint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        minimapHint:SetPoint("TOPLEFT", 20, y)
        minimapHint:SetText(GT("minimap_hint"))

        -- ==================== 免ALT键查看输入记录 ====================
        y = y - 30
        local altArrowTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        altArrowTitle:SetPoint("TOPLEFT", 16, y)
        altArrowTitle:SetText(GT("altarrow_title"))
        y = y - 25

        local altArrowCheck = CreateFrame("CheckButton", "LNAltArrow", content, "InterfaceOptionsCheckButtonTemplate")
        altArrowCheck:SetPoint("TOPLEFT", 20, y)
        altArrowCheck:SetSize(24, 24)
        f.altArrowCheck = altArrowCheck

        local altArrowLbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        altArrowLbl:SetPoint("LEFT", altArrowCheck, "RIGHT", 5, 0)
        altArrowLbl:SetText(GT("altarrow_enable"))

        local altArrowEnabled = true
        if _G.LNuiChat_GetAltArrowMode then altArrowEnabled = _G.LNuiChat_GetAltArrowMode() end
        altArrowCheck:SetChecked(altArrowEnabled)

        altArrowCheck:SetScript("OnClick", function(self)
            local enabled = self:GetChecked()
            if _G.LNuiChat_SetAltArrowMode then _G.LNuiChat_SetAltArrowMode(enabled) end
            Print(GT("altarrow_enabled"))
        end)

        y = y - 20
        local altArrowHint = content:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        altArrowHint:SetPoint("TOPLEFT", 20, y)
        altArrowHint:SetText(GT("altarrow_hint"))

        -- 重置位置按钮
        y = y - 50
        local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        resetBtn:SetSize(120, 22)
        resetBtn:SetPoint("TOPLEFT", 20, y)
        resetBtn:SetText(GT("reset_position"))
        resetBtn:SetScript("OnClick", function()
            if _G.LNuiChatDB then
                _G.LNuiChatDB.pos = nil
                _G.LNuiChatDB.hasMoved = false
            end
            local bar = GetChannelBar()
            if bar then
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", _G.ChatFrame1, "BOTTOMLEFT", 0, -5)
                if _G.LNuiChat_UpdateInputPosition then _G.LNuiChat_UpdateInputPosition() end
            end
            ReloadUI()
        end)

        _G.LNuiChatSettings_Update()
    end)

    return f
end

-- ==========================================
-- 小地图设置按钮
-- ==========================================
local function CreateMinimapButton()
    if _G.LNuiChatMinimapBtn then return end

    local btn = CreateFrame("Button", "LNuiChatMinimapBtn", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 2)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(25, 25)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetVertexColor(0, 0, 0, 0.6)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("CENTER", 11, -12)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface/AddOns/LNuiChat/Media/LNuiChat")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, -2)
    btn.icon = icon

    local function UpdatePosition()
        local db = GetGlobalDB()
        local angle = db.minimapAngle or 0.5
        local radius = Minimap:GetWidth() / 2
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local dx = (cx / scale) - mx
            local dy = (cy / scale) - my
            local angle = math.atan2(dy, dx)
            GetGlobalDB().minimapAngle = angle
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if _G.LNuiChatSettingsCategory and Settings and Settings.OpenToCategory then
                Settings.OpenToCategory(_G.LNuiChatSettingsCategory)
            elseif _G.LNuiChatSettingsPanel and InterfaceOptionsFrame_OpenToCategory then
                InterfaceOptionsFrame_OpenToCategory(_G.LNuiChatSettingsPanel)
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(GT("minimap_tooltip_title"))
        GameTooltip:AddLine(GT("minimap_tooltip_open_settings"), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(GT("minimap_tooltip_move"), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
end

local function Init()
    if not _G.LNuiChatDB then _G.LNuiChatDB = {} end
    if not _G.LNuiChatDB.global then _G.LNuiChatDB.global = {} end

    local globalDB = _G.LNuiChatDB.global

    if globalDB.colorScheme == nil then globalDB.colorScheme = "DEFAULT" end
    if globalDB.whisperStickyEnabled == nil then globalDB.whisperStickyEnabled = false end
    if globalDB.iconMode == nil then globalDB.iconMode = true end
    if globalDB.layout == nil then globalDB.layout = "horizontal" end
    if globalDB.skinStyle == nil then globalDB.skinStyle = "BLIZZARD" end
    if globalDB.inputAttachTo == nil then globalDB.inputAttachTo = "chatframe" end
    if globalDB.scale == nil then globalDB.scale = 1 end
    if globalDB.timestampCopyEnabled == nil then globalDB.timestampCopyEnabled = true end
    if globalDB.showMinimapButton == nil then globalDB.showMinimapButton = true end
    if globalDB.minimapAngle == nil then globalDB.minimapAngle = 0.5 end
    if _G.LNuiChatDB.altArrowMode == nil then _G.LNuiChatDB.altArrowMode = true end

    local panel = CreatePanel()
    local categoryID = addonName

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, addonName)
        Settings.RegisterAddOnCategory(cat)
        _G.LNuiChatSettingsCategory = cat.ID
        if _G.U1CfgFrames then _G.U1CfgFrames[addonName] = cat end
    else
        InterfaceOptions_AddCategory(panel)
        _G.LNuiChatSettingsPanel = panel
    end

    _G.U1GetSettingCategoryIDByName = _G.U1GetSettingCategoryIDByName or function(name)
        if name == addonName then return _G.LNuiChatSettingsCategory or categoryID end
        return nil
    end

    CreateMinimapButton()
    if globalDB.showMinimapButton == false and _G.LNuiChatMinimapBtn then
        _G.LNuiChatMinimapBtn:Hide()
    end

    SLASH_LNUISET1 = "/lnset"
    SLASH_LNUISET2 = "/lnsettings"
    SlashCmdList["LNUISET"] = function()
        if _G.LNuiChatSettingsCategory and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(_G.LNuiChatSettingsCategory)
        elseif _G.LNuiChatSettingsPanel and InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(_G.LNuiChatSettingsPanel)
        end
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Init()
        self:UnregisterEvent("PLAYER_LOGIN")
        self:SetScript("OnEvent", nil)
    end
end)
