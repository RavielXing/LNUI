-- ==========================================
-- LNuiChat 本地化模块
-- 支持简体中文(zhCN)和繁体中文(zhTW)
-- ==========================================

-- 检测客户端语言
local locale = GetLocale()
local isZhTW = (locale == "zhTW")

-- 本地化表
local L = {}
_G.LNuiChat_L = L

-- ==========================================
-- 通用文本
-- ==========================================
L["addon_name"] = isZhTW and "老農聊天條" or "老农聊天条"
L["prefix"] = isZhTW and "[老農聊天條]" or "[老农聊天条]"
L["icon"] = "|TInterface/AddOns/LNuiChat/Media/Emotion/laonong:20|t"

-- ==========================================
-- BDChatLog 聊天日志模块
-- ==========================================

-- 忽略的聊天标签页（战斗记录等）- 简繁体都要匹配
L["ignored_tabs"] = isZhTW and {
    ["戰鬥記錄"] = true, ["戰記"] = true, ["戰鬥"] = true, ["戰"] = true,
} or {
    ["战斗记录"] = true, ["战记"] = true, ["战斗"] = true, ["战"] = true,
}

-- 超链接悬停提示文本
if isZhTW then
    L["hlink_journal"] = "點擊查看冒險指南條目"
    L["hlink_transmogappearance"] = "點擊查看外觀"
    L["hlink_transmogillusion"] = "點擊查看幻象"
    L["hlink_battlepet"] = "點擊查看寵物信息"
    L["hlink_mountequipment"] = "點擊查看坐騎裝備"
    L["hlink_talentbuild"] = "點擊查看天賦配置"
    L["hlink_dungeonscore"] = "點擊查看史詩鑰石評分"
    L["hlink_pvprating"] = "點擊查看PvP評分"
    L["hlink_garrmission"] = "點擊打開要塞任務"
    L["hlink_garrfollower"] = "點擊查看追隨者"
    L["hlink_garrfollowerability"] = "點擊查看追隨者技能"
    L["hlink_worldmap"] = "點擊定位到地圖位置"
    L["hlink_perksactivity"] = "點擊查看旅行者日誌活動"
    L["hlink_initiativetask"] = "點擊查看住宅任務"
    L["hlink_housingdecor"] = "點擊查看住宅裝飾"
    L["hlink_warbandscene"] = "點擊查看戰團場景"
else
    L["hlink_journal"] = "点击查看冒险指南条目"
    L["hlink_transmogappearance"] = "点击查看外观"
    L["hlink_transmogillusion"] = "点击查看幻象"
    L["hlink_battlepet"] = "点击查看宠物信息"
    L["hlink_mountequipment"] = "点击查看坐骑装备"
    L["hlink_talentbuild"] = "点击查看天赋配置"
    L["hlink_dungeonscore"] = "点击查看史诗钥石评分"
    L["hlink_pvprating"] = "点击查看PvP评分"
    L["hlink_garrmission"] = "点击打开要塞任务"
    L["hlink_garrfollower"] = "点击查看追随者"
    L["hlink_garrfollowerability"] = "点击查看追随者技能"
    L["hlink_worldmap"] = "点击定位到地图位置"
    L["hlink_perksactivity"] = "点击查看旅行者日志活动"
    L["hlink_initiativetask"] = "点击查看住宅任务"
    L["hlink_housingdecor"] = "点击查看住宅装饰"
    L["hlink_warbandscene"] = "点击查看战团场景"
end

-- 锁定期间提示
L["lockdown_notice"] = isZhTW and 
    "|cffff9900[BDChatLog]|r：|cffffff00當前環境暫時限制了信息獲取，受限解除後將嘗試恢復 密語/隊團/公會 等聊天內容。|r" or
    "|cffff9900[BDChatLog]|r：|cffffff00当前环境暂时限制了信息获取，受限解除后将尝试恢复 密语/队团/公会 等聊天内容。|r"

-- 刷屏抑制提示
L["spam_suppress"] = isZhTW and
    "|cffff9900[BDChatLog]|r：|cffffff00檢測到短時間內多條相同信息，已自動抑制後續重複|r" or
    "|cffff9900[BDChatLog]|r：|cffffff00检测到短时间内多条相同信息，已自动抑制后续重复|r"
L["spam_prevent"] = isZhTW and "|cffffff00，防止存檔刷屏。|r" or "|cffffff00，防止存档刷屏。|r"

-- 会话分隔符
L["session_separator_prefix"] = isZhTW and "[ 登錄會話: " or "[ 登录会话: "
L["session_separator_suffix"] = " ] ------------------------|r"
L["prelogin_message_prefix"] = isZhTW and "- " or "- "

-- 颜色名称
L["color_gold"] = isZhTW and "金" or "金"
L["color_silver"] = isZhTW and "銀" or "银"
L["color_copper"] = isZhTW and "銅" or "铜"

-- 特殊内容标记
L["secret_message"] = "[??]"
L["censored_message"] = isZhTW and "[內容被和諧]" or "[内容被和谐]"
L["protected"] = "[Protected]"
L["bn_friend"] = isZhTW and "戰網好友" or "战网好友"

-- ==========================================
-- ChannelBar 频道栏模块
-- ==========================================

-- 按钮图标对应的单字符文本
L["btn_roll"] = "骰"
L["btn_world"] = "世"
L["btn_reload"] = "重"
L["btn_countdown"] = "倒"
L["btn_ready"] = "就"
L["btn_copy"] = isZhTW and "復" or "复"
L["btn_emote"] = "表"
L["btn_stats"] = isZhTW and "屬" or "属"

-- 频道按钮简称
L["btn_newbie"] = "新"
L["btn_say"] = isZhTW and "說" or "说"
L["btn_yell"] = isZhTW and "喊" or "喊"
L["btn_party"] = isZhTW and "隊" or "队"
L["btn_raid"] = isZhTW and "團" or "团"
L["btn_instance"] = isZhTW and "副" or "副"
L["btn_guild"] = isZhTW and "會" or "会"
L["btn_general"] = isZhTW and "綜" or "综"
L["btn_lfg"] = isZhTW and "尋" or "寻"
L["btn_trade"] = "交"

-- 按钮名称映射
L["button_names"] = isZhTW and {
    newbie = "新", say = "說", yell = "喊", party = "隊", raid = "團",
    instance = "副", guild = "會", general = "綜", lfg = "尋", trade = "交",
    world = "世", ready = "就", countdown = "倒", roll = "骰", copy = "復",
    emote = "表", reload = "重", stats = "屬",
} or {
    newbie = "新", say = "说", yell = "喊", party = "队", raid = "团",
    instance = "副", guild = "会", general = "综", lfg = "寻", trade = "交",
    world = "世", ready = "就", countdown = "倒", roll = "骰", copy = "复",
    emote = "表", reload = "重", stats = "属",
}

-- 频道名称（用于查找和匹配）
L["channel_world"] = isZhTW and "大腳世界頻道" or "大脚世界频道"
L["channel_general"] = isZhTW and "綜合" or "综合"
L["channel_trade"] = "交易"
L["channel_defense"] = isZhTW and "本地防務" or "本地防务"
L["channel_lfg"] = isZhTW and "尋求組隊" or "寻求组队"
L["channel_newbie"] = "新手聊天"
L["channel_looking_for_group"] = isZhTW and "預創建隊伍" or "预创建队伍"
L["channel_guild_recruit"] = isZhTW and "公會招募" or "公会招募"
L["channel_combat"] = isZhTW and "戰鬥記錄" or "战斗记录"

-- 频道缩写（用于显示）
L["channel_abbr_world"] = "世界"
L["channel_abbr_general"] = isZhTW and "綜合" or "综合"
L["channel_abbr_trade"] = "交易"
L["channel_abbr_defense"] = isZhTW and "防務" or "防务"
L["channel_abbr_lfg"] = isZhTW and "組隊" or "组队"
L["channel_abbr_newbie"] = "新手"
L["channel_abbr_prebuilt"] = isZhTW and "預建" or "预建"

-- 按钮提示文本
L["tooltip_newbie"] = isZhTW and "左鍵：新手頻道發言\n右鍵：加入/離開新手頻道" or "左键：新手频道发言\n右键：加入/离开新手频道"
L["tooltip_say"] = isZhTW and "說" or "说"
L["tooltip_yell"] = isZhTW and "喊" or "喊"
L["tooltip_party"] = isZhTW and "隊" or "队"
L["tooltip_raid"] = isZhTW and "團" or "团"
L["tooltip_instance"] = isZhTW and "副" or "副"
L["tooltip_guild"] = isZhTW and "會" or "会"
L["tooltip_general"] = isZhTW and "左鍵：綜合頻道發言" or "左键：综合频道发言"
L["tooltip_lfg"] = isZhTW and "左鍵：尋求組隊發言\n右鍵：加入/離開頻道" or "左键：寻求组队发言\n右键：加入/离开频道"
L["tooltip_trade"] = isZhTW and "左鍵：交易頻道發言\n右鍵：加入/離開頻道" or "左键：交易频道发言\n右键：加入/离开频道"
L["tooltip_world"] = isZhTW and "左鍵單擊：頻道發言\nShift+左鍵：屏蔽/恢復\n右鍵：加入/離開" or "左键单击：频道发言\nShift+左键：屏蔽/恢复\n右键：加入/离开"
L["tooltip_ready"] = isZhTW and "左鍵：就位確認\n右鍵雙擊：離開隊伍" or "左键：就位确认\n右键双击：离开队伍"
L["tooltip_countdown"] = isZhTW and "左鍵：5秒倒計時\n右鍵：10秒倒計時" or "左键：5秒倒计时\n右键：10秒倒计时"
L["tooltip_roll"] = isZhTW and "左鍵：Roll點\n右鍵：擲骰記錄" or "左键：Roll点\n右键：掷骰记录"
L["tooltip_copy"] = isZhTW and "左鍵：歷史聊天\n右鍵：備忘筆記" or "左键：历史聊天\n右键：备忘笔记"
L["tooltip_emote"] = isZhTW and "左鍵：表情圖示\n右鍵：表情動作" or "左键：表情图标\n右键：表情动作"
L["tooltip_stats"] = isZhTW and "左鍵：屬性通報到當前頻道\n右鍵：屬性通報到小隊\nShift+左鍵：通報到團隊\nShift+右鍵：通報到公會\nAlt+左鍵：密語當前目標\n中鍵：通報到大腳世界頻道" or "左键：属性通报到当前频道\n右键：属性通报到小队\nShift+左键：通报到团队\nShift+右键：通报到公会\nAlt+左键：密语当前目标\n中键：通报到大脚世界频道"
L["tooltip_reload"] = isZhTW and "左鍵雙擊：重載\n右鍵：重置副本" or "左键双击：重载\n右键：重置副本"

-- 世界频道按钮状态
L["world_blocked"] = "|cffff0000【已屏蔽】|r"
L["world_unblocked"] = "|cff00ff00【未屏蔽】|r"
L["world_block_action"] = isZhTW and "不再接收大腳世界頻道消息！" or "不再接收大脚世界频道消息！"
L["world_unblock_action"] = isZhTW and "恢復接收大腳世界頻道消息！" or "恢复接收大脚世界频道消息！"
L["world_blocked_status"] = "屏蔽"
L["world_unblocked_status"] = "未屏蔽"
L["world_status_note"] = isZhTW and "當前狀態：" or "当前状态："
L["world_blocked_hint"] = isZhTW and "注意：屏蔽時消息不會保留" or "注意：屏蔽时消息不会保留"
L["world_blocked_tooltip"] = isZhTW and "左鍵單擊：世界頻道發言\nShift+左鍵：切換屏蔽/接收\n右鍵單擊：加入/離開頻道\n\n當前狀態：" or "左键单击：世界频道发言\nShift+左键：切换屏蔽/接收\n右键单击：加入/离开频道\n\n当前状态："
L["world_general_managed"] = isZhTW and "綜合頻道由系統自動管理" or "综合频道由系统自动管理"
L["world_general_not_found"] = isZhTW and "未找到綜合頻道！請確保已加入該頻道。" or "未找到综合频道！请确保已加入该频道。"

-- 成功/失败消息
L["joined_channel"] = isZhTW and "已加入" or "已加入"
L["left_channel"] = isZhTW and "已離開" or "已离开"
L["not_joined"] = isZhTW and "未加入" or "未加入"
L["join_to_enable"] = isZhTW and "右鍵點擊加入！" or "右键点击加入！"
L["ready_check_failed"] = isZhTW and "就位確認失敗" or "就位确认失败"
L["countdown_failed"] = isZhTW and "倒計時失敗" or "倒计时失败"
L["countdown_cancelled"] = isZhTW and "倒計時已取消！" or "倒计时已取消！"
L["leave_party_failed"] = isZhTW and "離開隊伍失敗" or "离开队伍失败"
L["not_in_party"] = isZhTW and "不在隊伍中！" or "不在队伍中！"
L["reset_failed_during_instance"] = isZhTW and "副本中無法重置副本！" or "副本中无法重置副本！"
L["memo_not_loaded"] = isZhTW and "備忘筆記模組未載入！" or "备忘笔记模块未加载！"
L["not_in_raid"] = isZhTW and "不在團隊中！" or "不在团队中！"
L["not_in_instance_party"] = isZhTW and "不在副本隊伍中！" or "不在副本队伍中！"
L["not_in_guild"] = isZhTW and "不在公會中！" or "不在公会中！"
L["select_target"] = isZhTW and "請先選中一個玩家目標！" or "请先选中一个玩家目标！"
L["not_in_world_channel"] = isZhTW and "未加入大腳世界頻道！" or "未加入大脚世界频道！"

-- 配色方案
L["color_scheme_default"] = isZhTW and "預設金色" or "默认金色"
L["color_scheme_colorful"] = isZhTW and "彩色" or "彩色"
L["color_scheme_changed"] = isZhTW and "已切換到" or "已切换到"

-- 布局
L["layout_horizontal"] = isZhTW and "橫向" or "横向"
L["layout_vertical"] = isZhTW and "豎向" or "竖向"
L["layout_arrangement"] = isZhTW and "排列" or "排列"
L["layout_changed"] = isZhTW and "已切換到" or "已切换到"

-- 皮肤风格
L["skin_blizzard"] = isZhTW and "暴雪經典" or "暴雪经典"
L["skin_elvui"] = isZhTW and "ELVUI扁平" or "ELVUI扁平"
L["skin_transparent"] = isZhTW and "透明風格" or "透明风格"
L["skin_dropdown"] = isZhTW and "現代亮黑" or "现代亮黑"
L["skin_style_changed"] = isZhTW and "已切換到" or "已切换到"

-- 位置保存
L["position_saved"] = isZhTW and "位置已保存！" or "位置已保存！"

-- ==========================================
-- ChannelBarSettings 设置面板模块
-- ==========================================

-- 设置面板标题
L["settings_title"] = isZhTW and "|cff19CCF9[老農聊天條]:|r 設定" or "|cff19CCF9[老农聊天条]:|r 设置"
L["settings"] = isZhTW and "設定" or "设置"

-- 按钮可见性设置
L["btn_visibility_title"] = isZhTW and "1、勾選要顯示的按鈕（Ctrl+拖動移動聊天條）" or "1、勾选要显示的按钮（Ctrl+拖动移动聊天条）"
L["btn_select_all"] = isZhTW and "全選" or "全选"
L["btn_select_none"] = isZhTW and "全不選" or "全不选"

-- 时间戳功能
L["timestamp_title"] = isZhTW and "|cffffd7002、時間戳點擊複製功能|r" or "|cffffd7002、时间戳点击复制功能|r"
L["timestamp_enable"] = isZhTW and "啟用時間戳點擊複製功能" or "启用时间戳点击复制功能"
L["timestamp_enabled"] = isZhTW and "時間戳點擊複製功能已|cff00ff00啟用|r！" or "时间戳点击复制功能已|cff00ff00启用|r！"
L["timestamp_disabled"] = isZhTW and "時間戳點擊複製功能已|cffff0000關閉|r！" or "时间戳点击复制功能已|cffff0000关闭|r！"
L["timestamp_hint"] = isZhTW and "提示：此設定對所有角色生效，關閉後時間戳將恢復為暴雪原生樣式" or "提示：此设置对所有角色生效，关闭后时间戳将恢复为暴雪原生样式"

-- 皮肤风格设置
L["skin_title"] = isZhTW and "|cffffd7003、肌膚風格|r" or "|cffffd7003、皮肤风格|r"
L["skin_hint"] = isZhTW and "提示：透明風格完全隱藏背景和邊框，僅顯示圖示/文字，懸停時有輕微高亮效果。現代亮黑風格使用現代UI紋理，懸停顯示箭頭指示。" or "提示：透明风格完全隐藏背景和边框，仅显示图标/文字，悬停时有轻微高亮效果。现代亮黑风格使用现代UI纹理，悬停显示箭头指示。"

-- 排列方向设置
L["layout_title"] = isZhTW and "|cffffd7004、排列方向|r" or "|cffffd7004、排列方向|r"
L["layout_horizontal_default"] = isZhTW and "橫向排列（預設）" or "横向排列（默认）"
L["layout_vertical"] = isZhTW and "豎向排列" or "竖向排列"
L["layout_hint"] = isZhTW and "提示：豎向排列時聊天條將垂直顯示，適合放在螢幕兩側" or "提示：竖向排列时聊天条将垂直显示，适合放在屏幕两侧"

-- 输入框位置设置
L["input_title"] = isZhTW and "|cffffd7005、輸入框位置|r" or "|cffffd7005、输入框位置|r"
L["input_attach_chatframe"] = isZhTW and "依附於聊天框（預設）" or "依附于聊天框（默认）"
L["input_attach_channelbar"] = isZhTW and "依附於聊天條" or "依附于聊天条"
L["input_hint"] = isZhTW and "提示：選擇「依附於聊天條」後，輸入框將跟隨聊天條移動，寬度也會與聊天條保持一致" or "提示：选择「依附于聊天条」后，输入框将跟随聊天条移动，宽度也会与聊天条保持一致"
L["input_changed_chatframe"] = isZhTW and "輸入框已設定為依附於聊天框！" or "输入框已设置为依附于聊天框！"
L["input_changed_channelbar"] = isZhTW and "輸入框已設定為依附於聊天條！" or "输入框已设置为依附于聊天条！"

-- 缩放设置
L["scale_title"] = isZhTW and "|cffffd7006、聊天條縮放|r" or "|cffffd7006、聊天条缩放|r"
L["scale_hint"] = isZhTW and "提示：拖動滑塊調整縮放比例（70%-200%）。建議縮放後選擇「依附於聊天條」以同步寬度。" or "提示：拖动滑块调整缩放比例（70%-200%）。建议缩放后选择「依附于聊天条」以同步宽度。"

-- 配色方案设置
L["color_title"] = isZhTW and "|cffffd7007、配色方案|r" or "|cffffd7007、配色方案|r"
L["color_default_recommend"] = isZhTW and "預設金色（推薦）" or "默认金色（推荐）"
L["color_colorful"] = isZhTW and "彩色方案（各頻道不同色）" or "彩色方案（各频道不同色）"
L["color_hint"] = isZhTW and "提示：預設金色方案顯示效果最佳，彩色方案各頻道按鈕顯示不同顏色" or "提示：默认金色方案显示效果最佳，彩色方案各频道按钮显示不同颜色"

-- 密语设置
L["whisper_title"] = isZhTW and "|cffffd7008、密語設定|r" or "|cffffd7008、密语设置|r"
L["whisper_sticky"] = isZhTW and "啟用密語黏性（保持上次密語目標）" or "启用密语粘性（保持上次密语目标）"
L["whisper_hint"] = isZhTW and "提示：取消黏性後，每次發送密語後輸入框會自動切換回普通頻道" or "提示：取消粘性后，每次发送密语后输入框会自动切换回普通频道"
L["whisper_sticky_enabled"] = isZhTW and "密語黏性已啟用！" or "密语粘性已启用！"
L["whisper_sticky_disabled"] = isZhTW and "密語黏性已取消！" or "密语粘性已取消！"

-- 显示模式设置
L["display_title"] = isZhTW and "|cffffd7009、顯示模式設定|r" or "|cffffd7009、显示模式设置|r"
L["icon_mode"] = isZhTW and "使用圖示模式（推薦）" or "使用图标模式（推荐）"
L["icon_mode_hint"] = isZhTW and "提示：關閉後，聊天條將顯示純文字按鈕（骰、世、重等將顯示為文字）" or "提示：关闭后，聊天条将显示纯文字按钮（骰、世、重等将显示为文字）"
L["icon_mode_changed_icon"] = isZhTW and "已切換為圖示版！" or "已切换为图标版！"
L["icon_mode_changed_text"] = isZhTW and "已切換為純文字版！" or "已切换为纯文字版！"

-- 小地图按钮设置
L["minimap_title"] = isZhTW and "|cffffd70010、小地圖按鈕|r" or "|cffffd70010、小地图按钮|r"
L["minimap_show"] = isZhTW and "顯示小地圖設定按鈕" or "显示小地图设置按钮"
L["minimap_hint"] = isZhTW and "提示：隱藏後可通過命令 /lnset 或 /lnsettings 打開設定" or "提示：隐藏后可通过命令 /lnset 或 /lnsettings 打开设置"
L["minimap_shown"] = isZhTW and "小地圖按鈕已|cff00ff00顯示|r" or "小地图按钮已|cff00ff00显示|r"
L["minimap_hidden"] = isZhTW and "小地圖按鈕已|cffff0000隱藏|r" or "小地图按钮已|cffff0000隐藏|r"

-- ALT键设置
L["altarrow_title"] = isZhTW and "|cffffd70011、免ALT鍵查看輸入記錄|r" or "|cffffd70011、免ALT键查看输入记录|r"
L["altarrow_enable"] = isZhTW and "開啟免ALT鍵查看輸入記錄" or "开启免ALT键查看输入记录"
L["altarrow_hint"] = isZhTW and "提示：開啟後，聊天輸入框無需按住Alt鍵即可用方向鍵移動光標和瀏覽歷史記錄" or "提示：开启后，聊天输入框无需按住Alt键即可用方向键移动光标和浏览历史记录"
L["altarrow_enabled"] = isZhTW and "免ALT鍵查看輸入記錄已啟用！" or "免ALT键查看输入记录已启用！"
L["altarrow_disabled"] = isZhTW and "免ALT鍵查看輸入記錄已關閉！" or "免ALT键查看输入记录已关闭！"

-- 重置按钮
L["reset_position"] = isZhTW and "重置聊天條位置" or "重置聊天条位置"

-- 小地图按钮
L["minimap_tooltip_title"] = "|TInterface/AddOns/LNuiChat/Media/LNuiChat:16|t |cff19CCF9老農聊天條|r"
L["minimap_tooltip_open_settings"] = isZhTW and "左鍵：打開設定介面" or "左键：打开设置界面"
L["minimap_tooltip_move"] = isZhTW and "拖曳：移動按鈕位置" or "拖拽：移动按钮位置"

-- ==========================================
-- 备忘笔记模块
-- ==========================================

L["memo_title"] = isZhTW and "備忘筆記" or "备忘笔记"
L["memo_tab_logarch"] = isZhTW and "遷" or "迁"
L["memo_tab_one"] = "一"
L["memo_tab_two"] = "二"
L["memo_tab_three"] = "三"
L["memo_tab_four"] = "四"
L["memo_tab_five"] = "五"
L["memo_tab_six"] = "六"
L["memo_tab_seven"] = "七"
L["memo_limit_warning"] = isZhTW and "本頁即將達到單頁最大存儲限制，請及時清理。" or "本页即将达到单页最大存储限制，请及时清理。"
L["memo_color_warning"] = isZhTW and "顏色代碼未閉合，缺少 " or "颜色代码未闭合，缺少 "
L["memo_color_warning_suffix"] = isZhTW and " 個 ||r" or " 个 ||r"

-- ==========================================
-- 聊天日志视图
-- ==========================================

L["view_older"] = isZhTW and "較早" or "较早"
L["view_recent"] = isZhTW and "最近" or "最近"
L["view_button"] = isZhTW and "視圖" or "视图"
L["delete_button"] = isZhTW and "刪除" or "删除"
L["search_button"] = isZhTW and "搜尋" or "搜索"
L["older_button"] = isZhTW and "較早" or "较早"
L["recent_button"] = isZhTW and "最近" or "最近"
L["close_button"] = isZhTW and "關閉" or "关闭"
L["copy_button"] = isZhTW and "複製" or "复制"
L["memo_button"] = isZhTW and "筆記" or "笔记"
L["open_all_button"] = isZhTW and "打開全部" or "打开全部"
L["close_all_button"] = isZhTW and "關閉全部" or "关闭全部"

-- 视图按钮文本
L["delete_view_all"] = isZhTW and "刪除所有搜尋結果" or "删除所有搜索结果"
L["delete_view_count"] = isZhTW and "刪除視圖內 %d 條" or "删除视图内 %d 条"

-- 确认对话框
L["confirm_delete"] = isZhTW and "確定要刪除嗎？" or "确定要删除吗？"
L["confirm_delete_search"] = isZhTW and "確定要刪除所有搜尋結果嗎？" or "确定要删除所有搜索结果吗？"
L["button_delete"] = isZhTW and "刪除" or "删除"
L["button_cancel"] = isZhTW and "取消" or "取消"

-- 搜索
L["search_placeholder"] = isZhTW and "搜尋..." or "搜索..."
L["search_hint"] = isZhTW and "回車搜尋 ESC清空" or "回车搜索 ESC清空"
L["search_result_count"] = isZhTW and "共 %d 條匹配結果" or "共 %d 条匹配结果"
L["search_no_result"] = isZhTW and "未找到匹配結果" or "未找到匹配结果"
L["search_in_label"] = "在"

-- 标签页
L["tab_logarch"] = isZhTW and "日誌歸檔" or "日志归档"
L["tab_placeholder"] = isZhTW and "（無標籤）" or "（无标签）"
L["tab_prefix"] = isZhTW and "頻道" or "频道"

-- 提示信息
L["copy_success"] = isZhTW and "已複製 %d 條聊天記錄到剪貼簿！" or "已复制 %d 条聊天记录到剪贴板！"
L["copy_failed"] = isZhTW and "複製失敗，請重試！" or "复制失败，请重试！"
L["copy_nothing"] = isZhTW and "沒有可複製的內容！" or "没有可复制的内容！"
L["log_too_long"] = isZhTW and "... 日誌過長，僅顯示最近 " or "... 日志过长，仅显示最近 "
L["log_too_long_suffix"] = isZhTW and " 條，其餘已存檔 ..." or " 条，其余已存档 ..."
L["log_entry_count"] = isZhTW and "共 %d 條" or "共 %d 条"

-- 关键词过滤
L["keyword_filter_title"] = isZhTW and "|cffff9900關鍵詞過濾|r" or "|cffff9900关键词过滤|r"
L["keyword_filter_hint"] = isZhTW and "只阻止命中的新消息寫入存檔" or "只阻止命中的新消息写入存档"
L["keyword_filter_confirm"] = isZhTW and "|cffF76666回車確認|r   多個關鍵詞用分號隔開" or "|cffF76666回车确认|r   多个关键词用分号隔开"
L["keyword_filter_channel_hint"] = isZhTW and "可用如 [5. 大腳] 的方式過濾頻道" or "可用如 [5. 大脚] 的方式过滤频道"

-- ==========================================
-- StatsReport 属性通报模块
-- ==========================================

-- 主属性名称
L["stat_strength"] = isZhTW and "力量" or "力量"
L["stat_agility"] = isZhTW and "敏捷" or "敏捷"
L["stat_intellect"] = isZhTW and "智力" or "智力"
L["stat_stamina"] = isZhTW and "耐力" or "耐力"

-- 通报格式
L["report_itemlevel"] = isZhTW and "裝等" or "装等"
L["report_mythic_score"] = isZhTW and "史詩鑰石評分" or "史诗钥石评分"
L["report_health"] = isZhTW and "血量" or "血量"
L["report_crit"] = isZhTW and "暴擊" or "暴击"
L["report_haste"] = "急速"
L["report_mastery"] = "精通"
L["report_versatility"] = isZhTW and "全能" or "全能"
L["report_percent"] = "%"

-- 提示信息
L["restricted_combat"] = isZhTW and "戰鬥中" or "战斗中"
L["restricted_mythic"] = isZhTW and "大秘境中" or "大秘境中"
L["restricted_action"] = isZhTW and "無法獲取屬性數據，請脫戰或離開大秘境後再試！" or "无法获取属性数据，请脱战或离开大秘境后再试！"
L["get_stats_failed"] = isZhTW and "屬性獲取失敗，請重試！" or "属性获取失败，请重试！"
L["invalid_chars"] = isZhTW and "通報內容包含非法字元，已取消發送！" or "通报内容包含非法字符，已取消发送！"
L["insert_invalid_chars"] = isZhTW and "通報內容包含非法字元，已取消插入！" or "通报内容包含非法字符，已取消插入！"

-- ==========================================
-- LNuiChat 主模块 - 表情系统
-- ==========================================

-- 表情名称（聊天表情）
if isZhTW then
    L["emote_angel"] = "{天使}"
    L["emote_angry"] = "{生氣}"
    L["emote_biglaugh"] = "{大笑}"
    L["emote_clap"] = "{鼓掌}"
    L["emote_cool"] = "{酷}"
    L["emote_cry"] = "{哭}"
    L["emote_cutie"] = "{可愛}"
    L["emote_despise"] = "{鄙視}"
    L["emote_dreamsmile"] = "{美夢}"
    L["emote_embarrass"] = "{尷尬}"
    L["emote_evil"] = "{邪惡}"
    L["emote_excited"] = "{興奮}"
    L["emote_faint"] = "{暈}"
    L["emote_fight"] = "{打架}"
    L["emote_flu"] = "{流感}"
    L["emote_freeze"] = "{呆}"
    L["emote_frown"] = "{皺眉}"
    L["emote_greet"] = "{致敬}"
    L["emote_grimace"] = "{鬼臉}"
    L["emote_growl"] = "{齜牙}"
    L["emote_happy"] = "{開心}"
    L["emote_heart"] = "{心}"
    L["emote_horror"] = "{恐懼}"
    L["emote_ill"] = "{生病}"
    L["emote_innocent"] = "{無辜}"
    L["emote_kongfu"] = "{功夫}"
    L["emote_love"] = "{花癡}"
    L["emote_mail"] = "{郵件}"
    L["emote_makeup"] = "{化妝}"
    L["emote_meditate"] = "{沉思}"
    L["emote_miserable"] = "{可憐}"
    L["emote_okay"] = "{好}"
    L["emote_pretty"] = "{漂亮}"
    L["emote_puke"] = "{吐}"
    L["emote_shake"] = "{握手}"
    L["emote_shout"] = "{喊}"
    L["emote_shuuuu"] = "{閉嘴}"
    L["emote_shy"] = "{害羞}"
    L["emote_sleep"] = "{睡覺}"
    L["emote_smile"] = "{微笑}"
    L["emote_surprise"] = "{吃驚}"
    L["emote_surrender"] = "{失敗}"
    L["emote_sweat"] = "{流汗}"
    L["emote_tear"] = "{流淚}"
    L["emote_tears"] = "{悲劇}"
    L["emote_think"] = "{想}"
    L["emote_titter"] = "{偷笑}"
    L["emote_ugly"] = "{猥褻}"
    L["emote_victory"] = "{勝利}"
    L["emote_volunteer"] = "{雷鋒}"
    L["emote_wronged"] = "{委屈}"
    L["emote_laonong"] = "{老農}"
else
    L["emote_angel"] = "{天使}"
    L["emote_angry"] = "{生气}"
    L["emote_biglaugh"] = "{大笑}"
    L["emote_clap"] = "{鼓掌}"
    L["emote_cool"] = "{酷}"
    L["emote_cry"] = "{哭}"
    L["emote_cutie"] = "{可爱}"
    L["emote_despise"] = "{鄙视}"
    L["emote_dreamsmile"] = "{美梦}"
    L["emote_embarrass"] = "{尴尬}"
    L["emote_evil"] = "{邪恶}"
    L["emote_excited"] = "{兴奋}"
    L["emote_faint"] = "{晕}"
    L["emote_fight"] = "{打架}"
    L["emote_flu"] = "{流感}"
    L["emote_freeze"] = "{呆}"
    L["emote_frown"] = "{皱眉}"
    L["emote_greet"] = "{致敬}"
    L["emote_grimace"] = "{鬼脸}"
    L["emote_growl"] = "{龇牙}"
    L["emote_happy"] = "{开心}"
    L["emote_heart"] = "{心}"
    L["emote_horror"] = "{恐惧}"
    L["emote_ill"] = "{生病}"
    L["emote_innocent"] = "{无辜}"
    L["emote_kongfu"] = "{功夫}"
    L["emote_love"] = "{花痴}"
    L["emote_mail"] = "{邮件}"
    L["emote_makeup"] = "{化妆}"
    L["emote_meditate"] = "{沉思}"
    L["emote_miserable"] = "{可怜}"
    L["emote_okay"] = "{好}"
    L["emote_pretty"] = "{漂亮}"
    L["emote_puke"] = "{吐}"
    L["emote_shake"] = "{握手}"
    L["emote_shout"] = "{喊}"
    L["emote_shuuuu"] = "{闭嘴}"
    L["emote_shy"] = "{害羞}"
    L["emote_sleep"] = "{睡觉}"
    L["emote_smile"] = "{微笑}"
    L["emote_surprise"] = "{吃惊}"
    L["emote_surrender"] = "{失败}"
    L["emote_sweat"] = "{流汗}"
    L["emote_tear"] = "{流泪}"
    L["emote_tears"] = "{悲剧}"
    L["emote_think"] = "{想}"
    L["emote_titter"] = "{偷笑}"
    L["emote_ugly"] = "{猥琐}"
    L["emote_victory"] = "{胜利}"
    L["emote_volunteer"] = "{雷锋}"
    L["emote_wronged"] = "{委屈}"
    L["emote_laonong"] = "{老农}"
end

-- 表情动作面板
L["emote_action_title"] = isZhTW and "表情動作" or "表情动作"
L["emote_search_placeholder"] = isZhTW and "搜尋表情（中/英/拼音）" or "搜索表情（中/英/拼音）"
L["emote_search_hint"] = isZhTW and "左鍵執行 · 右鍵插入" or "左键执行 · 右键插入"
L["emote_clear"] = isZhTW and "清空" or "清空"
L["emote_search"] = isZhTW and "搜尋" or "搜索"

-- ==========================================
-- ChatTimestampCopy 时间戳复制
-- ==========================================

L["item_placeholder"] = isZhTW and "[物品]" or "[物品]"

-- ==========================================
-- 通用错误和状态消息
-- ==========================================

L["error"] = isZhTW and "錯誤" or "错误"
L["success"] = isZhTW and "成功" or "成功"
L["warning"] = isZhTW and "警告" or "警告"
L["info"] = isZhTW and "提示" or "提示"
L["ok"] = isZhTW and "確定" or "确定"
L["cancel"] = isZhTW and "取消" or "取消"
L["yes"] = isZhTW and "是" or "是"
L["no"] = isZhTW and "否" or "否"
L["close"] = isZhTW and "關閉" or "关闭"
L["confirm"] = isZhTW and "確認" or "确认"
L["loading"] = isZhTW and "載入中..." or "加载中..."
