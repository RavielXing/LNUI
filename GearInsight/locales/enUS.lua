-- GearInsight - English locale overrides.
-- Only consumed on non-zhCN clients (see T() in GearInsight.lua). The zhCN build
-- never reads this file, so adding/changing keys here cannot affect the Chinese version.

GearInsight = GearInsight or {}
GearInsight.LOC = GearInsight.LOC or {}

GearInsight.LOC["enUS"] = {
    -- Panel: titles / sections / buttons
    PANEL_TITLE        = "GearInsight",
    -- WCL talent library (picker)
    TALENT_BTN         = "WCL Builds",
    TALENT_TIP         = "Top players' talent builds (Raid / Push / Farm, top 5 each). Pick one to copy its import string.",
    TALENT_NODATA      = "No talent data for this spec (are you on the right spec?)",
    TALENT_PICK_TITLE  = "WCL Top Talent Builds",
    TALENT_PICK_HINT   = "Click a header to switch boss/dungeon · click a row to copy",
    TALENT_SWITCH_TIP  = "Left-click: next · Right-click: previous boss/dungeon",
    TALENT_COPY_HINT   = "Ctrl+C the code → paste into the talent UI's Import. The name below is for the loadout.",
    COPY_NAME_LABEL    = "Name",
    FOOD_GRP_FEAST     = "Feast",
    FOOD_GRP_MAIN      = "Solo (Primary stat)",
    FOOD_GRP_SINGLE    = "Solo (Secondary stat)",
    TALENT_IMPORT_BTN  = "One-click Import",
    TALENT_IMPORT_OK2  = "Imported '%s' → click Apply Changes in the talent UI",
    TALENT_APPLY_FALLBACK = ", falling back to manual import",
    TALENT_IMPORT_OK   = "Talent UI opened: Loadout dropdown (bottom-left) → Import → Ctrl+V (Ctrl+C the string here first)",
    TALENT_IMPORT_FAIL = "Import failed: ",
    TALENT_COPY_TITLE  = "WCL %s · %s #%d",
    TALENT_FAIL        = "Failed: ",
    -- M+ dungeon guide (WCL deaths/interrupts aggregation)
    DG_BTN             = "M+ Guide",
    DG_TIP             = "Mythic+ guide from real WCL data — what actually kills players, what top players interrupt (and skip), and damage taken before deaths. Auto-opens when you enter a dungeon.",
    DG_TITLE           = "M+ Guide",
    DG_NODATA          = "M+ guide data not loaded",
    DG_AUTOPOP         = "Auto-open on dungeon entry",
    DG_SOURCE          = "Data: real WCL runs (high keys + 12s)",
    DG_SEC_KICKS       = "1. Interrupt priority (top players' real kick rates)",
    DG_SEC_KILLERS     = "2. Killer abilities (what actually kills)",
    DG_SEC_HEAVY       = "3. Heavy hitters (damage taken before deaths)",
    DG_SAMPLE          = "Sample: %d runs / %d deaths",
    DG_DEATHS          = "deaths",
    DG_BOSS            = "[BOSS]",
    DG_KICK_MUST       = "MUST KICK",
    DG_KICK_HIGH       = "High",
    DG_KICK_MED        = "If free",
    DG_KICK_LOW        = "Skip",
    DG_ZONE_HINT       = "Dungeon guide opened (disable auto-open at the bottom-left of the window)",
    -- Live guide (nameplate watch card + cast alerts)
    LG_TITLE           = "Watch out",
    LG_TOGGLE          = "Live alerts (kicks/killers)",
    LG_LUSTBAR_TOGGLE  = "Lust monitor (lust-point hint + window bar)",
    -- KeyTimeline（钥匙时间轴，2026-09-04）
    KT_TOGGLE          = "Key timeline (lust-point call + boss pace vs top runs)",
    KT_SEG_OPEN        = "opener pull",
    KT_SEG_PRE         = "pack before %s",
    KT_SEG_POST        = "after last boss",
    KT_NTH             = "Lust #%d",
    KT_NEXT            = "Next lust",
    KT_HOLD            = "Hold burst · lust at",
    KT_ETA             = "in ≈%s",
    KT_NOW             = "≈now",
    KT_READY_SHORT     = "lust ready",
    KT_LATE_SHORT      = "lust ready in %s",
    KT_READY           = "your lust is ready",
    KT_READY_IN        = "your lust is ready in %s",
    KT_LUST_ON         = "Lust up — burn cooldowns",
    KT_NO_MORE         = "All consensus lust points of top runs are behind you",
    KT_PACE            = "%s: you %s · top %s (%s%s|r)",
    KT_PACE_FIRST      = "at %s top runs reach %s",
    KT_EVIDENCE        = "top runs lust here in %d%% of runs",
    KT_ALERT_CASTER    = "Lust point: ",
    KT_ALERT_LATE      = "Lust point reached, lust not ready: ",
    KT_ALERT_HOLD      = "Hold burst · lust point: ",
    KT_ALT             = "alternative: %s %d%%",
    KT_TIP_TITLE       = "Key timeline · how top runs play it",
    KT_TIP_BOSSES      = "Boss arrival (high-key median)",
    KT_TIP_LUST        = "Lust points (% of top runs lusting there)",
    KT_TIP_YOU         = "you %s",
    KT_TIP_DRAG        = "drag to move",
    DG_LUST_AT         = "~%.0f min",
    DG_BOSS_PACE       = "Top runs reach: ",
    LG_KILLER          = "Lethal",
    LG_HEAVY           = "Heavy",
    LG_MUST            = "KICK: ",
    LG_HIGH            = "Kick (high): ",
    LG_DODGE           = "Dodge/mitigate: ",
    LG_KILLER_SUB      = "killed players %d times in top runs",
    LG_KICK_READY      = "your interrupt is ready",
    LG_KICK_CD         = "your interrupt: %.1fs cd",
    -- Bloodlust sync
    DG_SEC_LUST        = "4. Bloodlust points (where top groups lust)",
    DG_LUST_FMT        = "lusted here in %d%% of runs · ~%.0f min",
    DG_SEC_LOOT        = "5. Loot pool (your BiS drops here)",
    DG_POOL_SUMMARY    = "BiS: %d/%d still needed · %d side upgrades",
    DG_POOL_GRAD       = "> BiS pieces (roll/need)",
    DG_POOL_FILLER     = "> Side upgrades (off-spec roll)",
    DG_POOL_DONE       = "> %d BiS pieces already obtained here ✓",
    DG_POOL_ALLDONE    = "Nothing left to farm here — all BiS obtained ✓",
    DG_TAG_NEED        = "[NEED]",
    DG_TAG_UP          = "[↑%d]",
    DG_SLOT            = "Slot ",
    DG_POOL_NONE       = "No BiS-relevant drops here for you (your BiS comes mostly from raid/tier sets)",
    DG_POOL_SUMMARY2   = "%d relevant · %d BiS to go · %d upgrades · %d owned",
    DG_POOL_SIDE       = "> %d more BiS-list drops (not an upgrade right now)",
    DG_POOL_DONE2      = "> %d already obtained here ✓",
    IB_LOADING         = "GearInsight: reading gear…",
    IB_LINE            = "GearInsight: BiS %d/%d graduated · %d to go",
    IB_ALLDONE         = "GearInsight: fully BiS (%d/%d) ✓",
    IB_TOGGLE_ON       = "Group hover BiS readout: ON",
    IB_TOGGLE_OFF      = "Group hover BiS readout: OFF",
    GB_TITLE           = "Group BiS Check",
    GB_REFRESH         = "Refresh",
    GB_RANGE           = "out of range",
    GB_LOADING         = "reading…",
    GB_NODATA          = "no BiS data",
    GB_NOENCH          = "no enchant x%d",
    GB_EMPTYSOCK       = "empty socket x%d",
    GB_READY           = "✓ ready",
    GB_SCANNING        = "inspecting…",
    GB_COUNT           = "%d group members",
    GB_UNAVAIL         = "Group BiS Check panel not loaded",
    GLD_TITLE          = "Guild Roster",
    GLD_REFRESH        = "Refresh",
    GLD_COUNT          = "%d online / %d members",
    GLD_OFFLINE        = "offline",
    GLD_AFK            = "away",
    GLD_DND            = "busy",
    GLD_ONLINE         = "online",
    GLD_NOGUILD        = "You're not in a guild",
    GLD_UNAVAIL        = "Guild Roster panel not loaded",
    LG_LUST_TITLE      = "Lust window — burn cooldowns",
    LG_LUST_POINT      = "Lust point",
    LG_LUST_POINT_FMT  = "top groups lust on this pull in %d%% of runs",
    -- Rotation reference (WCL top players)
    ROT_BTN            = "AI Coaching",
    ROT_TIP            = "Top WCL players' real openers, cast frequency and key buff uptimes (Raid / Mythic+), with AI coach notes.",
    ROT_NODATA         = "No rotation data for this spec (are you on the right spec?)",
    ROT_TITLE          = "AI Coaching",
    ROT_HINT           = "AI reads top WCL players' combat data · hover a spell for details",
    ROT_MODE_RAID      = "Raid",
    ROT_MODE_MPLUS     = "Mythic+ (Push)",
    ROT_OPENER         = "Opener",
    ROT_OPENER_SWITCH  = "click to cycle",
    ROT_OPENER_EMPTY   = "(none of these spells known — import this player's talents first)",
    ROT_CORE           = "Cast Frequency",
    ROT_CORE_SUB       = "casts/min · median of top players",
    ROT_PERMIN         = "/min",
    ROT_TIER_CORE      = "core",
    ROT_TIER_OFTEN     = "frequent",
    ROT_TIER_CD        = "CD/situational",
    ROT_NOT_KNOWN      = "not known",
    ROT_TT_NOT_KNOWN   = "Top players use this but you don't know it — most likely an untalented pick (copy a build via \"WCL Builds\"); could also be a trinket spell.",
    ROT_WATCH          = "Buff Watch",
    ROT_WATCH_SUB      = "active upkeep · top players' uptime — lower than this = a skill gap",
    ROT_WATCH_PASSIVE  = "Passive procs (automatic, nothing to press)",
    ROT_MODE_HINT      = "← click to switch (rotations differ a lot)",
    ROT_OPENER_SEE_RAID = "Opener is in the Raid view (a full M+ run has no fixed opener) · click to switch",
    ROT_TT_ACTIVE      = "Active upkeep: top players keep this at %d%%. If yours is lower, this is the thing to practice.",
    ROT_TT_SOURCE      = "Source: %s · automatic, nothing to press",
    ROT_SRC_TALENT     = "Talent: %s",
    ROT_TT_PASSIVE_TALENT = "Source: passive talent/gear · you have it, automatic, nothing to press",
    ROT_TT_PASSIVE_GEAR = "Source: gear/trinket effect · procs automatically (top players have the matching gear)",
    ROT_FOOT           = "Sample: %d top WCL players · gray = not known by you (trinkets / other races' racials / untalented)",
    ROT_PASSIVE_COUNT  = "%d buffs",
    ROT_FOLD_OPEN      = "click to expand",
    ROT_FOLD_CLOSE     = "click to collapse",
    ROT_HAVE           = "you have it",
    ROT_HAVE_NOT       = "not detected",
    ROT_AI_FUNNEL      = "Want AI feedback on YOUR combat data? Export Gear → paste at gearinsight.app → AI Coach",
    ROT_COACH          = "AI Coach Notes",
    ROT_COACH_BY       = "generated offline by an AI model · not real-time",
    ROT_MY             = "you:",
    ROT_MY_ON          = "Live comparison ON: %.1f min / %d fights recorded",
    ROT_MY_RESET       = "click to reset (recommended when switching raid/M+)",
    ROT_MY_OFF         = "Live comparison: fight for 1+ minute and a \"you vs top players\" column appears below",
    ROT_COACH_TIP      = "Generated offline by an AI model when the data is built (no in-game network). The AI only translates the deterministic stats below into plain words — every spell and number comes from top WCL players' logs; nothing beyond the data is added.",
    CONTENT_RAID       = "Raid",
    CONTENT_PUSH       = "Push",
    CONTENT_FARM       = "Farm",
    MLEVEL_HIGH        = "no cap · top keys this week",
    MLEVEL_FARM        = "+12 keys",
    REGION_US = "US", REGION_EU = "EU", REGION_KR = "KR", REGION_TW = "TW", REGION_CN = "CN", REGION_RU = "RU",
    SECTION_STATS      = "Stat Targets",
    MODE_RAID          = "Raid",
    MODE_MPLUS         = "M+",
    MODE_TIP           = "Switch stat-target source: Raid / Mythic+",
    MODE_MHIGH         = "High Keys",
    MODE_MFARM         = "+12",
    MODE_TIP_RAID      = "Raid stat targets",
    MODE_TIP_HIGH      = "Mythic+ high-key (pushing) stat targets",
    MODE_TIP_FARM      = "Mythic+ farming (+12) stat targets",
    -- Top-left toggles: usage reference frame + raid-gear filter
    USAGE_BTN          = "Usage ref: ",
    USAGE_RAID         = "Raid",
    USAGE_MPLUS        = "M+",
    USAGE_TIP          = "Usage% = aggregated from top players' real gear\n\nRaid \226\128\148 gear of top raid players\nM+ \226\128\148 gear of top Mythic+ players\n\nClick to switch (BiS order, usage%, farm plan follow)",
    EXRAID_BTN_ON      = "Raid gear: Excluded",
    EXRAID_BTN_OFF     = "Raid gear: Included",
    EXRAID_TIP         = "Whether raid drops are recommended.\nExcluded = only M+/crafted etc. non-raid sources (for solo players who skip raids; tier shells kept)\nIncluded = recommend raid drops too",
    SECTION_NEXT       = "Next Steps",
    BTN_FARMING        = "Farming Priority",
    FG_TITLE           = "Farming Priority",
    BTN_REFRESH        = "Refresh",
    CLOSE_SHORT        = "Close",

    -- Secondary stat names
    STAT_CRIT          = "Crit",
    STAT_HASTE         = "Haste",
    STAT_MASTERY       = "Mastery",
    STAT_VERS          = "Vers",

    -- Footer / author
    AUTHOR_BY          = "by",
    DATA_FOOTER        = "Midnight S2 \194\183 WCL \194\183 updated ",

    -- Slash / status prints
    PRINT_OPEN_FIRST   = "Open the panel or refresh data first.",
    DUMP_UNAVAILABLE   = "BisData.DumpEncounterJournal unavailable",
    SCALE_SET          = "Panel scale set to ",
    SCALE_USAGE        = "Usage: /gi scale <0.5-2.0>  current: ",
    CMD_ERROR          = "Command error: ",
    PANEL_INIT_FAIL    = "Panel init failed: ",
    REFRESH_FAIL       = "Refresh failed: data modules not ready",
    REFRESHED          = "Gear data refreshed",
    REFRESHED_NOPANEL  = "Gear data refreshed; panel not open, type /gi to view",
    HELP_LINE          = "/gi - panel | /gi farming - farming guide | /gi cbis - character panel BiS icons | /gi status - status | /gi refresh - refresh | /gi dumpids - dump IDs | /gi help",
    LOADED             = "Loaded. Type /gi to open the panel",

    -- Tooltips
    TT_BIS_ILVL        = "BiS ilvl: ",
    TT_BIS_TOPMX       = "Top players seen up to %d",
    TT_IMPROVE         = "Upgrade: +%.1f%%",
    TT_DROP            = "Drop: ",
    TT_COMPANION       = "GearInsight Companion live recommendation",
    TT_BIS_REC         = "GearInsight BiS recommendation",
    TT_SHIFT_CHAT      = "Shift+Click to link in chat",
    TT_TIER_CLICK      = "Click to see convertible same-slot items",
    TT_JOURNAL_CLICK   = "Click to open the Adventure Guide",

    -- Overview
    OV_SPEC            = "Spec: ",
    OV_ILVL            = "Item level: ",
    OV_GRAD            = "Target ilvl: ",
    OV_GAP             = "Gap: ",
    OV_OVER            = "Above target: ",
    OV_NODATA          = "No BiS data for this spec",
    STAT_PRIORITY      = "Stat priority: ",
    STAT_WORST         = "  |  Most needed: %s -%.1f%%",
    STAT_OK            = "  |  Stats within target",

    -- Stat bar tags
    LBL_PANEL          = "panel",
    LBL_DIST           = "dist",
    TAG_NONCORE        = "minor",
    TAG_LOW            = "low",
    TAG_TOL            = "near",
    TAG_OK             = "ok",
    TAG_OVER           = "over",
    TAG_GAP            = " need %.1f%%",
    TAG_GAP_RATING     = "(need %d)",
    LBL_TGT            = "target",
    TAG_GAP_R          = "  need %d",
    TAG_OVER_R         = "  +%d",
    TAG_GAP_R2         = " -%d",
    TAG_OVER_R2        = " +%d",
    EXPORT_COPY_HINT   = "Export string ready - press Ctrl+C",

    -- Upgrade rows
    SLOT_EMPTY         = "(empty)",
    HDR_UPGRADE_SLOT   = "Upgrade - ",
    NEED_HIGHER_ILVL   = " higher-ilvl version needed",
    TIER_FILLER        = "Set filler",
    TIER_FILLER_DROPS  = "drops",
    TIER_TOP_STATS     = "Recommended stats: %s",
    TIER_CORE_STAT     = "Core stat: %s",
    TIER_RAID_ONLY     = "this slot's fillers only drop in raid",
    TIER_NONRAID_FIRST = "non-raid fillers listed first (raid excluded)",
    MLEVEL_RAID        = "Mythic difficulty",
    MLEVEL_FMT         = "+%d keys (this week +%d~+%d)",
    MLEVEL_FMT_ONE     = "+%d keys",
    TTBIS_FILLER_RANK  = "  · filler priority #%d/%d",
    TIER_FILLER_CLICK  = "\194\183 click to see farmable items (",
    JOURNAL_HINT       = "(journal)",
    SOURCE_PREFIX      = "Source: ",

    -- Completed / empty states
    COMPLETED_PREFIX   = "Completed slots: ",
    GRAD_HDR           = "Graduated slots",
    POTION_LOW_NOTE    = "Top players rarely use combat potions on this spec; pick by stat/need",
    GRAD_HDR_TT        = "Click to expand/collapse graduated slots",
    COMPLETED_SUFFIX   = " (open Farming Priority for the full list)",
    EMPTY_COMPANION    = "Companion connected, nothing pending",
    EMPTY_KEY_DONE     = "Key slots done; check Farming Priority for the full list",
    EMPTY_NONE         = "No next steps",

    -- Farming guide
    FG_NODATA          = "No farming priority data",
    CAT_RAID           = "Raid",
    CAT_MPLUS          = "Mythic+",
    CAT_CRAFTED        = "Crafted",
    CAT_WORLD          = "World",
    CAT_TIER           = "Set",
    CAT_QUEST          = "Quest/Renown",
    FG_NEED            = "need ",
    FG_PCS             = "",
    FG_COMPLETE        = " (complete)",
    FG_SUB_COMPLETE    = "  complete",
    FG_CRAFTED_NOTE    = "Crafted gear can't be farmed — craft it or buy from the Auction House (only the 2 slots most worth crafting are shown)",
    OBTAINED           = "  (owned)",
    ILVL_LOW_PRE       = "(ilvl low ",
    MISSING_TAG        = "  [missing]",
    FILLER_TAG         = "(filler / convert)",

    -- Tier filler popup
    TIER_POPUP_HINT    = "Convert any one item via the Catalyst (same slot, same armor)",
    TIER_POPUP_SUFFIX  = " set filler",
    TIER_DEFAULT_SLOT  = "Set",
    LOADING            = "loading...",

    -- Multi-spec farming planner
    MS_TITLE     = "Multi-Spec Loot Plan",
    MS_HINT      = "Check the specs you farm together; each boss shows the loot spec to set",
    MS_PICK_HINT = "Check the specs you want to farm together",
    MS_NODATA    = "No data",
    MS_ALL_DONE  = "Selected specs are fully geared in the current data",
    MS_OTHER     = "Other source",
    MS_BTN_CUR   = "Loot spec: %s (current)",
    MS_BTN_SET   = "Set loot spec: %s",
    MS_BTN_OPEN  = "Multi-Spec Loot",
    MS_COMBAT    = "Can't change loot spec in combat",
    MS_SET_OK    = "Loot specialization set to %s",
    MS_SHARED    = "shared by specs",
    MS_CLICK_JOURNAL = "Click to open the Adventure Guide",
    MS_CLICK_FILLER = "Click for catalyzable same-slot pieces",
    MS_TIER_TAG = "[catalyst pieces]",
    MS_TIER_NOTE = "[set piece · catalyzable fillers below]",

    -- Slot top-5 popup
    TOP5_CLICK_HINT    = "Click to see this slot's top 5 by usage",
    TOP5_POPUP_HINT    = "Most-used items for this slot among top players",
    TOP5_TITLE_SUFFIX  = " \194\183 Top 5 by usage",
    TOP5_DEFAULT_SLOT  = "Slot",
    TOP5_BTN           = "Top 5",
    TOP5_BTN_TT        = "See this slot's top 5 by usage",

    -- New 12.0 Demon Hunter spec (spec-ID API can't name it off the active spec)
    SPEC_DEVAURER = "Devourer",
    TIER_FILLER_CLICK2 = "· Click for catalyzable pieces",

    -- Export to web companion
    EXPORT_BTN    = "Export Gear",
    EXPORT_TIP    = "Export a gear string to paste into the web companion for your upgrade list",
    EXPORT_WEB_HINT = "Open |cFF4DB8FFgearinsight.app/wow/en/analyze|r → paste this string for your gap list & farm order",
    EXPORT_TITLE  = "Export Gear to Web",
    EXPORT_HINT   = "Press Ctrl+C to copy the string below, then paste it into the web companion to see your upgrade list",
    EXPORT_NODATA = "Nothing to export — open the panel or run /gi refresh first",

    -- Global tooltip BiS rank
    FG_ONLYTOP_ON        = "Top BiS: only",
    FG_ONLYTOP_OFF       = "Top BiS: all",
    FG_ONLYTOP_TIP       = "Show only the #1 pick for each slot.\nPaired slots (rings / trinkets / weapons) keep #1 only, and Catalyst filler rows are hidden too.",
    MT_TAB_WISH          = "Wishlist",
    WLP_SUB              = "Source: %s   ·   %d items",
    WLP_SRC_RECS         = "Next steps (what you lack and would gain from)",
    WLP_SRC_BIS = "full BiS table",
    WLP_SRC_NONE         = "No data",
    WLP_STAT_TIP_BIS = "Falling back to the full BiS table instead of next-step advice computed from your current gear.|nUsually this means the data is stale - refresh once on the Gear tab for a better source.",
    WLP_ON               = "Party loot alert: on",
    WLP_OFF              = "Party loot alert: off",
    WLP_DEMO             = "Preview",
    WLP_TOGGLE_TIP       = "Pops up when a party member loots something on your wishlist.\nOnly fires for other people; your own loot never interrupts you.",
    WLP_DEMO_TIP         = "Show a sample alert so you can see what a real one looks like.\nDisappears after 8 seconds and never steals focus.",
    WLP_EMPTY            = "The list is empty. It is generated from Next steps — run an analysis on the Gear overview page first.",
    WLP_ADD_HINT         = "Shift-click an item link here, press Enter",
    WLP_DEL_TIP          = "Remove this from the wishlist",
    WLP_MANUAL           = "[manual]",
    WLP_SRC_MANUAL       = "All added by you",
    WA_MANUAL            = "added by you",
    WLP_INTRO            = "Alerts you when a party member loots an upgrade for one of your slots, with one-click whisper.|nThe list follows your gear automatically - nothing to maintain.",
    WLP_STAT             = "%d slots can be upgraded  ·  Source: %s",
    WLP_COL_SLOT         = "Slot",
    WLP_COL_CUR          = "Current",
    WLP_COL_TGT          = "Target",
    WLP_COL_GAIN         = "Gain",
    WLP_EMPTY_SLOT       = "empty",
    WP_ASK_GAIN          = "Hi, are you still after %s? It would be a +%d ilvl upgrade for that slot for me - mind passing it if you do not need it? Thanks!",
    WP_ASK               = "Hi, are you still after %s? It is exactly the slot I need - mind passing it if you do not need it? Thanks!",
    WP_ASK_FULL          = "Hi, are you still after %s? I am still on a %d ilvl there (+%d upgrade) - mind passing it if you do not need it? Thanks!",
    WLP_COL_BELL         = "Alert",
    WLP_FILLER           = "filler",
    WLP_BELL_TIP         = "Whether to alert you when something drops for this slot.|nTurning it off stops the popup; the row stays listed.",
    WP_TITLE             = "|cffd6b26c%d upgrade(s) for you just dropped:|r",
    WP_ASK_CUR           = "Hi, are you still after %s? I am on %s in that slot - it would be +%d ilvl for me. Mind passing it if you do not need it? Thanks!",
    WP_INFO_GAIN         = "|cff40ff40+%d ilvl|r",
    WP_INFO_EMPTY        = "empty slot",
    WP_INFO_BIS          = "|cffffd100BiS #%d of %d|r",
    WLP_LOADING          = "loading...",
    TTBIS_HEADER         = "GearInsight",
    TTFILLER_IS          = "Tier filler for this slot",
    TTSRC_RAID           = "Raid",
    TTSRC_DROP           = "Drops: ",
    TTSRC_SOURCE         = "Source: ",
    TTSRC_MPLUS          = "Mythic+",
    TTSRC_TIER           = "Tier conversion (Catalyst)",
    TTSRC_WORLD          = "World drop",
    TTSRC_CRAFTED        = "Crafted",
    TTSRC_BOSSNUM        = "Boss %d",
    TTBIS_CUR_FMT        = "%s BiS #%d / %d",
    TTBIS_SEASON_TAG        = "Season BiS ranking",
    TTBIS_USAGE_FMT      = "%.1f%% used",
    TTBIS_USAGE_RAID     = "Raid %.1f%%",
    TTBIS_USAGE_MPLUS    = "M+ %.1f%%",
    TTBIS_OTHER_LABEL    = "Other classes: ",
    TTBIS_SAMECLASS_LABEL = "Your other specs: ",
    TTBIS_OTHER_ENTRY_FMT = "%s %s #%d",
    TTBIS_OTHER_MORE_FMT = "+%d more",
    TTBIS_OTHER_SEP      = " \194\183 ",
    TTBIS_SLOT_FINGER    = "Ring",
    TTBIS_SLOT_TRINKET   = "Trinket",
    TTBIS_SLOT_WEAPON    = "Weapon",
    TTBIS_TOGGLE_ON      = "Tooltip BiS rank: on",
    TTBIS_TOGGLE_OFF     = "Tooltip BiS rank: off",
    TTBIS_TOGGLE_CURRENT = "Tooltip: current spec only",
    TTBIS_TOGGLE_ALL     = "Tooltip: all specs",
    TTBIS_TOGGLE_USAGE   = "Usage: /gi tooltip on|off|current|all|others (per-spec picks: panel \"Tooltip\" button)",
    TTBIS_TOGGLE_OTHERS_ON  = "Tooltip: other classes shown",
    TTBIS_TOGGLE_OTHERS_OFF = "Tooltip: other classes hidden",
    TTBIS_BTN            = "Display",
    TTBIS_BTN_TIP        = "Display settings:\n- Item-tooltip BiS rank lines (tick the same-class specs you want;\n  other classes are hidden by default)\n- Character panel (C) BiS icon toggle",
    TTBIS_MENU_NA        = "Menu API unavailable; use /gi tooltip others | on|off|current|all",

    -- Character panel BiS icons (PaperDollBis)
    PDB_COLLECTED        = "Collected — this is the BiS for this slot",
    PDB_SOURCE           = "Source: ",
    PDB_USAGE            = "Used by %.0f%% of top players",
    PDB_CLICK            = "Click for this slot's top 5",
    PDB_TOGGLE_ON        = "Character panel BiS icons: on",
    PDB_TOGGLE_OFF       = "Character panel BiS icons: off",
    PDB_MENU_TOGGLE      = "Show BiS icons on character panel (C)",
    PDB_MENU_SIZE        = "BiS icon size",
    PDB_MENU_POS         = "BiS icon position",
    PDB_POS_TL           = "Top left",
    PDB_POS_TR           = "Top right",
    PDB_POS_BL           = "Bottom left",
    PDB_POS_BR           = "Bottom right",
    PDB_SIZE_SET         = "Character panel BiS icon size: %dpx",
    PDB_POS_SET          = "Character panel BiS icon position: ",
    PDB_CFG_HELP         = "Usage: /gi cbis on|off | size 10-30 | pos tl|tr|bl|br",
    PDB_BEST_ENCH        = "Top enchant here: ",
    PDB_BEST_GEM         = "Top gems: ",
    PDB_ENCH_SEE_GUIDE   = "(see guide)",
    GROUPBIS_MENU_TOGGLE = "Show group members' BiS on hover",

    -- Gear difficulty tier (TierView)
    TIER_MYTHIC          = "Mythic",
    TIER_HEROIC          = "Heroic",
    TIER_NORMAL          = "Normal",
    TIER_MYTHIC_SUFFIX   = " (default \194\183 top-player raw data)",
    TIER_MENU_TITLE      = "BiS reference tier (ilvl / graduation scaled)",
    TIER_SET             = "BiS reference tier: ",
    TIER_SET_NOTE        = " (item levels scaled to this tier; usage % still reflects top players)",
    TIER_HELP            = "Usage: /gi tier m|h|n (Mythic/Heroic/Normal); current: ",
    TIER_TAG             = " tier",

    -- Web character profile (gearinsight.app)
    WEB_BTN              = "Web profile (click to copy link)",
    WEB_TITLE            = "Web Character Profile",
    WEB_HINT             = "Ctrl+C to copy, open in browser: parse score / AI coach / BiS gaps",
    WEB_TOOLTIP          = "Copy your profile page link: parse score / AI coaching / BiS gaps\nShare it with your group too",
    WEB_URL_FAIL         = "Character info not ready, try again shortly",
    TTBIS_MENU_TITLE     = "Display \194\183 Item tooltip BiS ranks",
    TTBIS_MENU_ENABLE    = "Enable tooltip lines",
    TTBIS_MENU_SAMECLASS = "Your other specs (tick = show)",
    TTBIS_MENU_OTHERS    = "Show other classes",

    -- LoadOnDemand talent library sub-addon
    TALENT_LOD_FAIL      = "Failed to load talent library module (GearInsight_Talents): ",
    TALENT_LOD_HINT      = "  Please make sure it is enabled in the AddOns list",

    -- QQ group (China community)
    QQ_LABEL           = "QQ Group 954673901 (click to copy)",
    QQ_TITLE           = "QQ Group",
    QQ_HINT            = "Press Ctrl+C to copy the group number",
    QQ_TOOLTIP         = "Click to copy QQ group 954673901",
    QQ_JOIN            = "Join the QQ group for the latest data updates: |cFFFFFF00954673901|r",

    -- Crafted-gear mini recommendation
    SECTION_CRAFTED_PICKS = "Crafted Picks (BiS-aware)",

    -- Gems & enchants section
    SECTION_GEMS_ENCH  = "Recommended Gems & Enchants",
    GEMS_LABEL         = "Gems (by usage):",
    ENCH_LABEL         = "Enchants (by slot):",
    ENCH_SEE_GUIDE     = "(see guide)",
    GE_USAGE_PREFIX    = "Top-player usage: ",
    CONS_LABEL         = "Consumables (pick by stat/role):",
}

-- GearInsight.L 是「就地打补丁」的表（zhCN.lua 先铺一份简体，这里覆盖成英文），
-- ⛔它不是 T() 查表，所以 scripts/gi_locale_audit.py **看不见这里漏的键**。
--
-- ⛔⛔ 2026-09-07 两个坑一起现形（土耳其玩家小地图按钮提示截图）：
--   ① 这个块原来的门是 `LOCALE == "enUS"` —— 只有英文客户端进得来，
--      德/法/韩/俄客户端**一个键都补不到**，连部位名都是简体中文。
--      改成「不是 zhCN 也不是 zhTW 就补英文」，zhTW.lua 在本文件之后加载，自己覆盖回繁中。
--   ② 原来只补了 SLOT_* 和 NO_ITEM，L 表其余 36 个中文键从没补过。
--      小地图提示第二行「左键：打开/关闭面板」露中文、第三行「右键：重新读取装备」
--      在没有中日韩字形的客户端上渲染成 9 个「?」菱形（缺字形标记）。
-- ⭐ 判据不是「rc=0」也不是「审计通过」，是**装上去把鼠标放上去看一眼**。
if GearInsight.LOCALE ~= "zhCN" and GearInsight.LOCALE ~= "zhTW" then
    local L = GearInsight.L
    if L then
        -- 部位名
        L["SLOT_HEAD"] = "Head"
        L["SLOT_NECK"] = "Neck"
        L["SLOT_SHOULDER"] = "Shoulder"
        L["SLOT_CHEST"] = "Chest"
        L["SLOT_WAIST"] = "Waist"
        L["SLOT_LEGS"] = "Legs"
        L["SLOT_FEET"] = "Feet"
        L["SLOT_WRIST"] = "Wrist"
        L["SLOT_HANDS"] = "Hands"
        L["SLOT_FINGER1"] = "Ring 1"
        L["SLOT_FINGER2"] = "Ring 2"
        L["SLOT_TRINKET1"] = "Trinket 1"
        L["SLOT_TRINKET2"] = "Trinket 2"
        L["SLOT_BACK"] = "Back"
        L["SLOT_MAINHAND"] = "Main Hand"
        L["SLOT_OFFHAND"] = "Off Hand"
        L["SLOT_UNKNOWN"] = "Unknown slot"
        L["NO_ITEM"] = "(empty)"
        -- 小地图按钮提示（⛔ 就是 2026-09-07 那张截图里露的两行）
        L["MINIMAP_TOOLTIP_LEFT"] = "Left-click: toggle the panel"
        L["MINIMAP_TOOLTIP_RIGHT"] = "Right-click: reload gear"
        -- 命令 / 状态回执
        L["ADDON_LOADED"] = "GearInsight loaded. Type /gi to open the panel."
        L["OPEN_PANEL"] = "Open the gear analysis panel"
        L["CLOSE_PANEL"] = "Close panel"
        L["RELOAD_DATA"] = "Reload gear data"
        L["GEAR_REFRESHED"] = "Gear data refreshed."
        L["SAVED_OK"] = "Character data saved to GearInsightDB."
        L["NO_ITEM_EQUIPPED"] = "No item equipped in that slot."
        L["UNKNOWN_CLASS"] = "Unknown class"
        L["UNKNOWN_SPEC"] = "Unknown spec"
        L["NO_SPEC_DATA"] = "No BiS data for this spec yet"
        L["DATA_VERSION"] = "Data version"
        -- 属性名
        L["STAT_CRIT"] = "Crit"
        L["STAT_HASTE"] = "Haste"
        L["STAT_MASTERY"] = "Mastery"
        L["STAT_VERSATILITY"] = "Versatility"
        L["STAT_STRENGTH"] = "Strength"
        L["STAT_AGILITY"] = "Agility"
        L["STAT_INTELLECT"] = "Intellect"
        L["STAT_STAMINA"] = "Stamina"
        -- 面板分区 / 字段
        L["SECTION_OVERVIEW"] = "Gear Overview"
        L["SECTION_STATS"] = "Stat Targets"
        L["SECTION_UPGRADE"] = "Upgrades"
        L["CURRENT_ILVL"] = "Item level"
        L["TARGET_ILVL"] = "BiS item level"
        L["SPEC_LABEL"] = "Spec"
        L["CLASS_LABEL"] = "Class"
        L["HERO_TALENT_LABEL"] = "Hero talent"
        -- 悬停提示（⛔ %d / %.1f%% 的个数与顺序必须和简体原串一致）
        L["TOOLTIP_UPGRADE"] = "Your upgrade"
        L["TOOLTIP_SLOT_RANK"] = "Slot rank"
        L["TOOLTIP_USAGE"] = "Top-player usage"
        L["TOOLTIP_SOURCE"] = "Source"
        L["TOOLTIP_ESTIMATED"] = " (estimated)"
        L["TOOLTIP_TOTAL_ITEMS"] = "%d samples"
        L["STAT_PROGRESS_FMT"] = "%.1f%% / %.1f%% (target)"
    end
end

-- ⭐ 2026-08-29: 53 keys that T() called but this file never defined, so they fell
-- back to the inline Chinese and English users saw Chinese text. Found by
-- scripts/gi_locale_audit.py (run it before every release).
-- ⛔ Format specifiers (%s / %d / %.0f%%) must match the Chinese original exactly.
do
    local L = GearInsight.LOC["enUS"]

    -- Auction House copy helpers
    L["COPY_TITLE"]       = "Buy from the Auction House"
    L["COPY_HINT"]        = "Ctrl+C to copy, then paste into the Auction House search box"
    L["CONS_COPY_HINT"]   = "Ctrl+C to copy \"%s\", then paste it into the Auction House search box"
    L["CONS_COPY_TT"]     = "Click to copy the name \194\187 search for it in the Auction House"
    L["ENCH_COPY_TT"]     = "Click to copy the name \194\187 search for it in the Auction House"
    L["ENCH_ALT_TT"]      = "Alternative: "

    -- Consumables
    L["CONS_FOOD_META"]   = "(meta)"
    L["CONS_LABEL_USAGE"] = "Consumables (flask/potion usage: %s \194\183 %d samples \194\183 click to copy name)"

    -- Encounter Journal
    L["EJ_COMBAT"]        = "The Encounter Journal cannot be opened in combat (Blizzard restriction) \226\128\148 try again after leaving combat"

    -- Raid-gear exclusion toggle
    L["EXRAID_ON"]        = "Raid gear excluded: only Mythic+, crafted and other non-raid sources are recommended"
    L["EXRAID_OFF"]       = "Restored: recommendations include raid gear"
    L["GRAD_UPGRADABLE"]  = "Upgradable"
    L["USAGE_MODE_SET"]   = "Usage reference switched to: "
    L["EXPORT_HINT_EN"]   = "Copy the string below (Ctrl+C) and paste it on gearinsight.app"

    -- Loot request sheet (send to your raid leader)
    L["NEED_TITLE"]       = "Loot request sheet \194\183 send it to your raid leader"
    L["NEED_HEADER"]      = "[Raid loot request] %s-%s %s ilvl %d"
    L["NEED_SPECLINE"]    = "Spec: %s | Difficulty: Mythic/Heroic/Normal (keep the one you are running)"
    L["NEED_LOOTSET"]     = "Loot spec:"
    L["NEED_ITEMS"]       = "Needs: "
    L["NEED_SLOT"]        = "slot"
    L["NEED_FREE"]        = "Free roll, nothing needed"
    L["NEED_TOTAL"]       = "Total: %d items needed"
    L["NEED_TRASH"]       = "Trash (drops throughout the zone)"
    L["NEED_SRC_OTHER"]   = "Other sources"
    L["NEED_OFFRAID"]     = "Not obtainable in this raid, plan separately:"
    L["NEED_OFFRAID_MORE"]= "- (%d more items, see the addon's farming priority)"
    L["NEED_REMIND"]      = "Before you pull: for bosses with a loot spec listed, switch your loot specialization first (Loot options \226\134\146 Loot Specialization)"
    L["NEED_HINT"]        = "Ctrl+C to copy. You can edit the text in the box first (drop difficulties, reword) before copying. The spec range follows the \"Multi-Spec Loot\" checkboxes."
    L["NEED_NODATA"]      = "Cannot build the request sheet: open the panel first, or run /gi refresh to reload your gear data"
    L["NEED_NORAID_WARN"] = "\194\167 Raid exclusion is currently on, so raid needs are not listed \226\128\148 run /gi noraid off and generate again"
    L["NEED_FOOTER"]      = "\226\128\148 generated by GearInsight \194\183 gearinsight.app"
    L["MS_NEED_BTN"]      = "Copy request sheet"
    L["MS_NEED_TIP"]      = "Builds a per-boss request sheet for the specs ticked above\n(loot spec / needed items / coin priority), then copy it to your raid leader"

    -- Bonus-roll coins
    L["NEED_COIN_NAME"]    = "Dim Void Core"
    L["NEED_COIN_ORDER"]   = "Coin priority: "
    L["NEED_COIN_HAVE"]    = "Coins (%s): %d in bags = %d extra rolls"
    L["NEED_COIN_UNKNOWN"] = "Coins (Dim Void Core): count unavailable, use them in the order below"
    L["NEED_ROLLAT"]       = "\226\152\133Coin priority #%d"

    -- Regions
    L["REGION_CN"] = "CN"
    L["REGION_TW"] = "TW"
    L["REGION_KR"] = "KR"
    L["REGION_EU"] = "EU"
    L["REGION_RU"] = "RU"

    -- Scenarios
    L["SCEN_RAID"] = "Raid"
    L["SCEN_MH"]   = "M+ high keys"
    L["SCEN_MF"]   = "M+ farm"

    -- Stat targets
    L["STAT_BASIS_TITLE"] = "Stat targets = mirror how WCL top players split their secondaries"
    L["STAT_BASIS_BODY"]  = "Target share = how WCL top players distribute their secondary stats (crit/haste/mastery/versatility) for the current scenario: raid / high keys / farm,\n"
    L["STAT_WORST_R"]     = "  |  lowest: %s - %.0f%% of target"

    L["CFG_TGT_ILVL"]   = "Wishlist target item level"
    L["CFG_TGT_ILVL_D"] = "Measure the gap against your own target: slots that reach this item level drop off the wishlist. 0 = use what top players wear (default). Useful early in a season when you only run keys and cannot reach the top track yet."

    L["GM_STATFIT"]     = "Secondary fit"

    -- 自定义私聊话术（玩家「目暮」2026-09-07 提）
    L["CFG_WHISPER"]        = "Whisper template"
    L["CFG_WHISPER_D"]      = "What gets pre-filled when you press Whisper in the popup. Placeholders: {item} the drop, {cur} what you wear now, {gain} item levels gained, {slot} the slot, {me} your name. Leave empty for the default."
    L["CFG_WHISPER_EDIT"]   = "Edit"
    L["CFG_WHISPER_RESET"]  = "Reset"
    L["CFG_WHISPER_RESET_OK"] = "Whisper template reset to default."
    L["WP_EDIT_TITLE"]      = "Whisper template"
    L["WP_EDIT_HINT"]       = "Placeholders: |cFFFFD100{item}|r the drop  |cFFFFD100{cur}|r your current piece  |cFFFFD100{gain}|r item levels gained  |cFFFFD100{slot}|r slot  |cFFFFD100{me}|r your name\nAnything unavailable is removed automatically. Leave empty to use the default."
    L["WP_EDIT_PREVIEW"]    = "Preview"
    L["WP_EDIT_SAVE"]       = "Save"
    L["WP_EDIT_RESET"]      = "Reset"
    L["WP_EDIT_SAVED"]      = "Whisper template saved."
    L["WP_TPL_DEFAULT"]     = "Hi, do you still need {item}? I am on {cur} right now, this would be +{gain} ilvl for me. If you cannot use it, mind passing it my way? Thanks!"
    L["EMB_OVER"]           = "%d embellished pieces equipped — the game only lets 2 work at once."
    L["WP_ILVL"]            = "ilvl"

    -- Parse score card (ui/ParseScore.lua)
    L["PS_T_LEGEND"]   = "Legendary"
    L["PS_T_PINK"]     = "Pink"
    L["PS_T_ORANGE"]   = "Orange"
    L["PS_T_PURPLE"]   = "Purple"
    L["PS_T_BLUE"]     = "Blue"
    L["PS_T_GREEN"]    = "Green"
    L["PS_T_GRAY"]     = "Gray"
    L["PS_SHARE"]      = "Share"
    L["PS_LINE1"]      = "|cFFFFD100[%s]|r  You ~ |c%sp%d %s|r"
    L["PS_LINE2_GAP"]  = "DPS %s · to p%d: ~%s more"
    L["PS_LINE2_SRC"]  = "DPS %s · source %s"
    L["PS_SHARE_TXT"]  = "[GearInsight] %s I parsed p%d (%s)! DPS %d - what about you?"
    L["PS_COPY_HINT"]  = "Ctrl+C to copy"
    L["PS_COPY_TITLE"] = "Share Parse"
    L["PS_NO_DMG"]     = "Could not read your damage (make sure Details! is running)."
    L["PS_NO_CURVE"]   = "No parse curve for this spec yet."
    L["MS_MISSING_N"]  = "(%d missing)"
    L["SLOT_N"]        = "Slot "

    -- Telegram (non-Chinese clients)
    L["TG_JOIN"]    = "Join the Telegram group for data updates & feedback: |cFFFFFF00t.me/gearInsight|r"
    L["TG_TITLE"]   = "Telegram Group"
    L["TG_LABEL"]   = "Telegram: t.me/gearInsight (click to copy)"
    L["TG_HINT"]    = "Ctrl+C to copy, open in browser to join"
    L["TG_TOOLTIP"] = "Click to copy Telegram group link"
end

-- ⭐ 2026-08-29：没有 Journal 条目的来源（localizedSource 的 _NON_JOURNAL_SRC 查表）。
do
    local L = GearInsight.LOC["enUS"]
    L["SRC_CRAFTED"]    = "Crafted"
    L["SRC_TIERCONV"]   = "Tier set conversion"
    L["SRC_WORLD"]      = "World drop"
    L["SRC_REPQUEST"]   = "Reputation quest"
    L["SRC_OTHER"]      = "Other source"
    L["SRC_KEYCHEST"]   = "Keystone chest"
    L["SRC_KEYCHEST_M"] = "Keystone chest (M+)"
end

-- 大秘境情报面板 (0.65.0, 2026-08-31)
do
    local t = GearInsight.LOC and GearInsight.LOC["enUS"]
    if t then
        t["MM_TITLE"] = "M+ Meta"
        t["MM_NEW"] = "new"
        t["MM_WAN"] = "0k"
        t["MM_DATA_TO"] = "Data through"
        t["MM_SAME_SRC"] = "same data as gearinsight.app"
        t["MM_STALE_SOFT"] = "data is %d days old"
        t["MM_STALE_HARD"] = "data is %d days old - please update the addon"
        t["MA_ROLE_TANK"] = "Tank"
        t["MA_ROLE_HEAL"] = "Healer"
        t["MA_ROLE_DPS"] = "DPS"
        t["MA_NODATA"] = "data not loaded"
        t["MA_RANK_N"] = "rank %d"
        t["MA_NOT_ON_BOARD"] = "your spec is not on this board (sample too small)"
        t["MA_TOP3"] = " top 3"
        t["MA_HINT"] = "/gi for the full board"
        t["LS_HINT"] = "Loot spec: %s can drop %d BiS pieces here, your current loot spec only covers %d"
        t["LS_INCL"] = "including"
        t["LS_HOW"] = "change it at Character > Specialization > Loot Specialization"
        t["WA_PREFIX"] = "wishlist:"
        t["WA_GOT"] = "picked up"
        t["WA_TIP"] = "click the name to whisper them"
        t["WP_WHISPER"] = "Whisper"
        t["WP_NEXT"] = "Next"
        t["WP_NTH"] = "|cff888888(%d of %d)|r"
        t["WP_CLOSE"] = "Close"
        t["WP_DEMO_ITEM"] = "Fangguard Belt"
        t["MM_H_PUSH"] = "Push DPS Board"
        t["MM_LVL_UP"] = "+ keys"
        t["MM_RUNS"] = " runs"
        t["MM_H_ROLE"] = "Tank / Healer pick rates"
        t["MM_TANKS"] = "Tanks  "
        t["MM_HEALS"] = "Healers  "
        t["MM_H_FARM"] = "Farm DPS Board"
        t["MM_LVL"] = "s"
        t["MM_H_TANKDPS"] = "Tank DPS"
        t["MM_H_HEALDPS"] = "Healer DPS"
        t["MM_H_DUNGEON"] = "Fastest dungeons"
        t["MM_H_UNDER"] = "Underrated (damage keeps up, nobody plays)"
        t["MM_IN_USE"] = " in use"
        t["MM_RECORDS"] = " logs"
        t["MM_FOOT"] = "Per-dungeon top-100 medians - raider.io rosters - updated weekly"
        t["MM_NODATA"] = "M+ meta data not loaded"
        t["OV_GRAD"] = "Drop baseline: "
        t["OV_GRAD_NOTE"] = "(what top players actually wear)"
    end
end

-- 0.66.0 主面板左侧标签页（ui/MainTabs.lua）
do
    local t = GearInsight.LOC.enUS
    t["MT_TAB_OV"] = "Overview"
    t["MT_TAB_MM"] = "M+ Intel"
    t["MT_TAB_TOOLS"] = "Tools"
    t["MT_TAB_SET"] = "Settings"
    t["MT_CAP_EXPORT"] = "Export your gear string, paste on the website for a full gap report"
    t["MT_CAP_TALENT"] = "Top WCL players' talent builds, one-click copy import string"
    t["MT_CAP_ROT"] = "Top players' openers / cast frequency / buff uptime"
    t["MT_CAP_DG"] = "Dungeon guide: kick priority / deadly spells / damage taken"
    t["MT_CAP_FARM"] = "Which dungeon to farm, sorted by your upgrade value"
    t["MT_CAP_MS"] = "Plan loot across multiple specs, never misclick Need"
    t["MT_CAP_MODE"] = "Whose usage% to reference: raid or M+ top players (drives BiS order and farm plan)"
    t["MT_CAP_EXRAID"] = "Include raid drops in recommendations (solo players can exclude)"
    t["MT_CAP_TIP"] = "Tooltip BiS line scope and character-pane icon toggles"
    t["MT_CAP_REFRESH"] = "Re-read your gear and recompute all recommendations"
end
do
    local t = GearInsight.LOC.enUS
    t["MT_TAB_TAL"] = "Talents · WCL Top Players"
    t["MT_TAB_TAL_SHORT"] = "Talents"
end
do
    local t = GearInsight.LOC.enUS
    t["TTBIS_CATALYST_PRE"] = "Catalyst-convert to "
    t["TTBIS_CATALYST_POST"] = " = BiS #%d"
end
-- 0.67.0 进阶页（ui/AdvancedPage.lua）
do
    local t = GearInsight.LOC.enUS
    t["MT_TAB_ADV"] = "Advanced · Website Link"
    t["MT_TAB_ADV_SHORT"] = "Advanced"
    t["ADV_ERR_EMPTY"] = "Nothing to import"
    t["ADV_ERR_FMT"] = "Bad format: must start with GIAD1| (use \"Copy back to the addon\" on the analyzer page)"
    t["ADV_ERR_SUM"] = "Checksum mismatch: string incomplete, copy it again from the website"
    t["ADV_ERR_NODATA"] = "No analysis content in the string"
    t["ADV_PLAN_NONE"] = "Nothing imported yet — analyze on the website, then paste the \"Copy back to the addon\" string above."
    t["ADV_PLAN_HEAD"] = "Website analysis · "
    t["ADV_PLAN_IMPORTED"] = " imported "
    t["ADV_FARM_HEAD"] = "Farm priority (most missing pieces first):"
    t["ADV_MISS_HEAD"] = "Missing pieces (by usage):"
    t["ADV_MISS_MORE"] = "…%d more, full list on the website"
    t["ADV_INTRO"] = "Three-step loop: 1) Export your gear string below. 2) Paste it on the gearinsight.app analyzer for power score / gap report / AI advice. 3) Paste the \"Copy back to the addon\" string here — your farm priorities stay on this page."
    t["ADV_IMPORT_LABEL"] = "Paste the website string (\"Copy back to the addon\" on the analyzer):"
    t["ADV_IMPORT_BTN"] = "Import"
    t["ADV_IMPORT_OK"] = "Imported"
end
do
    local t = GearInsight.LOC.enUS
    t["ADV_SCORE_HEAD"] = "WCL combat power (website-only):"
    t["ADV_SCORE_MED"] = "all-boss median "
    t["ADV_COACH_HEAD"] = "AI coach review (website-only):"
end
do
    local t = GearInsight.LOC.enUS
    t["ADV_INTRO"] = "Three-step loop: 1) Export your gear string. 2) Analyze on gearinsight.app (power score / gaps / AI advice). 3) Paste the receipt string back here - your WCL power score and AI coach review live on this page (website-only data the addon cannot fetch itself)."
end
do
    local t = GearInsight.LOC.enUS
    t["EXPORT_WEB_HINT2"] = "Open the URL below and paste the string for your gap report + farm order"
    t["EXPORT_URL_TIP"] = "Click the URL to select it, then Ctrl+C"
end
do
    local t = GearInsight.LOC.enUS
    t["EXPORT_WEB_HINT2"] = "Click the URL below to copy it, open it in your browser, then paste the string for your gap report + farm order"
    t["EXPORT_URL_TIP"] = "Click here to copy the URL (Ctrl+C), then paste it in your browser"
    t["EXPORT_WEB_HINT3"] = "The link below already carries your gear — copy it, paste it in your browser, and your gap report opens straight away"
    t["EXPORT_URL_TIP2"] = "Already selected — press Ctrl+C to copy the whole link. No need to paste the string above."
end
do
    local t = GearInsight.LOC.enUS
    t["EJ_OPEN_FAIL"] = "Could not open the Adventure Guide (client API may have changed) - please screenshot this line: "
end
do
    local t = GearInsight.LOC.enUS
    t["MM_COL_SPEC"] = "Spec"
    t["MM_COL_TIER"] = "Tier"
    t["MM_COL_DPS"] = "Avg DPS (median of top 100)"
end
do
    local t = GearInsight.LOC.enUS
    t["TAG_GAP_R3"] = " short %d (%.0f%%)"
    t["TAG_OVER_R3"] = " over %d (+%.0f%%)"
end
do
    -- 副本助手按需加载（core/DungeonModule.lua, 2026-09-04）
    local t = GearInsight.LOC.enUS
    t["DM_TITLE"] = "Dungeon Assistant"
    t["DM_BODY"] = "Enable the M+ dungeon guide and Bloodlust reminder? (deadliest abilities / interrupt priority / keystone timeline)"
    t["DM_BTN_ENABLE"] = "Enable"
    t["DM_BTN_NEVER"] = "Don't ask again"
    t["DM_TIP_NEVER"] = "Saved locally: this prompt won't show again and the module will never load (zero memory, zero events)."
    t["DM_ENABLED"] = "Dungeon Assistant enabled: it loads automatically when you enter a Mythic dungeon."
    t["DM_DISABLED"] = "Dungeon Assistant permanently disabled - it will no longer load or use memory. Click the \"Dungeon Guide\" button on the panel any time to turn it back on."
    t["DM_LOAD_FAIL"] = "Failed to load the Dungeon Assistant module (GearInsight_Dungeon): "
    t["DM_COMBAT_WAIT"] = "In combat - the Dungeon Assistant will load once you leave combat."
    t["DM_MASTER"] = "Auto-load this module in dungeons"
    t["DM_MASTER_TIP"] = "Unchecked = the module is not loaded at all from your next login (zero memory, zero events); the three options above stop too.\nClick the \"Dungeon Guide\" button on the panel any time to open it and turn it back on."
end
do
    local t = GearInsight.LOC.enUS
    t["DM_MASTER"] = "Enable Dungeon Assistant (auto-load in dungeons)"
    t["DM_MASTER_OFF"] = "Off - you can still open it from the \"Dungeon Guide\" button"
end
do
    -- 钥匙时间轴位置锁定（bug #108，2026-09-05）
    local t = GearInsight.LOC.enUS
    t["KT_UNLOCK_HINT"] = "Key Timeline - drag me where you want it"
    t["KT_UNLOCK_HINT2"] = "Then /gi kt lock (locked = clicks pass through to nameplates)"
    t["KT_UNLOCKED"] = "Key Timeline unlocked: drag to move, /gi kt lock to lock."
    t["KT_LOCKED"] = "Key Timeline locked (no longer intercepts the mouse)."
    t["KT_POS_RESET"] = "Key Timeline position reset."
    t["KT_HELP"] = "Usage: /gi kt unlock (drag) | lock | reset (default position)"
    t["KT_UNLOCK_TOGGLE"] = "Unlock timeline position (drag)"
    t["KT_UNLOCK_TIP"] = "While locked the timeline ignores the mouse entirely (does not block nameplate clicks). To move it: tick this, drag it, untick. Or /gi kt unlock / lock / reset."
end
do
    -- bug #109（2026-09-05）
    local t = GearInsight.LOC.enUS
    t["KT_ERR"] = "Key Timeline error (updates stopped - please send this line to the author):"
    t["DM_LOAD_FAIL_HINT"] = "(enable \"GearInsight Dungeon\" in the AddOns list, then /reload)"
    t["KT_HELP"] = "Usage: /gi kt unlock (drag) | lock | reset | debug (diagnostics for bug reports)"
    t["KT_HELP"] = "Usage: /gi kt off | on | scale 1.5 | unlock (drag) | lock | reset | debug (diagnostics for bug reports)"
    t["KT_OFF"] = "Key timeline disabled (/gi kt on to re-enable; also a checkbox under Tools → Dungeon guide)."
    t["KT_ON"] = "Key timeline enabled."
    t["KT_FIRST_HINT"] = "Key timeline is now showing. Turn it off: /gi kt off. Move it: /gi kt unlock. There is also a checkbox under Tools → Dungeon guide."
    t["CONS_CAT_FLASK"] = "Flasks"
    t["CONS_CAT_POTION"] = "Potions"
    t["CONS_CAT_FOOD"] = "Food"
    t["CONS_CAT_RUNE"] = "Runes"
    t["CONS_CAT_OIL"] = "Weapon oils"
    t["CONS_CAT_OTHER"] = "Other"
    t["CONS_FOOD_BUFF"] = "%.0f%% buffed"
    t["CFG_KT_SCALE"] = "Timeline size"
    t["KT_SCALE_SET"] = "Key timeline size: "
    t["KT_SCALE_USAGE"] = "Usage: /gi kt scale 0.8-2.0 (e.g. 1.5)"
    t["CONS_FILL_STAT"] = "fills %s"
    t["CFG_TITLE"] = "All settings"
    t["CFG_OPEN_PANEL"] = "Open GearInsight panel"
    t["CFG_FOOT"] = "Changes apply and save immediately. Command: /gi config opens this page."
    t["CFG_SEC_PANEL"] = "Character pane & tooltips"
    t["CFG_PDB"] = "Character pane BiS icons"
    t["CFG_PDB_D"] = "Shows a small BiS icon on each slot of the character pane; hover for the source."
    t["CFG_PDB_SIZE"] = "Icon size"
    t["CFG_PDB_POS"] = "Icon corner"
    t["CFG_PDB_POS_D"] = "Move it if it covers another addon's item-level text."
    t["CFG_POS_TL"] = "Top left"
    t["CFG_POS_TR"] = "Top right"
    t["CFG_POS_BL"] = "Bottom left"
    t["CFG_POS_BR"] = "Bottom right"
    t["CFG_TT"] = "BiS lines in item tooltips"
    t["CFG_TT_D"] = "Adds a GearInsight section to every item tooltip: spec ranks, source, top enchant."
    t["CFG_TT_OTHERS"] = "Also show other classes in tooltips"
    t["CFG_TT_SRC"] = "Show the source line in tooltips"
    t["CFG_INSPECT"] = "Show BiS gaps when inspecting others"
    t["CFG_INSPECT_D"] = "A small panel next to the inspect window listing what they still miss."
    t["CFG_GEARVIEW"] = "Gear overview defaults to the Gear Map"
    t["CFG_GEARVIEW_D"] = "Off = the old list view. You can switch at the top right of the panel any time."
    t["CFG_SEC_DM"] = "Dungeon assistant (M+ guide / live hints / key timeline)"
    t["CFG_DM"] = "Auto-load the dungeon assistant in Mythic+"
    t["CFG_DM_D"] = "Off by default. When on, the three features below load on dungeon entry; when off the module never loads."
    t["CFG_DM_POPUP"] = "Pop up the M+ guide on entry"
    t["CFG_DM_POPUP_D"] = "Interrupt priority / deadly spells / damage taken. You can still open it from the panel button."
    t["CFG_LG"] = "Live hints (must-kick / deadly spell highlight)"
    t["CFG_KT"] = "Key timeline (lust calls + boss pace vs top runs)"
    t["CFG_KT_D"] = "The bar at the top-centre of the screen inside a key. Commands: /gi kt off, /gi kt on."
    t["CFG_KT_POS"] = "Timeline position"
    t["CFG_KT_UNLOCK"] = "Unlock"
    t["CFG_KT_LOCK"] = "Lock"
    t["CFG_KT_RESET"] = "Reset"
    t["CFG_SEC_ALERT"] = "Alerts & extras"
    t["CFG_WISH"] = "Wishlist drop alerts"
    t["CFG_WISH_D"] = "Pops up when an item on your wishlist drops in your group."
    t["CFG_META"] = "M+ meta panel next to the keystone window"
    t["CFG_META_D"] = "Attaches this week's strongest specs / dungeon participation to the keystone UI."
    t["CFG_SEC_MAIN"] = "Main panel"
    t["CFG_SCALE"] = "Panel scale"
    t["CFG_USAGE"] = "Usage reference"
    t["CFG_USAGE_D"] = "BiS order, usage % and farm plan all follow this."
    t["CFG_USAGE_RAID"] = "Top raid players"
    t["CFG_USAGE_MPLUS"] = "Top M+ players"
    t["CFG_EXRAID"] = "Exclude raid gear (only recommend M+ obtainable)"
    t["CFG_RESETPOS"] = "Reset all window positions"
    t["CFG_RESETPOS_BTN"] = "Reset"
    t["CFG_RESETPOS_DONE"] = "Window positions reset; takes effect after /reload."
    t["DM_DISMISSED"] = "Dungeon assistant stays off. To enable: /gi config or ESC → Options → AddOns → GearInsight."
    t["DM_DISABLED"] = "Dungeon assistant disabled; it will not load or use memory. To enable: /gi config or ESC → Options → AddOns → GearInsight."
end
do
    -- 装备图（ui/GearMap.lua，2026-09-05）
    local t = GearInsight.LOC.enUS
    t["GM_TITLE"] = "Gear Map"
    t["GM_TOGGLE_LIST"] = "List"
    t["GM_TOGGLE_MAP"] = "Gear Map"
    t["GM_TOGGLE_TIP"] = "Gear Map = slots laid out like the character sheet; the arrow points at the BiS piece to get, the small squares show gem / enchant status.\nList = the old row-by-row view (kept for now)."
    t["GM_CLICK_TOP5"] = "Click: top 5 by usage for this slot"
    t["GM_RCLICK_SRC"] = "Right-click: source / tier filler"
    t["GM_DONE"] = "Best in slot"
    t["GM_UPGRADE"] = "Upgrade to: "
    t["GM_GEM_NOSOCKET"] = "This item has no socket"
    t["GM_GEM_EMPTY"] = "Empty socket! Recommended gem:"
    t["GM_GEM_OK"] = "Recommended gem socketed"
    t["GM_GEM_OTHER"] = "Non-recommended gem socketed, recommended:"
    t["GM_ENCH_TITLE"] = "Enchant"
    t["GM_ENCH_MISSING"] = "No enchant!"
    t["GM_RECOMMEND"] = "Recommended: "
    t["GM_ENCH_OK"] = "Recommended enchant applied"
    t["GM_ENCH_OTHER"] = "Non-recommended enchant, recommended:"
    t["GM_SUMMARY"] = "slots at best in slot"
    t["GM_LEGEND"] = "Small squares = gem / enchant: green ok, yellow non-recommended, red missing, grey n/a\nClick a BiS piece for top 5, right-click for source / filler"
end
do
    local t = GearInsight.LOC.enUS
    t["GM_OH_NO_PLAN"] = "Top players' mainstream setup uses a two-hander - no off-hand recommendation for this slot"
    t["GM_NO_PLAN"] = "No recommendation data for this slot yet"
end
do
    local t = GearInsight.LOC.enUS
    t["GM_GEM_NOSOCKET2"] = "No socket yet (this slot can be socketed this season)"
    t["GM_MINI_CLICK"] = "Left-click: search the AH if it is open, otherwise post to chat - Right-click: copy name"
    t["GM_ACT_TOP5"] = "Top 5"
    t["GM_ACT_FILLER"] = "Tier filler"
    t["GM_ACT_SRC"] = "Source"
end
