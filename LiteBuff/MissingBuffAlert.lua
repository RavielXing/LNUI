------------------------------------------------------------
-- MissingBuffAlert.lua
-- 独立中央缺失状态提示：玩家自己缺少自身重要buff/宠物/武器效果时，
-- 在屏幕中央以图标形式提示。受163UI配置项alertMissing控制。
------------------------------------------------------------

local _, addon = ...
local C_Spell = C_Spell
local C_UnitAuras = C_UnitAuras
local GetTime = GetTime
local UnitClassBase = UnitClassBase
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsDead = UnitIsDead
local UnitOnTaxi = UnitOnTaxi
local IsMounted = IsMounted
local IsSpellKnown = IsSpellKnown
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer
local UIParent = UIParent
local GameTooltip = GameTooltip
local format = format
local tinsert = tinsert
local wipe = wipe

local FALLBACK_ICON = "Interface\\Icons\\INV_MISC_QUESTIONMARK"
local ICON_SIZE = 42
local ICON_SPACING = 52
local shieldSlotSelections = {}

local function Enabled()
    return U1GetCfgValue and U1GetCfgValue("LiteBuff", "alertMissing")
end

local function IsLocked()
    if not U1GetCfgValue then
        return true
    end
    return U1GetCfgValue("LiteBuff", "missingLock") ~= false
end

local function ShouldHide()
    if UnitIsDeadOrGhost("player") then
        return true
    end
    if UnitOnTaxi and UnitOnTaxi("player") then
        return true
    end
    if IsMounted and IsMounted() then
        return true
    end
    return false
end

local function HasBuff(id)
    return not not addon:GetUnitBuffTimer("player", id)
end

local function HasAnyBuff(ids)
    for _, id in ipairs(ids) do
        if HasBuff(id) then
            return true
        end
    end
    return false
end

local function HasBuffByName(name)
    if not name or name == "" then
        return false
    end
    -- secret环境下GetAuraDataByIndex会直接报错，名字扫描只在不secret时用
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        return false
    end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then
            break
        end
        if not (issecretvalue and type(issecretvalue) == "function" and issecretvalue(aura.name)) and aura.name == name then
            return true
        end
        local id = aura.spellId
        if issecretvalue and type(issecretvalue) == "function" and issecretvalue(id) then
            id = nil
        end
        if id then
            local info = C_Spell.GetSpellInfo(id)
            if info and info.name == name then
                return true
            end
        end
    end
    return false
end

local function GetEnchants()
    local hasMH, _, _, mhID, hasOH, _, _, ohID = GetWeaponEnchantInfo()
    if issecretvalue and issecretvalue(hasMH) then hasMH = nil end
    if issecretvalue and issecretvalue(mhID) then mhID = nil end
    if issecretvalue and issecretvalue(hasOH) then hasOH = nil end
    if issecretvalue and issecretvalue(ohID) then ohID = nil end
    return (hasMH and mhID) or nil, (hasOH and ohID) or nil
end

-- GetWeaponEnchantInfo在大秘境secret环境下可能读不到，改用扫武器tooltip兜底
-- （LiteBuff常驻按钮的武器附魔检测也是走tooltip这条路的）
local lastTooltipScan = 0
local function TooltipHasEnchantBySpellIDs(ids)
    if not ids or #ids == 0 or not LibScanTip then
        return false
    end
    -- tooltip扫描比普通buff查询重，节流到0.5秒一次
    local now = GetTime()
    if now - lastTooltipScan < 0.5 then
        return false
    end
    lastTooltipScan = now

    local names = {}
    for _, spellID in ipairs(ids) do
        local info = C_Spell.GetSpellInfo(spellID)
        local name = info and info.name
        if name then
            tinsert(names, name)
        end
    end
    if #names == 0 then
        return false
    end

    for _, slot in ipairs({16, 17}) do
        if GetInventoryItemLink("player", slot) then
            LibScanTip:CallMethod("SetInventoryItem", "player", slot)
            for _, name in ipairs(names) do
                if LibScanTip:FindText(name) then
                    return true
                end
            end
        end
    end
    return false
end

local ENCHANT_SPELL_IDS = {
    [5400] = {318038, 319778},          -- 火舌武器
    [6498] = {382021, 382022, 382024},  -- 大地生命武器
    [7528] = {457481, 457496},          -- 唤潮者的护卫
    [7143] = {433568, 433550},          -- 圣言祭礼
    [7144] = {433583, 433584},          -- 恳求祭礼
}

local function HasEnchant(id)
    local mh, oh = GetEnchants()
    if id == mh or id == oh then
        return true
    end
    local ids = ENCHANT_SPELL_IDS[id]
    if ids and TooltipHasEnchantBySpellIDs(ids) then
        return true
    end
    return false
end

-- 符文熔铸附魔ID; GetWeaponEnchantInfo只返回临时附魔, 符文熔铸在itemString第3段
local RUNEFORGE_ENCHANT_IDS = {
    [3368] = true, -- 堕落十字军符文
    [3370] = true, -- 锋锐之霜符文
    [3847] = true, -- 岩肤石像鬼符文
    [6241] = true, -- 鲜红符文
    [6242] = true, -- 法术防护符文
    [6244] = true, -- 无尽饥渴符文
    [6245] = true, -- 天启符文
}

-- 取武器永久附魔ID(itemString的|Hitem:物品ID:附魔ID:段); 无武器nil, 有武器但读不到false
local function GetWeaponPermanentEnchantID(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return nil
    end
    if issecretvalue and type(issecretvalue) == "function" and issecretvalue(link) then
        return false
    end
    -- 链接可能带|cnIQn品质前缀, 不能按冒号位置取, 按结构匹配
    local enchant = string.match(link, "|Hitem:%d+:(%d+)")
    return tonumber(enchant) or false
end

-- 所有已装备武器都得是符文熔铸附魔, 任意一把不符即缺失; 没武器时不提示
local function HasRuneforge()
    local enchants = {}
    for _, slot in ipairs({16, 17}) do
        local enchant = GetWeaponPermanentEnchantID(slot)
        if enchant ~= nil then
            tinsert(enchants, enchant)
        end
    end
    if #enchants == 0 then
        return true
    end
    for _, enchant in ipairs(enchants) do
        if enchant == false or not RUNEFORGE_ENCHANT_IDS[enchant] then
            return false
        end
    end
    return true
end

local function GetIcon(id)
    local info = C_Spell.GetSpellInfo(id)
    return info and info.iconID or nil
end

local function FirstKnownIcon(ids)
    for _, id in ipairs(ids) do
        if IsSpellKnown(id) then
            local icon = GetIcon(id)
            if icon then
                return icon
            end
        end
    end
    for _, id in ipairs(ids) do
        local icon = GetIcon(id)
        if icon then
            return icon
        end
    end
    return nil
end

local function KnownIDs(ids)
    local out = {}
    for _, id in ipairs(ids) do
        if IsSpellKnown(id) then
            tinsert(out, id)
        end
    end
    return out
end

local function SortByPriority(ids, priority)
    local order = {}
    for i, id in ipairs(priority) do
        order[id] = i
    end
    table.sort(ids, function(a, b)
        local oa, ob = order[a], order[b]
        if oa == nil then oa = 999 end
        if ob == nil then ob = 999 end
        return oa < ob
    end)
    return ids
end

local function GetCurrentSpecID()
    local index = GetSpecialization()
    if not index then
        return nil
    end
    return GetSpecializationInfo(index)
end

local function SpellName(id)
    local info = C_Spell.GetSpellInfo(id)
    return info and info.name or tostring(id)
end

local function HasForm(id)
    local name = SpellName(id)
    return not not (name and addon:IsFormActive(name))
end

-- 暗影形态技能ID与光环ID同为232698; 形态类光环用IsFormActive兜底
local SHADOWFORM_SPELL_ID = 232698
local function HasShadowform()
    if HasAnyBuff({SHADOWFORM_SPELL_ID}) then
        return true
    end
    return HasForm(SHADOWFORM_SPELL_ID)
end

local function IsSpellOnCooldown(spellID)
    if not spellID then
        return false
    end
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if not info then
            return false
        end
        local startTime = info.startTime
        local duration = info.duration
        if issecretvalue and type(issecretvalue) == "function" and (issecretvalue(startTime) or issecretvalue(duration)) then
            return false
        end
        return type(startTime) == "number" and type(duration) == "number" and duration > 0 and GetTime() < startTime + duration
    end
    if GetSpellCooldown then
        local startTime, duration = GetSpellCooldown(spellID)
        if issecretvalue and type(issecretvalue) == "function" and (issecretvalue(startTime) or issecretvalue(duration)) then
            return false
        end
        return type(startTime) == "number" and type(duration) == "number" and duration > 0 and GetTime() < startTime + duration
    end
    return false
end

local function GetPetPersistentInfo()
    local class = UnitClassBase("player")
    local key
    local defaultCast
    if class == "HUNTER" then
        key = "HunterPets"
    elseif class == "DEATHKNIGHT" then
        key = "DeathKnightGhoul"
        defaultCast = 46584
    elseif class == "WARLOCK" then
        key = "WarlockPets"
    end
    local btn = key and LiteBuff:GetButton(key)
    if not btn then
        return nil, defaultCast, {}
    end

    local icon = btn.icon and btn.icon.icon and btn.icon.icon:GetTexture()
    local cast
    local options = {}
    if btn.spellList then
        for _, data in ipairs(btn.spellList) do
            if data and data.id then
                tinsert(options, data.id)
            end
        end
    end
    if btn.spellList and btn.spellList[btn.index] and btn.spellList[btn.index].id then
        cast = btn.spellList[btn.index].id
    end
    if not cast then
        local attr = btn:GetAttribute("spell1")
        if type(attr) == "number" then
            cast = attr
        end
    end
    if not cast then
        cast = defaultCast
    end
    return icon, cast, options
end

local function MissingEntries()
    local class = UnitClassBase("player")
    if not class then
        return {}
    end

    local missing = {}
    local function add(text, icon, cast, options, fixedText)
        if not options and cast then
            options = { cast }
        end
        tinsert(missing, { text = text, icon = icon or FALLBACK_ICON, cast = cast, options = options, fixedText = fixedText })
    end

    if class == "PALADIN" then
        local auras = {32223, 465, 317920}
        -- 默认优先虔诚光环，其次专注，最后十字军；后续可按版本/场景再调
        local knownAuras = SortByPriority(KnownIDs(auras), {465, 317920, 32223})
        local anyAuraActive = false
        for _, id in ipairs(knownAuras) do
            if HasForm(id) then
                anyAuraActive = true
                break
            end
        end
        if #knownAuras > 0 and not anyAuraActive then
            add("缺少光环(十字军/虔诚/专注)", FirstKnownIcon(knownAuras), knownAuras[1], knownAuras)
        end
        -- 铸光者祭礼：圣言祭礼/恳求祭礼二选一，只检查已学会的那个
        -- 圣言祭礼附魔7143，恳求祭礼附魔7144；祭礼也可能是技能本身的光环，所以多重检测
        local rites = {
            { skill = 433568, aura = 433550, enchant = 7143 }, -- 圣言祭礼
            { skill = 433583, aura = 433584, enchant = 7144 }, -- 恳求祭礼
        }
        local knownRiteSkills = {}
        local anyRiteActive = false
        for _, r in ipairs(rites) do
            if IsSpellKnown(r.skill) then
                tinsert(knownRiteSkills, r.skill)
                if HasAnyBuff({r.aura}) or HasAnyBuff({r.skill}) or HasBuffByName(SpellName(r.aura)) or HasBuffByName(SpellName(r.skill)) or HasEnchant(r.enchant) then
                    anyRiteActive = true
                end
            end
        end
        if #knownRiteSkills > 0 and not anyRiteActive then
            add("缺少铸光者祭礼", GetIcon(knownRiteSkills[1]), knownRiteSkills[1], knownRiteSkills)
        end
    elseif class == "WARRIOR" then
        if not HasAnyBuff({6673}) then
            add("缺少" .. SpellName(6673), GetIcon(6673), 6673)
        end
    elseif class == "ROGUE" then
        local lethal = {315584, 8679, 2823, 381664}
        local nonlethal = {3408, 381637, 5761}
        -- 优先级参考当前版本常见选择：增效/夺命/速效/致伤，萎缩/麻痹/减速
        local knownLethal = SortByPriority(KnownIDs(lethal), {381664, 2823, 315584, 8679})
        local knownNonlethal = SortByPriority(KnownIDs(nonlethal), {381637, 5761, 3408})
        if #knownLethal > 0 and not HasAnyBuff(lethal) then
            add("缺少伤害性毒药", FirstKnownIcon(knownLethal), knownLethal[1], knownLethal)
        end
        if #knownNonlethal > 0 and not HasAnyBuff(nonlethal) then
            add("缺少功能毒药", FirstKnownIcon(knownNonlethal), knownNonlethal[1], knownNonlethal)
        end
    elseif class == "DRUID" then
        if not HasAnyBuff({1126}) then
            add("缺少" .. SpellName(1126), GetIcon(1126), 1126)
        end
    elseif class == "MAGE" then
        if not HasAnyBuff({1459}) then
            add("缺少" .. SpellName(1459), GetIcon(1459), 1459)
        end
    elseif class == "SHAMAN" then
        if not HasAnyBuff({462854}) then
            add("缺少" .. SpellName(462854), GetIcon(462854), 462854)
        end
        -- 大地之盾施法用974，检测用被动光环383648
        local shieldDefs = {
            { cast = 192106, buff = 192106 },
            { cast = 52127, buff = 52127 },
            { cast = 974, buff = 383648 },
        }
        local knownShieldCasts = {}
        for _, def in ipairs(shieldDefs) do
            if IsSpellKnown(def.cast) then
                tinsert(knownShieldCasts, def.cast)
            end
        end
        local need = math.min(2, #knownShieldCasts)
        if need > 0 then
            local presentCount = 0
            local presentBuff = {}
            for _, def in ipairs(shieldDefs) do
                if HasAnyBuff({def.buff}) then
                    presentCount = presentCount + 1
                    presentBuff[def.buff] = true
                end
            end
            local missingCount = need - presentCount
            if missingCount > 0 then
                local shieldPriority
                if GetCurrentSpecID() == 264 then
                    shieldPriority = {52127, 974, 192106}
                else
                    shieldPriority = {192106, 974, 52127}
                end
                local knownOrdered = SortByPriority(knownShieldCasts, shieldPriority)

                -- 为每个缺失的护盾槽生成一个图标，槽位之间互斥
                local usedCast = {}
                local function IsCastPresent(cast)
                    for _, def in ipairs(shieldDefs) do
                        if def.cast == cast then
                            return presentBuff[def.buff] or usedCast[cast]
                        end
                    end
                    return false
                end

                for slot = 1, missingCount do
                    local available = {}
                    for _, cast in ipairs(knownOrdered) do
                        if not IsCastPresent(cast) then
                            tinsert(available, cast)
                        end
                    end
                    if #available == 0 then
                        break
                    end

                    local selected = shieldSlotSelections[slot]
                    local selectedStillAvailable = false
                    if selected then
                        for _, cast in ipairs(available) do
                            if cast == selected then
                                selectedStillAvailable = true
                                break
                            end
                        end
                    end
                    if not selectedStillAvailable then
                        selected = available[1]
                    end
                    shieldSlotSelections[slot] = selected
                    usedCast[selected] = true

                    add(format("缺少元素护盾(%d)", slot), GetIcon(selected), selected, available)
                end
            else
                wipe(shieldSlotSelections)
            end
        end
        if IsSpellKnown(382021) and not HasEnchant(6498) then
            add("缺少大地生命武器", GetIcon(382021), 382021)
        end
        if IsSpellKnown(318038) and not HasEnchant(5400) then
            add("缺少火舌武器", GetIcon(318038), 318038)
        end
        if GetCurrentSpecID() == 264 and IsSpellKnown(457481) and not HasEnchant(7528) then
            add("缺少唤潮者的护卫", GetIcon(457481), 457481)
        end
    elseif class == "HUNTER" then
        local specID = GetCurrentSpecID()
        if (specID == 253 or specID == 255) and (not UnitExists("pet") or UnitIsDead("pet")) then
            local icon, cast, options = GetPetPersistentInfo()
            add("缺失宠物", icon or 461121, cast, options, true)
        end
    elseif class == "DEATHKNIGHT" then
        local specID = GetCurrentSpecID()
        -- 亡者复生在CD时不提示缺宠物，免得明知道召不了还一直闪
        if specID == 252 and not IsSpellOnCooldown(46584) and (not UnitExists("pet") or UnitIsDead("pet")) then
            local icon, cast, options = GetPetPersistentInfo()
            add("缺失宠物", icon or 461121, cast, options, true)
        end
        -- 符文熔铸只能在特定区域使用, 所以只提示不给按钮
        if not HasRuneforge() then
            add("武器缺少符文熔铸", GetIcon(53428), nil, nil, true)
        end
    elseif class == "WARLOCK" then
        if not UnitExists("pet") or UnitIsDead("pet") then
            local icon, cast, options = GetPetPersistentInfo()
            add("缺失宠物", icon or 461121, cast, options, true)
        end
    elseif class == "EVOKER" then
        local bronze = {381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758}
        if not HasAnyBuff(bronze) then
            add("缺少青铜龙的祝福", FirstKnownIcon(bronze), 364342)
        end
    elseif class == "PRIEST" then
        if not HasAnyBuff({21562}) then
            add("缺少" .. SpellName(21562), GetIcon(21562), 21562)
        end
        -- 暗影形态, 学会才提示
        if IsSpellKnown(SHADOWFORM_SPELL_ID) and not HasShadowform() then
            add("缺少" .. SpellName(SHADOWFORM_SPELL_ID), GetIcon(SHADOWFORM_SPELL_ID), SHADOWFORM_SPELL_ID)
        end
    end

    return missing
end

local function ApplyCastToButton(b, id)
    if not id then
        b:SetAttribute("type", nil)
        b:SetAttribute("spell", nil)
        b:SetAttribute("macrotext", nil)
        b:SetAttribute("type1", nil)
        b:SetAttribute("spell1", nil)
        b:SetAttribute("macrotext1", nil)
        b.appliedCast = nil
    elseif not InCombatLockdown() then
        if id == 974 then
            -- 大地之盾可对队友施放：当前友方目标优先，没有则对自己
            local macrotext = '/cast [@target,help,nodead][@player] ' .. SpellName(974)
            b:SetAttribute("type", "macro")
            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext", macrotext)
            b:SetAttribute("macrotext1", macrotext)
            b:SetAttribute("spell", nil)
            b:SetAttribute("spell1", nil)
        else
            local spell = SpellName(id)
            b:SetAttribute("type", "spell")
            b:SetAttribute("type1", "spell")
            b:SetAttribute("spell", spell)
            b:SetAttribute("spell1", spell)
            b:SetAttribute("macrotext", nil)
            b:SetAttribute("macrotext1", nil)
        end
        b.appliedCast = id
    end
end

local function SetupStateDriver(b)
    if not b.stateDriverRegistered then
        b.stateDriverRegistered = true
        RegisterStateDriver(b, "visibility", "[combat] hide; show")
    end
end

local frame = CreateFrame("Frame", "LiteBuffMissingAlertFrame", UIParent)
frame:SetFrameStrata("MEDIUM")
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    if not IsLocked() then
        self:StartMoving()
    end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    if addon.db then
        addon.db.missingAlertPos = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
end)
frame:Hide()

-- 解锁时显示的定位框，方便没有缺失提示时也能拖动位置
local dragFrame = CreateFrame("Frame", nil, UIParent)
dragFrame:SetSize(140, 34)
dragFrame:SetFrameStrata("HIGH")
dragFrame:SetMovable(true)
dragFrame:EnableMouse(true)
dragFrame:RegisterForDrag("LeftButton")
dragFrame:SetClampedToScreen(true)
local dragBg = dragFrame:CreateTexture(nil, "BACKGROUND")
dragBg:SetAllPoints()
dragBg:SetColorTexture(0, 0.8, 0, 0.4)
local dragLabel = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dragLabel:SetPoint("CENTER")
dragLabel:SetText("缺失Buff提示位置")
dragFrame:Hide()

local function SaveCurrentPosition(x, y)
    if addon.db then
        addon.db.missingAlertPos = { point = "CENTER", relativePoint = "CENTER", x = x or 0, y = y or 0 }
    end
end

local DEFAULT_POS_X = 300
local DEFAULT_POS_Y = 0

local function ApplySavedPosition()
    local pos = addon.db and addon.db.missingAlertPos
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
        dragFrame:ClearAllPoints()
        dragFrame:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_POS_X, DEFAULT_POS_Y)
        dragFrame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_POS_X, DEFAULT_POS_Y)
    end
end

dragFrame:SetScript("OnDragStart", function(self)
    if not IsLocked() then
        self:StartMoving()
    end
end)
dragFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local px, py = UIParent:GetCenter()
    local cx, cy = self:GetCenter()
    local x, y = math.floor(cx - px + 0.5), math.floor(cy - py + 0.5)
    SaveCurrentPosition(x, y)
    ApplySavedPosition()
end)

local function GetButtonGlowLib()
    if LibStub then
        return LibStub("LibButtonGlow-1.0", true)
    end
end

local function StartGlow(b)
    if not b or b._glowStarted then
        return
    end
    b._glowStarted = true
    local LBG = GetButtonGlowLib()
    if LBG and LBG.ShowOverlayGlow then
        LBG.ShowOverlayGlow(b)
        local ov = b.__LBGoverlay
        if ov then
            local w, h = b:GetSize()
            ov:SetSize(w * 1.8, h * 1.8)
            ov:SetPoint("TOPLEFT", b, "TOPLEFT", -w * 0.4, h * 0.4)
            ov:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", w * 0.4, -h * 0.4)
        end
        return
    end
    if not b._glowTex then
        b._glowTex = b:CreateTexture(nil, "OVERLAY")
        b._glowTex:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
        b._glowTex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
        b._glowTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        b._glowTex:SetVertexColor(1, 0.9, 0.2, 1)
        b._glowTex:SetDrawLayer("OVERLAY", 1)
    end
    b._glowTex:Show()
end

local function StopGlow(b)
    if not b or not b._glowStarted then
        return
    end
    b._glowStarted = nil
    local LBG = GetButtonGlowLib()
    if LBG and LBG.HideOverlayGlow then
        LBG.HideOverlayGlow(b)
        return
    end
    if b._glowTex then
        b._glowTex:Hide()
    end
end

local icons = {}

local function UpdateDisplay(list)
    if #list == 0 then
        frame:Hide()
        return
    end

    local total = #list
    frame:SetSize(total * ICON_SPACING + 20, ICON_SIZE + 10)
    frame:Show()

    for i, entry in ipairs(list) do
        local b = icons[i]
        if not b then
            b = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
            b:SetSize(ICON_SIZE, ICON_SIZE)
            b:RegisterForClicks("AnyDown", "AnyUp")
            b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetAllPoints()
            SetupStateDriver(b)
            b:SetScript("OnEnter", function(self)
                if self.entryText then
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:AddLine(self.entryText, 1, 1, 1, true)
                    GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            b:SetScript("OnMouseWheel", function(self, delta)
                if InCombatLockdown() then
                    return
                end
                local opts = self.entryOptions
                if not opts or #opts < 2 then
                    return
                end
                local idx = self.entryOptionIndex or 1
                idx = idx - delta
                if idx < 1 then
                    idx = #opts
                elseif idx > #opts then
                    idx = 1
                end
                self.entryOptionIndex = idx
                local id = opts[idx]
                self.entryCast = id
                ApplyCastToButton(self, id)
                local icon = GetIcon(id)
                if icon then
                    self.icon:SetTexture(icon)
                end
                local name = SpellName(id)
                if name and not self.fixedText then
                    self.entryText = name
                end
            end)
            b:RegisterForDrag("LeftButton")
            b:SetScript("OnDragStart", function()
                if not IsLocked() then
                    frame:StartMoving()
                end
            end)
            b:SetScript("OnDragStop", function()
                frame:StopMovingOrSizing()
                local point, _, relativePoint, x, y = frame:GetPoint(1)
                if addon.db then
                    addon.db.missingAlertPos = { point = point, relativePoint = relativePoint, x = x, y = y }
                end
                ApplySavedPosition()
            end)
            icons[i] = b
        end
        SetupStateDriver(b)

        b:ClearAllPoints()
        b:SetPoint("CENTER", frame, "CENTER", (i - (total + 1) / 2) * ICON_SPACING, 0)
        local opts = entry.options
        if opts and #opts > 0 then
            local sameOptions = b.entryOptions and #b.entryOptions == #opts
            if sameOptions then
                for j = 1, #opts do
                    if b.entryOptions[j] ~= opts[j] then
                        sameOptions = false
                        break
                    end
                end
            end
            if sameOptions and b.entryOptionIndex then
                local idx = b.entryOptionIndex
                if idx < 1 then
                    idx = 1
                elseif idx > #opts then
                    idx = #opts
                end
                b.entryOptionIndex = idx
                local id = opts[idx]
                b.entryCast = id
                local name = SpellName(id)
                b.entryText = (entry.fixedText and entry.text) or name or entry.text
                b.icon:SetTexture(GetIcon(id) or entry.icon or FALLBACK_ICON)
            else
                b.entryOptions = opts
                b.entryOptionIndex = 1
                b.entryCast = opts[1]
                local name = SpellName(opts[1])
                b.entryText = (entry.fixedText and entry.text) or name or entry.text
                b.icon:SetTexture(GetIcon(opts[1]) or entry.icon or FALLBACK_ICON)
            end
        else
            b.entryOptions = nil
            b.entryOptionIndex = nil
            b.entryCast = entry.cast
            b.entryText = entry.text
            b.icon:SetTexture(entry.icon or FALLBACK_ICON)
        end
        b.fixedText = entry.fixedText
        ApplyCastToButton(b, b.entryCast)
        b:EnableMouse(true)
        pcall(StartGlow, b)
        b:Show()
    end

    for i = total + 1, #icons do
        local old = icons[i]
        if old then
            if old.stateDriverRegistered then
                UnregisterStateDriver(old, "visibility")
                old.stateDriverRegistered = nil
            end
            pcall(StopGlow, old)
            old:EnableMouse(false)
            old:Hide()
        end
    end
end

-- 进副本/换场景后先等几秒，避免角色光环/姿态还没就绪时误报缺失
local zoneSuppressUntil = 0
local zoneFrame = CreateFrame("Frame")
zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneFrame:SetScript("OnEvent", function()
    zoneSuppressUntil = GetTime() + 3
end)

local positionRestored = false
C_Timer.NewTicker(0.3, function()
    if not positionRestored then
        positionRestored = true
        ApplySavedPosition()
    end
    local locked = IsLocked()
    if locked or ShouldHide() then
        dragFrame:Hide()
    elseif frame:IsShown() then
        -- 有缺失提示时直接拖提示图标即可，定位框隐藏避免遮挡点击
        dragFrame:Hide()
    else
        dragFrame:Show()
    end
    -- 子按钮已用RegisterStateDriver在战斗中自动隐藏
    if InCombatLockdown() then
        dragFrame:Hide()
        return
    end
    -- 刚进副本/场景时等光环数据稳定再判断，避免插钥匙后误报
    if GetTime() < zoneSuppressUntil then
        frame:Hide()
        return
    end
    if Enabled() and not ShouldHide() then
        UpdateDisplay(MissingEntries())
    else
        frame:Hide()
    end
end)
