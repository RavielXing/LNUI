U1RegisterAddon("BtWQuests", {
    title = LOCALE_zhCN and "任务指南" or "任務指南",
    tags = { TAG_MAPQUEST },
    defaultEnable = 0,
    load = "NORMAL",
    minimap = "BtWQuestsMinimapButton",
    icon = [[Interface\QuestFrame\UI-QuestLog-BookIcon]],
    desc = LOCALE_zhCN and "BtwQuests插件是一款任务追溯插件，它可以根据你角色的任务进度，找到随时某个任务节点，查看任务要求，NPC地点等等。" or "BtwQuests插件是壹款任務追溯插件，它可以根據妳角色的任務進度，找到隨時某個任務節點，查看任務要求，NPC地點等等。",
});

U1RegisterAddon("BtWQuestsMidnight", { title = "1-至暗之夜任务", defaultEnable = 1, load="NORMAL", desc = "至暗之夜任务", });
U1RegisterAddon("BtWQuestsMidnightPrologue", { title = "2-至暗之夜开场任务", defaultEnable = 1, load="NORMAL", desc = "至暗之夜开场任务", });
U1RegisterAddon("BtWQuestsTheWarWithin", { title = "3-地心之战任务", defaultEnable = 0, load="NORMAL", ignoreLoadAll = 1, desc = "地心之战任务", });
U1RegisterAddon("BtWQuestsDragonflight", { title = "4-巨龙时代任务", defaultEnable = 0, load="NORMAL", ignoreLoadAll = 1, desc = "巨龙时代任务。" });