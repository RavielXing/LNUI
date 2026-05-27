U1RegisterAddon("KeystoneLoot", {
    title = LOCALE_zhCN and "大米战利品查询" or "大米戰利品查詢",
    defaultEnable = 0,
    tags = {TAG_ITEM},
    minimap = "LibDBIcon10_KeystoneLoot",
    desc = LOCALE_zhCN and "显示所有大秘境副本的掉落，并可以标记最爱。" or "顯示所有大秘境副本的掉落，並可以標記最愛。",
    icon = [[Interface\Icons\INV_Relics_Hourglass_02]],

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading) SlashCmdList.KEYSTONELOOT("KSL") end,
    },
});
