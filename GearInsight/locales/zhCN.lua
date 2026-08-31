-- GearInsight - Simplified Chinese Locale
-- All Chinese strings used by the addon are defined here.

local L = {}
GearInsight = GearInsight or {}
GearInsight.L = L

-- ⭐ 2026-08-29：语言的**唯一真相源**。zhCN.lua 是 .toc 里第一个加载的文件，
-- 在这里定一次，后面所有文件（包括 enUS/zhTW 的补丁块、GearInsight.lua 的 _LOCALE）
-- 都读它。⛔不允许再出现第二处 GetLocale() 判语言 —— 两套口径必然错位，
-- 会出现「文案英文但部位名中文」这种混搭（bug 台账 #13/#15）。
GearInsight.LOCALE = GEARINSIGHT_FORCE_LOCALE or (GetLocale and GetLocale()) or "enUS"

-- General
L["ADDON_NAME"]             = "GearInsight"
L["ADDON_LOADED"]           = "GearInsight 已加载。输入 /gi 打开面板。"
L["OPEN_PANEL"]             = "打开装备分析面板"
L["CLOSE_PANEL"]            = "关闭面板"
L["RELOAD_DATA"]            = "重新读取装备数据"

-- Stats
L["STAT_CRIT"]              = "暴击"
L["STAT_HASTE"]             = "急速"
L["STAT_VERSATILITY"]       = "全能"
L["STAT_MASTERY"]           = "精通"
L["STAT_STRENGTH"]          = "力量"
L["STAT_AGILITY"]           = "敏捷"
L["STAT_INTELLECT"]         = "智力"
L["STAT_STAMINA"]           = "耐力"

-- Panel titles and labels
L["PANEL_TITLE"]            = "GearInsight"
L["SECTION_OVERVIEW"]       = "装备总览"
L["SECTION_STATS"]          = "属性达成度"
L["SECTION_UPGRADE"]        = "升级建议"
L["CURRENT_ILVL"]           = "当前装等"
L["TARGET_ILVL"]            = "毕业装等"
L["SPEC_LABEL"]             = "专精"
L["CLASS_LABEL"]            = "职业"
L["HERO_TALENT_LABEL"]      = "英雄天赋"

-- Upgrade list
L["SLOT_HEAD"]              = "头盔"
L["SLOT_NECK"]              = "颈部"
L["SLOT_SHOULDER"]          = "肩膀"
L["SLOT_CHEST"]             = "胸甲"
L["SLOT_WAIST"]             = "腰带"
L["SLOT_LEGS"]              = "护腿"
L["SLOT_FEET"]              = "靴子"
L["SLOT_WRIST"]             = "手腕"
L["SLOT_HANDS"]             = "手套"
L["SLOT_FINGER1"]           = "戒指1"
L["SLOT_FINGER2"]           = "戒指2"
L["SLOT_TRINKET1"]          = "饰品1"
L["SLOT_TRINKET2"]          = "饰品2"
L["SLOT_BACK"]              = "背部"
L["SLOT_MAINHAND"]          = "主手"
L["SLOT_OFFHAND"]           = "副手"
L["SLOT_UNKNOWN"]           = "未知槽位"
L["NO_ITEM"]                = "（空槽）"

-- Tooltip lines
L["TOOLTIP_UPGRADE"]        = "对你的提升"
L["TOOLTIP_SLOT_RANK"]      = "槽位排名"
L["TOOLTIP_USAGE"]          = "顶尖使用率"
L["TOOLTIP_SOURCE"]         = "获取方式"
L["TOOLTIP_ESTIMATED"]      = "（估算）"
L["TOOLTIP_TOTAL_ITEMS"]    = "共%d件参考"

-- Stat progress bar
L["STAT_PROGRESS_FMT"]      = "%.1f%% / %.1f%%（目标）"
L["NO_SPEC_DATA"]           = "暂无该专精的BiS数据"
L["DATA_VERSION"]           = "数据版本"

-- Minimap button tooltip
L["MINIMAP_TOOLTIP_TITLE"]  = "GearInsight"
L["MINIMAP_TOOLTIP_LEFT"]   = "左键：打开/关闭面板"
L["MINIMAP_TOOLTIP_RIGHT"]  = "右键：重新读取装备"

-- Messages
L["GEAR_REFRESHED"]         = "装备数据已刷新。"
L["SAVED_OK"]               = "角色数据已保存至 GearInsightDB。"
L["NO_ITEM_EQUIPPED"]       = "该槽位未装备物品。"
L["UNKNOWN_CLASS"]          = "未知职业"
L["UNKNOWN_SPEC"]           = "未知专精"
