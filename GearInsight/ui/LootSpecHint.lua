-- 拾取专精提示：进大秘境时，算「你这套 BiS 在本副本能掉几件」，
-- 并比较同职业其它专精的拾取池，命中更多就提示切换。
--
-- ⭐ 竞品 KeystoneLoot（410 万下载）也做这个，但它只知道「物品在不在池子里」。
--    我们多一层：BisData 里每件都带 usagePct（顶尖玩家实穿率），
--    所以能算「切过去多拿到的是不是真值得的东西」，而不只是数量。
--
-- ⛔⛔ 两个跨语言坑（都踩过同族的）：
--    ① BisData 的 key 是**三段** "WARRIOR/FURY/Slayer"（含英雄天赋），
--       不是 RotationData 那种两段 —— 同一专精有多个英雄天赋分支，
--       物品会重复出现，必须按 itemId 去重，否则数量翻倍。
--    ② BisData 的 bossName / source 烘的是**中文**，而 GetInstanceInfo() 返回的是
--       客户端本地化名 —— 英文客户端一比就永远不匹配。
--       ✅ 借 core/DungeonNames.lua 的 { cn=, en= } 做一次归一，再用中文名去比。
GearInsight = GearInsight or {}
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    local L = GearInsight.LOC or {}
    local cur = L[_LOCALE]
    if cur and cur[key] then return cur[key] end
    if _LOCALE ~= "zhTW" then
        local en = L["enUS"]
        if en and en[key] then return en[key] end
    end
    return zh
end

-- 本地化副本名 → 数据里用的中文名。
-- 2026-09-04：名字表从 GearInsightDungeonData 挪到了 core/DungeonNames.lua。
--   原因：那份数据搬进了按需加载的 GearInsight_Dungeon，不加载时是 nil，
--   而这里是**主插件常驻逻辑**，不能依赖一个可能没加载的模块。
--   ⛔ 老兜底 `return localizedName` 在英文/繁中客户端会静默匹配不上（提示整个不出且不报错）。
local function DungeonCn(localizedName)
    return GearInsight.DungeonCnName and GearInsight.DungeonCnName(localizedName) or nil
end

-- ⛔⛔ bug #107（2026-09-04 修）：下面两个函数原来都在**顶层** pairs(GearInsight.BisData)
--   里找 "CLASS/SPEC/Hero" 键。可那些键在 `BisData.specs` 里，顶层只有 version /
--   consumables / specs / items 这些 —— 两个循环**一次都匹配不上**：
--   SpecsOfClass 恒返回空表、HitsForSpec 恒返回 0，整个「拾取专精提示」是死的。
--   失败路径和「这个本确实没推荐」完全同形（都是什么都不显示），所以一直没人发现。
--   ⛔ 别再写 pairs(BisData)：专精数据的唯一入口是 BisData.specs。

-- 专精键集合（"CLASS/SPEC/Hero"）。这里**只读键名**，不碰 bisBySlot，
-- 所以不会触发 core/BisPack.lua 的解码 —— 是廉价操作。
local function SpecKeys()
    local B = GearInsight.BisData
    return (B and B.specs) or nil
end

-- 某专精在本副本的 BiS 命中：返回 件数, 最高实穿率, 代表物品名
-- ⛔ 按 itemId 去重：同一专精的多个英雄天赋分支会重复列同一件装备。
-- ⚠ 这里会读 spec.bisBySlot → 触发该专精解码建表。只会命中**本职业本专精**的
--   那 1~2 个英雄天赋键，⛔别改成遍历全部 40 个专精：那会把按需解码打穿。
local function HitsForSpec(classToken, specToken, dungeonCn)
    local specs = SpecKeys()
    if not specs or not dungeonCn then return 0, 0, nil end
    local prefix = "^" .. classToken .. "/" .. specToken .. "/"
    local seen, n, best, bestName = {}, 0, 0, nil
    for key, spec in pairs(specs) do
        if type(key) == "string" and key:find(prefix) then
            for _, items in pairs(spec.bisBySlot or {}) do
                for _, it in ipairs(items) do
                    if it.itemId and not seen[it.itemId] and it.bossName == dungeonCn then
                        seen[it.itemId] = true
                        n = n + 1
                        local u = tonumber(it.usagePct) or 0
                        if u > best then best, bestName = u, it.itemName end
                    end
                end
            end
        end
    end
    return n, best, bestName
end

-- 同职业的全部专精 token（从 BisData 的 key 里提，⛔别硬编码，新专精会漏）
local _warned = false
local function SpecsOfClass(classToken)
    local specs = SpecKeys()
    if not specs then
        -- ⭐ 留一条痕迹：这个功能失败时和「本副本没推荐」长得一模一样，
        --   没有这句话就永远分不清「没数据」和「取数据取错了」（bug #107 活了很久的原因）。
        if not _warned then
            _warned = true
            GearInsight:Print("|cffff5555GearInsight: BisData.specs 不可用，拾取专精提示已跳过|r")
        end
        return {}
    end
    local out, seen = {}, {}
    for key in pairs(specs) do
        if type(key) == "string" then
            local c, sp = key:match("^([A-Z_]+)/([A-Z_]+)/")
            if c == classToken and sp and not seen[sp] then
                seen[sp] = true
                out[#out + 1] = sp
            end
        end
    end
    table.sort(out)
    return out
end

-- specID -> "CLASS/SPEC"（借 RotationData 现成映射，见 MetaAttach 里同款注释）
local function KeyBySpecID(id)
    if not id or type(_G.GearInsightRotation) ~= "table" then return nil end
    for k, v in pairs(_G.GearInsightRotation) do
        if v and v.specID == id then return k end
    end
end

local function Evaluate()
    local name, itype = GetInstanceInfo()
    if itype ~= "party" then return nil end          -- 只在 5 人本里算
    local dungeonCn = DungeonCn(name)
    local _, classToken = UnitClass("player")
    if not classToken then return nil end

    -- 当前拾取专精：0 表示「跟随当前专精」
    local lootSpecID = GetLootSpecialization and GetLootSpecialization() or 0
    local curIdx = GetSpecialization and GetSpecialization()
    local curSpecID = curIdx and GetSpecializationInfo and GetSpecializationInfo(curIdx) or nil
    local effectiveID = (lootSpecID ~= 0) and lootSpecID or curSpecID
    local effKey = KeyBySpecID(effectiveID)
    local effSpec = effKey and effKey:match("^[A-Z_]+/([A-Z_]+)$")

    local rows = {}
    for _, sp in ipairs(SpecsOfClass(classToken)) do
        local n, best, bestName = HitsForSpec(classToken, sp, dungeonCn)
        rows[#rows + 1] = { spec = sp, n = n, best = best, bestName = bestName }
    end
    if #rows == 0 then return nil end
    table.sort(rows, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return (a.best or 0) > (b.best or 0)
    end)

    local cur
    for _, r in ipairs(rows) do if r.spec == effSpec then cur = r end end
    return { dungeon = dungeonCn, rows = rows, cur = cur, top = rows[1],
             lootSpecID = lootSpecID }
end

-- 只在「有更优选择」时说话。⛔别每次进本都弹 —— 噪声化之后玩家就直接关插件了。
local function Announce()
    local r = Evaluate()
    if not (r and r.top) then return end
    if r.cur and r.cur.n >= r.top.n then return end          -- 当前已是最优，闭嘴
    if r.top.n == 0 then return end                          -- 本副本一件都不掉，没意义

    local curN = r.cur and r.cur.n or 0
    local msg = ("|cffffd100GearInsight|r %s"):format(
        T("LS_HINT", "拾取专精提示：%s 在本本能掉 %d 件毕业装，你当前拾取只吃到 %d 件")
            :format(r.top.spec, r.top.n, curN))
    print(msg)
    if r.top.bestName then
        print(("  |cff888888%s %s（实穿率 %.0f%%）|r"):format(
            T("LS_INCL", "其中包括"), r.top.bestName, r.top.best or 0))
    end
    print("  |cff888888" .. T("LS_HOW", "改拾取专精：角色界面 → 专精 → 拾取专精") .. "|r")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CHALLENGE_MODE_START")
ev:SetScript("OnEvent", function()
    -- 延后一拍：开门那一刻 GetInstanceInfo 偶尔还是上一个区域
    C_Timer.After(2, Announce)
end)

-- 供面板/斜杠命令调用，返回完整评估（也方便以后做成 UI 而不是聊天框）
function GearInsight:LootSpecEvaluate() return Evaluate() end
function GearInsight:LootSpecAnnounce() Announce() end
