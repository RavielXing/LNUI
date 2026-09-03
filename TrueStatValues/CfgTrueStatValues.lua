U1RegisterAddon("TrueStatValues", {
    title = LOCALE_zhCN and "属性溢出提示" or "屬性溢出提示",
    defaultEnable = 0,
    tags = { TAG_INTERFACE },
    icon = [[Interface\Icons\Ability_Hunter_SilentHunter]],
    desc = LOCALE_zhCN and "角色框提示属性是否溢出数值。" or "角色框提示屬性是否溢出數值。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("True Stat Values"))
        end
    }
});
