-- GearInsight — 部位名改用**暴雪自带的本地化全局串**。
--
-- ⭐ 为什么这么做（2026-08-29）：
-- 原来部位名放在 GearInsight.L 里，由 zhCN.lua 建表、enUS.lua / zhTW.lua 各自「就地打补丁」
-- 覆盖。后果是**只有这三种语言有正确部位名**——真正的 deDE / frFR / koKR / ruRU / esES /
-- esMX / ptBR / itIT 客户端两个补丁分支都不进，部位名直接显示简体中文。
--
-- 而这些词暴雪每个客户端都自带官方翻译（HEADSLOT / MAINHANDSLOT / …），
-- 我们没有任何理由自己维护一份、还漏掉 8 种语言。改用全局串以后：
--   · 新增语言 = 零工作量，暴雪发什么语言就支持什么语言；
--   · 用词和游戏内装备栏完全一致，玩家不会看到两套说法。
--
-- ⛔ zhCN 客户端**不进这里**：中文版要求 byte-for-byte 不变，
--    保持 zhCN.lua 里手写的那份，避免措辞被悄悄改掉。

local BLIZZ = {
    SLOT_HEAD     = "HEADSLOT",
    SLOT_NECK     = "NECKSLOT",
    SLOT_SHOULDER = "SHOULDERSLOT",
    SLOT_BACK     = "BACKSLOT",
    SLOT_CHEST    = "CHESTSLOT",
    SLOT_WAIST    = "WAISTSLOT",
    SLOT_LEGS     = "LEGSSLOT",
    SLOT_FEET     = "FEETSLOT",
    SLOT_WRIST    = "WRISTSLOT",
    SLOT_HANDS    = "HANDSSLOT",
    SLOT_MAINHAND = "MAINHANDSLOT",
    SLOT_OFFHAND  = "SECONDARYHANDSLOT",
}

-- 戒指/饰品暴雪只给一个词（"Finger" / "Trinket"），编号我们自己接。
local NUMBERED = {
    SLOT_FINGER1  = { "FINGER0SLOT",  1 },
    SLOT_FINGER2  = { "FINGER0SLOT",  2 },
    SLOT_TRINKET1 = { "TRINKET0SLOT", 1 },
    SLOT_TRINKET2 = { "TRINKET0SLOT", 2 },
}

if GearInsight and GearInsight.LOCALE ~= "zhCN" then
    local L = GearInsight.L
    if L then
        for key, g in pairs(BLIZZ) do
            local v = _G[g]
            -- ⛔ 只在暴雪真给了非空串时才覆盖；拿不到就保留原值（回退到已有翻译）。
            if type(v) == "string" and v ~= "" then L[key] = v end
        end
        for key, def in pairs(NUMBERED) do
            local v = _G[def[1]]
            if type(v) == "string" and v ~= "" then L[key] = v .. " " .. def[2] end
        end
    end
end
