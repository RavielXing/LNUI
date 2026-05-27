U1RegisterAddon("WorldQuestTracker", {
    title = LOCALE_zhCN and "世界任务增强" or "世界任務增強",
    tags = { TAG_MAPQUEST },
    defaultEnable = 1,
    load = "NORMAL",
    nopic = 1,
    icon = [[Interface\Icons\icon_treasuremap]],
    desc = LOCALE_zhCN and "是一款非常实用的世界任务追踪插件,它能够在地图上标记所有的世界任务和任务奖励,让玩家能够更加轻松的去做任务。" or "是一款非常實用的世界任務追蹤插件,它能夠在地圖上標記所有的世界任務和任務獎勵,讓玩家能夠更加輕松的去做任務。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function()
            if not WorldMapFrame.firstRun then
                ToggleWorldMap()
            end
            local L = LibStub ("AceLocale-3.0"):GetLocale ("WorldQuestTrackerAddon", true)
        end
    }
});