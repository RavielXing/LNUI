U1RegisterAddon("CooldownDone", {
    title = LOCALE_zhCN and "CD就绪" or "CD就緒",
    defaultEnable = 0,
    tags = { TAG_COMBATINFO, TAG_GOOD },
    icon = [[Interface\AddOns\CooldownDone\icon.tga]],
    desc = LOCALE_zhCN and "当技能CD结束时,会语音提示技能名字好了。" or "當技能CD結束時,會語音提示技能名字好了。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("CD 就绪"))
        end
    }
});
