U1RegisterAddon("ItemUpgradeTip", {
    title = LOCALE_zhCN and "装备升級提示" or "裝備升級提示",
    defaultEnable = 0,
    tags = {TAG_ITEM},
    desc = LOCALE_zhCN and "将有关装备升级成本的信息添加到鼠标提示里。" or "將有關裝備昇級成本的信息添加到鼠標提示裡。",
    icon = [[Interface\Icons\Achievement_dungeon_heroic_gloryoftheraider]],
    nopic = 1,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("ItemUpgradeTip"))
        end
    }
});
