local _, addon = ...
local L = addon.Localization.NewLocale("zhTW")
if not L then return end

KrowiEVU.PluginsApi:LoadPluginLocalization(L)

-- [[ Everything after this line is automatically generated from CurseForge and is not meant for manual edit - SOURCETOKEN - AUTOGENTOKEN ]] --

-- [[ Exported at 2026-02-08 10-26-38 ]] --
L["Are you sure you want to hide the options button?"] = "是否確定隱藏按鈕？再次顯示按鈕請到 {gameMenu} > {addOns} > 商人 > {general} > {options}"
L["Columns"] = "列數"
L["Columns first"] = "先豎後橫排列"
L["Custom"] = "自定義"
L["Default filters"] = "默認過濾器"
L["Deselect All"] = "全部取消"
L["Filters"] = "過濾器"
L["Hide collected"] = "隱藏已擁有的"
L["Icon Left click"] = "快速版面配置"
L["Icon Right click"] = "設定選項"
L["Mounts"] = "坐騎"
L["Only show"] = "只顯示"
L["Options button"] = "選項按鈕"
L["Options Desc"] = "打開選項，也可以從商人界面左上方的選項按鈕打開選項。"
L["Other"] = "其他"
L["Pets"] = "寵物"
L["Plugin_CanIMogIt_Desc"] = "這個插件修復了在應用不同過濾器時，商人物品圖標的疊加問題。"
L["Plugin_CanIMogIt_Name"] = true
L["Rows"] = "行數"
L["Rows first"] = "先橫豎後排列"
L["Select All"] = "全部選擇"
L["Show options button"] = "顯示設置按鈕"
L["Show options button Desc"] = "顯示/隱藏商人界面的設置按鈕"
L["Toys"] = "玩具"
L["Unchecked"] = "停用"
L["Wago"] = true
L["Ensembles"] = "套裝"
L["Arsenals"] = "武器"
L["Recipes"] = "食譜"
L["Illusions"] = "幻化"
L["Housing"] = "家宅"
L["RememberSearch"] = "記憶搜索"
L["RememberSearchBetweenVendors"] = "在商人之間搜索記錄"
L["Housing Quantity"] = "家宅數"
L["RememberFilter"] = "記住過濾器"
L["Token Banner"] = "代幣條"
L["Set custom"] = "設置自定義"
L["Token Format"] = "標簽格式"
L["Need"] = "需要"
L["Have"] = "擁有"
L["Both"] = "都要"
L["Enter housing quantity"] = "請輸入住房數量（1-999）："
L["Enter number of columns"] = "請輸入列數（2-99）："
L["Enter number of rows"] = "請輸入行數（1-99）："