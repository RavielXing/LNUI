U1RegisterAddon("Mapster", {
    title = LOCALE_zhCN and "地图增强" or "地圖增強",
    defaultEnable = 1,
    secure = 1,
    tags = { TAG_MAPQUEST },
    icon = [[Interface\WorldMap\UI-World-Icon]],
    desc = LOCALE_zhCN and "增强世界地图的功能" or "增強世界地圖的功能",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading) Settings.OpenToCategory(U1GetSettingCategoryIDByName("Mapster")) end,
    },

});
