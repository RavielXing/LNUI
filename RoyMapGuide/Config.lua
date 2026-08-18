local addonName, ns = ...
local L = ns.L

-- ========================================================================
-- UI 控件函数
-- ========================================================================
local function CreateHeader(layout, opt)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(opt.name, opt.tooltip))
end

local function CreateCheckbox(category, opt)
    local setting = Settings.RegisterProxySetting(
        category, opt.key, Settings.VarType.Boolean, opt.name, opt.default,
        function() return RoyMapGuideDB[opt.key] end,
        function(value) RoyMapGuideDB[opt.key] = value end
    )
    local init = Settings.CreateCheckbox(category, setting, opt.tooltip)
    if opt.onChange then setting:SetValueChangedCallback(opt.onChange) end
    return init
end

local function CreateSlider(category, opt)
    local getter = opt.getter or function() return RoyMapGuideDB[opt.key] end
    local setter = opt.setter or function(value) RoyMapGuideDB[opt.key] = value end
    local setting = Settings.RegisterProxySetting(
        category, opt.key, Settings.VarType.Number, opt.name, opt.default,
        getter, setter
    )
    local options = Settings.CreateSliderOptions(opt.min, opt.max, opt.step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
        if opt.step and opt.step < 1 then return string.format("%.1f", v) else return string.format("%d", v) end
    end)
    local init = Settings.CreateSlider(category, setting, options, opt.tooltip)
    if opt.onChange then setting:SetValueChangedCallback(opt.onChange) end
    return init
end

local function CreateDropdown(category, opt)
    local varType = type(opt.default) == "number"
                    and Settings.VarType.Number or Settings.VarType.String
    local getter = opt.getter or function() return RoyMapGuideDB[opt.key] end
    local setter = opt.setter or function(value) RoyMapGuideDB[opt.key] = value end
    local setting = Settings.RegisterProxySetting(
        category, opt.key, varType, opt.name, opt.default,
        getter, setter
    )
    local init = Settings.CreateDropdown(category, setting, opt.options, opt.tooltip)
    if opt.onChange then setting:SetValueChangedCallback(opt.onChange) end
    return init
end

local function CreateColorSwatch(category, opt)
    local setting = Settings.RegisterProxySetting(
        category, opt.key, Settings.VarType.String, opt.name, opt.default,
        function() return RoyMapGuideDB[opt.key] end,
        function(value) RoyMapGuideDB[opt.key] = value end
    )
    local init = Settings.CreateColorSwatch(category, setting, opt.tooltip)
    if opt.onChange then setting:SetValueChangedCallback(opt.onChange) end
    return init
end

local function CreateCheckBoxSlider(category, layout, opt)
    local cbSetting = Settings.RegisterProxySetting(
        category, opt.key, Settings.VarType.Boolean, opt.cbLabel, opt.cbDefault,
        function() return RoyMapGuideDB[opt.key] end,
        function(value) RoyMapGuideDB[opt.key] = value end
    )
    local sliderSetting = Settings.RegisterProxySetting(
        category, opt.sliderKey, Settings.VarType.Number, opt.sliderLabel, opt.sliderDefault,
        function() return RoyMapGuideDB[opt.sliderKey] end,
        function(value) RoyMapGuideDB[opt.sliderKey] = value end
    )
    local sliderOptions = Settings.CreateSliderOptions(opt.sliderMin, opt.sliderMax, opt.sliderStep)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
        if opt.sliderStep and opt.sliderStep < 1 then return string.format("%.1f", v) else return string.format("%d", v) end
    end)
    if opt.onChange then
        cbSetting:SetValueChangedCallback(opt.onChange)
        sliderSetting:SetValueChangedCallback(opt.onChange)
    end
    local initializer = CreateSettingsCheckboxSliderInitializer(
        cbSetting, opt.cbLabel, opt.cbTooltip,
        sliderSetting, sliderOptions, opt.sliderLabel, opt.sliderTooltip
    )
    layout:AddInitializer(initializer)
    return initializer
end

local function CreateCheckBoxDropdown(category, layout, opt)
    local cbSetting = Settings.RegisterProxySetting(
        category, opt.key, Settings.VarType.Boolean, opt.cbLabel, opt.cbDefault,
        function() return RoyMapGuideDB[opt.key] end,
        function(value) RoyMapGuideDB[opt.key] = value end
    )
    local varType = type(opt.dropdownDefault) == "number"
                    and Settings.VarType.Number or Settings.VarType.String
    local dropdownSetting = Settings.RegisterProxySetting(
        category, opt.dropdownKey, varType, opt.dropdownLabel, opt.dropdownDefault,
        function() return RoyMapGuideDB[opt.dropdownKey] end,
        function(value) RoyMapGuideDB[opt.dropdownKey] = value end
    )
    if opt.onChange then
        cbSetting:SetValueChangedCallback(opt.onChange)
        dropdownSetting:SetValueChangedCallback(opt.onChange)
    end
    local initializer = CreateSettingsCheckboxDropdownInitializer(
        cbSetting, opt.cbLabel, opt.cbTooltip,
        dropdownSetting, opt.options, opt.dropdownLabel, opt.dropdownTooltip
    )
    layout:AddInitializer(initializer)
    return initializer
end

local function CreateCheckBoxColor(category, layout, opt)
    local cbSetting = Settings.RegisterProxySetting(
        category, opt.key, Settings.VarType.Boolean, opt.cbLabel, opt.cbDefault,
        function() return RoyMapGuideDB[opt.key] end,
        function(value) RoyMapGuideDB[opt.key] = value end
    )
    if opt.onChange then cbSetting:SetValueChangedCallback(opt.onChange) end

    local function OnSwatchClick()
        local hex = RoyMapGuideDB[opt.colorKey] or opt.colorDefault or "FFFFFFFF"
        local c = CreateColorFromHexString(hex)
        local info = {}
        info.r, info.g, info.b = c:GetRGB()
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local newHex = CreateColor(r, g, b):GenerateHexColor()
            RoyMapGuideDB[opt.colorKey] = newHex
            if opt.onChange then opt.onChange(nil, newHex) end
        end
        info.cancelFunc = function()
            local r, g, b = ColorPickerFrame:GetPreviousValues()
            local prevHex = CreateColor(r, g, b):GenerateHexColor()
            RoyMapGuideDB[opt.colorKey] = prevHex
            if opt.onChange then opt.onChange(nil, prevHex) end
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end

    local function GetSwatchColor()
        local hex = RoyMapGuideDB[opt.colorKey] or opt.colorDefault or "FFFFFFFF"
        return CreateColorFromHexString(hex)
    end

    local initializer = CreateSettingsCheckboxWithColorSwatchInitializer(
        cbSetting, opt.cbTooltip,
        OnSwatchClick, nil, nil,
        GetSwatchColor, opt.colorLabel, nil
    )
    layout:AddInitializer(initializer)
    return initializer
end

local function CreateControl(category, layout, opt)
    if opt.type == "header" then
        CreateHeader(layout, opt)
        return nil
    elseif opt.type == "checkbox" then
        return CreateCheckbox(category, opt)
    elseif opt.type == "slider" then
        return CreateSlider(category, opt)
    elseif opt.type == "dropdown" then
        return CreateDropdown(category, opt)
    elseif opt.type == "color" then
        return CreateColorSwatch(category, opt)
    elseif opt.type == "CheckBoxSlider" then
        return CreateCheckBoxSlider(category, layout, opt)
    elseif opt.type == "CheckBoxDropdown" then
        return CreateCheckBoxDropdown(category, layout, opt)
    elseif opt.type == "CheckBoxColor" then
        return CreateCheckBoxColor(category, layout, opt)
    end
    return nil
end

-- ========================================================================
-- 主界面
-- ========================================================================
local function CreateMainFrame()
    local frame = CreateFrame("Frame")

    -- 标题
    local title = frame:CreateFontString(nil, "ARTWORK")
    title:SetFont(STANDARD_TEXT_FONT, 30, "OUTLINE")
    title:SetPoint("TOP", 0, -20)
    title:SetText("RoyMapGuide")
    title:SetTextColor(1, 0.8, 0)

    -- 副标题
    local subtitle = frame:CreateFontString(nil, "ARTWORK")
    subtitle:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -10)
    subtitle:SetText(L["全地图NPC标记"])
    subtitle:SetTextColor(0.6, 0.8, 1)

    -- 装饰线
    local line = frame:CreateLine()
    line:SetColorTexture(0.8, 0.6, 0, 0.6)
    line:SetThickness(1.5)
    line:SetStartPoint("TOPLEFT", 20, -90)
    line:SetEndPoint("TOPRIGHT", -20, -90)

    -- 更新记录标题
    local changelogTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    changelogTitle:SetPoint("TOP", line, "BOTTOM", 0, -15)
    changelogTitle:SetWidth(600)
    changelogTitle:SetJustifyH("LEFT")
    changelogTitle:SetText(L["更新记录"])
    changelogTitle:SetTextColor(1, 0.8, 0)

    -- 滚动框架
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOP", changelogTitle, "BOTTOM", 0, -10)
    scrollFrame:SetPoint("LEFT", frame, "LEFT", 30, 0)
    scrollFrame:SetPoint("RIGHT", frame, "RIGHT", -50, 0)
    scrollFrame:SetHeight(400)

    -- 滚动框架背景
    local bg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    bg:SetAllPoints(scrollFrame)
    bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    bg:SetBackdropColor(0, 0, 0, 0.8)
    bg:SetFrameLevel(scrollFrame:GetFrameLevel() - 1)

    -- 滚动内容子框架
    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(570)

    -- 更新记录文本
    local changelog = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    changelog:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -10)
    changelog:SetWidth(570)
    changelog:SetJustifyH("LEFT")
    changelog:SetSpacing(10)
    changelog:SetTextColor(0.5, 0.5, 0.5)

    if not rawget(ns.L, "changelog") then
        ns.L["changelog"] = [[
【2026.8.17】v1.7.1
・补充地下堡毒瀑深渊
・补充诅咒狂潮活动刷新位置

【2026.8.16】v1.7
・更改装饰决斗、仪式场地、千禧阈限标记
・补充盘卷蛇岛标记
・调整部分配置选项名称和描述

【2026.8.12】v1.6.5
・修复本地化文件

【2026.8.12】v1.6.4
・添加12.1支持
・补充团本孢陨幽境
・更改游学探奇标记名称

【2026.6.17】v1.6.3
・添加12.0.7支持

【2026.6.7】v1.6.2
・补充之前移除的暗月岛标记
・补充瓦德拉肯的化生台

【2026.5.31】v1.6.1
・调整toc文件顺序

【2026.5.31】v1.6
标记
・补充仪式场地标记和一些其他标记
・暂时移除暗月岛标记，下次马戏团到来时会重新加上
功能
・添加标记颜色更改功能
・添加地图缩放功能的开关
代码
・修复地图坐标报错，并优化坐标显示性能
・调整标记模板、标记图标、标记缩放等大量内容，修复部分错误标记
・完全重构插件结构
・调整配置选项顺序
・添加本地化支持（目前只有插件界面完成了本地化）

【2026.4.22】v1.5.5
・添加12.0.5支持

【2026.4.3】v1.5.4
・补充银月城（至暗之夜）黑市和家宅标记

【2026.4.2】v1.5.3
・补充地下堡幻日广场

【2026.3.27】v1.5.2
・补充永歌森林区域地图上的地下堡黑暗回廊

【2026.3.27】v1.5.1
・补充地下堡黑暗回廊

【2026.3.23】v1.5
・添加标记创建路径点功能，左键创建，右键取消
・添加原生标记文本偏移功能
・修复已知标记错误

【2026.3.20】v1.4
标记
・补充时间流、千禧阈限、宿敌地下堡、剥皮稀有标记
代码
・调整地图ID和坐标功能的配置结构为父子配置

【2026.3.16】v1.3
标记
・修复启用专业过滤后，部分专业不显示的问题
代码
・修复父子配置中父级配置默认值不生效的问题

【2026.3.15】v1.2
标记
・完善12.0银月城（至暗之夜）和4大区域标记
・补回银月城（燃烧的远征）标记
・更改两个达拉然主城名称，使用标准版本名称而非区域名称
・暂时移除卡兹阿加和银月城（至暗之夜）的时间流传送门
功能
・添加地图缩放功能
・添加MapID、玩家坐标和鼠标坐标显示，可调颜色、大小、位置
・添加标记层级更改
・添加标记缩放阈值，用于切换聚合标记和独立标记
・添加地图开关功能，左键开关标记，右键图文切换
代码
・添加父子配置联动，目前仅限单一控件
・完全重构当前所有标记数据结构
・添加动态捕获逻辑，用于捕获暴雪原生地图标记（当前为poi/maplink/副本/地下堡4类）
・修复获取坐标内存泄露
・其他代码优化和修复

【2026.2.28】v1.1
・添加12.0主城标记（临时版）

【2026.2.11】v1.0
・发布插件版
        ]]
    end
    changelog:SetText(L["changelog"])

    scrollChild:SetHeight(changelog:GetStringHeight() + 30)

    return frame
end

-- ========================================================================
-- 面板初始化
-- ========================================================================
local function InitializeSettings()
    -- 主界面使用 Canvas 布局，支持自定义 Frame
    local mainFrame = CreateMainFrame()
    local mainCategory = Settings.RegisterCanvasLayoutCategory(mainFrame, "RoyMapGuide")

    -- 子分类使用垂直布局，标准控件列表
    local mapCategory, mapLayout = Settings.RegisterVerticalLayoutSubcategory(mainCategory, L["地图设置"])

    -- 注册主分类
    Settings.RegisterAddOnCategory(mainCategory)
    ns.categoryID = mainCategory:GetID()

    local initializers = {}
    local function BuildControls(optList, category, layout)
        for _, opt in ipairs(optList) do
            local init = CreateControl(category, layout, opt)
            if init and opt.key then
                initializers[opt.key] = init
            end
        end
    end

    BuildControls(ns.MapOptions, mapCategory, mapLayout)

    -- 绑定父子联动关系
    for parentKey, groups in pairs(ns.OptionDependencies) do
        local parentInit = initializers[parentKey]
        if parentInit then
            for _, group in ipairs(groups) do
                for _, childKey in ipairs(group.children) do
                    local childInit = initializers[childKey]
                    if childInit then
                        childInit:SetParentInitializer(parentInit, group.enabled)
                        childInit:AddShownPredicate(group.enabled)
                    end
                end
            end
        end
    end
end

EventUtil.ContinueOnPlayerLogin(InitializeSettings)