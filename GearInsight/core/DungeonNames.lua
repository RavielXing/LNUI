-- core/DungeonNames.lua —— 本赛季大米副本的「中文名 ↔ 客户端本地化名」对照表。
--
-- 为什么单独一个文件、且留在主插件里（2026-09-04 拆分副本模块时新增）：
--   ① ui/LootSpecHint.lua（拾取专精提示，主插件常驻）需要把 GetInstanceInfo() 返回的
--      本地化副本名归一成中文，才能跟 BisData 里烘死的中文 bossName/source 对上。
--      它原本借 GearInsightDungeonData 做这件事 —— 那份数据现在搬进了按需加载的
--      GearInsight_Dungeon，**不加载时就是 nil**。
--      ⛔ 老代码的兜底是 `return localizedName`：中文客户端碰巧相等所以看不出问题，
--         英文/繁中客户端会**静默匹配不上**（提示整个不出，且不报错）。
--         所以名字表必须留在主插件，不能跟着数据一起搬走。
--   ② core/DungeonModule.lua（按需加载器）也要用它判断「当前这个本我们有没有数据」，
--      从而决定要不要提示加载 —— 那一步发生在子插件加载**之前**，更不能依赖子插件。
--
-- 维护：跟 core/DungeonData.lua 同源（generate_dungeon_lua.py），换赛季两边一起更新。
-- ⚠ 只放名字，别往这儿加任何逐本数据 —— 加了就等于把按需加载的那部分又拽回常驻内存。

GearInsight = GearInsight or {}

GearInsight.DUNGEON_NAMES = {
    { cn = "毒牙祭坛",       en = "Altar of Fangs",       shortCn = "毒牙", shortEn = "Fangs" },
    { cn = "纳洛拉克的洞穴", en = "Den of Nalorakk",      shortCn = "熊洞", shortEn = "Nalorakk" },
    { cn = "诸王之眠",       en = "King's Rest",          shortCn = "诸王", shortEn = "KingsRest" },
    { cn = "密谋小径",       en = "Murder Row",           shortCn = "密谋", shortEn = "MurderRow" },
    { cn = "红玉新生法池",   en = "Ruby Life Pools",      shortCn = "红玉", shortEn = "RubyPools" },
    { cn = "塞塔里斯神庙",   en = "Temple of Sethraliss", shortCn = "神庙", shortEn = "Sethraliss" },
    { cn = "夺目谷",         en = "The Blinding Vale",    shortCn = "夺目", shortEn = "BlindingVale" },
    { cn = "虚空之痕竞技场", en = "Voidscar Arena",       shortCn = "虚空", shortEn = "Voidscar" },
}

-- 本地化副本名 → 数据里用的中文名；不是本赛季的本返回 nil。
-- ⛔别改成「认不出就把原名返回去」：那正是上面 ① 说的静默降级。
--    调用方需要「这不是我们支持的本」这个信息，而不是一个假的中文名。
function GearInsight.DungeonCnName(localizedName)
    if not localizedName then return nil end
    for _, d in ipairs(GearInsight.DUNGEON_NAMES) do
        if d.cn == localizedName or d.en == localizedName then return d.cn end
    end
    return nil
end

-- 天赋载入档等窄空间使用的稳定简称。只对本赛季已知副本缩写；未知名字原样返回，
-- 避免数据换季时把不同副本粗暴截成同一个名字。
function GearInsight.DungeonShortName(name, useChinese)
    if not name then return "" end
    for _, d in ipairs(GearInsight.DUNGEON_NAMES) do
        if d.cn == name or d.en == name then
            return useChinese and d.shortCn or d.shortEn
        end
    end
    return name
end
