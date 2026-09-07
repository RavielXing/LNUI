U1ChangeLogFrame.TitleText:SetText("|cff19CCF9老|cffffb300农|cffD56AFF整|cffFF2AA5合|cff3cff00包|r |CFFFFFFFF-|r |cffFFD100更新记录|r");
-- 新增图片代码 --
-- local logo = U1ChangeLogFrame:CreateTexture(nil, "ARTWORK")
-- logo:SetTexture("Interface\\AddOns\\!!!163UI!!!\\Textures\\aitocar.blp")
-- logo:SetSize(220, 220)
-- logo:SetPoint("LEFT", U1ChangeLogFrame.TitleText, "RIGHT", 50, -125)

-- ▼▼▼ 窗口拖动 + 鼠标穿透 ▼▼▼
if not U1ChangeLogFrame._lnuiFixed then
    U1ChangeLogFrame._lnuiFixed = true

    -- 拦截鼠标事件，防止穿透到背后的插件控制台（解决tooltip乱飘和误点关闭）
    U1ChangeLogFrame:EnableMouse(true)

    -- 按住标题栏拖动窗口
    U1ChangeLogFrame:SetMovable(true)
    U1ChangeLogFrame:RegisterForDrag("LeftButton")
    U1ChangeLogFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    U1ChangeLogFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end
-- ▲▲▲ 修复结束 ▲▲▲

-- 获取滚动内容容器（由 163UIUI.lua 创建）
local display = U1ChangeLogFrameDisplay

if display then
    -- 在滚动目标内部创建居中的 HeaderText
    if not display.HeaderText then
        display.HeaderText = display:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        display.HeaderText:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE")
        display.HeaderText:SetPoint("TOPLEFT", display, "TOPLEFT", 0, 0)
        display.HeaderText:SetPoint("TOPRIGHT", display, "TOPRIGHT", -30, 0)
        display.HeaderText:SetJustifyH("CENTER")
    end
    display.HeaderText:SetText("|cffFFD100★衷心感谢 KeiraMetz @ NGA 鼎力帮助，修复众多插件问题★|r\n|cff959697--日常交流、建议反馈请加QQ粉丝群：36070228--|r")
end

U1ChangeLogFrame.ContentText:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE");

-- 将 ContentText 移到 HeaderText 下方，保持左对齐
if display and display.HeaderText then
    U1ChangeLogFrame.ContentText:ClearAllPoints()
    U1ChangeLogFrame.ContentText:SetPoint("TOPLEFT", display.HeaderText, "BOTTOMLEFT", 0, -8)
    U1ChangeLogFrame.ContentText:SetPoint("TOPRIGHT", display.HeaderText, "BOTTOMRIGHT", 0, -8)
    U1ChangeLogFrame.ContentText:SetJustifyH("LEFT")

    -- 重写 SetText，确保滚动目标高度 = HeaderText 高度 + 间距 + ContentText 高度
    local ContentText = U1ChangeLogFrame.ContentText
    local _OriginalSetText = ContentText.SetText
    function ContentText:SetText(text)
        _OriginalSetText(ContentText, text)
        local headerH = display.HeaderText:GetHeight()
        local contentH = ContentText:GetHeight()
        display:SetHeight(headerH + 8 + contentH)
    end
end

U1ChangeLogFrame.ContentText:SetText([[|cff19CCF9[2026年9月7日更新内容][568版]：|r
1.团员信息统计(AbyTeamStats)升级到20260906
2.智能快捷按钮(LiteBuff)升级到20260906
3.集合石(MeetingStone)升级到20260906
  |cff959697--上述更新维护，感谢 黑龙呀 @ QQ群|r
4.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.9.2
5.自动交接任务(AutoTurnIn)升级到12.0.3
6.大米战利品查询(KeystoneLoot)升级到2.15.1
7.大米路线规划(MythicDungeonTools)升级到6.2.15
8.求装备助手(PersonalLootHelper)升级到2.47
9.姓名板助手(Platynator)升级到484
10.错误提示增强(!BaudErrorFrame)升级到20260906
11.根据票选结果：毕业装备查询(GearInsight，0.76.8版) 替换 全职业天赋汇总(MurlokExport)
  |cff959697-- Interface\AddOns 里，如有 MurlokExport 文件夹，请删除。|r
12.PVP战场框体(BattleGroundEnemiesFixed)升级到12.1.0.3
13.地图标记(HandyNotes)各模块升级到155
14.一键驱散(Decursive)回归
15.冷却管理器(Coolinator)升级到141
16.库文件(!!!Libs)升级到20260907
17.家宅装饰清单(HomeBound)升级到1.56_CN

|cff19CCF9[2026年9月5日更新内容][567版]：|r
|cFFFFFF00为确保“老农整合包”的正常使用，请不要采用以下人员的配置分享：小趴菜买买、小鱼人买买、引子猪、战神黑旋风、唷哈哈吧、丰富之人、搞毛、花生没仁、yoyozmy、Even、木木、夏目玲子、小法哥哥、阿白。同时，敬告上述人员停止继续传播基于老农整合包的配置修改内容。感谢您的理解与支持。|r

1.鼠标提示增强(TipTac)升级到26.09.03
2.库文件(!!!Libs)升级到20260904
3.冷却管理器(Coolinator)升级到140
4.全职业天赋汇总(MurlokExport)升级到20260905.025119
5.便捷小工具插件(Plumber)升级到1.9.5
6.稀有精英探测(RareScanner)升级到12.1.0.8
7.角色进度查询(SavedInstances)升级到12.1.0
8.大米路线规划(MythicDungeonTools)升级到6.2.13
9.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.8.9
10.姓名板助手(Platynator)升级到482
11.装备装等观察(ItemInfoOverlay)升级到2.4.17-1
12.宠物战队(Rematch) （感谢 yongjiao888 @ NGA）
13.坐骑收集增强(MountJournalEnhanced)回归
  |cff959697--MountsJournal已下架。请手动前往 Interface\AddOns 目录，删除 MountsJournal和MountsJournalUI 文件夹，以避免插件冲突。|r

|cff19CCF9[2026年9月4日更新内容][565、566版]：|r
1.法术警报上计时(SpellAlertTimer)升级到20260901
2.姓名板助手(Platynator)升级到481
3.大米路线规划(MythicDungeonTools)升级到6.2.12
4.技能冷却计时(MinimalistCooldownEdge)升级到4.6.4
5.坐骑收集日志(MCL)升级到3.13.2
6.装备装等观察(ItemInfoOverlay)升级到2.4.16-6
7.宠物战队(Rematch)升级到20260902
8.客人订单助手(DFCN_PatronOffers)升级到1.89
9.冷却管理器(Coolinator)升级到138
10.大米战利品查询(KeystoneLoot)升级到2.15.0
11.坐骑界面增强(MountsJournal)升级到12.1.6
12.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.8.7
13.库文件(!!!Libs)升级到20260903
14.全职业天赋汇总(MurlokExport)升级到20260903.025036
15.属性溢出提示(TrueStatValues)升级到1.5.7

|cff19CCF9[2026年9月1日更新内容][563、564版]：|r
1.姓名板助手(Platynator)升级到479
2.鼠标提示增强(TipTac)升级到26.08.29
3.老农工具箱(LNui)升级到20260829
4.智能快捷按钮(LiteBuff)升级到20260829
5.自动交接任务(AutoTurnIn)升级到12.0.0
6.大米战利品查询(KeystoneLoot)升级到2.14.0
7.冷却管理器(Coolinator)升级到137
8.错误提示增强(!BaudErrorFrame)升级到20260830
9.Cell团队框架(Cell)升级到297_MiliUI
10.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.8.4
11.目标姓名板标记(TargetNameplateIndicator)升级到1.65
12.老农插件中心(!!!163UI!!!)升级到20260830
13.客人订单助手(DFCN_PatronOffers)升级到1.88

|cff19CCF9[2026年8月29日更新内容][561、562版]：|r
1.库文件(!!!Libs)升级到20260827
2.大米计时增强(AngryKeystones)升级到0.33.0
3.游戏界面移动(BlizzMove)升级到3.7.43
4.冷却管理器(Coolinator)升级到136
5.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.8.3
6.装备装等观察(ItemInfoOverlay)升级到2.4.15
7.大米战利品查询(KeystoneLoot)升级到2.13.1
8.坐骑收集日志(MCL)升级到3.13.1
9.坐骑界面增强(MountsJournal)升级到12.1.5
10.姓名板助手(Platynator)升级到476
11.密语管理(WhisperPop)升级到5.28
12.集合石(MeetingStone)升级到20260827
13.距离提示(RangeDisplay)升级到6.3.5
14.稀有精英探测(RareScanner)升级到12.1.0.7
15.Cell团队框架(Cell)升级到296.2-beta_MiliUI
16.老农插件中心(!!!163UI!!!)升级到20260828
  |cff959697--粉丝榜界面新增查找功能|r
17.AFK屏保(AFKS)
  |cff959697--屏幕右上角始终显示"X"退出按钮|r
18.全职业天赋汇总(MurlokExport)S2赛季数据不更新，临时下架
19.SUF头像增强(ShadowedUnitFrames)升级到4.6.7
20.鼠标提示增强(TipTac)升级到26.08.28
21.角色进度查询(SavedInstances)新增S2新周常、货币
  |cff959697--感谢 保修肯德基 @ NGA|r

|cff19CCF9[2026年8月26日更新内容][558-560版]：|r
1.拍卖小助手(Auctionator)升级到335
2.背包增强插件(Baganator)升级到822
3.大米战利品查询(KeystoneLoot)升级到2.13.0
4.按钮美化(Masque)升级到12.1.0
5.大米路线规划(MythicDungeonTools)升级到6.2.9
6.便捷小工具插件(Plumber)升级到1.9.4-c
7.背包物品同步(Syndicator)升级到277
8.老农工具箱(LNui)升级到20260825
9.坐骑收集日志(MCL)升级到3.11.1
10.技能冷却计时(MinimalistCooldownEdge)升级到4.6.3
11.CD就绪(CooldownDone)升级到2.0.0
12.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.7.9
13.姓名板助手(Platynator)升级到472

|cff19CCF9[2026年8月25日更新内容][557版]：|r
1.老农聊天条(LNuiChat)升级到20260824
  |cff959697--加入/离开 大脚世界频道 现在能立即生效了|r
2.装备装等观察(ItemInfoOverlay)升级到2.4.14
3.技能栏保存(Myslot)升级到3.11.0
4.稀有精英探测(RareScanner)升级到12.1.0.5
5.冷却管理器(Coolinator)升级到134
6.大米路线规划(MythicDungeonTools)升级到6.2.6
7.智能快捷按钮(LiteBuff)升级到20260824
8.老农工具箱(LNui)升级到20260824
9.技能冷却计时(MinimalistCooldownEdge)升级到4.6.2
10.大米路线规划(MythicDungeonTools)升级到6.2.7
11.稀有精英探测(RareScanner)升级到12.1.0.6
12.坐骑界面增强(MountsJournal)新增
13.Cell团队框架(Cell)升级到295_MiliUI
14.幻化装备提示(CanIMogIt)升级到12.1.0v2.8.11
15.任务增强(BtWQuests)升级到2.63.2
16.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.7.8
17.姓名板助手(Platynator)升级到471
18.SUF头像增强(ShadowedUnitFrames)升级到4.6.6
19.进一步优化和修复已知问题（感谢 黑龙呀 @ QQ群）

|cff19CCF9[2026年8月22日更新内容][555、556版]：|r
1.传送菜单(TeleportMenu)升级到12.8
2.坐骑收集日志(MCL)升级到3.11.0
3.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.7.7
4.Cell团队框架(Cell)升级到293_MiliUI
5.老农插件中心(!!!163UI!!!)升级到20260822
6.老农工具箱(LNui)升级到20260822
7.技能冷却计时(MinimalistCooldownEdge)升级到4.5.9
8.冷却管理器(Coolinator)升级到131
9.大米计时增强(AngryKeystones)升级到131
10.大米路线规划(MythicDungeonTools)升级到6.2.5
11.姓名板助手(Platynator)升级到468
12.团长工具(MRT)升级到5325
13.进一步优化和修复已知问题

|cff19CCF9[2026年8月21日更新内容][553、554版]：|r
1.背包增强插件(Baganator)升级到821-1
2.PVP战场框体(BattleGroundEnemiesFixed)升级到12.1.0.2
3.冷却管理器(Coolinator)升级到129
4.地图标记(HandyNotes)各模块升级到154
5.装备装等观察(ItemInfoOverlay)升级到2.4.11
6.装备升級提示(ItemUpgradeTip)升级到4.3.1
7.大米战利品查询(KeystoneLoot)升级到2.12.1
8.技能冷却计时(MinimalistCooldownEdge)升级到4.5.4
9.团长工具(MRT)升级到5320
10.大米路线规划(MythicDungeonTools)升级到6.2.4
11.姓名板助手(Platynator)升级到467-1
12.稀有精英探测(RareScanner)升级到12.1.0.4
13.法术警报上计时(SpellAlertTimer)升级到20260819
14.SUF头像增强(ShadowedUnitFrames)升级到4.6.5
15.任务导航线(WaypointUI)升级到1.6.0-b
16.Cell团队框架(Cell)升级到292_MiliUI
17.库文件(!!!Libs)升级到20260820
18.团员信息统计(AbyTeamStats)升级到20260820 （感谢 电视卫士 @ NGA）
19.集合石(MeetingStone)升级到20260819
20.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.7.4
21.家宅装饰清单(HomeBound)升级到1.55_CN
22.装备装等观察(ItemInfoOverlay)升级到2.4.12-1
23.宠物战队(Rematch)升级到20260820
24.鼠标提示增强(TipTac)升级到26.08.15
25.大脚黑市(BFBlackMarket)升级到16
26.修复一些已知的Bug

|cff19CCF9[2026年8月18日更新内容][551、552版]：|r
1.地图NPC标记(RoyMapGuide)升级到1.7.1
2.地图标记(HandyNotes)各模块升级到152
3.技能冷却计时(MinimalistCooldownEdge)升级到4.5.0
4.法术警报上计时(SpellAlertTimer)升级到20260817.1
5.一键换装(GearManagerEx)升级到20260817
6.Cell团队框架(Cell)升级到291_MiliUI
7.大米战利品查询(KeystoneLoot)升级到2.12.0
8.大米路线规划(MythicDungeonTools)升级到6.2.3
9.装备比较评分(Pawn)升级到2.13.15
10.宠物战队(Rematch)升级到20260817
11.世界任务(WorldQuestTracker)升级到12.1.0.560
12.装备装等观察(ItemInfoOverlay)升级到2.4.10-2

|cff19CCF9[2026年8月17日更新内容][550版]：|r
1.老农聊天条(LNuiChat)升级到20260817
2.Cell团队框架(Cell)升级到290_MiliUI
3.坐骑收集日志(MCL)升级到3.10.3
4.技能冷却计时(MinimalistCooldownEdge)升级到4.4.5
5.宠物战队(Rematch)升级到20260816
6.法术警报上计时(SpellAlertTimer)升级到20260817
7.传送菜单(TeleportMenu)升级到12.7-2
8.SUF头像增强(ShadowedUnitFrames)升级到4.6.3

|cff19CCF9[2026年8月17日更新内容][549版]：|r
1.SUF头像增强(ShadowedUnitFrames)升级到4.6.2
2.PVP战场框体(BattleGroundEnemiesFixed)升级到12.1.1
3.任务增强(Dragonflight、TheWarWithin)模块升级
4.Cell团队框架(Cell)升级到289_MiliUI
5.技能冷却计时(MinimalistCooldownEdge)升级到4.4.0
6.地图NPC标记(RoyMapGuide)升级到1.7
7.家宅装饰清单(HomeBound)升级到1.52_CN
8.法术警报上计时(SpellAlertTimer)升级到20260816
9.地图标记(HandyNotes)各模块升级到151
10.宠物战队(Rematch)回归
11.老农插件中心(!!!163UI!!!)升级到20260816
12.任务导航线(WaypointUI)升级到1.6.0
13.稀有精英探测(RareScanner)升级到12.1.0.3
14.坐骑收集日志(MCL)升级到3.10.2
15.便捷小工具插件(Plumber)升级到1.9.4-b
  |cff3cff00--注意：受12.1版本光环系统大幅调整影响，使用 ShadowedUnitFrames 和 Cell 的玩家，需手动清理旧版配置。具体操作为：在 WTF 文件夹中检索 cell 与 ShadowedUnitFrames 关键字，将匹配到的所有文件全部删除，重启游戏后即可正常。|r

|cff19CCF9[2026年8月15日更新内容][545-548版]：|r
1.坐骑收集日志(MCL)新增
2.法术警报上计时(SpellAlertTimer)新增
3.Cell团队框架(Cell)回归
4.装备装等观察(ItemInfoOverlay)升级到2.4.10
5.大米战利品查询(KeystoneLoot)升级到2.11.2
6.技能冷却计时(MinimalistCooldownEdge)升级到4.3.7
7.姓名板助手(Platynator)升级到464
8.稀有精英探测(RareScanner)升级到12.1.0.2
9.聊天过滤器(WindChatFilter)升级到1.8.0
10.世界飞行地图(WorldFlightMap)升级到20260815
11.错误提示增强(!BaudErrorFrame)升级到20260815
12.客人订单助手(DFCN_PatronOffers)升级到1.87
13.游戏界面移动(BlizzMove)升级到3.7.42
14.幻化装备提示(CanIMogIt)升级到v2.8.11-alpha2
15.修复一些已知的Bug

|cffFF1A1A----------------没有更多内容了----------------|r
]])