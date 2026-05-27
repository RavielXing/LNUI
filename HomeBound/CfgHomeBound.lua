U1RegisterAddon("HomeBound", {
    title = LOCALE_zhCN and "家宅装饰清单" or "家宅裝飾清單",
    defaultEnable = 0,
    minimap = "LibDBIcon10_HomeBound",
    modifier = "电视卫 @NGA 汉化",
    tags = { TAG_INTERFACE, TAG_GOOD },
    icon = 7252953,
    desc = LOCALE_zhCN and "收集家宅装饰时的最佳伴侣！电视卫士汉化版！" or "收集家宅裝飾時的最佳伴侶！電視衛士漢化版！",
	
	{
        text = LOCALE_zhCN and "配置选项" or "配置選項",
		callback = function()
			SlashCmdList["HB"]()
		end,
	},

});

