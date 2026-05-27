U1RegisterAddon("TeleportAnnouncer", {
    title = LOCALE_zhCN and "传送门通报" or "傳送門通報",
    defaultEnable = 1,
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\AddOns\TeleportAnnouncer\icon.tga]],
    desc = LOCALE_zhCN and "使用传送法术时，自动在队伍频道通报目的地。" or "使用傳送法術時，自動在隊伍頻道通報目的地。",

	{
		text = "配置插件",
		callback = function()
			SlashCmdList["TELEPORTANNOUNCER"]()
		end,
	},
});
