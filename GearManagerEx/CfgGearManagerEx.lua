U1RegisterAddon("GearManagerEx", {
    title = LOCALE_zhCN and "一键换装" or "一鍵換裝",
    defaultEnable = 0,
    load = "LOGIN",
    frames = {"GearManagerExToolBarFrame"},
    tags = {TAG_MANAGEMENT},
    icon = [[Interface\Icons\INV_Gizmo_03]],
    desc = LOCALE_zhCN and "增强系统默认的换装系统，在人物头像上方显示一键换装工具条，支持图标和数字显示模式。" or "增強系統默認的換裝系統，在人物頭像上方顯示一鍵換裝工具條，支持圖標和數字顯示模式。",

    toggle = function(name, info, enable, justload)
        if justload then
            CoreHideOnPetBattle(GearManagerExToolBarFrame)
        end
        return true
    end,

    -------- Options --------
    {
        var = "toolbar",
        default = 1,
        text = LOCALE_zhCN and "启用换装工具条" or "啟用換裝工具條",
        callback = function(cfg, v, loading) GearManagerEx_OnMenuHide(not v) end,
    },
    {
        text = LOCALE_zhCN and "一键脱光/穿回" or "一鍵脫光/穿回",
        callback = function(cfg, v, loading) GearManagerEx:QuickStrip() end,
    },
    --[[{
        text = "按鍵綁定",
        callback = function(cfg, v, loading) CoreUIShowKeyBindingFrame("HEADER_GEARMANAGEREX_TITLE") end,
    },--]]
    {
        text = LOCALE_zhCN and '重置快捷条' or '重置快捷條',
        callback = function(cfg, v, loading)
            return loading or GearManagerExToolBarCheckFrameButton and GearManagerExToolBarCheckFrameButton:Click()
        end,
    },
    --]]
});
