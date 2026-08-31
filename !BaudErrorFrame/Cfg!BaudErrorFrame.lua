U1RegisterAddon("!BaudErrorFrame", {
    title = LOCALE_zhCN and "错误提示增强" or "錯誤提示增強",
    tags = {TAG_MANAGEMENT},
    optionsAfterVar = 1,
    desc = LOCALE_zhCN and "收集插件错误的信息，不弹出窗口防止影响正常游戏，同时可以屏蔽'介面导致动作失效'的对话框。右键点击小地图按钮可进行一些设置，例如出错时在聊天框中显示信息。`如果小地图按钮被老农整合包收集，则出错时老农整合包的图标会闪烁。" or "收集插件錯誤的信息，不彈出窗口防止影響正常遊戲，同時可以屏蔽'介面導致動作失效'的對話框。右鍵點擊小地圖按鈕可進行一些設置，例如出錯時在聊天框中顯示信息。`如果小地圖按鈕被老農整合包收集，則出錯時老農整合包的圖標會閃爍。",
    load = "NORMAL",
    defaultEnable = 1,
    icon = [[Interface\Icons\INV_Inscription_Pigment_Bug04]],

    minimap = "LibDBIcon10_BaudErrorFrame",

    {
        var = "chatmessage",
        text = LOCALE_zhCN and "在聊天窗中显示错误" or "在聊天窗中顯示錯誤",
        getvalue = function() return BaudErrorFrameConfig["Messages"] end,
        default = false,
        callback = function(cfg, v, loading)
            BaudErrorFrameConfig["Messages"] = v;
        end,
    },
    {
        getvalue = function() return BaudErrorFrameConfig["PlaySound"] end,
        var = "PlaySound",
        text = LOCALE_zhCN and "发生错误时播放音效" or "發生錯誤時播放音效",
        callback = function(cfg, v, loading)
            BaudErrorFrameConfig["PlaySound"] = v;
        end,
    },

});
