local addonName, ns = ...
local L = ns.L

-- ========================================================================================================================
-- 【1】标准地图标记添加格式
-- ========================================================================================================================

-- [地图ID] = {
--     group = "自定义城市英文名称",
--     faction = "阵营区域",
--     subZoneScale = "城市子区域ID缩放补偿数值",
--     1.普通标记 >>>>> 自定义标记，标记顺序：portal/inn/official/profession/service/stable/collection/vendor/unique/special/quartermaster/pvp
--     2.poi标记 >>>>> 捕获暴雪自带标记（大部分传送门类、区域小城堡、活动标记等）
--     3.maplink标记 >>>>> 捕获暴雪自带标记（上下洞口通道类，注意：具体是poi还是maplink需要测试，有可能图标一致但类型不同）
--     4.副本标记 >>>>> 捕获暴雪自带副本入口
--     5.地下堡标记 >>>>> 捕获暴雪自带地下堡入口
-- },

-- ========================================================================================================================
-- 【2】标准标记字段和顺序
-- ========================================================================================================================

-- 完整字段 = { coord, template, color, icon, text, textA, offsetY, title, info, type, tags, isAggregate/isIndividual }
-- 最少字段 = { coord, icon/text }

-- 字段含义：
-- coord = 坐标 >>>>> 8位坐标值
-- template = 自定义标记模板 >>>>> 有模板优先使用模板，模板内字段均可被覆盖
-- color = 颜色分类
-- icon = 图标 >>>>> 使用图标ID
-- text = 文本 >>>>> 显示在地图上的文本（如果是专业名称，则名称顺序优先制造业＞采集业，其次按照专业英文名称顺序从A到Z）
-- textA = 锚点左右偏移 >>>>> 只用于偏移文本text字段，icon不受影响
-- offsetY = 标记上下偏移 >>>>> 用于微调标记上下位置，同时影响text和icon
-- title = 鼠标指向提示内容标题
-- info = 鼠标指向提示内容正文 >>>>> 标签变色：[n]NPC身份职能[/n] [i]特殊物品[/i] [c]货币[/c]
-- type = 专业分类（独立专业/混合专业） >>>>> 专业分类使用专业独立名称
-- tags = 混合标记分类（非混合专业） >>>>> 按配置顺序先后，专业tags不使用专业独立名称而使用profession
-- isAggregate/isIndividual = 聚合标记/独立标记

-- ========================================================================================================================
-- 【3】动态捕获通用poi/maplink/副本/地下堡标记的标准格式
-- ========================================================================================================================

-- poiNames = {
--     ["实际poi标记显示的名称"] = { color = "颜色分类", text = "自定义名称" },
-- },

-- maplinkNames = {
--     ["实际maplink标记显示的名称"] = { text = "自定义名称" },
-- },

-- instanceNames = {
--     ["实际副本显示的名称"] = { text = "自定义名称" },
-- },

-- delveNames = {
--     ["实际地下堡显示的名称"] = { text = "自定义名称" },
-- },

-- ========================================================================
-- 【标记模板】
-- ========================================================================
RoyMapGuide_MAP_DATA_TEMPLATES = {
    portal = { color = "portal", icon = 135860, text = "传送" },
    portal_stormwind = { color = "portal", icon = 135860, text = "暴风", title = "暴风城传送门" },
    portal_orgrimmar = { color = "portal", icon = 132096, text = "奥格", title = "奥格瑞玛传送门" },
    inn = { color = "inn", icon = 134414, text = "旅店", title = "旅店" },
    auction = { color = "official", icon = 133784, text = "拍卖", title = "拍卖行" },
    bank = { color = "official", icon = 413587, text = "银行", title = "银行" },
    blackmarket = { color = "official", icon = 626190, text = "黑市", title = "黑市首领", info = "郭雅夫人" },
    -- 专业
    profession_mixed = { color = "profession", icon = 1392955, text = "专业区", title = "专业训练师" },
    alchemy = { color = "profession", icon = 4620669, text = "炼金", title = "炼金术训练师", type = "Alchemy" },
    archaeology = { color = "profession", icon = 441139, text = "考古", title = "考古学训练师", type = "Archaeology" },
    blacksmithing = { color = "profession", icon = 4620670, text = "锻造", title = "锻造训练师", type = "Blacksmithing" },
    cooking = { color = "profession", icon = 4620671, text = "烹饪", title = "烹饪训练师", type = "Cooking" },
    enchanting = { color = "profession", icon = 4620672, text = "附魔", title = "附魔训练师", type = "Enchanting" },
    engineering = { color = "profession", icon = 4620673, text = "工程", title = "工程学训练师", type = "Engineering" },
    fishing = { color = "profession", icon = 4620674, text = "钓鱼", title = "钓鱼训练师", type = "Fishing" },
    herbalism = { color = "profession", icon = 4620675, text = "草药", title = "草药学训练师", type = "Herbalism" },
    inscription = { color = "profession", icon = 4620676, text = "铭文", title = "铭文训练师", type = "Inscription" },
    jewelcrafting = { color = "profession", icon = 4620677, text = "珠宝", title = "珠宝加工训练师", type = "Jewelcrafting" },
    leatherworking = { color = "profession", icon = 4620678, text = "制皮", title = "制皮训练师", type = "Leatherworking" },
    mining = { color = "profession", icon = 4620679, text = "采矿", title = "采矿训练师", type = "Mining" },
    skinning = { color = "profession", icon = 4620680, text = "剥皮", title = "剥皮训练师", type = "Skinning" },
    tailoring = { color = "profession", icon = 4620681, text = "裁缝", title = "裁缝训练师", type = "Tailoring" },
    -- 其他
    barber = { color = "service", icon = 133801, text = "理发", title = "理发店" },
    transmog = { color = "service", icon = 132288, text = "幻化", title = "幻化师" },
    tradingpost = { color = "service", icon = 4696085, text = "商栈", title = "商栈" },
    upgrade = { color = "service", icon = 1455684, text = "升级", title = "物品升级" },
    order = { color = "service", icon = 1103069, text = "订单", title = "制造订单" },
    delve = { color = "service", icon = 1064187, text = "地下堡", title = "地下堡行者总部" },
    stable = { color = "stable", icon = 1769016, text = "兽栏", title = "兽栏" },
    mount = { color = "collection", icon = 136103, text = "坐骑", title = "坐骑商人" },
    pet = { color = "collection", icon = 618972, text = "宠物", title = "宠物商人" },
    toy = { color = "collection", icon = 134144, text = "玩具", title = "玩具商人" },
    housing = { color = "collection", icon = 7252953, text = "家宅", title = "家宅商人" },
    guild = { color = "vendor", icon = 514261, text = "公会", title = "公会" },
    look = { color = "vendor", icon = 135030, text = "外观", title = "外观商人" },
    heirloom = { color = "vendor", icon = 135360, text = "传家宝", title = "传家宝商人" },
    unique_vendor = { color = "unique", icon = 133639, text = "商人", title = "特殊商人" },
    portaltrainer = { color = "special", icon = 237556, text = "传送", title = "传送门训练师" },
    cinematic = { color = "special", icon = 1109100, text = "动画", title = "动画短片" },
    randomraid = { color = "special", icon = 397907, text = "随机本", title = "随机本" },
    catalyst = { color = "special", icon = 2000852, text = "化生台", title = "化生台" },
    transformation = { color = "special", icon = 4640486, text = "幻形", title = "幻形讲坛" },
    quartermaster = { color = "quartermaster", icon = 413584 },
    pvp_vendor = { color = "pvp", icon = 236612, text = "PVP", title = "PVP商人" },
    dummy = { color = "pvp", icon = 458724, text = "木桩", title = "木桩" },
}

-- ========================================================================
-- 【标记数据库】
-- ========================================================================
RoyMapGuide_MAP_DATA = {
    --------------------------------------------------------------------------------
    -- 暴风城
    --------------------------------------------------------------------------------
    [84] = {
        group = "Stormwind",
        faction = "Alliance",
        { coord = 48790858, template = "portal", title = "同盟种族传送门", info = "[n]光铸德莱尼[/n]\n光铸道标\n\n[n]机械侏儒[/n]\n麦卡贡市传送器\n\n[n]黑铁矮人[/n]\n暗炉城钻探机\n\n[n]虚空精灵[/n]\n泰洛古斯裂隙\n\n[n]土灵[/n]\n土灵传送器\n\n[a]作者描述：通过光铸道标传送到维迪卡尔可以看到整个艾泽拉斯星球，放心往前不会从飞船上掉下去[/a]" },
        { coord = 74461834, template = "portal", title = "大地的裂变版本传送门", info = "海加尔山传送门\n暮光高地传送门\n瓦斯琪尔传送门\n奥丹姆传送门\n深岩之洲传送门\n托尔巴拉德传送门" },
        { coord = 82692959, template = "portal", text = "◆月光林地", textA = "RIGHT", title = "月光林地", info = "赛纳里奥使者安亚·碧月：和NPC对话传送到[i]月光林地[/i]" },
        { coord = 23875612, template = "portal", text = "◆达纳苏斯", textA = "RIGHT", title = "达纳苏斯传送门" },
        { coord = 66883441, template = "portal", text = "◆地铁/搏击", textA = "RIGHT", title = "矿道地铁/搏击俱乐部", info = "乘坐矿道地铁可通往铁炉堡" },
        { coord = 60397527, template = "inn", info = "奥里森" },
        { coord = 75685411, template = "inn", info = "梅根·提尔曼" },
        { coord = 64933194, template = "inn", text = "◆旅店", textA = "RIGHT", info = "塔格娜·耕石" },
        { coord = 49891572, template = "inn", info = "莎妮·护界" },
        { coord = 61167080, template = "auction" },
        { coord = 60113221, template = "auction" },
        { coord = 63037883, template = "bank" },
        { coord = 64802853, template = "bank" },
        -- 专业
        { coord = 55668608, template = "alchemy", info = "莉琳希亚·夜风" },
        { coord = 85822595, template = "archaeology", info = "哈里森·琼斯" },
        { coord = 63673700, template = "blacksmithing", info = "瑟鲁姆·深炉" },
        { coord = 77285321, template = "cooking", info = "斯蒂芬·雷百克" },
        { coord = 50651721, template = "cooking", info = "达利娅·穹花" },
        { coord = 52947442, template = "enchanting", info = "鲁坎·考迪尔" },
        { coord = 51211267, template = "enchanting", info = "艾丽斯塔·黎明之尘" },
        { coord = 62853197, template = "engineering", info = "利廉姆·火轴" },
        { coord = 54796959, template = "fishing", info = "阿诺德·利兰" },
        { coord = 40846586, template = "herbalism", info = "莎拉米尔" },
        { coord = 54308411, template = "herbalism", info = "塔尼莎" },
        { coord = 49837482, template = "inscription", info = "卡塔莉娜·斯坦弗" },
        { coord = 63486184, template = "jewelcrafting", info = "特蕾莎·登曼" },
        { coord = 71916264, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n西蒙·坦纳尔\n\n[n]剥皮训练师[/n]\n马瑞斯·格兰治", type = {"Leatherworking", "Skinning"} },
        { coord = 59513777, template = "mining", info = "吉尔曼·石手" },
        { coord = 53088135, template = "tailoring", info = "乔吉奥·波利罗" },
        { coord = 52011952, template = "tailoring", info = "艾维多斯" },
        { coord = 49101237, template = "profession_mixed", text = "锻造/工程/采矿◆", textA = "LEFT", title = "专业训练师", info = "[n]锻造训练师[/n]\n伊莱娅\n\n[n]工程学训练师[/n]\n技师法鲁德\n\n[n]采矿训练师[/n]\n德鲁本·粗臂", type = {"Blacksmithing", "Engineering", "Mining"} },
        -- 其他
        { coord = 61516461, template = "barber", info = "耶利尼克·沙希尔" },
        { coord = 50766074, template = "transmog", info = "织幻者哈沙姆\n\n[n]遗忘传说供应商[/n]\n搜寻者纳杰德：出售丢失的[i]老版本橙装[/i]" },
        { coord = 51037195, template = "tradingpost", info = "陶妮和怀尔德商栈\n\n宠物幻化" },
        { coord = 42546050, template = "stable", text = "制皮/兽栏◆", textA = "LEFT", title = "制皮训练师/兽栏", info = "[n]制皮训练师[/n]\n泰龙尼斯\n\n[n]兽栏管理员[/n]\n塞丽斯塔", tags = {"profession", "stable"} },
        { coord = 67263767, template = "stable", info = "耶诺瓦·石盾" },
        { coord = 53271283, template = "stable", text = "◆兽栏", textA = "RIGHT", info = "阿什利·黯叶" },
        { coord = 76926801, template = "mount", text = "◆坐骑", textA = "RIGHT", info = "凯蒂·斯托克斯：出售人类种族坐骑[i]战马[/i]" },
        { coord = 73005952, template = "mount", text = "◆坐骑/商人", textA = "RIGHT", title = "摩托商人/幸运商人", info = "[n]摩托商人[/n]\n保利：出售坐骑[i]勇士的践踏之刃[/i]\n\n[n]幸运商人[/n]\n“巧手”雷尼·麦考伊：出售玩具[i]波贝的炫彩酱汁[/i]和幸运相关的道具\n\n[a]作者描述：背包内常年放满幸运道具，相信玄学[/a]", tags = {"collection", "vendor" } },
        { coord = 76136540, template = "mount", title = "战争坐骑军需官", info = "通灵领主赛普[c]（邪气鞍座）[/c]\n\n卡特尔中尉[c]（荣耀印记）[/c]" },
        { coord = 69482515, template = "pet", title = "战斗宠物训练师", info = "奥黛丽·伯恩赫普" },
        { coord = 58905274, template = "pet", info = "蔚蔚：完成任务可以获得宠物[i]联盟气球[/i]" },
        { coord = 38096439, template = "toy", info = "安多哈尔的索拉尔：对NPC使用/疲倦，可以获得玩具[i]旅行者的篝火[/i]" },
        { coord = 61332268, template = "toy", info = "阿丽尔·闪拍：完成任务可获得玩具[i]自拍神器[/i]" },
        { coord = 56087712, template = "housing", info = "“第二把交椅”袍铎" },
        { coord = 48546877, template = "housing", info = "图乌兰：出售1款家宅装饰[i]微型黑暗之门复制品[/i]" },
        { coord = 49278011, template = "housing", info = "索莉罗：出售2款书本类家宅装饰" },
        { coord = 77826577, template = "housing", text = "◆家宅", textA = "RIGHT", title = "战场装饰专家", info = "莉伊卡：出售多款战场类家宅装饰，有成就限制[c]（荣誉点数/荣耀印记）[/c]" },
        { coord = 64157702, template = "guild", info = "[n]公会商人[/n]\n塞伊·普雷斯勒\n\n[n]公会注册员[/n]\n奥德文·拉弗林\n\n[n]战袍商人[/n]\n瑞贝卡·拉弗林" },
        { coord = 56251731, color = "special", icon = 134156, text = "克罗米", title = "克罗米", info = "切换时间线" },
        { coord = 87673608, color = "special", icon = 894556, text = "◆经验锁定", textA = "RIGHT", title = "经验锁定", info = "贝斯滕" },
        { coord = 75300926, template = "cinematic", info = "克罗米：可观看巨龙之魂副本中[i]击败死亡之翼的动画[/i]" },
        { coord = 49488569, color = "special", icon = 1455894, text = "战役", title = "场景战役", info = "档案员托马斯：可体验8.0前夕剧情[i]洛丹伦之战[/i]" },
        { coord = 67747303, template = "quartermaster", text = "暴风城", title = "暴风城军需官", info = "骑士队长兰希·莱薇森：出售[i]暴风城战袍[/i]/多款暴风城风格家宅装饰" },
        { coord = 67831704, template = "quartermaster", text = "土水派", title = "土水派军需官/龙龟饲养员", info = "[n]土水派军需官[/n]\n门徒韩俊：出售[i]土水派熊猫人战袍[/i]\n\n[n]龙龟饲养员[/n]\n老白鼻：出售熊猫人种族坐骑[i]龙龟[/i]\n\n[n]特殊道具[/n]\n熊猫萌萌：对NPC使用[i]/love[/i]可以获得道具[i]魔力竹笋[/i]，使用后可变身同款熊猫，支持施法" },
        { coord = 74756773, template = "pvp_vendor", info = "1层\n\n[n]杂货军需官[/n]\n军士长贝金斯：出售PVP宝石和2款战袍\n\n[n]旧世界护甲军需官[/n]\n克莱特军士长\n\n[n]旧世界武器军需官[/n]\n加克斯宾中尉\n\n[n]嗜血角斗士[/n]\n埃德兰·哈尔辛（第9赛季）\n\n[n]残忍角斗士[/n]\n崔丝提亚中尉（第9赛季）\n\n[n]冷酷角斗士[/n]\n骑士队长蒂麦尔·塞缇丝（第10赛季）\n\n[n]灾变角斗士[/n]\n迪格汉默上尉（第11赛季）\n\n[n]荣誉传家宝[/n]\n莉莉安娜·恩贝弗斯特\n\n[n]腐化候选者商人[/n]\n爱丽丝·费雪（8.0第4赛季）\n\n[n]荣誉奖励军需官[/n]\n骑士队长杰西卡：出售3款宠物\n\n2层\n\n[n]勇气军需官[/n]\n费尔德伦·提尔斯戴尔\n\n[n]正义军需官[/n]\n玛嘉莎·斯利文托\n\n[n]传承正义军需官[/n]\n托伦·兰道" },
        { coord = 78976232, template = "dummy" },
        poiNames = {
            ["前往无畏要塞（北风苔原）的船"] = { color = "portal", text = "北风苔原",  },
            ["前往伯拉勒斯港（提拉加德海峡）的船"] = { color = "portal", text = "伯拉勒斯" },
            ["前往觉醒海岸（巨龙群岛）的船"] = { color = "portal", text = "觉醒海岸" },
            ["暴风城传送大厅"] = { color = "portal", text = "传送大厅" },
        },
        instanceNames = {
            ["监狱"] = { text = "监狱" },
        },
    },

    -- 暴风城：矿道地铁
    [499] = {
        group = "Stormwind",
        faction = "Alliance",
        { coord = 52324805, color = "portal", icon = 132334, text = "搏击俱乐部", title = "搏击俱乐部", info = "矿道地铁下方入口" },
    },

    -- 暴风城：搏击俱乐部
    [500] = {
        group = "Stormwind",
        faction = "Alliance",
        { coord = 54202521, template = "quartermaster", text = "搏击", title = "搏击俱乐部军需官", info = "奎肯布什：出售2款坐骑/2款宠物/1款战袍/多款衬衣和套装外观/1款传家宝/3款家宅装饰\n装备[i]拳手的重击指环[/i]：可传送到搏击俱乐部" },
    },

    --------------------------------------------------------------------------------
    -- 铁炉堡
    --------------------------------------------------------------------------------
    [87] = {
        group = "Ironforge",
        faction = "Alliance",
        { coord = 76435115, template = "portal", text = "地铁", title = "矿道地铁", info = "乘坐矿道地铁可通往暴风城" },
        { coord = 18125142, template = "inn", info = "洛雷·火酒" },
        { coord = 24817379, template = "auction" },
        { coord = 34986131, template = "bank" },
        -- 专业
        { coord = 66615565, template = "alchemy", info = "塔雷·浆泡" },
        { coord = 75591113, template = "archaeology", info = "学者教授铁裤" },
        { coord = 52494200, template = "blacksmithing", info = "本古斯·深炉" },
        { coord = 60083644, template = "cooking", info = "达瑞尔·瑞克努索" },
        { coord = 68454353, template = "engineering", info = "宾斯匹德" },
        { coord = 48120760, template = "fishing", info = "格瑞诺尔·石印" },
        { coord = 55905914, template = "herbalism", info = "雷纳·石枝" },
        { coord = 50782640, template = "jewelcrafting", text = "◆珠宝/采矿", textA = "RIGHT", title = "专业训练师", info = "[n]珠宝加工训练师[/n]\n哈尼尔·坚石\n\n[n]采矿训练师[/n]\n吉尔弗拉姆·石趾", type = {"Jewelcrafting", "Mining"} },
        { coord = 40033307, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n费布·钢轴\n\n[n]剥皮训练师[/n]\n巴尔萨斯·裂石", type = {"Leatherworking", "Skinning"} },
        { coord = 43142937, template = "tailoring", info = "约莫德·石眉" },
        { coord = 60124535, template = "profession_mixed", text = "◆附魔/铭文", textA = "RIGHT", title = "专业训练师", info = "[n]附魔训练师[/n]\n吉布·草须\n\n[n]铭文训练师[/n]\n艾莉丝·布莱里特", type = {"Enchanting", "Inscription"} },
        -- 其他
        { coord = 25954934, template = "barber", info = "贝拉·布拉鲁斯" },
        { coord = 69308361, template = "stable", info = "乌布雷克·火拳" },
        { coord = 76140809, template = "housing", info = "因葛·明视：出售2款书柜类家宅装饰" },
        { coord = 24814391, template = "housing", info = "戴德里克·塑淞：出售多款矮人风格家宅装饰" },
        { coord = 36288582, template = "guild", info = "[n]公会商人[/n]\n斯蒂格·赫斯克尔勒\n\n[n]公会注册员[/n]\n乔多·钢眉\n\n[n]战袍商人[/n]\n利莎·钢眉" },
        { coord = 74470984, template = "heirloom", text = "传家宝◆", textA = "LEFT", info = "克罗姆·粗臂：出售传家宝/传家宝升级道具/多款地图类玩具[i]侦查地图[/i]" },
        { coord = 25500707, template = "portaltrainer", info = "贝尔斯塔弗·风暴之眼" },
        { coord = 54834749, template = "quartermaster", text = "诺莫瑞根/铁炉堡◆", textA = "LEFT", title = "声望军需官", info = "[n]诺莫瑞根军需官[/n]\n工匠大师崔尼：出售[i]诺莫瑞根战袍[/i]\n\n[n]铁炉堡军需官[/n]\n石盔上尉：出售[i]铁炉堡战袍[/i]/铁炉堡风格家宅装饰" },
        { coord = 58846964, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 达纳苏斯
    --------------------------------------------------------------------------------
    [89] = {
        group = "Darnassus",
        faction = "Alliance",
        { coord = 44067849, template = "portal", title = "传送门/传送门训练师", info = "地狱火半岛传送门\n埃索达传送门\n\n[n]传送门训练师[/n]\n埃莉萨·杜马斯", tags = {"portal", "special"} },
        { coord = 37095050, template = "portal", text = "鲁瑟兰村", title = "鲁瑟兰村传送门", info = "走进粉色区域自动传送" },
        { coord = 48421499, template = "inn", info = "格温·阿姆斯特" },
        { coord = 62533278, template = "inn", info = "塞琳尼" },
        { coord = 54875837, template = "auction" },
        { coord = 43615100, template = "bank" },
        -- 专业
        { coord = 53913853, template = "alchemy", info = "安尼希尔" },
        { coord = 42638333, template = "archaeology", info = "隐世者汉蒙" },
        { coord = 57005270, template = "blacksmithing", info = "罗尔夫·卡尔尼尔" },
        { coord = 49883663, template = "cooking", info = "阿雷贡" },
        { coord = 49623237, template = "engineering", text = "◆工程/采矿", textA = "RIGHT", title = "专业训练师", info = "[n]工程学训练师（上层）[/n]\n塔娜·伦特危尔\n\n[n]采矿训练师（下层）[/n]\n工头佩尔尼奇", type = {"Engineering", "Mining"} },
        { coord = 49126098, template = "fishing", info = "阿斯坦娅" },
        { coord = 49146880, template = "herbalism", info = "菲罗迪恩·唤月" },
        { coord = 53983111, template = "jewelcrafting", info = "艾莎·银露" },
        { coord = 56423101, template = "profession_mixed", text = "◆附魔/铭文", textA = "RIGHT", title = "专业训练师", info = "[n]附魔训练师（下层）[/n]\n塔兰丹\n\n[n]铭文训练师（上层）[/n]\n芬迪·达金", type = {"Enchanting", "Inscription"} },
        { coord = 60493683, template = "profession_mixed", text = "◆裁缝/制皮/剥皮", textA = "RIGHT", title = "专业训练师", info = "[n]裁缝训练师（下层）[/n]\n迈里恩\n\n[n]制皮训练师（上层）[/n]\n泰龙尼斯\n\n[n]剥皮训练师（上层）[/n]\n艾拉迪尔", type = {"Tailoring", "Leatherworking", "Skinning"} },
        -- 其他
        { coord = 43172893, template = "stable", info = "阿拉辛" },
        { coord = 64055357, template = "pet", info = "夏琳奈尔：出售2款宠物[i]猫头鹰[/i]" },
        { coord = 42493260, template = "mount", info = "莱兰奈：出售暗夜精灵种族坐骑[i]猎豹[/i]" },
        { coord = 48142179, template = "mount", info = "阿斯特丽德·长袜：出售2款坐骑[i]高山马[/i]" },
        { coord = 64583811, template = "guild", info = "[n]公会商人[/n]\n瓦莉亚·月弓\n\n[n]公会注册员[/n]\n琳沙娜\n\n[n]战袍商人[/n]\n沙鲁蒙\n\n[n]战袍设计师[/n]\n艾拉希亚" },
        { coord = 36164847, template = "quartermaster", text = "达纳苏斯◆", textA = "LEFT", title = "达纳苏斯军需官", info = "月之女祭司娜萨拉：出售[i]达纳苏斯战袍[/i]" },
        { coord = 37134743, template = "quartermaster", text = "◆吉尔尼斯", textA = "RIGHT", title = "吉尔尼斯军需官", info = "坎德雷勋爵：出售[i]吉尔尼斯战袍[/i]/吉尔尼斯风格家宅装饰" },
        { coord = 60485344, template = "dummy" },
        { coord = 60484603, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 埃索达
    --------------------------------------------------------------------------------
    [103] = {
        group = "Exodar",
        faction = "Alliance",
        { coord = 48356292, template = "portal_stormwind" },
        { coord = 59511877, template = "inn", info = "布雷尔" },
        { coord = 63255869, template = "auction" },
        { coord = 45434389, template = "bank" },
        -- 专业
        { coord = 27466284, template = "alchemy", text = "炼金/草药◆", textA = "LEFT", title = "专业训练师", info = "[n]炼金术训练师[/n]\n鲁克\n\n[n]草药学训练师[/n]\n塞摩尔汉", type = {"Alchemy", "Herbalism"} },
        { coord = 33646637, template = "archaeology", info = "蒂亚" },
        { coord = 59708777, template = "blacksmithing", text = "◆锻造/采矿", textA = "RIGHT", title = "专业训练师", info = "[n]锻造训练师[/n]\n米阿尔\n\n[n]采矿训练师[/n]\n穆亚特", type = {"Blacksmithing", "Mining"} },
        { coord = 55742671, template = "cooking", info = "穆曼" },
        { coord = 54169285, template = "engineering", info = "奥克基尔" },
        { coord = 31951467, template = "fishing", info = "伊雷特" },
        { coord = 44882423, template = "jewelcrafting", info = "法里" },
        { coord = 65667458, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "专业训练师", info = "[n]制皮训练师[/n]\n阿克汉姆\n\n[n]剥皮训练师[/n]\n雷米勒", type = {"Leatherworking", "Skinning"} },
        { coord = 64426900, template = "tailoring", info = "雷菲克" },
        { coord = 40183924, template = "profession_mixed", text = "附魔/铭文◆", textA = "LEFT", title = "专业训练师", info = "[n]附魔训练师[/n]\n纳霍加\n\n[n]铭文训练师[/n]\n索斯", type = {"Enchanting", "Inscription"} },
        -- 其他
        { coord = 60192521, template = "stable", info = "阿尔泰德" },
        { coord = 30073377, template = "pet", info = "希克斯：出售3款宠物[i]蛾子[/i]" },
        { coord = 53776844, template = "guild", info = "[n]公会商人[/n]\n露妮\n\n[n]公会注册员[/n]\n弗纳姆\n\n[n]战袍商人[/n]\n伊斯卡" },
        { coord = 45996269, template = "portaltrainer", text = "传送◆", textA = "LEFT", info = "鲁纳尔兰" },
        { coord = 54963722, template = "quartermaster", text = "埃索达", title = "埃索达军需官", info = "卡杜：出售[i]埃索达战袍[/i]" },
        { coord = 23783255, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 吉尔尼斯
    --------------------------------------------------------------------------------
    [218] = {
        group = "Gilneas",
        faction = "Alliance",
        { coord = 39006111, template = "inn", info = "格温·阿姆斯特" },
        { coord = 59423774, template = "bank" },
        { coord = 58352756, template = "profession_mixed", text = "专业", title = "全专业技能训练师", info = "杰克·“万金油”·德林顿" },
        { coord = 35977079, template = "stable", info = "费尼甘·考布勒" },
        { coord = 41903770, color = "special", icon = 463876, text = "管家", title = "格雷迈恩管家", info = "和NPC对话后可以使城内所有NPC消失一天" },
        { coord = 33356573, template = "quartermaster", text = "吉尔尼斯◆", textA = "LEFT", title = "吉尔尼斯军需官", info = "坎德雷勋爵：出售[i]吉尔尼斯战袍[/i]/吉尔尼斯风格家宅装饰" },
    },

    --------------------------------------------------------------------------------
    -- 暴风之盾
    --------------------------------------------------------------------------------
    [622] = {
        group = "Stormshield",
        faction = "Alliance",
        { coord = 60783792, template = "portal_stormwind" },
        { coord = 36384114, template = "portal", text = "雄狮岗哨◆", textA = "LEFT", title = "雄狮岗哨传送门", info = "通往塔纳安丛林的雄狮岗哨，需要完成任务线才可看到" },
        { coord = 35707789, template = "inn", info = "加西亚·悦花" },
        { coord = 54056634, template = "auction" },
        { coord = 54684868, template = "bank" },
        -- 专业
        { coord = 37396922, template = "alchemy", text = "炼金/草药◆", textA = "LEFT", title = "专业训练师", info = "[n]炼金术训练师[/n]\n贾登·塔斯克\n\n[n]草药学训练师[/n]\n洁·野花", type = {"Alchemy", "Herbalism"} },
        { coord = 49023319, template = "archaeology", title = "考古学训练师/考古商人", info = "[n]考古学训练师[/n]\n曼达·达洛维\n\n[n]考古商人[/n]\n格拉吉斯[c]（修复的遗物）[/c]", tags = {"profession", "vendor"} },
        { coord = 49264640, template = "blacksmithing", info = "艾米·金炉" },
        { coord = 35117616, template = "cooking", info = "埃尔顿·布莱克（旅店老板背后右转向下）" },
        { coord = 56656538, template = "enchanting", info = "比尔·星酒" },
        { coord = 48164047, template = "engineering", info = "希尔达·铜丝" },
        { coord = 55477849, template = "fishing", info = "奥斯汀·温德米尔" },
        { coord = 63163368, template = "inscription", title = "铭文训练师（上层）", info = "铭文师芝源" },
        { coord = 43483390, template = "jewelcrafting", info = "技师妮希亚" },
        { coord = 52394273, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "专业训练师", info = "[n]制皮训练师[/n]\n吉斯顿·锐羽\n\n[n]剥皮训练师[/n]\n游侠兰顿", type = {"Leatherworking", "Skinning"} },
        { coord = 47294364, template = "mining", info = "乔纳斯·链拳" },
        { coord = 51513709, template = "tailoring", info = "约书亚·福斯汀" },
        -- 其他
        { coord = 63113543, template = "transmog", text = "幻化◆", textA = "LEFT", title = "幻化师（下层）", info = "织幻者沙尔" },
        { coord = 33356486, template = "stable", info = "奥维尔·曼弗雷德" },
        { coord = 29645292, template = "unique_vendor", text = "图纸", title = "要塞图纸商人", info = "金凯德·加科布" },
        { coord = 48506225, template = "unique_vendor", text = "水晶", title = "埃匹希斯水晶商人", info = "共有6位，出售坐骑[i]苔皮淡水兽[/i]/要塞追随者合约[i]寻晨者鲁卡里斯[/i]" },
        { coord = 52026358, template = "unique_vendor", text = "挑战", title = "黄金挑战商人（绝版）", info = "挑战者萨维娜\n\n[a]作者描述：武器外观和特效都非常漂亮[/a]" },
        { coord = 63933575, template = "portaltrainer", text = "◆传送", textA = "RIGHT", title = "传送门训练师（上层）", info = "朱莉亚·瓦吉斯" },
        { coord = 51846136, color = "special", icon = 838813, text = "R币", title = "R币兑换", info = "大法师兰达洛克：出售[i]钢化命运印记[/i]" },
        { coord = 42917786, template = "quartermaster", text = "热砂", title = "热砂军需官", info = "加兹瑞克斯·轮锁：出售以下商品\n\n坐骑[i]驯养的刀脊野猪[/i]\n宠物[i]白色淡水兽幼崽[/i]/[i]被捕获的森林幼苗[/i]" },
        { coord = 46607674, template = "quartermaster", text = "主教", title = "主教议会军需官", info = "守备官努瑞姆：出售以下商品\n\n坐骑[i]土色岩皮雷象[/i]\n玩具[i]永久时光气泡[/i]\n宠物[i]德莱尼微型防御者[/i]\n8款家宅装饰[c]（要塞物资）[/c]" },
        { coord = 44537494, template = "quartermaster", text = "鸦人", title = "鸦人流亡者军需官", info = "暗影贤者巴考斯：出售以下商品\n\n坐骑[i]暗鬃冲锋者[/i]\n宠物[i]塞泰之子[/i]\n3款家宅装饰[c]（埃匹希斯水晶）[/c]" },
        { coord = 54771688, template = "quartermaster", text = "乌瑞恩", title = "乌瑞恩先锋军军需官", info = "魔导师朗格莱：出售[i]乌瑞恩先锋军战袍[/i]/坐骑[i]暗鬃冲锋者[/i][c]（荣耀印记）[/c]" },
        { coord = 54501872, template = "pvp_vendor", info = "[n]原祖争斗者[/n]\n布莱格·铜铸\n\n[n]原祖角斗士[/n]\n英格丽德·黑锭\n\n[n]好战争斗者[/n]\n“开碑掌”曾丽\n\n[n]好战角斗士[/n]\n霍莉·麦提拉\n\n[n]狂野争斗者[/n]\n斯勒格·旋箭\n\n[n]狂野角斗士[/n]\n阿米莉亚·克拉克" },
        { coord = 60731523, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 伯拉勒斯
    --------------------------------------------------------------------------------
    [1161] = {
        group = "Boralus",
        faction = "Alliance",
        { coord = 70581713, template = "portal", title = "传送门/传送门训练师", info = "暴风城传送门\n埃索达传送门\n铁炉堡传送门\n希利苏斯传送门：需要[i]切回当前时间线[/i]\n纳沙塔尔传送门：需要[i]完成相关任务[/i]\n\n[n]传送门训练师[/n]\n伊薇娅·维弗邦德" },
        { coord = 67952669, template = "portal", text = "◆赞达拉", textA = "RIGHT", title = "赞达拉", info = "杰塔瑞斯将军：和NPC对话传送到[i]沃顿/纳兹米尔/祖达萨[/i]" },
        { coord = 74111265, template = "inn", text = "功能区", title = "旅店/幻化/R币/随机本", tags = {"inn", "service", "special", "instance"}, isAggregate = true },
        { coord = 74111265, template = "inn", text = "旅店/随机本◆", textA = "LEFT", title = "旅店/随机本", info = "[n]旅店老板[/n]\n维斯雷·洛克霍德\n\n[n]随机本[/n]\n基库：奥迪尔/达萨罗之战/风暴熔炉/永恒王宫/尼奥罗萨，觉醒之城", tags = {"inn", "special"}, isIndividual = true },
        { coord = 75871756, template = "bank" },
        -- 专业
        { coord = 73450849, template = "profession_mixed", title = "专业训练师", isAggregate = true },
        { coord = 74210654, template = "alchemy", text = "◆炼金", textA = "RIGHT", info = "艾尔里克·沃尔格林", isIndividual = true },
        { coord = 68330848, template = "archaeology", info = "简·哈德森", isIndividual = true },
        { coord = 71211067, template = "cooking", info = "“船长”拜伦·梅尔萨克", isIndividual = true },
        { coord = 74031155, template = "enchanting", info = "艾米莉·法维瑟", isIndividual = true },
        { coord = 74160558, template = "fishing", info = "阿伦·高尔", isIndividual = true },
        { coord = 70310609, template = "herbalism", info = "德克兰·塞纳尔", isIndividual = true },
        { coord = 73340634, template = "inscription", text = "铭文", info = "佐伊·墨轮", isIndividual = true },
        { coord = 75210990, template = "jewelcrafting", info = "萨缪尔·D·科尔顿三世", isIndividual = true },
        { coord = 75481261, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "专业训练师", info = "[n]制皮训练师[/n]\n卡桑德拉·布莱诺\n\n[n]剥皮训练师[/n]\n卡米拉·达克斯凯", isIndividual = true },
        { coord = 75220757, template = "mining", info = "米拉·卡波特", isIndividual = true },
        { coord = 76941116, template = "tailoring", text = "◆裁缝/外观", textA = "RIGHT", title = "裁缝训练师/外观", info = "[n]裁缝训练师[/n]\n丹尼尔·布莱维\n\n[n]衬衣商人[/n]\n马文·希普斯柯：出售16款[i]衬衣外观[/i]", tags = {"profession", "vendor"}, isIndividual = true },
        -- 其他
        { coord = 64602818, template = "barber", info = "特里·罗克菲尔德" },
        { coord = 71581369, template = "transmog", text = "◆幻化/R币", textA = "RIGHT", title = "幻化师/R币兑换", info = "[n]幻化师[/n]\n织幻者艾基尔\n\n[n]命运大师[/n]\n特兹兰：可用金币/职业大厅资源/荣耀印记兑换[i]战痕命运印记[/i]", tags = {"service", "special"}, isIndividual = true },
        { coord = 69601316, template = "stable", info = "莱拉·斯塔福德" },
        { coord = 56774707, template = "mount", text = "◆坐骑/家宅", textA = "RIGHT", title = "坐骑商人/家宅商人", info = "[n]坐骑商人[/n]\n狡猾的尼克：出售坐骑[i]灰皮恐角龙[/i]/宠物[i]失落的栉龙[/i]\n\n[n]家宅商人[/n]\n詹妮·福雷斯特：出售5款家宅装饰[c]（战争物资）[/c]" },
        { coord = 50934593, template = "pet", title = "战斗宠物训练师", info = "达纳·普尔" },
        { coord = 70731566, template = "housing", text = "◆家宅", textA = "RIGHT", info = "培尔·巴洛：出售8款伯拉勒斯风格家宅装饰" },
        { coord = 70201476, template = "guild", info = "[n]公会商人[/n]\n派瑞·查尔顿\n\n[n]公会注册员[/n]\n码头侍卫菲恩森" },
        { coord = 66902577, template = "unique_vendor", text = "勋章", title = "服役勋章", info = "供应商烈炉：出售以下商品[c]（第七军团服役勋章）[/c]\n\n3款坐骑/1款宠物/1款玩具/5款传家宝/2款披风外观\n装备[i]船长的指挥玺戒[/i]：可传送到伯拉勒斯\n道具[i]十地饮剂[/i]：可提升10%经验（等级不高于49级）" },
        { coord = 66053231, template = "unique_vendor", text = "海岛", title = "海岛商人", info = "[n]达布隆币商人[/n]\n克拉丽莎船长：出售2款坐骑/2款宠物/3款玩具/3款帽子外观[c]（海员达布隆币）[/c]\n\n[n]“打捞”专家[/n]\n夜奔船长：出售3款[i]打捞品[/i][c]（海员达布隆币）[/c]" },
        { coord = 54337261, color = "unique", icon = 1044996, text = "佩佩", title = "潜水头盔佩佩", info = "凯瑟琳的猫之家，进门左边鱼缸里拾取[i]微型潜水盔[/i]" },
        { coord = 77181647, color = "special", icon = 2437249, text = "拆解", title = "自动拆解机1000型" },
        { coord = 67522154, template = "quartermaster", text = "海军部", title = "普罗德摩尔海军部军需官", info = "供给官芙蕾：出售2款坐骑/2款玩具/5款家宅装饰" },
        { coord = 68972470, template = "quartermaster", text = "◆第七军团", textA = "RIGHT", title = "第七军团军需官", info = "守备官嘉兰娜" },
        { coord = 56352603, template = "pvp_vendor", title = "PVP商人/旅店", info = "[n]副指挥官[/n]\n加布里埃尔元帅：[i]旅店[/i]，并且出售以下商品\n\n装备[i]艾泽拉斯之心[/i]强化PVP道具[c]（荣誉点数）[/c]\n\n8.0版本4个赛季PVP装备和武器外观套装[c]（荣耀印记）[/c]\n\n[n]角斗士军需官[/n]\n弗雷泽元帅\n\n[n]专业联络人[/n]\n利丹·古斯塔夫：PVP图纸配方[c]（荣耀印记）[/c]", tags = {"inn", "pvp"} },
        poiNames = {
            ["前往暴风城的船"] = { color = "portal", text = "暴风" },
        },
        instanceNames = {
            ["达萨罗之战"] = { text = "达萨罗之战" },
            ["围攻伯拉勒斯"] = { text = "围攻" },
        },
    },

    --------------------------------------------------------------------------------
    -- 贝拉梅斯
    --------------------------------------------------------------------------------
    [2239] = {
        group = "Belamath",
        faction = "Alliance",
        { coord = 55326473, template = "portal", title = "传送门", info = "[n]房间外[/n]\n暴风城传送门\n\n[n]房间内[/n]\n黑海岸传送门\n海加尔山传送门\n瓦尔莎拉传送门" },
        { coord = 48295403, template = "inn", text = "功能区", title = "旅店/专业训练师/兽栏/家宅", tags = {"inn", "profession", "stable", "vendor"}, isAggregate = true },
        { coord = 48135331, template = "inn", text = "旅店/烹饪/家宅◆", textA = "LEFT", title = "旅店/烹饪训练师/家宅商人", info = "[n]旅店老板[/n]\n塞琳尼\n\n[n]烹饪训练师[/n]\n阿雷贡\n\n[n]家宅商人[/n]\n艾兰蒂斯：出售7款家宅装饰[c]（巨龙群岛补给）[/c]", tags = {"inn", "profession", "vendor"}, isIndividual = true },
        -- 专业
        { coord = 54646014, template = "profession_mixed", text = "◆专业区", textA = "RIGHT", isAggregate = true }, 
        { coord = 47895674, template = "profession_mixed", isAggregate = true },
        { coord = 54905941, template = "alchemy", text = "◆炼金/草药", textA = "RIGHT", title = "专业训练师", info = "[n]炼金术训练师[/n]\n泰兰希尔\n\n[n]草药学训练师[/n]\n艾什教授", type = {"Alchemy", "Herbalism"}, isIndividual = true },
        { coord = 48545422, template = "enchanting", text = "◆附魔", textA = "RIGHT", info = "附魔师法尔林·树影", isIndividual = true },
        { coord = 52885592, template = "engineering", info = "渡鸦工匠塔里尔" },
        { coord = 48196402, template = "fishing", info = "垂钓者阿斯坦娅" },
        { coord = 54736190, template = "inscription", info = "芬迪·达金", isIndividual = true },
        { coord = 54616047, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "专业训练师", info = "[n]制皮训练师[/n]\n达丽亚娜\n\n[n]剥皮训练师[/n]\n耶蕾娜·夜空", isIndividual = true },
        { coord = 48825796, template = "tailoring", info = "埃德尔鲁·夏叶", isIndividual = true },
        { coord = 47895674, template = "profession_mixed", text = "锻造/珠宝/采矿◆", textA = "LEFT", title = "专业训练师", info = "[n]锻造训练师[/n]\n塞兰妮亚\n\n[n]珠宝加工训练师[/n]\n艾莎·银露\n\n[n]采矿训练师[/n]\n帕莉亚蕾", type = {"Blacksmithing", "Jewelcrafting", "Mining"}, isIndividual = true },
        -- 其他
        { coord = 48005436, template = "stable", text = "兽栏◆", textA = "LEFT", info = "阿拉辛", isIndividual = true },
        { coord = 51426602, template = "mount", info = "莱兰奈：出售暗夜精灵种族坐骑[i]猎豹[/i]" },
        { coord = 54096082, template = "housing", text = "家宅◆", textA = "LEFT", info = "迈斯林迪尔：出售2款家宅装饰[c]（巨龙群岛补给）[/c]" },
        { coord = 50165924, template = "cinematic", info = "女祭司瑟尔德雷：可观看3段动画\n\n[i]贝拉梅斯的建立\n伊瑟拉的离别\n玛法里奥的归来[/i]" },
        { coord = 46507063, template = "quartermaster", text = "达纳苏斯◆", textA = "LEFT", title = "达纳苏斯军需官", info = "月之女祭司娜萨拉：出售2款达纳苏斯战袍/1款披风外观/1款肩部外观/1款家宅装饰[c]（巨龙群岛补给）[/c]" },
        poiNames = {
            ["前往风谷村（吉尔尼斯）的船"] = { color = "portal", text = "吉尔尼斯" },
        },
    },

    --------------------------------------------------------------------------------
    -- 奥格瑞玛
    --------------------------------------------------------------------------------
    [85] = {
        group = "Orgrimmar",
        faction = "Horde",
        { coord = 39955091, template = "portal", text = "月光林地◆", textA = "LEFT", title = "月光林地", info = "赛纳里奥使者托尔·黑蹄：和NPC对话传送到[i]月光林地[/i]" },
        { coord = 50343738, template = "portal", title = "大地的裂变版本传送门", info = "海加尔山传送门\n暮光高地传送门\n瓦斯琪尔传送门\n奥丹姆传送门\n深岩之洲传送门" },
        { coord = 47403926, template = "portal", text = "托巴", title = "托尔巴拉德传送门" },
        { coord = 43046470, template = "portal", text = "雷霆崖", title = "通往雷霆崖的飞艇" },
        { coord = 50755557, template = "portal", text = "幽暗城", title = "幽暗城传送门" },
        { coord = 70583092, template = "portal", text = "搏击", title = "搏击俱乐部" },
        { coord = 38117537, template = "portal", title = "同盟种族传送门", info = "[n]夜之子[/n]\n暗夜要塞传送门\n\n[n]至高岭牛头人[/n]\n雷霆图腾传送门\n\n[n]土灵[/n]\n土灵传送器" },
        { coord = 53637877, template = "inn", info = "格雷什卡" },
        { coord = 32406476, template = "inn", text = "旅店/兽栏/拍卖/银行◆", textA = "LEFT", title = "功能区（精神谷）", info = "[n]旅店老板（下层）[/n]\n希加姆比\n\n[n]兽栏管理员（下层）[/n]\n克苏卡\n\n[n]拍卖行（上层）[/n]\n\n[n]银行（上层）[/n]", tags = {"inn", "stable", "official"} },
        { coord = 38894864, template = "inn", text = "旅店/兽栏/剥皮/裁缝◆", textA = "LEFT", title = "功能区（智慧谷）", info = "[n]旅店老板[/n]\n米瓦娜\n\n[n]裁缝训练师[/n]\n希瓦希·三羽\n\n[n]剥皮训练师[/n]\n雷恩托\n\n[n]兽栏管理员[/n]\n伦托", tags = {"inn", "profession", "stable"} },
        { coord = 71304997, template = "inn", title = "旅店（荣誉谷）", info = "努法" },
        { coord = 40828011, template = "inn", text = "旅店/专业/克罗米◆", textA = "LEFT", title = "功能区（大使馆）", info = "[n]旅店老板[/n]\n缇兹娜·银杯\n\n[n]烹饪训练师[/n]\n风苏\n\n[n]草药学训练师[/n]\n林地栽培者卡多斯\n\n[n]克罗米[/n]\n切换时间线", tags = {"inn", "profession", "special" } },
        { coord = 53987324, template = "auction" },
        { coord = 41674887, template = "auction" },
        { coord = 66633627, template = "auction" },
        { coord = 35857730, template = "auction" },
        { coord = 48838319, template = "bank" },
        { coord = 39904629, template = "bank" },
        { coord = 67585259, template = "bank" },
        -- 专业
        { coord = 55684577, template = "alchemy", info = "耶尔玛克" },
        { coord = 49067056, template = "archaeology", title = "考古学训练师（室内）", info = "贝洛克·辉刃" },
        { coord = 44927771, template = "blacksmithing", text = "◆锻造/采矿", textA = "RIGHT", title = "专业训练师", info = "[n]锻造训练师[/n]\n罗格\n\n[n]采矿训练师[/n]\n古恩托", type = {"Blacksmithing", "Mining"} },
        { coord = 40575024, template = "blacksmithing", info = "奥普诺·铁角" },
        { coord = 76523453, template = "blacksmithing", info = "奥克索斯·铁怒\n伯古什\n萨鲁·钢怒" },
        { coord = 32246967, template = "cooking", info = "扎姆沙" },
        { coord = 56546249, template = "cooking", info = "玛洛格" },
        { coord = 53504958, template = "enchanting", title = "附魔训练师（下层）", info = "古丹" },
        { coord = 56845654, template = "engineering", title = "工程学训练师（下层）", info = "罗克希克" },
        { coord = 37098473, template = "engineering", info = "“杰克”·帕萨雷克·砸修" },
        { coord = 35176734, template = "fishing", info = "老恩姆贝托" },
        { coord = 66454192, template = "fishing", info = "鲁玛克" },
        { coord = 34836285, template = "herbalism", info = "加迪" },
        { coord = 54295094, template = "herbalism", title = "草药学训练师（上层）", info = "穆拉加" },
        { coord = 55095587, template = "inscription", title = "铭文训练师（上层）", info = "内罗格" },
        { coord = 72313491, template = "jewelcrafting", text = "珠宝/采矿◆", textA = "LEFT", title = "专业训练师", info = "[n]珠宝加工训练师[/n]\n鲁格娜\n\n[n]采矿训练师[/n]\n马卡鲁", type = {"Jewelcrafting", "Mining"} },
        { coord = 60905489, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "专业训练师", info = "[n]制皮训练师[/n]\n卡洛雷克\n\n[n]剥皮训练师[/n]\n苏尔德", type = {"Leatherworking", "Skinning"} },
        { coord = 39038551, template = "mining", info = "蕾拉·碎石" },
        { coord = 60745913, template = "tailoring", info = "玛加尔" },
        -- 其他
        { coord = 40346060, template = "barber", text = "理发/外观◆", textA = "LEFT", title = "理发店/眼镜商人", info = "[n]理发师[/n]\n贝布莉·科弗库尔\n\n[n]眼镜商人[/n]\n卡尼斯：出售5款[i]眼镜外观[/i]" },
        { coord = 47647448, template = "transmog", info = "织幻者祖姆基" },
        { coord = 57926551, template = "transmog", info = "织幻者杜沙尔\n\n[n]遗忘传说供应商[/n]\n搜寻者克拉斯：出售丢失的[i]老版本橙装[/i]" },
        { coord = 48837605, template = "tradingpost", info = "赞希里商栈\n\n宠物幻化" },
        { coord = 38138713, template = "stable", text = "兽栏/裁缝◆", textA = "LEFT", title = "兽栏/裁缝训练师", info = "[n]兽栏管理员[/n]\n赫恩·石羽\n\n[n]裁缝训练师[/n]\n织魔者奥莉尔", tags = {"stable", "profession"} },
        { coord = 62153527, template = "stable", text = "兽栏/坐骑◆", textA = "LEFT", title = "兽栏/坐骑商人", info = "[n]兽栏管理员[/n]\n姆罗格\n\n[n]坐骑商人[/n]\n奥古纳罗：出售兽人职业坐骑[i]战狼[/i]", tags = {"stable", "collection"} },
        { coord = 38067808, template = "mount", info = "卡尔·万金：出售地精种族坐骑[i]三轮摩托[/i]" },
        { coord = 47995865, template = "mount", info = "卓卡玛：出售双足飞龙坐骑" },
        { coord = 41847317, template = "mount", title = "战争坐骑军需官", info = "亡灵卫兵奈萨里安[c]（邪气鞍座）[/c]\n\n狼骑兵波尔克[c]（荣耀印记）[/c]" },
        { coord = 52555926, template = "pet", title = "战斗宠物训练师", info = "瓦佐克" },
        { coord = 48124686, template = "pet", info = "珈珈：完成任务可以获得宠物[i]部落气球[/i]" },
        { coord = 52928900, template = "housing", info = "“第二把交椅”袍铎" },
        { coord = 48378114, template = "housing", info = "佳比：出售1款家宅装饰[i]微型黑暗之门复制品[/i]" },
        { coord = 47148002, template = "guild", info = "[n]公会商人[/n]\n古拉姆\n\n[n]公会注册员[/n]\n乌特伦\n\n[n]战袍商人[/n]\n伽雷尔" },
        { coord = 48487155, template = "look", title = "外观商人（上层）", info = "[n]勇气军需官[/n]\n杰姆斯瓦兹\n\n[n]正义军需官[/n]\n贡娜\n\n[n]传承正义军需官[/n]\n鲁戈克" },
        { coord = 35786854, template = "portaltrainer", text = "◆传送/铭文", textA = "RIGHT", title = "传送门训练师/铭文训练师（上层）", info = "[n]传送门训练师[/n]\n观星者吉拉吉\n\n[n]铭文训练师[/n]\n犹尔曼", tags = {"special", "profession"} },
        { coord = 74914326, template = "portaltrainer", title = "传送门训练师（底层）", info = "拉茜丝蕾·金星" },
        { coord = 74274432, color = "special", icon = 894556, text = "经验锁定◆", textA = "LEFT", title = "经验锁定（顶层）", info = "斯拉兹" },
        { coord = 43903941, template = "cinematic", info = "伊萨里奥斯勋爵：可观看巨龙之魂副本中[i]击败死亡之翼的动画[/i]" },
        { coord = 50165844, template = "quartermaster", text = "声望", title = "声望军需官", info = "[n]奥格瑞玛军需官[/n]\n石头守卫纳尔戈尔：出售[i]奥格瑞玛战袍[/i]/1款家宅装饰\n\n[n]暗矛军需官[/n]\n勇土乌拉金：出售[i]暗矛战袍[/i]\n\n[n]锈水财阀军需官[/n]\n弗里兹·维拉马尔：出售[i]锈水财阀战袍[/i]" },
        { coord = 68584025, template = "quartermaster", text = "火金派", title = "火金派军需官/龙龟饲养员", info = "[n]火金派军需官[/n]\n门徒君思：出售[i]火金派熊猫人战袍[/i]\n\n[n]龙龟饲养员[/n]\n乌龟大师吴玳：出售熊猫人种族坐骑[i]龙龟[/i]\n\n[n]特殊道具[/n]\n熊猫洛洛：对NPC使用[i]/love[/i]可获得道具[i]魔力竹笋[/i]，使用后可变身同款熊猫，支持施法" },
        { coord = 38947147, template = "pvp_vendor", title = "PVP商人/家宅商人", info = "[n]旧世界武器军需官[/n]\n石头守卫扎尔格\n\n[n]旧世界护甲军需官[/n]\n一等军士长霍拉麦\n\n[n]杂货军需官[/n]\n卫兵布莱恩·石皮：出售PVP宝石和2款战袍\n\n[n]荣誉传家宝[/n]\n加尔拉\n\n[n]腐化候选者商人[/n]\n阿妮卡·梅莱\n\n[n]嗜血角斗士[/n]\n洛戈克\n\n[n]残忍角斗士[/n]\n桃丽丝·沃兰休斯（第9赛季）\n\n[n]冷酷角斗士[/n]\n血卫士扎尔什（第10赛季）\n\n[n]灾变角斗士[/n]\n雷角中士（第11赛季）\n\n[n]荣誉奖励军需官[/n]\n军团士兵沃拉迪斯：出售3款宠物\n\n[n]战场装饰专家[/n]\n乔鲁尔：出售多款战场类家宅装饰，有成就限制[c]（荣誉点数/荣耀印记）[/c]", tags = {"pvp", "housing"}  },
        { coord = 63693285, template = "dummy" },
        { coord = 62174848, template = "dummy" },
        poiNames = {
            ["前往战歌要塞（北风苔原）的飞艇"] = { color = "portal", text = "北风苔原" },
            ["前往格罗姆高（荆棘谷）的飞艇"] = { color = "portal", text = "荆棘谷" },
            ["前往觉醒海岸（巨龙群岛）的飞艇"] = { color = "portal", text = "觉醒海岸" },
            ["奥格瑞玛传送大厅"] = { color = "portal", text = "传送大厅" },
        },
    },

    -- 奥格瑞玛：暗影裂口
    [86] = {
        group = "Orgrimmar",
        faction = "Horde",
        subZoneScale = 1.2,
        { coord = 45686745, template = "portaltrainer", info = "朗多克" },
        instanceNames = {
            ["怒焰裂谷"] = { text = "怒焰裂谷" },
        },
    },

    -- 奥格瑞玛：搏击俱乐部
    [503] = {
        group = "Orgrimmar",
        faction = "Horde",
        subZoneScale = 1.2,
        { coord = 50872916, template = "quartermaster", text = "搏击", title = "搏击俱乐部军需官", info = "保尔·诺斯：出售2款坐骑/2款宠物/1款战袍/多款衬衣和套装外观/1款传家宝/3款家宅装饰\n\n装备[i]拳手的重击指环[/i]：可传送到搏击俱乐部" },
    },

    --------------------------------------------------------------------------------
    -- 雷霆崖
    --------------------------------------------------------------------------------
    [88] = {
        group = "ThunderBluff",
        faction = "Horde",
        { coord = 15402567, template = "portal_orgrimmar", title = "通往奥格瑞玛的飞艇" },
        { coord = 45816471, template = "inn", info = "帕拉" },
        { coord = 40405178, template = "auction" },
        { coord = 47605859, template = "bank" },
        -- 专业
        { coord = 46623319, template = "alchemy", info = "本娜·冰蹄" },
        { coord = 75042810, template = "archaeology", info = "欧托·灰皮" },
        { coord = 39385509, template = "blacksmithing", info = "卡恩·石蹄" },
        { coord = 50745311, template = "cooking", info = "阿丝卡·迷雾行者" },
        { coord = 45323849, template = "enchanting", info = "泰戈·晨行者" },
        { coord = 36065961, template = "engineering", info = "工程师苍蹄" },
        { coord = 56134642, template = "fishing", info = "卡尔·迷雾行者" },
        { coord = 49964035, template = "herbalism", info = "克米恩·冰蹄" },
        { coord = 28742088, template = "inscription", title = "铭文训练师（下层）", info = "波什金·哈比德尔" },
        { coord = 34825397, template = "jewelcrafting", info = "娜哈莉·追云者" },
        { coord = 41494256, template = "leatherworking", info = "犹纳" },
        { coord = 34385784, template = "mining", info = "布瑞克·石蹄" },
        { coord = 44454315, template = "skinning", info = "莫兰塔" },
        { coord = 44514533, template = "tailoring", info = "坦帕" },
        -- 其他
        { coord = 45086024, template = "stable", info = "布尔鲁格" },
        { coord = 37446343, template = "guild", info = "[n]公会商人[/n]\n兰达·鸣角\n\n[n]公会注册员[/n]\n克拉姆\n\n[n]战袍商人[/n]\n瑟拉姆" },
        { coord = 22471690, template = "portaltrainer", title = "传送门训练师（下层）", info = "比尔吉特·克兰斯顿" },
        { coord = 47045021, template = "quartermaster", text = "雷霆崖", title = "雷霆崖军需官（顶层）", info = "卫兵图霍：出售[i]雷霆崖战袍[/i]/1款家宅装饰" },
        { coord = 57828317, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 幽暗城
    --------------------------------------------------------------------------------
    [90] = {
        group = "Undercity",
        faction = "Horde",
        { coord = 85271707, template = "portal", text = "外域", title = "地狱火半岛传送门" },
        { coord = 67733788, template = "inn", text = "旅店/兽栏◆", textA = "LEFT", title = "旅店/兽栏（上层）", info = "[n]旅店老板[/n]\n诺曼\n\n[n]兽栏管理员[/n]\n安雅·玛尔雷", tags = {"inn", "stable"} },
        { coord = 71434666, template = "auction" },
        { coord = 67555242, template = "auction" },
        { coord = 64415240, template = "auction" },
        { coord = 60484645, template = "auction" },
        { coord = 60504171, template = "auction" },
        { coord = 64393582, template = "auction" },
        { coord = 67633589, template = "auction" },
        { coord = 71514190, template = "auction" },
        { coord = 65984409, template = "bank" },
        -- 专业
        { coord = 47777332, template = "alchemy", info = "赫伯特·哈尔希医生" },
        { coord = 75423770, template = "archaeology", info = "亚当·霍萨克" },
        { coord = 61273058, template = "blacksmithing", info = "詹姆斯·范·布朗特" },
        { coord = 62164490, template = "cooking", title = "烹饪训练师（下层）", info = "尤奈斯·伯奇" },
        { coord = 61856139, template = "enchanting", info = "拉文尼亚·克洛文" },
        { coord = 76147404, template = "engineering", info = "弗兰克林·洛伊德" },
        { coord = 80723126, template = "fishing", info = "阿曼德·克伦威尔" },
        { coord = 54024957, template = "herbalism", info = "马尔萨·奥列斯塔" },
        { coord = 61065800, template = "inscription", info = "玛尔迦·帕克雷" },
        { coord = 56273687, template = "jewelcrafting", text = "珠宝/采矿◆", textA = "LEFT", title = "专业训练师", info = "[n]珠宝加工训练师[/n]\n内勒尔·费恩\n\n[n]采矿训练师[/n]\n布罗姆·基里安", type = {"Jewelcrafting", "Mining"} },
        { coord = 70155918, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "专业训练师", info = "[n]制皮训练师[/n]\n亚瑟·摩尔\n\n[n]剥皮训练师[/n]\n基里安·哈根", type = {"Leatherworking", "Skinning"} },
        { coord = 70763072, template = "tailoring", info = "乔瑟夫·格里高利" },
        -- 其他
        { coord = 69974658, template = "barber", text = "理发◆", textA = "LEFT", title = "理发店（上层）", info = "纳兹尼克·苏萨弗" },
        { coord = 69864371, template = "guild", title = "公会（下层）", info = "[n]公会商人[/n]\n金·霍恩\n\n[n]公会注册员[/n]\n克里斯托弗·德库尔\n\n[n]战袍商人[/n]\n迈瑞尔·普莱森斯" },
        { coord = 78167563, template = "heirloom", info = "艾斯特蕾·根德瑞：出售传家宝/传家宝升级道具/多款地图类玩具[i]侦查地图[/i]" },
        { coord = 84151555, template = "portaltrainer", info = "莱克斯顿·莫泰姆" },
        { coord = 63024900, template = "quartermaster", text = "幽暗城", title = "幽暗城军需官", info = "多纳尔德·亚当斯上尉：出售[i]幽暗城战袍[/i]/2款家宅装饰" },
        { coord = 55221587, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 银月城（燃烧的远征）
    --------------------------------------------------------------------------------
    [110] = {
        group = "SilvermoonCityTBC",
        faction = "Horde",
        { coord = 58551867, template = "portal_orgrimmar" },
        { coord = 49491477, template = "portal", text = "幽暗城", title = "幽暗城传送宝珠" },
        { coord = 79475821, template = "inn", info = "维兰德拉" },
        { coord = 67857290, template = "inn", info = "约维娅" },
        { coord = 92595836, template = "auction" },
        { coord = 60686154, template = "auction" },
        { coord = 89754319, template = "bank" },
        { coord = 66567791, template = "bank" },
        -- 专业
        { coord = 66731678, template = "alchemy", info = "卡博隆" },
        { coord = 81476386, template = "archaeology", info = "埃莱娜拉" },
        { coord = 79403868, template = "blacksmithing", info = "波玛尔" },
        { coord = 69657157, template = "cooking", title = "烹饪训练师（上层）", info = "塞莱恩" },
        { coord = 77034108, template = "engineering", info = "丹文" },
        { coord = 76236775, template = "fishing", info = "德拉森" },
        { coord = 67421838, template = "herbalism", info = "植物学家娜萨兰" },
        { coord = 90347384, template = "jewelcrafting", info = "卡琳达" },
        { coord = 85028057, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "专业训练师", info = "[n]制皮训练师[/n]\n莱纳里斯\n\n[n]剥皮训练师[/n]\n提恩", type = {"Leatherworking", "Skinning"} },
        { coord = 78904324, template = "mining", info = "比利尔" },
        { coord = 57375009, template = "tailoring", info = "基伦·希斯" },
        { coord = 69712367, template = "profession_mixed", text = "◆附魔/铭文", textA = "RIGHT", title = "专业训练师", info = "[n]附魔训练师[/n]\n瑟丹娜\n\n[n]铭文训练师[/n]\n赞塔希娅", type = {"Enchanting", "Inscription"} },
        -- 其他
        { coord = 82713077, template = "stable", info = "沙尔蕾恩" },
        { coord = 78348522, template = "guild", info = "[n]公会商人[/n]\n莱莉希亚\n\n[n]公会注册员[/n]\n坦德莉恩\n\n[n]战袍商人[/n]\n克雷迪斯" },
        { coord = 58082084, template = "portaltrainer", info = "纳林斯" },
        { coord = 82123758, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 战争之矛
    --------------------------------------------------------------------------------
    [624] = {
        group = "Warspear",
        faction = "Horde",
        { coord = 60805161, template = "portal_orgrimmar" },
        { coord = 52894409, template = "portal", text = "沃玛尔", title = "沃玛尔传送门", info = "通往塔纳安丛林的沃玛尔，需要完成任务线才可看到" },
        { coord = 44974323, template = "inn", info = "娜宁·晨光" },
        { coord = 54672562, template = "auction" },
        { coord = 51376191, template = "bank" },
        -- 专业
        { coord = 60952638, template = "alchemy", info = "克里斯托弗·柯西" },
        { coord = 73613118, template = "archaeology", title = "考古学训练师/考古商人", info = "[n]考古学训练师[/n]\n丽娜·碎轮\n\n[n]考古商人[/n]\n瑟卡[c]（修复的遗物）[/c]", tags = {"profession", "vendor"} },
        { coord = 74073708, template = "blacksmithing", info = "马兹顿·商齿" },
        { coord = 45614487, template = "cooking", title = "烹饪训练师（楼梯背后向下）", info = "盖伊·火眼" },
        { coord = 78735291, template = "enchanting", info = "哈尼充" },
        { coord = 71664031, template = "engineering", info = "汉·跳箭" },
        { coord = 69121656, template = "fishing", info = "布里克斯·箭投" },
        { coord = 62683062, template = "herbalism", info = "安东尼·阿里安" },
        { coord = 77084756, template = "inscription", info = "乔鲁晏" },
        { coord = 60243991, template = "jewelcrafting", info = "亚历山大·迅钢" },
        { coord = 49492785, template = "leatherworking", info = "布尔加·硬皮" },
        { coord = 79413532, template = "mining", info = "姆格·石裂" },
        { coord = 48703130, template = "skinning", info = "孔达尔·猎誓" },
        { coord = 59424281, template = "tailoring", info = "塞莎·银血" },
        -- 其他
        { coord = 58565293, template = "transmog", info = "织幻者贾索尔" },
        { coord = 77435949, template = "stable", info = "乌佳" },
        { coord = 42553642, template = "unique_vendor", text = "图纸", title = "要塞图纸商人", info = "托格·菲力克辛顿" },
        { coord = 66636426, template = "unique_vendor", text = "水晶", title = "埃匹希斯水晶商人", info = "共有6位，出售坐骑[i]苔皮淡水兽[/i]/要塞追随者合约[i]寻晨者鲁卡里斯[/i]" },
        { coord = 65295926, template = "unique_vendor", text = "挑战", title = "黄金挑战商人（绝版）", info = "挑战者森弗吉\n\n[a]作者描述：武器外观和特效都非常漂亮[/a]" },
        { coord = 59225019, template = "portaltrainer", info = "萨麦尔·玫刃" },
        { coord = 64196231, color = "special", icon = 838813, text = "R币", title = "R币兑换", info = "命运扭曲者提拉尔：出售[i]钢化命运印记[/i]" },
        { coord = 54006092, template = "quartermaster", text = "声望", title = "声望军需官", info = "[n]霜狼兽人军需官[/n]\n贝斯卡·赤牙：出售坐骑[i]迅捷霜狼[/i]/宠物[i]霜狼幼崽[/i]/玩具[i]永久冰霜精华[/i]\n\n[n]鸦人流亡者军需官[/n]\n鸦语者斯奇加：出售坐骑[i]暗鬃冲锋者[/i]/宠物[i]塞泰之子[/i]/3款家宅装饰\n\n[n]热砂军需官[/n]\n米米·响泡：出售坐骑[i]驯养的刀脊野猪[/i]/宠物[i]白色淡水兽幼崽[/i]/[i]被捕获的森林幼苗[/i]" },
        { coord = 49165493, template = "quartermaster", text = "沃金", title = "沃金之矛军需官", info = "达兹里安：出售[i]沃金之矛战袍[/i]/坐骑[i]风蹄公羊[/i][c]（荣耀印记）[/c]" },
        { coord = 48585755, template = "pvp_vendor", info = "[n]狂野争斗者[/n]\n弗洛比·冲补\n\n[n]狂野角斗士[/n]\n克拉德·晨行者\n\n[n]好战争斗者[/n]\n泰洛克斯·枯魂\n\n[n]好战角斗士[/n]\n玛露卡·轻歌\n\n[n]原祖角斗士[/n]\n血卫士斩斧\n\n[n]原祖争斗者[/n]\n岩卫士碎拳" },
        { coord = 69635638, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 达萨罗
    --------------------------------------------------------------------------------
    [1165] = {
        group = "Dazaralor",
        faction = "Horde",
        { coord = 48458796, template = "inn", title = "旅店（下层）", info = "古克古克\n\n[a]作者吐槽：室外是“达萨罗”城市地图，室内是“祖达萨”区域地图，离谱[/a]", isIndividual = true },
        { coord = 50028980, template = "inn", text = "功能区", title = "功能区", isAggregate = true },
        { coord = 52438494, template = "inn", info = "无情的希莫" },
        { coord = 34751160, template = "inn", info = "可悲的拉克尔" },
        { coord = 38651627, template = "inn", info = "保镖“铁手伙计”罗茜" },
        { coord = 52631722, template = "inn", info = "塔努布" },
        -- 专业
        { coord = 43623830, template = "profession_mixed", isAggregate = true },
        { coord = 42223797, template = "alchemy", info = "聪明的库玛莉", isIndividual = true },
        { coord = 43623830, template = "blacksmithing", text = "◆锻造/采矿", textA = "RIGHT", title = "专业训练师", info = "[n]锻造训练师[/n]\n掌炉者扎克阿尔\n\n[n]采矿训练师[/n]\n金匠西科特", type = {"Blacksmithing", "Mining"}, isIndividual = true },
        { coord = 52469044, template = "cooking", title = "烹饪训练师（下层）", info = "豪查", isIndividual = true },
        { coord = 38091416, template = "cooking", info = "厨子玛拉" },
        { coord = 47083569, template = "enchanting", title = "附魔训练师（下层室内）", info = "女附魔师奎妮", isIndividual = true },
        { coord = 45144059, template = "engineering", text = "◆工程/拆解", textA = "RIGHT", title = "工程学训练师/拆解大师Mk1型", info = "舒佳·爆帽", tags = {"profession", "special"} },
        { coord = 50522336, template = "fishing", info = "安静的塔莉" },
        { coord = 42103560, template = "herbalism", info = "贾登·弗拉", isIndividual = true },
        { coord = 42333971, template = "inscription", info = "记载者伽祖尔", isIndividual = true },
        { coord = 39201745, template = "inscription", info = "托可" },
        { coord = 47063792, template = "jewelcrafting", title = "珠宝训练师（下层室内）", info = "瑟舒利", isIndividual = true },
        { coord = 43763466, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n赞约\n\n[n]剥皮训练师[/n]\n“快刀”拉娜", type = {"Leatherworking", "Skinning"}, isIndividual = true },
        { coord = 36551789, template = "tailoring", info = "米力奈·哈吉特" },
        { coord = 44483390, template = "tailoring", info = "耐心的品金", isIndividual = true },
        -- 其他
        { coord = 47358105, template = "barber", info = "康纳·响痕" },
        { coord = 54478846, template = "transmog", text = "◆幻化/R币", textA = "RIGHT", title = "幻化师/R币兑换（2层）", info = "[n]幻化师[/n]\n织幻者哈伊里\n\n[n]命运大师[/n]\n祖尔温：可用金币/职业大厅资源/荣耀印记兑换[i]战痕命运印记[/i]", tags = {"service", "special"} },
        { coord = 47968914, template = "stable", title = "兽栏（上层）", info = "驭兽者苏佳妮", isIndividual = true },
        { coord = 45773630, template = "stable", info = "驭兽者卡拉塔克" },
        { coord = 47739166, template = "mount", title = "坐骑商人（下层）", info = "多哥：出售2款坐骑[i]骆驼[/i][c]（需要拉穆卡恒声望崇拜）[/c]", isIndividual = true },
        { coord = 48588709, template = "mount", title = "坐骑商人（上层）", info = "塔路图：出售坐骑[i]灰皮恐角龙[/i]/宠物[i]失落的栉龙[/i]", isIndividual = true },
        { coord = 55933236, template = "pet", title = "宠物商人（室内）", info = "快乐的霍罗阿：出售2款玩具/4款宠物[c]（抛光的宠物符咒）[/c]" },
        { coord = 51229508, template = "unique_vendor", text = "勋章", title = "服役勋章", info = "供给商穆克拉：出售以下商品[c]（荣耀战团服役勋章）[/c]\n\n3款坐骑/1款宠物/1款玩具/5款传家宝/2款披风外观/7款家宅装饰\n装备[i]指挥官的战斗玺戒[/i]：可传送到达萨罗\n道具[i]十地饮剂[/i]：可提升10%经验（等级不高于49级）" },
        { coord = 44479445, template = "unique_vendor", text = "海岛", title = "海岛商人", info = "[n]达布隆币商人[/n]\n泽塔佳船长：出售2款坐骑/2款宠物/3款玩具/3款帽子外观/1款家宅装饰[c]（海员达布隆币）[/c]\n\n[n]公海“打捞”专家[/n]\n基特船长：出售3款[i]打捞品[/i][c]（海员达布隆币）[/c]" },
        { coord = 53018994, template = "unique_vendor", text = "◆格里伏塔", textA = "RIGHT", title = "格里伏塔（上层）", info = "出售玩具[i]赞达拉人像护符[/i][c]（伪造的拉斯塔哈面具）[/c]" },
        { coord = 51833502, template = "dummy", title = "木桩（室内）" }
    },

    -- 达萨罗：巨擘封印
    [1163] = {
        group = "Dazaralor",
        faction = "Horde",
        subZoneScale = 0.8,
        { coord = 73786992,  template = "portal_orgrimmar" },
        { coord = 73796238,  template = "portal", text = "银月城", title = "银月城传送门" },
        { coord = 73717743,  template = "portal", text = "雷霆崖", title = "雷霆崖传送门" },
        { coord = 73588541,  template = "portal", text = "希利苏斯", title = "希利苏斯传送门", info = "需要[i]切回当前时间线[/i]" },
        { coord = 62948538,  template = "portal", text = "纳沙塔尔", title = "纳沙塔尔传送门", info = "需要[i]完成相关任务[/i]" },
        { coord = 48757191, template = "inn", info = "“美人”布丽琳" },
        { coord = 30526779, template = "bank", info = "[a]作者吐槽：室外是“巨擘封印”地图，室内是“祖达萨”区域地图，直接退了2级，离谱[/a]" },
        { coord = 32003112, template = "archaeology", info = "考察者阿勒琳达" },
        { coord = 66997347, template = "portaltrainer", info = "首席传送师欧库勒斯" },
    },

    -- 达萨罗：记载者大厅
    [1164] = {
        group = "Dazaralor",
        faction = "Horde",
        subZoneScale = 0.8,
        { coord = 28524989, template = "cooking", info = "皇家大厨提萨拉" },
        { coord = 70493300, template = "inscription", info = "记载者基扎尼" },
        { coord = 36446000, template = "housing", info = "提拉玛" },
        { coord = 54213702, template = "guild", info = "[n]公会商人[/n]\n尤拉·天足\n\n[n]公会注册员[/n]\n克林基利·腐拳" },
        { coord = 67257151, template = "quartermaster", text = "◆赞达拉帝国", textA = "RIGHT", title = "赞达拉帝国军需官", info = "纳塔哈卡塔：出售2款坐骑/1款玩具" },
        { coord = 68593071, template = "randomraid", info = "埃浦：奥迪尔/达萨罗之战/风暴熔炉/永恒王宫/尼奥罗萨，觉醒之城" },
    },

    --------------------------------------------------------------------------------
    -- 沙塔斯
    --------------------------------------------------------------------------------
    [111] = {
        group = "Shattrath",
        faction = "Neutral",
        { coord = 57234828, template = "portal_stormwind", text = "◆暴风", textA = "RIGHT" },
        { coord = 56814887, template = "portal_orgrimmar", text = "奥格◆", textA = "LEFT" },
        { coord = 48584201, template = "portal", text = "奎岛", title = "奎尔丹纳斯岛传送门" },
        { coord = 74683144, template = "portal", text = "时光之穴◆", textA = "LEFT", title = "时光之穴传送门", info = "塞菲尔：和NPC对话传送到[i]时光之穴[/i][c]（需要时光守护者声望崇拜）[/c]" },
        { coord = 28294936, template = "inn", info = "米娜蕾" },
        { coord = 56328155, template = "inn", info = "海索恩" },
        { coord = 51192696, template = "auction" },
        { coord = 56896273, template = "auction" },
        { coord = 48092930, template = "bank" },
        { coord = 60176037, template = "bank" },
        -- 专业
        { coord = 38473015, template = "alchemy", text = "◆炼金/草药", textA = "RIGHT", title = "专业训练师", info = "[n]炼金术训练师[/n]\n炼金师卡恩胡\n\n[n]草药学训练师[/n]\n吉嘉", type = {"Alchemy", "Herbalism"} },
        { coord = 38297097, template = "alchemy", text = "炼金/草药◆", textA = "LEFT", title = "专业训练师", info = "[n]炼金术训练师[/n]\n埃尔辛\n\n[n]草药学训练师[/n]\n草药学家奥莱拉", type = {"Alchemy", "Herbalism"} },
        { coord = 45632151, template = "alchemy", title = "炼金术训练师（上层）", info = "罗罗基姆" },
        { coord = 62667033, template = "archaeology", info = "搜寻者波杜鲁" },
        { coord = 69634268, template = "blacksmithing", info = "克拉度·利刃\n祖拉·熔怒" },
        { coord = 63106837, template = "cooking", info = "杰克·塔博尔" },
        { coord = 36022074, template = "jewelcrafting", info = "哈曼纳尔" },
        { coord = 36034830, template = "jewelcrafting", text = "◆珠宝/采矿", textA = "RIGHT", title = "专业训练师", info = "[n]珠宝加工训练师[/n]\n奈米哈\n\n[n]采矿训练师[/n]\n弗诺", type = {"Jewelcrafting", "Mining"} },
        { coord = 58527511, template = "jewelcrafting", text = "◆珠宝/采矿", textA = "RIGHT", title = "专业训练师", info = "[n]珠宝加工训练师[/n]\n吉蕾布莉·银丝\n\n[n]采矿训练师[/n]\n韩里尔", type = {"Jewelcrafting", "Mining"} },
        { coord = 63976590, template = "skinning", info = "塞莫尔" },
        { coord = 37663161, template = "profession_mixed", text = "锻造/工程◆", textA = "LEFT", title = "专业训练师", info = "[n]锻造训练师[/n]\n奥努度\n\n[n]工程学训练师[/n]\n技师米希拉", type = {"Blacksmithing", "Engineering"} },
        { coord = 43656509, template = "profession_mixed", text = "◆锻造/工程", textA = "RIGHT", title = "专业训练师", info = "[n]锻造训练师[/n]\n巴利尔\n\n[n]工程学训练师[/n]\n工程师辛蓓", type = {"Blacksmithing", "Engineering"} },
        { coord = 36294393, template = "profession_mixed", text = "◆附魔/铭文", textA = "RIGHT", title = "专业训练师", info = "[n]附魔训练师[/n]\n苏蕾\n\n[n]铭文训练师[/n]\n记录员利迪欧", type = {"Enchanting", "Inscription"} },
        { coord = 55747451, template = "profession_mixed", text = "附魔/铭文◆", textA = "LEFT", title = "专业训练师", info = "[n]附魔训练师[/n]\n附魔师安蒂亚拉\n\n[n]铭文训练师[/n]\n抄写员兰罗尔", type = {"Enchanting", "Inscription"} },
        { coord = 67276742, template = "profession_mixed", text = "◆制皮/特殊裁缝", textA = "RIGHT", title = "专业训练师", info = "[n]制皮训练师[/n]\n达尔玛里\n\n[n]暗纹裁缝大师[/n]\n安迪恩·达克斯宾\n\n[n]魔焰裁缝大师[/n]\n金吉·斯比维尔\n\n[n]月布裁缝大师[/n]\n纳丝玛拉·月歌", type = {"Leatherworking", "Tailoring"} },
        { coord = 41006334, template = "profession_mixed", text = "制皮/裁缝/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n戴恩瑞尔\n\n[n]裁缝训练师[/n]\n米拉丽丝\n\n[n]剥皮训练师[/n]\n伊尔杜", type = {"Leatherworking", "Tailoring", "Skinning"} },
        { coord = 37452724, template = "profession_mixed", text = "制皮/裁缝/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n库里姆\n\n[n]裁缝训练师[/n]\n编织者欧尔\n\n[n]剥皮训练师[/n]\n德雷姆", type = {"Leatherworking", "Tailoring", "Skinning"} },
        { coord = 43998965, template = "profession_mixed", text = "◆专业区", textA = "RIGHT", info = "每个书柜代表一个专业，可学习外域专业技能和制作外域家宅装饰" },
        -- 其他
        { coord = 28604777, template = "stable", info = "奥尔鲁赫" },
        { coord = 55987999, template = "stable", info = "伊苏瑞尔" },
        { coord = 23653284, template = "look", title = "套装兑换", info = "阿苏尔" },
        { coord = 24882688, template = "look", title = "套装兑换", info = "克尔拉兰" },
        { coord = 42419044, template = "look", title = "套装兑换", info = "阿罗迪斯·炎刃" },
        { coord = 44949168, template = "look", title = "套装兑换", info = "维恩娜·晨星" },
        { coord = 65656926, template = "unique_vendor", text = "◆格里伏塔", textA = "RIGHT", title = "格里伏塔" },
        { coord = 75443050, template = "unique_vendor", title = "社交名媛", info = "哈莉丝·西尔顿：出售2款玩具[i]戒指[/i]/2款著名背包[i]“巨无霸”背包/便携黑洞[/i]" },
        { coord = 30773461, template = "quartermaster", icon = 136149, text = "◆印记提交", textA = "RIGHT", title = "圣光护卫者阿德因", info = "提交[i]萨格拉斯印记[/i]" },
        { coord = 45208145, template = "quartermaster", icon = 133378, text = "徽记提交◆", textA = "LEFT", title = "魔导师菲亚琳", info = "提交[i]日怒徽记[/i]/[i]火翼徽记[/i]" },
        { coord = 47712575, template = "quartermaster", text = "奥尔多", title = "奥尔多军需官", info = "恩达尔林" },
        { coord = 60516432, template = "quartermaster", text = "占星者", title = "占星者军需官", info = "恩努利尔" },
        { coord = 62006882, template = "quartermaster", text = "贫民窟◆", textA = "LEFT", title = "贫民窟军需官", info = "纳克杜" },
        { coord = 51004171, template = "quartermaster", text = "◆沙塔尔", textA = "RIGHT", title = "沙塔尔军需官", info = "奥玛多尔" },
    },

    --------------------------------------------------------------------------------
    -- 达拉然（巫妖王之怒）
    --------------------------------------------------------------------------------
    [125] = {
        group = "DalaranWLK",
        faction = "Neutral",
        { coord = 40086277, template = "portal_stormwind" },
        { coord = 55332544, template = "portal_orgrimmar" },
        { coord = 25974419, template = "portal", text = "天台", title = "紫罗兰天台传送门", info = "通往紫罗兰城堡顶层的紫罗兰天台" },
        { coord = 35324526, template = "portal", text = "下水道", title = "下水道入口" },
        { coord = 60214764, template = "portal", text = "下水道", title = "下水道入口" },
        { coord = 50253952, template = "inn", info = "艾米丝·埃索盖斯" },
        { coord = 44676333, template = "inn", info = "伊丝拉米·轻风" },
        { coord = 65633217, template = "inn", info = "兽女乌达" },
        { coord = 38522511, template = "auction" },
        { coord = 37095479, template = "auction", text = "拍卖/外观◆", textA = "LEFT", title = "拍卖行/传承正义军需官（上层）", info = "[n]蒸汽动力拍卖师[/n]\n布拉斯博特·机钳\n\n[n]传承正义军需官[/n]\n奥术师艾弗蕾妮\n奥术师埃杜林\n奥术师米露蕊娅\n奥术师尤维尔\n奥术师菲莱尔", tags = {"official", "vendor"} },
        { coord = 65512345, template = "auction", text = "◆拍卖/外观", textA = "RIGHT", title = "拍卖行/传承正义军需官", info = "[n]蒸汽动力拍卖师[/n]\n雷加纳德·弧炎\n\n[n]传承正义军需官[/n]\n魔导师维莎拉\n魔导师拉姆布莉丝\n魔导师奥尔兰\n魔导师布拉塞尔\n魔导师萨雷恩", tags = {"official", "vendor"} },
        { coord = 43977693, template = "bank" },
        { coord = 52861801, template = "bank" },
        -- 专业
        { coord = 42653204, template = "alchemy", info = "林奇·黑箭" },
        { coord = 48353820, template = "archaeology", info = "博学者达瑞妮斯" },
        { coord = 44772854, template = "blacksmithing", info = "奥兰德·夏菲尔\n奥拉尔德·施米尔\n伊曼蒂尔·锋歌" },
        { coord = 40256612, template = "cooking", info = "[n]烹饪训练师[/n]\n凯瑟琳·李\n\n[n]烹饪供应商[/n]\n德里克·奥斯：出售玩具[i]大厨的帽子[/i][c]（美食家奖章）[/c]" },
        { coord = 69983900, template = "cooking", info = "[n]烹饪训练师[/n]\n埃维罗·隆古巴\n\n[n]烹饪供应商[/n]\n米森希：出售玩具[i]大厨的帽子[/i][c]（美食家奖章）[/c]" },
        { coord = 39063982, template = "enchanting", info = "附魔师纳萨尼斯" },
        { coord = 39072659, template = "engineering", info = "迪墨菲·欧申克\n芬德尔·汽哨\n钳工蒂迪" },
        { coord = 53046494, template = "fishing", info = "玛西娅·切斯" },
        { coord = 42933409, template = "herbalism", info = "多萝希·埃裉" },
        { coord = 41603715, template = "inscription", info = "帕林教授" },
        { coord = 40673536, template = "jewelcrafting", info = "[n]珠宝加工训练师[/n]\n提莫斯·琼斯\n\n[n]珠宝商人[/n]\n哈罗德·温斯顿：出售装备[i]肯瑞托戒指[/i]，可传送到达拉然" },
        { coord = 34762842, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n蒂亚妮·坎宁斯\n\n[n]剥皮训练师[/n]\n迪尔克·马克斯", type = {"Leatherworking", "Skinning"} },
        { coord = 41492568, template = "mining", info = "杰迪安·汉德尔斯" },
        { coord = 36133355, template = "tailoring", title = "裁缝训练师/特殊裁缝商人", info = "[n]裁缝训练师[/n]\n查理·沃尔斯\n\n[n]月布裁缝专家[/n]\n埃德尔鲁·夏叶\n\n[n]魔焰裁缝专家[/n]\n兰尔拉·亮纹\n\n[n]暗纹裁缝专家[/n]\n琳娜·布鲁德" },
        -- 其他
        { coord = 52283154, template = "barber", info = "吉兹·考波克利" },
        { coord = 59633741, template = "stable", info = "塔西娅·幽谷" },
        { coord = 58124208, template = "mount", info = "梅尔·弗兰希斯：出售多款坐骑，包括三人坐骑[i]旅行者的苔原猛犸象[/i]" },
        { coord = 44814562, template = "toy", info = "耶比托·乔巴斯/发条助手：出售多款玩具和宠物" },
        { coord = 58833900, template = "pet", info = "布琳妮：出售2款玩具/4款宠物" },
        { coord = 51205442, template = "guild", info = "[n]公会商人[/n]\n米尔拉·银焰\n\n[n]公会注册员[/n]\n安德鲁·马休\n\n[n]战袍商人[/n]\n伊丽莎白·罗斯" },
        { coord = 37153795, template = "look", info = "安吉莉克·巴特雷：出售2款[i]绷带衬衣外观[/i]" },
        { coord = 43494905, template = "look", title = "套装兑换（布甲）", info = "[n]布甲商人[/n]\n帕尔蒂丝\n鲁本·劳伦\n\n[n]衬衣商人[/n]\n卡兰杜娜：出售16款[i]衬衣外观[/i]" },
        { coord = 51337232, template = "look", title = "套装兑换（皮甲/锁甲）", info = "[n]皮甲商人[/n]\n拉法尔·朗罗\n瓦蕾莉·兰格鲁\n\n[n]锁甲商人[/n]\n玛蒂尔达·明火\n布拉古德·明火" },
        { coord = 46412668, template = "look", title = "套装兑换（板甲）", info = "杜比·克雷\n格里丝华尔德·哈兰德\n霍莱斯·哈德兰" },
        { coord = 57475316, template = "look", info = "爱丽丝·普里洛斯：出售6款[i]花朵副手外观[/i]" },
        { coord = 38605555, template = "unique_vendor", title = "魔法物品（下层）", info = "恩多拉·莫尔海德：出售以下商品\n\n固定商品\n法师技能[i]神秘宝典：奥术语言[/i]\n法师技能[i]神秘宝典：幻觉[/i]\n法师玩具[i]魔宠石[/i]\n\n随机商品\n法师技能[i]宝典：变形术：黑猫[/i]\n法师技能[i]远古传送门：达拉然[/i]\n法师玩具[i]达拉然学徒的胸针[/i]" },
        { coord = 40012834, template = "unique_vendor", text = "冰冻", title = "冰冻宝珠商人", info = "鼎鼎有名的佛罗佐：出售材料和裁缝图样[i]凝霜飞毯[/i][c]（冰冻宝珠）[/c]" },
        { coord = 56314673, template = "portaltrainer", info = "大法师塞琳德拉\n\n点击后方水晶可传送至达拉然城外的紫罗兰哨站" },
        { coord = 49774749, template = "cinematic", info = "雕像喷泉两侧的[i]荣耀之碑[/i]：可观看冰冠堡垒副本中[i]击败巫妖王的动画[/i]" },
        { coord = 64165484, template = "randomraid", info = "大法师提迈尔：翡翠梦魇/暗夜要塞/萨格拉斯之墓/燃烧王座\n\n[a]作者吐槽：所以为什么诺森德达拉然会有军团达拉然的随机本NPC[/a]" },
        { coord = 25214776, template = "quartermaster", text = "肯瑞托", title = "肯瑞托军需官", info = "大法师奥瓦利斯" },
        instanceNames = {
            ["紫罗兰监狱"] = { text = "紫罗兰监狱" },
        },
    },

    -- 达拉然（巫妖王之怒）：下水道
    [126] = {
        group = "DalaranWLK",
        faction = "Neutral",
        { coord = 35465758, template = "inn", info = "埃因·格林" },
        { coord = 32515535, template = "bank" },
        { coord = 64171658, template = "pet", title = "魔法材料商人", info = "达拉希尔：出售1款宠物[i]魅影精灵[/i]" },
        { coord = 47362760, template = "unique_vendor", title = "鬼祟的书商（随机刷新）", info = "卡维兹·洛典：出售各种[i]一部催人泪下的言情小说[/i]/萨满技能[i]妖术书：蟑螂[/i]" },
        { coord = 59345822, template = "pvp_vendor", info = "[n]凶残角斗士[/n]\n利齿里克斯\n\n[n]憎恨角斗士[/n]\n布拉兹克·火爪\n\n[n]致命角斗士[/n]\n赫温·汽爆\n\n[n]狂怒角斗士[/n]\n基洛·科尔温\n\n[n]无情角斗士[/n]\n佐姆·波克\n\n[n]暴怒角斗士[/n]\n夏尔兹·斯莫德普" },
    },

    --------------------------------------------------------------------------------
    -- 达拉然（军团再临）
    --------------------------------------------------------------------------------
    [627] = {
        group = "DalaranLegion",
        faction = "Neutral",
        { coord = 49474784, template = "portal", title = "守护者大厅", info = "可传送到龙眠神殿/泰洛古斯裂隙/卡拉赞" },
        { coord = 39546318, template = "portal_stormwind" },
        { coord = 55262398, template = "portal_orgrimmar" },
        { coord = 34594553, template = "portal", text = "下水道", title = "下水道入口" },
        { coord = 59854790, template = "portal", text = "下水道", title = "下水道入口" },
        { coord = 49794013, template = "inn", info = "艾米丝·埃索盖斯" },
        { coord = 44196374, template = "inn", info = "伊丝拉米·轻风" },
        { coord = 65423222, template = "inn", info = "兽女乌达" },
        { coord = 43497742, template = "bank" },
        { coord = 52441805, template = "bank" },
        -- 专业
        { coord = 42043177, template = "alchemy", info = "林奇·黑箭\n德崔斯·瓦德拉" },
        { coord = 41212644, template = "archaeology", info = "博学者达瑞妮斯" },
        { coord = 39706651, template = "cooking", title = "烹饪训练师/烹饪订单", info = "[n]烹饪训练师[/n]\n凯瑟琳·李\n\n[n]烹饪订单[/n]\n诺米：可下达烹饪订单" },
        { coord = 69973895, template = "cooking", title = "烹饪训练师/烹饪订单", info = "[n]烹饪训练师[/n]\n埃维罗·隆古巴\n\n[n]烹饪订单[/n]\n诺米：可下达烹饪订单" },
        { coord = 39224093, template = "enchanting", text = "附魔/幻化◆", textA = "LEFT", title = "附魔训练师/幻化师", info = "[n]附魔训练师[/n]\n附魔师纳萨尼斯\n\n[n]幻化师[/n]\n织幻者图维斯", tags = {"profession", "service"} },
        { coord = 38812472, template = "engineering", info = "迪墨菲·欧申克\n钳工蒂迪" },
        { coord = 52836560, template = "fishing", info = "玛西娅·切斯" },
        { coord = 42343389, template = "herbalism", info = "莉亚娜·泰/奎茵·柔步" },
        { coord = 41283705, template = "inscription", info = "帕林教授" },
        { coord = 40053529, template = "jewelcrafting", info = "[n]珠宝加工训练师[/n]\n提莫斯·琼斯\n\n[n]珠宝商人[/n]\n斯米克斯·璃目：出售戒指[i]肯瑞托强化指环[/i]，可传送到达拉然" },
        { coord = 35082943, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n蒂亚妮·坎宁斯\n娜穆·月水\n泰尼德·怒金\n\n[n]剥皮训练师[/n]\n孔达尔·猎誓", type = {"Leatherworking", "Skinning"} },
        { coord = 46092664, template = "mining", info = "迪格丝大妈" },
        { coord = 35003461, template = "tailoring", info = "坦妮瑟娅" },
        -- 其他
        { coord = 51863166, template = "barber", info = "吉兹·考波克利" },
        { coord = 59233762, template = "stable", info = "塔西娅·幽谷" },
        { coord = 57614212, template = "mount", info = "梅尔·弗兰希斯：出售多款坐骑，包括三人坐骑[i]旅行者的苔原猛犸象[/i]" },
        { coord = 58453916, template = "pet", title = "宠物商人/传送", info = "[n]宠物商人[/n]\n达姆斯：出售6款宠物/玩具[i]娜茜萨的镜子[/i][c]（抛光的宠物符咒）[/c]\n\n布琳妮：出售4款宠物/2款玩具\n\n缇菲·机簧（联盟）/吉雅达·金索（部落）：出售6款宠物/玩具[i]魔法宠物镜[/i][c]（抛光的宠物符咒）[/c]\n\n[i]传送门[/i]\n玛纳波夫：和NPC对话传送到哀嚎洞穴/死亡矿井/诺莫瑞根/斯坦索姆/黑石深渊" },
        { coord = 43904662, template = "toy", info = "耶比托·乔巴斯：出售多款玩具和宠物，包括玩具[i]棱彩装饰[/i]" },
        { coord = 43154909, template = "housing", info = "拉希尔·火脉：出售1款家宅装饰[i]“仰望天空”画作[/i]" },
        { coord = 50565513, template = "guild", info = "[n]公会注册员[/n]\n安德鲁·马休\n\n[n]战袍商人[/n]\n伊丽莎白·罗斯" },
        { coord = 36013753, template = "look", info = "安吉莉克·巴特雷：出售2款[i]绷带衬衣外观[/i]" },
        { coord = 50907303, template = "look", title = "套装兑换（皮甲/锁甲）", info = "[n]皮甲商人[/n]\n拉法尔·朗罗\n瓦蕾莉·兰格鲁\n\n[n]锁甲商人[/n]\n玛蒂尔达·明火\n布拉古德·明火" },
        { coord = 37285559, template = "look", title = "套装兑换（布甲）", info = "[n]布甲商人[/n]\n帕尔蒂丝\n布商\n\n[n]衬衣商人[/n]\n萨兰·日线：出售16款[i]衬衣外观[/i]\n\n理查德·哈特斯多克：出售2款[i]帽子外观[/i]" },
        { coord = 57115353, template = "look", info = "爱丽丝·普里洛斯：出售6款[i]花朵副手外观[/i]" },
        { coord = 44743195, template = "unique_vendor", text = "血商", title = "萨格拉斯之血商人", info = "伊尔妮雅·血棘：出售军团版本各种材料和职业大厅资源[c]（萨格拉斯之血）[/c]" },
        { coord = 48811361, template = "unique_vendor", text = "◆古怪硬币", textA = "RIGHT", title = "古怪硬币商人", info = "苏伊奥斯：出售坐骑[i]阿坎迪安战龟[/i]/玩具[i]圣光微粒[/i]（商品随机刷新）" },
        { coord = 45172908, template = "unique_vendor", text = "◆橙装/锻造", textA = "RIGHT", title = "橙装商人/锻造训练师", info = "[n]传说物品商人[/n]\n奥法工匠维迪尔：出售军团版本全职业橙装[c]（觉醒精华）[/c]\n\n[n]锻造训练师[/n]\n奥法工匠维迪尔\n奥拉尔德·施米尔", tags = {"unique", "profession"} },
        { coord = 55994701, template = "portaltrainer", info = "大法师塞琳德拉" },
        { coord = 56906716, color = "special", icon = 1604167, text = "R币", title = "R币兑换", info = "大法师兰达洛克：可用金币/职业大厅资源/荣耀印记兑换[i]破碎命运印记[/i]" },
        { coord = 25914458, color = "special", icon = 134156, text = "动画/克罗米◆", textA = "LEFT", title = "动画短片/场景战役", info = "[n]动画短片[/n]\n罗伯特·纽哈斯：可观看[i]伊利丹的故事[/i]/[i]卡德加的故事[/i]2段动画\n\n[n]克罗米[/n]\n可进入场景战役[i]拯救克罗米[/i]" },
        { coord = 63605479, template = "randomraid", info = "大法师提迈尔：翡翠梦魇/暗夜要塞/萨格拉斯之墓/燃烧王座" },
        { coord = 29197530, template = "pvp_vendor", info = "[n]军团角斗士[/n]\n苏提斯中尉\n\n[n]精锐军团角斗士[/n]\n罗伯茨上尉\n\n[n]军团争斗者[/n]\n多根中尉" },
        { coord = 33417401, template = "pvp_vendor", title = "角斗士军需官", info = "弗雷泽元帅[c]（战斗的回响/主宰的回响）[/c]" },
        { coord = 56922819, template = "pvp_vendor", info = "[n]军团角斗士[/n]\n药剂师李\n\n[n]精锐军团角斗士[/n]\n狂野的萨拉\n\n[n]军团争斗者[/n]\n塔里娅·恐角" },
        { coord = 59622517, template = "pvp_vendor", title = "角斗士军需官", info = "维奥莱特·影愈[c]（战斗的回响/主宰的回响）[/c]" },
        poiNames = {
            ["阿古斯"] = { color = "portal", text = "阿古斯" },
        },
        instanceNames = {
            ["突袭紫罗兰监狱"] = { text = "突袭紫罗兰监狱" },
        }
    },

    -- 达拉然（军团再临）：下水道
    [628] = {
        group = "DalaranLegion",
        faction = "Neutral",
        { coord = 71401794, template = "blackmarket" },
        { coord = 58265750, template = "pet", info = "劳拉·马利：出售宠物[i]阴沟水母[/i]和2款制皮图样，可制作玩具[i]火圈/皮质宠物缰绳[/i][c]（盲目之眼）[/c]" },
        { coord = 46605613, color = "vendor", icon = 801132, text = "商人", title = "凶狠的术士", info = "马修·莱比斯：出售铭文工艺图[i]魔典：空灵领主[/i]，可制作术士宠物空灵领主外观，并在理发店解锁[c]（盲目之眼）[/c]" },
        { coord = 66217418, color = "vendor", icon = 801132, text = "商人", title = "魔法物品（2层）", info = "达兹克·“普罗德摩尔”：出售裁缝图样[i]衣柜：达拉然平民[/i][c]（盲目之眼）[/c]" },
        { coord = 65578027, color = "vendor", icon = 801132, text = "商人", title = "传送门与杂货（3层）", info = "柯胡塔：出售附魔公式[i]魔光火盆[/i][c]（盲目之眼）[/c]" },
        { coord = 76108359, template = "unique_vendor", text = "◆语言药剂", textA = "RIGHT", title = "语言药剂商人", info = "菲兹·电胆：出售[i]语言药剂[/i]，可理解敌对阵营语言" },
        { coord = 50963798, template = "unique_vendor", title = "鬼祟的书商（随机刷新）", info = "卡维兹·洛典：出售各种[i]一部催人泪下的言情小说[/i]/萨满技能[i]妖术书：蟑螂[/i]" },
    },

    -- 达拉然（军团再临）：守护者大厅
    [629] = {
        group = "DalaranLegion",
        faction = "Neutral",
        { coord = 33867859, template = "portal", text = "◆泰洛古斯裂隙", textA = "RIGHT", title = "泰洛古斯裂隙传送门" },
        { coord = 64972109, template = "portal", text = "达拉然", title = "达拉然传送门" },
        { coord = 30808433, template = "portal", text = "龙眠神殿◆", textA = "LEFT", title = "龙眠神殿传送门" },
        { coord = 32027155, template = "portal", text = "卡拉赞", title = "卡拉赞传送门" },
        { coord = 30588120, template = "upgrade", info = "库佐尔兹" },
        { coord = 33348447, template = "unique_vendor", text = "残忆", title = "残忆商人（绝版）", info = "怀念者阿穆尔" },
    },

    --------------------------------------------------------------------------------
    -- 奥利波斯
    --------------------------------------------------------------------------------
    [1670] = {
        group = "Oribos",
        faction = "Neutral",
        { coord = 20884570, template = "portal_stormwind" },
        { coord = 20885478, template = "portal_orgrimmar" },
        { coord = 57115035, color = "portal", icon = 450907, text = "上楼", title = "上楼" },
        { coord = 52104278, color = "portal", icon = 450907, text = "上楼", title = "上楼" },
        { coord = 47065035, color = "portal", icon = 450907, text = "上楼", title = "上楼" },
        { coord = 52105785, color = "portal", icon = 450907, text = "上楼", title = "上楼" },
        { coord = 67465034, template = "inn", info = "塔·雷拉" },
        { coord = 60442939, template = "bank", title = "银行" },
        { coord = 65193601, template = "bank", text = "◆公会银行", textA = "RIGHT", title = "公会银行" },
        -- 专业
        { coord = 39244039, template = "alchemy", info = "炼药师奥·派尔" },
        { coord = 40513147, template = "blacksmithing", info = "匠人奥·伯克" },
        { coord = 46822266, template = "cooking", info = "厨师奥·克鲁特" },
        { coord = 48392942, template = "enchanting", info = "灌魔师奥·弗雷什" },
        { coord = 38084474, template = "engineering", text = "◆工程/拍卖", textA = "RIGHT", title = "工程学训练师/拍卖行", info = "[n]工程学训练师[/n]\n机械师奥·古尔\n\n[n]全息拍卖师（需要工程学）[/n]\n光子齿轮议价者", tags = {"profession", "official"} },
        { coord = 46172636, template = "fishing", info = "[n]钓鱼训练师[/n]\n寻回者奥·普林\n\n[n]钓鱼商人[/n]\n经销商奥·那格勒：出售[i]“掮灵垂钓器”[/i]" },
        { coord = 40223827, template = "herbalism", info = "遴选师奥·玛尔" },
        { coord = 36503670, template = "inscription", info = "抄写员奥·泰希" },
        { coord = 35234138, template = "jewelcrafting", info = "鉴定师奥·威森克" },
        { coord = 42172725, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n制革师奥·吉尔\n\n[n]剥皮训练师[/n]\n剥皮者奥·克姆", type = {"Leatherworking", "Skinning"} },
        { coord = 39303299, template = "mining", info = "挖掘者奥·非尔" },
        { coord = 45503178, template = "tailoring", info = "缝合者奥·菲斯" },
        -- 其他
        { coord = 64456426, template = "barber", info = "美容师塔·维兹基" },
        { coord = 64596988, template = "transmog", info = "织幻者塔·奥伦" },
        { coord = 34605652, template = "upgrade", info = "侵攻者佐·达什" },
        { coord = 59237543, template = "stable", info = "守护者塔·沙兰" },
        { coord = 65176755, template = "pet", info = "饲养者塔·希尔特：出售4款宠物[i]珠蜒[/i]/附魔公式[i]心能活化宠物绳[/i]，可制作同名玩具[c]（宠物符咒）[/c]" },
        { coord = 23304897, template = "portaltrainer", info = "传送代理商（仅法师可见）" },
        { coord = 36176413, color = "special", icon = 3257748, text = "格里恩", title = "格里恩", info = "文官阿得赖斯提斯：对话可切换盟约" },
        { coord = 42987418, color = "special", icon = 3257749, text = "◆通灵领主", textA = "RIGHT", title = "通灵领主", info = "剑斗士米维克斯：对话可切换盟约" },
        { coord = 39746089, color = "special", icon = 3257750, text = "法夜", title = "法夜", info = "月莓女勋爵：对话可切换盟约" },
        { coord = 44856895, color = "special", icon = 3257751, text = "温西尔", title = "温西尔", info = "德莱文将军：对话可切换盟约" },
        { coord = 79564985, template = "cinematic", info = "过往撰写师罗-艾德拉布：可观看[i]暗影界的故事[/i]/[i]仲裁官的故事[/i]2段动画" },
        { coord = 41367144, template = "randomraid", info = "塔·艾尔法：纳斯利亚堡/统御圣所/初诞者圣墓" },
        { coord = 47127771, template = "quartermaster", text = "◆四大盟约", textA = "RIGHT", title = "盟约军需官", info = "[n]四大盟约通用商品[/n]\n1款坐骑\n1款宠物\n1款盟约武器附魔幻象\n声望战袍\n职业盟约雕文\n道具[i]深邃机遇容器[/i]：学会所有导灵器并提升物品等级到278[c]（宇宙助溶剂）[/c]\n\n[n]不朽军团军需官[/n]\n达尔·瓦提什：出售以下商品\n工程图纸[i]结构图：虫洞发生器：暗影界[/i]，可制作同名玩具\n2款背部外观\n\n[n]晋升者军需官[/n]\n副官米卡罗丝：出售以下商品\n玩具[i]候选者担架[/i]\n工程图纸[i]结构图：PHA7-YNX型灵豹[/i]，可制作同名宠物\n\n[n]荒猎团军需官[/n]\n莉亚雯：出售以下商品\n铭文工艺图[i]暮光符文牡鹿印记[/i]，可制作德鲁伊旅行形态外观，并在理发店解锁\n1款背部外观[i]法夜纺织背包[/i]\n\n[n]收割者之庭军需官[/n]\n朴素者达尔维：出售以下商品\n玩具[i]罪钒茶具[/i]\n1款背部外观[i]微光金色罪碑锁链[/i]\n\n[n]宣罪军需官[/n]档案员莉昂娜拉：出售以下商品[c]（罪碑碎片）[/c]\n玩具[i]迅捷背诵羽毛笔[/i]/[i]粗俗仲裁者[/i]\n1款背部外观[i]地穴看守者的黝黑斗篷[/i]\n宠物[i]档案员的羽毛笔[/i]" },
        { coord = 35045814, template = "pvp_vendor", info = "[n]争端评估者[/n]\n承销商佐·库尔\n\n[n]争端大师[/n]\n佐·索尔格" },
    },

    -- 奥利波斯：转移之环
    [1671] = {
        group = "Oribos",
        faction = "Neutral",
        { coord = 49565159, template = "portal", text = "噬渊", title = "噬渊", info = "一跃而下",  },
        { coord = 55695158, color = "portal", icon = 450905, text = "下楼", title = "下楼" },
        { coord = 49544236, color = "portal", icon = 450905, text = "下楼", title = "下楼" },
        { coord = 43405158, color = "portal", icon = 450905, text = "下楼", title = "下楼" },
        { coord = 49546079, color = "portal", icon = 450905, text = "下楼", title = "下楼" },
        { coord = 60027110, template = "unique_vendor", text = "◆盟约道具", textA = "RIGHT", title = "传家宝掮灵", info = "奥·达拉：出售以下商品\n\n道具[i]旅行者的心能宝箱[/i]：用于心能转移，可存战团银行[c]（贮藏心能）[/c]\n道具[i]掮灵的卓越印记[/i]：当前盟约直升60级\n道具[i]无穷熏香[/i]：学会所有导灵器并提升物品等级到200\n道具[i]时缚沉思[/i]：使一名盟约伙伴直升30级\n玩具[i]侦察地图：深入暗影界[/i]" },
        poiNames = {
            ["前往扎雷殁提斯的传送门"] = { color = "portal", text = "扎雷殁提斯" },
            ["前往刻希亚的传送门"] = { color = "portal", text = "刻希亚" },
        },
    },

    -- 奥利波斯：掮灵之居
    [1672] = {
        group = "Oribos",
        faction = "Neutral",
        { coord = 50304318, template = "unique_vendor", text = "格里伏塔◆", textA = "LEFT", title = "格里伏塔", info = "[a]作者吐槽：很多上千金的灰色时尚小垃圾[/a]" }
    },

    --------------------------------------------------------------------------------
    -- 瓦德拉肯
    --------------------------------------------------------------------------------
    [2112] = {
        group = "Valdrakken",
        faction = "Neutral",
        { coord = 59774169, template = "portal_stormwind", text = "暴风/传送◆", textA = "LEFT", title = "暴风城传送门/传送门训练师", info = "艾蕾苟萨", tags = {"portal", "special"} },
        { coord = 56653831, template = "portal_orgrimmar" },
        { coord = 61953214, template = "portal", text = "顶层", title = "传送到守护巨龙之座顶层平台" },
        { coord = 62675729, template = "portal", text = "◆翡翠梦境", textA = "RIGHT", title = "翡翠梦境传送门" },
        { coord = 26094099, template = "portal", text = "◆荒芜之地", textA = "RIGHT", title = "荒芜之地传送门" },
        { coord = 47994878, template = "inn", info = "玛琳斯" },
        { coord = 72504716, template = "inn", info = "麦拉多尔米" },
        { coord = 43065961, template = "auction" },
        { coord = 57605654, template = "bank" },
        { coord = 15135294, template = "blackmarket", text = "◆黑市入口", textA = "RIGHT", title = "黑市入口（悬崖下方）" },
        { coord = 20184917, template = "blackmarket" },
        -- 专业
        { coord = 36407169, template = "alchemy", info = "康弗拉苟" },
        { coord = 36944663, template = "blacksmithing", info = "塑金者库洛科" },
        { coord = 46514624, template = "cooking", info = "艾鲁苟萨：出售2款[i]高脚杯单手锤外观[/i]" },
        { coord = 31056137, template = "enchanting", info = "索拉苟萨" },
        { coord = 42254863, template = "engineering", info = "克林基克里克·碎轰" },
        { coord = 44827471, template = "fishing", title = "钓鱼训练师/钓鱼商人", info = "[n]钓鱼训练师[/n]\n托克洛\n\n[n]钓鱼商人[/n]\n帕卡克：出售宠物[i]小野鸭[/i][c]（炖煮驼牛腩x1+河畔野餐x1+既定宿命讲干x3）[/c]", tags = {"profession", "vendor"} },
        { coord = 37426835, template = "herbalism", info = "阿格里库斯" },
        { coord = 38847342, template = "inscription", info = "塔伦达拉" },
        { coord = 40806111, template = "jewelcrafting", info = "图鲁拉多米" },
        { coord = 28536086, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n塑皮者科鲁兹\n\n[n]剥皮训练师[/n]\n粗犷的莱拉索尔", type = {"Leatherworking", "Skinning"} },
        { coord = 38905142, template = "mining", info = "潜地者赛基塔" },
        { coord = 32136626, template = "tailoring", info = "寻线者帕克斯\n寻线者弗拉冯" },
        -- 其他
        { coord = 28994858, template = "barber", info = "经营者瓦拉斯塔萨" },
        { coord = 74455606, template = "transmog", info = "织幻者达耶里斯" },
        { coord = 45673825, template = "upgrade", info = "考尔克夏恩" },
        { coord = 45535627, template = "upgrade", info = "库佐尔兹" },
        { coord = 38113773, template = "upgrade", text = "升级/元素◆", textA = "LEFT", title = "物品升级/元素涌流商人", info = "[n]物品升级[/n]\n艾尔扎\n\n[n]元素涌流商人[/n]\n密斯莱莎：出售1款坐骑/2款宠物/各职业[i]狂怒风暴套装和武器外观[/i][c]（元素涌流）[/c]", tags = {"service", "unique"} },
        { coord = 34636155, template = "order", info = "办事员斯卡拉维勒\n首席办事员米姆基·斯普拉洛克\n办事员银掌" },
        { coord = 46747889, template = "stable", info = "凯斯塔兹：出售以下商品\n\n玩具[i]宠物绳[/i]\n宠物[i]吓人的箱子[/i]/[i]滑鳗[/i]\n3款[i]驭空术坐骑外观：青铜之鳞[/i][c]（觉醒秩序x1+巨龙群岛补给x400）[/c]\n3款[i]驭空术坐骑外观：银色和紫色护甲[/i][c]（龙银矿石x20+陆行鸟肌腱x10+巨龙群岛补给x750）[/c]" },
        { coord = 48308293, template = "pet", info = "莱辛德拉" },
        { coord = 74496315, template = "pet", info = "园丁卡玛：出售2款宠物[i]始祖龙[/i][c]（原始熊脊骨x3+巨大而坚硬的股骨x1+巨龙群岛补给x150）[/c]" },
        { coord = 71554961, template = "housing", info = "西尔维拉斯：出售多款巨龙风格家宅装饰[c]（巨龙群岛补给）[/c]" },
        { coord = 31616930, template = "look", info = "加耶拉：出售4款套装外观/1款单手锤外观/6款副手外观[c]（巨龙版本材料+巨龙群岛补给）[/c]" },
        { coord = 36045011, template = "look", info = "[n]武器匠考雷夫[/n]\n出售多款武器外观[c]（巨龙版本材料+巨龙群岛补给）[/c]\n\n[n]铸甲师泰里斯克[/n]\n出售4款头部外观/9款肩部外观[c]（巨龙版本材料+巨龙群岛补给）[/c]\n\n[n]供给商索姆[/n]\n出售1款家宅装饰[i]龙族工匠的熔炉[/i][c]（巨龙群岛补给）[/c]" },
        { coord = 57922427, template = "look", info = "园丁赛留丝：出售4款[i]园艺武器外观[/i][c]（彩虹珍珠x1+巨龙群岛补给x150）[/c]" },
        { coord = 77543868, template = "heirloom", info = "赫雷多穆：出售传家宝装备和武器60-70级升级道具" },
        { coord = 33852769, template = "unique_vendor", title = "首席图书管理员", info = "黎波尔苟：出售法师雕文[i]奥术魔宠雕文[/i]" },
        { coord = 73804552, template = "unique_vendor", text = "青铜锭", title = "古老的青铜锭（绝版）", info = "米莉欧辛：出售坐骑[i]老基格沃斯先生[/i]/多款装备外观[c]（古老的青铜锭）[/c]\n\n[a]作者描述：只有仍然拥有该货币的人才能看到兑换NPC[/a]" },
        { coord = 42804270, template = "unique_vendor", text = "◆血腥硬币", textA = "RIGHT", title = "血腥硬币商人（进门右边墙角）", info = "护战者格雷什：出售玩具[i]恶龙克星的胜利旗帜[/i][c]（血腥硬币）[/c]" },
        { coord = 60264230, template = "cinematic", text = "◆动画", textA = "RIGHT", title = "动画短片（室内上层）", info = "斯托里多米：可观看[i]龙希尔的起源/奈萨里奥的陨落/巨龙的黎明[/i]3段动画" },
        { coord = 25015070, template = "transformation" },
        { coord = 26074003, color = "special", icon = 4638429, text = "圣物", title = "泰坦圣物兑换", info = "索罗缇丝" },
        { coord = 35182464, color = "special", icon = 4638531, text = "神器", title = "远古牢窟神器兑换", info = "莉莉安·明月" },
        { coord = 58163521, template = "quartermaster", text = "◆联军/随机本", textA = "RIGHT", title = "瓦德拉肯联军军需官/随机本", info = "[n]瓦德拉肯联军军需官[/n]\n乌纳托斯：出售多款图纸配方/幻化/宠物/家宅装饰/驭空术坐骑外观[c]（巨龙版本材料+巨龙群岛补给）[/c]\n\n[n]随机本[/n]\n路嘉·寻团：化身巨龙牢窟/亚贝鲁斯，焰影熔炉/阿梅达希尔，梦境之愿", tags = {"quartermaster", "special"} },
        { coord = 35425910, template = "quartermaster", text = "工商", title = "工匠商盟军需官", info = "拉布尔：出售[i]工匠商盟战袍[/i]/多款图纸配方[c]（匠人之勇）[/c]" },
        { coord = 44313653, template = "pvp_vendor", info = "[n]征服军需官[/n]\n卡尔德拉克斯\n\n[n]荣誉军需官[/n]\n赛尔瑟雷克斯\n\n[n]精锐征服军需官[/n]\n格莱莫拉\n\n[n]黑曜争斗者配方[/n]\n扎伊卡·断钢\n\n[n]苍郁争斗者配方[/n]\n米特基·织线\n\n[n]腾龙争斗者配方[/n]\n艾兰尼斯\n\n[n]猩红争斗者配方[/n]\n科加纳尔·焖炉\n\n[n]战争模式军需官[/n]\n战场大师恩博拉斯" },
        { coord = 43823961, template = "dummy" },
        poiNames = {
            ["创新引擎"] = { color = "special", text = "创新引擎" },
        },
    },

    -- 瓦德拉肯：提尔水库
    [2025] = {
        group = "Valdrakken",
        faction = "Neutral",
        { coord = 60675371, template = "catalyst" },
    },

    --------------------------------------------------------------------------------
    -- 多恩诺嘉尔
    --------------------------------------------------------------------------------
    [2339] = {
        group = "Dornogal",
        faction = "Neutral",
        { coord = 41172269, template = "portal", text = "◆卡雷什/暴风", textA = "RIGHT", title = "卡雷什/暴风城传送门" },
        { coord = 38162723, template = "portal_orgrimmar" },
        { coord = 45204722, template = "inn", info = "罗耐什" },
        { coord = 56754720, template = "auction" },
        { coord = 53274426, template = "bank" },
        { coord = 64765260, template = "blackmarket", text = "◆黑市", textA = "RIGHT" },
        -- 专业
        { coord = 47087052, template = "alchemy", info = "塔里格", isIndividual = true },
        { coord = 49066323, template = "blacksmithing", info = "达利恩" },
        { coord = 44194585, template = "cooking", info = "阿索达斯" },
        { coord = 52487135, template = "enchanting", info = "纳嘉德" },
        { coord = 49035608, template = "engineering", info = "热力先知阿赫达斯" },
        { coord = 50492684, template = "fishing", info = "德罗卡" },
        { coord = 44766931, template = "herbalism", info = "阿克丹", isIndividual = true },
        { coord = 48757117, template = "inscription", info = "布里甘", isIndividual = true },
        { coord = 49487081, template = "jewelcrafting", text = "◆珠宝", textA = "RIGHT", info = "马吉尔", isIndividual = true },
        { coord = 54455898, template = "leatherworking", info = "玛尔布" },
        { coord = 53035279, template = "mining", info = "塔里布" },
        { coord = 54455697, template = "skinning", info = "基纳德" },
        { coord = 54516350, template = "tailoring", info = "科塔格" },
        { coord = 47637143, template = "profession_mixed", isAggregate = true },
        -- 其他
        { coord = 58615264, template = "barber", info = "织线者格雷卡" },
        { coord = 58074878, template = "transmog", info = "织幻者戴基兰" },
        { coord = 45245243, template = "transmog", info = "织幻者塔沃克辛" },
        { coord = 44645608, template = "tradingpost", info = "[n]陶妮和怀尔德商栈[/n]\n安蒂·海髯\n\n[n]赞希里商栈[/n]\n忒哈" },
        { coord = 52054200, template = "upgrade", info = "库佐尔兹" },
        { coord = 58055645, template = "order", info = "[n]制造订单[/n]\n办事员格雷塔尔\n\n[n]专业天赋重置[/n]\n达拉·伏罗希[i]（仅限1次）[/i]" },
        { coord = 47864440, template = "delve", info = "雷诺·杰克逊：出售1款宠物/多款地心之战版本地下堡套装和武器外观[c]（共鸣水晶）[/c]" },
        { coord = 55366711, template = "stable", info = "卡尔甘德" },
        { coord = 58506486, template = "pet", info = "埃拉尼：出售5款宠物[c]（抛光的宠物符咒）[/c]" },
        { coord = 52866794, template = "housing", info = "“第二把交椅”袍铎" },
        { coord = 57266084, template = "look", info = "[n]外观商人[/n]\n欧斯迪恩：出售多款套装外观[c]（优先土壳宝石，其次共鸣水晶）[/c]\n\n[n]商人[/n]\n乔里德：出售1款家宅装饰[i]土灵指令之书[/i][c]（共鸣水晶）[/c]" },
        { coord = 62575093, template = "unique_vendor", text = "◆格里伏塔", textA = "RIGHT", offsetY = 5, title = "格里伏塔", info = "出售以下商品\n\n道具[i]始祖龟幸运符[/i]：可传送到库尔提拉斯斯托颂谷地珍宝海岸\n道具[i]灰羽护符[/i]：用来收集灰烬之羽\n材料[i]格里伏塔的耐用抛光粉[/i]：洗去11.0版本制造业装备美化\n珠宝[i]图鉴：立方渎神石[/i]" },
        { coord = 60960530, template = "unique_vendor", text = "变形术", title = "法师变形术秘典", info = "瓦莉拉·萨古纳尔：完成任务可以获得法师[i]变形术秘典：苔绒羱[/i]\n\n[a]作者吐槽：米尔豪斯和瓦莉拉打炉石，衣服裤子都输光了[/a]" },
        { coord = 50015414, template = "catalyst" },
        { coord = 47976789, template = "transformation" },
        { coord = 39102417, template = "quartermaster", text = "多恩议会◆", textA = "LEFT", title = "多恩诺嘉尔议会军需官", info = "审计员巴乌尔兹" },
        { coord = 59825641, template = "quartermaster", text = "◆工商", textA = "RIGHT", title = "工匠商盟军需官", info = "莱伦达尔：出售多款专业图纸配方[c]（匠人之敏）[/c]" },
        { coord = 55237685, template = "pvp_vendor", info = "[n]竞争者的配方[/n]\n霍萨恩\n\n[n]战争模式军需官[/n]\n吉尔德兰：出售玩具[i]炉铸胜利旗帜[/i][c]（血腥硬币）[/c]\n\n[n]荣誉军需官[/n]\n维勒尔德：出售2款家宅装饰[c]（荣誉点数）[/c]\n\n[n]征服军需官[/n]\n拉兰迪[c]（荣耀印记）[/c]" },
        { coord = 59996972, template = "pvp_vendor", text = "◆升级/PVP", textA = "RIGHT", title = "物品升级/PVP商人", info = "[n]物品升级[/n]\n雷多尼尔\n\n[n]精锐征服军需官[/n]\n罗古恩\n\n[n]战争模式补给商人[/n]\n玛尔拉", tags = {"service", "pvp"} },
        { coord = 57677324, template = "dummy" },
        poiNames = {
            ["通往时间流的传送门"] = { color = "portal", text = "时间流" },
            ["通往艾基-卡赫特的传送门"] = { color = "portal", text = "艾基" },
            ["前往海妖岛的飞艇"] = { color = "portal", text = "海妖岛" },
            ["前往安德麦的传送器"] = { color = "portal", text = "安德麦" },
            ["游学者学徒丽丽·风暴烈酒"] = { color = "special", text = "游学" },
            ["重访惊魂幻象"] = { color = "special", text = "惊魂幻象" },
        },
        maplinkNames = {
            ["喧鸣深窟"] = { text = "喧鸣深窟" },
        },
        instanceNames = {
            ["驭雷栖巢"] = { text = "驭雷栖巢" },
        },
    },

    --------------------------------------------------------------------------------
    -- 千丝之城
    --------------------------------------------------------------------------------
    [2213] = {
        group = "CityofThreads",
        faction = "Neutral",
        { coord = 49782190, template = "inn", info = "伊弗加瓦尔" },
        { coord = 57073948, template = "inn", title = "旅店（下层）", info = "遭嫌弃的艾里基" },
        -- 专业
        { coord = 45831356, template = "alchemy", info = "夏尔巴" },
        { coord = 46832256, template = "blacksmithing", text = "锻造/采矿◆", textA = "LEFT", title = "专业训练师", info = "[n]锻造训练师[/n]\n麦尔\n\n[n]采矿训练师[/n]\n不倦的敏泰恩", type = {"Blacksmithing", "Mining"} },
        { coord = 47892464, template = "cooking", info = "调味厨师德鲁克" },
        { coord = 45583449, template = "enchanting", info = "希尔拉菲" },
        { coord = 57493275, template = "engineering", info = "拉兰基" },
        { coord = 51432521, template = "fishing", info = "玛拉克罗兹" },
        { coord = 47271667, template = "herbalism", info = "卡瓦里斯" },
        { coord = 41752648, template = "inscription", info = "奎尔" },
        { coord = 47771942, template = "jewelcrafting", info = "[n]珠宝加工训练师[/n]\n格万罗\n\n[n]珠宝商人[/n]\n阿尔弗斯·瓦拉乌鲁：出售玩具[i]爱蛛者眼镜语[/i][c]（刻基）[/c]" },
        { coord = 43771960, template = "leatherworking", info = "戈什" },
        { coord = 42632048, template = "skinning", info = "法约尼" },
        { coord = 49721742, template = "tailoring", info = "喜丝者瓦利" },
        -- 其他
        { coord = 44211713, template = "pet", info = "巢穴之母马恩提克：出售2款宠物[c]（刻基）[/c]" },
        { coord = 57334587, template = "look", info = "[n]PVP商人[/n]\n阿布克萨：出售PVP装备[c]（至高探洞者的印记）[/c]\n\n[n]套装商人[/n]\n伊普克萨：出售尼鲁巴尔王宫英雄套装[c]（至高探洞者的印记）[/c]\n\n基尔克萨：出售尼鲁巴尔王宫全难度套装[c]（裹网珍玩）[/c]" },
        { coord = 63313823, color = "special", icon = 651601, text = "彩虹茶", title = "向日葵先生的茶（下层）", info = "道具[i]向日葵之茶[/i]：点击桌子上的道具可获得[i]彩虹拖尾特效[/i][c]（需要完成向日葵先生的任务，即可永久饮用）[/c]\n\n[a]作者描述：玩具棱彩装饰同款效果，持续20分钟，使用任意传送都会消失[/a]" },
        { coord = 07833386, color = "delve", icon = 5779390, text = "◆泽克维尔的巢穴", textA = "RIGHT", title = "宿敌地下堡" },
        instanceNames = {
            ["千丝之城"] = { text = "千丝之城" },
            ["艾拉-卡拉，回响之城"] = { text = "回响之城" },
            ["尼鲁巴尔王宫"] = { text = "尼鲁巴尔王宫" },
        },
        delveNames = {
            ["幽暗要塞"] = { text = "幽暗要塞" },
        },
    },

    -- 千丝之城：下层
    [2216] = {
        group = "CityofThreads",
        faction = "Neutral",
        { coord = 49782190, template = "inn", info = "伊弗加瓦尔" },
        { coord = 57073948, template = "inn", title = "旅店（下层）", info = "遭嫌弃的艾里基" },
        -- 专业
        { coord = 45831356, template = "alchemy", info = "夏尔巴" },
        { coord = 46832256, template = "blacksmithing", text = "锻造/采矿◆", textA = "LEFT", title = "专业训练师", info = "[n]锻造训练师[/n]\n麦尔\n\n[n]采矿训练师[/n]\n不倦的敏泰恩", type = {"Blacksmithing", "Mining"} },
        { coord = 47892464, template = "cooking", info = "调味厨师德鲁克" },
        { coord = 45583449, template = "enchanting", info = "希尔拉菲" },
        { coord = 57493275, template = "engineering", info = "拉兰基" },
        { coord = 51432521, template = "fishing", info = "玛拉克罗兹" },
        { coord = 47271667, template = "herbalism", info = "卡瓦里斯" },
        { coord = 41752648, template = "inscription", info = "奎尔" },
        { coord = 47771942, template = "jewelcrafting", info = "[n]珠宝加工训练师[/n]\n格万罗\n\n[n]珠宝商人[/n]\n阿尔弗斯·瓦拉乌鲁：出售玩具[i]爱蛛者眼镜语[/i][c]（刻基）[/c]" },
        { coord = 43771960, template = "leatherworking", info = "戈什" },
        { coord = 42632048, template = "skinning", info = "法约尼" },
        { coord = 49721742, template = "tailoring", info = "喜丝者瓦利" },
        -- 其他
        { coord = 44211713, template = "pet", info = "巢穴之母马恩提克：出售2款宠物[c]（刻基）[/c]" },
        { coord = 57334587, template = "look", info = "[n]PVP商人[/n]\n阿布克萨：出售PVP装备[c]（至高探洞者的印记）[/c]\n\n[n]套装商人[/n]\n伊普克萨：出售尼鲁巴尔王宫英雄套装[c]（至高探洞者的印记）[/c]\n\n基尔克萨：出售尼鲁巴尔王宫全难度套装[c]（裹网珍玩）[/c]" },
        { coord = 63313823, color = "special", icon = 651601, text = "彩虹茶", title = "向日葵先生的茶（下层）", info = "道具[i]向日葵之茶[/i]：点击桌子上的道具可获得[i]彩虹拖尾特效[/i][c]（需要完成向日葵先生的任务，即可永久饮用）[/c]\n\n[a]作者描述：玩具棱彩装饰同款效果，持续20分钟，使用任意传送都会消失[/a]" },
        { coord = 07833386, color = "delve", icon = 5779390, text = "◆泽克维尔的巢穴", textA = "RIGHT", title = "宿敌地下堡" },
        instanceNames = {
            ["千丝之城"] = { text = "千丝之城" },
            ["艾拉-卡拉，回响之城"] = { text = "回响之城" },
            ["尼鲁巴尔王宫"] = { text = "尼鲁巴尔王宫" },
        },
        delveNames = {
            ["幽暗要塞"] = { text = "幽暗要塞" },
        },
    },

    --------------------------------------------------------------------------------
    -- 安德麦
    --------------------------------------------------------------------------------
    [2346] = {
        group = "Undermine",
        faction = "Neutral",
        { coord = 17295076, template = "portal", text = "喧鸣", title = "喧鸣深窟深沟钻机", info = "卡莉·爽乘：和NPC对话搭乘钻机通往喧鸣深窟" },
        { coord = 18805221, template = "portal", text = "赞达拉", title = "赞达拉深沟钻机", info = "比格兹·快道：和NPC对话搭乘钻机通往祖达萨的卡亚海滨" },
        { coord = 43575180, template = "inn", text = "功能区", title = "洋际酒店", info = "[n]旅店老板[/n]\n帕克斯·紧身：和NPC对话可体验剧情模式解放安德麦团本尾王\n\n[n]财阀招募员[/n]\n凯蒂·板环：签订每周财阀声望\n\n[n]安德麦财阀声望军需官[/n]\n斯玛克斯·紧身：出售2款坐骑/4款家宅装饰[c]（共鸣水晶）[/c]\n\n[n]套装商人（上层）[/n]\n卡莉·炸桥：出售解放安德麦套装[c]（浮华嵌宝珍玩）[/c]", tags = {"inn", "special", "quartermaster", "vendor"} },
        { coord = 24464486, template = "blackmarket" },
        -- 专业
        { coord = 34097129, template = "fishing", info = "布莱尔·巴斯：出售3款鱼漂玩具和1款家宅装饰[i]锈浊的补丁浴盆[/i][c]（“金”鱼）[/c]", tags = {"profession", "unique"} },
        -- 其他
        { coord = 43268284, template = "mount", info = "斯凯吉特·烬轰：出售3款坐骑[c]（混杂机械件x25）[/c]" },
        { coord = 32128220, template = "pet", info = "克里奇" },
        { coord = 59622725, template = "pet", info = "普雷兹里·斩浪" },
        { coord = 43195047, template = "housing", info = "斯塔克斯·紧身：出售多款安德麦风格家宅装饰" },
        { coord = 24516333, template = "look", info = "格里希特·粗人：出售四大财阀[i]战袍/头部/肩膀外观[/i]，需要签订财阀声望才能购买对应的外观" },
        { coord = 25753814, template = "unique_vendor", text = "可乐罐", title = "S.C.R.A.P.交易", info = "安杰罗·锈桶：出售玩具[i]安德麦补给箱[/i][c]（空卡亚可乐罐）[/c]/2款宠物[c]（典藏卡亚可乐罐）[/c]" },
        { coord = 39152220, template = "quartermaster", text = "锈水", title = "锈水军需官", info = "洛可·笑轰：出售1款坐骑/1款宠物/2款玩具/2款家宅装饰[c]（共鸣水晶）[/c]" },
        { coord = 63431674, template = "quartermaster", text = "黑水", title = "黑水军需官", info = "水手长哈迪：出售1款坐骑/1款宠物/2款玩具/2款家宅装饰[c]（共鸣水晶）[/c]" },
        { coord = 27137257, template = "quartermaster", text = "热砂", title = "热砂军需官", info = "实验室助理拉兹丽：出售1款坐骑/1款宠物/2款玩具/2款家宅装饰[c]（共鸣水晶）[/c]" },
        { coord = 53317272, template = "quartermaster", text = "风险", title = "风险军需官", info = "拆废者薛兹：出售1款坐骑/1款宠物/2款玩具/2款家宅装饰[c]（共鸣水晶）[/c]" },
        { coord = 30743891, template = "quartermaster", text = "暗索", title = "暗索军需官（下水道入口）", info = "希奇·内幕：出售以下商品\n\n道具[i]一箱暗索杂物[/i]：可以开出声望道具[c]（市场研究）[/c]\n外观[i]暗索内幕外套[/i][c]（共鸣水晶）[/c]\n2款家宅装饰[c]（共鸣水晶）[/c]" },
        poiNames = {
            ["前往多恩诺嘉尔的传送器"] = { color = "portal", text = "多恩" },
            ["D.R.I.V.E."] = { color = "special", text = "车辆改装" },
        },
        instanceNames = {
            ["解放安德麦"] = { text = "解放安德麦" },
        },
        delveNames = {
            ["闸板陋巷"] = { text = "闸板陋巷" },
            ["破拆穹顶"] = { text = "破拆穹顶" },
        },
    },

    --------------------------------------------------------------------------------
    -- 塔扎维什
    --------------------------------------------------------------------------------
    [2472] = {
        group = "Tazavesh",
        faction = "Neutral",
        { coord = 50001947, template = "portal", text = "多恩", title = "多恩诺嘉尔地下堡行者总部传送门" },
        { coord = 46845685, template = "portal", text = "相位" },
        { coord = 41442482, template = "inn", info = "巴·奥尔" },
        -- 专业
        { coord = 46021831, template = "cooking", info = "巴·迪巴拉" },
        -- 其他
        { coord = 43012875, template = "transmog", info = "织幻者雅顿" },
        { coord = 47412689, template = "stable", info = "巴·西姆塔尔" },
        { coord = 51865387, template = "toy", info = "管理员威·卡：出售1款宠物/5款玩具" },
        { coord = 54595833, template = "look", info = "掮灵威·贝纳：出售6款[i]花朵副手外观[/i]" },
        { coord = 54315584, template = "unique_vendor", text = "采集", title = "采集兑换", info = "[n]草药兑换[/n]\n欧·米特：兑换卡兹阿加基础草药[c]（幻影蕾/卡雷什莲花）[/c]\n\n[n]矿石兑换[/n]\n欧·米尤兹：兑换卡兹阿加基础矿石[c]（凄棱石/卡雷什共鸣之石）[/c]" },
        { coord = 53195412, template = "unique_vendor", text = "◆书商", textA = "RIGHT", info = "佐·法尔：出售各种[i]一部催人泪下的言情小说[/i]" },
        { coord = 48734142, template = "unique_vendor", text = "◆格里伏塔", textA = "RIGHT", title = "格里伏塔", info = "出售以下商品\n\n道具[i]始祖龟幸运符[/i]：可传送到库尔提拉斯斯托颂谷地珍宝海岸\n道具[i]灰羽护符[/i]：用来收集灰烬之羽\n材料[i]格里伏塔的耐用抛光粉[/i]：洗去11.0版本制造业装备美化\n珠宝[i]图鉴：立方渎神石[/i]" },
        { coord = 49453917, template = "unique_vendor", text = "奸商", info = "塔·莱克斯\n\n[a]作者吐槽：单纯想标记一下，出售万金垃圾[/a]" },
        { coord = 43293549, template = "unique_vendor", text = "奸商", info = "塔·萨姆：出售1款家宅装饰[i]财团收藏家的笼子[/i][c]（共鸣水晶）[/c]\n\n[a]作者吐槽：还出售比另一个奸商更过分的万金垃圾[/a]" },
        { coord = 39992966, template = "quartermaster", text = "升级/托拉斯◆", textA = "LEFT", title = "物品升级/卡雷什托拉斯军需官", info = "[n]物品升级[/n]\n圣物匠赛·德斯\n\n[n]卡雷什托拉斯军需官[/n]\n欧·西里克：出售多款家宅装饰[c]（共鸣水晶）[/c]", tags = {"quartermaster", "service"} },
        poiNames = {
            ["通往多恩诺嘉尔的传送门"] = { color = "portal", text = "多恩" },
        },
        instanceNames = {
            ["塔扎维什，帷纱集市"] = { text = "帷纱集市" },
            ["奥尔达尼生态圆顶"] = { text = "生态园顶" },
        },
        delveNames = {
            ["虚空之锋庇护所"] = { text = "虚空之锋庇护所" },
        },
    },

    --------------------------------------------------------------------------------
    -- 银月城（至暗之夜）
    --------------------------------------------------------------------------------
    [2393] = {
        group = "SilvermoonCityMidnight",
        faction = "Neutral",
        { coord = 56467035, template = "inn", text = "旅店/烹饪◆", textA = "LEFT", title = "旅店/烹饪训练师", info = "[n]旅店老板[/n]\n约维娅\n\n[n]烹饪训练师[/n]\n塞莱恩", tags = {"inn", "profession"} },
        { coord = 66916205, template = "inn", info = "德兰妮尔" },
        { coord = 51097610, template = "auction", title = "拍卖行（下层）" },
        { coord = 67617250, template = "auction" },
        { coord = 50816522, template = "bank" },
        { coord = 72566455, template = "bank" },
        { coord = 51844855, template = "blackmarket" },
        -- 专业
        { coord = 44836038, template = "fishing", info = "德拉森" },
        { coord = 43775129, template = "blacksmithing", info = "波玛尔", isIndividual = true },
        { coord = 47985364, template = "enchanting", text = "附魔◆", textA = "LEFT", info = "多洛索斯", isIndividual = true },
        { coord = 39545100, template = "enchanting", info = "詹娜拉·日冕：可学习制作[i]欢乐幻魅[/i]" },
        { coord = 43535396, template = "engineering", info = "丹文", isIndividual = true },
        { coord = 48305141, template = "herbalism", offsetY = 5, info = "植物学家娜萨兰", isIndividual = true },
        { coord = 47935515, template = "jewelcrafting", info = "埃米恩", isIndividual = true },
        { coord = 43175565, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n塔尔玛\n\n[n]剥皮训练师[/n]\n提恩", type = {"Leatherworking", "Skinning"}, isIndividual = true },
        { coord = 42595286, template = "mining", info = "比利尔", isIndividual = true },
        { coord = 48235415, template = "tailoring", text = "◆裁缝", textA = "RIGHT", info = "贾兰娜", isIndividual = true },
        { coord = 47025187, template = "profession_mixed", text = "◆炼金/铭文", textA = "RIGHT", offsetY = -5, title = "专业训练师", info = "[n]炼金术训练师[/n]\n卡博隆\n\n[n]铭文训练师[/n]\n赞塔希娅", type = {"Alchemy", "Inscription"}, isIndividual = true },
        { coord = 45665227, template = "profession_mixed", text = "专业区", isAggregate = true },
        -- 专业（部落专属）
        { coord = 73297352, template = "alchemy", text = "◆炼金", textA = "RIGHT", info = "奥术师森纳瑟杭", isIndividual = true },
        { coord = 72907155, template = "enchanting", text = "附魔", info = "魔导师艾雷达妮娅", isIndividual = true },
        { coord = 72677383, template = "herbalism", text = "草药", info = "植物学家塔尼安雷尔", isIndividual = true },
        { coord = 73757124, template = "jewelcrafting", text = "◆珠宝", textA = "RIGHT", info = "奥雷妮亚", isIndividual = true },
        { coord = 69808114, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "专业训练师", info = "[n]制皮训练师[/n]\n萨瑟林\n\n[n]剥皮训练师[/n]\n玛斯雷恩", type = {"Leatherworking", "Skinning"}, isIndividual = true },
        { coord = 70708255, template = "mining", info = "塞伦", isIndividual = true },
        { coord = 73377270, template = "tailoring", info = "女裁缝蔻妮·琥珀之光", isIndividual = true },
        { coord = 69538457, template = "profession_mixed", text = "锻造/工程◆", textA = "LEFT", title = "专业训练师", info = "[n]锻造训练师[/n]\n阿拉瑟尔\n\n[n]工程学训练师[/n]\n葛洛莉丝", type = {"Blacksmithing", "Engineering"}, isIndividual = true },
        { coord = 72887271, template = "profession_mixed", text = "专业区", isAggregate = true },
        { coord = 69808114, template = "profession_mixed", text = "专业区", isAggregate = true },
        -- 其他
        { coord = 42257851, template = "barber" },
        { coord = 52865743, template = "transmog", info = "织幻者迪弗尔拉" },
        { coord = 48937812, template = "tradingpost", title = "商栈（上层）", info = "[n]陶妮和怀尔德商栈[/n]\n珊迪·海髯\n\n[n]赞希里商栈[/n]\n扎尔菈妮" },
        { coord = 48656203, template = "upgrade", info = "库佐尔兹" },
        { coord = 45665558, template = "order", text = "功能区", title = "订单/工商/兽栏", isAggregate = true },
        { coord = 45025561, template = "order", text = "订单", title = "制造订单/工匠商盟军需官", info = "[n]制造订单[/n]\n玛尔娜\n\n[n]工匠商盟军需官[/n]\n莱伦达尔：出售多款专业图纸配方[c]（匠人之魄）[/c]", tags = {"service", "quartermaster"}, isIndividual = true },
        { coord = 52557827, template = "delve", text = "◆地下堡/考古", textA = "RIGHT", title = "地下堡行者总部/考古学训练师（上层）", info = "[n]地下堡商人[/n]\n娜蕾迪亚·流光：出售[i]修复的宝匣钥匙[/i]/1款坐骑/1款宠物/1款玩具/1款墓碑外观/多款家宅装饰[c]（晦幽铸币）[/c]\n\n传送师阿斯特兰迪斯：出售1款坐骑/2款玩具/1款墓碑外观/多款家宅装饰[c]（虚光灰岩）[/c]\n\n[n]考古学训练师[/n]\n布菜恩·铜须", tags = {"service", "profession"} },
        { coord = 46355556, template = "stable", info = "塞拉菲娜·血心", isIndividual = true },
        { coord = 27267738, template = "stable", info = "沙尔蕾恩" },
        { coord = 67096610, template = "stable", info = "维奈丝特拉" },
        { coord = 48685038, template = "mount", title = "坐骑商人/宠物商人", info = "沃宁中士：出售2款坐骑/3款宠物，有成就和仪式场地名望限制[c]（虚光灰岩）[/c]", isIndividual = true },
        { coord = 44106278, template = "housing", info = "科伦·霍德拉林/海丝塔·福尔拉斯：出售多款绘画类家宅装饰" },
        { coord = 51175645, template = "housing", info = "丹妮亚·银舌/纳尔·银舌：出售多款家宅装饰" },
        { coord = 52504725, template = "housing", info = "德瑟琳：出售3款家宅装饰[c]（共鸣水晶）[/c]" },
        { coord = 31647667, template = "housing", info = "百变装饰决斗商人：出售多款家宅装饰[c]（虚光灰岩）[/c]" },
        { coord = 47695055, template = "housing", text = "家宅◆", textA = "LEFT", info = "莱阿娜：出售6款家宅装饰[c]（虚光灰岩）[/c]", isIndividual = true },
        { coord = 41726638, template = "look", title = "外观商人/传家宝商人", info = "[n]外观商人[/n]\n安德拉：出售多款套装外观[c]（华服资金）[/c]\n\n[n]传家宝商人[/n]\n附魔师埃罗丁：出售多款传家宝" },
        { coord = 34605180, template = "unique_vendor", title = "夺日者古董（上层）", info = "法苏娜·晴日：出售以下商品\n法师技能[i]神秘宝典：奥术语言[/i]\n法师技能[i]神秘宝典：幻觉[/i]\n法师玩具[i]魔宠石[/i]" },
        { coord = 64457961, template = "unique_vendor", info = "吉娅娜女士：出售多款项链道具\n\n[a]作者描述：格里伏塔女血精灵版[/a]" },
        { coord = 48194908, template = "unique_vendor", text = "仪式场地◆", textA = "LEFT", title = "仪式场地商人", info = "[n]军需官[/n]\n玛尔伦·银翼：出售冒险者和老兵装备宝箱[c]（战地奖赏）[/c]/战地奖赏袋子[c]（暗影微粒）[/c]\n\n[n]外观商人[/n]\n提阿姆·定晨：出售T2重置版换色套装[c]（战地奖赏+虚光灰岩）[/c]/战地奖赏袋子[c]（暗影微粒）[/c]" },
        { coord = 40386492, template = "catalyst" },
        { coord = 70088329, template = "catalyst" },
        { coord = 52187367, template = "transformation", title = "幻形讲坛（上层）" },
        { coord = 69116757, template = "quartermaster", text = "银月城", title = "银月城军需官", info = "女魔导师妮萨拉：出售[i]银月城战袍[/i]" },
        { coord = 36258449, template = "dummy" },
        poiNames = {
            ["传送大厅"] = { color = "portal", text = "传送" },
            ["通往时间流的传送门"] = { color = "portal", text = "时间流" },
            ["通往虚影风暴的传送门"] = { color = "portal", text = "虚影" },
            ["通往哈籁恩达尔的林根之路"] = { color = "portal", text = "哈籁恩" },
            ["游学者学徒丽丽·风暴烈酒"] = { color = "special", text = "游学" },
        },
        maplinkNames = {
            ["征服军需官"] = { color = "pvp", text = "PVP" },
        },
        instanceNames = {
            ["密谋小径"] = { text = "密谋小径" },
        },
        delveNames = {
            ["学府骚动"] = { text = "学府骚动" },
            ["黑暗回廊"] = { text = "黑暗回廊" },
        },
    },

    --------------------------------------------------------------------------------
    -- 暗月马戏团
    --------------------------------------------------------------------------------
    [407] = {
        group = "Darkmoonfaire",
        faction = "Zone",
        { coord = 51232314, template = "portal", text = "回程", title = "回程传送门" },
        { coord = 50569073, template = "portal", text = "回程", title = "回程传送门" },
        { coord = 48086953, template = "mount", info = "兰拉：出售3款坐骑/7款宠物" },
        { coord = 47766478, template = "toy", info = "吉瓦斯·格里加特：出售2款玩具/2款幻化/道具[i]暗月大礼帽[/i]，可获得10%经验和声望加成" },
        { coord = 51497508, template = "look", info = "切斯特：出售1款玩具[i]见鬼的纪念品[/i]/5款[i]贵族外观[/i]" },
        { coord = 47676672, template = "heirloom", title = "传家宝商人/外观商人", info = "[n]传家宝商人[/n]\n迪兰德·晨峰\n\n[n]外观商人[/n]\n巴伦姆/巴伦玛" },
        { coord = 54675867, template = "unique_vendor", text = "门票", title = "过山车门票商人", info = "狄玫：对话购买门票，坐过山车可获得10%经验加成，最高持续1小时" },
        { coord = 50475932, template = "unique_vendor", text = "门票", title = "旋转木马门票商人", info = "狄珂：对话购买门票，坐旋转木马可获得10%经验加成，最高持续1小时" },
        { coord = 36545797, template = "unique_vendor", text = "墨黑药水◆", textA = "LEFT", title = "墨黑药水商人", info = "罗纳·绿齿：出售[i]墨黑药水[/i]，可使周围环境变暗，持续2小时" },
        { coord = 48287194, template = "unique_vendor", text = "烟花", title = "烟花商人", info = "波米·斯巴克：出售多款烟花和玩具[i]XL号烟火小马[/i]" },
        { coord = 52518874, template = "unique_vendor", text = "钓鱼", title = "钓鱼商人", info = "格丽萨·日露：出售1款坐骑/2款宠物/1款玩具/道具[i]暗月火酒[/i][c]（暗月刃喉鱼）[/c]" },
        { coord = 51896092, color = "special", icon = 1392955, text = "考古", title = "考古任务/暗月卡牌兑换", info = "萨杜斯·帕雷教授（考古材料：[i]化石碎片x15[/i]）" },
        { coord = 50536956, color = "special", icon = 1392955, text = "炼金", title = "炼金任务", info = "塞兰妮亚（炼金材料：[i]月莓汁x5[/i]+[i]泡沫饮料x5[/i]）" },
        { coord = 51108206, color = "special", icon = 1392955, text = "锻造", title = "锻造任务", info = "亚布·尼比盖尔（锻造材料：[i]铁砧x1[/i]）" },
        { coord = 52916792, color = "special", icon = 1392955, text = "◆烹饪/钓鱼", textA = "RIGHT", title = "烹饪/钓鱼任务", info = "斯塔姆·雷角（烹饪材料：[i]面粉x5[/i]）" },
        { coord = 53237585, color = "special", icon = 1392955, text = "◆附魔/铭文", textA = "RIGHT", title = "附魔/铭文任务", info = "塞恪（铭文材料：[i]轻羊皮纸x5[/i]）" },
        { coord = 49256079, color = "special", icon = 1392955, text = "工程/制皮/采矿◆", textA = "LEFT", title = "工程/制皮/采矿任务", info = "瑞林（制皮材料：[i]蓝色染料x5[/i]+[i]闪光的小珠[/i]+[i]粗线x5[/i]）" },
        { coord = 55007078, color = "special", icon = 1392955, text = "◆珠宝/草药/剥皮", title = "珠宝/草药/剥皮任务", info = "克洛诺斯", textA = "RIGHT" },
        { coord = 55565500, color = "special", icon = 1392955, text = "裁缝", title = "裁缝任务", info = "萨琳娜·杜洛曼（裁缝材料：[i]红色染料x1[/i]+[i]蓝色染料x1[/i]+[i]粗线x1[/i]）" },
    },

    -- 暗月马戏团：莫高雷入口
    [7] = {
        group = "Darkmoonfaire",
        faction = "Zone",
        { coord = 36843586, color = "portal", icon = 1100023, text = "暗月马戏团", title = "入口传送门（每月一次）", info = "[n]专业任务材料准备[/n]\n考古：[i]化石碎片x15[/i]\n炼金：[i]月莓汁x5[/i]+[i]泡沫饮料x5[/i]\n锻造：[i]铁砧x1[/i]\n烹饪：[i]面粉x5[/i]\n铭文：[i]轻羊皮纸x5[/i]\n制皮：[i]蓝色染料x5[/i]+[i]闪光的小珠x10[/i]+[i]粗线x5[/i]\n裁缝：[i]红色染料x1[/i]+[i]蓝色染料x1[/i]+[i]粗线x1[/i]" }
    },

    -- 暗月马戏团：闪金镇入口
    [37] = {
        group = "Darkmoonfaire",
        faction = "Zone",
        { coord = 41796948, color = "portal", icon = 1100023, text = "暗月马戏团", title = "入口传送门（每月一次）", info = "[n]专业任务材料准备[/n]\n考古：[i]化石碎片x15[/i]\n炼金：[i]月莓汁x5[/i]+[i]泡沫饮料x5[/i]\n锻造：[i]铁砧x1[/i]\n烹饪：[i]面粉x5[/i]\n铭文：[i]轻羊皮纸x5[/i]\n制皮：[i]蓝色染料x5[/i]+[i]闪光的小珠x10[/i]+[i]粗线x5[/i]\n裁缝：[i]红色染料x1[/i]+[i]蓝色染料x1[/i]+[i]粗线x1[/i]" }
    },

    --------------------------------------------------------------------------------
    -- 千禧阈限（当前至暗之夜第2赛季）
    --------------------------------------------------------------------------------
    [2266] = {
        group = "TheTimeways",
        faction = "Zone",
        { coord = 39654857, template = "portal", text = "银月城", title = "银月城传送门" },
        --{ coord = 64524368, template = "portal", text = "通天峰", title = "阿兰卡峰林传送门", info = "通天峰" },
        --{ coord = 74344723, template = "portal", text = "萨隆矿坑", title = "冰冠堡垒传送门", info = "萨隆矿坑" },
        --{ coord = 70447274, template = "portal", text = "艾杰斯亚学院", title = "巨龙群岛传送门", info = "艾杰斯亚学院" },
        --{ coord = 60616928, template = "portal", text = "执政团之座", title = "艾瑞达斯传送门", info = "执政团之座" },
        { coord = 74344723, template = "portal", text = "诸王之眠", title = "穆贾巴山传送门", info = "诸王之眠" },
        { coord = 77296165, template = "portal", text = "红玉新生法池", title = "闪霜战地传送门", info = "红玉新生法池" },
        { coord = 70447274, template = "portal", text = "塞塔里斯神庙", title = "沃顿传送门", info = "塞塔里斯神庙" },
        { coord = 50214660, template = "dummy" },
        { coord = 48215796, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 暗影界
    --------------------------------------------------------------------------------
    -- 兵主之座
    [1698] = {
        group = "Shadowlands",
        faction = "Zone",
        { coord = 56383154, template = "portal", text = "奥利", title = "奥利波斯传送门" },
        { coord = 56463705, template = "portal", text = "造物", title = "六叠的隐居处，造物密院",  },
        { coord = 61603772, template = "portal", text = "锐眼", title = "努拉基尔，锐眼密院" },
        { coord = 62893425, template = "portal", text = "噬渊", title = "噬渊传送门", info = "噬渊通灵领主突袭激活时才通往噬渊" },
        { coord = 61553055, template = "portal", text = "祭仪", title = "埃索拉玛斯，祭仪密院" },
        { coord = 58812311, template = "portal", text = "瞭望台", title = "瞭望台，兵主之座" },
        { coord = 46932996, template = "inn", info = "塔巴尼·夜愿" },
        { coord = 56274805, template = "upgrade", info = "淤肠" },
        { coord = 60984648, template = "look", info = "[n]随机纳斯利亚武器匠[/n]\n麦利萨·绝命\n\n[n]普通纳斯利亚武器匠[/n]\n莫迪斯·艾尔弗森\n\n[n]英雄纳斯利亚武器匠[/n]\n泰亚·塔瑟雷\n\n[n]史诗纳斯利亚武器匠[/n]\n奥迪欧斯·谷欧" },
        { coord = 40452448, color = "special", icon = 237523, text = "符文熔炉◆", textA = "LEFT", title = "符文熔炉" },
        { coord = 52714107, template = "quartermaster", text = "◆通灵领主", textA = "RIGHT", title = "通灵领主军需官", info = "苏·泽泰" },
        { coord = 49689087, template = "dummy" },
        poiNames = {
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    -- 堕罪堡
    [1699] = {
        group = "Shadowlands",
        faction = "Zone",
        { coord = 62532654, template = "portal", text = "◆奥利波斯", textA = "RIGHT", title = "奥利波斯传送门" },
        { coord = 38076045, template = "portal", text = "噬渊", title = "噬渊传送门", info = "噬渊温西尔突袭激活时才可见" },
        { coord = 36324833, template = "portal", icon = 450905, text = "下层", title = "通往下层堕罪堡深渊" },
        { coord = 17846124, template = "portal", icon = 450907, text = "上层", title = "通往上层堕罪堡地表" },
        { coord = 42024849, template = "portal", icon = 450907, text = "上层", title = "堕罪地面飞行蝠", info = "点击蝙蝠可被带到地表" },
        { coord = 66783383, template = "inn", info = "夜幕卫士薇克莱拉" },
        { coord = 71522894, template = "stable", info = "瓦希利卡" },
        { coord = 47656132, template = "unique_vendor", text = "镜面", title = "镜面修复", info = "西蒙妮：出售[i]手工制作的镜面修复工具[/i][c]（注能红宝石x10）[/c]" },
        { coord = 52575249, template = "dummy" },
        { coord = 60185349, template = "dummy" },
        poiNames = {
            ["永恒高台"] = { color = "portal", text = "永恒高台" },
            ["堕傲庄"] = { color = "portal", text = "堕傲庄" },
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    -- 堕罪堡：深渊
    [1700] = {
        group = "Shadowlands",
        faction = "Zone",
        { coord = 71053798, color = "portal", icon = 450907, text = "上层", title = "通往堕罪堡上层" },
        { coord = 73382480, template = "upgrade", info = "凯·耶尔莫" },
        { coord = 53834640, template = "look", title = "随机纳斯利亚武器匠", info = "夜幕卫士杰丝莱莎" },
        { coord = 55385435, template = "look", title = "普通纳斯利亚武器匠", info = "阿法纳斯勋爵" },
        { coord = 45366531, template = "look", title = "英雄纳斯利亚武器匠", info = "纺尸者麦康奈尔" },
        { coord = 40304631, template = "look", title = "史诗纳斯利亚武器匠", info = "沃帕莉雅" },
        { coord = 70652741, template = "quartermaster", text = "堕罪", title = "堕罪军需官", info = "“苍白之刃”格雷戈" },
        poiNames = {
            ["饲育者林地"] = { color = "portal", text = "饲育者林地" },
            ["灾厄林"] = { color = "portal", text = "灾厄林" },
            ["赎罪大厅"] = { color = "portal", text = "赎罪大厅" },
            ["统御要塞"] = { color = "portal", text = "统御要塞" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
        },
    },

    -- 森林之心
    [1701] = {
        group = "Shadowlands",
        faction = "Zone",
        { coord = 51002025, template = "portal", text = "传送", title = "蘑网之环/奥利波斯传送门" },
        { coord = 53763838, template = "portal", icon = 450907, text = "上层", title = "通往森林之心上层华盖" },
        { coord = 54785617, template = "inn", info = "科瓦林" },
        { coord = 46945683, template = "upgrade", info = "工匠大师拉姆达" },
        { coord = 37982463, color = "special", icon = 3586268, text = "变形", title = "灵魂变形", info = "曼恩女士/丘法：和NPC对话可以改变法夜盟约技能灵魂变形的形态外观" },
        { coord = 59483180, template = "quartermaster", text = "◆荒猎团/法夜", textA = "RIGHT", title = "荒猎团/法夜军需官", info = "[n]荒猎团军需官[/n]\n艾丝琳\n\n[n]法夜军需官[/n]\n艾尔雯" },
        { coord = 40038075, template = "dummy" },
        { coord = 53857865, template = "dummy" },
        poiNames = {
            ["女王的温室"] = { color = "portal", text = "女王的温室" },
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    -- 森林之心：树根
    [1702] = {
        group = "Shadowlands",
        faction = "Zone",
        { coord = 59972849, template = "portal", text = "◆奥利波斯", textA = "RIGHT", title = "奥利波斯传送门" },
        { coord = 49445400, template = "look", info = "[n]随机纳斯利亚武器匠[/n]\n耀风\n\n[n]普通纳斯利亚武器匠[/n]\n阿德拉\n\n[n]英雄纳斯利亚武器匠[/n]\n哈尔科斯\n\n[n]史诗纳斯利亚武器匠[/n]\n苏拉努姆" },
        poiNames = {
            ["女王的温室"] = { color = "portal", text = "女王的温室" },
            ["森林之心"] = { color = "portal", text = "森林之心" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    -- 森林之心：蘑网之环
    [1819] = {
        group = "Shadowlands",
        faction = "Zone",
        { coord = 55695013, template = "quartermaster", text = "玛拉斯缪斯◆", textA = "LEFT", title = "玛拉斯缪斯军需官", info = "柯迪纳留斯：出售2款坐骑/3款宠物/2款背部外观/[i]军械：冬脉武器外观[/i]/2款灵魂变形外观任务道具" },
        poiNames = {
            ["前往森林之心"] = { color = "portal", text = "森林之心" },
            ["前往未知深域"] = { color = "portal", text = "未知深域" },
            ["前往塞兹仙林"] = { color = "portal", text = "塞兹仙林" },
            ["前往沉静之林"] = { color = "portal", text = "沉静之林" },
            ["前往长者之地"] = { color = "portal", text = "长者之地" },
            ["前往暮辉林地"] = { color = "portal", text = "暮辉林地" },
            ["前往幽蓝树桩"] = { color = "portal", text = "幽蓝树桩" },
            ["前往生命河床"] = { color = "portal", text = "生命河床" },
            ["前往未知伟域"] = { color = "portal", text = "未知伟域" },
            ["前往森林之缘"] = { color = "portal", text = "森林之缘" },
            ["前往碎心岭"] = { color = "portal", text = "碎心岭" },
            ["前往戈姆之巢"] = { color = "portal", text = "戈姆之巢" },
        },
    },

    -- 极乐堡
    [1707] = {
        group = "Shadowlands",
        faction = "Zone",
        { coord = 48796475, template = "portal", text = "◆奥利波斯", textA = "RIGHT", title = "奥利波斯传送门" },
        { coord = 26353389, template = "inn", title = "旅店（上层）", info = "看护者卡林" },
        { coord = 22793158, template = "stable", title = "兽栏（上层）", info = "野兽照看者克里斯塔" },
        { coord = 31314760, template = "mount", text = "坐骑/宠物◆", textA = "LEFT", title = "坐骑商人/宠物商人（上层）", info = "[n]坐骑商人[/n]\n宾基罗斯：出售5款坐骑[c]（有成就限制）[/c]\n\n[n]宠物商人[/n]\n泽里斯科斯：出售6款宠物[c]（有成就限制）[/c]" },
        { coord = 56538224, template = "look", title = "外观商人（上层）", info = "[n]随机纳斯利亚武器匠[/n]\n凯丽·胡\n\n[n]普通纳斯利亚武器匠[/n]\n阿里修斯\n\n[n]英雄纳斯利亚武器匠[/n]\n供应商普罗索斯\n\n[n]史诗纳斯利亚武器匠[/n]\n战斗大师恩迪欧斯" },
        poiNames = {
            ["传送网络"] = { color = "portal", text = "传送网络" },
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["晋升之路"] = { color = "special", text = "晋升之路" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    -- 极乐堡：羁绊圣所
    [1708] = {
        group = "Shadowlands",
        faction = "Zone",
        { coord = 57373018, template = "upgrade", info = "铸手非罗" },
        { coord = 63363052, template = "quartermaster", text = "格里恩", title = "格里恩军需官", info = "副官伽罗斯" },
        poiNames = {
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["晋升之路"] = { color = "special", text = "晋升之路" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    --------------------------------------------------------------------------------
    -- 卡兹阿加
    --------------------------------------------------------------------------------
    -- 多恩岛
    [2248] = {
        group = "KhazAlgar",
        faction = "Zone",
        maplinkNames = {
            ["喧鸣深窟"] = { text = "喧鸣深窟" },
        },
        instanceNames = {
            ["驭雷栖巢"] = { text = "驭雷栖巢" },
            ["燧酿酒庄"] = { text = "燧酿酒庄" },
        },
        delveNames = {
            ["克莱格瓦之眠"] = { text = "克莱格瓦之眠" },
            ["真菌之愚"] = { text = "真菌之愚" },
            ["地匍矿洞"] = { text = "地匍矿洞" },
        },
    },

    -- 喧鸣深窟
    [2214] = {
        group = "KhazAlgar",
        faction = "Zone",
        { coord = 72957320, template = "portal", icon = 2011121, text = "安德麦", title = "安德麦深沟钻机", info = "斯黛里亚：和NPC对话搭乘钻机通往安德麦" },
        poiNames = {
            ["前往海妖岛的钻探机"] = { color = "portal", text = "海妖岛" },
            ["冈达加兹"] = { color = "quartermaster", text = "邃渊协盟" },
        },
        maplinkNames = {
            ["多恩岛"] = { text = "多恩岛" },
            ["陨圣峪"] = { text = "陨圣峪" },
        },
        instanceNames = {
            ["矶石宝库"] = { text = "矶石宝库" },
            ["暗焰裂口"] = { text = "暗焰裂口" },
            ["水闸行动"] = { text = "水闸行动" },
        },
        delveNames = {
            ["恐惧陷坑"] = { text = "恐惧陷坑" },
            ["水能堡"] = { text = "水能堡" },
            ["九号挖掘场"] = { text = "九号挖掘场" },
        },
    },

    -- 陨圣峪
    [2215] = {
        group = "KhazAlgar",
        faction = "Zone",
        { coord = 39115763, template = "unique_vendor", text = "钓鱼", title = "钓鱼训练师/钓鱼大赛商人", info = "欧兹米特船长：出售外观套装[i]天蓝疏浚者[/i]/多款武器和装备外观/多款烹饪配方[c]（米雷达尔钓鱼大赛印记）[/c]"},
        poiNames = {
            ["米雷达尔"] = { color = "quartermaster", text = "陨圣峪阿拉希人" },
        },
        maplinkNames = {
            ["喧鸣深窟"] = { text = "喧鸣深窟" },
            ["多恩岛"] = { text = "多恩岛" },
        },
        instanceNames = {
            ["圣焰隐修院"] = { text = "圣焰隐修院" },
            ["破晨号"] = { text = "破晨号" },
            ["暗焰裂口"] = { text = "暗焰裂口" },
            ["水闸行动"] = { text = "水闸行动" },
        },
        delveNames = {
            ["夜幕圣所"] = { text = "夜幕圣所" },
            ["无底沉穴"] = { text = "无底沉穴" },
            ["飞掠裂口"] = { text = "飞掠裂口" },
            ["丝菌师洞穴"] = { text = "丝菌师洞穴" },
        },
    },

    -- 艾基-卡赫特
    [2255] = {
        group = "KhazAlgar",
        faction = "Zone",
        { coord = 34097695, color = "delve", icon = 5779390, text = "泽克维尔的巢穴◆", textA = "LEFT", title = "宿敌地下堡" },
        poiNames = {
            ["通往多恩诺嘉尔的传送门"] = { color = "portal", text = "多恩诺嘉尔" },
            ["纺丝者之巢"] = { color = "quartermaster", text = "斩离之丝" },
        },
        instanceNames = {
            ["千丝之城"] = { text = "千丝之城" },
            ["艾拉-卡拉，回响之城"] = { text = "回响之城" },
            ["尼鲁巴尔王宫"] = { text = "尼鲁巴尔王宫" },
        },
        delveNames = {
            ["螺旋织纹"] = { text = "螺旋织纹" },
            ["塔克-雷桑深渊"] = { text = "塔克-雷桑深渊" },
            ["幽暗要塞"] = { text = "幽暗要塞" },
        },
    },

    -- 海妖岛
    [2369] = {
        group = "KhazAlgar",
        faction = "Zone",
        { coord = 68994645, template = "inn", info = "斯尼兹·乱轴" },
        { coord = 71403744, template = "inn", info = "拜伦·奈尔斯图" },
        { coord = 70014863, template = "look", info = "索伊兹：出售坐骑[i]索伊兹的夏古斩浪者[/i]/1款宠物/多款套装外观" },
        { coord = 65734172, template = "look", info = "塔乔里[c]（焰祝之铁）[/c]" },
        { coord = 67933925, template = "look", info = "戴兜帽的供应商[c]（焰祝之铁）[/c]" },
        { coord = 70824024, template = "look", info = "艾琳达·海吉米尔[c]（焰祝之铁）[/c]" },
    },

    -- 卡雷什
    [2371] = {
        group = "KhazAlgar",
        faction = "Zone",
        { coord = 50363630, color = "special", icon = 135752, text = "披风/相位◆", textA = "LEFT", title = "雷什裹布升级员/相位潜行商人", info = "[n]雷什裹布升级员[/n]\n哈希姆：领取披风及披风升级[c]（虚灵丝线）[/c]\n\n[n]相位潜行商人[/n]\n莎德安妮丝：出售多款坐骑/宠物/幻化套装/玩具[c]（无拘钱币）[/c]" },
        { coord = 41972253, template = "look", text = "破袭队", offsetY = -5, info = "[n]异域护甲[/n]\n收购者巴·赛欧姆：出售法力熔炉：欧米伽套装[c]（饥渴虚空珍玩）[/c]\n\n[n]好奇的管理员[/n]\n巴·丘索：出售团本法力熔炉：欧米伽披风外观[c]（织丝兽的流丝官）[/c]\n\n[n]名望军需官[/n]\n佐·图鲁：查看法力熔炉破袭队名望等级\n\n[n]古怪的工程师[/n]\n佐·罗伯：出售法力熔炉：欧米伽武器外观[c]（虚灵精华残缕）[/c]" },
        poiNames = {
            ["通往多恩诺嘉尔的传送门"] = { color = "portal", text = "多恩诺嘉尔" },
            ["塔扎维什，帷纱集市"] = { color = "quartermaster", text = "卡雷什托拉斯" },
        },
        instanceNames = {
            ["塔扎维什，帷纱集市"] = { text = "纬纱集市" },
            ["奥尔达尼生态圆顶"] = { text = "生态园顶" },
            ["法力熔炉：欧米伽"] = { text = "法力熔炉" },
        },
        delveNames = {
            ["档案馆突袭"] = { text = "档案馆突袭" },
            ["虚空之锋庇护所"] = { text = "虚空之锋庇护所" },
        },
    },

    --------------------------------------------------------------------------------
    -- 奎尔萨拉斯
    --------------------------------------------------------------------------------
    -- 奎尔丹纳斯岛
    [2424] = {
        group = "QuelThalas",
        faction = "Zone",
        instanceNames = {
            ["魔导师平台"] = { text = "魔导师平台" },
            ["进军奎尔丹纳斯"] = { text = "进军奎尔丹纳斯" },
        },
        delveNames = {
            ["幻日广场"] = { text = "幻日广场" },
        },
    },

    -- 永歌森林
    [2395] = {
        group = "QuelThalas",
        faction = "Zone",
        { coord = 41907970, color = "special", icon = 4620680, text = "威风", title = "幽灵之爪", info = "掉落[i]威风之爪[/i]/[i]威风皮毛[/i]" },
        { coord = 43474745, template = "quartermaster", text = "银月宫廷", title = "名望军需官", info = "[n]银月宫廷军需官[/n]\n凯瑞斯·善晨：出售2款坐骑/1款宠物/1款玩具/多款套装外观/多款专业图纸配方/多款家宅装饰[c]（虚光灰岩）[/c]\n\n[n]血骑士商人[/n]\n铸甲师金冠\n\n[n]魔导士商人[/n]\n学徒戴尔\n\n[n]远行者商人[/n]\n游侠阿洛隆恩\n\n[n]径巷商贩[/n]\n奈里夫\n\n[n]家宅商人[/n]\n萨斯雷·蓝空：出售多款银月城风格家宅装饰[c]（虚光灰岩）[/c]" },
        instanceNames = {
            ["风行者之塔"] = { text = "风行者之塔" },
        },
        delveNames = {
            ["学府骚动"] = { text = "学府骚动" },
            ["黑暗回廊"] = { text = "黑暗回廊" },
            ["聚影领地"] = { text = "聚影领地" },
            ["阿塔阿曼"] = { text = "阿塔阿曼" },
        },
    },

    -- 永歌森林：仪式场地
    [2594] = {
        group = "QuelThalas",
        faction = "Zone",
        subZoneScale = 0.7,
        { coord = 70004892, template = "pet", title = "宠物蛋", info = "宠物蛋从河流中飘过来，拾取后可获得宠物[i]虚空之触雅鸟[/i]" },
        { coord = 30066306, template = "pet", title = "湿漉漉的巢穴", info = "使用道具[i]湿透的山猫玩具[/i]，可获得宠物[i]虚空腐化的毒鳍龙[/i]" },
        { coord = 15002500, color = "special", text = "海藻", icon = 1323035, title = "冲刷上岸的海藻", info = "[n]8个刷新点随机刷新2个[/n]\n刷出红名怪：概率获得[i]湿透的山猫玩具[/i]\n刷出黄名怪：必定获得坐骑[i]虚触毒鳍龙[/i]" },
        { coord = 65977421, color = "special", text = "海藻", icon = 1323035 },
        { coord = 61987708, color = "special", text = "海藻", icon = 1323035 },
        { coord = 47817204, color = "special", text = "海藻", icon = 1323035 },
        { coord = 40827260, color = "special", text = "海藻", icon = 1323035 },
        { coord = 37986361, color = "special", text = "海藻", icon = 1323035 },
        { coord = 46604595, color = "special", text = "海藻", icon = 1323035 },
        { coord = 50075513, color = "special", text = "海藻", icon = 1323035 },
        { coord = 53405543, color = "special", text = "海藻", icon = 1323035 },
        { coord = 15003000, color = "special", text = "草丛", icon = 1323036, title = "沙沙响的草丛", info = "[n]9个刷新点随机刷新1个[/n]\n刷出的宠物逃跑，获取失败\n刷出的宠物恐惧，可获得宠物[i]虚空之触山猫幼崽[/i]" },
        { coord = 66603711, color = "special", text = "草", icon = 1323036 },
        { coord = 66345246, color = "special", text = "草", icon = 1323036 },
        { coord = 63776551, color = "special", text = "草", icon = 1323036 },
        { coord = 54568036, color = "special", text = "草", icon = 1323036 },
        { coord = 41667987, color = "special", text = "草", icon = 1323036 },
        { coord = 43075786, color = "special", text = "草", icon = 1323036 },
        { coord = 43004963, color = "special", text = "草", icon = 1323036 },
        { coord = 41764969, color = "special", text = "草", icon = 1323036 },
        { coord = 35364494, color = "special", text = "草", icon = 1323036 },

    },

    -- 祖阿曼
    [2437] = {
        group = "QuelThalas",
        faction = "Zone",
        { coord = 47805310, color = "special", icon = 4620680, text = "威风", title = "银鳞", info = "掉落[i]威风之爪[/i]" },
        { coord = 43196925, color = "special", icon = 7491473, text = "祭坛", title = "祝福祭坛", info = "和祝福祭坛交互，可以切换神灵祝福" },
        poiNames = {
            ["阿曼尼扎村"] = { color = "quartermaster", text = "阿曼尼部族" },
        },
        instanceNames = {
            ["迈萨拉洞窟"] = { text = "迈萨拉洞窟" },
            ["纳洛拉克的洞穴"] = { text = "纳洛拉克" },
        },
        delveNames = {
            ["聚影领地"] = { text = "聚影领地" },
            ["阿塔阿曼"] = { text = "阿塔阿曼" },
            ["暮光地穴"] = { text = "暮光地穴" },
        },
    },

    -- 祖阿曼：仪式场地
    [2585] = {
        group = "QuelThalas",
        faction = "Zone",
        subZoneScale = 0.7,
        { coord = 55814964, template = "pet", title = "走失的熊崽", info = "提供食物后获得宠物[i]嘟嘟[/i][c]（赛猪肉x1）[/c]" },
        { coord = 55863841, template = "mount", title = "愤怒的阿曼尼战熊", info = "携带宠物[i]嘟嘟[/i]，击败愤怒的阿曼尼战熊，提供食物后获得坐骑[i]枯木战熊之母[/i][c]（赛猪肉x5）[/c]" },
        { coord = 50654730, template = "mount", title = "虚空腐化的邪鹰", info = "使用旁边树下的[i]错置的仪式蜡烛[/i]修复仪式法阵并启动仪式，击败召唤来的NPC后获得坐骑[i]虚空腐化的邪鹰[/i]" },
        { coord = 49447791, template = "pet", title = "走失的熊崽", info = "骑乘坐骑[i]虚空腐化的邪鹰[/i]后可看到[i]上升气流[/i]，传送到高塔顶部后点击[i]虚空侵染的巢穴[/i]获得宠物[i]虚痕雅鹰[/i]" },
    },

    -- 哈籁恩达尔
    [2413] = {
        group = "QuelThalas",
        faction = "Zone",
        { coord = 49255433, template = "unique_vendor", text = "明光之尘◆", textA = "LEFT", title = "明光之尘商人", info = "养蛾人威塔姆：出售7款武器幻化/2款坐骑/3款家宅装饰[c]（明光之尘）[/c]" },
        { coord = 66704760, color = "special", icon = 4620680, text = "威风", title = "流明之鳍", info = "掉落[i]威风尾翼[/i]" },
        poiNames = {
            ["大巢穴"] = { color = "quartermaster", text = "哈籁提" },
        },
        instanceNames = {
            ["夺目谷"] = { text = "夺目谷" },
            ["梦境裂隙"] = { text = "梦境裂隙" },
            ["孢陨幽境"] = { text = "孢陨幽境" },
        },
        delveNames = {
            ["回忆深沟"] = { text = "回忆深沟" },
            ["憎怨斗坑"] = { text = "憎怨斗坑" },
        },
    },

    -- 哈籁恩达尔：大巢穴
    [2576] = {
        group = "QuelThalas",
        faction = "Zone",
        subZoneScale = 0.7,
        { coord = 61797348, template = "portal", text = "虚影", title = "虚影风暴传送门" },
        { coord = 65436193, template = "inn", info = "尤纳" },
        { coord = 63627386, template = "inscription", info = "鲁卡尔，祖尔阿沙" },
        { coord = 62693439, template = "housing", info = "玛库：出售多款哈籁恩达尔风格家宅装饰" },
        poiNames = {
            ["永歌林根之路"] = { color = "portal", text = "银月城" },
        },
    },

    -- 虚影风暴
    [2405] = {
        group = "QuelThalas",
        faction = "Zone",
        { coord = 33946060, template = "portal", text = "银月城" },
        { coord = 43008300, color = "special", icon = 4620680, text = "究极", title = "虚空飞镰", info = "掉落[i]威风之爪[/i]/[i]威风皮毛[/i]/[i]威风尾翼[/i]" },
        { coord = 54006500, color = "special", icon = 4620680, text = "威风", title = "幽齿", info = "掉落[i]威风之爪[/i]/[i]威风皮毛[/i]" },
        { coord = 52587290, template = "quartermaster", text = "奇点特勤◆", textA = "LEFT", title = "奇点特勤军需官", info = "虚空研究者阿诺曼达尔" },
        poiNames = {
            ["通往银月城和哈籁恩达尔的传送门"] = { color = "portal", text = "银月城/哈籁恩" },
        },
        instanceNames = {
            ["虚空之痕竞技场"] = { text = "虚空之痕竞技场" },
            ["节点希纳斯"] = { text = "节点希纳斯" },
            ["虚影尖塔"] = { text = "虚影尖塔" },
        },
        delveNames = {
            ["影卫营"] = { text = "影卫营" },
            ["戮日圣殿"] = { text = "戮日圣殿" },
            ["磨难高地"] = { text = "磨难高地" },
        },
    },

    -- 虚影风暴：屠戮者高地
    [2444] = {
        group = "QuelThalas",
        faction = "Zone",
        subZoneScale = 0.7,
        instanceNames = {
            ["虚空之痕竞技场"] = { text = "虚空之痕竞技场" },
        },
        delveNames = {
            ["戮日圣殿"] = { text = "戮日圣殿" },
        },
    },

    -- 盘卷蛇岛
    [2512] = {
        group = "QuelThalas",
        faction = "Zone",
        subZoneScale = 1,
        { coord = 69555211, template = "unique_vendor", text = "幽灵", title = "幽灵食物/饮料/药水", info = "[n]幽灵食物商（中）[/n]\n阿塔莱基：出售[i]灵魂嫩芽[/i]，仅在死亡时可用，复活后直接满血\n\n[n]幽灵饮料商（左）[/n]\n马布朱尔：出售[i]来世麦酒[/i]，仅在死亡时可用，让灵魂醉酒\n\n[n]幽灵药水商（右）[/n]\n亚拉米：出售[i]液态亡灵药水[/i]，喝了就死" },
        { coord = 51644978, template = "quartermaster", text = "托卡船长", title = "托卡船长军需官", info = "二副斯拉格斯：出售以下商品\n\n坐骑[i]海栖岛屿巨蛇[/i][c]（盘卷游丝）[/c]\n宠物[i]毒液元素[/i][c]（虚光灰岩）[/c]\n鱼竿[i]盘卷女猎手[/i][c]（虚光灰岩）[/c]：可获得水下呼吸和游泳提速\n3款武器外观/6款家宅装饰/多款专业图纸配方" },
        { coord = 26606480, color = "special", icon = 5764921, text = "逼近的诱变者◆", textA = "LEFT", title = "诅咒狂潮", info = "逼近的诱变者" },
        { coord = 71203150, color = "special", icon = 5764921, text = "◆姆噜咕尔大屠杀", textA = "RIGHT", title = "诅咒狂潮", info = "萨克利索斯" },
        { coord = 67507800, color = "special", icon = 5764921, text = "◆低语沼泽之围", textA = "RIGHT", title = "诅咒狂潮", info = "毒液枪兵奥里卡西" },
        { coord = 47306200, color = "special", icon = 5764921, text = "◆畸形的海兽", textA = "RIGHT", title = "诅咒狂潮", info = "畸形的海兽" },
        { coord = 45502900, color = "special", icon = 5764921, text = "巢母之穴◆", textA = "LEFT", title = "诅咒狂潮", info = "瓦斯提，崇高巢母" },
        poiNames = {
            ["托卡的登陆点"] = { color = "quartermaster", text = "祖尔加拉" },
        },
        maplinkNames = {
            ["阿塔乌特克地窟"] = { text = "下层" },
        },
        instanceNames = {
            ["潮缚石窟"] = { text = "潮缚石窟" },
        },
        delveNames = {
            ["纳拉多尔岛"] = { text = "纳拉多尔岛" },
            ["荣耀之环"] = { text = "荣耀之环" },
            ["毒瀑深渊"] = { text = "毒瀑深渊" },
        },
    },

    -- 盘卷蛇岛：阿塔乌特克地窟
    [2509] = {
        group = "QuelThalas",
        faction = "Zone",
        subZoneScale = 1,
        { coord = 51256261, color = "special", text = "腐蚀祭坛", title = "腐蚀祭坛/腐蚀卷册", info = "和腐蚀祭坛交互，可以获得增益强化能力[c]（精魂腐蚀/腐蚀灵魂）[/c]\n\n[n]烈毒货物[/n]\n艾琳耶的头骨：出售1款坐骑/2款宠物/5款幻化套装/多款家宅装饰/炼金配方[i]液态光泽[/i][c]（腐蚀之币）[/c]\n\n[n]毒液学者[/n]\n艾琳耶：兑换[i]精魂腐蚀[/i][c]（腐蚀之币）[/c]"},
        maplinkNames = {
            ["盘卷蛇岛"] = { text = "上层" },
        },
        instanceNames = {
            ["毒牙祭坛"] = { text = "毒牙祭坛" },
            ["烈毒之渊"] = { text = "烈毒之渊" },
        },
    },
}