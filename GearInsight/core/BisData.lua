-- BisData.lua
-- Live BiS data from WarcraftLogs V2 -- WarcraftLogs V2 — Zone 53 (烈毒之渊 S2), Mythic
-- Generated: 2026-09-27 | 40 specs | 2993 items

GearInsight = GearInsight or {}

local BisData = {
    version = "0.5.112-live",
    updatedAt = "2026-09-27",
    source = "WarcraftLogs V2 — Zone 53 (烈毒之渊 S2), Mythic — auto-fetched",

    -- Stat display colors for progress bars
    statMeta = {
        crit   = { label = "Crit",   color = { r = 1.0, g = 0.2, b = 0.2 } },
        haste  = { label = "Haste",  color = { r = 0.2, g = 0.8, b = 0.2 } },
        mastery = { label = "Mastery", color = { r = 0.2, g = 0.4, b = 1.0 } },
        versatility = { label = "Versatility", color = { r = 0.8, g = 0.6, b = 0.2 } },
    },

    -- Source category display labels
    sourceCategories = {
        raid    = "团本",
        mplus   = "钥石",
        crafted = "制造",
        world   = "世界",
        other   = "其他",
    },
}

BisData.consumables = {
    { category = "合剂", name = "萨拉斯抗性合剂", icon = "inv_12_profession_alchemy_flask_sindoreipotion_yellow", stat = "versatility", itemId = 241320 },
    { category = "合剂", name = "魔导师合剂", icon = "inv_12_profession_alchemy_flask_sindoreipotion_black", stat = "mastery", itemId = 241322 },
    { category = "合剂", name = "血骑士合剂", icon = "inv_12_profession_alchemy_flask_sindoreipotion_white", stat = "haste", itemId = 241324 },
    { category = "合剂", name = "破碎残阳合剂", icon = "inv_12_profession_alchemy_flask_sindoreipotion_red", stat = "crit", itemId = 241326 },
    { category = "合剂", name = "萨拉斯荣誉勇猛合剂", icon = "inv_potionf_4", itemId = 241334 },
    { category = "药水", name = "圣光潜力", icon = "", itemId = 241308 },
    { category = "药水", name = "熵能萃取物", icon = "inv_alchemy_70_potion2_nightborne", itemId = 268954 },
    { category = "药水", name = "鲁莽药水", icon = "inv_12_profession_alchemy_voidpotion_red", itemId = 241288 },
    { category = "药水", name = "狂放恣意饮剂", icon = "inv_12_profession_alchemy_voidpotion_purple", itemId = 241292 },
    { category = "药水", name = "吞噬之梦药水", icon = "inv_12_profession_alchemy_voidpotion_blue", itemId = 241295 },
    { category = "药水", name = "虚空遮蔽酊剂", icon = "inv_12_profession_alchemy_voidpotion_violet", itemId = 241302 },
    { category = "药水", name = "圣光之护", icon = "inv_alchemy_80_potion02yellow", itemId = 241287 },
    { category = "药水", name = "狂热药水", icon = "inv_12_profession_alchemy_lightpotion_green", itemId = 241296 },
    { category = "药水", name = "银月城生命药水", icon = "inv_12_profession_alchemy_lightpotion_orange", itemId = 241304 },
    { category = "药水", name = "复苏血清", icon = "inv_alchemy_80_potion01purple", itemId = 241307 },
    { category = "武器油", name = "萨拉斯凤凰之油", icon = "", itemId = 243734 },
    { category = "武器油", name = "黎明之油", icon = "", itemId = 243736 },
    { category = "武器油", name = "私运者的附魔之锋", icon = "", itemId = 243738 },
    { category = "食物", name = "丰盛大餐", icon = "inv_misc_food_legion_heartyfeast", itemId = 228721, tier = "hearty" },
    { category = "食物", name = "丰盛食物", icon = "inv_tradeskill_cooking_feastofblood", itemId = 222693, tier = "hearty" },
    { category = "食物", name = "奎尔多雷拼盘", icon = "inv_cooking_10_draconicdelicacies", itemId = 242272 },
    { category = "食物", name = "盛放筵席", icon = "inv_misc_food_cooked_greatpabanquet_wok", itemId = 242273 },
    { category = "食物", name = "哈籁恩达尔庆典大餐", icon = "inv_misc_1h_soup_b_01_misc_1h_soup_b_01", itemId = 255846 },
    { category = "食物", name = "银月城浮华大餐", icon = "inv_tradeskill_cooking_feastofblood", itemId = 255845 },
    { category = "食物", name = "勇士便当", icon = "inv_misc_food_vendor_poundedricecake_1", itemId = 242274, tier = "single_main" },
    { category = "食物", name = "皇家烤肉", icon = "inv_cooking_100_roastduck", itemId = 242275, tier = "single_main" },
    { category = "食物", name = "异乎寻常的皇家烤肉", icon = "inv_cooking_100_roastduck", itemId = 255847, tier = "single_main" },
    { category = "食物", name = "植物狂宴", icon = "inv_cooking_100_sidesalad_color04", itemId = 255848, tier = "single_main" },
    { category = "食物", name = "红烧鲜血猎手", icon = "inv_misc_food_legion_fishbrulspecial", stat = "versatility", itemId = 242276, tier = "single" },
    { category = "食物", name = "赤红炸鱿鱼", icon = "inv_misc_food_cooked_valleystirfry", itemId = 242277, tier = "single" },
    { category = "食物", name = "美味熏脂鲤", icon = "inv_cooking_100_revengeservedcold", itemId = 242278, tier = "single" },
    { category = "食物", name = "黄油根须蟹", icon = "inv_misc_food_draenor_steamedscorpion", itemId = 242280, tier = "single" },
    { category = "食物", name = "闪光烤串", icon = "inv_cooking_100_roastduck", itemId = 242281, tier = "single" },
    { category = "食物", name = "虚无空盘餐", icon = "inv_cooking_100_roastduck", stat = "haste", itemId = 242282, tier = "single" },
    { category = "食物", name = "阳灼光鳍鱼", icon = "inv_misc_food_legion_fishbrulspecial", stat = "crit", itemId = 242283, tier = "single" },
    { category = "食物", name = "虚吻鱼肉卷", icon = "inv_cooking_100_roastduck", itemId = 242284, tier = "single" },
    { category = "食物", name = "迁跃睿心鱼翅", icon = "inv_cooking_100_roastduck", stat = "mastery", itemId = 242285, tier = "single" },
    { category = "食物", name = "邪吻肉柳", icon = "inv_cooking_100_roastduck", stat = "haste", itemId = 242286, tier = "single" },
    { category = "食物", name = "奥能肉饼", icon = "inv_cooking_100_roastduck", itemId = 242287, tier = "single" },
}

BisData.consumableUsage = {
    ["DEATHKNIGHT/BLOOD"] = { raid={ haste=54.1, crit=27.0, mastery=10.8, versatility=2.7, food=97.3, foodHearty=81.1, foodWellFed=16.2, rune=16.2, n=37 }, mplusHigh={ haste=60.5, versatility=21.1, crit=10.5, mastery=7.9, food=100.0, foodHearty=100.0, foodWellFed=0.0, rune=0.0, n=38 }, mplusFarm={ haste=52.6, crit=23.7, versatility=15.8, mastery=5.3, food=78.9, foodHearty=31.6, foodWellFed=47.4, rune=15.8, n=38 } },
    ["DEATHKNIGHT/FROST"] = { raid={ mastery=60.5, crit=31.6, haste=7.9, food=97.4, foodHearty=78.9, foodWellFed=18.4, rune=26.3, n=38 }, mplusHigh={ mastery=75.0, crit=22.5, haste=2.5, food=100.0, foodHearty=80.0, foodWellFed=20.0, rune=15.0, n=40 }, mplusFarm={ mastery=62.5, crit=32.5, haste=5.0, food=97.5, foodHearty=30.0, foodWellFed=67.5, rune=25.0, n=40 } },
    ["DEATHKNIGHT/UNHOLY"] = { raid={ mastery=59.5, crit=35.1, haste=5.4, food=100.0, foodHearty=83.8, foodWellFed=16.2, rune=32.4, n=37 }, mplusHigh={ mastery=71.8, haste=20.5, crit=5.1, food=97.4, foodHearty=74.4, foodWellFed=23.1, rune=17.9, n=39 }, mplusFarm={ mastery=65.0, crit=22.5, haste=12.5, food=95.0, foodHearty=37.5, foodWellFed=57.5, rune=17.5, n=40 } },
    ["DEMONHUNTER/DEVAURER"] = { raid={ mastery=47.4, crit=34.2, haste=18.4, food=97.4, foodHearty=86.8, foodWellFed=10.5, rune=21.1, n=38 }, mplusHigh={ mastery=73.5, crit=14.7, haste=11.8, food=100.0, foodHearty=70.6, foodWellFed=29.4, rune=17.6, n=34 }, mplusFarm={ mastery=82.1, haste=7.7, crit=7.7, food=84.6, foodHearty=28.2, foodWellFed=56.4, rune=12.8, n=39 } },
    ["DEMONHUNTER/HAVOC"] = { raid={ crit=77.8, mastery=22.2, food=100.0, foodHearty=77.8, foodWellFed=22.2, rune=30.6, n=36 }, mplusHigh={ crit=82.1, mastery=17.9, food=100.0, foodHearty=82.1, foodWellFed=17.9, rune=20.5, n=39 }, mplusFarm={ crit=74.4, mastery=23.1, food=97.4, foodHearty=48.7, foodWellFed=48.7, rune=46.2, n=39 } },
    ["DEMONHUNTER/VENGEANCE"] = { raid={ haste=70.3, crit=21.6, mastery=5.4, versatility=2.7, food=97.3, foodHearty=81.1, foodWellFed=16.2, rune=21.6, n=37 }, mplusHigh={ haste=66.7, crit=17.9, versatility=15.4, food=100.0, foodHearty=51.3, foodWellFed=48.7, rune=20.5, n=39 }, mplusFarm={ haste=65.0, crit=10.0, mastery=10.0, versatility=7.5, food=92.5, foodHearty=20.0, foodWellFed=72.5, rune=32.5, n=40 } },
    ["DRUID/BALANCE"] = { raid={ mastery=71.1, crit=15.8, haste=13.2, food=100.0, foodHearty=78.9, foodWellFed=21.1, rune=26.3, n=38 }, mplusHigh={ mastery=79.5, haste=15.4, crit=5.1, food=94.9, foodHearty=66.7, foodWellFed=28.2, rune=7.7, n=39 }, mplusFarm={ mastery=85.0, haste=7.5, crit=5.0, food=90.0, foodHearty=42.5, foodWellFed=47.5, rune=35.0, n=40 } },
    ["DRUID/FERAL"] = { raid={ mastery=64.1, haste=20.5, crit=15.4, food=100.0, foodHearty=94.9, foodWellFed=5.1, rune=25.6, n=39 }, mplusHigh={ mastery=67.5, crit=17.5, haste=12.5, versatility=2.5, food=97.5, foodHearty=67.5, foodWellFed=30.0, rune=15.0, n=40 }, mplusFarm={ mastery=74.4, haste=12.8, crit=12.8, food=92.3, foodHearty=35.9, foodWellFed=56.4, rune=33.3, n=39 } },
    ["DRUID/GUARDIAN"] = { raid={ haste=79.5, crit=7.7, versatility=7.7, mastery=2.6, food=94.9, foodHearty=79.5, foodWellFed=15.4, rune=15.4, n=39 }, mplusHigh={ haste=50.0, crit=30.0, versatility=17.5, mastery=2.5, food=100.0, foodHearty=50.0, foodWellFed=50.0, rune=15.0, n=40 }, mplusFarm={ haste=70.3, crit=10.8, versatility=10.8, mastery=2.7, food=83.8, foodHearty=24.3, foodWellFed=59.5, rune=10.8, n=37 } },
    ["DRUID/RESTORATION"] = { raid={ haste=81.6, mastery=15.8, versatility=2.6, food=81.6, foodHearty=50.0, foodWellFed=31.6, rune=15.8, n=38 }, mplusHigh={ haste=45.0, mastery=30.0, versatility=25.0, food=97.5, foodHearty=60.0, foodWellFed=37.5, rune=27.5, n=40 }, mplusFarm={ haste=42.1, mastery=34.2, versatility=5.3, food=76.3, foodHearty=23.7, foodWellFed=52.6, rune=13.2, n=38 } },
    ["EVOKER/AUGMENTATION"] = { raid={ mastery=87.5, crit=10.0, haste=2.5, food=100.0, foodHearty=92.5, foodWellFed=7.5, rune=15.0, n=40 }, mplusHigh={ mastery=78.4, crit=18.9, food=97.3, foodHearty=59.5, foodWellFed=37.8, rune=32.4, n=37 }, mplusFarm={ mastery=71.1, crit=18.4, food=81.6, foodHearty=39.5, foodWellFed=42.1, rune=26.3, n=38 } },
    ["EVOKER/DEVASTATION"] = { raid={ crit=86.8, haste=5.3, mastery=5.3, food=97.4, foodHearty=76.3, foodWellFed=21.1, rune=26.3, n=38 }, mplusHigh={ crit=89.7, versatility=5.1, haste=5.1, food=100.0, foodHearty=74.4, foodWellFed=25.6, rune=35.9, n=39 }, mplusFarm={ crit=71.8, mastery=20.5, haste=5.1, food=82.1, foodHearty=43.6, foodWellFed=38.5, rune=41.0, n=39 } },
    ["EVOKER/PRESERVATION"] = { raid={ mastery=62.5, crit=22.5, haste=5.0, food=90.0, foodHearty=67.5, foodWellFed=22.5, rune=7.5, n=40 }, mplusHigh={ versatility=48.6, haste=40.5, crit=10.8, food=86.5, foodHearty=75.7, foodWellFed=10.8, rune=10.8, n=37 }, mplusFarm={ crit=32.4, mastery=27.0, haste=21.6, food=67.6, foodHearty=27.0, foodWellFed=40.5, rune=16.2, n=37 } },
    ["HUNTER/BEASTMASTERY"] = { raid={ mastery=72.5, crit=15.0, haste=10.0, food=95.0, foodHearty=80.0, foodWellFed=15.0, rune=27.5, n=40 }, mplusHigh={ mastery=64.1, crit=23.1, versatility=12.8, food=97.4, foodHearty=79.5, foodWellFed=17.9, rune=7.7, n=39 }, mplusFarm={ mastery=69.4, crit=22.2, versatility=2.8, haste=2.8, food=80.6, foodHearty=30.6, foodWellFed=50.0, rune=30.6, n=36 } },
    ["HUNTER/MARKSMANSHIP"] = { raid={ crit=86.5, mastery=13.5, food=100.0, foodHearty=94.6, foodWellFed=5.4, rune=27.0, n=37 }, mplusHigh={ crit=81.6, mastery=7.9, haste=5.3, versatility=5.3, food=97.4, foodHearty=57.9, foodWellFed=39.5, rune=26.3, n=38 }, mplusFarm={ crit=92.1, mastery=5.3, versatility=2.6, food=89.5, foodHearty=23.7, foodWellFed=65.8, rune=36.8, n=38 } },
    ["HUNTER/SURVIVAL"] = { raid={ mastery=80.0, haste=10.0, crit=10.0, food=92.5, foodHearty=72.5, foodWellFed=20.0, rune=30.0, n=40 }, mplusHigh={ mastery=52.6, haste=34.2, crit=13.2, food=97.4, foodHearty=52.6, foodWellFed=44.7, rune=21.1, n=38 }, mplusFarm={ mastery=76.3, haste=15.8, crit=5.3, food=92.1, foodHearty=42.1, foodWellFed=50.0, rune=13.2, n=38 } },
    ["MAGE/ARCANE"] = { raid={ haste=43.6, versatility=33.3, crit=23.1, food=100.0, foodHearty=61.5, foodWellFed=38.5, rune=20.5, n=39 }, mplusHigh={ versatility=63.2, haste=23.7, crit=13.2, food=100.0, foodHearty=97.4, foodWellFed=2.6, rune=0.0, n=38 }, mplusFarm={ haste=55.6, versatility=30.6, crit=13.9, food=97.2, foodHearty=44.4, foodWellFed=52.8, rune=22.2, n=36 } },
    ["MAGE/FIRE"] = { raid={ haste=62.5, versatility=32.5, mastery=5.0, food=95.0, foodHearty=67.5, foodWellFed=27.5, rune=25.0, n=40 }, mplusHigh={ versatility=45.0, haste=35.0, mastery=20.0, food=92.5, foodHearty=52.5, foodWellFed=40.0, rune=12.5, n=40 }, mplusFarm={ haste=63.2, versatility=23.7, mastery=13.2, food=89.5, foodHearty=47.4, foodWellFed=42.1, rune=34.2, n=38 } },
    ["MAGE/FROST"] = { raid={ crit=62.5, mastery=22.5, haste=7.5, versatility=2.5, food=95.0, foodHearty=77.5, foodWellFed=17.5, rune=37.5, n=40 }, mplusHigh={ crit=47.5, mastery=42.5, haste=7.5, versatility=2.5, food=95.0, foodHearty=55.0, foodWellFed=40.0, rune=40.0, n=40 }, mplusFarm={ crit=61.5, mastery=25.6, versatility=7.7, haste=2.6, food=82.1, foodHearty=46.2, foodWellFed=35.9, rune=35.9, n=39 } },
    ["MONK/BREWMASTER"] = { raid={ versatility=47.5, crit=47.5, mastery=2.5, food=97.5, foodHearty=77.5, foodWellFed=20.0, rune=27.5, n=40 }, mplusHigh={ versatility=77.5, crit=20.0, mastery=2.5, food=97.5, foodHearty=50.0, foodWellFed=47.5, rune=2.5, n=40 }, mplusFarm={ versatility=64.1, crit=28.2, mastery=5.1, food=87.2, foodHearty=23.1, foodWellFed=64.1, rune=12.8, n=39 } },
    ["MONK/MISTWEAVER"] = { raid={ haste=70.3, crit=13.5, mastery=8.1, versatility=2.7, food=91.9, foodHearty=73.0, foodWellFed=18.9, rune=18.9, n=37 }, mplusHigh={ haste=45.0, mastery=42.5, versatility=7.5, crit=2.5, food=92.5, foodHearty=67.5, foodWellFed=25.0, rune=10.0, n=40 }, mplusFarm={ haste=59.0, mastery=17.9, crit=10.3, food=92.3, foodHearty=41.0, foodWellFed=51.3, rune=10.3, n=39 } },
    ["MONK/WINDWALKER"] = { raid={ mastery=62.5, haste=27.5, crit=10.0, food=100.0, foodHearty=82.5, foodWellFed=17.5, rune=20.0, n=40 }, mplusHigh={ mastery=78.9, crit=10.5, haste=5.3, versatility=5.3, food=97.4, foodHearty=68.4, foodWellFed=28.9, rune=13.2, n=38 }, mplusFarm={ mastery=86.5, crit=8.1, haste=2.7, food=89.2, foodHearty=32.4, foodWellFed=56.8, rune=24.3, n=37 } },
    ["PALADIN/HOLY"] = { raid={ mastery=70.0, haste=12.5, crit=7.5, food=82.5, foodHearty=62.5, foodWellFed=20.0, rune=10.0, n=40 }, mplusHigh={ versatility=46.2, haste=41.0, crit=12.8, food=100.0, foodHearty=100.0, foodWellFed=0.0, rune=0.0, n=39 }, mplusFarm={ mastery=32.4, haste=32.4, versatility=13.5, crit=5.4, food=73.0, foodHearty=32.4, foodWellFed=40.5, rune=5.4, n=37 } },
    ["PALADIN/PROTECTION"] = { raid={ crit=61.5, haste=38.5, food=97.4, foodHearty=87.2, foodWellFed=10.3, rune=23.1, n=39 }, mplusHigh={ crit=69.2, haste=23.1, versatility=5.1, mastery=2.6, food=100.0, foodHearty=59.0, foodWellFed=41.0, rune=23.1, n=39 }, mplusFarm={ crit=47.4, haste=34.2, versatility=5.3, mastery=5.3, food=76.3, foodHearty=18.4, foodWellFed=57.9, rune=23.7, n=38 } },
    ["PALADIN/RETRIBUTION"] = { raid={ mastery=80.6, haste=16.7, crit=2.8, food=97.2, foodHearty=69.4, foodWellFed=27.8, rune=33.3, n=36 }, mplusHigh={ mastery=66.7, haste=30.8, versatility=2.6, food=100.0, foodHearty=87.2, foodWellFed=12.8, rune=12.8, n=39 }, mplusFarm={ mastery=72.5, haste=20.0, crit=5.0, food=87.5, foodHearty=50.0, foodWellFed=37.5, rune=30.0, n=40 } },
    ["PRIEST/DISCIPLINE"] = { raid={ haste=87.5, crit=5.0, mastery=2.5, food=95.0, foodHearty=65.0, foodWellFed=30.0, rune=22.5, n=40 }, mplusHigh={ haste=59.5, mastery=24.3, crit=13.5, food=100.0, foodHearty=62.2, foodWellFed=37.8, rune=18.9, n=37 }, mplusFarm={ haste=60.5, mastery=13.2, crit=10.5, food=81.6, foodHearty=26.3, foodWellFed=55.3, rune=13.2, n=38 } },
    ["PRIEST/HOLY"] = { raid={ crit=51.3, mastery=30.8, haste=10.3, food=94.9, foodHearty=61.5, foodWellFed=33.3, rune=10.3, n=39 }, mplusHigh={ haste=55.6, crit=19.4, versatility=16.7, mastery=8.3, food=97.2, foodHearty=77.8, foodWellFed=19.4, rune=8.3, n=36 }, mplusFarm={ crit=51.3, haste=23.1, mastery=7.7, versatility=7.7, food=79.5, foodHearty=38.5, foodWellFed=41.0, rune=12.8, n=39 } },
    ["PRIEST/SHADOW"] = { raid={ mastery=62.2, crit=29.7, haste=8.1, food=100.0, foodHearty=70.3, foodWellFed=29.7, rune=32.4, n=37 }, mplusHigh={ crit=42.1, mastery=39.5, haste=18.4, food=94.7, foodHearty=55.3, foodWellFed=39.5, rune=15.8, n=38 }, mplusFarm={ mastery=46.2, crit=25.6, haste=20.5, food=84.6, foodHearty=33.3, foodWellFed=51.3, rune=33.3, n=39 } },
    ["ROGUE/ASSASSINATION"] = { raid={ crit=81.1, haste=16.2, mastery=2.7, food=94.6, foodHearty=81.1, foodWellFed=13.5, rune=18.9, n=37 }, mplusHigh={ crit=54.1, mastery=27.0, haste=18.9, food=100.0, foodHearty=91.9, foodWellFed=8.1, rune=5.4, n=37 }, mplusFarm={ crit=83.8, mastery=13.5, haste=2.7, food=91.9, foodHearty=32.4, foodWellFed=59.5, rune=21.6, n=37 } },
    ["ROGUE/OUTLAW"] = { raid={ crit=80.0, haste=15.0, versatility=5.0, food=97.5, foodHearty=87.5, foodWellFed=10.0, rune=15.0, n=40 }, mplusHigh={ crit=71.8, versatility=20.5, haste=2.6, food=92.3, foodHearty=69.2, foodWellFed=23.1, rune=12.8, n=39 }, mplusFarm={ crit=70.0, haste=15.0, versatility=12.5, mastery=2.5, food=95.0, foodHearty=50.0, foodWellFed=45.0, rune=22.5, n=40 } },
    ["ROGUE/SUBTLETY"] = { raid={ mastery=84.6, versatility=10.3, haste=5.1, food=100.0, foodHearty=89.7, foodWellFed=10.3, rune=43.6, n=39 }, mplusHigh={ mastery=90.0, crit=7.5, haste=2.5, food=92.5, foodHearty=67.5, foodWellFed=25.0, rune=10.0, n=40 }, mplusFarm={ mastery=86.8, haste=5.3, crit=5.3, versatility=2.6, food=97.4, foodHearty=50.0, foodWellFed=47.4, rune=31.6, n=38 } },
    ["SHAMAN/ELEMENTAL"] = { raid={ crit=48.7, mastery=38.5, haste=12.8, food=94.9, foodHearty=84.6, foodWellFed=10.3, rune=20.5, n=39 }, mplusHigh={ crit=79.5, mastery=12.8, haste=7.7, food=100.0, foodHearty=97.4, foodWellFed=2.6, rune=0.0, n=39 }, mplusFarm={ crit=59.0, mastery=23.1, haste=7.7, food=79.5, foodHearty=41.0, foodWellFed=38.5, rune=28.2, n=39 } },
    ["SHAMAN/ENHANCEMENT"] = { raid={ mastery=47.5, crit=37.5, haste=12.5, food=97.5, foodHearty=92.5, foodWellFed=5.0, rune=27.5, n=40 }, mplusHigh={ haste=35.0, crit=32.5, mastery=30.0, food=95.0, foodHearty=52.5, foodWellFed=42.5, rune=10.0, n=40 }, mplusFarm={ mastery=38.5, crit=38.5, haste=23.1, food=92.3, foodHearty=33.3, foodWellFed=59.0, rune=17.9, n=39 } },
    ["SHAMAN/RESTORATION"] = { raid={ crit=90.0, mastery=2.5, haste=2.5, food=95.0, foodHearty=67.5, foodWellFed=27.5, rune=12.5, n=40 }, mplusHigh={ crit=60.0, versatility=40.0, food=100.0, foodHearty=75.0, foodWellFed=25.0, rune=10.0, n=40 }, mplusFarm={ crit=72.2, haste=13.9, versatility=5.6, mastery=2.8, food=75.0, foodHearty=22.2, foodWellFed=52.8, rune=22.2, n=36 } },
    ["WARLOCK/AFFLICTION"] = { raid={ crit=71.1, haste=23.7, mastery=5.3, food=92.1, foodHearty=76.3, foodWellFed=15.8, rune=28.9, n=38 }, mplusHigh={ crit=69.2, haste=25.6, mastery=2.6, food=97.4, foodHearty=71.8, foodWellFed=25.6, rune=30.8, n=39 }, mplusFarm={ crit=56.4, haste=35.9, mastery=7.7, food=92.3, foodHearty=41.0, foodWellFed=51.3, rune=12.8, n=39 } },
    ["WARLOCK/DEMONOLOGY"] = { raid={ crit=86.5, haste=5.4, mastery=2.7, versatility=2.7, food=94.6, foodHearty=70.3, foodWellFed=24.3, rune=5.4, n=37 }, mplusHigh={ crit=80.0, haste=11.4, mastery=5.7, versatility=2.9, food=100.0, foodHearty=82.9, foodWellFed=17.1, rune=11.4, n=35 }, mplusFarm={ crit=94.4, mastery=5.6, food=94.4, foodHearty=50.0, foodWellFed=44.4, rune=36.1, n=36 } },
    ["WARLOCK/DESTRUCTION"] = { raid={ crit=71.8, mastery=20.5, haste=7.7, food=100.0, foodHearty=84.6, foodWellFed=15.4, rune=28.2, n=39 }, mplusHigh={ crit=59.0, haste=28.2, mastery=12.8, food=97.4, foodHearty=56.4, foodWellFed=41.0, rune=25.6, n=39 }, mplusFarm={ crit=69.2, mastery=23.1, haste=5.1, food=79.5, foodHearty=30.8, foodWellFed=48.7, rune=25.6, n=39 } },
    ["WARRIOR/ARMS"] = { raid={ haste=57.5, crit=35.0, mastery=7.5, food=100.0, foodHearty=72.5, foodWellFed=27.5, rune=27.5, n=40 }, mplusHigh={ mastery=40.5, haste=40.5, crit=18.9, food=100.0, foodHearty=97.3, foodWellFed=2.7, rune=2.7, n=37 }, mplusFarm={ haste=47.4, crit=28.9, mastery=23.7, food=97.4, foodHearty=44.7, foodWellFed=52.6, rune=5.3, n=38 } },
    ["WARRIOR/FURY"] = { raid={ mastery=67.5, haste=30.0, crit=2.5, food=100.0, foodHearty=95.0, foodWellFed=5.0, rune=32.5, n=40 }, mplusHigh={ mastery=77.5, haste=22.5, food=100.0, foodHearty=60.0, foodWellFed=40.0, rune=20.0, n=40 }, mplusFarm={ mastery=74.4, haste=25.6, food=84.6, foodHearty=43.6, foodWellFed=41.0, rune=28.2, n=39 } },
    ["WARRIOR/PROTECTION"] = { raid={ haste=69.4, crit=22.2, mastery=5.6, versatility=2.8, food=97.2, foodHearty=80.6, foodWellFed=16.7, rune=41.7, n=36 }, mplusHigh={ haste=56.4, versatility=23.1, mastery=10.3, crit=7.7, food=97.4, foodHearty=71.8, foodWellFed=25.6, rune=20.5, n=39 }, mplusFarm={ haste=64.1, crit=23.1, versatility=5.1, mastery=5.1, food=89.7, foodHearty=33.3, foodWellFed=56.4, rune=33.3, n=39 } },
}

BisData.potionUsage = {
    ["DEATHKNIGHT/BLOOD"] = { raid={ ["鲁莽药水"]=32.5 }, mplusHigh={ ["鲁莽药水"]=32.5 }, mplusFarm={ ["鲁莽药水"]=20.0 } },
    ["DEATHKNIGHT/FROST"] = { raid={ ["鲁莽药水"]=50.0 }, mplusHigh={ ["鲁莽药水"]=51.3 }, mplusFarm={ ["鲁莽药水"]=50.0, ["狂放恣意饮剂"]=2.6 } },
    ["DEATHKNIGHT/UNHOLY"] = { raid={ ["鲁莽药水"]=97.5 }, mplusHigh={ ["鲁莽药水"]=97.5 }, mplusFarm={ ["鲁莽药水"]=92.5 } },
    ["DEMONHUNTER/DEVAURER"] = { raid={ ["鲁莽药水"]=100.0 }, mplusHigh={ ["鲁莽药水"]=100.0 }, mplusFarm={ ["鲁莽药水"]=95.0 } },
    ["DEMONHUNTER/HAVOC"] = { raid={ ["鲁莽药水"]=87.2 }, mplusHigh={ ["鲁莽药水"]=89.7 }, mplusFarm={ ["鲁莽药水"]=90.0 } },
    ["DEMONHUNTER/VENGEANCE"] = { raid={ ["鲁莽药水"]=15.4 }, mplusHigh={ ["鲁莽药水"]=12.8 }, mplusFarm={ ["鲁莽药水"]=8.6 } },
    ["DRUID/BALANCE"] = { raid={ ["鲁莽药水"]=60.0 }, mplusHigh={ ["鲁莽药水"]=60.0, ["狂放恣意饮剂"]=2.5 }, mplusFarm={ ["鲁莽药水"]=15.0 } },
    ["DRUID/FERAL"] = { raid={ ["鲁莽药水"]=7.5, ["狂热药水"]=2.5 }, mplusHigh={ ["鲁莽药水"]=5.0, ["狂热药水"]=2.5 }, mplusFarm={ ["狂放恣意饮剂"]=2.6 } },
    ["DRUID/GUARDIAN"] = { raid={ ["鲁莽药水"]=2.6 }, mplusHigh={ ["鲁莽药水"]=2.5 }, mplusFarm={ ["鲁莽药水"]=5.0 } },
    ["DRUID/RESTORATION"] = { raid={ ["鲁莽药水"]=12.5 }, mplusHigh={ ["鲁莽药水"]=12.5 }, mplusFarm={ ["鲁莽药水"]=7.7 } },
    ["EVOKER/AUGMENTATION"] = { raid={ ["鲁莽药水"]=7.7 }, mplusHigh={ ["鲁莽药水"]=5.0 } },
    ["EVOKER/DEVASTATION"] = { raid={ ["鲁莽药水"]=17.5 }, mplusHigh={ ["鲁莽药水"]=15.0 }, mplusFarm={ ["鲁莽药水"]=15.0 } },
    ["EVOKER/PRESERVATION"] = { raid={ ["鲁莽药水"]=15.0 }, mplusHigh={ ["鲁莽药水"]=15.0 } },
    ["HUNTER/BEASTMASTERY"] = { raid={ ["狂放恣意饮剂"]=67.5, ["鲁莽药水"]=37.5 }, mplusHigh={ ["狂放恣意饮剂"]=65.0, ["鲁莽药水"]=35.0 }, mplusFarm={ ["鲁莽药水"]=20.0, ["狂放恣意饮剂"]=12.5 } },
    ["HUNTER/MARKSMANSHIP"] = { raid={ ["狂放恣意饮剂"]=2.5, ["鲁莽药水"]=2.5 }, mplusHigh={ ["狂放恣意饮剂"]=2.5, ["鲁莽药水"]=2.5 }, mplusFarm={ ["鲁莽药水"]=2.5 } },
    ["HUNTER/SURVIVAL"] = { raid={ ["狂放恣意饮剂"]=17.5, ["鲁莽药水"]=10.0 }, mplusHigh={ ["狂放恣意饮剂"]=17.5, ["鲁莽药水"]=10.0 }, mplusFarm={ ["鲁莽药水"]=10.0 } },
    ["MAGE/ARCANE"] = { raid={ ["鲁莽药水"]=20.5 }, mplusHigh={ ["鲁莽药水"]=20.0 }, mplusFarm={ ["鲁莽药水"]=20.0 } },
    ["MAGE/FIRE"] = { raid={ ["鲁莽药水"]=17.9, ["狂放恣意饮剂"]=7.7 }, mplusHigh={ ["鲁莽药水"]=17.5, ["狂放恣意饮剂"]=10.0 }, mplusFarm={ ["鲁莽药水"]=10.0, ["狂放恣意饮剂"]=2.5 } },
    ["MAGE/FROST"] = { raid={ ["鲁莽药水"]=89.5 }, mplusHigh={ ["鲁莽药水"]=92.1 }, mplusFarm={ ["鲁莽药水"]=82.5 } },
    ["MONK/BREWMASTER"] = { raid={ ["鲁莽药水"]=12.5 }, mplusHigh={ ["鲁莽药水"]=12.5 }, mplusFarm={ ["鲁莽药水"]=5.0, ["狂放恣意饮剂"]=2.5 } },
    ["MONK/MISTWEAVER"] = { raid={ ["鲁莽药水"]=27.5 }, mplusHigh={ ["鲁莽药水"]=27.5 }, mplusFarm={ ["鲁莽药水"]=12.5 } },
    ["MONK/WINDWALKER"] = { raid={ ["鲁莽药水"]=85.0 }, mplusHigh={ ["鲁莽药水"]=85.0 }, mplusFarm={ ["鲁莽药水"]=77.5 } },
    ["PALADIN/HOLY"] = { raid={ ["鲁莽药水"]=12.5 }, mplusHigh={ ["鲁莽药水"]=15.0 }, mplusFarm={ ["鲁莽药水"]=7.7 } },
    ["PALADIN/PROTECTION"] = { raid={ ["鲁莽药水"]=20.0, ["狂热药水"]=2.5, ["狂放恣意饮剂"]=2.5 }, mplusHigh={ ["鲁莽药水"]=17.5, ["狂热药水"]=2.5 }, mplusFarm={ ["鲁莽药水"]=22.5, ["狂放恣意饮剂"]=5.0 } },
    ["PALADIN/RETRIBUTION"] = { raid={ ["鲁莽药水"]=12.8, ["狂放恣意饮剂"]=2.6 }, mplusHigh={ ["鲁莽药水"]=12.8, ["狂放恣意饮剂"]=2.6 }, mplusFarm={ ["鲁莽药水"]=5.1 } },
    ["PRIEST/DISCIPLINE"] = { raid={ ["鲁莽药水"]=10.0 }, mplusHigh={ ["鲁莽药水"]=12.5 } },
    ["PRIEST/HOLY"] = { raid={ ["鲁莽药水"]=5.0 }, mplusHigh={ ["鲁莽药水"]=5.0 }, mplusFarm={ ["鲁莽药水"]=2.5 } },
    ["PRIEST/SHADOW"] = { raid={ ["鲁莽药水"]=20.5 }, mplusHigh={ ["鲁莽药水"]=20.5 }, mplusFarm={ ["鲁莽药水"]=5.0 } },
    ["ROGUE/ASSASSINATION"] = { raid={ ["鲁莽药水"]=12.5 }, mplusHigh={ ["鲁莽药水"]=12.5 }, mplusFarm={ ["狂放恣意饮剂"]=7.5, ["鲁莽药水"]=7.5 } },
    ["ROGUE/OUTLAW"] = { raid={ ["狂放恣意饮剂"]=5.0 }, mplusHigh={ ["狂放恣意饮剂"]=5.0 } },
    ["ROGUE/SUBTLETY"] = { raid={ ["鲁莽药水"]=52.5 }, mplusHigh={ ["鲁莽药水"]=55.0 }, mplusFarm={ ["鲁莽药水"]=36.8 } },
    ["SHAMAN/ELEMENTAL"] = { raid={ ["鲁莽药水"]=2.5 }, mplusHigh={ ["鲁莽药水"]=2.5 } },
    ["SHAMAN/ENHANCEMENT"] = { raid={ ["鲁莽药水"]=15.0 }, mplusHigh={ ["鲁莽药水"]=12.5 }, mplusFarm={ ["鲁莽药水"]=5.0 } },
    ["SHAMAN/RESTORATION"] = { raid={ ["鲁莽药水"]=7.5, ["吞噬之梦药水"]=2.5 }, mplusHigh={ ["鲁莽药水"]=7.5, ["吞噬之梦药水"]=2.5 }, mplusFarm={ ["鲁莽药水"]=5.0 } },
    ["WARLOCK/AFFLICTION"] = { raid={ ["鲁莽药水"]=10.0 }, mplusHigh={ ["鲁莽药水"]=10.0 }, mplusFarm={ ["鲁莽药水"]=10.0 } },
    ["WARLOCK/DEMONOLOGY"] = { raid={ ["鲁莽药水"]=35.0 }, mplusHigh={ ["鲁莽药水"]=40.0 }, mplusFarm={ ["鲁莽药水"]=10.0 } },
    ["WARLOCK/DESTRUCTION"] = { raid={ ["鲁莽药水"]=15.0 }, mplusHigh={ ["鲁莽药水"]=15.0 }, mplusFarm={ ["鲁莽药水"]=2.5 } },
    ["WARRIOR/ARMS"] = { raid={ ["鲁莽药水"]=82.1 }, mplusHigh={ ["鲁莽药水"]=82.1 }, mplusFarm={ ["鲁莽药水"]=59.0 } },
    ["WARRIOR/FURY"] = { raid={ ["鲁莽药水"]=32.5, ["狂放恣意饮剂"]=2.5 }, mplusHigh={ ["鲁莽药水"]=32.5, ["狂放恣意饮剂"]=2.5 }, mplusFarm={ ["鲁莽药水"]=15.4 } },
    ["WARRIOR/PROTECTION"] = { raid={ ["鲁莽药水"]=33.3 }, mplusHigh={ ["鲁莽药水"]=25.6 }, mplusFarm={ ["鲁莽药水"]=7.5 } },
}

BisData.oilUsage = {
    ["DEATHKNIGHT/BLOOD"] = { raid={ ["萨拉斯凤凰之油"]=98.1, ["磨锐石"]=0.5, n=800 }, mplusHigh={ ["萨拉斯凤凰之油"]=95.8, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=93.1, ["加重石"]=0.1, ["磨锐石"]=0.1, n=800 } },
    ["DEATHKNIGHT/FROST"] = { raid={ ["萨拉斯凤凰之油"]=99.3, ["磨锐石"]=0.3, n=704 }, mplusHigh={ ["萨拉斯凤凰之油"]=96.4, ["磨锐石"]=0.1, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=92.9, ["磨锐石"]=0.5, n=800 } },
    ["DEATHKNIGHT/UNHOLY"] = { raid={ ["萨拉斯凤凰之油"]=99.4, ["磨锐石"]=0.2, n=653 }, mplusHigh={ ["萨拉斯凤凰之油"]=94.9, ["磨锐石"]=0.1, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=93.6, ["磨锐石"]=0.2, n=800 } },
    ["DEMONHUNTER/DEVAURER"] = { raid={ ["萨拉斯凤凰之油"]=99.4, n=710 }, mplusHigh={ ["萨拉斯凤凰之油"]=93.2, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=94.4, n=800 } },
    ["DEMONHUNTER/HAVOC"] = { raid={ ["萨拉斯凤凰之油"]=99.2, n=786 }, mplusHigh={ ["萨拉斯凤凰之油"]=95.8, ["磨锐石"]=0.2, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=95.6, ["磨锐石"]=0.5, n=800 } },
    ["DEMONHUNTER/VENGEANCE"] = { raid={ ["萨拉斯凤凰之油"]=97.5, ["私运者的附魔之锋"]=1.1, ["磨锐石"]=0.2, n=610 }, mplusHigh={ ["萨拉斯凤凰之油"]=95.9, ["磨锐石"]=0.1, ["私运者的附魔之锋"]=0.1, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=93.1, ["私运者的附魔之锋"]=0.4, ["磨锐石"]=0.1, n=800 } },
    ["DRUID/BALANCE"] = { raid={ ["萨拉斯凤凰之油"]=99.6, n=817 }, mplusHigh={ ["萨拉斯凤凰之油"]=95.5, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=94.1, n=800 } },
    ["DRUID/FERAL"] = { raid={ ["萨拉斯凤凰之油"]=98.2, ["磨锐石"]=0.8, ["加重石"]=0.2, n=609 }, mplusHigh={ ["萨拉斯凤凰之油"]=94.1, ["磨锐石"]=1.2, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=91.8, ["磨锐石"]=0.6, ["加重石"]=0.1, n=800 } },
    ["DRUID/GUARDIAN"] = { raid={ ["萨拉斯凤凰之油"]=98.1, n=622 }, mplusHigh={ ["萨拉斯凤凰之油"]=93.1, ["磨锐石"]=0.8, ["黎明之油"]=0.4, ["私运者的附魔之锋"]=0.1, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=92.0, ["磨锐石"]=0.4, ["加重石"]=0.1, ["私运者的附魔之锋"]=0.1, n=800 } },
    ["DRUID/RESTORATION"] = { raid={ ["萨拉斯凤凰之油"]=96.2, ["黎明之油"]=0.7, n=718 }, mplusHigh={ ["萨拉斯凤凰之油"]=89.0, ["黎明之油"]=3.0, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=83.9, ["黎明之油"]=1.6, n=800 } },
    ["EVOKER/AUGMENTATION"] = { raid={ ["萨拉斯凤凰之油"]=98.9, n=783 }, mplusHigh={ ["萨拉斯凤凰之油"]=92.1, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=88.9, n=800 } },
    ["EVOKER/DEVASTATION"] = { raid={ ["萨拉斯凤凰之油"]=99.0, n=709 }, mplusHigh={ ["萨拉斯凤凰之油"]=95.5, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=92.5, ["黎明之油"]=0.1, n=800 } },
    ["EVOKER/PRESERVATION"] = { raid={ ["萨拉斯凤凰之油"]=97.9, ["黎明之油"]=0.1, n=826 }, mplusHigh={ ["萨拉斯凤凰之油"]=93.9, ["黎明之油"]=0.1, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=83.6, ["黎明之油"]=0.2, n=800 } },
    ["HUNTER/BEASTMASTERY"] = { raid={ ["萨拉斯凤凰之油"]=99.4, n=683 }, mplusHigh={ ["萨拉斯凤凰之油"]=95.0, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=92.0, n=800 } },
    ["HUNTER/MARKSMANSHIP"] = { raid={ ["萨拉斯凤凰之油"]=99.4, n=817 }, mplusHigh={ ["萨拉斯凤凰之油"]=92.0, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=94.0, n=800 } },
    ["HUNTER/SURVIVAL"] = { raid={ ["萨拉斯凤凰之油"]=99.1, n=532 }, mplusHigh={ ["萨拉斯凤凰之油"]=89.9, ["磨锐石"]=3.5, ["加重石"]=0.6, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=93.1, ["磨锐石"]=1.0, ["加重石"]=0.4, n=800 } },
    ["MAGE/ARCANE"] = { raid={ ["萨拉斯凤凰之油"]=99.9, n=827 }, mplusHigh={ ["萨拉斯凤凰之油"]=95.9, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=94.4, n=800 } },
    ["MAGE/FIRE"] = { raid={ ["萨拉斯凤凰之油"]=97.9, ["私运者的附魔之锋"]=0.3, n=327 }, mplusHigh={ ["萨拉斯凤凰之油"]=92.5, ["私运者的附魔之锋"]=0.1, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=87.6, ["黎明之油"]=0.1, n=800 } },
    ["MAGE/FROST"] = { raid={ ["萨拉斯凤凰之油"]=98.5, n=651 }, mplusHigh={ ["萨拉斯凤凰之油"]=94.4, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=92.8, ["私运者的附魔之锋"]=0.1, n=800 } },
    ["MONK/BREWMASTER"] = { raid={ ["萨拉斯凤凰之油"]=93.5, ["磨锐石"]=2.3, ["加重石"]=0.9, ["私运者的附魔之锋"]=0.6, n=649 }, mplusHigh={ ["萨拉斯凤凰之油"]=92.0, ["加重石"]=1.8, ["磨锐石"]=1.4, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=88.1, ["磨锐石"]=1.9, ["加重石"]=1.0, n=800 } },
    ["MONK/MISTWEAVER"] = { raid={ ["萨拉斯凤凰之油"]=98.0, ["黎明之油"]=0.3, n=717 }, mplusHigh={ ["萨拉斯凤凰之油"]=91.6, ["黎明之油"]=0.2, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=83.2, ["黎明之油"]=0.6, n=800 } },
    ["MONK/WINDWALKER"] = { raid={ ["萨拉斯凤凰之油"]=99.9, n=778 }, mplusHigh={ ["萨拉斯凤凰之油"]=95.4, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=93.4, ["磨锐石"]=0.4, n=800 } },
    ["PALADIN/HOLY"] = { raid={ ["萨拉斯凤凰之油"]=97.3, n=768 }, mplusHigh={ ["圣化仪式（圣骑士）"]=85.0, ["萨拉斯凤凰之油"]=11.2, imbue="圣化仪式（圣骑士）", n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=64.4, ["圣化仪式（圣骑士）"]=17.2, ["黎明之油"]=0.9, n=800 } },
    ["PALADIN/PROTECTION"] = { raid={ ["圣化仪式（圣骑士）"]=97.3, ["萨拉斯凤凰之油"]=2.2, imbue="圣化仪式（圣骑士）", n=779 }, mplusHigh={ ["圣化仪式（圣骑士）"]=95.6, ["萨拉斯凤凰之油"]=1.1, imbue="圣化仪式（圣骑士）", n=800 }, mplusFarm={ ["圣化仪式（圣骑士）"]=92.9, ["萨拉斯凤凰之油"]=3.6, imbue="圣化仪式（圣骑士）", n=800 } },
    ["PALADIN/RETRIBUTION"] = { raid={ ["萨拉斯凤凰之油"]=99.2, ["磨锐石"]=0.1, n=725 }, mplusHigh={ ["萨拉斯凤凰之油"]=96.1, ["磨锐石"]=0.4, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=95.0, ["磨锐石"]=0.4, n=800 } },
    ["PRIEST/DISCIPLINE"] = { raid={ ["萨拉斯凤凰之油"]=98.8, n=765 }, mplusHigh={ ["萨拉斯凤凰之油"]=92.5, ["黎明之油"]=0.2, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=86.6, ["黎明之油"]=0.1, n=800 } },
    ["PRIEST/HOLY"] = { raid={ ["萨拉斯凤凰之油"]=95.8, ["黎明之油"]=1.2, n=742 }, mplusHigh={ ["萨拉斯凤凰之油"]=93.4, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=82.9, ["黎明之油"]=1.6, n=800 } },
    ["PRIEST/SHADOW"] = { raid={ ["萨拉斯凤凰之油"]=99.4, n=784 }, mplusHigh={ ["萨拉斯凤凰之油"]=94.9, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=94.0, n=800 } },
    ["ROGUE/ASSASSINATION"] = { raid={ ["萨拉斯凤凰之油"]=99.4, n=779 }, mplusHigh={ ["萨拉斯凤凰之油"]=94.4, ["磨锐石"]=0.4, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=95.8, ["磨锐石"]=0.1, n=800 } },
    ["ROGUE/OUTLAW"] = { raid={ ["萨拉斯凤凰之油"]=98.7, ["磨锐石"]=0.2, n=595 }, mplusHigh={ ["萨拉斯凤凰之油"]=96.6, ["磨锐石"]=0.2, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=92.9, ["磨锐石"]=0.2, n=800 } },
    ["ROGUE/SUBTLETY"] = { raid={ ["萨拉斯凤凰之油"]=98.1, ["磨锐石"]=1.6, n=739 }, mplusHigh={ ["萨拉斯凤凰之油"]=92.8, ["磨锐石"]=3.6, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=94.1, ["磨锐石"]=1.4, n=800 } },
    ["SHAMAN/ELEMENTAL"] = { raid={ ["烈焰之舌武器（萨满）"]=100.0, imbue="烈焰之舌武器（萨满）", n=724 }, mplusHigh={ ["烈焰之舌武器（萨满）"]=96.2, ["萨拉斯凤凰之油"]=0.1, imbue="烈焰之舌武器（萨满）", n=800 }, mplusFarm={ ["烈焰之舌武器（萨满）"]=95.0, ["萨拉斯凤凰之油"]=0.1, imbue="烈焰之舌武器（萨满）", n=800 } },
    ["SHAMAN/ENHANCEMENT"] = { raid={ ["风怒武器（萨满）"]=100.0, imbue="风怒武器（萨满）", n=663 }, mplusHigh={ ["风怒武器（萨满）"]=95.4, imbue="风怒武器（萨满）", n=800 }, mplusFarm={ ["风怒武器（萨满）"]=97.0, imbue="风怒武器（萨满）", n=800 } },
    ["SHAMAN/RESTORATION"] = { raid={ ["大地生命武器（萨满）"]=100.0, imbue="大地生命武器（萨满）", n=790 }, mplusHigh={ ["大地生命武器（萨满）"]=95.1, imbue="大地生命武器（萨满）", n=800 }, mplusFarm={ ["大地生命武器（萨满）"]=96.0, imbue="大地生命武器（萨满）", n=800 } },
    ["WARLOCK/AFFLICTION"] = { raid={ ["萨拉斯凤凰之油"]=99.4, n=712 }, mplusHigh={ ["萨拉斯凤凰之油"]=95.1, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=92.4, n=800 } },
    ["WARLOCK/DEMONOLOGY"] = { raid={ ["萨拉斯凤凰之油"]=99.0, n=715 }, mplusHigh={ ["萨拉斯凤凰之油"]=93.8, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=94.8, n=800 } },
    ["WARLOCK/DESTRUCTION"] = { raid={ ["萨拉斯凤凰之油"]=99.5, n=590 }, mplusHigh={ ["萨拉斯凤凰之油"]=93.9, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=91.5, n=800 } },
    ["WARRIOR/ARMS"] = { raid={ ["萨拉斯凤凰之油"]=99.3, ["私运者的附魔之锋"]=0.1, n=814 }, mplusHigh={ ["萨拉斯凤凰之油"]=94.8, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=94.6, ["磨锐石"]=0.1, n=800 } },
    ["WARRIOR/FURY"] = { raid={ ["萨拉斯凤凰之油"]=99.7, n=605 }, mplusHigh={ ["萨拉斯凤凰之油"]=94.6, ["磨锐石"]=0.6, ["私运者的附魔之锋"]=0.2, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=94.8, ["磨锐石"]=0.6, n=800 } },
    ["WARRIOR/PROTECTION"] = { raid={ ["萨拉斯凤凰之油"]=97.6, ["磨锐石"]=0.3, ["私运者的附魔之锋"]=0.2, n=635 }, mplusHigh={ ["萨拉斯凤凰之油"]=90.6, ["磨锐石"]=0.9, ["黎明之油"]=0.4, n=800 }, mplusFarm={ ["萨拉斯凤凰之油"]=88.4, ["磨锐石"]=0.4, n=800 } },
}

BisData.mplusUsage = {
    ["DEATHKNIGHT/BLOOD/San'layn"] = { [158366]=5.8, [159418]=10.3, [159425]=7.7, [159459]=19.2, [162544]=5.1, [193753]=0.6, [193757]=0.6, [237828]=32.1, [237832]=11.5, [237834]=71.8, [237836]=18.6, [237846]=52.6, [239656]=25.6, [240949]=5.1, [250228]=2.6, [250244]=0.6, [250245]=1.9, [251136]=3.8, [251148]=7.1, [251193]=0.6, [251194]=3.2, [251214]=1.9, [251792]=0.6, [252258]=7.1, [268198]=14.7, [268213]=23.1, [268229]=7.1, [268239]=18.6, [268245]=28.8, [268248]=17.3, [268249]=9.6, [268250]=4.5, [268252]=7.1, [268260]=16.0, [268265]=86.5, [268266]=25.6, [270164]=13.5, [270165]=34.6, [270173]=9.0, [270174]=3.8, [270175]=67.3, [271444]=4.5, [271445]=55.1, [271469]=22.4, [271471]=20.5, [271472]=95.5, [271473]=87.2, [271474]=77.6, [271475]=77.6, [271477]=98.7, [271638]=7.7, [271878]=12.8, [273792]=18.6 },
    ["DEATHKNIGHT/FROST/Deathbringer"] = { [158366]=41.9, [159409]=9.0, [159418]=14.8, [193753]=1.3, [193763]=12.9, [237828]=62.6, [237834]=52.3, [237836]=1.9, [237839]=20.5, [240949]=1.9, [244746]=3.2, [246304]=1.3, [248583]=2.6, [249343]=0.6, [250228]=4.5, [251132]=50.3, [251136]=41.3, [251138]=5.2, [251142]=11.0, [251194]=0.6, [251234]=13.5, [251513]=19.4, [252258]=3.9, [268202]=53.0, [268208]=17.4, [268209]=27.1, [268222]=1.3, [268229]=3.9, [268239]=30.3, [268249]=12.3, [268252]=3.9, [268259]=23.2, [268260]=18.7, [268265]=73.5, [270163]=4.5, [270164]=1.9, [270165]=34.8, [270173]=20.0, [270175]=65.8, [271444]=15.5, [271445]=33.5, [271469]=12.9, [271472]=75.5, [271473]=71.6, [271474]=92.3, [271475]=96.1, [271476]=8.4, [271477]=94.8, [271878]=25.8, [272257]=1.3, [273776]=1.9 },
    ["DEATHKNIGHT/UNHOLY/San'layn"] = { [158366]=18.5, [159409]=3.3, [159413]=4.0, [159418]=19.9, [237828]=74.2, [237834]=73.5, [237836]=9.3, [237846]=24.5, [240949]=6.6, [244746]=2.6, [246304]=2.6, [249343]=2.6, [249344]=0.7, [250228]=6.0, [250229]=1.3, [251132]=24.5, [251136]=20.5, [251138]=4.0, [251142]=6.6, [251151]=3.3, [251194]=1.3, [251234]=14.6, [251513]=12.6, [251792]=0.7, [252258]=21.9, [265657]=0.7, [268213]=59.6, [268214]=5.3, [268222]=4.0, [268224]=1.3, [268229]=3.3, [268239]=15.2, [268245]=9.3, [268249]=11.9, [268252]=0.7, [268253]=15.2, [268259]=34.4, [268265]=74.8, [270163]=1.3, [270164]=6.6, [270165]=16.6, [270173]=23.8, [270175]=55.6, [271444]=12.6, [271469]=22.5, [271471]=19.2, [271472]=78.1, [271473]=70.9, [271474]=92.1, [271475]=84.8, [271477]=92.7, [271878]=26.5, [272149]=5.3, [272150]=4.6, [273777]=4.6, [273792]=15.2, [273796]=0.7, [273797]=1.3, [274493]=2.0 },
    ["DEMONHUNTER/DEVAURER/Void-Scarred"] = { [158366]=21.0, [159327]=14.0, [159337]=4.2, [159459]=4.2, [193763]=16.8, [237840]=56.6, [240949]=14.0, [244569]=66.4, [244570]=1.4, [244576]=65.7, [248583]=0.7, [249343]=0.7, [249346]=2.8, [250214]=0.7, [250215]=50.3, [251130]=13.3, [251132]=27.3, [251136]=21.7, [251153]=8.4, [251183]=10.5, [251190]=29.4, [251223]=5.6, [251234]=2.8, [252258]=31.5, [268201]=7.0, [268219]=0.7, [268225]=4.9, [268227]=20.3, [268234]=6.3, [268235]=2.8, [268240]=11.2, [268246]=9.1, [268249]=24.5, [268251]=4.2, [268252]=6.3, [268256]=23.8, [268265]=89.5, [270161]=0.7, [270164]=46.2, [270167]=25.9, [270168]=0.7, [270169]=1.4, [271092]=50.3, [271436]=21.0, [271535]=83.2, [271536]=80.4, [271537]=88.8, [271538]=84.6, [271540]=95.1, [271875]=9.8, [272147]=6.3, [272150]=1.4, [273778]=15.4, [273792]=4.9, [275527]=4.9, [279010]=1.4 },
    ["DEMONHUNTER/HAVOC/Fel-Scarred"] = { [158366]=38.2, [159327]=38.8, [159617]=0.7, [162544]=0.7, [193701]=2.0, [237839]=2.0, [237840]=88.2, [239048]=2.0, [239656]=19.1, [240949]=12.5, [244569]=40.1, [244570]=18.4, [244572]=2.6, [244574]=9.9, [244576]=56.6, [250214]=1.3, [250215]=0.7, [251132]=55.3, [251136]=40.8, [251183]=16.4, [251234]=25.0, [251513]=5.3, [268201]=9.2, [268209]=81.6, [268225]=1.3, [268227]=35.5, [268246]=15.8, [268249]=23.7, [268252]=0.7, [268256]=19.1, [268261]=7.9, [268265]=71.1, [270164]=3.9, [270166]=1.3, [270168]=28.3, [270173]=65.8, [270175]=39.5, [271436]=25.7, [271438]=5.3, [271532]=10.5, [271533]=16.4, [271535]=80.9, [271536]=87.5, [271537]=87.5, [271538]=100.0, [271540]=79.6, [271638]=3.3, [271875]=5.3, [272149]=5.9, [275526]=3.9 },
    ["DEMONHUNTER/VENGEANCE/Annihilator"] = { [158366]=3.8, [159300]=8.3, [159301]=22.3, [159313]=11.5, [159459]=31.8, [159617]=0.6, [171545]=1.3, [193763]=28.7, [237839]=16.6, [237840]=49.0, [239656]=28.7, [240949]=8.3, [244569]=14.6, [244570]=3.2, [244575]=15.9, [244576]=59.9, [248583]=4.5, [249343]=0.6, [250215]=8.9, [250225]=0.6, [250228]=2.5, [250243]=1.9, [250245]=16.6, [251124]=4.5, [251135]=28.0, [251136]=1.9, [251148]=15.9, [251153]=38.9, [251173]=20.4, [251194]=1.3, [251198]=7.0, [251223]=11.5, [251231]=22.9, [251513]=1.9, [251790]=0.6, [252258]=8.9, [268209]=36.9, [268235]=2.5, [268247]=12.7, [268248]=12.1, [268249]=0.6, [268252]=9.6, [268256]=12.7, [268265]=56.1, [268266]=7.6, [270160]=10.2, [270164]=10.2, [270165]=19.7, [270166]=2.5, [270173]=22.9, [270174]=1.3, [270175]=27.4, [271436]=28.7, [271535]=86.0, [271536]=75.8, [271537]=84.1, [271538]=75.8, [271540]=86.6, [271875]=11.5, [272148]=0.6, [272149]=1.9, [273774]=1.3, [273781]=19.1, [273791]=4.5, [273792]=31.8, [273796]=5.7, [274493]=4.5 },
    ["DRUID/BALANCE/Elune's Chosen"] = { [158366]=23.5, [159327]=18.3, [162544]=0.7, [240949]=2.0, [244569]=46.4, [244572]=7.2, [244574]=9.8, [244575]=7.2, [244576]=48.4, [245769]=80.3, [245770]=53.6, [250214]=2.6, [250215]=26.1, [250224]=0.7, [251124]=9.2, [251130]=1.3, [251132]=24.2, [251136]=22.9, [251142]=8.5, [251159]=0.7, [251183]=21.6, [251190]=24.8, [251194]=0.7, [251234]=5.2, [251513]=0.7, [251792]=0.7, [252258]=27.5, [268197]=4.2, [268210]=5.2, [268227]=34.6, [268235]=2.6, [268240]=19.0, [268249]=26.1, [268252]=8.5, [268253]=25.5, [268261]=23.5, [268263]=15.5, [268265]=82.4, [270161]=2.6, [270164]=30.7, [270167]=22.2, [270169]=6.5, [271092]=37.9, [271436]=15.7, [271525]=17.6, [271526]=88.2, [271527]=88.2, [271528]=86.9, [271529]=71.9, [271531]=96.7, [271875]=13.1, [272147]=6.5, [272149]=3.9, [272150]=3.9, [273774]=2.0, [273792]=7.8, [273794]=0.7, [273796]=22.9 },
    ["DRUID/FERAL/Wildstalker"] = { [155922]=7.2, [158366]=25.5, [159317]=27.5, [159327]=14.4, [162544]=9.8, [193701]=0.7, [237847]=3.3, [239048]=1.3, [239656]=19.6, [240949]=0.7, [244569]=39.9, [244572]=7.2, [244573]=17.0, [244574]=5.2, [244575]=20.3, [244576]=72.5, [248583]=6.5, [250214]=5.9, [250215]=2.0, [250228]=1.3, [251124]=11.8, [251130]=3.3, [251132]=21.6, [251136]=12.4, [251142]=14.4, [251153]=29.4, [251190]=20.9, [251194]=8.5, [251513]=7.8, [252258]=24.2, [268199]=11.1, [268215]=83.7, [268235]=5.2, [268240]=9.8, [268249]=12.4, [268252]=0.7, [268265]=81.7, [268290]=0.7, [268291]=3.9, [270164]=16.3, [270165]=22.2, [270166]=2.0, [270173]=19.6, [270175]=65.4, [271438]=1.3, [271525]=12.4, [271526]=90.8, [271527]=88.9, [271528]=86.3, [271529]=65.4, [271531]=92.2, [271875]=12.4, [272147]=11.1, [272149]=3.9, [272150]=3.3, [273774]=2.0, [273792]=3.3, [273796]=6.5, [274493]=2.0, [279010]=5.9 },
    ["DRUID/GUARDIAN/Elune's Chosen"] = { [158370]=9.9, [159313]=11.9, [159337]=1.3, [159459]=27.2, [162544]=10.6, [193763]=19.2, [193764]=4.6, [239656]=50.3, [240949]=14.6, [244569]=67.5, [244570]=8.6, [244574]=12.6, [244576]=66.2, [245771]=11.3, [250215]=23.8, [250228]=5.3, [250245]=13.2, [251124]=4.6, [251132]=7.3, [251135]=11.3, [251136]=5.3, [251146]=1.3, [251148]=2.0, [251153]=13.9, [251173]=11.3, [251189]=28.5, [251223]=15.2, [252258]=12.6, [268215]=65.6, [268240]=19.9, [268247]=14.6, [268249]=3.3, [268252]=6.6, [268265]=62.9, [268266]=7.3, [270160]=2.0, [270164]=6.6, [270165]=50.3, [270166]=2.6, [270173]=0.7, [270175]=41.7, [271436]=35.8, [271525]=7.9, [271526]=82.1, [271527]=69.5, [271528]=88.1, [271529]=93.4, [271531]=84.8, [271875]=5.3, [273781]=16.6, [273791]=5.3, [273792]=42.4, [273796]=4.6 },
    ["DRUID/RESTORATION/Wildstalker"] = { [159288]=10.3, [159317]=35.3, [159329]=3.8, [159337]=4.5, [159459]=22.4, [159617]=1.3, [162544]=8.3, [171622]=4.5, [171853]=1.9, [193757]=0.6, [193764]=0.6, [240949]=10.9, [244569]=36.5, [244570]=7.1, [244572]=37.2, [244576]=39.7, [245769]=70.9, [245770]=45.5, [248583]=2.6, [249343]=1.3, [249809]=0.6, [250214]=21.8, [250215]=0.6, [250254]=4.5, [250255]=16.0, [251135]=21.8, [251136]=2.6, [251140]=0.6, [251142]=25.0, [251148]=1.3, [251153]=13.5, [251190]=55.8, [251191]=5.1, [251194]=5.1, [251225]=3.8, [252258]=41.7, [264701]=1.3, [266317]=0.6, [268197]=17.7, [268225]=1.9, [268227]=12.8, [268234]=2.6, [268240]=16.7, [268247]=14.7, [268249]=1.3, [268251]=10.9, [268253]=11.5, [268256]=30.1, [268265]=54.5, [268266]=3.2, [270162]=39.7, [270164]=16.7, [270167]=34.0, [270169]=3.2, [270171]=0.6, [271092]=39.7, [271526]=56.4, [271527]=92.9, [271528]=85.3, [271529]=91.7, [271531]=91.7, [271875]=14.1, [272147]=5.1, [272150]=6.4, [273649]=0.6, [273774]=3.2, [273792]=1.3, [274493]=0.6, [279010]=3.8 },
    ["EVOKER/AUGMENTATION/Chronowarden"] = { [158366]=33.3, [159288]=12.8, [159388]=19.2, [159459]=0.6, [162544]=2.6, [193757]=0.6, [193759]=1.9, [193765]=8.3, [239035]=11.5, [239656]=17.9, [240949]=6.4, [244580]=3.2, [244581]=24.4, [244582]=5.1, [244583]=1.9, [244584]=80.8, [245769]=74.6, [245770]=12.2, [248583]=0.6, [249346]=5.8, [249998]=1.9, [250214]=3.8, [250215]=8.3, [250224]=34.0, [251132]=45.5, [251136]=26.3, [251142]=8.3, [251194]=5.1, [251200]=3.2, [251228]=18.6, [251234]=12.2, [252258]=8.3, [256971]=0.6, [268203]=11.5, [268217]=11.5, [268231]=7.1, [268233]=18.6, [268249]=23.7, [268252]=0.6, [268254]=33.3, [268258]=29.5, [268263]=18.6, [268265]=63.5, [268266]=0.6, [270161]=28.2, [270162]=0.6, [270164]=14.7, [270167]=8.3, [270168]=25.0, [270169]=1.3, [270170]=3.8, [271092]=44.9, [271499]=85.9, [271500]=89.7, [271501]=71.8, [271502]=94.2, [271504]=89.1, [271681]=3.4, [271876]=8.3, [272147]=0.6, [272149]=6.4, [272150]=7.1, [273789]=1.3, [273792]=7.7, [273794]=0.6, [273796]=0.6, [274493]=4.5 },
    ["EVOKER/DEVASTATION/Scalecommander"] = { [158366]=26.1, [159388]=8.3, [159459]=0.6, [160213]=5.1, [171644]=0.6, [239049]=8.3, [239656]=21.0, [240949]=2.5, [244580]=1.9, [244581]=21.0, [244582]=3.2, [244584]=56.1, [245769]=97.9, [245770]=35.7, [249346]=0.6, [250214]=7.6, [250215]=0.6, [250224]=1.9, [251132]=37.6, [251136]=29.9, [251148]=2.5, [251155]=14.6, [251200]=8.3, [251234]=5.1, [251513]=8.9, [251792]=0.6, [252258]=10.2, [268216]=21.0, [268217]=26.1, [268230]=2.5, [268237]=1.3, [268238]=10.2, [268249]=3.8, [268252]=25.5, [268258]=51.0, [268263]=2.1, [268265]=82.2, [268266]=7.6, [270161]=4.5, [270164]=56.7, [270167]=36.9, [271092]=52.2, [271440]=14.0, [271496]=15.3, [271499]=87.9, [271500]=94.3, [271501]=97.5, [271502]=82.2, [271504]=88.5, [271638]=7.6, [271876]=11.5, [272147]=1.3, [272149]=0.6, [273649]=0.6, [273778]=5.1, [273792]=18.5, [273796]=41.4, [274493]=0.6, [275526]=5.7 },
    ["EVOKER/PRESERVATION/Flameshaper"] = { [158366]=5.3, [159369]=29.6, [159380]=11.8, [159459]=21.1, [162544]=0.7, [171622]=0.7, [171640]=2.0, [193759]=2.0, [193763]=23.7, [193766]=13.7, [239049]=11.2, [239656]=27.0, [240949]=9.2, [244580]=2.0, [244581]=13.8, [244582]=3.3, [244584]=63.8, [245769]=82.1, [245770]=34.9, [246304]=6.6, [248583]=5.3, [250214]=3.3, [250215]=6.6, [250255]=2.0, [251125]=11.8, [251136]=3.3, [251142]=5.3, [251145]=22.4, [251148]=29.6, [251152]=5.3, [251158]=3.3, [251173]=11.2, [251194]=1.3, [251200]=19.7, [251233]=5.3, [252258]=1.3, [264701]=0.7, [268197]=3.2, [268203]=6.6, [268216]=33.6, [268238]=5.3, [268248]=15.1, [268252]=7.2, [268265]=77.6, [268266]=11.2, [270162]=48.7, [270164]=29.6, [270167]=23.0, [270169]=2.0, [270171]=2.0, [271092]=47.4, [271440]=41.4, [271441]=7.9, [271499]=84.9, [271500]=94.7, [271501]=86.2, [271502]=86.2, [271504]=78.3, [271876]=7.9, [272148]=4.6, [273792]=28.3, [274493]=1.3, [275529]=3.9 },
    ["HUNTER/BEASTMASTERY/Pack Leader"] = { [158366]=28.5, [159617]=9.9, [162544]=8.6, [193752]=1.3, [193759]=2.6, [193765]=0.7, [240949]=6.0, [244568]=6.0, [244581]=40.4, [244582]=36.4, [244584]=77.5, [249806]=1.3, [250214]=10.6, [250215]=21.9, [250225]=3.3, [250228]=1.3, [251131]=13.2, [251132]=39.7, [251136]=34.4, [251148]=1.3, [251155]=19.9, [251165]=2.6, [251194]=9.3, [251234]=7.3, [251513]=0.7, [265337]=31.8, [265657]=3.3, [268200]=4.6, [268207]=63.6, [268216]=23.8, [268217]=8.6, [268231]=3.3, [268248]=23.2, [268249]=36.4, [268252]=4.6, [268258]=19.9, [268265]=88.1, [270164]=25.8, [270165]=5.3, [270168]=7.9, [270173]=2.0, [270175]=35.8, [271440]=38.4, [271441]=3.3, [271487]=15.2, [271490]=80.1, [271491]=58.9, [271492]=96.0, [271493]=93.4, [271494]=16.6, [271495]=92.1, [271638]=3.3, [271876]=7.9, [272149]=3.3, [273796]=4.0, [274493]=0.7 },
    ["HUNTER/MARKSMANSHIP/Sentinel"] = { [156000]=3.4, [158366]=52.0, [159375]=5.4, [159380]=6.1, [159388]=39.2, [159617]=6.1, [162544]=1.4, [193701]=1.4, [193752]=8.1, [239049]=1.4, [240949]=1.4, [244581]=73.0, [244582]=23.0, [244584]=85.1, [248583]=0.7, [249806]=6.8, [250214]=4.7, [250215]=2.0, [250225]=1.4, [250228]=3.4, [251131]=7.4, [251132]=52.0, [251136]=53.4, [251148]=4.7, [251155]=11.5, [251165]=1.4, [251194]=1.4, [251228]=6.8, [251233]=1.4, [251234]=27.7, [251513]=2.7, [260235]=2.7, [265337]=16.2, [265657]=1.4, [268200]=8.8, [268207]=72.3, [268217]=5.4, [268230]=4.1, [268248]=10.8, [268249]=4.7, [268252]=6.1, [268258]=18.2, [268265]=68.9, [270164]=6.1, [270165]=6.8, [270166]=0.7, [270168]=35.8, [270173]=4.1, [270175]=50.0, [271487]=18.2, [271490]=91.2, [271491]=68.2, [271492]=91.9, [271493]=90.5, [271494]=19.6, [271495]=96.6, [271876]=2.0, [272148]=5.4, [272149]=0.7, [272250]=2.0, [273781]=1.4, [273796]=8.1 },
    ["HUNTER/SURVIVAL/Sentinel"] = { [158366]=27.7, [159136]=4.5, [159375]=5.2, [159617]=0.6, [160213]=4.5, [162544]=1.3, [171654]=1.9, [193752]=1.9, [193757]=0.6, [239035]=5.2, [239046]=0.6, [239049]=0.6, [239656]=21.9, [240949]=11.0, [244568]=1.9, [244577]=26.5, [244580]=2.6, [244581]=49.0, [244584]=92.3, [249806]=1.3, [250214]=14.2, [250215]=25.8, [250228]=1.3, [251136]=24.5, [251142]=29.0, [251155]=20.6, [251194]=3.2, [251200]=4.5, [251234]=15.5, [251792]=0.6, [252258]=25.8, [265657]=1.3, [268209]=25.2, [268213]=24.5, [268215]=21.3, [268216]=9.7, [268230]=4.5, [268233]=29.7, [268237]=3.9, [268249]=8.4, [268253]=27.1, [268265]=33.5, [270164]=7.7, [270165]=31.0, [270173]=30.3, [270175]=23.2, [271093]=27.3, [271487]=16.8, [271490]=96.8, [271491]=87.7, [271492]=89.0, [271493]=91.0, [271494]=17.4, [271495]=97.4, [271876]=1.9, [272147]=12.9, [272149]=1.9, [272150]=3.9, [273792]=10.3, [273796]=0.6, [273797]=11.6, [275070]=59.1 },
    ["MAGE/ARCANE/Sunfury"] = { [159263]=7.6, [159459]=28.7, [171622]=0.6, [193763]=23.6, [239648]=73.9, [239649]=13.4, [239650]=5.7, [239651]=1.9, [239653]=9.6, [240949]=9.6, [245769]=87.8, [245770]=40.8, [250215]=68.2, [251127]=11.5, [251139]=1.9, [251148]=29.3, [251160]=4.5, [251173]=1.3, [268197]=3.7, [268211]=17.8, [268221]=0.6, [268232]=45.9, [268242]=7.0, [268243]=6.4, [268248]=26.1, [268252]=16.6, [268255]=10.8, [268257]=15.9, [268263]=8.5, [268265]=94.3, [268266]=19.7, [270164]=64.3, [270167]=13.4, [270169]=9.6, [271092]=26.1, [271434]=9.6, [271435]=61.1, [271559]=18.5, [271562]=84.7, [271563]=93.6, [271564]=83.4, [271565]=77.1, [271566]=10.8, [271567]=96.8, [271638]=3.2, [271874]=7.6, [272148]=5.1, [273792]=8.9 },
    ["MAGE/FIRE/Sunfury"] = { [155945]=8.2, [156207]=1.3, [159243]=39.9, [159247]=2.5, [159263]=7.6, [159288]=33.5, [159459]=34.2, [162544]=1.3, [171545]=1.9, [193691]=32.9, [239045]=5.1, [239648]=63.9, [239649]=15.2, [239650]=3.2, [239651]=7.6, [239653]=12.7, [239655]=12.0, [239656]=20.9, [240949]=1.9, [240951]=0.6, [245769]=80.0, [245770]=53.2, [249343]=0.6, [250144]=8.2, [250214]=5.1, [250215]=3.2, [250224]=1.9, [251136]=0.6, [251137]=18.4, [251139]=1.3, [251142]=25.3, [251148]=4.4, [251190]=14.6, [251191]=5.7, [251194]=1.9, [251792]=3.2, [252258]=29.7, [266317]=3.2, [268242]=2.5, [268251]=13.9, [268255]=17.1, [268257]=15.8, [268263]=11.4, [268265]=39.2, [268266]=32.3, [270161]=1.9, [270164]=26.6, [270167]=17.7, [270168]=1.3, [270169]=5.7, [271092]=30.4, [271562]=86.1, [271563]=85.4, [271564]=80.4, [271565]=81.6, [271567]=85.4, [271874]=14.6, [272147]=7.6, [272150]=1.9, [272235]=3.2, [273649]=9.5, [273778]=6.3, [273792]=0.6, [273796]=39.2, [275529]=2.5, [279010]=0.6, [280376]=0.6 },
    ["MAGE/FROST/Spellslinger"] = { [156230]=0.6, [158366]=22.6, [159234]=2.6, [159247]=11.0, [159459]=0.6, [162544]=7.7, [193757]=0.6, [239031]=9.7, [239648]=51.6, [239649]=41.9, [239650]=1.3, [239651]=1.3, [239656]=13.5, [240949]=7.7, [245769]=63.3, [245770]=60.6, [246304]=12.9, [249343]=1.9, [250214]=5.8, [250215]=30.3, [250224]=3.9, [251132]=42.6, [251136]=32.9, [251137]=16.1, [251139]=2.6, [251148]=5.8, [251185]=13.5, [251194]=1.9, [251219]=27.1, [251234]=25.8, [251513]=10.3, [251792]=0.6, [252258]=7.1, [268221]=3.2, [268228]=20.0, [268242]=1.9, [268249]=8.4, [268252]=1.9, [268263]=15.0, [268265]=47.7, [270164]=40.6, [270167]=29.7, [270168]=1.3, [271092]=20.0, [271559]=15.5, [271560]=8.4, [271561]=14.8, [271562]=86.5, [271563]=93.5, [271564]=76.8, [271565]=80.6, [271566]=14.8, [271567]=90.3, [271874]=17.4, [272147]=0.6, [272149]=3.9, [272150]=2.6, [273773]=3.9, [273778]=13.5, [273779]=11.7, [273781]=12.3, [273792]=9.0, [273794]=1.3, [273796]=1.3, [274493]=3.9, [275526]=7.7 },
    ["MONK/BREWMASTER/Shado-Pan"] = { [158366]=0.6, [159288]=34.6, [159300]=18.6, [159304]=26.9, [159313]=4.5, [159327]=32.1, [159617]=2.6, [193751]=9.0, [193758]=11.5, [237847]=30.8, [239048]=7.1, [240949]=2.6, [244569]=28.8, [244576]=45.5, [245771]=11.5, [246304]=2.6, [250215]=3.2, [250228]=1.9, [250245]=49.4, [251136]=9.0, [251146]=7.7, [251148]=43.6, [251183]=21.8, [251189]=17.9, [251194]=1.3, [251198]=7.7, [251226]=1.9, [251234]=16.0, [251513]=51.3, [266317]=1.3, [268215]=46.8, [268227]=19.9, [268234]=6.4, [268248]=26.3, [268265]=66.7, [270160]=5.1, [270164]=16.0, [270166]=2.6, [270173]=10.3, [270174]=7.7, [270175]=40.4, [271436]=26.9, [271438]=7.1, [271517]=92.3, [271518]=83.3, [271519]=81.4, [271520]=80.1, [271522]=91.0, [272148]=0.6, [272149]=1.9, [272226]=14.1, [272229]=8.3, [273796]=4.5, [274493]=1.3 },
    ["MONK/MISTWEAVER/Conduit of the Celestials"] = { [156207]=2.0, [158366]=3.3, [159301]=17.6, [159312]=4.6, [159327]=15.0, [159459]=13.7, [162544]=9.2, [171853]=7.8, [193751]=1.3, [193757]=8.5, [193763]=19.0, [239048]=3.3, [239656]=17.6, [240949]=9.8, [244569]=30.7, [244570]=2.6, [244574]=9.8, [244575]=7.2, [244576]=55.6, [245770]=78.4, [249346]=2.6, [249808]=15.0, [250214]=5.9, [250215]=2.0, [250255]=5.2, [251130]=5.9, [251135]=11.8, [251136]=1.3, [251142]=5.2, [251148]=6.5, [251156]=0.7, [251190]=29.4, [251191]=100.0, [251194]=2.6, [251223]=3.3, [251513]=1.3, [251792]=3.9, [252258]=37.9, [268205]=20.3, [268227]=24.2, [268240]=26.1, [268247]=26.8, [268249]=4.6, [268265]=81.0, [268266]=13.7, [268290]=0.7, [270162]=51.6, [270164]=10.5, [270167]=18.3, [270169]=2.6, [270171]=2.6, [271436]=20.9, [271517]=94.1, [271518]=83.7, [271519]=64.7, [271520]=83.0, [271522]=91.5, [271875]=33.3, [272147]=1.3, [272150]=0.7, [273774]=2.0, [273781]=3.9, [273792]=17.0, [273796]=0.7, [279010]=7.8 },
    ["MONK/WINDWALKER/Conduit of the Celestials"] = { [158366]=34.7, [159459]=1.3, [171642]=1.3, [171853]=1.3, [240949]=5.3, [244569]=80.0, [244570]=2.7, [244574]=6.0, [244575]=3.3, [244576]=86.0, [245771]=4.7, [249343]=2.7, [250214]=2.7, [250215]=1.3, [250228]=4.7, [251132]=38.7, [251135]=4.7, [251136]=17.3, [251142]=1.3, [251153]=5.3, [251190]=30.7, [251194]=2.7, [251513]=20.0, [252258]=22.0, [268199]=4.0, [268215]=88.7, [268225]=8.0, [268227]=18.0, [268234]=14.0, [268235]=2.0, [268240]=6.7, [268246]=10.7, [268249]=6.0, [268256]=28.7, [268261]=5.3, [268265]=94.0, [270164]=6.7, [270165]=18.7, [270166]=2.7, [270173]=43.3, [270175]=85.3, [271436]=19.3, [271438]=0.7, [271514]=10.7, [271517]=88.7, [271518]=84.0, [271519]=87.3, [271520]=78.7, [271522]=94.0, [271638]=2.7, [271875]=12.0, [272147]=3.3, [272149]=0.7, [272150]=11.3, [272244]=0.7, [273792]=11.3, [274493]=4.0, [279010]=4.7 },
    ["PALADIN/HOLY/Herald of the Sun"] = { [158366]=0.7, [159425]=5.2, [159435]=3.3, [159459]=34.0, [162544]=1.3, [193757]=2.6, [193763]=27.5, [237828]=38.6, [237829]=4.6, [237831]=17.0, [237834]=80.4, [237836]=12.4, [237843]=60.1, [239050]=4.6, [240949]=9.2, [248583]=2.6, [250214]=3.9, [250215]=2.6, [250259]=1.3, [251136]=2.0, [251148]=24.2, [251173]=8.5, [251193]=8.5, [251194]=3.3, [252258]=10.5, [268196]=29.4, [268210]=26.1, [268211]=9.2, [268220]=4.6, [268226]=1.3, [268229]=7.8, [268239]=7.2, [268244]=15.7, [268245]=22.2, [268248]=17.0, [268262]=23.5, [268265]=85.0, [268266]=9.2, [270162]=57.5, [270164]=44.4, [270167]=11.8, [270171]=0.7, [271444]=10.5, [271445]=44.4, [271460]=16.3, [271462]=13.1, [271463]=87.6, [271464]=80.4, [271465]=86.9, [271466]=77.1, [271468]=81.0, [271638]=2.6, [271878]=15.0, [273777]=12.4, [273792]=24.2, [273796]=0.7, [274493]=0.7 },
    ["PALADIN/PROTECTION/Lightsmith"] = { [158366]=3.3, [159413]=1.3, [159459]=9.2, [162544]=2.0, [193763]=22.2, [237828]=38.6, [237830]=34.0, [237831]=62.7, [237834]=39.2, [237839]=17.0, [239036]=3.3, [239037]=9.2, [239656]=24.8, [240949]=25.5, [250228]=7.2, [250229]=2.6, [250244]=1.3, [250245]=6.5, [251126]=3.9, [251133]=17.6, [251136]=5.2, [251148]=15.7, [251151]=2.0, [251173]=17.0, [251182]=3.9, [251214]=5.9, [251229]=5.2, [251513]=1.3, [252258]=7.8, [268196]=15.7, [268202]=24.8, [268209]=38.6, [268239]=12.4, [268244]=17.6, [268245]=19.0, [268249]=2.0, [268252]=2.0, [268253]=10.5, [268259]=22.2, [268262]=15.0, [268265]=55.6, [268266]=0.7, [270160]=10.5, [270163]=0.7, [270164]=11.8, [270165]=11.1, [270168]=1.3, [270171]=1.3, [270173]=30.7, [270174]=0.7, [270175]=34.0, [270602]=1.3, [271444]=5.2, [271463]=77.1, [271464]=69.3, [271465]=90.8, [271466]=91.5, [271468]=91.5, [271878]=25.5, [272148]=8.5, [273777]=20.3, [273781]=26.1, [273792]=44.4, [273796]=9.2, [274493]=3.3 },
    ["PALADIN/RETRIBUTION/Herald of the Sun"] = { [158366]=5.1, [159413]=3.2, [159459]=3.8, [162544]=3.8, [171853]=3.2, [237828]=12.7, [237829]=2.5, [237832]=2.5, [237834]=83.4, [237836]=17.2, [237846]=17.8, [237848]=11.5, [239051]=5.7, [240949]=1.3, [250228]=1.3, [251133]=1.3, [251136]=23.6, [251142]=15.9, [251148]=0.6, [251190]=17.8, [251513]=31.8, [252258]=35.0, [268213]=58.0, [268222]=1.3, [268229]=2.5, [268239]=15.3, [268249]=21.7, [268252]=5.1, [268253]=33.1, [268259]=24.2, [268260]=40.1, [268265]=76.4, [270164]=3.8, [270165]=17.8, [270173]=57.3, [270175]=75.8, [270602]=3.2, [271444]=8.9, [271445]=40.8, [271460]=28.7, [271462]=22.3, [271463]=77.7, [271464]=89.8, [271465]=94.9, [271466]=78.3, [271467]=28.7, [271468]=95.5, [271638]=6.4, [271878]=9.6, [272147]=1.9, [272149]=2.5, [272150]=6.4, [273776]=0.6, [273792]=0.6, [273796]=0.6 },
    ["PRIEST/DISCIPLINE/Voidweaver"] = { [158366]=8.4, [159259]=18.7, [159459]=11.0, [162544]=0.6, [171654]=0.6, [193757]=2.6, [239031]=5.2, [239648]=63.9, [239649]=36.1, [239650]=2.6, [239653]=7.1, [239655]=6.5, [239656]=17.4, [240949]=1.9, [245769]=53.6, [245770]=27.1, [249343]=0.6, [249808]=3.9, [250215]=1.9, [250254]=0.6, [250255]=3.2, [251127]=14.2, [251132]=12.3, [251136]=9.0, [251137]=23.9, [251173]=12.3, [251190]=29.7, [251222]=11.0, [251792]=0.6, [252258]=26.5, [264701]=0.6, [268197]=15.5, [268203]=1.9, [268218]=19.4, [268221]=3.2, [268228]=10.3, [268236]=0.6, [268242]=1.9, [268243]=11.6, [268249]=9.7, [268252]=9.0, [268257]=20.0, [268263]=14.5, [268265]=81.9, [268266]=6.5, [268290]=3.2, [270161]=5.2, [270162]=40.6, [270164]=26.5, [270167]=27.7, [270169]=9.7, [270171]=1.9, [271092]=65.8, [271553]=89.0, [271554]=98.1, [271555]=57.4, [271556]=78.1, [271558]=89.0, [271874]=38.1, [272147]=1.3, [272149]=3.2, [272150]=0.6, [273781]=2.6, [273786]=1.3, [273792]=29.0, [273796]=2.6, [274493]=1.9 },
    ["PRIEST/HOLY/Oracle"] = { [158366]=3.3, [159243]=15.8, [159247]=5.9, [159288]=15.1, [159459]=16.4, [162544]=0.7, [193757]=2.0, [239045]=3.3, [239648]=57.9, [239649]=59.2, [239650]=5.3, [239652]=4.6, [240949]=3.9, [245769]=55.9, [245770]=46.7, [249343]=0.7, [250214]=3.3, [250255]=1.3, [251136]=11.2, [251139]=6.6, [251148]=21.1, [251154]=12.5, [251160]=3.9, [251190]=20.4, [251194]=3.3, [251222]=13.8, [251792]=2.6, [252258]=8.6, [268197]=20.6, [268210]=7.2, [268218]=20.4, [268221]=3.9, [268228]=16.4, [268236]=3.3, [268243]=5.3, [268248]=18.4, [268249]=5.9, [268252]=5.9, [268257]=9.9, [268263]=11.8, [268265]=62.5, [268266]=7.9, [268292]=0.7, [270162]=50.0, [270164]=27.0, [270167]=25.0, [270169]=0.7, [270171]=0.7, [271092]=31.6, [271435]=15.8, [271553]=86.2, [271554]=92.1, [271555]=72.4, [271556]=86.2, [271558]=87.5, [271638]=7.2, [271874]=18.4, [272147]=3.9, [272148]=2.0, [272149]=1.3, [272150]=0.7, [273781]=22.4, [273792]=29.6 },
    ["PRIEST/SHADOW/Archon"] = { [158366]=14.6, [159247]=5.7, [193691]=19.0, [239031]=4.4, [239045]=6.3, [239648]=67.1, [239649]=37.3, [239651]=19.0, [239655]=1.3, [240949]=2.5, [245769]=57.5, [245770]=20.9, [246305]=0.6, [248583]=1.3, [249343]=0.6, [250214]=8.9, [250215]=17.7, [250224]=0.6, [251127]=13.3, [251132]=38.0, [251136]=25.9, [251137]=19.6, [251142]=8.2, [251190]=15.2, [251199]=7.6, [251234]=2.5, [251792]=0.6, [252258]=43.7, [268197]=27.5, [268218]=13.3, [268228]=13.9, [268236]=4.4, [268243]=3.8, [268249]=15.2, [268252]=5.1, [268253]=12.7, [268257]=17.7, [268263]=12.5, [268265]=86.1, [270164]=29.1, [270167]=28.5, [270169]=23.4, [271092]=57.0, [271435]=26.6, [271553]=84.8, [271554]=72.2, [271555]=84.8, [271556]=84.8, [271558]=96.2, [271874]=6.3, [272147]=1.3, [272149]=1.3, [272150]=1.3, [273778]=11.4, [273785]=2.5, [273792]=31.0, [273796]=22.2 },
    ["ROGUE/ASSASSINATION/Fatebound"] = { [158366]=9.9, [159312]=9.3, [159327]=25.2, [193701]=0.7, [193763]=37.1, [237837]=46.4, [240949]=17.2, [244569]=25.2, [244570]=2.0, [244575]=11.9, [244576]=73.5, [250225]=0.7, [251130]=2.0, [251132]=29.1, [251136]=17.2, [251148]=0.7, [251183]=5.3, [251194]=2.0, [251223]=7.3, [251234]=2.6, [252258]=12.6, [268204]=14.6, [268225]=4.0, [268227]=19.9, [268235]=3.3, [268240]=15.9, [268246]=7.9, [268249]=10.6, [268252]=19.2, [268253]=16.6, [268256]=22.5, [268261]=21.2, [268265]=90.7, [270164]=12.6, [270165]=43.0, [270166]=2.0, [270168]=13.2, [270173]=7.3, [270175]=74.2, [271093]=31.1, [271436]=32.5, [271508]=82.8, [271509]=94.0, [271510]=92.7, [271511]=78.8, [271513]=93.4, [271875]=7.3, [272149]=0.7, [272150]=1.3, [273781]=3.3, [273792]=29.1, [273796]=4.0, [275070]=21.2 },
    ["ROGUE/OUTLAW/Trickster"] = { [158366]=3.2, [159459]=6.3, [159617]=5.7, [193763]=38.0, [237837]=17.1, [237839]=38.6, [237841]=5.7, [240949]=14.6, [244569]=45.6, [244570]=7.0, [244573]=34.8, [244574]=3.8, [244575]=15.2, [244576]=60.8, [250215]=8.2, [250228]=8.9, [251124]=7.6, [251132]=11.4, [251135]=12.7, [251136]=3.8, [251148]=31.0, [251153]=31.0, [251189]=28.5, [251223]=5.7, [251226]=6.3, [268209]=48.7, [268225]=3.2, [268240]=17.7, [268248]=38.0, [268252]=21.5, [268261]=9.5, [268265]=87.3, [268266]=7.6, [270164]=10.8, [270165]=8.9, [270166]=7.0, [270173]=36.1, [270175]=51.9, [271093]=15.2, [271436]=13.9, [271438]=1.9, [271508]=93.7, [271509]=89.9, [271510]=80.4, [271511]=69.0, [271513]=86.7, [271638]=4.4, [271875]=17.7, [272148]=7.6, [273774]=0.6, [273781]=5.1, [273792]=32.3, [275070]=53.8 },
    ["ROGUE/SUBTLETY/Deathstalker"] = { [158366]=11.5, [159288]=25.6, [159304]=18.6, [159327]=20.5, [159337]=2.6, [162544]=32.7, [237837]=64.7, [240949]=13.5, [244574]=7.1, [244576]=87.8, [250214]=5.8, [250215]=1.9, [250228]=0.6, [251124]=3.2, [251132]=24.4, [251136]=7.1, [251140]=0.6, [251142]=7.1, [251159]=1.9, [251183]=6.4, [251194]=32.7, [251223]=3.2, [251226]=3.2, [251235]=10.9, [252258]=4.5, [268225]=6.4, [268240]=3.2, [268246]=3.8, [268249]=30.8, [268251]=4.5, [268252]=4.5, [268253]=18.6, [268256]=26.3, [268261]=21.8, [268264]=7.7, [268265]=83.3, [270164]=17.9, [270165]=22.4, [270166]=0.6, [270168]=0.6, [270173]=14.7, [270175]=60.3, [271093]=25.0, [271436]=31.4, [271508]=92.3, [271509]=85.9, [271510]=68.6, [271511]=91.7, [271513]=93.6, [271875]=29.5, [272149]=1.3, [272150]=0.6, [273792]=0.6, [273797]=0.6, [275070]=39.7 },
    ["SHAMAN/ELEMENTAL/Farseer"] = { [158366]=22.3, [159375]=11.5, [193752]=5.1, [239656]=14.6, [240949]=15.3, [244577]=15.9, [244581]=19.7, [244582]=12.7, [244584]=82.2, [245770]=42.0, [250215]=8.3, [251132]=33.1, [251136]=31.2, [251155]=21.7, [251233]=1.3, [251513]=12.7, [252258]=6.4, [268196]=20.9, [268210]=11.5, [268217]=5.7, [268230]=1.3, [268231]=1.9, [268238]=4.5, [268249]=12.7, [268252]=7.6, [268253]=21.7, [268254]=20.4, [268258]=36.3, [268262]=50.5, [268263]=16.5, [268265]=93.0, [268266]=8.3, [270164]=80.9, [270167]=1.3, [270169]=3.2, [271092]=36.3, [271440]=42.7, [271441]=8.3, [271481]=97.5, [271482]=73.9, [271483]=89.8, [271484]=86.6, [271486]=86.0, [271638]=4.5, [271876]=12.7, [272252]=0.6, [273775]=5.1, [273781]=1.9, [273792]=24.8, [273796]=70.7 },
    ["SHAMAN/ENHANCEMENT/Stormbringer"] = { [156310]=1.3, [158366]=11.7, [159380]=3.2, [159388]=19.5, [162544]=0.6, [237850]=73.4, [239049]=1.3, [240949]=7.8, [244577]=14.9, [244581]=20.8, [244582]=8.4, [244583]=1.9, [244584]=87.0, [250214]=2.6, [250215]=4.5, [250225]=2.6, [250228]=3.2, [251136]=22.7, [251142]=7.8, [251190]=21.4, [251224]=9.7, [251228]=26.0, [251233]=1.3, [251234]=14.3, [251513]=3.2, [252258]=33.8, [268206]=7.1, [268209]=61.0, [268231]=1.9, [268237]=20.1, [268238]=0.6, [268249]=3.2, [268252]=2.6, [268253]=20.1, [268254]=31.2, [268258]=20.1, [268265]=64.9, [270164]=7.1, [270165]=13.6, [270166]=0.6, [270173]=37.7, [270175]=35.1, [271441]=2.6, [271478]=26.6, [271479]=4.5, [271481]=96.8, [271482]=64.3, [271483]=97.4, [271484]=96.8, [271486]=77.9, [271876]=19.5, [272147]=6.5, [273792]=29.2, [273796]=24.0, [279010]=1.3 },
    ["SHAMAN/RESTORATION/Totemic"] = { [155964]=5.9, [158366]=0.7, [159369]=11.2, [159380]=4.6, [159459]=7.9, [171622]=0.7, [193759]=6.6, [193763]=23.0, [237831]=52.5, [239046]=0.7, [239656]=14.5, [240949]=12.5, [244577]=15.1, [244579]=7.2, [244580]=11.8, [244581]=15.1, [244582]=5.3, [244583]=10.5, [244584]=84.9, [245770]=7.2, [248583]=2.0, [250246]=0.7, [250254]=2.6, [250255]=32.9, [251125]=22.4, [251136]=0.7, [251148]=39.5, [251184]=2.6, [251196]=22.7, [268196]=16.3, [268210]=10.5, [268216]=53.3, [268238]=4.6, [268248]=36.2, [268250]=5.3, [268252]=9.2, [268265]=80.3, [268266]=4.6, [270162]=58.6, [270164]=17.1, [270167]=3.9, [270171]=2.6, [271092]=70.4, [271440]=40.1, [271441]=6.6, [271481]=82.9, [271482]=79.6, [271483]=78.9, [271484]=82.2, [271486]=98.0, [271876]=1.3, [272148]=11.2, [273781]=7.9, [273792]=29.6, [274493]=1.3, [279009]=0.7 },
    ["WARLOCK/AFFLICTION/Hellcaller"] = { [158366]=9.7, [159247]=0.6, [159259]=23.9, [159459]=0.6, [193750]=1.3, [193763]=45.2, [239031]=16.8, [239032]=0.6, [239045]=2.6, [239648]=80.0, [239649]=32.9, [239656]=23.2, [240949]=6.5, [245769]=65.0, [245770]=32.3, [246305]=0.6, [250215]=5.2, [250224]=10.3, [251127]=9.0, [251136]=12.3, [251148]=7.1, [251173]=12.3, [251219]=36.1, [251222]=21.3, [251513]=0.6, [252258]=17.4, [268228]=5.2, [268232]=19.4, [268242]=7.7, [268248]=9.7, [268252]=6.5, [268263]=15.5, [268265]=72.3, [268266]=12.9, [270164]=38.1, [270167]=32.3, [270168]=0.6, [271092]=32.3, [271544]=77.4, [271545]=94.2, [271546]=71.6, [271547]=96.1, [271548]=16.8, [271549]=98.7, [271874]=12.9, [272147]=5.2, [272148]=2.6, [273649]=9.7, [273773]=2.6, [273778]=15.5, [273779]=18.4, [273781]=13.5, [273785]=0.6, [273786]=3.9, [273792]=42.6, [273794]=0.6, [273796]=64.5, [274493]=0.6, [279010]=0.6 },
    ["WARLOCK/DEMONOLOGY/Diabolist"] = { [158366]=8.8, [159247]=1.4, [162544]=1.4, [239032]=1.4, [239648]=54.1, [239649]=20.9, [239651]=9.5, [239655]=12.2, [239656]=22.3, [240949]=12.8, [245769]=91.8, [245770]=43.2, [250215]=6.1, [251132]=18.9, [251136]=27.0, [251148]=0.7, [251185]=16.2, [251513]=0.7, [252258]=2.0, [268205]=15.5, [268228]=33.1, [268232]=26.4, [268236]=8.1, [268241]=0.7, [268249]=4.7, [268252]=37.8, [268255]=19.6, [268263]=4.9, [268265]=80.4, [268266]=2.0, [270164]=68.2, [270167]=9.5, [270169]=15.5, [271092]=32.4, [271434]=2.0, [271435]=29.7, [271541]=15.5, [271542]=6.8, [271544]=95.9, [271545]=76.4, [271546]=95.3, [271547]=93.9, [271548]=20.9, [271549]=86.5, [271638]=7.4, [271874]=4.7, [273649]=8.8, [273773]=2.7, [273779]=3.3, [273781]=6.1, [273792]=29.1, [273794]=2.7, [273796]=56.1 },
    ["WARLOCK/DESTRUCTION/Hellcaller"] = { [156168]=16.9, [158366]=10.8, [159288]=17.6, [159459]=3.4, [162544]=5.4, [239045]=5.4, [239648]=53.4, [239649]=48.0, [239656]=26.4, [240949]=10.1, [245769]=66.7, [245770]=54.1, [246304]=1.4, [246305]=1.4, [250214]=6.8, [250215]=44.6, [250224]=8.1, [251127]=10.8, [251136]=27.0, [251137]=20.9, [251147]=4.1, [251148]=3.4, [251160]=0.7, [251173]=12.2, [251194]=2.7, [251219]=23.0, [251222]=14.9, [251227]=11.5, [251232]=1.4, [252258]=12.2, [256980]=4.7, [268218]=18.2, [268221]=0.7, [268243]=11.5, [268249]=6.8, [268252]=6.1, [268263]=14.0, [268265]=68.2, [268266]=0.7, [270161]=1.4, [270164]=29.7, [270167]=6.8, [270168]=8.1, [270169]=3.4, [270170]=0.7, [271092]=25.0, [271541]=18.2, [271543]=11.5, [271544]=75.7, [271545]=97.3, [271546]=89.9, [271547]=76.4, [271549]=94.6, [271874]=7.4, [272147]=0.7, [272148]=4.7, [272150]=0.7, [273778]=9.5, [273779]=12.3, [273781]=8.1, [273786]=0.7, [273792]=31.8, [273796]=7.4, [274493]=0.7 },
    ["WARRIOR/ARMS/Slayer"] = { [158366]=10.1, [193763]=17.7, [237828]=54.4, [237832]=7.0, [237834]=73.4, [237835]=1.9, [237836]=17.7, [237846]=18.4, [240949]=12.0, [250228]=0.6, [251132]=25.3, [251133]=5.7, [251136]=7.6, [251173]=4.4, [251214]=0.6, [251229]=0.6, [251513]=7.6, [252258]=40.5, [265657]=5.1, [268213]=67.1, [268214]=10.8, [268222]=2.5, [268224]=1.9, [268239]=15.2, [268245]=29.1, [268249]=9.5, [268252]=31.6, [268253]=28.5, [268259]=26.6, [268265]=86.1, [270164]=12.7, [270165]=41.8, [270173]=35.4, [270175]=14.6, [271444]=5.7, [271445]=47.5, [271453]=18.4, [271454]=89.9, [271455]=89.2, [271456]=92.4, [271457]=81.0, [271458]=7.6, [271459]=97.5, [271878]=8.2, [273781]=5.7, [273792]=22.8, [273796]=0.6, [274493]=0.6 },
    ["WARRIOR/FURY/Slayer"] = { [158366]=14.8, [159413]=5.8, [159459]=1.9, [162544]=5.2, [171699]=1.9, [193753]=1.3, [237828]=67.1, [237834]=87.1, [237835]=1.9, [237836]=5.8, [237846]=34.2, [239050]=0.6, [240949]=5.2, [248583]=0.6, [249342]=1.3, [249343]=6.5, [250228]=3.2, [251133]=6.5, [251136]=3.9, [251138]=1.9, [251142]=46.5, [251144]=16.1, [251173]=3.9, [251190]=47.1, [251194]=11.0, [251513]=1.3, [251792]=0.6, [252258]=49.7, [268213]=55.5, [268214]=41.9, [268222]=3.9, [268224]=5.8, [268229]=1.3, [268239]=3.2, [268249]=9.0, [268252]=0.6, [268253]=26.5, [268259]=36.8, [268260]=12.3, [268265]=41.3, [270163]=2.6, [270164]=11.6, [270165]=24.5, [270173]=41.9, [270175]=35.5, [271451]=9.7, [271453]=12.3, [271454]=95.5, [271455]=87.7, [271456]=98.1, [271457]=74.8, [271458]=8.4, [271459]=94.8, [271878]=3.9, [272147]=5.8, [272149]=1.9, [272150]=1.9, [273782]=19.4, [273792]=9.7, [273796]=5.8, [273797]=0.6, [275527]=0.6, [279010]=0.6 },
    ["WARRIOR/PROTECTION/Mountain Thane"] = { [158366]=5.2, [159413]=10.3, [159418]=25.2, [159459]=38.7, [162544]=0.6, [193763]=31.6, [237828]=47.7, [237831]=42.9, [237834]=85.2, [237835]=3.2, [237839]=16.8, [239050]=7.7, [240949]=9.7, [249342]=5.8, [249343]=1.3, [249806]=1.9, [250228]=7.1, [250229]=1.9, [250243]=3.9, [250245]=7.7, [251133]=4.5, [251136]=3.2, [251148]=11.0, [251150]=22.7, [251173]=16.8, [251182]=2.6, [251190]=15.5, [251193]=11.6, [251194]=0.6, [251214]=13.5, [251229]=4.5, [251234]=11.0, [252258]=40.0, [268196]=18.8, [268202]=55.5, [268209]=12.9, [268222]=1.9, [268239]=3.9, [268244]=21.9, [268249]=1.3, [268252]=3.2, [268253]=14.8, [268265]=58.7, [268266]=1.9, [270160]=12.3, [270163]=3.9, [270164]=14.8, [270165]=16.1, [270173]=20.0, [270174]=6.5, [270175]=27.1, [271444]=3.9, [271453]=12.9, [271454]=90.3, [271455]=89.7, [271456]=85.2, [271457]=69.0, [271459]=85.8, [271878]=4.5, [272147]=1.9, [272150]=1.3, [272256]=12.9, [273777]=11.6, [273792]=19.4, [273795]=1.3, [273796]=2.6, [274493]=2.6 },
}

-- ── 打包数据（格式见 services/wow-agent/bisdata_pack.py，解码器 core/BisPack.lua）──
-- ⛔ 别手改：itemId 与池索引是对应死的，改一个数字就是改一件装备。
BisData.packFormat = 1

BisData.pool_n = { "灾厄墓骑面甲", "破法者的掩蔽", "复生祭品护颅", "亚基克星藏骨匣", "哨兵的强酸锁链", "护卫之牙束带", "灾厄墓骑绞架肩铠", "遗忘祭品肩铠", "涌潮之海护肩", "灾厄墓骑胸甲", "破法者的庇护", "狂野精魂胸甲", "剧毒悔恨束带", "遗忘石窟束带", "尖牙蛮兵重型腰带", "灾厄墓骑护腿", "无羁深仇腿甲", "烈毒守卫护腿", "入殓教徒的马靴", "破法者的步伐", "鳞魔战靴", "破法者的护腕", "缚壳臂甲", "监督者的护臂", "灾厄墓骑死握护手", "破法者的决意", "鳞甲锁喉护手", "阿曼尼督军的指环", "仪式束缚者之戒", "阿特洛苏斯的腐化玺戒", "诱人水泡指环", "充能沙石指环", "咆哮奴役玺戒", "顶级蛮兵爪戒", "神灵崇拜者的指环", "窃来的珍贵指环", "游蛇之环", "邪恶炼金师指环", "翠玉盘蛇指环", "护光者的禁锢", "精工辛多雷指环", "衔尾蛇印玺", "长蛇绕环", "妖术指环", "乌拉特克贪婪之心", "守护者的躁动核心", "斯索拉克的凶猛", "剧毒狂怒之泉", "共鸣咆哮石", "破损的阿曼尼战旗", "祖尔金的处斩技法", "虫群之瘤", "盖博的无底袋", "乌拉特克信徒塑像", "丝质巫毒斗篷", "信徒的流丝罩袍", "防火斗披", "迈兹罗阿，督军的狂怒", "血骑士的战剑", "恶毒齿缘巨剑", "诱引巨盔", "多曼纳尔的寄生契约", "恶毒之怒吊坠", "烬怒肩铠", "灾厄墓骑束带", "致命净化束腰", "Baleful Grave-Knight's Vambraces", "鸟类守护者手套", "猎捕手的指环", "活体苦痛纤维", "焕新羁绊之鼓", "光荣征伐者的信物", "私酿酒馆裹布", "灾厄墓骑大披风", "阿曼穆索，督军的复仇", "强血者的仪式切肉斧", "被缚女神之颚", "破法者的利剑", "掠食者面甲", "沙漠卫士胸甲", "战争之神神像", "强酸守护者粉碎锤", "深渊末日猎犬的无情凝视", "盘卷守望者的凝视", "邪犬伪装", "深渊末日猎犬之颚", "泛沫毒液护肩", "银月城特工的披肩", "深渊末日猎犬核心护甲", "银月城特工的外套", "觉醒外衣", "失魂颅骨束带", "孤寂容器束带", "深渊末日猎犬宝饰束腰", "深渊末日猎犬腿甲", "巧手交易马裤", "银月城特工的护腿", "银月城特工的匿踪靴", "磨砂蛇皮便鞋", "极地探险者裹腿", "银月城特工的偏斜腕甲", "无眠精魂镣铐", "怒羽护臂", "深渊末日猎犬的镶钉护手", "无情屠戮护手", "狂热防御护手", "货运者水壶", "一瓶肮脏的烈性毒液", "光塔核心", "唤波者的海石", "穿灵者的魔印", "血棘披风", "简斯拉泽，灵魂之牙", "破法者的战刃", "咒魇裂魂匕首", "神殿探窟者秘法头盔", "缚蛇的翡翠之眼", "圣洁爱慕外衣", "游蛇鳞束带", "沾涎游蛇便鞋", "护根者束腕", "干燥工的庇护手套", "瓦什尼克的血色深仇", "深渊末日猎犬华丽披风", "烈毒骨制战刃", "奇点利刃", "备用的代言人兜帽", "冲锋巨熊项圈", "无光肩甲", "瘟疫兽皮", "原始恐龙统领的腰带", "盘卷妖术护腿", "破浪皮靴", "征服者的寒冰之握", "大副的甲壳结界", "金辉飞羽", "呼啸枢纽神像", "黎明之根的幼苗", "瓶中的电荷元素", "虚空处刑指令", "墓穴行者之爪", "神秘梦境守望者的酣眠凝视", "神秘梦境守望者翎羽", "神秘梦境守望者的月光法服", "神秘梦境守望者护腿", "神秘梦境守望者护手", "银月城特工的裹手", "妖术领主的厄运神像", "幽影恶念之牙", "恶意精魂短棍", "艾林哈籁灯笼", "嘶鸣深渊脊骨", "霜鳞的秘法蕨叶", "呼啸风暴头冠", "旋风苦修者腰带", "寡妇蛛之吻", "红玉雏龙蛋壳", "深渊巢魔的长柄大斧", "穿潮者的击泡长杖", "艾林哈籁刺杖", "蛇行神灵兜帽", "蛇皮护肩", "拾荒者护肩", "雾猎者镶甲", "御风蝰蛇护腿", "猎捕手的印玺", "虚空收割者之契", "双子毒牙护符", "战争试炼行装", "雾猎者腿甲", "闪电防御之握", "五环印章", "盘魂者仪式容器", "Enigmatic Dreamwatcher's Cloak", "冷光嫩芽", "灾厄回响的熔岩塑形头盔", "永恒毒牙之冠", "碎卷者链甲帽", "灾厄回响的裂峰护肩", "游魂护肩", "远行者的璀璨之羽", "灾厄灼热火山口胸甲", "觉醒恐牙胸甲", "蛇裔毒牙锁甲", "蛇形调配腰带", "远行者的战利品腰带", "部族防御者腰索", "灾厄大地之柱护腿", "远行者的加固腿铠", "释缚结合腿甲", "凶暴鳞靴", "鲁莽旅人战靴", "闪光能量战靴", "远行者的板层护腕", "怒潮护腕", "电弧琉璃护腕", "灾厄回响的黑檀巨角护手", "远行者的锋芒爪套", "涡流之怒护手", "维克斯胡尔的涌流腺体", "驭风者视面盔", "Galerider's Byrnie", "受诅藏骨腰带", "驭风者网甲护腕", "远行者的不懈守望", "驭风者链扣护手", "超自然抗毒剂", "脉动搜寻者之眼", "暗月统御：狩猎", "潜伏蝰蛇的渗液之牙", "虚痕王冠", "潜伏蝰蛇之颚", "首皇护肩", "潜伏蝰蛇的鳞板胸甲", "潜伏蝰蛇的盘绕腿甲", "潜伏蝰蛇的穿皮护手", "风鸣护手", "强酸安息巨弓", "艾林哈籁蔓枝弓", "盖博的备用冲击枪", "叮当作响的邪能护肩", "潜伏蝰蛇的珍贵尖牙", "觉醒族裔腿铠", "剧毒深渊护胫", "血红显像之戒", "阿曼尼召唤披巾", "潜伏蝰蛇披风", "塞塔里斯的尖牙头盔", "操纵者胸甲", "奥利瑟拉佐尔指环", "燃铁灌注器", "血骑士的强击矛", "始源魔网守卫之冠", "守毒者的骇人兜帽", "迷途书卷贤者兜帽", "始源魔网守卫的法力涌流", "永恒盘绕饰肩", "殉难者的披肩", "始源魔网守卫护胸", "殉难者的法衣", "召唤师的灼热衬衣", "深渊海窟束带", "强酸缠链束带", "虚灵冥界腰带", "始源魔网守卫的精裁裹腿", "殉难者的护腿", "学徒的献祭紧身裤", "嘶鸣密教便鞋", "内克扎莉的御魂长靴", "狂笑履魂靴", "殉难者的裹腕", "啃咬之护臂", "毒灼护腕", "始源魔网守卫的法力塑形手套", "永恒暗影之握", "殉难者的手套", "灾厄妖术之刃", "监察官头冠", "始源仪式法袍", "殉难者的裹腰", "碧空鞍座腰索", "睿智巫毒便鞋", "暴风迅雷便鞋", "伪造的手套", "叛君指环", "新手争斗者的指环", "达萨的束风纹章", "塞塔里斯的亵渎遗物", "无眠部族披风", "抛光的光木引导杖", "晋升仪式披肩", "潮缚女巫法袍", "绒线护腿", "卷沙软鞋", "震荡极性裹手", "亵渎仪式裹手", "美猴王的不屈面容", "暗影猎手战帽", "美猴王流苏护肩", "美猴王战衣", "根须行者腰带", "美猴王长裤", "光孢护腿", "金羽长靴", "库拉的屠宰裹腕", "美猴王的斗拳", "银月城特工的多功能腰带", "神圣大厅马裤", "真菌药剂", "艾林哈籁手杖", "毒术师的飞翼导能杖", "美猴王敏捷束带", "祝圣烈焰战盔", "祝圣烈焰肩铠", "祝圣烈焰壁垒", "破法者的束带", "祝圣烈焰护腿", "誓言使者胫甲", "祝圣烈焰护手", "魔导师的法力之剑", "破法者的责难", "泡鳍挡水盾", "毒痕鳞甲盾", "破法者的披肩", "破法者的腿甲", "防毒踏靴", "凄惶手铠", "缚炎者之蹄", "祝圣烈焰披风", "艾杰斯亚谜题盒", "宇宙忏悔者的真视头饰", "宇宙忏悔者的回响尖啸", "宇宙忏悔者的星蚀法袍", "宇宙忏悔者的包覆裹腿", "蜷曲盘蛇护腿", "裂隙践踏靴", "宇宙忏悔者的天界之握", "魔导师的仪式之匕", "烈毒仪式披肩", "寒冬之拥护腕", "奥纹束带", "天选屠血者精魂兜帽", "天选屠血者巫毒护肩", "天选屠血者绑带罩衫", "天选屠血者加固长裤", "天选屠血者尖牙护手", "水晶牢笼之戒", "远行者的慈悲", "萨塔特克，腐化之息", "远古构造体的烈毒短刀", "锋利的光木挥砍者", "重力束带", "矩阵回稳器", "蛇裔神谕者蛇冠", "蛇裔神谕者嘶鸣披肩", "驭风者斗篷", "蛇裔神谕者尖牙法服", "腐蚀鳞片护胸", "巨兽束腰", "蛇裔神谕者护腿", "远行者的刀锋战靴", "蛇裔神谕者妖术之握", "铁根肩甲", "远行者的劈斧", "绽铸之爪", "神赐护胸", "邪能浸透之靴", "杀叶者护手", "受诅通灵师颅骨", "受诅通灵师尖塔肩甲", "巢穴净化者护肩", "受诅通灵师嘎响法袍", "受诅通灵师绑腿", "受诅通灵师焦黑之握", "受诅通灵师软鞋", "翡翠督军的淬火战角", "翡翠督军的狂怒肩铠", "翡翠督军胸铠", "翡翠督军重型腰带", "翡翠督军腿铠", "翡翠督军的镶玉护手", "翡翠督军披风", "翔天恐魔胸甲", "哈舒拉的腕轮", "迅猛龙之王头盔", "主根肋铠", "裂尖臂甲", "以太流明遮阳目镜", "远古将军的黑曜石之柱", "灾厄墓骑马靴", "防腐平稳护腕", "誓言使者护手", "哨兵挑战者的奖赏", "艾林先知的凝视", "威厄高尔的最终凝视", "深渊末日猎犬护腕", "叛君徽记", "神秘梦境守望者符印束带", "蠕动毒蛇之结", "腐沼的孢子之心", "机械师的护腕", "乌拉特克的束缚指环", "入侵者的火焰风暴护胸", "连击大戟", "神圣净化指环", "动荡的邪心水晶", "光耀希望之种", "传染之牙", "焰缚军官的头盔", "护卵者的护腿", "黑爪龙人的执法者护手", "恒常冰封护符", "墓葬构造体手套", "巫术聚焦器", "骇人灾厄大披风", "纳洛拉克的梦魇", "圣金古墓腰带", "遗忘部族的护足", "季节轮替护手", "猎捕手的指圈", "变压脉冲电容器", "柯姬雅的熄火短杖", "潜伏蝰蛇踏靴", "萨拉斯竞争者的链甲腕扣", "碎裂护手", "幽影羽毛", "光耀飞羽", "天谴之石", "尊主宝石匕首", "森林梦境护腿", "始源魔网守卫战靴", "蜿蜒洪流裹腕", "始源魔网守卫的咒术披风", "蹈火者的长裤", "侍女镣铐", "烬翼羽毛", "始源魔网守卫的镶宝带扣", "光绽围腰", "始源魔网守卫护腕", "有害聚焦之牙", "蛇纹护符", "雾猎者罩衫", "光盲圣怒的连祷", "堕落代言人法杖", "雾猎者护肩", "美猴王披风", "祝圣烈焰护腰", "充能二元腿铠", "克拉西斯封印者肩铠", "磐石马裤", "一统肩甲", "祝圣烈焰巨靴", "烈毒角斗士的凶猛徽章", "血骑士的慈悲", "唤孢者的绽放指环", "星界响铃", "殉难者的冠冕", "世界之根华盖", "破法者的通牒", "贪婪盛宴之牙", "多头蛇鳞护腕", "蛇裔神谕者护腕", "蛇裔神谕者仪式披风", "游蛇蛮兵之槌", "蛮力手斧", "护火腕甲", "血腥震尾指环", "充能宝珠", "泰达希尔的祭献", "重生巨蛇长袍", "乘风翱翔者马裤", "暗月统御：鲜血", "受诅通灵师镣铐", "受诅通灵师的锁链披风", "施毒者护肩", "囤积丰收裹布", "受诅通灵师鸣响束带", "理智之握", "深藤手套", "翡翠督军的残暴战靴", "秋日恩赐腰带", "上古饥渴之心", "邪恶扭牙长柄战刃", "誓言使者战靴", "风暴庇护" }
BisData.pool_s = { "套装转换", "制造业", "烈毒之渊（团本）-盘魂者内克扎莉", "烈毒之渊（团本）-乌拉特克", "烈毒之渊（团本）-陵寝哨兵", "大秘境-毒牙祭坛", "烈毒之渊（团本）-地区掉落", "潮缚石窟（团本）-尼姆瑞莎·唤波者", "烈毒之渊（团本）-盘卷祭坛", "烈毒之渊（团本）-万毒邪祟者瓦什尼克", "烈毒之渊（团本）-迷失的探险者", "大秘境-密谋小径", "烈毒之渊（团本）-双子毒牙", "大秘境-诸王之眠", "大秘境-虚空之痕竞技场", "大秘境-塞塔里斯神庙", "烈毒之渊（团本）-斯索拉克", "大秘境-纳洛拉克的洞穴", "烈毒之渊（团本）", "大秘境-夺目谷", "大秘境-红玉新生法池", "烈毒之渊（团本）-万毒邪祟者瓦什尼克/斯索拉克", "烈毒之渊（团本）-盘魂者内克扎莉/迷失的探险者", "来源待查", "世界掉落", "梦境裂隙（团本）-奇美鲁斯，未梦之神", "虚影尖塔（团本）-威厄高尔和艾佐拉克", "孢陨幽境（团本）-腐沼", "进军奎尔丹纳斯（团本）-贝洛朗，奥的子嗣", "虚影尖塔（团本）-光盲先锋军", "虚影尖塔（团本）-弗拉希乌斯", "烈毒之渊（团本）-万毒邪祟者瓦什尼克 / 潮缚石窟（团本）-尼姆瑞莎·唤波者", "烈毒之渊（团本）-盘魂者内克扎莉/万毒邪祟者瓦什尼克" }
BisData.pool_c = { "tier", "crafted", "raid", "mplus", "other", "world" }
BisData.pool_b = { "盘魂者内克扎莉", "乌拉特克", "陵寝哨兵", "毒牙祭坛", "地区掉落", "尼姆瑞莎·唤波者", "盘卷祭坛", "万毒邪祟者瓦什尼克", "迷失的探险者", "密谋小径", "双子毒牙", "诸王之眠", "虚空之痕竞技场", "塞塔里斯神庙", "斯索拉克", "纳洛拉克的洞穴", "夺目谷", "红玉新生法池", "万毒邪祟者瓦什尼克/斯索拉克", "盘魂者内克扎莉/迷失的探险者", "奇美鲁斯，未梦之神", "威厄高尔和艾佐拉克", "腐沼", "贝洛朗，奥的子嗣", "光盲先锋军", "弗拉希乌斯", "万毒邪祟者瓦什尼克 / 潮缚石窟（团本）-尼姆瑞莎·唤波者", "盘魂者内克扎莉/万毒邪祟者瓦什尼克" }
BisData.pool_h = { "2h", "1h", "frill", "ranged", "shield" }

BisData.pool_st = {
    { crit = 139, mastery = 62 },
    { crit = 99, mastery = 99 },
    { crit = 61, haste = 140 },
    { crit = 107, haste = 107, mastery = 107, versatility = 107 },
    { crit = 95, haste = 310 },
    { crit = 230, haste = 175 },
    { haste = 50, versatility = 101 },
    { crit = 100, mastery = 50 },
    { crit = 107, mastery = 44 },
    { crit = 61, mastery = 148 },
    { crit = 99, haste = 99 },
    { haste = 149, mastery = 60 },
    { crit = 110, mastery = 46 },
    { haste = 106, versatility = 44 },
    { crit = 98, mastery = 53 },
    { crit = 209 },
    { haste = 136, mastery = 65 },
    { crit = 105, haste = 46 },
    { crit = 74, mastery = 74 },
    { haste = 47, mastery = 104 },
    { crit = 56, mastery = 56 },
    { crit = 34, mastery = 79 },
    { crit = 42, haste = 65 },
    { crit = 52, mastery = 99 },
    { crit = 100, haste = 50 },
    { crit = 147, haste = 258 },
    { haste = 266, versatility = 139 },
    { haste = 278, mastery = 127 },
    { haste = 316, versatility = 89 },
    { crit = 232, mastery = 174 },
    { crit = 249, mastery = 156 },
    { crit = 338, haste = 67 },
    { crit = 228, mastery = 171 },
    { crit = 162, versatility = 243 },
    { haste = 258, mastery = 118 },
    { crit = 73, mastery = 332 },
    { mastery = 255, versatility = 151 },
    { mastery = 272, versatility = 133 },
    { crit = 199, mastery = 199 },
    { haste = 140, mastery = 236 },
    { crit = 242, versatility = 134 },
    { crit = 113, mastery = 263 },
    { crit = 149 },
    { mastery = 149 },
    { haste = 35, mastery = 83 },
    { crit = 56, haste = 56 },
    { crit = 42, haste = 71 },
    { crit = 148, mastery = 61 },
    { haste = 133, mastery = 67 },
    { crit = 5, mastery = 9 },
    { crit = 261, mastery = 145 },
    { haste = 127, mastery = 278 },
    { haste = 95, mastery = 56 },
    { haste = 107, versatility = 49 },
    { haste = 41, mastery = 19 },
    { crit = 47, mastery = 96 },
    { crit = 41, mastery = 31 },
    { crit = 66, mastery = 47 },
    { crit = 82, haste = 35 },
    { haste = 31, mastery = 73 },
    { crit = 35, mastery = 66 },
    { haste = 104 },
    { crit = 50, haste = 50 },
    { crit = 131, mastery = 70 },
    { crit = 75, mastery = 116 },
    { crit = 136 },
    { crit = 137, haste = 64 },
    { crit = 140, mastery = 68 },
    { haste = 209 },
    { haste = 112, mastery = 79 },
    { crit = 53, versatility = 97 },
    { crit = 99, mastery = 52 },
    { crit = 74, haste = 74 },
    { haste = 138, versatility = 63 },
    { haste = 139, mastery = 62 },
    { crit = 107, mastery = 43 },
    { haste = 49, mastery = 108 },
    { crit = 52, haste = 28 },
    { crit = 65, mastery = 144 },
    { crit = 118, mastery = 83 },
    { crit = 88, mastery = 62 },
    { crit = 56, haste = 95 },
    { crit = 74, haste = 39 },
    { crit = 104, mastery = 47 },
    { crit = 48, mastery = 102 },
    { crit = 98, haste = 53 },
    { haste = 143 },
    { haste = 73, mastery = 40 },
    { crit = 50, mastery = 50 },
    { crit = 30, mastery = 70 },
    { crit = 140, haste = 61 },
    { crit = 313, haste = 93 },
    { crit = 107, mastery = 83 },
    { crit = 103, haste = 47 },
    { crit = 70, mastery = 38 },
    { crit = 87, mastery = 56 },
    { haste = 81, versatility = 37 },
    { crit = 31, mastery = 70 },
    { crit = 56, haste = 39 },
    { crit = 86, haste = 115 },
    { crit = 139, haste = 266 },
    { crit = 95, haste = 56 },
    { crit = 112, versatility = 79 },
    { crit = 85, haste = 66 },
    { haste = 66, mastery = 143 },
    { haste = 99, versatility = 52 },
    { crit = 84, versatility = 59 },
    { mastery = 143 },
    { crit = 31, haste = 70 },
    { haste = 147, versatility = 62 },
    { crit = 131, haste = 70 },
    { crit = 69, haste = 140 },
    { mastery = 44, versatility = 106 },
    { haste = 149 },
    { haste = 32, mastery = 68 },
    { crit = 68, mastery = 33 },
    { crit = 71, versatility = 120 },
    { haste = 59, mastery = 91 },
    { haste = 215, mastery = 161 },
    { mastery = 209 },
    { crit = 136, versatility = 65 },
    { crit = 7, haste = 5 },
    { crit = 59, versatility = 84 },
    { crit = 79, mastery = 112 },
    { mastery = 109, versatility = 92 },
    { haste = 27, mastery = 45 },
    { haste = 61, mastery = 344 },
    { haste = 71, mastery = 120 },
    { haste = 76, mastery = 115 },
    { mastery = 82, versatility = 69 },
    { haste = 177, mastery = 199 },
    { crit = 20, mastery = 41 },
    { haste = 42, mastery = 59 },
    { haste = 135, versatility = 66 },
    { crit = 136, mastery = 64 },
    { haste = 69, mastery = 132 },
    { crit = 109, versatility = 48 },
    { crit = 48, mastery = 109 },
    { haste = 74, mastery = 74 },
    { crit = 74, mastery = 33 },
    { crit = 66, haste = 135 },
    { haste = 47, mastery = 103 },
    { crit = 95, mastery = 56 },
    { crit = 143, haste = 66 },
    { haste = 99, mastery = 99 },
    { haste = 144, mastery = 65 },
    { crit = 101, mastery = 50 },
    { crit = 66, mastery = 85 },
    { haste = 56, mastery = 56 },
    { crit = 35, mastery = 78 },
    { crit = 67, haste = 43 },
    { haste = 97, mastery = 53 },
    { mastery = 35, versatility = 61 },
    { haste = 38, mastery = 58 },
    { crit = 104, versatility = 46 },
    { crit = 66, haste = 41 },
    { crit = 91, haste = 52 },
    { crit = 143 },
    { haste = 143, mastery = 58 },
    { haste = 120, mastery = 71 },
    { crit = 54, haste = 102 },
    { crit = 72, haste = 79 },
    { haste = 73, mastery = 136 },
    { crit = 59, mastery = 84 },
    { crit = 62, versatility = 88 },
    { crit = 24, versatility = 56 },
    { crit = 112, haste = 79 },
    { haste = 45, mastery = 106 },
    { crit = 209, versatility = 166 },
    { crit = 78, versatility = 35 },
    { crit = 81, mastery = 37 },
    { crit = 79, mastery = 122 },
    { crit = 120, haste = 71 },
    { crit = 204, haste = 172 },
    { haste = 136 },
    { haste = 143, mastery = 66 },
    { mastery = 107 },
    { crit = 57, haste = 143 },
    { crit = 102, haste = 48 },
    { haste = 107, versatility = 44 },
    { crit = 130, haste = 71 },
    { crit = 69, haste = 129 },
    { crit = 107, versatility = 44 },
    { haste = 102, mastery = 49 },
    { crit = 62, versatility = 139 },
    { mastery = 136, versatility = 64 },
    { crit = 100, mastery = 51 },
    { crit = 104, mastery = 46 },
    { haste = 105, mastery = 52 },
    { crit = 44, haste = 69 },
    { crit = 39, mastery = 74 },
    { haste = 52, mastery = 105 },
    { crit = 47, haste = 110 },
    { haste = 71, mastery = 33 },
    { haste = 122, mastery = 79 },
    { haste = 105, mastery = 96 },
    { haste = 53, versatility = 98 },
    { haste = 56, mastery = 95 },
    { mastery = 90, versatility = 53 },
    { haste = 225, versatility = 150 },
    { mastery = 102, versatility = 274 },
    { mastery = 52, versatility = 61 },
    { haste = 56, mastery = 44 },
    { haste = 52, mastery = 99 },
    { crit = 134, mastery = 67 },
    { crit = 113, mastery = 88 },
    { crit = 91, haste = 59 },
    { crit = 101, haste = 50 },
    { crit = 69, mastery = 82 },
    { crit = 31, mastery = 76 },
    { mastery = 133, versatility = 68 },
    { haste = 103, mastery = 47 },
    { haste = 62, mastery = 139 },
    { crit = 56, versatility = 95 },
    { crit = 135, versatility = 74 },
    { mastery = 71, versatility = 120 },
    { mastery = 66, versatility = 85 },
    { crit = 71, versatility = 42 },
    { haste = 106, versatility = 45 },
    { haste = 5, versatility = 7 },
    { haste = 63, mastery = 138 },
    { crit = 28, haste = 52 },
    { crit = 141, mastery = 60 },
    { crit = 105, mastery = 46 },
    { crit = 70, haste = 139 },
    { mastery = 59, versatility = 37 },
    { crit = 49, mastery = 101 },
    { haste = 33, mastery = 67 },
    { crit = 33, haste = 67 },
    { haste = 79, versatility = 72 },
    { mastery = 56, versatility = 87 },
    { haste = 83, versatility = 34 },
    { crit = 101, haste = 49 },
    { crit = 62, mastery = 139 },
    { haste = 143, versatility = 58 },
    { crit = 105, haste = 86 },
    { crit = 62, haste = 88 },
    { crit = 55, mastery = 102 },
    { crit = 99, haste = 52 },
    { crit = 71, mastery = 42 },
    { crit = 49, haste = 49 },
    { crit = 70, mastery = 139 },
    { haste = 43, versatility = 107 },
    { haste = 132, versatility = 69 },
    { crit = 74, haste = 135 },
    { crit = 172, mastery = 204 },
    { crit = 104 },
    { haste = 71, versatility = 30 },
    { crit = 58, haste = 42 },
    { mastery = 53, versatility = 98 },
    { crit = 54, mastery = 103 },
    { crit = 85, mastery = 57 },
    { crit = 146, haste = 63 },
    { crit = 93, haste = 108 },
    { haste = 91, mastery = 59 },
    { haste = 73, versatility = 136 },
    { crit = 46, mastery = 105 },
    { haste = 90, versatility = 53 },
    { crit = 124, versatility = 67 },
    { crit = 53, versatility = 98 },
    { mastery = 142, versatility = 67 },
    { crit = 69, haste = 73 },
    { haste = 141, mastery = 60 },
    { crit = 50, mastery = 107 },
    { haste = 107, mastery = 50 },
    { mastery = 68, versatility = 141 },
    { haste = 42, versatility = 18 },
    { crit = 58, haste = 90 },
    { haste = 79, versatility = 112 },
    { haste = 120, versatility = 71 },
    { haste = 44, versatility = 63 },
    { versatility = 130 },
    { crit = 108, haste = 93 },
    { haste = 102, versatility = 48 },
    { crit = 69, haste = 44 },
    { haste = 92, mastery = 51 },
    { crit = 124, mastery = 67 },
    { mastery = 123 },
    { haste = 74, mastery = 39 },
    { crit = 107, haste = 50 },
    { crit = 48, mastery = 275 },
    { crit = 50, haste = 57 },
    { haste = 148, mastery = 198 },
    { mastery = 116, versatility = 75 },
    { crit = 79, haste = 122 },
    { haste = 209, versatility = 166 },
    { mastery = 56, versatility = 39 },
    { mastery = 126, versatility = 75 },
    { haste = 75, versatility = 116 },
    { haste = 83, versatility = 40 },
    { crit = 39, mastery = 56 },
    { haste = 62, mastery = 81 },
    { haste = 35, mastery = 75 },
    { haste = 83, versatility = 118 },
    { haste = 62, versatility = 81 },
    { haste = 84, versatility = 59 },
    { haste = 203, versatility = 143 },
    { crit = 62, versatility = 33 },
    { haste = 47, mastery = 47 },
    { crit = 87, versatility = 56 },
    { haste = 50, mastery = 46 },
    { crit = 71, haste = 120 },
    { crit = 53, haste = 97 },
    { crit = 63, versatility = 44 },
    { haste = 73, versatility = 117 },
    { crit = 77, haste = 26 },
    { mastery = 94, versatility = 49 },
    { haste = 62, mastery = 88 },
    { mastery = 39, versatility = 74 },
    { crit = 57, haste = 44 },
    { crit = 220, haste = 156 },
    { crit = 67, versatility = 40 },
    { haste = 126, versatility = 75 },
    { crit = 54, haste = 88 },
    { crit = 80, mastery = 37 },
    { haste = 106, mastery = 45 },
    { crit = 50, haste = 101 },
    { crit = 116, versatility = 75 },
    { mastery = 62, versatility = 81 },
    { crit = 102, haste = 49 },
    { crit = 128 },
    { haste = 268, mastery = 55 },
    { mastery = 136 },
    { crit = 71, mastery = 120 },
    { crit = 34, mastery = 66 },
    { mastery = 57, versatility = 48 },
    { crit = 71, mastery = 36 },
    { haste = 77, mastery = 36 },
    { crit = 69, mastery = 31 },
    { haste = 33, mastery = 62 },
    { crit = 69, haste = 38 },
    { crit = 178, versatility = 168 },
    { crit = 61, versatility = 39 },
    { crit = 84, mastery = 109 },
    { crit = 67, mastery = 124 },
    { crit = 76, haste = 37 },
    { crit = 79, haste = 39 },
    { mastery = 62, versatility = 88 },
    { mastery = 122, versatility = 79 },
    { crit = 31, haste = 76 },
    { crit = 69, haste = 58 },
    { haste = 51, mastery = 100 },
    { mastery = 87, versatility = 56 },
    { crit = 110, haste = 90 },
    { crit = 84, haste = 59 },
    { haste = 63, mastery = 37 },
}

BisData.pool_bo = {
    { 6652, 13335, 12854, 13696, 13692, 13698, 1587 },
    { 12214, 13667, 13695, 12497, 13751, 14001, 8960, 12384, 8790, 13836, 13696 },
    { 6652, 13696, 13662, 13335, 12854 },
    { 6652, 13668, 13335, 13848, 13987 },
    { 6652, 13668, 13335, 12854 },
    { 42, 13668, 12854, 13696 },
    { 6652, 13335, 13694, 13697, 12854 },
    { 40, 13662, 13335, 10844, 12854 },
    { 43, 13662, 13334, 12854 },
    { 6652, 13335, 13848, 13690, 13698, 1597 },
    { 12214, 13667, 12497, 13751, 14001, 8960, 12384, 8792, 13836 },
    { 6652, 13662, 13335, 13848 },
    { 6652, 13695, 13662, 13335, 13848 },
    { 6652, 13695, 13662, 13335, 10844, 12854 },
    { 6652, 13335, 13708, 13848, 13693, 13698, 1597 },
    { 6652, 13662, 13335, 13848, 13708 },
    { 41, 13662, 13334, 12854 },
    { 6652, 13662, 13335, 12854 },
    { 12214, 13667, 12497, 13751, 14001, 13767, 8960, 8790, 13836 },
    { 6652, 13695, 13662, 13335, 12854 },
    { 13440, 6652, 13695, 13662, 12699, 12846 },
    { 13335, 13691, 6652, 13697, 12854 },
    { 13440, 6652, 13668, 12699, 12854 },
    { 13440, 41, 13668, 12699, 12854 },
    { 13440, 40, 13668, 12699, 12854 },
    { 12214, 13667, 8960, 12497, 13751, 14001, 13836 },
    { 6652, 13668, 12846 },
    { 6652, 13668, 12854 },
    { 12214, 13667, 12497, 13751, 14001, 12715, 8790, 13836 },
    { 6652, 13335, 13848 },
    { 6652, 13335, 12854, 13696 },
    { 42, 13335, 12854 },
    { 13440, 6652, 12699, 12854 },
    { 6652, 12854, 13696 },
    { 13440, 41, 12699, 12854 },
    { 6652, 13335, 12854 },
    { 6652, 12846 },
    { 12214, 13667, 12497, 13751, 14001, 8960, 12384, 8790, 13836 },
    { 13440, 6652, 13662, 12699, 12854 },
    { 12214, 12497, 13751, 14004, 13771, 8960, 8790, 13836 },
    { 13440, 6652, 13696, 13662, 12699, 12854 },
    { 6652, 13668, 12854, 13696 },
    { 6652, 13335, 13696, 13848, 1597, 13695 },
    { 6652, 13335, 12854, 13695, 1587 },
    { 13440, 6652, 13662, 12699, 12846 },
    { 40, 13668, 12846 },
    { 41, 12846, 13184 },
    { 6652, 13335, 13848, 1597 },
    { 42, 13335, 13848 },
    { 6652, 13335, 13848, 13847 },
    { 12214, 13667, 12497, 13751, 14001, 8790, 13836 },
    { 13440, 6652, 12699, 12846 },
    { 6652, 13335, 13696, 13847, 13848, 13692, 13698, 1597 },
    { 6652, 13696, 13662, 13335, 13848, 13847 },
    { 6652, 13335, 12854, 13694, 13697, 1587 },
    { 12214, 13667, 12497, 13751, 14001, 8793, 13836 },
    { 6652, 13335, 13690, 13698, 12854 },
    { 12214, 13667, 12497, 13751, 14001, 8960, 12384, 8793, 13836 },
    { 41, 13696, 13662, 13335, 13848 },
    { 6652, 13335, 13696, 13848, 1597 },
    { 6652, 13335, 13848, 13693, 13698, 1597 },
    { 12214, 13667, 12497, 13751, 14001, 8795, 13836 },
    { 12214, 12497, 13751, 14001, 8960, 12384, 8790, 13836 },
    { 13440, 42, 13662, 12699, 12854 },
    { 12214, 13667, 12497, 13751, 14001, 8960, 12384, 8790, 13836, 13696 },
    { 42, 13696, 13662, 13335, 12854 },
    { 13440, 40, 13696, 13662, 12699, 12854 },
    { 6652, 13335, 12854, 13691, 13697, 1587 },
    { 12214, 12497, 13751, 14001, 13771, 8960, 8791, 13836 },
    { 6652, 13334, 13696, 12854 },
    { 6652, 13668, 13335, 10844, 12854 },
    { 41, 13695, 13662, 13335, 10844, 12854 },
    { 13440, 41, 13696, 13662, 12699, 12851 },
    { 13440, 41, 12701, 12846 },
    { 13440, 41, 13695, 13662, 12699, 12854 },
    { 6652, 13662, 13334, 12854, 13696 },
    { 6652, 13334, 12854 },
    { 13440, 40, 12699, 12854 },
    { 12854, 13335, 13694, 6652, 13697, 13696 },
    { 13335, 13690, 6652, 13698, 12854 },
    { 12214, 13667, 12497, 13751, 14001, 8960, 12384, 8791, 13836 },
    { 41, 13335, 12854 },
    { 12214, 12497, 13751, 14001, 13771, 8960, 8793, 13836 },
    { 13440, 6652, 13696, 13662, 12699, 12846 },
    { 13440, 6652, 13695, 13662, 12699, 12854 },
    { 8902, 7756, 13668, 12699, 12846 },
    { 6652, 13335, 13848, 13846 },
    { 12214, 13667, 12497, 13751, 14004, 12715, 8795, 13836 },
    { 6652, 13662, 12846 },
    { 41, 13668, 13334, 12854 },
    { 13440, 43, 13662, 12699, 12846 },
    { 13334, 6652, 12854, 1587 },
    { 6652, 13696, 13662, 13334, 12854 },
    { 6652, 13696, 13662, 13335, 10844, 12854 },
    { 13335, 42, 13848, 13694, 13697, 1597 },
    { 6652, 13335, 13846, 13848, 13690, 13698, 1597 },
    { 6652, 13662, 13335, 13848, 13846 },
    { 12214, 13667, 12497, 13751, 14001, 8960, 12384, 8791, 13836, 13696 },
    { 13440, 6652, 13696, 13662, 12699, 12852 },
    { 12214, 13667, 12497, 13751, 14001, 8791, 13836 },
    { 6652, 13696, 13662, 12846 },
    { 40, 13696, 13662, 13335, 12854 },
    { 12214, 13667, 12497, 13751, 14001, 8795, 13836, 13696 },
    { 42, 13334, 12854 },
    { 12214, 8960, 13655, 12497, 13751, 14001, 13836 },
    { 6652, 13335, 12854, 13695, 13692, 13698, 1587 },
    { 6652, 13335, 13848, 13694, 13697, 1597 },
    { 13335, 43, 13848, 13693, 13698, 1597 },
    { 6652, 13335, 13691, 13697, 12854 },
    { 6652, 13335, 13848, 13708 },
    { 12214, 12497, 13751, 14004, 13771, 8960, 8791, 13836 },
    { 6652, 13335, 12854, 13696, 1587 },
    { 6652, 13662, 13335, 10844, 12854 },
    { 8902, 7756, 12699, 12846 },
    { 13335, 40, 13846, 13848, 13695, 13692, 13698, 1597 },
    { 6652, 13696, 13662, 13335, 13848, 13846 },
    { 13335, 13694, 6652, 13697, 12854 },
    { 12214, 13667, 12497, 13751, 8960, 12384, 8793, 13836 },
    { 13440, 40, 13662, 12699, 12853 },
    { 40, 13695, 13662, 13334, 12854 },
    { 6652, 13335, 13693, 13698, 12854 },
    { 6652, 13662, 13334, 12854 },
    { 12214, 13667, 12497, 13751, 14001, 8960, 12384, 8793, 13836, 13696 },
    { 6652, 13335, 13848, 13691, 13697, 1597 },
    { 6652, 13662, 12854 },
    { 13657, 12846 },
    { 13440, 6652, 12699, 12852 },
    { 6652, 12854 },
    { 13440, 40, 13662, 12699, 12854 },
    { 13440, 41, 13662, 12699, 12854 },
    { 6652, 13335, 13847, 13848, 13695, 13692, 13698, 1597 },
    { 12854, 13335, 13690, 6652, 13698 },
    { 13335, 41, 13848, 13693, 13698, 1597 },
    { 40, 13440, 13691, 13697, 12854 },
    { 12214, 13667, 12497, 13751, 14001, 8960, 12384, 8795, 13836, 13696 },
    { 12214, 12497, 13751, 14001, 12693, 8960, 8792, 13836 },
    { 6652, 13334, 12854, 13696 },
    { 13440, 6652, 12699, 13654 },
    { 13334, 6652, 13846, 12854, 13696, 13692, 13698, 1587 },
    { 6652, 13335, 12854, 13693, 13698, 1587 },
    { 12214, 13667, 12497, 13751, 13771, 8960, 8793, 13836 },
    { 12214, 8960, 13695, 12497, 13751, 14001, 13836, 13696 },
    { 8902, 7756, 13668, 12699, 41, 12846 },
    { 12214, 12497, 13751, 14001, 13771, 8960, 8790, 13836 },
    { 13440, 6652, 12701, 12854 },
    { 6652, 13335, 13696, 13692, 13698, 12854 },
    { 13440, 6652, 13696, 13662, 12699, 13695, 12854 },
    { 6652, 13335, 13846, 13696, 13848, 13692, 13698, 1597 },
    { 13335, 43, 13696, 13692, 13698, 13695, 12854 },
    { 13440, 6652, 13662, 12699, 12853 },
    { 12214, 13667, 12497, 13751, 14001, 11137, 13836, 13696 },
    { 13334, 41, 12854, 13696, 1587 },
    { 13440, 41, 13696, 13662, 12699, 12854 },
    { 13440, 40, 13662, 12699, 12846 },
    { 6652, 13335, 13654 },
    { 6652, 13335, 13696, 13695, 12854 },
    { 13335, 41, 13696, 13848, 1597 },
    { 6652, 13668, 13335, 13786 },
    { 8902, 7756, 13695, 13662, 12699, 12846 },
    { 6652, 13668, 12838 },
    { 13440, 6652, 12701, 12846 },
    { 13335, 13337, 6652, 13574, 12806 },
    { 13440, 42, 12699, 12846 },
    { 6652, 13335, 12852 },
    { 8902, 7756, 12699, 42, 12843 },
    { 13440, 40, 12699, 12846 },
    { 6652, 13335, 12854, 1587 },
    { 12245, 13760, 13554, 13552, 13576, 12497, 13766, 13658, 8960, 12384, 8791 },
    { 8902, 7756, 13696, 13662, 12699, 12843 },
    { 13334, 43, 13696, 12846 },
    { 13334, 40, 12854, 13696, 1587 },
    { 42, 13668, 12846 },
    { 13335, 12854, 43, 13696, 1587 },
    { 13658, 13452, 12838 },
    { 12214, 12497, 13751, 14004, 13771, 8960, 8793, 13836 },
    { 40, 12846 },
    { 12214, 13667, 12497, 13751, 14001, 8960, 12384, 8792, 13836, 13696 },
    { 12214, 13667, 12497, 13751, 14001, 13771, 8960, 8790, 13836 },
    { 13440, 6652, 13695, 13662, 12699, 12844 },
    { 12850, 6652, 13335, 13696, 1574 },
    { 13334, 6652, 12854, 13696, 1587 },
    { 8902, 7756, 13695, 13662, 12699, 40, 12846 },
    { 13440, 6652, 13662, 12699, 12851 },
    { 13335, 40, 12854, 13696, 1587 },
    { 41, 13662, 12830 },
    { 13335, 40, 12854, 1587 },
    { 41, 13662, 12846 },
}

-- 英文名字典：非中文客户端在物品尚未缓存时用它兜底（BisPack 解码时按 GearInsight.LOCALE 选）
BisData.item_en = {
    [155922] = "Mechanist's Bindings",
    [155945] = "Shackles of the Odalisque",
    [155964] = "Wristguards of the Firetender",
    [156000] = "Wrathstone",
    [156016] = "Pyrite Infuser",
    [156168] = "Grasps of Reason",
    [158366] = "Charged Sandstone Band",
    [158368] = "Sethraliss' Defiled Relic",
    [158370] = "Twin-Strike Polearm",
    [158374] = "Tiny Electromental in a Jar",
    [159136] = "Jeweled Dagger of Subjugation",
    [159234] = "Down-Lined Breeches",
    [159243] = "Sandals of Wise Voodoo",
    [159247] = "Handwraps of Oscillating Polarity",
    [159259] = "Sandswept Sandals",
    [159263] = "Bindings of the Slithering Current",
    [159288] = "Cloak of the Restless Tribes",
    [159300] = "Kula's Butchering Wristwraps",
    [159301] = "Primal Dinomancer's Belt",
    [159304] = "Goldfeather Boots",
    [159312] = "Desiccator's Blessed Gloves",
    [159313] = "Breeches of the Sacred Hall",
    [159317] = "Whirling Dervish Sash",
    [159327] = "Sand-Shined Snakeskin Sandals",
    [159329] = "Leggings of the Galeforce Viper",
    [159337] = "Grips of Electrified Defense",
    [159369] = "Belt of the Consecrated Tomb",
    [159375] = "Legguards of the Awakening Brood",
    [159380] = "Arc-Glass Bindings",
    [159388] = "Sabatons of Coruscating Energy",
    [159409] = "Embalmer's Steadying Bracers",
    [159413] = "Gauntlets of the Avian Sentinel",
    [159418] = "Girdle of Pestilent Purification",
    [159425] = "Shard-Tipped Vambraces",
    [159435] = "Legplates of Charged Duality",
    [159459] = "Ritual Binder's Ring",
    [159617] = "Lustrous Golden Plumage",
    [160213] = "Sepulchral Construct's Gloves",
    [162544] = "Jade Ophidian Band",
    [171527] = "Band of the Traitor King",
    [171539] = "Lurid Manifestation",
    [171545] = "Signet of the Traitor King",
    [171622] = "Ring of Holy Cleansing",
    [171640] = "Variable Pulse Lightning Capacitor",
    [171644] = "Necromantic Focus",
    [171646] = "Matrix Restabilizer",
    [171654] = "Alysrazor's Band",
    [171691] = "Crystal Prison Band",
    [171699] = "Widow's Kiss",
    [171853] = "Signet of the Fifth Circle",
    [193691] = "Sky Saddle Cord",
    [193701] = "Algeth'ar Puzzle Box",
    [193750] = "Wind Soarer's Breeches",
    [193751] = "Crown of Roaring Storms",
    [193752] = "Galerattle Gauntlets",
    [193753] = "Breastplate of Soaring Terror",
    [193757] = "Ruby Whelp Shell",
    [193758] = "Subjugator's Chilling Grips",
    [193759] = "Egg Tender's Leggings",
    [193762] = "Blazebinder's Hoof",
    [193763] = "Fireproof Drape",
    [193764] = "Invader's Firestorm Chestguard",
    [193765] = "Blazebound Lieutenant's Helm",
    [193766] = "Kokia's Burnout Rod",
    [237828] = "Spellbreaker's March",
    [237829] = "Spellbreaker's Shelter",
    [237830] = "Spellbreaker's Girdle",
    [237831] = "Spellbreaker's Rebuke",
    [237832] = "Spellbreaker's Cover",
    [237833] = "Spellbreaker's Legguards",
    [237834] = "Spellbreaker's Bracers",
    [237835] = "Spellbreaker's Mantle",
    [237836] = "Spellbreaker's Resolve",
    [237837] = "Farstrider's Mercy",
    [237838] = "Magister's Ritual Knife",
    [237839] = "Spellbreaker's Blade",
    [237840] = "Spellbreaker's Warglaive",
    [237841] = "Spellbreaker's Ultimatum",
    [237843] = "Magister's Mana Sword",
    [237845] = "Bloomforged Claw",
    [237846] = "Blood Knight's Warblade",
    [237847] = "Blood Knight's Impetus",
    [237848] = "Blood Knight's Mercy",
    [237850] = "Farstrider's Chopper",
    [239031] = "Brood Cleanser's Amice",
    [239032] = "Robes of the Reborn Serpent",
    [239033] = "Hood of the Slithering Loa",
    [239035] = "Sethraliss' Fanged Helm",
    [239036] = "Desert Guardian's Breastplate",
    [239037] = "C'thraxxi Binders Pauldrons",
    [239045] = "Mantle of Ceremonial Ascension",
    [239046] = "Loa-Blessed Chestguard",
    [239048] = "Vest of Reverent Adoration",
    [239049] = "Spaulders of Prime Emperor",
    [239050] = "Helm of the Raptor King",
    [239051] = "Pauldrons of the Great Unifier",
    [239648] = "Martyr's Bindings",
    [239649] = "Martyr's Waistwrap",
    [239650] = "Martyr's Mantle",
    [239651] = "Martyr's Leggings",
    [239652] = "Martyr's Crown",
    [239653] = "Martyr's Gloves",
    [239655] = "Martyr's Vestments",
    [239656] = "Adherent's Silken Shroud",
    [239664] = "Arcanoweave Cord",
    [240949] = "Masterwork Sin'dorei Band",
    [244568] = "Thalassian Competitor's Chain Cuffs",
    [244569] = "Silvermoon Agent's Sneakers",
    [244570] = "Silvermoon Agent's Coat",
    [244572] = "Silvermoon Agent's Mantle",
    [244573] = "Silvermoon Agent's Utility Belt",
    [244574] = "Silvermoon Agent's Leggings",
    [244575] = "Silvermoon Agent's Handwraps",
    [244576] = "Silvermoon Agent's Deflectors",
    [244577] = "Farstrider's Razor Talons",
    [244579] = "Farstrider's Unwavering Visage",
    [244580] = "Farstrider's Brilliant Plumes",
    [244581] = "Farstrider's Trophy Belt",
    [244582] = "Farstrider's Reinforced Faulds",
    [244583] = "Farstrider's Sharpened Claws",
    [244584] = "Farstrider's Plated Bracers",
    [244746] = "Aetherlume Sun Guard",
    [245769] = "Aln'hara Lantern",
    [245770] = "Aln'hara Cane",
    [245771] = "Aln'hara Pikestaff",
    [246304] = "Darkmoon Dominion: Hunt",
    [246305] = "Darkmoon Dominion: Blood",
    [248583] = "Drum of Renewed Bonds",
    [249342] = "Heart of Ancient Hunger",
    [249343] = "Gaze of the Alnseer",
    [249346] = "Vaelgor's Final Stare",
    [249806] = "Radiant Plume",
    [249808] = "Litany of Lightblind Wrath",
    [249998] = "Enforcer's Grips of the Black Talon",
    [250144] = "Emberwing Feather",
    [250214] = "Lightspire Core",
    [250215] = "Freightrunner's Flask",
    [250224] = "Mindpiercer's Sigil",
    [250225] = "Void Execution Mandate",
    [250228] = "Resonant Bellowstone",
    [250229] = "Idol of the War Loa",
    [250245] = "Tumor of the Swarm",
    [250246] = "Refueling Orb",
    [250248] = "Mycolic Medicine",
    [250254] = "Seed of Radiant Hope",
    [250255] = "Unstable Felheart Crystal",
    [250259] = "Sapling of the Dawnroot",
    [251124] = "Gauntlets of Fevered Defense",
    [251125] = "Felsoaked Soles",
    [251126] = "Greathelm of Temptation",
    [251127] = "Nibbling Armbands",
    [251129] = "Counterfeit Clutches",
    [251130] = "Breeches of Deft Deals",
    [251131] = "Jangling Felpaulets",
    [251132] = "Speakeasy Shroud",
    [251133] = "Overseer's Vambraces",
    [251135] = "Fury-fletched Armlets",
    [251136] = "Signet of Snarling Servitude",
    [251137] = "Tempestuous Sandals",
    [251138] = "Cinderfury Shoulderguards",
    [251139] = "Summoner's Searing Shirt",
    [251140] = "Vilefiend's Guise",
    [251142] = "Pendant of Malefic Fury",
    [251144] = "Autumn's Boon Belt",
    [251145] = "Forgotten Tribe Footguards",
    [251146] = "Scavenger's Spaulders",
    [251147] = "Hoarded Harvest Wrap",
    [251148] = "Pilfered Precious Band",
    [251150] = "Tempest's Shelter",
    [251151] = "Sentinel Challenger's Prize",
    [251152] = "Season's Turn Gauntlets",
    [251153] = "Arctic Explorer's Legwraps",
    [251154] = "Winter's Embrace Bracers",
    [251155] = "Tribal Defender's Cord",
    [251156] = "Fallen Speaker's Staff",
    [251158] = "Nalorakk's Nightmare",
    [251159] = "War Trial Vestments",
    [251160] = "Forest Dream Leg-guards",
    [251165] = "Pulverizing Pads",
    [251173] = "Yoke of the Charging Bear",
    [251182] = "Bedrock Breeches",
    [251183] = "Rootwarden Wraps",
    [251184] = "Ironroot Collar",
    [251185] = "Lightblossom Cinch",
    [251189] = "Rootwalker Harness",
    [251190] = "Bloodthorn Burnous",
    [251191] = "Luminescent Sprout",
    [251193] = "Taproot Ribs",
    [251194] = "Lightwarden's Bind",
    [251196] = "Teldrassil's Sacrifice",
    [251198] = "Lightspore Leggings",
    [251199] = "Worldroot Canopy",
    [251200] = "Saptorbane Guards",
    [251214] = "Bonds of the Hash'ura",
    [251219] = "Riftworn Stompers",
    [251220] = "Voidscarred Crown",
    [251221] = "Despondent's Gauntlets",
    [251222] = "Ethereal Netherwrap",
    [251223] = "Somber Spaulders",
    [251224] = "Hulking Handaxe",
    [251225] = "Fang of Contagion",
    [251226] = "Hide of Pestilence",
    [251227] = "Poisoner's Pauldrons",
    [251228] = "Behemoth Waistband",
    [251229] = "Visor of the Predator",
    [251231] = "Singularity Slicer",
    [251232] = "Overseer's Diadem",
    [251233] = "Manipulator's Vest",
    [251234] = "Graft of the Domanaar",
    [251235] = "Gravitic Girdle",
    [251513] = "Loa Worshiper's Band",
    [251785] = "Void-Reaper's Libram",
    [251792] = "Glorious Crusader's Keepsake",
    [252258] = "Sickening Signet of Atroxus",
    [256980] = "Deepvine Grips",
    [260235] = "Umbral Plume",
    [264701] = "Cosmic Bell",
    [265337] = "Aln'hara Sprigshot",
    [265657] = "Fiber of Living Agony",
    [266317] = "Novice Combatant's Ring",
    [268196] = "Venom-Slashed Scuteward",
    [268197] = "Spine of the Hissing Abyss",
    [268198] = "Caustic Keeper-Crusher",
    [268199] = "Tidepiercer's Bubble Popper",
    [268200] = "Gebbo's Backup Blaster",
    [268201] = "Venomous Boneglaive",
    [268202] = "Jaw of the Shackled Goddess",
    [268203] = "Hexing Spiritrender",
    [268204] = "Ancient Construct's Venomshiv",
    [268205] = "Venomancer's Winged Channeler",
    [268206] = "Slithering Savage's Gavel",
    [268207] = "Caustic Repose Greatbow",
    [268208] = "Strongblood's Ceremonial Cleaver",
    [268209] = "Aman'muso, Warlord's Vengeance",
    [268210] = "Malevolent Spiritcudgel",
    [268211] = "Baleful Hexblade",
    [268213] = "Maze-roa, Warlord's Fury",
    [268214] = "Malignant Toothed Edge",
    [268215] = "Abyssal Broodfiend's Bardiche",
    [268216] = "Cursed Reliquary Cincture",
    [268217] = "Rising Tide Wristguards",
    [268218] = "Nek'zali's Spiritwalkers",
    [268219] = "Shadow Hunter's Warmask",
    [268220] = "Scaleplate Strangulators",
    [268221] = "Tidebound Sorcereress's Robes",
    [268222] = "Reckless Spirit Breastplate",
    [268223] = "Ophidian Fangmail",
    [268224] = "Venom Warden's Greaves",
    [268225] = "Coiled Hex Legguards",
    [268226] = "Swelling Sea Spaulders",
    [268227] = "Unpossessed Skullsash",
    [268228] = "Venom-Singed Cuffs",
    [268229] = "Skullguard of the Risen Sacrifice",
    [268230] = "Crown of the Eternal Fang",
    [268231] = "Soulslither Spaulders",
    [268232] = "Cincture of the Abyssal Grotto",
    [268233] = "Ferocious Scaleboots",
    [268234] = "Ruthless Slaughtergrips",
    [268235] = "Vestment of the Awakening",
    [268236] = "Initiate's Sacrificial Tights",
    [268237] = "Cuisses of the Uncoiled Union",
    [268238] = "Grips of Swirling Fury",
    [268239] = "Shellbound Bracers",
    [268240] = "Restless Spirit Shackles",
    [268241] = "Ornaments of the Eternal Coil",
    [268242] = "Errant Scrollsage's Hood",
    [268243] = "Grasps of the Eternal Shadow",
    [268244] = "Forgotten Grotto Girdle",
    [268245] = "Entombed Cultist's Sabatons",
    [268246] = "Frothing Venom Spaulders",
    [268247] = "Breakwater Boots",
    [268248] = "Amani Summoning Shawl",
    [268249] = "Vile Alchemist's Band",
    [268250] = "Sentinel's Vitriolic Chain",
    [268251] = "Amulet of the Twin Fangs",
    [268252] = "Apex Brute's Claw Ring",
    [268253] = "Silken Voodoo Drape",
    [268254] = "Serpentine Mixing Belt",
    [268255] = "Cackling Soultreads",
    [268256] = "Sash of the Forlorn Vessel",
    [268257] = "Caustic Chain-Wrapped Sash",
    [268258] = "Boots of the Reckless Wayfarer",
    [268259] = "Girdle of Toxic Regret",
    [268260] = "Scaled Fiend's Warboots",
    [268261] = "Bespittled Slitherslippers",
    [268262] = "Bubblefin Splash Guard",
    [268263] = "Frostscale's Mystic Frond",
    [268264] = "Ravenous Feaster's Fang",
    [268265] = "Aqirbane Reliquary",
    [268266] = "Alluring Bubbleband",
    [268290] = "Sporecaller's Blooming Loop",
    [268291] = "Rotmire's Sporeheart",
    [270160] = "First Mate's Shellward",
    [270161] = "Fang of Umbral Malignance",
    [270162] = "Soulcoiler Ritual Vessel",
    [270163] = "Sszorak's Ferocity",
    [270164] = "Gebbo's Bottomless Bag",
    [270165] = "Keeper's Seething Core",
    [270166] = "Vashnik's Sanguine Rancor",
    [270167] = "Wavecaller's Seastone",
    [270168] = "Font of Venomous Rage",
    [270169] = "Hex Lord's Dooming Idol",
    [270170] = "Vexhul's Everflowing Gland",
    [270171] = "Preternatural Antivenom",
    [270173] = "Zul'jin's Guillotine Technique",
    [270174] = "Idol of the Howling Nexus",
    [270175] = "Voracious Heart of Ula'tek",
    [270602] = "Venomous Gladiator's Badge of Ferocity",
    [270930] = "Tomb-Creeper's Claw",
    [271092] = "Jan'thrazet, the Soul Fang",
    [271093] = "Zatha'tek, Breath of Corruption",
    [271434] = "Venom Rite Mantle",
    [271435] = "Slippers of the Hissing Cult",
    [271436] = "Slitherscale Girdle",
    [271438] = "Temple Delver's Mystic Helm",
    [271440] = "Greaves of the Noxious Depths",
    [271441] = "Crushing Coiler Coif",
    [271444] = "Pauldrons of the Forgotten Sacrifice",
    [271445] = "Fanged Brute's Greatbelt",
    [271451] = "Cloak of the Jade Warlord",
    [271453] = "Greatbelt of the Jade Warlord",
    [271454] = "Raging Pauldrons of the Jade Warlord",
    [271455] = "Greaves of the Jade Warlord",
    [271456] = "Tempered Horns of the Jade Warlord",
    [271457] = "Jeweled Gauntlets of the Jade Warlord",
    [271458] = "Vicious Kickers of the Jade Warlord",
    [271459] = "Cuirass of the Jade Warlord",
    [271460] = "Cloak of the Consecrated Flame",
    [271462] = "Waistguard of the Consecrated Flame",
    [271463] = "Pauldrons of the Consecrated Flame",
    [271464] = "Greaves of the Consecrated Flame",
    [271465] = "Warhelm of the Consecrated Flame",
    [271466] = "Gauntlets of the Consecrated Flame",
    [271467] = "Greatboots of the Consecrated Flame",
    [271468] = "Bulwark of the Consecrated Flame",
    [271469] = "Baleful Grave-Knight's Greatcloak",
    [271470] = "Baleful Grave-Knight's Vambraces",
    [271471] = "Baleful Grave-Knight's Girdle",
    [271472] = "Baleful Grave-Knight's Gibbets",
    [271473] = "Baleful Grave-Knight's Greaves",
    [271474] = "Baleful Grave-Knight's Casque",
    [271475] = "Baleful Grave-Knight's Deathgrips",
    [271476] = "Baleful Grave-Knight's Sabatons",
    [271477] = "Baleful Grave-Knight's Breastplate",
    [271478] = "Ritual Drape of the Ophidian Oracle",
    [271479] = "Wristbands of the Ophidian Oracle",
    [271481] = "Hissing Mantle of the Ophidian Oracle",
    [271482] = "Leggings of the Ophidian Oracle",
    [271483] = "Serpent Crown of the Ophidian Oracle",
    [271484] = "Hexing Grips of the Ophidian Oracle",
    [271486] = "Fanged Raiment of the Ophidian Oracle",
    [271487] = "Shroud of the Skulking Viper",
    [271489] = "Prized Fangs of the Skulking Viper",
    [271490] = "Jaws of the Skulking Viper",
    [271491] = "Skulking Viper's Coiled Legwraps",
    [271492] = "Skulking Viper's Weeping Fangs",
    [271493] = "Skulking Viper's Hidepiercers",
    [271494] = "Skulking Viper's Tracks",
    [271495] = "Skulking Viper's Scuteplate",
    [271496] = "Fearsome Greatcloak of Calamity",
    [271499] = "Calamitous Echo's Sundered Peaks",
    [271500] = "Earthen Pillars of Calamity",
    [271501] = "Calamitous Echo's Magmashapers",
    [271502] = "Calamitous Echo's Ebon Greathorns",
    [271504] = "Searing Caldera of Calamity",
    [271508] = "Chosen Bloodslayer's Voodoo Guards",
    [271509] = "Chosen Bloodslayer's Reinforced Pants",
    [271510] = "Chosen Bloodslayer's Spirit Shroud",
    [271511] = "Chosen Bloodslayer's Fanged Grips",
    [271513] = "Chosen Bloodslayer's Banded Poncho",
    [271514] = "Cape of the Monkey King",
    [271516] = "Agile Cord of the Monkey King",
    [271517] = "Tassels of the Monkey King",
    [271518] = "Pantaloons of the Monkey King",
    [271519] = "Monkey King's Unyielding Visage",
    [271520] = "Monkey King's Fighting Fists",
    [271522] = "Battle Gi of the Monkey King",
    [271523] = "Enigmatic Dreamwatcher's Cloak",
    [271525] = "Enigmatic Dreamwatcher's Sigiled Cincture",
    [271526] = "Enigmatic Dreamwatcher's Plumage",
    [271527] = "Enigmatic Dreamwatcher's Leggings",
    [271528] = "Enigmatic Dreamwatcher's Somnolent Stare",
    [271529] = "Enigmatic Dreamwatcher's Gauntlets",
    [271531] = "Enigmatic Dreamwatcher's Lunar Raiment",
    [271532] = "Abyssal Doomhound's Ornate Drape",
    [271533] = "Abyssal Doomhound's Wristguards",
    [271534] = "Abyssal Doomhound's Jeweled Cinch",
    [271535] = "Abyssal Doomhound's Jaws",
    [271536] = "Abyssal Doomhound's Legwraps",
    [271537] = "Abyssal Doomhound's Relentless Stare",
    [271538] = "Abyssal Doomhound's Studded Gauntlets",
    [271540] = "Abyssal Doomhound's Coreguard",
    [271541] = "Chaincloak of the Damned Necrolyte",
    [271542] = "Damned Necrolyte's Shackles",
    [271543] = "Damned Necrolyte's Clanging Cinch",
    [271544] = "Spires of the Damned Necrolyte",
    [271545] = "Damned Necrolyte's Leg Bindings",
    [271546] = "Skull of the Damned Necrolyte",
    [271547] = "Damned Necrolyte's Charred Grasps",
    [271548] = "Soles of the Damned Necrolyte",
    [271549] = "Damned Necrolyte's Rattling Robes",
    [271553] = "Cosmic Penitent's Echoing Screams",
    [271554] = "Enveloping Legwraps of the Cosmic Penitent",
    [271555] = "Cosmic Penitent's Truesight",
    [271556] = "Cosmic Penitent's Celestial Grips",
    [271558] = "Cosmic Penitent's Eclipsing Robes",
    [271559] = "Spellcloak of the Primal Leywarden",
    [271560] = "Cuffs of the Primal Leywarden",
    [271561] = "Primal Leywarden's Bejeweled Buckle",
    [271562] = "Primal Leywarden's Manaflux",
    [271563] = "Primal Leywarden's Tailored Legwraps",
    [271564] = "Crown of the Primal Leywarden",
    [271565] = "Primal Leywarden's Manashapers",
    [271566] = "Battleboots of the Primal Leywarden",
    [271567] = "Crest of the Primal Leywarden",
    [271638] = "Bound Serpent's Jade Eye",
    [271681] = "Perennial Frostbound Charm",
    [271874] = "Venomkeeper's Horrific Cowl",
    [271875] = "Gaze of the Coiled Watcher",
    [271876] = "Awoken Dreadfang Cuirass",
    [271878] = "Chausses of Unbound Rancor",
    [272147] = "Colubrine Band",
    [272148] = "Anguine Gyre",
    [272149] = "Hex Loop",
    [272150] = "Ouroboric Signet",
    [272226] = "Miststalker's Shroud",
    [272229] = "Serpentine Talisman",
    [272235] = "Pyrewalker's Treads",
    [272239] = "Miststalker's Brigandine",
    [272243] = "Miststalker's Cuisses",
    [272244] = "Miststalker's Spaulders",
    [272247] = "Galerider's Byrnie",
    [272249] = "Galerider's Chain Clasps",
    [272250] = "Galerider's Gaze",
    [272252] = "Galerider's Mantle",
    [272254] = "Galerider's Mesh Wraps",
    [272256] = "Pledgebearer's Sabatons",
    [272257] = "Pledgebearer's Gauntlets",
    [272259] = "Pledgebearer's Poleyns",
    [273649] = "Stormbound Emblem of Dazar",
    [273773] = "Handwraps of Blasphemous Rites",
    [273774] = "Snakeskin Spaulders",
    [273775] = "Hydra Scale Wristguards",
    [273776] = "Ancient General's Obsidian Pillars",
    [273777] = "Poison-Proof Stompers",
    [273778] = "Polished Lightwood Channeler",
    [273779] = "Nocuous Focal Fang",
    [273781] = "Strand of Warding Fangs",
    [273782] = "Vile Writhefang Glaive",
    [273785] = "Primordial Robe of Rites",
    [273786] = "Leggings of Entwined Serpents",
    [273789] = "Chestguard of Corroded Scales",
    [273791] = "Spare Speaker's Hood",
    [273792] = "Band of the Amani Warlord",
    [273794] = "Knot of Writhing Serpents",
    [273796] = "Vile Vial of Volatile Venom",
    [273797] = "Tattered Amani War Banner",
    [274493] = "Effigy of Ula'tek's Faithful",
    [274495] = "Pulse Seeker's Oculus",
    [275070] = "Sharpened Lightwood Slasher",
    [275526] = "Preyhunter's Band",
    [275527] = "Preyhunter's Signet",
    [275529] = "Preyhunter's Circle",
    [279009] = "Gore Rattler Coil",
    [279010] = "Ula'tek's Bind",
}

BisData.items = {
    [155922] = "381,24,5",
    [155945] = "415,24,5",
    [155964] = "446,24,5",
    [156000] = "408,24,5",
    [156016] = "231,19,3,0,1320",
    [156168] = "458,24,5",
    [158366] = "32,16,4,14,1030",
    [158368] = "268,23,3,20,1320,2888,0,0,0,1",
    [158370] = "384,24,5,0,0,0,0,1",
    [158374] = "139,16,4,14,1030,0,0,0,2",
    [159136] = "409,24,5,0,0,0,0,2",
    [159234] = "273,14,4,12,1041",
    [159243] = "262,14,4,12,1041",
    [159247] = "275,16,4,14,1030",
    [159259] = "274,16,4,14,1030",
    [159263] = "412,16,4,14,1030",
    [159288] = "269,14,4,12,1041",
    [159300] = "285,14,4,12,1041",
    [159301] = "131,14,4,12,1041",
    [159304] = "284,14,4,12,1041",
    [159312] = "122,14,4,12,1041",
    [159313] = "288,14,4,12,1041",
    [159317] = "155,16,4,14,1030",
    [159327] = "99,16,4,14,1030",
    [159329] = "165,16,4,14,1030",
    [159337] = "171,16,4,14,1030",
    [159369] = "397,14,4,12,1041",
    [159375] = "223,16,4,14,1030",
    [159380] = "196,16,4,14,1030",
    [159388] = "193,16,4,14,1030",
    [159409] = "371,14,4,12,1041",
    [159413] = "68,14,4,12,1041",
    [159418] = "66,14,4,12,1041",
    [159425] = "367,16,4,14,1030",
    [159435] = "428,16,4,14,1030",
    [159459] = "29,14,4,12,1041",
    [159617] = "136,14,4,12,1041,0,0,0,1",
    [160213] = "393,14,4,12,1041",
    [162544] = "39,16,4,14,1030",
    [171527] = "265,19,3,0,1320",
    [171539] = "225,19,3,0,1320",
    [171545] = "377,24,5",
    [171622] = "385,24,5",
    [171640] = "401,24,5",
    [171644] = "394,24,5",
    [171646] = "333,19,3,0,1320",
    [171654] = "230,19,3,0,1320",
    [171691] = "327,19,3,0,1320",
    [171699] = "156,19,3,0,1320",
    [171853] = "172,19,3,0,1320",
    [193691] = "261,21,4,18,1202",
    [193701] = "310,24,5,0,0,0,0,0,1",
    [193750] = "451,21,4,18,1202",
    [193751] = "154,21,4,18,1202",
    [193752] = "217,21,4,18,1202",
    [193753] = "363,21,4,18,1202",
    [193757] = "157,21,4,18,1202,0,0,0,2",
    [193758] = "134,21,4,18,1202",
    [193759] = "390,21,4,18,1202",
    [193762] = "308,21,4,18,1202",
    [193763] = "57,21,4,18,1202",
    [193764] = "383,21,4,18,1202",
    [193765] = "389,21,4,18,1202",
    [193766] = "402,21,4,18,1202,0,0,3",
    [237828] = "20,2,2",
    [237829] = "11,2,2",
    [237830] = "296,2,2",
    [237831] = "301,2,2,0,0,0,0,5",
    [237832] = "2,2,2",
    [237833] = "305,2,2",
    [237834] = "22,2,2",
    [237835] = "304,2,2",
    [237836] = "26,2,2",
    [237837] = "328,2,2,0,0,0,0,2",
    [237838] = "318,2,2,0,0,0,0,2",
    [237839] = "78,2,2,0,0,0,0,2",
    [237840] = "114,2,2,0,0,0,0,2",
    [237841] = "439,2,2,0,0,0,0,2",
    [237843] = "300,2,2,0,0,0,0,2",
    [237845] = "345,19,3,0,1320,0,0,2",
    [237846] = "59,2,2,0,0,0,0,1",
    [237847] = "232,2,2,0,0,0,0,1",
    [237848] = "434,2,2,0,0,0,0,1",
    [237850] = "344,2,2,0,0,0,0,2",
    [239031] = "351,16,4,14,1030",
    [239032] = "450,16,4,14,1030",
    [239033] = "161,16,4,14,1030",
    [239035] = "228,16,4,14,1030",
    [239036] = "80,16,4,14,1030",
    [239037] = "429,16,4,14,1030",
    [239045] = "271,14,4,12,1041",
    [239046] = "346,14,4,12,1041",
    [239048] = "118,14,4,12,1041",
    [239049] = "213,14,4,12,1041",
    [239050] = "365,14,4,12,1041",
    [239051] = "431,14,4,12,1041",
    [239648] = "251,2,2",
    [239649] = "260,2,2",
    [239650] = "238,2,2",
    [239651] = "246,2,2",
    [239652] = "437,2,2",
    [239653] = "256,2,2",
    [239655] = "240,2,2",
    [239656] = "56,2,2",
    [239664] = "321,2,2",
    [240949] = "41,2,2",
    [244568] = "404,24,5",
    [244569] = "98,2,2",
    [244570] = "90,2,2",
    [244572] = "88,2,2",
    [244573] = "287,2,2",
    [244574] = "97,2,2",
    [244575] = "147,2,2",
    [244576] = "101,2,2",
    [244577] = "341,2,2",
    [244579] = "205,2,2",
    [244580] = "181,2,2",
    [244581] = "186,2,2",
    [244582] = "189,2,2",
    [244583] = "198,2,2",
    [244584] = "194,2,2",
    [244746] = "368,24,5",
    [245769] = "151,2,2,0,0,0,0,3",
    [245770] = "290,2,2,0,0,0,0,1",
    [245771] = "160,2,2,0,0,0,0,1",
    [246304] = "209,19,3,0,1320",
    [246305] = "452,24,5",
    [248583] = "71,19,3,0,1320,0,0,0,1",
    [249342] = "462,31,3,26,1307,2734,0,0,0,2",
    [249343] = "374,26,3,21,1314,2795,0,0,2,7",
    [249346] = "375,27,3,22,1307,2735,0,0,1,4",
    [249806] = "407,29,3,24,1308,2739,0,0,0,8",
    [249808] = "423,30,3,25,1307,2737,0,0,0,5",
    [249998] = "391,1,1,0,0,0,1",
    [250144] = "416,25,6,0,0,0,0,0,1",
    [250214] = "109,20,4,17,1309,0,0,0,2",
    [250215] = "107,12,4,10,1304,0,0,0,1",
    [250224] = "111,15,4,13,1313,0,0,0,2",
    [250225] = "140,15,4,13,1313,0,0,0,1",
    [250228] = "49,12,4,10,1304,0,0,0,2",
    [250229] = "81,18,4,16,1311",
    [250245] = "52,15,4,13,1313,0,0,0,2",
    [250246] = "448,25,6",
    [250248] = "289,18,4,16,1311",
    [250254] = "387,20,4,17,1309,0,0,0,1",
    [250255] = "386,12,4,10,1304,0,0,0,1",
    [250259] = "138,20,4,17,1309,0,0,0,2",
    [251124] = "106,12,4,10,1304",
    [251125] = "347,12,4,10,1304",
    [251126] = "61,12,4,10,1304",
    [251127] = "252,12,4,10,1304",
    [251129] = "264,12,4,10,1304",
    [251130] = "96,12,4,10,1304",
    [251131] = "221,12,4,10,1304",
    [251132] = "73,12,4,10,1304",
    [251133] = "24,12,4,10,1304",
    [251135] = "103,12,4,10,1304",
    [251136] = "33,12,4,10,1304",
    [251137] = "263,12,4,10,1304",
    [251138] = "64,12,4,10,1304",
    [251139] = "241,12,4,10,1304",
    [251140] = "85,12,4,10,1304",
    [251142] = "63,12,4,10,1304",
    [251144] = "461,18,4,16,1311",
    [251145] = "398,18,4,16,1311",
    [251146] = "163,18,4,16,1311",
    [251147] = "456,18,4,16,1311",
    [251148] = "36,18,4,16,1311",
    [251150] = "465,18,4,16,1311,0,0,5",
    [251151] = "373,18,4,16,1311",
    [251152] = "399,18,4,16,1311",
    [251153] = "100,18,4,16,1311",
    [251154] = "320,18,4,16,1311",
    [251155] = "187,18,4,16,1311",
    [251156] = "424,18,4,16,1311,0,0,1",
    [251158] = "396,18,4,16,1311",
    [251159] = "169,18,4,16,1311",
    [251160] = "410,18,4,16,1311",
    [251165] = "405,20,4,17,1309",
    [251173] = "128,18,4,16,1311",
    [251182] = "430,20,4,17,1309",
    [251183] = "121,20,4,17,1309",
    [251184] = "343,20,4,17,1309",
    [251185] = "418,20,4,17,1309",
    [251189] = "281,20,4,17,1309",
    [251190] = "112,20,4,17,1309",
    [251191] = "175,20,4,17,1309,0,0,3",
    [251193] = "366,20,4,17,1309",
    [251194] = "40,20,4,17,1309",
    [251196] = "449,20,4,17,1309,0,0,5",
    [251198] = "283,20,4,17,1309",
    [251199] = "438,20,4,17,1309",
    [251200] = "348,20,4,17,1309",
    [251214] = "364,18,4,16,1311",
    [251219] = "316,15,4,13,1313",
    [251220] = "211,15,4,13,1313",
    [251221] = "307,15,4,13,1313",
    [251222] = "244,15,4,13,1313",
    [251223] = "129,15,4,13,1313",
    [251224] = "445,15,4,13,1313,0,0,2",
    [251225] = "388,15,4,13,1313,0,0,2",
    [251226] = "130,15,4,13,1313",
    [251227] = "455,15,4,13,1313",
    [251228] = "339,15,4,13,1313",
    [251229] = "79,15,4,13,1313",
    [251231] = "126,15,4,13,1313,0,0,2",
    [251232] = "258,15,4,13,1313",
    [251233] = "229,15,4,13,1313",
    [251234] = "62,15,4,13,1313",
    [251235] = "332,15,4,13,1313",
    [251513] = "35,2,2",
    [251785] = "167,19,3,0,1320",
    [251792] = "72,22,3,19,1320,2882,0,0,2,4",
    [252258] = "30,15,4,13,1313",
    [256980] = "459,25,6",
    [260235] = "406,29,3,24,1308,2739,0,0,0,8",
    [264701] = "436,25,6",
    [265337] = "219,2,2,0,0,0,0,4",
    [265657] = "70,19,3,0,1320,0,0,0,2",
    [266317] = "266,2,2",
    [268196] = "303,11,3,9,1320,2894,0,5,0,3",
    [268197] = "152,5,3,3,1320,2874,0,3,0,2",
    [268198] = "82,5,3,3,1320,2874,0,1,0,2",
    [268199] = "159,8,3,6,1317,2849,0,1,0,9",
    [268200] = "220,11,3,9,1320,2894,0,4,0,3",
    [268201] = "125,17,3,15,1320,2871,0,2,0,5",
    [268202] = "77,4,3,2,1320,2895,0,2,0,8",
    [268203] = "115,3,3,1,1320,2888,0,2,0,1",
    [268204] = "330,5,3,3,1320,2874,0,2,0,2",
    [268205] = "291,10,3,8,1320,2882,0,1,0,4",
    [268206] = "444,17,3,15,1320,2871,0,2,0,5",
    [268207] = "218,4,3,2,1320,2895,0,4,0,8",
    [268208] = "76,3,3,1,1320,2888,0,2,0,1",
    [268209] = "75,9,3,7,1320,2883,0,2,0,7",
    [268210] = "150,11,3,9,1320,2894,0,2,0,3",
    [268211] = "257,9,3,7,1320,2883,0,2,0,7",
    [268213] = "58,9,3,7,1320,2883,0,1,0,7",
    [268214] = "60,10,3,8,1320,2882,0,1,0,4",
    [268215] = "158,4,3,2,1320,2895,0,1,0,8",
    [268216] = "203,3,3,1,1320,2888,0,0,0,1",
    [268217] = "195,8,3,6,1317,2849,0,0,0,9",
    [268218] = "249,3,3,1,1320,2888,0,0,0,1",
    [268219] = "278,5,3,3,1320,2874,0,0,0,2",
    [268220] = "27,13,3,11,1320,2887,0,0,0,6",
    [268221] = "272,8,3,6,1317,2849,0,0,0,9",
    [268222] = "12,9,3,7,1320,2883,0,0,0,7",
    [268223] = "184,13,3,11,1320,2887,0,0,0,6",
    [268224] = "18,5,3,3,1320,2874,0,0,0,2",
    [268225] = "132,9,3,7,1320,2883,0,0,0,7",
    [268226] = "9,8,3,6,1317,2849,0,0,0,9",
    [268227] = "92,11,3,9,1320,2894,0,0,0,3",
    [268228] = "253,5,3,3,1320,2874,0,0,0,2",
    [268229] = "3,3,3,1,1320,2888,0,0,0,1",
    [268230] = "177,3,3,1,1320,2888,0,0,0,1",
    [268231] = "180,9,3,7,1320,2883,0,0,0,7",
    [268232] = "242,8,3,6,1317,2849,0,0,0,9",
    [268233] = "191,17,3,15,1320,2871,0,0,0,5",
    [268234] = "105,17,3,15,1320,2871,0,0,0,5",
    [268235] = "91,3,3,1,1320,2888,0,0,0,1",
    [268236] = "247,3,3,1,1320,2888,0,0,0,1",
    [268237] = "190,9,3,7,1320,2883,0,0,0,7",
    [268238] = "199,8,3,6,1317,2849,0,0,0,9",
    [268239] = "23,11,3,9,1320,2894,0,0,0,3",
    [268240] = "102,3,3,1,1320,2888,0,0,0,1",
    [268241] = "237,13,3,11,1320,2887,0,0,0,6",
    [268242] = "235,11,3,9,1320,2894,0,0,0,3",
    [268243] = "255,9,3,7,1320,2883,0,0,0,7",
    [268244] = "14,8,3,6,1317,2849,0,0,0,9",
    [268245] = "19,3,3,1,1320,2888,0,0,0,1",
    [268246] = "87,10,3,8,1320,2882,0,0,0,4",
    [268247] = "133,8,3,6,1317,2849,0,0,0,9",
    [268248] = "226,3,3,1,1320,2888,0,0,0,1",
    [268249] = "38,10,3,8,1320,2882,0,0,0,4",
    [268250] = "5,5,3,3,1320,2874,0,0,0,2",
    [268251] = "168,13,3,11,1320,2887,0,0,0,6",
    [268252] = "34,17,3,15,1320,2871,0,0,0,5",
    [268253] = "55,9,3,7,1320,2883,0,0,0,7",
    [268254] = "185,10,3,8,1320,2882,0,0,0,4",
    [268255] = "250,9,3,7,1320,2883,0,0,0,7",
    [268256] = "93,9,3,7,1320,2883,0,0,0,7",
    [268257] = "243,17,3,15,1320,2871,0,0,0,5",
    [268258] = "192,11,3,9,1320,2894,0,0,0,3",
    [268259] = "13,9,3,7,1320,2883,0,0,0,7",
    [268260] = "21,10,3,8,1320,2882,0,0,0,4",
    [268261] = "120,13,3,11,1320,2887,0,0,0,6",
    [268262] = "302,8,3,6,1317,2849,0,5,0,9",
    [268263] = "153,8,3,6,1317,2849,0,3,0,9",
    [268264] = "440,13,3,11,1320,2887,0,2,0,6",
    [268265] = "4,4,3,2,1320,2895,0,0,0,8",
    [268266] = "31,8,3,6,1317,2849,0,0,0,9",
    [268290] = "435,28,3,23,1305,2711,0,0,0,10",
    [268291] = "380,28,3,23,1305,2711,0,0,0,10",
    [270160] = "135,11,3,9,1320,2894,0,0,1,3",
    [270161] = "149,10,3,8,1320,2882,0,0,2,4",
    [270162] = "173,3,3,1,1320,2888,0,0,1,1",
    [270163] = "47,17,3,15,1320,2871,0,0,0,5",
    [270164] = "53,11,3,9,1320,2894,0,0,2,3",
    [270165] = "46,5,3,3,1320,2874,0,0,2,2",
    [270166] = "123,10,3,8,1320,2882,0,0,2,4",
    [270167] = "110,8,3,6,1317,2849,0,0,2,9",
    [270168] = "48,4,3,2,1320,2895,0,0,1,8",
    [270169] = "148,9,3,7,1320,2883,0,0,2,7",
    [270170] = "200,13,3,11,1320,2887,0,0,0,6",
    [270171] = "207,13,3,11,1320,2887,0,0,0,6",
    [270173] = "51,9,3,7,1320,2883,0,0,2,7",
    [270174] = "137,17,3,15,1320,2871,0,0,2,5",
    [270175] = "45,4,3,2,1320,2895,0,0,1,8",
    [270602] = "433,25,6",
    [270930] = "141,3,3,1,1320,2888,0,2,0,1",
    [271092] = "113,4,3,2,1320,2895,0,2,0,8",
    [271093] = "329,4,3,2,1320,2895,0,2,0,8",
    [271434] = "319,7,3,5,1320",
    [271435] = "248,7,3,5,1320",
    [271436] = "119,7,3,5,1320",
    [271438] = "116,7,3,5,1320",
    [271440] = "224,7,3,5,1320",
    [271441] = "178,7,3,5,1320",
    [271444] = "8,7,3,5,1320",
    [271445] = "15,7,3,5,1320",
    [271451] = "362,1,1,0,0,0,1",
    [271453] = "359,1,1,0,0,0,1",
    [271454] = "357,1,1,0,0,0,1",
    [271455] = "360,1,1,0,0,0,1",
    [271456] = "356,1,1,0,0,0,1",
    [271457] = "361,1,1,0,0,0,1",
    [271458] = "460,1,1,0,0,0,1",
    [271459] = "358,1,1,0,0,0,1",
    [271460] = "309,1,1,0,0,0,1",
    [271462] = "427,1,1,0,0,0,1",
    [271463] = "294,1,1,0,0,0,1",
    [271464] = "297,1,1,0,0,0,1",
    [271465] = "293,1,1,0,0,0,1",
    [271466] = "299,1,1,0,0,0,1",
    [271467] = "432,1,1,0,0,0,1",
    [271468] = "295,1,1,0,0,0,1",
    [271469] = "74,1,1,0,0,0,1",
    [271470] = "67,7,3,5,1320",
    [271471] = "65,1,1,0,0,0,1",
    [271472] = "7,1,1,0,0,0,1",
    [271473] = "16,1,1,0,0,0,1",
    [271474] = "1,1,1,0,0,0,1",
    [271475] = "25,1,1,0,0,0,1",
    [271476] = "370,1,1,0,0,0,1",
    [271477] = "10,1,1,0,0,0,1",
    [271478] = "443,1,1,0,0,0,1",
    [271479] = "442,1,1,0,0,0,1",
    [271481] = "335,1,1,0,0,0,1",
    [271482] = "340,1,1,0,0,0,1",
    [271483] = "334,1,1,0,0,0,1",
    [271484] = "342,1,1,0,0,0,1",
    [271486] = "337,1,1,0,0,0,1",
    [271487] = "227,1,1,0,0,0,1",
    [271489] = "222,1,1,0,0,0,1",
    [271490] = "212,1,1,0,0,0,1",
    [271491] = "215,1,1,0,0,0,1",
    [271492] = "210,1,1,0,0,0,1",
    [271493] = "216,1,1,0,0,0,1",
    [271494] = "403,1,1,0,0,0,1",
    [271495] = "214,1,1,0,0,0,1",
    [271496] = "395,7,3,5,1320",
    [271499] = "179,1,1,0,0,0,1",
    [271500] = "188,7,3,5,1320",
    [271501] = "176,1,1,0,0,0,1",
    [271502] = "197,1,1,0,0,0,1",
    [271504] = "182,7,3,5,1320",
    [271508] = "323,1,1,0,0,0,1",
    [271509] = "325,1,1,0,0,0,1",
    [271510] = "322,1,1,0,0,0,1",
    [271511] = "326,1,1,0,0,0,1",
    [271513] = "324,1,1,0,0,0,1",
    [271514] = "426,1,1,0,0,0,1",
    [271516] = "292,1,1,0,0,0,1",
    [271517] = "279,1,1,0,0,0,1",
    [271518] = "282,1,1,0,0,0,1",
    [271519] = "277,1,1,0,0,0,1",
    [271520] = "286,1,1,0,0,0,1",
    [271522] = "280,1,1,0,0,0,1",
    [271523] = "174,7,3,5,1320",
    [271525] = "378,1,1,0,0,0,1",
    [271526] = "143,1,1,0,0,0,1",
    [271527] = "145,1,1,0,0,0,1",
    [271528] = "142,1,1,0,0,0,1",
    [271529] = "146,1,1,0,0,0,1",
    [271531] = "144,1,1,0,0,0,1",
    [271532] = "124,1,1,0,0,0,1",
    [271533] = "376,1,1,0,0,0,1",
    [271534] = "94,1,1,0,0,0,1",
    [271535] = "86,1,1,0,0,0,1",
    [271536] = "95,1,1,0,0,0,1",
    [271537] = "83,1,1,0,0,0,1",
    [271538] = "104,1,1,0,0,0,1",
    [271540] = "89,1,1,0,0,0,1",
    [271541] = "454,1,1,0,0,0,1",
    [271542] = "453,1,1,0,0,0,1",
    [271543] = "457,1,1,0,0,0,1",
    [271544] = "350,1,1,0,0,0,1",
    [271545] = "353,1,1,0,0,0,1",
    [271546] = "349,1,1,0,0,0,1",
    [271547] = "354,1,1,0,0,0,1",
    [271548] = "355,1,1,0,0,0,1",
    [271549] = "352,1,1,0,0,0,1",
    [271553] = "312,1,1,0,0,0,1",
    [271554] = "314,1,1,0,0,0,1",
    [271555] = "311,1,1,0,0,0,1",
    [271556] = "317,1,1,0,0,0,1",
    [271558] = "313,1,1,0,0,0,1",
    [271559] = "413,1,1,0,0,0,1",
    [271560] = "419,1,1,0,0,0,1",
    [271561] = "417,1,1,0,0,0,1",
    [271562] = "236,1,1,0,0,0,1",
    [271563] = "245,1,1,0,0,0,1",
    [271564] = "233,1,1,0,0,0,1",
    [271565] = "254,1,1,0,0,0,1",
    [271566] = "411,1,1,0,0,0,1",
    [271567] = "239,1,1,0,0,0,1",
    [271638] = "117,7,3,5,1320",
    [271681] = "392,18,4,16,1311,0,0,3",
    [271874] = "234,4,3,2,1320,2895,0,0,0,8",
    [271875] = "84,4,3,2,1320,2895,0,0,0,8",
    [271876] = "183,4,3,2,1320,2895,0,0,0,8",
    [271878] = "17,4,3,2,1320,2895,0,0,0,8",
    [272147] = "37,19,3,0,1320",
    [272148] = "43,19,3,0,1320",
    [272149] = "44,19,3,0,1320",
    [272150] = "42,19,3,0,1320",
    [272226] = "422,25,6",
    [272229] = "421,25,6",
    [272235] = "414,25,6",
    [272239] = "164,19,3,0,1320",
    [272243] = "170,19,3,0,1320",
    [272244] = "425,25,6",
    [272247] = "202,19,3,0,1320",
    [272249] = "206,19,3,0,1320",
    [272250] = "201,19,3,0,1320",
    [272252] = "336,19,3,0,1320",
    [272254] = "204,19,3,0,1320",
    [272256] = "464,25,6",
    [272257] = "372,25,6",
    [272259] = "298,19,3,0,1320",
    [273649] = "267,14,4,12,1041",
    [273773] = "276,6,4,4,1322",
    [273774] = "162,6,4,4,1322",
    [273775] = "441,6,4,4,1322",
    [273776] = "369,6,4,4,1322",
    [273777] = "306,6,4,4,1322",
    [273778] = "270,6,4,4,1322,0,0,2",
    [273779] = "420,6,4,4,1322,0,0,3",
    [273781] = "6,6,4,4,1322",
    [273782] = "463,6,4,4,1322,0,0,1",
    [273785] = "259,6,4,4,1322",
    [273786] = "315,6,4,4,1322",
    [273789] = "338,6,4,4,1322",
    [273791] = "127,6,4,4,1322",
    [273792] = "28,6,4,4,1322",
    [273794] = "379,6,4,4,1322",
    [273796] = "108,6,4,4,1322,0,0,0,1",
    [273797] = "50,6,4,4,1322,0,0,0,1",
    [274493] = "54,19,3,0,1320,0,0,0,2",
    [274495] = "208,19,3,0,1320",
    [275070] = "331,6,4,4,1322,0,0,2",
    [275526] = "69,19,3,0,1320",
    [275527] = "166,19,3,0,1320",
    [275529] = "400,25,6",
    [279009] = "447,25,6",
    [279010] = "382,25,6",
}

BisData._pm = {
    ["DEATHKNIGHT/BLOOD/San'layn"] = "1:271474,77.6,1,0,334,1;237832,11.5,2,0,331,2;268229,7.1,3,0,334,3|2:268265,86.5,4,0,344,4;271638,7.7,71,0,334,92;268250,4.5,5,0,334,5|3:271472,95.5,7,0,334,7;271444,4.5,8,0,334,8|5:271477,98.7,10,0,344,10;193753,0.6,45,0,321,128;251193,0.6,45,0,321,270|6:271445,55.1,14,0,334,15;271471,20.5,43,0,344,54;159418,10.3,41,0,334,53|7:271473,87.2,15,0,344,10;271878,12.8,16,0,344,16|8:237828,32.1,19,0,331,19;268245,28.8,18,0,334,18;268260,16,18,0,334,20|9:237834,71.8,2,0,331,21;268239,18.6,20,0,334,22;159425,7.7,84,0,321,271|10:271475,77.6,22,0,334,24;237836,18.6,19,0,331,19;251214,1.9,150,0,331,268|11:268266,20.5,5,0,334,29;273792,18.6,23,0,334,26;159459,17.3,24,0,334,27;268249,9.6,5,0,334,36;252258,7.1,25,0,334,28;268252,7.1,5,0,334,32;251148,6.4,23,0,334,34;162544,5.1,28,0,334,37|12:268266,25.6,5,0,334,29;159459,19.2,24,0,334,27;273792,16.7,23,0,334,26;251148,7.1,23,0,334,34;268252,6.4,5,0,334,32;158366,5.8,23,0,334,30;252258,5.8,25,0,334,28;240949,5.1,29,0,331,39|13:270175,67.3,30,0,344,43;270165,22.4,31,0,334;270173,7.1,30,0,344;250228,1.3,33,0,334;250245,0.6,35,0,334;251792,0.6,37,0,321,0,25,6,0,0,0;270174,0.6,77,0,334,108|14:270165,34.6,31,0,334;270175,32.7,30,0,344,43;270164,13.5,36,0,334;270173,9,30,0,344;270174,3.8,77,0,334,108;250228,2.6,33,0,334;250245,1.9,35,0,334;251792,0.6,37,0,321,0,25,6,0,0,0|15:239656,25.6,38,0,331,46;271469,22.4,48,0,344,59;268248,17.3,18,0,334,170|16:237846,52.6,40,0,331,2;268213,23.1,30,0,344,48;268198,14.7,36,0,334,67",
    ["DEATHKNIGHT/FROST/Deathbringer"] = "1:271474,92.3,1,0,334,1;268229,3.9,3,0,334,3;244746,3.2,151,0,331,272|2:268265,73.5,4,0,344,4;251234,13.5,23,0,334,51;251142,11,42,0,334,52|3:271472,75.5,7,0,334,7;271444,15.5,8,0,334,8;251138,5.2,39,0,334,53|5:271477,94.8,10,0,344,10;268222,1.3,12,0,344,12;193753,1.3,45,0,321,128|6:271445,33.5,14,0,334,15;268259,23.2,13,0,344,13;159418,14.8,41,0,334,53|7:271473,71.6,15,0,344,10;271878,25.8,16,0,344,16;273776,1.9,125,0,334,273|8:237828,62.6,19,0,331,19;268260,18.7,18,0,334,20;271476,8.4,152,0,334,274|9:237834,52.3,2,0,331,21;268239,30.3,20,0,334,22;159409,9,153,0,334,275|10:271475,96.1,22,0,334,24;237836,1.9,19,0,331,19;272257,1.3,89,0,321,276|11:158366,41.9,23,0,334,30;251136,22.6,23,0,334,31;251513,17.4,26,0,331,33;268249,10.3,5,0,334,36;268252,3.9,5,0,334,32;240949,1.9,29,0,331,39;252258,1.3,25,0,334,28;251194,0.6,23,0,334,38|12:251136,41.3,23,0,334,31;158366,21.9,23,0,334,30;251513,19.4,26,0,331,33;268249,12.3,5,0,334,36;252258,3.9,25,0,334,28;268252,1.3,5,0,334,32|13:270175,65.8,30,0,344,43;270165,15.5,31,0,334;270173,7.7,30,0,344;270163,4.5,32,0,334;250228,3.9,33,0,334;248583,2.6,47,0,321,0,24,5,0,0,0|14:270165,34.8,31,0,334;270175,34.2,30,0,344,43;270173,20,30,0,344;250228,4.5,33,0,334;270164,1.9,36,0,334;248583,1.9,47,0,321,0,24,5,0,0,0;246304,1.3,105,0,341,0,24,5,0,0,0;270163,0.6,32,0,334|15:251132,50.3,39,0,334,58;193763,12.9,39,0,334,47;271469,12.9,48,0,344,59|16:268202,36.1,50,0,344,62;268209,27.1,49,0,344,60;268208,17.4,32,0,334,61|17:268202,53,50,0,344,62;237839,20.5,51,0,331,63;268208,13.9,32,0,334,61",
    ["DEATHKNIGHT/UNHOLY/San'layn"] = "1:271474,92.1,1,0,334,1;268229,3.3,3,0,334,3;244746,2.6,151,0,331,272|2:268265,74.8,4,0,344,4;251234,14.6,23,0,334,51;251142,6.6,42,0,334,52|3:271472,78.1,7,0,334,7;271444,12.6,8,0,334,8;251138,4,39,0,334,53|5:271477,92.7,10,0,344,10;268222,4,12,0,344,12;251151,3.3,154,0,321,277|6:268259,34.4,13,0,344,13;159418,19.9,41,0,334,53;271471,19.2,43,0,344,54|7:271473,70.9,15,0,344,10;271878,26.5,16,0,344,16;268224,1.3,17,0,334,17|8:237828,74.2,19,0,331,19;268245,9.3,18,0,334,18;273777,4.6,39,0,334,230|9:237834,73.5,2,0,331,21;268239,15.2,20,0,334,22;159409,3.3,153,0,334,275|10:271475,84.8,22,0,334,24;237836,9.3,19,0,331,19;159413,4,45,0,321,56|11:252258,21.2,25,0,334,28;251136,20.5,23,0,334,31;273792,15.2,23,0,334,26;251513,12.6,26,0,331,33;158366,12.6,23,0,334,30;240949,6.6,29,0,331,39;268249,6.6,5,0,334,36;251194,1.3,23,0,334,38|12:252258,21.9,25,0,334,28;251136,19.2,23,0,334,31;158366,18.5,23,0,334,30;268249,11.9,5,0,334,36;273792,9.9,23,0,334,26;251513,6.6,26,0,331,33;272149,5.3,27,0,321,42,25,6,0,0,0;272150,4.6,27,0,321,40,25,6,0,0,0|13:270175,55.6,30,0,344,43;270173,21.9,30,0,344;270164,6.6,36,0,334;270165,6.6,31,0,334;250228,3.3,33,0,334;249343,2.6,155,0,298,278;270163,1.3,32,0,334;273797,1.3,34,0,334|14:270175,39.7,30,0,344,43;270173,23.8,30,0,344;270165,16.6,31,0,334;250228,6,33,0,334;270164,4.6,36,0,334;246304,2.6,105,0,341,0,24,5,0,0,0;274493,2,37,0,321,0,25,6,0,0,0;250229,1.3,52,0,321,66|15:251132,24.5,39,0,334,58;271469,22.5,48,0,344,59;268253,15.2,12,0,344,45|16:268213,59.6,30,0,344,48;237846,24.5,40,0,331,2;268214,5.3,36,0,334,49",
    ["DEMONHUNTER/DEVAURER/Void-Scarred"] = "1:271537,88.8,53,0,344,68;271875,9.8,54,0,344,69;268219,0.7,3,0,334,211|2:268265,89.5,4,0,344,4;268251,4.2,90,0,334,127;251234,2.8,23,0,334,51|3:271535,83.2,55,0,334,71;268246,9.1,18,0,334,72;251223,5.6,39,0,334,102|5:271540,95.1,57,0,334,74;268235,2.8,18,0,334,75;244570,1.4,58,0,331,11|6:268256,23.8,59,0,344,77;271436,21,72,0,334,94;268227,20.3,3,0,334,76|7:271536,80.4,61,0,344,79;251130,13.3,39,0,334,80;268225,4.9,12,0,344,105|8:244569,66.4,63,0,331,73;159327,14,39,0,334,81;251153,8.4,64,0,334,82|9:244576,65.7,65,0,331,46;268240,11.2,66,0,334,83;251183,10.5,73,0,324,95|10:271538,84.6,68,0,334,84;268234,6.3,18,0,334,85;159337,4.2,39,0,334,130|11:252258,31.5,25,0,334,28;251136,21.7,23,0,334,31;268249,8.4,5,0,334,36;240949,7.7,29,0,331,39;268252,6.3,5,0,334,32;158366,6.3,23,0,334,30;272147,6.3,27,0,321,35,25,6,0,0,0;275527,4.9,27,0,321,126,25,6,0,0,0|12:268249,24.5,5,0,334,36;252258,22.4,25,0,334,28;158366,21,23,0,334,30;240949,14,29,0,331,39;251136,10.5,23,0,334,31;159459,4.2,24,0,334,27;273792,2.1,23,0,334,26;272150,1.4,27,0,321,40,25,6,0,0,0|13:250215,50.3,33,0,334;270164,28,36,0,334;270167,16.1,36,0,334,87;249346,2.8,155,0,298;270169,1.4,30,0,344,114;250214,0.7,33,0,334;270161,0.7,82,0,334|14:270164,46.2,36,0,334;270167,25.9,36,0,334,87;250215,25.2,33,0,334;270168,0.7,30,0,344,44;250214,0.7,33,0,334;248583,0.7,47,0,321,0,24,5,0,0,0;249343,0.7,155,0,298,278|15:251190,29.4,39,0,334,88;251132,27.3,39,0,334,58;193763,16.8,39,0,334,47|16:271092,50.3,30,0,344,62;237840,32.9,69,0,331,89;268201,7,36,0,334,98|17:237840,56.6,69,0,331,89;273778,15.4,128,0,334,203;271092,11.2,30,0,344,62",
    ["DEMONHUNTER/HAVOC/Fel-Scarred"] = "1:271537,87.5,53,0,344,68;271438,5.3,14,0,334,91;271875,5.3,54,0,344,69|2:268265,71.1,4,0,344,4;251234,25,23,0,334,51;271638,3.3,71,0,334,92|3:271535,80.9,55,0,334,71;268246,15.8,18,0,334,72;244572,2.6,56,0,331,73|5:271540,79.6,57,0,334,74;244570,18.4,58,0,331,11;239048,2,45,0,321,93|6:268227,35.5,3,0,334,76;271436,25.7,72,0,334,94;268256,19.1,59,0,344,77|7:271536,87.5,61,0,344,79;244574,9.9,62,0,331,11;268225,1.3,12,0,344,105|8:244569,40.1,63,0,331,73;159327,38.8,39,0,334,81;268261,7.9,18,0,334,18|9:244576,56.6,65,0,331,46;251183,16.4,73,0,324,95;271533,16.4,156,0,334,279|10:271538,100,68,0,334,84|11:251136,40.8,23,0,334,31;158366,38.2,23,0,334,30;240949,12.5,29,0,331,39;268249,5.3,5,0,334,36;251513,2,26,0,331,33;268252,0.7,5,0,334,32;162544,0.7,28,0,334,37|12:251136,30.3,23,0,334,31;268249,23.7,5,0,334,36;158366,19.7,23,0,334,30;240949,9.9,29,0,331,39;272149,5.9,27,0,321,42,25,6,0,0,0;251513,5.3,26,0,331,33;275526,3.9,46,0,321,57,25,6,0,0,0;268252,0.7,5,0,334,32|13:270175,39.5,30,0,344,43;270168,28.3,30,0,344,44;270173,27.6,30,0,344;193701,2,138,0,298;250214,0.7,33,0,334;270164,0.7,36,0,334;159617,0.7,33,0,334;250215,0.7,33,0,334|14:270173,65.8,30,0,344;270175,15.1,30,0,344,43;270168,12.5,30,0,344,44;270164,3.9,36,0,334;250214,1.3,33,0,334;270166,1.3,36,0,334|15:251132,55.3,39,0,334,58;239656,19.1,38,0,331,46;271532,10.5,48,0,344,97|16:268209,81.6,49,0,344,60;268201,9.2,36,0,334,98;237840,7.9,69,0,331,89|17:237840,88.2,69,0,331,89;268201,7.9,36,0,334,98;237839,2,51,0,331,63",
    ["DEMONHUNTER/VENGEANCE/Annihilator"] = "1:271537,84.1,53,0,344,68;271875,11.5,54,0,344,69;273791,4.5,75,0,334,100|2:268265,56.1,4,0,344,4;251173,20.4,23,0,334,101;273781,19.1,6,0,334,6|3:271535,86,55,0,334,71;251223,11.5,39,0,334,102;273774,1.3,45,0,321,107|5:271540,86.6,57,0,334,74;244570,3.2,58,0,331,11;268235,2.5,18,0,334,75|6:271436,28.7,72,0,334,94;159301,22.3,41,0,334,104;268256,12.7,59,0,344,77|7:271536,75.8,61,0,344,79;159313,11.5,39,0,334,220;251198,7,45,0,321,216|8:251153,38.9,64,0,334,82;244569,14.6,63,0,331,73;268247,12.7,76,0,334,106|9:244576,59.9,65,0,331,46;251135,28,67,0,334,47;159300,8.3,41,0,334,218|10:271538,75.8,68,0,334,84;244575,15.9,81,0,331,73;251124,4.5,64,0,334,86|11:159459,29.9,24,0,334,27;273792,19.7,23,0,334,26;268252,9.6,5,0,334,32;252258,8.9,25,0,334,28;240949,8.3,29,0,331,39;268266,7.6,5,0,334,29;251148,7,23,0,334,34;158366,3.8,23,0,334,30|12:159459,31.8,24,0,334,27;273792,31.8,23,0,334,26;251148,15.9,23,0,334,34;268266,7.6,5,0,334,29;268252,5.1,5,0,334,32;252258,2.5,25,0,334,28;272149,1.9,27,0,321,42,25,6,0,0,0;171545,1.3,86,0,321,200|13:270165,19.7,31,0,334;270175,17.8,30,0,344,43;250245,16.6,35,0,334;270160,10.2,31,0,334;270173,8.9,30,0,344;270164,7,36,0,334;250215,6.4,33,0,334;248583,4.5,47,0,321,0,24,5,0,0,0|14:270175,27.4,30,0,344,43;270173,22.9,30,0,344;270164,10.2,36,0,334;270165,8.9,31,0,334;250215,8.9,33,0,334;250245,7,35,0,334;273796,5.7,33,0,334;274493,4.5,37,0,321,0,25,6,0,0,0|15:239656,28.7,38,0,331,46;193763,28.7,39,0,334,47;268248,12.1,18,0,334,170|16:237840,39.5,69,0,331,89;268209,36.9,49,0,344,60;237839,16.6,51,0,331,63|17:237840,49,69,0,331,89;251231,22.9,74,0,321,99;237839,8.9,51,0,331,63",
    ["DRUID/BALANCE/Elune's Chosen"] = "1:271528,86.9,53,0,344,110;271875,13.1,54,0,344,69|2:268265,82.4,4,0,344,4;251142,8.5,42,0,334,52;251234,5.2,23,0,334,51|3:271526,88.2,79,0,334,84;244572,7.2,56,0,331,73;273774,2,45,0,321,107|5:271531,96.7,80,0,334,111;268235,2.6,18,0,334,75;251159,0.7,91,0,321,128|6:268227,34.6,3,0,334,76;271525,17.6,157,0,344,280;271436,15.7,72,0,334,94|7:271527,88.2,61,0,344,112;244574,9.8,62,0,331,11;251130,1.3,39,0,334,80|8:244569,46.4,63,0,331,73;268261,23.5,18,0,334,18;159327,18.3,39,0,334,81|9:244576,48.4,65,0,331,46;251183,21.6,73,0,324,95;268240,19,66,0,334,83|10:271529,71.9,68,0,334,113;251124,9.2,64,0,334,86;244575,7.2,81,0,331,73|11:158366,23.5,23,0,334,30;251136,22.9,23,0,334,31;268249,20.9,5,0,334,36;252258,9.8,25,0,334,28;268252,8.5,5,0,334,32;272147,6.5,27,0,321,35,25,6,0,0,0;272149,3.9,27,0,321,42,25,6,0,0,0;240949,1.3,29,0,331,39|12:252258,27.5,25,0,334,28;268249,26.1,5,0,334,36;158366,12.4,23,0,334,30;251136,11.1,23,0,334,31;273792,7.8,23,0,334,26;268252,5.9,5,0,334,32;272150,3.9,27,0,321,40,25,6,0,0,0;272149,2.6,27,0,321,42,25,6,0,0,0|13:250215,26.1,33,0,334;273796,22.9,33,0,334;270164,22.2,36,0,334;270167,20.3,36,0,334,87;270169,5.2,30,0,344,114;250214,2.6,33,0,334;250224,0.7,33,0,334|14:270164,30.7,36,0,334;270167,22.2,36,0,334,87;273796,19,33,0,334;250215,17.6,33,0,334;270169,6.5,30,0,344,114;270161,2.6,82,0,334;251792,0.7,37,0,321,0,25,6,0,0,0;273794,0.7,33,0,334|15:268253,25.5,12,0,344,45;251190,24.8,39,0,334,88;251132,24.2,39,0,334,58|16:245770,53.6,40,0,331,11;271092,37.9,30,0,344,62;268210,5.2,36,0,334,90|17:245769,80.3,83,0,331,63;268263,15.5,36,0,334,116;268197,4.2,36,0,334,115",
    ["DRUID/FERAL/Wildstalker"] = "1:271528,86.3,53,0,344,110;271875,12.4,54,0,344,69;271438,1.3,14,0,334,91|2:268265,81.7,4,0,344,4;251142,14.4,42,0,334,52;268291,3.9,158,0,298,281|3:271526,90.8,79,0,334,84;244572,7.2,56,0,331,73;273774,2,45,0,321,107|5:271531,92.2,80,0,334,111;268235,5.2,18,0,334,75;239048,1.3,45,0,321,93|6:159317,27.5,85,0,334,118;244573,17,135,0,331,73;271525,12.4,157,0,344,280|7:271527,88.9,61,0,344,112;244574,5.2,62,0,331,11;251130,3.3,39,0,334,80|8:244569,39.9,63,0,331,73;251153,29.4,64,0,334,82;159327,14.4,39,0,334,81|9:244576,72.5,65,0,331,46;268240,9.8,66,0,334,83;155922,7.2,159,0,321,282|10:271529,65.4,68,0,334,113;244575,20.3,81,0,331,73;251124,11.8,64,0,334,86|11:158366,25.5,23,0,334,30;252258,24.2,25,0,334,28;268249,11.1,5,0,334,36;272147,11.1,27,0,321,35,25,6,0,0,0;251194,8.5,23,0,334,38;251136,7.8,23,0,334,31;279010,5.9,160,0,308,283;273792,3.3,23,0,334,26|12:158366,19.6,23,0,334,30;252258,17,25,0,334,28;268249,12.4,5,0,334,36;251136,12.4,23,0,334,31;162544,9.8,28,0,334,37;251513,7.8,26,0,331,33;272147,4.6,27,0,321,35,25,6,0,0,0;251194,3.9,23,0,334,38|13:270175,65.4,30,0,344,43;270164,9.8,36,0,334;270165,7.2,31,0,334;270173,6.5,30,0,344;273796,6.5,33,0,334;250215,2,33,0,334;250228,1.3,33,0,334;248583,0.7,47,0,321,0,24,5,0,0,0|14:270175,22.2,30,0,344,43;270165,22.2,31,0,334;270173,19.6,30,0,344;270164,16.3,36,0,334;248583,6.5,47,0,321,0,24,5,0,0,0;250214,5.9,33,0,334;274493,2,37,0,321,0,25,6,0,0,0;270166,2,36,0,334|15:251132,21.6,39,0,334,58;251190,20.9,39,0,334,88;239656,19.6,38,0,331,46|16:268215,83.7,87,0,344,120;268199,11.1,36,0,334,121;237847,3.3,111,0,331,2",
    ["DRUID/GUARDIAN/Elune's Chosen"] = "1:271528,88.1,53,0,344,110;273791,5.3,75,0,334,100;271875,5.3,54,0,344,69|2:268265,62.9,4,0,344,4;273781,16.6,6,0,334,6;251173,11.3,23,0,334,101|3:271526,82.1,79,0,334,84;251223,15.2,39,0,334,102;251146,1.3,45,0,321,123|5:271531,84.8,80,0,334,111;244570,8.6,58,0,331,11;193764,4.6,45,0,321,284|6:271436,35.8,72,0,334,94;251189,28.5,75,0,334,214;271525,7.9,157,0,344,280|7:271527,69.5,61,0,344,112;244574,12.6,62,0,331,11;159313,11.9,39,0,334,220|8:244569,67.5,63,0,331,73;268247,14.6,76,0,334,106;251153,13.9,64,0,334,82|9:244576,66.2,65,0,331,46;268240,19.9,66,0,334,83;251135,11.3,67,0,334,47|10:271529,93.4,68,0,334,113;251124,4.6,64,0,334,86;159337,1.3,39,0,334,130|11:273792,36.4,23,0,334,26;159459,27.2,24,0,334,27;240949,14.6,29,0,331,39;268266,7.3,5,0,334,29;251136,5.3,23,0,334,31;268249,3.3,5,0,334,36;252258,2.6,25,0,334,28;251148,2,23,0,334,34|12:273792,42.4,23,0,334,26;159459,13.9,24,0,334,27;252258,12.6,25,0,334,28;162544,10.6,28,0,334,37;268252,6.6,5,0,334,32;268266,5.3,5,0,334,29;240949,5.3,29,0,331,39;251136,2.6,23,0,334,31|13:270175,41.7,30,0,344,43;250215,23.8,33,0,334;250245,9.9,35,0,334;270164,6.6,36,0,334;270165,6,31,0,334;250228,5.3,33,0,334;273796,4.6,33,0,334;270160,2,31,0,334|14:270165,50.3,31,0,334;270175,19.9,30,0,344,43;250245,13.2,35,0,334;270164,4.6,36,0,334;250215,4.6,33,0,334;270166,2.6,36,0,334;273796,2,33,0,334;250228,2,33,0,334|15:239656,50.3,38,0,331,46;193763,19.2,39,0,334,47;251132,7.3,39,0,334,58|16:268215,65.6,87,0,344,120;245771,11.3,88,0,331,2;158370,9.9,145,0,334,285",
    ["DRUID/RESTORATION/Wildstalker"] = "1:271528,85.3,53,0,344,110;271875,14.1,54,0,344,69;251140,0.6,21,0,321,70|2:268265,54.5,4,0,344,4;251142,25,42,0,334,52;268251,10.9,90,0,334,127|3:271526,56.4,79,0,334,84;244572,37.2,56,0,331,73;273774,3.2,45,0,321,107|5:271531,91.7,80,0,334,111;244570,7.1,58,0,331,11;193764,0.6,45,0,321,284|6:159317,35.3,85,0,334,118;268256,30.1,59,0,344,77;268227,12.8,3,0,334,76|7:271527,92.9,61,0,344,112;159329,3.8,39,0,334,125;268225,1.9,12,0,344,105|8:244569,36.5,63,0,331,73;268247,14.7,76,0,334,106;251153,13.5,64,0,334,82|9:244576,39.7,65,0,331,46;251135,21.8,67,0,334,47;268240,16.7,66,0,334,83|10:271529,91.7,68,0,334,113;159337,4.5,39,0,334,130;268234,2.6,18,0,334,85|11:252258,41.7,25,0,334,28;159459,10.9,24,0,334,27;240949,10.9,29,0,331,39;162544,8.3,28,0,334,37;272147,5.1,27,0,321,35,25,6,0,0,0;171622,4.5,86,0,321,286;251194,4.5,23,0,334,38;279010,3.2,160,0,308,283|12:252258,41.7,25,0,334,28;159459,22.4,24,0,334,27;272150,6.4,27,0,321,40,25,6,0,0,0;240949,5.8,29,0,331,39;162544,5.1,28,0,334,37;251194,5.1,23,0,334,38;279010,3.8,160,0,308,283;268266,3.2,5,0,334,29|13:270162,39.7,36,0,334;270167,18.6,36,0,334,87;250255,16,33,0,334;270164,5.8,36,0,334;250214,5.1,33,0,334;250254,4.5,33,0,334;270169,3.2,30,0,344,114;248583,2.6,47,0,321,0,24,5,0,0,0|14:270167,34,36,0,334,87;250214,21.8,33,0,334;270162,19.9,36,0,334;270164,16.7,36,0,334;250255,3.2,33,0,334;249343,1.3,155,0,298,278;159617,1.3,33,0,334;270169,0.6,30,0,344,114|15:251190,55.8,39,0,334,88;268253,11.5,12,0,344,45;159288,10.3,39,0,334,202|16:245770,45.5,40,0,331,11;271092,39.7,30,0,344,62;251225,3.8,161,0,321,287|17:245769,70.9,83,0,331,63;268197,17.7,36,0,334,115;251191,5.1,33,0,334,133",
    ["EVOKER/AUGMENTATION/Chronowarden"] = "1:271501,71.8,1,0,334,134;239035,11.5,41,0,334,172;193765,8.3,67,0,334,288|2:268265,63.5,4,0,344,4;251234,12.2,23,0,334,51;251142,8.3,42,0,334,52|3:271499,85.9,95,0,344,137;268231,7.1,12,0,344,138;244580,3.2,81,0,331,139|5:271504,89.1,96,0,344,140;271876,8.3,97,0,344,120;273789,1.3,39,0,334,254|6:268254,33.3,3,0,334,142;244581,24.4,98,0,331,139;251228,18.6,147,0,334,255|7:271500,89.7,61,0,344,144;244582,5.1,81,0,331,145;193759,1.9,45,0,321,289|8:268258,29.5,18,0,334,147;159388,19.2,39,0,334,148;268233,18.6,18,0,334,20|9:244584,80.8,98,0,331,149;268217,11.5,3,0,334,150;251200,3.2,41,0,334,47|10:271502,94.2,22,0,334,152;244583,1.9,100,0,331,73;249998,1.9,162,0,289,290|11:158366,26.9,23,0,334,30;251136,26.3,23,0,334,31;268249,23.7,5,0,334,36;273792,7.7,23,0,334,26;252258,6.4,25,0,334,28;251194,5.1,23,0,334,38;272149,1.3,27,0,321,42,25,6,0,0,0;268252,0.6,5,0,334,32|12:158366,33.3,23,0,334,30;268249,18.6,5,0,334,36;251136,14.1,23,0,334,31;252258,8.3,25,0,334,28;272150,7.1,27,0,321,40,25,6,0,0,0;240949,6.4,29,0,331,39;272149,6.4,27,0,321,42,25,6,0,0,0;162544,2.6,28,0,334,37|13:270168,25,30,0,344,44;270161,19.2,82,0,334;250224,18.6,33,0,334;270167,8.3,36,0,334,87;250215,8.3,33,0,334;249346,5.8,155,0,298;270164,5.1,36,0,334;270170,3.8,36,0,334|14:250224,34,33,0,334;270161,28.2,82,0,334;270164,14.7,36,0,334;270167,5.1,36,0,334,87;270168,5.1,30,0,344,44;274493,4.5,37,0,321,0,25,6,0,0,0;250214,3.8,33,0,334;250215,1.9,33,0,334|15:251132,45.5,39,0,334,58;239656,17.9,38,0,331,46;159288,12.8,39,0,334,202|16:271092,44.9,30,0,344,62;245770,12.2,40,0,331,11;268203,11.5,70,0,334,90|17:245769,74.6,83,0,331,63;268263,18.6,36,0,334,116;271681,3.4,163,0,321,291",
    ["EVOKER/DEVASTATION/Scalecommander"] = "1:271501,97.5,1,0,334,134;268230,2.5,93,0,334,135|2:268265,82.2,4,0,344,4;271638,7.6,71,0,334,92;251234,5.1,23,0,334,51|3:271499,87.9,95,0,344,137;239049,8.3,39,0,334,162;244580,1.9,81,0,331,139|5:271504,88.5,96,0,344,140;271876,11.5,97,0,344,120|6:268216,21,102,0,334,155;244581,21,98,0,331,139;251155,14.6,41,0,334,143|7:271500,94.3,61,0,344,144;244582,3.2,81,0,331,145;268237,1.3,12,0,344,146|8:268258,51,18,0,334,147;271440,14,113,0,334,168;159388,8.3,39,0,334,148|9:244584,56.1,98,0,331,149;268217,26.1,3,0,334,150;251200,8.3,41,0,334,47|10:271502,82.2,22,0,334,152;268238,10.2,18,0,334,86;160213,5.1,45,0,321,292|11:158366,25.5,23,0,334,30;273792,18.5,23,0,334,26;252258,10.2,25,0,334,28;251513,8.9,26,0,331,33;251136,8.3,23,0,334,31;268266,7.6,5,0,334,29;268252,5.7,5,0,334,32;275526,5.7,46,0,321,57,25,6,0,0,0|12:251136,29.9,23,0,334,31;158366,26.1,23,0,334,30;268252,25.5,5,0,334,32;273792,9.6,23,0,334,26;252258,4.5,25,0,334,28;251148,1.3,23,0,334,34;268249,1.3,5,0,334,36;272147,1.3,27,0,321,35,25,6,0,0,0|13:273796,41.4,33,0,334;270167,36.9,36,0,334,87;270164,16.6,36,0,334;250224,1.9,33,0,334;270161,1.3,82,0,334;249346,0.6,155,0,298;274493,0.6,37,0,321,0,25,6,0,0,0;250215,0.6,33,0,334|14:270164,56.7,36,0,334;273796,15.9,33,0,334;270167,10.8,36,0,334,87;250214,7.6,33,0,334;270161,4.5,82,0,334;250224,1.9,33,0,334;171644,0.6,114,0,321;251792,0.6,37,0,321,0,25,6,0,0,0|15:251132,37.6,39,0,334,58;239656,21,38,0,331,46;271496,15.3,164,0,328,293|16:271092,52.2,30,0,344,62;245770,35.7,40,0,331,11;273778,5.1,128,0,334,203|17:245769,97.9,83,0,331,63;268263,2.1,36,0,334,116",
    ["EVOKER/PRESERVATION/Flameshaper"] = "1:271501,86.2,1,0,334,134;271441,7.9,94,0,334,136;251158,3.3,41,0,334,294|2:268265,77.6,4,0,344,4;251173,11.2,23,0,334,101;251142,5.3,42,0,334,52|3:271499,84.9,95,0,344,137;239049,11.2,39,0,334,162;244580,2,81,0,331,139|5:271504,78.3,96,0,344,140;271876,7.9,97,0,344,120;251233,5.3,45,0,321,173|6:268216,33.6,102,0,334,155;159369,29.6,21,0,321,295;244581,13.8,98,0,331,139|7:271500,94.7,61,0,344,144;244582,3.3,81,0,331,145;193759,2,45,0,321,289|8:271440,41.4,113,0,334,168;251145,22.4,154,0,321,296;251125,11.8,125,0,334,260|9:244584,63.8,98,0,331,149;251200,19.7,41,0,334,47;159380,11.8,99,0,328,151|10:271502,86.2,22,0,334,152;268238,5.3,18,0,334,86;251152,5.3,45,0,321,296|11:251148,29.6,23,0,334,34;273792,28.3,23,0,334,26;159459,20.4,24,0,334,27;268266,5.3,5,0,334,29;158366,5.3,23,0,334,30;275529,3.9,160,0,308,297;251136,2,23,0,334,31;240949,1.3,29,0,331,39|12:159459,21.1,24,0,334,27;251148,20.4,23,0,334,34;273792,19.7,23,0,334,26;268266,11.2,5,0,334,29;240949,9.2,29,0,331,39;268252,7.2,5,0,334,32;272148,4.6,27,0,321,41,25,6,0,0,0;251136,3.3,23,0,334,31|13:270162,42.8,36,0,334;270167,23,36,0,334,87;270164,9.9,36,0,334;246304,6.6,105,0,341,0,24,5,0,0,0;250215,6.6,33,0,334;248583,5.3,47,0,321,0,24,5,0,0,0;270169,2,30,0,344,114;270171,2,104,0,334,158|14:270162,48.7,36,0,334;270164,29.6,36,0,334;270167,10.5,36,0,334,87;250214,3.3,33,0,334;250255,2,33,0,334;171640,2,165,0,311;270171,2,104,0,334,158;274493,1.3,37,0,321,0,25,6,0,0,0|15:239656,27,38,0,331,46;193763,23.7,39,0,334,47;268248,15.1,18,0,334,170|16:271092,47.4,30,0,344,62;245770,34.9,40,0,331,11;268203,6.6,70,0,334,90|17:245769,82.1,83,0,331,63;193766,13.7,166,0,321,298;268197,3.2,36,0,334,115",
    ["HUNTER/BEASTMASTERY/Pack Leader"] = "1:271492,96,106,0,334,159;271441,3.3,94,0,334,136;193765,0.7,67,0,334,288|2:268265,88.1,4,0,344,4;251234,7.3,23,0,334,51;271638,3.3,71,0,334,92|3:271490,80.1,107,0,344,161;251131,13.2,39,0,334,165;268231,3.3,12,0,344,138|5:271495,92.1,96,0,344,105;271876,7.9,97,0,344,120|6:244581,40.4,98,0,331,139;268216,23.8,102,0,334,155;251155,19.9,41,0,334,143|7:271491,58.9,108,0,344,163;244582,36.4,81,0,331,145;193759,2.6,45,0,321,289|8:271440,38.4,113,0,334,168;268258,19.9,18,0,334,147;271494,16.6,167,0,334,183|9:244584,77.5,98,0,331,149;268217,8.6,3,0,334,150;244568,6,168,0,292,299|10:271493,93.4,109,0,334,106;251165,2.6,45,0,321,300;193752,1.3,45,0,321,164|11:158366,28.5,23,0,334,30;251136,25.8,23,0,334,31;268249,15.9,5,0,334,36;251194,9.3,23,0,334,38;162544,7.9,28,0,334,37;240949,6,29,0,331,39;268252,4.6,5,0,334,32;272149,1.3,27,0,321,42,25,6,0,0,0|12:268249,36.4,5,0,334,36;251136,34.4,23,0,334,31;162544,8.6,28,0,334,37;158366,6.6,23,0,334,30;251194,5.3,23,0,334,38;272149,3.3,27,0,321,42,25,6,0,0,0;240949,3.3,29,0,331,39;251148,1.3,23,0,334,34|13:270175,35.8,30,0,344,43;270164,25.8,36,0,334;159617,9.9,33,0,334;250214,7.3,33,0,334;270165,5.3,31,0,334;273796,4,33,0,334;250215,4,33,0,334;270168,2.6,30,0,344,44|14:270175,23.2,30,0,344,43;250215,21.9,33,0,334;270164,19.2,36,0,334;250214,10.6,33,0,334;270168,7.9,30,0,344,44;270165,5.3,31,0,334;265657,3.3,37,0,321,0,25,6,0,0,0;250225,3.3,52,0,321|15:251132,39.7,39,0,334,58;268248,23.2,18,0,334,170;271487,15.2,48,0,344,171|16:268207,63.6,110,0,344,16;265337,31.8,111,0,331,145;268200,4.6,36,0,334,75",
    ["HUNTER/MARKSMANSHIP/Sentinel"] = "1:271492,91.9,106,0,334,159;268230,4.1,93,0,334,135;272250,2,101,0,321,153,25,6,0,0,0|2:268265,68.9,4,0,344,4;251234,27.7,23,0,334,51;273781,1.4,6,0,334,6|3:271490,91.2,107,0,344,161;251131,7.4,39,0,334,165;239049,1.4,39,0,334,162|5:271495,96.6,96,0,344,105;271876,2,97,0,344,120;251233,1.4,45,0,321,173|6:244581,73,98,0,331,139;251155,11.5,41,0,334,143;251228,6.8,147,0,334,255|7:271491,68.2,108,0,344,163;244582,23,81,0,331,145;159375,5.4,45,0,321,167|8:159388,39.2,39,0,334,148;271494,19.6,167,0,334,183;268258,18.2,18,0,334,147|9:244584,85.1,98,0,331,149;159380,6.1,99,0,328,151;268217,5.4,3,0,334,150|10:271493,90.5,109,0,334,106;193752,8.1,45,0,321,164;251165,1.4,45,0,321,300|11:158366,52,23,0,334,30;251136,27.7,23,0,334,31;268252,6.1,5,0,334,32;251148,4.7,23,0,334,34;268249,4.7,5,0,334,36;251513,1.4,26,0,331,33;162544,1.4,28,0,334,37;272149,0.7,27,0,321,42,25,6,0,0,0|12:251136,53.4,23,0,334,31;158366,27.7,23,0,334,30;272148,5.4,27,0,321,41,25,6,0,0,0;251148,4.7,23,0,334,34;251513,2.7,26,0,331,33;268249,2.7,5,0,334,36;251194,1.4,23,0,334,38;240949,1.4,29,0,331,39|13:270175,50,30,0,344,43;270168,19.6,30,0,344,44;270165,6.8,31,0,334;159617,6.1,33,0,334;250228,3.4,33,0,334;260235,2.7,155,0,298;250214,2.7,33,0,334;270164,2,36,0,334|14:270168,35.8,30,0,344,44;270175,23,30,0,344,43;273796,8.1,33,0,334;249806,6.8,155,0,298;270164,6.1,36,0,334;250214,4.7,33,0,334;270173,4.1,30,0,344;156000,3.4,114,0,321,66|15:251132,52,39,0,334,58;271487,18.2,48,0,344,171;268248,10.8,18,0,334,170|16:268207,72.3,110,0,344,16;265337,16.2,111,0,331,145;268200,8.8,36,0,334,75",
    ["HUNTER/SURVIVAL/Sentinel"] = "1:271492,89,106,0,334,159;239035,5.2,41,0,334,172;268230,4.5,93,0,334,135|2:268265,33.5,4,0,344,4;251142,29,42,0,334,52;251234,15.5,23,0,334,51|3:271490,96.8,107,0,344,161;244580,2.6,81,0,331,139;239049,0.6,39,0,334,162|5:271495,97.4,96,0,344,105;271876,1.9,97,0,344,120;239046,0.6,45,0,321,259|6:244581,49,98,0,331,139;251155,20.6,41,0,334,143;268216,9.7,102,0,334,155|7:271491,87.7,108,0,344,163;159375,5.2,45,0,321,167;268237,3.9,12,0,344,146|8:268233,29.7,18,0,334,20;244577,26.5,81,0,331,139;271494,17.4,167,0,334,183|9:244584,92.3,98,0,331,149;251200,4.5,41,0,334,47;244568,1.9,168,0,292,299|10:271493,91,109,0,334,106;160213,4.5,45,0,321,292;193752,1.9,45,0,321,164|11:252258,25.8,25,0,334,28;158366,20,23,0,334,30;272147,12.9,27,0,321,35,25,6,0,0,0;240949,11,29,0,331,39;273792,10.3,23,0,334,26;251136,7.7,23,0,334,31;268249,5.2,5,0,334,36;272150,3.9,27,0,321,40,25,6,0,0,0|12:158366,27.7,23,0,334,30;252258,25.8,25,0,334,28;251136,24.5,23,0,334,31;268249,8.4,5,0,334,36;273792,3.9,23,0,334,26;251194,3.2,23,0,334,38;240949,1.9,29,0,331,39;171654,1.9,86,0,321,174,24,5,0,0,0|13:250215,25.8,33,0,334;270175,23.2,30,0,344,43;270173,23.2,30,0,344;273797,11.6,34,0,334;270164,5.8,36,0,334;250214,3.9,33,0,334;270165,1.9,31,0,334;249806,1.3,155,0,298|14:270165,31,31,0,334;270173,30.3,30,0,344;250214,14.2,33,0,334;270164,7.7,36,0,334;250215,5.2,33,0,334;270175,5.2,30,0,344,43;273797,4.5,34,0,334;250228,1.3,33,0,334|15:268253,27.1,12,0,344,45;239656,21.9,38,0,331,46;271487,16.8,48,0,344,171|16:268209,25.2,49,0,344,60;268213,24.5,30,0,344,48;268215,21.3,87,0,344,120|17:275070,59.1,145,0,334,249;271093,27.3,30,0,344,247;159136,4.5,161,0,321,301",
    ["MAGE/ARCANE/Sunfury"] = "1:271564,83.4,115,0,344,176;271874,7.6,116,0,344,177;268242,7,102,0,334,178|2:268265,94.3,4,0,344,4;271638,3.2,71,0,334,92;251173,1.3,23,0,334,101|3:271562,84.7,117,0,334,179;271434,9.6,8,0,334,239;239650,5.7,58,0,331,73|5:271567,96.8,80,0,334,181;251139,1.9,119,0,331,182;268221,0.6,18,0,334,205|6:268232,45.9,20,0,334,183;268257,15.9,120,0,334,184;239649,13.4,65,0,331,73|7:271563,93.6,121,0,334,185;251160,4.5,45,0,321,302;239651,1.9,81,0,331,2|8:271435,61.1,113,0,334,187;268255,10.8,12,0,344,189;271566,10.8,167,0,334,303|9:239648,73.9,123,0,331,46;251127,11.5,41,0,334,190;159263,7.6,21,0,321,304|10:271565,77.1,124,0,344,192;239653,9.6,58,0,331,73;268243,6.4,12,0,344,193|11:251148,26.8,23,0,334,34;268266,19.7,5,0,334,29;268252,16.6,5,0,334,32;159459,16.6,24,0,334,27;273792,8.9,23,0,334,26;240949,6.4,29,0,331,39;272148,5.1,27,0,321,41,25,6,0,0,0|12:251148,29.3,23,0,334,34;159459,28.7,24,0,334,27;268266,17.2,5,0,334,29;240949,9.6,29,0,331,39;268252,6.4,5,0,334,32;272148,4.5,27,0,321,41,25,6,0,0,0;273792,3.8,23,0,334,26;171622,0.6,86,0,321,286|13:250215,68.2,33,0,334;270164,17.2,36,0,334;270169,9.6,30,0,344,114;270167,5.1,36,0,334,87|14:270164,64.3,36,0,334;250215,21.7,33,0,334;270167,13.4,36,0,334,87;270169,0.6,30,0,344,114|15:268248,26.1,18,0,334,170;193763,23.6,39,0,334,47;271559,18.5,36,0,334,191|16:245770,40.8,40,0,331,11;271092,26.1,30,0,344,62;268211,17.8,30,0,344,194|17:245769,87.8,83,0,331,63;268263,8.5,36,0,334,116;268197,3.7,36,0,334,115",
    ["MAGE/FIRE/Sunfury"] = "1:271564,80.4,115,0,344,176;271874,14.6,116,0,344,177;268242,2.5,102,0,334,178|2:268265,39.2,4,0,344,4;251142,25.3,42,0,334,52;268251,13.9,90,0,334,127|3:271562,86.1,117,0,334,179;239045,5.1,39,0,334,204;239650,3.2,58,0,331,73|5:271567,85.4,80,0,334,181;239655,12,118,0,331,11;251139,1.3,119,0,331,182|6:193691,32.9,41,0,334,53;268257,15.8,120,0,334,184;239649,15.2,65,0,331,73|7:271563,85.4,121,0,334,185;239651,7.6,81,0,331,2;272235,3.2,89,0,321,305|8:159243,39.9,39,0,334,197;251137,18.4,125,0,334,198;268255,17.1,12,0,344,189|9:239648,63.9,123,0,331,46;155945,8.2,169,0,311,306;159263,7.6,21,0,321,304|10:271565,81.6,124,0,344,192;239653,12.7,58,0,331,73;159247,2.5,129,0,334,208|11:159459,34.2,24,0,334,27;252258,29.7,25,0,334,28;268266,14.6,5,0,334,29;272147,7.6,27,0,321,35,25,6,0,0,0;266317,3.2,126,0,321,201;251148,1.9,23,0,334,34;272150,1.9,27,0,321,40,25,6,0,0,0;171545,1.9,86,0,321,200|12:268266,32.3,5,0,334,29;252258,25.9,25,0,334,28;159459,24.1,24,0,334,27;251148,4.4,23,0,334,34;275529,2.5,160,0,308,297;266317,2.5,126,0,321,201;240949,1.9,29,0,331,39;251194,1.9,23,0,334,38|13:273796,36.7,33,0,334;270167,17.7,36,0,334,87;270164,9.5,36,0,334;273649,9.5,33,0,334;250144,8.2,138,0,298;270169,5.7,30,0,344,114;251792,3.2,37,0,321,0,25,6,0,0,0;250215,3.2,33,0,334|14:273796,39.2,33,0,334;270164,26.6,36,0,334;270167,15.2,36,0,334,87;273649,6.3,33,0,334;250214,5.1,33,0,334;250224,1.9,33,0,334;250144,1.9,138,0,298;270168,1.3,30,0,344,44|15:159288,33.5,39,0,334,202;239656,20.9,38,0,331,46;251190,14.6,39,0,334,88|16:245770,53.2,40,0,331,11;271092,30.4,30,0,344,62;273778,6.3,128,0,334,203|17:245769,80,83,0,331,63;268263,11.4,36,0,334,116;251191,5.7,33,0,334,133",
    ["MAGE/FROST/Spellslinger"] = "1:271564,76.8,115,0,344,176;271874,17.4,116,0,344,177;268242,1.9,102,0,334,178|2:268265,47.7,4,0,344,4;251234,25.8,23,0,334,51;273781,12.3,6,0,334,6|3:271562,86.5,117,0,334,179;239031,9.7,45,0,321,262;239650,1.3,58,0,331,73|5:271567,90.3,80,0,334,181;268221,3.2,18,0,334,205;251139,2.6,119,0,331,182|6:239649,41.9,65,0,331,73;271561,14.8,170,0,321,307;251185,13.5,85,0,334,308|7:271563,93.5,121,0,334,185;159234,2.6,39,0,334,206;239651,1.3,81,0,331,2|8:251219,27.1,64,0,334,237;251137,16.1,125,0,334,198;271566,14.8,167,0,334,303|9:239648,51.6,123,0,331,46;268228,20,3,0,334,191;271560,8.4,171,0,334,309|10:271565,80.6,124,0,344,192;159247,11,129,0,334,208;273773,3.9,130,0,334,209|11:251136,28.4,23,0,334,31;158366,22.6,23,0,334,30;251513,10.3,26,0,331,33;273792,9,23,0,334,26;162544,7.7,28,0,334,37;240949,7.7,29,0,331,39;252258,5.2,25,0,334,28;272150,2.6,27,0,321,40,25,6,0,0,0|12:251136,32.9,23,0,334,31;158366,20,23,0,334,30;268249,8.4,5,0,334,36;275526,7.7,46,0,321,57,25,6,0,0,0;252258,7.1,25,0,334,28;251148,5.8,23,0,334,34;240949,5.2,29,0,331,39;273792,4.5,23,0,334,26|13:270164,32.9,36,0,334;250215,30.3,33,0,334;246304,12.9,105,0,341,0,24,5,0,0,0;270167,12.3,36,0,334,87;250214,5.8,33,0,334;249343,1.9,155,0,298,278;273796,1.3,33,0,334;270168,1.3,30,0,344,44|14:270164,40.6,36,0,334;270167,29.7,36,0,334,87;250215,13.5,33,0,334;250214,5.2,33,0,334;274493,3.9,37,0,321,0,25,6,0,0,0;250224,3.9,33,0,334;273794,1.3,33,0,334;251792,0.6,37,0,321,0,25,6,0,0,0|15:251132,42.6,39,0,334,58;271559,15.5,36,0,334,191;239656,13.5,38,0,331,46|16:245770,60.6,40,0,331,11;271092,20,30,0,344,62;273778,13.5,128,0,334,203|17:245769,63.3,83,0,331,63;268263,15,36,0,334,116;273779,11.7,33,0,334,310",
    ["MONK/BREWMASTER/Shado-Pan"] = "1:271519,81.4,131,0,344,210;193751,9,84,0,321,117;271438,7.1,14,0,334,91|2:268265,66.7,4,0,344,4;251234,16,23,0,334,51;272229,8.3,172,0,321,311|3:271517,92.3,55,0,334,212;251146,7.7,45,0,321,123|5:271522,91,132,0,334,213;239048,7.1,45,0,321,93;251226,1.9,45,0,321,103|6:271436,26.9,72,0,334,94;268227,19.9,3,0,334,76;251189,17.9,75,0,334,214|7:271518,83.3,133,0,344,215;251198,7.7,45,0,321,216;159313,4.5,39,0,334,220|8:159327,32.1,39,0,334,81;244569,28.8,63,0,331,73;159304,26.9,64,0,334,217|9:244576,45.5,65,0,331,46;251183,21.8,73,0,324,95;159300,18.6,41,0,334,218|10:271520,80.1,134,0,334,219;193758,11.5,45,0,321,107;268234,6.4,18,0,334,85|11:251513,51.3,26,0,331,33;251148,43.6,23,0,334,34;251136,3.2,23,0,334,31;272148,0.6,27,0,321,41,25,6,0,0,0;158366,0.6,23,0,334,30;251194,0.6,23,0,334,38|12:251513,43.6,26,0,331,33;251148,40.4,23,0,334,34;251136,9,23,0,334,31;240949,2.6,29,0,331,39;272149,1.9,27,0,321,42,25,6,0,0,0;266317,1.3,126,0,321,201;251194,1.3,23,0,334,38|13:270175,40.4,30,0,344,43;250245,17.9,35,0,334;270164,16,36,0,334;270174,7.7,77,0,334,108;270160,5.1,31,0,334;250215,3.2,33,0,334;270166,2.6,36,0,334;159617,2.6,33,0,334|14:250245,49.4,35,0,334;270164,16,36,0,334;270175,16,30,0,344,43;270173,10.3,30,0,344;273796,4.5,33,0,334;250228,1.9,33,0,334;274493,1.3,37,0,321,0,25,6,0,0,0;250215,0.6,33,0,334|15:159288,34.6,39,0,334,202;268248,26.3,18,0,334,170;272226,14.1,89,0,321,312|16:268215,46.8,87,0,344,120;237847,30.8,111,0,331,2;245771,11.5,88,0,331,2",
    ["MONK/MISTWEAVER/Conduit of the Celestials"] = "1:271519,64.7,131,0,344,210;271875,33.3,54,0,344,69;193751,1.3,84,0,321,117|2:268265,81,4,0,344,4;251142,5.2,42,0,334,52;273781,3.9,6,0,334,6|3:271517,94.1,55,0,334,212;251223,3.3,39,0,334,102;273774,2,45,0,321,107|5:271522,91.5,132,0,334,213;239048,3.3,45,0,321,93;244570,2.6,58,0,331,11|6:268227,24.2,3,0,334,76;271436,20.9,72,0,334,94;159301,17.6,41,0,334,104|7:271518,83.7,133,0,344,215;244574,9.8,62,0,331,11;251130,5.9,39,0,334,80|8:244569,30.7,63,0,331,73;268247,26.8,76,0,334,106;159327,15,39,0,334,81|9:244576,55.6,65,0,331,46;268240,26.1,66,0,334,83;251135,11.8,67,0,334,47|10:271520,83,134,0,334,219;244575,7.2,81,0,331,73;159312,4.6,45,0,321,96|11:252258,26.1,25,0,334,28;268266,13.7,5,0,334,29;159459,13.7,24,0,334,27;240949,9.8,29,0,331,39;279010,7.8,160,0,308,283;162544,7.2,28,0,334,37;273792,6.5,23,0,334,26;251148,3.9,23,0,334,34|12:252258,37.9,25,0,334,28;273792,17,23,0,334,26;162544,9.2,28,0,334,37;171853,7.8,86,0,321,131,24,5,0,0,0;251148,6.5,23,0,334,34;240949,4.6,29,0,331,39;268249,4.6,5,0,334,36;279010,3.3,160,0,308,283|13:270162,51.6,36,0,334;249808,15,155,0,298;270167,9.2,36,0,334,87;250214,5.9,33,0,334;250255,5.2,33,0,334;270164,3.3,36,0,334;270169,2.6,30,0,344,114;249346,2.6,155,0,298|14:270162,36.6,36,0,334;270167,18.3,36,0,334,87;249808,11.8,155,0,298;270164,10.5,36,0,334;193757,8.5,33,0,334;251792,3.9,37,0,321,0,25,6,0,0,0;250214,3.9,33,0,334;250255,3.3,33,0,334|15:251190,29.4,39,0,334,88;193763,19,39,0,334,47;239656,17.6,38,0,331,46|16:245770,78.4,40,0,331,11;268205,20.3,36,0,334,221;251156,0.7,145,0,334,313|17:251191,100,33,0,334,133",
    ["MONK/WINDWALKER/Conduit of the Celestials"] = "1:271519,87.3,131,0,344,210;271875,12,54,0,344,69;271438,0.7,14,0,334,91|2:268265,94,4,0,344,4;271638,2.7,71,0,334,92;251142,1.3,42,0,334,52|3:271517,88.7,55,0,334,212;268246,10.7,18,0,334,72;272244,0.7,89,0,321,314|5:271522,94,132,0,334,213;244570,2.7,58,0,331,11;268235,2,18,0,334,75|6:268256,28.7,59,0,344,77;271436,19.3,72,0,334,94;268227,18,3,0,334,76|7:271518,84,133,0,344,215;268225,8,12,0,344,105;244574,6,62,0,331,11|8:244569,80,63,0,331,73;268261,5.3,18,0,334,18;251153,5.3,64,0,334,82|9:244576,86,65,0,331,46;268240,6.7,66,0,334,83;251135,4.7,67,0,334,47|10:271520,78.7,134,0,334,219;268234,14,18,0,334,85;244575,3.3,81,0,331,73|11:252258,22,25,0,334,28;251513,20,26,0,331,33;251136,17.3,23,0,334,31;273792,11.3,23,0,334,26;158366,6.7,23,0,334,30;240949,5.3,29,0,331,39;279010,4.7,160,0,308,283;268249,4.7,5,0,334,36|12:158366,34.7,23,0,334,30;252258,20.7,25,0,334,28;272150,11.3,27,0,321,40,25,6,0,0,0;251136,10.7,23,0,334,31;273792,6.7,23,0,334,26;268249,6,5,0,334,36;240949,3.3,29,0,331,39;251194,2.7,23,0,334,38|13:270175,85.3,30,0,344,43;270165,11.3,31,0,334;270166,2,36,0,334;250215,1.3,33,0,334|14:270173,43.3,30,0,344;270165,18.7,31,0,334;270175,13.3,30,0,344,43;270164,6.7,36,0,334;250228,4.7,33,0,334;274493,4,37,0,321,0,25,6,0,0,0;250214,2.7,33,0,334;270166,2.7,36,0,334|15:251132,38.7,39,0,334,58;251190,30.7,39,0,334,88;271514,10.7,48,0,344,315|16:268215,88.7,87,0,344,120;245771,4.7,88,0,331,2;268199,4,36,0,334,121",
    ["PALADIN/HOLY/Herald of the Sun"] = "1:271465,86.9,106,0,334,223;268229,7.8,3,0,334,3;239050,4.6,84,0,321,269|2:268265,85,4,0,344,4;251173,8.5,23,0,334,101;271638,2.6,71,0,334,92|3:271463,87.6,7,0,334,224;271444,10.5,8,0,334,8;268226,1.3,9,0,334,9|5:271468,81,10,0,344,105;251193,8.5,45,0,321,270;237829,4.6,11,0,331,11|6:271445,44.4,14,0,334,15;268244,15.7,3,0,334,14;271462,13.1,173,0,334,316|7:271464,80.4,15,0,344,225;271878,15,16,0,344,16;159435,3.3,45,0,321,117|8:237828,38.6,19,0,331,19;268245,22.2,18,0,334,18;273777,12.4,39,0,334,230|9:237834,80.4,2,0,331,21;268239,7.2,20,0,334,22;159425,5.2,84,0,321,271|10:271466,77.1,134,0,334,227;237836,12.4,19,0,331,19;268220,4.6,18,0,334,25|11:159459,29.4,24,0,334,27;273792,24.2,23,0,334,26;251148,13.1,23,0,334,34;252258,10.5,25,0,334,28;240949,9.2,29,0,331,39;268266,9.2,5,0,334,29;251194,3.3,23,0,334,38;162544,1.3,28,0,334,37|12:159459,34,24,0,334,27;251148,24.2,23,0,334,34;273792,17.6,23,0,334,26;268266,7.8,5,0,334,29;252258,7.2,25,0,334,28;240949,5.9,29,0,331,39;251136,2,23,0,334,31;251194,0.7,23,0,334,38|13:270162,57.5,36,0,334;270164,24.8,36,0,334;270167,8.5,36,0,334,87;193757,2.6,33,0,334;250215,2.6,33,0,334;250214,1.3,33,0,334;250259,1.3,78,0,334;270171,0.7,104,0,334,158|14:270164,44.4,36,0,334;270162,34.6,36,0,334;270167,11.8,36,0,334,87;250214,3.9,33,0,334;248583,2.6,47,0,321,0,24,5,0,0,0;250215,1.3,33,0,334;274493,0.7,37,0,321,0,25,6,0,0,0;273796,0.7,33,0,334|15:193763,27.5,39,0,334,47;268248,17,18,0,334,170;271460,16.3,48,0,344,232|16:237843,60.1,136,0,331,63;268210,26.1,36,0,334,90;268211,9.2,30,0,344,194|17:268196,29.4,137,0,334,229;268262,23.5,32,0,334,228;237831,17,38,0,331,63",
    ["PALADIN/PROTECTION/Lightsmith"] = "1:271465,90.8,106,0,334,223;251229,5.2,41,0,334,64;251126,3.9,41,0,334,50|2:268265,55.6,4,0,344,4;273781,26.1,6,0,334,6;251173,17,23,0,334,101|3:271463,77.1,7,0,334,224;239037,9.2,64,0,334,317;271444,5.2,8,0,334,8|5:271468,91.5,10,0,344,105;239036,3.3,45,0,321,65;251151,2,154,0,321,277|6:237830,34,2,0,331,73;268259,22.2,13,0,344,13;268244,17.6,3,0,334,14|7:271464,69.3,15,0,344,225;271878,25.5,16,0,344,16;251182,3.9,45,0,321,318|8:237828,38.6,19,0,331,19;273777,20.3,39,0,334,230;268245,19,18,0,334,18|9:237834,39.2,2,0,331,21;251133,17.6,21,0,321,23;268239,12.4,20,0,334,22|10:271466,91.5,134,0,334,227;251214,5.9,150,0,331,268;159413,1.3,45,0,321,56|11:273792,44.4,23,0,334,26;240949,25.5,29,0,331,39;251148,7.8,23,0,334,34;159459,6.5,24,0,334,27;252258,6.5,25,0,334,28;251136,5.2,23,0,334,31;251513,1.3,26,0,331,33;158366,0.7,23,0,334,30|12:273792,35.9,23,0,334,26;251148,15.7,23,0,334,34;159459,9.2,24,0,334,27;272148,8.5,27,0,321,41,25,6,0,0,0;240949,8.5,29,0,331,39;252258,7.8,25,0,334,28;251136,4.6,23,0,334,31;158366,3.3,23,0,334,30|13:270175,34,30,0,344,43;270173,18.3,30,0,344;270165,9.2,31,0,334;273796,9.2,33,0,334;270160,7.2,31,0,334;250228,6.5,33,0,334;270164,4.6,36,0,334;274493,3.3,37,0,321,0,25,6,0,0,0|14:270173,30.7,30,0,344;270164,11.8,36,0,334;270165,11.1,31,0,334;270175,11.1,30,0,344,43;270160,10.5,31,0,334;250228,7.2,33,0,334;273796,6.5,33,0,334;250245,6.5,35,0,334|15:239656,24.8,38,0,331,46;193763,22.2,39,0,334,47;268253,10.5,12,0,344,45|16:268209,38.6,49,0,344,60;268202,24.8,50,0,344,62;237839,17,51,0,331,63|17:237831,62.7,38,0,331,63;268196,15.7,137,0,334,229;268262,15,32,0,334,228",
    ["PALADIN/RETRIBUTION/Herald of the Sun"] = "1:271465,94.9,106,0,334,223;268229,2.5,3,0,334,3;237832,2.5,2,0,331,2|2:268265,76.4,4,0,344,4;251142,15.9,42,0,334,52;271638,6.4,71,0,334,92|3:271463,77.7,7,0,334,224;271444,8.9,8,0,334,8;239051,5.7,45,0,321,319|5:271468,95.5,10,0,344,105;237829,2.5,11,0,331,11;268222,1.3,12,0,344,12|6:271445,40.8,14,0,334,15;268259,24.2,13,0,344,13;271462,22.3,173,0,334,316|7:271464,89.8,15,0,344,225;271878,9.6,16,0,344,16;273776,0.6,125,0,334,273|8:268260,40.1,18,0,334,20;271467,28.7,167,0,334,320;237828,12.7,19,0,331,19|9:237834,83.4,2,0,331,21;268239,15.3,20,0,334,22;251133,1.3,21,0,321,23|10:271466,78.3,134,0,334,227;237836,17.2,19,0,331,19;159413,3.2,45,0,321,56|11:251513,31.8,26,0,331,33;251136,23.6,23,0,334,31;252258,22.3,25,0,334,28;268249,5.7,5,0,334,36;268252,5.1,5,0,334,32;272150,3.8,27,0,321,40,25,6,0,0,0;171853,3.2,86,0,321,131,24,5,0,0,0;272149,2.5,27,0,321,42,25,6,0,0,0|12:252258,35,25,0,334,28;268249,21.7,5,0,334,36;251513,15.3,26,0,331,33;272150,6.4,27,0,321,40,25,6,0,0,0;251136,5.1,23,0,334,31;158366,5.1,23,0,334,30;162544,3.8,28,0,334,37;159459,3.8,24,0,334,27|13:270175,75.8,30,0,344,43;270173,18.5,30,0,344;270164,3.8,36,0,334;250228,1.3,33,0,334;273796,0.6,33,0,334|14:270173,57.3,30,0,344;270175,19.7,30,0,344,43;270165,17.8,31,0,334;270602,3.2,174,0,308,321;270164,1.3,36,0,334;273796,0.6,33,0,334|15:268253,33.1,12,0,344,45;271460,28.7,48,0,344,232;251190,17.8,39,0,334,88|16:268213,58,30,0,344,48;237846,17.8,40,0,331,2;237848,11.5,175,0,331,2",
    ["PRIEST/DISCIPLINE/Voidweaver"] = "1:271555,57.4,139,0,334,223;271874,38.1,116,0,344,177;268242,1.9,102,0,334,178|2:268265,81.9,4,0,344,4;251173,12.3,23,0,334,101;273781,2.6,6,0,334,6|3:271553,89,117,0,334,233;239031,5.2,45,0,321,262;239650,2.6,58,0,331,73|5:271558,89,80,0,334,234;239655,6.5,118,0,331,11;268221,3.2,18,0,334,205|6:239649,36.1,65,0,331,73;268257,20,120,0,334,184;251222,11,41,0,334,82|7:271554,98.1,140,0,334,235;273786,1.3,45,0,321,236;268236,0.6,122,0,334,186|8:251137,23.9,125,0,334,198;268218,19.4,18,0,334,188;159259,18.7,39,0,334,207|9:239648,63.9,123,0,331,46;251127,14.2,41,0,334,190;268228,10.3,3,0,334,191|10:271556,78.1,124,0,344,238;268243,11.6,12,0,344,193;239653,7.1,58,0,331,73|11:252258,26.5,25,0,334,28;273792,19.4,23,0,334,26;159459,11,24,0,334,27;268249,9.7,5,0,334,36;251136,9,23,0,334,31;268252,8.4,5,0,334,32;158366,8.4,23,0,334,30;268266,6.5,5,0,334,29|12:273792,29,23,0,334,26;252258,20.6,25,0,334,28;268252,9,5,0,334,32;268249,8.4,5,0,334,36;159459,7.7,24,0,334,27;251136,6.5,23,0,334,31;268266,5.2,5,0,334,29;268290,3.2,158,0,298,322|13:270162,30.3,36,0,334;270164,26.5,36,0,334;270167,22.6,36,0,334,87;270161,5.2,82,0,334;270169,3.2,30,0,344,114;193757,2.6,33,0,334;273796,2.6,33,0,334;250215,1.9,33,0,334|14:270162,40.6,36,0,334;270167,27.7,36,0,334,87;270164,11,36,0,334;270169,9.7,30,0,344,114;249808,3.9,155,0,298;250255,3.2,33,0,334;264701,0.6,176,0,321,323;274493,0.6,37,0,321,0,25,6,0,0,0|15:251190,29.7,39,0,334,88;239656,17.4,38,0,331,46;251132,12.3,39,0,334,58|16:271092,65.8,30,0,344,62;245770,27.1,40,0,331,11;268203,1.9,70,0,334,90|17:245769,53.6,83,0,331,63;268197,15.5,36,0,334,115;268263,14.5,36,0,334,116",
    ["PRIEST/HOLY/Oracle"] = "1:271555,72.4,139,0,334,223;271874,18.4,116,0,344,177;239652,4.6,177,0,331,2|2:268265,62.5,4,0,344,4;273781,22.4,6,0,334,6;271638,7.2,71,0,334,92|3:271553,86.2,117,0,334,233;239650,5.3,58,0,331,73;239045,3.3,39,0,334,204|5:271558,87.5,80,0,334,234;251139,6.6,119,0,331,182;268221,3.9,18,0,334,205|6:239649,59.2,65,0,331,73;251222,13.8,41,0,334,82;268257,9.9,120,0,334,184|7:271554,92.1,140,0,334,235;251160,3.9,45,0,321,302;268236,3.3,122,0,334,186|8:268218,20.4,18,0,334,188;159243,15.8,39,0,334,197;271435,15.8,113,0,334,187|9:239648,57.9,123,0,331,46;268228,16.4,3,0,334,191;251154,12.5,41,0,334,240|10:271556,86.2,124,0,344,238;159247,5.9,129,0,334,208;268243,5.3,12,0,344,193|11:273792,29.6,23,0,334,26;159459,16.4,24,0,334,27;251148,10.5,23,0,334,34;252258,8.6,25,0,334,28;268252,5.9,5,0,334,32;268266,5.3,5,0,334,29;268249,5.3,5,0,334,36;272147,3.9,27,0,321,35,25,6,0,0,0|12:251148,21.1,23,0,334,34;273792,18.4,23,0,334,26;159459,12.5,24,0,334,27;251136,11.2,23,0,334,31;268266,7.9,5,0,334,29;252258,6.6,25,0,334,28;268249,5.9,5,0,334,36;272147,3.9,27,0,321,35,25,6,0,0,0|13:270162,50,36,0,334;270167,25,36,0,334,87;270164,14.5,36,0,334;250214,3.3,33,0,334;251792,2.6,37,0,321,0,25,6,0,0,0;193757,2,33,0,334;250255,1.3,33,0,334;270171,0.7,104,0,334,158|14:270162,47.4,36,0,334;270164,27,36,0,334;270167,19.7,36,0,334,87;250214,3.3,33,0,334;250255,0.7,33,0,334;270171,0.7,104,0,334,158;270169,0.7,30,0,344,114;249343,0.7,155,0,298,278|15:251190,20.4,39,0,334,88;268248,18.4,18,0,334,170;159288,15.1,39,0,334,202|16:245770,46.7,40,0,331,11;271092,31.6,30,0,344,62;268210,7.2,36,0,334,90|17:245769,55.9,83,0,331,63;268197,20.6,36,0,334,115;268263,11.8,36,0,334,116",
    ["PRIEST/SHADOW/Archon"] = "1:271555,84.8,139,0,334,223;251199,7.6,84,0,321,324;271874,6.3,116,0,344,177|2:268265,86.1,4,0,344,4;251142,8.2,42,0,334,52;251234,2.5,23,0,334,51|3:271553,84.8,117,0,334,233;239045,6.3,39,0,334,204;239031,4.4,45,0,321,262|5:271558,96.2,80,0,334,234;273785,2.5,39,0,334,196;239655,1.3,118,0,331,11|6:239649,37.3,65,0,331,73;193691,19,41,0,334,53;268257,17.7,120,0,334,184|7:271554,72.2,140,0,334,235;239651,19,81,0,331,2;268236,4.4,122,0,334,186|8:271435,26.6,113,0,334,187;251137,19.6,125,0,334,198;268218,13.3,18,0,334,188|9:239648,67.1,123,0,331,46;268228,13.9,3,0,334,191;251127,13.3,41,0,334,190|10:271556,84.8,124,0,344,238;159247,5.7,129,0,334,208;268243,3.8,12,0,344,193|11:273792,31,23,0,334,26;251136,25.9,23,0,334,31;268249,15.2,5,0,334,36;252258,10.8,25,0,334,28;158366,9.5,23,0,334,30;240949,2.5,29,0,331,39;268252,2.5,5,0,334,32;272150,1.3,27,0,321,40,25,6,0,0,0|12:252258,43.7,25,0,334,28;273792,15.2,23,0,334,26;158366,14.6,23,0,334,30;251136,13.9,23,0,334,31;268249,5.7,5,0,334,36;268252,5.1,5,0,334,32;272147,1.3,27,0,321,35,25,6,0,0,0;272149,0.6,27,0,321,42,25,6,0,0,0|13:270164,29.1,36,0,334;270169,23.4,30,0,344,114;273796,22.2,33,0,334;250215,17.7,33,0,334;270167,5.1,36,0,334,87;250214,0.6,33,0,334;249343,0.6,155,0,298,278;250224,0.6,33,0,334|14:270167,28.5,36,0,334,87;270164,23.4,36,0,334;270169,12.7,30,0,344,114;273796,12,33,0,334;250215,12,33,0,334;250214,8.9,33,0,334;248583,1.3,47,0,321,0,24,5,0,0,0;250224,0.6,33,0,334|15:251132,38,39,0,334,58;251190,15.2,39,0,334,88;268253,12.7,12,0,344,45|16:271092,57,30,0,344,62;245770,20.9,40,0,331,11;273778,11.4,128,0,334,203|17:245769,57.5,83,0,331,63;268197,27.5,36,0,334,115;268263,12.5,36,0,334,116",
    ["ROGUE/ASSASSINATION/Fatebound"] = "1:271510,92.7,53,0,344,242;271875,7.3,54,0,344,69|2:268265,90.7,4,0,344,4;273781,3.3,6,0,334,6;251234,2.6,23,0,334,51|3:271508,82.8,7,0,334,243;268246,7.9,18,0,334,72;251223,7.3,39,0,334,102|5:271513,93.4,80,0,334,244;268235,3.3,18,0,334,75;244570,2,58,0,331,11|6:271436,32.5,72,0,334,94;268256,22.5,59,0,344,77;268227,19.9,3,0,334,76|7:271509,94,61,0,344,245;268225,4,12,0,344,105;251130,2,39,0,334,80|8:244569,25.2,63,0,331,73;159327,25.2,39,0,334,81;268261,21.2,18,0,334,18|9:244576,73.5,65,0,331,46;268240,15.9,66,0,334,83;251183,5.3,73,0,324,95|10:271511,78.8,68,0,334,187;244575,11.9,81,0,331,73;159312,9.3,45,0,321,96|11:273792,22.5,23,0,334,26;240949,17.2,29,0,331,39;251136,16.6,23,0,334,31;268252,11.9,5,0,334,32;268249,10.6,5,0,334,36;158366,9.9,23,0,334,30;252258,8.6,25,0,334,28;272150,1.3,27,0,321,40,25,6,0,0,0|12:273792,29.1,23,0,334,26;268252,19.2,5,0,334,32;251136,17.2,23,0,334,31;252258,12.6,25,0,334,28;268249,9.9,5,0,334,36;158366,7.9,23,0,334,30;251194,2,23,0,334,38;240949,1.3,29,0,331,39|13:270175,74.2,30,0,344,43;270165,8.6,31,0,334;270164,7.3,36,0,334;273796,4,33,0,334;270168,4,30,0,344,44;270173,2,30,0,344|14:270165,43,31,0,334;270175,20.5,30,0,344,43;270168,13.2,30,0,344,44;270164,12.6,36,0,334;270173,7.3,30,0,344;270166,2,36,0,334;193701,0.7,138,0,298;250225,0.7,52,0,321|15:193763,37.1,39,0,334,47;251132,29.1,39,0,334,58;268253,16.6,12,0,344,45|16:237837,43,144,0,331,63;271093,31.1,30,0,344,247;268204,14.6,36,0,334,248|17:237837,46.4,144,0,331,63;271093,27.2,30,0,344,247;275070,21.2,145,0,334,249",
    ["ROGUE/OUTLAW/Trickster"] = "1:271510,80.4,53,0,344,242;271875,17.7,54,0,344,69;271438,1.9,14,0,334,91|2:268265,87.3,4,0,344,4;273781,5.1,6,0,334,6;271638,4.4,71,0,334,92|3:271508,93.7,7,0,334,243;251223,5.7,39,0,334,102;273774,0.6,45,0,321,107|5:271513,86.7,80,0,334,244;244570,7,58,0,331,11;251226,6.3,45,0,321,103|6:244573,34.8,135,0,331,73;251189,28.5,75,0,334,214;271436,13.9,72,0,334,94|7:271509,89.9,61,0,344,245;244574,3.8,62,0,331,11;268225,3.2,12,0,344,105|8:244569,45.6,63,0,331,73;251153,31,64,0,334,82;268261,9.5,18,0,334,18|9:244576,60.8,65,0,331,46;268240,17.7,66,0,334,83;251135,12.7,67,0,334,47|10:271511,69,68,0,334,187;244575,15.2,81,0,331,73;251124,7.6,64,0,334,86|11:273792,32.3,23,0,334,26;251148,31,23,0,334,34;268252,13.9,5,0,334,32;268266,7.6,5,0,334,29;272148,7.6,27,0,321,41,25,6,0,0,0;159459,6.3,24,0,334,27;251136,1.3,23,0,334,31|12:251148,27.2,23,0,334,34;273792,25.9,23,0,334,26;268252,21.5,5,0,334,32;240949,14.6,29,0,331,39;251136,3.8,23,0,334,31;268266,3.2,5,0,334,29;158366,3.2,23,0,334,30;159459,0.6,24,0,334,27|13:270175,51.9,30,0,344,43;270173,36.1,30,0,344;250215,8.2,33,0,334;270164,1.9,36,0,334;159617,1.3,33,0,334;270165,0.6,31,0,334|14:270173,32.3,30,0,344;270175,23.4,30,0,344,43;270164,10.8,36,0,334;270165,8.9,31,0,334;250228,8.9,33,0,334;270166,7,36,0,334;159617,5.7,33,0,334;250215,3.2,33,0,334|15:193763,38,39,0,334,47;268248,38,18,0,334,170;251132,11.4,39,0,334,58|16:268209,48.7,49,0,344,60;237839,38.6,51,0,331,63;237841,5.7,178,0,331,63|17:275070,53.8,145,0,334,249;237837,17.1,144,0,331,63;271093,15.2,30,0,344,247",
    ["ROGUE/SUBTLETY/Deathstalker"] = "1:271510,68.6,53,0,344,242;271875,29.5,54,0,344,69;251140,0.6,21,0,321,70|2:268265,83.3,4,0,344,4;251142,7.1,42,0,334,52;268251,4.5,90,0,334,127|3:271508,92.3,7,0,334,243;268246,3.8,18,0,334,72;251223,3.2,39,0,334,102|5:271513,93.6,80,0,334,244;251226,3.2,45,0,321,103;251159,1.9,91,0,321,128|6:271436,31.4,72,0,334,94;268256,26.3,59,0,344,77;251235,10.9,85,0,334,250|7:271509,85.9,61,0,344,245;244574,7.1,62,0,331,11;268225,6.4,12,0,344,105|8:268261,21.8,18,0,334,18;159327,20.5,39,0,334,81;159304,18.6,64,0,334,217|9:244576,87.8,65,0,331,46;251183,6.4,73,0,324,95;268240,3.2,66,0,334,83|10:271511,91.7,68,0,334,187;251124,3.2,64,0,334,86;159337,2.6,39,0,334,130|11:162544,32.7,28,0,334,37;268249,18.6,5,0,334,36;251194,14.1,23,0,334,38;240949,13.5,29,0,331,39;158366,11.5,23,0,334,30;251136,5.1,23,0,334,31;252258,3.2,25,0,334,28;272150,0.6,27,0,321,40,25,6,0,0,0|12:251194,32.7,23,0,334,38;268249,30.8,5,0,334,36;162544,12.2,28,0,334,37;251136,7.1,23,0,334,31;158366,5.8,23,0,334,30;252258,4.5,25,0,334,28;268252,4.5,5,0,334,32;272149,1.3,27,0,321,42,25,6,0,0,0|13:270175,60.3,30,0,344,43;270165,21.2,31,0,334;270164,8.3,36,0,334;270173,7.1,30,0,344;250215,1.9,33,0,334;250214,0.6,33,0,334;250228,0.6,33,0,334|14:270175,37.2,30,0,344,43;270165,22.4,31,0,334;270164,17.9,36,0,334;270173,14.7,30,0,344;250214,5.8,33,0,334;270166,0.6,36,0,334;270168,0.6,30,0,344,44;273797,0.6,34,0,334|15:159288,25.6,39,0,334,202;251132,24.4,39,0,334,58;268253,18.6,12,0,344,45|16:237837,64.7,144,0,331,63;271093,25,30,0,344,247;268264,7.7,36,0,334,325|17:275070,39.7,145,0,334,249;237837,34,144,0,331,63;271093,23.1,30,0,344,247",
    ["SHAMAN/ELEMENTAL/Farseer"] = "1:271483,89.8,146,0,334,3;271441,8.3,94,0,334,136;268230,1.3,93,0,334,135|2:268265,93,4,0,344,4;271638,4.5,71,0,334,92;273781,1.9,6,0,334,6|3:271481,97.5,107,0,344,251;268231,1.9,12,0,344,138;272252,0.6,89,0,321,252,25,6,0,0,0|5:271486,86,96,0,344,253;271876,12.7,97,0,344,120;251233,1.3,45,0,321,173|6:251155,21.7,41,0,334,143;268254,20.4,3,0,334,142;244581,19.7,98,0,331,139|7:271482,73.9,61,0,344,256;244582,12.7,81,0,331,145;159375,11.5,45,0,321,167|8:271440,42.7,113,0,334,168;268258,36.3,18,0,334,147;244577,15.9,81,0,331,139|9:244584,82.2,98,0,331,149;268217,5.7,3,0,334,150;273775,5.1,179,0,315,326|10:271484,86.6,68,0,334,257;193752,5.1,45,0,321,164;268238,4.5,18,0,334,86|11:251136,31.2,23,0,334,31;240949,15.3,29,0,331,39;158366,13.4,23,0,334,30;268249,12.7,5,0,334,36;268252,7.6,5,0,334,32;273792,7.6,23,0,334,26;252258,6.4,25,0,334,28;251513,5.7,26,0,331,33|12:273792,24.8,23,0,334,26;158366,22.3,23,0,334,30;251136,14,23,0,334,31;251513,12.7,26,0,331,33;268266,8.3,5,0,334,29;268252,7.6,5,0,334,32;268249,5.1,5,0,334,36;252258,4.5,25,0,334,28|13:273796,70.7,33,0,334;270164,17.8,36,0,334;250215,8.3,33,0,334;270169,3.2,30,0,344,114|14:270164,80.9,36,0,334;273796,15.3,33,0,334;270169,2.5,30,0,344,114;270167,1.3,36,0,334,87|15:251132,33.1,39,0,334,58;268253,21.7,12,0,344,45;239656,14.6,38,0,331,46|16:245770,42,40,0,331,11;271092,36.3,30,0,344,62;268210,11.5,36,0,334,90|17:268262,50.5,32,0,334,228;268196,20.9,137,0,334,229;268263,16.5,36,0,334,116",
    ["SHAMAN/ENHANCEMENT/Stormbringer"] = "1:271483,97.4,146,0,334,3;271441,2.6,94,0,334,136|2:268265,64.9,4,0,344,4;251234,14.3,23,0,334,51;251142,7.8,42,0,334,52|3:271481,96.8,107,0,344,251;268231,1.9,12,0,344,138;239049,1.3,39,0,334,162|5:271486,77.9,96,0,344,253;271876,19.5,97,0,344,120;251233,1.3,45,0,321,173|6:268254,31.2,3,0,334,142;251228,26,147,0,334,255;244581,20.8,98,0,331,139|7:271482,64.3,61,0,344,256;268237,20.1,12,0,344,146;244582,8.4,81,0,331,145|8:268258,20.1,18,0,334,147;159388,19.5,39,0,334,148;244577,14.9,81,0,331,139|9:244584,87,98,0,331,149;271479,4.5,180,0,321,327;159380,3.2,99,0,328,151|10:271484,96.8,68,0,334,257;244583,1.9,100,0,331,73;268238,0.6,18,0,334,86|11:252258,30.5,25,0,334,28;251136,22.7,23,0,334,31;273792,14.3,23,0,334,26;158366,11,23,0,334,30;240949,7.8,29,0,331,39;272147,6.5,27,0,321,35,25,6,0,0,0;268249,2.6,5,0,334,36;268252,2.6,5,0,334,32|12:252258,33.8,25,0,334,28;273792,29.2,23,0,334,26;251136,11.7,23,0,334,31;158366,11.7,23,0,334,30;268249,3.2,5,0,334,36;251513,3.2,26,0,331,33;272147,2.6,27,0,321,35,25,6,0,0,0;240949,1.9,29,0,331,39|13:270175,35.1,30,0,344,43;273796,24,33,0,334;270173,15.6,30,0,344;270165,13.6,31,0,334;270164,3.9,36,0,334;250225,2.6,52,0,321;250214,2.6,33,0,334;250228,1.3,33,0,334|14:270173,37.7,30,0,344;270175,16.9,30,0,344,43;273796,14.3,33,0,334;270165,12.3,31,0,334;270164,7.1,36,0,334;250215,4.5,33,0,334;250228,3.2,33,0,334;250214,1.3,33,0,334|15:271478,26.6,181,0,334,328;251190,21.4,39,0,334,88;268253,20.1,12,0,344,45|16:268209,61,49,0,344,60;237850,20.1,83,0,331,63;268206,7.1,36,0,334,329|17:237850,73.4,83,0,331,63;251224,9.7,161,0,321,330;268206,6.5,36,0,334,329",
    ["SHAMAN/RESTORATION/Totemic"] = "1:271483,78.9,146,0,334,3;244579,7.2,103,0,331,11;271441,6.6,94,0,334,136|2:268265,80.3,4,0,344,4;273781,7.9,6,0,334,6;268250,5.3,5,0,334,5|3:271481,82.9,107,0,344,251;244580,11.8,81,0,331,139;251184,2.6,45,0,321,258|5:271486,98,96,0,344,253;271876,1.3,97,0,344,120;239046,0.7,45,0,321,259|6:268216,53.3,102,0,334,155;244581,15.1,98,0,331,139;159369,11.2,21,0,321,295|7:271482,79.6,61,0,344,256;193759,6.6,45,0,321,289;244582,5.3,81,0,331,145|8:271440,40.1,113,0,334,168;251125,22.4,125,0,334,260;244577,15.1,81,0,331,139|9:244584,84.9,98,0,331,149;155964,5.9,182,0,321,331;159380,4.6,99,0,328,151|10:271484,82.2,68,0,334,257;244583,10.5,100,0,331,73;268238,4.6,18,0,334,86|11:251148,39.5,23,0,334,34;273792,29.6,23,0,334,26;240949,12.5,29,0,331,39;268252,9.2,5,0,334,32;159459,4.6,24,0,334,27;272148,3.9,27,0,321,41,25,6,0,0,0;251136,0.7,23,0,334,31|12:251148,31.6,23,0,334,34;273792,29.6,23,0,334,26;272148,11.2,27,0,321,41,25,6,0,0,0;159459,7.9,24,0,334,27;240949,7.9,29,0,331,39;268252,5.3,5,0,334,32;268266,4.6,5,0,334,29;279009,0.7,160,0,308,332|13:270162,58.6,36,0,334;250255,32.9,33,0,334;270164,5.3,36,0,334;250254,2.6,33,0,334;270167,0.7,36,0,334,87|14:270162,39.5,36,0,334;250255,32.9,33,0,334;270164,17.1,36,0,334;270167,3.9,36,0,334,87;270171,2.6,104,0,334,158;248583,2,47,0,321,0,24,5,0,0,0;274493,1.3,37,0,321,0,25,6,0,0,0;250246,0.7,138,0,298|15:268248,36.2,18,0,334,170;193763,23,39,0,334,47;239656,14.5,38,0,331,46|16:271092,70.4,30,0,344,62;268210,10.5,36,0,334,90;245770,7.2,40,0,331,11|17:237831,52.5,38,0,331,63;251196,22.7,33,0,334,333;268196,16.3,137,0,334,229",
    ["WARLOCK/AFFLICTION/Hellcaller"] = "1:271546,71.6,148,0,344,261;271874,12.9,116,0,344,177;268242,7.7,102,0,334,178|2:268265,72.3,4,0,344,4;273781,13.5,6,0,334,6;251173,12.3,23,0,334,101|3:271544,77.4,117,0,334,7;239031,16.8,45,0,321,262;239045,2.6,39,0,334,204|5:271549,98.7,80,0,334,263;239032,0.6,183,0,324,334;273785,0.6,39,0,334,196|6:239649,32.9,65,0,331,73;251222,21.3,41,0,334,82;268232,19.4,20,0,334,183|7:271545,94.2,140,0,334,263;273786,3.9,45,0,321,236;193750,1.3,45,0,321,335|8:251219,36.1,64,0,334,237;159259,23.9,39,0,334,207;271548,16.8,48,0,344,264|9:239648,80,123,0,331,46;251127,9,41,0,334,190;268228,5.2,3,0,334,191|10:271547,96.1,124,0,344,193;273773,2.6,130,0,334,209;159247,0.6,129,0,334,208|11:273792,42.6,23,0,334,26;252258,17.4,25,0,334,28;268266,12.9,5,0,334,29;240949,6.5,29,0,331,39;272147,5.2,27,0,321,35,25,6,0,0,0;251136,5.2,23,0,334,31;158366,4.5,23,0,334,30;268252,1.9,5,0,334,32|12:273792,36.1,23,0,334,26;252258,15.5,25,0,334,28;251136,12.3,23,0,334,31;158366,9.7,23,0,334,30;268266,8.4,5,0,334,29;251148,7.1,23,0,334,34;268252,6.5,5,0,334,32;272148,2.6,27,0,321,41,25,6,0,0,0|13:273796,64.5,33,0,334;270164,12.9,36,0,334;273649,9.7,33,0,334;250215,5.2,33,0,334;270167,3.2,36,0,334,87;250224,3.2,33,0,334;274493,0.6,37,0,321,0,25,6,0,0,0;270168,0.6,30,0,344,44|14:270164,38.1,36,0,334;270167,32.3,36,0,334,87;273796,12.9,33,0,334;250224,10.3,33,0,334;273649,2.6,33,0,334;250215,1.9,33,0,334;246305,0.6,26,0,331;270168,0.6,30,0,344,44|15:193763,45.2,39,0,334,47;239656,23.2,38,0,331,46;268248,9.7,18,0,334,170|16:245770,32.3,40,0,331,11;271092,32.3,30,0,344,62;273778,15.5,128,0,334,203|17:245769,65,83,0,331,63;273779,18.4,33,0,334,310;268263,15.5,36,0,334,116",
    ["WARLOCK/DEMONOLOGY/Diabolist"] = "1:271546,95.3,148,0,344,261;271874,4.7,116,0,344,177|2:268265,80.4,4,0,344,4;271638,7.4,71,0,334,92;273781,6.1,6,0,334,6|3:271544,95.9,117,0,334,7;271434,2,8,0,334,239;268241,0.7,18,0,334,180|5:271549,86.5,80,0,334,263;239655,12.2,118,0,331,11;239032,1.4,183,0,324,334|6:268232,26.4,20,0,334,183;239649,20.9,65,0,331,73;251185,16.2,85,0,334,308|7:271545,76.4,140,0,334,263;239651,9.5,81,0,331,2;268236,8.1,122,0,334,186|8:271435,29.7,113,0,334,187;271548,20.9,48,0,344,264;268255,19.6,12,0,344,189|9:239648,54.1,123,0,331,46;268228,33.1,3,0,334,191;271542,6.8,184,0,334,336|10:271547,93.9,124,0,344,193;273773,2.7,130,0,334,209;159247,1.4,129,0,334,208|11:273792,29.1,23,0,334,26;251136,27,23,0,334,31;268252,18.9,5,0,334,32;240949,12.8,29,0,331,39;158366,5.4,23,0,334,30;268249,2.7,5,0,334,36;252258,1.4,25,0,334,28;162544,1.4,28,0,334,37|12:268252,37.8,5,0,334,32;273792,25,23,0,334,26;251136,18.9,23,0,334,31;158366,8.8,23,0,334,30;268249,4.7,5,0,334,36;268266,2,5,0,334,29;252258,2,25,0,334,28;251513,0.7,26,0,331,33|13:273796,56.1,33,0,334;270169,15.5,30,0,344,114;270164,14.9,36,0,334;273649,8.8,33,0,334;270167,3.4,36,0,334,87;250215,1.4,33,0,334|14:270164,68.2,36,0,334;273796,10.1,33,0,334;270167,9.5,36,0,334,87;250215,6.1,33,0,334;270169,3.4,30,0,344,114;273794,2.7,33,0,334|15:239656,22.3,38,0,331,46;251132,18.9,39,0,334,58;271541,15.5,48,0,344,337|16:245770,43.2,40,0,331,11;271092,32.4,30,0,344,62;268205,15.5,36,0,334,221|17:245769,91.8,83,0,331,63;268263,4.9,36,0,334,116;273779,3.3,33,0,334,310",
    ["WARLOCK/DESTRUCTION/Hellcaller"] = "1:271546,89.9,148,0,344,261;271874,7.4,116,0,344,177;251232,1.4,41,0,334,195|2:268265,68.2,4,0,344,4;251173,12.2,23,0,334,101;273781,8.1,6,0,334,6|3:271544,75.7,117,0,334,7;251227,11.5,39,0,334,338;239045,5.4,39,0,334,204|5:271549,94.6,80,0,334,263;251147,4.1,39,0,334,339;268221,0.7,18,0,334,205|6:239649,48,65,0,331,73;251222,14.9,41,0,334,82;271543,11.5,112,0,334,9|7:271545,97.3,140,0,334,263;273786,0.7,45,0,321,236;251160,0.7,45,0,321,302|8:251219,23,64,0,334,237;251137,20.9,125,0,334,198;268218,18.2,18,0,334,188|9:239648,53.4,123,0,331,46;156168,16.9,159,0,321,340;251127,10.8,41,0,334,190|10:271547,76.4,124,0,344,193;268243,11.5,12,0,344,193;256980,4.7,185,0,295,341|11:273792,31.8,23,0,334,26;251136,27,23,0,334,31;252258,12.2,25,0,334,28;158366,10.8,23,0,334,30;162544,5.4,28,0,334,37;251148,3.4,23,0,334,34;159459,3.4,24,0,334,27;268249,2.7,5,0,334,36|12:273792,27.7,23,0,334,26;251136,27,23,0,334,31;240949,10.1,29,0,331,39;158366,6.8,23,0,334,30;268249,6.8,5,0,334,36;268252,6.1,5,0,334,32;272148,4.7,27,0,321,41,25,6,0,0,0;252258,4.1,25,0,334,28|13:250215,44.6,33,0,334;270164,29.7,36,0,334;250224,8.1,33,0,334;270167,6.8,36,0,334,87;273796,4.1,33,0,334;250214,2.7,33,0,334;270168,2,30,0,344,44;246305,1.4,26,0,331|14:250215,37.8,33,0,334;270164,19.6,36,0,334;270168,8.1,30,0,344,44;273796,7.4,33,0,334;250224,7.4,33,0,334;250214,6.8,33,0,334;270167,6.1,36,0,334,87;270169,3.4,30,0,344,114|15:239656,26.4,38,0,331,46;271541,18.2,48,0,344,337;159288,17.6,39,0,334,202|16:245770,54.1,40,0,331,11;271092,25,30,0,344,62;273778,9.5,128,0,334,203|17:245769,66.7,83,0,331,63;268263,14,36,0,334,116;273779,12.3,33,0,334,310",
    ["WARRIOR/ARMS/Slayer"] = "1:271456,92.4,149,0,334,91;237832,7,2,0,331,2;251229,0.6,41,0,334,64|2:268265,86.1,4,0,344,4;273781,5.7,6,0,334,6;251173,4.4,23,0,334,101|3:271454,89.9,7,0,334,257;271444,5.7,8,0,334,8;237835,1.9,29,0,331,19|5:271459,97.5,10,0,344,10;268222,2.5,12,0,344,12|6:271445,47.5,14,0,334,15;268259,26.6,13,0,344,13;271453,18.4,60,0,344,265|7:271455,89.2,15,0,344,266;271878,8.2,16,0,344,16;268224,1.9,17,0,334,17|8:237828,54.4,19,0,331,19;268245,29.1,18,0,334,18;271458,7.6,186,0,334,342|9:237834,73.4,2,0,331,21;268239,15.2,20,0,334,22;251133,5.7,21,0,321,23|10:271457,81,109,0,334,208;237836,17.7,19,0,331,19;251214,0.6,150,0,331,268|11:268252,31.6,5,0,334,32;273792,22.8,23,0,334,26;252258,13.9,25,0,334,28;268249,9.5,5,0,334,36;251136,7.6,23,0,334,31;251513,5.1,26,0,331,33;240949,5.1,29,0,331,39;158366,4.4,23,0,334,30|12:252258,40.5,25,0,334,28;273792,19.6,23,0,334,26;240949,12,29,0,331,39;158366,10.1,23,0,334,30;251513,7.6,26,0,331,33;251136,5.1,23,0,334,31;268252,2.5,5,0,334,32;268249,2.5,5,0,334,36|13:270165,41.8,31,0,334;270173,33.5,30,0,344;270175,14.6,30,0,344,43;265657,5.1,37,0,321,0,25,6,0,0,0;270164,4.4,36,0,334;273796,0.6,33,0,334|14:270173,35.4,30,0,344;270165,35.4,31,0,334;270175,14.6,30,0,344,43;270164,12.7,36,0,334;274493,0.6,37,0,321,0,25,6,0,0,0;250228,0.6,33,0,334;273796,0.6,33,0,334|15:268253,28.5,12,0,344,45;251132,25.3,39,0,334,58;193763,17.7,39,0,334,47|16:268213,67.1,30,0,344,48;237846,18.4,40,0,331,2;268214,10.8,36,0,334,49",
    ["WARRIOR/FURY/Slayer"] = "1:271456,98.1,149,0,334,91;268229,1.3,3,0,334,3;239050,0.6,84,0,321,269|2:251142,46.5,42,0,334,52;268265,41.3,4,0,344,4;251173,3.9,23,0,334,101|3:271454,95.5,7,0,334,257;251138,1.9,39,0,334,53;237835,1.9,29,0,331,19|5:271459,94.8,10,0,344,10;268222,3.9,12,0,344,12;193753,1.3,45,0,321,128|6:268259,36.8,13,0,344,13;251144,16.1,21,0,321,343;271453,12.3,60,0,344,265|7:271455,87.7,15,0,344,266;268224,5.8,17,0,334,17;271878,3.9,16,0,344,16|8:237828,67.1,19,0,331,19;268260,12.3,18,0,334,20;271458,8.4,186,0,334,342|9:237834,87.1,2,0,331,21;251133,6.5,21,0,321,23;268239,3.2,20,0,334,22|10:271457,74.8,109,0,334,208;159413,5.8,45,0,321,56;237836,5.8,19,0,331,19|11:252258,35.5,25,0,334,28;158366,14.8,23,0,334,30;273792,9.7,23,0,334,26;268249,9,5,0,334,36;272147,5.8,27,0,321,35,25,6,0,0,0;240949,5.2,29,0,331,39;162544,5.2,28,0,334,37;251136,3.9,23,0,334,31|12:252258,49.7,25,0,334,28;251194,11,23,0,334,38;273792,9.7,23,0,334,26;158366,9.7,23,0,334,30;240949,5.2,29,0,331,39;162544,4.5,28,0,334,37;268249,1.9,5,0,334,36;272149,1.9,27,0,321,42,25,6,0,0,0|13:270173,41.9,30,0,344;270175,35.5,30,0,344,43;270165,9.7,31,0,334;273796,5.8,33,0,334;270164,5.2,36,0,334;249342,1.3,155,0,298;270163,0.6,32,0,334|14:270173,35.5,30,0,344;270165,24.5,31,0,334;270164,11.6,36,0,334;270175,9,30,0,344,43;249343,6.5,155,0,298,278;273796,5.2,33,0,334;250228,3.2,33,0,334;270163,2.6,32,0,334|15:251190,47.1,39,0,334,88;268253,26.5,12,0,344,45;271451,9.7,48,0,344,267|16:268213,55.5,30,0,344,48;273782,19.4,145,0,334,344;237846,18.1,40,0,331,2|17:268214,41.9,36,0,334,49;237846,34.2,40,0,331,2;268213,11,30,0,344,48",
    ["WARRIOR/PROTECTION/Mountain Thane"] = "1:271456,85.2,149,0,334,91;239050,7.7,84,0,321,269;251229,4.5,41,0,334,64|2:268265,58.7,4,0,344,4;251173,16.8,23,0,334,101;251234,11,23,0,334,51|3:271454,90.3,7,0,334,257;271444,3.9,8,0,334,8;237835,3.2,29,0,331,19|5:271459,85.8,10,0,344,10;251193,11.6,45,0,321,270;268222,1.9,12,0,344,12|6:159418,25.2,41,0,334,53;268244,21.9,3,0,334,14;271453,12.9,60,0,344,265|7:271455,89.7,15,0,344,266;271878,4.5,16,0,344,16;251182,2.6,45,0,321,318|8:237828,47.7,19,0,331,19;272256,12.9,187,0,321,345;273777,11.6,39,0,334,230|9:237834,85.2,2,0,331,21;251133,4.5,21,0,321,23;268239,3.9,20,0,334,22|10:271457,69,109,0,334,208;251214,13.5,150,0,331,268;159413,10.3,45,0,321,56|11:252258,40,25,0,334,28;273792,17.4,23,0,334,26;159459,14.2,24,0,334,27;251148,11,23,0,334,34;240949,7.7,29,0,331,39;268252,3.2,5,0,334,32;272147,1.9,27,0,321,35,25,6,0,0,0;272150,1.3,27,0,321,40,25,6,0,0,0|12:159459,38.7,24,0,334,27;273792,19.4,23,0,334,26;252258,12.3,25,0,334,28;240949,9.7,29,0,331,39;251148,6.5,23,0,334,34;158366,5.2,23,0,334,30;251136,3.2,23,0,334,31;268266,1.9,5,0,334,29|13:270175,27.1,30,0,344,43;270173,20,30,0,344;270165,16.1,31,0,334;270164,6.5,36,0,334;270174,5.8,77,0,334,108;249342,5.8,155,0,298;250245,3.9,35,0,334;250228,3.2,33,0,334|14:270175,14.8,30,0,344,43;270164,14.8,36,0,334;270173,13.5,30,0,344;270160,12.3,31,0,334;270165,9,31,0,334;250245,7.7,35,0,334;250228,7.1,33,0,334;270174,6.5,77,0,334,108|15:193763,31.6,39,0,334,47;251190,15.5,39,0,334,88;268253,14.8,12,0,344,45|16:268202,55.5,50,0,344,62;237839,16.8,51,0,331,63;268209,12.9,49,0,344,60|17:237831,42.9,38,0,331,63;251150,22.7,33,0,334,346;268196,18.8,137,0,334,229",
}

-- 催化继承特效版本：完整实例链无法从 WCL 重建，界面改为明确展示真实坯子。
BisData.tierVariants = {
    ["DEATHKNIGHT/BLOOD/San'layn"] = {
        raid = {
            [271473] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
        mplus = {
            [271473] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
    },
    ["DEATHKNIGHT/FROST/Deathbringer"] = {
        raid = {
            [271473] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
        mplus = {
            [271473] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
    },
    ["DEATHKNIGHT/UNHOLY/San'layn"] = {
        raid = {
            [271473] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
        mplus = {
            [271473] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
    },
    ["HUNTER/BEASTMASTERY/Pack Leader"] = {
        raid = {
            [271495] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271495] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["HUNTER/MARKSMANSHIP/Sentinel"] = {
        raid = {
            [271495] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271495] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["HUNTER/SURVIVAL/Sentinel"] = {
        raid = {
            [271495] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271495] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["MAGE/ARCANE/Sunfury"] = {
        raid = {
            [271564] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271564] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["MAGE/FIRE/Sunfury"] = {
        raid = {
            [271564] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271564] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["MAGE/FROST/Spellslinger"] = {
        raid = {
            [271564] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271564] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["PALADIN/HOLY/Herald of the Sun"] = {
        raid = {
            [271464] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
        mplus = {
            [271464] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
    },
    ["PALADIN/PROTECTION/Lightsmith"] = {
        raid = {
            [271464] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
        mplus = {
            [271464] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
    },
    ["PALADIN/RETRIBUTION/Herald of the Sun"] = {
        raid = {
            [271464] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
        mplus = {
            [271464] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
    },
    ["PRIEST/DISCIPLINE/Voidweaver"] = {
        raid = {
            [271555] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271555] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["PRIEST/HOLY/Oracle"] = {
        raid = {
            [271555] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271555] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["PRIEST/SHADOW/Archon"] = {
        raid = {
            [271555] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271555] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["SHAMAN/ELEMENTAL/Farseer"] = {
        raid = {
            [271486] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271486] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["SHAMAN/ENHANCEMENT/Stormbringer"] = {
        raid = {
            [271486] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271486] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["SHAMAN/RESTORATION/Totemic"] = {
        raid = {
            [271486] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271486] = {
                itemId = 271876,
                name = "觉醒恐牙胸甲",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["WARLOCK/AFFLICTION/Hellcaller"] = {
        raid = {
            [271546] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271546] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["WARLOCK/DEMONOLOGY/Diabolist"] = {
        raid = {
            [271546] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271546] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["WARLOCK/DESTRUCTION/Hellcaller"] = {
        raid = {
            [271546] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
        mplus = {
            [271546] = {
                itemId = 271874,
                name = "守毒者的骇人兜帽",
                stat = "mastery",
                effect = "毒咒",
            },
        },
    },
    ["WARRIOR/ARMS/Slayer"] = {
        raid = {
            [271455] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
        mplus = {
            [271455] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
    },
    ["WARRIOR/FURY/Slayer"] = {
        raid = {
            [271455] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
        mplus = {
            [271455] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
    },
    ["WARRIOR/PROTECTION/Mountain Thane"] = {
        raid = {
            [271455] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
        mplus = {
            [271455] = {
                itemId = 271878,
                name = "无羁深仇腿甲",
                stat = "crit",
                effect = "毒咒",
            },
        },
    },
}

BisData.specs = {
    ["DEATHKNIGHT/BLOOD/San'layn"] = {
        className = "DEATHKNIGHT",
        specName = "BLOOD",
        heroTalent = "San'layn",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { strength = 1, crit = 0.9, haste = 0.5, mastery = 0.7, versatility = 0.4 },
        targetStatPercents = { crit = 33.6, haste = 37.7, mastery = 17.3, versatility = 11.3 },
        targetStatPercentsMplus = { crit = 29.6, haste = 33.9, mastery = 13.8, versatility = 22.6 },
        targetStatPercentsMplusFarm = { crit = 32.3, haste = 34.5, mastery = 15.7, versatility = 17.4 },
        _pb = "1:271474,87.4,1,0,334,1;237832,5.2,2,0,331,2;268229,4.8,3,0,334,3|2:268265,67.5,4,0,344,4;268250,11.6,5,0,334,5;273781,9.1,6,0,334,6|3:271472,89.1,7,0,334,7;271444,2.6,8,0,334,8;268226,2.6,9,0,334,9|5:271477,87.6,10,0,344,10;237829,4.4,11,0,331,11;268222,3.6,12,0,344,12|6:268259,26.9,13,0,344,13;268244,26.9,3,0,334,14;271445,12.8,14,0,334,15|7:271473,76.6,15,0,344,10;271878,19.2,16,0,344,16;268224,2.4,17,0,334,17|8:268245,25.9,18,0,334,18;237828,21.2,19,0,331,19;268260,15.6,18,0,334,20|9:237834,74.5,2,0,331,21;268239,11,20,0,334,22;251133,6.1,21,0,321,23|10:271475,84.4,22,0,334,24;237836,5.5,19,0,331,19;268220,2.6,18,0,334,25|11:273792,19.5,23,0,334,26;159459,14.4,24,0,334,27;252258,14,25,0,334,28;268266,11.4,5,0,334,29;158366,6,23,0,334,30;251136,3.8,23,0,334,31;268252,2.9,5,0,334,32;251513,2.6,26,0,331,33;251148,2.2,23,0,334,34;272147,1.4,27,0,321,35;268249,1.1,5,0,334,36;162544,0.9,28,0,334,37;251194,0.9,23,0,334,38|12:240949,20.1,29,0,331,39;252258,16.9,25,0,334,28;268266,11.9,5,0,334,29;159459,9.8,24,0,334,27;251148,4,23,0,334,34;251136,3.4,23,0,334,31;158366,3.1,23,0,334,30;268252,2.8,5,0,334,32;272147,2.6,27,0,321,35;162544,2.5,28,0,334,37;251513,2,26,0,331,33;268249,1.2,5,0,334,36;251194,1.1,23,0,334,38;272150,1,27,0,321,40;272148,0.8,27,0,321,41;272149,0.6,27,0,321,42|13:270175,58.9,30,0,344,43;270165,4,31,0,334;270163,3.6,32,0,334;270168,1,30,0,344,44;250228,0.6,33,0,334;273797,0.5,34,0,334|14:270173,46.1,30,0,344;250245,7.6,35,0,334;270165,7,31,0,334;270163,3.2,32,0,334;270168,2,30,0,344,44;270164,1.4,36,0,334;274493,0.6,37,0,321|15:268253,18.8,12,0,344,45;239656,17.2,38,0,331,46;193763,12,39,0,334,47|16:268213,55.4,30,0,344,48;237846,24.9,40,0,331,2;268214,8.1,36,0,334,49",
        gems = {
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 20.7 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 20 },
            { id = 240894, nameCn = "无瑕万能榄石", usagePct = 15.6 },
        },
        enchants = {
            [1] = {
                { id = 7991, nameCn = "强化加速祝福", icon = "ui_profession_enchanting", usagePct = 67.6 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 24 },
            },
            [3] = {
                { id = 7973, nameCn = "埃基尔松的迅捷", icon = "ui_profession_enchanting", usagePct = 69.7 },
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 21.7 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 95.9 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 94.2 },
            },
            [8] = {
                { id = 8019, nameCn = "远行者的狩猎", icon = "ui_profession_enchanting", usagePct = 71.2 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 20.4 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 61 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 21 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 61 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 21 },
            },
            [16] = {
                { id = 6241, nameCn = "鲜红符文", usagePct = 98.9 },
            },
        },
    },
    ["DEATHKNIGHT/FROST/Deathbringer"] = {
        className = "DEATHKNIGHT",
        specName = "FROST",
        heroTalent = "Deathbringer",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { strength = 1, crit = 0.9, haste = 0.4, mastery = 0.8, versatility = 0.3 },
        targetStatPercents = { crit = 44, haste = 16.8, mastery = 37, versatility = 2.2 },
        targetStatPercentsMplus = { crit = 44.7, haste = 13.2, mastery = 37.4, versatility = 4.7 },
        targetStatPercentsMplusFarm = { crit = 44.9, haste = 17.2, mastery = 35, versatility = 2.9 },
        _pb = "1:271474,91.6,1,0,334,1;268229,3.4,3,0,334,3;251126,2.3,41,0,334,50|2:268265,85.1,4,0,344,4;251234,4.1,23,0,334,51;251142,3.7,42,0,334,52|3:271472,83.1,7,0,334,7;268226,7.8,9,0,334,9;251138,4.3,39,0,334,53|5:271477,92.8,10,0,344,10;268222,1.8,12,0,344,12;237829,1.3,11,0,331,11|6:268259,39.8,13,0,344,13;271471,22,43,0,344,54;159418,15.1,41,0,334,53|7:271473,74.3,15,0,344,10;271878,23.4,16,0,344,16;268224,0.6,17,0,334,17|8:237828,43,19,0,331,19;268260,22,18,0,334,20;268245,16.9,18,0,334,18|9:237834,65.6,2,0,331,21;268239,19.9,20,0,334,22;271470,3.8,44,0,334,55|10:271475,94.5,22,0,334,24;159413,1.8,45,0,321,56;268220,1.6,18,0,334,25|11:158366,16.5,23,0,334,30;268249,12.4,5,0,334,36;252258,10.8,25,0,334,28;272149,3.7,27,0,321,42;273792,3.7,23,0,334,26;268252,2.7,5,0,334,32;272150,2.1,27,0,321,40;240949,2,29,0,331,39;275526,0.9,46,0,321,57;272147,0.9,27,0,321,35|12:251513,28.1,26,0,331,33;251136,19.9,23,0,334,31;268249,13.8,5,0,334,36;252258,7.1,25,0,334,28;272149,4.5,27,0,321,42;240949,3.3,29,0,331,39;272150,2.7,27,0,321,40;273792,1.4,23,0,334,26;268252,1.3,5,0,334,32;272147,1.3,27,0,321,35|13:270175,66.5,30,0,344,43;270164,1.6,36,0,334;250228,0.7,33,0,334;274493,0.6,37,0,321;270163,0.1,32,0,334;273797,0,34,0,334|14:270173,36.6,30,0,344;270165,22.4,31,0,334;250228,2.3,33,0,334;270164,1.6,36,0,334;265657,0.9,37,0,321;274493,0.9,37,0,321;248583,0.9,47,0,321;270163,0.9,32,0,334;251792,0.6,37,0,321|15:251132,30.1,39,0,334,58;271469,20.6,48,0,344,59;268253,20,12,0,344,45|16:268209,36.6,49,0,344,60;268208,27.8,32,0,334,61;268202,14.8,50,0,344,62|17:268202,71.8,50,0,344,62;268208,12.5,32,0,334,61;237839,10,51,0,331,63",
        gems = {
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 22.1 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 19.5 },
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 18.3 },
        },
        enchants = {
            [1] = {
                { id = 7991, nameCn = "强化加速祝福", icon = "ui_profession_enchanting", usagePct = 44.4 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 40.4 },
            },
            [3] = {
                { id = 7973, nameCn = "埃基尔松的迅捷", icon = "ui_profession_enchanting", usagePct = 45.9 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 42.4 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.4 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 98.6 },
            },
            [8] = {
                { id = 8019, nameCn = "远行者的狩猎", icon = "ui_profession_enchanting", usagePct = 48.8 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 40.7 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 98.6 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 98.6 },
            },
            [16] = {
                { id = 3368, nameCn = "堕落十字军符文", usagePct = 72.1 },
                { id = 3847, nameCn = "石像鬼石肤符文", usagePct = 27.4 },
            },
            [17] = {
                { id = 3847, nameCn = "石像鬼石肤符文", usagePct = 70.8 },
                { id = 3368, nameCn = "堕落十字军符文", usagePct = 29 },
            },
        },
    },
    ["DEATHKNIGHT/UNHOLY/San'layn"] = {
        className = "DEATHKNIGHT",
        specName = "UNHOLY",
        heroTalent = "San'layn",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { strength = 1, crit = 0.9, haste = 0.4, mastery = 0.7, versatility = 0.3 },
        targetStatPercents = { crit = 45.2, haste = 14.4, mastery = 37.8, versatility = 2.7 },
        targetStatPercentsMplus = { crit = 42.6, haste = 16.6, mastery = 37.5, versatility = 3.3 },
        targetStatPercentsMplusFarm = { crit = 43.9, haste = 15.3, mastery = 36.4, versatility = 4.5 },
        _pb = "1:271474,94.3,1,0,334,1;268229,3.1,3,0,334,3;251229,1.1,41,0,334,64|2:268265,82.5,4,0,344,4;251234,8.1,23,0,334,51;251142,2.8,42,0,334,52|3:271472,80.9,7,0,334,7;268226,9.5,9,0,334,9;251138,4,39,0,334,53|5:271477,92,10,0,344,10;268222,4.7,12,0,344,12;239036,1.7,45,0,321,65|6:268259,47.8,13,0,344,13;271471,18.5,43,0,344,54;159418,13.6,41,0,334,53|7:271473,69.5,15,0,344,10;271878,29.2,16,0,344,16;268224,0.9,17,0,334,17|8:237828,67.7,19,0,331,19;268260,14.7,18,0,334,20;268245,8.6,18,0,334,18|9:237834,78.7,2,0,331,21;268239,11.2,20,0,334,22;251133,3.2,21,0,321,23|10:271475,91.4,22,0,334,24;159413,2,45,0,321,56;268220,1.5,18,0,334,25|11:251136,21.6,23,0,334,31;252258,15.9,25,0,334,28;268249,14.1,5,0,334,36;251513,9,26,0,331,33;273792,5.2,23,0,334,26;240949,4.3,29,0,331,39;272149,4.3,27,0,321,42;268252,2.9,5,0,334,32;272150,2.8,27,0,321,40;272147,2.5,27,0,321,35;275526,0.5,46,0,321,57|12:158366,19.1,23,0,334,30;268249,14.4,5,0,334,36;251513,6.7,26,0,331,33;240949,5.7,29,0,331,39;272150,5.4,27,0,321,40;273792,5.1,23,0,334,26;272149,4.1,27,0,321,42;268252,2.3,5,0,334,32;272147,1.4,27,0,321,35|13:270175,66.3,30,0,344,43;270164,2.1,36,0,334;250228,0.9,33,0,334;270163,0.6,32,0,334|14:270173,47.8,30,0,344;270165,10.3,31,0,334;270164,3.4,36,0,334;250228,1.5,33,0,334;274493,1.4,37,0,321;265657,1.2,37,0,321;248583,0.8,47,0,321;270163,0.6,32,0,334;250229,0.5,52,0,321,66|15:251132,28.8,39,0,334,58;268253,28.2,12,0,344,45;271469,17.2,48,0,344,59|16:268213,54.2,30,0,344,48;237846,25.9,40,0,331,2;268198,8.7,36,0,334,67",
        gems = {
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 27.9 },
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 24.8 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 19.8 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 48.9 },
                { id = 7991, nameCn = "强化加速祝福", icon = "ui_profession_enchanting", usagePct = 36.6 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 50.3 },
                { id = 7973, nameCn = "埃基尔松的迅捷", icon = "ui_profession_enchanting", usagePct = 36.2 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 98.2 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 97.8 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 47.5 },
                { id = 8019, nameCn = "远行者的狩猎", icon = "ui_profession_enchanting", usagePct = 42.6 },
            },
            [10] = {
                { id = 5447, usagePct = 66.7 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 96.9 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 96.9 },
            },
            [16] = {
                { id = 6245, nameCn = "天启符文", usagePct = 99.5 },
            },
        },
    },
    ["DEMONHUNTER/DEVAURER/Void-Scarred"] = {
        className = "DEMONHUNTER",
        specName = "DEVAURER",
        heroTalent = "Void-Scarred",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.7, mastery = 0.9, versatility = 0.5 },
        targetStatPercents = { crit = 32.9, haste = 29.2, mastery = 35.1, versatility = 2.8 },
        targetStatPercentsMplus = { crit = 26.3, haste = 31, mastery = 39, versatility = 3.8 },
        targetStatPercentsMplusFarm = { crit = 26.2, haste = 30, mastery = 39.9, versatility = 3.9 },
        _pb = "1:271537,86.5,53,0,344,68;271875,12.7,54,0,344,69;251140,0.3,21,0,321,70|2:268265,85.9,4,0,344,4;251142,4.9,42,0,334,52;251234,2.4,23,0,334,51|3:271535,84.9,55,0,334,71;268246,9.6,18,0,334,72;244572,2,56,0,331,73|5:271540,91,57,0,334,74;244570,4.2,58,0,331,11;268235,1.5,18,0,334,75|6:268227,34.2,3,0,334,76;268256,20.6,59,0,344,77;271534,11.5,60,0,344,78|7:271536,88.5,61,0,344,79;251130,3.7,39,0,334,80;244574,3.5,62,0,331,11|8:244569,62.5,63,0,331,73;159327,14.9,39,0,334,81;251153,8.7,64,0,334,82|9:244576,60.6,65,0,331,46;268240,13.7,66,0,334,83;251135,10.6,67,0,334,47|10:271538,90.1,68,0,334,84;268234,4.5,18,0,334,85;251124,3.2,64,0,334,86|11:268249,18.5,5,0,334,36;252258,13.9,25,0,334,28;240949,6.5,29,0,331,39;273792,6.1,23,0,334,26;272149,4.6,27,0,321,42;268252,3.9,5,0,334,32;272150,1.7,27,0,321,40;272147,0.7,27,0,321,35|12:251136,27.5,23,0,334,31;158366,19.4,23,0,334,30;252258,14.2,25,0,334,28;240949,6.1,29,0,331,39;273792,5.8,23,0,334,26;268252,3.8,5,0,334,32;272149,2.8,27,0,321,42;162544,1,28,0,334,37;272150,1,27,0,321,40|13:250215,53.5,33,0,334;273796,1,33,0,334;270168,0.6,30,0,344,44;250214,0.6,33,0,334|14:270164,38.2,36,0,334;270167,31.3,36,0,334,87;250214,1,33,0,334;273796,0.7,33,0,334;250224,0.6,33,0,334;248583,0.6,47,0,321|15:251132,35.1,39,0,334,58;251190,16.1,39,0,334,88;268253,14.1,12,0,344,45|16:271092,56.3,30,0,344,62;237840,28.3,69,0,331,89;268203,7.7,70,0,334,90|17:237840,59.7,69,0,331,89;271092,12.8,30,0,344,62;268203,8.9,70,0,334,90",
        gems = {
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 23.9 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 17.7 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 17.4 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 88.1 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 88.3 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.8 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 97.2 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 89.2 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 98.7 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 98.7 },
            },
            [16] = {
                { id = 8689, usagePct = 67.7 },
                { id = 8041, nameCn = "奥术精通", icon = "ui_profession_enchanting", usagePct = 26.3 },
            },
            [17] = {
                { id = 8689, usagePct = 68.6 },
                { id = 8041, nameCn = "奥术精通", icon = "ui_profession_enchanting", usagePct = 25.1 },
            },
        },
    },
    ["DEMONHUNTER/HAVOC/Fel-Scarred"] = {
        className = "DEMONHUNTER",
        specName = "HAVOC",
        heroTalent = "Fel-Scarred",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.4, mastery = 0.9, versatility = 0.4 },
        targetStatPercents = { crit = 51, haste = 8.5, mastery = 37.1, versatility = 3.4 },
        targetStatPercentsMplus = { crit = 53.6, haste = 7.4, mastery = 35.8, versatility = 3.1 },
        targetStatPercentsMplusFarm = { crit = 50.7, haste = 9, mastery = 37.2, versatility = 3.1 },
        _pb = "1:271537,89.2,53,0,344,68;271875,5.3,54,0,344,69;271438,1.8,14,0,334,91|2:268265,61.2,4,0,344,4;251234,30.4,23,0,334,51;271638,5.3,71,0,334,92|3:271535,87.5,55,0,334,71;268246,8,18,0,334,72;244572,1.9,56,0,331,73|5:271540,67.8,57,0,334,74;244570,25.1,58,0,331,11;239048,2.8,45,0,321,93|6:268227,39.1,3,0,334,76;268256,19.2,59,0,344,77;271436,15,72,0,334,94|7:271536,90.3,61,0,344,79;251130,4.2,39,0,334,80;244574,3.8,62,0,331,11|8:244569,42.7,63,0,331,73;159327,29.5,39,0,334,81;268261,12.8,18,0,334,18|9:244576,66,65,0,331,46;268240,10.2,66,0,334,83;251183,8.3,73,0,324,95|10:271538,96.9,68,0,334,84;268234,1.8,18,0,334,85;159312,0.4,45,0,321,96|11:251136,39.1,23,0,334,31;268249,15.3,5,0,334,36;240949,8.4,29,0,331,39;268252,4.5,5,0,334,32;251513,2,26,0,331,33;272149,2,27,0,321,42|12:158366,35.4,23,0,334,30;240949,6,29,0,331,39;251513,3.3,26,0,331,33;268252,3.3,5,0,334,32;272149,1.5,27,0,321,42;272148,0.6,27,0,321,41;162544,0.5,28,0,334,37|13:270168,47.5,30,0,344,44;270175,22,30,0,344,43;270166,1.1,36,0,334;250215,0.9,33,0,334;270164,0.8,36,0,334;273796,0.3,33,0,334|14:270173,65.4,30,0,344;270164,2.5,36,0,334;270166,2.4,36,0,334;250228,0.5,33,0,334;273796,0.4,33,0,334;250215,0.3,33,0,334|15:251132,58.9,39,0,334,58;271532,14.5,48,0,344,97;268253,11.7,12,0,344,45|16:268209,80.3,49,0,344,60;268201,9.5,36,0,334,98;237840,8,69,0,331,89|17:237840,85,69,0,331,89;268201,11.3,36,0,334,98;251231,1.1,74,0,321,99",
        gems = {
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 50.3 },
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 18.6 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 16.5 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 86.9 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 88.1 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.2 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 96.8 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 87 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99 },
            },
            [16] = {
                { id = 8689, usagePct = 81.4 },
            },
            [17] = {
                { id = 8689, usagePct = 78.5 },
            },
        },
    },
    ["DEMONHUNTER/VENGEANCE/Annihilator"] = {
        className = "DEMONHUNTER",
        specName = "VENGEANCE",
        heroTalent = "Annihilator",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.7, mastery = 0.7, versatility = 0.5 },
        targetStatPercents = { crit = 31.4, haste = 39.4, mastery = 14.7, versatility = 14.4 },
        targetStatPercentsMplus = { crit = 28.9, haste = 43.5, mastery = 9.9, versatility = 17.6 },
        targetStatPercentsMplusFarm = { crit = 29.7, haste = 39.2, mastery = 18.1, versatility = 13 },
        _pb = "1:271537,84.4,53,0,344,68;271875,11.5,54,0,344,69;273791,2,75,0,334,100|2:268265,55.2,4,0,344,4;251173,14.4,23,0,334,101;273781,12.2,6,0,334,6|3:271535,88.2,55,0,334,71;251223,3,39,0,334,102;268246,2.5,18,0,334,72|5:271540,90.8,57,0,334,74;244570,2.8,58,0,331,11;251226,2.1,45,0,321,103|6:268256,23.5,59,0,344,77;268227,17.2,3,0,334,76;159301,13.3,41,0,334,104|7:271536,78.8,61,0,344,79;244574,6.1,62,0,331,11;268225,5.4,12,0,344,105|8:251153,22,64,0,334,82;268247,20.5,76,0,334,106;244569,18.2,63,0,331,73|9:244576,70.6,65,0,331,46;268240,14.1,66,0,334,83;251135,8,67,0,334,47|10:271538,85.7,68,0,334,84;251124,6.4,64,0,334,86;193758,3.1,45,0,321,107|11:159459,18.7,24,0,334,27;252258,12.2,25,0,334,28;268252,7.4,5,0,334,32;251148,7.4,23,0,334,34;240949,5.6,29,0,331,39;251136,4.6,23,0,334,31;268266,4.6,5,0,334,29;251513,3.3,26,0,331,33;251194,2.3,23,0,334,38;272148,2,27,0,321,41;158366,1.6,23,0,334,30;272147,1.5,27,0,321,35;162544,1.1,28,0,334,37;268249,0.5,5,0,334,36|12:273792,26.6,23,0,334,26;251148,9.4,23,0,334,34;268252,8.4,5,0,334,32;240949,6.4,29,0,331,39;252258,6.2,25,0,334,28;251136,5.3,23,0,334,31;268266,4.8,5,0,334,29;272147,4.1,27,0,321,35;158366,3.9,23,0,334,30;272148,2.3,27,0,321,41;251513,1.1,26,0,331,33;251194,1,23,0,334,38;268249,0.8,5,0,334,36;272150,0.5,27,0,321,40;162544,0.5,28,0,334,37|13:270173,31.7,30,0,344;270175,27.9,30,0,344,43;270164,7.2,36,0,334;270165,6.7,31,0,334;270168,5.1,30,0,344,44;250215,3.3,33,0,334;250228,2,33,0,334;270166,2,36,0,334;270160,1.6,31,0,334;159617,0.7,33,0,334;270174,0.7,77,0,334,108;273796,0.7,33,0,334;274493,0.5,37,0,321|14:250245,14.4,35,0,334;270165,10,31,0,334;270164,6.6,36,0,334;270166,4.3,36,0,334;270168,3.4,30,0,344,44;250228,3.3,33,0,334;270160,1.5,31,0,334;273796,1.1,33,0,334;159617,1.1,33,0,334;274493,1,37,0,321;270174,0.8,77,0,334,108;250215,0.7,33,0,334;250259,0.5,78,0,334;158374,0.5,52,0,321;251792,0.5,37,0,321,0,19,3,0,1320,0;250225,0.5,52,0,321|15:193763,19.4,39,0,334,47;268253,18.6,12,0,344,45;239656,11.2,38,0,331,46|16:268209,53.5,49,0,344,60;237840,30.7,69,0,331,89;270930,9.7,36,0,334,109|17:237840,52.5,69,0,331,89;270930,17.7,36,0,334,109;251231,7.2,74,0,321,99",
        gems = {
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 27.8 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 20.3 },
            { id = 240894, nameCn = "无瑕万能榄石", usagePct = 11.5 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 66.2 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 20.9 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 67.2 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 19.9 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 98.2 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 91.4 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 63.5 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 23.9 },
            },
            [10] = {
                { id = 4732, usagePct = 33.3 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 69.4 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 21.3 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 69.4 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 21.3 },
            },
            [16] = {
                { id = 8689, usagePct = 43.5 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 38.9 },
            },
            [17] = {
                { id = 8689, usagePct = 39.8 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 38.8 },
            },
        },
    },
    ["DRUID/BALANCE/Elune's Chosen"] = {
        className = "DRUID",
        specName = "BALANCE",
        heroTalent = "Elune's Chosen",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.9, haste = 0.9, mastery = 0.8, versatility = 0.4 },
        targetStatPercents = { crit = 28.4, haste = 28.3, mastery = 38.9, versatility = 4.4 },
        targetStatPercentsMplus = { crit = 25.5, haste = 31, mastery = 39.1, versatility = 4.4 },
        targetStatPercentsMplusFarm = { crit = 25.9, haste = 29.8, mastery = 39.9, versatility = 4.4 },
        _pb = "1:271528,87,53,0,344,110;271875,12.1,54,0,344,69;271438,0.6,14,0,334,91|2:268265,92.8,4,0,344,4;251142,1.6,42,0,334,52;271638,1.6,71,0,334,92|3:271526,94.5,79,0,334,84;268246,2.7,18,0,334,72;244572,2,56,0,331,73|5:271531,92.7,80,0,334,111;268235,2.9,18,0,334,75;244570,2.6,58,0,331,11|6:268227,30.5,3,0,334,76;268256,26.4,59,0,344,77;271436,14.6,72,0,334,94|7:271527,85.9,61,0,344,112;244574,8.7,62,0,331,11;268225,2.6,12,0,344,105|8:244569,32.4,63,0,331,73;268261,21.4,18,0,334,18;159327,20.1,39,0,334,81|9:244576,50.9,65,0,331,46;268240,23.4,66,0,334,83;251135,9.3,67,0,334,47|10:271529,70.3,68,0,334,113;244575,15.8,81,0,331,73;268234,7.8,18,0,334,85|11:268249,27.8,5,0,334,36;251136,19.8,23,0,334,31;158366,17,23,0,334,30;252258,9.5,25,0,334,28;240949,5,29,0,331,39;268252,4.4,5,0,334,32;272149,3.1,27,0,321,42;272150,2.8,27,0,321,40;273792,2.8,23,0,334,26;162544,2.6,28,0,334,37;251194,1.8,23,0,334,38;272147,1.3,27,0,321,35;268266,0.6,5,0,334,29|12:252258,10.6,25,0,334,28;240949,5.8,29,0,331,39;273792,5.3,23,0,334,26;272149,3.9,27,0,321,42;268252,3.4,5,0,334,32;272150,2.6,27,0,321,40;251194,2.1,23,0,334,38;162544,1.6,28,0,334,37;251513,1.5,26,0,331,33;272147,1.2,27,0,321,35|13:273796,52.5,33,0,334;250215,14.8,33,0,334;270167,8.2,36,0,334,87;270169,4.2,30,0,344,114;250214,0.6,33,0,334;270161,0.4,82,0,334|14:270164,39.8,36,0,334;270167,31.5,36,0,334,87;250215,6.1,33,0,334;250214,1.6,33,0,334;270169,1.5,30,0,344,114;274493,0.6,37,0,321;251792,0.2,37,0,321,0,32,3,27,1317,2849|15:251132,28.4,39,0,334,58;268253,24,12,0,344,45;251190,16.9,39,0,334,88|16:271092,69.4,30,0,344,62;268210,4.2,36,0,334,90|17:245769,92.5,83,0,331,63;268197,4.2,36,0,334,115;268263,2.9,36,0,334,116",
        gems = {
            { id = 240900, nameCn = "无瑕迅捷紫晶", usagePct = 24.7 },
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 20.9 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 15.7 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 83.7 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 83.1 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.6 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 98.4 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 82.1 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 95.9 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 95.9 },
            },
            [16] = {
                { id = 8689, usagePct = 72.2 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 15.3 },
            },
        },
    },
    ["DRUID/FERAL/Wildstalker"] = {
        className = "DRUID",
        specName = "FERAL",
        heroTalent = "Wildstalker",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.8, mastery = 0.8, versatility = 0.4 },
        targetStatPercents = { crit = 25.6, haste = 27.9, mastery = 41.5, versatility = 5.1 },
        targetStatPercentsMplus = { crit = 25.3, haste = 25.7, mastery = 42, versatility = 7 },
        targetStatPercentsMplusFarm = { crit = 26.1, haste = 27.5, mastery = 39.2, versatility = 7.3 },
        _pb = "1:271528,91,53,0,344,110;271875,8.2,54,0,344,69;193751,0.3,84,0,321,117|2:268265,81.1,4,0,344,4;251142,6.7,42,0,334,52;251234,5.1,23,0,334,51|3:271526,89.3,79,0,334,84;244572,5.1,56,0,331,73;268246,3,18,0,334,72|5:271531,93.4,80,0,334,111;244570,2.8,58,0,331,11;268235,1.5,18,0,334,75|6:268256,25,59,0,344,77;268227,20.7,3,0,334,76;159317,14.1,85,0,334,118|7:271527,91,61,0,344,112;244574,4.4,62,0,331,11;268225,2.3,12,0,344,105|8:244569,41.5,63,0,331,73;251153,18.2,64,0,334,82;159327,12.8,39,0,334,81|9:244576,78.5,65,0,331,46;268240,6.4,66,0,334,83;251183,5.9,73,0,324,95|10:271529,58.1,68,0,334,113;244575,25.9,81,0,331,73;251124,6.2,64,0,334,86|11:252258,26.8,25,0,334,28;273792,12.8,23,0,334,26;268249,11.2,5,0,334,36;240949,4.3,29,0,331,39;272147,4.1,27,0,321,35;251194,2.6,23,0,334,38;162544,2,28,0,334,37;272150,2,27,0,321,40;272149,1.8,27,0,321,42;268252,1.5,5,0,334,32;159459,1.1,24,0,334,27;251513,1,26,0,331,33|12:158366,14.1,23,0,334,30;251136,13.5,23,0,334,31;273792,11.8,23,0,334,26;268249,6.9,5,0,334,36;240949,5.1,29,0,331,39;272147,5.1,27,0,321,35;272149,3.9,27,0,321,42;162544,3.3,28,0,334,37;251194,3.1,23,0,334,38;272150,2.1,27,0,321,40;251148,1.8,23,0,334,34;268266,1.6,5,0,334,29;159459,1.3,24,0,334,27;171699,0.7,86,0,321,119|13:270175,55.8,30,0,344,43;270164,6.4,36,0,334;270165,4.3,31,0,334;273796,3.9,33,0,334;250214,2,33,0,334;159617,1.1,33,0,334;193757,1.1,33,0,334;270168,1,30,0,344,44;270166,0.8,36,0,334;250228,0.7,33,0,334;250215,0.5,33,0,334|14:270173,39.7,30,0,344;270165,8.4,31,0,334;270164,7.2,36,0,334;273796,4.3,33,0,334;270166,2.5,36,0,334;270168,2,30,0,344,44;250214,1.8,33,0,334;274493,1.6,37,0,321;250228,0.8,33,0,334;265657,0.7,37,0,321;159617,0.7,33,0,334|15:251190,22,39,0,334,88;251132,19,39,0,334,58;268253,15.8,12,0,344,45|16:268215,82.8,87,0,344,120;268199,7.6,36,0,334,121;245771,3.6,88,0,331,2",
        gems = {
            { id = 240900, nameCn = "无瑕迅捷紫晶", usagePct = 26.9 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 18 },
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 13.6 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 62.2 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 29.4 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 70.9 },
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 23.1 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 98.7 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 96 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 68.2 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 26.2 },
            },
            [10] = {
                { id = 5447, usagePct = 22.6 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 95.2 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 95.2 },
            },
            [16] = {
                { id = 8689, usagePct = 59.6 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 34.2 },
            },
        },
    },
    ["DRUID/GUARDIAN/Elune's Chosen"] = {
        className = "DRUID",
        specName = "GUARDIAN",
        heroTalent = "Elune's Chosen",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.9, mastery = 0.6, versatility = 0.4 },
        targetStatPercents = { crit = 26, haste = 42.7, mastery = 14.5, versatility = 16.8 },
        targetStatPercentsMplus = { crit = 27.7, haste = 41, mastery = 13.9, versatility = 17.4 },
        targetStatPercentsMplusFarm = { crit = 26.8, haste = 42.8, mastery = 13.5, versatility = 16.8 },
        _pb = "1:271528,71.4,53,0,344,110;271875,24.1,54,0,344,69;239033,1,21,0,321,122|2:268265,73.5,4,0,344,4;251173,6.9,23,0,334,101;268250,6.3,5,0,334,5|3:271526,91,79,0,334,84;273774,3.5,45,0,321,107;251146,1.9,45,0,321,123|5:271531,92.8,80,0,334,111;244570,2.9,58,0,331,11;272239,1.8,89,0,321,124|6:271436,13.5,72,0,334,94;268256,12.9,59,0,344,77;268227,12.4,3,0,334,76|7:271527,87.3,61,0,344,112;244574,4.2,62,0,331,11;159329,2.3,39,0,334,125|8:244569,42.6,63,0,331,73;268247,17.2,76,0,334,106;251153,11.7,64,0,334,82|9:244576,74.8,65,0,331,46;268240,13,66,0,334,83;251135,4.5,67,0,334,47|10:271529,84.4,68,0,334,113;244575,5.5,81,0,331,73;251124,2.7,64,0,334,86|11:273792,19.5,23,0,334,26;252258,12.2,25,0,334,28;251148,7.6,23,0,334,34;251136,4.7,23,0,334,31;158366,4,23,0,334,30;268252,3.5,5,0,334,32;240949,3.4,29,0,331,39;272147,2.4,27,0,321,35;162544,1.4,28,0,334,37;251194,1.4,23,0,334,38;268249,1.3,5,0,334,36;251513,0.8,26,0,331,33;272148,0.8,27,0,321,41;272150,0.6,27,0,321,40;272149,0.6,27,0,321,42|12:268266,16.9,5,0,334,29;159459,16.7,24,0,334,27;252258,15.1,25,0,334,28;251148,5.8,23,0,334,34;268252,5.8,5,0,334,32;240949,3.7,29,0,331,39;272147,2.7,27,0,321,35;251136,2.6,23,0,334,31;158366,1.8,23,0,334,30;251194,1.8,23,0,334,38;272150,1.6,27,0,321,40;162544,1.4,28,0,334,37;272148,1.4,27,0,321,41;275527,0.6,27,0,321,126;268249,0.6,5,0,334,36;272149,0.6,27,0,321,42|13:270175,40.8,30,0,344,43;273796,8.7,33,0,334;270164,3.7,36,0,334;270165,3.4,31,0,334;250228,2.7,33,0,334;270168,2.6,30,0,344,44;250215,2.4,33,0,334;159617,2.4,33,0,334;270166,2.1,36,0,334;270160,1.3,31,0,334;250214,1,33,0,334;250225,0.8,52,0,321;274493,0.5,37,0,321|14:250245,17.8,35,0,334;270173,17.7,30,0,344;270164,8.5,36,0,334;273796,7.4,33,0,334;270165,5.6,31,0,334;270166,5.3,36,0,334;250228,4,33,0,334;250215,2.1,33,0,334;274493,1.9,37,0,321;248583,1.8,47,0,321;270168,1.6,30,0,344,44;250225,1,52,0,321;159617,0.8,33,0,334;265657,0.5,37,0,321;250214,0.5,33,0,334;251785,0.5,37,0,321|15:239656,32,38,0,331,46;193763,14.5,39,0,334,47;251190,8.4,39,0,334,88|16:268215,67,87,0,344,120;245771,12.4,88,0,331,2;268199,9.5,36,0,334,121",
        gems = {
            { id = 240894, nameCn = "无瑕万能榄石", usagePct = 27.1 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 21.6 },
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 17 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 75.4 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 73.2 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 97.5 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 93.7 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 73.6 },
                { id = 8019, nameCn = "远行者的狩猎", icon = "ui_profession_enchanting", usagePct = 16.8 },
            },
            [10] = {
                { id = 5932, usagePct = 46.2 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 51.1 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 32.4 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 51.1 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 32.4 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 49.3 },
                { id = 8689, usagePct = 33.8 },
            },
        },
    },
    ["DRUID/RESTORATION/Wildstalker"] = {
        className = "DRUID",
        specName = "RESTORATION",
        heroTalent = "Wildstalker",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.5, haste = 0.9, mastery = 0.5, versatility = 0.4 },
        targetStatPercents = { crit = 8.9, haste = 48.2, mastery = 34.7, versatility = 8.1 },
        targetStatPercentsMplus = { crit = 7.4, haste = 47.4, mastery = 32.8, versatility = 12.4 },
        targetStatPercentsMplusFarm = { crit = 11.7, haste = 42.6, mastery = 35.9, versatility = 9.8 },
        _pb = "1:271528,93.7,53,0,344,110;271875,3.9,54,0,344,69|2:268265,62.4,4,0,344,4;251142,15.6,42,0,334,52;268251,10,90,0,334,127|3:244572,57.5,56,0,331,73;271526,34.5,79,0,334,84;251223,2.8,39,0,334,102|5:271531,94,80,0,334,111;268235,3.3,18,0,334,75;251159,1,91,0,321,128|6:268256,43.2,59,0,344,77;159317,23.3,85,0,334,118;271436,10.6,72,0,334,94|7:271527,93.9,61,0,344,112;272243,1.9,89,0,321,129;268225,1.9,12,0,344,105|8:268247,34,76,0,334,106;244569,29.4,63,0,331,73;251153,8.9,64,0,334,82|9:244576,63,65,0,331,46;251135,12.3,67,0,334,47;268240,10.9,66,0,334,83|10:271529,92.8,68,0,334,113;244575,1.8,81,0,331,73;159337,1.5,39,0,334,130|11:252258,39.1,25,0,334,28;272147,11,27,0,321,35;240949,10.2,29,0,331,39;268266,9.7,5,0,334,29;272150,9.3,27,0,321,40;273792,2.6,23,0,334,26;162544,2.2,28,0,334,37;268249,2.1,5,0,334,36;159459,1.4,24,0,334,27;251194,1.4,23,0,334,38;251136,0.6,23,0,334,31|12:268266,11.7,5,0,334,29;272150,10,27,0,321,40;240949,9.6,29,0,331,39;272147,5.2,27,0,321,35;159459,3.9,24,0,334,27;268249,2.2,5,0,334,36;251194,2.1,23,0,334,38;273792,2.1,23,0,334,26;275527,1.7,27,0,321,126;162544,1.5,28,0,334,37;272149,1.1,27,0,321,42;171853,0.6,86,0,321,131|13:270167,32.2,36,0,334,87;270162,32,36,0,334;270169,7.1,30,0,344,114;250214,6,33,0,334;248583,4.9,47,0,321;251792,2.5,37,0,321,0,19,3,0,1320,0;274493,1.8,37,0,321;250215,0.7,33,0,334|14:270164,14.3,36,0,334;270169,6.7,30,0,344,114;248583,5.7,47,0,321;251792,4.6,37,0,321,0,19,3,0,1320,0;250214,4.3,33,0,334;274493,1,37,0,321;193757,0.6,33,0,334|15:251190,39.4,39,0,334,88;268253,26.5,12,0,344,45;271523,5.2,92,0,334,132|16:271092,58.4,30,0,344,62|17:245769,58.3,83,0,331,63;268197,27.2,36,0,334,115;251191,7.2,33,0,334,133",
        gems = {
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 53.9 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 20 },
            { id = 240900, nameCn = "无瑕迅捷紫晶", usagePct = 15 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 74.6 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 18.4 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 76.1 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 17.9 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 76.2 },
                { id = 8013, nameCn = "魔导师印记", icon = "ui_profession_enchanting", usagePct = 23.1 },
            },
            [7] = {
                { id = 7937, nameCn = "奥纹魔线", item = 240155, icon = "inv_12_tailoring_spellthread_violet_spellthread", usagePct = 75.2 },
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 23.6 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 75.2 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 20.2 },
            },
            [10] = {
                { id = 5447, usagePct = 45.5 },
            },
            [11] = {
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 71.6 },
                { id = 7969, nameCn = "祖尔金的精通", icon = "ui_profession_enchanting", usagePct = 18.7 },
            },
            [12] = {
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 71.6 },
                { id = 7969, nameCn = "祖尔金的精通", icon = "ui_profession_enchanting", usagePct = 18.7 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 50 },
                { id = 7983, nameCn = "狂战士之怒", icon = "ui_profession_enchanting", usagePct = 34.9 },
            },
        },
    },
    ["EVOKER/AUGMENTATION/Chronowarden"] = {
        className = "EVOKER",
        specName = "AUGMENTATION",
        heroTalent = "Chronowarden",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.8, haste = 0.6, mastery = 0.9, versatility = 0.3 },
        targetStatPercents = { crit = 29.7, haste = 15.3, mastery = 51.8, versatility = 3.2 },
        targetStatPercentsMplus = { crit = 31.8, haste = 17.2, mastery = 45.6, versatility = 5.3 },
        targetStatPercentsMplusFarm = { crit = 29.9, haste = 16.8, mastery = 48, versatility = 5.3 },
        _pb = "1:271501,87.9,1,0,334,134;268230,4.6,93,0,334,135;271441,3.3,94,0,334,136|2:268265,65.6,4,0,344,4;268251,21.6,90,0,334,127;271638,4.5,71,0,334,92|3:271499,89.1,95,0,344,137;268231,6.1,12,0,344,138;244580,2.8,81,0,331,139|5:271504,86.1,96,0,344,140;271876,13.4,97,0,344,120;268223,0.4,18,0,334,141|6:268254,50.4,3,0,334,142;244581,22.1,98,0,331,139;251155,7.8,41,0,334,143|7:271500,83.8,61,0,344,144;244582,9.1,81,0,331,145;268237,4.6,12,0,344,146|8:268233,38.4,18,0,334,20;268258,29.1,18,0,334,147;159388,10.5,39,0,334,148|9:244584,69.7,98,0,331,149;268217,19,3,0,334,150;159380,3.3,99,0,328,151|10:271502,83.5,22,0,334,152;244583,10.1,100,0,331,73;268238,3.8,18,0,334,86|11:268249,30.8,5,0,334,36;251136,23.4,23,0,334,31;268252,7.3,5,0,334,32;272149,6.4,27,0,321,42;240949,5.6,29,0,331,39;273792,2.2,23,0,334,26;252258,1.3,25,0,334,28;251513,1,26,0,331,33;162544,1,28,0,334,37;272147,1,27,0,321,35;272150,0.8,27,0,321,40|12:158366,21.3,23,0,334,30;240949,9.5,29,0,331,39;268252,6.8,5,0,334,32;272149,5.4,27,0,321,42;273792,2.9,23,0,334,26;252258,2.2,25,0,334,28;272150,2,27,0,321,40;162544,1.4,28,0,334,37|13:270168,37.9,30,0,344,44;270170,11.1,36,0,334;250224,8,33,0,334;270167,2.8,36,0,334,87;270169,1.5,30,0,344,114;250215,0.9,33,0,334;251792,0.8,37,0,321,0,19,3,0,1320,0|14:270161,23.8,82,0,334;270164,14.9,36,0,334;250224,13.2,33,0,334;270170,8.8,36,0,334;270167,5.9,36,0,334,87;270169,1.5,30,0,344,114;250215,0.5,33,0,334|15:251132,34.2,39,0,334,58;268253,20.1,12,0,344,45;239656,17.4,38,0,331,46|16:271092,55.4,30,0,344,62|17:245769,80.2,83,0,331,63;268263,10.6,36,0,334,116;268197,8.7,36,0,334,115",
        gems = {
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 48 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 21.2 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 11.2 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 85.2 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 84.2 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 98.3 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 95.7 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 87.4 },
            },
            [11] = {
                { id = 7969, nameCn = "祖尔金的精通", icon = "ui_profession_enchanting", usagePct = 65.9 },
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 18.8 },
            },
            [12] = {
                { id = 7969, nameCn = "祖尔金的精通", icon = "ui_profession_enchanting", usagePct = 65.9 },
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 18.8 },
            },
            [16] = {
                { id = 8689, usagePct = 37.4 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 33.2 },
            },
        },
    },
    ["EVOKER/DEVASTATION/Scalecommander"] = {
        className = "EVOKER",
        specName = "DEVASTATION",
        heroTalent = "Scalecommander",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.9, haste = 0.7, mastery = 0.6, versatility = 0.3 },
        targetStatPercents = { crit = 43, haste = 24.3, mastery = 27.3, versatility = 5.4 },
        targetStatPercentsMplus = { crit = 42.4, haste = 24.2, mastery = 26.2, versatility = 7.3 },
        targetStatPercentsMplusFarm = { crit = 38.9, haste = 24.6, mastery = 28.8, versatility = 7.7 },
        _pb = "1:271501,83.8,1,0,334,134;268230,6.2,93,0,334,135;272250,2.4,101,0,321,153|2:268265,87.4,4,0,344,4;273781,3.2,6,0,334,6;271638,2.1,71,0,334,92|3:271499,89,95,0,344,137;268231,3,12,0,344,138;244580,3,81,0,331,139|5:271504,87.1,96,0,344,140;271876,11.6,97,0,344,120;272247,0.8,89,0,321,154|6:268254,28.5,3,0,334,142;268216,25.1,102,0,334,155;244581,11.2,98,0,331,139|7:271500,88,61,0,344,144;244582,3.7,81,0,331,145;268237,3.5,12,0,344,146|8:268258,37.6,18,0,334,147;268233,14.8,18,0,334,20;159388,11.4,39,0,334,148|9:244584,71,98,0,331,149;268217,10.7,3,0,334,150;272254,5.2,101,0,321,156|10:271502,86.9,22,0,334,152;268238,8.6,18,0,334,86;244583,1.3,100,0,331,73|11:251136,20.8,23,0,334,31;273792,18.9,23,0,334,26;268252,14.7,5,0,334,32;268249,8.5,5,0,334,36;240949,7.9,29,0,331,39;272148,3.2,27,0,321,41;252258,1.8,25,0,334,28;251148,1.3,23,0,334,34;272149,1.1,27,0,321,42;251513,1.1,26,0,331,33;272147,0.7,27,0,321,35;162544,0.6,28,0,334,37;272150,0.6,27,0,321,40|12:158366,18.4,23,0,334,30;268252,16.9,5,0,334,32;268249,8.2,5,0,334,36;240949,7.8,29,0,331,39;252258,2.8,25,0,334,28;272148,2.1,27,0,321,41;251148,1.6,23,0,334,34;272150,1,27,0,321,40;272149,1,27,0,321,42;272147,0.8,27,0,321,35;251513,0.6,26,0,331,33|13:273796,30.8,33,0,334;250215,4,33,0,334;274493,2.1,37,0,321;250224,2.1,33,0,334;270161,1.7,82,0,334;248583,0.7,47,0,321;270168,0.7,30,0,344,44;270170,0.7,36,0,334;251792,0.7,37,0,321,0,19,3,0,1320,0|14:270164,38,36,0,334;270167,31.1,36,0,334,87;250224,4.4,33,0,334;270161,3.4,82,0,334;251792,1.7,37,0,321,0,19,3,0,1320,0;274493,1.7,37,0,321;270168,1.1,30,0,344,44;248583,1,47,0,321;250215,0.8,33,0,334|15:251132,27.4,39,0,334,58;239656,15.4,38,0,331,46;193763,11.6,39,0,334,47|16:271092,67.2,30,0,344,62;268210,3.8,36,0,334,90|17:245769,93.3,83,0,331,63;268263,3.3,36,0,334,116;268197,2.4,36,0,334,115",
        gems = {
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 34.1 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 20.7 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 18.3 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 80.4 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 15.8 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 81.3 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.2 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 96.5 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 76.1 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 20.1 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 83.8 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 83.8 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 48.9 },
                { id = 8689, usagePct = 44.3 },
            },
        },
    },
    ["EVOKER/PRESERVATION/Flameshaper"] = {
        className = "EVOKER",
        specName = "PRESERVATION",
        heroTalent = "Flameshaper",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.9, haste = 0.7, mastery = 0.7, versatility = 0.3 },
        targetStatPercents = { crit = 34.6, haste = 20.4, mastery = 39.3, versatility = 5.6 },
        targetStatPercentsMplus = { crit = 27.3, haste = 39, mastery = 10.8, versatility = 22.9 },
        targetStatPercentsMplusFarm = { crit = 36.8, haste = 23.3, mastery = 34.1, versatility = 5.8 },
        _pb = "1:271501,84.6,1,0,334,134;268230,3.8,93,0,334,135;244579,3.8,103,0,331,11|2:268265,72.5,4,0,344,4;251234,6.1,23,0,334,51;271638,3.5,71,0,334,92|3:271499,87.3,95,0,344,137;244580,4.1,81,0,331,139;268231,4.1,12,0,344,138|5:271504,86.7,96,0,344,140;271876,11.3,97,0,344,120;268223,1,18,0,334,141|6:268254,32.6,3,0,334,142;244581,22.6,98,0,331,139;268216,14.9,102,0,334,155|7:271500,77,61,0,344,144;244582,14.5,81,0,331,145;268237,3,12,0,344,146|8:268258,30.6,18,0,334,147;159388,16,39,0,334,148;268233,15.3,18,0,334,20|9:244584,44.6,98,0,331,149;268217,26.6,3,0,334,150;159380,9.7,99,0,328,151|10:271502,86,22,0,334,152;268238,5.7,18,0,334,86;272249,2.7,89,0,321,157|11:158366,24.9,23,0,334,30;268252,10.7,5,0,334,32;268249,10.4,5,0,334,36;273792,9.1,23,0,334,26;240949,5.1,29,0,331,39;272149,4.2,27,0,321,42;252258,3.4,25,0,334,28;272150,2.9,27,0,321,40;272147,2.1,27,0,321,35;251194,0.8,23,0,334,38;251148,0.8,23,0,334,34;162544,0.6,28,0,334,37|12:251136,25.9,23,0,334,31;268249,12.1,5,0,334,36;240949,8.7,29,0,331,39;268252,7.9,5,0,334,32;273792,5.8,23,0,334,26;272149,5.3,27,0,321,42;252258,4.7,25,0,334,28;272150,3.1,27,0,321,40;272147,1.8,27,0,321,35;162544,1.2,28,0,334,37;272148,0.8,27,0,321,41;251194,0.7,23,0,334,38|13:270162,48.3,36,0,334;250215,3,33,0,334;248583,2.3,47,0,321;274493,1.9,37,0,321;250214,1.5,33,0,334;270171,1,104,0,334,158;251792,0.8,37,0,321,0,19,3,0,1320,0;274495,0.7,37,0,321|14:270164,41,36,0,334;270167,10,36,0,334,87;248583,2.7,47,0,321;274493,2.5,37,0,321;250214,2.5,33,0,334;270171,2.1,104,0,334,158;274495,1.3,37,0,321;250215,1.2,33,0,334;251792,1,37,0,321,0,19,3,0,1320,0;246304,0.6,105,0,341;270169,0.6,30,0,344,114|15:251132,33.7,39,0,334,58;239656,16.2,38,0,331,46;268253,8.2,12,0,344,45|16:271092,40.9,30,0,344,62;268210,5.3,36,0,334,90|17:245769,69.5,83,0,331,63;268263,14.7,36,0,334,116;268197,11.4,36,0,334,115",
        gems = {
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 30.3 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 20.3 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 17.1 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 75.4 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 21.8 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 74.2 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 22.7 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 78.5 },
                { id = 8013, nameCn = "魔导师印记", icon = "ui_profession_enchanting", usagePct = 21.2 },
            },
            [7] = {
                { id = 7937, nameCn = "奥纹魔线", item = 240155, icon = "inv_12_tailoring_spellthread_violet_spellthread", usagePct = 63 },
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 36.4 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 75.2 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 23.2 },
            },
            [11] = {
                { id = 7969, nameCn = "祖尔金的精通", icon = "ui_profession_enchanting", usagePct = 40.8 },
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 19.9 },
            },
            [12] = {
                { id = 7969, nameCn = "祖尔金的精通", icon = "ui_profession_enchanting", usagePct = 40.8 },
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 19.9 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 43.4 },
                { id = 8689, usagePct = 36.4 },
            },
        },
    },
    ["HUNTER/BEASTMASTERY/Pack Leader"] = {
        className = "HUNTER",
        specName = "BEASTMASTERY",
        heroTalent = "Pack Leader",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.7, haste = 0.9, mastery = 0.8, versatility = 0.3 },
        targetStatPercents = { crit = 34.2, haste = 19.7, mastery = 40.4, versatility = 5.7 },
        targetStatPercentsMplus = { crit = 37.4, haste = 6.5, mastery = 46, versatility = 10.1 },
        targetStatPercentsMplusFarm = { crit = 39.8, haste = 10.5, mastery = 41.7, versatility = 8 },
        _pb = "1:271492,94.7,106,0,334,159;268230,1.8,93,0,334,135;251220,1.2,21,0,321,160|2:268265,79.5,4,0,344,4;251234,5.3,23,0,334,51;251142,4.5,42,0,334,52|3:271490,89.3,107,0,344,161;268231,3.8,12,0,344,138;239049,2.5,39,0,334,162|5:271495,87.6,96,0,344,105;271876,11.1,97,0,344,120;268223,0.6,18,0,334,141|6:244581,67.3,98,0,331,139;268254,10.2,3,0,334,142;251155,7.3,41,0,334,143|7:271491,75.1,108,0,344,163;244582,16.7,81,0,331,145;268237,4.5,12,0,344,146|8:268258,29.7,18,0,334,147;159388,19.6,39,0,334,148;268233,17.7,18,0,334,20|9:244584,76.7,98,0,331,149;268217,11.7,3,0,334,150;159380,3.4,99,0,328,151|10:271493,86.7,109,0,334,106;193752,4.4,45,0,321,164;268238,4.2,18,0,334,86|11:251136,17.6,23,0,334,31;268249,13.3,5,0,334,36;273792,5.6,23,0,334,26;162544,5.1,28,0,334,37;272150,4.5,27,0,321,40;240949,4.2,29,0,331,39;272147,3.7,27,0,321,35;268252,3.7,5,0,334,32;251194,3.2,23,0,334,38;272149,2.8,27,0,321,42;159459,1.6,24,0,334,27;251513,0.9,26,0,331,33;272148,0.6,27,0,321,41;251148,0.6,23,0,334,34|12:158366,18.7,23,0,334,30;252258,16.1,25,0,334,28;268249,11.1,5,0,334,36;273792,10,23,0,334,26;272147,4.5,27,0,321,35;162544,4.4,28,0,334,37;272149,4.4,27,0,321,42;240949,3.2,29,0,331,39;251194,3.1,23,0,334,38;272150,2.2,27,0,321,40;268252,2,5,0,334,32;159459,1.8,24,0,334,27;268266,1.6,5,0,334,29;251148,1,23,0,334,34;251513,1,26,0,331,33|13:270175,50.2,30,0,344,43;270168,9.4,30,0,344,44;270173,8.8,30,0,344;270164,7.5,36,0,334;250215,4.5,33,0,334;273796,2.8,33,0,334;159617,2.6,33,0,334;274493,0.7,37,0,321;250228,0.6,33,0,334|14:270165,17.7,31,0,334;270164,16.1,36,0,334;270168,16.1,30,0,344,44;270173,13.2,30,0,344;250215,2.8,33,0,334;159617,1.6,33,0,334;250214,1.5,33,0,334;273796,1.2,33,0,334;274493,1.2,37,0,321;250228,1,33,0,334;251792,0.7,37,0,321,0,19,3,0,1320,0;265657,0.6,37,0,321|15:251132,32.4,39,0,334,58;239656,15.2,38,0,331,46;193763,11.4,39,0,334,47|16:268207,69.5,110,0,344,16;265337,17.7,111,0,331,145;268200,11,36,0,334,75",
        gems = {
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 31.1 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 24.6 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 15 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 75.7 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 18.3 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 77.3 },
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 16.8 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.1 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 99.3 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 75.1 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 17.9 },
            },
            [10] = {
                { id = 5445, usagePct = 60 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 96.2 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 96.2 },
            },
            [16] = {
                { id = 8689, usagePct = 80.3 },
            },
        },
    },
    ["HUNTER/MARKSMANSHIP/Sentinel"] = {
        className = "HUNTER",
        specName = "MARKSMANSHIP",
        heroTalent = "Sentinel",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.8, mastery = 0.9, versatility = 0.4 },
        targetStatPercents = { crit = 51.6, haste = 8.1, mastery = 33, versatility = 7.3 },
        targetStatPercentsMplus = { crit = 51.2, haste = 7.9, mastery = 30.4, versatility = 10.4 },
        targetStatPercentsMplusFarm = { crit = 51.3, haste = 7.1, mastery = 33.9, versatility = 7.7 },
        _pb = "1:271492,93.1,106,0,334,159;268230,4.2,93,0,334,135;244579,1,103,0,331,11|2:268265,87.9,4,0,344,4;251234,8.8,23,0,334,51;271638,1.3,71,0,334,92|3:271490,93.8,107,0,344,161;268231,3.4,12,0,344,138;251131,1.3,39,0,334,165|5:271495,94.9,96,0,344,105;271876,5.1,97,0,344,120|6:244581,72.5,98,0,331,139;268216,15.4,102,0,334,155;271489,4.3,112,0,334,166|7:271491,52.8,108,0,344,163;244582,43.2,81,0,331,145;159375,2.6,45,0,321,167|8:268258,44.6,18,0,334,147;271440,13.3,113,0,334,168;159388,13.2,39,0,334,148|9:244584,63.5,98,0,331,149;268217,19.3,3,0,334,150;159380,5.1,99,0,328,151|10:271493,89.5,109,0,334,106;268238,4.2,18,0,334,86;244583,4,100,0,331,73|11:251136,36.1,23,0,334,31;158366,29.9,23,0,334,30;268249,9.5,5,0,334,36;268252,8.1,5,0,334,32;251148,5.6,23,0,334,34;240949,3.7,29,0,331,39;162544,1.7,28,0,334,37;272149,1.7,27,0,321,42;272148,1.5,27,0,321,41;251513,0.5,26,0,331,33|12:251148,8.7,23,0,334,34;268249,8.4,5,0,334,36;268252,8.1,5,0,334,32;240949,3.9,29,0,331,39;162544,2.3,28,0,334,37;272148,2.2,27,0,321,41;251513,2.1,26,0,331,33;272149,0.9,27,0,321,42;251194,0.7,23,0,334,38;171539,0.5,86,0,321,169;252258,0.5,25,0,334,28|13:270175,63.3,30,0,344,43;273796,1.8,33,0,334;270173,1.6,30,0,344;159617,1.3,33,0,334;270164,1,36,0,334;250225,0.5,52,0,321;250214,0.2,33,0,334|14:270168,64,30,0,344,44;270173,1.8,30,0,344;159617,1.3,33,0,334;270164,1,36,0,334;273796,0.7,33,0,334;270165,0.5,31,0,334;265657,0.2,37,0,321,0,33,3,28,1320,2888|15:251132,39.3,39,0,334,58;268248,15.9,18,0,334,170;271487,11.5,48,0,344,171|16:268207,82.7,110,0,344,16;268200,8,36,0,334,75;265337,7.8,111,0,331,145",
        gems = {
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 34.3 },
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 16.8 },
            { id = 240967, nameCn = "强能之永歌钻石", usagePct = 12.4 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 52.9 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 40.6 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 53.9 },
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 40 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.4 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 99.1 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 51.9 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 41.4 },
            },
            [10] = {
                { id = 5935, usagePct = 71.4 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99.2 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99.2 },
            },
            [16] = {
                { id = 8689, usagePct = 78.4 },
            },
        },
    },
    ["HUNTER/SURVIVAL/Sentinel"] = {
        className = "HUNTER",
        specName = "SURVIVAL",
        heroTalent = "Sentinel",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.6, haste = 0.9, mastery = 0.9, versatility = 0.3 },
        targetStatPercents = { crit = 28, haste = 25.8, mastery = 44.2, versatility = 2.1 },
        targetStatPercentsMplus = { crit = 25.8, haste = 24.1, mastery = 46, versatility = 4.1 },
        targetStatPercentsMplusFarm = { crit = 29.3, haste = 23.5, mastery = 44.1, versatility = 3.1 },
        _pb = "1:271492,90.8,106,0,334,159;268230,2.8,93,0,334,135;239035,1.7,41,0,334,172|2:268265,60.8,4,0,344,4;251142,10.5,42,0,334,52;251234,9.2,23,0,334,51|3:271490,90,107,0,344,161;268231,5.8,12,0,344,138;239049,2.8,39,0,334,162|5:271495,86.4,96,0,344,105;271876,11.7,97,0,344,120;251233,0.6,45,0,321,173|6:244581,69.7,98,0,331,139;268254,9.6,3,0,334,142;251155,7.9,41,0,334,143|7:271491,87.9,108,0,344,163;244582,8.1,81,0,331,145;268237,2.6,12,0,344,146|8:268258,23.4,18,0,334,147;268233,19.8,18,0,334,20;159388,17.1,39,0,334,148|9:244584,82.5,98,0,331,149;268217,8.1,3,0,334,150;159380,5.3,99,0,328,151|10:271493,85.9,109,0,334,106;244583,4.7,100,0,331,73;193752,3.4,45,0,321,164|11:252258,24.9,25,0,334,28;273792,13.6,23,0,334,26;158366,8.7,23,0,334,30;240949,7.3,29,0,331,39;272149,5.1,27,0,321,42;272150,3.8,27,0,321,40;268249,3.6,5,0,334,36;251194,3.6,23,0,334,38;272147,3.4,27,0,321,35;268252,2.6,5,0,334,32;162544,1.5,28,0,334,37|12:251136,21.5,23,0,334,31;158366,15.1,23,0,334,30;273792,11.3,23,0,334,26;268249,8.9,5,0,334,36;240949,7,29,0,331,39;272150,3.6,27,0,321,40;272147,3,27,0,321,35;272149,2.4,27,0,321,42;171654,1.1,86,0,321,174;162544,0.9,28,0,334,37;251513,0.8,26,0,331,33|13:270175,37.1,30,0,344,43;250215,10.7,33,0,334;270168,4,30,0,344,44;273796,2.1,33,0,334;250225,1.9,52,0,321;159617,1.5,33,0,334;156016,1.1,114,0,321,175;270164,1.1,36,0,334;273797,0.8,34,0,334;250214,0.6,33,0,334;265657,0.6,37,0,321|14:270173,33.5,30,0,344;270165,26.9,31,0,334;270164,6.4,36,0,334;250215,3.6,33,0,334;270168,2.1,30,0,344,44;250228,1.9,33,0,334;273796,1.5,33,0,334;274493,0.9,37,0,321;250214,0.9,33,0,334;270166,0.6,36,0,334|15:251132,23.9,39,0,334,58;268253,18.6,12,0,344,45;271487,16.9,48,0,344,171|16:268213,32.2,30,0,344,48;268215,30.1,87,0,344,120;237847,13,111,0,331,2",
        gems = {
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 33.4 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 20.9 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 12.2 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 60.4 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 31.2 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 60.3 },
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 31.9 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 97.6 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 99.1 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 59.5 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 32.6 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 94 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 94 },
            },
            [16] = {
                { id = 8689, usagePct = 68.2 },
                { id = 8041, nameCn = "奥术精通", icon = "ui_profession_enchanting", usagePct = 23.9 },
            },
            [17] = {
                { id = 8689, usagePct = 62.2 },
                { id = 8041, nameCn = "奥术精通", icon = "ui_profession_enchanting", usagePct = 29 },
            },
        },
    },
    ["MAGE/ARCANE/Sunfury"] = {
        className = "MAGE",
        specName = "ARCANE",
        heroTalent = "Sunfury",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.9, haste = 0.9, mastery = 0.6, versatility = 0.4 },
        targetStatPercents = { crit = 28.9, haste = 34.4, mastery = 17.2, versatility = 19.5 },
        targetStatPercentsMplus = { crit = 24.8, haste = 30.7, mastery = 10.6, versatility = 33.9 },
        targetStatPercentsMplusFarm = { crit = 25.7, haste = 35.2, mastery = 17.4, versatility = 21.7 },
        _pb = "1:271564,80.5,115,0,344,176;271874,16,116,0,344,177;268242,2.8,102,0,334,178|2:268265,88.5,4,0,344,4;273781,2.9,6,0,334,6;271638,2.5,71,0,334,92|3:271562,90.2,117,0,334,179;268241,3,18,0,334,180;239650,2.3,58,0,331,73|5:271567,90.7,80,0,334,181;239655,4.7,118,0,331,11;251139,2.1,119,0,331,182|6:268232,32.3,20,0,334,183;268257,24.7,120,0,334,184;251222,12.8,41,0,334,82|7:271563,91.5,121,0,334,185;239651,4.7,81,0,331,2;268236,1.6,122,0,334,186|8:271435,23.7,113,0,334,187;268218,14.8,18,0,334,188;268255,13.3,12,0,344,189|9:239648,73.4,123,0,331,46;251127,10.6,41,0,334,190;268228,7.7,3,0,334,191|10:271565,82.7,124,0,344,192;268243,4.4,12,0,344,193;239653,4,58,0,331,73|11:251148,21.8,23,0,334,34;159459,13.8,24,0,334,27;268252,11.6,5,0,334,32;273792,8.7,23,0,334,26;240949,6,29,0,331,39;251136,3.4,23,0,334,31;158366,2.1,23,0,334,30;268249,1.9,5,0,334,36;252258,1.8,25,0,334,28;272148,1.5,27,0,321,41;162544,1.2,28,0,334,37;251513,0.8,26,0,331,33;272147,0.5,27,0,321,35|12:268266,23.8,5,0,334,29;273792,10.4,23,0,334,26;268252,7.9,5,0,334,32;240949,6.5,29,0,331,39;251136,3.9,23,0,334,31;268249,2.8,5,0,334,36;252258,1.7,25,0,334,28;158366,1.7,23,0,334,30;272148,1.6,27,0,321,41;272149,1.1,27,0,321,42;272147,1,27,0,321,35;162544,0.6,28,0,334,37;251513,0.5,26,0,331,33;272150,0.5,27,0,321,40|13:250215,67.1,33,0,334;270169,6,30,0,344,114;270167,3.7,36,0,334,87;250224,0.6,33,0,334;251792,0.2,37,0,321,0,19,3,0,1320,0;250259,0.1,78,0,334|14:270164,59.5,36,0,334;270167,10.5,36,0,334,87;250224,1.9,33,0,334;270169,1.6,30,0,344,114;250214,0.8,33,0,334;251792,0.8,37,0,321,0,19,3,0,1320,0;270170,0.6,36,0,334;274493,0.5,37,0,321|15:193763,18.4,39,0,334,47;239656,15.6,38,0,331,46;268248,15.1,18,0,334,170|16:271092,35.7,30,0,344,62;268211,6.2,30,0,344,194|17:245769,85.3,83,0,331,63;268263,6.9,36,0,334,116;268197,5,36,0,334,115",
        gems = {
            { id = 240916, nameCn = "无瑕迅捷青金石", usagePct = 18.4 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 16.3 },
            { id = 240894, nameCn = "无瑕万能榄石", usagePct = 16.1 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 89 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 83.2 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.6 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 56.2 },
                { id = 7937, nameCn = "奥纹魔线", item = 240155, icon = "inv_12_tailoring_spellthread_violet_spellthread", usagePct = 43.8 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 82.5 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.6 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.6 },
            },
            [16] = {
                { id = 8689, usagePct = 77.6 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 17.1 },
            },
        },
    },
    ["MAGE/FIRE/Sunfury"] = {
        className = "MAGE",
        specName = "FIRE",
        heroTalent = "Sunfury",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.6, haste = 0.9, mastery = 0.6, versatility = 0.3 },
        targetStatPercents = { crit = 5.9, haste = 46.4, mastery = 33, versatility = 14.7 },
        targetStatPercentsMplus = { crit = 9, haste = 43.1, mastery = 29.4, versatility = 18.5 },
        targetStatPercentsMplusFarm = { crit = 11.8, haste = 43.5, mastery = 28.2, versatility = 16.5 },
        _pb = "1:271564,81.3,115,0,344,176;271874,12.5,116,0,344,177;251232,2.8,41,0,334,195|2:268265,64.2,4,0,344,4;251142,18,42,0,334,52;268251,4.6,90,0,334,127|3:271562,88.7,117,0,334,179;268241,3.7,18,0,334,180;239650,2.8,58,0,331,73|5:271567,80.1,80,0,334,181;273785,8,39,0,334,196;239655,4.6,118,0,331,11|6:268257,31.2,120,0,334,184;239649,21.7,65,0,331,73;193691,19,41,0,334,53|7:271563,86.2,121,0,334,185;268236,6.1,122,0,334,186;239651,2.8,81,0,331,2|8:268255,29.1,12,0,344,189;159243,24.8,39,0,334,197;251137,17.1,125,0,334,198|9:239648,86.2,123,0,331,46;268228,3.4,3,0,334,191;251127,3.4,41,0,334,190|10:271565,88.4,124,0,344,192;251129,5.8,45,0,321,199;268243,2.1,12,0,344,193|11:268266,25.4,5,0,334,29;272147,3.7,27,0,321,35;273792,2.8,23,0,334,26;162544,2.8,28,0,334,37;240949,2.8,29,0,331,39;171527,1.5,86,0,321,200;272150,1.5,27,0,321,40;251194,0.9,23,0,334,38;251148,0.9,23,0,334,34;268252,0.6,5,0,334,32|12:159459,30,24,0,334,27;252258,22.6,25,0,334,28;251194,3.4,23,0,334,38;273792,3.1,23,0,334,26;240949,2.1,29,0,331,39;272147,1.8,27,0,321,35;268249,1.5,5,0,334,36;251136,0.9,23,0,334,31;272150,0.6,27,0,321,40;266317,0.6,126,0,321,201|13:273796,49.8,33,0,334;273649,4.6,33,0,334;270169,4.3,30,0,344,114;270168,4.3,30,0,344,44;250215,3.1,33,0,334;250214,1.8,33,0,334;158368,0.6,127,0,328;250224,0.6,33,0,334|14:270164,31.5,36,0,334;270167,12.8,36,0,334,87;270168,11.9,30,0,344,44;270169,6.7,30,0,344,114;273649,5.5,33,0,334;250224,2.8,33,0,334;250214,2.4,33,0,334;270161,0.9,82,0,334;250215,0.6,33,0,334;270170,0.6,36,0,334;251792,0.6,37,0,321,0,8,3,6,1317,2849|15:251190,27.5,39,0,334,88;159288,22.9,39,0,334,202;239656,12.8,38,0,331,46|16:271092,40.1,30,0,344,62;273778,13.1,128,0,334,203|17:245769,84.2,83,0,331,63;268263,6.2,36,0,334,116;268197,3.3,36,0,334,115",
        gems = {
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 19.4 },
            { id = 240916, nameCn = "无瑕迅捷青金石", usagePct = 14.8 },
            { id = 240894, nameCn = "无瑕万能榄石", usagePct = 13.7 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 77 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 73.6 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 97.7 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 90.3 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 76 },
            },
            [10] = {
                { id = 5447, usagePct = 12.5 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 91.9 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 91.9 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 67.7 },
                { id = 8689, usagePct = 26.8 },
            },
        },
    },
    ["MAGE/FROST/Spellslinger"] = {
        className = "MAGE",
        specName = "FROST",
        heroTalent = "Spellslinger",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.9, haste = 0.8, mastery = 0.7, versatility = 0.4 },
        targetStatPercents = { crit = 37.3, haste = 21.3, mastery = 36.1, versatility = 5.3 },
        targetStatPercentsMplus = { crit = 37.4, haste = 21.4, mastery = 36.6, versatility = 4.5 },
        targetStatPercentsMplusFarm = { crit = 36, haste = 23.4, mastery = 32.5, versatility = 8 },
        _pb = "1:271564,76.3,115,0,344,176;271874,21.2,116,0,344,177;268242,1.4,102,0,334,178|2:268265,84.6,4,0,344,4;251234,6.1,23,0,334,51;273781,2.6,6,0,334,6|3:271562,90.5,117,0,334,179;239045,2.6,39,0,334,204;239650,1.8,58,0,331,73|5:271567,89.2,80,0,334,181;268221,4.3,18,0,334,205;239655,2,118,0,331,11|6:239649,28.1,65,0,331,73;268257,20.1,120,0,334,184;268232,19.2,20,0,334,183|7:271563,92,121,0,334,185;268236,2,122,0,334,186;159234,1.8,39,0,334,206|8:268218,30.6,18,0,334,188;251137,13.8,125,0,334,198;159259,12,39,0,334,207|9:239648,74.8,123,0,331,46;268228,11.5,3,0,334,191;251127,5.2,41,0,334,190|10:271565,86.6,124,0,344,192;159247,4,129,0,334,208;273773,3.2,130,0,334,209|11:251136,27.6,23,0,334,31;268252,8.4,5,0,334,32;268249,7.4,5,0,334,36;273792,6.8,23,0,334,26;240949,5.5,29,0,331,39;268266,5.1,5,0,334,29;252258,3.7,25,0,334,28;162544,3.2,28,0,334,37;251148,3.2,23,0,334,34;272149,2.9,27,0,321,42;251194,2.5,23,0,334,38;159459,2.2,24,0,334,27;272150,1.7,27,0,321,40;272148,1.2,27,0,321,41;272147,0.9,27,0,321,35|12:158366,19.8,23,0,334,30;268249,9.7,5,0,334,36;268252,7.8,5,0,334,32;273792,6.3,23,0,334,26;240949,6.1,29,0,331,39;252258,4.8,25,0,334,28;272149,4.5,27,0,321,42;251148,4.1,23,0,334,34;268266,4,5,0,334,29;159459,1.8,24,0,334,27;162544,1.7,28,0,334,37;272150,1.4,27,0,321,40;272147,1.1,27,0,321,35;251194,1.1,23,0,334,38;272148,0.6,27,0,321,41|13:250215,38.1,33,0,334;270167,14.9,36,0,334,87;270168,5.7,30,0,344,44;273796,2.8,33,0,334;250224,2.6,33,0,334;250214,2.2,33,0,334;251792,0.9,37,0,321,0,19,3,0,1320,0;270169,0.9,30,0,344,114;274493,0.5,37,0,321|14:270164,42.1,36,0,334;270168,8.1,30,0,344,44;250224,3.2,33,0,334;250214,1.8,33,0,334;270161,1.7,82,0,334;273796,1.4,33,0,334;274493,1.1,37,0,321;250259,0.6,78,0,334;251792,0.6,37,0,321,0,19,3,0,1320,0|15:251132,34.3,39,0,334,58;239656,14.6,38,0,331,46;193763,12.9,39,0,334,47|16:271092,49.3,30,0,344,62;268203,4.9,70,0,334,90|17:245769,81,83,0,331,63;268263,8.6,36,0,334,116;268197,6.8,36,0,334,115",
        gems = {
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 25.8 },
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 15.7 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 15.4 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 74.8 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 73.3 },
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 15.4 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 98.3 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 86.5 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 76.2 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 15.2 },
            },
            [10] = {
                { id = 5447, usagePct = 49.1 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 93.8 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 93.8 },
            },
            [16] = {
                { id = 8689, usagePct = 44.4 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 39.5 },
            },
        },
    },
    ["MONK/BREWMASTER/Shado-Pan"] = {
        className = "MONK",
        specName = "BREWMASTER",
        heroTalent = "Shado-Pan",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.4, mastery = 0.9, versatility = 0.3 },
        targetStatPercents = { crit = 44.1, haste = 6.8, mastery = 23.8, versatility = 25.4 },
        targetStatPercentsMplus = { crit = 39.9, haste = 4.8, mastery = 20.7, versatility = 34.6 },
        targetStatPercentsMplusFarm = { crit = 40.8, haste = 7.1, mastery = 24.2, versatility = 27.8 },
        _pb = "1:271519,86.1,131,0,344,210;271875,6,54,0,344,69;268219,3.2,3,0,334,211|2:268265,68,4,0,344,4;251234,15.1,23,0,334,51;271638,7.1,71,0,334,92|3:271517,85.5,55,0,334,212;251146,4.9,45,0,321,123;268246,4.3,18,0,334,72|5:271522,89.8,132,0,334,213;251226,3.4,45,0,321,103;244570,3.4,58,0,331,11|6:268227,27.3,3,0,334,76;251189,17.1,75,0,334,214;271436,13.9,72,0,334,94|7:271518,89.1,133,0,344,215;251130,3.4,39,0,334,80;251198,2.5,45,0,321,216|8:244569,36.8,63,0,331,73;159304,16,64,0,334,217;159327,12.2,39,0,334,81|9:244576,53.8,65,0,331,46;159300,14.6,41,0,334,218;268240,11.9,66,0,334,83|10:271520,86,134,0,334,219;193758,4.6,45,0,321,107;268234,3.1,18,0,334,85|11:251148,25.7,23,0,334,34;251136,6.3,23,0,334,31;158366,4.8,23,0,334,30;240949,3.9,29,0,331,39;272148,3.4,27,0,321,41;268252,3.1,5,0,334,32;272149,2.9,27,0,321,42;251194,2.9,23,0,334,38;162544,1.4,28,0,334,37;268249,1.1,5,0,334,36|12:251513,42.4,26,0,331,33;240949,5.7,29,0,331,39;158366,5.7,23,0,334,30;272148,5.2,27,0,321,41;251136,4.8,23,0,334,31;162544,2.3,28,0,334,37;268249,1.5,5,0,334,36;251194,1.1,23,0,334,38;268252,0.9,5,0,334,32;272149,0.8,27,0,321,42|13:270175,37.9,30,0,344,43;270168,18,30,0,344,44;270173,11.9,30,0,344;270160,3.7,31,0,334;270164,3.1,36,0,334;250215,2.2,33,0,334;270166,2,36,0,334;270174,1.8,77,0,334,108;250214,0.9,33,0,334;250228,0.8,33,0,334;270165,0.8,31,0,334;273796,0.5,33,0,334|14:270173,20.8,30,0,344;250245,17.4,35,0,334;270168,16.5,30,0,344,44;270164,5.5,36,0,334;270166,3.5,36,0,334;270174,2.3,77,0,334,108;250228,1.7,33,0,334;270160,1.2,31,0,334;251792,0.9,37,0,321,0,19,3,0,1320,0;250214,0.6,33,0,334;270165,0.5,31,0,334|15:268248,39,18,0,334,170;251132,13.3,39,0,334,58;159288,9.4,39,0,334,202|16:268215,60.6,87,0,344,120;268199,17.3,36,0,334,121;237847,9.7,111,0,331,2",
        gems = {
            { id = 240910, nameCn = "无瑕万能榴石", usagePct = 38 },
            { id = 240914, nameCn = "无瑕致命青金石", usagePct = 27.9 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 21.7 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 85.7 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 84.5 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 97.4 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 94.9 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 83.1 },
            },
            [10] = {
                { id = 4732, usagePct = 43.8 },
                { id = 5935, usagePct = 31.2 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 78.2 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 78.2 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 67.9 },
                { id = 8689, usagePct = 19.6 },
            },
            [17] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 72.7 },
            },
        },
    },
    ["MONK/MISTWEAVER/Conduit of the Celestials"] = {
        className = "MONK",
        specName = "MISTWEAVER",
        heroTalent = "Conduit of the Celestials",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.7, haste = 0.9, mastery = 0.7, versatility = 0.3 },
        targetStatPercents = { crit = 30.6, haste = 49.7, mastery = 10.2, versatility = 9.6 },
        targetStatPercentsMplus = { crit = 17.2, haste = 44.6, mastery = 24.3, versatility = 13.9 },
        targetStatPercentsMplusFarm = { crit = 22.5, haste = 45.2, mastery = 22.2, versatility = 10.1 },
        _pb = "1:271519,84.7,131,0,344,210;271875,14.2,54,0,344,69;273791,0.6,75,0,334,100|2:268265,83.5,4,0,344,4;268250,6.4,5,0,334,5;273781,4.5,6,0,334,6|3:271517,91.1,55,0,334,212;244572,3.5,56,0,331,73;251223,2.9,39,0,334,102|5:271522,84.1,132,0,334,213;268235,4.6,18,0,334,75;244570,4.3,58,0,331,11|6:244573,35,135,0,331,73;159301,20.8,41,0,334,104;271436,10.6,72,0,334,94|7:271518,83.4,133,0,344,215;244574,9.3,62,0,331,11;159313,2.5,39,0,334,220|8:268247,35.6,76,0,334,106;251153,20.5,64,0,334,82;244569,18,63,0,331,73|9:244576,37.5,65,0,331,46;268240,35,66,0,334,83;251135,12.6,67,0,334,47|10:271520,90.1,134,0,334,219;251124,3.2,64,0,334,86;193758,1.4,45,0,321,107|11:273792,29.6,23,0,334,26;268266,21.6,5,0,334,29;159459,15.2,24,0,334,27;268252,8.4,5,0,334,32;240949,4.9,29,0,331,39;251148,4.3,23,0,334,34;252258,4.2,25,0,334,28;268249,2.4,5,0,334,36;251136,1.4,23,0,334,31;272148,1.3,27,0,321,41;272147,0.8,27,0,321,35;162544,0.7,28,0,334,37;251194,0.6,23,0,334,38|12:268252,7.7,5,0,334,32;240949,6.6,29,0,331,39;252258,6.4,25,0,334,28;251148,4.3,23,0,334,34;272147,1.4,27,0,321,35;272150,1.4,27,0,321,40;251136,0.8,23,0,334,31;251194,0.8,23,0,334,38;162544,0.7,28,0,334,37;158366,0.7,23,0,334,30;272148,0.6,27,0,321,41|13:270162,50.9,36,0,334;270171,3.9,104,0,334,158;251792,2.9,37,0,321,0,19,3,0,1320,0;270169,2.9,30,0,344,114;250248,1.4,33,0,334;250215,1.1,33,0,334;274493,1,37,0,321;248583,0.7,47,0,321|14:270167,31,36,0,334,87;270164,9.1,36,0,334;270171,6.8,104,0,334,158;248583,5,47,0,321;270169,2.8,30,0,344,114;251792,2.6,37,0,321,0,19,3,0,1320,0;250248,1.8,33,0,334;250214,0.7,33,0,334;250215,0.6,33,0,334|15:239656,27.6,38,0,331,46;193763,23.7,39,0,334,47;268248,17.9,18,0,334,170|16:245770,90,40,0,331,11;268205,4,36,0,334,221",
        gems = {
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 47.6 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 20.4 },
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 8.1 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 75.8 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 19.2 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 78 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 17.6 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 86.7 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 52.5 },
                { id = 7937, nameCn = "奥纹魔线", item = 240155, icon = "inv_12_tailoring_spellthread_violet_spellthread", usagePct = 43.9 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 77.2 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 21.5 },
            },
            [11] = {
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 71.8 },
            },
            [12] = {
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 71.8 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 87.1 },
            },
        },
    },
    ["MONK/WINDWALKER/Conduit of the Celestials"] = {
        className = "MONK",
        specName = "WINDWALKER",
        heroTalent = "Conduit of the Celestials",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.6, haste = 0.5, mastery = 0.9, versatility = 0.3 },
        targetStatPercents = { crit = 26.9, haste = 32.2, mastery = 37.4, versatility = 3.5 },
        targetStatPercentsMplus = { crit = 25.7, haste = 28.6, mastery = 40.3, versatility = 5.4 },
        targetStatPercentsMplusFarm = { crit = 27.3, haste = 27.9, mastery = 41.5, versatility = 3.4 },
        _pb = "1:271519,87.3,131,0,344,210;271875,12,54,0,344,69;271438,0.5,14,0,334,91|2:268265,91,4,0,344,4;251142,3.1,42,0,334,52;268251,2.3,90,0,334,127|3:271517,94.1,55,0,334,212;268246,3.1,18,0,334,72;244572,1.8,56,0,331,73|5:271522,94.6,132,0,334,213;244570,3,58,0,331,11;268235,2.1,18,0,334,75|6:268256,26.1,59,0,344,77;268227,24.9,3,0,334,76;271516,15.2,60,0,344,222|7:271518,76.7,133,0,344,215;244574,11.8,62,0,331,11;268225,6.8,12,0,344,105|8:244569,82.3,63,0,331,73;268261,8,18,0,334,18;159327,3.2,39,0,334,81|9:244576,75.6,65,0,331,46;268240,11.7,66,0,334,83;251135,6.6,67,0,334,47|10:271520,80.7,134,0,334,219;244575,5.9,81,0,331,73;268234,5.3,18,0,334,85|11:268249,14.9,5,0,334,36;158366,14.1,23,0,334,30;273792,8.1,23,0,334,26;268252,6.2,5,0,334,32;251513,3.6,26,0,331,33;272149,3.3,27,0,321,42;240949,3.2,29,0,331,39;272147,2.3,27,0,321,35;251194,1.2,23,0,334,38;171853,0.6,86,0,321,131;162544,0.6,28,0,334,37|12:252258,23.1,25,0,334,28;251136,22,23,0,334,31;158366,11.6,23,0,334,30;273792,6.9,23,0,334,26;240949,5.3,29,0,331,39;272150,4.2,27,0,321,40;268252,3.7,5,0,334,32;272147,3,27,0,321,35;251513,2.7,26,0,331,33;251194,1.2,23,0,334,38;162544,1.2,28,0,334,37;268266,0.6,5,0,334,29;272149,0.6,27,0,321,42|13:270175,75.4,30,0,344,43;250215,1.9,33,0,334;270166,1.5,36,0,334;270164,0.5,36,0,334;273796,0.4,33,0,334;250259,0.4,78,0,334|14:270173,51,30,0,344;270165,16.1,31,0,334;270166,5.4,36,0,334;270164,1.9,36,0,334;251792,0.5,37,0,321,0,19,3,0,1320,0;250215,0.5,33,0,334;250228,0.5,33,0,334;270168,0.5,30,0,344,44|15:251132,23.7,39,0,334,58;268253,18.3,12,0,344,45;251190,17.6,39,0,334,88|16:268215,91.4,87,0,344,120;268199,3.1,36,0,334,121;237847,2.4,111,0,331,2",
        gems = {
            { id = 240900, nameCn = "无瑕迅捷紫晶", usagePct = 21.7 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 19.9 },
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 17 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 81.4 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 15.2 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 82.8 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.2 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 98.8 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 80.8 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 17.5 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.5 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.5 },
            },
            [16] = {
                { id = 8689, usagePct = 78.6 },
            },
            [17] = {
                { id = 8689, usagePct = 82.9 },
                { id = 8041, nameCn = "奥术精通", icon = "ui_profession_enchanting", usagePct = 17.1 },
            },
        },
    },
    ["PALADIN/HOLY/Herald of the Sun"] = {
        className = "PALADIN",
        specName = "HOLY",
        heroTalent = "Herald of the Sun",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.8, haste = 0.7, mastery = 0.9, versatility = 0.3 },
        targetStatPercents = { crit = 24.9, haste = 30, mastery = 37.2, versatility = 7.8 },
        targetStatPercentsMplus = { crit = 26, haste = 36.4, mastery = 11.1, versatility = 26.5 },
        targetStatPercentsMplusFarm = { crit = 25.9, haste = 32.1, mastery = 31.3, versatility = 10.8 },
        _pb = "1:271465,84.9,106,0,334,223;237832,5.5,2,0,331,2;251126,3,41,0,334,50|2:268265,73.3,4,0,344,4;251142,10,42,0,334,52;268251,3.7,90,0,334,127|3:271463,88.8,7,0,334,224;268226,3.1,9,0,334,9;251138,2.2,39,0,334,53|5:271468,89.8,10,0,344,105;268222,1.8,12,0,344,12|6:159418,17.2,41,0,334,53;237830,17.1,2,0,331,73;268259,16.8,13,0,344,13|7:271464,81.5,15,0,344,225;271878,12,16,0,344,16;272259,2.3,89,0,321,226|8:268260,41.7,18,0,334,20;237828,17.5,19,0,331,19;268245,14.9,18,0,334,18|9:237834,42.2,2,0,331,21;268239,32.9,20,0,334,22;251133,6.1,21,0,321,23|10:271466,76.8,134,0,334,227;237836,8.9,19,0,331,19;268220,3.3,18,0,334,25|11:268249,15.9,5,0,334,36;240949,8.3,29,0,331,39;251136,8.3,23,0,334,31;158366,6.8,23,0,334,30;272150,5.2,27,0,321,40;273792,5.2,23,0,334,26;272147,4.6,27,0,321,35;251194,3.7,23,0,334,38;162544,3.1,28,0,334,37;272149,3.1,27,0,321,42;159459,2.5,24,0,334,27;268266,1.3,5,0,334,29;268252,1,5,0,334,32;251148,0.9,23,0,334,34;272148,0.8,27,0,321,41|12:252258,28.7,25,0,334,28;251136,11.3,23,0,334,31;240949,6.5,29,0,331,39;158366,6.3,23,0,334,30;273792,5.5,23,0,334,26;272150,5,27,0,321,40;251194,4.4,23,0,334,38;272149,4.3,27,0,321,42;162544,3.9,28,0,334,37;272147,2.1,27,0,321,35;268252,1.6,5,0,334,32;159459,1.4,24,0,334,27;268266,0.7,5,0,334,29;251513,0.7,26,0,331,33;272148,0.5,27,0,321,41|13:270162,53.6,36,0,334;250214,3.9,33,0,334;251792,2.3,37,0,321,0,19,3,0,1320,0;270167,2.3,36,0,334,87;274493,1.8,37,0,321;250215,1.4,33,0,334;270171,1.4,104,0,334,158;248583,1,47,0,321;273796,0.9,33,0,334;274495,0.5,37,0,321|14:270164,42.6,36,0,334;270167,6,36,0,334,87;250214,5.2,33,0,334;274493,2.6,37,0,321;251792,2,37,0,321,0,19,3,0,1320,0;250215,1.8,33,0,334;248583,1.8,47,0,321;270171,1.4,104,0,334,158;273796,1.2,33,0,334;250248,0.5,33,0,334;270169,0.5,30,0,344,114|15:251190,21.3,39,0,334,88;251132,18.6,39,0,334,58;239656,14,38,0,331,46|16:237843,58.3,136,0,331,63;268210,22.2,36,0,334,90|17:237831,39.4,38,0,331,63;268262,28.7,32,0,334,228;268196,18.3,137,0,334,229",
        gems = {
            { id = 240900, nameCn = "无瑕迅捷紫晶", usagePct = 26.1 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 16.8 },
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 11 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 60.6 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 34.3 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 62.1 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 34.2 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 68.1 },
                { id = 8013, nameCn = "魔导师印记", icon = "ui_profession_enchanting", usagePct = 31.3 },
            },
            [7] = {
                { id = 7937, nameCn = "奥纹魔线", item = 240155, icon = "inv_12_tailoring_spellthread_violet_spellthread", usagePct = 58.6 },
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 39 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 61.1 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 36.4 },
            },
            [10] = {
                { id = 5445, usagePct = 50 },
            },
            [11] = {
                { id = 7969, nameCn = "祖尔金的精通", icon = "ui_profession_enchanting", usagePct = 51.4 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 27.5 },
            },
            [12] = {
                { id = 7969, nameCn = "祖尔金的精通", icon = "ui_profession_enchanting", usagePct = 51.4 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 27.5 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 62.2 },
                { id = 8689, usagePct = 27.9 },
            },
        },
    },
    ["PALADIN/PROTECTION/Lightsmith"] = {
        className = "PALADIN",
        specName = "PROTECTION",
        heroTalent = "Lightsmith",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { strength = 1, crit = 0.9, haste = 0.7, mastery = 0.6, versatility = 0.3 },
        targetStatPercents = { crit = 37.6, haste = 36.2, mastery = 16.6, versatility = 9.7 },
        targetStatPercentsMplus = { crit = 38.8, haste = 33.2, mastery = 12.7, versatility = 15.4 },
        targetStatPercentsMplusFarm = { crit = 39, haste = 34, mastery = 15.1, versatility = 11.8 },
        _pb = "1:271465,88.3,106,0,334,223;237832,4,2,0,331,2;268229,3.9,3,0,334,3|2:268265,58.7,4,0,344,4;273781,16,6,0,334,6;268250,9.1,5,0,334,5|3:271463,88.7,7,0,334,224;268226,3.2,9,0,334,9;237835,2.3,29,0,331,19|5:271468,89.1,10,0,344,105;268222,3.3,12,0,344,12;237829,2.2,11,0,331,11|6:268259,39.2,13,0,344,13;268244,18.5,3,0,334,14;237830,9.9,2,0,331,73|7:271464,79.5,15,0,344,225;271878,15.9,16,0,344,16;237833,1.3,51,0,331,2|8:237828,49,19,0,331,19;268245,22,18,0,334,18;273777,8.2,39,0,334,230|9:237834,67.5,2,0,331,21;268239,9.8,20,0,334,22;251133,6.3,21,0,321,23|10:271466,82.5,134,0,334,227;268220,5.5,18,0,334,25;251221,3,45,0,321,231|11:273792,27.3,23,0,334,26;252258,11.6,25,0,334,28;268252,9.8,5,0,334,32;159459,9,24,0,334,27;251136,7.8,23,0,334,31;240949,7.8,29,0,331,39;251148,6.7,23,0,334,34;268266,4.9,5,0,334,29;158366,4,23,0,334,30;162544,2.1,28,0,334,37;251513,1.8,26,0,331,33;272147,1.7,27,0,321,35;272148,1.5,27,0,321,41;251194,1.2,23,0,334,38;268249,0.9,5,0,334,36;272150,0.6,27,0,321,40;272149,0.5,27,0,321,42|12:159459,9.4,24,0,334,27;251136,9.1,23,0,334,31;251148,8.1,23,0,334,34;240949,7.7,29,0,331,39;268252,4.9,5,0,334,32;268266,4.2,5,0,334,29;158366,3.9,23,0,334,30;251513,3.1,26,0,331,33;162544,2.6,28,0,334,37;251194,2.2,23,0,334,38;268249,2.2,5,0,334,36;272147,1.3,27,0,321,35;272148,1.2,27,0,321,41;272150,0.8,27,0,321,40|13:270175,32,30,0,344,43;273796,12.3,33,0,334;270163,4,32,0,334;270165,4,31,0,334;270168,3.2,30,0,344,44;274493,0.8,37,0,321;193762,0.6,52,0,321,175;270160,0.5,31,0,334;270164,0.5,36,0,334|14:270173,45.2,30,0,344;250245,14.1,35,0,334;273796,5.6,33,0,334;270163,4.4,32,0,334;270168,3.5,30,0,344,44;270165,3.2,31,0,334;270164,2.1,36,0,334;193762,0.9,52,0,321,175;250228,0.9,33,0,334;250259,0.8,78,0,334|15:268253,28,12,0,344,45;193763,21.7,39,0,334,47;271460,10,48,0,344,232|16:268209,61,49,0,344,60;268202,15.7,50,0,344,62;237839,14.1,51,0,331,63|17:268196,41.1,137,0,334,229;237831,39.2,38,0,331,63;268262,14.5,32,0,334,228",
        gems = {
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 25.2 },
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 23.1 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 20.4 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 68.2 },
                { id = 7991, nameCn = "强化加速祝福", icon = "ui_profession_enchanting", usagePct = 15.5 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 68.6 },
                { id = 7973, nameCn = "埃基尔松的迅捷", icon = "ui_profession_enchanting", usagePct = 17.5 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 91.8 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 91.9 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 65 },
                { id = 8019, nameCn = "远行者的狩猎", icon = "ui_profession_enchanting", usagePct = 21.8 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 67 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 18 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 67 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 18 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 60.3 },
                { id = 8689, usagePct = 20.5 },
            },
        },
    },
    ["PALADIN/RETRIBUTION/Herald of the Sun"] = {
        className = "PALADIN",
        specName = "RETRIBUTION",
        heroTalent = "Herald of the Sun",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { strength = 1, crit = 0.9, haste = 0.5, mastery = 0.7, versatility = 0.3 },
        targetStatPercents = { crit = 32.4, haste = 26.8, mastery = 37.3, versatility = 3.5 },
        targetStatPercentsMplus = { crit = 26.6, haste = 25.8, mastery = 42.1, versatility = 5.5 },
        targetStatPercentsMplusFarm = { crit = 31.3, haste = 27, mastery = 37.1, versatility = 4.6 },
        _pb = "1:271465,91.6,106,0,334,223;268229,3.2,3,0,334,3;237832,2.3,2,0,331,2|2:268265,77.4,4,0,344,4;251142,8.8,42,0,334,52;251173,2.8,23,0,334,101|3:271463,89.9,7,0,334,224;268226,3.4,9,0,334,9;251138,3,39,0,334,53|5:271468,89.8,10,0,344,105;268222,6.9,12,0,344,12;237829,1.5,11,0,331,11|6:268259,49.1,13,0,344,13;159418,12.7,41,0,334,53;271445,12.6,14,0,334,15|7:271464,82.3,15,0,344,225;271878,12.8,16,0,344,16;268224,3,17,0,334,17|8:268260,48,18,0,334,20;237828,18.6,19,0,331,19;268245,14.5,18,0,334,18|9:237834,73.2,2,0,331,21;268239,12.6,20,0,334,22;251133,4.7,21,0,321,23|10:271466,87.3,134,0,334,227;237836,3.7,19,0,331,19;159413,2.6,45,0,321,56|11:252258,28.8,25,0,334,28;273792,7,23,0,334,26;158366,4.3,23,0,334,30;240949,3.9,29,0,331,39;251136,3.7,23,0,334,31;272150,2.5,27,0,321,40;272147,2.3,27,0,321,35;272149,1,27,0,321,42;268266,0.7,5,0,334,29;251194,0.6,23,0,334,38;159459,0.6,24,0,334,27|12:251513,44,26,0,331,33;268249,8.8,5,0,334,36;273792,4.6,23,0,334,26;251136,2.9,23,0,334,31;272150,2.8,27,0,321,40;272147,2.5,27,0,321,35;272149,2.3,27,0,321,42;240949,1.7,29,0,331,39;158366,1.5,23,0,334,30;268252,0.7,5,0,334,32;268266,0.6,5,0,334,29|13:270175,54.5,30,0,344,43;273796,7,33,0,334;270165,2.8,31,0,334;270164,1,36,0,334;274493,0.8,37,0,321;270168,0.6,30,0,344,44;193701,0,138,0,298|14:270173,57.8,30,0,344;270165,4.4,31,0,334;273796,3.7,33,0,334;270164,1.4,36,0,334;274493,0.7,37,0,321;270168,0.6,30,0,344,44|15:268253,34.5,12,0,344,45;271460,16.8,48,0,344,232;251190,16.7,39,0,334,88|16:268213,76.6,30,0,344,48;237846,9.9,40,0,331,2;268214,8.8,36,0,334,49",
        gems = {
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 53.7 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 20.4 },
            { id = 240900, nameCn = "无瑕迅捷紫晶", usagePct = 7.4 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 79.3 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 78.8 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 98.2 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 97.3 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 76.1 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.2 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.2 },
            },
            [16] = {
                { id = 8689, usagePct = 73.8 },
            },
        },
    },
    ["PRIEST/DISCIPLINE/Voidweaver"] = {
        className = "PRIEST",
        specName = "DISCIPLINE",
        heroTalent = "Voidweaver",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.6, haste = 0.9, mastery = 0.6, versatility = 0.3 },
        targetStatPercents = { crit = 20.2, haste = 51.4, mastery = 23.7, versatility = 4.7 },
        targetStatPercentsMplus = { crit = 25.1, haste = 42, mastery = 27.2, versatility = 5.8 },
        targetStatPercentsMplusFarm = { crit = 23.9, haste = 40.8, mastery = 30.6, versatility = 4.7 },
        _pb = "1:271555,77.9,139,0,334,223;271874,19.9,116,0,344,177;268242,1.8,102,0,334,178|2:268265,83.8,4,0,344,4;268250,5.5,5,0,334,5;273781,3.9,6,0,334,6|3:271553,88.6,117,0,334,233;239650,5.8,58,0,331,73;268241,2.6,18,0,334,180|5:271558,79,80,0,334,234;239655,19,118,0,331,11;273785,0.9,39,0,334,196|6:239649,30.8,65,0,331,73;268257,25.5,120,0,334,184;251222,13.5,41,0,334,82|7:271554,83.5,140,0,334,235;239651,10.1,81,0,331,2;273786,2.1,45,0,321,236|8:268255,33.2,12,0,344,189;251219,21.4,64,0,334,237;251137,10.3,125,0,334,198|9:239648,48.1,123,0,331,46;251127,24.4,41,0,334,190;268228,11.2,3,0,334,191|10:271556,86.4,124,0,344,238;268243,6.5,12,0,344,193;239653,2.2,58,0,331,73|11:252258,36.2,25,0,334,28;268266,17.5,5,0,334,29;159459,4.8,24,0,334,27;240949,4.7,29,0,331,39;272147,4.2,27,0,321,35;251136,1.4,23,0,334,31;268252,0.9,5,0,334,32|12:273792,26,23,0,334,26;159459,10.2,24,0,334,27;240949,4.2,29,0,331,39;272147,3.4,27,0,321,35;268252,2.4,5,0,334,32;251136,0.7,23,0,334,31;272150,0.7,27,0,321,40|13:270169,22.6,30,0,344,114;270162,20,36,0,334;270164,15.2,36,0,334;251792,3.8,37,0,321,0,19,3,0,1320,0;248583,3.1,47,0,321;274493,1.8,37,0,321;250214,1.2,33,0,334;270171,0.7,104,0,334,158;250215,0.7,33,0,334|14:270167,43,36,0,334,87;270164,13.2,36,0,334;270169,12.9,30,0,344,114;251792,6.4,37,0,321,0,19,3,0,1320,0;248583,2.5,47,0,321;250214,2.1,33,0,334;250215,1.4,33,0,334;274493,1.2,37,0,321|15:251190,33.7,39,0,334,88;193763,17.6,39,0,334,47;239656,12.3,38,0,331,46|16:271092,76.9,30,0,344,62;237838,3.3,141,0,331,63|17:245769,84.5,83,0,331,63;268197,9,36,0,334,115;268263,3,36,0,334,116",
        gems = {
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 37 },
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 20 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 19.3 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 75.2 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 17.9 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 77.3 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 15.3 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 60.4 },
                { id = 8013, nameCn = "魔导师印记", icon = "ui_profession_enchanting", usagePct = 38.9 },
            },
            [7] = {
                { id = 7937, nameCn = "奥纹魔线", item = 240155, icon = "inv_12_tailoring_spellthread_violet_spellthread", usagePct = 64.5 },
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 34.9 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 75.6 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 18.5 },
            },
            [10] = {
                { id = 3238, usagePct = 14.3 },
            },
            [11] = {
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 72.9 },
            },
            [12] = {
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 72.9 },
            },
            [16] = {
                { id = 7983, nameCn = "狂战士之怒", icon = "ui_profession_enchanting", usagePct = 42.2 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 37.1 },
            },
        },
    },
    ["PRIEST/HOLY/Oracle"] = {
        className = "PRIEST",
        specName = "HOLY",
        heroTalent = "Oracle",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.9, haste = 0.6, mastery = 0.8, versatility = 0.3 },
        targetStatPercents = { crit = 38, haste = 23.4, mastery = 31.5, versatility = 7 },
        targetStatPercentsMplus = { crit = 29.5, haste = 33.4, mastery = 23.3, versatility = 13.8 },
        targetStatPercentsMplusFarm = { crit = 35.1, haste = 26, mastery = 29.7, versatility = 9.2 },
        _pb = "1:271555,75.5,139,0,334,223;271874,18.9,116,0,344,177;268242,3.5,102,0,334,178|2:268265,76.1,4,0,344,4;251234,7.5,23,0,334,51;251142,3.6,42,0,334,52|3:271553,87.6,117,0,334,233;239650,3.8,58,0,331,73;271434,2.7,8,0,334,239|5:271558,85.8,80,0,334,234;239655,5.7,118,0,331,11;268221,4.7,18,0,334,205|6:239649,38.5,65,0,331,73;268232,13.5,20,0,334,183;251222,12.1,41,0,334,82|7:271554,85,140,0,334,235;239651,3.8,81,0,331,2;268236,3.2,122,0,334,186|8:268218,37.2,18,0,334,188;159259,11.7,39,0,334,207;251219,10.5,64,0,334,237|9:239648,50.4,123,0,331,46;268228,20.2,3,0,334,191;251154,9.2,41,0,334,240|10:271556,87.7,124,0,344,238;273773,3.6,130,0,334,209;159247,2.2,129,0,334,208|11:251136,27.1,23,0,334,31;158366,19.4,23,0,334,30;273792,9.3,23,0,334,26;268249,6.9,5,0,334,36;268252,6.5,5,0,334,32;252258,5.1,25,0,334,28;240949,4.9,29,0,331,39;251148,4.3,23,0,334,34;272149,4,27,0,321,42;251194,2.8,23,0,334,38;162544,2,28,0,334,37;272147,1.8,27,0,321,35;272150,0.9,27,0,321,40;159459,0.8,24,0,334,27;268266,0.8,5,0,334,29;272148,0.7,27,0,321,41|12:268252,6.5,5,0,334,32;268249,6.2,5,0,334,36;252258,5.8,25,0,334,28;240949,5.3,29,0,331,39;162544,4.3,28,0,334,37;251148,3.2,23,0,334,34;251194,3.2,23,0,334,38;272149,2.8,27,0,321,42;272147,2.2,27,0,321,35;272148,1.5,27,0,321,41;272150,1.2,27,0,321,40;268266,1.2,5,0,334,29;251513,0.5,26,0,331,33|13:270162,45.4,36,0,334;250214,2.4,33,0,334;250215,2.4,33,0,334;270169,2.4,30,0,344,114;274493,2.3,37,0,321;248583,1.9,47,0,321;251792,1.6,37,0,321,0,19,3,0,1320,0;270171,1.1,104,0,334,158;273796,0.5,33,0,334|14:270164,30.7,36,0,334;270167,16.3,36,0,334,87;250214,2.8,33,0,334;274493,2.3,37,0,321;248583,2.2,47,0,321;270169,1.9,30,0,344,114;251792,1.6,37,0,321,0,19,3,0,1320,0;250215,1.2,33,0,334;273796,0.9,33,0,334;193757,0.7,33,0,334|15:251132,31.3,39,0,334,58;239656,15.2,38,0,331,46;193763,11.7,39,0,334,47|16:271092,47.4,30,0,344,62;268210,6.6,36,0,334,90|17:245769,70.8,83,0,331,63;268263,14.6,36,0,334,116;268197,6.5,36,0,334,115",
        gems = {
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 21.6 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 19.9 },
            { id = 240910, nameCn = "无瑕万能榴石", usagePct = 18.5 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 76.8 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 17.5 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 76.7 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 17.3 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 79.1 },
                { id = 8013, nameCn = "魔导师印记", icon = "ui_profession_enchanting", usagePct = 20.5 },
            },
            [7] = {
                { id = 7937, nameCn = "奥纹魔线", item = 240155, icon = "inv_12_tailoring_spellthread_violet_spellthread", usagePct = 53.2 },
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 46.2 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 74.6 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 20.4 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 40.4 },
                { id = 7997, nameCn = "自然之怒", icon = "ui_profession_enchanting", usagePct = 30.3 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 40.4 },
                { id = 7997, nameCn = "自然之怒", icon = "ui_profession_enchanting", usagePct = 30.3 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 70.3 },
                { id = 8689, usagePct = 20.1 },
            },
        },
    },
    ["PRIEST/SHADOW/Archon"] = {
        className = "PRIEST",
        specName = "SHADOW",
        heroTalent = "Archon",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.9, haste = 0.7, mastery = 0.9, versatility = 0.3 },
        targetStatPercents = { crit = 26.3, haste = 30.5, mastery = 39.9, versatility = 3.3 },
        targetStatPercentsMplus = { crit = 27.3, haste = 29.8, mastery = 38.8, versatility = 4.1 },
        targetStatPercentsMplusFarm = { crit = 26.1, haste = 31.4, mastery = 38.6, versatility = 3.9 },
        _pb = "1:271555,90.2,139,0,334,223;271874,9.3,116,0,344,177;251232,0.3,41,0,334,195|2:268265,95.2,4,0,344,4;271638,1.1,71,0,334,92;268250,0.9,5,0,334,5|3:271553,89.7,117,0,334,233;239045,2.9,39,0,334,204;271434,2.7,8,0,334,239|5:271558,92.3,80,0,334,234;268221,3.3,18,0,334,205;239655,1.8,118,0,331,11|6:239649,55.6,65,0,331,73;268257,12.4,120,0,334,184;239664,8,142,0,331,241|7:271554,73.7,140,0,334,235;239651,17,81,0,331,2;268236,2.2,122,0,334,186|8:268218,24.5,18,0,334,188;251137,19.9,125,0,334,198;268255,19.6,12,0,344,189|9:239648,57.8,123,0,331,46;268228,19.1,3,0,334,191;251127,9.3,41,0,334,190|10:271556,87.8,124,0,344,238;268243,4.3,12,0,344,193;273773,3.8,130,0,334,209|11:251136,23.2,23,0,334,31;268249,16.7,5,0,334,36;273792,12.2,23,0,334,26;158366,8.7,23,0,334,30;268252,4.6,5,0,334,32;240949,4.5,29,0,331,39;272147,2.6,27,0,321,35;272150,2.2,27,0,321,40;251513,1.3,26,0,331,33;272149,0.9,27,0,321,42;162544,0.8,28,0,334,37;251194,0.8,23,0,334,38;268266,0.6,5,0,334,29|12:252258,20.5,25,0,334,28;273792,10.5,23,0,334,26;158366,10.5,23,0,334,30;268252,7,5,0,334,32;240949,5.6,29,0,331,39;272147,2.8,27,0,321,35;272150,2.2,27,0,321,40;272149,1.1,27,0,321,42;251194,0.8,23,0,334,38;251513,0.6,26,0,331,33;162544,0.6,28,0,334,37|13:250215,39.9,33,0,334;273796,14.4,33,0,334;270169,8.3,30,0,344,114;274493,0.4,37,0,321;250224,0.3,33,0,334|14:270164,32,36,0,334;270167,27.6,36,0,334,87;273796,9.6,33,0,334;270169,6.5,30,0,344,114;250214,1.7,33,0,334;274493,0.8,37,0,321|15:251132,24.5,39,0,334,58;268253,17.5,12,0,344,45;239656,15.2,38,0,331,46|16:271092,74.5,30,0,344,62|17:245769,48.6,83,0,331,63;268197,32.8,36,0,334,115;268263,16.1,36,0,334,116",
        gems = {
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 19.5 },
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 17.7 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 16.7 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 60.6 },
                { id = 7991, nameCn = "强化加速祝福", icon = "ui_profession_enchanting", usagePct = 21.4 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 54.7 },
                { id = 7973, nameCn = "埃基尔松的迅捷", icon = "ui_profession_enchanting", usagePct = 28.2 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.1 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 97.1 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 58.6 },
                { id = 8019, nameCn = "远行者的狩猎", icon = "ui_profession_enchanting", usagePct = 26.3 },
            },
            [10] = {
                { id = 3238, usagePct = 33.3 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 91.3 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 91.3 },
            },
            [16] = {
                { id = 8689, usagePct = 66 },
                { id = 8041, nameCn = "奥术精通", icon = "ui_profession_enchanting", usagePct = 21.5 },
            },
        },
    },
    ["ROGUE/ASSASSINATION/Fatebound"] = {
        className = "ROGUE",
        specName = "ASSASSINATION",
        heroTalent = "Fatebound",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.6, mastery = 0.5, versatility = 0.4 },
        targetStatPercents = { crit = 41.8, haste = 32.6, mastery = 19.9, versatility = 5.6 },
        targetStatPercentsMplus = { crit = 41.7, haste = 29.1, mastery = 21.1, versatility = 8.1 },
        targetStatPercentsMplusFarm = { crit = 43.4, haste = 29.6, mastery = 21.9, versatility = 5.1 },
        _pb = "1:271510,84.1,53,0,344,242;271875,14.2,54,0,344,69;271438,0.9,14,0,334,91|2:268265,88.3,4,0,344,4;273781,6.8,6,0,334,6;251173,1.4,23,0,334,101|3:271508,86.3,7,0,334,243;268246,5.5,18,0,334,72;251223,4.5,39,0,334,102|5:271513,92.3,80,0,334,244;251159,2.3,91,0,321,128;268235,2.1,18,0,334,75|6:268227,25.3,3,0,334,76;271436,17.2,72,0,334,94;268256,13.6,59,0,344,77|7:271509,87.5,61,0,344,245;251130,4.2,39,0,334,80;268225,3.1,12,0,344,105|8:268261,25.5,18,0,334,18;244569,23.6,63,0,331,73;251153,18,64,0,334,82|9:244576,74.1,65,0,331,46;268240,13.1,66,0,334,83;251183,4.6,73,0,324,95|10:271511,90.2,68,0,334,187;251124,3.3,64,0,334,86;268234,2.2,18,0,334,85|11:251136,20.2,23,0,334,31;158366,12.2,23,0,334,30;268249,8.2,5,0,334,36;240949,7.7,29,0,331,39;252258,3.9,25,0,334,28;251148,1.5,23,0,334,34;272149,1.3,27,0,321,42;159459,1,24,0,334,27;268266,0.9,5,0,334,29;162544,0.9,28,0,334,37|12:273792,33.5,23,0,334,26;268252,16.9,5,0,334,32;158366,10.3,23,0,334,30;240949,6.4,29,0,331,39;268249,6.3,5,0,334,36;252258,5.8,25,0,334,28;272150,1.5,27,0,321,40;159459,0.9,24,0,334,27;272149,0.8,27,0,321,42;171691,0.6,143,0,321,246;272147,0.6,27,0,321,35;251148,0.6,23,0,334,34;268266,0.5,5,0,334,29|13:270175,63.9,30,0,344,43;270173,5.4,30,0,344;273796,2.4,33,0,334;270166,0.6,36,0,334;159617,0.5,33,0,334;270164,0.5,36,0,334|14:270168,33.1,30,0,344,44;270165,18.1,31,0,334;270173,12.3,30,0,344;270164,2.6,36,0,334;273796,1.5,33,0,334;270166,0.8,36,0,334;250228,0.5,33,0,334|15:251132,26.6,39,0,334,58;193763,23.6,39,0,334,47;251190,13.9,39,0,334,88|16:237837,45.2,144,0,331,63;271093,42.9,30,0,344,247;268204,6.8,36,0,334,248|17:237837,51.3,144,0,331,63;271093,26.1,30,0,344,247;275070,17.7,145,0,334,249",
        gems = {
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 29.9 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 16.6 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 10.9 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 68.5 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 24 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 70.9 },
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 21.8 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.4 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 98.7 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 69.1 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 22.1 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99 },
            },
            [16] = {
                { id = 8689, usagePct = 89.6 },
            },
            [17] = {
                { id = 8689, usagePct = 90 },
            },
        },
    },
    ["ROGUE/OUTLAW/Trickster"] = {
        className = "ROGUE",
        specName = "OUTLAW",
        heroTalent = "Trickster",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.8, mastery = 0.5, versatility = 0.4 },
        targetStatPercents = { crit = 44.4, haste = 33.7, mastery = 5.2, versatility = 16.7 },
        targetStatPercentsMplus = { crit = 42.5, haste = 29.3, mastery = 6.9, versatility = 21.3 },
        targetStatPercentsMplusFarm = { crit = 42.5, haste = 31.7, mastery = 6.7, versatility = 19.1 },
        _pb = "1:271510,75.1,53,0,344,242;271875,20.3,54,0,344,69;273791,1.8,75,0,334,100|2:268265,60.2,4,0,344,4;273781,27.9,6,0,334,6;251173,8.6,23,0,334,101|3:271508,93.4,7,0,334,243;273774,3,45,0,321,107;251146,1.2,45,0,321,123|5:271513,91.9,80,0,334,244;251226,4,45,0,321,103;244570,3,58,0,331,11|6:244573,50.9,135,0,331,73;159301,16.6,41,0,334,104;251189,8.9,75,0,334,214|7:271509,89.1,61,0,344,245;159313,4.5,39,0,334,220;251130,2,39,0,334,80|8:244569,57.8,63,0,331,73;251153,15.6,64,0,334,82;268261,11.8,18,0,334,18|9:244576,37.3,65,0,331,46;268240,37.1,66,0,334,83;159300,11.9,41,0,334,218|10:271511,81.8,68,0,334,187;244575,7.1,81,0,331,73;251124,5,64,0,334,86|11:268252,18,5,0,334,32;159459,7.7,24,0,334,27;268266,7.1,5,0,334,29;240949,4.4,29,0,331,39;272148,2,27,0,321,41;158366,0.8,23,0,334,30|12:251148,31.9,23,0,334,34;273792,30.3,23,0,334,26;159459,11.1,24,0,334,27;268252,8.1,5,0,334,32;240949,6.2,29,0,331,39;268266,3.9,5,0,334,29;272148,3,27,0,321,41;251136,1.7,23,0,334,31;158366,1,23,0,334,30|13:270175,47.1,30,0,344,43;270166,4.4,36,0,334;270165,3.9,31,0,334;159617,3,33,0,334;250225,1.8,52,0,321;250215,1.8,33,0,334;270164,1.5,36,0,334;250228,1.3,33,0,334;250259,1.3,78,0,334;270168,0.5,30,0,344,44|14:270173,43.9,30,0,344;270165,8.9,31,0,334;159617,5.2,33,0,334;270166,4.2,36,0,334;270164,4,36,0,334;250215,3.7,33,0,334;250228,2,33,0,334;250225,2,52,0,321;250259,1.7,78,0,334;270168,0.7,30,0,344,44;273796,0.7,33,0,334;265657,0.7,37,0,321|15:268248,28.4,18,0,334,170;193763,28.2,39,0,334,47;239656,13.6,38,0,331,46|16:268209,55,49,0,344,60;237839,24.2,51,0,331,63;270930,12.6,36,0,334,109|17:271093,35.8,30,0,344,247;275070,32.1,145,0,334,249;237839,12.6,51,0,331,63",
        gems = {
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 24.4 },
            { id = 240910, nameCn = "无瑕万能榴石", usagePct = 18.1 },
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 18.1 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 58.9 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 33 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 55.4 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 38.7 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 98.8 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 98.8 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 56.9 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 36.4 },
            },
            [10] = {
                { id = 2603, usagePct = 11.1 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.4 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.4 },
            },
            [16] = {
                { id = 8689, usagePct = 69.1 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 26.4 },
            },
            [17] = {
                { id = 8689, usagePct = 71.5 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 24.3 },
            },
        },
    },
    ["ROGUE/SUBTLETY/Deathstalker"] = {
        className = "ROGUE",
        specName = "SUBTLETY",
        heroTalent = "Deathstalker",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.6, mastery = 0.7, versatility = 0.6 },
        targetStatPercents = { crit = 16.7, haste = 26.6, mastery = 39.3, versatility = 17.4 },
        targetStatPercentsMplus = { crit = 22.1, haste = 21.5, mastery = 44.2, versatility = 12.1 },
        targetStatPercentsMplusFarm = { crit = 21.3, haste = 23.5, mastery = 42.8, versatility = 12.4 },
        _pb = "1:271510,87,53,0,344,242;271875,11.5,54,0,344,69;268219,0.7,3,0,334,211|2:268265,90.1,4,0,344,4;251142,6.1,42,0,334,52;268251,1.4,90,0,334,127|3:271508,89.2,7,0,334,243;268246,3.8,18,0,334,72;251146,2.3,45,0,321,123|5:271513,94,80,0,334,244;268235,2.8,18,0,334,75;244570,0.9,58,0,331,11|6:268256,25.8,59,0,344,77;271436,20.4,72,0,334,94;251235,16.2,85,0,334,250|7:271509,82.7,61,0,344,245;268225,5.3,12,0,344,105;244574,4.1,62,0,331,11|8:159304,26.8,64,0,334,217;244569,22.2,63,0,331,73;268247,18.7,76,0,334,106|9:244576,78.9,65,0,331,46;268240,8,66,0,334,83;251135,4.6,67,0,334,47|10:271511,87.7,68,0,334,187;159337,4.1,39,0,334,130;268234,3.9,18,0,334,85|11:251194,32.6,23,0,334,38;252258,9.6,25,0,334,28;240949,8.5,29,0,331,39;268249,7.6,5,0,334,36;272150,4.6,27,0,321,40;158366,1.9,23,0,334,30;272149,1.8,27,0,321,42;251136,1.8,23,0,334,31;159459,1.4,24,0,334,27;266317,0.8,126,0,321,201;251148,0.7,23,0,334,34;273792,0.5,23,0,334,26|12:162544,34.1,28,0,334,37;268249,11.1,5,0,334,36;252258,8.5,25,0,334,28;240949,4.1,29,0,331,39;158366,2.7,23,0,334,30;272149,2.2,27,0,321,42;272150,2.2,27,0,321,40;251136,1.9,23,0,334,31;268266,1.1,5,0,334,29;159459,0.7,24,0,334,27;272147,0.5,27,0,321,35|13:270175,69.3,30,0,344,43;273797,1.2,34,0,334;270164,0.9,36,0,334;270168,0.5,30,0,344,44;171646,0.4,114,0,321|14:270165,32.9,31,0,334;270173,28.3,30,0,344;270164,3.7,36,0,334;270166,2.8,36,0,334;270168,1.9,30,0,344,44;273797,0.9,34,0,334;250228,0.4,33,0,334|15:251190,28.8,39,0,334,88;159288,20.8,39,0,334,202;268253,18.8,12,0,344,45|16:237837,47.9,144,0,331,63;271093,36.7,30,0,344,247;268204,9.6,36,0,334,248|17:237837,47.8,144,0,331,63;271093,28.6,30,0,344,247;275070,18.4,145,0,334,249",
        gems = {
            { id = 240900, nameCn = "无瑕迅捷紫晶", usagePct = 19.7 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 17.5 },
            { id = 240902, nameCn = "无瑕万能紫晶", usagePct = 15.9 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 73 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 20.1 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 74.2 },
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 17.9 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.4 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 98.2 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 75.7 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 17.1 },
            },
            [10] = {
                { id = 5932, usagePct = 37.5 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 98.1 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 98.1 },
            },
            [16] = {
                { id = 8689, usagePct = 82.7 },
            },
            [17] = {
                { id = 8689, usagePct = 82.3 },
            },
        },
    },
    ["SHAMAN/ELEMENTAL/Farseer"] = {
        className = "SHAMAN",
        specName = "ELEMENTAL",
        heroTalent = "Farseer",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.9, haste = 0.9, mastery = 0.8, versatility = 0.3 },
        targetStatPercents = { crit = 33.8, haste = 25.7, mastery = 35.3, versatility = 5.2 },
        targetStatPercentsMplus = { crit = 37.8, haste = 22, mastery = 32, versatility = 8.2 },
        targetStatPercentsMplusFarm = { crit = 34.9, haste = 25.6, mastery = 34.3, versatility = 5.3 },
        _pb = "1:271483,90.7,146,0,334,3;268230,4,93,0,334,135;271441,1.8,94,0,334,136|2:268265,92.4,4,0,344,4;273781,1.8,6,0,334,6;251142,1.5,42,0,334,52|3:271481,94.1,107,0,344,251;268231,2.5,12,0,344,138;272252,1,89,0,321,252|5:271486,89,96,0,344,253;271876,10.4,97,0,344,120;273789,0.4,39,0,334,254|6:268254,30.8,3,0,334,142;244581,27.5,98,0,331,139;251228,11.6,147,0,334,255|7:271482,71.3,61,0,344,256;244582,14.4,81,0,331,145;159375,6.4,45,0,321,167|8:244577,29.3,81,0,331,139;268258,28.3,18,0,334,147;268233,14.6,18,0,334,20|9:244584,72.8,98,0,331,149;268217,10.6,3,0,334,150;159380,5.2,99,0,328,151|10:271484,88.8,68,0,334,257;268238,3.3,18,0,334,86;244583,2.9,100,0,331,73|11:251136,25.8,23,0,334,31;268252,14.2,5,0,334,32;158366,12.3,23,0,334,30;252258,8.7,25,0,334,28;268249,5.2,5,0,334,36;240949,4.4,29,0,331,39;251513,2.3,26,0,331,33;272147,1.7,27,0,321,35;251148,1.5,23,0,334,34;272150,1.5,27,0,321,40;268266,1.1,5,0,334,29;272149,0.7,27,0,321,42;272148,0.7,27,0,321,41|12:273792,24,23,0,334,26;158366,14.2,23,0,334,30;268252,11.5,5,0,334,32;252258,10.6,25,0,334,28;268249,7.9,5,0,334,36;251513,4.3,26,0,331,33;240949,4.3,29,0,331,39;272150,2.1,27,0,321,40;272149,1.7,27,0,321,42;272147,1,27,0,321,35|13:273796,56.8,33,0,334;250215,6.8,33,0,334;270167,5.4,36,0,334,87;270169,1.2,30,0,344,114;274493,1,37,0,321;250214,0.6,33,0,334|14:270164,52.2,36,0,334;270167,10.1,36,0,334,87;250215,2.6,33,0,334;250214,2.1,33,0,334;274493,0.7,37,0,321;250224,0.7,33,0,334;248583,0.6,47,0,321|15:251132,30.5,39,0,334,58;193763,14.1,39,0,334,47;239656,13,38,0,331,46|16:271092,65.9,30,0,344,62;268210,3.6,36,0,334,90|17:268196,33.9,137,0,334,229;268262,31.7,32,0,334,228;245769,12,83,0,331,63",
        gems = {
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 21.4 },
            { id = 240898, nameCn = "无瑕致命紫晶", usagePct = 14.4 },
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 10.9 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 86.9 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 89.1 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.2 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 97.6 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 87 },
            },
            [10] = {
                { id = 2603, usagePct = 33.3 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99.2 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99.2 },
            },
            [16] = {
                { id = 8689, usagePct = 84.2 },
            },
        },
    },
    ["SHAMAN/ENHANCEMENT/Stormbringer"] = {
        className = "SHAMAN",
        specName = "ENHANCEMENT",
        heroTalent = "Stormbringer",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { agility = 1, crit = 0.9, haste = 0.8, mastery = 0.8, versatility = 0.3 },
        targetStatPercents = { crit = 27.7, haste = 30, mastery = 36.8, versatility = 5.5 },
        targetStatPercentsMplus = { crit = 25.1, haste = 30.8, mastery = 40.5, versatility = 3.7 },
        targetStatPercentsMplusFarm = { crit = 26.9, haste = 28.9, mastery = 40.3, versatility = 3.8 },
        _pb = "1:271483,80.1,146,0,334,3;244579,13.3,103,0,331,11;268230,2.3,93,0,334,135|2:268265,72.1,4,0,344,4;251142,6.2,42,0,334,52;273781,6,6,0,334,6|3:271481,92.2,107,0,344,251;268231,4.4,12,0,344,138;251184,1.2,45,0,321,258|5:271486,90.2,96,0,344,253;271876,9.5,97,0,344,120;273789,0.2,39,0,334,254|6:268254,37.6,3,0,334,142;251228,26.7,147,0,334,255;244581,10.3,98,0,331,139|7:271482,76.6,61,0,344,256;268237,9.2,12,0,344,146;244582,7.5,81,0,331,145|8:268258,28.1,18,0,334,147;268233,23.7,18,0,334,20;159388,16.7,39,0,334,148|9:244584,76.8,98,0,331,149;268217,8.1,3,0,334,150;159380,5.6,99,0,328,151|10:271484,92.5,68,0,334,257;268238,2.4,18,0,334,86;244583,2.3,100,0,331,73|11:273792,21.6,23,0,334,26;251136,15.8,23,0,334,31;158366,14.5,23,0,334,30;268252,4.7,5,0,334,32;268249,4.5,5,0,334,36;240949,4.4,29,0,331,39;272147,3.6,27,0,321,35;251513,1.1,26,0,331,33;272149,0.8,27,0,321,42;272150,0.8,27,0,321,40;268266,0.6,5,0,334,29;251194,0.5,23,0,334,38;162544,0.5,28,0,334,37|12:252258,30.3,25,0,334,28;158366,9.8,23,0,334,30;240949,6.8,29,0,331,39;268252,5.4,5,0,334,32;268249,3.8,5,0,334,36;272147,3.2,27,0,321,35;272149,1.7,27,0,321,42;159459,1.2,24,0,334,27;272150,1.1,27,0,321,40;251513,0.5,26,0,331,33|13:270175,46,30,0,344,43;273796,9.7,33,0,334;270165,8.7,31,0,334;250225,2.9,52,0,321;270164,2.3,36,0,334;250215,1.5,33,0,334;250214,1.1,33,0,334;265657,0.5,37,0,321;250228,0.5,33,0,334|14:270173,40.3,30,0,344;270165,11.5,31,0,334;273796,4.8,33,0,334;270164,3,36,0,334;250225,2.3,52,0,321;250228,1.8,33,0,334;270166,0.8,36,0,334;274493,0.6,37,0,321;250214,0.6,33,0,334;250215,0.5,33,0,334|15:268253,30,12,0,344,45;251132,20.1,39,0,334,58;251190,16.7,39,0,334,88|16:268209,61.1,49,0,344,60;237850,16.3,83,0,331,63;270930,15.1,36,0,334,109|17:237850,64.1,83,0,331,63;270930,9.4,36,0,334,109;237845,8.4,69,0,331,89",
        gems = {
            { id = 240900, nameCn = "无瑕迅捷紫晶", usagePct = 20.8 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 17.3 },
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 17.1 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 83.7 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 86.7 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 98.8 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 96 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 83.9 },
            },
            [10] = {
                { id = 5444, usagePct = 50 },
                { id = 2603, usagePct = 50 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 95 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 95 },
            },
            [16] = {
                { id = 8689, usagePct = 76.6 },
            },
            [17] = {
                { id = 8689, usagePct = 75.4 },
            },
        },
    },
    ["SHAMAN/RESTORATION/Totemic"] = {
        className = "SHAMAN",
        specName = "RESTORATION",
        heroTalent = "Totemic",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.9, haste = 0.7, mastery = 0.5, versatility = 0.4 },
        targetStatPercents = { crit = 44.9, haste = 27.3, mastery = 11.4, versatility = 16.4 },
        targetStatPercentsMplus = { crit = 41.4, haste = 24.7, mastery = 7.8, versatility = 26.1 },
        targetStatPercentsMplusFarm = { crit = 43, haste = 27.6, mastery = 11.7, versatility = 17.7 },
        _pb = "1:271483,88.6,146,0,334,3;268230,4.2,93,0,334,135;244579,2.4,103,0,331,11|2:268265,78.5,4,0,344,4;273781,9.1,6,0,334,6;251234,3.2,23,0,334,51|3:271481,88.6,107,0,344,251;244580,4.9,81,0,331,139;251131,2.7,39,0,334,165|5:271486,90.6,96,0,344,253;271876,4.2,97,0,344,120;239046,1.8,45,0,321,259|6:268216,58,102,0,334,155;244581,14.8,98,0,331,139;251155,7.5,41,0,334,143|7:271482,74.4,61,0,344,256;244582,17.6,81,0,331,145;159375,2.8,45,0,321,167|8:251125,21.8,125,0,334,260;244577,20.6,81,0,331,139;268258,18,18,0,334,147|9:244584,71.5,98,0,331,149;159380,11.1,99,0,328,151;251200,6.7,41,0,334,47|10:271484,85.9,68,0,334,257;268238,4.3,18,0,334,86;244583,3.7,100,0,331,73|11:273792,22.5,23,0,334,26;240949,11.3,29,0,331,39;251136,7.2,23,0,334,31;272148,4.4,27,0,321,41;158366,2.8,23,0,334,30;159459,2.5,24,0,334,27;268266,2.3,5,0,334,29|12:251148,22.8,23,0,334,34;268252,20,5,0,334,32;240949,10.8,29,0,331,39;251136,7.3,23,0,334,31;159459,3.9,24,0,334,27;272148,3.7,27,0,321,41;158366,2.5,23,0,334,30;268266,1.4,5,0,334,29;252258,0.9,25,0,334,28|13:270162,51.6,36,0,334;248583,3.5,47,0,321;251792,3.2,37,0,321,0,19,3,0,1320,0;250215,2.9,33,0,334;270171,1,104,0,334,158;274493,0.8,37,0,321;270169,0.5,30,0,344,114|14:270164,35.6,36,0,334;270167,9.6,36,0,334,87;248583,3,47,0,321;250215,2.5,33,0,334;270171,2.3,104,0,334,158;274493,2,37,0,321;251792,1.8,37,0,321,0,19,3,0,1320,0;193757,1.6,33,0,334;250248,0.9,33,0,334|15:268248,40.6,18,0,334,170;193763,12.7,39,0,334,47;251132,10.4,39,0,334,58|16:271092,62.5,30,0,344,62;268210,8.9,36,0,334,90;268203,8,70,0,334,90|17:237831,65.9,38,0,331,63;268196,23.5,137,0,334,229;268262,4.1,32,0,334,228",
        gems = {
            { id = 240910, nameCn = "无瑕万能榴石", usagePct = 28.9 },
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 14.2 },
            { id = 240914, nameCn = "无瑕致命青金石", usagePct = 11.7 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 76.7 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 19.1 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 74.5 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 22.1 },
            },
            [5] = {
                { id = 8013, nameCn = "魔导师印记", icon = "ui_profession_enchanting", usagePct = 77.9 },
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 21.7 },
            },
            [7] = {
                { id = 7937, nameCn = "奥纹魔线", item = 240155, icon = "inv_12_tailoring_spellthread_violet_spellthread", usagePct = 85.9 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 76.9 },
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 20.8 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 62.9 },
                { id = 7997, nameCn = "自然之怒", icon = "ui_profession_enchanting", usagePct = 28.9 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 62.9 },
                { id = 7997, nameCn = "自然之怒", icon = "ui_profession_enchanting", usagePct = 28.9 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 83.6 },
            },
        },
    },
    ["WARLOCK/AFFLICTION/Hellcaller"] = {
        className = "WARLOCK",
        specName = "AFFLICTION",
        heroTalent = "Hellcaller",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.6, haste = 0.9, mastery = 0.6, versatility = 0.3 },
        targetStatPercents = { crit = 35.3, haste = 35.3, mastery = 23.7, versatility = 5.7 },
        targetStatPercentsMplus = { crit = 34.2, haste = 43.3, mastery = 16.4, versatility = 6.1 },
        targetStatPercentsMplusFarm = { crit = 35.6, haste = 38.9, mastery = 19.6, versatility = 6 },
        _pb = "1:271546,76.4,148,0,344,261;271874,19.5,116,0,344,177;268242,2.7,102,0,334,178|2:268265,82.3,4,0,344,4;273781,6.2,6,0,334,6;268250,4.5,5,0,334,5|3:271544,87.9,117,0,334,7;239650,3.5,58,0,331,73;239031,2.7,45,0,321,262|5:271549,92.3,80,0,334,263;239655,3.1,118,0,331,11;251139,1.5,119,0,331,182|6:239649,26.5,65,0,331,73;268257,24.9,120,0,334,184;268232,14,20,0,334,183|7:271545,92.7,140,0,334,263;239651,3.5,81,0,331,2;273786,1.3,45,0,321,236|8:268218,19.7,18,0,334,188;251219,18.8,64,0,334,237;159259,13.3,39,0,334,207|9:239648,64.9,123,0,331,46;268228,11.9,3,0,334,191;251127,10.8,41,0,334,190|10:271547,86.8,124,0,344,193;268243,4.8,12,0,344,193;239653,2.5,58,0,331,73|11:273792,30.9,23,0,334,26;252258,7.9,25,0,334,28;158366,7.7,23,0,334,30;251136,7.7,23,0,334,31;240949,6.5,29,0,331,39;159459,3.7,24,0,334,27;268266,3.2,5,0,334,29;251148,2.1,23,0,334,34;268249,2.1,5,0,334,36;272147,1.3,27,0,321,35;272148,0.8,27,0,321,41;272149,0.8,27,0,321,42;171853,0.6,86,0,321,131|12:268252,23,5,0,334,32;251136,11.9,23,0,334,31;240949,7.9,29,0,331,39;252258,7.2,25,0,334,28;158366,5.1,23,0,334,30;268266,3.8,5,0,334,29;251148,3.2,23,0,334,34;159459,3.1,24,0,334,27;272147,2.4,27,0,321,35;268249,2,5,0,334,36;272148,2,27,0,321,41;272150,0.6,27,0,321,40|13:273796,34,33,0,334;270169,11,30,0,344,114;273649,9.6,33,0,334;270167,8.8,36,0,334,87;270168,7.7,30,0,344,44;250215,5.6,33,0,334;250224,2.1,33,0,334;270170,1.8,36,0,334;270161,0.7,82,0,334;274493,0.7,37,0,321|14:270164,43.5,36,0,334;270167,18.8,36,0,334,87;270168,11.5,30,0,344,44;273796,11.4,33,0,334;270169,4.2,30,0,344,114;273649,3.7,33,0,334;250224,3.2,33,0,334;250215,1.1,33,0,334;270170,0.7,36,0,334|15:193763,20.1,39,0,334,47;251132,18.8,39,0,334,58;239656,16.2,38,0,331,46|16:271092,43.8,30,0,344,62;273778,7,128,0,334,203|17:245769,84.3,83,0,331,63;268263,6.6,36,0,334,116;268197,6.1,36,0,334,115",
        gems = {
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 31.4 },
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 21.1 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 16.4 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 69.1 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 16.8 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 66.8 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.5 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 99.3 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 73 },
            },
            [10] = {
                { id = 5932, usagePct = 25 },
                { id = 844, usagePct = 25 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 90.2 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 90.2 },
            },
            [16] = {
                { id = 8689, usagePct = 47.5 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 37.7 },
            },
        },
    },
    ["WARLOCK/DEMONOLOGY/Diabolist"] = {
        className = "WARLOCK",
        specName = "DEMONOLOGY",
        heroTalent = "Diabolist",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.7, haste = 0.9, mastery = 0.7, versatility = 0.4 },
        targetStatPercents = { crit = 39.6, haste = 30.2, mastery = 24.3, versatility = 5.8 },
        targetStatPercentsMplus = { crit = 38.9, haste = 28, mastery = 21.7, versatility = 11.4 },
        targetStatPercentsMplusFarm = { crit = 40.3, haste = 30.1, mastery = 23.1, versatility = 6.4 },
        _pb = "1:271546,77.1,148,0,344,261;271874,19.4,116,0,344,177;268242,2.2,102,0,334,178|2:268265,85,4,0,344,4;273781,4.2,6,0,334,6;251234,2.7,23,0,334,51|3:271544,87.7,117,0,334,7;271434,3.9,8,0,334,239;239650,3.5,58,0,331,73|5:271549,91.6,80,0,334,263;239655,3.2,118,0,331,11;268221,2.8,18,0,334,205|6:239649,31.6,65,0,331,73;268257,22,120,0,334,184;268232,13,20,0,334,183|7:271545,91.7,140,0,334,263;239651,3.9,81,0,331,2;268236,1.4,122,0,334,186|8:268218,32.2,18,0,334,188;159259,14.8,39,0,334,207;271435,12.7,113,0,334,187|9:239648,65.2,123,0,331,46;268228,15.1,3,0,334,191;251127,8.3,41,0,334,190|10:271547,90.1,124,0,344,193;268243,4.3,12,0,344,193;159247,2.1,129,0,334,208|11:268252,23.1,5,0,334,32;273792,20.1,23,0,334,26;158366,12.3,23,0,334,30;240949,7.8,29,0,331,39;268249,3.6,5,0,334,36;252258,2.2,25,0,334,28;268266,2.2,5,0,334,29;251148,1.8,23,0,334,34;272149,1.1,27,0,321,42;272148,1.1,27,0,321,41;272150,1.1,27,0,321,40|12:251136,25,23,0,334,31;158366,11,23,0,334,30;240949,5.5,29,0,331,39;268249,4.3,5,0,334,36;252258,3.2,25,0,334,28;272148,2.7,27,0,321,41;251148,2,23,0,334,34;272149,2,27,0,321,42;268266,1.5,5,0,334,29;272147,1,27,0,321,35;272150,0.8,27,0,321,40;162544,0.6,28,0,334,37;251513,0.6,26,0,331,33|13:273796,56.8,33,0,334;270169,5.2,30,0,344,114;250215,4.2,33,0,334;273649,4.1,33,0,334;250224,1,33,0,334;274493,0.8,37,0,321|14:270164,57.6,36,0,334;270167,13.8,36,0,334,87;250215,2.2,33,0,334;250224,1.8,33,0,334;270168,0.8,30,0,344,44;270169,0.8,30,0,344,114;274493,0.7,37,0,321|15:251132,23.6,39,0,334,58;239656,17.1,38,0,331,46;193763,15.4,39,0,334,47|16:271092,40,30,0,344,62;268203,5.7,70,0,334,90|17:245769,74,83,0,331,63;268263,11.4,36,0,334,116;268197,10.6,36,0,334,115",
        gems = {
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 30.6 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 17.4 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 16 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 83.3 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 81.4 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.5 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 99.8 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 81.9 },
            },
            [10] = {
                { id = 5447, usagePct = 50 },
                { id = 5932, usagePct = 50 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.2 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 97.2 },
            },
            [16] = {
                { id = 8689, usagePct = 72.9 },
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 17.3 },
            },
        },
    },
    ["WARLOCK/DESTRUCTION/Hellcaller"] = {
        className = "WARLOCK",
        specName = "DESTRUCTION",
        heroTalent = "Hellcaller",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { intellect = 1, crit = 0.6, haste = 0.9, mastery = 0.7, versatility = 0.3 },
        targetStatPercents = { crit = 34.3, haste = 29.4, mastery = 31.1, versatility = 5.1 },
        targetStatPercentsMplus = { crit = 35.5, haste = 31.1, mastery = 27.7, versatility = 5.8 },
        targetStatPercentsMplusFarm = { crit = 35.4, haste = 30.6, mastery = 27.9, versatility = 6.1 },
        _pb = "1:271546,71,148,0,344,261;271874,25.1,116,0,344,177;268242,2.5,102,0,334,178|2:268265,85.3,4,0,344,4;273781,4.1,6,0,334,6;251234,3.4,23,0,334,51|3:271544,85.8,117,0,334,7;239650,4.2,58,0,331,73;268241,2.7,18,0,334,180|5:271549,93.1,80,0,334,263;268221,3.2,18,0,334,205;239655,1.7,118,0,331,11|6:239649,32.4,65,0,331,73;268257,27.3,120,0,334,184;251222,9.2,41,0,334,82|7:271545,91.9,140,0,334,263;239651,3.6,81,0,331,2;273786,1.4,45,0,321,236|8:268218,24.9,18,0,334,188;251137,14.4,125,0,334,198;271548,11.7,48,0,344,264|9:239648,66.1,123,0,331,46;268228,12.9,3,0,334,191;251127,11,41,0,334,190|10:271547,87.5,124,0,344,193;268243,4.4,12,0,344,193;239653,2.4,58,0,331,73|11:273792,17.5,23,0,334,26;268252,15.3,5,0,334,32;158366,12.9,23,0,334,30;252258,8.1,25,0,334,28;240949,6.1,29,0,331,39;268249,5.6,5,0,334,36;272149,2.5,27,0,321,42;272150,1.5,27,0,321,40;272147,1.2,27,0,321,35;162544,1,28,0,334,37;159459,1,24,0,334,27;251194,0.8,23,0,334,38;268266,0.5,5,0,334,29|12:251136,24.4,23,0,334,31;158366,10.7,23,0,334,30;252258,8.5,25,0,334,28;268249,6.1,5,0,334,36;240949,4.4,29,0,331,39;272149,2.4,27,0,321,42;272147,1.9,27,0,321,35;272148,1.5,27,0,321,41;251148,1.5,23,0,334,34;162544,1.2,28,0,334,37;272150,1,27,0,321,40;159459,1,24,0,334,27;251194,0.8,23,0,334,38;268266,0.5,5,0,334,29|13:250215,51.4,33,0,334;273796,5.4,33,0,334;270168,4.2,30,0,344,44;250224,1.4,33,0,334;250214,1.2,33,0,334;270169,0.8,30,0,344,114;270170,0.8,36,0,334|14:270164,46.8,36,0,334;270167,17.3,36,0,334,87;270168,3.2,30,0,344,44;250224,2.9,33,0,334;273796,2.5,33,0,334;250214,1.2,33,0,334;270161,1,82,0,334;250259,0.5,78,0,334|15:251132,33.1,39,0,334,58;193763,12.2,39,0,334,47;251190,12,39,0,334,88|16:271092,43.7,30,0,344,62;268203,6.8,70,0,334,90|17:245769,77,83,0,331,63;268197,9,36,0,334,115;268263,6.5,36,0,334,116",
        gems = {
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 24 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 15.8 },
            { id = 240908, nameCn = "无瑕精湛榴石", usagePct = 15.5 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 67 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 17.3 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 69.3 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 98.7 },
            },
            [7] = {
                { id = 7935, nameCn = "阳炎丝绸魔线", item = 240133, icon = "inv_tailoring_spellthread_orange_spellthread", usagePct = 99.1 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 71.2 },
                { id = 8019, nameCn = "远行者的狩猎", icon = "ui_profession_enchanting", usagePct = 16.2 },
            },
            [10] = {
                { id = 5935, usagePct = 40 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 91.8 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 91.8 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 43.3 },
                { id = 8689, usagePct = 40.4 },
            },
        },
    },
    ["WARRIOR/ARMS/Slayer"] = {
        className = "WARRIOR",
        specName = "ARMS",
        heroTalent = "Slayer",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { strength = 1, crit = 0.9, haste = 0.5, mastery = 0.5, versatility = 0.3 },
        targetStatPercents = { crit = 43, haste = 33.8, mastery = 19.4, versatility = 3.7 },
        targetStatPercentsMplus = { crit = 42.7, haste = 30.6, mastery = 20.7, versatility = 6 },
        targetStatPercentsMplusFarm = { crit = 46.4, haste = 31.1, mastery = 19.3, versatility = 3.2 },
        _pb = "1:271456,89.9,149,0,334,91;237832,5.4,2,0,331,2;268229,3.3,3,0,334,3|2:268265,80,4,0,344,4;268250,6.6,5,0,334,5;273781,4.8,6,0,334,6|3:271454,82.9,7,0,334,257;237835,9.1,29,0,331,19;268226,3.7,9,0,334,9|5:271459,87.3,10,0,344,10;268222,5.9,12,0,344,12;237829,4.1,11,0,331,11|6:268259,45.8,13,0,344,13;271445,17.1,14,0,334,15;271453,14.4,60,0,344,265|7:271455,85.3,15,0,344,266;271878,13.1,16,0,344,16;268224,1,17,0,334,17|8:237828,74.9,19,0,331,19;268245,16.5,18,0,334,18;268260,5.2,18,0,334,20|9:237834,81.1,2,0,331,21;268239,6.6,20,0,334,22;251133,4.5,21,0,321,23|10:271457,87.7,109,0,334,208;237836,4.9,19,0,331,19;268220,3.4,18,0,334,25|11:273792,33.2,23,0,334,26;268252,11.3,5,0,334,32;240949,9.5,29,0,331,39;251136,6,23,0,334,31;158366,5.7,23,0,334,30;268249,3.2,5,0,334,36;272147,2.3,27,0,321,35;268266,2,5,0,334,29;251513,1.4,26,0,331,33;272150,1,27,0,321,40;272149,1,27,0,321,42;159459,0.9,24,0,334,27|12:252258,22.7,25,0,334,28;251136,9.2,23,0,334,31;240949,8.2,29,0,331,39;268252,6.9,5,0,334,32;158366,6.3,23,0,334,30;268249,4.2,5,0,334,36;272147,3.8,27,0,321,35;251513,3.3,26,0,331,33;272150,1.5,27,0,321,40;272149,1.1,27,0,321,42;268266,1,5,0,334,29|13:270175,35.6,30,0,344,43;270165,22,31,0,334;270164,1.2,36,0,334;273796,0.9,33,0,334;270163,0.6,32,0,334;274493,0.4,37,0,321|14:270173,52.6,30,0,344;270164,2,36,0,334;273796,0.7,33,0,334;270163,0.6,32,0,334;265657,0,37,0,321,0,25,6,0,0,0|15:268253,30.3,12,0,344,45;193763,20,39,0,334,47;271451,13.3,48,0,344,267|16:268213,85.3,30,0,344,48;268198,5.3,36,0,334,67;237846,4.5,40,0,331,2",
        gems = {
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 22.8 },
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 17.9 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 11 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 69.1 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 21.1 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 76.4 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 99.4 },
            },
            [7] = {
                { id = 8163, nameCn = "血骑士的护甲片", item = 244643, icon = "inv_12_profession_leatherworking_thalassian_amor_kit", usagePct = 68.7 },
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 31.2 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 75.1 },
            },
            [10] = {
                { id = 5447, usagePct = 85.7 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99.1 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 99.1 },
            },
            [16] = {
                { id = 8689, usagePct = 78.2 },
                { id = 7983, nameCn = "狂战士之怒", icon = "ui_profession_enchanting", usagePct = 17.3 },
            },
        },
    },
    ["WARRIOR/FURY/Slayer"] = {
        className = "WARRIOR",
        specName = "FURY",
        heroTalent = "Slayer",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { strength = 1, crit = 0.9, haste = 0.6, mastery = 0.8, versatility = 0.3 },
        targetStatPercents = { crit = 24.1, haste = 35.4, mastery = 35, versatility = 5.6 },
        targetStatPercentsMplus = { crit = 22.2, haste = 35, mastery = 37.1, versatility = 5.7 },
        targetStatPercentsMplusFarm = { crit = 26.4, haste = 32.8, mastery = 36, versatility = 4.8 },
        _pb = "1:271456,91.2,149,0,334,91;268229,3.1,3,0,334,3;251126,2.6,41,0,334,50|2:268265,56.5,4,0,344,4;251142,24,42,0,334,52;251173,5.6,23,0,334,101|3:271454,90.7,7,0,334,257;251138,3.5,39,0,334,53;268226,2.3,9,0,334,9|5:271459,88.9,10,0,344,10;268222,7.4,12,0,344,12;193753,2.6,45,0,321,128|6:268259,44.8,13,0,344,13;159418,16.5,41,0,334,53;271453,14,60,0,344,265|7:271455,86.3,15,0,344,266;271878,10.2,16,0,344,16;268224,2.1,17,0,334,17|8:237828,47.4,19,0,331,19;268260,21.7,18,0,334,20;268245,11.4,18,0,334,18|9:237834,86.4,2,0,331,21;251133,4,21,0,321,23;268239,4,20,0,334,22|10:271457,83.8,109,0,334,208;251214,5.1,150,0,331,268;268220,3.1,18,0,334,25|11:268249,9.8,5,0,334,36;251136,6.1,23,0,334,31;251194,5.1,23,0,334,38;272150,4.6,27,0,321,40;162544,4.5,28,0,334,37;159459,4.3,24,0,334,27;272147,4.1,27,0,321,35;240949,4,29,0,331,39;158366,3.5,23,0,334,30;272149,2.5,27,0,321,42;268266,1.3,5,0,334,29|12:252258,38.2,25,0,334,28;273792,12.7,23,0,334,26;272150,5.8,27,0,321,40;251194,5.6,23,0,334,38;240949,5,29,0,331,39;272147,5,27,0,321,35;251136,4.6,23,0,334,31;158366,4.3,23,0,334,30;272149,2.6,27,0,321,42;159459,2,24,0,334,27;251513,1.7,26,0,331,33;251148,0.7,23,0,334,34;162544,0.7,28,0,334,37|13:270175,34.4,30,0,344,43;270164,3,36,0,334;273796,1.7,33,0,334;270163,1.5,32,0,334;250259,1,78,0,334;270168,1,30,0,344,44;250228,0.5,33,0,334|14:270173,50.1,30,0,344;270165,16.7,31,0,334;270164,2.5,36,0,334;250228,1.7,33,0,334;270163,1.3,32,0,334;273796,1,33,0,334;250259,0.7,78,0,334|15:268253,44.5,12,0,344,45;251190,18.2,39,0,334,88;271451,10.7,48,0,344,267|16:268213,79.7,30,0,344,48;237846,10.1,40,0,331,2;268214,5.6,36,0,334,49|17:237846,46.4,40,0,331,2;268214,20.8,36,0,334,49;268198,9.4,36,0,334,67",
        gems = {
            { id = 240900, nameCn = "无瑕迅捷紫晶", usagePct = 26.2 },
            { id = 240892, nameCn = "无瑕精湛榄石", usagePct = 18.4 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 16.7 },
        },
        enchants = {
            [1] = {
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 55.5 },
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 35.2 },
            },
            [3] = {
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 68.9 },
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 20.3 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 95.7 },
            },
            [7] = {
                { id = 8163, nameCn = "血骑士的护甲片", item = 244643, icon = "inv_12_profession_leatherworking_thalassian_amor_kit", usagePct = 62.8 },
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 37.2 },
            },
            [8] = {
                { id = 7963, nameCn = "山猫之敏", icon = "ui_profession_enchanting", usagePct = 68.7 },
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 19.2 },
            },
            [10] = {
                { id = 4732, usagePct = 50 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 87.4 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 87.4 },
            },
            [16] = {
                { id = 8689, usagePct = 57.9 },
                { id = 7983, nameCn = "狂战士之怒", icon = "ui_profession_enchanting", usagePct = 28.2 },
            },
            [17] = {
                { id = 8689, usagePct = 51.5 },
                { id = 7983, nameCn = "狂战士之怒", icon = "ui_profession_enchanting", usagePct = 23.2 },
            },
        },
    },
    ["WARRIOR/PROTECTION/Mountain Thane"] = {
        className = "WARRIOR",
        specName = "PROTECTION",
        heroTalent = "Mountain Thane",
        graduationItemLevel = 334,
        zoneName = "烈毒之渊 S2",
        statTolerancePct = 2.0,
        statWeights = { strength = 1, crit = 0.9, haste = 0.7, mastery = 0.6, versatility = 0.4 },
        targetStatPercents = { crit = 32.1, haste = 38.2, mastery = 17.9, versatility = 11.7 },
        targetStatPercentsMplus = { crit = 26.9, haste = 41.5, mastery = 16.8, versatility = 14.8 },
        targetStatPercentsMplusFarm = { crit = 34.8, haste = 41.4, mastery = 15.6, versatility = 8.2 },
        _pb = "1:271456,91.5,149,0,334,91;268229,3.6,3,0,334,3;239050,2.5,84,0,321,269|2:268265,51.8,4,0,344,4;268250,13.9,5,0,334,5;273781,13.7,6,0,334,6|3:271454,87.2,7,0,334,257;251138,2.8,39,0,334,53;271444,2.7,8,0,334,8|5:271459,88.2,10,0,344,10;268222,6,12,0,344,12;251193,2.7,45,0,321,270|6:268259,35.1,13,0,344,13;268244,15.6,3,0,334,14;271453,14.8,60,0,344,265|7:271455,82,15,0,344,266;271878,13.1,16,0,344,16;268224,2.7,17,0,334,17|8:237828,49.1,19,0,331,19;268245,21.1,18,0,334,18;268260,6.3,18,0,334,20|9:237834,77.6,2,0,331,21;268239,6.1,20,0,334,22;251133,5.5,21,0,321,23|10:271457,85,109,0,334,208;251214,6.1,150,0,331,268;237836,2.4,19,0,331,19|11:273792,26.9,23,0,334,26;251148,7.4,23,0,334,34;159459,7.1,24,0,334,27;251136,7.1,23,0,334,31;268252,6.6,5,0,334,32;240949,6.3,29,0,331,39;268266,5,5,0,334,29;158366,3.8,23,0,334,30;251513,2.5,26,0,331,33;272147,2,27,0,321,35;251194,1.7,23,0,334,38;272148,1.6,27,0,321,41;272150,1.4,27,0,321,40;162544,1.1,28,0,334,37;268249,1.1,5,0,334,36;272149,0.5,27,0,321,42|12:252258,16.1,25,0,334,28;159459,14.8,24,0,334,27;158366,7.1,23,0,334,30;240949,6.5,29,0,331,39;268266,5.8,5,0,334,29;251136,4.9,23,0,334,31;268252,4.6,5,0,334,32;251148,3.9,23,0,334,34;272150,3.6,27,0,321,40;162544,2.8,28,0,334,37;251194,2.2,23,0,334,38;272149,1.3,27,0,321,42;268249,1.3,5,0,334,36;272147,1.1,27,0,321,35|13:270175,31.5,30,0,344,43;270165,9,31,0,334;250245,8.3,35,0,334;270163,5.5,32,0,334;270164,2.7,36,0,334;273796,2.5,33,0,334;250228,1.3,33,0,334;270168,1.3,30,0,344,44;270160,1.1,31,0,334;270174,0.8,77,0,334,108;274493,0.8,37,0,321|14:270173,37.2,30,0,344;250245,11.5,35,0,334;270165,10.6,31,0,334;270163,5.2,32,0,334;250228,2.2,33,0,334;273796,1.9,33,0,334;270174,1.3,77,0,334,108;270164,1.3,36,0,334;270160,0.9,31,0,334;270168,0.8,30,0,344,44|15:268253,29.6,12,0,344,45;193763,13.2,39,0,334,47;271451,10.9,48,0,344,267|16:268209,53.9,49,0,344,60;268202,19.2,50,0,344,62;237839,12.9,51,0,331,63|17:268196,43.8,137,0,334,229;237831,33.4,38,0,331,63;268262,9.1,32,0,334,228",
        gems = {
            { id = 240890, nameCn = "无瑕致命榄石", usagePct = 30.5 },
            { id = 240983, nameCn = "费解之永歌钻石", usagePct = 19.8 },
            { id = 240906, nameCn = "无瑕迅捷榴石", usagePct = 13.8 },
        },
        enchants = {
            [1] = {
                { id = 7961, nameCn = "强化吸血妖术", icon = "ui_profession_enchanting", usagePct = 66 },
                { id = 8017, nameCn = "强化闪避符文", icon = "ui_profession_enchanting", usagePct = 15.5 },
            },
            [3] = {
                { id = 8031, nameCn = "银月城治愈", icon = "ui_profession_enchanting", usagePct = 62.8 },
                { id = 8001, nameCn = "阿梅达希尔之赐", icon = "ui_profession_enchanting", usagePct = 17.6 },
            },
            [5] = {
                { id = 7987, nameCn = "世界之魂印记", icon = "ui_profession_enchanting", usagePct = 91 },
            },
            [7] = {
                { id = 8159, nameCn = "森林猎手的护甲片", item = 244641, icon = "inv_12_profession_leatherworking_amani_armor_kit", usagePct = 57.8 },
                { id = 8163, nameCn = "血骑士的护甲片", item = 244643, icon = "inv_12_profession_leatherworking_thalassian_amor_kit", usagePct = 41.6 },
            },
            [8] = {
                { id = 7993, nameCn = "莎拉达希尔之根", icon = "ui_profession_enchanting", usagePct = 62.2 },
                { id = 8019, nameCn = "远行者的狩猎", icon = "ui_profession_enchanting", usagePct = 19.6 },
            },
            [10] = {
                { id = 4732, usagePct = 14.3 },
            },
            [11] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 55 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 35.2 },
            },
            [12] = {
                { id = 7967, nameCn = "鹰眼神视", icon = "ui_profession_enchanting", usagePct = 55 },
                { id = 8025, nameCn = "银月城之捷", icon = "ui_profession_enchanting", usagePct = 35.2 },
            },
            [16] = {
                { id = 8039, nameCn = "朗多雷之锐", icon = "ui_profession_enchanting", usagePct = 39 },
                { id = 7983, nameCn = "狂战士之怒", icon = "ui_profession_enchanting", usagePct = 34.3 },
            },
        },
    },
}

BisData.classArmor = {
    MAGE = "CLOTH",
    PRIEST = "CLOTH",
    WARLOCK = "CLOTH",
    DEMONHUNTER = "LEATHER",
    DRUID = "LEATHER",
    MONK = "LEATHER",
    ROGUE = "LEATHER",
    EVOKER = "MAIL",
    HUNTER = "MAIL",
    SHAMAN = "MAIL",
    DEATHKNIGHT = "PLATE",
    PALADIN = "PLATE",
    WARRIOR = "PLATE",
}

BisData.specIds = {
    ["DEATHKNIGHT/BLOOD"] = 250,
    ["DEATHKNIGHT/FROST"] = 251,
    ["DEATHKNIGHT/UNHOLY"] = 252,
    ["DEMONHUNTER/DEVAURER"] = 1480,
    ["DEMONHUNTER/HAVOC"] = 577,
    ["DEMONHUNTER/VENGEANCE"] = 581,
    ["DRUID/BALANCE"] = 102,
    ["DRUID/FERAL"] = 103,
    ["DRUID/GUARDIAN"] = 104,
    ["DRUID/RESTORATION"] = 105,
    ["EVOKER/AUGMENTATION"] = 1473,
    ["EVOKER/DEVASTATION"] = 1467,
    ["EVOKER/PRESERVATION"] = 1468,
    ["HUNTER/BEASTMASTERY"] = 253,
    ["HUNTER/MARKSMANSHIP"] = 254,
    ["HUNTER/SURVIVAL"] = 255,
    ["MAGE/ARCANE"] = 62,
    ["MAGE/FIRE"] = 63,
    ["MAGE/FROST"] = 64,
    ["MONK/BREWMASTER"] = 268,
    ["MONK/MISTWEAVER"] = 270,
    ["MONK/WINDWALKER"] = 269,
    ["PALADIN/HOLY"] = 65,
    ["PALADIN/PROTECTION"] = 66,
    ["PALADIN/RETRIBUTION"] = 70,
    ["PRIEST/DISCIPLINE"] = 256,
    ["PRIEST/HOLY"] = 257,
    ["PRIEST/SHADOW"] = 258,
    ["ROGUE/ASSASSINATION"] = 259,
    ["ROGUE/OUTLAW"] = 260,
    ["ROGUE/SUBTLETY"] = 261,
    ["SHAMAN/ELEMENTAL"] = 262,
    ["SHAMAN/ENHANCEMENT"] = 263,
    ["SHAMAN/RESTORATION"] = 264,
    ["WARLOCK/AFFLICTION"] = 265,
    ["WARLOCK/DEMONOLOGY"] = 266,
    ["WARLOCK/DESTRUCTION"] = 267,
    ["WARRIOR/ARMS"] = 71,
    ["WARRIOR/FURY"] = 72,
    ["WARRIOR/PROTECTION"] = 73,
}
BisData.specRawToCN = {
    ["AFFLICTION"] = "痛苦",
    ["ARCANE"] = "奥术",
    ["ARMS"] = "武器",
    ["ASSASSINATION"] = "刺杀",
    ["AUGMENTATION"] = "增辉",
    ["BALANCE"] = "平衡",
    ["BEASTMASTERY"] = "兽王",
    ["BLOOD"] = "鲜血",
    ["BREWMASTER"] = "酒仙",
    ["DEMONOLOGY"] = "恶魔",
    ["DESTRUCTION"] = "毁灭",
    ["DEVASTATION"] = "湮灭",
    ["DEVAURER"] = "噬灭",
    ["DISCIPLINE"] = "戒律",
    ["ELEMENTAL"] = "元素",
    ["ENHANCEMENT"] = "增强",
    ["FERAL"] = "野性",
    ["FIRE"] = "火焰",
    ["FROST"] = "冰法",
    ["FURY"] = "狂怒",
    ["GUARDIAN"] = "守护",
    ["HAVOC"] = "浩劫",
    ["HOLY"] = "神圣",
    ["MARKSMANSHIP"] = "射击",
    ["MISTWEAVER"] = "织雾",
    ["OUTLAW"] = "狂徒",
    ["PRESERVATION"] = "恩护",
    ["PROTECTION"] = "防护",
    ["RESTORATION"] = "恢复",
    ["RETRIBUTION"] = "惩戒",
    ["SHADOW"] = "暗影",
    ["SUBTLETY"] = "敏锐",
    ["SURVIVAL"] = "生存",
    ["UNHOLY"] = "邪恶",
    ["VENGEANCE"] = "复仇",
    ["WINDWALKER"] = "踏风",
}
BisData.weaponConfig = {
    ["DEATHKNIGHT/BLOOD"] = { raid={ ["2h"]=100.0 }, mplusHigh={ ["2h"]=100.0 }, mplusFarm={ ["2h"]=100.0 } },
    ["DEATHKNIGHT/FROST"] = { raid={ ["2h"]=83.8, ["dualWield"]=16.2 }, mplusHigh={ ["dualWield"]=58.5, ["2h"]=41.5 }, mplusFarm={ ["2h"]=68.4, ["dualWield"]=31.6 } },
    ["DEATHKNIGHT/UNHOLY"] = { raid={ ["2h"]=100.0 }, mplusHigh={ ["2h"]=100.0 }, mplusFarm={ ["2h"]=100.0 } },
    ["DEMONHUNTER/DEVAURER"] = { raid={ ["dualWield"]=100.0 }, mplusHigh={ ["dualWield"]=100.0 }, mplusFarm={ ["dualWield"]=100.0 } },
    ["DEMONHUNTER/HAVOC"] = { raid={ ["dualWield"]=100.0 }, mplusHigh={ ["dualWield"]=100.0 }, mplusFarm={ ["dualWield"]=100.0 } },
    ["DEMONHUNTER/VENGEANCE"] = { raid={ ["dualWield"]=100.0 }, mplusHigh={ ["dualWield"]=100.0 }, mplusFarm={ ["dualWield"]=100.0 } },
    ["DRUID/BALANCE"] = { raid={ ["2h"]=82.4, ["1hOff"]=17.6 }, mplusHigh={ ["2h"]=70.2, ["1hOff"]=29.8 }, mplusFarm={ ["2h"]=82.5, ["1hOff"]=17.5 } },
    ["DRUID/FERAL"] = { raid={ ["2h"]=100.0 }, mplusHigh={ ["2h"]=100.0 }, mplusFarm={ ["2h"]=100.0 } },
    ["DRUID/GUARDIAN"] = { raid={ ["2h"]=100.0 }, mplusHigh={ ["2h"]=100.0 }, mplusFarm={ ["2h"]=100.0 } },
    ["DRUID/RESTORATION"] = { raid={ ["2h"]=96.8, ["1hOff"]=3.2 }, mplusHigh={ ["2h"]=93.2, ["1hOff"]=6.8 }, mplusFarm={ ["2h"]=96.3, ["1hOff"]=3.7 } },
    ["EVOKER/AUGMENTATION"] = { raid={ ["1hOff"]=63.8, ["2h"]=36.2 }, mplusHigh={ ["1hOff"]=85.7, ["2h"]=14.3 }, mplusFarm={ ["1hOff"]=51.5, ["2h"]=48.5 } },
    ["EVOKER/DEVASTATION"] = { raid={ ["2h"]=56.0, ["1hOff"]=44.0 }, mplusHigh={ ["1hOff"]=55.1, ["2h"]=44.9 }, mplusFarm={ ["1hOff"]=50.0, ["2h"]=50.0 } },
    ["EVOKER/PRESERVATION"] = { raid={ ["2h"]=80.9, ["1hOff"]=19.1 }, mplusHigh={ ["2h"]=64.5, ["1hOff"]=35.5 }, mplusFarm={ ["2h"]=80.6, ["1hOff"]=19.4 } },
    ["HUNTER/BEASTMASTERY"] = { raid={ ["ranged"]=100.0 }, mplusHigh={ ["ranged"]=100.0 }, mplusFarm={ ["ranged"]=100.0 } },
    ["HUNTER/MARKSMANSHIP"] = { raid={ ["ranged"]=100.0 }, mplusHigh={ ["ranged"]=100.0 }, mplusFarm={ ["ranged"]=100.0 } },
    ["HUNTER/SURVIVAL"] = { raid={ ["dualWield"]=100.0 }, mplusHigh={ ["dualWield"]=100.0 }, mplusFarm={ ["dualWield"]=100.0 } },
    ["MAGE/ARCANE"] = { raid={ ["2h"]=83.7, ["1hOff"]=15.0, ["ranged"]=1.4 }, mplusHigh={ ["2h"]=87.3, ["1hOff"]=12.7 }, mplusFarm={ ["2h"]=85.5, ["1hOff"]=13.7, ["ranged"]=0.9 } },
    ["MAGE/FIRE"] = { raid={ ["2h"]=91.8, ["1hOff"]=8.2 }, mplusHigh={ ["2h"]=91.2, ["1hOff"]=8.8 }, mplusFarm={ ["2h"]=89.4, ["1hOff"]=10.6 } },
    ["MAGE/FROST"] = { raid={ ["2h"]=85.4, ["1hOff"]=14.6 }, mplusHigh={ ["2h"]=78.0, ["1hOff"]=22.0 }, mplusFarm={ ["2h"]=83.9, ["1hOff"]=16.1 } },
    ["MONK/BREWMASTER"] = { raid={ ["2h"]=100.0 }, mplusHigh={ ["2h"]=100.0 }, mplusFarm={ ["2h"]=100.0 } },
    ["MONK/MISTWEAVER"] = { raid={ ["2h"]=57.5, ["1hOff"]=42.5 }, mplusHigh={ ["1hOff"]=74.5, ["2h"]=25.5 }, mplusFarm={ ["2h"]=73.7, ["1hOff"]=26.3 } },
    ["MONK/WINDWALKER"] = { raid={ ["2h"]=98.7, ["dualWield"]=1.3 }, mplusHigh={ ["2h"]=100.0 }, mplusFarm={ ["2h"]=100.0 } },
    ["PALADIN/HOLY"] = { raid={ ["1hShield"]=97.0, ["2h"]=1.8, ["1hOff"]=1.2 }, mplusHigh={ ["1hShield"]=100.0 }, mplusFarm={ ["1hShield"]=99.3, ["2h"]=0.7 } },
    ["PALADIN/PROTECTION"] = { raid={ ["1hShield"]=100.0 }, mplusHigh={ ["1hShield"]=100.0 }, mplusFarm={ ["1hShield"]=100.0 } },
    ["PALADIN/RETRIBUTION"] = { raid={ ["2h"]=100.0 }, mplusHigh={ ["2h"]=100.0 }, mplusFarm={ ["2h"]=100.0 } },
    ["PRIEST/DISCIPLINE"] = { raid={ ["2h"]=81.8, ["1hOff"]=17.7, ["ranged"]=0.5 }, mplusHigh={ ["2h"]=74.0, ["1hOff"]=24.0, ["ranged"]=2.0 }, mplusFarm={ ["2h"]=79.1, ["1hOff"]=18.0, ["ranged"]=2.9 } },
    ["PRIEST/HOLY"] = { raid={ ["2h"]=65.9, ["1hOff"]=30.0, ["ranged"]=4.1 }, mplusHigh={ ["2h"]=65.2, ["1hOff"]=26.1, ["ranged"]=8.7 }, mplusFarm={ ["2h"]=81.0, ["1hOff"]=18.2, ["ranged"]=0.7 } },
    ["PRIEST/SHADOW"] = { raid={ ["2h"]=91.6, ["1hOff"]=7.9, ["ranged"]=0.6 }, mplusHigh={ ["2h"]=86.4, ["1hOff"]=11.4, ["ranged"]=2.3 }, mplusFarm={ ["2h"]=91.5, ["1hOff"]=8.5 } },
    ["ROGUE/ASSASSINATION"] = { raid={ ["dualWield"]=100.0 }, mplusHigh={ ["dualWield"]=100.0 }, mplusFarm={ ["dualWield"]=100.0 } },
    ["ROGUE/OUTLAW"] = { raid={ ["dualWield"]=100.0 }, mplusHigh={ ["dualWield"]=100.0 }, mplusFarm={ ["dualWield"]=100.0 } },
    ["ROGUE/SUBTLETY"] = { raid={ ["dualWield"]=100.0 }, mplusHigh={ ["dualWield"]=100.0 }, mplusFarm={ ["dualWield"]=100.0 } },
    ["SHAMAN/ELEMENTAL"] = { raid={ ["2h"]=66.9, ["1hShield"]=29.4, ["1hOff"]=3.7 }, mplusHigh={ ["1hShield"]=71.4, ["2h"]=28.6 }, mplusFarm={ ["2h"]=55.3, ["1hShield"]=41.5, ["1hOff"]=3.3 } },
    ["SHAMAN/ENHANCEMENT"] = { raid={ ["dualWield"]=100.0 }, mplusHigh={ ["dualWield"]=100.0 }, mplusFarm={ ["dualWield"]=100.0 } },
    ["SHAMAN/RESTORATION"] = { raid={ ["1hShield"]=76.8, ["2h"]=22.7, ["1hOff"]=0.5 }, mplusHigh={ ["1hShield"]=100.0 }, mplusFarm={ ["1hShield"]=76.1, ["2h"]=23.2, ["1hOff"]=0.7 } },
    ["WARLOCK/AFFLICTION"] = { raid={ ["2h"]=70.4, ["1hOff"]=27.5, ["ranged"]=2.1 }, mplusHigh={ ["2h"]=72.5, ["1hOff"]=26.1, ["ranged"]=1.4 }, mplusFarm={ ["2h"]=72.8, ["1hOff"]=26.5, ["ranged"]=0.7 } },
    ["WARLOCK/DEMONOLOGY"] = { raid={ ["2h"]=75.5, ["1hOff"]=24.0, ["ranged"]=0.5 }, mplusHigh={ ["2h"]=66.1, ["1hOff"]=32.2, ["ranged"]=1.7 }, mplusFarm={ ["2h"]=83.7, ["1hOff"]=15.5, ["ranged"]=0.8 } },
    ["WARLOCK/DESTRUCTION"] = { raid={ ["2h"]=76.6, ["1hOff"]=22.8, ["ranged"]=0.7 }, mplusHigh={ ["2h"]=70.6, ["1hOff"]=26.5, ["ranged"]=2.9 }, mplusFarm={ ["2h"]=83.9, ["1hOff"]=16.1 } },
    ["WARRIOR/ARMS"] = { raid={ ["2h"]=100.0 }, mplusHigh={ ["2h"]=100.0 }, mplusFarm={ ["2h"]=100.0 } },
    ["WARRIOR/FURY"] = { raid={ ["titansGrip"]=92.6, ["2h"]=7.4 }, mplusHigh={ ["titansGrip"]=77.0, ["2h"]=23.0 }, mplusFarm={ ["titansGrip"]=100.0 } },
    ["WARRIOR/PROTECTION"] = { raid={ ["1hShield"]=100.0 }, mplusHigh={ ["1hShield"]=100.0 }, mplusFarm={ ["1hShield"]=99.1, ["2h"]=0.9 } },
}

BisData.tierFiller = {
    MAIL = {
        [1] = {
            {
                nameCn = "盘魂者内克扎莉",
                type = "raid",
                encounterId = 2888,
                instanceId = 1320,
                itemId = 268230,
                bonusIDs = {
                    41,
                    13696,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 239035,
                bonusIDs = {
                    13440,
                    40,
                    13696,
                    13662,
                    12699,
                    13695,
                    12854,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
            {
                nameCn = "红玉新生法池",
                type = "mplus",
                itemId = 193765,
                bonusIDs = {
                    13440,
                    6652,
                    13696,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "versatility",
                },
            },
            {
                nameCn = "纳洛拉克的洞穴",
                type = "mplus",
                itemId = 251158,
                bonusIDs = {
                    13440,
                    43,
                    13696,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "versatility",
                    "haste",
                },
            },
            {
                nameCn = "虚空之痕竞技场",
                type = "mplus",
                itemId = 251220,
                bonusIDs = {
                    13440,
                    6652,
                    13696,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "mastery",
                },
            },
        },
        [5] = {
            {
                nameCn = "乌拉特克",
                type = "raid",
                encounterId = 2895,
                instanceId = 1320,
                itemId = 271876,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    13848,
                    13846,
                },
                stats = {
                    "mastery",
                },
            },
            {
                nameCn = "双子毒牙",
                type = "raid",
                encounterId = 2887,
                instanceId = 1320,
                itemId = 268223,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 239034,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "versatility",
                    "mastery",
                },
            },
            {
                nameCn = "毒牙祭坛",
                type = "mplus",
                itemId = 273789,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "虚空之痕竞技场",
                type = "mplus",
                itemId = 251233,
                bonusIDs = {
                    13440,
                    41,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 239046,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "versatility",
                },
            },
        },
        [3] = {
            {
                nameCn = "盘卷祭坛",
                type = "raid",
                encounterId = 2883,
                instanceId = 1320,
                itemId = 268231,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    13848,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
            {
                nameCn = "夺目谷",
                type = "mplus",
                itemId = 251184,
                bonusIDs = {
                    6652,
                    13662,
                    12854,
                },
                stats = {
                    "haste",
                    "versatility",
                },
            },
            {
                nameCn = "密谋小径",
                type = "mplus",
                itemId = 251131,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "versatility",
                    "crit",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 239049,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
        },
        [7] = {
            {
                nameCn = "盘卷祭坛",
                type = "raid",
                encounterId = 2883,
                instanceId = 1320,
                itemId = 268237,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    13848,
                },
                stats = {
                    "haste",
                    "mastery",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 159375,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
            {
                nameCn = "密谋小径",
                type = "mplus",
                itemId = 251141,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "versatility",
                },
            },
            {
                nameCn = "红玉新生法池",
                type = "mplus",
                itemId = 193759,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12846,
                },
                stats = {
                    "versatility",
                    "haste",
                },
            },
        },
        [10] = {
            {
                nameCn = "尼姆瑞莎·唤波者",
                type = "raid",
                encounterId = 2849,
                instanceId = 1317,
                itemId = 268238,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
            {
                nameCn = "夺目谷",
                type = "mplus",
                itemId = 251165,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "versatility",
                },
            },
            {
                nameCn = "红玉新生法池",
                type = "mplus",
                itemId = 193752,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
            {
                nameCn = "纳洛拉克的洞穴",
                type = "mplus",
                itemId = 251152,
                bonusIDs = {
                    13440,
                    40,
                    13662,
                    12699,
                    12851,
                },
                stats = {
                    "haste",
                    "versatility",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 160213,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "haste",
                },
            },
        },
    },
    CLOTH = {
        [7] = {
            {
                nameCn = "盘魂者内克扎莉",
                type = "raid",
                encounterId = 2888,
                instanceId = 1320,
                itemId = 268236,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "mastery",
                    "versatility",
                },
            },
            {
                nameCn = "毒牙祭坛",
                type = "mplus",
                itemId = 273786,
                bonusIDs = {
                    13440,
                    41,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
            {
                nameCn = "红玉新生法池",
                type = "mplus",
                itemId = 193750,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
            {
                nameCn = "纳洛拉克的洞穴",
                type = "mplus",
                itemId = 251160,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 159234,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
        },
        [1] = {
            {
                nameCn = "乌拉特克",
                type = "raid",
                encounterId = 2895,
                instanceId = 1320,
                itemId = 271874,
                bonusIDs = {
                    6652,
                    13696,
                    13662,
                    13335,
                    13848,
                    13846,
                },
                stats = {
                    "mastery",
                },
            },
            {
                nameCn = "迷失的探险者",
                type = "raid",
                encounterId = 2894,
                instanceId = 1320,
                itemId = 268242,
                bonusIDs = {
                    6652,
                    13696,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "夺目谷",
                type = "mplus",
                itemId = 251199,
                bonusIDs = {
                    13440,
                    6652,
                    13696,
                    13662,
                    12699,
                    13695,
                    12854,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
            {
                nameCn = "虚空之痕竞技场",
                type = "mplus",
                itemId = 251232,
                bonusIDs = {
                    13440,
                    6652,
                    13696,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "mastery",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 239047,
                bonusIDs = {
                    13440,
                    6652,
                    13696,
                    13662,
                    12699,
                    12846,
                },
                stats = {
                    "versatility",
                    "crit",
                },
            },
        },
        [3] = {
            {
                nameCn = "双子毒牙",
                type = "raid",
                encounterId = 2887,
                instanceId = 1320,
                itemId = 268241,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "haste",
                    "versatility",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 239031,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
            {
                nameCn = "虚空之痕竞技场",
                type = "mplus",
                itemId = 251227,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "versatility",
                    "mastery",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 239045,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "haste",
                },
            },
        },
        [10] = {
            {
                nameCn = "盘卷祭坛",
                type = "raid",
                encounterId = 2883,
                instanceId = 1320,
                itemId = 268243,
                bonusIDs = {
                    40,
                    13662,
                    13335,
                    13848,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 159247,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
            {
                nameCn = "密谋小径",
                type = "mplus",
                itemId = 251129,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "versatility",
                },
            },
            {
                nameCn = "毒牙祭坛",
                type = "mplus",
                itemId = 273773,
                bonusIDs = {
                    13440,
                    41,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
        },
        [5] = {
            {
                nameCn = "尼姆瑞莎·唤波者",
                type = "raid",
                encounterId = 2849,
                instanceId = 1317,
                itemId = 268221,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 239032,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
            {
                nameCn = "密谋小径",
                type = "mplus",
                itemId = 251139,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "毒牙祭坛",
                type = "mplus",
                itemId = 273785,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "mastery",
                },
            },
            {
                nameCn = "纳洛拉克的洞穴",
                type = "mplus",
                itemId = 251147,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "versatility",
                },
            },
        },
    },
    LEATHER = {
        [5] = {
            {
                nameCn = "盘魂者内克扎莉",
                type = "raid",
                encounterId = 2888,
                instanceId = 1320,
                itemId = 268235,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "haste",
                    "mastery",
                },
            },
            {
                nameCn = "红玉新生法池",
                type = "mplus",
                itemId = 193764,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "versatility",
                },
            },
            {
                nameCn = "纳洛拉克的洞穴",
                type = "mplus",
                itemId = 251159,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "haste",
                },
            },
            {
                nameCn = "虚空之痕竞技场",
                type = "mplus",
                itemId = 251226,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "versatility",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 239048,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
        },
        [1] = {
            {
                nameCn = "乌拉特克",
                type = "raid",
                encounterId = 2895,
                instanceId = 1320,
                itemId = 271875,
                bonusIDs = {
                    6652,
                    13696,
                    13662,
                    13335,
                    13848,
                    13847,
                },
                stats = {
                    "haste",
                },
            },
            {
                nameCn = "陵寝哨兵",
                type = "raid",
                encounterId = 2874,
                instanceId = 1320,
                itemId = 268219,
                bonusIDs = {
                    6652,
                    13696,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "mastery",
                    "versatility",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 239033,
                bonusIDs = {
                    13440,
                    6652,
                    13696,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
            {
                nameCn = "密谋小径",
                type = "mplus",
                itemId = 251140,
                bonusIDs = {
                    13440,
                    40,
                    13696,
                    13662,
                    12699,
                    13695,
                    12854,
                },
                stats = {
                    "haste",
                    "mastery",
                },
            },
            {
                nameCn = "毒牙祭坛",
                type = "mplus",
                itemId = 273791,
                bonusIDs = {
                    13440,
                    41,
                    13695,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "红玉新生法池",
                type = "mplus",
                itemId = 193751,
                bonusIDs = {
                    13440,
                    6652,
                    13695,
                    13662,
                    12699,
                    12846,
                },
                stats = {
                    "versatility",
                    "crit",
                },
            },
        },
        [3] = {
            {
                nameCn = "万毒邪祟者瓦什尼克",
                type = "raid",
                encounterId = 2882,
                instanceId = 1320,
                itemId = 268246,
                bonusIDs = {
                    40,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
            {
                nameCn = "毒牙祭坛",
                type = "mplus",
                itemId = 273774,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "versatility",
                },
            },
            {
                nameCn = "纳洛拉克的洞穴",
                type = "mplus",
                itemId = 251146,
                bonusIDs = {
                    13440,
                    40,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "versatility",
                    "crit",
                },
            },
            {
                nameCn = "虚空之痕竞技场",
                type = "mplus",
                itemId = 251223,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
        },
        [10] = {
            {
                nameCn = "斯索拉克",
                type = "raid",
                encounterId = 2871,
                instanceId = 1320,
                itemId = 268234,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 159337,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "versatility",
                },
            },
            {
                nameCn = "密谋小径",
                type = "mplus",
                itemId = 251124,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
            {
                nameCn = "红玉新生法池",
                type = "mplus",
                itemId = 193758,
                bonusIDs = {
                    13440,
                    40,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "versatility",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 159312,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
        },
        [7] = {
            {
                nameCn = "盘卷祭坛",
                type = "raid",
                encounterId = 2883,
                instanceId = 1320,
                itemId = 268225,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    13848,
                },
                stats = {
                    "mastery",
                    "haste",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 159329,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "versatility",
                },
            },
            {
                nameCn = "夺目谷",
                type = "mplus",
                itemId = 251198,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12846,
                },
                stats = {
                    "versatility",
                    "mastery",
                },
            },
            {
                nameCn = "密谋小径",
                type = "mplus",
                itemId = 251130,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 159313,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "versatility",
                    "haste",
                },
            },
        },
    },
    PLATE = {
        [1] = {
            {
                nameCn = "盘魂者内克扎莉",
                type = "raid",
                encounterId = 2888,
                instanceId = 1320,
                itemId = 268229,
                bonusIDs = {
                    40,
                    13696,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "密谋小径",
                type = "mplus",
                itemId = 251126,
                bonusIDs = {
                    13440,
                    6652,
                    13696,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
            {
                nameCn = "虚空之痕竞技场",
                type = "mplus",
                itemId = 251229,
                bonusIDs = {
                    13440,
                    6652,
                    13696,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 239050,
                bonusIDs = {
                    13440,
                    6652,
                    13696,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "versatility",
                    "haste",
                },
            },
        },
        [7] = {
            {
                nameCn = "乌拉特克",
                type = "raid",
                encounterId = 2895,
                instanceId = 1320,
                itemId = 271878,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    13848,
                    13708,
                },
                stats = {
                    "crit",
                },
            },
            {
                nameCn = "陵寝哨兵",
                type = "raid",
                encounterId = 2874,
                instanceId = 1320,
                itemId = 268224,
                bonusIDs = {
                    40,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "haste",
                    "mastery",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 159435,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "versatility",
                    "crit",
                },
            },
            {
                nameCn = "夺目谷",
                type = "mplus",
                itemId = 251182,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "versatility",
                },
            },
            {
                nameCn = "毒牙祭坛",
                type = "mplus",
                itemId = 273776,
                bonusIDs = {
                    13440,
                    40,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
        },
        [10] = {
            {
                nameCn = "双子毒牙",
                type = "raid",
                encounterId = 2887,
                instanceId = 1320,
                itemId = 268220,
                bonusIDs = {
                    6652,
                    13662,
                    13334,
                    12854,
                    13696,
                },
                stats = {
                    "crit",
                    "haste",
                },
            },
            {
                nameCn = "夺目谷",
                type = "mplus",
                itemId = 251197,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12846,
                },
                stats = {
                    "mastery",
                    "versatility",
                },
            },
            {
                nameCn = "纳洛拉克的洞穴",
                type = "mplus",
                itemId = 251214,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "虚空之痕竞技场",
                type = "mplus",
                itemId = 251221,
                bonusIDs = {
                    6652,
                    13662,
                    12854,
                },
                stats = {
                    "versatility",
                    "mastery",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 159413,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12852,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
        },
        [5] = {
            {
                nameCn = "盘卷祭坛",
                type = "raid",
                encounterId = 2883,
                instanceId = 1320,
                itemId = 268222,
                bonusIDs = {
                    40,
                    13662,
                    13335,
                    13848,
                },
                stats = {
                    "haste",
                    "mastery",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 239036,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12846,
                },
                stats = {
                    "mastery",
                    "crit",
                },
            },
            {
                nameCn = "夺目谷",
                type = "mplus",
                itemId = 251193,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "versatility",
                },
            },
            {
                nameCn = "毒牙祭坛",
                type = "mplus",
                itemId = 273787,
                bonusIDs = {
                    6652,
                    13662,
                    13696,
                    12854,
                },
                stats = {
                    "crit",
                    "versatility",
                },
            },
            {
                nameCn = "红玉新生法池",
                type = "mplus",
                itemId = 193753,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "mastery",
                    "haste",
                },
            },
            {
                nameCn = "纳洛拉克的洞穴",
                type = "mplus",
                itemId = 251151,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
        },
        [3] = {
            {
                nameCn = "尼姆瑞莎·唤波者",
                type = "raid",
                encounterId = 2849,
                instanceId = 1317,
                itemId = 268226,
                bonusIDs = {
                    6652,
                    13662,
                    13335,
                    12854,
                },
                stats = {
                    "crit",
                    "mastery",
                },
            },
            {
                nameCn = "塞塔里斯神庙",
                type = "mplus",
                itemId = 239037,
                bonusIDs = {
                    13440,
                    42,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "crit",
                },
            },
            {
                nameCn = "密谋小径",
                type = "mplus",
                itemId = 251138,
                bonusIDs = {
                    13440,
                    6652,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "haste",
                    "mastery",
                },
            },
            {
                nameCn = "诸王之眠",
                type = "mplus",
                itemId = 239051,
                bonusIDs = {
                    13440,
                    40,
                    13662,
                    12699,
                    12854,
                },
                stats = {
                    "versatility",
                    "mastery",
                },
            },
        },
    },
}
BisData.raidBossOrder = { [2888]=1, [2874]=2, [2894]=3, [2882]=4, [2871]=5, [2887]=6, [2883]=7, [2895]=8, [2849]=9 }
BisData.raidBossInstance = { [2888]=1320, [2874]=1320, [2894]=1320, [2882]=1320, [2871]=1320, [2887]=1320, [2883]=1320, [2895]=1320, [2849]=1317 }
BisData.randStatItems = { [237828]=true, [237829]=true, [237830]=true, [237831]=true, [237832]=true, [237833]=true, [237834]=true, [237835]=true, [237836]=true, [237837]=true, [237838]=true, [237839]=true, [237840]=true, [237841]=true, [237842]=true, [237843]=true, [237845]=true, [237846]=true, [237847]=true, [237848]=true, [237850]=true, [239648]=true, [239649]=true, [239650]=true, [239651]=true, [239652]=true, [239653]=true, [239655]=true, [239656]=true, [240947]=true, [240949]=true, [240950]=true, [240951]=true, [244568]=true, [244569]=true, [244570]=true, [244572]=true, [244573]=true, [244574]=true, [244575]=true, [244576]=true, [244577]=true, [244578]=true, [244579]=true, [244580]=true, [244581]=true, [244582]=true, [244583]=true, [244584]=true, [245769]=true, [245770]=true, [245771]=true, [265337]=true, [271434]=true, [271435]=true, [271436]=true, [271438]=true, [271440]=true, [271441]=true, [271444]=true, [271445]=true, [271638]=true }

local SPEC_CN = {
    ["元素"] = "ELEMENTAL",
    ["兽王"] = "BEASTMASTERY",
    ["冰法"] = "FROST",
    ["冰霜"] = "FROST",
    ["刺杀"] = "ASSASSINATION",
    ["噬灭"] = "DEVAURER",
    ["增强"] = "ENHANCEMENT",
    ["增辉"] = "AUGMENTATION",
    ["复仇"] = "VENGEANCE",
    ["奥术"] = "ARCANE",
    ["守护"] = "GUARDIAN",
    ["射击"] = "MARKSMANSHIP",
    ["平衡"] = "BALANCE",
    ["恢复"] = "RESTORATION",
    ["恩护"] = "PRESERVATION",
    ["恶魔"] = "DEMONOLOGY",
    ["惩戒"] = "RETRIBUTION",
    ["戒律"] = "DISCIPLINE",
    ["敏锐"] = "SUBTLETY",
    ["暗影"] = "SHADOW",
    ["武器"] = "ARMS",
    ["毁灭"] = "DESTRUCTION",
    ["浩劫"] = "HAVOC",
    ["湮灭"] = "DEVASTATION",
    ["火焰"] = "FIRE",
    ["狂徒"] = "OUTLAW",
    ["狂怒"] = "FURY",
    ["生存"] = "SURVIVAL",
    ["痛苦"] = "AFFLICTION",
    ["神圣"] = "HOLY",
    ["织雾"] = "MISTWEAVER",
    ["踏风"] = "WINDWALKER",
    ["邪恶"] = "UNHOLY",
    ["酒仙"] = "BREWMASTER",
    ["野性"] = "FERAL",
    ["防护"] = "PROTECTION",
    ["鲜血"] = "BLOOD",
}

local HERO_CN = {
    ["丛林守护者"] = "Keeper of the Grove",
    ["先知"] = "Farseer",
    ["利爪德鲁伊"] = "Druid of the Claw",
    ["命缚者"] = "Fatebound",
    ["哨兵"] = "Sentinel",
    ["图腾祭司"] = "Totemic",
    ["圣殿骑士"] = "Templar",
    ["地狱召唤者"] = "Hellcaller",
    ["塑焰者"] = "Flameshaper",
    ["天启骑士"] = "Rider of the Apocalypse",
    ["天神御师"] = "Conduit of the Celestials",
    ["奥达奇收割者"] = "Aldrachi Reaver",
    ["屠戮者"] = "Slayer",
    ["山丘领主"] = "Mountain Thane",
    ["巨神兵"] = "Colossus",
    ["影踪派"] = "Shado-Pan",
    ["恶魔使徒"] = "Diabolist",
    ["执政官"] = "Archon",
    ["日怒"] = "Sunfury",
    ["时空守卫"] = "Chronowarden",
    ["欺诈者"] = "Trickster",
    ["死亡使者"] = "Deathbringer",
    ["死亡猎手"] = "Deathstalker",
    ["歼灭者"] = "Annihilator",
    ["灵魂收割者"] = "Soul Harvester",
    ["烈日先驱"] = "Herald of the Sun",
    ["猎群领袖"] = "Pack Leader",
    ["疾咒师"] = "Spellslinger",
    ["神谕者"] = "Oracle",
    ["祥和宗师"] = "Master of Harmony",
    ["艾露恩钦选者"] = "Elune's Chosen",
    ["荒野追猎者"] = "Wildstalker",
    ["萨莱因"] = "San'layn",
    ["虚痕枭雄"] = "Void-Scarred",
    ["虚空编织者"] = "Voidweaver",
    ["邪痕枭雄"] = "Fel-Scarred",
    ["铸光者"] = "Lightsmith",
    ["霜火"] = "Frostfire",
    ["风暴使者"] = "Stormbringer",
    ["鳞长"] = "Scalecommander",
    ["黑暗游侠"] = "Dark Ranger",
}

-- 数据过滤（使用率参照系 / 排除团本 / 难度档）已移到 core/BisPack.lua，
-- 改为「按专精惰性重建」：以前换个设置就要把 40 个专精全部重建一遍。
-- ⛔ 别在这里再写一份 ApplyDataFilters / _cacheRaw —— 那就是同一件事两处实现，
--    早晚改一处漏一处。BisPack.Install 会在文件末尾把这些方法挂上去。

function BisData:GetSpecData(class, spec, heroTalent)
    if not class or not spec then return nil end
    self:ApplyDataFilters()
    local c = class:upper()
    local s = SPEC_CN[spec] or spec:upper()
    local h = HERO_CN[heroTalent or ""] or heroTalent or ""
    local key = string.format("%s/%s/%s", c, s, h)
    if self.specs[key] then return self.specs[key] end
    -- Fallback: any hero talent for this class/spec (gear is the same across hero talents)
    local prefix = string.format("%s/%s/", c, s)
    for k, v in pairs(self.specs) do
        if string.find(k, prefix, 1, true) then
            return v
        end
    end
    return nil
end

function BisData:GetSlotCandidates(class, spec, heroTalent, slotId)
    local data = self:GetSpecData(class, spec, heroTalent)
    if not data or not data.bisBySlot then return nil end
    return data.bisBySlot[slotId]
end

function BisData:FindItem(class, spec, heroTalent, itemId)
    local data = self:GetSpecData(class, spec, heroTalent)
    if not data or not data.bisBySlot then return nil end
    for slotId, candidates in pairs(data.bisBySlot) do
        for rank, entry in ipairs(candidates) do
            if entry.itemId == itemId then
                return entry, slotId, rank, #candidates
            end
        end
    end
    return nil
end

--- Group items by source category for a farming-plan view.
--- Returns a table with keys: raid, mplus, crafted, world, other.
--- Each value is an array of { slotId, item } .
-- allMode（2026-09-22）：刷本规划的「第一BiS: 全部」要真给全部候选，不然和「只看」一模一样
--   （玩家「什么玩意」09-22：「第一bis只看和全部，显示都是全部，不会切换了」）。
--   ⛔ 默认仍是 #1（成对 #1/#2）—— 主面板的制造推荐等调用方靠这个口径。
function BisData:GetItemsBySource(class, spec, heroTalent, is2H, allMode)
    local data = self:GetSpecData(class, spec, heroTalent)
    if not data or not data.bisBySlot then return nil end
    local bySlot = data.bisBySlot
    local groups = {}
    local function addEntry(slotId, entry)
        local cat = entry.sourceCategory or "other"
        if not groups[cat] then groups[cat] = {} end
        table.insert(groups[cat], { slotId = slotId, item = entry })
    end
    -- Merge two slots into one usage-ranked pool, deduped by item.
    local function mergePool(a, b)
        local byId, order = {}, {}
        local function add(list)
            if type(list) ~= "table" then return end
            for _, e in ipairs(list) do
                local prev = byId[e.itemId]
                if not prev then byId[e.itemId] = e; order[#order + 1] = e
                elseif (e.usagePct or 0) > (prev.usagePct or 0) then
                    byId[e.itemId] = e
                    for i, o in ipairs(order) do if o.itemId == e.itemId then order[i] = e break end end
                end
            end
        end
        add(a); add(b)
        table.sort(order, function(x, y) return (x.usagePct or 0) > (y.usagePct or 0) end)
        return order
    end
    local PAIRED = { [11] = true, [12] = true, [13] = true, [14] = true }
    -- Non-paired slots: weapons 2H→1 / dual→2, everything else top 1.
    for slotId, candidates in pairs(bySlot) do
        if not PAIRED[slotId] then
            local limit = allMode and 3 or 1
            if slotId == 16 or slotId == 17 then limit = allMode and (is2H and 2 or 4) or (is2H and 1 or 2) end
            for idx, entry in ipairs(candidates) do
                if idx <= limit then addEntry(slotId, entry) end
            end
        end
    end
    -- Paired slots are one pool: only the top-2 distinct items matter
    -- (#1 → slot 1, #2 → slot 2), not top-2 per slot.
    for _, pair in ipairs({ { 11, 12 }, { 13, 14 } }) do
        local pool = mergePool(bySlot[pair[1]], bySlot[pair[2]])
        for i = 1, math.min(allMode and 4 or 2, #pool) do
            addEntry(pair[(i % 2 == 1) and 1 or 2], pool[i])   -- 奇数进第一格、偶数进第二格，原来的 #1→11 / #2→12 不变
        end
    end
    return groups
end

--- Calculate stat gap between current stats and the spec's targets.
--- Returns nil if no target stats defined for the spec.
--- currentStats: { crit = 25.0, haste = 18.0, mastery = 20.0, versatility = 8.0 }
--- Returns per stat: { current, target, gap, deficit, atTarget, color }
function BisData:GetStatGap(currentStats, class, spec, heroTalent)
    local data = self:GetSpecData(class, spec, heroTalent)
    if not data or not data.targetStatPercents then return nil end
    local gaps = {}
    for stat, target in pairs(data.targetStatPercents) do
        local current = currentStats[stat] or 0
        local gap = target - current
        gaps[stat] = {
            current = current,
            target = target,
            gap = gap,
            deficit = math.max(0, gap),
            atTarget = current >= target,
            color = self.statMeta and self.statMeta[stat] and self.statMeta[stat].color,
        }
    end
    return gaps
end

--- Dump all encounters in the current expansion to chat.
--- Use this to discover instanceId / encounterId values for populating
--- the encounter journal mapping in generate_bisdata_lua.py.
--- Usage: /gi dumpids
function BisData:DumpEncounterJournal()
    if not EJ_GetInstanceByIndex then
        GearInsight:Print("Encounter Journal API not available.")
        return
    end
    local tierInfo = ""
    if EJ_GetNumTiers and EJ_GetTierInfo then
        local numTiers = EJ_GetNumTiers()
        if numTiers and numTiers > 0 then
            tierInfo = " / " .. (EJ_GetTierInfo(numTiers) or "Tier " .. numTiers)
        end
    end
    GearInsight:Print("=== Encounter Journal" .. tierInfo .. " ===")

    -- Helper to dump encounters for the currently selected instance
    local function _DumpEncounters()
        local found = false
        for j = 1, 50 do
            local encName, encDesc, encounterId = EJ_GetEncounterInfoByIndex(j)
            if not encName then break end
            found = true
            local descShort = (encDesc or ""):sub(1, 40)
            GearInsight:Print(string.format("    [%d] id=%d  %s  -- %s", j, encounterId or 0, encName, descShort))
        end
        if not found then
            GearInsight:Print("    (no encounter API available)")
        end
    end

    -- Raids - iterate by index until nil (no EJ_GetNumInstances exists)
    GearInsight:Print("--- Raids ---")
    for i = 1, 200 do
        local instanceId, instanceName = EJ_GetInstanceByIndex(i, true)
        if not instanceId then break end
        GearInsight:Print(string.format("  [raid] instanceId=%d  %s", instanceId, instanceName or "???"))
        EJ_SelectInstance(instanceId)
        _DumpEncounters()
    end

    -- Dungeons
    GearInsight:Print("--- Dungeons ---")
    for i = 1, 200 do
        local instanceId, instanceName = EJ_GetInstanceByIndex(i, false)
        if not instanceId then break end
        GearInsight:Print(string.format("  [dungeon] instanceId=%d  %s", instanceId, instanceName or "???"))
        EJ_SelectInstance(instanceId)
        _DumpEncounters()
    end

    -- Diagnostic: test encounter journal navigation with confirmed-available APIs
    GearInsight:Print("=== API Diagnostic ===")
    local function closeJ() if EncounterJournal and EncounterJournal:IsShown() then ToggleEncounterJournal() end end
    local function openJ() local io=EncounterJournal and EncounterJournal:IsShown() if not io then ToggleEncounterJournal() end end

    -- Verify encounter IDs are valid
    GearInsight:Print("EJ_GetEncounterInfo(2827): " .. tostring(EJ_GetEncounterInfo and EJ_GetEncounterInfo(2827) or "nil"))
    GearInsight:Print("EJ_GetEncounterInfo(2736): " .. tostring(EJ_GetEncounterInfo and EJ_GetEncounterInfo(2736) or "nil"))

    -- Test: open journal → select instance → select encounter (the click-handler approach)
    closeJ()
    GearInsight:Print("[Test] Open journal, then EJ_SelectInstance(1307) + EJ_SelectEncounter(2736)...")
    openJ()
    if EJ_SelectInstance then EJ_SelectInstance(1307) end
    if EJ_SelectEncounter then EJ_SelectEncounter(2736) end
    GearInsight:Print("  -> 请观察日志是否定位到 虚影尖塔→陨落之王萨哈达尔")

    -- Also try reversed: select first, then open journal
    closeJ()
    GearInsight:Print("[Test B] EJ_SelectInstance+SelectEncounter first, THEN open journal...")
    if EJ_SelectInstance then EJ_SelectInstance(1307) end
    if EJ_SelectEncounter then EJ_SelectEncounter(2736) end
    openJ()
    GearInsight:Print("  -> 请观察日志是否定位到 虚影尖塔→陨落之王萨哈达尔")

    GearInsight:Print("Available functions: EncounterJournal_OpenJournal=nil, EJ_SelectEncounter=" .. tostring(EJ_SelectEncounter ~= nil) .. ", EJ_SelectInstance=" .. tostring(EJ_SelectInstance ~= nil))
    GearInsight:Print("=== End of dump ===")
end

-- ── Multi-spec farming plan ─────────────────────────────────────────
-- One representative build per spec of a class (the hero-talent build with
-- the most candidates = widest usage coverage). Used by the multi-spec
-- farming planner so the player can pick which specs to farm for.
function BisData:GetClassSpecs(class)
    if not class then return {} end
    local c = class:upper()
    local bySpec = {}  -- specName -> { key, count, heroTalent }
    for key, data in pairs(self.specs) do
        if data.className == c then
            local count = 0
            if data.bisBySlot then
                for _, cands in pairs(data.bisBySlot) do count = count + #cands end
            end
            local cur = bySpec[data.specName]
            if not cur or count > cur.count then
                bySpec[data.specName] = { key = key, count = count, heroTalent = data.heroTalent }
            end
        end
    end
    local out = {}
    for sn, info in pairs(bySpec) do
        out[#out + 1] = {
            specName   = sn,
            specId     = self.specIds and self.specIds[c .. "/" .. sn] or nil,
            heroTalent = info.heroTalent,
            key        = info.key,
        }
    end
    return out
end

-- Cross-spec farming plan: for each selected spec, group its BiS targets by
-- boss, mark owned, and pick a recommended loot specialization per boss (the
-- spec with the most still-needed items there).
--   class             : class file string (e.g. "DRUID")
--   selectedSpecNames : array of spec names (e.g. { "GUARDIAN", "RESTORATION" })
--   isOwned           : function(itemId) -> bool
-- Returns: bossKey -> { sourceName, category, encounterId, instanceId,
--                       recommendSpec, recommendSpecId, missingCount,
--                       wants = { {specName, specId, slotId, item, owned}, ... } }
function BisData:GetCrossSpecFarmPlan(class, selectedSpecNames, isOwned)
    if not class then return nil end
    self:EnsureUsageMode()
    local c = class:upper()
    isOwned = isOwned or function() return false end
    local want = {}
    for _, sn in ipairs(selectedSpecNames or {}) do want[sn:upper()] = true end

    local function mergePool(a, b)
        local byId, order = {}, {}
        local function add(list)
            if type(list) ~= "table" then return end
            for _, e in ipairs(list) do
                local p = byId[e.itemId]
                if not p then byId[e.itemId] = e; order[#order + 1] = e
                elseif (e.usagePct or 0) > (p.usagePct or 0) then
                    byId[e.itemId] = e
                    for i, o in ipairs(order) do if o.itemId == e.itemId then order[i] = e break end end
                end
            end
        end
        add(a); add(b)
        table.sort(order, function(x, y) return (x.usagePct or 0) > (y.usagePct or 0) end)
        return order
    end

    -- Index which selected specs list each item anywhere in their BiS (a
    -- cloak / neck / ring with no primary stat is usable by several specs).
    local itemSpecs = {}
    local function noteItem(itemId, specName, specId)
        local rec = itemSpecs[itemId]
        if not rec then rec = { list = {}, set = {} }; itemSpecs[itemId] = rec end
        if not rec.set[specName] then
            rec.set[specName] = true
            rec.list[#rec.list + 1] = { name = specName, id = specId }
        end
    end

    local groups = {}
    local function addWant(item, specName, specId, slotId)
        local key
        if item.encounterId then key = "e" .. item.encounterId
        elseif item.instanceId then key = "i" .. item.instanceId
        else key = "c" .. (item.sourceCategory or "other") end
        local g = groups[key]
        if not g then
            g = { sourceName = item.source or "", category = item.sourceCategory or "other",
                  encounterId = item.encounterId, instanceId = item.instanceId,
                  bossOrder = item.bossOrder, wants = {} }
            groups[key] = g
        end
        g.wants[#g.wants + 1] = {
            specName = specName, specId = specId, slotId = slotId,
            item = item, owned = isOwned(item.itemId, item.ilvl, slotId) and true or false,
        }
    end

    for _, sp in ipairs(self:GetClassSpecs(c)) do
        if want[sp.specName] then
            local data = self.specs[sp.key]
            local bySlot = data and data.bisBySlot
            if bySlot then
                for _, cands in pairs(bySlot) do
                    for _, cc in ipairs(cands) do noteItem(cc.itemId, sp.specName, sp.specId) end
                end
                local done = {}
                for _, pr in ipairs({ { 11, 12 }, { 13, 14 } }) do
                    local pool = mergePool(bySlot[pr[1]], bySlot[pr[2]])
                    if pool[1] then addWant(pool[1], sp.specName, sp.specId, pr[1]) end
                    if pool[2] then addWant(pool[2], sp.specName, sp.specId, pr[2]) end
                    done[pr[1]] = true; done[pr[2]] = true
                end
                for slotId, cands in pairs(bySlot) do
                    if not done[slotId] and cands[1] then
                        addWant(cands[1], sp.specName, sp.specId, slotId)
                    end
                end
            end
        end
    end

    for _, g in pairs(groups) do
        for _, w in ipairs(g.wants) do
            local rec = itemSpecs[w.item.itemId]
            w.usedBy = rec and rec.list or { { name = w.specName, id = w.specId } }
        end
        local cnt = {}
        for _, w in ipairs(g.wants) do
            if not w.owned then
                local e = cnt[w.specName] or { n = 0, specId = w.specId }
                e.n = e.n + 1
                cnt[w.specName] = e
            end
        end
        local bestName, bestN, bestId = nil, 0, nil
        for sn, e in pairs(cnt) do
            if e.n > bestN then bestN = e.n; bestName = sn; bestId = e.specId end
        end
        g.recommendSpec = bestName
        g.recommendSpecId = bestId
        g.missingCount = bestN
    end

    return groups
end

GearInsight.BisData = BisData

-- 装上按需解码（core/BisPack.lua）
if GearInsight.BisPack then GearInsight.BisPack.Install(BisData) end

--[[
--@debug Auto-generated validation report
-- Total specs: 40
-- Total items (candidate entries): 2993
-- Unique item IDs: 366
-- Specs with missing bisBySlot: 0
-- Items with missing required fields: 0
-- Data integrity check: OK
--]]
