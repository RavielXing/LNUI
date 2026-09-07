U1RegisterAddon("GearInsight", {
    title = LOCALE_zhCN and "毕业装备查询 " or "畢業裝備查詢 ",
    defaultEnable = 0,
    tags = {TAG_ITEM, TAG_GOOD },
    icon = [[Interface\AddOns\GearInsight\icon]],
    minimap = "GearInsightMinimapButton",
    desc = LOCALE_zhCN and "毕业装备(BiS)查询：按职业专精看部位毕业件、属性目标、宝石附魔消耗品，团本/大秘境双使用率参照，缺件刷取规划。" or "畢業裝備(BiS)查詢：按職業專精看部位畢業件、屬性目標、寶石附魔消耗品，團本/大秘境雙使用率參照，缺件刷取規劃。",
});

U1RegisterAddon("GearInsight_Talents", { title = LOCALE_zhCN and "天赋库 (WCL)" or "天賦庫 (WCL)", parent = "GearInsight", defaultEnable = 1, })
U1RegisterAddon("GearInsight_Dungeon", { title = LOCALE_zhCN and "副本助手 (大米指导/嗜血提醒)" or "副本助手 (大米指導/嗜血提醒)", parent = "GearInsight", defaultEnable = 1, })