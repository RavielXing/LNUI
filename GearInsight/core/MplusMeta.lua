-- 由 _mp_site_export.py 生成，⛔别手改（每周随大秘境榜数据刷新）
-- ⛔ 必须写**全局** GearInsight：本插件全部模块走全局表；
--   `local _, GearInsight = ...` 拿到的是 addon 私有表，面板读全局就是 nil
--   （2026-08-31 玩家实测「大秘境情报数据未加载」，就是这一行的锅）。
GearInsight = GearInsight or {}
GearInsight.MplusMeta = {
    tag = "9月第1周 · 第2弹",
    date = "09-01",
    -- ⭐数据新鲜度用 Unix 时间戳判，⛔别用上面那个 date：它只有「09-01」没有年份，
    --   跨年就判反了，也算不出「距今几天」。面板据此提示玩家更新插件。
    epoch = 1788281076,
    season = "第二赛季",
    week = 2,
    pushLevel = 18,
    pushRuns = 2808,
    farmLevel = 10,
    farmRecords = 16800,
    pushTank = {
        { cls="Death Knight", spec="Blood", cn="血DK", pct=79.1, dr=0 },
        { cls="Monk", spec="Brewmaster", cn="酒仙", pct=7.5, dr=0 },
        { cls="Druid", spec="Guardian", cn="熊德", pct=6.4, dr=0 },
        { cls="Paladin", spec="Protection", cn="防骑", pct=2.9, dr=0 },
        { cls="Warrior", spec="Protection", cn="防战", pct=2.8, dr=0 },
        { cls="Demon Hunter", spec="Vengeance", cn="复仇DH", pct=1.2, dr=0 },
    },
    pushHealer = {
        { cls="Paladin", spec="Holy", cn="奶骑", pct=71.5, dr=0 },
        { cls="Shaman", spec="Restoration", cn="奶萨", pct=18.0, dr=0 },
        { cls="Monk", spec="Mistweaver", cn="奶僧", pct=4.3, dr=0 },
        { cls="Evoker", spec="Preservation", cn="奶龙", pct=3.2, dr=0 },
        { cls="Priest", spec="Holy", cn="神牧", pct=2.9, dr=0 },
    },
    pushDps = {
        { cls="Warlock", spec="Demonology", cn="恶魔术", med=338061, dr=0 },
        { cls="Mage", spec="Arcane", cn="奥法", med=322118, dr=0 },
        { cls="Shaman", spec="Elemental", cn="元素萨", med=317090, dr=0 },
        { cls="Rogue", spec="Outlaw", cn="狂徒贼", med=315469, dr=0 },
        { cls="Monk", spec="Windwalker", cn="踏风", med=311095, dr=0 },
        { cls="Rogue", spec="Assassination", cn="刺杀贼", med=307881, dr=0 },
        { cls="Warrior", spec="Arms", cn="武器战", med=305024, dr=0 },
        { cls="Death Knight", spec="Unholy", cn="邪DK", med=304913, dr=0 },
    },
    farmDps = {
        { cls="Warlock", spec="Demonology", cn="恶魔术", med=332235, dr=0 },
        { cls="Mage", spec="Arcane", cn="奥法", med=311869, dr=0 },
        { cls="Shaman", spec="Elemental", cn="元素萨", med=296444, dr=0 },
        { cls="Paladin", spec="Retribution", cn="惩戒骑", med=289783, dr=0 },
        { cls="Rogue", spec="Subtlety", cn="敏锐贼", med=285731, dr=0 },
        { cls="Warrior", spec="Arms", cn="武器战", med=285342, dr=0 },
        { cls="Rogue", spec="Assassination", cn="刺杀贼", med=279436, dr=0 },
        { cls="Monk", spec="Windwalker", cn="踏风", med=278826, dr=0 },
    },
    farmTanks = {
        { cls="Death Knight", spec="Blood", cn="血DK", med=186169 },
        { cls="Warrior", spec="Protection", cn="防战", med=165950 },
        { cls="Demon Hunter", spec="Vengeance", cn="复仇DH", med=163411 },
        { cls="Paladin", spec="Protection", cn="防骑", med=156164 },
        { cls="Druid", spec="Guardian", cn="熊德", med=152916 },
        { cls="Monk", spec="Brewmaster", cn="酒仙", med=140227 },
    },
    farmHeals = {
        { cls="Evoker", spec="Preservation", cn="奶龙", med=75809 },
        { cls="Paladin", spec="Holy", cn="奶骑", med=71675 },
        { cls="Monk", spec="Mistweaver", cn="奶僧", med=66906 },
        { cls="Druid", spec="Restoration", cn="奶德", med=64113 },
        { cls="Shaman", spec="Restoration", cn="奶萨", med=56540 },
        { cls="Priest", spec="Holy", cn="神牧", med=53769 },
    },
    pushUnder = {
        { cls="Rogue", spec="Outlaw", cn="狂徒贼", gap=6.7, pct=2.4 },
        { cls="Monk", spec="Windwalker", cn="踏风", gap=8.0, pct=1.0 },
        { cls="Death Knight", spec="Unholy", cn="邪DK", gap=9.8, pct=0.8 },
        { cls="Druid", spec="Feral", cn="猫德", gap=10.5, pct=2.5 },
    },
    farmUnder = {
        { cls="Rogue", spec="Subtlety", cn="敏锐贼", gap=14.0, pct=1.8 },
        { cls="Monk", spec="Windwalker", cn="踏风", gap=16.1, pct=1.0 },
        { cls="Death Knight", spec="Unholy", cn="邪DK", gap=16.1, pct=0.8 },
        { cls="Demon Hunter", spec="Havoc", cn="浩劫DH", gap=17.6, pct=0.8 },
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
