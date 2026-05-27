if not(GetLocale() == "zhTW") then
    return
end

local ADDON_NAME, CooldownDone = ...

local L = CooldownDone.Locale

L["addonName"] = "CD 就緒"
L["UnknownSpell"] = "未知法術"
L["UnknownItem"] = "未知物品"
L["UnknownAura"] = "未知光環"
L["Ready"] = "就緒"
L["ReadyTooltip"] = "技能就緒的文字"
L["Expired"] = "結束"
L["ExpiredTooltip"] = "BUFF 結束的文字"
L["Gained"] = "獲得"
L["GainedTooltip"] = "獲得 BUFF 的文字"
L["BuffList"] = "BUFF 列表"
L["AbilityList"] = "技能清單"
L["PleaseEnterID"] = "請輸入 ID"
L["IDNotFound"] = "未找到，請輸入正確的 ID"
L["IDExists"] = "已經存在"
L["CustomName"] = "自訂名稱\n或輸入聲音檔ID\n或輸入：\nInterface\\AddOns\\\nSomeAddOn\\SomeFile.ogg"
L["AuraExpired"] = "BUFF 結束"
L["AuraGained"] = "BUFF 獲得"
L["EnableTooltip"] = "啟用/停用插件功能，無需重載介面"
L["Debug"] = "調試"
L["DebugTooltip"] = "啟用/停用偵錯資訊"
L["VoiceTooltip"] = "選擇使用的語音"
L["VoiceSpeed"] = "語速"
L["Test"] = "測試"
L["ClickToTest"] = "點擊測試"
L["SpellName"] = "技能名稱"
L["AbilityListTip"] = "提示：修改天賦/習得法術/切換天賦/切換專精等操作後請重新載入遊戲！"
L["BuffListTip"] = "提示：移除 BUFF 資料後請重新載入遊戲！"
L["BuffListTip2"] = "一些本插件內建的BUFF合集ID：\n-1：全部\"時間扭曲\"類BUFF\n-2：全部\"時光位移\"類BUFF"
L["SpellList"] = "法術列表"
L["EquippedItemList"] = "裝備清單"
L["AddBuff"] = "新增 BUFF"
L["AddBuffTooltip"] = "輸入 ID 後點選按鈕"
L["ERR_PlaySoundFile"] = "播放聲音檔案出錯"
L["ERR_InCombatSettings"] = "戰鬥中，請脫戰後重試"
