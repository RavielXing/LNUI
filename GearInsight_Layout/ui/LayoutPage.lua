-- 「键位」页（用户 2026-09-18）：一键把本专精该有的按钮铺到动作条上，数据 = WCL 顶尖玩家真实按键频率
--   （core/RotationData.lua 的 core/opener），天赋树 / PvP 天赋 / 法术书兜底；铺格子、设绑定、还原之前都自动备份（含绑定，留 10 份，内容相同不重复存），备份可一键还原，
--   也能导出成 MySlot 格式串（协议见 MySlot/protobuf/MySlot.proto：8 字节头 [ver,86,4,22,crc32×4] + protobuf + base64）。
-- ⛔ 全程只用非保护 API：PickupSpell / PlaceAction / PickupAction / ClearCursor / PickupInventoryItem，出战斗即可；
--   铺格子不动绑定；「按推荐键位设置绑定」用 SetBinding + SaveBindings 改这 60 格的键。不碰编辑模式。
-- 两种铺法（用户「两个选项都要有」）：只填空位（已在条上的技能不动、缺的补进空格）/ 清空重铺（管的 60 格清掉按计划铺）。
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
local GOLD = { 1, 0.82, 0 }

-- 管的格子：暴雪默认布局里玩家看得见的 5 条。名字按游戏里的叫法，格号是 GetActionInfo 的槽位。
--   主条 1–12 · 条2(左下) 61–72 · 条3(右下) 49–60 · 条4(右) 25–36 · 条5(右2) 37–48
local BARS = {
    { key = "bar1", label = T("LY_BAR1", "主条"),   from = 1,  to = 12 },
    { key = "bar2", label = T("LY_BAR2", "条2·左下"), from = 61, to = 72 },
    { key = "bar3", label = T("LY_BAR3", "条3·右下"), from = 49, to = 60 },
    { key = "bar4", label = T("LY_BAR4", "条4·右"),  from = 25, to = 36 },
    { key = "bar5", label = T("LY_BAR5", "条5·右2"), from = 37, to = 48 },
}
local MAX_SLOT = 180

local PickupSpell = (C_Spell and C_Spell.PickupSpell) or _G.PickupSpell
local PickupItem = (C_Item and C_Item.PickupItem) or _G.PickupItem

local macroNameOf, libName   -- 定义在宏库段（ApplyKeyBindings 在它前面就要用，先声明）
-- ── 快照 / 还原 ──────────────────────────────────────────────────────────────
local function slotInfo(i)
    local t, id, sub = GetActionInfo(i)
    if not t then return nil end
    local r = { t = t, id = id, sub = sub }
    if t == "macro" then
        -- 12.x 宏格 GetActionInfo 回的 id 不是宏序号（带 subType 时是技能 id）。⛔ 别用 PickupAction/PlaceAction 去光标上拿：
        --   PlaceAction 会触发 ACTIONBAR_SLOT_CHANGED → refresh → 又 slotInfo → 事件雪崩直接把游戏跑到内存不足（2026-09-18 用户「点了这个直接死机，无限换键位」）
        --   GetActionText 直接给宏名，零副作用；序号再按名反查
        local name = GetActionText(i)
        if not name or name == "" then name = (type(id) == "number") and GetMacroInfo(id) or id end
        r.name = name
        local idx = name and GetMacroIndexByName(name)
        if idx and idx > 0 then r.id = idx end
    elseif t == "spell" and sub == "assistedcombat" and C_AssistedCombat then
        r.id = C_AssistedCombat.GetActionSpell()
    end
    return r
end

function GearInsight:SnapshotBars(reason)
    local snap = { time = time(), date = date("%m-%d %H:%M"), char = UnitName("player"), slots = {}, reason = reason }
    local specIdx = GetSpecialization and GetSpecialization()
    if specIdx then local _, n = GetSpecializationInfo(specIdx); snap.spec = n end
    for i = 1, MAX_SLOT do
        local r = slotInfo(i)
        if r then snap.slots[i] = r end
    end
    -- 全部按键绑定都存（命令 → 键）：设置绑定会把 Q/E 这种从「向左/右平移」上抢过来，只存 60 格的话还原时 Q/E 回不去
    snap.binds = {}
    for i = 1, GetNumBindings() do
        local cmd, _, k1, k2 = GetBinding(i)
        if cmd and (k1 or k2) then snap.binds[cmd] = { k1, k2 } end
    end
    -- 签名：格子 + 绑定拼成串，和上一份一样就不重复存
    local sig = {}
    for i = 1, MAX_SLOT do local r = snap.slots[i]; if r then sig[#sig + 1] = i .. ":" .. r.t .. ":" .. tostring(r.name or r.id) end end
    for cmd, b in pairs(snap.binds) do sig[#sig + 1] = cmd .. "=" .. tostring(b[1]) .. "/" .. tostring(b[2]) end
    table.sort(sig)
    snap.sig = table.concat(sig, "|")
    return snap
end
-- 备份显示名：「枫叶虎鲸·鲜血 09-18 16:42 · 清空重铺前」
function GearInsight.BackupTitle(snap)
    if snap.title and snap.title ~= "" then return string.format("%s  |cff888888%s·%s %s|r", snap.title, snap.char or "?", snap.spec or "?", snap.date or "?") end
    return string.format("%s·%s  %s  · %s", snap.char or "?", snap.spec or "?", snap.date or "?", snap.reason or T("LY_R_MANUAL", "手动保存"))
end
-- 永久保存（用户 2026-09-18「加个永久保存的按钮，标记永久保存的可以重命名」）：pinned 的不进 10 份轮换、不被一键清理，可改名
local MAX_ROTATE, MAX_PINNED = 10, 6
-- 列表显示顺序：永久的排前面（按存入先后），其余按时间倒序；返回 { {snap, idx} ... }
function GearInsight.OrderedBackups()
    local L = (GearInsightDB and GearInsightDB.layoutBackups) or {}
    local out = {}
    for i, sn in ipairs(L) do if sn.pinned then out[#out + 1] = { snap = sn, idx = i } end end
    for i, sn in ipairs(L) do if not sn.pinned then out[#out + 1] = { snap = sn, idx = i } end end
    return out
end
function GearInsight.TrimBackups(L)
    local n = 0
    for _, sn in ipairs(L) do if not sn.pinned then n = n + 1 end end
    for i = #L, 1, -1 do
        if n <= MAX_ROTATE then break end
        if not L[i].pinned then table.remove(L, i); n = n - 1 end
    end
end
function GearInsight.CountPinned()
    local n = 0
    for _, sn in ipairs((GearInsightDB and GearInsightDB.layoutBackups) or {}) do if sn.pinned then n = n + 1 end end
    return n, MAX_PINNED
end

-- 格号 → 绑定命令名（暴雪默认：主条 ACTIONBUTTONn，左下 MULTIACTIONBAR1，右下 2，右 3，右2 4）
local CMD_PREFIX = { bar1 = "ACTIONBUTTON", bar2 = "MULTIACTIONBAR1BUTTON", bar3 = "MULTIACTIONBAR2BUTTON", bar4 = "MULTIACTIONBAR3BUTTON", bar5 = "MULTIACTIONBAR4BUTTON" }
function GearInsight.SlotCommand(slot)
    for _, bar in ipairs(BARS) do
        if slot >= bar.from and slot <= bar.to then return CMD_PREFIX[bar.key] .. (slot - bar.from + 1) end
    end
end

-- 推荐键位默认表（可改；改动存 GearInsightDB.layoutKeys[专精][格号]）
local KEYROW = { "1", "2", "3", "4", "5", "6", "Q", "E", "R", "F", "T", "G" }
local DEFAULT_MOD = { bar1 = "", bar2 = "SHIFT-", bar3 = "CTRL-", bar4 = "ALT-", bar5 = "F" }
function GearInsight.DefaultKey(slot)
    for _, bar in ipairs(BARS) do
        if slot >= bar.from and slot <= bar.to then
            local n = slot - bar.from + 1
            if bar.key == "bar5" then return "F" .. n end
            return DEFAULT_MOD[bar.key] .. KEYROW[n]
        end
    end
end
local function keyStore()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.layoutKeys = GearInsightDB.layoutKeys or {}
    local idx = GetSpecialization and GetSpecialization()
    local specID = (idx and GetSpecializationInfo(idx)) or 0
    GearInsightDB.layoutKeys[specID] = GearInsightDB.layoutKeys[specID] or {}
    return GearInsightDB.layoutKeys[specID]
end
-- 智能推荐表持久化（按专精）：让推荐键「粘」住，不随每次重算漂移
local function smartStore()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.layoutSmart = GearInsightDB.layoutSmart or {}
    local idx = GetSpecialization and GetSpecialization()
    local specID = (idx and GetSpecializationInfo(idx)) or 0
    GearInsightDB.layoutSmart[specID] = GearInsightDB.layoutSmart[specID] or {}
    return GearInsightDB.layoutSmart[specID]
end
GearInsight.ClearSmartKeys = function() local t = smartStore(); for k in pairs(t) do t[k] = nil end end
-- 键池：按左手手感从好到差（WASD 附近、无修饰 → Shift → Ctrl → Alt → 远端数字 / F 键）。
--   7 8 9 0 - = 这排要伸手，排最后（用户「7 8 9 0 这种不好按的，智能换键位推荐」）。
local KEY_POOL = {}
local function buildKeyPool()
    for i = #KEY_POOL, 1, -1 do KEY_POOL[i] = nil end
    -- ⛔ 裸 W A S D Q E 是移动键，不进池（用户「QE AD 都不参与」）；带 Shift/Alt/Ctrl 的可以（「可以用 s+? a+?」）；F1-F4 顺手，F5 起算难按
    local bare = { "1", "2", "3", "4", "5", "R", "F", "T", "G", "Z", "X", "C", "V", "B" }
    -- 裸 Q E 可选加入（用户「Q E 是否加入按钮序列，做个可选项」）：开了就排在 1-5 之后，其余不变
    if GearInsightDB and GearInsightDB.layoutUseQE then bare = { "1", "2", "3", "4", "5", "Q", "E", "R", "F", "T", "G", "Z", "X", "C", "V", "B" } end
    local modBase = { "1", "2", "3", "4", "5", "Q", "E", "R", "F", "T", "G", "Z", "X", "C", "V", "A", "D", "S", "W" }
    for _, k in ipairs(bare) do KEY_POOL[#KEY_POOL + 1] = k end
    for _, m in ipairs({ "SHIFT-", "ALT-", "CTRL-" }) do for _, k in ipairs(modBase) do KEY_POOL[#KEY_POOL + 1] = m .. k end end
    for i = 1, 4 do KEY_POOL[#KEY_POOL + 1] = "F" .. i end
    for _, k in ipairs({ "6", "SHIFT-6", "ALT-6", "CTRL-6", "`", "SHIFT-`", "TAB", "SHIFT-TAB" }) do KEY_POOL[#KEY_POOL + 1] = k end
    for i = 5, 12 do KEY_POOL[#KEY_POOL + 1] = "F" .. i end
    for _, k in ipairs({ "7", "8", "9", "0", "-", "=", "SHIFT-7", "SHIFT-8", "SHIFT-9", "SHIFT-0" }) do KEY_POOL[#KEY_POOL + 1] = k end
end
local POOL_RANK = {}
local HARD_RANK
local function rebuildKeyPool()
    buildKeyPool()
    for k in pairs(POOL_RANK) do POOL_RANK[k] = nil end
    for i, k in ipairs(KEY_POOL) do POOL_RANK[k] = i end
    HARD_RANK = POOL_RANK["F5"]   -- 从 F5 起算「难按」
end
rebuildKeyPool()
GearInsight.RebuildKeyPool = rebuildKeyPool
local function isOurCmd(cmd) return cmd and (cmd:match("^ACTIONBUTTON%d+$") or cmd:match("^MULTIACTIONBAR%dBUTTON%d+$")) end
-- 键能不能给动作条用：没绑 / 绑在我们管的 60 格上 = 可以；绑在移动/技能栏切换等别的功能上 = 不碰
local function keyFree(k)
    -- 用户勾了「Q E 也参与分键」：Q/E 从左右平移上拿过来（设置绑定时会提示被挪走）
    if (k == "Q" or k == "E") and GearInsightDB and GearInsightDB.layoutUseQE then return true end
    local cmd = GetBindingAction(k)
    return not cmd or cmd == "" or isOurCmd(cmd)
end

-- 用户个性化键位快照（用户 2026-09-18「点了智能换再点回去，要能回去之前用户个性化的设置」）：
--   第一次打开这页 / 第一次「设置绑定」之前，把 60 格当时的绑定按专精记一份；「保留现有键位」读的是这份，不是被智能改过之后的实况
local function keySnapStore()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.layoutKeySnap = GearInsightDB.layoutKeySnap or {}
    local idx = GetSpecialization and GetSpecialization()
    local specID = (idx and GetSpecializationInfo(idx)) or 0
    return GearInsightDB.layoutKeySnap, specID
end
-- fromPanel = true：记的是右边面板现在显示的键（手动改的 > 推荐 > 实况），不是游戏实际绑定
function GearInsight.EnsureKeySnapshot(force, fromPanel)
    local store, specID = keySnapStore()
    if store[specID] and not force then return store[specID] end
    local snap = {}
    for _, bar in ipairs(BARS) do
        for sl = bar.from, bar.to do
            local k = fromPanel and GearInsight.SlotKey(sl) or GetBindingKey(GearInsight.SlotCommand(sl))
            if k and k ~= "" then snap[sl] = k end
        end
    end
    snap._at = date("%m-%d %H:%M")
    store[specID] = snap
    return snap
end
function GearInsight.UserKey(slot)
    local store, specID = keySnapStore()
    local snap = store[specID]
    if snap then return snap[slot] end
    return GetBindingKey(GearInsight.SlotCommand(slot))
end

-- 键位策略：手动选过就听手动的；没选过 → 60 格里绑了键的不到 10 个（新号 / 空条）= 智能，否则保留（用户 2026-09-18 同意）
function GearInsight.KeepKeysMode()
    if GearInsightDB and GearInsightDB.layoutKeepKeys ~= nil then return GearInsightDB.layoutKeepKeys and true or false end
    local bound = 0
    for _, bar in ipairs(BARS) do for sl = bar.from, bar.to do if GetBindingKey(GearInsight.SlotCommand(sl)) then bound = bound + 1 end end end
    return bound >= 10
end

-- 给整份计划算推荐键：slots 按职能顺序（主循环最先挑）。返回 slot → key
function GearInsight.SmartKeys(slots)
    local st = keyStore()
    local used, out = {}, {}
    -- ① 用户手动改过的先占
    for _, p in ipairs(slots) do
        local v = st[p.slot]
        if v then out[p.slot] = v; used[v] = true end
    end
    -- ② 「保留现有键位」模式：现在绑着的键原样留着；「智能换键位」模式：⛔ 不保留，全部按键池顺序重排——
    --    否则 1-5 绑在控制行上也会被当「顺手」留住，主循环反而拿不到（用户 2026-09-18「12345 理论上是最上面那些频繁按的常规按钮」）
    local smart = not GearInsight.KeepKeysMode()
    if not smart then
        for _, p in ipairs(slots) do
            if out[p.slot] == nil and st[p.slot] ~= false and not p.inMacro then
                local cur = GearInsight.UserKey(p.slot)   -- 个性化快照里的键，不是被智能改过的实况
                if cur and not used[cur] then out[p.slot] = cur; used[cur] = true end
            end
        end
    end
    -- ③ 智能推荐是「粘」的：上次算过的推荐键只要没被手动占走就原样保留，⛔ 不许因为用户改了某一格就把其他格全部顺位重排
    --    （用户 2026-09-18「我设置一个按键的时候，为什么会改其他的按键」「一定不要改之前任何其他按键」）。按专精存进 DB，重载后也稳
    local sticky = smartStore()
    if smart then
        for _, p in ipairs(slots) do
            local prev = sticky[p.slot]
            if out[p.slot] == nil and st[p.slot] ~= false and prev and prev ~= "" and not used[prev] and keyFree(prev) then
                out[p.slot] = prev; used[prev] = true
            end
        end
    end
    -- ④ 剩下的（新格 / 键被手动抢走的格）按键池顺序补：主循环最先拿到最顺手的
    local pi = 1
    for pass = 1, 2 do   -- 进了爆发/保命宏的技能和物品最后分（按宏格那一个键就够）
        -- 第二轮（宏里的）从带修饰键的段开始挑：裸 1-5 R F T G Z X C V B 是主要键位，一个都不给它们（用户「RFTGZ 不要浪费在宏能包括的上面」）
        if pass == 2 and pi < (POOL_RANK["SHIFT-1"] or 1) then pi = POOL_RANK["SHIFT-1"] or pi end
        for _, p in ipairs(slots) do
            -- 智能模式下 st==false（撞键时被设成「不绑」的格）不算数，全局重排；保留模式才尊重
            if ((pass == 1 and not p.inMacro) or (pass == 2 and p.inMacro)) and out[p.slot] == nil and st[p.slot] ~= false then
                while KEY_POOL[pi] and (used[KEY_POOL[pi]] or not keyFree(KEY_POOL[pi])) do pi = pi + 1 end
                if KEY_POOL[pi] then out[p.slot] = KEY_POOL[pi]; used[KEY_POOL[pi]] = true; pi = pi + 1 end
            end
        end
    end
    -- ⑤ 管的 60 格里没进计划的（空格）：智能模式下不绑（它们现在的键多半被上面挑走了，留着只会撞键）；保留模式下原样
    local planned = {}
    for _, p in ipairs(slots) do planned[p.slot] = true end
    for _, bar in ipairs(BARS) do
        for sl = bar.from, bar.to do
            if not planned[sl] and out[sl] == nil then
                local cur = GearInsight.UserKey(sl)
                if smart or not cur or used[cur] then out[sl] = "" else out[sl] = cur; used[cur] = true end
            end
        end
    end
    if smart then for k in pairs(sticky) do sticky[k] = nil end; for k, v in pairs(out) do sticky[k] = v end end
    return out
end
GearInsight._smartKeys = GearInsight._smartKeys or {}
-- 推荐键 = 手动改的 > 智能推荐表 > 现在绑的 > 默认表
function GearInsight.SlotKey(slot)
    local v = keyStore()[slot]
    if v == false then return nil end   -- 用户按 Backspace 清掉的：两种模式都尊重（撞键已不再写 false，所以 false 只来自用户）
    if v then return v end
    local sk = GearInsight._smartKeys[slot]
    if sk == "" then return nil end   -- 智能表明确说这格不绑
    if sk then return sk end
    local cur = GetBindingKey(GearInsight.SlotCommand(slot))
    return cur or GearInsight.DefaultKey(slot)
end
function GearInsight.SetSlotKey(slot, key)
    keyStore()[slot] = key   -- nil = 回默认；false = 不绑
end

-- 按表设置绑定：先把这 60 个命令上现有的键全解掉，再按推荐键绑；同一个键之前绑在别处会被自动挪过来
function GearInsight:ApplyKeyBindings()
    if InCombatLockdown() then self:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
    self.EnsureKeySnapshot()   -- 第一次动手前记下用户自己的键位（以后「保留现有键位」= 回到这份）
    local slots = self:BuildLayoutPlan()   -- 刷新智能推荐表
    -- 计划里是宏的格：先把宏真建出来放进格子，再绑键——只绑键不建宏，键按下去是空的（用户 2026-09-18「点绑定键位的时候宏不会实现，应该直接实现宏并放到键位」）
    local macroPlaced, macroFail = 0, {}
    for _, p in ipairs(slots) do
        if p.macro then
            local cur = slotInfo(p.slot)
            if not (cur and cur.t == "macro" and cur.name == macroNameOf(p)) then
                local mi = self:EnsureMacroItem(p)
                ClearCursor()
                if mi then PickupMacro(mi) end
                if GetCursorInfo() then PlaceAction(p.slot); macroPlaced = macroPlaced + 1
                else macroFail[#macroFail + 1] = macroNameOf(p) end
                ClearCursor()
            end
        end
    end
    local n = 0
    for _, bar in ipairs(BARS) do
        for sl = bar.from, bar.to do
            local cmd = self.SlotCommand(sl)
            local k1, k2 = GetBindingKey(cmd)
            if k1 then SetBinding(k1, nil) end
            if k2 then SetBinding(k2, nil) end
        end
    end
    -- 撞键：后出现的格直接拿走这个键，先前那格设为无快捷键，聊天框提示一句（用户「撞键位就提示一下，然后直接替换，原来的设为无快捷键」）
    local taken, usedKey, replaced = {}, {}, {}
    for _, bar in ipairs(BARS) do
        for sl = bar.from, bar.to do
            local key = self.SlotKey(sl)
            if key and key ~= "" then
                if usedKey[key] then
                    replaced[#replaced + 1] = string.format(T("LY_REPLACED_FMT", "%s：格 %d -> 格 %d"), GetBindingText(key, 1), usedKey[key], sl)
                    self.SetSlotKey(usedKey[key], false)   -- 原来那格置空「不绑」，不自动补键（用户「一定不要改之前任何其他按键」）
                    n = n - 1
                end
                usedKey[key] = sl
                local prev = GetBindingAction(key)
                if prev and prev ~= "" and not isOurCmd(prev) then taken[#taken + 1] = GetBindingText(key, 1) .. "←" .. (_G["BINDING_NAME_" .. prev] or prev) end
                if SetBinding(key, self.SlotCommand(sl)) then n = n + 1 end   -- SetBinding 会自动把这个键从先前那格解掉
            end
        end
    end
    -- 裸 Q E W A S D 是移动键：智能模式重排后它们不再被动作条占用，空出来就按暴雪默认还给移动（用户「记得把 QE 这种移动按钮重置回去」）
    local MOVE_DEFAULT = { Q = "STRAFELEFT", E = "STRAFERIGHT", W = "MOVEFORWARD", S = "MOVEBACKWARD", A = "TURNLEFT", D = "TURNRIGHT" }
    if GearInsightDB and GearInsightDB.layoutUseQE then MOVE_DEFAULT.Q = nil; MOVE_DEFAULT.E = nil end   -- Q E 进了按钮序列就不还给移动
    local moved = {}
    for k, cmd in pairs(MOVE_DEFAULT) do
        local act = GetBindingAction(k)
        if not act or act == "" then
            local k1, k2 = GetBindingKey(cmd)
            if k1 ~= k and k2 ~= k then SetBinding(k, cmd); moved[#moved + 1] = k .. "=" .. (_G["BINDING_NAME_" .. cmd] or cmd) end
        end
    end
    SaveBindings(2)   -- 一律存角色专用方案：账号方案(1)会波及所有角色
    self:Print(string.format(T("LY_KEYS_DONE", "已按推荐键位设置 %d 个绑定（已保存到当前绑定方案）"), n))
    if #moved > 0 then self:Print(T("LY_KEYS_MOVE_BACK", "移动键已还回：") .. table.concat(moved, "  ")) end
    if #taken > 0 then self:Print(T("LY_KEYS_TAKEN", "这些键原来绑着别的功能，已被挪到动作条（「保存」页还原可全部改回）：") .. table.concat(taken, "  ")) end
    if macroPlaced > 0 then self:Print(string.format(T("LY_KEYS_MACRO_PLACED", "已建好并放上 %d 个宏格"), macroPlaced)) end
    if #macroFail > 0 then self:Print("|cffff8000" .. T("LY_KEYS_MACRO_FAIL", "这些宏没放上（宏栏满了？）：") .. table.concat(macroFail, "  ") .. "|r") end
    if #replaced > 0 then self:Print("|cffffd100" .. T("LY_KEYS_REPLACED", "撞键，已替换（原来那格现在无快捷键）：") .. table.concat(replaced, "  ") .. "|r") end
    if self._layoutRefresh then self._layoutRefresh() end
end

local function placeInto(slot, r)
    ClearCursor()
    if not r then
        PickupAction(slot); ClearCursor(); return true
    end
    if r.t == "spell" then
        PickupSpell(r.id)
    elseif r.t == "macro" then
        local idx = r.name and GetMacroIndexByName(r.name)
        if idx and idx > 0 then PickupMacro(idx) end
    elseif r.t == "item" then
        PickupItem(r.id)
    elseif r.t == "summonmount" and C_MountJournal and C_MountJournal.Pickup then
        -- id 是 mountID，Pickup 要 displayIndex；「随机偏好坐骑」的 id 是 268435455（0xFFFFFFF），用 Pickup(0)
        if r.id == 268435455 or r.id == 0 then C_MountJournal.Pickup(0)
        else
            local n = C_MountJournal.GetNumDisplayedMounts and C_MountJournal.GetNumDisplayedMounts() or 0
            for k = 1, n do
                local _, _, _, _, _, _, _, _, _, _, _, mid = C_MountJournal.GetDisplayedMountInfo(k)
                if mid == r.id then C_MountJournal.Pickup(k); break end
            end
        end
    elseif r.t == "companion" or r.t == "summonpet" then
        if C_PetJournal and C_PetJournal.PickupPet then pcall(C_PetJournal.PickupPet, r.id) end
    elseif r.t == "flyout" and PickupSpellBookItem then
        -- 飞出面板没有稳定拾取法，跳过
        return false
    else
        return false
    end
    if GetCursorInfo() then
        PlaceAction(slot); ClearCursor(); return true
    end
    return false
end

function GearInsight:RestoreBars(snap)
    if InCombatLockdown() then self:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
    -- 动作条是按专精分的：A 专精的备份铺到 B 专精上只会一片红（用户 2026-09-18 同意拦）
    local specIdx = GetSpecialization and GetSpecialization()
    local curSpec = specIdx and select(2, GetSpecializationInfo(specIdx))
    if snap.spec and curSpec and snap.spec ~= curSpec then
        self:Print(string.format(T("LY_RESTORE_SPEC", "这份备份是「%s」专精的，你现在是「%s」——先切回那个专精再还原"), snap.spec, curSpec)); return
    end
    if snap.char and snap.char ~= UnitName("player") then
        self:Print(string.format(T("LY_RESTORE_CHAR", "这份备份是角色「%s」的，不铺到「%s」上"), snap.char, UnitName("player"))); return
    end
    local ok, skip, skipped = 0, 0, {}
    for i = 1, MAX_SLOT do
        local r = snap.slots[i]
        local cur = slotInfo(i)
        local same = (r == nil and cur == nil) or (r and cur and r.t == cur.t and (r.id == cur.id or (r.t == "macro" and r.name == cur.name)))
        if not same then
            if placeInto(i, r) then ok = ok + 1
            else
                skip = skip + 1
                local what = r and (r.t == "macro" and (T("LY_MACRO_WORD", "宏") .. "「" .. tostring(r.name) .. "」") or r.t == "spell" and ((C_Spell.GetSpellInfo(r.id) or {}).name or r.id) or r.t) or "?"
                skipped[#skipped + 1] = string.format(T("LY_SLOT_FMT", "格%d %s"), i, tostring(what))
            end
        end
    end
    if #skipped > 0 then self:Print("|cffff8000" .. T("LY_RESTORE_SKIPPED", "没放回去的：") .. table.concat(skipped, "  ") .. "|r") end
    if snap.binds then
        -- 全量：先解掉现在所有命令上的键，再按快照绑回（快照里没有的命令就保持空）
        for i = 1, GetNumBindings() do
            local cmd, _, k1, k2 = GetBinding(i)
            if cmd then
                if k1 then SetBinding(k1, nil) end
                if k2 then SetBinding(k2, nil) end
            end
        end
        for cmd, b in pairs(snap.binds) do
            if b[1] then SetBinding(b[1], cmd) end
            if b[2] then SetBinding(b[2], cmd) end
        end
        SaveBindings(2)   -- 一律存角色专用方案：账号方案(1)会波及所有角色
    end
    self:Print(string.format(T("LY_RESTORED", "已还原「%s」的键位：改回 %d 格，%d 格没法自动放（飞出面板等）；按键绑定同步还原"), snap.date or "?", ok, skip))
end

-- ── MySlot 串（可粘进 MySlot 导入）──────────────────────────────────────────
-- protobuf 手写编码：Charactor{ slot(1)=repeated Slot, ver(14)=uint32, name(15)=string }
--   Slot{ id(1) uint32, type(2) enum, index(3) uint32, strindex(4) string }
local MS_TYPE = { spell = 1, item = 2, macro = 3, flyout = 4, equipmentset = 6, summonpet = 7, companion = 8, summonmount = 9 }
local function varint(n)
    local out = {}
    repeat
        local b = n % 128
        n = math.floor(n / 128)
        if n > 0 then b = b + 128 end
        out[#out + 1] = string.char(b)
    until n == 0
    return table.concat(out)
end
local function fieldVarint(fn, v) return varint(fn * 8 + 0) .. varint(v) end
local function fieldBytes(fn, s) s = tostring(s or ""); return varint(fn * 8 + 2) .. varint(#s) .. s end   -- 宏格的 name 在宏被删后会退成数字 id，统一 tostring

local CRC_T
local function crc32(bytes)
    if not CRC_T then
        CRC_T = {}
        for i = 0, 255 do
            local c = i
            for _ = 1, 8 do
                if c % 2 == 1 then c = bit.bxor(bit.rshift(c, 1), 0xEDB88320) else c = bit.rshift(c, 1) end
            end
            CRC_T[i] = c
        end
    end
    local crc = 0xFFFFFFFF
    for i = 1, #bytes do
        crc = bit.bxor(CRC_T[bit.band(bit.bxor(crc, bytes[i]), 0xFF)], bit.rshift(crc, 8))
    end
    return bit.band(bit.bnot(crc), 0xFFFFFFFF)
end
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64(bytes)
    local out = {}
    for i = 1, #bytes, 3 do
        local a, b, c = bytes[i], bytes[i + 1], bytes[i + 2]
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

function GearInsight:MySlotString(snap)
    local body = {}
    -- ⛔ MySlot 导入时宏格**只**通过 Charactor.macro 列表落格（按 name+body 找/建宏，再把引用该 id 的格放上），
    --    slot 里 index=0 + 名字它根本不看 → 之前导出串里所有宏格导入后全空（用户 2026-09-18「导出再导入后不是之前的键位了」）。
    --    所以每个宏格都要附一条 Macro{ name(1), body(2), id(3), icon(4) }，Slot.index = 宏序号（照 MySlot:GetMacroInfo 的写法）
    local macros, macroSeen = {}, {}
    for i = 1, MAX_SLOT do
        local r = snap.slots[i]
        local ty = r and MS_TYPE[r.t]
        if ty then
            local s = fieldVarint(1, i) .. fieldVarint(2, ty)
            if r.t == "macro" then
                local idx = (type(r.id) == "number" and r.id > 0 and select(1, GetMacroInfo(r.id)) == r.name) and r.id
                    or (r.name and GetMacroIndexByName(r.name)) or 0
                if idx and idx > 0 then
                    s = s .. fieldVarint(3, idx) .. fieldBytes(4, r.name or "")
                    if not macroSeen[idx] then
                        local name, icon, mbody = GetMacroInfo(idx)
                        if name then
                            macroSeen[idx] = true
                            icon = tostring(icon or "INV_Misc_QuestionMark"):upper():gsub("INTERFACE\\ICONS\\", "")
                            macros[#macros + 1] = fieldBytes(1, name) .. fieldBytes(2, mbody or "") .. fieldVarint(3, idx) .. fieldBytes(4, icon)
                        end
                    end
                else
                    s = s .. fieldVarint(3, 0) .. fieldBytes(4, r.name or "")   -- 宏已删：留名字，MySlot 会报「未知宏」跳过
                end
            elseif type(r.id) == "number" and r.id >= 0 and r.id == math.floor(r.id) then
                s = s .. fieldVarint(3, r.id)
            else
                s = s .. fieldVarint(3, 0) .. fieldBytes(4, tostring(r.id or ""))
            end
            body[#body + 1] = fieldBytes(1, s)
        end
    end
    -- 按键绑定（Bind{ id(1)=命令编号或 0xFFFF, key1(2)/key2(3)=Key{ key(1), mod(2), keycode(15) }, command(15)=自定义命令名 }）
    --   编码表抄自 MySlot/keys.lua（core/MySlotKeys.lua）。之前只导格子不导绑定，导进去键位全空（用户 2026-09-18「保存没有保存正确的字符串，包括导出」）
    local nBind = 0
    local MK = _G.GearInsightMySlotKeys
    if MK and snap.binds then
        local function keyMsg(k)
            if not k then return nil end
            local mod, key = k:match("^(.+)%-(.+)$")
            if not (mod and key) then mod, key = "NONE", k end
            local modId = MK.mods[mod]
            if not modId then return nil end
            local keyId = MK.keys[key]
            local m = fieldVarint(1, keyId or MK.keys["KEYCODE"] or 0) .. fieldVarint(2, modId)
            if not keyId then m = m .. fieldBytes(15, key) end
            return m
        end
        for cmd, b in pairs(snap.binds) do
            local id = MK.binds[cmd]
            local m = fieldVarint(1, id or 0xFFFF)
            if not id then m = m .. fieldBytes(15, cmd) end
            local k1, k2 = keyMsg(b[1]), keyMsg(b[2])
            if k1 then m = m .. fieldBytes(2, k1) end
            if k2 then m = m .. fieldBytes(3, k2) end
            if k1 or k2 then body[#body + 1] = fieldBytes(2, m); nBind = nBind + 1 end
        end
    end
    for _, m in ipairs(macros) do body[#body + 1] = fieldBytes(3, m) end
    body[#body + 1] = fieldVarint(14, 42)
    body[#body + 1] = fieldBytes(15, UnitName("player") or "")
    local payload = table.concat(body)
    local bytes = { 42, 86, 4, 22, 0, 0, 0, 0 }
    for i = 1, #payload do bytes[#bytes + 1] = payload:byte(i) end
    local crc = crc32(bytes)
    bytes[5] = bit.rshift(crc, 24); bytes[6] = bit.band(bit.rshift(crc, 16), 255)
    bytes[7] = bit.band(bit.rshift(crc, 8), 255); bytes[8] = bit.band(crc, 255)
    -- 只给一行 base64：复制框是单行编辑框，带 # 注释头会被折成一行，MySlot 导入时把整行当注释删掉 → 「Bad importing text」
    --   （用户 2026-09-18「myslot 串好像不对」）。MySlot:Import 先删 # 行再去换行再 base64 解码，纯一行 base64 直接能导。
    local out = b64(bytes)
    -- 日志 + 存档留底（用户「加一下日志，然后自己解码对比」）：/reload 后 SavedVariables 里能拿到串，离线解码核对
    local nSlot = 0
    for i = 1, MAX_SLOT do if snap.slots[i] and MS_TYPE[snap.slots[i].t] then nSlot = nSlot + 1 end end
    self:Print(string.format(T("LY_MS_LOG", "MySlot 串：%d 格 + %d 条绑定，%d 字节，来源「%s」"), nSlot, nBind, #bytes, self.BackupTitle(snap)))
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.lastMySlotExport = { at = date("%m-%d %H:%M:%S"), from = self.BackupTitle(snap), slots = nSlot, binds = nBind, str = out }
    return out
end

-- ── 计划：这个专精该铺什么 ──────────────────────────────────────────────────
local function specKey()
    local _, cls = UnitClass("player")
    local idx = GetSpecialization and GetSpecialization()
    local specID = idx and GetSpecializationInfo(idx)
    local R = _G.GearInsightRotation or {}
    for k, v in pairs(R) do
        if v.specID == specID and k:sub(1, #cls) == cls then return k, v end
    end
    return nil
end

local function known(id)
    return id and (IsPlayerSpell(id) or (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id)))
end

-- 法术书里已学、主动、本专精的技能（不含被动 / 其他专精）
local function bookSpells()
    local out, seen = {}, {}
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return out end
    -- 第 1 页是「通用」（种族技能 / 自动攻击 / 坐骑 / 玩具 / 移动银行…），不铺；只要职业页 + 当前专精页
    for li = 2, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(li)
        if line and not line.offSpecID and not line.isGuild then
            for j = 1, line.numSpellBookItems do
                local idx = line.itemIndexOffset + j
                local info = C_SpellBook.GetSpellBookItemInfo(idx, Enum.SpellBookSpellBank.Player)
                if info and info.itemType == Enum.SpellBookItemType.Spell and not info.isPassive and not info.isOffSpec
                    and info.spellID and not seen[info.spellID] and known(info.spellID) then
                    seen[info.spellID] = true
                    out[#out + 1] = info.spellID
                end
            end
        end
    end
    return out
end

-- 返回 { {slot=n, id=spellID}|{slot=n, inv=13} ... } 与说明
-- 职能分组顺序（core/SpellRoles.lua 的键 + 插件自己判的 core/burst/dps/inv）
local ROLE_ORDER = {
    { "core",      T("LY_ROLE_CORE", "主循环"),   T("LY_ROLE_CORE_D", "WCL 顶尖玩家每分钟 ≥ 2 次的") },
    { "burst",     T("LY_ROLE_BURST", "爆发"),     T("LY_ROLE_BURST_D", "基础 CD ≥ 45 秒的输出技能") },
    { "interrupt", T("LY_ROLE_INT", "打断 / 嘲讽"), T("LY_ROLE_INT_D", "打断在前，空一格后是嘲讽") },
    { "cc",        T("LY_ROLE_CC", "控制 / 解控"), T("LY_ROLE_CC_D", "群控 > 单控，空一格后是解控（免疫/解除控制）") },
    { "def",       T("LY_ROLE_DEF", "减伤保命"), "" },
    { "heal",      T("LY_ROLE_HEAL", "治疗"),     "" },
    { "mob",       T("LY_ROLE_MOB", "位移"),     "" },
    { "raid",      T("LY_ROLE_RAID", "团队工具"), T("LY_ROLE_RAID_D", "给队友的减伤 / 增益 / 嗜血") },
    { "dispel",    T("LY_ROLE_DISPEL", "驱散"),     "" },
    { "summon",    T("LY_ROLE_SUMMON", "召唤"),     "" },
    { "util",      T("LY_ROLE_UTIL", "功能"),     T("LY_ROLE_UTIL_D", "不打不奶的主动技能：水上行走、变形、开锁…") },
    { "dps",       T("LY_ROLE_DPS", "其他输出"), T("LY_ROLE_DPS_D", "不在主循环里的短 CD 输出技能") },
    { "inv",       T("LY_ROLE_INV", "坐骑"),     T("LY_ROLE_INV_D", "随机偏好坐骑；主动饰品按效果并进爆发 / 减伤 / 治疗行") },
}
local ROLE_LABEL = {}
-- 「来源/职能」内部标记一律用简中 token 比较（"起手"/"嘲讽"…），显示时经 whyText 翻译——别在比较处改 token
local WHY_LOC = {
    ["起手"] = T("LY_WHY_OPENER", "起手"), ["天赋"] = T("LY_WHY_TALENT", "天赋"), ["PvP 天赋"] = T("LY_WHY_PVP", "PvP 天赋"),
    ["法术书"] = T("LY_WHY_BOOK", "法术书"), ["种族"] = T("LY_WHY_RACIAL", "种族"), ["嘲讽"] = T("LY_WHY_TAUNT", "嘲讽"),
    ["群控"] = T("LY_WHY_AOECC", "群控"), ["单控"] = T("LY_WHY_STCC", "单控"), ["解控"] = T("LY_WHY_CCBREAK", "解控"),
    ["坐骑"] = T("LY_WHY_MOUNT", "坐骑"), ["宏库"] = T("LY_WHY_LIB", "宏库"), ["饰品·主动"] = T("LY_WHY_TRK", "饰品·主动"),
    ["饰品·减伤"] = T("LY_WHY_TRK_DEF", "饰品·减伤"), ["饰品·治疗"] = T("LY_WHY_TRK_HEAL", "饰品·治疗"), ["饰品·爆发"] = T("LY_WHY_TRK_BURST", "饰品·爆发"),
}
local function whyText(w) if not w then return nil end return WHY_LOC[w] or w end
for _, r in ipairs(ROLE_ORDER) do ROLE_LABEL[r[1]] = r[2] end
GearInsight.LayoutRoleOrder = ROLE_ORDER

-- 种族主动技能 → 职能（已知的直接给；不在表里的通用页技能按描述兜底判）
local RACIAL_ROLE = {
    [59752] = "ccbreak", [20589] = "ccbreak", [7744] = "ccbreak",                 -- 求生意志 / 脱逃艺术家 / 被遗忘者的意志
    [20594] = "def", [265221] = "burst",                                         -- 石像形态 / 黑铁之血
    [58984] = "util", [68992] = "mob", [256948] = "mob", [69070] = "mob",        -- 影遁 / 暗影疾行 / 空间裂隙 / 火箭跳
    [59545] = "heal", [59543] = "heal", [59544] = "heal", [59547] = "heal", [59548] = "heal", [28880] = "heal", [121093] = "heal", [20577] = "heal", [291944] = "heal", -- 纳鲁的赐福 / 食尸 / 再生
    [255647] = "burst", [20572] = "burst", [33697] = "burst", [33702] = "burst", [26297] = "burst", [274738] = "burst", [436344] = "burst", [312924] = "burst", -- 圣光审判 / 血性狂暴 / 狂暴 / 先祖召唤 / 艾泽里特涌动 / 超有机光源
    [107079] = "stcc", [287712] = "stcc",                                        -- 震颤掌 / 重拳
    [20549] = "aoecc", [357214] = "aoecc", [368970] = "aoecc", [260364] = "aoecc", [255654] = "aoecc", -- 战争践踏 / 翼击 / 尾扫 / 奥术脉冲 / 蛮牛冲撞
    [25046] = "dispel", [28730] = "dispel", [50613] = "dispel", [69179] = "dispel", [80483] = "dispel", [129597] = "dispel", [155145] = "dispel", [202719] = "dispel", [232633] = "dispel", -- 奥术洪流
    [69041] = "dps", [312411] = "dps",                                           -- 火箭弹幕 / 百宝袋
}
-- 通用页里不是种族技能的：自动攻击 / 移动银行 / 复活战斗宠物 / 坐骑 / 工程玩意 / 冒险模式等
local GENERAL_SKIP = { [6603] = true, [88163] = true, [83958] = true, [125439] = true, [150544] = true, [30449] = true, [125046] = true, [4507] = true }
local function racialSpells()
    local out = {}
    if not (C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo) then return out end
    local line = C_SpellBook.GetSpellBookSkillLineInfo(1)
    if not line then return out end
    for j = 1, line.numSpellBookItems do
        local idx = line.itemIndexOffset + j
        local info = C_SpellBook.GetSpellBookItemInfo(idx, Enum.SpellBookSpellBank.Player)
        if info and info.itemType == Enum.SpellBookItemType.Spell and not info.isPassive and info.spellID and not GENERAL_SKIP[info.spellID] then
            -- 通用页还混着专业/玩具类，靠「有职能表」或「名字不含 Mk / 装置」粗筛
            local nm = info.name or ""
            if RACIAL_ROLE[info.spellID] or not (nm:find("Mk", 1, true) or nm:find("装置", 1, true) or nm:find("旁路器", 1, true) or nm:find("探测器", 1, true) or nm:find("银行", 1, true)) then
                out[#out + 1] = info.spellID
            end
        end
    end
    return out
end

local GROUP_MACRO_KEYS = { burst = true, def = true }   -- 有「AI 成宏」格的行
-- 哪些行上条：功能 / 其他输出 / 召唤 默认不上（把格子留给要按的，用户 2026-09-18 同意）；行头勾选可开
local GROUP_DEFAULT_OFF = { util = true, dps = true, summon = true }
local function groupStore()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.layoutGroups = GearInsightDB.layoutGroups or {}
    local idx = GetSpecialization and GetSpecialization()
    local specID = (idx and GetSpecializationInfo(idx)) or 0
    GearInsightDB.layoutGroups[specID] = GearInsightDB.layoutGroups[specID] or {}
    return GearInsightDB.layoutGroups[specID]
end
function GearInsight.GroupOn(key)
    local v = groupStore()[key]
    if v == nil then return not GROUP_DEFAULT_OFF[key] end
    return v and true or false
end
function GearInsight.SetGroupOn(key, on) groupStore()[key] = on and true or false end
local GROUP_MACRO = { burst = { name = T("LY_GM_BURST", "GI爆发宏"), icon = "Ability_Warrior_Rampage" }, def = { name = T("LY_GM_DEF", "GI保命宏"), icon = "Ability_Warrior_DefensiveStance" } }
-- 返回 slots = { {slot=n, id=spellID|nil, inv=13|nil, role=key, talent=bool, why=str} ... }（按职能顺序连续排进 60 格）
--   与 groups = { {key,label,items={...同上...}} ... }（含放不下的，item.slot=nil）
function GearInsight:BuildLayoutPlan()
    local key, R = specKey()
    local items, used, notes = {}, {}, {}
    local NEVER = { [6603] = true, [88163] = true, [150544] = true }  -- 自动攻击 / 攻击 / 坐骑（坐骑单独放）
    local function baseOf(id) return (FindBaseSpellByID and FindBaseSpellByID(id)) or id end
    local function add(id, why, force)
        if not id or NEVER[id] or (not force and not known(id)) then return end
        if C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id) then return end
        -- 副本传送（「传送到 xx 的入口」）一律不铺（用户 2026-09-18「传送副本的一律忽略」）
        local d = (C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(id)) or ""
        if (d:find("传送到", 1, true) and d:find("入口", 1, true)) or d:lower():find("teleports? .-entrance") then return end
        local base = baseOf(id)
        if used[base] then return used[base] end
        if C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(base) then return end
        local it = { id = base, why = why }
        used[base] = it; items[#items + 1] = it; return it
    end
    -- ① WCL 主循环（按每分钟次数），≥ 2 次/分才算主循环，其余按职能分（巫妖之躯 0.5 次/分那种不算）
    local coreSet = {}
    if R then
        local cores = {}
        for _, blk in ipairs({ R.raid, R.mplus }) do
            if blk and blk.core then
                for _, c in ipairs(blk.core) do cores[c[1]] = math.max(cores[c[1]] or 0, c[2]) end
            end
        end
        local order = {}
        for id, cpm in pairs(cores) do order[#order + 1] = { id, cpm } end
        table.sort(order, function(a, b) return a[2] > b[2] end)
        for _, o in ipairs(order) do
            local it = add(o[1], string.format(T("LY_WHY_WCL", "WCL %.1f 次/分"), o[2]))
            if it and o[2] >= 2.0 then it.cpm = o[2]; coreSet[it.id] = true end
        end
        for _, blk in ipairs({ R.raid, R.mplus }) do
            for _, okey in ipairs({ "opener", "openerSt", "openerAoe" }) do
                for _, o in ipairs((blk and blk[okey]) or {}) do
                    for _, id in ipairs(o.seq or {}) do add(id, "起手") end
                end
            end
        end
    else
        notes[#notes + 1] = T("LY_NO_WCL", "本专精暂无 WCL 循环数据，只按天赋 + 法术书分组")
    end
    -- ② 天赋树选中的主动技能：不单独分类，打「天赋」标记（用户「天赋技能用一个视觉效果标记，不用单独分类」）
    local talentSet = {}
    if C_ClassTalents and C_Traits and C_ClassTalents.GetActiveConfigID then
        local cfg = C_ClassTalents.GetActiveConfigID()
        local ci = cfg and C_Traits.GetConfigInfo(cfg)
        for _, treeID in ipairs((ci and ci.treeIDs) or {}) do
            for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                local node = C_Traits.GetNodeInfo(cfg, nodeID)
                local entryID = node and node.activeEntry and node.activeEntry.entryID
                if entryID and (node.activeRank or 0) > 0 then
                    local entry = C_Traits.GetEntryInfo(cfg, entryID)
                    local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                    if def and def.spellID then
                        local it = add(def.spellID, "天赋")
                        if it then talentSet[it.id] = true end
                    end
                end
            end
        end
    end
    -- ③ PvP 天赋
    if C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs and GetPvpTalentInfoByID then
        for _, tid in ipairs(C_SpecializationInfo.GetAllSelectedPvpTalentIDs() or {}) do
            local _, _, _, _, _, spellID = GetPvpTalentInfoByID(tid)
            if spellID and not (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(spellID)) then
                local it = add(spellID, "PvP 天赋", true)
                if it then talentSet[it.id] = true; it.pvp = true end
            end
        end
    end
    -- ④ 法术书兜底
    for _, id in ipairs(bookSpells()) do add(id, "法术书") end
    -- ⑤ 种族技能（通用页），蓝色「族」角标，按职能归行（用户「种族天赋智能识别并放到对应的分类行」）
    local racialSet = {}
    for _, id in ipairs(racialSpells()) do
        local it = add(id, "种族", true)
        if it then racialSet[it.id] = true; it.racial = true; if RACIAL_ROLE[id] then it.role = RACIAL_ROLE[id] end end
    end
    -- ⑤ 职能：主循环 > 表里的职能 > 爆发（基础 CD ≥ 45s）> 其他输出
    local roles = _G.GearInsightSpellRoles or {}
    for _, it in ipairs(items) do
        it.talent = talentSet[it.id] or nil
        if coreSet[it.id] then it.role = "core"
        elseif it.role then -- 种族表已给
        elseif roles[it.id] then it.role = roles[it.id]
        else
            -- 表里没有的：客户端描述里既不提伤害也不提治疗 → 功能类（冰霜之路这种表外的）；否则按基础 CD 分爆发/其他输出
            local desc = (C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(it.id)) or ""
            local dl = desc:lower()
            -- 表外技能（黑暗命令这种基础技能不在天赋表里）：先按描述判嘲讽 / 打断 / 解控
            if desc:find("嘲讽", 1, true) or desc:find("攻击你", 1, true) or desc:find("威胁值提高", 1, true) or dl:find("taunt", 1, true) or dl:find("attack you", 1, true) then
                it.role = "taunt"
            elseif desc:find("打断", 1, true) and (desc:find("无法施放", 1, true) or desc:find("不能施放", 1, true) or desc:find("沉默", 1, true)) or dl:find("interrupt", 1, true) then
                it.role = "interrupt"
            elseif (desc:find("免疫", 1, true) and (desc:find("魅惑", 1, true) or desc:find("恐惧", 1, true) or desc:find("昏迷", 1, true) or desc:find("眩晕", 1, true) or desc:find("沉默", 1, true) or desc:find("控制", 1, true) or desc:find("定身", 1, true) or desc:find("减速", 1, true) or desc:find("睡眠", 1, true)))
                or desc:find("解除[^。]-控制") or desc:find("摆脱[^。]-控制") then
                it.role = "ccbreak"
            elseif desc:find("眩晕") or desc:find("定身") or desc:find("昏迷") or desc:find("束缚") or desc:find("沉默") or desc:find("缴械") or desc:find("恐惧") or desc:find("移动速度降低") or desc:find("减速") or desc:find("变形") or desc:find("瘫痪") or desc:find("击退") then
                -- 控制（寒冰锁链这种表外的）：锥形/范围/所有敌人 = 群控，否则单控
                if desc:find("锥形") or desc:find("范围内") or desc:find("所有敌人") or desc:find("附近") or desc:find("区域") then it.role = "aoecc" else it.role = "stcc" end
            end
            -- 「造成 X 伤害」才算输出；「受到伤害会取消」这种不算（冰霜之路）
            local dealsDmg = desc:find("造成[^。]-伤害") or dl:find("deal[s]? [^.]-damage") or dl:find("inflict")
            local heals = desc:find("治疗") or desc:find("恢复[^。]-生命") or dl:find("heal") or dl:find("restor")
            if it.role then
                -- 上面已判
            elseif desc ~= "" and not dealsDmg and not heals then
                it.role = "util"
            else
                local cd = GetSpellBaseCooldown and GetSpellBaseCooldown(it.id) or 0
                it.role = (cd and cd >= 45000) and "burst" or "dps"
            end
        end
    end
    -- 宏库（core/MacroLib.lua ← 站点各专精宏，Icy Veins / Method 12.1）：勾选的进安排池，按第一个技能的职能归行（用户 2026-09-18）
    local spellRole = {}
    for _, it in ipairs(items) do if it.id then spellRole[it.id] = it.role end end
    local LIB = GearInsight.MacroLibFor(key)
    local libSel = GearInsight.LibStore()
    for _, m in ipairs(LIB) do
        if GearInsight.LibSelected(libSel, m) then
            if m.gi and m.group then
                -- 爆发 / 保命合成宏：正文按整行动态生成（groupItems 在分组后挂上）
                local meta = GROUP_MACRO[m.group]
                items[#items + 1] = { macro = m.group, role = m.group, why = libName(m), sep = true, sep2 = true, macroName = meta.name, macroIcon = meta.icon, libKey = m.key }
            elseif m.gi then
                items[#items + 1] = { macro = m.key, lib = m, macroName = "GI面板", macroIcon = "Interface\\AddOns\\GearInsight\\icon",
                                      macroBody = m.body, missing = {}, role = "util", why = "GearInsight", sep2 = true, gi = true }
            else
                local body, missing = GearInsight.LocalizeMacroBody(m)
                -- 宏里的技能全是主循环的 → 进主循环行（用户「所有宏里的技能都是基础循环的技能就对到基础循环那行」）；
                -- 否则按第一个非主循环技能的职能；都没有就功能
                local role, allCore = nil, (m.spells and #m.spells > 0) or false
                for _, sid in ipairs(m.spells or {}) do
                    local r = spellRole[sid] or roles[sid]
                    if r ~= "core" then allCore = false; if not role then role = r end end
                end
                if allCore then role = "core" elseif not role then role = "util" end
                items[#items + 1] = { macro = m.key, lib = m, macroName = GearInsight.LibMacroName(m), macroIcon = "INV_Misc_QuestionMark",
                                      macroBody = body, missing = missing, role = role, why = "宏库", sep2 = true }
            end
        end
    end
    -- 饰品 / 坐骑
    local function usableInv(inv)
        local link = GetInventoryItemLink("player", inv)
        if not link then return false end
        local getSpell = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell
        return getSpell and getSpell(link) ~= nil
    end
    -- 饰品按「使用：」效果分析后并进爆发 / 减伤保命 / 治疗那一行，行内空一格隔开（用户「饰品和爆发或保命放到一列，但是间隔两部分」）
    local function invRole(inv)
        local link = GetInventoryItemLink("player", inv)
        local getSpell = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell
        local _, spellID = getSpell and getSpell(link)
        local desc = (spellID and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID)) or ""
        local dl = desc:lower()
        if desc:find("所受", 1, true) or desc:find("吸收", 1, true) or desc:find("护盾", 1, true) or desc:find("减少", 1, true) or dl:find("damage taken", 1, true) or dl:find("absorb", 1, true) or dl:find("shield", 1, true) then return "def", "饰品·减伤" end
        if (desc:find("治疗", 1, true) or dl:find("heal", 1, true)) and not desc:find("伤害", 1, true) and not dl:find("damage", 1, true) then return "heal", "饰品·治疗" end
        return "burst", "饰品·爆发"
    end
    for _, inv in ipairs({ 13, 14 }) do
        if usableInv(inv) then
            local role, why = invRole(inv)
            items[#items + 1] = { inv = inv, role = role, why = why, sep = true }
        end
    end
    -- 推荐药水（core/PotionReco.lua ← WCL 顶尖玩家实际施放）：爆发药水进「爆发」行、生命药水进「减伤保命」行，饰品后面（用户 2026-09-18）
    local PR = _G.GearInsightPotionReco and key and _G.GearInsightPotionReco[key]
    if PR then
        local function pickId(ids)
            for _, id in ipairs(ids) do if (C_Item.GetItemCount and C_Item.GetItemCount(id) or GetItemCount(id) or 0) > 0 then return id, true end end
            return ids[1], false
        end
        if PR.burst then
            local id, have = pickId(PR.burst.ids)
            items[#items + 1] = { item = id, ids = PR.burst.ids, have = have, role = "burst", why = string.format(T("LY_WHY_POTION", "药水 · 顶尖玩家 %d%% 用 %s"), PR.burst.pct, PR.burst.cn), sep = true, cn = PR.burst.cn }
        end
        if PR.heal then
            local id, have = pickId(PR.heal.ids)
            items[#items + 1] = { item = id, ids = PR.heal.ids, have = have, role = "def", why = string.format(T("LY_WHY_POTION", "药水 · 顶尖玩家 %d%% 用 %s"), PR.heal.pct, PR.heal.cn), sep = true, cn = PR.heal.cn }
        end
    end
    items[#items + 1] = { id = 150544, role = "inv", why = "坐骑" }

    -- 分组 + 连续分配 60 格
    for i, it in ipairs(items) do it._ord = i end
    local groups, byRole = {}, {}
    for _, r in ipairs(ROLE_ORDER) do local g = { key = r[1], label = r[2], desc = r[3], items = {} }; groups[#groups + 1] = g; byRole[r[1]] = g end
    for _, it in ipairs(items) do
        if it.role == "taunt" then it.role = "interrupt"; it.sep = true; it.why = "嘲讽" end   -- 嘲讽和打断一行，空一格隔开（用户 2026-09-18）
        if it.role == "aoecc" then it.role = "cc"; it.why = "群控"; it._ord = it._ord - 10000 end   -- 群控排单控前面
        if it.role == "stcc" then it.role = "cc"; it.why = "单控" end
        if it.role == "ccbreak" then it.role = "cc"; it.sep = true; it.why = "解控" end
        -- 带持续时间的召唤（亡者复生「持续 1 分钟」、军队、图腾这种）是爆发 CD，不是常驻宠物（用户 2026-09-18）
        if it.role == "summon" and it.id then
            local desc = (C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(it.id)) or ""
            local cd = GetSpellBaseCooldown and GetSpellBaseCooldown(it.id) or 0
            if desc:find("持续", 1, true) or desc:lower():find(" for %d+ ") or desc:lower():find(" sec") or (cd and cd >= 45000) then
                it.role = "burst"; it.why = (it.why or "") .. T("LY_WHY_SUMMON_SFX", " · 召唤")
            end
        end
        local g = byRole[it.role] or byRole.dps; g.items[#g.items + 1] = it
    end
    -- 带 sep 的排到行尾（饰品 / 嘲讽在各自行的后半段）
    for _, g in ipairs(groups) do
        table.sort(g.items, function(a, b)
            local sa, sb = (a.sep2 and 2) or (a.sep and 1) or 0, (b.sep2 and 2) or (b.sep and 1) or 0
            if sa ~= sb then return sa < sb end
            return (a._ord or 0) < (b._ord or 0)
        end)
    end
    local allSlots = {}
    for _, bar in ipairs(BARS) do for sl = bar.from, bar.to do allSlots[#allSlots + 1] = sl end end
    local slots, k, dropped = {}, 1, 0
    for _, g in ipairs(groups) do
        g.on = GearInsight.GroupOn(g.key)
        for _, it in ipairs(g.items) do
            if not g.on and not it.macro and not it.inv and not it.item then it.slot = nil; it.off = true   -- 整行折叠：不占格（宏 / 饰品 / 药水照放）
            elseif allSlots[k] then it.slot = allSlots[k]; k = k + 1; slots[#slots + 1] = it
            else it.slot = nil; dropped = dropped + 1 end
        end
    end
    for _, g in ipairs(groups) do
        for _, it in ipairs(g.items) do if it.macro and not it.lib then it.groupItems = g.items end end   -- 只有分组宏（爆发/保命）才挂整行；宏库的宏用自己的正文
        -- 进了宏的技能/饰品/药水，键位排最后分（用户「爆发宏中的技能和物品不占主要按钮，用次要的按钮，最后分」）
        if GROUP_MACRO_KEYS[g.key] then for _, it in ipairs(g.items) do if not it.macro then it.inMacro = true end end end
    end
    GearInsight._smartKeys = GearInsight.SmartKeys(slots)
    local nCore = #(byRole.core.items)
    return slots, { core = nCore, total = #items, dropped = dropped, key = key, notes = notes, groups = groups }
end

-- mode = "fill"（只填空位）| "rebuild"（清空重铺）
function GearInsight:ApplyLayout(mode)
    if InCombatLockdown() then self:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
    local slots = self:BuildLayoutPlan()
    -- 已在条上的技能：同时记原 id / 基础 id / 名字，覆盖技能（心脏打击→吸血鬼之击）放上去后 GetActionInfo 回的是另一个 id，
    -- 只按 id 比会次次都当成「缺」再放一遍（用户「只填空位点一次加一个」）
    local onBar = {}
    for i = 1, MAX_SLOT do
        local r = slotInfo(i)
        if r and r.t == "spell" and r.id then
            onBar[r.id] = i
            local base = FindBaseSpellByID and FindBaseSpellByID(r.id); if base then onBar[base] = i end
            local info = C_Spell.GetSpellInfo(r.id); if info and info.name then onBar[info.name] = i end
        end
    end
    local function isOnBar(id)
        if onBar[id] then return true end
        local base = FindBaseSpellByID and FindBaseSpellByID(id); if base and onBar[base] then return true end
        local info = C_Spell.GetSpellInfo(id); return info and info.name and onBar[info.name] or false
    end
    local placed, kept = 0, 0
    if mode == "rebuild" then
        for _, bar in ipairs(BARS) do for s = bar.from, bar.to do PickupAction(s); ClearCursor() end end
        onBar = {}
        local noPotion = {}
        for _, p in ipairs(slots) do
            ClearCursor()
            if p.inv then PickupInventoryItem(p.inv)
            elseif p.item then if p.have then PickupItem(p.item) else noPotion[#noPotion + 1] = p.cn or tostring(p.item) end
            elseif p.macro then local mi = self:EnsureMacroItem(p); if mi then PickupMacro(mi) end
            elseif p.id == 150544 and C_MountJournal and C_MountJournal.Pickup then C_MountJournal.Pickup(0)   -- 随机偏好坐骑：PickupSpell 拾不起来（用户「这个按钮没有设置到动作条」）
            else PickupSpell(p.id) end
            if GetCursorInfo() then PlaceAction(p.slot); placed = placed + 1 end
            ClearCursor()
        end
        if #noPotion > 0 then self:Print(T("LY_NO_POTION", "包里没有推荐药水，这几格先空着：") .. table.concat(noPotion, "、")) end
    else
        -- 只填空位：已经在任何条上的技能不动；缺的按计划顺序放进管的空格里
        local empties = {}
        for _, bar in ipairs(BARS) do for s = bar.from, bar.to do if not slotInfo(s) then empties[#empties + 1] = s end end end
        local e = 1
        for _, p in ipairs(slots) do
            if p.id and isOnBar(p.id) then kept = kept + 1
            elseif p.inv or p.item or p.macro then -- 饰品 / 药水 / 宏只在重铺时放
            elseif empties[e] then
                ClearCursor(); PickupSpell(p.id)
                if GetCursorInfo() then PlaceAction(empties[e]); placed = placed + 1; e = e + 1 end
                ClearCursor()
            end
        end
    end
    self:Print(string.format(T("LY_DONE", "键位已铺：新放 %d 格，保留 %d 个原位技能（%s）"), placed, kept,
        mode == "rebuild" and T("LY_MODE_RB", "清空重铺") or T("LY_MODE_FILL", "只填空位")))
    if self._layoutRefresh then self._layoutRefresh() end
end

-- 铺之前问一句（用户「切换前问一下是否保存当前键位」）
StaticPopupDialogs["GEARINSIGHT_LAYOUT_CONFIRM"] = {
    text = "%s",
    button1 = OKAY, button2 = CANCEL,
    OnAccept = function(_, data) GearInsight:SaveLayoutBackup(data.reason, true); GearInsight:ApplyLayout(data.mode) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
-- 一键清理备份（用户 2026-09-18）：确认框；备份本身最多 10 份，满了自动挤掉最老的（SaveLayoutBackup 里已做）
StaticPopupDialogs["GEARINSIGHT_LAYOUT_CLEAR"] = {
    text = "%s",
    button1 = T("LY_BTN_CLEAR_ALL", "全部清掉"), button2 = CANCEL,
    OnAccept = function()
        GearInsightDB = GearInsightDB or {}
        local keep, n = {}, 0
        for _, sn in ipairs(GearInsightDB.layoutBackups or {}) do if sn.pinned then keep[#keep + 1] = sn else n = n + 1 end end
        GearInsightDB.layoutBackups = keep
        GearInsight:Print(string.format(T("LY_CLEARED", "已清掉 %d 份键位备份（永久保存的 %d 份留着）"), n, #keep))
        if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
-- 永久备份改名
StaticPopupDialogs["GEARINSIGHT_LAYOUT_RENAME"] = {
    text = "%s", button1 = OKAY, button2 = CANCEL, hasEditBox = true, maxLetters = 40,
    OnShow = function(self, data) self.editBox:SetText(data and data.snap and data.snap.title or ""); self.editBox:HighlightText() end,
    OnAccept = function(self, data)
        local t = self.editBox:GetText():gsub("^%s+", ""):gsub("%s+$", "")
        if data and data.snap then data.snap.title = (t ~= "") and t or nil end
        if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
    end,
    EditBoxOnEnterPressed = function(self) local p = self:GetParent(); p.button1:Click() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
-- 一键清宏：只删名字以 GI 打头的宏（用户 2026-09-18）；从后往前删，索引不会错位
StaticPopupDialogs["GEARINSIGHT_MACRO_CLEAR"] = {
    text = "%s",
    button1 = T("LY_BTN_DEL_ALL", "全部删掉"), button2 = CANCEL,
    OnAccept = function()
        if InCombatLockdown() then GearInsight:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
        local nGlobal, nChar = GetNumMacros()
        local total = (MAX_ACCOUNT_MACROS or 120) + (nChar or 0)
        local n = 0
        for i = total, 1, -1 do
            local name = GetMacroInfo(i)
            if name and (name:sub(1, 2) == "GI" or name == "placeholder") then DeleteMacro(i); n = n + 1 end
        end
        GearInsight:Print(string.format(T("LY_MACRO_CLEARED", "已删掉 %d 个 GI 打头的宏"), n))
        if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
function GearInsight:CountGiMacros()
    local _, nChar = GetNumMacros()
    local total, n = (MAX_ACCOUNT_MACROS or 120) + (nChar or 0), 0
    for i = 1, total do local name = GetMacroInfo(i); if name and (name:sub(1, 2) == "GI" or name == "placeholder") then n = n + 1 end end
    return n
end
StaticPopupDialogs["GEARINSIGHT_KEYS_CONFIRM"] = {
    text = T("LY_ASK_KEYS", "要按右边的推荐键位重设主条 + 条2~条5 共 60 格的按键绑定，之前占用同一个键的功能会被挪走。\n（做之前会自动备份一份，含绑定，可一键还原）"),
    button1 = OKAY, button2 = CANCEL,
    OnAccept = function() GearInsight:SaveLayoutBackup(T("LY_R_KEYS", "设置绑定前"), true); GearInsight:ApplyKeyBindings() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
function GearInsight:SaveLayoutBackup(reason, silent)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.layoutBackups = GearInsightDB.layoutBackups or {}
    local L = GearInsightDB.layoutBackups
    local snap = self:SnapshotBars(reason)
    if L[1] and L[1].sig == snap.sig then
        if not silent then self:Print(T("LY_SAME", "和上一份备份一模一样，没重复存")) end
        return L[1]
    end
    table.insert(L, 1, snap)
    self.TrimBackups(L)
    if not silent then self:Print(string.format(T("LY_SAVED", "键位已保存：%s"), self.BackupTitle(snap)))
    else self:Print(string.format(T("LY_AUTOSAVED", "已自动备份：%s（「保存」页可还原）"), self.BackupTitle(snap))) end
    if self._layoutRefresh then self._layoutRefresh() end
    return snap
end
function GearInsight:AskApplyLayout(mode)
    if InCombatLockdown() then self:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
    if mode == "rebuild" then
        StaticPopup_Show("GEARINSIGHT_LAYOUT_CONFIRM",
            T("LY_ASK_RB", "要清空主条 + 条2~条5 共 60 格，按 WCL 顶尖玩家的按键重铺。\n（做之前会自动备份一份，可一键还原）"), nil,
            { mode = mode, reason = T("LY_R_RB", "清空重铺前") })
    else
        self:SaveLayoutBackup(T("LY_R_FILL", "只填空位前"), true)
        self:ApplyLayout(mode)
    end
end

-- ── 施放排名窗口（用户「把技能施放排名也放一下，单独搞个按钮点出一个窗口」）──
--   数据 = core/RotationData.lua 的 raid.core / mplus.core（WCL 顶尖玩家每分钟施放次数），团本 / 大米两列并排，条形按最大值相对刻度
function GearInsight:ToggleCastRankWindow()
    local f = self._castRankFrame
    if f and f:IsShown() then f:Hide(); return end
    local COLW, ROWH, NROW = 330, 26, 16
    if not f then
        f = CreateFrame("Frame", "GearInsightCastRank", UIParent, "BackdropTemplate")
        f:SetSize(COLW * 2 + 48, 120 + NROW * ROWH); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        f:SetBackdropColor(0.05, 0.05, 0.08, 0.97); f:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetClampedToScreen(true)
        tinsert(UISpecialFrames, "GearInsightCastRank")
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 18, -14)
        f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f.sub:SetPoint("TOPLEFT", 18, -38); f.sub:SetPoint("RIGHT", -40, 0); f.sub:SetJustifyH("LEFT"); f.sub:SetWordWrap(false)
        local x = CreateFrame("Button", nil, f, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", -4, -4)
        -- 分隔线
        local sep = f:CreateTexture(nil, "ARTWORK"); sep:SetPoint("TOPLEFT", 18, -56); sep:SetPoint("TOPRIGHT", -18, -56); sep:SetHeight(1); sep:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
        local vsep = f:CreateTexture(nil, "ARTWORK"); vsep:SetPoint("TOP", f, "TOPLEFT", 18 + COLW + 6, -64); vsep:SetPoint("BOTTOM", f, "BOTTOMLEFT", 18 + COLW + 6, 30); vsep:SetWidth(1); vsep:SetColorTexture(1, 1, 1, 0.08)
        f.legend = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f.legend:SetPoint("BOTTOMLEFT", 18, 12); f.legend:SetPoint("RIGHT", -18, 0); f.legend:SetJustifyH("LEFT")
        f.legend:SetText(T("LY_RANK_LEGEND", "|cffff6060红字|r = 这个技能现在不在你的动作条上 · 条形按各列最大值相对刻度 · 悬停看技能说明"))
        f.cols = {}
        for i, key in ipairs({ "raid", "mplus" }) do
            local col = CreateFrame("Frame", nil, f)
            col:SetPoint("TOPLEFT", 18 + (i - 1) * (COLW + 12), -64); col:SetSize(COLW, NROW * ROWH + 24)
            col.hd = col:CreateFontString(nil, "OVERLAY", "GameFontNormal"); col.hd:SetPoint("TOPLEFT", 0, 0); col.hd:SetPoint("RIGHT", 0, 0); col.hd:SetJustifyH("LEFT"); col.hd:SetWordWrap(false)
            col.rows = {}
            for r = 1, NROW do
                local row = CreateFrame("Frame", nil, col)
                row:SetSize(COLW, ROWH); row:SetPoint("TOPLEFT", 0, -22 - (r - 1) * ROWH)
                if r % 2 == 0 then local z = row:CreateTexture(nil, "BACKGROUND"); z:SetAllPoints(); z:SetColorTexture(1, 1, 1, 0.03) end
                row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.rank:SetPoint("LEFT", 2, 0); row.rank:SetWidth(20); row.rank:SetJustifyH("RIGHT")
                row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(22, 22); row.icon:SetPoint("LEFT", 28, 0); row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.name:SetPoint("LEFT", 56, 0); row.name:SetWidth(110); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
                row.barBg = row:CreateTexture(nil, "BORDER"); row.barBg:SetPoint("LEFT", 170, 0); row.barBg:SetSize(110, 14); row.barBg:SetColorTexture(1, 1, 1, 0.06)
                row.bar = row:CreateTexture(nil, "ARTWORK"); row.bar:SetPoint("LEFT", 170, 0); row.bar:SetSize(1, 14)
                row.val = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.val:SetPoint("LEFT", 286, 0); row.val:SetWidth(42); row.val:SetJustifyH("RIGHT")
                row:EnableMouse(true)
                row:SetScript("OnEnter", function(self) if self._id then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(self._id); GameTooltip:Show() end end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                col.rows[r] = row
            end
            f.cols[key] = col
        end
        self._castRankFrame = f
    end
    local key, R = specKey()
    local specIdx = GetSpecialization and GetSpecialization()
    local specName = specIdx and select(2, GetSpecializationInfo(specIdx)) or "?"
    f.title:SetText(string.format("%s  |cffffd100%s|r", T("LY_RANK_TITLE", "技能施放排名 · WCL 顶尖玩家"), specName))
    f.sub:SetText(T("LY_RANK_SUB", "每分钟施放次数（cpm）· 团本 = 本周 M 首领前五玩家 · 大米 = 冲分各本前二聚合"))
    -- 条上有什么：原 id / 基础 id / 覆盖 id 全记（吸血鬼打击是心脏打击的覆盖形态，条上放的是心脏打击）
    local onBar = {}
    for i = 1, MAX_SLOT do
        local si = slotInfo(i)
        if si and si.t == "spell" and si.id then
            onBar[si.id] = true
            local base = FindBaseSpellByID and FindBaseSpellByID(si.id); if base then onBar[base] = true end
            local ov = FindSpellOverrideByID and FindSpellOverrideByID(si.id); if ov then onBar[ov] = true end
        end
    end
    local function has(id)
        if onBar[id] then return true end
        local base = FindBaseSpellByID and FindBaseSpellByID(id); if base and onBar[base] then return true end
        local ov = FindSpellOverrideByID and FindSpellOverrideByID(id); if ov and onBar[ov] then return true end
        return false
    end
    for _, ck in ipairs({ "raid", "mplus" }) do
        local col = f.cols[ck]
        local blk = R and R[ck]
        local rows = (blk and blk.core) or {}
        local hd = ck == "raid" and T("LY_RANK_RAID", "团本") or T("LY_RANK_MPLUS", "大米")
        if blk then
            local extra = blk.encCn and (blk.encCn .. (blk.mNum and (" M" .. blk.mNum) or "")) or (blk.dur and (T("LY_RANK_DUR", "中位 ") .. math.floor(blk.dur / 60) .. T("LY_MIN_UNIT", " 分")) or "")
            hd = string.format("|cffffd100%s|r  |cff888888%d %s · %s|r", hd, blk.n or 0, T("LY_RANK_SAMPLES", "个样本"), extra)
        end
        col.hd:SetText(hd)
        local maxV = 0
        for _, c in ipairs(rows) do if c[2] > maxV then maxV = c[2] end end
        for r = 1, NROW do
            local row, c = col.rows[r], rows[r]
            if c then
                local info = C_Spell.GetSpellInfo(c[1])
                row._id = c[1]
                row.rank:SetText(r); row.rank:SetTextColor(r <= 3 and 1 or 0.6, r <= 3 and 0.82 or 0.6, r <= 3 and 0 or 0.6)
                row.icon:SetTexture(info and info.iconID); row.name:SetText(info and info.name or c[1])
                local frac = c[2] / math.max(maxV, 0.01)
                row.bar:SetWidth(math.max(2, 110 * frac)); row.bar:SetColorTexture(1, 0.82 - 0.5 * (1 - frac), 0.15 * (1 - frac), 0.9)
                row.val:SetText(string.format("%.1f", c[2]))
                if has(c[1]) then row.name:SetTextColor(1, 1, 1) else row.name:SetTextColor(1, 0.4, 0.4) end
                row:Show()
            else
                row._id = nil; row:Hide()
            end
        end
        if #rows == 0 then col.hd:SetText(hd .. "  |cff888888" .. T("LY_RANK_NONE", "暂无数据") .. "|r") end
    end
    f:Show()
end

-- ── 分组宏（用户「AI 成宏，爆发就有爆发宏；左键绑定按钮，右键打开宏编辑」）──
--   普通暴雪宏（不是 GSE）：#showtooltip + 饰品 /use 13/14 + 药水 /use item:ID + 该行技能逐行 /cast。
--   多行 /cast 一次按键只会放出第一个能放的 GCD 技能 + 所有不占 GCD 的，这正是「一键爆发」的标准写法。宏正文上限 255 字。

-- ── 宏库：勾选状态按专精存；body 里 {{id}} 填成客户端语言的技能名；缺的技能列出来 ──
-- 宏库 = 插件自带（/gi 面板宏、爆发宏、保命宏）+ 站点各专精宏。自带三条默认选中，可取消（用户 2026-09-18）
local GI_MACROS = {
    { key = "gi#open",  gi = true, name = "GearInsight", nameCn = "打开 GearInsight 面板", note = "Open the GearInsight panel (/gi)", noteCn = "一键打开插件主面板（/gi）", body = "/gi", spells = {}, defaultOn = false },   -- 可选，默认不勾（用户 2026-09-18）
    { key = "gi#burst", gi = true, group = "burst", name = "GI Burst", nameCn = "GI 智能爆发宏", note = "Burst-row spells + on-use trinkets + burst potion in one macro; off-GCD first, targeted last", noteCn = "爆发行技能 + 主动饰品 + 爆发药水合成一键宏，不占 GCD 的先放、要目标的最后", spells = {},
      defaultOn = function() return GetSpecializationRole and GetSpecializationRole(GetSpecialization() or 0) == "DAMAGER" end },   -- DPS 默认勾
    { key = "gi#def",   gi = true, group = "def",   name = "GI Defensive", nameCn = "GI 智能保命宏", note = "Defensive-row spells + defensive trinket + healing potion in one macro", noteCn = "减伤保命行技能 + 减伤饰品 + 生命药水合成一键宏", spells = {},
      defaultOn = function() return GetSpecializationRole and GetSpecializationRole(GetSpecialization() or 0) == "TANK" end },      -- 坦克默认勾；治疗两个都不勾
}
function GearInsight.MacroLibFor(key)
    local out = {}
    for _, m in ipairs(GI_MACROS) do out[#out + 1] = m end
    for _, m in ipairs((_G.GearInsightMacroLib and key and _G.GearInsightMacroLib[key]) or {}) do out[#out + 1] = m end
    return out
end
local function libDefaultOn(m)
    local d = m.defaultOn
    if type(d) == "function" then return d() and true or false end
    return d and true or false
end
function GearInsight.LibSelected(st, m)
    local v = st[m.key]
    if v == nil then return libDefaultOn(m) end   -- 没碰过：按默认（自带的按职能）
    return v and true or false
end
function GearInsight.LibStore()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.layoutLib = GearInsightDB.layoutLib or {}
    local idx = GetSpecialization and GetSpecialization()
    local specID = (idx and GetSpecializationInfo(idx)) or 0
    GearInsightDB.layoutLib[specID] = GearInsightDB.layoutLib[specID] or {}
    return GearInsightDB.layoutLib[specID]
end
-- {{id}} → 本地化技能名；只有 /cast /use /castsequence 行里的技能才算「要会」，/cancelaura 之类的不算缺（用户截图：保护祝福被判缺）
local function fillIds(t) return (t or ""):gsub("{{(%d+)}}", function(idStr) local info = C_Spell.GetSpellInfo(tonumber(idStr)); return info and info.name or ("spell:" .. idStr) end) end
GearInsight.FillSpellIds = fillIds
function GearInsight.LocalizeMacroBody(m)
    local missing, seen = {}, {}
    for line in (m.body or ""):gmatch("[^\n]+") do
        local cmd = line:match("^/(%S+)")
        if cmd == "cast" or cmd == "use" or cmd == "castsequence" or cmd == "castrandom" then
            for idStr in line:gmatch("{{(%d+)}}") do
                local id = tonumber(idStr)
                if not seen[id] then
                    seen[id] = true
                    if not (IsPlayerSpell(id) or (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id))) then
                        local info = C_Spell.GetSpellInfo(id); missing[#missing + 1] = info and info.name or idStr
                    end
                end
            end
        end
    end
    return fillIds(m.body), missing
end
-- 宏名：⛔ CreateMacro 的名字上限是 16 **字节**（中文 3 字节/字），超了游戏会建成「placeholder」而且每次都新建一个
--   （用户截图一排 placeholder）。所以：「GI」+ 技能名前 4 个字（≤14 字节）；同技能多条宏时末尾加数字区分。
local function utf8Trunc(str, maxBytes)
    local out, n = {}, 0
    for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if n + #ch > maxBytes then break end
        out[#out + 1] = ch; n = n + #ch
    end
    return table.concat(out)
end
local libNameCache = {}
function GearInsight.LibMacroName(m)
    if libNameCache[m.key] then return libNameCache[m.key] end
    local first = m.spells and m.spells[1]
    local info = first and C_Spell.GetSpellInfo(first)
    local sp = info and info.name or GearInsight.FillSpellIds(libName(m))
    sp = sp:gsub("[%s%p]", "")
    local base = "GI" .. utf8Trunc(sp, 14)
    -- 同名去重：同一个技能的第 2、3 条宏加数字（占 1 字节，技能名再让 1 个字）
    local used = {}
    for k, v in pairs(libNameCache) do if k ~= m.key then used[v] = true end end
    local name = base
    local i = 2
    while used[name] do name = "GI" .. utf8Trunc(sp, 13) .. i; i = i + 1 end
    libNameCache[m.key] = name
    return name
end
-- 宏格通用：正文来源（分组宏 = 动态算；宏库 = 已本地化的正文）
local function macroBodyOf(it)
    if it.lib then return it.macroBody or "" end
    if it.groupItems then return GearInsight:BuildGroupMacro(it.macro, it.groupItems) end
    return it.macroBody or ""
end
-- 宏库条目名/说明：简中客户端用 nameCn/noteCn，其他语言用 name/note（宏库数据自带双语）
function libName(m) if _LOCALE == "zhCN" then return (m.nameCn ~= "" and m.nameCn) or m.name or T("LY_MACRO_WORD", "宏") end return (m.name and m.name ~= "" and m.name) or m.nameCn or T("LY_MACRO_WORD", "宏") end
local function libNote(m) if _LOCALE == "zhCN" then return (m.noteCn ~= "" and m.noteCn) or m.note or "" end return (m.note and m.note ~= "" and m.note) or m.noteCn or "" end
macroNameOf = function(it) return it.macroName or (GROUP_MACRO[it.macro] and GROUP_MACRO[it.macro].name) or "GI宏" end
local function macroIconOf(it) return it.macroIcon or (GROUP_MACRO[it.macro] and GROUP_MACRO[it.macro].icon) or "INV_Misc_QuestionMark" end
function GearInsight:EnsureMacroItem(it, regen)
    if InCombatLockdown() then self:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
    local name, icon, body = macroNameOf(it), macroIconOf(it), macroBodyOf(it)
    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then
        -- 已经有同名宏：不动（玩家可能在编辑器里改过）；Shift+右键 = 按最新计划重新生成
        if regen then EditMacro(idx, name, icon, body) end
    else
        local nGlobal, nChar = GetNumMacros()
        local perChar = (nChar or 0) < 18
        if not perChar and (nGlobal or 0) >= 120 then self:Print(T("LY_MACRO_FULL", "宏栏满了（角色 18 / 通用 120），删几个再来")); return end
        idx = CreateMacro(name, icon, body, perChar)
        if idx and it.gi then
            local _, tex = GetMacroInfo(idx)
            if not tex or tex == 134400 or tostring(tex):find("QuestionMark") then EditMacro(idx, name, "INV_Misc_Gear_01", body) end
        end
    end
    return idx, body
end
function GearInsight:BuildGroupMacro(groupKey, items)
    local lines = { "#showtooltip" }
    if groupKey == "burst" then lines[#lines + 1] = "/startattack" end
    for _, it in ipairs(items) do
        if it.inv then lines[#lines + 1] = "/use " .. it.inv end
    end
    for _, it in ipairs(items) do
        -- 药水用名字（用户「ITEM ID 换成名字」）；名字还没缓存到时退回 item:ID
        if it.item and it.have then
            local nm = C_Item.GetItemNameByID and C_Item.GetItemNameByID(it.item)
            lines[#lines + 1] = "/use " .. (nm or ("item:" .. it.item))
        end
    end
    -- 暴雪宏规则：一次按键只放出**第一个能放的占 GCD 技能**，后面占 GCD 的全部忽略；不占 GCD 的每次都放。
    --   所以不占 GCD 的排前面（每次都出），占 GCD 的排后面按优先级——按一次放一个，连按几下全放完（用户「为啥有一些技能没放出来」）。
    --   再按「要不要选中目标」分：自身技能在前，要目标的排最后（用户「智能把需要选中目标施放的排最后」）——有射程 = 要目标
    local buckets = { {}, {}, {}, {} }   -- 1 自身·不占GCD  2 自身·占GCD  3 目标·不占GCD  4 目标·占GCD
    for _, it in ipairs(items) do
        if it.id then
            local info = C_Spell.GetSpellInfo(it.id)
            if info and info.name then
                local _, gcd = GetSpellBaseCooldown(it.id)
                local hasRange = (C_Spell.SpellHasRange and C_Spell.SpellHasRange(it.id)) or (SpellHasRange and SpellHasRange(it.id)) or false
                local b = (hasRange and 2 or 0) + ((gcd and gcd == 0) and 1 or 2)
                buckets[b][#buckets[b] + 1] = info.name
            end
        end
    end
    for _, bk in ipairs(buckets) do for _, n in ipairs(bk) do lines[#lines + 1] = "/cast " .. n end end
    local body = table.concat(lines, "\n")
    while #body > 255 and #lines > 2 do table.remove(lines); body = table.concat(lines, "\n") end
    return body
end
function GearInsight:EnsureGroupMacro(groupKey, items)
    if InCombatLockdown() then self:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
    local meta = GROUP_MACRO[groupKey]; if not meta then return end
    local body = self:BuildGroupMacro(groupKey, items)
    local idx = GetMacroIndexByName(meta.name)
    if idx and idx > 0 then
        EditMacro(idx, meta.name, meta.icon, body)
    else
        local nGlobal, nChar = GetNumMacros()
        local perChar = (nChar or 0) < 18
        if not perChar and (nGlobal or 0) >= 120 then self:Print(T("LY_MACRO_FULL", "宏栏满了（角色 18 / 通用 120），删几个再来")); return end
        idx = CreateMacro(meta.name, meta.icon, body, perChar)
    end
    return idx, body
end
function GearInsight:OpenMacroEditor(name)
    if not MacroFrame then pcall(C_AddOns.LoadAddOn, "Blizzard_MacroUI") end
    if not MacroFrame then return end
    ShowUIPanel(MacroFrame)
    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then
        -- 角色宏在第二页；先切页再选
        local nGlobal = GetNumMacros()
        local tab = idx > (MAX_ACCOUNT_MACROS or 120) and 2 or 1
        if MacroFrame.SetTab then pcall(MacroFrame.SetTab, MacroFrame, tab) elseif MacroFrameTab1 then pcall(PanelTemplates_SetTab, MacroFrame, tab) end
        if MacroFrame.SelectMacro then pcall(MacroFrame.SelectMacro, MacroFrame, idx)
        elseif MacroFrame_SelectMacro then pcall(MacroFrame_SelectMacro, idx) end
    end
end

-- ── 页面：两种模式（用户「键位分为保存和替换两种模式」）───────────────────────
--   保存：把现在的动作条存一份（最多 5 份）/ 还原 / 导出 MySlot 串
--   替换：按 WCL 顶尖玩家按键铺动作条（只填空位 / 清空重铺），右侧计划预览
function GearInsight:BuildLayoutPage(pg)
    if pg._built then if self._layoutRefresh then self._layoutRefresh() end; return end
    pg._built = true
    self.EnsureKeySnapshot()   -- 第一次打开这页就记一份用户个性化键位
    local function btn(parent, text, w, x, y, onClick)
        local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        b:SetSize(w, 30); b:SetPoint("TOPLEFT", x, y); b:SetText(text); b:SetScript("OnClick", onClick)
        b:SetNormalFontObject("GameFontNormal"); b:SetHighlightFontObject("GameFontHighlight")
        return b
    end
    -- 模式切换
    local modeBtns = {}
    local views = {}
    local function showMode(m)
        GearInsightDB = GearInsightDB or {}; GearInsightDB.layoutMode = m
        for k, v in pairs(views) do v:SetShown(k == m) end
        for k, b in pairs(modeBtns) do
            if k == m then b:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9); b.fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else b:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.8); b.fs:SetTextColor(0.75, 0.75, 0.75) end
        end
        if self._layoutRefresh then self._layoutRefresh() end
    end
    local x = 14
    for _, m in ipairs({ { "save", T("LY_MODE_SAVE", "保存") }, { "replace", T("LY_MODE_REPLACE", "替换") } }) do
        local b = CreateFrame("Button", nil, pg, "BackdropTemplate")
        b:SetSize(120, 26); b:SetPoint("TOPLEFT", x, -34)
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        b:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.fs:SetPoint("CENTER"); b.fs:SetText(m[2])
        b:SetScript("OnClick", function() showMode(m[1]) end)
        modeBtns[m[1]] = b; x = x + 126
    end

    -- ── 保存 视图 ──
    local vs = CreateFrame("Frame", nil, pg); vs:SetPoint("TOPLEFT", 0, -66); vs:SetPoint("BOTTOMRIGHT"); views.save = vs
    local ss = vs:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ss:SetPoint("TOPLEFT", 14, -4); ss:SetPoint("RIGHT", -14, 0); ss:SetJustifyH("LEFT")
    ss:SetText(T("LY_SAVE_SUB", "把现在 180 格动作条 + 全部按键绑定存一份（轮换最多 10 份，满了自动挤掉最老的；铺格子 / 设置绑定 / 还原之前也会自动存），随时一键还原。点行首 ★ 标为永久保存（最多 6 份，不进轮换、不被清理、可点名字改名）；也可导出成 MySlot 串。"))
    btn(vs, T("LY_BTN_SAVE", "保存当前键位"), 150, 14, -48, function() GearInsight:SaveLayoutBackup(T("LY_R_MANUAL", "手动保存")) end)
    btn(vs, T("LY_BTN_MS", "导出 MySlot 串"), 150, 170, -48, function()
        local ok, str = pcall(GearInsight.MySlotString, GearInsight, GearInsight:SnapshotBars())
        if not ok then GearInsight:Print("|cffff4040" .. T("LY_MS_FAIL", "MySlot 串生成失败：") .. "|r" .. tostring(str)); return end
        GearInsight:ShowCopyText(str, T("LY_MS_HINT", "Ctrl+C 复制 > 打开 MySlot > 粘贴 > 导入"), "MySlot", nil, nil, {
            label = T("LY_MS_OPEN", "打开 MySlot"),
            onClick = function()
                local ok = false
                if SlashCmdList and SlashCmdList["MYSLOT"] then ok = pcall(SlashCmdList["MYSLOT"], "") end
                if not ok then GearInsight:Print(T("LY_MS_NOADDON", "没装 MySlot 插件（或没启用）：串已在上面，装好后 /myslot 粘贴导入")) end
            end,
        })
    end)
    btn(vs, T("LY_BTN_CLEAR", "一键清理备份"), 150, 326, -48, function()
        local n = GearInsightDB and GearInsightDB.layoutBackups and #GearInsightDB.layoutBackups or 0
        if n == 0 then GearInsight:Print(T("LY_BK_NONE", "还没有备份")); return end
        StaticPopup_Show("GEARINSIGHT_LAYOUT_CLEAR", string.format(T("LY_CLEAR_ASK", "要把 %d 份键位备份全部删掉吗？删了就找不回来了。"), n))
    end)
    local bkHd = vs:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bkHd:SetPoint("TOPLEFT", 14, -92); bkHd:SetText(T("LY_BK_HD", "已保存的键位"))
    local bkRows = {}
    local ROWS = MAX_ROTATE + MAX_PINNED
    local function rowSnap(i) local o = GearInsight.OrderedBackups()[i]; return o and o.snap, o and o.idx end
    for i = 1, ROWS do
        local y = -114 - (i - 1) * 30
        -- 左侧 ★：永久保存开关（金 = 永久，灰 = 轮换）
        local star = CreateFrame("Button", nil, vs); star:SetSize(22, 22); star:SetPoint("TOPLEFT", 12, y - 4)
        star.tex = star:CreateTexture(nil, "ARTWORK"); star.tex:SetAllPoints(); star.tex:SetAtlas("auctionhouse-icon-favorite")
        star:SetScript("OnClick", function()
            local sn = rowSnap(i); if not sn then return end
            if sn.pinned then sn.pinned = nil; GearInsight.TrimBackups(GearInsightDB.layoutBackups)
            else
                local n, mx = GearInsight.CountPinned()
                if n >= mx then GearInsight:Print(string.format(T("LY_PIN_FULL", "永久保存最多 %d 份，先取消一份再标"), mx)); return end
                sn.pinned = true
            end
            if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
        end)
        star:SetScript("OnEnter", function(self)
            local sn = rowSnap(i); if not sn then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(sn.pinned and T("LY_PIN_TT_ON", "永久保存中：不进 10 份轮换、不会被一键清理。点击取消永久")
                or T("LY_PIN_TT_OFF", "点击标为永久保存：不进 10 份轮换、不会被一键清理，标了以后可点名字改名"), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        star:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- 名字：永久的可点改名
        local nameBtn = CreateFrame("Button", nil, vs); nameBtn:SetSize(400, 22); nameBtn:SetPoint("TOPLEFT", 38, y - 4)
        local fs = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT"); fs:SetWidth(400); fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
        nameBtn:SetScript("OnClick", function()
            local sn = rowSnap(i); if not (sn and sn.pinned) then return end
            StaticPopup_Show("GEARINSIGHT_LAYOUT_RENAME", T("LY_RENAME_ASK", "给这份永久保存起个名字："), nil, { snap = sn })
        end)
        nameBtn:SetScript("OnEnter", function(self)
            local sn = rowSnap(i); if not sn then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(sn.pinned and T("LY_RENAME_TT", "点击改名") or (sn.reason or ""), 1, 1, 1)
            GameTooltip:Show()
        end)
        nameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local b = btn(vs, T("LY_BTN_RESTORE", "还原"), 70, 440, y, function()
            local target = rowSnap(i)
            if target then
                GearInsight:SaveLayoutBackup(T("LY_R_RESTORE", "还原前"), true)
                GearInsight:RestoreBars(target)
            end
        end)
        local d = btn(vs, T("LY_BTN_DEL", "删除"), 60, 516, y, function()
            local sn, idx = rowSnap(i)
            if sn and sn.pinned then GearInsight:Print(T("LY_DEL_PINNED", "这份是永久保存的：先点 ★ 取消永久再删")); return end
            if idx then table.remove(GearInsightDB.layoutBackups, idx); if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end end
        end)
        local e = btn(vs, T("LY_BTN_MS_ONE", "MySlot 串"), 90, 582, y, function()
            local sn = rowSnap(i)
            if sn then
                local ok, str = pcall(GearInsight.MySlotString, GearInsight, sn)
                if not ok then GearInsight:Print("|cffff4040" .. T("LY_MS_FAIL", "MySlot 串生成失败：") .. "|r" .. tostring(str)); return end
                GearInsight:ShowCopyText(str, T("LY_MS_HINT", "Ctrl+C 复制 > 打开 MySlot > 粘贴 > 导入"), "MySlot " .. (sn.title or sn.date or ""), nil, nil, {
                    label = T("LY_MS_OPEN", "打开 MySlot"),
                    onClick = function()
                        local ok2 = false
                        if SlashCmdList and SlashCmdList["MYSLOT"] then ok2 = pcall(SlashCmdList["MYSLOT"], "") end
                        if not ok2 then GearInsight:Print(T("LY_MS_NOADDON", "没装 MySlot 插件（或没启用）：串已在上面，装好后 /myslot 粘贴导入")) end
                    end,
                })
            end
        end)
        bkRows[i] = { fs = fs, b = b, d = d, e = e, star = star, nameBtn = nameBtn }
    end

    -- ── 替换 视图：左边操作，右边动作条实景（每格 = 图标 + 键位角标 + 来源色边）──
    local vr = CreateFrame("Frame", nil, pg); vr:SetPoint("TOPLEFT", 0, -66); vr:SetPoint("BOTTOMRIGHT"); views.replace = vr
    local LEFT_W = 250
    -- 左栏底色
    local lbg = vr:CreateTexture(nil, "BACKGROUND"); lbg:SetPoint("TOPLEFT", 10, 0); lbg:SetSize(LEFT_W, 1); lbg:SetPoint("BOTTOM", 0, 10); lbg:SetColorTexture(1, 1, 1, 0.03)
    local function lbl(parent, text, x, y, w, font, color)
        local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", x, y); fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetText(text)
        if color then fs:SetTextColor(color[1], color[2], color[3]) end
        return fs
    end
    local function wideBtn(parent, text, y, onClick, big)
        local bt = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        bt:SetSize(LEFT_W - 20, big and 34 or 28); bt:SetPoint("TOPLEFT", 20, y); bt:SetText(text); bt:SetScript("OnClick", onClick)
        bt:SetNormalFontObject(big and "GameFontNormalLarge" or "GameFontNormal"); bt:SetHighlightFontObject(big and "GameFontHighlightLarge" or "GameFontHighlight")
        return bt
    end
    lbl(vr, T("LY_STEP1", "① 铺技能"), 20, -8, LEFT_W - 20, "GameFontNormal", GOLD)
    wideBtn(vr, T("LY_BTN_RB", "清空重铺（推荐）"), -30, function() GearInsight:AskApplyLayout("rebuild") end, true)
    wideBtn(vr, T("LY_BTN_FILL", "只填空位"), -68, function() GearInsight:AskApplyLayout("fill") end)
    local tip1 = lbl(vr, T("LY_TIP", "清空重铺：主条 + 条2~条5 共 60 格按右边重铺。\n只填空位：条上已有的一个不动，只补缺的。"), 20, -100, LEFT_W - 24, "GameFontDisableSmall")
    local y2 = -100 - tip1:GetStringHeight() - 18
    lbl(vr, T("LY_STEP2", "② 设键位"), 20, y2, LEFT_W - 20, "GameFontNormal", GOLD)
    wideBtn(vr, T("LY_BTN_KEYS", "将插件建议实现到动作条"), y2 - 22, function() StaticPopup_Show("GEARINSIGHT_KEYS_CONFIRM") end, true)
    local bSnap = wideBtn(vr, T("LY_BTN_KEYS_RESET", "存储当前键位快照"), y2 - 60, function()
        -- ⛔ 不清手动改键记录、不读游戏实况：存的就是面板上现在显示的这套（用户 2026-09-18「点了直接给我设置面板重置了？？丢失了我的配置」——
        --   之前这里先 wipe 掉 layoutKeys 再抄实况，面板上调好还没绑到游戏里的键全没了）
        local snap = GearInsight.EnsureKeySnapshot(true, true)
        GearInsight:Print(string.format(T("LY_KEYSNAP_SAVED", "已把面板上现在这套键记为「我的键位」快照（%s），「保留现有键位」= 回到这份"), snap._at))
        if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
    end)
    bSnap:SetScript("OnEnter", function(self)
        local store, specID = keySnapStore()
        local snap = store[specID]
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(T("LY_KEYSNAP_TT1", "「我的键位」快照"), 1, 0.82, 0)
        GameTooltip:AddLine(T("LY_KEYSNAP_TT2", "「保留现有键位」模式读的不是实时绑定，而是这份快照——第一次打开这页时自动记的，所以智能改过之后还能切回去。\n你在面板上调好一套满意的键位，点这里把快照更新成面板上现在这套（不动游戏里的绑定，也不清手动改键记录）。"), 1, 1, 1, true)
        GameTooltip:AddLine(snap and (T("LY_KEYSNAP_TT3", "当前快照记于 ") .. (snap._at or "?")) or T("LY_KEYSNAP_TT4", "还没有快照"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    bSnap:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- 键位策略开关（用户「铺开的时候，有一个智能换键位，和保留键位的选项」）
    local cbSmart = CreateFrame("CheckButton", nil, vr, "UICheckButtonTemplate"); cbSmart:SetPoint("TOPLEFT", 18, y2 - 92); cbSmart:SetSize(24, 24)
    cbSmart.text:SetText(T("LY_CB_SMART", "换智能推荐键位")); cbSmart.text:SetFontObject("GameFontHighlightSmall")
    local cbKeep = CreateFrame("CheckButton", nil, vr, "UICheckButtonTemplate"); cbKeep:SetPoint("LEFT", cbSmart, "RIGHT", 96, 0); cbKeep:SetSize(24, 24)
    cbKeep.text:SetText(T("LY_CB_KEEP", "保留现有键位")); cbKeep.text:SetFontObject("GameFontHighlightSmall")
    local function syncCb()
        local keep = GearInsight.KeepKeysMode()
        cbSmart:SetChecked(not keep); cbKeep:SetChecked(keep)
    end
    -- 切换后把「会改哪些键」打出来，不然看不出有没有效果（用户「点了智能换键位，没效果」）
    local function reportKeyDiff(mode)
        local slots = GearInsight:BuildLayoutPlan()
        local changes, same = {}, 0
        for _, p in ipairs(slots) do
            local cur = GetBindingKey(GearInsight.SlotCommand(p.slot))
            local rec = GearInsight.SlotKey(p.slot)
            if cur == rec then same = same + 1
            else changes[#changes + 1] = string.format(T("LY_SLOT_FMT", "格%d %s"), p.slot, (cur and GetBindingText(cur, 1) or T("LY_NONE", "无")) .. ">" .. (rec and GetBindingText(rec, 1) or T("LY_NONE", "无"))) end
        end
        -- 只打一行统计（用户「不要打印了，太乱，统计的就行」）；逐格明细看右边格子的黄色角标
        GearInsight:Print(string.format(T("LY_KEYDIFF", "[%s] 推荐键位：会改 %d 格，%d 格不动（黄色角标 = 会改的；点「将插件建议实现到动作条」才生效）"), mode, #changes, same))
    end
    cbSmart:SetScript("OnClick", function()
        GearInsightDB = GearInsightDB or {}; GearInsightDB.layoutKeepKeys = false
        -- 切到智能 = 全局重排：之前手动点格改的键（含撞键留下的「不绑」）全部清掉，否则 1-5 被早先的手动记录占着，主循环拿不到（用户截图）
        local st, n = keyStore(), 0
        for k, v in pairs(st) do if v ~= false then st[k] = nil; n = n + 1 end end   -- 用户 Backspace 设的「不绑」保留
        GearInsight.ClearSmartKeys()   -- 主动切到智能 = 用户要的就是一次全局重排
        -- 静默清掉（统计一行就够了）
        syncCb(); if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end; reportKeyDiff(T("LY_CB_SMART", "换智能推荐键位"))
    end)
    cbKeep:SetScript("OnClick", function() GearInsightDB = GearInsightDB or {}; GearInsightDB.layoutKeepKeys = true; syncCb(); if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end; reportKeyDiff(T("LY_CB_KEEP", "保留现有键位")) end)
    local cbQE = CreateFrame("CheckButton", nil, vr, "UICheckButtonTemplate"); cbQE:SetPoint("TOPLEFT", 18, y2 - 116); cbQE:SetSize(24, 24)
    cbQE.text:SetText(T("LY_CB_QE", "Q E 也参与分键（默认留给左右平移）")); cbQE.text:SetFontObject("GameFontHighlightSmall")
    cbQE:SetChecked(GearInsightDB and GearInsightDB.layoutUseQE or false)
    cbQE:SetScript("OnClick", function(self)
        GearInsightDB = GearInsightDB or {}; GearInsightDB.layoutUseQE = self:GetChecked() and true or false
        GearInsight.RebuildKeyPool()
        if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
    end)
    cbSmart:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(T("LY_CB_SMART_TT", "按职能顺序整体重排：主循环拿 1-5，然后 RFTG ZXCV、Shift/Alt/Ctrl 组合、F1-F4…，7 8 9 0 / F5+ 排最后；裸 QE AD WS 留给移动"), 1, 1, 1, true); GameTooltip:Show() end)
    cbKeep:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(T("LY_CB_KEEP_TT", "按第一次打开这页时记下的「我的键位」快照来（智能改过也能回去），只给没绑键的格子补键"), 1, 1, 1, true); GameTooltip:Show() end)
    cbSmart:SetScript("OnLeave", function() GameTooltip:Hide() end); cbKeep:SetScript("OnLeave", function() GameTooltip:Hide() end)
    syncCb()
    wideBtn(vr, T("LY_BTN_RANK", "技能施放排名（参考）"), y2 - 148, function() GearInsight:ToggleCastRankWindow() end)
    wideBtn(vr, T("LY_BTN_MACRO_CLEAR", "一键清 GI 宏"), y2 - 180, function()
        local n = GearInsight:CountGiMacros()
        if n == 0 then GearInsight:Print(T("LY_MACRO_NONE", "没有 GI 打头的宏")); return end
        StaticPopup_Show("GEARINSIGHT_MACRO_CLEAR", string.format(T("LY_MACRO_CLEAR_ASK", "要删掉 %d 个「GI」打头的宏吗（含建坏的 placeholder）？动作条上对应的格会变空。"), n))
    end)
    lbl(vr, T("LY_KEYS_TIP", "格子左上角 = 推荐键：你现在按职能顺序整体重排：主循环拿 1-5，然后 RFTG ZXCV、Shift/Alt/Ctrl 组合、F1-F4…，7 8 9 0 / F5+ 排最后；裸 QE AD WS 留给移动不参与。\n点格子后按新键即改；Backspace 不绑；Esc 取消。"), 20, y2 - 216, LEFT_W - 24, "GameFontDisableSmall")
    -- 图例（两行三个）
    local LEGEND = { { "WCL", 1, 0.82, 0 }, { T("LY_WHY_OPENER", "起手"), 1, 0.5, 0 }, { T("LY_WHY_TALENT", "天赋"), 0.2, 0.9, 0.4 }, { "PvP", 0.8, 0.4, 1 }, { T("LY_WHY_BOOK", "法术书"), 0.55, 0.55, 0.55 }, { T("LY_LEG_TRK", "饰品/坐骑"), 0.3, 0.7, 1 } }
    for i, lg in ipairs(LEGEND) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local sw = vr:CreateTexture(nil, "ARTWORK"); sw:SetSize(10, 10); sw:SetPoint("BOTTOMLEFT", 20 + col * 76, 34 - row * 16); sw:SetColorTexture(lg[2], lg[3], lg[4])
        local fs = vr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); fs:SetPoint("LEFT", sw, "RIGHT", 3, 0); fs:SetText(lg[1])
    end
    local SRC_COLOR = { WCL = { 1, 0.82, 0 }, ["起手"] = { 1, 0.5, 0 }, ["天赋"] = { 0.2, 0.9, 0.4 }, ["PvP 天赋"] = { 0.8, 0.4, 1 }, ["法术书"] = { 0.55, 0.55, 0.55 }, ["饰品·主动"] = { 0.3, 0.7, 1 }, ["坐骑"] = { 0.3, 0.7, 1 } }
    local function srcColor(why)
        if not why then return SRC_COLOR["法术书"] end
        if why:sub(1, 3) == "WCL" then return SRC_COLOR.WCL end
        return SRC_COLOR[why] or SRC_COLOR["法术书"]
    end

    -- 右侧：整体可滚动（用户「整体菜单可以上下滚动」），按职能分行（用户「分行展示」），图标放大
    local GX = LEFT_W + 30
    local pvHd = lbl(vr, "", GX, -8, 600, "GameFontNormal")
    pvHd:ClearAllPoints(); pvHd:SetPoint("TOPLEFT", GX, -8); pvHd:SetPoint("RIGHT", -28, 0); pvHd:SetWordWrap(false)
    local rsf = CreateFrame("ScrollFrame", nil, vr, "UIPanelScrollFrameTemplate")
    -- 待生效状态行（用户「更改状态的时候，要显示当前有几个改动未实现，按什么实现」）
    local pending = lbl(vr, "", GX, -28, 600, "GameFontHighlightSmall")
    pending:ClearAllPoints(); pending:SetPoint("TOPLEFT", GX, -28); pending:SetPoint("RIGHT", -28, 0); pending:SetWordWrap(false)
    rsf:SetPoint("TOPLEFT", GX, -46); rsf:SetPoint("BOTTOMRIGHT", -28, 10)
    local rc = CreateFrame("Frame", nil, rsf); rc:SetSize(1, 1); rsf:SetScrollChild(rc)
    rsf:SetScript("OnSizeChanged", function(_, w) rc:SetWidth(math.max(200, w - 4)) end)
    -- 图标要大（用户「图标继续放大，太小了」）：分组行不再硬塞 12 个，一行 8 个，格子最大 72px
    local GAP, COLS = 5, 8
    local function cellSize()
        local w = rsf:GetWidth(); if not w or w < 100 then w = 560 end
        return math.max(40, math.min(72, math.floor((w - 4 - (COLS - 1) * GAP) / COLS)))
    end

    local capture = CreateFrame("Frame", nil, vr)
    capture:SetAllPoints(); capture:EnableKeyboard(true); capture:EnableMouse(true); capture:SetPropagateKeyboardInput(false); capture:Hide()
    capture:SetFrameStrata("DIALOG"); capture:SetFrameLevel(150)
    local function finishCapture(key)
        local slot = capture._slot; capture._slot = nil; capture:Hide()
        if slot and key ~= nil then
            if key then
                -- 这个键别的格已经在用 → 那格改成「不绑」，一个键只能指一格
                for _, bar in ipairs(BARS) do
                    for sl = bar.from, bar.to do
                        if sl ~= slot and GearInsight.SlotKey(sl) == key then
                            -- 被抢走键的格：置空「不绑」，⛔ 不自动补键、⛔ 不动任何其他格（用户 2026-09-18「如果冲突，就把被冲突的置为空，没有按键，改当前的」）
                            GearInsight.SetSlotKey(sl, false)
                            GearInsight:Print(string.format(T("LY_KEY_MOVED", "%s 原来指着格 %d，已挪到格 %d；格 %d 现在无快捷键（点它可再设）"), GetBindingText(key, 1), sl, slot, sl))
                        end
                    end
                end
            end
            GearInsight.SetSlotKey(slot, key)
        end
        if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
    end
    local function withMods(k)
        local m = ""
        if IsAltKeyDown() then m = m .. "ALT-" end
        if IsControlKeyDown() then m = m .. "CTRL-" end
        if IsShiftKeyDown() then m = m .. "SHIFT-" end
        return m .. k
    end
    capture:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then finishCapture(nil)
        elseif key == "BACKSPACE" or key == "DELETE" then finishCapture(false)
        elseif key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
        else finishCapture(withMods(key)) end
    end)
    capture:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" or button == "RightButton" then return end
        finishCapture(withMods(string.upper(button)))
    end)
    capture:SetScript("OnMouseWheel", function(_, d) finishCapture(withMods(d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")) end)
    -- 提示框挂在 UIParent 顶层，别被滚动区里的格子盖住；录键时把整个右侧压暗
    local dim = capture:CreateTexture(nil, "BACKGROUND"); dim:SetAllPoints(); dim:SetColorTexture(0, 0, 0, 0.6)
    local hintBox = CreateFrame("Frame", nil, capture, "BackdropTemplate")
    hintBox:SetFrameStrata("DIALOG"); hintBox:SetFrameLevel(200)
    hintBox:SetPoint("CENTER", capture, "CENTER", 120, 60); hintBox:SetSize(460, 150)
    hintBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    hintBox:SetBackdropColor(0.06, 0.06, 0.08, 1); hintBox:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    local hint = hintBox:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); hint:SetPoint("TOP", 0, -22); hint:SetText(T("LY_CAP_HINT", "按下新的键位…"))
    local hint2 = hintBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); hint2:SetPoint("TOP", hint, "BOTTOM", 0, -14); hint2:SetWidth(420); hint2:SetJustifyH("CENTER"); hint2:SetSpacing(4)
    hint2:SetText(T("LY_CAP_HINT2", "支持 Shift / Ctrl / Alt 组合、鼠标侧键、滚轮\nEsc 取消 · Backspace 不绑"))

    local function shortKey(k)
        local t = GetBindingText(k, 1) or k
        t = t:gsub("鼠标按键", "鼠"):gsub("鼠标滚轮向上", "滚上"):gsub("鼠标滚轮向下", "滚下"):gsub("Mouse Button ", "M"):gsub("Mouse Wheel Up", "WUp"):gsub("Mouse Wheel Down", "WDn")
        return t
    end
    local SRC_COLOR = { core = { 1, 0.82, 0 }, burst = { 1, 0.45, 0 }, interrupt = { 0.9, 0.2, 0.2 }, cc = { 0.65, 0.4, 1 },
                        def = { 0.3, 0.7, 1 }, heal = { 0.2, 0.9, 0.4 }, mob = { 0.4, 0.9, 0.9 }, raid = { 1, 0.7, 0.9 }, dispel = { 0.9, 0.9, 0.4 },
                        taunt = { 0.8, 0.5, 0.3 }, summon = { 0.6, 0.6, 0.6 }, util = { 0.5, 0.75, 0.75 }, dps = { 0.55, 0.55, 0.55 }, inv = { 0.8, 0.8, 0.8 } }

    -- 格子对象池
    local pool, hdrPool = {}, {}
    local function newCell()
        local c = CreateFrame("Button", nil, rc, "BackdropTemplate")
        c:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        c:SetBackdropColor(0, 0, 0, 0.6)
        c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetPoint("TOPLEFT", 2, -2); c.icon:SetPoint("BOTTOMRIGHT", -2, 2); c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        c.keyBg = c:CreateTexture(nil, "OVERLAY"); c.keyBg:SetPoint("TOPLEFT", 2, -2); c.keyBg:SetPoint("TOPRIGHT", -2, -2); c.keyBg:SetHeight(15); c.keyBg:SetColorTexture(0, 0, 0, 0.75)
        c.key = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); c.key:SetPoint("TOPLEFT", 3, -1); c.key:SetPoint("RIGHT", -2, 0); c.key:SetJustifyH("LEFT"); c.key:SetWordWrap(false)
        c.num = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); c.num:SetPoint("BOTTOMRIGHT", -2, 1); c.num:SetTextColor(0.65, 0.65, 0.65)
        -- 天赋角标：左下角绿色小三角块 + 「天」字（用户「天赋技能用一个视觉效果标记」）
        c.tal = c:CreateTexture(nil, "OVERLAY"); c.tal:SetSize(16, 16); c.tal:SetPoint("BOTTOMLEFT", 2, 2); c.tal:SetColorTexture(0.1, 0.75, 0.3, 0.95)
        c.talT = c:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall"); c.talT:SetPoint("CENTER", c.tal, "CENTER", 0, 0); c.talT:SetText(T("LY_BADGE_TALENT", "天"))
        c.mac = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); c.mac:SetPoint("CENTER", 0, -4); c.mac:SetText("|cffffd100" .. T("LY_MACRO_WORD", "宏") .. "|r"); c.mac:Hide()
        c.macBg = c:CreateTexture(nil, "BORDER"); c.macBg:SetPoint("BOTTOMLEFT", 2, 2); c.macBg:SetPoint("BOTTOMRIGHT", -2, 2); c.macBg:SetHeight(16); c.macBg:SetColorTexture(0, 0, 0, 0.7); c.macBg:Hide()
        c.macT = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.macT:SetPoint("BOTTOMLEFT", 3, 3); c.macT:SetPoint("BOTTOMRIGHT", -3, 3); c.macT:SetJustifyH("CENTER"); c.macT:SetWordWrap(false); c.macT:SetText(""); c.macT:Hide()
        c.rac = c:CreateTexture(nil, "OVERLAY"); c.rac:SetSize(16, 16); c.rac:SetPoint("BOTTOMLEFT", 2, 2); c.rac:SetColorTexture(0.2, 0.5, 0.95, 0.95)
        c.racT = c:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall"); c.racT:SetPoint("CENTER", c.rac, "CENTER", 0, 0); c.racT:SetText(T("LY_BADGE_RACIAL", "族"))
        c.hl = c:CreateTexture(nil, "HIGHLIGHT"); c.hl:SetAllPoints(); c.hl:SetColorTexture(1, 1, 1, 0.12)
        c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        c:RegisterForDrag("LeftButton")
        c:SetScript("OnDragStart", function(self)
            if InCombatLockdown() then return end
            ClearCursor()
            if self._inv then PickupInventoryItem(self._inv)
            elseif self._item then PickupItem(self._item)
            elseif self._macro then local mi = GearInsight:EnsureMacroItem(self._it); if mi then PickupMacro(mi) end
            elseif self._id == 150544 and C_MountJournal and C_MountJournal.Pickup then C_MountJournal.Pickup(0)
            elseif self._id then PickupSpell(self._id) end
        end)
        c:SetScript("OnClick", function(self, button)
            if not self._slot then return end
            if self._macro then
                -- 宏格：左键 = 改推荐键（和别的格一样，用户「点击了怎么不能设置按键」）；右键 = 打开宏编辑器；
                --        Shift+左键 = 现在就建宏并放到这格（不想等清空重铺时）；按住左键拖 = 拖到动作条
                if button == "RightButton" then
                    GearInsight:EnsureMacroItem(self._it, IsShiftKeyDown())
                    GearInsight:OpenMacroEditor(macroNameOf(self._it))
                    return
                elseif IsShiftKeyDown() then
                    if InCombatLockdown() then GearInsight:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
                    local mi = GearInsight:EnsureMacroItem(self._it)
                    if mi then ClearCursor(); PickupMacro(mi); if GetCursorInfo() then PlaceAction(self._slot) end; ClearCursor()
                        GearInsight:Print(string.format(T("LY_MACRO_PLACED", "宏「%s」已建好并放到格 %d"), macroNameOf(self._it), self._slot)) end
                    if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
                    return
                end
            end
            capture._slot = self._slot; capture:Show(); self.key:SetText("|cffffd100…|r")
        end)
        c:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self._inv then GameTooltip:SetInventoryItem("player", self._inv)
            elseif self._item then GameTooltip:SetItemByID(self._item)
            elseif self._macro then
                GameTooltip:AddLine(macroNameOf(self._it) .. "  |cff888888" .. T("LY_MACRO_TT", "普通宏（非 GSE）") .. "|r", 1, 0.82, 0)
                if self._it.lib then
                    local m = self._it.lib
                    GameTooltip:AddLine(fillIds(libName(m)) .. "  |cff888888" .. T("LY_LIB_SRC", "来自宏库（Icy Veins / Method 12.1）") .. "|r", 0.8, 0.8, 0.8)
                    if libNote(m) ~= "" then GameTooltip:AddLine(fillIds(libNote(m)), 0.7, 0.7, 0.7, true) end
                    if self._it.missing and #self._it.missing > 0 then GameTooltip:AddLine(T("LY_LIB_MISSING", "|cffff4040[缺]|r 你没有这些技能：") .. table.concat(self._it.missing, "、"), 1, 0.3, 0.3, true) end
                end
                for line in macroBodyOf(self._it):gmatch("[^\n]+") do GameTooltip:AddLine(line, 0.85, 0.85, 0.85) end
                GameTooltip:AddLine(" ")
                if self._it and self._it.groupItems then GameTooltip:AddLine(T("LY_MACRO_TT3", "按一次：不占 GCD 的全放 + 第一个能放的占 GCD 技能；连按几下才会全放完（暴雪宏规则，不是坏了）"), 1, 0.8, 0.4, true) end
                GameTooltip:AddLine(T("LY_MACRO_TT2", "左键：改推荐键 · Shift+左键：现在就建宏放到这格 · 拖动：拖到动作条 · 右键：打开宏编辑器（已有同名宏不重建）· Shift+右键：重新生成正文"), 0.6, 0.9, 0.6, true)
            elseif self._id then GameTooltip:SetSpellByID(self._id) end
            GameTooltip:AddLine(" ")
            local roleTxt = ((self._why == "嘲讽" or self._why == "解控" or self._why == "群控" or self._why == "单控") and whyText(self._why) or ROLE_LABEL[self._role] or "") .. (self._talent and (self._pvp and "  · |cff40c060" .. T("LY_WHY_PVP", "PvP 天赋") .. "|r" or "  · |cff40c060" .. T("LY_SRC_TALENT", "天赋技能") .. "|r") or "") .. (self._why == "种族" and "  · |cff4090ff" .. T("LY_SRC_RACIAL", "种族技能") .. "|r" or "")
            GameTooltip:AddLine(roleTxt .. (self._why and ("  · " .. whyText(self._why)) or ""), 0.8, 0.8, 0.8)
            if self._slot then
                local cur = GetBindingKey(GearInsight.SlotCommand(self._slot))
                GameTooltip:AddLine(string.format("%s %d   %s%s   %s%s", T("LY_SLOT", "格"), self._slot, T("LY_KEY_TT2", "现在："), cur and GetBindingText(cur, 1) or T("LY_KEY_NONE", "不绑"),
                    T("LY_KEY_REC", "推荐："), GearInsight.SlotKey(self._slot) and GetBindingText(GearInsight.SlotKey(self._slot), 1) or T("LY_KEY_NONE", "不绑")), 1, 1, 1)
                GameTooltip:AddLine(T("LY_KEY_TT3", "点一下再按新键可改；Backspace 不绑；Esc 取消 · 按住左键可直接拖到动作条"), 0.5, 0.5, 0.5)
                local k = GearInsight.SlotKey(self._slot)
                if k then
                    for _, bar in ipairs(BARS) do for sl = bar.from, bar.to do
                        if sl ~= self._slot and GearInsight.SlotKey(sl) == k then GameTooltip:AddLine(string.format(T("LY_KEY_CONFLICT", "[撞键] 和格 %d 撞键：实现时后出现的格拿到这个键，另一格置空。点其中一格改个键。"), sl), 1, 0.3, 0.3, true) end
                    end end
                end
            elseif self._it and self._it.off then
                GameTooltip:AddLine(T("LY_GROUP_OFF_TT", "这一行没勾「上条」，不占格；勾上行头的框才铺"), 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine(T("LY_NO_SLOT", "60 格放不下，这个不铺"), 1, 0.4, 0.4)
            end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return c
    end
    local hdrCbs = {}
    local function newHdr(i)
        local h = rc:CreateFontString(nil, "OVERLAY", "GameFontNormal"); h:SetJustifyH("LEFT")
        local cb = CreateFrame("CheckButton", nil, rc, "UICheckButtonTemplate"); cb:SetSize(20, 20)
        cb:SetScript("OnClick", function(self) if self._key then GearInsight.SetGroupOn(self._key, self:GetChecked()); if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end end end)
        cb:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(T("LY_GROUP_ON_TT", "勾 = 这一行上动作条、分键；不勾 = 整行折叠不占格（宏 / 饰品 / 药水照放）"), 1, 1, 1, true); GameTooltip:Show() end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        hdrCbs[i] = cb
        return h
    end

    -- 「现在的动作条」对照（在滚动区最下面）
    local nowCells = {}
    local nowHd = rc:CreateFontString(nil, "OVERLAY", "GameFontNormal"); nowHd:SetText(T("LY_NOW_HD", "现在的动作条") .. "  |cff888888" .. T("LY_NOW_NOTE", "红角 = 重铺后这格会变") .. "|r")
    local nowLbls = {}
    for bi, bar in ipairs(BARS) do
        nowLbls[bi] = rc:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); nowLbls[bi]:SetText(bar.label:match("^[^·]+"))
        for n = 1, 12 do
            local slot = bar.from + n - 1
            local c = CreateFrame("Button", nil, rc, "BackdropTemplate")
            c:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            c:SetBackdropColor(0, 0, 0, 0.5); c:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetPoint("TOPLEFT", 1, -1); c.icon:SetPoint("BOTTOMRIGHT", -1, 1); c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            c.mark = c:CreateTexture(nil, "OVERLAY"); c.mark:SetSize(8, 8); c.mark:SetPoint("TOPRIGHT", -1, -1); c.mark:SetColorTexture(1, 0.25, 0.25, 1); c.mark:Hide()
            c._slot = slot
            c:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local r = slotInfo(self._slot)
                if r and r.t == "spell" then GameTooltip:SetSpellByID(r.id)
                elseif r and r.t == "item" then GameTooltip:SetItemByID(r.id)
                elseif r and r.t == "macro" then GameTooltip:AddLine((T("LY_MACRO", "宏：")) .. tostring(r.name), 1, 1, 1)
                elseif r then GameTooltip:AddLine(tostring(r.t), 1, 1, 1)
                else GameTooltip:AddLine(T("LY_EMPTY", "空格"), 0.6, 0.6, 0.6) end
                local cur = GetBindingKey(GearInsight.SlotCommand(self._slot))
                GameTooltip:AddLine(string.format("%s %d · %s", T("LY_SLOT", "格"), self._slot, cur and GetBindingText(cur, 1) or T("LY_KEY_NONE", "不绑")), 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            c:SetScript("OnLeave", function() GameTooltip:Hide() end)
            nowCells[slot] = c
        end
    end
    -- 宏库列表：勾选 = 加入安排池（用户「让用户选择添加到安排池里，然后参与按键自动排，也可以设置快捷键」）
    local libHd = rc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local libRows = {}
    local function libRow(i)
        if libRows[i] then return libRows[i] end
        local r = CreateFrame("Frame", nil, rc); r:SetHeight(22)
        r.cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"); r.cb:SetSize(22, 22); r.cb:SetPoint("LEFT", 0, 0)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 26, 0); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", 48, 0); r.name:SetWidth(200); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
        r.st = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.st:SetPoint("LEFT", 252, 0); r.st:SetPoint("RIGHT", -4, 0); r.st:SetJustifyH("LEFT"); r.st:SetWordWrap(false)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            local m = self._m; if not m then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(fillIds(libName(m)), 1, 0.82, 0)
            if libNote(m) ~= "" then GameTooltip:AddLine(fillIds(libNote(m)), 0.8, 0.8, 0.8, true) end
            local body, missing = GearInsight.LocalizeMacroBody(m)
            GameTooltip:AddLine(" ")
            for line in body:gmatch("[^\n]+") do GameTooltip:AddLine(line, 0.85, 0.85, 0.85) end
            if #missing > 0 then GameTooltip:AddLine(T("LY_LIB_MISSING", "|cffff4040[缺]|r 你没有这些技能：") .. table.concat(missing, "、"), 1, 0.3, 0.3, true) end
            GameTooltip:AddLine(T("LY_LIB_TT", "勾选 = 加入安排池，按第一个技能的职能归行，自动分键；铺的时候建宏放上去"), 0.6, 0.9, 0.6, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.cb:SetScript("OnClick", function(self)
            local m = r._m; if not m then return end
            local st = GearInsight.LibStore()
            st[m.key] = self:GetChecked() and true or false
            if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
        end)
        libRows[i] = r; return r
    end
    local function layoutLib(y)
        local key = specKey()
        local LIB = GearInsight.MacroLibFor(key)
        local st = GearInsight.LibStore()
        local nSel = 0; for _, m in ipairs(LIB) do if GearInsight.LibSelected(st, m) then nSel = nSel + 1 end end
        libHd:ClearAllPoints(); libHd:SetPoint("TOPLEFT", 0, y)
        libHd:SetText(string.format("%s  |cff888888%d / %d · %s|r", T("LY_LIB_HD", "宏库 · 勾选加入安排池"), nSel, #LIB, T("LY_LIB_SUB", "Icy Veins / Method 12.1 各专精宏，红字 = 你缺技能")))
        y = y - 22
        for i, m in ipairs(LIB) do
            local r = libRow(i)
            r._m = m
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:SetPoint("RIGHT", rc, "RIGHT", -4, 0); r:Show()
            r.cb:SetChecked(GearInsight.LibSelected(st, m))
            local first = m.spells and m.spells[1]
            if m.gi and m.group then r.icon:SetTexture("Interface\\ICONS\\" .. GROUP_MACRO[m.group].icon)
            elseif m.gi then r.icon:SetTexture("Interface\\AddOns\\GearInsight\\icon")
            else r.icon:SetTexture(first and (C_Spell.GetSpellInfo(first) or {}).iconID or 134400) end
            local _, missing = GearInsight.LocalizeMacroBody(m)
            r.name:SetText(fillIds(libName(m)))
            if #missing > 0 then
                -- 没学/没点的技能：直接不可选（用户「天赋没有直接不可选」）；之前勾过的取消掉
                r.name:SetTextColor(0.5, 0.5, 0.5); r.st:SetText("|cffff6060" .. T("LY_LIB_LACK", "缺：") .. table.concat(missing, "、") .. "|r")
                r.cb:SetChecked(false); r.cb:Disable(); r.cb:SetAlpha(0.35)
                if st[m.key] then st[m.key] = nil end
            else
                r.name:SetTextColor(1, 1, 1); r.st:SetText(fillIds(libNote(m)))
                if m.gi then r.name:SetTextColor(1, 0.82, 0); r.st:SetText("|cffffd100[GearInsight]|r " .. libNote(m)) end
                r.cb:Enable(); r.cb:SetAlpha(1)
            end
            y = y - 22
        end
        for i = #LIB + 1, #libRows do libRows[i]:Hide() end
        return y - 8
    end

    local function layoutNow(y, cell)
        local w = rsf:GetWidth(); if not w or w < 100 then w = 560 end
        local NG = 2
        local NC = math.max(24, math.min(40, math.floor((w - 40 - 11 * NG) / 12)))
        nowHd:ClearAllPoints(); nowHd:SetPoint("TOPLEFT", 0, y)
        y = y - 20
        for bi, bar in ipairs(BARS) do
            nowLbls[bi]:ClearAllPoints(); nowLbls[bi]:SetPoint("TOPLEFT", 0, y - 8)
            for n = 1, 12 do
                local c = nowCells[bar.from + n - 1]
                c:SetSize(NC, NC); c:ClearAllPoints(); c:SetPoint("TOPLEFT", 34 + (n - 1) * (NC + NG), y)
            end
            y = y - NC - NG
        end
        return y
    end
    local function refreshNow(planned)
        for slot, c in pairs(nowCells) do
            local r = slotInfo(slot)
            local icon
            if r then
                if r.t == "spell" then icon = (C_Spell.GetSpellInfo(r.id) or {}).iconID
                elseif r.t == "item" then icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(r.id)
                elseif r.t == "macro" then
                    -- 宏格：图标别是问号/占位（用户「宏别空在这里」）——按正文第一个 /cast /use 的技能或物品取图标
                    local idx = r.name and GetMacroIndexByName(r.name)
                    if idx and idx > 0 then
                        local _, tex, body = GetMacroInfo(idx)
                        icon = tex
                        for line in (body or ""):gmatch("[^\n]+") do
                            local cmd, rest = line:match("^/(%S+)%s*(.*)$")
                            if cmd == "cast" or cmd == "use" or cmd == "castsequence" then
                                rest = rest:gsub("%[.-%]", ""):gsub("reset=%S+", ""):gsub("^%s+", "")
                                local nm = rest:match("^([^,;]+)"); nm = nm and nm:gsub("%s+$", "") or ""
                                local sp = nm ~= "" and C_Spell.GetSpellInfo(nm)
                                if sp and sp.iconID then icon = sp.iconID; break end
                                local itIcon = nm ~= "" and C_Item.GetItemIconByID and (tonumber(nm:match("item:(%d+)")) and C_Item.GetItemIconByID(tonumber(nm:match("item:(%d+)"))) or C_Item.GetItemIconByID(nm))
                                if itIcon then icon = itIcon; break end
                            end
                        end
                    end
                elseif r.t == "summonmount" then icon = "Interface\\ICONS\\Ability_Mount_RidingHorse" end
            end
            c.icon:SetTexture(icon)
            local p = planned[slot]
            local same = (not r and not p) or (r and p and ((p.id and r.t == "spell" and (r.id == p.id or (FindBaseSpellByID and FindBaseSpellByID(r.id) == p.id))) or (p.inv and r.t == "item") or (p.item and r.t == "item" and r.id == p.item) or (p.macro and r.t == "macro" and r.name == macroNameOf(p))))
            c.mark:SetShown(not same)
        end
    end

    local function refresh()
        local ordered = GearInsight.OrderedBackups()
        for i = 1, #bkRows do
            local o = ordered[i]
            local s = o and o.snap
            local r = bkRows[i]
            if s then
                local n = 0; for _ in pairs(s.slots) do n = n + 1 end
                r.fs:SetText(string.format("%s%s   |cff888888%d%s|r", s.pinned and "|cffffd100" or "", GearInsight.BackupTitle(s), n, T("LY_SLOT_UNIT", " 格")))
                r.star.tex:SetVertexColor(s.pinned and 1 or 0.35, s.pinned and 0.82 or 0.35, s.pinned and 0 or 0.35)
                r.star:Show(); r.nameBtn:Show(); r.b:Show(); r.d:Show(); r.e:Show()
            else
                r.fs:SetText(i == 1 and "|cff888888" .. T("LY_BK_NONE", "还没有备份") .. "|r" or "")
                r.star:Hide(); r.nameBtn:SetShown(i == 1); r.b:Hide(); r.d:Hide(); r.e:Hide()
            end
        end
        if not vr:IsShown() then return end
        rc:SetWidth(math.max(200, rsf:GetWidth() - 4))
        local slots, meta = self:BuildLayoutPlan()
        pvHd:SetText(string.format("%s  |cff888888%s%d · %s%d|r", T("LY_PV_HD", "重铺后的动作条 · 按职能分行"), T("LY_TOTAL", "共 "), meta.total, T("LY_DROP", "放不下 "), math.max(meta.dropped, 0)))
        local CELL = cellSize()
        -- 撞键统计：同一个推荐键指了几格
        local keyUse = {}
        for _, p in ipairs(slots) do local k = GearInsight.SlotKey(p.slot); if k then keyUse[k] = (keyUse[k] or 0) + 1 end end
        local ci, hi, y = 0, 0, 0
        for _, g in ipairs(meta.groups) do
            if #g.items > 0 then
                hi = hi + 1; hdrPool[hi] = hdrPool[hi] or newHdr(hi)
                local h, cb = hdrPool[hi], hdrCbs[hi]
                cb:ClearAllPoints(); cb:SetPoint("TOPLEFT", -2, y + 3); cb._key = g.key; cb:SetChecked(g.on); cb:Show()
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 20, y); h:SetPoint("RIGHT", rc, "RIGHT", -4, 0); h:SetWordWrap(false); h:Show()
                local col = SRC_COLOR[g.key] or SRC_COLOR.dps
                h:SetText(string.format("|cff%02x%02x%02x%s|r  |cff777777%d%s%s%s|r", col[1] * 255, col[2] * 255, col[3] * 255, g.label, #g.items, T("LY_N_UNIT", " 个"),
                    g.on and "" or T("LY_GROUP_OFF", " · 不上条（勾上才占格）"), g.desc ~= "" and ("  · " .. g.desc) or ""))
                y = y - 18
                local n = 0
                local sepDone, sep2Done = false, false
                for _, it in ipairs(g.items) do
                    if it.sep and not sepDone then sepDone = true; if n % COLS ~= 0 then n = n + 1 end end   -- 饰品前空一格
                    if it.sep2 and not sep2Done then sep2Done = true; if n % COLS ~= 0 then n = n + 1 end end -- 宏格前再空一格
                    ci = ci + 1; pool[ci] = pool[ci] or newCell()
                    local c = pool[ci]
                    c:SetSize(CELL, CELL); c:ClearAllPoints(); c:SetPoint("TOPLEFT", (n % COLS) * (CELL + GAP), y - math.floor(n / COLS) * (CELL + GAP)); c:Show()
                    c._id, c._inv, c._item, c._role, c._why, c._slot, c._talent, c._pvp, c._macro, c._groupItems, c._it = it.id, it.inv, it.item, it.role, it.why, it.slot, it.talent, it.pvp, it.macro, it.groupItems, it
                    local icon
                    if it.inv then icon = GetInventoryItemTexture("player", it.inv)
                    elseif it.item then icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.item)
                    elseif it.gi then icon = "Interface\\AddOns\\GearInsight\\icon"
                    elseif it.macro and it.lib then icon = (it.lib.spells and it.lib.spells[1] and (C_Spell.GetSpellInfo(it.lib.spells[1]) or {}).iconID) or "Interface\\ICONS\\INV_Misc_QuestionMark"
                    elseif it.macro then icon = "Interface\\ICONS\\" .. macroIconOf(it)
                    else icon = (C_Spell.GetSpellInfo(it.id) or {}).iconID end
                    c.icon:SetTexture(icon); c.icon:SetDesaturated(it.slot == nil or (it.item and not it.have) or false)
                    c:SetAlpha(it.off and 0.45 or 1)
                    c:SetBackdropBorderColor(col[1], col[2], col[3], it.slot and 1 or 0.35)
                    c.tal:SetShown(it.talent and true or false); c.talT:SetShown(it.talent and true or false)
                    c.rac:SetShown(it.racial and true or false); c.racT:SetShown(it.racial and true or false)
                    c.macBg:SetShown(it.macro and true or false); c.macT:SetShown(it.macro and true or false)
                    if it.macro then
                        -- 底部标签直接写宏名（用户「不显示宏库了，直接显示宏名」），去掉 GI 前缀省地方
                        local nm = macroNameOf(it):gsub("^GI", "")
                        c.macT:SetText(nm); c:SetBackdropBorderColor(1, 0.82, 0, 1)
                    end
                    if it.macro and it.missing and #it.missing > 0 then c:SetBackdropBorderColor(1, 0.3, 0.3, 1) end
                    c.num:SetText(it.slot or "")
                    if it.slot then
                        local k = GearInsight.SlotKey(it.slot)
                        local cur = GetBindingKey(GearInsight.SlotCommand(it.slot))
                        local txt = k and shortKey(k) or ""
                        if k and keyUse[k] and keyUse[k] > 1 then txt = "|cffff4040" .. txt .. "!|r"   -- 红 + ! = 和别的格撞键
                        elseif k and cur ~= k then txt = "|cffffd100" .. txt .. "|r" end
                        c.key:SetText(txt); c.keyBg:Show()
                    else c.key:SetText(""); c.keyBg:Hide() end
                    n = n + 1
                end
                y = y - math.ceil(n / COLS) * (CELL + GAP) - 8
            end
        end
        for j = ci + 1, #pool do pool[j]:Hide() end
        for j = hi + 1, #hdrPool do hdrPool[j]:Hide(); if hdrCbs[j] then hdrCbs[j]:Hide() end end
        y = layoutLib(y - 6)
        y = layoutNow(y - 6, CELL)
        rc:SetHeight(-y + 10)
        local planned = {}
        for _, p in ipairs(slots) do planned[p.slot] = p end
        refreshNow(planned)
        -- 统计：格子内容差几格（要点「清空重铺」）、键位差几格（要点「设置绑定」）
        local nContent, nKeys = 0, 0
        for _, bar in ipairs(BARS) do
            for sl = bar.from, bar.to do
                local r, p = slotInfo(sl), planned[sl]
                local same = (not r and not p) or (r and p and ((p.id and r.t == "spell" and (r.id == p.id or (FindBaseSpellByID and FindBaseSpellByID(r.id) == p.id))) or (p.inv and r.t == "item") or (p.item and r.t == "item" and r.id == p.item) or (p.macro and r.t == "macro" and r.name == macroNameOf(p))))
                if not same then nContent = nContent + 1 end
                local cur, rec = GetBindingKey(GearInsight.SlotCommand(sl)), GearInsight.SlotKey(sl)
                if (cur or "") ~= (rec or "") then nKeys = nKeys + 1 end
            end
        end
        local parts = {}
        if nContent > 0 then parts[#parts + 1] = string.format("|cffffd100%d|r %s", nContent, T("LY_PEND_CONTENT", "格内容未铺 → 点「清空重铺」")) end
        if nKeys > 0 then parts[#parts + 1] = string.format("|cffffd100%d|r %s", nKeys, T("LY_PEND_KEYS", "格键位未生效 → 点「将插件建议实现到动作条」")) end
        if #parts == 0 then pending:SetText("|cff40c060" .. T("LY_PEND_NONE", "动作条和键位都已和右边一致") .. "|r")
        else pending:SetText(table.concat(parts, "   ")) end
    end
    self._layoutRefresh = refresh
    -- 铺完 / 还原完 / 绑定完都会调 refresh；动作条被玩家手动改了也刷
    local ev = CreateFrame("Frame"); ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED"); ev:RegisterEvent("UPDATE_BINDINGS")
    -- 合并成每帧最多刷一次：铺 60 格会连发 60 个 ACTIONBAR_SLOT_CHANGED，逐个刷会把整页重画 60 遍
    local queued = false
    ev:SetScript("OnEvent", function()
        if queued or not (pg:IsShown() and vr:IsShown()) then return end
        queued = true
        C_Timer.After(0, function() queued = false; if pg:IsShown() and vr:IsShown() then refresh() end end)
    end)
    showMode((GearInsightDB and GearInsightDB.layoutMode) or "replace")   -- 默认停在「替换」（卖点在这页；「保存」是安全网）
end
