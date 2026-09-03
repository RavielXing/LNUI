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
    MLEVEL_FMT         = "+%d 層（本週 +%d~+%d）",
    MLEVEL_FMT_ONE     = "+%d 層",
    TTBIS_FILLER_RANK  = "  · 轉換優先度 #%d/%d",
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
    FG_CRAFTED_NOTE    = "製造裝備無法刷本取得，需專業製作或拍賣場購買（僅列最值得做的2個部位）",
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
    FG_ONLYTOP_TIP       = "只顯示每個部位排第一的畢業件。\n戒指/飾品/武器這類成對部位只留 #1，催化坯子行也一併隱去。",
    MT_TAB_WISH          = "心願單",
    WLP_SUB              = "來源：%s   ·   共 %d 件",
    WLP_SRC_RECS         = "下一步建議（你缺且能提升的）",
    WLP_SRC_BIS          = "本專精 BiS 全表（建議數據不新鮮，已回退）",
    WLP_SRC_NONE         = "暫無數據",
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

    -- Telegram（非中文客戶端社群；繁中一併給出，避免回退到簡體）
    L["TG_TITLE"]   = "Telegram 群組"
    L["TG_LABEL"]   = "Telegram："
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
        t["MM_SAME_SRC"] = "與官網 gearinsight.app 同源"
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
    t["MT_TAB_TOOLS"] = "實用工具"
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
