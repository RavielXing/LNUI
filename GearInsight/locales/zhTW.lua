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
    TALENT_IMPORT_OK2  = "已匯入「%s」，正在自動套用…",
    TALENT_APPLY_DONE  = "天賦已套用：%s",
    TALENT_APPLY_FAIL  = "天賦未自動套用：",
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
    DG_POOL_DONE       = "▸ 本圖已到手畢業件 %d 件 |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t",
    DG_POOL_ALLDONE    = "本圖對你已無可刷裝備，畢業件已全部到手 |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t",
    DG_TAG_NEED        = "[缺·優先R]",
    DG_TAG_UP          = "[↑%d]",
    DG_SLOT            = "槽",
    DG_POOL_NONE       = "本圖無你的 BiS 相關掉落（你的畢業件主要來自團本/套裝）",
    DG_POOL_SUMMARY2   = "本圖相關 %d 件 · 畢業缺 %d · 可升級 %d · 已有 %d",
    DG_POOL_SIDE       = "▸ 其它 BiS 候選 %d 件（當前非升級）",
    DG_POOL_DONE2      = "▸ 本圖已到手 %d 件 |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t",
    IB_LOADING         = "GearInsight：讀取裝備中…",
    IB_LINE            = "GearInsight：BiS 畢業 %d/%d · 缺 %d 件",
    IB_ALLDONE         = "GearInsight：BiS 全部畢業 (%d/%d) |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t",
    IB_TOGGLE_ON       = "組隊懸停 BiS 畢業度：已開啟",
    IB_TOGGLE_OFF      = "組隊懸停 BiS 畢業度：已關閉",
    GB_TITLE           = "團隊 BiS 體檢",
    GB_REFRESH         = "刷新",
    GB_RANGE           = "範圍外",
    GB_LOADING         = "讀取中…",
    GB_NODATA          = "無 BiS 資料",
    GB_NOENCH          = "缺附魔×%d",
    GB_EMPTYSOCK       = "空孔×%d",
    GB_READY           = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t 準備就緒",
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
    EXRAID_TIP         = "是否把團本掉落納入推薦。\n排除 = 只推薦大秘境/製造等非團本來源（不打團本的獨狼玩家用，套裝坯子仍保留）\n包含 = 推薦含團本掉落",
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
    ACCOUNT_SET        = "帳號串已綁定：",
    ACCOUNT_CLEAR_HINT = "解除：/gi account clear",
    ACCOUNT_LOCKED     = "帳號串已綁定，不可更改。如確需更換請在網站「帳號」頁面申請。",
    ACCOUNT_LOCKED_HINT = "綁定後不可更改。",
    ACCOUNT_NONE       = "尚未綁定帳號串。網站右上角角色選單 →「插件帳號串」複製，貼到這裡：/gi account GIA1-…",
    ACCOUNT_CLEARED    = "帳號串已清除，之後的匯出串不再帶帳號。",
    ACCOUNT_OK         = "帳號串已綁定。之後 /gi export 的匯出串自動帶上你的帳號，匯出的角色就是你的。",
    ACCOUNT_BAD        = "帳號串格式不對，應以 GIA1- 開頭（從網站 / 小程式整行複製）。",
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
    TTUP_HINT_TIER     = "團本套裝兌換物或珍玩兌換，或同部位坯子催化轉換",
    TTUP_HINT_CRAFTED  = "用更高檔火花重下工藝訂單",
    TTUP_HINT_GENERIC  = "更高難度的同款",
    TTUP_DIFF_MYTHIC   = "史詩", TTUP_DIFF_HEROIC = "英雄", TTUP_DIFF_NORMAL = "普通",
    TTBIS_TIER_RANK    = "套裝本體（原生屬性）在坯子橫評中 #%d/%d",
    TTBIS_TIER_FROM    = "催化來的套裝（%s）= 坯子橫評 #%d/%d",
    TTBIS_FILLER_ONLY  = "套裝坯子 #%d/%d",
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
    FG_TRACK_CAPPED    = "這條軌道升滿也到不了，要重拿更高難度的同款",
    MISSING_TAG        = "  [缺少]",
    FILLER_TAG         = "（補位 / 轉換）",

    -- Tier filler popup
    TIER_POPUP_HINT    = "催化後物品等級、屬性類型和主次比例都沿用坯子；上方套裝提示僅是本體預設屬性",
    TTBIS_TIER_VARIANT = "推薦催化：%s → 單%s + %s（第三屬性以實際坯子為準）",
    TTBIS_TIER_EFFECT  = "繼承特效",
    BP_FILLER_VARIANT  = "推薦坯子：%s · 單%s + %s",
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
    TTBIS_CUR_MODE_FMT   = "%s %s BiS #%d / 共%d",
    TTBIS_OTHER_MODE_ENTRY_FMT = "%s %s %s #%d",
    TTBIS_SEASON_TAG        = "賽季 BiS 排名",
    TTBIS_USAGE_FMT      = "使用率 %.1f%%",
    TTBIS_USAGE_RAID     = "團本 %.1f%%",
    TTBIS_USAGE_MPLUS    = "大秘境 %.1f%%",
    TTBIS_USAGE_RAID_SHORT = "團 %.1f%%",
    TTBIS_USAGE_MPLUS_SHORT = "祕 %.1f%%",
    TTBIS_OTHER_LABEL    = "其他職業：",
    TTBIS_SAMECLASS_LABEL = "本職業其他專精：",
    TTBIS_OTHER_ENTRY_FMT = "%s %s#%d",
    TTBIS_OTHER_MORE_FMT = "等 %d 個專精",
    TTBIS_OTHER_SUMMARY  = "其他職業：另有 %d 個專精需要",
    TTUP_ILVL_COMPACT    = "裝等 %d → %d",
    TTUP_CANT_COMPACT    = "%s%d/%d 升滿 %d，需另取：%s",
    TTUP_CAN_COMPACT     = "%s%d/%d，可直接升到 %d",
    TTUP_UNKNOWN_COMPACT = "更高版本：%s",
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

-- 常規裝備 / 英雄樹循環 / 寶庫獎勵文案（0.94.2）
do
    local t = GearInsight.LOC["zhTW"]
    t["TIER_CONVERT_TO"] = "化生為："
    t["COMMON_BIS_BASIS"] = "+%d · 排名 %d–%d · %d 位角色\n按部位展示實穿比例，非模擬最優；戒指/飾品每人可貢獻兩件。"
    t["COMMON_BIS_EMPTY"] = "目前專精暫無常規裝備樣本，不使用高層資料替代。"
    t["COMMON_BIS_EXAMPLE"] = "展示一份真實穿戴樣本，不代表該物品所有裝等。"
    t["COMMON_BIS_TITLE"] = "常規 · 實戰裝備參考"
    t["HERO_ROT_BASIS"] = "目前英雄樹 · %d 份有效戰鬥\n施法頻率與覆蓋率是該場景實戰統計，不代表固定起手順序。"
    t["HERO_ROT_CPM"] = "%.1f 次/分"
    t["HERO_ROT_MISSING"] = "目前英雄樹在此場景樣本不足（%d/3），不套用另一英雄樹的資料。\n請切換具體場景；未提供混合樹的起手或 AI 解讀。"
    t["HERO_ROT_NODATA"] = "目前專精暫無按英雄樹拆分的循環資料，不使用混合流派替代。"
    t["HERO_ROT_TITLE"] = "目前英雄天賦 · 循環參考"
    t["RV_COIN_H_VAULT"] = "英雄用幣：神話 1/6 · 318 裝等；評分按升滿 334 比較"
    t["RV_COIN_M_VAULT"] = "史詩用幣：普通件 334；非常稀有及末兩首領 344（與寶庫一致）"
    t["RV_TT_COIN_VAULT"] = "本難度直接掉落 %d；用幣與寶庫同裝等：%d，升滿比較按 %d。\n上方是手冊原始物品連結，可能與用幣獎勵的裝等不同。"
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
    t["MT_TAB_TOOLS"] = "進階&攻略"
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
    t["ADV_IMPORT_OK"] = "已匯入 |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"
end
do
    local t = GearInsight.LOC.zhTW
    t["ADV_SCORE_HEAD"] = "WCL 實戰戰力（網站獨有）："
    t["ADV_SCORE_MED"] = "全 boss 中位 "
    t["ADV_COACH_HEAD"] = "AI 教練點評（網站獨有）："
end
do
    local t = GearInsight.LOC.zhTW
end
do
    local t = GearInsight.LOC.zhTW
    t["EXPORT_WEB_HINT2"] = "打開下面網址 → 貼上此字串，即出缺件清單 + 刷取順序"
    t["EXPORT_URL_TIP"] = "點擊網址全選 · Ctrl+C 複製"
end
do
    local t = GearInsight.LOC.zhTW
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
    t["SUP_FOOT"] = "更新時間 %s（隨插件版本一起更新）· 支持與登記：%s/wow/en/supporters"
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
    t["GM_NO_FILTER_PLAN"] = "保留目前裝備；這一格暫無符合篩選條件的推薦"
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
    t["PVP_OWN_LEGEND2"] = "√ 已選"
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
    t["WP_TAG"] = "[GearInsight插件]"
    t["WP_EDIT_TAGNOTE"] = "開頭的「[GearInsight插件]」是固定的，不可改、也不用寫。"
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
    t["SUP_N_TIPS"] = "%d筆"
    t["SUP_COL_SINCE_VIDEO"] = "最近支持者"
    t["SUP_COL_RECENT"] = "最近 10 筆"
    t["SUP_FULL_LIST"] = "完整名單與統計在網站："
    t["SUP_CLICK_COPY"] = "（點擊複製）"
    t["MT_TAB_NEWS"] = "資訊"
    t["MT_TAB_NEWS_TITLE"] = "資訊 · 更新 / 版本 / 趨勢 / 關注"
    t["NW_NODATA"] = "缺少資料檔 core/NewsData.lua"
    t["NW_SEC_REL"] = "插件更新 · 最新 3 版"
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
    t["NW_FOOT"] = "資料隨插件版本一起更新 · 點行可複製帳號"
    t["SUP_CTA"] = "❤ 去支持 / 上榜登記（點擊複製網址）"
    t["SUP_CTA_TIP"] = "微信 / 支付寶 / Ko-fi 都在這一頁；登記後名字進榜，插件下一版一起烤進來"
    t["SUP_FOOT2"] = "更新時間 %s（隨插件版本一起更新）"
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
    t["NW_EFF_SHORT"] = "本區伺服器 %s 維護後生效"
    t["NW_EFF_FULL"] = "生效：%s（%s，本區維護後）· 其他區服：%s"
    t["NW_EFF_TAG"] = "即將生效"
    t["PN_FOLD_TIP"] = "展開 / 收起整份清單"
    t["PN_META"] = "%d 波 · 頂尖 %d 局 +%d"
    t["PN_MODE_KEY"] = "鑰石"
    t["PN_MODE_MANUAL"] = "手動"
    t["PN_MODE_SIM"] = "模擬"
    t["PN_NEXT_TIP"] = "下一波（普通 / 追隨者副本沒有敵軍進度，手動翻）"
    t["PN_NO_DATA"] = "這個副本沒有拉怪清單資料（本賽季 8 本才有）。"
    t["PN_OFF"] = "領航已關閉（/gi nav on 開啟）"
    t["PN_SIM_OFF"] = "領航模擬已停止。"
    t["PN_SIM_ON"] = "領航模擬：按頂尖耗時的 1/8 速度自動推進（/gi nav sim 再按一次停止）"
    t["PN_STAGE"] = "第 %d / %d 波 · 進度 %.1f%% · %s"
    t["PN_TIP_CLICK"] = "點擊 = 把這一波設為目前"
    t["PN_TIP_HD"] = "第 %d 波 · %s · 頂尖 %ds · 支持率 %d%%"
    t["LY_MODE_ROT"] = "手法"
    t["LY_ROT_NOW_HD"] = "現在該按 · 暴雪官方循環助手（按你目前天賦）"
    t["LY_ROT_NOW_NOTE"] = "選中目標 / 進戰鬥後這裡跟著變；鍵 = 你條上綁的（黃字 = 還沒綁，顯示插件推薦）"
    t["LY_ROT_LIST_HD"] = "官方循環技能 · %d 個 · 格子下面是你的鍵"
    t["LY_ROT_OPEN_HD"] = "頂尖玩家真實起手 · WCL %s 前 %d 名 · 灰 = 你目前天賦沒這個技能"
    t["LY_ROT_RAID"] = "團本"
    t["LY_ROT_MPLUS"] = "傳奇鑰石"
    t["LY_ROT_COACH_HD"] = "教練解讀 · 本專精"
    t["LY_ROT_NO_API"] = "這個客戶端沒有官方循環助手介面（C_AssistedCombat），只顯示頂尖起手與教練解讀。"
    t["LY_ROT_NO_COACH"] = "本專精暫無教練解讀。"
    t["LY_ROT_NEXT_IDLE"] = "（無目標 / 未進戰鬥）"
    t["LY_KEYS_BAD"] = "這些鍵系統不認、沒綁上（點格子重新按一次）："
    t["LY_TB_RESET"] = "重來"
    t["LY_TB_NEXT"] = "助手"
    t["LY_TB_DONE"] = "起手打完 · 接主循環"
    t["LY_TB_TITLE_ASSIST"] = "暴雪循環助手"
    t["LY_ROT_PIN_ASSIST"] = "釘到螢幕 · 只看助手"
    t["LY_ROT_TAL_BTN"] = "切換成他的天賦"
    t["LY_ROT_TAL_OK"] = "已切換成 %s 的天賦（%s）"
    t["LY_ROT_TAL_FAIL"] = "切換天賦失敗："
    t["LY_ROT_TAL_TIP"] = "一鍵換成 %s 的天賦（英雄天賦 %s）· 以新天賦檔「GI 名字」匯入並套用，你原來的檔不動"
    t["LY_ROT_TAL_NONE"] = "天賦庫裡沒有這個人的 build（下次刷資料時補）"
    t["LY_ROT_PIN_BTN"] = "選擇這個序列"
    t["LY_ROT_NO_OPEN"] = "暫無資料"
    t["LY_ROT_ST_HD"] = "單體起手 · 團本頂尖 %d 人 · 灰 = 你目前天賦沒這個技能"
    t["LY_ROT_AOE_HD"] = "群怪起手 · 傳奇鑰石高層第一波 %d 人"
    t["LY_KEY_MOVED"] = "%s 原來指著格 %s，已挪到格 %s；格 %s 現在無快捷鍵（點它可再設）"
    t["LY_KEY_OCCUPIED"] = "%s 已被格 %s 使用；沒有改動。請先手動清空原來的格，再設定新鍵。"
    t["LY_KEY_REASSIGNED"] = "%s 已從格 %d 轉給格 %d；原格已置空，其他鍵未改。"
    t["LY_KEY_REASSIGNED_SPECIAL"] = "%s 已從格 %d 轉給系統功能；原格已置空，其他鍵未改。"
    t["LY_BADGE_TRINKET"] = "飾"
    t["LY_BADGE_POTION"] = "藥"
    t["LY_TB_IDLE"] = "選中可攻擊的目標後，這裡顯示該按什麼"
    t["MT_TAB_TOOLS_TITLE"] = "進階 & 攻略"
    t["LY_TB_TITLE"] = "GI 循環助手"
    t["LY_TB_RESET_TIP"] = "把起手序列撥回第 1 步（練起手用；脫戰 6 秒也會自動回到第 1 步）"
    t["LY_KB_BTN"] = "虛擬鍵盤"
    t["LY_KB_BTN_TIP"] = "開啟 / 關閉虛擬鍵盤：看每個鍵指向什麼、哪些和計畫不一致、WASD QE 是不是留給了移動"
    t["LY_KB_HD"] = "虛擬鍵盤 · 這一層的鍵都指向什麼"
    t["LY_KB_NOTE"] = "金框 = 計畫裡的格 · 紅角 = 現在綁的不一致 · 灰 = 留給移動 · 暗字 = 被別的功能佔著"
    t["LY_KB_MOD_NONE"] = "無修飾"
    t["LY_KB_PLAN"] = "計畫："
    t["LY_KB_NOW"] = "現在："
    t["LY_KB_FREE"] = "現在：空閒"
    t["LY_KB_CLICK"] = "點擊 = 給這一格改鍵"
    t["LY_KB_MOVE"] = "移動"
    t["LY_KB_FOOT"] = "點鍵帽 = 給那格改鍵；Shift / Ctrl / Alt 層切上面按鈕看。裸 WASD / 空白鍵留給移動，Q E 看「Q E 也參與分鍵」。"
    t["LY_KB_MACRO_NEW"] = "（還沒建：點「將插件建議實現到快捷列」時會建好放上去）"
    t["LY_SPECIAL_TOOK"] = "%s 原來指著格 %d，現在給了「%s」；格 %d 無快捷鍵"
    t["LY_SP_REPLY"] = "回覆密語"
    t["LY_SP_REPLY_TIP"] = "暴雪原生「回覆密語」：一鍵回覆最近一條私聊（預設 R）"
    t["LY_SP_PING"] = "信號"
    t["LY_SP_PING_TIP"] = "暴雪原生信號輪（Ping）：按住彈出，指路 / 集火 / 危險"
    t["LY_SP_HOW"] = "點一下再按新鍵；Backspace = 不綁；Esc 取消"
    t["LY_SP_HD"] = "系統 · 預設不設定，設了就進虛擬鍵盤"
    t["LY_SP_NOTE"] = "回覆密語 / 信號 / 焦點 / 協助 / 互動 / 標記 / 自動奔跑 / 寵物攻擊"
    t["LY_SP_UNSET"] = "未設定"
    t["LY_SP_OK"] = "已生效"
    t["LY_SP_DIFF"] = "和遊戲裡的不一致，點「將插件建議實現到快捷列」"
    t["LY_SP_GAME"] = "遊戲預設 %s · 沒被佔，保留"
    t["LY_SP_NONE"] = "遊戲裡也沒綁"
    t["LY_SP_REPLY_SHORT"] = "密語"
    t["LY_SP_PING_SHORT"] = "信號"
    t["LY_SP_FOCUS_TIP"] = "把目前目標設為焦點（打斷焦點、盯 BOSS 讀條都靠它）"
    t["LY_SP_FOCUS_SHORT"] = "設焦"
    t["LY_SP_TFOCUS_TIP"] = "選取焦點目標"
    t["LY_SP_TFOCUS_SHORT"] = "焦點"
    t["LY_SP_ASSIST_TIP"] = "選取「你的目標的目標」——跟坦克的集火目標"
    t["LY_SP_ASSIST_SHORT"] = "協助"
    t["LY_SP_INTERACT_TIP"] = "對目標按互動：撿東西、跟 NPC 對話、開門"
    t["LY_SP_INTERACT_SHORT"] = "互動"
    t["LY_SP_TAB_TIP"] = "預設 Tab"
    t["LY_SP_SKULL_TIP"] = "給目標打骷髏標記（主集火）"
    t["LY_SP_SKULL_SHORT"] = "骷髏"
    t["LY_SP_CROSS_TIP"] = "給目標打叉標記（次集火）"
    t["LY_SP_CROSS_SHORT"] = "叉"
    t["LY_SP_AUTORUN_TIP"] = "預設小鍵盤 Lock"
    t["LY_SP_AUTORUN_SHORT"] = "自跑"
    t["LY_SP_PET_TIP"] = "有寵物的職業：讓寵物打目前目標"
    t["LY_SP_PET_SHORT"] = "寵攻"
    t["LY_SP_TAKEN"] = "預設 %s 被格 %d 佔用 → 留空（想要就點左邊設一個）"
    t["LY_TB_CD"] = "冷卻"
    t["LY_TB_READY"] = "就緒"
    t["LY_ROT_TAL_OK2"] = "已切換成 %s 的天賦"
    t["LY_TB_CAP_ASSIST"] = "常規循環"
    t["LY_TB_CAP_SEQ"] = "起手序列"
    t["LY_TB_NOT_KNOWN"] = "你現在沒有這個技能（他的天賦點了、你沒點）。替換頁只列你會的技能，所以那裡看不到；點手法頁「切換成他的天賦」就有了。"
    t["LY_TB_NO_KEY"] = "你會這個技能，但它不在快捷列上，也沒綁鍵。去「鍵位手法 → 替換」把它放上去。"
    t["LY_TB_VIA_MACRO"] = "這個鍵按的是巨集「%s」，裡面包含它。"
    t["LY_TB_UNLEARNED"] = "未學"
    t["LY_TB_WINDOW"] = "第 %d–%d 步 / 共 %d"
    t["LY_BTN_KEYS_LIVE"] = "讀取遊戲目前鍵位"
    t["LY_KEYSLIVE_TT1"] = "讀取遊戲目前鍵位"
    t["LY_KEYSLIVE_TT2"] = "把面板重置成你遊戲裡現在真實綁著的鍵：「我的鍵位」快照改記實況，並清掉這個專精在面板上手動改過的鍵。\n在暴雪按鍵設定裡改完鍵、或者面板上改亂了想從頭來，點這個。"
    t["LY_KEYSLIVE_ASK"] = "把面板重置成遊戲裡現在真實綁著的鍵？\n這會清掉這個專精在面板上手動改過、還沒綁到遊戲裡的鍵。"
    t["LY_KEYSLIVE_DONE"] = "已按遊戲目前鍵位重置面板（%s）"
    t["LY_KEY_WHERE"] = "這個技能現在在："
    t["LY_KEY_WHERE_TIP"] = "（清空重鋪後才會挪到這格）"
    t["LY_KEY_WHERE_NONE"] = "這個技能現在不在任何列上"
    t["MB_TT_LEFT"] = "左鍵：開啟 / 關閉面板"
    t["MB_TT_RIGHT"] = "右鍵：重新整理資料"
    t["MB_CMD_HINT"] = "小地圖按鈕不見了：/gi minimap"
    t["LY_SP_RESTORE"] = "預設 %s 空出來了 · 點「實現到快捷列」自動還回去"
    t["LY_SP_RESTORED"] = "系統鍵還回預設："
    t["LY_TB_ENV"] = "這不是職業技能，是區域 / 活動 / 物品給的（頂尖玩家在團本裡按了）。不會進你的戰術板序列。"
    t["LY_ROT_SELECTED"] = "已選擇 · 戰術板在用這條"
    t["LY_ROT_TAL_ON"] = "天賦已切換"
    t["LY_ROT_PIN_ON"] = "已選擇"
    t["LY_TB_TRINKET"] = "這是你身上 %s 的主動技能（裝備欄 %d）。"
    t["LY_TB_TRINKET_NOKEY"] = "它不在列上：去替換頁把飾品格鋪上去就有鍵了"
    t["LY_ROLE_MENU_NA"] = "這個客戶端沒有選單介面"
    t["LY_ROLE_MENU_TITLE"] = "放到哪一列"
    t["LY_ROLE_SET"] = "%s → 「%s」列（右鍵可改回）"
    t["LY_ROLE_RESET"] = "恢復自動判斷"
    t["LY_ROLE_USER"] = "你手動指定的列"
    t["LY_ROLE_TT"] = "右鍵：把這個技能挪到別的職能列（分錯列了就自己改）"
    t["MT_LAYOUT_AUTO"] = "點頁籤自動載入此模組"
    t["MT_LAYOUT_AUTO_ON"] = "鍵位手法：以後點頁籤直接載入"
    t["MT_LAYOUT_AUTO_OFF"] = "鍵位手法：下次登入點頁籤會先問（本次已載入的不會卸掉，插件不能中途卸載）"
    t["MT_LAYOUT_AUTO_TT"] = "GearInsight_Layout 是按需載入的獨立模組。勾上 = 點頁籤直接載入；不勾 = 每次登入第一次點頁籤先問你。徹底不想要就在遊戲插件列表裡取消勾選它，本頁會尊重那個設定、不再替你啟用。"
    t["MT_LAYOUT_DISABLED"] = "「鍵位手法」模組（GearInsight_Layout）在你的插件列表裡是停用狀態，本頁不會替你啟用。\n要用：插件列表裡勾上它後 /reload，或點下面的按鈕（會啟用並載入）。"
    t["MT_LAYOUT_ENABLE_BTN"] = "啟用並載入（僅本角色）"
    t["MT_MOD_AUTO"] = "點頁籤自動載入此模組"
    t["MT_MOD_AUTO_ON"] = "以後點頁籤直接載入"
    t["MT_MOD_AUTO_OFF"] = "下次登入點頁籤會先問（本次已載入的不會卸掉，插件不能中途卸載）"
    t["MT_MOD_AUTO_TT"] = "%s 是按需載入的獨立模組。勾上 = 點頁籤直接載入；不勾 = 每次登入第一次點頁籤先問你。徹底不想要就在遊戲插件列表裡取消勾選它，本頁會尊重那個設定、不再替你啟用。"
    t["MT_MOD_DISABLED"] = "「%s」模組（%s）在你的插件列表裡是停用狀態，本頁不會替你啟用。\n要用：插件列表裡勾上它後 /reload，或點下面的按鈕（會啟用並載入）。"
    t["MT_MOD_ENABLE_BTN"] = "啟用並載入（僅本角色）"
    t["MT_MOD_LOAD_FAIL"] = "載入「%s」失敗：%s"
    t["MT_MOD_LOAD_FAIL2"] = "（插件列表裡有沒有它？）"
    t["MT_MOD_YES"] = "以後自動載入"
    t["MT_MOD_ONCE"] = "只這次載入"
    t["MT_MOD_NO"] = "不載入"
    t["MT_TAL_MOD_HINT"] = "「天賦」是獨立模組（GearInsight_Talents，約 6.5MB）：WCL 頂尖玩家天賦庫、一鍵匯入、萬奧寶典、PvP 天賦。\n預設不載入，不佔記憶體；點下面的按鈕載入，選「以後自動載入」就不再問。"
    t["MT_TAL_MOD_BTN"] = "載入天賦模組"
    t["MT_TAL_MOD_ASK"] = "要載入「天賦」模組嗎？\n\nWCL 頂尖玩家天賦庫 / 一鍵匯入 / 萬奧寶典。\n載入後本次登入一直在；選「以後自動載入」下次點頁籤直接開。"
    t["TALENT_LOD_DISABLED"] = "天賦庫模組（GearInsight_Talents）在插件列表裡是停用的；要用請在插件列表勾上後 /reload，或到面板「天賦」頁點「啟用並載入」。"
    t["DM_ENABLE_ASK"] = "副本助手模組（GearInsight_Dungeon）在插件列表裡是停用的。\n要現在啟用並載入嗎？（只對本角色；不想要就選「不用」）"
    t["DM_ENABLE_YES"] = "啟用並載入"
    t["DM_ENABLE_NO"] = "不用"
    t["DM_ENABLED_OK"] = "副本助手已啟用並載入。"
    t["LY_SEQ_MENU_JUMP"] = "跳到這一步（不改序列）"
t["LY_SEQ_MENU_RESTORE"] = "恢復這一步"
t["LY_SEQ_MENU_DEL"] = "刪掉這一步（這個序列會記住）"
t["LY_SEQ_DEL_MSG"] = "起手序列第 %d 步「%s」已刪掉；右鍵格子可恢復"
t["LY_SEQ_MENU_RESTORE_ALL"] = "恢復全部刪掉的步驟（%d）"
t["LY_SEQ_SKIPPED"] = "這一步你已刪掉（右鍵恢復）"
t["LY_SEQ_CELL_TIP_HUD"] = "左鍵：跳到這一步 · 右鍵：刪掉這一步"
t["LY_SEQ_CELL_TIP"] = "右鍵：刪掉這一步（釘板上就不再等它）"
t["LY_SEQ_OFF"] = "已刪"
t["LY_TB_SCALE"] = "大小"
t["LY_TB_SCALE_TIP"] = "Ctrl + 滾輪也能調"
t["LY_KEYS_MISS_FMT"] = "格%d 應 %s 實 %s%s"
t["LY_KEYS_MISS_HOLDER"] = "（%s 現在綁在「%s」）"
t["LY_KEYS_MISS"] = "這些格的鍵沒對上："
t["LY_SPECIAL_WINS"] = "%s：格 %d 讓給「%s」"
t["LY_KEYS_CONTENT_PLACED"] = "格子內容按計劃對齊：換了 %d 格"
t["LY_ASK_KEYS"] = "按右邊的方案實現到動作條：\n① 計劃裡每一格的內容對齊：技能 / 坐騎 / 飾品 / 藥水放進對應格，巨集（GI爆發巨集 / 保命巨集 / 勾選的巨集庫巨集）沒有的先建出來；計劃外的格不動（要清掉它們點「清空重鋪」）；\n② 主條 + 條2~條5 共 60 格按推薦鍵位重設綁定，之前佔用同一個鍵的功能會被挪走。\n（做之前會自動備份一份，含綁定，可一鍵還原）"
t["LY_USER_MACRO_TIP"] = "這格放的是你自己的巨集「%s」（裡面 /cast 了這個技能），鍵給巨集，不再單放技能"
t["LY_CDV_CB"] = "暴雪冷卻管理器圖示下印鍵帽 · 該按的加金框"
t["LY_CDV_TIP"] = "暴雪自帶「冷卻管理器」（編輯模式裡開）的每個圖示底下印你條上的鍵，暴雪循環助手說該按的那個加金框——看它就夠，釘板可以不開。"
t["LY_BOARD_CB"] = "螢幕上顯示 GI 循環助手（釘板）"
t["LY_BOARD_TIP"] = "關掉 = 釘板收起並記住，登入 / 換裝都不會自己冒出來；再勾回來原樣回來。沒選序列時只顯示「現在該按」。"
t["LY_POS_TOP"] = "上"
t["LY_POS_BOTTOM"] = "下"
t["LY_POS_LEFT"] = "左"
t["LY_POS_RIGHT"] = "右"
t["LY_POS_CENTER"] = "中"
t["LY_POS_TL"] = "左上"
t["LY_POS_TR"] = "右上"
t["LY_POS_BL"] = "左下"
t["LY_POS_BR"] = "右下"
t["LY_POS_BTN"] = "鍵帽位置：%s"
t["LY_POS_TITLE"] = "冷卻管理器圖示上的鍵帽放哪"
t["LY_FIRST_BK"] = "原始鍵位（裝插件前）"
t["LY_FIRST_BK_MSG"] = "第一次備份已標為永久保存「原始鍵位（裝插件前）」，不進輪換、不會被清理；「保存」頁可改名 / 取消"
t["LY_ROLE_FORM"] = "姿態 / 形態"
t["LY_ROLE_FORM_D"] = "變身、姿態、光環切換；鋪在主條同位，變身後各頁都有"
t["LY_FORM_CAT"] = "獵豹形態"
t["LY_FORM_PROWL"] = "獵豹 · 潛行"
t["LY_FORM_BEAR"] = "熊形態"
t["LY_FORM_MOONKIN"] = "梟獸形態"
t["BP_EM_LIMIT"] = "美化全身最多 2 件：先去掉另一件的美化"
t["BP_EM_NOT_CRAFTED"] = "美化只能做在製造裝備上"
t["BP_GEM_UNIQUE"] = "這顆寶石全身只能鑲一顆"
t["BP_M_TRACK"] = "升級軌道"
t["BP_TR_X_TIP2"] = "這件的軌道升滿"
t["BP_AUTO_TAG"] = "（自動）"
t["BP_NONE"] = "無"
t["BP_M_ENCH"] = "附魔"
t["BP_TIP_USAGE"] = "頂尖玩家使用率 %.0f%%"
t["BP_MENU_EXTRAS"] = "附魔 / 寶石 / 美化 / 製造屬性…（右鍵這一格也能開）"
t["BP_ENCH_NONE"] = "不附魔"
t["BP_ALL_AUTO_E"] = "全部附魔恢復自動（按使用率）"
t["BP_M_GEM"] = "寶石（%d 孔）"
t["BP_GEM_SOCK_NOTE"] = "這個部位只有 %.0f%% 的頂尖玩家帶孔：你這件沒孔就不用鑲"
t["BP_GEM_SOCKET"] = "孔 %d"
t["BP_EMPTY_SOCK"] = "空"
t["BP_GEM_UNIQ_TAG"] = "唯一"
t["BP_ALL_AUTO_G"] = "全部寶石恢復自動（按使用率）"
t["BP_M_EM"] = "美化"
t["BP_EM_NONE"] = "不美化"
t["BP_M_CS"] = "製造屬性"
t["BP_CS_NOTE"] = "第一項點數約是第二項的 2 倍"
t["BP_CS_AUTO"] = "自動（按專精最想要的兩項）"
t["BP_TT_ENCH"] = "附魔："
t["BP_NO_ENCH"] = "未附魔"
t["BP_TT_NO_ENCH"] = "這一格沒選附魔"
t["BP_TT_GEM"] = "寶石："
t["BP_TT_EM"] = "美化："
t["BP_TT_CS"] = "製造屬性："
t["BP_TT_HINT"] = "左鍵：換裝備 · 右鍵：升級軌道 / 附魔 / 寶石 / 美化 / 製造屬性"
t["BP_CK_ENCH"] = "附魔 %d/%d 部位"
t["BP_CK_EM"] = "美化 %d/%d 件"
t["BP_CK_EM_OVER"] = "（超了，只能 2 件）"
t["BP_CK_EM_OPTIONAL"] = "（可選，未補齊）"
t["BP_CK_GEM_UNIQ"] = "唯一寶石鑲了不止一顆"
t["BP_BTN_FILL"] = "補齊附魔寶石美化"
t["BP_FILL_DONE"] = "已補齊：%d 處（附魔 / 寶石按頂尖玩家使用率，美化補到 2 件；你已選的不動）"
t["BP_BTN_FILL_TIP"] = "空著的附魔、寶石按頂尖玩家使用率補上，美化在製造件上補到 2 件；你已經選的不動。和網站 / 小程式的「一鍵補齊」同一套規則。"
t["BP_OH_2H"] = "雙手武器 · 不需要副手"
t["BP_RAND_IDEAL"] = "隨機屬性 · 理想 %s"
t["BP_TT_RAND"] = "隨機屬性：掉落時隨機兩條。方案按你專精最想要的「%s」計算，實際以掉落為準"
t["BP_TT_TARGET"] = "方案目標裝等：%d（%s）"
t["TTBIS_FILLER_PLAN"] = "方案選定"
t["WA_FILLER_PLAN"] = "方案坯子（#%d/%d）→ 轉 %s"
t["BP_FILLER_TITLE"] = "坯子 · 催化成「%s」"
t["BP_FILLER_CLEAR"] = "不指定坯子（按排名自動）"
t["BP_FILLER_ON"] = "坯子："
t["BP_FILLER_PICK"] = "點格子選坯子"
t["FG_SKIP_GRP"] = "不再提示的部位 / 裝備"
t["FG_SKIP_SUB"] = "右鍵格子：恢復 / 仍要提示"
t["FG_SKIP_CAT"] = "已跳過"
t["FG_SKIP_HDR"] = "已跳過 %d · 已達標（製造裝）%d"
t["FG_SKIP_NOTE"] = "右鍵任意格子可跳過這個部位 / 這件；開了篩選時身上製造裝裝等夠了會自動收到這裡"
t["FG_SKIP_RESTORE"] = "恢復提示"
t["FG_SKIP_RESTORE_ALL"] = "全部恢復"
t["FG_SKIP_AUTO_OFF"] = "仍要提示這個部位"
t["FG_SKIP_SLOT"] = "跳過這個部位（%s）"
t["FG_SKIP_ITEM"] = "跳過這件（下一名頂上來）"
t["FG_SKIP_WEAPONS"] = "跳過武器（主手 + 副手）"
t["FG_GRID_RCLICK"] = "右鍵：跳過這個部位 / 這件，或恢復"
t["FG_GRID_AUTO"] = "達"
t["FG_AUTO_TIP"] = "已達標：身上是製造裝 %d ≥ 推薦 %d（按目前篩選）"
t["FG_GRID_SKIP"] = "跳"
t["FG_SKIPPED_SLOT"] = "已跳過這個部位"
t["FG_SKIPPED_ITEM"] = "已跳過這件"
t["CONTENT_COMMON"] = "常規"
t["MLEVEL_COMMON"] = "+12 · 第 300~500 名"
t["TP_RANK_N"] = "第 %d 名"
t["LY_TALENT_WHY_STAGED"] = "天賦面板裡有改了還沒點「套用」的天賦"
t["LY_TALENT_WHY_NOCONFIG"] = "遊戲還沒把目前天賦配置給到插件（剛上線 / 剛切專精）"
t["LY_TALENT_WHY_NOEXPORT"] = "遊戲沒產生目前天賦的匯出字串"
t["LY_TALENT_NOT_SAVED"] = "這次儲存沒記下天賦：%s。按鍵照常存了；處理好後點「覆蓋儲存」就能補上天賦"
t["LY_MACRO_GROUP_FIXED"] = "爆發 / 保命合成巨集跟著它那一行，不能單獨挪"
t["LY_MACRO_OPEN_EDITOR"] = "打開巨集編輯器"
t["LY_PAGE_MENU_TITLE"] = "放進哪一頁（形態動作條）"
t["LY_PAGE_FULL"] = "已滿"
t["LY_PAGE_SET"] = "%s → 「%s」（右鍵可改回）"
t["LY_PAGE_RESET"] = "恢復自動分頁"
t["LY_PAGE_MAIN_TAG"] = "主條 1–12"
t["LY_PAGE_MAIN"] = "主條 1–12"
t["LY_PAGE_SHARED"] = "公用條 2~5（變身不換頁）"
t["LY_FORM_STEALTH"] = "潛行"
t["LY_WHY_FORM_ONLY"] = "本形態專屬"
t["LY_FORM_PAGE"] = "形態頁"
t["LY_SLOT_WORD"] = "格"
t["LY_FORM_PAGE_D"] = "變成這個形態時主條 1 顯示的內容，鍵與主條同位共用"
t["LY_FORM_MIRROR"] = "形態頁動作條已按形態鋪好：%d 格（貓 / 熊 / 梟獸 / 潛行時看到的那條，鍵位與主條共用）"
t["LY_FORM_BASE"] = "人形（施法）"
t["LY_FS_CAT"] = "貓"
t["LY_FS_BEAR"] = "熊"
t["LY_FS_BASE"] = "人"
t["LY_FS_STEALTH"] = "潛"
t["LY_ON_FORM_PAGE"] = "在「%s」頁第 %d 格（鍵 %s，與主條同位共用）"
t["LY_BADGE_GEN"] = "通"
t["LY_WHY_GENERAL"] = "通用"
t["LY_ROT_PIN_ROT"] = "選擇常規序列"
t["LY_ROT_PIN_ROT_TIP"] = "釘板只顯示「現在該按」這一格（暴雪循環助手，含單體 / AOE 判斷），不帶起手序列。"
t["LY_MACRO_HAS"] = "「%s」裡已經有 %s"
t["LY_MACRO_TOO_LONG"] = "「%s」加上 %s 會超 255 字，沒加"
t["LY_MACRO_ADDED"] = "已加進「%s」：%s（右鍵格子打開巨集編輯器可改）"
t["LY_ROLE_SKIP"] = "不進動作條"
t["LY_ROLE_SKIP_D"] = "你右鍵標過「不進動作條」的：永遠不鋪、不佔格、不分鍵"
t["LY_ROLE_SKIP_SET"] = "%s → 不進動作條（右鍵可改回）"
t["LY_NO_SLOT_BASE"] = "人形（施法）頁 12 格滿了，公用條也滿了"
t["LY_NO_SLOT_FORM"] = "這個形態頁 12 格滿了"
t["LY_NO_SLOT_60"] = "主條 + 條 2～5 共 60 格滿了"
t["LY_NO_SLOT_HINT"] = "右鍵把不用的技能標「不進動作條」騰格"
t["LY_FORM_ERR"] = "形態頁計劃出錯（已退回不分頁）："
t["LY_FORM_SECONDARY"] = "副形態"
t["LY_FORM_PRIMARY"] = "主形態 · 主條鍵位 1–5 起"
t["LY_NEED_HUMANOID"] = "先變回人形再鋪：變身時主條 1–12 指向的是當前形態那頁，人形頁碰不到（暴雪 API 限制）"
t["LY_FORM_ST_ERR"] = "形態頁出錯"
t["LY_FORM_ST"] = "形態頁"
t["LY_FORM_ST_BASE"] = "主條 1–12 = 人形頁"
t["LY_GROUP_SKIP_HINT"] = "右鍵技能 → 恢復自動判斷 才回到條上"
t["NW_REL_TIP"] = "%d 條改動 · 點開看全部"
    t["NW_REL_N"] = "%d 條"
end

do
    local t = GearInsight.LOC.zhTW
    t["CH_TODAY"] = "今日"
    t["CH_RESET_RULE"] = "遊戲日以北京時間 07:00 為界"
    t["CH_STALE"] = "今天（%s）的還沒整理 —— 每天 07:00 更新後寫；舊的不展示，免得按舊座標白跑。"
    t["CH_SEC_DAY"] = "今日"
    t["CH_SEC_DAY_NOTE"] = "只在今天有效，明早 07:00 過期"
    t["CH_SEC_WEEK"] = "本週"
    t["CH_SEC_WEEK_NOTE"] = "整週有效，到 %s"
    t["CH_SEC_WEEK_NOTE0"] = "整週有效"
    t["CH_POP_DAY"] = "翹課 · 今日（明早 07:00 過期）"
end

do
    local t = GearInsight.LOC.zhTW
    t["NW_CHEESE_DAILY"] = "翹課每日更新，注意每次上線前更新插件"
end

do
    local t = GearInsight.LOC.zhTW
    t["ROT_MODE_HINT_BOSS"] = "← 左鍵下一隻 BOSS / 大秘境，右鍵上一隻（各 BOSS 循環差異很大）"
end

do
    local t = GearInsight.LOC.zhTW
    t["BTN_RELOAD"] = "重載介面"
    t["SUP_STAT_PEOPLE"] = "位支持者"
    t["SUP_STAT_WEEK"] = "本週"
    t["TALENT_LOD_ENABLED"] = "天賦庫模組被停用了，已幫你啟用 —— 點下面按鈕重載介面即可生效"
    t["TALENT_LOD_RELOAD"] = "GearInsight_Talents 已啟用，需要重載介面"
    t["TTUP_DIFF_HEROIC"] = "英雄"
    t["TTUP_DIFF_NORMAL"] = "普通"
end
do
    -- 0.91.4：智能键位+宏 页签入口的 10 个键补繁體（0.91.0 加的，之前没过审计）
    local t = GearInsight.LOC.zhTW
    t["MT_LAYOUT_LOAD_FAIL"] = "載入「GearInsight_Layout」失敗："
    t["MT_LAYOUT_LOAD_FAIL2"] = "（插件列表裡有沒有 GearInsight_Layout？）"
    t["MT_LAYOUT_MOD_ASK"] = "要載入「鍵位手法」模組嗎？\n\n一鍵鋪快捷列 / 智慧分鍵 / 巨集庫 / 備份還原。\n載入後本次登入一直在；選「以後自動載入」下次點頁籤直接開。"
    t["MT_LAYOUT_MOD_BTN"] = "載入鍵位手法模組"
    t["MT_LAYOUT_MOD_HINT"] = "「鍵位手法」是獨立模組（GearInsight_Layout）：按 WCL 頂尖玩家的按鍵頻率一鍵鋪快捷列、智慧分鍵、巨集庫、備份 / 還原、MySlot 匯出。\n預設不載入，不佔記憶體；點下面的按鈕載入，選「以後自動載入」就不再問。"
    t["MT_LAYOUT_MOD_NO"] = "不載入"
    t["MT_LAYOUT_MOD_ONCE"] = "只這次載入"
    t["MT_LAYOUT_MOD_YES"] = "以後自動載入"
    t["MT_TAB_LAYOUT"] = "鍵位手法"
    t["MT_TAB_LAYOUT_TITLE"] = "鍵位手法 · 一鍵鋪快捷列 / 巨集庫 / 自動分鍵 / 循環助手"
end

do
    -- 0.92.14：LayoutPage 的 174 个键补繁體（opencc s2twp + 領域詞表；09-21 做無限版時審計出缺）
    local t = GearInsight.LOC.zhTW
    t["LY_ASK_RB"] = "要清空主條 + 條2~條5 共 60 格，按 WCL 頂尖玩家的按鍵重鋪。\n（做之前會自動備份一份，可一鍵還原）"
    t["LY_AUTOSAVED"] = "已自動備份：%s（「儲存」頁可還原）"
    t["LY_BADGE_RACIAL"] = "族"
    t["LY_BADGE_TALENT"] = "天"
    t["LY_BAR1"] = "主條"
    t["LY_BAR2"] = "條2·左下"
    t["LY_BAR3"] = "條3·右下"
    t["LY_BAR4"] = "條4·右"
    t["LY_BAR5"] = "條5·右2"
    t["LY_BK_HD"] = "已儲存的鍵位"
    t["LY_BK_NONE"] = "還沒有備份"
    t["LY_BTN_CLEAR"] = "一鍵清理備份"
    t["LY_BTN_CLEAR_ALL"] = "全部清掉"
    t["LY_BTN_DEL"] = "刪除"
    t["LY_BTN_DEL_ALL"] = "全部刪掉"
    t["LY_BTN_FILL"] = "只填空位"
    t["LY_BTN_KEYS"] = "將插件建議實現到快捷列"
    t["LY_BTN_KEYS_RESET"] = "儲存當前鍵位快照"
    t["LY_BTN_MACRO_CLEAR"] = "一鍵清 GI 巨集"
    t["LY_BTN_MS"] = "匯出 MySlot 串"
    t["LY_BTN_MS_ONE"] = "MySlot 串"
    t["LY_BTN_RANK"] = "技能施放排名（參考）"
    t["LY_BTN_RB"] = "清空重鋪（推薦）"
    t["LY_BTN_RESTORE"] = "還原"
    t["LY_BTN_SAVE"] = "儲存當前鍵位"
    t["LY_CAP_HINT"] = "按下新的鍵位…"
    t["LY_CAP_HINT2"] = "支援 Shift / Ctrl / Alt 組合、滑鼠側鍵、滾輪\nEsc 取消 · Backspace 不綁"
    t["LY_CB_KEEP"] = "保留現有鍵位"
    t["LY_CB_KEEP_TT"] = "按第一次開啟這頁時記下的「我的鍵位」快照來（智慧改過也能回去），只給沒綁鍵的格子補鍵"
    t["LY_CB_QE"] = "Q E 也參與分鍵（預設留給左右平移）"
    t["LY_CB_SMART"] = "換智慧推薦鍵位"
    t["LY_CB_SMART_TT"] = "按職能順序整體重排：主循環拿 1-5，然後 RFTG ZXCV、Shift/Alt/Ctrl 組合、F1-F4…，7 8 9 0 / F5+ 排最後；裸 QE AD WS 留給移動"
    t["LY_CLEARED"] = "已清掉 %d 份鍵位備份（永久儲存的 %d 份留著）"
    t["LY_CLEAR_ASK"] = "要把 %d 份鍵位備份全部刪掉嗎？刪了就找不回來了。"
    t["LY_COMBAT"] = "戰鬥中不能改快捷列"
    t["LY_DEL_PINNED"] = "這份是永久儲存的：先點 ★ 取消永久再刪"
    t["LY_DONE"] = "鍵位已鋪：新放 %d 格，保留 %d 個原位技能（%s）"
    t["LY_DROP"] = "放不下 "
    t["LY_EMPTY"] = "空格"
    t["LY_GM_BURST"] = "GI爆發"
    t["LY_GM_DEF"] = "GI保命"
    t["LY_GROUP_OFF"] = " · 不上條（勾上才佔格）"
    t["LY_GROUP_OFF_TT"] = "這一行沒勾「上條」，不佔格；勾上行頭的框才鋪"
    t["LY_GROUP_ON_TT"] = "勾 = 這一行上快捷列、分鍵；不勾 = 整行摺疊不佔格（巨集 / 飾品 / 藥水照放）"
    t["LY_KEYDIFF"] = "[%s] 推薦鍵位：會改 %d 格，%d 格不動（黃色角標 = 會改的；點「將插件建議實現到快捷列」才生效）"
    t["LY_KEYSNAP_SAVED"] = "已把面板上現在這套鍵記為「我的鍵位」快照（%s），「保留現有鍵位」= 回到這份"
    t["LY_KEYSNAP_TT1"] = "「我的鍵位」快照"
    t["LY_KEYSNAP_TT2"] = "「保留現有鍵位」模式讀的不是實時繫結，而是這份快照——第一次開啟這頁時自動記的，所以智慧改過之後還能切回去。\n你在面板上調好一套滿意的鍵位，點這裡把快照更新成面板上現在這套（不動遊戲裡的繫結，也不清手動改鍵記錄）。"
    t["LY_KEYSNAP_TT3"] = "當前快照記於 "
    t["LY_KEYSNAP_TT4"] = "還沒有快照"
    t["LY_KEYS_DONE"] = "已按推薦鍵位設定 %d 個繫結（已儲存到當前繫結方案）"
    t["LY_KEYS_MACRO_FAIL"] = "這些巨集沒放上（巨集欄滿了？）："
    t["LY_KEYS_MACRO_PLACED"] = "已建好並放上 %d 個巨集格"
    t["LY_KEYS_MOVE_BACK"] = "移動鍵已還回："
    t["LY_KEYS_REPLACED"] = "撞鍵，已替換（原來那格現在無快捷鍵）："
    t["LY_KEYS_TAKEN"] = "這些鍵原來綁著別的功能，已被挪到快捷列（「儲存」頁還原可全部改回）："
    t["LY_KEYS_TIP"] = "格子左上角 = 推薦鍵：你現在按職能順序整體重排：主循環拿 1-5，然後 RFTG ZXCV、Shift/Alt/Ctrl 組合、F1-F4…，7 8 9 0 / F5+ 排最後；裸 QE AD WS 留給移動不參與。\n點格子後按新鍵即改；Backspace 不綁；Esc 取消。"
    t["LY_KEY_CONFLICT"] = "[撞鍵] 和格 %d 撞鍵：實現時後出現的格拿到這個鍵，另一格置空。點其中一格改個鍵。"
    t["LY_KEY_NONE"] = "不綁"
    t["LY_KEY_REC"] = "推薦："
    t["LY_KEY_TT2"] = "這格現在綁："
    t["LY_KEY_TT3"] = "點一下再按新鍵可改；Backspace 不繫結；Esc 取消 · 按住左鍵可直接拖到動作條 · Shift+左鍵：塞進正在編輯的巨集（/cast 一行）或聊天框"
    t["LY_LEG_TRK"] = "飾品/坐騎"
    t["LY_LIB_HD"] = "巨集庫 · 勾選加入安排池"
    t["LY_LIB_LACK"] = "缺："
    t["LY_LIB_MISSING"] = "|cffff4040[缺]|r 你沒有這些技能："
    t["LY_LIB_SRC"] = "來自巨集庫（Icy Veins / Method 12.1）"
    t["LY_LIB_SUB"] = "Icy Veins / Method 12.1 各專精巨集，紅字 = 你缺技能"
    t["LY_LIB_TT"] = "勾選 = 加入安排池，按第一個技能的職能歸行，自動分鍵；鋪的時候建巨集放上去"
    t["LY_MACRO"] = "巨集："
    t["LY_MACRO_CLEARED"] = "已刪掉 %d 個 GI 打頭的巨集"
    t["LY_MACRO_CLEAR_ASK"] = "要刪掉 %d 個「GI」打頭的巨集嗎（含建壞的 placeholder）？快捷列上對應的格會變空。"
    t["LY_MACRO_FULL"] = "巨集欄滿了（角色 18 / 通用 120），刪幾個再來"
    t["LY_MACRO_NONE"] = "沒有 GI 打頭的巨集"
    t["LY_MACRO_PLACED"] = "巨集「%s」已建好並放到格 %d"
    t["LY_MACRO_TT"] = "普通巨集（非 GSE）"
    t["LY_MACRO_TT2"] = "左鍵：改推薦鍵 · Shift+左鍵：現在就建巨集放到這格 · 拖動：拖到快捷列 · 右鍵：挪到別的行 / 開啟巨集編輯器· Shift+右鍵：重新生成正文"
    t["LY_MACRO_TT3"] = "連續按這個巨集：不佔公共冷卻的技能會同時嘗試；佔公共冷卻的技能按序列逐個施放。切換目標、脫戰或 15 秒未繼續會從頭開始。"
    t["LY_MACRO_WORD"] = "巨集"
    t["LY_MIN_UNIT"] = " 分"
    t["LY_MODE_FILL"] = "只填空位"
    t["LY_MODE_RB"] = "清空重鋪"
    t["LY_MODE_REPLACE"] = "替換"
    t["LY_MODE_SAVE"] = "儲存"
    t["LY_MS_FAIL"] = "MySlot 串生成失敗："
    t["LY_MS_HINT"] = "Ctrl+C 複製 > 開啟 MySlot > 貼上 > 匯入"
    t["LY_MS_LOG"] = "MySlot 串：%d 格 + %d 條繫結，%d 位元組，來源「%s」"
    t["LY_MS_NOADDON"] = "沒裝 MySlot 插件（或沒啟用）：串已在上面，裝好後 /myslot 貼上匯入"
    t["LY_MS_OPEN"] = "開啟 MySlot"
    t["LY_NONE"] = "無"
    t["LY_NOW_HD"] = "現在的快捷列"
    t["LY_NOW_NOTE"] = "紅角 = 重鋪後這格會變"
    t["LY_NO_POTION"] = "包裡沒有推薦藥水，這幾格先空著："
    t["LY_NO_SLOT"] = "60 格放不下，這個不鋪"
    t["LY_NO_WCL"] = "本專精暫無 WCL 循環資料，只按天賦 + 法術書分組"
    t["LY_N_UNIT"] = " 個"
    t["LY_PEND_CONTENT"] = "格未鋪 → 清空重鋪"
    t["LY_PEND_KEYS"] = "格鍵未生效 → 實現到快捷列"
    t["LY_PEND_NONE"] = "快捷列和鍵位都已和右邊一致"
    t["LY_PIN_FULL"] = "永久儲存最多 %d 份，先取消一份再標"
    t["LY_PIN_TT_OFF"] = "點選標為永久儲存：不進 10 份輪換、不會被一鍵清理，標了以後可點名字改名"
    t["LY_PIN_TT_ON"] = "永久儲存中：不進 10 份輪換、不會被一鍵清理。點選取消永久"
    t["LY_PV_HD"] = "重鋪後的快捷列 · 按職能分行"
    t["LY_RANK_DUR"] = "中位 "
    t["LY_RANK_LEGEND"] = "|cffff6060紅字|r = 這個技能現在不在你的快捷列上 · 條形按各列最大值相對刻度 · 懸停看技能說明"
    t["LY_RANK_MPLUS"] = "大米"
    t["LY_RANK_NONE"] = "暫無資料"
    t["LY_RANK_RAID"] = "團本"
    t["LY_RANK_SAMPLES"] = "個樣本"
    t["LY_RANK_SUB"] = "每分鐘施放次數（cpm）· 團本 = 本週 M 首領前五玩家 · 大米 = 衝分各本前二聚合"
    t["LY_RANK_TITLE"] = "技能施放排名 · WCL 頂尖玩家"
    t["LY_RENAME_ASK"] = "給這份永久儲存起個名字："
    t["LY_RENAME_TT"] = "點選改名"
    t["LY_REPLACED_FMT"] = "%s：格 %d -> 格 %d"
    t["LY_RESTORED"] = "已還原「%s」的鍵位：改回 %d 格，%d 格沒法自動放（飛出面板等）；按鍵繫結同步還原"
    t["LY_RESTORE_CHAR"] = "這份備份是角色「%s」的，不鋪到「%s」上"
    t["LY_RESTORE_SKIPPED"] = "沒放回去的："
    t["LY_RESTORE_SPEC"] = "這份備份是「%s」專精的，你現在是「%s」——先切回那個專精再還原"
    t["LY_ROLE_BURST"] = "爆發"
    t["LY_ROLE_BURST_D"] = "基礎 CD ≥ 45 秒的輸出技能"
    t["LY_ROLE_CC"] = "控制 / 解控"
    t["LY_ROLE_CC_D"] = "群控 > 單控，空一格後是解控（免疫/解除控制）"
    t["LY_ROLE_CORE"] = "主循環"
    t["LY_ROLE_CORE_D"] = "WCL 頂尖玩家每分鐘 ≥ 2 次的"
    t["LY_ROLE_DEF"] = "減傷保命"
    t["LY_ROLE_DISPEL"] = "驅散"
    t["LY_ROLE_DPS"] = "其他輸出"
    t["LY_ROLE_DPS_D"] = "不在主循環裡的短 CD 輸出技能"
    t["LY_ROLE_HEAL"] = "治療"
    t["LY_ROLE_INT"] = "打斷 / 嘲諷"
    t["LY_ROLE_INT_D"] = "打斷在前，空一格後是嘲諷"
    t["LY_ROLE_INV"] = "坐騎"
    t["LY_ROLE_INV_D"] = "隨機偏好坐騎；主動飾品按效果並進爆發 / 減傷 / 治療行"
    t["LY_ROLE_MOB"] = "位移"
    t["LY_ROLE_RAID"] = "團隊工具"
    t["LY_ROLE_RAID_D"] = "給隊友的減傷 / 增益 / 嗜血"
    t["LY_ROLE_SUMMON"] = "召喚"
    t["LY_ROLE_UTIL"] = "功能"
    t["LY_ROLE_UTIL_D"] = "不打不奶的主動技能：水上行走、變形、開鎖…"
    t["LY_R_FILL"] = "只填空位前"
    t["LY_R_KEYS"] = "設定繫結前"
    t["LY_R_MANUAL"] = "手動儲存"
    t["LY_R_RB"] = "清空重鋪前"
    t["LY_R_RESTORE"] = "還原前"
    t["LY_SAME"] = "和上一份備份一模一樣，沒重複存"
    t["LY_SAVED"] = "鍵位已儲存：%s"
    t["LY_SAVE_SUB"] = "把現在 180 格快捷列 + 全部按鍵繫結存一份（輪換最多 10 份，滿了自動擠掉最老的；鋪格子 / 設定繫結 / 還原之前也會自動存），隨時一鍵還原。點行首 ★ 標為永久儲存（最多 6 份，不進輪換、不被清理、可點名字改名）；也可匯出成 MySlot 串。"
    t["LY_SLOT"] = "格"
    t["LY_SLOT_FMT"] = "格%d %s"
    t["LY_SLOT_UNIT"] = " 格"
    t["LY_SRC_RACIAL"] = "種族技能"
    t["LY_SRC_TALENT"] = "天賦技能"
    t["LY_STEP1"] = "① 鋪技能"
    t["LY_STEP2"] = "② 設鍵位"
    t["LY_TIP"] = "清空重鋪：主條 + 條2~條5 共 60 格按右邊重鋪。\n只填空位：條上已有的一個不動，只補缺的。"
    t["LY_TOTAL"] = "共 "
    t["LY_WHY_AOECC"] = "群控"
    t["LY_WHY_BOOK"] = "法術書"
    t["LY_WHY_CCBREAK"] = "解控"
    t["LY_WHY_LIB"] = "巨集庫"
    t["LY_WHY_MOUNT"] = "坐騎"
    t["LY_WHY_OPENER"] = "起手"
    t["LY_WHY_POTION"] = "藥水 · 頂尖玩家 %d%% 用 %s"
    t["LY_WHY_PVP"] = "PvP 天賦"
    t["LY_WHY_RACIAL"] = "種族"
    t["LY_WHY_STCC"] = "單控"
    t["LY_WHY_SUMMON_SFX"] = " · 召喚"
    t["LY_WHY_TALENT"] = "天賦"
    t["LY_WHY_TAUNT"] = "嘲諷"
    t["LY_WHY_TRK"] = "飾品·主動"
    t["LY_WHY_TRK_BURST"] = "飾品·爆發"
    t["LY_WHY_TRK_DEF"] = "飾品·減傷"
    t["LY_WHY_TRK_HEAL"] = "飾品·治療"
    t["LY_WHY_WCL"] = "WCL %.1f 次/分"
end
do
    local t = GearInsight.LOC.zhTW
    t["LY_LEG_MOUNT"] = "坐騎"
    t["LY_RESTORED_MACROS"] = "巨集也改回：%d 個內文改回存的那份，%d 個被刪的已重建"
    t["LY_RESTORED_MACRO_FAIL"] = "這些巨集沒法重建（巨集欄滿了：角色 18 / 通用 120）："
    t["LY_SHIFT_LINK_NONE"] = "先打開巨集編輯器（/macro）並點進內文，或打開聊天框，再 Shift+左鍵這格：會把它作為一行塞進去"
    t["LY_R_DAILY"] = "每日自動"
    t["LY_DAILY_TITLE"] = "每日存檔 %s"
    t["LY_DAILY_SAVED"] = "今天第一次登入，鍵位已自動存為永久備份「%s」（「儲存」頁可還原；只保留最近 %d 天）"
end
do
    local t = GearInsight.LOC.zhTW
    t["LY_ROT_NOW_NOTE2"] = "隨目標 / 戰鬥即時變 · 黃字鍵 = 未綁，顯示推薦  |cff888888[?]|r"
end
do
    local t = GearInsight.LOC.zhTW
    t["LY_TB_Q_SEQ"] = "接下來"
    t["LY_TB_Q_CAND"] = "候選"
end
do
    local t = GearInsight.LOC.zhTW
    t["LY_TB_Q_FOLLOW"] = "常見接續"
end
do
    local t = GearInsight.LOC.zhTW
    t["MT_BOARD_NEED_AUTO"] = "要讓「GI 循環助手」釘板登入後自己出現：打開「鍵位手法」頁，勾右下角「點頁籤自動載入此模組」（只提示這一次）"
end
do
    local t = GearInsight.LOC.zhTW
    t["PN_ON"] = "領航已打開（測試版）：進鑰石 / M0 自動彈拉怪清單；/gi nav off 關閉，/gi nav sim 模擬推進"
end

-- 2026-09-22 属性优先级行「其他专精」悬浮
do
    local L = GearInsight.LOC and GearInsight.LOC["zhTW"]
    if L then
        L["STAT_PRI_OTHERS"] = "本職業其他專精 · 屬性優先序"
        L["STAT_PRI_OTHERS_MODE"] = "依目前檔：%s · WCL 頂尖玩家配比"
    end
end

-- 2026-09-22 属性区「查看专精」下拉
do
    local L = GearInsight.LOC and GearInsight.LOC["zhTW"]
    if L then
        L["STAT_SPEC_FOLLOW"] = "目前專精"
        L["STAT_SPEC_MENU"] = "屬性目標按哪個專精算"
        L["STAT_SPEC_TIP"] = "檢視專精"
        L["STAT_SPEC_TIP_BODY"] = "把下面的屬性優先序和達成度切到本職業另一個專精的目標（用你現在的評級算）。只切屬性區，BiS 清單和刷本規劃仍按你的真實專精。"
        L["LY_ROLE_MENU_NA"] = "這個客戶端沒有選單介面"
    end
end

-- 2026-09-22 属性达成度整行悬浮
do
    local L = GearInsight.LOC and GearInsight.LOC["zhTW"]
    if L then
        L["STT_CUR"] = "你的評級"
        L["STT_PANEL"] = "面板"
        L["STT_TGT"] = "目標評級"
        L["STT_DIFF"] = "差值"
        L["STT_RULE"] = "目標 = WCL 頂尖玩家該屬性的平均評級。<90% 不足 · 90–100% 容差內 · 100–110% 達標 · >110% 超標；目標占比不到最高項 30% 的算非核心，不報紅。"
    end
end

do
    local t = GearInsight.LOC["zhTW"]
    if t then t["LY_AUTO_REMEMBERED"] = "「鍵位手法」已設為登入自動載入：鍵帽 / 循環助手以後不用再進插件開。要關的話在本頁右下角取消勾選。" end
end

-- 2026-09-22 Roll 币三选 / 低保（main/RollVault.lua）
do
    local t = GearInsight.LOC["zhTW"]
    if t then
        t["RV_BOSS_TIP"] = "本專精能用 %d 件 · 有用 %d · 值得要 %d\n單枚幣出貨率按 15%% 算（暴雪未公開）"
        t["RV_BTN"] = "Roll 幣 / 保底"
        t["RV_BTN_TIP"] = "本週 3 枚 roll 幣砸哪三個首領：按你身上裝備 + BiS + 套裝 + 軌道給每件掉落打分，已擊殺的首領自動排除，帶 roll 到的機率。週三開寶庫時右側自動出「保底怎麼選」。"
        t["RV_DIFF_H"] = "英雄"
        t["RV_DIFF_M"] = "傳奇"
        t["RV_DIFF_N"] = "普通"
        t["RV_BOSS_TIP4"] = "\n已用幣 roll 到過 %d 件，已出池 → 剩下的件機率更高"
        t["RV_ROLLED"] = "已出池"
        t["RV_ROLLED_AUTO"] = "已記下：這件用幣 roll 到了，已從該首領的 roll 幣池子移除（/gi roll 裡右鍵可取消）"
        t["RV_R_ROLLED"] = "已經用幣 roll 到過，已出池"
        t["RV_TT_NOTROLLED"] = "右鍵標記「我用幣 roll 到過這件」→ 出池，剩下件的機率上升。\n（正常打本拾取到不算出池，還能再 roll 到）"
        t["RV_TT_ROLLED"] = "已用幣 roll 到過 → 已從這個首領的 roll 幣池子移除。右鍵取消標記。"
        t["RV_COIN_UP"] = "｜%s本用幣出%s檔，下面的裝等和分數都已經按%s檔算"
        t["RV_DIFF_L"] = "隨機"
        t["RV_TT_COIN_ILVL"] = "這個難度直接掉 %d 裝等；roll 幣固定出高一檔 → %d，已按 %d 打分"
        t["RV_COINED"] = "[本週已用幣]"
        t["RV_NOT_ENOUGH"] = "本週只剩 %d 個首領能砸（一個首領一個 CD 只能 roll 一次），3 枚幣用不完"
        t["RV_COIN_TOP"] = "史詩已封頂，用幣還是史詩檔"
        t["RV_COIN_UP2"] = "roll 幣固定出高一檔：%s本用幣出%s檔 —— 下面的裝等和分數已按%s檔算"
        t["RV_SUB3"] = "%s · %s難度 · 3 枚幣全砸下去，約 %s 中一件有用的（其中 %s 是真提升）"
        t["RV_API_DONE"] = "roll 接口探測完成：C_ 命中 %d 個，全域 %d 個 —— 結果已放進可複製框（Ctrl+A → Ctrl+C）"
        t["RV_API_HINT"] = "Ctrl+A 全選 → Ctrl+C 複製，貼給開發者"
        t["RV_API_TITLE"] = "roll 幣介面探測"
        t["RV_EXCLUDED"] = "已排除"
        t["RV_ILVL_NA"] = "裝等 ?"
        t["RV_NOILVL"] = "裝等未知"
        t["RV_R_EXCLUDED"] = "你手動排除了這件（Shift+右鍵恢復）"
        t["RV_R_NOILVL"] = "裝等讀不出來（冒險指南資料沒載入）→ 不計入池子"
        t["RV_TT_COIN_GUESS"] = "⚠ 這件的幣檔裝等是按同團本的檔差推算的（冒險指南還沒給出真實值），點「重掃」可刷新"
        t["RV_TT_NOTROLLED2"] = "右鍵標記「我用幣 roll 到過這件」→ 出池，剩下件的機率上升。\nShift+右鍵 =「這件不算」，直接從池子裡踢掉。\n（正常打本拾取到不算出池，還能再 roll 到）"
        t["RV_MP_NONE"] = "本賽季傳奇鑰石沒有能給你提升的掉落了"
        t["RV_MP_RULE"] = "10 層以上用幣出神話檔 · 每次通關都能砸，沒有週 CD —— 所以挑本，不挑週"
        t["RV_MP_TIP"] = "傳奇鑰石用幣出神話檔，而且每次通關都能砸 —— 所以這裡排的是「刷哪個本最值」，不是「本週砸哪三個首領」。"
        t["RV_MP_TOP"] = "優先刷這幾個本"
        t["RV_NO_DUNG"] = "找不到本賽季傳奇鑰石地城（BisData 沒載入好？）"
        t["RV_SUB_MP"] = "本賽季傳奇鑰石 · 按「這個本的掉落對你平均有多大提升」排序"
        t["RV_TAB_MPLUS"] = "傳奇鑰石"
        t["RV_TITLE_MP"] = "Roll 幣怎麼花 · 傳奇鑰石刷哪個本"
        t["RV_BOSS_TIP6"] = "池子裡本專精能用 %d 件 · 其中 %d 件對你有提升 · %d 件值得要\n一枚幣必出其中一件 → 中有用件 = %d/%d = %s\n（已 roll 到的、手動排除的不算在分母裡；身上已有的仍在池子裡，可能 roll 到重複）"
        t["RV_MP_TIP2"] = "傳奇鑰石用幣出神話檔，而且每次通關都能砸 —— 所以這裡排的是「刷哪個本最值」，不是「本週砸哪三個首領」。\n一枚幣必出一件，中某一件 = 1 ÷ 該首領能用的件數。"
        t["RV_OWNED"] = "已擁有"
        t["RV_R_OWNED"] = "身上已經穿著這件了 → 不計入池子"
        t["RV_MIN_ALL"] = "全部（含讓人）"
        t["RV_MIN_MINOR"] = "小提升以上"
        t["RV_MIN_WANT"] = "值得要以上"
        t["RV_MIN_MUST"] = "必 roll"
        t["RV_MIN_PREFIX"] = "只看："
        t["RV_MIN_TIP"] = "參考價值過濾：低於這一檔的件不算進「有用」，也不進排序的期望值。\n⛔ 池子分母不變 —— 變的只是「多少件算數」。\n點一下換下一檔。"
        t["RV_R_OWNED2"] = "身上這件已經是同檔或更高 → 不計入池子"
        t["RV_TOP3_TIP3"] = "按「這個首領的掉落對你平均有多大提升」排序。一枚幣必出一件，所以中某一件的機率 = 1 ÷ 池子裡你能用的件數。\n本週該難度已殺的首領不進三選（勾「已殺的也算」看全部）。⛔ 插件只提示，不會自動幫你用幣。"
        t["RV_MP_DUNG_TIP"] = "整個本算一個池子（不分首領）：能用 %d 件 · 其中 %d 件有提升 · %d 件值得要\n一枚幣必出其中一件 → 中有用件 = %d/%d = %s\n（身上已有的、手動排除的、裝等讀不出來的都不佔分母）"
        t["RV_MIN_"] = ""
        t["RV_TT_COIN_MYTH"] = "這個本直接掉 %d 裝等；10 層以上用幣出神話檔 → %d，已按 %d 打分"
        t["RV_VAULT_EMPTY2"] = "本週還沒解鎖任何檔位。進度："
        t["RV_VAULT_EMPTY3"] = "  （介面還在載入，稍等一下再看）"
        t["RV_VAULT_EXPORT_FAIL2"] = "匯出失敗：裝備快照沒準備好（/gi refresh 後再試）。如果一直失敗，把這句發給作者。"
        t["RV_VAULT_EXPORT_HINT_EMPTY"] = "本週還沒有可選獎勵，這串只帶了你身上的裝備 —— 網頁那邊照樣能看推薦"
        t["RV_COL_POOL"] = "達標/池子"
        t["RV_VAULT_ERR"] = "算推薦時出錯了，把下面這行發給作者："
        t["RV_SEC_MP"] = "傳奇鑰石 · 每次通關都能砸，沒有週 CD"
        t["RV_SEC_RAID"] = "團本 · %s（%s難度）"
        t["RV_SRC_MP"] = "鑰石"
        t["RV_SRC_RAID"] = "團本"
        t["RV_TAB_MPLUS2"] = "含鑰石"
        t["RV_TAB_MPLUS_TIP"] = "把傳奇鑰石也算進來一起排 —— 幣是通用的，該砸團本還是刷鑰石放一張榜上比。\n傳奇鑰石每次通關都能砸，沒有週 CD。"
        t["RV_TOP_ALL"] = "這枚幣砸哪裡"
        t["RV_VAULT_EXPORT_HINT2"] = "Ctrl+C 複製，貼到瀏覽器網址列直接打開（自動算好，不用再貼一次）"
        t["RV_VAULT_EXPORT_HINT_EMPTY2"] = "本週還沒有可選獎勵，這條連結只帶了你身上的裝備 —— 貼到瀏覽器照樣能看推薦"
        t["RV_TT_COIN_MYTH2"] = "滑鼠上面那個裝等(%d)是這個本**直接掉**的；roll 幣 10 層以上出神話檔 %d，已按 %d 打分。\n（冒險指南給不出神話檔的物品連結，所以上面的提示只能顯示本檔裝等）"
        t["RV_MIN_TIP2"] = "多好才算「達標」。低於這一檔的件不算進機率，也不參與排序。\n池子的分母不變 —— 變的只是「多少件算數」，所以門檻越高，機率越低、榜越短。\n點一下換下一檔。"
        t["RV_TOP_TIP"] = "「一枚幣中」= 在這裡砸一枚幣，中一件達標裝備的機率。榜按它從高到低排。\n一枚幣必出一件，所以機率 = 達標件數 ÷ 池子件數。達標的門檻由上面「只看」那個按鈕定。\n不進榜的：本週已殺的首領、本 CD 已經用過幣的首領、機率為 0 的。\n傳奇鑰石沒有週 CD，每次通關都能砸，所以一直在榜上。\n插件只給建議，不會自動幫你用幣。"
        t["RV_VAULT_EMPTY4"] = "還沒有任何一格解鎖，寶庫裡現在挑不了東西。"
        t["RV_VAULT_EMPTY5"] = "（每一檔要刷夠次數才開一格，上面寫了還差幾次）"
        t["RV_VAULT_LIST"] = "能選的 %d 件："
        t["RV_VAULT_NONE2"] = "這 %d 件都不是提升（都 <15 分）。"
        t["RV_VAULT_NONE3"] = "挑裝等最高的那件拿走就行，主要是為了分解換升級紋章。"
        t["RV_VAULT_ROW"] = "%s %d/%d"
        t["RV_VAULT_ROW_NEED"] = "%s %d/%d（再 %d 次開下一格）"
        t["RV_VAULT_UNLOCK"] = "本週解鎖："
        t["RV_TT_COIN_MYTH3"] = "上面那個裝等(%d)是這個本直接掉的；roll 幣 10 層以上出神話檔，紋章升滿是 %d，已按 %d 打分。\n（冒險指南給不出神話檔的物品連結，所以上面的提示只能顯示本檔裝等）"
        t["RV_R_2H"] = "你拿的是雙手武器，副手用不上"
        t["RV_R_EMPTY"] = "這個槽是空的，按你身上裝等中位數比"
        t["RV_VAULT_NEED"] = "再 %d 次開一格"
        t["RV_VAULT_UNLOCK2"] = "本週解鎖"
        t["RV_VAULT_ONLY"] = "只有「%s」這排解鎖了，所以能選的都是它的獎勵；%s 刷夠次數才會多出選項。"
        t["RV_BEST"] = "最想要："
        t["RV_BOSS_TIP2"] = "本專精能用 %d 件 · 其中 %d 件對你有提升 · %d 件值得要\n一枚幣按 15%% 出貨算（暴雪未公開），%s"
        t["RV_BOSS_TIP3"] = "所以這個首領一枚幣中有用件 = 15%% × %d/%d"
        t["RV_COL_P"] = "一枚幣中"
        t["RV_COL_VERD"] = "值不值"
        t["RV_FARM2"] = "[傳奇鑰石也能刷]"
        t["RV_ILVL"] = "裝等"
        t["RV_NONE_ALL"] = "這個難度沒有能給你提升的掉落了 —— 換個難度看看"
        t["RV_NONE_HINT"] = "本週沒有值得砸幣的首領（都殺過了 / 都沒提升）—— 勾上「已殺的也算」看全部"
        t["RV_RESCAN_TIP"] = "重新讀冒險指南的掉落（換專精 / 換裝備後用）"
        t["RV_SAME"] = "同裝等"
        t["RV_SUB2"] = "%s · %s難度 · 3 枚幣全砸下去，約 %s 機率至少中一件對你有用的（其中 %s 是真提升）"
        t["RV_TITLE2"] = "Roll 幣怎麼花 · 本週 3 枚幣砸哪三個首領"
        t["RV_TOP3_2"] = "這週 3 枚幣砸這裡"
        t["RV_TOP3_TIP2"] = "按「這個首領的掉落對你平均有多大提升」排序。本週該難度已殺的首領不進三選（勾「已殺的也算」看全部）。\n⛔ 插件只提示，不會自動幫你用幣。"
        t["RV_TT_SCORE"] = "綜合得分 %d（裝等差 × 部位權重 + BiS/套裝/軌道）"
        t["RV_DONE"] = "[本週已殺]"
        t["RV_EJ_OPEN"] = "先關掉冒險指南再看（掃描要借用它的篩選狀態）"
        t["RV_ENTER"] = "本週 roll 幣砸：%s · 3 幣至少中一件有用 %s · /gi roll 看明細"
        t["RV_ENTER_NONE"] = "這本這個難度沒有值得用 roll 幣的首領（/gi roll 看明細）"
        t["RV_EXP"] = "期望"
        t["RV_FARM"] = "[傳奇鑰石可刷]"
        t["RV_INCL_DONE"] = "已殺的也算"
        t["RV_LOADING"] = "冒險指南的掉落還在載入，1 秒後自動重試…"
        t["RV_NONE"] = "沒有值得用幣的首領（都殺了 / 都沒提升）"
        t["RV_NO_API"] = "這個客戶端沒有冒險指南介面"
        t["RV_NO_INST"] = "找不到本賽季團本（BisData 沒載入好？）"
        t["RV_PROMPT_TOGGLE"] = "進本 roll 幣提示："
        t["RV_P_GOOD"] = "值得要"
        t["RV_P_ROLL"] = "roll 到"
        t["RV_P_USEFUL"] = "中有用件"
        t["RV_RESCAN"] = "重掃"
        t["RV_R_BIS"] = "BiS 第 %d 候選 +%d"
        t["RV_R_BIS_LOW"] = "BiS 同款低一檔 +%d"
        t["RV_R_ILVL"] = "裝等 +%d（%s）"
        t["RV_R_ILVL_DOWN"] = "裝等 %d，比身上低"
        t["RV_R_MPLUS"] = "鑰石也掉同槽同檔 ×0.5"
        t["RV_R_NOT_BIS_CAP"] = "不在本專精 BiS 名單裡，最高只算「值得要」"
        t["RV_R_MUST_BIS"] = "本專精 BiS 第 1（項鍊 / 飾品前 2）→ 必 roll"
        t["RV_R_OWNED3"] = "身上已有同檔或更高：不算提升，但仍在 Roll 幣池子裡，可能 roll 到重複件"
        t["TOPN_TITLE_SUFFIX"] = " 9483 使用率前 %d 名"
        t["TOPN_CLICK_HINT"] = "點擊檢視此部位使用率前 9 名"
        t["TOPN_BTN"] = "前9"
        t["TOPN_BTN_TT"] = "檢視此部位使用率前 9 名"
        t["GM_CLICK_TOPN"] = "點擊：該部位使用率前 9 名"
        t["PDB_CLICK_N"] = "點擊檢視本部位使用率前 9 名"
        t["RV_BONUS_GUARD_TT"] = "GearInsight：點一下確認，再點一次才真的用幣"
        t["RV_BONUS_CONFIRM"] = "確定要 ROLL 嗎？4 秒內再點一次 ROLL"
        t["RV_BONUS_NA"] = "這裡算不出來"
        t["RV_BONUS_NA_BODY"] = "沒認出是哪個首領 / 副本（或掉落資料還在載入）。打開 /gi roll 看完整列表。"
        t["RV_BONUS_YES"] = "建議 ROLL"
        t["RV_BONUS_MAYBE"] = "可以 ROLL（沒有必 roll 件）"
        t["RV_BONUS_NO"] = "不建議 ROLL"
        t["RV_BONUS_MUST"] = "必 roll %d/%d 件（%.0f%%）· 有用 %d 件（%.0f%%）"
        t["RV_BONUS_OWNED"] = "身上已有 %d 件仍在池子裡，可能 roll 到重複"
        t["TPG_MINE"] = "你身上"
        t["TPG_TALENT"] = "複製天賦碼 / 一鍵套用"
        t["TPG_FOOT"] = "懸停看完整屬性 · Shift+點擊發到聊天"
        t["TPG_SUB"] = "WCL 上榜時身上的整套裝備 · 附魔 · 寶石"
        t["TPG_NONE"] = "這條紀錄沒有裝備資料（等下次資料更新）"
        t["TPG_ENCH"] = "已附魔"
        t["TPG_SAME"] = "同款"
        t["TPG_GEAR_BTN"] = "查看裝備"
        t["TPG_HIS"] = "他身上"
        t["TPG_WCL"] = "WCL 連結"
        t["TPG_FOOT2"] = "懸停看完整屬性 · Shift+點擊發到聊天"
        t["TPG_BJT"] = "北京時間"
        t["TPG_DUR"] = "時長 %d:%02d"
        t["TPG_WCL_HINT"] = "Ctrl+C 複製，到瀏覽器打開這場戰鬥的 WCL 紀錄"
        t["TPG_WCL_TITLE"] = "WCL · 這場戰鬥"
        t["TP_ALT_BRANCH"] = "另一分支第一"
        t["TP_WORLD_RANK"] = "世界 #%d"
        t["RV_BTN_TIP2"] = "Roll 幣要在週三的低保裡選（不拿裝備，換一枚），平時拿不到。這裡按你身上 Roll 幣的實際數量，推薦砸哪幾個首領 / 大秘境：按 BiS 排名 + 軌道 + 套裝給每件掉落打分，已擊殺的首領自動排除，帶 roll 到的機率。週三開寶庫時右側自動出「低保怎麼選」。"
        t["RV_TITLE3"] = "Roll 幣怎麼花 · 你身上 %d 枚，砸哪 %d 個 boss"
        t["RV_ENTER2"] = "本週 roll 幣砸：%s · %d 幣至少中一件有用 %s · /gi roll 看明細"
        t["RV_TITLE_ZERO"] = "Roll 幣怎麼花 · 你身上 0 枚 · 假設拿一枚幣這樣用"
        t["RV_SUB4"] = "%s · %s難度 · %d 枚幣全砸下去，約 %s 中一件有用的（其中 %s 是真提升）"
        t["WCONF_2H"] = "雙手"
        t["WCONF_DW"] = "雙持"
        t["WCONF_1HS"] = "單手+盾"
        t["WCONF_1HO"] = "單手+副手"
        t["WCONF_TG"] = "泰坦之握"
        t["WCONF_RANGED"] = "遠程"
        t["WCONF_SCEN_RAID"] = "團本"
        t["WCONF_SCEN_MH"] = "大秘境高層"
        t["WCONF_SCEN_MF"] = "大秘境"
        t["WCONF_MINE"] = "（你）"
        t["WCONF_CMP"] = "武器形態（%s WCL 使用率）：%s"
        t["RV_R_FILLER_RANK"] = "坯子轉換優先級 #%d/%d"
        t["RV_R_FILLER_WORN"] = "；身上這格已是套裝件，不按催化算"
        t["RV_R_FILLER"] = "催化成 %s 後 = BiS #%d +%d"
        t["RV_R_FILLER_SET"] = "，套裝 %d→%d 件 +%d"
        t["RV_R_VAULT_NOT_BIS"] = "不在本專精 BiS 前 3、也不是套裝坯子 ×0.5"
        t["RV_R_MYTH_RULE"] = "神話軌：不比裝等，按軌道 + BiS 排名打分"
        t["RV_R_MYTH_CAT"] = "（催化成 %s）"
        t["RV_R_UNRANKED"] = "未上榜"
        t["RV_R_EMPTY_SLOT"] = "空槽"
        t["RV_R_MYTH_RANK"] = "BiS 排名：身上 %s → 新件 %s（%+d）"
        t["RV_R_MYTH_SAME"] = "身上已是神話軌，軌道不加分"
        t["RV_R_NO_TRACK"] = "無軌道"
        t["RV_R_MYTH_NOTRACK_HIGH"] = "身上無升級軌道且裝等不低於新件升滿，軌道不加分"
        t["RV_R_OTHER_SPECS"] = "本職業其它專精也上榜（%s）+%d"
        t["RV_R_FILLER_SWAP"] = "催化後替換身上套裝（%s）：身上 %s → 新件坯子 #%d（%+d）"
        t["RV_R_FILLER_FACTOR"] = " ×%.2f"
        t["RV_R_SET"] = "套裝 %d→%d 件 +%d"
        t["RV_R_TAKEN"] = "本週已拿到"
        t["RV_R_TRACK"] = "軌道 %s→傳奇 +%d"
        t["RV_SUB"] = "3 枚幣至少中一件有用 %s · 值得要 %s"
        t["RV_TAKEN"] = "已拿"
        t["RV_TITLE"] = "Roll 幣三選 · 本週 3 枚幣砸哪三個首領"
        t["RV_TOP3"] = "本週用幣："
        t["RV_TOP3_TIP"] = "按「首領期望分」排：Σ(能用的件得分) ÷ 能用件數。本週該難度已殺的首領不進三選（勾「已殺的也算」看全部）。⛔ 插件只提示，不會自動用幣。"
        t["RV_TRACK_MYTH"] = "傳奇"
        t["RV_USE_COIN"] = "|cFFFFD100★ %s 是本週三選第 %d：這個首領用 roll 幣|r（中有用件 %s）"
        t["RV_VAULT_EMPTY"] = "還沒有可選的獎勵（本週沒達到任何檔位，或介面還在載入）"
        t["RV_VAULT_EXPORT"] = "匯出到網頁看完整推薦"
        t["RV_VAULT_EXPORT_FAIL"] = "匯出失敗：裝備快照沒準備好，/gi refresh 後再試"
        t["RV_VAULT_EXPORT_HINT"] = "Ctrl+C 複製，貼到網站「保底推薦」頁"
        t["RV_VAULT_EXPORT_TITLE"] = "保底匯出串"
        t["RV_VAULT_HOWTO"] = "打開每週寶庫（週三開箱介面）時，右側會自動出現「保底怎麼選」；匯出串也在那裡"
        t["RV_VAULT_NONE"] = "都不是提升（全部 <15 分）：拿貨幣 / 隨便挑一件分解"
        t["RV_VAULT_PICK"] = "選這件："
        t["RV_VAULT_TITLE"] = "GearInsight · 保底怎麼選"
        t["RV_VT_MPLUS"] = "鑰石"
        t["RV_VT_PVP"] = "PvP"
        t["RV_VT_RAID"] = "團本"
        t["RV_VT_WORLD"] = "地下堡"
        t["RV_V_MUST"] = "必 roll"
        t["RV_V_WANT"] = "值得要"
        t["RV_V_MINOR"] = "小提升"
        t["RV_V_PASS"] = "讓人"
        t["RV_SLOT_1"] = "頭部"
        t["RV_SLOT_2"] = "頸部"
        t["RV_SLOT_3"] = "肩部"
        t["RV_SLOT_5"] = "胸部"
        t["RV_SLOT_6"] = "腰部"
        t["RV_SLOT_7"] = "腿部"
        t["RV_SLOT_8"] = "腳"
        t["RV_SLOT_9"] = "手腕"
        t["RV_SLOT_10"] = "手"
        t["RV_SLOT_11"] = "戒指"
        t["RV_SLOT_12"] = "戒指"
        t["RV_SLOT_13"] = "飾品"
        t["RV_SLOT_14"] = "飾品"
        t["RV_SLOT_15"] = "披風"
        t["RV_SLOT_16"] = "主手"
        t["RV_SLOT_17"] = "副手"
    end
end

-- Vault release 0.92.19
do
    local t = GearInsight.LOC["zhTW"]
    t["RV_PERSONAL_ALL"] = "全部裝備"
    t["RV_PERSONAL_LIMITED"] = "提升有限"
    t["RV_PERSONAL_NO_GAIN"] = "無提升"
    t["RV_ROLL_EXPORT_CLOSE_EJ"] = "請先關閉冒險指南，再點擊匯出以讀取 Roll 幣評估。"
    t["RV_ROLL_EXPORT_LOADING"] = "Roll 幣掉落資料仍在載入，請稍後重新匯出。"
    t["RV_ROLL_EXPORT_NO_API"] = "Roll 幣掉落介面尚不可用，請開啟 /gi roll 後重新匯出。"
    t["RV_ROLL_EXPORT_NO_RAID"] = "未找到當前賽季團隊副本，請更新插件資料後重新匯出。"
    t["RV_ROLL_EXPORT_WAIT"] = "正在載入 Roll 幣評估，完成後會自動產生匯出連結…"
    t["RV_R_ARMS_ONEHAND"] = "武器戰士使用雙手武器，這把單手武器不適合當前專精"
    t["RV_R_CURRENT_BIS"] = "身上裝備排名不低於新件，升滿裝等也不低，不加 BiS 分"
    t["RV_R_CURRENT_COMPARE"] = "當前裝等：身上 %d → 新件 %d（%+d）"
    t["RV_R_MAXED_COMPARE"] = "按軌道升滿比較：新件 %d，身上 %d"
    t["RV_R_NOT_TOP_BIS"] = "不在當前評分候選前 3 名，不加 BiS 分"
    t["RV_VAULT_ASK_EMPTY"] = "尚未讀到可領取裝備，請開啟寶庫領取介面，獎勵載入後再求助好友。"
    t["RV_VAULT_ASK_FRIENDS"] = "一鍵求助好友"
    t["RV_VAULT_ASK_HINT"] = "Ctrl+C 複製連結，到瀏覽器開啟；當前裝備和寶庫候選會一起產生求助卡，把連結傳給好友或公會，大家一起幫你選。"
    t["RV_VAULT_CLAIM_ROWS"] = "本次可領取"
    t["RV_VAULT_CLEAR_GAIN"] = "明顯提升"
    t["RV_VAULT_ERR_TITLE"] = "推薦計算失敗"
    t["RV_VAULT_EXPORT_NO_ITEMS"] = "尚未讀到可領取裝備，此連結只包含身上裝備；如有待領取獎勵，請等寶庫載入完成再匯出。"
    t["RV_VAULT_EXPORT_SHORT"] = "匯出到網頁"
    t["RV_VAULT_ILVL"] = "物品等級 %d"
    t["RV_VAULT_ILVL_MAX"] = "物品等級 %d · 升滿 %d"
    t["RV_VAULT_TAG_FILLER"] = " · |cFF8CC8FF坯子#%d→套裝BiS#%d|r"
    t["RV_VAULT_TAG_FILLER2"] = " · |cFF8CC8FF坯子#%d/%d|r"
    t["RV_VAULT_TAG_BIS"] = " · |cFFFFD100BiS#%d|r"
    t["RV_VAULT_LARGE_GAIN"] = "大提升"
    t["RV_VAULT_LIST2"] = "可選裝備 · %d 件（滑鼠移入查看屬性）"
    t["RV_VAULT_LOADING"] = "獎勵尚未讀取完成，請在寶庫處開啟領取介面，稍後會自動重新整理。"
    t["RV_VAULT_NO_PICK"] = "當前沒有可選裝備"
    t["RV_VAULT_NO_PROGRESS"] = "暫無進度資料"
    t["RV_VAULT_NO_REWARDS"] = "當前沒有可領取獎勵；上方是本週累計進度，預覽裝備不參與推薦。"
    t["RV_VAULT_PENDING"] = "獎勵仍在載入，暫不推薦；資料齊全後會自動重新整理。"
    t["RV_VAULT_PENDING_TITLE"] = "獎勵載入中"
    t["RV_VAULT_PICK_COIN"] = "推薦：選擇 Roll 幣"
    t["RV_VAULT_PICK_COIN_REASON"] = "%d 件裝備評分都低於 15，沒有明顯提升；直接拿寶庫底部的 Roll 幣。"
    t["RV_VAULT_PICK_COIN_VALUE"] = "Roll 幣值 %d 分（你打到%s%d，砸 %s 期望 %+.1f ×%.2f）高於最佳裝備 %d 分。"
    t["RV_VAULT_COIN_ABOVE"] = "，高於最佳裝備 %d 分。"
    t["RV_VAULT_COIN_MP"] = "大秘境·"
    t["RV_VAULT_COIN_LINE"] = "Roll 幣 %d 分：砸 %s，最好「%s」+%d × %s機率 %.0f%% × %.2f"
    t["RV_VAULT_COIN_LINE3"] = "Roll 幣 %d 分：砸 %s，必 roll %d/%d 件（機率 %.1f%%），最好「%s」+%d，期望 %+.1f × %.2f"
    t["RV_VAULT_COIN_SUB2"] = "砸 %s · 必roll %s +%d · 機率 %.1f%%"
    t["RV_VAULT_LATE"] = "能打 H7/8"
    t["RV_VAULT_LATE_MANUAL"] = "（手動）"
    t["RV_VAULT_LATE_AUTO"] = "（自動）"
    t["RV_VAULT_LATE_TT"] = "能打團本英雄第 7、8 個 boss（或有傳奇進度）：Roll 幣可以砸到後面的 boss，幣值 ×1.25；打不到 ×0.8。\n預設按你的擊殺紀錄自動判斷，也可以手動勾選 / 取消。"
    t["RV_PLAN_NONE"] = "不打團"
    t["RV_PLAN_H6"] = "H 1-6"
    t["RV_PLAN_H8"] = "H 全通"
    t["RV_PLAN_M"] = "M"
    t["RV_PLAN_AUTO"] = "自動：%s%d"
    t["RV_PLAN_AUTO_NONE"] = "自動：無擊殺紀錄"
    t["RV_PLAN_BTN"] = "團本："
    t["RV_PLAN_TT"] = "團本進度決定 Roll 幣能砸哪些 boss：H 本用幣出傳奇檔裝備。\n自動 = 按你的擊殺紀錄；點一下換一檔：不打團（只算大秘境）/ H 1-6（前 6 個 boss，×0.8）/ H 全通（×1.25）/ M（×1.25），再 × 稀缺 1.3。"
    t["RV_PLAN_NONE2"] = "打不了 H"
    t["RV_PLAN_H6B"] = "能打 H1-6"
    t["RV_PLAN_H8B"] = "能打 H1-8"
    t["RV_PLAN_TT2"] = "團本進度決定 Roll 幣能砸哪些 boss：H 難度 boss 用 Roll 幣、開低保都出神話軌裝備。\n自動 = 按你的擊殺紀錄；點一下換一檔：打不了 H（只算大秘境）/ 能打 H1-6（前 6 個 boss，×0.8）/ 能打 H1-8（全部 boss，×1.25），再 × 稀缺 1.3。"
    t["RV_PLAN_TT3"] = "團本進度決定 Roll 幣能砸哪些 boss：H 難度 boss 用 Roll 幣、開低保都出神話軌裝備。\n點一下換一檔：打不了 H（只算大秘境）/ 能打 H1-6（前 6 個 boss，×0.8）/ 能打 H1-8（全部 boss，×1.25），再 × 稀缺 1.3。"
    t["RV_VAULT_COIN_NONE"] = "按目前團本進度，能砸的 boss 和大秘境裡都沒有「必 roll」裝備（或掉落資料還在載入），Roll 幣記 0 分。可以點「團本」按鈕換進度。"
    t["RV_VAULT_COIN_NONE_SUB"] = "沒有必 roll 裝備可砸"
    t["RV_ROLLED2"] = "已ROLL到"
    t["RV_ROLLED_TAG"] = "[已ROLL到 · 右鍵取消]"
    t["RV_VAULT_COIN_ROW"] = "Roll 幣"
    t["RV_VAULT_COIN_SRC"] = "寶庫幣"
    t["RV_VAULT_COIN_SUB"] = "砸 %s · 最好 %s +%d · 機率 %.0f%%"
    t["RV_VAULT_COIN_GOOD"] = "值得要"
    t["RV_VAULT_COIN_USEFUL"] = "有用"
    t["RV_HINT_MARK"] = "右鍵裝備 = 標記「用幣 roll 到過」（出池，其餘件機率上升，一直保留） · Shift+右鍵 = 不算在池子裡 · 右鍵 boss = 本週已用幣"
    t["RV_VAULT_ROLL_POOL"] = "Roll 幣池子：標記 roll 到過的裝備"
    t["RV_VAULT_PICK_ITEM2"] = "推薦裝備：%s"
    t["RV_VAULT_PICK_REASON2"] = "%s · 物品等級 %d · 評分 %+d"
    t["RV_VAULT_PROGRESS_ROWS"] = "本週進度（下次獎勵）"
    t["RV_VAULT_SCORE_LABEL"] = "評分 %d"
    t["RV_VAULT_TT_CHAT"] = "Shift+點擊傳送到聊天"
    t["RV_VAULT_TT_SCORE"] = "GearInsight 評分"
    t["RV_VAULT_TT_SOURCE"] = "寶庫來源"
    t["RV_VAULT_WAIT_EXPORT"] = "獎勵仍在載入，請稍後再匯出。"
    t["RV_VT_DUNGEONS"] = "地下城"
    t["RV_VT_WORLD_ROW"] = "世界"
end

-- Saved layout talent associations
GearInsight.LOC["zhTW"]["LY_BACKUP_LABEL"] = "按鍵："
GearInsight.LOC["zhTW"]["LY_TB_MACRO_LABEL"] = "巨集"
GearInsight.LOC["zhTW"]["LY_TB_MACRO_HINT"] = "這個按鍵執行包含當前技能的巨集；不代表按一次就一定施放該技能。"
GearInsight.LOC["zhTW"]["LY_TALENT_LABEL"] = "天賦："
GearInsight.LOC["zhTW"]["RV_VAULT_WECHAT"] = "求助好友（分享連結）"
do
    local t = GearInsight.LOC["zhTW"]
    t["LY_BTN_OVERWRITE"] = "覆蓋儲存"
    t["LY_OVERWRITE_ASK"] = "用當前角色、專精的快捷列、巨集和按鍵覆蓋這份存檔？\n%s\n保留名稱和永久標記，原按鍵內容會被替換。"
    t["LY_OVERWRITE_DONE"] = "已覆蓋儲存：%s"
    t["LY_OVERWRITE_MISSING"] = "這份存檔已不存在，請重新整理列表後重試。"
    t["LY_DELETE_PINNED_ASK"] = "確定刪除這份永久按鍵存檔？\n%s\n刪除後無法從列表還原，與它關聯的天賦自動還原也會取消。"
    t["LY_TALENT_CUSTOM"] = "當前自訂天賦"
    t["LY_TALENT_OLD"] = "這份存檔未記錄當前角色的天賦，請切到正確天賦後覆蓋儲存。"
    t["LY_TALENT_BEFORE"] = "天賦連動還原前"
    t["LY_TALENT_AUTO"] = "切換天賦自動還原關聯按鍵"
    t["LY_TALENT_UNDO"] = "撤回上次連動"
    t["LY_TALENT_NONE"] = "天賦：未記錄"
    t["LY_TALENT_VIEW"] = "點擊查看儲存時的完整天賦；舊存檔可用覆蓋儲存補上。"
    t["RV_VAULT_NEVER"] = "不再彈出"
    t["RV_VAULT_OFF_MSG"] = "已關閉：以後開啟宏偉寶庫不再顯示「低保怎麼選」。想看時輸入 /gi vault，恢復自動顯示用 /gi vault on 或設定頁。"
    t["RV_VAULT_ON_MSG"] = "已開啟：開啟宏偉寶庫時自動顯示「低保怎麼選」。"
    t["CFG_VAULT"] = "開啟宏偉寶庫時顯示「低保怎麼選」"
    t["CFG_VAULT_D"] = "寶庫右側的推薦面板（含求助好友）。關閉後可輸入 /gi vault 手動叫出。"
    t["RV_VAULT_WECHAT"] = "求助好友（分享連結）"
    t["LY_TALENT_LINK"] = "關聯此天賦（自動標為永久）"
end

-- My BiS plan (core/BisPlan.lua, ui/PlanPage.lua) 09-23
do
    local t = GearInsight.LOC["zhTW"]
    t["OV_LEVELING"] = "升級中 %d/%d：滿級後再看差距"
    t["BP_BTN_CLEAR"] = "清空"
    t["BP_BTN_DATA"] = "從資料推薦生成"
    t["BP_BTN_EQUIP"] = "從身上生成"
    t["BP_BTN_EXPORT"] = "匯出"
    t["BP_BTN_IMPORT"] = "匯入"
    t["BP_CHIP_TT"] = "每個專精可存 3 套方案；綠點 = 正在生效的那套。"
    t["BP_CK_DUP"] = "戒指 / 飾品選了同一件（唯一裝備穿不了兩件）"
    t["BP_CK_EMPTY"] = "%d 格沒填：按資料推薦補"
    t["BP_CK_TIER"] = "套裝 %d 件"
    t["BP_CK_TIER_LOW"] = "（不足 4 件）"
    t["BP_CK_TITLE"] = "能不能穿上"
    t["BP_CK_UNIQUE"] = "戒指 / 飾品不重複"
    t["BP_CK_WEAPON"] = "武器搭配可穿"
    t["BP_CK_WEAPON_BAD"] = "雙手武器不能再配副手（只有狂怒戰士能雙持雙手）"
    t["BP_CLEAR_ASK"] = "清空「%s」這套方案？\n清空後這套不再生效，插件回到資料推薦。"
    t["BP_DIFF"] = "與資料推薦不同：|cffffd133%d|r 格"
    t["BP_DIFF_NONE"] = "這套方案還是空的"
    t["BP_EMPTY"] = "（空）"
    t["BP_EXPORT_EMPTY"] = "這套方案還是空的：先點格子選裝備，或「從資料推薦生成」"
    t["BP_EXPORT_HINT"] = "Ctrl+C 複製。網站 / 小程式 / 別人的插件都能匯入這串（三端通用）。"
    t["BP_EXPORT_TITLE"] = "方案串 · GIB1"
    t["BP_E_SPEC"] = "這個方案的專精插件裡沒有資料"
    t["BP_FOOT"] = "方案串三端通用 · 插件 / 網站 / 小程式"
    t["BP_HINT"] = "點格子選裝備 · 右鍵選升級軌道 · 選中格子後 Shift+點擊物品連結或拖入物品 · 沒填的格子按資料推薦"
    t["BP_IMPORT_OK"] = "已匯入到「%s」方案，點上方開關即可啟用。"
    t["BP_IMPORT_OTHER"] = "已匯入到「%s」的「%s」方案（不是你當前專精，切過去才會看到）。"
    t["BP_IMPORT_SUB"] = "貼上 GIB1 開頭的串或整條連結（網站 / 小程式 / 別人的插件匯出的都行）"
    t["BP_IMPORT_TITLE"] = "匯入方案串"
    t["BP_LEG_CUR"] = "身上"
    t["BP_LEG_PLAN"] = "方案"
    t["BP_MENU_CLEAR"] = "清空此格（回到資料推薦）"
    t["BP_MENU_EQUIPPED"] = "用身上這件："
    t["BP_MENU_HINT"] = "也可以：選中這格後 Shift+點擊任意物品連結，或把物品拖到格子上"
    t["BP_MENU_TITLE"] = "頂尖玩家實穿（使用率）"
    t["BP_MODE_AUTO"] = "目標 = 方案各件副屬性的佔比（自動）"
    t["BP_MODE_P"] = "目標 = 匯入的屬性優先級"
    t["BP_MODE_T"] = "目標 = 方案各件副屬性佔比（匯入的閾值另行顯示）"
    t["BP_MODE_W"] = "目標 = 匯入的屬性權重"
    t["BP_NA"] = "「我的 BiS」還在測試，這個版本沒有帶"
    t["BP_NOT_GEAR"] = "這不是能穿的裝備"
    t["BP_NO_SPEC"] = "讀不到當前專精的 BiS 資料"
    t["BP_OFF_MSG"] = "已切回資料推薦：插件各處按 WCL 頂尖玩家使用率推薦。"
    t["BP_ON_MSG"] = "已啟用「%s」方案：裝備總覽、角色面板、滑鼠提示、刷本規劃、低保、屬性目標都按它走。"
    t["BP_STAT_SUB"] = "身上 → 方案"
    t["BP_STAT_TAG"] = "[我的方案]"
    t["BP_STAT_TITLE"] = "屬性配比"
    t["BP_TAG_DATA"] = "資料推薦"
    t["BP_TAG_MINE"] = "自選"
    t["BP_TAG_SAME"] = "同資料"
    t["BP_TOGGLE_OFF"] = "啟用這套方案"
    t["BP_TOGGLE_ON"] = "● 正在生效 · 點擊關閉"
    t["BP_TOGGLE_SWITCH"] = "改用這套方案"
    t["BP_TOGGLE_TT"] = "啟用後，插件裡所有「推薦哪件 / 算不算畢業 / 屬性目標」都按這套方案；關掉就回到 WCL 頂尖玩家使用率。"
    t["BP_TOGGLE_TT_T"] = "BiS 依據"
    t["BP_TRACK_TITLE"] = "目標升級軌道"
    t["BP_TR_X_TIP"] = "按資料裡頂尖玩家那件"
    t["MT_TAB_PLAN"] = "我的 BiS"
    t["MT_TAB_PLAN_TITLE"] = "我的 BiS · 自己定每個部位，全插件跟著走"
    t["BP_S1"] = "頭部"
    t["BP_S2"] = "項鍊"
    t["BP_S3"] = "肩部"
    t["BP_S15"] = "披風"
    t["BP_S5"] = "胸部"
    t["BP_S9"] = "護腕"
    t["BP_S10"] = "手套"
    t["BP_S6"] = "腰帶"
    t["BP_S7"] = "腿部"
    t["BP_S8"] = "腳部"
    t["BP_S11"] = "戒指 1"
    t["BP_S12"] = "戒指 2"
    t["BP_S13"] = "飾品 1"
    t["BP_S14"] = "飾品 2"
    t["BP_S16"] = "主手"
    t["BP_S17"] = "副手"
    t["BP_TR_M"] = "神話"
    t["BP_TR_H"] = "英雄"
    t["BP_TR_C"] = "勇士"
    t["BP_TR_V"] = "老兵"
    t["BP_TR_X"] = "資料檔"
    t["BP_P_RAID"] = "團本"
    t["BP_P_MPLUS"] = "大米"
    t["BP_P_CUSTOM"] = "自訂"
    t["BP_E_EMPTY"] = "沒收到方案串：在插件方案頁點「匯出」，或在網站配裝頁點「複製方案串」，把整條貼過來"
    t["BP_E_VAULT"] = "這是「宏偉寶庫」的匯出串，不是配裝方案：請到網站寶庫頁貼上"
    t["BP_E_ANALYZE"] = "這是「裝備分析」的匯出串，不是配裝方案。方案串以 GIB1. 開頭"
    t["BP_E_LONG"] = "串太長了：確認只貼了一條方案串，沒把整段聊天紀錄帶上"
    t["BP_E_FORMAT"] = "不是方案串：應為 GIB1.<資料>.<校驗> 三段"
    t["BP_E_TRUNC"] = "方案串被截斷了：複製時沒選全（聊天軟體常把長連結折斷），回去重新複製一次完整的"
    t["BP_E_CHECK"] = "校驗碼對不上：方案串中途被改動過，回去重新複製一次，別手工編輯"
    t["BP_E_DECODE"] = "方案串解不開：內容不是 GearInsight 匯出的格式"
    t["BP_E_VERSION"] = "這是更新版本的方案串：請把插件更新到最新版再匯入"
    t["BP_E_FIELDS"] = "方案串欄位不全"
end

-- Named plan archives (0.93.19)
do
    local t = GearInsight.LOC["zhTW"]
    t["BP_ARCHIVE_HELP"] = "覆蓋儲存使用目前編輯的配裝；刪除只移除存檔。"
    t["BP_ARCHIVE_INFO"] = "%d 件 · 儲存於 %s"
    t["BP_ARCHIVE_NO_TALENT"] = "未記錄天賦"
    t["BP_CHIP_ARCHIVE_TT"] = "三個工作方案分別編輯；更多配裝可命名存檔。綠點 = 正在生效。"
    t["BP_DELETE_ARCHIVE_ASK"] = "刪除配裝存檔「%s」？"
    t["BP_DELETE_NAMED"] = "刪除"
    t["BP_LOAD_NAMED"] = "載入"
    t["BP_LOAD_NAMED_ASK"] = "載入「%s」到目前方案？目前方案的內容將被取代。"
    t["BP_MENU_EQUIPPED_ACTUAL"] = "使用目前穿戴："
    t["BP_MENU_EQUIPPED_ILVL"] = "裝等 %d"
    t["BP_NO_SAVED_PLANS"] = "還沒有存檔，先點擊「儲存配裝」"
    t["BP_OVERWRITE_ARCHIVE_ASK"] = "用目前編輯的配裝覆蓋「%s」？原存檔內容將被取代。"
    t["BP_OVERWRITE_NAMED"] = "覆蓋儲存"
    t["BP_SAVED_PLANS"] = "已存配裝"
    t["BP_SAVE_DONE"] = "已儲存配裝："
    t["BP_SAVE_EMPTY"] = "先選擇裝備再儲存配裝。"
    t["BP_SAVE_ICON"] = "選擇圖示：點擊這套配裝中的任意一件裝備"
    t["BP_SAVE_LIMIT"] = "每個專精最多儲存 10 套配裝，請覆蓋或刪除已有存檔。"
    t["BP_SAVE_NAMED"] = "儲存配裝"
    t["BP_SAVE_NAME_REQUIRED"] = "請輸入配裝名稱"
    t["BP_TALENT_CUSTOM"] = "目前自訂天賦"
end

-- 發版閘門語系補充（0.94.10）
do
    local t = GearInsight.LOC["zhTW"]
    t["BP_FILL_NEED_PLAN"] = "請先點「從資料推薦產生」或「從身上產生」建立方案，再補齊附魔、寶石和美化。"
    t["CH_MARK_DAILY"] = "標記日常"
    t["OV_WCL_MAX"] = "WCL 最高實穿："
    t["PN_KICK"] = "必斷"
    t["PN_LAST"] = "下一波：已是最後一波"
    t["PN_NEXT"] = "下一波："
    t["PN_UNITS"] = "隻"
    t["TTBIS_VENOM_CATALYST"] = "化生轉換 · M8 烏拉特克毒咒坯子"
    t["MODE_MCOMMON"] = "常規"
    t["MODE_TIP_COMMON"] = "常規隊伍屬性目標；只切換綠字參照"
    t["TIER_ATTRIBUTE_HINT"] = "屬性推薦：按目標裝等的完整副屬性評分；同分並列。"
    t["CFG_ROLL_ADVICE"] = "Roll 幣提醒"
    t["CFG_ROLL_ADVICE_D"] = "預設開啟。在暴雪 Roll 視窗旁顯示用幣建議與確認提醒；關閉後立即隱藏插件提醒，保留暴雪原生 Roll 按鈕。"
    t["CHAT_ITEM_LOADING"] = "物品資訊載入中，請稍後再次 Shift 點擊。"
end
