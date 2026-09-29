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
    { instanceID = 2993, challengeID = 588, tw = "毒牙祭壇", cn = "毒牙祭坛",       en = "Altar of Fangs",       shortCn = "毒牙", shortEn = "Fangs" },
    { instanceID = 2825, challengeID = 586, tw = "納羅拉克之穴", cn = "纳洛拉克的洞穴", en = "Den of Nalorakk",      shortCn = "熊洞", shortEn = "Nalorakk" },
    { instanceID = 1762, challengeID = 249, tw = "諸王之眠", cn = "诸王之眠",       en = "King's Rest",          shortCn = "诸王", shortEn = "KingsRest" },
    { instanceID = 2813, challengeID = 587, tw = "兇殺路", cn = "密谋小径",       en = "Murder Row",           shortCn = "密谋", shortEn = "MurderRow" },
    { instanceID = 2521, challengeID = 399, tw = "晶紅生命之池", cn = "红玉新生法池",   en = "Ruby Life Pools",      shortCn = "红玉", shortEn = "RubyPools" },
    { instanceID = 1877, challengeID = 250, tw = "瑟沙利斯神廟", cn = "塞塔里斯神庙",   en = "Temple of Sethraliss", shortCn = "神庙", shortEn = "Sethraliss" },
    { instanceID = 2859, challengeID = 584, tw = "盲目谷地", cn = "夺目谷",         en = "The Blinding Vale",    shortCn = "夺目", shortEn = "BlindingVale" },
    { instanceID = 2923, challengeID = 585, tw = "虛無之痕競技場", cn = "虚空之痕竞技场", en = "Voidscar Arena",       shortCn = "虚空", shortEn = "Voidscar" },
}

-- IDs / zhTW names verified against Blizzard mythic-keystone dungeon API, 2026-09-28.
-- instanceID is GetInstanceInfo return #8, NOT challengeID or a UI map ID.
-- When an instance ID is available it is authoritative, including unsupported maps.
function GearInsight.DungeonCnName(localizedName, instanceID)
    if instanceID and instanceID > 0 then
        for _, d in ipairs(GearInsight.DUNGEON_NAMES) do
            if d.instanceID == instanceID then return d.cn end
        end
        return nil
    end
    if not localizedName then return nil end
    for _, d in ipairs(GearInsight.DUNGEON_NAMES) do
        if d.cn == localizedName or d.en == localizedName or d.tw == localizedName then return d.cn end
    end
    return nil
end

-- Shared by the loader, guide, live hints and key timeline; no locale dependence.
function GearInsight.CurrentDungeonCnName()
    local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType ~= "party" then return nil end
    return GearInsight.DungeonCnName(name, instanceID)
end

-- 天赋载入档等窄空间使用的稳定简称。只对本赛季已知副本缩写；未知名字原样返回，
-- 避免数据换季时把不同副本粗暴截成同一个名字。
function GearInsight.DungeonShortName(name, useChinese)
    if not name then return "" end
    local cn = GearInsight.DungeonCnName(name)
    for _, d in ipairs(GearInsight.DUNGEON_NAMES) do
        if d.cn == cn then
            return useChinese and d.shortCn or d.shortEn
        end
    end
    return name
end
