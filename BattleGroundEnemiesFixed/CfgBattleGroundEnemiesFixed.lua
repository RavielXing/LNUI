U1RegisterAddon("BattleGroundEnemiesFixed", {
    title = LOCALE_zhCN and "PVP战场框体" or "PVP戰場框體",
    defaultEnable = 0,
    load = "LOGIN",

    tags = { TAG_PVP },
    icon = [[Interface\Icons\INV_Gizmo_Poltryiser_01]],
    desc = LOCALE_zhCN and "显示全部战场敌人。战场简洁敌对单位框体。" or "顯示全部戰場敵人。戰場簡潔敵對單位框體。",
    nopic = 1,

    {
        text = LOCALE_zhCN and "显示设置界面" or "顯示設置界面",
        tip = LOCALE_zhCN and "说明`快捷命令 /bge" or "說明`快捷命令 /bge",
        callback = function(cfg, v, loading)
            SlashCmdList["BattleGroundEnemies"]("")
        end,
    },

    {
        text = LOCALE_zhCN and "重置所有设定" or "重置所有設定",
        confirm = LOCALE_zhCN and "是否确定？" or "是否確定？",
        callback = function(cfg, v, loading)
            BattleGroundEnemiesDB = nil;
            ReloadUI();
        end,
    },

});
