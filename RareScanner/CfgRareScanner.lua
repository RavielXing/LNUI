U1RegisterAddon("RareScanner", {
    title = LOCALE_zhCN and "稀有精英探测" or "稀有精英探測",
    defaultEnable = 0,
    load = 'NORMAL',
    secure = 1,

    tags = { TAG_MAPQUEST },
    icon = [[Interface\AddOns\RareScanner\Media\Icons\OriginalSkull]],
    desc = LOCALE_zhCN and "搜寻小地图标识，当发现稀有精英或宝箱的时候给出提示。" or "搜尋小地圖標識，當發現稀有精英或寶箱的時候給出提示。",

    toggle = function(name, info, enable, justload)
        if justload then
        end
    end,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("RareScanner"))
        end
    }
});