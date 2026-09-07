U1RegisterAddon("PersonalLootHelper", {
    title = LOCALE_zhCN and "求装备助手" or "求裝備助手",
    defaultEnable = 0,
    tags = {TAG_ITEM, TAG_GOOD },
    icon = [[Interface\Cursor\pickup]],
    desc = LOCALE_zhCN and "战斗结束后，出现你需要的装备时候，可以私密对方求装备。" or "戰斗結束後，出現你需要的裝備時候，可以私密對方求裝備。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("Personal Loot Helper"))
        end
    }

});
