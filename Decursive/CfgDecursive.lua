U1RegisterAddon("Decursive", {
    title = LOCALE_zhCN and "一键驱散" or "一鍵驅散",
    defaultEnable = 0,
    load = "LOGIN",

    tags = { TAG_RAID },
    icon = [[Interface/AddOns/Decursive/iconOFF]],
    desc = LOCALE_zhCN and "方便驱散自身和队友负面状态的插件。" or "方便驅散自身和隊友負面狀態的插件。",

    toggle = function(name, info, enable, justload)
        if not justload then
            if enable then
                SlashCmdList["ACECONSOLE_DCR"]("enable");
            else
                SlashCmdList["ACECONSOLE_DCR"]("disable");
                StaticPopup1:Hide()
            end
        end
    end,
    -------- Options --------
    {
        text = LOCALE_zhCN and "运行命令/dcrshow" or "運行命令/dcrshow",
        callback = function(cfg, v, loading) SlashCmdList["ACECONSOLE_DCRSHOW"]() end,
    },
    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        tip = LOCALE_zhCN and "快捷命令`/decursive" or "快捷命令`/decursive",
        callback = function(cfg, v, loading) SlashCmdList["ACECONSOLE_DECURSIVE"]() end,
    },
    --]]
});
