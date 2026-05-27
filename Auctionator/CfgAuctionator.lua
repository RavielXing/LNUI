U1RegisterAddon("Auctionator", {
    title = LOCALE_zhCN and "拍卖助手" or "拍賣助手",
    load = "NORMAL",
    defaultEnable = 0,

    tags = {TAG_ITEM },
    desc = LOCALE_zhCN and "老牌拍卖助手，功能较多。" or "老牌拍賣助手，功能較多。",
    icon = [[Interface\AddOns\Auctionator\Images\logo]],

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("Auctionator"))
        end
    }
});
