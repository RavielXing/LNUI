U1RegisterAddon("AbyTeamStats", {
    title = LOCALE_zhCN and "团员信息统计" or "團員信息統計",
    defaultEnable = 0,
    minimap = "LibDBIcon10_TeamStats", --默认不收集
    frames = {"TeamStatsFrame"}, --需要保存位置的框体

    tags = { TAG_RAID, TAG_GOOD },
    icon = "Interface\\AddOns\\AbyTeamStats\\logo",
    desc = LOCALE_zhCN and "自动获取全团成员的平均装备等级/韧性/副本击杀次数统计,以列表的方式集中呈现。`- 战斗外可以点击人名选为目标`- 可选中团员发布到聊天频道`- 具有观察间隔保护机制`- 每条玩家记录约占1K内存`- 记录保留两天,可以强制清除" or "自動獲取全團成員的平均裝備等級/韌性/副本擊殺次數統計,以列表的方式集中呈現。`- 戰鬥外可以點擊人名選為目標`- 可選中團員發布到聊天頻道`- 具有觀察間隔保護機製`- 每條玩家記錄約占1K內存`- 記錄保留兩天,可以強製清除",

    author = LOCALE_zhCN and "|cffcd1a1c[爱不易原创]|r" or "|cffcd1a1c[愛不易原創]|r",

    --toggle = function(name, info, enable, justload) end, --如果未开插件，则初始不会调用。

    {
        text = LOCALE_zhCN and "打开统计窗口" or "打開統計窗口",
        callback = function(cfg, v, loading) CoreUIShowOrHide(TeamStatsFrame, not TeamStatsFrame:IsVisible()) end,
    },
    {
        text = LOCALE_zhCN and "清除缓存数据" or "清除緩存數據",
        callback = function(cfg, v, loading)
            TeamStatsDB = nil
            TeamStats:VARIABLES_LOADED()
        end,
    },
});