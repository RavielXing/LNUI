U1RegisterAddon("MidnightRatings", {
    title = LOCALE_zhCN and "装备绿字百分比" or "裝備綠字百分比",
    defaultEnable = 1,
    load = 'LOGIN',
    tags = { TAG_ITEM },
    modifier = "男爵凯恩 @NGA 汉化",
    icon = [[Interface\AddOns\MidnightRatings\logo]],
    desc = LOCALE_zhCN and "显示装备/宝石/附魔等 属性百分比(包含了专业属性)。" or "显示装备/宝石/附魔等 属性百分比(包含了专业属性)。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("Percentage Ratings"))
        end
    }

});