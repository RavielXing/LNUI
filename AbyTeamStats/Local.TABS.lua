local _, TS = ...

TS.DATA_VERSION = 20260731

-- 更新方法：https://wago.tools/db2/Achievement?locale=zhCN
-- 插件有对比成就（GetAchievementComparisonInfo）和对比统计（GetComparisonStatistic）两种入库方法
-- AchievementID负值代表对比成就，正值代表对比统计
-- 对比成就可获取战网下成就具体获取日期，对比统计可获取特定角色的完成次数

-- 总览数据 引领潮流
TS.VERSION_BOSSES = { -63651, "乌" }

--总览数据 钥石分数成就
local FIRST_TAB = {
    tab = "总览",
    ids = { -62447, -62448, -62449,}, 
    widths = { 54, 54, 54,},
    names = { "S2大师", "S2英雄", "S2传奇", },
    tips = { "钥石大师（账号共享，任意角色钥石2000分）", "钥石英雄（账号共享，任意角色钥石2500分）", "钥石传奇（账号共享，任意角色钥石3000分）",},
    reports = { false, false, false, },
}

-- 总览数据 团本1 
-- { "首领战", 普通id, 英雄id, { 史诗id, -史诗成就id, }, },

local INSTANCES = {
    {
        bosses = {
            { "盘魂者内克扎莉", 63534, 63535, { 63536, -63523, }, },
            { "陵寝哨兵", 63538, 63539, { 63540, -63524, }, },
            { "万毒邪祟者瓦什尼克", 63555, 63556, { 63557, -63526, }, },
            { "迷失的探险者", 63552, 63553, { 63554, -63525, }, },
            { "斯索拉克", 63558, 63559, { 63560, -63527, }, },
            { "双子毒牙", 63561, 63562, { 63563, -63528, }, },
            { "盘卷祭坛", 63564, 63565, { 63566, -63529, }, },
            { "乌拉特克", 63567, 63568, { 63569, -63476, }, },
        },
        diff = { "烈毒之渊", "英雄", "史诗", },
        tab = "烈毒之渊",
    },
}

local INSTANCES2 = {
    {
        bosses = {
            { "尼姆瑞莎·唤波者", 63614, 63615, { 63616, -63682, }, },
        },
        diff = { "潮缚石窟", "英雄", "史诗", },
        tab = "巢穴",
    },
}

-- 预留INSTANCES3
-- local INSTANCES3 = {
    -- {
        -- bosses = {
            -- { "贝洛朗，奥的子嗣", 61301, 61302, { 61303, -61378, }, },
            -- { "至暗之夜降临", 61305, 61306, { 61307, -61379, }, },
        -- },
        -- diff = { "奎尔丹纳斯", "英雄", "史诗", },
        -- tab = "进军奎尔丹纳斯",
    -- },
-- }


-- 建表 总览，添加数据
local TABS = {}

do
    local tab = FIRST_TAB
    local one = { ids = {}, names = {}, tips = {}, tab = tab.tab, widths = {}, reports = {} }
    for i = 1, #tab.ids do
        if tab.names[i] and #tab.names[i] > 0 then
            one.ids[i] = tab.ids[i]
            one.names[i] = tab.names[i]
            one.tips[i] = tab.tips[i]
            one.widths[i] = tab.widths[i]
            one.reports[i] = tab.reports[i]
        end
    end

    for i, ins in ipairs(INSTANCES) do
        for j, diff in ipairs(ins.diff) do
            if diff and #diff > 0 then
                local bosses = {}
                for k = 1, #ins.bosses do
                    bosses[k] = ins.bosses[k][j + 1]
                end
                table.insert(one.ids, bosses)
                table.insert(one.names, diff)
                table.insert(one.reports, ins.report == nil and true or ins.report)
                table.insert(one.widths, 63)
            end
        end
    end

    for i, ins in ipairs(INSTANCES2) do
        for j, diff in ipairs(ins.diff) do
            if diff and #diff > 0 then
                local bosses = {}
                for k = 1, #ins.bosses do
                    bosses[k] = ins.bosses[k][j + 1]
                end
                table.insert(one.ids, bosses)
                table.insert(one.names, diff)
                table.insert(one.reports, ins.report == nil and true or ins.report)
                table.insert(one.widths, 63)
            end
        end
    end
	
-- 预留INSTANCES3
    -- for i, ins in ipairs(INSTANCES3) do
        -- for j, diff in ipairs(ins.diff) do
            -- if diff and #diff > 0 then
                -- local bosses = {}
                -- for k = 1, #ins.bosses do
                    -- bosses[k] = ins.bosses[k][j + 1]
                -- end
                -- table.insert(one.ids, bosses)
                -- table.insert(one.names, diff)
                -- table.insert(one.reports, ins.report == nil and true or ins.report)
                -- table.insert(one.widths, 63)
            -- end
        -- end
    -- end

    tinsert(TABS, one)
end

-- 添加表2，史诗钥石评分
local tip = "副本评分(最高层数), 绿色限时, 灰色超时"
table.insert(TABS, {
    tab = DUNGEON_SCORE, --"史诗钥石评分"
    special = "season_mythic",
    specialIDs = { 0, 588, 587, 586, 584, 585, 249, 399, 250,}, --MapChallengeMode
    widths = { 60, 60, 60, 60, 60, 60, 60, 60, 60, },
    tips = { "", tip, tip, tip, tip, tip, tip, tip, tip, },
    names = { "钥石评分", "毒牙", "密谋", "洞穴", "夺目", "竞技场", "诸王", "红玉", "神庙",},
})--S3

-- 添加表3，千钧一发 Cutting Edge
table.insert(TABS, {
    tab = "千钧一发",
    any_done = true,
    dynamic_columns = true, -- 新增标志，表示动态生成列
    ids = {
        {-63651}, {-61625}, {-61492}, {-61627}, --12.0
        {-41625}, {-41297}, {-40254}, --11.0
        {-19351}, {-18254}, {-17108}, --10.0
        {-15471}, {-15135}, {-14461}, --9.0
        {-14069}, {-13785}, {-13419}, {-13323}, {-12535}, --8.0
        {-12111}, {-11875}, {-11192}, {-11580}, {-11191}, --7.0
        {-10045}, {-9443}, {-9442}, --6.0
        {-8401, -8400}, {-8260}, {-8238}, {-7487}, {-7486}, {-7485}, --5.0
    },
    widths = { 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, },
    tips = {
        "千钧一发：乌拉特克|n|cff19CCF9烈毒之渊|r",
        "千钧一发：宇宙之冕|n|cff19CCF9虚影尖塔|r",
        "千钧一发：奇美鲁斯，未梦之神|n|cff19CCF9梦境裂隙|r",
        "千钧一发：至暗之夜降临|n|cff19CCF9进军奎尔丹纳斯|r",
        "千钧一发：诸界吞噬者迪门修斯|n|cff19CCF9法力熔炉：欧米茄|r",
        "千钧一发：铬武大王加里维克斯|n|cff19CCF9解放安德麦|r",
        "千钧一发：安苏雷克女王|n|cff19CCF9尼鲁巴尔王宫|r",
        "千钧一发：火光之龙菲莱克|n|cff19CCF9阿梅达希尔，梦境之愿|r",
        "千钧一发：鳞长萨卡雷斯|n|cff19CCF9亚贝鲁斯，焰影熔炉|r",
        "千钧一发：莱萨杰丝，噬雷之龙|n|cff19CCF9化身巨龙牢窟|r",
        "千钧一发：典狱长|n|cff19CCF9初诞者圣墓|r",
        "千钧一发：希尔瓦娜斯·风行者|n|cff19CCF9统御圣所|r",
        "千钧一发：德纳修斯大帝|n|cff19CCF9纳斯利亚堡|r",
        "千钧一发：腐蚀者恩佐斯|n|cff19CCF9尼奥罗萨，觉醒之城|r",
        "千钧一发：艾萨拉女王|n|cff19CCF9永恒王宫|r",
        "千钧一发：乌纳特，虚空先驱|n|cff19CCF9风暴熔炉|r",
        "千钧一发：吉安娜·普罗德摩尔|n|cff19CCF9达萨罗之战|r",
        "千钧一发：戈霍恩|n|cff19CCF9奥迪尔|r",
        "千钧一发：寂灭者阿古斯|n|cff19CCF9安托鲁斯，燃烧王座|r",
        "千钧一发：基尔加丹|n|cff19CCF9萨格拉斯之墓|r",
        "千钧一发：古尔丹|n|cff19CCF9暗夜要塞|r",
        "千钧一发：海拉|n|cff19CCF9勇气试炼|r",
        "千钧一发：萨维斯|n|cff19CCF9翡翠梦魇|r",
        "千钧一发：黑暗之门|n|cff19CCF9地狱火堡垒|r",
        "千钧一发：黑手的熔炉|n|cff19CCF9黑石铸造厂|r",
        "千钧一发：元首之陨|n|cff19CCF9悬槌堡|r",
        "千钧一发：加尔鲁什·地狱咆哮（10人或25人）|n|cff19CCF9决战奥格瑞玛|r",
        "千钧一发：莱登|n|cff19CCF9雷电王座|r",
        "千钧一发：雷神|n|cff19CCF9雷电王座|r",
        "千钧一发：惧之煞|n|cff19CCF9永春台|r",
        "千钧一发：大女皇夏柯希尔|n|cff19CCF9恐惧之心|r",
        "千钧一发：皇帝的意志|n|cff19CCF9魔古山宝库|r",
    },
    names = {
        "乌拉特克", "宇宙之冕", "奇美鲁斯", "至暗之夜", --12.0
        "迪门修斯", "加里维克", "安苏雷克", --11.0
        "菲莱克", "鳞长", "噬雷之龙", --10.0
        "典狱长", "希尔瓦娜", "德纳修斯", --9.0
        "恩佐斯", "艾萨拉", "乌纳特", "吉安娜", "戈霍恩", --8.0
        "阿古斯", "基尔加丹", "古尔丹", "海拉", "萨维斯", --7.0
        "阿克蒙德", "黑手", "马尔高克", --6.0
        "加尔鲁什", "莱登","雷神", "惧之煞", "夏柯希尔", "皇帝意志" --5.0
    },
})

-- 鼠标移到统计项目上 /run a=GetMouseFocus().id print(a, GetAchievementInfo(a))

-- 添加表4，坚韧钥石 Resilient Keystones
local ResilientTip = "钥石坚韧等级（铁钥匙），钥石等级不会降低至相应层数之下|n|cff19CCF9此数据为角色所属战网下的最高进度，可能并非角色本身的坚韧等级，建议根据史诗钥石分数综合进行判断|r"
table.insert(TABS, {
    tab = "坚韧钥石（第2赛季）",
    dynamic_columns = true, -- 新增标志，表示动态生成列
    ids = {0, -62417, -62418, -62419, -62420, -62421, -62422, -62423, -62424, -62425, -62426, -62427, -62428, -62429, -62430, -62431, -62432, -62433, -62434, -62435}, 
    widths = {60, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48,},
    names = {"钥石评分", "12","13","14","15","16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30",},
    tips = {
        "当前赛季的大秘境总评分",
        ResilientTip, ResilientTip, ResilientTip, ResilientTip,
        ResilientTip, ResilientTip, ResilientTip, ResilientTip, ResilientTip,
        ResilientTip, ResilientTip, ResilientTip, ResilientTip, ResilientTip,
        ResilientTip, ResilientTip, ResilientTip, ResilientTip, ResilientTip,
    },
})

TS.TABS = TABS
for _, v in ipairs(TABS) do v.numCols = #(v.specialIDs or v.ids) end