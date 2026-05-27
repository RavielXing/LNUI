U1RegisterAddon("AngryKeystones", {
    title = LOCALE_zhCN and "大米计时增强" or "大米計時增強",
    defaultEnable = 1,
    tags = { TAG_COMBATINFO },
    icon = [[Interface\Icons\INV_Relics_Hourglass]],
    desc = LOCALE_zhCN and "AngryKeystones是一款用来大秘境的计时插件，在大秘境中精确显示进度以及世界，方便玩家做出选择。" or "AngryKeystones是一款用來大秘境的計時插件，在大秘境中精確顯示進度以及世界，方便玩家做出選擇。",
    nopic = 1,

    toggle = function(name, info, enable, justload)
        if justload then
        end
        return true
    end,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
            SlashCmdList.AngryKeystones("")
        end
    }
});
