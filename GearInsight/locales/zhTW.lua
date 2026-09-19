-- GearInsight - Traditional Chinese (zhTW) locale overrides.
-- Only consumed on a zhTW client (see T() in GearInsight.lua). The zhCN and enUS
-- builds never read this file, so adding/changing keys here cannot affect them.
-- Terminology follows Taiwan WoW conventions (副本/裝等/急速/全能/精通/暴擊…).

GearInsight = GearInsight or {}
GearInsight.LOC = GearInsight.LOC or {}

GearInsight.LOC["zhTW"] = {
    -- Panel: titles / sections / buttons
    PANEL_TITLE        = "GearInsight",
    TALENT_BTN         = "WCL天賦庫",
    TALENT_TIP         = "WCL 頂尖玩家天賦(團本/衝分/割草 各前5名)，選一套複製匯入串",
    TALENT_NODATA      = "當前專精暫無天賦資料(切到對應專精了嗎？)",
    TALENT_PICK_TITLE  = "WCL 頂尖天賦庫",
    TALENT_PICK_HINT   = "點標題切 boss/副本 · 點一行複製該套匯入串",
    TALENT_SWITCH_TIP  = "左鍵下一個 / 右鍵上一個 boss·副本",
    TALENT_COPY_HINT   = "Ctrl+C 複製天賦碼 → 天賦面板「匯入」貼上；下方為載入檔命名",
    COPY_NAME_LABEL    = "命名",
    FOOD_GRP_FEAST     = "盛宴",
    FOOD_GRP_MAIN      = "大師級單人",
    FOOD_GRP_SINGLE    = "高級單人",
    TALENT_IMPORT_BTN  = "一鍵匯入天賦",
    TALENT_IMPORT_OK2  = "已匯入「%s」→ 天賦面板點「套用變更」生效",
    TALENT_APPLY_FALLBACK = "，已轉手動匯入",
    TALENT_IMPORT_OK   = "天賦面板已開啟：左下「載入檔」→「匯入」→ Ctrl+V 貼上（字串沒複製就回本視窗 Ctrl+C）",
    TALENT_IMPORT_FAIL = "匯入失敗：",
    TALENT_COPY_TITLE  = "WCL %s · %s #%d",
    TALENT_FAIL        = "失敗：",
    -- 大米攻略（M+ 副本攻略）
    DG_BTN             = "M+攻略",
    DG_TIP             = "M+攻略：WCL 真實資料聚合 — 每個副本誰在殺人、頂尖玩家斷什麼不斷什麼、死亡前承傷構成。進副本自動彈出對應攻略。",
    DG_TITLE           = "M+攻略",
    DG_NODATA          = "M+攻略資料未載入",
    DG_AUTOPOP         = "進副本自動彈出",
    DG_SOURCE          = "資料: WCL 高層+12層 真實場次聚合",
    DG_SEC_KICKS       = "① 斷法優先級（頂尖玩家真實斷法率）",
    DG_SEC_KILLERS     = "② 致死技能榜（什麼在殺人）",
    DG_SEC_HEAVY       = "③ 重傷來源（死亡前承受的傷害構成）",
    DG_SAMPLE          = "樣本: %d場 / %d次死亡",
    DG_DEATHS          = "死",
    DG_BOSS            = "[BOSS]",
    DG_KICK_MUST       = "必斷",
    DG_KICK_HIGH       = "高優",
    DG_KICK_MED        = "有餘力斷",
    DG_KICK_LOW        = "可忽略",
    DG_ZONE_HINT       = "已為你打開本圖攻略（可在視窗左下角關閉自動彈出）",
    -- 臨場提示（姓名板關注點卡片+讀條高亮）
    LG_TITLE           = "臨場關注點",
    LG_TOGGLE          = "臨場提示(必斷/致死高亮)",
    LG_LUSTBAR_TOGGLE  = "嗜血監控(嗜血點提示+視窗條)",
    -- KeyTimeline（鑰匙時間軸，2026-09-04）
    KT_TOGGLE          = "鑰匙時間軸(嗜血點預告+boss進度vs頂尖場次)",
    KT_SEG_OPEN        = "開門波",
    KT_SEG_PRE         = "%s前一波",
    KT_SEG_POST        = "尾王後",
    KT_NTH             = "第%d次",
    KT_NEXT            = "下個嗜血點",
    KT_HOLD            = "留爆發·嗜血點",
    KT_ETA             = "≈%s後",
    KT_NOW             = "≈現在",
    KT_READY_SHORT     = "嗜血就緒",
    KT_LATE_SHORT      = "嗜血 %s 後轉好",
    KT_READY           = "你的嗜血已就緒",
    KT_READY_IN        = "你的嗜血 %s 後轉好",
    KT_LUST_ON         = "嗜血中·壓滿爆發",
    KT_NO_MORE         = "頂尖場次共識嗜血點已全部走過",
    KT_PACE            = "%s：你 %s · 頂尖 %s（%s%s|r）",
    KT_PACE_FIRST      = "頂尖場次 %s 到 %s",
    KT_EVIDENCE        = "頂尖場次 %d%% 在此開",
    KT_ALERT_CASTER    = "嗜血點：",
    KT_ALERT_LATE      = "嗜血點到了，嗜血未轉好：",
    KT_ALERT_HOLD      = "留爆發 · 嗜血點：",
    KT_ALT             = "備選：%s %d%%",
    KT_TIP_TITLE       = "鑰匙時間軸 · 頂尖場次怎麼打",
    KT_TIP_BOSSES      = "boss 到達（高層場次中位）",
    KT_TIP_LUST        = "嗜血點（幾成頂尖場次在此開）",
    KT_TIP_YOU         = "你 %s",
    KT_TIP_DRAG        = "拖動可移動",
    DG_LUST_AT         = "約%.0f分鐘",
    DG_BOSS_PACE       = "頂尖場次到達：",
    LG_KILLER          = "致死",
    LG_HEAVY           = "重傷",
    LG_MUST            = "必斷：",
    LG_HIGH            = "高優斷法：",
    LG_DODGE           = "閃避/減傷：",
    LG_KILLER_SUB      = "頂尖場次 %d 次死亡元兇",
    LG_KICK_READY      = "你的斷法已就緒",
    LG_KICK_CD         = "你的斷法還有 %.1f 秒",
    -- 嗜血協同
    DG_SEC_LUST        = "④ 嗜血點位（頂尖場次在哪開）",
    DG_LUST_FMT        = "%d%%場次在此開 · 約%.0f分鐘",
    DG_SEC_LOOT        = "⑤ 本圖資源池（你的 BiS 掉落）",
    DG_POOL_SUMMARY    = "畢業件 缺%d/共%d · 可升級散件 %d 件",
    DG_POOL_GRAD       = "▸ 畢業件（優先 R）",
    DG_POOL_FILLER     = "▸ 可升級散件（順手 R）",
    DG_POOL_DONE       = "▸ 本圖已到手畢業件 %d 件 ✓",
    DG_POOL_ALLDONE    = "本圖對你已無可刷裝備，畢業件已全部到手 ✓",
    DG_TAG_NEED        = "[缺·優先R]",
    DG_TAG_UP          = "[↑%d]",
    DG_SLOT            = "槽",
    DG_POOL_NONE       = "本圖無你的 BiS 相關掉落（你的畢業件主要來自團本/套裝）",
    DG_POOL_SUMMARY2   = "本圖相關 %d 件 · 畢業缺 %d · 可升級 %d · 已有 %d",
    DG_POOL_SIDE       = "▸ 其它 BiS 候選 %d 件（當前非升級）",
    DG_POOL_DONE2      = "▸ 本圖已到手 %d 件 ✓",
    IB_LOADING         = "GearInsight：讀取裝備中…",
    IB_LINE            = "GearInsight：BiS 畢業 %d/%d · 缺 %d 件",
    IB_ALLDONE         = "GearInsight：BiS 全部畢業 (%d/%d) ✓",
    IB_TOGGLE_ON       = "組隊懸停 BiS 畢業度：已開啟",
    IB_TOGGLE_OFF      = "組隊懸停 BiS 畢業度：已關閉",
    GB_TITLE           = "團隊 BiS 體檢",
    GB_REFRESH         = "刷新",
    GB_RANGE           = "範圍外",
    GB_LOADING         = "讀取中…",
    GB_NODATA          = "無 BiS 資料",
    GB_NOENCH          = "缺附魔×%d",
    GB_EMPTYSOCK       = "空孔×%d",
    GB_READY           = "✓ 準備就緒",
    GB_SCANNING        = "檢視中…",
    GB_COUNT           = "%d 名隊友",
    GB_UNAVAIL         = "團隊 BiS 體檢面板未載入",
    GLD_TITLE          = "公會花名冊",
    GLD_REFRESH        = "重新整理",
    GLD_COUNT          = "%d 在線 / %d 名成員",
    GLD_OFFLINE        = "離線",
    GLD_AFK            = "暫離",
    GLD_DND            = "勿擾",
    GLD_ONLINE         = "在線",
    GLD_NOGUILD        = "你還沒有加入公會",
    GLD_UNAVAIL        = "公會花名冊面板未載入",
    LG_LUST_TITLE      = "嗜血視窗·壓滿爆發",
    LG_LUST_POINT      = "嗜血點",
    LG_LUST_POINT_FMT  = "頂尖場次 %d%% 在這波開",
    -- 循環參考
    ROT_BTN            = "AI技術指導",
    ROT_TIP            = "WCL 頂尖玩家的真實起手序列、技能使用頻率、關鍵BUFF覆蓋率（團本/傳奇鑰石兩套參照）",
    ROT_NODATA         = "當前專精暫無循環資料(切到對應專精了嗎？)",
    ROT_TITLE          = "AI 技術指導",
    ROT_HINT           = "AI 解讀 WCL 頂尖玩家實戰資料 · 滑鼠懸停看技能說明",
    ROT_MODE_RAID      = "團本",
    ROT_MODE_MPLUS     = "傳奇鑰石(衝分)",
    ROT_OPENER         = "起手序列",
    ROT_OPENER_SWITCH  = "點擊換人",
    ROT_OPENER_EMPTY   = "（起手技能均未習得——先抄該玩家天賦）",
    ROT_CORE           = "技能使用頻率",
    ROT_CORE_SUB       = "次/分鐘·頂尖玩家中位數",
    ROT_PERMIN         = "次/分鐘",
    ROT_TIER_CORE      = "核心",
    ROT_TIER_OFTEN     = "常用",
    ROT_TIER_CD        = "CD/情境",
    ROT_NOT_KNOWN      = "未習得",
    ROT_TT_NOT_KNOWN   = "頂尖玩家在用、但你未習得——多半是沒選這個天賦（可用「WCL天賦庫」一鍵抄）；也可能是飾品技能。",
    ROT_WATCH          = "BUFF 盯防",
    ROT_WATCH_SUB      = "主動維持·頂尖玩家的覆蓋率，你低於它=操作短板",
    ROT_MODE_HINT      = "← 點擊切換場景（兩套循環差異很大）",
    ROT_OPENER_SEE_RAID = "起手序列在「團本」視圖（鑰石整本無固定開場）· 點此切換",
    ROT_TT_ACTIVE      = "主動維持：頂尖玩家覆蓋率 %d%%。你的覆蓋率低於這個 = 操作短板，優先練。",
    ROT_TT_SOURCE      = "來源：%s · 自動生效，無需操作",
    ROT_SRC_TALENT     = "天賦「%s」",
    ROT_TT_PASSIVE_TALENT = "來源：天賦/裝備被動 · 你已擁有，自動生效，無需操作",
    ROT_TT_PASSIVE_GEAR = "來源：裝備/飾品特效 · 自動觸發，無需操作（頂尖玩家穿了對應裝備才有）",
    ROT_FOOT           = "樣本：%d 名 WCL 頂尖玩家 · 灰色=你未習得（飾品/異族種族技能/未選天賦）",
    ROT_PASSIVE_COUNT  = "%d 項",
    ROT_FOLD_OPEN      = "點擊展開",
    ROT_FOLD_CLOSE     = "點擊收起",
    ROT_HAVE           = "已有",
    ROT_HAVE_NOT       = "未檢測到",
    ROT_AI_FUNNEL      = "想讓 AI 對照你的實戰資料？「匯出裝備」→ gearinsight.app → AI 教練",
    ROT_COACH          = "AI 教練解讀",
    ROT_COACH_BY       = "AI 大模型離線生成 · 非即時",
    ROT_MY             = "你:",
    ROT_MY_ON          = "實戰對照已開啟：累計戰鬥 %.1f 分鐘 / %d 場",
    ROT_MY_RESET       = "點擊清零（換團本/鑰石場景時建議清）",
    ROT_MY_OFF         = "實戰對照：進戰鬥累計滿 1 分鐘後，下方自動出現「你 vs 頂尖」",
    ROT_COACH_TIP      = "由 AI 大模型在資料更新時離線生成（遊戲內不連網）。AI 只把下方的確定性統計翻譯成人話——技能與數字全部來自 WCL 頂尖玩家日誌，不新增任何資料之外的內容。",
    ROT_WATCH_PASSIVE  = "被動觸發（自動生效，無需操作）",
    CONTENT_RAID = "團本", CONTENT_PUSH = "衝分", CONTENT_FARM = "割草",
    MLEVEL_HIGH = "不限層·當週最高層榜", MLEVEL_FARM = "+12 層",
    REGION_US = "美服", REGION_EU = "歐服", REGION_KR = "韓服", REGION_TW = "台服", REGION_CN = "國服", REGION_RU = "俄服",
    SECTION_STATS      = "屬性達成度",
    MODE_RAID          = "團本",
    MODE_MPLUS         = "M+",
    MODE_TIP           = "切換屬性目標來源：團隊 / 王者試煉",
    MODE_MHIGH         = "高層",
    MODE_MFARM         = "割草",
    MODE_TIP_RAID      = "團隊屬性目標",
    MODE_TIP_HIGH      = "王者試煉高層（衝分）屬性目標",
    MODE_TIP_FARM      = "王者試煉割草（+12）屬性目標",
    -- 左上開關：使用率參照系 + 團本裝備過濾
    USAGE_BTN          = "使用率參照: ",
    USAGE_RAID         = "團本",
    USAGE_MPLUS        = "大秘境",
    USAGE_TIP          = "使用率% = 頂尖玩家實戰配裝的集成統計\n\n團本 — 統計團本頂尖玩家的裝備\n大秘境 — 統計大秘境頂尖玩家的裝備\n\n點擊切換（畢業件首選順序、使用率%、刷取規劃隨之聯動）",
    EXRAID_BTN_ON      = "團本裝備: 排除",
    EXRAID_BTN_OFF     = "團本裝備: 包含",
    EXRAID_TIP         = "是否把團本掉落納入推薦。\n排除 = 只推薦大秘境/製造等非團本來源（不打團本的獨狼玩家用，套裝胚子仍保留）\n包含 = 推薦含團本掉落",
    SECTION_NEXT       = "下一步",
    BTN_FARMING        = "刷裝優先序",
    FG_TITLE           = "刷裝優先序",
    BTN_REFRESH        = "重新整理",
    CLOSE_SHORT        = "關閉",

    -- Secondary stat names (Taiwan official terminology: 致命一擊/急速/精通/臨機應變,
    -- shown as 2-char 致命/加速/精通/臨機)
    STAT_CRIT          = "致命",
    STAT_HASTE         = "加速",
    STAT_MASTERY       = "精通",
    STAT_VERS          = "臨機",

    -- Footer / author
    AUTHOR_BY          = "作者",
    DATA_FOOTER        = "Midnight S2 \194\183 WCL \194\183 更新於 ",

    -- Slash / status prints
    PRINT_OPEN_FIRST   = "請先開啟面板或重新整理資料。",
    DUMP_UNAVAILABLE   = "BisData.DumpEncounterJournal 無法使用",
    SCALE_SET          = "面板縮放已設定為 ",
    SCALE_USAGE        = "用法：/gi scale <0.5-2.0>  目前：",
    CMD_ERROR          = "指令執行出錯：",
    PANEL_INIT_FAIL    = "面板初始化失敗：",
    REFRESH_FAIL       = "重新整理失敗：資料模組尚未就緒",
    REFRESHED          = "裝備資料已重新整理",
    REFRESHED_NOPANEL  = "裝備資料已重新整理；面板未開啟，輸入 /gi 檢視",
    HELP_LINE          = "/gi - 面板 | /gi farming - 刷裝指南 | /gi cbis - 角色面板BiS圖示開關 | /gi status - 狀態 | /gi refresh - 重新整理 | /gi dumpids - 匯出 ID | /gi help",
    LOADED             = "已載入。輸入 /gi 開啟面板",

    -- Tooltips
    TT_BIS_ILVL        = "畢業裝等：",
    TT_BIS_TOPMX       = "頂尖玩家最高見到 %d",
    TT_IMPROVE         = "提升：+%.1f%%",
    TT_DROP            = "掉落：",
    TT_COMPANION       = "GearInsight Companion 即時推薦",
    TT_BIS_REC         = "GearInsight 畢業推薦",
    TT_SHIFT_CHAT      = "Shift+點擊 發送到聊天",
    TT_TIER_CLICK      = "點擊檢視可轉換的同部位物品",
    TT_JOURNAL_CLICK   = "點擊開啟冒險指南",

    -- Overview
    OV_SPEC            = "專精：",
    OV_ILVL            = "裝備等級：",
    OV_GRAD            = "目標裝等：",
    OV_GAP             = "差距：",
    OV_OVER            = "已超畢業線：",
    OV_NODATA          = "找不到此專精的畢業資料",
    STAT_PRIORITY      = "屬性優先序：",
    STAT_WORST         = "  |  最需要：%s -%.1f%%",
    STAT_OK            = "  |  屬性已達標",

    -- Stat bar tags
    LBL_PANEL          = "面板",
    LBL_DIST           = "分佈",
    TAG_NONCORE        = "次要",
    TAG_LOW            = "偏低",
    TAG_TOL            = "接近",
    TAG_OK             = "達標",
    TAG_OVER           = "超出",
    TAG_GAP            = " 還差 %.1f%%",
    TAG_GAP_RATING     = "(還差 %d)",
    LBL_TGT            = "目標",
    TAG_GAP_R          = "  缺 %d",
    TAG_OVER_R         = "  多 %d",
    TAG_GAP_R2         = " 缺%d",
    TAG_OVER_R2        = " 多%d",
    EXPORT_COPY_HINT   = "匯出裝備時彈出複製框，已自動全選，按 Ctrl+C 複製",
    MS_SOURCE_PREFIX   = "戰利品專精：",

    -- Upgrade rows
    SLOT_EMPTY         = "（空槽）",
    HDR_UPGRADE_SLOT   = "升級 - ",
    NEED_HIGHER_ILVL   = " 需要更高裝等的版本",
    TIER_FILLER        = "套裝補位",
    TIER_FILLER_DROPS  = "掉",
    TIER_TOP_STATS     = "主推屬性：%s",
    TIER_CORE_STAT     = "最核心：%s",
    TIER_RAID_ONLY     = "本部位坯子只出自團本",
    TIER_NONRAID_FIRST = "已按「排除團本」把非團本坯子排在前",
    MLEVEL_RAID        = "史詩難度",
    MLEVEL_RAID2       = "M 史詩 · H 英雄",
    MLEVEL_FMT         = "+%d 層（本週 +%d~+%d）",
    MLEVEL_FMT_ONE     = "+%d 層",
    TTBIS_FILLER_RANK  = "  · 轉換優先度 #%d/%d",
    TTUP_CANT          = "這件（%s%d/%d，升滿約 %d）升不到 %d —— 要去拿：%s",
    TTUP_CAN           = "把這件升級到位即可（%s%d/%d → 升滿約 %d）",
    TTUP_UNKNOWN       = "更高版本來自：%s",
    TRACK_TOO_LOW      = "%s %d/%d 升滿約 %d，到不了 %d",
    GRAD_BIS_TAG       = "已BiS",
    GM_TRACK_TOO_LOW   = "%s %d/%d 升滿約 %d，到不了 %d → 不算 BiS，去刷更高難度的同款 / 坯子",
    TTBIS_TOP_FARM     = "去刷橫評 #1：%s —— %s",
    TTBIS_TOP_TIERDROP = "史詩團本直掉",
    TTUP_ILVL          = "件對了，裝等還差：%d → %d",
    TTUP_HINT_MPLUS    = "大祕境每週寶庫（神話軌道）",
    TTUP_HINT_RAID     = "%s難度團本掉落",
    TTUP_HINT_TIER     = "更高軌道的坯子催化轉換，或史詩團本直掉",
    TTUP_HINT_CRAFTED  = "用更高檔火花重下工藝訂單",
    TTUP_HINT_GENERIC  = "更高難度的同款",
    TTUP_DIFF_MYTHIC   = "史詩", TTUP_DIFF_HEROIC = "英雄", TTUP_DIFF_NORMAL = "普通",
    TTBIS_TIER_RANK    = "套裝本體（原生屬性）在坯子橫評中 #%d/%d",
    TIER_FILLER_CLICK  = "\194\183 點擊檢視可刷取物品（",
    JOURNAL_HINT       = "（指南）",
    SOURCE_PREFIX      = "來源：",

    -- Completed / empty states
    COMPLETED_PREFIX   = "已完成部位：",
    GRAD_HDR           = "已畢業槽位",
    POTION_LOW_NOTE    = "該專精頂尖玩家戰鬥藥水使用率低，按屬性/需求自選即可",
    GRAD_HDR_TT        = "點擊展開/收起已畢業槽位",
    COMPLETED_SUFFIX   = "（開啟刷裝優先序檢視完整清單）",
    EMPTY_COMPANION    = "Companion 已連線，沒有待處理項目",
    EMPTY_KEY_DONE     = "關鍵部位已完成；開啟刷裝優先序檢視完整清單",
    EMPTY_NONE         = "沒有下一步",

    -- Farming guide
    FG_NODATA          = "沒有刷裝優先序資料",
    CAT_RAID           = "團本",
    CAT_MPLUS          = "王者試煉",
    CAT_CRAFTED        = "製造",
    CAT_WORLD          = "世界掉落",
    CAT_TIER           = "套裝",
    CAT_QUEST          = "任務/聲望",
    FG_NEED            = "需要 ",
    FG_PCS             = "",
    FG_COMPLETE        = "（已完成）",
    FG_SUB_COMPLETE    = "  已完成",
    FG_CRAFTED_NOTE    = "製造業裝備刷本刷不到、拍賣場也搜不到：找對應專業的玩家下「工藝訂單」（自備火花和材料）。僅列最值得做的 2 個部位",
    OBTAINED           = "  （已擁有）",
    ILVL_LOW_PRE       = "（裝等偏低 ",
    MISSING_TAG        = "  [缺少]",
    FILLER_TAG         = "（補位 / 轉換）",

    -- Tier filler popup
    TIER_POPUP_HINT    = "透過催化裝置轉換任一件物品（同部位、同護甲類型）",
    TIER_POPUP_SUFFIX  = " 套裝補位",
    TIER_DEFAULT_SLOT  = "套裝",
    LOADING            = "載入中...",

    -- Multi-spec farming planner
    MS_TITLE     = "多專精戰利品規劃",
    MS_HINT      = "勾選你想一起刷的專精；每個首領會顯示要設定的戰利品專精",
    MS_PICK_HINT = "勾選你想一起刷的專精",
    MS_NODATA    = "沒有資料",
    MS_ALL_DONE  = "在目前資料中，所選專精皆已畢業",
    MS_OTHER     = "其他來源",
    MS_BTN_CUR   = "戰利品專精：%s（目前）",
    MS_BTN_SET   = "設定戰利品專精：%s",
    MS_BTN_OPEN  = "多專精戰利品",
    MS_COMBAT    = "戰鬥中無法變更戰利品專精",
    MS_SET_OK    = "戰利品專精已設定為 %s",
    MS_SHARED    = "多專精共用",
    MS_CLICK_JOURNAL = "點擊開啟冒險指南",
    MS_CLICK_FILLER = "點擊檢視可催化的同部位物品",
    MS_TIER_TAG = "[可催化物品]",
    MS_TIER_NOTE = "[套裝部位 · 下方為可催化的補位物品]",

    -- Slot top-5 popup
    TOP5_CLICK_HINT    = "點擊檢視此部位使用率前 5 名",
    TOP5_POPUP_HINT    = "頂尖玩家此部位最常使用的物品",
    TOP5_TITLE_SUFFIX  = " \194\183 使用率前 5 名",
    TOP5_DEFAULT_SLOT  = "部位",
    TOP5_BTN           = "前 5 名",
    TOP5_BTN_TT        = "檢視此部位使用率前 5 名",

    -- New 12.0 Demon Hunter spec (spec-ID API can't name it off the active spec)
    SPEC_DEVAURER = "吞噬者",
    TIER_FILLER_CLICK2 = "· 點擊檢視可催化物品",

    -- Export to web companion
    EXPORT_BTN    = "匯出裝備",
    EXPORT_TIP    = "匯出裝備字串，貼到網頁版 Companion 取得你的升級清單",
    EXPORT_WEB_HINT = "開啟 |cFF4DB8FFgearinsight.app/wow/en/analyze|r → 貼上此字串，即顯示缺件清單 + 刷取順序",
    EXPORT_TITLE  = "匯出裝備至網頁",
    EXPORT_HINT   = "按 Ctrl+C 複製下方字串，再貼到網頁版 Companion 檢視你的升級清單",
    EXPORT_NODATA = "沒有可匯出的資料 — 請先開啟面板或執行 /gi refresh",

    -- QQ group (China community)
    QQ_LABEL           = "QQ 群 954673901（點擊複製）",
    QQ_TITLE           = "QQ 群",
    QQ_HINT            = "按 Ctrl+C 複製群號",
    QQ_TOOLTIP         = "點擊複製 QQ 群 954673901",
    QQ_JOIN            = "加入 QQ 群取得最新資料更新：|cFFFFFF00954673901|r",

    -- Global tooltip BiS rank
    FG_ONLYTOP_ON        = "第一BiS: 只看",
    FG_ONLYTOP_OFF       = "第一BiS: 全部",
    FG_ONLYTOP_TIP       = "只顯示每個部位排第一的畢業件。\n戒指/飾品留前 2、武器按雙持/雙手留 1–2；套裝部位只留第一名坯子。",
    MT_TAB_WISH          = "刷本規劃",
    WLP_SUB              = "來源：%s   ·   共 %d 件",
    WLP_SRC_RECS         = "下一步建議（你缺且能提升的）",
    WLP_SRC_BIS = "BiS 全表",
    WLP_SRC_NONE         = "暫無數據",
    WLP_STAT_TIP_BIS = "現在用的是 BiS 全表墊底，不是依你目前配裝算出來的下一步建議。|n多半是資料不新鮮了 —— 在「裝備總覽」重新整理一次就會換成更準的來源。",
    WLP_ON               = "隊友拾取提醒: 開",
    WLP_OFF              = "隊友拾取提醒: 關",
    WLP_DEMO             = "試一發",
    WLP_TOGGLE_TIP       = "隊友在隊伍裡撿到心願單上的東西時彈窗提醒。\n只對別人拾取生效，自己撿到不打擾。",
    WLP_DEMO_TIP         = "彈一個示例提醒，看看真觸發時長什麼樣。\n8 秒後自動消失，不搶焦點。",
    WLP_EMPTY            = "清單是空的。它由「下一步建議」自動生成 —— 先在裝備總覽頁跑一次分析。",
    WLP_ADD_HINT         = "Shift 點物品連結放這裡，Enter 添加",
    WLP_DEL_TIP          = "把這件踢出心願單",
    WLP_MANUAL           = "[手動]",
    WLP_SRC_MANUAL       = "全部由你手動添加",
    WA_MANUAL            = "手動添加",
    WLP_INTRO            = "隊伍裡掉到你能提升的部位時自動彈框提醒，並可一鍵密語問對方要。|n清單跟著你的裝備走，不用手動維護。",
    WLP_STAT             = "%d 個可提升部位  ·  來源：%s",
    WLP_COL_SLOT         = "部位",
    WLP_COL_CUR          = "目前",
    WLP_COL_TGT          = "目標",
    WLP_COL_GAIN         = "可提升",
    WLP_EMPTY_SLOT       = "空著",
    WP_ASK_GAIN          = "大佬，%s 你還需要嗎？我這個部位能提升 %d 裝等，用不上的話方便給我嗎～謝謝！",
    WP_ASK               = "大佬，%s 你還需要嗎？正好是我要的部位，用不上的話方便給我嗎～謝謝！",
    WP_ASK_FULL          = "大佬，%s 你還需要嗎？我這部位才 %d 裝等（能提升 %d），用不上的話方便給我嗎～謝謝！",
    WLP_COL_BELL         = "提醒",
    WLP_FILLER           = "坯子",
    WLP_BELL_TIP         = "這個部位掉東西時要不要提醒你。|n關掉後該部位不再彈窗，列表裡仍然顯示。",
    WP_TITLE             = "|cffd6b26c目前有 %d 件你可提升的裝備掉落：|r",
    WP_ASK_CUR           = "大佬，%s 你還需要嗎？我這部位現在是 %s，換上能 +%d 裝等，用不上的話方便給我嗎～謝謝！",
    WP_INFO_GAIN         = "|cff40ff40+%d 裝等|r",
    WP_INFO_EMPTY        = "空部位",
    WP_INFO_BIS          = "|cffffd100BiS #%d/共%d|r",
    WLP_LOADING          = "讀取中…",
    TTBIS_HEADER         = "GearInsight",
    TTFILLER_IS          = "本部位套裝坯子",
    TTSRC_RAID           = "團本",
    TTSRC_DROP           = "掉落：",
    TTSRC_SOURCE         = "來源：",
    TTSRC_MPLUS          = "大祕境",
    TTSRC_TIER           = "套裝轉換（催化劑）",
    TTSRC_WORLD          = "世界掉落",
    TTSRC_CRAFTED        = "製造業",
    TTSRC_BOSSNUM        = "%d號",
    TTBIS_CUR_FMT        = "%s BiS #%d / 共%d",
    TTBIS_SEASON_TAG        = "賽季 BiS 排名",
    TTBIS_USAGE_FMT      = "使用率 %.1f%%",
    TTBIS_USAGE_RAID     = "團本 %.1f%%",
    TTBIS_USAGE_MPLUS    = "大秘境 %.1f%%",
    TTBIS_OTHER_LABEL    = "其他職業：",
    TTBIS_SAMECLASS_LABEL = "本職業其他專精：",
    TTBIS_OTHER_ENTRY_FMT = "%s %s#%d",
    TTBIS_OTHER_MORE_FMT = "等 %d 個專精",
    TTBIS_OTHER_SEP      = " \194\183 ",
    TTBIS_SLOT_FINGER    = "戒指",
    TTBIS_SLOT_TRINKET   = "飾品",
    TTBIS_SLOT_WEAPON    = "武器",
    TTBIS_TOGGLE_ON      = "物品 tooltip BiS 排名：已開啟",
    TTBIS_TOGGLE_OFF     = "物品 tooltip BiS 排名：已關閉",
    TTBIS_TOGGLE_CURRENT = "物品 tooltip：僅顯示目前專精",
    TTBIS_TOGGLE_ALL     = "物品 tooltip：顯示全部專精",
    TTBIS_TOGGLE_USAGE   = "用法：/gi tooltip on|off|current|all|others（專精勾選請用面板「懸浮提示」按鈕）",
    TTBIS_TOGGLE_OTHERS_ON  = "物品 tooltip：顯示其它職業",
    TTBIS_TOGGLE_OTHERS_OFF = "物品 tooltip：隱藏其它職業",
    TTBIS_BTN            = "顯示設定",
    TTBIS_BTN_TIP        = "顯示相關設定：\n· 物品懸浮提示 BiS 排名行的顯示範圍\n  （勾選要顯示的本職業專精，其它職業預設隱藏）\n· 角色面板(C鍵) BiS 圖示開關",
    TTBIS_MENU_NA        = "目前客戶端不支援選單，請用命令：/gi tooltip others（其它職業開關）| on|off|current|all",

    -- 角色面板 BiS 圖示 (PaperDollBis)
    PDB_COLLECTED        = "已收集 — 這就是該部位 BiS",
    PDB_SOURCE           = "刷取：",
    PDB_USAGE            = "頂尖玩家使用率 %.0f%%",
    PDB_CLICK            = "點擊查看本部位使用率前5",
    PDB_TOGGLE_ON        = "角色面板 BiS 圖示：已開啟",
    PDB_TOGGLE_OFF       = "角色面板 BiS 圖示：已關閉",
    PDB_MENU_TOGGLE      = "角色面板(C鍵)顯示 BiS 圖示",
    PDB_MENU_SIZE        = "BiS 圖示大小",
    PDB_MENU_POS         = "BiS 圖示位置",
    PDB_POS_TL           = "左上",
    PDB_POS_TR           = "右上",
    PDB_POS_BL           = "左下",
    PDB_POS_BR           = "右下",
    PDB_SIZE_SET         = "角色面板 BiS 圖示大小：%dpx",
    PDB_POS_SET          = "角色面板 BiS 圖示位置：",
    PDB_CFG_HELP         = "用法：/gi cbis on|off | size 10-30 | pos tl|tr|bl|br",
    PDB_BEST_ENCH        = "本部位最火附魔：",
    PDB_BEST_GEM         = "最火寶石：",
    PDB_ENCH_SEE_GUIDE   = "(見攻略)",
    GROUPBIS_MENU_TOGGLE = "組隊懸停顯示隊友 BiS 畢業度",

    -- 裝備難度檔 (TierView)
    TIER_MYTHIC          = "傳奇",
    TIER_HEROIC          = "英雄",
    TIER_NORMAL          = "普通",
    TIER_MYTHIC_SUFFIX   = "（預設·頂尖原始資料）",
    TIER_MENU_TITLE      = "BiS 參照難度檔（裝等/畢業判定按檔換算）",
    TIER_SET             = "BiS 參照難度檔：",
    TIER_SET_NOTE        = "（裝等按該檔可獲取數值換算；使用率仍為頂尖玩家參照）",
    TIER_HELP            = "用法：/gi tier m|h|n（傳奇/英雄/普通）；目前：",
    TIER_TAG             = "檔",

    -- 網頁版角色主頁 (gearinsight.app)
    WEB_BTN              = "網頁版角色主頁（點擊複製）",
    WEB_TITLE            = "網頁版角色主頁",
    WEB_HINT             = "按 Ctrl+C 複製，瀏覽器開啟：戰力評分 / AI 教練 / BiS 缺件",
    WEB_TOOLTIP          = "複製你的專屬網頁：戰力評分 / AI 教練 / BiS 缺件\n也可發給隊友看你的戰績",
    WEB_URL_FAIL         = "角色資訊未就緒，稍後再試",
    TTBIS_MENU_TITLE     = "顯示設定 \194\183 物品懸浮提示 BiS 排名",
    TTBIS_MENU_ENABLE    = "啟用懸浮提示",
    TTBIS_MENU_SAMECLASS = "本職業其它專精（勾選=顯示）",
    TTBIS_MENU_OTHERS    = "顯示其它職業",

    -- LoadOnDemand 天賦庫子插件
    TALENT_LOD_FAIL      = "天賦庫模組(GearInsight_Talents)載入失敗：",
    TALENT_LOD_HINT      = "  請到角色選擇介面「插件」清單確認它已啟用",

    -- Crafted-gear mini recommendation
    SECTION_CRAFTED_PICKS = "製造推薦（結合BiS）",

    -- Gems & enchants section
    SECTION_GEMS_ENCH  = "推薦寶石與附魔",
    GEMS_LABEL         = "寶石（依使用率）：",
    ENCH_LABEL         = "附魔（依部位）：",
    ENCH_SEE_GUIDE     = "(見攻略)",
    GE_USAGE_PREFIX    = "頂尖使用率：",
    CONS_LABEL         = "消耗品（依屬性/角色取捨）：",
}

-- Slot labels & a handful of tooltip lines come from GearInsight.L (set by zhCN.lua,
-- which loads unconditionally). On a zhTW client they would otherwise render in
-- Simplified Chinese, so override them with Traditional Chinese here. Mirrors the
-- enUS.lua approach; gated on zhTW so zhCN/enUS behaviour is untouched.
if GearInsight.LOCALE == "zhTW" then
    local L = GearInsight.L
    if L then
        -- Slot labels
        L["SLOT_HEAD"]     = "頭部"
        L["SLOT_NECK"]     = "頸部"
        L["SLOT_SHOULDER"] = "肩部"
        L["SLOT_CHEST"]    = "胸甲"
        L["SLOT_WAIST"]    = "腰帶"
        L["SLOT_LEGS"]     = "腿部"
        L["SLOT_FEET"]     = "腳部"
        L["SLOT_WRIST"]    = "手腕"
        L["SLOT_HANDS"]    = "手部"
        L["SLOT_FINGER1"]  = "戒指1"
        L["SLOT_FINGER2"]  = "戒指2"
        L["SLOT_TRINKET1"] = "飾品1"
        L["SLOT_TRINKET2"] = "飾品2"
        L["SLOT_BACK"]     = "背部"
        L["SLOT_MAINHAND"] = "主手"
        L["SLOT_OFFHAND"]  = "副手"
        L["SLOT_UNKNOWN"]  = "未知部位"
        L["NO_ITEM"]       = "（空槽）"

        -- Tooltip lines (TooltipHook.lua / MinimapButton.lua read these directly)
        L["TOOLTIP_UPGRADE"]       = "對你的提升"
        L["TOOLTIP_SLOT_RANK"]     = "部位排名"
        L["TOOLTIP_USAGE"]         = "頂尖使用率"
        L["TOOLTIP_SOURCE"]        = "取得方式"
        L["TOOLTIP_ESTIMATED"]     = "（估算）"
        L["TOOLTIP_TOTAL_ITEMS"]   = "共 %d 件參考"
        L["MINIMAP_TOOLTIP_TITLE"] = "GearInsight"
        L["MINIMAP_TOOLTIP_LEFT"]  = "左鍵：開啟/關閉面板"
        L["MINIMAP_TOOLTIP_RIGHT"] = "右鍵：重新讀取裝備"

        -- Other L strings that may surface in prints/labels
        L["ADDON_LOADED"]   = "GearInsight 已載入。輸入 /gi 開啟面板。"
        L["OPEN_PANEL"]     = "開啟裝備分析面板"
        L["CLOSE_PANEL"]    = "關閉面板"
        L["RELOAD_DATA"]    = "重新讀取裝備資料"
        L["SECTION_OVERVIEW"]  = "裝備總覽"
        L["SECTION_STATS"]     = "屬性達成度"
        L["SECTION_UPGRADE"]   = "升級建議"
        L["CURRENT_ILVL"]      = "目前裝等"
        L["TARGET_ILVL"]       = "畢業裝等"
        L["SPEC_LABEL"]        = "專精"
        L["CLASS_LABEL"]       = "職業"
        L["HERO_TALENT_LABEL"] = "英雄天賦"
        L["STAT_VERSATILITY"]  = "臨機"
        L["STAT_MASTERY"]      = "精通"
        L["STAT_CRIT"]         = "致命"
        L["STAT_HASTE"]        = "加速"
        L["STAT_STRENGTH"]     = "力量"
        L["STAT_AGILITY"]      = "敏捷"
        L["STAT_INTELLECT"]    = "智力"
        L["STAT_STAMINA"]      = "耐力"
        L["STAT_PROGRESS_FMT"] = "%.1f%% / %.1f%%（目標）"
        L["NO_SPEC_DATA"]      = "暫無此專精的畢業資料"
        L["DATA_VERSION"]      = "資料版本"
        L["GEAR_REFRESHED"]    = "裝備資料已重新整理。"
        L["SAVED_OK"]          = "角色資料已儲存至 GearInsightDB。"
        L["NO_ITEM_EQUIPPED"]  = "該部位未裝備物品。"
        L["UNKNOWN_CLASS"]     = "未知職業"
        L["UNKNOWN_SPEC"]      = "未知專精"
    end
end

-- ⭐ 2026-08-29：补齐 56 条 T() 用了但本文件没定义的 key。
-- 这些 key 原本静默回退到内联**简体中文**，繁中玩家看到的是简体。
-- 由 scripts/gi_locale_audit.py 找出；⛔ 发版前必须再跑一次确认 0 缺失。
-- ⛔ 格式化占位符（%s / %d / %.0f%%）必须与简体原文完全一致。
do
    local L = GearInsight.LOC["zhTW"]

    -- 拍賣場複製
    L["COPY_TITLE"]       = "去拍賣場購買"
    L["COPY_HINT"]        = "Ctrl+C 複製，到拍賣場搜尋框貼上購買"
    L["CONS_COPY_HINT"]   = "Ctrl+C 複製「%s」，到拍賣場搜尋框貼上購買"
    L["CONS_COPY_TT"]     = "點擊複製名稱 → 到拍賣場搜尋購買"
    L["ENCH_COPY_TT"]     = "點擊複製名稱 → 到拍賣場搜尋購買"
    L["ENCH_ALT_TT"]      = "次選："

    -- 消耗品
    L["CONS_FOOD_META"]   = "（主流）"
    L["CONS_LABEL_USAGE"] = "消耗品（藥劑/藥水使用率：%s·%d樣本 · 點擊複製名稱）"

    -- 地城百科
    L["EJ_COMBAT"]        = "戰鬥中無法開啟地城百科（暴雪限制），脫離戰鬥後再點"

    -- 團本排除 / 其他
    L["EXRAID_ON"]        = "已排除團本裝備：只推薦傳奇鑰石／製造等非團本來源"
    L["EXRAID_OFF"]       = "已恢復：推薦含團本裝備"
    L["GRAD_UPGRADABLE"]  = "可升級"
    L["USAGE_MODE_SET"]   = "使用率參照系已切換為："
    L["EXPORT_HINT_EN"]   = "Ctrl+C 複製下方字串，貼到 gearinsight.app"
    L["CONTENT_PUSH"]     = "衝分"
    L["CONTENT_FARM"]     = "割草"
    L["MLEVEL_FARM"]      = "+12 層"

    -- 拾取需求單
    L["NEED_TITLE"]       = "拾取需求單 · 發給團長／隊友"
    L["NEED_HEADER"]      = "【團本拾取需求單】%s-%s %s 裝等%d"
    L["NEED_SPECLINE"]    = "專精: %s | 難度: 史詩/英雄/普通(依所打難度保留)"
    L["NEED_LOOTSET"]     = "拾取設定:"
    L["NEED_ITEMS"]       = "需求: "
    L["NEED_SLOT"]        = "槽"
    L["NEED_FREE"]        = "自由分配,無需求"
    L["NEED_TOTAL"]       = "合計: 需求裝備%d件"
    L["NEED_TRASH"]       = "小怪(全程區域掉落)"
    L["NEED_SRC_OTHER"]   = "其他來源"
    L["NEED_OFFRAID"]     = "本團本拿不到,另行安排:"
    L["NEED_OFFRAID_MORE"]= "- (等%d件,見插件刷裝優先序)"
    L["NEED_REMIND"]      = "開打前提醒: 有拾取設定的BOSS,開打前先切專精拾取(拾取選項→專精拾取)"
    L["NEED_HINT"]        = "Ctrl+C 複製；可先在框內直接編輯（刪難度、改措辭）再複製。專精範圍跟隨「多專精拾取」勾選。"
    L["NEED_NODATA"]      = "無法產生需求單：請先開啟面板或 /gi refresh 重新整理裝備資料"
    L["NEED_NORAID_WARN"] = "※ 目前開啟了「團本排除」，團本需求未列出——/gi noraid off 後重新產生"
    L["NEED_FOOTER"]      = "—— GearInsight 產生 · gearinsight.app"
    L["MS_NEED_BTN"]      = "複製需求單文字"
    L["MS_NEED_TIP"]      = "依上方勾選的專精產生逐BOSS需求單文字\n（拾取設定/需求裝備/擲幣推薦），複製後發給團長／隊友"

    -- ROLL 幣
    L["NEED_COIN_NAME"]    = "晦暗虛空核心"
    L["NEED_COIN_ORDER"]   = "擲幣優先: "
    L["NEED_COIN_HAVE"]    = "ROLL幣(%s): 現有%d個 = 可額外擲%d次"
    L["NEED_COIN_UNKNOWN"] = "ROLL幣(晦暗虛空核心): 數量未讀到,依下列順序使用"
    L["NEED_ROLLAT"]       = "★ROLL幣第%d優先"

    -- 伺服器地區
    L["REGION_CN"] = "國服"
    L["REGION_TW"] = "台服"
    L["REGION_KR"] = "韓服"
    L["REGION_EU"] = "歐服"
    L["REGION_RU"] = "俄服"

    -- 場景
    L["SCEN_RAID"] = "團本"
    L["SCEN_MH"]   = "傳奇鑰石高層"
    L["SCEN_MF"]   = "傳奇鑰石割草"

    -- 屬性目標
    L["STAT_BASIS_TITLE"] = "屬性目標 = 學 WCL 頂尖玩家的屬性配比"
    L["STAT_BASIS_BODY"]  = "目標佔比 = WCL 頂尖玩家把副屬性按什麼比例分配（致命/加速/精通/臨機，依目前場景：團本/高層/割草），\n"
    L["STAT_WORST_R"]     = "  |  最缺: %s(%.0f%%達標)"

    L["CFG_TGT_ILVL"]   = "心願單目標裝等"
    L["CFG_TGT_ILVL_D"] = "只按你自己的目標算差距：到了這個裝等的部位就從心願單消失。0 = 跟頂尖玩家口徑（預設）。賽季初只打大秘境時最有用。"

    L["GM_STATFIT"]     = "副屬性契合"

    -- 自訂密語話術（玩家「目暮」2026-09-07 提）
    L["CFG_WHISPER"]        = "密語要裝備的話術"
    L["CFG_WHISPER_D"]      = "彈窗裡點「密語」時預先填入的內容。可用 {item} 那件裝備、{cur} 你目前這件、{gain} 提升裝等、{slot} 部位、{me} 你的名字。留空使用預設。"
    L["CFG_WHISPER_EDIT"]   = "編輯"
    L["CFG_WHISPER_RESET"]  = "恢復預設"
    L["CFG_WHISPER_RESET_OK"] = "密語話術已恢復預設。"
    L["WP_EDIT_TITLE"]      = "自訂密語話術"
    L["WP_EDIT_HINT"]       = "可用佔位符：|cFFFFD100{item}|r 那件裝備  |cFFFFD100{cur}|r 你目前這件  |cFFFFD100{gain}|r 提升裝等  |cFFFFD100{slot}|r 部位  |cFFFFD100{me}|r 你的名字\n取不到的會自動去掉。留空則用預設話術。"
    L["WP_EDIT_PREVIEW"]    = "預覽"
    L["WP_EDIT_SAVE"]       = "儲存"
    L["WP_EDIT_RESET"]      = "恢復預設"
    L["WP_EDIT_SAVED"]      = "密語話術已儲存。"
    L["WP_TPL_DEFAULT"]     = "大佬，{item} 你還需要嗎？我這部位現在是 {cur}，換上能 +{gain} 裝等，用不上的話方便給我嗎～謝謝！"
    L["EMB_OVER"]           = "你身上有 %d 件「美化」裝備，遊戲上限是 2 件 —— 多出來的那件不會生效。"
    L["WP_ILVL"]            = "裝等"

    -- Parse 評分卡 (ui/ParseScore.lua)
    L["PS_T_LEGEND"]   = "傳說"
    L["PS_T_PINK"]     = "粉"
    L["PS_T_ORANGE"]   = "橙"
    L["PS_T_PURPLE"]   = "紫"
    L["PS_T_BLUE"]     = "藍"
    L["PS_T_GREEN"]    = "綠"
    L["PS_T_GRAY"]     = "灰"
    L["PS_SHARE"]      = "分享"
    L["PS_LINE1"]      = "|cFFFFD100[%s]|r  你 ≈ |c%sp%d %s|r"
    L["PS_LINE2_GAP"]  = "DPS %s · 距 p%d 還差 ~%s"
    L["PS_LINE2_SRC"]  = "DPS %s · 資料來源 %s"
    L["PS_SHARE_TXT"]  = "[GearInsight] %s 我打出 p%d(%s)! DPS %d ——你的呢？"
    L["PS_COPY_HINT"]  = "Ctrl+C 複製分享"
    L["PS_COPY_TITLE"] = "Parse 分享"
    L["PS_NO_DMG"]     = "沒讀到你的傷害（確認 Details! 開著）。"
    L["PS_NO_CURVE"]   = "目前專精暫無 parse 曲線。"
    L["MS_MISSING_N"]  = "(缺 %d 件)"
    L["SLOT_N"]        = "槽"

    -- Telegram（非中文客戶端社群；繁中一併給出，避免回退到簡體）
    L["TG_JOIN"]    = "加入 Telegram 群取得資料更新與回饋：|cFFFFFF00t.me/gearInsight|r"
    L["TG_TITLE"]   = "Telegram 群組"
    L["TG_LABEL"]   = "Telegram：t.me/gearInsight（點擊複製）"
    L["TG_HINT"]    = "Ctrl+C 複製，用瀏覽器開啟即可加入"
    L["TG_TOOLTIP"] = "點擊複製 Telegram 群組連結"
end

-- ⭐ 2026-08-29：沒有 Journal 條目的來源（localizedSource 的 _NON_JOURNAL_SRC 查表）。
do
    local L = GearInsight.LOC["zhTW"]
    L["SRC_CRAFTED"]    = "製造業"
    L["SRC_TIERCONV"]   = "套裝轉換"
    L["SRC_WORLD"]      = "世界掉落"
    L["SRC_REPQUEST"]   = "奇點聲望任務"
    L["SRC_OTHER"]      = "其他來源"
    L["SRC_KEYCHEST"]   = "鑰石寶箱"
    L["SRC_KEYCHEST_M"] = "鑰石寶箱（傳奇鑰石）"
end

-- 大秘境情报面板 (0.65.0, 2026-08-31)
do
    local t = GearInsight.LOC and GearInsight.LOC["zhTW"]
    if t then
        t["MM_TITLE"] = "傳奇鑰石情報"
        t["MM_NEW"] = "新"
        t["MM_WAN"] = "萬"
        t["MM_DATA_TO"] = "資料截至"
        t["MM_SAME_SRC"] = "與官網同源"
        t["MM_STALE_SOFT"] = "資料已 %d 天沒更新"
        t["MM_STALE_HARD"] = "資料已 %d 天沒更新，建議更新插件"
        t["MA_ROLE_TANK"] = "坦克位"
        t["MA_ROLE_HEAL"] = "治療位"
        t["MA_ROLE_DPS"] = "輸出位"
        t["MA_NODATA"] = "資料未載入"
        t["MA_RANK_N"] = "第%d名"
        t["MA_NOT_ON_BOARD"] = "你的專精不在該位置榜上（樣本太少）"
        t["MA_TOP3"] = "前三"
        t["MA_HINT"] = "/gi 看完整榜"
        t["LS_HINT"] = "拾取專精提示：%s 在本本能掉 %d 件畢業裝，你目前拾取只吃到 %d 件"
        t["LS_INCL"] = "其中包括"
        t["LS_HOW"] = "改拾取專精：角色介面 → 專精 → 拾取專精"
        t["WA_PREFIX"] = "心願單："
        t["WA_GOT"] = "撿到了"
        t["WA_TIP"] = "點名字可以直接密他"
        t["WP_WHISPER"] = "密語"
        t["WP_NEXT"] = "下一件"
        t["MT_TAB_PVP"] = "PvP 裝備"
        t["PM_TANK"] = "坦"
        t["PM_HEAL"] = "奶"
        t["PM_PLAYERS"] = " 人上榜"
        t["PM_H_PLAY"] = "誰在玩（占比 · 人數）"
        t["PM_H_WIN"] = "勝率（按場次加權）"
        t["PM_H_TOP"] = "%d 分以上人數"
        t["PM_TOTAL_TOP"] = "本模式共 %d 人"
        t["MB_RESCUED"] = "小地圖按鈕跑出螢幕了，已放回預設位置（左下）。想換地方直接拖它。"
        t["MB_BACK"] = "小地圖按鈕已放回預設位置（小地圖左下角）。"
        t["MB_FAIL"] = "小地圖按鈕建立失敗，請 /reload 後再試一次。"
        t["PM_H_TAL"] = "你的專精 · 頂尖玩家點了什麼"
        t["PM_TAL_SUB"] = "%s 榜前 %d 名 · 樣本 %d 人"
        t["PM_TAL_PVP"] = "PvP 專屬天賦"
        t["PM_TAL_HERO"] = "英雄天賦"
        t["PM_TAL_TREE"] = "天賦樹 · 誰點誰不點"
        t["PM_TAL_NOTE"] = "這是上榜玩家實際點的，不是「最優解」。"
        t["PM_H_BUILD"] = "一鍵匯入這套天賦"
        t["PM_RATING"] = " 分"
        t["PM_IMPORT"] = "匯入這套天賦"
        t["PM_NO_IMPORT"] = "找不到天賦匯入介面，請確認插件完整。"
        t["PM_IMPORT_OK"] = "天賦樹已匯入，還要自己去 PvP 天賦介面選那 3 個專屬天賦。"
        t["PM_IMPORT_FAIL"] = "匯入失敗："
        t["PM_HIS_PVP"] = "他的 PvP 天賦："
        t["PM_IMPORT_NOTE"] = "匯入只點天賦樹。PvP 專屬那 3 個不在字串裡，要自己去 PvP 天賦介面選。"
        t["PM_GAMES"] = "場"
        t["PM_SEASON"] = "第 %d 賽季"
        t["PM_STALE"] = "（資料已 %d 天未更新，建議更新插件）"
        t["PM_NODATA"] = "PvP 情報資料未載入"
        t["PM_NOTE1"] = "人多不等於強 —— 參與度高可能只是好上手、或者這陣子流行。"
        t["PM_NOTE2"] = "勝率只統計上榜玩家；單人成隊每局 6 人按輪次記勝負，天生貼近 50%，別跟戰場突襲橫比。"
        t["PM_NOTE3"] = "資料來自暴雪官方 PvP 排行榜，與官網同源。"
        t["WP_NTH"] = "|cff888888（第 %d/%d 件）|r"
        t["WP_CLOSE"] = "關閉"
        t["WP_DEMO_ITEM"] = "護衛之牙束帶"
        t["MM_H_PUSH"] = "衝層輸出榜"
        t["MM_LVL_UP"] = "層以上"
        t["MM_RUNS"] = " 場"
        t["MM_H_ROLE"] = "坦克 / 治療被選率"
        t["MM_TANKS"] = "坦克  "
        t["MM_HEALS"] = "治療  "
        t["MM_H_FARM"] = "刷場輸出榜"
        t["MM_LVL"] = "層"
        t["MM_H_TANKDPS"] = "坦克也要打傷害"
        t["MM_H_HEALDPS"] = "治療也要打傷害"
        t["MM_H_DUNGEON"] = "最快的地城"
        t["MM_H_UNDER"] = "被低估（傷害不落後 · 沒人用）"
        t["MM_IN_USE"] = " 在用"
        t["MM_RECORDS"] = " 條記錄"
        t["MM_FOOT"] = "口徑：每地城排行榜前 100 名的中位數 · raider.io 真實名單 · 每週更新"
        t["MM_NODATA"] = "傳奇鑰石情報資料未載入"
        t["OV_GRAD"] = "畢業基準: "
        t["OV_GRAD_NOTE"] = "（頂尖玩家實穿口徑）"
    end
end

-- 0.66.0 主面板左側標籤頁（ui/MainTabs.lua）
do
    local t = GearInsight.LOC.zhTW
    t["MT_TAB_OV"] = "裝備總覽"
    t["MT_TAB_MM"] = "傳奇鑰石情報"
    t["MT_TAB_TOOLS"] = "攻略"
    t["MT_TAB_SET"] = "設定"
    t["MT_CAP_EXPORT"] = "匯出裝備字串，貼到網頁版看缺件清單"
    t["MT_CAP_TALENT"] = "WCL 頂尖玩家天賦，一鍵複製匯入字串"
    t["MT_CAP_ROT"] = "頂尖玩家起手序列 / 技能頻率 / 增益盯防"
    t["MT_CAP_DG"] = "地城攻略：打斷優先序 / 致死技能 / 承傷構成"
    t["MT_CAP_FARM"] = "該刷哪個地城：按對你的提升大小排序"
    t["MT_CAP_MS"] = "多專精一起規劃拾取，別錯拾貪裝"
    t["MT_CAP_MODE"] = "使用率% 參照誰：團隊 / 傳奇鑰石頂尖玩家（連動畢業件與刷取規劃）"
    t["MT_CAP_EXRAID"] = "是否把團隊掉落納入推薦（不打團隊的獨行玩家選排除）"
    t["MT_CAP_TIP"] = "物品滑鼠提示 BiS 行的顯示範圍、角色面板圖示開關"
    t["MT_CAP_REFRESH"] = "重讀當前裝備並重算全部推薦"
end
do
    local t = GearInsight.LOC.zhTW
    t["MT_TAB_TAL"] = "天賦 · WCL 頂尖玩家"
    t["MT_TAB_TAL_SHORT"] = "天賦"
end
do
    local t = GearInsight.LOC.zhTW
    t["TTBIS_CATALYST_PRE"] = "催化轉換成 "
    t["TTBIS_TRACK_LOW"] = "|A:services-icon-warning:12:12|a %s軌道升到頂約 %d，轉出的套裝到不了 %d —— 要更高軌道的坯子"
    t["TTBIS_CATALYST_POST"] = " 後 = BiS #%d"
end
-- 0.67.0 进阶页（ui/AdvancedPage.lua）
do
    local t = GearInsight.LOC.zhTW
    t["MT_TAB_ADV"] = "進階 · 與網站互聯"
    t["MT_TAB_ADV_SHORT"] = "進階"
    t["ADV_ERR_EMPTY"] = "沒有內容"
    t["ADV_ERR_FMT"] = "格式不對：要以 GIAD1| 開頭（在網站分析頁點「複製回插件」）"
    t["ADV_ERR_SUM"] = "校驗不過：字串沒複製全，回網站重新複製一次"
    t["ADV_ERR_NODATA"] = "字串裡沒有分析內容"
    t["ADV_PLAN_NONE"] = "還沒匯入過 —— 網站分析完，把「複製回插件」的字串貼到上面。"
    t["ADV_PLAN_HEAD"] = "網站分析結果 · "
    t["ADV_PLAN_IMPORTED"] = " 匯入於 "
    t["ADV_FARM_HEAD"] = "建議刷取順序（缺件多的副本優先）："
    t["ADV_MISS_HEAD"] = "缺件清單（按使用率）："
    t["ADV_MISS_MORE"] = "…還有 %d 件，完整清單看網站"
    t["ADV_INTRO"] = "三步閉環：①下面「匯出裝備」複製裝備字串 → ②到 gearinsight.app 分析頁貼上，看戰力評分 / 缺件清單 / AI 建議 → ③把網站給的「複製回插件」回執字串貼回下面，刷取優先序就常駐這頁。"
    t["ADV_IMPORT_LABEL"] = "貼上網站回執字串（分析頁 →「複製回插件」）："
    t["ADV_IMPORT_BTN"] = "匯入分析結果"
    t["ADV_IMPORT_OK"] = "已匯入 ✓"
end
do
    local t = GearInsight.LOC.zhTW
    t["ADV_SCORE_HEAD"] = "WCL 實戰戰力（網站獨有）："
    t["ADV_SCORE_MED"] = "全 boss 中位 "
    t["ADV_COACH_HEAD"] = "AI 教練點評（網站獨有）："
end
do
    local t = GearInsight.LOC.zhTW
    t["ADV_INTRO"] = "三步閉環：①匯出裝備字串 → ②到 gearinsight.app 分析頁貼上 → ③把「複製回插件」回執貼回來，WCL 戰力評分和 AI 教練點評就常駐這頁（插件自己拿不到網路資料，這是網站獨有的）。"
end
do
    local t = GearInsight.LOC.zhTW
    t["EXPORT_WEB_HINT2"] = "打開下面網址 → 貼上此字串，即出缺件清單 + 刷取順序"
    t["EXPORT_URL_TIP"] = "點擊網址全選 · Ctrl+C 複製"
end
do
    local t = GearInsight.LOC.zhTW
    t["EXPORT_WEB_HINT2"] = "點擊下面網址複製，貼到瀏覽器打開 → 再貼上此字串，即出缺件清單 + 刷取順序"
    t["EXPORT_URL_TIP"] = "點擊這裡複製網址（Ctrl+C）· 貼到瀏覽器"
    t["EXPORT_WEB_HINT3"] = "下面這條網址已經帶上你的裝備 —— 複製它，貼到瀏覽器，直接出缺件清單"
    t["EXPORT_URL_TIP2"] = "已選中，Ctrl+C 複製整條 · 不用再貼上面那串"
end
do
    local t = GearInsight.LOC.zhTW
    t["EJ_OPEN_FAIL"] = "手冊沒能打開（可能是客戶端更新改了介面），請把這行截圖回報: "
end
do
    local t = GearInsight.LOC.zhTW
    t["MM_COL_SPEC"] = "專精"
    t["MM_COL_TIER"] = "檔位"
    t["MM_COL_DPS"] = "平均DPS（前100中位）"
end
do
    local t = GearInsight.LOC.zhTW
    t["TAG_GAP_R3"] = " 缺%d (%.0f%%)"
    t["TAG_OVER_R3"] = " 多%d (+%.0f%%)"
end
do
    -- 副本助手按需載入（core/DungeonModule.lua, 2026-09-04）
    local t = GearInsight.LOC.zhTW
    t["DM_TITLE"] = "副本助手"
    t["DM_BODY"] = "開啟大秘境指導 + 嗜血提醒？（致死技能榜 / 打斷優先度 / 鑰匙時間軸）"
    t["DM_BTN_ENABLE"] = "開啟"
    t["DM_BTN_NEVER"] = "不再提示"
    t["DM_TIP_NEVER"] = "記到本機：以後進本不再彈這個提示，模組也不會載入（零記憶體、零事件）。"
    t["DM_ENABLED"] = "副本助手已開啟：進大秘境自動載入。"
    t["DM_DISABLED"] = "副本助手已永久關閉，之後不再載入、不佔記憶體。想用時點面板上的「大秘境指導」按鈕即可重新開啟。"
    t["DM_LOAD_FAIL"] = "副本助手模組(GearInsight_Dungeon)載入失敗："
    t["DM_COMBAT_WAIT"] = "戰鬥中，副本助手將在脫離戰鬥後載入。"
    t["DM_MASTER"] = "進本自動載入本模組"
    t["DM_MASTER_TIP"] = "關掉 = 下次登入起本模組完全不載入（零記憶體、零事件），上面三項也一併停用。\n隨時點面板「大秘境指導」按鈕可臨時打開並重新開啟。"
end
do
    local t = GearInsight.LOC.zhTW
    t["DM_MASTER"] = "啟用副本助手（進本自動載入）"
    t["DM_MASTER_OFF"] = "已關閉 — 仍可用面板的「大秘境指導」按鈕臨時打開"
end
do
    -- 鑰匙時間軸位置鎖定（bug #108，2026-09-05）
    local t = GearInsight.LOC.zhTW
    t["KT_UNLOCK_HINT"] = "鑰匙時間軸 · 拖動我到合適位置"
    t["KT_UNLOCK_HINT2"] = "擺好後 /gi kt lock 鎖定（鎖定後不擋名條點選）"
    t["KT_UNLOCKED"] = "鑰匙時間軸已解鎖：拖動移動，/gi kt lock 鎖定。"
    t["KT_LOCKED"] = "鑰匙時間軸已鎖定（不再攔截滑鼠）。"
    t["KT_POS_RESET"] = "鑰匙時間軸位置已復位。"
    t["KT_HELP"] = "用法：/gi kt unlock（解鎖拖動）| lock（鎖定）| reset（復位到預設位置）"
    t["KT_UNLOCK_TOGGLE"] = "解鎖時間軸位置(拖動)"
    t["KT_UNLOCK_TIP"] = "鎖定時時間軸完全不接滑鼠（不擋名條點選）。要挪位置先勾上、拖到想要的地方、再取消勾選。也可用 /gi kt unlock / lock / reset。"
end
do
    -- bug #109（2026-09-05）
    local t = GearInsight.LOC.zhTW
    t["KT_ERR"] = "鑰匙時間軸出錯（已停止重新整理，請把這行發給作者）："
    t["DM_LOAD_FAIL_HINT"] = "（請在插件列表裡勾選 GearInsight Dungeon 後 /reload）"
    t["KT_HELP"] = "用法：/gi kt unlock（解鎖拖動）| lock（鎖定）| reset（復位）| debug（診斷，排查時發給作者）"
    t["KT_HELP"] = "用法：/gi kt off（關閉）| on（開啟）| unlock（解鎖拖動）| lock（鎖定）| reset（復位）| debug（診斷，排查時發給作者）"
    t["KT_OFF"] = "鑰匙時間軸已關閉（/gi kt on 重新打開；實用工具 → 副本攻略 裡也能勾）。"
    t["KT_ON"] = "鑰匙時間軸已開啟。"
    t["KT_FIRST_HINT"] = "鑰匙時間軸已顯示。關閉：/gi kt off；挪位置：/gi kt unlock；也可在 實用工具 → 副本攻略 裡取消勾選。"
    t["CONS_CAT_FLASK"] = "精煉藥劑"
    t["CONS_CAT_POTION"] = "藥水"
    t["CONS_CAT_FOOD"] = "食物"
    t["CONS_CAT_RUNE"] = "符文"
    t["CONS_CAT_OIL"] = "武器油"
    t["CONS_CAT_OTHER"] = "其他"
    t["CONS_FOOD_BUFF"] = "%.0f%% 上Buff"
    t["CFG_KT_SCALE"] = "時間軸大小"
    t["KT_SCALE_SET"] = "鑰匙時間軸大小："
    t["KT_SCALE_USAGE"] = "用法：/gi kt scale 0.8～2.0（例如 1.5）"
    t["CONS_FILL_STAT"] = "補%s"
    t["CFG_TITLE"] = "設定總表"
    t["CFG_OPEN_PANEL"] = "開啟插件面板"
    t["CFG_FOOT"] = "改動即時生效並自動儲存。指令：/gi config 開啟本頁。"
    -- 免费事业支持榜（设置页底部，2026-09-12）
    t["SUP_TITLE"] = "免費事業支持榜"
    t["SUP_LEDE"] = "GearInsight 永久免費，靠玩家一起撐著。每一筆支持都直接變成伺服器時長和 AI 分析次數——這面牆記著每一位讓它繼續免費的人。"
    t["SUP_GOAL_TITLE"] = "本週營運費"
    t["SUP_GOAL_PCT"] = "已覆蓋 %d%%"
    t["SUP_LEGEND_SERVER"] = "伺服器"
    t["SUP_LEGEND_LLM"] = "AI 分析（大模型 Token）"
    t["SUP_GOAL_LEFT"] = "還差 %d%%，就能讓 GearInsight 免費再撐一週"
    t["SUP_GOAL_DONE"] = "本週的伺服器和 AI 費用已經有人替大家付了"
    t["SUP_GOAL_HINT"] = "營運費 = 伺服器（網站、鏡像、資料更新）+ AI 分析用的大模型 Token。支持只花在這兩樣上。進度每週四 0 點重置，累計人數和金額不清零。"
    t["SUP_STATS"] = "%d 位支持者 · 本週 %d 筆"
    t["SUP_EMPTY"] = "做這面牆上的第一個名字。"
    t["SUP_FOOT"] = "更新時間 %s（隨外掛版本一起更新）· 支持與登記：%s/wow/en/supporters"
    t["CFG_SEC_PANEL"] = "角色面板與浮動提示"
    t["CFG_PDB"] = "角色面板 BiS 圖示"
    t["CFG_PDB_D"] = "開啟角色面板時，每個部位角上顯示該部位的畢業件小圖示，懸停看來源。"
    t["CFG_PDB_SIZE"] = "圖示大小"
    t["CFG_PDB_POS"] = "圖示位置"
    t["CFG_PDB_POS_D"] = "擋住別的插件的裝等數字時換個角。"
    t["CFG_POS_TL"] = "左上"
    t["CFG_POS_TR"] = "右上"
    t["CFG_POS_BL"] = "左下"
    t["CFG_POS_BR"] = "右下"
    t["CFG_TT"] = "物品浮動提示裡的 BiS 行"
    t["CFG_TT_D"] = "滑鼠放到任何裝備上，提示裡多出「GearInsight」段：本職業各專精排名、來源、最熱門附魔。"
    t["CFG_TT_OTHERS"] = "浮動提示也顯示其它職業"
    t["CFG_TT_SRC"] = "浮動提示顯示來源行"
    t["CFG_INSPECT"] = "檢視隊友時顯示對方的 BiS 差距"
    t["CFG_INSPECT_D"] = "檢視視窗旁多一個小面板，看隊友還缺哪幾件。"
    t["CFG_GEARVIEW"] = "裝備總覽預設用「裝備圖」"
    t["CFG_GEARVIEW_D"] = "關掉則用舊的列表檢視。面板右上角隨時可切。"
    t["CFG_SEC_DM"] = "副本助手（大米攻略 / 臨場提示 / 鑰匙時間軸）"
    t["CFG_DM"] = "進大秘境自動載入副本助手"
    t["CFG_DM_D"] = "預設關。開了才會在進本時載入下面三樣；關掉後模組不載入、不佔記憶體。"
    t["CFG_DM_POPUP"] = "進本自動彈出大米攻略"
    t["CFG_DM_POPUP_D"] = "打斷優先級 / 致死技能 / 承傷構成。關掉後仍可點面板「大米攻略」手動看。"
    t["CFG_LG"] = "臨場提示（必斷 / 致死技能高亮）"
    t["CFG_KT"] = "鑰匙時間軸（嗜血點預告 + Boss 節奏對比頂尖場次）"
    t["CFG_KT_D"] = "就是進本後螢幕中上那條進度條。指令：/gi kt off 關、/gi kt on 開。"
    t["CFG_KT_POS"] = "時間軸位置"
    t["CFG_KT_UNLOCK"] = "解鎖拖動"
    t["CFG_KT_LOCK"] = "鎖定"
    t["CFG_KT_RESET"] = "復位"
    t["CFG_SEC_ALERT"] = "提醒與附加"
    t["CFG_WISH"] = "願望清單掉落提醒"
    t["CFG_WISH_D"] = "隊伍裡掉了你願望清單上的件時彈窗提醒。"
    t["CFG_META"] = "鑰石視窗旁附帶大秘境情報"
    t["CFG_META_D"] = "開啟鑰石介面時，旁邊貼一塊本週強勢職業 / 副本參與度。"
    t["CFG_SEC_MAIN"] = "主面板"
    t["CFG_SCALE"] = "面板縮放"
    t["CFG_USAGE"] = "使用率參照"
    t["CFG_USAGE_D"] = "畢業件排序、使用率、刷取規劃都跟著這個口徑走。"
    t["CFG_USAGE_RAID"] = "團本頂尖玩家"
    t["CFG_USAGE_MPLUS"] = "大秘境頂尖玩家"
    t["CFG_EXRAID"] = "團本裝備：排除（只推大秘境能拿的）"
    t["CFG_RESETPOS"] = "復位所有視窗位置"
    t["CFG_RESETPOS_BTN"] = "復位"
    t["CFG_RESETPOS_DONE"] = "視窗位置已復位，/reload 後生效。"
    t["DM_DISMISSED"] = "副本助手保持關閉。想用時：/gi config 或 ESC → 選項 → 插件 → GearInsight 裡開啟。"
    t["DM_DISABLED"] = "副本助手已關閉，之後不再載入、不佔記憶體。想用時：/gi config 或 ESC → 選項 → 插件 → GearInsight 裡開啟。"
end
do
    -- 裝備圖（ui/GearMap.lua，2026-09-05）
    local t = GearInsight.LOC.zhTW
    t["GM_TITLE"] = "裝備圖"
    t["GM_TOGGLE_LIST"] = "列表"
    t["GM_TOGGLE_MAP"] = "裝備圖"
    t["GM_TOGGLE_TIP"] = "裝備圖 = 按角色面板欄位排布，箭頭指向該換的 BiS 件，小格是寶石/附魔到位情況。\n列表 = 舊版逐條列出（過渡保留）。"
    t["GM_CLICK_TOP5"] = "點選：該部位使用率前5"
    t["GM_RCLICK_SRC"] = "右鍵：來源 / 套裝坯子"
    t["GM_DONE"] = "已畢業"
    t["GM_UPGRADE"] = "待提升 → "
    t["GM_GEM_NOSOCKET"] = "這件沒有插槽"
    t["GM_GEM_EMPTY"] = "有空插槽！推薦鑲："
    t["GM_GEM_OK"] = "已鑲推薦寶石"
    t["GM_GEM_OTHER"] = "鑲了非推薦寶石，推薦："
    t["GM_ENCH_TITLE"] = "附魔"
    t["GM_ENCH_MISSING"] = "沒有附魔！"
    t["GM_RECOMMEND"] = "推薦："
    t["GM_ENCH_OK"] = "已附推薦附魔"
    t["GM_ENCH_OTHER"] = "附了非推薦附魔，推薦："
    t["GM_SUMMARY"] = "個部位已畢業"
    t["GM_LEGEND"] = "小格 = 寶石 / 附魔：綠 已到位 · 黃 非推薦 · 紅 缺 · 灰 無\n點 BiS 件看前5，右鍵看來源/坯子"
end
do
    local t = GearInsight.LOC.zhTW
    t["GM_OH_NO_PLAN"] = "頂尖玩家主流形態不用副手（雙手武器），這一格沒有推薦"
    t["GM_NO_PLAN"] = "這一格暫無推薦資料"
end
do
    local t = GearInsight.LOC.zhTW
    t["GM_GEM_NOSOCKET2"] = "這件還沒打孔（本賽季該部位可鑲孔）"
    t["GM_MINI_CLICK"] = "左鍵：拍賣行開著就直接搜，否則發到聊天 · 右鍵：複製名字"
    t["GM_ACT_TOP5"] = "前5"
    t["GM_ACT_FILLER"] = "套裝坯子"
    t["GM_ACT_SRC"] = "來源"
end

-- 0.79.0 天赋页第四档 PvP（榜首配置 + 专属天赋）
do
    local t = GearInsight.LOC.zhTW
    t["TALENT_TIP"] = "WCL 頂尖玩家天賦(團本/衝分/割草 各前5名) + PvP 榜首配置與專屬天賦，選一套複製匯入串"
    t["PVP_MODE_SHUFFLE"] = "單人混戰"
    t["PVP_MODE_BLITZ"] = "戰場閃電戰"
    t["CONTENT_PVP"] = "PvP"
    t["PVP_TOP_N"] = "榜前 %d 名"
    t["PVP_SAMPLE_N"] = "樣本 %d 人"
    t["PVP_TAL_SRC"] = "暴雪官方榜"
    t["PVP_TAL_TIP"] = "資料來自暴雪官方 PvP 排行榜，逐人查檔案得來（不是 WCL）。這是上榜玩家實際點的，不是「最佳解」。"
    t["PVP_OWN_TAL"] = "專屬天賦（3 選）· 上榜玩家選擇率"
    t["PVP_OWN_LEGEND"] = "√ 你已選 · 橙字 = 多數人選了你沒選"
    t["PVP_COPY_TITLE"] = "PvP %s #%d"
    t["PVP_COPY_HINT"] = "Ctrl+C 複製 → 天賦面板「匯入」貼上。串裡不含 PvP 專屬 3 個，匯完去 PvP 天賦介面選："
    t["PVP_ROW_TIP"] = "%d 分 · 藍字英雄天賦 · 灰字是他自己的 PvP 專屬天賦（串裡不含）\n點擊複製 / 一鍵匯入天賦樹"
    t["PVP_IMPORT_NOTE"] = "點一行複製匯入串；串只含天賦樹，專屬 3 個要自己去 PvP 天賦介面選"
end
-- 0.79.0 PvP 档排版返修（2026-09-10 截图：三处换行互相压住）
do
    local t = GearInsight.LOC.zhTW
    t["PVP_OWN_TAL"] = "專屬天賦 · 上榜玩家選擇率"
    t["PVP_OWN_LEGEND2"] = "√ 已選"
    t["PVP_OWN_LEGEND"] = "PvP 專屬天賦（戰場/競技場裡額外的 3 個）。\n綠字√ = 你身上已選；橙字 = 半數以上上榜玩家選了、你沒選。"
    t["PVP_ROW_TIP2"] = "%d 分 · 藍字是英雄天賦\n他的 PvP 專屬：%s（串裡不含）\n點擊複製 / 一鍵匯入天賦樹"
    t["PVP_IMPORT_NOTE2"] = "點一行複製匯入串 · 專屬 3 個需在 PvP 天賦介面自選"
end
-- 0.79.0 PvP 榜首行悬浮带图标分行
do
    local t = GearInsight.LOC.zhTW
    t["PVP_RATING_FMT"] = "%d 分"
    t["PVP_TIP_HERO"] = "英雄天賦："
    t["PVP_TIP_OWN"] = "他的 PvP 專屬天賦"
    t["PVP_TIP_NOTIN"] = "（串裡不含，匯完自己選）"
    t["PVP_TIP_CLICK"] = "點擊：複製匯入串 / 一鍵匯入天賦樹"
end
-- 0.79.0 清理导入的天赋载入档（玩家反馈）
do
    local t = GearInsight.LOC.zhTW
    t["TAL_CLEAR_TIP"] = "刪除本插件匯入的全部載入檔（名字以 GI- 開頭）。\n你自己建的檔和正在用的檔不動。"
    t["TAL_CLEAR_BTN"] = "清理匯入檔 (%d)"
    t["TAL_CLEAR_NONE"] = "沒有本插件匯入的載入檔可清理。"
    t["TAL_CLEAR_MORE"] = " …等 %d 個"
    t["TAL_CLEAR_OK"] = "刪除"
    t["TAL_CLEAR_FAIL"] = "清理失敗："
    t["TAL_CLEAR_DONE"] = "已刪除 %d 個匯入的載入檔"
    t["TAL_CLEAR_LEFT"] = "回讀：還剩 %d 個匯入檔沒刪掉。若天賦面板有未套用的改動，先點「套用變更」再清理。"
    t["TAL_CLEAR_REFUSED"] = "被拒絕"
    t["TAL_CLEAR_PENDING"] = "伺服器未回包"
    t["TAL_CLEAR_LEFT2"] = "回讀：還剩 %d 個匯入檔：%s。「伺服器未回包」= 稍等再看下拉；「被拒絕」= 先點「套用變更」再清理。"
    t["TAL_CLEAR_REFUSED2"] = "遊戲拒絕刪除 %d 個：%s —— 伺服器一次只處理一個，稍等幾秒再點一次清理即可。"
    t["TAL_CLEAR_SKIP"] = "（正在用的那份沒動）"
    t["TAL_CLEAR_ASK"] = "刪除本插件匯入的 %d 個天賦載入檔？\n%s%s\n\n你自己建的檔和正在用的檔不會動。"
end
-- 0.80.0 PvP 装备参照（ui/PvpGearView.lua）
do
    local t = GearInsight.LOC.zhTW
    t["USAGE_PVP"] = "PvP"
    t["USAGE_TIP2"] = "使用率% = 頂尖玩家實戰配裝的集成統計\n\n團本 — 統計團本頂尖玩家的裝備\n大秘境 — 統計大秘境頂尖玩家的裝備\nPvP — 單人混戰上榜玩家每部位買的副屬性版本（換一張專用表）\n\n點擊循環切換"
    t["PVPG_TITLE"] = "PvP 裝備參照"
    t["PVPG_NODATA"] = "當前專精暫無 PvP 裝備資料（切到對應專精了嗎？）"
    t["PVPG_SAMPLE"] = "樣本 %d 人 · 分數中位 %d"
    t["PVPG_SEC"] = "副屬性分布："
    t["PVPG_LEGEND"] = "√ 身上這件一致 · × 不一致 · 同組合優先買征服版本"
    t["PVPG_COL_SLOT"] = "部位"
    t["PVPG_COL_HEAD"] = "推薦副屬性 · 上榜占比 · 你身上 · 來源"
    t["PVPG_TIP_NOTE"] = "上榜玩家實際穿的；同組合的征服版本比榮譽版本高一檔"
    t["PVPG_TRINKETS"] = "飾品："
    t["PVPG_GEMS"] = "寶石："
    t["PVPG_ENCH"] = "附魔："
    t["PVPG_SET"] = "套裝："
    t["PVPG_SET_FMT"] = "%s · 4 件套只有 %.0f%% 的人湊齊 —— 多數人只拿 2 件挑屬性"
    t["PVPG_LOWSAMPLE"] = "! 這個專精上榜玩家分數中位只有 %d，樣本品質低，僅供參考"
    t["PVPG_LEGEND2"] = "征服裝實例內 344 · 榮譽裝 331 · 套裝件走催化"
    t["MT_TAB_PVP_TITLE"] = "PvP 裝備 · 上榜玩家怎麼穿"
    t["PVPG_COL_HEAD2"] = "推薦裝備（優先征服版）· 副屬性 · 上榜占比 · 你身上 · 來源"
    t["PVPG_TIP_ILVL"] = "實例 PvP 內物品等級：%d"
    t["OIL_IMBUE_NOTE"] = "該專精用職業自帶武器附魔：%s，不用油"
    t["PVPG_TIP_WORN"] = "上榜玩家穿的這件：物品等級 %d"
    t["PVPG_TIP_PVPLV"] = " · 實例 PvP 內 %d"
    t["PVPG_TIP_WORLD"] = "野外"
    t["PVPG_TIP_WORN2"] = "上榜玩家穿的這件：野外 %d · 實例 PvP 內 %d"
    t["PVPG_LEGEND3"] = "[身上]→[推薦]  藍字 = 實例 PvP 內裝等 · 綠框√ 副屬性一致 · 橙框× 不一致"
    t["PVPG_PREP"] = "其他準備"
    t["PVPG_PREP_HINT"] = "懸浮看屬性 · 左鍵拍賣行搜 · 右鍵複製名"
    t["PVPG_GEM_N"] = "上榜玩家鑲了 %d 顆"
    t["PVPG_PREP_TAL"] = "PvP 天賦"
    t["PVPG_PREP_TAL_TXT"] = "天賦頁第四檔「PvP」—— 榜首匯入串 + 專屬天賦選擇率"
    t["PVPG_PREP_TAL_CLICK"] = "點擊打開天賦頁"
    t["PVPG_PREP_CONS"] = "消耗品"
    t["PVPG_PREP_CONS_TXT"] = "合劑 / 藥水 / 食物 / 武器油同 PvE，看裝備總覽底部"
    t["PVPG_PREP_CONS_CLICK"] = "點擊回裝備總覽看消耗品欄"
    t["PVPG_MINI_OK"] = "已到位"
    t["PVPG_MINI_OTHER"] = "身上是別的"
    t["PVPG_MINI_NONE"] = "身上沒附"
    t["PVPG_MINI_NONE2"] = "身上沒鑲"
    t["PVPG_LEGEND4"] = "[身上]→[推薦][附魔/寶石小格]  藍字 = 實例 PvP 內裝等 · 綠框 一致/已到位 · 橙 不一致 · 紅 缺"
    t["PVPG_STAT_HINT"] = "屬性達成度 · 目標 = 上榜玩家占比 × 你身上的副屬性總量"
    t["TIER_STATFIT_LOW"] = "副屬性契合 %d%%"
    t["TIER_REFARM_FILLER"] = "重刷 %s 坯子再轉"
    t["GM_TIER_WRONGSTAT"] = "這件套裝是屬性不對的坯子轉的 → 重刷對屬性的坯子再轉"
    t["TV_NO_API"] = "天賦 API 不可用"
    t["TV_NO_CFG"] = "取不到啟用的天賦配置（切到該專精了嗎？）"
    t["TV_NO_TREE"] = "找不到天賦樹"
    t["TV_BAD_STR"] = "匯入串裡有非法字元"
    t["TV_SHORT"] = "匯入串太短，和這棵樹對不上（版本不同？）"
    t["TV_CLASS"] = "職業天賦"
    t["TV_HERO"] = "英雄天賦"
    t["TV_SPEC"] = "專精天賦"
    t["TV_LEGEND"] = "金框 = 這套點了 · 灰框 = 系統贈送 · 暗 = 沒點   |cFF40FF40綠框|r 要補  |cFFFF5555紅框|r 要退  |cFFFFCC33黃框|r 選法/點數不同"
    t["TV_DIFF_TOGGLE"] = "與我身上對比"
    t["TV_COPY"] = "複製匯入串"
    t["TV_TITLE"] = "天賦樹預覽"
    t["TV_WRONG_SPEC"] = "這套是別的專精的（specID %d，你現在是 %d）—— 切到那個專精再看"
    t["TV_DIFF_ADD"] = "這套點了，你沒點 → 要補"
    t["TV_DIFF_REMOVE"] = "你點了，這套沒點 → 要退"
    t["TV_DIFF_CHOICE"] = "二選一選的不一樣 → 換成這個"
    t["TV_DIFF_RANK"] = "點數不同：你 %d / 這套 %d"
    t["TV_SAME"] = "和你身上完全一樣"
    t["TV_DIFF_SUM"] = "與你身上：|cFF40FF40補 %d|r · |cFFFF5555退 %d|r · |cFFFFCC33改 %d|r"
    t["TV_MINE"] = "我目前的天賦"
    t["TV_OPEN_BTN"] = "查看天賦樹"
    t["WP_TAG"] = "[GearInsight外掛]"
    t["WP_EDIT_TAGNOTE"] = "開頭的「[GearInsight外掛]」是固定的，不可改、也不用寫。"
    t["TIER_RAID_DIRECT"] = "團本直掉"
    t["TIER_SELF_TAG"] = "本體·團本直掉，原生屬性"
    t["MT_MORE_TITLE"] = "更多功能在站外"
    t["MT_MORE_COPY"] = "Ctrl+C 複製，到瀏覽器打開"
    t["MT_MORE_CLICK"] = "點擊複製網址"
    t["MT_MORE_SITE"] = "網站"
    t["MT_MORE_SITE_HINT"] = "大秘境 / PvP 情報榜 · 裝備分析 · 天賦視圖 · 更新日誌"
    t["MT_MORE_MP"] = "微信小程式"
    t["MT_MORE_MP_NAME"] = "微信搜「GearInsight」"
    t["MT_MORE_MP_HINT"] = "手機上查 BiS / 掉落 / PvP 裝備，隨時看"
    t["TRACK_MAXED"] = "%s %d/%d 已封頂"
    t["TRACK_REFARM_TIER"] = "換更高軌道的坯子再轉"
    t["TRACK_REFARM"] = "要更高軌道的同款"
    t["GM_TRACK_MAXED"] = "%s %d/%d 已封頂，這條軌道到不了 %d → 換更高軌道的同款 / 坯子"
    t["FG_GRID_CLICK"] = "點擊打開地下城手冊 · Shift+點擊 發到聊天"
    t["FG_GRID_FILLER"] = "坯"
    t["FG_GRID_FILLER_TIP"] = "拿到後催化轉換成套裝件"
    t["FG_GRID_MISSING"] = "缺"
    t["FG_GRID_TIERGRP"] = "套裝 · 催化"
    t["MT_TAB_WISH_TITLE"] = "刷本規劃 · 缺什麼、去哪刷"
    t["WLP_INTRO2"] = "缺的裝備按副本排好、去哪刷一眼看清；隊伍裡掉到你能提升的部位會彈框提醒，可一鍵密語問要。清單跟著你的裝備走。"
    t["WLP_VIEW_SRC"] = "檢視: 按副本"
    t["WLP_VIEW_SLOT"] = "檢視: 按部位"
    t["MT_CAP_FARM2"] = "已併入左側「刷本規劃」頁籤，點此跳過去"
    t["FG_TP_TIP"] = "點擊傳送到副本門口"
    t["FG_TP_UNKNOWN"] = "還沒學會這個傳送（限時通關一次即可解鎖）"
    t["FG_LFG_RAID"] = "打開組隊工具，搜這個團本（預設英雄難度）"
    t["FG_LFG_MPLUS"] = "打開組隊工具，搜這個副本的隊伍"
    t["FG_LFG_RAID2"] = "打開組隊工具，搜這個團本的隊伍 · "
    t["FG_LFG_DIFF_HINT"] = "難度在「團本」標題右側切換"
    t["FG_DIFF_TIP"] = "組隊工具搜團本時用哪個難度（打不了傳奇就選英雄）"
    t["FG_DIFF_LBL"] = "組隊工具: "
    t["WLP_EXRAID_TIP"] = "不打團本就點「排除」：清單裡只留大秘境 / 製造等非團本來源。\n與裝備總覽頁的開關是同一個。"
    t["WLP_TIER_TIP"] = "團本裝備按哪個難度算目標裝等：傳奇 / 英雄 / 普通。打不了傳奇就切英雄，缺件和裝等差距都按英雄檔算。\n與設定頁的「參照難度檔」是同一個開關。"
    t["WLP_TIER_LBL"] = "團本難度: "
    t["WLP_SPECS_LBL"] = "一起刷的專精:"
    t["WLP_SPEC_CUR"] = "目前"
    t["WLP_SPEC_CUR_TIP"] = "目前專精，總是包含在內。"
    t["WLP_SPEC_TIP"] = "點一下把這個專精的缺件也合進來一起刷：同一個副本掉的件按專精合併，格子右下角的小圖示標出誰要它。\n副專精的件在背包裡也算已獲得。"
    t["FG_GRID_SPECS"] = "需要這件的專精: "
    t["FG_LFG_ERR"] = "[組隊工具] 出錯："
    t["FG_REDRAW_ERR"] = "[刷本助手] 重繪出錯："
    t["FG_LFG_NONAME"] = "取不到副本名"
    t["FG_LFG_NOFRAME"] = "打不開預組隊伍介面（PVEFrame_ShowFrame 缺失）"
    t["FG_LFG_NOPANEL"] = "LFGListFrame.SearchPanel 不存在，這版客戶端介面結構變了"
    t["FG_LFG_SETACT_ERR"] = "SetSearchToActivity 失敗："
    t["FG_LFG_NOACT"] = "沒找到「%s」對應的活動，已打開搜尋頁，請手動輸入"
    t["FG_LFG_SEARCH_ERR"] = "搜尋失敗："
    t["FG_LFG_NOSEARCH"] = "搜尋沒發出去（已切到搜尋頁並填好副本，手點一下搜尋）"
    t["OV_REFRESH_ERR"] = "面板重新整理出錯：副本 / 戰鬥裡部分資料讀不到，出本後點「重新整理資料」再試"
    t["OV_REFRESH_ERR_CHAT"] = "[總覽] 重新整理出錯："
    t["TOP5_REC_TAG"] = "目前推薦 · 過濾後 #%d"
    t["TOP5_REC_TAG0"] = "目前推薦"
    t["ROT_MY_NA_TIP"] = "副本裡客戶端不給增益資料，測不到；去木樁打一會兒學到持續時間後，副本裡會按施法次數估算（標 ≈）。"
    t["WA_FILLER_WHY"] = "套裝坯子 #%d/%d → 轉 %s"
    t["TTSRC_CRAFTED2"] = "製造業 · 拍賣場搜不到，找對應專業玩家下工藝訂單（自備火花+材料）"
    t["WLP_EXRAID_TIP2"] = "不打團本就點「排除」：清單裡只留大秘境 / 製造等非團本來源。\n只影響本頁，不動裝備總覽的設定。"
    t["WLP_TIER_TIP2"] = "團本裝備按哪個難度算目標裝等：傳奇 / 英雄 / 普通。打不了傳奇就切英雄，缺件和裝等差距都按英雄檔算。\n只影響本頁，不動設定頁的「參照難度檔」。"
    t["TIER_BTN_LBL"] = "參照檔: "
    t["TIER_BTN_TIP"] = "BiS 參照難度檔：傳奇（預設，頂尖玩家原始資料）/ 英雄 / 普通。\n切到英雄或普通後，團本和套裝件的目標裝等按該檔換算（每檔 -13），畢業判定跟著變，傳奇鑰石件不變。\n也可用 /gi tier m|h|n。"
    t["MT_TAB_CODEX_TITLE"] = "萬奧寶典 · 頂尖玩家怎麼選"
    t["MT_TAB_CODEX"] = "萬奧寶典"
    t["CX_APPLY"] = "一鍵換成推薦"
    t["CX_APPLY_TIP"] = "把與推薦不同的行改成頂尖玩家最多選的那枚，然後提交。\n改不了（戰鬥中 / 客戶端不允許）會在聊天框說明，請到萬奧寶典介面手動改。"
    t["CX_SCENE_RAID"] = "樣本: 團本"
    t["CX_SCENE_MPLUS"] = "樣本: 傳奇鑰石"
    t["CX_NODATA_FILE"] = "缺少資料檔 core/CodexData.lua"
    t["CX_NODATA"] = "目前專精暫無頂尖玩家樣本（資料每週隨 WCL 更新）。下面只顯示你目前的選擇。"
    t["CX_SUB"] = "WCL 頂尖玩家 %s 樣本 %d 人各行怎麼選。★ 推薦 = 選的人最多；√ = 你現在選的。懸浮看效果。"
    t["CX_RAID"] = "團本"
    t["CX_MPLUS"] = "傳奇鑰石"
    t["CX_NOTREE"] = "（讀不到寶典樹：可能還沒解鎖，或需要先打開一次寶典介面）"
    t["CX_PCT_NONE"] = "無樣本"
    t["CX_TIP_PCT"] = "頂尖玩家 %.0f%% 選它"
    t["CX_TIP_CUR"] = "你目前選的"
    t["CX_UNPICKED"] = "未選"
    t["CX_ROW"] = "第"
    t["CX_ROW_SUF"] = "行"
    t["CX_FOOT_SAME"] = "你的選擇已與推薦一致。"
    t["CX_FOOT_DIFF"] = "有 %d 行與推薦不同（橘色）。"
    t["CX_INCOMBAT"] = "戰鬥中不能改萬奧寶典。"
    t["CX_APPLIED"] = "萬奧寶典已改 %d 行並提交。"
    t["CX_COMMIT_FAIL"] = "選擇已改但提交失敗：請打開萬奧寶典介面確認/提交，或到寶典處再試。"
    t["CX_SET_FAIL"] = "第 %s 行改不了（客戶端不允許在此改，或行未解鎖）。"
    t["CX_FEW"] = "樣本少，僅供參考"
    t["CX_CURRENCY"] = "萬奧洞悉微粒：已用 %d，手上 %d（每週 1 顆，脫戰可隨時換）"
    t["CX_R1"] = "核心 · 觸發傷害/治療"
    t["CX_R2"] = "生存"
    t["CX_R3"] = "縈繞"
    t["CX_R4"] = "副屬性"
    t["CX_R5"] = "觸發效果"
    t["CX_REC_IS"] = "推薦"
    t["CX_SWITCH_TO"] = "建議換成"
    t["CX_ON_REC"] = "已是推薦"
    t["CX_OPEN"] = "打開萬奧寶典"
    t["CX_OPEN_TIP"] = "施放技能書裡的「萬奧寶典」，打開遊戲自帶的寶典介面（戰鬥中不可用）。"
    t["CX_OPEN_TIP2"] = "打開遊戲自帶的萬奧寶典介面，在那裡換符文；再點一次關閉。"
    t["CX_OPEN_FAIL"] = "打不開寶典介面："
    t["CX_HOWTO"] = "怎麼解鎖?"
    t["CX_HOWTO_TITLE"] = "萬奧寶典解鎖與每週進度"
    t["CX_HOWTO_TXT"] = "解鎖：80 級後到銀月城「戰場榮譽軍需官」處接《魔導師的信》開啟任務線，跟大魔導師羅曼斯、魔導師烏布里克在永歌森林修復逐日者萬奧樞紐，做完《萬奧甦醒》即拿到寶典並解鎖第 1 行。\n之後每週在逐日者萬奧樞紐（秘法殿）接週常「求知若渴」，做完得 1 顆萬奧洞悉微粒，每顆解鎖一行（共 5 週）：\n第 2 週 儀式奧術 ×8（儀式場所）· 第 3 週 暗影地脈凝結 ×5（虛空入侵）· 第 4 週 純淨原能 ×1（地下堡/地城/團本/寶箱）· 第 5 週 異界魔法碎片（對決世界首領）+ 3 個世界任務。\n帳號裡一個角色做過，其他角色自動拿到微粒；12.1 起小號可跳過前置劇情。寶典介面從地圖打開（或本頁「打開萬奧寶典」），脫戰隨時換。"
    t["MT_SUB_TAL"] = "天賦庫"
    t["FG_TIER_HDR"] = "套裝 4 件套：已有 %d/%d · 還差 %d 件"
    t["FG_GRID_OPTIONAL"] = "選"
    t["FG_OPTIONAL_TAG"] = "(可選)"
    t["FG_OPTIONAL_TIP"] = "這個部位頂尖玩家多用 %s；4 件套湊不夠時再用套裝件補"
    t["SUP_COL_TOP"] = "金額最高 10 人"
    t["SUP_COL_SINCE_VIDEO"] = "最近支持者"
    t["SUP_COL_RECENT"] = "最近 10 筆"
    t["SUP_FULL_LIST"] = "完整名單與統計在網站："
    t["SUP_CLICK_COPY"] = "（點擊複製）"
    t["MT_TAB_NEWS"] = "資訊"
    t["MT_TAB_NEWS_TITLE"] = "資訊 · 更新 / 版本 / 趨勢 / 關注"
    t["NW_NODATA"] = "缺少資料檔 core/NewsData.lua"
    t["NW_SEC_REL"] = "外掛更新 · 最新 3 版"
    t["NW_SEC_PATCH"] = "遊戲版本 · 最近 3 次熱修"
    t["NW_SEC_TIER"] = "資料趨勢 · 強度榜"
    t["NW_TIER_BASIS"] = "傳奇鑰石高層 · "
    t["NW_TIER_MORE"] = "完整 S–D 榜與治療 / 坦克口徑見網站 · 強度榜（攻略頁有地址）"
    t["NW_SEC_FOLLOW"] = "關注 · 更新第一時間到"
    t["NW_CN"] = "國內"
    t["NW_INTL"] = "海外"
    t["NW_COPY_HINT"] = "Ctrl+C 複製，去對應 App 搜尋 / 打開"
    t["NW_CLICK_COPY"] = "點擊複製"
    t["NW_SEC_CH"] = "頻道"
    t["NW_FOOT"] = "資料隨外掛版本一起更新 · 點行可複製帳號"
    t["SUP_CTA"] = "❤ 去支持 / 上榜登記（點擊複製網址）"
    t["SUP_CTA_TIP"] = "微信 / 支付寶 / Ko-fi 都在這一頁；登記後名字進榜，外掛下一版一起烤進來"
    t["SUP_FOOT2"] = "更新時間 %s（隨外掛版本一起更新）"
    t["NW_TIER_MORE2"] = "口徑：傳奇鑰石高層日誌中位數，按角色定位內第一名切檔；治療 / 坦克以輸出粗排僅供參考。網站 · 強度榜可看具體數值"
    t["NW_RESET_THU"] = "每週四 0 點重置，累計不清零"
    t["SUP_CTA2"] = "去支持 / 上榜登記"
    t["NW_SOURCE"] = "來源"
    t["NW_TIER_NOTE"] = "↑↓ = 較上週名次變化；治療 / 坦克以輸出粗排僅供參考"
    t["NW_TIER_GO"] = "看完整數值與治療 / 坦克口徑"
    t["NW_TIER_GO_SUB"] = "（點擊複製網址，打開即綁定你的角色）"
    t["SUP_CTA_SUB"] = "（點擊複製網址，打開即綁定你的角色，登記時自動填好名字）"
    t["PVPG_FOOT"] = "資料：暴雪官方 PvP 排行榜逐人檔案；這是他們穿的，不是「最佳解」。"
end
-- 0.79.0 情报页 2026-09-10 整页下线；/gi meta 只指路
do
    local t = GearInsight.LOC.zhTW
    t["META_MOVED"] = "大秘境 / PvP 情報已移到網站：gearinsight.app（插件內不再顯示）"
end
-- 0.79.0 情报页合并（ui/IntelPage.lua）：大秘境 + PvP 一页内切换
do
    local t = GearInsight.LOC.zhTW
    t["MT_TAB_INTEL"] = "情報"
    t["IN_SEG_MM"] = "傳奇鑰石"
    t["IN_SEG_PVP"] = "PvP"
end

-- 0.90.5 美化材料 · 製作順序
do
    local t = GearInsight.LOC.zhTW
    t["FG_CRAFTED_NOTE2"] = "製造件本身拍賣場搜不到：買好美化材料，找對應專業下「工藝訂單」（自備火花）。僅列最值得做的 2 個部位；美化材料與製作順序見下"
    t["EMB_TITLE"] = "美化材料 · 製作順序"
    t["EMB_HINT"] = "材料拍賣場可買（最多 2 件美化生效） · 左鍵搜拍賣場 · 右鍵複製"
    t["EMB_USE_LBL"] = "用在: "
    t["EMB_USE_STONE"] = "武器 / 主手"
    t["EMB_USE_LINING"] = "護腕 · 盾 · 披風"
    t["EMB_USE_SIGIL"] = "武器備選（與儀式石差距不大）"
    t["EMB_ROUTE_SHIELD"] = "你是主手 + 盾牌："
    t["EMB_ROUTE_2H"] = "你是雙手武器（雙持按此參考）："
    t["EMB_STEP_MH_SHIELD"] = "① 主手 → 「%s」；盾牌 → 「%s」，雙美化達成（護腕跳過）"
    t["EMB_STEP_2H"] = "① 武器 → 「%s」（狩獵符印也行，差距不大）"
    t["EMB_STEP_WRIST"] = "② 護腕 → 「%s」，至此雙美化達成"
    t["EMB_STEP_RING"] = "③ 傳奇鑰石刷不到那種屬性組合的戒指 / 項鍊（先對照掉落表）"
    t["EMB_STEP_CLOAK"] = "④ 披風 → 「%s」：開出傳奇武器換掉製造武器後少一個美化，用披風補回（傳奇武器 > 製造武器）"
    t["EMB_STEP_BELT"] = "⑤ 傳奇鑰石刷不到那種屬性組合的腰帶 / 鞋子 —— 先看英雄團本後 2 個 BOSS 掉不掉，別浪費火花"
    t["EMB_STEP_FREE"] = "⑥ 隨意"
end

-- 0.90.5 角色面板：同一件、装等没到 → 向上箭头
do
    local t = GearInsight.LOC.zhTW
    t["PDB_UP_TRACKMAX"] = "件對了，但這條軌道 %s 已封頂（%d）—— 要換更高軌道的同款，目標裝等 %d"
    t["PDB_UP_ILVL"] = "件對了，裝等還差：%d → %d，升級或拿更高難度版本"
end

-- 0.90.6 翹課頁
do
    local t = GearInsight.LOC.zhTW
    t["MT_TAB_CHEESE"] = "翹課"
    t["MT_TAB_CHEESE_TITLE"] = "翹課 · 本週省事清單"
    t["CH_SUB"] = "本週省事清單：每條按步驟走，帶座標的點「標記」就在螢幕上出箭頭（暴雪原生路點，不用裝插件；裝了 TomTom 會一起加）。"
    t["CH_TOMTOM_ON"] = "已偵測到 TomTom"
    t["CH_UPDATED"] = "更新 %s · %s"
    t["CH_NODATA"] = "缺少資料檔 core/CheeseData.lua"
    t["CH_MARK"] = "標記"
    t["CH_MARK_TIP"] = "在地圖上打點並開啟超級追蹤；裝了 TomTom 會同時加 TomTom 路點"
    t["CH_WAY"] = "複製 /way"
    t["CH_WAY_HINT"] = "Ctrl+C 複製 → 聊天框貼上回車（TomTom / 其它 /way 插件通用）"
    t["CH_WAY_TIP"] = "給用別的定位插件的人：/way #地圖ID x y"
    t["CH_WP_OK"] = "已標記 %s %.1f / %.1f（螢幕上跟著箭頭走；Shift+點小地圖圖釘可取消）"
    t["CH_WP_FAIL"] = "這個客戶端不支援打點"
    t["CH_NO_MAP"] = "認不出這張地圖（版本變了？）"
    t["CH_SRC"] = "來源：%s @%s · %s"
end

-- 0.90.6 資訊頁：翹課置頂 + 更新日誌彈窗
do
    local t = GearInsight.LOC.zhTW
    t["NW_SEC_CHEESE"] = "翹課 · 本週省事清單"
    t["NW_CHEESE_TIP"] = "%d 個座標 · 點開彈窗一鍵標記"
    t["NW_CHEESE_N"] = "%d 座標"
    t["NW_REL_TIP"] = "%d 條改動 · 點開看全部"
    t["NW_REL_N"] = "%d 條"
end

do
    local t = GearInsight.LOC.zhTW
    t["NW_SEC_CHEESE"] = "翹課 · 今日省事清單"
    t["MT_TAB_CHEESE_TITLE"] = "翹課 · 今日省事清單"
    t["CH_SUB"] = "今日省事清單：每條按步驟走，帶座標的點「標記」就在螢幕上出箭頭（暴雪原生路點，不用裝插件；裝了 TomTom 會一起加）。"
    t["CH_TODAY"] = "今日"
    t["CH_RESET_RULE"] = "遊戲日以北京時間 07:00 為界"
    t["CH_STALE"] = "今天（%s）的還沒整理 —— 每天 07:00 更新後寫；舊的不展示，免得按舊座標白跑。"
end

do
    local t = GearInsight.LOC.zhTW
    t["NW_CHEESE_DAILY"] = "翹課每日更新，注意每次上線前更新插件"
end

do
    local t = GearInsight.LOC.zhTW
    t["ROT_MODE_HINT_BOSS"] = "← 左鍵下一隻 BOSS / 大秘境，右鍵上一隻（各 BOSS 循環差異很大）"
end

