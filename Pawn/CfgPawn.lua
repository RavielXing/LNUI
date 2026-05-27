U1RegisterAddon("Pawn", {
    title = LOCALE_zhCN and "装备比较评分" or "裝備比較評分",
    defaultEnable = 0,
    tags = {TAG_ITEM},
    icon = [[Interface\AddOns\Pawn\Textures\PawnIcon]],
    desc = LOCALE_zhCN and "Pawn插件，根据装备属性权重来计算评分，通过统计的分数来直观的看出，装备的整体属性收益对你来说是提升了还是降低了。" or "Pawn插件，根據裝備屬性權重來計算評分，通過統計的分數來直觀的看出，裝備的整體屬性收益對你來說是提升了還是降低了。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("Pawn"))
        end
    }
});
