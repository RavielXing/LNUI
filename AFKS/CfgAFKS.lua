U1RegisterAddon("AFKS", {
    title = LOCALE_zhCN and "AFK屏保" or "AFK屏保",
    defaultEnable = 1,
    tags = { TAG_INTERFACE },
    icon = [[Interface\Icons\SPELL_HOLY_BORROWEDTIME]],
    desc = LOCALE_zhCN and "说明`一款非常漂亮的AFK暂离屏保插件。|cffFF2D2D在某些情况下，你无法使用键盘输入退出AFK界面，现在可以点击屏幕右上角，会出现X图标，点击就可以退出了。|r" or "說明`一款非常漂亮的AFK暫離屏保插件。|cffFF2D2D在某些情況下，你無法使用鍵盤輸入退出AFK界面，現在可以點擊屏幕右上角，會出現X圖標，點擊就可以退出了。|r",
    nopic = 1,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("AFKS"))
        end
    }

});
