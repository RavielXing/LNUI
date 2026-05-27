U1RegisterAddon("MRT", {
    title = LOCALE_zhCN and "团长工具" or "團長工具",
    tags = { TAG_RAID },
    desc = LOCALE_zhCN and "强大的团队副本工具" or "強大的團隊副本工具",
    load = "NORMAL",
    defaultEnable = 0,
    nopic = 1,
    icon = [[Interface\AddOns\MRT\media\MiniMap]],
    minimap = "LibDBIcon10_MethodRaidTools",
    toggle = function(name, info, enable, justload)
        return true
    end,

    { text = LOCALE_zhCN and "主界面" or "主界面", callback = function(cfg, v, loading) SlashCmdList["mrtSlash"]("set") end },
    { text = LOCALE_zhCN and "团员检查" or "團員檢查", callback = function(cfg, v, loading) SlashCmdList["mrtSlash"]("raid") end },
    { text = LOCALE_zhCN and "战术板" or "戰術板", callback = function(cfg, v, loading) SlashCmdList["mrtSlash"]("note") end },
    { text = LOCALE_zhCN and "编辑战术板" or "編輯戰術板", callback = function(cfg, v, loading) SlashCmdList["mrtSlash"]("edit note") end },
    { text = LOCALE_zhCN and "标记助手" or "標記助手", callback = function(cfg, v, loading) SlashCmdList["mrtSlash"]("mm") end },
    { text = LOCALE_zhCN and "切换小地图按钮" or "切換小地圖按鈕", callback = function(cfg, v, loading) SlashCmdList["mrtSlash"]("icon") end },
});

