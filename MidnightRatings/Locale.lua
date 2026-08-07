local ADDON_NAME = "MidnightRatings"
local locale = GetLocale()

local L = setmetatable({}, {
    __index = function(t, k)
        return k
    end
})

-- =========================================================================
-- English (Default)
-- =========================================================================
L["PANEL_TITLE"] = "Percentage Ratings Settings"
L["DISPLAY_OPTIONS"] = "1. Display Options"
L["APPEND_MODE"] = "Append: +100 Haste (3.00%)"
L["REPLACE_MODE"] = "Replace: +3.00% Haste"
L["SHOW_RATING"] = "Append Rating in Replace Mode"
L["SPLIT_VERS"] = "Show Versatility as (Dmg/Reduct)"
L["CONVERSION_FILTERS"] = "2. Conversion Filters"
L["ENABLE_ENCHANTS"] = "Convert Enchant Numbers"
L["ENABLE_GEMS"] = "Convert Gem Numbers"
L["ENABLE_COMPARISON"] = "Convert Comparison Stats (Shift-Hover)"
L["ENABLE_PROFESSIONS"] = "Convert Profession Stats (Gathering & Crafting)"
L["ENABLE_AURAS"] = "Convert Buff/Debuff & Spell Stats (only works outside of combat)"
L["COLOR_SETTINGS"] = "3. Color Settings"
L["COLOR_MAINTAIN"] = "Maintain Text Color (Matches Gear/Gem Color)"
L["COLOR_UNIFIED"] = "|cffFFFC03Unified Yellow|r"
L["COLOR_CUSTOM"] = "Custom Color"
L["COLOR_STAT"] = "Stat Colors (Customizable)"
L["STAT_TERTIARY"] = "Tertiary"
L["AND"] = " and "
L["ENCHANT_MATCH"] = "enchant"
L["COLOR_TOOLTIP_TITLE"] = "Color Settings"
L["COLOR_TOOLTIP_LEFT"] = "Left-Click to choose a new color."
L["COLOR_TOOLTIP_RIGHT"] = "Right-Click to reset to default."
L["ERROR_MENU_FAILED"] = "|cffFF0000[Percentage Ratings] Error:|r The Menu failed to register."
L["ERROR_RELOAD_SUGGEST"] = "Try: /console reloadui"
L["COMPARISON_CHANGES"] = "changes will occur"
L["COMPARISON_REPLACE"] = "replace this item"
L["COMPARISON_EQUIPPED"] = "currently equipped"
L["RESET_SUCCESS"] = "Database has been reset to defaults."


if locale == "zhCN" then
    L["PANEL_TITLE"] = "Percentage Ratings设置"
    L["DISPLAY_OPTIONS"] = "1. 显示选项"
    L["APPEND_MODE"] = "追加: +100 急速（3.00%）"
    L["REPLACE_MODE"] = "替换: +3.00% 急速"
    L["SHOW_RATING"] = "替换模式下显示原始数值"
    L["SPLIT_VERS"] = "全能显示为伤害/减伤"
    L["CONVERSION_FILTERS"] = "2. 转换选项"
    L["ENABLE_ENCHANTS"] = "转换附魔数值"
    L["ENABLE_GEMS"] = "转换宝石数值"
    L["ENABLE_COMPARISON"] = "转换对比数值（Shift+悬停）"
    L["ENABLE_PROFESSIONS"] = "转换专业属性（采集与制造）"
    L["ENABLE_AURAS"] = "转换增益/减益及法术属性（仅限非战斗状态）"
    L["COLOR_SETTINGS"] = "3. 颜色设置"
    L["COLOR_MAINTAIN"] = "原始颜色（匹配装备/宝石颜色）"
    L["COLOR_UNIFIED"] = "|cffFFFC03统一黄色|r"
    L["COLOR_CUSTOM"] = "自定义颜色"
    L["COLOR_STAT"] = "属性颜色（自定义）"
    L["STAT_TERTIARY"] = "次属性"
    L["AND"] = " 和"
    L["ENCHANT_MATCH"] = "附魔"
    L["COLOR_TOOLTIP_TITLE"] = "颜色设置"
    L["COLOR_TOOLTIP_LEFT"] = "左键点击选择新颜色"
    L["COLOR_TOOLTIP_RIGHT"] = "右键点击重置为默认"
    L["ERROR_MENU_FAILED"] = "|cffFF0000[Percentage Ratings] 错误:|r 菜单注册失败。"
    L["ERROR_RELOAD_SUGGEST"] = "尝试输入: /console reloadui"
    L["COMPARISON_CHANGES"] = "改变"
    L["COMPARISON_REPLACE"] = "替换"
    L["COMPARISON_EQUIPPED"] = "已装备"
    L["RESET_SUCCESS"] = "数据库已重置为默认值。"
end

-- =========================================================================
-- Traditional Chinese (zhTW)
-- =========================================================================
if locale == "zhTW" then
    L["PANEL_TITLE"] = "Percentage Ratings設定"
    L["DISPLAY_OPTIONS"] = "1. 顯示選項"
    L["APPEND_MODE"] = "追加: +100 加速（3.00%）"
    L["REPLACE_MODE"] = "替換: +3.00% 加速"
    L["SHOW_RATING"] = "替換模式下顯示原始數值"
    L["SPLIT_VERS"] = "全能顯示為傷害/減傷"
    L["CONVERSION_FILTERS"] = "2. 轉換過濾"
    L["ENABLE_ENCHANTS"] = "轉換附魔數值"
    L["ENABLE_GEMS"] = "轉換寶石數值"
    L["ENABLE_COMPARISON"] = "轉換對比數值（Shift+懸停）"
    L["ENABLE_PROFESSIONS"] = "轉換專業屬性（採集與製造）"
    L["ENABLE_AURAS"] = "轉換增益/減益及法術屬性（僅限非戰鬥狀態）"
    L["COLOR_SETTINGS"] = "3. 顏色設定"
    L["COLOR_MAINTAIN"] = "保留原始顏色（匹配裝備/寶石顏色）"
    L["COLOR_UNIFIED"] = "|cffFFFC03統一黃色|r"
    L["COLOR_CUSTOM"] = "自訂顏色"
    L["COLOR_STAT"] = "屬性顏色（自定義）"
    L["STAT_TERTIARY"] = "次屬性"
    L["AND"] = " 和"
    L["ENCHANT_MATCH"] = "附魔"
    L["COLOR_TOOLTIP_TITLE"] = "顏色設定"
    L["COLOR_TOOLTIP_LEFT"] = "左鍵點擊選擇新顏色"
    L["COLOR_TOOLTIP_RIGHT"] = "右鍵點擊重置為預設"
    L["ERROR_MENU_FAILED"] = "|cffFF0000[Percentage Ratings] 錯誤:|r 選單註冊失敗。"
    L["ERROR_RELOAD_SUGGEST"] = "嘗試: /console reloadui"
    L["COMPARISON_CHANGES"] = "改變"
    L["COMPARISON_REPLACE"] = "替換"
    L["COMPARISON_EQUIPPED"] = "已裝備"
    L["RESET_SUCCESS"] = "資料庫已重設為預設值。"
end

MidnightRatingsLocale = L