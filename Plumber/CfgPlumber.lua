U1RegisterAddon("Plumber", {
    title = LOCALE_zhCN and "便捷小工具插件" or "便捷小工具插件",
    defaultEnable = 1,
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\AddOns\Plumber\Art\Logo\PlumberLogo64]],
    desc = LOCALE_zhCN and "一个主要用于梦境增强的工具插件，但也包含一些其他小功能。" or "一個主要用於夢境增強的工具插件，但也包含一些其他小功能。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading) Settings.OpenToCategory(U1GetSettingCategoryIDByName("Plumber")) end,
    },
});