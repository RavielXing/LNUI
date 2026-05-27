U1RegisterAddon("MerchantEx", {
    title = LOCALE_zhCN and "自动修理贩卖" or "自動修理販賣",
    defaultEnable = 1,
    optionsAfterVar = 1,
    tags = {TAG_ITEM },
    icon = [[Interface\Icons\INV_GIZMO_MANAPOTIONPACK]],
    desc = LOCALE_zhCN and "商人助手插件，在商人面板右上有设置按钮，提供自动出售灰色物品、自动修理、自动购入施法材料等功能。" or "商人助手插件，在商人面板右上有設置按鈕，提供自動出售灰色物品、自動修理、自動購入施法材料等功能。",

    {
        var = "repair",
        default = 1,
        text = LOCALE_zhCN and "自动修理" or "自動修理",
        getvalue = function() return MerchantExDB.option.repair end,
        callback = function(cfg, v, loading) MerchantExDB.option.repair = v end,
        {
            var = "guild",
            default = 1,
            text = LOCALE_zhCN and "尽可能使用公会资金" or "盡可能使用公會資金",
            getvalue = function() return MerchantExDB.option.guild end,
            callback = function(cfg, v, loading) MerchantExDB.option.guild = v end,
        }
    },
    {
        var = "sell",
        default = 1,
        text = LOCALE_zhCN and "自动出售灰色物品" or "自動出售灰色物品",
        getvalue = function() return MerchantExDB.option.sell end,
        callback = function(cfg, v, loading) MerchantExDB.option.sell = v end,
        {
            var = "details",
            default = nil,
            text = LOCALE_zhCN and "显示出售物品列表" or "顯示出售物品列表",
            getvalue = function() return MerchantExDB.option.details end,
            callback = function(cfg, v, loading) MerchantExDB.option.details = v end,
        }
    },
    {
        var = "buy",
        default = 1,
        text = LOCALE_zhCN and "自动补购材料" or "自動補購材料",
        getvalue = function() return MerchantExDB.option.buy end,
        callback = function(cfg, v, loading) MerchantExDB.option.buy = v end,
    },
    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading) SlashCmdList["MERCHANTEX"]() end,
    },

});

U1RegisterAddon("BuyEmAll", {
    parent = "MerchantEx",
    title = LOCALE_zhCN and "批量购买助手" or "批量購買助手",
    defaultEnable = 1,
    desc = LOCALE_zhCN and "提供比默认批量购买更方便的批量购买界面，并且支持金币之外的购买，使用时请小心，有些货物无法退换。" or "提供比默認批量購買更方便的批量購買界面，並且支持金幣之外的購買，使用時請小心，有些貨物無法退換。",
})