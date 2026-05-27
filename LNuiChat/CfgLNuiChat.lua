U1RegisterAddon("LNuiChat", {
    title = LOCALE_zhCN and "老农聊天条" or "老農聊天條",
    defaultEnable = 1,
    tags = {TAG_CHAT},
    minimap = "LNuiChatMinimapBtn",
    icon = [[Interface\AddOns\LNuiChat\Media\LNuiChat]],
    desc = LOCALE_zhCN and "请通过 ESC -> 选项 -> 插件 -> LNuiChat 打开设置。" or "请通过 ESC -> 选项 -> 插件 -> LNuiChat 打开设置。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("LNuiChat"))
        end
    }

});
