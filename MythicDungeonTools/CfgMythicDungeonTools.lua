U1RegisterAddon("MythicDungeonTools", {
    title = LOCALE_zhCN and "大米路线规划" or "大米路線規劃",
    defaultEnable = 0,
    load = "NORMAL",
    minimap = "LibDBIcon10_MythicDungeonTools",
    icon = [[Interface\AddOns\MythicDungeonTools\Textures\MDTFull]],
    tags = { TAG_RAID },
    desc = "用于规划大秘境小怪进度的强力插件，命令： /mdt``可以访问国外网站`    https://wago.io/mdt `导入一些预案",
    pics = 0,

    toggle = function(name, info, enable, justload)
    end,

    {
        text = "开启窗口",
        callback = function(cfg, v, loading) MDT:ShowInterface() end,
    },
})