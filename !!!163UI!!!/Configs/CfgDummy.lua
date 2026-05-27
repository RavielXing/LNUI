--[[------------------------------------------------------------
Dummy的插件默認值：
- defaultEnable = 1
- desc = "此項功能為一系列小插件的組合……"
---------------------------------------------------------------]]
U1RegisterAddon("!!Forwarder", { dummy = 1,
    title = "頻道轉發",
    tags = { TAG_CHAT },
    icon = [[Interface\Icons\ACHIEVEMENT_GUILDPERK_HONORABLEMENTION_RANK2]],
    desc = "在野外也可以看到組隊頻道和交易頻道的信息，插件由愛不易warbaby原創奉獻",
    author = "|cffcd1a1c[愛不易原創]|r",
    defaultEnable = 0,

    children = {"LFGForwarder", "TradeForwarder"},
})

--[[
U1RegisterAddon("!!UnitFrames", { dummy = 1,
    title = "頭像增強",
    tags = { TAG_INTERFACE },
    icon = "Interface\\Icons\\Achievement_Reputation_Ogre",

    children = {"EN_UnitFrames", "ToTxp", "TargetButton", },
})
]]

U1RegisterAddon("!!TradeSkill", { dummy = 1,
    title = "專業技能助手",
    tags = { TAG_TRADING },
    icon = [[Interface\Icons\Ability_Racial_BetterLivingThroughChemistry]],
    desc = "對系統專業技能面板的增強",

    children = {"EnhancedTradeSkillUI", "TradeTabs", "WarbabyTradeLink", },
    {
        var = "knownRecipes",
        text = "啟用已學配方染色",
        tip = "說明`將拍賣行和商人等處已學會的配方染為綠色.",
        default = 1,
        alwaysEnable = 1,
    },
})

-- U1RegisterAddon("LibMapData-1.0", {
--     title = "庫：地圖數據",
--     load = "NORMAL",
--     icon = "Interface\\HelpFrame\\HelpIcon-ReportAbuse",
--     desc = "很多單體插件使用了地圖數據（LibMapData）這個庫，但由於更新不及時，玩家到新地圖上時會不停的刷屏。`愛不易特別製作了一個最新版的庫，當遇到插件刷MapData Missing的時候啟用即可。`如果沒有單體插件或沒有使用這個庫的單體插件，可以完全關閉或刪除此插件。",
--     alwaysRegister = 1,
--     defaultEnable = 1,
--     tags = { TAG_MANAGEMENT }
-- })
