U1RegisterAddon("SpellAlertTimer", {
    title = LOCALE_zhCN and "法术警报上计时" or "法術警報上計時",
    defaultEnable = 0,
    tags = { TAG_COMBATINFO },
    icon = [[Interface\Icons\Spell_Misc_HellifrePVPCombatMorale]],
    desc = LOCALE_zhCN and "给法术警报添加倒数文字。" or "給法術警報添加倒數文字。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("SpellAlertTimer"))
        end
    }
});

