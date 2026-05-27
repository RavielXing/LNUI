U1RegisterAddon("SavedInstances", {
    title = LOCALE_zhCN and "角色进度查询" or "角色進度查詢",
    defaultEnable = 0,
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\AddOns\SavedInstances\Media\Icon]],
    minimap = "LibDBIcon10_SavedInstances",
    desc = LOCALE_zhCN and "增加小地图按钮，可以查看帐号下所有角色的副本进度和Boss击杀情况。临时增加Method小号管理功能，点击小地图图标或者/alts打开。" or "增加小地圖按鈕，可以查看帳號下所有角色的副本進度和Boss擊殺情況。臨時增加Method小號管理功能，點擊小地圖圖標或者/alts打開。",
    nopic = 1,
    {
        text = LOCALE_zhCN and "显示副本进度框" or "顯示副本進度框",
        callback = function(cfg, v, loading) SlashCmdList["ACECONSOLE_SAVEDINSTANCES"]("show") end,
    },
    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading) SlashCmdList["ACECONSOLE_SAVEDINSTANCES"]("config") end,
    }
});