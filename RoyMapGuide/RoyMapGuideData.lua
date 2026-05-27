-- ========================================================================================================================
-- 【1】标准地图标记添加格式
-- ========================================================================================================================

-- [地图ID] = {
--     group = "自定义城市英文名称",
--     1.普通标记 >>>>> 自定义标记，标记顺序：portal/inn/official/profession/service/stable/collection/vender/unique/special/quartermaster/pvp
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
-- text = 文本 >>>>> 显示在地图上的文本（如果是专业名称，则混合专业名称顺序优先制造业＞采集业，其次按照专业英文名称顺序从A到Z）
-- textA = 锚点左右偏移 >>>>> 只用于偏移文本text字段，icon不受影响
-- offsetY = 标记上下偏移 >>>>> 用于微调标记上下位置，同时影响text和icon
-- title = 鼠标指向提示内容标题
-- info = 鼠标指向提示内容正文
-- type = 专业分类（独立专业/混合专业） >>>>> 专业分类使用专业独立名称
-- tags = 混合标记分类（非混合专业） >>>>> 按配置顺序先后，专业tags不使用专业独立名称而使用profession
-- isAggregate/isIndividual = 聚合标记/独立标记

-- ========================================================================================================================
-- 【3】动态捕获通用poi/maplink/副本/地下堡标记的标准格式（目前暂时）
-- ========================================================================================================================

-- poiNames = {
--     ["实际poi标记显示的名称"] = { color = "颜色分类", text = "自定义名称" },
-- },

-- maplinkNames = {
--     ["实际maplink标记显示的名称"] = "自定义名称",
-- },

-- instanceNames = {
--     ["实际地下堡显示的名称"] = "自定义名称",
-- },

-- delveNames = {
--     ["实际副本显示的名称"] = "自定义名称",
-- },

-- ========================================================================================================================
-- 标记模板
-- ========================================================================================================================
RoyMapGuide_MAP_DATA_TEMPLATES = {
    -- 传送
    portal = { color = "portal", icon = 237556 },
    portal_stormwind = { color = "portal", icon = 135763, text = "暴风", title = "暴风城传送门" },
    portal_orgrimmar = { color = "portal", icon = 135759, text = "奥格", title = "奥格瑞玛传送门" },
    -- 主要
    inn = { color = "inn", icon = 134414, text = "旅店", title = "旅店" },
    auction = { color = "official", icon = 133784, text = "拍卖", title = "拍卖行" },
    bank = { color = "official", icon = 413587, text = "银行", title = "银行及公会银行" },
    blackmarket = { color = "official", icon = 626190, text = "黑市", title = "黑市首领", info = "郭雅夫人" },
    -- 专业
    profession_mixed = { color = "profession", icon = 1392955, text = "专业区" },
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
    transmog = { color = "service", icon = 133564, text = "幻化", title = "幻化师" },
    tradingpost = { color = "service", icon = 4696085, text = "商栈", title = "商栈" },
    upgrade = { color = "service", icon = 1455684, text = "升级", title = "物品升级" },
    order = { color = "service", icon = 1103069, text = "订单", title = "下达制造订单" },
    stable = { color = "stable", icon = 1769016, text = "兽栏", title = "兽栏" },
    mount = { color = "collection", icon = 413588, text = "坐骑", title = "坐骑商人" },
    pet = { color = "collection", icon = 132599, text = "宠物", title = "宠物商人" },
    toy = { color = "collection", icon = 134505, text = "玩具", title = "玩具商人" },
    housing = { color = "collection", icon = 7449410, text = "家宅", title = "家宅商人" },
    guild = { color = "vendor", icon = 514261, text = "公会", title = "公会商人/注册员/战袍商人" },
    look = { color = "vendor", icon = 1030900, text = "外观", title = "外观商人" },
    heirloom = { color = "vendor", icon = 135360, text = "传家宝", title = "传家宝商人" },
    griftah = { color = "unique", icon = 236456, text = "◆格里伏塔", textA = "RIGHT", title = "绝世宝物商人" },
    portaltrainer = { color = "special", icon = 237556, text = "传送", title = "传送门训练师" },
    cinematic = { color = "special", icon = 1109100, text = "动画", title = "动画短片" },
    randomraid = { color = "special", icon = 397907, text = "排本", title = "排随机本" },
    catalyst = { color = "special", icon = 2000852, text = "化生台", title = "化生台" },
    transformation = { color = "special", icon = 4640486, text = "幻形", title = "幻形讲坛" },
    pvp_vendor = { color = "pvp", icon = 1455894, text = "PVP商人◆", textA = "LEFT", title = "PVP商人" },
    dummy = { color = "pvp", icon = 236179, text = "木桩", title = "木桩" },
}

-- ========================================================================================================================
-- 标记数据库
-- ========================================================================================================================
RoyMapGuide_MAP_DATA = {
    -- =============================================================================
    -- 联盟
    -- =============================================================================
    --------------------------------------------------------------------------------
    -- 暴风城
    --------------------------------------------------------------------------------
    [84] = {
        group = "Stormwind",
        -- 传送
        { coord = 48790858, template = "portal", text = "同盟传送", title = "同盟种族传送门", info = "光铸道标/麦卡贡传送器/暗炉城钻探机/泰洛古斯裂隙\n\n|cFFEE8800作者描述：通过光铸道标传送到维迪卡尔可以看到整个艾泽拉斯星球（放心往前不会掉下去）|r" },
        { coord = 74461834, template = "portal", text = "其他传送门", title = "大地的裂变版本传送门", info = "海加尔山/暮光高地/瓦斯琪尔/奥丹姆/深岩之洲/托尔巴拉德传送门" },
        { coord = 82692959, color = "portal", icon = 135758, text = "◆月光林地", textA = "RIGHT", title = "月光林地传送门", info = "和赛纳里奥使者安亚·碧月对话（|cFF00FF00有海加尔守护者声望需求|r）" },
        { coord = 23875612, color = "portal", icon = 135755, text = "◆达纳苏斯", textA = "RIGHT", title = "达纳苏斯传送门" },
        { coord = 66883441, color = "portal", icon = 132334, text = "◆地铁/搏击", textA = "RIGHT", title = "矿道地铁/搏击俱乐部", info = "乘坐矿道地铁可通往铁炉堡" },
        -- 主要
        { coord = 60397527, template = "inn", title = "旅店（贸易区）", info = "奥里森" },
        { coord = 75685411, template = "inn", title = "旅店（旧城区）", info = "梅根·提尔曼" },
        { coord = 64933194, template = "inn", text = "◆旅店", textA = "RIGHT", title = "旅店（矮人区）", info = "塔格娜·耕石" },
        { coord = 49891572, template = "inn", title = "旅店（大使馆）", info = "莎妮·护界" },
        { coord = 61167080, template = "auction", title = "拍卖行（贸易区）" },
        { coord = 60113221, template = "auction", title = "拍卖行（矮人区）" },
        { coord = 63037883, template = "bank", title = "银行及公会银行（贸易区）" },
        { coord = 64802853, template = "bank", title = "银行及公会银行（矮人区）" },
        -- 专业
        { coord = 55668608, template = "alchemy", info = "莉琳希亚·夜风" },
        { coord = 85822595, template = "archaeology", info = "哈里森·琼斯" },
        { coord = 63673700, template = "blacksmithing", title = "锻造训练师（矮人区）", info = "瑟鲁姆·深炉" },
        { coord = 77285321, template = "cooking", title = "烹饪训练师（旧城区）", info = "斯蒂芬·雷百克" },
        { coord = 50651721, template = "cooking", title = "烹饪训练师（大使馆）", info = "达利娅·穹花" },
        { coord = 52947442, template = "enchanting", title = "附魔训练师（法师区）", info = "鲁坎·考迪尔" },
        { coord = 51211267, template = "enchanting", title = "附魔训练师（大使馆）", info = "艾丽斯塔·黎明之尘" },
        { coord = 62853197, template = "engineering", title = "工程学训练师（矮人区）", info = "利廉姆·火轴" },
        { coord = 54796959, template = "fishing", info = "阿诺德·利兰" },
        { coord = 40846586, template = "herbalism", title = "草药学训练师（雄狮之眠）", info = "莎拉米尔" },
        { coord = 54308411, template = "herbalism", title = "草药学训练师（法师区）", info = "塔尼莎" },
        { coord = 49837482, template = "inscription", info = "卡塔莉娜·斯坦弗" },
        { coord = 63486184, template = "jewelcrafting", info = "特蕾莎·登曼" },
        { coord = 71916264, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "制皮/剥皮训练师", info = "西蒙·坦纳尔/马瑞斯·格兰治", type = {"Leatherworking", "Skinning"} },
        { coord = 59513777, template = "mining", title = "采矿训练师（矮人区）", info = "吉尔曼·石手" },
        { coord = 53088135, template = "tailoring", title = "裁缝训练师（法师区）", info = "乔吉奥·波利罗" },
        { coord = 52011952, template = "tailoring", title = "裁缝训练师（大使馆）", info = "艾维多斯" },
        { coord = 49101237, template = "profession_mixed", text = "锻造/工程/采矿◆", textA = "LEFT", title = "锻造/工程学/采矿训练师（大使馆）", info = "伊莱娅/技师法鲁德/德鲁本·粗臂", type = {"Blacksmithing", "Engineering", "Mining"} },
        -- 其他
        { coord = 61516461, template = "barber", info = "耶利尼克·沙希尔" },
        { coord = 50766074, template = "transmog", title = "幻化师/遗忘传说供应商", info = "织幻者哈沙姆\n搜寻者纳杰德：出售|cFF00FF00丢失的老版本橙装|r" },
        { coord = 51037195, template = "tradingpost", info = "陶妮和怀尔德商栈/宠物幻化处" },
        { coord = 42546050, template = "stable", text = "制皮/兽栏◆", textA = "LEFT", title = "制皮训练师（雄狮之眠）/兽栏", info = "泰龙尼斯/塞丽斯塔", tags = {"profession", "stable"} },
        { coord = 67263767, template = "stable", title = "兽栏（矮人区）", info = "耶诺瓦·石盾" },
        { coord = 53271283, template = "stable", text = "◆兽栏", textA = "RIGHT", title = "兽栏（大使馆）", info = "阿什利·黯叶" },
        { coord = 76926801, template = "mount", info = "凯蒂·斯托克斯：出售人类种族坐骑战马" },
        { coord = 73005952, template = "mount", text = "◆坐骑/商人", textA = "RIGHT", title = "摩托商人/幸运商人", info = "保利：出售坐骑|cFF00FF00勇士的践踏之刃|r\n\n“巧手”雷尼·麦考伊：出售玩具|cFF00FF00波贝的炫彩酱汁|r和幸运相关的道具\n\n|cFFEE8800作者描述：背包内常年放满幸运道具，相信玄学！|r", tags = {"collection", "vendor" } },
        { coord = 69482515, template = "pet", title = "战斗宠物训练师", info = "奥黛丽·伯恩赫普" },
        { coord = 58905274, template = "pet", title = "宠物联盟气球", info = "蔚蔚：完成任务可以获得宠物|cFF00FF00联盟气球|r" },
        { coord = 38096439, template = "toy", title = "玩具旅行者的篝火", info = "对安多哈尔的索拉尔使用/疲倦，可以获得玩具|cFF00FF00旅行者的篝火|r" },
        { coord = 61332268, template = "toy", title = "玩具自拍神器", info = "阿丽尔·闪拍：完成任务可获得玩具|cFF00FF00自拍神器|r" },
        { coord = 56087712, template = "housing", title = "弗雷德里克的奇妙家具", info = "“第二把交椅”袍铎" },
        { coord = 48546877, template = "housing", title = "促销装饰补给", info = "图乌兰：出售1款家宅装饰|cFF00FF00黑暗之门|r" },
        { coord = 49278011, template = "housing", title = "旅行书店", info = "索莉罗：出售2款书本类家宅装饰" },
        { coord = 64157702, template = "guild", info = "塞伊·普雷斯勒/奥德文·拉弗林/瑞贝卡·拉弗林" },
        { coord = 56251731, color = "special", icon = 134156, text = "克罗米", title = "克罗米", info = "切换时间线" },
        { coord = 87673608, color = "special", icon = 894556, text = "◆经验锁定", textA = "RIGHT", title = "经验锁定", info = "贝斯滕" },
        { coord = 75300926, template = "cinematic", info = "克罗米：可观看巨龙之魂副本中|cFF00FF00击败死亡之翼的动画|r" },
        { coord = 49488569, color = "special", icon = 618982, text = "战役", title = "场景战役", info = "档案员托马斯：可体验8.0前夕剧情|cFF00FF00洛丹伦之战|r" },
        { coord = 47888441, color = "special", icon = 132288, text = "变形", title = "变形效果", info = "和大法师纳卡达对话可随机变成一种生物，持续5分钟，支持施法但禁用坐骑，有30分钟变形Debuff" },
        { coord = 67747303, color = "quartermaster", icon = 255150, text = "暴风城", title = "暴风城军需官", info = "骑士队长兰希·莱薇森：出售暴风城战袍和暴风城风格家宅装饰" },
        { coord = 67831704, color = "quartermaster", icon = 255150, text = "土水派", title = "土水派军需官/龙龟饲养员", info = "门徒韩俊：出售土水派熊猫人战袍\n\n老白鼻（左）：出售熊猫人种族坐骑龙龟\n\n对附近的熊猫萌萌使用/love可以获得道具|cFF00FF00竹笋|r，使用后可变身同款熊猫，支持施法" },
        { coord = 76136540, color = "pvp", icon = 413588, text = "PVP坐骑◆", textA = "LEFT", title = "战争坐骑军需官", info = "通灵领主赛普（|cFF4499FF邪气鞍座|r）\n\n卡特尔中尉（|cFF4499FF荣耀印记|r）" },
        { coord = 74756773, template = "pvp_vendor", title = "勇士大厅", info = "克莱特军士长/加克斯宾中尉：出售旧世界PVP装备/武器（|cFF4499FF荣耀印记|r）\n\n军士长贝金斯：出售PVP宝石和2款战袍（|cFF4499FF荣耀印记|r）\n\n崔丝提亚中尉：出售第9赛季残忍角斗士装备和武器（|cFF4499FF荣耀印记|r）\n\n迪格汉默上尉：出售第11赛季灾变角斗士装备和武器（|cFF4499FF荣耀印记|r）\n\n骑士队长杰西卡：出售3款宠物\n\n埃德兰·哈尔辛：出售嗜血角斗士装备（|cFF4499FF荣耀印记|r）\n\n爱丽丝·费雪：出售孵化候选者装备（|cFF4499FF荣誉点数|r）\n\n骑士队长蒂麦尔·塞缇丝：出售第10赛季冷酷角斗士装备和武器（|cFF4499FF荣耀印记|r）\n\n莉莉安娜·恩贝弗斯特：出售荣誉传家宝（|cFF4499FF荣耀印记|r）" },
        { coord = 77826577, color = "pvp", icon = 7449410, text = "◆PVP家宅", textA = "RIGHT", title = "战场装饰专家", info = "莉伊卡：出售多种战场类家宅装饰，有成就限制（|cFF4499FF荣誉点数/荣耀印记|r）" },
        { coord = 78976232, template = "dummy" },
        -- poi
        poiNames = {
            ["前往无畏要塞（北风苔原）的船"] = { color = "portal", text = "北风苔原",  },
            ["前往伯拉勒斯港（提拉加德海峡）的船"] = { color = "portal", text = "伯拉勒斯" },
            ["前往觉醒海岸（巨龙群岛）的船"] = { color = "portal", text = "觉醒海岸" },
            ["暴风城传送大厅"] = { color = "portal", text = "传送大厅" },
        },
        -- 副本
        instanceNames = {
            ["监狱"] = "监狱",
        },
    },

    -- 暴风城：矿道地铁
    [499] = {
        group = "Stormwind",
        { coord = 52324805, color = "portal", icon = 132334, text = "搏击俱乐部", title = "搏击俱乐部", info = "矿道地铁下方入口" },
    },

    -- 暴风城：搏击俱乐部
    [500] = {
        group = "Stormwind",
        { coord = 54202521, color = "quartermaster", icon = 2737713, text = "搏击俱乐部", title = "搏击俱乐部军需官", info = "奎肯布什：出售坐骑/宠物/战袍/衬衣/传家宝/家宅装饰/传送到搏击俱乐部的戒指" },
    },

    --------------------------------------------------------------------------------
    -- 铁炉堡
    --------------------------------------------------------------------------------
    [87] = {
        group = "Ironforge",
        -- 传送
        { coord = 76435115, color = "portal", icon = 132334, text = "地铁", title = "矿道地铁", info = "乘坐矿道地铁可通往暴风城" },
        -- 主要
        { coord = 18125142, template = "inn", info = "洛雷·火酒" },
        { coord = 24817379, template = "auction" },
        { coord = 34986131, template = "bank" },
        -- 专业
        { coord = 66615565, template = "alchemy", info = "塔雷·浆泡" },
        { coord = 75591113, template = "archaeology", info = "学者教授铁裤" },
        { coord = 52494200, template = "blacksmithing", info = "本古斯·深炉" },
        { coord = 60083644, template = "cooking", info = "达瑞尔·瑞克努索" },
        { coord = 68454353, template = "engineering", info = "宾斯匹德" },
        { coord = 55905914, template = "herbalism", info = "雷纳·石枝" },
        { coord = 50782640, template = "jewelcrafting", text = "◆珠宝/采矿", textA = "RIGHT", title = "珠宝加工/采矿训练师", info = "哈尼尔·坚石/吉尔弗拉姆·石趾", type = {"Jewelcrafting", "Mining"} },
        { coord = 40033307, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "制皮/剥皮训练师", info = "费布·钢轴/巴尔萨斯·裂石", type = {"Leatherworking", "Skinning"} },
        { coord = 43142937, template = "tailoring", info = "约莫德:石眉" },
        { coord = 60124535, template = "profession_mixed", text = "◆附魔/铭文", textA = "RIGHT", title = "附魔/铭文训练师", info = "吉布·草须/艾莉丝·布莱里特", type = {"Enchanting", "Inscription"} },
        -- 其他
        { coord = 25954934, template = "barber", info = "贝拉·布拉鲁斯" },
        { coord = 69308361, template = "stable", info = "乌布雷克·火拳" },
        { coord = 76140809, template = "housing", title = "图书馆陈列爱好者", info = "因葛·明视：出售2款书柜类家宅装饰" },
        { coord = 36288582, template = "guild", info = "斯蒂格·赫斯克尔勒/乔多·钢眉/利莎·钢眉" },
        { coord = 74470984, template = "heirloom", text = "传家宝◆", textA = "LEFT", info = "克罗姆·粗臂：出售传家宝/传家宝升级道具/各个地图玩具|cFF00FF00侦查地图|r" },
        { coord = 25500707, template = "portaltrainer", info = "贝尔斯塔弗·风暴之眼" },
        { coord = 54834749, color = "quartermaster", icon = 255148, text = "诺莫瑞根/铁炉堡◆", textA = "LEFT", title = "诺莫瑞根/铁炉堡军需官", info = "工匠大师崔尼：出售诺莫瑞根战袍\n\n石盔上尉：出售铁炉堡战袍和铁炉堡风格家宅装饰" },
        { coord = 58846964, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 达纳苏斯
    --------------------------------------------------------------------------------
    [89] = {
        group = "Darnassus",
        -- 传送
        { coord = 44067849, template = "portal", text = "◆外域/埃索达/传送", textA = "RIGHT", title = "地狱火半岛/埃索达传送门/传送门训练师", info = "埃莉萨·杜马斯", tags = {"portal", "special"} },
        { coord = 37095050, template = "portal", text = "鲁瑟兰村", title = "鲁瑟兰村传送门", info = "走进粉色区域自动传送" },
        -- 主要
        { coord = 48421499, template = "inn", title = "旅店（风嚎橡树）", info = "格温·阿姆斯特" },
        { coord = 62533278, template = "inn", title = "旅店（工匠区）", info = "塞琳尼" },
        { coord = 54875837, template = "auction" },
        { coord = 43615100, template = "bank" },
        -- 专业
        { coord = 53913853, template = "alchemy", info = "安尼希尔" },
        { coord = 42638333, template = "archaeology", info = "隐世者汉蒙" },
        { coord = 57005270, template = "blacksmithing", info = "罗尔夫·卡尔尼尔" },
        { coord = 49883663, template = "cooking", info = "阿雷贡" },
        { coord = 49623237, template = "engineering", text = "◆工程/采矿", textA = "RIGHT", title = "工程学（1楼）/采矿训练师（2楼）", info = "塔娜·伦特危尔/工头佩尔尼奇", type = {"Engineering", "Mining"} },
        { coord = 49126098, template = "fishing", info = "阿斯坦娅" },
        { coord = 49146880, template = "herbalism", info = "菲罗迪恩·唤月" },
        { coord = 53983111, template = "jewelcrafting", info = "艾莎·银露" },
        { coord = 56423101, template = "profession_mixed", text = "◆附魔/铭文", textA = "RIGHT", title = "附魔（1楼）/铭文训练师（2楼）", info = "塔兰丹/芬迪·达金", type = {"Enchanting", "Inscription"} },
        { coord = 60493683, template = "profession_mixed", text = "◆裁缝/制皮/剥皮", textA = "RIGHT", title = "裁缝（1楼）/制皮/剥皮训练师（2楼）", info = "迈里恩/泰龙尼斯/艾拉迪尔", type = {"Tailoring", "Leatherworking", "Skinning"} },
        -- 其他
        { coord = 43172893, template = "stable", info = "阿拉辛" },
        { coord = 64055357, template = "pet", title = "猫头鹰训练师", info = "夏琳奈尔：出售2款宠物|cFF00FF00猫头鹰|r" },
        { coord = 42493260, template = "mount", title = "驯豹人", info = "莱兰奈：出售暗夜精灵种族坐骑猎豹" },
        { coord = 48142179, template = "mount", title = "高山马管理员", info = "阿斯特丽德·长袜：出售2款坐骑|cFF00FF00高山马|r" },
        { coord = 64583811, template = "guild", info = "瓦莉亚·月弓/琳沙娜/沙鲁蒙" },
        { coord = 36164847, color = "quartermaster", icon = 255151, text = "达纳苏斯◆", textA = "LEFT", title = "达纳苏斯军需官", info = "月之女祭司娜萨拉：出售达纳苏斯战袍" },
        { coord = 37134743, color = "quartermaster", icon = 466012, text = "◆吉尔尼斯", textA = "RIGHT", title = "吉尔尼斯军需官", info = "坎德雷勋爵：出售吉尔尼斯战袍和吉尔尼斯风格家宅装饰" },
        { coord = 60485344, template = "dummy" },
        { coord = 60484603, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 埃索达
    --------------------------------------------------------------------------------
    [103] = {
        group = "Exodar",
        -- 传送
        { coord = 48356292, template = "portal_stormwind" },
        -- 主要
        { coord = 59511877, template = "inn", info = "布雷尔" },
        { coord = 63255869, template = "auction" },
        { coord = 45434389, template = "bank" },
        -- 专业
        { coord = 27466284, template = "alchemy", text = "炼金/草药◆", textA = "LEFT", title = "炼金术/草药学训练师", info = "鲁克/塞摩尔汉", type = {"Alchemy", "Herbalism"} },
        { coord = 33646637, template = "archaeology", info = "蒂亚" },
        { coord = 59708777, template = "blacksmithing", text = "◆锻造/采矿", textA = "RIGHT", title = "锻造/采矿训练师", info = "米阿尔/穆亚特", type = {"Blacksmithing", "Mining"} },
        { coord = 55742671, template = "cooking", info = "穆曼" },
        { coord = 54169285, template = "engineering", info = "奥克基尔" },
        { coord = 31951467, template = "fishing", info = "伊雷特" },
        { coord = 44882423, template = "jewelcrafting", info = "法里" },
        { coord = 65667458, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "制皮/剥皮训练师", info = "阿克汉姆/雷米勒", type = {"Leatherworking", "Skinning"} },
        { coord = 64426900, template = "tailoring", info = "雷菲克" },
        { coord = 40183924, template = "profession_mixed", text = "附魔/铭文◆", textA = "LEFT", title = "附魔/铭文训练师", info = "纳霍加/索斯", type = {"Enchanting", "Inscription"} },
        -- 其他
        { coord = 60192521, template = "stable", info = "阿尔泰德" },
        { coord = 30073377, template = "pet", info = "希克斯：出售3款|cFF00FF00蛾子宠物|r" },
        { coord = 53776844, template = "guild", info = "露妮/弗纳姆/伊斯卡" },
        { coord = 45996269, template = "portaltrainer", text = "传送◆", textA = "LEFT", info = "鲁纳尔兰" },
        { coord = 54963722, color = "quartermaster", icon = 255147, text = "埃索达", title = "埃索达军需官", info = "卡杜：出售埃索达战袍" },
        { coord = 23783255, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 吉尔尼斯
    --------------------------------------------------------------------------------
    [218] = {
        group = "Gilneas",
        -- 主要
        { coord = 39006111, template = "inn", info = "格温·阿姆斯特" },
        { coord = 59423774, template = "bank", title = "银行" },
        { coord = 58352756, template = "profession_mixed", text = "专业", title = "全专业技能训练师", info = "杰克·“万金油”·德林顿" },
        -- 其他
        { coord = 35977079, template = "stable", info = "费尼甘·考布勒" },
        { coord = 41903770, color = "special", icon = 463876, text = "管家", title = "格雷迈恩管家", info = "和管家对话后可以使城内所有NPC消失一天" },
        { coord = 33356573, color = "quartermaster", icon = 466012, text = "吉尔尼斯◆", textA = "LEFT", title = "吉尔尼斯军需官", info = "坎德雷勋爵：出售吉尔尼斯战袍和吉尔尼斯风格家宅装饰" },
    },

    --------------------------------------------------------------------------------
    -- 暴风之盾
    --------------------------------------------------------------------------------
    [622] = {
        group = "Stormshield",
        -- 传送
        { coord = 60783792, template = "portal_stormwind" },
        { coord = 36384114, template = "portal", text = "雄狮岗哨◆", textA = "LEFT", title = "雄狮岗哨传送门", info = "通往塔纳安丛林的雄狮岗哨，需要完成任务线才可看到" },
        -- 主要
        { coord = 35707789, template = "inn", info = "加西亚·悦花" },
        { coord = 54056634, template = "auction" },
        { coord = 54684868, template = "bank" },
        -- 专业
        { coord = 37396922, template = "alchemy", text = "炼金/草药◆", textA = "LEFT", title = "炼金术/草药学训练师", info = "贾登·塔斯克/洁·野花", type = {"Alchemy", "Herbalism"} },
        { coord = 49023319, template = "archaeology", title = "考古学训练师/考古碎片", info = "曼达·达洛维\n\n格拉吉斯（左1）：出售以下商品\n\n各种考古碎片，至少考古600（|cFF4499FF修复的遗物|r）\n\n|cFF00FF00德拉诺考古学家的地图|r：随机分布德拉诺挖掘场（需要|cFF00FF00鸦人流亡者|r声望崇拜）\n\n|cFF00FF00德拉诺考古学家的磁石|r：随机传送到德拉诺可用的挖掘场（需要|cFF00FF00鸦人流亡者|r声望崇拜）", tags = {"profession", "vendor"} },
        { coord = 49264640, template = "blacksmithing", info = "艾米·金炉" },
        { coord = 35117616, template = "cooking", info = "埃尔顿·布莱克（旅店老板背后右转向下）" },
        { coord = 56656538, template = "enchanting", info = "比尔·星酒" },
        { coord = 48164047, template = "engineering", info = "希尔达·铜丝" },
        { coord = 55477849, template = "fishing", info = "奥斯汀·温德米尔" },
        { coord = 63163368, template = "inscription", title = "铭文训练师（2楼）", info = "铭文师芝源" },
        { coord = 43483390, template = "jewelcrafting", info = "技师妮希亚" },
        { coord = 52394273, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "制皮/剥皮训练师", info = "吉斯顿·锐羽/游侠兰顿", type = {"Leatherworking", "Skinning"} },
        { coord = 47294364, template = "mining", info = "乔纳斯·链拳" },
        { coord = 51513709, template = "tailoring", info = "约书亚·福斯汀" },
        -- 其他
        { coord = 63113543, template = "transmog", text = "幻化◆", textA = "LEFT", title = "幻化师(1楼)", info = "织幻者沙尔" },
        { coord = 33356486, template = "stable", info = "奥维尔·曼弗雷德" },
        { coord = 29645292, color = "unique", icon = 1001490, text = "图纸", title = "要塞图纸商人", info = "金凯德·加科布" },
        { coord = 48506225, color = "unique", icon = 1061300, text = "水晶", title = "埃匹希斯水晶商人", info = "共有6位，出售坐骑|cFF00FF00苔皮淡水兽|r/要塞追随者合约|cFF00FF00寻晨者鲁卡里斯|r" },
        { coord = 52026358, color = "unique", icon = 618858, text = "挑战", title = "黄金挑战商人（绝版）", info = "挑战者萨维娜\n\n|cFFEE8800作者描述：武器设计非常漂亮，当年错过了好可惜|r" },
        { coord = 63933575, template = "portaltrainer", text = "◆传送", textA = "RIGHT", title = "传送门训练师（2楼）", info = "朱莉亚·瓦吉斯" },
        { coord = 51846136, color = "special", icon = 838813, text = "R币", title = "R币兑换", info = "大法师兰达洛克：出售|cFF00FF00钢化命运印记|r" },
        { coord = 42917786, color = "quartermaster", icon = 1052654, text = "热砂", title = "热砂军需官", info = "加兹瑞克斯·轮锁：出售以下商品\n\n坐骑|cFF00FF00驯养的刀脊野猪|r\n\n宠物|cFF00FF00白色淡水兽幼崽/被捕获的森林幼苗|r" },
        { coord = 46607674, color = "quartermaster", icon = 1048727, text = "主教", title = "主教议会军需官", info = "守备官努瑞姆：出售以下商品\n\n坐骑|cFF00FF00土色岩皮雷象|r\n\n玩具|cFF00FF00永久时光气泡|r\n\n宠物|cFF00FF00德莱尼微型防御者|r\n\n8款家宅装饰（|cFF4499FF要塞物资|r）" },
        { coord = 44537494, color = "quartermaster", icon = 1042646, text = "鸦人", title = "鸦人流亡者军需官", info = "暗影贤者巴考斯：出售以下商品\n\n坐骑|cFF00FF00暗鬃冲锋者|r\n\n宠物|cFF00FF00塞泰之子|r\n\n3款家宅装饰（|cFF4499FF金币+埃匹希斯水晶|r）" },
        { coord = 54771688, color = "quartermaster", icon = 1042294, text = "乌瑞恩", title = "乌瑞恩先锋军军需官", info = "魔导师朗格莱：出售乌瑞恩先锋军战袍/坐骑|cFF00FF00暗鬃冲锋者|r" },
        { coord = 54501872, template = "pvp_vendor", info = "原祖/好战/狂野争斗者/角斗士（|cFF4499FF荣耀印记|r）" },
        { coord = 60731523, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 伯拉勒斯
    --------------------------------------------------------------------------------
    [1161] = {
        group = "Boralus",
        -- 传送
        { coord = 70581713, template = "portal", text = "传送", title = "传送门训练师/暴风城/希利苏斯/纳沙塔尔/埃索达/铁炉堡传送门", info = "伊薇娅·维弗邦德\n\n希利苏斯传送门：需要|cFF00FF00切回当前时间线|r才能看到\n\n纳沙塔尔传送门：需要|cFF00FF00完成主线任务|r才能看到)" },
        -- 主要
        { coord = 74111265, template = "inn", text = "功能区", title = "旅店/幻化师/R币兑换/排随机本", tags = {"inn", "service", "special", "instance"}, isAggregate = true },
        { coord = 74111265, template = "inn", text = "旅店/排本◆", textA = "LEFT", title = "旅店/排随机本", info = "维斯雷·洛克霍德\n\n基库：可排奥迪尔/达萨罗之战/风暴熔炉/永恒王宫/尼奥罗萨，觉醒之城的随机本", tags = {"inn", "special"}, isIndividual = true },
        { coord = 75871756, template = "bank" },
        -- 专业
        { coord = 73450849, template = "profession_mixed", title = "专业训练师", isAggregate = true },
        { coord = 74210654, template = "alchemy", text = "◆炼金", textA = "RIGHT", info = "艾尔里克·沃尔格林", isIndividual = true },
        { coord = 68330848, template = "archaeology", info = "简·哈德森" },
        { coord = 71211067, template = "cooking", info = "“船长”拜伦·梅尔萨克" },
        { coord = 74031155, template = "enchanting", info = "艾米莉·法维瑟", isIndividual = true },
        { coord = 74160558, template = "fishing", info = "阿伦·高尔" },
        { coord = 70310609, template = "herbalism", info = "德克兰·塞纳尔", isIndividual = true },
        { coord = 73340634, template = "inscription", text = "铭文", info = "佐伊·墨轮", isIndividual = true },
        { coord = 75210990, template = "jewelcrafting", info = "萨缪尔·D·科尔顿三世", isIndividual = true },
        { coord = 75481261, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "制皮/剥皮训练师", info = "卡桑德拉·布莱诺/卡米拉·达克斯凯", isIndividual = true },
        { coord = 75220757, template = "mining", info = "米拉·卡波特", isIndividual = true },
        { coord = 76941116, template = "tailoring", text = "◆裁缝/外观", textA = "RIGHT", title = "裁缝训练师/衬衫商人", info = "丹尼尔·布莱维/马文·希普斯柯：出售16款|cFF00FF00衬衫幻化|r", tags = {"profession", "vendor"}, isIndividual = true },
        -- 其他
        { coord = 64602818, template = "barber", info = "特里·罗克菲尔德" },
        { coord = 71581369, color = "service", icon = 133564, text = "◆幻化/R币", textA = "RIGHT", title = "幻化师/R币兑换", info = "织幻者艾基尔\n\n特兹兰：可用金币/职业大厅资源/荣耀印记兑换|cFF00FF00战痕命运印记|r", tags = {"service", "special"}, isIndividual = true },
        { coord = 69601316, template = "stable", info = "莱拉·斯塔福德" },
        { coord = 50934593, template = "pet", info = "达纳·普尔" },
        { coord = 56774707, template = "mount", text = "◆坐骑/家宅", textA = "RIGHT", title = "坐骑商人/船壳为家分销商", info = "狡猾的尼克：出售坐骑|cFF00FF00灰皮恐角龙|r和宠物|cFF00FF00失落的栉龙|r\n\n詹妮·福雷斯特：出售5款家宅装饰（|cFF4499FF战争物资|r）" },
        { coord = 70201476, template = "guild", title = "公会商人/注册员", info = "派瑞·查尔顿/码头侍卫菲恩森" },
        { coord = 66902577, color = "unique", icon = 2565243, text = "勋章", title = "服役勋章兑换", info = "供应商烈炉：出售以下商品（|cFF4499FF第七军团服役勋章|r）\n\n|cFF00FF00十地饮剂|r：可提升10%经验（等级不高于49级）\n\n6款传家宝\n\n2款披风幻化\n\n玩具|cFF00FF00掷刃车|r\n\n戒指|cFF00FF00船长的指挥玺戒|r：传送到伯拉勒斯\n\n3款坐骑" },
        { coord = 66053231, color = "unique", icon = 1604167, text = "海岛", title = "达布隆币商人/“打捞”专家", info = "克拉丽莎船长：出售以下商品（|cFF4499FF海员达布隆币|r）\n\n3款帽子幻化\n\n玩具|cFF00FF00手锚/暴躁的螃蟹/瘤木冲浪板|r\n\n宠物|cFF00FF00猩红八爪鱼/白化观暮鸦|r\n\n坐骑|cFF00FF00咸水海马/泥翼信天翁|r\n\n夜奔船长：出售3款打捞品（|cFF4499FF海员达布隆币|r）" },
        { coord = 54337261, color = "unique", icon = 1044996, text = "佩佩", title = "潜水头盔佩佩", info = "凯瑟琳的猫之家，进门左边鱼缸里拾取|cFF00FF00微型潜水盔|r" },
        { coord = 77181647, color = "special", icon = 2437249, text = "拆解", title = "自动拆解机1000型" },
        { coord = 67522154, color = "quartermaster", icon = 2012311, text = "海军部", title = "普罗德摩尔海军部军需官", info = "供给官芙蕾：出售以下商品\n\n5款家宅装饰\n\n玩具|cFF00FF00豺狼人标靶木桶|r\n\n坐骑|cFF00FF00海军骏马缰绳/普罗德摩尔观潮狮鹫缰绳|r" },
        { coord = 68972470, color = "quartermaster", icon = 2024072, text = "◆第七军团", textA = "RIGHT", title = "第七军团军需官", info = "守备官嘉兰娜" },
        { coord = 56352603, template = "pvp_vendor", title = "海歌船屋", info = "专业联络人布拉格尼/利丹·古斯塔夫：PVP图纸配方（|cFF4499FF荣耀印记|r）\n\n副指挥官加布里埃尔元帅：旅店/争霸版本3个赛季PVP套装（|cFF4499FF荣耀印记|r）" },
        -- poi
        poiNames = {
            ["前往暴风城的船"] = { color = "portal", text = "暴风" },
        },
        -- 副本
        instanceNames = {
            ["达萨罗之战"] = "达萨罗之战",
            ["围攻伯拉勒斯"] = "围攻",
        },
    },

    --------------------------------------------------------------------------------
    -- 贝拉梅斯
    --------------------------------------------------------------------------------
    [2239] = {
        group = "Belamath",
        -- 传送
        { coord = 55326473, template = "portal", text = "传送门", title = "暴风城/黑海岸/海加尔山/瓦尔莎拉传送门", isAggregate = true },
        { coord = 55326474, template = "portal", text = "传送门", title = "黑海岸/海加尔山/瓦尔莎拉传送门", isIndividual = true },
        { coord = 55466366, template = "portal_stormwind", isIndividual = true },
        -- 主要
        { coord = 48295403, color = "inn", icon = 134414, text = "功能区", title = "旅店/烹饪/附魔训练师/兽栏/家宅商人", tags = {"inn", "profession", "stable", "vendor"}, isAggregate = true },
        { coord = 48135331, color = "inn", icon = 134414, text = "旅店/烹饪/家宅◆", textA = "LEFT", title = "旅店/烹饪训练师/家宅商人", info = "塞琳尼/阿雷贡/艾兰蒂斯：出售7款家宅装饰（|cFF4499FF巨龙群岛补给|r）", tags = {"inn", "profession", "vendor"}, isIndividual = true },
        -- 专业
        { coord = 54646014, template = "profession_mixed", text = "◆专业区", textA = "RIGHT", title = "炼金术/草药学/铭文/制皮/剥皮训练师", isAggregate = true },
        { coord = 47895674, template = "profession_mixed", title = "锻造/珠宝加工/裁缝/采矿训练师", isAggregate = true },
        { coord = 54905941, template = "alchemy", text = "◆炼金/草药", textA = "RIGHT", title = "炼金术/草药学训练师", info = "泰兰希尔/艾什教授", type = {"Alchemy", "Herbalism"}, isIndividual = true },
        { coord = 48545422, template = "enchanting", text = "◆附魔", textA = "RIGHT", info = "附魔师法尔林·树影", isIndividual = true },
        { coord = 52885592, template = "engineering", info = "渡鸦工匠塔里尔" },
        { coord = 48196402, template = "fishing", info = "垂钓者阿斯坦娅" },
        { coord = 54736190, template = "inscription", info = "芬迪·达金", isIndividual = true },
        { coord = 54616047, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "制皮/剥皮训练师", info = "达丽亚娜/耶蕾娜·夜空", isIndividual = true },
        { coord = 48825796, template = "tailoring", info = "埃德尔鲁·夏叶", isIndividual = true },
        { coord = 47895674, template = "profession_mixed", text = "锻造/珠宝/采矿◆", textA = "LEFT", title = "锻造/珠宝加工/采矿训练师", info = "塞兰妮亚/艾莎·银露/帕莉亚蕾", type = {"Blacksmithing", "Jewelcrafting", "Mining"}, isIndividual = true },
        -- 其他
        { coord = 48005436, template = "stable", text = "兽栏◆", textA = "LEFT", info = "阿拉辛", isIndividual = true },
        { coord = 51426602, template = "mount", title = "驯豹人", info = "莱兰奈：出售暗夜精灵种族坐骑猎豹" },
        { coord = 54096082, template = "housing", text = "家宅◆", textA = "LEFT", info = "迈斯林迪尔：出售2款家宅装饰（|cFF4499FF巨龙群岛补给|r）" },
        { coord = 50165924, template = "cinematic", title = "过往先知", info = "女祭司瑟尔德雷：可观看|cFF00FF00贝拉梅斯的建立/伊瑟拉的离别/玛法里奥的归来|r3段动画" },
        { coord = 46507063, color = "quartermaster", icon = 4881291, text = "达纳苏斯◆", textA = "LEFT", title = "达纳苏斯军需官", info = "月之女祭司娜萨拉：出售|cFF00FF00达纳苏斯战袍/披风/月银肩甲装饰品|r和1款家宅装饰（|cFF4499FF巨龙群岛补给|r）" },
        -- poi
        poiNames = {
            ["前往风谷村（吉尔尼斯）的船"] = { color = "portal", text = "吉尔尼斯" },
        },
    },

    -- =============================================================================
    -- 部落
    -- =============================================================================
    --------------------------------------------------------------------------------
    -- 奥格瑞玛
    --------------------------------------------------------------------------------
    [85] = {
        group = "Orgrimmar",
        -- 传送
        { coord = 39955091, template = "portal", icon = 135758, text = "月光林地◆", textA = "LEFT", title = "月光林地传送门", info = "和赛纳里奥使者托尔·黑蹄对话（|cFF00FF00有海加尔守护者声望需求|r）" },
        { coord = 50343738, template = "portal", text = "其他传送门", title = "大地的裂变版本传送门", info = "通往海加尔山/暮光高地/瓦斯琪尔/奥丹姆/深岩之洲的传送门" },
        { coord = 43046470, color = "portal", icon = 135765, text = "雷霆崖", title = "通往雷霆崖的飞艇" },
        { coord = 50755557, color = "portal", icon = 135766, text = "幽暗城", title = "幽暗城传送门" },
        { coord = 70583092, color = "portal", icon = 132334, text = "搏击", title = "搏击俱乐部" },
        { coord = 38117537, color = "portal", icon = 237556, text = "同盟传送", title = "同盟种族传送门", info = "" },
        { coord = 47403926, color = "portal", icon = 462340, text = "托巴", title = "托尔巴拉德传送门" },
        -- 主要
        { coord = 53637877, template = "inn", title = "旅店（力量谷）", info = "格雷什卡" },
        { coord = 32406476, template = "inn", text = "旅店/兽栏/拍卖/银行◆", textA = "LEFT", title = "旅店/兽栏/拍卖/银行（精神谷）", info = "希加姆比/克苏卡(1楼)\n\n拍卖/银行（2楼）", tags = {"inn", "stable", "official"} },
        { coord = 38894864, template = "inn", text = "旅店/兽栏/剥皮/裁缝◆", textA = "LEFT", title = "旅店/裁缝/剥皮训练师/兽栏（智慧谷）", info = "米瓦娜/希瓦希·三羽\n\n雷恩托/伦托", tags = {"inn", "profession", "stable"} },
        { coord = 71304997, template = "inn", title = "旅店（荣誉谷）", info = "努法" },
        { coord = 40828011, template = "inn", text = "旅店/烹饪/草药/克罗米◆", textA = "LEFT", title = "旅店/烹饪/草药训练师/克罗米（大使馆）", info = "缇兹娜·银杯/风苏/林地栽培者卡多斯\n\n克罗米：切换时间线", tags = {"inn", "profession", "special" } },
        { coord = 53987324, template = "auction", title = "拍卖行（力量谷）" },
        { coord = 41674887, template = "auction", title = "拍卖行（智慧谷）" },
        { coord = 66633627, template = "auction", title = "拍卖行（荣誉谷）" },
        { coord = 35857730, template = "auction", title = "拍卖行（大使馆）" },
        { coord = 48838319, template = "bank", title = "银行及公会银行（力量谷）" },
        { coord = 39904629, template = "bank", title = "银行及公会银行（智慧谷）" },
        { coord = 67585259, template = "bank", title = "银行及公会银行（荣誉谷）" },
        -- 专业
        { coord = 55684577, template = "alchemy", info = "耶尔玛克" },
        { coord = 49067056, template = "archaeology", title = "考古学训练师（室内1楼）", info = "贝洛克·辉刃" },
        { coord = 44927771, template = "blacksmithing", text = "◆锻造/采矿", textA = "RIGHT", title = "锻造/采矿训练师（力量谷）", info = "罗格/古恩托", type = {"Blacksmithing", "Mining"} },
        { coord = 40575024, template = "blacksmithing", text = "◆锻造", textA = "RIGHT", title = "锻造训练师（智慧谷）", info = "奥普诺·铁角" },
        { coord = 76523453, template = "blacksmithing", title = "锻造训练师（荣誉谷）", info = "奥克索斯·铁怒/伯古什/萨鲁·钢怒" },
        { coord = 32246967, template = "cooking", title = "烹饪训练师（精神谷）", info = "扎姆沙" },
        { coord = 53504958, template = "enchanting", title = "附魔训练师（下层）（暗巷区）", info = "古丹" },
        { coord = 56845654, template = "engineering", text = "◆工程", textA = "RIGHT", title = "工程学训练师（下层）（暗巷区）", info = "罗克希克" },
        { coord = 37098473, template = "engineering", title = "工程学训练师（大使馆）", info = "“杰克”·帕萨雷克·砸修" },
        { coord = 35176734, template = "fishing", title = "钓鱼训练师（精神谷）", info = "老恩姆贝托" },
        { coord = 66454192, template = "fishing", title = "钓鱼训练师（荣誉谷）", info = "鲁玛克" },
        { coord = 34836285, template = "herbalism", title = "草药学训练师（精神谷）", info = "加迪" },
        { coord = 54295094, template = "herbalism", title = "草药学训练师（上层）（暗巷区）", info = "穆拉加" },
        { coord = 55095587, template = "inscription", title = "铭文训练师（上层）（暗巷区）", info = "内罗格" },
        { coord = 72313491, template = "jewelcrafting", text = "珠宝/采矿◆", textA = "LEFT", title = "珠宝加工/采矿训练师（荣誉谷）", info = "鲁格娜/马卡鲁", type = {"Jewelcrafting", "Mining"} },
        { coord = 60905489, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "制皮/剥皮训练师（暗巷区）", info = "卡洛雷克/苏尔德", type = {"Leatherworking", "Skinning"} },
        { coord = 39038551, template = "mining", title = "采矿训练师（大使馆）", info = "蕾拉·碎石" },
        { coord = 60745913, template = "tailoring", title = "裁缝训练师（暗巷区）", info = "玛加尔" },
        -- 其他
        { coord = 40346060, template = "barber", text = "理发/外观◆", textA = "LEFT", title = "理发店/眼镜外观兑换", info = "贝布莉·科弗库尔\n\n卡尼斯：出售5款|cFF00FF00眼镜外观|r" },
        { coord = 47647448, template = "transmog", title = "幻化师（力量谷）", info = "织幻者祖姆基" },
        { coord = 57926551, template = "transmog", title = "幻化师/遗忘传说供应商（暗巷区）", info = "织幻者杜沙尔\n搜寻者克拉斯：出售|cFF00FF00丢失的老版本橙装|r" },
        { coord = 48837605, template = "tradingpost", info = "赞希里商栈/宠物幻化处" },
        { coord = 38138713, template = "stable", text = "兽栏/裁缝◆", textA = "LEFT", title = "兽栏/裁缝训练师（大使馆）", info = "赫恩·石羽/织魔者奥莉尔", tags = {"stable", "profession"} },
        { coord = 62153527, template = "stable", text = "兽栏/坐骑◆", textA = "LEFT", title = "兽栏/驯狼者（荣誉谷）", info = "姆罗格\n\n奥古纳罗：出售兽人职业坐骑战狼", tags = {"stable", "collection"} },
        { coord = 38067808, template = "mount", title = "三轮摩托商人", info = "卡尔·万金：出售地精种族坐骑三轮摩托" },
        { coord = 47995865, template = "mount", title = "驭风者饲养员", info = "卓卡玛：出售双足飞龙坐骑" },
        { coord = 52555926, template = "pet", title = "战斗宠物训练师", info = "瓦佐克" },
        { coord = 48124686, template = "pet", title = "宠物部落气球", info = "珈珈：完成任务可以获得宠物|cFF00FF00部落气球|r" },
        { coord = 52928900, template = "housing", title = "弗雷德里克的奇妙家具", info = "“第二把交椅”袍铎" },
        { coord = 48378114, template = "housing", title = "促销装饰补给", info = "佳比：出售1款家宅装饰|cFF00FF00黑暗之门|r" },
        { coord = 47148002, template = "guild", info = "古拉姆/乌特伦/伽雷尔" },
        { coord = 48187177, template = "look", text = "外观◆", textA = "LEFT", title = "勇气/正义/传承正义军需官（室外2楼）", info = "杰姆斯瓦兹/贡娜/鲁戈克" },
        { coord = 35786854, template = "portaltrainer", text = "◆传送/铭文", textA = "RIGHT", title = "传送门训练师/铭文训练师（2楼）（精神谷）", info = "观星者吉拉吉/犹尔曼", tags = {"special", "profession"} },
        { coord = 74914326, template = "portaltrainer", title = "传送门训练师（1楼）（荣誉谷）", info = "拉茜丝蕾·金星" },
        { coord = 74274432, color = "special", icon = 894556, text = "经验锁定◆", textA = "LEFT", title = "经验锁定（3楼）", info = "斯拉兹" },
        { coord = 43903941, template = "cinematic", info = "伊萨里奥斯勋爵：可观看巨龙之魂副本中|cFF00FF00击败死亡之翼的动画|r" },
        { coord = 50165844, color = "quartermaster", icon = 236681, text = "声望", title = "奥格瑞玛/暗矛/锈水财阀声望军需官", info = "石头守卫纳尔戈尔：出售奥格瑞玛战袍和1款家宅装饰\n\n勇土乌拉金：出售暗矛战袍\n\n弗里兹·维拉马尔：出售锈水财阀战袍" },
        { coord = 68584025, color = "quartermaster", icon = 255152, text = "火金派", title = "火金派军需官/龙龟饲养员", info = "门徒君思：出售火金派熊猫人战袍\n\n乌龟大师吴玳（对面）：出售熊猫人种族坐骑龙龟\n\n对附近的熊猫洛洛使用/love可获得道具|cFF00FF00魔力竹笋|r，使用后可变身同款熊猫，支持施法" },
        { coord = 41847317, color = "pvp", icon = 413588, text = "PVP坐骑◆", textA = "LEFT", title = "战争坐骑军需官", info = "亡灵卫兵奈萨里安（|cFF4499FF邪气鞍座|r）\n\n狼骑兵波尔克（|cFF4499FF荣耀印记|r）" },
        { coord = 38137120, template = "pvp_vendor", title = "传说大厅", info = "石头守卫扎尔格/一等军士长霍拉麦：出售旧世界PVP装备/武器（|cFF4499FF荣耀印记|r）\n\n卫兵布莱恩·石皮：出售PVP宝石和2款战袍（|cFF4499FF荣耀印记|r）\n\n加尔拉：出售荣誉传家宝（|cFF4499FF荣耀印记|r）\n\n阿妮卡·梅莱:出售孵化候选者装备（|cFF4499FF荣誉点数|r）\n\n洛戈克：出售嗜血角斗士装备（|cFF4499FF荣耀印记|r）\n\n桃丽丝·沃兰休斯：出售第9赛季残忍角斗士装备和武器（|cFF4499FF荣耀印记|r）\n\n血卫士扎尔什：出售第10赛季冷酷角斗士装备和武器（|cFF4499FF荣耀印记|r）\n\n雷角中士：出售第11赛季灾变角斗士装备和武器（|cFF4499FF荣耀印记|r）\n\n军团士兵沃拉迪斯：3款宠物" },
        { coord = 63693285, template = "dummy", title = "木桩（荣誉谷）" },
        { coord = 62174848, template = "dummy", title = "木桩（城墙上）" },
        -- poi
        poiNames = {
            ["前往战歌要塞（北风苔原）的飞艇"] = { color = "portal", text = "北风苔原" },
            ["前往格罗姆高（荆棘谷）的飞艇"] = { color = "portal", text = "荆棘谷" },
            ["前往觉醒海岸（巨龙群岛）的飞艇"] = { color = "portal", text = "觉醒海岸" },
            ["奥格瑞玛传送大厅"] = { color = "portal", text = "传送大厅" },
        },
    },

    [503] = {  -- 奥格瑞玛：搏击俱乐部
        group = "Orgrimmar",
        { coord = 50872916, color = "quartermaster", icon = 2737714, text = "搏击俱乐部", title = "搏击俱乐部军需官", info = "保尔·诺斯：出售坐骑/宠物/战袍/衬衣/传家宝/家宅装饰/传送到搏击俱乐部的戒指" },
    },

    --------------------------------------------------------------------------------
    -- 雷霆崖
    --------------------------------------------------------------------------------
    [88] = {
        group = "ThunderBluff",
        -- 传送
        { coord = 15402567, template = "portal_orgrimmar", title = "通往奥格瑞玛的飞艇" },
        -- 主要
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
        { coord = 28742088, template = "inscription", info = "波什金·哈比德尔（预见之池洞中）" },
        { coord = 34825397, template = "jewelcrafting", info = "娜哈莉·追云者" },
        { coord = 41494256, template = "leatherworking", info = "犹纳" },
        { coord = 34385784, template = "mining", info = "布瑞克·石蹄" },
        { coord = 44454315, template = "skinning", info = "莫兰塔" },
        { coord = 44514533, template = "tailoring", info = "坦帕" },
        -- 其他
        { coord = 45086024, template = "stable", info = "布尔鲁格" },
        { coord = 37446343, template = "guild", info = "兰达·鸣角/克拉姆/瑟拉姆" },
        { coord = 22471690, template = "portaltrainer", info = "比尔吉特·克兰斯顿（预见之池洞中）" },
        { coord = 47045021, color = "quartermaster", icon = 255153, text = "雷霆崖", title = "雷霆崖军需官（圆柱顶层）", info = "卫兵图霍：出售雷霆崖战袍和1款家宅装饰" },
        { coord = 57828317, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 幽暗城
    --------------------------------------------------------------------------------
    [90] = {
        group = "Undercity",
        -- 传送
        { coord = 85271707, color = "portal", icon = 236778, text = "外域", title = "地狱火半岛传送门" },
        -- 主要
        { coord = 67733788, template = "inn", text = "旅店/兽栏◆", textA = "LEFT", title = "旅店/兽栏（上层）", info = "诺曼/安雅·玛尔雷", tags = {"inn", "stable"} },
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
        { coord = 56273687, template = "jewelcrafting", text = "珠宝/采矿◆", textA = "LEFT", title = "珠宝加工/采矿训练师", info = "内勒尔·费恩/布罗姆·基里安", type = {"Jewelcrafting", "Mining"} },
        { coord = 70155918, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "制皮/剥皮训练师", info = "亚瑟·摩尔/基里安·哈根", type = {"Leatherworking", "Skinning"} },
        { coord = 70763072, template = "tailoring", info = "乔瑟夫·格里高利" },
        -- 其他
        { coord = 69974658, template = "barber", text = "理发◆", textA = "LEFT", title = "理发店（上层）", info = "纳兹尼克·苏萨弗" },
        { coord = 69864371, template = "guild", title = "公会商人/注册员/战袍商人（下层）", info = "金·霍恩/克里斯托弗·德库尔/迈瑞尔·普莱森斯" },
        { coord = 78167563, template = "heirloom", info = "艾斯特蕾·根德瑞：出售传家宝/传家宝升级道具/各个地图玩具|cFF00FF00侦查地图|r" },
        { coord = 84151555, template = "portaltrainer", info = "莱克斯顿·莫泰姆" },
        { coord = 63024900, color = "quartermaster", icon = 255236, text = "幽暗城", title = "幽暗城军需官（上层）", info = "多纳尔德·亚当斯上尉：出售幽暗城战袍和2款家宅装饰" },
        { coord = 55221587, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 银月城（燃烧的远征）
    --------------------------------------------------------------------------------
    [110] = {
        group = "SilvermoonCityTBC",
        -- 传送
        { coord = 58551867, template = "portal_orgrimmar" },
        { coord = 49491477, color = "portal", icon = 135766, text = "幽暗城", title = "幽暗城传送宝珠" },
        -- 主要
        { coord = 79475821, template = "inn", title = "旅店（谋杀小径）", info = "维兰德拉" },
        { coord = 67857290, template = "inn", title = "旅店（花园街市）", info = "约维娅" },
        { coord = 92595836, template = "auction", title = "拍卖行（皇家贸易区）" },
        { coord = 60686154, template = "auction", title = "拍卖行（花园街市）" },
        { coord = 89754319, template = "bank" },
        -- 专业
        { coord = 66731678, template = "alchemy", info = "卡博隆" },
        { coord = 81476386, template = "archaeology", info = "埃莱娜拉" },
        { coord = 79403868, template = "blacksmithing", info = "波玛尔" },
        { coord = 69657157, template = "cooking", title = "烹饪训练师（旅店2楼）", info = "塞莱恩" },
        { coord = 77034108, template = "engineering", info = "丹文" },
        { coord = 76236775, template = "fishing", info = "德拉森" },
        { coord = 67421838, template = "herbalism", info = "植物学家娜萨兰" },
        { coord = 90347384, template = "jewelcrafting", info = "卡琳达" },
        { coord = 85028057, template = "leatherworking", text = "◆制皮/剥皮", textA = "RIGHT", title = "制皮/剥皮训练师", info = "莱纳里斯/提恩", type = {"Leatherworking", "Skinning"} },
        { coord = 78904324, template = "mining", info = "比利尔" },
        { coord = 57375009, template = "tailoring", info = "基伦·希斯" },
        { coord = 69712367, template = "profession_mixed", text = "◆附魔/铭文", textA = "RIGHT", title = "附魔/铭文训练师", info = "瑟丹娜/赞塔希娅", type = {"Enchanting", "Inscription"} },
        -- 其他
        { coord = 82713077, template = "stable", info = "沙尔蕾恩" },
        { coord = 78348522, template = "guild", info = "莱莉希亚/坦德莉恩/克雷迪斯" },
        { coord = 58082084, template = "portaltrainer", info = "纳林斯" },
        { coord = 82123758, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 战争之矛
    --------------------------------------------------------------------------------
    [624] = {
        group = "Warspear",
        -- 传送
        { coord = 60805161, template = "portal_orgrimmar" },
        -- 主要
        { coord = 44974323, template = "inn", info = "娜宁·晨光" },
        { coord = 54672562, template = "auction" },
        { coord = 51376191, template = "bank" },
        -- 专业
        { coord = 60952638, template = "alchemy", info = "克里斯托弗·柯西" },
        { coord = 73613118, template = "archaeology", title = "考古学训练师/考古碎片", info = "丽娜·碎轮\n\n瑟卡（墙外）：出售以下商品\n\n各种考古碎片，至少考古600（|cFF4499FF修复的遗物|r）\n\n|cFF00FF00德拉诺考古学家的地图|r：随机分布德拉诺挖掘场（需要|cFF00FF00鸦人流亡者|r声望崇拜）\n\n|cFF00FF00德拉诺考古学家的磁石|r：随机传送到德拉诺可用的挖掘场（需要|cFF00FF00鸦人流亡者|r声望崇拜）", tags = {"profession", "vendor"} },
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
        { coord = 42553642, color = "unique", icon = 1001490, text = "图纸", title = "要塞图纸商人", info = "托格·菲力克辛顿" },
        { coord = 66636426, color = "unique", icon = 1061300, text = "水晶", title = "埃匹希斯水晶商人", info = "共有6位，出售坐骑|cFF00FF00苔皮淡水兽|r/要塞追随者合约|cFF00FF00寻晨者鲁卡里斯|r" },
        { coord = 65295926, color = "unique", icon = 618858, text = "挑战", title = "黄金挑战商人（绝版）", info = "挑战者森弗吉\n\n|cFFEE8800作者描述：武器设计非常漂亮，当年错过了好可惜|r" },
        { coord = 59225019, template = "portaltrainer", info = "萨麦尔·玫刃" },
        { coord = 64196231, color = "special", icon = 838813, text = "R币", title = "R币兑换", info = "命运扭曲者提拉尔：出售|cFF00FF00钢化命运印记|r" },
        { coord = 54006092, color = "quartermaster", icon = 236681, text = "声望", title = "霜狼兽人/鸦人流亡者/热砂军需官", info = "贝斯卡·赤牙：出售以下商品\n\n坐骑|cFF00FF00迅捷霜狼|r\n\n宠物|cFF00FF00霜狼幼崽|r\n\n玩具|cFF00FF00永久冰霜精华|r\n\n鸦语者斯奇加：出售以下商品\n\n坐骑|cFF00FF00暗鬃冲锋者|r\n\n宠物|cFF00FF00塞泰之子|r\n\n3款家宅装饰（|cFF4499FF金币+埃匹希斯水晶|r）\n\n米米·响泡：出售以下商品\n\n坐骑|cFF00FF00驯养的刀脊野猪|r\n\n宠物|cFF00FF00白色淡水兽幼崽/被捕获的森林幼苗|r" },
        { coord = 49165493, color = "quartermaster", icon = 1042727, text = "沃金", title = "沃金之矛军需官", info = "达兹里安：出售沃金之矛战袍/坐骑" },
        { coord = 48585755, template = "pvp_vendor", info = "原祖/好战/狂野争斗者/角斗士（|cFF4499FF荣耀印记|r）" },
        { coord = 69635638, template = "dummy" },
    },

    --------------------------------------------------------------------------------
    -- 达萨罗
    --------------------------------------------------------------------------------
    [1165] = {
        group = "Dazaralor",
        -- 主要
        { coord = 48458796, template = "inn", text = "◆旅店", textA = "RIGHT", title = "旅店（2层）", info = "古克古克\n\n|cFFEE8800作者吐槽：室外是“达萨罗”城市地图，室内是“祖达萨”区域地图，离谱|r" },
        { coord = 52438494, template = "inn", title = "旅店（3层）", info = "无情的希莫" },
        { coord = 34751160, template = "inn", title = "旅店（佐卡罗广场上）", info = "可悲的拉克尔" },
        { coord = 38651627, template = "inn", title = "旅店（佐卡罗广场下）", info = "保镖“铁手伙计”罗茜" },
        { coord = 52631722, template = "inn", title = "旅店（赞枢尔）" },
        -- 专业
        { coord = 43623830, template = "profession_mixed", isAggregate = true },
        { coord = 42223797, template = "alchemy", info = "聪明的库玛莉", isIndividual = true },
        { coord = 43623830, template = "blacksmithing", text = "◆锻造/采矿", textA = "RIGHT", title = "锻造/采矿训练师", info = "掌炉者扎克阿尔/金匠西科特", type = {"Blacksmithing", "Mining"}, isIndividual = true },
        { coord = 52469044, template = "cooking", text = "烹饪◆", textA = "LEFT", title = "烹饪训练师（2层）", info = "豪查" },
        { coord = 38091416, template = "cooking", info = "厨子玛拉" },
        { coord = 47083569, template = "enchanting", title = "附魔训练师（室内）", info = "女附魔师奎妮", isIndividual = true },
        { coord = 50522336, template = "fishing", info = "安静的塔莉" },
        { coord = 42103560, template = "herbalism", info = "贾登·弗拉", isIndividual = true },
        { coord = 42333971, template = "inscription", info = "记载者伽祖尔（工匠平台）", isIndividual = true },
        { coord = 39201745, template = "inscription", info = "托可（佐卡罗广场）" },
        { coord = 47063792, template = "jewelcrafting", title = "珠宝训练师（室内）", info = "瑟舒利", isIndividual = true },
        { coord = 43763466, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "制皮/剥皮训练师（工匠平台）", info = "赞约/“快刀”拉娜", type = {"Leatherworking", "Skinning"}, isIndividual = true },
        { coord = 36551789, template = "tailoring", info = "米力奈·哈吉特" },
        { coord = 44483390, template = "tailoring", info = "耐心的品金", isIndividual = true },
        -- 其他
        { coord = 47358105, template = "barber", title = "理发店（2层）", info = "康纳·响痕" },
        { coord = 54478846, color = "service", icon = 133564, text = "◆幻化/R币", textA = "RIGHT", title = "幻化师/R币兑换（2层）", info = "织幻者哈伊里\n\n祖尔温：可用金币/职业大厅资源/荣耀印记兑换|cFF00FF00战痕命运印记|r", tags = {"service", "special"} },
        { coord = 47968914, template = "stable", title = "兽栏（3层）", info = "驭兽者苏佳妮" },
        { coord = 45773630, template = "stable", title = "兽栏（巨擘封印）", info = "驭兽者卡拉塔克" },
        { coord = 47739166, template = "mount", title = "骆驼商人（2层）", info = "多哥：出售2款坐骑|cFF00FF00骆驼|r（需要|cFF00FF00拉穆卡恒|r声望崇拜）" },
        { coord = 48588709, template = "mount", title = "坐骑商人（3层）", info = "塔路图：出售坐骑|cFF00FF00灰皮恐角龙|r和宠物|cFF00FF00失落的栉龙|r" },
        { coord = 55933236, template = "pet", title = "宠物商人（室内）", info = "快乐的霍罗阿：出售2款玩具和4款宠物" },
        { coord = 45144059, color = "special", icon = 2437249, text = "◆拆解/工程", textA = "RIGHT", title = "拆解大师Mk1型/工程学训练师", tags = {"special", "profession"} },
        { coord = 51229508, color = "unique", icon = 2565244, text = "勋章", title = "服役勋章兑换", info = "供给商穆克拉：出售以下商品（|cFF4499FF荣耀战团服役勋章|r）\n\n|cFF00FF00十地饮剂|r：可提升10%经验（等级不高于49级）\n\n5款传家宝\n\n7款家宅装饰\n\n2款披风幻化\n\n3款坐骑\n\n宠物|cFF00FF00坦基尔|r\n\n玩具|cFF00FF00凋零轰炸者|r\n\n戒指|cFF00FF00指挥官的战斗玺戒|r：传送到达萨罗" },
        { coord = 44479445, color = "unique", icon = 1604167, text = "海岛", title = "达布隆币商人/公海“打捞”专家", info = "泽塔佳船长：出售以下商品（|cFF4499FF海员达布隆币|r）\n\n3款帽子幻化\n\n玩具|cFF00FF00手锚/暴躁的螃蟹/瘤木冲浪板|r\n\n宠物|cFF00FF00猩红八爪鱼/白化观暮鸦|r\n\n坐骑|cFF00FF00咸水海马/泥翼信天翁|r\n\n1款家宅装饰\n\n基特船长：出售3款打捞品（|cFF4499FF海员达布隆币|r）" },
        { coord = 53018994, template = "griftah", title = "绝世宝物商人（3层）", info = "格里伏塔：出售玩具|cFF00FF00赞达拉人像护符|r（|cFF4499FF伪造的拉斯塔哈面具|r）" },
        { coord = 51833502, template = "dummy", title = "木桩（室内）" }
    },

    [1163] = {  -- 达萨罗：巨擘封印
        group = "Dazaralor",
        -- 传送
        { coord = 73796238, color = "portal", icon = 135761, text = "银月城", title = "银月城传送门" },
        { coord = 73786992, color = "portal", icon = 135759, text = "奥格", title = "奥格瑞玛传送门" },
        { coord = 73717743, color = "portal", icon = 135765, text = "雷霆崖", title = "雷霆崖传送门" },
        { coord = 73588541, color = "portal", icon = 236829, text = "希利苏斯", title = "希利苏斯传送门", info = "需要|cFF00FF00切回当前时间线|r才能看到" },
        { coord = 62948538, color = "portal", icon = 3012072, text = "纳沙塔尔", title = "纳沙塔尔传送门", info = "需要|cFF00FF00做主线任务|r才能看到" },
        -- 主要
        { coord = 48757191, template = "inn", info = "“美人”布丽琳" },
        { coord = 30526779, template = "bank", info = "|cFFEE8800作者吐槽：室外是“巨擘封印”地图，室内是“祖达萨”区域地图，直接退了2级，离谱|r" },
        -- 专业
        { coord = 32003112, template = "archaeology", info = "考察者阿勒琳达" },
        -- 其他
        { coord = 66997347, template = "portaltrainer", info = "首席传送师欧库勒斯" },
    },

    [1164] = {  -- 达萨罗：记载者大厅
        group = "Dazaralor",
        -- 专业
        { coord = 28524989, template = "cooking", info = "皇家大厨提萨拉" },
        { coord = 70493300, template = "inscription", info = "记载者基扎尼" },
        -- 其他
        { coord = 54213702, template = "guild", title = "公会商人/注册员", info = "尤拉·天足/克林基利·腐拳" },
        { coord = 67257151, color = "quartermaster", icon = 2015853, text = "◆赞达拉帝国", textA = "RIGHT", title = "赞达拉帝国军需官", info = "纳塔哈卡塔：出售以下商品\n\n玩具|cFF00FF00聚会图腾|r\n\n坐骑|cFF00FF00钴蓝翼手龙缰绳/幽灵飞翼龙的缰绳|r" },
        { coord = 68593071, template = "randomraid", info = "埃浦：可排奥迪尔/达萨罗之战/风暴熔炉/永恒王宫/尼奥罗萨，觉醒之城的随机本" },
    },

    -- =============================================================================
    -- 中立
    -- =============================================================================
    --------------------------------------------------------------------------------
    -- 沙塔斯
    --------------------------------------------------------------------------------
    [111] = {
        group = "Shattrath",
        -- 传送
        { coord = 57234828, template = "portal_stormwind", text = "◆暴风", textA = "RIGHT" },
        { coord = 56814887, template = "portal_orgrimmar", text = "奥格◆", textA = "LEFT" },
        { coord = 48584201, color = "portal", icon = 236806, text = "奎岛", title = "奎尔丹纳斯岛传送门" },
        { coord = 74683144, color = "portal", icon = 4630413, text = "时光之穴◆", textA = "LEFT", title = "时光之穴传送门", info = "和塞菲尔对话（需要|cFF00FF00时光守护者|r声望崇拜）" },
        -- 主要
        { coord = 28294936, template = "inn", title = "旅店（奥尔多）", info = "旅店老板米娜蕾" },
        { coord = 56328155, template = "inn", title = "旅店（占星者）", info = "旅店老板海索恩" },
        { coord = 51192696, template = "auction", title = "拍卖行（奥尔多）" },
        { coord = 56896273, template = "auction", title = "拍卖行（占星者）" },
        { coord = 48092930, template = "bank", title = "银行及公会银行（奥尔多）" },
        { coord = 60176037, template = "bank", title = "银行及公会银行（占星者）" },
        -- 专业
        { coord = 38473015, template = "alchemy", text = "◆炼金/草药", textA = "RIGHT", title = "炼金术/草药学训练师（奥尔多）", info = "炼金师卡恩胡/吉嘉", type = {"Alchemy", "Herbalism"} },
        { coord = 38297097, template = "alchemy", text = "炼金/草药◆", textA = "LEFT", title = "炼金术/草药学训练师（占星者）", info = "埃尔辛/草药学家奥莱拉", type = {"Alchemy", "Herbalism"} },
        { coord = 45632151, template = "alchemy", title = "炼金术训练师（2层）（贫民窟）", info = "罗罗基姆" },
        { coord = 62667033, template = "archaeology", info = "搜寻者波杜鲁" },
        { coord = 69634268, template = "blacksmithing", title = "锻造训练师（贫民窟）", info = "克拉度·利刃/祖拉·熔怒" },
        { coord = 63106837, template = "cooking", info = "杰克·塔博尔" },
        { coord = 36022074, template = "jewelcrafting", title = "珠宝加工训练师（奥尔多上）", info = "哈曼纳尔" },
        { coord = 36034830, template = "jewelcrafting", text = "◆珠宝/采矿", textA = "RIGHT", title = "珠宝加工（奥尔多下）/采矿训练师", info = "奈米哈/弗诺", type = {"Jewelcrafting", "Mining"} },
        { coord = 58527511, template = "jewelcrafting", text = "◆珠宝/采矿", textA = "RIGHT", title = "珠宝加工/采矿训练师（占星者）", info = "吉蕾布莉·银丝/韩里尔", type = {"Jewelcrafting", "Mining"} },
        { coord = 63976590, template = "skinning", title = "剥皮训练师（贫民窟）", info = "塞莫尔" },
        { coord = 37663161, template = "profession_mixed", text = "锻造/工程◆", textA = "LEFT", title = "锻造/工程训练师（奥尔多）", info = "奥努度/技师米希拉", type = {"Blacksmithing", "Engineering"} },
        { coord = 43656509, template = "profession_mixed", text = "◆锻造/工程", textA = "RIGHT", title = "锻造/工程学训练师（占星者）", info = "巴利尔/工程师辛蓓", type = {"Blacksmithing", "Engineering"} },
        { coord = 36294393, template = "profession_mixed", text = "◆附魔/铭文", textA = "RIGHT", title = "附魔/铭文训练师（奥尔多）", info = "苏蕾/记录员利迪欧", type = {"Enchanting", "Inscription"} },
        { coord = 55747451, template = "profession_mixed", text = "附魔/铭文◆", textA = "LEFT", title = "附魔/铭文训练师（占星者）", info = "附魔师安蒂亚拉/抄写员兰罗尔", type = {"Enchanting", "Inscription"} },
        { coord = 67276742, template = "profession_mixed", text = "◆制皮/特殊裁缝", textA = "RIGHT", title = "制皮/暗纹/魔焰/月布裁缝训练师（贫民窟）", info = "达尔玛里/安迪恩·达克斯宾/金吉·斯比维尔/纳丝玛拉·月歌", type = {"Leatherworking", "Tailoring"} },
        { coord = 41006334, template = "profession_mixed", text = "制皮/裁缝/剥皮◆", textA = "LEFT", title = "制皮/裁缝/剥皮训练师（占星者）", info = "戴恩瑞尔/米拉丽丝/伊尔杜", type = {"Leatherworking", "Tailoring", "Skinning"} },
        { coord = 37452724, template = "profession_mixed", text = "制皮/裁缝/剥皮◆", textA = "LEFT", title = "制皮/裁缝/剥皮训练师（奥尔多）", info = "库里姆/编织者欧尔/德雷姆", type = {"Leatherworking", "Tailoring", "Skinning"} },
        { coord = 43998965, template = "profession_mixed", text = "◆专业区", textA = "RIGHT", title = "全专业技能（奥尔多）", info = "每个书柜代表一个专业，可学习外域专业技能和制作外域家宅装饰" },
        -- 其他
        { coord = 28604777, template = "stable", title = "兽栏（奥尔多）", info = "奥尔鲁赫" },
        { coord = 55987999, template = "stable", title = "兽栏（占星者）", info = "伊苏瑞尔" },
        { coord = 23653284, template = "look", title = "套装兑换（奥尔多）", info = "阿苏尔" },
        { coord = 24882688, template = "look", title = "套装兑换（奥尔多）", info = "克尔拉兰" },
        { coord = 42419044, template = "look", title = "套装兑换（占星者）", info = "阿罗迪斯·炎刃" },
        { coord = 44949168, template = "look", title = "套装兑换（占星者）", info = "维恩娜·晨星" },
        { coord = 65656926, template = "griftah" },
        { coord = 75443050, color = "unique", icon = 133786, text = "◆社交名媛", textA = "RIGHT", title = "社交名媛", info = "哈莉丝·西尔顿：出售以下商品\n\n背包|cFF00FF00“巨无霸”背包/便携黑洞|r\n\n2款戒指玩具" },
        { coord = 30773461, color = "quartermaster", icon = 136149, text = "◆印记提交", textA = "RIGHT", title = "圣光护卫者阿德因", info = "提交|cFF00FF00萨格拉斯印记|r" },
        { coord = 45208145, color = "quartermaster", icon = 133378, text = "徽记提交◆", textA = "LEFT", title = "魔导师菲亚琳", info = "提交|cFF00FF00日怒徽记/火翼徽记|r" },
        { coord = 47712575, color = "quartermaster", icon = 236441, text = "奥尔多", title = "奥尔多军需官", info = "恩达尔林" },
        { coord = 60516432, color = "quartermaster", icon = 236449, text = "占星者", title = "占星者军需官", info = "恩努利尔" },
        { coord = 62006882, color = "quartermaster", icon = 463482, text = "贫民窟◆", textA = "LEFT", title = "贫民窟军需官", info = "纳克杜" },
        { coord = 51004171, color = "quartermaster", icon = 135026, text = "◆沙塔尔", textA = "RIGHT", title = "沙塔尔军需官", info = "奥玛多尔" },
    },

    --------------------------------------------------------------------------------
    -- 达拉然（巫妖王之怒）
    --------------------------------------------------------------------------------
    [125] = {
        group = "DalaranWLK",
        -- 传送
        { coord = 40086277, template = "portal_stormwind" },
        { coord = 55332544, template = "portal_orgrimmar", icon = 135759, text = "奥格◆", title = "奥格瑞玛传送门", color = "portal", textA = "LEFT" },
        { coord = 25974419, color = "portal", icon = 1536440, text = "天台", title = "紫罗兰天台传送门", info = "通往紫罗兰城堡顶层的紫罗兰天台" },
        { coord = 35324526, color = "portal", icon = 450906, text = "下水道", title = "下水道入口（左）" },
        { coord = 60214764, color = "portal", icon = 450908, text = "下水道", title = "下水道入口（右）" },
        -- 主要
        { coord = 50253952, template = "inn", title = "旅店（中立）", info = "艾米丝·埃索盖斯" },
        { coord = 44676333, template = "inn", title = "旅店（联盟）", info = "伊丝拉米·轻风" },
        { coord = 65633217, template = "inn", title = "旅店（部落）", info = "兽女乌达" },
        { coord = 38522511, template = "auction", title = "蒸汽动力拍卖师" },
        { coord = 37095479, template = "auction", text = "拍卖/外观◆", textA = "LEFT", title = "蒸汽动力拍卖师/传承正义军需官（银色领地2楼）", info = "布拉斯博特·机钳/5位传承正义军需官", tags = {"official", "vendor"} },
        { coord = 65512345, template = "auction", text = "◆拍卖/外观", textA = "RIGHT", title = "蒸汽动力拍卖师/传承正义军需官", info = "雷加纳德·弧炎/5位传承正义军需官", tags = {"official", "vendor"} },
        { coord = 43977693, template = "bank", title = "银行及公会银行（联盟旁）" },
        { coord = 52861801, template = "bank", title = "银行及公会银行（部落旁）" },
        -- 专业
        { coord = 42653204, template = "alchemy", info = "林奇·黑箭" },
        { coord = 48353820, template = "archaeology", info = "博学者达瑞妮斯" },
        { coord = 44772854, template = "blacksmithing", info = "奥兰德·夏菲尔/奥拉尔德·施米尔/伊曼蒂尔·锋歌" },
        { coord = 40256612, template = "cooking", title = "烹饪训练师（联盟）", info = "凯瑟琳·李\n\n德里克·奥斯：出售玩具|cFF00FF00大厨的帽子|r（|cFF4499FF美食家奖章|r）" },
        { coord = 69983900, template = "cooking", title = "烹饪训练师（部落）", info = "埃维罗·隆古巴\n\n米森希：出售玩具|cFF00FF00大厨的帽子|r（|cFF4499FF美食家奖章|r）" },
        { coord = 39063982, template = "enchanting", info = "附魔师纳萨尼斯" },
        { coord = 39072659, template = "engineering", info = "迪墨菲·欧申克/芬德尔·汽哨/钳工蒂迪" },
        { coord = 53046494, template = "fishing", info = "玛西娅·切斯" },
        { coord = 42933409, template = "herbalism", info = "多萝希·埃裉" },
        { coord = 41603715, template = "inscription", info = "帕林教授" },
        { coord = 40673536, template = "jewelcrafting", info = "提莫斯·琼斯\n\n哈罗德·温斯顿：出售戒指|cFF00FF00肯瑞托戒指|r，可传送到达拉然" },
        { coord = 34762842, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "制皮/剥皮训练师", info = "蒂亚妮·坎宁斯/迪尔克·马克斯", type = {"Leatherworking", "Skinning"} },
        { coord = 41492568, template = "mining", info = "杰迪安·汉德尔斯" },
        { coord = 36133355, template = "tailoring", title = "裁缝训练师/特殊裁缝商人", info = "查理·沃尔斯/月布裁缝专家埃德尔鲁·夏叶/魔焰裁缝专家兰尔拉·亮纹/暗纹裁缝专家琳娜·布鲁德" },
        -- 其他
        { coord = 52283154, template = "barber", info = "吉兹·考波克利" },
        { coord = 59633741, template = "stable", info = "塔西娅·幽谷" },
        { coord = 58124208, template = "mount", title = "特殊坐骑商人", info = "梅尔·弗兰希斯：出售多款坐骑，包括三人坐骑|cFF00FF00旅行者的苔原猛犸象|r" },
        { coord = 44814562, template = "toy", info = "耶比托·乔巴斯/发条助手：出售多款玩具和宠物" },
        { coord = 58833900, template = "pet", info = "布琳妮：出售2款玩具和4款宠物" },
        { coord = 51205442, template = "guild", title = "公会注册员/战袍商人", info = "安德鲁·马休/伊丽莎白·罗斯：出售巫妖王之怒版本的声望战袍" },
        { coord = 37153795, template = "look", title = "急救衬衣", info = "安吉莉克·巴特雷：出售2款|cFF00FF00绷带外观衬衣|r" },
        { coord = 43494905, template = "look", title = "外观兑换（布甲）", info = "帕尔蒂丝/鲁本·劳伦：出售布甲套装\n\n卡兰杜娜：出售16款衬衣" },
        { coord = 46412668, template = "look", title = "外观兑换（板甲）", info = "杜比·克雷/格里丝华尔德·哈兰德/霍莱斯·哈德兰：出售板甲套装" },
        { coord = 57475316, template = "look", title = "卖花女", info = "爱丽丝·普里洛斯：出售6款|cFF00FF00花朵副手外观|r" },
        { coord = 38605555, color = "unique", icon = 133739, text = "◆魔法货物", textA = "RIGHT", title = "魔法货物（巫术姐妹店内）", info = "恩多拉·莫尔海德：出售以下商品\n\n固定商品：\n\n法师技能|cFF00FF00神秘宝典：奥术语言|r\n法师技能|cFF00FF00神秘宝典：幻觉|r\n法师玩具|cFF00FF00魔宠石|r\n\n刷新商品：\n\n法师技能|cFF00FF00宝典变形术：黑猫|r\n法师技能|cFF00FF00远古传送门：达拉然|r\n法师玩具|cFF00FF00达拉然学徒的胸针|r" },
        { coord = 40012834, color = "unique", icon = 135851, text = "冰冻", title = "冰冻宝珠商人", info = "鼎鼎有名的佛罗佐：出售材料和裁缝图样|cFF00FF00凝霜飞毯|r（|cFF4499FF冰冻宝珠|r）" },
        { coord = 56314673, template = "portaltrainer", info = "大法师塞琳德拉\n\n点击后方水晶可传送至达拉然城外的紫罗兰哨站" },
        { coord = 49774749, template = "cinematic", info = "雕像喷泉两侧的|cFF00FF00荣耀之碑|r：可观看冰冠堡垒副本中|cFF00FF00击败巫妖王的动画|r" },
        { coord = 64165484, template = "randomraid", info = "大法师提迈尔：可排翡翠梦魇/暗夜要塞/萨格拉斯之墓/燃烧王座的随机本\n\n|cFFEE8800作者吐槽：所以为什么诺森德达拉然会有军团达拉然的随机本NPC|r" },
        { coord = 25214776, color = "quartermaster", icon = 236693, text = "肯瑞托", title = "肯瑞托军需官", info = "大法师奥瓦利斯" },
        -- 副本
        instanceNames = {
            ["紫罗兰监狱"] = "紫罗兰监狱",
        },
    },

    [126] = {  -- 达拉然（巫妖王之怒）：下水道
        group = "DalaranWLK",
        -- 主要
        { coord = 35465758, template = "inn", info = "埃因·格林" },
        { coord = 32515535, template = "bank" },
        -- 其他
        { coord = 64171658, template = "pet", title = "魔法材料商人", info = "达拉希尔：出售1款宠物|cFF00FF00魅影精灵|r" },
        { coord = 47362760, color = "unique", icon = 133740, text = "书商", title = "鬼祟的书商", info = "卡维兹·洛典：出售各种|cFF00FF00一部催人泪下的言情小说|r和萨满技能|cFF00FF00妖术书：蟑螂|r" },
        { coord = 59345822, template = "pvp_vendor", info = "凶残/憎恨/致命/狂怒/无情/暴怒角斗士PVP商人" },
    },

    --------------------------------------------------------------------------------
    -- 达拉然（军团再临）
    --------------------------------------------------------------------------------
    [627] = {
        group = "DalaranLegion",
        -- 传送
        poiNames = {
            ["阿古斯"] = { color = "portal", text = "阿古斯" },
        },
        { coord = 49474784, template = "portal", text = "传送", title = "守护者大厅", info = "可传送到龙眠神殿/泰洛古斯裂隙/卡拉赞" },
        { coord = 39546318, template = "portal_stormwind" },
        { coord = 55262398, template = "portal_orgrimmar" },
        { coord = 34594553, color = "portal", icon = 450906, text = "下水道", title = "下水道入口（左）" },
        { coord = 59854790, color = "portal", icon = 450908, text = "下水道", title = "下水道入口（右）" },
        -- 主要
        { coord = 49794013, template = "inn", title = "旅店（中立）", info = "艾米丝·埃索盖斯" },
        { coord = 44196374, template = "inn", title = "旅店（联盟）", info = "伊丝拉米·轻风" },
        { coord = 65423222, template = "inn", title = "旅店（部落）", info = "兽女乌达" },
        { coord = 43497742, template = "bank", title = "银行及公会银行（联盟旁）" },
        { coord = 52441805, template = "bank", title = "银行及公会银行（部落旁）" },
        -- 专业
        { coord = 42043177, template = "alchemy", info = "林奇·黑箭/德崔斯·瓦德拉" },
        { coord = 41212644, template = "archaeology", info = "博学者达瑞妮斯" },
        { coord = 39706651, template = "cooking", title = "烹饪训练师/烹饪订单（联盟）", info = "凯瑟琳·李\n\n诺米：可下达烹饪订单" },
        { coord = 69973895, template = "cooking", title = "烹饪训练师/烹饪订单（部落）", info = "埃维罗·隆古巴\n\n诺米：可下达烹饪订单" },
        { coord = 39224093, template = "enchanting", text = "附魔/幻化◆", textA = "LEFT", title = "附魔训练师/幻化师", info = "附魔师纳萨尼斯/织幻者图维斯", tags = {"profession", "service"} },
        { coord = 38812472, template = "engineering", info = "迪墨菲·欧申克/钳工蒂迪" },
        { coord = 52836560, template = "fishing", info = "玛西娅·切斯" },
        { coord = 42343389, template = "herbalism", info = "莉亚娜·泰/奎茵·柔步" },
        { coord = 41283705, template = "inscription", info = "帕林教授" },
        { coord = 40053529, template = "jewelcrafting", title = "珠宝加工训练师/珠宝商人", info = "提莫斯·琼斯\n\n斯米克斯·璃目：出售戒指|cFF00FF00肯瑞托强化指环|r，可传送到达拉然" },
        { coord = 35082943, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "制皮/剥皮训练师", info = "娜穆·月水/蒂亚妮·坎宁斯/泰尼德·怒金\n孔达尔·猎誓", type = {"Leatherworking", "Skinning"} },
        { coord = 46092664, template = "mining", info = "迪格丝大妈" },
        { coord = 35003461, template = "tailoring", info = "坦妮瑟娅" },
        -- 其他
        { coord = 51863166, template = "barber", info = "吉兹·考波克利" },
        { coord = 59233762, template = "stable", info = "塔西娅·幽谷" },
        { coord = 57614212, template = "mount", title = "特殊坐骑商人", info = "梅尔·弗兰希斯：出售多款坐骑，包括三人坐骑|cFF00FF00旅行者的苔原猛犸象|r" },
        { coord = 58453916, template = "pet", text = "◆宠物/传送", textA = "RIGHT", title = "宠物商人/宠物传送门", info = "达姆斯：出售6款宠物和玩具|cFF00FF00娜茜萨的镜子|r，让宠物变成你的样子\n\n缇菲·机簧（联盟）/吉雅达·金索（部落）：出售6款宠物和玩具|cFF00FF00魔法宠物镜|r，让你变成宠物的样子\n\n玛纳波夫：对话可传送到|cFF00FF00哀嚎洞穴/死亡矿井/诺莫瑞根/斯坦索姆/黑石深渊|r" },
        { coord = 43904662, template = "toy", info = "耶比托·乔巴斯：出售多款玩具和宠物，包括玩具|cFF00FF00棱彩装饰|r" },
        { coord = 43154909, template = "housing", title = "艺术品商人", info = "拉希尔·火脉：出售1款家宅装饰|cFF00FF00“仰望天空”画作|r" },
        { coord = 50565513, template = "guild", title = "公会注册员/战袍商人", info = "安德鲁·马休/伊丽莎白·罗斯：出售巫妖王之怒版本的声望战袍" },
        { coord = 36013753, template = "look", title = "急救衬衣", info = "安吉莉克·巴特雷：出售2款|cFF00FF00绷带外观衬衣|r" },
        { coord = 50907303, template = "look", title = "外观兑换（皮甲/锁甲）", info = "拉法尔·朗罗/瓦蕾莉·兰格鲁（皮甲套装兑换）\n玛蒂尔达·明火/布拉古德·明火（锁甲套装兑换）" },
        { coord = 37285559, template = "look", title = "外观兑换（布甲）", info = "帕尔蒂丝/布商：出售布甲套装\n\n萨兰·日线：出售16款|cFF00FF00衬衣|r\n\n理查德·哈特斯多克：出售2款|cFF00FF00头部幻化|r" },
        { coord = 57115353, template = "look", title = "卖花女", info = "爱丽丝·普里洛斯：出售6款|cFF00FF00花朵副手外观|r" },
        { coord = 44743195, color = "unique", icon = 1417744, text = "血商", title = "血商", info = "伊尔妮雅·血棘：出售军团版本各种材料和职业大厅资源（|cFF4499FF萨格拉斯之血|r）" },
        { coord = 48811361, color = "unique", icon = 1604168, text = "古怪硬币◆", textA = "LEFT", title = "虚空宝库管理员", info = "苏伊奥斯：出售坐骑|cFF00FF00阿坎迪安战龟|r/玩具|cFF00FF00圣光微粒|r（商品随机刷新）" },
        { coord = 45172908, color = "special", icon = 236521, text = "◆橙装/锻造", textA = "RIGHT", title = "橙装商人/锻造训练师", info = "奥法工匠维迪尔：出售军团版本全职业橙装（|cFF4499FF觉醒精华|r）/奥拉尔德·施米尔", tags = {"unique", "profession"} },
        { coord = 55994701, template = "portaltrainer", info = "大法师塞琳德拉" },
        { coord = 56906716, color = "special", icon = 1604167, text = "R币", title = "R币兑换", info = "大法师兰达洛克：可用金币/职业大厅资源/荣耀印记兑换|cFF00FF00破碎命运印记|r" },
        { coord = 25914458, color = "special", icon = 134156, text = "动画/克罗米◆", textA = "LEFT", title = "动画短片/场景战役", info = "罗伯特·纽哈斯：可观看|cFF00FF00伊利丹动画/卡德加动画|r\n\n克罗米的影像：可进入|cFF00FF00拯救克罗米|r场景战役，退出会被传送到诺森德龙眠神殿顶层" },
        { coord = 29197530, template = "pvp_vendor", text = "◆PVP商人", textA = "RIGHT", info = "角斗士/争斗者/精锐PVP商人" },
        { coord = 56922819, template = "pvp_vendor", text = "◆PVP商人", textA = "RIGHT", info = "角斗士/争斗者/精锐PVP商人" },
        { coord = 63605479, template = "randomraid", info = "大法师提迈尔：可排翡翠梦魇/暗夜要塞/萨格拉斯之墓/燃烧王座的随机本" },
        -- 副本
        instanceNames = {
            ["突袭紫罗兰监狱"] = "突袭紫罗兰监狱",
        }
    },

    [628] = {  -- 达拉然（军团再临）：下水道
        group = "DalaranLegion",
        { coord = 71401794, template = "blackmarket" },
        { coord = 58265750, template = "pet", info = "劳拉·马利：出售宠物|cFF00FF00阴沟水母|r和2款制皮图样，学习后可制作玩具|cFF00FF00火圈/皮质宠物缰绳|r（|cFF4499FF盲目之眼|r）" },
        { coord = 46605613, color = "vendor", icon = 801132, text = "商人", title = "凶狠的术士", info = "马修·莱比斯：出售铭文工艺图|cFF00FF00魔典：空灵领主|r，学习后可制作术士空灵领主宠物外观，并在理发店解锁（|cFF4499FF盲目之眼|r）" },
        { coord = 66217418, color = "vendor", icon = 801132, text = "商人", title = "魔法物品（2楼）", info = "达兹克·“普罗德摩尔”：出售裁缝图样|cFF00FF00衣柜：达拉然平民|r（|cFF4499FF盲目之眼|r）" },
        { coord = 65578027, color = "vendor", icon = 801132, text = "商人", title = "传送门与杂货（3楼）", info = "柯胡塔：出售附魔公式|cFF00FF00魔光火盆|r，学习后可制作玩具魔光火盆（|cFF4499FF盲目之眼|r）" },
        { coord = 76108359, color = "unique", icon = 134743, text = "◆语言药剂", textA = "RIGHT", title = "语言药剂商人", info = "菲兹·电胆：出售|cFF00FF00语言药剂|r，可看懂敌对阵营说话" },
    },

    [629] = {  -- 达拉然（军团再临）：守护者大厅
        group = "DalaranLegion",
        -- 传送
        { coord = 33867859, color = "portal", icon = 5927657, text = "◆泰洛古斯裂隙", textA = "RIGHT", title = "泰洛古斯裂隙传送门" },
        { coord = 64972109, color = "portal", icon = 237509, text = "达拉然", title = "达拉然传送门" },
        { coord = 30808433, color = "portal", icon = 236699, text = "龙眠神殿◆", textA = "LEFT", title = "龙眠神殿传送门" },
        { coord = 32027155, color = "portal", icon = 1530372, text = "卡拉赞", title = "卡拉赞传送门" },
        -- 其他
        { coord = 30588120, template = "upgrade", info = "库佐尔兹" },
        { coord = 33348447, color = "unique", icon = 3015740, text = "残忆", title = "残忆商人（绝版）", info = "怀念者阿穆尔" },
    },

    --------------------------------------------------------------------------------
    -- 奥利波斯
    --------------------------------------------------------------------------------
    [1670] = {
        group = "Oribos",
        -- 传送
        { coord = 20884570, template = "portal_stormwind" },
        { coord = 20885478, template = "portal_orgrimmar" },
        { coord = 57115035, color = "portal", icon = 450907, text = "上楼", title = "上楼" },
        { coord = 52104278, color = "portal", icon = 450907, text = "上楼", title = "上楼" },
        { coord = 47065035, color = "portal", icon = 450907, text = "上楼", title = "上楼" },
        { coord = 52105785, color = "portal", icon = 450907, text = "上楼", title = "上楼" },
        -- 主要
        { coord = 67465034, template = "inn", info = "塔·雷拉" },
        { coord = 60442939, template = "bank", title = "银行" },
        { coord = 65193601, template = "bank", text = "◆公会银行", textA = "RIGHT", title = "公会银行" },
        -- 专业
        { coord = 39244039, template = "alchemy", info = "炼药师奥·派尔" },
        { coord = 40513147, template = "blacksmithing", info = "匠人奥·伯克" },
        { coord = 46822266, template = "cooking", info = "厨师奥·克鲁特" },
        { coord = 48392942, template = "enchanting", info = "灌魔师奥·弗雷什" },
        { coord = 38084474, template = "engineering", text = "◆工程/拍卖", textA = "RIGHT", title = "工程学训练师/全息拍卖师（工程学限定）", info = "机械师奥·古尔/光子齿轮议价者", tags = {"profession", "official"} },
        { coord = 46172636, template = "fishing", title = "钓鱼训练师/钓鱼商人", info = "寻回者奥·普林\n\n经销商奥·那格勒：出售|cFF00FF00“掮灵垂钓器”|r" },
        { coord = 40223827, template = "herbalism", info = "遴选师奥·玛尔" },
        { coord = 36503670, template = "inscription", info = "抄写员奥·泰希" },
        { coord = 35234138, template = "jewelcrafting", info = "鉴定师奥·威森克" },
        { coord = 42172725, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "制皮/剥皮训练师", info = "制革师奥·吉尔/剥皮者奥·克姆", type = {"Leatherworking", "Skinning"} },
        { coord = 39303299, template = "mining", info = "挖掘者奥·非尔" },
        { coord = 45503178, template = "tailoring", info = "缝合者奥·菲斯" },
        -- 其他
        { coord = 64456426, template = "barber", info = "美容师塔·维兹基" },
        { coord = 64596988, template = "transmog", info = "织幻者塔·奥伦" },
        { coord = 34605652, template = "upgrade", info = "侵攻者佐·达什" },
        { coord = 59237543, template = "stable", info = "守护者塔·沙兰" },
        { coord = 65176755, template = "pet", info = "饲养者塔·希尔特：出售以下商品\n\n|cFF00FF00黄晶珠蜒/绿松石珠蜒/红宝石珠蜒|r（|cFF4499FF特定的灰色品质物品|r）\n\n|cFF00FF00无暇的紫晶珠蜒|r：概率提供彩虹飘带特效（|cFF4499FF宠物符咒|r）\n\n附魔公式|cFF00FF00心能活化宠物绳|r：学习后可制作同名玩具（|cFF4499FF宠物符咒|r）" },
        { coord = 23304897, template = "portaltrainer", info = "传送代理商（仅法师可见）" },
        { coord = 36176413, color = "special", icon = 3257748, text = "格里恩", title = "格里恩", info = "文官阿得赖斯提斯：对话可切换盟约" },
        { coord = 42987418, color = "special", icon = 3257749, text = "◆通灵领主", textA = "RIGHT", title = "通灵领主", info = "剑斗士米维克斯：对话可切换盟约" },
        { coord = 39746089, color = "special", icon = 3257750, text = "法夜", title = "法夜", info = "月莓女勋爵：对话可切换盟约" },
        { coord = 44856895, color = "special", icon = 3257751, text = "温西尔", title = "温西尔", info = "德莱文将军：对话可切换盟约" },
        { coord = 79564985, template = "cinematic", info = "过往撰写师罗-艾德拉布：可观看|cFF00FF00暗影界的故事/仲裁官的故事|r2段动画" },
        { coord = 41367144, template = "randomraid", info = "塔·艾尔法：可排纳斯利亚堡/统御圣所/初诞者圣墓的随机本" },
        { coord = 47127771, color = "quartermaster", icon = 3726261, text = "◆四大盟约", textA = "RIGHT", title = "盟约军需官", info = "四大盟约军需官出售以下通用商品\n\n1款宠物/1款坐骑/1款盟约武器附魔幻象/职业盟约雕文/道具|cFF00FF00深邃机遇容器|r：学会所有导灵器并提升至278等级（|cFF4499FF宇宙助溶剂|r）\n\n不朽军团军需官达尔·瓦提什：出售以下商品\n\n工程图纸|cFF00FF00结构图：虫洞发生器：暗影界|r，学习后可制作同名玩具\n\n背部幻化|cFF00FF00野蛮骨化之翼/死亡之像|r\n\n晋升者军需官副官米卡罗丝：出售以下商品\n\n玩具|cFF00FF00候选者担架|r\n\n工程图纸|cFF00FF00结构图：PHA7-YNX型灵豹|r，可制作同名宠物\n\n荒猎团军需官莉亚雯：出售以下商品\n\n铭文工艺图|cFF00FF00暮光符文牡鹿印记|r，学习后可制作德鲁伊旅行形态外观，并在理发店解锁\n\n背部幻化|cFF00FF00法夜纺织背包|r\n\n收割者之庭军需官朴素者达尔维：出售以下商品\n\n玩具|cFF00FF00罪钒茶具|r\n\n背部幻化|cFF00FF00微光金色罪碑锁链|r\n\n宣罪军需官档案员莉昂娜拉：出售以下商品（|cFF4499FF罪碑碎片|r）\n\n玩具|cFF00FF00迅捷背诵羽毛笔/粗俗仲裁者|r\n\n背部幻化|cFF00FF00地穴看守者的黝黑斗篷|r\n\n宠物|cFF00FF00档案员的羽毛笔|r" },
        { coord = 35045814, template = "pvp_vendor", info = "争端评估者承销商佐·库尔/争端大师佐·索尔格" },
    },

    [1671] = {  -- 奥利波斯：转移之环
        group = "Oribos",
        --传送
        { coord = 49565159, color = "portal", icon = 3257863, text = "噬渊", title = "噬渊", info = "一跃而下",  },
        -- 其他
        { coord = 60027110, color = "unique", icon = 3726261, text = "◆盟约道具", textA = "RIGHT", title = "传家宝掮灵", info = "奥·达拉：出售以下商品\n\n|cFF00FF00旅行者的心能宝箱|r：用于心能转移，可存战团银行（|cFF4499FF贮藏心能|r）\n\n|cFF00FF00掮灵的卓越印记|r：当前盟约直升60级\n\n|cFF00FF00无穷熏香|r：学会所有导灵器并提升至200等级\n\n|cFF00FF00时缚沉思|r：使一名盟约伙伴直升30级\n\n玩具|cFF00FF00侦察地图：深入暗影界|r" },
        -- poi
        poiNames = {
            ["前往扎雷殁提斯的传送门"] = { color = "portal", text = "扎雷殁提斯" },
            ["前往刻希亚的传送门"] = { color = "portal", text = "刻希亚" },
        },
    },

    [1672] = {  -- 奥利波斯：掮灵之居
        group = "Oribos",
        { coord = 50304318, template = "griftah", text = "格里伏塔◆", textA = "LEFT", info = "格里伏塔|cFFEE8800\n\n作者吐槽：很多上千金的灰色时尚小垃圾|r" }
    },

    --------------------------------------------------------------------------------
    -- 兵主之座
    --------------------------------------------------------------------------------
    [1698] = {
        group = "SanctumofDomination",
        -- 传送
        { coord = 56383154, color = "portal", icon = 3847780, text = "奥利波斯◆", textA = "LEFT", title = "奥利波斯传送门" },
        { coord = 56463705, template = "portal", text = "造物", title = "六叠的隐居处，造物密院",  },
        { coord = 61603772, template = "portal", text = "锐眼", title = "努拉基尔，锐眼密院" },
        { coord = 62893425, template = "portal", text = "◆泽雷克利斯", textA = "RIGHT", title = "泽雷克利斯：玛卓克萨斯" },
        { coord = 61553055, template = "portal", text = "祭仪", title = "埃索拉玛斯，祭仪密院" },
        { coord = 58812311, template = "portal", text = "瞭望台", title = "瞭望台，兵主之座" },
        -- 主要
        { coord = 46932996, template = "inn", info = "塔巴尼·夜愿" },
        -- 其他
        { coord = 56274805, template = "upgrade", info = "淤肠" },
        { coord = 60984648, template = "look", title = "4难度纳斯利亚武器匠", info = "麦利萨·绝命/莫迪斯·艾尔弗森/泰亚·塔瑟雷/奥迪欧斯·谷欧" },
        { coord = 46694238, color = "special", icon = 1391776, text = "灵魂", title = "灵魂守护者", info = "奥斯伯恩·布莱克：灵魂用于升级盟约圣所" },
        { coord = 40452448, color = "special", icon = 237523, text = "符文熔炉◆", textA = "LEFT" },
        { coord = 52714107, color = "quartermaster", icon = 3257749, text = "◆通灵领主", textA = "RIGHT", title = "通灵领主名望军需官", info = "苏·泽泰" },
        { coord = 49689087, template = "dummy" },
        -- poi
        poiNames = {
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    --------------------------------------------------------------------------------
    -- 堕罪堡
    --------------------------------------------------------------------------------
    [1699] = {
        group = "Sinfall",
        -- 传送
        { coord = 62532654, color = "portal", icon = 3847780, text = "◆奥利波斯", textA = "RIGHT", title = "奥利波斯传送门" },
        { coord = 36324833, color = "portal", icon = 450905, text = "下层", title = "通往堕罪堡下层深渊" },
        { coord = 17846124, color = "portal", icon = 450907, text = "上层", title = "通往堕罪堡上层地表" },
        { coord = 38076045, color = "portal", icon = 3257863, text = "噬渊", title = "噬渊传送门", info = "噬渊温西尔突袭激活时才可见" },
        { coord = 42024849, color = "portal", icon = 450907, text = "蝙蝠", title = "堕罪地面飞行蝠", info = "点击蝙蝠可被带到地表" },
        -- 主要
        { coord = 66783383, template = "inn", info = "夜幕卫士薇克莱拉" },
        -- 其他
        { coord = 71522894, template = "stable", info = "瓦希利卡" },
        { coord = 47656132, color = "unique", icon = 133617, text = "镜面修复◆", textA = "LEFT", title = "镜面修复工具", info = "西蒙妮：出售|cFF00FF00手工制作的镜面修复工具|r（|cFF4499FF注能红宝石|r）" },
        { coord = 45432834, color = "special", icon = 1391776, text = "灵魂", title = "灵魂守护者", info = "特纳瓦尔：灵魂用于升级盟约圣所" },
        { coord = 52575249, template = "dummy" },
        { coord = 60185349, template = "dummy" },
        -- poi
        poiNames = {
            ["永恒高台"] = { color = "portal", text = "永恒高台" },
            ["堕傲庄"] = { color = "portal", text = "堕傲庄" },
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    [1700] = {  -- 堕罪堡：深渊
        group = "Sinfall",
        -- 传送
        { coord = 71053798, color = "portal", icon = 450907, text = "上层", title = "通往堕罪堡上层" },
        -- 其他
        { coord = 73382480, template = "upgrade", info = "凯·耶尔莫" },
        { coord = 53834640, template = "look", title = "随机纳斯利亚武器匠", info = "夜幕卫士杰丝莱莎" },
        { coord = 55385435, template = "look", title = "普通纳斯利亚武器匠", info = "阿法纳斯勋爵" },
        { coord = 45366531, template = "look", title = "英雄纳斯利亚武器匠", info = "纺尸者麦康奈尔" },
        { coord = 40304631, template = "look", title = "史诗纳斯利亚武器匠", info = "沃帕莉雅" },
        { coord = 70652741, color = "quartermaster", icon = 3257751, text = "堕罪", title = "堕罪军需官", info = "“苍白之刃”格雷戈" },
        -- poi
        poiNames = {
            ["饲育者林地"] = { color = "portal", text = "饲育者林地" },
            ["灾厄林"] = { color = "portal", text = "灾厄林" },
            ["赎罪大厅"] = { color = "portal", text = "赎罪大厅" },
            ["统御要塞"] = { color = "portal", text = "统御要塞" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
        },
    },

    --------------------------------------------------------------------------------
    -- 森林之心
    --------------------------------------------------------------------------------
    [1701] = {
        group = "HeartoftheForest",
        -- 传送
        { coord = 51002025, template = "portal", text = "传送", title = "通往蘑网之环/奥利波斯传送门" },
        { coord = 53763838, color = "portal", icon = 450907, text = "上层", title = "通往森林之心上层华盖" },
        -- 主要
        { coord = 54785617, template = "inn", info = "科瓦林" },
        -- 其他
        { coord = 46945683, template = "upgrade", info = "工匠大师拉姆达" },
        { coord = 33944351, color = "special", icon = 1391776, text = "灵魂", title = "灵魂守护者", info = "翩翩：灵魂用于升级盟约圣所" },
        { coord = 37982463, color = "special", icon = 3586268, text = "形态", title = "灵魂变形形态", info = "曼恩女士/丘法：改变法夜盟约技能灵魂变形的形态外观" },
        { coord = 59483180, color = "quartermaster", icon = 3257750, text = "◆荒猎团/法夜", textA = "RIGHT", title = "荒猎团/法夜名望军需官", info = "艾丝琳/艾尔雯" },
        { coord = 40038075, template = "dummy" },
        { coord = 53857865, template = "dummy" },
        -- poi
        poiNames = {
            ["女王的温室"] = { color = "portal", text = "女王的温室" },
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    [1702] = {  -- 森林之心：树根
        group = "HeartoftheForest",
        -- 传送
        { coord = 59972849, color = "portal", icon = 3847780, text = "◆奥利波斯", textA = "RIGHT", title = "奥利波斯传送门" },
        -- 其他
        { coord = 49445400, template = "look", title = "4难度纳斯利亚武器匠", info = "耀风/阿德拉/哈尔科斯/苏拉努姆" },
        -- poi
        poiNames = {
            ["女王的温室"] = { color = "portal", text = "女王的温室" },
            ["森林之心"] = { color = "portal", text = "森林之心" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    [1819] = {  -- 森林之心：蘑网之环
        group = "HeartoftheForest",
        -- 其他
        { coord = 55695013, color = "quartermaster", icon = 3257750, text = "玛拉斯缪斯◆", textA = "LEFT", title = "玛拉斯缪斯军需官", info = "柯迪纳留斯" },
        -- poi
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

    --------------------------------------------------------------------------------
    -- 极乐堡
    --------------------------------------------------------------------------------
    [1707] = {
        group = "ElysianHold",
        -- 传送
        { coord = 48796475, color = "portal", icon = 3847780, text = "◆奥利波斯", textA = "RIGHT", title = "奥利波斯传送门" },
        -- 主要
        { coord = 26353389, template = "inn", title = "旅店（上层）", info = "看护者卡林" },
        -- 其他
        { coord = 22793158, template = "stable", title = "兽栏（上层）", info = "野兽照看者克里斯塔" },
        { coord = 31314760, template = "mount", text = "坐骑/宠物◆", textA = "LEFT", title = "坐骑和宠物商人（上层）", info = "宾基罗斯/泽里斯科斯：需要解锁对应成就才能购买" },
        { coord = 56538224, template = "look", title = "4难度纳斯利亚武器匠（上层）", info = "凯丽·胡/阿里修斯/供应商普罗索斯/战斗大师恩迪欧斯" },
        -- poi
        poiNames = {
            ["传送网络"] = { color = "portal", text = "传送网络" },
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["晋升之路"] = { color = "special", text = "晋升之路" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    [1708] = {  -- 极乐堡：羁绊圣所
        group = "ElysianHold",
        -- 其他
        { coord = 57373018, template = "upgrade", title = "物品升级（下层）", info = "铸手非罗" },
        { coord = 59513418, color = "special", icon = 1391776, text = "灵魂", title = "灵魂守护者（下层）", info = "灵魂向导戴丽雅：灵魂用于升级盟约圣所", offsetY = 5 },
        { coord = 63363052, color = "quartermaster", icon = 3257748, text = "格里恩", title = "格里恩军需官（下层）", info = "副官伽罗斯" },
        -- poi
        poiNames = {
            ["指挥台"] = { color = "special", text = "指挥台" },
            ["羁绊熔炉"] = { color = "special", text = "羁绊熔炉" },
            ["心能导流器"] = { color = "special", text = "心能导流器" },
            ["晋升之路"] = { color = "special", text = "晋升之路" },
            ["圣所升级"] = { color = "special", text = "圣所升级" },
        },
    },

    --------------------------------------------------------------------------------
    -- 瓦德拉肯
    --------------------------------------------------------------------------------
    [2112] = {
        group = "Valdrakken",
        -- 传送
        { coord = 59774169, template = "portal_stormwind", text = "暴风/传送◆", textA = "LEFT", title = "暴风城传送门/传送门训练师", info = "艾蕾苟萨", tags = {"portal", "special"} },
        { coord = 56653831, template = "portal_orgrimmar" },
        { coord = 61953214, template = "portal", text = "顶层", title = "传送到守护巨龙之座（顶层）" },
        { coord = 62675729, color = "portal", icon = 1396974, text = "◆翡翠梦境", textA = "RIGHT", title = "翡翠梦境传送门" },
        { coord = 26094099, color = "portal", icon = 236716, text = "◆荒芜之地", textA = "RIGHT", title = "荒芜之地传送门" },
        -- 主要
        { coord = 47994878, template = "inn", info = "玛琳斯" },
        { coord = 72504716, template = "inn", info = "麦拉多尔米" },
        { coord = 43065961, template = "auction" },
        { coord = 57605654, template = "bank" },
        { coord = 15135294, template = "blackmarket", text = "◆黑市入口", textA = "RIGHT", title = "黑市入口（悬崖下方）" },
        { coord = 20184917, template = "blackmarket" },
        -- 专业
        { coord = 36407169, template = "alchemy", info = "康弗拉苟" },
        { coord = 36944663, template = "blacksmithing", info = "塑金者库洛科" },
        { coord = 46514624, template = "cooking", info = "艾鲁苟萨：出售2款|cFF00FF00单手锤外观|r" },
        { coord = 31056137, template = "enchanting", info = "索拉苟萨" },
        { coord = 42254863, template = "engineering", info = "克林基克里克·碎轰" },
        { coord = 44827471, template = "fishing", title = "钓鱼训练师/渔具商人", info = "托克洛\n\n帕卡克：出售宠物|cFF00FF00小野鸭|r", tags = {"profession", "vendor"} },
        { coord = 37426835, template = "herbalism", info = "阿格里库斯" },
        { coord = 38847342, template = "inscription", info = "塔伦达拉" },
        { coord = 40806111, template = "jewelcrafting", info = "图鲁拉多米" },
        { coord = 28536086, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "制皮/剥皮训练师", info = "塑皮者科鲁兹/粗犷的莱拉索尔", type = {"Leatherworking", "Skinning"} },
        { coord = 38905142, template = "mining", icon = 4620679, text = "采矿", title = "采矿训练师", info = "潜地者赛基塔", color = "profession", type = "Mining" },
        { coord = 32136626, template = "enchanting", info = "寻线者帕克斯/寻线者弗拉冯" },
        -- 其他
        { coord = 30355284, template = "barber", info = "经营者瓦拉斯塔萨" },
        { coord = 74455606, template = "transmog", info = "织幻者达耶里斯" },
        { coord = 45673825, template = "upgrade", info = "考尔克夏恩" },
        { coord = 34636155, template = "order", info = "下达制造业订单" },
        { coord = 46747889, template = "stable", info = "凯斯塔兹：出售以下商品\n\n玩具|cFF00FF00宠物绳|r\n\n宠物|cFF00FF00吓人的箱子/滑鳗|r\n\n6款|cFF00FF00驭空术坐骑外观|r（|cFF4499FF巨龙版本材料+巨龙群岛补给|r）" },
        { coord = 48308293, template = "pet", info = "莱辛德拉" },
        { coord = 74496315, template = "pet", info = "园丁卡玛：出售2款|cFF00FF00始祖龙宠物|r（|cFF4499FF原始熊脊骨+巨大而坚硬的股骨+巨龙群岛补给|r）" },
        { coord = 36436299, color = "vendor", icon = 1030900, text = "商人", title = "贸易协调员", info = "多赛诺斯：出售多款图纸配方，包含1款|cFF00FF00驭空术坐骑外观|r（|cFF4499FF巨龙群岛补给|r）" },
        { coord = 33852769, color = "vendor", icon = 1030900, text = "商人", title = "首席图书管理员", info = "黎波尔苟：出售法师雕文|cFF00FF00奥术魔宠雕文|r" },
        { coord = 31616930, template = "look", info = "加耶拉：出售几款套装和副手幻化（|cFF4499FF巨龙版本材料+巨龙群岛补给|r）" },
        { coord = 36045011, template = "look", info = "铸甲师泰里斯克：出售几款头部和肩膀幻化（|cFF4499FF巨龙版本材料+巨龙群岛补给|r）" },
        { coord = 57922427, template = "look", title = "园艺供应商", info = "园丁赛留丝：出售4款园艺造型武器幻化（|cFF4499FF彩虹珍珠+巨龙群岛补给|r）" },
        { coord = 77543868, template = "heirloom", info = "赫雷多穆：出售传家宝装备和武器60-70级升级道具" },
        { coord = 73804552, color = "unique", icon = 4555657, text = "青铜锭", title = "古老的青铜锭（绝版）", info = "米莉欧辛：出售坐骑|cFF00FF00老基格沃斯先生|r和多款装备幻化（|cFF4499FF古老的青铜锭|r）\n\n|cFFEE8800作者描述：只有仍然拥有该货币的人才能看到兑换NPC|r" },
        { coord = 42804270, color = "unique", icon = 4638431, text = "◆血腥硬币", textA = "RIGHT", title = "血腥硬币商人（进门右边墙角）", info = "护战者格雷什：出售玩具|cFF00FF00恶龙克星的胜利旗帜|r（|cFF4499FF血腥硬币|r）" },
        { coord = 38113773, color = "unique", icon = 134388, text = "升级/元素◆", textA = "LEFT", title = "物品升级/元素涌流商人", info = "艾尔扎\n\n密斯莱莎：出售以下商品（|cFF4499FF元素涌流|r）\n\n各职业|cFF00FF00狂怒风暴套装|r\n\n宠物|cFF00FF00魅火/斯托米|r\n\n坐骑|cFF00FF00雷革蝾螈|r", tags = {"service", "unique"} },
        { coord = 60264230, template = "cinematic", text = "◆动画", textA = "RIGHT", title = "动画短片（上楼右转）", info = "斯托里多米：可观看|cFF00FF00龙希尔的起源/奈萨里奥的陨落/巨龙的黎明|r3段动画" },
        { coord = 25015070, template = "transformation" },
        { coord = 26074003, color = "special", icon = 4638429, text = "泰坦圣物◆", textA = "LEFT", title = "首席泰坦研究员", info = "索罗缇丝：用|cFF00FF00泰坦圣物|r兑换瓦德拉肯联军声望" },
        { coord = 35182464, color = "special", icon = 4638531, text = "远古牢窟神器◆", textA = "LEFT", title = "远古牢窟神器兑换", info = "莉莉安·明月：用|cFF00FF00远古牢窟神器|r兑换声望" },
        { coord = 58163521, color = "quartermaster", icon = 4687630, text = "联军", title = "瓦德拉肯联军军需官", info = "乌纳托斯：出售多款图纸配方/幻化/宠物/家宅装饰/驭空术坐骑外观（|cFF4499FF巨龙版本材料+巨龙群岛补给|r）" },
        { coord = 35425910, color = "quartermaster", icon = 4557373, text = "工匠商盟◆", textA = "LEFT", title = "工匠商盟军需官", info = "拉布尔：出售多款图纸配方和|cFF00FF00工匠商盟战袍|r（|cFF4499FF匠人之勇|r）" },
        { coord = 44313653, template = "pvp_vendor", info = "征服/荣誉/精锐征服/战争模式军需官\n黑曜/苍郁/腾龙/猩红争斗者配方" },
        { coord = 43823961, icon = 236179, text = "木桩", title = "木桩", color = "pvp" },
        -- poi
        poiNames = {
            ["创新引擎"] = { color = "special", text = "创新引擎" },
        },
    },

    --------------------------------------------------------------------------------
    -- 多恩诺嘉尔
    --------------------------------------------------------------------------------
    [2339] = {
        group = "Dornogal",
        -- 传送
        { coord = 41172269, template = "portal", text = "◆卡雷什/暴风", textA = "RIGHT", title = "卡雷什/暴风城传送门" },
        { coord = 38162723, template = "portal_orgrimmar" },
        -- 主要
        { coord = 45204722, template = "inn", info = "罗耐什" },
        { coord = 56754720, template = "auction", title = "拍卖行" },
        { coord = 53274426, template = "bank" },
        { coord = 64765260, template = "blackmarket", text = "◆黑市", textA = "RIGHT" },
        -- 专业
        { coord = 49066323, template = "blacksmithing", info = "达利恩" },
        { coord = 44194585, template = "cooking", info = "阿索达斯" },
        { coord = 52487135, template = "enchanting", info = "纳嘉德" },
        { coord = 49035608, template = "engineering", info = "热力先知阿赫达斯" },
        { coord = 50492684, template = "fishing", info = "德罗卡" },
        { coord = 44766931, template = "herbalism", info = "阿克丹" },
        { coord = 54455898, template = "leatherworking", info = "玛尔布" },
        { coord = 53035279, template = "mining", info = "塔里布" },
        { coord = 54455697, template = "skinning", info = "基纳德" },
        { coord = 54516350, template = "tailoring", info = "科塔格" },
        { coord = 48807092, template = "profession_mixed", text = "炼金/铭文/珠宝◆", title = "炼金/铭文/珠宝加工训练师", info = "塔里格/布里甘/马吉尔", type = {"Alchemy", "Inscription", "Jewelcrafting"}, textA = "LEFT" },
        -- 其他
        { coord = 58615264, template = "barber", info = "织线者格雷卡" },
        { coord = 58074878, template = "transmog", info = "织幻者戴基兰" },
        { coord = 44645608, template = "tradingpost", info = "安蒂·海髯/忒哈" },
        { coord = 52054200, template = "upgrade", info = "库佐尔兹" },
        { coord = 58055645, template = "order", info = "办事员格雷塔尔：下达制造业订单\n\n赛奈特（右1）：出售|cFF00FF00装备纹章|r和|cFF00FF00强化矩阵|r\n\n达拉·伏罗希（右2）：重置专业专精点（|cFF00FF00仅限1次|r）" },
        { coord = 47864440, color = "service", icon = 1064187, text = "地下堡", title = "地下堡行者总部", info = "雷诺·杰克逊（左）：出售地下堡外观（|cFF4499FF共鸣水晶|r）\n\n芬利·莫格顿爵士（右）：出售地下堡钥匙/道具/幻化/装备（|cFF4499FF晦幽铸币|r）" },
        { coord = 55366711, template = "stable", info = "卡尔甘德" },
        { coord = 58506486, template = "pet", info = "埃拉尼：出售5款宠物" },
        { coord = 52866794, template = "housing", title = "弗雷德里克的奇妙家具", info = "“第二把交椅”袍铎" },
        { coord = 57266084, template = "look", info = "欧斯迪恩：出售多款幻化套装（优先|cFF4499FF土壳宝石|r，其次|cFF4499FF共鸣水晶|r）\n\n乔里德（左1）：出售1款家宅装饰" },
        { coord = 62575093, template = "griftah", offsetY = 5, info = "格里伏塔：出售以下商品\n\n|cFF00FF00始祖龟幸运符|r：重复性传送道具，传送到库尔提拉斯斯托颂谷地珍宝海岸\n\n|cFF00FF00灰羽护符|r：用来收集灰烬之羽\n\n|cFF00FF00格里伏塔的耐用抛光粉|r：可以洗去装备美化\n\n|cFF00FF00立方渎神石|r：珠宝图纸" },
        { coord = 60960530, color = "unique", icon = 4279015, text = "变形术", title = "变形术秘典", info = "进入燃火之厅和瓦莉拉·萨古纳尔对话完成任务，获得法师专属|cFF00FF00变形术秘典苔绒羱|r\n\n|cFFEE8800作者吐槽：米尔豪斯竟然在和瓦莉拉打炉石|r" },
        { coord = 50015414, template = "catalyst" },
        { coord = 47976789, template = "transformation" },
        { coord = 39102417, color = "quartermaster", icon = 5891369, text = "多恩议会◆", textA = "LEFT", title = "多恩诺嘉尔议会军需官", info = "审计员巴乌尔兹" },
        { coord = 59825641, color = "quartermaster", icon = 4557373, text = "◆工匠商盟", textA = "RIGHT", title = "工匠商盟军需官", info = "莱伦达尔：出售专业图纸配方（|cFF4499FF匠人之敏|r）" },
        { coord = 55237685, template = "pvp_vendor", title = "配方/战争模式军需官/荣誉军需官", info = "霍萨恩：出售PVP装备配方和材料（|cFF4499FF荣誉点数|r）\n\n吉尔德兰：出售老兵等级PVP装备（|cFF4499FF血腥硬币|r）\n\n维勒尔德：出售探索者等级PVP装备和2款家宅装饰（|cFF4499FF荣誉点数|r）\n\n拉兰迪：出售勇士等级PVP装备（|cFF4499FF征服点数|r）" },
        { coord = 59996972, template = "pvp_vendor", text = "◆升级/PVP商人", textA = "RIGHT", title = "物品升级/精锐征服军需官/战争补给", info = "雷多尼尔：物品升级\n\n罗古恩：出售PVP武器外观（|cFF4499FF荣耀印记|r）\n\n玛尔拉：出售PVP药水和道具（|cFF4499FF荣誉点数|r）", tags = {"service", "pvp"} },
        { coord = 57677324, template = "dummy" },
        -- poi
        poiNames = {
            ["通往时间流的传送门"] = { color = "portal", text = "时间流" },
            ["通往艾基-卡赫特的传送门"] = { color = "portal", text = "艾基" },
            ["前往海妖岛的飞艇"] = { color = "portal", text = "海妖岛" },
            ["前往安德麦的传送器"] = { color = "portal", text = "安德麦" },
            ["游学者周卓"] = { color = "special", text = "游学探奇" },
        },
        -- maplink
        maplinkNames = {
            ["喧鸣深窟"] = "喧鸣深窟",
        },
        -- 副本
        instanceNames = {
            ["驭雷栖巢"] = "驭雷栖巢",
        },
    },

    --------------------------------------------------------------------------------
    -- 千丝之城
    --------------------------------------------------------------------------------
    [2213] = {
        group = "CityofThreads",
        -- 主要
        { coord = 49782190, template = "inn", title = "旅店（上层）", info = "伊弗加瓦尔" },
        { coord = 57073948, template = "inn", title = "旅店（下层）", info = "遭嫌弃的艾里基" },
        -- 专业
        { coord = 45831356, template = "alchemy", text = "◆炼金/商人", textA = "RIGHT", title = "炼金术训练师", info = "夏尔巴\n\n炼金术供应商赛斯巴格：出售|cFF00FF00变形翻译药水：蛛魔语|r（|cFF4499FF刻基|r）", tags = {"profession", "vendor"} },
        { coord = 46832256, template = "blacksmithing", text = "锻造/采矿◆", textA = "LEFT", title = "锻造/采矿训练师", info = "麦尔/不倦的敏泰恩", type = {"Blacksmithing", "Mining"} },
        { coord = 47892464, template = "cooking", info = "调味厨师德鲁克" },
        { coord = 45583449, template = "enchanting", info = "希尔拉菲" },
        { coord = 57493275, template = "engineering", info = "拉兰基" },
        { coord = 51432521, template = "fishing", info = "玛拉克罗兹" },
        { coord = 47271667, template = "herbalism", info = "卡瓦里斯" },
        { coord = 41752648, template = "inscription", info = "奎尔" },
        { coord = 47771942, template = "jewelcrafting", text = "◆珠宝/玩具", textA = "RIGHT", title = "珠宝加工训练师/商人", info = "格万罗\n\n珠宝加工供应商阿尔弗斯·瓦拉乌鲁:出售玩具|cFF00FF00爱蛛者眼镜语|r（|cFF4499FF刻基|r）", tags = {"profession", "collection"} },
        { coord = 43771960, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "制皮/剥皮训练师", info = "戈什/法约尼", type = {"Leatherworking", "Skinning"} },
        { coord = 49721742, template = "tailoring", info = "喜丝者瓦利" },
        -- 其他
        { coord = 44211713, template = "pet", info = "巢穴之母马恩提克：出售2款宠物（|cFF4499FF刻基|r）" },
        { coord = 57334587, template = "look", title = "套装兑换/商人（下层）", info = "阿布克萨/伊普克萨/基尔克萨：出售尼鲁巴尔王宫套装（|cFF4499FF至高探洞者的印记/裹网珍玩|r）\n\n止渴者阿夏拉萨拉：出售饮料|cFF00FF00元气饱满|r，进食充分后加速提高2点并且可以水上行走（|cFF4499FF刻基|r）" },
        { coord = 63313823, color = "special", icon = 651601, text = "彩虹茶", title = "向日葵先生的茶（下层）", info = "桌子上点击|cFF00FF00向日葵之茶|r，可获得获得|cFF00FF00彩虹拖尾特效|r（需要完成向日葵先生的任务，即可永久饮用）\n\n|cFFEE8800作者描述：玩具棱彩装饰同款效果，持续20分钟，使用任意传送都会消失|r" },
        -- 副本
        instanceNames = {
            ["千丝之城"] = "千丝之城",
            ["艾拉-卡拉，回响之城"] = "回响之城",
            ["尼鲁巴尔王宫"] = "尼鲁巴尔王宫",
        },
        -- 地下堡
        delveNames = {
            ["幽暗要塞"] = "幽暗要塞",
        },
        { coord = 07833386, color = "delve", icon = 5779390, text = "◆泽克维尔的巢穴", textA = "RIGHT", title = "宿敌地下堡" },
    },

    [2216] = {  -- 千丝之城：下层
        group = "CityofThreads",
        -- 主要
        { coord = 57073948, template = "inn", title = "旅店（下层）", info = "遭嫌弃的艾里基" },
        -- 其他
        { coord = 57334587, template = "look", title = "套装兑换/商人（下层）", info = "阿布克萨/伊普克萨/基尔克萨：出售团本尼鲁巴尔王宫套装（|cFF4499FF至高探洞者的印记/裹网珍玩|r）\n\n止渴者阿夏拉萨拉：出售饮料|cFF00FF00元气饱满|r，进食充分后加速提高2点并且可以水上行走（|cFF4499FF刻基|r）" },
        { coord = 63313823, color = "special", icon = 651601, text = "彩虹茶", title = "向日葵先生的茶（下层）", info = "桌子上点击|cFF00FF00向日葵之茶|r，可获得获得|cFF00FF00彩虹拖尾特效|r（需要完成向日葵先生的任务，即可永久饮用）\n\n|cFFEE8800作者描述：玩具棱彩装饰同款效果，持续20分钟，使用任意传送都会消失|r" },
        -- 副本
        instanceNames = {
            ["千丝之城"] = "千丝之城",
            ["艾拉-卡拉，回响之城"] = "回响之城",
            ["尼鲁巴尔王宫"] = "尼鲁巴尔王宫",
        },
        -- 地下堡
        delveNames = {
            ["幽暗要塞"] = "幽暗要塞",
        },
        { coord = 07833386, color = "delve", icon = 5779390, text = "◆泽克维尔的巢穴", textA = "RIGHT", title = "宿敌地下堡" },
    },

    --------------------------------------------------------------------------------
    -- 安德麦
    --------------------------------------------------------------------------------
    [2346] = {
        group = "Undermine",
        -- 传送
        { coord = 17295076, color = "portal", icon = 5770812, text = "喧鸣深窟◆", textA = "LEFT", title = "喧鸣深窟深沟钻机", info = "和卡莉·爽乘对话，通往喧鸣深窟" },
        { coord = 18805221, color = "portal", icon = 2065640, text = "赞达拉", title = "赞达拉深沟钻机", info = "和比格兹·快道对话，通往祖达萨的卡亚海滨" },
        -- 主要
        { coord = 43515170, template = "inn", text = "◆旅店/合约/军需官/套装", textA = "RIGHT", title = "旅店/财阀招募/安德麦财阀军需官/套装兑换（2楼右边）", info = "帕克斯·紧身：和NPC对话可单人剧情模式体验解放安德麦尾王\n\n凯蒂·板环：签订每周财阀声望\n\n斯玛克斯·紧身：出售以下商品\n\n专业论述（|cFF4499FF匠人之敏|r）\n\n坐骑|cFF00FF00紫罗兰装甲惊哮犬/紧身特快|r（|cFF4499FF共鸣水晶|r）\n\n4款家宅装饰（|cFF4499FF共鸣水晶|r）\n\n卡莉·炸桥：出售团本解放安德麦套装（|cFF4499FF浮华嵌宝珍玩|r）", tags = {"inn", "special", "quartermaster", "vendor"} },
        { coord = 24464486, template = "blackmarket" },
        -- 其他
        { coord = 43268284, template = "mount", info = "斯凯吉特·烬轰：出售3款坐骑（|cFF4499FF混杂机械件|r）" },
        { coord = 32128220, template = "pet", info = "克里奇" },
        { coord = 59622725, template = "pet", info = "普雷兹里·斩浪" },
        { coord = 24516333, template = "look", info = "格里希特·粗人：出售四大财阀|cFF00FF00战袍/护肩/头盔|r3种幻化，必须签订财阀声望才能购买对应声望的外观" },
        { coord = 25753814, color = "unique", icon = 134757, text = "可乐罐", title = "S.C.R.A.P.交易", info = "安杰罗·锈桶：出售以下商品\n\n|cFF00FF00筛过的废料堆|r：可开出宠物和坐骑（|cFF4499FF空卡亚可乐罐/典藏卡亚可乐罐|r）\n\n玩具|cFF00FF00安德麦补给箱|r（|cFF4499FF空卡亚可乐罐|r）\n\n宠物|cFF00FF00咬碎者/小白鼠|r（|cFF4499FF典藏卡亚可乐罐|r）\n\nS.C.R.A.P.豪华清洁器（|cFF4499FF沾满污泥的物件|r）" },
        { coord = 34097129, color = "unique", icon = 533422, text = "金鱼", title = "钓鱼训练师/“金”鱼交易", info = "布莱尔·巴斯：出售3款鱼漂玩具和1款家宅装饰|cFF00FF00锈浊的补丁浴盆|r（|cFF4499FF“金”鱼|r）" },
        { coord = 39152220, color = "quartermaster", icon = 6323357, text = "锈水", title = "绣水军需官", info = "洛可·笑轰：出售以下商品（|cFF4499FF共鸣水晶|r）\n\n玩具|cFF00FF00锈水财阀旗帜/盒装店面|r\n\n宠物|cFF00FF00锈水垃圾搬运工|r\n\n坐骑|cFF00FF00猩红装甲惊哮犬|r\n\n2款家宅装饰" },
        { coord = 63431674, color = "quartermaster", icon = 6323358, text = "黑水", title = "黑水军需官", info = "水手长哈迪：出售以下商品（|cFF4499FF共鸣水晶|r）\n\n玩具|cFF00FF00黑水财阀旗帜/私人捕鱼船|r\n\n宠物|cFF00FF00破浪机甲暴龙|r\n\n坐骑|cFF00FF00黑水伐木机尊享版MK2型|r\n\n2款家宅装饰" },
        { coord = 27137257, color = "quartermaster", icon = 6323359, text = "热砂", title = "热砂军需官", info = "实验室助理拉兹丽：出售以下商品（|cFF4499FF共鸣水晶|r）\n\n玩具|cFF00FF00热砂财阀旗帜/恒久诺格弗格药剂|r\n\n宠物|cFF00FF00艾匹|r\n\n坐骑|cFF00FF00钞绿色飞行器|r\n\n2款家宅装饰" },
        { coord = 53317272, color = "quartermaster", icon = 6323360, text = "风险", title = "风险军需官", info = "拆废者薛兹：出售以下商品（|cFF4499FF共鸣水晶|r）\n\n玩具|cFF00FF00风险投资公司旗帜/投掷锯刃|r\n\n宠物|cFF00FF00火箭拳|r\n\n坐骑|cFF00FF00黄褐运载火箭|r\n\n2款家宅装饰" },
        { coord = 30743891, color = "quartermaster", icon = 6124649, text = "暗索", title = "暗索军需官（下水道入口）", info = "希奇·内幕：出售以下商品\n\n|cFF00FF00一箱暗索杂物|r：开出声望道具（|cFF4499FF市场研究|r）\n\n幻化|cFF00FF00暗索内幕外套|r（|cFF4499FF共鸣水晶|r）\n\n2款家宅装饰（|cFF4499FF共鸣水晶|r）" },
        -- poi
        poiNames = {
            ["前往多恩诺嘉尔的传送器"] = { color = "portal", text = "多恩诺嘉尔" },
            ["D.R.I.V.E."] = { color = "special", text = "车辆改装" },
        },
        -- 副本
        instanceNames = {
            ["解放安德麦"] = "解放安德麦",
        },
        -- 地下堡
        delveNames = {
            ["闸板陋巷"] = "闸板陋巷",
            ["破拆穹顶"] = "破拆穹顶",
        },
    },

    --------------------------------------------------------------------------------
    -- 塔扎维什
    --------------------------------------------------------------------------------
    [2472] = {
        group = "Tazavesh",
        -- 传送
        { coord = 50001947, color = "portal", icon = 1064187, text = "◆多恩诺嘉尔", textA = "RIGHT", title = "多恩诺嘉尔地下堡行者总部传送门" },
        { coord = 46845685, color = "portal", text = "相位",  },
        -- 主要
        { coord = 41442482, template = "inn", info = "巴·奥尔" },
        -- 专业
        { coord = 46021831, template = "cooking", info = "巴·迪巴拉" },
        -- 其他
        { coord = 43012875, template = "transmog", info = "织幻者雅顿" },
        { coord = 47412689, template = "stable", info = "巴·西姆塔尔" },
        { coord = 51865387, template = "toy", info = "管理员威·卡：出售玩具|cFF00FF00柔软的泡沫塑料剑/静默耳塞|r" },
        { coord = 54315584, color = "vendor", icon = 1392955, text = "采集", title = "采集兑换", info = "欧·米特：兑换卡兹阿加基础草药（|cFF4499FF幻影蕾/卡雷什莲花|r）\n\n欧·米尤兹：兑换卡兹阿加基础矿石（|cFF4499FF凄棱石/卡雷什共鸣之石|r）" },
        { coord = 54595833, template = "look", title = "异域花朵", info = "掮灵威·贝纳：出售6款|cFF00FF00花朵副手外观|r" },
        { coord = 53195412, color = "unique", icon = 133740, text = "◆书商", textA = "RIGHT", title = "异域书籍", info = "佐·法尔：出售各种|cFF00FF00一部催人泪下的言情小说|r" },
        { coord = 49453917, color = "unique", icon = 876371, text = "奸商", title = "奸商1号", info = "塔·莱克斯\n\n|cFFEE8800作者吐槽：就单纯想标记一下，比格里伏塔还过分的千金垃圾|r" },
        { coord = 43293549, color = "unique", icon = 876371, text = "奸商", title = "奸商2号", info = "塔·萨姆：出售1款家宅装饰|cFF00FF00财团收藏家的笼子|r\n\n|cFFEE8800作者吐槽：比奸商1号还过分的万金垃圾|r" },
        { coord = 39992966, color = "quartermaster", icon = 6937965, text = "升级/托拉斯◆", textA = "LEFT", title = "物品升级/卡雷什托拉斯名望军需官", info = "圣物匠赛·德斯\n\n欧·西里克：出售多款家宅装饰（|cFF4499FF共鸣水晶|r）\n\n", tags = {"quartermaster", "service"} },
        -- poi
        poiNames = {
            ["通往多恩诺嘉尔的传送门"] = { color = "portal", text = "多恩诺嘉尔" },
        },
        -- 副本
        instanceNames = {
            ["塔扎维什，帷纱集市"] = "纬纱集市",
            ["奥尔达尼生态圆顶"] = "生态园顶",
        },
        -- 地下堡
        delveNames = {
            ["虚空之锋庇护所"] = "虚空之锋庇护所",
        },
    },

    --------------------------------------------------------------------------------
    -- 银月城（至暗之夜）
    --------------------------------------------------------------------------------
    [2393] = {
        group = "SilvermoonCityMidnight",
        -- 主要
        { coord = 56467035, template = "inn", text = "旅店/烹饪◆", textA = "LEFT", title = "旅店/烹饪训练师（上层）", info = "约维娅/塞莱恩", tags = {"inn", "profession"} },
        { coord = 66916205, template = "inn", info = "德兰妮尔" },
        { coord = 51097610, template = "auction", title = "拍卖行（下层）" },
        { coord = 67617250, template = "auction" },
        { coord = 50816522, template = "bank", text = "银行◆", textA = "LEFT" },
        { coord = 72566455, template = "bank" },
        { coord = 51844855, template = "blackmarket" },
        -- 专业
        { coord = 44836038, template = "fishing", info = "德拉森" },
        { coord = 43775129, template = "blacksmithing", info = "波玛尔", isIndividual = true },
        { coord = 47985364, template = "enchanting", text = "附魔◆", textA = "LEFT", info = "多洛索斯", isIndividual = true },
        { coord = 39545100, template = "enchanting", info = "詹娜拉·日冕：教授所有|cFF00FF00欢乐幻魅|r，学习制作使用后可以变换成其他种族" },
        { coord = 43535396, template = "engineering", info = "丹文", isIndividual = true },
        { coord = 48305141, template = "herbalism", offsetY = 5, info = "植物学家娜萨兰", isIndividual = true },
        { coord = 47935515, template = "jewelcrafting", info = "埃米恩", isIndividual = true },
        { coord = 43175565, template = "leatherworking", text = "制/剥◆", textA = "LEFT", title = "制皮/剥皮训练师", info = "塔尔玛/提恩", type = {"Leatherworking", "Skinning"}, isIndividual = true },
        { coord = 42595286, template = "mining", info = "比利尔", isIndividual = true },
        { coord = 48235415, template = "tailoring", text = "◆裁缝", textA = "RIGHT", info = "贾兰娜", isIndividual = true },
        { coord = 47025187, template = "profession_mixed", text = "◆炼金/铭文", textA = "RIGHT", title = "炼金术/铭文训练师", info = "卡博隆/赞塔希娅", type = {"Alchemy", "Inscription"}, isIndividual = true },
        { coord = 45665227, template = "profession_mixed", text = "专业区", title = "各专业分布于左右两边", isAggregate = true },
        -- 专业（部落专属）
        { coord = 73297352, template = "alchemy", text = "◆炼金", textA = "RIGHT", info = "奥术师森纳瑟杭", isIndividual = true },
        { coord = 72907155, template = "enchanting", text = "附魔", info = "魔导师艾雷达妮娅", isIndividual = true },
        { coord = 72677383, template = "herbalism", text = "草药", info = "植物学家塔尼安雷尔", isIndividual = true },
        { coord = 73757124, template = "jewelcrafting", text = "◆珠宝", textA = "RIGHT", info = "奥雷妮亚", isIndividual = true },
        { coord = 69808114, template = "leatherworking", text = "制皮/剥皮◆", textA = "LEFT", title = "制皮/剥皮训练师", info = "萨瑟林/玛斯雷恩", type = {"Leatherworking", "Skinning"}, isIndividual = true },
        { coord = 70708255, template = "mining", info = "塞伦", isIndividual = true },
        { coord = 73377270, template = "tailoring", info = "女裁缝蔻妮·琥珀之光", isIndividual = true },
        { coord = 69538457, template = "profession_mixed", text = "锻造/工程◆", textA = "LEFT", title = "锻造/工程学训练师", info = "阿拉瑟尔/葛洛莉丝", type = {"Blacksmithing", "Engineering"}, isIndividual = true },
        { coord = 72887271, template = "profession_mixed", text = "专业区", title = "炼金/附魔/草药/珠宝/裁缝", isAggregate = true },
        { coord = 69808114, template = "profession_mixed", text = "专业区", title = "锻造/工程/制皮/采矿/剥皮", isAggregate = true },
        -- 其他
        { coord = 42257851, template = "barber", info = "墙上的镜子" },
        { coord = 52865743, template = "transmog", info = "织幻者迪弗尔拉" },
        { coord = 48937812, template = "tradingpost", title = "商栈（上层）", info = "珊迪·海髯/扎尔菈妮" },
        { coord = 48656203, template = "upgrade", info = "库佐尔兹（进门右手边）" },
        { coord = 45665558, template = "order", text = "功能区", title = "订单/工商/兽栏", isAggregate = true },
        { coord = 45025561, template = "order", text = "订单", title = "下达制造订单/工匠商盟军需官", info = "玛尔娜：下达制造业订单\n\n莱伦达尔：出售多款图纸配方（|cFF4499FF匠人之魄|r）", tags = {"service", "quartermaster"}, isIndividual = true },
        { coord = 52557827, color = "service", icon = 1064187, text = "◆地下堡/考古", textA = "RIGHT", title = "地下堡行者总部/考古学训练师（上层）", info = "娜蕾迪亚·流光（左）：出售地下堡钥匙/坐骑/宠物/玩具/外观/家宅装饰\n\n传送师阿斯特兰迪斯（右）：出售以下商品：\n\n坐骑|cFF00FF00银月城奥术防御者|r\n\n墓碑外观|cFF00FF00辛多雷墓碑|r\n\n玩具|cFF00FF00至暗之夜地下堡行者的信号枪|r和|cFF00FF00核心守卫的炉石|r\n\n多款家宅装饰", tags = {"service", "profession"} },
        { coord = 46355556, template = "stable", info = "塞拉菲娜·血心", isIndividual = true },
        { coord = 27267738, template = "stable", info = "沙尔蕾恩" },
        { coord = 67096610, template = "stable", info = "维奈丝特拉" },
        { coord = 44106278, template = "housing", title = "绘画大师", info = "科伦·霍德拉林/海丝塔·福尔拉斯：出售多款绘画类家宅装饰" },
        { coord = 51175645, template = "housing", info = "丹妮亚·银舌：出售多款家宅装饰\n\n纳尔·银舌：出售一款家宅装饰（|cFF4499FF虚光灰岩|r）" },
        { coord = 52504725, template = "housing", info = "德瑟琳：出售3款家宅装饰（|cFF4499FF共鸣水晶|r）" },
        { coord = 41726638, template = "look", title = "萨拉斯华服/传家宝商人", info = "安德拉：出售多款幻化套装（|cFF4499FF华服资金|r）\n\n附魔师埃罗丁（左）：出售多款传家宝" },
        { coord = 34605180, color = "unique", icon = 133739, text = "商人", title = "夺日者古董（上层）", info = "法苏娜·晴日：出售以下商品\n\n法师技能|cFF00FF00神秘宝典：奥术语言|r\n法师技能|cFF00FF00神秘宝典：幻觉|r\n法师玩具|cFF00FF00魔宠石|r" },
        { coord = 64457961, color = "unique", icon = 236439, text = "商人", title = "古董与珍玩", info = "吉娅娜女士：出售多款项链道具\n\n|cFFEE8800作者描述：格里伏塔女血精灵版|r" },
        { coord = 58657084, color = "special", icon = 626190, text = "周卓", title = "游学探奇" },
        { coord = 40386492, template = "catalyst" },
        { coord = 70088329, template = "catalyst" },
        { coord = 52187367, template = "transformation", title = "幻形讲坛（上层）" },
        { coord = 69116757, color = "quartermaster", icon = 255146, text = "银月城", title = "银月城军需官", info = "女魔导师妮萨拉：出售银月城战袍" },
        { coord = 36258449, template = "dummy" },
        -- poi
        poiNames = {
            ["传送大厅"] = { color = "portal", text = "传送" },
            ["通往时间流的传送门"] = { color = "portal", text = "时间流" },
            ["通往虚影风暴的传送门"] = { color = "portal", text = "虚影" },
            ["通往哈籁恩达尔的林根之路"] = { color = "portal", text = "哈籁恩" },
        },
        -- 副本
        instanceNames = {
            ["密谋小径"] = "密谋小径",
        },
        -- 地下堡
        delveNames = {
            ["学府骚动"] = "学府",
            ["黑暗回廊"] = "黑暗回廊",
        },
    },

    --------------------------------------------------------------------------------
    -- 千禧阈限（当前12.0 第1赛季）
    --------------------------------------------------------------------------------
    [2266] = {
        group = "TheTimeways",
        { coord = 39654857, template = "portal", icon = 135761, text = "银月城", title = "银月城传送门" },
        { coord = 64524368, template = "portal", icon = 1029581, text = "通天峰", title = "通天峰传送门" },
        { coord = 74344723, template = "portal", icon = 343641, text = "萨隆矿坑", title = "萨隆矿坑传送门" },
        { coord = 70447274, template = "portal", icon = 4578414, text = "艾杰斯亚学院", title = "艾杰斯亚学院传送门" },
        { coord = 60616928, template = "portal", icon = 1711336, text = "执政团之座", title = "执政团之座传送门" },
        { coord = 50214660, template = "dummy" },
        { coord = 48215796, template = "dummy" },
    },

    -- =============================================================================
    -- 区域
    -- =============================================================================
    --------------------------------------------------------------------------------
    -- 暗月马戏团
    --------------------------------------------------------------------------------
    [407] = {
        group = "Darkmoonfaire",
        { coord = 51232314, template = "portal", text = "回程", title = "回程传送门" },
        { coord = 48086953, template = "mount", text = "藏品", title = "宠物与坐骑", info = "兰拉：出售3款坐骑和7款宠物" },
        { coord = 47766478, template = "toy", title = "纪念品与玩具商人", info = "吉瓦斯·格里加特：出售玩具/幻化/道具|cFF00FF00暗月大礼帽（10%经验加成）|r" },
        { coord = 54335316, color = "vendor", icon = 531974, text = "代币", title = "游戏代币商人", info = "吉娜·沙普沃斯" },
        { coord = 48906175, color = "vendor", icon = 531974, text = "代币", offsetY = -5, title = "游戏代币商人", info = "沙兹·吃币" },
        { coord = 48947571, color = "vendor", icon = 531974, text = "代币", title = "游戏代币商人", info = "崔克西·沙普沃斯" },
        { coord = 54675867, color = "vendor", icon = 134481, text = "门票", title = "过山车", info = "狄玫：对话购买门票，坐过山车可获得10%经验加成，最高持续1小时" },
        { coord = 50475932, color = "vendor", icon = 134481, text = "门票", title = "旋转木马", info = "狄珂：对话购买门票，坐旋转木马可获得10%经验加成，最高持续1小时" },
        { coord = 51497508, template = "look", info = "切斯特：出售几款|cFF00FF00礼服幻化|r和玩具|cFF00FF00见鬼的纪念品|r" },
        { coord = 47676672, template = "heirloom", text = "传家宝/套装◆", textA = "LEFT", title = "传家宝/幻化套装兑换", info = "迪兰德·晨峰/巴伦姆/巴伦玛" },
        { coord = 36545797, color = "unique", icon = 134757, text = "墨黑药水◆", textA = "LEFT", title = "墨黑药水商人", info = "罗纳·绿齿：出售|cFF00FF00墨黑药水|r，使周围变黑2小时，可在场景过亮时使用" },
        { coord = 48287194, color = "unique", icon = 134289, text = "焰火", title = "焰火商人", info = "波米·斯巴克：出售玩具|cFF00FF00XL号烟火小马|r" },
        { coord = 52518874, color = "unique", icon = 237302, text = "◆钓鱼商人", textA = "RIGHT", title = "钓鱼奖品", info = "格丽萨·日露：出售坐骑|cFF00FF00暗水鳐鱼|r/玩具|cFF00FF00航海家的滑哨|r/暗月火酒/2款宠物和几款食谱（|cFF4499FF暗月刃喉鱼|r）" },
        { coord = 51896092, color = "special", icon = 236669, text = "考古", title = "考古任务/暗月卡牌兑换", info = "萨杜斯·帕雷教授（考古材料：|cFF00FF00化石碎片x15|r）" },
        { coord = 50536956, color = "special", icon = 236669, text = "炼金", title = "炼金任务", info = "塞兰妮亚（炼金材料：|cFF00FF00月莓汁x5，泡沫饮料x5|r）" },
        { coord = 51108206, color = "special", icon = 236669, text = "锻造", title = "锻造任务", info = "亚布·尼比盖尔（锻造材料：|cFF00FF00铁砧x1|r）" },
        { coord = 52916792, color = "special", icon = 236669, text = "◆烹饪/钓鱼", textA = "RIGHT", title = "烹饪/钓鱼任务", info = "斯塔姆·雷角（烹饪材料：|cFF00FF00面粉x5|r）" },
        { coord = 53237585, color = "special", icon = 236669, text = "◆附魔/铭文", textA = "RIGHT", title = "附魔/铭文任务", info = "塞恪（铭文材料：|cFF00FF00轻羊皮纸x5|r）" },
        { coord = 49256079, color = "special", icon = 236669, text = "工程/制皮/采矿◆", textA = "LEFT", title = "工程/制皮/采矿任务", info = "瑞林（制皮材料：|cFF00FF00蓝色染料x5，闪光的小珠x10，粗线x5|r）" },
        { coord = 55007078, color = "special", icon = 236669, text = "◆珠宝/草药/剥皮", title = "珠宝/草药/剥皮任务", info = "克洛诺斯", textA = "RIGHT" },
        { coord = 55565500, color = "special", icon = 236669, text = "裁缝", title = "裁缝任务", info = "萨琳娜·杜洛曼（裁缝材料：|cFF00FF00红色染料x1，蓝色染料x1，粗线x1|r）" },
    },

    [7] = {  -- 暗月马戏团：莫高雷入口
        group = "Darkmoonfaire",
        { coord = 36843586, color = "portal", icon = 669449, text = "暗月马戏团", title = "入口传送门（每月一次）", info = "专业任务材料准备：\n\n考古：|cFF00FF00化石碎片x15|r\n\n炼金：|cFF00FF00月莓汁x5，泡沫饮料x5|r\n\n锻造：|cFF00FF00铁砧x1|r\n\n烹饪：|cFF00FF00面粉x5|r\n\n铭文：|cFF00FF00轻羊皮纸x5|r\n\n制皮：|cFF00FF00蓝色染料x5，闪光的小珠x10，粗线x5|r\n\n裁缝：|cFF00FF00红色染料x1，蓝色染料x1，粗线x1|r" }
    },

    [37] = {  -- 暗月马戏团：闪金镇入口
        group = "Darkmoonfaire",
        { coord = 41796948, color = "portal", icon = 669449, text = "暗月马戏团", title = "入口传送门（每月一次）", info = "专业任务材料准备：\n\n考古：|cFF00FF00化石碎片x15|r\n\n炼金：|cFF00FF00月莓汁x5，泡沫饮料x5|r\n\n锻造：|cFF00FF00铁砧x1|r\n\n烹饪：|cFF00FF00面粉x5|r\n\n铭文：|cFF00FF00轻羊皮纸x5|r\n\n制皮：|cFF00FF00蓝色染料x5，闪光的小珠x10，粗线x5|r\n\n裁缝：|cFF00FF00红色染料x1，蓝色染料x1，粗线x1|r" }
    },

    --------------------------------------------------------------------------------
    -- 卡兹阿加
    --------------------------------------------------------------------------------
    [2248] = {  -- 多恩岛
        group = "IsleofDorn",
        -- maplink
        maplinkNames = {
            ["喧鸣深窟"] = "喧鸣深窟",
        },
        -- 副本
        instanceNames = {
            ["驭雷栖巢"] = "驭雷栖巢",
            ["燧酿酒庄"] = "燧酿酒庄",
        },
        -- 地下堡
        delveNames = {
            ["克莱格瓦之眠"] = "克莱格瓦之眠",
            ["真菌之愚"] = "真菌之愚",
            ["地匍矿洞"] = "地匍矿洞",
        },
    },

    [2214] = {  -- 喧鸣深窟
        group = "TheRingingDeeps",
        -- 传送
        { coord = 72957320, icon = 2011121, text = "安德麦", title = "安德麦深沟钻机", info = "斯黛里亚：通往安德麦", color = "portal" },
        { coord = 44386614, icon = 450906, text = "艾基卡赫特通道", title = "通往艾基卡赫特的通道", color = "portal" },
        -- poi
        poiNames = {
            ["前往海妖岛的钻探机"] = { color = "portal", text = "海妖岛" },
            ["冈达加兹"] = { color = "quartermaster", text = "邃渊协盟" },
        },
        -- maplink
        maplinkNames = {
            ["多恩岛"] = "多恩岛",
            ["陨圣峪"] = "陨圣峪",
        },
        -- 副本
        instanceNames = {
            ["矶石宝库"] = "矶石宝库",
            ["暗焰裂口"] = "暗焰裂口",
            ["水闸行动"] = "水闸行动",
        },
        -- 地下堡
        delveNames = {
            ["恐惧陷坑"] = "恐惧陷坑",
            ["水能堡"] = "水能堡",
            ["九号挖掘场"] = "九号挖掘场",
        },
    },

    [2215] = {  -- 陨圣峪
        group = "Hallowfall",
        -- 传送
        { coord = 38297385, color = "portal", icon = 450905, text = "艾基卡赫特通道", title = "通往艾基卡赫特的通道" },
        { coord = 76706819, color = "portal", icon = 450905, text = "艾基卡赫特通道", title = "通往艾基卡赫特的通道" },
        -- poi
        poiNames = {
            ["米雷达尔"] = { color = "quartermaster", text = "陨圣峪阿拉希人" },
        },
        -- maplink
        maplinkNames = {
            ["喧鸣深窟"] = "喧鸣深窟",
            ["多恩岛"] = "多恩岛",
        },
        -- 副本
        instanceNames = {
            ["圣焰隐修院"] = "圣焰隐修院",
            ["破晨号"] = "破晨号",
            ["暗焰裂口"] = "暗焰裂口",
            ["水闸行动"] = "水闸行动",
        },
        -- 地下堡
        delveNames = {
            ["夜幕圣所"] = "夜幕圣所",
            ["无底沉穴"] = "无底沉穴",
            ["飞掠裂口"] = "飞掠裂口",
            ["丝菌师洞穴"] = "丝菌师洞穴",
        },
    },

    [2255] = {  -- 艾基卡赫特
        group = "AzjKahet",
        -- 传送
        { coord = 25623158, color = "portal", icon = 450907, text = "陨圣峪通道", title = "通往陨圣峪的通道" },
        { coord = 65221273, color = "portal", icon = 450907, text = "陨圣峪通道", title = "通往陨圣峪的通道" },
        { coord = 73452200, color = "portal", icon = 450908, text = "喧鸣深窟通道", title = "通往喧鸣深窟的通道" },
        poiNames = {
            ["通往多恩诺嘉尔的传送门"] = { color = "portal", text = "多恩诺嘉尔" },
            ["纺丝者之巢"] = { color = "quartermaster", text = "斩离之丝" },
        },
        -- 副本
        instanceNames = {
            ["千丝之城"] = "千丝之城",
            ["艾拉-卡拉，回响之城"] = "回响之城",
            ["尼鲁巴尔王宫"] = "尼鲁巴尔王宫",
        },
        -- 地下堡
        { coord = 34097695, color = "delve", icon = 5779390, text = "泽克维尔的巢穴◆", textA = "LEFT", title = "宿敌地下堡" },
        delveNames = {
            ["螺旋织纹"] = "螺旋织纹",
            ["塔克-雷桑深渊"] = "塔克雷桑深渊",
            ["幽暗要塞"] = "幽暗要塞",
        },
        
    },

    [2371] = {  -- 卡雷什
        group = "KAresh",
        -- 其他
        { coord = 50363630, color = "special", icon = 135752, text = "披风/相位◆", textA = "LEFT", title = "雷什裹布升级员/相位潜行商人", info = "哈希姆：领取披风及披风升级（|cFF4499FF虚灵丝线|r）\n\n莎德安妮丝：出售多款坐骑/宠物/幻化套装/玩具（|cFF4499FF无拘钱币|r）" },
        { coord = 41972253, color = "quartermaster", icon = 6997112, text = "破袭队", offsetY = -5, title = "法力熔炉破袭队名望军需官", info = "收购者巴·赛欧姆（左1）：出售团本法力熔炉：欧米伽套装（|cFF4499FF饥渴虚空珍玩|r）\n\n巴·丘索（左2）：出售团本法力熔炉：欧米伽披风外观（|cFF4499FF织丝兽的流丝官|r）\n\n佐·图鲁（右1）：查看名望等级\n\n佐·罗伯（右2）：出售团本法力熔炉：欧米伽武器外观（|cFF4499FF虚灵精华残缕|r）", tags = {"quartermaster", "vendor"} },
        -- poi
        poiNames = {
            ["通往多恩诺嘉尔的传送门"] = { color = "portal", text = "多恩诺嘉尔" },
            ["塔扎维什，帷纱集市"] = { color = "quartermaster", text = "卡雷什托拉斯" },
        },
        -- 副本
        instanceNames = {
            ["塔扎维什，帷纱集市"] = "纬纱集市",
            ["奥尔达尼生态圆顶"] = "生态园顶",
            ["法力熔炉：欧米伽"] = "法力熔炉",
        },
        -- 地下堡
        delveNames = {
            ["档案馆突袭"] = "档案馆突袭",
            ["虚空之锋庇护所"] = "虚空之锋庇护所",
        },
    },

    --------------------------------------------------------------------------------
    -- 奎尔萨拉斯
    --------------------------------------------------------------------------------
    [2395] = {  -- 永歌森林
        group = "EversongWoods",
        -- 其他
        { coord = 41907970, color = "special", icon = 4620680, text = "威风", title = "幽灵之爪", info = "掉落|cFF00FF00威风之爪|r和|cFF00FF00威风皮毛|r" },
        { coord = 43474745, color = "quartermaster", icon = 4880695, text = "银月宫廷", title = "银月宫廷军需官", info = "凯瑞斯·善晨：\n出售多款幻化套装/技能配方/坐骑/宠物/玩具/家宅装饰（|cFF4499FF虚光灰岩|r和|cFF4499FF匠人之魄|r）\n\n以下4个子阵营军需官均出售：\n名望战袍/3套幻化套装/武器幻化/家宅装饰/家宅装饰配方（|cFF4499FF虚光灰岩|r和|cFF4499FF匠人之魄|r）\n\n血骑士军需官：铸甲师金冠\n魔导士军需官：学徒戴尔\n远行者军需官：游侠阿洛隆恩\n径巷之影军需官：奈里夫\n\n装饰专家萨斯雷·蓝空：出售多款银月城风格家宅装饰（|cFF4499FF虚光灰岩|r）" },
        -- 副本
        instanceNames = {
            ["风行者之塔"] = "风行者之塔",
        },
        -- 地下堡
        delveNames = {
            ["学府骚动"] = "学府骚动",
            ["黑暗回廊"] = "黑暗回廊",
            ["聚影领地"] = "聚影领地",
            ["阿塔阿曼"] = "阿塔阿曼",
        },
    },

    [2405] = {  -- 虚影风暴
        group = "Voidstorm",
        -- 传送
        { coord = 33946060, color = "portal", text = "银月城" },
        { coord = 45436376, color = "portal", text = "奎岛" },
        -- 其他
        { coord = 43008300, color = "special", icon = 4620680, text = "究极", title = "虚空飞镰", info = "掉落|cFF00FF00威风之爪|r、|cFF00FF00威风皮毛|r和|cFF00FF00威风尾翼|r" },
        { coord = 54006500, color = "special", icon = 4620680, text = "威风", title = "幽齿", info = "掉落|cFF00FF00威风之爪|r和|cFF00FF00威风皮毛|r" },
        { coord = 52587290, icon = 7141549, text = "奇点特勤◆", title = "奇点特勤军需官", info = "虚空研究者阿诺曼达尔：出售多款幻化套装/技能配方/坐骑/宠物/玩具/家宅装饰（|cFF4499FF虚光灰岩|r和|cFF4499FF匠人之魄|r）", color = "quartermaster", textA = "LEFT" },
        -- poi
        poiNames = {
            ["通往银月城和哈籁恩达尔的传送门"] = { color = "portal", text = "银月/哈籁恩" },
        },
        -- 副本
        instanceNames = {
            ["虚空之痕竞技场"] = "虚空之痕竞技场",
            ["节点希纳斯"] = "节点希纳斯",
            ["虚影尖塔"] = "虚影尖塔",
        },
        -- 地下堡
        delveNames = {
            ["影卫营"] = "影卫营",
            ["戮日圣殿"] = "戮日圣殿",
            ["磨难高地"] = "磨难高地",
        },
    },

    [2444] = {  -- 虚影风暴：屠戮者高地
        group = "Voidstorm",
        -- 副本
        instanceNames = {
            ["虚空之痕竞技场"] = "虚空之痕竞技场",
        },
        -- 地下堡
        delveNames = {
            ["戮日圣殿"] = "戮日圣殿",
        },
    },

    [2424] = {  -- 奎尔丹纳斯岛
        group = "IsleofQuelDanas",
        -- 传送
        { coord = 51935638, color = "portal", icon = 7507880, text = "虚影", title = "虚影风暴传送门" },
        -- 副本
        instanceNames = {
            ["魔导师平台"] = "魔导师平台",
            ["进军奎尔丹纳斯"] = "进军奎尔丹纳斯",
        },
        -- 地下堡
        delveNames = {
            ["幻日广场"] = "幻日广场",
        },
    },

    [2437] = {  -- 祖阿曼
        group = "ZulAman",
        -- 其他
        { coord = 47805310, color = "special", icon = 4620680, text = "威风", title = "银鳞", info = "掉落|cFF00FF00威风之爪|r" },
        { coord = 43196925, color = "special", icon = 7491473, text = "祭坛", title = "祝福祭坛", info = "和祝福祭坛交互，可以切换神灵祝福" },
        -- poi
        poiNames = {
            ["阿曼尼扎村"] = { color = "quartermaster", text = "阿曼尼部族" },
        },
        -- 副本
        instanceNames = {
            ["迈萨拉洞窟"] = "迈萨拉洞窟",
            ["纳洛拉克的洞穴"] = "纳洛拉克",
        },
        -- 地下堡
        delveNames = {
            ["聚影领地"] = "聚影领地",
            ["阿塔阿曼"] = "阿塔阿曼",
            ["暮光地穴"] = "暮光地穴",
        },
    },

    [2413] = {  -- 哈籁恩达尔
        group = "Harandar",
        -- 其他
        { coord = 49255433, color = "unique", icon = 133852, text = "明光之尘◆", textA = "LEFT", title = "明光之尘商人", info = "养蛾人威塔姆：出售7款武器幻化/2款坐骑/3款家宅装饰（|cFF4499FF明光之尘|r）" },
        { coord = 66704760, color = "special", icon = 4620680, text = "威风", title = "流明之鳍", info = "掉落|cFF00FF00威风尾翼|r" },
        -- poi
        poiNames = {
            ["大巢穴"] = { color = "quartermaster", text = "哈籁提" },
        },
        -- 副本
        instanceNames = {
            ["夺目谷"] = "夺目谷",
            ["梦境裂隙"] = "梦境裂隙",
        },
        -- 地下堡
        delveNames = {
            ["回忆深沟"] = "回忆深沟",
            ["憎怨斗坑"] = "憎怨斗坑",
        },

    },

    [2576] = {  -- 哈籁恩达尔：大巢穴
        group = "TheDen",
        -- 传送
        { coord = 61797348, color = "portal", icon = 7507880, text = "虚影", title = "虚影风暴传送门" },
        -- 主要
        { coord = 65436193, template = "inn", info = "尤纳" },
        -- 专业
        { coord = 63627386, template = "inscription", info = "鲁卡尔，祖尔阿沙" },
        { coord = 62693439, template = "housing", info = "玛库：出售多款哈籁恩达尔风格家宅装饰" },
        -- poi
        poiNames = {
            ["永歌林根之路"] = { color = "portal", text = "银月城" },
        },
    },
}