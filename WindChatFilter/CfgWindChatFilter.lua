U1RegisterAddon("WindChatFilter", {
    title = LOCALE_zhCN and "聊天过滤器" or "聊天過濾器",
    defaultEnable = 1,
    minimap = "LibDBIcon10_WindChatFilter",
    tags = {TAG_CHAT},
    desc = LOCALE_zhCN and "Wind 聊天过滤器，是一个用于聊天过滤的专用插件。" or "Wind 聊天過濾器，是一個用於聊天過濾的專用插件。",
    icon = [[Interface\AddOns\WindChatFilter\Media\Icons\Icon]],

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function()
            LibStub("AceConfigDialog-3.0"):Open("WindChatFilter")
        end
    },
});


