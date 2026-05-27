U1RegisterAddon("Baganator", {
    title = LOCALE_zhCN and "背包增强插件" or "背包增強插件",
    defaultEnable = 1,
    tags = {TAG_ITEM},
    icon = [[Interface\AddOns\Baganator\Assets\logo]],
    desc = LOCALE_zhCN and "一款新的背包增强插件。" or "一款新的背包增強插件。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("Baganator"))
        end
    }
});

U1RegisterAddon("Syndicator", {
    parent = "Baganator",
    title = LOCALE_zhCN and "背包物品同步" or "背包物品同步",
    defaultEnable = 1,
    desc = LOCALE_zhCN and "角色间背包物品同步插件，在物品、货币、金钱、邮件、各类点数等提示信息里显示你同个用户名下所有角色小号所拥有的数量以及所处的位置（背包里或银行里）。" or "角色間背包物品同步插件，在物品、貨幣、金錢、郵件、各類點數等提示信息裏顯示你同個用戶名下所有角色小號所擁有的數量以及所處的位置（背包裏或銀行裏）。",
})