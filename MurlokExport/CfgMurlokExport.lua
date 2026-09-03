U1RegisterAddon("MurlokExport", {
    title = LOCALE_zhCN and "全职业天赋汇总" or "全職業天賦匯總",
    defaultEnable = 0,
    tags = { TAG_MANAGEMENT, TAG_GOOD },
    icon = [[Interface/AddOns/MurlokExport/Artwork/MurlokExport]],
    minimap = "LibDBIcon10_MurlokExport",
    desc = LOCALE_zhCN and "【内存占用非常高，不用时候建议关闭】是一款零干扰的资讯类插件：它把 murlok.io 上的顶级玩家（每专精 Top 50）数据在游戏内做成简明面板，覆盖 大秘境 与 Solo PvP 两大场景。你无需切窗口，就能对照当前号的属性分布、天赋、装备与附魔。" or "【內存占用非常高，不用時候建議關閉】是一款零幹擾的資訊類插件：它把 murlok.io 上的頂級玩家（每專精 Top 50）數據在遊戲內做成簡明面板，覆蓋 大秘境 與 Solo PvP 兩大場景。你無需切窗口，就能對照當前號的屬性分布、天賦、裝備與附魔。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("MurlokExport"))
        end
    }
});
