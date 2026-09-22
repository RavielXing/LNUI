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
-- /gikm 技能名或ID：键位来源排查（真身在 BuildLayoutPage 里；页没打开过就提示）。⛔ 顶层注册：函数里注册的斜杠命令有时聊天框不认（09-20 用户「打了没有用」）
-- /girole 技能名 [auto|core|burst|interrupt|cc|def|heal|mob|form|raid|dispel|summon|util|dps|skip]：命令行改职能行 / 恢复自动（右键菜单点不到时的保底，09-20）
SLASH_GEARINSIGHTROLE1 = "/girole"
SlashCmdList["GEARINSIGHTROLE"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local name, role = msg:match("^(.-)%s+(%S+)$")
    if not name then name, role = msg, "auto" end
    local sp = name ~= "" and C_Spell.GetSpellInfo(tonumber(name) or name)
    if not (sp and sp.spellID) then print("|cffe2b85cGearInsight|r /girole 技能名 [auto|core|burst|interrupt|cc|def|heal|mob|form|raid|dispel|summon|util|dps|skip]"); return end
    GearInsightDB = GearInsightDB or {}; GearInsightDB.layoutRoleOverride = GearInsightDB.layoutRoleOverride or {}
    if role == "auto" then GearInsightDB.layoutRoleOverride[sp.spellID] = nil; if GearInsightDB.layoutSpellKey then GearInsightDB.layoutSpellKey[sp.spellID] = nil end
    else GearInsightDB.layoutRoleOverride[sp.spellID] = role end
    print(string.format("|cffe2b85cGearInsight|r %s → %s", sp.name, role))
    if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
end
SLASH_GEARINSIGHTKM1 = "/gikm"
SlashCmdList["GEARINSIGHTKM"] = function(msg)
    if GearInsight._gikm then GearInsight._gikm(msg) else print("|cffe2b85cGearInsight|r 先打开一次「键位手法」页再用 /gikm") end
end

local PickupSpell = (C_Spell and C_Spell.PickupSpell) or _G.PickupSpell
local PickupItem = (C_Item and C_Item.PickupItem) or _G.PickupItem

local macroNameOf, libName   -- 定义在宏库段（ApplyKeyBindings 在它前面就要用，先声明）
local sameAsPlan   -- 定义在 BuildLayoutPlan 前面，ApplyKeyBindings 在它前面就要用，先声明
local bookSpells   -- 定义在下面；BuildFormPagePlans 在它前面就要用，先声明
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
    -- 09-21 用户「还原没把随机偏好坐骑的快捷键还原正确」（守护德）：变身时 GetActionInfo(1..12) 读到的是熊 / 猫那页，
    --   存下来就是「熊页当主条」，还原时再把人形主条铺到熊页上——坐骑（主条 9 格）就这么错位的。存 / 还原都必须人形
    if GearInsight.InForm and GearInsight.InForm() then self:Print("|cffff8000" .. T("LY_NEED_HUMANOID", "先变回人形再铺：变身时主条 1–12 指向的是当前形态那页，人形页碰不到（暴雪 API 限制）") .. "|r"); return nil end
    local snap = { time = time(), date = date("%m-%d %H:%M"), char = UnitName("player"), slots = {}, reason = reason }
    local specIdx = GetSpecialization and GetSpecialization()
    if specIdx then local _, n = GetSpecializationInfo(specIdx); snap.spec = n end
    for i = 1, MAX_SLOT do
        local r = slotInfo(i)
        if r then snap.slots[i] = r end
    end
    -- 宏格连正文一起存（09-21 用户「保存复位以后宏变了」：之前只记宏名，铺格子 / 设置绑定会把 GI 宏正文按新计划重新生成、「一键清 GI 宏」会把宏删掉，
    --   还原时按名字找宏只能找到「现在这份」——正文回不去、删了的回不来）。按宏名存 { icon, body, perChar }，还原时先把宏本身改回 / 重建，再放格子
    snap.macros = {}
    for i = 1, MAX_SLOT do
        local r = snap.slots[i]
        if r and r.t == "macro" and r.name and type(r.id) == "number" and r.id > 0 and not snap.macros[r.name] then
            local name, icon, body = GetMacroInfo(r.id)
            if name == r.name then snap.macros[name] = { icon = icon, body = body or "", perChar = r.id > (MAX_ACCOUNT_MACROS or 120) } end
        end
    end
    -- 全部按键绑定都存（命令 → 键）：设置绑定会把 Q/E 这种从「向左/右平移」上抢过来，只存 60 格的话还原时 Q/E 回不去
    --   一个命令可以绑不止两个键：全存（之前只存前两个，第三个起还原后就丢了）
    snap.binds = {}
    for i = 1, GetNumBindings() do
        local cmd = GetBinding(i)
        local keys = {}
        for _, k in ipairs({ select(3, GetBinding(i)) }) do if k and k ~= "" then keys[#keys + 1] = k end end
        if cmd and #keys > 0 then snap.binds[cmd] = keys end
    end
    -- 签名：格子 + 宏正文 + 绑定拼成串，和上一份一样就不重复存
    local sig = {}
    for i = 1, MAX_SLOT do local r = snap.slots[i]; if r then sig[#sig + 1] = i .. ":" .. r.t .. ":" .. tostring(r.name or r.id) end end
    for name, m in pairs(snap.macros) do sig[#sig + 1] = "M:" .. name .. "=" .. tostring(m.icon) .. ":" .. (m.body or "") end
    for cmd, b in pairs(snap.binds) do sig[#sig + 1] = cmd .. "=" .. table.concat(b, "/") end
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
    for _, sn in ipairs((GearInsightDB and GearInsightDB.layoutBackups) or {}) do if sn.pinned and not sn.daily then n = n + 1 end end   -- 每日存档不占名额
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
-- 格号 → 技能身份（BuildLayoutPlan 每次刷新）；手动键表按身份存，格号只是当前位置
GearInsight._slotIdent = GearInsight._slotIdent or {}
local function identOf(p)
    if not p then return nil end
    return p.id and ("s" .. p.id) or (p.macro and ("m" .. tostring(GearInsight.MacroNameOf and GearInsight.MacroNameOf(p) or p.macro))) or (p.item and ("i" .. p.item)) or (p.inv and ("v" .. p.inv)) or nil
end
GearInsight.IdentOf = identOf
local function slotIdent(slot) return GearInsight._slotIdent[slot] or ("k" .. slot) end
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

-- 系统键（回复密语 / 信号 / 焦点…）原本的默认键：第一次看到它绑着键就记下（按命令存 DB），被格子顶掉后靠这个还回去
function GearInsight.SpecialDefaultKey(cmd, cur)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.layoutSpecialDefault = GearInsightDB.layoutSpecialDefault or {}
    local st = GearInsightDB.layoutSpecialDefault
    local set = GearInsightDB.layoutSpecial and GearInsightDB.layoutSpecial[cmd]
    if cur == nil then cur = GetBindingKey(cmd) end
    if cur and cur ~= "" and not set and st[cmd] == nil then st[cmd] = cur end
    return st[cmd]
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
    -- ⓪ 用户在「系统键」里设过的键（回复密语 / 信号…）先占住：快照里某技能原来绑 Shift-R、后来 Shift-R 给了回复对话，
    --   快照沿用会把 Shift-R 再分给那格 → 设绑定时特殊键最后压过去，那格永远「未生效」（09-20 用户 格51 s-R）
    for _, k in pairs((GearInsightDB and GearInsightDB.layoutSpecial) or {}) do if k and k ~= "" then used[k] = true end end
    -- ① 用户手动改过的先占
    for _, p in ipairs(slots) do
        local v = st[identOf(p) or ("k" .. p.slot)]
        if v == nil then v = st[p.slot] end   -- 老存档按格号存的，兼容读
        if v then out[p.slot] = v; used[v] = true end
    end
    local function manual(p) local v = st[identOf(p) or ("k" .. p.slot)]; if v == nil then v = st[p.slot] end return v end
    -- ①' 右键换过行的技能：换行前的键跟着技能走（不管它被排到哪一格）
    local sk = (GearInsightDB and GearInsightDB.layoutSpellKey) or {}
    for _, p in ipairs(slots) do
        local k = p.id and sk[p.id]
        if k and out[p.slot] == nil and not used[k] and manual(p) ~= false then out[p.slot] = k; used[k] = true end
    end
    -- ② 「保留现有键位」模式：现在绑着的键原样留着；「智能换键位」模式：⛔ 不保留，全部按键池顺序重排——
    --    否则 1-5 绑在控制行上也会被当「顺手」留住，主循环反而拿不到（用户 2026-09-18「12345 理论上是最上面那些频繁按的常规按钮」）
    local smart = not GearInsight.KeepKeysMode()
    if not smart then
        -- 现在条上：技能 / 宏 / 物品 → 它所在格的键（快照优先，快照没有就实况）
        local bySpell, byMacro, byItem = {}, {}, {}
        -- 条 6 / 7 / 8（格 145–180）插件不铺，但玩家的技能可能就绑在那儿 → 认键时也扫，键取实况
        local EXTRA = { { 145, 156, "MULTIACTIONBAR5BUTTON" }, { 157, 168, "MULTIACTIONBAR6BUTTON" }, { 169, 180, "MULTIACTIONBAR7BUTTON" } }
        local scan = {}
        for _, bar in ipairs(BARS) do scan[#scan + 1] = { bar.from, bar.to } end
        for _, e in ipairs(EXTRA) do scan[#scan + 1] = e end
        for _, rg in ipairs(scan) do
            for sl = rg[1], rg[2] do
                local info = slotInfo(sl)
                local k = info and (rg[3] and GetBindingKey(rg[3] .. (sl - rg[1] + 1)) or GearInsight.UserKey(sl))
                if info and k and k ~= "" then
                    if info.t == "spell" and info.id then
                        local base = (FindBaseSpellByID and FindBaseSpellByID(info.id)) or info.id
                        if not bySpell[base] then bySpell[base] = k end
                        if not bySpell[info.id] then bySpell[info.id] = k end
                    elseif info.t == "macro" and info.name then
                        if not byMacro[info.name] then byMacro[info.name] = k end
                    elseif info.t == "item" and info.id then
                        if not byItem[info.id] then byItem[info.id] = k end
                    end
                end
            end
        end
        local mn = GearInsight.MacroNameOf
        -- 第一轮：按技能认（技能挪了格也跟着走）。⛔ 进了爆发宏的技能也认：它现在有自己的键就照留
        --   （09-19 用户：灵魂收割现绑滚轮下，因为被并进爆发宏被跳过，最后从修饰键池捡了个 Shift-5）
        for _, p in ipairs(slots) do
            if out[p.slot] == nil and manual(p) ~= false then
                local cur
                if p.id then cur = bySpell[p.id] or bySpell[(FindBaseSpellByID and FindBaseSpellByID(p.id)) or p.id]
                elseif p.macro and mn then cur = byMacro[mn(p)]
                elseif p.item then cur = byItem[p.item] end
                if cur and not used[cur] then out[p.slot] = cur; used[cur] = true end
            end
        end
        -- 第二轮：条上没有这个技能的（新铺的格）才按格号沿用原来那格的键
        for _, p in ipairs(slots) do
            if out[p.slot] == nil and manual(p) ~= false and not p.inMacro then
                local cur = GearInsight.UserKey(p.slot)   -- 个性化快照里的键，不是被智能改过的实况
                if cur and not used[cur] then out[p.slot] = cur; used[cur] = true end
            end
        end
    end
    -- ③ 智能推荐是「粘」的：上次算过的推荐键只要没被手动占走就原样保留，⛔ 不许因为用户改了某一格就把其他格全部顺位重排
    --    （用户 2026-09-18「我设置一个按键的时候，为什么会改其他的按键」「一定不要改之前任何其他按键」）。按专精存进 DB，重载后也稳
    local sticky = smartStore()
    -- 粘性按「技能身份」记，不按格号（09-20 用户「右键换行，其他的按键也不能改」：换一行整排格号后移，按格号记的键全串位）
    local function ident(p) return p.id and ("s" .. p.id) or (p.macro and ("m" .. tostring(GearInsight.MacroNameOf and GearInsight.MacroNameOf(p) or p.macro))) or (p.item and ("i" .. p.item)) or (p.inv and ("v" .. p.inv)) or ("k" .. p.slot) end
    if smart then
        for _, p in ipairs(slots) do
            local prev = sticky[ident(p)]
            if out[p.slot] == nil and manual(p) ~= false and prev and prev ~= "" and not used[prev] and keyFree(prev) then
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
            local low = p.inMacro or p.lowKey
            if ((pass == 1 and not low) or (pass == 2 and low)) and out[p.slot] == nil and manual(p) ~= false then
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
    if smart then
        for k in pairs(sticky) do sticky[k] = nil end
        for _, p in ipairs(slots) do if out[p.slot] then sticky[ident(p)] = out[p.slot] end end
    end
    return out
end
GearInsight._smartKeys = GearInsight._smartKeys or {}
-- 推荐键 = 手动改的 > 智能推荐表 > 现在绑的 > 默认表
function GearInsight.SlotKey(slot)
    local st = keyStore()
    local v = st[slotIdent(slot)]
    if v == nil then v = st[slot] end   -- 老存档兼容
    if v == false then return nil end   -- 用户按 Backspace 清掉的：两种模式都尊重（撞键已不再写 false，所以 false 只来自用户）
    if v then return v end
    local sk = GearInsight._smartKeys[slot]
    if sk == "" then return nil end   -- 智能表明确说这格不绑
    if sk then return sk end
    local cmd = GearInsight.SlotCommand(slot)
    local cur = cmd and GetBindingKey(cmd)   -- 条 6~8 / 形态页没有我们的命令名 → nil，别把 nil 传给 GetBindingKey
    return cur or GearInsight.DefaultKey(slot)
end
function GearInsight.SetSlotKey(slot, key)
    local st = keyStore()
    st[slotIdent(slot)] = key   -- nil = 回默认；false = 不绑；按技能身份存，换行 / 分页后跟着技能走
    st[slot] = nil              -- 老的按格号记录清掉，别再套到别的技能头上
end

-- 按表设置绑定：先把这 60 个命令上现有的键全解掉，再按推荐键绑；同一个键之前绑在别处会被自动挪过来
function GearInsight:ApplyKeyBindings()
    if InCombatLockdown() then self:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
    if GearInsight.InForm and GearInsight.InForm() then self:Print("|cffff8000" .. T("LY_NEED_HUMANOID", "先变回人形再铺：变身时主条 1–12 指向的是当前形态那页，人形页碰不到（暴雪 API 限制）") .. "|r"); return end
    self.EnsureKeySnapshot()   -- 第一次动手前记下用户自己的键位（以后「保留现有键位」= 回到这份）
    self._applyingKeys = true; C_Timer.After(1, function() GearInsight._applyingKeys = nil end)   -- 这段时间的 UPDATE_BINDINGS 是插件自己发的，别当成用户改键
    local slots = self:BuildLayoutPlan()   -- 刷新智能推荐表
    -- 计划里是宏的格：先把宏真建出来放进格子，再绑键——只绑键不建宏，键按下去是空的（用户 2026-09-18「点绑定键位的时候宏不会实现，应该直接实现宏并放到键位」）
    local macroPlaced, macroFail = 0, {}
    -- 09-20 用户「Shift+F 那格没设上，当前是 /gi 的宏，要设置成偏好坐骑」：只绑键不换内容，键是对的、格里东西不对 = 等于没实现。
    --   所以「实现」= 计划里每一格内容也对齐（技能 / 坐骑 / 饰品 / 药水 / 宏），不只是宏；做之前已自动备份，「清空重铺」只多做一件事：清掉计划外的格
    local placed, noPotion = 0, {}
    for _, p in ipairs(slots) do
        local cur = slotInfo(p.slot)
        if self._formBase and p.slot <= 12 then   -- 形态职业：物理主条 1–12 = 人形页，由 MirrorFormBars 铺；计划里的主形态技能去形态页
        elseif not sameAsPlan(cur, p) then
            ClearCursor()
            if p.userMacro then
                local idx = GetMacroIndexByName(p.userMacro)
                if idx and idx > 0 then PickupMacro(idx) end
                if GetCursorInfo() then PlaceAction(p.slot); placed = placed + 1 end
            elseif p.macro then
                local mi = self:EnsureMacroItem(p)
                if mi then PickupMacro(mi) end
                if GetCursorInfo() then PlaceAction(p.slot); macroPlaced = macroPlaced + 1
                else macroFail[#macroFail + 1] = macroNameOf(p) end
            else
                if p.inv then PickupInventoryItem(p.inv)
                elseif p.item then if p.have then PickupItem(p.item) else noPotion[#noPotion + 1] = p.cn or tostring(p.item) end
                elseif p.id == 150544 and C_MountJournal and C_MountJournal.Pickup then C_MountJournal.Pickup(0)
                elseif p.id then PickupSpell(p.id) end
                if GetCursorInfo() then PlaceAction(p.slot); placed = placed + 1 end
            end
            ClearCursor()
        end
    end
    if placed > 0 then self:Print(string.format(T("LY_KEYS_CONTENT_PLACED", "格子内容按计划对齐：换了 %d 格"), placed)) end
    self:MirrorFormBars(true)
    if #noPotion > 0 then self:Print(T("LY_NO_POTION", "包里没有推荐药水，这几格先空着：") .. table.concat(noPotion, "、")) end
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
    local taken, usedKey, replaced, badKeys = {}, {}, {}, {}
    local specialKeys = {}
    for cmd, k in pairs((GearInsightDB and GearInsightDB.layoutSpecial) or {}) do if k and k ~= "" then specialKeys[k] = cmd end end
    for _, bar in ipairs(BARS) do
        for sl = bar.from, bar.to do
            local key = self.SlotKey(sl)
            if key and key ~= "" and specialKeys[key] then
                -- 这个键用户明确给了系统功能：格子让路（置「不绑」），提示一句；否则最后特殊键压回去、这格永远对不上
                replaced[#replaced + 1] = string.format(T("LY_SPECIAL_WINS", "%s：格 %d 让给「%s」"), GetBindingText(key, 1), sl, _G["BINDING_NAME_" .. specialKeys[key]] or specialKeys[key])
                self.SetSlotKey(sl, false); key = nil
            end
            if key and key ~= "" then
                if usedKey[key] then
                    replaced[#replaced + 1] = string.format(T("LY_REPLACED_FMT", "%s：格 %d -> 格 %d"), GetBindingText(key, 1), usedKey[key], sl)
                    self.SetSlotKey(usedKey[key], false)   -- 原来那格置空「不绑」，不自动补键（用户「一定不要改之前任何其他按键」）
                    n = n - 1
                end
                usedKey[key] = sl
                local prev = GetBindingAction(key)
                if prev and prev ~= "" and not isOurCmd(prev) then taken[#taken + 1] = GetBindingText(key, 1) .. "←" .. (_G["BINDING_NAME_" .. prev] or prev) end
                if key == "MIDDLEBUTTON" or key:find("MIDDLEBUTTON", 1, true) then key = key:gsub("MIDDLEBUTTON", "BUTTON3"); self.SetSlotKey(sl, key) end   -- 老存档里的错键名迁移
                if SetBinding(key, self.SlotCommand(sl)) then n = n + 1
                else badKeys[#badKeys + 1] = string.format("%s→%d", key, sl) end   -- SetBinding 会自动把这个键从先前那格解掉；返回 false = 键名不合法，必须报出来
            end
        end
    end
    -- 用户设过的特殊键（回复密语 / 信号）：最后绑，压过格子（撞上的格已在录键时置空）
    for cmd, key in pairs((GearInsightDB and GearInsightDB.layoutSpecial) or {}) do
        if key and key ~= "" then
            local prev = GetBindingAction(key)
            if prev and prev ~= "" and prev ~= cmd then SetBinding(key, nil) end
            SetBinding(key, cmd)
        end
    end
    -- 没设过的系统键：默认键被格子顶掉过、现在又空出来了 → 自动还回默认（用户 2026-09-19「被顶了没自动恢复」）
    local restored = {}
    for cmd, d in pairs((GearInsightDB and GearInsightDB.layoutSpecialDefault) or {}) do
        local set = GearInsightDB.layoutSpecial and GearInsightDB.layoutSpecial[cmd]
        if not set and d and d ~= "" and not GetBindingKey(cmd) then
            local act = GetBindingAction(d)
            if not act or act == "" then SetBinding(d, cmd); restored[#restored + 1] = GetBindingText(d, 1) .. "→" .. (_G["BINDING_NAME_" .. cmd] or cmd) end
        end
    end
    if #restored > 0 then self:Print(T("LY_SP_RESTORED", "系统键还回默认：") .. table.concat(restored, "、")) end
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
    -- 设完还有格没对上 → 逐格说清楚（09-20 用户「点击实现为啥没实现成功」：面板只写「3 格键未生效」，看不出是哪格、被谁占了）
    local miss = {}
    for _, bar in ipairs(BARS) do
        for sl = bar.from, bar.to do
            local cur, rec = GetBindingKey(self.SlotCommand(sl)), self.SlotKey(sl)
            if (cur or "") ~= (rec or "") then
                local holder = rec and GetBindingAction(rec)
                holder = holder and holder ~= "" and (_G["BINDING_NAME_" .. holder] or holder) or nil
                miss[#miss + 1] = string.format(T("LY_KEYS_MISS_FMT", "格%d 应 %s 实 %s%s"), sl, rec and GetBindingText(rec, 1) or T("LY_NONE", "无"), cur and GetBindingText(cur, 1) or T("LY_NONE", "无"),
                    holder and string.format(T("LY_KEYS_MISS_HOLDER", "（%s 现在绑在「%s」）"), GetBindingText(rec, 1), holder) or "")
            end
        end
    end
    if #miss > 0 then self:Print("|cffff8000" .. T("LY_KEYS_MISS", "这些格的键没对上：") .. "|r" .. table.concat(miss, "  ")) end
    if #moved > 0 then self:Print(T("LY_KEYS_MOVE_BACK", "移动键已还回：") .. table.concat(moved, "  ")) end
    if #taken > 0 then self:Print(T("LY_KEYS_TAKEN", "这些键原来绑着别的功能，已被挪到动作条（「保存」页还原可全部改回）：") .. table.concat(taken, "  ")) end
    if macroPlaced > 0 then self:Print(string.format(T("LY_KEYS_MACRO_PLACED", "已建好并放上 %d 个宏格"), macroPlaced)) end
    if #macroFail > 0 then self:Print("|cffff8000" .. T("LY_KEYS_MACRO_FAIL", "这些宏没放上（宏栏满了？）：") .. table.concat(macroFail, "  ") .. "|r") end
    if #replaced > 0 then self:Print("|cffffd100" .. T("LY_KEYS_REPLACED", "撞键，已替换（原来那格现在无快捷键）：") .. table.concat(replaced, "  ") .. "|r") end
    if #badKeys > 0 then self:Print("|cffff5555" .. T("LY_KEYS_BAD", "这些键系统不认、没绑上（点格子重新按一次）：") .. table.concat(badKeys, "  ") .. "|r") end
    if self._layoutRefresh then self._layoutRefresh() end
end

local function placeInto(slot, r)
    ClearCursor()
    if not r then
        PickupAction(slot); ClearCursor(); return true
    end
    if r.t == "spell" then
        if r.sub == "assistedcombat" and C_AssistedCombat and C_AssistedCombat.GetActionSpell then PickupSpell(C_AssistedCombat.GetActionSpell() or r.id)
        elseif r.id == 150544 and C_MountJournal and C_MountJournal.Pickup then C_MountJournal.Pickup(0)   -- 随机偏好坐骑：PickupSpell 拾不起来
        else PickupSpell(r.id) end
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
            if not GetCursorInfo() and C_MountJournal.GetMountInfoByID then   -- 收藏页筛选 / 搜索框把它滤掉了：按坐骑法术拾（格子类型变 spell，功能一样）
                local _, sid = C_MountJournal.GetMountInfoByID(r.id)
                if sid then PickupSpell(sid) end
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

-- ── 形态页（09-20 群友 抖浆糊「德的清空重铺有问题，不同形态动作条 1 不一样」→ 用户「一个姿态对上这个姿态特有的动作条」）──
--   猫 / 猫潜行 / 熊 / 盗贼潜行时主条 1 被换成另一页：猫 73–84、猫潜行 85–96、熊 97–108、盗贼潜行 73–84；键位和主条共用 ACTIONBUTTONn。
--   每页 = 主条 1–12 的副本，但「需要别的形态才能用」的格腾出来，换成「需要这个形态」的技能（计划里在副条上的 + 法术书里只在这个形态能用的，如猫页的潜行）；
--   切成本形态的那格也腾出来（猫页上不需要「猫形态」）。清空重铺 = 整页按此重铺；对齐 / 只填空位 = 只补空格。
local FORM_DEFS = {
    DRUID = { pages = { cat = { 73, "cat" }, prowl = { 85, "cat" }, bear = { 97, "bear" } },
              -- 每个专精都给全部形态页（09-20 用户「为啥只有熊形态」）：主形态排第一，其余页放那个形态的专属技能
              bySpec = { [103] = { "cat", "prowl", "bear" }, [104] = { "bear", "cat", "prowl" } }, default = { "cat", "prowl", "bear" },
              switch = { [768] = "cat", [5487] = "bear" },
              -- 09-20 用户「猫形态只铺猫专属；多形态公用的放公用动作条」：主条 1–12 = 主形态专属（野德猫 / 守护熊），
              --   人形页 = 有读条的施法技能，其余不限形态的全部进条 2~5（公用，变身不换页）
              casterBase = true, mainForm = { [103] = "cat", [104] = "bear" } },
    ROGUE = { pages = { stealth = { 73, "stealth" } }, default = { "stealth" }, switch = { [1784] = "stealth" } },
}
local FORM_LABEL = { cat = T("LY_FORM_CAT", "猎豹形态"), prowl = T("LY_FORM_PROWL", "猎豹 · 潜行"), bear = T("LY_FORM_BEAR", "熊形态"), stealth = T("LY_FORM_STEALTH", "潜行") }
local FORM_WORDS = { cat = { "猎豹形态", "Cat Form", "貓形態", "獵豹形態" }, bear = { "熊形态", "Bear Form", "熊形態" }, stealth = { "潜行", "Stealth", "潛行", "暗影之舞", "Shadow Dance" } }
local formReqCache, formReqTries = {}, {}
-- 技能提示第 2~4 行「需要猎豹形态 / 需要熊形态或猎豹形态 / 需要潜行」→ { cat=true, bear=true } / nil（不限形态）
local scanTip
local function tipLines(id)
    -- 先 C_TooltipInfo；拿不到行（早期加载 / 保密值）再用隐藏 GameTooltip 扫（09-20 用户「人形态还在被分配熊技能」：需要熊形态那行没读到 → 当成不限形态）
    local out = {}
    local ok, data = pcall(function() return C_TooltipInfo and C_TooltipInfo.GetSpellByID and C_TooltipInfo.GetSpellByID(id) end)
    if ok and data and data.lines then
        for li = 1, #data.lines do
            local t = data.lines[li] and data.lines[li].leftText
            if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then out[#out + 1] = t end
            local r = data.lines[li] and data.lines[li].rightText
            if type(r) == "string" and not (issecretvalue and issecretvalue(r)) then out[#out + 1] = r end
        end
    end
    if #out == 0 then
        scanTip = scanTip or CreateFrame("GameTooltip", "GearInsightFormScanTip", nil, "GameTooltipTemplate")
        scanTip:SetOwner(UIParent, "ANCHOR_NONE"); scanTip:ClearLines()
        pcall(scanTip.SetSpellByID, scanTip, id)
        for li = 1, scanTip:NumLines() do
            for _, side in ipairs({ "Left", "Right" }) do
                local fs = _G["GearInsightFormScanTipText" .. side .. li]
                local t = fs and fs:GetText()
                if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then out[#out + 1] = t end
            end
        end
        scanTip:Hide()
    end
    return out
end
function GearInsight.SpellFormReq(id)
    if formReqCache[id] ~= nil then return formReqCache[id] or nil end
    local req = nil
    local lines = tipLines(id)
    for _, txt in ipairs(lines) do
        if txt:find("需要", 1, true) or txt:find("Requires", 1, true) or txt:find("需要", 1, true) then
            for f, words in pairs(FORM_WORDS) do
                for _, w in ipairs(words) do if txt:find(w, 1, true) then req = req or {}; req[f] = true end end
            end
        end
    end
    -- 提示一行都没读到（技能数据没加载）→ 最多再试 2 次就记为「不限形态」，别每次刷新都扫一遍整本法术书的提示（09-20「姿态行 hang」：卡顿）
    formReqTries[id] = (formReqTries[id] or 0) + 1
    if #lines > 0 or formReqTries[id] >= 3 then formReqCache[id] = req or false end
    return req
end
-- 形态职业的分页路由：返回 function(item) → "main"（主条 1–12）/ "base"（人形施法页）/ "shared"（条 2~5）/ 形态键（只在那页）；非形态职业返回 nil
function GearInsight.FormRouting()
    local _, cls = UnitClass("player"); local d = FORM_DEFS[cls]
    if not (d and d.casterBase) then return nil end
    local idx = GetSpecialization and GetSpecialization(); local specID = idx and GetSpecializationInfo(idx)
    local mainForm = d.mainForm and d.mainForm[specID]
    local pages = {}
    for _, k in ipairs((d.bySpec and d.bySpec[specID]) or d.default) do pages[d.pages[k][2]] = true end
    return function(it)
        if not it.id or it.macro or it.inv or it.item or it.id == 150544 or it.role == "inv" then return "shared" end   -- 宏 / 饰品 / 药水 / 坐骑：公用（09-20「坐骑 60 格放不下」：坐骑有读条被判成人形页）
        if d.switch and d.switch[it.id] then return "shared" end                      -- 切形态本身：哪个形态都要按得到
        local r = GearInsight.SpellFormReq(it.id)
        if r then
            local only, n = nil, 0
            for f in pairs(r) do only = f; n = n + 1 end
            if n == 1 then
                if only == mainForm then return "main" end
                if pages[only] then return only end
            end
            return "shared"                                                            -- 两个以上形态能用 → 公用
        end
        if not mainForm then return "main" end                                         -- 平衡 / 恢复：不限形态的照常上主条
        if formReqCache[it.id] == nil then return "shared" end                          -- 提示还没读到，不敢判：先放公用条
        local info = C_Spell.GetSpellInfo(it.id)
        if info and (info.castTime or 0) > 0 then return "base" end                    -- 有读条 = 人形施法 → 人形页
        return "shared"
    end, mainForm
end
function GearInsight.FormPages()
    local _, cls = UnitClass("player")
    local d = FORM_DEFS[cls]; if not d then return {} end
    local idx = GetSpecialization and GetSpecialization()
    local specID = idx and GetSpecializationInfo(idx)
    local out = {}
    for _, k in ipairs((d.bySpec and d.bySpec[specID]) or d.default) do local pg = d.pages[k]; out[#out + 1] = { key = k, base = pg[1], req = pg[2], label = FORM_LABEL[k] or k, switch = d.switch } end
    return out
end
-- slots = BuildLayoutPlan 的 60 格；返回 { {key,base,label,req, slots={[1..12]=item}} ... }
function GearInsight:BuildFormPagePlans(slots, groups)
    local pages = self.FormPages(); if #pages == 0 then self._formPlans = {}; self._formBase = nil; return {} end
    -- ⛔ 不能写 `x and f()`：and 只留 f() 的第一个返回值，mainForm 永远 nil（09-20 守护德「人形态还是熊的技能」根因）
    local route, mainForm
    if self.FormRouting then route, mainForm = self.FormRouting() end
    if route then
        -- 野德 / 守护：主条 1–12 的计划项就是主形态页；人形页 = page=="base" 的施法技能；别的形态页 = 那页专属 + 法术书专属
        local main = {}
        for _, it in ipairs(slots) do if it.slot and it.slot >= 1 and it.slot <= 12 then main[it.slot] = it end end
        local byPage = {}
        for _, g in ipairs(groups or {}) do for _, it in ipairs(g.items) do if it.page and it.page ~= "main" and it.page ~= "shared" and not it.off then byPage[it.page] = byPage[it.page] or {}; table.insert(byPage[it.page], it) end end end
        local out = {}
        local basePg = { key = "base", base = 1, req = "base", label = T("LY_FORM_BASE", "人形（施法）"), slots = {} }
        local free = self._freeSlots or {}
        local function spill(it)   -- 页上放不下 → 剩余的公用格 / 主条空格；真没有才算放不下
            local sl = table.remove(free, 1)
            if sl then it.slot = sl; it.page = "shared"; slots[#slots + 1] = it; return true end
            return false
        end
        local bl = byPage.base or {}
        for i = 1, math.min(12, #bl) do basePg.slots[i] = bl[i]; bl[i].formSlot = i end
        basePg.dropped = 0
        for i = 13, #bl do if not spill(bl[i]) then basePg.dropped = basePg.dropped + 1 end end
        basePg.label = T("LY_FORM_BASE", "人形（施法）") .. " · " .. T("LY_FORM_SECONDARY", "副形态")
        for _, pg in ipairs(pages) do
            pg.slots = {}
            if pg.req == mainForm then
                for i = 1, 12 do pg.slots[i] = main[i] end
                pg.dropped = 0
            else
                local used, cand = {}, {}
                for _, it in ipairs(byPage[pg.req] or {}) do if it.id and not used[it.id] then cand[#cand + 1] = it; used[it.id] = true end end
                self._bookCache = self._bookCache or {}
                local bookIds = self._bookCache.t and (GetTime() - self._bookCache.t < 5) and self._bookCache.ids or bookSpells()
                self._bookCache.ids, self._bookCache.t = bookIds, GetTime()   -- 法术书列表 5 秒内复用（每次刷新都翻整本太卡）
                for _, bid in ipairs(bookIds or {}) do
                    if type(bid) == "number" and not used[bid] then
                        local r = self.SpellFormReq(bid); local n = 0; for _ in pairs(r or {}) do n = n + 1 end
                        if r and n == 1 and r[pg.req] then cand[#cand + 1] = { id = bid, role = "form", why = T("LY_WHY_FORM_ONLY", "本形态专属"), page = pg.req }; used[bid] = true end
                    end
                end
                for i = 1, math.min(12, #cand) do pg.slots[i] = cand[i]; cand[i].formSlot = i end
                pg.dropped = 0
                for i = 13, #cand do if not (cand[i].role ~= "form" and spill(cand[i])) then pg.dropped = pg.dropped + 1 end end   -- 法术书补的专属不溢，计划里的溢
            end
            if pg.req == mainForm then pg.label = pg.label .. " · " .. T("LY_FORM_PRIMARY", "主形态 · 主条键位 1–5 起") end
            out[#out + 1] = pg
        end
        table.sort(out, function(a, b) local ra, rb = (a.req == mainForm) and 0 or 1, (b.req == mainForm) and 0 or 1; return ra < rb end)
        if mainForm then out[#out + 1] = basePg end   -- 人形 = 副形态，排最后；平衡 / 恢复没有主形态：主条本身就是人形，不另出
        self._formPlans = out; self._formBase = mainForm and basePg or nil
        return out
    end
    self._formBase = nil
    local main = {}
    for _, it in ipairs(slots) do if it.slot and it.slot >= 1 and it.slot <= 12 then main[it.slot] = it end end
    local function needs(it, f) if not it or not it.id then return false end local r = self.SpellFormReq(it.id); return r and r[f] or false end
    local function otherForm(it, f) if not it or not it.id then return false end local r = self.SpellFormReq(it.id); return r and not r[f] or false end
    for _, pg in ipairs(pages) do
        local f = pg.req
        local out, used = {}, {}
        for i = 1, 12 do
            local it = main[i]
            if it and not otherForm(it, f) and not (it.id and pg.switch and pg.switch[it.id] == f) then out[i] = it; if it.id then used[it.id] = true end end
        end
        -- 候选：计划里任何格上「需要本形态」的技能（主条上已在的不重复）+ 法术书里需要本形态且不在计划里的（猫页的潜行这种）
        local cand = {}
        for _, it in ipairs(slots) do if it.id and not used[it.id] and needs(it, f) then cand[#cand + 1] = it; used[it.id] = true end end
        for _, bid in ipairs(bookSpells() or {}) do   -- bookSpells 回的是 spellID 列表
            if type(bid) == "number" and not used[bid] and needs({ id = bid }, f) then cand[#cand + 1] = { id = bid, role = "form", why = T("LY_WHY_FORM_ONLY", "本形态专属") }; used[bid] = true end
        end
        local ci = 1
        for i = 1, 12 do if not out[i] and cand[ci] then out[i] = cand[ci]; ci = ci + 1 end end
        pg.slots = out; pg.dropped = #cand - (ci - 1)
    end
    self._formPlans = pages
    return pages
end
function GearInsight:MirrorFormBars(fillOnly)
    local pages = self._formPlans or self:BuildFormPagePlans(self:BuildLayoutPlan())
    if #pages == 0 then return 0 end
    if GearInsight.InForm() then self:Print("|cffff8000" .. T("LY_NEED_HUMANOID", "先变回人形再铺：变身时主条 1–12 指向的是当前形态那页，人形页碰不到（暴雪 API 限制）") .. "|r"); return 0 end
    local n = 0
    for _, pg in ipairs(pages) do
        for i = 1, 12 do
            local want, dst = pg.slots[i], slotInfo(pg.base + i - 1)
            if want then
                if not sameAsPlan(dst, want) and (not fillOnly or not dst) then
                    ClearCursor()
                    if want.userMacro then local mi = GetMacroIndexByName(want.userMacro); if mi and mi > 0 then PickupMacro(mi) end
                    elseif want.macro then local mi = self:EnsureMacroItem(want); if mi then PickupMacro(mi) end
                    elseif want.inv then PickupInventoryItem(want.inv)
                    elseif want.item then if want.have then PickupItem(want.item) end
                    elseif want.id then PickupSpell(want.id) end
                    if GetCursorInfo() then PlaceAction(pg.base + i - 1); n = n + 1 end
                    ClearCursor()
                end
            elseif dst and not fillOnly then
                PickupAction(pg.base + i - 1); ClearCursor(); n = n + 1
            end
        end
    end
    if n > 0 then self:Print(string.format(T("LY_FORM_MIRROR", "形态页动作条已按形态铺好：%d 格（猫 / 熊 / 潜行时看到的那条，键位与主条共用）"), n)) end
    return n
end
function GearInsight:RestoreBars(snap)
    if InCombatLockdown() then self:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
    if GearInsight.InForm and GearInsight.InForm() then self:Print("|cffff8000" .. T("LY_NEED_HUMANOID", "先变回人形再铺：变身时主条 1–12 指向的是当前形态那页，人形页碰不到（暴雪 API 限制）") .. "|r"); return end
    -- 动作条是按专精分的：A 专精的备份铺到 B 专精上只会一片红（用户 2026-09-18 同意拦）
    local specIdx = GetSpecialization and GetSpecialization()
    local curSpec = specIdx and select(2, GetSpecializationInfo(specIdx))
    if snap.spec and curSpec and snap.spec ~= curSpec then
        self:Print(string.format(T("LY_RESTORE_SPEC", "这份备份是「%s」专精的，你现在是「%s」——先切回那个专精再还原"), snap.spec, curSpec)); return
    end
    if snap.char and snap.char ~= UnitName("player") then
        self:Print(string.format(T("LY_RESTORE_CHAR", "这份备份是角色「%s」的，不铺到「%s」上"), snap.char, UnitName("player"))); return
    end
    -- 先把宏本身改回（09-21 用户「保存复位以后宏变了」）：正文 / 图标和存的时候不一样 → 改回；被删了 → 按存的正文重建。
    --   宏还原完再放格子，格子上引用的才是那份宏（老快照没有 macros 字段：照旧只按名字找）
    local mFixed, mMade, mFail = 0, 0, {}
    for name, m in pairs(snap.macros or {}) do
        local idx = GetMacroIndexByName(name)
        if idx and idx > 0 then
            local _, icon, body = GetMacroInfo(idx)
            if (body or "") ~= (m.body or "") or (m.icon and icon ~= m.icon) then EditMacro(idx, name, m.icon or icon, m.body or ""); mFixed = mFixed + 1 end
        else
            local nGlobal, nChar = GetNumMacros()
            local perChar = m.perChar and true or false
            if perChar and (nChar or 0) >= 18 then perChar = false end
            if not perChar and (nGlobal or 0) >= 120 then perChar = (nChar or 0) < 18 end
            if (perChar and (nChar or 0) >= 18) or (not perChar and (nGlobal or 0) >= 120) then mFail[#mFail + 1] = name
            elseif CreateMacro(name, m.icon or "INV_Misc_QuestionMark", m.body or "", perChar) then mMade = mMade + 1
            else mFail[#mFail + 1] = name end
        end
    end
    if mFixed + mMade > 0 then self:Print(string.format(T("LY_RESTORED_MACROS", "宏也改回：%d 个正文改回存的那份，%d 个被删的已重建"), mFixed, mMade)) end
    if #mFail > 0 then self:Print("|cffff8000" .. T("LY_RESTORED_MACRO_FAIL", "这些宏没法重建（宏栏满了：角色 18 / 通用 120）：") .. table.concat(mFail, "  ") .. "|r") end
    local ok, skip, skipped = 0, 0, {}
    for i = 1, MAX_SLOT do
        local r = snap.slots[i]
        local cur = slotInfo(i)
        local same = (r == nil and cur == nil) or (r and cur and r.t == cur.t and (r.id == cur.id or (r.t == "macro" and r.name == cur.name)
            or (r.sub == "assistedcombat" and cur.sub == "assistedcombat")))   -- 循环助手那格：存的技能 id 随天赋 / 推荐变，两边都是助手就是同一格
        if not same then
            if placeInto(i, r) then ok = ok + 1
            else
                skip = skip + 1
                local what = r and (r.t == "macro" and (T("LY_MACRO_WORD", "宏") .. "「" .. tostring(r.name) .. "」") or r.t == "spell" and ((C_Spell.GetSpellInfo(r.id) or {}).name or r.id)
                    or r.t == "summonmount" and T("LY_LEG_MOUNT", "坐骑") .. "#" .. tostring(r.id) or r.t) or "?"
                skipped[#skipped + 1] = string.format(T("LY_SLOT_FMT", "格%d %s"), i, tostring(what))
            end
        end
    end
    if #skipped > 0 then self:Print("|cffff8000" .. T("LY_RESTORE_SKIPPED", "没放回去的：") .. table.concat(skipped, "  ") .. "|r") end
    if snap.binds then
        -- 全量：先解掉现在所有命令上的键，再按快照绑回（快照里没有的命令就保持空）
        for i = 1, GetNumBindings() do
            local cmd = GetBinding(i)
            if cmd then
                for _, k in ipairs({ select(3, GetBinding(i)) }) do if k and k ~= "" then SetBinding(k, nil) end end   -- 全部键都解（不止前两个）
            end
        end
        for cmd, b in pairs(snap.binds) do
            for _, k in ipairs(b) do SetBinding(k, cmd) end
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
-- WCL / 起手序列里记的 ID 有时是效果 ID 或另一版本，法术书里同名的那条才是你会的 → 按名字换成你会的 ID
local function resolveKnown(id)
    if not id then return nil end
    if known(id) then return id end
    local nm = C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    local info = nm and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(nm)
    if info and info.spellID and info.spellID ~= id and known(info.spellID) then return info.spellID end
    return nil
end

-- 法术书里已学、主动、本专精的技能（不含被动 / 其他专精）
bookSpells = function()
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
    { "form",      T("LY_ROLE_FORM", "姿态 / 形态"), T("LY_ROLE_FORM_D", "变身、姿态、光环切换；铺在主条同位，变身后各页都有（09-20 用户「姿态有单独一栏」）") },
    { "raid",      T("LY_ROLE_RAID", "团队工具"), T("LY_ROLE_RAID_D", "给队友的减伤 / 增益 / 嗜血") },
    { "dispel",    T("LY_ROLE_DISPEL", "驱散"),     "" },
    { "summon",    T("LY_ROLE_SUMMON", "召唤"),     "" },
    { "util",      T("LY_ROLE_UTIL", "功能"),     T("LY_ROLE_UTIL_D", "不打不奶的主动技能：水上行走、变形、开锁…") },
    { "dps",       T("LY_ROLE_DPS", "其他输出"), T("LY_ROLE_DPS_D", "不在主循环里的短 CD 输出技能") },
    { "skip",      T("LY_ROLE_SKIP", "不进动作条"), T("LY_ROLE_SKIP_D", "你右键标过「不进动作条」的：永远不铺、不占格、不分键") },
    { "inv",       T("LY_ROLE_INV", "坐骑"),     T("LY_ROLE_INV_D", "随机偏好坐骑；主动饰品按效果并进爆发 / 减伤 / 治疗行") },
}
local ROLE_LABEL = {}
-- 「来源/职能」内部标记一律用简中 token 比较（"起手"/"嘲讽"…），显示时经 whyText 翻译——别在比较处改 token
local WHY_LOC = {
    ["起手"] = T("LY_WHY_OPENER", "起手"), ["天赋"] = T("LY_WHY_TALENT", "天赋"), ["PvP 天赋"] = T("LY_WHY_PVP", "PvP 天赋"),
    ["法术书"] = T("LY_WHY_BOOK", "法术书"), ["种族"] = T("LY_WHY_RACIAL", "种族"), ["通用"] = T("LY_WHY_GENERAL", "通用"), ["嘲讽"] = T("LY_WHY_TAUNT", "嘲讽"),
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

-- 右键技能格：把这个技能挪到别的职能行（用户自定义，按技能 ID 存，压过一切自动判断）
function GearInsight.ShowRoleMenu(anchor, spellID)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then GearInsight:Print(T("LY_ROLE_MENU_NA", "这个客户端没有菜单接口")); return end
    GearInsightDB = GearInsightDB or {}; GearInsightDB.layoutRoleOverride = GearInsightDB.layoutRoleOverride or {}
    local cur = GearInsightDB.layoutRoleOverride[spellID]
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle((C_Spell.GetSpellName(spellID) or tostring(spellID)) .. "  ·  " .. T("LY_ROLE_MENU_TITLE", "放到哪一行"))
        for _, r in ipairs(ROLE_ORDER) do
            if r[1] ~= "inv" and r[1] ~= "skip" then   -- 「不进动作条」单独放在分隔线下面
                root:CreateRadio(r[2], function() return cur == r[1] end, function()
                    -- 换行只是换行，键不动（09-20 用户「右键改分区，不要改变键位」）：记下它现在的键，分键时按技能优先给回它
                    GearInsightDB.layoutSpellKey = GearInsightDB.layoutSpellKey or {}
                    if not GearInsightDB.layoutSpellKey[spellID] then
                        local k
                        for _, pl in ipairs(GearInsight._lastPlan or {}) do if pl.id == spellID and pl.slot then k = GearInsight.SlotKey(pl.slot) end end
                        if k then GearInsightDB.layoutSpellKey[spellID] = k end
                    end
                    GearInsightDB.layoutRoleOverride[spellID] = r[1]
                    GearInsight:Print(string.format(T("LY_ROLE_SET", "%s → 「%s」行（右键可改回）"), C_Spell.GetSpellName(spellID) or "?", r[2]))
                    if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
                end)
            end
        end
        root:CreateDivider()
        root:CreateRadio(T("LY_ROLE_SKIP", "不进动作条"), function() return cur == "skip" end, function()
            GearInsightDB.layoutRoleOverride[spellID] = "skip"
            GearInsight:Print(string.format(T("LY_ROLE_SKIP_SET", "%s → 不进动作条（右键可改回）"), C_Spell.GetSpellName(spellID) or "?"))
            if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
        end)
        root:CreateButton(T("LY_ROLE_RESET", "恢复自动判断"), function()
            GearInsightDB.layoutRoleOverride[spellID] = nil
            if GearInsightDB.layoutSpellKey then GearInsightDB.layoutSpellKey[spellID] = nil end
            if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
        end)
    end)
end
-- 起手序列自定义（09-20 群友：战士起手两个冲锋，有的环境用不上第二个，高亮就卡住）：
--   按「序列 key（团本/大米|玩家|服务器）+ 原序列里的第几步」记「删掉」，钉板 / 手法页都按它过滤；右键格子删 / 恢复，左键钉板格子直接跳到那一步
function GearInsight.TacticSkip(key)
    GearInsightDB = GearInsightDB or {}; GearInsightDB.tacticSkip = GearInsightDB.tacticSkip or {}
    if not key then return {} end
    GearInsightDB.tacticSkip[key] = GearInsightDB.tacticSkip[key] or {}
    return GearInsightDB.tacticSkip[key]
end
function GearInsight.ShowSeqStepMenu(anchor, key, rawIdx, spellID, hudIdx)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then GearInsight:Print(T("LY_ROLE_MENU_NA", "这个客户端没有菜单接口")); return end
    if not key or not rawIdx then return end
    local skip = GearInsight.TacticSkip(key)
    local function repin()
        local tp = GearInsightDB.tacticPinned
        if tp and tp.key == key and tp.seq and #tp.seq > 0 then GearInsight:PinTacticBoard(tp.title, tp.seq, tp.key) end
        if GearInsight._rotRefresh then GearInsight._rotRefresh() end
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(string.format("%d. %s", rawIdx, C_Spell.GetSpellName(spellID) or tostring(spellID)))
        if hudIdx then
            root:CreateButton(T("LY_SEQ_MENU_JUMP", "跳到这一步（不改序列）"), function()
                local f = _G.GearInsightTacticBoard; if f then f._cur = hudIdx; f:Redraw() end
            end)
        end
        if skip[rawIdx] then
            root:CreateButton(T("LY_SEQ_MENU_RESTORE", "恢复这一步"), function() skip[rawIdx] = nil; repin() end)
        else
            root:CreateButton(T("LY_SEQ_MENU_DEL", "删掉这一步（这个序列会记住）"), function()
                skip[rawIdx] = true
                GearInsight:Print(string.format(T("LY_SEQ_DEL_MSG", "起手序列第 %d 步「%s」已删掉；右键格子可恢复"), rawIdx, C_Spell.GetSpellName(spellID) or "?"))
                repin()
            end)
        end
        local n = 0; for _ in pairs(skip) do n = n + 1 end
        if n > 0 then
            root:CreateDivider()
            root:CreateButton(string.format(T("LY_SEQ_MENU_RESTORE_ALL", "恢复全部删掉的步骤（%d）"), n), function() wipe(skip); repin() end)
        end
    end)
end
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
-- 玩家自己写的宏（鼠标指向 / 焦点 / 条件宏，名字不带 GI 前缀）里 /cast 的技能 → 那个宏就代表这个技能（09-20 用户「宏里已经有了，可以关联吗？鼠标指向宏」）：
--   计划格放这个宏而不是裸技能，键给宏；条上没有它就当成「已铺」。按基础 ID 记，第一个匹配的宏优先
function GearInsight.UserMacroMap()
    local map = {}
    for sl = 1, MAX_SLOT do
        local r = slotInfo(sl)
        if r and r.t == "macro" and r.name and r.name ~= "" and not tostring(r.name):match("^GI") then
            local idx = GetMacroIndexByName(r.name)
            local body = idx and idx > 0 and select(3, GetMacroInfo(idx)) or ""
            -- 一个宏只代表「第一个 /cast 的技能」（09-20 用户「为啥一铺有 4 个」：多技能宏被 4 个技能各认一次，条上铺了 4 份）
            local first
            for line in (body or ""):gmatch("[^\n]+") do
                local cmd, rest = line:match("^/(%S+)%s*(.*)$")
                if cmd == "cast" or cmd == "use" or cmd == "castsequence" then
                    rest = rest:gsub("%[.-%]", ""):gsub("reset=%S+", ""):gsub("^%s+", "")
                    for raw in rest:gmatch("[^,;]+") do
                        local nm = raw:gsub("^%s+", ""):gsub("%s+$", "")
                        local sp = nm ~= "" and C_Spell.GetSpellInfo(nm)
                        if sp and sp.spellID then first = sp.spellID; break end
                    end
                end
                if first then break end
            end
            if first then
                local base = (FindBaseSpellByID and FindBaseSpellByID(first)) or first
                if not map[base] then map[base] = { name = r.name, idx = idx, slot = sl } end
                if not map[first] then map[first] = map[base] end
            end
        end
    end
    return map
end
sameAsPlan = function(r, p)
    if not r and not p then return true end
    if not (r and p) then return false end
    if p.userMacro then return r.t == "macro" and r.name == p.userMacro end
    if p.id and r.t == "spell" and (r.id == p.id or (FindBaseSpellByID and FindBaseSpellByID(r.id) == p.id)) then return true end
    if p.id == 150544 and r.t == "summonmount" then return true end
    if p.inv and r.t == "item" then return true end
    if p.item and r.t == "item" and r.id == p.item then return true end
    if p.macro and r.t == "macro" and r.name == macroNameOf(p) then return true end
    return false
end
GearInsight.SameAsPlan = sameAsPlan
function GearInsight:BuildLayoutPlan()
    local key, R = specKey()
    local items, used, notes = {}, {}, {}
    local NEVER = { [6603] = true, [88163] = true, [150544] = true }  -- 自动攻击 / 攻击 / 坐骑（坐骑单独放）
    local function baseOf(id) return (FindBaseSpellByID and FindBaseSpellByID(id)) or id end
    local function add(id, why, force)
        if not id or NEVER[id] then return end
        if not force and not known(id) then id = resolveKnown(id); if not id then return end end
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
        -- 通用页里只有职能表认得的才是种族技能；其余（进阶传送、活动技能…）标「通用」，别再冒充种族（09-20 用户「这都不是种族技能」）
        local isRacial = RACIAL_ROLE[id] ~= nil
        local it = add(id, isRacial and "种族" or "通用", true)
        if it then racialSet[it.id] = true; it.racial = isRacial or nil; it.general = (not isRacial) or nil; if RACIAL_ROLE[id] then it.role = RACIAL_ROLE[id] end end
    end
    -- ⑤ 职能：主循环 > 表里的职能 > 爆发（基础 CD ≥ 45s）> 其他输出
    local roles = _G.GearInsightSpellRoles or {}
    local userRole = (GearInsightDB and GearInsightDB.layoutRoleOverride) or {}
    local umEarly = GearInsight.UserMacroMap and GearInsight.UserMacroMap() or {}   -- 有你自己的宏代表的技能：「不进动作条」不作用（宏得留着）
    for _, it in ipairs(items) do
        it.talent = talentSet[it.id] or nil
        -- 手动指定的行只管裸技能：宏（宏库 / GI 宏 / 你自己的宏）带着同一个技能 ID，别跟着技能进停车场或换行（09-20 用户「技能进去，宏别进」）
        if coreSet[it.id] then it.role = "core"
        elseif it.role then -- 种族表已给
        elseif roles[it.id] then it.role = roles[it.id]
        else
            -- 表里没有的：客户端描述里既不提伤害也不提治疗 → 功能类（冰霜之路这种表外的）；否则按基础 CD 分爆发/其他输出
            local desc = (C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(it.id)) or ""
            local dl = desc:lower()
            -- 表外技能（黑暗命令这种基础技能不在天赋表里）：先按描述判嘲讽 / 打断 / 解控
            -- 复活类绝不按 CD 判爆发（09-20 用户）：战复 = 团队工具，脱战复活 = 功能
            if (desc:find("复活", 1, true) or desc:find("起死回生", 1, true) or desc:find("复生", 1, true) or dl:find("resurrect", 1, true) or dl:find("back to life", 1, true)) then
                it.role = (desc:find("战斗中", 1, true) or dl:find("in combat", 1, true)) and "raid" or "util"
            elseif desc:find("嘲讽", 1, true) or desc:find("攻击你", 1, true) or desc:find("威胁值提高", 1, true) or dl:find("taunt", 1, true) or dl:find("attack you", 1, true) then
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
        -- 自动职能先记下（宏归行只看这个）；手动指定的行只管这一个裸技能——任何操作都是单一的（09-21 用户：枯萎凋零技能挪走，宏不许跟着动）
        it.autoRole = it.role
        if it.id and userRole[it.id] and not it.macro then it.role = userRole[it.id]; it.userRole = true end
    end
    -- 宏库（core/MacroLib.lua ← 站点各专精宏，Icy Veins / Method 12.1）：勾选的进安排池，按第一个技能的职能归行（用户 2026-09-18）
    local spellRole = {}
    for _, it in ipairs(items) do if it.id then spellRole[it.id] = it.autoRole or it.role end end   -- 宏归行只看技能的自动职能，不跟手动挪的行
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
        -- 顶尖玩家真在按的（WCL 有频率 / 出现在起手序列里）不能落进默认不上条的「其他输出」行：进主循环行，保留「起手」标
        --   （2026-09-19 用户：灵魂收割在 Xequella 起手里，却因为职能=dps 被放进关着的行，条上一直没有）
        if it.id and it.role == "dps" and (it.cpm or it.why == "起手" or (it.why and it.why:find("WCL", 1, true))) then it.role = "core" end
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
    local route = GearInsight.FormRouting and GearInsight.FormRouting()
    local kS, kB = 13, 0   -- 形态职业：公用条游标（allSlots 第 13 个起 = 条 2~5）；人形页计数，超 12 的溢到公用条
    for _, g in ipairs(groups) do
        g.on = g.key ~= "skip" and GearInsight.GroupOn(g.key)
        for _, it in ipairs(g.items) do
            it.page = nil; it.formSlot = nil
            if g.key == "skip" then it.slot = nil; it.off = true   -- 标过「不进动作条」的：永远不铺（09-20 用户）
            elseif not g.on and not it.macro and not it.inv and not it.item then it.slot = nil; it.off = true   -- 整行折叠：不占格（宏 / 饰品 / 药水照放）
            elseif route then
                local page = route(it)
                if page == "base" then kB = kB + 1; if kB > 12 then page = "shared" end end
                it.page = page
                if page == "main" then
                    if k <= 12 then it.slot = allSlots[k]; k = k + 1; slots[#slots + 1] = it
                    elseif allSlots[kS] then it.slot = allSlots[kS]; kS = kS + 1; slots[#slots + 1] = it
                    else it.slot = nil; dropped = dropped + 1 end
                elseif page == "shared" then
                    if allSlots[kS] then it.slot = allSlots[kS]; kS = kS + 1; slots[#slots + 1] = it
                    elseif k <= 12 then it.slot = allSlots[k]; k = k + 1; slots[#slots + 1] = it   -- 公用条满了 → 主条还有空就用（09-20 用户「格子是够的」）
                    else it.slot = nil; dropped = dropped + 1 end
                else it.slot = nil end   -- 人形页 / 别的形态页专属：不占 60 格，BuildFormPagePlans 按页排，键随同位主条格
            elseif allSlots[k] then it.slot = allSlots[k]; k = k + 1; slots[#slots + 1] = it
            else it.slot = nil; dropped = dropped + 1 end
        end
    end
    for _, g in ipairs(groups) do
        for _, it in ipairs(g.items) do if it.macro and not it.lib then it.groupItems = g.items end end   -- 只有分组宏（爆发/保命）才挂整行；宏库的宏用自己的正文
        -- 进了宏的技能/饰品/药水，键位排最后分（用户「爆发宏中的技能和物品不占主要按钮，用次要的按钮，最后分」）
        if GROUP_MACRO_KEYS[g.key] then for _, it in ipairs(g.items) do if not it.macro then it.inMacro = true end end end
        -- 姿态行不占主要键（09-20 用户「不用主要按钮，比如说 12345」）：和宏里的技能一样，从修饰键段开始挑
        if g.key == "form" then for _, it in ipairs(g.items) do it.lowKey = true end end
    end
    local um, umUsed = GearInsight.UserMacroMap(), {}
    for _, it in ipairs(slots) do
        it.userMacro = nil
        if it.id and not it.macro then
            local u = um[it.id] or um[(FindBaseSpellByID and FindBaseSpellByID(it.id)) or it.id]
            if u and not umUsed[u.name] then it.userMacro = u.name; umUsed[u.name] = true end   -- 一个宏只占一格
        end
    end
    -- 形态页先排（放不下的溢到剩余公用格 / 主条空格），再分键
    GearInsight._freeSlots = {}
    if route then
        for i = kS, #allSlots do GearInsight._freeSlots[#GearInsight._freeSlots + 1] = allSlots[i] end
        for i = k, 12 do GearInsight._freeSlots[#GearInsight._freeSlots + 1] = allSlots[i] end
    end
    do
        local ok, err = pcall(GearInsight.BuildFormPagePlans, GearInsight, slots, groups)
        GearInsight._formErr = (not ok) and tostring(err) or nil
        if not ok then
            GearInsight._formPlans = {}; GearInsight._formBase = nil
            GearInsight:Print("|cffff4040" .. T("LY_FORM_ERR", "形态页计划出错（已退回不分页）：") .. "|r" .. tostring(err))
        end
    end
    GearInsight._smartKeys = GearInsight.SmartKeys(slots)
    GearInsight._lastPlan = slots; GearInsight._lastGroups = groups
    wipe(GearInsight._slotIdent)
    for _, p in ipairs(slots) do if p.slot then GearInsight._slotIdent[p.slot] = identOf(p) or ("k" .. p.slot) end end
    local nCore = #(byRole.core.items)
    return slots, { core = nCore, total = #items, dropped = dropped, key = key, notes = notes, groups = groups }
end

-- mode = "fill"（只填空位）| "rebuild"（清空重铺）
-- ⛔ 暴雪 API：格 1–12 永远指「主条当前显示的那页」——变熊时 PickupAction(5) / PlaceAction(5) / GetActionInfo(5) 动的是熊页（97–108），
--   人形页根本碰不到（09-20 用户「重铺完了人形态还是熊的技能」：在熊形态下重铺，人形页内容其实写进了熊页，/gikm 看到 5 和 102 是同一格）。
--   所以铺条 / 实现必须在人形（无 bonus bar）下做；变了身就拦住提示。
function GearInsight.InForm()
    local off = GetBonusBarOffset and GetBonusBarOffset() or 0
    return off and off > 0
end
local function needHumanoid(self)
    if GearInsight.InForm() then self:Print("|cffff8000" .. T("LY_NEED_HUMANOID", "先变回人形再铺：变身时主条 1–12 指向的是当前形态那页，人形页碰不到（暴雪 API 限制）") .. "|r"); return true end
    return false
end
function GearInsight:ApplyLayout(mode)
    if InCombatLockdown() then self:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
    if needHumanoid(self) then return end
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
            if self._formBase and p.slot <= 12 then -- 主条 1–12 交给形态页逻辑
            elseif p.inv then PickupInventoryItem(p.inv)
            elseif p.item then if p.have then PickupItem(p.item) else noPotion[#noPotion + 1] = p.cn or tostring(p.item) end
            elseif p.userMacro then local idx = GetMacroIndexByName(p.userMacro); if idx and idx > 0 then PickupMacro(idx) end
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
        for _, bar in ipairs(BARS) do for s = bar.from, bar.to do if not slotInfo(s) and not (self._formBase and s <= 12) then empties[#empties + 1] = s end end end
        local e = 1
        for _, p in ipairs(slots) do
            if self._formBase and p.slot and p.slot <= 12 then -- 形态页处理
            elseif p.id and (p.userMacro or isOnBar(p.id)) then kept = kept + 1
            elseif p.inv or p.item or p.macro then -- 饰品 / 药水 / 宏只在重铺时放
            elseif empties[e] then
                ClearCursor(); PickupSpell(p.id)
                if GetCursorInfo() then PlaceAction(empties[e]); placed = placed + 1; e = e + 1 end
                ClearCursor()
            end
        end
    end
    self:MirrorFormBars(mode ~= "rebuild")
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
-- 12.x 的 StaticPopup 输入框字段叫 EditBox（旧版 editBox），按钮叫 Button1（旧版 button1）——两种都兼容（用户 2026-09-19「点没用」「无法保存」）
local function popupEdit(dlg) return dlg.EditBox or dlg.editBox or _G[dlg:GetName() .. "EditBox"] end
StaticPopupDialogs["GEARINSIGHT_LAYOUT_RENAME"] = {
    text = "%s", button1 = OKAY, button2 = CANCEL, hasEditBox = true, maxLetters = 40,
    OnShow = function(self, data)
        local eb = popupEdit(self)
        if eb then
            eb:SetText(data and data.snap and data.snap.title or ""); eb:HighlightText()
            C_Timer.After(0, function() if eb:IsShown() then eb:SetFocus() end end)   -- 弹窗显示这一帧焦点会被抢走，下一帧再给（09-19「光标没了」）
        end
    end,
    OnAccept = function(self, data)
        local eb = popupEdit(self)
        local t = eb and (eb:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "") or ""
        if data and data.snap then data.snap.title = (t ~= "") and t or nil end
        if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
    end,
    EditBoxOnEnterPressed = function(self) local p = self:GetParent(); local b = p.button1 or p.Button1 or _G[p:GetName() .. "Button1"]; if b then b:Click() end end,
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
StaticPopupDialogs["GEARINSIGHT_KEYS_LIVE"] = {
    text = T("LY_KEYSLIVE_ASK", "把面板重置成游戏里现在真实绑着的键？\n这会清掉这个专精在面板上手动改过、还没绑到游戏里的键。"),
    button1 = YES, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    OnAccept = function()
        local st = keyStore(); wipe(st)
        local snap = GearInsight.EnsureKeySnapshot(true, false)
        GearInsight:Print(string.format(T("LY_KEYSLIVE_DONE", "已按游戏当前键位重置面板（%s）"), snap._at))
        if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
    end,
}
StaticPopupDialogs["GEARINSIGHT_KEYS_CONFIRM"] = {
    text = T("LY_ASK_KEYS", "按右边的方案实现到动作条：\n① 计划里每一格的内容对齐：技能 / 坐骑 / 饰品 / 药水放进对应格，宏（GI爆发宏 / 保命宏 / 勾选的宏库宏）没有的先建出来；计划外的格不动（要清掉它们点「清空重铺」）；\n② 主条 + 条2~条5 共 60 格按推荐键位重设绑定，之前占用同一个键的功能会被挪走。\n（做之前会自动备份一份，含绑定，可一键还原）"),
    button1 = OKAY, button2 = CANCEL,
    OnAccept = function() if GearInsight.InForm and GearInsight.InForm() then GearInsight:ApplyKeyBindings(); return end GearInsight:SaveLayoutBackup(T("LY_R_KEYS", "设置绑定前"), true); GearInsight:ApplyKeyBindings() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
function GearInsight:SaveLayoutBackup(reason, silent)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.layoutBackups = GearInsightDB.layoutBackups or {}
    local L = GearInsightDB.layoutBackups
    local snap = self:SnapshotBars(reason)
    if not snap then return nil end   -- 变身中：没存（已提示）
    if L[1] and L[1].sig == snap.sig then
        if not silent then self:Print(T("LY_SAME", "和上一份备份一模一样，没重复存")) end
        return L[1]
    end
    -- 这个角色的第一份备份 = 用户装插件前自己的原始键位，默认标永久（09-20 群友 Q&Q「第一次键位保存应该默认永久保存」）：
    --   它是「全部还原」的底，不能被 10 份轮换挤掉；永久位满了才不标
    local first = #L == 0 and not GearInsightDB.layoutFirstPinned
    if first then
        local n, mx = self.CountPinned()
        if n < mx then snap.pinned = true; snap.title = T("LY_FIRST_BK", "原始键位（装插件前）") end
        GearInsightDB.layoutFirstPinned = true
    end
    table.insert(L, 1, snap)
    self.TrimBackups(L)
    if first and snap.pinned then self:Print(T("LY_FIRST_BK_MSG", "第一次备份已标为永久保存「原始键位（装插件前）」，不进轮换、不会被清理；「保存」页可改名 / 取消")) end
    if not silent then self:Print(string.format(T("LY_SAVED", "键位已保存：%s"), self.BackupTitle(snap)))
    else self:Print(string.format(T("LY_AUTOSAVED", "已自动备份：%s（「保存」页可还原）"), self.BackupTitle(snap))) end
    if self._layoutRefresh then self._layoutRefresh() end
    return snap
end
-- 每天第一次登录自动存一份**永久**键位备份（用户 09-21「每天第一次登录，必存一个键位（永久的，名称显著标识）」）：
--   标题「每日存档 09-22」，pinned 但不占 6 份永久名额、只保留最近 3 天（更早的自动清掉）；按角色记当天已存过；
--   变身 / 战斗中存不了就每分钟再试，最多试 10 次；这个模块是按需加载的，只有开着「自动加载」的人登录时才会跑
local MAX_DAILY = 3
function GearInsight:DailyLayoutBackup(tries)
    tries = tries or 0
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.layoutDaily = GearInsightDB.layoutDaily or {}
    local ck = (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or "")
    local today = date("%Y-%m-%d")
    if GearInsightDB.layoutDaily[ck] == today then return end
    if InCombatLockdown() or (GearInsight.InForm and GearInsight.InForm()) then
        if tries < 10 then C_Timer.After(60, function() GearInsight:DailyLayoutBackup(tries + 1) end) end
        return
    end
    local snap = self:SnapshotBars(T("LY_R_DAILY", "每日自动"))
    if not snap then return end
    GearInsightDB.layoutBackups = GearInsightDB.layoutBackups or {}
    local L = GearInsightDB.layoutBackups
    snap.pinned = true; snap.daily = true
    snap.title = string.format(T("LY_DAILY_TITLE", "每日存档 %s"), date("%m-%d"))
    table.insert(L, 1, snap)
    -- 只留最近 MAX_DAILY 份每日存档（按存入顺序，后面的更旧）
    local n = 0
    for i = 1, #L do
        if L[i].daily then n = n + 1 end
    end
    for i = #L, 1, -1 do
        if n <= MAX_DAILY then break end
        if L[i].daily then table.remove(L, i); n = n - 1 end
    end
    GearInsightDB.layoutDaily[ck] = today
    self:Print(string.format(T("LY_DAILY_SAVED", "今天第一次登录，键位已自动存为永久备份「%s」（「保存」页可还原；只保留最近 %d 天）"), snap.title, MAX_DAILY))
    if self._layoutRefresh then self._layoutRefresh() end
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(self, _, isLogin, isReload)
        if not (isLogin or isReload) then return end
        C_Timer.After(8, function() pcall(GearInsight.DailyLayoutBackup, GearInsight) end)   -- 等动作条 / 绑定就绪
    end)
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
GearInsight.MacroNameOf = macroNameOf
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
        -- ⛔ 2026-09-19 用户「爆发宏没有采用最火的药水」：以前包里没药就不写这行 → 宏正文里永远看不到药水。
        --    改为**始终写**：/use 药名 没药时只是静默失败，买了药宏就直接生效，不用重生成。
        if it.item then
            local nm = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(it.item)) or ((_LOCALE == "zhCN" or _LOCALE == "zhTW") and it.cn) or nil
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
        -- 虚拟键盘只跟「替换」页走：切到别的页藏掉，切回来按开关状态带回（09-19 截图：保存页右边一块空黑框 = 键盘窗没内容）
        if GearInsight._kbFrame then
            if m == "replace" and GearInsightDB.kbOpen then GearInsight._kbFrame:Show() else GearInsight._kbFrame:Hide() end
        end
        if self._layoutRefresh then self._layoutRefresh() end
    end
    local x = 14
    for _, m in ipairs({ { "save", T("LY_MODE_SAVE", "保存") }, { "replace", T("LY_MODE_REPLACE", "替换") }, { "rotation", T("LY_MODE_ROT", "手法") } }) do
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
        local cur = GearInsight:SnapshotBars(); if not cur then return end
        local ok, str = pcall(GearInsight.MySlotString, GearInsight, cur)
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
    local ROWS = MAX_ROTATE + MAX_PINNED + 3   -- +3 = 每日存档
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
                if GearInsight.InForm and GearInsight.InForm() then GearInsight:RestoreBars(target); return end   -- 只为打印「先变回人形」
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
    local bLive = wideBtn(vr, T("LY_BTN_KEYS_LIVE", "读取游戏当前键位"), y2 - 60, function()
        StaticPopup_Show("GEARINSIGHT_KEYS_LIVE")
    end)
    -- 拉丁文比中文宽一倍：英文 / 繁体以外的客户端两个按钮竖排、两个勾选框各占一行，下面几行顺延（09-21 无限英文客户端截图互相压住）
    local WIDE = not (_LOCALE == "zhCN" or _LOCALE == "zhTW")
    local DY = WIDE and 56 or 0
    if not WIDE then bLive:SetSize((LEFT_W - 20) / 2 - 3, 28) end
    bLive:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(T("LY_KEYSLIVE_TT1", "读取游戏当前键位"), 1, 0.82, 0)
        GameTooltip:AddLine(T("LY_KEYSLIVE_TT2", "把面板重置成你游戏里现在真实绑着的键：「我的键位」快照改记实况，并清掉这个专精在面板上手动改过的键。\n在暴雪按键设置里改完键、或者面板上改乱了想从头来，点这个。"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    bLive:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local bSnap = wideBtn(vr, T("LY_BTN_KEYS_RESET", "存储当前键位快照"), y2 - 60, function()
        -- ⛔ 不清手动改键记录、不读游戏实况：存的就是面板上现在显示的这套（用户 2026-09-18「点了直接给我设置面板重置了？？丢失了我的配置」——
        --   之前这里先 wipe 掉 layoutKeys 再抄实况，面板上调好还没绑到游戏里的键全没了）
        local snap = GearInsight.EnsureKeySnapshot(true, true)
        GearInsight:Print(string.format(T("LY_KEYSNAP_SAVED", "已把面板上现在这套键记为「我的键位」快照（%s），「保留现有键位」= 回到这份"), snap._at))
        if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
    end)
    if WIDE then bSnap:ClearAllPoints(); bSnap:SetPoint("TOPLEFT", bLive, "BOTTOMLEFT", 0, -4)
    else bSnap:SetSize((LEFT_W - 20) / 2 - 3, 28); bSnap:ClearAllPoints(); bSnap:SetPoint("TOPLEFT", bLive, "TOPRIGHT", 6, 0) end
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
    local cbSmart = CreateFrame("CheckButton", nil, vr, "UICheckButtonTemplate"); cbSmart:SetPoint("TOPLEFT", 18, y2 - 92 - (WIDE and 32 or 0)); cbSmart:SetSize(24, 24)
    cbSmart.text:SetText(T("LY_CB_SMART", "换智能推荐键位")); cbSmart.text:SetFontObject("GameFontHighlightSmall")
    local cbKeep = CreateFrame("CheckButton", nil, vr, "UICheckButtonTemplate"); if WIDE then cbKeep:SetPoint("TOPLEFT", cbSmart, "BOTTOMLEFT", 0, 0) else cbKeep:SetPoint("LEFT", cbSmart, "RIGHT", 96, 0) end; cbKeep:SetSize(24, 24)
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
    local cbQE = CreateFrame("CheckButton", nil, vr, "UICheckButtonTemplate"); cbQE:SetPoint("TOPLEFT", 18, y2 - 116 - DY); cbQE:SetSize(24, 24)
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
    wideBtn(vr, T("LY_BTN_RANK", "技能施放排名（参考）"), y2 - 148 - DY, function() GearInsight:ToggleCastRankWindow() end)
    wideBtn(vr, T("LY_BTN_MACRO_CLEAR", "一键清 GI 宏"), y2 - 180 - DY, function()
        local n = GearInsight:CountGiMacros()
        if n == 0 then GearInsight:Print(T("LY_MACRO_NONE", "没有 GI 打头的宏")); return end
        StaticPopup_Show("GEARINSIGHT_MACRO_CLEAR", string.format(T("LY_MACRO_CLEAR_ASK", "要删掉 %d 个「GI」打头的宏吗（含建坏的 placeholder）？动作条上对应的格会变空。"), n))
    end)
    lbl(vr, T("LY_KEYS_TIP", "格子左上角 = 推荐键：你现在按职能顺序整体重排：主循环拿 1-5，然后 RFTG ZXCV、Shift/Alt/Ctrl 组合、F1-F4…，7 8 9 0 / F5+ 排最后；裸 QE AD WS 留给移动不参与。\n点格子后按新键即改；Backspace 不绑；Esc 取消。"), 20, y2 - 216 - DY, LEFT_W - 24, "GameFontDisableSmall")
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
    pvHd:ClearAllPoints(); pvHd:SetPoint("TOPLEFT", GX, -8); pvHd:SetPoint("RIGHT", -130, 0); pvHd:SetWordWrap(false)
    local kbBtn = CreateFrame("Button", nil, vr, "UIPanelButtonTemplate"); kbBtn:SetSize(96, 20); kbBtn:SetPoint("TOPRIGHT", -28, -6); kbBtn:SetText(T("LY_KB_BTN", "虚拟键盘"))
    kbBtn:SetScript("OnClick", function() GearInsight:ToggleVirtualKeyboard() end)
    kbBtn:SetScript("OnEnter", function(b) GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(T("LY_KB_BTN_TIP", "打开 / 关闭虚拟键盘：看每个键指向什么、哪些和计划不一致、WASD QE 是不是留给了移动"), 1, 0.82, 0, 1, true); GameTooltip:Show() end)
    kbBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if GearInsightDB and GearInsightDB.kbOpen then C_Timer.After(0, function() if pg:IsShown() and vr:IsShown() and GearInsight._kbFrame then GearInsight._kbFrame:Show() end end) end   -- kbf 是后面才定义的 local（09-21 无限实测 nil 报错）
    local rsf = CreateFrame("ScrollFrame", nil, vr, "UIPanelScrollFrameTemplate")
    -- 待生效状态行（用户「更改状态的时候，要显示当前有几个改动未实现，按什么实现」）
    local pending = lbl(vr, "", GX, -28, 600, "GameFontHighlightSmall")
    pending:ClearAllPoints(); pending:SetPoint("TOPLEFT", GX, -28); pending:SetPoint("RIGHT", -28, 0); pending:SetWordWrap(false)
    rsf:SetPoint("TOPLEFT", GX, -46); rsf:SetPoint("BOTTOMRIGHT", -28, 10)
    local rc = CreateFrame("Frame", nil, rsf); rc:SetSize(1, 1); rsf:SetScrollChild(rc)
    rsf:SetScript("OnSizeChanged", function(_, w)
        rc:SetWidth(math.max(200, w - 4))
        -- 宽度变了列数可能变 → 下一帧重排一次（合并同帧多次触发；⛔别同步调，refresh 里会改 rc 尺寸）
        if vr:IsShown() and GearInsight._layoutRefresh and not rsf._relayoutPending then
            rsf._relayoutPending = true
            C_Timer.After(0, function() rsf._relayoutPending = nil; if vr:IsShown() and GearInsight._layoutRefresh then GearInsight._layoutRefresh() end end)
        end
    end)
    -- 图标要大（用户「图标继续放大，太小了」）：分组行不再硬塞 12 个，一行 8 个，格子最大 72px
    -- ⛔ 2026-09-19 玩家截图（窄分辨率 / 大 UI 缩放）：右栏只有 ~300px 宽时 8 列硬塞，每格被裁成一半、第 5 格跑到面板外。
    --   列数不能写死：先保证每格 ≥ 44px，列数在 4~8 之间按当前宽度算；面板尺寸变了就重排（下面 OnSizeChanged）。
    local GAP, COLS = 5, 8
    local function cellSize()
        local w = rsf:GetWidth(); if not w or w < 100 then w = 560 end
        COLS = math.max(4, math.min(8, math.floor((w - 4 + GAP) / (44 + GAP))))
        return math.max(40, math.min(72, math.floor((w - 4 - (COLS - 1) * GAP) / COLS)))
    end

    local capture = CreateFrame("Frame", nil, vr)
    capture:SetAllPoints(); capture:EnableKeyboard(true); capture:EnableMouse(true); capture:SetPropagateKeyboardInput(false); capture:Hide()
    capture:SetFrameStrata("DIALOG"); capture:SetFrameLevel(150)
    local function finishCapture(key)
        local special = capture._special; capture._special = nil
        if special then
            capture._slot = nil; capture:Hide()
            if key == nil then return end                      -- Esc
            GearInsightDB = GearInsightDB or {}; GearInsightDB.layoutSpecial = GearInsightDB.layoutSpecial or {}
            if InCombatLockdown() then GearInsight:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
            -- 先解掉这个命令原来的键，再绑新键（false = 不绑）
            local k1, k2 = GetBindingKey(special)
            if k1 then SetBinding(k1, nil) end
            if k2 then SetBinding(k2, nil) end
            if key then
                -- 键被我们的格占着 → 那格置空，提示一句（和格子之间撞键同一规则）
                for _, bar in ipairs(BARS) do
                    for sl = bar.from, bar.to do
                        if GearInsight.SlotKey(sl) == key then GearInsight.SetSlotKey(sl, false); GearInsight:Print(string.format(T("LY_SPECIAL_TOOK", "%s 原来指着格 %d，现在给了「%s」；格 %d 无快捷键"), GetBindingText(key, 1), sl, _G["BINDING_NAME_" .. special] or special, sl)) end
                    end
                end
                local prev = GetBindingAction(key)
                if prev and prev ~= "" and prev ~= special and isOurCmd(prev) then SetBinding(key, nil) end
                if not SetBinding(key, special) then GearInsight:Print("|cffff5555" .. T("LY_KEYS_BAD", "这些键系统不认、没绑上（点格子重新按一次）：") .. key .. "|r"); return end
                GearInsightDB.layoutSpecial[special] = key
            else
                GearInsightDB.layoutSpecial[special] = nil
            end
            SaveBindings(2)
            if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
            return
        end
        local slot = capture._slot; capture._slot = nil; capture:Hide()
        if slot and key ~= nil then
            if key then
                -- 这个键别的格已经在用 → 那格改成「不绑」，一个键只能指一格
                for _, bar in ipairs(BARS) do
                    for sl = bar.from, bar.to do
                        if sl ~= slot and GearInsight.SlotKey(sl) == key then
                            -- 被抢走键的格：置空「不绑」，⛔ 不自动补键、⛔ 不动任何其他格（用户 2026-09-18「如果冲突，就把被冲突的置为空，没有按键，改当前的」）
                            GearInsight.SetSlotKey(sl, false)
                            -- 提示里带技能名（用户 2026-09-19「把被替换的技能名也报出来」）：读格子里现在放的是什么
                            local function slotLabel(n)
                                local info = slotInfo(n)
                                local nm
                                if info then
                                    if info.t == "spell" and info.id then nm = C_Spell.GetSpellName and C_Spell.GetSpellName(info.id)
                                    elseif info.t == "item" and info.id then nm = C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.id)
                                    elseif info.t == "macro" then nm = info.name end
                                end
                                return nm and (string.format("%d「%s」", n, nm)) or tostring(n)
                            end
                            GearInsight:Print(string.format(T("LY_KEY_MOVED", "%s 原来指着格 %s，已挪到格 %s；格 %s 现在无快捷键（点它可再设）"), GetBindingText(key, 1), slotLabel(sl), slotLabel(slot), slotLabel(sl)))
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
        -- ⛔ 2026-09-19 用户「上面是鼠标中键，下面是 R」：OnMouseDown 给的是 "MiddleButton"，而绑定系统认的是 "BUTTON3"，
        --    直接大写成 MIDDLEBUTTON 去 SetBinding 会静默失败 → 面板显示鼠标中键、动作条上还是旧键。这里统一换成绑定键名。
        local MOUSE_KEY = { MIDDLEBUTTON = "BUTTON3", BUTTON4 = "BUTTON4", BUTTON5 = "BUTTON5" }
        local kb = string.upper(button)
        finishCapture(withMods(MOUSE_KEY[kb] or kb))
    end)
    capture:SetScript("OnMouseWheel", function(_, d) finishCapture(withMods(d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")) end)
    -- 虚拟键盘点键帽 → 给那格改键（与左键点格同一条路）
    GearInsight.BeginKeyCapture = function(slot) if slot then capture._slot = slot; capture:Show() end end
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
        -- 12.x 国服滚轮全名是「鼠标滚轮向下滚动」（旧版没有末尾「滚动」二字）→ 先替长的再替短的
        t = t:gsub("鼠标滚轮向上滚动", "滚↑"):gsub("鼠标滚轮向下滚动", "滚↓"):gsub("鼠标滚轮向上", "滚↑"):gsub("鼠标滚轮向下", "滚↓")
        t = t:gsub("滑鼠滾輪向上滾動", "滾↑"):gsub("滑鼠滾輪向下滾動", "滾↓"):gsub("滑鼠滾輪向上", "滾↑"):gsub("滑鼠滾輪向下", "滾↓")
        t = t:gsub("鼠标按键", "鼠"):gsub("滑鼠按鍵", "鼠")
        t = t:gsub("Mouse Button ", "M"):gsub("Mouse Wheel Up", "W↑"):gsub("Mouse Wheel Down", "W↓"):gsub("Scroll Up", "W↑"):gsub("Scroll Down", "W↓"):gsub("Num Pad ", "N")
        -- 长名功能键缩写（09-21 用户截图：键帽「a-c-Page Down」把旁边格子压住）：所有键帽 / 角标 / 表格共用这一处
        t = t:gsub("Page Down", "PD"):gsub("Page Up", "PU"):gsub("Num Lock", "NL"):gsub("Insert", "Ins"):gsub("Delete", "Del"):gsub("Home", "Hm"):gsub("Backspace", "BS"):gsub("Caps Lock", "Caps"):gsub("Print Screen", "PrtSc"):gsub("Scroll Lock", "SL")
        t = t:gsub("向下翻页", "PD"):gsub("向上翻页", "PU"):gsub("数字锁定", "NL"):gsub("插入", "Ins"):gsub("删除", "Del"):gsub("退格", "BS"):gsub("大写锁定", "Caps")
        return t
    end
    local SRC_COLOR = { core = { 1, 0.82, 0 }, burst = { 1, 0.45, 0 }, interrupt = { 0.9, 0.2, 0.2 }, cc = { 0.65, 0.4, 1 },
                        def = { 0.3, 0.7, 1 }, heal = { 0.2, 0.9, 0.4 }, mob = { 0.4, 0.9, 0.9 }, raid = { 1, 0.7, 0.9 }, dispel = { 0.9, 0.9, 0.4 },
                        taunt = { 0.8, 0.5, 0.3 }, form = { 0.95, 0.65, 0.25 }, skip = { 0.45, 0.45, 0.5 }, summon = { 0.6, 0.6, 0.6 }, util = { 0.5, 0.75, 0.75 }, dps = { 0.55, 0.55, 0.55 }, inv = { 0.8, 0.8, 0.8 } }

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
        -- 饰品 / 药水角标（用户 2026-09-19「饰品和药水分别用个角标」）：橙「饰」、紫「药」，和天/族同位
        c.inv = c:CreateTexture(nil, "OVERLAY"); c.inv:SetSize(16, 16); c.inv:SetPoint("BOTTOMLEFT", 2, 2); c.inv:SetColorTexture(0.95, 0.55, 0.15, 0.95); c.inv:Hide()
        c.invT = c:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall"); c.invT:SetPoint("CENTER", c.inv, "CENTER", 0, 0); c.invT:SetText(T("LY_BADGE_TRINKET", "饰")); c.invT:Hide()
        c.pot = c:CreateTexture(nil, "OVERLAY"); c.pot:SetSize(16, 16); c.pot:SetPoint("BOTTOMLEFT", 2, 2); c.pot:SetColorTexture(0.6, 0.35, 0.9, 0.95); c.pot:Hide()
        c.potT = c:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall"); c.potT:SetPoint("CENTER", c.pot, "CENTER", 0, 0); c.potT:SetText(T("LY_BADGE_POTION", "药")); c.potT:Hide()
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
        -- 拖技能松到宏格上 → 往这个宏正文追加一行 /cast 技能名（09-20 用户「可以把某个技能拉到宏里放下」）；物品 → /use
        c:SetScript("OnReceiveDrag", function(self)
            if not self._macro or InCombatLockdown() then return end
            local kind, id, _, spellID = GetCursorInfo()
            local line
            if kind == "spell" then
                local nm = spellID and C_Spell.GetSpellName(spellID); if nm then line = "/cast " .. nm end
            elseif kind == "item" then
                local nm = id and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id); if nm then line = "/use " .. nm end
            end
            if not line then return end
            ClearCursor()
            local mi = GearInsight:EnsureMacroItem(self._it); if not mi then return end
            local name, icon, body = GetMacroInfo(mi)
            body = body or ""
            if body:find(line, 1, true) then GearInsight:Print(string.format(T("LY_MACRO_HAS", "「%s」里已经有 %s"), name, line)); return end
            local nb = (body ~= "" and (body .. "\n") or "") .. line
            if #nb > 255 then GearInsight:Print(string.format(T("LY_MACRO_TOO_LONG", "「%s」加上 %s 会超 255 字，没加"), name, line)); return end
            EditMacro(mi, name, icon, nb)
            GearInsight:Print(string.format(T("LY_MACRO_ADDED", "已加进「%s」：%s（右键格子打开宏编辑器可改）"), name, line))
            if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end
        end)
        -- 右键兜底走 OnMouseUp（09-20 用户「右键点不了」：半透明的停车场格 OnClick 没触发）
        local function roleMenu(self)
            if self._rmAt == GetTime() then return end   -- OnClick 和 OnMouseUp 同一帧都到 → 只开一次
            self._rmAt = GetTime()
            if GearInsightDB and GearInsightDB.layoutDebug then GearInsight:Print("右键格 id=" .. tostring(self._id)) end
            GearInsight.ShowRoleMenu(self, self._id)
        end
        c:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" and self._id and not self._macro and not self._inv then roleMenu(self) end
        end)
        c:SetScript("OnClick", function(self, button)
            -- 右键职能菜单不看有没有格：停车场 / 折叠行 / 放不下的格也要能右键（09-20）
            if button == "RightButton" and self._id and not self._macro and not self._inv then roleMenu(self); return end
            if not self._slot then return end
            -- 手里拿着技能 / 物品点宏格 = 也算放下（有的人不拖直接点）
            if self._macro and GetCursorInfo() and not InCombatLockdown() then self:GetScript("OnReceiveDrag")(self); return end
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
            -- Shift+左键（技能 / 物品 / 饰品格）= 像法术书一样把它塞进正在编辑的宏 / 聊天框（09-21 用户「shift点这种技能按钮可以打印到宏的一行不」）：
            --   宏编辑器开着 → 暴雪自己会写成「/cast 技能名」一行；聊天框开着 → 链接；都没开 → 提示
            if IsShiftKeyDown() and (self._id or self._item or self._inv) then
                -- 宏编辑器开着 → 自己写行。⛔ 别走 ChatEdit_InsertLink：12.x 国服它塞出来的是「/施放 [狂暴]」，方括号被当宏条件
                --   → 「未知的宏设置」（09-21 用户截图）。物品 /use 名字，饰品 /use 槽号，技能 /cast 名字（替换后的）；光标不在行首先补换行
                local eb = (MacroFrame and MacroFrame.GetEditBox and MacroFrame:GetEditBox()) or MacroFrameText
                if eb and eb:IsVisible() and eb.HasFocus and eb:HasFocus() then
                    local line
                    if self._inv then line = "/use " .. self._inv
                    elseif self._item then local nm = C_Item.GetItemInfo(self._item); line = nm and ("/use " .. nm) or nil
                    elseif self._id then
                        local sid = (FindSpellOverrideByID and FindSpellOverrideByID(self._id)) or self._id
                        local sp = C_Spell.GetSpellInfo(sid); line = sp and sp.name and ("/cast " .. sp.name) or nil
                    end
                    if line then
                        local txt, pos = eb:GetText() or "", eb:GetCursorPosition() or 0
                        local before = txt:sub(1, pos)
                        if #before > 0 and before:sub(-1) ~= "\n" then line = "\n" .. line end
                        eb:Insert(line)
                        return
                    end
                end
                local link
                if self._inv then link = GetInventoryItemLink("player", self._inv)
                elseif self._item then link = select(2, C_Item.GetItemInfo(self._item))
                elseif self._id then
                    -- 格子记的是基础技能 id（狂暴），天赋替换后图标 / 提示都显示覆盖技能（化身：乌索克的守护者）；链接也要按覆盖后的拿，
                    --   否则塞进宏的是「/cast 狂暴」（09-21 用户「为啥 shift+左键点这个，给了狂暴」）
                    local sid = (FindSpellOverrideByID and FindSpellOverrideByID(self._id)) or self._id
                    link = (C_Spell.GetSpellLink and C_Spell.GetSpellLink(sid)) or (GetSpellLink and GetSpellLink(sid)) end
                if link and ChatEdit_InsertLink(link) then return end
                GearInsight:Print(T("LY_SHIFT_LINK_NONE", "先打开宏编辑器（/macro）并点进正文，或打开聊天框，再 Shift+左键这格：会把它作为一行塞进去"))
                return
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
            GameTooltip:AddLine(roleTxt .. (self._why and ("  · " .. whyText(self._why)) or "") .. ((self._it and self._it.userRole) and ("  |cff9ec9ff" .. T("LY_ROLE_USER", "你手动指定的行") .. "|r") or ""), 0.8, 0.8, 0.8)
            if self._it and self._it.userMacro then GameTooltip:AddLine(string.format(T("LY_USER_MACRO_TIP", "这格放的是你自己的宏「%s」（里面 /cast 了这个技能），键给宏，不再单放技能"), self._it.userMacro), 0.6, 0.8, 1, true) end
            if self._id and not self._macro and not self._inv then GameTooltip:AddLine(T("LY_ROLE_TT", "右键：把这个技能挪到别的职能行（分错行了就自己改）"), 0.5, 0.5, 0.5) end
            if self._slot then
                local cur = GetBindingKey(GearInsight.SlotCommand(self._slot))
                GameTooltip:AddLine(string.format("%s %d   %s%s   %s%s", T("LY_SLOT", "格"), self._slot, T("LY_KEY_TT2", "这格现在绑："), cur and GetBindingText(cur, 1) or T("LY_KEY_NONE", "不绑"),
                    T("LY_KEY_REC", "推荐："), GearInsight.SlotKey(self._slot) and GetBindingText(GearInsight.SlotKey(self._slot), 1) or T("LY_KEY_NONE", "不绑")), 1, 1, 1)
                if self._id then
                    -- 这个技能现在真实在条上哪几格、按什么键（重铺前后不一样，说清楚）
                    local where = {}
                    local base = (FindBaseSpellByID and FindBaseSpellByID(self._id)) or self._id
                    for sl = 1, 180 do
                        local t, sid = GetActionInfo(sl)
                        if t == "spell" and sid and (sid == self._id or sid == base or ((FindBaseSpellByID and FindBaseSpellByID(sid)) or sid) == base) then
                            local cmd = GearInsight.SlotCommand(sl) or (sl >= 145 and sl <= 156 and ("MULTIACTIONBAR5BUTTON" .. (sl - 144))) or (sl >= 157 and sl <= 168 and ("MULTIACTIONBAR6BUTTON" .. (sl - 156))) or (sl >= 169 and sl <= 180 and ("MULTIACTIONBAR7BUTTON" .. (sl - 168)))
                            local k = cmd and GetBindingKey(cmd)
                            where[#where + 1] = string.format("%s %d %s", T("LY_SLOT", "格"), sl, k and ("|cffffffff" .. GetBindingText(k, 1) .. "|r") or ("|cff888888" .. T("LY_KEY_NONE", "不绑") .. "|r"))
                        end
                    end
                    if #where > 0 then
                        if #where ~= 1 or not where[1]:find("^" .. T("LY_SLOT", "格") .. " " .. self._slot .. " ") then
                            GameTooltip:AddLine(T("LY_KEY_WHERE", "这个技能现在在：") .. table.concat(where, "  ") .. "  |cff888888" .. T("LY_KEY_WHERE_TIP", "（清空重铺后才会挪到这格）") .. "|r", 1, 0.82, 0, true)
                        end
                    else
                        GameTooltip:AddLine("|cff888888" .. T("LY_KEY_WHERE_NONE", "这个技能现在不在任何条上") .. "|r", 1, 1, 1, true)
                    end
                end
                GameTooltip:AddLine(T("LY_KEY_TT3", "点一下再按新键可改；Backspace 不绑；Esc 取消 · 按住左键可直接拖到动作条 · Shift+左键：塞进正在编辑的宏（/cast 一行）或聊天框"), 0.5, 0.5, 0.5)
                local k = GearInsight.SlotKey(self._slot)
                if k then
                    for _, bar in ipairs(BARS) do for sl = bar.from, bar.to do
                        if sl ~= self._slot and GearInsight.SlotKey(sl) == k then GameTooltip:AddLine(string.format(T("LY_KEY_CONFLICT", "[撞键] 和格 %d 撞键：实现时后出现的格拿到这个键，另一格置空。点其中一格改个键。"), sl), 1, 0.3, 0.3, true) end
                    end end
                end
            elseif self._it and self._it.off then
                GameTooltip:AddLine(T("LY_GROUP_OFF_TT", "这一行没勾「上条」，不占格；勾上行头的框才铺"), 0.7, 0.7, 0.7)
            elseif self._it and self._it.formSlot then
                local k = GearInsight.SlotKey(self._it.formSlot)
                GameTooltip:AddLine(string.format(T("LY_ON_FORM_PAGE", "在「%s」页第 %d 格（键 %s，与主条同位共用）"), ({ cat = T("LY_FORM_CAT", "猎豹形态"), bear = T("LY_FORM_BEAR", "熊形态"), base = T("LY_FORM_BASE", "人形（施法）"), stealth = T("LY_FORM_STEALTH", "潜行") })[self._it.page] or self._it.page, self._it.formSlot, k and shortKey(k) or "-"), 0.6, 0.8, 1)
            else
                local it = self._it
                local why = (it and it.page == "base") and T("LY_NO_SLOT_BASE", "人形（施法）页 12 格满了，公用条也满了")
                    or (it and it.page and it.page ~= "main" and it.page ~= "shared") and T("LY_NO_SLOT_FORM", "这个形态页 12 格满了")
                    or T("LY_NO_SLOT_60", "主条 + 条 2～5 共 60 格满了")
                GameTooltip:AddLine(T("LY_NO_SLOT", "60 格放不下，这个不铺") .. "  |cff888888" .. why .. " · " .. T("LY_NO_SLOT_HINT", "右键把不用的技能标「不进动作条」腾格") .. "|r", 1, 0.4, 0.4, true)
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

    -- ── 虚拟键盘 ──────────────────────────────────────────────────────
    --   每个键帽 = 这个键（当前修饰层）现在指向什么：金框 + 技能图标 = 计划里的格；红角 = 现在绑的和计划不一致；
    --   灰「移动」= WASD / QE 留给移动；暗灰小字 = 被别的功能占着（打开地图之类）；黑 = 空闲。
    --   修饰层按钮：无 / Shift / Ctrl / Alt。悬停看详情，点键帽 = 对应格子进入改键（同左键点格）。
    local KB_ROWS = {
        { "`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" },
        { "TAB", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]" },
        { "CAPSLOCK", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'" },
        { "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "SPACE" },
        { "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12" },
        { "BUTTON3", "BUTTON4", "BUTTON5", "MOUSEWHEELUP", "MOUSEWHEELDOWN", "NUMPAD0", "NUMPAD1", "NUMPAD2", "NUMPAD3" },
    }
    local KB_LABEL = { TAB = "Tab", CAPSLOCK = "Caps", SPACE = "Space", BUTTON3 = "鼠中", BUTTON4 = "鼠4", BUTTON5 = "鼠5", MOUSEWHEELUP = "滚上", MOUSEWHEELDOWN = "滚下", NUMPAD0 = "小0", NUMPAD1 = "小1", NUMPAD2 = "小2", NUMPAD3 = "小3" }
    local MOVE_KEYS = { W = "MOVEFORWARD", S = "MOVEBACKWARD", A = "TURNLEFT", D = "TURNRIGHT", Q = "STRAFELEFT", E = "STRAFERIGHT", SPACE = "JUMP" }
    local kbf = CreateFrame("Frame", "GearInsightVirtualKeyboard", UIParent, "BackdropTemplate")
    kbf:SetSize(600, 320); kbf:SetFrameStrata("DIALOG")
    kbf:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    kbf:SetBackdropColor(0.05, 0.05, 0.08, 0.97); kbf:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
    kbf:SetMovable(true); kbf:EnableMouse(true); kbf:RegisterForDrag("LeftButton"); kbf:SetClampedToScreen(true)
    kbf:SetScript("OnDragStart", kbf.StartMoving)
    kbf:SetScript("OnDragStop", function(x) x:StopMovingOrSizing(); local pt, _, rp, px, py = x:GetPoint(); GearInsightDB = GearInsightDB or {}; GearInsightDB.kbPos = { pt, rp, px, py } end)
    do
        local pos = GearInsightDB and GearInsightDB.kbPos
        if pos then kbf:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else kbf:SetPoint("LEFT", pg, "RIGHT", 6, 0) end
        local x = CreateFrame("Button", nil, kbf, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", 2, 2)
        x:SetScript("OnClick", function() kbf:Hide(); GearInsightDB.kbOpen = nil end)
    end
    kbf:Hide()
    GearInsight._kbFrame = kbf
    local kbHd = kbf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local kbNote = kbf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); kbNote:SetJustifyH("LEFT"); kbNote:SetWordWrap(true)
    local kbMod = GearInsightDB and GearInsightDB.layoutKbMod or ""
    local kbModBtns = {}
    local kbCells = {}
    local function kbCell()
        local c = CreateFrame("Button", nil, kbf, "BackdropTemplate")
        c:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetPoint("TOPLEFT", 2, -2); c.icon:SetPoint("BOTTOMRIGHT", -2, 2); c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        c.hi = c:CreateTexture(nil, "OVERLAY"); c.hi:SetPoint("TOPLEFT", 1, -1); c.hi:SetPoint("TOPRIGHT", -1, -1); c.hi:SetHeight(2); c.hi:SetColorTexture(1, 1, 1, 0.14)
        c.cap = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.cap:SetPoint("TOPLEFT", 3, -2)
        c.sub = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); c.sub:SetPoint("BOTTOM", 0, 2); c.sub:SetWidth(40); c.sub:SetWordWrap(false)
        c.mark = c:CreateTexture(nil, "OVERLAY"); c.mark:SetSize(8, 8); c.mark:SetPoint("TOPRIGHT", -1, -1); c.mark:SetColorTexture(1, 0.25, 0.25, 1); c.mark:Hide()
        c:SetScript("OnEnter", function(x)
            GameTooltip:SetOwner(x, "ANCHOR_RIGHT")
            GameTooltip:SetText(GetBindingText(x._key, 1) or x._key, 1, 0.82, 0)
            if x._p and x._p.id then GameTooltip:AddLine(T("LY_KB_PLAN", "计划：") .. (C_Spell.GetSpellName(x._p.id) or "?") .. string.format("  (%s %d)", T("LY_SLOT", "格"), x._p.slot), 1, 1, 1)
            elseif x._p and x._p.macro then
                local nm = macroNameOf(x._p)
                GameTooltip:AddLine(T("LY_KB_PLAN", "计划：") .. "|cffffd100" .. nm .. "|r" .. string.format("  (%s %d)", T("LY_SLOT", "格"), x._p.slot), 1, 1, 1)
                local body = macroBodyOf(x._p) or ""
                local n = 0
                for line in body:gmatch("[^\n]+") do n = n + 1; if n > 10 then GameTooltip:AddLine("…", 0.6, 0.6, 0.6); break end; GameTooltip:AddLine(line, 0.8, 0.8, 0.8) end
                if not (GetMacroIndexByName(nm) or 0 > 0) then GameTooltip:AddLine(T("LY_KB_MACRO_NEW", "（还没建：点「将插件建议实现到动作条」时会建好放上去）"), 0.6, 0.6, 0.6) end
            elseif x._p and x._p.item then GameTooltip:AddLine(T("LY_KB_PLAN", "计划：") .. (x._p.cn or "") .. string.format("  (%s %d)", T("LY_SLOT", "格"), x._p.slot), 1, 1, 1) end
            local act = GetBindingAction(x._key)
            if act and act ~= "" then GameTooltip:AddLine(T("LY_KB_NOW", "现在：") .. (_G["BINDING_NAME_" .. act] or act), 0.7, 0.7, 0.7)
            else GameTooltip:AddLine(T("LY_KB_FREE", "现在：空闲"), 0.5, 0.5, 0.5) end
            if x._p and x._p.slot then GameTooltip:AddLine(T("LY_KB_CLICK", "点击 = 给这一格改键"), 0.5, 0.75, 1) end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c:SetScript("OnClick", function(x)
            if x._p and x._p.slot and GearInsight.BeginKeyCapture then GearInsight.BeginKeyCapture(x._p.slot) end
        end)
        return c
    end
    local function macroTexOf(name, body)
        local idx = name and GetMacroIndexByName(name)
        local tex
        if idx and idx > 0 then local _, t, b = GetMacroInfo(idx); tex = t; body = body or b end
        if (not tex or tex == 134400 or tostring(tex):find("QuestionMark")) and body then
            for line in body:gmatch("[^\n]+") do
                local cmd, rest = line:match("^/(%S+)%s*(.*)$")
                if cmd == "cast" or cmd == "use" or cmd == "castsequence" then
                    rest = rest:gsub("%[.-%]", ""):gsub("reset=%S+", ""):gsub("^%s+", "")
                    local nm = rest:match("^([^,;]+)"); nm = nm and nm:gsub("%s+$", "") or ""
                    local sp = nm ~= "" and C_Spell.GetSpellInfo(nm)
                    if sp and sp.iconID then return sp.iconID end
                    local iid = tonumber(nm:match("item:(%d+)"))
                    local it = nm ~= "" and C_Item.GetItemIconByID and (iid and C_Item.GetItemIconByID(iid) or C_Item.GetItemIconByID(nm))
                    if it then return it end
                end
            end
        end
        return tex
    end
    local SPECIALS   -- 系统键表，下面才赋值（refreshKb 里查短标签）
    local function kbKey(base)
        return (kbMod ~= "" and (kbMod .. "-") or "") .. base
    end
    local function layoutKb()
        if not kbf:IsShown() then return end
        local y = -10
        local X0 = 10
        kbHd:ClearAllPoints(); kbHd:SetPoint("TOPLEFT", X0, y); kbHd:SetPoint("RIGHT", kbf, "RIGHT", -30, 0); kbHd:SetJustifyH("LEFT"); kbHd:SetWordWrap(false)
        kbHd:SetText(T("LY_KB_HD", "虚拟键盘 · 这一层的键都指向什么"))
        -- 修饰层按钮
        local mods = { { "", T("LY_KB_MOD_NONE", "无修饰") }, { "SHIFT", "Shift" }, { "CTRL", "Ctrl" }, { "ALT", "Alt" } }
        local x = 0
        for i, m in ipairs(mods) do
            local b = kbModBtns[i]
            if not b then
                b = CreateFrame("Button", nil, kbf, "UIPanelButtonTemplate"); b:SetSize(70, 18); b:SetText(m[2])
                b:SetScript("OnClick", function() kbMod = m[1]; GearInsightDB = GearInsightDB or {}; GearInsightDB.layoutKbMod = kbMod; if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end end)
                kbModBtns[i] = b
            end
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", X0 + x, y - 20); b:SetEnabled(kbMod ~= m[1]); x = x + 74
        end
        y = y - 44
        -- 图例单独一行（09-19 截图：标题 + 图例一行塞不下，字跑到窗外）
        kbNote:ClearAllPoints(); kbNote:SetPoint("LEFT", kbModBtns[4], "RIGHT", 10, 0); kbNote:SetPoint("RIGHT", kbf, "RIGHT", -10, 0); kbNote:SetWordWrap(false); kbNote:SetJustifyH("LEFT")
        kbNote:SetText("|cff888888" .. T("LY_KB_NOTE", "金框 = 计划里的格 · 红角 = 现在绑的不一致 · 灰 = 留给移动 · 暗字 = 被别的功能占着") .. "|r")
        local size, gap = 40, 3
        -- 宽键按倍数占位，位置累加算（原来按序号乘等宽，Tab / Caps 加宽后压住了旁边的键；空格伸出窗外）
        local WIDE = { TAB = 1.5, CAPSLOCK = 1.75, SPACE = 2.5 }
        local ROW_OFF = { 0, 0, 0, 0.9, 0, 0 }
        local idx, maxW = 0, 0
        for r, row in ipairs(KB_ROWS) do
            local x = math.floor(size * (ROW_OFF[r] or 0))
            for _, k in ipairs(row) do
                idx = idx + 1
                local c = kbCells[idx] or kbCell(); kbCells[idx] = c
                c._base = k
                local cw = math.floor(size * (WIDE[k] or 1) + gap * ((WIDE[k] or 1) - 1))
                c:SetSize(cw, size); c:ClearAllPoints(); c:SetPoint("TOPLEFT", X0 + x, y)
                c:Show()
                x = x + cw + gap
            end
            if x > maxW then maxW = x end
            y = y - size - gap
        end
        for j = idx + 1, #kbCells do kbCells[j]:Hide() end
        if not kbf.foot then kbf.foot = kbf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); kbf.foot:SetJustifyH("LEFT"); kbf.foot:SetWordWrap(true) end
        kbf.foot:ClearAllPoints(); kbf.foot:SetPoint("TOPLEFT", X0, y - 2); kbf.foot:SetPoint("RIGHT", kbf, "RIGHT", -10, 0)
        kbf.foot:SetText(T("LY_KB_FOOT", "点键帽 = 给那格改键；Shift / Ctrl / Alt 层切上面按钮看。裸 WASD / 空格留给移动，Q E 看「Q E 也参与分键」。"))
        kbf:SetSize(X0 * 2 + maxW, -y + 44)
    end
    kbf:SetScript("OnShow", function() if GearInsight._layoutRefresh then GearInsight._layoutRefresh() end end)
    function GearInsight:ToggleVirtualKeyboard()
        GearInsightDB = GearInsightDB or {}
        if kbf:IsShown() then kbf:Hide(); GearInsightDB.kbOpen = nil else kbf:Show(); GearInsightDB.kbOpen = true end
    end
    pg:HookScript("OnHide", function() kbf:Hide() end)
    local function refreshKb(planned, slots)
        -- 计划：key → 格
        local byKey, byKeyRaw = {}, {}
        for _, pl in ipairs(slots or {}) do
            local k = GearInsight.SlotKey(pl.slot)
            if k then byKey[k] = pl; byKeyRaw[k] = pl.slot end
        end
        local useQE = GearInsightDB and GearInsightDB.layoutUseQE
        for _, c in ipairs(kbCells) do
            if c:IsShown() then
                local key = kbKey(c._base)
                c._key = key
                local pl = byKey[key]
                c._p = pl
                local lbl = KB_LABEL[c._base] or c._base
                c.cap:SetText(lbl); c.icon:SetTexture(nil); c.sub:SetText(""); c.mark:Hide(); c:SetAlpha(1)
                local act = GetBindingAction(key)
                if pl then
                    local icon
                    if pl.inv then icon = GetInventoryItemTexture("player", pl.inv)
                    elseif pl.item then icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(pl.item)
                    elseif pl.macro then icon = macroTexOf(macroNameOf(pl), macroBodyOf(pl)) or ("Interface\\ICONS\\" .. macroIconOf(pl))
                    elseif pl.id then icon = (C_Spell.GetSpellInfo(pl.id) or {}).iconID end
                    c.icon:SetTexture(icon)
                    c:SetBackdropColor(0.1, 0.1, 0.12, 1); c:SetBackdropBorderColor(1, 0.82, 0, 1)
                    local cur = GetBindingKey(GearInsight.SlotCommand(pl.slot))
                    c.mark:SetShown(cur ~= key)
                elseif act and act ~= "" and SPECIALS and (function() for _, sp in ipairs(SPECIALS) do if sp.cmd == act then local eff = GearInsight.EffectiveSpecialKey and GearInsight.EffectiveSpecialKey(act, byKeyRaw); return eff == key end end return false end)() then
                    c:SetBackdropColor(0.08, 0.12, 0.2, 1); c:SetBackdropBorderColor(0.35, 0.65, 1, 1)
                    local short = act
                    for _, sp in ipairs(SPECIALS) do if sp.cmd == act then short = sp.short or act end end
                    c.sub:SetText("|cff9ec9ff" .. short .. "|r")
                elseif kbMod == "" and MOVE_KEYS[c._base] and not (useQE and (c._base == "Q" or c._base == "E")) then
                    c:SetBackdropColor(0.16, 0.16, 0.18, 1); c:SetBackdropBorderColor(0.35, 0.35, 0.38, 1); c.sub:SetText(T("LY_KB_MOVE", "移动")); c:SetAlpha(0.85)
                elseif act and act ~= "" and not isOurCmd(act) then
                    c:SetBackdropColor(0.08, 0.08, 0.1, 1); c:SetBackdropBorderColor(0.3, 0.3, 0.32, 1)
                    local nm = _G["BINDING_NAME_" .. act] or act
                    c.sub:SetText("|cff777777" .. tostring(nm):sub(1, 6) .. "|r")
                elseif act and act ~= "" then
                    -- 绑在我们的格上但计划里没排（比如用户手改的）：黄框
                    c:SetBackdropColor(0.1, 0.1, 0.12, 1); c:SetBackdropBorderColor(0.7, 0.6, 0.2, 1)
                    local sl = tonumber(act:match("(%d+)$"))
                    local r = sl and slotInfo(GearInsight.SlotFromCommand and GearInsight.SlotFromCommand(act) or -1)
                    if r and r.t == "spell" then c.icon:SetTexture((C_Spell.GetSpellInfo(r.id) or {}).iconID) end
                else
                    c:SetBackdropColor(0.04, 0.04, 0.06, 1); c:SetBackdropBorderColor(0.2, 0.2, 0.22, 1); c:SetAlpha(0.8)
                end
            end
        end
    end

    -- 特殊键：默认不设置；设置了就联动虚拟键盘 / 撞键规则
    local function pingCommand()
        if GearInsight._pingCmd ~= nil then return GearInsight._pingCmd or nil end
        local found = false
        for i = 1, (GetNumBindings and GetNumBindings() or 0) do
            local cmd = GetBinding(i)
            if type(cmd) == "string" and (cmd == "TOGGLEPING" or cmd == "PINGSYSTEM" or cmd:find("^PING")) then found = cmd; break end
        end
        GearInsight._pingCmd = found
        return found or nil
    end
    -- 「系统」键（用户 2026-09-19：分类叫系统；「类似场景的快捷键还有啥」）：战斗里会顺手按、又不在动作条上的暴雪原生命令。
    --   都是默认不设置；设了才占键、才进虚拟键盘。label 用暴雪自己的绑定名（BINDING_NAME_xxx，跟客户端语言走）。
    local function bname(cmd, zh) return _G["BINDING_NAME_" .. cmd] or zh end
    SPECIALS = {
        { cmd = "REPLY", label = bname("REPLY", "回复密语"), hint = T("LY_SP_REPLY_TIP", "暴雪原生「回复密语」：一键回复最近一条私聊（默认 R）"), short = T("LY_SP_REPLY_SHORT", "密语") },
        { cmd = pingCommand(), label = T("LY_SP_PING", "信号"), hint = T("LY_SP_PING_TIP", "暴雪原生信号轮（Ping）：按住弹出，指路 / 集火 / 危险"), short = T("LY_SP_PING_SHORT", "信号") },
        { cmd = "FOCUSTARGET", label = bname("FOCUSTARGET", "设置焦点"), hint = T("LY_SP_FOCUS_TIP", "把当前目标设为焦点（打断焦点、盯 BOSS 读条都靠它）"), short = T("LY_SP_FOCUS_SHORT", "设焦") },
        { cmd = "TARGETFOCUS", label = bname("TARGETFOCUS", "选中焦点"), hint = T("LY_SP_TFOCUS_TIP", "选中焦点目标"), short = T("LY_SP_TFOCUS_SHORT", "焦点") },
        { cmd = "ASSISTTARGET", label = bname("ASSISTTARGET", "协助目标"), hint = T("LY_SP_ASSIST_TIP", "选中「你的目标的目标」——跟坦克的集火目标"), short = T("LY_SP_ASSIST_SHORT", "协助") },
        { cmd = "INTERACTTARGET", label = bname("INTERACTTARGET", "与目标互动"), hint = T("LY_SP_INTERACT_TIP", "对目标按互动：捡东西、跟 NPC 对话、开门"), short = T("LY_SP_INTERACT_SHORT", "互动") },
        { cmd = "TARGETNEARESTENEMY", label = bname("TARGETNEARESTENEMY", "选择最近的敌人"), hint = T("LY_SP_TAB_TIP", "默认 Tab"), short = "Tab" },
        { cmd = "RAIDTARGET8", label = bname("RAIDTARGET8", "标记：骷髅"), hint = T("LY_SP_SKULL_TIP", "给目标打骷髅标记（主集火）"), short = T("LY_SP_SKULL_SHORT", "骷髅") },
        { cmd = "RAIDTARGET7", label = bname("RAIDTARGET7", "标记：叉"), hint = T("LY_SP_CROSS_TIP", "给目标打叉标记（次集火）"), short = T("LY_SP_CROSS_SHORT", "叉") },
        { cmd = "TOGGLEAUTORUN", label = bname("TOGGLEAUTORUN", "自动奔跑"), hint = T("LY_SP_AUTORUN_TIP", "默认小键盘 Lock"), short = T("LY_SP_AUTORUN_SHORT", "自跑") },
        { cmd = "PETATTACK", label = bname("PETATTACK", "宠物攻击"), hint = T("LY_SP_PET_TIP", "有宠物的职业：让宠物打当前目标"), short = T("LY_SP_PET_SHORT", "宠攻") },
    }
    local spHd = rc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local spRows = {}
    local function spRow(i)
        if spRows[i] then return spRows[i] end
        local r = CreateFrame("Frame", nil, rc); r:SetHeight(22)
        r.lbl = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.lbl:SetPoint("LEFT", 4, 0); r.lbl:SetWidth(90); r.lbl:SetJustifyH("LEFT")
        r.key = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.key:SetSize(110, 20); r.key:SetPoint("LEFT", 100, 0)
        r.key:SetScript("OnClick", function(b)
            if not r._cmd then return end
            capture._special = r._cmd; capture._slot = nil; capture:Show(); b:SetText("|cffffd100…|r")
        end)
        r.key:SetScript("OnEnter", function(b) GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(r._hint or "", 1, 0.82, 0, 1, true); GameTooltip:AddLine(T("LY_SP_HOW", "点一下再按新键；Backspace = 不绑；Esc 取消"), 0.6, 0.6, 0.6, true); GameTooltip:Show() end)
        r.key:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.now = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.now:SetPoint("LEFT", 218, 0); r.now:SetPoint("RIGHT", -4, 0); r.now:SetJustifyH("LEFT"); r.now:SetWordWrap(false)
        spRows[i] = r
        return r
    end
    -- 计划里 key → 格（系统键判「默认键有没有被占」用）
    local function planKeys()
        local m = {}
        for _, bar in ipairs(BARS) do
            for sl = bar.from, bar.to do local k = GearInsight.SlotKey(sl); if k then m[k] = sl end end
        end
        return m
    end
    -- 系统键当前有效的键：用户设过的 > 游戏默认且没被计划占用 > 空
    local function effectiveSpecial(cmd, pk)
        local set = GearInsightDB and GearInsightDB.layoutSpecial and GearInsightDB.layoutSpecial[cmd]
        if set then return set, "set" end
        local cur = GetBindingKey(cmd)
        local d = GearInsight.SpecialDefaultKey(cmd, cur)
        pk = pk or planKeys()
        if cur and not pk[cur] then return cur, "default" end
        if cur then return nil, "taken", cur end
        if d and pk[d] then return nil, "taken", d end        -- 已经被顶掉了：默认键在计划里
        if d and not pk[d] then return d, "restore", d end     -- 默认键空出来了 → 下次「实现到动作条」自动还回去
        return nil, "none"
    end
    GearInsight.EffectiveSpecialKey = effectiveSpecial
    GearInsight._specialsList = SPECIALS
    local function layoutSpecial(y)
        local pk = planKeys()
        spHd:ClearAllPoints(); spHd:SetPoint("TOPLEFT", 0, y)
        spHd:SetText(T("LY_SP_HD", "系统 · 默认不设置，设了就进虚拟键盘") .. "  |cff888888" .. T("LY_SP_NOTE", "回复密语 / 信号 / 焦点 / 协助 / 互动 / 标记 / 自动奔跑 / 宠物攻击") .. "|r")
        y = y - 22
        local n = 0
        for _, sp in ipairs(SPECIALS) do
            if sp.cmd then
                n = n + 1
                local r = spRow(n); r._cmd, r._hint = sp.cmd, sp.hint
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:SetPoint("RIGHT", rc, "RIGHT", -4, 0); r:Show()
                r.lbl:SetText(sp.label)
                local eff, why = effectiveSpecial(sp.cmd, pk)
                local cur = GetBindingKey(sp.cmd)
                r.key:SetText(eff and shortKey(eff) or T("LY_SP_UNSET", "未设置"))
                if why == "set" then
                    r.now:SetText(cur == eff and "|cff40c060" .. T("LY_SP_OK", "已生效") .. "|r" or "|cffff5555" .. T("LY_SP_DIFF", "和游戏里的不一致，点「将插件建议实现到动作条」") .. "|r")
                elseif why == "default" then
                    r.now:SetText(string.format(T("LY_SP_GAME", "游戏默认 %s · 没被占，保留"), GetBindingText(eff, 1)))
                elseif why == "taken" then
                    local tk = select(3, effectiveSpecial(sp.cmd, pk)) or cur
                    r.now:SetText(string.format("|cffff9c40" .. T("LY_SP_TAKEN", "默认 %s 被格 %d 占用 → 留空（想要就点左边设一个）") .. "|r", GetBindingText(tk, 1), pk[tk] or 0))
                elseif why == "restore" then
                    r.now:SetText(string.format("|cff40c060" .. T("LY_SP_RESTORE", "默认 %s 空出来了 · 点「实现到动作条」自动还回去") .. "|r", GetBindingText(eff, 1)))
                else
                    r.now:SetText(T("LY_SP_NONE", "游戏里也没绑"))
                end
                y = y - 24
            end
        end
        for j = n + 1, #spRows do spRows[j]:Hide() end
        return y - 6
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
            local same = sameAsPlan(r, p)
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
        if views.rotation and views.rotation:IsShown() and self._rotRefresh then self._rotRefresh() end
        if not vr:IsShown() then return end
        rc:SetWidth(math.max(200, rsf:GetWidth() - 4))
        local slots, meta = self:BuildLayoutPlan()
        do
            local fs = self._formPlans or {}
            local st = ""
            if self._formErr then st = "  |cffff4040" .. T("LY_FORM_ST_ERR", "形态页出错") .. "|r"
            elseif #fs > 0 then
                local names = {}
                for _, pg in ipairs(fs) do names[#names + 1] = (pg.label or pg.key):gsub(" ·.*$", "") .. "(" .. (function() local n = 0; for i = 1, 12 do if pg.slots and pg.slots[i] then n = n + 1 end end; return n end)() .. ")" end
                st = "  |cff9ec9ff" .. T("LY_FORM_ST", "形态页") .. " " .. table.concat(names, " / ") .. (self._formBase and ("  · " .. T("LY_FORM_ST_BASE", "主条 1–12 = 人形页")) or "") .. "|r"
            end
            self._formStatus = st
        end
        pvHd:SetText(string.format("%s  |cff888888%s%d · %s%d|r", T("LY_PV_HD", "重铺后的动作条 · 按职能分行"), T("LY_TOTAL", "共 "), meta.total, T("LY_DROP", "放不下 "), math.max(meta.dropped, 0)) .. (self._formStatus or ""))
        local CELL = cellSize()
        -- 撞键统计：同一个推荐键指了几格
        local keyUse = {}
        for _, p in ipairs(slots) do local k = GearInsight.SlotKey(p.slot); if k then keyUse[k] = (keyUse[k] or 0) + 1 end end
        local ci, hi, y = 0, 0, 0
        for _, g in ipairs(meta.groups) do
            if #g.items > 0 then
                hi = hi + 1; hdrPool[hi] = hdrPool[hi] or newHdr(hi)
                local h, cb = hdrPool[hi], hdrCbs[hi]
                cb:ClearAllPoints(); cb:SetPoint("TOPLEFT", -2, y + 3); cb._key = g.key; cb:SetChecked(g.on); cb:SetShown(g.key ~= "skip")   -- 「不进动作条」行没有勾选框：要回条上就右键那个技能 → 恢复自动判断（09-20 用户「为啥不让勾」）
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 20, y); h:SetPoint("RIGHT", rc, "RIGHT", -4, 0); h:SetWordWrap(false); h:Show()
                local col = SRC_COLOR[g.key] or SRC_COLOR.dps
                h:SetText(string.format("|cff%02x%02x%02x%s|r  |cff777777%d%s%s%s|r", col[1] * 255, col[2] * 255, col[3] * 255, g.label, #g.items, T("LY_N_UNIT", " 个"),
                    g.key == "skip" and (" · " .. T("LY_GROUP_SKIP_HINT", "右键技能 → 恢复自动判断 才回到条上")) or (g.on and "" or T("LY_GROUP_OFF", " · 不上条（勾上才占格）")), g.desc ~= "" and ("  · " .. g.desc) or ""))
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
                    local onPage = it.formSlot ~= nil
                    c.icon:SetTexture(icon); c.icon:SetDesaturated((it.slot == nil and not onPage) or (it.item and not it.have) or false)
                    c:SetAlpha(it.off and 0.45 or 1)
                    c:SetBackdropBorderColor(col[1], col[2], col[3], (it.slot or onPage) and 1 or 0.35)
                    c.tal:SetShown(it.talent and true or false); c.talT:SetShown(it.talent and true or false)
                    c.rac:SetShown((it.racial or it.general) and true or false); c.racT:SetShown((it.racial or it.general) and true or false)
                    c.racT:SetText(it.general and T("LY_BADGE_GEN", "通") or T("LY_BADGE_RACIAL", "族"))
                    c.inv:SetShown(it.inv and true or false); c.invT:SetShown(it.inv and true or false)
                    c.pot:SetShown(it.item and true or false); c.potT:SetShown(it.item and true or false)
                    c.macBg:SetShown(it.macro and true or false); c.macT:SetShown(it.macro and true or false)
                    if it.macro then
                        -- 底部标签直接写宏名（用户「不显示宏库了，直接显示宏名」），去掉 GI 前缀省地方
                        local nm = macroNameOf(it):gsub("^GI", "")
                        c.macT:SetText(nm); c:SetBackdropBorderColor(1, 0.82, 0, 1)
                    end
                    if it.macro and it.missing and #it.missing > 0 then c:SetBackdropBorderColor(1, 0.3, 0.3, 1) end
                    local FORM_SHORT = { cat = T("LY_FS_CAT", "猫"), bear = T("LY_FS_BEAR", "熊"), base = T("LY_FS_BASE", "人"), stealth = T("LY_FS_STEALTH", "潜") }
                    c.num:SetText(it.slot and ((self._formBase and it.slot <= 12 and it.page == "main") and (FORM_SHORT[GearInsight.FormRouting and select(2, GearInsight.FormRouting()) or ""] or "") .. it.slot or it.slot) or (onPage and (FORM_SHORT[it.page] or "") .. it.formSlot) or "")
                    local ks = it.slot or it.formSlot
                    if ks then
                        local k = GearInsight.SlotKey(ks)
                        local cur = GetBindingKey(GearInsight.SlotCommand(ks))
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
        -- 形态页（09-20 用户「这样展示」）：每个形态一行 12 格，格号 = 那页真实格号，键 = 主条同位的键
        for _, pg in ipairs(self._formPlans or {}) do
            hi = hi + 1; hdrPool[hi] = hdrPool[hi] or newHdr(hi)
            local h, cb = hdrPool[hi], hdrCbs[hi]
            cb:Hide()
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", 20, y); h:SetPoint("RIGHT", rc, "RIGHT", -4, 0); h:SetWordWrap(false); h:Show()
            local col = SRC_COLOR.form
            h:SetText(string.format("|cff%02x%02x%02x%s · %s|r  |cff777777%s %d–%d · %s%s|r", col[1] * 255, col[2] * 255, col[3] * 255, T("LY_FORM_PAGE", "形态页"), pg.label,
                T("LY_SLOT_WORD", "格"), pg.base, pg.base + 11, T("LY_FORM_PAGE_D", "变成这个形态时主条 1 显示的内容，键与主条同位共用"),
                (pg.dropped or 0) > 0 and string.format("  · %s %d", T("LY_DROP", "放不下 "), pg.dropped) or ""))
            y = y - 18
            for i = 1, 12 do
                local it = pg.slots[i]
                local n = i - 1
                ci = ci + 1; pool[ci] = pool[ci] or newCell()
                local c = pool[ci]
                c:SetSize(CELL, CELL); c:ClearAllPoints(); c:SetPoint("TOPLEFT", (n % COLS) * (CELL + GAP), y - math.floor(n / COLS) * (CELL + GAP)); c:Show()
                c._id, c._inv, c._item, c._role, c._why, c._slot, c._talent, c._pvp, c._macro, c._groupItems, c._it = it and it.id, it and it.inv, it and it.item, it and it.role or "form", it and it.why, i, it and it.talent, it and it.pvp, it and it.macro, nil, it
                local icon
                if it then
                    if it.inv then icon = GetInventoryItemTexture("player", it.inv)
                    elseif it.item then icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.item)
                    elseif it.macro then icon = "Interface\\ICONS\\" .. macroIconOf(it)
                    else icon = (C_Spell.GetSpellInfo(it.id) or {}).iconID end
                end
                c.icon:SetTexture(icon); c.icon:SetDesaturated(false); c:SetAlpha(it and 1 or 0.35)
                c:SetBackdropBorderColor(col[1], col[2], col[3], it and 1 or 0.35)
                c.tal:SetShown(it and it.talent and true or false); c.talT:SetShown(it and it.talent and true or false)
                c.rac:Hide(); c.racT:Hide(); c.inv:SetShown(it and it.inv and true or false); c.invT:SetShown(it and it.inv and true or false)
                c.pot:SetShown(it and it.item and true or false); c.potT:SetShown(it and it.item and true or false)
                c.macBg:SetShown(it and it.macro and true or false); c.macT:SetShown(it and it.macro and true or false)
                if it and it.macro then c.macT:SetText(macroNameOf(it):gsub("^GI", "")) end
                c.num:SetText(tostring(pg.base + i - 1))
                local k = GearInsight.SlotKey(i)
                c.key:SetText(k and shortKey(k) or ""); c.keyBg:SetShown(k ~= nil)
            end
            y = y - math.ceil(12 / COLS) * (CELL + GAP) - 8
        end
        for j = ci + 1, #pool do pool[j]:Hide() end
        for j = hi + 1, #hdrPool do hdrPool[j]:Hide(); if hdrCbs[j] then hdrCbs[j]:Hide() end end
        y = layoutLib(y - 6)
        y = layoutSpecial(y - 4)
        layoutKb()
        rc:SetHeight(-y + 10)
        local planned = {}
        for _, p in ipairs(slots) do planned[p.slot] = p end
        if self._formBase then for i = 1, 12 do planned[i] = self._formBase.slots[i] end end   -- 形态职业：物理主条 = 人形页
        refreshKb(planned, slots)
        nowHd:Hide(); for _, l in ipairs(nowLbls) do l:Hide() end; for _, c in pairs(nowCells) do c:Hide() end
        -- 统计：格子内容差几格（要点「清空重铺」）、键位差几格（要点「设置绑定」）
        local nContent, nKeys = 0, 0
        for _, bar in ipairs(BARS) do
            for sl = bar.from, bar.to do
                local r, p = slotInfo(sl), planned[sl]
                local same = sameAsPlan(r, p)
                if not same then nContent = nContent + 1 end
                local cur, rec = GetBindingKey(GearInsight.SlotCommand(sl)), GearInsight.SlotKey(sl)
                if (cur or "") ~= (rec or "") then nKeys = nKeys + 1 end
            end
        end
        local parts = {}
        if nContent > 0 then parts[#parts + 1] = string.format("|cffffd100%d|r %s", nContent, T("LY_PEND_CONTENT", "格未铺 → 清空重铺")) end
        if nKeys > 0 then parts[#parts + 1] = string.format("|cffffd100%d|r %s", nKeys, T("LY_PEND_KEYS", "格键未生效 → 实现到动作条")) end
        if #parts == 0 then pending:SetText("|cff40c060" .. T("LY_PEND_NONE", "动作条和键位都已和右边一致") .. "|r")
        else pending:SetText(table.concat(parts, "  |cff555555·|r  ")) end
    end
    -- ── 手法 视图（2026-09-19 用户「应该有个基础手法教学…要贴合当前的专精和天赋」「和这个模块好好整合」）──
    --   ① 暴雪官方循环助手（C_AssistedCombat，天赋一换它就换）：现在该按什么 + 整套循环技能，每格下面印你条上的键；
    --   ② 顶尖起手，分「单体（团本，2 人）/ 群怪（大米第一波大包，2 人）」（用户「下方分为群怪和单体…各收录两个人」）；
    --      每人一个「切换天赋」= 一键换成这个人的天赋（PopularTalents 里按 名字+服务器 找同一人的 build）；
    --   ③ 「钉到屏幕」= 战术板 HUD：起手序列 + 该按的格高亮，你放对一个它前进一格（用户「这样用户可以看着按」）；
    --   ④ 教练解读。
    --   ⛔ 只读：GetActionInfo / GetBindingKey / C_AssistedCombat；「现在该按」0.2s ticker，视图不显示就停。
    -- 手法页内容比面板高（起手行数 × 行高 + 教练解读）→ 套一层滚动框，内容不再溢出面板底边（09-20 用户「字体在框体外面了」「兜住」）
    local vsf = CreateFrame("ScrollFrame", nil, pg, "UIPanelScrollFrameTemplate"); vsf:SetPoint("TOPLEFT", 0, -66); vsf:SetPoint("BOTTOMRIGHT", -26, 6); views.rotation = vsf
    local vt = CreateFrame("Frame", nil, vsf); vsf:SetScrollChild(vt); vt:SetSize(700, 900)
    vsf:SetScript("OnSizeChanged", function(_, w) vt:SetWidth(math.max(300, w)) end)
    local rotTicker
    -- 条插件（Bartender4 / Dominos / ElvUI）的键：它们把键绑在自己按钮的 CLICK 命令上，GetBindingKey(ACTIONBUTTONn) 读不到
    --   （09-20 用户「循环务必遵从当前实现的键位」：钉板一直显示黄色推荐键，因为暴雪命令上没键）。只读：按钮的 action 属性 → 格号，keyBoundTarget / CLICK 命令 → 键
    local function addonBarKeys()
        local m = {}
        local function take(btn, name)
            if not btn or not btn.GetAttribute then return end
            local action = btn:GetAttribute("action") or btn._state_action or btn.action
            if type(action) ~= "number" or m[action] then return end
            for _, cmd in ipairs({ btn.keyBoundTarget, "CLICK " .. name .. ":Keybind", "CLICK " .. name .. ":LeftButton", "CLICK " .. name .. ":HOTKEY" }) do
                if cmd then
                    local k = GetBindingKey(cmd)
                    if k then m[action] = k; return end
                end
            end
        end
        for i = 1, 180 do
            take(_G["BT4Button" .. i], "BT4Button" .. i)
            take(_G["DominosActionButton" .. i], "DominosActionButton" .. i)
        end
        for b = 1, 15 do for i = 1, 12 do local n = "ElvUI_Bar" .. b .. "Button" .. i; take(_G[n], n) end end
        return m
    end
    GearInsight.AddonBarKeys = addonBarKeys
    -- 键位表也扫条 6~8（145–180）：玩家的宏 / 技能常放那儿绑 R 之类（09-20 用户「我有个宏是 R，这里能识别吗」）
    local KM_BARS = {}
    for _, b in ipairs(BARS) do KM_BARS[#KM_BARS + 1] = b end
    for _, e in ipairs({ { 145, 156, "MULTIACTIONBAR5BUTTON" }, { 157, 168, "MULTIACTIONBAR6BUTTON" }, { 169, 180, "MULTIACTIONBAR7BUTTON" } }) do
        KM_BARS[#KM_BARS + 1] = { from = e[1], to = e[2], cmd = e[3] }
    end
    local function keyMap()
        local abk = addonBarKeys()
        local function kmKey(sl)
            local cmd = GearInsight.SlotCommand(sl)
            if not cmd then for _, b in ipairs(KM_BARS) do if b.cmd and sl >= b.from and sl <= b.to then cmd = b.cmd .. (sl - b.from + 1) end end end
            return (cmd and GetBindingKey(cmd)) or abk[sl]
        end
        local m, viaMacro = {}, {}
        for _, bar in ipairs(KM_BARS) do
            for sl = bar.from, bar.to do
                local info = slotInfo(sl)
                if info and info.t == "spell" and info.id then
                    local base = (FindBaseSpellByID and FindBaseSpellByID(info.id)) or info.id
                    local cur = kmKey(sl)
                    local rec = GearInsight.SlotKey(sl)
                    -- 同一技能在条上放了两格：有键的那格说了算（09-20 用户：枯萎凋零裸技能在格 4 没键、GI 宏在格 6 绑 4，板子却显示空白）
                    if not m[base] or (not m[base].key and (cur or rec)) then m[base] = { key = cur or rec, real = cur ~= nil, slot = sl } end
                    if info.id ~= base and (not m[info.id] or not m[info.id].key) then m[info.id] = m[base] end
                elseif info and info.t == "item" and info.id then
                    -- 物品格（饰品 / 药水直接放条上）：它的主动技能 → 这格的键（09-19 饰品技能在板子上显示「—」）
                    local _, sid = C_Item.GetItemSpell and C_Item.GetItemSpell(info.id)
                    if sid then
                        local cur = kmKey(sl)
                        local rec = GearInsight.SlotKey(sl)
                        if not m[sid] then m[sid] = { key = cur or rec, real = cur ~= nil, slot = sl, item = info.id } end
                    end
                elseif info and info.t == "macro" and info.name then
                    -- 宏格：正文里每个 /cast /use 的技能都指向这格的键（直接放在条上的技能优先，见下面合并）
                    local idx = GetMacroIndexByName(info.name)
                    local body = idx and idx > 0 and select(3, GetMacroInfo(idx)) or ""
                    local cur = kmKey(sl)
                    local rec = GearInsight.SlotKey(sl)
                    local found, distinct = {}, {}
                    for line in (body or ""):gmatch("[^\n]+") do
                        local cmd, rest = line:match("^/(%S+)%s*(.*)$")
                        if cmd == "cast" or cmd == "castsequence" or cmd == "use" then
                            rest = rest:gsub("%[.-%]", ""):gsub("reset=%S+", ""):gsub("^%s+", "")
                            for raw in rest:gmatch("[^,;]+") do
                                local nm = raw:gsub("^%s+", ""):gsub("%s+$", "")
                                local sp = nm ~= "" and C_Spell.GetSpellInfo(nm)
                                if sp and sp.spellID then
                                    local base = (FindBaseSpellByID and FindBaseSpellByID(sp.spellID)) or sp.spellID
                                    found[#found + 1] = { sp.spellID, base }; distinct[base] = true
                                end
                            end
                        end
                    end
                    local nd = 0; for _ in pairs(distinct) do nd = nd + 1 end
                    -- 单技能宏（鼠标指向 / 条件宏，正文只有这一个技能）优先级高于裸技能格；多技能组合宏只兜底（09-21 用户）
                    for _, f in ipairs(found) do
                        local e = { key = cur or rec, real = cur ~= nil, slot = sl, macro = info.name, single = (nd == 1) }
                        if not viaMacro[f[2]] or (e.single and e.real and not viaMacro[f[2]].single) then viaMacro[f[2]] = e end
                        if not viaMacro[f[1]] or (e.single and e.real and not viaMacro[f[1]].single) then viaMacro[f[1]] = e end
                    end
                end
            end
        end
        -- 裸技能优先于宏，但裸技能那格没键、宏格有键 → 用宏的键（同上）
        -- 形态页（73–108）：键与主条同位共用——只有德 / 贼有形态页，别的职业那是主条翻页，别当成同位键（09-20）
        local _, _cls = UnitClass("player")
        for sl = 73, ((_cls == "DRUID" or _cls == "ROGUE") and 108 or 72) do
            local info = slotInfo(sl)
            if info and info.t == "spell" and info.id then
                local base = (FindBaseSpellByID and FindBaseSpellByID(info.id)) or info.id
                local n = (sl - 1) % 12 + 1
                local cur = GetBindingKey("ACTIONBUTTON" .. n) or abk[sl] or abk[n]
                local rec = GearInsight.SlotKey(n)
                if not m[base] or (not m[base].key and (cur or rec)) then m[base] = { key = cur or rec, real = cur ~= nil, slot = n } end
                if info.id ~= base and (not m[info.id] or not m[info.id].key) then m[info.id] = m[base] end
            end
        end
        for id, e in pairs(viaMacro) do
            if (e.single and e.real) or not m[id] or (not m[id].key and e.key) then m[id] = e end   -- 单技能宏有真键 → 压过裸技能格
        end
        return m
    end
    -- 触发才出现的「替换型」技能 → 它替换的基础技能（同一个键）。FindBaseSpellByID 只在替换生效那一刻才认得，平时查不到（09-19 实测）
    local REPLACES = {
        [433895] = 55090,    -- 吸血鬼打击 → 天灾打击（圣裔）
        [458128] = 85948,    -- 脓疮毒镰 → 脓疮打击（20 层后替换）
    }
    GearInsight.SpellReplaces = REPLACES
    -- 不是职业/天赋技能，是区域、活动或物品给的（顶尖玩家在团本里真按了，但不在任何人的天赋树里）：不算「未学」，也不给键
    local ENV_SPELLS = {
        [1259633] = true,    -- 冲锋！（带头冲锋 · 圣光先锋军志愿者加速，12.x 团本环境技能，09-19 截图）
    }
    GearInsight.EnvSpells = ENV_SPELLS
    local known   -- 下面才定义（keyText 里要用）
    local function keyText(km, id)
        local k = km[id] or km[(FindBaseSpellByID and FindBaseSpellByID(id)) or id] or (REPLACES[id] and km[REPLACES[id]])
        if not k or not k.key then
            if known and not known(id) then return "|cffff5555" .. T("LY_TB_UNLEARNED", "未学") .. "|r" end
            return "|cff888888—|r"
        end
        return (k.real and "|cffffffff" or "|cffffd100") .. shortKey(k.key) .. "|r"
    end
    -- /gikm 技能名或ID：打出键位表里这个技能的来源（排查「为啥没键 / 没认出宏」用）
    GearInsight._gikm = function(msg)
        msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local sp = msg ~= "" and C_Spell.GetSpellInfo(tonumber(msg) or msg)
        if not (sp and sp.spellID) then GearInsight:Print("/gikm 技能名或ID"); return end
        local km = keyMap()
        local id = sp.spellID
        local base = (FindBaseSpellByID and FindBaseSpellByID(id)) or id
        local k = km[id] or km[base] or (REPLACES[id] and km[REPLACES[id]])
        GearInsight:Print(string.format("%s id=%d base=%d known=%s", sp.name, id, base, tostring(known and known(id))))
        -- 计划里在哪：职能行 / 是否上条 / 页 / 格（09-20 用户「狂奔怒吼怎么没进来」）
        local hit
        for _, g in ipairs(GearInsight._lastGroups or {}) do for _, it in ipairs(g.items) do if it.id == id or it.id == base then hit = it; hit._g = g.label end end end
        if hit then GearInsight:Print(string.format("  计划：行=%s role=%s slot=%s page=%s off=%s why=%s formReq=%s", tostring(hit._g), tostring(hit.role), tostring(hit.slot), tostring(hit.page), tostring(hit.off), tostring(hit.why), GearInsight.SpellFormReq and (function() local r = GearInsight.SpellFormReq(id); if not r then return "-" end local t = {}; for k in pairs(r) do t[#t + 1] = k end; return table.concat(t, ",") end)() or "?"))
        else GearInsight:Print("  计划里没有它：法术书 / 天赋树都没把它当成主动技能收进来（被动？没学？覆盖形态 ID？）") end
        local inBook = false
        for _, bid in ipairs(bookSpells() or {}) do if bid == id or bid == base then inBook = true end end
        GearInsight:Print("  法术书兜底列表里：" .. tostring(inBook))
        local at = {}
        for sl = 1, 180 do local r = slotInfo(sl); if r and r.t == "spell" and (r.id == id or r.id == base or ((FindBaseSpellByID and FindBaseSpellByID(r.id)) or r.id) == base) then at[#at + 1] = sl end end
        GearInsight:Print("  现在物理在格：" .. (#at > 0 and table.concat(at, ",") or "无") .. "（1–12 = 主条当前显示的页 · 73–84 猫 · 85–96 猫潜行 · 97–108 熊）" .. (GearInsight.InForm() and " |cffff8000现在在形态里，1–12 就是当前形态页，不是人形页|r" or ""))
        if GearInsight._formPlans then for _, pg in ipairs(GearInsight._formPlans) do for i = 1, 12 do local it2 = pg.slots and pg.slots[i]; if it2 and (it2.id == id or it2.id == base) then GearInsight:Print(string.format("  形态页计划：%s 第 %d 格（物理 %d）", pg.label or pg.key, i, pg.base + i - 1)) end end end end
        if not k then GearInsight:Print("  键位表里没有：条 1~5 / 6~8 上没找到它，也没有 /cast 它的宏"); return end
        GearInsight:Print(string.format("  slot=%s key=%q real=%s macro=%s item=%s", tostring(k.slot), tostring(k.key), tostring(k.real), tostring(k.macro), tostring(k.item)))
        if k.slot then GearInsight:Print(string.format("  cmd=%s bound=%s rec=%s store=%s", tostring(GearInsight.SlotCommand(k.slot)), tostring(GetBindingKey(GearInsight.SlotCommand(k.slot) or "")), tostring(GearInsight.SlotKey(k.slot)), tostring(keyStore()[k.slot]))) end
    end
    local rotSet, knownNames, talentSpells, equippedUse = {}, {}, {}, {}
    -- 身上装备的主动技能：spellID → 装备栏位（饰品 13/14 最常见）
    local function rebuildEquippedUse()
        wipe(equippedUse)
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot)
            if link and C_Item and C_Item.GetItemSpell then
                local _, sid = C_Item.GetItemSpell(link)
                if sid then equippedUse[sid] = slot end
            end
        end
    end
    GearInsight.EquippedUseSpell = function(id) return equippedUse[id] end
    local rebuildKnownNames
    local rt   -- 页面元素表，下面才赋值；known() 里要读 rt._km
    known = function(id)
        if IsPlayerSpell and IsPlayerSpell(id) then return true end
        if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id) then return true end
        if IsSpellKnown and IsSpellKnown(id) then return true end
        local base = FindBaseSpellByID and FindBaseSpellByID(id)
        if base and base ~= id and IsPlayerSpell and IsPlayerSpell(base) then return true end
        if C_SpellBook and C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(id, Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0) then return true end
        if rotSet[id] then return true end
        if talentSpells[id] then return true end
        if REPLACES[id] and IsPlayerSpell(REPLACES[id]) then return true end
        if ENV_SPELLS[id] then return false end   -- 环境技能：客户端查不到你有没有，一律不进序列（09-20 用户「我没有的为啥还在序列里」）
        if equippedUse[id] then return true end
        -- 条上放着的也算（你已经会了才放得上去）
        if rt and rt._km and rt._km[id] then return true end
        -- 按名字：WCL 记的多是效果 / 覆盖 ID，法术书里同名的那条才是你会的
        local nm = C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if nm and knownNames[nm] then return true end
        -- 按名字问客户端：GetSpellInfo(名字) 返回的是你会的那个版本的 ID（09-19 用户：切了天赋仍显示「没有这个技能」）
        local info = nm and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(nm)
        if info and info.spellID and info.spellID ~= id and (IsPlayerSpell(info.spellID) or (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(info.spellID))) then return true end
        return false
    end
    -- 法术书 + 动作条 + 官方循环表 里的技能名集合（每次刷新重建）
    rebuildKnownNames = function(km)
        wipe(knownNames)
        if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
            local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
            for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
                local li = C_SpellBook.GetSpellBookSkillLineInfo(line)
                if li and li.itemIndexOffset and li.numSpellBookItems then
                    for j = li.itemIndexOffset + 1, li.itemIndexOffset + li.numSpellBookItems do
                        local info = C_SpellBook.GetSpellBookItemInfo(j, bank)
                        if info and info.name and not info.isPassive and not info.isOffSpec then knownNames[info.name] = true end
                    end
                end
            end
        end
        for id in pairs(km or {}) do local nm = C_Spell.GetSpellName(id); if nm then knownNames[nm] = true end end
        for id in pairs(rotSet) do local nm = C_Spell.GetSpellName(id); if nm then knownNames[nm] = true end end
        -- 你已点的天赋所授予的技能（含「替换型」技能：吸血鬼打击替换天灾打击、只在触发时出现，法术书里查不到，IsPlayerSpell 也是 false —— 09-19 截图）
        rebuildEquippedUse()
        wipe(talentSpells)
        local cfg = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
        local ci = cfg and C_Traits.GetConfigInfo(cfg)
        for _, treeID in ipairs(ci and ci.treeIDs or {}) do
            for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                local ni = C_Traits.GetNodeInfo(cfg, nodeID)
                if ni and (ni.activeRank or 0) > 0 then
                    local eid = ni.activeEntry and ni.activeEntry.entryID
                    local ei = eid and C_Traits.GetEntryInfo(cfg, eid)
                    local di = ei and ei.definitionID and C_Traits.GetDefinitionInfo(ei.definitionID)
                    if di then
                        if di.spellID then talentSpells[di.spellID] = true end
                        if di.overriddenSpellID then talentSpells[di.overriddenSpellID] = true end
                        if di.overridesSpellID then talentSpells[di.overridesSpellID] = true end
                    end
                end
            end
        end
    end
    -- 顶尖玩家 → PopularTalents 里同一个人的 build（名字 + 服务器；找不到就按名字）
    local function findBuild(player, server)
        local specID = GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()
        local d = specID and GearInsight_GetTalentData and GearInsight_GetTalentData(specID)
        if not (d and d.content and d.pool and d.dict) then return nil end
        local byName
        for _, cat in pairs(d.content) do
            for _, enc in ipairs(cat) do
                for _, ref in ipairs(enc.list or {}) do
                    if ref.player == player then
                        if ref.server == server then return d, ref end
                        byName = byName or ref
                    end
                end
            end
        end
        if byName then return d, byName end
        return nil
    end
    local function cell(parent, size)
        local c = CreateFrame("Frame", nil, parent, "BackdropTemplate"); c:SetSize(size, size)
        c:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); c:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetPoint("TOPLEFT", 1, -1); c.icon:SetPoint("BOTTOMRIGHT", -1, 1); c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        c.key = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.key:SetPoint("TOP", c, "BOTTOM", 0, -1)
        c.num = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); c.num:SetPoint("TOPLEFT", 2, -1)
        c:EnableMouse(true)
        -- 起手序列格：左键（钉板上）= 跳到这一步；右键 = 删掉 / 恢复这一步（09-20 群友）
        c:SetScript("OnMouseUp", function(x, btn)
            if not (x._id and x._key and x._raw) then return end
            if btn == "RightButton" then GearInsight.ShowSeqStepMenu(x, x._key, x._raw, x._id, x._hud)
            elseif btn == "LeftButton" and x._hud then local f = x:GetParent(); if f and f.Redraw then f._cur = x._hud; f:Redraw() end end
        end)
        c:SetScript("OnEnter", function(x)
            if not x._id then return end
            GameTooltip:SetOwner(x, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(x._id)
            if x._key and x._raw then
                local skipped = GearInsight.TacticSkip(x._key)[x._raw]
                if skipped then GameTooltip:AddLine(T("LY_SEQ_SKIPPED", "这一步你已删掉（右键恢复）"), 1, 0.35, 0.35, true)
                else GameTooltip:AddLine(x._hud and T("LY_SEQ_CELL_TIP_HUD", "左键：跳到这一步 · 右键：删掉这一步") or T("LY_SEQ_CELL_TIP", "右键：删掉这一步（钉板上就不再等它）"), 0.6, 0.6, 0.6, true) end
            end
            local km = (x:GetParent() and x:GetParent()._km) or {}
            local k = km[x._id] or km[(FindBaseSpellByID and FindBaseSpellByID(x._id)) or x._id]
            local eqSlot = GearInsight.EquippedUseSpell and GearInsight.EquippedUseSpell(x._id)
            if eqSlot then
                GameTooltip:AddLine(" ")
                local link = GetInventoryItemLink("player", eqSlot)
                GameTooltip:AddLine(string.format(T("LY_TB_TRINKET", "这是你身上 %s 的主动技能（装备栏 %d）。"), link or "?", eqSlot) .. (not (k and k.key) and ("  " .. T("LY_TB_TRINKET_NOKEY", "它不在条上：去替换页把饰品格铺上去就有键了")) or ""), 0.6, 0.8, 1, true)
            elseif GearInsight.EnvSpells and GearInsight.EnvSpells[x._id] then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(T("LY_TB_ENV", "这不是职业技能，是区域 / 活动 / 物品给的（顶尖玩家在团本里按了）。不会进你的战术板序列。"), 0.6, 0.8, 1, true)
            elseif not known(x._id) then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(T("LY_TB_NOT_KNOWN", "你现在没有这个技能（他的天赋点了、你没点）。替换页只列你会的技能，所以那里看不到；点手法页「切换成他的天赋」就有了。"), 1, 0.35, 0.35, true)
            elseif not (k and k.key) then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(T("LY_TB_NO_KEY", "你会这个技能，但它不在动作条上，也没绑键。去「键位手法 → 替换」把它放上去。"), 1, 0.82, 0, true)
            elseif k.macro then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format(T("LY_TB_VIA_MACRO", "这个键按的是宏「%s」，里面包含它。"), k.macro), 0.6, 0.8, 1, true)
            end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return c
    end

    -- ── 战术板 HUD（钉到屏幕）──
    local hud
    local function ensureHud()
        if hud then return hud end
        local f = CreateFrame("Frame", "GearInsightTacticBoard", UIParent, "BackdropTemplate")
        f:SetSize(560, 136)   -- 22 标题 + 44 格 + 22 键帽(大) + 标注行 + 底边留白（09-19「间歇拉开点」）
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.04, 0.05, 0.08, 0.85); f:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.5)
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true); f:SetFrameStrata("MEDIUM")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", function(x) x:StopMovingOrSizing(); local pt, _, rp, px, py = x:GetPoint(); GearInsightDB = GearInsightDB or {}; GearInsightDB.tacticPos = { pt, rp, px, py } end)
        local pos = GearInsightDB and GearInsightDB.tacticPos
        if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", UIParent, "CENTER", 0, -260) end
        -- 缩放（09-20 群友「这玩意能不能缩小点」）：Ctrl+滚轮 ±5%，右键标题栏出档位菜单；存 GearInsightDB.tacticScale
        local function setScale(v)
            v = math.max(0.5, math.min(1.5, math.floor(v * 20 + 0.5) / 20))
            GearInsightDB = GearInsightDB or {}; GearInsightDB.tacticScale = v
            f:SetScale(v)
        end
        f:SetScale((GearInsightDB and GearInsightDB.tacticScale) or 1)
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel", function(_, d) if IsControlKeyDown() then setScale(f:GetScale() + d * 0.05) end end)
        f:SetScript("OnMouseUp", function(_, btn)
            if btn ~= "RightButton" or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
            MenuUtil.CreateContextMenu(f, function(_, root)
                root:CreateTitle(T("LY_TB_SCALE", "大小"))
                for _, v in ipairs({ 0.6, 0.7, 0.8, 0.9, 1, 1.15, 1.3 }) do
                    root:CreateRadio(string.format("%d%%", v * 100), function() return math.abs(f:GetScale() - v) < 0.01 end, function() setScale(v) end)
                end
                root:CreateDivider()
                root:CreateButton(T("LY_TB_SCALE_TIP", "Ctrl + 滚轮也能调"), function() end)
            end)
        end)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.title:SetPoint("TOPLEFT", 8, -5); f.title:SetPoint("RIGHT", -104, 0); f.title:SetJustifyH("LEFT"); f.title:SetWordWrap(false)
        f.chrome = { f.title }   -- 收起态（只看助手）这些只在鼠标悬停时出现，平时是一块无标题的 HUD（09-21 用户「这个展示还是不太好」）
        -- 「−」「+」两个小钮（09-20 用户「调整窗口大小的提示没有，还是弄两个按钮吧」）：每次 ±10%，悬浮提示写着还能 Ctrl+滚轮 / 右键档位
        for i, d in ipairs({ { "-", -0.1, -84 }, { "+", 0.1, -64 } }) do
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); b:SetSize(18, 16); b:SetPoint("TOPRIGHT", d[3], -3); b:SetText(d[1])
            b:SetScript("OnClick", function() setScale(f:GetScale() + d[2]) end)
            b:SetScript("OnEnter", function(x) GameTooltip:SetOwner(x, "ANCHOR_TOP"); GameTooltip:SetText(string.format("%s %d%%", T("LY_TB_SCALE", "大小"), f:GetScale() * 100 + 0.5) .. "\n|cff888888" .. T("LY_TB_SCALE_TIP", "Ctrl + 滚轮也能调") .. "|r", 1, 0.82, 0, 1, true); GameTooltip:Show() end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.chrome[#f.chrome + 1] = b; if i == 1 then f.btnMinus = b else f.btnPlus = b end
        end
        local x = CreateFrame("Button", nil, f, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", 2, 2); x:SetScale(0.7); f.chrome[#f.chrome + 1] = x; f.btnX = x
        -- X = 关掉并记住（GearInsightDB.tacticBoardOn=false），登录 / 换装 / 删步都不再自动读出来；序列本身留着，手法页勾回来就原样回来（09-20 用户「要能手动关闭，并且不会自动读取出来」）
        x:SetScript("OnClick", function() f:Hide(); GearInsightDB = GearInsightDB or {}; GearInsightDB.tacticBoardOn = false; if GearInsight._rotRefresh then GearInsight._rotRefresh() end end)
        local rs = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); rs:SetSize(40, 16); rs:SetPoint("TOPRIGHT", -22, -3); rs:SetText(T("LY_TB_RESET", "重来")); f.resetBtn = rs; f.chrome[#f.chrome + 1] = rs
        rs:SetScript("OnClick", function() f._cur = 1; f:Redraw() end)
        rs:SetScript("OnEnter", function(b) GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(T("LY_TB_RESET_TIP", "把起手序列拨回第 1 步（练起手用；脱战 6 秒也会自动回到第 1 步）"), 1, 0.82, 0, 1, true); GameTooltip:Show() end)
        rs:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- 「现在该按」（暴雪助手）大格 + 序列小格
        f.next = cell(f, 44); f.next:SetPoint("TOPLEFT", 8, -22); f.next.icon:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark")
        -- 冷却扇形（原生 Cooldown 帧）：转完自动消失，比「CD 120s」一行字直观（09-21）
        f.next.cdf = CreateFrame("Cooldown", nil, f.next, "CooldownFrameTemplate"); f.next.cdf:SetAllPoints(f.next.icon)
        f.next.cdf:SetDrawEdge(false); f.next.cdf:SetHideCountdownNumbers(true); f.next.cdf:SetSwipeColor(0, 0, 0, 0.7)
        -- 「接下来 3 个」小灰格：有起手序列时是序列后 3 步；序列打完 / 没序列时是暴雪循环表里下一批能放的候选（只有下一个是暴雪算的，后面是候选，标「候选」）
        f.q = {}
        for i = 1, 3 do
            local q = CreateFrame("Frame", nil, f, "BackdropTemplate"); q:SetSize(26, 26)
            q:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); q:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
            q.icon = q:CreateTexture(nil, "ARTWORK"); q.icon:SetPoint("TOPLEFT", 1, -1); q.icon:SetPoint("BOTTOMRIGHT", -1, 1); q.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); q.icon:SetDesaturated(true)
            -- 小格键帽：右下角一枚小牌（09-21 用户「下一个的按键键帽也没有」）
            q.keyBg = q:CreateTexture(nil, "OVERLAY"); q.keyBg:SetColorTexture(0, 0, 0, 0.8); q.keyBg:SetPoint("BOTTOMRIGHT", 1, -1)
            q.key = q:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); q.key:SetPoint("BOTTOMRIGHT", -1, 0); q.key:SetTextColor(1, 0.85, 0.3)
            q.pct = q:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); q.pct:SetPoint("TOPLEFT", 1, -1); q.pct:SetTextColor(0.75, 0.9, 1)
            q:SetAlpha(0.7 - (i - 1) * 0.15)
            q.ag = q:CreateAnimationGroup()
            local tr = q.ag:CreateAnimation("Translation"); tr:SetOffset(-30, 0); tr:SetDuration(0.18); tr:SetSmoothing("OUT")   -- 从右边一格的位置滑到自己的位置（传送带）
            q.ag:SetScript("OnFinished", function() q:ClearAllPoints(); q:SetPoint("BOTTOMLEFT", f.next, "BOTTOMRIGHT", 6 + (i - 1) * 30, 0) end)
            q:Hide(); f.q[i] = q
        end
        -- 大图标换技能：弹一下（1.18 → 1）
        f.next.pop = f.next:CreateAnimationGroup()
        do
            local s1 = f.next.pop:CreateAnimation("Scale"); s1:SetScale(1.18, 1.18); s1:SetDuration(0.06); s1:SetOrder(1); s1:SetOrigin("CENTER", 0, 0)
            local s2 = f.next.pop:CreateAnimation("Scale"); s2:SetScale(1 / 1.18, 1 / 1.18); s2:SetDuration(0.12); s2:SetOrder(2); s2:SetOrigin("CENTER", 0, 0)
        end
        do local _ = nil
        end
        f.qLbl = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f.qLbl:Hide()
        -- 「助手」两个字挪到格子上方小字，键帽在格子下方（原来两个叠一起）
        -- 「助手」小字和标题「GI 循环助手」叠在一起（09-19 截图）→ 干脆不要，标题已经说明了
        f.nextLbl = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f.nextLbl:SetPoint("BOTTOMLEFT", f.next, "TOPLEFT", 0, 1); f.nextLbl:SetText(""); f.nextLbl:Hide()
        -- 左「暴雪助手」/ 右「推荐序列」：竖分隔线 + 底部两行小字（用户 2026-09-19「一个官方一个推荐，标注或隔离下」）
        f.divider = f:CreateTexture(nil, "ARTWORK"); f.divider:SetColorTexture(1, 1, 1, 0.12); f.divider:SetSize(1, 100)
        f.capA = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f.capA:SetJustifyH("CENTER")
        f.capB = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f.capB:SetJustifyH("LEFT"); f.capB:SetWordWrap(false)
        f.cells = {}
        -- 当前该按的格：金色呼吸光 + 粗大键位字（用户 2026-09-19「正要进行的技能加个高亮」「按钮按啥，粗体」）
        local function glowOn(c)
            if not c.glow then
                c.glow = c:CreateTexture(nil, "OVERLAY", nil, 7)
                c.glow:SetPoint("TOPLEFT", -8, 8); c.glow:SetPoint("BOTTOMRIGHT", 8, -8)
                c.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); c.glow:SetBlendMode("ADD"); c.glow:SetVertexColor(1, 0.82, 0, 0.9)
                c.glow:SetTexCoord(0.2, 0.8, 0.2, 0.8)
                c.ag = c.glow:CreateAnimationGroup(); c.ag:SetLooping("BOUNCE")
                local a = c.ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.35); a:SetToAlpha(1); a:SetDuration(0.45)
            end
            c.glow:Show(); if not c.ag:IsPlaying() then c.ag:Play() end
        end
        local function glowOff(c) if c.glow then c.ag:Stop(); c.glow:Hide() end end
        -- 键帽（用户 2026-09-19「做出键盘按键效果」）
        local MOD_CAP = { SHIFT = "s-", CTRL = "c-", ALT = "a-" }
        local function capParts(keyRaw)
            -- 一枚键帽：修饰键缩成 s- / c- / a-（暴雪原生写法），不再拆成两层叠着（09-20 用户「面板优化」）
            if not keyRaw then return { "—" } end
            local parts = {}
            for tok in keyRaw:gmatch("[^%-]+") do parts[#parts + 1] = tok end
            local out = ""
            for i, tok in ipairs(parts) do
                if i < #parts and MOD_CAP[tok] then out = out .. MOD_CAP[tok]
                else out = out .. (shortKey(tok):gsub("空格键", "Sp"):gsub("空白鍵", "Sp"):gsub("Space", "Sp")) end
            end
            return { out }
        end
        local function ensureCaps(c, n)
            c.caps = c.caps or {}
            for i = 1, n do
                if not c.caps[i] then
                    local k = CreateFrame("Frame", nil, c, "BackdropTemplate")
                    k:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                    k.hi = k:CreateTexture(nil, "ARTWORK"); k.hi:SetPoint("TOPLEFT", 1, -1); k.hi:SetPoint("TOPRIGHT", -1, -1); k.hi:SetHeight(2); k.hi:SetColorTexture(1, 1, 1, 0.18)
                    k.fs = k:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); k.fs:SetPoint("CENTER", 0, -1)
                    k.flash = k:CreateTexture(nil, "OVERLAY"); k.flash:SetAllPoints(); k.flash:SetColorTexture(1, 1, 1, 0.7); k.flash:Hide()
                    k.ag = k:CreateAnimationGroup()
                    local s1 = k.ag:CreateAnimation("Scale"); s1:SetScale(0.85, 0.85); s1:SetDuration(0.07); s1:SetOrder(1); s1:SetOrigin("CENTER", 0, 0)
                    local s2 = k.ag:CreateAnimation("Scale"); s2:SetScale(1 / 0.85, 1 / 0.85); s2:SetDuration(0.1); s2:SetOrder(2); s2:SetOrigin("CENTER", 0, 0)
                    local fa = k.ag:CreateAnimation("Alpha"); fa:SetChildKey("flash"); fa:SetFromAlpha(1); fa:SetToAlpha(0); fa:SetDuration(0.17); fa:SetOrder(1)
                    k.ag:SetScript("OnPlay", function() k.flash:Show() end); k.ag:SetScript("OnFinished", function() k.flash:Hide() end)
                    c.caps[i] = k
                end
            end
            for i = n + 1, #c.caps do c.caps[i]:Hide() end
        end
        local function drawCaps(c, keyRaw, hot)
            local parts = capParts(keyRaw)
            ensureCaps(c, #parts)
            c.key:SetText("")
            local h = hot and 22 or 15
            local font = hot and "GameFontNormal" or "GameFontHighlightSmall"
            local total, ws = 0, {}
            for i, txt in ipairs(parts) do
                local k = c.caps[i]; k.fs:SetFontObject(font); k.fs:SetText(txt)
                local w = math.min(math.max(h + 2, math.floor(k.fs:GetStringWidth() + 10)), math.floor((c:GetWidth() or 40) + 6)); ws[i] = w; total = total + w + (i > 1 and 5 or 0)   -- 封顶到格宽，再长就截断别压邻格
            end
            local limit = (c:GetWidth() or 34) + 6
            local stack = #parts > 1 and total > limit
            local x = -total / 2
            for i, txt in ipairs(parts) do
                local k = c.caps[i]
                k:ClearAllPoints(); k:SetSize(ws[i], h); k.fs:SetWidth(ws[i] - 4); k.fs:SetWordWrap(false)   -- 文字随键帽截断
                if stack then
                    -- 两层：每层居中，行高 h+2
                    k:SetPoint("TOP", c, "BOTTOM", 0, -3 - (i - 1) * (h + 2))
                else
                    k:SetPoint("TOPLEFT", c, "BOTTOM", x, -3); x = x + ws[i] + 5
                end
                if hot then k:SetBackdropColor(1, 0.82, 0, 1); k:SetBackdropBorderColor(1, 0.95, 0.6, 1); k.fs:SetTextColor(0.1, 0.08, 0.02)
                else k:SetBackdropColor(0.1, 0.11, 0.15, 1); k:SetBackdropBorderColor(0.45, 0.45, 0.5, 1); k.fs:SetTextColor(0.85, 0.85, 0.9) end
                k:Show()
            end
        end
        local function pressCaps(c) if c.caps then for _, k in ipairs(c.caps) do if k:IsShown() then k.ag:Stop(); k.ag:Play() end end end end
        local function rawKey(km, id)
            local k = km[id] or km[(FindBaseSpellByID and FindBaseSpellByID(id)) or id] or (GearInsight.SpellReplaces[id] and km[GearInsight.SpellReplaces[id]])
            return (k and k.real) and k.key or nil   -- 键帽只显示当前真绑的键，推荐键不上（09-21 用户「只显示当前存在的」）
        end
        function f:Redraw()
            local seq = self._seq or {}
            local km = self._km or {}
            local size, gap, x0 = 34, 4, 78
            -- 滚动窗口：一次最多亮 VIS 格，当前格尽量排在第 2 位，前面留 1 格「刚按过的」；打到后面整排往左滑
            local VIS, nAll, cur = 8, #seq, (self._cur or 1)
            local first = math.max(1, math.min(cur - 1, nAll - VIS + 1))
            self._first = first
            for i = 1, 16 do
                local c = self.cells[i] or cell(self, size); self.cells[i] = c
                local sid = seq[i]
                local pos = i - first + 1
                if sid and pos >= 1 and pos <= VIS then
                    c._id = sid; c._key = self._key; c._raw = self._map and self._map[i] or i; c._hud = i
                    c:ClearAllPoints(); c:SetPoint("TOPLEFT", x0 + (pos - 1) * (size + gap), -22)
                    c.icon:SetTexture(C_Spell.GetSpellTexture(sid)); c.icon:SetDesaturated(i < (self._cur or 1))
                    c.key:SetText(keyText(km, sid)); c.num:SetText(tostring(i)); c:Show()
                    if i == (self._cur or 1) then
                        c:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1); c:SetAlpha(1); glowOn(c)
                        drawCaps(c, rawKey(km, sid), true)
                    else
                        c:SetBackdropBorderColor(0.3, 0.3, 0.3, 1); c:SetAlpha(i < (self._cur or 1) and 0.45 or 0.9); glowOff(c)
                        drawCaps(c, rawKey(km, sid), false)
                    end
                else c:Hide(); glowOff(c) end
            end
            local n = #seq
            local done = (self._cur or 1) > n and n > 0
            if not self.hint then
                self.hint = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); self.hint:SetJustifyH("LEFT"); self.hint:SetWordWrap(false)
                self.cd = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); self.cd:SetJustifyH("LEFT")
            end
            self.hint:ClearAllPoints(); self.cd:ClearAllPoints()
            if n == 0 or done then
                for _, c in ipairs(self.cells) do c:Hide(); glowOff(c) end   -- 打完起手：格子收起，只剩助手横排（09-20 用户「考虑打完起手队列的情况」）
                -- 紧凑：格子靠左，名字 + 冷却在右侧两行；宽度按名字自适应
                -- 只看助手：一条横排 [图标][名字 / 状态][键帽]，高 78，宽按内容（09-20 用户「有点丑」；动感超人「下面留白」）
                -- 09-21 重做：无标题 HUD（标题 / 按钮悬停才出现），高 62；[大图标+冷却扇形+键帽][名字 / 状态][接下来 3 个小灰格]
                -- 09-21 二改：文字放图标下面，3 个小格紧挨着大图标（用户「这个文字放下面」「待释放技能紧挨着主技能」）
                self:SetHeight(92); self:SetWidth(self._compactW or 200)   -- 先按上次算的宽度画，别先 560 再缩（09-20 用户「刚切入会很大，然后缩小」）
                -- 全部居中（09-21 用户「居中一下，文字扩展也从中间展开」）：图标居中，名字 / 状态居中排在下面；有序列小格时图标组整体居中
                local nq = 0; for _, q in ipairs(self.q) do if q:IsShown() then nq = nq + 1 end end
                local groupW = 44 + (nq > 0 and (6 + nq * 30 - 4) or 0)
                self.next:ClearAllPoints(); self.next:SetPoint("TOP", self, "TOP", -(groupW - 44) / 2, -9)
                self.hint:SetPoint("TOP", self.next, "BOTTOM", (groupW - 44) / 2, -4); self.hint:SetWidth(0); self.hint:SetJustifyH("CENTER")
                self.cd:SetPoint("TOP", self.hint, "BOTTOM", 0, -2); self.cd:SetJustifyH("CENTER")   -- 「就绪 / 冷却」放技能名正下方（09-21 用户）
                for i, q in ipairs(self.q) do q:ClearAllPoints(); q:SetPoint("BOTTOMLEFT", self.next, "BOTTOMRIGHT", 6 + (i - 1) * 30, 0) end
                self.qLbl:ClearAllPoints(); self.qLbl:SetPoint("BOTTOM", self.q[2], "TOP", 0, 1)   -- 标签居中放在三个小格正上方（09-21 用户「节省点空间」）
                -- 悬停时的 ± / 关闭 / 重来 排在卡片上沿外面一条，不压图标和小格（09-21 截图「标题被挡住」）；标题在收起态不显示
                self.btnX:ClearAllPoints(); self.btnX:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 4, -2)
                self.btnPlus:ClearAllPoints(); self.btnPlus:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -20, 0)
                self.btnMinus:ClearAllPoints(); self.btnMinus:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -40, 0)
                if self.resetBtn then self.resetBtn:ClearAllPoints(); self.resetBtn:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -62, 0) end
                self.title:SetAlpha(0)
                self._compact = true; self._done = done
                self.hint:Show(); self.cd:Show()
                if self.resetBtn then self.resetBtn:Hide() end
            else
                self:SetWidth(math.max(300, x0 + math.min(VIS, n) * (size + gap) + 8)); self:SetHeight(136); self._compact = nil; self._done = done
                for _, q in ipairs(self.q) do q:Hide() end; self.qLbl:Hide()
                for _, o in ipairs(self.chrome) do o:SetAlpha(1); if o.EnableMouse then o:EnableMouse(true) end end
                self.btnX:ClearAllPoints(); self.btnX:SetPoint("TOPRIGHT", 2, 2)
                self.btnPlus:ClearAllPoints(); self.btnPlus:SetPoint("TOPRIGHT", -64, -3)
                self.btnMinus:ClearAllPoints(); self.btnMinus:SetPoint("TOPRIGHT", -84, -3)
                if self.resetBtn then self.resetBtn:ClearAllPoints(); self.resetBtn:SetPoint("TOPRIGHT", -22, -3) end
                self.next:ClearAllPoints(); self.next:SetPoint("TOPLEFT", 8, -22)
                self.hint:Hide(); self.cd:Hide()
                if self.resetBtn then self.resetBtn:Show() end
            end
            -- 分隔线 + 标注：只在有序列时显示
            self.divider:ClearAllPoints(); self.divider:SetPoint("TOPLEFT", x0 - 9, -22)
            self.capA:ClearAllPoints(); self.capA:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 6, -128); self.capA:SetWidth(66)
            self.capA:SetText("|cff9ec9ff" .. T("LY_TB_CAP_ASSIST", "常规循环") .. "|r")
            self.capB:ClearAllPoints(); self.capB:SetPoint("BOTTOMLEFT", self, "TOPLEFT", x0, -128); self.capB:SetWidth(math.max(120, math.min(VIS, n) * (size + gap)))
            local more = ""
            if n > VIS then more = string.format("  |cff666666%s|r", (first > 1 and "‹ " or "") .. string.format(T("LY_TB_WINDOW", "第 %d–%d 步 / 共 %d"), first, math.min(n, first + VIS - 1), n) .. (first + VIS - 1 < n and " ›" or "")) end
            self.capB:SetText("|cffe2b85c" .. T("LY_TB_CAP_SEQ", "起手序列") .. "|r" .. (self._who and ("  |cff888888" .. self._who .. "|r") or "") .. more)
            self.divider:SetShown(n > 0 and not done); self.capA:SetShown(n > 0 and not done); self.capB:SetShown(n > 0 and not done)
            -- 标题固定「GI 循环助手」（用户 2026-09-19）；后面小字：选的谁的序列 · 进度；打完只留助手
            local who = ""
            self.title:SetText("|cffe2b85c" .. T("LY_TB_TITLE", "GI 循环助手") .. "|r" .. who .. (done and ("  |cff40c060" .. T("LY_TB_DONE", "起手打完 · 接主循环") .. "|r") or (n > 0 and string.format("  |cff888888%d / %d|r", math.min(self._cur or 1, n), n) or "")))
            if done and self.resetBtn then self.resetBtn:Show() end   -- 打完仍留「重来」，练起手用
        end
        -- 你放对了序列里当前这一个 → 前进一格（本体 / 覆盖技能都认）
        f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:RegisterEvent("UPDATE_BINDINGS"); f:RegisterEvent("ACTIONBAR_SLOT_CHANGED"); f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED"); f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        f:SetScript("OnEvent", function(self, event, _, _, spellID)
            if event == "PLAYER_EQUIPMENT_CHANGED" then
                if self._kmQueued or InCombatLockdown() then return end
                self._kmQueued = true
                C_Timer.After(0.5, function()
                    self._kmQueued = nil
                    local tp = GearInsightDB and GearInsightDB.tacticPinned
                    if self:IsShown() and tp and tp.seq and #tp.seq > 0 then GearInsight:PinTacticBoard(tp.title, tp.seq, tp.key) end
                end)
                return
            end
            if event == "UPDATE_BINDINGS" or event == "ACTIONBAR_SLOT_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
                if self._kmQueued then return end
                self._kmQueued = true
                C_Timer.After(0.2, function() self._kmQueued = nil; if self:IsShown() then self._km = keyMap(); self._lastNext = nil; self:Redraw() end end)
                return
            end
            if event == "PLAYER_REGEN_ENABLED" then
                C_Timer.After(6, function() if not InCombatLockdown() then self._cur = 1; self:Redraw() end end)   -- 脱战 6 秒后自动重来
                return
            end
            if spellID and not (issecretvalue and issecretvalue(spellID)) then self._lastCast = (FindBaseSpellByID and FindBaseSpellByID(spellID)) or spellID; self._lastCastAt = GetTime() end
            if spellID and not (issecretvalue and issecretvalue(spellID)) and self.next and self.next._id then
                -- 按下的正是助手说的这个：键帽按压 + 大图标弹一下（收起态的反馈）
                local b1 = (FindBaseSpellByID and FindBaseSpellByID(spellID)) or spellID
                local b2 = (FindBaseSpellByID and FindBaseSpellByID(self.next._id)) or self.next._id
                if spellID == self.next._id or b1 == b2 then pressCaps(self.next); if self.next.pop then self.next.pop:Stop(); self.next.pop:Play() end end
            end
            local seq = self._seq; if not seq or not spellID or (issecretvalue and issecretvalue(spellID)) then return end
            local want = seq[self._cur or 1]; if not want then return end
            local base = (FindBaseSpellByID and FindBaseSpellByID(spellID)) or spellID
            local wbase = (FindBaseSpellByID and FindBaseSpellByID(want)) or want
            if spellID == want or base == wbase then
                local c = self.cells[self._cur or 1]; if c then pressCaps(c) end
                C_Timer.After(0.12, function() self._cur = (self._cur or 1) + 1; self:Redraw() end)
            end
        end)
        -- 助手在没进战斗时常给 nil：有可攻击目标就退回「循环表里第一个现在能放的」（JustAC 同款做法）
        local function nextSpell()
            if not (C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then return nil end
            local ok, id = pcall(C_AssistedCombat.GetNextCastSpell, false)
            if ok and id and not (issecretvalue and issecretvalue(id)) then return id end
            if UnitExists("target") and UnitCanAttack("player", "target") and C_AssistedCombat.GetRotationSpells then
                local ok2, list = pcall(C_AssistedCombat.GetRotationSpells)
                if ok2 and list then
                    for _, sid in ipairs(list) do
                        local usable = C_Spell.IsSpellUsable and C_Spell.IsSpellUsable(sid)
                        local cd = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(sid)
                        if usable and not (cd and cd.startTime and cd.startTime > 0 and cd.duration and cd.duration > 1.6) then return sid end
                    end
                end
            end
            return nil
        end
        -- 技能真实冷却剩余秒数（不算 GCD；有充能的按充能：还有一发就不算 CD）；保密值 / 不可用返回 nil
        local function cdLeft(sid)
            if not (sid and C_Spell.GetSpellCooldown) then return nil end
            local ch = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(sid)
            if ch and ch.maxCharges and ch.maxCharges > 1 then
                if issecretvalue and (issecretvalue(ch.currentCharges) or issecretvalue(ch.cooldownStartTime) or issecretvalue(ch.cooldownDuration)) then return nil end
                if (ch.currentCharges or 0) > 0 then return nil end
                local left = (ch.cooldownStartTime or 0) + (ch.cooldownDuration or 0) - GetTime()
                return left > 0 and left or nil
            end
            local cd = C_Spell.GetSpellCooldown(sid)
            if not cd then return nil end
            local st, du = cd.startTime or 0, cd.duration or 0
            if issecretvalue and (issecretvalue(st) or issecretvalue(du)) then return nil end
            if st > 0 and du > 1.6 then local left = st + du - GetTime(); if left > 0 then return left end end
            return nil
        end
        local function tickBody()
            if not f:IsShown() then return end
            -- 序列格：在 CD 的直接灰 + 图标上写倒计时；当前格在 CD 上就滚过去（09-20 用户「凡是在 CD 的直接显示灰色…滚到直接滚过去」）
            local seq = f._seq or {}
            if #seq > 0 then
                local cur, guard = f._cur or 1, 0
                while seq[cur] and cdLeft(seq[cur]) and guard < #seq do cur = cur + 1; guard = guard + 1 end
                if cur ~= (f._cur or 1) and cur <= #seq then f._cur = cur; f:Redraw() end
                for i, c in ipairs(f.cells) do
                    if c:IsShown() and c._id then
                        local left = cdLeft(c._id)
                        if not c.cdText then c.cdText = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); c.cdText:SetPoint("CENTER", 0, 0); c.cdText:SetTextColor(1, 0.9, 0.3) end
                        if left then
                            c.icon:SetDesaturated(true); c.cdText:SetText(left >= 10 and string.format("%d", math.floor(left + 0.5)) or string.format("%.1f", left)); c.cdText:Show()
                        else
                            c.icon:SetDesaturated(i < (f._cur or 1)); c.cdText:Hide()
                        end
                    elseif c.cdText then c.cdText:Hide() end
                end
            end
            local id = nextSpell()
            if id then
                f.next._id = id; f.next.icon:SetTexture(C_Spell.GetSpellTexture(id)); f.next:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
                drawCaps(f.next, rawKey(f._km or {}, id), not f._compact)   -- 收起态用小号键帽，塞在图标角上（09-21 用户「数字出黄框了」）
                f._lastNext = f.next._id
                -- 冷却扇形 + 呼吸光：战斗中且就绪才亮（09-21「该按的时候会亮」）
                local cdn = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(id)
                local cst, cdu = cdn and cdn.startTime or 0, cdn and cdn.duration or 0
                if f.next.cdf then
                    if not (issecretvalue and (issecretvalue(cst) or issecretvalue(cdu))) and cst > 0 and cdu > 1.6 then f.next.cdf:SetCooldown(cst, cdu) else f.next.cdf:Clear() end
                end
                if not cdLeft(id) then glowOn(f.next) else glowOff(f.next) end   -- 就绪就亮（09-21 用户「使用都不高亮了」）
                -- 助手说该按的正好是序列里当前这个 → 那格闪金底
                local cur = f.cells[f._cur or 1]
                if cur and cur:IsShown() and cur._id and ((FindBaseSpellByID and FindBaseSpellByID(cur._id)) or cur._id) == ((FindBaseSpellByID and FindBaseSpellByID(id)) or id) then cur:SetBackdropColor(1, 0.82, 0, 0.35) else for _, c in ipairs(f.cells) do c:SetBackdropColor(0, 0, 0, 0) end end
            else
                f.next._id = nil; f._lastNext = nil; glowOff(f.next); f.next.icon:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark"); f.next.key:SetText(""); f.next:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                if f.next.cdf then f.next.cdf:Clear() end
                if f.next.caps then for _, k in ipairs(f.next.caps) do k:Hide() end end
            end
            if f._compact then
                -- 标题 / ± / 关闭 / 重来：只在鼠标悬停时出现，平时是一块干净的 HUD
                local over = f:IsMouseOver()   -- 12.x 没有全局 MouseIsOver（09-21 报错 3904 attempt to call a nil value）
                for _, o in ipairs(f.chrome) do
                    local show = over and o ~= f.title and (o ~= f.resetBtn or f._done)
                    o:SetAlpha(show and 1 or 0); if o.EnableMouse then o:EnableMouse(show and true or false) end
                end
                -- 「接下来」：序列没打完 → 序列后 3 步；否则 → 暴雪循环表里除当前外能放的前 3 个（候选）
                local qlist, qFromSeq = f._qlist or {}, f._qFromSeq
                local seq2 = f._seq or {}
                if #seq2 > 0 and not f._done then
                    qlist, qFromSeq = {}, true
                    for i = (f._cur or 1) + 1, #seq2 do if #qlist >= 3 then break end; qlist[#qlist + 1] = seq2[i] end
                elseif false and id and C_AssistedCombat and C_AssistedCombat.GetRotationSpells then   -- ⛔ 统计预测已停用：暴雪只算下一个，再往后只能猜，猜错比不显示更糟（09-21 用户）
                    -- 候选 1 秒才重算一次，且只按真冷却筛（资源够不够每帧都在变，跟着变就闪；09-21 用户「有闪烁」）
                    if not f._qAt or GetTime() - f._qAt > 1 or f._qId ~= id then
                        f._qAt = GetTime(); f._qId = id
                        qlist, qFromSeq = {}, false
                        local ok2, list = pcall(C_AssistedCombat.GetRotationSpells)
                        local _, RR = specKey()
                        -- ① 先查接续表：顶尖玩家按完「当前这个」之后最常按什么（build_rotation_follow.py，bigram），只留现在能放的（09-21 用户「关联关系还得看一下」）
                        local fol, fol2 = RR and RR.follow, RR and RR.follow2
                        local baseId = (FindBaseSpellByID and FindBaseSpellByID(id)) or id
                        if fol then
                            -- 链式预测（09-21 用户「第二个技能还不是下一个技能」）：
                            --   第 1 格 = 按「你上一次真按的 + 暴雪算的这个」查三元表（没有就退回二元表）；第 2、3 格用同样办法往后滚。
                            --   每一步只取现在能放（不在 CD、资源够）的最高概率项；占比写在小格左上角，让人知道这是统计不是断言。
                            f._qPct = {}
                            local c0 = (f._lastCastAt and GetTime() - f._lastCastAt < 12) and f._lastCast or nil
                            local c1 = baseId
                            for _ = 1, 3 do
                                local rows = (c0 and fol2 and fol2[c0 .. "|" .. c1]) or fol[c1]
                                local pick, pct
                                for _, r in ipairs(rows or {}) do
                                    local sid = r[1]
                                    if sid ~= id and not cdLeft(sid) and C_Spell.GetSpellTexture(sid) then
                                        local usable = true
                                        if C_Spell.IsSpellUsable then local ok3, u = pcall(C_Spell.IsSpellUsable, sid); if ok3 and u == false then usable = false end end
                                        if usable then pick, pct = sid, r[2]; break end
                                    end
                                end
                                if not pick then break end
                                qlist[#qlist + 1] = pick; f._qPct[#qlist] = pct
                                c0, c1 = c1, (FindBaseSpellByID and FindBaseSpellByID(pick)) or pick
                            end
                            if #qlist > 0 then f._qFollow = true end
                        end
                        if #qlist == 0 then f._qFollow = false end
                        if ok2 and list and #qlist == 0 then
                            -- ② 没有接续数据：退回按 WCL 每分钟施放次数（core 表）排序；只列现在能放（不在 CD、资源够）的
                            local cpm = {}
                            for _, e in ipairs((RR and RR.raid and RR.raid.core) or {}) do cpm[e[1]] = e[2] or 0 end
                            for _, e in ipairs((RR and RR.mplus and RR.mplus.core) or {}) do if not cpm[e[1]] then cpm[e[1]] = e[2] or 0 end end
                            local cand = {}
                            for _, sid in ipairs(list) do
                                if sid ~= id and not (issecretvalue and issecretvalue(sid)) and not cdLeft(sid) then
                                    local usable = true
                                    if C_Spell.IsSpellUsable then local ok3, u = pcall(C_Spell.IsSpellUsable, sid); if ok3 and u == false then usable = false end end
                                    if usable then
                                        local base = (FindBaseSpellByID and FindBaseSpellByID(sid)) or sid
                                        cand[#cand + 1] = { sid, cpm[sid] or cpm[base] or 0 }
                                    end
                                end
                            end
                            table.sort(cand, function(a, b) return a[2] > b[2] end)
                            for i = 1, math.min(3, #cand) do qlist[i] = cand[i][1] end
                        end
                    end
                else
                    qlist, qFromSeq = {}, false
                end
                f._qlist, f._qFromSeq = qlist, qFromSeq
                local qkey = table.concat(qlist, ",")
                if qkey ~= f._qkey then
                    f._qkey = qkey
                    local conveyor = id ~= f._qMainId   -- 主技能换了 → 整条往左滚一格；只是候选换了 → 静默换图
                    f._qMainId = id
                    for i, q in ipairs(f.q) do
                        local sid = qlist[i]
                        if sid then
                            local pc = f._qPct and f._qPct[i]
                            q.pct:SetText(pc and string.format("%d%%", math.floor(pc + 0.5)) or "")
                            if q._sid ~= sid then
                                q._sid = sid; q.icon:SetTexture(C_Spell.GetSpellTexture(sid))
                                local kt = capParts(rawKey(f._km or {}, sid))[1]
                                if kt and kt ~= "—" then q.key:SetText(kt); q.keyBg:SetSize(math.max(12, q.key:GetStringWidth() + 4), 12); q.key:Show(); q.keyBg:Show() else q.key:Hide(); q.keyBg:Hide() end
                                if conveyor then q.ag:Stop(); q:ClearAllPoints(); q:SetPoint("BOTTOMLEFT", f.next, "BOTTOMRIGHT", 6 + (i - 1) * 30 + 30, 0); q.ag:Play() end
                            end
                            q:Show()
                        else q._sid = nil; q:Hide() end
                    end
                    if conveyor and f.next.pop then f.next.pop:Stop(); f.next.pop:Play() end
                    f.qLbl:SetText(qFromSeq and T("LY_TB_Q_SEQ", "接下来") or (f._qFollow and T("LY_TB_Q_FOLLOW", "常见接续") or T("LY_TB_Q_CAND", "候选"))); f.qLbl:SetShown(#qlist > 0)
                end
                if f.next.caps then
                    -- 键帽叠在图标右下角（09-20 用户「数字放到技能方块右下角」）：多段键从右往左排，超出图标就往左伸
                    local x = 2
                    for i = #f.next.caps, 1, -1 do
                        local k = f.next.caps[i]
                        if k:IsShown() then k:ClearAllPoints(); k:SetPoint("BOTTOMRIGHT", f.next, "BOTTOMRIGHT", x - 2, 2); x = x - k:GetWidth() - 3 end
                    end
                end
                local textW = math.max(f.hint:GetStringWidth() or 0, f.cd:GetStringWidth() or 0)
                local iconsW = 44 + (#qlist > 0 and (6 + 3 * 30 - 4) or 0)
                local w = 9 + math.max(iconsW, math.min(240, textW)) + 10
                if w ~= f._compactW then
                    -- 宽度从中间向两边长：先记住中心点，改完宽度再按中心点锚回去
                    local cx, cy = f:GetCenter()
                    f._compactW = w; f:SetWidth(w)
                    if cx and cy then f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy) end   -- GetCenter / SetPoint 同一坐标系（都是本帧缩放单位），不用换算
                end
            end
            if f.hint and f.hint:IsShown() then
                f.hint:SetText(id and ("|cffffffff" .. (C_Spell.GetSpellName(id) or "") .. "|r") or ("|cff888888" .. T("LY_TB_IDLE", "选中可攻击的目标后，这里显示该按什么") .. "|r"))
                local txt = ""
                if id and C_Spell.GetSpellCooldown then
                    -- 技能本身的 CD（基础冷却，秒）；有充能的用充能冷却
                    local baseMs = GetSpellBaseCooldown and GetSpellBaseCooldown(id) or 0
                    local ch = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(id)
                    if ch and ch.maxCharges and ch.maxCharges > 1 and ch.cooldownDuration and not (issecretvalue and issecretvalue(ch.cooldownDuration)) then baseMs = ch.cooldownDuration * 1000 end
                    local baseTxt = ""   -- 09-21：基础 CD 不再跟在「就绪」后面（「就绪 CD 120s」读着像还在冷却）；扇形 + 倒计时已够
                    local cd = C_Spell.GetSpellCooldown(id)
                    local st, du = cd and cd.startTime or 0, cd and cd.duration or 0
                    if not (issecretvalue and (issecretvalue(st) or issecretvalue(du))) and st > 0 and du > 1.6 then
                        local left = st + du - GetTime()
                        if left > 0 then txt = string.format("|cffff8040%s %s|r%s", T("LY_TB_CD", "冷却"), left >= 10 and string.format("%ds", math.floor(left + 0.5)) or string.format("%.1fs", left), baseTxt) end
                    end
                    if txt == "" then
                        if ch and ch.currentCharges and ch.maxCharges and ch.maxCharges > 1 and not (issecretvalue and issecretvalue(ch.currentCharges)) then
                            txt = string.format("|cff40c060%s|r |cff888888%d/%d|r%s", T("LY_TB_READY", "就绪"), ch.currentCharges, ch.maxCharges, baseTxt)
                        else
                            txt = "|cff40c060" .. T("LY_TB_READY", "就绪") .. "|r" .. baseTxt
                        end
                    end
                end
                f.cd:SetText(txt)
            end
        end
        f._tick = C_Timer.NewTicker(0.2, function()
            local ok, err = pcall(tickBody)
            if not ok and not f._tickErr then f._tickErr = true; GearInsight:Print("|cffff4040GI 钉板刷新出错（只报一次）：|r" .. tostring(err)) end
        end)
        -- ── 暴雪「冷却管理器」叠加（09-20 用户「做」）：它的每个图标底下印这格的键帽，暴雪助手说「现在该按」的那个加金框呼吸光 ──
        --   只读它的框体（EssentialCooldownViewer / UtilityCooldownViewer），每个图标挂一层自己的覆盖帧画东西，不碰暴雪的字段；开关 GearInsightDB.cdvKeys
        local CDV_NAMES = { "EssentialCooldownViewer", "UtilityCooldownViewer" }
        local cdvItems = {}
        local function cdvSpell(item)
            local sid
            if item.GetSpellID then local ok, v = pcall(item.GetSpellID, item); if ok then sid = v end end
            if not sid and item.cooldownID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
                local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, item.cooldownID)
                if ok and info then sid = info.overrideSpellID or info.spellID end
            end
            if sid and issecretvalue and issecretvalue(sid) then return nil end
            return sid
        end
        local function cdvOverlay(item)
            if not item._giOv then
                local ov = CreateFrame("Frame", nil, item); ov:SetAllPoints(); ov:SetFrameLevel(item:GetFrameLevel() + 5)
                ov.key = ov:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); ov.key:Hide()
                item._giOv = ov
            end
            return item._giOv
        end
        -- 冷却管理器图标只有 30 来像素，钉板那套大键帽塞不下（09-20 用户「既不美观」）：改成暴雪快捷键风格的小角标——
        --   图标右下角一枚紧凑小牌，修饰键缩成 s- / c- / a-（暴雪原生写法），空格 Sp、滚轮 滚↑；没绑的不画；该按的那格小牌变金 + 图标金框呼吸
        local CDV_MOD = { SHIFT = "s-", CTRL = "c-", ALT = "a-" }
        local function cdvKeyText(keyRaw)
            if not keyRaw then return nil end
            local parts = {}
            for tok in keyRaw:gmatch("[^%-]+") do parts[#parts + 1] = tok end
            local out = ""
            for i, tok in ipairs(parts) do
                if i < #parts and CDV_MOD[tok] then out = out .. CDV_MOD[tok]
                else
                    local t = shortKey(tok)
                    t = t:gsub("空格键", "Sp"):gsub("空白鍵", "Sp"):gsub("Space", "Sp"):gsub("Num Lock", "NL"):gsub("Page Up", "PU"):gsub("Page Down", "PD")
                    out = out .. t
                end
            end
            return out
        end
        local function cdvBadge(ov, keyRaw, hot)
            local txt = cdvKeyText(keyRaw)
            if not txt or txt == "" then if ov.badge then ov.badge:Hide() end; return end
            if not ov.badge then
                local b = CreateFrame("Frame", nil, ov, "BackdropTemplate")
                b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                b:SetPoint("TOP", ov, "TOP", 0, -1)   -- 顶部居中：右下角是暴雪的充能数字、中间是冷却数字，都别压（09-20 用户「会和这个数字重合」）
                b.fs = b:CreateFontString(nil, "OVERLAY"); b.fs:SetPoint("CENTER", 0, 0)
                ov.badge = b
            end
            local b = ov.badge
            -- 位置可选（09-20 用户）：GearInsightDB.cdvPos = TOP/BOTTOM/LEFT/RIGHT/CENTER/TOPLEFT/TOPRIGHT/BOTTOMLEFT/BOTTOMRIGHT，默认顶部居中
            local pos = (GearInsightDB and GearInsightDB.cdvPos) or "TOP"
            if b._pos ~= pos then
                b._pos = pos; b:ClearAllPoints()
                local dx = (pos:find("LEFT") and 1) or (pos:find("RIGHT") and -1) or 0
                local dy = (pos:find("TOP") and -1) or (pos:find("BOTTOM") and 1) or 0
                b:SetPoint(pos, ov, pos, dx, dy)
            end
            local iw = math.max(20, ov:GetWidth() or 32)
            local h = math.max(13, math.min(19, math.floor(iw * 0.46)))   -- 09-20 用户「字体可以放大点」
            local font = select(1, (NumberFont_Outline_Med or GameFontHighlightSmall):GetFont())   -- 数字字体（暴雪动作条快捷键同款），比正文字清爽；09-20 用户「字体很难看，不能加粗」
            local size = h - 2
            b.fs:SetFont(font, size, ""); b.fs:SetShadowOffset(1, -1); b.fs:SetShadowColor(0, 0, 0, 1); b.fs:SetText(txt)   -- 不描边只带阴影（09-20「描边有点太粗」）；底牌够黑，看得清
            while b.fs:GetStringWidth() + 5 > iw and size > 8 do size = size - 1; b.fs:SetFont(font, size, "") end
            b:SetSize(math.min(iw, math.floor(b.fs:GetStringWidth() + 7)), h)
            if hot then b:SetBackdropColor(1, 0.82, 0, 0.95); b:SetBackdropBorderColor(1, 0.95, 0.6, 1); b.fs:SetTextColor(0.1, 0.08, 0.02)
            else b:SetBackdropColor(0.02, 0.02, 0.03, 0.65); b:SetBackdropBorderColor(0.75, 0.75, 0.8, 0.9); b.fs:SetTextColor(1, 1, 1) end   -- 09-20 用户「太黑看不清」：底透一点、边亮一点，字纯白描边
            b:Show()
        end
        GearInsight.CdvBadge = cdvBadge
        local function cdvClear(item)
            local ov = item._giOv; if not ov then return end
            if ov.badge then ov.badge:Hide() end
            glowOff(ov); ov._hot = nil
        end
        local function cdvCollect()
            for _, it in ipairs(cdvItems) do cdvClear(it) end
            wipe(cdvItems)
            for _, name in ipairs(CDV_NAMES) do
                local v = _G[name]
                if v and v:IsShown() then
                    for _, k in ipairs({ v:GetChildren() }) do
                        if k.Icon or k.cooldownID or k.GetSpellID then cdvItems[#cdvItems + 1] = k end
                    end
                end
            end
        end
        GearInsight.CdvRefresh = function() f._cdvN = 0 end
        f._cdvTick = C_Timer.NewTicker(0.25, function()
            local on = GearInsightDB and GearInsightDB.cdvKeys ~= false
            if not on then if #cdvItems > 0 then for _, it in ipairs(cdvItems) do cdvClear(it) end; wipe(cdvItems) end; return end
            f._cdvN = (f._cdvN or 0) + 1
            if f._cdvN % 8 == 1 then
                cdvCollect(); f._cdvKm = keyMap()
                if f:IsShown() then f._km = f._cdvKm; f:Redraw() end   -- 钉板同一份键位表，和手法页显示一致
            end
            local km = f._cdvKm or {}
            local nid = nextSpell()
            local nb = nid and ((FindBaseSpellByID and FindBaseSpellByID(nid)) or nid)
            for _, it in ipairs(cdvItems) do
                local sid = it:IsShown() and cdvSpell(it)
                if sid then
                    local ov = cdvOverlay(it)
                    local hot = nb and (((FindBaseSpellByID and FindBaseSpellByID(sid)) or sid) == nb) or false
                    cdvBadge(ov, rawKey(km, sid), hot)
                    if hot and not ov._hot then ov._hot = true; glowOn(ov) elseif not hot and ov._hot then ov._hot = nil; glowOff(ov) end
                else cdvClear(it) end
            end
        end)
        hud = f
        return f
    end
    function GearInsight:PinTacticBoard(who, seq, key, explicit)
        local f = ensureHud()
        GearInsightDB = GearInsightDB or {}
        if explicit then GearInsightDB.tacticBoardOn = true end
        local raw, map = seq, {}
        if seq and #seq > 0 then
            if rebuildKnownNames then rebuildKnownNames(keyMap()) end
            local skip = GearInsight.TacticSkip(key)
            local keep = {}
            for i, sid in ipairs(seq) do if known(sid) and not skip[i] then keep[#keep + 1] = sid; map[#keep] = i end end
            seq = keep
        end
        f._who, f._seq, f._cur, f._km, f._key, f._map = who, seq or {}, 1, keyMap(), key, map
        GearInsightDB.tacticPinned = { title = who, seq = raw, key = key }   -- 存原序列，删掉的步按 key 另记，改天赋 / 恢复都能对上
        f:Redraw()
        if GearInsightDB.tacticBoardOn == false then f:Hide() else f:Show() end
        if rt and rt.boardCb then rt.boardCb:SetChecked(GearInsightDB.tacticBoardOn ~= false) end
    end
    -- 上次钉过的板子，登录后自动恢复（键位表现读）
    if GearInsightDB and GearInsightDB.tacticPinned and GearInsightDB.tacticPinned.seq and GearInsightDB.tacticBoardOn ~= false then
        -- 只钉助手（没序列）时不带任何副标题——老存档里存过「暴雪循环助手」这种标题，清掉（09-19 用户「为啥有暴雪循环助手的文字」）
        C_Timer.After(2, function() local tp = GearInsightDB.tacticPinned; if tp then self:PinTacticBoard((tp.seq and #tp.seq > 0) and tp.title or nil, tp.seq, tp.key) end end)
    end

    -- ── 页面元素 ──
    rt = {}
    -- 顶部「控制台」卡（09-20 用户「这个页面也好好美化一下」）：左边现在该按（大图标 + 键 + 名），右边两个开关一列；下面各段标题带金线
    rt.card = CreateFrame("Frame", nil, vt, "BackdropTemplate"); rt.card:SetPoint("TOPLEFT", 10, -2); rt.card:SetPoint("RIGHT", vt, "RIGHT", -12, 0); rt.card:SetHeight(108)
    rt.card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    rt.card:SetBackdropColor(0.05, 0.05, 0.08, 0.7); rt.card:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
    rt.nextHd = lbl(rt.card, T("LY_ROT_NOW_HD", "现在该按 · 暴雪官方循环助手（按你当前天赋）"), 10, -7, 400, "GameFontNormal")
    rt.nextIcon = rt.card:CreateTexture(nil, "ARTWORK"); rt.nextIcon:SetSize(50, 50); rt.nextIcon:SetPoint("TOPLEFT", 12, -28); rt.nextIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    rt.nextFrame = CreateFrame("Frame", nil, rt.card, "BackdropTemplate"); rt.nextFrame:SetPoint("TOPLEFT", rt.nextIcon, -1, 1); rt.nextFrame:SetPoint("BOTTOMRIGHT", rt.nextIcon, 1, -1)
    rt.nextFrame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); rt.nextFrame:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.8)
    rt.nextKey = rt.card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); rt.nextKey:SetPoint("TOPLEFT", rt.nextIcon, "TOPRIGHT", 12, 0)
    rt.nextName = rt.card:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); rt.nextName:SetPoint("TOPLEFT", rt.nextIcon, "TOPRIGHT", 12, -30); rt.nextName:SetWidth(240); rt.nextName:SetJustifyH("LEFT"); rt.nextName:SetWordWrap(false)
    -- 说明行改短句 + 详情进悬浮（09-21 用户截图：右边被开关列挤得只剩半句「黄字…」）
    rt.nextNote = lbl(rt.card, T("LY_ROT_NOW_NOTE2", "随目标 / 战斗实时变 · 黄字键 = 未绑，显示推荐  |cff888888[?]|r"), 10, -84, 380, "GameFontDisableSmall")
    rt.nextNote:ClearAllPoints(); rt.nextNote:SetPoint("BOTTOMLEFT", rt.card, "BOTTOMLEFT", 10, 8); rt.nextNote:SetPoint("RIGHT", rt.card, "RIGHT", -330, 0); rt.nextNote:SetWordWrap(false)   -- 一行到底，不折行压到下一段
    rt.noteHit = CreateFrame("Frame", nil, rt.card); rt.noteHit:SetAllPoints(rt.nextNote)
    rt.noteHit:SetScript("OnEnter", function(f) GameTooltip:SetOwner(f, "ANCHOR_TOP"); GameTooltip:SetText(T("LY_ROT_NOW_NOTE", "选中目标 / 进战斗后这里跟着变；键 = 你条上绑的（黄字 = 还没绑，显示插件推荐）"), 1, 1, 1, 1, true); GameTooltip:Show() end)
    rt.noteHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rt.nextIcon:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark"); rt.nextName:SetText(T("LY_ROT_NEXT_IDLE", "（无目标 / 未进战斗）"))
    -- 右列：两个开关（钉板 / 冷却管理器角标），文字在框右边、不出卡
    local function switch(y, text, tip, get, set)
        local cb = CreateFrame("CheckButton", nil, rt.card, "UICheckButtonTemplate"); cb:SetSize(24, 24); cb:SetPoint("TOPLEFT", rt.card, "TOPRIGHT", -318, y)
        cb.text:SetText(text); cb.text:SetFontObject("GameFontHighlightSmall"); cb.text:ClearAllPoints(); cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0); cb.text:SetWidth(284); cb.text:SetJustifyH("LEFT"); cb.text:SetWordWrap(false)
        cb:SetChecked(get())
        cb:SetScript("OnClick", function(b) set(b:GetChecked() and true or false) end)
        cb:SetScript("OnEnter", function(b) GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(tip, 1, 0.82, 0, 1, true); GameTooltip:Show() end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return cb
    end
    rt.boardCb = switch(-30, T("LY_BOARD_CB", "屏幕上显示 GI 循环助手（钉板）"), T("LY_BOARD_TIP", "关掉 = 钉板收起并记住，登录 / 换装都不会自己冒出来；再勾回来原样回来。没选序列时只显示「现在该按」。"),
        function() return GearInsightDB and GearInsightDB.tacticBoardOn ~= false and GearInsightDB.tacticPinned ~= nil end,
        function(on)
            GearInsightDB = GearInsightDB or {}
            if on then local tp = GearInsightDB.tacticPinned; GearInsight:PinTacticBoard(tp and tp.title, tp and tp.seq or {}, tp and tp.key, true)
            else GearInsightDB.tacticBoardOn = false; local hf = ensureHud(); hf:Hide() end
            if GearInsight._rotRefresh then GearInsight._rotRefresh() end
        end)
    rt.cdvCb = switch(-56, T("LY_CDV_CB", "暴雪冷却管理器图标下印键帽 · 该按的加金框"), T("LY_CDV_TIP", "暴雪自带「冷却管理器」（编辑模式里开）的每个图标底下印你条上的键，暴雪循环助手说该按的那个加金框——看它就够，钉板可以不开。"),
        function() return not (GearInsightDB and GearInsightDB.cdvKeys == false) end,
        function(on) GearInsightDB = GearInsightDB or {}; GearInsightDB.cdvKeys = on; if GearInsight.CdvRefresh then GearInsight.CdvRefresh() end end)
    -- 键帽位置下拉（九宫）
    local POS = { { "TOP", T("LY_POS_TOP", "上") }, { "BOTTOM", T("LY_POS_BOTTOM", "下") }, { "LEFT", T("LY_POS_LEFT", "左") }, { "RIGHT", T("LY_POS_RIGHT", "右") }, { "CENTER", T("LY_POS_CENTER", "中") },
                  { "TOPLEFT", T("LY_POS_TL", "左上") }, { "TOPRIGHT", T("LY_POS_TR", "右上") }, { "BOTTOMLEFT", T("LY_POS_BL", "左下") }, { "BOTTOMRIGHT", T("LY_POS_BR", "右下") } }
    local function posName(v) for _, o in ipairs(POS) do if o[1] == v then return o[2] end end return v end
    rt.posBtn = CreateFrame("Button", nil, rt.card, "UIPanelButtonTemplate"); rt.posBtn:SetSize(150, 20); rt.posBtn:SetPoint("TOPLEFT", rt.cdvCb, "BOTTOMLEFT", 26, -2)
    -- 预览：一格 36px 样例图标，键帽按当前位置画（09-20 用户「来个预览」）
    -- 预览画在左边「现在该按」的大图标上（09-20 用户「用左边的大图标不行吗」）：tickNext 每 0.2s 按当前位置 / 当前键重画
    local function posText()
        rt.posBtn:SetText(string.format(T("LY_POS_BTN", "键帽位置：%s"), posName((GearInsightDB and GearInsightDB.cdvPos) or "TOP")))
        if GearInsight.CdvBadge then GearInsight.CdvBadge(rt.nextFrame, rt._nextKeyRaw or "SHIFT-4", true) end
    end
    posText()
    rt.posBtn:SetScript("OnClick", function(b)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(b, function(_, root)
            root:CreateTitle(T("LY_POS_TITLE", "冷却管理器图标上的键帽放哪"))
            for _, o in ipairs(POS) do
                root:CreateRadio(o[2], function() return ((GearInsightDB and GearInsightDB.cdvPos) or "TOP") == o[1] end, function() GearInsightDB = GearInsightDB or {}; GearInsightDB.cdvPos = o[1]; posText() end)
            end
        end)
    end)
    rt.pinNext = rt.boardCb   -- 旧引用：refreshRot 里按 hasApi 显隐
    do local hf = ensureHud(); if not (GearInsightDB and GearInsightDB.tacticPinned and GearInsightDB.tacticBoardOn ~= false) then hf:Hide() end end   -- 登录时建出来给冷却管理器角标用；钉板要不要显示由上面的开关说了算
    -- 段标题下的金线
    rt.rules = {}
    local function ruled(fs) local r = vt:CreateTexture(nil, "ARTWORK"); r:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25); r:SetHeight(1); r:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3); r:SetPoint("RIGHT", vt, "RIGHT", -14, 0); rt.rules[fs] = r; return fs end
    rt.rotHd = ruled(lbl(vt, "", 14, -124, 700, "GameFontNormal"))
    -- 「选择常规序列」= 钉板只看暴雪循环助手、不带任何起手（09-20 用户「需要一个选择常规序列的按键」；原「钉到屏幕·只看助手」钮改到这行）
    rt.pinRot = CreateFrame("Button", nil, vt, "UIPanelButtonTemplate"); rt.pinRot:SetSize(120, 18); rt.pinRot:SetPoint("TOPRIGHT", vt, "TOPRIGHT", -20, -122)
    rt.pinRot:SetScript("OnClick", function() GearInsight:PinTacticBoard(nil, {}, nil, true); if GearInsight._rotRefresh then GearInsight._rotRefresh() end end)
    rt.pinRot:SetScript("OnEnter", function(b) GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(T("LY_ROT_PIN_ROT_TIP", "钉板只显示「现在该按」这一格（暴雪循环助手，含单体 / AOE 判断），不带起手序列。想跟起手就点下面某个人的「选择这个序列」。"), 1, 0.82, 0, 1, true); GameTooltip:Show() end)
    rt.pinRot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- 「官方循环技能」行选中时也要高亮（09-21 用户「这里选中要高亮」）：和玩家序列行同款金底金边罩子
    rt.rotSel = CreateFrame("Frame", nil, vt, "BackdropTemplate"); rt.rotSel:SetFrameLevel(vt:GetFrameLevel())
    rt.rotSel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    rt.rotSel:SetBackdropColor(GOLD[1], GOLD[2], GOLD[3], 0.10); rt.rotSel:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.7); rt.rotSel:Hide()
    rt.rotCells = {}
    rt.secHd = { st = ruled(lbl(vt, "", 14, -196, 700, "GameFontNormal")), aoe = ruled(lbl(vt, "", 14, -260, 700, "GameFontNormal")) }
    rt.openRows = { st = {}, aoe = {} }
    rt.coachHd = ruled(lbl(vt, T("LY_ROT_COACH_HD", "教练解读 · 本专精"), 14, -370, 700, "GameFontNormal"))
    rt.coach = vt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); rt.coach:SetPoint("TOPLEFT", 14, -390); rt.coach:SetPoint("RIGHT", -20, 0); rt.coach:SetJustifyH("LEFT"); rt.coach:SetSpacing(3)
    rt.noApi = lbl(vt, T("LY_ROT_NO_API", "这个客户端没有官方循环助手接口（C_AssistedCombat），只显示顶尖起手与教练解读。"), 14, -26, 700, "GameFontDisableSmall")

    local function drawOpeners(kind, list, y, km, secTitle)
        local hd = rt.secHd[kind]
        hd:ClearAllPoints(); hd:SetPoint("TOPLEFT", 14, y); hd:SetText(secTitle); hd:Show()
        y = y - 20
        local size, gap = 34, 4
        local rows = rt.openRows[kind]
        for r, op in ipairs(list) do
            local row = rows[r]
            if not row then
                row = { who = vt:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"), cells = {} }
                row.who:SetJustifyH("LEFT"); row.who:SetWidth(330); row.who:SetWordWrap(false)
                row.tal = CreateFrame("Button", nil, vt, "UIPanelButtonTemplate"); row.tal:SetSize(100, 18)
                row.pin = CreateFrame("Button", nil, vt, "UIPanelButtonTemplate"); row.pin:SetSize(104, 18)
                -- 选中行底色 + 金边（BACKGROUND 层，压在格子下面）
                row.sel = CreateFrame("Frame", nil, vt, "BackdropTemplate"); row.sel:SetFrameLevel(vt:GetFrameLevel())
                row.sel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                row.sel:SetBackdropColor(GOLD[1], GOLD[2], GOLD[3], 0.10); row.sel:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.7)
                row.selTag = row.sel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.selTag:SetPoint("TOPLEFT", row.sel, "TOPLEFT", 6, -2)
                rows[r] = row
            end
            local isSel = GearInsightDB and GearInsightDB.tacticPinned and GearInsightDB.tacticPinned.key == (kind .. "|" .. (op.player or "?") .. "|" .. (op.server or ""))
            row.sel:ClearAllPoints(); row.sel:SetPoint("TOPLEFT", 8, y + 5); row.sel:SetPoint("RIGHT", vt, "RIGHT", -12, 0); row.sel:SetHeight(6 + 22 + size + 30)   -- 罩住：名字行 + 图标行 + 图标下的键位字（09-20 截图键位字漏在框外、名字压边）
            row.sel:SetShown(isSel and true or false)
            row.selTag:SetText("")   -- 不再叠字（压住名字，09-19 截图）；按钮文字已说明
            -- 天赋是否已经是这个人的：当前载入档名 = GI-玩家名（或 GI-玩家名·2）
            local talOn = false
            do
                local sid = GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()
                local cid = sid and C_ClassTalents.GetLastSelectedSavedConfigID and C_ClassTalents.GetLastSelectedSavedConfigID(sid)
                local okc, ci = pcall(C_Traits.GetConfigInfo, cid or 0)
                local nm = okc and ci and ci.name or ""
                talOn = nm == ("GI-" .. (op.player or "?")) or nm == ("GI-" .. (op.player or "?") .. "·2")
            end
            row.who:ClearAllPoints(); row.who:SetPoint("TOPLEFT", 16, y - 3)
            local who = string.format("%s · %s%s", op.player or "?", op.server or "", op.region and op.region ~= "" and (" (" .. op.region .. ")") or "")
            if op.pull and op.pull ~= "" then who = who .. "  |cff666666" .. op.pull .. (op.enemies and op.enemies > 0 and (" ×" .. op.enemies) or "") .. "|r" end
            row.who:SetText(who); row.who:Show()
            -- 切换天赋：优先用 RotationData 里这个人自己的天赋（tal），没有再去天赋库按名字找
            local d, ref = findBuild(op.player, op.server)
            if op.tal and op.tal.dict and op.tal.flat then d, ref = { pool = { op.tal.flat }, dict = op.tal.dict }, { b = 1, hero = "" } end
            row.tal:ClearAllPoints(); row.tal:SetPoint("TOPRIGHT", vt, "TOPRIGHT", -20, y + 1)   -- 按钮和名字同一行，图标另起一行，不再压住第 13-16 格（09-19 截图）
            row.tal:SetText(talOn and ("|cff40c060" .. T("LY_ROT_TAL_ON", "天赋已切换") .. "|r") or T("LY_ROT_TAL_BTN", "切换成他的天赋")); row.tal:SetEnabled(d ~= nil); row.tal:Show()
            row.tal:SetScript("OnClick", function()
                if not d then return end
                if InCombatLockdown() then GearInsight:Print(T("LY_COMBAT", "战斗中不能改动作条")); return end
                -- ⛔ 走导入串 + C_ClassTalents.ImportLoadout（0.91.4 的无 taint 路径），不用 ResetTree/PurchaseRank 直改
                local str, err = GearInsight_ExportTalentBuild(GearInsight_CurrentSpecID(), d.pool[ref.b], d.dict)
                if not str then GearInsight:Print(T("LY_ROT_TAL_FAIL", "切换天赋失败：") .. tostring(err)); return end
                local nm = op.player or "?"   -- TryImportTalents 自己加 "GI-" 前缀，档名 = GI-玩家名
                local ok, msg = GearInsight_TryImportTalents(str, nm, function(okA, msgA)
                    if okA then
                        local tag = (type(msgA) == "string" and msgA:find("^GI%-")) and msgA or (ref.hero or "")
                        if tag ~= "" then GearInsight:Print(string.format(T("LY_ROT_TAL_OK", "已切换成 %s 的天赋（%s）"), op.player or "?", tag))
                        else GearInsight:Print(string.format(T("LY_ROT_TAL_OK2", "已切换成 %s 的天赋"), op.player or "?")) end
                    else GearInsight:Print(T("LY_ROT_TAL_FAIL", "切换天赋失败：") .. tostring(msgA)) end
                end)
                if not ok then GearInsight:Print(T("LY_ROT_TAL_FAIL", "切换天赋失败：") .. tostring(msg)) end
            end)
            row.tal:SetScript("OnEnter", function(b)
                GameTooltip:SetOwner(b, "ANCHOR_TOP")
                if d then GameTooltip:SetText(string.format(T("LY_ROT_TAL_TIP", "一键换成 %s 的天赋（英雄天赋 %s）· 以新天赋档「GI 名字」导入并应用，你原来的档不动"), op.player or "?", ref.hero or "?"), 1, 0.82, 0, 1, true)
                else GameTooltip:SetText(T("LY_ROT_TAL_NONE", "天赋库里没有这个人的 build（下次刷数据时补）"), 0.7, 0.7, 0.7, 1, true) end
                GameTooltip:Show()
            end); row.tal:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.pin:ClearAllPoints(); row.pin:SetPoint("RIGHT", row.tal, "LEFT", -6, 0); row.pin:SetText(isSel and ("|cffe2b85c" .. T("LY_ROT_PIN_ON", "已选择") .. "|r") or T("LY_ROT_PIN_BTN", "选择这个序列")); row.pin:Show()
            row.pin:SetScript("OnClick", function()
                local seq = {}
                for _, sid in ipairs(op.seq or {}) do seq[#seq + 1] = sid end   -- 原序列整份交给钉板，known / 删掉的步在那边过滤
                GearInsight:PinTacticBoard(string.format("%s · %s", (secTitle:gsub(" ·.*$", "")), op.player or "?"), seq, kind .. "|" .. (op.player or "?") .. "|" .. (op.server or ""), true)
                if GearInsight._rotRefresh then GearInsight._rotRefresh() end
            end)
            local shown = 0
            local seqShow, seqRaw = {}, {}
            for ri, sid in ipairs(op.seq or {}) do if not ENV_SPELLS[sid] then seqShow[#seqShow + 1] = sid; seqRaw[#seqShow] = ri end end   -- 环境技能页面上也不画（09-20）
            local seqKey = kind .. "|" .. (op.player or "?") .. "|" .. (op.server or "")
            local skip = GearInsight.TacticSkip(seqKey)
            for i, sid in ipairs(seqShow) do
                if i > 16 then break end
                local c = row.cells[i] or cell(vt, size); row.cells[i] = c
                c._id = sid; c._key = seqKey; c._raw = seqRaw[i]; c._hud = nil; shown = i
                c:ClearAllPoints(); c:SetPoint("TOPLEFT", 16 + (i - 1) * (size + gap), y - 22)
                local off = skip[seqRaw[i]]
                c.icon:SetTexture(C_Spell.GetSpellTexture(sid)); c.icon:SetDesaturated(off or not known(sid)); c:SetAlpha(off and 0.35 or 1)
                c.key:SetText(off and ("|cffff4040" .. T("LY_SEQ_OFF", "已删") .. "|r") or (known(sid) and keyText(km, sid) or "|cff666666x|r")); c.num:SetText(tostring(i)); c:Show()
            end
            for i = shown + 1, #row.cells do row.cells[i]:Hide() end
            y = y - 22 - size - 32
        end
        for r = #list + 1, #rows do rows[r].who:Hide(); rows[r].tal:Hide(); rows[r].pin:Hide(); if rows[r].sel then rows[r].sel:Hide() end; for _, c in ipairs(rows[r].cells) do c:Hide() end end
        if #list == 0 then hd:SetText(secTitle .. "  |cff666666" .. T("LY_ROT_NO_OPEN", "暂无数据") .. "|r"); y = y - 4 end
        return y
    end

    local function refreshRot()
        if not vt:IsShown() then return end
        local km = keyMap(); rt._km = km
        local hasApi = C_AssistedCombat and C_AssistedCombat.GetRotationSpells
        rt.noApi:SetShown(not hasApi)
        for _, o in ipairs({ rt.nextHd, rt.nextIcon, rt.nextFrame, rt.nextKey, rt.nextName, rt.nextNote, rt.rotHd, rt.pinRot }) do o:SetShown(hasApi and true or false) end
        local tp = GearInsightDB and GearInsightDB.tacticPinned
        local rotSel = tp and GearInsightDB.tacticBoardOn ~= false and not (tp.seq and #tp.seq > 0)
        rt.pinRot:SetText(rotSel and ("|cffe2b85c" .. T("LY_ROT_PIN_ON", "已选择") .. "|r") or T("LY_ROT_PIN_ROT", "选择常规序列"))
        rt.boardCb:SetChecked(GearInsightDB and GearInsightDB.tacticBoardOn ~= false and GearInsightDB.tacticPinned ~= nil)
        local y = -124
        if hasApi then
            local ok, list = pcall(C_AssistedCombat.GetRotationSpells)
            list = ok and list or {}
            wipe(rotSet); for _, id in ipairs(list) do rotSet[id] = true; local b = FindBaseSpellByID and FindBaseSpellByID(id); if b then rotSet[b] = true end end
            rebuildKnownNames(km)
            rt.rotHd:SetText(string.format(T("LY_ROT_LIST_HD", "官方循环技能 · %d 个 · 格子下面是你的键"), #list))
            local size, gap, perRow = 40, 6, 14
            for i, id in ipairs(list) do
                local c = rt.rotCells[i] or cell(vt, size); rt.rotCells[i] = c
                c._id = id
                c:ClearAllPoints(); c:SetPoint("TOPLEFT", 16 + ((i - 1) % perRow) * (size + gap), y - 20 - math.floor((i - 1) / perRow) * (size + 20))
                c.icon:SetTexture(C_Spell.GetSpellTexture(id)); c.icon:SetDesaturated(false); c.key:SetText(keyText(km, id)); c.num:SetText(""); c:Show()
            end
            for i = #list + 1, #rt.rotCells do rt.rotCells[i]:Hide() end
            local rowsN = math.max(1, math.ceil(#list / perRow))
            rt.rotSel:ClearAllPoints(); rt.rotSel:SetPoint("TOPLEFT", 8, y + 4); rt.rotSel:SetPoint("RIGHT", vt, "RIGHT", -12, 0); rt.rotSel:SetHeight(24 + rowsN * (size + 20) + 6)
            rt.rotSel:SetShown(rotSel and true or false)
            y = y - 24 - rowsN * (size + 20) - 10
        else
            for _, c in ipairs(rt.rotCells) do c:Hide() end
            rt.rotSel:Hide()
            wipe(rotSet); rebuildKnownNames(km)
            y = -50
        end
        local _, R = specKey()
        local raid = R and R.raid or {}
        local mp = R and R.mplus or {}
        -- 单体：团本前 2 名；群怪：大米第一波大包前 2 名（大米 openerSt 作单体的补充，团本没有时才用）
        local st = {}
        for i, o in ipairs(raid.opener or {}) do if i <= 2 then st[#st + 1] = o end end
        if #st == 0 then for i, o in ipairs(mp.openerSt or {}) do if i <= 2 then st[#st + 1] = o end end end
        local aoe = {}
        for i, o in ipairs(mp.openerAoe or {}) do if i <= 2 then aoe[#aoe + 1] = o end end
        y = drawOpeners("st", st, y, km, string.format(T("LY_ROT_ST_HD", "单体起手 · 团本顶尖 %d 人 · 灰 = 你当前天赋没这个技能"), #st))
        y = drawOpeners("aoe", aoe, y - 10, km, string.format(T("LY_ROT_AOE_HD", "群怪起手 · 大米高层第一波 %d 人"), #aoe))
        rt.coachHd:ClearAllPoints(); rt.coachHd:SetPoint("TOPLEFT", 14, y - 10)
        rt.coach:ClearAllPoints(); rt.coach:SetPoint("TOPLEFT", 14, y - 34); rt.coach:SetPoint("RIGHT", -20, 0)
        for fs, r in pairs(rt.rules) do r:SetShown(fs:IsShown()) end
        local coach = (R and R.raid and R.raid.coach) or (R and R.mplus and R.mplus.coach)
        rt.coach:SetText(coach and ((_LOCALE == "zhCN" or _LOCALE == "zhTW") and coach.cn or coach.en) or T("LY_ROT_NO_COACH", "本专精暂无教练解读。"))
        vt:SetHeight(math.max(400, -y + 30 + (rt.coach:GetStringHeight() or 0) + 24))   -- 滚动内容高度 = 实际排到哪
    end
    local function tickNext()
        if not (vt:IsShown() and pg:IsShown() and C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then return end
        local ok, id = pcall(C_AssistedCombat.GetNextCastSpell, false)
        if ok and id and not (issecretvalue and issecretvalue(id)) then
            rt.nextIcon:SetTexture(C_Spell.GetSpellTexture(id))
            rt.nextName:SetText(C_Spell.GetSpellName(id) or "")
            rt.nextKey:SetText(keyText(rt._km or {}, id))
            local k = rt._km and (rt._km[id] or rt._km[(FindBaseSpellByID and FindBaseSpellByID(id)) or id]); rt._nextKeyRaw = k and k.key or nil
            if GearInsight.CdvBadge and rt.nextFrame then GearInsight.CdvBadge(rt.nextFrame, rt._nextKeyRaw or "SHIFT-4", true) end
        else
            rt.nextIcon:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark"); rt.nextName:SetText(T("LY_ROT_NEXT_IDLE", "（无目标 / 未进战斗）")); rt.nextKey:SetText("")
            rt._nextKeyRaw = nil
            if GearInsight.CdvBadge and rt.nextFrame then GearInsight.CdvBadge(rt.nextFrame, "SHIFT-4", true) end   -- 没目标时用样例键做位置预览
        end
    end
    vt:SetScript("OnShow", function()
        refreshRot()
        if rotTicker then rotTicker:Cancel() end
        rotTicker = C_Timer.NewTicker(0.2, function()
            if not vt:IsShown() or not pg:IsShown() then rotTicker:Cancel(); rotTicker = nil; return end
            tickNext()
        end)
    end)
    vt:SetScript("OnHide", function() if rotTicker then rotTicker:Cancel(); rotTicker = nil end end)
    self._rotRefresh = refreshRot
    if vt:IsShown() and pg:IsShown() then C_Timer.After(0, function() if vt:IsShown() then vt:GetScript("OnShow")(vt) end end) end

    self._layoutRefresh = refresh
    -- 铺完 / 还原完 / 绑定完都会调 refresh；动作条被玩家手动改了也刷
    local ev = CreateFrame("Frame"); ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED"); ev:RegisterEvent("UPDATE_BINDINGS")
    -- 换天赋 / 换专精 / 学新技能也要重算方案（用户 2026-09-19「切了天赋还是没看到灵魂收割」：页面开着时没刷新）
    ev:RegisterEvent("TRAIT_CONFIG_UPDATED"); ev:RegisterEvent("PLAYER_TALENT_UPDATE"); ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED"); ev:RegisterEvent("SPELLS_CHANGED")
    -- 合并成每帧最多刷一次：铺 60 格会连发 60 个 ACTIONBAR_SLOT_CHANGED，逐个刷会把整页重画 60 遍
    local queued = false
    ev:SetScript("OnEvent", function(_, event)
        -- 用户在游戏里改了键（不是插件自己在铺）→「我的键位」快照跟着更新，替换页/键盘/战术板下一次刷新就是最新的
        if event == "UPDATE_BINDINGS" and not GearInsight._applyingKeys and not InCombatLockdown() then
            local store, specID = keySnapStore()
            if store[specID] then
                local snap, changed = store[specID], false
                for _, bar in ipairs(BARS) do
                    for sl = bar.from, bar.to do
                        local k = GetBindingKey(GearInsight.SlotCommand(sl))
                        if k == "" then k = nil end
                        if snap[sl] ~= k then snap[sl] = k; changed = true end
                    end
                end
                if changed then snap._at = date("%m-%d %H:%M") end
            end
        end
        local vt = views.rotation
        if queued or not pg:IsShown() then return end
        queued = true
        C_Timer.After(0, function()
            queued = false
            if not pg:IsShown() then return end
            refresh()   -- 保存页的备份列表也一起刷
            if vt and vt:IsShown() and GearInsight._rotRefresh then GearInsight._rotRefresh() end
            if GearInsight._kbRefresh and GearInsight._kbFrame and GearInsight._kbFrame:IsShown() then GearInsight._kbRefresh() end
        end)
    end)
    showMode((GearInsightDB and GearInsightDB.layoutMode) or "replace")   -- 默认停在「替换」（卖点在这页；「保存」是安全网）
end
