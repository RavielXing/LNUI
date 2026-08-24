U1RegisterAddon("CanIMogIt", {
    title = LOCALE_zhCN and "幻化装备提示" or "幻化裝備提示",
    defaultEnable = 0,
    tags = { TAG_ITEM },
    icon = [[Interface\Addons\CanIMogIt\Icons\KNOWN]],
    desc = LOCALE_zhCN and "显示幻化装备收藏提示。点【配置选项——插件——CanIMogIt进行设置】" or "顯示幻化裝備收藏提示。點【配置選項——插件——CanIMogIt進行設置】",

    {
        text = "设定选项",
        callback = function() SlashCmdList["ACECONSOLE_CANIMOGIT"]("") end,
    },

});
