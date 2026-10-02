U1RegisterAddon("GroupFinder", {
    title = LOCALE_zhCN and "魔兽集合石" or "魔獸集合石",
    tags = { TAG_RAID },
    minimap = "LibDBIcon10_GroupFinderLauncher",
    icon = [[Interface\AddOns\GroupFinder\Art\Logo\GroupFinder.png]],
    defaultEnable = 1,
    desc = LOCALE_zhCN and "一款专为《魔兽世界》正式服设计的跨服组队招募平台，整合系统原生“队伍查找器”功能，通过队伍搜索、招募发布、申请管理、高级过滤与黑名单屏蔽功能，帮助玩家快速查找目标队伍、管理招募流程，并更精准地匹配合适的队友。" or "一款專為《魔獸世界》正式服設計的跨服組隊招募平臺,整合系統原生「隊伍查找器」功能,通過隊伍搜索、招募發布、申請管理、高級過濾與黑名單屏蔽功能,幫助玩家快速查找目標隊伍、管理招募流程,並更精準地匹配合適的隊友。",
});

U1RegisterAddon("GroupFinder_Laonong", { title = "1-老农整合包扩展", defaultEnable = 1, load="NORMAL", desc = "按需加载的老农整合包粉丝身份与图标支持。" });
U1RegisterAddon("GroupFinder_Locales", { title = "2-语言资源", defaultEnable = 1, load="NORMAL", desc = "魔兽集合石的多语言资源，默认跟随游戏语言，仅加载当前选用的语言；手动切换后需重载界面生效。" });
U1RegisterAddon("GroupFinder_WorkspaceUI", { title = "3-地下城和团队副本", defaultEnable = 1, load="NORMAL", ignoreLoadAll = 1, desc = "魔兽集合石的工作区界面，包含寻找团队、创建招募、团本求组和大秘境等页面，首次打开主界面时加载。" });
U1RegisterAddon("GroupFinder_NetEase", { title = "4-网易新兵活动", defaultEnable = 0, load="NORMAL", ignoreLoadAll = 1, desc = "按需加载的网易新兵活动与玩家身份查询组件。" });