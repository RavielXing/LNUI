U1RegisterAddon("MySlot", {
    title = LOCALE_zhCN and "技能栏保存" or "技能欄保存",
    defaultEnable = 0,
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\AddOns\Myslot\Myslot.blp]],
    minimap = "LibDBIcon10_Myslot",
    desc = LOCALE_zhCN and "可以将当前角色的全部技能栏/宏命令/按键设置导出为一大段文本，另行保存到记事本里，这样洗掉专精再换回来时可以再导回来，也可以避免被其他人误修改。" or "可以將當前角色的全部技能欄/宏命令/按鍵設置導出為一大段文本，另行保存到記事本裏，這樣洗掉專精再換回來時可以再導回來，也可以避免被其他人誤修改。",
    nopic = 1,

    {
        text = LOCALE_zhCN and "导入 / 导出" or "導入 / 導出",
        callback = function(cfg, v, loading) SlashCmdList[ "MYSLOT" ]("") end,
    },
});
