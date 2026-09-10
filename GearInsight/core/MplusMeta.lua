-- 由 _mp_site_export.py 生成，⛔别手改（每周随大秘境榜数据刷新）
-- ⛔ 必须写**全局** GearInsight：本插件全部模块走全局表；
--   `local _, GearInsight = ...` 拿到的是 addon 私有表，面板读全局就是 nil
--   （2026-08-31 玩家实测「大秘境情报数据未加载」，就是这一行的锅）。
GearInsight = GearInsight or {}
GearInsight.MplusMeta = {
    tag = "9月第2周 · 第3弹",
    date = "09-08",
    -- ⭐数据新鲜度用 Unix 时间戳判，⛔别用上面那个 date：它只有「09-01」没有年份，
    --   跨年就判反了，也算不出「距今几天」。面板据此提示玩家更新插件。
    epoch = 1788836749,
    season = "第二赛季",
    week = 3,
    pushLevel = 19,
    pushRuns = 3331,
    farmLevel = 10,
    farmRecords = 8900,
    pushTank = {
        { cls="Death Knight", spec="Blood", cn="血DK", pct=79.2, dr=0 },
        { cls="Druid", spec="Guardian", cn="熊德", pct=9.0, dr=0 },
        { cls="Monk", spec="Brewmaster", cn="酒仙", pct=7.5, dr=0 },
        { cls="Paladin", spec="Protection", cn="防骑", pct=2.0, dr=0 },
        { cls="Warrior", spec="Protection", cn="防战", pct=1.6, dr=0 },
        { cls="Demon Hunter", spec="Vengeance", cn="复仇DH", pct=0.8, dr=0 },
    },
    pushHealer = {
        { cls="Paladin", spec="Holy", cn="奶骑", pct=70.7, dr=0 },
        { cls="Shaman", spec="Restoration", cn="奶萨", pct=20.4, dr=0 },
        { cls="Monk", spec="Mistweaver", cn="奶僧", pct=3.9, dr=0 },
        { cls="Evoker", spec="Preservation", cn="奶龙", pct=3.0, dr=0 },
        { cls="Priest", spec="Holy", cn="神牧", pct=1.9, dr=0 },
    },
    pushDps = {
        { cls="Warlock", spec="Demonology", cn="恶魔术", med=363178, dr=0 },
        { cls="Shaman", spec="Elemental", cn="元素萨", med=355129, dr=0 },
        { cls="Mage", spec="Arcane", cn="奥法", med=349996, dr=0 },
        { cls="Rogue", spec="Outlaw", cn="狂徒贼", med=349939, dr=0 },
        { cls="Druid", spec="Feral", cn="猫德", med=346861, dr=0 },
        { cls="Hunter", spec="Beast Mastery", cn="兽王猎", med=345658, dr=0 },
        { cls="Monk", spec="Windwalker", cn="踏风", med=337216, dr=0 },
        { cls="Warrior", spec="Arms", cn="武器战", med=336434, dr=0 },
    },
    farmDps = {
        { cls="Warlock", spec="Demonology", cn="恶魔术", med=343546, dr=0 },
        { cls="Mage", spec="Arcane", cn="奥法", med=313731, dr=0 },
        { cls="Shaman", spec="Elemental", cn="元素萨", med=305187, dr=0 },
        { cls="Paladin", spec="Retribution", cn="惩戒骑", med=301933, dr=0 },
        { cls="Warrior", spec="Arms", cn="武器战", med=296650, dr=0 },
        { cls="Rogue", spec="Assassination", cn="刺杀贼", med=294678, dr=1 },
        { cls="Monk", spec="Windwalker", cn="踏风", med=293026, dr=1 },
        { cls="Rogue", spec="Subtlety", cn="敏锐贼", med=290996, dr=1 },
    },
    farmTanks = {
        { cls="Death Knight", spec="Blood", cn="血DK", med=192710 },
    },
    farmHeals = {
    },
    pushUnder = {
        { cls="Rogue", spec="Outlaw", cn="狂徒贼", gap=3.6, pct=2.3 },
        { cls="Hunter", spec="Beast Mastery", cn="兽王猎", gap=4.8, pct=1.5 },
        { cls="Monk", spec="Windwalker", cn="踏风", gap=7.1, pct=1.9 },
        { cls="Rogue", spec="Subtlety", cn="敏锐贼", gap=11.7, pct=1.3 },
    },
    farmUnder = {
        { cls="Monk", spec="Windwalker", cn="踏风", gap=14.7, pct=1.9 },
        { cls="Rogue", spec="Subtlety", cn="敏锐贼", gap=15.3, pct=1.3 },
        { cls="Shaman", spec="Enhancement", cn="增强萨", gap=19.0, pct=0.1 },
    },
    dungeons = {
        { cn="红玉新生法池", en="Ruby Life Pools", sec=1062, gap=0 },
        { cn="虚空之痕竞技场", en="Voidscar Arena", sec=1069, gap=7 },
        { cn="毒牙祭坛", en="Altar of Fangs", sec=1097, gap=35 },
        { cn="夺目谷", en="The Blinding Vale", sec=1137, gap=75 },
        { cn="密谋小径", en="Murder Row", sec=1149, gap=87 },
        { cn="塞塔里斯神庙", en="Temple of Sethraliss", sec=1159, gap=97 },
        { cn="诸王之眠", en="King's Rest", sec=1242, gap=180 },
        { cn="纳洛拉克的洞穴", en="Den of Nalorakk", sec=1247, gap=185 },
    },
}
