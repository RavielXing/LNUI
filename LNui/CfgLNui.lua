U1PLUG = {}
local function load(cfg, v, loading, no_reload, plugin, text)
    plugin = plugin or cfg.var
    if v and U1PLUG[plugin] then
        U1PLUG[plugin]()
        U1PLUG[plugin] = nil
        if not loading then
            local message = (LOCALE_zhCN and "已启用小功能 - " or "已啓用小功能 - ") .. text
            U1Message(message, 0.2, 1.0, 0.2)
        end
    elseif not v and not no_reload then
        if not loading then
            U1Message(LOCALE_zhCN and "停用小功能可能需要重载界面。" or "停用小功能可能需要重載界面。", 1.0, 0.2, 0.2)
        end
    end
end

U1_NEW_ICON = U1_NEW_ICON or '|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t'
U1RegisterAddon("LNui", {
    title = LOCALE_zhCN and "老农工具箱" or "老农工具箱",
    defaultEnable = 1,
    load = "NORMAL",
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\AddOns\!!!163UI!!!\Textures\UI2-icon]],
    desc = LOCALE_zhCN and "各种贴心小功能" or "各种贴心小功能",
    nopic = 1,

	{
		type = "text",
        text = "|cffFF2D2D启用/关闭相关功能后，需【重载界面】|r",       
	},

    {
        text = LOCALE_zhCN and "显示布局网格" or "显示布局网格",
        tip = LOCALE_zhCN and "说明`快捷命令/align 20 或 /wangge 30, 默认格子大小是30" or "说明`快捷命令/align 20 或 /wangge 30, 默认格子大小是30",
        callback = function(cfg, v, loading) SlashCmdList["EALIGN_UPDATED"]("") end,
    },

    {
        var = "elong",
        text = LOCALE_zhCN and U1_NEW_ICON.."嗜血技能语音" or U1_NEW_ICON.."嗜血技能語音",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`为嗜血与英勇等重要技能添加语音文件。" or "說明`為嗜血與英勇等重要技能添加語音文件。",
    },

    {
        var = "AutoHideLootHistory",
        text = LOCALE_zhCN and "自动关闭战利品投掷" or "自動關閉戰利品投擲",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`15秒后自动关闭战利品投掷窗口，若鼠标在窗口上暂停计时。" or "說明`15秒後自動關閉戰利品投擲窗口，若鼠標在窗口上暫停計時。",
    },

    {
        var = "daojishi",
        text = LOCALE_zhCN and "显示随机框到期时间" or "顯示隨機到期時間",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`在随机或PVP排队界面显示到期时间。" or "說明`在隨機或PVP排隊界面顯示到期時間。",
    },

    {
        var = "na",
        text = LOCALE_zhCN and "Buff栏显示N/A" or "Buff欄顯示N/A",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`BUFF和DEBUFF显示N/A功能。" or "說明`BUFF和DEBUFF顯示N/A功能。",
    },

    {
        var = "QuickAuctionBuyer",
        text = LOCALE_zhCN and "拍卖行购物助手" or "拍賣行購物助手",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`拍卖行界面右侧扩展快速搜索[消耗品][宝石][附魔]的工具。" or "說明`拍賣行界面右側擴展快速搜索[消耗品][寶石][附魔]的工具。",
    },

    {
        var = "VersionChecker",
        text = LOCALE_zhCN and "有新版整合包更新通报" or "有新版整合包更新通報",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`当老农整合包有新版更新时，在聊天框中提示。" or "說明`當老農整合包有新版更新時，在聊天框中提示。",
    },

    {
        var = "touxiang",
        text = LOCALE_zhCN and "游戏原生头像美化" or "游戲原生頭像美化",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`原生头像职业颜色、材质替换、万亿简写、点击交易、精英头像、隐藏元素等。" or "說明`原生頭像職業顏色、材質替換、萬億簡寫、點擊交易、精英頭像、隱藏元素等。",
    },

    {
        var = "MythicScore", text = LOCALE_zhCN and "史诗钥石界面直接显示分数" or "史诗钥石界面直接显示分数", default = true,
    },

    {
        var = "UnlimitedMapPinDistance", text = LOCALE_zhCN and "导航地图标记无限距离" or "导航地图标记无限距离", default = true, callback = load, tip = LOCALE_zhCN and "说明`9.0新增的游戏内导航，暴雪限制地图标记在1000码-100码之内才显示，可以取消这个限制" or "说明`9.0新增的游戏内导航，暴雪限制地图标记在1000码-100码之内才显示，可以取消这个限制"
    },

    {
        var = "AlwaysShowAltBarText", text = LOCALE_zhCN and "始终显示特殊能量条的文字" or "始终显示特殊能量条的文字", default = true,
        tip = LOCALE_zhCN and "说明`在大小幻象里，始终显示能量条上面的文字，便于查看。" or "说明`在大小幻象里，始终显示能量条上面的文字，便于查看。",
    },

    {
        var = "AddonProfilerToggle",
        text = LOCALE_zhCN and "关闭CPU性能分析" or "關閉CPU性能分析",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "关闭暴雪插件性能分析功能，恢复11.1消失的帧数。" or "關閉暴雪插件性能分析功能，恢復11.1消失的幀數。",
    },

    {
        var = "ItemUpgradeTooltip",
        text = LOCALE_zhCN and "装备升级装等范围" or "裝備升級裝等範圍",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "在装备界面显示装备升级装等范围。" or "在裝備界面顯示裝備升級裝等範圍。",
    },

    {
        var = "ExaltedPlus", text = LOCALE_zhCN and "声望增强" or "声望增强", default = true, callback = load,
        tip = LOCALE_zhCN and "说明`7.2版本新增功能`声望面板直接显示崇拜后的进度。`获得声望时会显示当前进度。`可以设置自动追踪刚获得的声望。" or "说明`7.2版本新增功能`声望面板直接显示崇拜后的进度。`获得声望时会显示当前进度。`可以设置自动追踪刚获得的声望。",
        {
            var = "autotrace",
            default = true,
            text = LOCALE_zhCN and "满级后自动追踪刚提升的声望" or "满级后自动追踪刚提升的声望"
        }
    },

    {
        var = "minimapdifficulty",
        text = LOCALE_zhCN and "小地图副本难度" or "小地圖副本難度",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`小地图显示副本难度。" or "说明`小地圖顯示副本難度。",
    },

    {
        var = "DamageValue",
        text = LOCALE_zhCN and "伤害统计显示万亿" or "傷害統計顯示萬億",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`伤害统计显示万亿。" or "说明`傷害統計顯示萬億。",
    },

    {
        var = "skipTalkingHead",
        default = false,
        text = LOCALE_zhCN and "完全屏蔽剧情台词窗口" or "完全屏蔽剧情台词窗口",
        confirm = LOCALE_zhCN and "建议通过双击空格关闭台词窗口，\n完全屏蔽可能会导致剧情不连贯。\n您确定吗?" or "建议通过双击空格关闭台词窗口，\n完全屏蔽可能会导致剧情不连贯。\n您确定吗?",
        tip = LOCALE_zhCN and "说明`7.0新增的窗口，如果启用此选项，则完全屏蔽，毫无痕迹。建议不要启用，提供了双击空格直接关闭当前台词的功能。" or "说明`7.0新增的窗口，如果启用此选项，则完全屏蔽，毫无痕迹。建议不要启用，提供了双击空格直接关闭当前台词的功能。",
        callback = function(cfg, v, loading) U1Toggle_SkipTalkingHead(v) end,
    },

    {
        var = "88Movie",
        text = LOCALE_zhCN and "跳过所有过场动画" or "跳過所有過場動畫",
        default = false,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`跳过所有过场动画。" or "說明`跳過所有過場動畫。",
    },


    {
        var = "shuangjikongge",
        text = LOCALE_zhCN and "双击空格关闭台词窗口" or "雙擊空格關閉臺詞窗口",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`你可以通过双击空格键，来关闭剧情台词窗口。" or "説明`你可以通過雙擊空格鍵，來關閉劇情臺詞窗口。",
    },

    {
        var = "HideQuickJoin",
        text = LOCALE_zhCN and "屏蔽快速加入提示" or "屏蔽快速加入提示",
        default = false,
        tip = LOCALE_zhCN and "说明`7.1新增的快速加入提示消息，贴心提供屏蔽功能。" or "说明`7.1新增的快速加入提示消息，贴心提供屏蔽功能。",
        callback = function(cfg, v, loading) U1Toggle_QuickJoinToasts(not v, loading) end,
    },

    {
        var = "replaceTalent",
        default = true,
        text = LOCALE_zhCN and "自动替换天赋技能" or "自动替换天赋技能",
        tip = LOCALE_zhCN and "说明`当同一层天赋是不能并存的主动技能时，更换天赋会用新技能替换动作条上的旧技能，而不是同时存在新旧两个技能" or "说明`当同一层天赋是不能并存的主动技能时，更换天赋会用新技能替换动作条上的旧技能，而不是同时存在新旧两个技能",
    },

    {
        var = "garrisonMMB",
        default = true,
        text = LOCALE_zhCN and "职业大厅小地图按钮" or "职业大厅小地图按钮",
        tip = LOCALE_zhCN and "说明`把职业大厅小地图按钮缩小为普通小地图按钮大小，并支持拖动。关闭此功能需要重载界面" or "说明`把职业大厅小地图按钮缩小为普通小地图按钮大小，并支持拖动。关闭此功能需要重载界面",
        callback = function(cfg, v, loading)
            if not loading and v then U1_ProcessGarrisonLandingPageMMB() end
            if not loading and not v then U1Message(LOCALE_zhCN and "停用小功能需要重载界面" or "停用小功能需要重载界面", 1.0, 0.2, 0.2) end
        end
    },

    {
        var = "QuestWatchSort", text = LOCALE_zhCN and "任务追踪按距离排序" or "任务追踪按距离排序", default = false, callback = load,
        tip = LOCALE_zhCN and "说明`按任务远近进行排序``暴雪的任务排序功能失效很久了,为您临时提供解决方案" or "说明`按任务远近进行排序``暴雪的任务排序功能失效很久了,为您临时提供解决方案",
    },

    {
        var = "DejaPRFader",
        text = LOCALE_zhCN and "隐藏团队管理边框" or "隱藏團隊管理邊框",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`隐藏团队管理左侧的边框。" or "説明`隱藏團隊管理左側的邊框。",
    },

    {
        var = "Focuser",
        text = LOCALE_zhCN and "shift焦点目标" or "shift焦點目標",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`shift + 目标，可以快速设置焦点目标。" or "说明`shift + 目標，可以快速設置焦點目標。",
    },

    {
        var = "LFGInviteAnnouncer",
        text = LOCALE_zhCN and "提示加入什么副本" or "提示加入什麽副本",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`集合石进组后提示你加入的是什么副本&活动，输入 /lfgia move，拖动你想要的位置。" or "说明`集合石進組後提示妳加入的是什麽副本&活動，輸入 /lfgia move，拖動你想要的位置。",
    },

    {
        var = "AutoLootPlus",
        text = LOCALE_zhCN and "超快自动拾取" or "超快自動拾取",
        default = false,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`打开拾取界面的瞬间捡起里面所有东西(只在开启自动拾取时有效)。" or "说明`打開拾取界面的瞬間撿起裏面所有東西(只在開啟自動拾取時有效)。",
    },

    -- {
        -- var = "zZ_Bufftimes",
        -- text = LOCALE_zhCN and "Buff时间显示" or "Buff時間顯示",
        -- default = true,
        -- callback = function(cfg, v, loading)
            -- load(cfg, v, loading, nil, nil, cfg.text)
        -- end,
        -- tip = LOCALE_zhCN and "说明`在右上角Buff时间显示。" or "说明`在右上角Buff時間顯示。",
    -- },

    {
        var = "CastBar",
        text = LOCALE_zhCN and "原生施法条增强" or "原生施法條增強",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`在原生施法条上增加图标和倒计时。" or "说明`在原生施法條上增加圖標和倒計時。",
    },

    {
        var = "CopyFriendList",
        text = LOCALE_zhCN and "好友复制功能" or "好友复制功能",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`点击好友列表（O键面板）左上角可以弹出好友复制功能菜单，可以复制同账号下其他角色的游戏内好友列表。" or "说明`点击好友列表（O键面板）左上角可以弹出好友复制功能菜单，可以复制同账号下其他角色的游戏内好友列表。",
    },

    {
        var = "FriendsGuildTab",
        text = LOCALE_zhCN and "好友面板公会切换按钮" or "好友面板公会切换按钮",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`在好友面板右下角添加切换到公会面板的按钮" or "说明`在好友面板右下角添加切换到公会面板的按钮",
    },

    {
        var = "GuildRosterButtons",
        text = LOCALE_zhCN and "公会名单切换按钮" or "公会名单切换按钮",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`在公会名单面板上显示一组按钮，用来切换'玩家状态','专业'等，比默认的下拉菜单方式要方便一些。" or "说明`在公会名单面板上显示一组按钮，用来切换'玩家状态','专业'等，比默认的下拉菜单方式要方便一些。",
    },

    {
        var = "FixBlizGuild",
        text = LOCALE_zhCN and "延迟加载公会新闻" or "延迟加载公会新闻",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`打开公会面板时不加载公会新闻，可能会减少初次打开公会卡死的问题。" or "说明`打开公会面板时不加载公会新闻，可能会减少初次打开公会卡死的问题。",
    },

    {
        var = "OpenBags",
        text = LOCALE_zhCN and "开启银行时打开全部背包" or "开启银行时打开全部背包",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "开启银行时打开全部背包" or "开启银行时打开全部背包",
    },

    {
        var = "bfautorelease",
        default = false,
        text = LOCALE_zhCN and "战场中自动释放灵魂" or "战场中自动释放灵魂",
    },

    {
        var = "map_raid_color",
        default = true,
        text = LOCALE_zhCN and "地图队友图标颜色" or "地图队友图标颜色",
        tip = LOCALE_zhCN and "说明`大地图和小地图上的队友圆点显示为起职业颜色" or "说明`大地图和小地图上的队友圆点显示为起职业颜色",
        reload = 1,
        callback = function(cfg, v, loading)
            local mod = U1PLUGIN_ColorRostersOnMap
            if(mod and mod.Init) then
                return mod:Init()
            end
        end,
    },

    {
        var = "SlashCommands",
        text = LOCALE_zhCN and "快捷命令" or "快捷命令",
        default = true,
        callback = function(cfg, v, loading)
            load(cfg, v, loading, nil, nil, cfg.text)
        end,
        tip = LOCALE_zhCN and "说明`增加若干命令行指令`● /tele 传入传出随机副本`● /in 秒数 其他命令`　　延迟N秒后执行其他命令`　　例如/in 1 /yell 开怪啦" or "说明`增加若干命令行指令`● /tele 传入传出随机副本`● /in 秒数 其他命令`　　延迟N秒后执行其他命令`　　例如/in 1 /yell 开怪啦",
    },
})
