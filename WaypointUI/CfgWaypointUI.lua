U1RegisterAddon("WaypointUI", {
    title = LOCALE_zhCN and "任务导航线" or "任務導航綫",
    tags = { TAG_MAPQUEST },
    defaultEnable = 1,
    load = "NORMAL",
    nopic = 1,
    icon = [[Interface\AddOns\WaypointUI\Art\Icons\Logo-White]],
    desc = LOCALE_zhCN and "Waypoint UI，一个给地图标记增加指示线的插件，让你的标记看起来更高更直观" or "Waypoint UI，一個給地圖標記增加指示線的插件，讓你的標記看起來更高更直觀",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("Waypoint UI"))
        end
    }
});