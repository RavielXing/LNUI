U1RegisterAddon("DiGuaTimelineAudioHelper", {
    title = LOCALE_zhCN and "地瓜语音助手" or "地瓜語音助手",
    defaultEnable = 1,
    tags = { TAG_RAID },
    icon = [[Interface\AddOns\DiGuaTimelineAudioHelper\logo]],
    desc = LOCALE_zhCN and "副本怪物技能语音播报插件，帮助新手快速熟悉副本机制。" or "副本怪物技能語音播報插件，幫助新手快速熟悉副本機制。",

	{
		text = "配置插件",
		callback = function()
			SlashCmdList["DIGUA"]()
		end,
	},
});
