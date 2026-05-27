U1RegisterAddon("BlizzMove", {
    title = LOCALE_zhCN and "游戏界面移动" or "遊戲界面移動",
    desc = LOCALE_zhCN and "移动系统的界面框体。" or "移動系統的界面框體。",
    secure = 1,
    load = "LOGIN",
    optdeps = {"Mapster"},
    defaultEnable = 1,

    tags = { TAG_INTERFACE },
    icon = [[Interface\Icons\INV_Helmet_01]],

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("BlizzMove"))
        end
    }

});