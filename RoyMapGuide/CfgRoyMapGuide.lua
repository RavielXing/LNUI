U1RegisterAddon("RoyMapGuide", {
    title = LOCALE_zhCN and "全地图NPC标记" or "全地圖NPC標記",
    defaultEnable = 1,
    tags = { TAG_MAPQUEST },
    icon = [[Interface\AddOns\RoyMapGuide\Icon.tga]],
    desc = LOCALE_zhCN and "全地图NPC标记。" or "全地圖NPC標記。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("RoyMapGuide"))
        end
    }
});