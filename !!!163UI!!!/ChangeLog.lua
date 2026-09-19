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

U1ChangeLogFrame.ContentText:SetText([[|cff19CCF9[2026年9月19日更新内容][576版]：|r
1.老农聊天条(LNuiChat)升级到20260918
  |cff959697-- 新增当前频道金色边框提示：当处于某个聊天频道时，该频道显示金色边框，用于标识当前所在频道；
  -- 自动切换频道：当处于“说”“喊”等普通频道时，进入队伍或团队后，自动切换到对应的队伍或团队频道；当处于队伍或团队频道时，离开队伍或团队后，自动切换回“说”“喊”等普通频道；
  -- 当处于大脚世界频道、公会频道、综合频道等频道时，进入或离开队伍/团队，均不更改当前频道；
  -- Tab键切换频道去除密语频道。|r
2.毕业装备查询(GearInsight)升级到0.91.3
3.世界任务增强，WorldQuestTab替换WorldQuestTracker
  |cff959697-- WorldQuestTracker会引起任务追踪进度条不更新问题，所以下架；
  -- 世界任务列表，点击大地图界面外最下面的图标；
  -- Interface\AddOns里，如有 WorldQuestTracker 文件夹，请删除。|r
4.库文件(!!!Libs)升级到20260918
5.拍卖小助手(Auctionator)升级到337
6.背包增强插件(Baganator)升级到826
7.冷却管理器(Coolinator)升级到147
8.装备装等观察(ItemInfoOverlay)升级到2.4.20
9.姓名板助手(Platynator)升级到488
10.属性递减提示(StatDiminishing)升级到1.6
11.背包物品同步(Syndicator)升级到281

|cff19CCF9[2026年9月17日更新内容][575版]：|r
1.毕业装备查询(GearInsight)升级到0.90.4
2.Cell团队框架(Cell)升级到302_MiliUI
3.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.9.7
4.地图标记(HandyNotes)各模块升级到156
5.坐骑收集日志(MCL)升级到3.13.4
6.稀有精英探测(RareScanner)升级到12.1.0.10
7.PVP战场框体(BattleGroundEnemiesFixed)升级到12.1.0.4
8.冷却管理器(Coolinator)升级到143
9.大米战利品查询(KeystoneLoot)升级到2.17.0
10.集合石(MeetingStone)升级到20260916
11.背包增强插件(Baganator)升级到824

|cff19CCF9[2026年9月15日更新内容][574版]：|r
1.毕业装备查询(GearInsight)升级到0.90.1
2.属性递减提示，StatDiminishing替换TrueStatValues（感谢 黑龙呀 @ QQ群）
  |cff959697-- Interface\AddOns 里，如有 TrueStatValues 文件夹，请删除。|r
3.拍卖小助手(Auctionator)升级到336
4.Cell团队框架(Cell)升级到299_MiliUI
5.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.9.6
6.装备装等观察(ItemInfoOverlay)升级到2.4.19
7.姓名板助手(Platynator)升级到485
8.智能快捷按钮(LiteBuff)升级到20260914

|cff19CCF9[2026年9月14日更新内容][573版]：|r
1.Cell团队框架(Cell)“隐藏暴雪小队”，也能隐藏SUF头像增强的小队了
2.毕业装备查询(GearInsight)升级到0.81.4
3.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.9.5
4.客人订单助手(DFCN_PatronOffers)升级到1.90
5.自动交接任务(AutoTurnIn)升级到20260913
6.集合石(MeetingStone)尝试减少内存占用
7.背包物品同步(Syndicator)升级到279
8.装备比较评分(Pawn)升级到2.13.16
9.老农工具箱(LNui)升级到20260913
10.老农插件中心(!!!163UI!!!)升级到20260913
11.智能快捷按钮(LiteBuff)升级到20260913
12.库文件(!!!Libs)升级到20260913
13.任务导航线(WaypointUI)升级到1.7.1
14.目标姓名板标记(TargetNameplateIndicator)升级到1.67

|cff19CCF9[2026年9月12日更新内容][571、572版]：|r
1.老农聊天条(LNuiChat)升级到20260912
  |cff959697-- 新增“Ctrl + 鼠标右键” 按住拖动，可改变按钮顺序
  -- “重置聊天条位置”升级为“初始化聊天条”|r
2.背包增强插件(Baganator)升级到823
3.毕业装备查询(GearInsight)升级到0.80.10
4.大米战利品查询(KeystoneLoot)升级到2.16.1
5.智能快捷按钮(LiteBuff)升级到20260912
6.坐骑收集日志(MCL)升级到3.13.3
7.背包物品同步(Syndicator)升级到278
8.集合石(MeetingStone)升级到20260912

|cff19CCF9[2026年9月11日更新内容][570版]：|r
1.老农聊天条(LNuiChat)升级到20260911
  |cff959697-- 修复Tab键切换频道卡住问题
  -- 修复Tab键识别战网密语或角色密语频道问题|r
2.毕业装备查询(GearInsight)升级到0.80.2
3.装备装等观察(ItemInfoOverlay)升级到2.4.18
4.团长工具(MRT)升级到5330
5.修复一些已知的Bug

|cff19CCF9[2026年9月10日更新内容][569版]：|r
1.老农聊天条(LNuiChat)升级到20260908
2.世界飞行地图(WorldFlightMap)升级到20260910
3.毕业装备查询(GearInsight)升级到0.78.1
4.大米战利品查询(KeystoneLoot)升级到2.16.0
5.稀有精英探测(RareScanner)升级到12.1.0.9
6.冷却管理器(Coolinator)升级到142
7.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.9.3
8.大米路线规划(MythicDungeonTools)升级到6.2.16
9.便捷小工具插件(Plumber)升级到1.9.5-b
10.幻化装备提示(CanIMogIt)升级到12.1.0v2.8.13-alpha1
11.任务导航线(WaypointUI)升级到1.7.0
12.智能快捷按钮(LiteBuff)升级到20260909
13.Cell团队框架(Cell)升级到298_MiliUI

|cff19CCF9[2026年9月7日更新内容][568版]：|r
1.团员信息统计(AbyTeamStats)升级到20260907
2.智能快捷按钮(LiteBuff)升级到20260907
3.集合石(MeetingStone)升级到20260906
  |cff959697-- 上述更新维护，感谢 黑龙呀 @ QQ群|r
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
  |cff959697-- MountsJournal已下架。请手动前往 Interface\AddOns 目录，删除 MountsJournal和MountsJournalUI 文件夹，以避免插件冲突。|r

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

|cffFF1A1A----------------没有更多内容了----------------|r
]])