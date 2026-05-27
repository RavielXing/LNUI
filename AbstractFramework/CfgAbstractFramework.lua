U1RegisterAddon("AbstractFramework", {
    title = LOCALE_zhCN and "大脚工匠/黑市" or "大脚工匠/黑市",
    defaultEnable = 0,
    tags = { TAG_ITEM },
    icon = [[Interface\AddOns\AbstractFramework\Media\Icons\AF]],
    desc = LOCALE_zhCN and "大脚工匠/黑市插件。" or "大脚工匠/黑市插件。",

    {
        type = "text",
        text = "|cffFF2D2D勾选启用插件后，请“重载界面”。|r",       
    },

	{
		text = "大脚工匠",
		callback = function()
			SlashCmdList["BFCRAFTSMAN"]()
		end,
	},
	
	{
		text = "大脚黑市",
		callback = function()
			SlashCmdList["BFBLACKMARKET"]()
		end,
	},

});

U1RegisterAddon("BFCraftsman", {
    parent = "AbstractFramework",
    minimap = "LibDBIcon10_BFCraftsman",
    title = LOCALE_zhCN and "勾选启用-大脚工匠" or "勾選啓用-大脚工匠",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    desc = LOCALE_zhCN and "大脚工匠。" or "大脚工匠。",
})

U1RegisterAddon("BFBlackMarket", {
    parent = "AbstractFramework",
    minimap = "LibDBIcon10_BFBlackMarket",
    title = LOCALE_zhCN and "勾选启用-大脚黑市" or "勾選啓用-大脚黑市",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    desc = LOCALE_zhCN and "大脚黑市。" or "大脚黑市。",
})
