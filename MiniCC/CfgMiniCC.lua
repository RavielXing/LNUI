U1RegisterAddon("MiniCC", {
    title = LOCALE_zhCN and "控制技能提示" or "控製技能提示",
    defaultEnable = 0,
    tags = { TAG_PVP },
    icon = [[Interface\AddOns\MiniCC\Icon]],
    desc = LOCALE_zhCN and "在头像上提示控制技能图标及其剩余时间。" or "在頭像上提示控製技能圖標及其剩余時間。",
    nopic = 1,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("MiniCC"))
        end
    },
});
