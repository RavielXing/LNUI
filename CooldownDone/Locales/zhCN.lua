if not(GetLocale() == "zhCN") then
    return
end

local ADDON_NAME, CooldownDone = ...

local L = CooldownDone.Locale

L["addonName"] = "CD 就绪"
L["UnknownSpell"] = "未知法术"
L["UnknownItem"] = "未知物品"
L["UnknownAura"] = "未知光环"
L["Ready"] = "就绪"
L["ReadyTooltip"] = "技能就绪的文本"
L["Expired"] = "结束"
L["ExpiredTooltip"] = "BUFF 结束的文本"
L["Gained"] = "获得"
L["GainedTooltip"] = "获得 BUFF 的文本"
L["BuffList"] = "BUFF 列表"
L["AbilityList"] = "技能列表"
L["PleaseEnterID"] = "请输入 ID"
L["IDNotFound"] = "未找到，请输入正确的 ID"
L["IDExists"] = "已经存在"
L["CustomName"] = "自定义名称\n或输入声音文件ID\n或输入：\nInterface\\AddOns\\\nSomeAddOn\\SomeFile.ogg"
L["AuraExpired"] = "BUFF 结束"
L["AuraGained"] = "BUFF 获得"
L["EnableTooltip"] = "启用/禁用插件功能，无需重载界面"
L["Debug"] = "调试"
L["DebugTooltip"] = "启用/禁用调试信息"
L["VoiceTooltip"] = "选择使用的语音"
L["VoiceSpeed"] = "语速"
L["Test"] = "测试"
L["ClickToTest"] = "点击测试"
L["SpellName"] = "技能名称"
L["AbilityListTip"] = "提示：修改天赋/习得法术/切换天赋/切换专精等操作后请重新加载游戏！"
L["BuffListTip"] = "提示：移除 BUFF 数据后请重新加载游戏！"
L["BuffListTip2"] = "一些本插件内置的BUFF合集ID：\n-1：全部\"时间扭曲\"类BUFF\n-2：全部\"时空错位\"类BUFF"
L["SpellList"] = "法术列表"
L["EquippedItemList"] = "装备列表"
L["AddBuff"] = "添加 BUFF"
L["AddBuffTooltip"] = "输入 ID 后点击按钮"
L["ERR_PlaySoundFile"] = "播放声音文件出错"
L["ERR_InCombatSettings"] = "战斗中，请脱战后重试"

