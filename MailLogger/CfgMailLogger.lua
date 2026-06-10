U1RegisterAddon("MailLogger", {
    title = LOCALE_zhCN and "交易记录助手" or "交易記錄助手",
    defaultEnable = 0,
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\MINIMAP\TRACKING\Mailbox]],
    minimap = "LibDBIcon10_MailLogger",
    desc = LOCALE_zhCN and "MailLogger 插件是一个功能强大且实用的交易和邮件记录工具，通过自动化记录、便捷查询、多条件筛选和直观的界面设计，帮助玩家更好地管理游戏中的交易和邮件活动。" or "MailLogger 插件是一個功能強大且實用的交易和郵件記錄工具，通過自動化記錄、便捷查詢、多條件篩選和直觀的界面設計，幫助玩家更好地管理遊戲中的交易和郵件活動。",

    { text = LOCALE_zhCN and "主界面设置" or "主界面設置", callback = function(cfg, v, loading) SlashCmdList["ml"]("gui") end },
	
});
