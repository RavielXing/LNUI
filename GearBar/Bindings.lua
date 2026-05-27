-- 按键绑定初始化
local function InitBindings()
    -- 创建绑定分类
    BINDING_HEADER_GEARBAR = "GearBar"
    BINDING_HEADER_GEARBAR_INVENTORYBAR_BUTTON = "装备栏按钮"
    
    -- 装备栏按钮
    BINDING_NAME_GEARBAR_BUTTON1 = "装备栏按钮 1"
    BINDING_NAME_GEARBAR_BUTTON2 = "装备栏按钮 2"
    BINDING_NAME_GEARBAR_BUTTON3 = "装备栏按钮 3"
    BINDING_NAME_GEARBAR_BUTTON5 = "装备栏按钮 5"
    BINDING_NAME_GEARBAR_BUTTON6 = "装备栏按钮 6"
    BINDING_NAME_GEARBAR_BUTTON7 = "装备栏按钮 7"
    BINDING_NAME_GEARBAR_BUTTON8 = "装备栏按钮 8"
    BINDING_NAME_GEARBAR_BUTTON9 = "装备栏按钮 9"
    BINDING_NAME_GEARBAR_BUTTON10 = "装备栏按钮 10"
    BINDING_NAME_GEARBAR_BUTTON11 = "装备栏按钮 11"
    BINDING_NAME_GEARBAR_BUTTON12 = "装备栏按钮 12"
    BINDING_NAME_GEARBAR_BUTTON13 = "装备栏按钮 13"
    BINDING_NAME_GEARBAR_BUTTON14 = "装备栏按钮 14"
    BINDING_NAME_GEARBAR_BUTTON15 = "装备栏按钮 15"
    BINDING_NAME_GEARBAR_BUTTON16 = "装备栏按钮 16"
    BINDING_NAME_GEARBAR_BUTTON17 = "装备栏按钮 17"
    BINDING_NAME_GEARBAR_BUTTON18 = "装备栏按钮 18"
end

-- 注册到插件加载事件
local bindingFrame = CreateFrame("Frame")
bindingFrame:RegisterEvent("ADDON_LOADED")
bindingFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == "GearBar" then
        InitBindings()
    end
end)
