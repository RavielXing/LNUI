U1RegisterAddon("tullaRange", {
    title = LOCALE_zhCN and "技能超距提示" or "技能超距提示",
    defaultEnable = 1,
    tags = { TAG_COMBATINFO },
    icon = [[Interface\Icons\Inv_misc_punchcards_red]],
    desc = LOCALE_zhCN and "动作条技能距离提示插件。" or "動作條技能距離提示插件。",
    nopic = 1,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("tullaRange"))
        end
    }
});

U1RegisterAddon("tullaRange_Config", { protected = 1, hide = 1 })