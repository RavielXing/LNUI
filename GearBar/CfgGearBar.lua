U1RegisterAddon("GearBar", {
    title = LOCALE_zhCN and "饰品管理" or "飾品管理",
    defaultEnable = 0,
    tags = { TAG_ITEM },
    icon = [[Interface\Icons\INV_Jewelry_Talisman_13]],
    desc = LOCALE_zhCN and "显示两个饰品按钮。按钮之间的空当处按住可移动位置" or "顯示兩個飾品按鈕。按鈕之間的空擋処按住可移動位置",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("GearBar"))
        end
    }

});
