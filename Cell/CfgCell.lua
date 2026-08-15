U1RegisterAddon("Cell", {
    title = LOCALE_zhCN and "Cell团队框架" or "Cell團隊框架",
    load = "NORMAL",
    tags = { TAG_RAID },
    icon = [[Interface\AddOns\Cell\Media\icon]],
    desc = LOCALE_zhCN and "目前最强大团队框架插件。" or "目前最強大團隊框架插件。",
    nopic = 1,
    defaultEnable = 0,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
            Cell.funcs:ShowOptionsFrame()
        end,
    },
})