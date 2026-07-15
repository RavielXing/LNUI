U1ChangeLogFrame.TitleText:SetText("|cff19CCF9老|cffffb300农|cffD56AFF整|cffFF2AA5合|cff3cff00包|r |CFFFFFFFF-|r |cffFFD100更新记录|r");
-- 新增图片代码 --
-- local logo = U1ChangeLogFrame:CreateTexture(nil, "ARTWORK")
-- logo:SetTexture("Interface\\AddOns\\!!!163UI!!!\\Textures\\aitocar.blp")
-- logo:SetSize(220, 220)
-- logo:SetPoint("LEFT", U1ChangeLogFrame.TitleText, "RIGHT", 50, -125)

U1ChangeLogFrame.ContentText:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE");
U1ChangeLogFrame.ContentText:SetText([[|cffFFD100★衷心感谢 KeiraMetz @ NGA 鼎力帮助，修复众多插件问题★|r

|cff19CCF9[2026年7月16日更新内容][526版]：|r
1.客人订单助手(DFCN_PatronOffers)升级到1.79
2.冷却管理器(Coolinator)升级到100
3.全职业天赋汇总(MurlokExport)升级到20260715.002659
4.装备比较评分(Pawn)升级到2.13.13
5.地图标记(HandyNotes)各模块升级到146
6.家宅装饰清单(HomeBound)升级到1.47_CN
7.技能冷却计时(MinimalistCooldownEdge)升级到4.1.6
8.老农插件中心(!!!163UI!!!)升级到20260715

|cff19CCF9[2026年7月9日更新内容][525版]：|r
1.老农聊天条(LNuiChat)升级到20260706
2.冷却管理器(Coolinator)升级到94
3.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.5.9
4.智能快捷按钮(LiteBuff)升级到20260707 (感谢 黑龙呀)
5.一键驱散(Decursive)升级到2.8.1-RC1
6.技能冷却计时(MinimalistCooldownEdge)升级到4.1.5
7.全职业天赋汇总(MurlokExport)升级到20260709.003659
8.客人订单助手(DFCN_PatronOffers)升级到1.78
9.姓名板助手(Platynator)升级到434
10.拍卖小助手(Auctionator)升级到329
11.背包增强插件(Baganator)升级到812
12.游戏界面移动(BlizzMove)升级到3.7.38
13.背包物品同步(Syndicator)升级到273
14.家宅装饰清单(HomeBound)升级到1.46_CN

|cff19CCF9[2026年7月5日更新内容][524版]：|r
1.控制技能提示(MiniCC)升级到4.6.0
2.全职业天赋汇总(MurlokExport)升级到20260705.003921
3.背包增强插件(Baganator)升级到810
4.冷却管理器(Coolinator)升级到82
5.大米路线规划(MythicDungeonTools)升级到6.1.20
6.姓名板助手(Platynator)升级到432
7.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.5.8
8.客人订单助手(DFCN_PatronOffers)升级到1.77
9.队伍查找器(GroupFinder)升级到1.2.6
  |cff7F7F7F--优化：支持暴雪原生搜索框的搜索建议框，并提高搜索建议框的层级。
  --新增：老农粉丝榜福利彩蛋。|r

|cff19CCF9[2026年7月3日更新内容][523版]：|r
1.冷却管理器(Coolinator)升级到77
2.客人订单助手(DFCN_PatronOffers)升级到1.76
3.全职业天赋汇总(MurlokExport)升级到20260702.004554
4.世界飞行地图(WorldFlightMap)升级到20260702
5.技能冷却计时(MinimalistCooldownEdge)升级到4.1.3
6.便捷小工具插件(Plumber)升级到1.9.3-c
7.队伍查找器(GroupFinder)升级到1.2.5
  |cff7F7F7F--修复：受邀进队后再退队时，寻找队伍将自动清理过期申请与已加入状态，避免旧队伍继续显示'已加入'并点亮悬浮窗。
  --修复：优化寻找队伍结果有效性判断、普通地下城父级聚合搜索与团本聚合搜索逻辑，降低'未知目标'脏数据与不可申请结果残留风险。
  --修复：黑名单列表恢复共享行背景 atlas 渲染，避免警示行显示为纯色块，并继续跟随'警示背景颜色'设置。
  --修复：修复副本类型导航飞窗的鼠标悬停样式异常，统一菜单交互视觉反馈。
  --新增：赛季/团队副本高级筛选新增'职责过滤'，可按坦克、治疗、输出人数快速筛选队伍。
  --新增：创建招募面板右下角新增'职责计数器'，可实时查看当前队伍 / 团队的职责构成与人数。
  --新增：赛季地下城高级筛选的副本选择区域新增'清空'按钮，可一键取消已选全部副本。
  --新增：设置页'视觉与外观'新增'列表'配色设置，可分别调整默认、好友、警示与置灰列表行的背景颜色和透明度，并支持实时预览与单项恢复默认。
  --新增：高级过滤'职责筛选'新增筛选模式，可在'全部匹配'与'任一匹配'之间切换。
  --新增：设置页'队伍列表-队伍成员模式'新增'专精模式(适老版)'，放大专精右上角的职责图标，为了清晰阅读专精图标信息，右上角的图标仅显示坦克与治疗类型，输出类职责不再显示。
  --优化：寻找队伍搜索/刷新按钮在检索与冷却期间统一显示加载动效，冷却期间触发的搜索会在冷却结束后延迟执行，避免过早返回空列表。
  --优化：创建招募申请人列表改为增量刷新，单个申请更新仅重绘对应行；申请人增减时保留当前滚动位置，并以置灰行标记失效申请。
  --优化：队伍成员与申请人专精图标改用客户端专精/职业图标解析，统一圆形遮罩与职责角标显示。
  --优化：申请提示音效选项调整为静态列表并完善默认值迁移，避免旧保存值影响新的默认音效。|r

|cff19CCF9[2026年7月2日更新内容][521、522版]：|r
1.老农插件中心(!!!163UI!!!)升级到20260701
  |cff7F7F7F--新按钮材质源自 蓝雨秋夜 @ NGA，衷心致谢。|r
2.全职业天赋汇总(MurlokExport)升级到20260630.004639
3.稀有精英探测(RareScanner)升级到12.0.7.2
4.冷却管理器(Coolinator)升级到73
5.智能快捷按钮(LiteBuff)升级到20260702 (感谢 黑龙呀)
6.队伍查找器(GroupFinder)升级到1.2.2
  |cff7F7F7F--适配：适配魔兽世界 12.1 PTR 版本。
  --修复：重构寻找队伍搜索调度逻辑，完善赛季副本、地下堡目录、高级筛选范围与多语言副本 ID 映射，降低 12.1 版本及台服客户端出现分类错乱的风险。
  --修复：受魔兽世界 12.0 版本限制，插件无法稳定获取队伍标题明文信息；现已调整'屏蔽同标题队伍'逻辑，在扫描到可见队伍名称时，将先拉黑该队伍队长，并联动屏蔽其他相同队伍名称的队长。
  --新增：补充繁体中文本地化支持，并加入调试语言切换能力。
  --新增：设置页'行为与音效'新增申请提示音效，发布招募期间有新申请时将自动播放音效。
  --优化：副本类型一级导航新增右键快捷操作，右键点击一级分类可立即搜索该分类下全部副本；右键点击'历史记录 / 重置'可一键清空所有搜索项。
  --优化：为了防止队伍列表自动滚动，失效、满员或已解散的搜索结果将先置灰并保留当前滚动位置，点击置灰条目后再移除并自动补行。
  --优化：创建招募申请人角色信息查询将根据招募类型显示大秘境、团本或紧凑链接，并优化 WCL 详情列展示，避免内容被截断。|r

|cff19CCF9[2026年6月26日更新内容][519、520版]：|r
1.冷却管理器(Coolinator)升级到67
2.地图标记(HandyNotes)各模块升级到145
3.全职业天赋汇总(MurlokExport)升级到20260629.004842
4.老农插件中心(!!!163UI!!!)升级到20260622
5.技能栏保存(Myslot)升级到6.0.0
6.控制技能提示(MiniCC)升级到4.5.4
7.库文件(!!!Libs)升级到20260628
8.战斗计时(163UI_CombatTimer)升级到20260628
9.老农工具箱(LNui)升级到20260628
10.客人订单助手(DFCN_PatronOffers)升级到1.74
11.商人界面扩展(Krowi_ExtendedVendorUI)升级到22.1
12.PVP战场框体(BattleGroundEnemiesFixed)升级到12.0.7.2
13.背包物品同步(Syndicator)升级到271
14.鼠标提示增强(TipTac)升级到26.06.27
  |cff7F7F7F--自行新增改善装备对比掉帧卡顿措施 |r
15.队伍查找器(GroupFinder)新增，(感谢 草东先生 @ NGA)
  |cffFF2D2D--集合石(MeetingStone)下架，请Interface\AddOns里，删除MeetingStone、MeetingStoneEX文件夹 |r
16.姓名板助手(Platynator)升级到431
17.便捷小工具插件(Plumber)升级到1.9.3-b

|cff19CCF9[2026年6月26日更新内容][516-518版]：|r
1.冷却管理器(Coolinator)升级到新增
2.控制技能提示(MiniCC)升级到4.5.3
3.老农聊天条(LNuiChat)升级到20260625
4.游戏界面移动(BlizzMove)升级到3.7.37
5.技能冷却计时(MinimalistCooldownEdge)升级到4.1.2
6.全职业天赋汇总(MurlokExport)升级到20260625.004700
7.距离提示(RangeDisplay)升级到6.3.2
8.老农插件中心(!!!163UI!!!)升级到20260622
9.技能栏保存(Myslot)升级到5.25.4
10.大米路线规划(MythicDungeonTools)升级到6.1.19
11.姓名板助手(Platynator)升级到429
12.大米战利品查询(KeystoneLoot)升级到2.10.2
13.任务导航线(WaypointUI)升级到1.5.3
14.客人订单助手(DFCN_PatronOffers)升级到1.73
15.智能快捷按钮(LiteBuff)升级到20260625
16.部分插件配置优化
17.修复其他一些已知的Bug
18.彩蛋

|cff19CCF9[2026年6月22日更新内容][514、515版]：|r
1.技能冷却计时(MinimalistCooldownEdge)升级到4.1.1
2.便捷小工具插件(Plumber)升级到1.9.2-f
3.装备比较评分(Pawn)升级到2.13.12
4.全职业天赋汇总(MurlokExport)升级到20260621.005239
5.老农聊天条(LNuiChat)升级到20260621
6.智能快捷按钮(LiteBuff)升级到20260621
7.控制技能提示(MiniCC)升级到4.4.3
8.游戏界面移动(BlizzMove)升级到3.7.36
9.火焰节模块(HandyNotes_MidsummerFireFestival)新增
  |cff7F7F7F--老农插件中心-地图任务-地图标记-15-火焰节 勾选开启|r

|cff19CCF9[2026年6月20日更新内容][513版]：|r
1.装备装等观察(ItemInfoOverlay)
  |cff7F7F7F--新增 注孢：神话 装备图标和颜色显示 |r
2.右键菜单增强(EnhancedMenu)
  |cff7F7F7F--修复 副本内右键 集合石 玩家无菜单问题 |r
3.控制技能提示(MiniCC)升级到4.4.2
4.地图标记图标开关(HandyNotes_WorldMapButton)升级到120007.01
5.世界任务(WorldQuestTracker)升级到12.0.7.556
6.老农插件中心(!!!163UI!!!)升级到20260619
7.全职业天赋汇总(MurlokExport)升级到20260620.004757
8.客人订单助手(DFCN_PatronOffers)升级到1.71
9.库文件(!!!Libs)升级到20260620
10.老农工具箱(LNui)升级到20260619
11.多米诺动作条(Dominos)升级到11.3.1
12.姓名板助手(Platynator)升级到424
13.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.5.7
14.修复其他一些已知的Bug

|cff19CCF9[2026年6月18日更新内容][511、512版]：|r
1.老农工具箱(LNui)升级到20260616
2.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.5.6
3.库文件(!!!Libs)升级到20260616
4.全职业天赋汇总(MurlokExport)升级到20260618.005243
5.拍卖小助手(Auctionator)升级到327
6.背包增强插件(Baganator)升级到807
7.姓名板助手(Platynator)升级到423
8.背包物品同步(Syndicator)升级到271
9.幻化装备提示(CanIMogIt)升级到12.0.7v2.8.8
10.大米战利品查询(KeystoneLoot)升级到2.10.1
11.装备绿字百分比(MidnightRatings)升级到1.7.15
12.团长工具(MRT)升级到5315
13.大米路线规划(MythicDungeonTools)升级到6.1.18
14.装备比较评分(Pawn)升级到2.13.11
15.地图NPC标记(RoyMapGuide)升级到1.6.3
16.传送菜单(TeleportMenu)升级到12.6
17.SUF头像增强(ShadowedUnitFrames)升级到4.5.9
18.家宅装饰清单(HomeBound)升级到1.45_CN
19.坐骑收集增强(MountJournalEnhanced)升级到2.54.0
20.控制技能提示(MiniCC)升级到4.2.0
21.游戏界面移动(BlizzMove)升级到3.7.35
22.任务增强(BtWQuests)升级到2.63.0
23.集合石(MeetingStone)升级到20260618
24.战斗计时(163UI_CombatTimer)升级到20260618
25.AFK屏保(AFKS)升级到1.11.3
26.PVP战场框体(BattleGroundEnemiesFixed)升级到12.0.7
27.密语管理(WhisperPop)升级到5.27

|cff19CCF9[2026年6月15日更新内容][509、510版]：|r
1.老农工具箱(LNui)升级到20260612
  |cff7F7F7F--新增 随机框显示到期时间 功能 |r
2.饰品管理(GearBar)
  |cff7F7F7F--新增 显示装备鼠标提示 设置 |r
3.姓名板助手(Platynator)升级到422
  |cff7F7F7F--新增 老农整合包样式 ，Platynator设置-样式选择|r
4.技能冷却计时(MinimalistCooldownEdge)升级到4.1.0
5.全职业天赋汇总(MurlokExport)升级到20260613.005152
6.大米计时增强(AngryKeystones)升级到0.32.28
7.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.5.2
8.团员信息统计(AbyTeamStats)升级到20260614
9.集合石(MeetingStone)升级到20260614

|cff19CCF9[2026年6月11日更新内容][507、508版]：|r
1.控制技能提示(MiniCC)升级到3.25.0
2.PVP战场框体(BattleGroundEnemiesFixed)升级到12.0.5.13
3.一键驱散(Decursive)升级到2.8.0-RC8
4.全职业天赋汇总(MurlokExport)升级到20260611.034005
5.大米路线规划(MythicDungeonTools)升级到6.1.16
6.姓名板助手(Platynator)升级到421
7.便捷小工具插件(Plumber)升级到1.9.2-e
8.稀有精英探测(RareScanner)升级到12.0.5.8
9.SUF头像增强(ShadowedUnitFrames)升级到4.5.7
10.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.5.0
11.新增 交易记录助手(MailLogger)快跑兄弟修复版
12.大米战利品查询(KeystoneLoot)升级到2.9.1
13.技能栏保存(Myslot)升级到5.25.3

|cff19CCF9[2026年6月7日更新内容][506版]：|r
1.老农插件中心(!!!163UI!!!)升级到20260606 (感谢 GeekHugo )
  |cff7F7F7F新增 全局通用配置 功能：老农插件中心-额外设置-全账号共享插件启停 |r
2.老农聊天条(LNuiChat)升级到20260607
  |cff7F7F7F大米中限制使用属性通报 |r
3.老农工具箱(LNui)升级到20260606
4.姓名板助手(Platynator)升级到416
5.大米路线规划(MythicDungeonTools)升级到6.1.14
6.背包物品同步(Syndicator)升级到270
7.游戏界面移动(BlizzMove)升级到3.7.34
8.全职业天赋汇总(MurlokExport)升级到20260607.033628
9.大脚黑市(BFBlackMarket)升级到14
10.大脚工匠(BFCraftsman)升级到22
11.客人订单助手(DFCN_PatronOffers)升级到1.69
12.大米战利品查询(KeystoneLoot)升级到2.8.0
13.PVP战场框体(BattleGroundEnemiesFixed)升级到12.0.5.11
14.地图NPC标记(RoyMapGuide)升级到1.6.2

|cff19CCF9[2026年6月4日更新内容][505版]：|r
1.装备绿字百分比(MidnightRatings)升级到1.7.14
2.全职业天赋汇总(MurlokExport)升级到20260604.034247
3.大米路线规划(MythicDungeonTools)升级到6.1.12
4.客人订单助手(DFCN_PatronOffers)升级到1.68
5.拍卖小助手(Auctionator)升级到325
6.老农聊天条(LNuiChat)升级到20260603
7.背包增强插件(Baganator)升级到806
8.姓名板助手(Platynator)升级到414
9.背包物品同步(Syndicator)升级到269
10.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.4.9
11.多米诺动作条(Dominos)升级到11.3.0
12.团长工具(MRT)升级到5300
13.技能超距提示(tullaRange)升级到12.1.0

|cff19CCF9[2026年6月1日更新内容][504版]：|r
1.老农聊天条(LNuiChat)升级到20260601
  |cff7F7F7F1.1-属性通报改为按当前专精动态判断，并战斗中限制使用
  1.2-修复密语粘性设置失效问题
  1.3-优化历史聊天模块
  1.4-全局内存优化|r
2.任务导航线(WaypointUI)升级到1.5.2
3.全职业天赋汇总(MurlokExport)升级到20260531.033253
4.控制技能提示(MiniCC)升级到3.24.0
5.PVP战场框体(BattleGroundEnemiesFixed)升级到12.0.5.10
6.拍卖小助手(Auctionator)升级到323
7.姓名板助手(Platynator)升级到402
8.地图NPC标记(RoyMapGuide)升级到1.6.1
9.家宅装饰清单(HomeBound)升级到1.44_CN

|cff19CCF9[2026年5月29日更新内容][503版]：|r
1.老农聊天条(LNuiChat)升级到20260528
|cff7F7F7F1.1-属性通报改为：左键：属性通报到当前频道
1.2-历史聊天面板分页逻辑改为两个分区|r
2.任务导航线(WaypointUI)升级到1.5.1
3.客人订单助手(DFCN_PatronOffers)升级到1.66
4.控制技能提示(MiniCC)升级到3.23.0
5.全职业天赋汇总(MurlokExport)升级到20260528.025153
6.大米路线规划(MythicDungeonTools)升级到6.1.11
7.姓名板助手(Platynator)升级到401
8.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.4.8
9.大米战利品查询(KeystoneLoot)升级到2.7.0
10.世界任务(WorldQuestTracker)修复一处错误(感谢 Ridwin @ NGA)

|cff19CCF9[2026年5月27日更新内容][501、502版]：|r
1.客人订单助手(DFCN_PatronOffers)升级到1.65
2.大米战利品查询(KeystoneLoot)升级到2.6.0
3.全职业天赋汇总(MurlokExport)升级到20260526.025301
4.姓名板助手(Platynator)升级到399
5.鼠标提示增强(TipTac)继续尝试改善装备对比时卡顿问题
6.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.4.6
7.大米路线规划(MythicDungeonTools)升级到6.1.9
8.控制技能提示(MiniCC)升级到3.21.0
9.稀有精英探测(RareScanner)升级到12.0.5.6

|cff19CCF9[2026年5月24日更新内容][500版]：|r
1.老农聊天条(LNuiChat)升级到20260524
|cff7F7F7F1.1-新增 属性通报 功能
1.2-内存优化
1.3-屏蔽/恢复大脚世界频道：左键双击 改为 Shift+左键|r
2.客人订单助手(DFCN_PatronOffers)升级到1.63
3.一键驱散(Decursive)升级到2.8.0-RC7
4.集合石(MeetingStone)升级到20260522
5.全职业天赋汇总(MurlokExport)升级到20260524.025726
6.装备绿字百分比(MidnightRatings)升级到1.7.13
7.装备装等观察(ItemInfoOverlay)晋升虚空铸造图标显示优化
8.控制技能提示(MiniCC)升级到3.19.0
9.背包增强插件(Baganator)升级到805
10.幻化装备提示(CanIMogIt)升级到12.0.1v2.8.6
11.大米路线规划(MythicDungeonTools)升级到6.1.5
12.姓名板助手(Platynator)升级到397
13.便捷小工具插件(Plumber)升级到1.9.2-c

|cff19CCF9[2026年5月22日更新内容][499版]：|r
1.老农聊天条(LNuiChat)升级到20260522
|cff7F7F7F1.1-历史聊天模块新增 备忘录 功能|r
2.背包增强插件(Baganator)升级到804
3.客人订单助手(DFCN_PatronOffers)升级到1.62
4.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.4.5
5.按钮美化(Masque)升级到12.0.5
6.全职业天赋汇总(MurlokExport)升级到20260521.032532
7.大米路线规划(MythicDungeonTools)升级到6.1.4
8.姓名板助手(Platynator)升级到396
9.稀有精英探测(RareScanner)升级到12.0.5.5
10.背包物品同步(Syndicator)升级到268
11.密语管理(WhisperPop)升级到5.26
12.装备装等观察(ItemInfoOverlay)自行新增 晋升虚空铸造 图标
13.装备绿字百分比(MidnightRatings)升级到1.7.12
14.库文件(!!!Libs)升级到20260522

|cff19CCF9[2026年5月19日更新内容][498版]：|r
1.老农聊天条(LNuiChat)升级到20260519
|cff7F7F7F1.1-修复现代亮黑风格指示标偶尔不消失问题
1.2-修复大米中被私密触发的秘密值问题|r
2.姓名板助手(Platynator)升级到393
3.大米路线规划(MythicDungeonTools)升级到6.1.3
4.全职业天赋汇总(MurlokExport)升级到20260518.032643
5.技能冷却计时(MinimalistCooldownEdge)升级到4.0.7
5.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.4.2
7.一键驱散(Decursive)升级到2.8.0-RC6
8.客人订单助手(DFCN_PatronOffers)升级到1.60

|cff19CCF9[2026年5月18日更新内容][497版]：|r
1.老农插件中心(!!!163UI!!!)升级到20260518
2.大米战利品查询(KeystoneLoot)升级到2.5.1
3.便捷小工具插件(Plumber)升级到1.9.2-b
4.姓名板助手(Platynator)升级到390
5.技能冷却计时(MinimalistCooldownEdge)升级到4.0.6
6.装备绿字百分比(MidnightRatings)升级到1.7.11
7.装备装等观察(ItemInfoOverlay)升级到2.4.7
8.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.4.1
9.全职业天赋汇总(MurlokExport)升级到20260517.024949
10.鼠标提示增强(TipTac)自行尝试改善装备对比时卡顿问题
11.老农聊天条(LNuiChat)升级到20260518
|cff7F7F7F11-1.新增聊天日志受限场景消息延迟恢复功能
11-2.新增免ALT键查看输入记录功能
11-3.优化暴雪默认风格鼠标悬停高亮显示效果
11-4.新增现代亮黑风格(推荐）|r

|cff19CCF9[2026年5月15日更新内容][496版]：|r
1.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.4.0
2.装备绿字百分比(MidnightRatings)升级到1.7.10
3.技能冷却计时(MinimalistCooldownEdge)升级到4.0.5
4.全职业天赋汇总(MurlokExport)升级到20260514.025150
（内存占用非常高，不用时候建议关闭）
5.密语管理(WhisperPop)升级到5.23
6.老农聊天条(LNuiChat)升级到20260515
7.团长工具(MRT)升级到5295
8.拍卖小助手(Auctionator)升级到322
9.装备比较评分(Pawn)升级到2.13.10
10.姓名板助手(Platynator)升级到388

|cff19CCF9[2026年5月14日更新内容][495版]：|r
1.密语管理(WhisperPop)升级到5.22
2.装备绿字百分比(MidnightRatings)升级到1.7.9
3.全职业天赋汇总(MurlokExport)升级到20260513.024952
4.便捷小工具插件(Plumber)升级到1.9.2
5.姓名板助手(Platynator)升级到387
6.传送菜单(TeleportMenu)升级到12.4-2
7.客人订单助手(DFCN_PatronOffers)升级到1.59
8.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.3.7
9.大米战利品查询(KeystoneLoot)升级到2.5.0
10.SUF头像增强(ShadowedUnitFrames)升级到4.5.6
11.老农工具箱(LNui)升级到20260511
12.稀有精英探测(RareScanner)升级到12.0.5.3
13.控制技能提示(MiniCC)升级到3.18.0
14.老农聊天条(LNuiChat)升级到20260513
15.老农插件中心(!!!163UI!!!)升级到20260513
16.家宅装饰清单(HomeBound)升级到1.43_CN
17.饰品管理(GearBar)改为暴雪风格，中间空挡处左键按住移动

|cff19CCF9[2026年5月9日更新内容][494版]：|r
1.控制技能提示(MiniCC)升级到3.17.1
2.大米计时增强(AngryKeystones)升级到0.32.27
3.地图标记(HandyNotes)各模块升级到144
4.装备装等观察(ItemInfoOverlay)升级到2.4.6
5.技能冷却计时(MinimalistCooldownEdge)升级到4.0.1
6.全职业天赋汇总(MurlokExport)升级到20260508.024319
7.姓名板助手(Platynator)升级到377
8.便捷小工具插件(Plumber)升级到1.9.1-f
9.稀有精英探测(RareScanner)升级到12.0.5.2
10.智能快捷按钮(LiteBuff)升级到20260506
11.老农聊天条(LNuiChat)升级到20260508
12.大米战利品查询(KeystoneLoot)升级到2.4.3
13.老农工具箱(LNui)升级到20260508
14.老农插件中心(!!!163UI!!!)升级到20260508

|cff19CCF9[2026年5月6日更新内容][493版]：|r
1.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.3.6
2.全职业天赋汇总(MurlokExport)升级到20260505.023148
3.姓名板助手(Platynator)升级到376
4.鼠标提示增强(TipTac)升级到26.5.3-cn
5.控制技能提示(MiniCC)升级到3.16.0
6.便捷小工具插件(Plumber)升级到1.9.1-e
7.PVP战场框体(BattleGroundEnemiesFixed)升级到12.0.5.9
8.大米战利品查询(KeystoneLoot)升级到2.4.2
9.大米路线规划(MythicDungeonTools)升级到6.1.2
10.错误信息收集(!BaudErrorFrame)升级到20260505

|cff19CCF9[2026年5月3日更新内容][491、2版]：|r
1.控制技能提示(MiniCC)升级到3.15.2
2.PVP战场框体(BattleGroundEnemiesFixed)升级到12.0.5.8
3.Cell团队框架(Cell)升级到275.10-skye
4.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.3.5
5.大米战利品查询(KeystoneLoot)升级到2.4.1
6.技能冷却计时(MinimalistCooldownEdge)升级到3.9.8
7.全职业天赋汇总(MurlokExport)升级到20260503.024011
8.老农工具箱(LNui)升级到20260502
9.背包增强插件(Baganator)升级到802
10.姓名板助手(Platynator)升级到375
11.老农插件中心(!!!163UI!!!)升级到20260503
12.集合石(MeetingStone)升级到20260503

|cff19CCF9[2026年5月1日更新内容][490版]：|r
1.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.3.4
2.大米战利品查询(KeystoneLoot)升级到2.4.0
3.全职业天赋汇总(MurlokExport)升级到20260501.024843
4.老农工具箱(LNui)升级到20260501
5.客人订单助手(DFCN_PatronOffers)升级到1.57
6.游戏界面移动(BlizzMove)升级到3.7.33
7.大米路线规划(MythicDungeonTools)升级到6.1.1
8.便捷小工具插件(Plumber)升级到1.9.1-d
9.角色进度查询(SavedInstances)升级到12.0.5
10.老农聊天条(LNuiChat)升级到20260501

|cffFF1A1A----------------没有更多内容了----------------|r
]])
