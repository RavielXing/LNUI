U1RegisterAddon("ItemInfoOverlay", {
    title = LOCALE_zhCN and "装备装等观察" or "裝備裝等觀察",
    defaultEnable = 1,
    load = 'LOGIN',
    tags = { TAG_ITEM },
    icon = 625999,
    desc = LOCALE_zhCN and "老李三鹿李 @ nga 制作的物品信息显示、角色装备界面增强。" or "老李三鹿李 @ nga 製作的物品信息顯示、角色裝備界面增強。",

	{
		text = "配置插件",
		callback = function()
			SlashCmdList["ITEMINFOOVERLAY"]()
		end,
	},
});