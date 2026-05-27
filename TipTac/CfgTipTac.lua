U1RegisterAddon("TipTac", {
    title = LOCALE_zhCN and "鼠标提示增强" or "鼠標提示增強",
    load = "NORMAL",
    defaultEnable = 1,
    minimap = "LibDBIcon10_TipTac",
    tags = { TAG_INTERFACE },
    icon = [[Interface\AddOns\TipTac\media\tiptac_logo]],
    desc = LOCALE_zhCN and "高度可定制的提示信息增强插件。" or "高度可定製的提示信息增強插件。",
    nopic = 1,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("TipTac"))
        end
    }

});

U1RegisterAddon("TipTacItemRef", { title = LOCALE_zhCN and "TipTac 链接与增益模块" or "TipTac 鏈接與增益模塊", parent = "TipTac", defaultEnable = 1 })
U1RegisterAddon("TipTacTalents", { title = LOCALE_zhCN and "TipTac 天赋专精模块" or "TipTac 天賦專精模塊", parent = "TipTac", defaultEnable = 1 })
U1RegisterAddon("TipTacOptions", { title = LOCALE_zhCN and "TipTac 配置选项模块" or "TipTac 配置選項模塊", parent = "TipTac", defaultEnable = 1 })