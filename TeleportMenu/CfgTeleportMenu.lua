U1RegisterAddon("TeleportMenu", {
    title = LOCALE_zhCN and "传送菜单" or "傳送菜單",
    defaultEnable = 1,
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\Icons\inv_hearthstonepet]],
    desc = LOCALE_zhCN and "主菜单显示炉石玩具和各种传送按钮等。" or "主菜單顯示爐石玩具和各種傳送按鈕等。",
	
    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("TeleportMenu"))
        end
    }
});
