U1RegisterAddon("MinimalistCooldownEdge", {
    title = LOCALE_zhCN and "技能冷却计时" or "技能冷卻計時",
    defaultEnable = 1,
    load = "LOGIN",
    tags = { TAG_COMBATINFO },
    icon = [[Interface\AddOns\MinimalistCooldownEdge\Assets\Textures\MinimalistCooldownEdge]],
    desc = LOCALE_zhCN and "给所有的技能冷却动画添加文字显示及冷却后的效果。" or "給所有的技能冷卻動畫添加文字顯示及冷卻後的效果。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("MiniCE"))
        end
    },
});
