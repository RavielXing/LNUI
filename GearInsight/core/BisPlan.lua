-- core/BisPlan.lua —— 自定义 BiS 方案（「我的方案」）+ GIB1 三端方案串（2026-09-23 立项）
--
-- 设计稿：clawhub docs/gearinsight-custom-bis-planner-design.md（§10 = GIB1 规范，三端唯一格式）
-- 网站参考实现：services/dashboard/gib1.py；金样本：services/dashboard/tests/fixtures/gib1_samples.txt
--   ⛔ 编解码必须和 gib1.py **逐字节一致**，对拍脚本 scripts/gi_bisplan_test.py 跑金样本。
--   ⛔ 改格式先改设计稿 §10、升 GIB2，再通知网站 / 小程序两个会话。
--
-- ⭐ 为什么注入在 BisPack.buildSpec 这一层（而不是一个个改消费方）：
--    总览 / 角色面板图标 / 悬浮 / 刷本规划 / 低保 / 心愿单 / 检视 全都读 spec.bisBySlot。
--    方案件在建表那一刻排到每槽第一位，所有地方自动跟随 —— 一个入口，不会漏、不会两处打架
--    （同族教训：09-07 术士属性页和主面板各算各的）。
--
-- ⛔ 方案条目是**复制出来的新表**：池条目的 stats / bonusIDs 是池化共享表，谁都别就地改。
-- ⛔ 本文件是新模块：测完用户点头之前在 scripts/gi_pack_release.py 的 HOLD 里，不进发行包。
--    其它文件里调它的地方一律 `GearInsight.BisPlan and ...` 判空，模块不在时行为与以前完全一样。

GearInsight = GearInsight or {}
local BP = {}
GearInsight.BisPlan = BP

local function T(key, zh)
    local loc = GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
    if loc == "zhCN" then return zh end
    local L = GearInsight.LOC or {}
    local cur = L[loc]
    if cur and cur[key] then return cur[key] end
    if loc ~= "zhTW" and L.enUS and L.enUS[key] then return L.enUS[key] end
    return zh
end
BP.T = T

local PREFIX = "GIB1"
local MAX_LEN = 4000
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
local SLOT_OK = {}
for _, s in ipairs(SLOTS) do SLOT_OK[s] = true end
local TRACK_OK = { m = true, h = true, c = true, v = true, x = true }
local STATS = { "crit", "haste", "mastery", "vers" }
local STAT_OK = { crit = true, haste = true, mastery = true, vers = true }
-- 插件内部属性键 ↔ GIB1 属性键
local TO_GIB = { crit = "crit", haste = "haste", mastery = "mastery", versatility = "vers" }
local FROM_GIB = { crit = "crit", haste = "haste", mastery = "mastery", vers = "versatility" }
BP.SLOTS, BP.TO_GIB, BP.FROM_GIB = SLOTS, TO_GIB, FROM_GIB

-- 轨道满级装等（12.1 赛季二）。⛔ 换季改这里 + RollVault.lua 的 UPGRADE_LEVELS。
BP.TRACK_MAX = { m = 334, h = 321, c = 308, v = 295 }
BP.TRACKS = { "m", "h", "c", "v", "x" }

-- 方案槽：每专精最多 3 套
BP.PLAN_IDS = { "raid", "mplus", "custom" }

-- ════════════════════════════════════════════════════════════════════
-- 小工具
-- ════════════════════════════════════════════════════════════════════
-- 按分隔符切，保留空字段（"a||b" → {"a","","b"}），与 Python str.split 一致
local function split(s, sep)
    local out, i = {}, 1
    while true do
        local j = string.find(s, sep, i, true)
        if not j then out[#out + 1] = string.sub(s, i); break end
        out[#out + 1] = string.sub(s, i, j - 1)
        i = j + #sep
    end
    return out
end
BP._split = split

local function trim(s) return (string.gsub(s, "^%s+", ""):gsub("%s+$", "")) end

-- Python int(str(s).strip())：只认整数写法，其余回退默认值
local function toInt(s, default)
    if type(s) == "number" then
        if s == math.floor(s) then return s end
        return default or 0
    end
    local m = type(s) == "string" and string.match(s, "^%s*([+-]?%d+)%s*$")
    return m and tonumber(m) or (default or 0)
end

-- Python float → 整数值时转 int（_num）
local function toNum(s)
    if type(s) == "number" then return s end
    if type(s) ~= "string" then return nil end
    local t = trim(s)
    if not string.match(t, "^[+-]?%d*%.?%d+$") and not string.match(t, "^[+-]?%d+%.?%d*$") then return nil end
    return tonumber(t)
end

-- 最多 4 位小数、去尾零（三端一致：1 / 0.9 / 0.6125 / 25）
function BP.FmtNum(v)
    local s = string.format("%.4f", tonumber(v) or 0)
    s = string.gsub(s, "0+$", ""); s = string.gsub(s, "%.$", "")
    if s == "" or s == "-0" then return "0" end
    return s
end
local fmtNum = BP.FmtNum

local function isDigits(x)      -- Python x.strip().lstrip("-").isdigit()
    local t = trim(x):gsub("^%-+", "")
    return t ~= "" and not string.find(t, "%D")
end

-- ── base64url ───────────────────────────────────────────────────────
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64_REV = {}
for i = 1, 64 do B64_REV[string.byte(B64, i)] = i - 1 end
B64_REV[string.byte("+")] = 62; B64_REV[string.byte("/")] = 63

-- ⛔ 编码一律补齐尾部 '='（与 Export.lua 的 b64encode / gib1.py 一致）
function BP.B64Encode(raw)
    local out, n = {}, #raw
    for i = 1, n, 3 do
        local a, b, c = string.byte(raw, i, i + 2)
        local v = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(v / 262144) % 64
        local c2 = math.floor(v / 4096) % 64
        local c3 = math.floor(v / 64) % 64
        local c4 = v % 64
        out[#out + 1] = string.sub(B64, c1 + 1, c1 + 1) .. string.sub(B64, c2 + 1, c2 + 1)
            .. (b and string.sub(B64, c3 + 1, c3 + 1) or "=") .. (c and string.sub(B64, c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

-- 解不开返回 nil（非法字符 / 长度不对）
function BP.B64Decode(s)
    s = string.gsub(s, "=+$", "")
    if #s % 4 == 1 then return nil end
    local out, bits, nbits = {}, 0, 0
    for i = 1, #s do
        local v = B64_REV[string.byte(s, i)]
        if not v then return nil end
        bits = bits * 64 + v; nbits = nbits + 6
        if nbits >= 8 then
            nbits = nbits - 8
            local byte = math.floor(bits / (2 ^ nbits)) % 256
            out[#out + 1] = string.char(byte)
            bits = bits % (2 ^ nbits)
        end
    end
    return table.concat(out)
end

-- UTF-8 合法性（Python .decode("utf-8") 严格模式；非法 → 当「解不开」）
local function validUtf8(s)
    local i, n = 1, #s
    while i <= n do
        local c = string.byte(s, i)
        local len
        if c < 0x80 then len = 1
        elseif c >= 0xC2 and c <= 0xDF then len = 2
        elseif c >= 0xE0 and c <= 0xEF then len = 3
        elseif c >= 0xF0 and c <= 0xF4 then len = 4
        else return false end
        for k = 1, len - 1 do
            local cc = string.byte(s, i + k)
            if not cc or cc < 0x80 or cc > 0xBF then return false end
        end
        i = i + len
    end
    return true
end

-- djb2 → 6 位 hex（与 Export.lua checksum / api._gi_checksum 同一个函数）
function BP.Checksum(s)
    if GearInsight._checksum then return GearInsight._checksum(s) end
    local h = 5381
    for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 16777216 end
    return string.format("%06x", h)
end

local function urlUnquote(s)
    return (string.gsub(s, "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

-- 空白 + 零宽字符（Python isspace 覆盖的常见几种 + 设计稿列的零宽）
local STRIP_SEQ = { "\226\128\139", "\226\128\140", "\226\128\141", "\239\187\191", "\194\160", "\227\128\128" }
function BP.Normalize(code)
    local t = trim(code or "")
    for _, sep in ipairs({ "#b=", "?b=", "&b=" }) do
        local i = string.find(t, sep, 1, true)
        if i then t = string.sub(t, i + #sep); break end
    end
    if string.find(t, "%", 1, true) then t = urlUnquote(t) end
    t = string.gsub(t, "%s", "")
    for _, z in ipairs(STRIP_SEQ) do t = string.gsub(t, z, "") end
    if string.upper(string.sub(t, 1, 5)) == PREFIX .. "." then t = PREFIX .. "." .. string.sub(t, 6) end
    return t
end

-- ════════════════════════════════════════════════════════════════════
-- 解码（返回 plan 或 nil, 原因码, 提示）
-- ════════════════════════════════════════════════════════════════════
local ERR_MSG = {
    empty = { "BP_E_EMPTY", "没收到方案串：在插件方案页点「导出」，或在网站配装页点「复制方案串」，把整条贴过来" },
    vault_code = { "BP_E_VAULT", "这是「宏伟宝库」的导出串，不是配装方案：请到网站宝库页粘贴" },
    analyze_code = { "BP_E_ANALYZE", "这是「装备分析」的导出串，不是配装方案。方案串以 GIB1. 开头" },
    too_long = { "BP_E_LONG", "串太长了：确认只贴了一条方案串，没把整段聊天记录带上" },
    format = { "BP_E_FORMAT", "不是方案串：应为 GIB1.<数据>.<校验> 三段" },
    truncated = { "BP_E_TRUNC", "方案串被截断了：复制时没选全（聊天软件常把长链接折断），回去重新复制一次完整的" },
    checksum = { "BP_E_CHECK", "校验码对不上：方案串中途被改动过，回去重新复制一次，别手工编辑" },
    decode = { "BP_E_DECODE", "方案串解不开：内容不是 GearInsight 导出的格式" },
    version = { "BP_E_VERSION", "这是更新版本的方案串：请把插件更新到最新版再导入" },
    fields = { "BP_E_FIELDS", "方案串字段不全" },
}
function BP.ErrorText(code)
    local e = ERR_MSG[code]
    if not e then return tostring(code) end
    return T(e[1], e[2])
end

local function parseSlot(entry)
    local p = split(entry, ":")
    if #p < 3 then return nil end
    local slot, iid = toInt(p[1]), toInt(p[2])
    if not SLOT_OK[slot] or iid <= 0 then return nil end
    local track = string.lower(trim(p[3]))
    local out = { slot = slot, id = iid, track = TRACK_OK[track] and track or "x" }
    local ext, extKeys = nil, nil
    local rest = {}
    for i = 4, #p do rest[#rest + 1] = p[i] end
    for _, kv in ipairs(split(table.concat(rest, ":"), ",")) do
        local eq = string.find(kv, "=", 1, true)
        if eq then
            local k, v = trim(string.sub(kv, 1, eq - 1)), trim(string.sub(kv, eq + 1))
            if k == "cf" then
                if toInt(v) > 0 then out.cf = toInt(v) end
            elseif k == "cs" then
                local cs = {}
                for _, x in ipairs(split(v, ".")) do if x ~= "" then cs[#cs + 1] = x end end
                out.cs = cs
            elseif k == "em" then
                out.em = toInt(v)
            elseif k == "b" then
                local b = {}
                for _, x in ipairs(split(v, ".")) do if isDigits(x) then b[#b + 1] = toInt(x) end end
                out.b = b
            elseif k ~= "" then
                -- 未知扩展键：不报错、不解释，原样带回（向前兼容）
                ext = ext or {}; extKeys = extKeys or {}
                if ext[k] == nil then extKeys[#extKeys + 1] = k end
                ext[k] = v
            end
        end
    end
    if ext then out.ext = ext end
    return out
end

local function parseStats(s)
    s = trim(s or "")
    if s == "" or s == "auto" then return { mode = "auto" } end
    local c = string.find(s, ":", 1, true)
    local mode = c and string.sub(s, 1, c - 1) or s
    local rest = c and string.sub(s, c + 1) or ""
    if mode == "p" then
        local order = {}
        for _, x in ipairs(split(rest, ">")) do if x ~= "" then order[#order + 1] = x end end
        return { mode = "p", order = order }
    end
    if mode == "w" then
        local w, worder = {}, {}
        for _, kv in ipairs(split(rest, ",")) do
            local e = string.find(kv, "=", 1, true)
            local k = e and string.sub(kv, 1, e - 1) or kv
            local v = e and string.sub(kv, e + 1) or ""
            local n = toNum(v)
            if k ~= "" and n ~= nil then
                if w[k] == nil then worder[#worder + 1] = k end
                w[k] = n
            end
        end
        return { mode = "w", weights = w, _worder = worder }
    end
    if mode == "t" then
        local rules = {}
        for _, r in ipairs(split(rest, ",")) do
            for _, op in ipairs({ ">=", "<=" }) do
                local i = string.find(r, op, 1, true)
                if i then
                    local k, v = string.sub(r, 1, i - 1), string.sub(r, i + 2)
                    local n = toNum(v)
                    if k ~= "" and n ~= nil then rules[#rules + 1] = { stat = k, op = op, value = n } end
                    break
                end
            end
        end
        return { mode = "t", rules = rules }
    end
    return { mode = "auto" }
end

local function parseMap(s, multi)
    s = trim(s or "")
    if s == "" or s == "auto" then return "auto" end
    local out, any = {}, false
    for _, kv in ipairs(split(s, ";")) do
        local e = string.find(kv, "=", 1, true)
        local k = e and string.sub(kv, 1, e - 1) or kv
        local v = e and string.sub(kv, e + 1) or ""
        local slot = toInt(k)
        if SLOT_OK[slot] then
            if multi then
                local ids = {}
                for _, x in ipairs(split(v, ".")) do if toInt(x) > 0 then ids[#ids + 1] = toInt(x) end end
                if #ids > 0 then out[tostring(slot)] = ids; any = true end
            elseif toInt(v) > 0 then
                out[tostring(slot)] = toInt(v); any = true
            end
        end
    end
    return any and out or "auto"
end

function BP.Decode(code)
    code = BP.Normalize(code)
    if code == "" then return nil, "empty" end
    local head = string.upper(string.sub(code, 1, 5))
    local first200 = string.sub(code, 1, 200)
    if head == "GIV1." or string.find(first200, "GIV1.", 1, true) then return nil, "vault_code" end
    if string.upper(string.sub(code, 1, 4)) == "GI1." or string.find(first200, "GI1.", 1, true) then return nil, "analyze_code" end
    if #code > MAX_LEN then return nil, "too_long" end
    local parts = split(code, ".")
    if #parts ~= 3 or parts[1] ~= PREFIX then return nil, "format" end
    local body, want = parts[2], string.lower(parts[3])
    local padded = body .. string.rep("=", (4 - #body % 4) % 4)
    local raw = BP.B64Decode(padded)
    if raw and not validUtf8(raw) then raw = nil end
    if want ~= BP.Checksum(body) and want ~= BP.Checksum(padded) then
        local bars = raw and select(2, string.gsub(raw, "|", "|")) or 0
        if raw == nil or bars < 8 then return nil, "truncated" end
        return nil, "checksum"
    end
    if raw == nil then return nil, "decode" end
    local f = split(raw, "|")
    if f[1] ~= "1" then
        if toInt(f[1]) > 1 then return nil, "version" end
        return nil, "decode"
    end
    if #f < 9 then return nil, "fields" end
    local seen, slots = {}, {}
    for _, e in ipairs(split(f[5], ";")) do
        local s = parseSlot(e)
        if s and not seen[s.slot] then seen[s.slot] = s end
    end
    for _, sid in ipairs(SLOTS) do if seen[sid] then slots[#slots + 1] = seen[sid] end end
    return {
        v = 1, specId = toInt(f[2]), name = f[3], updated = toInt(f[4]),
        slots = slots, stats = parseStats(f[6]),
        gems = parseMap(f[7], true), enchants = parseMap(f[8], false), src = f[9],
    }
end

-- ════════════════════════════════════════════════════════════════════
-- 编码（plan 用 Decode 同一形状：slots 为数组）
-- ════════════════════════════════════════════════════════════════════
local BANNED_NAME = "[|;,:=]"
function BP.CleanName(name) return (string.gsub(tostring(name or ""), BANNED_NAME, " ")) end

local function hasAny(s, chars)
    for i = 1, #chars do if string.find(s, string.sub(chars, i, i), 1, true) then return true end end
    return false
end

local function encSlot(s)
    local slot, iid = toInt(s.slot), toInt(s.id)
    local track = string.lower(tostring(s.track or "x"))
    local out = slot .. ":" .. iid .. ":" .. (TRACK_OK[track] and track or "x")
    local kv = {}
    if toInt(s.cf) > 0 then kv[#kv + 1] = "cf=" .. toInt(s.cf) end
    local cs = {}
    for _, x in ipairs(s.cs or {}) do
        x = tostring(x)
        if x ~= "" and not hasAny(x, "|;,:=.") then cs[#cs + 1] = x end
    end
    if #cs > 0 then kv[#kv + 1] = "cs=" .. table.concat(cs, ".") end
    if toInt(s.em) ~= 0 then kv[#kv + 1] = "em=" .. toInt(s.em) end
    local b = {}
    for _, x in ipairs(s.b or {}) do if isDigits(tostring(x)) then b[#b + 1] = tostring(toInt(tostring(x))) end end
    if #b > 0 then kv[#kv + 1] = "b=" .. table.concat(b, ".") end
    if s.ext then
        local keys = {}
        for k in pairs(s.ext) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = tostring(s.ext[k])
            if k ~= "" and not hasAny(k .. v, "|;,:=") then kv[#kv + 1] = k .. "=" .. v end
        end
    end
    if #kv > 0 then out = out .. ":" .. table.concat(kv, ",") end
    return out
end

local function encStats(st)
    st = st or {}
    local mode = st.mode or "auto"
    if mode == "p" then
        local o = {}
        for _, k in ipairs(st.order or {}) do if STAT_OK[k] then o[#o + 1] = k end end
        return #o > 0 and ("p:" .. table.concat(o, ">")) or "auto"
    end
    if mode == "w" then
        local o = {}
        local order = st._worder
        if not order then order = {}; for _, k in ipairs(STATS) do if (st.weights or {})[k] ~= nil then order[#order + 1] = k end end end
        for _, k in ipairs(order) do
            local v = (st.weights or {})[k]
            if STAT_OK[k] and tonumber(v) then o[#o + 1] = k .. "=" .. fmtNum(v) end
        end
        return #o > 0 and ("w:" .. table.concat(o, ",")) or "auto"
    end
    if mode == "t" then
        local o = {}
        for _, r in ipairs(st.rules or {}) do
            if STAT_OK[r.stat] and (r.op == ">=" or r.op == "<=") and tonumber(r.value) then
                o[#o + 1] = r.stat .. r.op .. fmtNum(r.value)
            end
        end
        return #o > 0 and ("t:" .. table.concat(o, ",")) or "auto"
    end
    return "auto"
end

local function encMap(m, multi)
    if type(m) ~= "table" then return "auto" end
    local keys = {}
    for k in pairs(m) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return toInt(tostring(a)) < toInt(tostring(b)) end)
    local out = {}
    for _, k in ipairs(keys) do
        local slot = toInt(tostring(k))
        if SLOT_OK[slot] then
            local v = m[k]
            if multi then
                local ids = {}
                for _, x in ipairs(type(v) == "table" and v or { v }) do if toInt(x) > 0 then ids[#ids + 1] = tostring(toInt(x)) end end
                if #ids > 0 then out[#out + 1] = slot .. "=" .. table.concat(ids, ".") end
            elseif toInt(v) > 0 then
                out[#out + 1] = slot .. "=" .. toInt(v)
            end
        end
    end
    return #out > 0 and table.concat(out, ";") or "auto"
end

function BP.Encode(plan)
    local bySlot = {}
    for _, s in ipairs(plan.slots or {}) do
        local sid = toInt(s.slot)
        if SLOT_OK[sid] and toInt(s.id) > 0 and not bySlot[sid] then bySlot[sid] = s end
    end
    local enc = {}
    for _, sid in ipairs(SLOTS) do if bySlot[sid] then enc[#enc + 1] = encSlot(bySlot[sid]) end end
    local src = string.sub(string.gsub(tostring(plan.src or "addon"), "|", ""), 1, 32)
    local payload = table.concat({
        "1", tostring(toInt(plan.specId)), BP.CleanName(plan.name or ""), tostring(toInt(plan.updated)),
        table.concat(enc, ";"), encStats(plan.stats), encMap(plan.gems, true), encMap(plan.enchants, false), src }, "|")
    local body = BP.B64Encode(payload)
    return PREFIX .. "." .. body .. "." .. BP.Checksum(body)
end

-- ════════════════════════════════════════════════════════════════════
-- 存储：GearInsightDB.plans["CLASS/SPEC"] = { active = id|nil, list = { [id] = plan } }
--   plan 与 Decode 同形（slots 为数组），另存 _bySlot 缓存不落盘。
-- ════════════════════════════════════════════════════════════════════
local function specKey2(k)
    if type(k) ~= "string" then return nil end
    return string.match(k, "^([^/]+/[^/]+)") or k
end
BP.SpecKey2 = specKey2

function BP.KeyOfSpecData(sd)
    return sd and sd.className and sd.specName and (sd.className .. "/" .. sd.specName) or nil
end

function BP.SpecIdOf(key2)
    local ids = GearInsight.BisData and GearInsight.BisData.specIds
    return ids and ids[key2] or 0
end
function BP.KeyOfSpecId(id)
    for k, v in pairs((GearInsight.BisData and GearInsight.BisData.specIds) or {}) do
        if v == id then return k end
    end
    return nil
end

local function store(key2, create)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.plans = GearInsightDB.plans or {}
    local s = GearInsightDB.plans[key2]
    if not s and create then s = { list = {} }; GearInsightDB.plans[key2] = s end
    return s
end

function BP.Get(key2, id)
    local s = store(key2)
    return s and s.list and s.list[id] or nil
end

function BP.ActiveId(key2)
    local s = store(key2)
    local id = s and s.active
    if id and s.list and s.list[id] and #(s.list[id].slots or {}) > 0 then return id end
    return nil
end

function BP.ActivePlan(key2)
    local id = BP.ActiveId(key2)
    return id and store(key2).list[id] or nil, id
end

-- 方案是否在起作用（给 RecsReader 实时推荐让路用）
function BP.ActiveFor(specDataOrKey)
    local key = type(specDataOrKey) == "table" and BP.KeyOfSpecData(specDataOrKey) or specKey2(specDataOrKey)
    return key and BP.ActiveId(key) ~= nil or false
end

-- 当前角色当前专精的数据表（StatReader 口径，和主面板一致）
function BP.PlayerSpecData()
    local sr, bd = GearInsight.StatReader, GearInsight.BisData
    if not (sr and bd and bd.GetSpecData) then return nil end
    local ok, st = pcall(sr.ReadAll, sr)
    if not (ok and st and st.class and st.spec) then return nil end
    return bd:GetSpecData(st.class, st.spec, st.heroTalent)
end
function BP.ActiveForPlayer()
    local sd = BP.PlayerSpecData()
    return sd and BP.ActiveFor(sd) or false
end

local function slotMap(plan)
    local m = {}
    for _, s in ipairs(plan.slots or {}) do m[s.slot] = s end
    return m
end
BP.SlotMap = slotMap

-- ── 坯子（GIB1 扩展键 cf = 催化来源件，09-25 用户「怎么选坯子」→「当然要（三端互通）」）──
-- 启用中方案给某个套装部位指定的坯子；没启用 / 没指定 → nil。刷本规划 / 心愿单 / 悬浮按它跟随。
function BP.ChosenFiller(specData, slot)
    local key = specData and BP.KeyOfSpecData(specData)
    local plan = key and BP.ActivePlan(key)
    local s = plan and slotMap(plan)[slot]
    return (s and tonumber(s.cf) and s.cf > 0) and s.cf or nil
end
-- 设 / 清某一格的坯子：保留这一格已有的轨道和其它扩展键；这一格还没有装备就填上套装件本体
function BP.SetFiller(key2, id, slot, tierId, cf)
    local plan = BP.Get(key2, id)
    local cur = plan and slotMap(plan)[slot]
    local itemId = (cur and cur.id) or tierId
    if not itemId then return nil end
    local extra = {}
    if cur then for k, v in pairs(cur) do if k ~= "slot" and k ~= "id" and k ~= "track" then extra[k] = v end end end
    extra.cf = (cf and cf > 0) and cf or nil
    return BP.SetSlot(key2, id, slot, itemId, (cur and cur.track) or "x", extra)
end

-- 全局签名：悬浮索引 / 坯子缓存按它失效
function BP.Sig()
    local parts = {}
    for k, s in pairs((GearInsightDB and GearInsightDB.plans) or {}) do
        local p = s.active and s.list and s.list[s.active]
        if p then parts[#parts + 1] = k .. "=" .. s.active .. ":" .. tostring(p.updated or 0) .. ":" .. tostring(p._rev or 0) end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

-- 改了方案之后：丢掉已建的池、让悬浮索引失效、刷新面板
function BP.Changed(key2)
    local plan = key2 and select(1, BP.ActivePlan(key2))
    local bd = GearInsight.BisData
    if bd and bd.InvalidatePools then bd:InvalidatePools() end
    BP._statCache = nil
    local th = GearInsight.TooltipHook
    if th then th._itemIndex = nil; th._fillerSig = nil end
    if GearInsight.RefreshPanel and GearInsight._panelFrame and GearInsight._panelFrame:IsShown() then
        pcall(GearInsight.RefreshPanel, GearInsight)
    end
    if GearInsight.RefreshPaperDollBis then pcall(GearInsight.RefreshPaperDollBis) end
    if BP.OnChanged then pcall(BP.OnChanged, key2, plan) end
end

function BP.Save(key2, id, plan)
    local s = store(key2, true)
    plan.updated = time and time() or plan.updated or 0
    plan._rev = (plan._rev or 0) + 1
    s.list[id] = plan
    BP.Changed(key2)
end

-- 命名存档独立于三个工作方案；保存、载入均深拷贝，编辑不会改写存档。
function BP.CopyPlan(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = BP.CopyPlan(v) end
    return out
end

function BP.SavedPlans(key2)
    local s = store(key2)
    return s and s.archives or {}
end

function BP.SavedPlansNewest(key2)
    local out = {}
    for i, record in ipairs(BP.SavedPlans(key2)) do out[i] = record end
    table.sort(out, function(a, b)
        if (a.savedAt or 0) ~= (b.savedAt or 0) then return (a.savedAt or 0) > (b.savedAt or 0) end
        if (a.saveOrder or a.id or 0) ~= (b.saveOrder or b.id or 0) then
            return (a.saveOrder or a.id or 0) > (b.saveOrder or b.id or 0)
        end
        return (a.id or 0) > (b.id or 0)
    end)
    return out
end

local function nextSaveOrder(key2)
    local s = store(key2, true)
    local order = s.archiveOrder or 0
    for _, record in ipairs(s.archives or {}) do order = math.max(order, record.saveOrder or record.id or 0) end
    s.archiveOrder = order + 1
    return s.archiveOrder
end

function BP.ArchiveIdentity(key2)
    local out = { specId = BP.SpecIdOf(key2), talentIcon = 236415 }
    if out.specId and GetSpecializationInfoByID then
        local _, name, _, icon = GetSpecializationInfoByID(out.specId)
        out.specName, out.specIcon = name, icon
    end
    local index = GetSpecialization and GetSpecialization()
    local activeId = index and GetSpecializationInfo and GetSpecializationInfo(index)
    if activeId == out.specId and GearInsight.LayoutTalentSnapshot then
        local ok, talent = pcall(GearInsight.LayoutTalentSnapshot)
        if ok and talent then out.talents = BP.CopyPlan(talent) end
    elseif activeId == out.specId and C_ClassTalents and C_Traits then
        local ok, talent = pcall(function()
            local config = C_ClassTalents.GetActiveConfigID()
            if not config or (C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(config)) then return nil end
            local info = C_Traits.GetConfigInfo(config)
            return { specId = activeId, name = info and info.name or T("BP_TALENT_CUSTOM", "当前自定义天赋"),
                export = C_Traits.GenerateImportString and C_Traits.GenerateImportString(config) }
        end)
        if ok then out.talents = talent end
    end
    return out
end

function BP.SaveNamed(key2, plan, name, iconItem)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or not plan or #(plan.slots or {}) == 0 then return nil end
    local found = false
    for _, slot in ipairs(plan.slots) do if slot.id == iconItem then found = true; break end end
    if not found then return nil end
    local s = store(key2, true)
    s.archives = s.archives or {}
    if #s.archives >= 10 then return nil, "limit" end
    s.archiveSerial = (s.archiveSerial or 0) + 1
    local record = { id = s.archiveSerial, name = name, iconItem = iconItem, plan = BP.CopyPlan(plan) }
    record.plan.name = name
    record.identity = BP.ArchiveIdentity(key2)
    record.savedAt = time and time() or 0
    record.saveOrder = nextSaveOrder(key2)
    s.archives[#s.archives + 1] = record
    BP.Changed(key2)
    return record
end

function BP.DeleteNamed(key2, archiveId)
    local list = BP.SavedPlans(key2)
    for i, record in ipairs(list) do
        if record.id == archiveId then table.remove(list, i); BP.Changed(key2); return true end
    end
    return false
end

function BP.OverwriteNamed(key2, archiveId, plan)
    if not plan or #(plan.slots or {}) == 0 then return false end
    for _, record in ipairs(BP.SavedPlans(key2)) do
        if record.id == archiveId then
            record.plan = BP.CopyPlan(plan)
            record.plan.name = record.name
            local found = false
            for _, slot in ipairs(plan.slots) do if slot.id == record.iconItem then found = true end end
            if not found then record.iconItem = plan.slots[1].id end
            record.savedAt = time and time() or 0
            record.saveOrder = nextSaveOrder(key2)
            record.identity = BP.ArchiveIdentity(key2)
            BP.Changed(key2)
            return true
        end
    end
    return false
end

function BP.LoadNamed(key2, archiveId, targetId)
    for _, record in ipairs(BP.SavedPlans(key2)) do
        if record.id == archiveId then
            BP.Save(key2, targetId, BP.CopyPlan(record.plan))
            return true
        end
    end
    return false
end

function BP.SetActive(key2, id)
    local s = store(key2, true)
    s.active = id
    BP.Changed(key2)
end

function BP.Delete(key2, id)
    local s = store(key2)
    if not s then return end
    s.list[id] = nil
    if s.active == id then s.active = nil end
    BP.Changed(key2)
end

-- 设一格（id=nil → 清掉这格，回到数据推荐）
function BP.SetSlot(key2, id, slot, itemId, track, extra)
    local s = store(key2, true)
    local plan = s.list[id] or { name = "", slots = {}, stats = { mode = "auto" }, gems = "auto", enchants = "auto", src = "addon" }
    local out = {}
    for _, e in ipairs(plan.slots or {}) do if e.slot ~= slot then out[#out + 1] = e end end
    if itemId then
        local e = { slot = slot, id = itemId, track = track or "x" }
        for k, v in pairs(extra or {}) do e[k] = v end
        out[#out + 1] = e
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    plan.slots = out
    BP.Save(key2, id, plan)
    return plan
end

-- ════════════════════════════════════════════════════════════════════
-- 注入：BisPack.buildSpec 建完每槽候选后调用
-- ════════════════════════════════════════════════════════════════════
local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }
local PAIR_RANK = { [11] = 1, [12] = 2, [13] = 1, [14] = 2 }

local function copyEntry(e)
    local c = {}
    for k, v in pairs(e) do c[k] = v end
    return c
end

-- 在几张池里按 itemId 找模板条目（只读）
local function findTemplate(iid, lists)
    for _, list in ipairs(lists) do
        for _, e in ipairs(list or {}) do
            if e.itemId == iid then return e end
        end
    end
    return nil
end

function BP.MakeEntry(bd, planSlot, template)
    local e
    if template then
        e = copyEntry(template)
    else
        e = (GearInsight.BisPack and GearInsight.BisPack.EntryFromItem and GearInsight.BisPack.EntryFromItem(bd, planSlot.id))
            or { itemId = planSlot.id, itemName = "", itemNameCn = "", source = "", sourceCategory = "", bossName = "" }
        e.usagePct = 0
        if (e.itemName or "") == "" then
            local nm = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(planSlot.id)
            e.itemName = nm or ("item:" .. planSlot.id)
        end
    end
    e.planned = true
    e.planTrack = planSlot.track
    local tmax = BP.TRACK_MAX[planSlot.track or "x"]
    if planSlot.b and #planSlot.b > 0 then
        e.bonusIDs = planSlot.b                      -- 显式 bonusID 覆盖一切
    elseif tmax then
        -- 指定了轨道：装等按轨道满级；池里的 bonusID 代表顶尖玩家那件（多半是神话），不是这条轨道 —— 丢掉，
        -- 同时清 mx，免得 BisTargetIlvl 又把目标抬回神话
        e.ilvl, e._ilvlRaw, e.mx = tmax, tmax, nil
        e.bonusIDs = nil -- 神话轨道也不能继承模板中未升满或特殊掉落的实例 bonus。
    end
    return e
end

function BP.ApplyToPool(bd, key3, spec, bySlot, raw)
    local key2 = specKey2(key3)
    local plan = key2 and select(1, BP.ActivePlan(key2))
    if not plan then return bySlot end
    rawset(spec, "_dataBySlot", bySlot)          -- 方案页的候选列表要看「不含方案」的数据池
    local mp = bd.mplusBySlot and bd.mplusBySlot[key3] or {}
    local map = slotMap(plan)
    local made = {}
    for slot, ps in pairs(map) do
        local pair = PAIR[slot]
        local tpl = findTemplate(ps.id, { bySlot[slot], pair and bySlot[pair], raw[slot], pair and raw[pair], mp[slot], pair and mp[pair] })
        local e = BP.MakeEntry(bd, ps, tpl)
        e.planRank = PAIR_RANK[slot] or 1
        made[slot] = e
    end
    local out = {}
    for slot, list in pairs(bySlot) do out[slot] = list end
    for _, slot in ipairs(SLOTS) do
        local mine, pair = made[slot], PAIR[slot]
        local partner = pair and made[pair]
        if mine or partner then
            local list, skip = {}, {}
            if mine then list[#list + 1] = mine; skip[mine.itemId] = true end
            if partner and not skip[partner.itemId] then list[#list + 1] = partner; skip[partner.itemId] = true end
            for _, e in ipairs(bySlot[slot] or {}) do
                if not skip[e.itemId] then list[#list + 1] = e end
            end
            out[slot] = list
        end
    end
    return out
end

-- 成对槽位合并排序用：方案件排最前（planRank 小的先），其余按使用率
function BP.PoolLess(x, y)
    local px, py = x.planRank or 99, y.planRank or 99
    if px ~= py then return px < py end
    return (x.usagePct or 0) > (y.usagePct or 0)
end

-- ════════════════════════════════════════════════════════════════════
-- 属性跟随：方案 → 属性目标（评级占比 %）+ 契合度权重
-- ════════════════════════════════════════════════════════════════════
local SEC = { "crit", "haste", "mastery", "versatility" }
local ITEM_STAT_KEY = {
    crit = "ITEM_MOD_CRIT_RATING_SHORT", haste = "ITEM_MOD_HASTE_RATING_SHORT",
    mastery = "ITEM_MOD_MASTERY_RATING_SHORT", versatility = "ITEM_MOD_VERSATILITY",
}

local function itemSecondary(e)
    if e.stats then
        local t = {}
        for _, k in ipairs(SEC) do t[k] = e.stats[k] or (k == "versatility" and e.stats.vers) or 0 end
        return t
    end
    local link = "item:" .. e.itemId
    if e.bonusIDs and #e.bonusIDs > 0 and GearInsight.LinkMid then
        link = "item:" .. e.itemId .. GearInsight.LinkMid() .. #e.bonusIDs .. ":" .. table.concat(e.bonusIDs, ":")
    end
    local ok, raw = pcall(function() return C_Item and C_Item.GetItemStats and C_Item.GetItemStats(link) end)
    if not (ok and type(raw) == "table") then return nil end
    local t = {}
    for _, k in ipairs(SEC) do t[k] = raw[ITEM_STAT_KEY[k]] or 0 end
    return t
end

-- 在专精的各个池里按 itemId 找条目（只读；拿 stats / 名字 / 来源用）
function BP.FindEntry(specData, itemId)
    if not (specData and itemId) then return nil end
    for _, pool in ipairs({ rawget(specData, "_dataBySlot") or {}, specData.bisBySlot or {}, rawget(specData, "_rawBisBySlot") or {} }) do
        for _, list in pairs(pool or {}) do
            for _, e in ipairs(list) do if e.itemId == itemId then return e end end
        end
    end
    return nil
end

-- 任意一套方案 → { crit=%, haste=%, mastery=%, versatility=% }（四项合计 100）；拿不到返回 nil
--   第二个返回值 = 是否完整（有物品还没缓存到属性时 false，调用方别缓存）
function BP.ComputeStatPercents(plan, specData)
    if not plan then return nil end
    local st = plan.stats or { mode = "auto" }
    if st.mode == "w" or st.mode == "p" then
        local w = {}
        if st.mode == "w" then
            for k, v in pairs(st.weights or {}) do if FROM_GIB[k] then w[FROM_GIB[k]] = tonumber(v) or 0 end end
        else
            local steps = { 1, 0.8, 0.6, 0.4 }
            for i, k in ipairs(st.order or {}) do if FROM_GIB[k] then w[FROM_GIB[k]] = steps[i] or 0.2 end end
        end
        local sum = 0
        for _, k in ipairs(SEC) do sum = sum + (w[k] or 0) end
        if sum > 0 then
            local pct = {}
            for _, k in ipairs(SEC) do pct[k] = (w[k] or 0) / sum * 100 end
            return pct, true
        end
    end
    -- auto（以及 t 阈值模式的底子）：方案里每件的副属性加总 → 占比
    -- ⛔ 口径与网站 /wow/plan 对齐（网站会话 09-23 给的规则，改一边另一边一起改）：
    --   占比 = 某项评级 ÷ 四项副属性评级之和，只算装备（不含宝石 / 附魔）；
    --   催化件 cf → 副属性取来源件；制造件 cs 指定了就用那两项，没指定取专精团本目标占比最高的两项，按预算平分。
    local tot, sum, complete = { crit = 0, haste = 0, mastery = 0, versatility = 0 }, 0, true
    local pending = {}          -- 制造件：先记下，等算出「每件平均预算」再平分
    local nItems = 0
    local function secTotal(sec) local t = 0; for _, k in ipairs(SEC) do t = t + (sec[k] or 0) end; return t end
    for _, s in ipairs(plan.slots or {}) do
        local srcId = (s.cf and s.cf > 0) and s.cf or s.id
        local e = BP.FindEntry(specData, srcId) or { itemId = srcId }
        -- 显式物品变体必须现读，不能沿用推荐样本的装等和副属性。
        if s.b and #s.b > 0 and srcId == s.id then
            e = copyEntry(e)
            e.bonusIDs = s.b
            e.stats = nil
        end
        local crafted = (s.cs and #s.cs > 0) or e.sourceCategory == "crafted" or e.source == "制造" or e.source == "制造业"
        local sec = not (s.cs and #s.cs > 0) and itemSecondary(e) or nil
        if sec and secTotal(sec) > 0 then
            for _, k in ipairs(SEC) do tot[k] = tot[k] + sec[k]; sum = sum + sec[k] end
            nItems = nItems + 1
        elseif crafted then
            pending[#pending + 1] = { s = s, e = e }
        elseif not sec then
            complete = false
        end
    end
    if #pending > 0 then
        -- ⛔ 09-25 三端统一：随机属性 1 / 2 **不是平分**，约 2:1（334 鞋 = 100 / 51），大的给第一项。
        --   点数优先取这件在数据里的真实值（apply_random_stats.py 已按 Random Stat 1/2 写进 stats），拿不到按平均预算 2:1 拆。
        --   没指定 cs 的两项 = 当前参照目标占比最高两项，同值按 crit < haste < mastery < versatility（和数据端 / 网站同一条）。
        local budget = nItems > 0 and (sum / nItems) or 100
        local tp = (GearInsight.FillerStatPct and GearInsight.FillerStatPct(specData)) or (specData and specData.targetStatPercents) or {}
        local top = {}
        for i, k in ipairs(SEC) do top[#top + 1] = { k = k, v = tonumber(tp[k]) or 0, i = i } end
        table.sort(top, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.i < b.i end)
        for _, pe in ipairs(pending) do
            local s, e = pe.s, pe.e
            local two = {}
            for _, g in ipairs(s.cs or {}) do if FROM_GIB[g] then two[#two + 1] = FROM_GIB[g] end end
            if #two == 0 then two = { top[1].k, top[2].k } end
            local vals = {}
            for _, k in ipairs(SEC) do local v = e.stats and tonumber(e.stats[k]) or 0; if v > 0 then vals[#vals + 1] = v end end
            table.sort(vals, function(a, b) return a > b end)
            local hi, lo = vals[1], vals[2]
            if not (hi and lo) then hi, lo = budget * 2 / 3, budget / 3 end
            if #two == 1 then
                tot[two[1]] = tot[two[1]] + hi + lo
            else
                tot[two[1]] = tot[two[1]] + hi; tot[two[2]] = tot[two[2]] + lo
            end
            sum = sum + hi + lo
        end
    end
    if sum <= 0 then return nil, complete end
    local pct = {}
    for _, k in ipairs(SEC) do pct[k] = tot[k] / sum * 100 end
    return pct, complete
end

-- ════════════════════════════════════════════════════════════════════
-- 附魔 / 宝石 / 美化 / 制造属性（09-25 用户「附魔宝石可以设定吗」→「要做」「美化啥的都做到位」）
--   ⛔ 规则逐条照网站 wow_plan.py（resolve_extras / fill_embellish / check_extras），数据是同一份 plan_extras.json
--      （插件侧 core/PlanExtras.lua 由 build_plan_extras_lua.py 生成）—— 三端一致红线，改一边另一边一起改。
--   · plan.enchants = "auto" | { ["槽"] = 附魔效果ID }；dict 时没列的格 = 不附魔（网站同语义）
--   · plan.gems     = "auto" | { ["槽"] = { 宝石ID, … } }；auto 只给「顶尖玩家过半都有孔」的部位按孔数补
--   · slot.em = 美化 ID（全身最多 2 件，只能做在制造件上）；slot.cs = { "haste", "mastery" }（制造件两条属性，GIB1 键名）
-- ════════════════════════════════════════════════════════════════════
BP.ENCHANT_SLOTS = { [1] = true, [3] = true, [5] = true, [7] = true, [8] = true, [11] = true, [12] = true, [16] = true, [17] = true }
BP.EM_LIMIT = 2
local WEAPON_LOC = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true }

function BP.X() return _G.GearInsightPlanExtras end
function BP.SpecX(specData)
    local x = BP.X()
    local key = specData and BP.KeyOfSpecData(specData)
    return (x and key and x.specs and x.specs[key]) or nil
end
local function eqLoc(id)
    if not (id and C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, loc = C_Item.GetItemInfoInstant(id)
    return loc
end
-- 副手只有是武器才能附魔（网站 WEAPON_INV = 单手 / 双手 / 主手 / 副手武器）
function BP.CanEnchant(slot, itemId)
    if not BP.ENCHANT_SLOTS[slot] then return false end
    if slot == 17 then return WEAPON_LOC[eqLoc(itemId) or ""] or false end
    return true
end
function BP.IsCrafted(specData, itemId)
    local e = BP.FindEntry(specData, itemId)
    return (e and (e.sourceCategory == "crafted" or e.source == "制造业" or e.source == "制造")) and true or false
end
-- 美化只能做在制造件上（⛔ 团本地区掉落的随机属性件不行，虽然 DB2 里也是随机属性 24/25）
BP.CanEmbellish = BP.IsCrafted

local function autoSockets(sx, slot)
    local so = sx and sx.sock and sx.sock[slot]
    return (so and (so.pct or 0) >= 50) and (so.n or 0) or 0
end
BP.AutoSockets = autoSockets
-- 唯一宝石（limits 里那类，698 = 全身 1 颗）：placed 里已有同类就不行
function BP.GemLimitOk(gid, placed)
    local X = BP.X()
    local g = X and X.gems and X.gems[gid]
    if not (g and g.lim) then return true end
    for _, x in ipairs(placed or {}) do
        local gx = X.gems[x]
        if gx and gx.lim == g.lim then return false end
    end
    return true
end

local function copyList(v)
    local out = {}
    for _, x in ipairs(type(v) == "table" and v or { v }) do if tonumber(x) then out[#out + 1] = tonumber(x) end end
    return out
end

-- 方案实际生效的附魔 / 宝石：{ [slot] = 附魔ID }, { [slot] = { 宝石ID… } }, autoE[slot], autoG[slot]
--   items = { [slot] = itemId }（方案里的件；没放的格调用方用数据推荐那件补进来）
function BP.ResolveExtras(plan, specData, items)
    local sx = BP.SpecX(specData)
    items = items or {}
    local ench, gems, autoE, autoG = {}, {}, {}, {}
    if type(plan and plan.enchants) == "table" then for k, v in pairs(plan.enchants) do ench[tonumber(k)] = tonumber(v) end end
    if type(plan and plan.gems) == "table" then for k, v in pairs(plan.gems) do gems[tonumber(k)] = copyList(v) end end
    local slots = {}
    for slot in pairs(items) do slots[#slots + 1] = slot end
    table.sort(slots)
    if not plan or plan.enchants == nil or plan.enchants == "auto" then
        for _, slot in ipairs(slots) do
            if not ench[slot] and BP.CanEnchant(slot, items[slot]) then
                local top = sx and sx.ench and sx.ench[slot]
                if top and top[1] then ench[slot] = top[1][1]; autoE[slot] = true end
            end
        end
    end
    if not plan or plan.gems == nil or plan.gems == "auto" then
        local placed = {}
        for _, v in pairs(gems) do for _, g in ipairs(v) do placed[#placed + 1] = g end end
        for _, slot in ipairs(slots) do
            local need = autoSockets(sx, slot) - #(gems[slot] or {})
            for _ = 1, need do
                local pick
                for _, gu in ipairs((sx and sx.gem and sx.gem[slot]) or {}) do
                    if BP.GemLimitOk(gu[1], placed) then pick = gu[1]; break end
                end
                if not pick then break end
                gems[slot] = gems[slot] or {}
                gems[slot][#gems[slot] + 1] = pick
                placed[#placed + 1] = pick
                autoG[slot] = true
            end
        end
    end
    return ench, gems, autoE, autoG
end

-- 把 auto 固化成展开值（改一格前先调：dict 语义下没列的格 = 不附魔，不固化别的格会跟着丢）
local function materialize(plan, specData, items, which)
    if plan[which] ~= nil and plan[which] ~= "auto" then return end
    local ench, gems = BP.ResolveExtras(plan, specData, items)
    local out = {}
    if which == "enchants" then for slot, id in pairs(ench) do out[tostring(slot)] = id end
    else for slot, list in pairs(gems) do out[tostring(slot)] = copyList(list) end end
    plan[which] = out
end

local function planFor(key2, id)
    local p = BP.Get(key2, id)
    if p then return p end
    return { name = "", slots = {}, stats = { mode = "auto" }, gems = "auto", enchants = "auto", src = "addon" }
end

-- enchantId：数字 = 指定；false = 不附魔；nil = 全部恢复自动
function BP.SetEnchant(key2, id, specData, items, slot, enchantId)
    local plan = planFor(key2, id)
    if enchantId == nil then plan.enchants = "auto"
    else
        materialize(plan, specData, items, "enchants")
        plan.enchants[tostring(slot)] = enchantId or nil
    end
    BP.Save(key2, id, plan)
end
-- list：{ 宝石ID… } = 指定这一格；{} = 这一格不镶；nil = 全部恢复自动。⛔ 唯一宝石超限直接拒绝（网站 gem_unique）
function BP.SetGems(key2, id, specData, items, slot, list)
    local plan = planFor(key2, id)
    if list == nil then plan.gems = "auto"; BP.Save(key2, id, plan); return true end
    materialize(plan, specData, items, "gems")
    local placed = {}
    for k, v in pairs(plan.gems) do if tonumber(k) ~= slot then for _, g in ipairs(v) do placed[#placed + 1] = g end end end
    for _, g in ipairs(list) do
        if not BP.GemLimitOk(g, placed) then return false, "gem_unique" end
        placed[#placed + 1] = g
    end
    plan.gems[tostring(slot)] = (#list > 0) and copyList(list) or nil
    BP.Save(key2, id, plan)
    return true
end
-- 这一格的扩展键（em / cs）：这一格方案里还没放装备就用 itemId 补一条
local function setSlotExt(key2, id, slot, itemId, k, v)
    local plan = BP.Get(key2, id)
    local cur = plan and slotMap(plan)[slot]
    local useId = (cur and cur.id) or itemId
    if not useId then return false end
    local extra = {}
    if cur then for kk, vv in pairs(cur) do if kk ~= "slot" and kk ~= "id" and kk ~= "track" then extra[kk] = vv end end end
    extra[k] = v
    BP.SetSlot(key2, id, slot, useId, (cur and cur.track) or "x", extra)
    return true
end
-- 美化：emId = 数字 / nil（去掉）。⛔ 全身最多 2 件、只能做在制造件上（网站 embellish_limit）
function BP.SetEmbellish(key2, id, specData, slot, itemId, emId)
    if emId then
        if not BP.CanEmbellish(specData, itemId) then return false, "not_crafted" end
        local plan = BP.Get(key2, id)
        local n = 0
        for _, s in ipairs((plan and plan.slots) or {}) do if s.slot ~= slot and (tonumber(s.em) or 0) > 0 then n = n + 1 end end
        if n >= BP.EM_LIMIT then return false, "embellish_limit" end
    end
    return setSlotExt(key2, id, slot, itemId, "em", emId)
end
-- 制造两条属性：two = { "haste", "mastery" }（GIB1 键名，第一项拿大的那份）/ nil = 按专精理想自动
function BP.SetCraftStats(key2, id, slot, itemId, two)
    return setSlotExt(key2, id, slot, itemId, "cs", two)
end

-- 一键补齐（网站 /plan/autofill）：已指定的保留，空的附魔 / 宝石按使用率补满，美化按使用率在制造件上补到 2 件
function BP.Autofill(key2, id, specData, items)
    local plan = planFor(key2, id)
    local sx = BP.SpecX(specData)
    local ench, gems = BP.ResolveExtras({ enchants = "auto", gems = "auto" }, specData, items)
    local oldE = type(plan.enchants) == "table" and plan.enchants or {}
    local oldG = type(plan.gems) == "table" and plan.gems or {}
    local e2, g2, changes = {}, {}, 0
    for k, v in pairs(oldE) do e2[k] = v end
    for slot, eid in pairs(ench) do
        local k = tostring(slot)
        if not e2[k] then e2[k] = eid; changes = changes + 1 end
    end
    local placed = {}
    for k, v in pairs(oldG) do g2[k] = copyList(v); for _, g in ipairs(v) do placed[#placed + 1] = g end end
    local gslots = {}
    for slot in pairs(gems) do gslots[#gslots + 1] = slot end
    table.sort(gslots)
    for _, slot in ipairs(gslots) do
        local k = tostring(slot)
        if not g2[k] then
            local keep = {}
            for _, g in ipairs(gems[slot]) do if BP.GemLimitOk(g, placed) then keep[#keep + 1] = g; placed[#placed + 1] = g end end
            if #keep > 0 then g2[k] = keep; changes = changes + #keep end
        end
    end
    plan.enchants, plan.gems = e2, g2
    -- 美化：按使用率在方案的制造件上补到 2 件（fill_embellish）
    local have, cands = 0, {}
    for _, s in ipairs(plan.slots or {}) do
        if (tonumber(s.em) or 0) > 0 then have = have + 1
        elseif BP.CanEmbellish(specData, s.id) then
            for _, eu in ipairs((sx and sx.em and sx.em[s.slot]) or {}) do cands[#cands + 1] = { u = eu[2], s = s, id = eu[1] } end
        end
    end
    table.sort(cands, function(a, b) if a.u ~= b.u then return a.u > b.u end return a.s.slot < b.s.slot end)
    local done = {}
    for _, c in ipairs(cands) do
        if have >= BP.EM_LIMIT then break end
        if not done[c.s.slot] then c.s.em = c.id; done[c.s.slot] = true; have = have + 1; changes = changes + 1 end
    end
    BP.Save(key2, id, plan)
    return changes
end

-- 编辑约束检查（网站 check_extras）：{ emN, emOver, gemUniqueBad, enchN, enchSlots }
function BP.CheckExtras(plan, specData, items)
    local out = { emN = 0 }
    for _, s in ipairs((plan and plan.slots) or {}) do if (tonumber(s.em) or 0) > 0 then out.emN = out.emN + 1 end end
    out.emOver = out.emN > BP.EM_LIMIT
    local ench, gems = BP.ResolveExtras(plan or {}, specData, items)
    local placed = {}
    for _, list in pairs(gems) do
        for _, g in ipairs(list) do
            if not BP.GemLimitOk(g, placed) then out.gemUniqueBad = true end
            placed[#placed + 1] = g
        end
    end
    out.enchN, out.enchSlots = 0, 0
    for slot, iid in pairs(items or {}) do
        if BP.CanEnchant(slot, iid) then out.enchSlots = out.enchSlots + 1; if ench[slot] then out.enchN = out.enchN + 1 end end
    end
    return out
end

-- 随机属性 / 制造件「自动」时的理想两项（GIB1 键名）：当前参照目标占比最高两项，同值按 crit < haste < mastery < versatility
--   ⛔ 与数据端 apply_random_stats.py、网站 rand_ideal 同一条规则
function GearInsight.RandIdealGib(specData)
    local pct = (GearInsight.FillerStatPct and GearInsight.FillerStatPct(specData)) or (specData and specData.targetStatPercents) or {}
    local list = {}
    for i, k in ipairs(SEC) do list[#list + 1] = { k = k, v = tonumber(pct[k]) or 0, i = i } end
    table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.i < b.i end)
    return { TO_GIB[list[1].k], TO_GIB[list[2].k] }
end

-- 名字 / 图标（客户端语言；数据里没有就退回游戏 API）
local function xname(t, fallback)
    if not t then return fallback end
    local loc = GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
    if (loc == "zhCN" or loc == "zhTW") and t.cn and t.cn ~= "" then return t.cn end
    return (t.en and t.en ~= "" and t.en) or t.cn or fallback
end
function BP.EnchantName(eid)
    local X = BP.X()
    local nm = xname(X and X.enchants and X.enchants[eid], nil)
    if nm then   -- 「附魔头盔 - 强化闪避符文」→「强化闪避符文」
        nm = nm:gsub("^附魔[^%-]-%s*%-%s*", ""):gsub("^Enchant [^%-]-%s*%-%s*", "")
    end
    return nm or ("#" .. tostring(eid))
end
function BP.EnchantIcon(eid)
    local X = BP.X()
    local t = X and X.enchants and X.enchants[eid]
    return (t and t.icon and t.icon ~= "") and ("Interface\\Icons\\" .. t.icon) or 134400
end
function BP.EnchantDesc(eid)
    local X = BP.X()
    local t = X and X.enchants and X.enchants[eid]
    if not t then return nil end
    local loc = GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
    local d = ((loc == "zhCN" or loc == "zhTW") and t.dcn ~= "" and t.dcn) or t.den
    return (d and d ~= "") and d or nil
end
function BP.GemName(gid)
    local X = BP.X()
    local nm = xname(X and X.gems and X.gems[gid], nil)
    return nm or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(gid)) or ("#" .. tostring(gid))
end
function BP.GemIcon(gid)
    local X = BP.X()
    local t = X and X.gems and X.gems[gid]
    if t and t.icon and t.icon ~= "" then return "Interface\\Icons\\" .. t.icon end
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(gid)) or 134400
end
function BP.GemUnique(gid)
    local X = BP.X()
    local t = X and X.gems and X.gems[gid]
    return t and t.lim and true or false
end
function BP.EmName(bid)
    local X = BP.X()
    return xname(X and X.embellish and X.embellish[bid], "#" .. tostring(bid))
end
function BP.EmIcon(bid)
    local X = BP.X()
    local t = X and X.embellish and X.embellish[bid]
    return (t and t.icon and t.icon ~= "") and ("Interface\\Icons\\" .. t.icon) or 134400
end
function BP.EmDesc(bid)
    local X = BP.X()
    local t = X and X.embellish and X.embellish[bid]
    if not t then return nil end
    local loc = GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
    local d = ((loc == "zhCN" or loc == "zhTW") and t.dcn ~= "" and t.dcn) or t.den
    return (d and d ~= "") and d or nil
end

-- 启用中的方案 → 属性目标（主面板 / 坯子 / 契合度都走这里）
function BP.StatPercents(specData)
    local key2 = BP.KeyOfSpecData(specData)
    local plan = key2 and select(1, BP.ActivePlan(key2))
    if not plan then return nil end
    local sig = key2 .. ":" .. tostring(plan._rev or 0) .. ":" .. tostring(plan.updated or 0)
    BP._statCache = BP._statCache or {}
    local hit = BP._statCache[sig]
    if hit then return hit.pct, hit.mode end
    local pct, complete = BP.ComputeStatPercents(plan, specData)
    if pct and complete then BP._statCache[sig] = { pct = pct, mode = (plan.stats or {}).mode } end
    return pct, (plan.stats or {}).mode
end

-- 契合度 / 打分权重：主属性照原样，副属性按方案占比归一（最高 = 1）
function BP.Weights(specData)
    local pct = BP.StatPercents(specData)
    local base = specData and specData.statWeights
    if not pct then return base end
    local mx = 0
    for _, k in ipairs(SEC) do if (pct[k] or 0) > mx then mx = pct[k] end end
    if mx <= 0 then return base end
    local w = {}
    for k, v in pairs(base or {}) do w[k] = v end
    for _, k in ipairs(SEC) do w[k] = (pct[k] or 0) / mx end
    return w
end

-- 统一入口：拿权重就调这个（方案不在 / 没启用 → 原 statWeights）
function GearInsight.SpecStatWeights(specData)
    if BP and BP.Weights then
        local ok, w = pcall(BP.Weights, specData)
        if ok and w then return w end
    end
    return specData and specData.statWeights
end

-- ════════════════════════════════════════════════════════════════════
-- 生成方案
-- ════════════════════════════════════════════════════════════════════
-- 从数据 BiS：每槽取数据池 #1；成对槽（戒指/饰品）两槽合池取前两件不同的
-- withFiller=true（只有「从数据推荐生成」按钮传）：套装部位顺手填上排名第一的坯子 cf
--   （09-25 用户「数据推荐的时候，也得直接推荐到坯子」）。页面每次刷新比对「同数据」时不传，免得反复打分。
-- 这个套装部位排名第一的坯子（和悬浮「转换优先级 #1」同一把尺子 BuildFillerList；套装本体不算、幻化外观已在里面剔掉）
function BP.TopFiller(specData, slot)
    if not GearInsight.BuildFillerList then return nil end
    local _, cls = UnitClass("player")
    local armor = GearInsight.BisData and GearInsight.BisData.classArmor and GearInsight.BisData.classArmor[cls]
    local ok, list = pcall(GearInsight.BuildFillerList, armor, slot, nil, specData, nil, true)
    if not (ok and list) then return nil end
    for _, f in ipairs(list) do
        if f.itemId and not f.isTier then return f.itemId end
    end
    return nil
end

function BP.FromData(specData, withFiller)
    local pool = (specData and (rawget(specData, "_dataBySlot") or specData.bisBySlot)) or {}
    local slots, done = {}, {}
    for _, sid in ipairs(SLOTS) do
        if not done[sid] then
            local pair = PAIR[sid]
            if pair then
                local merged = GearInsight.MergePairPool and GearInsight.MergePairPool(pool[sid], pool[pair]) or pool[sid] or {}
                local picks = {}
                for _, e in ipairs(merged) do
                    if not e.planned and (not picks[1] or picks[1].itemId ~= e.itemId) then picks[#picks + 1] = e end
                    if #picks == 2 then break end
                end
                local lo = math.min(sid, pair)
                if picks[1] then slots[#slots + 1] = { slot = lo, id = picks[1].itemId, track = "x", b = BP.CopyPlan(picks[1].bonusIDs) } end
                if picks[2] then slots[#slots + 1] = { slot = lo + 1, id = picks[2].itemId, track = "x", b = BP.CopyPlan(picks[2].bonusIDs) } end
                done[sid], done[pair] = true, true
            else
                for _, e in ipairs(pool[sid] or {}) do
                    if not e.planned then
                        local st = { slot = sid, id = e.itemId, track = "x", b = BP.CopyPlan(e.bonusIDs) }
                        if withFiller and (e.isTier or e.sourceCategory == "tier") then st.cf = BP.TopFiller(specData, sid) end
                        slots[#slots + 1] = st
                        break
                    end
                end
                done[sid] = true
            end
        end
    end
    table.sort(slots, function(a, b) return a.slot < b.slot end)
    return slots
end

-- 从身上：原样
function BP.BonusesFromLink(link)
    local body = type(link) == "string" and link:match("item:([^|]+)")
    if not body then return nil end
    local fields = {}
    for field in (body .. ":"):gmatch("(.-):") do fields[#fields + 1] = field end
    local count = tonumber(fields[13]) or 0
    if count < 1 or count > 100 then return nil end
    local bonuses = {}
    for i = 1, count do
        local value = tonumber(fields[13 + i])
        if not value or value <= 0 then return nil end
        bonuses[i] = value
    end
    return bonuses
end

function BP.EquippedSlot(sid)
    local id = GetInventoryItemID and GetInventoryItemID("player", sid)
    if not id then return nil end
    local link = GetInventoryItemLink and GetInventoryItemLink("player", sid)
    return { slot = sid, id = id, track = "x", b = BP.BonusesFromLink(link) }, link
end

function BP.FromEquipped()
    local slots = {}
    for _, sid in ipairs(SLOTS) do
        local equipped = BP.EquippedSlot(sid)
        if equipped then slots[#slots + 1] = equipped end
    end
    return slots
end

-- 导出链接（国服 .cn，其余 .app —— 与低保导出同一判定）
function BP.ExportURL(code)
    local region = GetCurrentRegion and GetCurrentRegion()
    local domestic = region == 5 or (not region and GearInsight.LOCALE == "zhCN")
    return "https://" .. (domestic and "gearinsight.cn" or "gearinsight.app") .. "/wow/plan#b=" .. code
end

function BP.ExportPlan(key2, id)
    local plan = BP.Get(key2, id)
    if not plan then return nil end
    local copy = {}
    for k, v in pairs(plan) do copy[k] = v end
    copy.specId = BP.SpecIdOf(key2)
    local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("GearInsight", "Version")) or ""
    copy.src = "addon" .. (ver ~= "" and ("-" .. ver) or "")
    return BP.Encode(copy)
end

-- 导入：返回 key2, id 或 nil, 原因码
function BP.Import(code, id)
    local plan, err = BP.Decode(code)
    if not plan then return nil, err end
    local key2 = BP.KeyOfSpecId(plan.specId)
    if not key2 then return nil, "spec" end
    local s = store(key2, true)
    if not id then
        id = "custom"
        for _, pid in ipairs(BP.PLAN_IDS) do
            if not (s.list[pid] and #(s.list[pid].slots or {}) > 0) then id = pid; break end
        end
    end
    s.list[id] = plan
    plan._rev = (plan._rev or 0) + 1
    BP.Changed(key2)
    return key2, id, plan
end
