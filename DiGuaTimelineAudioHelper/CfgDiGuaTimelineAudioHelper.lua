U1RegisterAddon("DiGuaTimelineAudioHelper", {
    title = LOCALE_zhCN and "地瓜语音助手" or "地瓜語音助手",
    defaultEnable = 1,
    tags = { TAG_RAID },
    icon = [[Interface\AddOns\DiGuaTimelineAudioHelper\logo]],
    desc = LOCALE_zhCN and "感谢使用|cFF00FF00[神秘地瓜] 副本语音助手|r如果觉得好用，请在|cFFFFA6D5“爱发电”|r平台搜索|cFFFFFF00“神秘地瓜”|r支持我的插件，您的支持就是我最大的动力。" or "感謝使用|cFF00FF00[神秘地瓜] 副本語音助手|r如果覺得好用，請在|cFFFFA6D5「愛發電」|r平臺搜索|cFFFFFF00「神秘地瓜」|r支持我的插件，您的支持就是我最大的動力。",

	{
		text = "配置插件",
		callback = function()
			SlashCmdList["DIGUA"]()
		end,
	},
});
