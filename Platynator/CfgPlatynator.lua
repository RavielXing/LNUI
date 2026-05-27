U1RegisterAddon("Platynator", {
    title = LOCALE_zhCN and "姓名板助手" or "姓名板助手",
    defaultEnable = 1,
    tags = { TAG_INTERFACE },
    icon = [[Interface\AddOns\Platynator\Assets\logo.tga]],
    desc = LOCALE_zhCN and "多功能源生血条增强插件。" or "多功能源生血條增強插件。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("Platynator"))
        end
    }
});